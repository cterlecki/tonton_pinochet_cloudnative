variable "team" {
  description = "Team prefix, same as in infra/org."
  type        = string
}

variable "environment" {
  description = "Target environment."
  type        = string

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "environment must be dev or prd."
  }
}

variable "account_id" {
  description = "Member account id (infra/org output account_ids). Guards against applying to the wrong account."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "eu-west-3"
}

variable "vpc_cidr" {
  description = "VPC address range. Subnets are carved out of it."
  type        = string
}

variable "azs" {
  description = "Availability zones, one public + one private subnet each. EKS needs at least 2."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "EKS needs at least 2 availability zones."
  }
}
