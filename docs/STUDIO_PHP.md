# ODC Studio PHP

Interface web completa que usa a implementação oficial PHP/Laravel do ODC1.

```bash
php -S 127.0.0.1:8088 -t studio-php/public
```

Não requer banco de dados. O upload é temporário e cada ação trabalha com arquivos temporários seguros. O limite padrão é 256 MB e pode ser configurado por `ODC_STUDIO_MAX_UPLOAD_MB`.
