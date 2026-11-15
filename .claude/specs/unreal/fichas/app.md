# Ficha de hechos: app (game/app, game/director, game/discovery)

Fecha de lectura: 14 de noviembre de 2026. Solo lectura: no se ha escrito código, no se ha ejecutado Godot ni Unreal, no se ha compilado nada y no se ha tocado git. Cada hecho lleva ruta:línea del repo. Lo no leído está en el apartado 18.

## 1. Cómo se leyó

- `game/app/`: los 27 `.gd` leídos completos (21 en la raíz, 3 en `capture_styles/`, 3 en `hallucinations/`) más `game/app/hotel.tscn`. Lectura por tramos de 250 a 600 líneas, sin resumir de memoria.
- `game/director/pacing_director.gd` (893 líneas): completo.
- `game/discovery/discovery_catalog.gd` (52 líneas): completo.
- Total leído: 12.192 líneas de `.gd` y 25 del `.tscn`.
- Búsquedas de apoyo (solo para contar y localizar, no para describir): apariciones de clases de Godot, `$` rutas, `.connect(`, grupos, acciones de entrada, RPC, llamadas a `match_net`, `net`, `ui`, `session`, `world_audio` y al contrato de la criatura, todo dentro de estas tres carpetas. Tests: búsqueda de rutas `game/app/` y `game/director/` en `tests/`, y lectura de las cabeceras de comentario de los tests que las usan.
- `project.godot`: sin sección `[autoload]` (búsqueda de la cadena `autoload` en el fichero: 0 aciertos).

## 2. Inventario de archivos leídos

| Archivo | Líneas | Qué hace |
|---|---:|---|
| game/app/hotel.tscn | 25 | Escena raíz `TheFourHotel` (Node3D, `process_mode = 3`) con `Services/Settings`, `Services/GameSession`, `Player`, `Interface`, `Presentation` y `WorldAudio`. |
| game/app/hotel_main.gd | 2123 | El "level": arranque, máquina de estados de la partida, generación y construcción del piso, bucles de física y de cuadro, y delegados de los servicios hijos. |
| game/app/executions.gd | 759 | La captura: decisión del anfitrión, escena en un reloj común, cuerpo, linterna y cámara en el suelo. |
| game/app/death_tape.gd | 584 | La cinta de la cámara de quien muere (solo en su máquina): encuadre de la máscara, caída, sonido del micrófono y fin. |
| game/app/blood.gd | 544 | La sangre de una captura: gotas, manchas en paredes y suelos, charco y sonidos. Se calcula una vez al empezar la captura. |
| game/app/camera_fall.gd | 495 | Dónde y cómo cae la cámara de quien muere: rayos, candidatos de encuadre, ruta de la caída en el aire y en el suelo. |
| game/app/capture_score.gd | 173 | Tiempos y curvas de la captura de The Locust, en segundos desde el agarre. Es la partitura que leen todos. |
| game/app/capture_styles/locust_capture.gd | 246 | Estilo de captura de The Locust: posición, entrada, caída, cuerpo, linterna y máscara. |
| game/app/capture_styles/lurker_capture.gd | 284 | Estilo de The Lurker: la cuelga del techo, una baldosa que oscila, su propia sangre. |
| game/app/capture_styles/lurker_score.gd | 135 | Partitura de The Lurker con los mismos nombres que `capture_score.gd`. |
| game/app/code_lock.gd | 529 | Cajones, las cuatro cifras del código, pistas en papel, paneles eléctricos, la llave, la foto Polaroid y el teclado de la última puerta. |
| game/app/floor_map.gd | 207 | El plano que se dibuja en la hoja compartida, a partir de rayos que lo ven. Se olvida a los 180 s. |
| game/app/floor_save.gd | 141 | Continuar: qué se guarda de un piso en curso y cómo se devuelve sobre el mismo seed. |
| game/app/hallucinations/locust_hallucinations.gd | 94 | Mentiras de The Locust: su llamada desde fuera de la vista y su modelo para asomarse. |
| game/app/hallucinations/lurker_hallucinations.gd | 631 | Mentiras de The Lurker: ruidos según dónde está el oyente, caras en puertas, particiones, rincones. |
| game/app/hallucinations/lurker_poser.gd | 37 | Pone el modelo de The Lurker en la pose de asomarse o de quietud. |
| game/app/interaction.gd | 431 | Lo que el jugador hace con E y Tab en cada cuadro: puertas, armarios, cajones, documentos, teclado, ascensor, paneles. |
| game/app/lifts.gd | 558 | Ascensores entre alas: botón, viaje, puertas, tarjetas de sector y bajada por escalerilla. |
| game/app/observer_gizmos.gd | 226 | Marcas del observador sobre el piso: rastros, ruidos, puertas, sets, cono de visión, ductos. |
| game/app/observer_view.gd | 654 | Herramienta del observador: cámara libre, plano, registro, lectura acústica y teclas. |
| game/app/phantom_passage.gd | 145 | Paso de la criatura por una sala lejana que no está: un punto que camina y sus pasos. |
| game/app/phantom_sight.gd | 321 | Aparición de la criatura donde no está: asomada al marco de una puerta o de pie al fondo de un pasillo. |
| game/app/presentation_rig.gd | 494 | Entorno, lente, cámara HDR, campo entrelazado, ajustes gráficos, cues de pantalla, sonidos del propio piso y música. |
| game/app/revival.gd | 319 | Renacer: reparto de cuerpos, criatura enviada a su hueco, lugar de vuelta, mirar a un compañero. |
| game/app/run_ledger.gd | 377 | Libro de la partida: lo que hizo cada superviviente y los momentos del piso; cierra la línea que se archiva. |
| game/app/sanity.gd | 318 | Cordura de cada superviviente, susto al ver a la criatura, y las mentiras del piso cuando la cordura baja. |
| game/app/session_perf.gd | 212 | Traza de rendimiento opcional a JSONL, con un hilo escritor. |
| game/app/televisions.gd | 210 | Televisores de cada sector: encendido, cuenta, y el salto de la criatura entre pantallas encendidas. |
| game/director/pacing_director.gd | 893 | Director de ritmo: fases de construcción, pico y respiro; pistas a salas; cruces; sonidos de puertas. |
| game/discovery/discovery_catalog.gd | 52 | Catálogo de documentos del piso: 4 entradas definidas de 16 previstas. |

## 3. Flujo de una partida de principio a fin

### 3.1 Arranque (sin partida)

- `hotel.tscn:12-25`: raíz con `process_mode = 3` (`PROCESS_MODE_ALWAYS`, la misma constante que `hotel_main.gd:290`). Hijos: `Services/Settings` (settings_service.gd), `Services/GameSession` (game_session.gd), `Player` (player.tscn), `Interface` (interface.tscn), `Presentation` (presentation.tscn), `WorldAudio` (world_audio.tscn).
- `_enter_tree` (`hotel_main.gd:187-287`): lee los argumentos (194-222). Si es un proceso de prueba (`--test-profile` o un `.gd` como argumento), usa ficheros propios `user://test_hotel_<nombre>_settings.json`, `..._checkpoint.json`, `..._discoveries.json`, `..._records.json` y `user://test_coop_<nombre>_checkpoint.json` (212-241). Fija `set_floor(floor_asked())` (224). Crea como hijos de `$Services`, en este orden: Discoveries (225-228), Records (229-232), Net (237-243), Sanity (244-247), Lifts (248-251), FloorMap (252-255), Televisions (256-259), CodeLock (260-263), Executions (264-267), DeathTape (268-271), Revival (272-275), Interaction (276-279), PresentationRig (280-283), Ledger (284-287).
- `_ready` (289-369): traza de rendimiento si `--perf-log` (291-295); `automation` si es headless o `--automation` (296); audio del mundo activo salvo automation o `--silent` (297-298); conexión de señales (299-323, ver apartado 4.2); `build_environment` (325), `build_audio` (326), `apply_settings` (327-328); sala de título en `TITLE_ORIGIN` (330-333); jugador en (1, 0.06, 3.8) (334); `ui.menu("main", hay_partida_guardada, mensaje)` (336); `on_state()` (337).
- Después, si no hay automation, observador, repaso ni bots: `ui.play_intro()` (347). Luego, en este orden: repaso de bots (348-350), bots (351-353), `--steam-host` (357), `--observer` (362-363), `--playtest-seed` con `--locust` o no (358-369).

### 3.2 Título

- La sala de título es `title_scene.gd` (no leído), colocada en `TITLE_ORIGIN` = (-600, 0, 0) (`hotel_main.gd:43`, 330-333).
- `update_title_scene` (1402-1421): en MENU activa la sala y pone la luz ambiente en `TITLE_AMBIENT` = 0.03 (`hotel_main.gd:45`, 1410), oculta el hotel (1411) y al jugador (1412). Fuera del menú devuelve la luz del hotel (1416) y lo muestra si no se está construyendo (1418).
- Música del menú: `menu_music` (`presentation_rig.gd:473-480`), `the_four_theme.mp3`, -12 dB (477), sonando con audio y en MENU (`update_menu_scene`, rig 490-494).

### 3.3 Sala de espera (multijugador)

- Pantallas según eventos de la red (`hotel_main.gd:307-323`): `lobby_changed` lleva a "lobby" si hay asiento distinto de 0, "steam_wait" o "join" (308); con reglas abiertas por un anfitrión que cambia, vuelve a "rules" (311); `joined` lleva a "lobby" (312); una invitación de Steam lleva a "steam_wait" (320-323).
- Acciones: `host_open` (579-581), `host_steam` (582-584), `join` (585), `connect` (587-589), `lobby_start` → `net.start_match()` (593-594), `lobby_leave` (595-597), `rules_reset` (606-608), `online_room` → `return_to_lobby` (614).
- Arranque de la partida en sala: `start_online_floor` (`hotel_main.gd:1012-1045`) construye el piso del anfitrión, pone al jugador en `match_net.spawn_point(seat)` (1039), y llama a `match_net.floor_built()` (1045). `begin_online_play` (1048-1076) activa la sesión en línea, dificultad (1056), reglas (1057), crea o no el director (1058), y pone el control de la criatura: en VERSUS, "player" o "puppet" (1059-1060); en COOP, "ai" si es anfitrión o "puppet" (1061-1062).

### 3.4 Nueva partida

- `"new"` abre el menú "difficulty" (`hotel_main.gd:554`). `"begin"` llama a `start_intro(randi_range(0, 2147483647))` (555).
- `start_intro` (634-658): la escena de apertura `INTRO` se pone en `INTRO_ORIGIN` = (600, 0, 0) (42, 638-641); el hotel se oculta (644); se paran ambiente, tema y ventilación (647); el ambiente de la sala a 0 (655); estado CUTSCENE (656); se muestra "saltar" (657).
- Se salta con `interact` mantenido `SKIP_HOLD` = 0.8 s (`hotel_main.gd:47`, 1621-1627), o con `step_back` en cutscene (1325).
- `finish_intro` (660-669): libera la escena, muestra el hotel y la cámara del jugador, y llama a `start_floor(intro_seed, false, [1], "", floor_asked())` (669). `intro_seed` es la semilla de la traza si hay `--perf-seed` (636), o la elegida.

### 3.5 Continuar

- `"continue"` (556-559): `session.checkpoint()`; si hay datos, `continue_floor` (739-748): `set_floor(data.floor)` (742); `session.read_state(seed)` ANTES de empezar el piso (744), porque lo guardado se lee contra el generador; `start_floor(seed, fallback, [1], dificultad)` (745); si la lectura no está vacía y el estado es PLAYING con la misma semilla, `SAVE.give(self, state)` (747) y `keep_floor()` (748).
- `floor_save.gd`, `take` (24-75) guarda: sector, tiempo, reinicios, metas, posición, orientación, cordura, aguante, agachado, linterna, zoom y escondite del jugador; puertas; sets encendidos; cajones registrados con quién los registró; paneles abiertos; pistas leídas; si el código está dado; ascensores (lift_away, creature_hold, lobby_time, arrived); estado de la criatura (`creature.save_state()`); oscuridad del hotel; la hoja; los objetivos; el plano (`floor_map.pack`); el libro (`ledger.pack`); el reloj de la cinta.
- `floor_save.gd:16-18` dice qué NO se guarda: la mente del director, los temporizadores de alucinaciones, un viaje en ascensor a medias (el jugador se coloca donde iba) y la persecución (la criatura vuelve a buscar). Tras volver, `GRACE` = 8 s (`floor_save.gd:22`, 127).
- Cuándo se guarda: `keep_floor()` cada `KEEP_EVERY` = 30 s de juego (`hotel_main.gd:803`, 1785-1786); al pausar (1223-1228); al cerrar la ventana (1917). No se guarda en línea, de observador, de bots ni de repaso (`can_keep`, 806-811).

### 3.6 Generación y construcción del piso

- `start_floor` (720-734) y `build_floor` (832-943). Orden exacto:
  1. Estado LOADING (`hotel_main.gd:834`).
  2. Dos fotogramas de proceso (836-837).
  3. Reinicio: `world_audio.reset`, `player.reset_survival`, zoom a 1 (842-843), `ledger.reset` (844), `executions.reset` (846), `tape.reset` (847), `set_rules({})` (853).
  4. Se libera la criatura y el hotel anteriores (857-862); `match_net.floor_building()` (863).
  5. `manifest = kind.GENERATOR.new().generate(seed, drawn_for o survivors)` (865). Con `force_fallback`: `candidate(404, 0, true)` y `fallback = true` (866-869).
  6. `build_objectives` (871), `tv_sets = settle_objectives(survivors).televisions` (872).
  7. `await mount_geometry` (873; 945-956): `kind.GEOMETRY.new()`, `build(manifest)` (954), `configure_hotel()` (955).
  8. Jugador en (0, 0.04, 0) (874-875), orientado a `manifest.start_facing` o a PI (888); `visibility_clock = 1` (889).
  9. Dos fotogramas de física (892-893), `validate_floor_physics` (894; `kind.VALIDATOR.new().validate_physics`). Si hay errores, mapa de respaldo `candidate(404)` y segunda validación (895-911); si también falla, `save_error` y vuelta al menú (908-911).
  10. Hasta 90 fotogramas de física esperando que el mapa de navegación lleve de (0,0,0) a la salida (921-926). Si no, menú con "No se pudo validar la ruta de salida" (927-931).
  11. `bounce_ready` (933; 965-968): espera a que la luz de rebote se hornee en hilos.
  12. `WARMUP.run(self)` (938-940): precalienta los pipelines de sombreado, salvo headless o `--no-warmup` (938).
- Después, `start_floor`: `set_difficulty(chosen)` (724; 149-152: `session.difficulty` y `apply_tuning`), `camcorder.start_tape(seed)` (725), zoom 1 (727-728), `session.start(seed, fallback, slots)` (731), `populate_floor(true)` (734).
- `populate_floor` (971-1007): `spawn_creature` (973), limpia cajones (976), `place()` de cada objetivo en el orden del piso (979), `place_documents` (982), `code.place_key` (983), director (984-990; `tune(tuning())` y `setup(self, manifest.seed)`), sonidos de la puerta y el ambiente (993-1000), tarjeta del sector (1004-1005; no con automation, observador o criatura local), `lifts.pending_brief` y `brief_wait` = `OPENING_CARD` = 2.6 (1006-1007; `lifts.gd:465`).

### 3.7 Juego

- Física: `_physics_process` (`hotel_main.gd:1595`) llama a `step_physics` (1600-1659):
  - Repaso: retorna (1602). Observador: lifts, floor_map, bots y `host_gate` (1605-1620).
  - CUTSCENE: contador de saltar (1621-1628). PAUSED: retorna (1634).
  - Siempre: `lifts.ride_along`, `ride_out`, `update_cars` (1635-1637). Si no hay PLAYING, retorna (1638).
  - PLAYING: `lifts.count_away` (1639), `floor_map.tick` si `rule("plan") == 1` (1640), `lifts.announce_sector` (1643), `drive_local` (1645; `interaction`), `sanity.tick` (1649), y en el anfitrión `host_gate` (1657) y `ledger.tick` (1659).
