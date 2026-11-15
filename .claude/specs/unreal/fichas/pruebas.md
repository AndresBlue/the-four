# Ficha de hechos: pruebas, bots, bancos y verificación

Fecha: 14 de noviembre de 2026. Repositorio: `E:/Projects/The Four` (rama `main`).
Encargo: levantar los hechos de `tests/`, `tools/verify.ps1`, `tools/godot.ps1`, `tools/bots/`, `tools/bots.ps1`, `tools/benchmarks/` y `tools/dev/` para diseñar el port de esta parte a Unreal 5.8.4. Solo hechos; no hay diseño de Unreal aquí.

**Marcas**

| Marca | Significa |
|---|---|
| **[C]** | Comprobado leyendo el archivo local. Va con ruta:línea. |
| **[E]** | Dato sacado de un artefacto de ejecución local (`evidence/verification.json`, logs de `evidence/`). Dice cuándo se generó. |
| **[D]** | Deducción a partir de [C]. Sin ejecutar. |

Ruta corta usada abajo: `T:` = `tests/`, `TOOLS:` = `tools/`, `DOC:` = `docs/`.

---

## 0. Alcance y límites de la lectura

- **Leído entero:** `tools/verify.ps1` (194 líneas), `tools/godot.ps1` (170), `tools/bots.ps1` (214), `tools/net_test.ps1` (40), `tools/bots/bot_run.gd` (60), `tools/benchmarks/run_bench.ps1` (41), `tools/benchmarks/bench_table.ps1` (19), `T:tests/hotel/creature_contract_test.gd` líneas 1 a 1560 de 2079, `evidence/verification.json` (63 entradas).
- **Leída la cabecera de los 54 archivos `.gd` de `T:`** (comentarios `##` de arriba y `extends`/`const`), y el resultado de contar por archivo las llamadas a `check(`, las funciones, las esperas (`await`) y las referencias a escenas (`tscn`, `start_floor`).
- **Leídas solo las funciones y los títulos de `check()` (no el cuerpo) de:** `office_test.gd` (1381), `lurker_shell_test.gd` (947), `stages_test.gd` (847), `net_test.gd` (806), `capture_test.gd` (801), `office_light_test.gd` (747), `hotel_test.gd` (723), `lurker_fairness_test.gd` (718), `survival_test.gd` (691), `lurker_senses_test.gd` (525), `echo_test.gd` (504). Los cuerpos de estos once no están leídos: es el principal hueco de esta ficha (ver apartado 12).
- **Leído solo el resto de `creature_contract_test.gd` (líneas 1560 a 2079) por sus títulos de `check()`.**
- **Leídas las cabeceras y la lista de funciones de `tools/bots/*.gd` (4.942 líneas en total) y `tools/dev/*` (unas 60 herramientas).** No se han leído los cuerpos de `bot_brain.gd` (1229), `bot_replay.gd` (615), `bot_team.gd` (567), `bot_threat.gd` (445), `bot_threat_lurker.gd` (441), `bot_match.gd` (481), ni los de `tools/dev/capture_bench.gd` (764), `lurker_telemetry.gd` (468), `map_metrics.gd` (456), `lurker_route_probe.gd` (459) ni `body_clip_probe.gd` (285).
- **No se ha ejecutado nada:** ni Godot, ni `verify.ps1`, ni Unreal. Los tiempos son los de la última ejecución registrada en `evidence/verification.json` [E].

---

## 1. Inventario de archivos leídos

### 1.1 Orquestación y lanzadores

| Archivo | Líneas | Qué hace |
|---|---|---|
| `TOOLS:verify.ps1` | 194 | Ejecuta las 63 comprobaciones en tres lotes en paralelo, con tiempo límite por cada una, y deja `evidence/verification.json`. |
| `TOOLS:godot.ps1` | 170 | Lanzador único de Godot con 25 modos (`play`, `test`, `bots`, `export`...). |
| `TOOLS:bots.ps1` | 214 | Juega muchos pisos con bots, uno por proceso, vigila cada uno y escribe `resumen.txt` y `summary.json`. |
| `TOOLS:net_test.ps1` | 40 | Lanza 2 o 3 procesos de Godot (host y invitados) en 127.0.0.1 para un escenario de red. |
| `TOOLS:history.ps1` | 6219 bytes | No leído (fuera del encargo). |
| `TOOLS:benchmarks/run_bench.ps1` | 41 | Lanza `hotel_benchmark.gd` con una etiqueta; modo `-Modest` simula un equipo modesto. |
| `TOOLS:benchmarks/bench_table.ps1` | 19 | Imprime en tabla el `report.json` de una o varias etiquetas. |

### 1.2 Tests (`T:`) y cabecera de cada uno

Lista completa con líneas, llamadas a `check(`, esperas y lugar en `verify.ps1` en el apartado 3. Las cabeceras se leyeron en todos los archivos [C]. Los ficheros que no son pruebas: `T:tests/office/lurker_fixture.gd` (104 líneas, plan de cuatro celdas compartido por dos pruebas [C] cabecera de `T:tests/office/lurker_fixture.gd`), `T:tests/hotel/manifest_golden.json` (70.562 bytes, la referencia dorada, cabecera de `T:tests/hotel/manifest_golden_test.gd`), y los tres envoltorios de `office_test.gd`: `T:tests/office/office_test_generator.gd`, `office_test_validator.gd` y `office_test_physics.gd` (7 a 8 líneas cada uno, fijan la variable `part` [C] `T:tests/office/office_test_generator.gd:6-8`).

### 1.3 Herramientas `TOOLS:bots/` (cabecera y líneas)

| Archivo | Líneas | Qué hace (primera línea de su cabecera) |
|---|---|---|
| `bot_run.gd` | 60 | Un piso jugado por bots, sin ventana, y su resumen en `summary.json`. Sin `--test-profile` sale con código 2 [C] `TOOLS:bots/bot_run.gd:23-25`. |
| `bot_match.gd` | 481 | Piso entero jugado por bots: lo monta con sus puestos y pone las reglas del juego a sus cuerpos. |
| `bot_brain.gd` | 1229 | Cerebro de un bot: toma tareas del equipo y las hace. |
| `bot_team.gd` | 567 | Lo que los bots saben juntos y quién hace qué. |
| `bot_nav.gd` | 225 | Ruta de un bot por la malla de navegación. |
| `bot_senses.gd` | 114 | Lo que un bot ve y oye. |
| `bot_body.gd` | 157 | Cuerpo de un superviviente bot (un `remote_player` que camina). |
| `bot_threat.gd` | 445 | Modelo del Locust para los bots: lo sabe todo, todo el tiempo. |
| `bot_threat_lurker.gd` | 441 | Modelo de La Acechadora (Lurker) para los bots. |
| `bot_threat_none.gd` | 29 | Modelo de una planta sin criatura. |
| `bot_threats.gd` | 18 | Elige el modelo según la clase de criatura del piso. |
| `bot_watch.gd` | 108 | Juega pisos seguidos mientras se miran en el observador. |
| `bot_watchdog.gd` | 138 | Vigila la partida desde fuera: `watch_creature()` audita a la criatura y reporta incidencias. |
| `bot_recorder.gd` | 252 | Escribe todo lo que hace una partida de bots para verla luego. |
| `bot_replay.gd` | 615 | Vuelve a ver una partida grabada en el observador. |
| `bot_replay_puppet.gd` | 33 | Cuerpo de un bot en la repetición. |
| `bot_error_tap.gd` | 30 | Recoge los errores del motor durante una partida de bots. |

### 1.4 Herramientas `TOOLS:benchmarks/` y `TOOLS:dev/`

| Archivo | Líneas | Qué hace |
|---|---|---|
| `TOOLS:benchmarks/hotel_benchmark.gd` | 467 | Coste de fotograma del hotel a 1080p por calidad: tres vistas quietas y un recorrido caminando. Imprime líneas `BENCHMARK`. |
| `TOOLS:benchmarks/preset_sheet.gd` | 65 | Pone los cuatro presets de una vista en una hoja para juzgarlos a ojo. |
| `TOOLS:benchmarks/compare_captures.gd` | 54 | Compara dos carpetas de capturas imagen a imagen (diferencia media y máxima). |
| `TOOLS:dev/*` | unas 60 | Sondas y miradas. Su uso se resume en el apartado 7. |

---

## 2. Cómo corre `verify.ps1`

### 2.1 Paralelismo y lotes

