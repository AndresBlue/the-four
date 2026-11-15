# Ficha de hechos: gen_hotel (generación del piso 1, el hotel)

Fecha de lectura: 14 de noviembre de 2026. Repositorio: `E:\Projects\The Four` (rama main). Esta ficha no cambia código ni ejecuta Godot.

Convenciones: `ruta:línea` es relativo a la raíz del repo. Las cifras de «apariciones» son conteos de la palabra con grep en el archivo, incluyen declaraciones de tipo y no son llamadas. `FLOOR.VERSION` vale 8 (`game/world/generation/floor_definition.gd:9`). Godot de referencia: 4.7.2 (`.claude/godot-api/VERSION`).

---

## 0. Alcance

- Lo pedido: los 15 archivos de `game/world/generation/` y las pruebas de `tests/hotel/` con golden o manifest en el nombre.
- Leído además porque el generador lo usa: `game/floors/palettes/hotel_palette.gd` (entero), `game/floors/hotel_floor.gd` (entero), tramos de `game/app/hotel_main.gd`, una función y grep de `game/world/hotel/hotel_geometry.gd`, y `tests/hotel/hotel_test.gd` (líneas 1 a 230).
- Fuera de alcance: los archivos del piso 2 (`office_*.gd`) y de conductos (`conduit_*.gd`). Solo se mira qué sobrescriben o de qué dependen.

## 1. Inventario de archivos leídos

### 1.1 `game/world/generation/` (15 archivos)

| Archivo | Líneas | Leído | Qué hace |
|---|---|---|---|
| `map_generator.gd` | 2116 | entero | Generador del hotel: plantas, plan de pasillos, refugio, puertas, habitaciones, números, luz. |
| `floor_definition.gd` | 321 | entero | Constantes de planta (VERSION, PITCH, PORTAL...), `palette()`, `room_at`, `route_metres`, geometría de puertas, navegación. |
| `map_validator.gd` | 316 | entero | Validador lógico (`validate`) y físico (`validate_physics`). |
| `wall_walker.gd` | 121 | entero | Recorrido con la mano en la pared (8 caminatas). Sirve para comprobar que el refugio no se encuentra así. |
| `hint_placement.gd` | 492 | entero | Ocho papeles de pistas de la última etapa. |
| `document_placement.gd` | 82 | entero | Dos documentos por piso, en mesas o en una maleta. |
| `digit_placement.gd` | 75 | entero | Los cuatro dígitos del código y los muebles donde están. |
| `tv_placement.gd` | 89 | entero | Televisores de las etapas 2 y 3. `settle()` cambia los demás televisores a mueble. |
| `exit_route_signs.gd` | 210 | entero | Carteles de salida de los pasillos. Sin azar. |
| `conduit_graph.gd` | 260 | no | Red de conductos (oficinas y el acechador). No la usa el hotel. Solo cabecera y grep. |
| `conduit_metres.gd` | 219 | no | Metros de conductos (oficinas). Solo cabecera. |
| `office_generator.gd` | 3686 | no | Piso 2. Extiende `map_generator.gd` (línea 1) y sobrescribe funciones (§3.12). |
| `office_layout.gd` | 384 | no | Piso 2. |
| `office_recipes.gd` | 840 | no | Piso 2. |
| `office_validator.gd` | 1335 | no | Piso 2. Extiende `map_validator.gd` (línea 1). |

### 1.2 Fuera de la carpeta, leídos porque el generador los usa

| Archivo | Líneas | Leído | Qué hace |
|---|---|---|---|
| `game/floors/palettes/hotel_palette.gd` | 297 | entero | Tablas de tipos de habitación, tamaños, planes, cifras de luz y puertas. |
| `game/floors/hotel_floor.gd` | 111 | entero | Reglas del piso: generador, validador, geometría, etapas, objetivos. |
| `game/app/hotel_main.gd` | 2123 | tramos 505-520, 626-640, 730-745, 822-975; grep de semillas (452, 562-566, 636-669, 1022) y de 1682 | Llamador: `build_floor()`, orden de carga, semillas de partida. |
| `game/world/hotel/hotel_geometry.gd` | 3298 | líneas 1-3, 34, 1958-1972 y grep | Constructor de escena (`extends Node3D`). `prop_transform()` (línea 1958) lo usan tres generadores de colocación. |
| `game/discovery/discovery_catalog.gd` | 52 | líneas 51-52 y grep | `for_creature()`: catálogo de documentos por criatura. |
| `tests/hotel/manifest_golden_test.gd` | 39 | entero | Prueba de la huella dorada. |
| `tools/dev/record_manifest_golden.gd` | 81 | entero | Grabador de la huella: casos, semillas y cálculo de hashes. |
| `tests/hotel/manifest_golden.json` | 2299 | estructura y análisis con Python | 255 casos grabados, versión 8. |
| `tests/hotel/hotel_test.gd` | 723 | líneas 1-230 | Pruebas de generación (300 semillas, valores fijados). |
| `tests/hotel/palette_scan_test.gd` | 302 | líneas 1-60 y 236-302 | Barrido de números sueltos y comprobación de las constantes de la paleta. |
| `.claude/godot-api/doc/classes/JSON.xml` | - | líneas 45-53 | Firma de `JSON.stringify`. |
| `docs/DEVELOPMENT.md` | - | línea 212 | Descripción de la huella dorada y de cómo se regraba. |

Solo grep (sin leer): `tests/hotel/creature_contract_test.gd` (6 referencias), `echo_test.gd`, `stages_test.gd`, `loop_test.gd`, `bots_test.gd`, `spatial_audio_test.gd`, `hotel_batch.gd`, `capture_test.gd`, `continue_test.gd`, `difficulty_test.gd`. Sin leer: `tools/dev/map_metrics.gd`, `tools/benchmarks/hotel_benchmark.gd` (usa `distance_map` en las líneas 164 y 255).

---

## 2. Qué es y quién lo llama

- `map_generator.gd` es `extends RefCounted` (línea 1). No es un nodo. Ninguno de los nueve archivos de generación del hotel tiene `class_name`.
- Entrada: `generate(run_seed: int, survivors := 2) -> Dictionary` (`map_generator.gd:105`). Salida: el manifiesto (§4).
- `candidate(run_seed, attempt, standby := false)` (`map_generator.gd:138`) dibuja un intento de piso. `generate()` lo llama hasta 8 veces; si todos fallan, dibuja el piso de reserva con `candidate(404, 0, true)` (línea 118).
- Llamadores comprobados:
  - `hotel_main.gd:865`: `kind.GENERATOR.new().generate(seed_value, drawn_for if drawn_for > 0 else survivors)`.
  - `hotel_main.gd:867` y `899`: `candidate(404, 0, true)`, el piso de reserva (forzado, o tras fallar la validación física).
  - `hotel_main.gd:723`: `survivors = slots.size()`. Con una persona, `slots` es `[1]` (líneas 562-566, 669, 745).
  - `tools/dev/record_manifest_golden.gd:49-52`, `tests/hotel/hotel_test.gd`, `tools/dev/map_metrics.gd`.
- Una instancia nueva por piso (`GENERATOR.new()` en cada llamada). Guarda estado en la instancia: `areas`, `drawing`, `laying`, `stats`, `palette` (`map_generator.gd:92-101`).
- Orden en `hotel_main.build_floor()` (`hotel_main.gd:832-943`):
  1. `generate` (865).
  2. `build_objectives()` (871).
  3. `settle_objectives` (872), que llama a `TV_PLACEMENT.settle()` (`game/floors/objectives/televisions_objective.gd:12-13`). Esto cambia el manifiesto en sitio (§5.4).
  4. `mount_geometry` (873), que hace `hotel.build(manifest)` (954).
  5. Dos `await physics_frame` (892-893), luego `validate_floor_physics()` (894; líneas 958-961).
  6. Si la validación física falla, se reconstruye el piso de reserva (897-907).
  7. Espera de navegación de hasta 90 fotogramas (921-926). Comprueba que `FLOOR.navigation_path` llega a la salida.
  8. Bounce light y calentamiento de shaders (933-941).

---

## 3. Algoritmo, paso a paso

### 3.1 Intentos (`generate`, `map_generator.gd:105-121`)

1. `areas = palette.areas_for(survivors)` (línea 106). Valores en `hotel_palette.gd:45-53`: `area_for(s) = AREA.get(clamp(s,1,5), 1.0)` con `AREA = {1: 0.5, 4: 1.2, 5: 1.35}`. Se obtiene `[1.0, a, a]` con `a = area_for(s)` si `s == 1`, o `[a, a, a]` en otro caso. Con 2 y 3 supervivientes, `a = 1.0`.
2. Hasta `ATTEMPTS = 8` intentos (líneas 45, 107): `candidate(run_seed, attempt)`.
   - Vacío (`fail` dentro): siguiente intento.
   - `walk < min_walk()`: `fail("walk")` (líneas 110-112). `min_walk()` = `min(30, round(30 * media(areas)))` (líneas 2003-2005).
   - `validator().validate(result)` con errores: `fail("invalid_" + prefijo)` por cada error (línea 117).
   - Sin errores: `result.fallback = false` y se devuelve (114-116).
