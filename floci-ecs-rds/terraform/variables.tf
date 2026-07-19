variable "db_name" {
  description = "RDS(MySQL) のデータベース名"
  type        = string
  default     = "todo_app"
}

variable "db_user" {
  description = "RDS のマスターユーザー名"
  type        = string
  default     = "todo"
}

variable "db_pass" {
  description = "RDS のマスターパスワード"
  type        = string
  default     = "todopassword"
}

variable "app_image" {
  description = "ECS で動かすアプリのローカル Docker イメージ"
  type        = string
  default     = "todo-app:latest"
}

variable "app_port" {
  description = "アプリの待ち受けポート(Next.js standalone)"
  type        = number
  default     = 3000
}
