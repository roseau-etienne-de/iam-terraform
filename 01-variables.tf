variable "project_id" {
  description = "Main project where IAM applies"
  type        = string
}

variable "tfstate_bucket" {
  description = "GCP bucket where terraform state is stored"
  type        = string
}

variable "region" {
  description = "GCP region where resources are deployed"
  type        = string
}
