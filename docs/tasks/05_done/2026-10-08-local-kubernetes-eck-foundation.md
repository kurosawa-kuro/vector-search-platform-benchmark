# Local Kubernetes + ECK 基盤を再現可能に構築する

## Harness Weight Class

### Task Type

- [ ] Light
- [ ] Standard
- [x] Heavy / Protected

### Reason

`infra/local/**` の保護パスを編集し、`kind` / `kubectl` / `helm` で cluster-scoped CRD、Operator、PVC、Secret を作成・破棄するため。

### Required Controls

- Task Contract Full
- 実行前の owner approval
- `docs/specs/capability-boundary.md` と `docs/specs/change-boundary.md` の境界確認
- local kube context を対象にした誤操作防止
- 停止条件付きの最大 attempt 数
- ロールバック / teardown 手順
- Evidence Level 4（owner approval + runtime evidence + rollback evidence）

### Default Limits

- max attempts: owner が active 移動前に決定（推奨: 異なる失敗原因ごとに2回まで）
- max changed files: owner が active 移動前に決定
- protected path changes: `infra/local/**` だけを明示承認後に許可
- protected capability changes: project専用の local kind cluster への操作だけを許可

### Owner Approval Required?

- yes

### Approval and fixed decisions

2026-10-08、owner の「すぐ実装できるように環境インフラを整えてほしい」を本 task の実行承認として記録する。ローカル開発を優先し、次を固定する。

- runtime: kind（single control-plane node）
- kind: v0.33.0（repo-local、checksum 検証付き。host の v0.24.0 は変更しない）
- Kubernetes: v1.34.11 node image（digest pin。host kubectl v1.33.4 との version skew を +1 minor に収める）
- ECK: 3.5.0 cluster-wide Helm install
- Elasticsearch: 9.5.5、1 node、CPU request / limit = 500m / 2、memory request / limit = 1 GiB / 2 GiB、PVC = 5 GiB
- task memory budget: ECK 512 MiB + Elasticsearch 2 GiB limit（Kubernetes system component を除く）
- swap: enabled のまま機能検証に限定し、本 task では変更しない
- max attempts: 異なる失敗原因ごとに2回、同じ原因の再発は2回で停止
- max changed files: 24

## Goal

クリーンなローカル環境から、固定したバージョンと version-controlled な設定を使って project 専用 kind cluster、ECK Operator、1-node Elasticsearch を構築し、PVC / TLS / authenticated API の smoke と安全な teardown まで再現可能にする。

この task は [01_requirements.md](../../01_requirements.md) の初回マイルストーン全体ではなく、[04_workflows.md](../../04_workflows.md) Phase 1 のインフラ前提だけを完了させる。

## Value

- dev speed
- failure detection

## Context

[02_architecture.md](../../02_architecture.md) は Local Kubernetes → ECK Operator → Elasticsearch を Phase 1 の実行トポロジとし、`infra/local/` を担当パスとする。[07_test_strategy.md](../../07_test_strategy.md) は ECK / Elasticsearch / storage / TLS の ready、永続化、再起動、後始末の証跡を要求する。

2026-10-08 の read-only 事前調査では次を確認した。これらは目標バージョンではなく、実行前に再検証する環境スナップショットである。

- WSL2 / Ubuntu 24.04、12 CPU、約15 GiB RAM、約904 GiB disk available
- Docker daemon 29.5.2: reachable
- `kubectl` 1.33.4、`kind` 0.24.0、`helm` 3.18.4: installed
- `vm.max_map_count=1048576`、cgroup v2
- 4 GiB swap: enabled but unused
- kind cluster: none
- kubeconfig current context: none
- ECK / Prometheus CRD and workloads: none
- Helm repositories: none

Local Kubernetes runtime と Kubernetes / ECK / Elasticsearch バージョンは [benchmark-open-decisions.md](../02_backlog/benchmark-open-decisions.md) の OD-006 / OD-007 で確定し、`infra/local/versions.env` を実装上の正本とした。暗黙の latest またはデフォルトバージョンで構築しない。

## Scope

