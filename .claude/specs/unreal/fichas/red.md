# Ficha de hechos: red (online)

Fecha de lectura: 14 de noviembre de 2026. Repositorio: `E:\Projects\The Four`.
Todas las referencias son `ruta:línea` relativas a la raíz del repo. Nada de lo de aquí se ejecutó: solo se leyó código.

Método: lectura completa de `game/net/` (5 archivos GDScript y el de diagnóstico), de `tests/net/net_test.gd` y de `tools/net_test.ps1`; `addons/godotsteam/godotsteam.gdextension` completo y `addons/godotsteam/readme.md` solo hasta la línea 40; búsquedas con Grep en `game/` (fuera de `game/net/`) de `rpc`, `multiplayer`, `Steam`, `MultiplayerSynchronizer`, `MultiplayerSpawner`, `ENetMultiplayerPeer`, y de las funciones que llama la red. Tramos de otros archivos se citan donde se usan. Lo no leído está en la sección 16.

---

## 1. Inventario de archivos leídos

| Archivo | Líneas | Qué hace |
|---|---|---|
| `game/net/net_session.gd` | 448 (leído entero) | Sala: conexión (ENet o Steam), asientos, nombres, personajes, opciones del anfitrión, arranque de partida, desconexiones. Nodo raíz "Net". 5 RPC. |
| `game/net/match_net.gd` | 1231 (entero) | Replicación de la partida: 50 RPC, estado de jugadores y criatura, puertas, armarios, televisores, cajones, paneles, código, ascensores, ejecuciones, objetivos de planta 2, hoja compartida, fotos, reincorporación (`catch_up`/`restore`), checkpoint. Nodo "Match" (hijo de Net). |
| `game/net/remote_player.gd` | 299 (entero) | Cuerpo de otro superviviente en esta máquina: interpolación de estados, linterna, cámara, pasos, armario, muerte. |
| `game/net/steam_link.gd` | 336 (entero) | Entrada por Steam: lobby, invitaciones, amigos, `SteamMultiplayerPeer`, logros, presencia, overlay. Nodo "Steam" (hijo de Net). |
| `game/net/steam_diagnose.gd` | 38 (entero) | Modo `--steam-diagnose`: imprime métodos, señales y constantes de GodotSteam que usa el juego. |
| `tests/net/net_test.gd` | 806 (entero) | Prueba de extremo a extremo con un proceso por rol (host, alpha, bravo, vs_*, late_*, watch_*, office_*). |
| `tools/net_test.ps1` | 39 (entero) | Lanza los procesos Godot de cada escenario y recoge `evidence/net_<rol>.json`. |
| `addons/godotsteam/godotsteam.gdextension` | 32 (entero) | Rutas de la extensión por plataforma y arquitectura. |
| `addons/godotsteam/readme.md` | 95 (leído 1-40) | Versión del plugin (4.22.1, línea 31) y tabla SDK Steamworks / plugin (líneas 44-50). |

Otros archivos leídos por tramos (los que usa la red):

- `game/app/hotel_main.gd`: 300-325 (señales de red), 440-480 (observador), 575-620 (acciones del menú de red), 832-905 (`build_floor`), 1005-1135 (`start_online_floor`, `begin_online_play`, `leave_online_floor`, `on_net_closed`, `locust_hear`), 1151-1160, 1573-1600 (`catch_up_progress`), 1709-1716 (`objective_snapshots`), 1950-1958 (televisores).
- `game/app/televisions.gd`: 45-130.
- `game/world/hotel/hotel_geometry.gd`: 2920-2932 (`lit`, `set_room_power`).
- `game/enemies/lurker/lurker.gd`: 488-512 (`pack_state`, `push_state`), 1295-1298 (`tell`), 1425-1452 (`play_cue`), 1473-1524 (`drain_step`, `_process` de luz).
- `game/enemies/locust/hotel_locust.gd`: 1227-1252 (`pack_state`, `push_state`, `follow_state`).
- `game/services/game_session.gd`: 145-165 (`drop`, `returned`, `check_quota`).
- `tests/hotel/creature_contract_test.gd`: 84-135 (contrato RPC), 1636-1700 (prueba de cable).
- `tests/hotel/observer_test.gd`: 55-64.
- `project.godot`: secciones `[physics]` (51) y `[steam]` (71-74).
- `.claude/godot-api/VERSION`: `4.7.2.stable.steam.ed1daf0bf`.
- `.claude/godot-api/modules/multiplayer/doc_classes/SceneMultiplayer.xml` y `doc/classes/MultiplayerPeer.xml`: solo los valores por defecto de `server_relay` y de `TRANSFER_MODE_*`, y `ENetMultiplayerPeer.create_server` (`max_clients`, por defecto 32).

---

## 2. Topología y límites

- **Estrella con anfitrión autoritario.** El anfitrión es la autoridad de todas las RPC `authority` (`net_session.gd:283-409`, `match_net.gd:107-1204`). Los invitados hablan solo con el anfitrión.
- **Relay a mano.** `server_relay` se pone a `false` en `net_session.gd:127`. Por defecto Godot lo tiene en `true` (`.claude/godot-api/modules/multiplayer/doc_classes/SceneMultiplayer.xml`). El anfitrión reenvía lo de un invitado a los demás con `relay()` (`match_net.gd:297-300`), por `multiplayer.get_peers()` excepto el remitente.
- **Asientos.** Anfitrión = asiento 1 (`net_session.gd:130-131`). Invitados = asientos 2..6 (`net_session.gd:328-331`). Observadores = sin asiento (`net_session.gd:291-297`; el observador recibe `welcome(0)`, y `observing = seat == 0` en `net_session.gd:349`).
- **Máximos.**
  - Sala: `MAX_PLAYERS = 6` asientos (`net_session.gd:30`). `register` rechaza el séptimo (`net_session.gd:318-319`).
  - Supervivientes: `MAX_SURVIVORS = 5` (`net_session.gd:31`). Coop: `start_problem` pide como mucho 5 conectados (`net_session.gd:400`). Versus: `seats_for(VERSUS) = 6` (5 supervivientes más The Locust, `net_session.gd:406-407`).
  - Mínimo para empezar: `MIN_PLAYERS = 2` (`net_session.gd:37`, `398`).
  - Observadores: `OBSERVERS = 2` (`net_session.gd:36`) entra solo en el tope de ENet: `create_server(port, MAX_PLAYERS - 1 + OBSERVERS)` = 7 clientes (`net_session.gd:110`). **`register` no cuenta observadores**: no hay tope propio (`net_session.gd:291-297`).
  - Steam: `createLobby(..., net.MAX_PLAYERS)` = 6 miembros (`steam_link.gd:140`). Los observadores solo entran por IP (`hotel_main.gd:457` y `476` usan `join_observer`, que va por ENet).
- **Personajes.** Tres (`clampi(character, 0, 2)`, `net_session.gd:332`, `392`).
- **Nombres.** `clean_name` recorta a 18 caracteres y pone "Jugador" si queda vacío (`net_session.gd:221-223`). Un nombre repetido en la sala pasa a "Nombre 2", "Nombre 3"… (`net_session.gd:321-327`), con la base recortada a 15 (`net_session.gd:326`).
- **Versión.** `PROTOCOL = "the-four-net-22"` (`net_session.gd:39`) más `hash(JSON.stringify(FLOORS.versions()))` (`net_session.gd:258`, `288`). Si no coinciden, `refuse` con "Versiones distintas del juego: actualizad todos al mismo exe." (`net_session.gd:289`). En Steam, los datos del lobby llevan `game = "the_four"` y `protocol` (`steam_link.gd:33`, `149-150`), y el invitado los comprueba al entrar (`steam_link.gd:218-223`).

---

## 3. Transporte, puertos y plugin

### IP (ENet)

- Anfitrión: `ENetMultiplayerPeer.new()` (`net_session.gd:108`), `set_bind_ip(bind)` (`109`; `bind` por defecto `"*"`, `56`, `103`), `create_server(port, 7)` (`110`).
- Puerto del anfitrión: `PORT = 38430` por defecto (`net_session.gd:27`), validado entre 1024 y 65535 (`net_session.gd:105-106`). Ajustes del menú: `port_setting("host_port")` y `settings.values.host_bind` (`hotel_main.gd:580`).
- Invitado: `create_client(address.strip_edges(), port)` (`net_session.gd:152`), puerto entre 1 y 65535 (`net_session.gd:148-149`). Ajuste `port_setting("join_port")` (`hotel_main.gd:588`).
- Observador: `join(...)` con `net.PORT` o `--port=` (`hotel_main.gd:451-457`).
- Dirección que se le enseña al jugador: IPs locales (`IP.get_local_addresses()`, `net_session.gd:236`; se filtran 127.*, 169.254.* y las que no son IPv4, `237`) y el texto "puerto UDP abierto hacia este equipo" (`net_session.gd:231`).
- Puertos de pruebas: `24600` (`tests/net/net_test.gd:13`; `tools/net_test.ps1:1`), `24688` (`tests/hotel/rules_test.gd:160`).

### Steam (`SteamMultiplayerPeer`)

