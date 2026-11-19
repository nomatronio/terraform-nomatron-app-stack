module "app_stack" {
  source = "../.."

  org_name         = var.org_name
  name             = "Example web service"
  slug             = "example-web-service"
  cluster_id       = var.cluster_id
  repo_url         = "https://github.com/example/example-web-service"
  git_provider     = "github"
  trigger_mode     = "tag"
  tag_pattern_type = "semver"

  jobs = {
    web = {
      name             = "Web"
      jobspec_type     = "hcl"
      source_mode      = "directory"
      source_directory = "deploy"
      job_file_path    = "web.nomad.hcl"
      job_var_file_paths = [
        "vars/common.hcl",
      ]
      priority = 10
    }
  }

  environments = {
    staging = {
      name      = "Staging"
      slug      = "staging"
      namespace = "example-staging"
      priority  = 10
    }
    production = {
      name      = "Production"
      slug      = "production"
      namespace = "example-production"
      priority  = 20
    }
  }

  variables = {
    log_level = {
      scope      = "app"
      key        = "LOG_LEVEL"
      value_type = "string"
      value      = "info"
      environment_values = {
        staging = {
          value = "debug"
        }
        production = {
          value = "info"
        }
      }
    }
    runtime_secret = {
      scope     = "job"
      job_key   = "web"
      key       = "RUNTIME_SECRET"
      sensitive = true
      value_wo  = var.runtime_secret
      environment_values = {
        staging = {
          value_wo = var.runtime_secret
        }
        production = {
          value_wo = var.runtime_secret
        }
      }
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
