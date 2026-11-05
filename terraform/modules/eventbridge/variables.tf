variable "rule_name" {
  type        = string
  description = "Name of the EventBridge rule."
}

variable "processing_queue_arn" {
  type        = string
  description = "ARN of Processing SQS Queue target."
}

variable "processing_dlq_arn" {
  type        = string
  description = "ARN of Processing Dead Letter Queue for failed EventBridge deliveries."
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to EventBridge resources."
  default     = {}
}

