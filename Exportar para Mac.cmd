@echo off
rem Exporta la version de Mac y deja el zip en exports\macos\TheFour.zip.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 export-mac
echo.
pause
