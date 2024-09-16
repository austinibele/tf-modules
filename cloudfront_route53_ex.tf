# -------------------------------------------------------------------------------
# Elastic IP
# -------------------------------------------------------------------------------

resource "aws_eip" "ec2_eip" {
  instance = module.ec2_instance.id[0]
  domain   = "vpc" 

  tags = {
    Name = "${var.namespace}-ElasticIP"
  }
}

# -----------------------------------------------------------------------------
# Route 53 Configuration
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "main" {
  domain_name               = lookup(var.domain, var.env) 
  subject_alternative_names = ["www.${lookup(var.domain, var.env)}"]
  validation_method         = "DNS"
}

resource "aws_route53_zone" "main" {
  name = var.domain[var.env]
}

resource "aws_route53_record" "www" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = aws_route53_zone.main.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.www : record.fqdn]
}

# -------------------------------------------------------------------------------
# CloudFront Distribution
# -------------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = aws_eip.ec2_eip.public_dns
    origin_id   = "ec2-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2", "TLSv1.1", "TLSv1"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.namespace} CloudFront Distribution"

  aliases = [
    var.domain[var.env],
    "www.${var.domain[var.env]}"
  ]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE", "OPTIONS"]    
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "ec2-origin"

    forwarded_values {
      query_string = true
      headers      = ["Accept", "Content-Type"]
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate.main.arn
    ssl_support_method             = "sni-only"
  }

  tags = {
    Name = "${var.namespace}-CloudFront"
  }
}

# -------------------------------------------------------------------------------
# Route 53 Records for CloudFront
# -------------------------------------------------------------------------------

resource "aws_route53_record" "cf" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain[var.env]
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cf_www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain[var.env]}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}