# ================================================================
# MODULE UFW - Configuration du pare-feu
# ================================================================
# Ce module configure UFW (Uncomplicated Firewall) sur chaque nœud
# pour sécuriser le cluster Kubernetes tout en permettant
# les communications nécessaires

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

variable "private_interface" {
  description = "Interface réseau privé (ex: eth0, ens2)"
  type        = string
}

variable "vpn_interface" {
  description = "Interface VPN WireGuard (ex: wg0)"
  type        = string
}

variable "vpn_port" {
  description = "Port WireGuard à autoriser"
  type        = string
}

variable "kubernetes_interface" {
  description = "Interface Kubernetes/CNI (ex: cilium_vxlan)"
  type        = string
}

variable "additional_rules" {
  description = "Règles UFW supplémentaires à appliquer"
  type        = list(string)
  default     = []
}

# ================================================================
# GÉNÉRATION DE LA CONFIGURATION UFW
# ================================================================
# Crée le script de configuration UFW à partir d'un template
# Le script configure toutes les règles nécessaires pour Kubernetes

locals {
  ufw_config = templatefile("${path.module}/scripts/ufw.sh", {
    private_interface    = var.private_interface      # Interface réseau principal
    kubernetes_interface = var.kubernetes_interface   # Interface Kubernetes (Cilium)
    vpn_interface        = var.vpn_interface          # Interface WireGuard
    vpn_port             = var.vpn_port               # Port WireGuard (51820)
    
    # Règles supplémentaires formatées pour UFW
    additional_rules = join("\nufw ", flatten(["", var.additional_rules]))
  })
}

# ================================================================
# CONFIGURATION DU PARE-FEU SUR CHAQUE NŒUD
# ================================================================
# Applique la configuration UFW sur chaque serveur du cluster
# Règles principales configurées :
# - SSH (port 22) autorisé depuis partout
# - WireGuard (port 51820) autorisé depuis partout  
# - Trafic Kubernetes autorisé sur les interfaces internes
# - API Kubernetes (port 6443) autorisé entre nœuds
# - etcd (ports 2379-2380) autorisé entre nœuds
# - Kubelet (port 10250) autorisé entre nœuds
# - Services NodePort (30000-32767) autorisés

resource "null_resource" "firewall" {
  count = var.node_count

  # Trigger pour reconfigurer si le template change
  triggers = {
    template = local.ufw_config
  }

  # Connexion SSH au serveur
  connection {
    host  = element(var.connections, count.index)
    user  = "root"
    agent = true
  }

  # ================================================================
  # APPLICATION DE LA CONFIGURATION UFW
  # ================================================================
  # Exécute le script UFW généré qui :
  # 1. Reset UFW pour partir d'une configuration propre
  # 2. Configure les règles par défaut (deny all, allow outgoing)
  # 3. Autorise SSH pour l'administration
  # 4. Autorise WireGuard pour le VPN inter-nœuds
  # 5. Autorise le trafic Kubernetes sur les interfaces internes
  # 6. Autorise les ports spécifiques Kubernetes
  # 7. Active UFW avec la nouvelle configuration

  provisioner "remote-exec" {
    inline = [local.ufw_config]
  }
}

# ================================================================
# OUTPUTS - Informations du pare-feu
# ================================================================

output "firewall_configured" {
  description = "Indique si le pare-feu a été configuré"
  depends_on  = [null_resource.firewall]
  value       = true
}

output "ufw_config_applied" {
  description = "Configuration UFW appliquée"
  value       = local.ufw_config
}