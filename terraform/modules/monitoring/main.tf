resource "aws_cloudwatch_log_group" "glue_logs" {
  name              = "/aws-glue/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_encryption ? var.cloudwatch_logs_kms_key_arn : null

  tags = {
    Name        = "${var.project_name}-${var.environment}-glue-logs"
    Environment = var.environment
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
  
  kms_master_key_id = var.enable_encryption ? var.kms_key_arn : null
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-alerts"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = length(var.alarm_email_addresses)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email_addresses[count.index]
}

# CloudWatch Alarms for Glue Jobs
resource "aws_cloudwatch_metric_alarm" "job_failure" {
  for_each            = toset(["data-ingestion", "data-processing", "data-quality"])
  alarm_name          = "${each.value}-failure"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "This alarm monitors for failures in the ${each.value} Glue job"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    JobName = each.value
  }
  
  tags = {
    Name        = "${each.value}-failure-alarm"
    Environment = var.environment
  }
}

# CloudWatch Alarm for job duration
resource "aws_cloudwatch_metric_alarm" "job_duration" {
  for_each            = toset(["data-ingestion", "data-processing", "data-quality"])
  alarm_name          = "${each.value}-long-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.aggregate.elapsedTime"
  namespace           = "Glue"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.job_duration_threshold * 60 * 1000  # Convert minutes to milliseconds
  alarm_description   = "This alarm monitors for unusually long duration of the ${each.value} Glue job"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    JobName = each.value
  }
  
  tags = {
    Name        = "${each.value}-duration-alarm"
    Environment = var.environment
  }
}

# CloudWatch Alarm for memory usage
resource "aws_cloudwatch_metric_alarm" "memory_usage" {
  for_each            = toset(["data-ingestion", "data-processing", "data-quality"])
  alarm_name          = "${each.value}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.jvm.heap.usage"
  namespace           = "Glue"
  period              = 300
  statistic           = "Maximum"
  threshold           = 85
  alarm_description   = "This alarm monitors for high memory usage in the ${each.value} Glue job"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    JobName = each.value
  }
  
  tags = {
    Name        = "${each.value}-memory-alarm"
    Environment = var.environment
  }
}

# CloudWatch Dashboard for Glue jobs
resource "aws_cloudwatch_dashboard" "glue_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-glue-dashboard"
  
  dashboard_body = jsonencode({
    widgets = concat(
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 2
          properties = {
            markdown = "# AWS Glue ETL Pipeline Dashboard - ${upper(var.environment)} Environment\nLast updated: ${formatdate("YYYY-MM-DD", timestamp())}"
          }
        }
      ],
      # Job Status Widgets
      [for idx, job_name in ["data-ingestion", "data-processing", "data-quality"] : {
        type   = "metric"
        x      = (idx * 8) % 24
        y      = 2
        width  = 8
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["Glue", "glue.driver.aggregate.numCompletedTasks", "JobName", job_name],
            [".", "glue.driver.aggregate.numFailedTasks", ".", "."]
          ]
          region = var.aws_region
          title  = "${job_name} - Task Status"
          period = 300
        }
      }],
      # Job Duration Widgets
      [for idx, job_name in ["data-ingestion", "data-processing", "data-quality"] : {
        type   = "metric"
        x      = (idx * 8) % 24
        y      = 8
        width  = 8
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["Glue", "glue.driver.aggregate.elapsedTime", "JobName", job_name]
          ]
          region = var.aws_region
          title  = "${job_name} - Duration (ms)"
          period = 300
        }
      }],
      # Memory Usage Widgets
      [for idx, job_name in ["data-ingestion", "data-processing", "data-quality"] : {
        type   = "metric"
        x      = (idx * 8) % 24
        y      = 14
        width  = 8
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["Glue", "glue.driver.jvm.heap.usage", "JobName", job_name]
          ]
          region = var.aws_region
          title  = "${job_name} - Memory Usage (%)"
          period = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      }],
      # Records Processed Widgets
      [for idx, job_name in ["data-ingestion", "data-processing", "data-quality"] : {
        type   = "metric"
        x      = (idx * 8) % 24
        y      = 20
        width  = 8
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["Glue", "glue.ALL.s3.filesystem.read_bytes", "JobName", job_name],
            [".", "glue.ALL.s3.filesystem.write_bytes", ".", "."]
          ]
          region = var.aws_region
          title  = "${job_name} - Data Processed"
          period = 300
        }
      }]
    )
  })
}

# Lambda function for enhanced monitoring and alerting
resource "aws_lambda_function" "monitoring" {
  count         = var.enable_enhanced_monitoring ? 1 : 0
  function_name = "${var.project_name}-${var.environment}-monitoring"
  role          = var.monitoring_role_arn
  handler       = "index.handler"
  runtime       = "python3.10"
  timeout       = 60
  memory_size   = 128
  
  s3_bucket = var.scripts_bucket_name
  s3_key    = "lambda/monitoring.zip"
  
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
      ENVIRONMENT   = var.environment
      GLUE_JOBS     = join(",", ["data-ingestion", "data-processing", "data-quality"])
    }
  }
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring"
    Environment = var.environment
  }
}

# EventBridge rule to trigger monitoring Lambda
resource "aws_cloudwatch_event_rule" "glue_job_state_change" {
  count       = var.enable_enhanced_monitoring ? 1 : 0
  name        = "${var.project_name}-${var.environment}-glue-job-state-change"
  description = "Capture Glue job state changes"
  
  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail-type = ["Glue Job State Change"]
    detail = {
      jobName = ["data-ingestion", "data-processing", "data-quality"]
    }
  })
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-glue-job-state-change"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  count     = var.enable_enhanced_monitoring ? 1 : 0
  rule      = aws_cloudwatch_event_rule.glue_job_state_change[0].name
  target_id = "InvokeMonitoringLambda"
  arn       = aws_lambda_function.monitoring[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.enable_enhanced_monitoring ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monitoring[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.glue_job_state_change[0].arn
}
