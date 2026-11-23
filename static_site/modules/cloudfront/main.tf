resource "aws_cloudfront_origin_access_control" "website_oac" {
  name                              = "s3-website-oac-${var.domain}"
  description                       = "Origin Access Control for ${var.domain} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  api_lambda_oac_enabled       = local.api_origin_enabled && var.api_origin_lambda_oac
  api_origin_enabled           = var.api_origin_domain_name != ""
  preserve_forbidden           = var.preserve_forbidden_responses || local.api_lambda_oac_enabled
  static_error_codes           = local.api_lambda_oac_enabled ? [] : (local.preserve_forbidden ? [404] : [403, 404])
  api_cache_policy_id          = var.api_cache_policy_id != "" ? var.api_cache_policy_id : try(aws_cloudfront_cache_policy.api[0].id, null)
  api_origin_request_policy_id = var.api_origin_request_policy_id != "" ? var.api_origin_request_policy_id : try(aws_cloudfront_origin_request_policy.api[0].id, null)
  resource_name_prefix         = var.resource_name_prefix != "" ? "${var.resource_name_prefix}-" : ""
  viewer_request_function_code = var.directory_routing_function_code != "" ? var.directory_routing_function_code : var.redirect_www_to_apex_function_code
}

resource "aws_cloudfront_origin_access_control" "lambda_oac" {
  count                             = local.api_lambda_oac_enabled ? 1 : 0
  name                              = "lambda-api-oac-${var.domain}"
  description                       = "Origin Access Control for ${var.domain} API"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "api" {
  count = local.api_origin_enabled && var.api_cache_policy_id == "" ? 1 : 0

  name        = "api-cache-${replace(var.domain, ".", "-")}"
  default_ttl = var.api_cache_ttl_seconds
  max_ttl     = var.api_cache_ttl_seconds
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "all"
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

resource "aws_cloudfront_origin_request_policy" "api" {
  count = local.api_origin_enabled && var.api_origin_request_policy_id == "" ? 1 : 0

  name = "api-origin-request-${replace(var.domain, ".", "-")}"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "none"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_response_headers_policy" "immutable_cache_headers" {
  count = var.private_static_cache_immutable_assets ? 0 : 1

  name = "${local.resource_name_prefix}immutable-cache-headers"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=31536000, immutable"
      override = true
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "images_cache_headers" {
  count = var.private_static_cache_immutable_assets ? 0 : 1

  name = "${local.resource_name_prefix}images-cache-headers"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=2592000"
      override = true
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "css_cache_headers" {
  count = var.private_static_cache_immutable_assets ? 0 : 1

  name = "${local.resource_name_prefix}css-cache-headers"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=31536000, immutable"
      override = true
    }
  }
}

resource "aws_cloudfront_cache_policy" "immutable_assets" {
  count = var.private_static_cache_immutable_assets ? 0 : 1

  name        = "${local.resource_name_prefix}immutable-assets"
  default_ttl = 31536000
  max_ttl     = 31536000
  min_ttl     = 86400

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

resource "aws_cloudfront_function" "redirect_www_to_apex" {
  name    = "${local.resource_name_prefix}redirect-www-to-apex"
  runtime = "cloudfront-js-2.0"
  comment = "Viewer request routing for ${var.domain}"
  publish = true
  code    = local.viewer_request_function_code
}

resource "aws_cloudfront_origin_request_policy" "private_static" {
  count = var.security_headers_policy ? 1 : 0

  name = "${local.resource_name_prefix}private-static-origin"

  cookies_config { cookie_behavior = "none" }
  headers_config { header_behavior = "none" }
  query_strings_config { query_string_behavior = "none" }
}

resource "aws_cloudfront_response_headers_policy" "static_security" {
  count = var.security_headers_policy ? 1 : 0

  name = "${local.resource_name_prefix}static-security"

  dynamic "custom_headers_config" {
    for_each = var.no_index ? [1] : []
    content {
      items {
        header   = "X-Robots-Tag"
        value    = "noindex, nofollow, noarchive"
        override = true
      }
    }
  }

  security_headers_config {
    content_security_policy {
      content_security_policy = var.security_headers_content_security_policy
      override                = true
    }
    content_type_options { override = true }
    dynamic "frame_options" {
      for_each = var.security_headers_frame_options == null ? [] : [var.security_headers_frame_options]
      content {
        frame_option = frame_options.value
        override     = true
      }
    }
    referrer_policy {
      referrer_policy = "no-referrer"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = false
      preload                    = false
      override                   = true
    }
  }
}

resource "aws_cloudfront_distribution" "main" {
  lifecycle {
    precondition {
      condition = !var.preserve_forbidden_responses || (
        var.security_headers_policy && var.directory_routing_function_code != ""
      )
      error_message = "Preserving 403 responses requires private static behavior and a viewer function that rewrites the bucket root."
    }

    precondition {
      condition = !var.api_origin_lambda_oac || (
        local.api_origin_enabled && var.security_headers_policy &&
        var.directory_routing_function_code != "" &&
        var.api_cache_policy_id == "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
      )
      error_message = "Lambda OAC requires an API origin, private static behavior, a viewer function that rewrites the bucket root, and the managed CachingDisabled API policy."
    }
  }

  enabled             = true
  is_ipv6_enabled     = var.is_ipv6_enabled
  price_class         = var.price_class
  wait_for_deployment = var.wait_for_deployment
  aliases             = var.aliases
  web_acl_id          = var.web_acl_id

  origin {
    domain_name              = var.bucket_domain_name
    origin_id                = "s3-website"
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
  }

  dynamic "origin" {
    for_each = local.api_origin_enabled ? [1] : []
    content {
      domain_name              = var.api_origin_domain_name
      origin_id                = "api-origin"
      origin_access_control_id = local.api_lambda_oac_enabled ? aws_cloudfront_origin_access_control.lambda_oac[0].id : null

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }

      dynamic "custom_header" {
        for_each = var.api_origin_custom_header_value != "" ? [1] : []
        content {
          name  = var.api_origin_custom_header_name
          value = var.api_origin_custom_header_value
        }
      }
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3-website"

    cache_policy_id            = var.security_headers_policy ? "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" : var.default_cache_policy_id # CachingDisabled
    origin_request_policy_id   = var.security_headers_policy ? aws_cloudfront_origin_request_policy.private_static[0].id : var.origin_request_policy_id
    response_headers_policy_id = var.security_headers_policy ? aws_cloudfront_response_headers_policy.static_security[0].id : null

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.api_origin_enabled ? toset(var.api_path_patterns) : []
    content {
      path_pattern               = ordered_cache_behavior.value
      target_origin_id           = "api-origin"
      allowed_methods            = var.api_allowed_methods
      cached_methods             = var.api_cached_methods
      viewer_protocol_policy     = "redirect-to-https"
      compress                   = true
      cache_policy_id            = local.api_cache_policy_id
      origin_request_policy_id   = local.api_origin_request_policy_id
      response_headers_policy_id = var.no_index ? try(aws_cloudfront_response_headers_policy.static_security[0].id, null) : null

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.security_headers_policy || var.private_static_cache_immutable_assets ? [] : ["*.css"]
    content {
      path_pattern               = ordered_cache_behavior.value
      target_origin_id           = "s3-website"
      allowed_methods            = ["GET", "HEAD", "OPTIONS"]
      cached_methods             = ["GET", "HEAD", "OPTIONS"]
      viewer_protocol_policy     = "redirect-to-https"
      compress                   = true
      cache_policy_id            = aws_cloudfront_cache_policy.immutable_assets[0].id
      origin_request_policy_id   = var.origin_request_policy_id
      response_headers_policy_id = aws_cloudfront_response_headers_policy.css_cache_headers[0].id

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = !var.security_headers_policy || var.private_static_cache_immutable_assets ? ["_next/static/*"] : []
    content {
      path_pattern               = ordered_cache_behavior.value
      target_origin_id           = "s3-website"
      allowed_methods            = ["GET", "HEAD", "OPTIONS"]
      cached_methods             = ["GET", "HEAD", "OPTIONS"]
      viewer_protocol_policy     = "redirect-to-https"
      compress                   = true
      cache_policy_id            = var.private_static_cache_immutable_assets ? var.default_cache_policy_id : aws_cloudfront_cache_policy.immutable_assets[0].id
      origin_request_policy_id   = var.private_static_cache_immutable_assets ? null : var.origin_request_policy_id
      response_headers_policy_id = var.private_static_cache_immutable_assets ? try(aws_cloudfront_response_headers_policy.static_security[0].id, null) : aws_cloudfront_response_headers_policy.immutable_cache_headers[0].id

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.security_headers_policy || var.private_static_cache_immutable_assets ? [] : ["images/*"]
    content {
      path_pattern               = ordered_cache_behavior.value
      target_origin_id           = "s3-website"
      allowed_methods            = ["GET", "HEAD", "OPTIONS"]
      cached_methods             = ["GET", "HEAD", "OPTIONS"]
      viewer_protocol_policy     = "redirect-to-https"
      compress                   = true
      cache_policy_id            = var.default_cache_policy_id
      origin_request_policy_id   = var.origin_request_policy_id
      response_headers_policy_id = aws_cloudfront_response_headers_policy.images_cache_headers[0].id

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.security_headers_policy || var.private_static_cache_immutable_assets ? [] : ["static/*"]
    content {
      path_pattern               = ordered_cache_behavior.value
      target_origin_id           = "s3-website"
      allowed_methods            = ["GET", "HEAD", "OPTIONS"]
      cached_methods             = ["GET", "HEAD", "OPTIONS"]
      viewer_protocol_policy     = "redirect-to-https"
      compress                   = true
      cache_policy_id            = var.default_cache_policy_id
      origin_request_policy_id   = var.origin_request_policy_id
      response_headers_policy_id = aws_cloudfront_response_headers_policy.images_cache_headers[0].id

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  dynamic "custom_error_response" {
    for_each = var.strict_error_responses ? local.static_error_codes : []
    content {
      error_code         = custom_error_response.value
      response_code      = 404
      response_page_path = "/404.html"
    }
  }

  dynamic "custom_error_response" {
    for_each = var.strict_error_responses ? [] : local.static_error_codes
    content {
      error_code         = custom_error_response.value
      response_code      = 200
      response_page_path = "/index.html"
    }
  }

  tags = var.tags
}

resource "aws_s3_bucket_policy" "website" {
  bucket = var.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${var.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }],
      local.preserve_forbidden ? [{
        # S3 returns 403 on missing keys without ListBucket. This profile's
        # viewer must rewrite the bucket root and forward no query strings.
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:ListBucket"
        Resource  = var.bucket_arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }] : []
    )
  })
}

moved {
  from = aws_cloudfront_response_headers_policy.immutable_cache_headers
  to   = aws_cloudfront_response_headers_policy.immutable_cache_headers[0]
}

moved {
  from = aws_cloudfront_response_headers_policy.images_cache_headers
  to   = aws_cloudfront_response_headers_policy.images_cache_headers[0]
}

moved {
  from = aws_cloudfront_response_headers_policy.css_cache_headers
  to   = aws_cloudfront_response_headers_policy.css_cache_headers[0]
}

moved {
  from = aws_cloudfront_cache_policy.immutable_assets
  to   = aws_cloudfront_cache_policy.immutable_assets[0]
}
