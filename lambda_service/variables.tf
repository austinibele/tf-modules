# -----------------------------------------------------------------------------
# Required
# -----------------------------------------------------------------------------

variable "namespace" {
  description = "Project namespace (e.g., shared, crm)"
  type        = string
}

variable "env" {
  description = "Environment (dev, prod, live)"
  type        = string
}

variable "name" {
  description = "Lambda short name (e.g., slack-alert-notifier). Used in function, queue, and default HTTP route names."
  type        = string
}

# -----------------------------------------------------------------------------
# Identity / IAM
# -----------------------------------------------------------------------------

variable "description" {
  description = "Lambda (and schedule) description"
  type        = string
  default     = ""
}

variable "iam_role_name" {
  description = "IAM role name. Defaults to $${function_name}-role. Override to preserve existing role names on import."
  type        = string
  default     = null
}

variable "iam_policy_statements" {
  description = "Inline IAM statements merged into a single $${function_name}-policy (plus module-generated SQS consume / async DLQ send)."
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default = []
}

variable "managed_policy_arns" {
  description = "Additional managed policy ARNs to attach to the Lambda role"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Package / runtime
# -----------------------------------------------------------------------------

variable "package_type" {
  description = "Lambda package type. Zip uses s3_bucket/s3_key (CI replaces the placeholder). Image uses image_uri."
  type        = string
  default     = "Zip"

  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "package_type must be Zip or Image."
  }
}

variable "s3_bucket" {
  description = "S3 bucket for the Zip placeholder. Required when package_type is Zip."
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key for the Zip placeholder. Required when package_type is Zip. CI replaces the object/code."
  type        = string
  default     = null
}

variable "image_uri" {
  description = "ECR image URI. Required when package_type is Image. CI owns subsequent image updates."
  type        = string
  default     = null
}

variable "handler" {
  description = "Lambda handler (Zip only; ignored for Image)"
  type        = string
  default     = "src.handler.handler"
}

variable "runtime" {
  description = "Lambda runtime (Zip only; ignored for Image)"
  type        = string
  default     = "python3.12"
}

variable "architectures" {
  description = "Lambda instruction set architectures"
  type        = list(string)
  default     = ["x86_64"]
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

variable "environment_variables" {
  description = "Lambda environment variables. Omitted from the function when empty."
  type        = map(string)
  default     = {}
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrency. Null omits the attribute (unreserved / -1)."
  type        = number
  default     = null
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

variable "vpc_subnet_ids" {
  description = "Subnet IDs for vpc_config. Must be paired with vpc_security_group_ids."
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for vpc_config. Must be paired with vpc_subnet_ids."
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Schedule
# -----------------------------------------------------------------------------

variable "schedule_expression" {
  description = "EventBridge / Scheduler expression (e.g., cron(0 5 * * ? *)). Null creates no schedule."
  type        = string
  default     = null
}

variable "schedule_timezone" {
  description = "IANA timezone (e.g., America/New_York). When set with schedule_expression, uses EventBridge Scheduler instead of a classic UTC EventBridge rule."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# HTTP API
# -----------------------------------------------------------------------------

variable "http_api" {
  description = "Attach the function to an HTTP API v2 (AWS_IAM). Null creates no integration or routes."
  type = object({
    api_id        = string
    execution_arn = string
    route_keys    = optional(list(string))
  })
  default = null
}

# -----------------------------------------------------------------------------
# SQS trigger / async DLQ
# -----------------------------------------------------------------------------

variable "sqs_trigger" {
  description = "Create a trigger queue + DLQ + event source mapping. Mutually exclusive with enable_async_dlq (same DLQ name)."
  type = object({
    visibility_timeout_seconds         = optional(number)
    max_receive_count                  = optional(number, 3)
    batch_size                         = optional(number, 10)
    maximum_batching_window_in_seconds = optional(number, 0)
    message_retention_seconds          = optional(number, 1209600)
    receive_wait_time_seconds          = optional(number, 20)
    extra_queue_policy_statements      = optional(list(any), [])
  })
  default = null
}

variable "enable_async_dlq" {
  description = "Create $${function_name}-dlq and attach it as the function async dead_letter_config. Mutually exclusive with sqs_trigger."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Observability
# -----------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "enable_log_alarms" {
  description = "Enable log-metric alarms (only created when env is prod or live)"
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

variable "alarm_actions" {
  description = "SNS ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

variable "alarm_category" {
  description = "alarm_category written into the Errors (and log-alarm) JSON descriptions"
  type        = string
  default     = "lambda_service"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
