packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-3"
}

variable "profile" {
  type    = string
  default = "<tfuser>"
}

data "amazon-ami" "ubuntu" {
  filters = {
    name                = "ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
  region      = var.region
  profile     = var.profile
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "ubuntu-22.04-custom-{{timestamp}}"
  instance_type = "t2.micro"
  region        = var.region
  profile       = var.profile
  source_ami    = data.amazon-ami.ubuntu.id
  ssh_username  = "ubuntu"

  tags = {
    Name = "Ubuntu 24.04 Custom AMI"
    OS   = "Ubuntu"
    Version = "24.04"
  }
}

build {
  name = "ubuntu-custom"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "sleep 30",
      "sudo apt-get update",
      "sudo mkdir -p /root/.ssh",
      "echo '<VOTRE_CLÉ_PUBLIQUE>' | sudo tee /root/.ssh/authorized_keys",
      "sudo chmod 700 /root/.ssh",
      "sudo chmod 600 /root/.ssh/authorized_keys",
      "sudo chown -R root:root /root/.ssh",
      "echo 'Custom AMI build completed'"
    ]
  }
}