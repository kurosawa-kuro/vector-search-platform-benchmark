#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

[[ -x "${KIND_BIN}" ]] || die "pinned kind is missing; run make local-bootstrap"
cluster_exists || die "kind cluster does not exist: ${CLUSTER_NAME}"

printf 'context: %s\n' "${KUBE_CONTEXT}"
kubectl --context "${KUBE_CONTEXT}" get nodes -o wide
kubectl --context "${KUBE_CONTEXT}" -n "${ECK_NAMESPACE}" get pods
kubectl --context "${KUBE_CONTEXT}" -n "${ELASTIC_NAMESPACE}" \
  get elasticsearch,pods,pvc,services,statefulsets