- Cuadro: `_process` (1774) llama a `step_frame` (1779-1852): `update_menu_scene` (1780), `hotel.tell_time` (1782), PLAYING: `update_execution` (1784) y `keep_floor` cada 30 s (1785-1786), oclusión (1794-1795), cámara de efectos (1797-1799), `update_fields` (1800), cámara de cinta visible (1801), `camcorder.hunter` (1803), marcas (1805), zoom (1806-1807), `show_tape` (1809), `update_rewind` (1810), luz del piloto (1813), `update_screen_cues` (1815), volúmenes de ambiente y tema (1819-1825), subtítulos (1826-1827), ronda de visibilidad (1828-1852).
- Cambio de sector (`on_state`, 1162-1259, con `session.stage > last_stage` en 1187-1195): `lifts.follow_players` (1188), `executions.clear_leavings` (1190), `stage_tape = tape_seconds()` (1193), `ledger.note_sector` (1195).
- TRANSITION (1230-1241): si quedan sectores, sin menú y con el ratón capturado; si no, menú "transition".
- Cierre de un sector: el coche que sale con alguien dentro (`lifts.gd:278-279`) o la llegada a la escalera (552-558) llaman a `session.finish_stage()`.
- Pausa: `step_back` (1324-1343) y Escape (1892). Al perder el foco, `session.pause()` (1915) salvo automation, observador o partida en línea.

### 3.8 Muerte

- La criatura alcanza a un superviviente: `executions.capture_survivor` (179-197). Condiciones (181-186): participante en EXPLORING; no en ascensor; no protegido; `level.spare` (bots); `creature.may_capture(body)`.
- `stage_capture` (201-232) decide con el anfitrión: `style().approach(body)` (206), `choose_entry` (208; 246-247, con un solo sorteo de `rng`), mirada a la lente con probabilidad 1 de cada 3 si está solo o 1 de cada 6 en equipo (`GLANCE_ALONE` 81, `GLANCE_TEAM` 82), lado (215), caída `fall_room` (216), semilla `forced.seed` o `rng.randi() & 0x7fffffff` (222), cue de la advertencia (226) y `extra` del estilo (230).
- Envío y aplicación en todas las máquinas: `match_net.execute_start.rpc` (193); `apply_execution` (261-323): `creature.begin_capture(execution)` (285), `turn_for_capture` (287), linterna (288), `blood.begin` (289), armario abierto (292-296). En la máquina de la víctima: vibración `rumble(0.5, 0.9, 0.7)` (299), jugador parado (300-302), la hoja y el libro se cierran (306-313), `camcorder.focus` vacío (320-321), `tape.begin(execution, covered)` (322). Al final, `scream()` (323).
- `update_execution` (345-375), cada cuadro: grito (351), sonido del golpe a `ARM_TIME` (355-357), primera puñalada en `KILL_TIME` (358-360), caída en `DROP_TIME` (361), golpe del cuerpo en `DROP_TIME + FALL_LENGTH * 0.85` (364-367), `place_victim` (368), `move_torch` (369), `move_camcorder` (370), `staged.pose` (372). Fin en `capture_length() + 0.3` o `END_TIME` (373-375).
- `finish_execution` (379-417): `leave_scene` (383); en la máquina de la víctima, `tape.stop(false)` (387), `lost_signal = LOST_HOLD` (388); `ledger.note_death` (400); `session.capture(seat)` (401), que es donde se decide la derrota o el reinicio; `objectives_on_death` (403); si había un compañero en el armario, también muere (405-409).
- Soltar la captura: `release_execution` (421-452) cuando la criatura se va o se corta la escena: cámara de vuelta, linterna encendida, `blood.release` (437), armario cerrado (440-444), `creature.end_capture()` (452).

### 3.9 Renacer

- `session.revived` llega a `on_revived(restart)` (`hotel_main.gd:305` → `revival.gd:20-43`). Ver apartado 8.

### 3.10 Repetición

- Cinta de la propia víctima: ver apartado 6. Al terminar, la criatura puede mirar a la lente si el jugador lo ve (`settle_lens`, `executions.gd:556-560`, `GLANCE_BY` = 2.0, 83-85).
- Observador: `--observer` (ver apartado 7). Sin cuerpo; cámara propia.
- Repaso de partidas de bots: `begin_replay` (`hotel_main.gd:375-382`) carga `res://tools/bots/bot_replay.gd`, que NO viene con el juego exportado (370-374, 377).
- Menús de consulta: "archive" (618), "records" con la cinta de los registros (619-621), "achievements" (622).

### 3.11 Final

- `WON` (1242-1252): `file_run(true)` si no es cliente y el resumen está vacío (1244); en piso 1 contra la máquina, abre el piso 2 para esa dificultad (1247-1248; `unlock_floor2` 626-631). Menú "online_won" o "won".
- `FAILED` (1253-1259): `clear_checkpoint` si hay partida y es anfitrión (1256); `file_run(false)` (1258); menú "online_failed" o "failed".
- `file_run` (1273-1276): `close_run(won)` → `ledger.close(won)` (1292; 299-377), que termina con `SCORE.settle(line)` (`run_ledger.gd:377`); `take_run` (1281-1287) llama a `records.file(line, seat, mine)` (1286) y guarda `ui.outcome` y `ui.places`; en red, `match_net.tell_summary(line)` (1276).
- Salida por escalera (piso 2): `begin_leaving` (`lifts.gd:524-540`) y `ride_out` (552-558) con `LEAVE_TIME` = 4.0 (`lifts.gd:457`).

## 4. Qué orquesta hotel_main y cómo se comunica

### 4.1 Patrón de servicios

- No hay autoloads (`project.godot` sin sección `[autoload]`). Todo cuelga de `hotel.tscn`:
  - `$Services/Settings` y `$Services/GameSession` vienen de la escena (`hotel.tscn:16-20`).
  - Los catorce restantes se crean en código y se añaden a `$Services` (`hotel_main.gd:225-287`).
- Cada servicio recibe `level = self` (por ejemplo `hotel_main.gd:238, 246, 250, 254, 258, 262, 266, 270, 274, 278, 282, 286`) y guarda una referencia a `level`. `level.X` es la forma de hablar entre piezas.
- `hotel_main.gd:1935-2123` tiene DELEGADOS: propiedades y funciones que reenvían a `tvs`, `code`, `executions`, `revival`, `interaction`, `rig`, para que el código de red, los bots y los tests siga llamando a `level.X`.
- `hotel_main.gd:15-17`: `creature` es una propiedad que devuelve `locust` (el nombre antiguo sigue vivo).

### 4.2 Señales conectadas (hotel_main)

- `player.hiding_changed` → `world_audio.hide_cue` (299) y `on_hide_changed` (300).
- `ui.action_requested` → `on_action` (301).
- `ui.sheet.chunk_drawn` → `match_net.sheet_local` (302).
- `session.changed` → `on_state` (304); `session.revived` → `on_revived` (305).
- `net.closed` → `on_net_closed` (306); `net.lobby_changed` (308, 311); `net.joined` (312); `net.steam.join_asked` (320).
- `records.changed` → `tell_steam` (318), que llama a `net.steam.unlock`.
- `settings.changed` → `apply_settings` (327).
- `process_frame` → `capture_perf_frame` (295), solo con traza.
- `player.noise` → `on_noise` (1545); `door.noise` → `on_noise` (1546); `door.sound_requested` → `world_audio.door_cue` (994); `hide.peek_started` → `on_peek` (996).
- Desde otros: `session.changed.emit()` en `revival.gd:151,186`, `code_lock.gd:221`, `floor_save.gd:140`, `code_lock.gd` y `director` (`signal decided`, `pacing_director.gd:114`, emitida en `say`, 867).
- En total hay 23 llamadas `.connect(` en el ámbito y 6 líneas con `signal` o `.emit(`.

### 4.3 Grupos y nodos con nombre

- Grupos: `"hotel_hides"` (se añade en `game/world/interactables/hiding_place.gd:146`) y `"hotel_documents"` (`hotel_document.gd:21`). Los lee `observer_gizmos.gd:188` y 203.
- Rutas `$`: `$Services` (14 usos), `$Presentation/Analog` (2), `$Presentation/WorldEnvironment` (1, `hotel_main.gd:1925`), `$WorldAudio`, `$Player`, `$Interface`, `$Services/Settings`, `$Services/GameSession`.
- Rutas de nodo por nombre: `Presentation/Lens`, `Presentation/Lens/Screen`, `Presentation/Analog/Screen`, `Presentation/Camcorder` (`presentation_rig.gd:38, 51-53`); `HUD/Crosshair` (`hotel_main.gd:1205`).

### 4.4 Red: llamadas desde la capa de app

- RPC directos: `execute_start.rpc` (executions.gd:193), `tell_lens.rpc_id(1, ...)` (552), `lens_settled.rpc` (560), `hide_forced.rpc` (hotel_main.gd:1477), `television_state.rpc` (revival.gd:181), `warp_state.rpc` (televisions.gd:202).
- Métodos de `match_net` usados (en orden de frecuencia): `in_match` (35 usos), `local_is_locust` (21), `bodies` (21), `config` (4), `versus` (3), `use_panel` (3), `use_hide` (3), `world_sound` (2), `use_door` (2), `next_watch` (2), `locust_seat` (2), `clear_checkpoint` (2), `call_lift` (2), `body_of` (2), y 1 uso cada uno de `watching`, `watched_body`, `warp_state`, `use_television`, `use_container`, `use_code`, `tell_summary`, `tell_lens`, `tell_hunter`, `television_state`, `spawn_point`, `sheet_local`, `ride_lift`, `revive_everyone`, `remote_leaves`, `rejoin_snapshot`, `pack_local`, `noise`, `locust_ride`, `lens_settled`, `leave_floor`, `hide_forced`, `free_victim_hide`, `floor_built`, `floor_building`, `execute_start`, `end`, `checkpoint_path`, `catch_up`, `cards`, `begin_wardrobe_job`, `begin`.
- Métodos de `net` usados: `in_match` (35), `is_client` (27), `local_is_locust` (21), `active` (11), `start_match` (4), `shutdown` (4), `versus`, `use_hide`, `world_sound`, `use_panel`, `use_door`, `next_watch`, `locust_seat`, `join_observer`, `clear_checkpoint`, `body_of`, `watched_body`, `use_television`, `use_container`, `use_code`, `tell_summary`, `tell_hunter`, `start_problem`, `spawn_point`, `sheet_local`, `set_option`, `ride_lift`, `revive_everyone`, `return_to_lobby`, `remote_leaves`.
- Regla de autoridad: la mayoría de decisiones se toman en el anfitrión (`net.is_client()` se pregunta antes de actuar en, entre otros: `capture_survivor` 180, `burst_wardrobe` 1475, `on_revived` 21, `note_hide` 1269, `hotel_main.gd:1244` (cierre de la partida), `hotel_main.gd:1195` (libro de sector), `sanity.tick` 86, `lifts.follow_players` 60, `executions.report_lens` 552, `hotel_main.gd:1655`). Las cosas visuales se hacen en todas.

### 4.5 Contratos que app espera de otras piezas

