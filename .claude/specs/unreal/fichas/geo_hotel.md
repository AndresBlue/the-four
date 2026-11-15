# Ficha de hechos: geo_hotel

Fecha: 2026-11-14. Alcance: `game/world/hotel/` (10 archivos .gd) y `game/world/interactables/` (8 .gd, más `office/office_usable.gd`). Total: 19 .gd, 6.640 líneas, todas leídas. `hotel_geometry.gd` (3.298 líneas) en cuatro tramos.

Solo lectura. No se ejecutó Godot, no se compiló nada y no se tocó git. Las referencias son `ruta:línea` desde la raíz del repo. Lo marcado «grep» se obtuvo por búsqueda y no se leyó entero. Lo que no se llegó a leer está en el apartado 19.

---

## 0. Resumen

- El hotel no usa escenas `.tscn`, ni CSG, ni `ImmediateMesh` ni `PrimitiveMesh`. Toda la geometría se construye por código al montar cada habitación (grep: cero apariciones de `.tscn`, `instantiate(`, `CSG`, `ImmediateMesh`, `PrimitiveMesh` en estas carpetas).
- Hay tres vías de geometría:
  1. Cajas unitarias (`BoxMesh` de tamaño 1, o cilindro/cono) transformadas y agrupadas en un `MultiMesh` por (habitación, material, forma) (`game/world/hotel/hotel_geometry.gd:530-631`).
  2. Modelos `.res` importados, también en `MultiMesh` por (habitación, malla) (`hotel_geometry.gd:633-664`, `:735-756`).
  3. Molduras y paneles generados desde secciones 2D, en `ArrayMesh` sin UV (`game/world/hotel/mouldings.gd:64-70`).
- Cada habitación tiene una luz de techo `OmniLight3D`, en tres tipos: tubo fluorescente, candelabro o cúpula (`hotel_geometry.gd:1355-1405`, `game/floors/palettes/hotel_palette.gd:278-283`).
- La luz se aísla por habitación con 16 capas de render y máscaras de cull (`room_layers.gd:28-38`, `:54-75`, `:107-220`) en el preset de menor calidad.
- Las puertas salen de las aristas del grafo del piso. Tienen hoja, sello de sombra, marco y placa. Cada una usa capas de colisión propias (4, 8, 16, 32, 64, 128).
- La luz rebotada se hornea con `VoxelGI` en `WorkerThreadPool`, una planta a la vez (`bounce_light.gd:84-103`, `hotel_geometry.gd:2371-2400`).
- La vestimenta sale de 13 juegos de piezas por módulo (`room_dressing.gd:31-45`).
- Lo que depende del motor: `hash()` y `sin()` en `vary()` (`hotel_geometry.gd:494-504`), las máscaras de cull, la visibilidad en tres tramos (`hotel_geometry.gd:2981-2997`) y los timers de los contenedores (`hotel_container.gd`).

---

## 1. Inventario de archivos leídos

| Archivo | Líneas | Qué hace |
|---|---|---|
| game/world/hotel/hotel_geometry.gd | 3298 | Constructor del piso: habitaciones, muros, puertas, ascensores, luces, sondas, niebla, navegación, visibilidad por rondas y capas. |
| game/world/hotel/room_dressing.gd | 618 | Vestimenta: piezas a lo largo de los muros, cosas sobre baldas, basura y decales. |
| game/world/hotel/prop_factory.gd | 219 | Receta de mobiliario por tipo (cama, sofá, mesa, armario, lámpara, televisor, lavabo...). |
| game/world/hotel/mouldings.gd | 220 | Zócalo, carril, cornisa, paneles del dado y rosetón, desde secciones 2D. |
| game/world/hotel/room_layers.gd | 220 | Asigna 16 capas de render a las habitaciones y calcula las máscaras de cada lámpara. |
| game/world/hotel/bounce_light.gd | 269 | Luz rebotada: un `VoxelGI` por habitación, horneado en hilos de trabajo. |
| game/world/hotel/lighting.gd | 124 | Temperatura de color y perfiles fotométricos (texturas proyectoras). |
| game/world/hotel/mesh_halves.gd | 87 | Parte una malla en dos mitades por z = 0 (puertas con capas). |
| game/world/hotel/stand_in_mesh.gd | 38 | Malla solo en memoria, para el horneado de luz rebotada. |
| game/world/hotel/material_albedo.gd | 31 | Color medio de cada material del hotel, para el sustituto del horneado. |
| game/world/interactables/hiding_place.gd | 448 | Armarios donde se esconde la gente: puertas, asomarse, entrar y salir. |
| game/world/interactables/hotel_container.gd | 415 | Muebles con cajones o baldas que se registran; qué sale y cómo suena. |
| game/world/interactables/hotel_door.gd | 141 | Puerta de hoja: giro, bloqueo por fase, capas de colisión y señales de ruido. |
| game/world/interactables/hotel_television.gd | 154 | Televisor que se enciende: pantalla CRT, foco y relleno de luz. |
| game/world/interactables/hotel_document.gd | 84 | Papel legible en el suelo o sobre un mueble. |
| game/world/interactables/hotel_hint.gd | 97 | Pistas: papel, polaroid o tarjeta «no molestar» en el pomo. |
| game/world/interactables/hotel_panel.gd | 72 | Caja de fusibles cerrada con llave; al abrirla devuelve luz a un ala. |
| game/world/interactables/hotel_lock.gd | 52 | Teclado de cuatro dígitos junto a la última puerta. |
| game/world/interactables/office/office_usable.gd | 53 | Base de los objetos de oficina manejados a mano (solo la interfaz). |

No se leyeron los 19 archivos `.uid` (una línea cada uno).

---

## 2. De la planta a la geometría

### 2.1 Entrada

- `build(data)` (`hotel_geometry.gd:1054-1172`) recibe el `manifest`: `rooms`, `edges`, `merged` (pares abiertos), `gates`, `doors`, `dark`, `kept`, `wing`, `variant`, `layout`, `height`.
- Altura de cada habitación: `palette.height_of(room)`, que vale `HALL_HEIGHT` (4.8) si es parte de un salón con hall, y si no `HEIGHTS[tipo]` (4.2 o 3.15) (`game/floors/palettes/hotel_palette.gd:108-109`, `:255-257`; asignado en `game/world/generation/map_generator.gd:1727-1731`).
- `room.variant` y `room.layout` salen de `decoration.randi_range(0, 3)` en el generador (`map_generator.gd:1729-1730`). La geometría los lee como datos.
- `room.kept` (0 cuidada, 1 descuidada, 2 abandonada) decide basura y decales (`room_dressing.gd:61-64`).
- `room.dark` decide qué lámparas están apagadas (`hotel_geometry.gd:2916-2919`).

### 2.2 Cajas (`box()`, `flush()`)

- `box(parent, pos, size, material, solid, form, euler)` (`hotel_geometry.gd:530-561`):
  - Si el material no está vacío, la transformación `Basis.from_euler(euler) * Basis.from_scale(size)` más `pos` se añade a `batches[parent].groups[material + forma]` (`:537-539`).
  - Si `solid`, crea un `CollisionShape3D` con `BoxShape3D(size)` (`:540-561`).
  - Si el material está vacío, solo hay colisionador.
- Formas (`hotel_geometry.gd:136`): `box`, `cylinder` (`@cyl`), `cone` (`@cone`), `plain` (`@plain`), `detail` (`@detail`), `detail_cylinder` (`@detail@cyl`).
- Malla unitaria por forma (`hotel_geometry.gd:566-577`): `BoxMesh` de tamaño 1. Para `@cyl` y `@cone`, `CylinderMesh` de altura 1, radio inferior 0.5, superior 0.5 (o 0.28 en cono), 20 segmentos, 1 anillo.
- `flush()` (`hotel_geometry.gd:590-631`): por cada grupo crea un `MultiMesh` con `TRANSFORM_3D`, y un `MultiMeshInstance3D` llamado `Mesh_<grupo>` bajo el nodo de la habitación.
  - Si la habitación está registrada, `use_custom_data = true` y cada instancia recibe como custom data el color `(medio ancho, medio fondo, alto, bits de borde)` (`:598-606`; el color se fija en `:1187`, los bits de borde en `:1241`).
  - Fuera de habitación (placas de puerta, escenas sueltas): sin luz rebotada (`:612`).
  - Los grupos `@detail`: sin sombra y con kit (`:615-619`). Los `@plain`: con kit, visibles solo de lejos (`:620`).
  - Grupo de cortinas (`curtain`, `SWAYING`): la sombra va por una copia quieta en negro, solo sombra (`:624-631`, `:585`).

### 2.3 Modelos importados (`place()`, `flush()`)

- `place(parent, mesh, xform, casts, material, only_kit)` (`hotel_geometry.gd:735-756`): guarda la instancia en `model_batches[habitación].meshes[slot]`, donde `slot = "id_malla:casts:material:kit"`. Devuelve un handle `{entry, index, parent}` para mover la pieza después.
- Cada manecilla de reloj (`mesh.has_meta("hands")`) crea un `slot` aparte (`:750-755`).
- `flush()` crea un `MultiMeshInstance3D` `Model_<resource_name>` por slot (`:633-664`).
  - Sombra: apagada si `casts` es falso, o si la altura es menor de `SHADOW_MODEL` (0.6 m) y la malla no tiene meta `casts` (`:658-659`).
  - Si la altura es menor de `SMALL_MODEL` (0.3 m) y el ancho máximo menor de 0.8 m, deja de dibujarse a partir de `SMALL_REACH` (16 m) con margen 2 m (`:660-663`).
- Modelos: `res://assets/props/hotel/<nombre>.res` (`room_dressing.gd:16`, `:58`). Además hay `Chandelier_02.res`, `wall_lamp.res`, `door_leaf.res`, `door_frame.res`, `lift_*.res`, `tv_body.res`, `tv_screen.res`, `sofa.res`, `monstera.res` (`hotel_geometry.gd:286-292`, `:1644-1647`; `prop_factory.gd:7-21`).
- Piezas con cajones o puertas: `<nombre>_body.res` más `<nombre>_<parte>.res`, con meta `parts`, `pivot` y `box` (`hotel_container.gd:171-196`, `hotel_panel.gd:36-59`).
- Relojes: `<nombre>_<manecilla>.res` con meta `pivot`; el cuerpo lleva meta `hands` (`hotel_geometry.gd:750-755`).

### 2.4 Mallas generadas por código

