variable "project_name" {
  type = string
}
variable "ami_id" {
  type = string
}
variable "key_pair_name" {
  type = string
}
variable "public_subnet_ids" {
  type = list(string)
}
variable "bh_sg_id" {
  type = string
}
variable "private_key_path" {
  type = string
}
