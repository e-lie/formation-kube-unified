# Data source pour les zones de disponibilité
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "${var.workspace}-vpc"
    Workspace = var.workspace
    Feature   = var.feature_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.workspace}-igw"
    Workspace = var.workspace
    Feature   = var.feature_name
  }
}

# Subnet public 1
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name      = "${var.workspace}-public-subnet-1"
    Workspace = var.workspace
    Feature   = var.feature_name
  }
}

# Subnet public 2 (pour ALB multi-AZ)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_2
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name      = "${var.workspace}-public-subnet-2"
    Workspace = var.workspace
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
    Name      = "${var.workspace}-public-route-table"
    Workspace = var.workspace
    Feature   = var.feature_name
  }
}

# Association subnet 1 avec route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Association subnet 2 avec route table
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group pour les serveurs web
resource "aws_security_group" "web_servers" {
  name        = "${var.workspace}-web-servers"
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
    Name      = "${var.workspace}-web-servers-sg"
    Workspace = var.workspace
    Feature   = var.feature_name
  }
}

# Security Group pour l'ALB (conditionnel)
resource "aws_security_group" "alb" {
  count       = var.instance_count > 1 ? 1 : 0
  name        = "${var.workspace}-alb-sg"
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
    Name      = "${var.workspace}-alb-sg"
    Workspace = var.workspace
    Feature   = var.feature_name
  }
}