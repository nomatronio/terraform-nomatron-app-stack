mock_provider "nomatron" {
  mock_resource "nomatron_environment" {
    defaults = {
      id = "mock-environment-id"
    }
  }
}

run "basic_stack" {
  command = apply

  variables {
    org_name   = "example-org"
    name       = "Example app"
    slug       = "example-app"
    cluster_id = "cluster-example"
    repo_url   = "https://github.com/example/example-app"

    jobs = {
      web = {
        name         = "Web"
        jobspec_type = "hcl"
        source_mode  = "file"
        jobspec_path = "deploy/web.nomad.hcl"
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
  }

  assert {
    condition     = output.application_slug == "example-app"
    error_message = "The application should retain its configured slug."
  }

  assert {
    condition     = output.environments["staging"].slug == "staging" && output.environments["production"].slug == "production"
    error_message = "Environment slugs should be stable and match their map keys."
  }

  assert {
    condition     = keys(output.jobs) == ["web"] && output.approval_policy_id == null && length(output.variable_ids) == 0
    error_message = "The basic case should create one job with no managed policy or variables."
  }
}

run "complete_stack" {
  command = apply

  variables {
    org_name         = "example-org"
    name             = "Example app"
    slug             = "example-app"
    cluster_id       = "cluster-example"
    repo_url         = "https://github.com/example/example-app"
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
        scope = "app"
        key   = "LOG_LEVEL"
        value = "info"
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
        value_wo  = "test-secret-value"
        environment_values = {
          staging = {
            value_wo = "test-secret-value"
          }
          production = {
            value_wo = "test-secret-value"
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

  assert {
    condition     = output.application_slug == "example-app" && output.jobs["web"].slug == "web"
    error_message = "The complete case should create the configured application and job slugs."
  }

  assert {
    condition     = output.environments["production"].slug == "production" && output.approval_policy_id != null
    error_message = "The complete case should create the production environment and approval policy."
  }

  assert {
    condition     = nomatron_approval_policy.this[0].environment_rules[0].environment_id == "mock-environment-id"
    error_message = "Approval policy environment rules must use the resolved environment ID."
  }

  assert {
    condition     = keys(output.variable_ids) == ["log_level", "runtime_secret"]
    error_message = "The complete case should create both variables without exposing values."
  }
}

run "reject_zero_environments" {
  command = plan

  variables {
    org_name     = "example-org"
    name         = "Example app"
    cluster_id   = "cluster-example"
    repo_url     = "https://github.com/example/example-app"
    environments = {}
  }

  expect_failures = [var.environments]
}

run "reject_file_job_without_path" {
  command = plan

  variables {
    org_name   = "example-org"
    name       = "Example app"
    cluster_id = "cluster-example"
    repo_url   = "https://github.com/example/example-app"
    environments = {
      staging = {
        name      = "Staging"
        namespace = "example-staging"
        priority  = 10
      }
    }
    jobs = {
      web = {
        name         = "Web"
        jobspec_type = "hcl"
        source_mode  = "file"
      }
    }
  }

  expect_failures = [var.jobs]
}

run "reject_directory_job_without_directory" {
  command = plan

  variables {
    org_name   = "example-org"
    name       = "Example app"
    cluster_id = "cluster-example"
    repo_url   = "https://github.com/example/example-app"
    environments = {
      staging = {
        name      = "Staging"
        namespace = "example-staging"
        priority  = 10
      }
    }
    jobs = {
      web = {
        name         = "Web"
        jobspec_type = "hcl"
        source_mode  = "directory"
      }
    }
  }

  expect_failures = [var.jobs]
}

run "reject_both_variable_values" {
  command = plan

  variables {
    org_name   = "example-org"
    name       = "Example app"
    cluster_id = "cluster-example"
    repo_url   = "https://github.com/example/example-app"
    environments = {
      staging = {
        name      = "Staging"
        namespace = "example-staging"
        priority  = 10
      }
    }
    variables = {
      invalid = {
        scope    = "app"
        value    = "plain"
        value_wo = "secret"
      }
    }
  }

  expect_failures = [var.variables]
}

run "reject_sensitive_variable_using_value" {
  command = plan

  variables {
    org_name   = "example-org"
    name       = "Example app"
    cluster_id = "cluster-example"
    repo_url   = "https://github.com/example/example-app"
    environments = {
      staging = {
        name      = "Staging"
        namespace = "example-staging"
        priority  = 10
      }
    }
    variables = {
      invalid = {
        scope     = "app"
        sensitive = true
        value     = "secret"
      }
    }
  }

  expect_failures = [var.variables]
}

run "reject_unknown_environment_rule" {
  command = plan

  variables {
    org_name   = "example-org"
    name       = "Example app"
    cluster_id = "cluster-example"
    repo_url   = "https://github.com/example/example-app"
    environments = {
      staging = {
        name      = "Staging"
        namespace = "example-staging"
        priority  = 10
      }
    }
    approval_policy = {
      default_rule = {
        required_approvals = 1
      }
      environment_rules = {
        production = {
          required_approvals = 2
        }
      }
    }
  }

  expect_failures = [nomatron_approval_policy.this]
}

run "reject_unknown_variable_environment" {
  command = plan

  variables {
    org_name   = "example-org"
    name       = "Example app"
    cluster_id = "cluster-example"
    repo_url   = "https://github.com/example/example-app"
    environments = {
      staging = {
        name      = "Staging"
        namespace = "example-staging"
        priority  = 10
      }
    }
    variables = {
      setting = {
        scope = "app"
        value = "safe"
        environment_values = {
          production = {
            value = "safe"
          }
        }
      }
    }
  }

  expect_failures = [nomatron_variable.this]
}

run "reject_invalid_tag_ref" {
  command = plan

  variables {
    org_name     = "example-org"
    name         = "Example app"
    cluster_id   = "cluster-example"
    repo_url     = "https://github.com/example/example-app"
    trigger_mode = "tag"
    ref          = "release"
    environments = {
      staging = {
        name      = "Staging"
        namespace = "example-staging"
        priority  = 10
      }
    }
  }

  expect_failures = [var.ref]
}

run "reject_global_variable_scope" {
  command = plan

  variables {
    org_name   = "example-org"
    name       = "Example app"
    cluster_id = "cluster-example"
    repo_url   = "https://github.com/example/example-app"
    environments = {
      staging = {
        name      = "Staging"
        namespace = "example-staging"
        priority  = 10
      }
    }
    variables = {
      invalid = {
        scope = "global"
        value = "safe"
      }
    }
  }

  expect_failures = [var.variables]
}
