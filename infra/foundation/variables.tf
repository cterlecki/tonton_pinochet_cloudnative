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

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint. GitHub-hosted runners run foundation apply with dynamic IPs, so the default is open; access stays gated by IAM."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "github_config_url" {
  description = "Repository (or org) URL the runner scale set registers to."
  type        = string
}

variable "github_app_id" {
  description = "GitHub App id used by ARC. Not secret."
  type        = string
}

variable "github_app_installation_id" {
  description = "Installation id of that GitHub App on the repository. Not secret."
  type        = string
}
