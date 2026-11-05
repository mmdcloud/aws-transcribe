output "rule_name" {
  description = "Name of EventBridge rule"
  value       = aws_cloudwatch_event_rule.transcribe_state_change.name
}

output "rule_arn" {
  description = "ARN of EventBridge rule"
  value       = aws_cloudwatch_event_rule.transcribe_state_change.arn
}

