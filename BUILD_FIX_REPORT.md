# ODC SDK 1.1.0 — Build Fix R1

Correções derivadas dos workflows `84820183707` (CI) e `84820183719` (Security/CodeQL).

## Falhas confirmadas e correções

### 1. Rust — `cargo fmt --all -- --check`

**Falha:** os arquivos `rust-tauri/src/lib.rs` e `rust-tauri/src/bin/odc.rs` estavam funcionalmente escritos, porém fora do formato exigido pelo `rustfmt`. O primeiro passo do job Rust encerrava o job antes de `clippy`, `test` e `build`.

**Correção:** código Rust normalizado e CLI reorganizada com validação de argumentos e propagação explícita de erros. Também foi removido o padrão `map(... println!)` e outras construções propensas a lints do Clippy.

### 2. Go — colisão do nome de saída

**Falha:** `go build ./cmd/odc` executado dentro de `golang/` tenta criar `./odc`, mas `golang/odc` já é um diretório do package. Erro observado:

```text
go: build output "odc" already exists and is a directory
```

**Correção:** CI agora usa:

```bash
go build -o /tmp/odc-ci ./cmd/odc
```

### 3. Contract — validação YAML truncada por `#`

**Falha:** o comando Ruby estava em um scalar YAML simples. O trecho Ruby `#{f}` era interpretado pelo YAML como início de comentário, truncando o comando e produzindo erro de aspas no shell.

**Correção:** o comando passou a usar bloco literal `run: |`, preservando integralmente `#{f}`.

### 4. PowerShell — sintaxe genérica incompatível

**Falha:** Windows PowerShell 5.1 não aceita a sintaxe:

```powershell
[Linq.Enumerable]::SequenceEqual[byte](...)
```

O parser produzia `MissingArrayIndexExpression`, `UnexpectedToken byte]` e erros em cascata.

**Correção:** comparação do SHA-256 feita pelos valores hexadecimais gerados por `BitConverter`, compatível com Windows PowerShell 5.1.

### 5. Shell — `Broken pipe`

**Falha:** `find_chunk()` fazia `scan | awk ... exit`. Ao encontrar o chunk, `awk` encerrava a leitura enquanto `scan` ainda escrevia no pipe, gerando repetidos `echo: write error: Broken pipe`.

**Correção:** `awk` agora consome todo o stream e apenas imprime a primeira ocorrência, sem encerrar antecipadamente o pipe.

### 6. CodeQL — permissões do workflow

**Falha:** C# e JavaScript/TypeScript chegavam à análise, mas o CodeQL não conseguia ler dados do workflow run:

```text
Resource not accessible by integration
.../actions/workflow-runs#get-a-workflow-run
```

**Correção:** adicionado:

```yaml
permissions:
  actions: read
  contents: read
  security-events: write
```

### 7. CodeQL Go — nenhuma fonte compilada capturada

**Falha:** `actions/setup-go` era executado **depois** de `github/codeql-action/init`. O próprio log informou que `which go` apontava para o Go do toolcache, e não para o wrapper de tracing do CodeQL. A finalização encerrou com `no-source-code-seen-during-build`.

**Correção:** toolchains (`setup-go` / `setup-dotnet`) são instalados antes do `codeql-action/init`. Depois do init o Go é compilado com build limpo e forçado:

```bash
go clean -cache
go build -a -o /tmp/odc-codeql ./cmd/odc
```

O C# também usa `--no-incremental` no build manual do CodeQL.

## Validações executadas neste ambiente

Aprovadas localmente:

- parsing de todos os YAMLs dos workflows via Ruby `YAML.load_file`;
- `scripts/ci/check-version.sh`;
- `scripts/ci/check-version-sync.py`;
- `scripts/ci/validate-tree.sh`;
- Shell: `bash -n` e leitura real de `test-vectors/hello.odc` sem `Broken pipe`;
- Go: `gofmt`, `go vet`, `go test`, `go build -o ...` e `verify` do vetor canônico;
- PHP: lint, create, verify, extract e comparação byte a byte;
- Node.js: syntax check e verify;
- Studio PHP: lint;
- Studio HTML/JavaScript: `node --check`;
- interoperabilidade PHP → Node.js → Go.

Rust/.NET/PowerShell completos dependem dos respectivos toolchains/Windows runners e devem ser confirmados pelo rerun do GitHub Actions. Os erros concretos observados nos logs foram corrigidos no código/workflows antes deste pacote.

> Observação: a tentativa de atualizar diretamente a branch do PR via conector GitHub retornou HTTP 403 `Resource not accessible by integration`. Por isso este pacote inclui patch aplicável diretamente à branch existente.
