output "alarm_names" {
  value = [for a in aws_cloudwatch_metric_alarm.this : a.alarm_name]
}

output "metric_filter_names" {
  value = [for f in aws_cloudwatch_log_metric_filter.this : f.name]
}


