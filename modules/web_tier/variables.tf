variable "project_name" {
  type = string
}
variable "ami_id" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "key_pair_name" {
  type = string
}
variable "private_key_path" {
  type = string
}
variable "public_subnet_ids" {
  type = list(string)
}
variable "web_tier_sg_id" {
  type = string
}
variable "ext_lb_sg_id" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "int_lb_dns" {
  type = string
}
variable "acm_certificate_arn" {
  type = string
}
variable "bastion_public_ip" {
  type = string
}
