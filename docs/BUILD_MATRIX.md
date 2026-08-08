# Matriz de Build ODC 1.0.0

| Família | Linux x64 | Linux arm64 | Windows x86 | Windows x64 | Windows arm64 | macOS x64 | macOS arm64 | Forma |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Go CLI | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | binário nativo |
| Rust CLI | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | binário nativo |
| .NET CLI | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | self-contained/single-file |
| .NET Studio | — | — | ✓ | ✓ | ✓ | — | — | WinForms self-contained |
| Tauri Studio | ✓ | ✓ | — | ✓ | ✓ | ✓ | ✓ | executável desktop portátil |
| PowerShell Studio | — | — | ✓ | ✓ | ✓ | — | — | launcher EXE + WinForms |
| Delphi CLI/Studio | — | — | ✓ | ✓ | — | — | — | runner self-hosted Delphi |
| PHP/Laravel | plataforma independente | | | | | | | PHAR + source ZIP |
| Node.js | plataforma independente | | | | | | | pacote NPM `.tgz` |
| TypeScript | navegador/Node | | | | | | | pacote NPM `.tgz` |
| Studio Web | navegador offline | | | | | | | ZIP estático |
| Shell | Unix/POSIX com ferramentas requeridas | | | | | | | TAR.GZ |

A matriz pode ser estendida sem modificar o wire format ODC1.


## Novos Studios 1.1.0

| Studio | Plataforma | Artefato |
|---|---|---|
| PHP | qualquer SO com PHP 8.1+ | `odc-studio-php-1.1.0.zip` |
| HTML/JavaScript | navegador moderno | `odc-studio-html-js-1.1.0.zip` |
