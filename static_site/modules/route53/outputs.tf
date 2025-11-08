output "zone_id" {
  description = "ID of the hosted zone."
  value       = aws_route53_zone.primary.zone_id
}

output "name_servers" {
  description = "Name servers for the hosted zone."
  value       = aws_route53_zone.primary.name_servers
}

output "certificate_validation_arn" {
  description = "ARN of the validated ACM certificate."
  value       = aws_acm_certificate_validation.website.certificate_arn
}

