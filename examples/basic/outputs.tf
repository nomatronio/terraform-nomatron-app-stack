output "application_id" {
  description = "Created application ID."
  value       = module.app_stack.application_id
}

output "application_slug" {
  description = "Application slug."
  value       = module.app_stack.application_slug
}
