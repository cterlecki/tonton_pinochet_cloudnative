terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local state on purpose: this stack runs first, before any state bucket exists.
  # Migrate later with `terraform init -migrate-state` to a bucket in the management account.
}

provider "aws" {
  region = var.region
}
