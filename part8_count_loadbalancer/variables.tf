variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "<awsprofile-votreprenom>"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_terraform"
}

variable "feature_name" {
  description = "Name of the feature being tested"
  type        = string
  default     = "main"
}

variable "instance_count" {
  description = "Number of web server instances"
  type        = number
  default     = 3
}