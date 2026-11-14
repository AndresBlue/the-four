# Ficha de hechos: la planta de las oficinas (piso 2)

Solo lectura: no se ha ejecutado Godot ni tocado código, documentos ni git. Referencias en formato `ruta:línea` desde la raíz del proyecto. Decimales con punto, como en el código.

Abreviaturas: **OG** = `game/world/generation/office_generator.gd`; **MG** = `game/world/generation/map_generator.gd` (base del hotel, de la que hereda OG); **FD** = `floor_definition.gd`; **OP** = `game/floors/palettes/office_palette.gd`; **OL** = `office_layout.gd`; **OR** = `office_recipes.gd`; **OV** = `office_validator.gd`; **MV** = `map_validator.gd`.

Alcance de lectura: OG entero. OP: líneas 1-430 y el índice de constantes y funciones. MG: líneas 22-1170 y 1311-1530 y 1787-1960, más el índice. FD: 1-110 y 250-300 y el índice. MV: 1-110 y el índice. OV: 1-135, el índice y los mensajes de error. OL y OR: solo el índice de funciones y algunas funciones sueltas. `office_floor.gd` entero. `docs/OFICINAS.md` 11.3 (líneas 687-788) y `.claude/specs/spec_rediseno.md` sección 3 (líneas 59-93). No leídos en detalle: `conduit_metres.gd`, `wall_walker.gd`, `hint_placement.gd` y los demás generadores de `generation/`, los bots, los consumidores marcados como «solo grep».

---

## 0. Plantas y niveles

- Índice de planta en el código: `wing` (en la generación, `laying`), valores 0, 1, 2 (FD:26 `PLANTAS := 3`).
- wing 0 = PERSONAL, nivel 1, y = 0 m. wing 1 = REGISTRO Y ARCHIVO, nivel 2, y = -6 m. wing 2 = DIRECCIÓN, nivel 3, y = -12 m (FD:42-43 `planta_y`, `PITCH := 6.0` en FD:25; OP:250 `PLANTA_NAMES`; `office_floor.gd:55-59` `STAGES`).
- La documentación y la nota de diseño dicen «planta 1, 2, 3» (`spec_rediseno.md:68` usa «planta 1 (`laying == 0`)»). Equivale a wing + 1.

---

## 1. Algoritmo, en orden de ejecución

### 1.1 Entrada y reintentos
- `generate(run_seed, survivors := 2)` (MG:105). Lo llama el juego en `hotel_main.gd:865` con `drawn_for` o `survivors`.
- `areas = palette.areas_for(survivors)` (MG:106). Con OP:52 `AREA := {1: 0.5, 4: 1.2, 5: 1.35}` y OP:60-62: un superviviente da `[1.0, 0.5, 0.5]`; dos o tres dan `[1,1,1]`; cuatro `[1.2,1.2,1.2]`; cinco `[1.35,1.35,1.35]`.
- Intentos: `attempts()` = 12 en oficinas (OG:41; el hotel tiene 8, MG:45).
- Por intento: `candidate(run_seed, attempt)`. Se descarta si `walk < min_walk()` (MG:110; `min_walk` = `min(30, round(30 * media(areas)))`, MG:2003) o si el validador da errores (MG:113-117).
- Si ningún intento sirve: `candidate(404, 0, true)` marcado `fallback = true` y con `requested_seed` (MG:118-121). El juego también llama `candidate(404, 0, true)` directamente en `hotel_main.gd:867` y `:899`.

### 1.2 `candidate()` (MG:138-219; OG:46-51 lo envuelve con `super`)
1. `rng` = `RandomNumberGenerator` con `seed = hash([run_seed, "floor", attempt])` (MG:141).
2. `deal(rng, standby)` (MG:143, 347-353): un plan («deck») por planta, sin repetir, sorteado de `palette.DECKS[planta]`. En standby, `["blocks","blocks","blocks"]`.
3. Por planta, en orden 0, 1, 2 (MG:153-174):
   - `drawing` = área de la planta (1.0 en standby, MG:155); `laying` = planta (MG:156).
   - Hasta `TRIES = 6` intentos por planta (MG:160-166): `open_planta(f, planta, lay_grid(planta_rng, standby, anchor))` y `lay_planta(...)`. Si falla, `drop_planta` y se reintenta con otra semilla `hash([run_seed, "planta", planta, attempt, tried])` (MG:161-162). Si los seis fallan, `fail("planta")` (MG:167).
   - Se guardan `refuges`, `entries`, `hits`, `walk`, `bearings`, `plans`, y `gates` (MG:169-176).
   - La planta siguiente se traza alrededor del lobby del ascensor de esta (MG:177-180): `anchor` = span del lobby.
4. Enlace de ascensores: `gates[planta].arrive = entries[planta+1]` (MG:181); lobbies con cabina reciben `lift` (MG:184-186).
5. Origen: se desplazan `px`, `pz` de todas las celdas para que la recepción quede en (0, 0) (MG:187-193).
6. `finish(f, start, refuges, entries, decoration)` (MG:197). En oficinas, OG:538 lo reemplaza entero (ver 1.6).
7. `number_rooms(f, plaques)` (MG:201; hereda OG).
8. `hang_doors(f, gates, fittings)` (MG:205; OG:59 lo envuelve y ajusta offsets de ascensor).
9. `place_hides` (MG:206; hereda). `light_rooms` (MG:209; hereda).
10. `furnish(f, gates, doors, run_seed, attempt, standby)` (MG:212; en oficinas OG:960; el hotel devuelve `{}` en MG:224).
11. `result` (MG:217). OG:49-50 pone `floor = 2` y `version = OP.VERSION` (2). OG:977-978 vuelve a poner `floor` y `version` desde `furnish`, que se fusionan encima (MG:218 `merge(extra, true)`).

### 1.3 `lay_grid()`: la rejilla de una planta (MG:237-251)
- `side = sqrt(area)`. `fewest = max(5, round(8*side))`, `most = round(13*side)` (MG:238-240).
- `columns = randi(fewest, most)`; en standby, 10 (MG:241).
- `rows = clamp(ceil(U(100,118) * area / columns), fewest, most)`; después `rows++` hasta que `columns*rows >= ceil(100*area)` (MG:242-243).
- Carriles: `lanes_across = randi(2, min(widest, columns/3 + 1))`, con `widest = 4` si area <= 1 y 5 si no (MG:244-245). Igual para filas (MG:246). En standby, 3 y 3.
- `gaps(rng, modules, count, standby)` (MG:272-286): candidatos 1..n-1 mezclados, sin huecos contiguos (distancia >= 2). Con 12% de probabilidad, un hueco de borde (0 o n). Gap `i` = hueco antes del módulo `i`.
- `axis(rng, modules, lanes)` (MG:289-298): por cada índice, si hay hueco, un carril con ancho de `LANE_WIDTHS`; después un módulo con tamaño de `MODULE_SIZES`. Las columnas totales = módulos + carriles.
- Tamaños (OP:138-139): módulos 6.0, 6.5, 7.0, 7.5, 8.0, 9.0 m. Carriles 3.0, 3.0, 3.2, 3.2, 3.4, 3.6, 2.4 m.
- Anclaje (`pin`, MG:256-266): un módulo de cada eje queda con el tamaño del lobby y el eje se desplaza para que caiga en él. `grid.anchor` = índice de esa celda (MG:250).

### 1.4 Celdas (MG:301-320)
- `base` de la planta = número de celdas de las plantas anteriores (MG:311). `id = base + local`, `local = fila * columnas + columna` (MG:301-306).
- Campos iniciales (MG:306): `id, x, z, cols, rows, wing, kind, type = VOID (20), sector 0, props [], px, py, pz, span_x, span_z, hall -1, corridor false, service false, order 0.5`.
- `kind` (MG:305): `"cross"` si columna y fila son carril; `"lane"` si solo una; si no `"module"`.
- `py = FD.planta_y(wing) = -6*wing` (FD:42-43).

