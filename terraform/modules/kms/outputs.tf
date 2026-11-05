output "key_arn" {
  description = "ARN of the KMS Customer Managed Key"
  value       = try(aws_kms_key.pipeline_key[0].arn, null)
}

output "key_id" {
  description = "Key ID of the KMS Customer Managed Key"
  value       = try(aws_kms_key.pipeline_key[0].id, null)
}

output "alias_arn" {
  description = "ARN of the KMS Key Alias"
  value       = try(aws_kms_alias.pipeline_key_alias[0].arn, null)
}

