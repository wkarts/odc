#!/usr/bin/env bash
set -euo pipefail
VERSION="$(tr -d '[:space:]' < VERSION)"
OUT="${1:-dist/source}"
mkdir -p "$OUT"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
NAME="odc-sdk-${VERSION}"
mkdir -p "$TMP/$NAME"
rsync -a --exclude '.git' --exclude 'dist' --exclude 'release-assets' --exclude 'bin/*' --exclude '**/node_modules' --exclude '**/target' ./ "$TMP/$NAME/"
( cd "$TMP" && zip -qr "$OLDPWD/$OUT/${NAME}-source.zip" "$NAME" )
( cd "$TMP" && tar -czf "$OLDPWD/$OUT/${NAME}-source.tar.gz" "$NAME" )
echo "Pacotes-fonte gerados em $OUT"
