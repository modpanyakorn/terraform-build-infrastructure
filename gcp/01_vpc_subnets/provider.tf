terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  project     = "your-project-id"
  region      = "asia-southeast1"                 # Singapore
  credentials = file("your-service-account.json") # Grant permission "owner"
}