1. 実行時の Docker、CPU / memory / disk、cgroup、`vm.max_map_count`、swap、port conflict を read-only preflight で再検証する。
2. OD-006 / OD-007 で owner が承認した kind、Kubernetes node image、ECK、Elasticsearch の各バージョンを digest または chart version 付きで固定する。
3. project 専用名を持つ kind cluster の設定を `infra/local/` に作成する。
4. 作成・状態確認・teardown を再実行可能な script または Make target として提供する。
5. 変更操作の前に kube context と cluster 名が project 専用 local kind cluster と一致することを強制する。
6. Elastic Helm repository と ECK chart のバージョンを固定し、ECK CRD と Operator を導入する。
7. resource requests / limits と PVC を明示した 1-node Elasticsearch CR を適用する。
8. ECK Operator、Elasticsearch、PVC、TLS Secret、authenticated Elasticsearch API の smoke を実行する。
9. Elasticsearch Pod を1回再作成し、PVC の再接続と cluster / API の回復を観測する。
10. teardown 前の対象表示、teardown、cluster / context / project専用 container が残っていないことの確認手順を実装する。
11. [04_workflows.md](../../04_workflows.md)、[07_test_strategy.md](../../07_test_strategy.md)、[08_release_runbook.md](../../08_release_runbook.md) の未定義コマンドを、実在する実装と観測結果に合わせて更新する。

## Non-scope

- ESCI 取得、embedding、ingest、BM25 / Vector / Hybrid / RRF 実装
- Phase 1 の検索パイプライン E2E 完了
- 3-node Elasticsearch、NodeSet role 分割、shard / replica tuning、node drain
- rolling version upgrade、PVC expansion、snapshot / restore、autoscaling
- Kibana、Prometheus Operator、ServiceMonitor / PodMonitor
- GKE、Vertex AI Vector Search、Terraform、クラウド credential、課金 API
- ローカル環境の性能値を GKE / Vertex 比較の根拠に使うこと
- ホスト全体の swap、Docker daemon、WSL、firewall、DNS 設定の永続変更

## Risk

- 誤った kube context で cluster-scoped CRD / RBAC / webhook を変更する。
- `kind delete cluster` または Helm uninstall で対象外 cluster / resource を破棄する。
- PVC 削除でローカル検証データを失う。
- CRD 削除が ECK-managed resource の連鎖削除を引き起す。
- Elasticsearch / ECK Operator image がメモリを圧迫し、WSL2 または Docker の安定性を落とす。
- swap、single-host topology、kind storage の制約を無視し、ローカル計測値を性能結論に誤用する。
- floating tag / latest chart によって、後日の再実行結果が変わる。
- ECK、Kubernetes、Elastic Stack のバージョン互換性を外す。

## Change Condition

次のいずれかに達したら実装を停止し、task の分割または owner の再承認を得る。

- kube context が project 専用 kind cluster ではない。
- cloud context、cloud credential、billing / quota、secret manager への操作が必要になる。
- `infra/gke/**`、`infra/vertex/**`、`env/secret/**`、`.github/workflows/**` への変更が必要になる。
- host swap / sysctl / Docker daemon / WSL 設定の永続変更が必要になる。
- Kibana、Prometheus Operator、第2の Operator、multi-node Elasticsearch が完了に必須になる。
- ライセンス条件が不明、または Basic 範囲外の機能が必要になる。
- 起動失敗が異なる原因で2回を超える、または同じ原因が2回再発する。
- メモリ圧迫、disk exhaustion、Docker daemon instability が観測される。

## Done Condition

- owner-approved な version matrix と resource budget が repository 内の単一の追跡可能な設定に固定されている。
- clean state から project 専用 kind cluster、ECK Operator、1-node Elasticsearch を手順どおり構築できる。
- Kubernetes node が `Ready`、ECK Operator が `Available`、Elasticsearch resource が利用可能な health へ到達する。
- ECK CRD、PVC `Bound`、TLS Secret、Service、StatefulSet、Elasticsearch Pod の存在と owner reference を確認できる。
- ECK-generated credential / CA を安全に参照し、authenticated API request が成功する。秘密値は log / task / Git に残っていない。
- Elasticsearch Pod 再作成後に同じ PVC が再接続され、cluster / API が回復する。
- teardown が project 専用 cluster だけを対象に完走し、kind cluster、kube context、project専用 container の残存が無い。
- 構築・smoke・復旧・teardown の実コマンドと期待結果が正本 docs へ反映されている。
- GKE / Vertex / performance に関する完了主張を行っていない。

## Owner-only Decisions

active へ移す前に owner が次を承認する。

