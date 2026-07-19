output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "サブネット ID の一覧(a, b)"
  value       = [aws_subnet.a.id, aws_subnet.b.id]
}

output "security_group_id" {
  description = "アプリ用セキュリティグループ ID"
  value       = aws_security_group.app.id
}
