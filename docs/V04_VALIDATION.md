# The Four — Validación 0.4-P1

Fecha: 16/09/2026. Godot 4.7.2 Steam, Windows, NVIDIA RTX 4060 Ti.

Revisión de código: fd0aa1ecb70be27c00293cfef90d26f7e85c3f5a. Generador: versión 2.

## Alcance y resultado

Primera entrega individual implementada: hotel procedural, menú, ajustes persistentes, puertas, mobiliario provisional, linterna, salida libre, refugio reversible y checkpoint de inicio. No acredita cooperativo, IA, escondites interactivos ni campaña completa.

- **34 comprobaciones funcionales aprobadas:** semillas, módulos, movimiento, pausa, interacción, puertas, ajustes, controles, protección del refugio, salida, muerte de prueba, reintento, guardado e incompatibilidad.
- **1.000 semillas de distribución:** reproducibles, conectadas y sin necesidad de respaldo en el lote 0–999.
- **1.000 mapas construidos y validados físicamente:** barridos de cápsula en pasos, espacios reservados de cobertura y entradas de habitaciones subdivididas, además de ruta de navegación hasta la salida. Ningún fallo en el lote final.
- **20 recorridos físicos automatizados**, semillas 0–19: entradas de movimiento/interacción, apertura de puertas y victoria, sin teletransportar al personaje.
- **3 pruebas de audio:** decodificación real, bucle y silencio del bus ambiental.
- **18 regresiones históricas aprobadas:** movimiento, colisiones, Locust y controles de música del H1. No se atribuyen al juego cooperativo futuro.
- Importación de scripts y recursos sin errores. Inspección visual de menú, ajustes, habitaciones y refugio.

Los veinte recorridos automáticos del lote final no se presentan como partidas manuales o humanas. Durante la depuración también se realizaron recorridos renderizados de referencia. Las capturas de inspección y las mediciones de rendimiento sí reposicionan la cámara deliberadamente; no forman parte de la evidencia de recorrido sin teletransporte.

## Correcciones verificadas

El recorrido físico detectó que una hoja de puerta podía empujar al jugador contra su marco. Ahora la colisión se suspende durante el giro y se restaura cuando no solapa al personaje; el cierre comprueba ocupación antes y después. La regresión comprueba que vuelve a ser sólida.

Los lotes de reconstrucción detectaron que consultar navegación inmediatamente podía devolver una ruta antigua o vacía. El mapa estático se sincroniza sin iteraciones asíncronas y la partida no comienza hasta comprobar una ruta que alcance la salida real. No se utiliza la función obsoleta de actualización forzada.

La inspección visual detectó cabeceros frente al acceso. Los muebles principales ahora se orientan según las paredes y se ajustan al tamaño de las zonas domésticas; se añadieron barridos específicos de acceso y se repitió el lote físico completo. Se incrementó la versión del generador para no prometer reproducción con distribuciones anteriores.

## Rendimiento y presentación

Se miden tres vistas de un mapa de 121 módulos a 1920 × 1080, con calentamiento y 180 muestras por calidad. VSync y límite de FPS se desactivan solo durante la medición. Los informes guardan media y percentil 95, tiempo de carga y memoria estática del motor.

Informes: [Forward+](validation/hotel_benchmark_forward_plus.json) y [Compatibility](validation/hotel_benchmark_gl_compatibility.json). Ambas muestras quedan bajo el presupuesto de 16,67 ms por fotograma para 60 FPS. Es una medición breve de escenas seleccionadas, no una prueba sostenida de campaña ni de la escena futura más exigente. Memoria estática no equivale a memoria total del proceso o VRAM.

Los muebles y materiales siguen siendo provisionales. Los efectos actuales son una base, no aceptación de fotorrealismo. Los perfiles reducidos conservan geometría, puertas, salida, HUD y legibilidad de menús; falta validar las futuras señales de criaturas y la hoja.

## Evidencia reproducible

Los informes de cierre están versionados en `docs/validation/`:

- [Comprobaciones funcionales](validation/hotel_tests.json).
- [Lote físico y veinte recorridos](validation/hotel_batch.json).
- [Audio](validation/hotel_audio.json).
- [Regresión histórica](validation/legacy_tests.json).

Las ejecuciones escriben nuevos informes y capturas en `evidence/`, excluido de Git. Las herramientas de prueba usan preferencias/checkpoints separados por herramienta y nunca el perfil normal.

```powershell
./tools/godot.ps1 test
./tools/godot.ps1 hotel-batch
./tools/godot.ps1 hotel-audio
./tools/godot.ps1 hotel-walkthrough
./tools/godot.ps1 hotel-benchmark
./tools/godot.ps1 legacy-test
```

El lote físico puede tardar varios minutos. `hotel-walkthrough` abre una ventana y maneja el personaje hasta la salida; `hotel-benchmark` mide el render principal. Para comparar Compatibility, ejecutar el mismo script con `--rendering-method gl_compatibility`.

## Aceptación pendiente

- Veinte recorridos manuales y cinco partidas de exploración humana para orientación, monotonía y duración. La meta de 25–40 minutos no está comprobada.
- Escucha y selección final de todos los audios nuevos, mezcla contextual y catálogo de SFX/VFX.
- Mobiliario/materiales finales y permisos para distribución.
- Pruebas propias de cooperativo, hoja, IA, muerte por criaturas, cuatro pisos y rendimiento sostenido.

La implementación de P1 puede jugarse y revisarse; estos pendientes permanecen abiertos en el TODO y no se marcan como satisfechos por la automatización.
