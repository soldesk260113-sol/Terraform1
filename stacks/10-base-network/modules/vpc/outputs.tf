output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "public_subnets" {
  value = { for s in aws_subnet.public : s.availability_zone => {
    id         = s.id
    cidr_block = s.cidr_block
  } }
}

output "private_subnets" {
  value = { for s in aws_subnet.private : s.availability_zone => {
    id         = s.id
    cidr_block = s.cidr_block
  } }
}

output "igw_id" {
  value = aws_internet_gateway.this.id
}

output "private_route_table_ids" {
  value = [for rt in aws_route_table.private : rt.id]
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

