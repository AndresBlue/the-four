# Ficha de hechos: geo_oficinas (piso 2, oficinas de 1987)

Propósito: dar al diseño del port a Unreal hechos exactos de cómo Godot construye hoy la geometría, la luz, las puertas, las sondas y el polvo del piso 2. Solo hechos. No contiene propuestas de diseño de Unreal.

Método: lectura completa de los 28 archivos `.gd` de `game/world/office/` (9.688 líneas, 16 en `pieces/`), de `.claude/specs/visual_vuelta_grande.md` (118 líneas), y de cuatro cruces con código fuera de la carpeta: `game/world/hotel/hotel_geometry.gd` (503-504, 525-528, 530-531, 590-607, 735-756), `game/floors/palettes/office_palette.gd` (280, 1003, 1006), `evidence/bench/piso2_dens6_final_forward_plus/report.json`. Las referencias son `ruta:línea` desde la raíz del repo. Lo no leído va en «Sin comprobar».

Estado del código: la versión leída es la de la vuelta grande (commits citados en el spec), en el HEAD `e50a862` del momento de la lectura (14 de noviembre de 2026).

---

## 1. Inventario de archivos leídos

Archivos de primer nivel de `game/world/office/` (12):

| Archivo | Líneas | Qué hace |
|---|---|---|
| office_geometry.gd | 2841 | Orquestador del piso. Hereda de `hotel_geometry.gd`. Luz (troneras, rebote, sondas, focos), falso techo, paredes, puertas, cristales y persianas, columnas, cabina del montacargas, polvo, unidades de emergencia, persianas de archivo, aire y niebla. |
| office_landmarks.gd | 630 | Salas de hito (ventanilla, cuarto eléctrico, seguridad, sala de máquinas, vestíbulo del montacargas): dintel con bandera, luces de puerta, cartel de seguridad, directorio y señales de dirección. |
| office_props.gd | 759 | Piezas de esquina (`room.props`), muebles (`room.furniture`), mostrador de recepción, butacas de espera, lavabos, microfichas, filas de archivo. |
| office_clutter.gd | 424 | Lo que queda tirado: sillas caídas o giradas, cajón abierto, cables, papeles en el suelo, cajas volcadas. Reglas de ruta (`clear_of_route`). |
| office_walls.gd | 392 | Lo que cuelga de las paredes por tipo de sala (cuadros, carteles, pizarras, tablero de directorio, cuadro eléctrico, extintor, detector). |
| office_fittings.gd | 295 | Falso techo: detector, rociador, difusores sobre losetas libres. Alfombras, alicatado de aseos, cortinas del despacho. |
| office_models.gd | 299 | Tabla `MODELS` (64 clases, rutas a `.res`), `LIGHTS` (4 lámparas de mueble), `FRONTED`, `CAST_LEAST`, `stand_in()` (respaldo en código). |
| office_pictures.gd | 174 | Cuadros, planos y diplomas: imágenes de `assets/paintings/office/` o dibujos procedurales de respaldo. |
| main_duct_geometry.gd | 318 | Conducto principal de la planta 3, escalera de planta, pozo con escalera, cráneo y restos. Cajas con colisión. |
| office_bounce.gd | 126 | Volúmenes VoxelGI de rebote con los colores propios de oficina; alcance y recortes. |
| scissor_gate.gd | 64 | Reja plegable del montacargas de carga (malla de celosía en un `MultiMeshInstance3D`). |
| office_accents.gd | 31 | Contador de luces de acento por sala (máximo 3, `MOST`). |

Subcarpeta `pieces/` (16 archivos, 3.335 líneas): `index.gd` (26; lista de familias), `room_equipment.gd` (34), `movables.gd` (140), `fixtures.gd` (125), `stationery.gd` (132), `cabinets.gd` (194), `storage.gd` (224), `desks.gd` (314), `desk_things.gd` (228), `kit.gd` (421; constructor común de todas las piezas), `machines.gd` (180), `air_equipment.gd` (161), `power_equipment.gd` (182), `mail_equipment.gd` (222), `stand_ins.gd` (490), `wall.gd` (262).

Además: 27 archivos `.uid` (no hay `office_landmarks.gd.uid`), sin mayor interés para el port.

Spec leído: `.claude/specs/visual_vuelta_grande.md` (118 líneas): estado, decisiones del autor, críticas de imagen, luz, polvo, hitos, «No entró» (118 líneas en total, secciones en las líneas 5-22, 24-35, 37-54, 56-75, 77-84, 86-97, 99-102, 104-117).

Cruces leídos: `hotel_geometry.gd` 503-504 (`vary`), 525-528, 530-531 (`box`), 590-607 (`flush`), 735-756 (`place`); `office_palette.gd` 280-285, 1003, 1006-1021; `report.json` completo.

---

## 2. Cómo se convierte el modelo en geometría

Tres vías, todas en Godot:

**a) Mallas por código (la mayoría de piezas).** `pieces/kit.gd` construye un `ArrayMesh` con una superficie por clave de material (`finish()`, `kit.gd:399-421`). Las primitivas son cajas biseladas (`block`, `kit.gd:92-133`), cilindros (`cylinder`, `kit.gd:143-153`), triángulos y cuadrados (`tri`, `quad`, `kit.gd:72-89`) y trazos planos (`stroke`, `kit.gd:173-178`). Las piezas se cachean por builder y por clave de tamaño (`cached`, `key_of`, `kit.gd:31-39`). Metadatos que lee el resto del código: `size`, `collider` (o `colliders`), `solid`, `wall`, `mount`, `picture`, `text_plate`, `light_strip`, `casts`, `lift` (`kit.gd:399-421`, `wall.gd` 24-262, `desks.gd` 252, 292).

**b) Modelos importados (`.res`).** `office_models.gd:21-130` (`MODELS`) asocia cada clase con una o varias rutas bajo `assets/props/office/` y `assets/props/hotel/` (escala, `height`, `seat`, `pot`). `mesh_of()` carga con `load()` y cachea (`office_models.gd:160-168`). Si el archivo no existe, pasa al siguiente o al `stand_in()` de código (`office_models.gd:245-281`). `fit_of()` escala (altura o `scale`) y da media vuelta a los asientos con la espalda en -Z (`office_models.gd:217-224`, detección en `backed()` 228-241). Las tres tablas de respaldo son `pieces/stand_ins.gd`, `desk_things.gd`, `machines.gd`, `stationery.gd`, `wall.gd`, `mail_equipment.gd`, `air_equipment.gd`, `power_equipment.gd`, `room_equipment.gd`.

**c) Mallas cargadas a mano en código** (sin `.res` de por medio):
- Columnas: `BoxMesh` por columna y parte (`office_geometry.gd:954-963`).
- Hoja de puerta de respaldo: `door_leaf_mesh()` con `SurfaceTool` y `BoxMesh` (`office_geometry.gd:2225-2267`).
- Marco de nogal: `door_frame_mesh()` con `KIT.block` (`office_geometry.gd:2273-2293`).
- Conducto, escalera, pozo y cráneo: `MainDuct` con `SurfaceTool` por material (`main_duct_geometry.gd:296-308`). El cráneo es un `.obj` con albedo, normal y rugosidad PNG (`main_duct_geometry.gd:258-278`, `SKULL_SCALE` 0,073, `SKULL_FLOOR` 1,783).
- Lente de tubos: `lens_texture()` genera una `Image` de 4×64 (`office_geometry.gd:537-550`).
- Rayas de peligro: `Image` de 128×14 con `QuadMesh` (`office_landmarks.gd:382-395`).
- Motas de polvo: `QuadMesh` con sombreador, en un `MultiMeshInstance3D` (`office_geometry.gd:1325-1353`).

**Colocación y lotes (hotel).** Toda pieza pasa por `builder.place(parent, mesh, xform, casts, material, only_kit)` (`hotel_geometry.gd:735-756`). Se agrupa por padre y por (malla, `casts`, material, `only_kit`) y se dibuja en un único `MultiMesh` por sala y malla al hacer `flush()` (`hotel_geometry.gd:590-607`). Si la sala es un lote registrado (`batch_roots`), el `MultiMesh` lleva `use_custom_data` con los datos de sala (`hotel_geometry.gd:598-606`). Las cajas (`box`) van al mismo lote por material (`hotel_geometry.gd:530-531`; `office_geometry.gd:470-472` fuerza el material de cristal de tubos cuando `glass_of_tubes` está puesto). Los objetos con `hands` (relojes) tienen mallas propias (`hotel_geometry.gd:750-755`).

**Mallas de texto.** `Label3D` en todas partes: letreros y dinteles (`office_landmarks.gd:285-299`, `label()`), placas de número (`office_geometry.gd:2137`), placas de zona (`office_geometry.gd:1524`), placas de pared (`office_walls.gd:360-376`, `plate_text`), directorio (`office_landmarks.gd:573-619`), mostrador (`office_props.gd:641-658`). Tipografía: `FontVariation` con `variation_embolden` 0,7 y `variation_transform` 0,78 (`office_landmarks.gd:317-326`). Tamaño de píxel del texto 0,0015 m (`office_landmarks.gd:26`, `office_walls.gd:61`, `office_props.gd:637`). `visibility_range_end` de 14 m (letreros de zona, `office_landmarks.gd:84`), 20 m (placas de pared y de número, `office_walls.gd:69`, `office_props.gd:638`) y 32 m (banderolas, `office_landmarks.gd:83`).

