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

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
}
