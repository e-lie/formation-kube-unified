output "load_balancer_dns" {
  description = "DNS name of the load balancer (if enabled)"
  value       = var.instance_count > 1 ? aws_lb.main[0].dns_name : null
}

output "load_balancer_url" {
  description = "URL of the load balancer (if enabled)"
  value       = var.instance_count > 1 ? "http://${aws_lb.main[0].dns_name}" : null
}