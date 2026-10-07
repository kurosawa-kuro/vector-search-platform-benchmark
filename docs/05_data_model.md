# 05 データモデル

## 方針

この文書は backend 固有 schema ではなく、データ準備、embedding、ingest、retrieval、evaluation、reporting の境界を越える論理契約を定義する。物理ファイル形式と実装言語は未確定。

## 論理エンティティ

| エンティティ | 必須データ | 用途 |
|---|---|---|
| DatasetManifest | dataset ID / version、出典、取得日、ライセンス確認状態、subset / 変換条件、件数、integrity ID | Evaluation Corpus の provenance と再生条件 |
| Query | query ID、query text | 検索入力と評価単位 |
| Product | product ID、embedding 対象テキスト、検索対象テキスト、metadata | lexical / semantic / filter 検索対象 |
| RelevanceJudgment | query ID、product ID、relevance label | 検索品質の Ground Truth |
| EmbeddingManifest | artifact ID、model ID / version、dimension、生成設定、source dataset ID、件数、integrity ID | 両 backend で使う embedding の同一性証明 |
| EmbeddingRecord | artifact ID、entity type、source ID、vector | query / product と vector の対応 |
| BackendManifest | backend ID / type、product / service version、topology、index ID、dataset ID、embedding artifact ID、index settings | index と入力 artifact の追跡 |
| BenchmarkScenario | scenario ID / version、backend、retrieval mode、query set、Top-K、filter、load profile、warmup / measurement 条件、infra configuration | 実行前に固定する比較条件 |
| RunManifest | run ID、scenario ID、開始 / 終了時刻、status、code / config revision、参照 artifact IDs、実行環境、error summary | 1回の実験の監査記録 |
| RankedResult | run ID、query ID、product ID、rank、score、retrieval mode | backend 非依存の検索結果 |
| QualityResult | run ID、metric name、cutoff、value、aggregation scope | nDCG / MRR / Recall / Precision の結果 |
| PerformanceSample | run ID、operation、sample / interval、latency、success / failure、throughput | latency、QPS、ingest、index build、update 計測 |
| ResourceSample | run ID、component、timestamp / interval、CPU、memory、heap、disk、network | リソース消費の計測 |
| CostSnapshot | run ID または scenario ID、region、currency、pricing date、unit prices、usage assumptions、monthly / per-1M-query estimate | コスト比較の前提と結果 |
| ReportManifest | report ID、対象 run IDs、生成時刻、生成コード版、output paths | report と raw evidence の対応 |

## ID と同一性

- dataset、embedding、scenario、run、report には安定した ID を付与する。採番方式は実装前に固定する。
- DatasetManifest と EmbeddingManifest は内容同一性を検証できる integrity ID を持つ。
- BackendManifest は参照した dataset ID と embedding artifact ID を必須とする。
- RunManifest は scenario ID と全 artifact ID を固定し、実行後に書き換えない。
- 同一 embedding artifact ID を参照していない Vertex / Elasticsearch run は直接比較できない。

## 検索結果の共通契約

- 品質評価に必要な最小契約は `query ID + product ID + rank` とする。
- score は backend / retrieval mode 間で尺度が異なるため、異なる方式間で直接比較しない。
- Top-K、filter、query set は RankedResult 自体ではなく BenchmarkScenario を正本とする。
- 同一 query で product ID が重複する結果は契約違反とする。

## 評価結果の分離

```text
results/
  raw/          # RankedResult, raw timing, backend response references
  quality/      # nDCG, MRR, Recall, Precision
  performance/  # latency, QPS, build / ingest / update
  resource/     # CPU, memory, heap, disk, network
  cost/         # unit prices, assumptions, estimates
  reports/      # cross-run summaries and condition matrices
```

これは目標論理構成であり、大容量 artifact の物理保存先は未確定。Git には小さな fixture、schema、manifest、要約 report だけを置き、データセット本体、大容量 embedding、raw result は原則コミットしない。

## 設定

| 種別 | 方針 |
|---|---|
| 共通 benchmark 設定 | dataset / embedding / query set / Top-K / load / measurement を versioned config で管理 |
| Backend 設定 | Elasticsearch と Vertex を分離し、共通 scenario から参照 |
| インフラ設定 | Local / GKE / Vertex を分離し、構成とバージョンを run に記録 |
| 一般設定 | `env/config.yaml` または環境変数 |
| ローカル秘密情報 | ignore した `env/secret.yaml` 等のローカルファイル |
| 共有 / クラウド credential | Doppler 等の secret manager |

秘密情報は manifest、result、log、report へ保存しない。

## schema 互換性

- schema には version を付け、producer と consumer の対応を検証する。
- 必須フィールドの削除、意味変更、ID 規則変更は破壊的変更とする。
- 破壊的変更では migration 手順、旧 artifact の扱い、回帰テストを task に定義する。
- 指標の計算式または relevance mapping を変えた場合は、過去の QualityResult をそのまま混ぜず、計算版を分ける。

## 未決事項

物理ファイル形式、ID / integrity ID 方式、ESCI の具体的な field mapping、metadata filter 対象、artifact 保存先、保持期間、スキーマ管理ツールは [benchmark-open-decisions.md](./tasks/02_backlog/benchmark-open-decisions.md) で決定する。

## 関連タスク

- schema、migration、設定、永続化方式の変更は task に目的・移行手順・検証方法を残す。
- 破壊的変更や後方互換が絡む変更は、実装前に `docs/tasks/03_active/` で作業計画を固定する。
- 確定した migration 手順は `docs/runbooks/` または `08_release_runbook.md` へ昇格する。
