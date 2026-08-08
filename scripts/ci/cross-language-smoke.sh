#!/usr/bin/env bash
set -euo pipefail
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp test-vectors/hello.txt "$WORK/input.txt"
printf '{"suite":"cross-language","version":1}\n' > "$WORK/meta.json"

# PHP cria.
php php-laravel/bin/odc create "$WORK/input.txt" "$WORK/php.odc" "$WORK/meta.json"
php php-laravel/bin/odc verify "$WORK/php.odc"

# Node lê/extrai o mesmo ODC.
node nodejs/bin/odc.js info "$WORK/php.odc" > "$WORK/node-info.json"
node nodejs/bin/odc.js extract "$WORK/php.odc" "$WORK/node-out.txt"
cmp "$WORK/input.txt" "$WORK/node-out.txt"

# Go lê/extrai o mesmo ODC.
go -C golang run ./cmd/odc info "$WORK/php.odc" > "$WORK/go-info.json"
go -C golang run ./cmd/odc extract "$WORK/php.odc" "$WORK/go-out.txt"
cmp "$WORK/input.txt" "$WORK/go-out.txt"

echo 'Interop PHP -> Node.js -> Go aprovada.'
