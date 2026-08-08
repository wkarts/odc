# PHP / Laravel

Uso sem framework:

```bash
php bin/odc create ../../test-vectors/hello.txt /tmp/hello.odc ../../test-vectors/hello.metadata.json
php bin/odc info /tmp/hello.odc
php bin/odc verify /tmp/hello.odc
php bin/odc extract /tmp/hello.odc /tmp/hello.txt
```

Em Laravel, instale a pasta como package local/Composer ou copie `src/` para um package interno. O payload ODC deve ficar no filesystem/S3/MinIO; no banco grave somente o caminho, hash e metadados de negócio necessários.
