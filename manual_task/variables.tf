
variable "permissions_boundary_arn" {
  description = "Reviewed, foundation-owned runtime permissions ceiling."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:policy/crm-security/runtime-[a-z0-9-]+$", var.permissions_boundary_arn))
    error_message = "A foundation runtime boundary ARN is required."
  }
}
