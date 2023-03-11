terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  required_version = "1.3.9"
}

variable "bucket_name" {
  description = "bucket name"
  default     = "masterclass-bucketo"
  type        = string
}

variable "dyno_table_name" {
  description = "terraform state table name"
  default     = "terraform-locks-table"
  type        = string
}

variable "region_name" {
  description = "region name"
  default     = "us-east-1"
  type        = string
}

provider "aws" {
  region = var.region_name
}

terraform {
  backend "s3" {
    bucket = "masterclass-bucketo"
    key    = "global/s3/terraform.tfstate"
    region = "us-east-1"

    dynamodb_table = "terraform-locks-table"
    encrypt        = true
  }
}

resource "aws_s3_bucket" "state_backend" {
  bucket = var.bucket_name
  # force_destroy = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_acl" "state_backend" {
  bucket = aws_s3_bucket.state_backend.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.state_backend.id

  # Enable versioning so we can see the full revision history of our state files
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "js_sdsdnk_bjsdu829-" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket_versioning.versioning_example.id

  # Enable server-side encryption by default
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dyno_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
