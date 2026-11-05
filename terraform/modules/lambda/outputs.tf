output "dispatcher_function_name" {
  description = "Name of Dispatcher Lambda Function"
  value       = aws_lambda_function.dispatcher.function_name
}

output "dispatcher_function_arn" {
  description = "ARN of Dispatcher Lambda Function"
  value       = aws_lambda_function.dispatcher.arn
}

output "processor_function_name" {
  description = "Name of Processor Lambda Function"
  value       = aws_lambda_function.processor.function_name
}

output "processor_function_arn" {
  description = "ARN of Processor Lambda Function"
  value       = aws_lambda_function.processor.arn
}

output "dispatcher_role_arn" {
  description = "ARN of Dispatcher Lambda Execution Role"
  value       = aws_iam_role.dispatcher_lambda_role.arn
}

output "processor_role_arn" {
  description = "ARN of Processor Lambda Execution Role"
  value       = aws_iam_role.processor_lambda_role.arn
}

output "transcribe_role_arn" {
  description = "ARN of Transcribe Data Access Role"
  value       = aws_iam_role.transcribe_data_access_role.arn
}

