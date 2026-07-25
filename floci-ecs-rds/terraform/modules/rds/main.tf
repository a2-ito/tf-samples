resource "aws_db_subnet_group" "main" {
  name       = "todo-db-subnet"
  subnet_ids = var.subnet_ids
  tags       = { Name = "todo-db-subnet" }
}

resource "aws_db_instance" "todo" {
  identifier          = "todo-db"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  db_name             = var.db_name
  username            = var.db_user
  password            = var.db_pass
  skip_final_snapshot = true
  publicly_accessible = false

  # 保管データの暗号化(KMS の AWS 管理キーを使用)
  storage_encrypted = true

  # バックアップは既定の 1 日では障害調査に足りないため 7 日保持する
  backup_retention_period = 7

  # 監視と認証
  performance_insights_enabled        = true
  iam_database_authentication_enabled = true

  # マイナーバージョンのセキュリティ修正を自動適用する
  auto_minor_version_upgrade = true

  # スナップショットにインスタンスのタグを引き継ぐ
  copy_tags_to_snapshot = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
}
