# Ficha de hechos: piso 2, acecho desde arriba y oscuridad

Lectura de solo código y de `docs/OFICINAS.md` (§1-4 y arranque de §6). Sin Godot, sin ediciones. Rutas relativas a la raíz; `ruta:línea` es la definición o el uso. "no encontrado" = buscado sin resultado. El escondite pedido en `game/app/` está en `game/world/interactables/hiding_place.gd`.


## 0. Piso, plantas y plazas

- Plantas: `FLOOR.PLANTAS := 3` (`game/world/generation/floor_definition.gd:26`). `planta_of(y)` (`floor_definition.gd:47-48`) saca la planta de la altura. El índice de planta se corresponde con `room.wing` (0, 1, 2), inferido del uso en `always_lit` (`office_palette.gd:1113-1118`).
- Sistemas: `SYSTEMS := ["mail", "power", "air"]` (`game/floors/palettes/office_palette.gd:461`); `POWER := ["mains", "emergency", "none"]` (`office_palette.gd:462`); `PLANTA_NAMES := ["PERSONAL", "REGISTRO Y ARCHIVO", "DIRECCIÓN"]` (`office_palette.gd:463`).
- Etapas (`game/floors/office_floor.gd:56-58`): planta 1 pide `["files"]` (NIVEL 1), planta 2 `["power"]` (NIVEL 2), planta 3 `["air"]` (NIVEL 3). Mapa de manejadores (`office_floor.gd:62`): files, power y air. No hay televisiones ni código en el piso 2.
- Plazas (`game/net/net_session.gd`): `MAX_PLAYERS := 6` (:30), `MAX_SURVIVORS := 5` (:31), `MIN_PLAYERS := 2` (:37). `seats_for(mode)` = `MAX_SURVIVORS + (1 si VERSUS)` (:406-407).


## 1. Alturas y huecos

### Puertas y marcos (constantes)

| Qué | Valor | Dónde |
|---|---|---|
| Alto del hueco de puerta (`OPENING_HIGH`) | 2,65 m | `game/world/hotel/hotel_geometry.gd:896`; el piso 2 lo usa en `game/world/office/office_geometry.gd:2310, 2313, 2323` |
| Ancho del hueco (`FLOOR.PORTAL`) | 1,3 m | `floor_definition.gd:29` |
| Mitad de la puerta en la pared (`DOOR_HALF`) | 1,25 m | `game/world/office/office_walls.gd:33` |
| Jamba (`JAMB_WIDE`) / saliente (`JAMB_PROUD`) | 0,09 m / 0,02 m | `office_geometry.gd:101-102` |
| Soffit (`SOFFIT_DROP`) | 0,004 m | `office_geometry.gd:104` |
| Umbral (`THRESHOLD`) | Vector2(0,18 + 2·JAMB_PROUD, 0,006) | `office_geometry.gd:105` |
| Alto del marco (`door_frame_mesh`) | `OPENING_HIGH + JAMB_WIDE` = 2,74 m | `office_geometry.gd:2323` |
| Regla sobre la puerta (`OVER_DOOR`) | 2,76 m | `office_walls.gd:67`, uso `:252-256` |
| Medio grosor de muro (`WALL_HALF`) | 0,09 m (muro de 0,18 m) | `game/floors/palettes/office_palette.gd:1157` |
| Placa de número (`PLAQUE_Y`, `PLAQUE_FROM_JAMB`) | 1,55 m; 0,22 m | `office_geometry.gd:94-95` |
| Señal (`SIGN_Y`) / interruptor (`SWITCH_Y`) | 1,6 m / 1,15 m | `office_geometry.gd:62, 107` |

Calculado: entre el dintel (2,65 m) y el falso techo (2,95 m) hay **0,30 m**. Entre el marco (2,74 m) y el falso techo quedan **0,21 m** de pared.

### Techos, plénum y mobiliario

