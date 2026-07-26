resource "aws_db_subnet_group" "main" {
  name       = "todo-db-subnet"
  subnet_ids = var.subnet_ids
  tags       = { Name = "todo-db-subnet" }
}

# --- 拡張モニタリング(Enhanced Monitoring)用の IAM ロール ---
# RDS が OS レベルのメトリクスを CloudWatch Logs に書き込むために引き受けるロール。
data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "todo-rds-monitoring-role"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
  tags               = { Name = "todo-rds-monitoring-role" }
}

# AWS 管理ポリシー AmazonRDSEnhancedMonitoringRole と同等の権限をインラインで定義する。
# Floci には AWS 管理ポリシーが存在せず、AttachRolePolicy が NoSuchEntity で失敗するため。
data "aws_iam_policy_document" "monitoring" {
  statement {
    sid    = "EnableCreationAndManagementOfRDSCloudwatchLogGroups"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy",
    ]
    resources = ["arn:aws:logs:*:*:log-group:RDS*"]
  }

  statement {
    sid    = "EnableCreationAndManagementOfRDSCloudwatchLogStreams"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:log-group:RDS*:log-stream:*"]
  }
}

resource "aws_iam_role_policy" "monitoring" {
  name   = "todo-rds-monitoring-policy"
  role   = aws_iam_role.monitoring.id
  policy = data.aws_iam_policy_document.monitoring.json
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

  # 拡張モニタリング(60 秒間隔で OS メトリクスを収集)
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.monitoring.arn

  # DB のログを CloudWatch Logs に出力する
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  # 単一 AZ 障害でサービスが停止しないよう Multi-AZ 構成にする
  multi_az = true

  # マイナーバージョンのセキュリティ修正を自動適用する
  auto_minor_version_upgrade = true

  # スナップショットにインスタンスのタグを引き継ぐ
  copy_tags_to_snapshot = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
}
