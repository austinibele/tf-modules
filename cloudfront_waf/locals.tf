locals {
  resource_prefix    = coalesce(var.name_prefix, var.name)
  metric_name_prefix = coalesce(var.metric_name_prefix, var.name)
  log_group_name     = coalesce(var.log_group_name, "aws-waf-logs-${local.resource_prefix}")

  create_trusted_ip_set = var.trusted_ip_set_arn == null && length(var.trusted_ip_cidrs) > 0
  trusted_ip_set_arn = var.trusted_ip_set_arn != null ? var.trusted_ip_set_arn : (
    local.create_trusted_ip_set ? aws_wafv2_ip_set.trusted[0].arn : null
  )
  trusted_ips_enabled = local.trusted_ip_set_arn != null
  bypass_enabled      = length(var.bypass_header_values) > 0

  # Verbatim from the plan's Invalid client-identity header policy (183 chars).
  invalid_identity_regex = "^\\s*(localhost(\\.localdomain)?|0(\\.[0-9]{1,3}){3}|127(\\.[0-9]{1,3}){1,3}|2130706433|0x7f000001|0177\\.0\\.0\\.1|::1|\\[::1\\]|0:0:0:0:0:0:0:1|::ffff:127(\\.[0-9]{1,3}){3}|::ffff:7f00:1)\\s*$"

  identity_second_headers = [
    "x-real-ip",
    "x-client-ip",
    "true-client-ip",
    "x-originating-ip",
    "x-azure-clientip",
    "x-azure-socketip",
  ]

  # Verbatim from the plan's High-confidence public-path policy.
  # The plan lists 8 URI regexes (plus a separate traversal statement).
  path_patterns_impossible = [
    "(^|/)\\.env($|[./])",
    "(^|/)\\.(git|svn|hg)($|/)",
    "(^|/)\\.aws/credentials$",
    "(^|/)proc/(self|[0-9]+)/environ$",
    "(^|/)etc/(passwd|shadow)$",
  ]

  path_patterns_remainder = [
    "(^|/)(package(-lock)?\\.json|pnpm-lock\\.yaml|yarn\\.lock|next\\.config\\.(js|mjs|cjs|ts)|serverless\\.ya?ml|terraform\\.tfstate(\\.backup)?|[^/]+\\.tfvars(\\.json)?)$",
    "(^|/)vendor/phpunit/phpunit/(src/)?util/php/eval-stdin\\.php$",
    "(^|/)(wp-config\\.php|\\.htaccess|\\.htpasswd|composer\\.(json|lock)|auth\\.json|appsettings(\\.[^/]+)?\\.json)$",
  ]

  traversal_regex = "(^|/)\\.\\.(/|$)"

  static_extension_regex = "\\.(css|js|mjs|map|woff|woff2|ttf|eot|png|jpg|jpeg|gif|webp|svg|ico|avif)$"

  path_remainder_rule_enabled = var.path_block_mode == "impossible_only"

  priority = {
    trusted_ips          = 10
    internal_webhooks    = 20
    header_compound      = 30
    header_xff_only      = 40
    high_confidence_path = 50
    path_remainder_count = 60
    traversal            = 70
    amazon_ip_reputation = 80
    common_rule_set      = 90
    sqli                 = 100
    known_bad_inputs     = 110
    hard_dynamic_rate    = 120
    soft_dynamic_rate    = 130
    static_observation   = 140
    better_auth_rate     = 150
  }
}
