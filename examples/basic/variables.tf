variable "nomatron_address" {
  type        = string
  description = "Nomatron API address."
}

variable "nomatron_token" {
  type        = string
  sensitive   = true
  description = "Nomatron API token."
}

variable "org_name" {
  type        = string
  description = "Existing Nomatron organization name."
  default     = "example-org"
}

variable "cluster_id" {
  type        = string
  description = "Existing Nomad cluster ID."
  default     = "cluster-example"
}
