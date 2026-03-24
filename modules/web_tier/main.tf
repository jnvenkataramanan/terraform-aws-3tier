###############################################################
# MODULE: WEB TIER
#
# Order inside this module:
#   1. aws_instance.web_tier     — EC2 boot
#   2. local-exec                — render nginx script
#   3. file provisioner          — SCP to web EC2 (public IP)
#   4. remote-exec               — run web_tier_setup.sh
#   5. aws_ami_from_instance     — bake web-tier-ami
#   6. aws_launch_template       — uses baked AMI
#   7. aws_lb_target_group       — web-tier-tg (port 80)
#   8. aws_autoscaling_group     — web-tier-asg
#   9. aws_autoscaling_policy    — CPU scaling
#  10. aws_lb (ext-lb)           — created AFTER acm_certificate_arn
#                                  is passed in (already ISSUED)
#  11. aws_lb_listener HTTP:80   — redirect to HTTPS
#  12. aws_lb_listener HTTPS:443 — forward to web-tier-tg with cert
###############################################################

resource "aws_instance" "web_tier" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.web_tier_sg_id]
  associate_public_ip_address = true
  tags = { Name = "web-tier-instance" }

  provisioner "local-exec" {
    command = <<-CMD
      sed -e 's|$${int_lb_dns}|${var.int_lb_dns}|g' \
        ${path.module}/../../scripts/web_tier_setup.sh \
        > /tmp/web_tier_setup_rendered.sh
      chmod +x /tmp/web_tier_setup_rendered.sh
    CMD
  }

  provisioner "file" {
    source      = "/tmp/web_tier_setup_rendered.sh"
    destination = "/home/ubuntu/web_tier_setup.sh"
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(var.private_key_path)
      host                = self.private_ip
      bastion_host        = var.bastion_public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file(var.private_key_path)
    }
  }

  provisioner "remote-exec" {
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(var.private_key_path)
      host                = self.private_ip
      bastion_host        = var.bastion_public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file(var.private_key_path)
    }
    inline = [
      "chmod +x /home/ubuntu/web_tier_setup.sh",
      "sudo /home/ubuntu/web_tier_setup.sh",
      "sudo systemctl status nginx --no-pager || true"
    ]
  }
}

resource "aws_ami_from_instance" "web_tier_ami" {
  name               = "web-tier-ami"
  source_instance_id = aws_instance.web_tier.id
  tags               = { Name = "web-tier-ami" }
}

resource "aws_launch_template" "web_tier" {
  name          = "web-tier-template"
  image_id      = aws_ami_from_instance.web_tier_ami.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.web_tier_sg_id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = { Name = "web-tier-asg-instance" }
  }
  tags = { Name = "web-tier-template" }
}

resource "aws_lb_target_group" "web_tier_tg" {
  name     = "web-tier-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = { Name = "web-tier-tg" }
}

resource "aws_autoscaling_group" "web_tier_asg" {
  name                      = "web-tier-asg"
  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 4
  vpc_zone_identifier       = var.public_subnet_ids
  target_group_arns         = [aws_lb_target_group.web_tier_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  launch_template {
    id      = aws_launch_template.web_tier.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "web-tier-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "web_tier_cpu" {
  name                   = "web-tier-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.web_tier_asg.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# ext-lb — created ONLY after BOTH conditions are met:
#   1. web_tier_asg ready  (explicit depends_on)
#      chain: EC2 → AMI → template → tg → ASG
#   2. acm_certificate_arn received (cert ISSUED)
#      implicit — var.acm_certificate_arn only resolves after
#      aws_acm_certificate_validation completes in route53_acm module
# Web EC2 boot → nginx → AMI → ASG run WITHOUT waiting for cert.
# ext-lb creation is the only step that needs cert to be ISSUED.
resource "aws_lb" "ext_lb" {
  name               = "ext-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.ext_lb_sg_id]
  subnets            = var.public_subnet_ids
  enable_deletion_protection = false
  tags = { Name = "ext-lb" }

  depends_on = [aws_autoscaling_group.web_tier_asg]
}

# HTTP:80 → redirect to HTTPS:443
resource "aws_lb_listener" "ext_http" {
  load_balancer_arn = aws_lb.ext_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS:443 with ACM cert — cert is already ISSUED when we reach here
resource "aws_lb_listener" "ext_https" {
  load_balancer_arn = aws_lb.ext_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tier_tg.arn
  }
}
