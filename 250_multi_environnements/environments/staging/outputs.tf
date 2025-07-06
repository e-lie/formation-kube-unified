# Outputs du module VPC
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# Outputs du module webserver
output "instance_ids" {
  description = "IDs of the web server instances"
  value       = module.webserver.instance_ids
}

output "instance_public_ips" {
  description = "Public IP addresses of the web server instances"
  value       = module.webserver.instance_public_ips
}

output "individual_server_urls" {
  description = "URLs of individual servers"
  value       = module.webserver.individual_server_urls
}

# Outputs du module loadbalancer
output "load_balancer_dns" {
  description = "DNS name of the load balancer (if enabled)"
  value       = module.loadbalancer.load_balancer_dns
}

# URL de l'application (ALB ou première instance)
output "web_url" {
  description = "URL to access the web application"
  value = var.instance_count > 1 ? module.loadbalancer.load_balancer_url : "http://${module.webserver.instance_public_ips[0]}"
}