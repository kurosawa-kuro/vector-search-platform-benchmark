# CLAUDE.md

このファイルは Claude Code がこのリポジトリで作業する際の最小ガイド。

## Source of Truth

- Project overview: `README.md`
- Documentation index: `docs/00_index.md`
- Requirements: `docs/01_requirements.md`
- Architecture: `docs/02_architecture.md`
- Test strategy: `docs/07_test_strategy.md`
- Harness 全体像: `.claude/README.md`（このリポジトリの AI 制御一式）
- Harness アーキ本体: `docs/specs/kurosawa-thin-harness-architecture.md`（tool-agnostic マスター）＋ repo 固有 instantiation（`docs/specs/{runtime-protocol,capability-boundary,change-boundary,evidence-policy,judgment-memory}.md`）
- 判断日誌 / 蒸留記憶: `docs/decisions/decision-log.md` / `docs/memory/`
- Feature spec（実装前・1 機能ごと）: `SPEC.md`
- Task notes: `docs/tasks/`
- Planning brief（未確定の初期構想）: `docs/tasks/01_idea/vector-search-platform-benchmark-project-concept.md`

**spec の使い分け（混同しない）**: `SPEC.md` = 今から作る 1 機能の使い捨て実装スペック（公式 Explore→Plan→Implement→Commit の入口、新セッションで実行）。`docs/specs/` = 恒久アーキ設計マスター。`docs/tasks/` = タスク台帳。

## プロジェクト文脈

公開の Amazon Shopping Queries Dataset / ESCI を用い、Vertex AI Vector Search と GKE Standard + ECK + Elasticsearch を比較する。目的は ANN の単純な勝敗ではなく、EC retrieval で検索基盤を Elasticsearch on GKE へ統合できる条件と、Managed Vector DB が優位になる境界を明らかにすること。

- 比較方式: BM25、Dense Vector ANN、Hybrid Search、Hybrid + RRF
- 評価軸: 検索品質、latency / QPS、ingest / index build、CPU / memory / disk / network、費用、運用複雑性
- 成果物: 再現可能なデータ準備と benchmark runner、各評価レポート、アーキテクチャ選定基準を示す最終 ADR

## プロジェクト固有のガードレール

- Vertex と Elasticsearch の比較では、同一 dataset、query、embedding、評価条件を使う。embedding model の差を検索基盤の差に混入させない。
- Vector-only で結論を出さない。Elasticsearch は BM25、metadata filter、Hybrid Search、RRF を含めて評価する。
- 検索品質は nDCG / MRR / Recall / Precision、性能は p50 / p95 / p99 latency、QPS、index build、ingest / update latency を分けて記録する。コスト前提とリソース設定も結果に付与する。
- 公開データのみを使う。実案件の商品、query、Ground Truth、特徴量、ログは持ち込まない。ESCI 本体は原則コミットせず、取得・前処理手順とライセンスを管理する。
- 実装は「評価基盤 → Local Kubernetes + ECK → GKE Standard → Vertex 比較 → ADR」の順で進める。初回スプリントでは Local ECK 上の BM25 / Vector / Hybrid / RRF と品質評価までに集中し、GKE と Vertex は触らない。
- 検索モデルの研究、LLM 検索エージェント、EC UI、Recommendation Engine、Elasticsearch の全機能網羅は非ゴール。

## コマンド

```bash
make setup    # 初期セットアップ (依存取得 + ビルド)
make build    # ビルド
make run      # 実行
make dev      # 開発サーバー / ホットリロード
make test     # テスト
make fmt      # フォーマット
make lint     # 静的解析
```

## アーキテクチャ

- ソースは `src/` 配下に置く。
- 非機密の設定は `env/config.yaml`、ローカル秘密情報は `env/secret.yaml`、チーム共有・本番クレデンシャルは Doppler (`doppler.yaml`) で管理する。
- 設計・運用ドキュメントは `docs/` 配下。権威順位と更新規約は `docs/00_index.md` に従う。
- パス別ルールは `.claude/rules/` 配下に置く。
- 一回性の作業計画は `docs/tasks/`、繰り返し使う作業手順は `.claude/skills/` に置く。

## 作業ルール

- 推測でコードを書かない。コマンドを書いたら実際に実行して確認する。
- 仕様変更は連動する `docs/` とテストを同一 PR で直す。drift を作らない。
- 既存の関数・ユーティリティ・パターンを優先的に再利用する。
- task note を仕様の正本にしない。確定内容は `docs/specs/`、`docs/adr/`、`docs/runbooks/` に昇格する。
- **Scope invariant（常時）**: 作業中に Goal/Scope 外の変更・前提崩れ・追加副作用・docs と実装の矛盾を見つけたら即実装しない。`control-change` で分類するか follow-up task に残す。「ついで修正/共通化/改名」は scope creep。

## AI Runtime Protocol（薄い・常時）

Thin Harness の常時手順。詳細は `.claude/README.md` と `docs/specs/runtime-protocol.md`、停止条件は同 §「停止して owner に確認する」。

> **このハーネスは重い既定で出荷されている。** 新規生成直後は、まず skill `harness-trim` を1回回し、このプロジェクトの脅威モデルに合わせて hooks / rules / permissions / agents / skills を keep・delete・adjust する（削除は想定手順で scope creep ではない）。以降は下記の常時手順に従う。

1. Goal / Scope / Done を言い直す。
2. Weight Class を判定（Light / Standard / Heavy → `classify-task`）。Light は以降の重い手順をスキップしてよい。
3. owner-only 判断・保護 capability・allowed/forbidden paths を確認（`scan-decisions` / `capability-boundary.md` / `change-boundary.md`）。
4. Standard/Heavy の新機能は **plan モードで探索（編集せず読む）→ `SPEC.md` を自己完結で記述（触るファイル/IF 名指し・Non-scope・末尾 E2E 検証）→ 可能なら新セッションで実行**。その後 skeleton + TDD contract を先に固める（`plan-skeleton`）。
5. scope 内で最小変更を当てる。複数 attempt が要るなら停止条件付きで回す（`reconcile-task`）。
6. 必要 Evidence Level（≥2、本番は4）で検証（`verify-completion` / `evidence-policy.md`）。
7. scope 拡大・保護境界接触・二度違う理由で検証失敗 → 停止して owner へ。
8. 非自明な判断を下した時だけ記録（`log-decision`）。
