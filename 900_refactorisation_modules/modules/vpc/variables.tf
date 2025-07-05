variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
}

variable "public_subnet_cidr_2" {
  description = "CIDR block for second public subnet"
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

variable "instance_count" {
  description = "Number of instances (for security group logic)"
  type        = number
}