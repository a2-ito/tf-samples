#!/bin/sh
# ECS 上の todo-app に対して疎通確認(GET / と Todo の CRUD)を行う。
# アプリコンテナはホストにポート公開しておらず floci-net 上にしかいないため、
# 同じ floci-net 上に curl コンテナを起動してアクセスする
# (デフォルト bridge に起動するとアプリへ届かず HTTP 000 になる)。
set -e

NET=floci-net

APP=$(docker ps --format '{{.Names}}' | grep 'floci-ecs' | grep 'todo-app' | head -1)
if [ -z "$APP" ]; then
  echo "アプリコンテナ(floci-ecs-*-todo-app)が見つかりません。" >&2
  exit 1
fi
APP_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$APP")
echo "APP=$APP  APP_IP=$APP_IP"

run() {
  name="curl$$_$1"; docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" --network "$NET" curlimages/curl:latest sh -c "$2" >/dev/null 2>&1
  docker wait "$name" >/dev/null 2>&1 || true
  docker logs "$name" 2>&1; docker rm -f "$name" >/dev/null 2>&1 || true
}

echo "--- GET / ---"
run a "curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://$APP_IP:3000/"
echo "--- POST /api/todos ---"
run b "curl -s -w '\nHTTP %{http_code}\n' -X POST http://$APP_IP:3000/api/todos -H 'Content-Type: application/json' -d '{\"title\":\"Floci smoke test\",\"description\":\"ECS+RDS\"}'"
echo "--- GET /api/todos ---"
run c "curl -s http://$APP_IP:3000/api/todos; echo"
