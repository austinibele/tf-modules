locals {
  log_group_name = "/aws/lambda/${var.function_name}"
  package_path   = "${path.module}/${var.function_name}.zip"
}

data "archive_file" "dispatcher" {
  type        = "zip"
  source_file = "${path.module}/lambda/dispatcher.py"
  output_path = local.package_path
}

resource "aws_cloudwatch_log_group" "dispatcher" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_iam_role" "dispatcher" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.dispatcher.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dispatcher" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.dispatcher.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:ListTaskDefinitions",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "ecs:RunTask"
        Resource = var.allowed_task_definition_arns
        Condition = {
          ArnEquals = {
            "ecs:cluster" = var.allowed_cluster_arns
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = var.pass_role_arns
      }
    ]
  })
}

resource "aws_lambda_function" "dispatcher" {
  function_name    = var.function_name
  role             = aws_iam_role.dispatcher.arn
  filename         = data.archive_file.dispatcher.output_path
  source_code_hash = data.archive_file.dispatcher.output_base64sha256
  handler          = "dispatcher.handler"
  runtime          = "python3.12"
  timeout          = var.timeout
  memory_size      = var.memory_size

  environment {
    variables = {
      LOG_LEVEL = var.log_level
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.dispatcher,
    aws_iam_role_policy.dispatcher,
    aws_iam_role_policy_attachment.basic_execution,
  ]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${var.metric_alarm_name_prefix}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = var.alarm_actions
  alarm_description = jsonencode({
    log_group_name  = aws_cloudwatch_log_group.dispatcher.name
    ignore_patterns = []
    alarm_category  = "ecs_dispatcher"
  })

  dimensions = {
    FunctionName = aws_lambda_function.dispatcher.function_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "throttles" {
  alarm_name          = "${var.metric_alarm_name_prefix}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = var.alarm_actions
  alarm_description = jsonencode({
    log_group_name  = aws_cloudwatch_log_group.dispatcher.name
    ignore_patterns = []
    alarm_category  = "ecs_dispatcher"
  })

  dimensions = {
    FunctionName = aws_lambda_function.dispatcher.function_name
  }

  tags = var.tags
}

module "log_alarms" {
  source              = "../cloudwatch_log_metric_alarms"
  enable              = var.enable_log_alarms && length(var.log_alarm_filters) > 0
  namespace           = var.metric_namespace
  env                 = var.env
  log_group_name      = aws_cloudwatch_log_group.dispatcher.name
  name_prefix         = var.log_alarm_name_prefix
  alarm_actions       = var.alarm_actions
  filters             = var.log_alarm_filters
  include_id_in_names = true
  alarm_description = var.log_alarm_description != "" ? var.log_alarm_description : jsonencode({
    log_group_name  = aws_cloudwatch_log_group.dispatcher.name
    ignore_patterns = []
    alarm_category  = "ecs_dispatcher"
  })
}
