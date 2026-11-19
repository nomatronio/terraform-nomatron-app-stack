variable "org_name" {
  type        = string
  description = "Organization name that owns the application. Maps to org_name on application, job, environment, approval policy, and non-global variables. RequiresReplace on those resources."

  validation {
    condition     = length(trimspace(var.org_name)) > 0
    error_message = "org_name must be a non-empty string."
  }
}

variable "name" {
  type        = string
  description = "Application display name. Maps to nomatron_application.name (required)."

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must be a non-empty string."
  }
}

variable "slug" {
  type        = string
  default     = null
  description = "Optional stable application slug. Maps to nomatron_application.slug (optional, computed; RequiresReplace). If omitted, the server generates one. Prefer setting this so jobs, environments, and variables can reference a known slug."
}

variable "description" {
  type        = string
  default     = null
  description = "Optional application description. Maps to nomatron_application.description."
}

variable "cluster_id" {
  type        = string
  description = "Nomad cluster ID backing the application. Maps to nomatron_application.cluster_id (required). Also the default cluster_id for environments that do not override it."

  validation {
    condition     = length(trimspace(var.cluster_id)) > 0
    error_message = "cluster_id must be a non-empty Nomad cluster ID."
  }
}

variable "repo_url" {
  type        = string
  description = "Source repository URL. Maps to nomatron_application.repo_url (required, RequiresReplace)."

  validation {
    condition     = length(trimspace(var.repo_url)) > 0
    error_message = "repo_url must be a non-empty repository URL."
  }
}

variable "git_provider" {
  type        = string
  default     = null
  description = "Optional Git provider for the repository, such as github. Maps to nomatron_application.git_provider (optional, computed, RequiresReplace). The provider lowercases this value."
}

variable "trigger_mode" {
  type        = string
  default     = null
  description = "Deployment trigger mode. Maps to nomatron_application.trigger_mode (optional, computed). Use branch_commit to deploy from branch pushes, or tag to deploy from matching Git tags. The provider defaults this to branch_commit when omitted."

  validation {
    condition     = var.trigger_mode == null || contains(["branch_commit", "tag"], var.trigger_mode)
    error_message = "trigger_mode must be branch_commit or tag when set."
  }
}

variable "ref" {
  type        = string
  default     = null
  description = "Branch ref tracked when trigger_mode is branch_commit. Maps to nomatron_application.ref (optional, computed). The provider defaults this to main when omitted. The provider errors if ref is set to a value other than main (or empty) when trigger_mode is tag."

  validation {
    condition     = var.trigger_mode != "tag" || var.ref == null || var.ref == "main" || var.ref == ""
    error_message = "ref must be main or empty when trigger_mode is tag."
  }
}

variable "tag_pattern_type" {
  type        = string
  default     = null
  description = "Tag matching style when trigger_mode is tag: semver, prefix, suffix, or custom_regex. Maps to nomatron_application.tag_pattern_type (optional, computed)."

  validation {
    condition     = var.tag_pattern_type == null || contains(["semver", "prefix", "suffix", "custom_regex"], var.tag_pattern_type)
    error_message = "tag_pattern_type must be semver, prefix, suffix, or custom_regex when set."
  }
}

variable "tag_pattern" {
  type        = string
  default     = null
  description = "Prefix, suffix, or regular expression used when trigger_mode is tag. Leave unset for semver. Maps to nomatron_application.tag_pattern (optional, computed)."
}

variable "vcs_github_id" {
  type        = string
  default     = null
  description = "Optional GitHub App integration ID for repository sync. Maps to nomatron_application.vcs_github_id (optional, RequiresReplace)."
}

variable "skip_repo_access_validation" {
  type        = bool
  default     = null
  description = "If true, skip GitHub repository and install access validation when creating the application. Maps to nomatron_application.skip_repo_access_validation (optional, RequiresReplace). Use only for bootstrap flows where the integration may be installed after Terraform creates the app."
}

variable "jobs" {
  type = map(object({
    name               = string
    slug               = optional(string)
    description        = optional(string)
    cluster_id         = optional(string)
    default_namespace  = optional(string)
    repo_url           = optional(string)
    jobspec_type       = string
    source_mode        = optional(string)
    jobspec_path       = optional(string)
    source_directory   = optional(string)
    job_file_path      = optional(string)
    job_var_file_paths = optional(list(string))
    priority           = optional(number)
  }))
  default     = {}
  description = <<-EOT
    Map of jobs. The map key is used as nomatron_job.slug when slug is omitted, so keys should be stable slugs.
    jobspec_type is required by the provider (examples use hcl; the provider does not enumerate allowed values).
    source_mode is file or directory. When omitted, the provider treats the source as file and requires jobspec_path.
    When source_mode is directory, source_directory is required; jobspec_path is not used as the source path; job_file_path and job_var_file_paths may be set. job_var_file_paths are only valid with directory mode (and the provider documents them for HCL jobspecs).
    Do not set is_primary; it is computed from priority (true when priority is 10).
    cluster_id and repo_url are optional job-level overrides.
  EOT

  validation {
    condition     = alltrue([for _, job in var.jobs : contains(["file", "directory"], coalesce(job.source_mode, "file"))])
    error_message = "jobs[*].source_mode must be file or directory when set; omitted is treated as file."
  }

  validation {
    condition     = alltrue([for _, job in var.jobs : coalesce(job.source_mode, "file") != "file" || (job.jobspec_path != null && length(trimspace(job.jobspec_path)) > 0)])
    error_message = "jobs[*].jobspec_path is required when source_mode is file or omitted."
  }

  validation {
    condition     = alltrue([for _, job in var.jobs : coalesce(job.source_mode, "file") != "file" || (job.source_directory == null && job.job_file_path == null && job.job_var_file_paths == null)])
    error_message = "jobs[*].source_directory, job_file_path, and job_var_file_paths can only be set when source_mode is directory."
  }

  validation {
    condition     = alltrue([for _, job in var.jobs : coalesce(job.source_mode, "file") != "directory" || (job.source_directory != null && length(trimspace(job.source_directory)) > 0)])
    error_message = "jobs[*].source_directory is required when source_mode is directory."
  }
}

