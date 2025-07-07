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
  profile = "<awsprofile-votreprenom>"
}

data "aws_ami" "custom_ubuntu" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["ubuntu-22.04-custom-<votre-prenom>-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "web_ssh_access" {
  name        = "web-ssh-access-<votre-prenom>"
  description = "Allow SSH and HTTP access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web and SSH Access"
  }
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.custom_ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_ssh_access.id]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_terraform")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y nginx",
      "systemctl start nginx",
      "systemctl enable nginx",
      "echo '<h1>Hello from Terraform Provisioner!</h1>' > /var/www/html/index.html",
      "echo 'Nginx installed and configured successfully'"
    ]
  }

  tags = {
    Name = "Nginx Web Server"
    Type = "Provisioner-configured"
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

output "web_url" {
  value = "http://${aws_instance.web_server.public_ip}"
}