# ODC Studios PHP + HTML/JavaScript

## Objetivo

Adicionar dois Studios completos ao SDK ODC sem alterar o wire format ODC1:

1. **ODC Studio PHP** — interface web local, sem banco, utilizando diretamente a implementação oficial `php-laravel/src/OdcContainer.php`.
2. **ODC Studio HTML/JavaScript** — interface estática/offline, sem backend, implementada com APIs binárias nativas do navegador.

## Recursos entregues

- criar `.odc` de qualquer arquivo;
- compressão adaptativa;
- abrir e inspecionar header e chunks;
- visualizar nome, MIME, tamanhos, compressão, SHA-256 e metadata;
- validar integridade SHA-256;
- extrair o payload original;
- editar metadata;
- remover metadata;
- preview local de imagens, vídeo, PDF e texto no Studio HTML/JS;
- execução PHP sem banco e sem estado persistente obrigatório;
- GitHub Actions gerando os dois novos artefatos de release;
- correção dos action tags de `checkout` e `setup-node` para versões oficiais suportadas (`v6`).

## Artefatos novos

- `odc-studio-php-1.1.0.zip`
- `odc-studio-html-js-1.1.0.zip`

## Compatibilidade

O wire format continua **ODC1 / versão 1.0**. O bump do SDK para **1.1.0** representa somente evolução das ferramentas e Studios.

## Segurança

- Studio HTML/JS não envia arquivos para rede;
- Studio PHP usa somente uploads temporários e nomes sanitizados;
- nenhuma operação aceita caminho arbitrário fornecido pelo cliente;
- payload ODC permanece binário, sem Base64;
- validação SHA-256 permanece obrigatória na extração/verificação.

## Validação

- lint PHP;
- `node --check` dos módulos JavaScript;
- smoke test HTTP do Studio PHP;
- `check-version-sync.py`;
- test vectors e interoperabilidade já existentes permanecem no pipeline.

## Branch sugerida

`feat/odc-studios-php-html-js`
