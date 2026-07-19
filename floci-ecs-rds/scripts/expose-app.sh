#!/bin/sh
# ECS 上の todo-app をブラウザから見られるよう、ホストの :3000 を
# アプリコンテナ(bridge IP:3000)へ socat で転送する。
#   起動: scripts/expose-app.sh
#   停止: docker rm -f todo-app-proxy
# 実行後 http://localhost:3000 で開ける。
set -e

PORT="${PORT:-3000}"

APP=$(docker ps --format '{{.Names}}' | grep 'floci-ecs' | grep 'todo-app' | head -1)
if [ -z "$APP" ]; then
  echo "アプリコンテナ(floci-ecs-*-todo-app)が見つかりません。" >&2
  exit 1
fi
APP_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$APP")
echo "forwarding localhost:${PORT} -> ${APP_IP}:3000 (app=$APP)"

docker rm -f todo-app-proxy >/dev/null 2>&1 || true
docker run -d --name todo-app-proxy -p "${PORT}:3000" alpine/socat \
  "tcp-listen:3000,fork,reuseaddr" "tcp-connect:${APP_IP}:3000" >/dev/null

echo "-> http://localhost:${PORT}  (停止: docker rm -f todo-app-proxy)"
