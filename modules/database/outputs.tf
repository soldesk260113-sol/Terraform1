output "db_instance_id" { # DB 인스턴스 ID
  value = aws_db_instance.default.id
}

output "db_endpoint" { # DB 접속 Endpoint
  value = aws_db_instance.default.endpoint
}