---

## 3. Colisiones

- El hotel crea colisionadores de caja, uno por caja sólida, dentro de un cuerpo por sala (`hotel_geometry.gd:525-528`, comentario sobre `solids`). La oficina no cambia esto: `box(..., solid=true)` (`office_geometry.gd:328`, `office_geometry.gd:334`, `office_props.gd:174-175`).
- `piece()` coloca cajas de colisión por cada `colliders` de la malla o por la caja `collider` (`office_props.gd:620-626`). `solid` falso no crea colisionador (`kit.gd:399-421`, `office_props.gd:623`).
- Falso techo: colisionador de una caja sobre las losetas (`office_geometry.gd:334`). Losetas caídas o colgantes sin colisionador (`office_geometry.gd:425-427`, la tapa colgante usa `box(..., false)`).
- Muebles de cabina y mostrador: colisionadores de caja (`office_props.gd:174-175`, `office_props.gd:669`, `office_props.gd:684-685`).
- Conducto principal: `StaticBody3D` «MainDuctBody» con `collision_layer` 1 y `collision_mask` 0 (`main_duct_geometry.gd:120-124`). Cada caja del conducto tiene `CollisionShape3D` + `BoxShape3D` (`main_duct_geometry.gd:287-293`). Las cajas de la losa de salida del pozo son colisionables (`main_duct_geometry.gd:221`).
- Reja del montacargas de carga: sin colisión (`scissor_gate.gd:5`). El hotel no tiene colisión en sus cabinas de puerta.
- Cabina del montacargas: suelo y techo de acero (`office_geometry.gd:1710-1711`). Paneles, pasamanos y postes sin colisión: `box()` tiene `solid` en falso por defecto (`hotel_geometry.gd:530`; `office_geometry.gd:1716-1722`).
- Navegación: radio de agente 0,3 m (`office_geometry.gd:2431`).
- Asientos: `chair()` pone un colisionador de caja de 0,44×0,46×0,42 (`office_props.gd:685`).

---

## 4. Puertas

- Selección de hoja (`office_geometry.gd:2211-2215`): `service` (acero) si `service_door(a, b)` (`office_geometry.gd:2205-2206`: almacén, depósito, eléctrico, sala de aire, planta de aire, o etapa de montacargas); si no, `vision` con probabilidad `VISION` 0,35 (`office_geometry.gd:106`, `vary` sal 172) o `plain`.
- Modelos de puerta: `DOOR_MODELS` (`office_geometry.gd:2198`): `puerta_oficina_sousinho_leaf.res`, `puerta_lisa_sousinho_leaf.res`, `puerta_metal_tboiston_leaf.res`. Marco de acero `puerta_metal_tboiston_frame.res` (`office_geometry.gd:2199`).
- Respaldo en código: `door_leaf_mesh(steel, vision)` (`office_geometry.gd:2225-2267`): caja de hoja, panel de ventanilla de 0,15×0,6 m a 1,2 m de altura (`office_geometry.gd:2228`), manilla o barra antipánico a 1,0 m (`office_geometry.gd:2246`, `2248-2254`), tercera superficie de cristal `clear_glass` (`office_geometry.gd:2259-2266`).
- Marco: `door_frame_mesh()` de nogal, con `JAMB_WIDE` 0,09 m (`office_geometry.gd:101`), `JAMB_PROUD` 0,02 (`:102`), `SOFFIT_DROP` 0,004 (`:104`). Vale también el de acero si el marco de acero existe (`frame_mesh`, `office_geometry.gd:2217-2220`).
- Umbral: franja de metal de `FLOOR.PORTAL` por 0,006 m (`office_geometry.gd:105`, `office_geometry.gd:2123-2125`). `FLOOR.PORTAL` no está leído (ver Sin comprobar).
- Placa de número: `PLAQUE` 0,26×0,09 m a `PLAQUE_Y` 1,55 m, fondo 0,019 (`office_geometry.gd:90-100`), ancho por letra `PLAQUE_LETTER` 0,065 y margen 0,06 (`office_geometry.gd:92-93`). Texto `Label3D` con alcance 20 (`office_geometry.gd:2137`).
- Interruptor: placa de 0,08×0,12 a `SWITCH_Y` 1,15 m (`office_geometry.gd:107`, `1905-1909`).
- Dintel y cartel de puerta de hito: cartel de 0,42×0,30 m a `SIGN_Y` 1,6 (`office_landmarks.gd:52-54`); dintel con bandera de 0,62×0,28 (`office_landmarks.gd:78-81`).
- Cámara sobre la puerta de tarjeta del puesto de seguridad (`office_landmarks.gd:183-190`).
- Marco de puerta: `KIT.finish` con `solid: false`, o sea sin colisión propia (`office_geometry.gd:2293`).

---

## 5. Luces de techo

**Troneras (luminarias del falso techo).**
- Forma: marco de 1,2×0,6 m o 0,6×1,2 m (`office_geometry.gd:391`), con cuerpo de 0,11 m (`TROFFER_BODY`, `office_geometry.gd:118`). Cuatro familias en `troffer_face()` (`office_geometry.gd:481-514`): «narrow» (lente estrecha 0,28 m, lamas cada 0,1 m, `NARROW_LENS` y `LOUVRE_PITCH`), «parabolic» (rejilla de cuatro celdas, `PARABOLIC_PITCH` 0,19), «wrap» (difusor envolvente hasta `WRAP_DROP` 0,09 m), y la lente plana por defecto. La familia la da `OFFICE.troffer_look(room)`.
- Lente: material `troffer_lens_<kelvin>` con emisión de la temperatura de la sala, `LENS_GLOW` 4,0, textura de emisión `lens_texture()` y modo `EMISSION_OP_MULTIPLY` (`office_geometry.gd:432-450`). Color base `LENS_ALBEDO` #e6e2d8 (`office_geometry.gd:154`), oscurecido a 0 en `LENS_LIT_DARK` 1,0 (`:157`).
- Lente apagada: `lens_off` = `LENS_ALBEDO` × 0,55 (`office_geometry.gd:293`).
- Lente reflejada en sondas: `LENS_MIRRORED` 15 (`office_geometry.gd:240`), en capa 2 (`PROBE_ONLY`, `office_geometry.gd:241`).
- Halo: `HALO_REACH` 1,8 m (`office_geometry.gd:172`), `HALO_BELOW` 0,002 (`:173`), `HALO_ENERGY` 0,22 (`:174`). Malla de losa con sombreador `ceiling_halo.gdshader`, `energy` de 0 a `HALO_ENERGY` × energía del foco (`office_geometry.gd:2466-2482`, `set_halo`). Se recorta a la losa de la sala y a las celdas abiertas (`open_to()`, `office_geometry.gd:636-644`).
- Luz de la sala: `LAMP_ENERGY` 2,3 (`office_geometry.gd:126`), perfil `LAMP_PROFILE` «even» (`:132`), colgada `LAMP_DROP` 0,9 m bajo el techo (`:135`), atenuación de `OmniLight3D` 1,25 con pozos o 0,9 sin ellos (`:141-142`). Especular 0 (`LAMP_SPECULAR`, `:151`).
- Rebote y pozos por pantalla: dos `SpotLight3D` por tronera en `pool_pair()` (`office_geometry.gd:672-678`, `684-729`):
  - «Pool»: `POOL_ENERGY` 3,0 (`:195`), ángulo 75° (`:197`), alcance 7 m (`:199`), caída `POOL_FALL` 1,0 (`:198`), tamaño de penumbra `POOL_SIZE` 0,6 (`office_geometry.gd:2569`), sombra solo en las 32 más cercanas (`POOLS_CAST` 32, `:2567`; `POOL_KEEP` 1,0, `:2568`), sesgo 0,04 y normal 0,6 (`:699-700`), sin volumétrico (`:696`).
  - «Bounce»: a 0,1 m del suelo (`BOUNCE_FROM`, `:739`), cono de 90° (`BOUNCE_ANGLE`, `:740`), alcance altura + 3,0 (`BOUNCE_REACH`, `:741`), atenuación 0,5, `BAKE_DYNAMIC` (entra en el VoxelGI), sin sombra (`:710-727`). Energía `energy × share` con `share = BOUNCE_SHARE × mean / (1 − mean)` (`office_geometry.gd:750`, `bounce_of()` 756-763). `FLOOR_SHARE` 0,25 (`:748`), `ROOM_REFLECT` 0,32 (`:749`), `RECEPTION_BOUNCE` 0,5 (`:659`).
- Modo de visibilidad: los pozos solo se muestran con `pools_shown()` (`office_geometry.gd:2533-2534`): iluminación por capas de sala (`layered`), `static_light` apagado, y no Compatibility.
- Atenuación de salas concretas: recepción 0,9 (`RECEPTION_DIM`, `office_geometry.gd:649`), ventanilla 0,7 (`WINDOW_DIM`, `:662`).
- Fallo de tubo (una lámpara de la sala parpadea): `flicker_one()` (`office_geometry.gd:1666-1693`) con temporizador de escena (`get_tree().create_timer`, `:1692`) y fin en `end_flicker()` (`:1695-1698`). Probabilidad `FAILING` 0,12 por sala (`:145`, sal 160).

