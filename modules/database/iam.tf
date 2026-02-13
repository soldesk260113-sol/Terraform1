# DB 인스턴스용 IAM 역할 생성
resource "aws_iam_role" "db_role" {
  name = "${var.environment}-db-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# EC2 인스턴스 프로파일 생성
resource "aws_iam_instance_profile" "db_profile" {
  name = "${var.environment}-db-profile"
  role = aws_iam_role.db_role.name
}
