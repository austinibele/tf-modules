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
  description = "Bucket name."
  type        = string
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

