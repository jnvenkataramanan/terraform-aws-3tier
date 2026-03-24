###############################################################
# AWS Three-Tier Architecture — Root Module
#
# EXECUTION ORDER:
#   Stage 1  → Route53 Hosted Zone  (no deps)
#   Stage 1  → ACM Certificate      (needs hosted_zone_id)
#   Stage 2  → VPC                  (parallel with Stage 1)
#   Stage 2  → Security Groups      (needs VPC)
#   Stage 2  → RDS                  (needs VPC + SGs)
#   Stage 3  → Bastion Host         (needs VPC + bh_sg)
#   Stage 4  → App Tier             (needs Bastion + RDS)
#   Stage 5  → Internal ALB         (needs app-tier-tg)
#   Stage 6  → Web Tier             (needs int_lb_dns + cert)
#   Stage 7  → WAF                  (needs ext_lb_arn)
#   Stage 8  → Route53 A record     (needs ext_lb_dns)
###############################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = var.aws_region }

###############################################################
# STAGE 1A — Route53 Hosted Zone
# No dependencies — runs immediately
###############################################################
module "route53_zone" {
  source       = "./modules/route53_acm"
  project_name = var.project_name
  domain_name  = var.domain_name
  # A record values — Terraform waits for web_tier automatically
  ext_lb_dns     = module.web_tier.ext_lb_dns_name
  ext_lb_zone_id = module.web_tier.ext_lb_zone_id
}

###############################################################
# STAGE 1B — ACM Certificate
# Needs hosted_zone_id to create CNAME validation record
# Outputs certificate_arn → web_tier needs this for HTTPS listener
###############################################################
module "acm" {
  source         = "./modules/acm"
  project_name   = var.project_name
  domain_name    = var.domain_name
  hosted_zone_id = module.route53_zone.hosted_zone_id
}

###############################################################
# STAGE 2A — VPC
###############################################################
module "vpc" {
  source               = "./modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
}

###############################################################
# STAGE 2B — Security Groups
# HTTPS:443 only in ext-lb-sg (HTTP not needed in SG)
###############################################################
module "security_groups" {
  source       = "./modules/security_groups"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  my_ip        = var.my_ip
}

###############################################################
# STAGE 2C — RDS MySQL
###############################################################
module "rds" {
  source            = "./modules/rds"
  project_name      = var.project_name
  db_subnet_ids     = module.vpc.db_subnet_ids
  db_sg_id          = module.security_groups.db_sg_id
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  db_instance_class = var.db_instance_class
}

###############################################################
# STAGE 3 — Bastion Host
# Only needs: ami, key, public_subnet, bh_sg, private_key
# SSH retry loop — waits until EC2 is actually ready
###############################################################
module "bastion" {
  source            = "./modules/ec2"
  project_name      = var.project_name
  ami_id            = var.ami_id
  key_pair_name     = var.key_pair_name
  public_subnet_ids = module.vpc.public_subnet_ids
  bh_sg_id          = module.security_groups.bh_sg_id
  private_key_path  = var.private_key_path
}

###############################################################
# STAGE 4 — App Tier
# app_tier_setup.sh → db_init.sh → AMI → Template → TG → ASG
###############################################################
module "app_tier" {
  source             = "./modules/app_tier"
  project_name       = var.project_name
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  key_pair_name      = var.key_pair_name
  private_key_path   = var.private_key_path
  private_subnet_ids = module.vpc.private_subnet_ids
  app_tier_sg_id     = module.security_groups.app_tier_sg_id
  vpc_id             = module.vpc.vpc_id
  bastion_public_ip  = module.bastion.bastion_public_ip
  db_host            = module.rds.db_endpoint
  db_username        = var.db_username
  db_password        = var.db_password
  db_name            = var.db_name

  depends_on = [module.bastion, module.rds]
}

###############################################################
# STAGE 5 — Internal ALB
# Wires int-lb listener → app-tier-tg
###############################################################
module "int_alb" {
  source               = "./modules/alb"
  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  int_lb_sg_id         = module.security_groups.int_lb_sg_id
  app_target_group_arn = module.app_tier.app_target_group_arn

  depends_on = [module.app_tier]
}

###############################################################
# STAGE 6 — Web Tier
# EC2 → nginx → AMI → ASG → ext-lb (after ASG + cert ready)
# acm_certificate_arn implicit wait for cert ISSUED
###############################################################
module "web_tier" {
  source              = "./modules/web_tier"
  project_name        = var.project_name
  ami_id              = var.ami_id
  instance_type       = var.instance_type
  key_pair_name       = var.key_pair_name
  private_key_path    = var.private_key_path
  public_subnet_ids   = module.vpc.public_subnet_ids
  web_tier_sg_id      = module.security_groups.web_tier_sg_id
  ext_lb_sg_id        = module.security_groups.ext_lb_sg_id
  vpc_id              = module.vpc.vpc_id
  int_lb_dns          = module.int_alb.int_lb_dns_name
  acm_certificate_arn = module.acm.certificate_arn
  bastion_public_ip   = module.bastion.bastion_public_ip

  depends_on = [module.int_alb, module.acm]
}

###############################################################
# STAGE 7 — WAF
###############################################################
module "waf" {
  source       = "./modules/waf"
  project_name = var.project_name
  ext_lb_arn   = module.web_tier.ext_lb_arn

  depends_on = [module.web_tier]
}

# Stage 8 — Route53 A record (www → ext-lb)
# Inside module.route53_zone — Terraform creates it automatically
# after web_tier because ext_lb_dns/zone_id are web_tier references
