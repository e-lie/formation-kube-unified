# Application Load Balancer (conditionnel)
resource "aws_lb" "main" {
  count              = var.instance_count > 1 ? 1 : 0
  name               = "${terraform.workspace}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets           = [aws_subnet.public.id, aws_subnet.public_2.id]

  enable_deletion_protection = false

  tags = {
    Name        = "${terraform.workspace}-alb"
    Workspace   = terraform.workspace
    Feature     = var.feature_name
    Environment = "load-balancer"
  }
}

# Target Group pour les serveurs web
resource "aws_lb_target_group" "web_servers" {
  count    = var.instance_count > 1 ? 1 : 0
  name     = "${terraform.workspace}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name      = "${terraform.workspace}-web-tg"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}

# Attachement des instances au Target Group
resource "aws_lb_target_group_attachment" "web_servers" {
  count            = var.instance_count > 1 ? var.instance_count : 0
  target_group_arn = aws_lb_target_group.web_servers[0].arn
  target_id        = aws_instance.web_server[count.index].id
  port             = 80
}

# Listener pour l'ALB
resource "aws_lb_listener" "web" {
  count             = var.instance_count > 1 ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_servers[0].arn
  }

  tags = {
    Name      = "${terraform.workspace}-web-listener"
    Workspace = terraform.workspace
    Feature   = var.feature_name
  }
}