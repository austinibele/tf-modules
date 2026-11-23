variable "namespace" {
  description = "Namespace prefix used for resource naming."
  type        = string
}

variable "domain" {
  description = "Primary domain name for the static site."
  type        = string
}

variable "tags" {
  description = "Tags applied across resources."
  type        = map(string)
  default     = {}
}

variable "bucket_name" {
  description = "Optional explicit bucket name. Defaults to {var.namespace}-website when empty."
  type        = string
  default     = ""
}

variable "aliases" {
  description = "Additional aliases for the CloudFront distribution. Defaults to [domain, \"www.domain\"]."
  type        = list(string)
  default     = []
}

variable "existing_zone_id" {
  description = "Existing public Route 53 zone to use. Empty creates a dedicated zone for backward compatibility."
  type        = string
  default     = ""
}

variable "create_www_alias" {
  description = "Whether to create a www alias record."
  type        = bool
  default     = true
}

variable "create_ipv6_alias_records" {
  description = "Whether to create AAAA aliases alongside A aliases."
  type        = bool
  default     = false
}

variable "enable_website_configuration" {
  description = "Whether to configure the S3 website endpoint."
  type        = bool
  default     = true
}

variable "object_ownership" {
  description = "S3 object ownership mode."
  type        = string
  default     = "BucketOwnerPreferred"
}

variable "enable_server_side_encryption" {
  description = "Whether to enable default S3-managed server-side encryption."
  type        = bool
  default     = false
}

variable "resource_name_prefix" {
  description = "Optional unique prefix for CloudFront policy and function names."
  type        = string
  default     = ""
}

variable "directory_routing_function_code" {
  description = "Optional viewer-request function code used for directory routing. Empty preserves the legacy www redirect function."
  type        = string
  default     = ""
}

variable "strict_error_responses" {
  description = "Whether missing S3 objects return a 404 page instead of SPA HTML success responses."
  type        = bool
  default     = false
}

variable "preserve_forbidden_responses" {
  description = "Pass through CloudFront and WAF 403 responses. Requires private static behavior and a viewer function that rewrites the bucket root."
  type        = bool
  default     = false
}

variable "security_headers_policy" {
  description = "Whether to attach restrictive static-site response headers."
  type        = bool
  default     = false
}

variable "security_headers_frame_options" {
  description = "Legacy X-Frame-Options header. Null omits it when an explicit CSP frame-ancestors allowlist owns framing."
  type        = string
  default     = "SAMEORIGIN"
  validation {
    condition     = var.security_headers_frame_options == null ? true : contains(["SAMEORIGIN", "DENY"], var.security_headers_frame_options)
    error_message = "Use SAMEORIGIN, DENY, or null with an explicit CSP frame-ancestors policy."
  }
}

variable "security_headers_content_security_policy" {
  description = "Content-Security-Policy value for the opt-in static response headers."
  type        = string
  default     = "default-src 'self'; base-uri 'none'; connect-src 'none'; form-action 'none'; frame-ancestors 'self'; img-src 'self' data:; object-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'"
}

variable "route53_additional_records" {
  description = "Additional Route 53 records to create beyond the CloudFront aliases."
  type = map(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  }))
  default = {}
}

variable "index_document" {
  description = "Default index document for the S3 website configuration."
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Default error document for the S3 website configuration."
  type        = string
  default     = "error.html"
}

variable "api_origin_domain_name" {
  description = "Optional API origin domain (e.g., Lambda Function URL without https://)."
  type        = string
  default     = ""
}

variable "api_path_patterns" {
  description = "Path patterns routed to the API origin."
  type        = list(string)
  default     = ["/api/*"]
}

variable "api_origin_custom_header_name" {
  description = "Optional custom header name added to API origin requests."
  type        = string
  default     = "x-cf-origin"
}

variable "api_origin_custom_header_value" {
  description = "Optional custom header value added to API origin requests."
  type        = string
  default     = ""
}

variable "api_allowed_methods" {
  description = "Allowed HTTP methods for API behaviors."
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS"]
}

variable "api_cached_methods" {
  description = "Cached HTTP methods for API behaviors."
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "api_cache_ttl_seconds" {
  description = "Default/max TTL (seconds) for API cache policy when managed by the module."
  type        = number
  default     = 86400
}

variable "api_cache_policy_id" {
  description = "Optional cache policy ID to use for API behaviors."
  type        = string
  default     = ""
}

variable "api_origin_request_policy_id" {
  description = "Optional origin request policy ID to use for API behaviors."
  type        = string
  default     = ""
}

variable "web_acl_id" {
  description = "Optional WAFv2 web ACL ARN (CLOUDFRONT scope). Null leaves the distribution unprotected."
  type        = string
  default     = null
}

variable "private_static_cache_immutable_assets" {
  description = "With security headers enabled, use the managed cache policy on hashed Next.js assets and retain the security headers."
  type        = bool
  default     = false
}

variable "no_index" {
  description = "Add an X-Robots-Tag response header to behaviors using the security headers policy."
  type        = bool
  default     = false
}

variable "api_origin_lambda_oac" {
  description = "Sign API origin requests with Lambda OAC and preserve origin error bodies and status. Missing static objects return S3's native 404."
  type        = bool
  default     = false
}

variable "wait_for_deployment" {
  description = "Wait for CloudFront distribution deployment before completing the apply."
  type        = bool
  default     = false
}

variable "distribution_certificate_arn" {
  description = "Optional externally validated ACM certificate ARN for the distribution. The regular site certificate and validation records remain managed independently."
  type        = string
  default     = ""
}

variable "supplemental_distribution_aliases" {
  description = "Optional aliases whose certificate validation and traffic records are owned outside the module. Requires distribution_certificate_arn."
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.supplemental_distribution_aliases) == 0 || var.distribution_certificate_arn != ""
    error_message = "Provide an externally validated distribution certificate covering all supplemental aliases."
  }
}
