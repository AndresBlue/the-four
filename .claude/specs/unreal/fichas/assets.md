# Ficha de hechos: assets (para el port a Unreal)

Fecha de la lectura: 14 de noviembre de 2026. Repo: `E:\Projects\The Four`, rama `main`.
Solo lectura: no se ejecutó Godot ni Unreal, no se tocó git y no se escribió código del juego.

Convenciones: «MB» son mebibytes (1 048 576 bytes). Las rutas `archivo:línea` son del repo. Las rutas `source_assets/`, `models/`, `sfx/` y `assets/props/**/*.zip` están fuera de git (ver sección 2). Cuando una cifra sale de un recuento hecho con un script, se dice; si sale de un documento, se cita la línea de `docs/ASSETS.md`.

---

## 0. Lo esencial

- **Lo que entra en el juego (`assets/`, versionado):** 216 mallas horneadas en formato `.res` de Godot (hotel 101, oficinas 95, otras 20); 3 personajes (`.fbx`) con sus clips (`clips.res`); 2 criaturas en `.glb` (Locust 14,6 MB y Lurker 5,3 MB); 30 sets de texturas escaneadas CC0 (12 de hotel y 18 de oficinas); 202 audios (163 WAV, 37 OGG, 1 MP3, 1 M4A); 31 cuadros JPG; 21 decals PNG; 18 PNG de 256 px de logros de interfaz.
- **Los originales están fuera de git:** `source_assets/` ocupa 2 791 archivos y 7 164,9 MB; `models/` 254,0 MB; `sfx/` 213,2 MB; y 8 zips de modelos dentro de `assets/props/` (467,0 MB) que están ignorados por `.gitignore`.
- **Fuente de intercambio:** los 196 modelos de piso (`assets/props/hotel` y `assets/props/office`) tienen en disco una carpeta de origen con glTF o FBX: 100 + 94 en glTF, 1 en FBX (`key_chain`) y 1 mixto (sección 3.1 y anexo A). Ninguno falta.
- **Mallas hechas por código:** `office_models.gd` declara 82 tipos de objeto. 81 tienen modelo horneado y uno (`waiting_chair`) no. Hay 44 tipos con sustituto hecho en código; 14 de ellos no tienen modelo en disco. Otros 51 tipos tienen modelo y no tienen sustituto: si falta su `.res`, no se dibuja nada.
- **Integridad:** las 674 entradas de `docs/asset_hashes.json` coinciden en tamaño y SHA-256 con el disco (comprobado con script).
- **Faltas comprobadas:** la fuente `assets/fonts/vcr_osd_mono.ttf` no existe en el disco (`game/ui/osd_style.gd:4`). No hay ningún `.ttf` ni `.otf` en el repo.
- **Licencias que condicionan el port:** El Locust es CC BY-NC-ND 4.0 (no comercial, sin derivadas; `docs/ASSETS.md:110-111` y `:433`). Realistic Female es CC BY-SA 4.0 (`docs/ASSETS.md:33`, `:112`). El televisor, el dormitorio, la puerta de madera y el armario no tienen licencia comprobada (`docs/ASSETS.md:72`).

---

## 1. Qué hay y en qué estado (recuento por carpeta)

| Carpeta | Archivos / entradas | Tamaño | Qué es | En git |
|---|---|---|---|---|
| `assets/props/` | 1 679 archivos | 682,1 MB | Mallas `.res` (216), materiales `.tres` (222), texturas JPG (514) y PNG (90), y 8 zips de origen | `.res`, `.tres`, JPG y PNG sí. Los zips no (`.gitignore`: `assets/props/**/*.zip`) |
| `assets/players/` | 254 | 227,5 MB | 3 personajes: `model.fbx` (1,9 MB, 27,2 MB y 67,3 MB), `model.obj` del detective (2,6 MB), 121 PNG de textura y 3 `clips.res` (3,8 MB) | Sí |
| `assets/textures/` | 419 | 164,9 MB | 30 sets escaneados (`albedo`, `normal`, `orm` a 2048 y 1024 px), la carpeta `lite/` (43 entradas) y 6 PNG de papeles y tarjetas del hotel | Sí |
| `assets/audio/` | 403 (202 audios y 201 `.import`) | 78,2 MB | `sfx/` (164 archivos), `intro/` (17), `dread/` (7), `events/` (7), `glass/` (4), `hotel/ambience.wav` (8,6 MB), `the_four_theme.mp3` (5,9 MB), `bed-sound.m4a` (0,6 MB) | Sí |
| `assets/enemies/` | 20 | 34,3 MB | `locust.glb` (15 303 916 bytes) y sus 5 PNG; `lurker/lurker.glb` (5 527 156 bytes) y su PNG de cara | Sí |
| `assets/paintings/` | 64 | 7,3 MB | 14 cuadros del hotel y 17 láminas de oficina (JPG), más 2 `paintings.json` | Sí |
| `assets/decals/` | 42 | 5,8 MB | 13 decals de color, 7 normales y `blood_atlas.png` | Sí |
| `assets/ui/` | 36 | 0,3 MB | 18 PNG de 256 × 256 px (`achievements/`) | Sí |
| `assets/images/` | 5 | 1,5 MB | `the_four.png` (icono del proyecto, `project.godot:24`), `the_four.ico`, `the-locust.png` | Sí |
| `assets/*.png` | 4 | 10,3 MB | Carta, libreta, papel-mapa y nota del hotel (del autor) | Sí |
| `models/` | 39 | 254,0 MB | 6 zips de origen de personajes, videocámara, VHS y armario (239,9 MB) y 32 FBX de Mixamo en `models/mixamo/` (14,2 MB) | No (`.gitignore`: `/models/`) |
| `source_assets/` | 2 791 | 7 164,9 MB | Originales: `oficinas/` (1 865 archivos, 6 520 MB), `props/` (768, 304 MB), `textures/` (33, 154 MB), `decals/` (13 zips, 65 MB), `audio/` (9, 43 MB), `camcorder/`, `vhs_tape/`, `elevator/`, `paintings/`, `characters/`, `locust.zip` (20,6 MB) | No (`.gitignore`: `source_assets/`) |
| `sfx/` | 61 | 213,2 MB | Másteres de audio del autor: 18 WAV, 3 MP3, 39 OGG (60 audios) | No (`.gitignore`: `/sfx/`) |
| `art/lurker/` | 16 | 18,4 MB | `lurker.blend` (4,9 MB, fuente Blender 5.2), `referencia.webp` (imagen de origen sin comprobar), `renders/` | Sí (`art/` tiene `.gdignore`) |

Fuentes: recuentos con script sobre el disco; tamaños de `docs/ASSETS.md` y `.gitignore` en las líneas citadas.

---

## 2. Formatos dentro del juego

| Familia | Formato que lee Godot | Cómo se importa | Dónde está |
|---|---|---|---|
| Mallas de piso | `.res` (Mesh horneado, una superficie por material) | No hay import: son recursos binarios de `tools/props/build_catalogue.gd` (`ResourceSaver.save`, `:345`, `:446`, `:552`) | `assets/props/hotel/*.res`, `assets/props/office/*.res` |
| Modelos de origen (personajes, enemigos, otros) | `.glb` o `.fbx` como `PackedScene`; `.obj` como `Mesh`; `.dae` como `PackedScene` | Import automático (`*.import`: 15 PackedScene, 4 Mesh) | `assets/players/*/model.fbx`, `assets/enemies/*.glb`, `assets/props/*/*.fbx`, `assets/props/camcorder/*.obj`, `assets/props/office/skull/skull.obj`, `assets/props/vhs_tape/vhs_tape.dae` |
| Materiales | `.tres` (StandardMaterial3D o ShaderMaterial) | Escritos a mano o por script | `game/presentation/materials/*.tres` (49), `game/presentation/materials/office/*.tres` (56), y `assets/props/*/*.tres` (222) |
| Texturas | `CompressedTexture2D` (VRAM comprimida) | `compress/mode=2`, formatos `s3tc_bptc` y `etc2_astc`, mipmaps generados (`assets/textures/brown_leather/albedo.jpg.import:9-10`, `:20`). `project.godot:58`: `vram_compression/import_etc2_astc=true` | Todas las JPG y PNG (1 033 `.import` de tipo textura) |
| Audio | `AudioStreamWAV`, `AudioStreamOggVorbis`, `AudioStreamMP3` | WAV con `compress/mode=2` (`assets/audio/hotel/ambience.wav.import:24`), `edit/loop_mode=0` (`:21`) | 166 `.import` WAV, 37 OGG, 2 MP3 |
| Cuadros | Textura de un `QuadMesh` | `load()` del JPG (ver sección 6) | `assets/paintings/*.jpg` |

Los `.import` cuentan 1 257 archivos: 1 033 de textura, 166 WAV, 37 OGG, 2 MP3, 15 PackedScene y 4 Mesh. Recuento con script.

---

## 3. Modelos

### 3.1 Mallas horneadas (`.res`) y su fuente

**Hotel: 101 `.res` en `assets/props/hotel/`.** Los hornea `tools/props/build_catalogue.gd`: lee `source_assets/props/<id>/` y escribe en `assets/props/hotel/` (`build_catalogue.gd:19-20`). Las excepciones de orientación y escala están en `:23` (`YAW`: tres modelos giran -90°) y `:25` (`SCALE`: estantería 0,1, fuente de agua 0,01 y perchero 0,01). Se excluyen modelos en `:31` (`SKIP`). Los objetos con varias piezas se separan con `PARTS` (`:36`).
- 90 tienen carpeta propia, o la de su padre, con glTF en `source_assets/props/<id>/` (Poly Haven, sufijo `_1k` o `_2k`). Ejemplo: `GothicCommode_01_drawer_1.res` sale de `GothicCommode_01`.
- 1 tiene origen FBX: `key_chain` (`source_assets/props/key_chain/`).
- 10 son partes de un padre sin carpeta propia, también con glTF (`vintage_suitcase_a_body.res` sale de `vintage_suitcase`; `modular_pipes_straight.res` de `modular_pipes`).

**Oficinas: 95 `.res` en `assets/props/office/`.** Vienen de las descargas de Sketchfab y Poly Haven en `source_assets/oficinas/<grupo>/<slug>/`. Cada una tiene una carpeta `_gltf/` o `_zip/scene.gltf`. El emparejamiento se hizo por nombre de carpeta (sección 15). 94 tienen glTF y 1 tiene glTF y FBX. Dos son partes de un padre (`retro_oficina_yj_chair.res` y `retro_oficina_yj_desk.res` salen de `retro_oficina_yj`). El detalle está en el anexo A.

**Otras 20 mallas `.res`** (todas en `assets/props/`):

| Carpeta | `.res` | Origen | Horneado en | Tamaño de referencia |
|---|---|---|---|---|
| `sofa/` | `sofa.res` | `assets/props/sofa/sofa.fbx` (zip `other/sofa-pbr.zip`, `docs/ASSETS.md:407`) | `build_model_props.gd:14` | `size` 2,15 en x |
| `monstera/` | `monstera.res` | `monstera.fbx` (zip `plants/monstera-indoor.zip`, `ASSETS:409`) | `build_model_props.gd:16` | `size` 1,35 |
| `tv/` | `tv_body.res`, `tv_screen.res` | `old_tv.fbx` (zip `tv/sony-trinitron-prl.zip`, `ASSETS:405`) partido en dos | `build_model_props.gd:12` | `size` 0,62 |
| `bedroom/` | `bed.res` | `bedroom_set.fbx` (zip `bedroom/bedroom-furniture-set.zip`, `ASSETS:406`) | `build_model_props.gd:13` | `size` 2,1 en z |
| `wall_lamp/` | `wall_lamp.res` | `wall_lamp.fbx` (zip `other/wall-lamp-2048px2.zip`, `ASSETS:408`) | `build_model_props.gd:15` | `size` 0,42, anclaje en pared |
| `wardrobe/` | `wardrobe_body.res`, `wardrobe_leaf_left.res`, `wardrobe_leaf_right.res`, y dos `*_inside.res` | `wardrobe.fbx` (sin zip identificado, sección 15) | `tools/props/build_wardrobe.gd:7-8`, `SIZE` `:12` (1,25 × 2,3 × 0,78 m) | Sin ficha de licencia (`ASSETS:72`) |
| `door/` | `door_leaf.res`, `door_frame.res` | `door.fbx` (zip `door/door-wooden-old-9mb.zip`, `ASSETS:411`) | `tools/props/build_door.gd:18` (`OPENING_HIGH` 2,65 m) | Sin ficha de licencia (`ASSETS:72`) |
| `elevator/` | `lift_car`, `lift_door_a`, `lift_door_b`, `lift_call`, `lift_screen` (`.res`) | `elevator.fbx` (de `source_assets/elevator/…/ElevatorAnimation.fbx`, `ASSETS:58-64`) | `tools/props/build_elevator.gd:22` (`LIFT_SCALE` 0,8) | Sketchfab, CC BY (`ASSETS:53`) |
| `camcorder/` | `camcorder.res` | `camcorder_body.obj` y `camcorder_glass.obj` (de `source_assets/camcorder/source/LAATSTE VERSIE.obj`, zip `models/panasonic-vhs-c-movie-camera-nv-a3.zip`) | `tools/props/build_camcorder.gd:15` (`CAMCORDER_LENGTH` 0,27 m) | CC BY 4.0 (`ASSETS:54`) |
| `vhs_tape/` | `vhs_tape.res` | `vhs_tape.dae` (zip `models/vhs.zip`) | `tools/props/build_camcorder.gd:17` (`TAPE_LENGTH` 0,187 m) | CC BY 4.0 (`ASSETS:55`) |

