locals {
  common_tags = merge(
    {
      Name = var.name
    },
    var.tags
  )

  az_count = length(var.azs)
}

# Basic validation (Terraform 1.3+)
resource "null_resource" "validate" {
  triggers = {
    azs_len     = tostring(length(var.azs))
    pub_len     = tostring(length(var.public_subnet_cidrs))
    priv_len    = tostring(length(var.private_subnet_cidrs))
  }

  lifecycle {
    precondition {
      condition     = length(var.azs) == length(var.public_subnet_cidrs)
      error_message = "public_subnet_cidrs length must match azs length."
    }
    precondition {
      condition     = length(var.azs) == length(var.private_subnet_cidrs)
      error_message = "private_subnet_cidrs length must match azs length."
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, { Name = "${var.name}-public-${var.azs[count.index]}" })
}

resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = var.private_subnet_cidrs[count.index]

  tags = merge(local.common_tags, { Name = "${var.name}-private-${var.azs[count.index]}" })
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-rt-public" })
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway(s)
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0
  tags  = merge(local.common_tags, { Name = "${var.name}-eip-nat-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id

  tags = merge(local.common_tags, { Name = "${var.name}-nat-${count.index}" })

  depends_on = [aws_internet_gateway.this]
}

# Private Route Tables (one per AZ)
resource "aws_route_table" "private" {
  count = local.az_count
  vpc_id = aws_vpc.this.id
  tags  = merge(local.common_tags, { Name = "${var.name}-rt-private-${var.azs[count.index]}" })
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? local.az_count : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"

  # single NAT면 0번 NAT 사용, 아니면 AZ별 NAT 사용
  nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
