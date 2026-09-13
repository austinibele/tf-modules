# lambda_service

Reusable Lambda: function + IAM + log group + Errors alarm, with optional HTTP API routes, SQS trigger + DLQ, async DLQ, and EventBridge / Scheduler.

Terraform creates the function with a **placeholder** package (`s3_bucket`/`s3_key` or `image_uri`). CI owns subsequent code/image updates. The function ignores changes to `filename`, `source_code_hash`, `s3_bucket`, `s3_key`, `s3_object_version`, and `image_uri`.

Function name: `${namespace}-${env}-${name}`. Log group: `/aws/lambda/${function_name}`.

## Examples

### HTTP + SQS

```hcl
module "slack_alert" {
  source = "git::https://github.com/austinibele/tf-modules.git//lambda_service?ref=main"

  namespace = var.namespace
  env       = var.env
  name      = "slack-alert-notifier"
  timeout   = 30

  iam_role_name = "${var.namespace}-${var.env}-slack-alert-notifier-lambda-role"

  s3_bucket = var.s3_lambda_zips_bucket_name
  s3_key    = "placeholders/slack-alert-notifier.zip"

  http_api = {
    api_id        = aws_apigatewayv2_api.lambda_api.id
    execution_arn = aws_apigatewayv2_api.lambda_api.execution_arn
    # defaults: route_keys ["ANY /slack-alert-notifier", "ANY /slack-alert-notifier/{proxy+}"], authorization_type AWS_IAM
    # authorization_type = "NONE"  # unauthenticated public routes
  }

  sqs_trigger = {
    visibility_timeout_seconds = 180
    extra_queue_policy_statements = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.namespace}-${var.env}-slack-alert-notifier"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/*"
          }
        }
      }
    ]
  }

  iam_policy_statements = [
    {
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = [aws_sqs_queue.delivery_receipt.arn]
    }
  ]

  alarm_actions = [aws_sns_topic.alarms.arn]
  tags          = local.tags
}
```

### Scheduled

```hcl
module "force_redeploy" {
  source = "git::https://github.com/austinibele/tf-modules.git//lambda_service?ref=main"

  namespace   = var.namespace
  env         = var.env
  name        = "force-redeploy"
  description = "Force ECS redeploy on a cron"

  s3_bucket = var.s3_lambda_zips_bucket_name
  s3_key    = "placeholders/force-redeploy.zip"

  schedule_expression = "cron(0 5 * * ? *)"
  schedule_timezone   = "America/New_York" # omit for a classic UTC EventBridge rule

  alarm_actions = [aws_sns_topic.alarms.arn]
  tags          = local.tags
}
```

### Image

```hcl
module "ads_clustering" {
  source = "git::https://github.com/austinibele/tf-modules.git//lambda_service?ref=main"

  namespace    = var.namespace
  env          = var.env
  name         = "ads-clustering"
  package_type = "Image"
  image_uri    = var.ads_workflow_lambda_image_uri
  timeout      = 900
  memory_size  = 3008

  environment_variables = local.ads_clustering_env
  alarm_actions         = [aws_sns_topic.alarms.arn]
  tags                  = local.tags
}
```

`enable_async_dlq` and `sqs_trigger` are mutually exclusive (same `${function_name}-dlq` name).

## Inputs

| Name | Default | Notes |
| --- | --- | --- |
| `namespace`, `env`, `name` | required | Function name `${namespace}-${env}-${name}` |
| `description` | `""` | |
| `iam_role_name` | `null` → `${function_name}-role` | Preserve existing roles on import |
| `package_type` | `"Zip"` | `Zip` or `Image` |
| `s3_bucket`, `s3_key` | `null` | Required for Zip |
| `image_uri` | `null` | Required for Image |
| `handler` | `"src.handler.handler"` | Zip only |
| `runtime` | `"python3.12"` | Zip only |
| `architectures` | `["x86_64"]` | |
| `timeout` | `30` | |
| `memory_size` | `128` | |
| `environment_variables` | `{}` | |
| `reserved_concurrent_executions` | `null` | Omit = unreserved |
| `vpc_subnet_ids`, `vpc_security_group_ids` | `[]` | Both set → `vpc_config` + VPC access role |
| `iam_policy_statements` | `[]` | Merged with SQS consume / async DLQ send into one inline policy |
| `managed_policy_arns` | `[]` | |
| `schedule_expression` | `null` | Null = no schedule |
| `schedule_timezone` | `null` | Set → EventBridge Scheduler |
| `http_api` | `null` | `{ api_id, execution_arn, route_keys?, authorization_type? }` (`AWS_IAM` default; `NONE` allowed) |
| `sqs_trigger` | `null` | Queue + DLQ + ESM (`ReportBatchItemFailures`) |
| `enable_async_dlq` | `false` | Async `dead_letter_config` |
| `log_retention_days` | `14` | |
| `enable_log_alarms` | `true` | Active only in `prod`/`live` |
| `log_alarm_filters` | `ERROR` / `error` | |
| `alarm_actions` | `[]` | |
| `alarm_category` | `"lambda_service"` | Errors + log alarms |
| `tags` | `{}` | |

## Outputs

`function_arn`, `function_name`, `function_invoke_arn`, `role_arn`, `role_name`, `log_group_name`, `queue_url`, `queue_arn`, `queue_name`, `dlq_arn`, `dlq_name`, `route_keys`, `schedule_arn`

Queue / DLQ / schedule outputs are `null` when that feature is unused. `dlq_*` prefers the SQS-trigger DLQ, otherwise the async DLQ. `route_keys` is `[]` when `http_api` is unset.
