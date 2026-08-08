@echo off
cd /d %~dp0..
if "%ODC_STUDIO_PORT%"=="" set ODC_STUDIO_PORT=8088
php -S 127.0.0.1:%ODC_STUDIO_PORT% -t studio-php/public
