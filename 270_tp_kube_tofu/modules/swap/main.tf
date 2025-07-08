# ================================================================
# MODULE SWAP - Configuration du fichier d'échange
# ================================================================
# Ce module configure un fichier de swap sur chaque nœud
# et prépare la configuration Kubernetes pour gérer le swap
# (Kubernetes peut maintenant fonctionner avec swap activé)

# ================================================================
# VARIABLES D'ENTRÉE
# ================================================================

variable "node_count" {
  description = "Nombre de nœuds à configurer"
  type        = number
}

variable "connections" {
  description = "Liste des IPs publiques pour les connexions SSH"
  type        = list(any)
}

# ================================================================
# CONFIGURATION DU SWAP SUR CHAQUE NŒUD
# ================================================================
# Configure un fichier de swap de 2GB pour améliorer les performances
# et permet à Kubernetes de gérer le swap de manière contrôlée

resource "null_resource" "swap" {
  count = var.node_count

  # Connexion SSH au serveur
  connection {
    host  = element(var.connections, count.index)
    user  = "root"
    agent = true
  }

  # ================================================================
  # ÉTAPE 1: Création et activation du fichier de swap
  # ================================================================
  provisioner "remote-exec" {
    inline = [
      "fallocate -l 2G /swapfile",                              # Créer un fichier de 2GB
      "chmod 600 /swapfile",                                    # Sécuriser les permissions
      "mkswap /swapfile",                                       # Formater comme swap
      "swapon /swapfile",                                       # Activer le swap
      "echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab", # Rendre permanent au boot
    ]
  }

  # ================================================================
  # ÉTAPE 2: Préparation du répertoire pour kubelet
  # ================================================================
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/systemd/system/kubelet.service.d",
    ]
  }

  # ================================================================
  # ÉTAPE 3: Configuration kubelet pour le swap
  # ================================================================
  # Configure kubelet pour permettre le swap (nouvelles versions de Kubernetes)
  provisioner "file" {
    content     = file("${path.module}/templates/90-kubelet-extras.conf")
    destination = "/etc/systemd/system/kubelet.service.d/90-kubelet-extras.conf"
  }

  # ================================================================
  # ÉTAPE 4: Rechargement de la configuration systemd
  # ================================================================
  provisioner "remote-exec" {
    inline = [
      "systemctl daemon-reload",  # Recharger pour prendre en compte la nouvelle config kubelet
    ]
  }
}
