# Vector Search Platform Benchmark

> Vertex AI Vector Search vs Elasticsearch on GKE for E-commerce Retrieval

公開の一般 EC 検索データを用い、Vertex AI Vector Search と GKE Standard + ECK + Elasticsearch を、検索品質・性能・リソース・コストの4軸で比較するベンチマークプロジェクトです。

目的は、単純な ANN 性能の勝敗を決めることではありません。次のアーキテクチャ選定問題に、実測値で答えることを目指します。

> **When should Elasticsearch on GKE replace Vertex AI Vector Search for e-commerce retrieval?**

## ステータス

現在は計画・評価基盤の準備段階です。要件と基礎設計は `docs/01_requirements.md`〜`docs/08_release_runbook.md` に整理済みですが、ベンチマーク本体と実行可能なセットアップはまだ実装されていません。

- 現行仕様・設計: [docs/00_index.md](docs/00_index.md)
- 蒸留前の構想（参考資料）: [vector-search-platform-benchmark-brainstorm.md](docs/archive/vector-search-platform-benchmark-brainstorm.md)
- 未決のベンチマーク条件: [benchmark-open-decisions.md](docs/tasks/02_backlog/benchmark-open-decisions.md)
- 実行中タスク: [docs/tasks/README.md](docs/tasks/README.md)

構想に含まれていた候補と未決値は、現行仕様と混ぜず archive と backlog で管理します。確定した判断は `docs/adr/` へ昇格します。

## 比較対象

| 基盤 | 役割 | 主な検証対象 |
|---|---|---|
| Vertex AI Vector Search | Managed Dense Vector ANN の基準点 | 検索品質、latency、QPS、運用性、コスト |
| GKE Standard + ECK + Elasticsearch | Kubernetes 上の統合検索基盤 | BM25、Dense Vector、HNSW、filter、Hybrid Search、RRF、quantization |

Elasticsearch は Vector Search 単体ではなく、lexical retrieval と semantic retrieval を組み合わせられる基盤として評価します。

## データセット

[Amazon Shopping Queries Dataset / ESCI](https://github.com/amazon-science/esci-data) の利用を計画しています。query-product の関連度ラベルを使い、BM25、Vector、Hybrid、RRF の検索品質を同じデータ上で評価します。

データ取り扱いの原則:

- 公開データのみを使用する。
- 実案件の商品、query、Ground Truth、特徴量、ログは使用しない。
- データセット本体は原則として Git にコミットしない。
- 再現可能な取得・前処理スクリプトと手順を管理する。
- 使用前に配布条件とライセンスを確認し、README に記録する。

## 評価設計

### 検索方式

1. Elasticsearch BM25 only
2. Vertex / Elasticsearch Dense Vector only
3. Elasticsearch Hybrid Search
4. Elasticsearch Hybrid + RRF

### 評価軸

| 軸 | 主な指標 |
|---|---|
| 検索品質 | nDCG@10、MRR、Recall@10 / @100、Precision@10 |
| 性能 | p50 / p95 / p99 latency、QPS、index build time、ingest throughput、update latency |
| リソース | CPU、memory、JVM heap、vector index memory、disk、network |
| コスト / FinOps | 月額、1M query あたりコスト、replica / RAM 増加の費用対効果、運用複雑性 |

## 比較の不変条件

- Vertex と Elasticsearch で同一の dataset、query、embedding、評価条件を使う。
- embedding model の差を Vector DB の性能差に混入させない。
- ANN の latency / QPS だけで結論を出さない。
- raw result、設定、製品バージョン、コスト前提を保存し、ベンチマークを再実行可能にする。

## 実装フェーズ

| Phase | 目的 |
|---|---|
| 0: Dataset / Evaluation Foundation | ESCI の取得・schema・loader・relevance parser・品質評価基盤を固定する |
| 1: Local Kubernetes + ECK | subset で BM25 / Vector / Hybrid / RRF から品質評価までを再現可能にする |
| 2: GKE Standard + ECK | リソース構成、shard / replica、障害、rolling update、quantization を検証する |
| 3: Vertex AI Vector Search | 同一 dataset / embedding / query で Elasticsearch と比較する |
| 4: Architecture Decision | 製品の勝敗ではなく、選定が逆転する境界条件を ADR にする |

### 初回実装スコープ

初回スプリントでは Phase 1 までに集中します。

```text
Amazon ESCI subset
  -> Embedding generation
  -> Local Kubernetes
  -> ECK + Elasticsearch
  -> BM25 / Vector / Hybrid / RRF
  -> nDCG / MRR / Recall
```

**GKE と Vertex AI Vector Search は初回スプリントでは対象外です。** 検索ロジック、Kubernetes、クラウド比較を同時にデバッグする状態を避けます。

## 想定成果物

- 再現可能な ESCI データ準備処理
- Local Kubernetes / GKE 上の ECK + Elasticsearch
- Vertex AI Vector Search 構成
- 共通 embedding と benchmark runner
- 検索品質、latency / QPS、リソース、コストの各レポート
- Vertex が優位になる条件と Elasticsearch が優位になる条件を示す最終 ADR

## 非ゴール

- 実案件や工業用 EC の再現
- 検索モデルや embedding model 自体の研究・開発
- LLM 検索エージェント、EC UI、Recommendation Engine の構築
- Elasticsearch の全機能網羅

## セットアップ

現在の `Makefile` はスケルトンで、`setup`、`build`、`run`、`test` などの target に実コマンドはまだ定義されていません。Phase 0 で実行環境と依存関係を固定した後、この節と [docs/04_workflows.md](docs/04_workflows.md) に再現可能な手順を追加します。

設定値は `env/config.yaml`（非機密）、`env/secret.yaml`（ローカル機密情報・コミット禁止）、Doppler（チーム共有・本番機密情報）で管理します。

## ドキュメント

- [docs/01_requirements.md](docs/01_requirements.md) — 確定した目的、スコープ、ユースケースの反映先
- [docs/02_architecture.md](docs/02_architecture.md) — 確定した構成、境界、設計判断の反映先
- [docs/04_workflows.md](docs/04_workflows.md) — セットアップ、検証、運用フロー
- [docs/07_test_strategy.md](docs/07_test_strategy.md) — テスト方針と品質ゲート
- [AGENTS.md](AGENTS.md) — Codex などの AI コーディングエージェント共通ガイド
- [CLAUDE.md](CLAUDE.md) — Claude Code 用ガイド