| Pieza | Dónde | Cómo |
|---|---|---|
| Molduras (zócalo, carril, cornisa) | `mouldings.gd:99-127` | `ArrayMesh` por barrido de sección 2D; sin UV. |
| Esquinas de molduras | `mouldings.gd:133-154` | Dos barridos a inglete. |
| Paneles del dado | `mouldings.gd:173-191` | Cuatro bandas `quad` por panel. |
| Rosetón del techo | `mouldings.gd:199-220` | 48 giros de la sección `ROSE`. |
| Tope de la puerta | `hotel_geometry.gd:911-930` | `SurfaceTool` con tres tiras `BoxMesh`. |
| Armario grande: hojas | `hiding_place.gd:244-276` | `ArrayMesh` con tabla, dos paneles y tirador. |
| Mitades (puertas con capas) | `mesh_halves.gd:21-87` | `SurfaceTool`; recorta cada triángulo por z = 0. |
| Sustituto de horneado | `stand_in_mesh.gd:1-38` | Clase `Mesh` propia; no llega a la GPU. |
| Placa «SALIDA» | `hotel_geometry.gd:1861-1917` | `QuadMesh` con `ShaderMaterial` (`exit_panel.gdshader`). |
| Cuadros | `hotel_geometry.gd:2686-2690` | `QuadMesh` con textura recortada por `uv1_scale`/`uv1_offset`. |
| Marco tallado | `hotel_geometry.gd:2691-2706` | Del `.res` quitando la superficie «canvas». |
| Textos | `hotel_geometry.gd:809-825`, `:1824-1835` | `Label3D`, con `pixel_size` 0.007 o 0.0016. |
| Decales | `hotel_geometry.gd:762-780` | `Decal` con textura de `assets/decals/<nombre>.png` y, si existe, `_normal.png`. |
| Papel del código | `hotel_container.gd:322-405` | Dos `BoxMesh` finos, con `QuadMesh` de cara (`add_part`). |
| Papel de la pista/documento | `hotel_document.gd:20-84`, `hotel_hint.gd:21-97` | `BoxMesh`, `PlaneMesh`, `QuadMesh`. |

### 2.5 Orden de construcción de una habitación (`build_room`, `hotel_geometry.gd:1182-1212`)

1. Color de la raíz de la habitación (`:1187`).
2. `floor_surface` (`:1215-1217`).
3. `ceiling` (`:1220-1223`).
4. `walls` (`:1228-1297`).
5. `fittings` (`:1301-1343`): props del `manifest`, alcobas, armarios (`hiding_place.gd`), esquinas, ventilación y decoración (`DRESSING.dress`).
6. `room_lamp` (`:1348-1349`) y `extras` (`:1458-1466`).
7. Niebla de salón, solo en Forward+ (`:1194-1204`).
8. Sonda de reflexión (`:1209-1210`).
9. `extras` (`:1211`) y `build_occluder` (`:1212`, `:2066-2078`).

---

## 3. Dimensiones de la construcción

### 3.1 Muros

- Núcleo del muro: caja de 0.18 m de grosor (`hotel_geometry.gd:846`, `:854`, `:1254`, `:1271`, `:1813`, `:1978`; `wall_core` en `:2086-2090`).
- Colisionador: el grosor completo de 0.18 m. Dibujo: solo la mitad de la habitación (`:2088-2090`).
- Alcobas, tabiques: 0.12 m (`hotel_geometry.gd:1320`, `:1325`, `:1328`); tabique de 0.8 m y 1.6 m también a 0.12 m.
- Dado de paneles: caja de 0.07 m de grueso a 0.11 m fuera del eje (`:1982`); carril plano a 0.15 m (`:1983`); base plana a 0.155 m (`:1984`). Los paneles de `mouldings.gd` salen hasta `PANEL_FRAME = 0.16`, `PANEL_GROOVE = 0.149`, `PANEL_FIELD = 0.155` (`mouldings.gd:44-46`).
- Zócalo: de 0.14 a 0.172 m fuera del eje y de 0 a 0.16 m de alto (`mouldings.gd:27`).
- Carril: de 0.085 a 0.176 m fuera del eje, y de -0.03 a 0.052 m respecto de la cima del dado; la moldura va a 0.96 m (`mouldings.gd:30`; altura en `hotel_geometry.gd:1985`).
- Cornisa: de 0.085 a 0.196 m fuera, de -0.16 a 0 m respecto del techo (`mouldings.gd:34`).
- Escalones de cornisa planos: a `altura - 0.05` (0.1 m de alto) y `altura - 0.13` (0.06 m de alto) (`hotel_geometry.gd:1995-1996`).
- Muro del vestíbulo del ascensor: núcleo de 0.18 m con altura `height - top`, donde top = 2.25 m (hueco más margen), en `hotel_geometry.gd:1809-1813`.

### 3.2 Suelos y techos

- Suelo: losa de 0.3 m, cara superior en y = 0 (`hotel_geometry.gd:1217`: `Vector3(0, -0.15, 0)` y tamaño `(span.x, 0.3, span.y)`). Material: `palette.floor_finish(room)`, que es `"tile"` si el tipo está en `HARD_FLOORS` [4, 7, 9] y `"carpet"` si no (`hotel_palette.gd:263-264`; lista `HARD_FLOORS` en `:71`).
- Techo: losa de 0.2 m, cara inferior en y = altura (`hotel_geometry.gd:1223`). Material: `ceiling_service` en `SERVICE_CEILINGS` [7, 8, 9, 15], `ceiling` en el resto (`hotel_palette.gd:200`).
- Material de muro: `plaster_decrepit` para `DECREPIT_WALLS` [8, 18], `plaster` en el resto (`hotel_palette.gd:267-268`, `:201`).

### 3.3 Alturas

| Qué | Valor | Dónde |
|---|---|---|
| Altura por tipo | 4.2 o 3.15 m | `hotel_palette.gd:108` |
| Hall (salón de varias celdas) | 4.8 m | `hotel_palette.gd:109`, `:256` |
| Candelabro si altura > 4.0 m y no es recepción | 4.0 m umbral | `hotel_palette.gd:215`, `:280` |
| Hueco de puerta (dintel) | 2.65 m | `hotel_geometry.gd:896`, `:1108` |
| Hoja de puerta (colisionador) | 2.58 m | `hotel_geometry.gd:1135` |
| Puerta de salida | 2.65 m | `hotel_geometry.gd:1619` |
| Interruptor de pared | 1.26 m | `hotel_geometry.gd:266` |
| Rejilla de ventilación | 2.46 m | `hotel_geometry.gd:273` |
| Cuadro (centro) | 2.02 m | `hotel_geometry.gd:1543` |
| Lámpara de pared | 1.6 m | `hotel_geometry.gd:1552` |
| Placa de número de puerta | 1.94 m | `hotel_geometry.gd:877`, `:951` |
| Toma de corriente (zócalo) | 0.056 m | `hotel_geometry.gd:222` |
| Alarma de incendios | 1.22 m | `room_dressing.gd:227` |
| Caja de fusibles | 1.25 m | `room_dressing.gd:363` |
| Reloj de pared | 2.05 m | `room_dressing.gd:350` |
| Espejo sobre cómoda | 1.62 m | `room_dressing.gd:249` |
| Espejo sobre consola | 1.45 m | `room_dressing.gd:258` |
| Armario pequeño | 2.3 m de alto, 1.25 ancho, 0.78 fondo | `hiding_place.gd:23-25` |
| Armario grande | 2.45 m de alto, 2.2 ancho, 0.9 fondo | `hiding_place.gd:28` |
| Ascensor, hueco | 1.532 m ancho, 2.23 m alto | `hotel_geometry.gd:1652` |
| Ascensor, interior | 3.211 × 2.415 × 1.861 m | `hotel_geometry.gd:1651` |

Dimensiones del piso (`game/world/generation/floor_definition.gd`, grep): `PITCH = 6.0` (separación vertical entre plantas, `:25`), `PLANTAS = 3` (`:26`), `PORTAL = 1.3` (ancho del hueco de puerta, `:29`), `LEAF_WIDTH = 1.2` (`:31`), `LIFT_DEPTH = 2.34` (`:67`).

---

## 4. Puertas

### 4.1 Creación

- Una puerta por arista del grafo (`hotel_geometry.gd:1093-1161`).
  - No se crea si la pareja está abierta (`:1097`) o si es la última puerta con cerradura (`:1100`).
  - Estado inicial: `spec.open` (`:1159`).
  - Puerta en fase: `gate_stage > 0` la deja cerrada y bloqueada (`:1154-1158`).
- Por cada puerta:
  - Nodo `DOOR` (`hotel_door.gd`) con `collision_layer = 8`, `collision_mask = 4` (`:1112-1113`).
  - Hoja `DOOR_LEAF` con `gi_mode` deshabilitado (`:1121-1127`).
  - Sello de sombra `light_seal`: caja de (ancho − 0.02) × (alto − 0.02) × 0.04 m, solo sombra (`:897-899`, `:1129`).
  - Colisionador de caja 1.2 × 2.58 × 0.07 m, en (0.6, 1.29, 0) (`:1132-1137`).
  - Marco `DOOR_FRAME`, fuera del nodo puerta, sin GI (`:1140-1146`).
  - Tope de jamba `jamb_seal` (`:1147-1148`, `door_stop` `:911-930`): tiras de 0.16 m de ancho (0.04 de lip más 0.12 de solape).
  - Placas (`door_plaques`, `:936-952`): caja dorada de 0.34 × 0.19 × 0.004 m a y = 1.94 m, con número de la habitación de detrás en Label3D.
- Puerta de salida (`build_exit_door`, `:1572-1635`): colisión 8/4, caja 1.2 × 2.65 × 0.12 m, con bloqueo y `gate_stage` del último escalón.

### 4.2 Giro y tiempos (`hotel_door.gd`)

- `OPEN_TURN = 1.48` rad (`:6`), ángulo por puerta `open_turn` que puede ser ±.
- Tiempos: lenta 1.5 s, normal 0.55 s, forzada 0.32 s (`:56-58`). Forzada usa `TRANS_QUAD`; las demás `TRANS_SINE` (`:78`).
- Estados de capa: `GHOST = 64` mientras se mueve, `SOLID = 8` cerrada y libre, `OPEN_SOLID = 64|128` abierta y libre (`:40-49`).
- `_physics_process` solo corre si hay movimiento o capa `GHOST`; cada tick comprueba `holds_somebody()` (`:116-121`, `:103-110`).

### 4.3 Medias para luz por capas

- Con `layered` activo, la puerta se parte en dos mitades (`make_halves`, `hotel_geometry.gd:2247-2271`): casing con `Casing_a_b_0` y `_1`, hoja con `Leaf_0` y `_1`, y las placas por lado.
- Las capas de cada mitad salen de `layer_at` delante y detrás de la puerta (`:2257`).

---

## 5. Ascensores (cabinas)

