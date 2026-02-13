# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

# 퍼블릭 라우팅 테이블 생성
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id # 모든 트래픽을 IGW로 라우팅
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

# 퍼블릭 서브넷과 라우팅 테이블 연결
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---- Private / DR Routing ----

# 프라이빗 라우팅 테이블
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
      cidr_block     = var.on_prem_cidr
      gateway_id     = aws_vpn_gateway.main.id
  }

  tags = {
    Name = "${var.environment}-private-rt"
  }
}

# 프라이빗 서브넷 연결
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# VGW Route Propagation (Automatic route learning from VPN)
resource "aws_vpn_gateway_route_propagation" "private" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.private.id
}
