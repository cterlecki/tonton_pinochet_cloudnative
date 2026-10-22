terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State lives in the bucket this stack creates (bootstrap: docs/architecture.md, Terraform stacks).
  # terraform init -backend-config=backends/<env>.hcl
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
      Stack       = "access"
    }
  }
}
