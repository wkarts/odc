# ODC Studio HTML/JavaScript

Studio ODC1 100% estático, sem backend e sem build obrigatório.

Abra `index.html` em um navegador moderno. Todos os bytes permanecem localmente.

## Recursos

- criar ODC de qualquer arquivo;
- compressão adaptativa;
- abrir e inspecionar header/chunks;
- SHA-256 com Web Crypto;
- extrair o arquivo original;
- editar/remover metadata;
- preview local de imagem, vídeo, PDF e texto.

O codec usa `ArrayBuffer`, `Uint8Array`, `DataView`, `CompressionStream`, `DecompressionStream` e `crypto.subtle`.
