output "instance_ids" {
  description = "IDs of the web server instances"
  value       = aws_instance.web_server[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses of the web server instances"
  value       = aws_instance.web_server[*].public_ip
}

output "individual_server_urls" {
  description = "URLs of individual servers"
  value = [
    for instance in aws_instance.web_server : 
    "http://${instance.public_ip}"
  ]
}