- Criatura (`level.creature`), usada en todo el ámbito. Métodos: `can(cap)`, `capture_style()`, `hallucinations()`, `begin_capture(exec)`, `turn_for_capture(yaw)`, `end_capture()`, `capture_length()`, `may_capture(body)`, `cue_of(body)`, `lead_to(point, radius, seconds, kind, once, avoid, sniff)`, `investigate(point)`, `search_from(point, dir)`, `follow_to_planta(stage, bool?)`, `teleport(point, yaw, why)`, `relocate(point, rest)`, `place_at(room)`, `start_room(n)`, `den_point(stage)`, `save_state()`, `restore_state(kept, grace)`, `set_control("player"|"puppet"|"ai")`, `tune(profile)`, `arm(bool)`, `apply_quality()`, `blackout()`, `hear(point, r)`, `hear_route(point, r)`, `sees(player, bool)`, `gaze()`, `face_point()`, `view()`, `watched(point)`, `quarry()`, `activity()` (con `&"capture"`, `&"withdraw"`, `&"roam"`, `&"chase"`), `is_hostile()`, `is_chasing()`, `is_hunting()`, `is_wary()`, `in_transit()`, `is_engaged()`, `is_attacking()`, `noticing()`, `accepts_leads()`, `earned_rest()`, `forced_after()`, `searched_lately(room)`, `travel_metres(room)`, `presence_sound()`, `beat_now()`, `debug_lines()`, `debug_state()`, `draw_gizmos(node)`, `hunter_camera()`, `ducts` (si tiene), `rng` (RandomNumberGenerator), `grace`, `dull`, `control`, `visual` (con `scene`, `crawling`, `look_point`, `limbs.upright_share`, `limbs.grips`, `scene_held`, `animator`, `play(clip)`, `mask_transform()`). La definición está en `game/enemies/creature.gd` (no leído).
- Jugador (`level.player`): `camera` (con `top_level`, `near`, `fov`, `rotation`, `global_transform`, `current`), `torch` (SpotLight3D con `visible`, `light_size`, `shadow_enabled`, `light_volumetric_fog_energy`, `light_color`, `light_energy`, `spot_range`, `spot_angle`, `spot_attenuation`, `shadow_bias`, `shadow_normal_bias`), `sanity`, `stamina`, `exhausted`, `crouched`, `zoom`, `zoom_wanted`, `pilot_as` (Vector3), `focus_attributes`, `autofocus`, `handheld_enabled`, `avatar` (con `show_to_owner`, `end_capture`, `fallen`, `bones`, `bone_point`, `rig`, `meshes`, `pose_capture`, `set_body_shadow`, `set_character`), `hidden`, `hiding_place`, `held`, `active`, `reading`, `slot`, `spawn`, `burnt`, `velocity`, `visible`, `collision_layer`, `reset_survival`, `reset_handheld`, `set_pilot`, `set_burnt`, `snap_torch`, `force_leave_hide`, `enter_hide`, `ease_out`, `lens_focus`, `peek`, `hard_floor`, `eye_height`, `FOCUS_BLUR`, `zoom_fraction()`. Lo define `player.gd` (no leído).
- Nodo del piso (`level.hotel`), usado como `GEOMETRY` (`hotel_geometry.gd`, no leído): `doors` (con `doorway`, `opened`, `moving`, `locked`, `closed_rotation`, `set_state`, `sound_requested`, `noise`, `name`), `hides` (con `inside_offset`, `occupant`, `peek_started`, `force_open`, `hold_open`, `release_open`, `has_room`), `lifts`, `arrivals`, `arrival_cars`, `arrival_facing`, `depart_leaves`, `arrive_leaves`, `gates` (con `locked`), `room_nodes`, `plan_walls`, `panes`, `containers`, `panels`, `materials` (con `ceiling_service`), `bounce` (con `baking`, `poll`, `perf`), `dark`, `reduced`, `echo_view`, `eye_planta`, `building`, `ROUND_PARTS`, `probes_at_once`, `probes_made`, `lit(room_id)`, `flicker_one(room, t, seed)`, `blackout(bool)`, `light_body(model)`, `adopt(node)`, `in_car(index, point, reach)`, `doors_near(p, r)`, `relock_gate(stage)`, `open_gates(stage, ready)`, `update_part(...)`, `update_visibility(p, bool)`, `tell_time(sec)`, `apply_quality(preset)`, `grade()`, `start_bounce`.
- Tipo de sector (`level.kind`, `FLOORS.kind(n)`, ver `floor_index.gd`, no leído): `NUMBER`, `PAR`, `LEAVE`, `CREATURE`, `CREATURE_KEY`, `OBJECTIVES`, `GENERATOR`, `GEOMETRY`, `VALIDATOR`, `stage(n)` (con `objectives`, `errand`, `brief`), `count()`, `title_of(stage)`, `stages_asking(name)`, `FIRST_LEAD`, `get_script_constant_map()`.
- Palette/office (`FLOOR.palette(manifest)`, `OFFICE` = `office_palette.gd`, no leído): `hard_floor(room)`, `off_limits_rooms(manifest)`, `label(room)`, `height_of(room)`, `false_ceiling(room)`, `tile_of(p)`, `tile_centre(cell, ceiling)`, `TILE`, `has_phone`, `has_typewriter`, `has_copier`, `troffers(room)`.
- Manifest (el generador), claves que lee app: `rooms[i]` con `id`, `wing`, `py`, `height`, `span_x`, `span_z`, `corridor`, `landing`, `number`, `furniture[]` (con `kind`, `at`, `extra.height`); `exit`, `start`, `start_facing`, `refuges`, `gates[]` (con `room`, `beyond`, `out`, `arrive`), `plans[]` (con `plan`, `shape`, `rooms`), `entries`, `merged`, `adjacency`, `archives[]` (con `aisles`), `power` (con `board.point` y `timers[].point`), `air.unit.point`, `area`, `fallback`, `requested_seed`, `seed`, `floor`. Uso: `hotel_main.gd:865-870, 913, 1510-1512`; `observer_view.gd:400-416`; `code_lock.gd:109-115`; `lurker_hallucinations.gd:156-162, 301`; `lurker_capture.gd:72-74`; `phantom_sight.gd:290`; `run_ledger.gd:358`; `revival.gd:120-124`.
- Sesión (`level.session`, `game_session.gd`, no leído): `state`, `stage`, `stages`, `floor_number`, `run_seed`, `roster_count`, `participants` (seat → Life), `dropped`, `goal` (dict: `ready`, `blackout`, `restored`, `kind`, `done`, `needed`), `elapsed`, `restarts`, `restarts_allowed`, `solo_restarts`, `restart_wait`, `keeps_checkpoint`, `online`, `authority`, `difficulty`, `message`, `checkpoint_path`, `last_fall()`, `forget_checkpoint()`, `capture(seat)`, `finish_stage()`, `more_stages()`, `can_depart()`, `update_goal(delta, met)`, `set_refuge(slot, bool)`, `start(seed, fallback, slots)`, `start_match()`, `read_state(seed)`, `write_state(state)`, `checkpoint()`, `pause()`, `set_state(state)`, `State` (ver 3.7), `Life` (EXPLORING=0, REFUGE=1, DEAD=2; ver `observer_view.gd:518` y `sanity.gd:90`).
- Estados de sesión: `observer_view.gd:654` tiene la lista `["menú","cargando","jugando","en pausa","cambio de sector","ganado","perdido","escena"]`, que indexa por el estado. Si se respeta el orden de la lista, MENU=0, LOADING=1, PLAYING=2, PAUSED=3, TRANSITION=4, WON=5, FAILED=6, CUTSCENE=7 (inferido, no verificado en game_session.gd).
- Reglas de la sala (`rule(id)`, `hotel_main.gd:136`; `MATCH_RULES` no leído). Ids usados en el ámbito: `restarts`, `plan`, `plan_fade` (169), `onslaught` (179), `sanity` (`sanity.gd:104`, `wear` 134), `code` (`code_lock.gd:510`), `tv_travel` (`televisions.gd:188`), `plain_sight` (`presentation_rig.gd:196`).
- Dificultad: `tuning()` (146-147) devuelve `DIFFICULTY.profile(difficulty, kind.CREATURE_KEY)`. Claves usadas: `restarts`, `solo_restarts`, `lift_wait`, `lift_hold`, `grace`, `tv_hop` (`televisions.gd:186`). Y las del director, en 10.3.
- World audio (`level.world_audio`, `world_audio.gd`, no leído): `enabled`, `hush`, `reset()`, `play_at(path, point, db, bus?, pitch?)`, `play_long(path, point, db, rid, hushed, seconds, tag?)`, `stop_long(voice)`, `long_playing(path, secs, tag)`, `long_cues` (con `player`, `point`, `gain`), `route_source(point)`, `apply_route(player, route, db, bus, flag?)`, `walked_route(a, b)`, `listener_position()`, `set_creature(c)`, `aura`, `mood`, `duck_db()`, `play_everywhere(path, point, db, pitch)`, `phantom_point`, `choose(list)`, `loop_stream(stream)`, `voices`, `caption_text`, `update_tv_hiss`, `hide_cue`, `door_cue`, `DUCT_BUS`, `ACOUSTIC_MASK`.
- Interfaz (`level.ui`, `interface.gd`, no leído): `menu(name, ...)` (nombres en 4.6), `show_transit`, `hide_transit`, `show_brief`, `hide_brief`, `show_skip`, `hold_skip`, `hide_skip`, `show_rewind`, `hide_rewind`, `lost_signal(sec)`, `flash(text, sec)`, `keypad(kind)`, `show_lock`, `hide_lock`, `show_document`, `hide_document`, `show_hint`, `show_characters`, `show_settings`, `set_briefing`, `close_menus`, `hold(p)`, `tear_away`, `tear_sheet`, `film_marks(material)`, `play_intro`, `sheet` (con `visible`, `open`, `close`, `clear`, `snapshot`, `restore`, `chunk_drawn`, `map_source`, `map`, `seat`, `editable`), `hint`, `subtitle`, `progress`, `summary`, `places`, `outcome`, `elapsed`, `descend`, `settings_open`, `return_action`, `records_back`, `rules_stale`, `screen`.

### 4.6 Menús que pide app

- `"main"`, `"difficulty"`, `"loading"`, `"pause"`, `"transition"`, `"won"`, `"failed"`, `"online_won"`, `"online_failed"`, `"online_pause"`, `"lobby"`, `"join"`, `"join_steam"`, `"host_ip"`, `"mp_ip"`, `"mp_steam"`, `"multiplayer"`, `"steam_wait"`, `"steam_invite"`, `"rules"`, `"credits"`, `"archive"`, `"records"`, `"achievements"`. Y en `ui.show_*`, los que no son menús: `"characters"` (`hotel_main.gd:572`, 604) y `"settings"` (570, 599).

## 5. Ejecuciones (la captura)

### 5.1 Decisión y datos

- Quién decide: el anfitrión (o el único equipo). `stage_capture` (`executions.gd:201-232`).
- Qué se envía: un diccionario `execution` con `seat`, `partner`, `time`, `point`, `yaw`, `stabs`, `dropped`, `screamed`, `entry`, `side`, `slump`, `straight`, `room`, `hide`, `far`, `from`, `facing`, `crouched`, `torch`, `glance`, `seed`, `id`, `ending`, y opcional `extra`, `cue`, `lens` (`executions.gd:272-282`).
- Entradas posibles: `ENTRIES` (`capture_score.gd:13`) = front, back, side, above, wardrobe, ambush. The Lurker usa back y above (`lurker_score.gd:11`). Elección de The Locust (`locust_capture.gd:62-73`): en armario, "ambush" si la criatura está en pounce y "wardrobe" si no; agachado, "above"; de pie: "front" si mira hacia ella (ángulo <= 50 grados), "back" si mira de espaldas (>= 130), y "side" en medio.
- Elección de The Lurker (`lurker_capture.gd:61-69`): "above" si la sala es alta (`OFFICE.height_of(room) > HIGH_ROOM` = 3.0, `lurker_capture.gd:20`) o en pasillo de archivo, ella está delante (70 grados) y el jugador no mira hacia arriba más de 30 grados (`pitch < 30`, `lurker_capture.gd:68`; en Godot, el giro positivo de X mira hacia arriba); si no, "back".

### 5.2 Escena en el reloj común

- Todas las distancias y tiempos salen de `capture_score.gd` (13-173). Entradas en segundos desde el agarre: `FACE_TIME` 0.55 (18), `BACK_TURN_FROM` 0.12 (19), `BACK_TURN_TO` 0.34 (20), `BACK_FACE_TIME` 0.68 (21), `SCREAM_AFTER` 0.05 (25), `ARRIVE` 0.07 (28), `JERK_TIME` 0.22 (30), `SWIPE_REACH` 0.07 (34), `SWIPE_LENGTH` 0.24 (35), `LIFT_FROM` 1.6 (40), `LIFT_TO` 2.7 (41), `ARM_TIME` 3.08 (43), `KILL_TIME` 3.3 (44), `DROP_TIME` 3.5 (45), `FALL_LENGTH` 0.9 (50), `CUT_TIME` 4.7 (59), `END_TIME` 5.0 (62).
- Altura y distancia de la víctima: `HOLD_FAR` (0.75, 1.05) (67), `HOLD_NEAR` 0.6 (68), `LIFT_HEIGHT` 1.0 (69), `HOLD_STAND` 0.1 (70). Espacio para caer: `LIE_ROOM` 1.4 (75).
- Curvas (funciones puras del tiempo): `stoop` (119-123), `lift` (126-128), `closing` (131-132), `limp` (135-136), `fall` (139-140), `sunk` (144-145), `toppled` (148-150), `jolt` (153-155), `swipe` (158-159), `thrust` (162-164), `turned` (167-169), `glance` (172-173).
- Partitura de The Lurker (`lurker_score.gd`): `GRAB` 0.3 (14), `BACK_TURN` 0.35 a 0.8 (16-17), `FACE_TIME` 2.33 (19), `ARRIVE` 0.25 (23), `SWIPE_LENGTH` 0.2 (28), `LIFT_FROM` 1.6 y `LIFT_TO` 2.6 (30-31), `ARM_TIME` 3.0, `KILL_TIME` 3.15, `DROP_TIME` 3.6 (33-35), `CUT_TIME` 5.4 (44), `END_TIME` 5.7 (45), `HOLD_FAR` (0.35, 0.55) (49), `HOLD_NEAR` 0.45 (50), `HOLD_STAND` 0.0 (52), `closing` = 0 (102-103: "nunca se la acerca").

### 5.3 Dónde está cada cosa en cada segundo

- Víctima: `victim_hold_point` (`locust_capture.gd:120-124`): a distancia `far` mientras dura la cara, luego se acerca y se levanta. Lurker (`lurker_capture.gd:123-125`): los pies se levantan hasta `lift` * `extra.lift` por encima de `from`.
- Ojo (lente de la cámara de la víctima): `lens_point` (locust 128-131): a `far` delante de la criatura, con altura 1.64 m de pie y 0.9 m agachado. Lurker (127-129): a la altura de los ojos de la víctima levantada.
- Máscara (cara de la criatura en el visor): `mask_from` (locust 135-137).
- Cuerpo al caer: `body_rest` (locust 150-152), `head_rest` (155-157), `head_away` (164-172). La cabeza se gira lejos de donde queda la cámara.
- Caída: `fall_room` (82-88): primero de lado (0.35 m de altura), luego hacia atrás con alturas 0.2 y 0.6; si no hay sitio, doblado (slump) con `room` metros atrás. `LIE_ROOM` 1.4 m. `fall_way` (104-105) con 0.62 y 0.78.
- Linterna: `torch_rest` (locust 188-207): una semilla propia `seed ^ 0x51ed` (190); cae a 2.1 a 2.9 m del cuerpo (198); la luz apunta al carbón y la pared de atrás (206-207).
- Cuerpo de The Lurker: `pose` (`lurker_capture.gd:156-181`), con `STOOP` 0.25 (26), `GRAB` 0.3 (`lurker_score.gd:14`), `CEILING_REACH` 2.6 (24), `HANG_BEHIND` 0.45 (23).
- Baldosa de The Lurker: `swing_tile` (185-210), `TILE_FROM` 0.2 (28), `TILE_OPEN` 0.2 (29), `TILE_SWING` 0.45 (30); amplitud `exp(-0.4 s) * cos(2.2 s)` (206).

### 5.4 Qué suena y qué se ve, en orden

- Grito: `scream()` (`executions.gd:328-341`) a `scream_time(entry, covered)` = `SCREAM_AFTER` (+ `face_start` salvo cubierto). En la víctima, en su propio oído (`scream_sound`, volumen -8 dB si está "suave", `SOFT_DB` en `death_tape.gd:99`). En los demás, `play_everywhere(SCREAM, creature + (0,2,0), -4.0, 0.0)` (341).
- Golpe: `kill_sound(seed)` (`locust_capture.gd:25`, `KILL_BLOW` `execution_hit.wav` en 22); The Lurker elige entre `bite_1.wav` y `bite_2.wav` (lurker_capture 14, 36).
- Vibración de mando: `rumble(0.5, 0.9, 0.7)` al agarre (`executions.gd:299`), `rumble(0.2, 1.0, 0.35)` al golpe (359), `rumble(0.3, 0.5, 0.2)` a la caída (367), `rumble(0.35, 0, 0.25)` al apagón (`hotel_main.gd:1385`).
- Sonido de caída del cuerpo: `BODY_FALL` (`executions.gd:59`, stomps 1 a 3), a -7 dB, `pitch` 0.74, en `DROP_TIME + FALL_LENGTH*0.85` (366).
- Sangre y su sonido: apartado 5 de `blood.gd` abajo.

## 6. Cinta de muerte (`death_tape.gd`)

- Solo en la máquina de la víctima (`death_tape.gd:8-10`). Empieza en `begin` (165-210) desde `executions.apply_execution` (322).
- Cámara: la del jugador, desacoplada (`camera.top_level = true`, 190), con `camera.near = LENS_NEAR` 0.02 (`death_tape.gd:42`, 187) y sin movimiento de mano (`handheld_enabled = false`, 188-189).
- Encuadre de la máscara (`facing`, 312-352): la distancia de la lente a la máscara: `MASK_FAR` 0.26 al llegar, `MASK_HELD` 0.165 tras la sacudida, `MASK_CLOSE` 0.135 y `MASK_NEAR` 0.11 como mínimo (30-33). Se acerca (lunge) en los últimos `LUNGE` = 0.07 s hasta `MASK_LUNGE` 0.082 (40-41). Temblor de la mano: `SHAKE` 0.4 grados, `SHAKE_RATE` 13 Hz, desvanecimiento `SHAKE_FADE` 0.3 s (49-51). Llegada: `ARRIVE_DROP` 0.05 y `ARRIVE_SIDE` 0.2 (45-46).
- Por la espalda (`turning`, 363-378): la cámara tira hacia atrás (`BACK_DIP` 0.3 radianos, 54) y gira en el brazo.
- Caída de la cámara: `plan` (221-237) llama a `FALL.solve` con la escena (`from`, `middle`, `hold`, `body`, `head`, `creature`, `torch`, `dark`, `exclude`, `allowed`). `take` tiene `rest`, `kind` (VIEW, PARTIAL, DOWN o UP), `score` y la ruta. La ruta la pone `FALL.pose(take, thrown, t)` (287).
- Qué ve la lente tras la caída: el suelo, y se va rompiendo: `dropout` (508-514) corta trozos de sonido y de imagen, con una función de hash determinista `sin(piece*12.9898 + id*78.233)*43758.5453` (513).
- Sangre en la lente: `on_lens(id, lens)` (`blood.gd:489-495`), con `LENS_REACH` 1.7 (`blood.gd:77`). Se pinta desde `KILL_TIME + 0.1` (`death_tape.gd:445`).
- Golpes en la imagen (`frame_picture`, 413-449): `HIT_GRAB` (0.4, 0.05), `HIT_FLOOR` (1.0, 0.27), `HIT_AGAIN` 0.5, `HIT_BODY` (0.9, 0.32) (57-63). Escribe en `post_material`: `tape_hit`, `tape_band`, `tape_fray` (441), `lens_blood`, `lens_seed` (447), `lens_down` (450).
- Sonido del micrófono (`frame_sound`, 459-503): `mic_on` (532-541) añade al bus 0 tres efectos: paso alto a `MIC_LOW` 120 Hz, paso bajo a `MIC_HIGH` 6500 Hz y ganancia. La ganancia automática (AGC) baja a `AGC_FLOOR` -14 dB al caer, `AGC_BLOW` -9 al golpe, sube `AGC_RISE` 7 dB/s hasta `AGC_OVER` 6 (63-71). El silbido de cinta (`HISS` `tv_static.wav`) suena en `HISS_DB` -33 dB (94-95).
- Lámpara de la cámara: `LAMP_FACE` (0.5, 1.15, 1.4), `LAMP_FACE_LIT` (0.22, 1.15, 1.4), `LAMP_FLOOR_DARK` (1.3, 1.15, 0.5), `LAMP_FLOOR_LIT` (0.2, 0.9, 1.2) (87-90); antes del golpe, `LAMP_BEFORE` 1.8 s (93).
- Fin: `stop(alive)` (555-584): restaura la cámara, `camera.top_level = false`, `camera.near` guardada, el zoom, `handheld_enabled`, `pilot_as`; `camera_cut`.
- Estado de la cinta en la capa de app: `CLEAR_OF_HEAD` 0.5 m y `SHOWN_AFTER` 0.5 s (126-127), para mostrar el cuerpo del jugador en su propia cámara (`avatar.show_to_owner`, 301-303).
- Sin partida: `lost(time)` = `time >= CUT_TIME` o `gone` (157-158). Con `brief` (ya se vio esa forma de caer en el piso), la imagen se va al pararse la cámara (`frame_picture` 417-419).

