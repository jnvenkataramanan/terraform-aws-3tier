output "hosted_zone_id" {
  value = aws_route53_zone.primary.zone_id
}
output "name_servers" {
  value = aws_route53_zone.primary.name_servers
}
output "www_record_fqdn" {
  value = aws_route53_record.www.fqdn
}
