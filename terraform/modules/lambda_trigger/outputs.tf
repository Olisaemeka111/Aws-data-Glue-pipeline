/**
 * Outputs for Lambda Data Trigger Module
 */

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.data_trigger.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.data_trigger.function_name
}

output "security_alerts_topic_arn" {
  description = "ARN of the SNS topic for security alerts"
  value       = aws_sns_topic.security_alerts.arn
}

output "scan_results_table_name" {
  description = "Name of the DynamoDB table for scan results"
  value       = aws_dynamodb_table.scan_results.name
}

output "scan_results_table_arn" {
  description = "ARN of the DynamoDB table for scan results"
  value       = aws_dynamodb_table.scan_results.arn
}

output "security_dashboard_name" {
  description = "Name of the CloudWatch dashboard for security monitoring"
  value       = aws_cloudwatch_dashboard.security_dashboard.dashboard_name
}
