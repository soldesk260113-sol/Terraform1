module "ecr" {
  source = "../../modules/ecr"

  environment  = var.environment
  repositories = var.ecr_repositories
}

module "s3" {
  source = "../../modules/s3"

  environment = var.environment
  region      = var.region
}
