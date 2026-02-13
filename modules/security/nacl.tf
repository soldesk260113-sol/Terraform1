# 서브넷 레벨의 네트워크 ACL 설정
resource "aws_network_acl" "main" {
  vpc_id = var.vpc_id
  subnet_ids = var.subnet_ids

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.environment}-nacl"
  }
}

