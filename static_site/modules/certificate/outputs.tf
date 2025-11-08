output "certificate_arn" {
  description = "ARN of the ACM certificate."
  value       = aws_acm_certificate.website.arn
}

output "domain_validation_options" {
  description = "Domain validation options for DNS records."
  value       = aws_acm_certificate.website.domain_validation_options
}

