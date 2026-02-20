terraform {
  backend "s3" {
    bucket = "antigravity-terraform-state-368352028691"
    key    = "stacks/10-net-sec/dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
