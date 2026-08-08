# PowerShell + Windows Forms

- `Odc.Core.ps1`: API PowerShell.
- `ODC-Studio.ps1`: Windows Forms para criar, abrir, validar, extrair e editar metadata.
- `Build-ODC-Studio-Exe.ps1`: alternativa PS2EXE quando o módulo estiver instalado.
- `../bin/windows-x64/ODC-Studio.exe`: launcher Windows x64 já compilado no pacote; contém os scripts embutidos e abre a interface por `powershell.exe -STA`.
- `../bin/windows-x86/ODC-Studio.exe`: equivalente x86.

O launcher compilado não exige módulo PS2EXE, mas utiliza o Windows PowerShell disponível no Windows.
