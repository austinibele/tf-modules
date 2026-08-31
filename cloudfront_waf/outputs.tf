output "web_acl_arn" {
  description = "ARN of the CloudFront-scope Web ACL."
  value       = aws_wafv2_web_acl.this.arn
}

output "log_group_name" {
  description = "CloudWatch log group receiving WAF logs."
  value       = aws_cloudwatch_log_group.waf.name
}

output "rule_actions" {
  description = "Rule name to action mode for plan review. omitted means the rule is not created."
  value = {
    AllowTrustedIPs                       = local.trusted_ips_enabled ? "allow" : "omitted"
    AllowInternalWebhooks                 = local.bypass_enabled ? "allow" : "omitted"
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
  }
}
