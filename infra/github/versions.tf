terraform {
  required_version = ">= 1.10"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Local state on purpose: applied by hand by a repo admin, like infra/org and infra/access.
}

# Credentials: GITHUB_TOKEN of a repo admin (e.g. `export GITHUB_TOKEN=$(gh auth token)`).
provider "github" {
  owner = var.owner
}
