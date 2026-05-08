# Terraform and provider config
# Change project, region, and zone to match your GCP project

terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "class75-jorunesimpkins-490100"
  region  = "us-central1"
  zone    = "us-central1-a"
}