#!/usr/bin/env bash
set -euo pipefail
DIR="${1:-release-assets}"
cd "$DIR"
find . -maxdepth 1 -type f ! -name 'SHA256SUMS.txt' -printf '%f\n' | LC_ALL=C sort | while read -r f; do sha256sum "$f"; done > SHA256SUMS.txt
echo "SHA256SUMS.txt gerado com $(wc -l < SHA256SUMS.txt) entradas."
