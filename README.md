# Nomatron application stack Terraform module

This module creates an application, its jobs and environments, optional approval policy, and app-, job-, or organization-scoped variables in an existing Nomatron organization. The organization and Nomad cluster must already exist.

Terraform 1.11 or later is required because sensitive variable values use Terraform's write-only `value_wo` attributes.

## Usage

```hcl
module "app_stack" {
  source = "nomatronio/app-stack/nomatron"

  org_name   = "example-org"
  name       = "Example web service"
  slug       = "example-web-service"
  cluster_id = "cluster-id-from-your-account"
  repo_url   = "https://github.com/example/example-web-service"

  jobs = {
    web = {
      name         = "Web"
      jobspec_type = "hcl"
      source_mode  = "file"
      jobspec_path = "deploy/web.nomad.hcl"
      priority     = 10
    }
  }

  environments = {
    staging = {
      name      = "Staging"
      namespace = "example-staging"
      priority  = 10
    }
    production = {
      name      = "Production"
      namespace = "example-production"
      priority  = 20
    }
  }

  variables = {
    log_level = {
      scope = "app"
      key   = "LOG_LEVEL"
      value = "info"
      environment_values = {
        production = {
          value = "info"
        }
      }
    }
    registry_token = {
      scope     = "job"
      job_key   = "web"
      key       = "REGISTRY_TOKEN"
      sensitive = true
      value_wo  = var.registry_token
    }
  }

  approval_policy = {
    default_rule = {
      required_approvals = 1
      users              = ["platform.admin"]
    }
    environment_rules = {
      production = {
        required_approvals = 2
        groups             = ["release-managers"]
      }
    }
  }
}
```

The root configuration must declare the `nomatronio/nomatron` provider at `~> 0.6` and configure it with an API address and token. The module does not configure a provider. Set secrets through a sensitive root variable and pass them to the module's `value_wo`; do not put secret values in ordinary Terraform variables or outputs.

At least one environment is required. If an application slug is omitted, child resources use the computed application slug and Terraform creates the application first. Setting a stable slug is recommended so dependent resources have predictable identifiers.

The `jobs` map key becomes the job slug unless `slug` is set. Jobs default to file source mode and require `jobspec_path`; directory mode requires `source_directory`. `job_var_file_paths` can be set only with directory mode. `jobspec_type` is required; this module's examples use `hcl`.

Do not set `nomatron_job.is_primary`; the provider computes it from `priority` (`priority = 10` is the primary deployment group).

## Approval policies

Environment rules are keyed by an environment map key or its explicit slug. The module resolves the corresponding environment ID for the provider. The default policy created by the server is not managed when `approval_policy` is null. If adopting an existing policy, import it before managing it with this module.

Approver groups may be group names or IDs. Being in an approver group does not grant the permission to update application jobs; that permission comes from a role or an OIDC group mapping. OIDC group mappings take effect at the user's next sign-in when group sync is enabled, and do not add organization membership. Service accounts cannot approve. This module does not assign roles or create users.

## Variables

The variable map key is a module-local handle; `key` defaults to that map key. Supported scopes are `organization`, `app`, and `job`; global variables are not managed here. Organization-scoped variables cannot have job or environment-specific values. A job-scoped variable must set `job_key` to a key in `jobs`.

For non-sensitive values, set `value` and use `value` in each `environment_values` entry. For sensitive values, set `sensitive = true` and use `value_wo` in every location. The two attributes are mutually exclusive. Environment value keys may be an environment map key or explicit slug.

## Example plan

The basic example uses placeholder organization and cluster IDs. Replace them and set the API address for an account before running a plan:

```sh
export TF_VAR_nomatron_address="https://api.example.invalid"
export TF_VAR_nomatron_token="$NOMATRON_TOKEN"
terraform -chdir=examples/basic init
terraform -chdir=examples/basic plan
```

The token is read from the `NOMATRON_TOKEN` environment variable and is not included in command arguments. The example defaults are placeholders and must be replaced before applying.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `org_name` | `string` | — | Existing organization name. |
| `name` | `string` | — | Application display name. |
| `cluster_id` | `string` | — | Existing cluster ID; also the default for environments. |
| `repo_url` | `string` | — | Source repository URL. |
| `environments` | `map(object)` | — | App environments; at least one is required. |
| `slug` | `string` | `null` | Stable application slug; server-generated if omitted. |
| `description` | `string` | `null` | Application description. |
| `git_provider` | `string` | `null` | Git provider value, such as `github`. |
| `trigger_mode` | `string` | `null` | `branch_commit` or `tag`. |
| `ref` | `string` | `null` | Branch ref; for tag mode it must be `main` or empty. |
| `tag_pattern_type` | `string` | `null` | `semver`, `prefix`, `suffix`, or `custom_regex`. |
| `tag_pattern` | `string` | `null` | Tag prefix, suffix, or regular expression. |
| `vcs_github_id` | `string` | `null` | Existing GitHub App integration ID. |
| `skip_repo_access_validation` | `bool` | `null` | Skip repository access validation during bootstrap. |
| `jobs` | `map(object)` | `{}` | Jobs keyed by stable local handle. |
| `variables` | `map(object)` | `{}` | App, job, or organization-scoped variables. |
| `approval_policy` | `object` | `null` | Optional default rule and slug-keyed environment rules. |

See [variables.tf](variables.tf) for full object types and validation rules.

## Outputs

| Name | Description |
| --- | --- |
| `application_id` | Application ID. |
| `application_slug` | Application slug. |
| `jobs` | Job IDs, slugs, effective repository URLs, computed primary status, and priorities. |
| `environments` | Environment IDs, slugs, cluster IDs, namespaces, and priorities. |
| `variable_ids` | Variable IDs, keys, scopes, and value IDs; no values are exposed. |
| `approval_policy_id` | Approval policy composite ID, or `null` when unmanaged. |
| `approval_policy_version` | Approval policy version, or `null` when unmanaged. |

## Importing existing resources

Import resources into the module's resource addresses. The examples below assume a module instance named `app_stack`:

```sh
terraform import 'module.app_stack.nomatron_application.this' 'example-org/example-app'
terraform import 'module.app_stack.nomatron_job.this["web"]' 'example-org/example-app/web'
terraform import 'module.app_stack.nomatron_environment.this["production"]' 'example-org/example-app/production'
terraform import 'module.app_stack.nomatron_approval_policy.this[0]' 'example-org/example-app'
terraform import 'module.app_stack.nomatron_variable.this["log_level"]' 'app/example-org/example-app/VARIABLE_ID'
terraform import 'module.app_stack.nomatron_variable.this["runtime_secret"]' 'job/example-org/example-app/web/VARIABLE_ID'
terraform import 'module.app_stack.nomatron_variable.this["org_setting"]' 'organization/example-org/VARIABLE_ID'
```

## Testing

Run `terraform fmt -check -recursive`, `terraform init -backend=false`, `terraform validate`, and `terraform test` from the module root. Tests use Terraform's mock Nomatron provider and do not contact a live server. `tflint` can also be run from the module root when installed.
