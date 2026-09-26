@echo off
rem Vuelve a ver una partida grabada de bots en el observador.
cd /d "%~dp0"
set /p RUN="Carpeta de la partida (evidence\bots\...\...): "
set AT=0
set /p AT="Segundo (Enter = 0): "
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 bots-replay -Run "%RUN%" -At %AT%
