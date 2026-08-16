# Two CloudWatch alarms (warn + critical) on AWS/ApplicationELB.TargetResponseTime p95 for a
# given target group. Both fire to the same SNS topic; severity is conveyed via the alarm
# name + description so the slack-error-notifier Lambda can render them differently.
#
# Datapoints-to-Alarm defaults to 4 of 5 minutes over threshold. Callers with
# low traffic can raise the period/evaluation window to reduce noise.
#
# Optional warn_request_count_gate: when set, the warn alarm uses metric math so p95
# latency is only evaluated in periods where RequestCount sum meets the gate; otherwise
# the gated expression returns 0 (not breaching). Critical remains a plain p95 alarm.

resource "aws_cloudwatch_metric_alarm" "warn" {
  count      = var.enable ? 1 : 0
  alarm_name = "${var.namespace}-${var.service_label}-alb-p95-latency-warn-${var.env}"
  # JSON description carries alarm_category so slack-error-notifier routes it
  # to SlackChannel.ALB_LATENCY_ALERTS instead of the default channel. Empty
  # log_group_name skips log retrieval (no log filter on ALB metric alarms).
  alarm_description = jsonencode({
    log_group_name  = ""
    ignore_patterns = []
    alarm_category  = "alb_latency"
  })
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  datapoints_to_alarm = coalesce(var.warn_datapoints_to_alarm, var.datapoints_to_alarm)
  threshold           = var.warn_threshold_seconds
  metric_name         = var.warn_request_count_gate == null ? "TargetResponseTime" : null
  namespace           = var.warn_request_count_gate == null ? "AWS/ApplicationELB" : null
  period              = var.warn_request_count_gate == null ? var.period : null
  extended_statistic  = var.warn_request_count_gate == null ? "p95" : null
  treat_missing_data  = "notBreaching"

  dimensions = var.warn_request_count_gate == null ? {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.load_balancer_arn_suffix
  } : null

  dynamic "metric_query" {
    for_each = var.warn_request_count_gate == null ? [] : [1]
    content {
      id          = "latency"
      return_data = false

      metric {
        metric_name = "TargetResponseTime"
        namespace   = "AWS/ApplicationELB"
        period      = var.period
        stat        = "p95"

        dimensions = {
          TargetGroup  = var.target_group_arn_suffix
          LoadBalancer = var.load_balancer_arn_suffix
        }
      }
    }
  }

  dynamic "metric_query" {
    for_each = var.warn_request_count_gate == null ? [] : [1]
    content {
      id          = "requests"
      return_data = false

      metric {
        metric_name = "RequestCount"
        namespace   = "AWS/ApplicationELB"
        period      = var.period
        stat        = "Sum"

        dimensions = {
          TargetGroup  = var.target_group_arn_suffix
          LoadBalancer = var.load_balancer_arn_suffix
        }
      }
    }
  }

  dynamic "metric_query" {
    for_each = var.warn_request_count_gate == null ? [] : [1]
    content {
      id          = "gated"
      expression  = "IF(requests >= ${var.warn_request_count_gate}, latency, 0)"
      label       = "p95 latency when RequestCount >= ${var.warn_request_count_gate}"
      return_data = true
    }
  }

  alarm_actions = [var.alarm_topic_arn]
  ok_actions    = [var.alarm_topic_arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "critical" {
  count      = var.enable ? 1 : 0
  alarm_name = "${var.namespace}-${var.service_label}-alb-p95-latency-critical-${var.env}"
  alarm_description = jsonencode({
    log_group_name  = ""
    ignore_patterns = []
    alarm_category  = "alb_latency"
  })
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  datapoints_to_alarm = coalesce(var.critical_datapoints_to_alarm, var.datapoints_to_alarm)
  threshold           = var.critical_threshold_seconds
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = var.period
  extended_statistic  = "p95"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.load_balancer_arn_suffix
  }

  alarm_actions = [var.alarm_topic_arn]
  ok_actions    = [var.alarm_topic_arn]

  tags = var.tags
}
