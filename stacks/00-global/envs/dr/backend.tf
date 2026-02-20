terraform {
  backend "s3" {
    bucket = "dr-backup-ap-northeast-2"
    key    = "stacks/00-global/dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}