# --- Repository (created by hand, adopted here) ---

import {
  to = github_repository.this
  id = var.repository
}

resource "github_repository" "this" {
  name         = var.repository
  has_issues   = true
  has_projects = true

  # Linear history: squash merge only, PR title as commit title (Conventional Commits).
  allow_squash_merge          = true
  allow_merge_commit          = false
  allow_rebase_merge          = false
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "COMMIT_MESSAGES"
  # Off: the dev -> main PR would delete dev.
  delete_branch_on_merge = false

  lifecycle {
    prevent_destroy = true
    # Visibility is a deliberate manual choice, never flipped by an apply.
    ignore_changes = [visibility]
  }
}

# --- main protection ---

resource "github_branch_protection" "main" {
  repository_id = github_repository.this.node_id
  pattern       = "main"

  # Admins too: no direct push to main for anyone.
  enforce_admins                  = true
  require_signed_commits          = true
  required_linear_history         = true
  require_conversation_resolution = true
  allows_force_pushes             = false
  allows_deletions                = false

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
  }

  # Empty until ci.yml exists: requiring a check that never runs would block every PR.
  dynamic "required_status_checks" {
    for_each = length(var.required_status_checks) > 0 ? [1] : []

    content {
      strict   = true
      contexts = var.required_status_checks
    }
  }
}

# --- Environments (the deployer role trust policy is bound to environment:<env>) ---

data "github_user" "prd_reviewer" {
  for_each = toset(var.prd_reviewers)
  username = each.value
}

resource "github_repository_environment" "env" {
  for_each = toset(["dev", "prd"])

  repository          = github_repository.this.name
  environment         = each.key
  prevent_self_review = each.key == "prd"
  can_admins_bypass   = each.key != "prd"

  dynamic "reviewers" {
    for_each = each.key == "prd" ? [1] : []

    content {
      users = [for u in data.github_user.prd_reviewer : tonumber(u.id)]
    }
  }
}

# --- Repo variables for keyless AWS auth (no AWS secret anywhere) ---

resource "github_actions_variable" "this" {
  for_each = merge({
    AWS_REGION       = var.aws_region
    AWS_ROLE_ARN_DEV = var.deployer_role_arns["dev"]
    AWS_ROLE_ARN_PRD = var.deployer_role_arns["prd"]
    # release.yml refuses tags pushed by anyone else
    RELEASE_ACTORS = join(",", var.release_actors)
    },
    # GitHub rejects empty variables: no label means no variable (runs-on falls back to ubuntu-latest).
    var.runner_label == "" ? {} : { RUNNER_LABEL = var.runner_label }
  )

  repository    = github_repository.this.name
  variable_name = each.key
  value         = each.value
}

# --- Collaborators (team + instructor) ---

resource "github_repository_collaborator" "this" {
  for_each = var.collaborators

  repository = github_repository.this.name
  username   = each.key
  permission = each.value
}
