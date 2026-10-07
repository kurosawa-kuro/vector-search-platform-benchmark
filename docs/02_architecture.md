# 02 アーキテクチャ

## 概要

共通の ESCI コーパスと embedding artifact を基準に、backend 固有の ingest / retrieval adapter を通して Vertex AI Vector Search と Elasticsearch を実行する。結果は共通形式に正規化し、品質・性能・リソース・コストを独立に集計した後、選定条件表と ADR へ統合する。

```text
Amazon ESCI
  -> Dataset preparation / relevance parsing
  -> Common embedding generation
  -> Versioned dataset + embedding artifacts
       |                              |
       v                              v
  Vertex adapter                Elasticsearch adapter
  Vertex AI Vector Search       Local K8s or GKE + ECK
       |                              |
       +----------> normalized ranked results
                              + performance samples
                              + resource samples
                              + cost assumptions
                                   |
                                   v
                         Evaluation / aggregation
                                   |
                                   v
                     Reports / condition matrix / ADR
```

編集可能な同内容の図: [図版/アーキテクチャ全体.drawio](./図版/アーキテクチャ全体.drawio)（draw.io MCP で編集。上の text 図と内容を一致させる）

## 設計原則

1. **公平な入力**: 同一 dataset、query、embedding、評価条件を両 backend で使う。
2. **共通契約と backend 分離**: 共通データ契約と評価ロジックに provider 固有 API を漏らさない。
3. **raw-first**: 集計値だけでなく、再計算できる raw result と run metadata を残す。
4. **段階的な複雑性導入**: データと評価契約を先に固定し、Local ECK、GKE、Vertex の順に進む。
5. **数値と条件の一体管理**: 全指標を dataset / embedding / backend / version / topology / load / cost 条件と紐付ける。

## 構成要素

担当パスは目標構成。未作成パスは、対応フェーズの task で作成する。

| 構成要素 | 責務 | 担当パス |
|---|---|---|
| Dataset preparation | ESCI 取得、subset 作成、schema 検証、query / product / relevance 変換 | `src/dataset/`, `scripts/` |
| Embedding generation | product / query の共通 embedding 生成と provenance 付与 | `src/embedding/` |
| Ingest adapters | 共通コーパスを backend 固有 index へ投入 | `src/ingest/` |
| Retrieval adapters | BM25 / Vector / Hybrid / RRF の実行と結果正規化 | `src/retrieval/` |
| Evaluator | relevance label と ranked result から品質指標を算出 | `src/evaluation/` |
| Benchmark runner | scenario 検証、実行順制御、計測、run metadata 保存 | `src/benchmark/` |
| Backend configuration | Elasticsearch / Vertex 固有設定を共通コードから分離 | `configs/elastic/`, `configs/vertex/` |
| Local infrastructure | Local Kubernetes、ECK、Elasticsearch、PVC、TLS | `infra/local/` |
| GKE infrastructure | GKE Standard、node pool、storage、ECK、Elasticsearch | `infra/gke/` |
| Vertex infrastructure | Vertex AI Vector Search のリソースと設定 | `infra/vertex/` |
| Result store | raw result と quality / performance / resource / cost 集計を分離保存 | `results/` |
| エージェントガイド | Codex / 他エージェント向けの repo ガイド | `AGENTS.md` |
| Claude ガイド | Claude Code の司令ルール | `CLAUDE.md` |
| タスク文書 | 一回性の作業計画・実装タスク | `docs/tasks/` |
| Claude skills | Claude Code で繰り返し使う作業手順 | `.claude/skills/` |
| 図版 | この章の構成・フローを図で表現（draw.io MCP で編集） | `docs/図版/` |

## 実行トポロジ

### Local ECK

```text
Local machine
  -> Local Kubernetes runtime
       -> ECK Operator
            -> Elasticsearch
                 -> BM25 / dense_vector / kNN / filter / Hybrid / RRF
```

機能と評価パイプラインの確認用。本格的な cloud 性能比較には使わない。

### GKE Standard + ECK

```text
GKE Standard
  -> Node pool / Persistent Disk
  -> ECK Operator
       -> Elasticsearch cluster
            -> HNSW / quantization / shard / replica
```

CPU / memory / JVM heap / disk / network と、node drain、Pod restart、rolling update を含む Kubernetes 運用性の検証用。

