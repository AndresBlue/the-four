@echo off
rem Los veinte modulos de habitacion, uno al lado del otro, para mirarlos.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 gallery
