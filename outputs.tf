output "application_id" {
  description = "Application ID."
  value       = nomatron_application.this.id
}

output "application_slug" {
  description = "Application slug (known after apply, or the value you set)."
  value       = nomatron_application.this.slug
}

output "jobs" {
  description = "Map of job key to id, slug, effective_repo_url, is_primary, and priority."
  value = {
    for key, job in nomatron_job.this : key => {
      id                 = job.id
      slug               = job.slug
      effective_repo_url = job.effective_repo_url
      is_primary         = job.is_primary
      priority           = job.priority
    }
  }
}

output "environments" {
  description = "Map of environment key to id, slug, cluster_id, namespace, and priority."
  value = {
    for key, environment in nomatron_environment.this : key => {
      id         = environment.id
      slug       = environment.slug
      cluster_id = environment.cluster_id
      namespace  = environment.namespace
      priority   = environment.priority
    }
  }
}

output "variable_ids" {
  description = "Map of variable key to variable id and value_id. Does not include secret values."
  value = {
    for key, variable in nomatron_variable.this : key => {
      id       = variable.id
      key      = variable.key
      scope    = variable.scope
      value_id = variable.value_id
    }
  }
}

output "approval_policy_id" {
  description = "Approval policy composite id (org_name/app_slug), or null if the module does not manage the policy."
  value       = try(nomatron_approval_policy.this[0].id, null)
}

output "approval_policy_version" {
  description = "Approval policy version, or null if the module does not manage the policy."
  value       = try(nomatron_approval_policy.this[0].version, null)
}
