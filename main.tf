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

  name = "terraform_server_security_group"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}




resource "aws_launch_configuration" "ec2_collection" {
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

# get the details of default vpc (virual private clod)
data "aws_vpc" "default" {
  default = true
}

# use the default vpc id and get the default subnets ids
data "aws_subnet_ids" "default_subnet_ids" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.ec2_collection.name
  vpc_zone_identifier = data.aws_subnet_ids.default_subnet_ids.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key = "Name"
    value = "Terraform_Auto_Scale_Group"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

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
resource "aws_lb" "example" {
  name = "Terraform_Auto_Scale_Group"
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.default_subnet_ids.ids
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
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

resource "aws_lb_target_group" "asg" {
  name = "terraform-example-target-group"

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


output "public_ip" {
  value = aws_instance.EC2_Server.public_ip
  description = "The public IP address of the web server"
}

output "alb_dns_name" {
  value = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}