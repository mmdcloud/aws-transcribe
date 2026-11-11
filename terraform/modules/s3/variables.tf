variable "raw_bucket_name" {
  type        = string
  description = "Name of the raw audio S3 bucket."
}

variable "transcripts_bucket_name" {
  type        = string
  description = "Name of the transcripts and analytics S3 bucket."
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
}

variable "force_destroy" {
  type        = bool
  description = "Whether to force destroy the bucket or not"
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of KMS CMK for S3 bucket encryption (null for AES256)."
  default     = null
}

variable "ingestion_queue_arn" {
  type        = string
  description = "ARN of Ingestion SQS Queue for S3 object creation notifications."
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to S3 resources."
  default     = {}
}

