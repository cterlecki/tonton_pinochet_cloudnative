terraform {
  required_version = ">= 1.10"

  # State in the account's bucket created by infra/access.
  # terraform init -backend-config=backends/<env>.hcl
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # shortcut: local state until infra/access has created the state buckets,
  # then add `backend "s3" {}` and run `terraform init -backend-config=backends/<env>.hcl -migrate-state`.
}

# Credentials: an Identity Center profile for the target account (AWS_PROFILE=<env>).
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = "${var.team}-cloudnative"
      Environment = var.environment
      Stack       = "foundation"
    }
  }
}