**Regletas (battens) de la planta.** `lamp_fixture()` devuelve un tubo «batten» (`office_geometry.gd:1931-1943`). `batten_lights()` (`:2042-2063`) crea tres focos: «Batten» con `BATTEN_DOWN` {energía 4,0, ángulo 85, penumbra 1,4, desenfoque 3,0} (`:2038`); el rebote del mismo par con `spot_attenuation` `BATTEN_BOUNCE_FALL` 2,0 (`:2041`); y «BattenUp» hacia el techo, {energía 3,0, ángulo 88, alcance 4,0} (`BATTEN_UP`, `:2039`), desde 0,35 m bajo el techo (`BATTEN_UP_FROM`, `:2040`). Altura de tubos `BATTEN_TUBES` 0,14 (`:2037`). El modelo de regleta es `mounted_fluorescent_lights_batten.res` (`office_geometry.gd:2068`), con la superficie de cristal marcada como `glow_surface` (`:2077`).

**Regletas de archivo:** `archive_battens()` (`office_geometry.gd:1954-1990`): una por pasillo (`archives[].aisles`) o cuatro en archivo móvil. Focos `BATTEN_CAST` {2,2; 62°; 6 m} con sombra si son de la sala, o `BATTEN_AISLE` {1,4; 34°; 4,5 m} sin sombra (`:1997-1998`, `batten_spot` 1999-2020).

**Luces de acento** (≤3 por sala, `office_accents.gd:6`; recepción 7, `office_geometry.gd:1757`):
- `accent_spot()` (`office_geometry.gd:2626-2651`): `SpotLight3D` «AccentSpot», `light_size` = `ACCENT_SIZE` (0,08) × penumbra del preset (`:2637`), especular 0 en recepción y 0,3 en otras (`:2639`), distancia de caída `distance_fade`.
- `accent_strip()` (`office_geometry.gd:2656-2676`): `AreaLight3D` (la franja de recepción), sin sombra.
- `accent_sconce()` (`office_geometry.gd:2709-2733`): aplique de pared con cristal propio; `BOX_LAMP_OUT` 0,16 m (`:1764`), `BOX_LAMP_FALL` 0,9 (`:1765`), perfil `box_sconce` (`:2725`).
- Luz de mueble: `LIGHTS` (`office_models.gd:147-152`) para `desk_lamp_banker`, `desk_lamp_arm`, `floor_lamp` y `vending`, con `LIT_MOST` 1 por sala (`office_models.gd:142`). Pasa por `accent_spot()` (`office_models.gd:284-299`).
- Lámparas de mostrador: `front_desk()` tiene tres focos `accent_spot` de 3,6 de energía, 2,7 de alcance y 32° (`office_props.gd:451`), una franja `accent_strip` de energía `STRIP_ENERGY` 10 (`office_props.gd:458`, `:418`), y `mirror_ghost` de `STRIP_MIRRORED` 60 (`office_props.gd:460`).

**Luces de emergencia:** un `SpotLight3D` «EmergencyLight» por unidad (`office_geometry.gd:1170-1187`): energía `EMERGENCY_ENERGY` 1,4, alcance 9, ángulo 55°, `EMERGENCY_KELVIN` 2400, sombra activa con sesgo 0,04. Solo en salas de paso (LANDING, LOBBY, CORRIDOR, GALLERY, ELECTRICAL, `office_geometry.gd:1114-1116`) y en plantas con energía. Número de sombras: `EMERGENCY_CAST` 6 (3 en Compatibility), `EMERGENCY_REACH` 18 m (`:1095-1096`). Cuando la sala no tiene luz, la lente pasa a emisión de `emergency_on()` (`:1212-1219`, emisión × 3,0).

**Hitos:** `door_light()` (`office_landmarks.gd:213-227`): dos `SpotLight3D` por dintel, «LandmarkDoorHalo» (energía `LAMP_ENERGY` 0,7 en `office_landmarks.gd:71`, alcance 2,8, ángulo 38°, niebla `LANDMARK_AIR` 6 en `office_geometry.gd:1289`) y «LandmarkDoorWash» (energía `wash` del tipo de sala, alcance 3,2, ángulo 46°, sin niebla). Ambas `shadow_enabled` falso y `BAKE_DISABLED` (`:222-223`). Lámpara de objeto `object_lamp()` (`office_landmarks.gd:244-264`): `SpotLight3D` «LandmarkLamp» (`FOCAL_ENERGY` 3,5, `FOCAL_REACH` 3,0, `FOCAL_ANGLE` 28°, `:90-92`), con sombra solo cuando el ojo está en su sala (`round_landmarks()`, `office_geometry.gd:1291-1301`).

**Salidas de emergencia:** `exit_sign()` pone `EXIT_ENERGY` 0,1 y `EXIT_RANGE` 1,2 m (`office_geometry.gd:2312-2323`).

**Lámpara de ventanilla:** `WINDOW_LAMP_ENERGY` 7,0, ángulo 34°, giro 1,29 rad (`office_geometry.gd:1069-1071`).

**Niebla volumétrica por luz** (`light_volumetric_fog_energy`), en `air_lights()` (`office_geometry.gd:1270-1281`): emergencias `EMERGENCY_AIR` 3,0 (`:1265`), acentos `ACCENT_AIR` 1,5 (`:1266`), carteles de salida `EXIT_AIR` 4,0 (`:1267`), focos de pantalla `POOL_AIR` 0,12 (`:1268`) y lámparas de sala `LAMP_AIR` 0,25 (`:1269`), con 0 para las que dan luz por sus luminarias (`lit_by_fittings()`). Cada uno solo entra en la niebla si da sombra (`air()`, `office_geometry.gd:1303-1305`).

**Cuándo se bake y cuándo no:** `lit_by_fittings()` (`office_geometry.gd:2545-2546`) decide que la lámpara de la sala no alumbra ni da sombra ni va al volumen de rebote (`light_bake_mode = BAKE_DISABLED`, `apply_quality()` `:2827`). Sin esa condición la lámpara pasa a `BAKE_DYNAMIC`.

---

## 6. Reflejos de suelo con sondas

- Sonda por sala: `make_probe()` (`office_geometry.gd:2505-2528`): la superficie del suelo (`Mesh_<floor_look>`) y la de acero de recepción (`Mesh_reception_steel`) reciben la capa 8 (`FLOOR_LAYER`, `:232`). Alcance `PROBE_PAST` 0,05 m (`:228`) sobre la altura de la sala. `reflection_mask` = 8 (`:2510`). Intensidad `PROBE_INTENSITY` 1,0 (`:231`); en recepción `RECEPTION_PROBE` 6,0 (`:1773`) y posición a `PROBE_EYE` 2,0 m (`:1775`, `:2517`). Actualización por pasos de `PROBE_STEP` 0,05 (`:2486`, `probe_strength()` 2487-2492).
- Las sondas se crean solo mientras la sala está encendida (comentario en `office_geometry.gd:2503-2504`, `round_probes()` del hotel) y se hacen en la lista `probe_slots` (`office_geometry.gd:2341-2344`).
- Fantasmas de lente: `lens_ghosts()` (`office_geometry.gd:606-630`): quad bajo cada lente, emisión `LENS_MIRRORED` 15, en capa 2 (`PROBE_ONLY`), sin sombra.
- Fantasmas de cristal y de aplique: `mirror_ghost()` (`office_geometry.gd:2681-2698`): quad en capa 2 con emisión.
- Motivo declarado en el código: una sonda capturaba una tronera como ruido blanco sobre laca si no iba en capa propia (`office_geometry.gd:223-227`, `:233-237`).

---

## 7. Catálogo de piezas (`pieces/`)

Cada familia crea mallas con `KIT.block`/`cylinder`/`stroke`. Tamaños de muestra en `samples()` de cada archivo. Resumen:

