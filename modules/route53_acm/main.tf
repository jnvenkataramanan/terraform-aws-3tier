###############################################################
# MODULE: ROUTE53
# Part 1 (Stage 1): Hosted Zone only
# Part 2 (Stage 9): A record www → ext-lb alias
#   ext_lb_dns + ext_lb_zone_id passed after web_tier done
###############################################################

resource "aws_route53_zone" "primary" {
  name = var.domain_name
  tags = { Name = "${var.project_name}-hosted-zone" }
}

# A record — created after web_tier outputs ext_lb values
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  alias {
    name                   = var.ext_lb_dns
    zone_id                = var.ext_lb_zone_id
    evaluate_target_health = true
  }
}
