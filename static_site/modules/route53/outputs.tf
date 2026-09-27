output "zone_id" {
  description = "ID of the hosted zone."
  value       = local.zone_id
}

output "name_servers" {
  description = "Name servers for the hosted zone."
  value       = try(aws_route53_zone.primary[0].name_servers, [])
}

output "certificate_validation_arn" {
  description = "ARN of the validated ACM certificate."
  value       = aws_acm_certificate_validation.website.certificate_arn
}
