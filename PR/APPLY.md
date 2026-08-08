# Aplicação

```bash
git checkout main
git pull --ff-only

git checkout -b fix/tauri-studio-icons-self-healing

# Copie os arquivos deste pacote mantendo os caminhos:
# .github/workflows/build-assets.yml
# scripts/ci/ensure-tauri-icons.py
# scripts/ci/validate-tree.sh

python scripts/ci/ensure-tauri-icons.py --check

git add \
  .github/workflows/build-assets.yml \
  scripts/ci/ensure-tauri-icons.py \
  scripts/ci/validate-tree.sh

git commit -m "fix(build): materializar ícones obrigatórios do Tauri Studio no CI"
git push -u origin fix/tauri-studio-icons-self-healing
```

PR para `main`.
