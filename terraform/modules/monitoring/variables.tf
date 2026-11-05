variable "name_prefix" {
  type        = string
  description = "Resource naming prefix."
}

variable "region" {
  type        = string
  description = "AWS Region."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS CMK ARN for log group encryption (null for default AWS encryption)."
  default     = null
}

variable "kms_key_id" {
  type        = string
  description = "KMS Key ID or alias for SNS topic encryption."
  default     = "alias/aws/sns"
}

variable "log_retention_in_days" {
  type        = number
  description = "Retention period in days for CloudWatch log groups."
  default     = 30
}

variable "create_alarm_sns_topic" {
  type        = bool
  description = "Whether to create a new SNS topic for pipeline alarms."
  default     = true
}

variable "alarm_sns_topic_arns" {
  type        = list(string)
  description = "Optional existing SNS topic ARNs for alarms."
  default     = []
}

variable "alarm_email_endpoints" {
  type        = list(string)
  description = "Optional email endpoints to subscribe to alerts topic."
  default     = []
}

variable "dispatcher_function_name" {
  type        = string
  description = "Dispatcher Lambda function name."
}

variable "processor_function_name" {
  type        = string
  description = "Processor Lambda function name."
}

variable "ingestion_queue_name" {
  type        = string
  description = "Name of Ingestion SQS Queue."
}

variable "ingestion_dlq_name" {
  type        = string
  description = "Name of Ingestion Dead Letter Queue."
}

variable "processing_queue_name" {
  type        = string
  description = "Name of Processing SQS Queue."
}

variable "processing_dlq_name" {
  type        = string
  description = "Name of Processing Dead Letter Queue."
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to monitoring resources."
  default     = {}
}