- Falso techo: `HEIGHTS` = 2,95 m para casi todas las salas (`office_palette.gd:320`); `PLENUM.ceiling = 2.95` (`:519`).
- Sin falso techo, si la sala tiene altura < `PLENUM.slab - 0.01` (`:984-985`). Losa `PLENUM.slab = 4.4` (`:519`). Salas de 4,4 m: índices 12 (pasillo de servicio), 22 (sala de climatización) y 23 (climatizadora) (`:320`).
- Plénum (`office_palette.gd:519`): `duct_y 3.7`; `main 1.2`; `duct [1.0, 0.8]` (troncos, ancho y alto); `branch [0.5, 0.3]` (ramales). `office_generator.gd:2701-2702` elige una u otra según sea tronco (`trunk`) o no.
- Techo de ella en salas sin falso techo: `EXPOSED_CEILING = 3.05` (`game/enemies/lurker/lurker_shell.gd:35`); el comentario dice "under the main duct's floor (3.1)" (`:33-34`).
- Franja libre encima del mobiliario: `FURNITURE_TOP = 2.2` (`office_palette.gd:565`).
- Mamparas (`partition`): altura **1,2 m** (`office_palette.gd:633`: `{"size": Vector2(0.0, 0.06), "height": 1.2}`). `PAIR_SCREEN = Vector3(1.5, 1.2, 0.06)` (`game/world/office/office_props.gd:588`). Existe `partition_screen_150` de 1,5 m (`game/world/office/pieces/movables.gd:15`); no comprobé en qué piso se usa.
- Otro mobiliario: `filing` 1,32 m (`office_palette.gd:643`); `bookcase` 2,0 m (`:644`).
- Estanterías de archivo: `ARCHIVE_LAYOUT` (`office_palette.gd:551`): `shelf 2.1`, `row 0.6`, `aisle 1.0`, `spine 1.6`, `end_min 1.0`, `door_depth 1.5`, `door_band 1.0`, `inset 0.15`, `wall_gap [0.0, 0.9]`.
- Columnas: `COLUMN = 0.6` (`office_palette.gd:378`); `COLUMN_OFF 2.1` (:379); `COLUMN_PAD 0.3` (:380); `COLUMN_CLEAR 1.3` (:381); `COLUMN_LAMP 0.9` (:382); `COLUMN_TILE 0.6` (:383). Alto = el de la sala: `var h := float(room.height)` (`office_geometry.gd:938`). Base `COLUMN_BASE 0.1` (`office_geometry.gd:123`), capitel `COLUMN_CAP 0.08` (`:124`).
- Taquilla: `LAYOUT.LOCKER = Vector2(1.3, 1.1)` (`game/world/generation/office_layout.gd:18`). `LOCKER_HALF = 0.75` (`office_walls.gd:34`; `game/world/office/office_fittings.gd:54`), la mitad del recorte en pared. Banco de taquillas del vestuario: `locker_bank(... Vector3(2.7, 1.9, 0.45))` (`office_props.gd:400`). No encontrado: constante de alto de taquilla en la paleta; ni si el banco y `LAYOUT.LOCKER` son el mismo objeto.
- Pasillos: `LANE_WIDTHS = [3.0, 3.0, 3.2, 3.2, 3.4, 3.6, 2.4]` (`office_palette.gd:340`). `MODULE_SIZES = [6.0 ... 9.0]` (:339). `BAY = 7.2` (:108). `NAVE_AISLE = 3.0` (:370). `NAVE_SIZE = (12, 16)` (:616), `NAVE_MODULE = 6.5` (:617). Baldosa `TILE = 0.6` (`office_palette.gd:1154`); `TROFFER_PITCH = 3.0` (:1155).

### Constantes de su superficie (`game/enemies/lurker/lurker_shell.gd`)

- Distancia del ancla a techo, dintel y soffit: `BAND_CLEAR = 0.35` (:21). `DEFAULT_HANG = 0.35` (:23). `HANG_MIN = 0.05` (:24). `HANG_MAX = 0.9` (:26), en bandeja. `CUE_HANG_MAX = 1.5` (:61), bajada para una pista. `CH_HANG = 0.25` (:28). `CH_HANG_SHARE = 0.6` (:30).
- Retranqueo del techo en lados con pared: `TRAY_INSET = 0.25` (:37).
- Alcance de bandas: `PORTAL_REACH = 1.4` (:39), `WALL_REACH = 1.4` (:41), `DIP_RUN = 0.6` (:43).
- Ancho de bandas: `PORTAL_WIDTH = 1.3` (:45), `WALL_BAND_WIDTH = 1.2` (:46). `GRILLE_ABOVE = 0.55` (:48).
- Paredes sin falso techo: `WALL_LOW = 1.0` (:69), `WALL_CORNER = 0.45` (:70), `WALL_DOOR = 0.3` (:71), `WALL_MIN = 1.0` (:72).
- Taquillas: `LOCKER_SLOT = 1.6` (:75); `FACE_OFFSET = (0, 0.45, 0.3)` (:55).
- Luces y columnas: `LAMP_CLEAR = 1.0` (:53); `RADIUS = 0.45` (:80); `COLUMN_MARGIN = 0.3` (:81).
- Pasillos de archivo como canal: `CHANNEL_MAX = 1.6` (:50). Radio de acuerdo: `BEND = 0.45` (:17), `R_MIN = 0.05` (:19).
- Pista: `CUE_ANGLE = 0.2617993878` rad, 15° (:57); `CUE_NEAR = 1.0` (:64); `CUE_FACE_LOW = 0.6` (:62).

### Alturas de anclaje (calculadas con lo anterior)

- Bandeja con falso techo: `y = 2.95 − hang`. Con `DEFAULT_HANG` = 2,60 m; con `HANG_MAX` = 2,05 m; con `CUE_HANG_MAX` = 1,45 m. Fórmula en `anchor_of` (`lurker_shell.gd:682`).
- Bandeja sin falso techo: `y = 3.05 − hang`.
- Banda de puerta en el portal: `OPEN − BAND_CLEAR` = 2,30 m (`lurker_shell.gd:408-409`).


## 2. Dónde puede estar ella (`game/enemies/lurker/lurker_shell.gd`)

### Construcción

- Solo para el piso 2: `build` devuelve `null` si `floor != 2` (`lurker_shell.gd:244-245`). `fill()` en `:250`.
- Tipos de parche: `enum Kind { TRAY, BAND, CHANNEL }` (`:15`).
- Salas sin superficie: las `off_limits` (`:253`) y las vacías, `FLOOR.is_void` (`:255`).

### Superficies

- **TRAY, techo de cada sala** (`add_tray`, `:292-314`). El `rect` es `ceiling_rect` con `TRAY_INSET` en lados con pared (`:299-302`). Altura `y = py + height_of` si hay falso techo, si no `py + EXPOSED_CEILING` (`:294`). Registro literal (`:314`):
  `{"kind": Kind.TRAY, "room": int(room.id), "wing": ..., "y": y, "rect": Rect2(low, high - low), "cell": Rect2(...), "open": {}, "posts": posts, "blocked": {}}`
