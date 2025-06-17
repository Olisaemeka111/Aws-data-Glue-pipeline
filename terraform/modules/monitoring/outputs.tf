output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for Glue logs"
  value       = aws_cloudwatch_log_group.glue_logs.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.glue_dashboard.dashboard_name
}

output "job_failure_alarms" {
  description = "Map of job failure CloudWatch alarms"
  value       = { for job_name in ["data-ingestion", "data-processing", "data-quality"] : job_name => aws_cloudwatch_metric_alarm.job_failure[job_name].arn }
}

output "job_duration_alarms" {
  description = "Map of job duration CloudWatch alarms"
  value       = { for job_name in ["data-ingestion", "data-processing", "data-quality"] : job_name => aws_cloudwatch_metric_alarm.job_duration[job_name].arn }
}

output "monitoring_lambda_arn" {
  description = "ARN of the monitoring Lambda function"
  value       = var.enable_enhanced_monitoring ? aws_lambda_function.monitoring[0].arn : null
}
