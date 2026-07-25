resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "todo-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "todo-igw" }
}

# --- VPC Flow Logs ---
# VPC 内の通信を CloudWatch Logs に記録する。
# Floci は CreateFlowLogs に未対応(UnsupportedOperation)のため既定では作らない。
# 詳細は variables.tf の enable_flow_logs を参照。
resource "aws_cloudwatch_log_group" "flow_log" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/todo-flow-logs"
  retention_in_days = 7
  tags              = { Name = "todo-flow-logs" }
}

data "aws_iam_policy_document" "flow_log_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    # 書き込み先のロググループ配下のみに限定する
    resources = ["${aws_cloudwatch_log_group.flow_log[0].arn}:*"]
  }
}

resource "aws_iam_role" "flow_log" {
  count              = var.enable_flow_logs ? 1 : 0
  name               = "todo-vpc-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume.json
  tags               = { Name = "todo-vpc-flow-log-role" }
}

resource "aws_iam_role_policy" "flow_log" {
  count  = var.enable_flow_logs ? 1 : 0
  name   = "todo-vpc-flow-log-policy"
  role   = aws_iam_role.flow_log[0].id
  policy = data.aws_iam_policy_document.flow_log[0].json
}

resource "aws_flow_log" "main" {
  count                = var.enable_flow_logs ? 1 : 0
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_log[0].arn
  iam_role_arn         = aws_iam_role.flow_log[0].arn
  tags                 = { Name = "todo-flow-log" }
}

# --- Public subnets (ECS) ---
# map_public_ip_on_launch は無効。ECS サービス側で assign_public_ip = true を
# 指定しているため、タスクは個別に public IP を得られる。サブネットの既定で
# 全リソースに public IP を割り当てる必要はない。
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags                    = { Name = "todo-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false
  tags                    = { Name = "todo-public-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "todo-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  count          = var.enable_route_table_association ? 1 : 0
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  count          = var.enable_route_table_association ? 1 : 0
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# --- Private subnets (RDS) ---
# インターネットへの経路を持たない(NAT なし)。RDS は外向き通信を必要としない。
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "todo-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "todo-private-b" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "todo-private-rt" }
}

resource "aws_route_table_association" "private_a" {
  count          = var.enable_route_table_association ? 1 : 0
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  count          = var.enable_route_table_association ? 1 : 0
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# --- Security groups ---
# ECS(アプリ)用。ingress は VPC 内からアプリポートのみ許可する。
# 実運用で外部公開する場合は ALB を前段に置き、ALB の SG からのみ許可すること。
resource "aws_security_group" "app" {
  name        = "todo-app-sg"
  description = "App SG: allow the app port from within the VPC only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "App port from within the VPC"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # egress は全許可のまま。ECR からのイメージ取得や外部 API 呼び出しに必要で、
  # 絞るには VPC エンドポイントの用意が前提になるためサンプルの範囲を超える。
  # (Trivy AVD-AWS-0177 と同様に .trivyignore.yaml で除外している)
  egress {
    description = "all outbound (image pull and outbound API calls)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "todo-app-sg" }
}

# RDS 専用セキュリティグループ。ECS(app SG)からの MySQL 3306 のみ許可(最小権限)。
# egress は定義しない(ルール 0 件 = 全拒否)。RDS は外向き通信を必要としない。
resource "aws_security_group" "rds" {
  name        = "todo-rds-sg"
  description = "RDS SG: allow MySQL 3306 from the app(ECS) SG only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from ECS(app SG)"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = { Name = "todo-rds-sg" }
}
