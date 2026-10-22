locals {
  name = "${var.team}-cloudnative-${var.environment}"
}

# --- Terraform state bucket (used by every stack of this account) ---

resource "aws_s3_bucket" "tfstate" {
  bucket = "${local.name}-tfstate"

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

# --- Keyless CI: GitHub OIDC -> deployer role ---

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "deployer_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only jobs running in the matching GitHub environment of this repo.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "deployer" {
  name                 = "github-deployer"
  assume_role_policy   = data.aws_iam_policy_document.deployer_trust.json
  max_session_duration = 3600
}

# shortcut: full admin for the deployer, scope it down once the foundation/serverless resources are known.
resource "aws_iam_role_policy_attachment" "deployer_admin" {
  role       = aws_iam_role.deployer.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- Instructor access (credentials created by hand so they never reach state) ---

resource "aws_iam_user" "instructor" {
  name = var.instructor_user_name
}

resource "aws_iam_user_policy_attachment" "instructor" {
  for_each = toset([
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess",
  ])

  user       = aws_iam_user.instructor.name
  policy_arn = each.value
}

# --- Budget ---

resource "aws_budgets_budget" "monthly" {
  name         = "${local.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = [50, 90, 100]

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.budget_emails
    }
  }
}
