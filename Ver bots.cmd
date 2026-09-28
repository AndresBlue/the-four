@echo off
rem Los bots jugando en vivo en el observador. [ ] cambian la velocidad, R pasa al piso siguiente.
cd /d "%~dp0"
set SEED=81
set /p SEED="Semilla (Enter = 81): "
set BOTS=3
set /p BOTS="Bots, de 1 a 5 (Enter = 3): "
set MERCY=n
set /p MERCY="Con clemencia: la criatura solo anota las capturas y el piso llega al final (s/N): "
set EXTRA=
if /i "%MERCY%"=="s" set EXTRA=-Mercy
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 bots -Bots %BOTS% -Seed %SEED% %EXTRA%
