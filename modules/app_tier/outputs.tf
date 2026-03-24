output "app_tier_ami_id" {
  value = aws_ami_from_instance.app_tier_ami.id
}
output "app_target_group_arn" {
  value = aws_lb_target_group.app_tier_tg.arn
}
output "app_tier_asg_name" {
  value = aws_autoscaling_group.app_tier_asg.name
}
output "app_launch_template_id" {
  value = aws_launch_template.app_tier.id
}
