# 메인 VPC 리소스 정의
# ROSA, RDS, ECR 등 모든 중요 워크로드가 배치될 전용 네트워크 공간입니다.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # ROSA 통신 및 VPC Endpoint Private DNS 사용을 위해 필수
  enable_dns_support   = true # ROSA 통신 및 VPC Endpoint Private DNS 사용을 위해 필수

  tags = {
    Name = "${var.environment}-vpc"
  }
}

