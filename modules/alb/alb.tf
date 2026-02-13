# 애플리케이션 로드 밸런서 (ALB) 생성
resource "aws_lb" "main" {
  name               = "${var.environment}-alb"
  internal           = false # 인터넷에서 접근 가능 (Public)
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  tags = {
    Name = "${var.environment}-alb"
  }
}

