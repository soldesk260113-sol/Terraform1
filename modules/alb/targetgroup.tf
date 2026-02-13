# 타겟 그룹 생성 (HTTP 80)
resource "aws_lb_target_group" "main" {
  name     = "${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/health" # 헬스 체크 경로
  }
}

# ALB 리스너 설정 (HTTP -> HTTPS 리다이렉트)
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ALB 리스너 설정 (HTTPS -> Target Group)
resource "aws_lb_listener" "front_end_https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"  # 최신 TLS 1.3 정책
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# [ROSA 연결 안내]
# 이 Target Group과 ROSA 파드를 연결하려면, 클러스터 내부의 'AWS Load Balancer Controller'가 필요합니다.
# 방법: ROSA에 'TargetGroupBinding' 커스텀 리소스(CRD)를 생성하여,
#       이 Target Group ARN과 Kubernetes Service를 매핑해주면 자동으로 연결됩니다.
output "target_group_arn" {
  value = aws_lb_target_group.main.arn
}
