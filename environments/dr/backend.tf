terraform {
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket" # 상태 파일 저장 S3 버킷
  #   key            = "dr/terraform.tfstate"      # 상태 파일 경로
  #   region         = "ap-northeast-2"
  #   dynamodb_table = "terraform-lock"            # 상태 잠금용 DynamoDB 테이블
  #   encrypt        = true
  # }
}
