output "db_endpoint" {
  description = "ECS タスク・マイグレーションが接続する RDS(MySQL) のエンドポイント(Floci プロキシ経由)"
  value       = module.ecs.db_endpoint
}

output "ecs_cluster" {
  value = module.ecs.cluster_name
}

output "ecs_service" {
  value = module.ecs.service_name
}

output "hint" {
  description = "アプリコンテナの確認・アクセス方法"
  value       = <<-EOT
    マイグレーション:  ../scripts/migrate.sh
    動作確認(curl):   ../scripts/smoke-test.sh
    ブラウザ公開:      ../scripts/expose-app.sh   -> http://localhost:${var.app_port}
    アプリコンテナ:    docker ps --filter name=floci-ecs --filter name=todo-app
  EOT
}
