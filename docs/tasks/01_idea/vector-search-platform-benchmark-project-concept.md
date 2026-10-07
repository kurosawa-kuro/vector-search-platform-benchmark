# Vector Search Platform Benchmark

## 0. 推奨するプロジェクト名・リポジトリ名

### 第一候補（推奨）

- **プロジェクト名**: Vector Search Platform Benchmark
- **サブタイトル**: Vertex AI Vector Search vs Elasticsearch on GKE for E-commerce Retrieval
- **Repository**: `vector-search-platform-benchmark`

### この名前を推す理由

- Elastic 側・Vertex 側のどちらにも結論を寄せず、比較検証プロジェクトとして中立。
- 今後、Pinecone / OpenSearch / AlloyDB / Agent Retrieval 等を追加しても名前を変えずに拡張できる。
- 「Elasticsearchを触ったPoC」ではなく、**検索基盤の技術選定を定量比較するプロジェクト**だと伝わる。
- GKE、ECK、Vertex AI、検索品質、FinOps を1つのテーマにまとめやすい。

### 代替案

| 優先 | Project | Repository | 特徴 |
|---|---|---|---|
| 1 | Vector Search Platform Benchmark | `vector-search-platform-benchmark` | 最も中立で長期利用しやすい |
| 2 | GKE Vector Search Benchmark | `gke-vector-search-benchmark` | Kubernetes / GKE色を強く出せる |
| 3 | Elastic vs Vertex Search Lab | `elastic-vs-vertex-search-lab` | 目的が一目で伝わるが将来拡張に弱い |
| 4 | E-commerce Retrieval Benchmark | `ecommerce-retrieval-benchmark` | 検索品質を前面に出せるがK8s色が薄い |

**採用推奨:** `vector-search-platform-benchmark`

---

# 1. プロジェクト概要

公開されている一般消費者向けEC検索データを用い、以下の2つの検索基盤を同一条件で比較する。

1. **Vertex AI Vector Search**
2. **GKE Standard + ECK + Elasticsearch Vector Search**

目的は、単純なANN性能比較ではない。

> **一般的なEC検索において、どの条件なら Vertex AI Vector Search を Elasticsearch on GKE に集約できるのかを、検索品質・性能・運用・コストの4軸で検証する。**

Elasticsearchについては、Vector Search単体だけでなく、本来の強みであるBM25・filter・Hybrid Search・RRFまで評価対象とする。

---

# 2. 背景仮説

2026年時点のElasticsearchは、従来の全文検索エンジンにVector Searchを追加しただけの製品ではなく、Vector DBとして利用可能な水準まで進化している。

特にKubernetes / Elasticsearch運用能力を既に持つ組織では、専用Vector DBを別基盤として保有するよりも、GKE + ECK + Elasticsearchへ検索基盤を集約できる可能性がある。

検証したい中心仮説は次の通り。

> **EC検索のように lexical search、semantic search、metadata filter、reranking を組み合わせる用途では、純粋なANN性能だけでなく、基盤統合による運用コスト削減を含めると Elasticsearch on GKE が優位になる条件が存在する。**

一方で、超大規模・高QPS・厳格なtail latency・高Recallが要求される場合は、Vertex AI Vector Searchが優位である可能性を残す。

---

# 3. データセット方針

## 採用データ

**Amazon Shopping Queries Dataset / ESCI** を使用する。

工業用・商業用ECの実案件データは使用しない。

### 採用理由

- 一般消費者向けECであり、実案件データを持ち込む必要がない。
- query-product の関連度ラベルを利用できるため、検索品質を定量評価できる。
- Vector Searchだけではなく、BM25 / Hybrid Search / RRF の比較に適している。
- 将来的に言語別評価へ拡張できる。
- 検索基盤の性能評価と検索品質評価を同じデータセット上でつなげられる。

## データ取扱方針

- 公開データのみ利用する。
- 実案件の商品、検索query、Ground Truth、特徴量、ログは一切利用しない。
- データセット本体は原則としてGitリポジトリへコミットしない。
- 取得スクリプトまたはセットアップ手順のみ管理する。
- 利用前に配布条件・ライセンスをREADMEへ明記する。

---

# 4. 比較対象

## A. Vertex AI Vector Search

役割:

- Dense Vector ANNの基準点
- Google-managed Vector Searchとしての性能・運用性を測る
- ElasticsearchをGKEで自前運用する場合との比較対象

## B. Elasticsearch on GKE

構成:

```text
GKE Standard
  |
  +-- ECK Operator
        |
        +-- Elasticsearch
              +-- BM25
              +-- Dense Vector Search
              +-- HNSW
              +-- Quantization
              +-- Metadata Filter
              +-- Hybrid Search
              +-- RRF
```

検証候補:

- HNSW
- int8系量子化
- BBQ系量子化
- shard / replica構成
- CPU / memory構成
- Persistent Disk
- Pod / Node障害時の挙動
- rolling update

