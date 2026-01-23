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
