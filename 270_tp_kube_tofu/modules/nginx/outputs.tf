# Outputs du module nginx

output "deployment_name" {
  description = "Name of the nginx deployment"
  value       = kubernetes_deployment.nginx.metadata[0].name
}

output "service_name" {
  description = "Name of the nginx service"
  value       = kubernetes_service.nginx.metadata[0].name
}

output "service_type" {
  description = "Type of the nginx service"
  value       = kubernetes_service.nginx.spec[0].type
}

output "deployment_ready" {
  description = "Whether the deployment is ready"
  value       = kubernetes_deployment.nginx.status[0].ready_replicas == var.replicas
}

output "advanced_deployment_name" {
  description = "Name of the advanced nginx deployment"
  value       = kubernetes_deployment.nginx_advanced.metadata[0].name
}

output "advanced_service_name" {
  description = "Name of the advanced nginx service"
  value       = kubernetes_service.nginx_advanced.metadata[0].name
}

output "namespace" {
  description = "Namespace where nginx is deployed"
  value       = var.namespace
}