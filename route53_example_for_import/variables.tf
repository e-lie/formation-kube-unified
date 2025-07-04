variable "domain_name" {
  description = "Domain name for the DNS zone"
  type        = string
  default     = "example-terraform-demo.com"
}

variable "load_balancer_ip" {
  description = "IP address of the load balancer"
  type        = string
  default     = "1.2.3.4"  # Placeholder - will be replaced with real ALB IP
}