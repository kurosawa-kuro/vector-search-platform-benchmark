#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

[[ -x "${KIND_BIN}" ]] || die "pinned kind is missing; run make local-bootstrap"

if ! cluster_exists; then
  kubectl config get-contexts -o name | grep -Fxq "${KUBE_CONTEXT}" && \
    die "kind cluster is absent but project kube context remains: ${KUBE_CONTEXT}"
  docker ps --all --format '{{.Names}}' | grep -Fxq "${CLUSTER_NAME}-control-plane" && \
    die "kind cluster is absent but project node container remains"
  printf 'kind cluster %s is absent; project context and node container are also absent\n' "${CLUSTER_NAME}"
  exit 0
fi

require_target_context
printf 'The following project-local resources will be deleted with cluster %s:\n' "${CLUSTER_NAME}"
kubectl --context "${KUBE_CONTEXT}" get namespaces
kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
  get elasticsearch,pods,pvc,services,statefulsets 2>/dev/null || true

"${KIND_BIN}" delete cluster --name "${CLUSTER_NAME}"

cluster_exists && die "kind cluster still exists after teardown"
kubectl config get-contexts -o name | grep -Fxq "${KUBE_CONTEXT}" && die "kube context still exists after teardown"
docker ps --all --format '{{.Names}}' | grep -Fxq "${CLUSTER_NAME}-control-plane" && \
  die "project kind container still exists after teardown"

printf 'PASS: project kind cluster, kube context, and node container are absent.\n'
