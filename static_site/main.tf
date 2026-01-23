locals {
  bucket_name      = var.bucket_name != "" ? var.bucket_name : "${var.namespace}-website"
  computed_aliases = length(var.aliases) > 0 ? var.aliases : [var.domain, "www.${var.domain}"]
  san_names        = [for alias in distinct(local.computed_aliases) : alias if alias != var.domain]
}

module "static_site_bucket" {
  source = "./modules/bucket"

  bucket_name    = local.bucket_name
  tags           = var.tags
  index_document = var.index_document
  error_document = var.error_document
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

  domain              = var.domain
  aliases             = local.computed_aliases
  bucket_domain_name  = module.static_site_bucket.bucket_regional_domain_name
  bucket_id           = module.static_site_bucket.bucket_id
  bucket_arn          = module.static_site_bucket.bucket_arn
  acm_certificate_arn = module.static_site_certificate.certificate_arn
  tags                = var.tags

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
  distribution_domain_name              = module.static_site_cloudfront.distribution_domain_name
  distribution_hosted_zone_id           = module.static_site_cloudfront.distribution_hosted_zone_id
  certificate_arn                       = module.static_site_certificate.certificate_arn
  certificate_domain_validation_options = module.static_site_certificate.domain_validation_options
  additional_records                    = var.route53_additional_records
}