Notas de estos 20: `hotel_geometry.gd:286-292` precarga el candelabro (`Chandelier_02.res`), la lámpara de pared, las hojas de puerta y el marco. `tools/props/fit_models.json` (60 entradas) fija la posición y la escala de cada pieza de oficina en el marco del juego (su `_doc` describe la puerta: bisagra en x = -0,05 y hoja de 0,012 a 2,638 m de altura).

**Mallas que no son `.res`:**
- Cráneo de la oficina del conducto: `assets/props/office/skull/skull.obj` (con 3 PNG de 512 px), escala `SKULL_SCALE` 0,073 en `game/world/office/main_duct_geometry.gd:262`. Origen: `source_assets/oficinas/equipos/human_skull_oga/skull-obj.zip`, CC0 (`docs/ASSETS.md:498`).
- Escalera del conducto: `res://assets/props/hotel/modular_fire_escape_ladder.res` (`main_duct_geometry.gd:20`).

### 3.2 Personajes y animaciones

- Tres personajes en `assets/players/<id>/model.fbx`: `detective` (1,9 MB), `detective_woman` (27,2 MB) y `realistic_female` (67,3 MB). Se cargan en `game/player/avatars/avatar_visual.gd:59`. Sus zips de origen están en `models/` (`detective.zip`, `detective-woman.zip`, `realistic-female.zip`; `ASSETS:39-42`).
- El esqueleto del detective es el autorrig de Mixamo, no del modelo original (`docs/ASSETS.md:35`). Mixamo permite usar sus animaciones en juegos, pero no redistribuir los archivos sueltos (`ASSETS:37`).
- Clips usados (`ASSETS:37`): Breathing Idle, Male Standard Walk, Male Hurried Walk, Running Forward Quickly, Male Walk Backwards, Backwards Running, Strafe Walking, Running Strafe (izquierda y derecha), Low Crouching Idle, Crouched Walk, Crouch Walk Back, Crouched Cover Sneaking Right (y su reflejo a la izquierda) y Jumping Forward.
- Los clips se hornean en `assets/players/<id>/clips.res` con `tools/avatars/bake_survivor_clips.gd` (`ASSETS:37`). Los FBX de origen son 32 en `models/mixamo/` (31 clips y `mixamo_detective.fbx`). Se cargan en `avatar_visual.gd:107`.
- Clips bajados y no usados (`ASSETS:37`): Falling Idle, Forward Running Jump, Jogging, Standing Jump, los «Standing» de caminar, correr y esprintar, Crouch Idle, Crouch Walk hacia delante y de lado, y Crouched Cover Sneaking Left.

### 3.3 Criaturas

- **The Locust:** `assets/enemies/locust.glb` (15 303 916 bytes, 14,6 MB), con 5 PNG de textura (`assets/enemies/locust_*.png`). Origen: `source_assets/locust.zip` (20,6 MB), dentro de `source/locust.glb` (`docs/ASSETS.md:426-427`). Licencia CC BY-NC-ND 4.0 (`ASSETS:433`). Lo cargan `game/app/hallucinations/locust_hallucinations.gd:17`, `game/enemies/locust/locust.tscn:3`, `game/intro/tv_broadcast.gd:10`, `game/presentation/shader_warmup.gd:33` y `game/title/title_scene.gd:15`.
- **The Lurker:** `assets/enemies/lurker/lurker.glb` (5 527 156 bytes), hecho con los scripts de `tools/art/lurker/` (Blender 5.2) a partir de `art/lurker/lurker.blend` (`ASSETS:441-443`). Lo carga `game/enemies/lurker/lurker.tscn:4`. Su textura de cara es `assets/enemies/lurker/lurker_lurker_face.png` (496 KB).
- Falta: `assets/enemies/lurker/ink_noise.res` lo hornea `tools/art/lurker/bake_ink_noise.gd`, pero no está en disco (`grep` de rutas `res://` en `game/`, `tests/` y `tools/`).

### 3.4 Lo que hace el código en lugar de un modelo

`game/world/office/office_models.gd:245-281` (`stand_in`) fabrica en código un sustituto para 44 tipos. De ellos, 14 no tienen modelo:

`cable`, `crt_black`, `folders`, `keyboard`, `microwave`, `mug`, `paper_scatter`, `paper_stack`, `pen_cup`, `phone_off`, `register`, `tray_wire`, `waiting_chair` (con `paths: []` en `:24`) y `work_light`.

Los otros 51 tipos con modelo no tienen sustituto (`stand_in` devuelve `null` en `:281`), así que si su `.res` falta, `put()` no dibuja nada (`:175`): `basin`, `bin`, `bookcase_model`, `books`, `boombox`, `box`, `broom`, `cctv_camera`, `ceiling_diffuser`, `clerk_chair`, `clipboard`, `coat_stand`, `coat_wall_rack`, `coffee_maker`, `cord_floor`, `desk_clock`, `desk_fan`, `desk_walnut_suite`, `dot_matrix_printer`, `dustpan`, `emergency_glass`, `emergency_unit`, `fan_unit`, `filing_grey`, `filing_grey_body`, `filing_grey_drawer`, `fire_alarm`, `floor_lamp`, `hand_dryer`, `hose`, `jug`, `lockers`, `magnifier`, `mousetrap`, `notepad`, `plant_hanging`, `plant_terracotta`, `projector_screen`, `shoes`, `smoke_detector`, `spectacles`, `sprinkler`, `stapler`, `stationery`, `television`, `terminal_3178`, `thermos`, `thermostat`, `toolbox`, `towel` y `waiting_pair`.

Otras piezas que se construyen con primitivas y `SurfaceTool`, sin modelo:
- Hotel: muebles de `game/world/hotel/prop_factory.gd` (camas, mesas, armarios, mostradores) con `builder.box` y `builder.cylinder` (`hotel_geometry.gd:530`, `:563`).
- Oficinas: paredes, puertas y piezas en `game/world/office/office_geometry.gd`, `office_walls.gd`, `office_props.gd` y `pieces/*.gd`, con `SurfaceTool` (8 usos en `office_geometry.gd`).
- Cuadros de respaldo: si faltan las láminas, `office_pictures.gd:79-147` dibuja tres tipos (estampas, mapa de ciudad, diploma) y el plano de evacuación.
- Carteles de salida, nota del hotel y tarjeta «No molestar»: dibujados por `tools/textures/make_exit_sign.py`, `bake_hotel_note.py` y `bake_do_not_disturb.py` (`docs/ASSETS.md:10-13`).

### 3.5 Modelos sin fuente recuperable o con licencia pendiente

| Caso | Estado | Fuente | Referencia |
|---|---|---|---|
| Televisor de la escena de entrada (`tv/`) | Licencia no comprobada | Zip local `assets/props/tv/sony-trinitron-prl.zip` (35,1 MB) | `docs/ASSETS.md:72`, `:405` |
| Dormitorio (`bedroom/`) | Licencia no comprobada | Zip local `assets/props/bedroom/bedroom-furniture-set.zip` (17,4 MB) | `ASSETS:72`, `:406` |
| Puerta de madera (`door/`) | Licencia no comprobada | Zip local `assets/props/door/door-wooden-old-9mb.zip` (9,8 MB) | `ASSETS:72`, `:411` |
| Armario (`wardrobe/`) | Licencia no comprobada | `wardrobe.fbx` sin zip identificado | `ASSETS:72` |
| The Locust | No comercial y sin derivadas (CC BY-NC-ND 4.0) | `source_assets/locust.zip` | `ASSETS:110-111`, `:433-437` |
| Realistic Female (`assets/players/realistic_female`) | CC BY-SA 4.0: obliga a compartir las derivadas bajo la misma licencia | `models/realistic-female.zip` | `ASSETS:33`, `:112` |
| Fuente de texto del OSD (`assets/fonts/vcr_osd_mono.ttf`) | Falta en el disco | Ninguna en el repo | `game/ui/osd_style.gd:4` |
| Lurker: imagen de referencia | Origen sin comprobar; el modelo no incluye la imagen | `art/lurker/referencia.webp` | `ASSETS:442` |
| Modelos de Sketchfab pendientes de descarga con sesión | 82 entradas con `status` `needs_login` en los registros | No descargados | Sección 4 |
| Láminas del Art Institute para oficinas no bajadas | 0 descargas; la API del Met devolvió 403 | No hay | `source_assets/oficinas/registro_imagenes.json`, campo `estado` |

Las mallas de hotel y oficinas restantes sí tienen fuente en disco (anexo A), aunque la licencia viene de la ficha que cita `docs/ASSETS.md` (secciones 281-364 y 154-211). Según esas tablas, 55 modelos de hotel son CC0 (Poly Haven), y de las oficinas, 24 son CC0 y 57 CC BY.

---

## 4. Descargas pendientes y faltas de oficinas

Fuente: `source_assets/oficinas/RESUMEN.md` (fecha 22 de octubre, líneas 1-425) y los registros actuales (`source_assets/oficinas/*/registro.json`, 10 grupos, 327 entradas).

- Estados de los 327 registros: `ok` 154, `needs_login` 82, `rejected` 51, `pendiente` 27, `missing` 11, `incluido` 1, `duplicado` 1. Recuento con script.
- `RESUMEN.md` cubre 7 grupos (231 entradas). No incluye `carpinteria`, `muebles_c` ni `objetos`. Los registros de `equipos`, `muebles_a`, `muebles_b` y `muebles_c` cambiaron el 12 y el 14 de noviembre. El resumen no se ha conciliado con los registros.
- `source_assets/oficinas/sketchfab_14nov.txt` lista 36 candidatos Sketchfab CC BY (14 de noviembre). Dos de pago no se bajaron (última línea del archivo).
- `source_assets/oficinas/_herramientas/pendientes.json`: 93 entradas (grupo, slug, fuente y URL) de lo que falta por bajar.
- Faltas de modelado que `RESUMEN.md` pide hacer en el proyecto: archivo móvil con manivela (`:121-123`), fotocopiadora apagada, estación de tubo neumático, compuerta de ducto y bandejas de cables (`:180-185`); vidrio armado y papel térmico (`:213-216`); archivador de dos cajones (`:76-78`).
- Faltas de sonido: reja de tijera que se abre y cierra, gateo sobre chapa, garras sobre placa de falso techo, placa que se levanta (`:337-340`, `:395-398`).
- Dos sonidos solo existen con sesión: la puerta con barra antipánico y las persianas venecianas (`:266-268`).

---

## 5. Texturas y materiales

**Sets escaneados (30):**
- Hotel (12, en `docs/ASSETS.md:122-133`): `carpet016`, `wallpaper001a`, `decrepit_wallpaper`, `ceiling_interior`, `officeceiling001`, `lacquered_cherry_wood`, `dark_wood`, `tiles036`, `metal048b`, `velour_velvet`, `quatrefoil_jacquard_fabric`, `brown_leather`. Todos CC0.
- Oficinas (18, en `ASSETS:373-390`): `office_anti_skid_tiles`, `office_bricks019`, `office_cardboard004`, `office_concrete_wall_008`, `office_cork003`, `office_dark_paneled_wood`, `office_fabric026`, `office_fabric028`, `office_galvanizedsteel02`, `office_hessian_380`, `office_painted_concrete_02`, `office_paintedmetal006`, `office_teak_veneer`, `office_terrazzo003`, `office_tiles032`, `office_tiles043`, `office_tiles110`, `office_walnut_veneer`. Todos CC0.
- Alfombra oriental (`office_rug_met452567`, `ASSETS:397-399`): dominio público del Met. Es un `rug.tres` y `albedo.png` de 1024 px, no un set escaneado.

**Formato de cada set:** `albedo.jpg` (sRGB), `normal.jpg` (convención OpenGL), `orm.jpg` (oclusión, rugosidad y metal en R, G y B) y las mismas en `_1k` (1024 px). Fuente: `assets/textures/README.md`.

**Recuento de imágenes por tamaño (medido en las cabeceras):**