## 7. Vista del observador (`observer_view.gd`, `observer_gizmos.gd`)

### 7.1 Qué es y cómo entra

- `--observer` (`hotel_main.gd:362-363`) → `begin_observing` (442-466): `settings.force_window = true` (446), `session.keeps_checkpoint = false` (450), puerto por defecto `net.PORT` (451), semilla al azar si no hay (452), dirección `--address` (454) y puerto `--port` (455). Llama a `net.join_observer` y espera hasta `OBSERVER_WAIT` = 2.5 s (420, 457-461). Si nadie responde, construye un piso propio (466).
- Llamada periódica: `observer_seek` (471-476) reintenta cada `OBSERVER_KNOCK` = 3.0 s (439, 475-476).
- Modo: `enter_observer_mode` (480-507): sin cuerpo, `player.active = false`, `visible = false`, `collision_layer = 0` (482-485), la criatura no tiene aura ni presencia (489-491), la radio de amenaza se apaga (493-495), y se crea `OBSERVER.new()` (502-505) con cámara actual (505).
- Otro piso: `R` → `rebuild(randi_range(0, 2147483647))` (239), `Shift+R` vuelve a la semilla anterior (240). `observer_rebuild` (511-514) impide hacerlo si hay partida.

### 7.2 Cámara, controles y capas

- Cámara: `far` 400, `fov` 75 (140-141); `cull_mask` 1048573 (144): no capa 2, que es el cuerpo propio.
- Vuelo: `SPEED` 22 m/s (76), rango 2 a 200 (77), `QUICK` 4 al correr (79); rueda ×1.25 o ÷1.25 (211-212). `MAP_HEIGHT` 150 (81). Inclinación limitada a ±1.5 rad (205).
- Teclas (`observer_view.gd:202-249`, y ayuda en 30-35): movimiento (`left`, `right`, `forward`, `backward` por `Input.get_vector`, 492; `jump`, `crouch` 493; `sprint` 494); TAB sigue al siguiente cuerpo, con la criatura al final (224, 284-289); F suelta (225); M plano (226, 330-342); 1 a 7 capas (215-219): path, trails, noises, doors, errand, sight, ducts; L luz propia (228-230); C techos (231-234); V lectura acústica (235, 294-319); H paneles (227); R otro piso (236-239); P pausa del tiempo (242-243), `[` y `]` (244-247); F5 volcado a `user://observer_<hora>.json` (248, 619-648); ESC libera el ratón, y otra vez cierra (249, 264-269); RePág/AvPág cambian de planta (222-223, 253-260).
- Capas (`observer_gizmos.gd:11-18`): 1 el camino de la criatura y su destino (`draw_creature` 152-163); 2 rastros de los últimos 12 s (`TRAIL_TIME` 12, `TRAIL_EVERY` 0.25; 21-22, `draw_trails` 165-172); 3 ruidos como anillos que se apagan en `NOISE_TIME` 2.5 s (24, `draw_noises` 174-181); 4 puertas, armarios y ascensores (`draw_doors` 183-193); 5 lo que pide el sector: sets, cajones y documentos (`draw_errand` 195-204); 6 cono de visión de la criatura (`draw_sight` 216-226); 7 ductos (`draw_ducts` 208-212).
- Dibujo: un solo `ImmediateMesh` de líneas, sin sombras, `no_depth_test = true`, `render_priority = 120` (`observer_gizmos.gd:52, 75-85`), redibujado en cada cuadro (`_process` 91-107). `top_level = true` (74).
- Plano: `frame_map` (346-362) con cámara ortogonal, `camera.size = map_span * 2.3 * ...` (`fit_map` 368-374). Las paredes del plano vienen de `hotel.plan_walls`.
- Lectura acústica de la criatura (`toggle_echo` 294-319): usa `Ears` (`observer_view.gd:45-73`), con `EYE` (0, 2.35, 0) (46), `ARM` 2.8 (50) y `SHOULDER` 1.0 (51), y `echo_view.gd` (no leído).
- Luz propia del observador: `DirectionalLight3D` con energía 1.1, o 2.2 en plano (`observer_view.gd:155-160, 451`); ambiente 0.4 o 1.4 en plano (446); color (0.78, 0.8, 0.85) (447); la niebla se apaga si hay luz propia (449-450).
- Registro en pantalla: `LOG_KEPT` 16 (83), `watch_changes` (500-522) compara cada cuadro lo que cambia y añade líneas. El panel `report()` (525-589) y las métricas `readings()` (592-615). No hay cambios al juego: solo se mira.

### 7.3 Nombres de planta

- `PLAN_NAMES` (`observer_view.gd:86`) y `SHAPE_NAMES` (87) traducen los planos del generador: espina, doble, anillo, peine, manzanas, brazos, madriguera, podrido; y rectángulo, con muesca, en L, en U, con patio, en H.

## 8. Renacer (`revival.gd`)

- Cuándo: `session.revived(restart)` (`hotel_main.gd:305`). `on_revived` (20-43): si es cliente o no hay piso, no hace nada (21).
- Punto de vuelta: `revival_point` (113-126): la entrada del ala (`gates[stage-2].arrive`); en el piso 2 se corre `LIFT_AWAY` = 0.9 m (130) desde la pared del ascensor (125-126). `revival_spread` (134-135): 0.9 en el piso 2, 1.2 en el piso 1. Los cuerpos se reparten a un radio de esa distancia (27-28).
- Quién se levanta: cada asiento de `participants` que no está en `dropped` (27-28). Los que se fueron a mitad no vuelven (`session.dropped`, 27).
- Reinicio de sector (`restart = true`): `ledger.note_restart()` (37); la criatura va a su hueco `creature.den_point(stage)`, o si no lo tiene `den_away(point, RESTART_DEN)` = 45 m de paseo (38-41, 49). `den_away` (60-85): sala de la misma ala, a 45 m o más, sin refugio ni lobby ni vacío; el sorteo lo hace un `RandomNumberGenerator` con `draw.seed = hash([manifest.seed, "restart den", stage, restarts])` (81); el punto se proyecta al mapa de navegación si está listo (84).
- `apply_revival` (139-192):
  - Pone `participants[seat] = EXPLORING` y emite `changed` (147-151).
  - Al jugador local, `restore_local_player` (154, 195-218): cordura 100 (198), no quemado (199), se libera la mano (207-208), `stop_watching` (211), `clear_screen_cues` (212), `visibility_clock = 1` (214), `camera_cut` (215); hoja reabierta si estaba abierta (218).
  - A los demás, `body.place(pos, 0)` (161), `sanity.minds.erase(seat)` (163), `set_burnt(false)` (164).
  - Si reinicia: `hotel.relock_gate(stage)` (168), `goal.ready = false` (171), `handler.reset()` de los objetivos (174), las televisiones del sector se apagan (177-181), el corte de luz se quita (184-186), `relocate_creature(creature_at, restart_grace())` (187), `director.on_restart()` (188: rest 60 s), `executions.clear_leavings` (190), `begin_rewind()` (192: `REWIND_TIME` 1.4 s, 757).
- Gracia de la criatura tras el reinicio: `restart_grace()` = `max(RESTART_GRACE=12, tuning().grace)` (`revival.gd:51-54`).
- `relocate_creature` (95-99): `creature.relocate(point, rest)` y luego `creature.teleport(point, NAN, &"revival")`.
- Mirar a un compañero (`watch_teammates` 244-258, `watch_over` 267-299): la cámara vigila con la del compañero (`body.smooth_view()`, 287); se copian `fov`, `near` y `far` de la cámara propia (275-277); las capas de la malla del cuerpo visto se apagan cuando la cámara está en su cabeza (`AT_HEAD` 0.5 m, 311; `near_head` 312-315; `own_sight` 304-309). La pista de texto es "HAS MUERTO, OBSERVANDO A %s, %s PARA CAMBIAR" (258).
- `stop_watching` (227-241): vuelve a la cámara propia, la criatura se ve de nuevo, y `snap_torch` (241).

## 9. Alucinaciones (cordura y mentiras)

### 9.1 Cordura (`sanity.gd`)

- Qué es: un medidor sin barra. Cae en la oscuridad y sube con luz (`sanity.gd:8-12`).
- Tasas (por segundo): `SANITY_DARK` = 100/450 (= 0.222, siete minutos y medio de 100 a 0, `sanity.gd:39`, 137); con la linterna encendida y sin estar escondido, multiplicada por `SANITY_TORCH` 0.4 (40, 138); `SANITY_LIGHT` = 100/240 (sube en 4 minutos, 41, 140). Escondido o a oscuras cae como la oscuridad.
- Sustos: `SANITY_GLIMPSE` 4 (ver la criatura), `SANITY_STARE` 15 (ser mirado de frente), `SANITY_SIGHT_REST` 5 segundos entre sustos, con descuento de lo pagado (45-47, 103-122, 141-153). `SANITY_SHRIEK` 6 (100).
- Vista de la criatura (`sight_of_creature`, 203-219): a menos de `SANITY_SEEN` = 28 m (53), dentro de un cono de 0.72 de coseno (211, unos 44 grados), sin pared que lo tape (212-214), y con luz o a menos de 6 m (210). Mirar de frente: `STARE_CONE` 30 grados (50, 219).
- Umbral de mentiras: `SANITY_UNEASY` = 60 (51). Por debajo, el piso miente. `SANITY_BACK` 25 (52, 154): recupera la marca de quemado. Quemado al llegar a 0 (155).
- Ritmo de las mentiras: `HALLUCINATION_WAIT` (13, 42) segundos según cuánto ha bajado (54, 241); `PASSAGE_SHARE` (0.2, 0.45) para el paso falso (58, 245).
- Quién tiene la cordura: el anfitrión la lleva para todos (`minds`, 80); se avisa, según su comentario (`sanity.gd:37-38`), dos veces por segundo, con `pack()` (163-168) y `apply()` (172-180) en las máquinas. El propio medidor del jugador es `level.player.sanity`.
- El desgaste solo corre con `rule("sanity") == 1` (134) y solo en EXPLORING o REFUGE (90).
- Quemado: `burnt_survivors` (311-318) lo usa el director. Solo cuentan los vivos a los que puede llegar.

### 9.2 Mentiras de la criatura (`creature_lies`, `lies_tell_own`, `hallucinate`)

- `hallucinate` (227-253): si la cordura está por encima de `SANITY_UNEASY`, o se lee un texto, no pasa nada (228). Espera `lerpf(13, 42, gone) * randf_range(0.7, 1.3)` (241). Puede ser voz (si `gone > 0.5` y `randf() < gone*0.45`, 243), paso falso de la criatura (245-247), o sonido del piso: puerta, armario o llamada de la criatura (251-253).
- `lies_tell_own` (257-261) mira `OWN_LIES` de la criatura. Si tiene las suyas, `creature_lies()` (266-279) las crea y las guarda; la espera pasa a `lerpf(...) * randf_range(0.7, 1.3) * own.wait_scale()` (235-236).
- `ensure_sight` (283-290) crea `PhantomSight` cuando la cordura baja de `UNEASY` (97).

### 9.3 Mentiras de The Locust (`locust_hallucinations.gd`)

- Llamada desde otro punto (`false_call`, 40-59): solo las llamadas con `segment[1] >= LOCUST.AGGRESSIVE_GRUNT` (50-52); la voz suena por la pista `Threat` (44) a -4 dB (56), con tono 0.8 a 0.95 (57), `unit_size` 7 y `max_distance` 40 (46-47). El recurso es `grunts.ogg` (13).
- Duración: la de la pieza del clip (59, 62-65).
- Paso falso (`walk_past` 68-73 → `phantom_passage.gd`): ver 9.5.
- Modelo: `locust.glb` a escala `SIGHT_SCALE` = 1.95 (17, 19, 83-89).
- Huesos que no pueden verse: `Spine`, `Spine2`, `Pelvis`, `L_Forearm`, `R_Forearm`, `L_Hand`, `R_Hand` (`BODY_BONES`, 23); la cara se mira por `Head1` (22).

### 9.4 Mentiras de The Lurker (`lurker_hallucinations.gd`)

- Elige con pesos (`WEIGHTS`, 46) entre lo que hay cerca: garras (3.0), ducto (2.0; 4.0 en la planta de índice 2, `DUCT_WEIGHT_HIGH`), teléfono (1.5; 2.5 en la planta de índice 0, `PHONE_WEIGHT_LOW`), máquina de escribir (1.0), tubo (2.0), fotocopiadora (0.7), silla (0.7), persiana (1.0), lámpara (1.5), palanca (1.5), tictac (1.5), ventiladores (1.5). Ver `choices` (125-163) y `lie` (100-115).
- Lo que no se dice nunca: `NEVER` (43) lista sus sonidos reales (aviso, grito, presencia, mordisco, campana): `say` y `loop_long` lo rechazan con `push_error` (421-425, 429-437).
- Garras (`claws`, 366-382): de 3 a 6 golpes sobre el falso techo en 1.5 m, en 1.2 s; el 40% de las veces, una baldosa se mueve con polvo (`dust_puff`, 378-381).
- Ductos (`duct_path` 222-245 y `knock` 497-526): un camino de 3 a 6 aristas en la planta del oyente, empezando a 12 m; nunca cerca de ella (3 m, 243). Los golpes avanzan a `KNOCK_SPEED` 1.6 m/s (51, 457). Cada golpe es un `AudioStreamPlayer3D` con `unit_size` 6 y `max_distance` 40 (519-520), por la ruta de sonido de conductos (`ducts.sound_route`, 513), en el bus `DUCT_BUS` (515).
- Tubo (`tube_run` 248-258): de 6 a 20 m del oyente, con `CAPSULE_SPEED` de la objetivo de archivos (467).
- Persiana (`pane_near` 262-278, `shadow` 388-418): una sombra cruza el cristal en `SHADOW_TIME` 0.8 s, tamaño `SHADOW` (0.5, 1.4), alfa 0.8 (66-68). Gradiente y `QuadMesh`, sin sombra (392-411).
- Lámpara (`lamp_near` 282-296): hace fallar una luminaria en vista, durante `LAMP_FAIL` 1.2 s (70, 349).
- Ventiladores: `FANS_SHAPE` (2.5, 1.0, 1.5) segundos (64), `FANS_DB` -6 (62), en la forma de subida, mantener y bajada (475-485).
- Sus caras donde no está (`sight_spots` 556-602): puerta abierta a 10-35 m (`PEEK_RANGE`, 27), partición a 10-25 m (`PARTITION_RANGE`, 28), esquina a 8-20 m (`CORNER_RANGE`, 29), altura de la cabeza en el marco `PEEK_HEAD` (1.7, 2.0) (30), `OVER_PARTITION` 0.25 (31), `UNDER_CEILING` 0.35 (32). Máximo 6 lugares (`SPOTS_MOST`, 33), revueltos con `rng` (601-602).
- Descanso entre caras: `SIGHT_REST` (40, 90) segundos (37).
- Historia: las últimas 32 mentiras (114). `FOUND_KEEP` 2.0 s (82).
- `rng.randomize()` en `setup` (88): sin semilla. Las mentiras no se repiten entre máquinas.

