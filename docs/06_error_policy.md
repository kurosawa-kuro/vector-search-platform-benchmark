# 06 エラー方針

## 原則

- 正しくない条件で結果を生成することは、結果が無いことより危険。データ契約または比較公平性の違反は fail fast し、run を `invalid` にする。
- 自動再試行は一時的で、同じ入力に対し安全に再実行できる操作に限る。
- 一部成功を全体成功と扱わない。欠落 query、欠落 sample、計測窓の中断は manifest と report に明示する。
- 失敗した run の raw evidence も、秘密情報を除いて調査可能な範囲で保存する。

## エラー分類

| コード | 分類 | 例 | 対応 | Run 状態 |
|---|---|---|---|---|
| DATA-LICENSE | 利用条件 | ライセンス未確認、配布条件不明 | 即時停止し、owner 判断まで使用しない | blocked / invalid |
| DATA-ACQUIRE | データ取得 | network failure、配布元の一時エラー | 入力元を変えず、上限付きで再試行可 | failed |
| DATA-CONTRACT | schema / integrity | 必須値欠落、ID 不整合、relevance 参照先欠落 | 再試行せず fail fast。変換または入力を修正 | invalid |
| EMBEDDING-CONTRACT | embedding | model provenance 欠落、次元不一致、source ID 欠落 | 再試行せず artifact を無効化 | invalid |
| CONFIG | scenario / config | 未知の retrieval mode、必須設定欠落、範囲外値 | 実行前検証で停止 | invalid |
| PROVISION | infra 構築 | ECK / cluster / index が ready にならない | 原因と状態を保存し停止。一時障害のみ再試行 | failed |
| INGEST | ingest / index | バルク投入失敗、件数不一致、index build failure | 失敗対象を記録。件数または artifact 不一致は index を無効化 | failed / invalid |
| QUERY-TRANSIENT | 一時的な query 失敗 | timeout、接続切断、一時的 5xx | scenario で定義した同一条件で上限付き再試行。回数を記録 | running / failed |
| QUERY-PERMANENT | 永続的な query 失敗 | 無効 query、mapping 不整合、未対応 filter | 再試行せず停止。scenario または adapter を修正 | invalid |
| QUOTA | quota / rate limit | Vertex quota、cloud API rate limit | 計測窓を汚染しないよう run を停止。条件を変える場合は別 scenario | failed |
| EVALUATION | 指標算出 | relevance 欠落、重複 result、Top-K 不整合 | 集計せず run を無効化 | invalid |
| OBSERVABILITY | 計測 | sample 欠落、時刻不整合、resource collector 停止 | 影響軸の数値を比較対象から除外し、欠落を明示 | failed / partial |
| COST | 費用前提 | region / currency / pricing date 欠落 | コスト比較を公開せず、前提を修正 | invalid for cost |
| SECRET | 秘密情報 | credential 欠落、log / artifact への漏えい疑い | 停止、露出範囲確認、必要な credential 無効化・ローテーション | failed / security incident |

`partial` は report 上の明示であり、Benchmark Run の成功状態ではない。比較に必要な軸が欠けた run は `completed` へ進めない。

## 再試行方針

- 再試行の対象は network、timeout、一時的 5xx、rate limit 等の transient error に限る。
- schema、license、設定、embedding 同一性、relevance のエラーは再試行しない。
- 最大回数、backoff、timeout は versioned config で固定し、RunManifest に実績を残す。値は [benchmark-open-decisions.md](./tasks/02_backlog/benchmark-open-decisions.md) で決定する。
- 再試行が latency 統計に与える影響を隠さない。初回 attempt と retry を識別可能にする。
- scenario 条件を変えて成功させた場合は、元 run の再試行ではなく別 scenario / run とする。

## 比較無効化条件

次のいずれかに該当する run は、数値が取得できても横断比較に使わない。

- dataset ID、embedding artifact ID、query set、Top-K、filter 条件の不一致
- warmup / measurement 期間または負荷プロファイルの不一致
- index 件数または embedding dimension の不一致
- 計測中のスケール、設定変更、バージョン変更
- 必要な raw result、run metadata、時刻、単位の欠落
- 実験結果に影響する未説明の backend error または resource saturation

## ログ

構造化ログに次を含める。

- timestamp / severity / component / operation
- run ID / scenario ID / backend / retrieval mode
- query ID または batch ID（必要な場合）
- attempt number / duration / result count
- error code / retryable / terminal status

次はログへ出力しない。

- API key、token、credential、secret file の内容
- Authorization header または署名付き URL
- サービスが返した秘密情報を含み得る raw response

ESCI は公開データだが、大量の query / product text を通常ログへ重複出力せず、ID で追跡する。

## レポートでの扱い

- failed / invalid / excluded run の件数と理由を明記する。
- 成功 run のみを見せて失敗率を隠さない。
- missing metric を0として扱わない。欠測と明記する。
- 比較不可の run は参考値として別表にし、比較結論の根拠に使わない。

## 関連タスク

- エラー分類、リトライ、ログ出力の変更は task に再現条件と期待する観測結果を残す。
- 障害対応で得た恒久手順は task に閉じず、`docs/runbooks/` へ昇格する。
- 回帰防止が必要なものは [07_test_strategy.md](./07_test_strategy.md) と task の Acceptance Criteria に反映する。
