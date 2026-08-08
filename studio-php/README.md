# ODC Studio PHP

Studio web local que executa o codec ODC1 em PHP. Não usa banco de dados.

## Executar

Na raiz do repositório:

```bash
php -S 127.0.0.1:8088 -t studio-php/public
```

Abra `http://127.0.0.1:8088`.

O limite padrão é 256 MB por upload. Altere com `ODC_STUDIO_MAX_UPLOAD_MB`.

## Operações

- criar ODC;
- inspecionar header/chunks;
- validar SHA-256;
- extrair original;
- editar metadata;
- remover metadata.

O Studio referencia diretamente `php-laravel/src`, portanto usa a mesma implementação PHP oficial do SDK.
