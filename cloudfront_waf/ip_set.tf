resource "aws_wafv2_ip_set" "trusted" {
  count              = local.create_trusted_ip_set ? 1 : 0
  name               = "${local.resource_prefix}-allowed-ips"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.trusted_ip_cidrs
  tags               = var.tags
}

resource "aws_wafv2_ip_set" "host_allowlist" {
  for_each           = { for entry in var.host_ip_allowlists : entry.name => entry }
  name               = "${local.resource_prefix}-${each.key}-allowed-ips"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = each.value.cidrs
  tags               = var.tags
}

# Addresses banned for 24 hours after repeated HighConfidencePath blocks. The
# waf-probe-ban job (infra-lambdas) owns the addresses, so Terraform ignores them.
resource "aws_wafv2_ip_set" "probe_ban" {
  for_each           = var.probe_ban_enabled ? { ipv4 = "IPV4", ipv6 = "IPV6" } : {}
  name               = "${local.resource_prefix}-probe-ban-${each.key}"
  scope              = "CLOUDFRONT"
  ip_address_version = each.value
  addresses          = []
  tags               = var.tags

  lifecycle {
    ignore_changes = [addresses]
  }
}
