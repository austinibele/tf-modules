output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "function_invoke_arn" {
  description = "Lambda invoke ARN (API Gateway integrations)"
  value       = aws_lambda_function.this.invoke_arn
}

output "role_arn" {
  description = "Lambda IAM role ARN"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Lambda IAM role name"
  value       = aws_iam_role.this.name
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.this.name
}

output "queue_url" {
  description = "SQS trigger queue URL (null when sqs_trigger is unset)"
  value       = one(aws_sqs_queue.queue[*].url)
}

output "queue_arn" {
  description = "SQS trigger queue ARN (null when sqs_trigger is unset)"
  value       = one(aws_sqs_queue.queue[*].arn)
}

output "queue_name" {
  description = "SQS trigger queue name (null when sqs_trigger is unset)"
  value       = one(aws_sqs_queue.queue[*].name)
}

output "dlq_arn" {
  description = "DLQ ARN: SQS trigger DLQ if present, otherwise async DLQ (null when neither is created)"
  value       = one(concat(aws_sqs_queue.dlq[*].arn, aws_sqs_queue.async_dlq[*].arn))
}

output "dlq_name" {
  description = "DLQ name: SQS trigger DLQ if present, otherwise async DLQ (null when neither is created)"
  value       = one(concat(aws_sqs_queue.dlq[*].name, aws_sqs_queue.async_dlq[*].name))
}

output "route_keys" {
  description = "HTTP API route keys attached to this function (empty when http_api is unset)"
  value       = local.http_route_keys
}

output "schedule_arn" {
  description = "EventBridge rule ARN or Scheduler schedule ARN (null when no schedule)"
  value       = one(concat(aws_cloudwatch_event_rule.this[*].arn, aws_scheduler_schedule.this[*].arn))
}
