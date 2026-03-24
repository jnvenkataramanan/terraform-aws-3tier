###############################################################
# Root Variables
###############################################################

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "project"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private (app tier) subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks for DB private subnets"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "my_ip" {
  description = "Your public IP address for Bastion Host SSH access (e.g. 203.0.113.5/32)"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the existing EC2 Key Pair"
  type        = string
  default     = "awsproject"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Ubuntu Server 24.04 LTS in us-east-1)"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 24.04 LTS us-east-1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# RDS Variables
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master DB username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Master DB password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

# Domain Variable
variable "domain_name" {
  description = "Your custom domain name (e.g. yourdomain.com)"
  type        = string
}

# Provisioner variable
variable "private_key_path" {
  description = "Local path to your .pem private key (e.g. ~/Downloads/awsproject.pem)"
  type        = string
  default     = "~/.ssh/awsproject.pem"
}
