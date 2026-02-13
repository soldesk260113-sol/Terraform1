resource "aws_db_subnet_group" "default" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.environment}-db-subnet-group"
  }
}

resource "aws_db_instance" "default" {
  identifier        = "${var.environment}-db"
  engine            = "postgres"
  engine_version    = "14.7"
  instance_class    = var.instance_class
  allocated_storage = 20
  
  # DR/Standby behavior (simplified for Terraform)
  # In a real DR scenario, this might be a cross-region read replica
  # replicate_source_db = var.primary_db_arn 

  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = var.security_group_ids
  skip_final_snapshot    = true
  
  username = var.db_username
  password = var.db_password

  tags = {
    Name = "${var.environment}-db"
  }
}

