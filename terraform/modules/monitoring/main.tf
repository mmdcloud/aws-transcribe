# ------------------------------------------------------------------------------
# 1. CloudWatch Log Groups with Retention & KMS CMK Encryption
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "dispatcher_log_group" {
  name              = "/aws/lambda/${var.dispatcher_function_name}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "/aws/lambda/${var.dispatcher_function_name}"
    }
  )
}

resource "aws_cloudwatch_log_group" "processor_log_group" {
  name              = "/aws/lambda/${var.processor_function_name}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "/aws/lambda/${var.processor_function_name}"
    }
  )
}

# ------------------------------------------------------------------------------
# 2. SNS Alerting Topic for Operational Escalation
# ------------------------------------------------------------------------------

resource "aws_sns_topic" "pipeline_alerts" {
  count             = var.create_alarm_sns_topic ? 1 : 0
  name              = "${var.name_prefix}-alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-alerts"
      Role = "OperationalAlerts"
    }
  )
}

resource "aws_sns_topic_subscription" "email_subscribers" {
  for_each  = var.create_alarm_sns_topic ? toset(var.alarm_email_endpoints) : toset([])
  topic_arn = aws_sns_topic.pipeline_alerts[0].arn
  protocol  = "email"
  endpoint  = each.value
}

locals {
  all_alarm_actions = concat(
    var.create_alarm_sns_topic ? [aws_sns_topic.pipeline_alerts[0].arn] : [],
    var.alarm_sns_topic_arns
  )
}

# ------------------------------------------------------------------------------
# 3. CloudWatch Metric Alarms (DLQ Depth & Lambda Faults)
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "ingestion_dlq_alarm" {
  alarm_name          = "${var.name_prefix}-ingestion-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Poison pill detected in Ingestion Dead Letter Queue (${var.ingestion_dlq_name})"
  alarm_actions       = local.all_alarm_actions
  ok_actions          = local.all_alarm_actions

  dimensions = {
    QueueName = var.ingestion_dlq_name
  }
}

resource "aws_cloudwatch_metric_alarm" "processing_dlq_alarm" {
  alarm_name          = "${var.name_prefix}-processing-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Unprocessable event detected in Processing Dead Letter Queue (${var.processing_dlq_name})"
  alarm_actions       = local.all_alarm_actions
  ok_actions          = local.all_alarm_actions

  dimensions = {
    QueueName = var.processing_dlq_name
  }
}

resource "aws_cloudwatch_metric_alarm" "dispatcher_errors" {
  alarm_name          = "${var.name_prefix}-dispatcher-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Errors encountered in Dispatcher Lambda (${var.dispatcher_function_name})"
  alarm_actions       = local.all_alarm_actions

  dimensions = {
    FunctionName = var.dispatcher_function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "processor_errors" {
  alarm_name          = "${var.name_prefix}-processor-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Errors encountered in Processor Lambda (${var.processor_function_name})"
  alarm_actions       = local.all_alarm_actions

  dimensions = {
    FunctionName = var.processor_function_name
  }
}

# ------------------------------------------------------------------------------
# 4. CloudWatch Operational Dashboard
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "pipeline_dashboard" {
  dashboard_name = "${var.name_prefix}-overview"

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
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.ingestion_queue_name, { label = "Ingestion Queue Depth" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.ingestion_dlq_name, { color = "#d62728", label = "Ingestion DLQ Depth" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Ingestion SQS Queue & DLQ Depth"
          period  = 60
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
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.processing_queue_name, { label = "Processing Queue Depth" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.processing_dlq_name, { color = "#d62728", label = "Processing DLQ Depth" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Processing SQS Queue & DLQ Depth"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.dispatcher_function_name, { stat = "Sum", label = "Invocations" }],
            ["AWS/Lambda", "Errors", "FunctionName", var.dispatcher_function_name, { stat = "Sum", color = "#d62728", label = "Errors" }],
            ["AWS/Lambda", "Throttles", "FunctionName", var.dispatcher_function_name, { stat = "Sum", color = "#ff7f0e", label = "Throttles" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Dispatcher Lambda Invocations & Faults"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.processor_function_name, { stat = "Sum", label = "Invocations" }],
            ["AWS/Lambda", "Errors", "FunctionName", var.processor_function_name, { stat = "Sum", color = "#d62728", label = "Errors" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.processor_function_name, { stat = "Average", label = "Avg Duration (ms)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Processor Lambda Invocations, Duration & Faults"
          period  = 60
        }
      }
    ]
  })
}

