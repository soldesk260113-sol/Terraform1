output "vpc_id" { # VPC ID 출력
  value = aws_vpc.main.id
}

output "public_subnet_ids" { # 퍼블릭 서브넷 ID 목록
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" { # 프라이빗 서브넷 ID 목록
  value = aws_subnet.private[*].id
}

output "private_route_table_ids" {
  value = [aws_route_table.private.id]
}

output "vpn_tunnel1_address" {
  value = aws_vpn_connection.main.tunnel1_address
}

output "vpn_tunnel2_address" {
  value = aws_vpn_connection.main.tunnel2_address
}
