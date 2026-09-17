# Validación 0.4-S1 — hotel variable y The Locust

## Estado vigente (17/09/2026)

Los valores de las secciones siguientes son históricos (16/09/2026). Los vigentes están en [GAME_DESIGN.md](GAME_DESIGN.md): Locust con visión de 120°/70 m, oído por rutas a 2,6 veces el radio, persecución 6,4 m/s, estocada de 0,3 s con alcance de 3,2 m; resistencia 8/s de gasto y 6/s de recuperación tras 3 s; escondites en armarios con puertas y asomarse. Pruebas actuales: `survival_tests.json` 36/36, `spatial_audio.json` 27/27, `hotel_tests.json` 34/34. Las partidas humanas siguen pendientes.

## Registro histórico

Fecha: 16/09/2026. Godot 4.7.2 Steam, Windows, RTX 4060 Ti. Proyecto local `E:\Projects\The Four`. Esta entrega adelanta supervivencia individual a petición del usuario y amplía P1/P2. No incorpora cooperativo ni muebles externos.

## Cambios comprobados

- Generador v3: módulos rectangulares de 12/14/18 × 12/16/20 m, conexiones de espacios comunes de dos/tres módulos sin paredes internas, y cuatro variantes de partición doméstica. Se mantiene una base ortogonal; no es geometría arbitraria ni cambiante durante la partida.
- Navegación calculada desde colisiones de arquitectura y muebles, con consultas completas para mapas grandes. Validación de accesos a los cuatro escondites de cada módulo no protegido.
- Agacharse, cápsula y cámara reducidas, resistencia 100, gasto 20/s y recuperación 15/s después de 1,5 s. Agotamiento requiere recuperar 25 antes de volver a correr.
- Locust: patrulla, visión de 80°/14 m con confirmación de 0,35 s, oído atenuado por paredes, investigación, persecución y búsqueda de 10 s. Puertas abren lentamente y la criatura espera; su hoja mantiene oclusión mientras gira.
- Ataque a menos de 1,2 m, línea de visión comprobada, preparación de 0,7 s con señal sonora/texto/pose y recuperación de 1,2 s. Alejarse permite esquivarlo. Refugio inmune a percepción/captura. Reintento reinicia amenaza, 15 s de protección inicial, resistencia y escondite.
- Escondites interactivos junto al perímetro: sin movimiento y con mirada limitada. Entrada observada o inspección frontal cercana puede revelar al jugador. Captura dentro de escondite verificada con aproximación real.
- Polvo de escala pequeña, cortinas móviles, madera procedural, niebla localizada Forward+ y sondas de reflexión. Efectos reducidos desactivan movimiento de cortinas y polvo/niebla. Interface fuera del filtro VHS.
- Pasos y aviso sintetizados originalmente; reducción de música/ambiente durante preparación del ataque. Modelo existente a 1,65× y animación procedural provisional; originales intactos.

## Evidencia automática

- `evidence/hotel_tests.json`: **34/34** comprobaciones de menú, ajustes, puertas, movimiento, checkpoint, respaldo y salida, además de 1.000 grafos reproducibles.
- `evidence/hotel_generation_acceptance.json`: **1.000/1.000 semillas físicas válidas**, semillas 0–999, y **20/20 recorridos automáticos** finales con movimiento, puertas y victoria, sin teletransportar posiciones. Fuentes: `hotel_batch.json` (física/navegación) y `hotel_walks_final.json` (recorridos). La arquitectura se prueba con IA desactivada expresamente; no acredita escapar de Locust en mil partidas.
- `evidence/survival_tests.json`: **33/33** comprobaciones con física real: resistencia/postura, visión, oclusión, ruido, investigación, búsqueda limitada, persecución, anticipación/esquiva, cruce de puerta lenta, escondite observado, refugio, captura y reintento.
- `evidence/hotel_audio.json`: **4/4** — señal decodificada en mezcla, bucle, silencio del bus y aviso de ataque audible con música/efectos generales silenciados. Prueba en tiempo real, con niveles iniciales explícitos para ser repetible.
- `evidence/smoke_test.log`: **18/18** regresiones del prototipo histórico. No se utilizan para acreditar la IA nueva.
- Capturas inspeccionadas: salón conectado, habitación doméstica, Locust, escondite, refugio y menús. `survival_capture.gd` coloca la cámara para inspección; estas capturas no se presentan como recorridos manuales.

Durante el lote físico, un recorrido automático chocó con el cuerpo inmóvil de Locust porque el antiguo modo `--no-enemy` solo detenía la IA. Se corrigió el aislamiento de arquitectura y se repitieron los veinte recorridos: todos pasan. El informe consolidado conserva la incidencia original y enlaza la repetición correcta. En la partida normal, la colisión de la criatura permanece activa.

## Muestras de rendimiento

Semilla 81, 121 módulos, 1920×1080, tres vistas por calidad y 180 muestras por perfil. Sin límite de FPS ni sincronización vertical, criatura desactivada para comparar presentación.

- Forward+: P95 baja **3,506 ms**, media **3,558 ms**, alta **3,519 ms**. Carga del piso **731 ms**. Memoria estática observada **197,741,216 bytes**.
- Compatibility: P95 baja **4,37 ms**, media **6,462 ms**, alta **6,677 ms**. Carga del piso **674 ms**. Memoria estática observada **140,210,124 bytes**. Sin crear recursos de niebla incompatibles con OpenGL.

Son muestras breves, no una garantía sostenida de 60 FPS ni medición de toda la memoria del proceso/VRAM. Falta medir persecuciones largas, escenas extremas y futuro cooperativo.

## Límites y aceptación pendiente

- Veinte recorridos **humanos** y cinco partidas de exploración: pendientes. No se acredita duración de 25–40 minutos ni sensación de orientación/terror con las pruebas automáticas. Protocolo: [PLAYTEST_HOTEL.md](PLAYTEST_HOTEL.md).
- Muebles externos pendientes por decisión del usuario. Materiales, movimiento de criatura y acabado artístico son provisionales; no se afirma fotorrealismo.
- Falta balance humano de frecuencia de encuentros, escondites, legibilidad de muertes y capacidad práctica para cuatro jugadores.
- Sonido contextual completo, acústica por habitación y selección final de los cinco audios siguen pendientes.
- Red, hoja, acompañamiento cooperativo, otros tres enemigos y campaña completa pendientes.
- Checkpoints del generador v2 no se convierten a v3: se informa incompatibilidad y se conserva el archivo. Para probar esta entrega, iniciar partida nueva.
- Permisos de distribución del modelo y música siguen pendientes; no se publicaron ni subieron assets.

## Reproducción

Desde la raíz: `./tools/godot.ps1 test`, `survival-test`, `hotel-batch`, `hotel-audio` y `hotel-benchmark`. Los tests usan perfiles propios. Arquitectura usa `--no-enemy`; supervivencia mantiene la amenaza activa. `./tools/godot.ps1 playtest -Seed 81` inicia una partida visible reproducible para evaluación humana.

La configuración de consultas de rutas se contrastó con la [documentación oficial de NavigationPathQueryParameters3D](https://docs.godotengine.org/en/stable/classes/class_navigationpathqueryparameters3d.html): el límite predeterminado de búsqueda puede devolver una ruta parcial en mapas grandes. Se valida además que la ruta llegue realmente a la salida.
