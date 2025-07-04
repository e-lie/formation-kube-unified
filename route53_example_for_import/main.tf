terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-west-3"
  profile = "<awsprofile-votreprenom>"
}

# Zone DNS publique (à créer manuellement d'abord)
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "Main DNS Zone"
    Environment = "terraform-tutorial"
  }
}

# Enregistrement A pour pointer vers le load balancer
# (sera importé dans le tutorial part9)
resource "aws_route53_record" "web" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "web.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.load_balancer_ip]
}