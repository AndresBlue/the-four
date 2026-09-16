# THE FOUR

Prototipo 0.1 de exploración en primera persona, creado para Godot 4.7.2 (Steam).

## Jugar

Abre **Jugar.cmd**. Para editar, abre **Abrir en Godot.cmd** o importa `project.godot` en Godot y pulsa F6 sobre `scenes/main.tscn` (F5 ejecuta el proyecto).

Haz clic dentro del juego para capturar el ratón. WASD mueve al jugador, el ratón gira la cámara, Shift permite correr y Espacio salta. Esc libera o captura el ratón; R vuelve al inicio; F11 cambia entre ventana y pantalla completa. Al perder el foco, se libera el ratón y se detiene el movimiento.

## Incluido

- Piso de 24 × 32 metros, corredor central y cuatro salas laterales conectadas.
- Geometría editable, colisiones, techo modular, pilares y luz básica.
- Jugador con cápsula física de 1,75 m, cámara, gravedad, salto y carrera.
- Un enemigo estático con colisión en la zona de observación.
- HUD con controles y zona actual.
- Pruebas de física y controles, y captura del render desde Godot.

El enemigo inicial es una representación geométrica provisional de The Locust creada para comprobar escala y render. No es el modelo de Sketchfab ni un asset oficial. La descarga del modelo de xerio3900 requiere que el usuario inicie sesión; su integración está pendiente.

## Conexión con ChatGPT / Codex

Este repositorio es el punto compartido entre Codex y Godot. Codex edita escenas y scripts y ejecuta el Godot instalado en Steam para importar, probar y abrir el juego. Esta conexión por archivos y línea de comandos está comprobada en este equipo. No hay un chat incrustado en el editor, ni un servidor MCP de Godot instalado, ni llamadas a OpenAI dentro del juego.

Para continuar el desarrollo, añade esta carpeta como proyecto local en Codex. Godot recarga los archivos externos; detén la ejecución y vuelve a ejecutar para ver los cambios. Si pregunta por una escena modificada externamente, recarga la versión de disco después de guardar cualquier trabajo propio.

Referencia oficial: https://learn.chatgpt.com/docs/codex/cli
Interfaz de Godot: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html

## Herramientas

Desde PowerShell, en esta carpeta:

```powershell
./tools/godot.ps1 editor
./tools/godot.ps1 play
./tools/godot.ps1 test
./tools/godot.ps1 capture
```

La herramienta encuentra la instalación de Steam de este equipo. En otro equipo admite `-GodotPath 'ruta/al/godot.exe'` o la variable `GODOT_PATH`.

`tools/build_scene.gd` genera `scenes/main.tscn`. La escena resultante contiene nodos reales y se puede editar visualmente. **Reconstruir sustituye esa escena:** conserva antes los cambios manuales mediante Git o modifica el generador.

## Estructura

- `scenes/main.tscn`: escena completa del prototipo.
- `scripts/player.gd`: movimiento y cámara.
- `scripts/main.gd`: controles de sesión, HUD y capturas.
- `assets/enemies/`: modelos y créditos de terceros cuando estén disponibles.
- `tools/`: lanzamiento, generación y pruebas.
- `evidence/`: capturas y resultados locales de pruebas, excluidos de Git.
- `docs/ASSETS.md`: fuentes y estado de licencias.
- `docs/ROADMAP.md`: siguientes etapas.

Repositorio Git local, rama `main`. No tiene remoto ni está publicado en GitHub.