- **desks.gd (314):** escritorio de nogal (1,6×0,75×0,8), L de laminado (1,6×0,74×1,4) y L de nogal (1,8×0,75×1,5), escritorio de acero (1,5×0,75×0,75), escritorio de seguridad (3,0×0,87×0,8, dos pedestales), mesa de juntas (3,6×0,75×1,2), mesa de comedor (1,2×0,74×0,8), mesa de clasificación (2,0×1,02×0,9), mesa de consulta (1,4×0,74×0,7), mostrador de recepción (2,4×1,1×1,5) y su versión `front_desk` (3,4×1,08×1,0, `FRONT_LEDGE` 0,4, `FRONT_WORK` 0,74, `desks.gd:221-222`), mesa baja (0,9×0,42×0,5).
- **cabinets.gd (194):** archivador metálico de 2 o 4 cajones (0,47×1,32×0,62), fichero de tarjetas (1,2×1,0×0,5), aparador de nogal (1,8×0,8×0,48), librería (0,9×2,0×0,35 o 1,0×2,2×0,4), casillero de correo `pigeonholes` (1,8×1,9×0,4), mostrador de buzón `pigeon_counter` (2,4×1,1×0,8).
- **storage.gd (224):** estantería de archivo de acero (2,0×2,1×0,4; cinco baldas y archivo en las caras), archivo móvil (3,0×2,1×0,8; los carriles los pone `PROPS.row()`), estantería de madera (1,2×1,8×0,4), rifle (1,0×1,9×0,45), bases y alacenas de cocina (1,8×1,2×0,6 con fregadero; 1,2×0,9×0,6; alacena 1,8×0,7×0,35).
- **machines.gd (180):** fotocopiadora (1,1×1,05×0,7), impresora matricial (0,6×0,25×0,42), torre de ordenador (0,2×0,45×0,45), CRT (0,4×0,4×0,42 o negro 0,38×0,36×0,4), teclado (0,46×0,035×0,17), calculadora (0,2×0,09×0,26), proyector de transparencias (0,4×0,8×0,45).
- **movables.gd (140):** carro de dos baldas (0,8×0,9×0,5), carro cargado (0,8×1,0×0,5), carro postal, pizarra móvil (1,5×1,9×0,6), mampara (1,6×1,2 o 1,5 de alto, 0,06 de grosor), banco de listones (1,5×0,45×0,4).
- **stationery.gd (132):** carpetas de anillas (0,4×0,32×0,29), carpetas de cartón, caja de archivo (0,33×0,25×0,39), libros, resmas de papel, bandejas (de plástico o de alambre, 0,26×0,07×0,34), registro (0,5×0,03×0,35).
- **desk_things.gd (228):** teléfono (0,22×0,1×0,24, con o sin descolgar), taza, cenicero (0,14), portalápices (0,08×0,16×0,08), papeles sueltos (0,9×0,7 m), cable (1,2×0,3), cajón sacado (0,42×0,27×0,36), alfombra persa (3,0×2,0), lector de microfichas (0,45×0,55×0,5).
- **wall.gd (262):** placa de señal (0,3×0,1×0,01), marco con fondo (0,6×0,8 y 0,5×0,4), reloj cuadrado (0,3), directorio de fieltro (0,9×0,7×0,05), tablón de anuncios (1,2×0,9×0,03, con hasta 20 hojas), armario de llaves, espejo (0,6×0,8×0,03), perchero de ganchos (1,2×0,34), persiana enrollable (1,8×1,6×0,1).
- **air_equipment.gd (161):** unidad de aire AH-1 (3,0×2,2×1,5), ventilador (rotor 0,68), volante (0,36), caja de control (0,3×0,4×0,15), consola de seguridad (1,6×0,45×0,42).
- **power_equipment.gd (182):** cuadro eléctrico de 5 zonas (2,6×2,4×0,2), conductos del cuadro, palancas (0,05×0,26×0,05 y la roja 0,07×0,34×0,07), caja de suministro (0,6×0,75×0,16), interruptor de temporizador (0,1×0,14×0,05).
- **mail_equipment.gd (222):** central neumática (0,56×1,15×0,2, con tubos de latón), receptor de estación (0,36×0,5×0,16), máquina de escribir (0,46×0,3×0,38), lector de tarjetas (0,2×0,28×0,09), collar de tubo, lente de piloto, mapa de red (0,9×0,62×0,025), placa de instrucciones.
- **fixtures.gd (125):** cubículos de aseo (2,7×2,0×1,5, tres cabinas), aplique de caja (0,13×0,32×0,09), alfombras (`rug`, `mat_rib`, `black`, `carpet_exec`), cortina de terciopelo (1,4×2,1×0,12), persiana de lamas (1,2×1,0×0,04; lamas de 0,025 m giradas 0,35 rad).
- **room_equipment.gd (34):** bloque de taquillas (2,7×1,9×0,45, seis puertas, con candado).
- **stand_ins.gd (490):** sillas de oficina (0,6×0,95×0,6), sillón de dirección de cuero (0,68×1,15×0,66), silla de visita de nogal (0,56×0,88×0,56), lámparas de mesa (banquero y brazo), máquina expendedora (0,9×1,8×0,8, con 36 casillas), enfriador de agua, nevera, microondas, globo, extintor, lámpara de trabajo, escalera de tijera, maceta y planta de respaldo, fuente de pared, abrigo y toalla.
- **kit.gd (421):** utilidades comunes: caja biselada, cilindro, `front` (frente de cajón con tirador), `handle`, `knob`, `label`, `sheets`, `book_row`, `box_row`, `binder_row`, `file_row`, `post_pile`, y `hash01` (azar fijo por posición, ver §12).

Los materiales por clave vienen de `game/presentation/materials/office/<clave>.tres` (`kit.gd:13`, `kit.gd:45-56`), y los que no existen caen en `push_error` y usan `metal` (`kit.gd:50-51`).

---

## 8. Hitos (office_landmarks.gd)

- Tipos: `window` (ventanilla de personal, banderola «PERSONAL / VENTANILLA»), `electrical` (cuarto eléctrico, amarillo), `security` (seguridad, rojo), `machines` (sala de máquinas, rojo), `lift` (vestíbulo del montacargas, sin banderola ni lámpara; `office_landmarks.gd:34-40`). Los vestíbulos del montacargas de las plantas 1 y 2 son de tipo REFUGE.
- Clave del hito por manifiesto: `mail.window`, `power.room`, `air.security.room`, `air.room`/`air.plant`, `refuges` (`office_landmarks.gd:106-115`). Tabla de objetivos por planta: `targets()` (`office_landmarks.gd:423-430`).
- Carteles de puerta (`SIGNS`, `office_landmarks.gd:45-50`) con cuatro estilos. Cartel de 0,42×0,30 m (`SIGN`), cabecera 34%.
- Banderola: `BANNER` (0,022×0,28×0,62 m, `office_landmarks.gd:78`), a `BANNER_Y` 2,34 m (`:80`), alcance de lectura 32 m (`BANNER_REACH`, `:83`).
- Bulto sobre la puerta: caja `BULKHEAD` (0,24×0,13×0,09, `:67`), `LAMP_Y` 2,84 m (`:68`), por encima del marco a 2,74 y bajo el falso techo a 2,95 (comentario `office_landmarks.gd:65-66`).
- Señales de dirección colgadas: `WAY` (1,0×0,2×0,02 m), `WAY_Y` 2,25 (`:99-100`), `WAYS_MOST` 4 por planta (`:101`), con reparto por ruta más corta (`ways()`, `office_landmarks.gd:467-505`, BFS con `tree_from()` `:434-446`).
- Directorio de llegada: tablero de 0,9×0,7 m con nogal y fieltro negro (`board_mesh`, `office_landmarks.gd:622-630`), líneas `LINE_MOST` 0,056 m (`:103`), flechas `arrow_mesh` (`:557-564`).

---

## 9. Polvo y haces (aire de la planta)

- Niebla de la planta (`office_geometry.gd:203-218`): `AIR_DENSITY` [0,008; 0,02; 0,02] por planta (`:210`); planta 1 queda en 0,008, plantas 2 y 3 en 0,02. `AIR_ANISOTROPY` 0,6 (`:211`). Linterna en la niebla `TORCH_AIR` 3,0 (`:212`). `grade()` (`:213-218`) devuelve el diccionario de gradación con `fog_density`, `fog_anisotropy` y `torch_fog`. `GRADE` (`:203`): clave 0,05, blanco (1,2; 1,0; 1,15), contraste 1,16, saturación 0,85, `ssao_light` 0,35.
- Motas (`build_dust()`, `office_geometry.gd:1325-1353`): `MOTES_BOX` 4,0 m (`:1319`), `MOTES_PER_DUST` 14 (`:1320`), `MOTES_MOST` 140 (`:1321`), así 1.960 instancias en un único `MultiMesh` con identidades (`:1340`). Semilla `RandomNumberGenerator` 6113 (`:1327-1328`) solo para el alfa de cada mota (`:1344`). Forma de mota en `MOTE_LOOK` (`:1323`): `wrap` 4,0, `speck` (0,003; 0,008), `min_pixels` 2, `bokeh` 10, `focus` 1, `twinkle` 0,5, `scatter` 3,0. Sombreador `ceiling_dust.gdshader` (en `lurker`, no leído).
- Visibilidad (`round_rooms()`, `office_geometry.gd:1359-1366`): solo si `preset.dust > 0`, sin efectos reducidos, sin eco, y si la sala del ojo es vacía o no está encendida (`:1363`). El número visible es `min(dust, MOTES_MOST) × MOTES_PER_DUST` (`:1365`).
- `preset.lamp_fog` decide si una luz entra en la niebla (`air()`, `:1304`).
- El informe de banco (`report.json`) no separa el coste de las motas del resto; ver §10.

---

## 10. Nodos, mallas y luces

**Lo que hay medido (un solo piso):** `evidence/bench/piso2_dens6_final_forward_plus/report.json`: piso 2, semilla 7, 413 salas, `node_count` 26.358, renderer Forward+, GPU NVIDIA RTX 4060 Ti, viewport 1920×1080, dificultad «apacible», `quality` 2 (la correspondencia con el preset «Alto» no está en el informe). Carga del piso 19.490 ms. Memoria (`memory`, en bytes): textura 2.160.108.544; vídeo 2.504.161.072.

| Vista | Dibujos | Primitivas | Dibujos de sombra | Fotograma medio / p95 (ms) | GPU medio (ms) |
|---|---|---|---|---|---|
| still_room142 | 303 | 223.447 | 3.772 | 14,9 / 25,0 | 12,7 |
| still_room23 | 158 | 267.872 | 2.860 | 12,4 / 25,7 | 10,4 |
| still_room0 | 72 | 148.600 | 299 | 7,7 / 9,2 | 7,3 |
| arrival | 229 | 230.719 | 1.701 | 13,7 / 33,5 | 9,6 |
| walk | 446 | 280.189 | 3.053 | 14,2 / 25,6 | 12,4 |

