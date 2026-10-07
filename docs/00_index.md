# プロジェクトドキュメント索引

このディレクトリは、Vector Search Platform Benchmark の要件・設計・ワークフロー・データ契約・テスト・リリース運用の正本。本プロジェクトは、Amazon Shopping Queries Dataset / ESCI を用い、Vertex AI Vector Search と GKE Standard + ECK + Elasticsearch の選定条件を検索品質・性能・リソース・コストの4軸で明らかにする。

## 権威順位

```text
コード / Makefile / config / manifests
> docs/01〜08 / docs/specs / docs/adr / docs/runbooks
> docs/tasks
> README / CLAUDE / AGENTS
> docs/archive
```

- `docs/01〜08` は現行のプロジェクト仕様と基礎設計。
- `docs/tasks/` は日々の実行順・証跡・未決事項の正本だが、製品仕様の正本ではない。
- `docs/archive/` は出典・候補・思考過程の保存先であり、現行仕様として参照しない。
- 仕様変更時は、実装・設定・関連ドキュメントを同じ変更で整合させる。

## 毎日使う入口

| 入口 | 用途 |
|---|---|
| [tasks/README.md](./tasks/README.md) | 今日やること、次にやること、完了証跡を管理する |
| [tasks/02_backlog/benchmark-open-decisions.md](./tasks/02_backlog/benchmark-open-decisions.md) | ベンチマーク条件の未決事項を管理する |
| [tasks/03_active/refactoring-candidates.md](./tasks/03_active/refactoring-candidates.md) | cleanup / refactoring 候補を管理する |
| [04_workflows.md](./04_workflows.md) | データ準備から ADR までの実行順を確認する |
| [07_test_strategy.md](./07_test_strategy.md) | フェーズごとの品質ゲートとベンチマーク妥当性を確認する |

## プロジェクト正本

| ドキュメント | 答える問い |
|---|---|
| [01_requirements.md](./01_requirements.md) | 何を、誰のために、どの条件で満たすか |
| [02_architecture.md](./02_architecture.md) | 要件をどの構成要素と境界で実現するか |
| [03_domain_model.md](./03_domain_model.md) | ベンチマーク中の用語、概念、状態をどう解釈するか |
| [04_workflows.md](./04_workflows.md) | データ準備、環境構築、計測、比較、判断をどの順で行うか |
| [05_data_model.md](./05_data_model.md) | 入力、embedding、索引、実験条件、結果をどの論理契約で持つか |
| [06_error_policy.md](./06_error_policy.md) | 失敗をどう分類し、再試行・停止・無効化するか |
| [07_test_strategy.md](./07_test_strategy.md) | 実装正しさと比較の公平性をどう検証するか |
| [08_release_runbook.md](./08_release_runbook.md) | 環境・ベンチマーク成果物・ADR をどう公開し、異常時に戻すか |

## フェーズ別の読み順

| Phase | 先に読む文書 |
|---|---|
| 0: Dataset / Evaluation Foundation | 01 → 03 → 05 → 07 → 04 |
| 1: Local Kubernetes + ECK | 01 → 02 → 04 → 06 → 07 |
| 2: GKE Standard + ECK | 02 → 04 → 06 → 07 → 08 |
| 3: Vertex AI Vector Search Comparison | 01 → 02 → 05 → 07 → 04 |
| 4: Architecture Decision | 01 → 07 → 08 → `docs/adr/` |

## 出典と未決事項

- 蒸留元の初期構想: [archive/vector-search-platform-benchmark-brainstorm.md](./archive/vector-search-platform-benchmark-brainstorm.md)
- 未決の実験条件: [tasks/02_backlog/benchmark-open-decisions.md](./tasks/02_backlog/benchmark-open-decisions.md)
- 設計選択の理由は、検証後に `docs/adr/` へ記録する。

## ハーネス（AI 制御）

AI エージェント制御の全体像は `.claude/README.md`。アーキ本体と repo 固有 instantiation は `docs/specs/` に置く。

| ドキュメント | 役割 |
|---|---|
| [specs/kurosawa-thin-harness-architecture.md](./specs/kurosawa-thin-harness-architecture.md) | Thin Harness アーキ本体（tool-agnostic マスター） |
| [specs/runtime-protocol.md](./specs/runtime-protocol.md) | 実行手順と停止条件（repo 固有） |
| [specs/capability-boundary.md](./specs/capability-boundary.md) | 保護 capability と permissions 写像 |
| [specs/change-boundary.md](./specs/change-boundary.md) | 保護パスと変更境界 |
| [specs/evidence-policy.md](./specs/evidence-policy.md) | Evidence Level と done の下限 |
| [specs/judgment-memory.md](./specs/judgment-memory.md) | 判断記憶のパイプライン |
| [templates/](./templates/) | 各 Layer のテンプレート |
| [decisions/decision-log.md](./decisions/decision-log.md) | 判断日誌（append-only） |
| [memory/](./memory/) | 蒸留済み判断記憶 |