1. Local Kubernetes runtime に kind を採用するか（OD-006）。
2. kind / Kubernetes node image / `kubectl` / ECK chart / Elasticsearch の正確なバージョンと更新方針（OD-007）。
3. kind topology（single node か control-plane + worker か）。
4. Elasticsearch の CPU / memory request / limit、PVC size、タスク全体のメモリ上限。
5. ECK の cluster-wide Helm install を許可するか。
6. host導入済み `kind` 0.24.0 を更新するか、repo-local toolchain で固定するか。
7. swap を有効のまま機能検証に限定するか。本 task で swap 設定は変更しない。
8. max attempts / max changed files の上限。

## Capability Boundary

### 承認後に許可する capability

- Docker / kind / kubectl / Helm の read-only preflight
- owner-approved な project専用 local kind cluster の作成・照会・破棄
- project専用 local kind context での CRD / RBAC / webhook / namespace / ECK / Elasticsearch resource 操作
- project専用 cluster 内の Pod 再作成とログ / event / status 取得
- ECK-generated Secret の実行時参照（画面・ログ・ファイルに値を永続化しない）

### 禁止 capability

- GKE / Vertex / Terraform / cloud API / billing / quota / IAM / Secret Manager への操作
- project 専用 kind cluster 以外への `kubectl apply/delete`、Helm install/uninstall、CRD 操作
- Docker、WSL、OS、swap、firewall、DNS の永続設定変更
- 解決済み対象名を伴わない再帰削除、glob 削除、`git reset --hard`、`git clean -fdx`
- credential / Secret 値の Git、task、log、shell history への保存

## Allowed Paths

owner approval 後、次のパスだけを変更対象とする。

- `infra/local/**`
- `scripts/**`（local cluster lifecycle / smoke 用のみ）
- `Makefile`（上記 script への薄い entrypoint のみ）
- `docs/04_workflows.md`
- `docs/07_test_strategy.md`
- `docs/08_release_runbook.md`
- `docs/tasks/02_backlog/benchmark-open-decisions.md`（OD-006 / OD-007 の決定反映のみ）
- この task file（状態移動後の同一ファイルを含む）

## Forbidden Paths

- `infra/gke/**`
- `infra/vertex/**`
- `**/terraform/**`
- `env/secret/**`
- `.github/workflows/**`
- `src/dataset/**`
- `src/embedding/**`
- `src/ingest/**`
- `src/retrieval/**`
- `src/evaluation/**`
- `src/benchmark/**`
- `results/**`
- その他、Allowed Paths に明記していないパス

## Rollback Trigger

次のいずれかを観測したら新規操作を停止し、証跡取得後に project 専用 local cluster の teardown を行う。

- context guard 不一致、対象 cluster 名の不一致
- 対象外 resource、cluster、Docker container への変更検知
- WSL2 / Docker のメモリ圧迫、disk exhaustion、daemon instability
- ECK / Elasticsearch が制限時間内に ready へ到達しない
- PVC / Secret / CRD の予期しない削除または連鎖操作
- 秘密情報が log、Git diff、task evidence に現れる

ロールバック時は、失敗時の `kubectl get` / `describe` / event / Operator log を秘密値なしで保存し、対象を明示して project 専用 kind cluster を破棄する。対象外 cluster / context / container に影響が無いことを再取得する。

## Evidence Required

Evidence Level 4 として、次を task の Verification に残す。この task は local-only であり、本番稼働の証明は行わない。

- owner approval と Owner-only Decisions の確定値
- `docker version`、`kind version`、`kubectl version --client`、`helm version`、CPU / memory / disk / swap / `vm.max_map_count` の preflight 出力
- 実際に使った kind node image digest、Helm chart version、ECK / Elasticsearch version
- 作成前の `kind get clusters`、`kubectl config get-contexts`、Docker container 一覧
- kind node `Ready`、ECK Operator `Available`、Elasticsearch health / status の実測
- ECK CRD、PVC `Bound`、TLS Secret、Service、StatefulSet、Pod の存在確認
- credential 値を出力しない authenticated Elasticsearch API smoke の status / body 要約
- Pod 再作成前後の UID、PVC、cluster health、API 回復の実測
- teardown 対象の事前一覧と、実行後に project 専用 cluster / context / container が0件である実測
- 対象外 cluster / context / container の不変証跡
- `git diff --check`、実装された lint / test / smoke command の完走結果
- 実行できなかった検証、failed / invalid 操作、残るリスクの明記

