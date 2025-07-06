variable "instance_count" {
  description = "Number of web server instances"
  type        = number
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to place instances"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group for web servers"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
}

variable "workspace" {
  description = "Terraform workspace name"
  type        = string
}

variable "feature_name" {
  description = "Name of the feature being deployed"
  type        = string
}