### 9.5 Paso falso de la criatura (`phantom_passage.gd`)

- `START` (12, 20) m de paseo (21), `CLOSEST` 8 m (22), `PACE` 1.9 m/s (23), `LONGEST` 10 s (24), `STRIDE` 0.62 s entre pisadas (26). Lejos de la criatura real: `REAL_NEAR` 30 m (29), `REAL_AURA` 0.2 (30).
- Pistas: `Threat`, `unit_size` 6 y `max_distance` 34 (48-49), `area_mask` 512 (50), con el sonido de garras de `LOCUST.claw_sound()` (47).
- `begin` (73-101): elige hasta 8 salas a esa distancia que no estén fuera de límites (76-89), y valida que el camino quede a 8 m o más del oyente (93-94) y que no se vea desde la cámara (111-115).

### 9.6 Aparición de la criatura donde no está (`phantom_sight.gd`)

- Cuándo: solo con cordura por debajo de `UNEASY` = 60 (29), con `REST` (90, 180) entre apariciones (30); cada `LOOK_EVERY` = 0.5 s (31) tira un dado con `CHANCE` (0.01, 0.06), que sube según la cordura (32, 117-118). No con el observador, ni bots, ni en el armario, ni en lectura, ni en refugio (95-101), ni cerca de la criatura real (`REAL_NEAR` 25, 47).
- Dónde: `place` (193-213) prueba los lugares de las mentiras (`sight_spots`) y en su defecto, puertas a 10-35 m (`PEEK_RANGE`, 23) o el fondo de un pasillo recto de 3 celdas o más a 24-45 m (`STAND_RANGE`, 24; `RUN_CELLS` 3, 25; `corridor_end` 286-312).
- Cómo: se muestra un tiempo `SHOWN` (0.6, 1.6) (41). Desaparece si sale de la vista (`LOST` 0.5, 43), si gira más deprisa que `FAST` = 120 grados/s (44), si está a menos de `NEAR` = 8 m (45), si entra la linterna (`torch_on`, 175-178), o a los `UNSEEN_FOR` = 6 s sin verla (42). Al desaparecer deja `glitch` 0.5 en la cordura (160).
- Visibilidad: `SEEN` 0.8 coseno del centro (37), `PLACE_OFF` (0.45, 0.85) lejos del centro (35), `SIGHT_MASK` = 1 | 8 | 64 (20).
- Pose: `PEEK_IN` 0.4 s (49), `PEEK_LEAN` 0.6 (54), `JAMB_BEHIND` (0.55, 0.4, 0.7) (53).

## 10. Director de ritmo (`game/director/pacing_director.gd`)

### 10.1 Entradas

- Se crea solo si hay director (`hotel_main.gd:984-990`): en partida solo o en COOP con anfitrión (1058). No en VERSUS. `tune(tuning())` (988) y `setup(self, manifest.seed)` (989).
- Desde el piso: `level.session.state` (PLAYING para actuar, 243); `level.session.participants` (seat → Life) (431-436); `level.survivors()` y `survivor_active(body)` (260-261); `level.refuge_room()` (317); `level.goal_points()` (318, 688); `level.hotel.dark` (448, 452); `level.off_limits_rooms()` (825); `level.point_in_refuge(p)` (786); `level.hotel.doors` (783); `level.manifest.adjacency` (516, 809); `level.manifest.rooms` (con `id`, `wing`, `corridor`, `furniture`); `level.get_world_3d().direct_space_state` (602, 770), `navigation_map` (770); `level.lifts.creature_car(stage)` (344); `level.ledger.since_sign` (572); `level.sanity` no se usa; `level.match_net.world_sound` (774, 791); `level.world_audio.play_at` (773, 790).
- De la criatura: ver el contrato en 4.5. Lo que el director usa: `is_hostile`, `noticing`, `grace`, `control`, `in_transit`, `activity()`, `global_position`, `rng`, `accepts_leads`, `lead_to`, `investigate`, `forced_after`, `earned_rest`, `travel_metres`, `searched_lately`, `watched`, `quarry`, `is_wary`, `is_hunting`, `dull` (escribe).
- De los supervivientes: `hidden`, `global_position`, `velocity`, `camera` (para cruzar la mirada), `burnt`, `name`, `slot`, `hiding_place` (cuando está escondido).

### 10.2 Salidas

- Pistas a la criatura: `it.lead_to(point, radius, seconds, kind, once, avoid_rooms, sniff)` (`pacing_director.gd:854` y 519). Tipos (`kind` en la UI y el registro): "merodea" (prowl), "emboscada" (ambush), "pasa" (pasa por el pasillo), "retirada" (retreat), "golpes" (raps), "cruce" (cross), "quieto" (quieto), "vuelve", "entre bastidores" (backstage), "distracción", "cordura", "encuentro".
- Sonidos a la red y al local: `match_net.world_sound(sound, point, db, 0.0)` (774 y 791). Sonidos: `door_raps_1.wav`, `door_raps_2.wav` (110), `object_fall_1.wav`, `object_fall_2.wav` (111).
- Encuentro forzado: `it.investigate(point)` (775).
- Historial: `decided` (signal, 114, 867) y `history` (138, 866). El observador escribe en su registro (869-870).
- Estado: `status_lines()` (880-889) para el panel del observador.

### 10.3 Cifras (ruta:línea)

- Fases: `enum Phase { BUILD, PEAK, RELIEF }` (56); nombres "acecho", "pico", "respiro" (57).
- Pistas: `LEAD_EVERY` (25, 40) (59); `PROWL_START` 40 (62); `PROWL_STEP` 5 (63); `PROWL_MIN` 18 (64); `PROWL_MIN_DARK` 24 (65); `DEATH_EASE` 8 (67); `DEATH_MEMORY` 300 (68); `LEAD_RADIUS` 12 (70); `LEAD_TIME` 40 (71).
- Amenaza: `MENACE_FAR` 45 (74); `MENACE_NEAR` 12 (75); `HOSTILE_MENACE` 1.3 (76); `MENACE_RISE` 0.2 (77); `MENACE_EBB` 0.05 (78); `PEAK_MENACE` 0.7 (79); `PEAK_NEAR` 20 (80); `PEAK_MAX` 25 (81); `PEAK_MAX_TENSE` 15 (82).
- Descanso: `REST_AFTER_CHASE` 30 (84); `REST_AFTER_DEATH` 45 (85); `REST_AFTER_RESTART` 60 (86).
- Alejarse: `BACKSTAGE_MIN` 45 (89); `BY_THE_WAY` 12 (90).
- Reglas duras: `CLEAR_STRAIGHT` 10 (93); `CLEAR_WALK` 12 (94); `CLEAR_HIDDEN` 8 (95) más `LEAD_RADIUS` 12 (833).
- Distracción: `DISTRACT_NEAR` 16 (98); `DISTRACT_FAR` 35 (99); `DISTRACT_REST` 45 (100).
- Cordura: `BURNT_EVERY` (30, 45) (102); `BURNT_RADIUS` 14 (103).
- Quieto: `STALL` 60 (105).
- Retirada: `DOUBLE_BACK` 0.4 (107); `DOUBLE_BACK_AFTER` (20, 30) (108).
- Carga (`strain`): `STRAIN_HUNT` 1/25 (179), `STRAIN_NEAR` 1/60 (180), `STRAIN_HIDE` 1/30 (181), `STRAIN_EBB` 1/90 (182), `STRAIN_FULL` 0.85 (185), `STRAIN_SOME` 0.35 (186), `HIDE_NEAR` 20 (187), `STRAIN_KEPT` 0.25 (189), `REST_HEARING` 0.5 (191).
- Cruces: `CROSS_NEAR` 15 (194), `CROSS_FAR` 32 (195), `CROSS_SIGHT` 30 (196), `CROSS_REST` 30 (197).
- Encuentros forzados: `FORCED_TIME` 40 (203), `FORCED_RETRY` 5 (204), `FORCED_REFRESH` 8 (205), `FORCED_AHEAD` 6 (206), `FORCED_LEADABLE` 8 (211), `LONELY_CAP` 30 (212).
- Perfil de dificultad (`tune`, 224-240), claves: `lead_every`, `prowl_min`, `peak_max`, `peak_tense`, `rest_chase`, `rest_death`, `death_ease`, `double_back`, `distract_rest`, `burnt_every`, `encounter_every`, `cross`, y opcionales `calm` (0), `solo_ease` (1.0), `ambush` (2.0). Los valores vienen de `game/floors/difficulty.gd` (no leído).
- Semilla: `hash([seed_value, "director"])` (217). Los primeros valores: `next_lead` y `burnt_next` (218-219).

### 10.4 Fases y transiciones

- BUILD (`tick` 406-426): cada `LEAD_EVERY` s, una pista con la siguiente de la lista `moves` (construcción de `build` 622-669): "merodea" 3.0, "emboscada" `ambush_weight` 2.0, "pasa" 1.5, "retirada" 1.0, "golpes" 0.7, y "cruce" si `cross_weight` > 0. No repite la última (642-643). Si el equipo lleva `STALL` = 60 s sin entrar en una sala nueva, "quieto" 3.0 o "golpes" 1.0 con calma. La cercanía baja `prowl` en `PROWL_STEP` cada pista (669) hasta `nearest_prowl()` = `prowl_min` (o `prowl_min_dark` en oscuridad) + `death_ease` * muertes (451-452).
- PICO (`tick` 393-399): cuando `menace >= PEAK_MENACE` o `nearest_walk() < PEAK_NEAR` (408). Sale si pasa `peak_limit()` (447-448, `PEAK_MAX` o `PEAK_MAX_TENSE` si está a oscuras o hay muertes), o si la criatura se aleja (395-399).
- RESPIRO (`rest`, 268-274): pasa a RELIEF durante `seconds` desde el reinicio, muerte o la caza. En RELIEF: `backstage()` (718-720) y `distraction()` (757-777). Termina con `clock >= rest_until` (400-405).
- Caza: `hostile()` pasa a PEAK (378-380); al acabar, `breathe(rest_chase)` (381-383).
- Crece `menace` (463-473) y `strain` (296-303). Un descanso por carga (`calm > 0`) paga `STRAIN_KEPT` (287).

### 10.5 Rutinas

- `pick_target` (478-489): puntúa a los vivos que no están escondidos por distancia de paseo, `minf(reach, 90) + rng.randf_range(0, 25)`.
- `forced_due` (498-530): tras `forced_after()` sin contacto, lleva a la criatura al cuarto de un superviviente solo (`lonely_target`, 536-552). Los que están escondidos, y sus vecinos, se evitan (510-517).
- `cross` (594-619): busca salas a 15 a 32 m de paseo que el superviviente pueda ver (`CROSS_SIGHT` 30). Prefiere delante de su mirada (dot > 0.5, 615).
- `encounter_due` (566-586): si un superviviente lleva más de `encounter_every * spacing()` sin signo de la criatura (`ledger.since_sign`), la cruza por su vista.
- `retreat` (710-715): aleja a la criatura y, con probabilidad `double_back`, la vuelve a traer 20 a 30 s después.
- `burnt_lead` (798-815): cada 30 a 45 s, si alguien tiene la cordura quemada, la criatura va a una sala cercana (no la suya) y abre un armario (`play("cordura", ..., sniff = true)`).
- `validate_lead` (821-835): sala de la misma ala, fuera de límites (protegidas), sin la de nadie, a 10 m en línea recta y 12 m de paseo, a 20 m (8 + 12) si el superviviente está escondido; y no revisitar salas registradas (`searched_lately`), salvo al volver de una retirada (`validate_lead(back, true)`) y en los cruces (`cross`, 611).
- `far_lead` (726-752): sala lejos del equipo y de su camino a 45 m o más, sin pasar por ellos.

### 10.6 Estado y deshacer

- `tick` (373-426) corre en `_physics_process` (242-247), con el reloj acumulado (`clock`), no con el de la pantalla.
- No se guarda en `floor_save` (16-18 de `floor_save.gd`). Tras volver, la mente del director empieza de cero.

## 11. Argumentos de línea de órdenes que acepta app

| Argumento | Dónde se lee | Qué hace |
|---|---|---|
| `--test-profile` | `hotel_main.gd:195`, 212, 216 | Modo de prueba: ficheros propios en `user://`; con `--perf-log`, sin script ni automatización, muestra la traza (`settings.trace_display`, 222). |
| `--profile-tag=<tag>` | 205 | Sufijo de los ficheros de prueba. |
| `--perf-log=<fichero>` | 218 | Traza de rendimiento (solo con `--test-profile`). |
| `--perf-seed=<n>` | 219-221 | Semilla de la primera partida nueva (0 a 2147483647). |
| `*.gd` como argumento | 198-201 | Proceso con script: ficheros propios, sin pantalla de título, `scripted = true`. |
| `--automation` | 296, 1179, 1600 y otros | Automatización: sin audio del mundo (297), sin intro (347), sin tarjeta de sector (1005) y sin espera de esa tarjeta (1007). |
| `--background` | 1179 | Con `--automation`: el ratón no se captura. |
| `--silent` | 297, 997 | Sin audio del mundo ni música de ambiente. |
| `--observer` | 362, 347 | Observador: se une a una sala o construye un piso propio. |
| `--address=<ip>` | 454 | Dónde llamar al observador (por defecto 127.0.0.1). |
| `--port=<n>` | 455 | Puerto del observador. |
| `--bots-replay=<carpeta>` | 343 | Repaso de una partida de bots (no viene en el juego exportado). |
| `--bots-at=<s>` | 344 | Segundo del repaso. |
| `--bots-watch` | 345 | Bots jugando piso tras piso, en el observador. |
| `--bots-hunt` | 346 | Bots contra la criatura controlada por este equipo. |
| `--bots=<n>` | 404 | Número de bots (1 a 5; por defecto 3, o 5 en caza). |
| `--seed=<n>` | 405 | Semilla de los bots (por defecto 81). |
| `--knowledge=<modo>` | 406 | Conocimiento de los bots (por defecto "discover"). |
| `--mercy` | 402 | Misericordia para los bots. |
| `--steam-host` | 357 | Crea sala de Steam nada más arrancar. |
| `--playtest-seed=<n>` | 359-361 | Semilla de una partida de prueba (0 a 2147483647). |
| `--locust` | 368 | Con semilla: partida local con la criatura en manos del jugador. |
| `--floor=<n>` | 693-699 | Número del piso que se juega (1 por defecto). |
| `--creature=<clave>` | 686-690 | Criatura en vez de la del piso: `locust`, `lurker`, `none`. |
| `--stage=<n>` | 706 | Sector al que se llega nada más empezar (0 por defecto). |
| `--jumps` | 709 | F9 salta al siguiente sector (solo alone, vivo, sin paseo en curso). |
| `--no-enemy` | 1548 | Desactiva la criatura (pruebas de arquitectura). |
| `--no-warmup` | 938 | No precalienta los pipelines de sombreado. |

- Teclas de depuración: F8 marca en la traza (`_input` 1859-1861); F9 llama a `session.capture(player.slot)`, que da por muerto al jugador, solo en build de depuración y fuera de red (1893); con `--jumps`, F9 salta de sector (1866-1868); F11 abre los ajustes de ventana (1894-1909).

## 12. Cifras que definen cómo se siente y se ve (ruta:línea)

### 12.1 hotel_main.gd

