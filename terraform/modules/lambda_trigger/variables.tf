/**
 * Variables for Lambda Data Trigger Module
 */

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

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the Lambda function ZIP file"
  type        = string
}

variable "source_bucket" {
  description = "S3 bucket that contains the source data"
  type        = string
}

variable "source_prefix" {
  description = "Prefix for the source data in the S3 bucket"
  type        = string
  default     = ""
}

variable "glue_workflow_name" {
  description = "Name of the Glue workflow to trigger"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Lambda function VPC configuration"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the Lambda function VPC configuration"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "max_file_size_mb" {
  description = "Maximum allowed file size in MB"
  type        = number
  default     = 100
}

variable "allowed_file_types" {
  description = "List of allowed file extensions"
  type        = list(string)
  default     = ["csv", "json", "parquet", "avro"]
}

variable "blocked_files_threshold" {
  description = "Threshold for blocked files alarm"
  type        = number
  default     = 5
}

variable "enable_security_hub" {
  description = "Whether to enable Security Hub integration"
  type        = bool
  default     = true
}
