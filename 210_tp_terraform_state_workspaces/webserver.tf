# Data source pour l'AMI Ubuntu standard
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Template pour user-data
data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh.tpl")

  vars = {
    ssh_public_key = file("${var.ssh_key_path}.pub")
    feature_name   = var.feature_name
    workspace      = terraform.workspace
  }
}

# Instance EC2 avec user-data
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_ssh_access.id]
  user_data              = data.template_file.user_data.rendered

  tags = {
    Name      = "${terraform.workspace}-web-server"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}

# Outputs webserver
output "instance_id" {
  value = aws_instance.web_server.id
}

output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "web_url" {
  value = "http://${aws_instance.web_server.public_ip}"
}