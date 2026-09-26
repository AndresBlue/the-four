@echo off
rem Mira una partida abierta en este equipo, o recorre un piso sin jugar.
cd /d "%~dp0"
set SEED=81
set /p SEED="Semilla (Enter = 81): "
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 observer -Seed %SEED%
