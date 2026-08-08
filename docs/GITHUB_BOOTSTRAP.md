# Bootstrap do repositório GitHub

O conteúdo deste pacote é a raiz do repositório.

```bash
git init
git add .
git commit -m "chore: bootstrap ODC SDK 1.0.0"
git branch -M main
git remote add origin <URL_DO_REPOSITORIO>
git push -u origin main
```

Para a primeira release:

```bash
git tag -a v1.0.0 -m "ODC SDK 1.0.0"
git push origin v1.0.0
```

A tag deve ser exatamente `v` + o conteúdo de `VERSION`.

## Configuração opcional Delphi

Cadastre um runner self-hosted Windows com os labels `self-hosted`, `Windows`, `X64`, `delphi`. Depois crie a variável de repositório:

`ODC_DELPHI_ENABLED=true`

Sem essa variável, a build/release principal não aguarda Delphi e continua integralmente para as toolchains hospedadas.

## Proteção recomendada da branch

Proteja `main` exigindo o workflow CI e revisão de pull request antes do merge. A Release só precisa de `contents: write` no job final; os jobs de build usam `contents: read`.
