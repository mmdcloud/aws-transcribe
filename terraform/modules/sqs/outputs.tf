output "ingestion_queue_arn" {
  description = "ARN of Ingestion SQS Queue"
  value       = aws_sqs_queue.ingestion_queue.arn
}

output "ingestion_queue_url" {
  description = "URL of Ingestion SQS Queue"
  value       = aws_sqs_queue.ingestion_queue.id
}

output "ingestion_queue_name" {
  description = "Name of Ingestion SQS Queue"
  value       = aws_sqs_queue.ingestion_queue.name
}

output "ingestion_dlq_arn" {
  description = "ARN of Ingestion Dead Letter Queue"
  value       = aws_sqs_queue.ingestion_dlq.arn
}

output "ingestion_dlq_url" {
  description = "URL of Ingestion Dead Letter Queue"
  value       = aws_sqs_queue.ingestion_dlq.id
}

output "ingestion_dlq_name" {
  description = "Name of Ingestion Dead Letter Queue"
  value       = aws_sqs_queue.ingestion_dlq.name
}

output "processing_queue_arn" {
  description = "ARN of Processing SQS Queue"
  value       = aws_sqs_queue.processing_queue.arn
}

output "processing_queue_url" {
  description = "URL of Processing SQS Queue"
  value       = aws_sqs_queue.processing_queue.id
}

output "processing_queue_name" {
  description = "Name of Processing SQS Queue"
  value       = aws_sqs_queue.processing_queue.name
}

output "processing_dlq_arn" {
  description = "ARN of Processing Dead Letter Queue"
  value       = aws_sqs_queue.processing_dlq.arn
}

output "processing_dlq_url" {
  description = "URL of Processing Dead Letter Queue"
  value       = aws_sqs_queue.processing_dlq.id
}

output "processing_dlq_name" {
  description = "Name of Processing Dead Letter Queue"
  value       = aws_sqs_queue.processing_dlq.name
}