- El peer no está tipado: `ClassDB.instantiate("SteamMultiplayerPeer")` (`steam_link.gd:156`, `226`). Anfitrión: `create_host(0)` (`157`). Invitado: `create_client(owner_steam_id, 0)` (`227`). Puerto virtual 0. Steam no usa puertos.
- AppID: el ajuste del plugin es `steam/initialization/app_data/app_id` (`steam_link.gd:29`). `DEV_APP_ID = 480`, Spacewar (`steam_link.gd:30`). En el proyecto: `[steam]` con `initialization/app_data/app_id=480` (`project.godot:73`) e `initialize_on_startup=true` (`project.godot:74`).
- Solo si GodotSteam carga: `installed()` comprueba `Engine.has_singleton("Steam")` y `ClassDB.class_exists("SteamMultiplayerPeer")` (`steam_link.gd:50-51`). No se arranca en headless ni con `--automation` (`steam_link.gd:67-69`).
- Arranque: si Steam ya arrancó al iniciar el motor (`api.getAppID() > 0`, `steam_link.gd:75-76`), no se inicia otra vez; si no, `steamInitEx(app_id, false)` (`steam_link.gd:81`) con `SteamAppId` y `SteamGameId` en el entorno (`79-80`). Sin sesión iniciada: "Steam está abierto pero sin conexión." (`steam_link.gd:86-89`).

### Plugin GodotSteam

- Versión: GodotSteam 4.22.1 (`addons/godotsteam/readme.md:31`, y el propio juego lo dice en `steam_link.gd:19`). Tabla del readme: SDK Steamworks 1.65 pide plugin 4.21 o superior (`readme.md:44-46`).
- Archivos presentes: `win64/libgodotsteam.windows.template_debug.x86_64.dll`, `win64/libgodotsteam.windows.template_release.x86_64.dll` (3 961 344 bytes), `win64/steam_api64.dll` (versión de archivo 10.83.75.46, no confirmada como SDK 1.65), `osx/libgodotsteam.macos.template_debug.universal.dylib`, `osx/libgodotsteam.macos.template_release.universal.dylib`, `osx/libsteam_api.dylib`.
- **Faltan en la carpeta** rutas que nombra `godotsteam.gdextension`: Linux x86_64, Linux arm64, Linux x86_32, Android arm64 y Windows x86_32 (`godotsteam.gdextension:6-13`, `21`, `23`, `26-29`, `32`). El de Windows debug y release de 64 bits sí está (`:20`, `:22`).
- `godotsteam.gdextension`: `entry_symbol = "godotsteam_init"` (`:2`), `compatibility_minimum = "4.4"` (`:3`). Línea 16-19: comentario local que dice que Steam solo se carga en el juego exportado (`template_*`).
- Nota del propio archivo: "The Steam edition of the Godot editor has its own, older steam_api64.dll" (`godotsteam.gdextension:17-18`): en el editor no hay Steam.

---

## 4. Tabla de RPC (las 55)

Hechos comunes:

- Las 55 son `@rpc("<modo>", "call_remote", "<canal>")`. Con `call_remote` la llamada no se ejecuta en quien la envía: el anfitrión ejecuta su copia a mano (por ejemplo `match_net.gd:206-207` (`go.rpc()` y luego `go()`), `net_session.gd:435-436` (`begin.rpc(config)` y luego `begin(config)`)).
- "Modo" es el de `@rpc`. "Canal" es el modo de transferencia de Godot. `reliable`, `unreliable`, `unreliable_ordered` (valores en `.claude/godot-api/doc/classes/MultiplayerPeer.xml`).
- Varias RPC se llaman por nombre con `callv` (`match_net.gd:292-300`, `to_everyone` y `relay`): `player_state`, `locust_state`, `player_card`, `office_photo`, `locust_call`, `creature_event_rpc`.
- Fuente de las columnas de "quién llama": grep de `.rpc(` y `.rpc_id(` en `game/net/` y en `game/` fuera de la red (ver las referencias de la tabla).

Notación: "A" = any_peer, "Au" = authority. Canales: "R" = reliable, "U" = unreliable, "UO" = unreliable_ordered.

