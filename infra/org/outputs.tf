output "account_ids" {
  description = "Member account id per environment."
  value       = { for env, acct in aws_organizations_account.env : env => acct.id }
}

output "access_role_arns" {
  description = "Role the other stacks assume in each member account."
  value       = { for env, acct in aws_organizations_account.env : env => "arn:aws:iam::${acct.id}:role/OrganizationAccountAccessRole" }
}
