variable "project_id" {
    type = string
    default = "web"
    description = "Unique project ID"
}

variable "env" {
    type = string
    default = "dev"
    description = "Environment for the project"
}

variable "target_group_suffix" {
  description = "A unique suffix to ensure the target group name is unique"
  type        = string
}

# ALB vars
variable "certificate_arn" {
    type = string 
    default = ""
}

variable "enable_https" {
    type = bool 
    default = false 
}

variable "internal" {
    type = bool 
    default = false 
}

variable "load_balancer_type" {
    type = string 
    default = "application" 
}

variable "security_groups" {
    type = list(string)
    default = [""] 
}

variable "subnets" {
    type = list(string)
    default = [""] 
}

variable "target_group" {
    type = string 
    default = "ip"
}

# Target group vars
variable "create_target_group" {
    type = bool 
    default = false 
    description = "Whether or not to create an LB target group"
}

variable "port" {
    type = number 
    default = 80 
    description = "Port for the target group"
}

variable "protocol" {
    type = string 
    default = "HTTP"
}

variable "target_type" {
    type = string 
    default = "ip"
}

variable "vpc_id" {
    type = string 
    default = ""
}

variable "custom_header_name" {
    type = string 
    default = "" 
}

variable "custom_header_value" {
    type = string 
    default = "" 
}
