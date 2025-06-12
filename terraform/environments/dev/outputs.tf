output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "s3_buckets" {
  description = "S3 buckets created for the ETL pipeline"
  value = {
    raw       = module.storage.raw_bucket.name
    processed = module.storage.processed_bucket.name
    curated   = module.storage.curated_bucket.name
    scripts   = module.storage.scripts_bucket.name
    temp      = module.storage.temp_bucket.name
  }
}

output "glue_catalog_database" {
  description = "Name of the Glue Catalog Database"
  value       = module.glue.glue_catalog_database_name
}

output "glue_jobs" {
  description = "Names of the Glue jobs"
  value = {
    ingestion  = module.glue.data_ingestion_job_name
    processing = module.glue.data_processing_job_name
    quality    = module.glue.data_quality_job_name
  }
}

output "glue_workflow" {
  description = "Name of the Glue workflow"
  value       = module.glue.workflow_name
}

output "dynamodb_tables" {
  description = "DynamoDB tables for job state management"
  value = {
    bookmarks = module.glue.job_bookmarks_table_name
    state     = module.glue.job_state_table_name
  }
}

output "cloudwatch_dashboard" {
  description = "Name of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = module.monitoring.sns_topic_arn
}