| # | RPC (archivo:línea) | Modo | Canal | Quién la llama (archivo:línea) | Dirección | Qué manda |
|---|---|---|---|---|---|---|
| 1 | `begin(data, snapshot)` `match_net.gd:107-108` | Au | R | `net_session.gd:435` (inicio); `net_session.gd:296` (observador en partida); `match_net.gd:1134` (vuelve un asiento) | host → todos, o → uno | `config` (seed, mode, locust_seat, survivors, players, rules, floor, difficulty) y `snapshot` (`{"returning": true}` u `{"observer": true}`) |
| 2 | `report_ready(floor_hash)` `match_net.gd:171-172` | A | R | `match_net.gd:158` (`floor_built`, en invitado) | invitado → host | hash del manifiesto del piso construido |
| 3 | `go()` `match_net.gd:210-211` | Au | R | `match_net.gd:206` (y `go()` local en `207`) | host → todos | nada |
| 4 | `player_state(seat, data)` `match_net.gd:334-335` | A | UO | `match_net.gd:280` (`to_everyone`, 20 veces por segundo) y `340` (`relay`) | jugador → host → resto | `[seat, pack_local()]`, 12 campos (`match_net.gd:332`) |
| 5 | `locust_state(data)` `match_net.gd:342-343` | A | UO | `match_net.gd:283` (`to_everyone`) y `352` (`relay`) | quien conduce la criatura → host → resto | `creature.pack_state()`: 6 campos en `hotel_locust` (`hotel_locust.gd:1227-1228`), 12 en `lurker` (`lurker.gd:42`, `490-492`) |
| 6 | `minds_state(told)` `match_net.gd:365-366` | Au | UO | `match_net.gd:362` (`push_session`, 2 veces por segundo) | host → todos | `level.sanity.pack()`: cordura de cada uno |
| 7 | `session_state(state, participants, elapsed, message, stage, goal)` `match_net.gd:369-370` | Au | R | `match_net.gd:361` (2 veces por segundo) y `match_net.gd:1168` (`catch_up`) | host → todos, o → uno | estado, vidas, tiempo, mensaje, etapa y `goal` (incluye `blackout`, `ready`, `done`, `needed`) |
| 8 | `request_door(index, slow, forceful)` `match_net.gd:393-394` | A | R | `match_net.gd:390` (`use_door` en invitado) | invitado → host | índice de puerta; el host comprueba `near_sender` (alcance `REACH = 5.0`, `match_net.gd:32`, `412-415`) |
| 9 | `door_swung(index, target, slow, forceful)` `match_net.gd:400-401` | Au | R | `match_net.gd:144` (señal `door.swung` del host) | host → todos | sentido, lentitud y fuerza del vaivén |
| 10 | `door_settled(index, opened)` `match_net.gd:405-406` | Au | R | `match_net.gd:145` (señal `door.settled`) | host → todos | estado final abierto o cerrado |
| 11 | `request_office(objective, action, index)` `match_net.gd:443-444` | A | R | `match_net.gd:437` (`use_office` en invitado) | invitado → host | objetivo (nombre), acción, índice |
| 12 | `office_state(objective, action, index, seat, data)` `match_net.gd:456-457` | Au | R | `match_net.gd:441` (`tell_office`, host), `match_net.gd:454` (petición aceptada) | host → todos | `data` = resultado de `handler.apply` |
| 13 | `office_photo(seat, bytes)` `match_net.gd:469-470` | A | R | `match_net.gd:466` (host → todos), `467` (invitado → host), `477` (`relay`) | autor → host → resto | JPEG (empieza con `FF D8`, máximo `PHOTO_MAX_BYTES = 24576`, `files_objective.gd:61`) |
| 14 | `office_refused(objective, action, index)` `match_net.gd:480-481` | Au | R | `match_net.gd:451` | host → quien pidió | nada más que la negativa |
| 15 | `request_television(index)` `match_net.gd:501-502` | A | R | `match_net.gd:499` (`use_television` en invitado) | invitado → host | índice del televisor |
| 16 | `television_state(index, value)` `match_net.gd:510-511` | Au | R | `match_net.gd:497`, `508`; `revival.gd:181` | host → todos | encendido o apagado |
| 17 | `request_warp(index)` `match_net.gd:525-526` | A | R | `match_net.gd:523` (`locust_warp` del cazador) | cazador → host | solo en versus (`match_net.gd:527`, comprueba `locust_peer()`) |
| 18 | `warp_state(index)` `match_net.gd:539-540` | Au | R | `match_net.gd:521`, `532`; `televisions.gd:202` | host → todos | televisor de salida |
| 19 | `request_container(index)` `match_net.gd:558-559` | A | R | `match_net.gd:556` | invitado → host | índice del cajón |
| 20 | `container_state(index, value, seat)` `match_net.gd:568-569` | Au | R | `match_net.gd:554`, `565` | host → todos | cajón registrado, quién lo registró |
| 21 | `request_panel(index, action)` `match_net.gd:585-586` | A | R | `match_net.gd:583` (`use_panel`, `interaction.gd:350-351`) | invitado → host | `"open"` o `"power"` (`match_net.gd:587` filtra) |
| 22 | `panel_state(index, action)` `match_net.gd:594-595` | Au | R | `match_net.gd:581`, `592` | host → todos | acción aplicada |
| 23 | `request_code(text)` `match_net.gd:608-609` | A | R | `match_net.gd:606` (`use_code`) | invitado → host | el texto escrito; el host lo compara con su propio código (`match_net.gd:611-612`) |
| 24 | `code_state()` `match_net.gd:617-618` | Au | R | `match_net.gd:604`, `615` | host → todos | nada (código aceptado) |
| 25 | `revived_state(places, restart, creature_at)` `match_net.gd:627-628` | Au | R | `match_net.gd:625` (`revive_everyone`, llamado desde `revival.gd:43`) | host → todos | posiciones de cada uno, si se reinicia la etapa, dónde vuelve la criatura |
| 26 | `request_lift(index)` `match_net.gd:640-641` | A | R | `match_net.gd:638` (`call_lift`, `interaction.gd:327`) | invitado → host | índice del ascensor; el host comprueba `in_car` con `RIDE_SLACK` (`match_net.gd:644`) |
| 27 | `ride_state(seat, point)` `match_net.gd:652-653` | Au | R | `match_net.gd:650` (`ride_lift`, `lifts.gd:275`) | host → todos | asiento y punto de salida |
| 28 | `floor_left()` `match_net.gd:661-662` | Au | R | `match_net.gd:659` (`leave_floor`, `lifts.gd:521`) | host → todos | nada (se vacían las pantallas de viaje) |
| 29 | `locust_rode(point)` `match_net.gd:672-673` | Au | R | `match_net.gd:670` (`locust_ride`, `lifts.gd:187`) | host → todos | punto de salida de la criatura |
| 30 | `request_hide(index, entering, quiet)` `match_net.gd:696-697` | A | R | `match_net.gd:689`, `692` (`use_hide`) | invitado → host | entrar o salir; si sale, si es silencioso |
| 31 | `hide_state(index, seat, quiet)` `match_net.gd:714-715` | Au | R | `match_net.gd:686`, `709`, `712`, `1000`, `1006` | host → todos | `seat > 0` entra, `seat < 0` sale, `seat == local` lo lleva a su propio armario |
| 32 | `hide_forced(index)` `match_net.gd:740-741` | Au | R | `hotel_main.gd:1477`; `match_net.gd:147` (señal `forced`) | host → todos | armario forzado abierto |
| 33 | `player_noise(point, radius, kind)` `match_net.gd:751-752` | A | U | `match_net.gd:749` (`noise` en invitado) | invitado → host | ruido que oye la criatura (solo el host la escucha, `match_net.gd:753`) |
| 34 | `play_world_sound(path, point, gain, start)` `match_net.gd:769-770` | Au | R | `match_net.gd:767` (`world_sound`, solo host); `pacing_director.gd:774`, `791`; `lurker.gd:1334` | host → todos | ruta (solo `res://assets/audio/`), punto, ganancia, inicio |
| 35 | `creature_event_rpc(kind, data)` `match_net.gd:780-781` | A | R | `match_net.gd:778` (`creature_event`, `to_everyone`); `match_net.gd:785` (`relay`); `lurker.gd:1298` (`tell`) | quien conduce → host → resto | tipo de evento y datos (`tile`, `scare`, `torch`, `snuff`, según `lurker.gd:227`, `890`, `1577`, `1634`) |
| 36 | `locust_call(kind, segment, pitch)` `match_net.gd:793-794` | A | R | `match_net.gd:791` (`creature_call`); `match_net.gd:798` (`relay`); llamadores en `hotel_locust.gd:516`, `542`, `601`, `956`, `1136`, `1158`, `1370` | quien conduce → host → resto | `grunt`, `cry`, `howl`, `warning`, `doubt`, `lost` |
| 37 | `strike(origin, facing)` `match_net.gd:820-821` | A | R | `match_net.gd:818` (`locust_strike`, `locust_player.gd:204`) | cazador → host | origen y mirada del golpe |
| 38 | `request_force(index)` `match_net.gd:854-855` | A | R | `match_net.gd:852` (`locust_open_hide`, `locust_player.gd:456`) | cazador → host | armario |
| 39 | `request_shriek()` `match_net.gd:867-868` | A | R | `match_net.gd:865` (`locust_shriek`, `locust_player.gd:334`) | cazador → host | nada |
| 40 | `shriek_reveal(points)` `match_net.gd:910-911` | Au | U | `match_net.gd:908` (`update_shriek`, host) | host → cazador | `PackedVector3Array` de posiciones que el chillido encontró |
| 41 | `heard_contact(point, apparent, distance, strength, kind, muffle)` `match_net.gd:925-926` | Au | U | `match_net.gd:923` (`tell_hunter`, `hotel_main.gd:1149`) | host → cazador | lo que oye la criatura, como se lo oye |
| 42 | `execute_start(seat, point, yaw, data)` `match_net.gd:970-971` | Au | R | `executions.gd:193` | host → todos | víctima, punto, giro, datos de la captura |
| 43 | `tell_lens(id, rest, seen)` `match_net.gd:976-977` | A | R | `executions.gd:552` | víctima → host | transformada de la cámara que cae y si se ve |
| 44 | `lens_settled(id, rest, look)` `match_net.gd:987-988` | Au | R | `executions.gd:560` | host → todos | cámara asentada y si la criatura la mira |
| 45 | `floor_summary(line)` `match_net.gd:1012-1013` | Au | R | `match_net.gd:1010` (`tell_summary`, llamado en `hotel_main.gd:1276`) | host → todos | línea del parte del piso |
| 46 | `player_card(seat, said)` `match_net.gd:1031-1032` | A | R | `match_net.gd:1029` (`say_card` en `go()`); `match_net.gd:1037` (`relay`) | cada uno → host → resto | ficha del jugador (`records.card`); el nombre lo pone el anfitrión (`match_net.gd:1036`) |
| 47 | `sheet_chunk(op_id, kind, points)` `match_net.gd:1062-1063` | A | R | `match_net.gd:1060` (`sheet_local`, `hotel_main.gd:302`) | invitado → host | trazo en trozos; máximo 128 puntos (`match_net.gd:1070`) y 30 por segundo y asiento (`match_net.gd:1046`, `1072-1077`) |
| 48 | `sheet_confirmed(op_id, kind, points)` `match_net.gd:1081-1082` | Au | R | `match_net.gd:1058`, `1079` | host → todos | trazo confirmado |
| 49 | `restore(doors, hides, places, creature_state, sheet, sets, progress)` `match_net.gd:1170-1171` | Au | R | `match_net.gd:1167` (`catch_up`) | host → quien vuelve o mira | estado completo del piso para reincorporarse |
| 50 | `back_to_room()` `match_net.gd:1203-1204` | Au | R | `net_session.gd:442` (`return_to_lobby`) | host → todos | nada (vuelta a la sala) |
| 51 | `register(protocol, generator, player_name, character, observer)` `net_session.gd:283-284` | A | R | `net_session.gd:258` (`_connected`) | invitado → host | protocolo, hash de versiones, nombre, personaje, si mira |
| 52 | `refused(reason)` `net_session.gd:342-343` | Au | R | `net_session.gd:338` (`refuse`) | host → uno | motivo |
| 53 | `welcome(seat)` `net_session.gd:346-347` | Au | R | `net_session.gd:295` (observador, asiento 0), `333` | host → uno | asiento asignado |
| 54 | `lobby_state(seats, host_options, playing)` `net_session.gd:360-361` | Au | R | `net_session.gd:357` (`broadcast_lobby`) | host → todos | `seats` (con el `peer` de Godot de cada asiento), `options`, si se juega |
| 55 | `profile(character)` `net_session.gd:388-389` | A | R | `net_session.gd:386` (`set_character`) | invitado → host | personaje |

Cuenta: 50 en `match_net.gd` (`grep -c "^@rpc"`) y 5 en `net_session.gd`. Los nombres y el número de argumentos de las 50 de `match_net.gd` están fijados en `tests/hotel/creature_contract_test.gd:86-89` (lista `RPCS`, 50 entradas). Las 5 de `net_session.gd` no están en esa lista.

---

## 5. Estado que se sincroniza y cada cuánto

| Qué | Cada cuánto | Canal | Dónde | Notas |
|---|---|---|---|---|
| Cuerpo del superviviente (posición, giro, mirada, velocidad, banderas, armario, asomos, cámara, zoom, foco) | 20 por segundo (`SEND_RATE`, `match_net.gd:23`), en `_physics_process` (`match_net.gd:274-283`) | UO | `player_state`, `pack_local` (`match_net.gd:307-332`) | Banderas: 1 agachado, 2 linterna encendida, 8 leyendo (`match_net.gd:311`). Bit 4 retirado (`match_net.gd:309-310`). |
| Criatura (posición, giro, velocidad, modo, gracia, mirada) | 20 por segundo, solo si la máquina conduce y no es `puppet` (`match_net.gd:282-283`) | UO | `locust_state` | `hotel_locust`: 6 campos. `lurker`: 12 campos (`PACK_SIZE`, `lurker.gd:42`). |
| Sesión (estado, vidas, tiempo, mensaje, etapa, meta) | 2 por segundo (`SESSION_RATE`, `match_net.gd:24`, `269-272`, `358-361`) | R | `session_state` | Además, a quien vuelve o mira (`match_net.gd:1168`). |
| Cordura de cada uno | 2 por segundo | UO | `minds_state` (`match_net.gd:362`) | El invitado lo aplica solo si `floor_live` (`match_net.gd:367`). |
| Puertas | por evento | R | `door_swung`, `door_settled` | Solo el anfitrión dispara los vaivenes (`match_net.gd:143-145`). |
| Armarios | por evento; asomos y vaivén en `player_state` | R y UO | `hide_state`, `request_hide`, `pack_local` | `remote_player.gd:176-184` aplica asomos y vaivén al armario. |
| Televisores, cajones, paneles, código, ascensores | por evento | R | `television_state`, `container_state`, `panel_state`, `code_state`, `ride_state` | Cada petición del invitado llega al host y el host responde a todos. |
| Objetivos de planta 2 (tarjetas, cuadro de energía, aire) | por evento | R | `office_state`, `office_refused`, `office_photo` | Snapshot a quien vuelve (`hotel_main.gd:1709-1716`). |
| Hoja compartida (trazos) | hasta 30 trozos por segundo y asiento (`match_net.gd:1046`) | R | `sheet_chunk`, `sheet_confirmed` | 3000 operaciones como máximo (`paper_sheet.gd:53`, `match_net.gd:1076`). |
| Tarjeta del jugador | una vez al empezar | R | `player_card` (`match_net.gd:1027-1029`) | Quien mira no guarda tarjetas (`match_net.gd:1039`). |
| Parte del piso | una vez al terminar | R | `floor_summary` (`match_net.gd:1009-1017`) | |
| Ruido del jugador | por evento, sin garantía | U | `player_noise` (`match_net.gd:751`) | |
| Sonidos del mundo | por evento | R | `play_world_sound` | Solo el anfitrión. |

