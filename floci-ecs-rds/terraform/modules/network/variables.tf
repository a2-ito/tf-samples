variable "app_port" {
  description = "アプリの待ち受けポート。app SG の ingress をこのポートのみに絞るために使う。"
  type        = number
}

variable "enable_flow_logs" {
  description = <<-EOT
    VPC Flow Logs(ロググループ / IAM ロール / aws_flow_log)を作成するか。
    Floci は CreateFlowLogs に未対応で
    (api error UnsupportedOperation: Operation CreateFlowLogs is not supported)、
    apply が失敗するため既定では無効にしている。
    実 AWS に適用する場合は true にする。
  EOT
  type        = bool
  default     = false
}

variable "enable_route_table_association" {
  description = <<-EOT
    サブネットとルートテーブルの関連付け(aws_route_table_association)を作成するか。
    Floci はこのリソースの作成を完了できず(DescribeRouteTables が association を
    返さないため provider がタイムアウトする)、既定では無効にしている。
    実 AWS に適用する場合は true にする(public サブネットが IGW 経由で疎通するために必要)。
  EOT
  type        = bool
  default     = false
}
