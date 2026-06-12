variable "enable" {
  description = "Toggle alarm creation. Set false to disable without removing the module call."
  type        = bool
  default     = true
}

variable "namespace" {
  type = string
}

variable "env" {
  type = string
}

variable "service_label" {
  description = "Short label used in the alarm name and description, e.g. 'crm-backend'."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group (e.g. 'targetgroup/<name>/<id>'). Use aws_lb_target_group.<name>.arn_suffix."
  type        = string
}

variable "load_balancer_arn_suffix" {
  description = "ARN suffix of the ALB (e.g. 'app/<name>/<id>'). Use aws_lb.<name>.arn_suffix."
  type        = string
}

variable "warn_threshold_seconds" {
  description = "p95 latency threshold (seconds) for the warn alarm."
  type        = number
}

variable "critical_threshold_seconds" {
  description = "p95 latency threshold (seconds) for the critical alarm."
  type        = number
}

variable "period" {
  description = "CloudWatch metric evaluation period, in seconds."
  type        = number
  default     = 60
}

variable "evaluation_periods" {
  description = "Number of periods to evaluate."
  type        = number
  default     = 5
}

variable "datapoints_to_alarm" {
  description = "Number of breaching datapoints required to enter ALARM."
  type        = number
  default     = 4
}

variable "warn_datapoints_to_alarm" {
  description = "Number of breaching datapoints required for the warn alarm. Defaults to datapoints_to_alarm."
  type        = number
  default     = null
}

variable "critical_datapoints_to_alarm" {
  description = "Number of breaching datapoints required for the critical alarm. Defaults to datapoints_to_alarm."
  type        = number
  default     = null
}

variable "alarm_topic_arn" {
  description = "SNS topic ARN that alarm notifications publish to."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
