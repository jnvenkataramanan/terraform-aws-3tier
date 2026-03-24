output "web_tier_ami_id" {
  value = aws_ami_from_instance.web_tier_ami.id
}
output "web_target_group_arn" {
  value = aws_lb_target_group.web_tier_tg.arn
}
output "web_tier_asg_name" {
  value = aws_autoscaling_group.web_tier_asg.name
}
output "web_launch_template_id" {
  value = aws_launch_template.web_tier.id
}
output "ext_lb_arn" {
  value = aws_lb.ext_lb.arn
}
output "ext_lb_dns_name" {
  value = aws_lb.ext_lb.dns_name
}
output "ext_lb_zone_id" {
  value = aws_lb.ext_lb.zone_id
}
