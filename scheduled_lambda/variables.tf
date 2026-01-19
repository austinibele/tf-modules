# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "namespace" {
  description = "Project namespace (e.g., crm)"
  type        = string
}

variable "env" {
  description = "Environment (dev, prod)"
  type        = string
}

variable "name" {
  description = "Lambda short name (e.g., force-redeploy, ecr-cleanup)"
  type        = string
}

variable "description" {
  description = "EventBridge rule description"
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge schedule expression (e.g., cron(0 5 * * ? *))"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket containing the Lambda zip"
  type        = string
}

variable "s3_key" {
  description = "S3 key for the Lambda zip"
  type        = string
}

variable "environment_variables" {
  description = "Lambda environment variables"
  type        = map(string)
  default     = {}
}

variable "iam_policy_statements" {
  description = "Additional IAM policy statements (beyond CloudWatch Logs)"
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default = []
}

variable "alarm_actions" {
  description = "SNS ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Optional Variables with Defaults
# -----------------------------------------------------------------------------

variable "handler" {
  description = "Lambda handler"
  type        = string
  default     = "lambda_function.handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "enable_log_alarms" {
  description = "Enable log-based alarms"
  type        = bool
  default     = true
}

variable "log_alarm_filters" {
  description = "Log alarm filter patterns"
  type = list(object({
    id      = string
    pattern = string
  }))
  default = [
    { id = "filter-1", pattern = "ERROR" },
    { id = "filter-2", pattern = "error" },
  ]
}
