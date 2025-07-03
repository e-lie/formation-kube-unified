# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "${terraform.workspace}-vpc"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${terraform.workspace}-igw"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}

# Subnet public
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name      = "${terraform.workspace}-public-subnet"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}

# Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name      = "${terraform.workspace}-public-route-table"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}

# Association subnet avec route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group avec nom unique par workspace
resource "aws_security_group" "web_ssh_access" {
  name        = "${terraform.workspace}-web-ssh-access"
  description = "Allow SSH and HTTP access for ${terraform.workspace}"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${terraform.workspace}-web-ssh-access"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}

# Outputs réseau
output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.public.id
}