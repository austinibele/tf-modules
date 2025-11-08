output "distribution_id" {
  description = "The ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "The ARN of the CloudFront distribution."
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_hosted_zone_id" {
  description = "The hosted zone ID for the CloudFront distribution."
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "function_arn" {
  description = "ARN of the CloudFront function handling redirects."
  value       = aws_cloudfront_function.redirect_www_to_apex.arn
}