| Carpeta | Imágenes | Tamaños |
|---|---|---|
| `assets/textures/` | 208 | 93 de 1024 px, 87 de 2048 px, 11 de 128 px, 8 de 512 px, y pocas más |
| `assets/props/hotel/` | 207 | 180 de 1024 px, 24 de 2048 px, 3 de 512 px |
| `assets/props/office/` | 334 | 286 de 1024 px, 27 de 2048 px, 18 de 512 px, 3 de 2 × 2 px (sin comprobar su uso) |
| `assets/players/` | 121 | 40 de 2048 px, 37 de 1024 px, 34 de 512 px, 8 de 64 px, 2 de 128 px |
| `assets/paintings/` | 31 | 14 del hotel con ancho fijo de 1024 px (alto de 511 a 1508 px); 17 de oficina con ancho fijo de 843 px |
| `assets/decals/` | 21 | 20 de 512 px y 1 de 1024 px |
| `assets/enemies/` | 6 | 4 de 2048 px, 1 de 1024 px, 1 de 512 px |
| `assets/ui/` | 18 | 256 × 256 px |

**Preset de calidad que elige el mapa de texturas:** `game/presentation/graphics_presets.gd` tiene 5 presets en `PRESETS` (`:183`). El flag `small_maps` (escaneos a 1024 px en vez de 2048) vale `true` en los presets de índice 0 (Bajo, `:191`) y 4 (Muy bajo, `:233`), y `false` en los de 1 a 3 (`:201`, `:211`, `:221`). El índice 0 es Bajo y el 4 es Muy bajo según el orden de `NAMES` (`:20`) y los nombres de `PRESETS` (esto se dedujo del orden, ver sección 15). `hotel_geometry.gd:429-431` guarda `small_maps` como variable estática y la aplica en `:402-404`. Si cambia el preset durante la partida, `apply_quality()` la vuelve a aplicar (`:2579-2584`).

**Texturas lite:** `assets/textures/lite/` tiene una textura pequeña por material (`hotel_geometry.MATERIALS`) y `lite.json`. Las carga `lite_map()` (`hotel_geometry.gd:472-478`) y las usa el preset Muy bajo (`assets/textures/README.md`). El shader de cinta lee `tape_lite` (`presentation_rig.gd:287`).

**Materiales `.tres`:** `game/presentation/materials/*.tres` (49) y `materials/office/*.tres` (56, con 2 `.gdshader`). Los carga `hotel_geometry.gd:401` con `duplicate()`. Cada `.tres` lleva metadatos `scan` (qué set usa) y `lite`. `hotel_geometry.gd:484-490` carga los mapas de un set (`albedo`, `normal`, `orm`) con `ResourceLoader.exists` antes.

**Shaders:** 29 `.gdshader` en `game/`. Los más usados por la geometría son `wood.gdshader`, `wood_lacquer.gdshader`, `exit_panel.gdshader` (`hotel_geometry.gd:1859`, `:2712-2713`), `venetian_blind.gdshader`, `wired_glass.gdshader` (`office_geometry.gd:87-88`) y `ceiling_halo.gdshader` (`:257`).

**Decals (manchas en el suelo y paredes):** `hotel_geometry.gd:767-769` carga el albedo (`res://assets/decals/%s.png`) y la normal (`%s_normal.png`) en un `Decal` (10 usos en `game/`, ver sección 9).

**Cuadros:**
- Hotel: 14 entradas de `assets/paintings/paintings.json`. `hotel_geometry.gd:2662` define `PAINTINGS`; `:2676` carga `%d.jpg` por el id del cuadro.
- Oficinas: 17 entradas de `assets/paintings/office/paintings.json`. `office_pictures.gd:17` (`ART`), `:29` (lee el JSON), `:32` (solo entran las que existen con `ResourceLoader.exists`), `:52` (carga la textura) y `:62` (rugosidad 0,85). El color es `AGED` (0,88; 0,82; 0,68) en `:19`. Hay 6 estampas y 3 mapas de respaldo (`:15-16`).
- Marco de oficina: 0,75 de anchura para las estampas (retrato) y 1,47 para las vistas de ciudad (`:22`).

**Fuentes de los cuadros y decals:** Art Institute of Chicago (CC0) para los 31 cuadros (`docs/ASSETS.md:234-273`). ambientCG y Poly Haven para los decals (`ASSETS:216-232`). Originales en `source_assets/paintings/` (15 + 18 archivos, 10 MB en total) y `source_assets/decals/` (13 zips, 65 MB).

---

## 6. Audio

**Recuento (`assets/audio/`, 202 audios):**
- 163 WAV (70,4 MB), 37 OGG (1,3 MB), 1 MP3 (`the_four_theme.mp3`, 5,9 MB, 384,63 s; `ASSETS:505`), 1 M4A (`bed-sound.m4a`, 0,6 MB).
- `assets/audio/hotel/ambience.wav`: 410,46 s, estéreo, 11 025 Hz, PCM de 8 bits (`ASSETS:18`). Es la copia de `ambience.wav` de la raíz.
- Subcarpetas de `assets/audio/sfx/` (164 archivos, 58,2 MB): `lurker` (56), `office` (19), `door` (18), `footsteps` (32), `wardrobe` (8), `blood` (5), `search` (8), `lift` (4), `ambience` (1, 41,3 MB, `dark_hotel.wav`), `presence` (1, 2,2 MB), `camera` (2), `flashlight` (6), `heartbeat` (2), `paper` (1) y `chase` (1).

**Procedencia (`docs/ASSETS.md`):**
- Freesound con licencias CC0 y CC BY (`:78-98`, tabla de 19 filas: 10 CC0 y 9 CC BY). Las CC BY piden crédito en los créditos del juego.
- BigSoundBank (CC0), en `:449-463` (13 filas).
- Pixabay Content License (no pide atribución; prohíbe revender el archivo suelto) en `:458`, `:462-463` y `:481-494`.
- SoundBible (CC BY 3.0) para la fotocopiadora (`:460`).
- Sonidos de Freesound que salieron del juego por no comerciales: `:104`.

**Cargas en código y sus clases (apariciones en `game/`):**
- `AudioStreamPlayer3D` 52 (16 archivos), `AudioStreamPlayer` 84 (18 archivos), `AudioStreamWAV` 15 (5 archivos), `AudioStreamOggVorbis` 2 (2), `AudioStreamMP3` 1 (1).
- Bucles: `world_audio.gd:188-195` (`loop_stream()`: `LOOP_FORWARD` y `loop_end` para WAV; `loop = true` para OGG y MP3). `presentation_rig.gd:450-453` y `intro_sequence.gd:498-502` hacen lo mismo.
- Buses: los nombres `Effects`, `Threat` y `Steps` aparecen en `intro_sequence.gd:444-455`; `world_audio.gd` crea un bus de conductos (`ensure_duct_bus()`, `:528`).
- Lista de sonidos: `game/app/executions.gd:52-59` (grito, golpe, estática, pasos), `game/intro/intro_sequence.gd:444-469` (voces de la intro), `game/app/lifts.gd:205-208` (ascensor), `game/world/interactables/hotel_container.gd:73-85` (cajones y cajas), `game/app/hallucinations/lurker_hallucinations.gd:353-377` y `:518` (sonidos del Lurker).
- Sonidos generados en código: `game/enemies/locust/hotel_locust.gd:475-477` (sonido de zarpazo) y `game/ui/osd_style.gd:230-248` (pitidos de interfaz).

**Archivos de audio que el código no nombra literalmente:** 41 WAV de `assets/audio/` no aparecen por nombre en `game/`, `tools/` ni `docs/`. La mayoría se carga con nombres construidos (`"tile_%d.wav"`, `"knock_%d.wav"`, `"cue_%d.wav"`). Ver sección 15.

**Originales de audio:**
- `sfx/`: 60 audios (18 WAV, 3 MP3, 39 OGG), copia de trabajo en `assets/audio/sfx/` (`docs/ASSETS.md:527-529`).
- `source_assets/audio/` (9 archivos, 43 MB): `ambience.wav`, `deep_ambiance.flac`, `deep_atmosphere_short.wav`, `piercing-glitchy-voice-sfx.wav`, `726475__ultraameise__liminal-beep.mp3`. Ninguno tiene referencia en `game/`, `tools/` ni `tests/` (grep). El de voz tiene nivel alto y «requiere edición» (`ASSETS:19`). Por la regla del proyecto, no hay voces humanas sintéticas (`CLAUDE.md`).
- `source_assets/oficinas/audio_criatura/`, `audio_edificio/` y `audio_oficina/` (36, 52 y 32 registros, de los que 19, 24 y 16 están en estado `ok`).

---

## 7. Cadena de horneado (de la fuente al juego)

| Herramienta | Entrada | Salida | Constantes que cambian la forma o el tamaño |
|---|---|---|---|
| `tools/props/build_catalogue.gd` | `source_assets/props/<id>/` (glTF) y `source_assets/oficinas/…` con `--sources` | `assets/props/hotel/*.res`, `assets/props/office/*.res` | `YAW` `:23`, `SCALE` `:25`, `SKIP` `:31`, `PARTS` `:36`, `PLACED` `:73`, `CLOCKS` `:82`, `MOVING` `:101`, `SHUT` `:114`, `LAID` `:122`, `ASKEW` `:124`. LOD con `generate_lods(60.0, 25.0, [])` (`:339`, `:438`, `:549`) |
| `tools/props/build_model_props.gd` | `tv/old_tv.fbx`, `bedroom/bedroom_set.fbx`, `sofa/sofa.fbx`, `wall_lamp/wall_lamp.fbx`, `monstera/monstera.fbx` | `.res` de cada carpeta | Tamaño real en metros: 0,62, 2,1, 2,15, 0,42 y 1,35 (`:12-16`) |
| `tools/props/build_door.gd` | `door/door.fbx` | `door_leaf.res`, `door_frame.res` | `OPENING_HIGH` 2,65 (`:18`); escalas en `:87` y `:94` |
| `tools/props/build_elevator.gd` | `elevator/elevator.fbx` | `lift_*.res` | `LIFT_SCALE` 0,8 (`:22`) |
| `tools/props/build_camcorder.gd` | `camcorder_body.obj`, `camcorder_glass.obj`, `vhs_tape.dae` | `camcorder.res`, `vhs_tape.res` | `CAMCORDER_LENGTH` 0,27 (`:15`), `TAPE_LENGTH` 0,187 (`:17`) |
| `tools/props/build_wardrobe.gd` | `assets/props/wardrobe/wardrobe.fbx` | `wardrobe_body.res`, `wardrobe_leaf_*.res` | `SOURCE` `:7`, `OUTPUT` `:8`, `DOOR_PARTS` `:10`, `SIZE` (1,25 × 2,3 × 0,78) `:12` |
| `tools/props/fit_models.json` (lo escribe `fit_model.py`, no leído) | Medidas por pieza (60 entradas) | Lo consumen los scripts de horneado de oficina | Escalas de oficina |
| `tools/props/ingest_models.py` (602 líneas) | `source_assets/` | Registros, carpetas `_gltf/`, `sources.json` | No leído en su totalidad (sección 14) |
| `tools/props/fetch_models.py` (57) | Descarga de Poly Haven con md5 | `source_assets/props/` | No leído en su totalidad |
| `tools/props/decimate.py` (130) y `add_mesh_lods.gd` (42) | Mallas | Mallas con menos triángulos | No leídos en su totalidad |
| `tools/textures/ingest_pbr.py` | `source_assets/textures/` y `oficinas/materiales/` | `assets/textures/<set>/` (2048 y 1024) y el bloque `SCANS` de `docs/ASSETS.md:115` | No leído |
| `tools/textures/bake_lite_maps.gd` | Los sets y los shaders | `assets/textures/lite/` | No leído |
| `tools/avatars/bake_survivor_clips.gd` | `models/mixamo/*.fbx` y el esqueleto | `assets/players/<id>/clips.res` | No leído |
| `tools/art/lurker/*.py` (Blender) | `art/lurker/lurker.blend` | `assets/enemies/lurker/lurker.glb` | No leídos |
| `tools/audio/prepare_*.py` (7 scripts) | `sfx/`, `source_assets/oficinas/audio_*` | `assets/audio/sfx/*` | Recortes y ganancias (no leídos a fondo) |

---

## 8. Dónde se carga cada familia en el juego (`ruta:línea`)

