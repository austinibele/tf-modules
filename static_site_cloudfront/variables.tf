variable "domain" {
  description = "Primary domain name for the CloudFront distribution."
  type        = string
}

variable "aliases" {
  description = "Alternative domain names (CNAMEs) for the distribution."
  type        = list(string)
  default     = []
}

variable "bucket_domain_name" {
  description = "Regional domain name of the origin S3 bucket."
  type        = string
}

variable "bucket_id" {
  description = "ID of the origin S3 bucket."
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the origin S3 bucket."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS."
  type        = string
}

variable "tags" {
  description = "Tags to apply to CloudFront resources."
  type        = map(string)
  default     = {}
}

variable "default_cache_policy_id" {
  description = "Cache policy ID for the default behavior."
  type        = string
  default     = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
}

variable "origin_request_policy_id" {
  description = "Origin request policy ID to forward headers/cookies/query strings."
  type        = string
  default     = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "is_ipv6_enabled" {
  description = "Whether IPv6 is enabled."
  type        = bool
  default     = true
}

variable "wait_for_deployment" {
  description = "Whether to wait for the distribution deployment to complete."
  type        = bool
  default     = false
}

variable "redirect_www_to_apex_function_code" {
  description = "CloudFront function code for redirecting www subdomain traffic."
  type        = string
  default     = <<EOT
function handler(event) {
  var request = event.request;
  var headers = request.headers || {};
  var hostHeader = headers.host && headers.host.value ? headers.host.value : '';
  if (hostHeader.toLowerCase().startsWith('www.')) {
    var newHost = hostHeader.substring(4);
    var location = 'https://' + newHost + (request.uri || '/');
    var qs = '';
    var qsObj = request.querystring || {};
    var keys = Object.keys(qsObj);
    if (keys.length > 0) {
      var parts = [];
      for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        var val = qsObj[key];
        if (val && typeof val.value !== 'undefined') {
          parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(val.value));
        }
      }
      if (parts.length > 0) {
        qs = '?' + parts.join('&');
      }
    }
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: {
        location: { value: location + qs }
      }
    };
  }
  return request;
}
EOT
}

