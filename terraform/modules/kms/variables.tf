variable "enabled" {
  type        = bool
  description = "Whether to provision the KMS Customer Managed Key."
  default     = true
}

variable "name_prefix" {
  type        = string
  description = "Resource naming prefix."
}

variable "account_id" {
  type        = string
  description = "AWS Account ID for key policy statements."
}

variable "region" {
  type        = string
  description = "AWS Region for key policy statements."
}

variable "deletion_window_in_days" {
  type        = number
  description = "Waiting period before scheduled deletion of KMS key."
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to the KMS resources."
  default     = {}
}

