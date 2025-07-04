# Data source pour l'AMI personnalisée
data "aws_ami" "custom_ubuntu" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["ubuntu-22.04-custom-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Instances EC2 avec count
resource "aws_instance" "web_server" {
  count                  = var.instance_count
  ami                    = data.aws_ami.custom_ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_servers.id]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.ssh_key_path)
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y nginx",
      "systemctl start nginx",
      "systemctl enable nginx",
      "echo '<h1>Server ${count.index + 1} - Feature: ${var.feature_name} (${terraform.workspace})</h1>' > /var/www/html/index.html",
      "echo '<p>Instance ID: ${count.index}</p>' >> /var/www/html/index.html"
    ]
  }

  tags = {
    Name      = "${terraform.workspace}-web-server-${count.index + 1}"
    Workspace = terraform.workspace
    Feature   = var.feature_name
    Server    = "web-${count.index + 1}"
  }
}

# Outputs pour les instances
output "instance_ids" {
  description = "IDs of the web server instances"
  value       = aws_instance.web_server[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses of the web server instances"
  value       = aws_instance.web_server[*].public_ip
}

# Output conditionnel pour l'ALB
output "load_balancer_dns" {
  description = "DNS name of the load balancer (if enabled)"
  value       = var.instance_count > 1 ? aws_lb.main[0].dns_name : null
}

# URL de l'application (ALB ou première instance)
output "web_url" {
  description = "URL to access the web application"
  value = var.instance_count > 1 ? 
    "http://${aws_lb.main[0].dns_name}" : 
    "http://${aws_instance.web_server[0].public_ip}"
}

# URLs de toutes les instances (pour debug)
output "individual_server_urls" {
  description = "URLs of individual servers"
  value = [
    for instance in aws_instance.web_server : 
    "http://${instance.public_ip}"
  ]
}