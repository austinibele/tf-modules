variable "comment" {
  description = "Distribution comment (shown in the CloudFront console)."
  type        = string
}

variable "aliases" {
  description = "Viewer alternate domain names (CNAMEs)."
  type        = list(string)
}

variable "acm_certificate_arn" {
  description = "us-east-1 ACM certificate ARN for the viewer aliases."
  type        = string
}

variable "origin_domain_name" {
  description = "ALB DNS name used as the HTTPS origin."
  type        = string
}

variable "origin_verify_secret" {
  description = "Value of the X-Origin-Verify custom origin header."
  type        = string
  sensitive   = true
}

variable "web_acl_arn" {
  description = "CloudFront-scope WAF Web ACL ARN. Null leaves the distribution unprotected."
  type        = string
  default     = null
  nullable    = true
}

variable "origin_read_timeout" {
  description = "Origin read timeout in seconds. AWS/CloudFront default is 30."
  type        = number
  default     = 30
}

variable "http_version" {
  description = "Viewer HTTP versions. Use \"http2\" for long-lived streams (SSE): an established QUIC connection that dies surfaces as ERR_QUIC_PROTOCOL_ERROR with no fallback."
  type        = string
  default     = "http2and3"

  validation {
    condition     = contains(["http1.1", "http2", "http2and3", "http3"], var.http_version)
    error_message = "http_version must be one of http1.1, http2, http2and3, http3."
  }
}

variable "tags" {
  description = "Tags applied to the distribution."
  type        = map(string)
  default     = {}
}
