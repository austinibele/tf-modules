resource "aws_cloudfront_origin_access_control" "website_oac" {
  name                              = "s3-website-oac-${var.domain}"
  description                       = "Origin Access Control for ${var.domain} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "immutable_cache_headers" {
  name = "immutable-cache-headers"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=31536000, immutable"
      override = true
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "images_cache_headers" {
  name = "images-cache-headers"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=2592000"
      override = true
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "css_cache_headers" {
  name = "css-cache-headers"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=31536000, immutable"
      override = true
    }
  }
}

resource "aws_cloudfront_cache_policy" "immutable_assets" {
  name        = "immutable-assets"
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
  name    = "redirect-www-to-apex"
  runtime = "cloudfront-js-2.0"
  comment = "301 redirect from www to apex for ${var.domain}"
  publish = true
  code    = var.redirect_www_to_apex_function_code
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = var.is_ipv6_enabled
  price_class         = var.price_class
  wait_for_deployment = var.wait_for_deployment
  aliases             = var.aliases

  origin {
    domain_name              = var.bucket_domain_name
    origin_id                = "s3-website"
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "s3-website"

    cache_policy_id          = var.default_cache_policy_id
    origin_request_policy_id = var.origin_request_policy_id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
    }
  }

  ordered_cache_behavior {
    path_pattern               = "*.css"
    target_origin_id           = "s3-website"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    cache_policy_id            = aws_cloudfront_cache_policy.immutable_assets.id
    origin_request_policy_id   = var.origin_request_policy_id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.css_cache_headers.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
    }
  }

  ordered_cache_behavior {
    path_pattern               = "_next/static/*"
    target_origin_id           = "s3-website"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    cache_policy_id            = aws_cloudfront_cache_policy.immutable_assets.id
    origin_request_policy_id   = var.origin_request_policy_id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.immutable_cache_headers.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
    }
  }

  ordered_cache_behavior {
    path_pattern               = "images/*"
    target_origin_id           = "s3-website"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    cache_policy_id            = var.default_cache_policy_id
    origin_request_policy_id   = var.origin_request_policy_id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.images_cache_headers.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
    }
  }

  ordered_cache_behavior {
    path_pattern               = "static/*"
    target_origin_id           = "s3-website"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    cache_policy_id            = var.default_cache_policy_id
    origin_request_policy_id   = var.origin_request_policy_id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.images_cache_headers.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect_www_to_apex.arn
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

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  tags = var.tags
}

resource "aws_s3_bucket_policy" "website" {
  bucket = var.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${var.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}

