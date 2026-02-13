resource "aws_customer_gateway" "main" {
  bgp_asn    = var.bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.environment}-cgw"
  }
}

resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-vgw"
  }
}

resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.main.id
  type                = "ipsec.1"
  static_routes_only  = true

  # Tunnel 1 암호화 설정 (AES-256)
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]  # DH Group 14 (2048-bit)
  tunnel1_phase2_dh_group_numbers      = [14]

  # Tunnel 2 암호화 설정 (AES-256)
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_dh_group_numbers      = [14]
  tunnel2_phase2_dh_group_numbers      = [14]

  tags = {
    Name = "${var.environment}-vpn"
  }
}

# VPN Connection용 정적 라우팅 (Static Route)
# AWS에게 "온프레미스 대역(10.2.2.0/24)으로 가는 트래픽은 이 VPN 연결을 태워라"고 명시
resource "aws_vpn_connection_route" "office" {
  destination_cidr_block = var.on_prem_cidr
  vpn_connection_id      = aws_vpn_connection.main.id
}
