output "bh_sg_id" {
  value = aws_security_group.bh_sg.id
}
output "ext_lb_sg_id" {
  value = aws_security_group.ext_lb_sg.id
}
output "web_tier_sg_id" {
  value = aws_security_group.web_tier_sg.id
}
output "int_lb_sg_id" {
  value = aws_security_group.int_lb_sg.id
}
output "app_tier_sg_id" {
  value = aws_security_group.app_tier_sg.id
}
output "db_sg_id" {
  value = aws_security_group.db_sg.id
}
