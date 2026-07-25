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
