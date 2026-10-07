# AGENTS.md

AI コーディングエージェント（Claude Code / Codex / GitHub Copilot 等）共通の作業ガイド。
Codex は作業前にこのファイルを読むため、ここには repo 共通方針のみ記す。
ツール固有の指示は各ツールのファイル（例: Claude Code は `CLAUDE.md`）に置く。

## プロジェクト概要

- 目的: 公開の一般 EC 検索データを用い、Vertex AI Vector Search と GKE Standard + ECK + Elasticsearch を、検索品質・性能・リソース・コストの4軸で再現可能に比較する。
- 最終ゴール: 単純な製品の勝敗ではなく、「EC retrieval で Elasticsearch on GKE が Vertex AI Vector Search の代替候補になる条件」と「Managed Vector DB を選ぶべき境界」を ADR として説明可能にする。
- データ: Amazon Shopping Queries Dataset / ESCI。公開データのみを使い、実案件の商品・query・Ground Truth・特徴量・ログは使用しない。
- 検索方式: BM25、Dense Vector ANN、Hybrid Search、Hybrid + RRF。Elasticsearch は HNSW、metadata filter、quantization も検証対象とする。
- 主要技術: Elasticsearch、ECK、Kubernetes（Local から GKE Standard へ段階的に移行）、Vertex AI Vector Search、共通 embedding / benchmark runner。
- 作業中の初期構想の詳細: `docs/tasks/01_idea/vector-search-platform-benchmark-project-concept.md`。これは未確定の planning brief であり、確定後は `docs/01_requirements.md`、`docs/02_architecture.md`、`docs/adr/` へ昇格する。

## ベンチマーク不変条件

- Vertex と Elasticsearch には、同一 dataset、query、embedding、評価条件を使う。embedding model の差を基盤性能差に混入させない。
- ANN の latency / QPS だけで結論を出さない。検索品質（nDCG / MRR / Recall / Precision）、tail latency、ingest / index build、CPU / memory / disk / network、月額と1M queryあたりコスト、運用複雑性を分けて記録する。
- Elasticsearch の評価を Vector-only に限定しない。EC 検索で重要な lexical retrieval、filter、hybrid、reranking を含める。
- データセット本体は原則コミットせず、取得・前処理スクリプトと手順を管理する。配布条件とライセンスを使用前に確認する。
- ベンチマークは再実行可能にし、raw result、設定、バージョン、コスト前提を記録する。

## 段階的な実装境界

1. Phase 0: ESCI 取得・schema / loader・relevance label parser・品質評価基盤を固定する。
2. Phase 1: subset と Local Kubernetes + ECK で BM25 / Vector / Hybrid / RRF から評価までを再現可能にする。
3. Phase 2: 完成したローカル構成を GKE Standard へ移植し、リソース・障害・rolling update を検証する。
4. Phase 3: 同一条件で Vertex AI Vector Search と比較する。
5. Phase 4: 境界条件と選定基準を最終 ADR にまとめる。

初回スプリントでは Phase 1 までに集中し、GKE と Vertex は触らない。検索ロジック、Kubernetes、クラウド比較を同時にデバッグしない。

## 非ゴール

- 実案件や工業用 EC の再現、非公開データの利用
- embedding model 自体の研究・開発
- LLM 検索エージェント、EC UI、Recommendation Engine の構築
- Elasticsearch の全機能網羅

## セットアップ / 主要コマンド

```bash
make setup    # 依存取得 + ビルド
make dev      # 開発サーバー
make test     # テスト
make fmt      # フォーマット
```

## コーディング規約

- 既存のコード・命名・パターンに合わせる。新規導入より既存の再利用を優先する。
- 変更後はテストとフォーマッタを実行してから完了とする。
- 非機密の設定値は `env/config.yaml`、ローカル秘密情報は `env/secret.yaml`、チーム共有・本番クレデンシャルは Doppler (`doppler.yaml`)。秘密情報をコミットしない。

## ドキュメント

設計・仕様・運用は `docs/` 配下を参照。更新規約と権威順位は `docs/00_index.md` に従う。
仕様レベルの変更は連動するドキュメントを同一 PR でまとめて直す。

## Codex / Claude Code

- `AGENTS.md` は Codex / 他エージェント共通ガイド。
- `CLAUDE.md` は Claude Code の司令塔。
- `.claude/rules/` と `.claude/skills/` は Claude Code 用。Codex が読む前提にしない。
- Codex 向けに永続させたい recurring な指摘やミス防止は、この `AGENTS.md` または nested `AGENTS.md` に小さく追加する。

## Harness（AI 制御一式）

- このリポジトリの AI 制御の全体像は `.claude/README.md`（Kurosawa Thin Harness Architecture の実装）。
- アーキ本体（tool-agnostic マスター）は `docs/specs/kurosawa-thin-harness-architecture.md`、repo 固有の脅威モデルは `docs/specs/{capability-boundary,change-boundary,runtime-protocol,evidence-policy,judgment-memory}.md`。
- permissions の ask/deny と保護パスは脅威モデルで決める。**他プロジェクトの設定をそのまま移植しない**。

## Task / Skill

- 一回性の作業計画・調査メモ・実装タスクは `docs/tasks/` に置く。
- Claude Code で繰り返し使う作業手順は `.claude/skills/` に置く（classify-task → create-task → scan-decisions → plan-skeleton → execute-task → verify-completion → review-task のライフサイクル）。
- Codex repo skills を本格運用する場合は `.agents/skills/` を任意追加する。標準生成物には含めない。
- task note を仕様の正本にしない。確定した仕様は `docs/specs/`、判断理由は `docs/adr/`、運用手順は `docs/runbooks/` に昇格する。
