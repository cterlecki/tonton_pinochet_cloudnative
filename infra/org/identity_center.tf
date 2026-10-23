data "aws_ssoadmin_instances" "this" {
  provider = aws.sso
}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  # firstname.lastname@domain -> { user = "firstname.lastname", given = "Firstname", family = "Lastname" }
  members = { for e in var.team_emails : split("@", e)[0] => {
    email  = e
    given  = title(split(".", split("@", e)[0])[0])
    family = title(split(".", split("@", e)[0])[1])
  } }

  # Management account + every member account.
  all_account_ids = concat(
    [aws_organizations_organization.this.master_account_id],
    [for acct in aws_organizations_account.env : acct.id],
  )
}

resource "aws_identitystore_user" "member" {
  provider = aws.sso
  for_each = local.members

  identity_store_id = local.identity_store_id
  user_name         = each.key
  display_name      = "${each.value.given} ${each.value.family}"

  name {
    given_name  = each.value.given
    family_name = each.value.family
  }

  emails {
    value   = each.value.email
    type    = "work"
    primary = true
  }
}

resource "aws_identitystore_group" "team" {
  provider = aws.sso

  identity_store_id = local.identity_store_id
  display_name      = "team"
  description       = "${local.name} team members"
}

resource "aws_identitystore_group_membership" "team" {
  provider = aws.sso
  for_each = aws_identitystore_user.member

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.team.group_id
  member_id         = each.value.user_id
}

resource "aws_ssoadmin_permission_set" "admin" {
  provider = aws.sso

  instance_arn     = local.sso_instance_arn
  name             = "AdministratorAccess"
  description      = "Full admin for team members"
  session_duration = "PT8H"
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  provider = aws.sso

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_account_assignment" "team_admin" {
  provider = aws.sso
  for_each = toset(local.all_account_ids)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.team.group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = each.key

  depends_on = [aws_ssoadmin_managed_policy_attachment.admin]
}

# --- Instructor: read-only + billing on the member accounts, outside the team group ---

resource "aws_identitystore_user" "instructor" {
  provider = aws.sso

  identity_store_id = local.identity_store_id
  user_name         = "jeremie.jaouen"
  display_name      = "Jeremie Jaouen"

  name {
    given_name  = "Jeremie"
    family_name = "Jaouen"
  }

  emails {
    value   = var.instructor_email
    type    = "work"
    primary = true
  }
}

resource "aws_ssoadmin_permission_set" "instructor" {
  provider = aws.sso

  instance_arn     = local.sso_instance_arn
  name             = "InstructorReadOnly"
  description      = "Read-only and billing view for the instructor"
  session_duration = "PT8H"
}

resource "aws_ssoadmin_managed_policy_attachment" "instructor" {
  provider = aws.sso
  for_each = toset([
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess",
  ])

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.instructor.arn
  managed_policy_arn = each.value
}

# Member accounts only: the management account would also expose Organizations and Identity Center.
resource "aws_ssoadmin_account_assignment" "instructor" {
  provider = aws.sso
  for_each = aws_organizations_account.env

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.instructor.arn
  principal_type     = "USER"
  principal_id       = aws_identitystore_user.instructor.user_id
  target_type        = "AWS_ACCOUNT"
  target_id          = each.value.id

  depends_on = [aws_ssoadmin_managed_policy_attachment.instructor]
}