### 1.5 `lay_planta()`: una planta (MG:362-421; OG no la sobrescribe; llama a sus hooks)
a. `order_field` (MG:367, 433-442): valor 0..1 de «cuánto queda» por celda = base por planta (OP:150 `ORDER_BASE := [0.8, 0.62, 0.55]`) + gradiente + deriva por parches (`drift`, MG:448-458, hash entero).
b. `target = randi(scaled(84), scaled(96))` (MG:368), standby 96. `scaled(v) = round(v*drawing)` (MG:1998).
c. `alive` = todas las celdas `kind == "module"` (MG:370-371).
d. Forma (no standby): `pick_shape` (MG:377, 467-482) recorta una forma de `SHAPES = [rect, notch, ell, you, court, aitch]` (MG:54; `cut_shape` MG:487-516). Acepta la primera cuyo sobrante `spare - cortadas` quede entre 2 y `max(6, scaled(16))`; si no, la más cercana. `spare = alive - reserved - target`; `reserved = 1` en wing 0 y 2 en las demás (MG:374).
e. `corridors(f, plan, rng, alive, arrival, standby)` (MG:380, 573-690). Esqueleto por plan:
   - `spine` / `comb` (MG:581-605): un eje principal + 1-3 «dientes» de 3-8 celdas (spine), o dientes hasta un borde (comb).
   - `arms` (MG:606-621): un cruce y 2-4 brazos hasta el borde.
   - `twin` (MG:622-638): dos carriles paralelos unidos por 1-2 transversales.
   - `ring` (MG:639-655): anillo exterior (interior con p=0.35) y opcional radio (p=0.4).
   - `blocks` / `rot` (MG:656-678): todas las líneas, se quitan tramos (30-45%) mientras quede una sola pieza.
   - `warren` (MG:679-687): 1-2 tramos cerca de la entrada.
   - Luego `grow(f, on, alive, SERVED[plan], rng, blocked)` (MG:688; 718-743) hasta que la fracción de salas servidas llegue a `SERVED` (OP:145: spine 0.5, twin 0.55, ring 0.55, comb 0.6, blocks 0.65, arms 0.5, warren 0.0). Después `prune` (MG:689; 759-773).
f. `corridor` = conjunto de celdas-pasillo (MG:381). Si `arrival < 0`: `pick_start` (MG:382). En oficinas, OG:136-141 prefiere celdas con banda RECEPTION y puerta a pasillo.
g. `plant_service` (MG:384; 810-832): en wing 0, un bloque de 4 celdas de servicio; en el resto, pocillos de servicio por orden.
h. `open_doors` (MG:385; 841-873): fusiona pasillo con pasillo; puertas sala-pasillo con probabilidad `0.55 + 0.45*order`; puertas entre salas con `lerp(0.46, 0.05, shared) * between`, con `between = ROOM_DOORS.get(plan, 1.0)` (warren 1.8, OP:147).
i. `fire_doors` (MG:850; 877-893): si un tramo recto de pasillo supera `OPEN_RUN = 45 m` (MG:42), quita una fusión y deja una puerta cortafuegos.
j. `join` (MG:386; 902-953): conecta lo que quedó aislado a lo ya alcanzado; si no hay puerta, un carril como pasaje.
k. `make_halls(f, alive, arrival, rng, budget)` (MG:387; OG:126-133 lo sobrescribe en wing 0). Base (MG:1076-1104): `wanted = randi(scaled(4), scaled(8))` salones (OP:164 `HALLS`), de 2 o 3 celdas en línea (la de 3 solo si no supera `OPEN_RUN`) o en L. OG en wing 0: primero `make_nave` (OG:190-219) y luego el resto con el presupuesto restante.
l. `trim(f, planta, alive, arrival, {}, target+1, rng)` (MG:388; 1311-1341): quita salas de fondo de saco primero.
m. `loops` (MG:389; 975-996): añade puertas entre celdas vecinas separadas en profundidad hasta `cycles >= rings(area) + LOOPS`, con `LOOPS = 4` (MG:63) y `rings(area) = 4 si area < 1, si no 6` (OP:71-72).
n. `place_refuge(f, alive, arrival, back, rng, standby, bearings)` (MG:390; OG:148-158; base MG:1420-1516). Candidatos: celdas con fracción del camino dentro de `DEPTHS[laying]` (OP:153: wing 0 [0.65,0.9]; wing 1 [0.8,0.97]; wing 2 [0.6,0.9]). En wing 0 además metros >= `90*sqrt(area)` (OP:161 `LEAST_WALKS`). Se evitan los rumbos (`bearing`) de las plantas ya trazadas (MG:1466) y se prefieren celdas no visibles por la mano en la pared (MG:1469). Hasta 8 pruebas (MG:1479-1497) y, si fallan, islas (MG:1500-1509). OG fija `refuge_band = true` y `refuge_fits` pide la banda REFUGE (wing 0 y 1) o AIR_ROOM (wing 2) (OG:157-158).
o. `trim(..., refuge, target)` (MG:392), `tidy` (MG:393; 1343-1353).
p. `expose` (MG:394; 1120-1138): no en standby. Pasillos expuestos en wing 1 de 20 m (prob. 0.5) y en wing 2 de 28 m (prob. 0.8) (OP:191-194). Wing 0 nunca.
q. `place_specials` (MG:397; OG:253-274). Ver sección 4.3.
r. Cuenta: `count_rooms` (MG:399; 1363-1373) cuenta salas, no pasillos, y un salón una vez. Ventana `rooms_window(area) = [round(81*a), round(99*a)]` (MG:400; OP:53, 64-65). Fuera de ella: `fail("few_…")` o `fail("many_…")` (MG:401-402).
s. `cycles(f, alive) >= rings(area)` (MG:403; OG:108-121 descuenta las vueltas dentro de un salón).
t. `alike(f, planta, alive) <= ALIKE = 0.3` (MG:404; 1001-1063): solapamiento de pasillos con cada planta de arriba (en 48x48, máximo de 8 giros y espejos).
u. `in_depth(f, rooms_only, arrival, refuge.room)` (MG:407; 1611): no en standby.
v. Marca final: celdas vivas → `type = -1`, `corridor = (kind != "module")`; el resto → `VOID` (MG:408-416). La celda del lobby de la planta recibe `landing = true` (MG:418-419).
w. Devuelve `{arrival, refuge, landing, out, hits, walk, shape, count, bearing}` (MG:421).

### 1.6 `finish()` de oficinas (OG:538-643; no llama al `finish` de MG)
1. `zones(f, entries)` (OG:540; MG:1787-1811): sectores por BFS. Semillas: la entrada más 4-6 lejanas (`count = clamp(round(n/20), 5, 7)`, MG:1793).
2. Pasillos: tipo `GALLERY` (12) o `CORRIDOR` (11). Cada línea de carril es galería con probabilidad `GALLERY_SHARE = 0.15` (OP:342; OG:544-551).
3. `name_departments` (OG:716-736): un departamento por sector, según `DEPARTMENTS[wing]` (OP:358). El primero es el de la entrada. En wing 2, el sector del puesto de seguridad se llama SEGURIDAD y el del aire MANTENIMIENTO (OG:732-736).
4. Estructura fija (OG:554-572): RECEPTION (0) en `start`; LOBBY (10) en `entries` de wing 1 y 2; LANDING (9) o AIR_PLANT (23) en las celdas `landing`; REFUGE (19) en `refuges[0]` y `refuges[1]`; AIR_ROOM (22) en `refuges[2]`; WINDOW (17), ELECTRICAL (18), SECURITY (21) en sus especiales. Quedan `locked` y sin salón.
5. Salones (OG:573-591): un tipo por salón, por `HALL_MIX[wing]` (OP:371) con los focos x3 (`FOCUS = 3.0`, OP:364). ARCHIVE solo si el salón es recto y cabe en banda (OG:586). EXEC_OFFICE solo si todas sus celdas caben en banda (OG:587).
6. Resto de celdas (OG:592-606): `service` → `SERVICE_BY_PLANTA[wing]` (OP:372). Si no, `PLANTA_MIX[wing]` (OP:366) con focos, filtrado por `fitting()` (banda). BOARDROOM pasa a STORE si no cabe (OG:604).
7. `place_musts` (OG:607; 806-902), con `MUSTS` (OP:373): wing 0 `{BREAK_ROOM:1, BOARDROOM:1}`; wing 1 `{ARCHIVE:2, MAIL:1, COPY_ROOM:1}`; wing 2 `{BOARDROOM:1, EXEC_OFFICE:2, SECRETARY:1}`. Además: aseos (TOILETS) uno por sector de 5 o más salas con una puerta a pasillo (OG:875-894); en wing 1, un salón de archivo si no hay (OG:862-874); MOBILE_ARCHIVE con puertas en dos ejes pasa a ARCHIVE (OG:896-902).
8. `suites` (OG:608; 651-685): secretaría sin despacho de dirección junto a ella pasa a tener puerta con uno (intercambio de tipos con `SUITE_SWAP`, OP:595).
9. `cap_numbers` (OG:609; 922-946): salas numeradas por encima de `NUMBERED_MOST = 96` (OP:54) pasan a DEPOT (25). No se usa `keep_to_hundred` de MG.
10. Naves (OG:612-616): `room.nave_axis` = eje de la nave si la nave sigue entera y todas sus celdas son OPEN_OFFICE o CUBICLES; si no, `f.nave = {}`.
11. Por sala (OG:617-635): `height` (OP:695), `variant` (0-3), `layout = 0`, `cover_slots = 4`, y cuatro `props` de `RECIPES[type]` (OP:87) barajados con el stream `decoration`. Rotación 0 o 2 para `WALL_KINDS` (OP:211) en las esquinas 0-1 y 2-3; si no, aleatoria.
12. `open_sides` (OG:637-643): cada par fusionado abre un lado en `a` (este o sur) y el opuesto en `b`.

