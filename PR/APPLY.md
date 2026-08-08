# Aplicação

Branch:

```text
fix/tauri-native-file-dialogs-and-release
```

Título:

```text
fix(studio,release): adicionar diálogos nativos e publicar tag/release após build
```

Aplicação do projeto completo:

```bash
git checkout main
git pull --ff-only
git checkout -b fix/tauri-native-file-dialogs-and-release

# copie o conteúdo do pacote sobre a raiz do repositório

git add .
git commit -m "fix(studio,release): adicionar diálogos nativos e publicar tag/release após build"
git push -u origin fix/tauri-native-file-dialogs-and-release
```

Abra PR para `main`.

Após o merge, o workflow `Build & Release` deve compilar toda a matriz e, se tudo estiver verde, criar automaticamente `v1.1.0` e a GitHub Release `ODC SDK 1.1.0`.
