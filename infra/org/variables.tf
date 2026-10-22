variable "team" {
  description = "Team prefix used in every resource name (e.g. team42 -> team42-cloudnative-dev)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,30}$", var.team))
    error_message = "team must be 2-30 chars of lowercase letters, digits or dashes."
  }
}

variable "email_base" {
  description = "Mailbox supporting plus-addressing; each account gets <local>+<env>@<domain>."
  type        = string

  validation {
    condition     = can(regex("^[^@+]+@[^@]+$", var.email_base))
    error_message = "email_base must be a plain address without '+' (e.g. name@gmail.com)."
  }
}

variable "envs" {
  description = "Environments, one member account each."
  type        = set(string)
  default     = ["dev", "prd"]
}

variable "region" {
  description = "Region used by the provider (Organizations itself is global)."
  type        = string
  default     = "eu-west-3"
}

variable "sso_region" {
  description = "Region where IAM Identity Center is enabled."
  type        = string
  default     = "eu-west-1"
}

variable "team_emails" {
  description = "Team members signing in through Identity Center. Format firstname.lastname@domain (username = local part). Keep in gitignored terraform.tfvars."
  type        = set(string)

  validation {
    condition     = alltrue([for e in var.team_emails : can(regex("^[a-z]+\\.[a-z-]+@[^@]+$", e))])
    error_message = "Each email must look like firstname.lastname@domain, lowercase."
  }
}
