terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

locals {
  # Common tags to be assigned to all resources
  common_tags = {
    Name = "Demo-Instance"
  }
}

######################################################################################
# Create an EC2 instance with a security group and keypair.
######################################################################################
resource "aws_instance" "demo-server" {
  ami = "ami-04505e74c0741db8d"
  #   ami = "ami-033b95fb8079dc481" #Amazon Linux 2 AMI (HVM) - Kernel 5.10, SSD Volume Type 
  instance_type        = "t2.micro"
  key_name             = "Key1"
  security_groups      = [aws_security_group.demo-sg.name]
  iam_instance_profile = aws_iam_instance_profile.demo-profile.name
  tags                 = local.common_tags
  user_data            = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd.x86_64
    systemctl start httpd.service
    systemctl enable httpd.service
    echo “Hello World from $(hostname -f)” > /var/www/html/index.html
  EOF
}

######################################################################################
# Create a role , policy and attach the policy to the role
######################################################################################
resource "aws_iam_role" "demo-role" {
  name = "demo-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags               = local.common_tags
}

resource "aws_iam_policy" "demo-policy" {
  name        = "demo-policy"
  description = "A demo policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:ListBucket"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "demo-attach" {
  role       = aws_iam_role.demo-role.name
  policy_arn = aws_iam_policy.demo-policy.arn
}

######################################################################################
# Create a Security group to attach to EC2
#####################################################################################
# variable my_ip {}
resource "aws_security_group" "demo-sg" {
  name = "demo-sg"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["69.215.228.134/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["69.215.228.134/32"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["69.215.228.134/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

######################################################################################
#  Create an instance profile to assign the role to ec2
######################################################################################
resource "aws_iam_instance_profile" "demo-profile" {
  name = "demo-profile"
  role = aws_iam_role.demo-role.name
}