DiskBBQ等、ライセンス条件の異なる機能は基本検証と分離する。

---

# 5. 検索方式

最低でも以下の4方式を比較する。

## A. BM25 only

```text
query
  -> Elasticsearch BM25
  -> Top-K
```

目的:

- lexical searchの基準値
- ECにおけるexact / keyword matchingの強さを確認

## B. Dense Vector only

```text
query
  -> embedding
  -> ANN
  -> Top-K
```

Vertex AI Vector SearchとElasticsearch Vector Searchを直接比較する。

## C. Elasticsearch Hybrid

```text
BM25
 +
Dense Vector
 -> fusion
 -> Top-K
```

## D. Elasticsearch Hybrid + RRF

```text
BM25 candidates
       +
Vector candidates
       |
       v
      RRF
       |
       v
     Top-K
```

最終的に、Vertex単体と比較して「Elasticsearchへ検索候補生成を統合する価値」があるかを見る。

---

# 6. 評価軸

評価を4レイヤーに分離する。

## 6.1 検索品質

候補指標:

- nDCG@10
- MRR
- Recall@10
- Recall@100
- Precision@10

目的は「速いVector DB」を選ぶことではなく、**EC検索として正しい候補を返せる基盤を選ぶこと**。

## 6.2 Performance

- p50 latency
- p95 latency
- p99 latency
- QPS
- index build time
- ingest throughput
- update latency

## 6.3 Resource

- CPU
- memory
- JVM heap
- vector index memory
- disk usage
- network

## 6.4 Cost / FinOps

- Vertex AI Vector Search費用
- GKE node費用
- Persistent Disk費用
- Elasticsearch構成別費用
- replica増加コスト
- RAM増加による性能改善量
- 月額換算
- 1M queryあたり概算コスト

単純なクラウド料金だけではなく、**別基盤を持つことによる運用複雑性**も定性的に記録する。

---

# 7. 検証フェーズ

## Phase 0 - Dataset / Evaluation Foundation

目的:

- ESCIを再現可能にロードする。
- 評価基盤を先に固定する。

成果物:

- dataset download / prepare script
- schema
- query / product loader
- relevance label parser
- nDCG / MRR / Recall evaluator

この段階ではKubernetesへ進まない。

---

## Phase 1 - Local Kubernetes + ECK

目的:

**ElasticsearchをVector DBとして利用する構造を理解する。**

構成例:

```text
Local machine
  |
  +-- kind / k3d / Docker Desktop Kubernetes
        |
        +-- ECK Operator
              |
              +-- Elasticsearch
```

データはsubsetから開始する。

対象:

- ECK Operator
- Elasticsearch CRD
- PVC
- Secret / TLS
- dense_vector
- kNN
- BM25
- filter
- Hybrid Search
- RRF

ここでは本格的な性能比較を行わない。

### Phase 1 完了条件

同一queryについて、以下を再現可能に実行できること。

```text
BM25
Vector
Hybrid
Hybrid + RRF
```

さらにESCIのrelevance labelを使ってnDCG等を計測できること。

---

# 8. Phase 2 - GKE Standard + ECK

目的:

**Vector DBをKubernetesインフラとして理解する。**

Localで完成した構成をGKE Standardへ移植する。

検証項目:

- node pool
- resource requests / limits
- JVM heap
- shard
- replica
- PVC
- HNSW memory consumption
- quantization
- autoscaling候補
- node drain
- Pod restart
- rolling update

### 主な問い

- RAMを増やした場合、p95 / p99はどこまで改善するか。
- CPU増加がQPSへどの程度効くか。
- shard数を増やした際、どこから逆効果になるか。
- replica増加のコストに対してQPSはどれだけ伸びるか。
- Vector indexの圧縮で品質・latency・RAMがどう変化するか。

---

# 9. Phase 3 - Vertex AI Vector Search Comparison

同一dataset、同一embedding、同一queryで比較する。

```text
                     Amazon ESCI
                          |
                    same embeddings
                          |
             +------------+------------+
             |                         |
             v                         v
 Vertex AI Vector Search      Elasticsearch on GKE
                                      |
                              ECK / HNSW / Quantization
             |                         |
             +------------+------------+
                          |
                          v
             Quality / Latency / QPS / Cost
```

### 原則

**embedding modelの差をVector DB性能差へ混入させない。**

同一embeddingを両基盤へ投入する。

---

# 10. Phase 4 - Architecture Decision

最終成果物は「Elasticが勝った / Vertexが勝った」という一行結論ではない。

次の条件表を作る。

例:

| 条件 | 推奨 |
|---|---|
| keyword + semantic + filterが重要 | Elasticsearch有力 |
| 既にGKE / Elastic運用チームが存在 | Elasticsearch有力 |
| 検索基盤を一本化したい | Elasticsearch有力 |
| 超大規模ANN | Vertex要検討 |
| 厳格なtail latency | Vertex要検討 |
| 運用人員を極小化したい | Managed側有力 |
| Kubernetesを既存固定費として持つ | ECKのTCOが改善しやすい |

