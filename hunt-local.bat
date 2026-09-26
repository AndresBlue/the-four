@echo off
rem La vista del cazador sola, contra un superviviente quieto (sin proteccion inicial).
cd /d "%~dp0"
set SEED=81
set /p SEED="Semilla (Enter = 81): "
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 locust -Seed %SEED%