- `TITLE_AMBIENT` 0.03 (:45); `SKIP_HOLD` 0.8 (:47); `INTRO_ORIGIN` (600, 0, 0) (:42); `TITLE_ORIGIN` (-600, 0, 0) (:43).
- `OBSERVER_WAIT` 2.5 (:420); `OBSERVER_KNOCK` 3.0 (:439).
- `REWIND_TIME` 1.4 (:757); `KEEP_EVERY` 30.0 (:803); `POWER_BACK` 1.6 (:1395).
- Refugio: `point_in_refuge` usa un margen de 0.55 m a cada lado y una altura de -0.1 a 2.0 m (:1522).
- Ambiente: -17 dB base, -9 dB por la angustia (:1820); tema -24 dB (:1825).
- Visibilidad: ronda cada 0.25 s (:1832); `hotel.probes_at_once` = 1 (:1848); ventilación en cuadrícula de 12 m (:1854).
- Posición del jugador tras construir: (0, 0.04, 0) (:874); al empezar la partida, (1, 0.06, 3.8) (:334).
- Bots: semilla 81 (:402); 3 bots, o 5 en caza (:402).
- `HUNTER_WARDROBE_RADIUS` = `HEARD["wardrobe_hunter"] / HEARING_SCALE` (:1132).

### 12.2 capture_score.gd y estilos

- Locust (`capture_score.gd`): las cifras de 5.2 (ver 5.2 arriba) y `LIE_ROOM` 1.4 (:75), `FLAT` 1.57 (:79), `SEAT_HEIGHT` 0.13 (:81).
- Lurker (`lurker_score.gd`): `FALL_SINK` (0.5, 0.66) (:39), `FALL_BACK` (0.62, 0.88) (:40); `GLANCE_FROM` 4.4 (:42), `GLANCE_COCK` 4.68 (:43).
- `lurker_capture.gd`: `HIGH_ROOM` 3.0 (:20), `HANG_BEHIND` 0.45 (:23), `CEILING_REACH` 2.6 (:24), `STOOP` 0.25 (:26), `TILE_FROM` 0.2 (:28), `TILE_OPEN` 0.2 (:29), `TILE_SWING` 0.45 (:30), `SWING_TILE` y `HANG` = true (:17-18).
- `locust_capture.gd`: `KILL_BLOW` (:22); `approach`: distancia y giro (41-54).

### 12.3 executions.gd

- `LOST_HOLD` 2.6 (:77); `GLANCE_ALONE` 3 (:81); `GLANCE_TEAM` 6 (:82); `GLANCE_BY` 2.0 (:85).
- Linterna que cae: `TORCH_FALL` 0.5 (:113); `TORCH_SPILL` (0.3, 1.2) (:115); `TORCH_ROLL` 1.15 (:116); `TORCH_TURN` 1.5 (:117).
- Vibración: (0.5, 0.9, 0.7) (:299), (0.2, 1.0, 0.35) (:359), (0.3, 0.5, 0.2) (:367).
- Sonido de caída del cuerpo: -7 dB, `pitch` 0.74 (:366); golpe del cuerpo a `FALL_LENGTH * 0.85` (:364).
- Escala de la linterna: `spill.light_energy` = 0.3 (`TORCH_SPILL.x`) y `omni_range` 1.2 (660-661), `omni_attenuation` 1.6 (662); tubo de 0.17 m, radio 0.028 y 0.02 (670-674); cristal de 0.025 m de radio (686-697).
- Atenuación de la luz caída: `distance_fade_begin` 20 m y `distance_fade_length` 6 m (650-652).

### 12.4 death_tape.gd

- Ya en el apartado 6 (`:30-127`). Además: `LAMP` (:87-90), `HISS_DB` -33 (:95), `SOFT_DB` -8 (:99), `CLEAR_OF_HEAD` 0.5 (:126), `SHOWN_AFTER` 0.5 (:127), `MIC_LOW` 120 (:66), `MIC_HIGH` 6500 (:67), `AGC_*` (:68-71).

### 12.5 blood.gd

- `GRAB_DB` -12.5 (:40); `SPRAY_DB` -6.0 (:41); `WELL_DB` -10.0 (:42); `WELL_FADE` 3.5 (:43).
- `SOLID` 1 (:51); `GRAVITY` 9.8 (:52); `FLIGHT` 1.5 (:54); `STEP` 0.04 (:55).
- Manchas: `ROUND` 0 a 7 (:58), `SLANTED` 8 a 13 (:59), `RUNS` 14 y 15 (:60); `SLANT` 0.8 (:63); `MOST_DRAWN` 3.2 (:64); `RUN_PACE` 0.07 m/s (:66).
- Charco: `POOL_SPAN` 1.5 (:70), `POOL_RADIUS` (0.36, 0.5) (:71), `POOL_TIME` 30 (:72); 16 rayos alrededor (:378).
- Número de gotas: 16 al agarre (:209); de 0.35 s hasta `DROP_TIME` (:213-217); 54 al golpe (:223); 9 de la hoja (:228); 4 borbotones de 7 a 4 gotas (:235-239).
- `SETTLED` 70 (:74); `LENS_REACH` 1.7 (:77).
- Multimalla: 4 canales personalizados por mancha: (celda, nacimiento, carrera, empapado) (:356).

### 12.6 camera_fall.gd

- `DIRECTIONS` 16 (:31); `RADII` (0.9, 1.5, 2.2) (:32); `CLEARANCE` 0.12 (:35); `SOLID` 1|8 (:36); `ANY_LEAF` 1|8|64|128 (:37); `FLOOR_SLACK` 0.2 (:40); `KEEP_OFF` 0.45 (:43); `KEEP_BODY` 0.4 (:44); `DARK_REACH` 1.05 (:47).
- Posición en el suelo: `LENS_SIDE` (-1: 0.076; 1: 0.034) (:52); `LENGTH` 0.27 (:53); `PITCH` (8, 20) (:54); `ROLL` (-1: 80 a 102; 1: 56 a 78) (:58).
- Caída: `GRAVITY` 9.8 (:64); `TOSS` (0.2, 0.9) (:65); `HOP` (0.05, 0.09) (:66); `HOP_KEEP` 0.5 (:67); `AIR_LEAST` 2.0 (:68); `HOP_TURN` (100, 190) (:69); `SECTION` (0.055, 0.06) (:74); `STEP` 0.115 (:75); `KNOCK_TIME` (0.15, 0.2, 0.3) (:76); `KNOCK_SLOW` (0.3, 0.86) (:77); `ROCK` 0.36 (:80); `ROCK_ANGLE` 5 (:81); `ROCK_RATE` 6.5 (:82); `ROCK_FADE` 0.1 (:83).
- Campo de visión de la cámara: `VIEW_HALF` 39 grados (:86); `AIM_SPREAD` 26 grados (:89); `UP_PITCH` (55, 84) (:25); `UP_ROLL` 18 (:26); `UP_REACH` 1.2 (:27).
- Cuadrícula de encuadre: 5 columnas por 3 filas (249-250); rayos de 0.7 m (255).
- Sonido de caída: `blows` (491-495): 1.0 al suelo, 0.5 al rebote, y 0.34 - 0.06 * i en cada canto.

### 12.7 presentation_rig.gd (lo que se ve)

- `ambient_energy` 0.16 (:13) (se toma de `environment` al construir, :37).
- `LIT_FOG_LENGTH` 14.0 (:20).
- Cámara HDR: tonemap lineal y exposición 1.0 con la cámara encendida (80-81); umbral de bloom 0.9 (82).
- Campo entrelazado: `FIELD_TIME` 1/60 (:104), `FIELD_FROM` 12 px (:106), `FIELD_TO` 30 px (:108), `FIELD_MAX` 48 px (:110); altura de referencia 1080 px (127).
- Lente: `vignette` 0.45 (:145, 304); `detail` 0.35 (:146); `noise` = `settings.grain` (:143); `chromatic` = `settings.chromatic` (:144).
- Tinte de la cinta: (1.02, 1.0, 0.9) (:308); en la vista de la criatura, sin tinte (1, 1, 1).
- Ruido de la cinta en pantalla: `static_level` sube 14/s y baja 1.6/s (:386).
- Cinta: `frayed` = `clamp(1 - sanity/SANITY_UNEASY + glitch, 0, 1)` (:398); `vhs` * (1 + frayed*1.6) (:399); `chromatic` * frayed * 0.7 (:400).
- Música: `MUSIC_CUT` 0.12 s (:486), `MUSIC_RETURN` 2.0 s (:488).
- Sonidos: papel -8 dB (:421); grito en la capa Threat (:427); estático -2 dB (:436); siseo del viaje -80 dB base, `RIDE_HISS_DB` -20 (:406, 442); ambiente -17 (:449); tema -24 (:460); ventilación -19, distancia máxima 16 (:468-469); música de menú -12 (:477).
- Sombras: tamaño del atlas según el preajuste, topado en 4096 en Compatibility (:260-261; `COMPAT_SHADOW_ATLAS` en :201). Profundidad: `positional_shadow_atlas_16_bits = not compatibility` (:267), es decir, 16 bits fuera de Compatibility. El comentario de :262-266 dice 32 bits; el código y el comentario no coinciden (ver apartado 17).
- Opciones del entorno (`apply_settings`, 214-319): SSAO, SSIL, SSR, SDFGI desactivado (234-235), glow, bicúbico, GI a media resolución, niebla volumétrica, filtro de niebla, sombras de la luz de la linterna (311), antialias SMAA o FXAA o nada, TAA (277), `mesh_lod_threshold` (278), `anisotropic_filtering_level` (280), `use_debanding` (281), limitador de rugosidad (282), `surface_detail` global (285).
- Cámara en la pantalla: `apply_lens` (135-152) y `update_zoom_lens` (161-181) con el `fov` del zoom (177-181); la lente solo se ve con `LOOK.lens` y no en observador (141).

### 12.8 interaction.gd

- `HIDE_TAP` 0.28 s (:55); `DOOR_REACH` 2.4 m (:174); `DOOR_BEHIND_REACH` 2.0 m (:178); `SLOW_HOLD` 1.0 s (:181).
- Corriendo empuja la puerta con golpe si la velocidad supera 4.6 m/s (393).
- Subtítulo fijo "[Ventilación constante]" entre 5 y 10 s de partida (402-403).

### 12.9 lifts.gd

- `LIFT_RETURN` 15 (:66); `CREATURE_WAIT` 15 (:79); `CREATURE_HOLD` 20 (:80); `CROSS_AIM` 2.5 (:174); `RIDE_REACH` 1.4 (:241); `RIDE_SLACK` 0.5 (:248); `RIDE_SHUT` 1.7 (:449); `RIDE_DESCENT_AT` 0.8 (:450); `RIDE_BELL` 7.3 (:451); `RIDE_OPEN` 7.7 (:452); `RIDE_TIME` 8.5 (:453); `RIDE_BLIND` 0.35 (:454); `LEAVE_TIME` 4.0 (:457); `RIDE_CARD` 0.2 (:462); `OPENING_CARD` 2.6 (:465); `LADDER_DROP` 1.4 (:549).
- Puertas: `DOOR_CLOSING` 1.7 (:365), `DOOR_OPENING` 1.6 (:366), `DOORS_HEARD` 0.2 (:367), `DOORS_ONCE` 0.6 (:345); volúmenes `DING_GAIN` 0 (:209), `DOORS_GAIN` -4 (:210), `DESCENT_GAIN` -6 (:211).
- Primer aviso: `FIRST_BRIEF` (:50) y `FIRST_HOLD` 11.0 (:51).

### 12.10 televisions.gd, code_lock.gd, floor_map.gd, sanity.gd, phantom_*, revival.gd, run_ledger.gd, observer_*.gd, pacing_director.gd

- `televisions.gd`: `WARP_REACH` 3.4 (:91); `TV_BURST_GAIN` -6 (:64); `HOP_REST` 25 (:177); `HOP_PATIENCE` 4 (:179); `HOP_CLEAR` 12 (:181); salto con -6 y -4 dB (150-151).
- `code_lock.gd`: `PANEL_DB` -10 (:227); `KNOB` (1.16, 1.25, 0.078) (:268); foto: `PHOTO_SIZE` 512 (:309), `PHOTO_BACK` 2.2 (:310), `PHOTO_EYE` 1.45 (:311), 58 grados de campo (:329), luz de flash 2.4 con alcance 7 (:333-334); colores de marcas (:18-20).
- `floor_map.gd`: `PIECE` 0.7 m (:17); `LOOK_EVERY` 0.15 s (:23); `ARC` 90 grados (:24); `RAYS` 55 (:25); `REACH_LIT` 15 m (:26); `REACH_TORCH` 12 m (:27); `REACH_DARK` 3 m (:28); `SNAP` 0.35 m (:30); `FORGET` 180 s (:32); `GRID` 2.0 m (:35).
- `sanity.gd`: §9.1.
- `phantom_sight.gd`: §9.6.
- `phantom_passage.gd`: §9.5.
- `revival.gd`: `RESTART_DEN` 45 (:49), `RESTART_GRACE` 12 (:51), `LIFT_AWAY` 0.9 (:130), `AT_HEAD` 0.5 (:311).
- `run_ledger.gd`: `ENCOUNTER_GAP` 20 (:54); `SIGN_EVERY` 0.25 (:55); `CHASE_LEAST` 3 (:58); `LOOSE_WAIT` 10 (:60); `ESCAPE_TOLD` 8 (:62); `STRIDE_MOST` 9 (:64); `RUNNING` 4.8 (:65); `CALL_REST` 15 (:159).
- `observer_view.gd`: `SPEED` 22 (:76); `SPEED_RANGE` (2, 200) (:77); `QUICK` 4 (:79); `MAP_HEIGHT` 150 (:81); `LOG_KEPT` 16 (:83); cámara `far` 400 (:140), `fov` 75 (:141); luz 1.1 o 2.2 (:157, 451); ambiente 0.4 o 1.4 (446); posición de la cámara de la lectura: `Ears.ARM` 2.8 (:50), `SHOULDER` 1.0 (:51).
- `observer_gizmos.gd`: `TRAIL_TIME` 12 (:21); `TRAIL_EVERY` 0.25 (:22); `NOISE_TIME` 2.5 (:24); colores (:25-50).
- `session_perf.gd`: `SLOW_US` 50000 (:5); `DETAIL_US` 2000 (:6); `SAMPLE_US` 250000 (:7); `HEARTBEAT_US` 500000 (:8); `MAX_PENDING` 8192 (:9).
- `pacing_director.gd`: §10.3.
- `discovery_catalog.gd`: `TOTAL` 16 (:10) frente a 4 entradas en `ENTRIES` (11-44), todas de `creature` "locust" (:13, 22, 30, 38).

### 12.11 lurker_hallucinations.gd y locust_hallucinations.gd

- §9.3 y §9.4 arriba. Colores de sonido: `CLAW_DB` -10 (:49), `KNOCK_DB` -6 (:50), `PHONE_DB` -8 (:52), `TYPING_DB` -10 (:55), `HISS_DB` -8 (:56), `COPIER_DB` -8 (:57), `CHAIR_DB` -6 (:58), `STARTER_DB` -8 (:59), `LEVER_DB` -4 (:60), `TICK_DB` -10 (:61), `FANS_DB` -6 (:62).

## 13. Motor: clases y nodos que usa esta parte (apariciones aproximadas)

Conteo de líneas que contienen el nombre en el ámbito (`game/app`, `game/director`, `game/discovery`). Un mismo renglón puede contar varias veces. Cifras aproximadas.

