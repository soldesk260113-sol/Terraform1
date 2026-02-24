resource "aws_customer_gateway" "this" {
  bgp_asn    = var.cgw_bgp_asn
  ip_address = var.onprem_public_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.name}-cgw"
  }
}

resource "aws_vpn_gateway" "this" {
  tags = {
    Name = "${var.name}-vgw"
  }
}

resource "aws_vpn_gateway_attachment" "this" {
  vpc_id         = var.vpc_id
  vpn_gateway_id = aws_vpn_gateway.this.id
}

resource "aws_vpn_connection" "this" {
  vpn_gateway_id      = aws_vpn_gateway.this.id
  customer_gateway_id = aws_customer_gateway.this.id
  type                = "ipsec.1"
  static_routes_only  = var.static_routes_only

  tags = {
    Name = "${var.name}"
  }

  depends_on = [aws_vpn_gateway_attachment.this]
}

# Static routing이면 반드시 연결 라우트 등록
resource "aws_vpn_connection_route" "onprem" {
  for_each               = var.static_routes_only ? toset(var.onprem_cidrs) : []
  vpn_connection_id      = aws_vpn_connection.this.id
  destination_cidr_block = each.value
}

# 각 Route Table에 onprem CIDRs -> VGW 라우트 추가
locals {
  route_map = {
    for pair in setproduct(var.route_table_ids, var.onprem_cidrs) :
    "${pair[0]}_${pair[1]}" => {
      rtb_id = pair[0]
      cidr   = pair[1]
    }
  }
}

resource "aws_route" "to_onprem" {
  for_each               = local.route_map
  route_table_id         = each.value.rtb_id
  destination_cidr_block = each.value.cidr
  gateway_id             = aws_vpn_gateway.this.id

  depends_on = [aws_vpn_gateway_attachment.this]
}

