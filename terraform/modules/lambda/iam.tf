# ------------------------------------------------------------------------------
# IAM Roles & Policies for Dispatcher, Transcribe Data Access, & Processor
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 1. Dispatcher Lambda IAM Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "dispatcher_lambda_role" {
  name = "${var.name_prefix}-dispatcher-role"

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

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-dispatcher-role"
    }
  )
}

resource "aws_iam_policy" "dispatcher_lambda_policy" {
  name        = "${var.name_prefix}-dispatcher-policy"
  description = "Allows Job Dispatcher Lambda to interact with SQS, S3, Transcribe, and KMS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "CloudWatchLogsAccess"
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.name_prefix}-dispatcher:*"
        },
        {
          Sid    = "SQSConsumerAccess"
          Effect = "Allow"
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes"
          ]
          Resource = var.ingestion_queue_arn
        },
        {
          Sid    = "S3AudioReadAccess"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion"
          ]
          Resource = "${var.raw_audio_bucket_arn}/*"
        },
        {
          Sid    = "TranscribeJobManagement"
          Effect = "Allow"
          Action = [
            "transcribe:StartTranscriptionJob",
            "transcribe:GetTranscriptionJob",
            "transcribe:TagResource"
          ]
          Resource = "arn:aws:transcribe:${var.region}:${var.account_id}:transcription-job/*"
        },
        {
          Sid      = "PassTranscribeExecutionRole"
          Effect   = "Allow"
          Action   = "iam:PassRole"
          Resource = aws_iam_role.transcribe_data_access_role.arn
        },
        {
          Sid    = "XRayTracing"
          Effect = "Allow"
          Action = [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords"
          ]
          Resource = "*"
        }
      ],
      var.kms_key_arn != null ? [
        {
          Sid    = "KMSDecryptAndGenerate"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey*"
          ]
          Resource = var.kms_key_arn
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "dispatcher_policy_attach" {
  role       = aws_iam_role.dispatcher_lambda_role.name
  policy_arn = aws_iam_policy.dispatcher_lambda_policy.arn
}

# ------------------------------------------------------------------------------
# 2. Transcribe Data Access IAM Role (Used by Transcribe for KMS/S3 access)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "transcribe_data_access_role" {
  name = "${var.name_prefix}-transcribe-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transcribe.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-transcribe-access-role"
    }
  )
}

resource "aws_iam_policy" "transcribe_data_access_policy" {
  name        = "${var.name_prefix}-transcribe-access-policy"
  description = "Allows Amazon Transcribe to read audio from Raw Bucket and write output to Transcripts Bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "S3RawBucketRead"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            var.raw_audio_bucket_arn,
            "${var.raw_audio_bucket_arn}/*"
          ]
        },
        {
          Sid    = "S3TranscriptsBucketWrite"
          Effect = "Allow"
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            var.transcripts_bucket_arn,
            "${var.transcripts_bucket_arn}/*"
          ]
        }
      ],
      var.kms_key_arn != null ? [
        {
          Sid    = "KMSAccessForTranscribe"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey*"
          ]
          Resource = var.kms_key_arn
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "transcribe_policy_attach" {
  role       = aws_iam_role.transcribe_data_access_role.name
  policy_arn = aws_iam_policy.transcribe_data_access_policy.arn
}

# ------------------------------------------------------------------------------
# 3. Processor & Bedrock Summarizer Lambda IAM Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "processor_lambda_role" {
  name = "${var.name_prefix}-processor-role"

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

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-processor-role"
    }
  )
}

resource "aws_iam_policy" "processor_lambda_policy" {
  name        = "${var.name_prefix}-processor-policy"
  description = "Allows Processor Lambda to access SQS, S3, Transcribe, Bedrock, DynamoDB, and KMS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "CloudWatchLogsAccess"
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.name_prefix}-processor:*"
        },
        {
          Sid    = "SQSConsumerAccess"
          Effect = "Allow"
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes"
          ]
          Resource = var.processing_queue_arn
        },
        {
          Sid    = "S3TranscriptReadAndAnalyticsWrite"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = "${var.transcripts_bucket_arn}/*"
        },
        {
          Sid    = "TranscribeMetadataRead"
          Effect = "Allow"
          Action = [
            "transcribe:GetTranscriptionJob"
          ]
          Resource = "arn:aws:transcribe:${var.region}:${var.account_id}:transcription-job/*"
        },
        {
          Sid    = "BedrockModelInvocation"
          Effect = "Allow"
          Action = [
            "bedrock:InvokeModel",
            "bedrock:InvokeModelWithResponseStream"
          ]
          Resource = [
            "arn:aws:bedrock:*::foundation-model/*",
            "arn:aws:bedrock:*:*:inference-profile/*"
          ]
        },
        {
          Sid    = "DynamoDBAnalyticsWrite"
          Effect = "Allow"
          Action = [
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:GetItem",
            "dynamodb:Query"
          ]
          Resource = [
            var.dynamodb_table_arn,
            "${var.dynamodb_table_arn}/index/*"
          ]
        },
        {
          Sid    = "XRayTracing"
          Effect = "Allow"
          Action = [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords"
          ]
          Resource = "*"
        }
      ],
      var.kms_key_arn != null ? [
        {
          Sid    = "KMSDecryptAndGenerate"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey*",
            "kms:Encrypt"
          ]
          Resource = var.kms_key_arn
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "processor_policy_attach" {
  role       = aws_iam_role.processor_lambda_role.name
  policy_arn = aws_iam_policy.processor_lambda_policy.arn
}

