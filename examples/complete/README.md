# Complete application stack

This example adds a directory-mode job, staging and production environments, an approval policy, and app- and job-scoped variables. The sensitive value is passed through `value_wo` and is not exposed as an output.

Set `nomatron_address`, `nomatron_token`, and `runtime_secret` as Terraform input variables. Use `TF_VAR_nomatron_token` and `TF_VAR_runtime_secret` in your shell; do not place secret values in command arguments or files committed to version control. Replace the organization and cluster placeholders before applying.
