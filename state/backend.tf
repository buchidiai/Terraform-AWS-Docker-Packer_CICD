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

resource "aws_s3_bucket_versioning" "terraform_state" {

  bucket = "terraform-code-bucket"

  lifecycle {
  	prevent_destroy = true
  }

  # Enable versioning so we can see the full revision history of our
  # state files
  versioning_configuration {
    status = "Enabled"
  }


}

resource "aws_kms_key" "js_sdsdnk_bjsdu829-" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}


resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket_versioning.terraform_state.id

   # Enable server-side encryption by default
   rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
}


resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}