variable "table_name" {
  type        = string
  description = "Name of the DynamoDB table."
}

variable "billing_mode" {
  type        = string
  description = "Billing mode (PAY_PER_REQUEST or PROVISIONED)."
  default     = "PAY_PER_REQUEST"
}

variable "read_capacity" {
  type        = number
  description = "Provisioned read capacity units."
  default     = null
}

variable "write_capacity" {
  type        = number
  description = "Provisioned write capacity units."
  default     = null
}

variable "kms_key_arn" {
  type        = string
  description = "KMS CMK ARN for server-side encryption."
  default     = null
}

variable "ttl_attribute_name" {
  type        = string
  description = "Name of TTL attribute."
  default     = "ttl_timestamp"
}

variable "ttl_enabled" {
  type        = bool
  description = "Whether TTL is enabled."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to DynamoDB table."
  default     = {}
}

