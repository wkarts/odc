# ODC Studio Tauri + publicação automática de Release

## Problemas corrigidos

### 1. ODC Studio Tauri sem seletor nativo de arquivos

A interface aceitava somente caminhos digitados manualmente. Isso causava erros como `O sistema não pode encontrar o caminho especificado (os error 3)` e não oferecia a experiência esperada de uma aplicação desktop.

A correção adiciona o plugin oficial `tauri-plugin-dialog` e comandos Rust dedicados para:

- selecionar arquivo de origem;
- escolher destino `.odc`;
- abrir container `.odc`;
- escolher destino do arquivo extraído.

Os campos de caminho agora são somente leitura e preenchidos pelos diálogos nativos do Windows, Linux e macOS. Ao selecionar a origem, o Studio sugere automaticamente o `.odc` no mesmo diretório.

### 2. Build verde gerava somente Artifacts, sem tag e sem GitHub Release

O workflow `Build artifacts` encerrava após `build-assets.yml`. Os arquivos exibidos em **Actions > Artifacts** eram temporários e não havia etapa de publicação.

O novo `Build & Release` passa a:

1. validar `VERSION`;
2. executar toda a matriz de builds;
3. baixar os artifacts `release-*` somente depois de todos os builds aprovados;
4. consolidar os arquivos de release;
5. gerar `release-manifest.json`;
6. gerar e validar `SHA256SUMS.txt`;
7. criar a tag `v<VERSION>`;
8. criar a GitHub Release `ODC SDK <VERSION>`;
9. anexar todos os binários, Studios, fontes, manifesto e checksums.

A tag é criada somente após a matriz ficar verde. Se a mesma versão já estiver vinculada a outro commit, a publicação automática é ignorada e a versão precisa ser incrementada, preservando a imutabilidade das releases.

O workflow `release.yml` permanece como recuperação manual e não é mais disparado pelo push da tag automática, evitando uma segunda compilação duplicada.

## Compatibilidade

- wire format ODC1 inalterado;
- `VERSION` permanece `1.1.0` porque ainda não existe release/tag pública dessa versão;
- codecs e vetores canônicos permanecem inalterados;
- nenhum servidor é introduzido no ODC Studio Tauri;
- funcionamento local/offline preservado.

## Arquivos principais

- `rust-tauri/studio/src-tauri/Cargo.toml`
- `rust-tauri/studio/src-tauri/src/main.rs`
- `rust-tauri/studio/web-dist/index.html`
- `.github/workflows/build.yml`
- `.github/workflows/release.yml`
- `scripts/release/publish-release.sh`
- `scripts/ci/validate-tree.sh`