### 1.7 `hang_doors` (OG:59-86 sobre MG:1843-1879)
- MG: por cada arista no fusionada, `offset`, `hinge` (±1), `swing` (±1) y `open`. Lobbies con cabina: centro, cerrada, abre hacia el lobby (MG:1856-1859). Pasillo-pasillo con ancho < 6 (`LANE_WALL`): cortafuegos pegado a un muro (MG:1860-1869). Resto: `DOOR_PLACES` (OP:198) o desplazamiento `clamp(…, ±room_most)` (MG:1870-1875). `open` con `lerp(OPEN_DOORS.x 0.8, OPEN_DOORS.y 0.5, min(order))` (MG:79, 1875); fuego `FIRE_OPEN = 0.3` (MG:80, 1869).
- OG: si una sala es lobby con cabina, acota el desplazamiento (OG:69-74), y en archivos el gozne se separa del centro (OG:78-79).

### 1.8 `furnish()` (OG:960-984)
- Ensayo previo: una red de ductos desechable por planta; si algún puente falla, `{"fail": "duct_bridge"}` (OG:965-967).
- Pasos en orden (OG:973): `furnish_lobby` (2722), `furnish_archives` (2771), `furnish_mail` (988), `furnish_power` (1256), `furnish_air` (1369), `furnish_sockets` (1487), `furnish_glass` (1526), `furnish_columns` (1591), `furnish_furniture` (1690), `furnish_ducts` (2081), `furnish_main` (2579). Cualquier paso que devuelva texto corta el generador con `fail`.
- Cada sistema saca sus números de `stream(run_seed, attempt, name)` (OG:952-955: `hash([seed, "office", name, attempt])`). Nombres usados: `tubes` (991), `power` (1259), `glazed` (1529), `recipes` (1696), `halls` (1762), `open_doors` (1766), `archives` (2774), `ducts` (2084), `air` (2583, en `furnish_main`).

### 1.9 Qué es del motor del hotel y qué es de oficinas
**Heredado de MG sin tocar (la base de la forma):** `generate`, `candidate` (vía `super`), `deal`, `lay_grid`, `gaps`, `axis`, `pin`, `cell`, `open_planta`, `drop_planta`, `use`, `at`, `order_field`, `drift`, `pick_shape`, `cut_shape`, `corridors` (todos los planes), `grow`, `served`, `prune`, `plant_service`, `open_doors`, `fire_doors`, `join`, `reach`, `loops`, `alike`, `raster`, `overlap`, `cycles` (vía `super`), `expose`, `trim`, `tidy`, `remove`, `count_rooms`, `way_to`, `place_refuge` (vía `super`), `try_refuge`, `island`, `in_depth`, `route_metres`, `weighted`, `zones`, `number_rooms`, `numbers` (MG:2016, con `palette.numbered` de la paleta del generador), `place_hides`, `light_rooms`, `save`, `restore`, `link`, `merge`, `unlink`, `shuffle`, `scaled`, `min_walk`, `step`, `offset`, `pair_key`.

**Sobrescrito o ampliado por OG:**
- `_init` (OG:35), `validator` (OG:37), `attempts` (OG:41), `candidate` (OG:46, con `super`), `hang_doors` (OG:59, con `super`), `hide_free`/`hide_apart` (OG:91-98, con `super` y LAYOUT), `depth_wanted` (OG:101), `least_walk` (OG:104), `cycles` (OG:108, con `super`), `make_halls` (OG:126, en wing 0 usa la nave), `pick_start` (OG:136), `place_refuge` (OG:148, con `super`), `refuge_fits` (OG:157), `place_specials` (OG:253), `place_air` (OG:345), `try_security`, `accepts_security`, `main_path`, `walk_main`, `try_main_exit`, `facing` (OG:520, con `super`), `finish` (OG:538, **completo, sin `super`**), `furnish` (OG:960, **completo, sin `super`**).
- `MG.furnish` devuelve `{}` (MG:224-225); `MG.place_specials` devuelve `true` (MG:426-427); `MG.make_halls` y `MG.place_refuge` tienen su hook por `laying` o `refuge_band`.

---

## 2. Manifiesto: claves y quién las escribe

**Raíz (MG:216-218 + OG:49-50 + OG:977-983):**
- `version`: `OP.VERSION = 2` en oficinas (OG:50 y OG:978, que sobrescriben `FD.VERSION = 8`, FD:9).
- `floor`: `2` (OG:49, OG:977). `FD.palette(manifest)` elige la paleta por esta clave (FD:18-19).
- `seed` (MG:217), `requested_seed` (solo fallback, MG:119), `attempt`, `fallback` (bool), `area`, `areas`, `walk`, `plantas` (`[{base, width, height}]`, MG:216), `start`, `exit` (= `refuges[0]`), `refuges` (3 ids), `gates`, `wings` (3), `rooms`, `edges`, `adjacency`, `ambient_seed` (= seed + 4000037), `merged`, `doors`, `wall_hits`, `entries`, `plans` (`[{plan, shape, rooms}]`, MG:174), `start_facing`.
- De OG `furnish`: `arrival_lift` (`[wx, wy]`, OG:2742), `arrival_lift_along` (OG:2763-2764), `archives`, `mail`, `power`, `air`, `tubes`, `ducts`, `departments`, `plenum`.

**`gates`** (MG:176; OG:1477-1478): `[ {stage 1..3, room (refugio), beyond (lobby), out [x,y] (lado de la cabina), arrive (lobby de llegada, -1 en la última)} ]`. La tercera tiene `kind = "shaft"` y su `beyond` pierde la clave `lift` (OG:1477-1478).

**`rooms[i]`** (una por celda; sala = celda o salón de celdas con el mismo `hall`):
- De MG/FD: `id`, `x`, `z`, `cols`, `rows`, `wing`, `kind` (`module`/`lane`/`cross`), `type`, `sector` (MG:1812), `px`, `py`, `pz`, `span_x`, `span_z`, `hall` (-1 o id del ancla, MG:1101), `corridor`, `service`, `order`, `landing` (solo la celda de lobby de cada planta, MG:418), `lift` (solo lobbies, MG:185-186), `doors` (`[[vecino, offset]]`, MG:1877-1878), `dark`, `kept` (0-2, MG:1938), `number` (MG:1959-1990), `hides` (`[[x, z]]` en espacio de sala, MG:1913-1916).
- De OG: `open_sides` (OG:637-643), `height` (OG:622), `variant` (OG:624), `layout` (OG:621), `cover_slots` (OG:626), `nave_axis` (OG:612-615), `props` (`[{kind, slot 0-3, rotation}]`, OG:635), `feature` (OG:1700-1759), `furniture` (`[{kind, at:[x,z], turn, size:[w,d], extra:{height, group}}]`, OR:61-66), `glazed` (lista de muros, OG:1578-1581), `sockets` (`[[x,z]]` x4, OG:1493-1504), `columns` (`[{x,z}]`, OG:1611), `sector` (en `zones`).

**`doors`** (diccionario `"a:b"` con `a < b`; MG:1876): `{offset, hinge (±1), swing (±1), open (bool)}`. OG:1378-1379 añade `lock: "card"` y `open: false` a la puerta del puesto de seguridad.

**`merged`** (lista de `[a, b]` ordenada, MG:214-215): pares de celdas sin muro entre ellas, es decir, salones y sus costuras. **`edges`** (todas las conexiones, pares `[min, max]`, MG:2095 y MG:217), **`adjacency`** (vecinos por id).