- Un ascensor por gate, con cabina en el vestíbulo detrás de la puerta de refugio (`build_lifts`, `hotel_geometry.gd:1674-1699`).
- Cabina de otro piso en la celda de llegada (`:1683-1697`). La gente se deja a 1.8 m delante (`:1699`).
- Modelo `lift_car.res` a 0.8 del tamaño original (comentario `:1638-1640`).
- Puertas: `lift_door_a.res`, `lift_door_b.res`. Recorrido: −0.8 y −1.56 m (`:1644-1656`).
- Botones (`lift_call.res`) en (−1.12, 1.21) y pantalla en y = 2.5 (`:1666-1667`). Número de planta «1» en Label3D violeta (`:1671`, `:1824-1835`).
- Pared del vestíbulo: `LIFT_PROUD = 0.006`, `LIFT_RIM = 0.02`, casing 0.09 × 0.085 m (`:1661-1663`).
- Luz de cabina: `OmniLight3D` de 2.4, alcance 5.5 m, color (0.96, 0.94, 0.86), con sombra, siempre encendida (`:1839-1851`).
- La cabina es una «habitación» propia para las capas (`hotel_geometry.gd:1727`, `room_layers.gd:88-93`).

---

## 6. Luces

### 6.1 Lámpara de techo (una por habitación, `lamp_fixture` y `lamp_light`)

| Tipo | Condición | Accesorio | Luz |
|---|---|---|---|
| Tubo fluorescente | `BATTEN_ROOMS` [4, 7, 8, 9] | Caja metal 1.5 × 0.08 × 0.32 m; dos cilindros de 0.05 m por 1.38 m en z = ±0.08 (`hotel_geometry.gd:1370-1371`) | 4100 K + `TUBE_TINT`, energía 3.4 × 1.25 = 4.25, perfil `tube`, y = altura − 0.35, especular 0.45 (`:1372-1375`). |
| Candelabro | altura > 4.0 y no recepción | Modelo `Chandelier_02` a escala 1.5, giro aleatorio por posición, sin sombra del modelo ni GI (`:1376-1394`) | 2700 K, energía 3.6 × 1.25 = 4.5, perfil `chandelier`. |
| Cúpula | resto | Cilindro dorado de radio 0.26 m, alto 0.06 m, en y = altura − 0.03 (`:1397`); cono de vidrio 0.46 × 0.16 × 0.46 m, en y = altura − 0.13, girado π (`:1400`) | 2700 K, energía 4.5, perfil `dome`, y = altura − 0.45 (`:1401-1404`). |

- Rosetón: sobre cada lámpara, salvo en `SERVICE_CEILINGS` (`:1390`, `:1399`).
- Parámetros comunes de la `OmniLight3D` (`hotel_geometry.gd:1409-1451`):
  - Alcance: `max(10, 0.85 × lado mayor)` (`room_layers.gd:79-80`, `:1417`).
  - Atenuación 1.25 (`:1418`); tamaño de fuente 0.12 × penumbra (`:1419`).
  - Sombra activa (`:1421`), sesgo 0.03, sesgo normal 0.6 (`:1426-1427`).
  - Proyector = perfil fotométrico (`:1430`).
  - Niebla volumétrica 0 (`:1434`), fundido por preset (`:1439-1440`).
- Habitación a oscuras: lámpara apagada y marcada `off` (`:1445-1447`). En la cúpula, el vidrio pasa a `light_off` (`:1400`).
- `drain()` y `set_room_power()` cambian la energía de la lámpara de la habitación (apartado 7.2).

Perfiles fotométricos (`lighting.gd:81-124`): `dome` (pozo de luz hacia abajo y un brillo en el techo), `tube` (ala de murciélago), `chandelier` (casi uniforme), `troffer` (oficinas), `box_sconce` (oficinas), `sconce` (cono arriba y abajo, nada detrás). Ganancia del perfil 1.25 (`:23`).

Temperaturas: 2700 K incandescente (`:26`), 4100 K fluorescente (`:27`), balance de cámara 3200 K (`:33`). Pared: 2600 K (`hotel_geometry.gd:2101`).

### 6.2 Lámparas de pared (`sconce_light`, `hotel_geometry.gd:2097-2135`)

- Una por cada cuadro en salas con `SCONCE_ROOMS` [0, 10, 11, 12]: dos por cuadro, a ±0.98 m (`:1545-1556`).
- Cuadros: en muros de 9 m o más, a ±3.5 m del centro (`:1289-1297`). Distancia mínima a un hueco: 2.2 m (`:1176`).
- `OmniLight3D`: alcance 3.4 m, atenuación 1.6, energía `SCONCE_ENERGY` = 1.6, tamaño 0.05 × penumbra, perfil `sconce`, sin GI (`:2103-2119`).
- Solo las 12 más cercanas (`SCONCES_LIT`, `:323`) tienen sombra, a menos de 24 m (`SCONCE_REACH`, `:311`). Las demás hasta 40 m (`SCONCE_FILL_REACH`, `:332`) se encienden sin sombra con energía 1.6 × 0.7 = 1.12 (`SCONCE_FILL_ENERGY`, `:334`, `:3189`).
- Histéresis: una lámpara ya encendida cuenta 1.5 m más cerca (`hotel_geometry.gd:3129`).
- Fundido: `SCONCE_REACH − 8` y 6 m (`:2121`, `:3190`).

### 6.3 Lámparas de mueble (`practical`, `hotel_geometry.gd:2326-2349`)

- `prop_factory.gd:145`: lámpara de recepción, 0.3 de energía, alcance 3.0, a 1.6 m.
- `prop_factory.gd:151`: lámpara de pie, 0.38 de energía, alcance 3.6, a 1.58 m, color `ffb36b`.
- `omni_attenuation = 2.2`, tamaño 0.2 × penumbra, sombra, sin GI, especular 0.25 (`:2334-2342`).
- Fundido: `furniture_lamps − 10` y 8 m (`:2353-2355`). No se crean en habitaciones a oscuras (`:2328`).

### 6.4 Baliza de recepción (`start_beacon`, `:1470-1497`)

- Cristal rojo con emisión `BEACON_GLOW = 9.0` (`:1454`, `:1477`).
- `OmniLight3D` roja de energía 3.2, alcance 10, color (1.0, 0.1, 0.06) (`:1486-1491`).
- La lámpara de techo de recepción baja a 0.3 de su energía (`:1493`).
- Parpadeo de 1.6 s, con 0.8 s encendido y un tartamudeo en cada fase (`:2629-2635`).

### 6.5 Señales de salida

- Refugio: dos paneles a 2.25 m y 2.45 m (`:1464-1465`); `exit_sign` (`:1865-1917`): luz verde (0.25, 1.0, 0.45) de 0.55 de energía, alcance 2.8, sin GI, niebla 0.12, fundido `EXIT_REACH − 4` y 3 (`:1899-1915`).
- Señales de ruta en pasillos (`route_sign`, `:1939-1951`): panel 1.35 × el de refugio (`:1934`), a 2.65 m de alto (`:1935`), a 1 m del centro de la celda (`:1932`).
- Sobreviven al corte de luz (`hotel_geometry.gd:3143-3144`).
- Alcance de visibilidad: `EXIT_REACH = 14` (`:124`).

### 6.6 Televisor (`hotel_television.gd`)

- `SpotLight3D` «Glow»: alcance 8, cono 55°, inclinación −0.3, energía 2.2, con sombra, en `SCREEN + (0, 0, 0.3)` (`:33-37`, `:89-103`).
- `OmniLight3D` «Fill»: alcance 4.5, energía 0.5, sombra en doble paraboloide (`:38-39`, `:104-117`). En Compatibility no hay doble paraboloide (`:114`).
- Pantalla: `SCREEN = (-0.009, 1.672, 0.396)`, tamaño 0.563 × 0.422 (`:22-23`); brillo 1.1 (`:42`); apertura 0.4 s (`:43`).
- Parpadeo: `0.86 + 0.14 sin(t × 9.7) + 0.16 si fposmod(t, 1.7) < 0.06` (`:145`).

### 6.7 Luz rebotada (`bounce_light.gd`)

- Un `VoxelGI` por habitación, por salón (rectangular) o por tramo recto de pasillo (`hotel_geometry.gd:2406-2459`, `:2479-2517`).
- Como mucho 8 volúmenes visibles a la vez (`bounce_light.gd:46-47`).
- Subdivisión 128 si el lado mayor supera 20 m, 64 si no (`:126-127`, `:48`).
- Altura del volumen: alto + 0.3 m (`:124`). Borde: 0.3 m (`:50`).
- Hilos: `clampi(núcleos / 2, 1, 8)` (`:100`).
- El horneado usa un sustituto con el color medio de cada material (`material_albedo.gd`, `stand_in_mesh.gd`).

### 6.8 Sondas de reflexión

- Una por habitación iluminada, de tamaño `(span.x − 0.2, alto − 0.05, span.y − 0.2)` (`hotel_geometry.gd:1210`).
- `ReflectionProbe`: `interior`, `box_projection`, `blend_distance = 0.1`, `intensity = 0.6`, `max_distance = 30` (`:2536-2543`).
- Como mucho 24 creadas (`PROBES_SHOWN`) y 32 mantenidas (`PROBES_KEPT`) (`:388-389`, `:3090-3105`).

### 6.9 Niebla

- `FogVolume` por salón con hall, solo en Forward+ (`:1195-1204`): tamaño 0.65 × span, alto 0.7, y = 0.45, densidad 0.025, albedo `81775f`.
- Visible solo con `preset.floor_haze` (`:3017`).

---

## 7. Interruptores, corte de luz e interactivos

### 7.1 Interruptores

- Los interruptores de pared (`switch_plate`, `hotel_geometry.gd:265-267`) son solo geometría: no tienen código de interacción en esta carpeta.
- Caja de fusibles: `hotel_panel.gd`; hay al menos una por planta (`room_dressing.gd:368-382`); la llave del piso abre cualquiera (texto en el encabezado de `hotel_panel.gd:1-10`). Al abrir, la puerta gira `OPEN = 1.75` rad en `SWING = 0.7` s (`:14-15`, `:36-59`). Alcance `REACH = 0.35` m (`:16`).

### 7.2 Corte de luz

- `blackout(on)` (`hotel_geometry.gd:969-995`):
  - Todas las luces de techo, prácticas, sconces y tubos pasan a `visible = false` y marca `off` (`:972-981`).
  - Balizas: apagadas mientras dure el corte (`:982-984`).
  - Materiales con emisión: multiplicador 0 (`:989-990`).
  - Sconces con cubierta de emisión: se apagan con `switch_off` (`:991-993`).
  - Bounce: se oculta con `show_near(..., false)` (`:995`).
  - Televisores no se tocan (`:961-962`); las señales de salida tampoco.
