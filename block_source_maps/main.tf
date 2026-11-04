variable "name_prefix" {
  type        = string
  default     = ""
  description = "Prefix for the CloudFront Function name; include namespace and environment so each env is unique in the AWS account."
}

# A behavior takes one viewer-request function. Where this function already sits on a
# behavior whose origin is the shared ALB, it also sets the origin-verify header from the
# key value store that infra-shared writes, so the shared stack alone rotates the value.
variable "key_value_store_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "CloudFront KeyValueStore holding the origin-verify value. Null leaves the function as the .map blocker alone."
}

variable "origin_verify_key" {
  type        = string
  default     = "x-origin-verify"
  description = "Key in the store whose value is sent to the origin."
}

variable "origin_verify_header_names" {
  type        = list(string)
  default     = ["x-origin-verify"]
  description = "Request headers set to the store value (lower-case). A second name is used only while a migration verifies the function path."
}

resource "aws_cloudfront_function" "block_source_maps" {
  name    = var.name_prefix != "" ? "${var.name_prefix}-block-source-maps" : "block-source-maps"
  runtime = "cloudfront-js-2.0"
  publish = true

  key_value_store_associations = var.key_value_store_arn == null ? [] : [var.key_value_store_arn]

  code = var.key_value_store_arn == null ? local.code_block_only : local.code_block_and_origin_verify
}

locals {
  code_block_only = <<-EOF
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

  code_block_and_origin_verify = <<-EOF
    import cf from 'cloudfront';
    const kvs = cf.kvs();
    async function handler(event) {
      const request = event.request;
      if (request.uri.endsWith('.map')) {
        return {
          statusCode: 403,
          statusDescription: 'Forbidden',
        };
      }
      // No store, no header: the origin's firewall decides. An uncaught error here would answer 503 to every viewer.
      let value;
      try {
        value = await kvs.get('${var.origin_verify_key}');
      } catch (error) {
        return request;
      }
    %{for name in var.origin_verify_header_names~}
      request.headers['${name}'] = { value: value };
    %{endfor~}
      return request;
    }
  EOF
}

output "function_arn" {
  value = aws_cloudfront_function.block_source_maps.arn
}
