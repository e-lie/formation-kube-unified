terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-west-3"
  profile = "<tfuser>"
}

data "aws_ami" "custom_ubuntu" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["ubuntu-24.04-custom-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.custom_ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "Custom Ubuntu Server"
    Type = "Packer-built"
  }
}

output "instance_id" {
  value = aws_instance.web_server.id
}

output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "instance_public_dns" {
  value = aws_instance.web_server.public_dns
}

output "ami_id" {
  value = data.aws_ami.custom_ubuntu.id
}

output "ami_name" {
  value = data.aws_ami.custom_ubuntu.name
}