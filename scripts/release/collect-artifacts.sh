#!/usr/bin/env bash
set -euo pipefail
SRC="${1:-artifacts}"
DST="${2:-release-assets}"
rm -rf "$DST"; mkdir -p "$DST"
find "$SRC" -type f | while read -r f; do
  base="$(basename "$f")"
  if [[ -e "$DST/$base" ]]; then echo "Colisão de asset: $base" >&2; exit 1; fi
  cp "$f" "$DST/$base"
done
count="$(find "$DST" -maxdepth 1 -type f | wc -l)"
[[ "$count" -gt 0 ]] || { echo 'Nenhum asset coletado.' >&2; exit 1; }
echo "$count assets coletados."
