output "environments" {
  description = "GitHub environments the deployer roles trust."
  value       = keys(github_repository_environment.env)
}

output "actions_variables" {
  description = "Repo variables available to workflows as vars.<NAME>."
  value       = { for k, v in github_actions_variable.this : k => v.value }
}
