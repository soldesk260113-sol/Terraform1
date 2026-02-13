# 퍼블릭 서브넷 생성
# 용도: Application Load Balancer (ALB) 등 외부 인터넷 연결이 필요한 리소스
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]

  map_public_ip_on_launch = true # 인스턴스 시작 시 퍼블릭 IP 자동 할당 (주로 Bastion Host 등)

  tags = {
    Name = "${var.environment}-public-subnet-${count.index + 1}"
    "kubernetes.io/role/elb" = "1" # (Optional) AWS Load Balancer Controller가 퍼블릭 ELB 생성 시 인식
  }
}

# 프라이빗 서브넷 생성
# 용도: ROSA Worker Node, RDS, VPC Endpoints, DR Worker 등 외부 노출 방지 리소스
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.environment}-private-subnet-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1" # (Optional) Internal ELB 생성 시 인식
  }
}

