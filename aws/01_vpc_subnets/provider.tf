terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region     = "ap-southeast-1" # Singapore
  access_key = var.access_key
  secret_key = var.secret_key
}