3. Si los 8 fallan: `candidate(404, 0, true)`, con `fallback = true` y `requested_seed = run_seed` (118-120). Este piso no pasa por `validate()` dentro de `generate()`. Los tests sí lo validan (`hotel_test.gd:170`).

### 3.2 Un intento de piso (`candidate`, `map_generator.gd:138-219`)

1. Semilla de planes: `hash([run_seed, "floor", attempt])` (141). `deal()` (347-353) reparte un plan por planta de `palette.DECKS[planta]`, sin repetir y sin el par de `APART` (`blocks` con `rot`). En standby, los planes son fijos `["blocks","blocks","blocks"]` (348), sin sortear.
2. Para cada planta (153-177): `drawing = 1.0` si standby, o `areas[planta]` (155). Hasta `TRIES = 6` intentos (160-166):
   - Semilla propia: `hash([run_seed, "planta", planta, attempt, tried])` (162).
   - `open_planta(f, planta, lay_grid(...))` (163) y `lay_planta(...)` (164).
   - Si devuelve `{}`: `drop_planta` y otro intento (166).
   - Si los 6 fallan: `fail("planta")` (167).
3. Tras cada planta: refugio y entrada en índices globales (169-170), `walk += hops` (172), `gates` (176), y el lobby del ascensor marca el ancla de la planta siguiente (177-179): `anchor = {x: [px-span_x/2, px+span_x/2], z: [pz-span_z/2, pz+span_z/2]}` del lobby. `back = out` (180).
4. Al final: `gates[k].arrive = entries[k+1]` (181). Los lobbies reciben `lift = out` (184-186).
5. Origen: el piso se centra en la recepción. Se restan `px` y `pz` de la recepción a todas las celdas (187-193). `py` no cambia.
6. Acabado (197, `finish`). Números con semilla `hash([run_seed,"plaques",attempt])` (199-201). Puertas `hang_doors` y armarios `place_hides` con `hash([run_seed,"fittings",attempt])` (203-206). Luz `light_rooms` con `hash([run_seed,"wear",attempt])` (207-209). `furnish()` (212) devuelve `{}` en el hotel (224-225).
7. Resultado (217-219): `version, seed, area, areas, walk, attempt, plantas, start, exit, refuges, gates, wings, rooms, edges, adjacency, ambient_seed, merged, doors, wall_hits, entries, plans, start_facing`.

### 3.3 Una planta (`lay_planta`, `map_generator.gd:362-421`)

En este orden:

1. `order_field` (367; 433-442). Cada celda recibe `order` en [0,1]: `ORDER_BASE[planta] - slope * proyección_sobre_dirección_al_azar + 0.3 * drift(x/4, z/4, salt)`, con `ORDER_BASE = [0.8, 0.6, 0.42]`. `drift` es ruido de valor propio (`smoothstep`, `patch = hash([salt,"order",x,z]) % 1000 / 499.5 - 1`, líneas 448-458). `salt = rng.randi()` (438).
2. Objetivo `target` (368): en standby, 96. Si no, `randi_range(scaled(84), scaled(96))`, con `scaled(v) = roundi(v * drawing)` (1998-1999).
3. `alive` = celdas de tipo módulo (369-371). `reserved` = 1 en la planta 0, 2 en las demás (374). Son el lobby de salida y el de llegada.
4. Forma (375-379, salvo standby): `pick_shape` (467-482) prueba las formas de `SHAPES` en orden al azar. Cada una (salvo `rect`) se prueba 3 veces. Acepta el primer corte con `left = spare - cells.size()` en `[2, most]`, con `spare = alive - reserved - target` y `most = max(6, scaled(16))`. Si no hay acierto, toma el corte más cercano. Formas (`cut_shape`, 487-516): `notch` (una o dos esquinas), `ell` (esquina de 30-45 % de la rejilla), `you` (una mordida en un lado), `court` (patio interior 2-3 × 2-3), `aitch` (dos mordidas en lados opuestos).
5. Pasillos: `corridors(...)` (380-381, 573-690), según el plan (§3.4).
6. Entrada si es `-1`: `pick_start` (382, 795-805). Elige al azar entre las habitaciones con pasillo en la puerta, o entre todas.
7. Servicio (384, `plant_service`, 810-832). En la planta 0, un bloque de 2×2 módulos con mayor suma de `order` pasa a servicio. Después, cada módulo (salvo la entrada) pasa a servicio con probabilidad `lerp(0, 0.14, 1 - order)`.
8. Puertas (385, `open_doors`, 841-873):
   - Pasillo con pasillo: fusión (sin pared) siempre (847-849).
   - `fire_doors` (877-894): si una línea recta de pasillo abierta supera `OPEN_RUN = 45` m, se quita la fusión en el tramo que la rebasa. Esa pareja pasa a tener puerta con pared.
   - Módulo con pasillo (851-863): la primera puerta siempre en standby, en la entrada, o con probabilidad `0.55 + 0.45 * order`. Las demás con `lerp(0.3, 0.03, order)`. La entrada no abre hacia `back` (856).
   - Módulo con módulo (864-873): probabilidad `lerp(0.46, 0.05, min(order))` multiplicada por `between` (1.8 en `warren`, 1.25 en `rot`, 1.0 en el resto; `palette.ROOM_DOORS`). Entre dos de servicio (`service`) siempre (872-873).
9. Conexión `join` (386, 902-953): se busca lo que no se alcanza desde la entrada. Se une a lo ya alcanzado por una puerta. Si no hay, se abre un paso por un carril libre entre dos habitaciones (929-936). Lo que sigue sin alcanzarse se borra (941-943).
10. Salones `make_halls` (387, 1076-1104), salvo standby. Entre 2 y 6 salones, escalados. Un salón es de 2 o 3 módulos unidos (sin pared). Nunca la entrada ni servicio. La línea de tres no puede ser más larga que 45 m. El presupuesto son las habitaciones de sobra.
11. `trim` a `target + 1` (388, 1311-1340). Primero quita habitaciones sin salida (una sola puerta, no protegida). Sin refugio todavía, también quita del borde si el resto sigue alcanzable.
12. `loops` (389, 975-996): añade puertas entre celdas vecinas separadas en profundidad hasta tener `rings(drawing) + LOOPS` ciclos. `rings = 4` si area < 1, si no 6 (`hotel_palette.gd:64-65`). `LOOPS = 4`.
13. Refugio `place_refuge` (390, 1420-1516). Ver §3.5.
14. `trim` a `target` con refugio (392): solo quita habitaciones que no llevan a nada, nunca el camino a la salida.
15. `tidy` (393, 1343-1353): quita tramos de pasillo sin habitación en la puerta.
16. `expose` (394, salvo standby). Ver §3.6.
17. `place_specials` (397): en el hotel devuelve `true` (426-427).
18. Comprobaciones (399-407). Cada una hace `fail` con su motivo y repite la planta:
   - Número de habitaciones entre `rooms_window(drawing)` = (round(81·d), round(99·d)) (`hotel_palette.gd:55-56`). Motivos `few_` y `many_`.
   - Ciclos ≥ `rings(drawing)` (`cycles_`).
   - Parecido de pasillos con la planta de arriba ≤ `ALIKE = 0.3` (404; motivo `alike_`). Fuera de standby.
   - Profundidad del refugio (`in_depth`, 407; motivo `depth_`).
19. Tipos provisionales (408-418): las celdas vivas pasan a `type = -1`. Las vacías, a `VOID` (20). `landing = true` en el lobby (418).
20. `walk = maxi(0, hops[refugio])` (421). Es un conteo de puertas (BFS), no metros.

### 3.4 Planes de pasillo (`corridors`, `map_generator.gd:573-690`)

Cada plan dibuja un esqueleto de líneas de la rejilla. Después crecen los pasillos (`grow`) y se podan (`prune`).

- `spine` (581-596): una línea principal, en el eje elegido al azar. Entre 1 y 3 «dientes» de 3 a 8 celdas.
- `comb` (581-605): los dientes van hacia un borde, por el lado de la mitad mayor (80 %). A veces, con probabilidad 50 % (línea 605), una calle de cierre une sus extremos.
- `arms` (606-621): un cruce de una línea vertical y otra horizontal, con brazos en 2 a 4 de las 4 direcciones.
- `twin` (622-638): dos líneas paralelas (la primera y la última, o casi) unidas por 1 o 2 puentes.
- `ring` (639-655): anillo con las líneas exteriores (o una interior, con 35 %). A veces un radio (40 %).
- `blocks` y `rot` (656-678): todas las líneas, luego se quita entre 30 y 45 % de los tramos sin partir los pasillos. `rot` añade un parche circular de radio 25-45 m donde no hay pasillo (`blocked`).
- `warren` (679-687): 1 o 2 tramos cerca de la entrada. Casi nada de pasillo.
- Si hay pocas líneas, todas (608, 627, 641).
- Crecimiento (688, salvo standby): `grow` (718-743) alarga pasillos hacia habitaciones no servidas hasta `SERVED[plan]` (`hotel_palette.gd:135`). Ganancia por tramo: `0.5 + order` por habitación nueva, más ruido de `0.75`.
- Poda (689; `prune`, 759-773): quita celdas de pasillo que no tienen habitación al lado y no siguen en dos sentidos.

