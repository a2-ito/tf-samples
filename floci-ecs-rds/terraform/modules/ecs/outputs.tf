output "cluster_name" {
  description = "ECS クラスタ名"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "ECS サービス名"
  value       = aws_ecs_service.app.name
}

output "db_endpoint" {
  description = "ECS タスクが接続する RDS(MySQL) のホスト:ポート"
  value       = "${var.db_host}:${var.db_port}"
}
