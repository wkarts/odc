# Runner self-hosted para Delphi

Instale o GitHub Actions Runner em uma máquina Windows com Delphi devidamente licenciado. Adicione os labels:

`self-hosted`, `Windows`, `X64`, `delphi`

O `PATH` do serviço/runner deve localizar `dcc32.exe` e `dcc64.exe` (ou configure `DELPHI_BIN` e adapte o workflow).

O workflow compila:

- `delphi/OdcCli.dpr` em Win32 e Win64;
- `delphi/studio/OdcStudio.dpr` em Win32 e Win64.

Os executáveis são empacotados e publicados como artifacts. Em execução manual com `attach_to_release=true`, também são enviados à tag informada.
