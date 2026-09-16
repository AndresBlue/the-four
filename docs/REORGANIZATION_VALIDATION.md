# Reorganización del proyecto — 16 de septiembre de 2026

Se conservan The Four 0.4-S1, Godot 4.7.2 Steam y generador v3. El trabajo reorganiza y hace editables los componentes; no completa nuevos hitos de juego.

## Cambios

- Escenas y scripts agrupados por función en `game/`; prototipo de fusibles aislado en `legacy/fuse_prototype/`.
- Escena principal con servicios, jugador, interfaz y presentación visibles; escenas reutilizables de jugador y Locust.
- HUD y contenedor de menús editables, iluminación en un recurso Environment, catorce materiales y cinco shaders externos.
- Recetas de mobiliario separadas del constructor de arquitectura; nodos generados con nombres identificables.
- Galería de referencia de los veinte módulos, cámara de inspección y comando para regenerarla.
- Pruebas y utilidades clasificadas; `tools/verify.ps1` ejecuta las regresiones con perfiles separados.
- Siete originales sueltos trasladados a `source_assets/audio/` y `source_assets/characters/`, conservando sus bytes. Las copias activas siguen en `assets/`.
- Guía `DEVELOPMENT.md`, convenciones de texto y nombres de capas físicas.

## Evidencia ejecutada

- Contratos de escenas: **9/9**, incluidos aislamiento de cápsula/entorno/filtro por instancia, dependencias inicializadas y galería de veinte módulos.
- Hotel: **34/34**, con mil semillas de grafo, movimiento, puertas, pausa, ajustes, refugio, salida, muerte y checkpoint.
- Supervivencia: **33/33**, incluidos percepción, navegación, ataque, escondites y reintento.
- Audio: **4/4**, reproducción, bucle, silencio del ambiente y aviso independiente de música/efectos.
- Prototipo histórico: **18/18** regresiones básicas y **37/37** del H1 de fusibles.
- Lote físico adicional: **20/20 semillas y 20/20 recorridos hasta la salida**, sin teletransportes ni fallos. No se presenta como una nueva ejecución física de mil semillas; el millar de esta verificación corresponde al grafo.
- Auditoría de referencias: ninguna ruta literal faltante en escenas, scripts o recursos revisados.
- SHA-256 de los siete originales trasladados y assets anteriormente catalogados: conservados.
- UIDs existentes de scripts movidos: conservados. Generador, definición y validador: código idéntico al anterior tras sustituir rutas.
- Capturas del menú, ajustes, habitación y refugio revisadas con Forward+ en RTX 4060 Ti; galería con render real.

Los resultados locales están en `evidence/verification.json`, `scene_contracts.json`, `reorganization_batch.json`, `reorganization_integrity.json` y los registros `verify_*.log`. La galería se genera con `tools/editor/build_gallery.gd`.

## Incidencias resueltas durante la verificación

La inspección visual detectó que la galería guardada en modo sin pantalla perdía las transformaciones de MultiMesh. La galería ahora guarda mallas convencionales editables; una regresión comprueba su geometría al cargarla. El juego conserva su agrupación de mallas optimizada.

Una prueba nueva detectó un valor de iluminación ambiental distinto al extraer el recurso: se corrigió y la prueba verifica los valores originales. Se corrigió además una anotación de tipo del propio test. La captura de audio falló una vez al ejecutarse simultáneamente con otras suites; las ejecuciones aisladas y el verificador secuencial pasaron. El verificador conserva la ejecución de audio en tiempo real y secuencial.

## Límites

La galería es una referencia regenerable y no modifica los niveles. El mapa y el contenido de los menús siguen generándose por código; no se incorpora un editor visual de generación. No se repitió balance humano ni una campaña cooperativa y no se atribuyen mejoras de rendimiento a esta reorganización. Los permisos de los assets siguen pendientes. `source_assets/` permanece fuera de Git y necesita copia de seguridad aparte.
