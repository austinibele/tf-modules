# WCU budget (plan: stay ≤ 1500; Linux rule set intentionally omitted)
#
# | Component                                              | WCU        |
# | ------------------------------------------------------ | ---------: |
# | AWSManagedRulesCommonRuleSet                           |        700 |
# | AWSManagedRulesSQLiRuleSet                             |        200 |
# | AWSManagedRulesAmazonIpReputationList                  |         25 |
# | AWSManagedRulesKnownBadInputsRuleSet (opt-in, off)     |      (200) |
# | Custom: header (compound + XFF-only), path, traversal, |            |
# | three rate rules with scope-downs, allow rules         | ~150–250 |
# | Projected total (Known Bad Inputs off)                 | ~1,075–1,175 |
# | Projected total (Known Bad Inputs on)                  | ~1,275–1,375 |
#
# Do not add AWSManagedRulesLinuxRuleSet (200 WCU). Anonymous IP List and
# Common Bot Control are deferred (cost + WCU).

resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = "CLOUDFRONT"

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  challenge_config {
    immunity_time_property {
      immunity_time = var.challenge_immunity_time_seconds
    }
  }

  token_domains = length(var.token_domains) > 0 ? var.token_domains : null

  # ---------------------------------------------------------------------------
  # 10 — Trusted IPs
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = local.trusted_ips_enabled ? [1] : []
    content {
      name     = "AllowTrustedIPs"
      priority = local.priority.trusted_ips

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = local.trusted_ip_set_arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.metric_name_prefix}-allowed-ips"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ---------------------------------------------------------------------------
  # 20 — Internal webhook bypass header
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = local.bypass_enabled ? [1] : []
    content {
      name     = "AllowInternalWebhooks"
      priority = local.priority.internal_webhooks

      action {
        allow {}
      }

      statement {
        dynamic "byte_match_statement" {
          for_each = length(var.bypass_header_values) == 1 && length(var.bypass_host_suffixes) == 0 ? [1] : []
          content {
            search_string         = var.bypass_header_values[0]
            positional_constraint = "EXACTLY"
            field_to_match {
              single_header {
                name = var.bypass_header_name
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }

        dynamic "or_statement" {
          for_each = length(var.bypass_header_values) > 1 && length(var.bypass_host_suffixes) == 0 ? [1] : []
          content {
            dynamic "statement" {
              for_each = var.bypass_header_values
              content {
                byte_match_statement {
                  search_string         = statement.value
                  positional_constraint = "EXACTLY"
                  field_to_match {
                    single_header {
                      name = var.bypass_header_name
                    }
                  }
                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }
        }

        dynamic "and_statement" {
          for_each = length(var.bypass_host_suffixes) > 0 ? [1] : []
          content {
            dynamic "statement" {
              for_each = length(var.bypass_header_values) == 1 ? [1] : []
              content {
                byte_match_statement {
                  search_string         = var.bypass_header_values[0]
                  positional_constraint = "EXACTLY"
                  field_to_match {
                    single_header {
                      name = var.bypass_header_name
                    }
                  }
                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }

            dynamic "statement" {
              for_each = length(var.bypass_header_values) > 1 ? [1] : []
              content {
                or_statement {
                  dynamic "statement" {
                    for_each = var.bypass_header_values
                    content {
                      byte_match_statement {
                        search_string         = statement.value
                        positional_constraint = "EXACTLY"
                        field_to_match {
                          single_header {
                            name = var.bypass_header_name
                          }
                        }
                        text_transformation {
                          priority = 0
                          type     = "NONE"
                        }
                      }
                    }
                  }
                }
              }
            }

            dynamic "statement" {
              for_each = length(var.bypass_host_suffixes) == 1 ? [1] : []
              content {
                byte_match_statement {
                  search_string         = lower(var.bypass_host_suffixes[0])
                  positional_constraint = "ENDS_WITH"
                  field_to_match {
                    single_header {
                      name = "host"
                    }
                  }
                  text_transformation {
                    priority = 0
                    type     = "LOWERCASE"
                  }
                }
              }
            }

            dynamic "statement" {
              for_each = length(var.bypass_host_suffixes) > 1 ? [1] : []
              content {
                or_statement {
                  dynamic "statement" {
                    for_each = var.bypass_host_suffixes
                    content {
                      byte_match_statement {
                        search_string         = lower(statement.value)
                        positional_constraint = "ENDS_WITH"
                        field_to_match {
                          single_header {
                            name = "host"
                          }
                        }
                        text_transformation {
                          priority = 0
                          type     = "LOWERCASE"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.metric_name_prefix}-internal-webhooks"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ---------------------------------------------------------------------------
  # 30 — Invalid client-identity (compound: XFF AND any second header)
  # ---------------------------------------------------------------------------
  rule {
    name     = "InvalidClientIdentityCompound"
    priority = local.priority.header_compound

    action {
      dynamic "count" {
        for_each = var.header_compound_action == "count" ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = var.header_compound_action == "block" ? [1] : []
        content {}
      }
    }

    statement {
      and_statement {
        statement {
          regex_pattern_set_reference_statement {
            arn = aws_wafv2_regex_pattern_set.invalid_identity.arn
            field_to_match {
              single_header {
                name = "x-forwarded-for"
              }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          or_statement {
            dynamic "statement" {
              for_each = local.identity_second_headers
              content {
                regex_pattern_set_reference_statement {
                  arn = aws_wafv2_regex_pattern_set.invalid_identity.arn
                  field_to_match {
                    single_header {
                      name = statement.value
                    }
                  }
                  text_transformation {
                    priority = 0
                    type     = "LOWERCASE"
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.metric_name_prefix}-invalid-identity-compound"
      sampled_requests_enabled   = var.sampled_requests_enabled
    }
  }

  # ---------------------------------------------------------------------------
  # 40 — Invalid client-identity (XFF only)
  # ---------------------------------------------------------------------------
  rule {
    name     = "InvalidClientIdentityXffOnly"
    priority = local.priority.header_xff_only

    action {
      dynamic "count" {
        for_each = var.header_xff_only_action == "count" ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = var.header_xff_only_action == "block" ? [1] : []
        content {}
      }
    }

    statement {
      regex_pattern_set_reference_statement {
        arn = aws_wafv2_regex_pattern_set.invalid_identity.arn
        field_to_match {
          single_header {
            name = "x-forwarded-for"
          }
        }
        text_transformation {
          priority = 0
          type     = "LOWERCASE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.metric_name_prefix}-invalid-identity-xff"
      sampled_requests_enabled   = var.sampled_requests_enabled
    }
  }

  # ---------------------------------------------------------------------------
  # 50 — High-confidence public paths (action-capable)
  # ---------------------------------------------------------------------------
  rule {
    name     = "HighConfidencePath"
    priority = local.priority.high_confidence_path

    action {
      dynamic "count" {
        for_each = var.path_rule_action == "count" ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = var.path_rule_action == "block" ? [1] : []
        content {}
      }
    }

    statement {
      dynamic "or_statement" {
        for_each = var.path_block_mode == "full" ? [1] : []
        content {
          statement {
            regex_pattern_set_reference_statement {
              arn = aws_wafv2_regex_pattern_set.paths_impossible.arn
              field_to_match {
                uri_path {}
              }
              text_transformation {
                priority = 0
                type     = "URL_DECODE"
              }
              text_transformation {
                priority = 1
                type     = "URL_DECODE"
              }
              text_transformation {
                priority = 2
                type     = "LOWERCASE"
              }
              text_transformation {
                priority = 3
                type     = "NORMALIZE_PATH"
              }
            }
          }
          statement {
            regex_pattern_set_reference_statement {
              arn = aws_wafv2_regex_pattern_set.paths_remainder.arn
              field_to_match {
                uri_path {}
              }
              text_transformation {
                priority = 0
                type     = "URL_DECODE"
              }
              text_transformation {
                priority = 1
                type     = "URL_DECODE"
              }
              text_transformation {
                priority = 2
                type     = "LOWERCASE"
              }
              text_transformation {
                priority = 3
                type     = "NORMALIZE_PATH"
              }
            }
          }
        }
      }

      dynamic "regex_pattern_set_reference_statement" {
        for_each = var.path_block_mode == "impossible_only" ? [1] : []
        content {
          arn = aws_wafv2_regex_pattern_set.paths_impossible.arn
          field_to_match {
            uri_path {}
          }
          text_transformation {
            priority = 0
            type     = "URL_DECODE"
          }
          text_transformation {
            priority = 1
            type     = "URL_DECODE"
          }
          text_transformation {
            priority = 2
            type     = "LOWERCASE"
          }
          text_transformation {
            priority = 3
            type     = "NORMALIZE_PATH"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.metric_name_prefix}-high-confidence-path"
      sampled_requests_enabled   = var.sampled_requests_enabled
    }
  }

  # ---------------------------------------------------------------------------
  # 60 — Remainder path patterns (COUNT only, tenant-content split)
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = local.path_remainder_rule_enabled ? [1] : []
    content {
      name     = "HighConfidencePathRemainder"
      priority = local.priority.path_remainder_count

      action {
        count {}
      }

      statement {
        regex_pattern_set_reference_statement {
          arn = aws_wafv2_regex_pattern_set.paths_remainder.arn
          field_to_match {
            uri_path {}
          }
          text_transformation {
            priority = 0
            type     = "URL_DECODE"
          }
          text_transformation {
            priority = 1
            type     = "URL_DECODE"
          }
          text_transformation {
            priority = 2
            type     = "LOWERCASE"
          }
          text_transformation {
            priority = 3
            type     = "NORMALIZE_PATH"
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.metric_name_prefix}-high-confidence-path-remainder"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ---------------------------------------------------------------------------
  # 70 — Traversal (no NORMALIZE_PATH)
  # ---------------------------------------------------------------------------
  rule {
    name     = "Traversal"
    priority = local.priority.traversal

    action {
      dynamic "count" {
        for_each = var.traversal_action == "count" ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = var.traversal_action == "block" ? [1] : []
        content {}
      }
    }

    statement {
      regex_match_statement {
        regex_string = local.traversal_regex
        field_to_match {
          uri_path {}
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 2
          type     = "LOWERCASE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.metric_name_prefix}-traversal"
      sampled_requests_enabled   = var.sampled_requests_enabled
    }
  }

  # ---------------------------------------------------------------------------
  # 80 — Amazon IP Reputation
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.enable_amazon_ip_reputation ? [1] : []
    content {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = local.priority.amazon_ip_reputation

      override_action {
        dynamic "count" {
          for_each = var.amazon_ip_reputation_override_count ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = var.amazon_ip_reputation_override_count ? [] : [1]
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"

          dynamic "scope_down_statement" {
            for_each = length(var.ip_reputation_exclude_country_codes) > 0 ? [1] : []
            content {
              not_statement {
                statement {
                  geo_match_statement {
                    country_codes = var.ip_reputation_exclude_country_codes
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.metric_name_prefix}-ip-reputation"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ---------------------------------------------------------------------------
  # 90 — Common Rule Set
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.enable_common_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = local.priority.common_rule_set

      override_action {
        dynamic "count" {
          for_each = var.common_rule_set_override_count ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = var.common_rule_set_override_count ? [] : [1]
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = var.common_rule_set_rule_action_overrides
            content {
              name = rule_action_override.value.name
              action_to_use {
                dynamic "count" {
                  for_each = rule_action_override.value.action == "count" ? [1] : []
                  content {}
                }
                dynamic "allow" {
                  for_each = rule_action_override.value.action == "allow" ? [1] : []
                  content {}
                }
                dynamic "block" {
                  for_each = rule_action_override.value.action == "block" ? [1] : []
                  content {}
                }
                dynamic "captcha" {
                  for_each = rule_action_override.value.action == "captcha" ? [1] : []
                  content {}
                }
                dynamic "challenge" {
                  for_each = rule_action_override.value.action == "challenge" ? [1] : []
                  content {}
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.metric_name_prefix}-common-rules"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ---------------------------------------------------------------------------
  # 100 — SQLi
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.enable_sqli ? [1] : []
    content {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = local.priority.sqli

      override_action {
        dynamic "count" {
          for_each = var.sqli_override_count ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = var.sqli_override_count ? [] : [1]
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesSQLiRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.metric_name_prefix}-sqli"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ---------------------------------------------------------------------------
  # 110 — Known Bad Inputs
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.enable_known_bad_inputs ? [1] : []
    content {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = local.priority.known_bad_inputs

      override_action {
        dynamic "count" {
          for_each = var.known_bad_inputs_override_count ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = var.known_bad_inputs_override_count ? [] : [1]
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.metric_name_prefix}-known-bad-inputs"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ---------------------------------------------------------------------------
  # 120 — Hard dynamic rate (before soft Challenge)
  # ---------------------------------------------------------------------------
  rule {
    name     = "HardDynamicRate"
    priority = local.priority.hard_dynamic_rate

    action {
      dynamic "count" {
        for_each = var.hard_rate_action == "count" ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = var.hard_rate_action == "block" ? [1] : []
        content {}
      }
    }

    statement {
      rate_based_statement {
        limit                 = var.hard_rate_limit
        evaluation_window_sec = var.rate_evaluation_window_sec
        aggregate_key_type    = "CUSTOM_KEYS"

        custom_key {
          ip {}
        }

        custom_key {
          header {
            name = "host"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }

        # Keep OPTIONS + static prefix/extension composition aligned with
        # SoftDynamicRate and StaticObservationRate. Hard intentionally omits
        # webhook and Better Auth exemptions so floods on those paths still count.
        scope_down_statement {
          not_statement {
            statement {
              or_statement {
                statement {
                  byte_match_statement {
                    search_string         = "OPTIONS"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      method {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }

                dynamic "statement" {
                  for_each = var.static_uri_prefixes
                  content {
                    byte_match_statement {
                      search_string         = statement.value
                      positional_constraint = "STARTS_WITH"
                      field_to_match {
                        uri_path {}
                      }
                      text_transformation {
                        priority = 0
                        type     = "LOWERCASE"
                      }
                    }
                  }
                }

                statement {
                  regex_pattern_set_reference_statement {
                    arn = aws_wafv2_regex_pattern_set.static_extensions.arn
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "LOWERCASE"
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.metric_name_prefix}-hard-dynamic-rate"
      sampled_requests_enabled   = var.sampled_requests_enabled
    }
  }

  # ---------------------------------------------------------------------------
  # 130 — Soft dynamic rate (Challenge-capable; webhook- and Better Auth-exempt)
  # ---------------------------------------------------------------------------
  rule {
    name     = "SoftDynamicRate"
    priority = local.priority.soft_dynamic_rate

    action {
      dynamic "count" {
        for_each = var.soft_rate_action == "count" ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = var.soft_rate_action == "block" ? [1] : []
        content {}
      }
      dynamic "challenge" {
        for_each = var.soft_rate_action == "challenge" ? [1] : []
        content {}
      }
    }

    statement {
      rate_based_statement {
        limit                 = var.soft_rate_limit
        evaluation_window_sec = var.rate_evaluation_window_sec
        aggregate_key_type    = "CUSTOM_KEYS"

        custom_key {
          ip {}
        }

        custom_key {
          header {
            name = "host"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }

        # Keep OPTIONS + static prefix/extension composition aligned with
        # HardDynamicRate and StaticObservationRate. Soft also exempts webhooks
        # and Better Auth (below); those extras must stay off the hard rule.
        scope_down_statement {
          not_statement {
            statement {
              or_statement {
                statement {
                  byte_match_statement {
                    search_string         = "OPTIONS"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      method {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }

                dynamic "statement" {
                  for_each = var.static_uri_prefixes
                  content {
                    byte_match_statement {
                      search_string         = statement.value
                      positional_constraint = "STARTS_WITH"
                      field_to_match {
                        uri_path {}
                      }
                      text_transformation {
                        priority = 0
                        type     = "LOWERCASE"
                      }
                    }
                  }
                }

                statement {
                  regex_pattern_set_reference_statement {
                    arn = aws_wafv2_regex_pattern_set.static_extensions.arn
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "LOWERCASE"
                    }
                  }
                }

                dynamic "statement" {
                  for_each = var.webhook_exempt_prefixes
                  content {
                    byte_match_statement {
                      search_string         = statement.value
                      positional_constraint = "STARTS_WITH"
                      field_to_match {
                        uri_path {}
                      }
                      text_transformation {
                        priority = 0
                        type     = "LOWERCASE"
                      }
                    }
                  }
                }

                dynamic "statement" {
                  for_each = var.webhook_exempt_paths
                  content {
                    byte_match_statement {
                      search_string         = statement.value
                      positional_constraint = "EXACTLY"
                      field_to_match {
                        uri_path {}
                      }
                      text_transformation {
                        priority = 0
                        type     = "LOWERCASE"
                      }
                    }
                  }
                }

                # Better Auth is governed by RateLimitBetterAuth (priority 150)
                # and must not be challenged by this soft rule when that rule is on.
                dynamic "statement" {
                  for_each = var.better_auth_rate_enabled ? [var.better_auth_rate_path_prefix] : []
                  content {
                    byte_match_statement {
                      search_string         = statement.value
                      positional_constraint = "STARTS_WITH"
                      field_to_match {
                        uri_path {}
                      }
                      text_transformation {
                        priority = 0
                        type     = "LOWERCASE"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.metric_name_prefix}-soft-dynamic-rate"
      sampled_requests_enabled   = var.sampled_requests_enabled
    }
  }

  # ---------------------------------------------------------------------------
  # 140 — Static observation (COUNT only; inverse of dynamic static-asset match)
  # ---------------------------------------------------------------------------
  rule {
    name     = "StaticObservationRate"
    priority = local.priority.static_observation

    action {
      count {}
    }

    statement {
      rate_based_statement {
        limit                 = var.static_rate_limit
        evaluation_window_sec = var.rate_evaluation_window_sec
        aggregate_key_type    = "CUSTOM_KEYS"

        custom_key {
          ip {}
        }

        custom_key {
          header {
            name = "host"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }

        # Inverse of the static-asset match shared with HardDynamicRate and
        # SoftDynamicRate; keep prefix/extension lists aligned with those rules.
        scope_down_statement {
          or_statement {
            dynamic "statement" {
              for_each = var.static_uri_prefixes
              content {
                byte_match_statement {
                  search_string         = statement.value
                  positional_constraint = "STARTS_WITH"
                  field_to_match {
                    uri_path {}
                  }
                  text_transformation {
                    priority = 0
                    type     = "LOWERCASE"
                  }
                }
              }
            }

            statement {
              regex_pattern_set_reference_statement {
                arn = aws_wafv2_regex_pattern_set.static_extensions.arn
                field_to_match {
                  uri_path {}
                }
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.metric_name_prefix}-static-observation-rate"
      sampled_requests_enabled   = var.sampled_requests_enabled
    }
  }

  # ---------------------------------------------------------------------------
  # 150 — Better Auth /api/ba/ rate (existing infra-crm rule, input-driven)
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = var.better_auth_rate_enabled ? [1] : []
    content {
      name     = "RateLimitBetterAuth"
      priority = local.priority.better_auth_rate

      action {
        dynamic "count" {
          for_each = var.better_auth_rate_action == "count" ? [1] : []
          content {}
        }
        dynamic "block" {
          for_each = var.better_auth_rate_action == "block" ? [1] : []
          content {}
        }
      }

      statement {
        rate_based_statement {
          limit                 = var.better_auth_rate_limit
          evaluation_window_sec = var.rate_evaluation_window_sec
          aggregate_key_type    = "IP"

          scope_down_statement {
            byte_match_statement {
              search_string         = var.better_auth_rate_path_prefix
              positional_constraint = "STARTS_WITH"
              field_to_match {
                uri_path {}
              }
              text_transformation {
                priority = 0
                type     = "LOWERCASE"
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.metric_name_prefix}-ba-rate-limit"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = var.sampled_requests_enabled
  }

  tags = var.tags
}
