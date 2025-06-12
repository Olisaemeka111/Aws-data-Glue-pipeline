variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "glue-etl-pipeline"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "staging"
}

# Networking variables
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16"
}

# Glue job variables
variable "glue_version" {
  description = "Version of AWS Glue to use"
  type        = string
  default     = "4.0"
}

variable "python_version" {
  description = "Python version for Glue jobs"
  type        = string
  default     = "3.10"
}

variable "worker_type" {
  description = "Type of worker for Glue jobs"
  type        = string
  default     = "G.1X"
}

variable "number_of_workers" {
  description = "Number of workers for Glue jobs"
  type        = number
  default     = 5
}

variable "max_concurrent_runs" {
  description = "Maximum number of concurrent runs for each job"
  type        = number
  default     = 3
}

variable "job_timeout" {
  description = "Timeout for Glue jobs in minutes"
  type        = number
  default     = 60
}

variable "enable_job_bookmarks" {
  description = "Enable job bookmarks for Glue jobs"
  type        = bool
  default     = true
}

variable "enable_spark_ui" {
  description = "Enable Spark UI for Glue jobs"
  type        = bool
  default     = true
}

variable "enable_metrics" {
  description = "Enable CloudWatch metrics for Glue jobs"
  type        = bool
  default     = true
}

variable "enable_continuous_logging" {
  description = "Enable continuous logging for Glue jobs"
  type        = bool
  default     = true
}

# Encryption variables
variable "enable_encryption" {
  description = "Enable encryption for resources"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
  default     = ""
}

# Monitoring variables
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 90
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarms"
  type        = string
  default     = "alerts@example.com"
}

variable "job_duration_threshold" {
  description = "Threshold for job duration alarm in minutes"
  type        = number
  default     = 45
}

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring with Lambda"
  type        = bool
  default     = true
}

# Storage variables
variable "raw_data_retention_days" {
  description = "Number of days to retain raw data before moving to glacier"
  type        = number
  default     = 90
}

# Data crawler variables
variable "crawler_schedule" {
  description = "Cron schedule for Glue crawlers"
  type        = string
  default     = "cron(0 0 * * ? *)"  # Run daily at midnight
}

variable "raw_data_path_patterns" {
  description = "S3 path patterns for raw data crawlers"
  type        = list(string)
  default     = ["data/incoming/"]
}

variable "processed_data_path_patterns" {
  description = "S3 path patterns for processed data crawlers"
  type        = list(string)
  default     = ["data/processed/"]
}

variable "curated_data_path_patterns" {
  description = "S3 path patterns for curated data crawlers"
  type        = list(string)
  default     = ["data/curated/"]
}
