output "alerts_topic_arn" {
  description = "ARN of SNS Topic for operational alerts"
  value       = try(aws_sns_topic.pipeline_alerts[0].arn, null)
}

output "dashboard_name" {
  description = "Name of the CloudWatch Operational Dashboard"
  value       = aws_cloudwatch_dashboard.pipeline_dashboard.dashboard_name
}

