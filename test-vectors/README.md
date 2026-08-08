# Test vectors

- `hello.txt` + `hello.odc`: TXT pequeno integrado literalmente ao ODC.
- `compressible.txt` + `compressible.odc`: TXT grande altamente compressível, armazenado como gzip dentro do ODC.
- `*.metadata.json`: metadata usada na criação.
- `*.info.json`: resultado da implementação PHP.
- `originals.sha256`: hashes dos arquivos originais.

Para comprovar reversibilidade:

```bash
php ../php-laravel/bin/odc extract hello.odc /tmp/hello-restored.txt
cmp hello.txt /tmp/hello-restored.txt
```
