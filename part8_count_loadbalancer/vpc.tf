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

# Security Group pour les serveurs web
resource "aws_security_group" "web_servers" {
  name        = "${terraform.workspace}-web-servers"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  # SSH depuis l'extérieur (pour administration)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP depuis l'ALB seulement (si ALB activé)
  dynamic "ingress" {
    for_each = var.instance_count > 1 ? [1] : []
    content {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      security_groups = [aws_security_group.alb[0].id]
    }
  }

  # HTTP direct si pas d'ALB
  dynamic "ingress" {
    for_each = var.instance_count == 1 ? [1] : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${terraform.workspace}-web-servers-sg"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}

# Security Group pour l'ALB (conditionnel)
resource "aws_security_group" "alb" {
  count       = var.instance_count > 1 ? 1 : 0
  name        = "${terraform.workspace}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name      = "${terraform.workspace}-alb-sg"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}

