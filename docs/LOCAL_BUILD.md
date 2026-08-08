# Build local

## Go
`cd golang && go build ./cmd/odc`

## Rust
`cd rust-tauri && cargo build --release --bin odc`

## .NET CLI
`dotnet publish csharp-dotnet/Odc.Cli/Odc.Cli.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true`

## .NET Studio
`dotnet publish csharp-dotnet/Odc.Studio/Odc.Studio.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true`

## PHP PHAR
`php -d phar.readonly=0 scripts/build/build-php-phar.php php-laravel dist/odc-php.phar`

## TypeScript
`cd typescript && npm install && npm run build`

## Studio Web
`cd studio-web && npm install && npm run build`

## Tauri Studio
Instale os pré-requisitos do Tauri 2 para seu sistema e execute `cargo build --release --manifest-path rust-tauri/studio/src-tauri/Cargo.toml`.
