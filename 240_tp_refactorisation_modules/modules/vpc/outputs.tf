output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [aws_subnet.public.id, aws_subnet.public_2.id]
}

output "web_servers_security_group_id" {
  description = "ID of the web servers security group"
  value       = aws_security_group.web_servers.id
}

output "alb_security_group_ids" {
  description = "IDs of the ALB security groups"
  value       = aws_security_group.alb[*].id
}