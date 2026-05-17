output "lambda_function_name" {
  description = "Dispatcher Lambda function name."
  value       = aws_lambda_function.dispatcher.function_name
}

output "lambda_function_arn" {
  description = "Dispatcher Lambda function ARN."
  value       = aws_lambda_function.dispatcher.arn
}

output "lambda_role_arn" {
  description = "Dispatcher Lambda execution role ARN."
  value       = aws_iam_role.dispatcher.arn
}

output "log_group_name" {
  description = "Dispatcher Lambda CloudWatch log group name."
  value       = aws_cloudwatch_log_group.dispatcher.name
}
