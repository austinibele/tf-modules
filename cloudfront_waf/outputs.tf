output "web_acl_arn" {
  description = "ARN of the CloudFront-scope Web ACL."
  value       = aws_wafv2_web_acl.this.arn
}

output "log_group_name" {
  description = "CloudWatch log group receiving WAF logs."
  value       = aws_cloudwatch_log_group.waf.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group receiving WAF logs."
  value       = aws_cloudwatch_log_group.waf.arn
}

output "probe_ban_ip_sets" {
  description = "The probe-ban IP sets as { ipv4 = { arn, id, name }, ipv6 = { ... } }, or null when probe_ban_enabled is false."
  value = var.probe_ban_enabled ? {
    for version, set in aws_wafv2_ip_set.probe_ban : version => { arn = set.arn, id = set.id, name = set.name }
  } : null
}

output "rule_actions" {
  description = "Rule name to action mode for plan review. omitted means the rule is not created."
  value = merge({
    AllowTrustedIPs                       = local.trusted_ips_enabled ? "allow" : "omitted"
    AllowInternalWebhooks                 = local.bypass_enabled ? "allow" : "omitted"
    BlockProbeBan                         = var.probe_ban_enabled ? "block" : "omitted"
    InvalidClientIdentityCompound         = var.header_compound_action
    InvalidClientIdentityXffOnly          = var.header_xff_only_action
    HighConfidencePath                    = var.path_rule_action
    HighConfidencePathRemainder           = local.path_remainder_rule_enabled ? "count" : "omitted"
    Traversal                             = var.traversal_action
    AWSManagedRulesAmazonIpReputationList = var.enable_amazon_ip_reputation ? (var.amazon_ip_reputation_override_count ? "count" : "none") : "omitted"
    AWSManagedRulesCommonRuleSet          = var.enable_common_rule_set ? (var.common_rule_set_override_count ? "count" : "none") : "omitted"
    AWSManagedRulesSQLiRuleSet            = var.enable_sqli ? (var.sqli_override_count ? "count" : "none") : "omitted"
    AWSManagedRulesKnownBadInputsRuleSet  = var.enable_known_bad_inputs ? (var.known_bad_inputs_override_count ? "count" : "none") : "omitted"
    HardDynamicRate                       = var.hard_rate_action
    SoftDynamicRate                       = var.soft_rate_action
    StaticObservationRate                 = "count"
    RateLimitBetterAuth                   = var.better_auth_rate_enabled ? var.better_auth_rate_action : "omitted"
  }, { for entry in var.host_ip_allowlists : "BlockHost-${entry.name}-UnlistedIPs" => "block" }, { for entry in var.host_path_rate_limits : "RateLimit-${entry.name}" => entry.action }, { for entry in var.label_blocks : "LabelBlock-${entry.name}" => "block" }, { for entry in var.label_blocks : "LabelBlockExempt-${entry.name}" => "count" if length(entry.except_hosts) > 0 })
}
