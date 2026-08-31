variable "name" {
  description = "Web ACL name and ACL-level CloudWatch metric name. Also the default prefix for child resources and rule metrics when name_prefix / metric_name_prefix are unset."
  type        = string
}

variable "name_prefix" {
  description = "Optional prefix for child resources (IP set, regex sets, log group). Defaults to `name`."
  type        = string
  default     = null
}

variable "metric_name_prefix" {
  description = "Prefix for per-rule CloudWatch metric names. Defaults to `name`. The ACL-level metric always uses `name` so it stays independent of this prefix."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to module resources."
  type        = map(string)
  default     = {}
}

variable "default_action" {
  description = "Web ACL default action."
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be allow or block."
  }
}

variable "token_domains" {
  description = "Hostnames that may accept aws-waf-token cookies issued by Challenge."
  type        = list(string)
  default     = []
}

variable "challenge_immunity_time_seconds" {
  description = "Challenge token immunity time in seconds."
  type        = number
  default     = 300

  validation {
    condition     = var.challenge_immunity_time_seconds >= 60 && var.challenge_immunity_time_seconds <= 259200
    error_message = "challenge_immunity_time_seconds must be between 60 and 259200."
  }
}

# -----------------------------------------------------------------------------
# Trusted IPs and internal webhook bypass
# -----------------------------------------------------------------------------

variable "trusted_ip_set_arn" {
  description = "Existing CloudFront-scope IP set ARN. Takes precedence over trusted_ip_cidrs."
  type        = string
  default     = null
}

variable "trusted_ip_cidrs" {
  description = "IPv4 CIDRs used to create a CloudFront-scope IP set when trusted_ip_set_arn is unset."
  type        = list(string)
  default     = []
}

variable "bypass_header_name" {
  description = "Header name inspected for the internal webhook allow rule (WAF requires lowercase)."
  type        = string
  default     = "x-waf-bypass-secret"
}

