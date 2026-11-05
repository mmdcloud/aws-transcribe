# ------------------------------------------------------------------------------
# 1. Job Dispatcher Lambda (Ingestion SQS -> Transcribe API)
# ------------------------------------------------------------------------------

data "archive_file" "dispatcher_zip" {
  type        = "zip"
  source_file = var.dispatcher_source_file
  output_path = "${path.root}/build/dispatcher.zip"
}

resource "aws_lambda_function" "dispatcher" {
  function_name    = "${var.name_prefix}-dispatcher"
  description      = "Validates uploaded audio from Ingestion SQS and starts Amazon Transcribe batch job with diarization"
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.dispatcher_lambda_role.arn
  filename         = data.archive_file.dispatcher_zip.output_path
  source_code_hash = data.archive_file.dispatcher_zip.output_base64sha256

  memory_size = var.dispatcher_memory
  timeout     = var.dispatcher_timeout

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TRANSCRIPTS_BUCKET  = var.transcripts_bucket_id
      TRANSCRIBE_ROLE_ARN = aws_iam_role.transcribe_data_access_role.arn
      LANGUAGE_CODE       = var.transcribe_language_code
      ENABLE_LANGUAGE_ID  = tostring(var.transcribe_enable_language_id)
      MAX_SPEAKER_LABELS  = tostring(var.transcribe_max_speakers)
      ENVIRONMENT         = var.environment
      LOG_LEVEL           = "INFO"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-dispatcher"
      Role = "JobDispatcher"
    }
  )
}

resource "aws_lambda_event_source_mapping" "dispatcher_sqs" {
  event_source_arn                   = var.ingestion_queue_arn
  function_name                      = aws_lambda_function.dispatcher.arn
  batch_size                         = 5
  maximum_batching_window_in_seconds = 10
  function_response_types            = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 50
  }
}

# ------------------------------------------------------------------------------
# 2. Job Processor & Bedrock Summarizer Lambda (Processing SQS -> Bedrock -> DynamoDB/S3)
# ------------------------------------------------------------------------------

data "archive_file" "processor_zip" {
  type        = "zip"
  source_file = var.processor_source_file
  output_path = "${path.root}/build/processor.zip"
}

resource "aws_lambda_function" "processor" {
  function_name    = "${var.name_prefix}-processor"
  description      = "Processes Transcribe completion events, parses diarization, generates Bedrock GenAI analytics, and persists to S3 and DynamoDB"
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.processor_lambda_role.arn
  filename         = data.archive_file.processor_zip.output_path
  source_code_hash = data.archive_file.processor_zip.output_base64sha256

  memory_size = var.processor_memory
  timeout     = var.processor_timeout

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TRANSCRIPTS_BUCKET  = var.transcripts_bucket_id
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
      BEDROCK_MODEL_ID    = var.bedrock_model_id
      BEDROCK_MAX_TOKENS  = tostring(var.bedrock_max_tokens)
      BEDROCK_TEMPERATURE = tostring(var.bedrock_temperature)
      TTL_RETENTION_DAYS  = tostring(var.dynamodb_ttl_days)
      LOG_LEVEL           = "INFO"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-processor"
      Role = "JobProcessor"
    }
  )
}

resource "aws_lambda_event_source_mapping" "processor_sqs" {
  event_source_arn                   = var.processing_queue_arn
  function_name                      = aws_lambda_function.processor.arn
  batch_size                         = 5
  maximum_batching_window_in_seconds = 10
  function_response_types            = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 50
  }
}