Notas del informe: las vistas fijas son cinco (`still_room*`), más `arrival` y `walk` (recorrido de 34 puntos, `walk_points` 34). Los sobresaltos vienen en `hitches` del propio informe, por ejemplo `over_33ms` 1 en `still_room142`. Memoria: textura 2.160 MB (unos 2,16 GB) y vídeo 2.504 MB (unos 2,5 GB), según `memory`.

**Por planta:** no hay cifras de nodos, mallas ni luces por planta en los archivos leídos. Lo que sí sale del código, por sala (fórmulas, sin medir):
- 1 `OmniLight3D` de sala por sala (`lights[id]`, `office_geometry.gd:2459`).
- Sala con tronera: 2 `SpotLight3D` por tronera (Pool y Bounce) (`office_geometry.gd:672-678`).
- Sala con regletas: 3 focos por sala (Batten, su rebote y BattenUp; `batten_lights()`, `office_geometry.gd:2042-2063`), y un foco por regleta de archivo (`archive_battens()`, `batten_spot()`).
- Acentos: máximo 3 por sala (`office_accents.gd:6`), recepción 7 (`office_geometry.gd:1757`).
- Luz de mueble: máximo 1 por sala (`office_models.gd:142`).
- Dintel de hito: 2 `SpotLight3D` (`office_landmarks.gd:208-209`), y 1 de objeto para el puesto de seguridad y el cuadro (`office_landmarks.gd:244-264`).
- Unidad de emergencia: 1 `SpotLight3D` (`office_geometry.gd:1170`).
- Sonda por sala con hueco de sonda (`probe_slots`): 1 `ReflectionProbe` mientras la sala está encendida (`office_geometry.gd:2341-2344`, `:2505-2528`).
- Volúmenes VoxelGI: uno por volumen de rebote (`office_bounce.gd:55-90`), número no determinado por el código leído.
- Mallas: una `MultiMeshInstance3D` por sala y grupo (malla, casts, material, kit), según `flush()` (`hotel_geometry.gd:590-607`). Número por sala no determinado.

**Conteo de clases y nodos en `game/world/office/`** (apariciones del texto, no instancias en ejecución): véase §16.

---

## 11. Espesores, alturas, UV y materiales

**Espesores y alturas (de código):**
- Tabique: pieza de muro de 0,18 m (`office_geometry.gd:1449`, `:1579-1580`, `wall_core(..., 0.18)`); caras a ±0,09 m del límite de celda (`office_geometry.gd:1452`, `:1469`, `:1481`; `office_palette.gd:1006` `WALL_HALF` 0,09). Este dato es el que usa el rebote para no pasarse (`office_bounce.gd:22-25`).
- Zócalo: 0,10 m alto y 0,006 m de grosor (`SKIRT`, `office_geometry.gd:45`).
- Friso de roble hasta 1,0 m con baranda de nogal (`FRIEZE_TOP`, `RAIL`, `office_geometry.gd:52-53`). Friso de grosor `DADO_THICK` 0,015 (`:56`).
- Dado de nogal hasta 1,05 m y tapa 0,04 × 0,02 (`DADO_TOP`, `DADO_CAP`, `:54-55`).
- Dos tonos hasta 1,2 m (`TWO_TONE_TOP`, `:57`), revestimiento `LINING` 0,004 (`:58`).
- Paneles de la secretaría hasta 9 m (`PANEL_TOP`, `office_walls.gd:50`).
- Altura de sala: la da el manifiesto (`room.height`). Valor de respaldo 2,95 m (`office_props.gd:519`). Falso techo a 2,95 y cabecera de puerta a 2,74 (`office_landmarks.gd:65-66`).
- Losa sin falso techo: caja de 0,2 m de grosor, de `h` a `h + 0,2` (`office_geometry.gd:328`).
- Suelo: caja de 0,3 m centrada en −0,15 m (`office_geometry.gd:2419`).
- Falso techo: losetas de 0,6 m (`OFFICE.TILE` 0,6, `office_palette.gd:1003`; `office_geometry.gd:318`). Grosor `TILE_THICK` 0,015 (`:115`), cara `TILE_FACE` 0,004 (`:116`), T de `TEE` (0,024×0,004×0,032, `:117`).
- Columnas: `OFFICE.COLUMN` 0,6 m (`office_palette.gd:280`), base 0,1 m (`COLUMN_BASE`), remate 0,08 (`COLUMN_CAP`), resalte 0,012 (`COLUMN_PROUD`) (`office_geometry.gd:122-125`).
- Vidrio: alféizar 0,95 m, dintel 2,65 m, parteluz cada 1,2 m (`MULLION_PITCH`), grueso 0,008 (`GLASS_THICK`), parteluz 0,05 (`office_geometry.gd:71-75`).
- Marco de puerta: 0,09 m de jamba (`JAMB_WIDE`, `office_geometry.gd:101`).
- Cartel de zona: alto 0,12 m y fondo 0,006 m (`SIGN_HIGH`, `SIGN_DEPTH`, `office_geometry.gd:63-64`).

**Materiales y UV:**
- Acabados de oficina: `STAND_INS` (`office_geometry.gd:10`) apunta cada acabado a un material del hotel si no hay propio (metal, light, wood, ceramic, fabric, leather, trim, carpet, etc.). Acabados lisos sin material propio: `PLAIN` (`office_geometry.gd:35`), por ejemplo `office_paint` #b9ad96, `vinyl_polished` #a99f88, `vinyl_hall` #857862, `block` #c7bfa5, `concrete` #807b72, `terrazzo` #5a5650, `slab` #7c7a74, con rugosidad 0,9 y metadato `stand_in`.
- Materiales propios de oficina: `res://game/presentation/materials/office/<clave>.tres` (`office_geometry.gd:39`, carga en `_init` `:285-291`). Solo se sobreescriben `carpet` y `ceiling_service` (`OWN_OVER`, `:40`) y `glow_strip` (`OWN_ONLY`, `:43`).
- Mapas: `apply_scan(material, small_maps)` (`office_geometry.gd:291`), metadato `lite` = `office/<clave>` para el modo «Muy bajo» (`:290`).
- Cuadros: `QuadMesh` de 1×1 con `uv1_scale` y `uv1_offset` según el recorte (`office_pictures.gd:52-61`), material con rugosidad 0,85 y color `AGED` (`office_pictures.gd:19`, `:53`).
- Alfombra de Met 452567 (dominio público): `res://assets/textures/office_rug_met452567/rug.tres`, `RUG_ASPECT` 1,355 (`office_fittings.gd:36-37`), en `PlaneMesh` (`office_fittings.gd:165-169`).
- Lente: `uv1_triplanar` = true y `uv1_offset` (0,5; 0,5; 0,5) (`office_geometry.gd:447-448`).
- Halo: UV desplazado al centro de su tronera (`ceiling_halo()` `office_geometry.gd:583`).
- Piezas hechas en código: `KIT.tri`, `quad`, `block` y `cylinder` solo fijan normal y vértice, no UV (`kit.gd:72-133`). Las texturas de esas piezas dependen de los `.tres` de cada material (no leídos: §Sin comprobar).
- Sombreadores propios: `wired_glass.gdshader` (cristal armado, `office_geometry.gd:88`), `venetian_blind.gdshader` (`:87`), `ceiling_halo.gdshader` (`:257`), `ceiling_dust.gdshader` (en `lurker`, `office_geometry.gd:1318`). `tile.gdshader`, `ceiling_tile.gdshader` y `surface.gdshaderinc` se citan en el spec (no leídos).
- Cristal: `clear_glass` con `wire` 0 y color (0,78; 0,8; 0,76; 0,12) (`office_geometry.gd:270-275`). Cristal armado como `ShaderMaterial` `wired_glass` (`:267-269`).
- Pantallas y cristales de tubos: rugosidad `SCREEN_ROUGHNESS` 0,3 (`office_geometry.gd:230`, `:296`).
- Emisión de lentes: `EMISSION_OP_MULTIPLY` (`office_geometry.gd:446`).

---

## 12. Orden, física y azar

**Azar.** Todo el azar de adorno es determinista por posición:
- `vary(value, salt)` en el hotel (`hotel_geometry.gd:503-504`): una función seno con `value.x`, `value.z`, `value.y`, `salt` y la variable `looks` (`hotel_geometry.gd:502`). La variable `looks` cambia el resultado según el juego y se fija a 0 en escenas de presentación (`hotel_geometry.gd:500-502`).
- `hash01(n, salt)` en `kit.gd:388-389` (seno de `n` y sal, misma idea) para el contenido de cada pieza.
- Sales de `vary` observadas en la oficina: van de 2 a 492 (`office_props.gd`, `office_clutter.gd`, `office_fittings.gd`, `office_geometry.gd`). No hay una lista exhaustiva.
- `RandomNumberGenerator` con semilla 6113 solo para la alfa de las motas (`office_geometry.gd:1327-1328`, `:1344`).
- Dificultad: `difficulty_id` por defecto «equilibrada» (`office_geometry.gd:1008`); la oscuridad de la planta 0 la decide `darken_first_stage()` (`:1015-1024`) con `vary` sal 180 y `LIT_LEFT` 0,1 (`:1014`).
- Semilla del piso: `manifest.seed` en las láminas de planta (`office_pictures.gd:42`).

