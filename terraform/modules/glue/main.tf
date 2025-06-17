resource "aws_glue_catalog_database" "main" {
  name        = "${var.project_name}_${var.environment}_catalog"
  description = "Glue Catalog Database for ${var.project_name} in ${var.environment} environment"
  
  catalog_id = data.aws_caller_identity.current.account_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-catalog"
    Environment = var.environment
    Component   = "glue-catalog"
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# KMS Key for Glue encryption (if not provided)
resource "aws_kms_key" "glue_key" {
  count = var.enable_encryption ? 1 : 0
  
  description             = "KMS key for AWS Glue encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Glue Service"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-glue-key"
    Environment = var.environment
    Component   = "encryption"
  }
}

resource "aws_kms_alias" "glue_key_alias" {
  count = var.enable_encryption ? 1 : 0
  
  name          = "alias/${var.project_name}-${var.environment}-glue"
  target_key_id = aws_kms_key.glue_key[0].key_id
}

# Glue Connection for VPC access (only if VPC is configured)
resource "aws_glue_connection" "vpc_connection" {
  count = var.subnet_id != null && var.subnet_id != "" ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-vpc-connection"
  
  connection_type = "NETWORK"
  
  connection_properties = {
    # Remove placeholder JDBC properties for network connection
  }
  
  physical_connection_requirements {
    availability_zone      = var.subnet_availability_zone
    security_group_id_list = [var.security_group_id]
    subnet_id              = var.subnet_id
  }

  description = "VPC connection for Glue jobs in ${var.environment} environment"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc-connection"
    Environment = var.environment
    Component   = "glue-network"
  }
}

# Glue Crawler for raw data discovery
resource "aws_glue_crawler" "raw_data" {
  name          = "${var.project_name}-${var.environment}-raw-data-crawler"
  role          = var.glue_service_role_arn
  database_name = aws_glue_catalog_database.main.name
  description   = "Crawler for raw data discovery in ${var.environment} environment"
  
  s3_target {
    path = "s3://${var.raw_bucket_name}/data/"
    
    # Connection name only if VPC connection exists
    connection_name = var.subnet_id != null ? aws_glue_connection.vpc_connection[0].name : null
  }
  
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })
  
  # Schedule based on environment
  schedule = var.environment == "prod" ? "cron(0 */6 * * ? *)" : "cron(0 */12 * * ? *)"
  
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
  
  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }
  
  lineage_configuration {
    crawler_lineage_settings = "ENABLE"
  }
  
  # Security configuration
  security_configuration = var.enable_encryption ? aws_glue_security_configuration.main[0].name : null
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-raw-data-crawler"
    Environment = var.environment
    Component   = "glue-crawler"
    DataSource  = "raw"
  }
  
  depends_on = [aws_glue_catalog_database.main]
}

# Glue Crawler for processed data
resource "aws_glue_crawler" "processed_data" {
  name          = "${var.project_name}-${var.environment}-processed-data-crawler"
  role          = var.glue_service_role_arn
  database_name = aws_glue_catalog_database.main.name
  description   = "Crawler for processed data discovery in ${var.environment} environment"
  
  s3_target {
    path = "s3://${var.processed_bucket_name}/data/"
    
    connection_name = var.subnet_id != null ? aws_glue_connection.vpc_connection[0].name : null
  }
  
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })
  
  schedule = var.environment == "prod" ? "cron(0 */8 * * ? *)" : "cron(0 */24 * * ? *)"
  
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
  
  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }
  
  lineage_configuration {
    crawler_lineage_settings = "ENABLE"
  }
  
  security_configuration = var.enable_encryption ? aws_glue_security_configuration.main[0].name : null
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-processed-data-crawler"
    Environment = var.environment
    Component   = "glue-crawler"
    DataSource  = "processed"
  }
  
  depends_on = [aws_glue_catalog_database.main]
}

# Glue Security Configuration
resource "aws_glue_security_configuration" "main" {
  count = var.enable_encryption ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-security-config"

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn                = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.glue_key[0].arn
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "CSE-KMS"
      kms_key_arn                   = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.glue_key[0].arn
    }

    s3_encryption {
      s3_encryption_mode = "SSE-KMS"
      kms_key_arn        = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.glue_key[0].arn
    }
  }
  
  # Tags are not supported in aws_glue_security_configuration
}

# DynamoDB table for job bookmarks
resource "aws_dynamodb_table" "job_bookmarks" {
  name         = "${var.project_name}-${var.environment}-job-bookmarks"
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
  
  # Global secondary index for querying by status
  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    range_key       = "updated_at"
    projection_type = "ALL"
  }
  
  attribute {
    name = "status"
    type = "S"
  }
  
  attribute {
    name = "updated_at"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.enable_encryption ? (var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.glue_key[0].arn) : null
  }
  
  # TTL for automatic cleanup of old records (30 days)
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-job-bookmarks"
    Environment = var.environment
    Component   = "glue-bookmarks"
  }
}

