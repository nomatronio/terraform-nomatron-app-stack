output "application_slug" {
  description = "Application slug."
  value       = module.app_stack.application_slug
}

output "jobs" {
  description = "Job identifiers and deployment priorities."
  value       = module.app_stack.jobs
}

output "environments" {
  description = "Environment identifiers and settings."
  value       = module.app_stack.environments
}

output "approval_policy_id" {
  description = "Managed approval policy ID."
  value       = module.app_stack.approval_policy_id
}
