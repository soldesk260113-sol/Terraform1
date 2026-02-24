# 1. DB 서브넷 그룹
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

# 2. RDS 보안 그룹
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow DB traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # VPC 내부 대역 허용
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.dms_sg_id] # DMS 보안 그룹 허용
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.bridge_sg_id] # Tailscale 브릿지 보안 그룹 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. 파라미터 그룹 (DMS 및 SCRAM 인증 설정 포함)
resource "aws_db_parameter_group" "pg13" {
  name   = "${var.project_name}-pg13-params"
  family = "postgres13"

  # 비밀번호 암호화 방식을 온프레미스와 맞춤 (SCRAM-SHA-256)
  parameter {
    name  = "password_encryption"
    value = "scram-sha-256"
  }

  # DMS CDC를 위한 논리적 복제 설정
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot" # 적용을 위해 재부팅 필요
  }

  parameter {
    name  = "wal_sender_timeout"
    value = "0"
  }
}

# 4. RDS PostgreSQL 인스턴스
resource "aws_db_instance" "rds" {
  identifier           = "${var.project_name}-rds"
  allocated_storage    = var.db_allocated_storage
  engine               = "postgres"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  
  db_name              = "appdb"
  username             = "postgres"
  password             = var.db_password # terraform.tfvars의 값을 참조
  
  parameter_group_name   = aws_db_parameter_group.pg13.name
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  skip_final_snapshot  = true
  publicly_accessible  = false

  tags = { Name = "${var.project_name}-rds" }
}
