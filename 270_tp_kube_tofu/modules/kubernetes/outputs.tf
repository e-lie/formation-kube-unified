# Outputs pour la connexion au cluster Kubernetes

# Endpoint du cluster
output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = "https://${element(var.connections, 0)}:6443"
  sensitive   = false
}

# Note: Les certificats ne sont pas directement accessibles via Terraform
# car ils sont générés sur les nœuds. Une approche alternative serait
# d'utiliser des data sources ou des provisioners pour les récupérer.

# Pour l'instant, nous utiliserons des placeholders ou une approche
# de récupération via SSH

# IP du master node pour référence
output "master_ip" {
  description = "IP du nœud master Kubernetes"
  value       = element(var.connections, 0)
}

# VPN IP du master pour communication interne
output "master_vpn_ip" {
  description = "IP VPN du nœud master"
  value       = element(var.vpn_ips, 0)
}

# Token du cluster (pour référence)
output "cluster_token" {
  description = "Token du cluster Kubernetes"
  value       = local.cluster_token
  sensitive   = true
}