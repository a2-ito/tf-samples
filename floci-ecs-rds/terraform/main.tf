module "network" {
  source = "./modules/network"
}

module "rds" {
  source = "./modules/rds"

  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id
  db_name           = var.db_name
  db_user           = var.db_user
  db_pass           = var.db_pass
}

module "ecs" {
  source = "./modules/ecs"

  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id
  db_host           = module.rds.address
  db_port           = module.rds.port
  app_image         = var.app_image
  app_port          = var.app_port
  db_name           = var.db_name
  db_user           = var.db_user
  db_pass           = var.db_pass
}
