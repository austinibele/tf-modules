resource "aws_route53_zone" "primary" {
  count = var.existing_zone_id == "" ? 1 : 0

  name    = var.domain
  comment = "Public hosted zone for ${var.domain}"
}

locals {
  zone_id = var.existing_zone_id != "" ? var.existing_zone_id : aws_route53_zone.primary[0].zone_id
}

locals {
  # Keyed by the certificate's domain names, which are known at plan time.
  # The validation options themselves are known only after a new certificate
  # is created, so they can supply values but not for_each keys.
  validation_by_domain = {
    for dvo in var.certificate_domain_validation_options : dvo.domain_name => dvo
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = toset(var.certificate_domain_names)

  allow_overwrite = true
  name            = local.validation_by_domain[each.key].resource_record_name
  records         = [local.validation_by_domain[each.key].resource_record_value]
  ttl             = 60
  type            = local.validation_by_domain[each.key].resource_record_type
  zone_id         = local.zone_id
}

resource "aws_acm_certificate_validation" "website" {
  provider                = aws.us_east_1
  certificate_arn         = var.certificate_arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_route53_record" "primary_root" {
  zone_id = local.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = var.distribution_domain_name
    zone_id                = var.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "primary_www" {
  for_each = var.create_www_alias ? toset(["www"]) : toset([])
  zone_id  = local.zone_id
  name     = "www.${var.domain}"
  type     = "A"

  alias {
    name                   = var.distribution_domain_name
    zone_id                = var.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

moved {
  from = aws_route53_zone.primary
  to   = aws_route53_zone.primary[0]
}

moved {
  from = aws_route53_record.primary_www
  to   = aws_route53_record.primary_www["www"]
}

resource "aws_route53_record" "primary_root_ipv6" {
  count   = var.create_ipv6_alias_records ? 1 : 0
  zone_id = local.zone_id
  name    = var.domain
  type    = "AAAA"

  alias {
    name                   = var.distribution_domain_name
    zone_id                = var.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "primary_www_ipv6" {
  count   = var.create_www_alias && var.create_ipv6_alias_records ? 1 : 0
  zone_id = local.zone_id
  name    = "www.${var.domain}"
  type    = "AAAA"

  alias {
    name                   = var.distribution_domain_name
    zone_id                = var.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "additional" {
  for_each = var.additional_records

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}
