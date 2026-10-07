#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

"${SCRIPT_DIR}/bootstrap-kind.sh"
"${SCRIPT_DIR}/preflight.sh"

if ! cluster_exists; then
  "${KIND_BIN}" create cluster \
    --name "${CLUSTER_NAME}" \
    --image "${KIND_NODE_IMAGE}" \
    --config "${SCRIPT_DIR}/kind.yaml" \
    --wait 180s
else
  printf 'kind cluster %s already exists; reconciling it\n' "${CLUSTER_NAME}"
fi

require_target_context

helm repo add elastic https://helm.elastic.co --force-update
helm repo update elastic
helm upgrade --install elastic-operator elastic/eck-operator \
  --kube-context "${KUBE_CONTEXT}" \
  --namespace "${ECK_NAMESPACE}" \
  --create-namespace \
  --version "${ECK_VERSION}" \
  --values "${SCRIPT_DIR}/eck-values.yaml" \
  --wait \
  --timeout 5m

kubectl --context "${KUBE_CONTEXT}" apply -f "${SCRIPT_DIR}/namespace.yaml"
sed "s/__ELASTICSEARCH_VERSION__/${ELASTICSEARCH_VERSION}/g" \
  "${SCRIPT_DIR}/elasticsearch.yaml.tpl" | \
  kubectl --context "${KUBE_CONTEXT}" apply -f -

kubectl --context "${KUBE_CONTEXT}" -n "${ECK_NAMESPACE}" \
  rollout status statefulset/elastic-operator --timeout=5m
wait_for_elasticsearch
"${SCRIPT_DIR}/smoke.sh"

printf '\nLocal ECK foundation is ready.\n'
"${SCRIPT_DIR}/status.sh"
