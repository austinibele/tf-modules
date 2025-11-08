output "bucket_id" {
  description = "ID of the S3 bucket hosting the static site."
  value       = module.static_site_bucket.bucket_id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket hosting the static site."
  value       = module.static_site_bucket.bucket_arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket."
  value       = module.static_site_bucket.bucket_regional_domain_name
}

output "website_endpoint" {
  description = "S3 static website endpoint."
  value       = module.static_site_bucket.website_endpoint
}

output "distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = module.static_site_cloudfront.distribution_id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = module.static_site_cloudfront.distribution_arn
}

output "distribution_domain_name" {
  description = "Domain name of the CloudFront distribution."
  value       = module.static_site_cloudfront.distribution_domain_name
}

output "distribution_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution."
  value       = module.static_site_cloudfront.distribution_hosted_zone_id
}

output "certificate_arn" {
  description = "ARN of the ACM certificate used by CloudFront."
  value       = module.static_site_certificate.certificate_arn
}

output "route53_zone_id" {
  description = "Hosted zone ID created for the static site domain."
  value       = module.static_site_route53.zone_id
}

output "route53_name_servers" {
  description = "Name servers of the hosted zone."
  value       = module.static_site_route53.name_servers
}

output "certificate_validation_arn" {
  description = "ARN of the validated ACM certificate."
  value       = module.static_site_route53.certificate_validation_arn
}