### 3.5 Refugio (`place_refuge`, `map_generator.gd:1420-1516`, y `try_refuge` 1520-1560, `island` 1568-1592)

- Metros desde la entrada a cada celda (`route_metres`, 1629-1649). Celdas caminadas por la mano en la pared (`WALKER.covered`, `wall_walker.gd:89-98`).
- `far_side`: el percentil (1 − 0.3) de las distancias en línea recta de los módulos (1431-1435).
- Candidatos (1439-1460):
  - Módulo, no entrada, sin sala ni servicio, con metros conocidos.
  - Cuota de profundidad `share = metros/máximo` entre `DEPTH = (0.55, 0.9)`, o `FIRST_DEPTH = (0.65, 0.9)` en la planta 0 (`hotel_palette.gd:144,149`).
  - En la planta 0, metros ≥ `FIRST_WALK * sqrt(d)` = 150·√d (`hotel_palette.gd:150`, 1446).
  - Un lobby vecino (`landing`) en cada dirección (`way`).
  - Peso: ×2 si no está junto a un pasillo; ×1.5 si no está en el borde; ×0.3 si lo recorre la mano en la pared; ×6 si tiene puertas hacia celdas que la mano no mira.
  - `plain` = está lejos en línea recta (`far_side`) o el camino es menos de 1.5 veces la línea recta (`WINDING`).
- Filtros: evitar el rumbo (`bearing`, 8 sectores) de otra planta, y si quedan, preferir las no `plain`.
- Hasta 8 sorteos ponderados (1479-1497). Cada uno prueba `try_refuge`: se sella el lobby, el refugio conserva una puerta (las no recorridas primero), se rehace la unión y se cuentan las manos en la pared (`WALKER.score`). Acepta si `hits == 0` y `fits` (profundidad).
- Si nada: `island` (1499-1508) con los 16 mejores pesos. El refugio queda en un anillo de 10 celdas con una sola puerta hacia dentro.
- Si nada de eso: `{}` en planta no standby (planta redibujada). En standby, se toma el mejor intento.

### 3.6 Salidas expuestas (`expose`, `map_generator.gd:1120-1133`, `blind_run` 1139-1195, `keeps_promises` 1223-1233)

- Solo en la planta 1 (segunda) y la 2 (tercera). `EXPOSED = [0, 30, 50]` (`hotel_palette.gd:167`), con probabilidad `EXPOSED_CHANCE = [0, 0.5, 1.0]` (168). La planta 2 pide además un segundo tramo de 35 m (`SECOND_EXPOSED`, 169, línea 1124). Metros escalados por √d.
- Un tramo es un pasillo recto o una L de dos piernas (`corridor_runs`, 1238-1271), entre `least` y `most = EXPOSED_LONGEST * √d = 90·√d` (170).
- Cada candidato debe: tener salida en los dos extremos (`way_out`); cerrar las puertas de sus habitaciones; abrir una puerta a una habitación vecina a la de cada habitación que se quede sin otra salida; no tocar la entrada, el refugio ni su lobby.
- Ranking: `-|longitud − 1.25·least| − 2·abiertas + rand·6` (1178). Se prueban los 14 mejores (`EXPOSED_TRIES`, 68).
- Lo que se valida en `keeps_promises`: todo alcanzable (1225); ciclos ≥ `rings` (1226); rodeo ≥ `DETOUR = 1.5` veces la longitud (1229-1230); profundidad del refugio (1231); ninguna mano en la pared lo encuentra (1232).

### 3.7 Acabado (`finish`, `map_generator.gd:1679-1753`)

1. Galerías (1681-1684): cada línea de pasillo es galería con probabilidad 0.22.
2. Tipos (1685-1696), con `decoration` (tipos del `palette`):
   - Pasillo: `GALLERY` (12) si su línea es galería, si no `CORRIDOR` (11).
   - Servicio: `SERVICE_ROOMS` = [7, 8, 9, 15].
   - Resto: `TIDY_ROOMS` con probabilidad `order`; si no, `UNRULY_ROOMS`.
   - Salón (`hall`): `HALL_ROOMS[hall % 4]` = [5, 6, 17, 18].
   - Lobby de acceso al refugio (`landing`): `LANDING` (9).
3. Recepción (1697) = `RECEPTION` (0). Lobbies de llegada de las plantas 1 y 2 (1700) = `LOBBY` (10). Refugios (1701-1704) = `REFUGE` (19), sin servicio ni salón.
4. `keep_to_hundred` (1705, 1761-1782): si una planta tiene más de `NUMBERED_MOST = 96` habitaciones con número, las de menor `order` (con −0.3 si están junto a servicio) pasan a servicio.
5. Televisores (1707-1721): en las plantas 1 y 2 (índices), se elige al azar entre las salas sin `tv` hasta `tv_rooms(area)` (6 si area < 1, si no 8). Pasan a `TV_ROOM` (14). `RECIPES` con `tv` son los tipos 3 (suite) y 14.
6. Muebles (1722-1744): por cada celda no void y no corredor, 4 piezas de `RECIPES[tipo]` (línea 80-102), barajadas. Giro al azar 0-3, salvo `WALL_KINDS` (0 en las dos primeras esquinas, 2 en las otras) y `wardrobe`/`curtain` (1 o 3 por paridad). `variant` y `layout` al azar 0-3. `height = height_of(room)`.
7. `open_sides` (1746-1752): las fusiones marcan lado abierto en las dos habitaciones.
8. Zonas (1787-1812): entre 5 y 7 por planta (`clamp(round(n/20), 5, 7)`), sembradas en las habitaciones más lejanas entre sí. Cada habitación toma la zona más cercana (`sector`).

### 3.8 Puertas, armarios, luz, números

- `hang_doors` (1843-1879): una puerta por cada arista que no es fusión. `offset` (desplazamiento en la pared, en metros), `hinge` (±1), `swing` (±1), `open` (bool).
  - Puerta de refugio: en el centro, cerrada, abre hacia el lobby (1856-1859).
  - Pasillo con pasillo y pared < 6 m (`LANE_WALL`): puerta de incendios, lado al azar, `open` con probabilidad `FIRE_OPEN = 0.3`.
  - Resto: `DOOR_PLACES` (0, 0, ±1.5, ±2) o `DOOR_PLACES_DOMESTIC` (0, ±1.5) si hay alcoba. Abre con probabilidad `lerp(0.8, 0.5, min(order))`.
- `place_hides` (1885-1916): armarios según `palette.WARDROBES` (líneas 69): 2 en dormitorios y guardarropa, 1 en salas privadas. En las puntas `HIDE_SPOTS = [-1.8, 0, 1.8]`, sin pisar una puerta (`HIDE_CLEAR = 1.75`). Dos armarios en paredes opuestas si se puede; si no, separados `HIDE_APART = 3.0`.
- `light_rooms` (1931-1948): primero `kept` por habitación: `order + randf_range(−0.25, 0.25)`; `kept = 0` si > 0.55, `1` si > 0.25, `2` si no. Luego las salas oscuras: probabilidad `DARK_CORRIDOR.x = 0.03` en pasillos o `DARK_OWN[planta]` = (0.23, 0.29, 0.36) en el resto, solo si `may_be_dark`. Se propaga a vecinos con `DARK_CORRIDOR.y = 0.05` o `DARK_SPREAD = 0.45`.
- `number_rooms` (1955-1995): por planta, centenas `(planta + 1) * 100`. Tres sorteos (`down`, `backwards`, `odd_first`). Las habitaciones se recorren en orden de barrido. Impares a un lado del pasillo y pares al otro. `take_number` (1991-1995) cae al otro lado si una serie pasa de 99.

---

## 4. Modelo de datos de salida

### 4.1 Manifiesto (Dictionary)

- `version` (= 8), `seed` (semilla de partida; en el piso de reserva es 404), `requested_seed` (solo en reserva), `fallback` (bool).
- `area` (media de `areas`), `areas` (`[a0, a1, a2]`, la escala de cada planta).
- `walk` (suma de puertas de entrada a refugio en las tres plantas), `attempt`.
- `plantas`: `[{base, width, height}]` por planta. `width` y `height` cuentan módulos más carriles.
- `start` (recepción, id global), `entries` (entrada de cada planta), `refuges` (refugio de cada planta), `exit` (= `refuges[0]`).
- `gates`: `[{stage (1-based), room (refugio), beyond (lobby), out ([x,y], lado de la cabina), arrive (lobby de abajo; -1 en la última)}]`.
- `wings` (= 3), `rooms`, `edges` (`[[a, b], ...]` con `a < b`, en el orden de creación), `adjacency` (lista por id de vecinos, en orden de creación), `merged` (`[[a,b], ...]` fusiones ordenadas), `doors` (diccionario `"a:b"` → `{offset, hinge, swing, open}`), `wall_hits` (conteo de manos en la pared por planta; 0 en un piso normal), `plans` (`[{plan, shape, rooms}]`), `start_facing` (yaw de la recepción), `ambient_seed = run_seed + 4000037` (217).

### 4.2 Habitación (una entrada de `rooms`)