- `set_room_power(room_id, on)` (`:2930-2941`): corta una habitación, y su lámpara queda marcada `off`.
- `drain(room_id, amount)` (`:2949-2960`): escala la energía de la lámpara sin crear luces nuevas. Con `LIT_DRAIN = 0.9`, la habitación cuenta como a oscuras (`:102`, `:2924-2925`).

### 7.3 Objetos interactivos (interactables/)

Todos son `Area3D` con `collision_layer = 16`, `collision_mask = 0`, excepto la puerta (`StaticBody3D`) y el armario (`Area3D` más cuerpos).

| Archivo | Qué es | Forma del área | Señales | Estados |
|---|---|---|---|---|
| hiding_place.gd | Armario (`BODY` y dos hojas) o armario grande de dos plazas | Caja de (ancho − 0.1) × 1.9 × (fondo + 0.12) (`:162-166`) | `peek_started`, `forced` (`:68-70`) | `opening`, `peek`, `ease`, `occupants`, `pulled`, `held_open`; cierra a los 1.1 s de salir, a 2.5 s de forzar y a 0.6 s de soltar (`:365`, `:374`, `:385`). |
| hotel_container.gd | Cajón, puerta, tapa o balda con papel o llave | 1.1 × 1.2 m de ancho y alto, fondo max(front, 0.3) + 0.25 + 0.2 (`:45-50`) | `searched_changed` (`:11`) | `searched`, `shown`, `left`; el papel o llave aparece con `plant_note()` / `plant_key()` (`:322-405`). |
| hotel_document.gd | Papel en suelo | 0.42 × 0.2 × 0.42 (`:26`) | ninguna | Hojas de 0.21 × 0.297 m (`:43`). |
| hotel_hint.gd | Pista, polaroid o tarjeta en pomo | 0.36 × 0.16 × 0.36, o tarjeta 0.16 × 0.3 × 0.1 (`:31-34`) | ninguna | Tarjeta 0.09 × 0.225 m (`:14`), polaroid 0.088 × 0.107 m (`:15`). |
| hotel_lock.gd | Teclado | 0.5 × 0.6 × 0.35 m a y = 1.3 (`:15-17`) | ninguna | `KEYS = 4` (`:6`); verde (0.3, 1.0, 0.45) si espera, gris si abierto (`:35-36`, `:52`). |
| hotel_panel.gd | Caja de fusibles | 0.5 × 0.6 × 0.35 m (`:29`) | ninguna | `opened`; `open(seconds)`. |
| hotel_television.gd | Televisor | 1.25 × 1.2 × 0.95 m a y = 1.45 (`:72-74`) | `switched` (`:14`) | `on`, `opening`, `flicker`. |
| hotel_door.gd | Puerta | Cuerpo estático | `noise`, `sound_requested`, `swung`, `settled` (`:7-12`) | `opened`, `moving`, `locked`, `gate_stage`. |
| office/office_usable.gd | Base de objetos de oficina | Caja 0.6 × 0.6 × 0.4 (`:17`) | ninguna | `handler`, `action`, `index`, `stand`, `face_yaw`. |

Los sonidos de búsqueda van por `SEARCH_SOUNDS` (`hotel_container.gd:74-84`): cajón grande, cajón suave (5 variantes), caja, papel (`PAPER_SOUND`), o el chirrido de puerta lenta por defecto (`:85`). Volumen: −20 dB por defecto, −10 dB chirrido, −24 dB papel (`:88-90`). El papel no lo oye la criatura (`hushed()`, `:98-99`).

### 7.4 Gestos de contenedor

- Un cajón sale 0.5 × su profundidad (`DRAWER_OUT`, `:134`).
- Una puerta gira 1.1 rad (`DOOR_OPEN`, `:135`) y la tapa de un baúl 1.45 rad (`LID_OPEN`, `:137`).
- Un objeto bajado: 0.4 m delante (`SET_DOWN`, `:144`), empujado 0.2 m (`SHOVE`, `:145`), girado 0.5 rad (`SET_TURN`, `:146`), volcado en 0.3 s (`TOPPLE`, `:147`).
- Duración si el sonido no tiene golpe: 0.8 s (`UNTIMED_OPEN`, `:140`).
- Una pieza registrada se queda abierta para todos (`hotel_container.gd:111-127`, comentario).
- Las piezas `console` y `bookcase` no se abren nunca (`STILL`, `:109`).

### 7.5 Armario (hiding_place.gd)

- Ángulos: abierta 1.75 rad (`OPEN_ANGLE`, `:40`), asomarse 0.75 rad (`PEEK_ANGLE`, `:41`), salir sin ruido 1.3 rad (`EASE_ANGLE`, `:42`).
- Hoja sólida si su ángulo es menor de 0.25 rad (`COLLISION_LIMIT`, `:62`, `:329`); si no, solo bloquea vista (`SIGHT_ONLY = 64`).
- Tiempos de entrada: abrir 0.14 s, cerrar 0.45 s, retraso `ENTER_TIME − 0.2` (`:349-352`). `ENTER_TIME = 0.5`, `LEAVE_TIME = 0.34`, `QUIET_EXIT = 3.0`, `QUIET_LEAVE_TIME = 0.6` (`:51-54`).
- Tope de capa 128 (`SURVIVORS_ONLY`, `:191`): ocupa el interior mientras nadie de esta máquina está dentro, y se quita en el mismo fotograma en que alguien entra (`:312-320`).

---

## 8. Colisiones y capas

### 8.1 Capas de colisión

| Valor | Uso | Dónde |
|---|---|---|
| 1 (defecto) | Mundo, muros, suelo, techo, mobiliario y navegación | `hotel_geometry.gd:546-554`, `:2810` (`geometry_collision_mask = 1`). |
| 4 | Supervivientes (máscara de puerta abierta) | `hotel_door.gd:109`, `:50-53`. |
| 8 | Puertas cerradas y hojas de armario | `hotel_geometry.gd:1112`; `hiding_place.gd:225`. |
| 16 | Objetos interactivos (rayo de foco) | `hiding_place.gd:147`, `hotel_container.gd:43`, `hotel_document.gd:22`, `hotel_hint.gd:23`, `hotel_lock.gd:11`, `hotel_panel.gd:25`, `hotel_television.gd:66`. |
| 32 | Criatura | `hotel_door.gd:50-53`, `hiding_place.gd:443`. |
| 64 | Solo vista y oído (no bloquea a cuerpos); también eco de la criatura | `hotel_door.gd:40-41`, `hiding_place.gd:63-64`, `hotel_container.gd:283`. |
| 128 | Solo supervivientes | `hotel_door.gd:42-43`, `hiding_place.gd:191`. |

Máscaras de consulta: `hiding_place.gd:443` usa `1 | 8 | 4 | 32` para la salida. `hotel_door.gd:109-110` usa 4 si está abierta, o `4 | 32` si cerrada.

Inferencia del comentario: 4 son supervivientes y 32 es la criatura (`hotel_door.gd:50-53`). Esto viene del texto del comentario, no de la definición de las capas en el proyecto.

### 8.2 Capas de render (`room_layers.gd`)

- Capa 1: la de todo lo que se dibuja de forma normal.
- Bits 4 a 19 (`ROOMS = 0xFFFF0`, `:31`): 16 capas, una por habitación (color de grafo), con `FIRST = 4` y `COUNT = 16` (`:28-29`). Son capas 5 a 20 contando desde 1.
- `ALL = 0xFFFFF` (`:32`).
- `put_on()` cambia capas y máscaras solo si la instancia está en capa 1, y oculta y muestra la instancia alrededor del cambio (`:54-59`). Comentario: no se puede cambiar una pareja geometría-luz emparejada en Godot 4.7.2 (`:42-53`).
- Alcance de vecindad: `LATE_REACH = 8` (`:35`) y `OFFICE_LATE_REACH = 6` (`:37`).
- Radio de coche: `CAR_REACH = 5.5` (`:40`).

---

## 9. Cuántos nodos, mallas y luces

No se midió. Nada de esto se ejecutó. Lo que sigue es la estructura del código.

Por habitación:
- 1 `Node3D` raíz, `Room_<id>_<tipo>` (`hotel_geometry.gd:1069-1073`).
- 1 `OmniLight3D` de techo (siempre, también en celdas vacías apagadas, `:1078-1085`).
- 1 `StaticBody3D` «Solid» con un `CollisionShape3D` por caja sólida (`:546-554`).
- 1 `MultiMeshInstance3D` por cada par (material, forma) presente (`:607-621`). Como máximo 26 materiales × 6 formas.
- 1 `MultiMeshInstance3D` por cada modelo distinto (`:642-664`).
- Decales: hasta 4, 9 o 16 según el estado (`room_dressing.gd:560`), menos los que se descartan por los huecos (`:597`, `:601`, `:617`).
- Lámparas de pared: dos por cuadro en salas `SCONCE_ROOMS` (`hotel_geometry.gd:1545-1556`).
- Armarios: uno por cada posición de `FLOOR.hiding_positions(room)` (`hotel_geometry.gd:1332-1340`); los palettes fijan 2, 1 o 0 según el tipo (`hotel_palette.gd:69`, grep).

Por puerta: `DOOR` más `Leaf`, `LightSeal`, `CollisionShape3D`, `Casing_a_b`, `Stop`, dos `Plaque_*` si hay número, y la etiqueta (`hotel_geometry.gd:1110-1160`, `:936-952`).

Por planta: no comprobado. Los comentarios dan cifras de una semilla (seed 81), pero se contradicen (apartado 18).

---

## 10. Materiales, UV y texturas

### 10.1 Materiales

- 26 claves cargadas de `res://game/presentation/materials/<clave>.tres`, duplicadas en `_init()` (`hotel_geometry.gd:129`, `:399-403`):
  `plaster`, `plaster_decrepit`, `wood`, `panel`, `door`, `trim`, `linen`, `fabric`, `bedspread`, `leather`, `metal`, `black`, `green`, `screen`, `leaf`, `ceramic`, `tile`, `gold`, `carpet`, `ceiling`, `ceiling_service`, `light`, `shade`, `mirror`, `painting`, `curtain`.
- Derivados (`hotel_geometry.gd:408-424`):
  - `light_off` (cúpula apagada, emisión 0, albedo oscurecido 0.55).
  - `panel_field` (panel sin rayas: `panel_spacing = 0`).
  - `wood_leaf` y `panel_leaf` (`object_space = true`, para que la veta gire con la hoja).
  - `shade_off` (pantalla apagada).
  - `tube_<n>` (tubo que parpadea; `:1366-1368`).
