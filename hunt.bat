@echo off
rem Eres The Locust contra bots, piso tras piso. Volver al menu lo termina.
cd /d "%~dp0"
set SEED=81
set /p SEED="Semilla (Enter = 81): "
set BOTS=5
set /p BOTS="Bots, de 1 a 5 (Enter = 5): "
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 hunt -Bots %BOTS% -Seed %SEED%
