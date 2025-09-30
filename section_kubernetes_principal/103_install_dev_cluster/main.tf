terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-west-3" # DC de paris
  profile = "default"
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "Simple Web Server"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  # "099720109477" is Canonical's official AWS account ID
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
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