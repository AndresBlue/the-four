@echo off
rem El piso 2, las oficinas, con The Lurker, desde el proyecto tal como esta (sin
rem exportar): "Nueva partida" empieza en el piso 2. Usa el perfil de pruebas: no
rem toca tus ajustes ni tu Continuar.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 play -Extra "--floor=2 --test-profile"