- **Lados abiertos** (`open_sides_of`, `:317-328`): une bandejas a la misma altura (tolerancia 0,001 m, `:325`).
- **BAND de puerta** (`add_door_band`, `:392-416`): una por cada arista de `edges` que no esté en `merged` (`:260-265`). Perfil de seis puntos (`:405-412`): ancla a `h − c` sobre la sala, y a `OPEN − c` sobre el portal.
- **BAND de salida de pared** (`:266-277`): una por rejilla tipo `wall`. Ancho 1,2 m (`:275`), fondo en `exit.y − py + GRILLE_ABOVE` (`:275`).
- **BAND de pared sin falso techo** (`add_wall_strips`, `:459-502`): tiras hasta `WALL_LOW` (1,0 m) sobre el suelo, recorte de `WALL_CORNER` en esquinas y de `WALL_DOOR` en marcos (`:485`, `:463`), descartando tiras de menos de `WALL_MIN` (`:497`). Solo si no hay falso techo (`:280`).
- **BAND frente de taquilla** (`add_locker_bands`, `:505-513`): una por cada `room.hides`. Ancho `LAYOUT.LOCKER.x * 0.5` (0,65 m), fondo `LOCKER_SLOT + FACE_OFFSET.z` = 1,9 m (`:510`).
- **CHANNEL, pasillo de archivo** (`add_channel`, `:517-559`): uno por `aisle` de cada unidad de archivo que no sea móvil (`:282-284`), si el ancho es menor que `CHANNEL_MAX` (`:525`). Registro (`:555-557`): `{"kind": Kind.CHANNEL, "room", "wing", "unit", "origin", "axis", "across", "length", "width", "height", "profile": Profile.section(width, height, BEND), "tray"}`.

### Estado de ella

- `class State` (`:195-213`): `patch`, `u`, `v`, `heading` (rad), `hang`, `lowered`.
- `anchor_of` (`:678-693`), `frame_of` (`:669-676`), `transform_of` (`:700-703`). Para una bandeja, la normal es `Vector3.DOWN` (`:671`).

### Puntos con nombre (no existe un tipo "sitio de espera")

- `state_at(point, hang)` (`:856-873`): estado de bandeja en la sala del punto.
- `above_locker(hide)` (`game/enemies/lurker/lurker.gd:1272-1275`): ancla de la bandeja sobre el centro de la taquilla (`hide.global_position + UP`).
- `channel_mouth(channel)` (`lurker_shell.gd:912-927`): centro del techo del canal, o pared lejos de un fluorescente si está a menos de `LAMP_CLEAR`.
- `cue_pose(eye, view, distance)` (`:1044-1068`): pose de la pista. Elige la altura más baja que deja la cara a 15° del ojo; si no, `CUE_HANG_MAX`.
- `clear_point(room, x, z)` (`:589-636`): punto de bandeja a `LAMP_CLEAR` o más de lámparas y columnas.
- `plenum_mouth(point)` (`:1077-1083`): centro de la baldosa, en el techo falso.
- Taquilla (brain): `to_locker` (`game/enemies/lurker/lurker_brain.gd:1106-1110`); `wait_above_tick` (`:1112-1126`); `WAIT_ABOVE_TIME = Vector2(20, 40)` (`:1103`).

### Dónde no puede estar

- Salas `off_limits` (`lurker_shell.gd:253-255`; `OFF_LIMITS = [9, 10, 19]`, `office_palette.gd:468`).
- Salas vacías (`lurker_shell.gd:255`).
- Lámparas: un punto de parada a menos de `LAMP_CLEAR` de una lámpara no es válido (`clear_of`, `:638-643`). Un fluorescente de emergencia no cuenta (`lamps_in`, `:571-572`).
- Columnas: `RADIUS` 0,45 m alrededor de cada columna (`:80`, `:309-310`); tope de paso en `post_hit` (`:817-841`); la pista no cruza una columna (`column_near`, `:369-375`).
- Paredes: las tiras de pared quedan a `WALL_CORNER` de las esquinas y a `WALL_DOOR` de los marcos (`:485`).


## 3. Salidas del plénum y ductos

### Tipos de salida

| `kind` | Cómo se crea | Dónde |
|---|---|---|
| `wall` | rejilla baja en pared (`wall_exit`) | `game/world/generation/office_generator.gd:2684` |
| `ceiling` | rejilla en una baldosa del techo (`ceiling_exit`) | `office_generator.gd:2692` |
| `duct` | ducto bajo la celda, sin falso techo (`open_exit`) | `office_generator.gd:2715` |
| `gap` | placa que falta, `roundi(GAP_SHARE[planta] * pool.size())` | `office_generator.gd:2800, 2815` |
| `hatch` | escotilla del ducto principal (planta 3) | `office_generator.gd:2848` |
| `tile` | baldosa del plénum, una por sala con falso techo | `game/enemies/lurker/duct_graph.gd:87` |
| `hub`, `station` | tubo neumático (planta 1), van en `tubes.exits` | `office_generator.gd:1246, 1249` |

### Cuántas por sala y planta (reglas; el número exacto depende de la semilla)