---

## 6. Semilla y generación de la planta

Reparto de la semilla:

- **Quién elige.** Solo el anfitrión (`net_session.gd:410-437`). Si no le pasan una semilla (`seed_value < 0`), toma:
  - la del checkpoint, si la partida es de reanudar (`options.resume`) y el checkpoint es válido (`net_session.gd:418-421`);
  - si no, `randi_range(0, 2147483647)` (`net_session.gd:419`).
- **El modo no sale del checkpoint.** Al reanudar, la semilla y el piso vienen del checkpoint (`net_session.gd:419-421`), pero `config.mode` se toma de `options.mode` (`net_session.gd:424`). El checkpoint guarda `mode` (`match_net.gd:1213`), y no se lee.
- **Locust al azar.** `randi() % seats.size()` si The Locust es RANDOM (`net_session.gd:415`).
- **Reparto.** La semilla viaja en `config.seed` dentro de `begin` (`net_session.gd:435`, `match_net.gd:108-121`, `hotel_main.gd:1049-1052`). No viaja la planta: **cada máquina genera su propia planta** a partir de la semilla.
- **Cómo la genera.** `start_online_floor` llama a `build_floor(config.seed, false, config.survivors.size(), dificultad)` (`hotel_main.gd:1022`). `build_floor` llama a `kind.GENERATOR.new().generate(seed_value, ...)` (`hotel_main.gd:865`).
  - Planta 1 (hotel): `map_generator.gd:105` `generate(run_seed, survivors)`. Cada flujo tiene su `RandomNumberGenerator` con semilla explícita: `hash([run_seed, "floor", attempt])` (`map_generator.gd:140-141`), `[run_seed, "planta", planta, attempt, tried]` (`161-162`), `"rooms"` (`195-196`), `"plaques"` (`199-200`), `"fittings"` (`203-204`), `"wear"` (`207-208`).
  - Planta 2 (oficinas): `office_generator.gd:1013-1015`: `stream(run_seed, attempt, name)`, con `hash([run_seed, "office", name, attempt])`. Flujos: `"tubes"` (`1052`), `"power"` (`1320`), `"glazed"` (`1597`), `"recipes"` (`1780`), `"halls"` (`1846`).
- **Comprobación.** `manifest_hash = hash(JSON.stringify(level.manifest))` (`match_net.gd:131`). Cada invitado lo envía (`report_ready`, `match_net.gd:158`). El anfitrión lo compara (`judge_ready`, `match_net.gd:187-191`). Si no coincide: `refuse` con "Tu piso no coincide con el del anfitrión: usad todos el mismo exe." (`match_net.gd:190`). Si el anfitrión aún no tiene su hash, la respuesta espera en `pending_ready` (`match_net.gd:182-184`, `152-155`).
- **Respaldo local por física.** `build_floor` valida la física del piso en la máquina (`validate_floor_physics`, `hotel_main.gd:958-961`, `kind.VALIDATOR.new().validate_physics(get_world_3d(), manifest)`). Si hay errores, reemplaza la planta por un candidato de respaldo fijo `candidate(404, 0, true)` y lo marca `fallback` (`hotel_main.gd:895-906`). Si ese equipo cae al respaldo y el otro no, el hash no coincide y el anfitrión lo echa (`judge_ready`).
- **Checkpoint (solo anfitrión).** `write_checkpoint` guarda `{"format": 1, "generator", "seed", "floor", "mode"}` en `user://coop_checkpoint.json` (`match_net.gd:30`, `1210-1213`). `saved_checkpoint` valida formato, número de piso y versión del generador (`match_net.gd:1218-1231`). Se escribe al empezar (`match_net.gd:227`) y se borra cuando el piso online acaba en victoria o en derrota (`hotel_main.gd:1250`, `1256`).

---

## 7. Sincronización por entidad

### Jugadores (otros supervivientes)

- Envío: `_physics_process` del anfitrión y de cada invitado, 20 por segundo (`match_net.gd:274-283`). No envía quien está muerto (`match_net.gd:279`).
- Contenido: `pack_local()` (`match_net.gd:307-332`) devuelve `[pos, yaw, pitch, velocidad, banderas, índice de armario, asomo izquierdo, asomo derecho, origen de la cámara, cuaternión de la cámara, zoom, foco]`, 12 campos. Recepción valida 12 (`match_net.gd:338`).
- Recepción en la máquina de otro: `remote_player.push_state` (`remote_player.gd:145-185`) guarda el estado con `time: clock` (`remote_player.gd:162`). **El tiempo es el reloj local de llegada**, no el del emisor. Se interpola en `_physics_process` (`remote_player.gd:212-268`) a `clock - DELAY` (`remote_player.gd:243`), con `DELAY = 0.1` (`remote_player.gd:15`) y un búfer de 12 estados (`remote_player.gd:163`).
- El anfitrión acepta un estado solo si viene del asiento que lo envía (`match_net.gd:337`). Reenvía con `relay` (`match_net.gd:340`).
- Muerte: `set_dead` oculta el cuerpo (salvo que esté caído, `remote_player.gd:124-143`). El sistema de vidas (`level.session.participants`) llega en `session_state`.
- Armario del otro: `remote_enters` / `remote_leaves` (`match_net.gd:725-738`).

### Criatura

- Control: `"ai"` en el anfitrión de coop, `"puppet"` en los demás, `"player"` para el cazador (`hotel_main.gd:1058-1062`; `creature.gd:74` define `set_control`). En versus, el cazador conduce y el anfitrión la ve como réplica del jugador (`hotel_main.gd:1059-1060`).
- Estado: `locust_state` a 20 por segundo desde la máquina que conduce (`match_net.gd:282-283`). En el puppet, `push_state` (`match_net.gd:343-354`), y el movimiento lo suaviza `follow_state` con retardo 0.1 s:
  - `hotel_locust.gd:1250-1252` (búfer de 10, `1241`), llamado desde `hotel_locust.gd:1570`.
  - `lurker.gd:514-517` (búfer de 10, `504`), llamado desde `lurker.gd:554`.
- Eventos fiables de la criatura: `creature_event_rpc` (`match_net.gd:780-787`), que llega al puppet con `on_event` (`match_net.gd:787`). Llamadas de la criatura (gruñidos, aullidos): `locust_call` (`match_net.gd:793-800`), al puppet con `play_call` (`match_net.gd:800`).
- Fuera de la red: la criatura del anfitrión decide quién recibe el golpe (`resolve_strike`, `match_net.gd:828-831`; `strike_victim`, `835-845`, con `validate_strike` de la criatura).

### Puertas y armarios

- El anfitrión decide. Un invitado pide con `request_door` (`match_net.gd:388-398`); el anfitrión lo atiende solo si el invitado está cerca (`near_sender`, `match_net.gd:412-415`, alcance `REACH = 5.0`, `match_net.gd:32`).
- Lo que se ve en cada máquina: `door_swung` y `door_settled` (`match_net.gd:400-409`) llamados desde las señales del anfitrión (`match_net.gd:143-145`). En el invitado: `swing_to` y `set_state`.
- Armarios: `use_hide` (`match_net.gd:680-694`), `request_hide` (`697-712`), con `has_room` y `near_sender` (`match_net.gd:704`). El anfitrión avisa con `hide_state` (`715-723`). Si la criatura ve entrar, se lo dice (`match_net.gd:706-707`).

### Luces

