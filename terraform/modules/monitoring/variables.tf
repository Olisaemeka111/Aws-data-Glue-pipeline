variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "glue_job_names" {
  description = "List of Glue job names to monitor"
  type        = list(string)
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "alarm_email_addresses" {
  description = "List of email addresses to notify for alarms"
  type        = list(string)
  default     = []
}

variable "job_duration_threshold" {
  description = "Threshold for job duration alarm in minutes"
  type        = number
  default     = 45
}

variable "enable_encryption" {
  description = "Whether to enable KMS encryption"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  type        = string
  default     = null
}

variable "cloudwatch_logs_kms_key_arn" {
  description = "ARN of the KMS key for CloudWatch Logs encryption"
  type        = string
  default     = null
}

variable "monitoring_role_arn" {
  description = "ARN of the IAM role for monitoring"
  type        = string
}

variable "scripts_bucket_name" {
  description = "Name of the S3 bucket containing Lambda scripts"
  type        = string
}

variable "enable_enhanced_monitoring" {
  description = "Whether to enable enhanced monitoring with Lambda"
  type        = bool
  default     = true
}
