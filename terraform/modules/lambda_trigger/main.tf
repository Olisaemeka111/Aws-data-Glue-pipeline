/**
 * Lambda Data Trigger Module
 * 
 * This module creates a Lambda function that triggers the Glue ETL pipeline
 * when new data is detected in the source S3 bucket, with integrated security scanning.
 */

resource "aws_lambda_function" "data_trigger" {
  function_name    = "${var.project_name}-${var.environment}-data-trigger"
  description      = "Triggers Glue ETL pipeline when new data is detected, with security scanning"
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 300
  memory_size      = 256
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      GLUE_WORKFLOW_NAME = var.glue_workflow_name
      SECURITY_SNS_TOPIC = aws_sns_topic.security_alerts.arn
      SCAN_RESULTS_TABLE = aws_dynamodb_table.scan_results.name
      ENVIRONMENT        = var.environment
      MAX_FILE_SIZE_MB   = var.max_file_size_mb
      ALLOWED_FILE_TYPES = join(",", var.allowed_file_types)
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-data-trigger"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-data-trigger"
  retention_in_days = 30

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-data-trigger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lambda Basic Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda VPC Access Policy
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for Lambda to access required services
resource "aws_iam_policy" "lambda_custom_policy" {
  name        = "${var.project_name}-${var.environment}-data-trigger-policy"
  description = "Custom policy for data trigger Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:HeadObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.source_bucket}",
          "arn:aws:s3:::${var.source_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartWorkflowRun",
          "glue:GetWorkflow"
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:workflow/${var.glue_workflow_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.security_alerts.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.scan_results.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "securityhub:BatchImportFindings"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          var.kms_key_arn
        ]
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach custom policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_custom_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_custom_policy.arn
}

# S3 Event Notification to trigger Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.source_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.data_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.source_prefix
    filter_suffix       = ""
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.source_bucket}"
}

# SNS Topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name              = "${var.project_name}-${var.environment}-security-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "security_alerts_policy" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "SNS:Publish",
          "SNS:Subscribe"
        ]
        Resource = aws_sns_topic.security_alerts.arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = var.aws_account_id
          }
        }
      }
    ]
  })
}

# DynamoDB Table for scan results
resource "aws_dynamodb_table" "scan_results" {
  name         = "${var.project_name}-${var.environment}-security-scan-results"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "scan_id"
  range_key    = "timestamp"

  attribute {
    name = "scan_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "file_key"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name               = "FileKeyIndex"
    hash_key           = "file_key"
    range_key          = "timestamp"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "StatusIndex"
    hash_key           = "status"
    range_key          = "timestamp"
    projection_type    = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Alarms for security monitoring
resource "aws_cloudwatch_metric_alarm" "blocked_files_alarm" {
  alarm_name          = "${var.project_name}-${var.environment}-blocked-files-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedFiles"
  namespace           = "GlueETLPipeline"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.blocked_files_threshold
  alarm_description   = "This alarm monitors for excessive blocked files due to security issues"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    Environment = var.environment
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Security Hub integration
resource "aws_securityhub_account" "security_hub" {
  count = var.enable_security_hub ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count            = var.enable_security_hub ? 1 : 0
  standards_arn    = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on       = [aws_securityhub_account.security_hub]
}

# CloudWatch Dashboard for security monitoring
resource "aws_cloudwatch_dashboard" "security_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-security-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["GlueETLPipeline", "BlockedFiles", "Environment", var.environment]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Blocked Files"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["GlueETLPipeline", "SecurityScanCount", "Environment", var.environment, "Result", "CLEAN"],
            ["GlueETLPipeline", "SecurityScanCount", "Environment", var.environment, "Result", "WARNING"],
            ["GlueETLPipeline", "SecurityScanCount", "Environment", var.environment, "Result", "BLOCKED"]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Security Scan Results"
        }
      }
    ]
  })
}
