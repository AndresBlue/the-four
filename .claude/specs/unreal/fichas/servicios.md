# Ficha de hechos: servicios (game/services/)

Fecha de la lectura: 14 de noviembre de 2026. Repositorio: `E:\Projects\The Four`, rama `main`.
Lectura solo de código y documentación. No se ejecutó Godot, no se compiló nada, no se tocó git y no se abrió el perfil real del jugador.

Convención: `ruta:línea`, con la línea del archivo tal como está en disco. Donde pongo `DEVELOPMENT.md:N`, N es la línea real del archivo (no la de una búsqueda parcial). Lo que no está comprobado va en el apartado final «Sin comprobar».

---

## 0. Resumen

1. **No hay autoloads.** `project.godot` no tiene sección `[autoload]` (project.godot:1-74) y ningún otro archivo del repo la tiene (búsqueda sin resultados). Los servicios son nodos de escena: `Services/Settings` y `Services/GameSession` están en `game/app/hotel.tscn:16-20`. `Discoveries` y `Records` los crea código en `game/app/hotel_main.gd:225-232`.
2. **Persistencia:** cuatro archivos JSON bajo `user://` (`hotel_settings.json`, `records.json`, `discoveries.json`, `hotel_checkpoint.json`), un binario (`hotel_checkpoint.state`) y un archivo de texto de renderer (`renderer.cfg`). Escritura atómica por archivo temporal con relectura (`save_file.gd:8-20`).
3. **Perfil de prueba:** con `--test-profile` o al lanzar un script `.gd`, todos los archivos cambian de nombre a `test_hotel_<nombre>_*` (`hotel_main.gd:212-241`). Con eso, las pruebas no tocan el perfil del jugador.
4. **Versión del juego:** `application/config/version = "1.3.0"` (project.godot:18). El CHANGELOG también tiene 1.3.0 como última (docs/CHANGELOG.md:73). La guía dice 1.2.0 en dos sitios (DEVELOPMENT.md:3 y 444): está desactualizada.
5. **Steam:** AppID 480 en `project.godot:73`, que es el AppID de prueba de Steam. El plugin GodotSteam se inicia con el motor (project.godot:74).
6. **Export:** dos presets, Windows Desktop (`exports/windows/TheFour.exe`) y macOS universal (`exports/macos/TheFour.zip`) (export_presets.cfg:12 y 59). El zip de Windows tiene cuatro archivos más un lanzador (godot.ps1:145-159).
7. **Física:** no hay ajustes de ticks en `project.godot`, así que son los de Godot (60 por segundo). Gravedad 20.0 (project.godot:53). Ningún servicio usa `_physics_process`: todo el tiempo de los servicios va en `_process` (game_session.gd:310, settings_service.gd:502).
8. **Azar:** los servicios no sortean nada, salvo el identificador de la cuenta de récords, que usa `RandomNumberGenerator` sin semilla (records_service.gd:83-85).
9. **Consumidores fuera de la carpeta:** `hotel_main.gd`, `hotel_ui.gd`, `records_board.gd`, `tape_report.gd`, `run_ledger.gd`, `match_net.gd`, `steam_link.gd`, `hotel_floor.gd`, `floor_save.gd` y otros (lista en el apartado 2).
10. **Tests:** 54 archivos `.gd` en `tests/` (medido con `find`). Los que prueban esta parte están en el apartado 13.

---

## 1. Inventario de lo leído

| Archivo | Líneas | Qué hace |
|---|---|---|
| `game/services/save_file.gd` | 36 | Escritura atómica de texto (temporal, relectura, renombrado), lectura JSON, recuperación de un temporal huérfano y copia a `.corrupt` de lo que no se lee. |
| `game/services/discovery_service.gd` | 28 | Lista de documentos leídos por el jugador (`user://discoveries.json`), en orden de lectura. |
| `game/services/game_session.gd` | 337 | Estado de la partida (menú, carga, jugando, pausa, transición, ganado, perdido, escena de entrada), etapas del piso, reinicios, cuórum, punto de control y estado guardado del piso. |
| `game/services/settings_service.gd` | 507 | Ajustes, teclas, mando, ventana, gráficos, volúmenes de audio y renderer. Aplica todo a Godot. |
| `game/services/records_service.gd` | 402 | Tablones de cintas, carrera, hitos por piso, tarjetas de otros jugadores. |
| `game/services/run_score.gd` | 248 | Cálculo puro de puntaje, nota, parte de cada superviviente y hitos a partir de una línea de cinta. No guarda nada. |
| `project.godot` | 74 | Versión, escena principal, capas, física, render, Steam. |
| `export_presets.cfg` | 81 | Presets de Windows y macOS. |
| 17 archivos `.cmd` de la raíz | de 1 a 16 cada uno | Accesos directos que llaman a `tools/godot.ps1` (apartado 9). Todos leídos. |
| `tools/export/Probar piso 2.bat` | 5 | Lanzador del piso 2. Se copia junto al `.exe` y al zip (godot.ps1:145-147). |
| `docs/README.md` | 23 | Índice de la documentación. |
| `docs/DEVELOPMENT.md` | 464 | Guía de edición. Leídas las líneas 1-60 y 413-464 completas. Las líneas 61-412 solo por palabras clave (ver «Sin comprobar»). |
| `tools/godot.ps1` | 170 | Lanzador de todos los modos, argumentos de cada uno, exportación y zip. Leído completo. |
| `game/app/hotel.tscn` | 25 | Escena principal: declara el nodo `Services` con sus dos hijos. Leída completa. |
| `game/app/hotel_main.gd` | 180-330 | Cableado de los servicios (`_enter_tree`) y conexión de señales. Solo ese tramo. |
| `game/ui/hotel_ui.gd` | 10-11, 362 | Texto de versión y conexión de `display_pending`. Solo esas líneas. |
| `docs/CHANGELOG.md` | 1-4 y cabeceras | Última versión y fecha. Solo cabeceras. |
| `game/net/steam_link.gd` | 21, 29-30, 53, 78-82, 105 | AppID y cómo se lee. Solo búsqueda. |
| `.claude/godot-api/doc/classes/ProjectSettings.xml` y `Engine.xml`, `DisplayServer.xml` | búsqueda | Valores por defecto de ticks, modo de ventana y `max_fps`. |

---

## 2. Montaje: nodos, orden de alta y consumidores

**Autoloads:** ninguno (apartado 0.1).

**Escena `game/app/hotel.tscn`:**
- Recursos externos: `settings_service.gd` (id 2), `game_session.gd` (id 3) (hotel.tscn:4-5).
- Árbol: `TheFourHotel` (Node3D, script `hotel_main.gd`) (hotel.tscn:12-14) → `Services` (Node) (hotel.tscn:16) → `Settings` (script `settings_service.gd`) (hotel.tscn:17-18) y `GameSession` (script `game_session.gd`) (hotel.tscn:19-20). Después van `Player`, `Interface`, `Presentation` y `WorldAudio` (hotel.tscn:21-25).

**Alta de los servicios creados por código** (`game/app/hotel_main.gd`, `_enter_tree`, líneas 187 a 287). Orden de llegada:
1. `settings = $Services/Settings` (190) y `session = $Services/GameSession` (191).
2. Ajuste de rutas de perfil de prueba (212-215) y de `trace_display` (222).
3. `discoveries = DISCOVERIES.new()`, nombre `Discoveries`, ruta propia si hay perfil de prueba (225-228).
4. `records = RECORDS.new()`, nombre `Records`, ruta propia si hay perfil de prueba (229-232).
5. Luego, bajo `Services` y en este orden: `Net` (237-242), `Sanity` (244-247), `Lifts` (248-251), `FloorMap` (252-255), `Televisions` (256-259), `CodeLock` (260-263), `Executions` (264-267), `DeathTape` (268-271), `Revival` (272-275), `Interaction` (276-279), `PresentationRig` (280-283), `Ledger` (284-287).

