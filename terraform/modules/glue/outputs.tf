output "glue_catalog_database_name" {
  description = "Name of the Glue Catalog Database"
  value       = aws_glue_catalog_database.main.name
}

output "glue_connection_name" {
  description = "Name of the Glue VPC Connection"
  value       = length(aws_glue_connection.vpc_connection) > 0 ? aws_glue_connection.vpc_connection[0].name : null
}

output "glue_crawler_name" {
  description = "Name of the Glue Crawler"
  value       = aws_glue_crawler.raw_data.name
}

output "job_bookmarks_table_name" {
  description = "Name of the DynamoDB table for job bookmarks"
  value       = aws_dynamodb_table.job_bookmarks.name
}

output "job_state_table_name" {
  description = "Name of the DynamoDB table for job state management"
  value       = aws_dynamodb_table.job_state.name
}

output "data_ingestion_job_name" {
  description = "Name of the data ingestion Glue job"
  value       = aws_glue_job.data_ingestion.name
}

output "data_processing_job_name" {
  description = "Name of the data processing Glue job"
  value       = aws_glue_job.data_processing.name
}

output "data_quality_job_name" {
  description = "Name of the data quality Glue job"
  value       = aws_glue_job.data_quality.name
}

output "workflow_name" {
  description = "Name of the Glue workflow"
  value       = aws_glue_workflow.main.name
}

output "workflow_triggers" {
  description = "Names of the Glue workflow triggers"
  value = {
    start_ingestion = aws_glue_trigger.start_ingestion.name
    start_quality   = aws_glue_trigger.start_quality.name
    start_processing = aws_glue_trigger.start_processing.name
  }
}
