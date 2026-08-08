$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$port = if ($env:ODC_STUDIO_PORT) {$env:ODC_STUDIO_PORT} else {'8088'}
php -S "127.0.0.1:$port" -t studio-php/public
