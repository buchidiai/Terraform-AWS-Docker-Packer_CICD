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


terraform {
	backend "s3" {
		bucket = "masterclass-bucketo"
		key = "stage/services/webserver-cluster/terraform.tfstate"
		region = "us-east-1"

		dynamodb_table = "terraform-locks-table"
		encrypt = true
	}
}

module "webserver_cluster" {
	source = "../../../modules/services/webserver-cluster"

  cluster_name = "webserver-stage"
  instance_type = "t2.micro"
	min_size = 2
	max_size = 2
}