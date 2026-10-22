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
