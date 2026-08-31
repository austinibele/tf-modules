# CloudFront-scope Web ACLs (scope = "CLOUDFRONT") must be created in us-east-1.
# Callers must pass a provider configured for us-east-1. This module does not
# declare a provider alias so it matches terraform/stacks/infra-crm/waf.tf,
# which uses the stack's default provider (region = var.aws_region, us-east-1).
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.73.0"
    }
  }
}
