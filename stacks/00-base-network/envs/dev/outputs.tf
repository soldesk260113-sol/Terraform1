output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_route_table_ids" {
  value = module.vpc.private_route_table_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr
}

