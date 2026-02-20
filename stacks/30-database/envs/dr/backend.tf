terraform {
  backend "s3" {
    bucket = "antigravity-terraform-state-368352028691"
    key    = "stacks/30-database/dr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