- Color medio por material (`material_albedo.gd:4-31`): por ejemplo `plaster` (0.574, 0.506, 0.364), `wood` (0.302, 0.171, 0.091), `gold` (0.003, 0.002, 0.000), `curtain` (0.253, 0.066, 0.058). Son sRGB y los mide `tools/lighting/measure_albedo.gd` según el propio comentario.
- Paleta de cada piso: `palette.wall_material(room)` y `palette.floor_finish(room)` (`hotel_geometry.gd:1188`, `:1217`).
- Decales: tinte por nombre en `DECAL_TINT` (`hotel_geometry.gd:797`).
- Pinturas: `StandardMaterial3D` con `roughness = 0.62` (`:2675-2678`). Vidrio: `clearcoat_roughness = 1.0` (`:2727-2733`).

### 10.2 Texturas (escaneos y versión lite)

- Escaneos: `assets/textures/<conjunto>/albedo.jpg`, `normal.jpg`, `orm.jpg`; versión 1k con `_1k` (`hotel_geometry.gd:481-491`). Se carga con `load()` síncrono.
- Versión lite (sin escaneos): `assets/textures/lite/<clave>.png`, con tamaño en metros en `lite.json` (`:439-479`). El json se lee con `FileAccess` y `JSON.parse_string` (`:473-474`).
- Calidad: `preset.surface_detail < 0.5` quita los mapas (`:2580`); `small_maps` elige 1k (`:2579`).
- Uniformes del shader: `use_maps`, `albedo_map`, `normal_map`, `orm_map`, `use_lite`, `lite_map`, `lite_metres`, `panel_spacing`, `object_space` (`:447-471`, `:418-421`).
- `wood.gdshader` y `wood_lacquer.gdshader` (`:2712-2713`, cambio de shader por preset en `:2714-2718`).
- Shader de cristal de la salida: `exit_panel.gdshader` (`hotel_geometry.gd:1859`).
- Shader de la pantalla: `game/intro/tv_screen.gdshader` (`hotel_television.gd:18`).
- Texturas de decal: `assets/decals/<nombre>.png` y `_normal.png` (`hotel_geometry.gd:762-770`).
- Texturas de papel: `nota-hotel-lejos.png`, `carta-lejos.png`, `libreta-lejos.png`, `carta-trozo.png`, `no-molestar.png`, `no-molestar-reverso.png` (`hotel_document.gd:9-13`, `hotel_hint.gd:11-12`, `hotel_container.gd:319`).
- Pinturas: `assets/paintings/<id>.jpg` y `paintings.json` (`hotel_geometry.gd:2662-2676`).

### 10.3 UV

- Las molduras no tienen UV (`mouldings.gd:64-70`: solo VERTEX y NORMAL). El shader de estos materiales tiene que sacar coordenadas en otro sitio. Qué usa exactamente: no comprobado (`game/presentation/shaders/surface.gdshaderinc`, no leído).
- Cajas: `BoxMesh` unitario estirado por la transformación de la instancia (`hotel_geometry.gd:539`, `:566-577`). Su UV es el de un cubo unitario.
- Sustituto de horneado: UV a cero (`stand_in_mesh.gd:17-19`).
- `MeshHalves` copia UV y tangentes (`mesh_halves.gd:26-29`, `:86`).
- Recorte de pintura: `uv1_scale` y `uv1_offset` según la proporción (`hotel_geometry.gd:2679-2685`).

---

## 11. Tramos, hilos y tiempos

### 11.1 Construcción por tramos

- `build()` espera un fotograma (`await get_tree().process_frame`) al cambiar de planta (`hotel_geometry.gd:1066-1068`) y otro antes de la navegación (`:1168`). Motivo del comentario: una ventana sin responder cinco segundos (`:1043-1046`).
- Mientras se construye: `building = true` y `visible = false` (`:1056`, `:1052`). `update_part()` no hace nada (`:2989`).
- Vestimenta por tramos de pared: `wall_stretches()` (`hotel_geometry.gd:2796`) llama a `room_dressing.gd:136-168`.
- Muros por tramos: `wall_run` (`:1977-1990`), con el dado en paneles por tramo (`dado_panels`, `hotel_geometry.gd:249-262`) y un enchufe en tramos de 4 m o más.
- Pasillos en tramos rectos: `corridor_runs()` y `run_on()` (`:2436-2517`).
- Navegación: una región por planta, `Navigation_<planta>` (`:2836-2846`).

### 11.2 Horneado en hilos

- `bounce_light.gd:102`: `WorkerThreadPool.add_group_task(bake, jobs, workers, ...)`. Cada trabajo hornea un volumen (`:106-120`).
- El sustituto es una `Mesh` que no llega al GPU (`stand_in_mesh.gd:1-6`), para que el hilo no espere al principal (comentario `bounce_light.gd:32-38`).
- `Engine.print_error_messages = false` durante el horneado (`:98`, restaurado en `:145`).
- `poll()` cada fotograma (`hotel_geometry.gd:2623`) y `finish()` al final (`bounce_light.gd:130-162`).
- Una planta a la vez (`hotel_geometry.gd:2372-2373`). `release(planta)` libera las demás (`:2375`, `bounce_light.gd:165-173`).
- `_exit_tree()` espera al horneado (`hotel_geometry.gd:2532-2533`).

En el hilo principal: preparar grupos y sustitutos (`stand_in_colours`, `bounce_light.gd:260-269`), crear los `VoxelGI` definitivos al terminar (`finish`, `bounce_light.gd:136-162`), las texturas, la navegación (`NavigationServer3D.bake_from_source_geometry_data`, `hotel_geometry.gd:2840`), las luces y los MultiMesh.

### 11.3 Visibilidad por rondas

- `update_visibility()` (`hotel_geometry.gd:2970-2971`) se reparte en `ROUND_PARTS = 3` (`:2981`), una parte por fotograma: habitaciones y puertas; sondas; luces, sconces y bounce (`:2988-2997`, `:3000-3154`).
- El comentario dice que el conjunto costaba unos 2 ms y se hacía cuatro veces por segundo (`:2976-2978`).
- Solo se dibuja la planta del ojo (`put_away`, `:3257-3270`); `shown_planta` cambia al cambiar de planta.
- Radio de dibujo: `preset.room_reach` (`:2993`). Luces: `min(fade_end + 2, reach − omni_range − 2)` (`:3044-3045`).
- Puertas: dentro de `reach` (`:3065`). Prácticas: dentro de `furniture_lamps` (`:3140`). Señales de salida: `EXIT_REACH` (`:3147`).
- Sconces: 12 con sombra a 24 m, 40 m sin sombra (`:3123-3136`).
- Pasillos y coches: siempre con sombra si hay sombras y no hay capas estáticas (`:3152-3154`).

### 11.4 Animaciones

- Luces parpadeantes: en `_process` (`:2628-2656`); comentario: los fallos son pequeños y ocasionales.
- Reloj: `tell_time` y `turn_hands`, sin animación por fotograma (`:701-712`).
- Cortina: `curtain_material.motion` según `reduced` (`:3008-3011`).
- Polvo: partículas CPU de 10 s de vida, caja de emisión (6, 1.2, 6) (`:3272-3298`, `:3013`).

---

## 12. Vestimenta de habitaciones (`room_dressing.gd`)

### 12.1 Qué se decide por habitación

- Sin vestimenta: refugio (`REFUGE`) y vestíbulo de ascensor (`landing`) (`room_dressing.gd:194`).
- Juego por módulo (`MODULE_SET`, `hotel_palette.gd:219`): ver tabla 12.2.
- Pasillo de menos de 5 m en su lado menor: juego `passage` (`room_dressing.gd:199`).
- Selección de pieza en cada tramo: `sets[int(vary(seed_pos, 31) × tamaño)]` (`:209`).
- Estado: `kept` (0 cuidada, 1 descuidada, 2 abandonada) decide basura y decales (`:195`, `:300-318`, `:346-347`).

### 12.2 Juegos por módulo

| Módulo (tipo) | Juego | Piezas (orden) |
|---|---|---|
| 0 recepción, 5 salón, 10 vestíbulo, 14 sala de TV | lounge | console, armchair, commode, plant, bookcase, armchair, "" (`room_dressing.gd:33`). |
| 1, 2, 3 habitaciones y suite | bedroom | commode, armchair, chair, luggage, "", commode (`:32`). |
| 4 baño | bath | bins, "", chairs (`:39`). |
| 6 comedor | dining | console, chairs, cabinet, chairs, "" (`:35`). |
| 7 lavandería | laundry | rack, baskets, boxes, bins, "" (`:37`). |
| 8, 9 almacén y mantenimiento | service | steel, rack, boxes, bins, steel, "" (`:36`). |
| 11, 12 pasillo y galería | corridor | console, chairs, bins, plant, armchair, "" (`:40`). |
| 13 sala de lectura | reading | bookcase, bookcase, armchair, console, "" (`:34`). |
| 15 oficina | office | drawers, steel, chairs, boxes, "" (`:38`). |
| 16 guardarropa | wardrobe | luggage, rack, luggage, "" (`:44`). |
| 17 sala de plantas | garden | plant, plant, armchair, "" (`:42`). |
| 18 salón vacío | empty | boxes, chairs, cabinet, "", "" (`:43`). |
| 19 refugio, 20 vacío | ninguno | sin piezas. |

Cada tramo elige una pieza del juego. Un "" deja el tramo libre.

Pasillo corto (`passage`): console, bins, plant, "", "" (`:41`).

Alcobas de vivienda (`DOMESTIC` [1, 2, 3, 4, 7, 15, 16], `hotel_palette.gd:178`): en cada esquina, un muro de 3.2 m, dos tabiques de 0.8 m y uno de 1.6 m, todos de 0.12 m de grueso (`hotel_geometry.gd:1313-1329`); `layout` quita esquinas (`:1317-1319`).

### 12.3 Tramos de pared

- `stretches()` (`room_dressing.gd:136-168`): una pared del tipo `[lado, dentro, distancia, longitud]`. Solo si la longitud es al menos `far × 2 + 1` (7.1 m con `FAR = 3.05`) (`:148`).
- Dos tramos por pared, a ±2.2 m del centro: `(NEAR + far) × 0.5` (`:153`).
- Anchura del tramo: `far − NEAR` = 1.7 m (`:167`). `NEAR = 1.35` (`:26`), `FAR = 3.05` (`:27`), `FAR_DOMESTIC = 2.6` (`:28`).
- Se descarta el tramo si hay un hueco a menos de `NEAR` (`:160`), si hay armario a menos de `half + WARDROBE_HALF` (`:161-163`, `WARDROBE_HALF = 0.75` en `:51`) o si la pared está abierta (`:148`).
- Separación del muro: `INSET = 0.2` (`:20`), más `LIFT_DEPTH − 0.09` si la pared es la del ascensor (`:165`).