**`plantas[i]`** (MG:216): `{base, width, height}` por planta. Las celdas van en orden `base + fila*width + columna`.

**`air`** (OG:1479; OG:2604-2624): `security` `{room, door ("a:b"), outside, desk{wall, along, point, yaw}, reader{…}}`; `room` (AIR_ROOM, id); `plant` (AIR_PLANT, id); `hatch` `{point, yaw, node}`; `unit` `{wall, along, point, yaw}`; `stop` `{…}`; `shaft` `{point, side:[x,z], rect:[cx, cz, sx, sz], floor_y, ladder:{point, yaw}, node}`; `remains` `{point, along}`; `main` `{nodes[], cells[], length, bends, cross, stub}`.

**`mail`** (OG:1120): `{window (id), desk {wall, along, point, yaw}, stand {point, yaw}, camera, camera_target, map, reader, stations (número)}`.

**`tubes`** (OG:1089-1119): `{nodes [[x,y,z]], rooms [id por nodo], edges [[a, b, metros, "tube"]], exits [{node, room, kind: "hub"|"station", point, yaw, number?, tube?}], hub: 0}`. `hub` es el literal 0 y no se actualiza (OG:1089).

**`power`** (OG:1333): `{room (id del cuadro), board {wall, along, point, yaw}, circuits [{code "R-n", name, sector, colour, lever, rooms[]}], lift_lever (= número de circuitos), timers [{rooms[], sector, room, wall, along, point, yaw}]}`.

**`archives`** (OG:2909): por unidad `{rooms[], axis ("x"/"z"), mobile, open [kl, kr], height, wall_gap [g0, g1], spine (rect), rows [rect], aisles [rect]}`. Los rect son `[x0, z0, x1, z1]` (OG:2912-2914).

**`ducts`** (OG:2085, 2181): `{nodes [[x, y, z, room, kind]], edges [[a, b, metros, kind]], exits [{node, room, kind, point, yaw}]}`.
- Tipos de nodo (kind): `trunk`, `branch` (OG:2199), `exit` (OG:2423), `hatch` (OG:2589), `main` (OG:2594), `shaft` (OG:2598), `stub` (OG:2377).
- Tipos de arista (kind): `trunk` (OG:2204), `branch` (OG:2226), `loose` (OG:2104), `express` (OG:2168), `bridge` (OG:2238, 2256), `drop` (OG:2424), `main` (OG:2602), `cross` (OG:2604); en los cortes de un ramal se conserva el tipo original (OG:2379-2382).
- Tipos de salida (kind): `wall` (OG:2445), `ceiling` (OG:2453), `duct` (OG:2476), `gap` (OG:2572), `hatch` (OG:2605). Las `tile` no salen en el manifiesto: `duct_graph.gd:87` las añade en el cliente.

**`departments`** (OG:979-982): `[[{sector, name, colour}]]` x3 plantas.
**`plenum`** (OG:983 = copia de OP:306): `{ceiling 2.95, slab 4.4, duct_y 3.7, main 1.2, duct [1.0, 0.8], branch [0.5, 0.3]}`.

---

## 3. La rejilla

- **Unidad mínima: la celda.** Es un rectángulo `span_x` x `span_z` en la intersección de una columna y una fila de la rejilla (MG:301-306). Las columnas y filas son módulos o carriles.
- **Sala: una celda o un salón** (varias celdas con el mismo `hall`). El ancla es la primera celda del salón (MG:1101; OG:573-591). Las celdas del salón se unen con `merge` (MG:1102) y sus muros internos no tienen puerta.
- **Forma de los salones**: MG:1076-1104 produce líneas de 2 o 3 celdas y ángulos en L (con 3 celdas). OG:165-219 (`nave_shapes`) produce bloques 2x2, 3x2 y 2x3, líneas de 5, 4 y 3 celdas y L de 5 y 4 celdas. **Por tanto una sala no es siempre un rectángulo**: los salones y las naves pueden ser L.
- **Restricción de forma por tipo**: ARCHIVE exige salón recto (`straight()`, OG:586 y OG:778-784). EXEC_OFFICE solo exige banda (OG:587). Las formas de nave de 2 celdas de ancho deben cumplir `nave_fits` (OG:207, OG:223-232).
- **Muros**: cada celda tiene cuatro muros, `west`, `east`, `north`, `south`. La cara interior está en `±span/2 ∓ WALL_HALF` (OL:89-95; `WALL_HALF = 0.09`, OP:869).
- **Lados abiertos**: `open_sides` (OG:637-643). Un lado abierto no tiene muro ni puerta.
- **Puertas**: `offset` respecto del centro del muro (FD:271-274 `door_offset`), en el eje del muro. `portal_between()` (FD:254-264) da el centro del hueco. Paso libre `PORTAL = 1.3` (FD:29). Hoja `LEAF_WIDTH = 1.2` (FD:31). Altura de puerta: **no encontrada en el código** (la nota de diseño dice 2,65 m: `spec_rediseno.md:87`).
- **Costuras entre celdas de una misma sala**: pares de `merged`; `open_sides` marca el lado (OG:638-643).
- **Anchos de pasillo**: carriles de `LANE_WIDTHS` (OP:139), de 2.4 a 3.6 m. El pasillo es una celda `kind` `lane` o `cross` con `corridor = true`.
- **Límite de recorrido recto**: `OPEN_RUN = 45 m` (MG:42; MV:8 para el validador).
- **Supuestos de «sala = rectángulo alineado a la rejilla»** que existen en el código:
  - toda celda está alineada con la rejilla de su planta (MG:301-306);
  - los salones de cada tipo tienen banda de forma: `ROOM_BANDS` (OP:377-394), con `fits_band` (OP:717-727), que fija lado corto mínimo y máximo y lado largo mínimo y máximo (0 = sin cota);
  - ARCHIVE recto (OG:586), salón de sala de juntas con banda (OG:196, 795).
- **Numeración**: `number_rooms` (MG:1955-1990). Por planta, centena `(wing+1)*100`, impares a un lado del pasillo y pares al otro. `numbers()` (MG:2016) usa `palette.numbered`, es decir la paleta de oficinas (OP:127 `NO_NUMBER`).

---

## 4. Tipos de sala y programa por planta

### 4.1 Enum `OFFICE.*` (OP:15-43)
Estructurales (mismo número en todas las paletas): RECEPTION 0, LANDING 9, LOBBY 10, CORRIDOR 11, GALLERY 12, REFUGE 19, VOID 20.
De oficinas: OPEN_OFFICE 1, CUBICLES 2, OFFICE 3, TOILETS 4, BOARDROOM 5, ARCHIVE 6, COPY_ROOM 7, STORE 8, MOBILE_ARCHIVE 13, MAIL 14, BREAK_ROOM 15, EXEC_OFFICE 16, WINDOW 17, ELECTRICAL 18, SECURITY 21, AIR_ROOM 22, AIR_PLANT 23, SECRETARY 24, DEPOT 25.
Nombres en pantalla: `NAMES` (OP:80). Los 26 tipos van de 0 a 25 (`HEIGHTS` tiene 26 entradas, OP:119).

### 4.2 Programa de cada planta (wing)
Planes posibles, `DECKS` (OP:144):
- wing 0: spine, twin, ring, comb.
- wing 1: comb, blocks, twin, spine.
- wing 2: ring, arms, warren, spine, blocks.

**wing 0, PERSONAL (nivel 1)**
- MUSTS (OP:373): BREAK_ROOM 1, BOARDROOM 1.
- PLANTA_MIX (OP:367): OFFICE 4.0, COPY_ROOM 1.0, BREAK_ROOM 0.8, TOILETS 0.6, BOARDROOM 0.6, MAIL 0.5, MOBILE_ARCHIVE 0.4, STORE 0.4 (los `{tipo: peso}` del array 0).
- HALL_MIX (OP:371): OPEN_OFFICE 3.0, CUBICLES 3.0.
- SERVICE_BY_PLANTA (OP:372): TOILETS, BREAK_ROOM, STORE, COPY_ROOM.
- Nave en esta planta (OG:126-133; 190-219).
- Especiales: ventanilla (WINDOW) y estaciones de tubo; la recepción (RECEPTION) está aquí.

