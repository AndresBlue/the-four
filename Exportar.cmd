@echo off
rem Exporta el juego y deja el zip en exports\TheFour.zip.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 export
echo.
pause
