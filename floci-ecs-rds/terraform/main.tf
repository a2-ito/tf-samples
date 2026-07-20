module "network" {
  source = "./modules/network"
}

module "rds" {
  source = "./modules/rds"

  subnet_ids = module.network.subnet_ids
  # 【検証用】RDS には ECS からの ingress を持たない専用 SG を割り当てる。
  # 通常運用に戻す場合は module.network.security_group_id へ戻す。
  security_group_id = module.network.rds_security_group_id
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
