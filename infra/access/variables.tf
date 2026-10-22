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

variable "github_repo" {
  description = "owner/repo allowed to assume the deployer role."
  type        = string
  default     = "cterlecki/tonton_pinochet_cloudnative"
}

variable "instructor_user_name" {
  description = "IAM user name for the instructor."
  type        = string
  default     = "jeremie.jaouen"
}

variable "budget_limit_usd" {
  description = "Monthly budget for this account, in USD."
  type        = number
  default     = 30
}

variable "budget_emails" {
  description = "Recipients of budget alerts. Keep in gitignored terraform.tfvars (public repo)."
  type        = list(string)

  validation {
    condition     = length(var.budget_emails) > 0
    error_message = "At least one budget email is required."
  }
}