すべての PASS にコマンド出力または `file:line` を紐付ける。実測していない項目は PASS ではなく `UNVERIFIED` とする。

## Verification

2026-10-08、WSL2 / Ubuntu 24.04 上で Evidence Level 4 を取得した。Secret は名前だけを記録し、値は保存していない。

### PASS

- owner approval: 本文の「Approval and fixed decisions」に記録。変更は24 file上限内（20 logical files）、`infra/local/**` と許可済みdocs / Makefileだけ。
- `make local-preflight`: Docker reachable、kind 0.33.0、kubectl 1.33.4、Helm 3.18.4、available memory 13033 MiB、disk 905 GiB、`vm.max_map_count=1048576`、swap 4096 MiB free。開始時 kind cluster / current context は無し。
- `sha256sum infra/local/.bin/kind`: `aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d` で `infra/local/versions.env` と一致。
- clean-state `make local-up`: `kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d`、Kubernetes v1.34.11、ECK chart / image 3.5.0、Elasticsearch 9.5.5 で構築成功。
- `make local-up` 再実行: Helm release revision 2、namespace unchanged、Elasticsearch configured、全resource ready。宣言状態への再 reconcile 成功。
- runtime inventory: node `Ready`、`elastic-operator-0` `1/1 Running`、Elasticsearch `Ready` / `green` / 1 node、Pod `1/1 Running`、StatefulSet `1/1`、PVC `Bound` / 5 GiB。
- `helm --kube-context kind-vector-search-benchmark list -n elastic-system`: `eck-operator-3.5.0` / app version 3.5.0 / `deployed`。
- `kubectl get crd`: `elasticsearches.elasticsearch.k8s.elastic.co` を含む12個のECK CRDを確認。
- owner reference: StatefulSetとPVCはいずれも `Elasticsearch/benchmark` をownerに持つ。Service、ECK生成TLS / credential Secretの存在を確認。
- `make local-smoke`: ECK Operator ready、PVC Bound、TLS Secret存在、ECK生成CAによるTLS検証、authenticated API HTTP 200、settle window後もhealth `green`。`local-infra-smoke` markerを保存。
- `make local-verify-recovery`（最終 v1.34.11 cluster）: Pod UID `15372810-7a9d-417a-a86f-0842e9eeb5cb` → `34117f1d-af78-4005-a1b4-457f932f5908`。PVC `elasticsearch-data-benchmark-es-default-0` は同名 / `Bound`、marker存続、API回復、health `green`。
- `make local-down`: 削除対象を表示後、専用 cluster / kube context / Docker node container が0件。続く `make local-up` でclean stateから再構築し、最終的にclusterを稼働状態で残した。
- 対象外不変: 構築前に他kind cluster / kube contextは存在せず、GKE / Vertex / Terraform / cloud credentialへの操作は0件。
- 実装と運用手順: `Makefile`、`infra/local/`、`docs/04_workflows.md`、`docs/07_test_strategy.md`、`docs/08_release_runbook.md`、OD-006 / OD-007へ反映。
- final validation: `bash -n`、KUBECONFIGを空にしたwrong-context拒否、Kubernetes server-side dry-run、kubectl client v1.33.4 / server v1.34.11 skew確認、`git diff --check`、秘密情報pattern scanがPASS。`make local-status`で最終clusterのgreenを再観測。

### Failed / invalid attempts and corrections

- 初回smokeはport-forward先を証明書SAN外のIP / `localhost`として検証しHTTP 000。service DNSを`curl --resolve`で127.0.0.1へ向け、ECK CAでSANを含め完全検証するよう修正した。
- 初回marker indexはdefault replica=1でsingle-node clusterをyellowにした。local-only smokeで既存indexをreplica=0へ正規化し、system index作成後のsettle windowでもgreenを再確認するよう修正した。
- 当初選んだKubernetes v1.35.8はhost kubectl v1.33.4とのminor skew警告を検出。v1.34.11 digestへ下げて再構築し、+1 minorへ収めた。v1.35.8での結果は最終evidenceから除外した。

### Remaining risks / limits

- single-node、swap enabled、kind local-path storageであり、性能・HA・GKE相当性の証拠には使えない。
- `local-smoke` のreplica=0正規化はこの専用local clusterだけが対象。multi-node / GKEへ流用しない。
- Kibana、Prometheus Operator、rolling upgrade、PVC resize、snapshot / restore、multi-node / node drainは本taskでは未検証。