**wing 1, REGISTRO Y ARCHIVO (nivel 2)**
- MUSTS: ARCHIVE 2, MAIL 1, COPY_ROOM 1 (OP:373).
- PLANTA_MIX (OP:368): ARCHIVE 2.0, OFFICE 2.0, MOBILE_ARCHIVE 1.8, MAIL 1.5, COPY_ROOM 1.5, STORE 0.6, TOILETS 0.5, BREAK_ROOM 0.4.
- HALL_MIX: ARCHIVE 4.0, CUBICLES 1.5, OPEN_OFFICE 1.0 (OP:371).
- SERVICE_BY_PLANTA: STORE, COPY_ROOM, TOILETS, STORE (OP:372).
- Especial: cuarto eléctrico (ELECTRICAL) y su cuadro, circuitos y temporizadores.

**wing 2, DIRECCIÓN (nivel 3)**
- MUSTS: BOARDROOM 1, EXEC_OFFICE 2, SECRETARY 1 (OP:373).
- PLANTA_MIX (OP:369): EXEC_OFFICE 3.5, SECRETARY 2.0, BOARDROOM 1.0, TOILETS 0.6, ARCHIVE 0.5, BREAK_ROOM 0.5, STORE 0.4.
- HALL_MIX: OPEN_OFFICE 1.5, EXEC_OFFICE 1.5, ARCHIVE 0.5 (OP:371).
- SERVICE_BY_PLANTA: STORE, TOILETS, BREAK_ROOM, STORE (OP:372).
- Especiales: puesto de seguridad, climatización, climatizadora, ducto principal y pozo.

**Número de salas por planta**: ventana `[round(81*area), round(99*area)]` (OP:53, 64-65; MG:400). Con 1 superviviente la planta 0 tiene área 1.0 y las demás 0.5.

### 4.3 Salas de hito: cómo se colocan

| Sala (tipo) | Planta | Cómo se coloca | Regla de distancia o forma |
|---|---|---|---|
| Recepción interna (0) | wing 0 | `pick_start` (OG:136-141): entre celdas con banda RECEPTION y puerta a pasillo (MG:795 si no hay). | Banda RECEPTION: lado corto >= 6.5, lado largo >= 8.0 (OP:378). |
| Ventanilla de Personal (WINDOW 17) | wing 0 | `place_specials` (OG:258-264), `candidates(…, corridor_door=true, room_type=WINDOW)`. | Camino en `WINDOW_DEPTH` 0.15-0.45 (OP:300). Peso 2 si tiene 1 o 2 puertas (OG:327). Standby: la de menos puertas (OG:335-340). Su escritorio y su cámara: `furnish_mail` (OG:988-1121). |
| Estaciones de tubo (`stations`) | wing 0 | `furnish_mail` (OG:1026-1085). | Número 8-14 (`STATIONS`, OP:311): `round(11*sqrt(area)) ± 1`. Separación mínima `STATION_APART = 15 * sqrt(area)` metros andando (OP:313; OG:1066). Tubo mínimo `STATION_TUBE_MIN = 25` m (OP:315; OG:1042). Reparto por sector (OG:1045-1049). |
| Cuarto eléctrico (ELECTRICAL 18) | wing 1 | `place_specials` (OG:266-273), `candidates(…, allow_service=true, room_type=ELECTRICAL)`. | Camino en `ELECTRICAL_DEPTH` 0.4-0.7 (OP:301). Peso x3 con 1 puerta, x1.5 si es de servicio (OG:328-332). Cuadro en la pared lejana (OG:1256-1271). Circuitos por sector en orden de palanca (OG:1273-1286). Temporizadores hasta cubrir `TIMER_COVER = 0.5` del pasillo (OP:340; OG:1308-1332). |
| Puesto de seguridad (SECURITY 21) | wing 2 | `try_security` (OG:374-413), con `accepts_security` (OG:416-434). | Camino en `SECURITY_DEPTH` 0.25-0.55 (OP:302). Hasta 8 intentos (OG:390). Peso 4 si tiene una puerta (OG:378). Sellado a una sola puerta (OG:398-405). Puerta de tarjeta cerrada (OG:1377-1379). Consola en un muro sin hueco (OG:1381-1401). Lector en la sala exterior (OG:1404-1419). Es tipo acristalable (`GLAZED_TYPES` incluye 21, OP:353). |
| Climatización (AIR_ROOM 22) | wing 2 | El refugio de la planta 2 (`refuges[2]`, OG:560), fusionado con su lobby (OG:345-349). | Banda AIR_ROOM: lado corto >= 7.0 y lado largo >= 8.0 (OP:392). |
| Climatizadora (AIR_PLANT 23) | wing 2 | El `landing` de la planta 2 (OG:557). | Unidad de aire: 3.0 x 2.2 x 1.5 m (OP:330; OG:1440-1457) en un muro sin hueco, sin tapar la escotilla ni el paso. |
| Ducto principal | wing 2 | `main_path` (OG:438-448) y `try_main_exit` (OG:469-501). | Longitud entre 25 y 45 m (`MAIN_LENGTH`, OP:316), al menos 2 codos (`MAIN_BENDS`, OP:318), puntuación según `MAIN_IDEAL = 35` m (OP:317). Standby: 15-70 m y 1 codo (OG:493-495). Ningún salón de juntas en el camino (OG:797). |
| Pozo (shaft) | wing 2 | Salida final del ducto principal (OG:1466-1476). | Es el `gates[2]` con `kind = "shaft"` (OG:1477) y pierde la cabina (OG:1478). Escalera en la pared (OG:1475). |
| Montacargas: cabina y refugio | las tres | Refugio de cada planta (`place_refuge`, MG:390) y su lobby (`landing`). | `gates` (MG:176). Banda REFUGE de wing 0 y 1: lado corto >= 6.0 y lado largo <= 7.0 (OP:393). |
| Vestíbulo de llegada (LOBBY 10) | wing 1 y 2 | `entries` de cada planta (OG:555). | Lobby de llegada del ascensor en la recepción, muro opuesto a la puerta principal (OG:722-766; ancho mínimo 7.6 m para dos posiciones). |
| Sala de juntas (BOARDROOM 5) | wing 0 y 2 | `MUSTS` (OG:607). | Banda BOARDROOM: lado corto >= 6.5 y lado largo >= 8.0 (OP:386). No en el ducto principal (OG:795-797). Mesa en el centro (OG:2037-2054). |
| Archivo (ARCHIVE 6) | wing 1 | `MUSTS` (2 salones o celdas, OP:373). Si no hay, salón recto forzado (OG:862-874). | Salón recto y banda ARCHIVE: lado corto >= 6.5 (OP:380). Filas en `lay_archive` (OG:2795). |
| Despacho de dirección (EXEC 16) | wing 2 | `MUSTS` (2, OP:373). | Banda EXEC_OFFICE: lado largo <= 8.0 (OP:384). Acristalable. |
| Secretaría (SECRETARY 24) | wing 2 | `MUSTS` (1) y `suites` (OG:651-685): junto a un despacho, con puerta entre los dos. | Acristalable. |
| Sala de descanso (BREAK_ROOM 15) | wing 0 | `MUSTS`. | Banda BREAK_ROOM: lado corto >= 7.0 y lado largo >= 8.0 (OP:387). |
| Reprografía (COPY_ROOM 7) y correo (MAIL 14) | wing 1 | `MUSTS`. | COPY_ROOM: lado corto >= 6.0 (OP:382). MAIL: lado corto >= 6.0 y lado largo >= 6.5 (OP:379). |
| Aseos (TOILETS 4) | las tres | Uno por sector con 5 o más salas y puerta a pasillo (OG:875-894). | Banda TOILETS: lado corto <= 6.5 y lado largo >= 7.0 (OP:388). |
| Depósito (DEPOT 25) | cualquiera | Desbordamiento de numeración (OG:922-946). | |

---

## 5. Validador (OV, sobre MV)

**Base MV** (`validate`, MV:22-58; luego `plantas` MV:117, `open_runs` MV:187, `lifts` MV:211, `fittings` MV:67):
- `module_count`: número de plantas y de celdas (MV:30-32).
- `same_exit`: `start != exit` (MV:33).
- `grid_N`: índice = `base + z*width + x`, `cols`, `rows` (MV:39).
- `void_N`: una celda VOID sin puertas ni `props` (MV:41).
- `cover`: 4 ranuras en celdas de módulo que no son pasillo (MV:43).
- `prop_socket`: ranuras 0-3 sin repetir (MV:46).
- `wing_leak_A_B`: ninguna arista entre plantas (MV:52).
- `connector`: vecinos a distancia Manhattan 1 (MV:53).
- `fittings`: `door_missing_N`, `door_wall_N`, `door_sides_N`, `door_hang_N`, `gate_door_N`, `fire_door_N`, `door_into_corridor_N`, `door_count`, `kept_N`, `dark_N`, `hides_N`, `hide_door_N` (MV:67-110).
- `plantas`, `open_runs` (`OPEN_RUN = 45`), `lifts`: se leen en MV:117-230 (no leídos en detalle).

