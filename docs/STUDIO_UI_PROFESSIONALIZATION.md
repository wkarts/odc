# ODC Studios — profissionalização visual e desktop

Esta revisão aplica a mesma linguagem visual e operacional às interfaces Studio sem alterar o formato ODC1 nem os codecs.

## Alterações

- ícones consolidados em `assets/icons/png`, `assets/icons/windows` e `assets/icons/macos`;
- conjunto Tauri colocado no caminho canônico `rust-tauri/studio/src-tauri/icons/`;
- ODC Studio HTML/JavaScript redesenhado com sidebar, cabeçalho, cards, mapa de chunks, preview e status;
- ODC Studio Web/TypeScript redesenhado com a mesma identidade;
- ODC Studio PHP redesenhado e com preview temporário de conteúdo compatível;
- ODC Studio Tauri redesenhado para desktop e com janela maior/responsiva;
- ODC Studio .NET reorganizado como aplicação desktop com navegação lateral e status operacional;
- ODC Studio PowerShell reorganizado com cabeçalho, cards, status e controles consistentes;
- ODC Studio Delphi reorganizado com header institucional, páginas operacionais, status e metadata em `TMemo`;
- binário Tauri Windows Release usa `windows_subsystem = "windows"`, eliminando a janela de console/CMD;
- pacote HTML/JS de release passa a incluir `assets/`.

## Tauri sem console no Windows

O `src/main.rs` contém:

```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
```

O console continua disponível em builds de debug e é ocultado em builds Release para Windows.

## Ícones

Estrutura canônica:

```text
assets/icons/
├── png/
│   ├── 32x32.png
│   ├── 64x64.png
│   ├── 128x128.png
│   ├── 256x256.png
│   ├── 512x512.png
│   └── icon.png
├── windows/icon.ico
└── macos/icon.icns

rust-tauri/studio/src-tauri/icons/
├── 32x32.png
├── 128x128.png
├── 128x128@2x.png
├── icon.png
├── icon.ico
└── icon.icns
```

O diretório antigo `optional-prebuilt-icons/` foi removido para evitar duas fontes concorrentes de assets.

## Compatibilidade

Nenhuma mudança no wire format ODC1, nos test-vectors, no SHA-256, nos chunks ou na interoperabilidade entre linguagens.
