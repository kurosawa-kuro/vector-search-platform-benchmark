# 03 ドメインモデル

## ドメインの中心

このプロジェクトの中心は「検索製品」ではなく、同一の評価コーパスと実験条件に対する **Benchmark Run** である。すべての指標と判断は Benchmark Run へ追跡可能でなければならない。

## 用語

| 用語 | 意味 |
|---|---|
| Evaluation Corpus | 評価対象とする versioned な query、product、relevance label の集合 |
| Query | 検索入力。一意な ID とテキストを持つ |
| Product | 検索対象。一意な ID、embedding 対象テキスト、filter 用 metadata を持つ |
| Relevance Label | query-product 間の関連度を表す Ground Truth |
| Dataset Artifact | 出典、版、subset 条件、変換条件を付与した Evaluation Corpus |
| Embedding Artifact | 同一モデルで生成した query / product vector と model provenance の集合 |
| Backend | 検索を実行する基盤。Vertex AI Vector Search または Elasticsearch |
| Backend Index | Backend に投入された、Dataset Artifact と Embedding Artifact の検索可能な表現 |
| Retrieval Mode | BM25、Dense Vector、Hybrid、Hybrid + RRF のいずれか |
| Benchmark Scenario | backend、retrieval mode、Top-K、filter、負荷、インフラ構成、計測条件の組合せ |
| Benchmark Run | 不変な scenario に対する1回の実行とその証跡 |
| Ranked Result | 1 query に対し、product ID、rank、score を持つ検索結果 |
| Quality Metric | relevance label と Ranked Result から算出する nDCG、MRR、Recall、Precision |
| Performance Sample | latency、throughput、index build、ingest、update の計測値 |
| Resource Sample | CPU、memory、JVM heap、vector index memory、disk、network の計測値 |
| Cost Assumption | region、単価、構成、利用量、通貨、計算日などコスト計算の前提 |
| Benchmark Report | 複数 run を品質・性能・リソース・コストの軸で集計した成果物 |
| Decision Boundary | 条件を変えたときに推奨 backend が変わる境界 |
| Architecture Decision | Decision Boundary、根拠、制約、残存リスクをまとめた ADR |

## 関係

```text
Dataset Artifact
  +-- Query
  +-- Product
  +-- Relevance Label (Query <-> Product)
  |
  +-- generated-by --> Embedding Artifact
                         |
                         +-- ingested-into --> Backend Index

Benchmark Scenario
  +-- references --> Dataset Artifact
  +-- references --> Embedding Artifact
  +-- selects ----> Backend / Backend Index / Retrieval Mode
  |
  +-- executed-as -> Benchmark Run
                         |
                         +-- Ranked Results
                         +-- Performance Samples
                         +-- Resource Samples
                         +-- Cost Assumptions
                                      |
                                      v
                              Benchmark Report
                                      |
                                      v
                            Architecture Decision
```

## 不変条件

- Relevance Label は検索 backend の出力ではなく、Evaluation Corpus に属する。
- Embedding Artifact は backend に属さず、同一 artifact を両 backend で利用する。
- Benchmark Scenario は実行中に変更しない。条件を変える場合は別 scenario / run とする。
- Ranked Result は backend 固有レスポンスではなく、共通契約へ正規化する。
- 集計指標は raw result と run metadata から再計算できる。
- 比較表は同じ dataset / embedding / query set / 負荷条件の run だけを直接比較する。

## 状態 / ライフサイクル

### Dataset Artifact

```text
discovered
  -> license-verified
  -> acquired
  -> validated
  -> prepared
  -> versioned

validation failure -> rejected
license uncertainty -> blocked
```

`versioned` に達していない dataset を benchmark へ使わない。

### Backend Index

```text
absent
  -> provisioning
  -> ingesting
  -> validating
  -> ready

provision / ingest failure -> failed
artifact mismatch          -> invalid
```

`ready` かつ artifact 同一性検証済みの index だけを計測に使う。

### Benchmark Run

```text
planned
  -> validating
  -> running
  -> completed
  -> aggregated

validation failure -> invalid
execution failure  -> failed
```

- `invalid`: 公平性やデータ契約を満たさず、比較に使えない。
- `failed`: 実行は妥当だったが、backend / infra / quota 等の失敗で完了していない。
- `completed`: raw result と run metadata の保存まで完了した。
- `aggregated`: 指標の再計算と整合性検証が完了した。

### Architecture Decision

```text
evidence-incomplete
  -> evidence-reviewed
  -> proposed
  -> accepted | superseded
```

単一指標または単一 run だけで `accepted` にしない。

## 関連タスク

- 用語、状態、ライフサイクルの変更は task に背景と影響範囲を残してから反映する。
- 未確定のドメインルールはこの文書へ入れず、`docs/tasks/02_backlog/` で調査対象として管理する。
- 確定したドメイン判断は、必要なら `docs/adr/` にも残す。
