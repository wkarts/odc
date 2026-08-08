# Build Fix R2

## Falha

O job Rust encerrava antes de `clippy`, `test` e `build` porque `cargo fmt --all -- --check` detectou diferenças de formatação.

## Arquivos corrigidos

- `rust-tauri/src/bin/odc.rs`
- `rust-tauri/src/lib.rs`

## Ajustes

- chamada `create_from_file(...)` compactada conforme rustfmt;
- `encoder.write_all(...)` normalizado;
- expressões de `le64(...)`, `compression`, `sha256` e `expected_hash` normalizadas conforme rustfmt.

Não há alteração funcional nesta correção.
