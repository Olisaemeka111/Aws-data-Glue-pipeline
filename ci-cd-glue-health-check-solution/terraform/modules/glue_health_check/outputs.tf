# Outputs for Glue Health Check Terraform Module

# Job Information
output "health_check_job_name" {
  description = "Name of the created health check Glue job"
  value       = var.is_health_check ? aws_glue_job.health_check[0].name : null
}

output "health_check_job_arn" {
  description = "ARN of the created health check Glue job"
  value       = var.is_health_check ? aws_glue_job.health_check[0].arn : null
}

output "job_suffix" {
  description = "Unique suffix used for the health check job"
  value       = var.job_suffix
}

# IAM Information
output "glue_role_arn" {
  description = "ARN of the IAM role used by the Glue job"
  value = var.glue_role_arn != "" ? var.glue_role_arn : (
    var.is_health_check && length(aws_iam_role.glue_health_check_role) > 0 ?
    aws_iam_role.glue_health_check_role[0].arn : null
  )
}

output "glue_role_name" {
  description = "Name of the IAM role used by the Glue job"
  value = var.glue_role_arn != "" ? split("/", var.glue_role_arn)[1] : (
    var.is_health_check && length(aws_iam_role.glue_health_check_role) > 0 ?
    aws_iam_role.glue_health_check_role[0].name : null
  )
}

# CloudWatch Information
output "log_group_name" {
  description = "Name of the CloudWatch log group for the health check job"
  value       = var.is_health_check ? aws_cloudwatch_log_group.health_check_logs[0].name : null
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for the health check job"
  value       = var.is_health_check ? aws_cloudwatch_log_group.health_check_logs[0].arn : null
}

# Monitoring Information
output "alarm_name" {
  description = "Name of the CloudWatch alarm for job failures"
  value       = var.is_health_check && var.enable_alarms ? aws_cloudwatch_metric_alarm.job_failure_alarm[0].alarm_name : null
}

output "alarm_arn" {
  description = "ARN of the CloudWatch alarm for job failures"
  value       = var.is_health_check && var.enable_alarms ? aws_cloudwatch_metric_alarm.job_failure_alarm[0].arn : null
}

# S3 Information
output "scripts_bucket_name" {
  description = "Name of the S3 bucket for scripts (if created)"
  value       = var.create_scripts_bucket ? aws_s3_bucket.scripts_bucket[0].bucket : var.scripts_bucket
}

output "scripts_bucket_arn" {
  description = "ARN of the S3 bucket for scripts (if created)"
  value       = var.create_scripts_bucket ? aws_s3_bucket.scripts_bucket[0].arn : null
}

# Job Configuration
output "script_location" {
  description = "S3 location of the Glue script being tested"
  value       = var.script_location
}

output "max_capacity" {
  description = "Maximum capacity (DPU) allocated for the health check job"
  value       = var.max_capacity
}

output "timeout_minutes" {
  description = "Timeout in minutes for the health check job"
  value       = var.timeout_minutes
}

output "glue_version" {
  description = "AWS Glue version used for the health check job"
  value       = var.glue_version
}

# Resource Tags
output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}

# Health Check Status
output "is_health_check_deployment" {
  description = "Whether this is a health check deployment"
  value       = var.is_health_check
}

# Environment Information
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

output "aws_account_id" {
  description = "AWS account ID where resources are deployed"
  value       = data.aws_caller_identity.current.account_id
}

# Job Commands for Manual Execution
output "start_job_command" {
  description = "AWS CLI command to start the health check job manually"
  value = var.is_health_check ? join(" ", [
    "aws glue start-job-run",
    "--job-name ${aws_glue_job.health_check[0].name}",
    "--arguments '{\"--health-check-mode\":\"true\",\"--stub-data-sources\":\"true\",\"--dry-run\":\"true\"}'"
  ]) : null
}

output "get_job_status_command" {
  description = "AWS CLI command to get job status"
  value = var.is_health_check ? join(" ", [
    "aws glue get-job-runs",
    "--job-name ${aws_glue_job.health_check[0].name}",
    "--max-results 1"
  ]) : null
}

output "view_logs_command" {
  description = "AWS CLI command to view CloudWatch logs"
  value = var.is_health_check ? join(" ", [
    "aws logs describe-log-streams",
    "--log-group-name ${aws_cloudwatch_log_group.health_check_logs[0].name}"
  ]) : null
}

