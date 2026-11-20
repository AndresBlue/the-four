@echo off
rem Juega con el registro de rendimiento encendido: cada fotograma y lo que lo
rem ocupa, en la carpeta "Rendimiento" junto al juego. Usa tus ajustes y tu
rem Continuar, como siempre. Si notas un tiron, pulsa F8 cuando el juego vuelva
rem a responder. Al cerrar el juego se abre la carpeta: manda el .jsonl mas
rem reciente a quien te lo pidio.
start "" /wait "%~dp0TheFour.exe" -- "--perf-log=%~dp0Rendimiento" %*
explorer "%~dp0Rendimiento"
