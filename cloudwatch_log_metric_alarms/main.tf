locals {
  filters_map = var.enable ? { for f in var.filters : f.id => f } : {}
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each       = local.filters_map
  name           = var.include_id_in_names ? "${var.name_prefix}-${each.key}-${var.env}" : "${var.name_prefix}-${var.env}"
  pattern        = each.value.pattern
  log_group_name = var.log_group_name

  metric_transformation {
    name      = var.include_id_in_names ? "${var.name_prefix}-${each.key}-${var.env}" : "${var.name_prefix}-${var.env}"
    namespace = var.namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each                 = aws_cloudwatch_log_metric_filter.this
  alarm_name               = each.value.metric_transformation[0].name
  comparison_operator      = "GreaterThanOrEqualToThreshold"
  evaluation_periods       = var.evaluation_periods
  metric_name              = each.value.metric_transformation[0].name
  namespace                = var.namespace
  period                   = var.period
  statistic                = var.statistic
  threshold                = var.threshold

  alarm_actions      = var.alarm_actions
  alarm_description  = var.log_group_name
}


