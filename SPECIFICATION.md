# ODC 1.0 — Optical Data Container

ODC é um container binário genérico, independente de linguagem e servidor. O formato armazena qualquer sequência de bytes com metadados, compressão opcional e verificação de integridade SHA-256.

## Princípios

- binário: payload nunca é convertido para Base64;
- portável: mesma estrutura em PHP, Delphi, Rust, Node.js, C#/.NET, Go, TypeScript, Shell e PowerShell;
- extensível: chunks desconhecidos podem ser ignorados pelo leitor;
- streaming: payload pode ser copiado sem materializar o arquivo inteiro na RAM;
- compacto: gzip só é usado se economizar pelo menos 64 bytes;
- verificável: SHA-256 sempre representa os bytes originais, antes de eventual gzip;
- seguro contra corrupção acidental: parsing com limites e hash. ODC 1.0 não oferece confidencialidade; criptografia autenticada deve ser tratada como extensão futura.

## Byte order

Todos os inteiros são **little-endian**.

## Header fixo — 24 bytes

| Offset | Tamanho | Tipo | Campo | Valor |
|---:|---:|---|---|---|
| 0 | 4 | bytes | magic | `ODC1` |
| 4 | 2 | u16 | version_major | `1` |
| 6 | 2 | u16 | version_minor | `0` |
| 8 | 4 | u32 | flags | bit 0 = payload gzip |
| 12 | 4 | u32 | header_size | `24` |
| 16 | 4 | u32 | chunk_count | quantidade de chunks |
| 20 | 4 | u32 | reserved | `0` |

## Header de chunk — 12 bytes

| Offset relativo | Tamanho | Tipo | Campo |
|---:|---:|---|---|
| 0 | 2 | u16 | type |
| 2 | 2 | u16 | flags |
| 4 | 8 | u64 | length |

Após o header vêm exatamente `length` bytes de valor.

## Chunks ODC 1.0

| Type | Nome | Conteúdo |
|---:|---|---|
| `0x0001` | FILE_NAME | nome original UTF-8 |
| `0x0002` | MIME_TYPE | MIME UTF-8 |
| `0x0003` | METADATA_JSON | objeto JSON UTF-8 opcional |
| `0x0004` | ORIGINAL_SIZE | u64 LE, 8 bytes |
| `0x0010` | COMPRESSION | u8: 0=none, 1=gzip |
| `0x0020` | SHA256 | 32 bytes binários do arquivo original |
| `0x0100` | PAYLOAD | arquivo original ou payload gzip |

Chunks obrigatórios: FILE_NAME, MIME_TYPE, ORIGINAL_SIZE, COMPRESSION, SHA256 e PAYLOAD.
METADATA_JSON é opcional.

## Compressão

- `0`: payload literal.
- `1`: gzip RFC 1952.
- o writer deve usar gzip somente se o payload resultante + 64 bytes for menor que o original;
- formatos tipicamente já comprimidos (JPEG, PNG, WebP, MP4, ZIP, 7z etc.) devem normalmente ficar em `none`.

## Integridade

`SHA256` é calculado sobre o arquivo original, antes de gzip. Durante `extract`/`verify`, o payload é descomprimido quando necessário e o hash é recalculado.

## Edição

ODC é append/rewriting-friendly, mas não é seguro remover bytes no meio do arquivo in-place. Operações de alteração devem:

1. ler o índice de chunks;
2. escrever um arquivo temporário;
3. copiar chunks preservados;
4. adicionar/substituir/remover o chunk desejado;
5. atualizar `chunk_count`;
6. fazer rename atômico quando possível.

Alterar somente METADATA_JSON não altera SHA256, pois o hash protege o payload original.

## Limites de implementação recomendados

- FILE_NAME: <= 1 MiB;
- MIME_TYPE: <= 1 MiB;
- METADATA_JSON: <= 16 MiB;
- SHA256: exatamente 32 bytes;
- ORIGINAL_SIZE: exatamente 8 bytes;
- COMPRESSION: exatamente 1 byte;
- qualquer deslocamento deve ser validado contra o tamanho físico do arquivo.

## ODC e QR/Fountain

ODC é o container de armazenamento. QR/Fountain é uma representação/transporte opcional e não faz parte do arquivo ODC 1.0. Isso evita armazenar permanentemente redundância óptica.
