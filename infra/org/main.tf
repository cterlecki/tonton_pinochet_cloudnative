locals {
  name       = "${var.team}-cloudnative"
  email_part = split("@", var.email_base)
}

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  # IAM Identity Center for team sign-in on both accounts.
  aws_service_access_principals = ["sso.amazonaws.com"]
}

resource "aws_organizations_account" "env" {
  for_each = var.envs

  name      = "${local.name}-${each.key}"
  email     = "${local.email_part[0]}+${each.key}@${local.email_part[1]}"
  role_name = "OrganizationAccountAccessRole"

  # A closed account stays suspended 90 days and burns its email: never delete from Terraform.
  close_on_deletion = false

  lifecycle {
    prevent_destroy = true
    # AWS does not return role_name after creation; ignore to avoid a forced replacement.
    ignore_changes = [role_name]
  }

  depends_on = [aws_organizations_organization.this]
}

# --- Terraform state bucket for this stack (management account) ---

resource "aws_s3_bucket" "tfstate" {
  bucket = "${local.name}-org-tfstate"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
