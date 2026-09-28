@echo off
rem Juega a The Four.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 play
