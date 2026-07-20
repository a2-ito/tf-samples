resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "todo-vpc" }
}

resource "aws_subnet" "a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "todo-subnet-a" }
}

resource "aws_subnet" "b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "todo-subnet-b" }
}

resource "aws_security_group" "app" {
  name        = "todo-app-sg"
  description = "Allow app and mysql traffic (local emulator)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "all inbound (local only)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "todo-app-sg" }
}

# RDS 専用セキュリティグループ。
# ECS(app SG)からの MySQL 3306 のみ ingress を許可する(最小権限)。
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "todo-rds-sg" }
}