- Cada celda que no es pasillo tiene una salida (`duct_exits`, `office_generator.gd:2721-2792`):
  - sin falso techo: `open_exit` (`:2732`);
  - con falso techo: con probabilidad `WALL_EXIT_P = 0.15` (no en archivos) una de pared (`:2735`); si no, una de techo sobre una baldosa libre (`:2736-2739`); si no, de pared (`:2740`).
- Pasillos: `CORRIDOR_EXIT_P = 0.5` (`office_generator.gd:14`, `:2748`). En el edificio real, un pasillo sin falso techo siempre tiene ducto (`:2747`).
- Un tramo de pasillo sin salida recibe una en su celda central (`:2765-2791`).
- Placas que faltan: `GAP_SHARE = [0.03, 0.045, 0.06]` por planta (`office_palette.gd:547`). El conjunto son las salas con falso techo menos la recepción (`office_generator.gd:2798-2802`).
- Baldosas posibles (`exit_tiles`, `:2617-2637`): fuera de estanterías de archivo (`:2629-2634`), fuera de la franja de columnas (`:2628`), y en planta 3 solo dentro de `main_clear` (`:2626`).
- Plénum en el grafo (`duct_graph.gd:66-94`): una salida `tile` y un nodo `plenum` por sala con falso techo, no `off_limits` (`:75`), con baldosas libres no ocupadas por otras salidas (`:73-76`). Arista al nodo de la celda (`:86`) y a las salas con puerta o lado abierto de la misma planta (`:88-94`).
- Baldosa de entrada o salida (`tile_near`, `duct_graph.gd:116-131`): reusa la baldosa abierta más cercana si está a ≤ `TILE_REUSE = 2.5` m (`game/enemies/lurker/lurker_routes.gd:48`); si no, la baldosa libre más cercana.
- Las baldosas `tile` no suenan (`duct_graph.gd:142`).

### Ducto principal (planta 3, de tamaño humano)

- `MAIN_LENGTH = (25, 45)` m (`office_palette.gd:529`); `MAIN_IDEAL = 35` (:530); `MAIN_BENDS = 2` (:531); `MAIN_CLEAR = 1.2` (:539); `SHAFT = (2.2, 2.2)` (:541); `AIR_UNIT = (3.0, 2.2, 1.5)` (:543); `HATCH = {"in": 1.5, "stand": 0.75}` (:534); `STUB = 1.5` (:536).

### Cuánto tarda en salir o entrar

- Entrada a techo, rápida (alumbrada, huida): `BOLT_TIME = 0.3` s; `bolt_speed = clampf(metres / BOLT_TIME, 8, 40)` m/s (`game/enemies/lurker/lurker_motion.gd:427-429`, `:439-443`).
- Salto: `LEAP_REACH = 7.5` m, `LEAP_TIME = 0.6` s, `LEAP_RISE = 0.3` m (`lurker_motion.gd:72-74`).
- Trepar: `CLIMB_SPEED = 1.5` m/s (`lurker_motion.gd:75`).
- Costes de planificación (no son segundos): `PORTAL_COST = 0.5`, `ENTER_COST = 1.5`, `LEAVE_COST = 1.5` (`lurker_routes.gd:25-27`).
- Velocidades por el ducto: `duct_speed = 1.6` por defecto (`lurker_routes.gd:66`); `MAIN_DUCT_SPEED = 1.0` (`lurker_routes.gd:39`); `CRAWL_SPEED = 1.35` (`game/enemies/lurker/lurker_brain.gd:20`).
- Pausa antes de volver a salir tras un fallo: `emerge_delay = Vector2(4.0, 7.0)` por defecto (`lurker_brain.gd:143`); `emerge_range = Vector2(6, 10)` (`:145`). Los valores por dificultad están en la tabla de `docs/OFICINAS.md` sección 4 (no comprobados en `game/floors/difficulty.gd`).


## 4. Oscuridad por planta y cómo se sabe si una sala está a oscuras

### Luz para las reglas

- `hotel.lit(room_id)` (`game/world/hotel/hotel_geometry.gd:2924-2925`):
  `return not dark and not dark_ids.has(room_id) and not unpowered.has(room_id) and float(drains.get(room_id, 0.0)) < LIT_DRAIN`
- `LIT_DRAIN = 0.9` (`hotel_geometry.gd:102`). Campos: `dark` (:89), `dark_ids` (:92), `unpowered` (:95), `drains` (:98).
- `set_room_power(room_id, on)` (`hotel_geometry.gd:2930-2941`). Versión de oficina: llama a la base y repinta lentes (`office_geometry.gd:1029-1034`).
- `drain(room_id, amount)` (`hotel_geometry.gd:2949-2955`). Versión de oficina: además atenúa acentos y lentes (`office_geometry.gd:2822-2825`).
- `lit_at(point)` de la cordura (`game/app/sanity.gd:184-188`): en el ducto principal, oscuro siempre (`level.crawling_at`); si no, `hotel.lit(room)`.

### Qué planta tiene qué

- **Planta 1, `mains` (wing 0):** `always_lit` = todas las salas no vacías ni cuarto eléctrico (`office_palette.gd:1113-1119`: "on mains, every room").
- **Planta 2, `emergency` (wing 1):** `always_lit` solo las `off_limits` (`office_palette.gd:1118`). Lo demás lo corta el cuadro de zonas (`power_objective.gd`, ver sección 5).
- **Planta 3, `none` (wing 2):** `decide_dark` marca oscuras todas las salas de wing 2 que no estén en `always_lit(data, 2)` (`office_geometry.gd:1000-1005`). Esa lista son las `off_limits` y el puesto de seguridad (21) (`office_palette.gd:1118`).