**Orden de construcción.**
- `build(data)` (`office_geometry.gd:982-995`): primero `duct_holes` del conducto; luego `dressing_log`; después `await super(data)` (la construcción del hotel); luego `glow_room(false)` para las salas oscuras (`:989-990`); luego `refresh_accents` (`:992`); por último el conducto principal `MAIN_DUCT.build` y su `add_child` (`:993-995`). El comentario indica que el conducto se construye tras el horneado de navegación y antes de la comprobación de física (`office_geometry.gd:980-981`).
- `flush()` (`office_geometry.gd:875-881`): antes de agrupar, guarda `service_runs` por sala para poder cortar una loseta sin leer el `MultiMesh` (`lift_out()`, `:820-869`).
- `extras()` (`office_geometry.gd:2333-2404`) va después de `build_room()` y dentro de la sala: unidades de emergencia, sondas de salas oscuras, post y consola, rejillas de pared, arrival lift, muebles (`PROPS.build_item`), luego `FITTINGS.dress`, `WALLS.dress` y `CLUTTER.dress`. El orden de estas tres es fijo (`office_geometry.gd:2381-2384`).
- `_process(delta)` (`office_geometry.gd:2434-2440`): llama a `super` y después `glow_halos()`. `glow_halos()` (`:2447-2464`) recalcula la energía de halos y sus focos por distancia y cada planta cambia el estado de todos sus halos (`:2450-2453`).
- Sala vista: `round_lamps()` (`office_geometry.gd:1224-1236`) ejecuta en orden `round_accents`, `round_pools`, `air_lights`, `round_landmarks` y las unidades de emergencia.
- `round_pools()` (`office_geometry.gd:2571-2586`): ordena por distancia al ojo y da sombra a las 32 primeras (depende de la posición de cámara en cada frame).
- `set_room_power()` (`office_geometry.gd:1029-1034`) y `drain()` (`:2792-2795`) cambian lentes, acentos y sondas por sala.
- `blackout()` (`:2799-2802`).
- Temporizadores y tweens: `flicker_one()` usa `get_tree().create_timer` (`office_geometry.gd:1692`). `turn_tile()` anima la loseta con `create_tween` y `Tween.TRANS_SINE` (`office_geometry.gd:801-815`; `TILE_SWING` 0,25 s, `TILE_DOWN` 1,05, `TILE_UP` 1,22, `:794-796`).
- `scissor_gate.gd`: `set_notify_local_transform(true)` y `relayout()` cada vez que cambia la posición (`scissor_gate.gd:13-18`). El ascensor de carga la mueve en x (`lifts.gd`, no leído).

**Física.**
- Colisionadores de caja, un cuerpo por sala (ver §3). El conducto principal es un `StaticBody3D` con capa 1 (`main_duct_geometry.gd:120-124`).
- Cuerpo del jugador en el conducto: `body_bit()` devuelve capa −1 dentro del conducto (`office_geometry.gd:1371-1373`, `MAIN_DUCT.inside()`), y el reflejo de la lámpara de la sala no le llega.
- `put_away()` oculta el conducto salvo en la planta 3 (`office_geometry.gd:1376-1378`).
- Las motas se envuelven en una caja de 4 m alrededor del ojo; el `custom_aabb` es enorme (±10.000 m) para que nunca se recorten (`office_geometry.gd:1351`).

**Señales.** Solo `connect` en `office_geometry.gd:1692` (fin del fallo de tubo) y `perf` (medidor de rendimiento) en `_process` (`:2435-2440`, `:2492`). No hay señales de física.

**Rutas a `RenderingServer`:** `RenderingServer.get_current_rendering_method()` en `round_lamps()` (`:1226`), `pools_shown()` (`:2534`) y `round_accents()` (`:2779`); y `RenderingServer.instance_set_visible` en `make_probe()` (`:2524`, `:2526`). Compatibility cambia el número de sombras (`EMERGENCY_CAST_COMPAT` 3, `office_geometry.gd:1097`).

---

## 13. Lo que el autor y el director consideran flojo

Del spec (`visual_vuelta_grande.md`), tal como lo dejan escrito:
- Foto 4, z-fighting blanco en una pared: sin resolver, no se reproduce, hace falta la semilla y el sitio (spec línea 63).
- Lo que no se consiguió de la luz de una sala que sale a un pasillo oscuro (spec línea 84): la luz apenas se ve en el aire; las motas en la linterna se ven poco; el halo de la emergencia es una bola, no un cono; la linterna de un compañero sigue fuera de la niebla.
- «Queda» (spec línea 75): el suelo de la recepción con motas más gruesas que la referencia; las butacas entran solo por el borde del encuadre (semilla 7); las vetas del suelo del pasillo se notan mucho; la luz de emergencia muy oxidada; `fire_alarm` sin sustituto en código; todo visto en Alto y en semillas 7, 33 y 101.
- «Pendiente» (spec líneas 106-117): carros del archivo móvil; climatizadora (parece dos lavadoras, escalera de pie, compuerta suelta); taquilla escondite lisa y taquillas de aseo en silueta; tubos del correo que acaban en el aire y tubos neumáticos sin soportes; repetición de cajas de archivo y de tablones de corcho; zócalo del mostrador; fregadero con grifo; huecos negros junto a algunas pantallas sin causa confirmada; churretes de pared a la misma altura (pide tocar un sombreado compartido con el hotel); reja del montacargas en bandas; centros de sala vacíos; sin comprobar en captura: placa colgante del techo, silla azul de cerca, blocs en la mesa de juntas, silla de secretaría, perchero en su sala, la puerta de mirilla y el rebote en Medio y Bajo (en el código no sale allí: `pools_shown()`); abrigo colgado sin modelo.
- Del spec, línea 71: el cuerpo propio no da sombra bajo pantallas ni regletas en Alto y Ultra (cambio de rendimiento).
- Del spec, línea 67: la luz de una sala son sus luminarias (contrato del autor de 14 de noviembre). Las galerías de servicio, almacenes, depósitos y salas de aire siguieron con su lámpara hasta rev12.
- Del mismo spec: la foto 4 sigue sin resolver (línea 63) y los pasillos más oscuros que las salas están medidos en `evidence/rediseno/rev11/` (línea 68).

Evidencias citadas en el spec: `evidence/autor_12nov/1.webp` a `6.webp`; `evidence/autor_14nov/f01` a `f12`; `evidence/rediseno/rev5` a `rev13`; `evidence/rediseno/polvo/`, `hitos/`, `rev13/ref_bands.py`. No abiertas.

---

## 14. Constantes y cifras que definen el aspecto