| Clase o API | Apariciones | Dónde se nota |
|---|---:|---|
| Node3D | 82 | Base de casi todo lo que está en el mundo. |
| Transform3D | 69 | Pose de cámara, de cuerpo, de manchas. |
| Basis | 62 | Rotaciones de cámara, de caída, de sangre. |
| Input | 55 | Teclas y pad: `is_action_just_pressed("interact")` (11 veces), `is_action_pressed("interact")` (8), `sheet`, `sprint`, `jump`, `crouch`, `get_vector("left"...)`. |
| Performance | 51 | Traza y observador (monitores de FPS, memoria, dibujo). |
| Node | 35 | Tipo base de servicios y de nodos auxiliares. |
| OS | 31 | Argumentos de línea de órdenes (`get_cmdline_user_args`), `is_debug_build`. |
| get_world_3d() | 28 | Espacio físico y de navegación. |
| Camera3D | 28 | Cámara del jugador, de la criatura y de observación. |
| RenderingServer | 25 | Sombras, SSAO, SSIL, SSR, GI, niebla volumétrica, SMAA, filtros, `frame_pre_draw`/`post_draw`. |
| RandomNumberGenerator | 25 | Sorteos seeded y no seeded (apartado 14). |
| Time | 22 | Reloj de pared (`get_ticks_msec`/`usec`), fecha para ficheros. |
| PhysicsDirectSpaceState3D | 22 | Rayos y formas de la física. |
| get_tree() | 20 | Temporizadores (`create_timer`), `paused`, `process_frame`, `physics_frame`, grupos. |
| RID | 19 | Excluir cuerpos de los rayos, sonido de la ruta. |
| PhysicsRayQueryParameters3D | 19 | Rayos de sangre, cámara, cordura, suelo. |
| AudioStreamPlayer | 19 | Sonidos 2D (cinta, grito, papel, estático, siseo, música). |
| MeshInstance3D | 17 | Manchas, cámara caída, gizmos. |
| PackedVector3Array | 15 | Caminos de navegación y de conductos. |
| get_viewport() | 14 | Cámara activa, resolución, sombras. |
| get_ticks_usec | 12 | Trazas y medición de tiempos. |
| ProjectSettings | 12 | `get_setting("rendering/...")` y `globalize_path`. |
| Engine | 11 | `time_scale` (observador), `get_version_info`, `max_fps`. |
| FileAccess | 10 | Ficheros de la traza y del volcado. |
| ShaderMaterial | 9 | Manchas, charco, lente, cinta; parámetros fijados por código cada cuadro. |
| Control | 7 | Paneles del observador. |
| AudioStreamPlayer3D | 7 | Sonidos en el mundo (ventilación, pasos, puertas, conductos). |
| MultiMesh | 6 | Manchas de sangre con 4 canales por instancia (`blood.gd:356`), gotas en el aire. |
| InputEventKey | 6 | Teclas del observador y del piso. |
| AudioServer | 6 | Efectos de bus en vivo (mic de la cinta), volumen del bus de amenaza. |
| StandardMaterial3D | 5 | Materiales de humo, de luz, de la cinta, de la sombra. |
| MultiMeshInstance3D | 5 | Manchas y gotas. |
| BaseMaterial3D | 5 | Constantes de sombreado y transparencia. |
| PlaneMesh | 4 | Charco (`blood.gd:399`). |
| Label | 4 | Textos del observador. |
| DisplayServer | 4 | Nombre del servidor de pantalla (headless). |
| SubViewport | 3 | Foto Polaroid (`code_lock.gd:324`). |
| SpotLight3D | 3 | Linterna de la víctima y de la caída. |
| NavigationServer3D | 3 | Mapa de navegación, iteración, camino. |
| CameraAttributesPractical | 3 | Enfoque y desenfoque de la cámara del jugador. |
| Environment | 3 | Entorno del mundo. |
| CanvasLayer | 3 | Paneles del observador. |
| AABB | 3 | Límites de las mallas. |
| OmniLight3D | 2 | Resplandor de la linterna caída (`executions.gd:658`), destello de la foto. |
| Skeleton3D | 2 | Huesos de la criatura (`lurker_poser.gd:12`). |
| QuadMesh | 2 | Sombra de persiana. |
| CompositorEffect | 2 | Efectos de cámara y de desenfoque (`presentation_rig.gd:59, 63`). |
| AudioStreamWAV | 2 | Bucles de ambiente. |
| AudioEffectAmplify | 2 | Ganancia del micrófono. |
| AnimationPlayer | 2 | Clips "peek", "idle", "loom". |
| ImmediateMesh | 1 | Gizmos del observador (`observer_gizmos.gd:52`). |
| Thread y Mutex | 1 y 1 | Escritor de la traza (`session_perf.gd:11-12`). |
| ENetMultiplayerPeer, ENetPacketPeer | 1 y 1 | Estadísticas de red del observador (`observer_view.gd:603-605`). |
| JSON | 2 | Volcado y traza (`stringify`). |
| GradientTexture2D, Gradient | 2 y 1 | Textura de la sombra de la persiana. |
| Compositor | 1 | `presentation_rig.gd:64`. |
| ColorRect | 1 | Fondo del panel del observador. |
| Geometry2D | 1 | Distancia a segmento (`floor_map.gd:177`). |
| CollisionObject3D | 2 | Cuerpos que se excluyen de los rayos. |
| SphereShape3D, PhysicsShapeQueryParameters3D | 1 y 1 | Espacio libre de la cámara caída (`camera_fall.gd:142-150`). |

Nodos y rutas por nombre:
- `$Services` (14 usos), `$Services/Settings`, `$Services/GameSession`, `$Player`, `$Interface`, `$WorldAudio`, `$Presentation/Analog`, `$Presentation/WorldEnvironment`.
- Rutas en `Presentation`: `Lens`, `Lens/Screen`, `Analog/Screen`, `Camcorder`, `WorldEnvironment` (`presentation_rig.gd:36-53`).
- Grupos: `hotel_hides`, `hotel_documents`.
- Acciones de entrada: `interact`, `sheet`, `left`, `right`, `forward`, `backward`, `jump`, `crouch`, `sprint`. Su definición está en `project.godot` (no leído).
- Constantes de la ruta de nodo: `process_mode` = 0 (heredado), 1 (PAUSABLE), 3 (ALWAYS), 4 (DISABLED), según uso en `hotel.tscn:13`, `hotel_main.gd:290, 492, 949, 1533`, `presentation_rig.gd:447-475`.
- Prioridad de proceso: `blood.gd:87` 90; `death_tape.gd:142` 100.
- Señales de Godot usadas: `connect` (23), `signal` declarada (1: `decided`), `emit` (5).
- Recursos cargados en tiempo de ejecución: 25 `.wav`, 12 `.ogg`, 2 `.mp3`, 1 `.png` (atlas de sangre), 1 `.glb` (`locust.glb`, `hallucinations/locust_hallucinations.gd:17`), 1 `.res` (cámara, `executions.gd:22`), 2 `.gdshader` (`blood.gdshader`, `blood_pool.gdshader`), y 8 `.tscn` (`lurker.tscn`, `lurker_creature.tscn`, `null_creature.tscn`, `locust.tscn`, `player.tscn`, `world_audio.tscn`, `presentation.tscn`, `interface.tscn`).

## 14. Dependencias de orden, física y azar

### 14.1 Tiempo y orden de los bucles

| Qué | Dónde | Por qué importa |
|---|---|---|
| `_physics_process` del nivel | `hotel_main.gd:1595-1659` | Mueve lifts, interacción, cordura, objetivos, la criatura (en la física), el libro. |
| `_process` del nivel | `hotel_main.gd:1774-1852` | Cámara, cinta, pantalla, ronda de visibilidad, volúmenes. |
| `_physics_process` del director | `pacing_director.gd:242-247` | Toda su lógica con el reloj acumulado. |
| `_physics_process` de fantasmas | `phantom_sight.gd:103`, `phantom_passage.gd:121` | Aparición y paso falso. |
| `ride_lifts` con `get_physics_process_delta_time` | `lifts.gd:251` | Tiempo de los viajes. |
| Captura: `update_execution` | `executions.gd:345` (en `step_frame`) | El reloj de la captura va con `delta` de cuadro, no con la física. |
| Cinta: `_process` con `get_process_delta_time` | `death_tape.gd:246-260` | Prioridad 100: después del jugador. |
| Manchas de sangre: `_process` | `blood.gd:440-456` | Prioridad 90. |
| Observador: `_process` | `observer_view.gd:428` | `Engine.time_scale` cambia su ritmo. |
| Marcas del observador | `observer_gizmos.gd:91` | Se redibujan con `get_process_delta_time` (155). |
| Construcción de piso | `hotel_main.gd:836-937` | Espera dos cuadros, dos cuadros de física, hasta 90 cuadros de física y el horneado de luz. Si cambia el orden de la física o de la navegación, cambia si el piso "pasa" la validación. |
| Ronda de visibilidad | `hotel_main.gd:1832-1852` | Una parte por cuadro, en 4 veces por segundo. |
| Tiempo de la cordura y las mentiras | `sanity.gd:236-253`, `lurker_hallucinations.gd:94` | Reloj de pared (`Time.get_ticks_msec`). No es el reloj del piso. |
| Dedupe de puertas | `lifts.gd:346-351` | Reloj de pared, 0.6 s. |
| Televisión: escucha | `televisions.gd:77-85` | Reloj de pared (`hiss_after`). |
| Creación de temporizadores | `lurker_hallucinations.gd:384-385` | `get_tree().create_timer(seconds)`. Se anulan si el nodo muere. |
| Guardado | `hotel_main.gd:1785-1786` | Cada 30 s de juego (reloj de juego). |
| Guardado al pausar | `hotel_main.gd:1223-1228` | Sincrónico. |
| Foto Polaroid | `code_lock.gd:344-350` | Espera a `RenderingServer.frame_pre_draw` y `frame_post_draw` dos veces. |

### 14.2 Azar

Sorteos con semilla (reproducibles entre máquinas):

| Qué | Semilla | Dónde |
|---|---|---|
| Blood (sangre de la captura) | `scene.seed ^ 0xb100d` | `blood.gd:99` |
| Caída de la cámara (encuadre) | `seed` de la captura | `camera_fall.gd:106` |
| Caída de la cámara (ruta) | `seed ^ 0x2545f491` | `camera_fall.gd:362` |
| Linterna caída | `seed ^ 0x51ed` | `locust_capture.gd:190` |
| Semilla de la captura | sorteo del anfitrión `rng.randi() & 0x7fffffff` (o forzada), enviada a todos | `executions.gd:222` |
| Director de ritmo | `hash([seed, "director"])` | `pacing_director.gd:217` |
| Lugar de reinicio de la criatura | `hash([manifest.seed, "restart den", stage, restarts])` | `revival.gd:81` |
| Llave del piso | `hash([manifest.seed, "key"])` | `code_lock.gd:187` |
| Polvo de la cinta | función determinista de `(time, id)` | `death_tape.gd:513` |
| Cuándo entra la criatura por la televisión | `creature.rng` | `televisions.gd:198` |
| Mirada a la lente | `rng.randi_range(1, 3)` solo, o `(1, 6)` en equipo; del anfitrión | `executions.gd:212` |

Sorteos sin semilla (cada máquina tira los suyos):

| Qué | Dónde |
|---|---|
| Mentiras de la cordura: tiempos, azar de cuál, sonido | `sanity.gd:236-253`, `sanity.gd:300` (`randf`, `randi`, `randf_range`). |
| Lugar de la aparición | `phantom_sight.gd:81` (`rng.randomize()`), 83 y 124. |
| Paso falso | `phantom_passage.gd:43` (`randomize`), 99, 135. |
| Mentiras de The Lurker | `lurker_hallucinations.gd:88` (`randomize`). |
| Mentiras de The Locust | `locust_hallucinations.gd:53, 57` (`randi`, `randf_range` globales). |
| Captura: "rng" propio del nodo de ejecuciones | `executions.gd:130` (`randomize`), 94. |
| Posición de llegada en el ascensor | `lifts.gd:299, 302` (`randf_range` global). |
| Sitio de la víctima tras el renacer | `revival.gd:28` (`randf_range` global). |
| Sonido de búsqueda en un cajón | `code_lock.gd:403` (`randi()` global). |
| Semillas de piso nuevo | `hotel_main.gd:452, 555, 562, 564, 566` (`randi_range`). |
| Semilla de observación | `observer_view.gd:239` (`randi_range`). |
| Punto de la mentira en cordura | `sanity.gd:299-302` (`randf`). |

Consecuencia: en una partida en línea, las decisiones de la captura se toman en el anfitrión y se envían; los detalles visuales y sonoros (lugar de la mentira, polvo, sonidos de cajones) son locales y pueden diferir entre máquinas, por diseño (`lurker_hallucinations.gd:3-9`, `locust_hallucinations.gd:4-7`, `phantom_sight.gd:7-12`).

### 14.3 Física

- Rayos y formas: `PhysicsRayQueryParameters3D` (19) y `PhysicsShapeQueryParameters3D` (1) en `camera_fall.gd:142-150`, `blood.gd:250-252, 287, 382`, `phantom_sight.gd:170`, `floor_map.gd:160`, `interaction.gd:145-195`, `sanity.gd:212`, `lurker_capture.gd:101`. El mundo es estático salvo puertas y cuerpos.
- Máscaras de capa de física que aparecen: 1 (suelo, paredes, muebles), 4 (cuerpos de supervivientes, `hotel_main.gd:1036, 1065`), 8 (hojas de puerta cerradas, `hotel_main.gd:890`), 16 (áreas de interacción, `interaction.gd:145`), 64 y 128 (hojas de puerta abiertas o que alguien ocupa, `camera_fall.gd:33-37`, `interaction.gd:186-187`). No aparece la capa 2 de física; sí aparece la capa 2 de visibilidad (`executions.gd:580`, `revival.gd:308-309`).
- Mapa de navegación: `NavigationServer3D.map_set_use_async_iterations(map, false)` (`hotel_main.gd:324`), `map_get_iteration_id` (`revival.gd:84`, `televisions.gd:122`), `FLOOR.navigation_path` y `FLOOR.closest` (ver 3.6, 14.1).
- Cuerpos: `CollisionObject3D` (2 usos); `query.exclude` lleva los RID de la criatura y de los cuerpos (`executions.gd:143`, `blood.gd:288`).
- Colisión de la cámara caída: formas `SphereShape3D` de radio `CLEARANCE` 0.12 (`camera_fall.gd:142-148`).
- Física de caída: la trayectoria es analítica (`camera_fall.gd:360-414` y `blood.gd:249`), no simulada con motor.
- `PhysicsDirectSpaceState3D` se obtiene en cada uso (`get_world_3d().direct_space_state`) y no se guarda.

### 14.4 Red y autoridad (lo que cambia el orden)

- El anfitrión decide: `capture_survivor` (`executions.gd:179-197`), `stage_capture` (201-232), `session.capture` (401), `tell_lens` (552) → `settle_lens` (556), `execute_start.rpc` (193), `hide_forced.rpc` (`hotel_main.gd:1477`), `use_*` y `world_sound` (desde `interaction`, `televisions`, `code_lock` y el director).
- Las cosas visuales y sonoras corren en todas las máquinas: `apply_execution` (261-323), `update_execution` (345-375), `blood.begin` (289), `camera_fall.solve` (solo en la víctima, `death_tape.gd:237`) y `camera_fall.route` (en los que miran, `executions.gd:604`).
- Un invitado no hace el sentido común de la partida: `if net.is_client(): return` en varios puntos (ver 4.4).

## 15. Cadena de imagen y sonido (hechos)

Orden, de dentro afuera, de lo que se ve en pantalla cuando se juega al hotel. Todo lo de abajo está en el código de `game/app` o lo llama.

