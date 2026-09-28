@echo off
rem Abre el proyecto en el editor de Godot.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 editor
