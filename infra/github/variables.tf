variable "owner" {
  description = "GitHub account owning the repository."
  type        = string
  default     = "cterlecki"
}

variable "repository" {
  description = "Repository name."
  type        = string
  default     = "tonton_pinochet_cloudnative"
}

variable "collaborators" {
  description = "Collaborator login -> permission (pull, triage, push, maintain, admin). The owner is not listed."
  type        = map(string)

  validation {
    condition     = alltrue([for p in values(var.collaborators) : contains(["pull", "triage", "push", "maintain", "admin"], p)])
    error_message = "permission must be one of pull, triage, push, maintain, admin."
  }
}

variable "prd_reviewers" {
  description = "Logins allowed to approve deployments to the prd environment."
  type        = list(string)
}

variable "release_actors" {
  description = "GitHub logins allowed to push release tags (release.yml)"
  type        = list(string)
}

variable "required_status_checks" {
  description = "Check names that must pass before merging to main (filled once ci.yml exists, issue #6)."
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "Exposed to workflows as AWS_REGION."
  type        = string
  default     = "eu-west-3"
}

variable "deployer_role_arns" {
  description = "infra/access output deployer_role_arn per environment."
  type        = map(string)

  validation {
    condition     = toset(keys(var.deployer_role_arns)) == toset(["dev", "prd"])
    error_message = "deployer_role_arns must have exactly the keys dev and prd."
  }
}

variable "runner_label" {
  description = "infra/foundation output runner_label (ARC scale set name), exposed as RUNNER_LABEL. Empty = no variable, workflows fall back to ubuntu-latest."
  type        = string
  default     = ""
}
