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

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "glue-etl-pipeline"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
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
  default     = "G.2X"
}

variable "glue_number_of_workers" {
  description = "Default number of workers for Glue jobs"
  type        = number
  default     = 20
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
  default     = ["admin@example.com", "operations@example.com"]
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 90
}

variable "enable_cross_region_replication" {
  description = "Whether to enable cross-region replication for S3 buckets"
  type        = bool
  default     = true
}

variable "enable_disaster_recovery" {
  description = "Whether to enable disaster recovery configuration"
  type        = bool
  default     = true
}
