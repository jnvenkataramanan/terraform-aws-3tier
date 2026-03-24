variable "project_name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "int_lb_sg_id" {
  type = string
}
variable "app_target_group_arn" {
  type = string
}
