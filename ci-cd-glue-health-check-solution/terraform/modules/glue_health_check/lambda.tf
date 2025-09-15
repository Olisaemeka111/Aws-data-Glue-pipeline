# Lambda functions for Glue Health Check orchestration

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_health_check_role" {
  count = var.deploy_lambda_functions ? 1 : 0

  name = "lambda-health-check-role-${var.job_suffix}"

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

  tags = local.common_tags
}

# IAM policy for Lambda functions
resource "aws_iam_role_policy" "lambda_health_check_policy" {
  count = var.deploy_lambda_functions ? 1 : 0

  name = "lambda-health-check-policy-${var.job_suffix}"
  role = aws_iam_role.lambda_health_check_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DeleteLogGroup"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:CreateJob",
          "glue:DeleteJob",
          "glue:GetJob",
          "glue:GetJobs",
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.scripts_bucket}/*",
          "arn:aws:s3:::${var.scripts_bucket}",
          "arn:aws:s3:::${var.temp_bucket}/*",
          "arn:aws:s3:::${var.temp_bucket}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:*health-check*"
        ]
      }
    ]
  })
}

# Attach basic execution role policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  count = var.deploy_lambda_functions ? 1 : 0

  role       = aws_iam_role.lambda_health_check_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function: Health Check Trigger
resource "aws_lambda_function" "health_check_trigger" {
  count = var.deploy_lambda_functions ? 1 : 0

  filename      = data.archive_file.trigger_lambda_zip[0].output_path
  function_name = "glue-health-check-trigger-${var.job_suffix}"
  role          = aws_iam_role.lambda_health_check_role[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60

  source_code_hash = data.archive_file.trigger_lambda_zip[0].output_base64sha256

  environment {
    variables = {
      GLUE_ROLE_ARN   = var.glue_role_arn != "" ? var.glue_role_arn : aws_iam_role.glue_health_check_role[0].arn
      SCRIPTS_BUCKET  = var.scripts_bucket
      TEMP_BUCKET     = var.temp_bucket
      SNS_TOPIC_ARN   = var.alarm_sns_topic_arn
      MAX_CAPACITY    = var.max_capacity
      TIMEOUT_MINUTES = var.timeout_minutes
    }
  }

  tags = merge(local.common_tags, {
    Name = "glue-health-check-trigger-${var.job_suffix}"
    Type = "trigger"
  })

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# Lambda function: Job Monitor
resource "aws_lambda_function" "job_monitor" {
  count = var.deploy_lambda_functions ? 1 : 0

  filename      = data.archive_file.monitor_lambda_zip[0].output_path
  function_name = "glue-health-check-monitor-${var.job_suffix}"
  role          = aws_iam_role.lambda_health_check_role[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60

  source_code_hash = data.archive_file.monitor_lambda_zip[0].output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN         = var.alarm_sns_topic_arn
      CLEANUP_FUNCTION_NAME = var.deploy_lambda_functions ? aws_lambda_function.cleanup[0].function_name : ""
      WEBHOOK_URL           = var.webhook_url
    }
  }

  tags = merge(local.common_tags, {
    Name = "glue-health-check-monitor-${var.job_suffix}"
    Type = "monitor"
  })

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# Lambda function: Cleanup
resource "aws_lambda_function" "cleanup" {
  count = var.deploy_lambda_functions ? 1 : 0

  filename      = data.archive_file.cleanup_lambda_zip[0].output_path
  function_name = "glue-health-check-cleanup-${var.job_suffix}"
  role          = aws_iam_role.lambda_health_check_role[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300 # 5 minutes for cleanup

  source_code_hash = data.archive_file.cleanup_lambda_zip[0].output_base64sha256

  environment {
    variables = {
      SCRIPTS_BUCKET  = var.scripts_bucket
      TEMP_BUCKET     = var.temp_bucket
      METADATA_BUCKET = var.logs_bucket
    }
  }

  tags = merge(local.common_tags, {
    Name = "glue-health-check-cleanup-${var.job_suffix}"
    Type = "cleanup"
  })

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# Data sources for Lambda function code
data "archive_file" "trigger_lambda_zip" {
  count = var.deploy_lambda_functions ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/lambda_trigger.zip"

  source {
    content = templatefile("${path.module}/../../../src/lambda/health_check_trigger/lambda_function.py", {
      # Template variables if needed
    })
    filename = "lambda_function.py"
  }
}

data "archive_file" "monitor_lambda_zip" {
  count = var.deploy_lambda_functions ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/lambda_monitor.zip"

  source {
    content = templatefile("${path.module}/../../../src/lambda/job_monitor/lambda_function.py", {
      # Template variables if needed
    })
    filename = "lambda_function.py"
  }
}

data "archive_file" "cleanup_lambda_zip" {
  count = var.deploy_lambda_functions ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/lambda_cleanup.zip"

  source {
    content = templatefile("${path.module}/../../../src/lambda/cleanup/lambda_function.py", {
      # Template variables if needed
    })
    filename = "lambda_function.py"
  }
}

# API Gateway for webhook integration (optional)
resource "aws_api_gateway_rest_api" "health_check_api" {
  count = var.deploy_lambda_functions && var.create_api_gateway ? 1 : 0

  name        = "glue-health-check-api-${var.job_suffix}"
  description = "API Gateway for Glue health check webhooks"

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "trigger_resource" {
  count = var.deploy_lambda_functions && var.create_api_gateway ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.health_check_api[0].id
  parent_id   = aws_api_gateway_rest_api.health_check_api[0].root_resource_id
  path_part   = "trigger"
}

resource "aws_api_gateway_method" "trigger_post" {
  count = var.deploy_lambda_functions && var.create_api_gateway ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.health_check_api[0].id
  resource_id   = aws_api_gateway_resource.trigger_resource[0].id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "trigger_lambda_integration" {
  count = var.deploy_lambda_functions && var.create_api_gateway ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.health_check_api[0].id
  resource_id = aws_api_gateway_resource.trigger_resource[0].id
  http_method = aws_api_gateway_method.trigger_post[0].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.health_check_trigger[0].invoke_arn
}

resource "aws_lambda_permission" "api_gateway_trigger" {
  count = var.deploy_lambda_functions && var.create_api_gateway ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_check_trigger[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.health_check_api[0].execution_arn}/*/*"
}

# EventBridge rule for Glue job state changes
resource "aws_cloudwatch_event_rule" "glue_job_state_change" {
  count = var.deploy_lambda_functions && var.enable_event_monitoring ? 1 : 0

  name        = "glue-health-check-state-change-${var.job_suffix}"
  description = "Capture Glue job state changes for health check jobs"

  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail-type = ["Glue Job State Change"]
    detail = {
      jobName = [{
        prefix = "glue-health-check-"
      }]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda_monitor_target" {
  count = var.deploy_lambda_functions && var.enable_event_monitoring ? 1 : 0

  rule      = aws_cloudwatch_event_rule.glue_job_state_change[0].name
  target_id = "HealthCheckMonitorTarget"
  arn       = aws_lambda_function.job_monitor[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge_monitor" {
  count = var.deploy_lambda_functions && var.enable_event_monitoring ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job_monitor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.glue_job_state_change[0].arn
} 