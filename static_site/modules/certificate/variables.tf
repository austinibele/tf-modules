variable "domain" {
  description = "Primary domain name for the certificate."
  type        = string
}

variable "subject_alternative_names" {
  description = "Subject alternative names for the certificate."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the ACM certificate."
  type        = map(string)
  default     = {}
}

