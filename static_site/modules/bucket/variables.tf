variable "bucket_name" {
  description = "Name of the S3 bucket to create."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all S3 resources."
  type        = map(string)
  default     = {}
}

variable "index_document" {
  description = "Index document for S3 static website hosting."
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Error document for S3 static website hosting."
  type        = string
  default     = "error.html"
}

variable "enable_website_configuration" {
  description = "Whether to configure the S3 website endpoint. CloudFront REST origins do not need it."
  type        = bool
  default     = true
}

variable "object_ownership" {
  description = "S3 object ownership mode for the bucket."
  type        = string
  default     = "BucketOwnerPreferred"
}

variable "enable_server_side_encryption" {
  description = "Whether to enable default S3-managed server-side encryption."
  type        = bool
  default     = false
}
