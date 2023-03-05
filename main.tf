terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
    }
  }
  required_version = "1.3.9" # or latest Terraform version
}

provider "aws" {
  region = "us-east-2"
}

variable "server_port" {
  description = "The port the server will be listening on"
  default = 8080
  type = number
}

resource "aws_instance" "EC2_Server" {
  ami = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = <<-EOF
  #!/bin/bash
  echo "Hello, World" > index.html
  nohup busybox httpd -f -p ${var.server_port} &
  EOF

  tags = {
    Name = "Terraform_Server"
  }
}


resource "aws_security_group" "instance" {

  name = "terraform-server-example"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


output "public_ip" {
  value = aws_instance.EC2_Server.public_ip
  description = "The public IP address of the web server"
}

resource "aws_launch_configuration" "example" {
  image_id = "ami-0baa981b80a5a70f1"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
    EOF

#   lifecycle {
#     create_before_destroy = true
#   }
}

# get the details of default vpc
data "aws_vpc" "default" {
  default = true
}

# use the default vpc id and get the default subnets ids
data "aws_subnet_ids" "default_subnet_ids" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
#   vpc_zone_identifier = data.aws_subnet_ids.default_subnet_ids.ids

#   target_group_arns = [aws_lb_target_group.asg.arn]
#   health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key = "Name"
    value = "Terraform_ASG"
    propagate_at_launch = true
  }
}