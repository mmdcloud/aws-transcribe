variable "aws_region" {
  type        = string
  description = "AWS deployment region."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Target deployment environment (e.g., dev, staging, prod, production)."
  default     = "production"

  validation {
    condition     = contains(["dev", "development", "staging", "uat", "prod", "production"], var.environment)
    error_message = "Environment must be one of: dev, development, staging, uat, prod, production."
  }
}

variable "project_name" {
  type        = string
  description = "Project identifier used for resource naming and tagging."
  default     = "call-analytics"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "raw_audio_bucket_name" {
  type        = string
  description = "Optional override for S3 raw audio bucket name. If blank, a globally unique name will be generated."
  default     = ""
}

variable "transcripts_bucket_name" {
  type        = string
  description = "Optional override for S3 transcripts & analytics bucket name. If blank, a globally unique name will be generated."
  default     = ""
}

variable "dynamodb_table_name" {
  type        = string
  description = "Optional override for DynamoDB metadata table name. If blank, a default will be derived."
  default     = ""
}

# ------------------------------------------------------------------------------
# Security & KMS
# ------------------------------------------------------------------------------
variable "use_kms_cmk" {
  type        = bool
  description = "Whether to provision a dedicated AWS KMS Customer Managed Key (CMK) for multi-service envelope encryption. If false, AWS managed keys are used."
  default     = true
}

variable "kms_key_deletion_window_in_days" {
  type        = number
  description = "Waiting period (in days) before scheduled deletion of KMS key."
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window_in_days >= 7 && var.kms_key_deletion_window_in_days <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

# ------------------------------------------------------------------------------
# Amazon Transcribe Settings
# ------------------------------------------------------------------------------
variable "transcribe_language_code" {
  type        = string
  description = "Default language code for Amazon Transcribe batch jobs (e.g., en-US, es-US, fr-CA)."
  default     = "en-US"
}

variable "transcribe_enable_language_id" {
  type        = bool
  description = "Enable automatic language identification in Amazon Transcribe batch jobs."
  default     = false
}

variable "transcribe_max_speakers" {
  type        = number
  description = "Maximum number of distinct speakers for diarization (between 2 and 10)."
  default     = 5

  validation {
    condition     = var.transcribe_max_speakers >= 2 && var.transcribe_max_speakers <= 10
    error_message = "Max speakers must be between 2 and 10."
  }
}

# ------------------------------------------------------------------------------
# Amazon Bedrock Settings
# ------------------------------------------------------------------------------
variable "bedrock_model_id" {
  type        = string
  description = "Amazon Bedrock Foundation Model ID or inference profile for analytics and summarization."
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "bedrock_max_tokens" {
  type        = number
  description = "Max output tokens for Bedrock inference."
  default     = 2048
}

variable "bedrock_temperature" {
  type        = number
  description = "Temperature setting for Bedrock model (lower value = deterministic output)."
  default     = 0.1
}

# ------------------------------------------------------------------------------
# Lambda Compute Configurations
# ------------------------------------------------------------------------------
variable "dispatcher_lambda_memory" {
  type        = number
  description = "Memory size (MB) for Job Dispatcher Lambda."
  default     = 512
}

variable "dispatcher_lambda_timeout" {
  type        = number
  description = "Timeout (seconds) for Job Dispatcher Lambda."
  default     = 60
}

variable "processor_lambda_memory" {
  type        = number
  description = "Memory size (MB) for Job Processor Lambda."
  default     = 1024
}

variable "processor_lambda_timeout" {
  type        = number
  description = "Timeout (seconds) for Job Processor Lambda."
  default     = 300
}

# ------------------------------------------------------------------------------
# SQS Queue Settings
# ------------------------------------------------------------------------------
variable "sqs_ingestion_visibility_timeout" {
  type        = number
  description = "Visibility timeout (seconds) for ingestion queue. Recommended: >= 6x Lambda timeout."
  default     = 360
}

variable "sqs_processing_visibility_timeout" {
  type        = number
  description = "Visibility timeout (seconds) for processing queue. Recommended: >= 6x Lambda timeout."
  default     = 1800
}

variable "sqs_max_receive_count" {
  type        = number
  description = "Number of times a message is delivered before being moved to the Dead Letter Queue."
  default     = 3
}

variable "sqs_message_retention_seconds" {
  type        = number
  description = "Message retention period in seconds for main SQS queues (14 days max = 1209600)."
  default     = 864000 # 10 days
}

variable "dlq_message_retention_seconds" {
  type        = number
  description = "Message retention period in seconds for Dead Letter Queues (DLQ)."
  default     = 1209600 # 14 days
}

# ------------------------------------------------------------------------------
# DynamoDB Settings
# ------------------------------------------------------------------------------
variable "dynamodb_billing_mode" {
  type        = string
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)."
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "Billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "dynamodb_read_capacity" {
  type        = number
  description = "Provisioned read capacity units (only used when billing mode is PROVISIONED)."
  default     = 5
}

variable "dynamodb_write_capacity" {
  type        = number
  description = "Provisioned write capacity units (only used when billing mode is PROVISIONED)."
  default     = 5
}

variable "dynamodb_ttl_days" {
  type        = number
  description = "Number of days before DynamoDB items are automatically expired via TTL."
  default     = 90
}

# ------------------------------------------------------------------------------
# Logging & Observability
# ------------------------------------------------------------------------------
variable "log_retention_in_days" {
  type        = number
  description = "CloudWatch log retention in days."
  default     = 30
}

variable "alarm_sns_topic_arns" {
  type        = list(string)
  description = "Optional list of existing SNS Topic ARNs to receive CloudWatch alarm notifications."
  default     = []
}

variable "create_alarm_sns_topic" {
  type        = bool
  description = "Whether to create a new SNS topic for pipeline alerts."
  default     = true
}

variable "alarm_email_endpoints" {
  type        = list(string)
  description = "Optional list of email addresses to subscribe to the newly created pipeline alarm SNS topic."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all AWS resources."
  default = {
    Architecture = "CallCenterAnalyticsPipeline"
    ManagedBy    = "Terraform"
  }
}

