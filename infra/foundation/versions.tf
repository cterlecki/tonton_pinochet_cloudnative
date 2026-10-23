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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
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

# Talks to the cluster created in this same stack: token fetched at apply time (needs the aws CLI).
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
}
