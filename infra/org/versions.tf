terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Single env, so the config is inline. The bucket is created by this stack (bootstrap: docs/architecture.md).
  backend "s3" {
    bucket       = "tonton-pinochet-cloudnative-org-tfstate"
    key          = "org/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "sso"
  region = var.sso_region
}
