output "bastion_host_public_ip" {
  description = "Bastion Host Public IP"
  value       = module.bastion.bastion_public_ip
}
output "int_lb_dns_name" {
  description = "Internal Load Balancer DNS"
  value       = module.int_alb.int_lb_dns_name
}
output "ext_lb_dns_name" {
  description = "External Load Balancer DNS"
  value       = module.web_tier.ext_lb_dns_name
}
output "rds_endpoint" {
  description = "RDS MySQL Endpoint"
  value       = module.rds.db_endpoint
}
output "acm_certificate_arn" {
  description = "ACM Certificate ARN"
  value       = module.acm.certificate_arn
}
output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = module.waf.web_acl_arn
}
output "name_servers" {
  description = "Route53 NS records — paste these in GoDaddy"
  value       = module.route53_zone.name_servers
}
output "website_url" {
  description = "Live website URL"
  value       = "https://www.${var.domain_name}"
}
