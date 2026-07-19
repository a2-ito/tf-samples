#!/bin/sh
# Floci(AWS エミュレータ)を起動する。
#
# なぜ `floci start` を使わないか:
#   この環境では Docker デーモンが Lima/colima の VM 内にあり、ホストへは
#   TCP(tcp://127.0.0.1:2375)で転送されている。`floci start` はホストの
#   DOCKER_HOST の値をそのまま Floci コンテナ内へ渡すため、コンテナ内の
#   127.0.0.1:2375 は自分自身を指してしまい、Floci が RDS/ECS 用の
#   兄弟コンテナを起動できない(Connection refused)。
#   そこで VM 内の /var/run/docker.sock を直接マウントし、コンテナ内の
#   DOCKER_HOST を unix ソケットに向ける。
#
# (ホストの docker CLI が unix ソケットで直接デーモンに繋がる環境なら、
#  素の `floci start` で問題ない。)
#
# コンテナ間接続について:
#   Floci が起動する RDS/ECS コンテナと、それらへ接続するコンテナ(アプリ、
#   マイグレーション)は同じ Docker ネットワーク上にいる必要がある。
#   デフォルトの bridge はコンテナ名の DNS 解決が効かないため、ユーザー定義
#   ネットワーク(floci-net)を作ってそこに載せる。
#   FLOCI_HOSTNAME=floci を設定すると、Floci が RDS エンドポイント等の応答に
#   localhost ではなく DNS 解決可能な "floci" を埋め込むため、他コンテナから
#   floci:7001(RDS プロキシポート)で RDS へ到達できる。
set -e

NAME=floci
PORT=4566
NET=floci-net

docker network create "$NET" >/dev/null 2>&1 || true
docker rm -f "$NAME" >/dev/null 2>&1 || true

docker run -d --name "$NAME" \
  --network "$NET" \
  -p "${PORT}:4566" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v floci-data:/app/data \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  -e FLOCI_HOSTNAME="$NAME" \
  -e FLOCI_SERVICES_DOCKER_NETWORK="$NET" \
  floci/floci:latest >/dev/null

printf "waiting for Floci"
for _ in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/_floci/health" 2>/dev/null || true)
  if [ "$code" = "200" ]; then
    echo " ... ready (http://localhost:${PORT})"
    exit 0
  fi
  printf "."
  sleep 1
done

echo
echo "Floci が起動しませんでした。'docker logs ${NAME}' を確認してください。" >&2
exit 1
