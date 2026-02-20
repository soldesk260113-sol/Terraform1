module "vpc" {
  source = "../../modules/vpc"

  name = "${var.project}-${var.env}"

  vpc_cidr = var.vpc_cidr
  azs      = var.azs

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}