- Paralelismo por defecto: `max(2, min(8, floor(ProcessorCount / 3)))` [C] `TOOLS:verify.ps1:22`. En este equipo (24 hilos) da **8**.
- Tres lotes, uno tras otro [C] `TOOLS:verify.ps1:186-190`:
  1. **Lote 1**, con `--fixed-fps 60` (reloj fijo): todas las pruebas que no son de audio y de red, más las sondas y los chequeos de capas y de shaders. Límite de simultáneas: el parámetro `-Jobs`, es decir 8 [C] `TOOLS:verify.ps1:188`.
  2. **Lote 2**, red: los cinco escenarios a la vez, pero con como mucho **4** [C] `TOOLS:verify.ps1:189`. Cada escenario tiene su puerto fijo [C] `TOOLS:verify.ps1:120-121`: coop 24600, versus 24610, late 24620, observer 24630, office_coop 24650.
  3. **Lote 3**, audio en tiempo real: `hotel_audio_test`, `spatial_audio_test`, `office_audio_test`, con como mucho **2** [C] `TOOLS:verify.ps1:51, 190`.
- Los tests de audio y de red no llevan `--fixed-fps`: corren en reloj real [C] `TOOLS:verify.ps1:40, 114-115, 117-122` (en la lista, `$audio`).
- Dentro de cada lote se ordena por la duración de la última vez, la más larga primero [C] `TOOLS:verify.ps1:161`. Si falta registro, supone 60 s.

### 2.2 Argumentos de cada prueba

- Todas: `--headless --path <proyecto> --rendering-method forward_plus --script res://tests/<x>.gd --log-file evidence/verify_<nombre>.log -- --automation --test-profile --silent` [C] `TOOLS:verify.ps1:38-41, 52`.
- `hotel/hotel_test` e `hotel/intro_test` añaden `--no-enemy` [C] `TOOLS:verify.ps1:53`.
- `hotel/observer_test` añade `--port=24640` para no coincidir con un juego abierto [C] `TOOLS:verify.ps1:56`.
- `office/office_test_generator` tiene límite de 600 s; el resto de pruebas, 360 s [C] `TOOLS:verify.ps1:59`.
- Las sondas de `TOOLS:dev/` usan argumentos propios [C] `TOOLS:verify.ps1:66-79, 85, 99`: `creature_stuck_probe` con semillas 81 y 213, 6 viajes, `--strict`, límite 480 s; `lurker_route_probe` con 8 semillas, 2 viajes, `--short`, límite 150 s; la misma con `--unseen=pesadilla`, límite 90 s; `lurker_elbow_probe`, límite 90 s; `body_clip_probe`, límite 480 s; `hearing_probe` con semillas 81 y 213, límite 360 s.
- Capas de luz: `light_layers_scan.gd -- --test-profile 40`, y con `--floor=2` [C] `TOOLS:verify.ps1:104, 107`. Criterio: el log debe contener `LIGHT_LAYERS`.
- Shaders: `check_shaders.gd` con `forward_plus` y con `gl_compatibility`, con ventana (no `--headless`), `--test-profile --background`, límite 360 s [C] `TOOLS:verify.ps1:113-116`. Sin GPU informa `SHADERS_SKIPPED` y cuenta como aprobado [C] `TOOLS:verify.ps1:108-111`.
- Bots: `hotel/bots_test` (límite 600 s) y `office/office_bots_test` (límite 600 s), ambas en el lote 1 [C] `TOOLS:verify.ps1:89-94`.

### 2.3 Criterio de aprobado y de tiempo agotado

- Criterio general: código de salida 0 y ningún `ERROR:` (incluye `SCRIPT ERROR:`) en el log [C] `TOOLS:verify.ps1:142-143`.
- Capas de luz: además debe aparecer `LIGHT_LAYERS` [C] `TOOLS:verify.ps1:144`.
- Shaders: falla con `SHADER ERROR`, `Shader compilation failed` o `SCRIPT ERROR:` [C] `TOOLS:verify.ps1:145`.
- Red: aprobado si el JSON de `evidence/net_<rol>.json` dice `passed`, y no hay `SCRIPT ERROR:` en el log [C] `TOOLS:net_test.ps1:30-32`.
- Tiempo agotado: se mata el proceso y se marca como fallo [C] `TOOLS:verify.ps1:170-175`.
- Resultados: `evidence/verification.json` (campos `test`, `passed`, `exit_code`, `seconds`) [C] `TOOLS:verify.ps1:192-193`. Logs: `evidence/verify_<nombre>.log` [C] `TOOLS:verify.ps1:49`.
- Si algo falla, el script termina con error al final [C] `TOOLS:verify.ps1:194`.

### 2.4 Los tests de red en `net_test.ps1`

- Escenarios: `coop` (host, alpha, bravo), `versus` (vs_host, vs_hunter), `late` (late_host, late_guest), `observer` (watcher, watch_host, watch_guest), `office_coop` (office_host, office_alpha, office_bravo) [C] `TOOLS:net_test.ps1:12`.
- Cada rol es un proceso de Godot con `--headless --rendering-method forward_plus --script res://tests/net/net_test.gd -- --automation --test-profile --silent --role=<rol> --port=<puerto>` [C] `TOOLS:net_test.ps1:17`.
- Arranques escalonados de 700 ms entre procesos [C] `TOOLS:net_test.ps1:20`. Tiempo total por defecto 420 s [C] `TOOLS:net_test.ps1:1`.

---

## 3. Tabla de pruebas

**Columnas:** *checks* = número de llamadas a `check()` en el código (no es el número de ejecuciones). *Esperas* = `await` sobre `process_frame`, `physics_frame`, temporizadores u otras funciones propias (conteo grueso). *Juego* = si la prueba levanta escena de piso (`hotel.tscn`, `office` o `start_floor`) o corre el motor con fotogramas. *Último tiempo* = `evidence/verification.json` [E], en segundos, bajo carga de lote, así que no es el tiempo solo.

### 3.1 Hotel (`T:tests/hotel/`)

