# ODC Studios — Professional UI e correções desktop

## Objetivo

Profissionalizar todas as interfaces Studio existentes, corrigir a estrutura dos ícones e eliminar a janela de console do ODC Studio Tauri no Windows Release sem alterar o wire format ODC1.

## Entregas

- estrutura canônica de ícones em `assets/icons/`;
- ícones Tauri diretamente em `rust-tauri/studio/src-tauri/icons/`;
- remoção do diretório intermediário `optional-prebuilt-icons/`;
- `windows_subsystem = "windows"` no Tauri Release;
- novo layout profissional no Studio HTML/JavaScript;
- novo layout profissional no Studio Web/TypeScript;
- novo layout profissional no Studio PHP;
- novo layout profissional no Studio Tauri;
- novo layout profissional no Studio .NET/WinForms;
- novo layout profissional no Studio PowerShell/WinForms;
- novo layout profissional no Studio Delphi/VCL;
- pacote HTML/JS passa a incluir `assets/icon.png`;
- validação de árvore passa a exigir os ícones canônicos.

## Compatibilidade

- ODC1 permanece inalterado;
- versão do SDK permanece 1.1.0;
- operações create/info/verify/extract/set-meta/remove-meta preservadas;
- nenhuma refatoração de codec ou mudança de payload.

## Validação

Foram executados lint PHP, smoke HTTP do Studio PHP, Node checks, TypeScript build local, validação de workflows/YAML, contrato de versão e interoperabilidade PHP → Node.js → Go.
