provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    key = "staging/terraform.tfstate"
    # Other backend config will be provided via CLI or environment variables
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Networking module
module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  region       = var.aws_region
}

# Storage module
module "storage" {
  source = "../../modules/storage"

  project_name            = var.project_name
  environment             = var.environment
  region                  = var.aws_region
  enable_encryption       = var.enable_encryption
  kms_key_arn             = var.kms_key_arn
  raw_data_retention_days = var.raw_data_retention_days
  
  # Data catalog and crawler configuration
  create_glue_catalog_database = true
  create_glue_crawlers         = true
  crawler_schedule             = var.crawler_schedule
  raw_data_path_patterns       = var.raw_data_path_patterns
  processed_data_path_patterns = var.processed_data_path_patterns
  curated_data_path_patterns   = var.curated_data_path_patterns
  
  # VPC configuration for crawlers
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.private_subnet_ids
  security_group_ids = [module.security.glue_security_group_id]
}

# Security module
module "security" {
  source = "../../modules/security"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  enable_encryption = var.enable_encryption
}

# Glue module
module "glue" {
  source = "../../modules/glue"

  project_name                = var.project_name
  environment                 = var.environment
  region                      = var.aws_region
  vpc_id                      = module.networking.vpc_id
  subnet_ids                  = module.networking.private_subnet_ids
  security_group_id           = module.security.glue_security_group_id
  scripts_bucket_name         = module.storage.scripts_bucket_name
  raw_bucket_name             = module.storage.raw_bucket_name
  processed_bucket_name       = module.storage.processed_bucket_name
  curated_bucket_name         = module.storage.curated_bucket_name
  temp_bucket_name            = module.storage.temp_bucket_name
  glue_catalog_database_name  = module.storage.glue_catalog_database_name
  glue_version                = var.glue_version
  python_version              = var.python_version
  worker_type                 = var.worker_type
  number_of_workers           = var.number_of_workers
  max_concurrent_runs         = var.max_concurrent_runs
  job_timeout                 = var.job_timeout
  enable_job_bookmarks        = var.enable_job_bookmarks
  enable_spark_ui             = var.enable_spark_ui
  enable_metrics              = var.enable_metrics
  enable_continuous_logging   = var.enable_continuous_logging
  enable_encryption           = var.enable_encryption
  kms_key_arn                 = var.kms_key_arn
}

# Monitoring module
module "monitoring" {
  source = "../../modules/monitoring"

  project_name              = var.project_name
  environment               = var.environment
  region                    = var.aws_region
  glue_job_names            = module.glue.glue_job_names
  log_retention_days        = var.log_retention_days
  alarm_email               = var.alarm_email
  job_duration_threshold    = var.job_duration_threshold
  enable_encryption         = var.enable_encryption
  kms_key_arn               = var.kms_key_arn
  monitoring_role_arn       = module.security.monitoring_role_arn
  scripts_bucket_name       = module.storage.scripts_bucket_name
  enable_enhanced_monitoring = var.enable_enhanced_monitoring
}

# DynamoDB policy for Glue jobs
resource "aws_iam_policy" "dynamodb_policy" {
  name        = "${var.project_name}-${var.environment}-dynamodb-policy"
  description = "Policy for Glue jobs to access DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = [
          module.glue.job_state_table_arn,
          module.glue.job_bookmark_table_arn
        ]
      }
    ]
  })
}

# Attach DynamoDB policy to Glue job role
resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy" {
  role       = module.glue.glue_job_role_name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

# SNS policy for Glue jobs
resource "aws_iam_policy" "sns_policy" {
  name        = "${var.project_name}-${var.environment}-sns-policy"
  description = "Policy for Glue jobs to publish to SNS topics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sns:Publish"
        ]
        Effect   = "Allow"
        Resource = [module.monitoring.sns_topic_arn]
      }
    ]
  })
}

# Attach SNS policy to Glue job role
resource "aws_iam_role_policy_attachment" "attach_sns_policy" {
  role       = module.glue.glue_job_role_name
  policy_arn = aws_iam_policy.sns_policy.arn
}
