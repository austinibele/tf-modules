resource "aws_route53_zone" "primary" {
  name    = var.domain
  comment = "Public hosted zone for ${var.domain}"
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in var.certificate_domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
      type  = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.value]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "website" {
  provider                = aws.us_east_1
  certificate_arn         = var.certificate_arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_route53_record" "primary_root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = var.distribution_domain_name
    zone_id                = var.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "primary_www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain}"
  type    = "A"

  alias {
    name                   = var.distribution_domain_name
    zone_id                = var.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "additional" {
  for_each = var.additional_records

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}

