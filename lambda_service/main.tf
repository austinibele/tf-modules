# -----------------------------------------------------------------------------
# Lambda service: function + optional HTTP route, SQS/DLQ, schedule, alarms.
# CI owns function code; Terraform only creates the placeholder package.
# -----------------------------------------------------------------------------

locals {
  function_name = "${var.namespace}-${var.env}-${var.name}"
  log_group     = "/aws/lambda/${local.function_name}"
  iam_role_name = coalesce(var.iam_role_name, "${local.function_name}-role")

  vpc_enabled = length(var.vpc_subnet_ids) > 0 && length(var.vpc_security_group_ids) > 0

  schedule_eventbridge = var.schedule_expression != null && var.schedule_timezone == null
  schedule_scheduler   = var.schedule_expression != null && var.schedule_timezone != null

  http_route_keys = var.http_api == null ? [] : (
    var.http_api.route_keys != null ? var.http_api.route_keys : [
      "ANY /${var.name}",
      "ANY /${var.name}/{proxy+}",
    ]
  )

  extra_queue_policy_statements = var.sqs_trigger == null ? [] : var.sqs_trigger.extra_queue_policy_statements

  dlq_name = one(concat(aws_sqs_queue.dlq[*].name, aws_sqs_queue.async_dlq[*].name))
  has_dlq  = var.sqs_trigger != null || var.enable_async_dlq

  sqs_consume_statements = var.sqs_trigger == null ? [] : [{
    Effect = "Allow"
    Action = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    Resource = [aws_sqs_queue.queue[0].arn]
  }]

  async_dlq_statements = var.enable_async_dlq ? [{
    Effect   = "Allow"
    Action   = ["sqs:SendMessage"]
    Resource = [aws_sqs_queue.async_dlq[0].arn]
  }] : []

  all_policy_statements = concat(
    var.iam_policy_statements,
    local.sqs_consume_statements,
    local.async_dlq_statements,
  )
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# -----------------------------------------------------------------------------
# IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "this" {
  name = local.iam_role_name

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

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc" {
  count = local.vpc_enabled ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "this" {
  count = (length(var.iam_policy_statements) > 0 || var.sqs_trigger != null || var.enable_async_dlq) ? 1 : 0

  name = "${local.function_name}-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.all_policy_statements
  })
}

# -----------------------------------------------------------------------------
# SQS trigger (queue + DLQ + ESM)
# -----------------------------------------------------------------------------

resource "aws_sqs_queue" "dlq" {
  count = var.sqs_trigger != null ? 1 : 0

  name                      = "${local.function_name}-dlq"
  message_retention_seconds = 1209600
  tags                      = var.tags
}

resource "aws_sqs_queue" "queue" {
  count = var.sqs_trigger != null ? 1 : 0

  name                       = local.function_name
  visibility_timeout_seconds = coalesce(try(var.sqs_trigger.visibility_timeout_seconds, null), max(6 * var.timeout, 30))
  message_retention_seconds  = try(var.sqs_trigger.message_retention_seconds, 1209600)
  receive_wait_time_seconds  = try(var.sqs_trigger.receive_wait_time_seconds, 20)

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = try(var.sqs_trigger.max_receive_count, 3)
  })

  tags = var.tags
}

resource "aws_sqs_queue_policy" "queue" {
  count = length(local.extra_queue_policy_statements) > 0 ? 1 : 0

  queue_url = aws_sqs_queue.queue[0].id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.extra_queue_policy_statements
  })
}

resource "aws_lambda_event_source_mapping" "this" {
  count = var.sqs_trigger != null ? 1 : 0

  event_source_arn                   = aws_sqs_queue.queue[0].arn
  function_name                      = aws_lambda_function.this.arn
  batch_size                         = try(var.sqs_trigger.batch_size, 10)
  maximum_batching_window_in_seconds = try(var.sqs_trigger.maximum_batching_window_in_seconds, 0)
  enabled                            = true
  function_response_types            = ["ReportBatchItemFailures"]
}

# -----------------------------------------------------------------------------
# Async invocation DLQ
# -----------------------------------------------------------------------------