Creada en `cell()` (`map_generator.gd:306`): `id, x, z, cols, rows, wing, kind ("module"|"lane"|"cross"), type, sector, props, px, py, pz, span_x, span_z, hall, corridor, service, order`.

Añadidas después: `landing` (solo el lobby), `lift` (lista `[x,y]` en lobbies), `doors` (`[[vecino, offset], ...]`), `open_sides`, `dark` (bool), `kept` (0, 1, 2), `number` (0 si no tiene), `hides` (`[[x,z], ...]` en espacio de la habitación), `height`, `variant` (0-3), `layout` (0-3), `cover_slots` (4 si no es pasillo), `props` (`[{kind, slot (0-3), rotation (0-3)}]`).

Tipos (`TYPES` en `hotel_palette.gd:72`, nombres en 73): 0 recepción, 1 habitación doble, 2 habitación simple, 3 suite, 4 baño, 5 salón, 6 comedor, 7 lavandería, 8 almacén, 9 mantenimiento, 10 vestíbulo, 11 pasillo, 12 galería, 13 sala de lectura, 14 sala de televisión, 15 oficina, 16 guardarropa, 17 jardín interior, 18 salón vacío, 19 refugio, 20 vacío. El tipo 9 es también `LANDING` (`hotel_palette.gd:14`), el lobby del ascensor, y se distingue por la marca `landing` (ver §13, punto 13).

Un salón (`hall >= 0`) es varias celdas con el mismo `hall` (id de la primera).

### 4.3 Rejilla y tamaño de celda, en metros

- No hay tamaño de celda fijo en el hotel. Cada celda tiene `span_x` y `span_z` (`cell()`, línea 306).
- Módulo: el lado se sortea de `MODULE_SIZES = [12, 12, 13, 13, 14, 15, 16]` (`hotel_palette.gd:126`). Por columna y por fila por separado (`axis()`, 292-293).
- Carril (pasillo): `LANE_WIDTHS = [3.0, 3.5, 3.5, 4.0]` (`hotel_palette.gd:127`).
- Lobby del ascensor: su lado se fuerza al del lobby de la planta de encima (`pin()`, 256-266). Las plantas quedan alineadas en `xz`, y el validador lo comprueba (`map_validator.gd:220-222`).
- Altura de planta: `PITCH = 6.0` m (`floor_definition.gd:25`). `py = -6 * planta` (`planta_y`, 42-43).
- Planta de un punto: `floor((5 − y) / 6)`, acotada a 0-2 (`planta_of`, 47-48). Son 1 m por debajo del suelo y hasta el aire bajo la losa.
- Puerta: hueco libre `PORTAL = 1.3` m (`floor_definition.gd:29`). Hoja `LEAF_WIDTH = 1.2` m (31). Cabina del ascensor `LIFT_DEPTH = 2.34` m (67).
- `CELL = 12.0` (27) solo sirve de respaldo en `position_of` y `size_of` si faltan `px`, `span_x` (40, 62). Con `cell()` siempre están, así que no se usa en el hotel.
- Altura de sala: `HEIGHTS` (`hotel_palette.gd:108`): 3.15 por defecto, 4.2 en varias, `HALL_HEIGHT = 4.8` en salones.
- Ancho de cuadrícula de medición de parecido: `LIKENESS_CELLS = 48` (`map_generator.gd:52`). No es una celda de juego.

### 4.4 Diagrama de la planta

- La planta es una cuadrícula de `width × height` celdas en orden de fila (`id = base + z·width + x`). Los vecinos están a 1 (mismo fila) o a `width` (otra fila). Las celdas no usadas son `VOID`.
- Ids globales: la planta 0 empieza en 0. Cada planta sigue a la anterior (`base = f.rooms.size()`, línea 311).

---

## 5. Semilla y azar

### 5.1 Qué semilla entra

- `run_seed` entra en `generate`. En partida nueva, `hotel_main.gd:562, 564, 566` usa `randi_range(0, 2147483647)` (reintento, bajar de piso, comenzar piso 2). `hotel_main.gd:452` igual, para el observador. `hotel_main.gd:1022` toma `config.seed` de la red.
- `intro_seed` (`hotel_main.gd:636`, 669) pasa a `start_floor`. Su origen no se ha seguido (§14).

### 5.2 Generadores derivados (todos `RandomNumberGenerator` con `seed = hash([...])`)

| Uso | Semilla | Línea |
|---|---|---|
| Planes | `hash([run_seed, "floor", attempt])` | 141 |
| Planta (cada intento) | `hash([run_seed, "planta", planta, attempt, tried])` | 162 |
| Deriva del orden (`salt`) | `rng.randi()` del generador de la planta | 438 |
| Decoración de habitaciones (tipos, muebles, pasillos con galería) | `hash([run_seed, "rooms", attempt])` | 196 |
| Números | `hash([run_seed, "plaques", attempt])` | 200 |
| Puertas y armarios | `hash([run_seed, "fittings", attempt])` | 204 |
| Luz y desgaste | `hash([run_seed, "wear", attempt])` | 208 |
| Código (dígitos) | `hash([manifest.seed, "code"])` | `digit_placement.gd:20` |
| Dígitos en muebles | `hash([manifest.seed, "digits", stage])` | `digit_placement.gd:31` |
| Documentos | `hash([manifest.seed, "documents"])` | `document_placement.gd:30` |
| Pistas | `hash([manifest.seed, "hints", stage])` | `hint_placement.gd:58` |
| Número del parte de limpieza | `1000 + absi(hash([manifest.seed, "limpieza"])) % 9000` | `hint_placement.gd:190` |
| Televisores | `hash([manifest.seed, "televisions", survivors, stage])` | `tv_placement.gd:51` |

- `exit_route_signs.gd` no usa azar: los carteles salen solo del manifiesto (línea 25 lo dice).
- `wall_walker.gd` y `map_validator.gd` no usan azar.
- No se usan `randi()`, `randf()` ni `randomize()` globales en la generación. Todo pasa por instancias de `RandomNumberGenerator` (comprobado con grep).

### 5.3 Piso de reserva

- `candidate(404, 0, true)` fija `manifest.seed = 404` (línea 217). Por eso el código, los documentos y las pistas de cualquier piso de reserva son los mismos para cualquier semilla pedida. Solo cambian los televisores (dependen de `survivors`).
- Confirmado en la huella: los 5 casos `standby` tienen el mismo hash de manifiesto y 5 hashes distintos de televisores (§7).

### 5.4 Mutación del manifiesto

- `TV_PLACEMENT.settle(manifest, survivors, kind)` (`tv_placement.gd:35-45`) cambia `prop.kind` de `"tv"` a `"tv_stand"` en las habitaciones de televisores no elegidos. Lo hace en sitio y antes de montar la geometría.
- En la huella, el hash del manifiesto se calcula antes de `settle` (`record_manifest_golden.gd:53-54`). Así se compara el manifiesto generado, no el mutado.

---

## 6. Qué garantiza el validador

`validate(data)` (`map_validator.gd:22-58`) devuelve una lista de errores. Se cumple lo siguiente cuando la lista está vacía:

1. Número de plantas y celdas coherente (`module_count`, 30-32). Inicio distinto de salida (`same_exit`, 33).
2. Cada habitación en su sitio de la rejilla; `id` = índice; `cols`/`rows` correctos (`grid_`, 39). Las celdas `VOID` no tienen puertas ni props (`void_`, 41). Las habitaciones no pasillo tienen 4 huecos de mueble (`cover`, 43). Los props tienen huecos 0-3, sin repetir (`prop_socket`, 46).
3. Ninguna arista une dos plantas (`wing_leak_`, 52). Las uniones son ortogonales (`connector`, 53).
4. `plantas()` (117-183): cada planta alcanzable desde su entrada (`planta_split`); entrada válida (`entry_`); habitaciones contadas entre la ventana de la planta (`rooms_`, 173); números dentro de su centena y sin repetir (`number_`); ≤ 96 numerados (`numbered_`, 174); ciclos ≥ `rings(area)` (`cycles_`, 175); refugio alcanzable (`refuge_unreachable_`) con una sola puerta aparte del lobby (`refuge_doors_`, 180); lobby con una sola puerta, hacia el refugio, marcado `landing` (`lobby_`, 181); en plantas 1 y 2, al menos `tv_rooms(area)` televisores (`few_televisions_`, 182).
5. `open_runs()` (187-207): ninguna recta abierta de más de `OPEN_RUN = 45` m (+0.01) (`open_run_`).
6. `lifts()` (211-227): el lobby de abajo está justo debajo (`lift_`, 220); mismo tamaño (`lift_size_`, 222); entrada coincide (`lift_entry_`, 223); nada abre hacia la pared donde está la cabina (`lift_back_`, 226).
7. `fittings()` (67-111): cada arista sin fusión tiene su puerta (`door_missing_`, 81); la puerta cabe en la pared (`door_wall_`, 88); la puerta vista desde ambos lados (`door_sides_`, 89); bisagra y giro ±1 (`door_hang_`, 90); puertas de refugio y de incendio con sus reglas (93-95); ninguna puerta hacia un pasillo desde una sala (`door_into_corridor_`, 96); `kept` en 0-2 (100); oscuridad solo donde se permite (101); armarios dentro del número de la sala y lejos de puertas (`hides_`, `hide_door_`, 103-110).

