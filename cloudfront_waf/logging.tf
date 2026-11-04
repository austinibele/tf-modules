resource "aws_cloudwatch_log_group" "waf" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# WAF logs every request header by default. The bypass header's value is the
# allow rule's secret and a session cookie or bearer token is a credential, so
# their values are redacted; the header names and every other field stay.
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.this.arn

  dynamic "redacted_fields" {
    for_each = toset(distinct(concat([lower(var.bypass_header_name)], var.log_redacted_header_names)))
    content {
      single_header {
        name = redacted_fields.value
      }
    }
  }
}
