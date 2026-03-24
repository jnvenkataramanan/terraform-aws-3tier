###############################################################
# MODULE: RDS MYSQL
# Creates: DB Subnet Group + MySQL RDS Instance
###############################################################

# DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "db-subnet-group"
  description = "Subnet group for ${var.project_name} RDS"
  subnet_ids  = var.db_subnet_ids

  tags = {
    Name = "db-subnet-group"
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "mysql" {
  identifier              = "database-1"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = "gp2"
  storage_encrypted       = false
  multi_az                = false

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [var.db_sg_id]
  availability_zone      = "us-east-1a"
  publicly_accessible    = false

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project_name}-rds-mysql"
  }
}
