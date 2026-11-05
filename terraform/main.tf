data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  name_prefix = "${var.project_name}-${var.environment}"

  raw_bucket_name = coalesce(
    var.raw_audio_bucket_name,
    "${local.name_prefix}-raw-audio-${local.account_id}-${random_string.suffix.result}"
  )

  transcripts_bucket_name = coalesce(
    var.transcripts_bucket_name,
    "${local.name_prefix}-transcripts-${local.account_id}-${random_string.suffix.result}"
  )

  dynamodb_table_name = coalesce(
    var.dynamodb_table_name,
    "${local.name_prefix}-metadata"
  )

  eventbridge_rule_name = "${local.name_prefix}-transcribe-state-change"

  # Deterministic ARNs to decouple cross-module resource policies and avoid cycles
  raw_audio_bucket_arn = "arn:aws:s3:::${local.raw_bucket_name}"
  eventbridge_rule_arn = "arn:aws:events:${local.region}:${local.account_id}:rule/${local.eventbridge_rule_name}"
}

# ------------------------------------------------------------------------------
# 1. KMS Module
# ------------------------------------------------------------------------------
module "kms" {
  source = "./modules/kms"

  enabled                 = var.use_kms_cmk
  name_prefix             = local.name_prefix
  account_id              = local.account_id
  region                  = local.region
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  tags                    = var.tags
}

# ------------------------------------------------------------------------------
# 2. SQS Module
# ------------------------------------------------------------------------------
module "sqs" {
  source = "./modules/sqs"

  name_prefix                       = local.name_prefix
  kms_master_key_id                 = var.use_kms_cmk ? module.kms.key_id : "alias/aws/sqs"
  sqs_ingestion_visibility_timeout  = var.sqs_ingestion_visibility_timeout
  sqs_processing_visibility_timeout = var.sqs_processing_visibility_timeout
  sqs_max_receive_count             = var.sqs_max_receive_count
  sqs_message_retention_seconds     = var.sqs_message_retention_seconds
  dlq_message_retention_seconds     = var.dlq_message_retention_seconds
  raw_audio_bucket_arn              = local.raw_audio_bucket_arn
  eventbridge_rule_arn              = local.eventbridge_rule_arn
  tags                              = var.tags
}

# ------------------------------------------------------------------------------
# 3. S3 Module
# ------------------------------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  raw_bucket_name         = local.raw_bucket_name
  transcripts_bucket_name = local.transcripts_bucket_name
  environment             = var.environment
  kms_key_arn             = module.kms.key_arn
  ingestion_queue_arn     = module.sqs.ingestion_queue_arn
  tags                    = var.tags
}

# ------------------------------------------------------------------------------
# 4. DynamoDB Module
# ------------------------------------------------------------------------------
module "dynamodb" {
  source = "./modules/dynamodb"

  table_name         = local.dynamodb_table_name
  billing_mode       = var.dynamodb_billing_mode
  read_capacity      = var.dynamodb_read_capacity
  write_capacity     = var.dynamodb_write_capacity
  kms_key_arn        = module.kms.key_arn
  ttl_attribute_name = "ttl_timestamp"
  ttl_enabled        = true
  tags               = var.tags
}

# ------------------------------------------------------------------------------
# 5. Lambda Module (Dispatcher & Processor Lambdas + IAM Roles)
# ------------------------------------------------------------------------------
module "lambda" {
  source = "./modules/lambda"

  name_prefix                   = local.name_prefix
  account_id                    = local.account_id
  region                        = local.region
  environment                   = var.environment
  dispatcher_source_file        = "${path.root}/../src/dispatcher/handler.py"
  processor_source_file         = "${path.root}/../src/processor/handler.py"
  dispatcher_memory             = var.dispatcher_lambda_memory
  dispatcher_timeout            = var.dispatcher_lambda_timeout
  processor_memory              = var.processor_lambda_memory
  processor_timeout             = var.processor_lambda_timeout
  raw_audio_bucket_arn          = module.s3.raw_audio_bucket_arn
  transcripts_bucket_id         = module.s3.transcripts_bucket_id
  transcripts_bucket_arn        = module.s3.transcripts_bucket_arn
  dynamodb_table_name           = module.dynamodb.table_name
  dynamodb_table_arn            = module.dynamodb.table_arn
  ingestion_queue_arn           = module.sqs.ingestion_queue_arn
  processing_queue_arn          = module.sqs.processing_queue_arn
  kms_key_arn                   = module.kms.key_arn
  transcribe_language_code      = var.transcribe_language_code
  transcribe_enable_language_id = var.transcribe_enable_language_id
  transcribe_max_speakers       = var.transcribe_max_speakers
  bedrock_model_id              = var.bedrock_model_id
  bedrock_max_tokens            = var.bedrock_max_tokens
  bedrock_temperature           = var.bedrock_temperature
  dynamodb_ttl_days             = var.dynamodb_ttl_days
  tags                          = var.tags
}

# ------------------------------------------------------------------------------
# 6. EventBridge Module
# ------------------------------------------------------------------------------
module "eventbridge" {
  source = "./modules/eventbridge"

  rule_name            = local.eventbridge_rule_name
  processing_queue_arn = module.sqs.processing_queue_arn
  processing_dlq_arn   = module.sqs.processing_dlq_arn
  tags                 = var.tags
}

# ------------------------------------------------------------------------------
# 7. Monitoring Module
# ------------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  name_prefix              = local.name_prefix
  region                   = local.region
  kms_key_arn              = module.kms.key_arn
  kms_key_id               = var.use_kms_cmk ? module.kms.key_id : "alias/aws/sns"
  log_retention_in_days    = var.log_retention_in_days
  create_alarm_sns_topic   = var.create_alarm_sns_topic
  alarm_sns_topic_arns     = var.alarm_sns_topic_arns
  alarm_email_endpoints    = var.alarm_email_endpoints
  dispatcher_function_name = module.lambda.dispatcher_function_name
  processor_function_name  = module.lambda.processor_function_name
  ingestion_queue_name     = module.sqs.ingestion_queue_name
  ingestion_dlq_name       = module.sqs.ingestion_dlq_name
  processing_queue_name    = module.sqs.processing_queue_name
  processing_dlq_name      = module.sqs.processing_dlq_name
  tags                     = var.tags
}