| Archivo | Líneas | Carga | Cómo |
|---|---|---|---|
| `game/world/office/office_models.gd` | `:11-16` | Precarga los scripts de sustitutos | `preload` |
| | `:154`, `:156` | Caché estática de modelos y de «frente» por instancia | `static var` |
| | `:160-168` | `mesh_of()`: carga el primer `.res` que existe, o usa el sustituto | `load()` solo si `ResourceLoader.exists` |
| | `:173-186` | `put()`: coloca el modelo con `builder.place()` | |
| | `:229-235` | `backed()`: lee los vértices del Mesh para saber de qué lado está el respaldo | `get_instance_id()`, `surface_get_arrays()` |
| `game/world/hotel/prop_factory.gd` | `:7-8` | `SOFA` y `MONSTERA` | `preload` |
| | `:20-21` | Cuerpo y pantalla del televisor | `preload` |
| | `:42-43`, `:46-51` | `put()` con `DRESSING.mesh()`, y `model()` que crea un `MeshInstance3D` | |
| `game/world/hotel/room_dressing.gd` | `:16-17` | Ruta `assets/props/hotel/%s.res` y `MONSTERA` | |
| | `:55-59` | `mesh(name)`: caché estática y `load()` | `load()` |
| | `:404` | Comprueba si existe `<nombre>_body.res` | `ResourceLoader.exists` |
| `game/world/hotel/hotel_geometry.gd` | `:286-292` | Candelabro, lámpara de pared, hojas y marco de puerta | `preload` |
| | `:401-404` | Materiales `.tres` y escaneos al construir | `load()` y `duplicate()` |
| | `:439`, `:472-478` | Texturas lite | `load()` |
| | `:484-490` | Mapas de un set | `load()` con `ResourceLoader.exists` |
| | `:752` | Mano del reloj | `load()` |
| | `:767-769` | Decals | `load()` |
| | `:1644-1647` | Ascensor | `preload` |
| | `:1859-1860`, `:1925-1930` | Señal de salida y señales de ruta | `preload` |
| | `:2662-2676` | Cuadros del hotel | `load()` con `%d.jpg` |
| | `:2692` | Marco de pie | `load()` |
| | `:2788-2790` | Rutas de sonido de ascensor y zumbido | Cadenas |
| `game/world/office/office_geometry.gd` | `:287-288` | Materiales `.tres` opcionales | `ResourceLoader.exists` y `load()` |
| | `:1981`, `:2068-2072` | Regleta fluorescente | `ResourceLoader.exists` y `load()` |
| | `:2198-2219` | Puertas y marcos de oficina | `load()` con `ResourceLoader.exists` |
| `game/world/office/office_props.gd` | `:559-570` | Papeleras, plantas y macetas de recepción | `load(path)` |
| | `:662-670` | Escritorio de la oficina | `ResourceLoader.exists` y `load()` |
| `game/world/office/office_fittings.gd` | `:36`, `:161-168` | Alfombra oriental | `load()` |
| `game/world/office/office_pictures.gd` | `:17`, `:29`, `:32`, `:52` | Carpeta de cuadros, índice JSON, comprobación y textura | `FileAccess`, `ResourceLoader.exists`, `load()` |
| `game/world/office/main_duct_geometry.gd` | `:20`, `:223-228` | Escalera del conducto | `load()` |
| | `:246-248` | Cráneo: si falta el modelo, se dibuja una caja | `ResourceLoader.exists` |
| | `:261-273` | Cráneo: `.obj` y tres PNG (color, normal y rugosidad) | `load()` |
| `game/player/avatars/avatar_visual.gd` | `:59` | `model.fbx` del personaje | `load()` y `instantiate()` |
| | `:107` | `clips.res` | `load()` |
| | `:117` | `model.obj` del detective | `load()` |
| | `:210` | Textura de relieve | `load()` |
| `game/app/presentation_rig.gd` | `:218`, `:287` | Escaneos y cinta lite según el preset | |
| | `:422-478` | Sonidos de papel, estática, ambiente, música y ventilación | `load()` y `duplicate()` |
| `game/intro/intro_sequence.gd` | `:444-469` | Voces de la intro | `voice3d`, `voice2d` |
| | `:498-502` | Bucles | `loop_mode` |
| | `:548`, `:563`, `:574` | Cama, cuerpo de la tele y pantalla | `load()` |
| `game/app/executions.gd` | `:22`, `:52-59` | Videocámara y sonidos de la ejecución | `preload` y cadenas |
| `game/app/lifts.gd` | `:205-208`, `:534` | Sonidos del ascensor | Cadenas |
| `game/world/interactables/hotel_container.gd` | `:27`, `:73-85`, `:174-208` | Llave, sonidos por mueble y piezas de contenedor | `preload` y `load()` |
| `game/ui/osd_style.gd` | `:4`, `:20-21`, `:22-29` | Fuente OSD (no existe en disco) y, si falta, `SystemFont` con lista de sistema | `ResourceLoader.exists` y `load()`; si no, `SystemFont` |
| `game/audio/world_audio.gd` | `:131`, `:155`, `:188-195` | Creación de fuentes de audio y bucles | |
| `game/presentation/graphics_presets.gd` | `:183-233`, `:304` | Presets (escala, escaneos a 1024 o 2048 px) | `PRESETS[...]` |

---

## 9. Clases y nodos de Godot que usa esta parte (apariciones aproximadas)

Recuento con `grep -F` sobre `game/**/*.gd`, `*.tscn`, `*.tres` y `*.gdshader`. Las cifras son el número de líneas que contienen el texto (una línea puede contar dos veces). El número de archivos es el de archivos distintos.

| Clase o llamada | Apariciones | Archivos | Función en esta parte (lo que habría que sustituir) |
|---|---|---|---|
| `load(` | 645 | 133 | Carga de todo lo de `assets/` y de `game/` |
| `preload(` | 558 | 131 | Carga de scripts y de recursos fijos |
| `ResourceLoader` (`exists`) | 21 | 15 | Fallbacks: si falta un `.res`, se usa el sustituto |
| `ArrayMesh` | 344 | 23 | Geometría procedural de paredes, muebles y cajas |
| `SurfaceTool` | 23 | 6 | Geometría procedural (`office_geometry.gd` 8 usos; `hiding_place.gd` 3) |
| `add_surface_from_arrays` | 4 | 4 | Mallas hechas a mano |
| `surface_get_arrays` | 7 | 7 | Lectura de vértices (`office_models.gd:235`) |
| `surface_set_material` | 11 | | Asignar material por superficie |
| `MeshInstance3D` | 155 | 32 | Nodo que muestra un Mesh |
| `MultiMeshInstance3D` | 30 | 7 | Un MultiMesh por material y habitación (`hotel_geometry.gd:506-509`, `office_models.gd:9`) |
| `BoxMesh` | 29 | | Cajas primitivas |
| `QuadMesh` | 20 | | Cuadros y planos |
| `CylinderMesh`, `SphereMesh`, `PlaneMesh`, `CapsuleMesh` | 5, 3, 8, 1 | | Primitivas |
| `StandardMaterial3D` | 92 | 55 | Materiales de color plano |
| `ShaderMaterial` | 146 | 88 | Materiales con shader (`ShaderMaterial.new()` 26) |
| `Texture2D` | 85 | 29 | Texturas en materiales |
| `ImageTexture` (`create_from_image`) | 24 | 11 | Texturas hechas en código (cuadros de respaldo) |
| `Image` | 13 | 10 | Imágenes hechas en código (`office_pictures.gd`) |
| `Decal` | 10 | 3 | Manchas de suelo y pared (`hotel_geometry.gd:767-769`) |
| `Skeleton3D` | 17 | 8 | Personajes y criaturas |
| `AnimationPlayer` | 7 | 4 | Animaciones de la criatura y las puertas |
| `PackedScene` (`instantiate`) | 9 (8) | 6 | Escenas `.glb` y `.fbx` |
| `AudioStreamPlayer3D` | 52 | 16 | Sonido posicionado |
| `AudioStreamPlayer` | 84 | 18 | Sonido sin posición |
| `AudioStreamWAV` | 15 | 5 | Bucles y pitidos generados |
| `AudioStreamOggVorbis` | 2 | 2 | Bucles OGG |
| `AudioStreamMP3` | 1 | 1 | Música |
| `CollisionShape3D` / `BoxShape3D` | 28 / 19 | 18 / 13 | Colisiones por cajas (no hay `create_trimesh_shape` ni `create_convex_shape` en `game/`) |
| `OmniLight3D` / `SpotLight3D` | 50 / 27 | 11 / 12 | Luces de los muebles y de las salas (en el mismo código de geometría) |
| `VoxelGI` / `ReflectionProbe` | 15 / 5 | 6 / 2 | Iluminación indirecta, no es asset, pero se monta con la geometría |

Llamadas que **no** aparecen en `game/` (todo lo de bake está en `tools/`): `ImporterMesh` 0, `GLTFDocument` 0, `ResourceSaver` 0, `generate_lods` 0, `generate_tangents` 0, `create_trimesh_shape` 0, `create_convex_shape` 0, `CompressedTexture2D` 0, `Texture2DArray` 0.

---

## 10. Constantes y cifras que definen cómo se ve o se siente (`ruta:línea`)

**Escalas y tamaños de muebles de oficina** (`game/world/office/office_models.gd`):
- `:22` silla apilable escala 0,8.
- `:25` `reception_seat` altura 0,83 m. `:32` `office_chair` altura 0,95 m. `:34` `exec_chair` altura 1,24 m. `:36-37` `clerk_chair` y `visitor_chair` altura 0,88 m.
- `:40` `plant_tall` altura 1,45 m. `:41` `plant_small` altura 0,25 m.
- `:44` papelera escala 0,62. `:55` monitor CRT altura 0,36 m.
- `:133` `GREY_PITCH` = 0,2988 m (separación de cajones del archivador). `:134` `GREY_OUT` = 0,3 m.
- `:140` `POTS`: 0,4 × 0,38 × 0,4 m (oscura) y 0,2 × 0,16 × 0,2 m (cerámica).
- `:142` `LIT_MOST` = 1 (una lámpara iluminada por habitación como máximo).
- `:147-152` `LIGHTS`: energía 1,4, 1,4, 1,0 y 0,7; alcance 2,8, 2,6, 2,4 y 3,5 m; ángulo 42°, 40°, 70° y 70° (lámpara de banquero, flexo, lámpara de pie y expendedora).
- `:203` `CAST_LEAST` = (0,9; 0,6; 0,2): tamaño mínimo para que un mueble proyecte sombra (ver también `:207`).

**Cuadros** (`game/world/office/office_pictures.gd`):
- `:11` `SIZE` = 256 px (textura de respaldo). `:15` `PRINTS` = 6. `:16` `MAPS` = 3.
- `:12-13` `PAPER` (0,8; 0,76; 0,66) e `INK` (0,26; 0,22; 0,18).
- `:19` `AGED` (0,88; 0,82; 0,68) como color de albedo de las láminas.
- `:22` `OPENING`: estampa 0,75 y ciudad 1,47 (proporción del marco).
- `:62` rugosidad 0,85.

**Televisor del hotel** (`game/world/hotel/prop_factory.gd`):
- `:24` `TV_SCALE` = 0,82 / 0,62. `:25` `TV_TOP` = 1,212 m (altura de la encimera). `:22` `TV_STAND` = `GothicCommode_01`.

**Muebles del hotel** (`prop_factory.gd`):
- `:60` cama escalada a (1,9 / 1,49; 1,0; 2,6 / 2,04). `:71` `sofa_03` a 2,3 / 2,73. `:72` `Sofa_01` a 1,3. `:76` mesita a 1,2. `:192` papeleras a 0,62.
- `:189` monstera girada según la posición (`builder.vary`).

**Decoración del hotel** (`game/world/hotel/room_dressing.gd`):
- `:20` `INSET` = 0,2. `:23` `WALL_FACE` = -0,11. `:26` `NEAR` = 1,35. `:27` `FAR` = 3,05. `:28` `FAR_DOMESTIC` = 2,6. `:51` `WARDROBE_HALF` = 0,75.
- `:47-49` listas de adornos, cosas de almacén y botellas (`ORNAMENTS`, `STORE_THINGS`, `BOTTLES`).

**Geometría de la oficina:** `game/world/office/main_duct_geometry.gd:262` `SKULL_SCALE` = 0,073 (0,14 m de ancho, `:248`).

**Presets de calidad** (`game/presentation/graphics_presets.gd`):
- Escala de render por preset: `:185` 0,67 (Bajo), `:195` 0,85 (Medio), `:205` 1,0 (Alto), `:215` 1,0 (Ultra), `:227` 0,5 (Muy bajo).
- Escaneos a 1024 px: `:191` (Bajo) y `:233` (Muy bajo). A 2048 px: `:201`, `:211`, `:221`.
- Sombras: `shadow_atlas` 4096 en el preset de índice 0 (`:186`).

**Calibración de la cinta** (`game/presentation/graphics_presets.gd`): `tape_lite` true solo en Muy bajo (`:227` en adelante).

**Ajustes de horneado** (`tools/props/build_catalogue.gd`):
- `generate_lods(60.0, 25.0, [])` en `:339`, `:438` y `:549` (ángulos de fusión de normales 60° y de división 25°). Las LOD son las que hace Godot en el bake, no las de un artista.

**Ajustes de import de la criatura** (`assets/enemies/lurker/lurker.glb.import`): `meshes/generate_lods=true` (`:27`), `meshes/create_shadow_meshes=true` (`:28`), `meshes/light_baking=1` (`:29`), `animation/fps=30` (`:34`).

**Presupuestos de triángulos** (`tests/office/office_dressing_test.gd:24-25`): 5 000 para piezas pequeñas (`SMALL_TRIANGLES`) y 20 000 para grandes (`BIG_TRIANGLES`). La misma cifra de 5 000 aparece en `tests/office/office_pieces_test.gd:32`, y `:203-205` lo comprueba para cada pieza.

**Partes de docs que dan cifras de diseño** (sin código equivalente comprobado): la escala 1,65 del Locust (`docs/ASSETS.md:435`; no encontré esa constante en `game/enemies/locust/`); y la altura 2,46 m medida del Locust (`ASSETS:435`).

