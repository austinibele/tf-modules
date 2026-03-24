# -----------------------------------------------------------------------------
# Scheduled Lambda Module
# Creates a Lambda function triggered by EventBridge on a cron schedule,
# with CloudWatch logs, IAM role, and alarms.
# -----------------------------------------------------------------------------

locals {
  function_name = "${var.namespace}-${var.env}-${var.name}"
  log_group     = "/aws/lambda/${local.function_name}"

  # Merge logs permissions with caller-supplied statements
  base_log_statement = {
    Effect = "Allow"
    Action = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    Resource = ["arn:aws:logs:*:*:*"]
  }

  all_policy_statements = concat([local.base_log_statement], var.iam_policy_statements)
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# -----------------------------------------------------------------------------
# EventBridge Schedule
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "this" {
  name                = "${local.function_name}-schedule"
  description         = var.description
  schedule_expression = var.schedule_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "this" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "${var.name}-target"
  arn       = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  role          = aws_iam_role.this.arn

  s3_bucket    = var.s3_bucket
  s3_key       = var.s3_key
  package_type = "Zip"

  handler     = var.handler
  runtime     = var.runtime
  timeout     = var.timeout
  memory_size = var.memory_size

  depends_on = [
    aws_iam_role_policy.this,
    aws_cloudwatch_log_group.this,
  ]

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM Role & Policy
# -----------------------------------------------------------------------------

resource "aws_iam_role" "this" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "this" {
  name = "${local.function_name}-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.all_policy_statements
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Metric Alarm (Lambda Errors)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda errors for ${local.function_name}"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Log-based Alarms (via external module)
# -----------------------------------------------------------------------------

module "log_alarms" {
  source         = "../cloudwatch_log_metric_alarms"
  enable         = var.enable_log_alarms && contains(["prod", "live"], var.env)
  namespace      = var.namespace
  env            = var.env
  log_group_name = aws_cloudwatch_log_group.this.name
  name_prefix    = "${local.function_name}-log-error-count"
  alarm_actions  = var.alarm_actions
  filters        = var.log_alarm_filters
}
