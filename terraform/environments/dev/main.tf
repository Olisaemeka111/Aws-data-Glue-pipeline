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

locals {
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  bucket_prefix      = "${var.project_name}-${var.environment}"
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

# Storage Module
module "storage" {
  source = "../../modules/storage"
  
  project_name      = var.project_name
  environment       = var.environment
  bucket_prefix     = local.bucket_prefix
  enable_encryption = var.enable_data_encryption
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
  monitoring_role_arn       = module.security.monitoring_role_arn
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

# Lambda Data Trigger Module
module "lambda_trigger" {
  source = "../../modules/lambda_trigger"
  
  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  aws_account_id      = data.aws_caller_identity.current.account_id
  lambda_zip_path     = var.lambda_zip_path
  source_bucket       = module.storage.raw_bucket.name
  glue_workflow_name  = module.glue.workflow_name
  subnet_ids          = module.networking.private_subnet_ids
  security_group_ids  = [module.security.lambda_security_group_id]
  kms_key_arn         = module.storage.kms_key_arn
  max_file_size_mb    = var.max_file_size_mb
  allowed_file_types  = var.allowed_file_types
  blocked_files_threshold = var.blocked_files_threshold
  enable_security_hub = var.enable_security_hub
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

data "aws_caller_identity" "current" {}
