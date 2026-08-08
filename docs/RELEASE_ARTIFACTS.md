# Contrato de artefatos de Release

Principais famílias:

- `odc-go-<versão>-<os>-<arch>` — CLI Go nativa.
- `odc-rust-<versão>-<os>-<arch>` — CLI Rust nativa.
- `odc-dotnet-<versão>-<rid>` — CLI .NET self-contained single-file.
- `odc-studio-dotnet-<versão>-<rid>` — Studio WinForms .NET.
- `odc-studio-tauri-<versão>-<plataforma>` — Studio Tauri/Rust portátil.
- `odc-studio-powershell-<versão>-win-<arch>` — Studio WinForms PowerShell encapsulado em launcher .exe.
- `odc-php-<versão>.phar` — CLI PHP portátil (requer PHP >= 8.1).
- `argws-odc-<versão>.tgz` — pacote Node.js.
- `argws-odc-web-<versão>.tgz` — biblioteca TypeScript/web.
- `odc-studio-web-<versão>.zip` — Studio Web totalmente local/offline.
- `odc-shell-<versão>.tar.gz` — implementação Shell.
- `odc-sdk-<versão>-source.{zip,tar.gz}` — pacote-fonte completo.
- `SHA256SUMS.txt` e `release-manifest.json` — integridade e inventário.

Delphi é publicado pelo workflow self-hosted, pois depende de toolchain licenciada.

- `odc-studio-php-1.1.0.zip` — Studio PHP local e biblioteca ODC PHP necessária.
- `odc-studio-html-js-1.1.0.zip` — Studio estático HTML/JavaScript puro, offline.
