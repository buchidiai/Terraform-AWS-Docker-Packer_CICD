#terraform settings
terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
    }
  }
  required_version = "1.3.9" # or latest Terraform version
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "terraform_state" {

  bucket = "terraform-code-bucket"

  lifecycle {
  	prevent_destroy = true
  }

  # Enable versioning so we can see the full revision history of our
  # state files
  versioning {
    enabled = true
  }

  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}