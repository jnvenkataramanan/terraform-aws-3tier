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
variable "private_subnet_ids" {
  type = list(string)
}
variable "app_tier_sg_id" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "bastion_public_ip" {
  type = string
}
variable "db_host" {
  type = string
}
variable "db_username" {
  type      = string
  sensitive = true
}
variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_name" {
  type = string
}
