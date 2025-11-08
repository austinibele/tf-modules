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

