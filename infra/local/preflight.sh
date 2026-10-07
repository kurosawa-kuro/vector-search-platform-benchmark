#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

for command_name in docker kubectl helm curl jq awk df grep; do
  require_command "${command_name}"
done
[[ -x "${KIND_BIN}" ]] || die "pinned kind is missing; run make local-bootstrap"
[[ "$("${KIND_BIN}" version -q)" == "${KIND_VERSION#v}" ]] || die "pinned kind version mismatch"

docker info >/dev/null 2>&1 || die "Docker daemon is not reachable"

available_kib="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
(( available_kib >= 6 * 1024 * 1024 )) || die "at least 6 GiB available memory is required"

available_disk_kib="$(df -Pk "${REPO_ROOT}" | awk 'NR == 2 {print $4}')"
(( available_disk_kib >= 20 * 1024 * 1024 )) || die "at least 20 GiB free disk is required"

map_count="$(sysctl -n vm.max_map_count)"
(( map_count >= 262144 )) || die "vm.max_map_count must be at least 262144 (found ${map_count})"

printf 'docker: reachable\n'
printf 'kind: %s\n' "$("${KIND_BIN}" version -q)"
printf 'kubectl: %s\n' "$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
printf 'helm: %s\n' "$(helm version --short)"
printf 'available memory: %s MiB\n' "$((available_kib / 1024))"
printf 'available disk: %s GiB\n' "$((available_disk_kib / 1024 / 1024))"
printf 'vm.max_map_count: %s\n' "${map_count}"
printf 'swap: '
awk '/SwapTotal:/ {printf "%s MiB total", int($2 / 1024)} /SwapFree:/ {printf ", %s MiB free\n", int($2 / 1024)}' /proc/meminfo
printf 'existing kind clusters:\n'
"${KIND_BIN}" get clusters 2>/dev/null || true
printf 'current kube context: %s\n' "$(kubectl config current-context 2>/dev/null || printf '<none>')"

if cluster_exists; then
  actual_node_image="$(docker inspect --format '{{.Config.Image}}' "${CLUSTER_NAME}-control-plane")"
  [[ "${actual_node_image}" == "${KIND_NODE_IMAGE}" ]] || die \
    "existing cluster uses '${actual_node_image}', expected '${KIND_NODE_IMAGE}'; run make local-down before upgrading"
  printf 'existing node image: %s\n' "${actual_node_image}"
fi