### 12.4 Piezas (`furnish`, `room_dressing.gd:241-345`)

| Pieza | Modelo | Escala | Colisión y notas |
|---|---|---|---|
| commode | GothicCommode_01 | min(1, ancho/1.25) | Sólida. Nota en cajón central (`commode_note`). Espejo a 1.62 m (`:249`). |
| console | ClassicConsole_01 | min(0.85, ancho/1.6) | Sólida. Nota sobre la tapa (`note_fold`). Espejo a 1.45 m. |
| armchair | ArmChair_01 o GreenChair_01 | 1 | Sólida, con mesa lateral `side_table_tall_01`. |
| chair | dining_chair_02 | 1 | Sólida. Mesa lateral con 50 %. |
| chairs | dining_chair_02 × 2 | 1 | Sólidas, en x = ±0.28. |
| luggage | vintage_suitcase_a, vintage_suitcase_b | 1 | La segunda tumbada y abierta: contiene la nota. |
| plant | potted_plant_02 o monstera | 1 | Caja de 0.5 × 0.54 × 0.5 m. |
| bookcase | wooden_bookshelf_worn | min(0.9, ancho/1.4) | Estantes llenos con libros y cajas. Nota en balda. |
| cabinet | vintage_cabinet_01 (kept 0) o painted_wooden_cabinet (kept 1 o 2) | min(0.82, ancho/2.1) con kept 0; min(1, ancho/1.25) en el resto | Con kept 0, armario de vidrio y nota sobre el mostrador. La rama de GothicCommode_01 no se alcanza. |
| drawers | drawer_cabinet | min(1, ancho/1.2) | Nota en el tercer cajón. |
| steel | steel_frame_shelves_01 | 1 | Estantes llenos con `STORE_THINGS`. |
| rack | worn_metal_rack | 1 | Igual que steel. |
| boxes | cardboard_box_01, plastic_crate_02 | 1 | Pila de 3 + kept, hasta 0.5 m. |
| baskets | wicker_basket_02 × 2, bleach_bottle | 1.3 | Sin colisión. |
| bins | metal_trash_can_rust o _clean | 0.6 | Sólido. Con 50 % `WetFloorSign_01`; si kept >= 1, `trashbag`. |
| (defecto) | vintage_grandfather_clock_01 o litter | 1 | Reloj en `CLOCK_ROOMS` si kept = 0 y probabilidad (0.3). Basura si kept >= 1. |

Piezas por encima del juego: reloj de pared a (0.2, 2.05) con probabilidad 0.3, solo en tramos vacíos, silla, sillón o sillas (`room_dressing.gd:349-350`); alarma de incendios en el primer tramo de `ALARM_ROOMS` [0, 10, 11, 12] con probabilidad 0.6, a 1.22 m (`:225-227`); caja de fusibles en `FUSE_ROOMS` [7, 8, 9, 15] con probabilidad 0.4, a (−0.45, 1.25), solo en tramos vacíos, cajas, cubos o cestas (`:354-356`, `:361-366`).

Ventiladores de techo en `FAN_ROOMS` [6, 13, 15] (`:230-236`), dos, a ±0.25 del lado mayor.

Relojes de pie en `CLOCK_ROOMS` [1, 2, 3, 5, 6, 13, 14] (`:345`).

Basura (`litter`, `:527-547`): `1 + kept × 2` objetos. Probabilidades: silla volcada (0.2, solo kept 2), botella (0.5), papel (0.7), caja (0.85), cajetilla (resto).

Pila de cajas (`stack`, `:463-494`): `3 + kept` cajas, hasta x = 0.5 m, la nota va sobre la caja más alta, con preferencia por la de cartón.

Techo (`hotel_geometry.gd:225-239`): un detector de humo siempre y, en `SPRINKLER_ROOMS` [0, 5, 6, 10, 11, 12, 13, 14] (`hotel_palette.gd:205`), un rociador. Las esquinas van al 17 % del lado, con tope de 2.2 m.

### 12.5 Decales (`decals`, `room_dressing.gd:553-618`)

- Cantidad: `[4, 9, 16][kept]` (`:560`).
- Tipos: humedad de techo (`Leaking001/003/005`), manchas de la pared (`Leaking008/009`), huellas de mano junto a la puerta (`Fingerprints002/004`), suciedad (`SurfaceImperfections001/013/017`), `Smear003` en salas `SMEAR_ROOMS` [4, 7, 8, 9], chicle en salas públicas, huellas `Footsteps003` en salas abandonadas.
- Proyección de la decal: 0.3 m en suelo y 0.5 m en pared; tamaño 1.2 a 2.6 m en suelo (`:575-576`, `:598`).

### 12.6 Ubicación de la nota del código

- Papel en `hotel_container`: `note_spot` con `at`, `yaw`, `skew`, `lie`, `hang`, `lie_tilt`, `hang_tilt`, `model`, `piece`. Lo genera la vestimenta (`note_fold`, `room_dressing.gd:522-523`).
- Tamaño de la hoja 0.16 × 0.21 × 0.003 m (`hotel_container.gd:317-318`).

---

## 13. Clases y nodos Godot

Número de apariciones en `game/world/hotel/` y `game/world/interactables/` (grep, cuenta todas las menciones, incluidos comentarios; orientativo):

| Clase | Apariciones | Dónde se usa |
|---|---|---|
| Node3D | 101 | Todo el árbol. |
| MeshInstance3D | 53 | Modelos, puertas, papeles, placas. |
| Mesh (base) | 53 | Parámetros y mallas. |
| GeometryInstance3D | 42 | Ajustes de sombra y GI. |
| OmniLight3D | 24 | Lámparas de techo, pared, mueble, baliza, salida, cabina. |
| CollisionShape3D | 21 | Colisionadores de caja. |
| StandardMaterial3D | 20 | Materiales de papel, vidrio, cuadros. |
| BoxShape3D | 15 | Colisionadores. |
| Tween | 14 | Puertas, cajones, armarios, paneles. |
| ArrayMesh | 14 | Molduras, hojas de armario, tope de puerta, marco tallado. |
| VoxelGI | 12 | Luz rebotada. |
| RenderingServer | 12 | `instance_set_visible`, `get_rendering_device`, método de render. |
| MultiMesh | 12 | Lotes de cajas y de modelos. |
| Light3D (base) | 12 | Tipos de lámpara. |
| BaseMaterial3D | 12 | Emisión de materiales. |
| Area3D | 12 | Objetos interactivos (8 archivos). |
| BoxMesh | 11 | Cajas unitarias, tiras, tapas. |
| SurfaceTool | 8 | Mitades, tope, hojas. |
| StaticBody3D | 8 | Cuerpos sólidos, puertas, armarios. |
| ShaderMaterial | 8 | Shaders de madera, salida, pantalla. |
| QuadMesh | 5 | Cuadros, salida, cristal, papel. |
| ReflectionProbe | 4 | Sondas. |
| NavigationMesh | 4 | Malla de navegación. |
| WorkerThreadPool | 3 | Horneado. |
| ResourceLoader | 3 | `exists()` de escaneos y modelos. |
| PlaneMesh | 3 | Hojas de papel. |
| MultiMeshInstance3D | 3 | Relojes, cortinas, lotes de piezas abiertas. |
| ImageTexture | 3 | Perfiles fotométricos. |
| FileAccess | 3 | Lite y pinturas. |
| Decal | 3 | Decales. |
| CharacterBody3D | 3 | Armario (ocupantes). |
| CPUParticles3D | 3 | Polvo. |
| SpotLight3D | 2 | Foco del televisor. |
| PhysicsShapeQueryParameters3D | 2 | Comprobación de cuerpos en puerta y salida. |
| NavigationServer3D | 2 | Horneado de navegación. |
| Label3D | 2 | Números de puerta, dígitos de ascensor, textos. |
| JSON | 2 | `lite.json`, `paintings.json`. |
| Image | 2 | Perfiles fotométricos. |
| FogVolume | 2 | Niebla de salón. |
| CylinderMesh | 2 | Cilindros de unidad, tirador. |
| SphereMesh | 1 | Lente de baliza. |
| OccluderInstance3D | 1 | Oclusor. |
| ArrayOccluder3D | 1 | Oclusor. |
| NavigationRegion3D | 1 | Región por planta. |
| NavigationMeshSourceGeometryData3D | 1 | Fuente de navegación. |
| FogMaterial | 1 | Niebla. |
| CapsuleShape3D | 1 | Salida del armario. |
| AudioStreamPlayer3D | 1 | Ruido del televisor (campo `burst`). |
| Geometry2D | 1 | Triangulación de molduras. |
| Callable | 1 | Parámetro `unit_mesh` (`bounce_light.gd:84`). |
| RefCounted | 8 | Base de clases de datos. |

Otros usos de Godot sin contar: `Engine.print_error_messages` (`bounce_light.gd:98`, `:145`), `OS.get_processor_count()` (`:100`), `Time.get_ticks_msec` (solo en un comentario, `hotel_television.gd:56`), `get_tree().node_added` (`hotel_geometry.gd:2286`), `FogMaterial`, `Decal`, `ShaderMaterial` y `get_world_3d().direct_space_state` (`hotel_door.gd:110`, `hiding_place.gd:447`).

Las lecturas de recursos son `preload` en tiempo de compilación (por ejemplo `hotel_geometry.gd:286-296`) y `load()` síncrono en `scan_maps` y `lite_map` (`:490`, `:478`).

---

## 14. Constantes que definen cómo se ve y se siente