| Constante | Valor | Ruta:línea |
|---|---|---|
| GRADE (clave, blanco, contraste, saturación, ssao_light) | 0,05; (1,2; 1,0; 1,15); 1,16; 0,85; 0,35 | game/world/office/office_geometry.gd:203 |
| AIR_DENSITY por planta | 0,008; 0,02; 0,02 | office_geometry.gd:210 |
| AIR_ANISOTROPY / TORCH_AIR | 0,6 / 3,0 | office_geometry.gd:211-212 |
| LAMP_ENERGY / LAMP_DROP / LAMP_PROFILE | 2,3 / 0,9 m / «even» | office_geometry.gd:126, 135, 132 |
| LAMP_ATTENUATION / _ALONE | 1,25 / 0,9 | office_geometry.gd:141-142 |
| LAMP_SPECULAR / POOL_SPECULAR | 0 / 0 | office_geometry.gd:151, 196 |
| POOL_ENERGY / POOL_ANGLE / POOL_FALL / POOL_RANGE | 3,0 / 75° / 1,0 / 7 m | office_geometry.gd:195-199 |
| POOLS_CAST / POOL_KEEP / POOL_SIZE | 32 / 1,0 m / 0,6 | office_geometry.gd:2567-2569 |
| POOL_UNDER_TUBES | 0,1 m | office_geometry.gd:2570 |
| BOUNCE_FROM / BOUNCE_ANGLE / BOUNCE_REACH | 0,1 m / 90° / 3,0 m | office_geometry.gd:739-741 |
| FLOOR_SHARE / ROOM_REFLECT / BOUNCE_SHARE | 0,25 / 0,32 / 0,75 | office_geometry.gd:748-750 |
| RECEPTION_DIM / RECEPTION_BOUNCE / RECEPTION_HALO | 0,9 / 0,5 / 0 | office_geometry.gd:649, 659, 654 |
| WINDOW_DIM | 0,7 | office_geometry.gd:662 |
| HALO_REACH / HALO_ENERGY / HALO_BELOW | 1,8 m / 0,22 / 0,002 m | office_geometry.gd:172-174 |
| LENS_GLOW / LENS_MIRRORED / LENS_LIT_DARK | 4,0 / 15 / 1,0 | office_geometry.gd:178, 240, 157 |
| LENS_TUBES / LENS_DIFFUSER | 0,24; 0,5; 0,76 / 0,35 | office_geometry.gd:181-182 |
| LENS_ALBEDO | #e6e2d8 | office_geometry.gd:154 |
| FAILING | 0,12 | office_geometry.gd:145 |
| PROBE_PAST / PROBE_INTENSITY / PROBE_STEP | 0,05 m / 1,0 / 0,05 | office_geometry.gd:228, 231, 2486 |
| RECEPTION_PROBE / PROBE_EYE | 6,0 / 2,0 m | office_geometry.gd:1773, 1775 |
| FLOOR_LAYER / PROBE_ONLY | 8 / 2 | office_geometry.gd:232, 241 |
| SCREEN_ROUGHNESS | 0,3 | office_geometry.gd:230 |
| BATTEN_DOWN / BATTEN_UP | {4,0; 85°; 1,4; 3,0} / {3,0; 88°; 4,0} | office_geometry.gd:2038-2039 |
| BATTEN_TUBES / BATTEN_UP_FROM / BATTEN_BOUNCE_FALL | 0,14 m / 0,35 m / 2,0 | office_geometry.gd:2037, 2040-2041 |
| BATTEN_CAST / BATTEN_AISLE | {2,2; 62°; 6 m} / {1,4; 34°; 4,5 m} | office_geometry.gd:1997-1998 |
| EMERGENCY_ENERGY / EMERGENCY_RANGE / EMERGENCY_ANGLE / EMERGENCY_KELVIN | 1,4 / 9 m / 55° / 2400 K | office_geometry.gd:1098-1101 |
| EMERGENCY_CAST / EMERGENCY_CAST_COMPAT / EMERGENCY_REACH | 6 / 3 / 18 m | office_geometry.gd:1095-1097 |
| EMERGENCY_AIR / ACCENT_AIR / EXIT_AIR / POOL_AIR / LAMP_AIR | 3,0 / 1,5 / 4,0 / 0,12 / 0,25 | office_geometry.gd:1265-1269 |
| LANDMARK_AIR / FOCAL_AIR | 6,0 / 2,0 | office_geometry.gd:1289-1290 |
| EXIT_ENERGY / EXIT_RANGE | 0,1 / 1,2 m | office_geometry.gd:2322-2323 |
| WINDOW_LAMP_ENERGY / _ANGLE / _YAW | 7,0 / 34° / 1,29 rad | office_geometry.gd:1069-1071 |
| ACCENT_SIZE | 0,08 | office_geometry.gd:2619 |
| RECEPTION_ACCENTS | 7 | office_geometry.gd:1757 |
| MOTES_BOX / MOTES_PER_DUST / MOTES_MOST | 4,0 m / 14 / 140 | office_geometry.gd:1319-1321 |
| MOTE_LOOK (wrap, bokeh, scatter, ...) | 4,0; 10; 3,0 | office_geometry.gd:1323 |
| TILE / TILE_THICK / TILE_FACE | 0,6 / 0,015 / 0,004 m | office_palette.gd:1003; office_geometry.gd:115-116 |
| TROFFER_BODY / WRAP_DROP | 0,11 / 0,09 m | office_geometry.gd:118, 168 |
| NARROW_LENS / LOUVRE_PITCH / PARABOLIC_PITCH | 0,28 / 0,1 / 0,19 m | office_geometry.gd:163-167 |
| CLUTTER: FALLEN, ODD, ASIDE, CABLE, FLOOR_PAPERS, LITTER | tablas de 5 valores por «mess» | office_clutter.gd:31-38, 229 |
| DIFFUSERS / APART / POST_CLEAR | 4 / 1,8 m / 0,45 m | office_fittings.gd:25-29 |
| WALL_HALF (cara del muro) / espesor de pieza | 0,09 m / 0,18 m (literal en `wall_core`) | office_palette.gd:1006; office_geometry.gd:1449 |
| SIGN_Y / SIGN / SIGN_HEAD | 1,6 m / 0,42×0,30 m / 0,34 | office_landmarks.gd:52-54 |
| LAMP_Y / LAMP_DOWN / LAMP_ANGLE / LAMP_REACH | 2,84 m / 50° / 38° / 2,8 m | office_landmarks.gd:68-72 |
| WASH_ANGLE / WASH_REACH | 46° / 3,2 m | office_landmarks.gd:73-74 |
| FOCAL_ENERGY / FOCAL_ANGLE / FOCAL_REACH | 3,5 / 28° / 3,0 m | office_landmarks.gd:90-92 |
| BANNER_Y / BANNER_REACH / SIGN_REACH | 2,34 m / 32 m / 14 m | office_landmarks.gd:80, 83-84 |
| WAY_Y / WAYS_MOST | 2,25 m / 4 | office_landmarks.gd:100-101 |
| PLAQUE / PLAQUE_Y / PLAQUE_LETTER | 0,26×0,09 m / 1,55 m / 0,065 m | office_geometry.gd:90, 94, 92 |
| SWITCH_Y | 1,15 m | office_geometry.gd:107 |
| MULLION_PITCH / GLASS_SILL / GLASS_HEAD | 1,2 m / 0,95 m / 2,65 m | office_geometry.gd:71-74 |
| TWO_TONE_TOP / DADO_TOP / FRIEZE_TOP | 1,2 / 1,05 / 1,0 m | office_geometry.gd:57, 54, 52 |
| COLUMN (lado) / COLUMN_BASE / COLUMN_CAP | 0,6 / 0,1 / 0,08 m | office_palette.gd:280; office_geometry.gd:123-124 |
| CORRIDOR_PITCH / HALL_STEP | 2 m (del spec, línea 18; el valor en `office_palette.gd` no se leyó) / 5 a 8 m (spec línea 18) | `office_walls.gd:4-6` usa `OFFICE.CORRIDOR_PITCH` |
| CEILING_OUT / TUBE_CLEAR | 0,35 / 0,22 m | office_landmarks.gd:75-76 |
| PLAQUE_FROM_JAMB / PLAQUE_DEPTH | 0,22 / 0,019 m | office_geometry.gd:95, 100 |
| JAMB_WIDE / JAMB_PROUD / SOFFIT_DROP | 0,09 / 0,02 / 0,004 m | office_geometry.gd:101-104 |
| BAR_ENERGY (espejo de aseo) | 1,4 | office_fittings.gd:218 |
| STRIP_ENERGY / STRIP_MIRRORED | 10 / 60 | office_props.gd:418-419 |
| DOOR_CLEAR / WET_BAND / TRIM | 0,6 / 0,15 / 0,018 m | office_fittings.gd:52, 45, 48 |
| SCONCE_Y (aseo) | 2,05 m | office_fittings.gd:55 |

---

## 15. Dependencias que el port tiene que ver

- `FLOOR_LAYER` (8) y `PROBE_ONLY` (2) son capas de render por sala y por función: `room_layers.gd` (no leído) reparte las capas 5 a 20 por sala (`office_geometry.gd:223-227`).
- Las luces de tronera tienen `shadow_enabled` falso salvo en las 32 más cercanas. Las luces de rebote usan `BAKE_DYNAMIC` (entran en el VoxelGI, `office_geometry.gd:721`).
- Cualquier luz con `light_volumetric_fog_energy` (niebla) se controla por luz (`air()`).
- `light_projector` con el perfil de `LIGHTING.profile()` (`office_geometry.gd:2814-2815`); la luz de caja usa `box_sconce` (`:2725`) y `light_lamp()` lo quita (`:2555`). `LIGHTING.profile()` no se leyó.
- Distancias de desvanecimiento: `distance_fade_enabled` y `set_fade()` (`office_geometry.gd:2645`, `:2670`, `:2703`).
- `ReflectionProbe.reflection_mask`, `intensity`, `size.y` (`office_geometry.gd:2509-2527`).
- `MultiMesh` con `use_custom_data` y `set_instance_custom_data` (`hotel_geometry.gd:598-606`, `office_geometry.gd:856`).
- `custom_aabb` de ±10.000 m en las motas (`office_geometry.gd:1351`).
- `Label3D` con `font`, `visibility_range_end`, `cast_shadow` apagado, y `FontVariation` (`office_landmarks.gd:285-299`).
- `Geometry3D.get_closest_point_to_segment` (`office_landmarks.gd:236`) y `Geometry2D.get_closest_point_to_segment` (`office_clutter.gd:388`, `:395`).
- `SurfaceTool`, `commit_to_arrays()`, `index()` y `ArrayMesh.surface_set_material` (`kit.gd:399-421`).
- `RenderingServer.instance_set_visible` y `get_current_rendering_method()` (`office_geometry.gd:1226`, `:2524`).
- `Image.create` y `ImageTexture.create_from_image` (`office_geometry.gd:540-549`).
- `ResourceLoader.exists()` como comprobación de existencia de cada modelo (`office_models.gd:166`, `main_duct_geometry.gd:223`, `office_fittings.gd:161`).
- `FileAccess` y `JSON.parse_string` para `paintings.json` (`office_pictures.gd:29`).
- `ThemeDB.fallback_font` (`office_landmarks.gd:304`, `:323`, `:330`).

---

## 16. Clases de Godot en la parte (apariciones en `game/world/office/`)

Conteo por texto (`grep` sobre `game/world/office/`). Cuenta líneas que contienen el nombre, no instancias. Los tipos (`Node3D`, `ArrayMesh`, `AABB`) son sobre todo anotaciones de tipo; los constructores reales están en la fila «.new()» de la columna de la derecha, que se cuenta en la misma pasada.

