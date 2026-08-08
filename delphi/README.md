# Delphi

Unit principal: `OdcContainer.pas`.

Alvo recomendado: Delphi 10.4+ / 11 / 12, usando apenas RTL (`System.Classes`, `System.Hash`, `System.ZLib`, `System.JSON`). O gzip usa `TZCompressionStream(..., windowBits=31)` / `TZDecompressionStream(..., 31, ...)`, recurso documentado pela Embarcadero.

A implementação de `SetMetadata` recria o container a partir do payload extraído para priorizar simplicidade/segurança. Em arquivos muito grandes, substitua por rewrite streaming de chunks.
