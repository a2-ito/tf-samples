---
title: "Floci + Terraform で ECS + RDS をローカル構築して、RDS エンドポイントの癖にハマった話"
emoji: "🐳"
type: "tech"
topics: ["floci", "terraform", "ecs", "rds", "docker"]
published: false
---

## はじめに

[Floci](https://floci.io/) は LocalStack のドロップイン代替をうたう AWS ローカルエミュレータである。
標準の AWS クライアントを `http://localhost:4566` に向けるだけで動き、RDS や ECS はモックではなく実際の Docker コンテナ（本物の MySQL や PostgreSQL）で動く。

この Floci 上に、Terraform で ECS + RDS 構成の Web アプリ（Next.js + MySQL）をローカル構築するサンプルを作った。
その過程で、RDS のエンドポイントをそのまま接続に使えないという癖に突き当たった。
本記事では、この癖の正体と回避策を記録する。

## 全体構成

構成はごく素直で、VPC とサブネット、セキュリティグループ、RDS（MySQL）、ECS（Fargate）でアプリを動かす。
Terraform の provider だけは Floci に向ける必要がある。

```hcl
# provider.tf
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2            = "http://localhost:4566"
    ecs            = "http://localhost:4566"
    rds            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    # ... 以下省略
  }
}
```

認証はダミーで、各種バリデーションはローカルなのでスキップする。
ここまでは LocalStack と同じ要領で、特に問題は起きない。

## つまずき: Floci が報告する RDS エンドポイントで接続できない

問題は、ECS のタスクから RDS へ接続する段で起きた。

Terraform で RDS を作ると、`aws_db_instance` は接続先として `address` と `port` を返す。
素直に考えれば、この値を ECS コンテナの環境変数 `DB_HOST` に渡せばよい。

ところが Floci が返してきた値はこうだった。

```
address  = "172.17.0.3"
port     = 7001
```

`172.17.0.3` は Docker bridge ネットワーク上の IP らしき値だが、ポートが `7001` になっている。
アプリが接続を試みても、MySQL には届かない。

## `7001` の正体

`7001` がどこから来た値なのか、リポジトリ内には定義がない。
`provider.tf` で明示しているのは Floci のエッジエンドポイント `4566` だけである。
そこで Floci のドキュメントを当たったところ、[Docker Compose の設定ページ](https://floci.io/floci/configuration/docker-compose/)に答えがあった。

```
7001-7099:7001-7099  # RDS proxy ports
```

`7001` は Floci が **RDS のTCPプロキシに割り当てるポート**で、`7001-7099` という専用レンジの先頭だった。
Floci の RDS は本物の MySQL コンテナを起動し、そこへの接続を Floci 本体がこのレンジのポートでプロキシする。
RDS インスタンスを複数作れば、`7002`、`7003` と採番されていく類のものである。

つまり Floci が返す `address:port`（`172.17.0.3:7001`）は、**ホストマシンからプロキシ経由で DB に届くための入口**を表している。
一方、実際の MySQL コンテナは標準の `3306` で待ち受けている。
報告値の実体は `172.17.0.4:3306` のような別のアドレスであり、報告値と実体がずれる[^floci-rds]。

[^floci-rds]: Floci の RDS/ElastiCache は「実 Docker コンテナへ TCP をプロキシする」設計で、そのプロキシポートをホストへ公開するために `7001-7099` のレンジを使う。ポート採番のアルゴリズムそのものは Floci 本体の実装依存で、公式ドキュメントには明記されていない。

## なぜ ECS からは `7001` で届かないのか

ここで一つ区別が要る。
「ホストマシンから接続する」経路と、「ECS コンテナ（別の Docker コンテナ）から接続する」経路は別物である。

`7001-7099` のプロキシは、ホストマシン向けに公開されるポートである。
ホスト上の `mysql` クライアントからなら、`localhost:7001` で RDS に届く。
`7001-7099` をホストに publish しておけば、この経路は成立する。

しかし ECS のアプリコンテナから見ると事情が変わる。
コンテナにとって `localhost:7001` は自分自身を指してしまい、RDS ではない。
Floci のプロキシがホストの `0.0.0.0:7001` で待ち受けていても、bridge 上の別コンテナからそこへ素直には到達できない。
さらに、この検証環境では Docker デーモンが Lima/colima の VM 内にあり、publish 先が VM の IP になるため経路はいっそう込み入る。

要するに、`7001` はホスト向けの入口であって、コンテナ間通信の入口ではない。

## 解決策: 実 IP を `docker inspect` で取って Terraform に渡す

ECS コンテナと RDS コンテナは、どちらも同じ Docker bridge 上にいる。
であれば、プロキシを経由せず、RDS コンテナの実 IP へ標準ポート `3306` で直接つなげばよい。

RDS コンテナの実 IP は `docker inspect` で取れる。
Floci は RDS 用のコンテナを `floci-rds-<identifier>` という名前で起動するので、その名前で引く。

```sh
#!/bin/sh
# rds_ip.sh <db-instance-identifier>
# 出力: {"ip":"172.17.0.x"}
IDENT="$1"
IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "floci-rds-${IDENT}")
printf '{"ip":"%s"}\n' "$IP"
```

この値を Terraform に取り込むには、`external` provider の data source を使う。
スクリプトが返す JSON を、そのまま Terraform の値として読み込める。

```hcl
data "external" "rds_ip" {
  program = ["sh", "${path.module}/scripts/rds_ip.sh", var.db_identifier]
}

locals {
  db_host = data.external.rds_ip.result.ip
}
```

あとは `local.db_host` を ECS タスク定義の環境変数 `DB_HOST` に渡し、ポートは `3306` を使う。
Floci が報告する `7001` のエンドポイントは接続には使わず、参考値として output に残すだけにした。

なお、これは Floci に固有の回避策である。
本物の AWS の RDS であれば、`aws_db_instance.address` と `.port`（`3306`）がそのまま正しい接続先になる。

## 補足: Terraform のモジュール構成

リソースが増えてきたので、機能ごとにモジュールへ分割した。
`main.tf` から各モジュールを呼び出し、モジュール間の依存は output と変数で受け渡す。

```
terraform/
├── main.tf          # module "network" / "rds" / "ecs" を呼び出す
├── provider.tf      # provider 設定（Floci に向ける）
├── variables.tf
├── outputs.tf
└── modules/
    ├── network/     # VPC, サブネット, セキュリティグループ
    ├── rds/         # DB サブネットグループ, RDS インスタンス
    └── ecs/         # クラスタ, タスク定義, サービス（+ 実 IP 取得）
        └── scripts/rds_ip.sh
```

`rds_ip.sh` は `${path.module}` で参照するため、`ecs` モジュールの中に同梱している。
`data.external` と実 IP を保持する `locals` も、ECS リソースと密結合なので `ecs` モジュールへ入れた。

RDS の識別子を ECS モジュールへ変数として渡すと、その値の依存によって作成順序が保たれる。
以前は `data.external` に `depends_on` を明示していたが、モジュール分割後は値の依存で順序が担保されるため不要になった。

```hcl
module "ecs" {
  source = "./modules/ecs"

  db_identifier = module.rds.identifier  # この依存で RDS 作成後に評価される
  # ... 他の変数
}
```

## まとめ

Floci は LocalStack 互換で、`4566` に向ける基本の使い勝手は変わらない。
一方で、RDS を本物のコンテナで動かすがゆえの癖がある。

- Floci が返す RDS エンドポイント（`address:7001`）は、ホストからプロキシ経由で届くための入口である。
- ポート `7001` は Floci の RDS プロキシレンジ `7001-7099` の先頭で、実体の MySQL は `3306` で待ち受けている。
- ECS コンテナから接続するなら、プロキシではなく RDS コンテナの実 IP + `3306` を使う。
- 実 IP は `docker inspect` で取り、`external` provider の data source 経由で Terraform に注入する。

ローカルエミュレータで「本物のエンジン」を使う構成では、エミュレータが見せる論理的なエンドポイントと、コンテナの実体との間にこうしたずれが生じうる。
接続がうまくいかないときは、報告されたエンドポイントを疑い、実体がどこで待ち受けているかを確かめるとよい。
