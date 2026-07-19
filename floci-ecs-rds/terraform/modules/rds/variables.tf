variable "subnet_ids" {
  description = "DB サブネットグループに含めるサブネット ID"
  type        = list(string)
}

variable "security_group_id" {
  description = "RDS に紐付けるセキュリティグループ ID"
  type        = string
}

variable "db_name" {
  description = "RDS(MySQL) のデータベース名"
  type        = string
}

variable "db_user" {
  description = "RDS のマスターユーザー名"
  type        = string
}

variable "db_pass" {
  description = "RDS のマスターパスワード"
  type        = string
}