# DynamoDB table for job state management
resource "aws_dynamodb_table" "job_state" {
  name         = "${var.project_name}-${var.environment}-job-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_name"

  attribute {
    name = "job_name"
    type = "S"
  }
  
  # Global secondary index for querying by status
  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    range_key       = "updated_at"
    projection_type = "ALL"
  }
  
  attribute {
    name = "status"
    type = "S"
  }
  
  attribute {
    name = "updated_at"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.enable_encryption ? (var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.glue_key[0].arn) : null
  }
  
  # TTL for automatic cleanup of old records (30 days)
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-job-state"
    Environment = var.environment
    Component   = "glue-state"
  }
}

# Glue ETL Job for data ingestion
resource "aws_glue_job" "data_ingestion" {
  name              = "${var.project_name}-${var.environment}-data-ingestion"
  role_arn          = var.glue_service_role_arn
  glue_version      = var.glue_version
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = var.job_timeout
  max_retries       = var.max_retries
  description       = "Data ingestion job for ${var.project_name} in ${var.environment} environment"

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket_name}/jobs/data_ingestion.py"
    python_version  = var.python_version
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-glue-datacatalog"          = "true"
    "--TempDir"                          = "s3://${var.temp_bucket_name}/temp/"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${var.temp_bucket_name}/sparkHistoryLogs/"
    "--raw_bucket"                       = var.raw_bucket_name
    "--processed_bucket"                 = var.processed_bucket_name
    "--environment"                      = var.environment
    "--state_table"                      = aws_dynamodb_table.job_state.name
    "--sns_topic_arn"                    = var.sns_topic_arn
    "--conf"                             = "spark.sql.adaptive.enabled=true --conf spark.sql.adaptive.coalescePartitions.enabled=true"
  }

  execution_property {
    max_concurrent_runs = var.max_concurrent_runs
  }

  # Only add connections if VPC is configured
  connections = var.subnet_id != null ? [aws_glue_connection.vpc_connection[0].name] : []
  
  # Security configuration
  security_configuration = var.enable_encryption ? aws_glue_security_configuration.main[0].name : null

  tags = {
    Name        = "${var.project_name}-${var.environment}-data-ingestion"
    Environment = var.environment
    Component   = "glue-job"
    JobType     = "ingestion"
  }
  
  depends_on = [
    aws_dynamodb_table.job_state,
    aws_dynamodb_table.job_bookmarks
  ]
}

# Glue ETL Job for data processing
resource "aws_glue_job" "data_processing" {
  name              = "${var.project_name}-${var.environment}-data-processing"
  role_arn          = var.glue_service_role_arn
  glue_version      = var.glue_version
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = var.job_timeout
  max_retries       = var.max_retries
  description       = "Data processing job for ${var.project_name} in ${var.environment} environment"

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket_name}/jobs/data_processing.py"
    python_version  = var.python_version
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-glue-datacatalog"          = "true"
    "--TempDir"                          = "s3://${var.temp_bucket_name}/temp/"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${var.temp_bucket_name}/sparkHistoryLogs/"
    "--processed_bucket"                 = var.processed_bucket_name
    "--curated_bucket"                   = var.curated_bucket_name
    "--environment"                      = var.environment
    "--state_table"                      = aws_dynamodb_table.job_state.name
    "--database_name"                    = aws_glue_catalog_database.main.name
    "--sns_topic_arn"                    = var.sns_topic_arn
    "--conf"                             = "spark.sql.adaptive.enabled=true --conf spark.sql.adaptive.coalescePartitions.enabled=true"
  }

  execution_property {
    max_concurrent_runs = var.max_concurrent_runs
  }
  
  connections = var.subnet_id != null ? [aws_glue_connection.vpc_connection[0].name] : []
  
  security_configuration = var.enable_encryption ? aws_glue_security_configuration.main[0].name : null

  tags = {
    Name        = "${var.project_name}-${var.environment}-data-processing"
    Environment = var.environment
    Component   = "glue-job"
    JobType     = "processing"
  }
  
  depends_on = [
    aws_dynamodb_table.job_state,
    aws_dynamodb_table.job_bookmarks,
    aws_glue_job.data_ingestion
  ]
}

