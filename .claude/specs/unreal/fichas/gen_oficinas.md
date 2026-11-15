# Ficha de hechos: generación de las oficinas (piso 2)

Ficha «gen_oficinas» para el estudio de porteo a Unreal. Solo hechos del código del repo, leídos a mano. Nada ejecutado: ni Godot, ni compilación, ni git.

Rutas relativas a la raíz del repo. Cada cifra va con su ruta:línea.

**Estado del árbol.** Al empezar la sesión, git marcaba como modificados (sin commit): `game/world/generation/office_generator.gd`, `office_recipes.gd`, `game/floors/palettes/office_palette.gd`, `tests/office/*` y `tools/*` relacionados. La ficha describe el árbol de trabajo tal como se leyó, no el último commit (e50a862).

---

## 0. Qué es, en cuatro líneas

- `office_generator.gd` (3686 líneas) dibuja una tirada del piso 2: tipos y salas de tres plantas, puertas, y once pasos de sistemas de planta en `furnish()` (vestíbulo, archivos, correo con tubos, corriente, aire, enchufes, cristal, columnas, muebles, ductos y ducto principal). Hereda casi todo el algoritmo de `map_generator.gd` (hotel) y lo sustituye en los pasos de oficina.
- `office_recipes.gd` (840 líneas) pone los muebles libres de cada sala según su receta (`palette.ROOM_FURNITURE`).
- `office_layout.gd` (384 líneas) da la geometría de paso de cada sala: qué zonas un mueble no puede tapar.
- `office_validator.gd` (1335 líneas) comprueba el manifiesto con 19 grupos de reglas y, en un piso montado en el motor, la física (`validate_physics`).

Todo lo de arriba es lógica de datos (RefCounted, diccionarios y arrays). Solo `validate_physics()` toca el mundo de física. El piso se ve en el juego por `office_floor.gd` y las geometrías de `game/world/office/` (fuera de esta ficha).

---

## 1. Inventario de lectura

