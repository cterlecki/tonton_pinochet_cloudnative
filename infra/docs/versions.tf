terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State in the account's bucket created by infra/access.
  # terraform init -backend-config=backends/dev.hcl
  # Single site, hosted in the dev account only: no prd tfvars or backend on purpose.
  backend "s3" {}
}

# Credentials: an Identity Center profile for the target account (AWS_PROFILE=<env>).
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = "${var.team}-cloudnative"
      Environment = var.environment
      Stack       = "docs"
    }
  }
}