**Orden de `_ready` de los servicios** (inferido del ciclo de vida de Godot: `_enter_tree` baja desde el padre, `_ready` sube desde los hijos; ver «Sin comprobar»):
- `Settings._ready` (settings_service.gd:92-99): `process_mode` ALWAYS, `load_settings()`, `write_renderer()` si `manages_window()`, `apply()`, `apply_display()`.
- `GameSession._ready` (game_session.gd:75): solo `process_mode` ALWAYS.
- `Records._ready` (records_service.gd:58): `load_records()`.
- `Discoveries._ready` (discovery_service.gd:9-10): `load_record()`.
- Por eso el cambio de `save_path` y de `checkpoint_path` en `_enter_tree` (hotel_main.gd:214-215, 227, 231) ocurre antes de leer nada.

**Consumidores de los servicios** (búsqueda, no todos leídos):
- `game/app/hotel_main.gd`: conexiones de señales (304-305, 318, 327), `records` (34-36, 225-232, 318-321), `settings` (190, 327, 362 en hotel_ui).
- `game/app/run_ledger.gd`: `SCORE` y `RECORDS` (14-15), `RECORDS.EVENTS_KEPT` (119), tipo de compañía (354, 376).
- `game/ui/records_board.gd` (12-13), `game/ui/tape_report.gd` (12-13), `game/ui/hotel_ui.gd` (215, 362).
- `game/net/match_net.gd:22` (usa `SAVE_FILE` para el punto de control de red) y `:1213`; `game/net/steam_link.gd:259` (los hitos son logros de Steam).
- `game/floors/hotel_floor.gd` (4, 45, 49, 51), `game/floors/difficulty.gd:23`, `game/floors/match_rules.gd:12`, `game/floors/office_floor.gd:36`, `game/presentation/graphics_presets.gd:35`, `game/app/floor_save.gd` (5, 12).
- `game/ui/achievements_board.gd` (6, 26), `game/ui/tape_report.gd` (6, 20).

---

## 3. Guardado y perfil

### 3.1 Archivos

| Archivo (ruta lógica) | Formato | Lo escribe | Contenido | Versión y reglas |
|---|---|---|---|---|
| `user://hotel_settings.json` | JSON | `settings_service.save_settings()` (499-500) | `values`, `bindings`, `pad_bindings`, `pad_rev`, `audio_curve`, `display_rev`, `subtitle_rev`, `character_rev` | Revisiones: pad 2 (:24), audio 2 (:53), display 3 (:57), subtítulos 1 (:66), personaje 1 (:71). |
| `user://records.json` | JSON con sangría de tabuladores | `records_service.save()` (401-402) | `version`, `id`, `runs`, `career`, `milestones`, `rivals` | `VERSION = 2` (:21). Un archivo con versión menor se convierte al leerlo (77-81). |
| `user://discoveries.json` | JSON con tabuladores | `discovery_service.record()` (23) | `version` 1, `found` (lista de ids) | Un id repetido no se guarda dos veces (discovery_service.gd:17). |
| `user://hotel_checkpoint.json` | JSON | `game_session.write_checkpoint()` (294-308) | `format` 1, `generator`, `seed`, `floor`, `fallback`, `difficulty` | `format` 1 (game_session.gd:279, 296). `generator` es la versión del generador del piso. |
| `user://hotel_checkpoint.json.bak` | igual | copia del anterior al escribir (300-302) | igual | Se usa solo si el principal no se puede leer (game_session.gd:270). |
| `user://hotel_checkpoint.state` | binario `store_var` | `game_session.write_state()` (223-240) | `{format, generator, seed, state}` con vectores y tablas por asiento | `STATE_FORMAT = 2` (game_session.gd:219). Nombre: el del checkpoint cambiando la extensión (221). |
| `user://renderer.cfg` | texto `[rendering]` con `renderer/rendering_method="..."` | `settings_service.write_renderer()` (148-153) | Solo si el renderer no es `forward_plus`; si lo es, borra el archivo (149-151) | Lo lee Godot al arrancar porque `project.godot:20` lo declara como `project_settings_override`. |
| `*.tmp` y `*.corrupt` | temporal y copia de lo ilegible | `save_file.gd` (8-15, 35) | | |

### 3.2 Escritura y lectura (`save_file.gd`)

- `write_temp(temp, text)` (8-15): abre el temporal, escribe, cierra, lo vuelve a leer, y si no coincide lo borra y devuelve falso.
- `write(path, text)` (18-20): primero el temporal, después `DirAccess.rename_absolute` al archivo final. Solo reemplaza cuando el nuevo ya existe entero.
- `read(path)` (29-36): si falta el archivo principal y existe `path.tmp`, lo renombra (31). Si el texto no es JSON válido ni es `{}`, renombra el archivo a `.corrupt` (35). Así un guardado nuevo no pisa lo que no se pudo leer.
- `parse(text)` (23-25): `JSON.new().parse`, devuelve `{}` si falla.

Los estados de partida no usan `save_file.gd`: `write_state` escribe su propio temporal y lo comprueba comparando bytes con `var_to_bytes(kept).size() + 4` (game_session.gd:237). El comentario dice que `store_var()` pone la longitud al principio (235-236).

### 3.3 Checkpoint de partida (game_session.gd)

- `start()` (82-101): si no es online y `keeps_checkpoint`, olvida el estado anterior y escribe el checkpoint nuevo.
- `checkpoint()` (264-286): lee el principal; si no se lee, prueba el `.bak` (270). Mensajes en español: «El checkpoint no se puede leer. Puedes iniciar una partida nueva.» (272), «Checkpoint incompatible con esta versión. Se conserva el archivo original.» (280), «El checkpoint contiene una semilla inválida.» (283). Un checkpoint sin `floor` es del hotel, número 1 (276-278). Un número de piso sin construir o de otro generador se rechaza (279-281).
- `forget_checkpoint()` (201-203) borra el checkpoint y el estado cuando se gana o se pierde el piso (llamadas en 190 y 336).
- `write_checkpoint()` (294-308): escribe el temporal con `SAVE_FILE.write_temp`, guarda el anterior como `.bak`, renombra el temporal al final y, si falla, devuelve el `.bak` a su sitio.

### 3.4 Perfil de prueba y `--test-profile`

`game/app/hotel_main.gd`, `_enter_tree`:
- Nombre de la prueba: el del argumento `.gd` sin extensión, o `default` (196-201). Con `--profile-tag=x` se le añade `_x` (204-205).
- `own_files = scripted or test_profile` (212).
- Si `own_files`: `settings.save_path = user://test_hotel_<nombre>_settings.json` (214), `session.checkpoint_path = user://test_hotel_<nombre>_checkpoint.json` (215), `discoveries.save_path = user://test_hotel_<nombre>_discoveries.json` (227), `records.save_path = user://test_hotel_<nombre>_records.json` (231), `match_net.checkpoint_path = user://test_coop_<nombre>_checkpoint.json` (241).
- Sin esos argumentos, se usan los archivos del jugador (apartado 3.1).
- `settings_service.manages_window()` (447-452) devuelve falso si hay un argumento que termina en `.gd`, o `--automation`, o `--test-profile`, o si el motor va sin ventana. En ese caso no se toca la ventana (463-465) ni se escribe `renderer.cfg` (97).
- Piso lanzado por semilla (`--playtest-seed`, `playtest`, `locust`, Vista del cazador): usa los ajustes del jugador pero no guarda checkpoint (`session.keeps_checkpoint = false`), según DEVELOPMENT.md:58 y :98.

**Carpeta real del jugador:** según `CLAUDE.md` del proyecto, es `%APPDATA%\Godot\app_userdata\THE FOUR — Hotel`. El nombre sale de `config/name` (project.godot:17). No se ha abierto ni se ha listado.

---

## 4. Ajustes del jugador (settings_service.gd)