| Clase | Apariciones | Uso principal |
|---|---|---|
| Node3D | 441 | Contenedor de todo; en su mayoría tipo de parámetro |
| ArrayMesh | 331 | Pieza de código; tipo de retorno de `kit.gd` |
| AABB | 58 | Cajas de colisión y de pieza |
| MeshInstance3D | 27 | Mallas sueltas (lentes, persianas, cabinas, cristal, letreros) |
| StandardMaterial3D | 22 | Materiales de lentes, fantasmas, sondas, pasamanos |
| GeometryInstance3D | 19 | Desactivar sombra y GI |
| Image | 17 | Imágenes procedurales (lentes, cuadros, planos, rayas) |
| SurfaceTool | 15 | Construcción de mallas de conducto, puertas, cabina |
| ShaderMaterial | 13 | Cristal armado, persianas, halo, sombra del polvo |
| MultiMesh | 13 | Polvo, rejilla de montacargas, mallas por sala |
| SpotLight3D | 12 | Pozos, rebotes, focos de hito, emergencias, lámparas |
| BoxMesh | 12 | Cajas de columnas, marcos, bloques |
| ResourceLoader | 11 | Existencia de modelos y materiales |
| MultiMeshInstance3D | 9 | Motas, celosía de montacargas |
| Label3D | 9 | Letreros, placas, directorio |
| QuadMesh | 8 | Cuadros, persianas, fantasmas, sombra de lente |
| OmniLight3D | 7 | Lámpara de sala (`lights`), cabina |
| RenderingServer | 6 | Método de render, visibilidad |
| ImageTexture | 5 | Textura de lente, plano |
| VoxelGI | 3 | Volúmenes de rebote (`office_bounce.gd`) |
| ThemeDB | 3 | Fuente por defecto de los letreros |
| StaticBody3D | 3 | Conducto principal |
| FontVariation | 3 | Letra estarcida |
| AreaLight3D | 3 | Franja de mostrador (`accent_strip`) |
| Tween | 2 | Loseta (`turn_tile`) |
| ReflectionProbe | 2 | Sonda de sala |
| Geometry2D / Geometry3D | 2 / 1 | Distancias a segmentos |
| FileAccess | 2 | `paintings.json` |
| Time | 2 | Medidor de rendimiento |
| PlaneMesh | 1 | Alfombra oriental |
| CollisionShape3D / BoxShape3D | 1 / 1 | Colisionador de caja del conducto |
| RandomNumberGenerator | 1 | Alfa de las motas (semilla 6113) |
| create_timer / connect / await | 1 / 1 / 1 | Fin de fallo de tubo; `await super(data)` |
| JSON | 1 | Lista de cuadros |

Nota: las lámparas de sala (una `OmniLight3D` por sala) se crean en `game/world/hotel/hotel_geometry.gd` (`lamp_light()`, línea 1409), no en esta carpeta; aquí solo se referencian. Búsquedas de nodos: `find_children` en `office_geometry.gd:1056`; `get_node_or_null` en `office_clutter.gd:113`.

---

## 17. Pruebas que vigilan esta parte

Archivos de `tests/office/` que nombran la geometría o las piezas:
- `office_dark_test.gd`
- `office_dressing_test.gd` (según el comentario de `office_geometry.gd:2614-2617` es el consumidor de `dressing_log`: `walls`, `ceiling`, `chairs`, `clutter`, `fronts`; el archivo de la prueba no se leyó)
- `office_finishes_test.gd`
- `office_light_test.gd`
- `office_pieces_test.gd`
- `office_walk_test.gd`
- `lurker_tiles_test.gd` (cruce con las losetas que mueve la fugitiva)

Por nombre, también forman parte del conjunto de la oficina (no leídos): `office_audio_test.gd`, `office_bots_test.gd`, `office_lies_test.gd`, `office_proportion_test.gd`, `office_test.gd`, `office_test_generator.gd`, `office_test_physics.gd`, `office_test_validator.gd`, y los `lurker_*_test.gd`.

Herramientas que consumen esta parte: `tools/capture/office_pieces_sheet.gd`, `tools/capture/office_capture.gd`, `tools/capture/office_rooms_capture.gd`, `tools/props/build_catalogue.gd`, `tools/props/fit_models.json`, `tools/props/cloth_pieces.py`, `tools/textures/ingest_dressing.py`.

El tamaño del conjunto de pruebas de la oficina es 4.564 líneas en `tests/office/office_*.gd` (`wc` sobre los archivos `office_*`, no leídos uno a uno).

---

## Sin comprobar

- Número de nodos, mallas y luces **por planta**: no está en el código ni en el informe; solo hay cifras de un piso (26.358 nodos, §10). Hace falta ejecutar el generador con el manifiesto de la semilla.
- Contenido del manifiesto (`room.height`, `room.px`, `room.pz`, `room.furniture`, `room.props`, `room.sockets`, `ducts.exits`, `archives`, `mail`, `power`, `air`, `arrival_lift`, `departments`, `entries`, `merged`): se usa, pero el generador (`game/world/generation/office_*`, `floor_definition.gd`, `office_palette.gd`, `office_layout.gd`) no se leyó.
- `FLOOR.PORTAL`, `OPENING_HIGH` (`office_geometry.gd:2280`), `FLOOR.doorways`, `FLOOR.position_of`, `FLOOR.size_of` (`floor_definition.gd`): no leído.
- `OFFICE.troffer_look()`, `OFFICE.lamp_kelvin()`, `OFFICE.floor_look()`, `OFFICE.wall_trim()`, `OFFICE.lamp_of()`, `OFFICE.false_ceiling()`, `OFFICE.troffers()`, `OFFICE.free_tiles()`, `OFFICE.FURNITURE`, `OFFICE.WALL_DRESSING`, `OFFICE.RULE_TEXTS`, `OFFICE.CORRIDOR_RHYTHM`, `OFFICE.CORRIDOR_PITCH`, `OFFICE.FILING_FINISH`, `OFFICE.WAITING_CHAIR`, `OFFICE.SPRINKLER_ROOMS`, `OFFICE.litter_of()`, `OFFICE.plaque()`, `OFFICE.zone_label()`, `OFFICE.stripe_color()`: referenciados, no leídos (`office_palette.gd` sólo se miró en 280-285 y 1003-1021).
- `LIGHTING.light_color()`, `LIGHTING.profile()`, `LIGHTING.PROFILE_GAIN`, `ROOM_LAYERS.lamp_range()`, `ROOM_LAYERS.light_only()`, `ROOM_LAYERS.put_on()`, `room_layers.gd`: no leídos.
- `hotel_geometry.gd` en general (3.000+ líneas): solo las funciones citadas en §2 y §12. `box()` del hotel, `place()` y `flush()` se leyeron, pero `round_probes()`, `lamp_light()`, `wall_run()` original, `build()` del hotel y `lift_out` del hotel no.
- `bounce_light.gd` (`office_bounce.gd` hereda de él): no leído. `SKIP` y `shines()` solo por su uso.
- `ceiling_dust.gd`, `ceiling_halo.gdshader`, `ceiling_dust.gdshader`, `tile.gdshader`, `ceiling_tile.gdshader`, `venetian_blind.gdshader`, `wired_glass.gdshader`, `surface.gdshaderinc`: no leídos.
- Materiales `.tres` de `game/presentation/materials/office/`: no leídos (solo sus nombres). Sus UV y tilings no se conocen.
- Mapas de escaneo `apply_scan`, `scan_maps`, `small_maps`, `officeceiling001` (`office_geometry.gd:304-316`): no leído.
- Modelos `.res` y `.obj`, tamaños de malla, número de triángulos por modelo (`portalapices_aspectstudio` 4,8 k triángulos en el spec, línea 102): no medido.
- Tablas de `build_catalogue.gd` (`PARTS`, `YAW`, `PLACED`), `ingest_models.py` (`TINT`, `PATCHES`, `SRGB_FACTOR`, `COLOUR_OF`), `fit_models.json`: no leídos. El spec (líneas 19, 65, 73) menciona cómo se generan.
- Clases `office_recipes.gd`, `office_generator.gd`, `office_layout.gd`: no leídas; determinan qué piezas caen en cada sala.
- `docs/OFICINAS.md` (diseño aprobado del piso 2): existe en el repo, no leído. `spec_rediseno.md` (citado varias veces en el spec, y en `office_geometry.gd`): no existe en `.claude/specs/`.
- `game/world/hotel/bounce_light.gd`, `game/enemies/lurker/ceiling_dust.gd`, `game/world/office/lifts.gd`: no leídos.
- Valores de `OPENING_HIGH`, `DOOR_CLEAR` y del resto de constantes de `office_palette` que se citan sin leer: no comprobados.
- Qué preset es «Alto» frente a `quality` 2 del informe: no comprobado.
- Si la verificación de la escena (`verify.ps1`) pasa o falla con el estado actual: no se ejecutó nada, por encargo.
- Cifras de las capturas del autor (`evidence/autor_*`, `rev*`): no abiertas.
- `vary()` depende de la variable `looks` del hotel (`hotel_geometry.gd:502`); no se sabe en qué momento se fija en cada escena. Solo se leyó su definición.
