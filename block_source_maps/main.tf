variable "name_prefix" {
  type        = string
  default     = ""
  description = "Prefix for the CloudFront Function name; include namespace and environment so each env is unique in the AWS account."
}

resource "aws_cloudfront_function" "block_source_maps" {
  name    = var.name_prefix != "" ? "${var.name_prefix}-block-source-maps" : "block-source-maps"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-EOF
    function handler(event) {
      if (event.request.uri.endsWith('.map')) {
        return {
          statusCode: 403,
          statusDescription: 'Forbidden',
        };
      }
      return event.request;
    }
  EOF
}

output "function_arn" {
  value = aws_cloudfront_function.block_source_maps.arn
}