| Archivo | Líneas | checks | Esperas | Juego | Lote en verify | Último tiempo | Qué afirma (resumen de la cabecera) |
|---|---|---|---|---|---|---|---|
| `avatar_test.gd` | 155 | 15 | 6 | No carga piso | 1 | 1,1 s | Animación de los supervivientes medida en el esqueleto: pies fijos, rodillas, brazos, agachado, salto. El aspecto lo mira `tools/capture/avatar_gait_capture.gd`. |
| `bots_test.gd` | 338 | 24 | 18 | Piezas de piso | 1 | 28,5 s | Piso montado por piezas para los bots, reglas del juego sobre sus cuerpos, un bot que cierra una etapa a pie. |
| `capture_test.gd` | 801 | 69 | 54 | Sí | 1 | 71,7 s | La captura (`docs/EXECUTION.md`): la puntuación, la cámara del superviviente, el cuerpo sin atravesar paredes, cortar la escena a mitad, armarios. |
| `continue_test.gd` | 202 | 30 | 16 | Sí (5 refs) | 1 | 85,6 s | Continuar devuelve el piso como se dejó (`game/app/floor_save.gd`). Punto de control sin piso, piso no construido. |
| `creature_contract_test.gd` | 2079 | 120 | 6 | Sí (`start_floor(81)`) | 1 | 16,8 s | Contrato de la criatura (`game/enemies/creature.gd`) en el Locust: predicados por modo, RPC de red, `teleport()`, traslados (ascensor, tele, revival), captura y cómo la ven los consumidores. |
| `creature_test.gd` | 164 | 18 | 7 | Sí (2 refs) | 1 | 61,4 s | Rondas y búsquedas de la criatura en un piso sin nadie. No tiene línea `_RESULT`. |
| `difficulty_test.gd` | 445 | 55 | 26 | Sí (9 refs) | 1 | 147,6 s | Dificultades (`game/floors/difficulty.gd`): "desafiante" es el juego de antes, cifra a cifra; cada palanca va en el mismo sentido. |
| `echo_test.gd` | 504 | 68 | 32 | Sí (1 ref) | 1 | 20,4 s | Vista acústica del Locust: cadencia de chasquido, presupuesto de rayos, anillos, lo que un cuerpo revela, chillido, hitos. La imagen la mira `tools/capture/echo_capture.gd`. |
| `hotel_audio_test.gd` | 62 | 0 | 1 | Sí | 3 | 10,6 s | Sonido del hotel en tiempo real: sin `check()`, sale con código según cinco booleanos. |
| `hotel_batch.gd` | 110 | (usa `hotel_walkthrough`) | 6 | Sí | **No está en verify** | — | Recorre el hotel sin física. Modo de `godot.ps1` `hotel-batch`. |
| `hotel_test.gd` | 723 | 110 | 23 | Sí (6 refs) | 1 | 168,3 s | Hotel como lo dejan las etapas 1a y 1b (generador, validador, reglas del piso). Imprime `HOTEL_RESULT=`. |
| `hotel_walkthrough.gd` | 120 | 0 (imprime `STUCK`) | 8 | Sí | **No está en verify** | — | Recorrido completo del hotel, con capturas si hay pantalla. Modo `hotel-walkthrough`. |
| `intro_test.gd` | 69 | 18 | 13 | Sí (1 ref) | 1 | 18,5 s | Escena de apertura: se salta, lleva al piso, devuelve la vista. Lleva `--no-enemy`. |
| `loop_test.gd` | 293 | 33 | 8 | Sí | 1 | 17,7 s | Bucle de un piso: reglas y eventos del director de ritmo y los documentos sobre los muebles. |
| `manifest_golden_test.gd` | 39 | 6 | 0 | No (genera) | 1 | 65,8 s | Pisos del hotel byte a byte contra `manifest_golden.json`: 50 semillas por número de supervivientes (1 a 5) y el piso de reserva. |
| `objectives_test.gd` | 208 | 23 | 1 | Sí (2 refs) | 1 | 12,5 s | Objetivos como manejadores (`game/floors/objectives/`); lo que dan es lo que daba el código antiguo. |
| `observer_test.gd` | 117 | 16 | 8 | Sí | 1 | 23,9 s | Observador sin anfitrión (`game/app/observer_view.gd`): R y Mayúsculas+R cambian de piso, la planta elegida, ningún piso es de nadie. Puerto 24640. |
| `palette_scan_test.gd` | 302 | 21 | 0 | No (escanea texto) | 1 | 9,3 s | Ningún número de tipo de sala fuera de las paletas (`docs/OFICINAS.md` 11.2). **Fallo en la última ejecución** (ver 11). |
| `room_light_test.gd` | 218 | 16 | 10 | Sí | 1 | 12,2 s | Luz por sala (`room_layers.gd`): `lit()`, apagón de un ala, drenaje, `put_on_actor()`, `follow_bodies()`. |
| `rules_test.gd` | 185 | 38 | 12 | Sí (2 refs) | 1 | 12,2 s | Reglas que puede cambiar una sala (`game/floors/match_rules.gd`): mercedes, notas, onslaught, sets como puertas. |
| `sanity_test.gd` | 323 | 41 | 26 | Sí (3 refs) | 1 | 32,2 s | La cordura: medidor que baja a oscuras, sube con la luz, da mentiras, y marca el cuerpo para la criatura. |
| `scene_contract_test.gd` | 339 | 72 | 12 | Sí (6 refs) | 1 | 7 s | Contratos de escena: instancia `hotel.tscn` dos veces y compara. Imprime `SCENE_CONTRACTS`. |
| `spatial_audio_test.gd` | 361 | 58 | 23 | Sí | 3 | 28,2 s | Audio espacial en tiempo real, con `AudioEffectCapture`. |
| `stages_test.gd` | 847 | 177 | 50 | Sí (4 refs) | 1 | 36,2 s | Tres etapas encadenadas (no un solo encargo): cerrar una pasa a la siguiente, solo la última acaba el piso. |
| `survival_test.gd` | 691 | 99 | 57 | Sí (5 refs) | 1 | 43,1 s | Supervivencia: obstáculos, puertas (`door_gap`), armarios, kit del jugador. Imprime `DOOR_DEBUG` y `LEAF_DEBUG` (depuración). |

### 3.2 Oficinas, piso 2 (`T:tests/office/`)

| Archivo | Líneas | checks | Esperas | Juego | Lote | Último tiempo | Qué afirma |
|---|---|---|---|---|---|---|---|
| `office_test.gd` (en 3 partes) | 1381 | 92 | 3 | Parte "physics" sí | 1 (partes `generator`, `validator`, `physics`) | 449,2 / 30 / 68,4 s | Piso 2 como lo dejan 1a y 1b: paleta de nombres, tipo de sala, 64 pisos del generador hechos dos veces (iguales), validador por mutaciones de la semilla 7, texto. Con `--real-plan` juzga el plano real (`planta_real.md` 13). Imprime `OFFICE_TEST_RESULT`. |
| `office_test_generator.gd` | 8 | 0 | 0 | — | 1 | (incluido arriba) | Envoltorio: parte `generator`. |
| `office_test_validator.gd` | 7 | 0 | 1 | — | 1 | (incluido arriba) | Envoltorio: parte `validator`. |
| `office_test_physics.gd` | 8 | 0 | 0 | — | 1 | (incluido arriba) | Envoltorio: parte `physics`, ocho pisos montados. |
| `office_walk_test.gd` | 274 | 46 | 27 | Sí (2 refs) | 1 | 30,3 s | Piso 2 de principio a fin: tarjeta, tablero, ascensor de carga, post, ventiladores, trampilla, conducto principal, escalera del eje. |
| `conduit_graph_test.gd` | 112 | 17 | 0 | No (manifiestos) | 1 | 7 s | Grafo de conductos (`conduit_graph.gd`): árbol de tubos conectado, distancias, salidas más cercanas, cierres por ala. |
| `lurker_shell_test.gd` | 947 | 63 | 2 | No (stub, sin piso) | 1 | 88 s | Caparazón y rutas de La Acechadora (`lurker_shell.gd`, `lurker_routes.gd`): curvas, transformaciones, costuras, cobertura de paredes y armarios, rutas por puertas y ductos. |
| `lurker_motion_test.gd` | 329 | 23 | 0 | No (sin cuerpo ni física) | 1 | 8,1 s | Movimiento de La Acechadora (`lurker_motion.gd`) a 60 ticks por segundo: rutas, saltos del techo, paso, pausas. |
| `lurker_fairness_test.gd` | 718 | 34 | 12 | Sí (2 refs) | 1 | 22,2 s | Justicia de La Acechadora: nunca coge a quien no avisó, nunca antes de la ventana de aviso; 200 aproximaciones con semilla en un pasillo; parte A en un piso 2 construido. |
| `lurker_senses_test.gd` | 525 | 44 | 21 | Sí (2 refs) | 1 | 24 s | Sentidos de La Acechadora (`lurker_senses.gd`): vista en la oscuridad, oído por sala y por ductos, linterna, luz de lámparas, presa. |
| `office_lies_test.gd` | 349 | 20 | 12 | Sí (2 refs) | 1 | 26,5 s | Mentiras de La Acechadora por planta: cada planta miente con lo suyo; ninguna bebe luz ni toca objetivos. |
| `lurker_capture_test.gd` | 129 | 13 | 3 | Sí (2 refs) | 1 | 16,5 s | Captura de La Acechadora bajo un techo falso, por detrás: sujeción, cabeza, mordisco, cámara, sangre. |
| `office_dark_test.gd` | 63 | 7 | 1 | Sí (2 refs) | 1 | 37,6 s | Oscuridad del primer tramo del piso 2 por dificultad, misma semilla: Apacible todo encendido, Pesadilla lo que puede quedar a oscuras. |
| `jump_test.gd` | 34 | 4 | 1 | Sí (2 refs) | 1 | 14,6 s | "Saltar" (`hotel_main.jump_to`, `lifts.skip_stage()`): llevar a un sector y parar. |
| `descend_test.gd` | 37 | 9 | 3 | Sí (2 refs) | 1 | 22,3 s | Bajar del piso 1 al piso 2 (`unlock_floor2()`): dificultad guardada, nueva partida, construcción del piso 2. |
| `lurker_tiles_test.gd` | 216 | 18 | 5 | Sí (2 refs) | 1 | 15,2 s | Baldosas del techo falso por las que entra y sale La Acechadora, y cómo se abre y cierra. |
| `lurker_forced_test.gd` | 136 | 11 | 4 | Sí (2 refs) | 1 | 15,7 s | Encuentros forzados de La Acechadora en Pesadilla: no antes de `forced_after()`, ni hacia alguien escondido. |
| `lurker_observer_test.gd` | 161 | 18 | 3 | Sí (2 refs) | 1 | 14,8 s | Marcas de La Acechadora para el observador y lo que guarda una grabación de bots. |
| `lurker_bots_test.gd` | 181 | 11 | 5 | Sí (1 ref) | 1 | 35,1 s | Modelo de La Acechadora para los bots: una guardia detrás del trabajador; un experto se vuelve a tiempo con la linterna. |
| `lurker_mood_audio_test.gd` | 70 | 5 | 1 | No | **1** (no está en la lista de audio) | 0,5 s | Partitura de La Acechadora sin piso: tema de vuelta en 6 s tras huir; paso de ducto por compases. |
| `office_audio_test.gd` | 416 | 27 | 15 | Sí (2 refs) | 3 | 29,3 s | Sonido de La Acechadora en tiempo real: bus de ductos, por rejilla de la sala del oyente, nunca por pared. |
| `office_bots_test.gd` | 49 | 4 | 4 | Sí (1 ref) | 1 | 102,3 s | Dos bots oráculo juegan las oficinas de la ventanilla al ascensor de la escalera, sin incidencias graves; `STAGE_MOST := 240.0` segundos por nivel (línea 543). |
| `office_finishes_test.gd` | 346 | 53 | 2 | Sí (3 refs) | 1 | 20,6 s | Kit de construcción del piso 2: materiales propios, suelos, zócalos, friso, letreros, losa, rejillas, puertas. `TYPE_COUNT := 26` (línea 12). |
| `office_light_test.gd` | 747 | 129 | 2 | Sí (2 refs) | 1 | 15,4 s | Luz del piso 2: color de lámparas por tipo, luces de rebote, halos, accesorios, drenaje y potencia; semilla 7. |
| `office_pieces_test.gd` | 270 | 35 | 0 | No (mide mallas) | 1 | 2,7 s | Piezas hechas en código (`pieces/index.gd`): tamaños, regla de 2,2 m, triángulos, horneado una vez por constructor. |
| `office_dressing_test.gd` | 347 | 24 | 1 | Sí (2 refs) | 1 | 14,6 s | Decoración del piso 2, semilla 7: modelos, sillas frente a mesas, nada sobre puertas, cristal ni ruedas; imprime `OFFICE_DRESSING_RESULT n/n`. |
| `office_proportion_test.gd` | 299 | 13 | 5 | No (sin ventana) | **No está en verify** | — | Proporción de ocho pisos: tipo de suelo, anchura del objeto principal en el encuadre, recorrido del tablero al ascensor. Excluida: ver `TOOLS:verify.ps1:46`. |
| `lurker_fixture.gd` | 104 | 0 | 2 | — | — | — | Plan de prueba y dobles (no es prueba). |

