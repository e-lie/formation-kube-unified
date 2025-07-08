# ================================================================
# MODULE SCALEWAY - Provisioning des serveurs VPS
# ================================================================
# Ce module crée les serveurs virtuels sur Scaleway Cloud
# Il configure automatiquement SSH et installe les paquets de base

# Variables d'entrée pour la configuration Scaleway
variable "access_key" {
  description = "Clé d'accès Scaleway (depuis le profil CLI)"
  type        = string
  default     = ""
}

variable "secret_key" {
  description = "Clé secrète Scaleway (depuis le profil CLI)"
  type        = string
  default     = ""
}

variable "project_id" {
  description = "ID du projet Scaleway (depuis le profil CLI)"
  type        = string
  default     = ""
}

variable "profile" {
  description = "Profil Scaleway CLI à utiliser"
  type        = string
  default     = "default"
}

variable "hosts" {
  description = "Nombre de serveurs à créer"
  type        = number
  default     = 3
}

variable "hostname_format" {
  description = "Format du nom d'hôte (ex: k8s-node-%d)"
  type        = string
}

variable "zone" {
  description = "Zone Scaleway (ex: fr-par-1)"
  type        = string
  default     = "fr-par-1"
}

variable "type" {
  description = "Type d'instance Scaleway (ex: DEV1-S)"
  type        = string
  default     = "DEV1-S"
}

variable "image" {
  description = "Image de base (ex: ubuntu_jammy)"
  type        = string
  default     = "ubuntu_jammy"
}

variable "ssh_keys" {
  description = "Liste des clés SSH à installer"
  type        = list(string)
}

variable "apt_packages" {
  description = "Paquets supplémentaires à installer"
  type        = list(string)
  default     = []
}

# Configuration du provider Scaleway
# Utilise le profil CLI pour l'authentification
provider "scaleway" {
  access_key  = var.access_key
  secret_key  = var.secret_key
  project_id  = var.project_id
  zone        = var.zone
  profile     = var.profile
}

# Création des serveurs Scaleway
# Chaque serveur est provisionné avec SSH et les paquets de base
resource "scaleway_instance_server" "host" {
  count = var.hosts
  
  # Configuration de base du serveur
  name  = format(var.hostname_format, count.index + 1)
  type  = var.type
  image = var.image
  
  # Configuration SSH - les clés sont ajoutées automatiquement
  # Scaleway injecte les clés SSH dans l'image au démarrage
  
  # Tags pour identifier les serveurs
  tags = [
    "kubernetes",
    "k8s-node-${count.index + 1}",
    "managed-by-terraform"
  ]

  # Connexion SSH pour le provisioning
  connection {
    type    = "ssh"
    user    = "root"
    host    = self.public_ip
    timeout = "5m"
    # La clé privée correspondante doit être dans ~/.ssh/
  }

  # Installation des paquets de base requis pour Kubernetes
  provisioner "remote-exec" {
    inline = [
      # Attendre que le système soit prêt
      "while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do sleep 1; done",
      
      # Mise à jour du système
      "apt-get update",
      
      # Installation des paquets de base
      "apt-get install -yq ufw curl wget gnupg2 software-properties-common ${join(" ", var.apt_packages)}",
      
      # Configuration basique du firewall (sera configuré plus tard par le module UFW)
      "ufw --force reset",
      
      # Optimisations pour Kubernetes
      "echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf",
      "echo 'net.bridge.bridge-nf-call-iptables=1' >> /etc/sysctl.conf",
      
      "echo 'Serveur ${count.index + 1} configuré avec succès'"
    ]
  }
}

# ================================================================
# OUTPUTS - Informations sur les serveurs créés
# ================================================================

output "hostnames" {
  description = "Noms des serveurs créés"
  value       = scaleway_instance_server.host[*].name
}

output "public_ips" {
  description = "Adresses IP publiques des serveurs"
  value       = scaleway_instance_server.host[*].public_ip
}

output "private_ips" {
  description = "Adresses IP privées des serveurs (même que publiques chez Scaleway)"
  value       = scaleway_instance_server.host[*].private_ip
}

output "private_network_interface" {
  description = "Interface réseau privé par défaut"
  value       = "ens2"  # Interface par défaut sur Scaleway
}

output "server_ids" {
  description = "IDs des serveurs créés"
  value       = scaleway_instance_server.host[*].id
}