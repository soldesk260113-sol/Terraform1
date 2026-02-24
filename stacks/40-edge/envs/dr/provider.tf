provider "aws" {
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "kubernetes" {
  host  = "https://api.rosa-single-2a.4klb.p3.openshiftapps.com:443"
  token = var.openshift_token
  insecure = true
}