### 3.3 Red (`T:tests/net/`)

| Archivo | Líneas | checks | Esperas | Juego | Lote | Último tiempo | Qué afirma |
|---|---|---|---|---|---|---|---|
| `net_test.gd` | 806 | 209 | 178 | Sí (procesos reales por ENet) | 2 (vía `net_test.ps1`) | coop 99,6 · versus 30,7 · late 67,7 · observer 37,8 · office_coop 88,3 s | Partida en red de extremo a extremo entre procesos en 127.0.0.1: sala de tres, mismo piso, puertas y armarios por el anfitrión, muerte vista, salida, reconexión a mitad de piso, cierre de sala. Cada rol escribe `evidence/net_<rol>.json`. |

### 3.4 Pruebas que `verify.ps1` no lanza

- `hotel_batch.gd`, `hotel_walkthrough.gd`: no están en la lista de `verify.ps1`; se lanzan a mano con `godot.ps1 hotel-batch` y `godot.ps1 hotel-walkthrough` [C] `TOOLS:godot.ps1:55-56`.
- `office_proportion_test.gd`: excluida a propósito [C] `TOOLS:verify.ps1:46`.
- Comprobación hecha por mí: de los 54 archivos `.gd` de `T:`, quedan fuera de la lista de `verify.ps1` solo `hotel_batch`, `hotel_walkthrough`, `net_test` (vía `net_test.ps1`), `lurker_fixture` (no es prueba), `office_proportion_test` y `office_test` (se lanza por sus tres partes con sus envoltorios) [C, grep sobre `TOOLS:verify.ps1`].

### 3.5 Sondas de `TOOLS:dev/` que corren dentro de `verify.ps1`

| Sonda | Último tiempo [E] | Qué afirma (cabecera) |
|---|---|---|
| `dev/creature_stuck_probe` (`--seeds=81,213 --trips=6 --strict`) | 50 s | La criatura se atasca: ningún alto de más de 2 s, ningún salto de su último recurso, ningún viaje sin acabar. |
| `dev/lurker_route_probe` (`--seeds=8 --trips=2 --short --strict`) | 60,7 s | Rutas de La Acechadora en el piso 2 construido: ningún salto no declarado, nunca en sala vedada, nunca por puerta cerrada. |
| `dev/lurker_route_probe --unseen=pesadilla` | 20,7 s | Lo mismo a las velocidades de Pesadilla sin ser vista. |
| `dev/lurker_elbow_probe` | 2,7 s | Los brazos de La Acechadora no atraviesan muebles, puertas ni supervivientes. |
| `dev/body_clip_probe` (`--strict`) | 68 s | El cuerpo de quien es cogido no entra más de 4 cm en ninguna pared (56 capturas). |
| `dev/hearing_probe` (`--seeds=81,213`) | 18,3 s | Desde encima de los muebles no hay navegación sobrante; la ruta al oído no es más corta que la recta. |
| `dev/light_layers_scan` (piso 1, 40 semillas) | 11,4 s | Dieciséis capas de render bastan: ninguna lámpara comparte capa con una sala que alcanza (`game/world/hotel/room_layers.gd`). |
| `dev/light_layers_scan --floor=2` | 120,6 s | Lo mismo en el piso 2. |
| `dev/check_shaders` (forward_plus) | 3,5 s | Todos los shaders se dibujan una vez; con ventana. |
| `dev/check_shaders` (gl_compatibility) | 2,7 s | Lo mismo con el renderizador de compatibilidad. |

---

## 4. Contratos que el port debe conservar

Estas son las pruebas que vigilan cosas que el gameplay necesita. Son el punto de partida de la verificación del port.

### 4.1 Manifiesto dorado (plantas generadas)

- cabecera de `T:tests/hotel/manifest_golden_test.gd` (líneas 2 a 7): los pisos del hotel salen del generador como se grabaron; 50 semillas por número de supervivientes (1 a 5) y el piso de reserva; cada manifiesto y los conjuntos asentados sobre él, byte a byte [C].
- Referencia: `T:tests/hotel/manifest_golden.json` (70.562 bytes) [C]. Lo genera `TOOLS:dev/record_manifest_golden.gd` (81 líneas, cabecera de su archivo) [C].
- Cada 6 `check()` de la prueba [C]. Último tiempo: 65,8 s [E].
- Regla de la casa: "El piso 1 (el hotel) no cambia salvo que el encargo lo diga: lo vigilan `manifest_golden_test` y `creature_contract_test`" (`CLAUDE.md`, sección de reglas para todos los agentes) [C].

### 4.2 Contrato de la criatura

- `T:tests/hotel/creature_contract_test.gd` (2079 líneas, 120 checks). Afirma:
  - Los predicados por modo (`is_hostile`, `is_attacking`, `is_hunting`, `is_chasing`, `is_engaged`, `is_roaming`, `accepts_leads`, `is_wary`) con sus listas literales: `T:tests/hotel/creature_contract_test.gd:105-124` [C].
  - `alarm_level()` por modo: 2 en caza, embestida, recuperación y alerta; 1 en investigación y búsqueda; 0 en el resto: `T:…:219-222` [C].
  - Las RPC de red: un diccionario `RPCS` con unas 50 entradas (conteo a mano) y su número de argumentos: `T:…:88` [C]. Una copia en red recibe el mismo estado: `T:…:562-586` [C].
  - Los tres sitios que mueven a la criatura (ascensor, tele y revival) dejan la criatura igual que lo hacía su mano antigua, incluidos sus sorteos: `T:…:833-901` [C]. Casos: 9 o más por sitio.
  - Las capturas: `begin_capture()` y `end_capture()` dejan el estado igual que lo hacía `executions.gd` [C] `T:…:1107-1129`. Cada marca de escena: `T:…:1333` (instantes 0, 0,05, 0,3, 0,62, 1,2, 1,9, 2,6, 3,4, 4,2 y 4,75 s) [C].
  - La criatura nula (`game/enemies/null_creature.gd`) no toma nada, no manda nada, no se oye: `T:…:1513-1549` [C].
- Lista de lo que la prueba considera "consumidores" del contrato: `T:…:66` (diez archivos) y `T:…:69` (nueve sin nada propio) [C].
- Los archivos que aún leen directamente a La Acechadora, por nombre: nada del Locust fuera de `KEPT` (`observer_view.gd` → `echo_view.gd`; `bot_nav.gd` → `door_threading.gd`) [C] `T:…:85`.

### 4.3 Justicia (La Acechadora)

- cabecera de `T:tests/office/lurker_fairness_test.gd` (líneas 2 a 9): nunca coge a quien no avisó, nunca antes de la ventana de aviso; mirar a la luz, una linterna en su cara o huir salva; caminar lejos no salva, correr sí (fecha de la cabecera: 24 de octubre de 2026) [C].
- Parte B: 200 aproximaciones con semilla sobre un pasillo recto, sin escena, contra la verdad del arnés y un oráculo que no lee el cerebro [C] (cabecera, línea 5).
- Pesadilla: cabecera de `T:tests/office/lurker_forced_test.gd` (líneas 2 a 5): encuentros forzados según `forced_after()` y `FORCED_REFRESH` [C].
- las cabeceras de `T:tests/office/lurker_shell_test.gd` y `lurker_motion_test.gd`: geometría y movimiento sin física [C].

