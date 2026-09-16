# THE FOUR

Prototipo 0.3-H1 de terror y exploración en primera persona para Godot 4.7.2 (Steam).

Ubicación principal: `E:\Projects\The Four`. Migrado el 16/09/2026 conservando el repositorio Git y su historial. Es un repositorio local en la rama `main`, sin remoto público.

## Jugar y editar

Abre **Jugar.cmd**. Para editar, abre **Abrir en Godot.cmd** o importa `project.godot` en Godot y pulsa F5.

Pulsa **INICIAR PARTIDA**. WASD mueve al jugador; ratón mira; Shift corre; Espacio salta; **E** interactúa a un máximo de 2 m. Una pulsación abre puertas; mantener E permite apertura lenta. Recoge los tres fusibles, instálalos en el panel del ascensor y, dentro de la cabina, mantén E durante 3 s para salir. **Esc** abre la pausa real; perder el foco también pausa. F11 alterna pantalla completa. El reintento está disponible desde los menús de victoria y derrota.

**M** silencia/restaura la música. **− / +** ajustan el volumen en pasos de 3 dB, entre −40 y −6 dB; comienza a −22 dB con entrada gradual. La pista se reproduce en bucle. El volumen todavía no se guarda entre ejecuciones.

## Implementado

- Piso fijo de 24 × 32 m, corredor y cuatro salas, colisiones, pilares, luminarias y materiales básicos.
- Jugador físico en primera persona con gravedad, caminar, carrera y salto.
- The Locust: GLB suministrado por el usuario, texturas embebidas, escala 1,9×, ajuste de posición y pose estática en Godot. Se conserva el GLB original sin modificación.
- Música aportada por el usuario: MP3 de 384,63 s, bucle, entrada gradual, silencio y control de volumen.
- Pruebas de movimiento, colisiones, recursos, controles de audio y mezcla/retorno del bucle.

El hito 1 añade objetivos, puertas, ascensor, pausa, victoria, muerte de prueba, reintento y menús. **The Locust permanece estático y no ataca.** Para comprobar la muerte durante una ejecución de desarrollo, pulsa **F9**; esta función no existe en una exportación de distribución. IA, supervivencia, guardado, generación, campaña y multijugador permanecen pendientes. El siguiente hito es H2.

## Documentación

- `docs/GAME_DESIGN.md`: plan de avance; reglas de generación, criaturas, mecánicas, objetos, muerte, victoria/derrota y criterios de aceptación.
- `docs/ROADMAP.md`: orden de los diez hitos y dependencias.
- `docs/TODO.md`: tareas con separación de implementado, pendiente y ampliación posterior.
- `docs/H1_VALIDATION.md`: revisión evaluada, pruebas reproducibles y límites del hito 1.
- `docs/ASSETS.md`: créditos, fuentes y situación de los permisos.
- `docs/asset_hashes.json`: huellas SHA-256 de los archivos recibidos e incorporados.
- `docs/VALIDATION.md`: resultado de la validación del prototipo 0.2.

## Conexión con Codex y estructura

Codex y Godot trabajan sobre esta misma carpeta: Codex modifica los archivos y ejecuta el Godot de Steam para importar y validar. No hay chat dentro del editor ni una API de OpenAI dentro del juego. Para futuras tareas, selecciona `E:\Projects\The Four` como proyecto local en Codex.

- `scenes/main.tscn`: escena editable del piso de prueba.
- `scripts/player.gd`: movimiento y cámara.
- `scripts/main.gd`: coordinación de sesión, interacción y capturas.
- `scripts/game_session.gd`: autoridad de estados, fusibles, salida y muerte.
- `scripts/level_gameplay.gd`: puertas, objetos y ascensor del mapa fijo.
- `scripts/interactable.gd`: interacción, puertas y protección del umbral.
- `scripts/session_ui.gd`: HUD y menús de partida.
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
./tools/godot.ps1 h1-test
./tools/godot.ps1 audio-test
./tools/godot.ps1 walkthrough
./tools/godot.ps1 capture
```

La ruta del proyecto se calcula desde el propio lanzador, por lo que admite espacios y no depende de su ubicación anterior. Admite otra instalación con `-GodotPath 'ruta/al/godot.exe'` o `GODOT_PATH`.

`tools/build_scene.gd` reconstruye `scenes/main.tscn` con nodos reales. **Reconstruir sustituye esa escena**: guarda antes cualquier edición manual en Git o incorpora el cambio al generador.

La prueba de mezcla de audio se ejecuta con Godot en modo headless y `--script res://tools/audio_test.gd`. Las capturas aceptan argumentos después de `--`: `--capture=ruta.png`, `--closeup`, `--overview`, `--silent`.

## Assets y publicación

El modelo de Doumty se anuncia como **CC BY-NC-ND**, no como CC BY. La canción no contiene título, artista o licencia verificables en sus metadatos. Se usan en este prototipo local a partir de los archivos aportados; antes de publicar o comercializar, resolver los permisos o sustituir los assets. Detalles y enlaces en `docs/ASSETS.md`.