---

## 11. Orden de ejecución, física y azar

**Carga perezosa y cachés:**
- Los modelos se cargan la primera vez que se piden (`office_models.gd:166`, `room_dressing.gd:58`, `office_pictures.gd:52`). Después se guardan en variables estáticas (`office_models.gd:154`, `room_dressing.gd:55`, `office_pictures.gd:24`, `hotel_geometry.gd:431`), que duran mientras el proceso viva, entre plantas y partidas.
- `office_models.gd:229-230` guarda el resultado de `backed()` por `get_instance_id()`. Ese id cambia entre sesiones: la caché no sobrevive a un reinicio.
- `office_pictures.gd:37-44` guarda los cuadros en metadatos del `builder` (`set_meta("office_pictures")`), por construcción.

**Orden con la calidad:**
- `presentation_rig.gd:218` pone `small_maps` en el generador antes de construir el piso.
- `hotel_geometry.gd:2579-2584` vuelve a aplicar los escaneos si cambia el preset durante la partida (`apply_quality()`).
- `hotel_geometry.gd:401-404` aplica los escaneos al crear los materiales, así que el orden entre crear el piso y fijar la calidad importa.

**Azar:**
- La decoración del hotel no consume el generador: `hotel_geometry.gd:503-504` (`vary()`) es un hash de la posición, la «sal» y la semilla del piso (`looks`), con `sin` y `fposmod`. Dos máquinas con la misma semilla visten igual cada habitación.
- Los cuadros de respaldo usan `KIT.hash01` (`office_pictures.gd:84-115`), también determinista.
- Azar sin semilla (`RandomNumberGenerator.new()` sin `seed`): `game/audio/world_audio.gd:68` (elige el sonido de un grupo, `:209`; variación de tono 0,98 a 1,02, `:410`; zumbido y siseo con inicio aleatorio, `:768`, `:797`); `game/audio/dread_aura.gd:58` (cadencia y tono de los chasquidos, `:238`, `:253-259`); `game/app/hallucinations/lurker_hallucinations.gd:72` (sonidos del Lurker, `:353-377`, `:518`, y el barajado de `:605-607`); `game/world/office/office_geometry.gd:1327` (opacidad de las motas de polvo, `:1344`). No hay `rng.seed` en `game/audio/` ni en `game/app/` (grep).
- Las semillas que sí existen son las de generación: `game/world/generation/*.gd` usan `hash([…])` con la semilla del piso (`digit_placement.gd:20`, `map_generator.gd:141`, `office_generator.gd:1015`). No se leyeron en detalle.

**Física:**
- La audio espacial corre en `_physics_process` (`world_audio.gd:660`) y llama a `step_physics()` (`:667`), así que el sonido se actualiza en el paso de física y no en el de render.
- La geometría de las cajas de colisión es `builder.box(..., solid = true)` (`hotel_geometry.gd:530`); las mallas visibles no tienen colisión (`prop_factory.gd:1-4`).
- Las sombras se activan por tamaño: `office_models.gd:204-207` (`casts()`). Un mesh con `has_meta("casts")` siempre proyecta sombra.

**Metadatos que el código lee de los Mesh y materiales:** `has_meta("piece")` (`office_models.gd:179`, `:218`), `has_meta("casts")` (`:205`), `has_meta("stand_in")` y `get_meta("lite")` (`tests/office/office_finishes_test.gd:109`), `get_meta("triangles")` (`tests/office/office_pieces_test.gd:203`), `get_meta("box")` (`hotel_container.gd:208`), `get_meta("hands")` (`hotel_geometry.gd:750-751`) y `get_meta("pivot")` (`hotel_geometry.gd:755`, `hotel_container.gd:185`, `hotel_panel.gd:50`). Los pone `tools/props/build_catalogue.gd` (`:343-345`, `:442-445`). Esto hay que replicarlo si se porta.

**Señales:** no se estudiaron (sección 15).

---

## 12. Pruebas de `tests/` que vigilan esta parte

| Prueba | Líneas | Qué vigila |
|---|---|---|
| `tests/office/office_dressing_test.gd` | `:21` (lista `OWN`), `:23` (`STAND_ONLY`), `:24-25` (presupuestos), `:36-51` (carga cada `.res` y cuenta triángulos), `:51` (comprobación final) | Que cada modelo de oficina esté horneado y quepa en su presupuesto |
| `tests/office/office_pieces_test.gd` | `:32`, `:99`, `:201`, `:203-205`, `:225` | Presupuesto de triángulos por pieza, material propio con lite, sustitutos y brillo de la luz |
| `tests/office/office_finishes_test.gd` | `:109-110`, `:291-325` | Que la oficina use su material y su lite, y que las puertas usen `OG.DOOR_MODELS` |
| `tests/office/office_light_test.gd` | `:113-114` | Colores de los sustitutos de la luz |
| `tests/hotel/scene_contract_test.gd` | `:114-134`, `:325-326` | Relojes (`%s.res` y manecillas), espejo, lápices, y que todas las carpetas de `assets/players/` tengan `model.fbx` |
| `tests/hotel/stages_test.gd` | `:7`, `:32` | Formas de colisión de los modelos de escena (`create_trimesh_shape`) |
| `tests/hotel/hotel_test.gd` | `:473-476` | Material de los cuadros (`paintings()[0].mesh.material`) |
| `tests/hotel/palette_scan_test.gd` | `:65-66`, `:74` | Que las constantes de `room_dressing.gd` y `prop_factory.gd` no cambien |
| `tests/hotel/spatial_audio_test.gd` | `:347` | Sonido posicionado del grito de la ejecución |
| `tests/hotel/survival_test.gd` | `:70`, `:80` | Sonidos del zoom de la cámara (`zoom_in.wav`, `zoom_out.wav`) |

Las pruebas `hotel/manifest_golden_test.gd` y `hotel/creature_contract_test.gd` no miran assets de forma directa, pero sí el piso que los usa.

No hay prueba de que la fuente del OSD exista. No hay prueba de que `assets/fonts/` exista. No hay prueba que mire los 216 `.res` juntos.

---

## 13. Integridad y conservación

- `docs/asset_hashes.json`: 674 entradas. Cada clave es una ruta (`assets/...` o `source_assets/...`) y su valor es `{bytes, sha256}`. Cubre: 569 de `assets/props/office/` (todos los `.res`, `.tres`, JPG y PNG de oficina), 76 de `assets/audio/`, 18 de `assets/paintings/`, 8 de `assets/textures/`, 1 de `assets/enemies/` (`locust.glb`) y 2 de `source_assets/` (`locust.zip` y `song.mp3`). Comprobado con script: 674 de 674 coinciden en tamaño y SHA-256 (155 MB leídos).
- No están en el hash: los `.res` de hotel (101), los de personaje, los decals, los de UI y casi todo el audio. Tampoco los originales de `source_assets/` salvo esos dos.
- `.gitignore`: `.godot/`, `source_assets/`, `/sfx/`, `/models/`, `assets/props/**/*.zip`, `evidence/*.avi`, `evidence/bench/`, entre otros. `.gitattributes`: `*.png`, `*.jpg` y `*.glb` como binarios; `*.gd`, `*.tscn`, `*.tres` y `*.json` como texto.
- Los zips de `assets/props/` (8, 467 MB): `plants/monstera-indoor.zip` (159,6 MB) y `plants/indoor-plant-dieffenbachia.zip` (171,7 MB, sin usar: solo tiene `.blend`, `ASSETS:410`), `key/key-chain.zip` (59,3 MB), `tv/sony-trinitron-prl.zip` (35,1 MB), `bedroom/bedroom-furniture-set.zip` (17,4 MB), `other/wall-lamp-2048px2.zip` (10,7 MB), `door/door-wooden-old-9mb.zip` (9,8 MB) y `other/sofa-pbr.zip` (3,5 MB).
- Los `.zip` de `models/` (6): `detective.zip` (29,4 MB), `detective-woman.zip` (39,3 MB), `realistic-female.zip` (108,9 MB), `panasonic-vhs-c-movie-camera-nv-a3.zip` (21,9 MB), `vhs.zip` (4,1 MB) y `soviet-old-wardrobe.zip` (36,3 MB).
- Sin fuente recuperable dentro del repo: la fuente de texto del OSD (`vcr_osd_mono.ttf`) y `ink_noise.res`.

---

## 14. Archivos leídos

**Lectura completa:**
- `docs/ASSETS.md` (530 líneas): procedencia, licencias y pendientes de todo el juego.
- `source_assets/oficinas/RESUMEN.md` (425 líneas, en 3 tramos): resumen de búsquedas y faltas de oficinas (22 de octubre).
- `source_assets/oficinas/registro_imagenes.json`: estado de la búsqueda del Met (403 y pendientes).
- `source_assets/oficinas/sketchfab_14nov.txt` (36 candidatos Sketchfab y 2 de pago).
- `source_assets/oficinas/_herramientas/recoger_descarga.py` (52 líneas): espera la descarga en la carpeta Descargas del usuario y la mueve a `source_assets/`.
- `assets/textures/README.md` (30 líneas): sets, presets y cómo se generan.
- `game/world/office/office_models.gd` (299 líneas): catálogo de modelos de oficina.
- `game/world/office/office_pictures.gd` (174 líneas): cuadros y láminas de oficina.
- `game/world/hotel/prop_factory.gd` (219 líneas): muebles del hotel.
- `tools/props/build_model_props.gd` (75 líneas, casi entero): bake de los 5 modelos de `JOBS`.
- `.gitignore` y `.gitattributes` (completos).
- `tests/office/office_dressing_test.gd`, líneas 13-51: presupuesto de triángulos.
- `.import` de `assets/textures/brown_leather/albedo.jpg`, `assets/enemies/lurker/lurker.glb` y `assets/audio/hotel/ambience.wav` (muestras).

**Lectura parcial (por tramos o con `grep`):**
- `docs/asset_hashes.json` (120 KB): estructura y verificación con script de las 674 entradas.
- `source_assets/oficinas/registro.json` (10 grupos) y `registro_polyhaven_modelos.json` (39) y `registro_materiales_2.json` (34): estados, licencias y motivos por script.
- `source_assets/oficinas/_herramientas/pendientes.json` (93 entradas): estructura y campos.
- `game/world/hotel/room_dressing.gd` (líneas 15-60 y las de carga).
- `game/world/hotel/hotel_geometry.gd` (3 298 líneas): 498-512, 400-432, 2579-2584 y `grep` de cargas y `vary`, `box`, `place`.
- `game/world/office/office_geometry.gd` (2 841): `grep` de cargas y de `DOOR_MODELS`.
- `game/world/office/office_props.gd` (759), `office_fittings.gd` (295), `main_duct_geometry.gd` (318): `grep`, y 258-273 y 20 y 223-228 de main_duct.
- `game/player/avatars/avatar_visual.gd` (778), `game/app/presentation_rig.gd` (494), `game/intro/intro_sequence.gd` (665), `game/app/lifts.gd`, `game/app/executions.gd`, `game/world/interactables/hotel_container.gd` (415): `grep` de cargas.
- `game/audio/world_audio.gd` (816): nombres de funciones y líneas de aleatoriedad.
- `game/audio/dread_aura.gd` y `game/app/hallucinations/lurker_hallucinations.gd`: `grep` de `rng`.
- `game/presentation/graphics_presets.gd`: `PRESETS`, `small_maps`, `tape_lite` y `scale` por `grep -n`.
- `tools/props/build_catalogue.gd` (555): líneas 1-30 y 325-350, y `grep` de rutas y constantes.
- `tools/props/build_door.gd`, `build_elevator.gd`, `build_camcorder.gd`, `build_wardrobe.gd`: `grep` de constantes.
- `tools/props/fit_models.json` (1 609 líneas): estructura y `_doc`.
- `tests/office/office_pieces_test.gd`, `tests/office/office_finishes_test.gd`, `tests/hotel/scene_contract_test.gd`, `stages_test.gd`, `hotel_test.gd`, `palette_scan_test.gd`, `spatial_audio_test.gd`, `survival_test.gd`: `grep` de las líneas citadas.
- `project.godot`: `grep` de `icon` y `vram_compression`.
- `game/ui/osd_style.gd`: `grep` de la fuente.
- `assets/paintings/paintings.json` y `assets/paintings/office/paintings.json`: estructura.

**No leídos:**
- `tools/props/ingest_models.py` (602), `fetch_models.py` (57), `decimate.py` (130), `add_mesh_lods.gd` (42), `prepare_key_textures.py`, `tools/textures/ingest_pbr.py`, `bake_lite_maps.gd`, `bake_hotel_note.py`, `bake_do_not_disturb.py`, `make_exit_sign.py`, `bake_blood.py`, `tools/avatars/bake_survivor_clips.gd`, `tools/art/lurker/*`, `tools/audio/prepare_*.py`.