1. Modelo: cuerpo, criatura y mobiliario ya en el mundo (`hotel_geometry.gd`, no leído).
2. Luces: lámparas de cada sala que apaga `hotel.lit()` y `flicker_one` (`hotel_main.gd`; `lurker_hallucinations.gd:349`).
3. Linterna: `SpotLight3D` del jugador con `shadow_enabled` según ajustes, `light_size` por penumbra (`presentation_rig.gd:311-313`), y niebla volumétrica `light_volumetric_fog_energy` por el grado del piso (343).
4. Entorno (`Environment` de `Presentation/WorldEnvironment`): ambiente 0.16 o 0 (`presentation_rig.gd:13, 242`), niebla de profundidad apagada por el observador (`observer_view.gd:449`), SSAO y SSIL según ajustes (223-228), SSR (230-233), SDFGI siempre apagado (235), glow con umbral 0.9 con cámara (82), niebla volumétrica (244-251).
5. Cámara de cinta (`CompositorEffect` `camera_effect`): HDR, iris y compresión (`camcorder_effect.gd`, no leído), con la tonemap lineal (80-82). Desenfoque de movimiento con `blur_effect` (`motion_blur_effect.gd`, no leído), con `samples` 0 si hay efectos reducidos (76-77).
6. Lente (`Presentation/Lens/Screen`, `lens_material`): `barrel`, `scale`, `noise`, `chromatic`, `vignette` 0.45, `detail` 0.35, `gain_map` (la ganancia de la cámara), y `field_shift` del entrelazado (`presentation_rig.gd:131, 143-146, 177-178, 85`).
7. Pantalla de la cinta (`Presentation/Analog/Screen`, `post_material`): `vhs`, `scanlines`, `grain`, `chromatic`, `vignette`, `tint`, `enclosure`, `chroma_taps`, `lite`, `signal_loss`, `tape_hit`, `tape_band`, `tape_fray`, `lens_blood`, `lens_seed`, `lens_down`, `rewinding`, `signal_loss` (`presentation_rig.gd:286-308, 387, 392-400`; `death_tape.gd:439-450`; `hotel_main.gd:783, 789`).
8. Sangre: `MultiMeshInstance3D` de manchas con `blood.gdshader` y charcos con `blood_pool.gdshader`, con `clock` y `age` fijados en cada cuadro (`blood.gd:452-453`), y gotas en el aire como `MultiMesh` (`blood.gd:415-438, 459-485`).
9. Gizmos del observador: `ImmediateMesh` de líneas sin profundidad y con prioridad 120 (`observer_gizmos.gd:75-85`).
10. Sonido: `AudioServer` bus 0 con efectos del micrófono en la cinta (`death_tape.gd:532-549`); buses "Threat", "Effects", "Ambience", "Music" (`presentation_rig.gd:425-476`, `death_tape.gd:145, 518`); pistas 2D y 3D con rutas de sonido propias (`world_audio.gd`, no leído).
11. Pipelines: precalentamiento de sombreado en la carga (`WARMUP.run(self)`, `hotel_main.gd:940`), que también precalienta la cámara caída y la sangre (`executions.gd:707-714`, `blood.gd:517-544`).

Sonidos que app dispara, por nombre de recurso (ver 14.2 para el azar): grito `execution_scream.wav`; golpe `execution_hit.wav`; estático `execution_static.ogg`; los cuatro chorros de sangre `blood-gush-1..4.ogg`; el borbotón `hemorrhage.ogg`; los pasos `chase/grunts.ogg`; `intro/stomp_1..3.wav`; `paper/paper.ogg`; `events/object_fall_1..2.wav`; `intro/bed_shift.wav`, `intro/bed_stir.wav`; ascensor `lift/doors_close.wav`, `descent.wav`, `doors_open.wav`, `bell.wav`; `office/ladder.wav`; `wardrobe/opening1.ogg` (panel); `sfx/lurker/bite_1.wav`, `bite_2.wav`, `cue_*.wav`, `scare_*.wav`, `presence.wav` (estos últimos, prohibidos para mentiras, `lurker_hallucinations.gd:40-43`).

## 16. Pruebas que vigilan esta parte

Pruebas en `tests/` que cargan código de `game/app/`, `game/director/` o `game/discovery/` (por ruta o por nombre). Las filas marcadas «inferido del nombre» o «cabecera no leída» no se han leído por dentro; su relación con esta parte viene de la búsqueda de rutas:

| Prueba | Qué vigila (de su cabecera) | Archivos de app que toca |
|---|---|---|
| tests/hotel/creature_contract_test.gd (2079 líneas) | Contrato de la criatura (The Locust) en cada modo; red; `teleport()`; la criatura es su locust. Mantiene la captura del Locust con las cifras antiguas. | Casi todos: `executions`, `capture_score`, `locust_capture`, `death_tape`, `blood`, `floor_save`, `lifts`, `televisions`, `revival`, `run_ledger`, `sanity`, `presentation_rig`, `phantom_*`, `observer_*`, `interaction`, `hallucinations`, `pacing_director`. |
| tests/hotel/capture_test.gd (801) | La partitura, cómo se elige a la víctima, la escena en su reloj, la cámara en la cinta, la máscara bien orientada, una muerte al final. | `blood`, `camera_fall`, `capture_score`, `executions`, `death_tape`. |
| tests/hotel/continue_test.gd (202) | Continuar devuelve el piso como se dejó. | `floor_save`. |
| tests/hotel/observer_test.gd (117) | El observador: R, Mayús+R, planta, no hay juego de nadie. | `observer_view`. |
| tests/hotel/loop_test.gd (293) | Director y documentos (placement, lectura y archivo). | `pacing_director` (via nivel), `discovery_catalog`. |
| tests/hotel/sanity_test.gd (323) | La cordura: baja en la oscuridad, sube con luz, miente bajo `UNEASY`, marca al cuerpo. | `sanity`. |
| tests/hotel/difficulty_test.gd (445) | Las dificultades: "desafiante" es el juego de antes; cada palanca en su sentido; el piso las hereda. | `lifts`, `televisions`, `pacing_director`. |
| tests/hotel/objectives_test.gd (208) | Los objetivos como manejadores y el contrato de su lógica con `floor_save`. | `floor_save`, `lifts`, `hotel_main`, `pacing_director`. |
| tests/hotel/echo_test.gd (504) | La lectura acústica de la criatura. | `observer_view` (indirecto). |
| tests/hotel/intro_test.gd (69) | Escena de apertura: se salta y entrega la vista. | `hotel_main`. |
| tests/hotel/rules_test.gd (185) | Las reglas de la sala (mercy, código, plano, cordura, onslaught, luz del tv). | `hotel_main`, `pacing_director`, `televisions`. |
| tests/hotel/stages_test.gd (847) | Un piso son tres sectores encadenados. | `hotel_main`. |
| tests/hotel/survival_test.gd (691) | Supervivencia del jugador en el piso (inferido del nombre; cabecera no leída). | `hotel_main`, `sanity`, `interaction`. |
| tests/hotel/manifest_golden_test.gd (39) | Los pisos del hotel salen byte a byte iguales (50 semillas por número de supervivientes). | No toca app directamente. Es la guarda del piso 1. |
| tests/hotel/creature_test.gd, scene_contract_test.gd, hotel_audio_test.gd, spatial_audio_test.gd, room_light_test.gd, palette_scan_test.gd, hotel_walkthrough.gd, hotel_batch.gd, hotel_test.gd, loop_test.gd, bots_test.gd | Varios aspectos del hotel (cabeceras no leídas; solo se sabe qué piezas del hotel cargan). | Parcial (`hotel_main`, `interaction`, `blood`, `code_lock`). |
| tests/net/net_test.gd | Que las reglas y la dificultad lleguen a los invitados (según las cabeceras de difficulty_test.gd y rules_test.gd). | Indirecto. |
| tests/office/lurker_capture_test.gd (129) | La captura de The Lurker en el piso 2. | `lurker_capture`, `lurker_score`, `capture_score`. |
| tests/office/lurker_forced_test.gd (136) | Encuentros forzados de The Lurker (`forced_after`). | `pacing_director` (indirecto). |
| tests/office/lurker_observer_test.gd (161) | Marcas del observador de The Lurker y su paquete de doce. | `observer_gizmos`. |
| tests/office/lurker_fairness_test.gd, lurker_senses_test.gd, lurker_tiles_test.gd, lurker_bots_test.gd | Justicia, sentidos, baldosas y bots de The Lurker (inferido del nombre). | `lurker_capture`, `lurker_hallucinations`, `sanity`. |
| tests/office/office_lies_test.gd | Mentiras de The Lurker en el piso 2 (inferido del nombre). | `lurker_hallucinations`, `sanity`. |
| tests/office/descend_test.gd, jump_test.gd, office_*_test.gd | Bajada, salto, luz, audio y cuerpos del piso 2 (inferido del nombre). | Parcial (`hotel_main`, `lifts`, `code_lock`). |

Regla del proyecto (CLAUDE.md): `manifest_golden_test` y `creature_contract_test` vigilan el piso 1. Las pruebas de Godot se ejecutan con `--headless` y `--test-profile` (`CLAUDE.md`, reglas del proyecto). Este encargo no las ejecutó.

## 17. Hechos que complican el port

- Las decisiones de captura y de mente se toman en el anfitrión y se mandan por red con RPC de Godot (`executions.gd:193`, `hotel_main.gd:1477`, `revival.gd:181`, `televisions.gd:202`, `executions.gd:552, 560`). Los detalles se recalculan en cada máquina con sorteos de Godot y con la física de cada máquina.
- Cadena de sorteos de Godot: `RandomNumberGenerator` con semilla (`seed`), `hash()` de GDScript sobre arrays (`pacing_director.gd:217`, `revival.gd:81`, `code_lock.gd:187`), y operaciones XOR con constantes (`blood.gd:99`, `camera_fall.gd:362`, `locust_capture.gd:190`). Reproducir las mismas cifras exige la misma función de azar y el mismo `hash`, o enviar el resultado.
- Muchas cifras del juego dependen de cuánto dura un fotograma o de rayos que se lanzan en cada fotograma: `hotel_main.gd:1832` (la ronda de visibilidad), `executions.gd:345` (la captura usa `delta`), `death_tape.gd:257` (la cámara usa `get_process_delta_time`), `observer_view.gd:428`.
- Escena de la cinta: dependen de `ShaderMaterial` con parámetros puestos a mano cada cuadro, y de un `CompositorEffect` propio (`presentation_rig.gd:59-66`). La imagen completa vive en esos parámetros (apartado 15).
- Muchos parámetros se leen de `ProjectSettings` por su ruta de texto (`presentation_rig.gd:224, 229, 282`).
- El piso se construye con esperas de fotogramas y de física (apartado 14.1), y se rechaza si la validación física o la ruta de navegación fallan (`hotel_main.gd:894-931`).
- Mallas generadas en tiempo de ejecución: `ImmediateMesh`, `MultiMesh` con datos por instancia, `PlaneMesh`/`QuadMesh` creados por código (`blood.gd:323-327, 330-359, 399-411`; `observer_gizmos.gd:52`).
- Audio de bus en vivo: `AudioServer.add_bus_effect` / `remove_bus_effect` durante la partida (`death_tape.gd:532-549`), y `AudioStreamPlayer3D` con `area_mask` (`lurker_hallucinations.gd:521`, `presentation_rig.gd:470`, `phantom_passage.gd:50`), con rutas de sonido que calcula `world_audio.gd` (no leído).
- Cuerpos físicos y animación: `Skeleton3D`, `AnimationPlayer` con clips llamados por nombre ("loom", "idle", "peek"), huesos por nombre ("Head1", "Spine", "Pelvis", "head", "body", "abdomen", "a.L", "a.R", "la", "ra") (`locust_hallucinations.gd:22-23`, `lurker_hallucinations.gd:21-22`, `lurker_capture.gd:156-181`, `lurker_poser.gd:12-13`, `death_tape.gd:383`).
- Navegación: `FLOOR.closest(map, p)` y `navigation_path` se llaman al decidir (`pacing_director.gd:770-771`, `sanity.gd:302`, `televisions.gd:122`, `revival.gd:84`, `phantom_passage.gd:67, 90-92`).
- Ficheros de usuario: `user://` con JSON para ajustes, puntos de guardado, descubrimientos, registros, traza y volcado (`hotel_main.gd:214-241`, `session_perf.gd:25-212`, `observer_view.gd:619-648`).
- Hilos: un hilo escritor con `Mutex` en `session_perf.gd:11-12, 177-212`.
- El nombre del volcado del observador y la cabecera de la traza usan la hora del sistema (`observer_view.gd:641`, `session_perf.gd:43`).
- Profundidad del atlas de sombras: `presentation_rig.gd:262-267` comenta 32 bits, y el código pone `positional_shadow_atlas_16_bits = not compatibility` (:267), es decir, 16 bits fuera de Compatibility. Qué se ve depende de cuál se aplique; no lo comprobé.

## 18. Sin comprobar

- No leí `game/game_session.gd` (`game/services/game_session.gd`): los estados y valores de `session.State` y `session.Life` están inferidos de cómo se usan aquí (ver 4.5).
- No leí `game/net/net_session.gd` ni `match_net.gd`: la red, los modos VERSUS y COOP, y el significado exacto de cada RPC.
- No leí `game/ui/` (`interface.tscn`, `interface.gd`, `paper_sheet.gd`, `hotel_form.gd`): los menús, los textos y las pantallas.
- No leí `game/title/title_scene.gd`, `game/intro/intro_sequence.gd`, ni `ui.play_intro()`.
- No leí `game/world/` (`hotel_geometry.gd`, `floor_definition.gd`, `hiding_place.gd`, `hotel_door.gd`, `hotel_television.gd`, `hotel_container.gd`, `hotel_panel.gd`, `hotel_hint.gd`, `hotel_lock.gd`, `hotel_document.gd`, `room_dressing.gd`, los generadores).
- No leí `game/floors/` (`difficulty.gd`, `match_rules.gd`, `hotel_floor.gd`, `office_floor.gd`, `floor_index.gd`, `palettes/`, `objectives/`). Los números de dificultad salen de ahí, y el generador y los pisos también.
- No leí `game/enemies/` (`creature.gd`, `locust/hotel_locust.gd`, `locust_look.gd`, `locust_poser.gd`, `echo_view.gd`, `lurker/*`, `creature_sight.gd`): la definición del contrato de la criatura.
- No leí `game/player/` (`player.gd`, `avatar_visual.gd`).
- No leí `game/audio/world_audio.gd`, `dread_aura.gd`, `noise_kinds.gd`, `search_timing.gd`, `grunt_segments.gd`: la acústica, los sonidos, el aura y los radios de ruido.
- No leí `game/presentation/` (`camcorder_look.gd`, `camcorder_effect.gd`, `motion_blur_effect.gd`, `graphics_presets.gd`, `shader_warmup.gd`, shaders `.gdshader`, `camcorder_osd`). Las cifras de sus presets y los valores de la lente quedan fuera.
- No leí `game/services/` (`settings_service.gd`, `records_service.gd`, `discovery_service.gd`, `run_score.gd`): la puntuación, los registros y los ajustes.
- No leí `tools/bots/` ni `tools/dev/`.
- No leí `project.godot` más allá de comprobar que no tiene `[autoload]`: las acciones de entrada y los buses de audio.
- No inspeccioné los recursos (`.wav`, `.ogg`, `.glb`, `.res`, `.png`, `.gdshader`): duraciones, bucles, dimensiones.
- No sé si las cifras de `ruta:línea` cambian si se corrige un salto de línea en los ficheros: las leí tal como están hoy (14 de noviembre de 2026).
- No comprobé `.claude/godot-api/` para cada clase citada: el conteo de clases es aproximado y viene de búsqueda de texto dentro de estas tres carpetas.
- No ejecuté nada: los tests no se han corrido, ni el juego, ni se ha medido rendimiento. Las cifras de duración (por ejemplo, siete minutos y medio de cordura) son las del comentario y las constantes, no mediciones.
- No comprobé que `hash()` de GDScript sea estable entre versiones de Godot 4.7 ni fuera de Godot.
- No leí `docs/` (`EXECUTION.md`, `GAME_DESIGN.md`, `OFICINAS.md`, `DIFFICULTY.md`, `LORE.md`, `REALISM.md`, `AUDIO.md`): las intenciones de diseño citadas en los comentarios no están verificadas aquí.
- No cubrí `tests/` por dentro: solo cabeceras de comentario y búsqueda de rutas.
