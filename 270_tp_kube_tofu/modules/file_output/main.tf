variable public_ips {}
variable domain {}
variable subdomain {}

resource "local_file" "ip_file" {
  content  = join("\n", var.public_ips)
  filename = "${path.module}/../public_ips.txt"
}

resource "local_file" "domain_file" {
  content  = "${var.subdomain}.${var.domain}"
  filename = "${path.module}/../base_domain.txt"
}