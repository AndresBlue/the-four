@echo off
rem Salta a un piso y a un sector sin cumplir los anteriores, desde el proyecto
rem tal como esta (sin exportar). Uso: Saltar.cmd [piso] [sector]
rem   Saltar.cmd 2 3   piso 2, sector 3
rem   Saltar.cmd 2     piso 2 desde su primer sector
rem Sin argumentos los pregunta. "Nueva partida" empieza en ese piso y, al
rem empezar a jugar, te lleva al sector pedido. Dentro de la partida, F9 salta
rem al sector siguiente; en el ultimo sector, sale del piso. Usa el perfil de
rem pruebas: no toca tus ajustes ni tu Continuar.
cd /d "%~dp0"
set PISO=%1
set SECTOR=%2
if "%PISO%"=="" set /p PISO=Piso (1 o 2):
if "%SECTOR%"=="" set /p SECTOR=Sector (1, 2, 3...; vacio para el primero):
if "%SECTOR%"=="" set SECTOR=1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 play -Extra "--floor=%PISO% --stage=%SECTOR% --jumps --test-profile"