**Recuentos por script** (no son archivos del repo): inventario por carpeta, extensiones, tamaños, `.import`, hashes, trazado de origen de los `.res` y de los sets, dimensiones de imágenes (cabeceras JPEG y PNG), `grep` de rutas `res://` y verificación de existencia.

---

## Anexo A: origen de cada malla horneada (`.res`)

Generado con script a partir de `assets/props/hotel/*.res` y `assets/props/office/*.res`, emparejando el nombre del `.res` con el nombre de la carpeta de origen en `source_assets/`. Cuando el nombre del `.res` no coincide con una carpeta, se usa la carpeta del modelo padre («parte de»). Recuento: hotel 91 directos y 10 partes; oficinas 93 directos y 2 partes; ninguno sin origen. Formatos: hotel 100 glTF y 1 FBX (`key_chain`); oficinas 94 glTF y 1 con glTF y FBX.

| Grupo | Modelo horneado (.res) | Carpeta de origen | Formato en disco | Ejemplo de archivo fuente |
|---|---|---|---|---|
| hotel | `ArmChair_01.res` | ArmChair_01 | gltf | `source_assets/props/ArmChair_01/ArmChair_01_2k.gltf` |
| hotel | `CashRegister_01.res` | CashRegister_01 | gltf | `source_assets/props/CashRegister_01/CashRegister_01_1k.gltf` |
| hotel | `Chandelier_02.res` | Chandelier_02 | gltf | `source_assets/props/Chandelier_02/Chandelier_02_1k.gltf` |
| hotel | `ClassicConsole_01.res` | ClassicConsole_01 | gltf | `source_assets/props/ClassicConsole_01/ClassicConsole_01_2k.gltf` |
| hotel | `ClassicNightstand_01.res` | ClassicNightstand_01 | gltf | `source_assets/props/ClassicNightstand_01/ClassicNightstand_01_2k.gltf` |
| hotel | `GothicBed_01.res` | GothicBed_01 | gltf | `source_assets/props/GothicBed_01/GothicBed_01_2k.gltf` |
| hotel | `GothicCommode_01.res` | GothicCommode_01 | gltf | `source_assets/props/GothicCommode_01/GothicCommode_01_2k.gltf` |
| hotel | `GothicCommode_01_body.res` | GothicCommode_01 | gltf | `source_assets/props/GothicCommode_01/GothicCommode_01_2k.gltf` |
| hotel | `GothicCommode_01_drawer_1.res` | GothicCommode_01 | gltf | `source_assets/props/GothicCommode_01/GothicCommode_01_2k.gltf` |
| hotel | `GothicCommode_01_drawer_2.res` | GothicCommode_01 | gltf | `source_assets/props/GothicCommode_01/GothicCommode_01_2k.gltf` |
| hotel | `GothicCommode_01_drawer_3.res` | GothicCommode_01 | gltf | `source_assets/props/GothicCommode_01/GothicCommode_01_2k.gltf` |
| hotel | `GreenChair_01.res` | GreenChair_01 | gltf | `source_assets/props/GreenChair_01/GreenChair_01_2k.gltf` |
| hotel | `SchoolChair_01.res` | SchoolChair_01 | gltf | `source_assets/props/SchoolChair_01/SchoolChair_01_2k.gltf` |
| hotel | `Sofa_01.res` | Sofa_01 | gltf | `source_assets/props/Sofa_01/Sofa_01_2k.gltf` |
| hotel | `WetFloorSign_01.res` | WetFloorSign_01 | gltf | `source_assets/props/WetFloorSign_01/WetFloorSign_01_1k.gltf` |
| hotel | `alarm_clock_01.res` | alarm_clock_01 | gltf | `source_assets/props/alarm_clock_01/alarm_clock_01_1k.gltf` |
| hotel | `alarm_clock_01_hour.res` | alarm_clock_01 | gltf | `source_assets/props/alarm_clock_01/alarm_clock_01_1k.gltf` |
| hotel | `alarm_clock_01_minute.res` | alarm_clock_01 | gltf | `source_assets/props/alarm_clock_01/alarm_clock_01_1k.gltf` |
| hotel | `alarm_clock_01_second.res` | alarm_clock_01 | gltf | `source_assets/props/alarm_clock_01/alarm_clock_01_1k.gltf` |
| hotel | `antique_ceramic_vase_01.res` | antique_ceramic_vase_01 | gltf | `source_assets/props/antique_ceramic_vase_01/antique_ceramic_vase_01_1k.gltf` |
| hotel | `bleach_bottle.res` | bleach_bottle | gltf | `source_assets/props/bleach_bottle/bleach_bottle_1k.gltf` |
| hotel | `book_encyclopedia_set_01.res` | book_encyclopedia_set_01 | gltf | `source_assets/props/book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf` |
| hotel | `brass_vase_02.res` | brass_vase_02 | gltf | `source_assets/props/brass_vase_02/brass_vase_02_1k.gltf` |
| hotel | `cardboard_box_01.res` | cardboard_box_01 | gltf | `source_assets/props/cardboard_box_01/cardboard_box_01_1k.gltf` |
| hotel | `ceiling_fan.res` | ceiling_fan | gltf | `source_assets/props/ceiling_fan/ceiling_fan_1k.gltf` |
| hotel | `ceramic_vase_01.res` | ceramic_vase_01 | gltf | `source_assets/props/ceramic_vase_01/ceramic_vase_01_1k.gltf` |
| hotel | `cigarette_pack.res` | cigarette_pack | gltf | `source_assets/props/cigarette_pack/cigarette_pack_1k.gltf` |
| hotel | `clipboard.res` | clipboard | gltf | `source_assets/props/clipboard/clipboard_1k.gltf` |
| hotel | `dining_chair_02.res` | dining_chair_02 | gltf | `source_assets/props/dining_chair_02/dining_chair_02_2k.gltf` |
| hotel | `drawer_cabinet.res` | drawer_cabinet | gltf | `source_assets/props/drawer_cabinet/drawer_cabinet_2k.gltf` |
| hotel | `drawer_cabinet_body.res` | drawer_cabinet | gltf | `source_assets/props/drawer_cabinet/drawer_cabinet_2k.gltf` |
| hotel | `drawer_cabinet_drawer_1.res` | drawer_cabinet | gltf | `source_assets/props/drawer_cabinet/drawer_cabinet_2k.gltf` |
| hotel | `drawer_cabinet_drawer_2.res` | drawer_cabinet | gltf | `source_assets/props/drawer_cabinet/drawer_cabinet_2k.gltf` |
| hotel | `drawer_cabinet_drawer_3.res` | drawer_cabinet | gltf | `source_assets/props/drawer_cabinet/drawer_cabinet_2k.gltf` |
| hotel | `drawer_cabinet_drawer_4.res` | drawer_cabinet | gltf | `source_assets/props/drawer_cabinet/drawer_cabinet_2k.gltf` |
| hotel | `fancy_picture_frame_01.res` | fancy_picture_frame_01 | gltf | `source_assets/props/fancy_picture_frame_01/fancy_picture_frame_01_2k.gltf` |
| hotel | `fire_alarm.res` | fire_alarm | gltf | `source_assets/props/fire_alarm/fire_alarm_1k.gltf` |
| hotel | `industrial_storage_cart.res` | industrial_storage_cart | gltf | `source_assets/props/industrial_storage_cart/industrial_storage_cart_2k.gltf` |
| hotel | `jug_01.res` | jug_01 | gltf | `source_assets/props/jug_01/jug_01_1k.gltf` |
| hotel | `key_chain.res` | key_chain | fbx | `source_assets/props/key_chain/KeyChain.FBX` |
| hotel | `mantel_clock_01.res` | mantel_clock_01 | gltf | `source_assets/props/mantel_clock_01/mantel_clock_01_1k.gltf` |
| hotel | `mantel_clock_01_hour.res` | mantel_clock_01 | gltf | `source_assets/props/mantel_clock_01/mantel_clock_01_1k.gltf` |
| hotel | `mantel_clock_01_minute.res` | mantel_clock_01 | gltf | `source_assets/props/mantel_clock_01/mantel_clock_01_1k.gltf` |
| hotel | `metal_office_desk.res` | metal_office_desk | gltf | `source_assets/props/metal_office_desk/metal_office_desk_2k.gltf` |
| hotel | `metal_trash_can_clean.res` | metal_trash_can | gltf | `source_assets/props/metal_trash_can/metal_trash_can_1k.gltf` |
| hotel | `metal_trash_can_rust.res` | metal_trash_can | gltf | `source_assets/props/metal_trash_can/metal_trash_can_1k.gltf` |
| hotel | `modular_airduct_circular_01_duct.res` | parte de modular_airduct_circular_01 | gltf | `source_assets/props/modular_airduct_circular_01/modular_airduct_circular_01_1k.gltf` |
| hotel | `modular_airduct_circular_01_fan.res` | parte de modular_airduct_circular_01 | gltf | `source_assets/props/modular_airduct_circular_01/modular_airduct_circular_01_1k.gltf` |
| hotel | `modular_fire_escape_ladder.res` | parte de modular_fire_escape | gltf | `source_assets/props/modular_fire_escape/modular_fire_escape_1k.gltf` |
| hotel | `modular_pipes_straight.res` | parte de modular_pipes | gltf | `source_assets/props/modular_pipes/modular_pipes_1k.gltf` |
| hotel | `mounted_fluorescent_lights_batten.res` | parte de mounted_fluorescent_lights | gltf | `source_assets/props/mounted_fluorescent_lights/mounted_fluorescent_lights_1k.gltf` |
| hotel | `multi_cleaner_bottle.res` | multi_cleaner_bottle | gltf | `source_assets/props/multi_cleaner_bottle/multi_cleaner_bottle_1k.gltf` |
| hotel | `office_notepads_a4.res` | parte de office_notepads | gltf | `source_assets/props/office_notepads/office_notepads_1k.gltf` |
| hotel | `office_notepads_pad.res` | office_notepads | gltf | `source_assets/props/office_notepads/office_notepads_1k.gltf` |
| hotel | `ornate_mirror_01.res` | ornate_mirror_01 | gltf | `source_assets/props/ornate_mirror_01/ornate_mirror_01_2k.gltf` |
| hotel | `painted_wooden_cabinet.res` | painted_wooden_cabinet | gltf | `source_assets/props/painted_wooden_cabinet/painted_wooden_cabinet_2k.gltf` |
| hotel | `painted_wooden_cabinet_body.res` | painted_wooden_cabinet | gltf | `source_assets/props/painted_wooden_cabinet/painted_wooden_cabinet_2k.gltf` |
| hotel | `painted_wooden_cabinet_door_1.res` | painted_wooden_cabinet | gltf | `source_assets/props/painted_wooden_cabinet/painted_wooden_cabinet_2k.gltf` |
| hotel | `painted_wooden_cabinet_door_2.res` | painted_wooden_cabinet | gltf | `source_assets/props/painted_wooden_cabinet/painted_wooden_cabinet_2k.gltf` |
| hotel | `painted_wooden_cabinet_drawer_1.res` | painted_wooden_cabinet | gltf | `source_assets/props/painted_wooden_cabinet/painted_wooden_cabinet_2k.gltf` |
| hotel | `painted_wooden_cabinet_drawer_2.res` | painted_wooden_cabinet | gltf | `source_assets/props/painted_wooden_cabinet/painted_wooden_cabinet_2k.gltf` |
| hotel | `plastic_crate_02.res` | plastic_crate_02 | gltf | `source_assets/props/plastic_crate_02/plastic_crate_02_1k.gltf` |
| hotel | `potted_plant_02.res` | potted_plant_02 | gltf | `source_assets/props/potted_plant_02/potted_plant_02_1k.gltf` |
| hotel | `potted_plant_04.res` | potted_plant_04 | gltf | `source_assets/props/potted_plant_04/potted_plant_04_1k.gltf` |
| hotel | `power_box_01.res` | power_box_01 | gltf | `source_assets/props/power_box_01/power_box_01_1k.gltf` |
| hotel | `power_box_01_body.res` | power_box_01 | gltf | `source_assets/props/power_box_01/power_box_01_1k.gltf` |
| hotel | `power_box_01_door_0.res` | power_box_01 | gltf | `source_assets/props/power_box_01/power_box_01_1k.gltf` |
| hotel | `side_table_tall_01.res` | side_table_tall_01 | gltf | `source_assets/props/side_table_tall_01/side_table_tall_01_2k.gltf` |
| hotel | `sofa_03.res` | sofa_03 | gltf | `source_assets/props/sofa_03/sofa_03_2k.gltf` |
| hotel | `stationery_supplies.res` | stationery_supplies | gltf | `source_assets/props/stationery_supplies/stationery_supplies_1k.gltf` |
| hotel | `steel_frame_shelves_01.res` | steel_frame_shelves_01 | gltf | `source_assets/props/steel_frame_shelves_01/steel_frame_shelves_01_2k.gltf` |
| hotel | `trashbag.res` | trashbag | gltf | `source_assets/props/trashbag/trashbag_1k.gltf` |
| hotel | `vintage_cabinet_01.res` | vintage_cabinet_01 | gltf | `source_assets/props/vintage_cabinet_01/vintage_cabinet_01_1k.gltf` |
| hotel | `vintage_cabinet_01_body.res` | vintage_cabinet_01 | gltf | `source_assets/props/vintage_cabinet_01/vintage_cabinet_01_1k.gltf` |
| hotel | `vintage_cabinet_01_door_2.res` | vintage_cabinet_01 | gltf | `source_assets/props/vintage_cabinet_01/vintage_cabinet_01_1k.gltf` |
| hotel | `vintage_cabinet_01_door_5.res` | vintage_cabinet_01 | gltf | `source_assets/props/vintage_cabinet_01/vintage_cabinet_01_1k.gltf` |
| hotel | `vintage_cabinet_01_door_6.res` | vintage_cabinet_01 | gltf | `source_assets/props/vintage_cabinet_01/vintage_cabinet_01_1k.gltf` |
| hotel | `vintage_cabinet_01_door_7.res` | vintage_cabinet_01 | gltf | `source_assets/props/vintage_cabinet_01/vintage_cabinet_01_1k.gltf` |
| hotel | `vintage_cabinet_01_glass_1.res` | vintage_cabinet_01 | gltf | `source_assets/props/vintage_cabinet_01/vintage_cabinet_01_1k.gltf` |
| hotel | `vintage_cabinet_01_glass_3.res` | vintage_cabinet_01 | gltf | `source_assets/props/vintage_cabinet_01/vintage_cabinet_01_1k.gltf` |
| hotel | `vintage_cabinet_01_glass_4.res` | vintage_cabinet_01 | gltf | `source_assets/props/vintage_cabinet_01/vintage_cabinet_01_1k.gltf` |
| hotel | `vintage_grandfather_clock_01.res` | vintage_grandfather_clock_01 | gltf | `source_assets/props/vintage_grandfather_clock_01/vintage_grandfather_clock_01_2k.gltf` |
| hotel | `vintage_grandfather_clock_01_hour.res` | vintage_grandfather_clock_01 | gltf | `source_assets/props/vintage_grandfather_clock_01/vintage_grandfather_clock_01_2k.gltf` |
| hotel | `vintage_grandfather_clock_01_minute.res` | vintage_grandfather_clock_01 | gltf | `source_assets/props/vintage_grandfather_clock_01/vintage_grandfather_clock_01_2k.gltf` |
| hotel | `vintage_suitcase_a.res` | vintage_suitcase | gltf | `source_assets/props/vintage_suitcase/vintage_suitcase_1k.gltf` |
| hotel | `vintage_suitcase_a_body.res` | parte de vintage_suitcase | gltf | `source_assets/props/vintage_suitcase/vintage_suitcase_1k.gltf` |
| hotel | `vintage_suitcase_a_lid_0.res` | parte de vintage_suitcase | gltf | `source_assets/props/vintage_suitcase/vintage_suitcase_1k.gltf` |
| hotel | `vintage_suitcase_b.res` | vintage_suitcase | gltf | `source_assets/props/vintage_suitcase/vintage_suitcase_1k.gltf` |
| hotel | `vintage_suitcase_b_body.res` | parte de vintage_suitcase | gltf | `source_assets/props/vintage_suitcase/vintage_suitcase_1k.gltf` |
| hotel | `vintage_suitcase_b_lid_0.res` | parte de vintage_suitcase | gltf | `source_assets/props/vintage_suitcase/vintage_suitcase_1k.gltf` |
| hotel | `wall_clock.res` | wall_clock | gltf | `source_assets/props/wall_clock/wall_clock_1k.gltf` |
| hotel | `wall_clock_hour.res` | wall_clock | gltf | `source_assets/props/wall_clock/wall_clock_1k.gltf` |
| hotel | `wall_clock_minute.res` | wall_clock | gltf | `source_assets/props/wall_clock/wall_clock_1k.gltf` |
| hotel | `wall_clock_second.res` | wall_clock | gltf | `source_assets/props/wall_clock/wall_clock_1k.gltf` |
| hotel | `wicker_basket_02.res` | wicker_basket_02 | gltf | `source_assets/props/wicker_basket_02/wicker_basket_02_1k.gltf` |
| hotel | `wine_bottles_01_alsace.res` | wine_bottles_01 | gltf | `source_assets/props/wine_bottles_01/wine_bottles_01_1k.gltf` |
| hotel | `wine_bottles_01_bordeaux.res` | wine_bottles_01 | gltf | `source_assets/props/wine_bottles_01/wine_bottles_01_1k.gltf` |
| hotel | `wine_bottles_01_burgundy.res` | wine_bottles_01 | gltf | `source_assets/props/wine_bottles_01/wine_bottles_01_1k.gltf` |
| hotel | `wine_bottles_01_champagne.res` | wine_bottles_01 | gltf | `source_assets/props/wine_bottles_01/wine_bottles_01_1k.gltf` |
| hotel | `wooden_bookshelf_worn.res` | wooden_bookshelf_worn | gltf | `source_assets/props/wooden_bookshelf_worn/wooden_bookshelf_worn_2k.gltf` |
| hotel | `worn_metal_rack.res` | worn_metal_rack | gltf | `source_assets/props/worn_metal_rack/worn_metal_rack_2k.gltf` |
| office | `Television_01.res` | Television_01 | gltf | `source_assets/props/Television_01/Television_01_1k.gltf` |
| office | `alargador_evan4129.res` | alargador_evan4129 | gltf | `source_assets/oficinas/objetos/alargador_evan4129/_gltf/alargador.gltf` |
| office | `anthurium_botany_01_a.res` | anthurium_botany_01 | gltf | `source_assets/props/anthurium_botany_01/anthurium_botany_01_1k.gltf` |
| office | `anthurium_botany_01_b.res` | anthurium_botany_01 | gltf | `source_assets/props/anthurium_botany_01/anthurium_botany_01_1k.gltf` |
| office | `anthurium_botany_01_c.res` | anthurium_botany_01 | gltf | `source_assets/props/anthurium_botany_01/anthurium_botany_01_1k.gltf` |
| office | `archivador_gris_ahmagh2e_body4.res` | archivador_gris_ahmagh2e | gltf | `source_assets/oficinas/carpinteria/archivador_gris_ahmagh2e/_gltf/archivadores.gltf` |
| office | `archivador_gris_ahmagh2e_drawer.res` | archivador_gris_ahmagh2e | gltf | `source_assets/oficinas/carpinteria/archivador_gris_ahmagh2e/_gltf/archivadores.gltf` |
| office | `archivador_gris_ahmagh2e_shut4.res` | archivador_gris_ahmagh2e | gltf | `source_assets/oficinas/carpinteria/archivador_gris_ahmagh2e/_gltf/archivadores.gltf` |
| office | `archivadores_palanca_janexx.res` | archivadores_palanca_janexx | gltf | `source_assets/oficinas/objetos/archivadores_palanca_janexx/_gltf/archivadores.gltf` |
| office | `armario_manguera_red2000.res` | armario_manguera_red2000 | gltf | `source_assets/oficinas/equipos/armario_manguera_red2000/_gltf/armario.gltf` |
| office | `bandeja_sinnervoncrawsz.res` | bandeja_sinnervoncrawsz | gltf | `source_assets/oficinas/objetos/bandeja_sinnervoncrawsz/_gltf/bandeja.gltf` |
| office | `boombox.res` | boombox | gltf | `source_assets/props/boombox/boombox_1k.gltf` |
| office | `butaca_madera_renend.res` | butaca_madera_renend | gltf | `source_assets/oficinas/muebles_c/butaca_madera_renend/_zip/scene.gltf` |
| office | `cafetera_kird3rf.res` | cafetera_kird3rf | gltf | `source_assets/oficinas/objetos/cafetera_kird3rf/_gltf/cafetera.gltf` |
| office | `caja_carton_krolzuzanna.res` | caja_carton_krolzuzanna | gltf | `source_assets/oficinas/objetos/caja_carton_krolzuzanna/_gltf/caja.gltf` |
| office | `cajas_archivo_cozmoth.res` | cajas_archivo_cozmoth | gltf | `source_assets/oficinas/objetos/cajas_archivo_cozmoth/_gltf/caja.gltf` |
| office | `calathea_orbifolia_01_a.res` | calathea_orbifolia_01 | gltf | `source_assets/props/calathea_orbifolia_01/calathea_orbifolia_01_1k.gltf` |
| office | `calathea_orbifolia_01_b.res` | calathea_orbifolia_01 | gltf | `source_assets/props/calathea_orbifolia_01/calathea_orbifolia_01_1k.gltf` |
| office | `calathea_orbifolia_01_c.res` | calathea_orbifolia_01 | gltf | `source_assets/props/calathea_orbifolia_01/calathea_orbifolia_01_1k.gltf` |
| office | `camara_cctv_smoggybeard.res` | camara_cctv_smoggybeard | gltf | `source_assets/oficinas/equipos/camara_cctv_smoggybeard/_gltf/camara.gltf` |
| office | `cenicero_vidrio_red2000.res` | cenicero_vidrio_red2000 | gltf | `source_assets/oficinas/objetos/cenicero_vidrio_red2000/_gltf/cenicero.gltf` |
| office | `crt_terminal_ibm3278_sketchfab.res` | crt_terminal_ibm3278_sketchfab | gltf | `source_assets/oficinas/equipos/crt_terminal_ibm3278_sketchfab/_gltf/ibm_3278.gltf` |
| office | `detector_humo_sousinho.res` | detector_humo_sousinho | gltf | `source_assets/oficinas/carpinteria/detector_humo_sousinho/_gltf/detector.gltf` |
| office | `dustpan.res` | dustpan | gltf | `source_assets/props/dustpan/dustpan_1k.gltf` |
| office | `escritorio_madera_collings.res` | escritorio_madera_collings | gltf | `source_assets/oficinas/muebles_c/escritorio_madera_collings/_gltf/escritorio.gltf` |
| office | `escritorio_tanker_lenawachs.res` | escritorio_tanker_lenawachs | gltf | `source_assets/oficinas/muebles_c/escritorio_tanker_lenawachs/_gltf/tanker.gltf` |
| office | `expendedora_attheseedof.res` | expendedora_attheseedof | gltf | `source_assets/oficinas/muebles_c/expendedora_attheseedof/_gltf/expendedora.gltf` |
| office | `extintor_loic.res` | extintor_loic | gltf | `source_assets/oficinas/equipos/extintor_loic/_gltf/extintor.gltf` |
| office | `fichero_vintage_wooden_drawer_01.res` | fichero_vintage_wooden_drawer_01 | fbx+gltf | `source_assets/oficinas/muebles_a/fichero_vintage_wooden_drawer_01/vintage_wooden_drawer_01_2k.fbx` |
| office | `flexo_sousinho.res` | flexo_sousinho | gltf | `source_assets/oficinas/objetos/flexo_sousinho/_gltf/flexo.gltf` |
| office | `globo_collings.res` | globo_collings | gltf | `source_assets/oficinas/objetos/globo_collings/_gltf/globo.gltf` |
| office | `impresora_okidata_papaj.res` | impresora_okidata_papaj | gltf | `source_assets/oficinas/muebles_c/impresora_okidata_papaj/_gltf/impresora.gltf` |
| office | `lampara_banquero_meunier.res` | lampara_banquero_meunier | gltf | `source_assets/oficinas/objetos/lampara_banquero_meunier/_gltf/lampara.gltf` |
| office | `lampara_pie_bilgehankorkmaz.res` | lampara_pie_bilgehankorkmaz | gltf | `source_assets/oficinas/objetos/lampara_pie_bilgehankorkmaz/_gltf/lampara_pie.gltf` |
| office | `lavabo_juang3d.res` | lavabo_juang3d | gltf | `source_assets/oficinas/equipos/lavabo_juang3d/_gltf/lavabo.gltf` |
| office | `libreria_libros_collings.res` | libreria_libros_collings | gltf | `source_assets/oficinas/muebles_c/libreria_libros_collings/_gltf/libreria.gltf` |
| office | `libros_frodoundead_row_a.res` | libros_frodoundead | gltf | `source_assets/oficinas/objetos/libros_frodoundead/_gltf/filas.gltf` |
| office | `libros_frodoundead_row_b.res` | libros_frodoundead | gltf | `source_assets/oficinas/objetos/libros_frodoundead/_gltf/filas.gltf` |
| office | `libros_frodoundead_row_c.res` | libros_frodoundead | gltf | `source_assets/oficinas/objetos/libros_frodoundead/_gltf/filas.gltf` |
| office | `libros_frodoundead_row_d.res` | libros_frodoundead | gltf | `source_assets/oficinas/objetos/libros_frodoundead/_gltf/filas.gltf` |
| office | `luz_emergencia_sousinho_body.res` | luz_emergencia_sousinho | gltf | `source_assets/oficinas/equipos/luz_emergencia_sousinho/_gltf/emergencia.gltf` |
| office | `luz_emergencia_sousinho_glass.res` | luz_emergencia_sousinho | gltf | `source_assets/oficinas/equipos/luz_emergencia_sousinho/_gltf/emergencia.gltf` |
| office | `magnifying_glass_01.res` | magnifying_glass_01 | gltf | `source_assets/props/magnifying_glass_01/magnifying_glass_01_1k.gltf` |
| office | `metal_stool_01.res` | metal_stool_01 | gltf | `source_assets/props/metal_stool_01/metal_stool_01_1k.gltf` |
| office | `metal_toolbox.res` | metal_toolbox | gltf | `source_assets/props/metal_toolbox/metal_toolbox_1k.gltf` |
| office | `microfichas_maxdragonn.res` | microfichas_maxdragonn | gltf | `source_assets/oficinas/equipos/microfichas_maxdragonn/_gltf/microfichas.gltf` |
| office | `mid_century_lounge_chair.res` | mid_century_lounge_chair | gltf | `source_assets/props/mid_century_lounge_chair/mid_century_lounge_chair_1k.gltf` |
| office | `mousetrap.res` | mousetrap | gltf | `source_assets/props/mousetrap/mousetrap_1k.gltf` |
| office | `nevera_dylanheyes.res` | nevera_dylanheyes | gltf | `source_assets/oficinas/muebles_c/nevera_dylanheyes/_gltf/nevera.gltf` |
| office | `pachira_aquatica_01_a.res` | pachira_aquatica_01 | gltf | `source_assets/props/pachira_aquatica_01/pachira_aquatica_01_1k.gltf` |
| office | `pachira_aquatica_01_b.res` | pachira_aquatica_01 | gltf | `source_assets/props/pachira_aquatica_01/pachira_aquatica_01_1k.gltf` |
| office | `pachira_aquatica_01_c.res` | pachira_aquatica_01 | gltf | `source_assets/props/pachira_aquatica_01/pachira_aquatica_01_1k.gltf` |
| office | `pachira_aquatica_01_d.res` | pachira_aquatica_01 | gltf | `source_assets/props/pachira_aquatica_01/pachira_aquatica_01_1k.gltf` |
| office | `perchero_coat_rack_whostea.res` | perchero_coat_rack_whostea | gltf | `source_assets/oficinas/muebles_a/perchero_coat_rack_whostea/_zip/scene.gltf` |
| office | `perchero_pared_ehnri.res` | perchero_pared_ehnri | gltf | `source_assets/oficinas/muebles_a/perchero_pared_ehnri/_gltf/perchero.gltf` |
| office | `pilea_terracota_allquad.res` | pilea_terracota_allquad | gltf | `source_assets/oficinas/objetos/pilea_terracota_allquad/_gltf/pilea.gltf` |
| office | `plastic_thermos.res` | plastic_thermos | gltf | `source_assets/props/plastic_thermos/plastic_thermos_1k.gltf` |
| office | `portalapices_aspectstudio.res` | portalapices_aspectstudio | gltf | `source_assets/oficinas/objetos/portalapices_aspectstudio/_gltf/portalapices.gltf` |
| office | `potted_plant_01.res` | potted_plant_01 | gltf | `source_assets/props/potted_plant_01/potted_plant_01_1k.gltf` |
| office | `potus_colgante_kemowolfpaw.res` | potus_colgante_kemowolfpaw | gltf | `source_assets/oficinas/objetos/potus_colgante_kemowolfpaw/_gltf/potus.gltf` |
| office | `projector_screen.res` | projector_screen | gltf | `source_assets/props/projector_screen/projector_screen_1k.gltf` |
| office | `puerta_lisa_sousinho_leaf.res` | puerta_lisa_sousinho | gltf | `source_assets/oficinas/carpinteria/puerta_lisa_sousinho/_gltf/puerta_lisa.gltf` |
| office | `puerta_metal_tboiston_frame.res` | puerta_metal_tboiston | gltf | `source_assets/oficinas/carpinteria/puerta_metal_tboiston/_gltf/puerta_metal.gltf` |
| office | `puerta_metal_tboiston_leaf.res` | puerta_metal_tboiston | gltf | `source_assets/oficinas/carpinteria/puerta_metal_tboiston/_gltf/puerta_metal.gltf` |
| office | `puerta_oficina_sousinho_leaf.res` | puerta_oficina_sousinho | gltf | `source_assets/oficinas/carpinteria/puerta_oficina_sousinho/_gltf/puerta_oficina.gltf` |
| office | `reloj_mesa_sousinho.res` | reloj_mesa_sousinho | gltf | `source_assets/oficinas/objetos/reloj_mesa_sousinho/_gltf/reloj.gltf` |
| office | `retro_oficina_yj_chair.res` | parte de retro_oficina_yj | gltf | `source_assets/oficinas/muebles_c/retro_oficina_yj/_gltf/retro_oficina.gltf` |
| office | `retro_oficina_yj_desk.res` | parte de retro_oficina_yj | gltf | `source_assets/oficinas/muebles_c/retro_oficina_yj/_gltf/retro_oficina.gltf` |
| office | `rociador_tashakosaykina.res` | rociador_tashakosaykina | gltf | `source_assets/oficinas/equipos/rociador_tashakosaykina/_gltf/rociador.gltf` |
| office | `rotary_phone_black_sketchfab.res` | rotary_phone_black_sketchfab | gltf | `source_assets/oficinas/equipos/rotary_phone_black_sketchfab/_gltf/rotary_phone.gltf` |
| office | `round_spectacles.res` | round_spectacles | gltf | `source_assets/props/round_spectacles/round_spectacles_1k.gltf` |
| office | `round_wooden_table_01.res` | round_wooden_table_01 | gltf | `source_assets/props/round_wooden_table_01/round_wooden_table_01_2k.gltf` |
| office | `secamanos_ladylionstudios.res` | secamanos_ladylionstudios | gltf | `source_assets/oficinas/equipos/secamanos_ladylionstudios/_gltf/secamanos.gltf` |
| office | `silla_banquero_zamzam.res` | silla_banquero_zamzam | gltf | `source_assets/oficinas/muebles_c/silla_banquero_zamzam/_gltf/silla.gltf` |
| office | `silla_giratoria_old_computer_chair.res` | silla_giratoria_old_computer_chair | gltf | `source_assets/oficinas/muebles_a/silla_giratoria_old_computer_chair/_zip/scene.gltf` |
| office | `silla_tela_projectkaizen.res` | silla_tela_projectkaizen | gltf | `source_assets/oficinas/muebles_c/silla_tela_projectkaizen/_gltf/silla.gltf` |
| office | `sillas_espera_connorwassall.res` | sillas_espera_connorwassall | gltf | `source_assets/oficinas/muebles_c/sillas_espera_connorwassall/_gltf/sillas_espera.gltf` |
| office | `sillon_mirey_a.res` | sillon_mirey_a | gltf | `source_assets/oficinas/muebles_c/sillon_mirey_a/_gltf/sillon.gltf` |
| office | `small_wooden_table_01.res` | small_wooden_table_01 | gltf | `source_assets/props/small_wooden_table_01/small_wooden_table_01_2k.gltf` |
| office | `sofa_02.res` | sofa_02 | gltf | `source_assets/props/sofa_02/sofa_02_1k.gltf` |
| office | `standing_picture_frame_02.res` | standing_picture_frame_02 | gltf | `source_assets/props/standing_picture_frame_02/standing_picture_frame_02_1k.gltf` |
| office | `steel_frame_shelves_02.res` | steel_frame_shelves_02 | gltf | `source_assets/props/steel_frame_shelves_02/steel_frame_shelves_02_1k.gltf` |
| office | `taquilla_zambur.res` | taquilla_zambur | gltf | `source_assets/oficinas/carpinteria/taquilla_zambur/_gltf/taquillas.gltf` |
| office | `terminal_ibm3178_maxdragon.res` | terminal_ibm3178_maxdragon | gltf | `source_assets/oficinas/objetos/terminal_ibm3178_maxdragon/_gltf/terminal.gltf` |
| office | `termostato_alarma_ladylionstudios.res` | termostato_alarma_ladylionstudios | gltf | `source_assets/oficinas/equipos/termostato_alarma_ladylionstudios/_gltf/termostato.gltf` |
| office | `toalla_aprilpolubiec.res` | toalla_aprilpolubiec | gltf | `source_assets/oficinas/objetos/toalla_aprilpolubiec/_gltf/toalla.gltf` |
| office | `typewriter_1930s_unbranded_sketchfab.res` | typewriter_1930s_unbranded_sketchfab | gltf | `source_assets/oficinas/equipos/typewriter_1930s_unbranded_sketchfab/_gltf/typewriter.gltf` |
| office | `unidad_hvac_kubassa.res` | unidad_hvac_kubassa | gltf | `source_assets/oficinas/equipos/unidad_hvac_kubassa/_gltf/hvac.gltf` |
| office | `ventila_techo_ahmagh2e.res` | ventila_techo_ahmagh2e | gltf | `source_assets/oficinas/equipos/ventila_techo_ahmagh2e/_gltf/ventila.gltf` |
| office | `ventilador_joshsmith.res` | ventilador_joshsmith | gltf | `source_assets/oficinas/muebles_c/ventilador_joshsmith/_gltf/ventilador.gltf` |
| office | `vintage_stapler.res` | vintage_stapler | gltf | `source_assets/props/vintage_stapler/vintage_stapler_1k.gltf` |
| office | `water_cooler_bottle_tboiston.res` | water_cooler_bottle_tboiston | gltf | `source_assets/oficinas/muebles_b/water_cooler_bottle_tboiston/_zip/scene.gltf` |
| office | `wooden_broom.res` | wooden_broom | gltf | `source_assets/props/wooden_broom/wooden_broom_1k.gltf` |
| office | `wooden_ladder_02.res` | wooden_ladder_02 | gltf | `source_assets/props/wooden_ladder_02/wooden_ladder_02_1k.gltf` |
| office | `zapato_inciprocal.res` | zapato_inciprocal | gltf | `source_assets/oficinas/objetos/zapato_inciprocal/_gltf/zapatos.gltf` |