### Primera etapa a oscuras por dificultad (`darken_first_stage`, `office_geometry.gd:1015-1024`)

- Apacible: todo con luz (`:1022`).
- Desafiante: las salas que `may` estar a oscuras, salvo un 10 % (`LIT_LEFT = 0.1`, `:1014`, `:1023`).
- Pesadilla: todas las `may` (`:1024`).
- `may = OFFICE.may_be_dark(room) and not OFFICE.off_limits(room)` (`:1020`). Solo wing 0 (`:1017`).

### Luces que no se pueden beber ni cortar

- `NEVER_DARK = [0, 9, 10, 17, 18, 19, 20, 21, 22, 23]` (`office_palette.gd:326`). `may_be_dark` es `not in NEVER_DARK` (`:1055-1056`). Se usa en el apagón por beber (`lurker.gd:1621`).
- Lámparas por tipo (`lamp_of`, `:1060-1063`): emergencia en cuarto eléctrico (18) y vacío (20); `batten` en `BATTEN_ROOMS = [6, 8, 12, 13, 22, 23, 25]` (`:434`); el resto, fluorescente (`troffer`).
- `off_limits` (`office_palette.gd:1098-1099`; `OFF_LIMITS = [9, 10, 19]`, `:468`).
- Apliques de hito: son luces propias (`door_light`, `game/world/office/office_landmarks.gd:221`). El drenaje baja `lights[room_id]` (`hotel_geometry.gd:2949-2955`). No encontrado un filtro de apliques de hito en `drain_rooms` (`game/enemies/lurker/lurker_senses.gd:301`; cuerpo no leído).

### Cómo bebe la luz (`game/enemies/lurker/lurker.gd`)

- Drenaje pasivo (`_process`, `:1483-1518`): objetivo entre `DRAIN = Vector2(0.4, 0.7)` (`lurker_senses.gd:118`) según `SENSES.drain_rooms` (`:301`). Cada 0,1 s se recalcula (`DRAIN_EVERY`, `:119`); se suaviza con `DRAIN_EASE 1.5` (`:121`) y `DRAIN_WOBBLE 0.08` (`:123`).
- Tope pasivo: `clampf(..., 0.0, 0.89)` (`lurker.gd:1509`). Así el drenaje pasivo nunca llega a `LIT_DRAIN` 0.9, y no deja la sala a oscuras para las reglas.
- Apagón de sala entera (`snuff_step`, `:1600-1615`): exige `brain.state == STALK`, `hotel.lit(theirs)` y `may_snuff` (`:1612`). Tras `snuff_time` seguido (`:1615`) manda `snuff(room, seat)` (`:1626-1634`).
- `may_snuff` (`:1619-1623`): `may_be_dark`, no protegida (`level.point_protected`), no `off_limits`, y no devuelta hace menos de `DEEP_AGAIN` s. Devolver: `undrain()` (`lurker.gd:1637-1645`).
- Constantes del apagón: `DEEP = 0.93` (`lurker.gd:134`); `DEEP_RISE = 0.3`/s (:135); `DEEP_FALL = 1.0`/s (:136); `DEEP_MOST = 25` s (:137); `DEEP_OUT = 3` s (:138); `DEEP_AGAIN = 45` s (:139); `DEEP_WOBBLE = 0.12` (:140); `DEEP_REST_WOBBLE = 0.02` (:141). Por encima de 0,9, la sala queda oscura para las reglas.
- Linterna bebida: `drink_torches(seats, seconds)` (`:1525-1531`); `torch_step` (`:1535-1557`). Las constantes `DRUNK_*` no las localicé.


## 5. Objetivos: dónde se para el superviviente

Holds y tiempos son constantes del código. "hold" = mantener el uso (`hold_of`).

### Planta 1, `game/floors/objectives/files_objective.gd`

- Acciones: `["type", "take", "swipe", "pick"]` (`:20`).
- **Máquina de escribir (ventanilla):** `type`. Usable en el escritorio con `stand` (`:96`) y orientación `look_yaw(-facing(stand.yaw))` (`:96`). Hold `TYPE_TIME = 5.0` s (`:24`; `hold_of` `:377`). Foto de la cámara del techo al fraction 0,6, `TYPE_PHOTO_AT` (`:58`, `:391-392`): unos 3,0 s. `cancel_use` para la voz de tecleo (`:435-437`). No leí otro corte.
- **Estación del tubo:** `take`. Usable en `at + out * 0.55` mirando `look_yaw(-out)` (`:102`), o sea de cara a la pared. Hold `TAKE_TIME = 1.5` s (`:25`; `:378`).
- **Lector de fichas (montacargas):** `swipe`. Mirando `look_yaw(-reader_out)` (`:143`). Hold `SWIPE_TIME = 0.5` s (`:26`; `:379`).
- `pick`: hold `PICK_TIME = 1.0` s (`:21`; `:380`). Lugar de uso no leído.
- Envío: `SEND_DELAY = 1.2` s (`:28`); `CAPSULE_SPEED = 6.0` m/s (`:29`); llegada `sent + exit.tube / CAPSULE_SPEED` (`:460`).
- Alcance: `USE_REACH = 2.5` m (`:30`); `SLACK = 0.5` (`:31`).

