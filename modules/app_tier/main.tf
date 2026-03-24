###############################################################
# MODULE: APP TIER  (fully self-contained, ordered)
#
# Exact order inside this module:
#   1. aws_instance.app_tier     — EC2 boots
#   2. provisioner local-exec    — render scripts
#   3. provisioner file          — SCP scripts via bastion
#   4. provisioner remote-exec   — run app_tier_setup.sh + db_init.sh
#   5. aws_ami_from_instance     — bake AMI after provisioners done
#   6. aws_launch_template       — uses baked AMI
#   7. aws_lb_target_group       — app-tier-tg (port 4000)
#   8. aws_autoscaling_group     — app-tier-asg attaches to TG
#   9. aws_autoscaling_policy    — CPU scaling
###############################################################

# ── 1+2+3+4: App EC2 with all provisioners ──────────────────
resource "aws_instance" "app_tier" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.app_tier_sg_id]

  tags = { Name = "app-tier-instance" }

  # Step 1 — local-exec: render scripts with real DB values
  provisioner "local-exec" {
    command = <<-CMD
      sed \
        -e 's|$${db_host}|${var.db_host}|g' \
        -e 's|$${db_user}|${var.db_username}|g' \
        -e 's|$${db_password}|${var.db_password}|g' \
        -e 's|$${db_name}|${var.db_name}|g' \
        ${path.module}/../../scripts/app_tier_setup.sh \
        > /tmp/app_tier_setup_rendered.sh
      sed \
        -e 's|$${db_host}|${var.db_host}|g' \
        -e 's|$${db_user}|${var.db_username}|g' \
        -e 's|$${db_password}|${var.db_password}|g' \
        -e 's|$${db_name}|${var.db_name}|g' \
        ${path.module}/../../scripts/db_init.sh \
        > /tmp/db_init_rendered.sh
      chmod +x /tmp/app_tier_setup_rendered.sh /tmp/db_init_rendered.sh
      echo "Scripts rendered — db_host: ${var.db_host}"
    CMD
  }

  # Step 2a — file: copy app setup script via bastion jump
  provisioner "file" {
    source      = "/tmp/app_tier_setup_rendered.sh"
    destination = "/home/ubuntu/app_tier_setup.sh"
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

  # Step 2b — file: copy db init script via bastion jump
  provisioner "file" {
    source      = "/tmp/db_init_rendered.sh"
    destination = "/home/ubuntu/db_init.sh"
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

  # Step 3 — remote-exec: run both scripts on app tier
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
      "chmod +x /home/ubuntu/app_tier_setup.sh /home/ubuntu/db_init.sh",
      "sudo /home/ubuntu/app_tier_setup.sh",
      "sudo /home/ubuntu/db_init.sh",
      "sudo systemctl status nodeapp --no-pager || true"
    ]
  }
}

# ── 5: AMI — baked AFTER provisioners complete ───────────────
resource "aws_ami_from_instance" "app_tier_ami" {
  name               = "app-tier-ami"
  source_instance_id = aws_instance.app_tier.id
  tags               = { Name = "app-tier-ami" }

  # Implicit dependency: Terraform waits for aws_instance.app_tier
  # (including ALL provisioners) before creating this AMI
}

# ── 6: Launch Template — uses baked AMI ──────────────────────
resource "aws_launch_template" "app_tier" {
  name          = "app-tier-template"
  image_id      = aws_ami_from_instance.app_tier_ami.id   # baked AMI
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_tier_sg_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "app-tier-asg-instance" }
  }

  tags = { Name = "app-tier-template" }
}

# ── 7: Target Group — app-tier-tg (port 4000) ────────────────
resource "aws_lb_target_group" "app_tier_tg" {
  name     = "app-tier-tg"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "app-tier-tg" }
}

# ── 8: ASG — attaches to target group ────────────────────────
resource "aws_autoscaling_group" "app_tier_asg" {
  name                      = "app-tier-asg"
  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 4
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.app_tier_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app_tier.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "app-tier-asg-instance"
    propagate_at_launch = true
  }
}

# ── 9: CPU-based scaling policy ──────────────────────────────
resource "aws_autoscaling_policy" "app_tier_cpu" {
  name                   = "app-tier-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.app_tier_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
