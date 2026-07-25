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

# --- Public subnets (ECS) ---
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "todo-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
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
# ECS(アプリ)用。ローカルエミュレータ前提で inbound を広く開けている。
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

# RDS 専用セキュリティグループ。ECS(app SG)からの MySQL 3306 のみ許可(最小権限)。
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