| Constante | Valor | Ruta:línea | Qué gobierna |
|---|---|---|---|
| KIT_NEAR | 16 m | hotel_geometry.gd:158 | Distancia de la moldura detallada. |
| KIT_FAR | 26 m | hotel_geometry.gd:159 | Distancia desde la que se ve la pieza plana. |
| KIT_OVERLAP | 1.0 m | hotel_geometry.gd:163 | Solape entre piezas detallada y plana. |
| KIT_MARGIN | 0.5 m | hotel_geometry.gd:164 | Margen de transición. |
| LIT_DRAIN | 0.9 | hotel_geometry.gd:102 | Umbral de habitación a oscuras. |
| EXIT_REACH | 14 m | hotel_geometry.gd:124 | Alcance de la señal de salida. |
| LAMP_SIZE | 0.12 | hotel_geometry.gd:304 | Tamaño de fuente (penumbra). |
| PRACTICAL_SIZE | 0.2 | hotel_geometry.gd:305 | Ídem, muebles. |
| SCONCE_SIZE | 0.05 | hotel_geometry.gd:306 | Ídem, pared. |
| SCONCE_REACH | 24 m | hotel_geometry.gd:311 | Alcance con sombra. |
| SCONCES_LIT | 12 | hotel_geometry.gd:323 | Lámparas de pared con sombra. |
| SCONCE_FILL_REACH | 40 m | hotel_geometry.gd:332 | Alcance sin sombra. |
| SCONCE_ENERGY | 1.6 | hotel_geometry.gd:333 | Energía de pared. |
| SCONCE_FILL_ENERGY | 0.7 | hotel_geometry.gd:334 | Factor de relleno. |
| BEACON_GLOW | 9.0 | hotel_geometry.gd:1454 | Emisión de la baliza. |
| PAINTING_CLEAR | 2.2 m | hotel_geometry.gd:1176 | Distancia mínima cuadro-hueco. |
| NUMBER_REACH | 20 m | hotel_geometry.gd:392 | Alcance de números de puerta. |
| PROBES_SHOWN / PROBES_KEPT | 24 / 32 | hotel_geometry.gd:388-389 | Sondas de reflexión. |
| SHADOW_MODEL | 0.6 m | hotel_geometry.gd:719 | Altura mínima para proyectar sombra. |
| SMALL_MODEL | 0.3 m | hotel_geometry.gd:720 | Altura de modelo pequeño. |
| SMALL_REACH | 16 m | hotel_geometry.gd:721 | Alcance de modelo pequeño. |
| MODEL_LIFT | 0.002 m | hotel_geometry.gd:726 | Elevación de modelos sobre su base. |
| JAMB_GAP | 0.01 m | hotel_geometry.gd:729 | Separación del muro a la jamba. |
| DECAL_REACH | 14 m | hotel_geometry.gd:799 | Distancia de decales (fundido de 4 m). |
| UNTOLD | 02:50 (10 200 s) | hotel_geometry.gd:691 | Hora de los relojes sin dato. |
| CHANDELIER_SCALE | 1.5 | hotel_geometry.gd:287 | Escala del candelabro. |
| SEAL_DEPTH | 0.04 m | hotel_geometry.gd:893 | Grosor del sello de puerta. |
| OPENING_HIGH | 2.65 m | hotel_geometry.gd:896 | Altura del hueco. |
| FLOOR_ISLAND | 0.35 m | hotel_geometry.gd:2852 | Altura máxima para que una pieza de navegación sea suelo. |
| FLOOR_PIECE | 0.1 | hotel_geometry.gd:2855 | Tamaño mínimo de pieza frente a la mayor. |
| ROUND_PARTS | 3 | hotel_geometry.gd:2981 | Partes de la ronda de visibilidad. |
| CANVAS | 1.14 × 0.78 m | hotel_geometry.gd:2663 | Lienzo de cuadro. |
| GRILLE | 0.42 × 0.22 m | hotel_geometry.gd:271 | Rejilla de ventilación. |
| PARTITION_FACE | 0.06 m | hotel_geometry.gd:208 | Cara de tabique. |
| ROOM_LAYERS.COUNT | 16 | room_layers.gd:29 | Capas de render. |
| LATE_REACH | 8 m | room_layers.gd:35 | Vecindad de lámpara. |
| CAR_REACH | 5.5 m | room_layers.gd:40 | Alcance de la lámpara de cabina. |
| PROFILE_GAIN | 1.25 | lighting.gd:23 | Ganancia de perfiles. |
| INCANDESCENT / FLUORESCENT | 2700 K / 4100 K | lighting.gd:26-27 | Temperaturas. |
| CAMERA_WHITE | 3200 K | lighting.gd:33 | Balance de cámara. |
| SKIP (horneado) | light, shade, tube | bounce_light.gd:45 | Materiales que no entran al horneado. |
| SHOWN | 8 | bounce_light.gd:47 | Volúmenes visibles. |
| BIG_SIDE | 20 m | bounce_light.gd:48 | Lado a partir del que sube la subdivisión. |
| EDGE | 0.3 m | bounce_light.gd:50 | Borde de volumen. |
| PANEL_WIDTH / FOOT / HEAD | 0.6 / 0.12 / 0.955 m | mouldings.gd:40-42 | Dado de paneles. |
| PANEL_FRAME | 0.16 m | mouldings.gd:44 | Cara del marco de panel. |
| SMOOTH | 0.8 | mouldings.gd:23 | Umbral de normal suave en molduras. |
| UNIT | 0.1 m | mouldings.gd:20 | Longitud de tramo de moldura. |
| ROSE_TURNS | 48 | mouldings.gd:197 | Segmentos del rosetón. |
| NEAR / FAR / FAR_DOMESTIC | 1.35 / 3.05 / 2.6 m | room_dressing.gd:26-28 | Franja libre de muro. |
| INSET | 0.2 m | room_dressing.gd:20 | Separación del muro. |
| WALL_FACE | −0.11 m | room_dressing.gd:23 | Cara del yeso para colgar. |
| WARDROBE_HALF | 0.75 m | room_dressing.gd:51 | Medio ancho de armario. |
| ON_TOP | 0.002 m | room_dressing.gd:427 | Separación sobre base. |
| DRAWER_TILT | 0.2 rad | room_dressing.gd:498 | Inclinación de nota en cajón. |
| WIDTH / HEIGHT / DEPTH (armario) | 1.25 / 2.3 / 0.78 m | hiding_place.gd:23-25 | Armario pequeño. |
| BIG_SIZE | 2.2 × 2.45 × 0.9 m | hiding_place.gd:28 | Armario grande. |
| OPEN_ANGLE / PEEK_ANGLE / EASE_ANGLE | 1.75 / 0.75 / 1.3 rad | hiding_place.gd:40-42 | Ángulos de hoja. |
| COLLISION_LIMIT | 0.25 rad | hiding_place.gd:62 | Umbral de hoja sólida. |
| OPEN_TURN | 1.48 rad | hotel_door.gd:6 | Giro de puerta. |
| SLOW_SWING / SWING / FORCEFUL_SWING | 1.5 / 0.55 / 0.32 s | hotel_door.gd:56-58 | Tiempos de puerta. |
| DRAWER_OUT | 0.5 | hotel_container.gd:134 | Cajón fuera. |
| DOOR_OPEN / LID_OPEN | 1.1 / 1.45 rad | hotel_container.gd:135, :137 | Puerta y tapa. |
| TOPPLE / SET_DOWN / SHOVE / SET_TURN | 0.3 s / 0.4 / 0.2 / 0.5 | hotel_container.gd:144-147 | Objetos movidos. |
| SEARCH_DB / SEARCH_CREAK_DB / SEARCH_PAPER_DB | −20 / −10 / −24 dB | hotel_container.gd:88-90 | Volumen de la búsqueda. |
| SHEET | 0.16 × 0.21 m | hotel_container.gd:317 | Tamaño de la nota. |
| BRIGHTNESS / OPEN_TIME | 1.1 / 0.4 s | hotel_television.gd:42-43 | Pantalla al encender. |
| RANGE / CONE / TILT / ENERGY | 8 m / 55° / −0.3 / 2.2 | hotel_television.gd:34-37 | Foco del televisor. |
| FILL_RANGE / FILL | 4.5 m / 0.5 | hotel_television.gd:38-39 | Relleno del televisor. |
| OPEN / SWING / REACH (panel) | 1.75 rad / 0.7 s / 0.35 m | hotel_panel.gd:14-16 | Caja de fusibles. |
| KEYS | 4 | hotel_lock.gd:6 | Dígitos del teclado. |
| CARD / POLAROID | 0.09 × 0.225 / 0.088 × 0.107 m | hotel_hint.gd:14-15 | Tamaños de pistas. |
| FORM_SHEET | 0.2 × 0.3 m | hotel_document.gd:16 | Formulario. |
| LEAF_WIDTH / PORTAL / LIFT_DEPTH / PITCH | 1.2 / 1.3 / 2.34 m / 6.0 m | floor_definition.gd:25-67 (grep) | Medidas del piso. |
| HEIGHTS / HALL_HEIGHT | 4.2, 3.15 / 4.8 m | hotel_palette.gd:108-109 (grep) | Altura de habitación. |
| CHANDELIER_HEIGHT | 4.0 m | hotel_palette.gd:215 (grep) | Umbral del candelabro. |
| WARDROBES | {1:2, 2:2, 3:2, 16:2, 13:1, 14:1, 15:1, 8:1} | hotel_palette.gd:69 (grep) | Armarios por tipo. |

Colores principales: incandescente 2700 K, fluorescente 4100 K con tinte (0.92, 1.0, 0.9) (`lighting.gd:29`), salida (0.25, 1.0, 0.45) (`hotel_geometry.gd:1902`), baliza (1.0, 0.1, 0.06) (`:1489`), cabina (0.96, 0.94, 0.86) (`:1843`), televisor (0.72, 0.82, 1.0) (`hotel_television.gd:33`), niebla de salón `81775f` (`hotel_geometry.gd:1201`), polvo (0.8, 0.73, 0.55, 0.22) (`:3291`).

---

## 15. Orden de ejecución, física, azar y señales

### 15.1 Orden

- `build()` es una secuencia con dos esperas de fotograma (`hotel_geometry.gd:1066-1068`, `:1168`). Un piso se oculta mientras se construye.
- El orden de las puertas importa por índice: los índices de puerta son los que usa la red (`:1161-1162`, comentario). Las puertas de fase se construyen al final para mantener el orden de las fases (`:1098-1100`, `:1161-1163`).
- Los armarios se numeran por orden de construcción: el mismo índice es el mismo armario en cada máquina (`hiding_place` y `hotel_geometry.gd:56-57`, comentario).
- `lights[id]` es la lámpara de la habitación `id`; el orden de `lights` debe respetarse (`hotel_geometry.gd:1076`).
- `assign_layers()` va después de `flush()` (`:1166-1167`) y las capas no se cambian mientras Godot tiene la pareja geometría-luz emparejada (`room_layers.gd:42-53`).
- `late_arrival()` cuelga de `get_tree().node_added` y usa `call_deferred` (`hotel_geometry.gd:2285-2290`).
- `set_kit()` y `apply_quality()` se pueden llamar con el piso ya construido (`:2572-2620`).

### 15.2 Física

- Puertas: `_physics_process` solo corre en movimiento o en `GHOST` (`hotel_door.gd:116-121`). Una puerta deja de ser sólida mientras se mueve; al parar pasa a `SOLID` o `OPEN_SOLID` según quede alguien dentro (`:103-110`, `:121`).
- Armario: `_physics_process` solo cuenta el tiempo de cierre (`hiding_place.gd:426-435`).
- `hiding_place.gd:313-320`: el tope `plug` se desactiva en el mismo fotograma en que entra alguien.
- Comprobación de salida: `PhysicsShapeQueryParameters3D` con cápsula 0.3 × 1.05 m y máscara `1|8|4|32` (`hiding_place.gd:437-448`).
### 15.3 Azar