variable "bypass_header_values" {
  description = "Exact header values that allow internal webhook traffic. Empty omits the allow rule."
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "bypass_host_suffixes" {
  description = "If non-empty, the bypass rule also requires Host to ENDS_WITH one of these suffixes (lowercased)."
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Custom rule actions (new rules default to count)
# -----------------------------------------------------------------------------

variable "header_compound_action" {
  description = "Action for the compound invalid-identity header rule (XFF AND a second header)."
  type        = string
  default     = "count"

  validation {
    condition     = contains(["count", "block"], var.header_compound_action)
    error_message = "header_compound_action must be count or block."
  }
}

variable "header_xff_only_action" {
  description = "Action for the XFF-only invalid-identity header rule."
  type        = string
  default     = "count"

  validation {
    condition     = contains(["count", "block"], var.header_xff_only_action)
    error_message = "header_xff_only_action must be count or block."
  }
}

variable "path_block_mode" {
  description = "full: all high-confidence path patterns in the action-capable rule. impossible_only: application-impossible patterns in that rule; remainder COUNT-only."
  type        = string
  default     = "full"

  validation {
    condition     = contains(["full", "impossible_only"], var.path_block_mode)
    error_message = "path_block_mode must be full or impossible_only."
  }
}

variable "path_rule_action" {
  description = "Action for the high-confidence path rule (impossible-only subset, or all patterns when path_block_mode is full)."
  type        = string
  default     = "count"

  validation {
    condition     = contains(["count", "block"], var.path_rule_action)
    error_message = "path_rule_action must be count or block."
  }
}

variable "traversal_action" {
  description = "Action for the URI traversal rule."
  type        = string
  default     = "count"

  validation {
    condition     = contains(["count", "block"], var.traversal_action)
    error_message = "traversal_action must be count or block."
  }
}

variable "soft_rate_action" {
  description = "Action for the soft dynamic rate rule. Challenge is only valid here."
  type        = string
  default     = "count"

  validation {
    condition     = contains(["count", "block", "challenge"], var.soft_rate_action)
    error_message = "soft_rate_action must be count, block, or challenge."
  }
}

variable "hard_rate_action" {
  description = "Action for the hard dynamic rate rule."
  type        = string
  default     = "count"

  validation {
    condition     = contains(["count", "block"], var.hard_rate_action)
    error_message = "hard_rate_action must be count or block."
  }
}

# -----------------------------------------------------------------------------
# Rate limits and webhook / static scope
# -----------------------------------------------------------------------------

variable "soft_rate_limit" {
  description = "Soft dynamic rate limit (requests per evaluation window)."
  type        = number
  default     = 120
}

variable "hard_rate_limit" {
  description = "Hard dynamic rate limit (requests per evaluation window)."
  type        = number
  default     = 300
}

variable "static_rate_limit" {
  description = "Static-asset observation rate limit (COUNT only)."
  type        = number
  default     = 1500
}

variable "rate_evaluation_window_sec" {
  description = "Rate-rule evaluation window in seconds."
  type        = number
  default     = 60

  validation {
    condition     = contains([60, 120, 300, 600], var.rate_evaluation_window_sec)
    error_message = "rate_evaluation_window_sec must be 60, 120, 300, or 600."
  }
}

variable "static_uri_prefixes" {
  description = "URI prefixes treated as static assets (excluded from dynamic rate rules)."
  type        = list(string)
  default     = ["/_next/static/", "/_next/image", "/images/", "/fonts/"]

  validation {
    condition     = length(var.static_uri_prefixes) >= 1
    error_message = "static_uri_prefixes must contain at least one prefix so static observation or_statement has two or more children."
  }
}

variable "webhook_exempt_paths" {
  description = "Exact URI paths excluded from the soft (Challenge-capable) rate rule."
  type        = list(string)
  default = [
    "/api/payments/stripe/webhook",
    "/api/payments/paypal/webhook",
    "/api/scheduling/google/webhook",
    "/api/fb-login/deauthorize",
    "/api-mv/payments/notification",
    "/api-mv/payments/stripe-notification",
  ]
}

variable "webhook_exempt_prefixes" {
  description = "URI prefixes excluded from the soft (Challenge-capable) rate rule."
  type        = list(string)
  default = [
    "/api-m/receiver/",
    "/api-m/myvisa-receiver/",
  ]
}

# -----------------------------------------------------------------------------
# Managed groups
# -----------------------------------------------------------------------------

variable "enable_amazon_ip_reputation" {
  description = "Include AWSManagedRulesAmazonIpReputationList."
  type        = bool
  default     = true
}

variable "amazon_ip_reputation_override_count" {
  description = "When true, the Amazon IP Reputation group uses override_action count."
  type        = bool
  default     = false
}

variable "ip_reputation_exclude_country_codes" {
  description = "Country codes excluded from the IP Reputation group via scope-down (existing CRM behavior excludes CO)."
  type        = list(string)
  default     = ["CO"]
}

variable "enable_common_rule_set" {
  description = "Include AWSManagedRulesCommonRuleSet."
  type        = bool
  default     = true
}

variable "common_rule_set_override_count" {
  description = "When true, the Common Rule Set uses override_action count."
  type        = bool
  default     = false
}

variable "common_rule_set_rule_action_overrides" {
  description = "Per-rule action overrides for the Common Rule Set. Default matches existing SizeRestrictions_BODY count."
  type = list(object({
    name   = string
    action = string
  }))
  default = [
    {
      name   = "SizeRestrictions_BODY"
      action = "count"
    }
  ]

  validation {
    condition = alltrue([
      for override in var.common_rule_set_rule_action_overrides :
      contains(["count", "allow", "block", "captcha", "challenge"], override.action)
    ])
    error_message = "Each Common Rule Set override action must be count, allow, block, captcha, or challenge."
  }
}

variable "enable_sqli" {
  description = "Include AWSManagedRulesSQLiRuleSet."
  type        = bool
  default     = true
}

variable "sqli_override_count" {
  description = "When true, the SQLi group uses override_action count."
  type        = bool
  default     = false
}

# Opt-in: this rule set was not part of the pre-module inline CRM ACL, and it costs
# 200 of the 1500 WCU ceiling. Defaulting it off keeps the CRM cutover like-for-like
# and preserves WCU headroom; adopters enable it deliberately.
variable "enable_known_bad_inputs" {
  description = "Include AWSManagedRulesKnownBadInputsRuleSet (200 WCU)."
  type        = bool
  default     = false
}

variable "known_bad_inputs_override_count" {
  description = "When true, Known Bad Inputs uses override_action count."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Existing /api/ba/ rate rule (infra-crm parity)
# -----------------------------------------------------------------------------

variable "better_auth_rate_enabled" {
  description = "Include the existing /api/ba/ rate rule."
  type        = bool
  default     = true
}

variable "better_auth_rate_limit" {
  description = "Better Auth rate limit (requests per evaluation window)."
  type        = number
  default     = 200
}

variable "better_auth_rate_path_prefix" {
  description = "URI prefix scoped by the Better Auth rate rule."
  type        = string
  default     = "/api/ba/"
}

variable "better_auth_rate_action" {
  description = "Action for the Better Auth rate rule. Defaults to block to match existing waf.tf."
  type        = string
  default     = "block"

  validation {
    condition     = contains(["count", "block"], var.better_auth_rate_action)
    error_message = "better_auth_rate_action must be count or block."
  }
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "log_group_name" {
  description = "CloudWatch log group name. Must start with aws-waf-logs-. Defaults to aws-waf-logs-<name_prefix>."
  type        = string
  default     = null

  validation {
    condition     = var.log_group_name == null || startswith(var.log_group_name, "aws-waf-logs-")
    error_message = "log_group_name must start with aws-waf-logs-."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days."
  type        = number
  default     = 30
}

variable "sampled_requests_enabled" {
  description = "Enable WAF sampled-request visibility on rules."
  type        = bool
  default     = true
}