**Oficinas OV** (`validate`, OV:17-20: si `floor == 2`, llama a `office(data)`). `office()` (OV:23-45) corre en este orden; `plenum_ok` corta si falla:

| Grupo (OV) | Función (línea) | Códigos de error | Qué mide, según su comentario o su cuerpo |
|---|---|---|---|
| 1 plenum | `plenum_ok` (95) | `office_floor`, `office_version`, `plenum` | Floor 2 y `version = 2`. El conducto y los ramales están por encima del falso techo más alto + 0.05 y dentro de la losa. |
| 2 tipos y alturas | `rooms_ok` (114) | `type_N`, `height_N`, `dark_N` | Tipo válido; altura = `height_of`; oscuridad solo donde puede; archivos sin `props` ni muebles; sala de juntas fuera del ducto principal. |
| 3 especiales | `specials_ok` (129) | `special_window`, `special_electrical`, `special_security`, `special_air_room`, `special_air_plant` | Un solo especial de cada tipo en su planta; `refuges[2]` es el air room. |
| 4 profundidad | `depths_ok` (161) | `depth_<regla>_N`, `depth_refuge_P`, `depth_walk_0` | Cuota del camino dentro de la banda de ventanilla, eléctrico, seguridad y refugio (con `SLACK = 0.01`). Walk de wing 0 >= `LEAST_WALKS[0]*sqrt(area) - 0.5`. |
| 5 departamentos | `departments_ok` (177) | `departments`, `departments_P` | Un departamento por sector; nombres y colores únicos; SEGURIDAD en wing 2. |
| 6 taquillas | `lockers_ok` (203) | `lockers_N` | Taquillas solo donde su tipo las tiene (`WARDROBES`), fuera de huecos y de bandas de puerta. |
| 7 archivos | `archives_ok` (220) | `archive_i`, `aisle_i` | Unidad recta; filas dentro y separadas; espina por el centro; pasillos >= `AISLE_MIN = 0.95`; puertas libres. |
| 8 correo | `mail_ok` (304) | `mail`, `mail_reader`, `station_count`, `station_numbers`, `tube_graph`, `station_apart`, `station_N`, `tube_run_A_B` | Ventanilla, lector en su sitio, 8-14 estaciones numeradas 1..n, árbol de tubos, separación, tramos. |
| 9 corriente | `power_ok` (398) | `power`, `circuit_count`, `circuit_order`, `circuit_cover`, `timer_N`, `timer_cover` | Cuadro en el cuarto eléctrico; un circuito por sector en orden R-1, R-2…; cobertura de temporizadores >= 0.5. |
| 10 aire | `air_ok` (445) | `air`, `security_doors`, `security_door`, `security_desk`, `security_reader`, `shaft`, `main_chain`, `main_length`, `main_bends`, `hatch`, `unit`, `stop`, `remains`, `main_cross`, `main_clear_N` | Puerta de tarjeta cerrada, consola, lector, escotilla, unidad, paso, pozo; longitud del ducto en [25, 45]; >= 2 codos; restos sobre la línea. |
| 11 ductos | `ducts_ok` (588) + `cross_ok` (552) + `express_ok` (649) | `duct_node_N`, `duct_off_limits_N`, `duct_edge`, `duct_edge_A_B`, `duct_express_A_B`, `duct_link_A_B`, `duct_band_A_B`, `duct_split_P`, `main_cross` | Nodos y aristas consistentes; distancias exactas (0.01); atajo en la banda 0.55 del camino; una sola pieza por planta. |
| 11b salidas | `exits_ok` (664) | `exit_off_limits_N`, `exit_N`, `exit_tile_N`, `exit_duct_N`, `exit_wall_N`, `main_clear_N`, `exit_archive_N`, `gaps_P`, `duct_room_exit_N`, `duct_corridor_N` | Salidas dentro de su sala y en placas libres; fuera del ducto principal y de filas de archivo; huecos = `round(GAP_SHARE * elegibles)` (OP:334). |
| 12 llegada | `arrival_ok` (744) | `arrival_lift` | Ascensor de llegada en un muro cerrado de la recepción sin puerta. |
| 13 esquinas | `corners_ok` (752) | `sockets_N`, `props_N` | Sockets según su regla (`SOCKET_INSET`); esquinas fuera de taquillas, accesorios y huecos. |
| 14 cristales | `glazed_ok` (795) | `glazed_N`, `glazed_window` | Cristalera en ambas caras de un muro entre tipo acristalable y pasillo; ventanilla con puerta acristalada. |
| 15 muebles | `furniture_ok` (828), `reach_ok` (886) | `furniture_N`, `reach_N` | Muebles de los tipos de su receta, fuera de zonas de paso; alcance desde el pasillo central (naves). |
| 16 naves y columnas | `columns_ok` (966) | `nave_N`, `nave_aisle_N`, `column_N` | Eje de nave; pasillo central libre; columnas bien colocadas. |
| 17 anillos | `rings_ok` (1010) | `rings_P` | `doors/2 - celdas + 1 - dentro de salones >= rings(area)`. |
| 18 vidrio | `glass_ok` (1043) | `glass_N` | Nada delante de una cristalera (comentario de OV:1040). |
| 19 pasillos | `hall_ok` (1060) | `hall_N` | Mobiliario de pasillo: solo en la banda de `HALL_WIDTH` (OV:1058). |

**Física** (`validate_physics`, OV:1084-1244, con `World3D`): `center_N` (centro de sala libre, OV:1112), `cover_access_N` (cobertura alcanzable desde el centro, OV:1125; el comentario de cabecera está en OV:1241-1242), `hide_entry_N` (barrido de entrada a escondite < 0.99, OV:1131), `archive_aisle_N` (OV:1158), `exit_way_N` (OV:1181), `ceiling_band_N` (OV:1215), `boardroom_N` (OV:1237).

---

## 6. Quién consume la forma (fuera de `generation/`, y dentro cuando se lee la forma)

Cada fila: archivo:línea, qué lee del manifiesto, y qué supone de la forma. Los marcados «solo grep» coinciden con una búsqueda de claves y no se leyeron en detalle.

**Geometría y render (`game/world/office/`, `game/world/hotel/`)**
- `game/world/office/office_geometry.gd:286` (`rooms_of = manifest.rooms`); `:317-325` (`ducts.exits` de `ceiling` y `gap` por sala); `:554` (vecinos en `manifest.rooms` para luz); `:617-624` (`merged` para aperturas); `:804` (`rooms[room_id]`); `:904` (`open_sides` y `glazed` → sin muro), `:1389` (`FLOOR.beside`), `:1696` (`furniture` footprint). **Supone**: `id` = índice; `px/pz/span`; kinds de salida; `merged` son pares.
- `game/world/office/office_walls.gd:126` (`open_sides` en `walls_of`). **Supone**: los lados abiertos no llevan muro.
- `game/world/office/office_clutter.gd:383` (`open_sides`); `:407-423` (`mail`, `tubes.exits` y `rooms` para rutas de cliente). **Supone**: las estaciones están en salas de wing 0.
- `game/world/office/main_duct_geometry.gd:33`, `:46-85`, `:70` (`air.shaft.floor_y`, `shaft.rect`, `hatch.point/yaw`, `air.main`, `rooms[air.plant].py`). **Supone**: la escotilla y el pozo tienen la forma de OG:2604-2624.
- `game/world/office/office_bounce.gd:77` (`open_sides` para el rebote de luz). **Supone**: lados abiertos iguales que en geometría.
- `game/world/office/office_pictures.gd:42` (`manifest.seed` para el plano). **Supone**: la semilla es la de la forma.
- `game/world/hotel/hotel_geometry.gd`, `room_layers.gd`, `room_dressing.gd`: leen la forma compartida con el hotel (solo grep).
- `game/world/office/office_props.gd`, `office_fittings.gd`, `pieces/*.gd`: sin lectura de forma (solo grep, `footprint`).

