variable "aws_region" {
  description = "The AWS region to deploy resources"
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
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways for private subnets"
  type        = bool
  default     = true
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
}

variable "glue_number_of_workers" {
  description = "Default number of workers for Glue jobs"
  type        = number
  default     = 5
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
  default     = ["admin@example.com"]
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

# Lambda Data Trigger variables
variable "lambda_zip_path" {
  description = "Path to the Lambda function ZIP file"
  type        = string
  default     = "../build/lambda/data_trigger_lambda.zip"
}

variable "max_file_size_mb" {
  description = "Maximum allowed file size in MB for security scanning"
  type        = number
  default     = 100
}

variable "allowed_file_types" {
  description = "List of allowed file extensions for security scanning"
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

variable "raw_data_path_patterns" {
  description = "List of S3 path patterns to monitor for new data"
  type        = list(string)
  default     = ["data/incoming/*"]
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarms"
  type        = string
  default     = "admin@example.com"
}

variable "max_concurrent_runs" {
  description = "Maximum number of concurrent runs for Glue jobs"
  type        = number
  default     = 1
}

variable "enable_job_bookmarks" {
  description = "Whether to enable job bookmarks for Glue jobs"
  type        = bool
  default     = true
}

variable "enable_spark_ui" {
  description = "Whether to enable Spark UI for Glue jobs"
  type        = bool
  default     = true
}

variable "enable_metrics" {
  description = "Whether to enable metrics for Glue jobs"
  type        = bool
  default     = true
}

variable "enable_continuous_logging" {
  description = "Whether to enable continuous logging for Glue jobs"
  type        = bool
  default     = true
}

variable "job_duration_threshold" {
  description = "Threshold in minutes for job duration alarms"
  type        = number
  default     = 20
}

variable "enable_enhanced_monitoring" {
  description = "Whether to enable enhanced monitoring for Glue jobs"
  type        = bool
  default     = true
}

variable "raw_data_retention_days" {
  description = "Number of days to retain raw data"
  type        = number
  default     = 30
}

variable "crawler_schedule" {
  description = "Schedule expression for Glue crawlers"
  type        = string
  default     = "cron(0 1 * * ? *)"
}

variable "processed_data_path_patterns" {
  description = "List of S3 path patterns for processed data"
  type        = list(string)
  default     = ["data/processed/"]
}

variable "curated_data_path_patterns" {
  description = "List of S3 path patterns for curated data"
  type        = list(string)
  default     = ["data/curated/"]
}

variable "enable_encryption" {
  description = "Whether to enable encryption for resources"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for encryption"
  type        = string
  default     = ""
}

variable "number_of_workers" {
  description = "Number of workers for Glue jobs"
  type        = number
  default     = 2
}

variable "worker_type" {
  description = "The type of workers for Glue jobs"
  type        = string
  default     = "G.1X"
}

variable "job_timeout" {
  description = "The timeout for Glue jobs in minutes"
  type        = number
  default     = 30
}