`validate_physics(world, data)` (`map_validator.gd:231-303`). Necesita un mundo de física con geometría cargada. Lo llama `hotel_main.gd:960`:

- Cápsula de radio 0.32 m y altura 1.8 m (234-236), máscara de colisión 1 (239). Centro a 0.94 m (242).
- Cada habitación: el centro libre (`center_`, 245).
- Habitaciones no pasillo: desde el centro a las cuatro esquinas (±2.2 m, `room_sweeps`, 308) con recorrido libre hasta 0.99 (`cover_access_`, 251).
- Alcobas de habitaciones domésticas: entrada a ±4.4 m con recorrido de 3.0 m a cada lado (`alcove_entrance_`, 252-257).
- Armarios: el acceso y la entrada en su sitio (`hide_approach_`, `hide_entry_`, 259-266).
- Cada puerta: el paso por el hueco (`passage_`, 281-287) y la hoja abriéndose en cuatro ángulos (0.6, 0.9, 1.2, 1.48 rad) sin chocar con máscara 1 u 8 (`leaf_arc_`, 297-302). Hoja de caja 1.2 − 0.3 m × 2.3 m × 0.05 m (269-270).

Lo que `generate()` no comprueba y se hace en la búsqueda: el número mínimo de pasos (`walk`, 110), la profundidad del refugio (`in_depth`), que ninguna mano en la pared lo encuentre (`WALKER.score`, en `place_refuge`). Estas condiciones se fijan en los intentos y no en el validador.

---

## 7. Manifiesto dorado

### 7.1 Qué es

- `tests/hotel/manifest_golden.json`: `{version: 8, cases: [...]}`. 255 casos.
- Casos: 5 cifras de supervivientes × (50 semillas + 1 caso de reserva) = 255 (`record_manifest_golden.gd:30-35`).
- Cada caso: `key` (`"S/n"` o `"standby S/n"`), `seed`, `survivors`, `fallback`, `fell_back`, `manifest` (SHA-256 de `JSON.stringify(manifest, "", true, true)`), `televisions` (SHA-256 de `JSON.stringify(settle(...), "", true, true)`).
- `JSON.stringify(data, indent, sort_keys, full_precision)`: `sort_keys` vale true por defecto y `full_precision` false (`JSON.xml:45-53`). La huella usa `true` en ambos parámetros de orden y decimales (`record_manifest_golden.gd:53, 55`).
- Semillas (`record_manifest_golden.gd:23`): 81, 202, 213, 777, 4242, 9001 y otras 44 (cincuenta en total). Incluye la 404 como semilla normal.

### 7.2 Lo que he comprobado en el JSON (sin correr Godot)

- Cada supervivencia tiene 50 manifiestos distintos (y 50 hashes de televisores distintos).
- Supervivientes 2 y 3 dan el mismo manifiesto (81/2 = 81/3 y 202/2 = 202/3). Solo cambian los televisores. Es lo que dice `DEVELOPMENT.md:212` y lo que causa `areas_for`.
- Los 5 casos de reserva tienen el mismo manifiesto (`7475a325…`) y 5 hashes de televisores distintos.

### 7.3 Qué fija y qué no

- Fija cada byte del manifiesto de las 255 combinaciones y los sets que elige `TV_PLACEMENT.settle()`.
- No fija: el código de la prueba, el número de versión de Godot, ni el resultado en otra máquina (la huella se grabó aquí). Las ejecuciones no se han hecho aquí.
- Cambiar el generador a propósito exige regrabar (`record_manifest_golden.gd`, documentado en `DEVELOPMENT.md:212`) y subir `FLOOR.VERSION`.

### 7.4 Prueba

`tests/hotel/manifest_golden_test.gd`:
- Comprueba que `golden.version == FLOOR.VERSION` (línea 25).
- Comprueba que las claves grabadas son las de la herramienta (27-28).
- Para cada caso, vuelve a dibujar con `RECORD.draw` y compara manifiesto y televisores (31-34).
- Escribe `res://evidence/manifest_golden_test.json` (36-37).

---

## 8. Lógica pura frente a árbol de escena

### 8.1 Sin nodos (`extends RefCounted`)

- `map_generator.gd`: todo el generador. No usa física ni navegación; los vectores y el azar son de Godot pero no hay nodos.
- `wall_walker.gd`: entero, solo enteros, `Vector2i` y diccionarios.
- `exit_route_signs.gd`: entero, sin azar, solo vectores de rejilla y metros.
- `digit_placement.gd`, `tv_placement.gd`, `document_placement.gd`, `hint_placement.gd`: azar y geometría, sin nodos.
- `hotel_palette.gd`: tablas y funciones sobre `Dictionary`.

### 8.2 Dependencias que tocan algo del motor o de la escena

- `floor_definition.gd`:
  - `closest(map: RID, point)` (58-59): `NavigationServer3D.map_get_closest_point`.
  - `navigation_path(map: RID, origin, target)` (310-321): `NavigationServer3D` y `NavigationPathQueryParameters3D`/`Result3D`.
  - `room_at` (78-89): caché estática `index_rooms` y `grid_index` (105-106), que se reconstruye si cambia el array de habitaciones (80-81).
- `map_validator.gd`: `validate_physics()` (231-303) usa `World3D.direct_space_state`, `cast_motion`, `intersect_shape`, `CapsuleShape3D` y `BoxShape3D`. No se puede llamar sin física.
- `document_placement.gd:49`, `tv_placement.gd:63`, `hint_placement.gd:355`: llaman `GEOMETRY.prop_transform(room, prop, palette)` de `hotel_geometry.gd:1958`. Es una función estática que devuelve `Transform3D` (solo matemáticas), pero vive en el script de un nodo (`hotel_geometry.gd:1`).
- `document_placement.gd:10` y `:63`: `CATALOG.for_creature(creature)` de `discovery_catalog.gd` (52 líneas). El llamador pasa la cadena `"locust"` (`hint_placement.gd:76`, `interaction.gd:78`, `loop_test.gd:207`).
- `hint_placement.gd:76`: `DOCUMENTS.choose(manifest, "locust", containers)`. `containers` lo arma `room_dressing.gd:220` durante la construcción (builder.containers).

### 8.3 Lo que sí toca el árbol (fuera de la ficha)

- `hotel_main.gd` (crea `GENERATOR.new()`, espera fotogramas, llama a navegación).
- `hotel_geometry.gd` (3298 líneas, `extends Node3D`): consume el manifiesto y pone nodos.
- `code_lock.gd`, `interaction.gd`, `televisions_objective.gd`, `room_dressing.gd`: lo consumen en partida.

---

## 9. Motor Godot usado por la generación, con apariciones

Conteo con grep en los 9 archivos de generación del hotel y en `hotel_palette.gd`:

| Elemento | Dónde (apariciones aproximadas) | Uso |
|---|---|---|
| `RefCounted` (`extends`) | 10 archivos (9 de generación y `hotel_palette.gd`) | Base sin nodo |
| `RandomNumberGenerator` | `map_generator` 40 (6 `.new()`), `hint_placement` 10, `digit_placement` 2, `document_placement` 1, `tv_placement` 1 | Todo el azar |
| `Vector2i` | `map_generator` 46, `exit_route_signs` 15, `wall_walker` 11, `hint_placement` 6, `floor_definition` 4, `map_validator` 4, `hotel_palette` 4 | Celdas, rejilla, rumbos |
| `Vector2` | `map_generator` 25, `hint_placement` 13, `floor_definition` 3, `map_validator` 2, `hotel_palette` 4 | Posiciones en plano, forma |
| `Vector3` | `floor_definition` 24, `map_validator` 19, `hint_placement` 3, `document_placement` 2 | Posiciones en el mundo |
| `Rect2`, `Rect2i` | `map_generator` 11, `hint_placement` 1 | Caja de rejilla, ventana de parecido |
| `Basis` | `floor_definition` 2, `map_validator` 7 | Giros de sockets, hojas |
| `Transform3D` | `map_validator` 6 | Sondas físicas |
| `PackedByteArray` / `PackedInt32Array` | `map_generator` 4 / 1 | Cuadrícula de 48 × 48 para parecido |
| `PackedVector3Array` | `floor_definition` 2 | Ruta de navegación |
| `NavigationServer3D` | `floor_definition` 2 | Ruta y punto más cercano |
| `NavigationPathQueryParameters3D` / `…Result3D` | `floor_definition` 1 / 1 | Consulta de ruta |
| `RID` | `floor_definition` 2 | Mapa de navegación (parámetro) |
| `World3D` | `map_validator` 1 | Mundo de física |
| `direct_space_state` / `cast_motion` / `intersect_shape` | `map_validator` 7 / 5 / 2 | Sondas de cápsula y hoja |
| `PhysicsShapeQueryParameters3D` | `map_validator` 2 | Consultas de forma |
| `CapsuleShape3D` / `BoxShape3D` | `map_validator` 1 / 1 | Cápsula de 0.32 m, hoja de puerta |
| `Callable` | `map_generator` 2 (variables tipadas) | Filtros de función |
| Lambdas `func(` | `map_generator` 32, `hint_placement` 8, `exit_route_signs` 3, `map_validator` 3 | Orden y filtros |
| `hash()` | `map_generator` 7, `hint_placement` 2, `digit_placement` 2, `document_placement` 1, `tv_placement` 1 | Semillas |
| `sort_custom` | `map_generator` 9, `hint_placement` 3, `tv_placement` 1 | Ordenar |
| `shuffle` (función propia, `map_generator.gd:2078`) | `map_generator` 15 llamadas, `hint_placement` 5 | Barajar con su RNG |
| `preload(` | `map_generator` 4, `floor_definition` 2, `map_validator` 1, `hint_placement` 3, `document_placement` 3, `digit_placement` 1, `tv_placement` 3, `exit_route_signs` 1 | Cargar scripts |
| Nodos, `SceneTree`, `get_tree`, `await`, señales, `_process`, `Time`, `OS`, `FileAccess`, `JSON` | 0 | No aparecen en los 9 archivos |