### 4.1 Valores por defecto (`DEFAULTS`, línea 6)

| Clave | Valor por defecto | Nota |
|---|---|---|
| `character` | 2 | Índice del personaje. El comentario de :67-70 dice que el valor por defecto es la Exploradora. Mapa de índices sin comprobar. |
| `pad_look` | 2.6 | Sensibilidad del stick derecho. Se limita a 0.6-6.0 (:197). |
| `rumble` | true | Vibración del mando. |
| `pad_sprint_toggle`, `pad_crouch_toggle` | true | Correr y agacharse alternan con el botón. |
| `window_mode` | 0 | Pantalla completa exclusiva (ver 4.3). |
| `resolution` | 0 | 1280x720 (:75). |
| `scale` | 0.67 | Escala de render. |
| `upscaler` | "auto" | |
| `sharpness` | 0.85 | Nitidez. Se traduce a `fsr_sharpness = lerpf(2.0, 0.0, sharpness)` (:426). |
| `aa` | "preset" | |
| `ao`, `fog`, `reflections`, `blur` | -1 | -1 significa «lo que diga el preset». |
| `quality` | 1 | Índice de preset (`graphics_presets.gd`, no leído). |
| `shadows` | true | |
| `fps` | 60 | Solo 0, 30, 60, 120, 144 (:195). Se aplica a `Engine.max_fps` (:414). |
| `vsync` | true | Se aplica en `DisplayServer.window_set_vsync_mode` (:420). |
| `vhs` 0.3, `grain` 0.05, `chromatic` 0.25, `scanlines` 0.1 | | Efectos de la cinta. |
| `osd` | true | |
| `bob` | 0.4 | |
| `reduced`, `startle_soft`, `subtitles` | false | `subtitles` tiene revisión propia (:66, :116). |
| `gore` | true | |
| `sensitivity` | 0.0022 | Limitado a 0.0005-0.008 (:196). |
| `invert` | false | |
| `master`, `ambience`, `music`, `effects`, `threat` | 0.5 | Volúmenes 0-1 (`AUDIO_KEYS`, :50). |
| `difficulty` | "desafiante" | Pero el primer arranque da «equilibrada» (:173). Ver `game/floors/difficulty.gd`, no leído. |
| `first_game_done` | false | |
| `floor2` | "" | Dificultades con las que se llegó al piso 2 (:184-185). |
| `join_address` | "127.0.0.1" | |
| `join_port`, `host_port` | "38430" | |
| `host_bind` | "*" | |
| `renderer` | "forward_plus" | Solo `forward_plus` o `gl_compatibility` (:181). |

### 4.2 Teclas y mando

- `KEYS` (línea 7): `forward` W, `backward` S, `left` A, `right` D, `sprint` Shift, `jump` Espacio, `interact` E, `flashlight` F, `crouch` Ctrl, `sheet` Tab, `locust_trace` Q, `lean_left` 1, `lean_right` 3.
- Teclas que no se pueden asignar: Escape, F9 y F11 (312, 142). Un control sin tecla se guarda como 0 (139-141).
- `PAD_KEYS` (línea 19): `interact` X, `crouch` B, `flashlight` Y, `jump` A, `sprint` clic en stick izquierdo, `sheet` Back, `lean_left` cruceta izquierda, `lean_right` cruceta derecha. El clic del panel táctil también abre la hoja (`PAD_SHEET_TOO`, :20).
- `PAD_RESERVED` (:27): Start, reservado para pausar.
- Gatillos para El Locust: `locust_strike` gatillo derecho y `locust_shriek` gatillo izquierdo (`PAD_TRIGGERS`, :32). Umbral 0.5 (`TRIGGER_DEADZONE`, :33).
- Menús: `UI_PAD` (:39) asigna A, B, cruceta a `ui_accept`, `ui_cancel` y direcciones. `UI_STICK` (:42) añade el stick izquierdo.
- Zona muerta de sticks: 0.15 (`STICK_DEADZONE`, :46).
- Mirar: `LOOK_ACTIONS` (:47), stick derecho, no se guarda.
- Movimiento: `MOVE_AXES` (:48), stick izquierdo.
- Familia del mando (`pad_family`, :275-283): por nombre y por fabricante USB. Sony `0x054C` (:265), Nintendo `0x057E` (:266), lo demás Xbox.
- Nombres en pantalla: `PAD_NAMES` (:256-260), `PAD_COMMON` (:262), `TRIGGER_NAMES` (:263).
- Teclas modificadoras: `MODIFIER_FLAGS` (:395) y `_input` (:397-410) sueltan la acción si el sistema dice que el modificador está arriba.

### 4.3 Ventana y resolución

- `WINDOW_MODES` (:61): «Pantalla completa», «Ventana sin bordes», «Ventana». Constantes `FULLSCREEN` 0, `BORDERLESS` 1, `WINDOWED` 2 (:62-64).
- Traducción a Godot (`apply_display`, :461-473): `FULLSCREEN` → `WINDOW_MODE_EXCLUSIVE_FULLSCREEN` (4); los otros dos que no son ventana → `WINDOW_MODE_FULLSCREEN` (3). Ventana → `WINDOW_MODE_WINDOWED` y `place_window()` centrada (470-473).
- `RESOLUTIONS` (:75): 1280x720, 1600x900, 1920x1080, 2560x1440. Índice 0-3 (190).
- `window_size_for` (:475-480): mantiene 16:9 y reduce si no cabe en el área útil de la pantalla menos `WINDOW_MARGIN` (:74) = `Vector2i(48, 96)`.
- `place_window` (:482-492): centra la ventana completa, con barra de título.
- Confirmación de cambios de ventana: `set_value` de una clave de `DISPLAY_KEYS` (`window_mode`, `resolution`, :72) arranca una cuenta atrás de 12 s (:219-220). Si no se confirma, `revert_display()` vuelve a lo anterior (:231-238, :506). `confirm_display()` lo fija (:225-229).

### 4.4 Gráficos, audio y renderer

- Escala de render: `get_viewport().scaling_3d_scale = values.scale` (:421). Modo de escalado: `PRESETS.scaling_mode(values)` (:425), sin leer.
- Renderer: se elige antes de arrancar. `renderer_pending()` compara con `RenderingServer.get_current_rendering_method()` (:156-157). Un cambio espera a reiniciar.
- Primer arranque (`first_run`, :169-178): si la GPU es integrada o no hay (`DEVICE_TYPE_INTEGRATED_GPU`, `DEVICE_TYPE_CPU`, :175), pone la calidad en `PRESETS.VERY_LOW` y su escala (177-178).
- Volumen: bus `Master`, `Ambience`, `Music`, `Effects`, `Threat` y `Steps` (que usa el volumen de efectos) (:428). Decibelios: `linear_to_db(max(volume * 2, 0.0002))` (:496-497): 50 % es 0 dB, 100 % es +6 dB, 25 % es -6 dB (comentario en :494-495).
- Silencio del bus de la criatura: `mute_threat` (:444, :436) sin tocar el ajuste guardado.
- Modo observador: `force_window` (:441) mantiene la ventana sin tocar el ajuste guardado.

### 4.5 Revisiones de ajustes

| Constante | Valor | Qué hace al leer un archivo viejo |
|---|---|---|
| `PAD_REVISION` (:24) | 2 | Si el archivo tiene otra, los botones vuelven a `PAD_KEYS` (120-126). |
| `AUDIO_CURVE` (:53) | 2 | Si no coincide, las claves de `AUDIO_KEYS` vuelven a su valor por defecto (114). |
| `DISPLAY_REVISION` (:57) | 3 | Si no coincide, `window_mode` y `resolution` vuelven a su valor por defecto (115). |
| `SUBTITLE_REVISION` (:66) | 1 | Subtítulos apagados (116). |
| `CHARACTER_REVISION` (:71) | 1 | El personaje vuelve al de por defecto (117). |