resource "aws_sqs_queue" "async_dlq" {
  count = var.enable_async_dlq ? 1 : 0

  name                      = "${local.function_name}-dlq"
  message_retention_seconds = 1209600
  tags                      = var.tags
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  description   = var.description
  role          = aws_iam_role.this.arn

  package_type  = var.package_type
  s3_bucket     = var.package_type == "Zip" ? var.s3_bucket : null
  s3_key        = var.package_type == "Zip" ? var.s3_key : null
  image_uri     = var.package_type == "Image" ? var.image_uri : null
  handler       = var.package_type == "Zip" ? var.handler : null
  runtime       = var.package_type == "Zip" ? var.runtime : null
  architectures = var.architectures

  timeout                        = var.timeout
  memory_size                    = var.memory_size
  reserved_concurrent_executions = var.reserved_concurrent_executions

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.this,
    aws_iam_role_policy_attachment.basic,
    aws_iam_role_policy_attachment.vpc,
    aws_iam_role_policy_attachment.managed,
  ]

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = local.vpc_enabled ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.enable_async_dlq ? [1] : []
    content {
      target_arn = aws_sqs_queue.async_dlq[0].arn
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
      s3_bucket,
      s3_key,
      s3_object_version,
      image_uri,
    ]

    precondition {
      condition     = !(var.enable_async_dlq && var.sqs_trigger != null)
      error_message = "enable_async_dlq and sqs_trigger cannot both be set; they use the same DLQ name (${local.function_name}-dlq)."
    }

    precondition {
      condition     = var.package_type != "Zip" || (var.s3_bucket != null && var.s3_bucket != "" && var.s3_key != null && var.s3_key != "")
      error_message = "package_type Zip requires s3_bucket and s3_key."
    }

    precondition {
      condition     = var.package_type != "Image" || (var.image_uri != null && var.image_uri != "")
      error_message = "package_type Image requires image_uri."
    }

    precondition {
      condition     = (length(var.vpc_subnet_ids) == 0) == (length(var.vpc_security_group_ids) == 0)
      error_message = "vpc_subnet_ids and vpc_security_group_ids must both be set or both be empty."
    }

    precondition {
      condition     = var.schedule_timezone == null || var.schedule_expression != null
      error_message = "schedule_timezone requires schedule_expression."
    }
  }
}

# -----------------------------------------------------------------------------
# EventBridge Schedule
# Without schedule_timezone: classic EventBridge rule (UTC only).
# With schedule_timezone: EventBridge Scheduler (IANA timezone, DST-aware).
# Neither is created when schedule_expression is null.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "this" {
  count = local.schedule_eventbridge ? 1 : 0

  name                = "${local.function_name}-schedule"
  description         = var.description
  schedule_expression = var.schedule_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "this" {
  count = local.schedule_eventbridge ? 1 : 0

  rule      = aws_cloudwatch_event_rule.this[0].name
  target_id = "${var.name}-target"
  arn       = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge" {
  count = local.schedule_eventbridge ? 1 : 0

  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this[0].arn
}

resource "aws_scheduler_schedule" "this" {
  count = local.schedule_scheduler ? 1 : 0

  name                         = "${local.function_name}-schedule"
  description                  = var.description
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.this.arn
    role_arn = aws_iam_role.scheduler[0].arn
  }
}

resource "aws_iam_role" "scheduler" {
  count = local.schedule_scheduler ? 1 : 0

  name = "${local.function_name}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "scheduler" {
  count = local.schedule_scheduler ? 1 : 0

  name = "${local.function_name}-scheduler-policy"
  role = aws_iam_role.scheduler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [aws_lambda_function.this.arn]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# HTTP API v2 (AWS_IAM)
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "this" {
  count = var.http_api != null ? 1 : 0

  api_id                 = var.http_api.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  for_each = toset(local.http_route_keys)

  api_id             = var.http_api.api_id
  route_key          = each.value
  authorization_type = "AWS_IAM"
  target             = "integrations/${aws_apigatewayv2_integration.this[0].id}"
}

resource "aws_lambda_permission" "apigateway" {
  count = var.http_api != null ? 1 : 0

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.http_api.execution_arn}/*/*"
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
  alarm_description = jsonencode({
    log_group_name  = aws_cloudwatch_log_group.this.name
    ignore_patterns = []
    alarm_category  = var.alarm_category
  })
  alarm_actions = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DLQ depth alarm (SQS trigger DLQ or async DLQ)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "dlq" {
  count = local.has_dlq ? 1 : 0

  alarm_name          = "${local.function_name}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = local.dlq_name
  }

  alarm_actions = var.alarm_actions
  alarm_description = jsonencode({
    log_group_name  = aws_cloudwatch_log_group.this.name
    ignore_patterns = []
    alarm_category  = "dlq"
  })

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Log-based Alarms
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
  alarm_description = jsonencode({
    log_group_name  = aws_cloudwatch_log_group.this.name
    ignore_patterns = []
    alarm_category  = var.alarm_category
  })
}
