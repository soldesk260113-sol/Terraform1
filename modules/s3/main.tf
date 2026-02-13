resource "aws_s3_bucket" "dr_backup" {
  bucket = "${var.environment}-dr-backup-bucket-${var.region}"

  tags = {
    Name        = "${var.environment}-dr-backup"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.dr_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.dr_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

