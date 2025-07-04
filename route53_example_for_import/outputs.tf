output "zone_id" {
  description = "ID of the Route53 zone"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Name servers for the zone"
  value       = aws_route53_zone.main.name_servers
}

output "web_domain" {
  description = "Web domain name"
  value       = aws_route53_record.web.fqdn
}