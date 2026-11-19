# Basic application stack

This example creates an application, one file-mode job, and two environments in an existing organization and cluster.

Set `nomatron_address` and `nomatron_token` with Terraform input variables. For example, set `TF_VAR_nomatron_token` in your shell and provide the API address through `TF_VAR_nomatron_address`, then run `terraform init` and `terraform plan` from this directory. The organization and cluster defaults are placeholders; replace them with IDs from your Nomatron account before applying.
