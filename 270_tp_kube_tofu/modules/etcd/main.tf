# ================================================================
# MODULE ETCD - Base de données distribuée pour Kubernetes
# ================================================================
# Ce module configure un cluster etcd haute disponibilité
# etcd est la base de données clé-valeur utilisée par Kubernetes
# pour stocker toute la configuration du cluster

# ================================================================
# VARIABLES D'ENTRÉE
# ================================================================

variable "node_count" {
  description = "Nombre de nœuds etcd à déployer"
  type        = number
}

variable "connections" {
  description = "Liste des IPs publiques pour les connexions SSH"
  type        = list(any)
}

variable "hostnames" {
  description = "Liste des noms d'hôtes des serveurs"
  type        = list(any)
}

variable "vpn_unit" {
  description = "Nom du service systemd WireGuard"
  type        = string
}

variable "vpn_ips" {
  description = "Liste des IPs VPN des serveurs"
  type        = list(any)
}

variable "etcd_version" {
  description = "Version d'etcd à installer"
  type        = string
  default     = "v3.5.6"
}

# ================================================================
# CALCULS LOCAUX
# ================================================================
# Sélectionne uniquement les nœuds nécessaires pour etcd
# (généralement 1, 3 ou 5 nœuds pour maintenir le quorum)

locals {
  etcd_hostnames = slice(var.hostnames, 0, var.node_count)  # Noms des nœuds etcd
  etcd_vpn_ips   = slice(var.vpn_ips, 0, var.node_count)   # IPs VPN des nœuds etcd
}

# ================================================================
# INSTALLATION ET CONFIGURATION D'ETCD
# ================================================================
# Configure etcd sur chaque nœud sélectionné
# etcd forme un cluster distribué pour la haute disponibilité

resource "null_resource" "etcd" {
  count = var.node_count

  # Trigger pour recréer si la configuration change
  triggers = {
    template = join("", local.etcd_service)
  }

  # Connexion SSH au serveur
  connection {
    host  = element(var.connections, count.index)
    user  = "root"
    agent = true
  }

  # ================================================================
  # ÉTAPE 1: Copie du script d'installation
  # ================================================================
  provisioner "file" {
    source      = "${path.module}/scripts/install.sh"
    destination = "/tmp/install-etcd.sh"
  }

  # ================================================================
  # ÉTAPE 2: Installation d'etcd
  # ================================================================
  # Télécharge et installe la version spécifiée d'etcd
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-etcd.sh",
      "/tmp/install-etcd.sh '${var.etcd_version}'"
    ]
  }

  # ================================================================
  # ÉTAPE 3: Configuration du service systemd
  # ================================================================
  # Crée la configuration du service etcd personnalisée pour ce nœud
  provisioner "file" {
    content     = element(local.etcd_service, count.index)
    destination = "/etc/systemd/system/etcd.service"
  }

  # ================================================================
  # ÉTAPE 4: Démarrage et vérification du service
  # ================================================================
  # Active et démarre etcd en attendant la connectivité VPN
  # etcd a besoin de la connectivité entre nœuds (via WireGuard)
  # sinon on obtient des erreurs comme "bind: cannot assign requested address"
  provisioner "remote-exec" {
    inline = [
      "systemctl is-enabled etcd.service || systemctl enable etcd.service",
      "systemctl daemon-reload",
      
      # Redémarre le service (peut échouer au premier essai)
      "systemctl restart etcd.service || true",
      
      # Attend jusqu'à 100 secondes que le service soit actif
      "for n in $(seq 1 20); do if systemctl is-active etcd.service; then exit 0; fi; sleep 5; done; echo 'etcd failed to start, latest status:'; systemctl --no-pager status etcd.service; echo; exit 1",
    ]
  }
}

# ================================================================
# GÉNÉRATION DES CONFIGURATIONS ETCD
# ================================================================
# Crée la configuration systemd spécifique pour chaque nœud etcd
# Chaque nœud connaît tous les autres membres du cluster

locals {
  etcd_service = [
    for n in range(var.node_count) :
    templatefile("${path.module}/templates/etcd.service", {
      hostname              = element(local.etcd_hostnames, n)                                                          # Nom de ce nœud
      intial_cluster        = "${join(",", formatlist("%s=http://%s:2380", local.etcd_hostnames, local.etcd_vpn_ips))}" # Liste tous les membres
      listen_client_urls    = "http://${element(local.etcd_vpn_ips, n)}:2379"                                          # Port client (API)
      advertise_client_urls = "http://${element(local.etcd_vpn_ips, n)}:2379"                                          # URL annoncée aux clients
      listen_peer_urls      = "http://${element(local.etcd_vpn_ips, n)}:2380"                                          # Port peer (réplication)
      vpn_unit              = var.vpn_unit                                                                               # Dépendance WireGuard
    })
  ]
}

# ================================================================
# OUTPUTS - Endpoints du cluster etcd
# ================================================================

output "endpoints" {
  description = "Liste des endpoints etcd pour Kubernetes"
  depends_on  = [null_resource.etcd]
  value       = formatlist("http://%s:2379", local.etcd_vpn_ips)
}