---

## 15. Sin comprobar

- **Contenido de los binarios:** no se abrió ningún `.res`, `.glb`, `.fbx` ni `.blend`. No hay triángulos, huesos ni materiales por malla medidos, salvo los presupuestos y las cifras de los registros y tests.
- **Licencias:** salen de `docs/ASSETS.md` y de los registros. No se abrió ninguna ficha de Sketchfab, Poly Haven, Freesound, Pixabay ni BigSoundBank (sin acceso a internet en esta lectura).
- **Trazado de origen de los `.res`:** el emparejamiento es por nombre de carpeta (anexo A). No se comprobó uno por uno que el glTF citado sea el que produce cada `.res`. En particular, los 23 modelos del hotel que son «partes» solo se comprobó que existe el padre; no se verificó con `PARTS` (`build_catalogue.gd:36`) que la pieza salga de ese glTF.
- **Fuente del armario (`wardrobe.fbx`):** no se identificó el zip. El nombre `soviet-old-wardrobe.zip` de `models/` es una suposición.
- **Partes de origen del televisor, la puerta y el ascensor:** se citan desde `docs/ASSETS.md` y `build_model_props.gd`; no se comprobó con los zips.
- **Escala del Locust (1,65):** citada desde `docs/ASSETS.md:435`; no encontré esa constante en `game/enemies/locust/`.
- **Huérfanos:** 40 `.res` y 41 audios no aparecen por nombre en `game/`, `tools/` ni `docs/`. Muchos se cargan por nombre construido (`_drawer_%d`, `tile_%d`, `knock_%d`). La lista es heurística y no está verificada.
- **Orden de presets:** la correspondencia índice 0 = Bajo y 4 = Muy bajo se dedujo del orden de `PRESETS` y de `NAMES`. No se ejecutó nada para confirmarlo.
- **Señales de Godot:** no se estudiaron las conexiones de señales de estas clases. Las llamadas a `connect` no se contaron.
- **Audio:** no se midió la frecuencia ni los canales de cada WAV (solo los de `ASSETS:18` y el import de un archivo). El valor `compress/mode=2` del import no se interpreta.
- **Texturas:** solo se midieron dimensiones. No se leyó el contenido de ningún PNG o JPG ni la calidad de los escaneos.
- **Fechas:** `RESUMEN.md` es del 22 de octubre; los registros son de hasta el 14 de noviembre. No se conciliaron.
- **Codificación:** `registro_polyhaven_modelos.json` tiene caracteres de sustitución (U+FFFD) en campos de texto, por ejemplo `sof� de cuero capiton�` (campo `item`). Visto al leer; no se corrige aquí.
- **Lurker:** no se revisó el contenido de `tools/art/lurker/`, ni el origen de `referencia.webp`.
- **Vigencia de los `.res`:** no se comprobó si cada `.res` es más reciente que su fuente.
- **Tamaño exacto de los zips de `source_assets/oficinas/_rechazados/`:** el total (751,7 MB) sale de un recuento; no se abrió ningún zip.
- **`assets/props/office/*` con 2 × 2 px:** 3 imágenes de ese tamaño; no se sabe para qué se usan.
