# Checklist de Release

1. Atualizar `VERSION` e os arquivos de versão sincronizados.
2. Atualizar `CHANGELOG.md`.
3. Executar CI.
4. Confirmar vetores ODC e interoperabilidade.
5. Criar/push da tag `vX.Y.Z` ou executar `Release` manualmente com a mesma tag.
6. Verificar `SHA256SUMS.txt` e `release-manifest.json` nos assets.
7. Se Delphi estiver desabilitado na release principal, executar `Delphi self-hosted build` e anexar os dois pacotes Windows à mesma tag.