### Vertex AI Vector Search

```text
Common embedding artifacts
  -> Vertex ingest adapter
  -> Vertex AI Vector Search
  -> normalized ranked results
```

Managed Dense Vector ANN の比較基準。BM25 / Hybrid / RRF は Elasticsearch 側の統合価値として別軸で扱う。

## 検索実行フロー

| 方式 | フロー |
|---|---|
| BM25 | query → Elasticsearch BM25 → ranked Top-K |
| Dense Vector | query → common query embedding → backend ANN → ranked Top-K |
| Hybrid | BM25 candidates + Vector candidates → fusion → ranked Top-K |
| Hybrid + RRF | BM25 candidates + Vector candidates → RRF → ranked Top-K |

## 成長フェーズ

| Phase | アーキテクチャ上の変化 | 完了境界 |
|---|---|---|
| 0: Dataset / Evaluation Foundation | dataset、embedding、relevance、evaluator の契約を固定 | Kubernetes に進まず、データ準備と指標算出が再実行できる |
| 1: Local Kubernetes + ECK | Local ECK、Elasticsearch adapter、4 retrieval modes を追加 | 同一 query の4方式と品質計測を end-to-end で実行できる |
| 2: GKE Standard + ECK | Local topology を GKE へ移植し、リソース / 障害計測を追加 | 構成差と運用イベントの影響を記録できる |
| 3: Vertex Comparison | Vertex adapter と共通 comparison runner を追加 | 公平性検証を通過した横断比較を実行できる |
| 4: Architecture Decision | 集計結果を条件表と ADR へ統合 | 優劣が逆転する境界と残存リスクを説明できる |

## Golden Path とアーキテクチャ

| Golden Path ステップ | 通る構成要素 | 主な境界 / データ | 停止条件 |
|---|---|---|---|
| 1. ESCI 準備 | Dataset preparation | 外部配布元 → versioned dataset artifact | ライセンス未確認、schema 不整合、relevance 欠落 |
| 2. Embedding 生成 | Embedding generation | dataset IDs → versioned embedding artifact | model provenance 欠落、次元不一致、source ID 欠落 |
| 3. Index 準備 | Ingest adapters / backend infrastructure | common artifact → provider-specific index | 件数不一致、backend 非 ready、異なる embedding |
| 4. 検索・負荷実行 | Benchmark runner / retrieval adapters | common scenario → normalized result | scenario 不整合、異なる Top-K / filter / load 条件 |
| 5. 集計 | Evaluator / result store | raw results → metrics / reports | raw result 欠落、計算不能、条件 provenance 欠落 |
| 6. 判断 | Reports / ADR | evidence → condition matrix / ADR | 証跡不足、前提非明記、単一指標のみの結論 |

## 境界

- データ取得・変換と検索 backend を分離し、外部データ形式を backend adapter へ直接漏らさない。
- embedding 生成と ANN 検索を分離し、各 backend 内で独自 embedding を生成しない。
- 品質評価は provider に依存せず、正規化した ranked result と relevance label のみに依存する。
- ベンチマーク制御とインフラ構築を分離し、シナリオから管理 API の詳細を隠蔽する。
- non-secret 設定は version control 対象にし、ローカル秘密情報は ignore し、共有・本番 credential は secret manager で管理する。
- データセット本体、大容量 embedding、raw benchmark output は原則 Git にコミットしない。保存先と保持期間は実装前に決定する。
- Codex が `.claude/rules/` や `.claude/skills/` を読む前提にしない。共通指針は `AGENTS.md` に置く。

## 未決の設計選択

実装言語 / runtime、local Kubernetes runtime、embedding model、artifact 保存形式、製品バージョン、GKE topology、計測ツールは未確定。[benchmark-open-decisions.md](./tasks/02_backlog/benchmark-open-decisions.md) で決定し、非自明な選択は `docs/adr/` に根拠を残す。

## 関連タスク

- 構造変更、責務移動、adapter 追加、共通化は、実装前に `docs/tasks/03_active/` へ task を作る。
- 中規模以上の変更では、task に Skeleton / Plan / Acceptance Criteria を書いてから実装する。
- 確定した設計判断は task から `docs/adr/` またはこの文書へ昇格する。