### 4.4 Dificultad

- cabecera de `T:tests/hotel/difficulty_test.gd` (líneas 2 a 8): "desafiante" es el juego de antes, cifra a cifra; cada palanca va en el mismo sentido de la más fácil a la más difícil; el piso guarda la dificultad en el punto de control y en la cinta; la gracia de la sala se aplica por encima [C].
- Dificultades en el orden de `TOOLS:bots.ps1:30`: apacible, equilibrada, desafiante (por defecto), pesadilla [C].
- `TOOLS:bots.ps1:31`: experto (por defecto) o novato; el novato solo ve y oye lo que el bot percibe (`docs/DIFFICULTY.md` según la cabecera de `bots.ps1` líneas 15-17) [C].
- cabecera de `T:tests/office/office_dark_test.gd` (líneas 2 a 8): la oscuridad por dificultad en el piso 2 (Apacible todo encendido, Equilibrada según el manifiesto, Desafiante todo menos una décima parte, `office_geometry.LIT_LEFT`, Pesadilla lo que puede estar a oscuras) [C].

### 4.5 Manifiesto de piso 2 y generador

- `T:tests/office/office_test.gd:2-12` (cabecera): 64 pisos del generador, cada uno hecho dos veces, iguales y válidos; `--real-plan` juzga el plano real (`planta_real.md` 13) [C].

---

## 5. Bots y telemetría

### 5.1 `TOOLS:bots.ps1` (lote de pisos)

- Parámetros: `-Bots` 1 a 5 (defecto 3); `-Runs` 1 a 100.000 (defecto 10); `-Seed` (defecto 81); `-Seeds` (lista); `-Floor` 1 a 4 (defecto 1, el hotel); `-Mercy`, `-NoEnemy`, `-Oracle`; `-Difficulty` (defecto `desafiante`); `-Skill` (defecto `experto`); `-Parallel` 1 a 20 (defecto 2); `-MaxMinutes` 1 a 600 (defecto 45); `-StallSeconds` 20 a 3.600 (defecto 120); `-Strict` [C] `TOOLS:bots.ps1:18-37`.
- Un proceso de Godot por piso: `--headless --fixed-fps 60 --script res://tools/bots/bot_run.gd -- --test-profile --automation --silent --profile-tag=wN --bots=B --seed=S --floor=F --out=<carpeta> --commit=<hash> [--mercy] [--no-enemy] [--knowledge=oracle] --difficulty=D --skill=K` [C] `TOOLS:bots.ps1:61-66`.
- Carpeta del lote: `evidence/bots/<fecha>[-etiqueta]/`; por piso: `NN-s<semilla>-b<bots>/` con `run.log`, `heartbeat.json`, `summary.json`, `final_del_log.txt` si cayó [C] `TOOLS:bots.ps1:51, 57-60, 165, 208`.
- Vigilancia: el latido (`heartbeat.json`) se reescribe cada diez segundos de reloj; si calla más de `StallSeconds`, se mata y queda `colgado`; si pasa `MaxMinutes`, `tiempo_real_agotado`; si no deja `summary.json`, `caída` [C] `TOOLS:bots.ps1:97-110, 162`.
- Incidencias: `bot_*` (atascos del bot; grave si `severity = grave`), `criatura_*`, `no_encontrado`, `captura`, `muerte`, `error_motor`; las que no son `leve` salen en el resumen y con el comando para reproducir: `./tools/godot.ps1 bots-replay -Run "<carpeta>" -At <segundo - 8>` [C] `TOOLS:bots.ps1:146-158`.
- Resumen (`resumen.txt` y `summary.json`): ganadas, incidencias graves, errores del motor, y la línea de dificultad: porcentaje ganadas, sin derrumbes, caídas por piso, encuentros y persecuciones por bot, cuántas de cada diez persecuciones acaban en huida, y la mediana del rato sin la criatura [C] `TOOLS:bots.ps1:177-198, 208`.
- Código de salida con `-Strict`: 1 si hay procesos que no acabaron o incidencias graves [C] `TOOLS:bots.ps1:212-214`.

### 5.2 `TOOLS:bots/bot_run.gd` (un piso)

- Sin `--test-profile` sale con código 2: "un run sin él sobrescribió una vez el punto de control de un jugador" [C] `TOOLS:bots/bot_run.gd:5-8, 23-25`.
- Opciones por defecto: bots 3 (rango 1 a 5), semilla 81, `knowledge` = `discover` (el oráculo es `--knowledge=oracle`), `skill` = `experto`, `stage_cap` = 1800 s, `run_cap` = 5400 s [C] `TOOLS:bots/bot_run.gd:27-35`.
- Pone `Engine.max_fps = 0` tras el primer fotograma [C] `TOOLS:bots/bot_run.gd:44`.
- Escribe `summary.json` en la carpeta indicada y, al final, imprime `BOTS_RESULT <resultado> · semilla … · … incidencias, … graves` [C] `TOOLS:bots/bot_run.gd:51-55`.

### 5.3 `TOOLS:bots/bot_watchdog.gd` (vigilancia desde fuera)

- Dos partes: la escalera de atascos propia de cada bot y esta vigilancia (cabecera, `bot_watchdog.gd:1-3`) [C].
- `watch_creature()` pide a la criatura una auditoría (`threat.audit_creature(...)`) que devuelve tipo y gravedad [C] `TOOLS:bots/bot_watchdog.gd:58-69`.
- Escalar y abandonar: `on_escalated`, `on_abandoned` [C] `TOOLS:bots/bot_watchdog.gd:112-116`.

### 5.4 `TOOLS:bots/bot_watch.gd` y `bot_replay.gd`

- `bot_watch.gd` juega pisos seguidos en el observador: un piso acaba, gana o pierde, y sigue con la siguiente semilla [C] (cabecera de `godot.ps1:60-61` y `bot_watch.gd:1-3`).
- `bot_recorder.gd` escribe todo lo que hace la partida (252 líneas) y `bot_replay.gd` la vuelve a ver en el observador (615 líneas); la repetición se lanza con `godot.ps1 bots-replay -Run <carpeta> -At <segundo>` [C] `TOOLS:godot.ps1:73-78`.
- `bot_replay_puppet.gd` es el cuerpo de un bot en la repetición [C].

### 5.5 Telemetría de la criatura y de La Acechadora

- `TOOLS:dev/lurker_telemetry.gd` (468 líneas): "La Acechadora como juega hoy, en cifras: una partida de bots en el piso 2" [C] (cabecera). Cuerpo no leído.
- `TOOLS:bots/bot_threat_lurker.gd`: modelo de La Acechadora para los bots (`docs/OFICINAS.md` 11.6) [C] (cabecera).
- `T:tests/office/lurker_observer_test.gd` comprueba que lo que guarda la grabadora de bots de La Acechadora coincide con su modelo [C] (`T:…:1-10`).

### 5.6 Errores del motor durante los bots

- `TOOLS:bots/bot_error_tap.gd` (30 líneas) recoge todos los errores que el motor o un script reportan durante una partida de bots [C] (cabecera).
- `bots.ps1` cuenta errores con `SCRIPT ERROR:` y líneas que empiezan por `ERROR:` [C] `TOOLS:bots.ps1:126`.

---

## 6. Bancos de rendimiento

Fuente de cifras: `DOC:PERFORMANCE.md`, auditoría de septiembre de 2026 [C] (`DOC:PERFORMANCE.md:1-3`). Método [C] `DOC:PERFORMANCE.md:12-22`: 1080p, semilla 81, cuatro vistas (tres quietas y un recorrido caminando), espera de 1,5 s antes de medir, tiempo de fotograma (media, p95, p99 y máximo), GPU, hilo de render, llamadas y primitivas, VRAM. El PC de desarrollo es una RTX 4060 Ti con Ryzen 9 5900X [C] `DOC:PERFORMANCE.md:38, 201`. **Límite de 350 FPS** puesto por RivaTuner en este PC: no es el juego [C] `DOC:PERFORMANCE.md:23`.

### 6.1 Cifras de referencia (este PC, Forward+, sin límite de FPS)

Tabla por preset, recorrido caminando [C] `DOC:PERFORMANCE.md:461-467`, con seed 81:

