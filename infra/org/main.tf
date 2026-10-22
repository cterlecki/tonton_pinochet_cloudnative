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