Límites de `sanitize` (:180-199): `resolution` 0-3, `window_mode` 0-2, `ao`/`fog`/`reflections`/`blur` -1 a 1, `character` 0-2, `quality` 0 a `PRESETS.count() - 1`, `fps` solo los cinco valores, `sensitivity` 0.0005-0.008, `pad_look` 0.6-6.0, `scale` desde el mínimo de `PRESETS.SCALING_MODES` hasta 1.0, el resto 0-1. Valores no numéricos o no finitos vuelven al valor por defecto (188).

---

## 5. Logros y estadísticas

- **Hitos (`milestones`):** clave `"<piso>:<id>"` (records_service.gd:319), con la fecha de la primera vez (321). `reach()` (313-323) solo cuenta si la línea no tiene reglas propias (317). Las reglas de cada hito están en `run_score.gd:217-248` (`earned`, `meets`); la lista de hitos de cada piso viene de `FLOORS.milestones()` (`floor_index.gd`, no leído).
- **Logros de Steam:** los hitos son logros con nombre `F<piso>_<ID>` (ejemplo `F1_OUT`) (DEVELOPMENT.md:77). `hotel_main.gd:318-321` manda `records.milestones.keys()` a `net.steam.unlock()` al cambiar, y en diferido al arrancar. Sin los logros creados en Steamworks, Steam rechaza todos (DEVELOPMENT.md:77).
- **Carrera (`career`):** cifras acumuladas (`tally`, records_service.gd:273-296). Claves que suma: `floors`, `lost`, `time`, `hunts`, `hunts_won`, `catches`, `escaped`, `mvps`, `tvs`, `digits`, `code`, `searched`, `escapes`, `hides`, `hidden`, `metres`, `deaths` (`CAREER_COUNTS`, :268). Además `best_score`, `best_grade`, `titles` (un recuento por parte) (289-296). `usual_part()` (302-307) devuelve la parte más veces.
- **Tarjeta (`card`):** filas de `CARD_ROWS` (338-352): floors, lost, solo_time, coop_time, best_score, best_grade, mvps, tvs, digits, escapes, deaths, time, milestones. Tipos: `count`, `time`, `clock`, `grade`. Se guarda hasta 24 tarjetas (`RIVALS_KEPT`, :43), y se expulsa la tarjeta vista hace más tiempo (383-387). La tarjeta propia la arma `card()` (356-365).
- **Partes del superviviente:** `TITLES` en `run_score.gd:54-66`, once títulos: CERRAJERO, ELECTRICISTA, SABUESO, ESCAPISTA, CEBO, EL DEL ARMARIO, MANOS LARGAS, EXPLORADOR, MARATONISTA, AL BORDE, CARNE DE CAÑÓN. Sin parte: SE QUEDÓ ATRÁS, FANTASMA (si la criatura no llegó a perseguirle, fuera de versus) o SUPERVIVIENTE (`run_score.gd:178-183`).

---

## 6. Registro de partidas (records_service.gd)

- **Tablones:** `TABLES` (51-56): `time` «MÁS RÁPIDOS», `score` «MAYOR PUNTAJE», `clean` «SIN BAJAS», `brave` «SIN ESCONDERSE».
- **Compañías:** `SOLO` «solo», `COOP` «coop», `VERSUS` «versus», `CUSTOM` «custom» (:26-31). Nombres en pantalla en :33. Cada piso tiene un tablón por compañía.
- **Solo cuentan** las cintas ganadas (`SCORE.won`, :200) y las de la versión actual del generador (`current`, :200, 252-253). Una línea sin `generator` cuenta como versión 4 (:252).
- **Orden:** `time` ascendente. `score` descendente y, a igual puntaje, tiempo ascendente (201-202).
- **Límite:** `KEPT = 24` líneas por tabla (:23, :203). `trim()` (257-263) borra las líneas que no están en ninguna tabla.
- **Límites de `clean()`** (134-178): `floor` 1 a `FLOORS.COUNT`; `players` 1-8 (:140); `time` y `par` entre 0 y 360000 (:141-142); `stage` 1-16 (:143); `sectors` hasta 16 (:156); `team` hasta 8 (:158); `events` hasta 120 (`EVENTS_KEPT`, :161, :179); nombres hasta 24 letras (:170, :184); títulos y motivos hasta 60 (:189); nombre de tarjeta hasta 18 (:357, :373).
- **Desempate del MVP** (`run_score.gd:143-148`): puntos, después menos muertes, después el asiento más bajo.
- **Orden al registrar una cinta** (`file()`, 115-129): primero `tally` (la carrera), después `reach` (los hitos), y solo si ganó `record()` (que pone `generator`, `date` y guarda). Si perdió, solo guarda.
- **Identificador de la cuenta** (`id`): aleatorio de 16 caracteres hexadecimales si el archivo no lo tiene (82-85). Sin semilla.
- **Fechas:** `Time.get_datetime_string_from_system(false, true)` en 93, 321 (se cortan a 10 caracteres) y 379 (última vez vista de una tarjeta). Hora de reloj, no de juego.
- **Versión del archivo:** `VERSION = 2` (:21). Un archivo con versión menor se convierte (77-81).
- **Badges:** `SIN BAJAS`, `SIN ESCONDERSE`, `EQUIPO ENTERO` (232-238).

---

## 7. Partida en curso (game_session.gd)

- **Estados** (línea 7): `MENU`, `LOADING`, `PLAYING`, `PAUSED`, `TRANSITION`, `WON`, `FAILED`, `CUTSCENE`. **Vida** (línea 8): `EXPLORING`, `REFUGE`, `DEAD`.
- **Etapas:** un piso tiene `stages = FLOORS.kind(1).count()` (línea 20), o sea tres en el hotel según el comentario de 14-18. Lo que cierra cada etapa lo decide `update_goal` (123-128) y `finish_stage` (132-138) pasa a `TRANSITION`.
- **Transición:** 1,2 s en `_process` (321). Después, o se sube a la siguiente etapa (322-335) o se gana el piso (336-337).
- **Reinicios:** `RESTARTS = 1` (:29) por piso (`restarts_allowed`, :32). `solo_restarts = 0` (:33). Espera del reinicio: `RESTART_WAIT = 2.6` s (:42) la primera vez, `RESTART_WAIT_AGAIN = 0.6` s (:45) las siguientes (184). Se cuenta en `_process` (313-317).
- **Cuórum:** `minimum_survivors() = max(1, ceil(roster_count / 2))` (103). `check_quota()` (160-192): si no llega, reinicia (si quedan reinicios y hay suficientes que puedan levantarse) o pasa a `FAILED` (187-191).
- **Perdidos para el piso:** `dropped` (56, 150-158). Nadie los levanta al reiniciar (196-197).
- **Pausa:** `pause()` (257-258) solo desde `PLAYING`. `elapsed` avanza en `_process` solo en `PLAYING` (311).
- **Autoridad:** `authority` (73). Un invitado tiene una copia de la sesión y no avanza etapas (`_process` sale en 312 si no es autoridad). Ver DEVELOPMENT.md:22.
- **Revivir:** señal `revived(restart)` (5), emitida desde `_process` (318, 334). `hotel_main.gd:305` la conecta.

---

## 8. Física, ventana, render y export

### 8.1 Capas (project.godot:40-49, sección `[layer_names]`)

| Capa | Nombre en project.godot | Línea |
|---|---|---|
| 3D render 2 | «Local player body (hidden by own camera)» | :42 |
| 3D física 1 | «Architecture» | :43 |
| 3D física 3 | «Players» | :44 |
| 3D física 4 | «Closed doors» | :45 |
| 3D física 5 | «Hiding interactions» | :46 |
| 3D física 6 | «Creatures» | :47 |
| 3D física 7 | «Door sight occlusion» | :48 |
| 3D física 10 | «Audio areas» | :49 |

