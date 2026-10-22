output "tfstate_bucket" {
  description = "State bucket for the other stacks of this account."
  value       = aws_s3_bucket.tfstate.bucket
}

output "deployer_role_arn" {
  description = "Set as GitHub variable AWS_ROLE_ARN_<ENV>."
  value       = aws_iam_role.deployer.arn
}

output "instructor_user" {
  description = "Create console password / access key by hand, share through a one-time secure channel."
  value       = aws_iam_user.instructor.name
}
