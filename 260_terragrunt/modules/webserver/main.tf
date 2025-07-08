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
  count = var.instance_count
  
  template = file("${path.module}/user-data.sh.tpl")

  vars = {
    ssh_public_key = file("${var.ssh_key_path}.pub")
    feature_name   = var.feature_name
    workspace      = var.workspace
    server_number  = count.index + 1
    instance_id    = count.index
  }
}

# Instances EC2 avec count et user-data
resource "aws_instance" "web_server" {
  count                  = var.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  user_data              = data.template_file.user_data[count.index].rendered

  tags = {
    Name      = "${var.workspace}-web-server-${count.index + 1}"
    Workspace = var.workspace
    Feature   = var.feature_name
    Server    = "web-${count.index + 1}"
  }
}