Las capas 2, 8 y 9 de física no tienen nombre en el archivo. DEVELOPMENT.md:55 cita las capas 1, 8 y 64 para los rayos del cuerpo de la captura: no comprobado el significado de esos números en el archivo.

### 8.2 Física

- Ticks: no hay `physics/common/physics_ticks_per_second` en `project.godot`. El valor por defecto es 60 (`.claude/godot-api/doc/classes/ProjectSettings.xml`, `physics/common/physics_ticks_per_second`).
- `max_physics_steps_per_frame`: por defecto 8, según la búsqueda en `.claude/godot-api/doc/classes/` (el archivo exacto no se ha confirmado). No se cambia en el proyecto.
- Gravedad: `physics/3d/default_gravity = 20.0` (project.godot:53).
- Uso fuera de servicios: `game/player/hotel_player.gd:431` usa `Engine.physics_ticks_per_second` para los pasos.
- Pruebas con reloj fijo: `--fixed-fps 60` (tools/godot.ps1:52-58, 82, 125).

### 8.3 Ventana, renderer y arranque

- Viewport: 1280x720 (project.godot:32-33). Ventana inicial: 1280x720 (:35-36). Escalado `canvas_items`, aspecto `expand` (:37-38).
- `display/window/size/mode = 3` (project.godot:34). En `DisplayServer.xml`, `WINDOW_MODE_FULLSCREEN` vale 3 y `WINDOW_MODE_EXCLUSIVE_FULLSCREEN` vale 4. Los ajustes del jugador la reemplazan al arrancar (apartado 4.3).
- Renderer: `features` incluye «Forward Plus» (project.godot:21). Móvil: `gl_compatibility` (:57). Override por archivo: `user://renderer.cfg` (:20).
- Importación: `etc2_astc` (:58). Sombras: `soft_shadow_filter_quality = 3` (:59). Anisotropía 4 (:60). Color de fondo (:61). Oclusión activa (:62).
- Globales de shader: `surface_detail = 4.0` (:66-69).
- Splash: `boot_splash/show_image = false` (:23). Fondo (:22). Icono `the_four.png` (:24).

### 8.4 Versión y etiquetas

- Número: `application/config/version = "1.3.0"` (project.godot:18). Está en un solo sitio (DEVELOPMENT.md:439).
- Pantalla: `hotel_ui.version()` devuelve `"v" + version` (game/ui/hotel_ui.gd:10-11).
- CHANGELOG: `## 1.3.0 — 10 de noviembre de 2026` es la primera (docs/CHANGELOG.md:73). Después, 1.2.0 (121), 1.1.0 (154), 1.0.1 (190).
- Etiquetas: cada versión publicada es una etiqueta `vX.Y.Z` sobre el commit de la exportación (DEVELOPMENT.md:442; CHANGELOG.md, cabecera). No comprobado en git (no se ejecutó git).
- Números que no son la versión del juego: protocolo de red `the-four-net-22` (DEVELOPMENT.md:443), generador de pisos `FLOOR.VERSION` v8 (443), versión de generador de piso 2 `office_palette.VERSION` v2 (443), `records_service.VERSION` 2 (records_service.gd:21), revisiones de ajustes (apartado 4.5), `STATE_FORMAT` 2 (game_session.gd:219), formato de checkpoint 1 (game_session.gd:279, 296).

### 8.5 Export

**`tools/godot.ps1`** (los modos `export` y `export-mac`):
- `export` (:83-94): borra `.godot/exported` (cache de exportación, :88-89), exporta con `--export-release "Windows Desktop" exports/windows/TheFour.exe` (:93), sin modo headless (el horneado de shaders necesita GPU, :90-92).
- Después, quita los `*.truncated` (144), copia `tools/export/Probar piso 2.bat` a la carpeta (145-147), comprueba cuatro archivos: `TheFour.exe`, `TheFour.pck`, `steam_api64.dll`, `libgodotsteam.windows.template_release.x86_64.dll` (148). Crea `exports/TheFour.zip` con una carpeta `The Four/` dentro, que contiene esos cuatro archivos y el lanzador (150-162).
- `export-mac` (:98-103): borra la misma caché y exporta `--export-release macOS exports/macos/TheFour.zip` (102). Sin zip extra (163-167).
- Si el exportador falla (código distinto de 0), el script lanza error (138, 166).

**`export_presets.cfg`:**
- Preset 0 «Windows Desktop» (:1-47): `export_filter = "all_resources"` (:9) con exclusiones `tests/*, tools/*, evidence/*, source_assets/*, models/*, sfx/*, exports/*, docs/*, *.zip, *.blend` (:11). Salida `exports/windows/TheFour.exe` (:12). Arquitectura `x86_64` (:30). `shader_baker/enabled = true` (:29). Icono `the_four.ico` (:33). `embed_pck = false` (:26). `product_name = "The Four"` (:39). Versiones de archivo vacías (:36-37), o sea el exportador pone la del proyecto según DEVELOPMENT.md:439 (no comprobado). Direct3D12 desactivado (:44).
- Preset 1 «macOS» (:48-81): misma exclusión (:58), salida `exports/macos/TheFour.zip` (:59), arquitectura `universal` (:70), `shader_baker/enabled = true` (:73), `bundle_identifier = com.andresblue.thefour` (:74), categoría «Games» (:75), mínimo macOS 11.00 en ARM (:78), firma `codesign = 1` (:79), notarización 0 (:81). Versiones vacías (:76-77).
- `script_export_mode = 2` en ambos (:19, :66). Significado no comprobado.

### 8.6 Steam

- `[steam]` (project.godot:71-74): `initialization/app_data/app_id = 480` (:73) y `initialization/processes/initialize_on_startup = true` (:74).
- `game/net/steam_link.gd`: `APP_ID_SETTING = "steam/initialization/app_data/app_id"` (:29), `DEV_APP_ID = 480` (:30), `app_id()` lee el ajuste (:53). Se inicia con `steamInitEx(app_id(), false)` (:81). Variables de entorno `SteamAppId` y `SteamGameId` (:79-80). Un comentario dice que con 480 una invitación abre Spacewar (:105).
- Plugin: GodotSteam 4.22.1 en `addons/godotsteam/`, solo Windows 64 (DEVELOPMENT.md:75). DLL: `steam_api64.dll` (godot.ps1:148).
- No hay `steam_appid.txt` en la raíz (`ls`).

---

## 9. Lanzadores `.cmd` (raíz) y `tools/export/`

Todos llaman a `tools\godot.ps1 <modo>` salvo que se diga otra cosa. Modos: `godot.ps1:2`.