variable "environments" {
  type = map(object({
    name       = string
    slug       = optional(string)
    cluster_id = optional(string)
    namespace  = string
    priority   = number
  }))
  description = <<-EOT
    Map of app environments. At least one is required; a deployable app needs an environment before plans or applies can run.
    The map key is used as nomatron_environment.slug when slug is omitted. Always write slug on the resource (each.value.slug or each.key) so approval policy rules and variable environment_values can be keyed predictably.
    name, namespace, and priority are required by the provider. cluster_id is required on the resource; default it to var.cluster_id when omitted.
  EOT

  validation {
    condition     = length(var.environments) > 0
    error_message = "environments must contain at least one environment. A Nomatron application needs an environment before plans or applies can run."
  }

  validation {
    condition     = alltrue([for _, env in var.environments : length(trimspace(env.name)) > 0 && length(trimspace(env.namespace)) > 0])
    error_message = "environments[*].name and namespace must be non-empty."
  }
}

variable "variables" {
  type = map(object({
    scope       = string
    key         = optional(string)
    description = optional(string)
    sensitive   = optional(bool, false)
    value_type  = optional(string, "string")
    value       = optional(string)
    value_wo    = optional(string)
    job_key     = optional(string)
    environment_values = optional(map(object({
      value    = optional(string)
      value_wo = optional(string)
    })), {})
  }))
  default     = {}
  description = <<-EOT
    Map of nomatron_variable resources. The map key is a local handle; the variable key defaults to the map key if key is omitted.
    scope must be organization, app, or job (not global). Organization scope uses org_name and no app, job, or environment values. App scope uses the application slug. Job scope requires job_key to name an entry in jobs.
    Sensitive variables must use value_wo, never value. Non-sensitive variables must use value, never value_wo. The same rule applies to each environment_values entry. value and value_wo are mutually exclusive.
    value_type must be string, number, bool, or json. environment_values is keyed by environment map key or explicit slug and is valid only for app and job scopes.
  EOT

  validation {
    condition     = alltrue([for _, v in var.variables : contains(["organization", "app", "job"], v.scope)])
    error_message = "variables[*].scope must be organization, app, or job. Global variables are out of scope for this module."
  }

  validation {
    condition     = alltrue([for _, v in var.variables : contains(["string", "number", "bool", "json"], v.value_type)])
    error_message = "variables[*].value_type must be string, number, bool, or json."
  }

  validation {
    condition     = alltrue([for _, v in var.variables : !((v.value != null) && (v.value_wo != null))])
    error_message = "variables[*]: only one of value or value_wo can be set."
  }

  validation {
    condition     = alltrue([for _, v in var.variables : !v.sensitive || v.value == null])
    error_message = "Sensitive variables must use value_wo instead of value."
  }

  validation {
    condition     = alltrue([for _, v in var.variables : v.sensitive || v.value_wo == null])
    error_message = "Non-sensitive variables must use value, not value_wo."
  }

  validation {
    condition     = alltrue([for _, v in var.variables : v.scope != "job" || (v.job_key != null && length(trimspace(v.job_key)) > 0)])
    error_message = "variables[*].job_key is required when scope is job."
  }

  validation {
    condition     = alltrue([for _, v in var.variables : v.scope != "organization" || length(v.environment_values) == 0])
    error_message = "environment_values can only be set for app or job scoped variables."
  }

  validation {
    condition     = alltrue(flatten([for _, v in var.variables : [for _, ev in v.environment_values : !((ev.value != null) && (ev.value_wo != null))]]))
    error_message = "variables[*].environment_values: only one of value or value_wo can be set."
  }

  validation {
    condition     = alltrue(flatten([for _, v in var.variables : [for _, ev in v.environment_values : !v.sensitive || ev.value == null]]))
    error_message = "Sensitive environment-specific values must use value_wo, not value."
  }

  validation {
    condition     = alltrue(flatten([for _, v in var.variables : [for _, ev in v.environment_values : v.sensitive || ev.value_wo == null]]))
    error_message = "Non-sensitive environment-specific values must use value, not value_wo."
  }
}

variable "approval_policy" {
  type = object({
    default_rule = object({
      required_approvals = number
      users              = optional(list(string), [])
      groups             = optional(list(string), [])
    })
    environment_rules = optional(map(object({
      required_approvals = number
      users              = optional(list(string), [])
      groups             = optional(list(string), [])
    })), {})
  })
  default     = null
  nullable    = true
  description = <<-EOT
    Optional application approval policy. When null, the module does not manage nomatron_approval_policy (the server still creates a default policy on the app; this module will not overwrite it).
    default_rule is required by the provider when the resource is created. required_approvals is required on every rule.
    users are usernames that can approve. groups may be names or IDs; the module passes them through.
    environment_rules is keyed by environment map key or explicit slug. The module resolves each environment ID.
  EOT
}
