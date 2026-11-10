@echo off
rem El piso 2, las oficinas, con The Lurker, para probarlo: "Nueva partida"
rem empieza en el piso 2. Usa el perfil de pruebas: no toca tus ajustes ni tu
rem Continuar.
start "" "%~dp0TheFour.exe" -- --floor=2 --test-profile %*
