@echo off
rem Todas las pruebas (unos 25 minutos).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify.ps1
echo.
pause
