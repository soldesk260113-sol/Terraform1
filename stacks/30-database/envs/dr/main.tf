data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "dr-backup-ap-northeast-2"
    key    = "stacks/10-base-network/dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  vpc_id                  = data.terraform_remote_state.base.outputs.vpc_id
  vpc_cidr                = data.terraform_remote_state.base.outputs.vpc_cidr
  private_subnet_ids      = data.terraform_remote_state.base.outputs.private_subnet_ids
  public_subnet_ids       = data.terraform_remote_state.base.outputs.public_subnet_ids
  private_route_table_ids = data.terraform_remote_state.base.outputs.private_route_table_ids
  
  # Security Groups from net-sec
  # In case net-sec doesn't have a specific DB SG, we use vpn_test_sg or create a local one if needed.
  # For now, following db-terraform logic, modules might create their own or take IDs.
}

# 1. Tailscale Auth Key Generation
resource "tailscale_tailnet_key" "bridge_key" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
}

# 2. S3 Storage for pgBackRest
module "s3_pgbackrest" {
  source       = "../../modules/s3_pgbackrest"
  project_name = var.project_name
}

# 3. DMS Module (Replication Instance)
module "dms" {
  source                 = "../../modules/dms"
  project_name           = var.project_name
  vpc_id                 = local.vpc_id
  subnet_ids             = local.private_subnet_ids
  onprem_db_tailscale_ip = var.onprem_db_tailscale_ip
  rds_endpoint           = module.rds.db_instance_address
  onprem_db_password     = var.onprem_db_password
  rds_db_password        = var.rds_db_password
  dms_instance_class     = var.dms_instance_class
  vpc_cidr               = local.vpc_cidr
  migration_type         = "full-load-and-cdc" # CDC 활성화
}

# 4. Tailscale Bridge (Connectivity)
module "tailscale_bridge" {
  source             = "../../modules/tailscale_bridge"
  project_name       = var.project_name
  vpc_id             = local.vpc_id
  subnet_id          = local.public_subnet_ids[0]
  vpc_cidr           = local.vpc_cidr
  ami_id             = var.bridge_ami_id
  instance_type      = var.bridge_instance_type
  dms_sg_id          = module.dms.dms_sg_id
  tailscale_auth_key = tailscale_tailnet_key.bridge_key.key
}

# 5. RDS Module (Target DB)
module "rds" {
  source               = "../../modules/rds"
  project_name         = var.project_name
  vpc_id               = local.vpc_id
  db_subnet_ids        = local.private_subnet_ids
  vpc_cidr             = local.vpc_cidr
  instance_class       = var.db_instance_class
  engine_version       = var.postgres_version
  db_password          = var.rds_db_password
  db_allocated_storage = var.db_allocated_storage
  dms_sg_id            = module.dms.dms_sg_id
  bridge_sg_id         = module.tailscale_bridge.bridge_sg_id
}

# 7. Ansible 변수 자동 생성
resource "local_file" "ansible_vars" {
  content  = <<-EOT
    # Terraform Generated Variables (DR)
    # Generated at: ${timestamp()}

    # S3 Backup
    s3_bucket_name: "${module.s3_pgbackrest.bucket_name}"
    s3_region: "${var.aws_region}"
    aws_access_key: "${module.s3_pgbackrest.iam_access_key_id}"
    aws_secret_key: "${module.s3_pgbackrest.iam_secret_access_key}"

    # RDS & Migration
    rds_endpoint: "${module.rds.db_instance_address}"
    db_password: "${var.rds_db_password}"
    postgres_version: "${var.postgres_version}"

    # Connectivity
    vpc_cidr: "${local.vpc_cidr}"
    bridge_private_ip: "${module.tailscale_bridge.private_ip}"
    onprem_ip: "${var.onprem_db_tailscale_ip}"
    tailscale_auth_key: "${tailscale_tailnet_key.bridge_key.key}"
  EOT
  filename = "${path.module}/../../../../../../Ansible/02_Database_Layer/group_vars/backup/terraform.yml"
  
  depends_on = [
    module.s3_pgbackrest,
    module.rds,
    module.tailscale_bridge
  ]
}

# 8. Hybrid Network Route (VPC -> Bridge -> On-Prem)
resource "aws_route" "private_to_onprem" {
  count                  = length(local.private_route_table_ids)
  route_table_id         = local.private_route_table_ids[count.index]
  destination_cidr_block = "100.64.0.0/10" # Tailscale 대역
  network_interface_id   = module.tailscale_bridge.bridge_interface_id
}

resource "aws_route" "private_to_onprem_direct" {
  count                  = length(local.private_route_table_ids)
  route_table_id         = local.private_route_table_ids[count.index]
  destination_cidr_block = "10.2.3.0/24" # 온프레미스 직접 대역
  network_interface_id   = module.tailscale_bridge.bridge_interface_id
}
