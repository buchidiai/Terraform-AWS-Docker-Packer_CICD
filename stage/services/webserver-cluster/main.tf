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
		bucket = "terra-bucket-01"
		key = "stage/services/webserver-cluster/terraform.tfstate"
		region = "us-east-1"

		dynamodb_table = "terraform-locks-table"
		encrypt = true
	}
}

#variable for port
variable "server_port" {
  description = "The port the server will be listening on"
  default = 8080
  type = number
}

#security group with ingress & egress ports setting
resource "aws_security_group" "instance" {
  name = "terraform_server_security_group"
  description = "default traffic"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#security group for the application load balancer
resource "aws_security_group" "alb" {
  name = "terraform-ec2-grp-alb"

  # Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# spin up ec2 instances w/ security group in auto scaling group
resource "aws_launch_configuration" "ec2-grp" {
  image_id = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
    EOF
#when Terraform must change a resource,
#Terraform will instead destroy the existing object and then create a new replacement object with the new configured arguments
  lifecycle {
    create_before_destroy = true
  }
}

# get the details of default vpc (virual private cloud)
# fetch data about default vpv when you create aws account
data "aws_vpc" "default" {
  default = true
}

# use the default vpc id and get the default subnets ids
#get subnet ids by using the default vpc
data "aws_subnets" "subnets" {
  filter {
     name   = "vpc-id"
     values = [data.aws_vpc.default.id]
   }
}
# configuration for the auto scaling group
resource "aws_autoscaling_group" "ec2-grp" {
  launch_configuration = aws_launch_configuration.ec2-grp.name
  vpc_zone_identifier = data.aws_subnets.subnets.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key = "Name"
    value = data.aws_ami.ubuntu.arn
    propagate_at_launch = true
  }
}
# configuration for the load balancer
resource "aws_lb" "ec2-grp" {
  name = "ec2-img"
  load_balancer_type = "application"
  subnets = data.aws_subnets.subnets.ids
  security_groups = [aws_security_group.alb.id]
}
#config for listener rule for appliaction load balancer
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ec2-grp.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }
}
#config for target group for appliaction load balancer
resource "aws_lb_target_group" "asg" {
  name = "terraform-ec2-grp-target-group"

  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

# config for listener rule for auto scale group
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 1

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}


output "alb_dns_name" {
  value = aws_lb.ec2-grp.dns_name
  description = "The domain name of the load balancer"
}