# Glue ETL Job for data quality
resource "aws_glue_job" "data_quality" {
  name              = "${var.project_name}-${var.environment}-data-quality"
  role_arn          = var.glue_service_role_arn
  glue_version      = var.glue_version
  worker_type       = "G.1X"  # Smaller worker type for quality checks
  number_of_workers = max(2, floor(var.number_of_workers / 2))  # Use fewer workers
  timeout           = var.job_timeout
  max_retries       = var.max_retries
  description       = "Data quality validation job for ${var.project_name} in ${var.environment} environment"

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket_name}/jobs/data_quality.py"
    python_version  = var.python_version
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-disable"  # Quality checks don't need bookmarks
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-glue-datacatalog"          = "true"
    "--TempDir"                          = "s3://${var.temp_bucket_name}/temp/"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${var.temp_bucket_name}/sparkHistoryLogs/"
    "--curated_bucket"                   = var.curated_bucket_name
    "--environment"                      = var.environment
    "--state_table"                      = aws_dynamodb_table.job_state.name
    "--sns_topic_arn"                    = var.sns_topic_arn
    "--quality_rules_s3_path"            = "s3://${var.scripts_bucket_name}/config/quality_rules.json"
    "--fail_on_quality_issues"           = var.environment == "prod" ? "true" : "false"
    "--conf"                             = "spark.sql.adaptive.enabled=true --conf spark.sql.adaptive.coalescePartitions.enabled=true"
  }

  execution_property {
    max_concurrent_runs = 1  # Only one quality check at a time
  }
  
  connections = var.subnet_id != null ? [aws_glue_connection.vpc_connection[0].name] : []
  
  security_configuration = var.enable_encryption ? aws_glue_security_configuration.main[0].name : null

  tags = {
    Name        = "${var.project_name}-${var.environment}-data-quality"
    Environment = var.environment
    Component   = "glue-job"
    JobType     = "quality"
  }
  
  depends_on = [
    aws_dynamodb_table.job_state,
    aws_glue_job.data_processing
  ]
}

# Glue Workflow for orchestration
resource "aws_glue_workflow" "main" {
  name        = "${var.project_name}-${var.environment}-etl-workflow"
  description = "ETL workflow for ${var.project_name} in ${var.environment} environment"
  
  max_concurrent_runs = 1

  tags = {
    Name        = "${var.project_name}-${var.environment}-etl-workflow"
    Environment = var.environment
    Component   = "glue-workflow"
  }
}

# Trigger to start the workflow (manual or scheduled)
resource "aws_glue_trigger" "start_workflow" {
  name         = "${var.project_name}-${var.environment}-start-workflow"
  description  = "Trigger to start the ETL workflow"
  type         = var.environment == "prod" ? "SCHEDULED" : "ON_DEMAND"
  workflow_name = aws_glue_workflow.main.name
  
  # Schedule for production environment (daily at 2 AM)
  schedule = var.environment == "prod" ? "cron(0 2 * * ? *)" : null

  actions {
    crawler_name = aws_glue_crawler.raw_data.name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-start-workflow"
    Environment = var.environment
    Component   = "glue-trigger"
  }
}

# Trigger to start ingestion after crawler completes
resource "aws_glue_trigger" "start_ingestion" {
  name         = "${var.project_name}-${var.environment}-start-ingestion"
  description  = "Trigger to start data ingestion after crawler completes"
  type         = "CONDITIONAL"
  workflow_name = aws_glue_workflow.main.name

  predicate {
    conditions {
      crawler_name = aws_glue_crawler.raw_data.name
      crawl_state  = "SUCCEEDED"
    }
  }

  actions {
    job_name = aws_glue_job.data_ingestion.name
    
    arguments = {
      "--environment" = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-start-ingestion"
    Environment = var.environment
    Component   = "glue-trigger"
  }
}

# Trigger to start processing after ingestion completes
resource "aws_glue_trigger" "start_processing" {
  name         = "${var.project_name}-${var.environment}-start-processing"
  description  = "Trigger to start data processing after ingestion completes"
  type         = "CONDITIONAL"
  workflow_name = aws_glue_workflow.main.name

  predicate {
    conditions {
      job_name = aws_glue_job.data_ingestion.name
      state    = "SUCCEEDED"
    }
  }

  actions {
    job_name = aws_glue_job.data_processing.name
    
    arguments = {
      "--environment" = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-start-processing"
    Environment = var.environment
    Component   = "glue-trigger"
  }
}

# Trigger to start quality checks after processing completes
resource "aws_glue_trigger" "start_quality" {
  name         = "${var.project_name}-${var.environment}-start-quality"
  description  = "Trigger to start data quality checks after processing completes"
  type         = "CONDITIONAL"
  workflow_name = aws_glue_workflow.main.name

  predicate {
    conditions {
      job_name = aws_glue_job.data_processing.name
      state    = "SUCCEEDED"
    }
  }

  actions {
    job_name = aws_glue_job.data_quality.name
    
    arguments = {
      "--environment" = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-start-quality"
    Environment = var.environment
    Component   = "glue-trigger"
  }
}

# CloudWatch Log Groups for Glue jobs
resource "aws_cloudwatch_log_group" "glue_jobs" {
  for_each = toset([
    "data_ingestion",
    "data_processing", 
    "data_quality"
  ])
  
  name              = "/aws-glue/jobs/${var.project_name}-${var.environment}-${each.key}"
  retention_in_days = var.log_retention_days
  
  kms_key_id = null  # Disable KMS encryption for log groups to avoid permission issues

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-logs"
    Environment = var.environment
    Component   = "glue-logs"
    JobType     = each.key
  }
}
