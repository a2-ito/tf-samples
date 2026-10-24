# 版の上限は呼び出し側（../../provider.tf）で決める。モジュールは動く下限だけを書く
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
