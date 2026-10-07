#!/usr/bin/env bash

set -euo pipefail

LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${LOCAL_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${LOCAL_DIR}/versions.env"

KIND_BIN="${LOCAL_DIR}/.bin/kind"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

cluster_exists() {
  "${KIND_BIN}" get clusters 2>/dev/null | grep -Fxq "${CLUSTER_NAME}"
}

require_target_context() {
  cluster_exists || die "kind cluster does not exist: ${CLUSTER_NAME}"

  local current_context
  current_context="$(kubectl config current-context 2>/dev/null || true)"
  [[ "${current_context}" == "${KUBE_CONTEXT}" ]] || die \
    "refusing mutation: current context '${current_context:-<none>}' is not '${KUBE_CONTEXT}'"

  kubectl --context "${KUBE_CONTEXT}" cluster-info >/dev/null
}

wait_for_elasticsearch() {
  local deadline phase health
  deadline=$((SECONDS + 600))

  while (( SECONDS < deadline )); do
    phase="$(kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
      get elasticsearch "${ELASTICSEARCH_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    health="$(kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
      get elasticsearch "${ELASTICSEARCH_NAME}" -o jsonpath='{.status.health}' 2>/dev/null || true)"
    if [[ "${phase}" == "Ready" && "${health}" != "red" && -n "${health}" ]]; then
      return 0
    fi
    sleep 5
  done

  kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
    get elasticsearch,pods,pvc,services,statefulsets >&2 || true
  die "Elasticsearch did not reach Ready with non-red health within 10 minutes"
}

start_port_forward() {
  local log_file="$1"
  kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
    port-forward "service/${ELASTICSEARCH_NAME}-es-http" 9200:9200 >"${log_file}" 2>&1 &
  PORT_FORWARD_PID=$!

  local deadline
  deadline=$((SECONDS + 30))
  while (( SECONDS < deadline )); do
    # This loop only verifies that the forwarded socket accepts HTTPS. The
    # authenticated request below performs full validation with the ECK CA.
    if curl --insecure --silent --show-error --output /dev/null https://localhost:9200 2>/dev/null; then
      return 0
    fi
    if ! kill -0 "${PORT_FORWARD_PID}" 2>/dev/null; then
      sed -n '1,80p' "${log_file}" >&2
      die "kubectl port-forward exited before becoming ready"
    fi
    sleep 1
  done
  die "kubectl port-forward did not become ready within 30 seconds"
}

authenticated_request() {
  local method="$1"
  local path="$2"
  local output_file="$3"
  local data="${4:-}"
  local password ca_file http_status service_host

  password="$(kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
    get secret "${ELASTICSEARCH_NAME}-es-elastic-user" \
    -o go-template='{{.data.elastic | base64decode}}')"
  ca_file="$(mktemp)"
  kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
    get secret "${ELASTICSEARCH_NAME}-es-http-certs-public" \
    -o go-template='{{index .data "ca.crt" | base64decode}}' >"${ca_file}"

  service_host="${ELASTICSEARCH_NAME}-es-http.${ELASTIC_NAMESPACE}.svc"

  local curl_args=(
    --silent --show-error
    --cacert "${ca_file}"
    --noproxy '*'
    --resolve "${service_host}:9200:127.0.0.1"
    --user "elastic:${password}"
    --request "${method}"
    --output "${output_file}"
    --write-out '%{http_code}'
  )
  if [[ -n "${data}" ]]; then
    curl_args+=(--header 'Content-Type: application/json' --data "${data}")
  fi
  http_status="$(curl "${curl_args[@]}" "https://${service_host}:9200${path}")"

  password=''
  rm -f -- "${ca_file}"
  printf '%s' "${http_status}"
}
