module "provider" {
  source = "./modules/hcloud"
  token           = var.hcloud_token
  ssh_keys        = var.hcloud_ssh_keys
  location        = var.hcloud_location
  type            = var.hcloud_type
  image           = var.hcloud_image
  hosts           = var.node_count
  hostname_format = var.hostname_format
  apt_packages = ["ceph-common", "nfs-common", "open-iscsi"]
}

module "swap" {
  source = "./modules/swap"

  node_count  = var.node_count
  connections = module.provider.public_ips
}

module "dns" {
  source     = "./modules/digitalocean"

  node_count = var.node_count
  token      = var.digitalocean_token
  domain     = var.domain
  subdomain  = var.subdomain
  public_ips = module.provider.public_ips
  hostnames  = module.provider.hostnames
}

module "wireguard" {
  source = "./modules/wireguard"

  node_count   = var.node_count
  connections  = module.provider.public_ips
  private_ips  = module.provider.private_ips
  hostnames    = module.provider.hostnames
  overlay_cidr = var.overlay_cidr
}

module "firewall" {
  source = "./modules/ufw"

  node_count           = var.node_count
  connections          = module.provider.public_ips
  private_interface    = module.provider.private_network_interface
  vpn_interface        = module.wireguard.vpn_interface
  vpn_port             = module.wireguard.vpn_port
  kubernetes_interface = var.overlay_interface
}

module "etcd" {
  source = "./modules/etcd"

  node_count  = var.etcd_node_count
  connections = module.provider.public_ips
  hostnames   = module.provider.hostnames
  vpn_unit    = module.wireguard.vpn_unit
  vpn_ips     = module.wireguard.vpn_ips
}

module "kubernetes" {
  source = "./modules/kubernetes"

  node_count     = var.node_count
  connections    = module.provider.public_ips
  cluster_name   = var.domain
  vpn_interface  = module.wireguard.vpn_interface
  vpn_ips        = module.wireguard.vpn_ips
  etcd_endpoints = module.etcd.endpoints
  overlay_cidr = var.overlay_cidr
  overlay_interface = var.overlay_interface
}

module "file_output" {
  source = "./modules/file_output"
  public_ips = module.provider.public_ips
  domain = var.domain
  subdomain = var.subdomain
}

# Module nginx avec provider Kubernetes
module "nginx_app" {
  source = "./modules/nginx"
  
  # Dépend de l'installation de Kubernetes
  depends_on = [module.kubernetes]
  
  # Configuration cluster
  master_ip    = module.kubernetes.master_ip
  cluster_name = var.domain
  namespace    = "demo"
  replicas     = 3
  
  # Ressources personnalisées
  cpu_limit      = "500m"
  memory_limit   = "512Mi"
  cpu_request    = "250m"
  memory_request = "256Mi"
}
