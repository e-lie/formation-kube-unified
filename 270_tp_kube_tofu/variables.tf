/* general */
variable "node_count" {
  default = 3
}

/* etcd_node_count must be <= node_count; odd numbers provide quorum */
variable "etcd_node_count" {
  default = 3
}

variable "domain" {
  default = "example.com"
}

variable "subdomain" {
  default = "stagiaire1"
}

variable "hostname_format" {
  default = "kube-stagiaire1%d"
}

variable "overlay_cidr" {
  default = "10.96.0.0/16"
}

variable "overlay_interface" {
  default = "cilium_vxlan"
}

/* scaleway */
variable "scaleway_profile" {
  description = "Profil Scaleway CLI à utiliser"
  type        = string
  default     = "default"
}

variable "scaleway_ssh_keys" {
  description = "Liste des noms des clés SSH Scaleway"
  type        = list(string)
  default     = []
}

variable "scaleway_zone" {
  description = "Zone Scaleway"
  type        = string
  default     = "fr-par-1"
}

variable "scaleway_type" {
  description = "Type d'instance Scaleway"
  type        = string
  default     = "DEV1-M"
}

variable "scaleway_image" {
  description = "Image de base Scaleway"
  type        = string
  default     = "ubuntu_jammy"
}

/* digitalocean for DNS*/
variable "digitalocean_token" {
  default = ""
}

