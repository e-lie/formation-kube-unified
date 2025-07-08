# ================================================================
# MODULE KUBERNETES - Installation et configuration du cluster
# ================================================================
# Ce module configure un cluster Kubernetes haute disponibilité
# avec etcd externe, CNI Cilium et configuration personnalisée

# ================================================================
# VARIABLES D'ENTRÉE
# ================================================================

variable "apiserver_extra_args" {
  description = "Arguments supplémentaires pour kube-apiserver"
  type        = map(any)
  default     = {}
}

variable "apiserver_extra_volumes" {
  description = "Volumes supplémentaires pour kube-apiserver"
  # Pas de type spécifié pour éviter la conversion bool->string par yamlencode
  # Liste de définitions de volumes selon l'API kubeadm
  # Voir: https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/#kubeadm-k8s-io-v1beta3-ControlPlaneComponent
  default = []
}

variable "kubelet_extra_config" {
  description = "Configuration supplémentaire pour kubelet (YAML brut)"
  type        = string
  # YAML brut pour éviter les problèmes de conversion avec map(any)
  # S'applique uniquement lors de la création du cluster
  default = ""
}

variable "node_count" {
  description = "Nombre de nœuds dans le cluster"
  type        = number
}

variable "connections" {
  description = "Liste des IPs publiques pour les connexions SSH"
  type        = list(any)
}

variable "vpn_ips" {
  description = "Liste des IPs VPN pour la communication interne"
  type        = list(any)
}

variable "vpn_interface" {
  description = "Interface VPN WireGuard"
  type        = string
}

variable "etcd_endpoints" {
  description = "Liste des endpoints etcd"
  type        = list(any)
}

variable "overlay_interface" {
  description = "Interface réseau overlay Kubernetes"
  type        = string
  default     = "cilium_vxlan"
}

variable "overlay_cidr" {
  description = "CIDR du réseau overlay Kubernetes"
  type        = string
  default     = "10.96.0.0/16"
}

variable "cilium_version" {
  description = "Version de Cilium CNI à installer"
  type        = string
  default     = "1.16.0"
}

variable "cluster_name" {
  description = "Nom du cluster Kubernetes"
  type        = string
}

# ================================================================
# GÉNÉRATION DU TOKEN DE CLUSTER
# ================================================================
# Génère un token sécurisé pour l'authentification des nœuds workers
# Format: XXXXXX.XXXXXXXXXXXXXXXX (6 + 16 caractères alphanumériques)

resource "random_string" "token1" {
  length  = 6
  upper   = false
  special = false
}

resource "random_string" "token2" {
  length  = 16
  upper   = false
  special = false
}

locals {
  cluster_token = "${random_string.token1.result}.${random_string.token2.result}"
}

# ================================================================
# INSTALLATION ET CONFIGURATION DE KUBERNETES
# ================================================================
# Configure Kubernetes sur chaque nœud du cluster
# Le premier nœud devient le master, les autres sont des workers

resource "null_resource" "kubernetes" {
  count = var.node_count

  # Connexion SSH au serveur
  connection {
    host  = element(var.connections, count.index)
    user  = "root"
    agent = true
  }

  # ================================================================
  # ÉTAPE 1: Installation des dépendances système
  # ================================================================
  provisioner "remote-exec" {
    inline = [
      "apt-get install -qy jq",                                   # Utilitaire JSON pour les scripts
      "modprobe br_netfilter && echo br_netfilter >> /etc/modules", # Module bridge nécessaire
    ]
  }

  # ================================================================
  # ÉTAPE 2: Configuration de Docker
  # ================================================================
  # Prépare la configuration Docker pour Kubernetes
  provisioner "remote-exec" {
    inline = ["[ -d /etc/docker ] || mkdir -p /etc/docker"]
  }

  provisioner "file" {
    content     = file("${path.module}/templates/daemon.json")
    destination = "/etc/docker/daemon.json"
  }

  # ================================================================
  # ÉTAPE 3: Génération de la configuration master
  # ================================================================
  # Crée le fichier de configuration kubeadm pour le master
  provisioner "file" {
    content = templatefile("${path.module}/templates/master-configuration.yml", {
      api_advertise_address   = element(var.vpn_ips, 0)                         # IP VPN du master
      apiserver_extra_args    = yamlencode(var.apiserver_extra_args)             # Args personnalisés
      apiserver_extra_volumes = yamlencode(var.apiserver_extra_volumes)          # Volumes personnalisés
      etcd_endpoints          = "- ${join("\n    - ", var.etcd_endpoints)}"      # Endpoints etcd
      cert_sans               = "- ${element(var.connections, 0)}"               # SAN du certificat
      kubelet_extra_config    = var.kubelet_extra_config                        # Config kubelet
    })
    destination = "/tmp/master-configuration.yml"
  }

  # ================================================================
  # ÉTAPE 4: Installation de Kubernetes
  # ================================================================
  # Installe kubeadm, kubelet et kubectl
  provisioner "remote-exec" {
    inline = [
      file("${path.module}/scripts/install.sh")
    ]
  }

  # ================================================================
  # ÉTAPE 5: Configuration spécifique master/worker
  # ================================================================
  # Le premier nœud (index 0) devient master avec Cilium CNI
  # Les autres nœuds rejoignent le cluster comme workers
  provisioner "remote-exec" {
    inline = [
      count.index == 0
      ? templatefile("${path.module}/scripts/master.sh", {
          token          = local.cluster_token    # Token pour l'auth des workers
          cilium_version = var.cilium_version     # Version CNI Cilium
          overlay_cidr   = var.overlay_cidr       # CIDR du réseau pods
        })
      : templatefile("${path.module}/scripts/slave.sh", {
          master_ip = element(var.vpn_ips, 0)     # IP VPN du master
          token     = local.cluster_token         # Token d'authentification
        })
    ]
  }
}

# ================================================================
# OUTPUTS - Informations du cluster Kubernetes
# ================================================================

output "overlay_interface" {
  description = "Interface réseau overlay utilisée"
  value       = var.overlay_interface
}

output "overlay_cidr" {
  description = "CIDR du réseau overlay Kubernetes"
  value       = var.overlay_cidr
}

output "cluster_endpoint" {
  description = "Endpoint du cluster Kubernetes"
  depends_on  = [null_resource.kubernetes]
  value       = "https://${element(var.connections, 0)}:6443"
}

output "master_ip" {
  description = "IP publique du nœud master"
  depends_on  = [null_resource.kubernetes]
  value       = element(var.connections, 0)
}

output "master_vpn_ip" {
  description = "IP VPN du nœud master"
  depends_on  = [null_resource.kubernetes]
  value       = element(var.vpn_ips, 0)
}

output "cluster_token" {
  description = "Token du cluster Kubernetes"
  depends_on  = [null_resource.kubernetes]
  value       = local.cluster_token
  sensitive   = true
}