| Archivo | Modo o comando | Qué hace |
|---|---|---|
| `Jugar.cmd` | `play` | Juega. |
| `Jugar piso 2.cmd` | `play -Extra "--floor=2 --test-profile"` | Piso 2 con perfil de prueba. |
| `Saltar.cmd` | `play -Extra "--floor=N --stage=M --jumps --test-profile"` | Salta a un piso y sector. Pregunta lo que falte. |
| `Abrir proyecto.cmd` | `editor` | Abre el editor. |
| `Taller de habitaciones.cmd` | `gallery` | `tools/workbenches/module_gallery.tscn`. |
| `Pasillo del Lurker.cmd` | `lurker` | `tools/workbenches/lurker_test.tscn`. |
| `Cazar a los bots.cmd` | `hunt -Bots 5 -Seed 81` | Eres El Locust contra bots. |
| `Vista del cazador.cmd` | `locust -Seed 81` | Vista del cazador. |
| `Ver bots.cmd` | `bots -Bots -Seed [-Mercy]` | Bots en vivo en el observador. |
| `Bots en lote.cmd` | `tools\bots.ps1 -Bots -Runs -Seed -Parallel 10` | Muchos pisos sin ventana. |
| `Ver repeticion.cmd` | `bots-replay -Run -At` | Vuelve a ver una partida grabada. |
| `Observador.cmd` | `observer -Seed 81` | Observador. |
| `Banco de capturas.cmd` | `bench -Seed 81` o `bench-films` (G) | Banco de la captura. Con G graba tres películas en `evidence\`. |
| `Registrar piso 2.cmd` | `tools\dev\record_floor2.ps1` | No leído. |
| `Verificar.cmd` | `tools\verify.ps1` | Todas las pruebas. El comentario dice «unos 25 minutos» (línea 2). DEVELOPMENT.md:433 dice 4,5 minutos. |
| `Exportar.cmd` | `export` | Windows, zip en `exports\TheFour.zip`. |
| `Exportar para Mac.cmd` | `export-mac` | macOS, zip en `exports\macos\TheFour.zip`. |
| `tools/export/Probar piso 2.bat` | `start TheFour.exe -- --floor=2 --test-profile` | Lanzador del piso 2 que va dentro del zip. |

**Ruta de Godot** (`tools/godot.ps1:15-25`): `GODOT_PATH` o `-GodotPath`. Si no, busca `D:\SteamLibrary\...\godot.windows.opt.tools.64.exe` y `C:\Program Files (x86)\Steam\...`. El editor usado para comprobar la versión es 4.7.2 stable steam (`.claude/godot-api/VERSION`).

**Modo `play` sin `--rendering-method`**: los modos de juego (`play`, `playtest`, `locust`, `rehearsal`, `bench`, `editor`, `gallery`, `lurker`, `lurker-arena`, `compatibility`, `observer`, `bots`, `hunt`, `bots-replay`, `export`, `export-mac`) no fuerzan Forward+ (godot.ps1:29). Los demás sí (`--rendering-method forward_plus`).

---

## 10. Clases y nodos de Godot que usa esta carpeta

Conteo aproximado de apariciones de cada identificador en `game/services/*.gd` (búsqueda por palabra, `grep -o -w`). Es lo que habría que sustituir.

| Clase, nodo o API | Apariciones | Dónde (ejemplos) |
|---|---|---|
| `FileAccess` | ~26 | save_file.gd, game_session.gd (`open`, `get_file_as_string`, `get_file_as_bytes`, `file_exists`) |
| `DirAccess` | ~13 | `rename_absolute`, `remove_absolute` (save_file.gd, game_session.gd, settings_service.gd:150) |
| `JSON` | ~6 | `JSON.new().parse`, `JSON.stringify` (save_file.gd:24, records_service.gd:402) |
| `store_var` / `get_var` / `var_to_bytes` | 2 / 1 / 1 | game_session.gd:233, 249, 237. Formato binario de Godot. |
| `DisplayServer` | ~28 | ventana: `window_set_mode`, `window_get_mode`, `window_set_size`, `window_set_position`, `screen_get_usable_rect`, `window_set_vsync_mode`, `get_name` (settings_service.gd:419-492) |
| `RenderingServer` | 2 | `get_current_rendering_method`, `get_video_adapter_type` (settings_service.gd:157, 174) |
| `RenderingDevice` | 2 | `DEVICE_TYPE_INTEGRATED_GPU`, `DEVICE_TYPE_CPU` (settings_service.gd:175) |
| `Input` | ~9 | `get_connected_joypads`, `get_joy_name`, `get_joy_info`, `is_action_pressed`, `action_release` (settings_service.gd:276-410) |
| `InputMap` | ~23 | `has_action`, `add_action`, `action_erase_events`, `action_add_event`, `action_set_deadzone`, `action_get_events` (settings_service.gd:336-380) |
| `InputEventKey` | 4 | `physical_keycode` (settings_service.gd:343-344) |
| `InputEventJoypadButton` | 5 | `button_index` (settings_service.gd:349-363) |
| `InputEventJoypadMotion` | 4 | `axis`, `axis_value` (settings_service.gd:382-385) |
| `InputEventWithModifiers`, `InputEventMouseMotion`, `InputEventMouseButton` | 1 cada uno | `_input` (settings_service.gd:398-403) |
| `AudioServer` | ~6 | `get_bus_index`, `add_bus`, `set_bus_name`, `set_bus_volume_db`, `set_bus_mute`, `bus_count` (settings_service.gd:428-436) |
| `Engine` | 1 | `Engine.max_fps` (settings_service.gd:414) |
| `ProjectSettings` | 1 | `globalize_path` (settings_service.gd:150) |
| `OS` | ~3 | `OS.get_keycode_string` (:334), `OS.get_cmdline_args` y `get_cmdline_user_args` (:449, 451) |
| `Time` | 3 | `get_datetime_string_from_system` (records_service.gd:93, 321, 379) |
| `RandomNumberGenerator` | 1 | `randomize()`, `randi()` (records_service.gd:83-85) |
| `Node` (base y `PROCESS_MODE_ALWAYS`) | ~6 | `extends Node` (discovery, game_session, records, settings) y `process_mode` (settings_service.gd:93, game_session.gd:75) |
| `RefCounted` | 2 | `extends RefCounted` (save_file.gd:1, run_score.gd:1) |
| `get_viewport()` y sus propiedades | 3 llamadas | `scaling_3d_scale`, `scaling_3d_mode`, `fsr_sharpness` (settings_service.gd:421, 425, 426) |
| `Vector2i` | 8 | `WINDOW_MARGIN`, `RESOLUTIONS`, `size` (settings_service.gd:74-75, 476-492) |
| `call_deferred` | 1 | `place_window.call_deferred()` (settings_service.gd:473) |
| Señales declaradas | 6 | `changed` (4 clases), `revived(restart)` (game_session.gd:5), `display_pending(seconds)` (settings_service.gd:5) |
| `_ready` / `_process` / `_input` | 4 / 2 / 1 | Ver apartado 12. Ningún `_physics_process`. |

Uso de `Dictionary` y `Array` (GDScript): ~62 apariciones de `Dictionary` en la carpeta. Son tipos del lenguaje, no del motor, pero muchos ajustes y partidas son diccionarios con claves de texto (ver apartado 15).

---

## 11. Constantes que definen cómo se siente o se ve

### 11.1 Partida (game_session.gd)

| Constante | Valor | Línea |
|---|---|---|
| `RESTARTS` | 1 | :29 |
| `RESTART_WAIT` | 2.6 s | :42 |
| `RESTART_WAIT_AGAIN` | 0.6 s | :45 |
| Duración de `TRANSITION` | 1.2 s | :321 |
| `solo_restarts` (en solitario) | 0 | :33 |
| Cuórum | ceil(roster / 2), mínimo 1 | :103 |
| Versión del formato de estado | 2 | :219 |

### 11.2 Puntaje (run_score.gd)

| Constante | Valor | Línea |
|---|---|---|
| `TV` | 150 | :14 |
| `DIGIT` | 200 | :15 |
| `CODE` | 250 | :16 |
| `SEARCH` (mueble registrado) | 10 | :17 |
| `ROOM` (sala pisada) | 5 | :18 |
| `ESCAPE` (salida) | 120 | :19 |
| `SECTOR` (sector cerrado en pie) | 150 | :20 |
| `OUT` (salió del piso) | 300 | :21 |
| `INTACT` (sin morir) | 250 | :22 |
| `DEATH` (cada muerte) | -200 | :23 |
| Topes: búsqueda 30, salas 60, salidas 5 | | :26-28 |
| `TIME_RATE` (por segundo bajo la marca) | 1.0 | :32 |
| `TIME_CAP` | 1500 | :33 |
| `CLEAN` (sin bajas) | 500 | :34 |
| `BRAVE` (sin esconderse) | 300 | :35 |
| `WHOLE` (equipo entero) | 300 | :36 |
| `COLLAPSE` (derrumbe) | -300 | :37 |
| `SHARE` (cada compañero cuenta) | 0.3 | :42 |
| Notas `S` 4800, `A` 4000, `B` 3200, `C` 2400, si no `D` | | :43-44 |

Partes (`TITLES`, :54-66) con su mínimo (`least`) y su marca (`mark`):
- ELECTRICISTA: mínimo 2 televisores (:56).
- SABUESO: mínimo 2 números (:57).
- ESCAPISTA: mínimo 2 salidas, marca 3 (:58).
- CEBO: mínimo 45 s perseguido, marca 90 (:59).
- EL DEL ARMARIO: mínimo 60 s dentro, marca 120 (:60).
- MANOS LARGAS: mínimo 8 muebles, marca 20 (:61).
- EXPLORADOR: mínimo 25 salas, marca 70 (:62).
- MARATONISTA: mínimo 600 m, marca 2500 (:63).
- AL BORDE: 1 vez sin cordura (:64).
- CARNE DE CAÑÓN: mínimo 2 caídas, marca 2 (:65).
- CERRAJERO: marcar el código de la última puerta (:55).

### 11.3 Registro (records_service.gd)

| Constante | Valor | Línea |
|---|---|---|
| `KEPT` (líneas por tabla) | 24 | :23 |
| `RIVALS_KEPT` | 24 | :43 |
| `EVENTS_KEPT` | 120 | :179 |
| Tope de tiempo de cinta | 360000 s | :141 |
| Jugadores por cinta | 1 a 8 | :140 |

### 11.4 Ajustes (settings_service.gd)

| Constante | Valor | Línea |
|---|---|---|
| `STICK_DEADZONE` | 0.15 | :46 |
| `TRIGGER_DEADZONE` | 0.5 | :33 |
| `WINDOW_MARGIN` | (48, 96) px | :74 |
| `RESOLUTIONS` | 1280x720, 1600x900, 1920x1080, 2560x1440 | :75 |
| Cuenta atrás para confirmar ventana | 12 s | :219 |
| Escalado de la nitidez | `lerpf(2.0, 0.0, sharpness)` | :426 |
| Decibelios | `linear_to_db(max(v * 2, 0.0002))` | :497 |
| Mínimo de volumen, sensibilidad, mirada del mando | 0.0005 a 0.008; 0.6 a 6.0 | :196-197 |
| FPS permitidos | 0, 30, 60, 120, 144 | :195 |
| Valores por defecto de sensibilidad y mirada | 0.0022 y 2.6 | :6 |

### 11.5 Escena y render (project.godot)

Ver apartado 8.3 y `project.godot:21-69`.

---

## 12. Orden de ejecución, física, azar y señales

**Señales (declaradas y conectadas):**

| Señal | Declarada en | Conectada en |
|---|---|---|
| `GameSession.changed` | game_session.gd:2 | `hotel_main.gd:304` (`on_state`) |
| `GameSession.revived(restart)` | game_session.gd:5 | `hotel_main.gd:305` (`on_revived`) |
| `Records.changed` | records_service.gd:15 | `hotel_main.gd:318` (`tell_steam`) |
| `Settings.changed` | settings_service.gd:4 | `hotel_main.gd:327` (`apply_settings`) |
| `Settings.display_pending(seconds)` | settings_service.gd:5 | `hotel_ui.gd:362` (`_display_changed`) |
| `Discoveries.changed` | discovery_service.gd:4 | Sin conexión en `game/` (búsqueda). |

**Procesos:**
- No hay `_physics_process` en la carpeta. Todo el tiempo de los servicios va en `_process(delta)` (game_session.gd:310-337; settings_service.gd:502-507). Es decir, depende del fotograma, no de un paso fijo.
- `game_session._process`: suma el tiempo jugado solo en `PLAYING` (311), cuenta la espera de reinicio (313-317) y la transición de 1.2 s (319-337). Solo si es la autoridad (312).
- `settings_service._process`: cuenta atrás de confirmación de ventana (503-507).
- `settings_service._input` (397-410): se ejecuta antes que el juego. Marca el último mando usado (`last_pad`, `using_pad`) y suelta acciones de modificadores (410).

**Diferido y orden:**
- `apply_display()` llama a `place_window.call_deferred()` (settings_service.gd:473). El comentario dice que al salir de pantalla completa el rectángulo antiguo puede volver un fotograma después.
- `tell_steam.call_deferred()` (hotel_main.gd:320).
- En `_ready` de Settings, `apply()` va después de `write_renderer()` (98) y antes de `apply_display()` (99).
- `apply()` (412-437) llama primero a `apply_bindings()` (413).
- `records.file()` aplica en orden: `tally`, `reach`, y después `record` solo si ganó (123-125).
- `game_session.start()` olvida el estado y escribe el checkpoint antes de pasar a `PLAYING` (96-101).
- `settings.save_path` se cambia en `_enter_tree` del nivel, antes de la carga de `Settings._ready` (hotel_main.gd:214).

**Azar:**
- Único sorteo en la carpeta: el identificador de la cuenta, `RandomNumberGenerator` con `randomize()` (records_service.gd:83-85). No tiene semilla. Solo se usa si el archivo no tiene `id`.
- `run_seed` lo fija quien llama a `start()` (game_session.gd:82-83). Los servicios no generan semillas.

**Orden de las colecciones (Dictionary):**
- `participants` (game_session.gd:52, 114, 162, 177, 196-197): el orden de recorrido es el de inserción. Sin comprobar en la doc del motor.
- `bindings` y `pad_bindings` (settings_service.gd:337, 354, 404): se recorren en el orden de inserción. Esto decide el orden de los eventos de cada acción.
- `rivals` (records_service.gd:385-386, 398): la expulsión y el orden por fecha de vista. Empates: sin comprobar si la ordenación es estable.
- `board.sort_custom` (records_service.gd:201-202): los empates de tiempo y puntaje no tienen desempate por nombre.

**Reloj de pared:** las fechas de las cintas, las tarjetas y el registro de hitos usan el reloj del sistema (apartado 6). No dependen del juego.

**Dispositivos:** `pad_family()` y `button_name()` dependen de los mandos conectados (settings_service.gd:275-292). `DisplayServer` depende de la pantalla actual (`window_get_current_screen`, :484).

---

## 13. Pruebas de `tests/` que vigilan esta parte

Búsqueda por nombres de servicio, clases, rutas y campos. No se abrió cada archivo; las referencias son las de la búsqueda.

| Prueba | Qué vigila (según la búsqueda) |
|---|---|
| `tests/hotel/continue_test.gd` | Continuar: checkpoint, estado guardado, escritura fallida, `.bak`, checkpoint sin número de piso, versión incompatible, `session.state_path()` (líneas 3-195). Es la prueba más directa de `game_session.gd` y de `save_file.gd`. |
| `tests/hotel/hotel_test.gd` | Estados `PLAYING`, `WON`, `FAILED`; reintento; checkpoint incompatible (`999`); respaldo con semilla 123 (678-711). |
| `tests/hotel/difficulty_test.gd` | Reinicios y reinicios en solitario (`SESSION` precargado en 14; 380-424); dificultad guardada en la cinta (426). |
| `tests/hotel/stages_test.gd` | Etapas, objetivos y `records`. |
| `tests/hotel/rules_test.gd` | Tablón de compañía «custom» y hitos no alcanzados (131-132). |
| `tests/hotel/bots_test.gd` | El piso de bots no toca el checkpoint (42-57) ni el tablón (45, 139). |
| `tests/hotel/scene_contract_test.gd` | Teclas modificadoras (`MODIFIER_FLAGS`), ruta de récords de prueba (189) y el resto de ajustes. |
| `tests/hotel/loop_test.gd` | Descubrimientos y precarga de servicios. |
| `tests/hotel/intro_test.gd` | `CUTSCENE` a `PLAYING` (29, 43, 61). |
| `tests/hotel/hotel_batch.gd`, `hotel_walkthrough.gd` | `session.state` (110 en walkthrough, 22 y 110 en batch). |
| `tests/net/net_test.gd` | Sesión replicada y estados de `level.session` (139-805). También aparece en la búsqueda de `records`; ese uso no se ha revisado. |
| `tests/office/descend_test.gd` | `session.floor_number` y `state` del piso 2 (29-31). |
| `tests/office/office_test.gd` | Aparece en la búsqueda amplia de servicios (2 coincidencias). No se ha revisado qué comprueba. |
| Pruebas con `settings` (15 archivos) | Incluye `tests/hotel/hotel_test.gd`, `survival_test.gd`, `echo_test.gd`, `hotel_audio_test.gd`, `sanity_test.gd`, `spatial_audio_test.gd`, `office_audio_test.gd`. Solo medido el número de menciones, no su uso. |

Nota: en `tests/hotel/capture_test.gd` y `tests/office/lurker_capture_test.gd`, el término «records» es `blood.records` (la sangre de la captura), no el servicio. No cuentan para esta ficha.

---

## 14. Discrepancias en la documentación y el código

1. **Versión.** `project.godot:18` y `docs/CHANGELOG.md:73` dicen 1.3.0. `docs/DEVELOPMENT.md:3` y `:444` dicen «juego 1.2.0» (la última versión en 444 es la 1.2.0 del 20 de octubre). La guía está atrasada.
2. **Pantalla de versión.** `docs/DEVELOPMENT.md:439` dice que el menú muestra «v1.0.0   PROYECTO FAN NO OFICIAL». El código de `hotel_ui.version()` devuelve solo `"v" + versión` (hotel_ui.gd:10-11). El texto «PROYECTO FAN NO OFICIAL» no aparece en esa función; no se buscó en el resto.
3. **Duración de las pruebas.** `Verificar.cmd:2` dice «unos 25 minutos». `docs/DEVELOPMENT.md:433` dice «todo en 4,5 minutos en este equipo».
4. **Número de pruebas.** El encargo mencionaba 106 archivos de prueba. `find tests -name "*.gd"` da 54.
5. **Modo de ventana.** `project.godot:34` pone `window/size/mode = 3` (pantalla completa de Godot). El ajuste por defecto `window_mode = 0` del jugador se traduce a pantalla completa exclusiva (settings_service.gd:466-468). Son dos cosas distintas y el código aplica la segunda.
6. **Repositorio.** La guía (DEVELOPMENT.md:3) y la memoria del autor dicen «repositorio privado `AndresBlue/the-four`». No se comprobó contra el remoto de git, porque no se ejecutó git.

---

## 15. Hechos que complican el port (sin proponer diseño)

- **Formato binario de estado de piso** (`hotel_checkpoint.state`): es `store_var` de Godot, con vectores y tablas indexadas por asiento (game_session.gd:213-215, 223-252). Leerlo fuera de Godot exige reimplementar ese formato o migrar.
- **JSON con tipos de Godot:** el código lee los números de los archivos JSON comprobando `is float or is int` (game_session.gd:278, 282; settings_service.gd:188, 281). Cómo entrega Godot los enteros de JSON no está comprobado en la doc local.
- **Rutas `user://` y nombre de carpeta** con guion largo: `THE FOUR — Hotel` (project.godot:17, CLAUDE.md).
- **Teclas por código físico** (`physical_keycode`, settings_service.gd:344) y botones de mando por enumeración de Godot (`JOY_BUTTON_*`, `JOY_AXIS_*`, :19-42).
- **Acciones de `InputMap` con nombres de Godot** (`ui_accept`, `ui_cancel`, `ui_up`, etc., :39-42, 358-368). Algunos eventos se añaden o se quitan a mano.
- **Ventana y pantalla:** `DisplayServer` con modos de Godot (`WINDOW_MODE_EXCLUSIVE_FULLSCREEN`, `WINDOW_MODE_FULLSCREEN`, `WINDOW_MODE_WINDOWED`), con la particularidad de que la posición se corrige un fotograma después (settings_service.gd:472-473).
- **Escalado 3D y nitidez** con la API de Godot: `scaling_3d_mode`, `scaling_3d_scale`, `fsr_sharpness` (settings_service.gd:421-426). El valor de `sharpness` se invierte al traducirlo (:423-424).
- **Renderer al arrancar:** `user://renderer.cfg` como override de `project.godot:20`. No se puede cambiar en caliente (settings_service.gd:156-157).
- **Steam:** AppID 480 en la configuración del proyecto (project.godot:73) y GodotSteam como extensión (`addons/godotsteam/`). La inicialización ocurre al arrancar el motor (project.godot:74).
- **Export:** el zip de Windows lleva cuatro archivos fijos (`TheFour.exe`, `TheFour.pck`, `steam_api64.dll`, la DLL de GodotSteam) con carpeta `The Four/` (godot.ps1:148, 152-159).
- **Detección de ventana de prueba** por argumentos de línea de comandos y por extensión `.gd` (settings_service.gd:447-452). Depende de cómo se lanza.
- **Azar y reloj:** sin semillas en los servicios. Las fechas usan el reloj del sistema (apartado 12).

---

## Sin comprobar

- **`docs/DEVELOPMENT.md`, líneas 61-412:** leídas solo por palabras clave. No se leyeron completas las reglas de sala, las dificultades (165-196), el piso nuevo (197-232) ni el piso 2 (233-412).
- **Archivos no leídos que los servicios usan:** `game/floors/difficulty.gd`, `game/floors/floor_index.gd` (`kind`, `built`, `COUNT`, `milestones`), `game/floors/match_rules.gd`, `game/presentation/graphics_presets.gd` (`PRESETS`, `VERY_LOW`, `scaling_mode`, `UPSCALERS`, `ANTIALIASING`, `SCALING_MODES`), `game/world/generation/floor_definition.gd` (`FLOOR.VERSION`). Por eso no se conocen los nombres ni los valores exactos de los presets y las dificultades.
- **Archivos mencionados y no leídos:** `tools/verify.ps1`, `tools/bots.ps1`, `tools/dev/record_floor2.ps1` (`Registrar piso 2.cmd`), `tools/net_test.ps1`.
- **Código de red:** `game/net/net_session.gd`, `game/net/steam_link.gd` (solo búsqueda), `game/net/match_net.gd` (solo búsqueda).
- **`game/app/hotel_main.gd` fuera de 180-330** y `game/ui/hotel_ui.gd` fuera de 10-11 y 362 (solo búsqueda).
- **Pruebas:** no se abrió ninguna prueba completa. Las referencias son de búsqueda. El número de líneas de cada prueba que cubre cada punto no se ha verificado.
- **Orden exacto de `_ready` entre hermanos** (Settings, GameSession, Records, Discoveries): inferido del ciclo de vida de Godot, no comprobado en la documentación local ni ejecutado.
- **Valor de gravedad por defecto de Godot:** no comprobado. Solo se sabe que el proyecto pone 20.0.
- **Estabilidad de `sort_custom` y orden de `Dictionary`** en Godot 4.7.2: no comprobado.
- **`script_export_mode = 2`:** significado no comprobado.
- **Exportador y versiones:** que el exportador tome la versión del proyecto (DEVELOPMENT.md:439) no está comprobado en el código de Godot.
- **Etiquetas de git** (`vX.Y.Z`): viene de la guía (DEVELOPMENT.md:442). No se ejecutó git, así que no se ha comprobado en el repositorio.
- **Capas de física 2, 8 y 9 y los números 1, 8 y 64** que cita DEVELOPMENT.md:55: no comprobado su significado.
- **Carpeta real del jugador** (`%APPDATA%\Godot\app_userdata\THE FOUR — Hotel`): viene de CLAUDE.md, no se ha listado (y no debe tocarse).
- **Conteo de apariciones (apartado 10):** es una búsqueda por palabra en la carpeta, no un análisis del código. Puede contar comentarios.
- **Ajuste `character = 2`:** el mapa de índice a personaje no se ha leído.
- **Consumidores:** la lista del apartado 2 es una búsqueda por nombre. No hay una lectura completa de cada consumidor.