- **Piso 1 (apagón).** No hay RPC de apagón. El apagón está en `session.goal["blackout"]`, que viaja en `session_state` (2 por segundo). Cada máquina aplica `apply_blackout()` o `restore_power()` según la meta (`hotel_main.gd:1185-1186`, `apply_blackout` en `1384`). El anfitrión pone `goal["blackout"] = false` al pasar la tele o el código (`code_lock.gd:218-219`, `revival.gd:184-185`).
- **Televisores.** Pedidos con `request_television` (`match_net.gd:501-508`), que el anfitrión acepta si el invitado está cerca y el televisor sigue apagado. Aplicado con `television_state` → `apply_television` (`televisions.gd:68-86`). La lista de televisores encendidos sale de `lit_televisions` (`televisions.gd:98-102`).
- **Una sala.** `lit(room_id)` (`hotel_geometry.gd:2924-2925`) lee `dark`, `dark_ids`, `unpowered` y `drains` de la máquina. `set_room_power` (`hotel_geometry.gd:2930`) cambia `unpowered`.
- **Piso 2.** El cuadro de energía cambia `set_room_power` (`power_objective.gd:235`) desde `office_state`.
- **Drenaje por la criatura (piso 2).** `drains` se calcula en cada máquina. El `drain_step` de la criatura calcula los objetivos con `SENSES.drain_rooms(level, global_position, ...)` (`lurker.gd:1473-1479`, `lurker_senses.gd:301`) a partir de la posición de la criatura en esa máquina. El temblor de la luz usa `drain_time`, que suma el `delta` de cada máquina (`lurker.gd:1487`, `1502`). **El temblor no está sincronizado.**

### Objetivos (piso 2)

- Uso: `use_office` (`match_net.gd:427-436`). El anfitrión decide con `handler.allow` y `handler.apply`, y avisa con `tell_office` (`match_net.gd:440-441`), o responde a `request_office` (`match_net.gd:443-454`), con `office_state` (`456-459`), que aplican todos si `floor_live`.
- Objetos: `files` (tarjetas, fotos), `power` (cuadro y palanca roja), `air` (ventiladores y escotilla). Llaman a `tell_office`: `air_objective.gd:385`, `files_objective.gd:609`, `646`, `power_objective.gd:316`. Usan la red con `level.net.is_client()`: `files_objective.gd:603`, `641`; `power_objective.gd:314`; `air_objective.gd:365`, `383`.
- Snapshot a quien vuelve: `objective_snapshots` guarda los que dicen `snapshotted()` (`hotel_main.gd:1709-1716`). `catch_up_progress` los restaura con `objectives[name].restore(...)` (`hotel_main.gd:1573-1593`, `match_net.gd:1166`).

### Otros

- Ejecución (captura): `execute_start` (`match_net.gd:970-972`), `tell_lens` (`976-985`), `lens_settled` (`987-989`), `free_victim_hide` (`992-1006`).
- Revivir: `revive_everyone` (`match_net.gd:624-625`) → `revived_state` (`627-629`) → `apply_revival` (`revival.gd:139`).
- Ascensores: `call_lift` (`633-638`) → `request_lift` (`640-646`) → `press` del anfitrión → `ride_lift` (`649-650`) → `ride_state` (`652-654`); `leave_floor` (`658-662`); `locust_ride` (`668-674`).
- Fotos: `send_photo` (`464-467`) → `office_photo` (`469-478`); el anfitrión retransmite y solo acepta si el asiento coincide con quien envía (`match_net.gd:474-477`).
- Chillido del cazador: `locust_shriek` (`862-865`) → `request_shriek` (`867-873`); `update_shriek` (`886-908`) mira a los supervivientes que se mueven (`SHRIEK_STIR`, `879`) y lo envía a `shriek_reveal` (`910-916`).
- Oído de la criatura (cazador): `tell_hunter` (`918-923`) → `heard_contact` (`925-927`).

---

## 8. Unirse a mitad (reincorporación)

Secuencia con el código actual, para quien vuelve a una partida en curso:

1. El invitado conecta y envía `register(...)` con su perfil pendiente (`net_session.gd:256-258`). Si es observador, `observer = true`.
2. El anfitrión (`register`, `net_session.gd:283-335`):
   - Observador: lo anota en `observers` y responde `welcome(0)` (`net_session.gd:291-297`). Si hay partida, le envía `begin` con `{"observer": true}` (`296`). No hay tope propio.
   - Con partida en curso (`in_match`): solo entra quien estaba desconectado, con el mismo nombre (`net_session.gd:299-305`), o con un nombre "Nombre N" que cuadra con su nombre de antes, prefiriendo el mismo personaje (`306-311`). Si no hay ninguno: "La partida ya empezó. Espera a que vuelvan a la sala." (`312-314`).
   - Sin partida: asiento libre de 2 a 6 (`328-331`).
3. Vuelve el asiento: `connected = true`, `peer = id` (`315-316`), `welcome(seat)` (`333`), `broadcast_lobby` (`334`), y `match_net.seat_returned(seat, id)` (`335`).
4. `seat_returned` (`match_net.gd:1125-1134`): saca al asiento de `away`, llama a `level.session.returned(seat)` (`game_session.gd:157-158`), pone el cuerpo visible y envía `begin(config, {"returning": true})` a ese peer (`match_net.gd:1134`).
5. El invitado reconstruye la planta (`begin` → `end()` → `start_online_floor` → `build_floor`, `match_net.gd:107-121`; `hotel_main.gd:1012-1045`). Con la etiqueta "Volviendo a la partida…" (`hotel_main.gd:1034`, que lee `rejoin_snapshot`).
6. Al terminar, `floor_built` crea los cuerpos de los demás (`match_net.gd:135-140`) y envía `report_ready` con su hash (`match_net.gd:158`).
7. El anfitrión: `report_ready` (`match_net.gd:171-185`). Si el hash no coincide, `refuse`. Si la sesión ya está en `PLAYING`, `TRANSITION`, `WON` o `FAILED`, hace `catch_up` (`match_net.gd:192-197`). Si no, marca al asiento como listo (`198-199`).
8. `catch_up` (`match_net.gd:1137-1168`) envía `restore(puertas, armarios, posiciones, estado de la criatura, hoja, televisores, progreso)` (`1167`) y luego `session_state` (`1168`). El progreso (`1166`) incluye cajones registrados, código, paneles abiertos, ascensores que se han ido, etapa y objetivos.
9. El invitado aplica `restore` (`match_net.gd:1171-1201`) con `begin_online_play` si hace falta, `catch_up_progress` (`hotel_main.gd:1573`), puertas, posiciones (su propio cuerpo y el de los demás), armarios con `hide_state`, la criatura con `resume_state` si la conduce él (`match_net.gd:1196`) o con `push_state` si no, televisores en silencio (`hush`, `1189-1200`) y la hoja (`restore_sheet`).
10. Quien solo mira también se pone al día: `report_ready` de un observador con el hash correcto llama a `catch_up(0, id)` (`match_net.gd:178-180`).
11. Hasta `floor_live`, el invitado ignora `minds_state` (`match_net.gd:367`), `session_state` (`370-372`) y `go` (`222`).

Plazo de la sala: `READY_TIMEOUT = 30` s (`match_net.gd:28`, `251-257`). Pasado, el anfitrión empieza sin los que no han construido la planta.

Alta en mitad de una etapa: sin cambios de etapa, el asiento que vuelve cuenta desde la siguiente (`game_session.gd:157-158`, comentario de la línea 156).

---

## 9. Desconexiones

- **Un invitado se cae (en el anfitrión)**, `_peer_disconnected` (`net_session.gd:263-277`):
  - Observador: `observers.erase(id)` y listo (`265`).
  - Asiento en partida: `connected = false`, `peer = 0` (`269-270`), `match_net.seat_dropped(seat)` (`271`), `check_ready` (`274`).
  - Asiento en sala: se borra (`276`).
  - En los dos casos, `broadcast_lobby` (`277`).
- `seat_dropped` (`match_net.gd:1108-1123`): el cazador tiene el mismo periodo de gracia; el anfitrión devuelve la criatura a la IA (`set_control("ai")`, `hunter_gone`, `1116-1119`). Un superviviente se marca como `away` y su cuerpo como ausente (`1122-1123`). Si ya estaba muerto, no pasa nada (`1121`).
- **Gracia de 60 s**, en `_process` del anfitrión (`match_net.gd:259-268`): `RECONNECT_GRACE = 60` (`match_net.gd:26`), solo mientras la sesión está en `PLAYING`. Al cumplirse, `level.session.drop(seat)` (`match_net.gd:266`, `game_session.gd:150-154`: el asiento pasa a muerto y queda en `dropped`), y `objectives_on_death` (`267`).
- **Quorum.** Al empezar, un superviviente sin conexión se da por perdido (`match_net.gd:228-229`, y el cazador en `233`). Dentro de la partida, `check_quota` (`game_session.gd:160-165`) decide si quedan vivos suficientes.
- **Se cae el anfitrión (en un invitado).** Godot emite `server_disconnected`, y `shutdown("Se perdió la conexión con el anfitrión.")` (`net_session.gd:92`, `205-219`): cierra el peer, pone `OfflineMultiplayerPeer`, llama a `match_net.end()` (`207`) y emite `closed` (`219`). `on_net_closed` (`hotel_main.gd:1093-1109`) termina la partida, sale del piso y lleva al menú con el motivo.
- **No conecta.** `connection_failed` → "No se pudo conectar con esa dirección." (`net_session.gd:91`).
- **El anfitrión cierra la sala.** Botón "Cerrar la sala" (`hotel_ui.gd:862`) → acción `online_quit` → `shutdown("")` y `leave_online_floor()` (`hotel_main.gd:615-617`). Los demás reciben `server_disconnected` y vuelven al menú. Lo prueba `net_test.gd:613`.
- **Rechazo.** `refuse` manda el motivo y, 0.5 s después, `peer.disconnect_peer(id)` (`net_session.gd:337-340`).
- **El anfitrión muere en la partida** (no es desconexión): la partida sigue con los demás (`net_test.gd:295-297`, `608-611`).
- **Steam.** `_peer_connected` y `_peer_disconnected` de `steam_link.gd:329-336` solo escriben en el log. La lógica de asientos la lleva `net_session` con las señales de `multiplayer` (`net_session.gd:88-89`).

