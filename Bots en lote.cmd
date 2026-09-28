@echo off
rem Muchos pisos de bots sin ventana; al final, el resumen (evidenceots\<lote>esumen.txt).
cd /d "%~dp0"
set SEED=81
set /p SEED="Semilla (Enter = 81): "
set BOTS=3
set /p BOTS="Bots, de 1 a 5 (Enter = 3): "
set RUNS=20
set /p RUNS="Pisos (Enter = 20): "
powershell -NoProfile -ExecutionPolicy Bypass -File tools\bots.ps1 -Bots %BOTS% -Runs %RUNS% -Seed %SEED% -Parallel 10
echo.
pause
