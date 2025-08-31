# This module defines an ECS task definition for manual/one-off tasks.
# 
# Important note about networking:
# - For Fargate tasks, AWS requires the use of 'awsvpc' network mode
# - We cannot hardcode VPC/security group settings in the task definition
# - Network configuration (VPC, subnets, security groups) must be provided at runtime
# - We don't create an ECS service because:
#   1. Services maintain a desired count of running tasks
#   2. These are manual tasks that should only run when explicitly started
#   3. Services would create unnecessary infrastructure and costs
#
# Instead, we:
# 1. Define the task with required 'awsvpc' network mode
# 2. Provide network configuration through outputs
# 3. Use this configuration when running tasks via AWS CLI, EventBridge, etc.


variable "task_name" {
    type        = string
    description = "Name of the task (e.g. 'classify-orders')"
}

variable "script_path" {
    type        = string
    default     = null
    description = "Path to the script to run (e.g. 'bin/db-utils/pg-dump-ecs.sh')"
}

variable "entrypoint_command" {
    type        = string
    default     = null
    description = "Entrypoint command for the task"
}

variable "inputs" {
    type = object({
        namespace     = string
        env           = string
        cpu           = optional(number, 1024)
        memory        = optional(number, 2048)
        image_uri     = string
        aws_region    = string
        log_group_name = string
    })
    description = "Common inputs required for all manual tasks"
}

variable "environment_map" {
    type        = map(string)
    default     = null
    description = "Environment variables as a map (preferred)"
}

variable "execution_role_arn" {
    type        = string
    description = "ARN of the IAM role that grants the ECS task execution permissions"
}

variable "task_role_arn" {
    type        = string
    description = "ARN of the IAM role that grants the ECS task runtime permissions"
}

locals {
    command_to_run     = coalesce(var.entrypoint_command, var.script_path)
    env_from_map       = var.environment_map == null ? [] : [for k, v in var.environment_map : { name = k, value = tostring(v) }]
    environment_values = concat([
        {
            name  = "ENV"
            value = var.inputs.env
        },
        {
            name  = "LOCAL_MODE"
            value = "false"
        }
    ], local.env_from_map)
}

resource "aws_ecs_task_definition" "manual_task" {
    family                   = "${var.inputs.namespace}-${var.task_name}-${var.inputs.env}"
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    execution_role_arn       = var.execution_role_arn
    task_role_arn            = var.task_role_arn
    cpu                      = tostring(var.inputs.cpu)
    memory                   = tostring(var.inputs.memory)

    container_definitions = jsonencode([
        {
            name              = "${var.inputs.namespace}-${var.task_name}-${var.inputs.env}",
            image             = var.inputs.image_uri,
            essential         = true,
            memory            = var.inputs.memory,
            memoryReservation = 256,
            entryPoint        = ["/bin/sh", "-c"],
            command           = [
                "${local.command_to_run} 2>&1"
            ],
            environment       = local.environment_values,
            logConfiguration = {
                logDriver = "awslogs",
                options = {
                    "awslogs-group"         = var.inputs.log_group_name,
                    "awslogs-region"        = var.inputs.aws_region,
                    "awslogs-stream-prefix" = "${var.inputs.namespace}-${var.task_name}-${var.inputs.env}",
                    "awslogs-create-group"  = "true",
                    "mode"                  = "non-blocking"
                }
            }
        }
    ])

    tags = var.tags
}

output "task_definition_arn" {
    value       = aws_ecs_task_definition.manual_task.arn
    description = "ARN of the created task definition"
}


# -----------------------------------------------------------------------------
# Optional EventBridge schedule to run the manual task on a cron
# -----------------------------------------------------------------------------

variable "schedule_enabled" {
    type        = bool
    default     = false
    description = "Enable EventBridge schedule for this task"
}

variable "schedule_expression" {
    type        = string
    default     = null
    description = "EventBridge schedule expression, e.g. cron(0 2 * * ? *)"
}

variable "cluster_arn" {
    type        = string
    default     = null
    description = "ECS cluster ARN to run the scheduled task in"
}

variable "schedule_task_count" {
    type        = number
    default     = 1
    description = "Number of tasks to run for the schedule trigger"
}

variable "schedule_network" {
    type = object({
        subnets          = list(string)
        security_groups  = list(string)
        assign_public_ip = bool
    })
    default     = null
    description = "Network configuration for the scheduled run (awsvpc)"
}

variable "events_role_arn" {
    type        = string
    default     = null
    description = "Pre-existing IAM role for EventBridge to run ECS tasks; if null, module creates one"
}

variable "launch_type" {
    type        = string
    default     = "FARGATE"
    description = "Launch type for scheduled runs"
}

variable "tags" {
    type        = map(string)
    default     = null
    description = "Optional tags to apply to supported resources"
}

locals {
    create_events_role = var.schedule_enabled && var.events_role_arn == null
}

resource "aws_iam_role" "events_role" {
    count = local.create_events_role ? 1 : 0

    name = "${var.inputs.namespace}-${var.inputs.env}-${var.task_name}-events-ecs-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "events.amazonaws.com"
                }
            }
        ]
    })

    tags = var.tags
}

resource "aws_iam_role_policy" "events_run_task_policy" {
    count = local.create_events_role ? 1 : 0

    name = "${var.inputs.namespace}-${var.inputs.env}-${var.task_name}-events-run-task-policy"
    role = aws_iam_role.events_role[0].id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow",
                Action = "ecs:RunTask",
                Resource = aws_ecs_task_definition.manual_task.arn
            },
            {
                Effect = "Allow",
                Action = "iam:PassRole",
                Resource = [
                    var.execution_role_arn,
                    var.task_role_arn
                ]
            }
        ]
    })
}

locals {
    events_role_arn_effective = coalesce(var.events_role_arn, try(aws_iam_role.events_role[0].arn, null))
}

resource "aws_cloudwatch_event_rule" "schedule" {
    count = var.schedule_enabled ? 1 : 0

    name                = "${var.inputs.namespace}-${var.inputs.env}-${var.task_name}-schedule"
    description         = "Triggers ${var.task_name} on a schedule"
    schedule_expression = var.schedule_expression

    tags = var.tags
}

resource "aws_cloudwatch_event_target" "schedule_target" {
    count = var.schedule_enabled ? 1 : 0

    rule      = aws_cloudwatch_event_rule.schedule[0].name
    target_id = "Run${var.task_name}"
    arn       = var.cluster_arn
    role_arn  = local.events_role_arn_effective

    ecs_target {
        task_count          = var.schedule_task_count
        task_definition_arn = aws_ecs_task_definition.manual_task.arn
        launch_type         = var.launch_type

        network_configuration {
            subnets          = var.schedule_network.subnets
            security_groups  = var.schedule_network.security_groups
            assign_public_ip = var.schedule_network.assign_public_ip
        }
    }
}

output "schedule_rule_arn" {
    value       = try(aws_cloudwatch_event_rule.schedule[0].arn, null)
    description = "ARN of the schedule rule (if enabled)"
}

output "events_role_arn_effective" {
    value       = local.events_role_arn_effective
    description = "IAM role used by EventBridge to run the task (created or provided)"
}


