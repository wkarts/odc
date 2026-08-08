#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
VERSION="${2:-}"
ASSET_DIR="${3:-release-assets}"
MODE="${4:-auto}"

[[ -n "$TAG" ]] || { echo 'TAG não informada.' >&2; exit 2; }
[[ -n "$VERSION" ]] || { echo 'VERSION não informada.' >&2; exit 2; }
[[ "$TAG" == "v$VERSION" ]] || { echo "Contrato inválido: TAG=$TAG VERSION=$VERSION" >&2; exit 2; }
[[ -d "$ASSET_DIR" ]] || { echo "Diretório de assets ausente: $ASSET_DIR" >&2; exit 2; }
[[ -s "$ASSET_DIR/SHA256SUMS.txt" ]] || { echo 'SHA256SUMS.txt ausente.' >&2; exit 2; }
[[ -s "$ASSET_DIR/release-manifest.json" ]] || { echo 'release-manifest.json ausente.' >&2; exit 2; }
command -v git >/dev/null || { echo 'git não encontrado.' >&2; exit 3; }
command -v gh >/dev/null || { echo 'gh não encontrado.' >&2; exit 3; }

HEAD_SHA="$(git rev-parse HEAD)"
git fetch --force --tags origin

TAG_EXISTS=false
TAG_SHA=''
if git rev-parse -q --verify "refs/tags/$TAG^{commit}" >/dev/null 2>&1; then
  TAG_EXISTS=true
  TAG_SHA="$(git rev-list -n 1 "$TAG")"
fi

if [[ "$TAG_EXISTS" == true && "$TAG_SHA" != "$HEAD_SHA" ]]; then
  MESSAGE="VERSION $VERSION já está vinculada à tag $TAG no commit $TAG_SHA; HEAD atual é $HEAD_SHA. Incremente VERSION para uma nova release."
  if [[ "$MODE" == auto ]]; then
    echo "::warning::$MESSAGE"
    {
      echo '## Release não publicada'
      echo
      echo "$MESSAGE"
      echo
      echo 'O build foi concluído normalmente; a publicação foi preservada para manter a tag imutável.'
    } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
    exit 0
  fi
  echo "$MESSAGE" >&2
  exit 1
fi

if [[ "$TAG_EXISTS" == false ]]; then
  git config user.name 'github-actions[bot]'
  git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
  git tag -a "$TAG" "$HEAD_SHA" -m "ODC SDK $VERSION"
  git push origin "refs/tags/$TAG"
fi

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG já existe; atualizando assets de forma idempotente."
  gh release upload "$TAG" "$ASSET_DIR"/* --clobber
else
  args=(
    release create "$TAG"
    "$ASSET_DIR"/*
    --title "ODC SDK $VERSION"
    --generate-notes
    --verify-tag
  )
  [[ "$VERSION" == *-* ]] && args+=(--prerelease)
  gh "${args[@]}"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## ODC SDK $VERSION publicado"
    echo
    echo "- Tag: \`$TAG\`"
    echo "- Commit: \`$HEAD_SHA\`"
    echo "- Assets: $(find "$ASSET_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')"
    echo '- Manifesto: `release-manifest.json`'
    echo '- Checksums: `SHA256SUMS.txt`'
  } >> "$GITHUB_STEP_SUMMARY"
fi
