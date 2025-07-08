variable "node_count" {}

variable "token" {}

variable "domain" {}

variable "subdomain" {}

variable "hostnames" {
  type = list(any)
}

variable "public_ips" {
  type = list(any)
}

provider "digitalocean" {
  token = var.token
}

resource "digitalocean_record" "hosts" {
  count = var.node_count

  domain = var.domain
  name   = "${element(var.hostnames, count.index)}.${var.subdomain}"
  value  = element(var.public_ips, count.index)
  type   = "A"
  ttl    = 300
}

resource "digitalocean_record" "domain" {
  domain = var.domain
  name   = var.subdomain
  value  = element(var.public_ips, 0)
  type   = "A"
  ttl    = 300
}

resource "digitalocean_record" "wildcard" {
  depends_on = [digitalocean_record.domain]

  domain = var.domain
  name   = "*.${var.subdomain}.${var.domain}."
  value  = "${var.subdomain}.${var.domain}."
  type   = "CNAME"
  ttl    = 300
}

output "domains" {
  value = digitalocean_record.hosts.*.fqdn
}
