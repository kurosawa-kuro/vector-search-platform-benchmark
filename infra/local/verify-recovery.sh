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

pod_name="$(kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
  get pod -l "elasticsearch.k8s.elastic.co/cluster-name=${ELASTICSEARCH_NAME}" \
  -o jsonpath='{.items[0].metadata.name}')"
old_uid="$(kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
  get pod "${pod_name}" -o jsonpath='{.metadata.uid}')"
pvc_name="$(kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
  get pvc -l "elasticsearch.k8s.elastic.co/cluster-name=${ELASTICSEARCH_NAME}" \
  -o jsonpath='{.items[0].metadata.name}')"

printf 'recreating pod %s (uid=%s, pvc=%s)\n' "${pod_name}" "${old_uid}" "${pvc_name}"
kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" delete pod "${pod_name}" --wait=true

deadline=$((SECONDS + 600))
new_uid=''
while (( SECONDS < deadline )); do
  new_uid="$(kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
    get pod "${pod_name}" -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
  if [[ -n "${new_uid}" && "${new_uid}" != "${old_uid}" ]]; then
    break
  fi
  sleep 3
done
[[ -n "${new_uid}" && "${new_uid}" != "${old_uid}" ]] || die "replacement pod was not observed"

kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
  wait --for=condition=Ready "pod/${pod_name}" --timeout=10m
wait_for_elasticsearch

[[ "$(kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
  get pvc "${pvc_name}" -o jsonpath='{.status.phase}')" == "Bound" ]] || die "original PVC is not Bound"

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
status="$(authenticated_request GET '/local-infra-smoke/_doc/persistence-marker' "${tmp_dir}/marker.json")"
[[ "${status}" == "200" ]] || die "persistence marker request returned HTTP ${status}"
[[ "$(jq -r '.found' "${tmp_dir}/marker.json")" == "true" ]] || die "persistence marker was not found"
status="$(authenticated_request GET '/_cluster/health?wait_for_status=green&timeout=30s' \
  "${tmp_dir}/health.json")"
[[ "${status}" == "200" ]] || die "recovered cluster health request returned HTTP ${status}"
[[ "$(jq -r '.status' "${tmp_dir}/health.json")" == "green" ]] || die "recovered cluster health is not green"

printf 'PASS: pod UID changed from %s to %s.\n' "${old_uid}" "${new_uid}"
printf 'PASS: PVC %s remained Bound and the persisted marker survived.\n' "${pvc_name}"
