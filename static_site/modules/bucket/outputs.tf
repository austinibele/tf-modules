output "bucket_id" {
  description = "The ID of the website bucket."
  value       = aws_s3_bucket.website.id
}

output "bucket_arn" {
  description = "The ARN of the website bucket."
  value       = aws_s3_bucket.website.arn
}

output "bucket_regional_domain_name" {
  description = "The regional domain name of the website bucket."
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}

output "website_endpoint" {
  description = "The S3 website endpoint URL."
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