| Preset | GPU caminando (ms) | Fotograma caminando media · p99 (ms) | GPU quieto (ms) | Llamadas de dibujo · de sombra | Memoria de vídeo | Carga del piso |
|---|---|---|---|---|---|---|
| Muy bajo | 0,52 | 2,85 · 4,04 | 0,48 | 156 · 0 | 359 MB | 10,1 s |
| Bajo | 1,36 | 2,90 · 4,80 | 1,28 | 154 · 65 | 494 MB | 10,4 s |
| Medio | 4,68 | 5,77 · 7,44 | 3,81 | 177 · 1.066 | 1.251 MB | 13,0 s |
| Alto | 9,87 | 11,10 · 14,37 | 7,82 | 178 · 1.898 | 1.982 MB | 13,9 s |
| Ultra | 14,58 | 15,83 · 20,23 | 12,31 | 200 · 1.944 | 2.182 MB | 14,0 s |

- Compatibilidad, mismo PC: Bajo 3,01 ms de GPU y 1.169 llamadas; Muy bajo 1,14 ms y 189 llamadas [C] `DOC:PERFORMANCE.md:469`.
- Nota del propio documento: Forward+ y Compatibilidad están en el tope de 350 FPS en este PC, así que su comparación de fotograma no sirve; la de GPU sí [C] `DOC:PERFORMANCE.md:469`.

### 6.2 Equipo modesto simulado (`run_bench.ps1 -Modest`)

- Cuatro núcleos a un hilo cada uno, el otro hilo de cada núcleo ocupado por un bucle, y `-Extra '--pixels=9'` para simular la gráfica [C] `TOOLS:benchmarks/run_bench.ps1:4-9, 23-35`.
- Tabla [C] `DOC:PERFORMANCE.md:473-485` (caminando): Medio Forward+ ×9: GPU 36,9 ms, fotograma 38,1 ms (26 FPS). Bajo entregado (FSR 2.2) ×9: 17,9 ms (53 FPS). Bajo FSR 1 ×9: 10,9 ms (83 FPS). Muy bajo Forward+ ×9: 2,99 ms (240 FPS). Muy bajo Compatibilidad ×9: 3,77 ms (213 FPS). Muy bajo Forward+ ×16: 5,20 ms (156 FPS). Muy bajo Forward+ ×36: 11,2 ms (79 FPS).

### 6.3 Antes y después (auditoría)

- Tabla [C] `DOC:PERFORMANCE.md:38-46`: Baja caminando: fotograma 3,95 → 2,87 ms; llamadas visibles 446 → 89; llamadas de sombra 1.343 → 431. Media caminando: 5,71 → 4,20 ms; sombra 1.791 → 451. Alta caminando: 6,80 → 5,53 ms.
- Llegadas en frío al entrar en salas nuevas: máximo 36,7 → 26,3 ms con calentamiento de pipelines [C] `DOC:PERFORMANCE.md:334-344`.
- Partes de la auditoría: visibilidad por planta, puertas y armarios dormidos, `_physics_process` de 369 puertas [C] `DOC:PERFORMANCE.md:405-418`. Un tick de física pasó de 1,19 a 0,70 ms [C] `DOC:PERFORMANCE.md:417`.

### 6.4 Cómo se lanza

- `./tools/benchmarks/run_bench.ps1 -Label <nombre> [-Extra '--seed=N'] [-Compatibility] [-Modest]` [C] `TOOLS:benchmarks/run_bench.ps1:2-6`. Espera hasta 30 minutos [C] (`WaitForExit(1800000)`). Restaura `default_bus_layout.tres` y `the_four_theme.mp3.import` tras cada ejecución [C] `TOOLS:benchmarks/run_bench.ps1:39`.
- Resultado en `evidence/bench/<nombre>_<renderizador>/report.json` [C] (`TOOLS:benchmarks/bench_table.ps1:7`), que `bench_table.ps1` imprime en tabla [C].
- Líneas que imprime el benchmark: `BENCHMARK ...` y `BENCHMARK_MEMORY` [C] `TOOLS:benchmarks/hotel_benchmark.gd` (grep).

---

## 7. Herramientas de `TOOLS:dev/` y de `godot.ps1`

### 7.1 Veces que se citan en `DOC/` y `.claude/` (no es uso diario medido)

Conteo de menciones de cada ruta en `docs/`, `.claude/` y `CLAUDE.md` [C, grep]. Es una pista de qué se consulta, no una medida de uso.

| Herramienta | Menciones | Qué hace |
|---|---|---|
| `TOOLS:dev/office_metrics.gd` | 53 | Lo que promete el generador de oficinas, medido en sus manifiestos. |
| `TOOLS:dev/light_layers_scan.gd` | 31 | Capas de luz por lámpara (verify). |
| `TOOLS:dev/map_metrics.gd` | 28 | Los pisos en cifras frente a lo que el generador promete. |
| `TOOLS:dev/check_scripts.gd` | 23 | Carga todos los scripts de `game/` y `tests/` para ver errores de sintaxis y de tipos. |
| `TOOLS:dev/asset_hashes.py` | 21 | Hashes de assets grandes, en bloques. |
| `TOOLS:dev/body_clip_probe.gd` | 18 | Cuerpo de quien es cogido contra las paredes (verify). |
| `TOOLS:dev/lurker_route_probe.gd` | 17 | Rutas de La Acechadora (verify). |
| `TOOLS:dev/light_leak.gd` | 14 | Luz que entra en una sala a la que no pertenece. |
| `TOOLS:dev/creature_stuck_probe.gd` | 14 | Dónde se atasca la criatura (verify). |
| `TOOLS:dev/map_plan.gd` | 13 | Planta dibujada en texto por semilla. |
| `TOOLS:dev/echo_rehearsal.gd` | 13 | Ensayo de la vista acústica del Locust. |
| `TOOLS:dev/check_shaders.gd` | 13 | Dibuja todos los shaders (verify, con ventana). |
| `TOOLS:dev/office_equipment_dump.gd` | 12 | Equipamiento de las oficinas (área 5). |
| `TOOLS:benchmarks/run_bench.ps1` | 37 | Banco de rendimiento. |
| `TOOLS:benchmarks/hotel_benchmark.gd` | 35 | Banco de rendimiento. |

- Fuera de esta parte pero muy citados: `TOOLS:capture/office_rooms_capture.gd` (62), `TOOLS:capture/office_capture.gd` (26), `TOOLS:capture/echo_capture.gd` (20), `TOOLS:capture/torch_capture.gd` (17), `TOOLS:capture/office_pieces_sheet.gd` (17) [C, grep].

### 7.2 Modos de `godot.ps1` (25)

`play`, `gallery`, `lurker`, `lurker-arena`, `build-gallery`, `playtest`, `locust`, `rehearsal`, `bench`, `bench-films`, `survival-test`, `editor`, `test`, `hotel-batch`, `hotel-walkthrough`, `hotel-audio`, `hotel-benchmark`, `compatibility`, `observer`, `bots`, `hunt`, `bots-run`, `bots-replay`, `export`, `export-mac` [C] `TOOLS:godot.ps1:2`.

- Por menciones en docs: `locust` (23), `rehearsal` (19), `export` (16), `playtest` (15), `hotel-batch` (10), `test` (8), `observer` (6), `compatibility` (5), `build-gallery` (5), `lurker-arena` (4), `hotel-walkthrough` (4) [C, grep].
- `godot.ps1` usa `--rendering-method forward_plus` para todos los modos de prueba y no para los de juego [C] `TOOLS:godot.ps1:29`.
- `bench-films` graba tres AVI (frente, espalda, armario) en `evidence/` con `--write-movie` y 1280x720, con límite de 600 s por película [C] `TOOLS:godot.ps1:110-133`.
- `export`: borra `.godot/exported` antes de exportar; exporta el preset `Windows Desktop` a `exports/windows/TheFour.exe` sin modo headless, porque el horneado de shaders necesita GPU; luego zip `exports/TheFour.zip` con cuatro archivos y el lanzador [C] `TOOLS:godot.ps1:83-94, 134-162`.
- `export-mac`: preset `macOS`, zip en `exports/macos/TheFour.zip` [C] `TOOLS:godot.ps1:98-103`.

---

## 8. Clases y nodos de Godot en esta parte

Conteo de apariciones por clase en `T:` (todas las pruebas) [C, grep sobre `tests/`]:

