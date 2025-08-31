variable "enable" {
  type    = bool
  default = true
}

variable "namespace" {
  type = string
}

variable "env" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "alarm_actions" {
  type = list(string)
}

variable "filters" {
  type = list(object({
    id      = string
    pattern = string
  }))
}

variable "evaluation_periods" {
  type    = number
  default = 1
}

variable "period" {
  type    = number
  default = 60
}

variable "statistic" {
  type    = string
  default = "Sum"
}

variable "threshold" {
  type    = number
  default = 1
}

variable "include_id_in_names" {
  type    = bool
  default = true
}


