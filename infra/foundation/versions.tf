terraform {
  required_version = ">= 1.10"

  # State in the account's bucket created by infra/access.
  # terraform init -backend-config=backends/<env>.hcl
  backend "s3" {}
}
