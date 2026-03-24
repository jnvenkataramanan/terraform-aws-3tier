###############################################################
# MODULE: SECURITY GROUPS — all 6, in dependency order
###############################################################

resource "aws_security_group" "bh_sg" {
  name        = "bh-sg"
  description = "Allow SSH from My IP only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from My IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "bh-sg" }
}

# HTTPS only — HTTP not needed, ext-lb listener handles redirect internally
resource "aws_security_group" "ext_lb_sg" {
  name        = "ext-lb-sg"
  description = "Allow HTTPS:443 from anywhere"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "ext-lb-sg" }
}

resource "aws_security_group" "web_tier_sg" {
  name        = "web-tier-sg"
  description = "SSH from bh-sg, HTTP from ext-lb-sg"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH from Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bh_sg.id]
  }
  ingress {
    description     = "HTTP from External Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ext_lb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "web-tier-sg" }
}

resource "aws_security_group" "int_lb_sg" {
  name        = "int-lb-sg"
  description = "Allow HTTP from web-tier-sg"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from Web Tier"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tier_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "int-lb-sg" }
}

resource "aws_security_group" "app_tier_sg" {
  name        = "app-tier-sg"
  description = "SSH from bh-sg, TCP 4000 from int-lb-sg"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH from Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bh_sg.id]
  }
  ingress {
    description     = "App Port 4000 from Internal Load Balancer"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.int_lb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "app-tier-sg" }
}

resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allow MySQL from app-tier-sg"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from App Tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "db-sg" }
}
