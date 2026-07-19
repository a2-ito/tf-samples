output "identifier" {
  description = "RDS インスタンス識別子"
  value       = aws_db_instance.todo.identifier
}

output "address" {
  description = "RDS 接続先ホスト(FLOCI_HOSTNAME 設定時は floci に解決される)"
  value       = aws_db_instance.todo.address
}

output "port" {
  description = "RDS のポート"
  value       = aws_db_instance.todo.port
}