### Planta 2, `game/floors/objectives/power_objective.gd`

- Acciones: `["lever", "red", "switch"]` (`:18`).
- Cuadro (`BOARD = (2.6, 1.9, 0.12)`, `:25`). Palancas de zona en `lever_at` (`:159-161`), alto `LEVER_Y = 1.35` (`:26`), recorrido `LEVER_SWING = 70°` (`:29`). Hold 0 (`hold_of` `:249`). Postura: `stand = origin + out * 0.8` (`:96`).
- **Presupuesto:** `budget := 3` fijo (`:39`); el texto dice "NO MÁS DE %d ZONAS A LA VEZ." (`:154`). Si se pasa, cae la zona más antigua (`:276-278`). No encontrado el cambio a 2 por dificultad.
- **Minuteros (`switch`):** `switch_time := 75.0` fijo (`:41`), activado al pulsar (`:294`). Ilumina la sala del minutero mientras `switch_until > now` (`:209-214`).
- **Palanca roja (MONTACARGAS):** hold `RED_HOLD = 1.0` s (`:21`; `hold_of` `:249`). Arranca el reloj `lift_timer := 60.0` fijo (`:40`); el montacargas se activa cuando `now >= red_started + lift_timer` (`:314`).
- `USE_REACH = 2.5` (`:22`), `SLACK = 0.5` (`:23`). `begin_use`/`cancel_use` vacíos (`:251`, `:255`).

### Planta 3, `game/floors/objectives/air_objective.gd`

- Acciones: `["hatch", "climb", "ladder", "post", "start", "stop"]` (`:20`).
- **Escotilla (`hatch`):** hold `HATCH_TIME = 2.0` s (`:24`; `hold_of` `:288`). Apertura `HATCH_SWING = 100°` (`:46`).
- **Subir al ducto (`climb`):** hold `CLIMB_HOLD = 0.5` s (`:25`; `:292`). Tránsito `CLIMB_UP = 2.4` s (`:27`) y `CLIMB_DOWN = 2.0` s (`:28`), con `player.transit` (`:437`).
- **Escalera del pozo (`ladder`):** hold `LADDER_HOLD = 1.2` s (`:26`; `:293`).
- **Lector del puesto (`post`):** hold `POST_SWIPE = 0.5` s (`:38`; `:289`). Pared a altura 0 (`wall_use`, `:99`, `:224-228`).
- **Arrancar (`start`):** hold `START_HOLD = 1.0` s (`:39`; `:290`). Mesa a 0,95 m (`:100`). Cargas `charges := 2` (`:51`), resta una al arrancar (`:346`). `running_until = elapsed + fan_time` (`:347`); `fan_time := 80.0` fijo (`:52`).
- **Parar (`stop`):** hold `STOP_HOLD = 1.0` s (`:40`; `:291`).
- Ducto a gatas: `SPEED_CRAWL = 1.2` m/s, vuelta `SPEED_CRAWL_BACK = 0.6` m/s (`game/player/survivor_gait.gd:38-39`). Vuelta a bajar desde la boca: `MOUTH_REACH = 1.0` m (`air_objective.gd:44`).
- Máscara de sonido de la climatizadora: `AIR_MASK = 0.65` (`:42`).


## 6. Escondites (taquillas)

- Clase: `game/world/interactables/hiding_place.gd`. Armario de madera: `WIDTH 1.25`, `HEIGHT 2.3`, `DEPTH 0.78` (`:23-25`); grande `BIG_SIZE = (2.2, 2.45, 0.9)` (`:28`). Capacidad 1 (`:86`), o 2 en el grande.
- Taquilla de oficina: `var skin := {}` (`:78`), "an office locker, spec_f1_geometry.md 9.7" (`:75-77`). Huella de taquilla `LAYOUT.LOCKER` (1,3 × 1,1; `office_layout.gd:18`).
- Tiempos: `ENTER_TIME = 0.5` s (`hiding_place.gd:51`); `LEAVE_TIME = 0.34` s (`:52`); `QUIET_EXIT = 3.0` s, tecla mantenida para salir sin portazo (`:53`); `QUIET_LEAVE_TIME = 0.6` s (`:54`).
- Rendija: `slit` (`:90`), línea de la sala para quien está dentro.
- **Con ella:**
  - "no abre taquillas" (`game/enemies/lurker/lurker.gd:147-148`);
  - espera encima: `to_locker` (`lurker_brain.gd:1106-1110`); `WAIT_ABOVE_TIME = 20-40` s (`:1103`); ancla sobre la taquilla (`lurker.gd:1272-1275`);
  - sale cuando se acaba el tiempo o desaparece la taquilla (`lurker_brain.gd:1117-1122`), y deja `searched[room] = clock + 60` (`:1118`; `SEARCHED_FOR = 60`, `:502`);
  - si la presa asoma sin esconderse y es `fair`, pasa a `CREEP` (`:1114-1116`).
- Banda del frente de la taquilla, hasta `LOCKER_SLOT + FACE_OFFSET.z` = 1,9 m (`lurker_shell.gd:75`, `:510`).
- Emboscadas cerca de taquillas: `AMBUSH_WAIT = 12` s (`lurker_brain.gd:788`), `AMBUSH_LEAVE = 16` (`:789`), `AMBUSH_REACH = 10` (`:791`).
- **Cordura dentro:** `body.hidden` usa la tasa oscura `SANITY_DARK`, sin el factor de linterna (`game/app/sanity.gd:131-139`).