Funciones de Godot que dependen de un detalle del motor: `hash()`, `RandomNumberGenerator` (algoritmo y `seed` como propiedad, `RandomNumberGenerator.xml:54`), `Dictionary` (orden de inserción) y `Array.sort_custom`. La referencia del repo no describe `hash()`, `sort_custom` ni el algoritmo de RNG (descripciones vacías). Ver §14.

---

## 10. Constantes y cifras (`ruta:línea`)

### 10.1 Generador (`map_generator.gd`)

| Constante | Valor | Línea | Comentario del código |
|---|---|---|---|
| `MIN_WALK` | 30 | 34 | Habitaciones mínimas que hay que recorrer entre las tres etapas (suma de puertas). |
| `TARGET` | (84, 96) | 38 | Habitaciones por planta del hotel de dos o tres. |
| `OPEN_RUN` | 45.0 m | 42 | «The creature sees seventy metres and runs faster than anybody» (39-41). |
| `ATTEMPTS` | 8 | 45 | Intentos por piso. |
| `TRIES` | 6 | 46 | Intentos por planta. |
| `ALIKE` | 0.3 | 51 | Parecido máximo de pasillos entre plantas. |
| `LIKENESS_CELLS` | 48 | 52 | Tamaño de la cuadrícula de medición. |
| `SHAPES` | rect, notch, ell, you, court, aitch | 54 | Formas de corte. |
| `FAR_SIDE` | 0.3 | 58 | Fracción de habitaciones lejanas que el refugio evita. |
| `WINDING` | 1.5 | 59 | Rodeo mínimo del camino respecto de la línea recta. |
| `LOOPS` | 4 | 63 | Ciclos extra antes del refugio. |
| `DETOUR` | 1.5 | 67 | Rodeo mínimo al que obliga una salida expuesta. |
| `EXPOSED_TRIES` | 14 | 68 | Candidatos probados. |
| `FIRE_JAMB` | 0.2 m | 73 | Separación del marco de la puerta de incendios. |
| `LANE_WALL` | 6.0 m | 75 | Pared más corta que esto es fin de carril. |
| `OPEN_DOORS` | (0.8, 0.5) | 79 | Probabilidad de puerta abierta (según tipo de sala y orden). |
| `FIRE_OPEN` | 0.3 | 80 | Puerta de incendios abierta. |
| `HIDE_SPOTS` | −1.8, 0, 1.8 | 84 | Puntos de armario en la pared. |
| `HIDE_CLEAR` | 1.75 m | 85 | Distancia de un armario a la puerta. |
| `HIDE_APART` | 3.0 m | 88 | Distancia entre dos armarios de una pared. |
| Profundidad del refugio | `DEPTH` / `FIRST_DEPTH` de la paleta (vía `depth_wanted()`) | 1444, 1617, 1622-1623 | Fracción del camino más largo. |
| Celdas reservadas al lobby | 1 en la planta 0, 2 en las demás | 374 | Celdas de lobby que no cuentan como habitación. |
| `scaled()` | `round(v · drawing)` | 1998-1999 | Escala por tamaño de piso. |
| `min_walk()` | `min(30, round(30·media))` | 2003-2005 | Mínimo de recorrido escalado. |

### 10.2 Piso y geometría (`floor_definition.gd`)

| Constante | Valor | Línea | Uso |
|---|---|---|---|
| `VERSION` | 8 | 9 | Versión de planos. |
| `PITCH` | 6.0 m | 25 | Separación vertical de plantas. |
| `PLANTAS` | 3 | 26 | Número de plantas (etapas). |
| `CELL` | 12.0 m | 27 | Respaldo de tamaño de celda. |
| `PORTAL` | 1.3 m | 29 | Hueco libre de puerta. |
| `LEAF_WIDTH` | 1.2 m | 31 | Ancho de hoja. |
| `VOID` | 20 | 34 | Celda vacía. |
| `LIFT_DEPTH` | 2.34 m | 67 | Profundidad de la cabina tras el lobby. |
| `navigation_path` | `path_search_max_polygons = 0`, `simplify_epsilon = 0.02` | 316-318 | Parámetros de ruta de navegación. |

### 10.3 Validador (`map_validator.gd`)

| Constante | Valor | Línea | Uso |
|---|---|---|---|
| `OPEN_RUN` | 45.0 m | 8 | Recta abierta máxima. |
| `JAMB` | 0.15 m | 10 | Margen de la jamba. |
| `FIRE_JAMB` | 0.3 m | 12 | Jamba de incendios. |
| `HIDE_CLEAR` | 1.75 m | 14 | Distancia de armarios. |
| Cápsula | radio 0.32, alto 1.8 | 234-236 | Sondas físicas. |
| Centro | 0.94 m | 242 | Altura del pecho. |
| Esquinas de sondeo | ±2.2 m | 308 | Acceso a coberturas. |
| Alcoba | ±4.4 m, desplazamiento 3.0 | 255-256 | Entrada a alcoba. |
| Hoja | caja (1.2 − 0.3) × 2.3 × 0.05 | 269-270 | Barrido de puerta. |
| Ángulos de hoja | 0.6, 0.9, 1.2, 1.48 | 297 | Apertura comprobada. |

### 10.4 Paleta del hotel (`hotel_palette.gd`)

| Constante | Valor | Línea | Comentario del código |
|---|---|---|---|
| Roles | RECEPTION 0, LANDING 9, LOBBY 10, CORRIDOR 11, GALLERY 12, REFUGE 19, VOID 20 | 13-22 | Mismo número en todas las paletas. |
| `TV_ROOM` | 14 | 27 | Sala de televisión. |
| `EMPTY_SALON` | 18 | 28 | Salón vacío. |
| `AREA` | {1: 0.5, 4: 1.2, 5: 1.35} | 37 | Comentario 30-36: solo, la mitad de lo que andan dos o tres; cuatro, una quinta parte más; cinco, un tercio más. |
| `ROOMS` | (81, 99) | 42 | Habitaciones por planta del hotel de dos o tres. |
| `NUMBERED_MOST` | 96 | 43 | Habitaciones con número como mucho. |
| `tv_rooms(area)` | 6 si < 1, si no 8 | 61-62 | Televisores por planta 2 y 3. |
| `rings(area)` | 4 si < 1, si no 6 | 64-65 | Anillos mínimos. |
| `WARDROBES` | {1:2, 2:2, 3:2, 16:2, 13:1, 14:1, 15:1, 8:1} | 69 | Armarios por tipo. |
| `HARD_FLOORS` | [4, 7, 9] | 71 | Suelo de baldosa. |
| `RECIPES` | 21 filas (tipo 20 vacío) | 80-102 | Cuatro piezas por esquina. |
| `HEIGHTS` | 4.2 / 3.15 por tipo | 108 | Altura de sala. |
| `HALL_HEIGHT` | 4.8 m | 109 | Altura de salón. |
| `NEVER_DARK` | [0, 4, 7, 8, 9, 10, 19, 20] | 112 | Nunca a oscuras. |
| `NO_NUMBER` | [0, 7, 8, 9, 10, 11, 12, 15, 19, 20] | 117 | Sin número en la puerta. |
| `TIDY_ROOMS` | [1, 1, 2, 2, 2, 3, 4, 16] | 120 | Habitaciones de planta ordenada. |
| `UNRULY_ROOMS` | [2, 3, 4, 5, 6, 13, 14, 16, 17, 18] | 121 | Habitaciones de planta desordenada. |
| `SERVICE_ROOMS` | [7, 8, 9, 15] | 122 | Servicio. |
| `HALL_ROOMS` | [5, 6, 17, 18] | 123 | Salones. |
| `MODULE_SIZES` | 12, 12, 13, 13, 14, 15, 16 m | 126 | Lado de módulo. |
| `LANE_WIDTHS` | 3.0, 3.5, 3.5, 4.0 m | 127 | Ancho de carril. |
| `DECKS` | 3 listas de planes | 132 | Planes por planta. |
| `SERVED` | spine 0.4, twin 0.45, ring 0.45, comb 0.55, blocks 0.6, arms 0.4, warren 0.0, rot 0.35 | 135 | Fracción de habitaciones servidas. |
| `APART` | blocks ↔ rot | 137 | Planes que no pueden compartir piso. |
| `ORDER_BASE` | [0.8, 0.6, 0.42] | 141 | Deterioro por planta. |
| `DEPTH` | (0.55, 0.9) | 144 | «How far in the refuge is» (142-143). |
| `FIRST_DEPTH` | (0.65, 0.9) | 149 | Profundidad de la planta 0. |
| `FIRST_WALK` | 150.0 m | 150 | «being left in under a minute» (145-148). |
| `HALLS` | (2, 6) | 154 | Salones por planta. |
| `ROOM_DOORS` | {warren: 1.8, rot: 1.25} | 158 | Puertas entre habitaciones. |
| `EXPOSED` | [0, 30, 50] | 167 | Metros de tramo expuesto (comentario 159-166). |
| `EXPOSED_CHANCE` | [0, 0.5, 1.0] | 168 | Probabilidad por planta. |
| `SECOND_EXPOSED` | 35.0 m | 169 | Segundo tramo de la planta 2. |
| `EXPOSED_LONGEST` | 90.0 m | 170 | Máximo de tramo. |
| `DOOR_PLACES` | 0, 0, ±1.5, ±2 | 176 | Desplazamiento de puertas. |
| `DOOR_PLACES_DOMESTIC` | 0, ±1.5 | 177 | Con alcoba. |
| `DOMESTIC` | [1, 2, 3, 4, 7, 15, 16] | 178 | Habitaciones con alcoba. |
| `DARK_OWN` | 0.23, 0.29, 0.36 | 185 | Oscuridad propia por planta (comentario 180-184). |
| `DARK_SPREAD` | 0.45 | 186 | Contagio a vecinos. |
| `DARK_CORRIDOR` | (0.03, 0.05) | 187 | Pasillos a oscuras (casi nunca). |
| `WEAR` | 0.25 | 190 | Ruido de desgaste. |
| `KEPT` | (0.25, 0.55) | 191 | Umbrales de desgaste. |
| `WALL_KINDS` | bed, sofa, desk, tv, reception, washer, basin, shelf | 195 | Piezas que dan la espalda a la pared. |
| `CHANDELIER_HEIGHT` | 4.0 m | 215 | Araña por encima de esta altura. |
| `BATTEN_ROOMS` | [4, 7, 8, 9] | 212 | Fluorescentes. |
| `MODULE_SET` | tipo → conjunto de muebles | 219 | Muebles de pared por tipo. |

