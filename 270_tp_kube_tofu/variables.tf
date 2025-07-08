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

/* hcloud */
variable "hcloud_token" {
  default = ""
}

variable "hcloud_ssh_keys" {
  type    = list(string)
  default = [""]
}

variable "hcloud_location" {
  default = "nbg1"
}

variable "hcloud_type" {
  default = "cx11"
}

variable "hcloud_image" {
  default = "ubuntu-24.04"
}

/* digitalocean for DNS*/
variable "digitalocean_token" {
  default = ""
}

