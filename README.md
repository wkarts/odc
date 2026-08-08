# ODC SDK 1.1.0 — Optical Data Container

Pacote de referência multiplataforma para criar, ler, inspecionar, validar, extrair e editar metadados de arquivos `.odc`.

## Implementações incluídas

- Delphi — `delphi/OdcContainer.pas` + CLI de exemplo.
- PHP / Laravel — biblioteca, CLI e integração de exemplo.
- Rust / Tauri — crate + CLI + comandos Tauri opcionais.
- Node.js — módulo CommonJS/ESM-compatible e CLI.
- C# / .NET — biblioteca + CLI.
- Go — package + CLI.
- TypeScript — browser/Node via Web APIs + exemplo.
- Shell/Bash — CLI compatível usando ferramentas Unix.
- PowerShell — core + Windows Forms Studio.
- PHP Studio — interface web local usando o codec PHP oficial, sem banco.
- HTML/JavaScript Studio — aplicação estática completa, 100% offline e sem backend.
- Windows x64/x86 — `ODC-Studio.exe`, launcher compilado que executa a interface PowerShell Forms embutida.

## Operações padronizadas

```text
create      arquivo.ext arquivo.odc [metadata]
info        arquivo.odc
verify      arquivo.odc
extract     arquivo.odc destino.ext
set-meta    arquivo.odc metadata.json
remove-meta arquivo.odc
```

## Test vectors

`test-vectors/` contém arquivos `.txt`, `.odc`, JSON de metadados e hashes esperados. Eles foram gerados pela implementação PHP e validados pelas implementações Node.js e Go no ambiente de construção.

## Segurança

ODC 1.0 garante verificação de integridade do payload por SHA-256 e parsing defensivo. **Não oferece confidencialidade ou autenticidade criptográfica contra um atacante que possa substituir o container inteiro.** Veja `SECURITY.md`.

## Marca

ODC é o nome técnico do formato. A aplicação que o utiliza pode exibir uma marca própria (ARGWS, FERSOFT ou outro parceiro) sem alterar o wire format `.odc`.

## GitHub CI/CD e releases multi-plataforma

Esta distribuição inclui uma estrutura pronta para GitHub Actions em `.github/workflows/`. O pipeline compila/empacota as implementações e Studios disponíveis, executa validações de interoperabilidade e, em tags `vX.Y.Z`, cria uma GitHub Release com manifesto e SHA-256.

Consulte `docs/CI_CD_GITHUB.md`, `docs/RELEASE_ARTIFACTS.md`, `docs/LOCAL_BUILD.md` e `docs/DELPHI_RUNNER.md`.

A compilação Delphi utiliza runner Windows self-hosted porque o toolchain Delphi é licenciado e não faz parte dos runners hospedados do GitHub. As demais famílias utilizam runners GitHub-hosted adequados a x64/arm64 e, onde suportado, x86.

