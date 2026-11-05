# ------------------------------------------------------------------------------
# 1. Ingestion Queues (S3 -> SQS -> Dispatcher Lambda)
# ------------------------------------------------------------------------------

resource "aws_sqs_queue" "ingestion_dlq" {
  name                      = "${var.name_prefix}-ingestion-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  kms_master_key_id         = var.kms_master_key_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ingestion-dlq"
      Role = "DeadLetterQueue"
    }
  )
}

resource "aws_sqs_queue_redrive_allow_policy" "ingestion_dlq" {
  queue_url = aws_sqs_queue.ingestion_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.ingestion_queue.arn]
  })
}

resource "aws_sqs_queue" "ingestion_queue" {
  name                       = "${var.name_prefix}-ingestion-queue"
  visibility_timeout_seconds = var.sqs_ingestion_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention_seconds
  kms_master_key_id          = var.kms_master_key_id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingestion_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ingestion-queue"
      Role = "IngestionQueue"
    }
  )
}

resource "aws_sqs_queue_policy" "ingestion_queue_policy" {
  queue_url = aws_sqs_queue.ingestion_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "IngestionQueuePolicy"
    Statement = [
      {
        Sid    = "AllowS3BucketNotifications"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.ingestion_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.raw_audio_bucket_arn
          }
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# 2. Processing Queues (EventBridge -> SQS -> Processor Lambda)
# ------------------------------------------------------------------------------

resource "aws_sqs_queue" "processing_dlq" {
  name                      = "${var.name_prefix}-processing-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  kms_master_key_id         = var.kms_master_key_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-processing-dlq"
      Role = "DeadLetterQueue"
    }
  )
}

resource "aws_sqs_queue_redrive_allow_policy" "processing_dlq" {
  queue_url = aws_sqs_queue.processing_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.processing_queue.arn]
  })
}

resource "aws_sqs_queue" "processing_queue" {
  name                       = "${var.name_prefix}-processing-queue"
  visibility_timeout_seconds = var.sqs_processing_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention_seconds
  kms_master_key_id          = var.kms_master_key_id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.processing_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-processing-queue"
      Role = "ProcessingQueue"
    }
  )
}

resource "aws_sqs_queue_policy" "processing_queue_policy" {
  queue_url = aws_sqs_queue.processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "ProcessingQueuePolicy"
    Statement = [
      {
        Sid    = "AllowEventBridgeStateChangeNotifications"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.processing_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.eventbridge_rule_arn
          }
        }
      }
    ]
  })
}