**Ductos, enemigo y rutas (`game/enemies/lurker/`)**
- `game/enemies/lurker/duct_graph.gd:30-88` (`ducts.nodes`, `edges`, `exits`; `edges + merged`; kind `gap`; `tile` la añade el cliente en `:87`). **Supone**: kinds de nodo y salida de OG:2199-2605; el grafo sale del manifiesto, así que es el mismo en todas las máquinas (docs 11.4).
- `game/enemies/lurker/lurker_routes.gd:113-116` (`rooms`, `merged`), `:144` (`edges`), `:165` (`air.main`), `:273-274` (`record.rooms`). **Supone**: rutas por salas, puertas abiertas y salidas de ducto; refugios nunca (docs 11.4).
- `game/enemies/lurker/lurker_shell.gd:468` (`footprint` de muebles): solo grep. `lurker.gd:200`, `:324` (seed), `lurker_voice.gd:95` (seed), `lurker_motion.gd`, `lurker_senses.gd`, `lurker_brain.gd`: solo grep sobre `rooms`, `ducts`, `seed`.
- `game/app/hallucinations/lurker_hallucinations.gd` (`rooms`, `ducts`, `lines`): solo grep. Alucinaciones.

**Plano, mapas y objetivos**
- `game/app/floor_map.gd:153` (`FLOOR.room_at(level.manifest.rooms, eye)`). Plano. **Supone**: `room_at` con la forma de la rejilla de FD:78-89.
- `game/floors/objectives/air_objective.gd:75`, `:85` (`air.main`, `air.plant`, `rooms[air.plant].py`), `:141` (`plenum.slab`), `:162` (`portal_between`). **Supone**: `air.plant` es la climatizadora; las puertas se leen con `portal_between`.
- `game/floors/objectives/power_objective.gd:57`, `:84`, `:111` (`power.room`, `timers`), `:153`. **Supone**: `power.room` es el cuadro y los temporizadores tienen `yaw` y `room`.
- `game/floors/objectives/files_objective.gd:75`, `:133`, `:545-546` (`mail.window`, `tubes`, `plan_walls`, `stations`). **Supone**: `mail.window` es una sala de wing 0; las estaciones se numeran.
- `game/floors/objectives/files_objective.gd:512` (seed de estación).

**Ascensores, cerradura y navegación del jugador**
- `game/app/lifts.gd:108-110` (`gates[index].beyond`), `:165` (`room_at`), `:438` (`room_at` → `wing`). **Supone**: `gates` por índice de planta.
- `game/app/code_lock.gd:91`, `:109-115` (último `gates` con `room` y `beyond`), `:177-182` (`refuges`, `containers[index].room`), `:187` (seed `"key"`). **Supone**: la última puerta es la de la planta 3 (`kind = "shaft"`) y los refugios son `refuges`.
- `game/app/phantom_passage.gd:77-88` (`rooms`, `adjacency[room.id]`). **Supone**: `adjacency` por id de celda.
- `game/app/interaction.gd`, `blood.gd`, `observer_gizmos.gd`, `televisions.gd`: solo grep.

**Red y huella de red**
- `game/net/match_net.gd:131` (`manifest_hash = hash(JSON.stringify(level.manifest))`); `:148`, `:158`, `:179`, `:188`, `:256` (comparación de hashes de cada invitado); `:1213` (checkpoint escrito con `GENERATOR_VERSION`, `seed`, `floor`, `mode`); `:1229-1234` (un checkpoint se acepta solo si `generator` coincide y `seed` es numérico). **Supone**: la forma sale del generador idéntica en cada máquina.
- `game/app/hotel_main.gd:731`, `:865-870` (`GENERATOR.new().generate(seed, survivors)`), `:867` y `:899` (`candidate(404, 0, true)`), `:1052` (`session.start(config.seed, …)`).
- `game/floors/office_floor.gd:14-22` (`GENERATOR`, `VALIDATOR`, `GENERATOR_VERSION = PALETTE.VERSION`).

**Dentro de `game/world/generation/` (comparten la forma con ambos pisos)**
- `hint_placement.gd`, `exit_route_signs.gd`, `document_placement.gd`, `tv_placement.gd`, `conduit_graph.gd`, `conduit_metres.gd`, `wall_walker.gd`: leen `rooms` o `adjacency` según grep. Usados por OG y MG (por ejemplo `METRES.walk_within` en OG:1044, `METRES.door_graph` en OG:2126, `WALKER.covered` en MG:1423). **No leídos en detalle.**
- `digit_placement.gd:20`, `:31` y `document_placement.gd:30` (seeds `hash([manifest.seed, …])`).

**Bots y herramientas**
- `tools/bots/bot_nav.gd`, `bot_senses.gd`, `bot_threat.gd`, `bot_threat_lurker.gd`, `bot_body.gd`, `bot_brain.gd`, `bot_match.gd`, `bot_recorder.gd`, `bot_replay.gd`, `bot_team.gd`, `bot_watchdog.gd`: solo grep (`adjacency`, `manifest.rooms`, `merged`, `open_sides`, `gates`).
- `tools/dev/office_metrics.gd`, `map_metrics.gd`, `map_plan.gd`: miden la forma (ver 7).
- `tools/capture/office_rooms_capture.gd`, `office_angles_capture.gd`, `office_capture.gd`, `lurker_office_look.gd`, `rooms_capture.gd`, `doors_capture.gd`, `lift_capture.gd`, `sheet_map_capture.gd`, `exit_signs_probe.gd`: solo grep.

---

## 7. Pruebas que fijan la forma

**Hotel (no fijan la planta de oficinas)**
- `tests/hotel/manifest_golden_test.gd` (cabecera líneas 1-7): compara los manifiestos del **hotel** con `tests/hotel/manifest_golden.json` (70 KB, 22 oct). Casos: 50 semillas (lista en `tools/dev/record_manifest_golden.gd:23`) x supervivientes 1-5 y el standby forzado (semilla 81, `record_manifest_golden.gd:27`). El grabador usa `map_generator.gd` (`record_manifest_golden.gd:16`). **Nunca toca `office_generator.gd`**, pero sí cualquier cambio en código de MG compartido con oficinas.
- `tests/hotel/creature_contract_test.gd:1531`: `OFFICE_GENERATOR.new().generate(1)`, dentro de un contrato de criatura del hotel.
- `tests/hotel/echo_test.gd:484` (`generate(81, roster_count)`).

**Oficinas (no hay golden de oficinas: se fijan invariantes, no valores)**
- `tests/office/office_test.gd` (349-381, `generator_checks`): 64 pisos: semillas 1-40 a dos supervivientes, 41-46 a 1, 3, 4 y 5 (`office_test.gd:346-348`); cada uno dos veces con instancia nueva, con igualdad de JSON (`:375-381`); las semillas del hotel 1-10 no cambian (`:350-351`, `:375`). Comprueba validez (validador), conteos y tiempo.
- `tests/office/office_test.gd:912` (`seed_seven`): `generate(7, 2)` como base. `:919` (`validator_checks`) y `:1176` (`mutation`): cada mutación de la sección 3.4 sobre una copia del piso 7 la debe nombrar el validador.
- `tests/office/office_test.gd:1210` (`nave_checks`); `:1265` (`PHYSICS_SEEDS = [7, 21, 33, 3, 12, 19, 28, 38]`) y `:1269` (`physics_checks`, con `OFFICE.columns_test = true` en `:1273`): cada piso debe pasar `validate_physics` sin errores y tener columnas (>0).
- `tests/office/office_test.gd:81` (`palette_tables`), `:149` (`palette_places`), `:182` (`palette_lattice`), `:240` (`palette_crawl`), `:262` (`kind_checks`), `:869` (`pieces_checks`). Sobre tablas y piezas, no sobre el trazado.
- `tests/office/office_proportion_test.gd:15` (`SEEDS = [7, 21, 33, 1, 2, 3, 4, 5]`) y `:222-263`: a dos supervivientes, no debe caer ningún piso (`fallen`), ninguna sala de tipo oficina de más de 7.5 m en el ducto principal de wing 2 (`strays`, `:253`), ni muebles solapados del mismo grupo (`overlaps`, `:263`).
- `tests/office/office_walk_test.gd:13` (`SEEDS = [7, 33]`): solo grep, no leído.
- `tests/office/lurker_shell_test.gd:23` (`SEEDS = 1-10`) y `:605-606` (dos `SHELL.build(generate(7, 2))` iguales).
- `tests/office/lurker_motion_test.gd:287`, `:308` (`generate(7, 2)`).
- `tests/office/lurker_capture_test.gd:15` (`[7, 2026, 11]`); `lurker_fairness_test.gd:360` y `lurker_senses_test.gd:20` (`[2026, 7, 11, 23]`); `office_audio_test.gd:13` (`[81, 7, 2026, 11]`). Solo grep.
- `tests/office/conduit_graph_test.gd`, `office_dressing_test.gd`, `office_light_test.gd`, `office_finishes_test.gd`, `office_dark_test.gd`, `office_pieces_test.gd`, `jump_test.gd`, `office_lies_test.gd`, `lurker_tiles_test.gd`, `lurker_bots_test.gd`, `lurker_observer_test.gd`, `lurker_forced_test.gd`, `lurker_fixture.gd`: solo grep (contienen `generate`, `golden` o `footprint`).
- `tests/net/net_test.gd`: partidas en red con el piso del anfitrión (`:129`, `:407`, `:457`). Solo grep en cuanto a la forma.