| Clase o API | Apariciones en `T:` | Nota |
|---|---|---|
| `Vector3` | 1217 | Casi todo es geometría de posición. |
| `Array` / `Dictionary` | 671 / 496 | Estructuras de datos de manifiestos y estados. |
| `Vector2` | 202 | |
| `FileAccess` | 132 | Lee manifiestos y escribe `evidence/*.json`. |
| `JSON` | 73 | Serializa resultados (`creature_contract_test.gd:193`) [C]. |
| `Input.` / `InputEvent*` | 73 / 19 | Simula teclado, ratón y mando. |
| `SceneTree` | 50 | Base de cada prueba (`extends SceneTree`). |
| `Node3D` | 48 | |
| `Transform3D` / `Basis` / `Quaternion` | 45 / 41 / 4 | |
| `Time` | 36 | `Time.get_ticks_msec()` 31 veces: tiempo de reloj real. |
| `Node` | 35 | |
| `Color` | 34 | |
| `AudioServer` / `AudioEffectCapture` | 32 / 8 | Las pruebas de audio leen buses y captura. |
| `Callable` | 23 | |
| `PackedVector3Array` | 22 | Rutas de navegación y estados. |
| `RandomNumberGenerator` | 21 | Ver apartado 10. |
| `DirAccess` | 20 | |
| `ShaderMaterial` / `StandardMaterial3D` | 18 / 4 | |
| `Viewport` | 17 | |
| `MeshInstance3D` / `ArrayMesh` / `MultiMeshInstance3D` | 17 / 16 / 12 | Las pruebas de geometría miran mallas. |
| `PhysicsRayQueryParameters3D` / `PhysicsDirectSpaceState3D` | 11 / 10 | Rayos de visión y de sonido. |
| `OmniLight3D` / `SpotLight3D` | 10 / 6 | |
| `StaticBody3D` / `CharacterBody3D` / `Area3D` | 10 / 5 / 2 | |
| `Camera3D` | 5 | |
| `Label3D` | 7 | Letreros. |
| `NavigationServer3D` | 6 | Malla de navegación del piso. |
| `Engine` | 10 | `Engine.max_fps` (7) en pruebas. |
| `RenderingServer` | 7 | |
| `Image` / `ImageTexture` | 4 / 2 | |
| `OS` | 3 | `OS.get_cmdline_user_args()`. |
| `ProjectSettings` | 3 | |
| `WorldEnvironment` / `Skeleton3D` / `GPUParticles3D` / `SurfaceTool` | 2 / 1 / 1 / 1 | |
| `DisplayServer` / `ResourceLoader` / `ConfigFile` | 2 / 1 / 1 | |

Herramientas (`TOOLS:bots/`, `TOOLS:dev/`, `TOOLS:benchmarks/`) [C, grep]:

| Clase o API | Apariciones | Nota |
|---|---|---|
| `await process_frame` / `await physics_frame` | 71 / 42 | |
| `OS.get_cmdline_user_args()` | 58 | Así leen sus opciones todas las herramientas. |
| `_physics_process` | 46 | |
| `save_png` | 28 | Capturas a disco. |
| `RenderingServer.frame_post_draw` | 26 | Captura de la imagen tras dibujar. |
| `Time.get_ticks_msec` / `Time.get_ticks_usec` | 23 / 16 | Medidas de tiempo. |
| `DisplayServer` | 22 | Detectar modo sin pantalla. |
| `Image.create` / `Image.load_from_file` | 15 / 3 | |
| `randf` / `randi` | 15 / 10 | |
| `Performance.get_monitor` | 9 | Monitores de rendimiento. |
| `RandomNumberGenerator` | 8 | |
| `RenderingServer.get_rendering_info` / `get_current_rendering_method` / `get_rendering_device` | 6 / 4 / 2 | |
| `RenderingServer.viewport_*_measure_render_time` | 2 + 2 | Tiempos de GPU y CPU del render. |
| `Engine.max_fps` / `Engine.time_scale` / `Engine.physics_ticks_per_second` | 6 / 3 / 3 | |
| `--fixed-fps` (en cadenas de argumentos) | 10 | |
| `--write-movie` | 2 | Grabación de AVI. |

---

## 9. Constantes y cifras con ruta:línea

Las cifras que definen el comportamiento de lo que se prueba y las que fijan una prueba. Las que son de los juegos (`LOCUST.*`, `SCORE.*`) están en código de `game/` no leído, y aparecen aquí solo por cómo las usa la prueba.

**Semillas y datos fijos de las pruebas**

| Cifra | Ruta:línea | Qué fija |
|---|---|---|
| Semilla 81 de piso | `T:tests/hotel/creature_contract_test.gd:145`; `T:tests/hotel/hotel_audio_test.gd:6`; `TOOLS:godot.ps1:3`; `TOOLS:bots.ps1:21`; `TOOLS:bots/bot_run.gd:29` | Piso por defecto de casi todo. |
| Semilla 8101 | `T:tests/hotel/creature_contract_test.gd:439` | Puntos y direcciones de `shared_sight` (100 cada una). |
| Semilla 7 | `T:tests/office/office_light_test.gd` cabecera; `office_dressing_test.gd:2`; `office_test.gd` (validador, `seed_seven()`) | Piso 2 de referencia. |
| Semillas 81 y 213 | `TOOLS:verify.ps1:66, 99` | Sondas de atasco y de oído. |
| Semillas de La Acechadora 8 | `TOOLS:verify.ps1:71, 75` | Rutas del piso 2. |
| 200 aproximaciones | `T:tests/office/lurker_fairness_test.gd:5` | Parte B de la justicia. |
| 100 puntos (sombra) y 100 direcciones (`beside_view`) | `T:tests/hotel/creature_contract_test.gd:446, 461` | Equivalencia de la mirada. |
| 50 semillas por número de supervivientes | `T:tests/hotel/manifest_golden_test.gd:3-4` | Manifiesto dorado. |
| 64 pisos hechos dos veces | `T:tests/office/office_test.gd:5-6` | Generador de oficinas. |
| Límite 240 s por nivel | `T:tests/office/office_bots_test.gd:9` (`STAGE_MOST := 240.0`) | Duración de cada nivel de los bots. |
| 6 rondas por caso de captura | `T:tests/hotel/creature_contract_test.gd:1408` | Sorteos de la captura. |
| 40 y paso 3 (salas a probar) | `T:tests/hotel/creature_contract_test.gd:403` | Puntos de la prueba de rutas. |
| 40 semillas de capas | `TOOLS:verify.ps1:104, 107` | `light_layers_scan`. |
| 64 entradas de buffer | `T:tests/hotel/creature_contract_test.gd:1528-1529` | `heard` de la criatura nula. |

**Umbrales de las pruebas**

| Umbral | Ruta:línea | Qué fija |
|---|---|---|
| Parada de más de 2 s; cualquier salto de su protocolo de último recurso | `TOOLS:verify.ps1:63-64` | Atasco de la criatura. |
| 4 cm dentro de la pared | `TOOLS:verify.ps1:80-82` | Cuerpo de quien es cogido. |
| 56 capturas | `TOOLS:verify.ps1:80-82` | Cuerpo de quien es cogido. |
| 6 m de luz (sin linterna, a distancia) | `T:tests/hotel/creature_contract_test.gd:525` | Visión de la criatura. |
| 0,72 de coseno (mirada) | `T:…:526` | Cono de mirada de la cordura. |
| Pasos 0,55 / 0,7 / 1,7 | `T:…:1494` | Pasos de armario por defecto. |
| 1,3 veces la distancia de inicio | `T:…:420` | Caminar bajo el aura. |
| Ventana de 6 s | `T:tests/office/lurker_mood_audio_test.gd:2-4` | Vuelta del tema tras huir. |
| Umbral de tirón 20 ms y 33 ms | `DOC:PERFORMANCE.md:18` | Tirones en las medidas. |
| 1.800 s y 5.400 s de simulado | `TOOLS:bots/bot_run.gd:34-35` | Límite de un piso y de la partida de bots. |
| 120 s sin latido | `TOOLS:bots.ps1:34` | Piso colgado. |
| 45 min de reloj | `TOOLS:bots.ps1:33` | Piso con tiempo real agotado. |
| 8 s antes de la incidencia | `TOOLS:bots.ps1:158, 171` | Segundo de la repetición. |
| 10 s de latido | `TOOLS:bots.ps1:100-101` | Latido de cada piso. |

**Cifras de la criatura que las pruebas comparan** (los valores están en `game/`, no leído aquí)

