# Validación del prototipo 0.2

16/09/2026 · Godot 4.7.2 stable Steam · Windows · OpenGL Compatibility · NVIDIA GeForce RTX 4060 Ti.

## Migración

Repositorio principal: `E:\Projects\The Four`. Se conserva el historial de 0.1 (`ec1cc07`, `30c9122`). El Git migrado pasó `git fsck --full`; los restos de la carpeta Git original se eliminaron solo después de comparar sus archivos con el destino. El proyecto anterior ya no contiene una segunda copia activa.

El ZIP y MP3 aportados se conservan en `source_assets/`; el archivo GLB extraído es idéntico al del ZIP y el MP3 usado es idéntico al original. Las huellas se registran en `asset_hashes.json`.

## Pruebas automatizadas

`tests/legacy/smoke_test.gd`: 18 comprobaciones.

- Suelo y gravedad.
- Movimiento hacia delante y aumento de velocidad al correr.
- Colisión contra paredes y paso por puertas.
- Salto y aterrizaje.
- Rotación con ratón y límite vertical de cámara.
- Detención de movimiento cuando el control está inactivo.
- Colisión y posición estática del enemigo.
- Existencia de la instancia GLB y sus dos mallas.
- Tipo de audio MP3, duración y bucle habilitado.
- M silencia y restaura el bus de música.
- Límites superior e inferior de volumen.

`tests/legacy/audio_test.gd`: dos comprobaciones adicionales.

- Mezcla de muestras reales del MP3: 57.344 frames capturados, pico aproximado 0,025 a −22 dB. Confirma decodificación y mezcla; no es una evaluación artística de la canción.
- Retorno automático al principio al alcanzar el final: reproducción continuó alrededor de 0,80 s después del salto de bucle.

Resultados completos regenerables en `evidence/tests.json` y `evidence/audio_test.json`, fuera del historial Git.

## Inspección visual

Captura del viewport real de Godot: modelo texturizado, pose estática, escala, escenario y HUD. Render Compatibility sin errores en el registro de la captura. Se ajustó el apoyo vertical del modelo; el GLB original no se reescribió.

## Límites

Estas comprobaciones validan el prototipo actual. No validan IA, generación de mapas, victoria/derrota, muerte o interacciones: esas funciones son propuestas documentadas en `GAME_DESIGN.md` y aún no están implementadas. La calidad del corte musical al reiniciar el bucle puede refinarse más adelante con una edición autorizada o una pista creada para bucle.
