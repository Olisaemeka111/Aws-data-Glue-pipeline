# Variables for Glue Health Check Terraform Module

# Required variables
variable "job_suffix" {
  description = "Unique suffix for health check job (e.g., PR number + timestamp)"
  type        = string

  validation {
    condition     = length(var.job_suffix) > 0 && length(var.job_suffix) <= 50
    error_message = "Job suffix must be between 1 and 50 characters."
  }
}

variable "is_health_check" {
  description = "Flag to indicate this is a health check deployment"
  type        = bool
  default     = false
}

variable "script_location" {
  description = "S3 location of the Glue script to test"
  type        = string

  validation {
    condition     = can(regex("^s3://", var.script_location))
    error_message = "Script location must be a valid S3 URL starting with s3://."
  }
}

# IAM Configuration
variable "glue_role_arn" {
  description = "ARN of existing IAM role for Glue job (if empty, a new role will be created)"
  type        = string
  default     = ""
}

# Job Configuration
variable "glue_version" {
  description = "AWS Glue version to use"
  type        = string
  default     = "4.0"

  validation {
    condition     = contains(["1.0", "2.0", "3.0", "4.0"], var.glue_version)
    error_message = "Glue version must be one of: 1.0, 2.0, 3.0, 4.0."
  }
}

variable "max_capacity" {
  description = "Maximum number of DPU (Data Processing Units) for the job"
  type        = number
  default     = 2

  validation {
    condition     = var.max_capacity >= 2 && var.max_capacity <= 100
    error_message = "Max capacity must be between 2 and 100 DPU."
  }
}

variable "timeout_minutes" {
  description = "Job timeout in minutes"
  type        = number
  default     = 30

  validation {
    condition     = var.timeout_minutes >= 1 && var.timeout_minutes <= 2880
    error_message = "Timeout must be between 1 and 2880 minutes (48 hours)."
  }
}

variable "custom_job_arguments" {
  description = "Custom job arguments to merge with default health check arguments"
  type        = map(string)
  default     = {}
}

# S3 Configuration
variable "scripts_bucket" {
  description = "S3 bucket name for storing Glue scripts"
  type        = string
  default     = "glue-health-check-scripts"
}

variable "temp_bucket" {
  description = "S3 bucket name for temporary files"
  type        = string
  default     = "glue-health-check-temp"
}

variable "logs_bucket" {
  description = "S3 bucket name for logs"
  type        = string
  default     = "glue-health-check-logs"
}

variable "create_scripts_bucket" {
  description = "Whether to create the scripts S3 bucket"
  type        = bool
  default     = false
}

# Network Configuration
variable "connections" {
  description = "List of connection names for the job"
  type        = list(string)
  default     = []
}

variable "security_configuration" {
  description = "Name of the security configuration to use for the job"
  type        = string
  default     = ""
}

# Monitoring Configuration
variable "enable_alarms" {
  description = "Whether to create CloudWatch alarms for the health check job"
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = ""
}

# Worker Configuration (for Glue 2.0+)
variable "worker_type" {
  description = "Type of predefined worker (G.1X, G.2X, G.025X, etc.)"
  type        = string
  default     = ""

  validation {
    condition = var.worker_type == "" || contains([
      "Standard", "G.1X", "G.2X", "G.025X", "G.4X", "G.8X"
    ], var.worker_type)
    error_message = "Worker type must be one of: Standard, G.1X, G.2X, G.025X, G.4X, G.8X."
  }
}

variable "number_of_workers" {
  description = "Number of workers for the job (used with worker_type)"
  type        = number
  default     = 0

  validation {
    condition     = var.number_of_workers >= 0
    error_message = "Number of workers must be non-negative."
  }
}

# Environment Configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "health-check"

  validation {
    condition     = contains(["dev", "staging", "prod", "health-check"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, health-check."
  }
}

# Additional Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Retention Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

# Health Check Specific Configuration
variable "stub_data_size" {
  description = "Size of stub data to generate (small, medium, large)"
  type        = string
  default     = "small"

  validation {
    condition     = contains(["small", "medium", "large"], var.stub_data_size)
    error_message = "Stub data size must be one of: small, medium, large."
  }
}

variable "enable_spark_ui" {
  description = "Whether to enable Spark UI for the health check job"
  type        = bool
  default     = true
}

variable "enable_continuous_logging" {
  description = "Whether to enable continuous CloudWatch logging"
  type        = bool
  default     = true
}

# Resource Naming
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "glue-health-check"

  validation {
    condition     = length(var.name_prefix) <= 30
    error_message = "Name prefix must be 30 characters or less."
  }
}

# Performance Configuration
variable "enable_auto_scaling" {
  description = "Whether to enable auto scaling for the job"
  type        = bool
  default     = false
}

variable "max_retries" {
  description = "Maximum number of retries for the job"
  type        = number
  default     = 0

  validation {
    condition     = var.max_retries >= 0 && var.max_retries <= 10
    error_message = "Max retries must be between 0 and 10."
  }
}

# Development Configuration
variable "enable_debug_mode" {
  description = "Whether to enable debug mode for health check"
  type        = bool
  default     = false
}

variable "dry_run_only" {
  description = "Whether to run only in dry-run mode (no actual processing)"
  type        = bool
  default     = true
}

# Lambda Function Configuration
variable "deploy_lambda_functions" {
  description = "Whether to deploy Lambda functions for orchestration"
  type        = bool
  default     = true
}

variable "create_api_gateway" {
  description = "Whether to create API Gateway for webhook integration"
  type        = bool
  default     = false
}

variable "enable_event_monitoring" {
  description = "Whether to enable EventBridge monitoring of Glue job state changes"
  type        = bool
  default     = true
}

variable "webhook_url" {
  description = "Webhook URL for CI/CD integration notifications"
  type        = string
  default     = ""
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.9"

  validation {
    condition     = contains(["python3.8", "python3.9", "python3.10"], var.lambda_runtime)
    error_message = "Lambda runtime must be python3.8, python3.9, or python3.10."
  }
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60

  validation {
    condition     = var.lambda_timeout >= 3 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 3 and 900 seconds."
  }
} 