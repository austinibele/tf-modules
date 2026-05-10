# Two CloudWatch alarms (warn + critical) on AWS/ApplicationELB.TargetResponseTime p95 for a
# given target group. Both fire to the same SNS topic; severity is conveyed via the alarm
# name + description so the slack-error-notifier Lambda can render them differently.
#
# Datapoints-to-Alarm: 4 of 5 minutes over threshold. Avoids paging on a single transient
# minute while keeping mean-time-to-detect at ~4 min.

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
  evaluation_periods  = 5
  datapoints_to_alarm = 4
  threshold           = var.warn_threshold_seconds
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
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

resource "aws_cloudwatch_metric_alarm" "critical" {
  count      = var.enable ? 1 : 0
  alarm_name = "${var.namespace}-${var.service_label}-alb-p95-latency-critical-${var.env}"
  alarm_description = jsonencode({
    log_group_name  = ""
    ignore_patterns = []
    alarm_category  = "alb_latency"
  })
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 4
  threshold           = var.critical_threshold_seconds
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
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
