resource "aws_cloudwatch_event_rule" "transcribe_state_change" {
  name        = var.rule_name
  description = "Captures Amazon Transcribe Job State Change events (COMPLETED or FAILED) and forwards to Processing SQS queue"

  event_pattern = jsonencode({
    source      = ["aws.transcribe"]
    detail-type = ["Transcribe Job State Change"]
    detail = {
      TranscriptionJobStatus = ["COMPLETED", "FAILED"]
    }
  })

  tags = merge(
    var.tags,
    {
      Name = var.rule_name
    }
  )
}

resource "aws_cloudwatch_event_target" "sqs_processing_target" {
  rule      = aws_cloudwatch_event_rule.transcribe_state_change.name
  target_id = "SendToProcessingSQS"
  arn       = var.processing_queue_arn

  dead_letter_config {
    arn = var.processing_dlq_arn
  }

  retry_policy {
    maximum_event_age_in_seconds = 86400
    maximum_retry_attempts       = 5
  }
}

