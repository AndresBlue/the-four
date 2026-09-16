# THE FOUR — Hotel

**0.4-P1 · Primer hotel procedural individual · Godot 4.7.2 Steam**

Proyecto principal: `E:\Projects\The Four`. Repositorio local, sin publicación ni remoto público.

## Jugar

Abre **Jugar.cmd** y elige **Jugar · nuevo recorrido**. Explora el hotel hasta encontrar la sala señalizada **SALIDA / REFUGIO**. Dentro puedes volver a explorar o mantener la interacción durante tres segundos para terminar el piso. No necesitas recoger fusibles ni completar puzles.

Controles iniciales: WASD para moverte, ratón para mirar, Shift para correr, Espacio para saltar, **E** para puertas, **F** para linterna y **Esc** para pausa. Pulsa y suelta E para apertura normal; mantenla un segundo para apertura lenta. Los controles se pueden cambiar en Ajustes.

**Continuar** restaura el inicio del mismo piso, no la posición donde cerraste el juego. Reintentar conserva el mapa y restablece puertas/estado. Al completar esta demostración se borra su checkpoint. Los cambios de pantalla necesitan confirmación; se revierten a los doce segundos si no se aceptan.

## Qué contiene esta entrega

- Entre 100 y 132 módulos en cinco sectores, distribución reproducible, rutas alternativas y salida distante.
- Veinte definiciones de habitaciones/espacios y más de quince tipos de muebles originales provisionales.
- Habitaciones subdivididas, puertas físicas, cobertura reservada y navegación validada.
- Menú principal, ajustes persistentes de gráficos/imagen/controles/audio, créditos y pausa real.
- Refugio reversible, salida libre, checkpoint individual y reintento.
- Forward+, perfil Compatibility, iluminación cálida/fría, moqueta y papel mural procedurales, niebla y filtro analógico regulable.
- Ambiente aportado por el usuario en bucle y música en buses separados.

**Todavía no hay IA, ataques, cooperativo, hoja compartida ni cuatro pisos jugables.** El mobiliario y materiales siguen siendo provisionales; no se presenta como una entrega fotorrealista. La duración de 25–40 minutos por piso necesita pruebas humanas de exploración.

F9 activa una derrota de prueba en ejecución de desarrollo, fuera del refugio. El personaje de Locust permanece disponible en el prototipo histórico; no hay una criatura activa en este hotel.

## Abrir y validar

**Abrir en Godot.cmd** abre el proyecto; F5 ejecuta el hotel. La arquitectura y el mobiliario se construyen al iniciar el nivel a partir del manifiesto; no son una colección de nodos guardados manualmente en la escena.

Desde PowerShell en la carpeta del proyecto:

```powershell
./tools/godot.ps1 play
./tools/godot.ps1 compatibility
./tools/godot.ps1 editor
./tools/godot.ps1 test
./tools/godot.ps1 hotel-batch
./tools/godot.ps1 hotel-walkthrough
```

Las pruebas nuevas usan archivos `test_hotel_*` separados de las preferencias/checkpoints normales. `hotel-batch` construye mil mapas y recorre veinte con movimiento real automatizado; puede tardar varios minutos. `hotel-walkthrough` abre una ventana, recorre un piso y guarda capturas.

Herramientas adicionales: `hotel_audio_test.gd` comprueba la mezcla y el bucle del ambiente; `hotel_benchmark.gd` mide tres vistas por calidad a 1080p. Ejecutarlas con Godot, `--path` al proyecto, `--script res://tools/<archivo>` y, tras `--`, `--automation --test-profile --silent`.

## Prototipo anterior

`./tools/godot.ps1 legacy` abre el H1 de fusibles con Locust estático. `legacy-test`, `h1-test`, `audio-test` y `walkthrough` conservan sus pruebas históricas. `build` reconstruye exclusivamente la escena histórica y sobrescribe esa escena; no genera el hotel actual.

## Estructura y documentación

- `scenes/hotel.tscn`: entrada actual; `scripts/hotel/`: sesión, generador/validador, geometría, jugador, ajustes y menús.
- `scenes/main.tscn` y scripts anteriores: prototipo histórico de fusibles.
- `docs/GAME_DESIGN.md`, `ROADMAP.md`, `TODO.md`: diseño v0.4, orden y estado real.
- `docs/V04_VALIDATION.md`: resultados y limitaciones de esta entrega.
- `docs/ASSETS.md`, `hotel_audio_inventory.json`: procedencia, créditos y análisis técnico.
- `docs/history/`: plan v0.3 conservado.
- `evidence/`: resultados y capturas regenerables, excluidos de Git.

El proyecto usa los archivos locales compartidos entre Codex y Godot; no incorpora una API de ChatGPT en el juego. Los audios originales y paquetes de personajes aportados se conservan. Antes de distribuir deben resolverse los permisos pendientes de los assets; no se descargó ni acreditó como usado un modelo de Sketchfab que no se haya incorporado.