---

## 10. Steam: salas, invitaciones, logros, presencia, identidad

- **Crear sala.** `host_steam` → `steam.create_lobby` (`net_session.gd:174-182`) → `api.createLobby(LOBBY_TYPE_FRIENDS_ONLY, 6)` (`steam_link.gd:137-140`; tipo por constante, valor de respaldo 1). Al crearse (`_lobby_created`, `steam_link.gd:142-164`): datos `game`, `protocol`, `host` (`149-151`), `setLobbyJoinable(lobby, true)` (`152`), presencia `connect = "+connect_lobby <id>"` (`154`), `create_host(0)` (`156-157`) y `net.as_host(peer, "steam", ...)` (`163`).
- **Entrar.** `join_steam` → `api.joinLobby` (`steam_link.gd:205-208`). `_lobby_joined` (`210-234`) comprueba la respuesta (constante `CHAT_ROOM_ENTER_RESPONSE_SUCCESS`, valor de respaldo 1), los datos `game` y `protocol`, toma el dueño (`getLobbyOwner`, `224`) y hace `create_client(owner, 0)` (`226-227`).
- **Invitar.** `invite_friends` abre la ventana del overlay (`steam_link.gd:177-180`, `activateGameOverlayInviteDialog`), solo si `overlay_ready()` (`173-174`: Steam arrancado y `isOverlayEnabled()`). `invite(friend)` envía la invitación al chat de Steam (`steam_link.gd:197-201`, `inviteUserToLobby`). La interfaz lo usa en `hotel_ui.gd:802`, `805`.
- **Aceptar una invitación.** `join_requested` (`steam_link.gd:238-240`) → `join_asked` → `hotel_main.gd:320-322` → `join_steam`. Con el juego cerrado: `+connect_lobby <id>` en la línea de arranque (`steam_link.gd:104-112`; solo con AppID distinto de 480, según el propio comentario `104-105`).
- **Amigos.** `online_friends` (`steam_link.gd:183-193`, filtra estado `PERSONA_STATE_OFFLINE`), `friends` (`282-290`), `friend_rooms` (`243-255`: amigos que juegan con el mismo AppID y tienen lobby). En la interfaz: `hotel_ui.gd:755` (salas de amigos), `785` (amigos en línea), `778` (entrar).
- **Logros.** `unlock(keys)` (`steam_link.gd:269-279`): `getAchievement`, `setAchievement` y `storeStats`. Nombres de API `F<planta>_<ID>` (`steam_link.gd:265-266`). Lo llama `records.changed` (`hotel_main.gd:317-318`), y una vez al arrancar con `call_deferred` (`319`). Logros de un amigo: `requestUserStats` (`steam_link.gd:295-298`) y `_user_stats_received` (`300-311`, `getUserAchievementAndUnlockTime`); la interfaz los pide en `hotel_ui.gd:1171-1172`. Con AppID 480 los logros no existen (comentario `steam_link.gd:262-264`).
- **Presencia.** `setRichPresence("connect", ...)` (`steam_link.gd:154`) y `clearRichPresence` al salir de la sala (`steam_link.gd:320`).
- **Identidad.** `getSteamID` y `getPersonaName` (`steam_link.gd:92`, `151`, `162`, `233`). `getFriendPersonaName` para nombres de logs y de dueño (`steam_link.gd:191`, `233`). `SteamMultiplayerPeer.get_steam_id_for_peer_id(id)` (`steam_link.gd:331`, solo log). La identidad de juego sigue siendo el `peer` de Godot (asiento).
- **Overlay.** `isOverlayEnabled` se mira a los 3 s (`steam_link.gd:121-125`).
- **Relay.** `initRelayNetworkAccess` al arrancar (`steam_link.gd:96`).
- **Callbacks.** `api.run_callbacks()` en cada `_process` (`steam_link.gd:118-120`).
- **Lo que no se usa** (según el código leído): no hay tickets de autenticación, ni leaderboards, ni nube, ni voz, ni `MultiplayerSynchronizer` ni `MultiplayerSpawner`. Grep en `game/` y `game/net/`: 0 resultados para `MultiplayerSynchronizer` y `MultiplayerSpawner`.

Métodos de GodotSteam que usa el juego (ya comprobados por `steam_diagnose.gd:7-8`, lista `METHODS` y `SIGNALS`): `steamInitEx`, `run_callbacks`, `loggedOn`, `getAppID`, `getSteamID`, `getPersonaName`, `getFriendPersonaName`, `createLobby`, `joinLobby`, `leaveLobby`, `setLobbyData`, `getLobbyData`, `getLobbyOwner`, `setLobbyJoinable`, `activateGameOverlayInviteDialog`, `setRichPresence`, `clearRichPresence`, `getFriendCount`, `getFriendByIndex`, `getFriendGamePlayed`, `getFriendPersonaState`, `getLaunchCommandLine`, `initRelayNetworkAccess`, `isOverlayEnabled`, `inviteUserToLobby`, `activateGameOverlayInvite`, `getAchievement`, `setAchievement`, `storeStats`, `requestUserStats`, `getUserAchievementAndUnlockTime`. Señales: `lobby_created`, `lobby_joined`, `lobby_chat_update`, `join_requested`, `user_stats_received`. Hay una lista más larga en `steam_diagnose.gd:7-8` que se puede ver ejecutando el modo, pero no se ejecutó.

---

## 11. Clases y nodos de Godot que usa esta parte (apariciones aproximadas en `game/net/`)

| Clase o nodo | Apariciones aprox. | Dónde |
|---|---|---|
| `multiplayer` (MultiplayerAPI) | 47 | `net_session.gd` (conexiones y señales), `match_net.gd` (autoridad, remitente) |
| `get_remote_sender_id()` | 32 | `match_net.gd`, `net_session.gd` |
| `rpc_id` / `.rpc(` | 31 / 30 (+5 `.rpc`) | `match_net.gd`, `net_session.gd` |
| `callv` | 3 | `match_net.gd:293-300` |
| `ENetMultiplayerPeer` | 2 | `net_session.gd:108`, `151` |
| `SceneMultiplayer` (`server_relay`) | 2 | `net_session.gd:127` |
| `OfflineMultiplayerPeer` | 1 | `net_session.gd:210` |
| `MultiplayerPeer` (tipo) | 7 | `net_session.gd` (variable `peer`), `steam_link.gd` |
| `ClassDB` (`instantiate`, `class_exists`, constantes) | 15 | `steam_link.gd` (peer y constantes), `steam_diagnose.gd` |
| `Engine.get_singleton` / `has_singleton` | 2 | `steam_link.gd:51`, `70` |
| `Steam` (singleton, menciones) | unas 89 (incluye comentarios) | `steam_link.gd` |
| `Node3D` (tipo) | 16 | `match_net.gd`, `remote_player.gd` |
| `Transform3D` | 11 | `match_net.gd` (cámara), `remote_player.gd` |
| `Basis`, `Quaternion` | 3, 1 | `match_net.gd:332`, `remote_player.gd:158` |
| `CharacterBody3D`, `CapsuleShape3D`, `CollisionShape3D` | 1 cada uno | `remote_player.gd:1` (clase), `69-73` |
| `Camera3D` | 2 | `remote_player.gd:18`, `81` |
| `SpotLight3D` | 2 | `remote_player.gd:19`, `88` |
| `AudioStreamPlayer3D` | 3 | `remote_player.gd:29`, `56`, `115` |
| `PackedVector2Array` / `PackedVector3Array` / `PackedByteArray` | 3 / 2 / 2 | payloads de `sheet_chunk`, `shriek_reveal`, `office_photo` |
| `JSON` (`stringify`, `parse_string`) | 5 | `net_session.gd:258`, `288`; `match_net.gd:131`, `1213`, `1220` |
| `FileAccess` / `DirAccess` | 3 / 1 | checkpoint (`match_net.gd:1216-1220`) |
| `ProjectSettings` | 3 | `steam_link.gd:54`, `38` de `steam_diagnose.gd` |
| `OS` (cmdline, environment) | 6 | `steam_link.gd` |
| `IP` (`get_local_addresses`) | 1 | `net_session.gd:236` |
| `DisplayServer` (headless) | 1 | `steam_link.gd:67` |
| `get_tree()`, `create_timer(0.5)` | 2, 1 | `net_session.gd:340` |
| `process_mode`, `add_child`, `queue_free`, `call_deferred` | 4, 8, 1, 1 | nodos de la red |
| `Time.get_ticks_msec` | varios | `match_net.gd:1071-1074`; `televisions.gd:68-86` |
| `hash()` | 3 | `match_net.gd:131`, `net_session.gd:258`, `288` |
| `randi`, `randi_range` | 1 y 1 (más `randi` en `remote_player.gd:293`) | `net_session.gd:415`, `419`; `remote_player.gd:293` |
| `Engine.get_physics_interpolation_fraction()` | 1 | `remote_player.gd:275` |

