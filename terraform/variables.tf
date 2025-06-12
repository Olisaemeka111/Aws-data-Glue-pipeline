variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for disaster recovery"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "glue-etl-pipeline"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_vpc_endpoints" {
  description = "Whether to create VPC endpoints for AWS services"
  type        = bool
  default     = true
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

variable "glue_job_timeout" {
  description = "Default timeout for Glue jobs in minutes"
  type        = number
  default     = 60
}

variable "glue_job_max_retries" {
  description = "Default number of retries for Glue jobs"
  type        = number
  default     = 3
}

variable "glue_worker_type" {
  description = "Default worker type for Glue jobs"
  type        = string
  default     = "G.1X"
  validation {
    condition     = contains(["G.1X", "G.2X", "G.4X", "G.8X", "Standard"], var.glue_worker_type)
    error_message = "Worker type must be one of: G.1X, G.2X, G.4X, G.8X, Standard."
  }
}

variable "glue_number_of_workers" {
  description = "Default number of workers for Glue jobs"
  type        = number
  default     = 10
}

variable "s3_data_bucket_prefix" {
  description = "Prefix for S3 data buckets"
  type        = string
  default     = "data"
}

variable "enable_data_encryption" {
  description = "Whether to enable KMS encryption for data at rest"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Whether to enable enhanced monitoring"
  type        = bool
  default     = true
}

variable "alarm_email_addresses" {
  description = "List of email addresses to notify for alarms"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
