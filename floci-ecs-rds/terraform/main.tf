module "network" {
  source = "./modules/network"
}

module "rds" {
  source = "./modules/rds"

  subnet_ids = module.network.private_subnet_ids
  # RDS は private サブネットに配置し、ECS(app SG)からの 3306 のみ許可する専用 SG を割り当てる。
  security_group_id = module.network.rds_security_group_id
  db_name           = var.db_name
  db_user           = var.db_user
  db_pass           = var.db_pass
}

module "ecs" {
  source = "./modules/ecs"

  subnet_ids        = module.network.public_subnet_ids
  security_group_id = module.network.security_group_id
  db_host           = module.rds.address
  db_port           = module.rds.port
  app_image         = var.app_image
  app_port          = var.app_port
  db_name           = var.db_name
  db_user           = var.db_user
  db_pass           = var.db_pass
}
