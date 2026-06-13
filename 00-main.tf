terraform {
  required_version = ">=1.9.5"
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
  }
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

provider "google" {
  project = var.project_id
  region  = var.region
}

terraform {
  backend "gcs" {
    bucket = var.tfstate_bucket
    prefix = "${var.project_id}/iam"
  }
}
