# Segurança do ODC 1.0

## O que ODC 1.0 protege

- detecção de truncamento e estrutura inválida;
- limites de tamanho para metadados lidos em memória;
- SHA-256 do payload original;
- escrita por arquivo temporário e rename nas implementações de referência quando aplicável.

## O que ODC 1.0 NÃO protege

ODC 1.0 não criptografa o payload e não possui assinatura digital. Quem tiver acesso ao `.odc` pode extrair seu conteúdo. Um atacante que puder substituir todo o arquivo também pode criar outro ODC e recalcular o SHA-256.

Para confidencialidade/autenticidade, uma extensão futura deve usar criptografia autenticada (por exemplo AES-256-GCM ou XChaCha20-Poly1305) e/ou assinatura digital. Não invente criptografia própria dentro do metadata.