## 7. Cordura (`game/app/sanity.gd`)

- Baja en oscuridad: `SANITY_DARK = 100/450` por segundo (`:39`). De 100 a 0 en 450 s (7,5 min).
- Con linterna encendida y sin estar oculto: `× SANITY_TORCH = 0.4` (`:40`, `:138`).
- Sube con luz: `SANITY_LIGHT = 100/240` por segundo (`:41`, `:140`). De 0 a 100 en 240 s.
- Sin regla de cordura (`level.rule("sanity") != 1`), la cordura se queda en 100 (`:134-135`).
- Quemado: a 0 se pone quemado (`:155`); vuelve con `SANITY_BACK = 25` (`:52`, `:154`).
- Alucinaciones: `SANITY_UNEASY = 60` (`:51`; `:97-98`, `:228`). Espera entre ellas `HALLUCINATION_WAIT = (13, 42)` (`:54`).
- Sustos: `SANITY_GLIMPSE = 4.0` por vista (`:45`); `SANITY_STARE = 15.0` si la mirada le apunta a los ojos dentro de `STARE_CONE = 30°` (`:46`, `:50`); descanso entre sustos `SANITY_SIGHT_REST = 5.0` s (`:47`); `SANITY_SHRIEK = 6.0` por chillido cercano (`:100`); `SANITY_SEEN = 28` sin uso leído (`:53`).
- `fright` (`:103-122`) paga solo lo que supera lo ya pagado en el descanso (`:111-116`).


## 8. Salas donde ella nunca entra

- `OFF_LIMITS = [9, 10, 19]` (`office_palette.gd:468`): 9 `LANDING` (montacargas), 10 `LOBBY` (vestíbulo de llegada), 19 `REFUGE` (vestíbulo del montacargas) (`:201-206`, nombres en `TYPES`, `:267`).
- `off_limits_rooms(manifest)`: salas no vacías y `off_limits`, ordenadas (`office_palette.gd:1102-1107`).
- Efectos en el código: sin bandeja (`lurker_shell.gd:253-255`); sin nodo de plénum ni baldosa (`duct_graph.gd:75`).
- Refugio: el generador marca `REFUGE` (19) en `refuges` (`office_generator.gd:642-643`). En planta 3 (`laying == 2`), `refuge_fits` usa `AIR_ROOM` (22) (`office_generator.gd:230-231`).
- Nunca a oscuras (`NEVER_DARK`, `office_palette.gd:326`): recepción (0), montacargas (9), vestíbulo de llegada (10), ventanilla (17), cuarto eléctrico (18), vestíbulo del montacargas (19), vacío (20), puesto de seguridad (21), sala de climatización (22) y climatizadora (23).
- La recepción (0) no es `off_limits` (no está en `OFF_LIMITS`).


## 9. Supervivientes, tamaños y tiempos

### Plazas

- 2 a 5 supervivientes: `MIN_PLAYERS = 2` (`net_session.gd:37`), `MAX_SURVIVORS = 5` (`:31`). En versus, +1 para la criatura (`:407`): 6 plazas, `MAX_PLAYERS = 6` (`:30`).

### Área y edificio

- `AREA = {1: 0.5, 4: 1.2, 5: 1.35}` (`office_palette.gd:238`). `area_for(s) = AREA.get(clamp(s, 1, 5), 1.0)` (`:242-243`), o sea 1,0 para 2 y 3 supervivientes.
- `areas_for(s) = [1.0 si s == 1 si no area, area, area]` (`:246-248`).
- Edificio: `area = areas.max()` (`game/world/generation/office_generator.gd:3197`).
- `half = max(half_bays, round(half_bays × area))` (`:3201`). Sin `closing` y con área ≤ 1, el total de bays sale de `randi_range(bays.x, bays.y)` (`:3204`). Sin `closing` y con área > 1, total = `2 × half` (`:3207`).
- `closing = areas.min() < area` (`:3198`): con 1 superviviente, las plantas 2 y 3 tienen área 0,5. Entonces `counts = [half, half]` (`:3202`; `if not closing` en `:3203`).

### TYPOLOGIES (`office_palette.gd:54-95`)

- **ring** (peso 2.0, `:66`; sin `rooms` ni `rings`):
  - filas de frente a fondo (`:56`): front 4,8/6,0; main 2,4/3,0; central 7,2; central 7,2; main 2,4/3,0; back 4,8/5,4/6,0; gallery 2,4; service 4,8/5,4/6,0.
  - fondo: 36,0 a 40,8 m (suma de mínimos y máximos, calculado).
  - `half_bays = 5` (`:59`); `bays = (11, 12)` (`:60`).
  - salas: no define, por defecto `REAL_ROOMS = (45, 99)` (`:112`; `rooms_window`, `:250-252`); anillos: `[6, 4]` por defecto (`:258-260`).
- **spine** (peso 0.0, `:83`: no sale por sorteo; solo con `--plan=spine`, `FORCE_TYPOLOGY`, `:102-107`):
  - filas (`:73`): front 4,8/5,4/6,0; main 2,4/3,0; central 7,2; gallery 2,4; service 4,8/5,4/6,0.
  - fondo: 21,6 a 24,6 m (calculado).
  - `half_bays = 6` (`:76`); `bays = (12, 13)` (`:77`); `rooms = (32, 60)` (`:92`); `rings = [2, 2]` (`:93`).