| Archivo | Líneas | Cómo se leyó | Qué hace |
|---|---|---|---|
| game/world/generation/office_generator.gd | 3686 | entero (1 a 3686) | Generador de oficinas: sobrescribe el del hotel en tipos, salas, ductos y sistemas. |
| game/world/generation/office_layout.gd | 384 | entero | Geometría de sala: muros, zonas de paso, taquillas, cuadros de pared. |
| game/world/generation/office_recipes.gd | 840 | entero | Colocación de muebles por receta, recetas de pared, pasillos y puertas abiertas. |
| game/world/generation/office_validator.gd | 1335 | entero | Validador: 19 grupos de reglas sobre el manifiesto, más `validate_physics()`. |
| .claude/specs/planta_real.md | 200 | entero | Nota de diseño del edificio nuevo (secciones 1 a 13) y su estado de construcción. |
| game/floors/office_floor.gd | 88 | entero | Tipo de piso 2: nombres, etapas, objetivos. Declara `GENERATOR` y `VALIDATOR` (`:14-15`) pero no los llama. |
| game/world/generation/map_generator.gd | 2116 | solo 1 a 450 (candidate, generate, lay_grid, lay_planta, order_field, drift), más firmas (`grep`) y `weighted`, `shuffle` (1667-1678, 2078-2084) | Base del hotel. Todo lo que el generador de oficinas no sobrescribe se hereda de aquí. |
| game/floors/palettes/office_palette.gd | 1217 | parcial: todas las constantes y funciones (`grep ^const`, `grep func`, con su línea), y los tramos 12-60, 93-170, 186-196, 486-520, 604-625, 645-665, 828-880, 1000-1012, 1042-1086, 1165-1217 | Paleta: números de tipo, cifras, tablas (recetas, bandas, pesos, programa del edificio nuevo). |
| docs/OFICINAS.md | 1031 | parcial: 1-19, 661-735 (11.2 y 11.3), 794-826 (11.7), 889-907 (13) | Diseño aprobado del piso 2. Sección 11.3 describe el generador actual. |
| game/app/hotel_main.gd | solo fragmentos | solo `grep` (líneas 865-867, 899, 960) | Quién llama al generador y al validador de física. |
| tests/office/* | cabeceras y listas de funciones | `head` y `grep ^func` | Qué comprueban las pruebas (ver §13). |
| .claude/godot-api/doc/classes/RandomNumberGenerator.xml, @GlobalScope.xml, Array.xml | 3 | solo las partes citadas | Versión del motor y documentación de `hash`, `randi_range`, `sort_custom`. |

No leído: `floor_definition.gd` (321), `conduit_metres.gd` (219), `map_validator.gd` (316), `wall_walker.gd`, el resto de `map_generator.gd`, `.claude/specs/fichas/planta.md` (414), el resto de `office_palette.gd` y de `docs/OFICINAS.md`.

---

## 2. Algoritmo, paso a paso

### 2.1 Entrada y reintentos (heredado, `generate()`)

- `generate(run_seed, survivors := 2)`: `game/world/generation/map_generator.gd:105-121`. Se llama desde `game/app/hotel_main.gd:865` (`GENERATOR.new().generate(seed_value, drawn_for if drawn_for > 0 else survivors)`).
- Áreas por planta: `palette.areas_for(survivors)`, `game/floors/palettes/office_palette.gd:148-155`.
  - 1 superviviente: `[1.0, 0.5, 0.5]`. 2 y 3: `[1, 1, 1]`. 4: `[1.2, 1.2, 1.2]`. 5: `[1.35, 1.35, 1.35]` (`AREA` en `:144`).
- Intentos: `attempts()` devuelve 12 en oficinas (`office_generator.gd:45`; el hotel tiene 8 en `map_generator.gd:45`).
- Por cada intento: `candidate(run_seed, attempt)`. Si `walk < min_walk()` falla con `"walk"`. Si `validator().validate(result)` trae errores, falla con `"invalid_<motivo>"` y pasa al siguiente. Si no trae errores, el resultado sale con `fallback = false`.
- Si los 12 fallan: `candidate(404, 0, true)` (planta de reserva, `standby`), con `fallback = true` y `requested_seed`: `map_generator.gd:118-121`.
- `min_walk()`: `min(30, round(30 * media de áreas))` (`map_generator.gd:2003-2006`). Con áreas 1, da 30.

### 2.2 Una tirada: `candidate(run_seed, attempt, standby)`

Oficinas: `office_generator.gd:50-62` (sobrescribe) y base `map_generator.gd:138-219`.

1. **Edificio.** `building = draw_building(run_seed, attempt)` si `real_plan` (el interruptor, ver §7) y no es reserva; si no, `{}` (`office_generator.gd:51`). Hoy, `REAL_PLAN = false` (`office_palette.gd:17`), así que `building` es `{}` salvo que se active.
2. **Reparto de planes.** `rng` con semilla `hash([run_seed, "floor", attempt])` (`map_generator.gd:141`). `deal()` (`office_generator.gd:3383` -> base `map_generator.gd:347-353`): un plan por planta sacado de `palette.DECKS` (`office_palette.gd:247`), sin repetir plan ni su pareja `APART`. Reserva: `["blocks", "blocks", "blocks"]`.
3. **Por planta** (base `map_generator.gd:153-174`):
   - `drawing = areas[planta]` (1.0 en reserva).
   - Hasta `TRIES = 6` intentos (`map_generator.gd:46`). Cada uno con su `rng` de semilla `hash([run_seed, "planta", planta, attempt, tried])` (`:162`).
   - `lay_grid()` (oficinas `office_generator.gd:3389` -> base `map_generator.gd:237-251`): columnas entre `fewest = max(5, round(8*sqrt(drawing)))` y `most = round(13*sqrt(drawing))`; filas con `ceil(randf_range(100, 118) * drawing / columnas)` acotado al mismo rango y con al menos `100*drawing` celdas; carriles de 2 a 4 por eje (`widest`, `:244`). Reserva: 10 x 10 con carriles fijos (`:241-242`, `:275`).
   - `open_planta()` crea las celdas (`map_generator.gd:310-320`, celda en `:301-306`). Si el intento falla, `drop_planta()` las borra (`:323-331`).
4. **`lay_planta()`** (base `map_generator.gd:362-421`). En este orden:
   - `order_field()`: a cada celda un valor `order` en [0, 1] (`:433-442`), con base `ORDER_BASE = [0.8, 0.62, 0.55]` (`office_palette.gd:253`), gradiente aleatorio y ruido `drift()` (`:448-466`).
   - `target = rng.randi_range(scaled(84), scaled(96))` (`map_generator.gd:368`, `TARGET` en `:38`). Reserva: `TARGET.y`.
   - Celdas vivas: las de tipo `module` (`:369-371`).
   - Si no es reserva: `pick_shape()` corta una forma (oficinas: `office_generator.gd:3402` devuelve el contorno del edificio o, hoy, la base `map_generator.gd:467-516`, con `SHAPES = rect, notch, ell, you, court, aitch`, `:54`).
   - `corridors()` (oficinas `office_generator.gd:3408`; hoy, base `map_generator.gd:573-691`): carriles como pasillo, según el plan del planta.
   - `pick_start()` si no hay entrada (oficinas `:157-163`: la recepción en una celda con pasillo a su puerta, cuando hay candidatas; si no, base `:795`).
   - `plant_service()` (oficinas `:3417`, base `:810-840`): banda de servicio. Hoy, azar por `order` (`map_generator.gd:832`).
   - `open_doors()` (oficinas `:3434`; hoy, base `:841-876`): puertas entre celdas según `order` y `ROOM_DOORS` (`office_palette.gd:250`).
   - `join()` (base `:902-956`): une lo que queda suelto.
   - `make_halls()` (oficinas `:144-154`): en planta 0 hoy, primero `make_nave()` (una nave de oficina abierta o cubículos, `:213-242`), luego los salones de la base.
   - `trim()` (oficinas `:3568`, en hoy base `:1311`), `loops()` (oficinas `:3582`, en hoy base `:975`), `place_refuge()` (oficinas `:170-178` -> base `:1420`), `trim()` otra vez, `tidy()` (oficinas `:3573`, en hoy base `:1343`), `expose()` (oficinas `:3641`, en hoy base `:1120`).
   - `place_specials()` (oficinas `:276-297`): planta 0 la ventanilla, planta 1 el cuadro eléctrico, planta 2 `place_air()` (`:377-400`): puesto de seguridad, sala y planta de aire, ducto principal.
5. **Comprobaciones de la planta** (base `:399-407`):
   - recuento de salas dentro de `rooms_window(drawing)` (`office_palette.gd:156-159`: `ROOMS = (81, 99)` por área; con edificio, `REAL_ROOMS = (45, 99)`);
   - `cycles(f, alive) >= palette.rings(drawing)` (`office_palette.gd:164-165`: 4 si el área es menor que 1, si no 6). Oficinas `cycles()` (`office_generator.gd:126-139`) descuenta las costuras dentro de cada salón;
   - `alike() <= ALIKE = 0.3` solo fuera de reserva (`map_generator.gd:51`, `:404`). Con edificio, `alike()` devuelve 0 (`office_generator.gd:3645-3647`);
   - `in_depth()` de la sala del refugio dentro de `DEPTHS[planta]`: `(0.65, 0.9)`, `(0.8, 0.97)`, `(0.6, 0.9)` (`office_palette.gd:256`).
   - Las celdas no vivas pasan a `VOID` (tipo 20). El vestíbulo de llegada, marcado `landing`.
6. **Encadenado de plantas.** La siguiente planta se dibuja bajo el vestíbulo del montacargas de la anterior (`map_generator.gd:177-180`, `anchor`). `back` es la salida del refugio (`:180`). Se guardan `gates`, `entries`, `refuges`, `walk` (`:162-176`).
7. **Centrado.** Las coordenadas se restan del centro de la recepción (`map_generator.gd:187-193`). Las áreas van en `f.areas` (`:194`).
8. **`finish()`** (oficinas `office_generator.gd:574-614`; con rng `hash([run_seed, "rooms", attempt])`, base `:195-197`). Pasos:
   - `zones(f, entries)` (oficinas `:3667-3673`; hoy, base `map_generator.gd:1787`): sector (departamento) de cada celda.
   - Pasillos y galerías (`:579-585`). Las galerías salen de `gallery_lines()` (`:696-704`): cada línea de carril es galería con probabilidad `GALLERY_SHARE = 0.15` (`office_palette.gd:448`). En edificio, la galería de cada planta es la fila de servicio.
   - Nombres de departamento (`name_departments()` `:777-799`): uno por sector, de la tabla `DEPARTMENTS` (`office_palette.gd:467`). En la planta 3, el sector del puesto se llama SEGURIDAD y el del aire MANTENIMIENTO (`:793-797`).
   - Tipos fijos (`:587-605`): recepción (0) en `start`; vestíbulo (10) en la entrada de las plantas 2 y 3; rellano (9) o planta de aire (23) en la celda `landing`; refugios (19) y sala de aire (22); ventanilla (17), cuadro (18), puesto de seguridad (21). Los refugios pierden `hall` y `service`.
   - Hoy: `type_rooms()` (`:619-655`). Salones por `HALL_MIX` (`office_palette.gd:480`) con pesos multiplicados por `FOCUS = 3.0` (`:473`) si el departamento los pide. Archivo solo si las celdas van en recto (`straight()`) y caben en su banda. Resto por `PLANTA_MIX` (`:475`) y foco. Celdas de servicio por `SERVICE_BY_PLANTA` (`:481`). Sala de juntas comprobada con `boardroom_fits()` (`:856-859`).
   - Edificio: los tipos salen del programa (`building.programme`, `:609-612`).
   - `cap_numbers()` (`:983-1007`): si hay más de `NUMBERED_MOST = 96` salas numeradas (`office_palette.gd:146`), las sobrantes pasan a depósito (`DEPOT`, 25), con la regla de «más cerca del servicio primero».
   - `finish_rooms()` (`:658-692`): eje de nave en sus celdas, cuatro ranuras de esquina por sala (`palette.RECIPES`, `office_palette.gd:190-221`, tiradas con el rng de decoración), y lados abiertos (`open_sides`).
   - Hoy también: `place_musts()` (`:867-963`): lo que cada planta debe tener (`MUSTS`, `office_palette.gd:482`):
     - planta 1: descanso (15) 1, juntas (5) 1;
     - planta 2: archivo (6) 2, correo (14) 1, reprografía (7) 1;
     - planta 3: juntas (5) 1, dirección (16) 2, secretaría (24) 1.
     - Aseos: uno por sector de 5 celdas o más (`:943-955`).
   - `suites()` (`:712-746`): una secretaría junto a un despacho de dirección, con puerta entre los dos (la puerta se abre en `open_doors` de recetas).
9. **Numeración, puertas, taquillas, luces** (todo heredado de la base, sin sobrescribir):
   - `number_rooms()` (`map_generator.gd:1955`), rng `hash([run_seed, "plaques", attempt])` (`:199-201`).
   - `hang_doors()` (oficinas `office_generator.gd:64-91` -> base `map_generator.gd:1843`): puertas, con dos retoques de oficina (un hueco de ascensor se aleja de la pared del cubo y la hoja de un archivo cuelga del marco lejos del centro).
   - `place_hides()` (base `:1885`): taquillas en paredes, con `hide_free()` (oficinas `:96-111`) y `hide_apart()` (`:115-117`). En edificio, `hide_free` exige pared de 6 m o más en salas estrechas.
   - `light_rooms()` (base `:1931`): salas oscuras, rng `hash([run_seed, "wear", attempt])` (`:207-209`).
10. **`furnish()`** (oficinas `office_generator.gd:1021-1045`). Se ve en §4.
11. **Resultado.** Base `map_generator.gd:217-219`: clave `version = OFFICE_PALETTE.VERSION` (oficinas `:55`, `= 2`), `floor = 2` (oficinas `:54`), más lo que devuelve `furnish()`.

### 2.3 Cifras que pesan en el paso a paso

- Ventana de salas por área: 81 a 99 (`ROOMS`, `office_palette.gd:145`).
- Pesos del `target` (`scaled(84..96)`): salas a sortear antes de cortar.
- Profundidad del refugio por planta (`DEPTHS`, `:256`); del ventanilla (`WINDOW_DEPTH` `(0.15, 0.45)`, `:403`); del cuadro (`ELECTRICAL_DEPTH` `(0.4, 0.7)`, `:404`); de seguridad (`SECURITY_DEPTH` `(0.25, 0.55)`, `:405`).
- Metros de la llegada a la salida: `LEAST_WALKS = [90, 0, 0]` (`:264`), solo planta 0. Con edificio, `REAL_LEAST_WALKS = [75, 0, 0]` (`:44`).
- Ducto principal: `MAIN_LENGTH` `(25, 45)`, `MAIN_IDEAL = 35`, `MAIN_BENDS = 2` (`:419-421`). En reserva, 15 a 70 y al menos un codo (`office_generator.gd:530`).
- Exposiciones de pasillo (heredadas, `expose()`): `EXPOSED = [0, 20, 28]` (`:294`), `EXPOSED_CHANCE = [0, 0.5, 0.8]` (`:295`). Con edificio, `expose()` no hace nada (`office_generator.gd:3641-3643`).

---

## 3. Modelo de datos de salida

El manifiesto es un diccionario. Todo lo que el juego lee sale de aquí.

### 3.1 Nivel superior

De la base (`map_generator.gd:217`): `version`, `seed`, `area`, `areas`, `walk`, `attempt`, `plantas` (`[{base, width, height}]`), `start`, `exit`, `refuges`, `gates`, `wings`, `rooms`, `edges`, `adjacency`, `ambient_seed`, `merged`, `doors`, `wall_hits`, `entries`, `plans`, `start_facing`. Más `fallback` y `requested_seed` (`generate()`, `:118-120`).

De oficinas: `floor` (2), `version` (2), `departments` (`[[{sector, name, colour}] x 3]`), `plenum` (`PLENUM` de la paleta, `office_palette.gd:409`), `arrival_lift` (`[x, z]`) y `arrival_lift_along` (`office_generator.gd:2839-2861`), y los sistemas `mail`, `tubes`, `power`, `air`, `ducts`, `archives` (§4).

### 3.2 Celdas (`rooms[i]`)

Un `Dictionary` por celda; `id` es el índice (`map_generator.gd:301-306`):

- rejilla: `id, x, z, cols, rows, wing` (planta), `kind` ("module", "lane", "cross"), `type`, `sector`, `hall` (id del salón, -1 si no), `corridor` (bool), `service` (bool), `order`;
- geometría: `px, pz` (centro en metros, relativo al recepción tras el centrado), `py` (`FLOOR.planta_y()`, no leído), `span_x, span_z` (tamaño de la celda), `height` (`palette.height_of()`, `office_palette.gd:828-829`);
- oficinas: `props` (`[{kind, slot 0-3, rotation}]`), `cover_slots = 4`, `variant` (0-3), `layout = 0`, `nave_axis` ("x", "z" o ""), `open_sides` (lados sin pared), `sockets` (4 puntos `[x, z]` a `SOCKET_INSET = 1.3` de las paredes, `office_palette.gd:453`, `office_generator.gd:1559-1572`), `columns` (`[{x, z}]`), `furniture` (ver §8), `feature` (pared que mira la cámara), `glazed` (lados con cristal), `hides` (`[x, z]` de cada taquilla), `dark` (bool), `landing` (bool), `lift` (`[x, z]` del muro del ascensor, `map_generator.gd:185`), `sector`. `kept` lo usa `duct_gaps()` (`office_generator.gd:2648`), pero no he leído dónde se escribe (probablemente la base).

Tipos (`office_palette.gd:107-135`, `TYPES` en `:172`, un nombre por índice):

| Nº | Constante | Tipo |
|---|---|---|
| 0 | RECEPTION | recepción interna |
| 1 | OPEN_OFFICE | oficina abierta |
| 2 | CUBICLES | cubículos |
| 3 | OFFICE | despacho |
| 4 | TOILETS | aseos |
| 5 | BOARDROOM | sala de juntas |
| 6 | ARCHIVE | archivo |
| 7 | COPY_ROOM | reprografía |
| 8 | STORE | almacén |
| 9 | LANDING | rellano del montacargas |
| 10 | LOBBY | vestíbulo de llegada |
| 11 | CORRIDOR | pasillo |
| 12 | GALLERY | galería de servicio |
| 13 | MOBILE_ARCHIVE | archivo móvil |
| 14 | MAIL | correo (ventanilla de personal) |
| 15 | BREAK_ROOM | descanso |
| 16 | EXEC_OFFICE | despacho de dirección |
| 17 | WINDOW | ventanilla |
| 18 | ELECTRICAL | cuadro eléctrico |
| 19 | REFUGE | refugio |
| 20 | VOID | celda no usada |
| 21 | SECURITY | puesto de seguridad |
| 22 | AIR_ROOM | sala de aire |
| 23 | AIR_PLANT | planta de aire (climatización) |
| 24 | SECRETARY | secretaría |
| 25 | DEPOT | depósito |

Altura por tipo (`HEIGHTS`, `office_palette.gd:222`): 2.95 m con falso techo; 4.4 m en la galería (12), la sala de aire (22) y la planta (23). Sin falso techo en esos tres (`false_ceiling()`, `:833-834`: altura menor que `slab - 0.01`).

### 3.3 Grafo de puertas y ductos

- `edges` y `adjacency`: pares de ids globales; `merged` agrupa las celdas unidas en un salón (`merged[pair_key]`). Puertas abiertas: `doors["a:b"] = {offset, hinge, swing, open, lock?}` (`hang_doors`).
- `gates`: `[{stage, room, beyond, out: [x, y], arrive}]` (`map_generator.gd:176`). Son los huecos de ascensor.
- `ducts`: `{nodes, edges, exits}`:
  - nodo: `[x, y, z, room, kind]`, con kind en `trunk, branch, stub, main, hatch, shaft, exit` (`office_generator.gd:2344-2347`);
  - arista: `[a, b, metros, kind]`, con kind en `trunk, branch, bridge, loose, express, main, cross, drop` (`:2355-2361`, `:2404-2415`);
  - salida: `{node, room, kind, point, yaw}`, con kind en `ceiling, duct, wall, hatch, gap` (`exit_*`, `:2505-2570`, `:2644-2667`).
- `tubes`: `{nodes, rooms, edges, exits, hub}` (`office_generator.gd:1150-1181`). Aristas `[a, b, metros, "tube"]`. Salidas `{node, room, kind: "hub"|"station", point, yaw, number, tube}`.
- `archives`: `[{rooms, axis, mobile, open, height, wall_gap, spine: [x0, z0, x1, z1], rows: [[x0, z0, x1, z1]...], aisles: [...]}]` (`lay_archive`, `:2892-3006`).

### 3.4 Sistemas (furnish)

- `mail`: `{window, desk: {wall, along, point, yaw}, stand, camera, camera_target, map, reader, stations}` (`office_generator.gd:1181`).
- `power`: `{room, board: {wall, along, point, yaw}, circuits: [{code "R-n", name, sector, colour, lever, rooms}], lift_lever, timers: [{rooms, sector, room, wall, along, point, yaw}]}` (`:1394`).
- `air`: `{security: {room, door, outside, desk, reader}, room, plant, hatch: {point, yaw, node}, unit, stop, shaft: {point, side, rect, floor_y, ladder, node}, main: {nodes, cells, length, bends, cross, stub}, remains: {point, along}}` (`:1547`, `:2716`, `:2698-2716`).
- `mail.reader`, `security.reader`, `timers`: spots de pared (`wall_spot`, `:2734-2735`) con `point` (metros, `[x, y, z]` redondeado a mm).
- Puntos: todos los números que van al manifiesto se redondean a milímetro (`snappedf(..., 0.001)`, `rounded()` en `:2738-2739`).

---

## 4. Sistemas: `furnish()` en orden

`office_generator.gd:1021-1045`. Antes de nada, un ensayo de los ductos en las tres plantas (`duct_skeleton`, `:1026-1028`): si una planta no queda en una sola pieza, falla con `"duct_bridge"`. Luego registra cada taquilla como pared ocupada (`:1030-1033`, medio metro de semiancho: `0.65`).

Después, los pasos en este orden (`:1034`): `furnish_lobby`, `furnish_archives`, `furnish_mail`, `furnish_power`, `furnish_air`, `furnish_sockets`, `furnish_glass`, `furnish_columns`, `furnish_furniture`, `furnish_ducts`, `furnish_main`. Cada uno devuelve `""` o un motivo. Un motivo corta el intento (`{"fail": motivo}`, base `:213`).

| Paso | Líneas | Qué pone | Motivos de fallo |
|---|---|---|---|
| furnish_lobby | 2814-2864 | Muro del ascensor de llegada en la recepción, sin puerta. Prueba los dos lados del muro y centra si cabe el mostrador (`reception_counter`) | ninguno |
| furnish_archives | 2868-2889 | Filas de estantería de cada archivo (`lay_archive`) | ninguno |
| furnish_mail | 1049-1182 | Mostrador de ventanilla en la pared lejos de la puerta; cámara en el muro de enfrente, a `CAMERA_DROP = 0.15` bajo el techo; mapa a 1.2 m; hub de tubos; lector de tarjetas junto a la puerta de etapa (`mail_reader`, `:1186-1206`); entre 8 y 14 estaciones, `round(11*sqrt(area)) +- 1` (`:1087`); tubos en árbol (`tube_points`, `:1260-1313`). Separación de estaciones `STATION_APART * sqrt(area)` (`:1127`) con relajación 0.8 si no hay | `window_desk`, `mail_reader`, `stations` |
| furnish_power | 1317-1395 | Cuadro en una pared lejana del cuarto eléctrico (en `0`, `-1.8` o `1.8`, `:1326`). Un circuito por sector, con palanca en orden aleatorio (`:1334-1347`). Minuteros en tramos de pasillo con `TIMER_P = 0.65` (`:1376`) hasta cubrir `TIMER_COVER = 0.5` del pasillo (`:1382`) | `board`, `timers` |
| furnish_air | 1437-1551 | Puesto de seguridad con puerta de tarjeta (`lock = "card"`, `open = false`, `:1446-1447`) y su mostrador; lector fuera; escotilla sobre la planta de aire, hacia la primera celda del ducto principal (`:1496`); manejador (`unit`) en un muro libre, a 3.0 x 2.2 x 1.5 m (`AIR_UNIT`, `office_palette.gd:433`), y tope (`stop`) a `STOP_Y = 1.3`; pozo al final del ducto (`:1533-1548`) | `security_desk`, `security_reader`, `unit`, `stop` |
| furnish_sockets | 1555-1590 | Cuatro ranuras de esquina por sala; quita las piezas de esquina que chocan con taquillas, con la ventanilla, con puertas, con la escotilla o el manejador | ninguno |
| furnish_glass | 1594-1651 | Cristal entre la ventanilla y el pasillo siempre (`:1609-1611`, `"window_glass"`). Otras salas de tipo vidriado (`GLAZED_TYPES = [3, 16, 17, 21, 24]`, `office_palette.gd:459`) con probabilidad `GLAZED_P = 0.55` por muro (`:1616-1623`); en edificio, por departamento con `REAL_GLAZED = [0.9, 0.1]` (`:462`, `:1619-1620`) | `window_glass` |
| furnish_columns | 1667-1688 | Columnas de nave en cada costura de módulos (`COLUMN_OFF = 2.1` del eje del pasillo, `office_palette.gd:281`), solo si `columns_on()` (`:279`) y la nave es de dos celdas de ancho. Cada columna se acepta si cabe (`column_fits`, `:1754-1763`) | ninguno |
| furnish_furniture | 1774-1851 | Muebles de cada sala según su receta (§8). Pasillos: mobiliario de pared cada 5 a 8 m (`HALL_KINDS`, `office_palette.gd:810`). Después `RECIPES.open_doors` abre puertas de salas con luz con probabilidad `OPEN_LIT = 0.6` (`office_palette.gd:724`, `office_recipes.gd:820-840`) | ninguno |
| furnish_ducts | 2165-2266 | Grafo de ductos de las tres plantas: troncos sobre pasillos, ramal por sala (`duct_skeleton`, `:2272-2341`), lazos sueltos con `LOOSE_P = 0.3` (`:2186`) si el atajo pasa `SHORTCUT_MIN = 0.55` del paseo (`:2187`), trazos rectos `EXPRESS_PER = 30` por planta (`:29`), cruce con el ducto principal (`duct_cross`, `:2419-2468`), salidas (`duct_exits`, `:2574-2641`) y huecos (`duct_gaps`, `:2644-2667`) | `duct_bridge`, `main_cross`, `duct_exit` o `duct_exit_<TIPO>`, `gaps` |
| furnish_main | 2671-2717 | Ducto principal: escotilla, nodos de las celdas del ducto, pozo, arista de cruce, restos (`REMAINS`, `office_palette.gd:435`) | ninguno |

Cifras de los ductos: plénum `ceiling 2.95`, `slab 4.4`, `duct_y 3.7`, `main 1.2`, `duct [1.0, 0.8]`, `branch [0.5, 0.3]` (`office_palette.gd:409`). Escotilla `HATCH: in 1.5, stand 0.75` (`:424`). Cruce `STUB = 1.5` (`:426`). Distancia mínima de la red al ducto `MAIN_CLEAR = 1.2` (`:429`). Pozo `SHAFT = (2.2, 2.2)` (`:431`).

---

## 5. Semilla y azar

### 5.1 Cómo se siembra

- Cada tirada de planta: `hash([run_seed, "planta", planta, attempt, tried])` (`map_generator.gd:162`).
- Por tirada completa: `hash([run_seed, "floor", attempt])` (`:141`), `"rooms"` (`:196`, decoración de tipos, nombres de sala, esquinas), `"plaques"` (`:200`, numeración), `"fittings"` (`:204`, puertas y taquillas), `"wear"` (`:208`, luces y salas oscuras).
- Orden: `hash([run_seed, "order", x, z])` (`map_generator.gd:458`, función `patch`), para el ruido `drift()`.
- Sistemas de oficina: `stream(run_seed, attempt, name)` = `hash([run_seed, "office", name, attempt])` (`office_generator.gd:1013-1016`). Nombres usados: `"tubes"` (`:1052`), `"power"` (`:1320`), `"glazed"` (`:1597`), `"recipes"` (`:1780`), `"halls"` (`:1846`), `"open_doors"` (`:1850`), `"ducts"` (`:2168`), `"air"` (`:2675`), `"archives"` (`:2871`). Edificio: `hash([run_seed, "building", attempt])` (`:3030`).
- Planta de reserva: siempre `candidate(404, 0, true)` (`map_generator.gd:118`).
- `hash()` de GDScript sobre arrays de enteros y cadenas. La documentación local (`.claude/godot-api/doc/classes/@GlobalScope.xml:273-278`) no describe el algoritmo (descripción vacía).

### 5.2 Dónde se saca azar

- `RandomNumberGenerator` (`rng.randi_range`, `rng.randf`, `rng.randf_range`, `rng.randi`), ocurrencias: 39 en `office_generator.gd`, 4 en `office_recipes.gd`.
- `shuffle(list, rng)` propio (`map_generator.gd:2078-2083`): Fisher-Yates con `randi_range`.
- `weighted(candidates, rng)` propio (`map_generator.gd:1667-1676`): una tirada `randf() * total`.
- Ninguna llamada a `randf()` global (sin `rng`) en estos archivos. `randomize()` no aparece.

### 5.3 Qué parte del orden depende de la estructura de datos

- Diccionarios en GDScript recorridos con `for key in dict`: el orden es el de inserción (no comprobado en la documentación local). Ejemplos comprobados: `structure` (`office_generator.gd:587-605`), `f.merged.values()` (`:687`, y en la base `map_generator.gd:214-215` se ordena después).
- `sort_custom`: la documentación local no dice si es estable (`Array.xml:385-390`). En casi todos los sitios hay desempate explícito por id. Sin desempate: `office_generator.gd:3252`, `runs.sort_custom(func(a, b): return a.size() > b.size())`, después de un `shuffle(runs, rng)`. Con varias naves del mismo tamaño, el orden depende del algoritmo de orden del motor.

---

## 6. El validador

`office_validator.gd`: `validate(data)` = base (`map_validator.gd`, no leído) + `office(data)` si `floor == 2` (`:17-20`). `office()` (`:23-45`) ejecuta 19 grupos en este orden. Los que tienen un número lo llevan en el comentario del código.

| Nº | Función | Líneas | Qué asegura |
|---|---|---|---|
| 1 | plenum_ok | 95-111 | Plénum con sus claves; cotas de ducto por encima del techo más alto con falso techo, más 0.05 m. |
| 2 | rooms_ok | 114-126 | Tipo válido; altura igual a `height_of`; salas oscuras solo si `may_be_dark`; archivos y junta sin mobiliario ni en el ducto. |
| 3 | specials_ok | 129-148 | Una ventanilla, un cuadro, un puesto de seguridad, una sala de aire y una planta de aire; refugios y vestíbulos en su sitio. |
| 4 | depths_ok | 161-173 | Profundidades de ventanilla, cuadro, seguridad y refugio dentro de bandas (`SLACK = 0.01`); recorrido de la planta 0 `>= LEAST_WALKS[0] * sqrt(area) - 0.5`. No se aplica a la reserva. |
| 5 | departments_ok | 177-200 | Tres listas de departamentos; nombres, colores y sectores únicos; SEGURIDAD en el sector del puesto. |
| 6 | lockers_ok | 203-216 | Taquillas solo en tipos con `WARDROBES`; no en puerta ni a menos de `WALL_APART` de otra. |
| 7 | archives_ok | 220-292 | Unidad recta; filas dentro, separadas; espina por el centro; pasillos `>= AISLE_MIN = 0.95`; puertas despejadas. |
| 8 | mail_ok | 304-393 | Ventanilla (escritorio, pared, cámara a `WINDOW`), lector a 1.5 m de la puerta, 8 a 14 estaciones numeradas, árbol de tubos conexo, tubos sobre salas que dicen. |
| 9 | power_ok | 398-437 | Cuadro en su sala; un circuito por sector en orden de palanca (`R-n`); cada sala en un circuito; minuteros sobre pasillos; cobertura `>= 0.5`. |
| 10 | air_ok | 445-543 (y `cross_ok` 552-582) | Puerta de tarjeta cerrada; escritorio, lector, escotilla, manejador, tope y pozo; cadena del ducto principal; longitud `25 a 45` (`:508-509`); dos codos; cruce único. |
| 11 | ducts_ok | 588-642 (y `express_ok` 649-661, `exits_ok` 664-741) | Nodos y aristas coherentes; tronco y ramal con puerta; atajos `>= 0.55`; un pozo por planta; salidas y huecos según la tabla. |
| 12 | arrival_ok | 744-748 | Ascensor de llegada en muro cerrado de la recepción. |
| 13 | corners_ok | 752-791 | Ranuras por la regla; piezas de esquina fuera de taquillas, cuadros de pared, puertas, escotilla y manejador. |
| 14 | glazed_ok | 795-823 | Cristal en las dos caras del muro; ventanilla acristalada hacia el pasillo. |
| 15 | furniture_ok | 828-863 (y `against_wall` 872-877, `reach_ok` 886-959) | Muebles de los tipos de su receta, tamaños de la tabla, fuera de zonas de paso; en una nave, altura máxima `NAVE_TOP = 1.3` salvo contra pared (`:867`); alcanzabilidad de la nave con un cuerpo de 0.32 m en rejilla de 0.2 m (`:884-885`). |
| 16 | columns_ok | 966-1005 | Naves con eje; columnas solo en naves, en lados abiertos y con la celda de enfrente; sin chocar con pasos, puertas, lámparas, muebles ni rejillas. |
| 17 | rings_ok | 1010-1033 | Número de vueltas por planta `>= rings(area)`, contando el grafo de puertas menos los salones. |
| 18 | glass_ok | 1043-1056 | Nada a menos de `GLASS_CLEAR = 0.6` de un cristal; las piezas de esquina sobre el antepecho (`GLASS_LOW`) no cuentan. |
| 19 | hall_ok | 1060-1071 | Mobiliario de pasillo solo en pasillos de 3 m o más, de hasta 0.5 m de fondo, con `HALL_PASS = 2.0` libres. |

Física (`validate_physics()`, `:1084-1239`; sobrescribe el de la base, que llama a `super`). Solo en un piso montado en el motor (`hotel_main.gd:960`).
- Cápsula de 0.32 m de radio y 1.8 m de alto (`:1090-1092`); ojos a 0.94 m (`:1108`).
- Umbral de barrido: `cast_motion(...)[0] < 0.99` cuenta como choque (`:1124`, `:1131`, `:1157`, `:1236`).
- Rayos desde cada salida: tramo de 2.25 m y 2.6 m (`:1169-1170`); pared: 1.0 m (`:1172`).
- Banda sobre el falso techo: entre 2.25 m y `height - 0.05` (`:1193-1194`), con sangría `0.25 + WALL_HALF` (`:1196`). Excluye los armarios (`HIDE`) por su `get_parent()` (`:1177`, `:1213`).
- Sala de juntas: pasillo a ambos lados de la mesa (`:1218-1238`).
- Para una nave, la comprobación del centro y de la taquilla se hace desde el pasillo (`:1098-1112`).

Reglas de la validación de la base y de los cambios de `office_validator.gd` sobre ella: `map_validator.gd` no leído (316 líneas).

---

## 7. El edificio nuevo: qué está hecho y qué solo está diseñado

Fuente de diseño: `.claude/specs/planta_real.md`. Fuente de código: `office_generator.gd` (sección «The real building», `:3013-3686`), `office_palette.gd` (`:30-103`, `:486-505`, `:1165-1217`).

**Interruptor.** `REAL_PLAN = false` (`office_palette.gd:17`). Se enciende con `real_plan_test = true` en una herramienta, o con `--real-plan` en la línea de órdenes (`:20-21`). El generador lee el interruptor una vez, al crearse (`office_generator.gd:37`), y la paleta lo lee cada vez que se le pregunta (`office_palette.gd:94`, `:101`, `:157`, `:662`). Ver discrepancia 5.

**Construido en código (presente, con el interruptor apagado no se usa):**

| Pieza | Líneas | Descripción |
|---|---|---|
| Tipología «anillo» | `office_palette.gd:30-37` (solo `"ring"`), `office_generator.gd:3028-3132` | Filas: banda delantera, pasillo, dos centrales de 7.2, pasillo, banda trasera, galería de 2.4, servicio. Columnas: testeros, transversales, vanos de 7.2 por mitad (despachos de dos celdas de 3.6, o salas de una de 7.2). Todo múltiplo de 0.6 (`:30`). |
| Contorno con muesca | `office_generator.gd:3097-3107`, `NOTCH_P = 0.35` (`office_palette.gd:104`) | Con probabilidad 0.35, un extremo sin galería ni servicio. |
| Núcleos y montacargas | `:3028-3132` (`lifts`) | Dos núcleos en los extremos de la zona central, con montacargas A y B; climatización en el núcleo de A. |
| Recepción | `:3088-3093` | En el extremo de B, en esquina de la banda delantera o en el testero. |
| Cortes | `:3117-3128` | Planta 2: galería junto al transversal de B. Planta 3: un tramo de pasillo principal. |
| Programa por zonas | `draw_programme()` `:3186-3335`; `zone_of()` `:3135-3151`; `REAL_ZONES` `office_palette.gd:56-62` | Tipos por zona (oficina, bahía, esquina, extremo, profunda, estrecha, ascensor, núcleo, servicio), salones primero, aseos de dos en dos, lo que cada planta debe tener (`REAL_MUSTS`, `:63-70`). |
| Departamentos por tramo | `departments_of()` `:3341-3374`; `REAL_DEPARTMENTS = (5, 7)` (`:97`) | Tramos de bahías, sin cruzar transversal. |
| Naves, archivos, suites | `:3237-3298` | Naves sobre cada tramo de bahías entre núcleo y transversal; archivos en planta 2; suites de dirección en planta 3. |
| Puertas con motivo | `open_doors()` `:3434-3545` | Pasillos, naves con una puerta por pasillo principal, archivos por los dos extremos, depósitos en fila, juntas con dos puertas. Puertas de corredor cruzadas solo donde hay corte. |
| Salones y refugio | `real_halls()` `:3551-3566`; `real_refuge()` `:3610-3640` | Salones del programa; refugio en el vestíbulo del montacargas. |
| Zonas de la sala | `special_fits()` `:3653-3663`; `zones()` `:3667-3673` | Cuadro en banda de servicio, ventanilla en banda y celda de oficina, seguridad en su puerta. |
| Taquillas y minuteros por muro | `hide_free()` `:96-111`; `timer_button()` `:1407-1433` | Regla del largo del muro en salas de 3.6. |
| Clasificación de salas por banda | `ROOM_BANDS` (hoy) y `REAL_ROOM_BANDS` (`:71-95`) | Tamaños de sala por tipo; `fits_band_now()` (`:93-96`) solo lo usa un test (`tests/office/office_test.gd:515`). |
| Receta de despacho pequeño | `SMALL_FURNITURE` (`office_palette.gd:649-652`), `recipe_of()` (`:660-662`) | Sala de menos de 4.5 m de lado con receta propia, con el interruptor encendido. |
| Vueltas | `loops()` `:3582-3608` | Anillo más transversales por las salas con dos puertas, cuando el edificio está. |
| Vacías en el edificio | `trim()` `:3568`, `tidy()` `:3573`, `expose()` `:3641`, `alike()` `:3645` | Sin efecto cuando hay edificio. |

**Pendiente o no construido (según el código, no según el texto):**

- Tipología «espina»: no está (solo `"ring"` en `TYPOLOGIES`, `office_palette.gd:30-37`). Planta_real 7 y 13.7 la piden.
- Pasillo expuesto por arquitectura (20 m en planta 2, 28 m en planta 3): `expose()` no hace nada con edificio (`office_generator.gd:3641-3643`). Planta_real 13.10 lo pide.
- Escaleras de emergencia: pendiente del autor (planta_real.md:178).
- Espera de la ventanilla: `reception_wait` solo existe para la recepción (`office_recipes.gd:438-450`, `office_generator.gd:1832-1836`). Planta_real.md:200 dice que falta en la ventanilla.
- Validador de edificio: no hay ninguna rama del validador para el edificio (`grep` de `building|real_plan|programme` en `office_validator.gd`: 0 resultados). Planta_real 9 pide reglas nuevas; no están.
- Absorción de celdas de carril: no hay (planta_real 13.6 la aplaza, correcto).
- `in_core()` (`office_generator.gd:3378`) no tiene llamadas en el repo: código muerto.

---

## 8. Recetas de sala

Dos tablas distintas en la paleta:

1. **Esquinas** (`palette.RECIPES`, `office_palette.gd:190-221`): por tipo, cuatro ranuras (una por esquina, `""` vacía). Se tiran al azar con el rng de decoración (`office_generator.gd:673-684`): cada ranura recibe una clase de pieza de esquina (`CORNER_SIZES`, `office_palette.gd:577`), con su rotación. Las clases de pared (`WALL_KINDS`, `:314`) van con rotación fija por lado.
2. **Muebles libres** (`palette.ROOM_FURNITURE[tipo]`, `office_palette.gd:615-646`; `SMALL_FURNITURE` para salas pequeñas con interruptor encendido, `:649`). Formato de cada entrada: `[clase, cómo, mínimo, máximo, fila]`:
   - `clase`: clave de `palette.FURNITURE` (`:513-569`), con su tamaño (`size`), altura (`height`) y variantes (`compact`, `shorter`).
   - `cómo`: uno de `lattice` (rejilla de mesas, `lay_lattice`), `table` (mesa de juntas, `lay_table`), `back` (contra la pared característica), `wall` (contra ella o contra otra libre), `side` (contra otra libre o ella), `spare` (como `side`, sin prueba que exija que quepa), `middle` (de pie hacia la pared característica, `lay_middle`), `closed` (pared libre sin puerta), `run` (pegado al último tramo de pared, `lay_run`), `center` (centro de la pared característica con dos laterales, `lay_center`), `hall` (de corredor, `lay_halls`).
   - `mínimo, máximo`: número de tiradas (`rng.randi_range`).
   - `fila`: piezas seguidas en un mismo grupo.
   - Ver la cabecera de `ROOM_FURNITURE` (`office_palette.gd:604-614`).

**Cómo decide la colocación** (`office_generator.gd:1774-1851`, `office_recipes.gd`):
- Pared característica: `room.feature` (`RECIPES.feature_of`, `office_recipes.gd:216-229`, con reglas `palette.FEATURE_WALLS`, `:707`): mostrador, ventanilla, cuadro, planta de aire, ascensor, puerta de la dirección, o la pared más lejos de la puerta (`far_wall`, `:172-195`).
- Orden de paredes (`walls_for`, `:346-367`): las sin puerta primero, la de enfrente de la característica al final, y la que mira el ojo desde la puerta primero (`feature_end`, `:594-607`).
- Cada tirada prueba posiciones en orden: desde la esquina (`FROM_CORNER`, `:24`: 0.12 a 2.22 m) y luego `ALONG` (`:21`: 0, ±0.9 ... ±4.5 m) (`corner_first`, `:579-587`). `TURN_GAP = 0.5` para doblar la esquina (`:26`).
- Zonas que el mueble no puede tapar: `keep_clear()` (`office_recipes.gd:101-120`): zonas de paso de `LAYOUT.clear_zones()` (`office_layout.gd:267-337`), cristales (`GLASS_CLEAR`), esquinas (hasta la esquina), huecos tomados (`TAKEN_PAST = 0.1`, `:41`; `TAKEN_OUT = 0.6`, `:42`), escotilla y manejador (`air_zones`, `:127-136`), la línea de la cámara a la mecanógrafa (`mail.camera`).
- Medidas: `ITEM_GAP = 0.9` entre grupos (`office_layout.gd:26`), `NAVE_STREET = 1.2` en naves (`:30`), `WALL_GAP = 0.05` (`office_recipes.gd:19`).
- Puntos de partida para piezas libres: `MIDDLE_DEPTHS` (1.1 a 3.2 m, y -1.1 a -3.2, `office_recipes.gd:32`) y `MIDDLE_SIDES` (`:33`), probados en ese orden.
- `restore()` (`:277-297`): devuelve las esquinas quitadas que siguen cabiendo.
- Salones de un solo mueble (`ONE_PER_HALL`, `office_palette.gd:714`): se colocan en la celda cabecera (`hall_heads`, `office_recipes.gd:199-211`).

**Luces: no las decide ninguna receta.** Las lámparas las da la paleta:
- `palette.troffers(room)` (`office_palette.gd:1042-1078`): fluorescentes de dos baldosas cada `TROFFER_PITCH = 3.0` m (`:1004`), sobre la rejilla de baldosas de `TILE = 0.6` m (`:1003`).
- `lamp_of(room)` decide el tipo de lámpara (`:909`); `lamp_kelvin` (`:915`), `troffer_look` (`:919`).
- Las recetas solo usan las lámparas para evitarlas: `column_fits()` mira `COLUMN_LAMP = 0.9` (`office_generator.gd:1761-1762`; `office_palette.gd:284`).
- Las salas oscuras las decide `light_rooms()` de la base (`map_generator.gd:1931-1954`) con `DARK_OWN` (`office_palette.gd:306`) y `DARK_CORRIDOR` (`:308`).
- Puertas abiertas en salas con luz: `OPEN_LIT = 0.6` (`:724`), en `office_recipes.gd:820-840`.

---

## 9. Lógica pura frente a lo que toca el árbol de escena

**Lógica pura** (sin nodos, sin física; solo `Dictionary`, `Array`, `Vector2/3`, `Rect2`, `RandomNumberGenerator`, `Geometry2D`, `Basis`):
- `office_generator.gd` completo, salvo los `preload` de `OFFICE_PALETTE`, `OFFICE_VALIDATOR`, `METRES`, `LAYOUT`, `RECIPES` (`:7-11`).
- `office_recipes.gd` completo.
- `office_layout.gd` completo.
- `office_validator.gd`, salvo `validate_physics()` (`:1084-1239`), que toca el mundo, y las dos comprobaciones de nodo de `HIDE` (`:1177`, `:1213`).
- `office_palette.gd`, salvo `real_plan_on()` (`:20-21`, `OS.get_cmdline_user_args()`), `plan_fill()`/`plan_code()` (`:178-181`, `Color`), `STRIPES` (`:464`, `Color`), y `crawl_boxes()`/`shaft_box()` (`:1169-1217`, `AABB` con caché estática `crawl_manifest`/`crawl_cache`, consumida en tiempo de ejecución por `air_objective.gd:269` y `hotel_main.gd:1690`).

**Toca el árbol de escena o el mundo de física:**
- `OFFICE_VALIDATOR.validate_physics(world: World3D, data)` (`office_validator.gd:1084`). Pide `world.direct_space_state` (`:1089`), lanza `intersect_shape`, `cast_motion`, `intersect_ray` (`:1112`, `:1124`, `:1131`, `:1157`, `:1175`, `:1213`, `:1236`) y pregunta `collider is Node` y `get_parent() is HIDE` (`:1177`, `:1213`). Llamado desde `game/app/hotel_main.gd:960` y `tools/dev/office_plan_physics.gd:42`.
- `hotel_main.gd` (no leído en detalle) crea el mundo y las instancias del piso. El generador no crea ni lee nodos.

---

## 10. Clases y nodos del motor que usa esta parte

Recuento por archivo (`grep -c` sobre el texto; las cifras son aproximadas, incluyen comentarios):

| Clase o función del motor | generator | recipes | layout | validator | Para qué | Habrá que sustituir |
|---|---|---|---|---|---|---|
| Vector2 / Vector2i | muchos (cientos en total) | muchos | muchos | muchos | rejilla, puntos de muro, medidas | sí, por el tipo equivalente |
| Vector3 | 48 | 0 | 3 | 38 | puntos del manifiesto (metros) | sí |
| Rect2 | 20 | 17 | 24 | 27 | zonas de paso, huellas de muebles | sí |
| Rect2i | 0 (en `map_generator.gd`, no en esta parte) | | | | | |
| RandomNumberGenerator | 39 | 4 | 0 | 0 | todo el azar | sí; hay que reproducir su algoritmo para semillas iguales |
| Geometry2D (static) | 2 | 0 | 2 | 5 | distancias a segmentos e intersección de segmentos | sí |
| Basis | 1 (`:1958`) | 0 | 0 | 7 | giro de los módulos de pod | sí (matriz) |
| Transform3D | 0 | 0 | 0 | 6 | poses de las consultas de física | sí, solo en físico |
| PhysicsShapeQueryParameters3D | 0 | 0 | 0 | 2 | consultas de forma | sí, solo en físico |
| PhysicsRayQueryParameters3D | 0 | 0 | 0 | 1 | rayos | sí, solo en físico |
| PhysicsDirectSpaceState3D (`direct_space_state`) | 0 | 0 | 0 | 1 + 2 `intersect_shape` + 4 `cast_motion` + 2 `intersect_ray` | barridos del validador | sí |
| CapsuleShape3D / BoxShape3D | 0 | 0 | 0 | 1 / 1 | cuerpo de prueba del validador | sí |
| World3D | 0 | 0 | 0 | 1 | parámetro de `validate_physics` | sí |
| AABB | 0 | 0 | 0 | 1 (y en la paleta: `crawl_cache`, `shaft_cache`) | cajas del ducto | sí |
| Node / get_parent / is | 0 | 0 | 0 | 2 + 2 | esquivar armarios (`HIDE`) | sí |
| HIDE (`hiding_place.gd`, preload) | 0 (las cinco ocurrencias son constantes `HIDE_*`) | 0 | 0 | 2 | identificar taquillas | sí |
| RefCounted (`extends`) | 0 (hereda de `map_generator.gd`, que es RefCounted, `:1`) | 1 (`:1`, también la clase interna `Near`, `:536`) | 1 (`:1`) | 0 | base de las clases | sí |
| PackedByteArray | 0 | 0 | 0 | 2 (`reach_ok`) | rejilla de alcanzabilidad | sí |
| Callable / lambdas | ~60 `func(...)` | | | | filtros y ordenaciones | sí |
| hash() (GDScript) | 2 (`:1015`, `:3030`), más los de la base | 0 | 0 | 0 | semillas de cada tirada y de cada sistema | sí; hay que copiar el algoritmo exacto |
| snappedf, roundi, floori, ceili, clampi, smoothstep, lerpf, absi, signi | muchos | muchos | muchos | muchos | redondeo a milímetro, matemática | sí, por equivalentes |
| Color | 0 | 0 | 0 | 0 (la paleta: 2 usos, `:180`, `:464`) | colores de plano | no, solo herramienta |
| OS.get_cmdline_user_args() | 0 | 0 | 0 | 0 (la paleta: `:21`) | interruptor del edificio | sí, si se conserva |

Ninguna señal (`signal`, `emit`), ni `_process`, ni `_physics_process`, ni `await` en estos archivos (`grep`).

---

## 11. Constantes y cifras que definen el sentido de juego y de imagen

Con ruta:línea. Las de la paleta (`office_palette.gd`) están sueltas arriba; aquí van las que dan la forma.

**Generador (`office_generator.gd`):**

| Constante | Valor | Línea | Qué regula |
|---|---|---|---|
| LOOSE_P | 0.3 | 13 | Enlaces sueltos de ducto entre salas |
| CORRIDOR_EXIT_P | 0.5 | 14 | Rejillas en celdas de pasillo |
| WALL_EXIT_P | 0.15 | 15 | Rejillas de pared en vez de techo |
| TIMER_P | 0.65 | 16 | Minuteros por tramo |
| MAIN_TRIES | 64 | 17 | Caminos candidatos para el ducto principal |
| GLAZED_P | 0.55 | 18 | Cristal por muro de despacho, dirección o secretaría |
| READER_ALONG | 1.1 | 19 | Lector junto a la puerta |
| READER_Y | 1.2 | 20 | Altura del lector |
| STOP_Y | 1.3 | 21 | Altura del tope del manejador |
| CAMERA_DROP | 0.15 | 22 | Cámara bajo el techo |
| STAND_OUT | 0.6 | 23 | Pies de la mecanógrafa desde el mostrador |
| TABLE_OFFSET | 1.55 | 24 | Mesa de juntas desde el centro |
| TABLE_WALK | 0.66 | 25 | Paso libre a cada lado de la mesa |
| DESKS_MOST | 8 | 26 | Muebles libres por celda |
| SHORTCUT_MIN | 0.55 | 28 | Atajo mínimo frente al paseo |
| EXPRESS_PER | 30 | 29 | Trazos rectos por planta |
| EXPRESS_CELLS | (2, 12) | 30 | Celdas que cubre cada trazo |
| EXPRESS_MOST | 0.9 | 31 | Atajo por trazo: no más de 0.9 del paseo |
| EXPRESS_STARTS | 80 | 32 | Celdas probadas de inicio |
| NAVE_LONG | 0.6 | 33 | Probabilidad de nave de 2 x 3 frente a 2 x 2 |
| ATTEMPTS (oficinas) | 12 | 45 | Intentos antes de la reserva |
| FIRST_VIEW_SPREAD | 90.0 | 569 | Ángulo de la primera vista |
| ISLAND_STEP | 0.3 | 1985 | Paso de búsqueda de islas |
| ISLAND_PITCH | 1.5 | 1987 | Ancho de un par de mesas en una isla |
| ROW_STEP | 0.3 | 2038 | Paso de las filas de pared de la nave |
| OPEN_RUN (base) | 45.0 | `map_generator.gd:42` | Largo recto máximo de pasillo o salón antes de un cortafuegos; el generador lo usa en `runs_fit()` (`office_generator.gd:259-260`) |
| Estaciones | round(11 * sqrt(area)) +- 1, entre 8 y 14 | 1087 | Número de estaciones de tubo |
| Separación de estaciones | `STATION_APART (15) * sqrt(area)` con relajación 0.8 | 1127 | Distancia entre estaciones |
| Ducto principal, codos de planta | `MAIN_LENGTH (25, 45)`, `MAIN_IDEAL 35`, `MAIN_BENDS 2` | palette 419-421 | Longitud y codos |
| Huecos de pared (`timer_button`) | `TIMER_SPOTS` (`palette:446`) | 1421 | Puntos de minutero |
| Columnas de nave | `COLUMN 0.6`, `COLUMN_OFF 2.1`, `COLUMN_PAD 0.3`, `COLUMN_CLEAR 1.3`, `COLUMN_LAMP 0.9` | palette 280-284 | Columnas |

**Base del hotel que el piso 2 hereda** (`map_generator.gd`): `TARGET (84, 96)` (`:38`), `TRIES 6` (`:46`), `ALIKE 0.3` (`:51`), `LOOPS 4` (`:63`), `OPEN_RUN 45` (`:42`), `HIDE_SPOTS [-1.8, 0, 1.8]` (`:84`), `HIDE_CLEAR 1.75` (`:85`), `HIDE_APART 3.0` (`:88`), `OPEN_DOORS (0.8, 0.5)` (`:79`), `FIRE_OPEN 0.3` (`:80`), `WAYS` (`:69`).

**Recetas (`office_recipes.gd`):** `WALL_GAP 0.05` (`:19`); `ALONG` (`:21`); `FROM_CORNER` (`:24`); `TURN_GAP 0.5` (`:26`); `MIDDLE_DEPTHS` (`:32`); `MIDDLE_SIDES` (`:33`); `ANY_WAY` (`:36`); `TAKEN_PAST 0.1` (`:41`); `TAKEN_OUT 0.6` (`:42`); `RAISE_AWAY 0.9` (`:46`); `RAISE_REACH 1.2` (`:47`); `TABLE_WALK 0.7` (`:49`); `HALL_END 0.3` (`:53`); `HALL_SIGN_RUN 2.8` (`:54`); `HALL_BY 0.5` (`:55`); `HALL_SLOT_CLEAR 0.55` (`:58`); `LIFT_FRONT 1.2` (`:455`); `FRAME_CLEAR 0.22` (`:410`).

**Geometría de paso (`office_layout.gd`):** `CENTRE_CLEAR 0.6` (`:7`); `START_CLEAR 1.5` (`:10`); `SWEEP_CLEAR 0.45` (`:11`); `DOOR_BAND 1.5` (`:12`); `DOOR_SIDE 0.3` (`:13`); `FIXTURE_CLEAR (1.2, 1.2)` (`:14`); `LOCKER (1.3, 1.1)` (`:18`); `LOCKER_OUT 1.1` (`:21`); `LOCKER_REACH 2.2` (`:25`); `ITEM_GAP 0.9` (`:26`); `NAVE_STREET 1.2` (`:30`); `INNER_PAD 0.02` (`:31`); `EPS 0.001` (`:33`).

**Validador (`office_validator.gd`):** `SHORTCUT_MIN 0.55` (`:10`, igual que el generador `:28`); `AISLE_MIN 0.95` (`:11`); `SLACK 0.01` (`:12`); `SLEEVE 0.05` (`:13`); `NAVE_TOP 1.3` (`:867`); `WALL_NEAR 0.3` (`:869`); `REACH_STEP 0.2` (`:884`); `REACH_BODY 0.32` (`:885`); cápsula 0.32 x 1.8 (`:1091-1092`); ojos 0.94 (`:1108`); umbral 0.99 (`:1124`); suelo del falso techo 2.25 (`:1169`, `:1193`); techo 2.6 (`:1170`); pared 1.0 (`:1172`); aleja de la pared del pasillo 0.37 (`:1154`); mesa de juntas 0.93, 0.33, 0.45, 0.25 (`:1232-1233`).

**Paleta (`office_palette.gd`), las que más pesan:**

| Constante | Valor | Línea |
|---|---|---|
| VERSION | 2 | 12 |
| REAL_PLAN | false | 17 |
| BAY | 7.2 | 39 |
| REAL_ROOMS | (45, 99) | 43 |
| REAL_LEAST_WALKS | [75, 0, 0] | 44 |
| NOTCH_P | 0.35 | 104 |
| AREA | {1: 0.5, 4: 1.2, 5: 1.35} | 144 |
| ROOMS | (81, 99) | 145 |
| NUMBERED_MOST | 96 | 146 |
| WARDROBES | {4: 2, 8: 1, 14: 1, 15: 1, 21: 2} | 169 |
| HEIGHTS | 2.95 y 4.4 (ver 3.2) | 222 |
| MODULE_SIZES | [6, 6.5, 7, 7.5, 8, 9] | 241 |
| LANE_WIDTHS | [3, 3, 3.2, 3.2, 3.4, 3.6, 2.4] | 242 |
| DECKS | 3 listas de planes | 247 |
| ORDER_BASE | [0.8, 0.62, 0.55] | 253 |
| DEPTHS | (0.65, 0.9), (0.8, 0.97), (0.6, 0.9) | 256 |
| LEAST_WALKS | [90, 0, 0] | 264 |
| EXPOSED | [0, 20, 28] | 294 |
| EXPOSED_CHANCE | [0, 0.5, 0.8] | 295 |
| DARK_OWN | [0.23, 0.29, 0.36] | 306 |
| DARK_SPREAD | 0.45 | 307 |
| DARK_CORRIDOR | (0.03, 0.05) | 308 |
| WINDOW_DEPTH | (0.15, 0.45) | 403 |
| ELECTRICAL_DEPTH | (0.4, 0.7) | 404 |
| SECURITY_DEPTH | (0.25, 0.55) | 405 |
| PLENUM | ceiling 2.95, slab 4.4, duct_y 3.7, main 1.2, duct [1, 0.8], branch [0.5, 0.3] | 409 |
| TUBE_Y | 2.8 | 411 |
| STATION_Y | 1.25 | 413 |
| STATIONS | (8, 14) | 414 |
| STATION_APART | 15.0 | 416 |
| STATION_TUBE_MIN | 25.0 | 418 |
| MAIN_LENGTH / MAIN_IDEAL / MAIN_BENDS | (25, 45) / 35 / 2 | 419-421 |
| HATCH | in 1.5, stand 0.75 | 424 |
| STUB | 1.5 | 426 |
| MAIN_CLEAR | 1.2 | 429 |
| SHAFT | (2.2, 2.2) | 431 |
| AIR_UNIT | (3.0, 2.2, 1.5) | 433 |
| REMAINS | (0.55, 0.8) | 435 |
| GAP_SHARE | [0.03, 0.045, 0.06] | 437 |
| ARCHIVE_LAYOUT | shelf 2.1, row 0.6, aisle 1.0, spine 1.6, end_min 1.0, door_depth 1.5, door_band 1.0, inset 0.15, wall_gap [0, 0.9] | 441 |
| TIMER_COVER | 0.5 | 443 |
| GALLERY_SHARE | 0.15 | 448 |
| WALL_GRILLE_Y | 0.35 | 449 |
| WALL_APART | 1.5 | 451 |
| SOCKET_INSET | 1.3 | 453 |
| FURNITURE_TOP | 2.2 | 455 |
| GLAZED_TYPES | [3, 16, 17, 21, 24] | 459 |
| REAL_GLAZED | [0.9, 0.1] | 462 |
| DEPARTMENTS (tabla) | 467 | |
| FOCUS | 3.0 | 473 |
| PLANTA_MIX / HALL_MIX / SERVICE_BY_PLANTA | 475 / 480 / 481 | |
| MUSTS | [{15: 1, 5: 1}, {6: 2, 14: 1, 7: 1}, {5: 1, 16: 2, 24: 1}] | 482 |
| ROOM_BANDS | 486-505 | |
| NAVE_SIZE / NAVE_MODULE | (12, 16) / 6.5 | 506-507 |
| GLASS_CLEAR / GLASS_LOW | 0.6 / lista | 721-722 |
| OPEN_LIT | 0.6 | 724 |
| SUITE_SWAP | [TOILETS, STORE, BREAK_ROOM, EXEC_OFFICE] | 728 |
| CORRIDOR_PITCH | 2.0 | 762 |
| FIXTURE_HALF | ELECTRICAL 2.2, SECURITY 1.1, AIR_PLANT 1.7 | 772 |
| HALL_KINDS / HALL_WIDTH / HALL_DEPTH / HALL_STEP / HALL_PASS | lista / 3.0 / 0.5 / (5.0, 8.0) / 2.0 | 810-814 |
| TILE / TROFFER_PITCH / WALL_HALF | 0.6 / 3.0 / 0.09 | 1003-1006 |
| GRILLE_CLEAR / GRILLE_WALL | 0.9 / 1.0 | 1007-1008 |
| TYPOLOGIES.ring | filas, columnas, mitades (ver §7) | 30-37 |
| REAL_ZONES, REAL_MUSTS | 56-62, 63-70 | |

---

## 12. Lo que depende del orden de ejecución, de la física o del azar

- **Semillas y RNG:** toda la aleatoriedad sale de `RandomNumberGenerator` sembrado con `hash()` de un array (§5). Si el port cambia el generador de números o el `hash()`, el mismo `run_seed` dará otro piso. El manifiesto, la versión y el hash del JSON son la prueba de igualdad (`planta_real.md:184`).
- **Orden de las llamadas al rng:** cada sistema tiene su stream (`stream(...)`), así que el orden entre sistemas no cambia los números de otro. Dentro de una tirada, el orden de las llamadas sí importa: `lay_planta` (base) y `furnish_*` consumen el mismo `rng` en un orden fijo. Ver `office_generator.gd:1034` y `map_generator.gd:362-421`.
- **Reintentos:** la planta se rehace hasta `TRIES = 6` veces, y el piso hasta 12. Un cambio en un paso cambia qué intento sale, y con él todo el piso.
- **`shuffle` y `weighted`:** orden de la lista de entrada y `randi_range`/`randf` (§5.2). Un cambio de la lista cambia el resultado aunque el rng sea el mismo.
- **Ordenaciones:** `sort_custom` sin desempate: `office_generator.gd:3252`. El desempate con id en el resto (§5.3).
- **Diccionarios:** el orden de recorrido es el de inserción. Si el port usa mapas sin orden, hay que fijar el orden (§5.3).
- **Física:** solo en `validate_physics()` (§9): depende del motor de física, del orden de los cuerpos y de la capa 1 (`collision_mask = 1`, `:1095`, `:1189`). El barrido da fracción de recorrido (`[0]`, con umbral 0.99). Un motor de física distinto puede cambiar el resultado en el límite.
- **Caché estática:** `crawl_boxes()` y `shaft_box()` guardan el último manifiesto por identidad (`is_same`, `office_palette.gd:1181`, `:1208`). El juego consulta `crawling_at` por cuerpo y por fotograma (`game/floors/objectives/air_objective.gd:269`, comentario en la paleta: «asks every physics frame»).
- **Opciones de línea de órdenes:** `real_plan_on()` lee `OS.get_cmdline_user_args()` cada vez que se le pregunta (`office_palette.gd:21`). Cambia el piso sin tocar el código.
- **Interruptores estáticos de prueba:** `real_plan_test` y `columns_test` (`office_palette.gd:18`, `:287`), que las pruebas cambian en tiempo de ejecución.
- **Señales, `_process`, `_physics_process`:** no hay en estos archivos.

---

## 13. Pruebas que vigilan esta parte

- `tests/office/office_test.gd` (1381 líneas, cabecera en `:1-6`): 64 plantas del generador, dos veces cada una (`generator_checks()`, `:353`, `floor_basics`/`floor_specials`/`floor_finish`/`floor_post`/`floor_power`/`floor_air`/`floor_ducts`/`floor_archives`/`floor_rooms`/`floor_recipes`, `:451-871`); mutaciones del validador sobre la semilla 7 (`validator_checks()`, `:935`, `mutation()`, `:1192`); física de la planta 1 (`physics_checks()`, `:1285`); textos (`texts()`, `:1376`). Se parte en `office_test_generator.gd` (8 líneas), `office_test_validator.gd` (7) y `office_test_physics.gd` (8), que heredan de él.
- `tests/office/office_proportion_test.gd` (299): ocho plantas; proporción de tipos, anchura del mueble principal, camino de la mesa a la puerta.
- `tests/office/office_dressing_test.gd` (347): semilla 7; amueblado por tipo; nada sobre el techo donde está una lámpara.
- `tests/office/office_walk_test.gd` (274): partida completa de piso 2 con el generador.
- `tests/office/office_dark_test.gd`, `office_light_test.gd`, `office_lies_test.gd`, `office_pieces_test.gd`, `office_finishes_test.gd`, `office_audio_test.gd`, `office_bots_test.gd`: usan el piso generado.
- `tests/office/lurker_*` (`lurker_shell_test.gd`, `lurker_motion_test.gd`, `lurker_senses_test.gd`, `lurker_tiles_test.gd`, `lurker_bots_test.gd`, `lurker_capture_test.gd`, `lurker_fairness_test.gd`, `lurker_forced_test.gd`): usan el manifiesto y `LAYOUT`.
- `tests/office/conduit_graph_test.gd`: grafo de ductos y tubos sobre el manifiesto.
- `tests/hotel/manifest_golden_test.gd` con `tests/hotel/manifest_golden.json`: el hotel no cambia (lo genera `tools/dev/record_manifest_golden.gd`).
- `tests/hotel/creature_contract_test.gd`, `echo_test.gd`, `hotel_test.gd`, `palette_scan_test.gd`: llaman a `generate` o `candidate` (grep).
- Herramientas que miden: `tools/dev/office_metrics.gd` (mil semillas), `office_plan.gd` y `office_plan_metrics.gd` (planos), `office_plan_physics.gd` (física), `light_layers_scan.gd` (capas de luz), `tools/capture/office_*` (capturas).
- Según `planta_real.md:166-167` (sin verificar), `office_test` fija cifras de hoy en las líneas 143, 418 y 504 a 568, y `manifest_golden_test` debe pasar sin tocarse.

---

## 14. Quién usa el manifiesto y los módulos de esta parte (solo lista)

- `LAYOUT` (`office_layout.gd`) lo cargan: `game/enemies/lurker/lurker_routes.gd:16`, `game/enemies/lurker/lurker_shell.gd:13`, `game/floors/objectives/files_objective.gd:16`, `game/floors/objectives/power_objective.gd:15`, `game/world/office/office_clutter.gd:16`, `office_fittings.gd:15`, `office_geometry.gd:7`, `office_walls.gd:19`, `tools/capture/room_framing.gd:8`.
- `GENERATOR` se declara en `game/floors/office_floor.gd:14`, y lo usan `game/app/hotel_main.gd:865`, `:867`, `:899` (vía `kind.GENERATOR`).
- `VALIDATOR` se declara en `game/floors/office_floor.gd:15`, y lo usa `hotel_main.gd:960` (vía `kind.VALIDATOR`).
- `OFFICE` (la paleta) lo usan la geometría, los objetivos, la IA del Lurker y el validador (por ejemplo `game/enemies/lurker/lurker_senses.gd:288` con `troffers`, `game/app/hallucinations/lurker_hallucinations.gd:288`).

---

## 15. Discrepancias detectadas

1. **Cabecera de planta_real.md.** La línea 3 dice «Propuesta, sin construir». La sección 13 y el «Estado de la construcción» (líneas 180-200) dicen que las fases 1 a 3 están hechas. El código tiene más que la línea 3 deja entender.
2. **«Qué falta» de planta_real.md (línea 200) frente al código.** Dice que faltan: programa por zonas («los tipos aún salen de PLANTA_MIX celda a celda»), bandas por celda nueva, puertas con motivo, receta de despacho pequeño, taquillas y minuteros por muro, espina, validador y pruebas reescritos. El código ya tiene `draw_programme()` con `REAL_ZONES` (`office_generator.gd:3186`, `office_palette.gd:56`), `open_doors()` con motivos (`:3434`), `SMALL_FURNITURE` (`office_palette.gd:649`), `hide_free()` para edificio (`office_generator.gd:96-111`) y `loops()` (`:3582`). Sí falta la espina (`TYPOLOGIES` solo tiene «ring»). No he comprobado si todo eso funciona. El texto va por detrás del código, o el código está a medias.
3. **Dos lecturas del interruptor.** El generador guarda `real_plan` al crearse (`office_generator.gd:37`), mientras la paleta lo pregunta en cada uso (`office_palette.gd:94`, `:101`, `:157`, `:662`). Si el interruptor cambia entre la creación del generador y su uso, mezcla el edificio con las cifras de hoy.
4. **Criterios distintos para `least_walks`.** La validación del recorrido (`office_validator.gd:173`) usa `OFFICE.least_walks()` (depende del interruptor, `office_palette.gd:100-101`). El generador usa `building.is_empty()` (`office_generator.gd:122`). La reserva no se valida, así que hoy no choca.
5. **`LEAST_WALKS` solo tiene valor en la planta 0** (`office_palette.gd:264`). Las plantas 1 y 2 valen 0.0. No he verificado qué pasa con 0.0 en `least_walk()` (`office_generator.gd:122-123`, que sí lo usa para las otras plantas).
6. **Duplicado de constante.** `SHORTCUT_MIN = 0.55` está en el generador (`:28`) y en el validador (`office_validator.gd:10`). Cambiar uno sin el otro rompe la prueba.
7. **`in_core()` sin llamadas** (`office_generator.gd:3378`).
8. **`planta_real.md` 13.11** dice que `place_refuge` de oficinas pasa `[]` como rumbos. El código pasa la lista `bearings` que le da la base (`map_generator.gd:164` y `:390`, `office_generator.gd:170-173`), y con edificio `real_refuge()` (`:3610`) no la usa. Hoy no hay `[]`.

---

## 16. Sin comprobar

- Dentro de `map_generator.gd` (2116 líneas): solo se leyeron 1 a 450 y las firmas. No leídos: `corridors` base (573-691), `join` (902-956), `open_doors` base (841-876), `make_halls` base (1076-1105), `place_refuge` base (1420-1519), `try_refuge` (1520), `in_depth` (1611), `route_metres` (1629), `finish` base (1679), `zones` base (1787), `hang_doors` base (1843-1884), `place_hides` (1885), `light_rooms` (1931), `number_rooms` (1955), `expose` base (1120-1138), `trim` base (1311), `tidy` base (1343), `loops` base (975-1000), `alike` base (1001), `cycles` base (1066). El `WALKER` (`wall_walker.gd`) tampoco.
- `floor_definition.gd`, `conduit_metres.gd`, `map_validator.gd` (la base de `validate` y de `validate_physics`), `wall_walker.gd`: no leídos. Por eso no sé con exactitud `FLOOR.portal_between`, `FLOOR.lift_wall`, `FLOOR.LIFT_DEPTH`, `FLOOR.planta_y`, `FLOOR.doorways`, `METRES.door_metres`, ni qué comprueba la base del validador.
- `office_palette.gd`: sin leer las líneas 61-95 (cuerpo de `REAL_ROOM_BANDS` y `fits_band_now`), 104-146, 171-185, 197-221 (salvo cabecera), 254-292, 300-365, 370-485 (tablas de planes, bandas, acabados), 507-660 (fichas de muebles en detalle), 663-760, 779-1000 (acabados, cartel, suelo), 1086-1164 (rejilla de baldosas, columnas). Sin leer `office_geometry.gd` y los demás de `game/world/office/`.
- Cuerpo de `lay_planta` de la base con `drop_planta`, `count_rooms` (`map_generator.gd:1363`), `in_depth` y `count_rooms`: no comprobado en detalle.
- `hotel_main.gd`: solo las líneas que llaman al generador (865-899) y al validador (960). No he leído cómo se monta el piso ni cómo se inicia el juego.
- `docs/OFICINAS.md` sin leer: 20-660 y 736-793, 827-888, 908-1031 (salvo lo citado). `.claude/specs/fichas/planta.md` (414 líneas) sin leer; el propio planta_real.md dice que es su fuente de hechos.
- `tests/office/office_test.gd`: solo cabecera y lista de funciones. No he leído sus cifras ni sus mutaciones.
- Comportamiento real de `hash()` sobre arrays, de `RandomNumberGenerator` (algoritmo y `randi_range`), de `sort_custom` (estabilidad) y del orden de inserción de `Dictionary`: no están documentados en `.claude/godot-api/` (descripciones vacías) y no se han comprobado en el motor.
- Si las plantas de hoy pasan siempre la validación en 1000 semillas: no medido (no ejecutado).
- La cifra de 39 usos de `RandomNumberGenerator` cuenta también los del texto de comentarios; no lo he separado.