### 10.5 Colocación de textos y objetos

| Archivo | Constantes | Líneas |
|---|---|---|
| `digit_placement.gd` | `COUNT = 4`; `MIN_FROM_ENTRANCE = 30`; `SHARE_IN = 0.25`; `DEEP = 0.8`; `NO_PAGES = ["luggage"]` | 9, 12, 13, 15, 26 |
| `document_placement.gd` | `SURFACES` (mesa, escritorio, mesilla = 0.84 m); `HOLDERS = ["luggage"]`; `SHUT_IN = 0.25`; `PER_FLOOR = 2`; `MIN_FROM_START = 25`; `SHARE_IN = 0.2` | 11, 17-23 |
| `tv_placement.gd` | `SPARE = 2`; `LEAST = 2`; `MIN_FROM_ENTRANCE = 25`; `SHARE_IN = 0.2` | 14, 17, 20, 21 |
| `hint_placement.gd` | `POINTS = 3`; `ZONE_SPAN = (0.1, 0.6)`; `ZONE_LEAST = 12`; `POINT_SPAN = (0.25, 0.85)`; `CIRCLE = 10`; `CORNER = (44, 32)`; `MARKED = 4`; `BLANK_CARDS = 3`; `STATES` (8 textos, cuatro «HECHA») | 24, 28-43 |
| `exit_route_signs.gd` | `COUNTS = [(2,4), (3,6), (3,6)]`; `STEPS = [33, 42, 50]`; `QUIET = 0.35`; `ROOM_COST = 12`; `ENTRY_WEIGHT = 20`; `APART = 18`; `SPREAD = 45`; `NEAR_REFUGE = 9`; `MEETING = 1.0`, `CORNER = 0.8`, `STRAIGHT = 0.5` | 31-49 |

El valor 84/96/81/99 y las demás cifras de «cómo se siente» están comentadas en el código con la fecha del autor (20 y 22 de octubre de 2026 en `hint_placement.gd:4-5`, `hotel_palette.gd:145-148`, `exit_route_signs.gd:27-36`).

### 10.6 Constantes de prueba (`tests/hotel/hotel_test.gd`)

- `SEEDS = 300` (19). `for seed_value in SEEDS` recorre 0 a 299 (según la sintaxis de GDScript; §14). Entre 1 y 30 para 1, 2, 4 y 5 supervivientes (192).

---

## 11. Orden de ejecución, física y azar

### 11.1 Azar (dentro del generador)

- Todo el azar sale de `RandomNumberGenerator` con semilla fija. Cualquier sorteo extra o cualquier cambio en el orden de los sorteos cambia lo que sale después de él en ese mismo flujo.
- Dentro de `candidate`, el orden fijo es: planes → plantas (cada una con su flujo) → decoración → números → puertas y armarios → luz → muebles de `furnish` (vacío en el hotel).
- `lay_planta` sortea en este orden: deriva (`order_field`), forma, pasillos, entrada, servicio, puertas, salones, poda, bucles, refugio, poda. `expose` solo sortea si `EXPOSED[planta] > 0` (el `or` es perezoso, 1121).
- `place_refuge`: en standby ordena los candidatos por `share` (1472); fuera de standby sortea cada intento con `weighted()` (un `randf()` por intento, 1481). La cola de islas se ordena por peso (1499).

### 11.2 Orden de iteración dependiente de Dictionary y Array

- Varios bucles recorren `Dictionary` (`alive`, `cost`, `flow`, `on`, `merged.values()`) o `Array` (`f.edges`, `f.adjacency`) en el orden de inserción. Ejemplos: `prune` (`on.keys()`, 763), `exit_route_signs` (`for id in cost`, 117, 132, 141), `hang_doors` (`f.edges`, 1848, consume `rng` por cada arista), `join` (`missing` ordenado, 910).
- Muchos bucles ordenan antes de barajar (`cells.sort()` en `map_generator.gd:813, 844, 983, 1080, 1322`). Otros no, y dependen del orden de inserción.
- `sort_custom` con desempate explícito: `map_generator.gd:215, 1778` y `hint_placement.gd:182`.
- `sort_custom` sin desempate explícito: `map_generator.gd:686, 992, 1179, 1472, 1499` y `tv_placement.gd:76`. En 1499 los pesos son productos de 2.0, 1.5, 0.3 y 6.0, así que hay muchos empates. Cómo ordena Godot los empates no está comprobado (§14).
- `adjacency[id]` se rellena en el orden de creación de aristas (`connect_rooms`, 2094-2097). Lo recorren BFS, `way_to`, `join` y los muros.

### 11.3 Física

- `validate_physics` se llama después de dos fotogramas de física (`hotel_main.gd:892-894`). Usa la geometría ya construida (`hotel_main.gd:954`). Si la geometría cambia, cambia el resultado de la validación.
- Las hojas se comprueban con máscara 1 | 8 (`map_validator.gd:273`). La máscara 8 son las hojas de puerta.
- La navegación se comprueba con hasta 90 fotogramas de espera (`hotel_main.gd:921-926`). Si no se llega a la salida, error y no se inicia la partida.

### 11.4 Señales, procesos y tiempo

- La generación es síncrona: sin `await`, sin señales, sin `_process`.
- `hotel_main.gd:836-837` y `892-893` esperan fotogramas antes de validar y navegar. El orden importa: primero la geometría, luego la validación.

### 11.5 Mutación y estado estático

- `TV_PLACEMENT.settle()` muta `props` después de hacer el hash del manifiesto (§5.4).
- `FLOOR.index_rooms` y `FLOOR.grid_index` son estáticos (`floor_definition.gd:105-106`). `room_at` reconstruye el índice cuando el array de habitaciones cambia de identidad (80-81). Así, un manifiesto nuevo siempre reconstruye.
- Las instancias de `GENERATOR` guardan `areas`, `drawing`, `laying`, `stats`. `stats` solo lo leen herramientas.

---

## 12. Pruebas que vigilan esta parte

### 12.1 Golden

- `tests/hotel/manifest_golden_test.gd`: 255 casos, huella SHA-256 del manifiesto y de los televisores (§7). Tarda unos 40 segundos (`DEVELOPMENT.md:212`).

### 12.2 `tests/hotel/hotel_test.gd` (generación, líneas 17-224)

