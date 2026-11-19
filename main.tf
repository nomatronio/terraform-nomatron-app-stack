locals {
  environment_key_by_slug = merge([
    for key, environment in var.environments : {
      (coalesce(environment.slug, key)) = key
    }
  ]...)
}

resource "nomatron_application" "this" {
  org_name                    = var.org_name
  name                        = var.name
  slug                        = var.slug
  description                 = var.description
  cluster_id                  = var.cluster_id
  repo_url                    = var.repo_url
  git_provider                = var.git_provider
  ref                         = var.ref
  trigger_mode                = var.trigger_mode
  tag_pattern_type            = var.tag_pattern_type
  tag_pattern                 = var.tag_pattern
  vcs_github_id               = var.vcs_github_id
  skip_repo_access_validation = var.skip_repo_access_validation
}

resource "nomatron_environment" "this" {
  for_each = var.environments

  org_name   = nomatron_application.this.org_name
  app_slug   = nomatron_application.this.slug
  name       = each.value.name
  slug       = coalesce(each.value.slug, each.key)
  cluster_id = coalesce(each.value.cluster_id, var.cluster_id)
  namespace  = each.value.namespace
  priority   = each.value.priority
}

resource "nomatron_job" "this" {
  for_each = var.jobs

  org_name           = nomatron_application.this.org_name
  app_slug           = nomatron_application.this.slug
  name               = each.value.name
  slug               = coalesce(each.value.slug, each.key)
  description        = each.value.description
  cluster_id         = each.value.cluster_id
  default_namespace  = each.value.default_namespace
  repo_url           = each.value.repo_url
  jobspec_type       = each.value.jobspec_type
  source_mode        = each.value.source_mode
  jobspec_path       = each.value.jobspec_path
  source_directory   = each.value.source_directory
  job_file_path      = each.value.job_file_path
  job_var_file_paths = each.value.job_var_file_paths
  priority           = each.value.priority
}

resource "nomatron_variable" "this" {
  for_each = var.variables

  scope       = each.value.scope
  org_name    = var.org_name
  app_slug    = each.value.scope == "organization" ? null : nomatron_application.this.slug
  job_slug    = each.value.scope == "job" ? try(nomatron_job.this[each.value.job_key].slug, null) : null
  key         = coalesce(each.value.key, each.key)
  description = each.value.description
  sensitive   = each.value.sensitive
  value_type  = each.value.value_type
  value       = each.value.sensitive ? null : each.value.value
  value_wo    = each.value.sensitive ? each.value.value_wo : null

  environment_values = [
    for env_slug, environment_value in each.value.environment_values : {
      environment_slug = try(coalesce(var.environments[local.environment_key_by_slug[env_slug]].slug, local.environment_key_by_slug[env_slug]), env_slug)
      value            = each.value.sensitive ? null : environment_value.value
      value_wo         = each.value.sensitive ? environment_value.value_wo : null
    }
  ]

  depends_on = [
    nomatron_environment.this,
    nomatron_job.this,
  ]

  lifecycle {
    precondition {
      condition     = each.value.scope != "job" || contains(keys(var.jobs), each.value.job_key)
      error_message = "variables[\"${each.key}\"].job_key must match an entry in jobs."
    }

    precondition {
      condition     = alltrue([for environment_slug in keys(each.value.environment_values) : contains(keys(local.environment_key_by_slug), environment_slug)])
      error_message = "variables[\"${each.key}\"].environment_values keys must match an environment map key or explicit slug."
    }

    precondition {
      condition = alltrue([
        for _, environment_value in each.value.environment_values :
        each.value.sensitive ? environment_value.value_wo != null : environment_value.value != null
      ])
      error_message = "Each environment_values entry must set value_wo when sensitive and value otherwise."
    }
  }
}

resource "nomatron_approval_policy" "this" {
  count = var.approval_policy == null ? 0 : 1

  org_name = nomatron_application.this.org_name
  app_slug = nomatron_application.this.slug

  default_rule = {
    required_approvals = var.approval_policy.default_rule.required_approvals
    users              = var.approval_policy.default_rule.users
    groups             = var.approval_policy.default_rule.groups
  }

  environment_rules = [
    for slug, rule in var.approval_policy.environment_rules : {
      environment_id     = try(nomatron_environment.this[local.environment_key_by_slug[slug]].id, null)
      required_approvals = rule.required_approvals
      users              = rule.users
      groups             = rule.groups
    }
  ]

  lifecycle {
    precondition {
      condition     = alltrue([for slug in keys(var.approval_policy.environment_rules) : contains(keys(local.environment_key_by_slug), slug)])
      error_message = "approval_policy.environment_rules keys must match an environment map key or explicit slug."
    }
  }
}
