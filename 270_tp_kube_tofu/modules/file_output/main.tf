# ================================================================
# MODULE FILE_OUTPUT - Génération de fichiers locaux
# ================================================================
# Ce module génère des fichiers locaux contenant les informations
# importantes du déploiement pour une utilisation ultérieure
# (scripts, debugging, documentation, etc.)

# ================================================================
# VARIABLES D'ENTRÉE
# ================================================================

variable "public_ips" {
  description = "Liste des IPs publiques des serveurs"
  type        = list(any)
}

variable "domain" {
  description = "Domaine principal (ex: example.com)"
  type        = string
}

variable "subdomain" {
  description = "Sous-domaine pour ce cluster (ex: stagiaire1)"
  type        = string
}

# ================================================================
# GÉNÉRATION DU FICHIER DES IPS PUBLIQUES
# ================================================================
# Crée un fichier texte avec toutes les IPs publiques
# Utile pour les scripts d'administration et de debug

resource "local_file" "ip_file" {
  content  = join("\n", var.public_ips)
  filename = "${path.module}/../public_ips.txt"
  
  # Permissions lecture seule pour l'utilisateur
  file_permission = "0600"
}

# ================================================================
# GÉNÉRATION DU FICHIER DU DOMAINE PRINCIPAL
# ================================================================
# Crée un fichier contenant le FQDN principal du cluster
# Utile pour les scripts qui ont besoin de connaître l'URL

resource "local_file" "domain_file" {
  content  = "${var.subdomain}.${var.domain}"
  filename = "${path.module}/../base_domain.txt"
  
  # Permissions lecture seule pour l'utilisateur
  file_permission = "0600"
}