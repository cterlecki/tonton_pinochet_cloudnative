terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local state on purpose: this stack creates the state bucket.
  # Migrate later with `terraform init -migrate-state` to the bucket it outputs.
}

# Credentials: an Identity Center profile for the target account (AWS_PROFILE=<env>).
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = "${var.team}-cloudnative"
      Environment = var.environment
      Stack       = "access"
    }
  }
}
