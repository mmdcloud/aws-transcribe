variable "name_prefix" {
  type        = string
  description = "Resource naming prefix."
}

variable "kms_master_key_id" {
  type        = string
  description = "KMS Key ID or alias for SQS SSE encryption."
  default     = "alias/aws/sqs"
}

variable "sqs_ingestion_visibility_timeout" {
  type        = number
  description = "Visibility timeout (seconds) for ingestion queue."
  default     = 360
}

variable "sqs_processing_visibility_timeout" {
  type        = number
  description = "Visibility timeout (seconds) for processing queue."
  default     = 1800
}

variable "sqs_max_receive_count" {
  type        = number
  description = "Number of times a message is delivered before moving to DLQ."
  default     = 3
}

variable "sqs_message_retention_seconds" {
  type        = number
  description = "Message retention in seconds for main queues."
  default     = 864000
}

variable "dlq_message_retention_seconds" {
  type        = number
  description = "Message retention in seconds for DLQs."
  default     = 1209600
}

variable "raw_audio_bucket_arn" {
  type        = string
  description = "ARN of S3 raw audio bucket for SQS queue policy."
}

variable "eventbridge_rule_arn" {
  type        = string
  description = "ARN of EventBridge rule for SQS queue policy."
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to SQS resources."
  default     = {}
}

