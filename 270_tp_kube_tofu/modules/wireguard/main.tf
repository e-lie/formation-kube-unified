# ================================================================
# MODULE WIREGUARD - Configuration VPN sécurisé
# ================================================================
# Ce module configure WireGuard pour créer un réseau VPN privé
# entre tous les nœuds du cluster Kubernetes pour sécuriser
# les communications inter-nœuds

# ================================================================
# VARIABLES D'ENTRÉE
# ================================================================

variable "node_count" {
  description = "Nombre de nœuds dans le cluster"
  type        = number
}

variable "connections" {
  description = "Liste des IPs publiques pour les connexions SSH"
  type        = list(any)
}

variable "private_ips" {
  description = "Liste des IPs privées des serveurs"
  type        = list(any)
}

variable "vpn_interface" {
  description = "Nom de l'interface WireGuard"
  type        = string
  default     = "wg0"
}

variable "vpn_port" {
  description = "Port d'écoute WireGuard"
  type        = string
  default     = "51820"
}

variable "hostnames" {
  description = "Liste des noms d'hôtes des serveurs"
  type        = list(any)
}

variable "overlay_cidr" {
  description = "CIDR du réseau overlay Kubernetes"
  type        = string
  default     = "10.96.0.0/16"
}

variable "vpn_iprange" {
  description = "Plage IP du réseau VPN WireGuard"
  type        = string
  default     = "10.0.1.0/24"
}

# ================================================================
# GÉNÉRATION DES CLÉS WIREGUARD
# ================================================================
# Génère une paire de clés (publique/privée) pour chaque nœud
# Ces clés servent à l'authentification et au chiffrement WireGuard

data "external" "keys" {
  count = var.node_count

  # Script qui génère les clés WireGuard (wg genkey | tee private | wg pubkey)
  program = ["sh", "${path.module}/scripts/gen_keys.sh"]
}

# ================================================================
# CALCUL DES IPS VPN
# ================================================================
# Génère automatiquement les IPs VPN séquentielles pour chaque nœud
# Ex: 10.0.1.1, 10.0.1.2, 10.0.1.3...

locals {
  vpn_ips = [
    for n in range(var.node_count) :
    cidrhost(var.vpn_iprange, n + 1)  # +1 pour éviter l'IP réseau (.0)
  ]
}

# ================================================================
# CONFIGURATION WIREGUARD SUR CHAQUE NŒUD
# ================================================================
# Configure WireGuard sur chaque serveur du cluster
# Installe le logiciel, génère la configuration et démarre le service

resource "null_resource" "wireguard" {
  count = var.node_count

  # Trigger pour recréer si le nombre de nœuds change
  triggers = {
    count = var.node_count
  }

  # Connexion SSH au serveur
  connection {
    host  = element(var.connections, count.index)
    user  = "root"
    agent = true
  }

  # ================================================================
  # ÉTAPE 1: Configuration du kernel pour le réseau
  # ================================================================
  provisioner "remote-exec" {
    inline = [
      # Activation du routage IP (requis pour WireGuard et Kubernetes)
      "echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf",

      # Module bridge pour Kubernetes
      "echo br_netfilter > /etc/modules-load.d/kubernetes.conf",
      "modprobe br_netfilter",
      "echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf",

      # Application des paramètres kernel
      "sysctl -p",
    ]
  }

  # ================================================================
  # ÉTAPE 2: Installation de WireGuard
  # ================================================================
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -yq wireguard",
    ]
  }

  # ================================================================
  # ÉTAPE 3: Génération du fichier de configuration WireGuard
  # ================================================================
  # Crée le fichier /etc/wireguard/wg0.conf avec :
  # - La configuration de l'interface locale
  # - La liste de tous les peers (autres nœuds)
  provisioner "file" {
    content = templatefile("${path.module}/templates/interface.conf", {
      address     = element(local.vpn_ips, count.index)           # IP VPN de ce nœud
      port        = var.vpn_port                                  # Port d'écoute
      private_key = element(data.external.keys.*.result.private_key, count.index)  # Clé privée

      # Configuration des peers (tous les autres nœuds)
      peers = templatefile("${path.module}/templates/peer.conf", {
        exclude_index = count.index                               # Exclure ce nœud
        endpoints     = var.private_ips                           # IPs des endpoints
        port          = var.vpn_port                              # Port WireGuard
        public_keys   = data.external.keys.*.result.public_key   # Clés publiques
        allowed_ips   = local.vpn_ips                            # IPs autorisées
      })
    })
    destination = "/etc/wireguard/${var.vpn_interface}.conf"
  }

  # ================================================================
  # ÉTAPE 4: Sécurisation du fichier de configuration
  # ================================================================
  provisioner "remote-exec" {
    inline = [
      "chmod 700 /etc/wireguard/${var.vpn_interface}.conf",
    ]
  }

  # ================================================================
  # ÉTAPE 5: Configuration des hôtes et démarrage WireGuard
  # ================================================================
  provisioner "remote-exec" {
    inline = [
      # Ajout des entrées dans /etc/hosts pour résolution locale
      "${join("\n", formatlist("echo '%s %s' >> /etc/hosts", local.vpn_ips, var.hostnames))}",
      
      # Activation et démarrage du service WireGuard
      "systemctl is-enabled wg-quick@${var.vpn_interface} || systemctl enable wg-quick@${var.vpn_interface}",
      "systemctl daemon-reload",
      "systemctl restart wg-quick@${var.vpn_interface}",
    ]
  }

  # ================================================================
  # ÉTAPE 6: Configuration du routage pour Kubernetes overlay
  # ================================================================
  # Crée un service systemd pour router le trafic Kubernetes via VPN
  provisioner "file" {
    content = templatefile("${path.module}/templates/overlay-route.service", {
      address      = element(local.vpn_ips, count.index)
      overlay_cidr = var.overlay_cidr
    })
    destination = "/etc/systemd/system/overlay-route.service"
  }

  provisioner "remote-exec" {
    inline = [
      "systemctl is-enabled overlay-route.service || systemctl enable overlay-route.service",
      "systemctl daemon-reload",
      "systemctl start overlay-route.service",
    ]
  }
}

# ================================================================
# OUTPUTS - Informations VPN
# ================================================================

output "vpn_ips" {
  description = "Liste des IPs VPN attribuées à chaque nœud"
  depends_on  = [null_resource.wireguard]
  value       = local.vpn_ips
}

output "vpn_unit" {
  description = "Nom du service systemd WireGuard"
  depends_on  = [null_resource.wireguard]
  value       = "wg-quick@${var.vpn_interface}.service"
}

output "vpn_interface" {
  description = "Nom de l'interface WireGuard"
  value       = var.vpn_interface
}

output "vpn_port" {
  description = "Port WireGuard utilisé"
  value       = var.vpn_port
}

output "overlay_cidr" {
  description = "CIDR du réseau overlay Kubernetes"
  value       = var.overlay_cidr
}