#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

require_command curl
require_command sha256sum

[[ "$(uname -m)" == "x86_64" ]] || die "only linux/amd64 is pinned in versions.env"

mkdir -p "$(dirname "${KIND_BIN}")"

if [[ -x "${KIND_BIN}" ]] && [[ "$("${KIND_BIN}" version -q)" == "${KIND_VERSION#v}" ]]; then
  printf 'kind %s is already installed at %s\n' "${KIND_VERSION}" "${KIND_BIN}"
  exit 0
fi

tmp_file="$(mktemp "${KIND_BIN}.download.XXXXXX")"
trap 'rm -f -- "${tmp_file}"' EXIT

curl --fail --location --silent --show-error \
  "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64" \
  --output "${tmp_file}"
printf '%s  %s\n' "${KIND_LINUX_AMD64_SHA256}" "${tmp_file}" | sha256sum --check --status || \
  die "kind binary checksum mismatch"
chmod 0755 "${tmp_file}"
mv -- "${tmp_file}" "${KIND_BIN}"
trap - EXIT

printf 'installed kind %s at %s\n' "${KIND_VERSION}" "${KIND_BIN}"
