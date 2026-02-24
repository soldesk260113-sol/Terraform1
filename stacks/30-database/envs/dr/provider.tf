provider "aws" {
  region = var.aws_region
}

provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = var.tailnet
}
