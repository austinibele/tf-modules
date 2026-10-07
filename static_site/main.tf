locals {
  bucket_name      = var.bucket_name != "" ? var.bucket_name : "${var.namespace}-website"
  computed_aliases = length(var.aliases) > 0 ? var.aliases : [var.domain, "www.${var.domain}"]
  san_names        = [for alias in distinct(local.computed_aliases) : alias if alias != var.domain]
}

module "static_site_bucket" {
  source = "./modules/bucket"

  bucket_name                   = local.bucket_name
  tags                          = var.tags
  index_document                = var.index_document
  error_document                = var.error_document
  enable_website_configuration  = var.enable_website_configuration
  object_ownership              = var.object_ownership
  enable_server_side_encryption = var.enable_server_side_encryption
}

module "static_site_certificate" {
  source = "./modules/certificate"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain                    = var.domain
  subject_alternative_names = local.san_names
  tags                      = var.tags
}

module "static_site_cloudfront" {
  source = "./modules/cloudfront"

  domain                                   = var.domain
  aliases                                  = local.computed_aliases
  bucket_domain_name                       = module.static_site_bucket.bucket_regional_domain_name
  bucket_id                                = module.static_site_bucket.bucket_id
  bucket_arn                               = module.static_site_bucket.bucket_arn
  acm_certificate_arn                      = module.static_site_route53.certificate_validation_arn
  tags                                     = var.tags
  web_acl_id                               = var.web_acl_id
  resource_name_prefix                     = var.resource_name_prefix
  directory_routing_function_code          = var.directory_routing_function_code
  strict_error_responses                   = var.strict_error_responses
  security_headers_policy                  = var.security_headers_policy
  security_headers_frame_options           = var.security_headers_frame_options
  security_headers_content_security_policy = var.security_headers_content_security_policy

  api_origin_domain_name         = var.api_origin_domain_name
  api_path_patterns              = var.api_path_patterns
  api_origin_custom_header_name  = var.api_origin_custom_header_name
  api_origin_custom_header_value = var.api_origin_custom_header_value
  api_allowed_methods            = var.api_allowed_methods
  api_cached_methods             = var.api_cached_methods
  api_cache_ttl_seconds          = var.api_cache_ttl_seconds
  api_cache_policy_id            = var.api_cache_policy_id
  api_origin_request_policy_id   = var.api_origin_request_policy_id
}

module "static_site_route53" {
  source = "./modules/route53"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain                                = var.domain
  existing_zone_id                      = var.existing_zone_id
  create_www_alias                      = var.create_www_alias
  create_ipv6_alias_records             = var.create_ipv6_alias_records
  distribution_domain_name              = module.static_site_cloudfront.distribution_domain_name
  distribution_hosted_zone_id           = module.static_site_cloudfront.distribution_hosted_zone_id
  certificate_arn                       = module.static_site_certificate.certificate_arn
  certificate_domain_validation_options = module.static_site_certificate.domain_validation_options
  additional_records                    = var.route53_additional_records
}
