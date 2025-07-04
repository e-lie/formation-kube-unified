# Outputs réseau
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "IDs of the public subnets"
  value       = [aws_subnet.public.id, aws_subnet.public_2.id]
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
  value = var.instance_count > 1 ? "http://${aws_lb.main[0].dns_name}" : "http://${aws_instance.web_server[0].public_ip}"
}

# URLs de toutes les instances (pour debug)
output "individual_server_urls" {
  description = "URLs of individual servers"
  value = [
    for instance in aws_instance.web_server : 
    "http://${instance.public_ip}"
  ]
}