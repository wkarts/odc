#!/usr/bin/env bash
set -euo pipefail
required=(
  VERSION SPECIFICATION.md README.md SECURITY.md
  php-laravel/src/OdcContainer.php
  delphi/OdcContainer.pas
  rust-tauri/src/lib.rs
  nodejs/src/odc.js
  csharp-dotnet/Odc/OdcContainer.cs
  golang/odc/odc.go
  typescript/src/odc.ts
  shell/odc.sh
  powershell/Odc.Core.ps1
  test-vectors/hello.odc
)
for f in "${required[@]}"; do
  [[ -f "$f" ]] || { echo "Arquivo obrigatório ausente: $f" >&2; exit 1; }
done
printf 'ODC1' | cmp -n 4 - test-vectors/hello.odc >/dev/null || { echo 'Vetor hello.odc não possui magic ODC1' >&2; exit 1; }
echo 'Árvore e vetor canônico validados.'
