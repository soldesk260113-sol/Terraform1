terraform {
  backend "s3" {
    bucket = "antigravity-terraform-state-368352028691"
    key    = "stacks/00-base-network/dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
