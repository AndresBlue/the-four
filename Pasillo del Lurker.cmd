@echo off
rem The Lurker en un pasillo de hotel, jugado: viene hacia ti por el suelo, las
rem paredes y el techo, a oscuras; con la linterna (F) se escabulle. WASD y raton,
rem la rueda el zoom, Esc para salir. No guarda nada.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 lurker
