variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "glue_service_role_arn" {
  description = "ARN of the IAM role for AWS Glue service"
  type        = string
}

variable "raw_bucket_name" {
  description = "Name of the raw data S3 bucket"
  type        = string
}

variable "processed_bucket_name" {
  description = "Name of the processed data S3 bucket"
  type        = string
}

variable "curated_bucket_name" {
  description = "Name of the curated data S3 bucket"
  type        = string
}

variable "scripts_bucket_name" {
  description = "Name of the scripts S3 bucket"
  type        = string
}

variable "temp_bucket_name" {
  description = "Name of the temporary files S3 bucket"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet for Glue connection"
  type        = string
}

variable "subnet_availability_zone" {
  description = "Availability zone of the subnet for Glue connection"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group for Glue connection"
  type        = string
}

variable "glue_version" {
  description = "AWS Glue version"
  type        = string
  default     = "4.0"
}

variable "python_version" {
  description = "Python version for Glue jobs"
  type        = string
  default     = "3.10"
}

variable "worker_type" {
  description = "Worker type for Glue jobs"
  type        = string
  default     = "G.1X"
}

variable "number_of_workers" {
  description = "Number of workers for Glue jobs"
  type        = number
  default     = 10
}

variable "job_timeout" {
  description = "Timeout for Glue jobs in minutes"
  type        = number
  default     = 60
}

variable "max_retries" {
  description = "Maximum number of retries for Glue jobs"
  type        = number
  default     = 3
}

variable "max_concurrent_runs" {
  description = "Maximum number of concurrent runs for each Glue job"
  type        = number
  default     = 3
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
