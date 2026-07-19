# Floci + Terraform で ECS + RDS な Web アプリをローカル構築

[Floci](https://floci.io/)(LocalStack ドロップイン代替の AWS ローカルエミュレータ)上に、
Terraform で **VPC / RDS(MySQL) / ECS** を構築し、Next.js 製の Todo アプリ
([a2-ito/todo-app](https://github.com/a2-ito/todo-app))を動かすサンプル。

```
ブラウザ ──▶ ECS task (todo-app / Next.js :3000) ──▶ RDS (MySQL 8.0)
                      すべて Floci が起動する Docker コンテナ
```

## 構成

```
floci-ecs-rds/
├── app/                     # todo-app を clone(Docker イメージのビルド元)
├── terraform/
│   ├── main.tf              # 各モジュールを呼び出し、依存を受け渡す
│   ├── provider.tf          # AWS provider。エンドポイントを Floci(:4566)へ
│   ├── variables.tf         # DB 名/ユーザー/パスワード、イメージ名など
│   ├── outputs.tf
│   └── modules/
│       ├── network/         # VPC / subnet x2 / security group
│       ├── rds/             # aws_db_instance (mysql 8.0)
│       └── ecs/             # cluster / task definition / service
└── scripts/
    ├── floci-up.sh          # Floci を起動(共有ネットワーク + FLOCI_HOSTNAME)
    ├── migrate.sh           # RDS へ Drizzle マイグレーション適用
    ├── smoke-test.sh        # ECS 経由でアプリの CRUD を確認
    └── expose-app.sh        # localhost:3000 をアプリコンテナへ転送(ブラウザ用)
```

## 前提

- Docker が動作していること(このサンプルは Lima/colima の VM 内 Docker + TCP 転送環境で検証)
- `terraform` / `aws` CLI
- Floci CLI(`curl -fsSL https://floci.io/install.sh | FLOCI_INSTALL_DIR="$HOME/.local/bin" sh`)
  ※ 起動は `floci start` ではなく後述の `floci-up.sh` を使う(理由は下記)

## クイックスタート(Makefile)

```sh
make all      # up -> build -> apply -> migrate -> smoke を一括実行
make expose   # ブラウザで見る -> http://localhost:3000
make clean    # 後片付け(destroy + Floci 停止)
```

個別に実行する場合や仕組みを追う場合は以下の手順を参照(`make <target>` と対応)。

## 手順

### 1. Floci を起動（`make up`）

```sh
./scripts/floci-up.sh
```

> **なぜ `floci start` を使わないか**
> Docker デーモンが Lima/colima の VM 内にあり `tcp://127.0.0.1:2375` でホストへ転送される構成だと、
> `floci start` はホストの `DOCKER_HOST` をそのまま Floci コンテナ内へ渡す。すると
> コンテナ内の `127.0.0.1:2375` は自分自身を指し、Floci が RDS/ECS 用の兄弟コンテナを
> 起動できない(Connection refused)。`floci-up.sh` は VM 内の `/var/run/docker.sock` を
> マウントし、コンテナ内 `DOCKER_HOST` を unix ソケットに向けて回避する。
> (ホストが unix ソケットで直接 Docker に繋がる環境なら素の `floci start` でも可。)

### 2. アプリの Docker イメージをビルド

```sh
# 未 clone の場合
git clone --depth 1 https://github.com/a2-ito/todo-app.git app

docker build -t todo-app:latest ./app
```

ECS の task definition はこのローカルイメージ(`todo-app:latest`)を直接参照する
(Floci の ECS はホストと同じ Docker デーモンを使うため ECR プッシュ不要)。

### 3. Terraform で構築

```sh
cd terraform
terraform init
terraform apply
```

VPC / RDS(MySQL) / ECS cluster / task definition / service を作成する。
`aws_ecs_service` により todo-app コンテナ(`floci-ecs-*-todo-app`)が 1 つ起動する。

### 4. マイグレーション(テーブル作成)

```sh
cd ..
./scripts/migrate.sh
```

todo-app 本来の Drizzle マイグレーション(`npm run drizzle:migrate` = `drizzle-kit push`)を、
Floci と同じネットワーク(`floci-net`)上の node コンテナから `floci:7001` 経由で実行し、
`todos` テーブルを作成する。

### 5. 動作確認

```sh
# curl で CRUD 確認
./scripts/smoke-test.sh

# ブラウザで見る
./scripts/expose-app.sh   # -> http://localhost:3000
```

## 後片付け

```sh
cd terraform && terraform destroy
docker rm -f todo-app-proxy            # expose-app.sh を使った場合
docker rm -f floci                     # Floci 本体を停止
```

## ハマりどころ / 設計メモ

Floci は LocalStack 互換だが、ローカルエミュレータ特有の癖がある。本サンプルはそれを吸収している。

- **`floci start` は VM+TCP 環境で Docker ソケットを渡せない**
  → `floci-up.sh` でソケットマウントして起動(手順1参照)。

- **RDS への接続は Floci のプロキシ経由(コンテナ間)で行う**
  Floci の RDS は実際の MySQL コンテナを起動し、`7001-7099` のプロキシポートで接続を中継する。
  コンテナ間で接続するには、全コンテナを同じ Docker ネットワークに載せ、Floci に
  `FLOCI_HOSTNAME=floci` を設定する(`floci-up.sh` がそれ)。こうすると Floci が
  `aws_db_instance.address` に `localhost` ではなく DNS 解決可能な `floci` を埋め込むため、
  ECS タスクは `floci:7001` で RDS に到達できる。この `address` / `.port` をそのまま
  ECS の `DB_HOST` / `DB_PORT` に渡している。
  (`FLOCI_HOSTNAME` を設定しないと Floci は `localhost` や bridge IP を報告し、
  別コンテナからは届かない。)

- **ホスト(Mac)から RDS へは直接繋がらない**
  Floci のプロキシは VM 内ネットワーク上にあるため、マイグレーションや DB 確認は
  同一ネットワーク(`floci-net`)上のコンテナ経由で `floci:7001` に繋いで行う(`migrate.sh` がそれ)。

- **ECS タスクはホストにポート公開されない**
  アプリコンテナは `3000/tcp` を expose するだけなので、ブラウザで見るには
  `expose-app.sh`(socat 転送)を使う。

- **Floci はエフェメラル**
  コンテナ再起動で AWS 状態が消える。再開時は `floci-up.sh` からやり直す
  (`terraform` の state も作り直しになる)。
