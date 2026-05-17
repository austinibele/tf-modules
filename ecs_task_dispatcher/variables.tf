variable "function_name" {
  description = "Stable Lambda function name."
  type        = string
}

variable "allowed_cluster_arns" {
  description = "ECS clusters this dispatcher may run tasks on."
  type        = list(string)
}

variable "allowed_task_definition_arns" {
  description = "Task definition ARN patterns this dispatcher may run, usually family ARNs ending in :*."
  type        = list(string)
}

variable "pass_role_arns" {
  description = "IAM roles this dispatcher may pass to ECS tasks."
  type        = list(string)
}

variable "alarm_actions" {
  description = "SNS topic ARNs for dispatcher alarms."
  type        = list(string)
  default     = []
}

variable "log_alarm_filters" {
  description = "CloudWatch Logs metric filter patterns for dispatcher logs."
  type = list(object({
    id      = string
    pattern = string
  }))
  default = []
}

variable "enable_log_alarms" {
  description = "Whether to create log metric alarms for dispatcher logs."
  type        = bool
  default     = true
}

variable "log_alarm_name_prefix" {
  description = "Metric/alarm name prefix for log-based alarms."
  type        = string
}

variable "log_alarm_description" {
  description = "Alarm description for log-based alarms, usually JSON consumed by slack-error-notifier."
  type        = string
  default     = ""
}

variable "metric_alarm_name_prefix" {
  description = "Name prefix for Lambda metric alarms."
  type        = string
}

variable "metric_namespace" {
  description = "CloudWatch custom metric namespace for log metric filters."
  type        = string
}

variable "env" {
  description = "Environment name used in log metric alarm names."
  type        = string
}

variable "timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Python logger level."
  type        = string
  default     = "INFO"
}

variable "tags" {
  description = "Tags to apply to supported resources."
  type        = map(string)
  default     = {}
}
