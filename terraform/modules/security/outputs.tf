output "glue_service_role_arn" {
  description = "ARN of the IAM role for AWS Glue service"
  value       = aws_iam_role.glue_service_role.arn
}

output "glue_service_role_name" {
  description = "Name of the IAM role for AWS Glue service"
  value       = aws_iam_role.glue_service_role.name
}

output "monitoring_role_arn" {
  description = "ARN of the IAM role for monitoring"
  value       = aws_iam_role.monitoring_role.arn
}

output "monitoring_role_name" {
  description = "Name of the IAM role for monitoring"
  value       = aws_iam_role.monitoring_role.name
}

output "lambda_security_group_id" {
  description = "ID of the security group for Lambda functions"
  value       = aws_security_group.lambda_security_group.id
}

output "glue_connection_security_group_id" {
  description = "ID of the security group for AWS Glue connections"
  value       = aws_security_group.glue_connection.id
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret for Glue connections"
  value       = aws_secretsmanager_secret.glue_connections.arn
}

output "cloudwatch_logs_kms_key_arn" {
  description = "ARN of the KMS key for CloudWatch Logs encryption"
  value       = var.enable_encryption ? aws_kms_key.cloudwatch_logs[0].arn : null
}
