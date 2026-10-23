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

# The repo uses immutable OIDC subjects (repo:<owner>@<owner_id>/<repo>@<repo_id>:...),
# see gh api repos/<owner>/<repo>/actions/oidc/customization/sub
variable "github_owner" {
  description = "GitHub owner of the repo allowed to assume the deployer role."
  type        = string
}

variable "github_owner_id" {
  description = "Numeric id of github_owner (gh api users/<owner> --jq .id)."
  type        = string
}

variable "github_repo" {
  description = "Repo name (without owner) allowed to assume the deployer role."
  type        = string
}

variable "github_repo_id" {
  description = "Numeric id of github_repo (gh api repos/<owner>/<repo> --jq .id)."
  type        = string
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