- No hay `RandomNumberGenerator` ni `randi()` ni `randf()` en estas carpetas (grep: cero apariciones).
- Todo lo que se ve viene de `vary(position, salt)` (`hotel_geometry.gd:503-504`):
  `fposmod(sin(x × 12.9898 + z × 78.233 + y × 37.719 + salt × 11.31 + looks) × 43758.5453, 1.0)`.
- `looks` sale de `hash([seed, "looks"])` (`:494-495`, `:1059`). El comentario dice que no consume el azar del generador (`:499-501`).
- Las piezas, las pistas, la basura y los decales dependen de `vary()` (`room_dressing.gd`, `hotel_geometry.gd`).
- `hotel_container.pick()` usa `hash(Vector3i(global_position × 100))` (`hotel_container.gd:169`) ; el mismo resultado en cada máquina.
- El azar de la estructura viene de `decoration.randi_range` en el generador (`map_generator.gd:1729-1730`), fuera de estas carpetas.

### 15.4 Señales

| Señal | Archivo:línea | Nota |
|---|---|---|
| `noise(point, radius, kind)` | hotel_door.gd:7 | Consumidor no leído. Radio desde `game/audio/noise_kinds.gd` (no leído). |
| `sound_requested(opening, slow, point, emitter, forceful)` | hotel_door.gd:8 | Consumidor no leído; el comentario cita `world_audio.door_cue` (`hotel_door.gd:74-76`). |
| `swung(target, slow, forceful)` | hotel_door.gd:11 | El comentario dice que el host la retransmite (`hotel_door.gd:9-10`). |
| `settled(opened)` | hotel_door.gd:12 | Puerta en estado final. |
| `peek_started(point)` | hiding_place.gd:68 | Armario, al asomarse. |
| `forced` | hiding_place.gd:70 | Se emite al forzar el armario (`force_open`, `hiding_place.gd:369-374`). |
| `searched_changed` | hotel_container.gd:11 | Consumidor no leído. |
| `switched(on)` | hotel_television.gd:14 | Consumidor no leído. |

### 15.5 Hilos

- Horneado de luz rebotada en `WorkerThreadPool` (`bounce_light.gd:102-103`), sin tocar nodos del árbol en los hilos (`bounce_light.gd:32-38`, `:105-120`).
- La espera en `finish()` es bloqueante (`bounce_light.gd:139`).
- Navegación: horneada en el hilo principal durante `build()` (`hotel_geometry.gd:2840`). No comprobado si Godot la paraleliza por dentro.

---

## 16. Pruebas que vigilan esta parte

Lista de archivos de `tests/` que nombran algún símbolo de estas carpetas (grep). No se leyeron los tests.

| Test | Símbolos que toca |
|---|---|
| tests/hotel/hotel_test.gd (723 líneas) | hotel_geometry, room_layers, bounce, SCONCES_LIT, stretches, hotel_door. |
| tests/hotel/stages_test.gd (847) | searched, blackout, hotel_container, lighting, prop_factory, dressing. Comprueba el doblez de la nota contra la malla (comentario `room_dressing.gd:519-520`). |
| tests/hotel/creature_contract_test.gd (2079) | searched, hiding_place, stretches, blackout. |
| tests/hotel/room_light_test.gd (218) | blackout, room_light, room_layers. |
| tests/hotel/palette_scan_test.gd (302) | room_dressing, prop_factory, hotel_geometry. |
| tests/hotel/loop_test.gd (293) | hotel_geometry, hotel_document, searched. |
| tests/hotel/scene_contract_test.gd (339) | hotel_geometry. |
| tests/hotel/sanity_test.gd (323) | hotel_door. |
| tests/hotel/spatial_audio_test.gd (361) | blackout, hotel_door. |
| tests/hotel/survival_test.gd (691) | hotel_door, hiding_place. |
| tests/hotel/continue_test.gd (202) | searched, hiding_place. |
| tests/hotel/capture_test.gd (801) | hiding_place. |
| tests/hotel/objectives_test.gd (208) | blackout, searched. |
| tests/hotel/rules_test.gd (185) | blackout. |
| tests/hotel/echo_test.gd (504) | stretches, blackout. |
| tests/hotel/creature_test.gd (164) | searched. |
| tests/hotel/difficulty_test.gd (445) | searched. |
| tests/hotel/bots_test.gd (338) | searched, blackout. |
| tests/office/office_light_test.gd (747) | bounce, blackout, room_layers, lighting, stand_in_mesh, hotel_geometry, bounce_light. |
| tests/office/office_pieces_test.gd (270) | prop_factory, bounce. |
| tests/office/lurker_shell_test.gd (947) | hotel_geometry. |

Según `CLAUDE.md` del proyecto, el piso 1 (el hotel) lo vigilan `manifest_golden_test` y `creature_contract_test` («El piso 1 (el hotel) no cambia salvo que el encargo lo diga»). `manifest_golden_test.gd` no nombra estas carpetas, porque prueba el generador.

Herramientas que miden esta parte (grep, no leídas): `tools/dev/light_leak.gd`, `tools/dev/light_layers_scan.gd`, `tools/dev/zfight_scan.gd`, `tools/dev/leak_who.gd`, `tools/dev/hearing_probe.gd`, `tools/props/build_catalogue.gd`, `tools/props/build_door.gd`, `tools/props/build_wardrobe.gd`, `tools/props/build_elevator.gd`, `tools/lighting/measure_albedo.gd`, `tools/bots/*.gd`.

---

## 17. Consumidores de esta parte (grep, no leídos)

Archivos fuera de estas carpetas que llaman a `hotel_geometry`, `room_dressing`, `prop_factory` o a los interactables: `game/app/hotel_main.gd`, `game/app/floor_map.gd`, `game/app/code_lock.gd`, `game/app/interaction.gd`, `game/app/observer_view.gd`, `game/app/phantom_sight.gd`, `game/enemies/locust/echo_view.gd`, `game/enemies/lurker/lurker_shell.gd`, `game/floors/hotel_floor.gd`, `game/floors/objectives/files_objective.gd`, `game/floors/objectives/objective.gd`, `game/world/generation/document_placement.gd`, `game/world/generation/hint_placement.gd`, `game/world/generation/floor_definition.gd`, `game/intro/intro_sequence.gd`, `game/title/title_scene.gd`, `game/presentation/graphics_presets.gd`.

Fuera de `game/app/`: `SEARCH_TIME` lo usa `game/app/interaction.gd`; `LEAVE_TIME` y `QUIET_*` los usan `game/player/hotel_player.gd` y `game/audio/noise_kinds.gd`; `UNTIMED_OPEN` y `DOOR_SWING` los usa `game/app/code_lock.gd` (grep).

---

## 18. Contradicciones dentro del código

- Tamaño del piso: `bounce_light.gd:28` dice «about 5 s for a floor of 121 rooms», mientras que `hotel_geometry.gd:3196-3197` dice «571 rooms, 369 doors and 624 wall lamps on seed 81» para tres plantas. Los dos comentarios son de épocas distintas. Por el código, el número depende del seed.
- Planta: `hotel_geometry.gd:2358-2359` dice «a planta is some 140 lit rooms», compatible con 571 / 3 ≈ 190 habitaciones por planta; no se ha medido.

---

## 19. Sin comprobar

- Ni se ejecutó el piso ni se midieron nodos, mallas, luces ni tiempos. Las cifras de los comentarios (seed 81) no se han repetido.
- No se leyeron: `game/presentation/graphics_presets.gd` (solo se conocen sus claves por el código: `penumbra`, `lamp_fade`, `room_reach`, `furniture_lamps`, `decals`, `probes`, `bounce`, `sconce_lights`, `sconce_fill`, `lamps_cast`, `static_light`, `detail_kit`, `surface_detail`, `small_maps`, `dust`, `glazed_art`, `floor_haze`, `lamp_fog`); los valores de cada preset son desconocidos.
- `game/world/generation/floor_definition.gd` (solo constantes y las funciones `planta_of`, `size_of`, `position_of`, `is_void`, `lift_wall`, `hiding_positions`, `doorways` por grep); `portal_between`, `leaf_yaw`, `leaf_turn`, `door_offset`, `beside`, `palette()` no se leyeron.
- `game/floors/palettes/hotel_palette.gd`: solo constantes y funciones `lamp_of`, `wall_material`, `floor_finish`, `domestic`, `height_of`, `numbered`. El resto no se leyó (`RECIPES`, `DECKS`, `WALL_KINDS` y otras).
- `game/world/generation/exit_route_signs.gd` (`ROUTE_SIGN.place`), `game/world/generation/map_generator.gd` (solo 1720-1733).
- Shaders y materiales: `game/presentation/shaders/wood.gdshader`, `wood_lacquer.gdshader`, `exit_panel.gdshader`, `game/intro/tv_screen.gdshader`, `surface.gdshaderinc`, y los `.tres` de `game/presentation/materials/`.
- Recursos `.res` de `assets/props/`: sus metas (`pivot`, `box`, `parts`, `hands`, `casts`, `slit`, `hinge`) no se leyeron; solo se conocen por su uso en el código.
- `game/audio/noise_kinds.gd` (radios de `NOISE.radius`).
- `tools/props/build_catalogue.gd`, `build_door.gd`, `build_wardrobe.gd`, `build_elevator.gd`, `build_model_props.gd`.
- Documentación citada en comentarios (`docs/REALISM.md`, `docs/PERFORMANCE.md` sección 10, `docs/OFICINAS.md`, `spec_f1_geometry.md`): no leída.
- Comportamiento de Godot 4.7 que el código supone (horneado de `VoxelGI` en hilos, capas emparejadas, `NavigationServer3D.bake_from_source_geometry_data` en hilo principal, `Decal` y su coste con Forward+, `hash()` de arrays): viene de comentarios del propio código. No se contrastó con `.claude/godot-api/`.
- Los 19 `.uid` no se leyeron.
- Los consumidores del apartado 17 solo se conocen por grep, no se leyeron.
- El código compara el método de render con las cadenas `forward_plus` y `gl_compatibility` (`hotel_geometry.gd:803`, `:1195`, `hotel_television.gd:114`). El método `mobile` no aparece en estos archivos y no se comprobó su comportamiento.
- No se comprobó el uso de `ENTER_TIME`, `QUIET_EXIT` y otras constantes fuera de estas carpetas; sus usos se conocen por grep.
- `palette.RECIPES`, `palette.DECKS` y demás tablas de la paleta del hotel no se leyeron.
- Las funciones `FLOOR.hiding_positions()`, `FLOOR.doorways()` y `FLOOR.leaf_yaw()` no se leyeron; su contrato (qué devuelven exactamente) queda por confirmar.
