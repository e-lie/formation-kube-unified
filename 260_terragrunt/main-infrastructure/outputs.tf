output "vpc_id" {
  description = "ID du VPC"
  value       = module.vpc.vpc_id
}

output "web_instance_ids" {
  description = "IDs des instances web"
  value       = module.webserver.instance_ids
}

output "web_public_ips" {
  description = "IPs publiques des instances web"
  value       = module.webserver.public_ips
}

output "web_url" {
  description = "URL du load balancer"
  value       = module.loadbalancer.web_url
}