- `BAY = 7.2` m (`office_palette.gd:108`).

### Largo calculado (bays × 7,2 m)

| Supervivientes | Área | Ring | Spine |
|---|---|---|---|
| 1 | 1,0 con `closing`: 2 × half | 10 bays = 72,0 m | 12 bays = 86,4 m |
| 2 o 3 | 1,0 | 11-12 bays = 79,2-86,4 m | 12-13 bays = 86,4-93,6 m |
| 4 | 1,2 | 12 bays = 86,4 m | 14 bays = 100,8 m |
| 5 | 1,35 | 14 bays = 100,8 m | 16 bays = 115,2 m |

### Salas por planta (`rooms_window = round(rooms × area)`, `office_palette.gd:250-252`)

- Ring (45-99): área 1,0 → 45-99; 1,2 → 54-119; 1,35 → 61-134.
- Spine (32-60): área 1,0 → 32-60; 1,2 → 38-72; 1,35 → 43-81.

### Distancia mínima en planta 1

- `REAL_LEAST_WALKS = [75.0, 0.0, 0.0]` (`office_palette.gd:113`), multiplicado por `sqrt(drawing)` (`office_generator.gd:173`). El factor `drawing` no lo leí.

### Velocidades (`game/player/survivor_gait.gd`)

- Andar `SPEED_WALK = 3.8` (`:12`); correr `SPEED_RUN = 6.0` (`:13`); agachado `SPEED_CROUCH = 2.0` (`:11`); a gatas `SPEED_CRAWL = 1.2` (`:38`); a gatas hacia atrás `SPEED_CRAWL_BACK = 0.6` (`:39`).
- Cadencias `CADENCE_WALK 2.0`, `CADENCE_RUN 2.5`, `CADENCE_CROUCH 1.5` (`:25-27`). Altura agachado `HEIGHT_CROUCHED = 1.05` (`:33`).
- `speed(crouched, running, crawling, backwards)` elige entre estas (`:78-80`).
- `game/player/hotel_player.gd`: `CRAWL_EYE = 0.62` (`:41`), `CRAWL_TURN_RATE = 2.4` (`:42`), `RUN_PUSH = 0.55` (`:12`). No comprobé dónde se llama `speed()`.

### Tiempo de recorrido (calculado: longitud / velocidad)

| Longitud | Andando 3,8 | Corriendo 6,0 | Agachado 2,0 | A gatas 1,2 |
|---|---|---|---|---|
| 72,0 m | 18,9 s | 12,0 s | 36,0 s | 60,0 s |
| 86,4 m | 22,7 s | 14,4 s | 43,2 s | 72,0 s |
| 100,8 m | 26,5 s | 16,8 s | 50,4 s | 84,0 s |
| 115,2 m | 30,3 s | 19,2 s | 57,6 s | 96,0 s |
| 75 m (distancia mínima planta 1) | 19,7 s | 12,5 s | 37,5 s | 62,5 s |

- Estaciones del tubo: `STATIONS = (8, 14)` (`office_palette.gd:524`); `STATION_APART = 15.0` m (`:526`); `STATION_TUBE_MIN = 25.0` (`:528`).


## 10. Discrepancias entre docs y código (solo hechos)

1. **Mamparas:** `docs/OFICINAS.md` §2 dice 1,5 m; el código tiene `partition` a 1,2 m (`office_palette.gd:633`) y `PAIR_SCREEN` a 1,2 m (`office_props.gd:588`). Existe `partition_screen_150` (`movables.gd:15`).
2. **Minuteros:** docs §3 dice 45-90 s; código `switch_time = 75.0` fijo (`power_objective.gd:41`).
3. **Montacargas:** docs §3 dice 45-90 s; código `lift_timer = 60.0` fijo (`power_objective.gd:40`).
4. **Zonas a la vez:** docs §3 dice 3 en Apacible y Equilibrada, 2 en Desafiante y Pesadilla; código `budget := 3` (`power_objective.gd:39`), sin cambio por dificultad encontrado.
5. **Ventiladores:** docs §3 dice 60-90 s y 2 o 1 carga por dificultad; código `fan_time := 80.0` (`air_objective.gd:52`) y `charges := 2` (`:51`), sin cambio por dificultad encontrado.


## 11. No encontrado o no leído

- `game/floors/difficulty.gd`: no leído. Las cifras de dificultad de `docs/OFICINAS.md` §4 no están comprobadas en el código.
- `lurker_senses.gd:301` (`drain_rooms`, cuerpo): no leído. No sé si excluye `may_be_dark` o apliques de hito.
- Cancelación de usos: `office_usable.gd:43` (`cancel(seat)`) llama a `handler.cancel_use`. Quién llama y cuándo no lo leí (podría estar en `game/app/interaction.gd`).
- Altura de la taquilla: sin constante en la paleta.
- `DRUNK_*` (linterna bebida): sin localizar.
- `PICK_TIME` (`files_objective.gd:21`): lugar de uso no leído.
- Encuentro de Lurker con 5 supervivientes: `PAUSE_SCALE` y `STALK_SCALE` (`lurker_brain.gd:132-133`) tienen 4 valores, para 1 a 4. No leí el índice que se usa con 5.
- Peso de tipología: `typology_of()` no leído (`office_palette.gd:40` solo comenta el peso).
- `drawing` (factor de `least_walk`, `office_generator.gd:173`): no leído.
