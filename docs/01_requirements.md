# 01 要件

## 目的

公開の一般消費者向け EC 検索データを用い、次の2つの検索基盤を同一条件で比較する。

1. Vertex AI Vector Search
2. GKE Standard + ECK + Elasticsearch

ゴールは単純な ANN 性能の勝敗ではない。検索品質・性能・リソース・コストの4軸で実測し、次の問いに条件付きで答えることである。

> 一般的な EC retrieval において、どの条件なら Vertex AI Vector Search を Elasticsearch on GKE へ統合でき、どの条件なら Managed Vector DB を選ぶべきか。

## 検証仮説

- lexical search、semantic search、metadata filter、reranking を組み合わせる EC 検索では、ANN 性能だけでなく基盤統合による運用コストを含めると、Elasticsearch on GKE が優位になる条件がある。
- 超大規模、高 QPS、厳格な tail latency、高 Recall を求める条件では、Vertex AI Vector Search が優位になる可能性がある。

これらは結論ではなく、反証可能な仮説として扱う。

## ユーザー

- 一次ユーザー: EC 検索基盤の技術選定を行うアーキテクト、エンジニア、技術責任者
- 二次ユーザー: GKE / Elasticsearch の運用担当者、クラウドコストを評価する担当者

## 範囲

### 対象

- Amazon Shopping Queries Dataset / ESCI を用いた一般 EC 検索
- Elasticsearch の BM25 only、Dense Vector only、Hybrid Search、Hybrid + RRF
- Vertex AI Vector Search と Elasticsearch の Dense Vector ANN 比較
- Elasticsearch の HNSW、metadata filter、quantization、shard / replica 構成
- ローカル Kubernetes + ECK による機能確認
- GKE Standard + ECK による性能・リソース・運用性検証
- 検索品質、性能、リソース、コスト / FinOps の比較
- 製品の勝敗ではなく、選定が逆転する境界条件を示す最終 ADR

### 非対象

- 実案件や工業用 EC 検索の再現
- 実案件の商品、query、Ground Truth、特徴量、ログの利用
- 検索モデルや新しい embedding model の研究・開発
- LLM 検索エージェント、UI / EC サイト、Recommendation Engine の開発
- Elasticsearch の全機能網羅
- 初回マイルストーンでの GKE または Vertex AI Vector Search の構築・比較

## 機能要件

| ID | 要件 |
|---|---|
| FR-001 | ESCI を再現可能な手順で取得・前処理できること |
| FR-002 | query、product、relevance label を読み込み、評価に利用できること |
| FR-003 | 比較対象の両基盤に同一の product embedding と query embedding を入力できること |
| FR-004 | 同一 query に対し、BM25、Dense Vector、Hybrid、Hybrid + RRF を実行できること |
| FR-005 | nDCG@10、MRR、Recall@10、Recall@100、Precision@10 を算出できること |
| FR-006 | p50 / p95 / p99 latency、QPS、index build time、ingest throughput、update latency を計測できること |
| FR-007 | CPU、memory、JVM heap、vector index memory、disk usage、network を実験条件と紐付けて記録できること |
| FR-008 | Vertex、GKE node、Persistent Disk、Elasticsearch 構成、replica、RAM の費用前提を記録し、月額と1M query あたりの概算を比較できること |
| FR-009 | raw result、実験設定、バージョン、コスト前提を保存し、同条件の実験を再実行できること |
| FR-010 | 検索品質、性能、リソース、コストを分離したレポートと、統合した選定条件表を作成できること |

## 制約と不変条件

- 公開データのみを利用する。
- データセット本体は原則 Git にコミットせず、取得・前処理コードと手順を管理する。
- 利用前にデータの配布条件とライセンスを確認し、README に記録する。
- Vertex と Elasticsearch で同一 dataset、query、embedding、評価条件を使い、embedding model の差を基盤性能差に混入させない。
- Elasticsearch は Vector-only で結論を出さず、BM25、filter、Hybrid Search、RRF を含めて評価する。
- 性能数値は実行環境、バージョン、設定、負荷条件と紐付け、条件の異なる数値を直接比較しない。
- ライセンス条件の異なる機能（DiskBBQ 等）は基本比較から分離する。

