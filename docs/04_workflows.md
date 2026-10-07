# 04 ワークフロー

## 現在の実行状態

`src/` とベンチマーク用の `make setup`、`make run`、`make test` 等はスケルトン。Local Kubernetes + ECK 基盤だけは `infra/local/` と `make local-*` に実装済みで、Elasticsearch API smoke まで再実行できる。

## 作業開始

```bash
git status --short
```

1. [tasks/README.md](./tasks/README.md) と `docs/tasks/04_verifying/` を確認する。
2. `docs/tasks/03_active/` から今回の task を1つ選ぶ。
3. Goal / Scope / Acceptance Criteria / Verification と、対象 Phase を確認する。
4. [benchmark-open-decisions.md](./tasks/02_backlog/benchmark-open-decisions.md) の未決値に依存する場合は、根拠と決定を先に残す。
5. 仕様・設計変更がある場合は、実装と同じ変更で `docs/01〜08` を更新する。

## フェーズ順序

```text
Phase 0: Dataset / Evaluation Foundation
  -> Phase 1: Local Kubernetes + ECK
  -> Phase 2: GKE Standard + ECK
  -> Phase 3: Vertex AI Vector Search Comparison
  -> Phase 4: Architecture Decision
```

前 Phase の完了ゲートを通過するまで次へ進まない。初回マイルストーンは Phase 1 までとし、GKE と Vertex には触らない。フェーズ別の品質ゲートは [07_test_strategy.md](./07_test_strategy.md) を正本とする。

## Phase 0: Dataset / Evaluation Foundation

### 前提

- ESCI の配布条件・ライセンスが確認済み。
- dataset version / subset 条件、embedding model、relevance mapping、指標定義が固定されている。
- データ取得先と大容量 artifact の保存先が Git 管理対象外になっている。

### 手順

1. ESCI を取得し、出典、取得日、版、整合性情報を DatasetManifest に記録する。
2. query / product / relevance label を共通 schema へ変換する。
3. 件数、ID 参照整合性、必須値、relevance の対応を検証する。
4. 同一の固定済み subset から query / product embedding を生成する。
5. model / version / dimension / source dataset / 生成設定を EmbeddingManifest に記録する。
6. 小さな fixture で nDCG / MRR / Recall / Precision evaluator の手計算値と一致することを確認する。
7. 同一入力から artifact を再生できる証跡を残す。

## Phase 1: Local Kubernetes + ECK

### ローカル基盤コマンド

版の正本は `infra/local/versions.env`。`local-up` は固定 kind の取得、preflight、専用 cluster 作成、ECK / Elasticsearch 適用、TLS / authenticated API smoke を順に実行する。

```bash
make local-preflight
make local-up
make local-status
make local-smoke
make local-verify-recovery
```

- 対象 context は `kind-vector-search-benchmark` に固定し、変更操作前に current context と cluster 名を検証する。
- 1-node 開発環境では replica を配置できないため、smoke は既存 local index の replica 数を0へ正規化し、settle window 後も health `green` であることを確認する。この設定を GKE / performance scenario へ流用しない。
- `local-verify-recovery` は marker を投入済みの状態で Elasticsearch Pod を再作成し、Pod UID の変更、同じ PVC の `Bound`、marker の存続、health `green` を検証する。
- cluster を破棄する場合だけ `make local-down` を使う。対象一覧を表示してから専用 cluster を削除し、cluster / context / node container の残存ゼロを確認する。

### 前提

- Phase 0 の dataset / embedding artifact と evaluator がゲートを通過している。
- Local Kubernetes runtime、ECK / Elasticsearch バージョン、subset、index settings が scenario に固定されている。

### 手順

1. `make local-up` で Local Kubernetes、ECK Operator、Elasticsearch を構築する。
2. `make local-status` と `make local-smoke` で CRD、PVC、Secret / TLS、authenticated API、cluster ready / green を確認する。
3. common product / embedding artifact を index し、件数と embedding provenance を検証する。
4. 同一 query set で BM25、Vector、Hybrid、Hybrid + RRF を実行する。
5. ranked result を共通契約へ正規化し、quality metrics を算出する。
6. run metadata、raw result、ログ、検証結果を保存する。

Phase 1 ではパイプラインの正しさと再現性を優先し、クラウドの本格性能結論を出さない。

## Phase 2: GKE Standard + ECK

### 手順

1. Phase 1 の manifest / adapter / scenario 契約を変えず GKE Standard へ移植する。
2. node pool、requests / limits、JVM heap、shard、replica、PVC、HNSW、quantization 条件を scenario ごとに固定する。
3. scenario 実行前に cluster health、index count、artifact 同一性を検証する。
4. warmup と measurement を分けて負荷を実行し、latency / QPS と resource samples を同じ run ID に紐付ける。
5. node drain、Pod restart、rolling update を定義済みシナリオで実行し、回復時間とエラーを記録する。
6. GKE node / Persistent Disk / Elasticsearch 構成のコスト前提を保存する。

クラウド課金を伴う作成・破棄は、対象 project / region / resource と実行者の権限を明示確認してから行う。

## Phase 3: Vertex AI Vector Search Comparison

1. Phase 2 と同じ dataset / query / embedding artifact を Vertex 側に ingest する。
2. Top-K、filter、query set、warmup / measurement 条件の同一性を比較前ゲートで検証する。
3. Dense Vector scenario を実行し、ranked result、latency、QPS、error を共通形式で保存する。
4. Vertex の費用前提を GKE 側と同じ pricing date / currency / usage model で記録する。
5. Dense Vector 同士の直接比較と、Elasticsearch の BM25 / Hybrid / RRF を含む統合価値を区別して report する。

## Phase 4: Architecture Decision

1. 各 report の対象 run、除外 run、前提、制約を確認する。
2. 検索品質、tail latency / QPS、リソース、コスト、運用複雑性を別々に評価する。
3. Elasticsearch 優位、Vertex 優位、判断保留の条件表を作る。
4. 優劣が逆転する Decision Boundary、根拠 run、残存リスクを最終 ADR に記録する。

## 1回の Benchmark Run

1. scenario を読み込み、必須値と参照 artifact を検証する。
2. backend / index の ready、件数、dataset / embedding ID の一致を確認する。
3. RunManifest を `planned` から `validating` へ進め、code / config / infra version を固定する。
4. warmup を行い、warmup result を本計測から分離する。
5. measurement を実行し、result / performance / resource / error を run ID に紐付ける。
6. raw artifact を保存し、RunManifest を `completed` または `failed` / `invalid` にする。
7. `completed` run のみを集計し、再計算検証後に `aggregated` にする。

## 作業終了

```bash
git diff --check
git status --short
```

- 実行した検証、結果、実行できなかった項目、残リスクを task の `Verification` に残す。
- 未決事項は `docs/tasks/02_backlog/` へ移し、仕様値として推測で埋めない。
- 確定した仕様・設計・運用手順・判断は docs 本体、runbook、ADR へ昇格する。
- 実装と基本検証が済み、外部の terminal signal のみを待つ場合に限って task を `04_verifying/` へ移す。
