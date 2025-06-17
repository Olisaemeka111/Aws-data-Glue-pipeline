variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "bucket_prefix" {
  description = "Prefix for S3 bucket names"
  type        = string
}

variable "enable_encryption" {
  description = "Whether to enable KMS encryption for S3 buckets"
  type        = bool
  default     = true
}

variable "enable_replication" {
  description = "Whether to enable cross-region replication for critical data"
  type        = bool
  default     = false
}

variable "replication_region" {
  description = "Region to replicate data to if replication is enabled"
  type        = string
  default     = null
}

# Glue Data Catalog and Crawler variables
variable "create_glue_catalog_database" {
  description = "Whether to create a Glue Data Catalog database"
  type        = bool
  default     = true
}

variable "create_glue_catalog" {
  description = "Whether to create a Glue Data Catalog"
  type        = bool
  default     = true
}

variable "create_glue_crawlers" {
  description = "Whether to create Glue crawlers for data discovery"
  type        = bool
  default     = true
}

variable "crawler_schedule" {
  description = "Cron schedule for Glue crawlers"
  type        = string
  default     = "cron(0 0 * * ? *)"
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

# VPC configuration for crawlers
variable "vpc_id" {
  description = "VPC ID for Glue crawlers"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for Glue crawlers"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security group IDs for Glue crawlers"
  type        = list(string)
  default     = []
}
