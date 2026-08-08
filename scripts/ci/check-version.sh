#!/usr/bin/env bash
set -euo pipefail
VERSION="$(tr -d '[:space:]' < VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] || { echo "VERSION inválida: $VERSION" >&2; exit 1; }
if [[ -n "${GITHUB_REF_NAME:-}" && "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
  [[ "${GITHUB_REF_NAME}" == "v${VERSION}" ]] || { echo "Tag ${GITHUB_REF_NAME} difere de VERSION v${VERSION}" >&2; exit 1; }
fi
echo "Contrato de versão ${VERSION} aprovado."
