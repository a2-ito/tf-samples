APP_NAME := todo-app
APP_IMAGE := todo-app:latest
TF_DIR := terraform

# IaC セキュリティスキャナ(Docker 実行。ローカルインストール不要)
TRIVY_IMAGE := aquasec/trivy:0.72.0
CHECKOV_IMAGE := bridgecrew/checkov:3.3.8
TRIVY_CACHE := floci-trivy-cache
SCAN_OUT := .scan

# Floci 接続用のダミー認証(全ターゲット共通)
export AWS_ACCESS_KEY_ID := test
export AWS_SECRET_ACCESS_KEY := test
export AWS_DEFAULT_REGION := us-east-1

.PHONY: help up down build apply plan migrate smoke expose unexpose destroy all clean scan scan-trivy scan-checkov

help:
	@echo "targets:"
	@echo "  make up       - Floci を起動 (socket マウント付き)"
	@echo "  make build    - todo-app の Docker イメージをビルド"
	@echo "  make apply    - terraform で VPC/RDS/ECS を構築"
	@echo "  make plan     - terraform plan"
	@echo "  make migrate  - RDS へ Drizzle マイグレーション適用"
	@echo "  make smoke    - ECS 経由でアプリの CRUD 確認"
	@echo "  make expose   - localhost:3000 をアプリへ転送 (ブラウザ用)"
	@echo "  make scan     - IaC セキュリティスキャン (Trivy + Checkov)"
	@echo "  make scan-trivy    - Trivy のみ (tfsec 後継の misconfig scan)"
	@echo "  make scan-checkov  - Checkov のみ"
	@echo "  make all      - up -> build -> apply -> migrate -> smoke を一括実行"
	@echo "  make destroy  - terraform destroy"
	@echo "  make down     - Floci を停止"
	@echo "  make clean    - destroy + down + proxy 削除"

up:
	./scripts/floci-up.sh

build:
	@test -d app || git clone --depth 1 https://github.com/a2-ito/todo-app.git app
	docker build -t $(APP_IMAGE) ./app

upgrade:
	cd $(TF_DIR) && terraform init -upgrade

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

# --- IaC セキュリティスキャン ---
# レポートはコンテナ内からマウント先ファイルへ書き出し、ホスト側で cat する。
# DOCKER_HOST が TCP の環境(colima/lima のポートフォワード等)では
# コンテナのアタッチ出力が端末に届かないため、ファイル経由にしている。
# 設定は trivy.yaml / .checkov.yaml 側にまとめてある。
scan: scan-trivy scan-checkov

scan-trivy:
	@mkdir -p $(SCAN_OUT)
	@docker run --rm \
		-v "$(CURDIR):/src" -v $(TRIVY_CACHE):/root/.cache/trivy \
		-w /src $(TRIVY_IMAGE) \
		config --config trivy.yaml --output /src/$(SCAN_OUT)/trivy.txt $(TF_DIR); \
	status=$$?; \
	if [ -s $(SCAN_OUT)/trivy.txt ]; then cat $(SCAN_OUT)/trivy.txt; \
	else echo "trivy: 検出なし"; fi; \
	exit $$status

scan-checkov:
	@mkdir -p $(SCAN_OUT)
	@docker run --rm \
		-v "$(CURDIR):/src" -w /src $(CHECKOV_IMAGE) \
		--config-file /src/.checkov.yaml -o cli --output-file-path /src/$(SCAN_OUT); \
	status=$$?; \
	if [ -s $(SCAN_OUT)/results_cli.txt ]; then cat $(SCAN_OUT)/results_cli.txt; \
	else echo "checkov: 出力なし"; fi; \
	exit $$status

# 依存順に一気に実行(初回セットアップ用)
all: up build apply migrate smoke

destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve

down:
	-docker rm -f floci

clean: destroy unexpose down
	@echo "cleaned up."
