# CI/CD GitHub — ODC SDK

A estrutura foi desenhada para um repositório GitHub único e multi-linguagem.

## Fluxos

- `ci.yml`: validações em pull request e push.
- `build.yml`: build manual/branch de todos os artefatos sem criar Release.
- `build-assets.yml`: workflow reutilizável que produz os pacotes de release.
- `release.yml`: ao publicar a tag `v<conteúdo de VERSION>`, recompila, reúne os assets, gera SHA-256/manifesto e cria a GitHub Release.
- `delphi-self-hosted.yml`: build Delphi VCL em runner Windows self-hosted com Delphi instalado/licenciado; pode anexar os binários à release existente.
- `security.yml`: CodeQL para linguagens suportadas pelo CodeQL usadas no repositório.

## Regra de versão

`VERSION` é a fonte canônica. Uma release `v1.0.0` só passa se `VERSION` contiver `1.0.0`.

## Artefatos

O release gera CLIs nativas (Go, Rust, .NET), Studio .NET, Studio Tauri, Studio PowerShell, PHAR PHP, pacotes Node/TypeScript, Studio Web, shell e pacote-fonte completo.

## Delphi

O compilador Delphi não é fornecido nos runners hospedados do GitHub e exige licença. Defina a variável do repositório `ODC_DELPHI_ENABLED=true` para incluir automaticamente Delphi no build/release usando um runner `self-hosted, Windows, X64, delphi`. O workflow manual `delphi-self-hosted.yml` também permanece disponível. Veja `docs/DELPHI_RUNNER.md`.

## Segurança da Release

O job final usa `permissions: contents: write`, `gh release` e `GITHUB_TOKEN`. Os jobs de build usam apenas `contents: read`. Os assets recebem `SHA256SUMS.txt` e `release-manifest.json`.

## Studios PHP e HTML/JavaScript

A partir do SDK 1.1.0, a matriz de release publica também:

- `odc-studio-php-<versão>.zip`: Studio web local em PHP, sem banco de dados;
- `odc-studio-html-js-<versão>.zip`: Studio estático, offline, sem backend.

Os dois são validados no job `studios` do workflow `ci.yml`. O Studio PHP recebe ainda um smoke test HTTP com o servidor embutido do PHP.
