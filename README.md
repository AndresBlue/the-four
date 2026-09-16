# THE FOUR

Prototipo 0.2 de terror y exploración en primera persona para Godot 4.7.2 (Steam).

Ubicación principal: `E:\Projects\The Four`. Migrado el 16/09/2026 conservando el repositorio Git y su historial. Es un repositorio local en la rama `main`, sin remoto público.

## Jugar y editar

Abre **Jugar.cmd**. Para editar, abre **Abrir en Godot.cmd** o importa `project.godot` en Godot y pulsa F5.

Haz clic en el juego para capturar el ratón. WASD mueve al jugador; ratón mira; Shift corre; Espacio salta; Esc libera/captura el ratón; R vuelve al inicio; F11 alterna pantalla completa. La pérdida de foco libera el ratón y pausa la música.

**M** silencia/restaura la música. **− / +** ajustan el volumen en pasos de 3 dB, entre −40 y −6 dB; comienza a −22 dB con entrada gradual. La pista se reproduce en bucle. El volumen todavía no se guarda entre ejecuciones.

## Implementado

- Piso fijo de 24 × 32 m, corredor y cuatro salas, colisiones, pilares, luminarias y materiales básicos.
- Jugador físico en primera persona con gravedad, caminar, carrera y salto.
- The Locust: GLB suministrado por el usuario, texturas embebidas, escala 1,9×, ajuste de posición y pose estática en Godot. Se conserva el GLB original sin modificación.
- Música aportada por el usuario: MP3 de 384,63 s, bucle, entrada gradual, silencio y control de volumen.
- Pruebas de movimiento, colisiones, recursos, controles de audio y mezcla/retorno del bucle.

Todavía no hay IA, interacción con objetos, daño, victoria/derrota, mapas generados ni multijugador. El enemigo permanece estático. Las propuestas para esas funciones están en **docs/GAME_DESIGN.md**.

## Documentación

- `docs/GAME_DESIGN.md`: plan de avance; reglas de generación, criaturas, mecánicas, objetos, muerte, victoria/derrota y criterios de aceptación.
- `docs/ASSETS.md`: créditos, fuentes y situación de los permisos.
- `docs/asset_hashes.json`: huellas SHA-256 de los archivos recibidos e incorporados.
- `docs/VALIDATION.md`: resultado de la validación del prototipo 0.2.

## Conexión con Codex y estructura

Codex y Godot trabajan sobre esta misma carpeta: Codex modifica los archivos y ejecuta el Godot de Steam para importar y validar. No hay chat dentro del editor ni una API de OpenAI dentro del juego. Para futuras tareas, selecciona `E:\Projects\The Four` como proyecto local en Codex.

- `scenes/main.tscn`: escena editable del piso de prueba.
- `scripts/player.gd`: movimiento y cámara.
- `scripts/main.gd`: controles de sesión, HUD y capturas.
- `scripts/locust_visual.gd`: pose estática de presentación, sin IA.
- `scripts/music.gd`: bucle, mezcla y controles de música.
- `assets/enemies/locust.glb`: modelo original con texturas embebidas.
- `assets/audio/the_four_theme.mp3`: copia exacta de la canción aportada.
- `source_assets/`: ZIP y MP3 originales, conservados localmente y excluidos de Git/importación para evitar duplicados.
- `tools/`: generación, lanzamiento y pruebas.
- `evidence/`: capturas y resultados locales excluidos de Git y del escaneo de Godot.

## Herramientas

En PowerShell, desde esta carpeta:

```powershell
./tools/godot.ps1 editor
./tools/godot.ps1 play
./tools/godot.ps1 test
./tools/godot.ps1 capture
```

La ruta del proyecto se calcula desde el propio lanzador, por lo que admite espacios y no depende de su ubicación anterior. Admite otra instalación con `-GodotPath 'ruta/al/godot.exe'` o `GODOT_PATH`.

`tools/build_scene.gd` reconstruye `scenes/main.tscn` con nodos reales. **Reconstruir sustituye esa escena**: guarda antes cualquier edición manual en Git o incorpora el cambio al generador.

La prueba de mezcla de audio se ejecuta con Godot en modo headless y `--script res://tools/audio_test.gd`. Las capturas aceptan argumentos después de `--`: `--capture=ruta.png`, `--closeup`, `--overview`, `--silent`.

## Assets y publicación

El modelo de Doumty se anuncia como **CC BY-NC-ND**, no como CC BY. La canción no contiene título, artista o licencia verificables en sus metadatos. Se usan en este prototipo local a partir de los archivos aportados; antes de publicar o comercializar, resolver los permisos o sustituir los assets. Detalles y enlaces en `docs/ASSETS.md`.
