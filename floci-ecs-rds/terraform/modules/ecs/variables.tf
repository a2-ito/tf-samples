variable "subnet_ids" {
  description = "ECS サービスを配置するサブネット ID"
  type        = list(string)
}

variable "security_group_id" {
  description = "ECS タスクに紐付けるセキュリティグループ ID"
  type        = string
}

variable "db_host" {
  description = "ECS タスクが接続する DB ホスト(Floci の場合は FLOCI_HOSTNAME で解決される名前)"
  type        = string
}

variable "db_port" {
  description = "ECS タスクが接続する DB ポート(Floci の RDS プロキシポート)"
  type        = number
}

variable "app_image" {
  description = "ECS で動かすアプリのローカル Docker イメージ"
  type        = string
}

variable "app_port" {
  description = "アプリの待ち受けポート(Next.js standalone)"
  type        = number
}

variable "db_name" {
  description = "アプリが接続する DB 名"
  type        = string
}

variable "db_user" {
  description = "アプリが接続する DB ユーザー名"
  type        = string
}

variable "db_pass" {
  description = "アプリが接続する DB パスワード"
  type        = string
}
