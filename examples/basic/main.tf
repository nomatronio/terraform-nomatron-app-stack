module "app_stack" {
  source = "../.."

  org_name   = var.org_name
  name       = "Example app"
  slug       = "example-app"
  cluster_id = var.cluster_id
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
