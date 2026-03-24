###############################################################
# MODULE: INTERNAL ALB
# Only int-lb here. ext-lb lives inside web_tier module
# because it needs web-tier-tg which is created there.
###############################################################

resource "aws_lb" "int_lb" {
  name               = "int-lb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.int_lb_sg_id]
  subnets            = var.private_subnet_ids

  enable_deletion_protection = false
  tags = { Name = "int-lb" }
}

# Listener wired after app_tier module creates app-tier-tg
resource "aws_lb_listener" "int_http" {
  load_balancer_arn = aws_lb.int_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = var.app_target_group_arn
  }
}
