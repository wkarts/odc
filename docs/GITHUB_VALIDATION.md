# Validação da estrutura GitHub

Data da preparação: 2026-08-08.

## Validado no ambiente de preparação

- árvore obrigatória e magic `ODC1` do vetor canônico;
- sincronismo de versão entre PHP/Node/TypeScript/Rust/Tauri/.NET;
- parsing YAML de todos os workflows;
- ODC Studio PHP: lint, create/info/verify/extract/set-meta/remove-meta via HTTP local;
- ODC Studio HTML/JavaScript: parse Node e round-trip create/info/verify/extract/setMetadata;
- lint PHP e criação/execução do PHAR;
- sintaxe e leitura Node.js;
- compilação TypeScript da biblioteca e do ODC Studio Web;
- `gofmt`, `go vet`, `go test` e build Go;
- cross-build Go para Linux x64/arm64, Windows x86/x64/arm64 e macOS x64/arm64;
- build do launcher ODC Studio PowerShell para Windows x86/x64/arm64;
- interoperabilidade PHP -> Node.js -> Go usando o mesmo `.odc`;
- sintaxe/execução de leitura Shell;
- geração de pacotes-fonte ZIP/TAR.GZ.

## Compatibilidade GitHub Actions

Os workflows usam `actions/checkout@v6`, `actions/setup-node@v6`, `actions/setup-go@v7`, `actions/setup-dotnet@v5`, `actions/upload-artifact@v7` e `actions/download-artifact@v5`, conforme as versões suportadas na preparação desta release.

## Delegado ao GitHub Actions

O ambiente local de preparação não continha compiladores Rust, .NET ou Delphi. Esses artefatos são produzidos nos runners definidos nos workflows. Delphi depende de runner self-hosted com toolchain licenciado. O Studio Tauri é compilado em runners por plataforma com os pré-requisitos Linux declarados no workflow.

## Política

Uma falha de qualquer matriz obrigatória bloqueia o job de build e, por consequência, o job de publicação. Delphi só integra a matriz principal quando `ODC_DELPHI_ENABLED=true`; caso contrário, permanece disponível no workflow self-hosted manual.
