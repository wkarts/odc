# Validação executada neste pacote

Ambiente de preparação: Linux.

Executado com sucesso antes da entrega:

- PHP 8.4: lint, create, verify, extract e geração/execução do PHAR.
- Node.js 22: sintaxe, leitura e verify dos vetores ODC.
- Go 1.23: `gofmt`, `go vet`, `go test`, build e interoperabilidade com PHP/Node.
- Go cross-build: Linux x64/arm64, Windows x86/x64/arm64 e macOS x64/arm64.
- TypeScript: compilação da biblioteca ODC e do Studio Web.
- Studio HTML/JavaScript puro: create/info/verify/extract/setMetadata com round-trip byte a byte.
- Studio PHP: lint e fluxo HTTP completo create/info/verify/extract/set-meta/remove-meta via servidor PHP local.
- Shell/Bash: validação sintática e leitura do vetor canônico.
- PowerShell Studio launcher: cross-compilado como PE Windows x86, x64 e arm64 usando o launcher Go; a GUI WinForms em si requer Windows para execução.
- Workflows GitHub Actions: parsing YAML de todos os arquivos e validação dos scripts auxiliares de manifesto/checksum.
- GitHub Actions: tags oficiais ajustadas para checkout/setup-node v6 e mantidas as versões atuais de setup-go/setup-dotnet/upload/download artifact conforme documentação oficial.
- Interoperabilidade: um ODC criado em PHP foi lido e extraído por Node.js e Go, com comparação byte a byte do payload.

Não compilados no host de preparação por ausência do toolchain local:

- Delphi/RAD Studio;
- C#/.NET;
- Rust e Tauri.

Esses três grupos possuem jobs específicos no GitHub Actions. Delphi usa runner self-hosted licenciado quando `ODC_DELPHI_ENABLED=true`.

Detalhes adicionais: `docs/GITHUB_VALIDATION.md`.
