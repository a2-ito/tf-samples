#!/bin/sh
# RDS(MySQL)に対して todo-app の Drizzle マイグレーションを適用する。
#
# アプリ(ECS)と同様に、Floci の TCP プロキシ(floci:7001)経由で RDS へ接続する。
# ホスト(Mac)からは Floci のネットワークに直接繋がらないため、同じネットワーク
# (floci-net)上の node コンテナから drizzle-kit push を実行する。
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APPDIR="$ROOT/app"

NET="${FLOCI_NETWORK:-floci-net}"
DB_HOST="${DB_HOST:-floci}"
DB_PORT="${DB_PORT:-7001}"
DB_USER="${DB_USER:-todo}"
DB_PASS="${DB_PASS:-todopassword}"
DB_NAME="${DB_NAME:-todo_app}"

echo "MySQL の起動を待機中... (${DB_HOST}:${DB_PORT})"
for _ in $(seq 1 30); do
  name="ping$$"; docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" --network "$NET" mysql:8.0 \
    sh -c "mysqladmin -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS ping 2>&1" >/dev/null 2>&1
  docker wait "$name" >/dev/null 2>&1 || true
  out=$(docker logs "$name" 2>&1); docker rm -f "$name" >/dev/null 2>&1 || true
  echo "$out" | grep -q "mysqld is alive" && break
  sleep 2
done

echo "Drizzle マイグレーションを実行中..."
name="migrate$$"; docker rm -f "$name" >/dev/null 2>&1 || true
docker run -d --name "$name" --network "$NET" \
  -v "$APPDIR":/app -w /app \
  -e DB_TYPE=mysql -e DB_HOST="$DB_HOST" -e DB_PORT="$DB_PORT" -e DB_USER="$DB_USER" -e DB_PASS="$DB_PASS" -e DB_NAME="$DB_NAME" \
  node:20-alpine \
  sh -c "npm ci --include=dev >/tmp/npm.log 2>&1 && npm run drizzle:migrate" >/dev/null 2>&1
docker wait "$name" >/dev/null 2>&1 || true
docker logs "$name" 2>&1
docker rm -f "$name" >/dev/null 2>&1 || true
echo "完了。"
