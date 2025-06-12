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

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "raw_bucket_arn" {
  description = "ARN of the raw data S3 bucket"
  type        = string
}

variable "processed_bucket_arn" {
  description = "ARN of the processed data S3 bucket"
  type        = string
}

variable "curated_bucket_arn" {
  description = "ARN of the curated data S3 bucket"
  type        = string
}

variable "scripts_bucket_arn" {
  description = "ARN of the scripts S3 bucket"
  type        = string
}

variable "temp_bucket_arn" {
  description = "ARN of the temporary files S3 bucket"
  type        = string
}

variable "dynamodb_table_arns" {
  description = "ARNs of DynamoDB tables used by Glue jobs"
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "ARNs of KMS keys used for encryption"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  type        = string
  default     = null
}

variable "sns_topic_arns" {
  description = "ARNs of SNS topics for notifications"
  type        = list(string)
  default     = []
}

variable "enable_encryption" {
  description = "Whether to enable KMS encryption"
  type        = bool
  default     = true
}
