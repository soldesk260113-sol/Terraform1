terraform {
  backend "s3" {
    bucket = "dr-backup-ap-northeast-2"
    key    = "stacks/10-base-network/dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