**Métricas (1000 semillas)**
- `tools/dev/office_metrics.gd` (cabecera líneas 1-7): `godot --headless --script tools/dev/office_metrics.gd -- 1000 [--survivors=N]`. Mide 35 medidas (`MEASURES`, línea 12): `rooms`, `numbered`, `refuge_share`, `window_share`, `electrical_share`, `security_share`, `walk_0`, `area_0`, `stations`, `tube_min`, `sectors_served`, `sectors`, `timer_cover`, `archives_1`, `aisle_min`, `aisles_per_salon`, `lockers`, `main_length`, `main_bends`, `crossings`, `duct_pieces`, `rooms_with_exit`, `ratio_min`, `ratio_band`, `loose`, `express`, `gaps`, `gaps_wanted`, `dark`, `open_items`, `boardrooms`, `boardrooms_with_table`, `glazed`, `props`, `tiles_least`. Cada una con umbral PASS/FAIL. Escribe `evidence/office_metrics.json` y sale con código 1 si falla alguna. Los umbrales no se han leído.

---

## 8. Semillas, determinismo y red

**Sorteos**
- Todo sorteo sale de un `RandomNumberGenerator` con `seed = hash([...])` sobre enteros y cadenas. En lo leído no aparece el RNG global: todos los sorteos (`randf`, `randi_range`, `randf_range`) pasan por un `rng`.
  - Base: `floor` (MG:141), `planta` (MG:162), `rooms` (MG:196), `plaques` (MG:200), `fittings` (MG:204), `wear` (MG:208), `order` (en `patch`, MG:458).
  - Oficinas: `stream(seed, attempt, name)` = `hash([seed, "office", name, attempt])` (OG:952-955), con los nombres de 1.8.
- `shuffle(list, rng)` propio (MG:2078-2083, Fisher-Yates con `rng.randi_range`); `weighted(candidates, rng)` (MG:1667-1677). No se usa `Array.shuffle`.
- Orden estable: `sort_custom` con desempate por id en casi todas las ordenaciones (ejemplos: OG:339, 383, 694, 892). `alive.keys()` se ordena antes de barajar (MG:1079-1081; OG:294, 1050).
- Redondeo a milímetro en la salida: `rounded()` = `snappedf(…, 0.001)` (OG:2646-2647; `rect_of` OG:2912-2914; `wall_spot` OG:2642-2643).

**Semilla de fallback**
- `candidate(404, 0, true)` (MG:118, `hotel_main.gd:867, :899`): standby con la rejilla fija de 10x10, carriles de posiciones fijas (MG:275), planes `blocks`, sin forma, sin expuestos, sin chequeo de `alike`. Se marca `fallback = true` y `requested_seed = run_seed` (MG:119-120).

**Precisión y plataforma**
- Las cuentas usan `sqrt`, `sin`, `cos` (MG:238, 435-437, 451-453; OG:1448). No hay control explícito de la precisión: que dos máquinas den el mismo manifiesto depende de que el motor haga la misma aritmética de coma flotante. El redondeo a milímetro de la salida limita el efecto. **No verificado** en varias plataformas.
- `hash()` de enteros y cadenas es estable entre plataformas en el motor (el propio comentario de MG:444-447 lo supone: «every machine has to generate the same floor from the same seed»).

**Red**
- `match_net.gd` (cabecera líneas 2-5): el anfitrión decide la semilla, el modo y los supervivientes; cada máquina genera el piso con esa semilla.
- Cada máquina calcula `manifest_hash = hash(JSON.stringify(level.manifest))` (`match_net.gd:131`) y lo envía al anfitrión (`:158`), que lo compara con el suyo (`:148`, `:179`, `:188`, `:256`).
- La versión del generador (`GENERATOR_VERSION`) se guarda en el checkpoint y se exige al cargarlo (`match_net.gd:1213`, `:1230`; `office_floor.gd:22`).

**Persistencia de ajustes**
- `PALETTE.VERSION = 2` (OP:12) para oficinas; `FD.VERSION = 8` (FD:9) para la base. El manifiesto final lleva `version = 2` en oficinas (OG:50, 978).

---

## 9. Hechos a tener en cuenta (sin proponer cambios)

1. **Versión del manifiesto de oficinas**: `FD.VERSION = 8` (FD:9) se sustituye por `OP.VERSION = 2` (OG:50, OG:978). Un cambio de forma en oficinas hay que contarlo con `OP.VERSION`, no con `FD.VERSION`.
2. **Documentación contra código, boardroom**: `spec_rediseno.md:68` dice que la sala de juntas nunca se lleva «la única sala de juntas posible (módulo de 10 m o más)». El código usa `fits_band(BOARDROOM, …)` (OG:196, OG:795), con la banda `[6.5, 0, 8.0, 0]` de OP:386 (lado corto >= 6.5, lado largo >= 8.0). No hay un umbral de 10 m en el código leído.
3. **`tubes.hub`** es el literal `0` (OG:1089) y no se actualiza. En la práctica el nodo 0 es la boca del hub porque los primeros puntos de cualquier tubo son los del hub (OG:1208-1209 y `tube_points`, OG:1199-1252).
4. **`finish()` de oficinas no llama a `keep_to_hundred`** (de MG:1761) sino a `cap_numbers` (OG:609, OG:922).
5. **`furnish()` de MG devuelve `{}`** (MG:224-225); el de oficinas es completo y **no llama a `super`** (OG:960).
6. **Nave**: la nota de diseño dice que la nave sirve `2 x 2 o 2 x 3`, y en L o en línea «hasta 5 módulos de 9 m o menos, por `open_runs`» (`spec_rediseno.md:68`). En el código, las L y líneas de 5, 4 y 3 celdas se prueban en ese orden (OG:165-180), y `runs_fit` mide con `OPEN_RUN = 45` (OG:236-237).
7. **`refuge_fits` y `refuge_band`** (OG:144, 148-158): la banda se pide en la primera llamada a `place_refuge` (OG:149); si no sale refugio, esa llamada se repite sin banda (OG:151-153).

---

## 10. No encontrado o no leído

- **Altura de puerta**: no encontrada en FD ni en OP (sí en la nota de diseño, `spec_rediseno.md:87`, «Puertas de 2,65»).
- **Umbrales de `office_metrics.gd`**: no leídos.
- **`conduit_metres.gd`, `wall_walker.gd`, `hint_placement.gd`, `exit_route_signs.gd`, `tv_placement.gd`, `document_placement.gd`, `digit_placement.gd`, `conduit_graph.gd`**: no leídos en detalle.
- **`office_recipes.gd` y `office_layout.gd`**: solo índice de funciones; el detalle de `keep_clear`, `lay`, `hall_heads`, `feature_of` no se leyó.
- **`office_palette.gd` líneas 430-1080**: solo el índice (las tablas de muebles, `ROOM_FURNITURE`, `CORNERS_REPLACED` en OP:558, `WALL_DRESSING`, `DOOR_MODELS`, funciones de luz y de acabado).
- **`map_generator.gd` 1130-1310, 1530-1786, 2022-2116**: no leídos (expose, blind_run, rejoin, corridor_runs, try_refuge, island, finish del hotel, keep_to_hundred, weighted).
- **`in_depth` (MG:1611), `route_metres` (MG:1629), `hidden_doors` (MG:1653)**: solo el nombre.
- **Bots, capturas, pruebas marcadas como «solo grep»** (sección 6 y 7).
- **Consumidores de `hallucinations` y `interaction`**: solo grep.
