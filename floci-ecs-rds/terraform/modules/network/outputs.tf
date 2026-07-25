output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "public サブネット ID の一覧(ECS 用: a, b)"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  description = "private サブネット ID の一覧(RDS 用: a, b)"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "security_group_id" {
  description = "アプリ用セキュリティグループ ID"
  value       = aws_security_group.app.id
}

output "rds_security_group_id" {
  description = "RDS 専用セキュリティグループ ID(ECS からの 3306 のみ許可)"
  value       = aws_security_group.rds.id
}
