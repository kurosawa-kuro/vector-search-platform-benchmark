#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

for command_name in kubectl curl jq; do
  require_command "${command_name}"
done
require_target_context
wait_for_elasticsearch

kubectl --context "${KUBE_CONTEXT}" -n "${ECK_NAMESPACE}" \
  wait --for=jsonpath='{.status.readyReplicas}'=1 statefulset/elastic-operator --timeout=60s
[[ "$(kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
  get pvc -l 'elasticsearch.k8s.elastic.co/cluster-name=benchmark' \
  -o jsonpath='{.items[0].status.phase}')" == "Bound" ]] || die "Elasticsearch PVC is not Bound"

for secret_name in \
  "${ELASTICSEARCH_NAME}-es-elastic-user" \
  "${ELASTICSEARCH_NAME}-es-http-certs-public"; do
  kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" get secret "${secret_name}" >/dev/null
done

tmp_dir="$(mktemp -d)"
PORT_FORWARD_PID=''
cleanup() {
  if [[ -n "${PORT_FORWARD_PID}" ]]; then
    kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    wait "${PORT_FORWARD_PID}" 2>/dev/null || true
  fi
  rm -rf -- "${tmp_dir}"
}
trap cleanup EXIT

start_port_forward "${tmp_dir}/port-forward.log"

# A dedicated one-node development cluster cannot allocate replicas. Normalize
# all existing local indices, including ECK-created system indices, before
# enforcing the green baseline. This setting is intentionally local-only.
status="$(authenticated_request PUT '/_all/_settings?expand_wildcards=all' \
  "${tmp_dir}/single-node-settings.json" '{"index":{"number_of_replicas":0}}')"
[[ "${status}" == "200" ]] || die "single-node index settings request returned HTTP ${status}"
status="$(authenticated_request GET '/_cluster/health' "${tmp_dir}/health.json")"
[[ "${status}" == "200" ]] || die "authenticated cluster health request returned HTTP ${status}"
[[ "$(jq -r '.status' "${tmp_dir}/health.json")" == "green" ]] || die "cluster health is not green"

status="$(authenticated_request PUT '/local-infra-smoke/_doc/persistence-marker?refresh=true' \
  "${tmp_dir}/index.json" '{"purpose":"pvc-recovery-check"}')"
[[ "${status}" == "200" || "${status}" == "201" ]] || die "marker write returned HTTP ${status}"

# A one-node cluster cannot allocate the default replica. Keep this smoke-only
# index replica-free so the cluster remains green after the marker is written.
status="$(authenticated_request PUT '/local-infra-smoke/_settings' \
  "${tmp_dir}/settings.json" '{"index":{"number_of_replicas":0}}')"
[[ "${status}" == "200" ]] || die "smoke index settings request returned HTTP ${status}"
status="$(authenticated_request GET '/_cluster/health?wait_for_status=green&timeout=30s' \
  "${tmp_dir}/health-after-write.json")"
[[ "${status}" == "200" ]] || die "post-write cluster health request returned HTTP ${status}"
[[ "$(jq -r '.status' "${tmp_dir}/health-after-write.json")" == "green" ]] || \
  die "cluster health is not green after marker write"

# ECK/Elasticsearch can create a system index just after the first authenticated
# request. Let that converge, normalize any newly-created index, and require a
# second green observation before declaring the environment ready.
sleep 10
status="$(authenticated_request PUT '/_all/_settings?expand_wildcards=all' \
  "${tmp_dir}/settled-settings.json" '{"index":{"number_of_replicas":0}}')"
[[ "${status}" == "200" ]] || die "settled single-node index settings request returned HTTP ${status}"
status="$(authenticated_request GET '/_cluster/health?wait_for_status=green&timeout=30s' \
  "${tmp_dir}/settled-health.json")"
[[ "${status}" == "200" ]] || die "settled cluster health request returned HTTP ${status}"
[[ "$(jq -r '.status' "${tmp_dir}/settled-health.json")" == "green" ]] || \
  die "cluster health did not settle at green"

printf 'PASS: ECK operator ready, PVC Bound, TLS secrets present, authenticated API HTTP 200, cluster green.\n'
printf 'PASS: replica-free persistence marker indexed; cluster remained green after settle window.\n'
