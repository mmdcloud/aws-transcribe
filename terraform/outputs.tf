# ------------------------------------------------------------------------------
# Root Terraform Outputs (Forwarded from Modules)
# ------------------------------------------------------------------------------

output "raw_audio_bucket_name" {
  description = "Name of S3 bucket for raw audio ingestion"
  value       = module.s3.raw_audio_bucket_id
}

output "raw_audio_bucket_arn" {
  description = "ARN of S3 bucket for raw audio ingestion"
  value       = module.s3.raw_audio_bucket_arn
}

output "transcripts_bucket_name" {
  description = "Name of S3 bucket storing diarized transcripts and Bedrock analytics JSON"
  value       = module.s3.transcripts_bucket_id
}

output "transcripts_bucket_arn" {
  description = "ARN of S3 bucket storing diarized transcripts and Bedrock analytics JSON"
  value       = module.s3.transcripts_bucket_arn
}

output "ingestion_queue_url" {
  description = "URL of Ingestion SQS Queue"
  value       = module.sqs.ingestion_queue_url
}

output "ingestion_queue_arn" {
  description = "ARN of Ingestion SQS Queue"
  value       = module.sqs.ingestion_queue_arn
}

output "ingestion_dlq_url" {
  description = "URL of Ingestion Dead Letter Queue (DLQ)"
  value       = module.sqs.ingestion_dlq_url
}

output "ingestion_dlq_arn" {
  description = "ARN of Ingestion Dead Letter Queue (DLQ)"
  value       = module.sqs.ingestion_dlq_arn
}

output "processing_queue_url" {
  description = "URL of Processing SQS Queue"
  value       = module.sqs.processing_queue_url
}

output "processing_queue_arn" {
  description = "ARN of Processing SQS Queue"
  value       = module.sqs.processing_queue_arn
}

output "processing_dlq_url" {
  description = "URL of Processing Dead Letter Queue (DLQ)"
  value       = module.sqs.processing_dlq_url
}

output "processing_dlq_arn" {
  description = "ARN of Processing Dead Letter Queue (DLQ)"
  value       = module.sqs.processing_dlq_arn
}

output "dispatcher_lambda_function_name" {
  description = "Function name of Job Dispatcher Lambda"
  value       = module.lambda.dispatcher_function_name
}

output "dispatcher_lambda_arn" {
  description = "ARN of Job Dispatcher Lambda"
  value       = module.lambda.dispatcher_function_arn
}

output "processor_lambda_function_name" {
  description = "Function name of Job Processor / Bedrock Summarizer Lambda"
  value       = module.lambda.processor_function_name
}

output "processor_lambda_arn" {
  description = "ARN of Job Processor / Bedrock Summarizer Lambda"
  value       = module.lambda.processor_function_arn
}

output "dynamodb_table_name" {
  description = "Name of DynamoDB table storing call analytics and metadata"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of DynamoDB table storing call analytics and metadata"
  value       = module.dynamodb.table_arn
}

output "eventbridge_rule_name" {
  description = "Name of EventBridge rule capturing Transcribe state changes"
  value       = module.eventbridge.rule_name
}

output "eventbridge_rule_arn" {
  description = "ARN of EventBridge rule capturing Transcribe state changes"
  value       = module.eventbridge.rule_arn
}

output "kms_key_arn" {
  description = "ARN of KMS Customer Managed Key (null if CMK disabled)"
  value       = module.kms.key_arn
}

output "sns_alerts_topic_arn" {
  description = "ARN of SNS topic for operational alerts (null if disabled)"
  value       = module.monitoring.alerts_topic_arn
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch Operational Dashboard"
  value       = module.monitoring.dashboard_name
}
