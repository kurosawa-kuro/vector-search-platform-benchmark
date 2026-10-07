# 08 リリース Runbook

## このプロジェクトにおけるリリース

本プロジェクトのリリースは、単一アプリケーションの本番デプロイに限らない。次の成果物を、追跡可能な版と証跡付きでフェーズ開放または公開することを指す。

| リリース単位 | 内容 |
|---|---|
| Evaluation Foundation | dataset preparation、schema、embedding provenance、metric evaluator |
| Local ECK Benchmark | Local Kubernetes + ECK + Elasticsearch の E2E 証跡 |
| GKE Benchmark Environment | GKE / ECK / Elasticsearch の versioned manifests と benchmark evidence |
| Vertex Comparison | 同一条件の Vertex / Elasticsearch 比較結果 |
| Decision Package | quality / performance / resource / cost reports、条件表、最終 ADR |

## フェーズ促進条件

- Phase 0 から 1: dataset / embedding / evaluator の contract と再現手順が確立している。
- Phase 1 から 2: Local ECK で Golden Path が通り、4 retrieval modes の quality result を再生できる。
- Phase 2 から 3: GKE の実験環境、負荷条件、resource / cost 収集が固定されている。
- Phase 3 から 4: Vertex / Elasticsearch の Benchmark Validity Gate が通り、比較可能な run が揃っている。
- Phase 4 完了: 掲載値が raw evidence へ追跡でき、制約と残存リスクを含む ADR がレビュ済み。

## リリース前

1. リリース対象と Phase、code / config / manifest / schema の版を固定する。
2. `docs/tasks/03_active/` と `docs/tasks/04_verifying/` に、対象リリースを止める未完了 task が無いことを確認する。
3. リリース対象 task の `Verification` と [07_test_strategy.md](./07_test_strategy.md) の対象フェーズゲートを確認する。
4. schema / artifact の互換性、migration の要否、旧 artifact の扱いを確認する。
5. クラウドリソースを含む場合は project、region、resource names、概算費用、作成 / 破棄権限を確認する。
6. secret scan と、manifest / log / result / report が credential を含まないことの確認を行う。
7. 公開 report で failed / invalid / excluded run、制約、pricing date が開示されていることを確認する。

実行 runtime と release tooling が未確定のため、コマンドはまだ定義しない。ツール実装時に、この runbook に実在するコマンドと期待結果を追加する。

## デプロイ / リリース

### Local ECK

1. 対象の Local Kubernetes runtime と利用可能リソースを確認する。
2. 固定済み ECK / Elasticsearch manifest を適用する。
3. cluster / PVC / TLS の ready を確認する。
4. versioned dataset / embedding artifact を ingest し、BackendManifest を検証する。
5. デプロイ後 smoke を実行する。

### GKE Standard + ECK

1. GCP project / region、billing、quota、credential、概算費用を明示確認する。
2. versioned infrastructure definition から GKE / node pool / storage / ECK を構築する。
3. cluster、Elasticsearch、storage、observability collector の ready を確認する。
4. artifact を ingest し、件数と provenance を検証する。
5. smoke 通過後にだけ benchmark run を許可する。

### Vertex AI Vector Search

1. GCP project / region、billing、quota、credential、概算費用を明示確認する。
2. versioned configuration から対象リソースを構築する。
3. GKE / Elasticsearch と同じ embedding artifact を ingest する。
4. index / endpoint の ready と件数を確認する。
5. smoke 通過後にだけ comparison run を許可する。

## デプロイ後 smoke（Golden Path）

| # | Golden Path ステップ | 確認方法 | 期待する観測結果 |
|---|---|---|---|
| 1 | ESCI 準備 | DatasetManifest と contract validation を確認 | 出典・版・subset・件数が固定され、query / product / relevance が整合 |
| 2 | Embedding 生成 | EmbeddingManifest と ID 対応を確認 | model / version / dimension / source dataset が追跡可能で欠落 ID が無い |
| 3 | Index 準備 | backend health、index count、BackendManifest を確認 | backend が ready で dataset / embedding ID と件数が一致 |
| 4 | 検索実行 | 小さな固定 query set で対象 retrieval mode を実行 | エラーなく共通 RankedResult が生成される |
| 5 | 評価 | smoke run の raw result から quality metric を再計算 | metric が生成され、raw result と一致 |
| 6 | 追跡 | RunManifest から全 artifact / config / version を追跡 | 欠落参照なく run を再現する入力が特定できる |

個別 health check だけが緑でも、この一本が通らなければリリース失敗とする。

## ロールバックトリガー

- smoke のいずれかのステップが期待状態へ到達しない。
- dataset / embedding / index の artifact ID または件数が一致しない。
- schema 非互換、指標回帰、秘密情報の露出が検出される。
- 想定外の課金、resource 増加、quota 消費が観測される。
- バージョン更新後に旧 scenario を再実行できない。

## ロールバック

1. 新規 benchmark run を停止し、失敗時点の manifest / log / event を保存する。
2. 失敗 run を `failed` または `invalid` にし、公開比較対象から除外する。
3. code / config / manifest を直前の検証済み版へ戻す。schema 変更を含む場合は定義済み migration / restore 手順を使う。
4. 破壊または課金を伴う cloud resource 操作は、対象を読み取りで特定し、owner 確認と保存対象の退避後に行う。
5. 旧版で smoke を再実行し、Golden Path の回復を観測する。
6. 原因、影響範囲、ロールバック証跡、回帰防止 task を記録する。

保存形式、クラウドごとの実コマンド、削除保護、backup / restore の詳細は実装後に `docs/runbooks/` へ追加する。

## リリース後

- report / ADR から raw evidence、run IDs、config、pricing date へのリンクを確認する。
- 作成した cloud resource の保持 / 破棄方針と課金継続の有無を記録する。
- 異常、除外 run、未解決事項を `docs/tasks/03_active/` または `docs/tasks/02_backlog/` に残す。
- 恒久的な運用手順は `docs/runbooks/`、設計判断は `docs/adr/` へ昇格する。
