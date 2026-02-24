output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

output "subnets_by_az" {
  description = "Subnets grouped by Availability Zone"
  value = {
    for az in var.azs : az => {
      public = {
        id   = module.vpc.public_subnets[az].id
        cidr = module.vpc.public_subnets[az].cidr_block
      }
      private = {
        id   = module.vpc.private_subnets[az].id
        cidr = module.vpc.private_subnets[az].cidr_block
      }
    }
  }
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = module.vpc.private_route_table_ids
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}
