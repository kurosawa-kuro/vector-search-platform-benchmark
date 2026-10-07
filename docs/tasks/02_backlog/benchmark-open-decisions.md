# ベンチマーク条件の未決事項を固定する

## Goal

Phase 0〜3 の実装・比較結果に影響する未決値を、根拠、比較可能性、再現性、ライセンス、コストとともに固定する。

## Context

`docs/archive/vector-search-platform-benchmark-brainstorm.md` から `docs/01_requirements.md`〜`docs/08_release_runbook.md` へ仕様・設計を蒸留した。元構想では下表の値が候補または未指定であり、根拠なく正本化できない。

## Scope

### 確定済み

| ID | 決定 | 根拠 / 正本 |
|---|---|---|
| OD-006 | Phase 1 の Local Kubernetes runtime は kind、single control-plane node とする | ローカル専用、再構築可能、ECK 検証に必要な Kubernetes / StorageClass を最小構成で提供できる。実装は `infra/local/versions.env` と `infra/local/kind.yaml` |
| OD-007 | kind v0.33.0、Kubernetes v1.34.11（digest pin）、ECK 3.5.0、Elasticsearch 9.5.5 | ECK 3.5.0 の Kubernetes 1.31+ 要件を満たし、host kubectl v1.33.4 との skew を +1 minor に収める。版の正本は `infra/local/versions.env` |

OD-006 / OD-007 は local Phase 1 のみの決定であり、GKE topology やクラウド比較条件を固定しない。更新時は [kind releases](https://github.com/kubernetes-sigs/kind/releases)、[ECK download](https://www.elastic.co/downloads/elastic-cloud-kubernetes)、[ECK Elasticsearch quickstart](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/elasticsearch-deployment-quickstart) を確認し、digest / chart / Stack version を同時に更新する。

### 対象

| ID | 論点 | 決定に必要な根拠 | 反映先 |
|---|---|---|---|
| OD-001 | 実装言語、runtime、package / test tooling | 開発性、ライブラリ、再現性、CI 実行性 | 02 / 04 / 07 / Makefile |
| OD-002 | ESCI version、locale、split、subset 方式と規模 | ライセンス、品質評価の代表性、ローカル実行可能性 | 01 / 05 / 07 |
| OD-003 | ESCI field mapping、product text 組み立て、metadata filter 対象 | source schema、検索意図、欠損率 | 05 / ADR |
| OD-004 | relevance label の gain mapping、tie、指標集計方法 | 数理定義、既存評価との比較可能性 | 05 / 07 |
| OD-005 | embedding model / version / dimension / normalization / batch 条件 | 両 backend の対応条件、コスト、品質、再生性 | 01 / 05 / ADR |
| OD-006 | Local Kubernetes runtime（確定済み） | ECK 対応、ローカルリソース、CI 適合性 | 02 / 04 / ADR |
| OD-007 | Kubernetes / ECK / Elasticsearch の固定バージョン（確定済み） | 互換性、機能、ライセンス、サポート | 02 / 04 / 08 |
| OD-008 | HNSW / int8 / BBQ / DiskBBQ の対象範囲 | 製品版、ライセンス、比較可能性 | 01 / ADR |
| OD-009 | GCP project / region、GKE node / disk / shard / replica topology | quota、単価、容量、データローカリティ | 02 / 04 / 08 |
| OD-010 | Vertex AI Vector Search の構成・固定バージョン相当の記録方法 | 比較公平性、再現性、quota、単価 | 02 / 05 / 08 |
| OD-011 | query set、Top-K、filter、concurrency、warmup、duration、繰り返し数 | 統計的安定性、想定ワークロード、費用 | 05 / 07 |
| OD-012 | timeout、retry 上限、backoff、失敗率の扱い | 公平性、運用性、latency への影響 | 06 / 07 |
| OD-013 | resource / performance 計測ツールと sampling interval | 計測 overhead、時間窓整合性、両 backend の比較可能性 | 02 / 05 / 07 |
| OD-014 | cost の region / currency / pricing date / monthly usage / 1M query 定義 | 単価の追跡性、利用量前提、比較可能性 | 01 / 05 / 07 |
| OD-015 | 運用複雑性の評価 rubric | 作業種別、必要スキル、障害対応、変更管理 | 01 / 07 / ADR |
| OD-016 | artifact 形式、ID / integrity ID、保存先、保持期間 | サイズ、コスト、再計算、Git 制約 | 05 / 08 |
| OD-017 | 各 Phase の数値閾値と判断保留条件 | 実測 baseline、SLO 仮説、統計的変動 | 01 / 07 / 08 |

### 非対象

- 個別論点の根拠ない即断
- Phase 0 / 1 完了前の GKE / Vertex 実装
- 実案件データを使った補完

## Skeleton

1. Phase 0 の blocker（OD-001〜006、16）を先に決める。
2. Local ECK 実装の blocker（OD-006〜008、12）を決める。
3. GKE / Vertex の課金・比較条件（OD-009〜015）は Phase 2 着手前に決める。
4. 数値閾値（OD-017）は baseline 実測後に固定する。

## Plan

- [ ] 各論点に owner と決定期限を付ける。
- [ ] 候補、前提、比較軸、証跡を論点ごとに記録する。
- [ ] ライセンス・課金・外部 API 仕様は一次情報で確認する。
- [ ] 確定値を該当 docs / config / tests へ同時に反映する。
- [ ] 非自明な選択は `docs/adr/` へ記録する。

## Acceptance Criteria

- Phase 0 着手に必要な値が、根拠と追跡可能な参照付きで固定されている。
- 各確定値が単一の正本へ反映され、docs 間で重複・矛盾していない。
- 比較結果へ影響する値が scenario / manifest で versioned になる。
- 未決の値が仕様やコードに暗黙の default として入っていない。

## Verification

- 未実施。各論点の決定時に調査参照、変更パス、検証結果を追記する。

## Notes

- 元構想は `docs/archive/vector-search-platform-benchmark-brainstorm.md` に退避済み。
- この task は owner 判断待ちを含むため `02_backlog/` で管理する。