## ユースケース

| ID | ユースケース | 成功条件 |
|---|---|---|
| UC-001 | 公開 ESCI データから評価コーパスを再構築する | 取得・前処理手順から query / product / relevance が再生され、データ契約検証を通過する |
| UC-002 | 共通 embedding を生成し、比較基盤へ投入する | 両基盤で同一 model / version / dimension / source ID の embedding を使っていることを追跡できる |
| UC-003 | Local ECK で4つの検索方式を評価する | 同一 query で BM25 / Vector / Hybrid / RRF を実行し、relevance label から品質指標を算出できる |
| UC-004 | GKE 上の Elasticsearch 構成を比較する | 構成別の品質・性能・リソース・障害時挙動を記録できる |
| UC-005 | Vertex と Elasticsearch を公平に比較する | 同一 dataset / query / embedding に対する品質、latency、QPS、コストが比較表にまとまる |
| UC-006 | 検索基盤の選定を判断する | Vertex が優位な条件、Elasticsearch が優位な条件、判断保留条件を ADR に示せる |

## Critical User Journey / Golden Path

- 一次ユーザー: EC 検索基盤の技術選定者
- 完了状態: 追跡可能な実験証跡から、条件付きの選定 ADR を説明できる

| # | ステップ | 成功条件（観測可能な状態） |
|---|---|---|
| 1 | ESCI を取得・前処理する | データの出典・ライセンス・変換条件と query / product / relevance が追跡できる |
| 2 | 共通 embedding を生成する | model / version / dimension / source ID 付きの embedding artifact が生成される |
| 3 | 比較基盤を構築し、同一コーパスを index する | 対象 backend が ready で、対象件数と embedding の同一性を検証できる |
| 4 | 検索・負荷シナリオを実行する | 方式別の ranked result、latency、throughput、エラーが run ID に紐付く |
| 5 | 品質・性能・リソース・コストを集計する | 条件と raw result から各指標を再計算できる |
| 6 | 選定条件を ADR にまとめる | 境界条件、根拠、制約、残存リスクが記録される |

Golden Path の構成要素への写像は [02_architecture.md](./02_architecture.md)、フェーズごとの検証は [07_test_strategy.md](./07_test_strategy.md)、公開時の smoke は [08_release_runbook.md](./08_release_runbook.md) に定義する。

## 成功条件

次の問いを、実験証跡と条件付きで説明できること。

1. Vertex AI Vector Search が優位になる条件
2. Elasticsearch が優位になる条件
3. HNSW / quantization の性能・コスト特性
4. Kubernetes に Vector DB を載せる運用コスト
5. Hybrid Search による検索品質改善量
6. Elasticsearch への基盤統合で削減できる構成要素
7. Managed Vector DB を選択すべき規模・SLO・運用条件

## 初回マイルストーン

ESCI subset の取得から、共通 embedding、Local Kubernetes + ECK + Elasticsearch、4つの検索方式、nDCG / MRR / Recall 計測までを再現可能に通す。この完了まで GKE と Vertex AI Vector Search の実装に進まない。

## 未決事項

embedding model、ESCI subset、実装言語、ローカル Kubernetes runtime、製品バージョン、負荷条件、費用前提、各フェーズの数値閾値は未確定。[benchmark-open-decisions.md](./tasks/02_backlog/benchmark-open-decisions.md) で根拠とともに決定する。

## 関連タスク

- 要件追加・変更は、まず `docs/tasks/03_active/` または `docs/tasks/02_backlog/` に task として記録する。
- 確定した要件だけをこの文書へ反映する。
- 要件変更に伴う未実装作業は `docs/tasks/README.md` から追跡できる状態にする。
