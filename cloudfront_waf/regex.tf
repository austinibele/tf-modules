resource "aws_wafv2_regex_pattern_set" "invalid_identity" {
  name  = "${local.resource_prefix}-invalid-identity"
  scope = "CLOUDFRONT"

  regular_expression {
    regex_string = local.invalid_identity_regex
  }

  tags = var.tags
}

resource "aws_wafv2_regex_pattern_set" "paths_impossible" {
  name  = "${local.resource_prefix}-paths-impossible"
  scope = "CLOUDFRONT"

  dynamic "regular_expression" {
    for_each = local.path_patterns_impossible
    content {
      regex_string = regular_expression.value
    }
  }

  tags = var.tags
}

resource "aws_wafv2_regex_pattern_set" "paths_remainder" {
  name  = "${local.resource_prefix}-paths-remainder"
  scope = "CLOUDFRONT"

  dynamic "regular_expression" {
    for_each = local.path_patterns_remainder
    content {
      regex_string = regular_expression.value
    }
  }

  tags = var.tags
}

resource "aws_wafv2_regex_pattern_set" "static_extensions" {
  name  = "${local.resource_prefix}-static-extensions"
  scope = "CLOUDFRONT"

  regular_expression {
    regex_string = local.static_extension_regex
  }

  tags = var.tags
}

# Probe paths for software none of the callers run (PHP, WordPress, CGI). Only
# created when the caller passes probe_patterns; joins HighConfidencePath.
resource "aws_wafv2_regex_pattern_set" "paths_probe" {
  count = local.probe_paths_enabled ? 1 : 0
  name  = "${local.resource_prefix}-paths-probe"
  scope = "CLOUDFRONT"

  dynamic "regular_expression" {
    for_each = var.probe_patterns
    content {
      regex_string = regular_expression.value
    }
  }

  tags = var.tags
}
