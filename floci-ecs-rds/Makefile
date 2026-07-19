APP_NAME := todo-app
APP_IMAGE := todo-app:latest
TF_DIR := terraform

# Floci 接続用のダミー認証(全ターゲット共通)
export AWS_ACCESS_KEY_ID := test
export AWS_SECRET_ACCESS_KEY := test
export AWS_DEFAULT_REGION := us-east-1

.PHONY: help up down build apply plan migrate smoke expose unexpose destroy all clean

help:
	@echo "targets:"
	@echo "  make up       - Floci を起動 (socket マウント付き)"
	@echo "  make build    - todo-app の Docker イメージをビルド"
	@echo "  make apply    - terraform で VPC/RDS/ECS を構築"
	@echo "  make plan     - terraform plan"
	@echo "  make migrate  - RDS へ Drizzle マイグレーション適用"
	@echo "  make smoke    - ECS 経由でアプリの CRUD 確認"
	@echo "  make expose   - localhost:3000 をアプリへ転送 (ブラウザ用)"
	@echo "  make all      - up -> build -> apply -> migrate -> smoke を一括実行"
	@echo "  make destroy  - terraform destroy"
	@echo "  make down     - Floci を停止"
	@echo "  make clean    - destroy + down + proxy 削除"

up:
	./scripts/floci-up.sh

build:
	@test -d app || git clone --depth 1 https://github.com/a2-ito/todo-app.git app
	docker build -t $(APP_IMAGE) ./app

plan:
	cd $(TF_DIR) && terraform init -input=false && terraform plan

apply:
	cd $(TF_DIR) && terraform init -input=false && terraform apply -auto-approve

migrate:
	./scripts/migrate.sh

smoke:
	./scripts/smoke-test.sh

expose:
	./scripts/expose-app.sh

unexpose:
	-docker rm -f todo-app-proxy

# 依存順に一気に実行(初回セットアップ用)
all: up build apply migrate smoke

destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve

down:
	-docker rm -f floci

clean: destroy unexpose down
	@echo "cleaned up."
