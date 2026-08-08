param([string]$Output = "$PSScriptRoot\ODC-Studio-PS2EXE.exe")
$ErrorActionPreference='Stop'
if(-not (Get-Module -ListAvailable ps2exe)){throw 'Módulo ps2exe não encontrado. Instale previamente com: Install-Module ps2exe -Scope CurrentUser'}
Import-Module ps2exe
Invoke-ps2exe -InputFile "$PSScriptRoot\ODC-Studio.ps1" -OutputFile $Output -NoConsole -STA -Title 'ODC Studio' -Product 'ODC Studio' -Version '1.0.0.0'
Write-Host "Gerado: $Output"