最終ADRでは、**どの境界条件でアーキテクチャ選択が逆転するか**を書く。

---

# 11. 非ゴール

今回やらないことを明示する。

- 実案件の再現
- 工業用EC検索の再現
- 実案件データの利用
- 検索モデルそのものの研究
- 新しいembedding modelの開発
- LLM検索エージェントの開発
- UI / ECサイトの構築
- Recommendation Engineの構築
- Elasticsearch全機能の網羅

目的はあくまで、

> **Vector Search基盤のアーキテクチャ選定を、EC検索を題材に実測すること。**

---

# 12. 推奨リポジトリ構成

```text
vector-search-platform-benchmark/
|
+-- README.md
+-- docs/
|   +-- 01_requirements.md
|   +-- 02_architecture.md
|   +-- 03_dataset.md
|   +-- 04_evaluation.md
|   +-- 05_benchmark-plan.md
|   +-- 06_cost-model.md
|   +-- adr/
|       +-- 0001-use-amazon-esci.md
|       +-- 0002-use-eck-on-gke.md
|       +-- 0003-use-same-embeddings.md
|       +-- 0004-retrieval-strategy.md
|
+-- infra/
|   +-- local/
|   |   +-- eck/
|   |   +-- elasticsearch/
|   +-- gke/
|   |   +-- terraform/
|   |   +-- eck/
|   +-- vertex/
|       +-- terraform/
|
+-- src/
|   +-- dataset/
|   +-- embedding/
|   +-- ingest/
|   +-- retrieval/
|   +-- evaluation/
|   +-- benchmark/
|
+-- configs/
|   +-- elastic/
|   +-- vertex/
|
+-- results/
|   +-- quality/
|   +-- performance/
|   +-- cost/
|
+-- scripts/
|   +-- setup-local.sh
|   +-- load-esci.sh
|   +-- run-benchmark.sh
|
+-- Makefile
+-- pyproject.toml
+-- .github/
    +-- workflows/
```

---

# 13. ADR候補

## ADR-0001: Amazon ESCIを使用する

理由:

- 公開一般ECデータ
- relevance labelが存在
- 検索品質を定量化可能
- 実案件データ不要

## ADR-0002: GKEではECKを利用する

理由:

- ElasticsearchをKubernetes-nativeに管理できる。
- Stateful workload運用も検証テーマに含められる。
- Kubernetes / Vector DB / FinOpsを一つのPoCに統合できる。

## ADR-0003: VertexとElasticで同一embeddingを使用する

理由:

Vector DBの比較にembedding model差を混ぜないため。

## ADR-0004: Vector-onlyだけで結論を出さない

理由:

一般EC検索ではlexical retrievalが依然重要であり、Elasticsearchの価値はBM25 + Vector + Filter + Hybridにあるため。

---

# 14. 成果物

最低成果物:

1. 再現可能なAmazon ESCIデータ準備処理
2. Local Kubernetes + ECK + Elasticsearch
3. GKE + ECK + Elasticsearch
4. Vertex AI Vector Search
5. 共通embedding
6. 共通benchmark runner
7. 検索品質レポート
8. latency / QPSレポート
9. resource usageレポート
10. cost比較
11. 最終ADR

最終成果物の中心はコードではなく、以下の判断資料とする。

> **When should Elasticsearch on GKE replace Vertex AI Vector Search for e-commerce retrieval?**

---

# 15. 成功条件

このPoCは「Elasticの方が高性能だった」だけでは成功としない。

以下を説明可能になれば成功とする。

1. Vertex AI Vector Searchが優位になる条件
2. Elasticsearchが優位になる条件
3. HNSW / quantizationの性能・コスト特性
4. KubernetesへVector DBを載せる運用コスト
5. Hybrid Searchによる検索品質改善量
6. Elasticsearchへ基盤統合することで削減できる構成要素
7. どの規模からManaged Vector DBを選ぶべきか

つまり、

> **製品比較ではなく、アーキテクチャ選定基準を得ること**

を最終ゴールとする。

---

# 16. 最初の実装スコープ

初回スプリントでは以下だけを行う。

```text
Amazon ESCI subset
        |
        v
Embedding generation
        |
        v
Local Kubernetes
        |
        v
ECK
        |
        v
Elasticsearch
   |         |
 BM25      Vector
   \         /
    \       /
     Hybrid
       |
      RRF
       |
       v
nDCG / MRR / Recall
```

**GKEもVertexも最初は触らない。**

Local ECK上で評価パイプラインまで完成した段階でPhase 1完了とし、その後GKEへ昇格する。

この順番にすることで、「検索ロジック」「Kubernetes」「クラウド性能比較」を同時にデバッグする状態を避ける。
