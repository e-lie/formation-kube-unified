variable "instance_count" {
  description = "Number of instances (determines if ALB is created)"
  type        = number
}

variable "workspace" {
  description = "Terraform workspace name"
  type        = string
}

variable "feature_name" {
  description = "Name of the feature being deployed"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the load balancer"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the load balancer"
  type        = list(string)
}

variable "instance_ids" {
  description = "List of instance IDs to attach to the target group"
  type        = list(string)
}