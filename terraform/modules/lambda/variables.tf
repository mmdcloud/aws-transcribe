variable "name_prefix" {
  type        = string
  description = "Resource naming prefix."
}

variable "account_id" {
  type        = string
  description = "AWS Account ID."
}

variable "region" {
  type        = string
  description = "AWS Region."
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
}

variable "dispatcher_source_file" {
  type        = string
  description = "Path to dispatcher Lambda handler python file."
}

variable "processor_source_file" {
  type        = string
  description = "Path to processor Lambda handler python file."
}

variable "dispatcher_memory" {
  type        = number
  description = "Memory size for Dispatcher Lambda."
  default     = 512
}

variable "dispatcher_timeout" {
  type        = number
  description = "Timeout in seconds for Dispatcher Lambda."
  default     = 60
}

variable "processor_memory" {
  type        = number
  description = "Memory size for Processor Lambda."
  default     = 1024
}

variable "processor_timeout" {
  type        = number
  description = "Timeout in seconds for Processor Lambda."
  default     = 300
}

variable "raw_audio_bucket_arn" {
  type        = string
  description = "ARN of S3 raw audio bucket."
}

variable "transcripts_bucket_id" {
  type        = string
  description = "Name/ID of transcripts S3 bucket."
}

variable "transcripts_bucket_arn" {
  type        = string
  description = "ARN of transcripts S3 bucket."
}

variable "dynamodb_table_name" {
  type        = string
  description = "Name of DynamoDB table."
}

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN of DynamoDB table."
}

variable "ingestion_queue_arn" {
  type        = string
  description = "ARN of Ingestion SQS queue."
}

variable "processing_queue_arn" {
  type        = string
  description = "ARN of Processing SQS queue."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS CMK ARN (null if using AWS managed key)."
  default     = null
}

variable "transcribe_language_code" {
  type        = string
  description = "Default language code for Transcribe."
  default     = "en-US"
}

variable "transcribe_enable_language_id" {
  type        = bool
  description = "Enable automatic language identification."
  default     = false
}

variable "transcribe_max_speakers" {
  type        = number
  description = "Maximum speakers for diarization."
  default     = 5
}

variable "bedrock_model_id" {
  type        = string
  description = "Bedrock foundation model ID or inference profile."
  default     = "amazon.nova-micro-v1:0"
}

variable "bedrock_max_tokens" {
  type        = number
  description = "Max output tokens for Bedrock."
  default     = 2048
}

variable "bedrock_temperature" {
  type        = number
  description = "Bedrock inference temperature."
  default     = 0.1
}

variable "dynamodb_ttl_days" {
  type        = number
  description = "TTL retention days for DynamoDB items."
  default     = 90
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to Lambda resources."
  default     = {}
}

