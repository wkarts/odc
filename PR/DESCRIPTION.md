# Correção pós-merge — ODC Studio Tauri

## Problema

A matriz Tauri falha em Linux, macOS e Windows porque o checkout de `main`
não contém os recursos esperados pelo Tauri:

- `rust-tauri/studio/src-tauri/icons/icon.png`
- `rust-tauri/studio/src-tauri/icons/icon.ico`

Linux/macOS falham no `tauri::generate_context!()` e Windows falha no
`tauri-build` ao gerar o resource file.

## Causa confirmada

O workflow que falhou fez checkout do commit `2fc2945e65a41d6a6eb118d2bfe7db3bafda4d7c`.
Nesse commit os dois arquivos de ícone não existem no repositório.

## Solução

Adicionar `scripts/ci/ensure-tauri-icons.py`, que contém assets mínimos
determinísticos embutidos e os materializa antes do `cargo build`.

O script:

- gera `icon.png` e `icon.ico` somente quando necessário;
- valida SHA-256 dos bytes embutidos;
- valida o arquivo final depois da escrita;
- funciona em Linux, macOS e Windows;
- remove a dependência de um commit binário separado para que a matriz Tauri
  não volte a quebrar pelo mesmo motivo.

O workflow passa a executar:

```bash
python scripts/ci/ensure-tauri-icons.py
test -s rust-tauri/studio/src-tauri/icons/icon.png
test -s rust-tauri/studio/src-tauri/icons/icon.ico
cargo build --release --manifest-path rust-tauri/studio/src-tauri/Cargo.toml
```

## Escopo

Não altera:

- wire format ODC1;
- versão ODC;
- codec;
- APIs;
- Studio Web/PHP/.NET/PowerShell/Delphi;
- regras de release.

É uma correção estritamente de build do ODC Studio Tauri.