Señales de red: `peer_connected`, `peer_disconnected`, `connected_to_server`, `connection_failed`, `server_disconnected` (`net_session.gd:88-92`); `steam_link.gd:97-103` conecta las de Steam y las de `multiplayer`.

---

## 12. Constantes y cifras que definen cómo se siente o se ve

Red (`game/net/`):

- `net_session.gd:27` `PORT = 38430`; `:30` `MAX_PLAYERS = 6`; `:31` `MAX_SURVIVORS = 5`; `:36` `OBSERVERS = 2`; `:37` `MIN_PLAYERS = 2`; `:39` `PROTOCOL = "the-four-net-22"`; `:46` `RANDOM = 0`.
- `net_session.gd:110` tope de ENet = `MAX_PLAYERS - 1 + OBSERVERS` = 7.
- `net_session.gd:222` nombre máximo 18; `:326` base de los duplicados 15.
- `net_session.gd:340` `create_timer(0.5)` antes de desconectar al rechazado.
- `net_session.gd:415` locust al azar; `:419` semilla al azar en `[0, 2147483647]`.
- `match_net.gd:23` `SEND_RATE = 20.0` (estado de jugador y de criatura).
- `match_net.gd:24` `SESSION_RATE = 2.0`.
- `match_net.gd:26` `RECONNECT_GRACE = 60.0`.
- `match_net.gd:28` `READY_TIMEOUT = 30.0`.
- `match_net.gd:30` `CHECKPOINT = "user://coop_checkpoint.json"`.
- `match_net.gd:32` `REACH = 5.0` (puertas, armarios, cajones, paneles, televisores, ascensores: distancia del que pide).
- `match_net.gd:34` `SPAWN_RADIUS = 1.2`; `:161` ángulo de asiento `TAU * (seat - 1) / MAX_PLAYERS`.
- `match_net.gd:534` `WARP_SLACK = 1.5`; `televisions.gd:91` `WARP_REACH = 3.4`.
- `match_net.gd:806-808` `SHRIEK_RANGE = 26.0`, `SHRIEK_TIME = 4.0`, `SHRIEK_RATE = 5.0`; `:879` `SHRIEK_STIR = 0.45` m/s; `:906` el punto del grito está a 1.2 m de altura.
- `match_net.gd:1046` `SHEET_RATE = 30.0`; `:1070` máximo 128 puntos por trozo; `paper_sheet.gd:53` `MAX_OPS = 3000`.
- `match_net.gd:830` la criatura no recibe golpes con `grace > 0`.
- `files_objective.gd:61` `PHOTO_MAX_BYTES = 24576`.
- `lifts.gd:241` `RIDE_REACH = 1.4`; `:248` `RIDE_SLACK = 0.5`; `:66` `LIFT_RETURN = 15.0`; `:457` `LEAVE_TIME = 4.0`.
- `steam_link.gd:30` `DEV_APP_ID = 480`; `:33` `GAME_KEY = "the_four"`; `:123` 3 s para mirar el overlay; `:140` 6 miembros de lobby.
- `hotel_main.gd:420` `OBSERVER_WAIT = 2.5`; `:439` `OBSERVER_KNOCK = 3.0`.
- `project.godot:73` AppID 480; `:74` `initialize_on_startup=true`; `[physics]` sin tasa de tick (valor por defecto, véase la sección 16).

Visual de los cuerpos remotos (`game/net/remote_player.gd`):

- `:15` `DELAY = 0.1` s de retardo de interpolación; `:163` búfer de 12 estados; `:204` `RIDE_HOLD = 3.0`.
- `:22` `TORCH_ENERGY = 8.0`; `:101` `light_volumetric_fog_energy = 0.0` (la niebla de otro no se ilumina, comentario en `:96-100`); `:105` `shadow_bias = 0.04`; `:106` `light_size = 0.03`; `:111` posición de la linterna `(0.24, -0.3, -0.25)`.
- `:84-85` cámara: `fov = 78.0`, `far = 95.0`; `:86` `cull_mask = 1048573`; `:83` altura de cámara `1.64`.
- `:71-74` cápsula: radio 0.3, altura 1.8, forma en `y = 0.91`; `:67`, `133` capas de colisión 4 y 0.
- `:92-95` linterna: `spot_range = 24`, `spot_angle = 32`, `spot_attenuation = 0.85`.
- `:117-119` voz de pasos: `max_distance = 26`, `unit_size = 3`, `area_mask = 512`.
- `:282-285` pasos: umbral de carrera 4.6 m/s (`:283`); zancada `2.0/1.5` agachado, `6.0/2.5` corriendo, `3.8/2.0` andando; `:282` velocidad mínima 0.3.
- `:298` volumen de pasos: `-29` agachado, `-13` corriendo, `-19` andando; `+2` sobre suelo duro.
- `:256`: si el estado nuevo está a más de 3 m, se toma de golpe. `:147` usa el mismo umbral para descartar estados de antes de un ascensor.
- `:267` `abs(velocity.y) < 1.2` para decidir si está en el suelo.
- `:280` si se mueve más de 1 m de golpe, no cuenta como paso.

Criaturas (lectura de la red):

- `hotel_locust.gd:1241` búfer de 10 estados; `:1257` retardo 0.1 s.
- `lurker.gd:504` búfer de 10; `:517` retardo 0.1 s; `:42` `PACK_SIZE = 12`.

---

## 13. Lo que depende del orden de ejecución, de la física o del azar de Godot

- **Reloj de envío.** `match_net._physics_process` descuenta `send_clock` con el `delta` de física (`match_net.gd:276-283`). Con la tasa de física por defecto (sección 16, sin comprobar) envía 20 veces por segundo. El de sesión se descuenta en `_process` (`match_net.gd:269-272`).
- **Reloj de recepción.** `remote_player.gd:213` (`clock += delta` en `_physics_process`), `243` (`wanted = clock - DELAY`), `162` (`time: clock` al llegar). Los invitados no usan el reloj del emisor. Lo mismo en las criaturas: `hotel_locust.gd:1251`, `1257`; `lurker.gd:515-517`.
- **Temporizadores de partida en `_process`.** Gracia de 60 s (`match_net.gd:259-268`), búsqueda de armarios (`942-966`, con `update_wardrobe_jobs` en `_process`, `match_net.gd:244-245`, solo en la máquina que decide), chillido (`886-908`, mismo sitio). Con `get_tree().paused` no avanzan (`match_net.gd:244`).
- **Reloj del sistema.** `Time.get_ticks_msec()` en el presupuesto de trazos (`match_net.gd:1071-1074`) y en el siseo de los televisores (`televisions.gd:68-86`). Son relojes de pared, no de física.
- **Interpolación de física.** `remote_player.gd:275` usa `Engine.get_physics_interpolation_fraction()` para la cámara que mira un compañero muerto. El proyecto no fija `physics_interpolation` (sección 16).
- **Azar global.** `randi()` y `randi_range()` sin semilla propia: `net_session.gd:415`, `419` (locust y semilla de partida); `remote_player.gd:293` (qué clip de paso suena); `hotel_main.gd:452` (semilla de observador). Que la RNG global esté o no sembrada al arrancar no está comprobado.
- **Azar sembrado.** Toda la planta: `RandomNumberGenerator.seed = hash([...])` (`map_generator.gd:141`, `162`, `196`, `200`, `204`, `208`; `office_generator.gd:1015`). Es lo que hace que cada máquina genere la misma planta.
- **`hash()` como identidad.** El manifiesto entero se compara como hash de su texto JSON (`match_net.gd:131`, `187-191`). Cualquier diferencia de formato (un flotante, el orden de claves) lo rompe.
- **Física local en la generación.** La validación física (`hotel_main.gd:958-961`) corre en cada máquina con su motor de física, y decide el respaldo (`hotel_main.gd:895-906`).
- **Orden de llegada.** Godot entrega las RPC `reliable` en orden. `unreliable_ordered` no entrega las que llegan atrasadas, pero no las reordena (`MultiplayerPeer.xml`, valores de transferencia). `lobby_state` va antes que `begin` en `start_match` (`net_session.gd:434-435`), dos RPC fiables.
- **Esperas por frames.** `build_floor` espera 2 frames de proceso (`hotel_main.gd:836-837`) y 2 de física antes y después de validar (`hotel_main.gd:892-893`, `904-905`); `start_online_floor` espera `session.changed` si la sesión está en `LOADING` (`hotel_main.gd:1018-1019`). El anfitrión espera a todos con `check_ready` (`match_net.gd:201-207`).
- **Señales diferidas.** `join_asked.emit.call_deferred(int(id))` (`steam_link.gd:112`); `tell_steam.call_deferred()` (`hotel_main.gd:319`).
- **Temporizador de rechazo.** `create_timer(0.5)` (`net_session.gd:340`), en tiempo real.
- **Steam.** `run_callbacks` en cada `_process` (`steam_link.gd:118-120`): si la escena se detiene, Steam no recibe nada.

---

## 14. Pruebas que vigilan esta parte

