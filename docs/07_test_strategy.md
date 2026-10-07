# 07 テスト戦略

## 目的

このプロジェクトでは、コードが動くことと同じ重みで、ベンチマークの比較が公平・再現可能・追跡可能であることを検証する。

テストは次の2種類を区別する。

1. **実装検証**: parser、adapter、evaluator、runner、infra が契約どおり動くか。
2. **実験妥当性検証**: 同一条件で比較し、指標と結論を raw evidence から再生できるか。

## テスト層

| 層 | 対象 | 主な検証 |
|---|---|---|
| Unit | parser、schema validation、metric calculation、RRF / fusion、config validation | 小さな固定 fixture に対する決定的な入出力 |
| Contract | dataset、embedding、RankedResult、manifest、backend adapter | 必須フィールド、ID 整合性、バージョン、provider 間の共通契約 |
| Integration | Elasticsearch / Vertex adapter、artifact store、metrics collector | 実 backend または忠実な test environment との ingest / query / result normalization |
| End-to-end | Dataset preparation → embedding → index → retrieval → evaluation | [01_requirements.md](./01_requirements.md) の Golden Path |
| Infrastructure | ECK / Elasticsearch / storage / TLS / GKE / Vertex | ready、バージョン、永続化、再起動、rolling update、後始末 |
| Benchmark validity | run 間の公平性、warmup / measurement、sample completeness | dataset / embedding / query / Top-K / load の一致と欠測の無いこと |
| Reproducibility | 別実行での artifact / metric 再生 | 同一入力・設定から必要な結果を再生できること |

## テストデータ

- Unit / Contract では、Git にコミット可能な小さな synthetic fixture を使う。
- metric evaluator には、期待 nDCG / MRR / Recall / Precision を手計算で固定した golden fixture を用意する。
- End-to-end では、利用条件を確認済みの ESCI subset を使う。ESCI 本体は Git にコミットしない。
- 実案件のデータ、query、Ground Truth、特徴量、ログを fixture に使わない。

## 重要テストケース

### Dataset / schema

- query / product ID の重複と欠落を検出する。
- RelevanceJudgment が存在しない query / product を参照した場合に失敗する。
- subset / 変換条件が manifest へ保存される。
- 同一入力と条件から同一性を検証可能な artifact が生成される。

### Embedding

- query / product の全対象 ID に vector が対応する。
- dimension、model ID / version、source dataset ID の欠落で失敗する。
- Elasticsearch と Vertex の BackendManifest が同一 EmbeddingManifest を参照する。

### Retrieval adapter

- BM25、Vector、Hybrid、RRF が共通 RankedResult 契約を返す。
- Top-K を超えず、query 内で product ID が重複しない。
- backend score を rank と混同せず、backend 固有 field が evaluator に漏れない。
- filter 条件が scenario と backend request で一致する。

### Evaluator

- empty result、relevant item なし、Top-K 未満、tie、複数 relevance level を扱う。
- 指標の cutoff と aggregation scope を結果に保存する。
- raw RankedResult から同じ QualityResult を再計算できる。

### Benchmark runner

- 必須 artifact または条件不一致を実行前に検出する。
- warmup sample を measurement sample から分離する。
- retry / timeout / error を run ID と attempt に紐付ける。
- 失敗・中断時に `completed` を記録しない。
- code / config / infra / dataset / embedding の各バージョンを RunManifest に保存する。

### 秘密情報

- log、manifest、result、report に token、API key、credential、Authorization header が含まれない。
- secret の欠落は明確なエラーになるが、値自体は出力しない。

## フェーズ別品質ゲート

| Phase | 必須ゲート |
|---|---|
| 0 | dataset contract test、embedding contract test、metric golden test、artifact 再生手順が通る |
| 1 | Local ECK で ingest から4 retrieval modes、RankedResult 正規化、quality evaluation までの E2E が通る |
| 2 | GKE で構成固定、performance / resource 収集、node drain / Pod restart / rolling update シナリオの証跡が残る |
| 3 | Vertex / Elasticsearch 間の fairness gate が通り、Dense Vector 同士の比較を raw result から再生できる |
| 4 | 全掲載値が run IDs へ追跡でき、除外 run、制約、残存リスクを含む ADR がレビュ済み |

## Benchmark Validity Gate

横断比較へ含める前に、run ごとに次を自動または証跡付きで検証する。

- dataset ID / integrity ID が一致する。
- embedding artifact ID / dimension / model provenance が一致する。
- query set / Top-K / filter / retrieval mode が期待どおりである。
- backend index 件数と参照 artifact が一致する。
- warmup / measurement / concurrency / duration / retry 条件が一致する。
- performance / resource sample の対象時間窓が一致する。
- pricing date / region / currency / usage assumptions が比較可能である。
- failed / invalid / excluded run が report から隠されていない。

## 性能テストの扱い

- 性能 benchmark を機能テストの pass / fail と混同しない。
- p50 / p95 / p99、QPS、resource は実行条件と一緒に解釈する。
- 数値閾値は根拠なく固定せず、決定後に scenario と task Acceptance Criteria へ記録する。
- 異なる環境または異なる計測窓の値を、一つの比較表で同等に扱わない。

## コマンドと品質ゲート

実行 runtime と test framework が未確定のため、テストコマンドはまだ定義しない。`make test`、`make fmt`、`make lint` の実コマンドを実装したときに、この節を同時に更新する。

現時点で文書変更に実行できる最小検証:

```bash
git diff --check
```

## タスク完了条件

各 task は完了前に次を `Verification` へ残す。

- 実行したコマンドと対象環境
- 結果の要約と証跡パス
- 通過したフェーズゲート
- 実行できなかった検証と理由
- failed / invalid / excluded run とその理由
- 残るリスクと follow-up task

テスト追加や期待値変更が必要な場合は task に理由を書き、仕様変更なら先に該当 docs を更新する。
