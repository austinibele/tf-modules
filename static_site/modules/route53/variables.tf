variable "domain" {
  description = "Root domain for the hosted zone."
  type        = string
}

variable "distribution_domain_name" {
  description = "CloudFront distribution domain name for alias records."
  type        = string
}

variable "distribution_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution."
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate associated with the distribution."
  type        = string
}

variable "certificate_domain_validation_options" {
  description = "Domain validation options returned by the ACM certificate."
  type = list(object({
    domain_name           = string
    resource_record_name  = string
    resource_record_type  = string
    resource_record_value = string
  }))
}

variable "additional_records" {
  description = "Additional non-alias DNS records to create. Map key is an identifier for the record."
  type = map(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  }))
  default = {}
}