- **`tests/net/net_test.gd`** (lanzado por `tools/net_test.ps1`). Cinco escenarios, cada uno con sus roles:
  - `coop` (`host`, `alpha`, `bravo`; `net_test.gd:67-70`): sala de 3, mismo piso, cuerpos moviéndose, puerta y armario por el anfitrión, muerte mirada desde un compañero, salida juntos, caída y vuelta con el mismo nombre (`net_test.gd:287-290`), cierre de sala (`299-300`, `613`), reglas y dificultad de la sala (`219-225`, `381-382`), tarjetas (`281`).
  - `versus` (`vs_host`, `vs_hunter`; `71-72`): cazador en el lugar del Locust, grito, teles, armario, ejecución.
  - `late` (`late_host`, `late_guest`; `73-74`): un invitado que llega después y sube en su propio viaje (`311-368`).
  - `observer` (`watcher`, `watch_host`, `watch_guest`; `75-77`): observador sin cuerpo que recibe el piso (`93-146`).
  - `office_coop` (`office_host`, `office_alpha`, `office_bravo`; `78-80`): piso 2 con tarjetas, foto, cuadro, aire y palanca roja (`398-522`).
  - Cada rol escribe `evidence/net_<rol>.json` (`net_test.gd:81-83`). `tools/net_test.ps1` falla si hay `SCRIPT ERROR:` en el log (`net_test.ps1:32`).
  - Puerto fijo 24600 (`net_test.gd:13`, `net_test.ps1:1`). Los tres procesos se lanzan con 700 ms de separación (`net_test.ps1:20`), y se matan al agotar 420 s (`net_test.ps1:22-26`).
- **`tests/hotel/creature_contract_test.gd`.**
  - `RPCS` (`:86-89`): 50 nombres de RPC y su número de argumentos. Comprueba que coinciden (`creature_contract_test.gd:1658`, mensaje "Las RPC de la red son las de antes").
  - `wire()` (`:1643-1700`): el paquete de la criatura son los mismos bytes (`var_to_bytes`) en todos los modos, y un puppet lo lee igual que antes.
  - `:1598` comprueba que `match_net.gd` pregunta lo que la criatura debe contestar (`is_engaged`, `validate_strike`, etc.).
  - `:1740-1824` `strike_victim` con superviviente cercano y lejano.
- **`tests/hotel/observer_test.gd`** (`:55-113`): observador sin sala (mira un piso propio), `join_observer` y `shutdown`.
- **`tests/hotel/rules_test.gd`** (`:160-178`): abre sala en el puerto 24688, `options.rules`.
- **`tests/hotel/hotel_test.gd:229-232`**: el menú de multijugador ofrece `mp_steam` y `mp_ip`, y no pide personaje antes de la conexión.
- **`tests/hotel/scene_contract_test.gd:102`**: escena de multijugador en la lista de pantallas.
- **Otras pruebas que usan la red por dentro** (en la sala de pruebas, no en `tests/net/`):
  - `tests/hotel/echo_test.gd` (`:11`, `298-373`): cuerpos remotos y chillido.
  - `tests/hotel/capture_test.gd:695`: armario con `use_hide`.
  - `tests/hotel/bots_test.gd` (`:81`, `231`, `307`): `use_container` y `spawn_point`.
  - `tests/hotel/stages_test.gd` (`:128`, `379-388`, `526-530`, `714-767`, `806`): `call_lift`, `use_panel`, jugadores desconectados y configuración de partida.
  - `tests/hotel/spatial_audio_test.gd:198`: `SHRIEK_RANGE`.
  - `tests/office/office_walk_test.gd` (`:62`, `85-261`): `use_office` en todos los objetivos de planta 2.
  - `tests/office/lurker_fairness_test.gd` (`:361`, `535-540`): cuerpos remotos.
  - `tests/office/lurker_observer_test.gd:120`: comprueba que existen `creature_event` y `creature_event_rpc`.

Nota: `tests/hotel/creature_contract_test.gd` cuenta RPC de `match_net.gd`. Las 5 de `net_session.gd` (`register`, `refused`, `welcome`, `lobby_state`, `profile`) no tienen prueba de contrato de cable en `tests/`.

---

## 15. Hallazgos que conviene saber

- **`send_cue` y `send_cue_over` no envían nada por red** (`match_net.gd:755-765`). El comentario (`755-758`) dice que "Phase 4 also sends it, reliable, to every machine". El cuerpo solo llama a `level.creature.play_cue(...)` o `cue_over(...)` en la máquina que los llama. Los llama el cerebro del Lurker (`lurker.gd:885-886`). Si ese cerebro solo corre en la máquina que conduce, los demás no oyen el aviso. **Sin comprobar** si el cerebro corre en todas las máquinas (`lurker.gd:533-560` no leído).
- **Reanudar no respeta el modo guardado** (`net_session.gd:418-424`, `match_net.gd:1213`): la semilla y el piso vienen del checkpoint, el modo viene de `options.mode`.
- **Observadores sin tope** (`net_session.gd:291-297`): el único límite es el de ENet (7 clientes en total, `net_session.gd:110`).
- **`remote_player.gd:256`**: `global_position = target if target.distance_to(previous) > 3.0 else target`. Las dos ramas son iguales. El comentario de la línea 255 dice "se toma de golpe".
- **`online_descend`** (`hotel_main.gd:611-612`) pone `net.options.floor = 2` a mano; `set_option("floor", ...)` (`net_session.gd:373`) lo valida con `FLOORS.built`.
- **`set_option("mode", VERSUS)` fuerza el piso 1** (`net_session.gd:377`).
- **`lobby_state` expone el `peer` de Godot** de cada asiento a todos (`net_session.gd:131`, `332`, `357`).
- **`var pending_profile := {}`** se declara a mitad del archivo (`net_session.gd:202`), y se usa desde `_connected` (`:258`).
- **`rejoin_snapshot`** solo se lee para elegir el texto de carga (`hotel_main.gd:1034`). `match_net.gd` lo guarda en `begin` (`120`) y lo vacía en `end()` (`101`).
- **`refuse`** no comprueba que el invitado siga conectado al cabo de 0.5 s: solo que la sala siga abierta (`if peer != null`, `net_session.gd:340`).
- **Diferencia de nombres de archivo.** `godotsteam.gdextension` nombra rutas que no están (sección 3).

---

## 16. Sin comprobar

- **Lo no leído de los archivos del repo:**
  - `game/app/hotel_main.gd` salvo los tramos de la sección 1 (la mayor parte del archivo no se leyó).
  - `game/app/lifts.gd`, `revival.gd`, `executions.gd`, `code_lock.gd`, `sanity.gd`, `observer_view.gd`, `televisions.gd` fuera de 45-130, `game/services/game_session.gd` fuera de 145-165, `files_objective.gd`, `power_objective.gd`, `air_objective.gd` (solo grep de las líneas citadas).
  - `game/enemies/locust/hotel_locust.gd` y `game/enemies/lurker/lurker.gd`: solo los tramos citados (sin leer el cerebro, el movimiento ni `_physics_process` completos).
  - `game/world/interactables/hiding_place.gd`, `game/world/hotel/hotel_geometry.gd` (fuera de 2920-2932), `game/app/hotel_main.gd` (su `build_floor` completo).
  - `game/net/*.uid`, `avatar_visual.tscn`, `footstep_segments.gd` (cuerpos remotos).
  - `docs/` (incluido `docs/DEVELOPMENT.md`, que cita `godotsteam.gdextension`).
- **Lo no leído de addons/godotsteam:** `readme.md` líneas 41-95 (tabla de compatibilidad completa y changelog). No hay en el repo ninguna referencia de firmas de GodotSteam: las firmas que usa el juego solo se pueden ver ejecutando `--steam-diagnose` (no se ejecutó).
- **Versión de la SDK Steamworks** dentro de `steam_api64.dll`: 10.83.75.46 es la versión del archivo. No está confirmado que sea la 1.65.
- **Determinismo de `hash()` de Godot** entre máquinas, plataformas y versiones (`match_net.gd:131`, `map_generator.gd:141`, `office_generator.gd:1015`, `net_session.gd:258`, `288`). El código de Godot no está en el repo. Esto es lo que más pesa para el port.
- **Si la RNG global de Godot se siembra al arrancar** (`randi` en `net_session.gd:415`, `419`).
- **Canales reales.** Cómo se traducen `reliable`, `unreliable` y `unreliable_ordered` en ENet y en `SteamMultiplayerPeer`. Los valores de los modos están en `.claude/godot-api/doc/classes/MultiplayerPeer.xml`, pero no el comportamiento del peer de Steam.
- **Tope efectivo de ENet** con `create_server(port, 7)` (el parámetro se llama `max_clients` en `ENetMultiplayerPeer.create_server`, por defecto 32 según el XML).
- **Cerebro del Lurker en invitados** y si los avisos (`send_cue`) llegan a todos (sección 15).
- **Mediciones:** no se midió latencia, ancho de banda ni tamaño de los mensajes. Solo hay ritmos de envío (sección 5).
- **Reincorporación de un cazador** (`match_net.gd:1196`, `resume_state`): leído, no probado.
- **`tests/hotel/*`** solo en las líneas citadas por grep. No se ejecutó ninguna prueba.

Ponytail: no comprobado el determinismo de `hash()` y la RNG global de Godot (el motor no está en el repo). Riesgo para el port: si la planta de una máquina difiere, el hash la hace caer con el aviso "Tu piso no coincide"; lo que no pasa por el hash (estado de la criatura, física de objetos, drenaje de luz) no tiene esa red de seguridad.
