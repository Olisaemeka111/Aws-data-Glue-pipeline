output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of NAT gateways"
  value       = module.networking.nat_gateway_ids
}

output "vpc_endpoint_s3_id" {
  description = "ID of VPC endpoint for S3"
  value       = module.networking.vpc_endpoint_s3_id
}

output "vpc_endpoint_dynamodb_id" {
  description = "ID of VPC endpoint for DynamoDB"
  value       = module.networking.vpc_endpoint_dynamodb_id
}

output "raw_bucket_name" {
  description = "Name of the raw data bucket"
  value       = module.storage.raw_bucket_name
}

output "processed_bucket_name" {
  description = "Name of the processed data bucket"
  value       = module.storage.processed_bucket_name
}

output "curated_bucket_name" {
  description = "Name of the curated data bucket"
  value       = module.storage.curated_bucket_name
}

output "scripts_bucket_name" {
  description = "Name of the scripts bucket"
  value       = module.storage.scripts_bucket_name
}

output "temp_bucket_name" {
  description = "Name of the temporary data bucket"
  value       = module.storage.temp_bucket_name
}

output "glue_catalog_database_name" {
  description = "Name of the Glue catalog database"
  value       = module.storage.glue_catalog_database_name
}

output "glue_raw_crawler_name" {
  description = "Name of the Glue crawler for raw data"
  value       = module.storage.raw_data_crawler_name
}

output "glue_processed_crawler_name" {
  description = "Name of the Glue crawler for processed data"
  value       = module.storage.processed_data_crawler_name
}

output "glue_curated_crawler_name" {
  description = "Name of the Glue crawler for curated data"
  value       = module.storage.curated_data_crawler_name
}

output "glue_job_names" {
  description = "Names of Glue jobs"
  value       = module.glue.glue_job_names
}

output "glue_workflow_name" {
  description = "Name of the Glue workflow"
  value       = module.glue.glue_workflow_name
}

output "job_state_table_name" {
  description = "Name of the DynamoDB table for job state"
  value       = module.glue.job_state_table_name
}

output "job_bookmark_table_name" {
  description = "Name of the DynamoDB table for job bookmarks"
  value       = module.glue.job_bookmark_table_name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = module.monitoring.cloudwatch_log_group_name
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.monitoring.cloudwatch_dashboard_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "monitoring_lambda_function_name" {
  description = "Name of the monitoring Lambda function"
  value       = module.monitoring.monitoring_lambda_function_name
}
