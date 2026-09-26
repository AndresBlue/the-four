@echo off
rem Los bots en vivo, pero la criatura solo anota las capturas: el piso siempre llega al final.
cd /d "%~dp0"
set SEED=81
set /p SEED="Semilla (Enter = 81): "
set BOTS=3
set /p BOTS="Bots, de 1 a 5 (Enter = 3): "
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 bots -Bots %BOTS% -Seed %SEED% -Mercy