- 300 semillas (0 a 299): validación, ids, una puerta por refugio (157-158), refugio sin tocar por la mano (160), lifts alineados (161), más de la mitad de puertas fuera del centro (162), oscuridad por planta entre 20 y 55 % (164), pasillos a oscuras menos del 10 % (165).
- Piso de reserva válido y con recorrido mínimo (170).
- Numeración por centena (171), subida de números 0.35-0.65 (172-173), sin fugas entre plantas (174), 80 a 100 habitaciones por planta (175).
- Pasillo expuesto de 30 m en casi todos (≥ 0.98) y de 50 m en la mayoría (≥ 0.88) en la planta 2 (179-181).
- Supervivientes 1, 2, 4 y 5 válidos con seeds 1 a 30 (189-210). Relaciones de tamaño (210). Ninguna planta pasa de 96 numerados (211).
- Recorrido mínimo medio ≥ 40 (213). Fallos del piso de reserva < 1 % (214). 21 tipos de celda en el lote (215).
- Reproducible con 81; distinto con 82 (216-217).
- Fijado: `hash(JSON.stringify(generate(81))) == 388120810` y `… 777 == 4201817092` (224). Usa `JSON.stringify` con los valores por defecto (orden de claves sí, decimales no).

### 12.3 `tests/hotel/palette_scan_test.gd`

- Ningún número de tipo de sala fuera de las paletas, en todo `game/` y `tools/`, con patrones (`type == 19`, `in [4, 7, 9]`, etc., líneas 22-30). Lista de casos que debe atrapar (32-44) y que no debe atrapar (45-57).
- Constantes de la paleta iguales a las de antes (`moved`, 241-244).
- Las preguntas de la paleta responden como las listas antiguas (`questions`, 247-285): dureza, oscuridad, altura, luz, alcobas, numeración, tamaños de piso.
- La paleta no precarga nada (235). El generador dibuja con la paleta del hotel (295-296). `numbers()` pregunta a la paleta (297-302).

### 12.4 Pruebas que usan el generador

- `creature_contract_test.gd:1025-1026`: `GENERATOR.distance_map` para la distancia desde la salida y el refugio. `creature_contract_test.gd:1531`: `OFFICE_GENERATOR.new().generate(1)`.
- `echo_test.gd:39` (`distance_map`); `echo_test.gd:483-484` (genera 81 otra vez con `roster_count` y compara).
- `loop_test.gd:78` (`PLACEMENT.MIN_FROM_START`); `loop_test.gd:206-208` (`PER_FLOOR`, reproducibilidad de documentos).
- `bots_test.gd:55` (`TV_PLACEMENT.needed(2) + 2`); `bots_test.gd:62` (código por `DIGITS.code`).
- `spatial_audio_test.gd:310` (`DIGITS.code`); `stages_test.gd:686` (`distance_map`).
- `hotel_batch.gd`, `capture_test.gd`, `continue_test.gd`, `difficulty_test.gd`: referencias a `floor_definition.gd`.

### 12.5 Herramientas que miden el generador

- `tools/dev/map_metrics.gd -- 1000`: mide 1000 manifiestos contra umbrales y deja `evidence/map_metrics.json` (`DEVELOPMENT.md:433`).
- `tools/dev/map_plan.gd -- 81`: dibuja en texto las tres plantas (`DEVELOPMENT.md:433`).
- `tools/dev/record_manifest_golden.gd`: regraba la huella.
- `tools/benchmarks/hotel_benchmark.gd`: `distance_map` (164, 255).

---

## 13. Hechos que complican un port (sin diseño)

1. Las semillas dependen de `hash()` de Godot aplicado a arrays con enteros y cadenas, y de `RandomNumberGenerator` con su algoritmo y su `seed`. La huella solo se reproduce si el flujo de sorteos es idéntico.
2. La huella compara el JSON con claves ordenadas y decimales completos. Cambiar el orden de las operaciones con flotantes (por ejemplo, la suma de `along` en `axis()`, 294-297) cambia los hashes.
3. Varias salidas dependen del orden de inserción de `Dictionary` y `Array` (§11.2). `adjacency`, `edges` y `merged` tienen orden. `hang_doors` sortea según `f.edges`.
4. `candidate()` y `lay_planta` usan estado de instancia (`areas`, `drawing`, `laying`) y se reintentan de forma parcial (`drop_planta`, `save`/`restore`). `map_generator.gd` tiene 105 funciones: 88 de instancia y 17 estáticas.
5. Las pruebas de física (`validate_physics`) exigen un mundo de física con la geometría ya construida. El generador no es puro en ese punto.
6. La navegación se comprueba con `NavigationServer3D` después de esperar fotogramas.
7. `settle()` muta el manifiesto después del hash y antes de la geometría.
8. `prop_transform` (`hotel_geometry.gd:1958-1972`) es matemática de `Transform3D`, pero vive en un script de nodo. Lo usan `document_placement`, `tv_placement` y `hint_placement`.
9. El piso de reserva usa la semilla 404 para todo su contenido distinto de los televisores.
10. Los textos del juego están en español dentro del código de `hint_placement.gd` (papeles, partes, órdenes). Los textos del juego no llevan «·» ni «—» (`CLAUDE.md`). No he comprobado si cumplen.
11. Las oficinas (piso 2) extienden el generador base por herencia y sobrescriben funciones. El piso 1 y el piso 2 comparten `map_generator.gd` y `map_validator.gd`. Cualquier cambio en la base alcanza a las oficinas.
12. Los nombres de las pruebas y de los valores fijados (388120810, 4201817092) son literales en el código.
13. El tipo 9 es a la vez `LANDING` (`hotel_palette.gd:14`, lobby del ascensor) y `mantenimiento` (`TYPES`, `SERVICE_ROOMS` en la línea 122). `exit_route_signs.gd:65-66` y `:89` tratan el tipo 9 como circulación (`CIRCULATION` incluye 9, línea 244), así que un almacén de mantenimiento cuenta como circulación para los carteles. `map_generator.gd:1768` excluye el tipo 9 del recuento de numerados por el mismo motivo. El lobby se distingue en el generador por la marca `landing`, no por el tipo.

---

## 14. Sin comprobar

- No se ha ejecutado Godot ni las pruebas. Ninguna huella se ha recalculado. Lo que digo sobre los hashes sale de leer el JSON y el código.
- `hotel_main.gd` solo en tramos: leídos 505-520, 626-640, 730-745, 822-975. Solo grep: 452 (observador), 562-566, 636-669, 1022 y 1682 (`settle_objectives`). Sin leer: 1-505, 520-626, 640-730, 745-822 y 975-2123. No he visto si hay más llamadas a `start_floor`.
- Origen de `intro_seed` (`hotel_main.gd:636, 669`). No seguí quién llama a `start_intro(seed_value)`.
- `hotel_main.gd:402`: la semilla 81 aparece como valor por defecto de una opción. No leí su contexto.
- `hotel_geometry.gd`: solo la cabecera, la línea 34, la función `prop_transform` (1958-1972) y grep. Falta todo lo que consume el manifiesto (muros, puertas, luces, lámparas).
- `room_dressing.gd` (`containers`, línea 220): solo grep.
- `office_*.gd` y `conduit_*.gd`: no leídos. Solo grep de las sobrescrituras (`office_generator.gd`) y de la dependencia de los conductos.
- `hotel_test.gd` líneas 231-723 (pruebas de escena, sin leer). `palette_scan_test.gd` líneas 61-235 (listas `BEFORE`, `GONE` y comprobaciones de compilación, sin leer).
- `creature_contract_test.gd`, `echo_test.gd`, `loop_test.gd`, `bots_test.gd`, `stages_test.gd`, `spatial_audio_test.gd`, `hotel_batch.gd`, `capture_test.gd`, `continue_test.gd`, `difficulty_test.gd`: solo grep.
- `tools/dev/map_metrics.gd` y `tools/benchmarks/hotel_benchmark.gd`: no leídos.
- `manifest_golden.json`: no leído línea a línea. Cifras confirmadas con Python (255 casos, versión 8, 50 hashes únicos por supervivencia, 5 casos de reserva con un solo manifiesto).
- `hash()`: la referencia (`@GlobalScope.xml:273-278`) no trae descripción. No sé el algoritmo ni si es estable entre máquinas o versiones.
- `RandomNumberGenerator`: la referencia no describe el algoritmo (`RandomNumberGenerator.xml`). No sé si es el mismo en todas las plataformas.
- `Array.sort_custom`: la referencia no dice si es estable (`Array.xml:385-390`). Tomo que no lo es.
- Orden de inserción de `Dictionary`: no está confirmado en la referencia del repo. Lo asumo porque el código lo usa.
- `for x in N` en GDScript: la semántica de 0 a N-1 es la que supongo (`hotel_test.gd:19`).
- `NavigationPathQueryParameters3D.path_search_max_polygons = 0` (`floor_definition.gd:316`): no sé qué significa el 0 en Godot 4.7.
- Tamaño real en metros de una planta: no medido. Se deduce de `MODULE_SIZES` y `LANE_WIDTHS`.
- Cuántos intentos de piso fallan en la práctica (`stats`): no ejecutado. `hotel_test.gd:214` dice menos del 1 % en 300 semillas.
- Si los textos del juego cumplen la regla de «·» y «—» en `hint_placement.gd`: no comprobado.
- Si las cifras de la luz y de los sockets de habitación (`room_dressing.gd`, `hotel_geometry.gd`) coinciden con lo que la paleta dice: no comprobado.
- Igualdad de la huella entre máquinas: no comprobada. La huella se grabó en la máquina del autor.
