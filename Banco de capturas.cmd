@echo off
rem El banco de capturas: la criatura te coge cuando se lo pides, con la luz, la
rem entrada y el final que elijas (las teclas salen en pantalla). Sirve para
rem juzgar la escena de la captura, y en particular el desgarro de la embestida
rem (tecla T: A sin desgarro, B con desgarro). No guarda nada: ni Continuar ni
rem records. Con G graba las cuatro escenas de comparacion en evidence\.
cd /d "%~dp0"
set MODO=
set /p MODO="Enter = jugar el banco   |   G = grabar las cuatro escenas A/B (evidence\captura_*.avi): "
set SEED=81
set /p SEED="Semilla (Enter = 81): "
if /i "%MODO%"=="G" (
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 bench-films -Seed %SEED%
    echo.
    echo Las grabaciones estan en evidence\captura_*.avi
    pause
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 bench -Seed %SEED%
)