# Cleanup Information
output "cleanup_commands" {
  description = "Commands to manually cleanup health check resources"
  value = var.is_health_check ? {
    delete_job       = "aws glue delete-job --job-name ${aws_glue_job.health_check[0].name}"
    delete_log_group = "aws logs delete-log-group --log-group-name ${aws_cloudwatch_log_group.health_check_logs[0].name}"
    delete_alarm     = var.enable_alarms ? "aws cloudwatch delete-alarms --alarm-names ${aws_cloudwatch_metric_alarm.job_failure_alarm[0].alarm_name}" : "No alarm to delete"
  } : {}
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of health check configuration"
  value = var.is_health_check ? {
    job_name        = aws_glue_job.health_check[0].name
    max_capacity    = var.max_capacity
    timeout_minutes = var.timeout_minutes
    glue_version    = var.glue_version
    script_location = var.script_location
    environment     = var.environment
    enable_alarms   = var.enable_alarms
    dry_run_only    = var.dry_run_only
  } : {}
}

# Validation Results
output "validation_results" {
  description = "Validation results for the configuration"
  value = {
    job_suffix_length      = length(var.job_suffix)
    script_location_valid  = can(regex("^s3://", var.script_location))
    timeout_within_limits  = var.timeout_minutes >= 1 && var.timeout_minutes <= 2880
    capacity_within_limits = var.max_capacity >= 2 && var.max_capacity <= 100
    glue_version_supported = contains(["1.0", "2.0", "3.0", "4.0"], var.glue_version)
  }
}

# Resource Count
output "resource_count" {
  description = "Number of resources created by this module"
  value = {
    glue_jobs  = var.is_health_check ? 1 : 0
    iam_roles  = var.glue_role_arn == "" ? 1 : 0
    log_groups = var.is_health_check ? 1 : 0
    alarms     = var.is_health_check && var.enable_alarms ? 1 : 0
    s3_buckets = var.create_scripts_bucket ? 1 : 0
  }
}

# Lambda Function Information
output "lambda_trigger_function_name" {
  description = "Name of the health check trigger Lambda function"
  value       = var.deploy_lambda_functions ? aws_lambda_function.health_check_trigger[0].function_name : null
}

output "lambda_trigger_function_arn" {
  description = "ARN of the health check trigger Lambda function"
  value       = var.deploy_lambda_functions ? aws_lambda_function.health_check_trigger[0].arn : null
}

output "lambda_monitor_function_name" {
  description = "Name of the job monitor Lambda function"
  value       = var.deploy_lambda_functions ? aws_lambda_function.job_monitor[0].function_name : null
}

output "lambda_monitor_function_arn" {
  description = "ARN of the job monitor Lambda function"
  value       = var.deploy_lambda_functions ? aws_lambda_function.job_monitor[0].arn : null
}

output "lambda_cleanup_function_name" {
  description = "Name of the cleanup Lambda function"
  value       = var.deploy_lambda_functions ? aws_lambda_function.cleanup[0].function_name : null
}

output "lambda_cleanup_function_arn" {
  description = "ARN of the cleanup Lambda function"
  value       = var.deploy_lambda_functions ? aws_lambda_function.cleanup[0].arn : null
}

# API Gateway Information
output "api_gateway_url" {
  description = "API Gateway endpoint URL for webhook integration"
  value       = var.deploy_lambda_functions && var.create_api_gateway ? aws_api_gateway_rest_api.health_check_api[0].execution_arn : null
}

# Integration Commands
output "trigger_health_check_command" {
  description = "AWS CLI command to trigger health check manually"
  value = var.deploy_lambda_functions ? join(" ", [
    "aws lambda invoke",
    "--function-name ${aws_lambda_function.health_check_trigger[0].function_name}",
    "--payload '{\"pr_number\":\"123\",\"script_location\":\"s3://bucket/script.py\"}'",
    "response.json"
  ]) : null
}

output "monitor_job_command" {
  description = "AWS CLI command to monitor job status manually"
  value = var.deploy_lambda_functions ? join(" ", [
    "aws lambda invoke",
    "--function-name ${aws_lambda_function.job_monitor[0].function_name}",
    "--payload '{\"job_name\":\"${local.job_name}\"}'",
    "response.json"
  ]) : null
}

output "cleanup_command" {
  description = "AWS CLI command to trigger cleanup manually"
  value = var.deploy_lambda_functions ? join(" ", [
    "aws lambda invoke",
    "--function-name ${aws_lambda_function.cleanup[0].function_name}",
    "--payload '{\"job_name\":\"${local.job_name}\"}'",
    "response.json"
  ]) : null
} 