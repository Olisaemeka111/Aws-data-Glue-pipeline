provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  availability_zones         = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  secondary_availability_zones = ["${var.secondary_region}a", "${var.secondary_region}b", "${var.secondary_region}c"]
  bucket_prefix              = "${var.project_name}-${var.environment}"
}

# Networking Module
module "networking" {
  source = "../../modules/networking"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  aws_region         = var.aws_region
  availability_zones = local.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
  enable_vpc_endpoints = var.enable_vpc_endpoints
}

# Storage Module - Primary Region
module "storage" {
  source = "../../modules/storage"
  
  project_name      = var.project_name
  environment       = var.environment
  bucket_prefix     = local.bucket_prefix
  enable_encryption = var.enable_data_encryption
  enable_replication = var.enable_cross_region_replication
  replication_region = var.enable_cross_region_replication ? var.secondary_region : null
}

# Security Module
module "security" {
  source = "../../modules/security"
  
  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  vpc_id              = module.networking.vpc_id
  raw_bucket_arn      = module.storage.raw_bucket.arn
  processed_bucket_arn = module.storage.processed_bucket.arn
  curated_bucket_arn  = module.storage.curated_bucket.arn
  scripts_bucket_arn  = module.storage.scripts_bucket.arn
  temp_bucket_arn     = module.storage.temp_bucket.arn
  dynamodb_table_arns = []  # Will be updated after Glue module creates tables
  kms_key_arns        = var.enable_data_encryption ? [module.storage.kms_key_arn] : []
  kms_key_arn         = module.storage.kms_key_arn
  sns_topic_arns      = []  # Will be updated after Monitoring module creates SNS topics
  enable_encryption   = var.enable_data_encryption
}

# Glue Module
module "glue" {
  source = "../../modules/glue"
  
  project_name            = var.project_name
  environment             = var.environment
  glue_service_role_arn   = module.security.glue_service_role_arn
  raw_bucket_name         = module.storage.raw_bucket.name
  processed_bucket_name   = module.storage.processed_bucket.name
  curated_bucket_name     = module.storage.curated_bucket.name
  scripts_bucket_name     = module.storage.scripts_bucket.name
  temp_bucket_name        = module.storage.temp_bucket.name
  subnet_id               = module.networking.private_subnet_ids[0]
  subnet_availability_zone = local.availability_zones[0]
  security_group_id       = module.security.glue_connection_security_group_id
  glue_version            = var.glue_version
  python_version          = var.python_version
  worker_type             = var.glue_worker_type
  number_of_workers       = var.glue_number_of_workers
  job_timeout             = var.glue_job_timeout
  max_retries             = var.glue_job_max_retries
  enable_encryption       = var.enable_data_encryption
  kms_key_arn             = module.storage.kms_key_arn
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"
  
  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  glue_job_names            = [
    module.glue.data_ingestion_job_name,
    module.glue.data_processing_job_name,
    module.glue.data_quality_job_name
  ]
  log_retention_days        = var.log_retention_days
  alarm_email_addresses     = var.alarm_email_addresses
  job_duration_threshold    = var.glue_job_timeout * 0.75  # Set threshold at 75% of timeout
  enable_encryption         = var.enable_data_encryption
  kms_key_arn               = module.storage.kms_key_arn
  cloudwatch_logs_kms_key_arn = module.security.cloudwatch_logs_kms_key_arn
  monitoring_role_arn       = module.security.monitoring_role_name
  scripts_bucket_name       = module.storage.scripts_bucket.name
  enable_enhanced_monitoring = var.enable_monitoring
}

# Update security module with dynamodb table arns and sns topic arns
resource "aws_iam_policy" "dynamodb_tables_policy" {
  name        = "${var.project_name}-${var.environment}-dynamodb-tables-policy"
  description = "Policy for DynamoDB tables access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${module.glue.job_bookmarks_table_name}",
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${module.glue.job_state_table_name}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_tables_policy_attachment" {
  role       = module.security.glue_service_role_name
  policy_arn = aws_iam_policy.dynamodb_tables_policy.arn
}

resource "aws_iam_policy" "sns_topics_policy" {
  name        = "${var.project_name}-${var.environment}-sns-topics-policy"
  description = "Policy for SNS topics access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          module.monitoring.sns_topic_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sns_topics_policy_attachment" {
  role       = module.security.glue_service_role_name
  policy_arn = aws_iam_policy.sns_topics_policy.arn
}

# Disaster Recovery Configuration
resource "aws_dynamodb_table" "job_bookmarks_replica" {
  count        = var.enable_disaster_recovery ? 1 : 0
  provider     = aws.secondary
  name         = "${var.project_name}-${var.environment}-job-bookmarks-replica"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_name"
  range_key    = "run_id"

  attribute {
    name = "job_name"
    type = "S"
  }

  attribute {
    name = "run_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-job-bookmarks-replica"
  }
}

resource "aws_dynamodb_table" "job_state_replica" {
  count        = var.enable_disaster_recovery ? 1 : 0
  provider     = aws.secondary
  name         = "${var.project_name}-${var.environment}-job-state-replica"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_name"

  attribute {
    name = "job_name"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-job-state-replica"
  }
}

# AWS Config Rule for monitoring compliance
resource "aws_config_config_rule" "s3_bucket_encryption" {
  name        = "${var.project_name}-${var.environment}-s3-encryption"
  description = "Checks whether S3 buckets have encryption enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "dynamodb_encryption" {
  name        = "${var.project_name}-${var.environment}-dynamodb-encryption"
  description = "Checks whether DynamoDB tables have encryption enabled"

  source {
    owner             = "AWS"
    source_identifier = "DYNAMODB_TABLE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-${var.environment}-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_iam_role" "config_role" {
  name = "${var.project_name}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy_attachment" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

data "aws_caller_identity" "current" {}
