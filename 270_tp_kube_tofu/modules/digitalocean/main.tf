# ================================================================
# MODULE DIGITALOCEAN - Configuration DNS
# ================================================================
# Ce module configure les enregistrements DNS pour le cluster Kubernetes
# Il crée des enregistrements A pour chaque nœud et un wildcard pour les applications

# ================================================================
# VARIABLES D'ENTRÉE
# ================================================================

variable "node_count" {
  description = "Nombre de nœuds dans le cluster"
  type        = number
}

variable "token" {
  description = "Token API DigitalOcean"
  type        = string
}

variable "domain" {
  description = "Domaine principal (ex: example.com)"
  type        = string
}

variable "subdomain" {
  description = "Sous-domaine pour ce cluster (ex: stagiaire1)"
  type        = string
}

variable "hostnames" {
  description = "Liste des noms d'hôtes des serveurs"
  type        = list(any)
}

variable "public_ips" {
  description = "Liste des IPs publiques des serveurs"
  type        = list(any)
}

# ================================================================
# CONFIGURATION DU PROVIDER DIGITALOCEAN
# ================================================================

provider "digitalocean" {
  token = var.token
}

# ================================================================
# ENREGISTREMENTS DNS POUR CHAQUE NŒUD
# ================================================================
# Crée un enregistrement A pour chaque serveur du cluster
# Format: kube-stagiaire1X.stagiaire1.example.com -> IP_PUBLIQUE

resource "digitalocean_record" "hosts" {
  count = var.node_count

  # Configuration de l'enregistrement DNS
  domain = var.domain
  name   = "${element(var.hostnames, count.index)}.${var.subdomain}"  # ex: kube-stagiaire11.stagiaire1
  value  = element(var.public_ips, count.index)                       # IP publique du serveur
  type   = "A"
  ttl    = 300  # TTL court pour faciliter les tests et changements
}

# ================================================================
# ENREGISTREMENT DNS PRINCIPAL DU CLUSTER
# ================================================================
# Crée l'enregistrement principal qui pointe vers le premier nœud (master)
# Format: stagiaire1.example.com -> IP_DU_MASTER

resource "digitalocean_record" "domain" {
  domain = var.domain
  name   = var.subdomain                    # ex: stagiaire1
  value  = element(var.public_ips, 0)      # IP du premier serveur (master)
  type   = "A"
  ttl    = 300
}

# ================================================================
# ENREGISTREMENT WILDCARD POUR LES APPLICATIONS
# ================================================================
# Crée un wildcard qui redirige toutes les sous-domaines vers le cluster
# Format: *.stagiaire1.example.com -> stagiaire1.example.com
# Permet d'accéder aux applications déployées (ex: app.stagiaire1.example.com)

resource "digitalocean_record" "wildcard" {
  depends_on = [digitalocean_record.domain]

  domain = var.domain
  name   = "*.${var.subdomain}.${var.domain}."     # Wildcard pour toutes les apps
  value  = "${var.subdomain}.${var.domain}."      # Redirige vers le domaine principal
  type   = "CNAME"
  ttl    = 300
}

# ================================================================
# OUTPUTS - Informations DNS créées
# ================================================================

output "domains" {
  description = "Liste des FQDNs créés pour chaque nœud"
  value       = digitalocean_record.hosts.*.fqdn
}

output "main_domain" {
  description = "FQDN principal du cluster"
  value       = digitalocean_record.domain.fqdn
}

output "wildcard_domain" {
  description = "Domaine wildcard pour les applications"
  value       = digitalocean_record.wildcard.fqdn
}