- `LOCUST.EXECUTION_TIME` (`T:…:237`), `LOCUST.EYE_HEIGHT` (`T:…:255`), `LOCUST.SUSPICION` (`T:…:379`), `LOCUST.SIGHT_RANGE` (`T:…:482`), `LOCUST.ONSLAUGHT_REACH` (`T:…:1064`).
- `SANITY_SEEN` (`T:…:524`), `STARE_CONE` (`T:…:536`).
- `SCORE.HOLD_FAR`, `SCORE.HOLD_NEAR`, `SCORE.LIE_ROOM`, `SCORE.LIFT_HEIGHT`, `SCORE.HOLD_STAND`, `SCORE.seat_back()`, `SCORE.seat_lean()` (`T:…:1138-1264`).
- `PHANTOM.PLACE_OFF` (`T:…:466`).
- Cifras propias del `executions` de la captura: `GLANCE_ALONE` y `GLANCE_TEAM` (`T:…:1149`).
- La mano de la captura: el pecho va de 1,2 a 0,68 m; la cara, de 1,58 a 0,88 m, al agacharse (`T:…:1262`); ojos de 0,9 m agachado y 1,64 m de pie (`T:…:1215`).
- Linterna de reposo: rango de 0,5 a 0,9 y de 0,6 a 1,0, distancia de 2,1 a 2,9 m, inclinación de 4 grados y ±0,22 rad (`T:…:1272-1283`).
- Cuerpo que cae: `0,62` y `0,78` en la dirección de caída (`T:…:1197`).
- Escala del modelo de mentira: 1,95 (`T:…:547`).

---

## 10. Orden de ejecución, física, azar y reloj

### 10.1 Reloj

- **Lote 1 de `verify.ps1` y `bots.ps1` (`--fixed-fps 60`):** el reloj de física va a 60 ticks por segundo sin relación con el tiempo real; el juego va tan deprisa como da la máquina [C] `TOOLS:verify.ps1:13-16, 40`; `DOC:PERFORMANCE.md:310` (medido sin ventana, a `--fixed-fps 60`).
- **Audio y red:** reloj real [C] `TOOLS:verify.ps1:19, 117-122`. Se usa `Time.get_ticks_msec()` en 31 sitios de `T:` [C grep].
- **Benchmark:** 1,5 s de espera antes de medir por la recolocación de luces [C] `DOC:PERFORMANCE.md:14`.
- **`Engine.max_fps`:** 7 usos en `T:` y `bot_run.gd` lo pone a 0 [C].

### 10.2 Orden: esperas y señales

- `await physics_frame` (159 en `T:`), `await process_frame` (107), `await frames` (228), `await wait_for` (133), `await pause_for` (59), `await create_timer` (9) [C grep]. La mayoría de las pruebas son secuencias de esperas, no callbacks.
- `_physics_process` aparece 95 veces en `T:` (probablemente en las escenas que prueban) [C grep].
- `connect(` aparece 14 veces en `T:` [C grep].
- `call_deferred` aparece 50 veces en `T:`: la mayoría de las pruebas empiezan con `_initialize` → `run.call_deferred()` (por ejemplo `T:tests/hotel/creature_contract_test.gd:96`) [C].
- `add_child` 80 veces y `queue_free` 66 en `T:` [C grep]: las pruebas montan y desmontan escenas.

### 10.3 Azar

- `RandomNumberGenerator` aparece 21 veces en `T:`, 13 de ellas en `creature_contract_test.gd` [C grep]. Semillas fijas, por ejemplo `rng.seed = 8101` (`T:…:439`), `draw.seed = hash([manifest.seed, "den"])` (`T:…:1039`), `draw.seed = int(execution.seed) ^ 0x51ed` (`T:…:1268`).
- `seeded.seed = hash([case.name, round])` (`T:…:1410`) para repetir cada captura con el mismo sorteo.
- `randf` y `randi` en `T:`: 61 y 13 (conteo grueso) [C grep]. Los que no son de un generador con semilla, como `rng.randi_range` o `randf` del `executions`, dependen de la semilla de la ejecución.
- La criatura guarda su estado de sorteos (`it.rng.state = draws`) y las pruebas lo devuelven al final (`T:…:901, 1093, 1129, 1479`) [C].

### 10.4 Física

- Las pruebas de rayos usan `intersect_ray` (`PhysicsDirectSpaceState3D` aparece 10 veces) con máscaras de capa `1 | 8 | 64` y `1 | 8` (`T:…:484, 527, 1190`) [C]. El resultado depende del orden de los cuerpos en la escena.
- `lurker_motion_test` y `lurker_shell_test` corren sin cuerpos ni física (`T:tests/office/lurker_motion_test.gd` cabecera, `lurker_shell_test.gd:1-8`) [C].

---

## 11. Estado de la última verificación

- Fecha de `evidence/verification.json`: 14 de noviembre de 2026, 19:34 [E] (fecha de modificación del archivo).
- **62 de 63 aprobadas; 1 fallida:** `hotel/palette_scan_test` [E].
- Su log: `evidence/verify_palette_scan_test.log:30` → `FAIL Ningún número de tipo de sala fuera de las paletas (318 scripts)  (4 sitios)`. Los cuatro sitios [C, mismo log]:
  - `res://tools/dev/office_plan.gd:100` (dos líneas: comparación con un número y tabla propia leída por tipo).
  - `res://tools/dev/office_plan.gd:137` (las mismas dos clases de sitio).
- Por tanto, `tools/dev/office_plan.gd` tiene números de tipo de sala fuera de las paletas, lo que la prueba no admite (`docs/OFICINAS.md` 11.2, según la cabecera de `T:tests/hotel/palette_scan_test.gd`) [C].
- Tiempo total aproximado de la última ejecución [E]: suma de segundos de las 63 entradas ≈ 2.724 s (con paralelismo, el reloj de pared es menor).
  - Lote 1 (sin red ni audio): ≈ 2.332 s de suma.
  - Red: ≈ 324 s de suma.
  - Audio: ≈ 69 s de suma.
- La más larga: `office/office_test_generator` con 449,2 s [E].

---

## 12. Sin comprobar

Lo que no llegué a leer o comprobar. Cada punto dice qué falta y por qué sigue fuera de la ficha.

1. **Cuerpos de once pruebas largas** (`office_test.gd`, `lurker_shell_test.gd`, `stages_test.gd`, `net_test.gd`, `capture_test.gd`, `office_light_test.gd`, `hotel_test.gd`, `lurker_fairness_test.gd`, `survival_test.gd`, `lurker_senses_test.gd`, `echo_test.gd`). Solo leí sus funciones y los títulos de sus `check()`. Lo que afirman con números concretos (umbrales, semillas, conteos dentro de bucles) puede faltar en las tablas de los apartados 3, 4 y 9.
2. **`creature_contract_test.gd` de la línea 1560 a la 2079** (apartado de consumidores de red, bots, observador y criatura nula). Solo leí los títulos de sus `check()`.
3. **Cuerpos de `tools/bots/` (4.942 líneas):** no leí `bot_brain.gd`, `bot_replay.gd`, `bot_team.gd`, `bot_threat.gd`, `bot_threat_lurker.gd`, `bot_match.gd`, `bot_senses.gd`, `bot_nav.gd`, `bot_body.gd`, `bot_recorder.gd`. Sé lo que dicen sus cabeceras y `bot_run.gd`, `bot_watchdog.gd` (solo la lista de funciones) y `bot_watch.gd` (solo la lista de funciones).
4. **Cuerpos de `tools/dev/`:** no leí ninguna de las sondas largas (`capture_bench.gd`, `lurker_telemetry.gd`, `map_metrics.gd`, `lurker_route_probe.gd`, `body_clip_probe.gd`, `zfight_scan.gd`, `leak_who.gd`, `echo_rehearsal.gd`, `hitch_probe.gd`, `office_metrics.gd`, `office_plan.gd`). Solo sus primeras líneas de cabecera.
5. **`hotel_benchmark.gd` (467 líneas):** solo sé su cabecera y que imprime `BENCHMARK`. No leí sus vistas, calidades ni los campos de `report.json`.
6. **`DOC:PERFORMANCE.md`:** leí los apartados de método, la tabla de presets (líneas 473-486), la tabla de equipo modesto y algunas partes de la auditoría. No leí las líneas 292-301 de la tabla de otro recorrido (encabezado sin leer), ni los apartados 2 a 5.
7. **`TOOLS:history.ps1`** (6.219 bytes): no leído.
8. **`godot.ps1 execution`:** aparece nueve veces en `docs/` y `.claude/`, pero `godot.ps1` no tiene ese modo [C: ValidateSet, `TOOLS:godot.ps1:2`]. No comprobé si es una cita de otra cosa (por ejemplo `docs/EXECUTION.md`) o un modo que falta.
9. **Duración exacta bajo carga:** los tiempos de la sección 3 son de una ejecución con lotes llenos; no sirven como medida de cada prueba sola.
10. **Cuántos casos corren de verdad:** el número de `check()` es el del código, no el de ejecución (un bucle puede multiplicarlo). No medí ejecuciones reales de cada `check()`.
11. **Coste de desarrollo del port:** no hay nada aquí sobre cuánto tardaría reescribir cada prueba. Solo hechos del repositorio.
12. **Unreal:** nada de esta ficha se ha comprobado contra Unreal. Es Godot, tal como está.
