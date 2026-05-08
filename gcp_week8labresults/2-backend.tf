# Remote state stored in GCS — change bucket name to match your project
# Run `terraform init` after adding/changing backend config

terraform {
  backend "gcs" {
    bucket = "week7-terraform-state-class75-jorunesimpkins"
    prefix = "terraform/state"
  }
}