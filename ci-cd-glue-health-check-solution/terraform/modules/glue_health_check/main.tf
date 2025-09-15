# Terraform module for Glue Health Check Infrastructure
# This module creates temporary Glue jobs for CI/CD health checks

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

# Data sources for existing resources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values for resource naming and tagging
locals {
  common_tags = {
    Environment = "health-check"
    Purpose     = "ci-cd-validation"
    AutoDelete  = "true"
    CreatedBy   = "terraform"
    JobSuffix   = var.job_suffix
    Timestamp   = timestamp()
  }

  job_name = "glue-health-check-${var.job_suffix}"

  # Default arguments for health check jobs
  default_job_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-disable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${var.logs_bucket}/spark-logs/"
    "--health-check-mode"                = "true"
    "--stub-data-sources"                = "true"
    "--dry-run"                          = "true"
    "--TempDir"                          = "s3://${var.temp_bucket}/glue-temp/"
  }
}

# IAM role for Glue health check job (if not provided)
resource "aws_iam_role" "glue_health_check_role" {
  count = var.glue_role_arn == "" ? 1 : 0

  name = "glue-health-check-role-${var.job_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for health check role
resource "aws_iam_role_policy" "glue_health_check_policy" {
  count = var.glue_role_arn == "" ? 1 : 0

  name = "glue-health-check-policy-${var.job_suffix}"
  role = aws_iam_role.glue_health_check_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.scripts_bucket}/*",
          "arn:aws:s3:::${var.temp_bucket}/*",
          "arn:aws:s3:::${var.logs_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.scripts_bucket}",
          "arn:aws:s3:::${var.temp_bucket}",
          "arn:aws:s3:::${var.logs_bucket}"
        ]
      }
    ]
  })
}

# Attach AWS managed policy for Glue service role
resource "aws_iam_role_policy_attachment" "glue_service_role" {
  count = var.glue_role_arn == "" ? 1 : 0

  role       = aws_iam_role.glue_health_check_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# CloudWatch Log Group for health check job
resource "aws_cloudwatch_log_group" "health_check_logs" {
  count = var.is_health_check ? 1 : 0

  name              = "/aws-glue/health-check/${local.job_name}"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "glue-health-check-logs-${var.job_suffix}"
  })
}

# Main Glue job for health check
resource "aws_glue_job" "health_check" {
  count = var.is_health_check ? 1 : 0

  name         = local.job_name
  description  = "Temporary health check job for PR ${var.job_suffix} - CI/CD validation"
  role_arn     = var.glue_role_arn != "" ? var.glue_role_arn : aws_iam_role.glue_health_check_role[0].arn
  glue_version = var.glue_version

  command {
    script_location = var.script_location
    python_version  = "3"
    name            = "glueetl"
  }

  # Merge default arguments with custom ones
  default_arguments = merge(
    local.default_job_arguments,
    var.custom_job_arguments
  )

  # Resource configuration
  max_capacity = var.max_capacity
  timeout      = var.timeout_minutes

  # Worker configuration (for Glue 2.0+)
  dynamic "execution_property" {
    for_each = var.glue_version != "1.0" ? [1] : []
    content {
      max_concurrent_runs = 1
    }
  }

  # Connections (if any)
  connections = length(var.connections) > 0 ? var.connections : null

  # Security configuration
  security_configuration = var.security_configuration

  tags = merge(local.common_tags, {
    Name = local.job_name
    Type = "health-check"
  })

  depends_on = [
    aws_cloudwatch_log_group.health_check_logs,
    aws_iam_role_policy.glue_health_check_policy,
    aws_iam_role_policy_attachment.glue_service_role
  ]
}

# CloudWatch metric alarm for job failures
resource "aws_cloudwatch_metric_alarm" "job_failure_alarm" {
  count = var.is_health_check && var.enable_alarms ? 1 : 0

  alarm_name          = "glue-health-check-${var.job_suffix}-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "AWS/Glue"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Health check job failure alarm for ${local.job_name}"

  dimensions = {
    JobName = local.job_name
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = merge(local.common_tags, {
    Name = "glue-health-check-alarm-${var.job_suffix}"
  })
}

# S3 bucket for scripts (if needed)
resource "aws_s3_bucket" "scripts_bucket" {
  count = var.create_scripts_bucket ? 1 : 0

  bucket = "glue-health-check-scripts-${random_id.bucket_suffix[0].hex}"

  tags = merge(local.common_tags, {
    Name = "glue-health-check-scripts"
  })
}

resource "random_id" "bucket_suffix" {
  count = var.create_scripts_bucket ? 1 : 0

  byte_length = 4
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "scripts_bucket_versioning" {
  count = var.create_scripts_bucket ? 1 : 0

  bucket = aws_s3_bucket.scripts_bucket[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "scripts_bucket_lifecycle" {
  count = var.create_scripts_bucket ? 1 : 0

  bucket = aws_s3_bucket.scripts_bucket[0].id

  rule {
    id     = "health_check_cleanup"
    status = "Enabled"

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 3
    }

    filter {
      prefix = "health-check/"
    }
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "scripts_bucket_pab" {
  count = var.create_scripts_bucket ? 1 : 0

  bucket = aws_s3_bucket.scripts_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
} 