# Ficha de hechos: materiales, texturas y su ingesta

Repo: `E:\Projects\The Four` (rama main). Motor del código: Godot 4.7.2 (`.claude/godot-api/VERSION`). Lectura del 14 de noviembre de 2026.

Solo lectura. No se ejecutó Godot, Unreal ni ningún script que escriba. Las dimensiones de imagen se leyeron de sus cabeceras; PIL no está instalado y no se instaló nada.

Las rutas van como `ruta:línea`. Los anexos A, B y C se generaron desde el repo con scripts de solo lectura, no se copiaron a mano.

## 0. Alcance y método

**Leído entero:**
- `game/presentation/materials/`: 105 `.tres` (49 en la raíz y 56 en `office/`), más `office/ceiling_halo.gdshader` (19 líneas) y `office/ceiling_tile.gdshader` (60).
- `game/presentation/shaders/`: `finish` (85), `wood` (4), `wood.gdshaderinc` (142), `wood_lacquer` (5), `ceiling` (34), `wallpaper` (84), `carpet` (82), `tile` (89), `curtain` (27), `painting` (30), `venetian_blind` (17), `wired_glass` (30), `exit_panel` (67), `blood` (62), `blood_pool` (87), `blood_worn` (60), `surface.gdshaderinc` (205), `image_maps.gdshaderinc` (112), `typewriter_ink` (32).
- `tools/textures/ingest_pbr.py` (344) y `tools/textures/bake_lite_maps.gd` (210).
- `game/world/hotel/material_albedo.gd` (31).
- `assets/textures/README.md` (30) y `docs/ASSETS.md`, en sus bloques SCANS, OFFICE_SCANS y DRESSING.

**Leído por tramos, solo lo que toca a materiales:**
- `game/world/hotel/hotel_geometry.gd` (3298 líneas): 120-135, 385-530, 530-660, 762-800, 1005-1030, 2574-2600 y 2660-2730.
- `game/world/office/office_geometry.gd` (2841): 28-46, 150-158, 280-296, 428-452, 1318-1346, más búsquedas.
- `game/presentation/graphics_presets.gd` (365): 85-145, 183-236 y 303-330.
- `game/app/presentation_rig.gd` (494): 214-222 y 280-290.
- `project.godot` (74): 50-75.

**Solo cabecera o búsqueda:**
- Shaders de cámara `analog` (286), `lens` (92) y `lens_blood.gdshaderinc` (196). Son posprocesado de la cámara, no materiales del mundo.
- `tools/textures/check_ingest_pbr.py` (128): cabecera.
- `tools/textures/ingest_dressing.py` (189): cabecera, constantes y firmas.
- `bake_blood.py` (134), `bake_do_not_disturb.py` (83), `bake_hotel_note.py` (198), `make_exit_sign.py` (272) y `make_icon.py` (67): solo docstring.
- Búsquedas en `game/` (clases de Godot), `tools/props/` (carga de `.tres`) y `tests/`.

## 1. Resumen

- **105 `.tres` en `game/presentation/materials/`:** 71 son `ShaderMaterial` y 34 son `StandardMaterial3D`. No hay ningún `ORMMaterial3D` (medido).
- **Los 71 `ShaderMaterial` usan 9 shaders:** `finish` 37, `wood` 11, `wallpaper` 7, `tile` 7, `carpet` 4, `ceiling` 2, `ceiling_tile` 1 (oficinas), `painting` 1 y `curtain` 1 (medido).
- **46 referencias `metadata/scan`**, 28 sets distintos, todas en `ShaderMaterial`. Un set es una carpeta de `assets/textures/<set>/` con `albedo`, `normal` y `orm`.
- **Los 34 `StandardMaterial3D` usan mapas propios** de `assets/props/` con UV de malla. `apply_scan()` no les aplica escaneos (`hotel_geometry.gd:447`).
- **La geometría generada no tiene UV útiles.** Las cajas y cilindros se mapean en el shader con coordenadas en metros de posición y normal de mundo (`surface.gdshaderinc:70-75`, `face_uv()`).
- **Cinco presets** (Bajo, Medio, Alto, Ultra, Muy bajo) fijan `surface_detail` (0 a 5), la anisotropía (desactivada a 16X) y si se usan escaneos de 1024 o 2048 px (`graphics_presets.gd:191-233`).
- **En Muy bajo no se cargan escaneos.** Cada material se pinta con una imagen pequeña horneada desde su propio shader (`assets/textures/lite/`, 21 PNG y `lite.json`).
- **Licencias según el registro:** 12 sets del hotel y 18 de oficinas, CC0 1.0. Los decals (13) son de ambientCG, CC0. Los cuadros (14) son del Art Institute of Chicago, CC0 open access (registro en `docs/ASSETS.md`).
- **Renderer:** `forward_plus` por defecto (`settings_service.gd:6`). `gl_compatibility` es opción (`settings_service.gd:149-157`). Varios efectos solo se activan en forward_plus (`graphics_presets.gd:303-318`).

## 2. Qué materiales existen y cómo se crean

### 2.1 Dos familias de recurso

**Familia S, `ShaderMaterial`** (71 archivos). Tiene `shader = ExtResource`, parámetros `shader_parameter/*` y, opcionalmente, `metadata/scan`. La usan paredes, suelos, techos, muebles de madera, telas, metales y pinturas. Ejemplo: `wood.tres` (`shader` en línea 6, `metadata/scan = "lacquered_cherry_wood"` en línea 11).

**Familia T, `StandardMaterial3D`** (34 archivos). Mapas PBR con canales de un ORM empaquetado. Ejemplo: `bed.tres:12-22`:
- `ao_texture_channel = 0` (rojo, oclusión);
- `roughness_texture_channel = 1` (verde, rugosidad);
- `metallic_texture_channel = 2` (azul, metal).

Hay también materiales sin textura, solo color y emisión: `light.tres`, `shade.tres`, `mirror.tres`, `lift_light.tres`, `lift_metal.tres`, `lift_screen.tres`, y en oficinas `glow_*.tres`, `lamp_off.tres`, `tgrid.tres`, `threshold.tres`. Lista completa en el Anexo A.

Constantes de enumerado comprobadas en `.claude/godot-api/doc/classes/BaseMaterial3D.xml`: `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC` = 5, `CULL_DISABLED` = 2, `TRANSPARENCY_ALPHA_SCISSOR` = 2, `EMISSION_OP_MULTIPLY` = 1, `SPECULAR_DISABLED` = 2, `TEXTURE_CHANNEL_GREEN` = 1.

### 2.2 Dónde se cargan y se derivan

**Hotel.**
- `hotel_geometry.gd:129` define `MATERIALS`: 26 claves (plaster, plaster_decrepit, wood, panel, door, trim, linen, fabric, bedspread, leather, metal, black, green, screen, leaf, ceramic, tile, gold, carpet, ceiling, ceiling_service, light, shade, mirror, painting, curtain).
- `_init()` (399-428) hace por cada clave: `load(...).duplicate()`, pone `set_meta("lite", clave)` y llama a `apply_scan`.
- Derivados en código, en el mismo `_init`: `light_off` (emisión apagada), `panel_field` (`panel_spacing` 0), `wood_leaf` y `panel_leaf` (`object_space` true) y `shade_off`.
- Otros `.tres` no están en `MATERIALS`. Los carga `tools/props/` al hornear modelos: `build_wardrobe.gd:156` y `:203` cargan `wardrobe.tres` y `wardrobe_inside.tres`. `build_camcorder.gd:13`, `build_elevator.gd:19`, `build_model_props.gd:6` y `build_door.gd:16` declaran la carpeta `res://game/presentation/materials/`.

**Oficinas** (`office_geometry.gd`):
- `STAND_INS` (línea 10): claves que son copia de un material del hotel. Ejemplos: `tgrid`→metal, `veneer`→panel, `walnut`→trim, `carpet_exec`→carpet.
- `PLAIN` (35): colores planos de 18 claves sin `.tres`. El stand-in se crea con `StandardMaterial3D.new()` en la línea 277.
- `MATERIAL_DIR` (39): `office/<clave>.tres`. `OWN_OVER` (40) = carpet y ceiling_service, que sustituyen al del hotel. `OWN_ONLY` (43) = glow_strip.
- `_init` (264-296): carga de `STAND_INS`, de `MATERIAL_DIR` y de `apply_scan`. `SCREEN_ROUGHNESS` (230) se aplica en la línea 296.
- `lens_key()` (432-452) crea `troffer_lens_<kelvin>` por temperatura de color.
- `ceiling_halo()` (557-599) crea un `ShaderMaterial` con `ceiling_halo.gdshader`.

**Cuadros del hotel** (`hotel_geometry.gd:2669-2708`, `paintings()`):
- Un `StandardMaterial3D` por cuadro, con `albedo_texture` de `assets/paintings/<id>.jpg`, `roughness` 0.62 y `uv1_scale`/`uv1_offset` para recortar al lienzo.
- `QuadMesh` de `CANVAS = Vector2(1.14, 0.78)` (línea 2663). Los retratos se giran.
- Marco tallado: `assets/props/hotel/fancy_picture_frame_01.res`, sin su lienzo.

**Decals** (`hotel_geometry.gd:762-790`): `Decal.new()` con `texture_albedo` de `assets/decals/<name>.png` y normal `<name>_normal.png` si existe. `DECAL_TINT` (797), `DECAL_REACH = 14.0` (799), `decal_shown()` (792).

**Lacado** (`hotel_geometry.gd:2714-2720`, `lacquer(coated)`): cambia el shader de `wood.gdshader` a `wood_lacquer.gdshader` cuando `surface_detail > 4.5`. Se llama desde `apply_quality()` en la línea 2594.

**Otros `uv1_*`:**
- `office_pictures.gd:57` y `:60` usan `uv1_scale` para láminas.
- `hotel_container.gd:382` usa `uv1_scale` en un rótulo.
- `office_geometry.gd:447-448` pone `uv1_triplanar = true` y `uv1_offset = (0.5, 0.5, 0.5)` en la lente de los fluorescentes.

### 2.3 Cuántos de cada shader y de qué material

Ver Anexo A para el detalle de cada `.tres`. Resumen medido: `finish` 37 (cuero, metal, tela, papel, pintura de acero, madera de cristal, pared de yeso), `wood` 11 (puertas, paneles, nogal, teca), `wallpaper` 7 (papel de rollo y pintura de oficina), `tile` 7 (azulejo y vinilo), `carpet` 4 (moqueta del hotel y de oficinas), `ceiling` 2, `ceiling_tile` 1, `painting` 1, `curtain` 1.

## 3. Parámetros de los shaders

Valores por defecto según el shader. Ruta:línea de la declaración.

**`surface.gdshaderinc`** (incluido por todos los shaders de superficie):
- `global uniform float surface_detail` (:40). Valor de proyecto 4.0 (`project.godot:66-68`).
- `flat_color` vec4, default gris 0.5 (:177).
- `use_lite` bool false (:178). `lite_map` sampler2D (:179). `lite_metres` vec2 1.0 (:180).
- Entradas por varyings: `wp` y `wn` (posición y normal de mundo, :7-8), `room_data` vec4 plano (:13).

**`image_maps.gdshaderinc`** (grupo `image_maps`):
- `use_maps` bool false (:10).
- `albedo_map` (:11, sRGB), `normal_map` (:12, `hint_normal`), `orm_map` (:14, blanco por defecto).
- `map_mode` enum Replace 0, Recolour 1, Detail 2, default 1 (:19).
- `map_tint` vec4 1.0 (:20). `map_detail` 0 a 2, default 1.0 (:21). `normal_strength` 1.0 (:22).
- `map_roughness` -1 a 1, default 0 (:24). `map_metallic` 0 a 1, default 1 (:26).
- `map_metres` 1.0 (:28): metros que cubre una repetición. `map_no_tile` false (:33).

**`finish.gdshader`:**
- `albedo`, `variation_color`, `roughness` 0.7 (:9), `metallic` 0 (:10), `specular` 0.5 (:11).
- `finish` enum: Plain 0, Brushed 1, Weave 2, Crumpled 3, Leaf 4, default 0 (:12).
- `detail_scale` 1 (:13), `relief` 1 (:14), `sheen` 0 (:15), `grime` 0.35 (:16), `backlight` 0 (:17).
- `map_rough_keep` 1 (:20). `brush_across` false (:22).

**`wood.gdshaderinc`** (`wood.gdshader` y `wood_lacquer.gdshader`):
- `light_color`, `dark_color`, `ring_density` 22 (:12), `varnish` 0.65 (:13).
- `lacquer_edge` 0.06 (:17), `scuffs` 0.5 (:18), `panel_spacing` 0 (:19).
- `door_panels` false (:20), `object_space` false (:21).
- Barniz: `lacquer = mix(0.75, 0.28, varnish)` (:118). La capa de laca `CLEARCOAT` solo existe con `LACQUER_COAT` (:121-136).

**`wallpaper.gdshader`:** `roll_width` 0.53 (:10), `motif_height` 0.46 (:11), `print_strength` 0.55 (:12), `stains` 0.55 (:13), `grime` 0.5 (:14), `ink_bleed` 0.03 (:16).

**`carpet.gdshader`:** `tile_size` 0.62 (:10), `pattern` 1.0 (:11), `wear` 0.6 (:12), `fibre_bleed` 0.035 (:14).

**`tile.gdshader`:** `tile_size` 0.3 (:9), `grout_width` 0.0035 (:10), `checker` 0.35 (:11), `grime` 0.6 (:12), `tile_count` 8.0 (:14), `specular_level` 0.42 (:16), `marble` 0 (:19), `wear` 0 (:21), `tilt_always` false (:24), `tilt` 0.045 (:27).

**`ceiling.gdshader`:** `base_color`, `stain_color`, `stains` 0.6 (:8).

**`office/ceiling_tile.gdshader`:** `tile` 0.6 (:12), `yellowed` 0.3 (:13), `ringed` 0.12 (:14), `cracked` 0.05 (:15).

**`curtain.gdshader`:** `motion` 1.0 (:6). El vértice mueve la cortina con `sin(TIME*0.7 + x*8)*0.035*motion*(1-UV.y)` (:11).

**`painting.gdshader`:** sin parámetros numéricos. La semilla es `hash13(floor(wp*0.8))*50` (:15).

**`office/ceiling_halo.gdshader`:** `glow`, `energy` 0, `inner` (0.6, 0.3), `reach` 1.2. Modo `blend_add`, `unshaded` (línea 6).

**`venetian_blind.gdshader`:** `pitch` 0.022, `open` 0.3, `drop` 1.0, `height` 1.7 (:6-9).

**`wired_glass.gdshader`:** `pitch` 0.025 (:12), `wire` 0.06 (:13).

**Efectos (fuera de materiales del mundo):** `blood`, `blood_pool`, `blood_worn` y `exit_panel` son `ShaderMaterial` de sangre y de cartel. `analog`, `lens` y `lens_blood` son posprocesado de cámara.

## 4. Texturas: origen, licencia, formato y tamaño

Dimensiones medidas en el Anexo B.

**Sets del hotel (12):** brown_leather, carpet016, ceiling_interior, dark_wood, decrepit_wallpaper, lacquered_cherry_wood, metal048b, quatrefoil_jacquard_fabric, tiles036, velour_velvet, wallpaper001a, officeceiling001.
- Fuentes: ambientCG (Carpet016, Wallpaper001A, OfficeCeiling001, Tiles036, Metal048B) y Poly Haven (el resto).
- Licencia CC0 1.0 según `docs/ASSETS.md`, bloque SCANS, y `ingest_pbr.py:53-66`.
- Tamaños: 2048×2048 y `_1k` a 1024×1024.

**Sets de oficinas (18):** office_anti_skid_tiles, office_bricks019, office_cardboard004, office_concrete_wall_008, office_cork003, office_dark_paneled_wood, office_fabric026, office_fabric028, office_galvanizedsteel02, office_hessian_380, office_painted_concrete_02, office_paintedmetal006, office_teak_veneer, office_terrazzo003, office_tiles032, office_tiles043, office_tiles110, office_walnut_veneer.
- Licencia CC0 1.0 según `docs/ASSETS.md:366-391`. `office_galvanizedsteel02` viene de cgbookcase y solo tiene 1024 px.
- Sin referencia en ningún `.tres`: `office_dark_paneled_wood` (`docs/ASSETS.md:378`, "sin uso desde el área 4d") y `office_tiles043` (`docs/ASSETS.md:388`, "conservada para pruebas").
- `office_rug_met452567`: solo `albedo.png` de 1024×1388, más `rug.tres`. Lo carga `office_fittings.gd:36` como `RUG_ORIENTAL`.

**Decals:** 13 en `ingest_dressing.py:35-49`, 512 px RGBA. Registro en `docs/ASSETS.md`, bloque DRESSING, ambientCG CC0.

**Cuadros:** 14 entradas en `assets/paintings/paintings.json` (medido). Imágenes de 1024 px de ancho. Láminas de oficina: `assets/paintings/office/`, 843 px según el registro.

**Lite (Muy bajo):** 21 PNG en `assets/textures/lite/`: bedspread, black, carpet, ceiling, ceiling_service, ceramic, door, fabric, gold, green, leaf, leather, linen, metal, panel, plaster, plaster_decrepit, screen, tile, trim, wood. Metros que cubre cada una en `lite.json` (ej.: bedspread 0.8, black 1.0, carpet 1.24, ceiling 4.0, ceiling_service 3.6). Tamaños: 128² (finish), 512² (carpet, ceiling, door, panel, tile, trim, wood) y 1024×1224 (plaster, plaster_decrepit).

**Formato de un set** (`ingest_pbr.py:6-9`, `assets/textures/README.md`):
- `albedo.jpg`: color sRGB, subsampling 2.
- `normal.jpg`: convención OpenGL (verde arriba), subsampling 0.
- `orm.jpg`: R oclusión, G rugosidad, B metal, subsampling 0.
- Calidad JPEG 92 (`ingest_pbr.py:69`, `:214`).
- Cada imagen lleva un `.import` (`ingest_pbr.py:71-97`): `compress/mode=2` (VRAM), mipmaps activos, `compress/normal_map` 1 para la normal y 2 para el resto.

**Licencias y avisos:** `docs/ASSETS.md:3-5` dice que hasta resolver permisos no se distribuye, y para el piso 2 se permiten solo CC0, dominio público o CC BY con crédito. `ingest_pbr.py:318-320` imprime `CREDIT` si la licencia de un set de oficinas no empieza por CC0.

## 5. Ingesta de texturas (`tools/textures/`): qué entra y qué sale

| Script | Entrada | Salida | Notas |
|---|---|---|---|
| `ingest_pbr.py` | `source_assets/textures/` (zips ambientCG `*_2K-JPG.zip`, carpetas Poly Haven con `diff`, `nor_gl`, `arm`, e `info.json`). Para oficinas: `source_assets/oficinas/materiales/registro.json` y `registro_materiales_2.json` (solo `status: ok`). | `assets/textures/<set>/{albedo,normal,orm}.jpg` a 2048 px y `_1k` a 1024 px, con su `.import`. Actualiza el bloque SCANS o OFFICE_SCANS de `docs/ASSETS.md`. | Hotel: cuadrado (`ingest_pbr.py:210`). Oficinas: conserva la proporción de la descarga, con el lado mayor a 2048 (`keep_shape`). Solo escribe si el lado original es mayor (`target_size`, :189-194). `--only=`, `--set=office`. cgbookcase: DirectX a OpenGL invirtiendo G (:181) y metal 1 por defecto (:178). |
| `check_ingest_pbr.py` | Lo mismo que `ingest_pbr.py`, sin escribir activos. | Informe `CHECK_*`. Sale con 1 si algo falla. | Solo cabecera leída. |
| `ingest_dressing.py` | `source_assets/decals/` (zips ambientCG), `source_assets/paintings/` (Art Institute con `info.json`), `source_assets/paintings/office/`. | `assets/decals/<name>.png` 512 px RGBA (alfa desde Opacity, Roughness o Displacement), `<name>_normal.png`. `assets/paintings/<id>.jpg` 1024 px y `paintings.json`. Bloque DRESSING del registro. | 13 decals en `DECALS` (:35-49). `SIZE = 512` (:33). Cuerpo no leído completo. |
| `bake_lite_maps.gd` | Los materiales de `hotel_geometry.MATERIALS` con shader (`plan()`, :79-107) y sus shaders. Necesita ventana (renderiza). | `assets/textures/lite/<clave>.png` con `.import`, y `lite.json` con los metros. | `SUPER = 2` (:30), `BAND = 0.25` (:33), `TALLEST = 4.8` (:35). Fija `surface_detail` a 4.0 (:111). Tamaños: wallpaper 1024 px (:89), carpet 512 (:93), tile 512 (:95), ceiling 512 (:97), wood 512 (:101), finish 128 (:106). `ceiling_tile`, `curtain` y `painting` no tienen plan, y por eso no tienen imagen lite. |
| `bake_blood.py` | Cabecera. | `assets/decals/blood_atlas.png`: atlas 4×4 de celdas de 256 px. | Lo usa `blood.gdshader`. |
| `bake_do_not_disturb.py` | Cabecera. | `assets/textures/no-molestar.png` 360×900 y su reverso. | Cartel de pomo, cuadro de texto. |
| `bake_hotel_note.py` | Cabecera. `assets/nota-hotel.png` 1024×1536. | `assets/textures/nota-hotel-lejos.png` 384×576, y versiones "lejos" de carta y libreta. | Papel de la mesa. |
| `make_exit_sign.py` | Cabecera. | Máscara de grabado de `exit_panel.gdshader` (R cara, G borde), y señales `way_*.png` de los pasillos. | Letras dibujadas como contornos propios. |
| `make_icon.py` | Cabecera. Arte del juego. | Icono sin fondo negro. | Inundación desde los bordes. |

Documentación de flujo: `assets/textures/README.md` (30 líneas). Su paso 5 cita `tools/lighting/measure_albedo.gd`, que existe. Ese script escribe `game/world/hotel/material_albedo.gd`, una tabla de 26 colores medios sRGB por material del hotel (`material_albedo.gd:4`, "do not edit by hand"). La consumen `game/world/hotel/bounce_light.gd` y `game/world/office/office_bounce.gd`.

## 6. Cómo se asignan a la geometría generada

**Hotel, cajas en lotes** (`hotel_geometry.gd`):
- `box()` (530) no crea nodos. Anota la caja en un grupo por sala y por par material+forma (`SHAPES`, línea 136: box, cylinder, cone, plain, detail, detail_cylinder). `batch_target()` (516) busca la sala.
- `flush()` (590-635) crea un `MultiMeshInstance3D` por grupo. La malla es un `BoxMesh` de tamaño 1 (o `CylinderMesh`) y la escala va en la transformada de cada instancia. `mesh.material = materials[material_of(group)]` (595).
- Dentro de una sala, `use_custom_data = true` y cada instancia lleva la sala en `set_instance_custom_data` (601-606). El shader lo lee como `INSTANCE_CUSTOM` en `room_data` (`surface.gdshaderinc:13` y `:16`).
- Fuera de sala, `gi_mode` queda desactivado (612).
- Grupos con material en `SWAYING` (`["curtain"]`, línea 585) proyectan sombra con una copia fija (`_Shadow`, `shadows_only`).
- Cajas sólidas: `StaticBody3D` por sala (530-566, `solids`).

**Modelos importados del hotel:** `instance.material_override = materials[entry.material]` (`hotel_geometry.gd:654`).

**UV y coordenadas:**
- Shaders de superficie: `face_uv()` (`surface.gdshaderinc:70-75`) elige el plano según la normal dominante y devuelve coordenadas en metros (x-z en suelo y techo, x-y o z-y en paredes). No se usan UV de malla.
- `map_uv()` = `face_uv() / map_metres` (`image_maps.gdshaderinc:46`).
- Madera: `grain` en metros, por pieza, con corte aleatorio de origen `hash13(floor(origin*7.1))` (`wood.gdshaderinc:64`). En `object_space` (puertas) la veta sigue a la hoja.
- Tile con escaneo: `size = map_metres / tile_count` (`tile.gdshader:41`).
- StandardMaterial3D: usan UV de malla, excepto la lente (`uv1_triplanar`, `office_geometry.gd:447`).

**Oficinas:** las cajas pasan por `office_geometry.gd`, que usa el mismo sistema de `surface.gdshaderinc` a través de sus `.tres` (`MATERIAL_DIR`). Lo que no encaja (cristal de pared armada, persianas, halo de techo) usa shaders propios.

**Decals:** proyectores `Decal` con altura, tamaño, `distance_fade_begin = DECAL_REACH` (`hotel_geometry.gd:770-790`). Los oculta `decal_shown()` según `rank`, el preset (`decals`) y `echo_view` (`:792-795`).

## 7. Presets de calidad y renderer

Fuente: `graphics_presets.gd`. Los nombres están en la línea 20 (`NAMES`). El índice del preset es el de `PRESETS` (183), y `of()` lo acota a la tabla (303-305).

| Índice | Nombre | `surface_detail` | Anisotropía | `small_maps` (1024 px) | Líneas en `PRESETS` |
|---|---|---|---|---|---|
| 0 | Bajo | 2.0 | 2X (:191) | sí (:191) | 184-193 |
| 1 | Medio | 3.0 | 4X (:201) | no (:201) | 194-203 |
| 2 | Alto | 4.0 | 8X (:211) | no (:211) | 204-213 |
| 3 | Ultra | 5.0 | 16X (:221) | no (:221) | 214-223 |
| 4 | Muy bajo | 0.0 | desactivada (:233) | sí (:233) | 226-236 |

**Qué hace `surface_detail` en el shader:**
- `fbm` usa `clamp(int(surface_detail), 1, 4)` octavas (`surface.gdshaderinc:45`).
- Debajo de 2.5: `fine_noise` devuelve 0.5 (:64) y `map_no_tile` se desactiva (`image_maps.gdshaderinc:57`).
- Desde 2.5: `map_no_tile` activo.
- Por encima de 4.5: `finest_surface()` (:157). Acaban aquí las inclinaciones de baldosas (`tile.gdshader:81`), el lacado en capa (`wood_lacquer`, `hotel_geometry.gd:2594`) y la pelusa de la moqueta (`carpet.gdshader:63`).
- Bajo 0.5: `baked_surface()` (:182). Se dibuja `lite_map` y no hay escaneo ni ruido.

**Renderer:**
- `project.godot:57` fija `renderer/rendering_method.mobile="gl_compatibility"`.
- El valor por defecto de la opción de renderer es `forward_plus` (`settings_service.gd:6`, clave `"renderer"`).
- Si cambia, se escribe `user://renderer.cfg` (`settings_service.gd:149-157`).
- Si no es forward_plus, `of()` desactiva SSAO, SSIL, SSR, niebla, haze de suelo, TAA, autofocus, `lamp_fog`, `sconce_lights` y `bounce` (`graphics_presets.gd:308-318`).
- El comentario de decals dice "Forward+ only: Compatibility draws none" (`graphics_presets.gd:85-100`). Es un comentario, no comprobado en el motor.

**Configuración del motor en el arranque** (`presentation_rig.gd`):
- Antes de construir un piso: `level.GEOMETRY.small_maps = preset.small_maps` (218) y `no_maps = surface_detail < 0.5` (219).
- `viewport.anisotropic_filtering_level = preset.anisotropy` (280).
- `RenderingServer.global_shader_parameter_set("surface_detail", ...)` (285).
- Predeterminado del proyecto: `[shader_globals] surface_detail = 4.0` (`project.godot:64-68`). Filtro anisótropo por defecto 4 (`project.godot:60`).

## 8. Constantes y cifras que definen cómo se ve (ruta:línea)

**Iluminación de los bordes de sala** (`surface.gdshaderinc`):
- Retranqueo de paredes 0.12 m (:121-122).
- Caída de borde `exp(-two*3.2)` (:128).
- Suelo `exp(-(h+wall)*6)` (:130). Techo `exp(-(t+wall)*2.5)` (:131).
- En `room_grime()` (:136-148): oclusión ×0.55 (:141), suciedad de la base de pared (:144), humedad amarilla del techo ×0.45 (:146).

**Relieve de paredes y techos:** `plane_swell` con amplitudes 0.012 y 0.02 (:164).

**Finish y madera:**
- `finish.gdshader:37-62`: ramas de acabado (cepillado, tejido, arrugado, hoja).
- `wood.gdshaderinc:17` `lacquer_edge` 0.06 (aporte máximo del barniz vista de canto). `:118` barniz 0.75→0.28. `:135` rugosidad de capa 0.6+.

**Escaneos** (`image_maps.gdshaderinc`):
- Media de color en el nivel de mip 12 (:78).
- Coeficiente de luma en :79 con `LUMA = (0.2126, 0.7152, 0.0722)` (:36).

**Patrones de suelo y pared:**
- Papel (:10-16): rollo 0.53 m, motivo 0.46 m, ink_bleed 0.03 m.
- Moqueta (:10-14): medallón 0.62 m, fibra 0.035 m.
- Baldosa (:9-27): 0.3 m, junta 0.0035 m, `tile_count` 8, inclinación 0.045.

**Oficina** (`office_geometry.gd`):
- `LAMP_SPECULAR = 0.0` (:151).
- `LENS_ALBEDO = #e6e2d8` (:154), `LENS_LIT_DARK = 1.0` (:157).
- `HALO_REACH = 1.8` (:172), `HALO_BELOW = 0.002` (:173), `HALO_ENERGY = 0.22` (:174).
- `SCREEN_ROUGHNESS = 0.3` (:230).
- `BLIND_PITCH = 0.022` (:76), `BLIND_COLOR = #cbbf9f` (:86).
- Polvo: `MOTES_MOST = 140` (:1321), `MOTE_ALPHA = (0.6, 1.0)` (:1322).

**Hotel** (`hotel_geometry.gd`):
- `EXIT_REACH = 14.0` (:124). `DECAL_REACH = 14.0` (:799).
- `CANVAS = (1.14, 0.78)` (:2663). Rugosidad de cuadros 0.62 (:2676).

**Lite** (`bake_lite_maps.gd`): `SUPER` 2 (:30), `BAND` 0.25 (:33), `TALLEST` 4.8 m (:35).

**Presets:** `NAMES` (:20), `PRESETS` (:183), `surface_detail` en 191, 201, 211, 221 y 233.

## 9. Orden de ejecución, física y azar

**Orden de carga:**
- `apply_scan()` lee `GEOMETRY.small_maps` y `no_maps`, que deben estar fijadas antes de construir el piso (`presentation_rig.gd:218-219`). Después `apply_quality()` vuelve a aplicarlas (`hotel_geometry.gd:2580-2588`).
- `scans` y `lite` son `static var` (`hotel_geometry.gd:438` y :440). Se comparten entre constructores. `scan_maps()` borra el tamaño contrario (:481-493).
- `_init()` del hotel (399) duplica los `.tres`. Un cambio posterior en `materials` no afecta a los duplicados ya creados.

**Cambios en ejecución:**
- `global_shader_parameter_set("surface_detail")` se llama en `presentation_rig.gd:285`. Afecta a todo superficie en pantalla.
- `lacquer()` cambia `material.shader` en `apply_quality()` (`hotel_geometry.gd:2594`).
- `set_shader_parameter` tiene 197 llamadas en `game/` (ver sección 10). Por ejemplo, la energía del halo cambia cada frame (`office_geometry.gd:2472`).

**Azar y determinismo:**
- `hotel_geometry.gd:503-506` `vary()` usa `sin(...)*43758.5453` con `looks` (la semilla del piso). No consume el RNG del generador.
- `hotel_geometry.gd:494-495` `looks_of()` usa `hash([run_seed, "looks"])`. Determinismo de `hash()` de Array entre máquinas: sin comprobar.
- `office_geometry.gd:1327-1328` `build_dust()`: `RandomNumberGenerator` con `seed = 6113`. Los alfas de las motas salen de `randf_range` (:1344).
- Los shaders usan hash y ruido sobre la posición de mundo (`surface.gdshaderinc:18-22`). Son deterministas por posición y no dependen del frame.
- `hotel_geometry.gd` no llama a `randf`, `randi`, `randomize` ni `RandomNumberGenerator` en la parte de materiales (grep).

**Tiempo y cámara en los shaders:**
- `curtain.gdshader:11` usa `TIME` (balanceo de 3.5 cm). `SWAYING` evita que el balanceo afecte a la sombra (`hotel_geometry.gd:585`).
- `carpet.gdshader:68` usa `CAMERA_POSITION_WORLD` (inclinación del pelo según la cámara, solo en finest).
- `wood.gdshaderinc:131` usa `VIEW` (Fresnel de la laca).
- `blood.gdshader:35` y `blood_pool.gdshader:31` usan `CAMERA_POSITION_WORLD` para separar la sangre de la superficie.
- `blood` y `blood_pool` tienen `clock` y `age` como uniforms que el código cambia cada frame.

**Física:** ningún material depende de física. Las colisiones son cuerpos aparte (`hotel_geometry.gd:530-566`). `curtain.gdshader:2-3` dice que la cortina no mueve la colisión.

## 10. Clases y nodos del motor usados en esta parte

Conteo de líneas que coinciden en `game/**/*.gd`. Es una aproximación, no un conteo de instancias. `SubViewport`, `VoxelGI` y `ReflectionProbe` son sobre todo iluminación y posprocesado.

| Clase o llamada | Líneas | Uso en esta parte |
|---|---:|---|
| `StandardMaterial3D.new` | 41 | Stand-ins de oficina, cuadros, lentes, LEDs, cristal |
| `ShaderMaterial.new` | 26 | Decals, halo, lentes de cámara, sangre, polvo |
| `set_shader_parameter` | 197 | Ajustes en ejecución de casi todos los shaders |
| `material_override` | 51 | Asignación por nodo |
| `set_surface_override_material` | 10 | Cambios por superficie (luces, lentes) |
| `uv1_scale` / `uv1_offset` | 11 | Cuadros, rótulos |
| `uv1_triplanar` | 1 | Lente de oficina |
| `next_pass` | 2 | Capa de sangre en `avatar_visual.gd` |
| `global_shader_parameter_set` | 1 | `surface_detail` (`presentation_rig.gd:285`) |
| `Decal.new` | 3 | `hotel_geometry.gd:764`, `lurker_visual.gd:165` y `:174` |
| `MultiMeshInstance3D.new` | 12 | Lotes de cajas y modelos |
| `MultiMesh.new` | 11 | Lotes de cajas y modelos |
| `set_instance_custom_data` / `use_custom_data` | 17 | `room_data` por sala |
| `BoxMesh.new` | 29 | Malla unidad de las cajas |
| `QuadMesh.new` | 16 | Cuadros, polvo, pantallas |
| `CylinderMesh.new` | 5 | Cilindros de los lotes |
| `SphereMesh.new` | 3 | Cúpula de lámpara |
| `ArrayMesh.new` | 8 | Marco tallado y mallas a medida |
| `SubViewport` | 27 | Posprocesado y horneado (`bake_lite_maps.gd:142`) |
| `VoxelGI` | 15 | Luz de rebote (fuera de materiales) |
| `ReflectionProbe` | 5 | Sondas (fuera de materiales) |

Lo que no está en `game/` y es parte de la cadena: `tools/textures/*.py`, `tools/textures/bake_lite_maps.gd` (`SubViewport`, `BoxMesh`, `Camera3D` ortogonal) y `tools/lighting/measure_albedo.gd`.

## 11. Pruebas que vigilan esta parte

54 archivos `.gd` bajo `tests/` (medido). El encargo mencionaba 106, probablemente contando `.uid`. Búsqueda por grep de los asserts de materiales:

- `tests/office/office_finishes_test.gd` (346): acabados de oficina. `DIR` (:11) y `PLAIN_TRES` (:16). Claves comprobadas (:77, :107). Comprueba que la placa usa `ceiling_tile.gdshader` (:116).
- `tests/office/office_light_test.gd` (747): colores de rebote para las claves de `PLAIN` y de `OWN_OVER` (:104-109).
- `tests/hotel/hotel_test.gd` (723): preset Ultra con barniz en capa propia (:477) y preset Muy bajo sin escaneos ni brillo (:508).
- `tests/hotel/scene_contract_test.gd` (339): `mirror.tres` (:132) y `hotel_environment.tres` (:21).
- `tests/hotel/palette_scan_test.gd` (302): **no es de materiales.** Escanea scripts por tipos de sala.
- `CLAUDE.md` (raíz del repo): el piso 1 lo vigilan `manifest_golden_test` y `creature_contract_test`, y no debe cambiar salvo que el encargo lo diga.

No se ejecutó ninguna prueba.

## 12. Hechos que complican un port (sin diseño)

Son hechos del código actual que cualquier port tendría que resolver. No es diseño.

1. **Coordenadas de mundo, no UV.** El shader calcula `wp` y `wn` en el vértice con `MODEL_MATRIX` (`surface.gdshaderinc:16`). Las cajas no tienen UV útiles. La madera además cambia la veta según el origen del lote (`wood.gdshaderinc:64`).
2. **Datos por instancia.** `room_data` se lee de `INSTANCE_CUSTOM` (`surface.gdshaderinc:13,16`) y lo escribe `flush()` (`hotel_geometry.gd:601-606`). Lo usa el polvo de rincones, el suelo y el techo.
3. **Mapeo por plano con mip y derivadas explícitas.** `map_lookup` calcula `dFdx`/`dFdy` antes de desplazar la UV (`image_maps.gdshaderinc:48-53`). `textureGrad` se usa en las muestras (:68).
4. **Media de color del escaneo** en el nivel de mip 12 (`image_maps.gdshaderinc:78`), con el comentario "the smallest mip".
5. **Normal reconstruida de dos canales.** Z se recalcula desde XY (`surface.gdshaderinc:101-106`), por si la importación guarda dos canales.
6. **Lacado en shader aparte.** Hay un segundo shader de madera solo por coste (`wood.gdshaderinc:2-6`, comentario). `apply_quality` cambia de shader en ejecución (`hotel_geometry.gd:2714-2720`).
7. **Imágenes lite son fotografías del propio shader.** `bake_lite_maps.gd:139-194` renderiza el material a 4.0 de `surface_detail` con luz plana y la repite. Por tanto Muy bajo depende de la salida del shader.
8. **Efectos solo de forward_plus.** Decals, SSAO, SSIL, SSR, niebla, TAA, bounce (`graphics_presets.gd:303-318`).
9. **Escaneo solo para ShaderMaterial.** `apply_scan` sale si el material no es `ShaderMaterial` (`hotel_geometry.gd:447`). Los StandardMaterial3D usan sus propios mapas.
10. **Inventario de shaders de mundo muy acoplado.** Usan `#include` de `surface.gdshaderinc` e `image_maps.gdshaderinc`, macros (`SURFACE_VERTEX`, `BUMPED_VIEW_NORMAL`), `global uniform` y `render_mode` distintos (`ceiling_halo`: `blend_add`, `unshaded`; `blood`: `world_vertex_coords`).
11. **Cambios por frame.** Muchos `set_shader_parameter` en ejecución (197 llamadas), por ejemplo `clock` y `age` de la sangre, y la energía del halo.
12. **Proporción de escaneo.** Hotel: cuadrado forzado (`ingest_pbr.py:210`). Oficinas: conserva proporción. Un set de proporción distinta a la del hotel tiene que tratarse distinto.

## 13. Sin comprobar

- **Apariencia real.** No se renderizó nada ni se hizo ninguna captura. Las cifras son de código, no de pantalla.
- **Peso en disco de `assets/textures/`.** No medido.
- **`hotel_geometry.gd` y `office_geometry.gd` completos.** Solo los tramos de la sección 0.
- **Los 192 `ORMMaterial3D` de `assets/props/`.** Solo conteo por carpeta: 112 en office, 80 en hotel.
- **Shaders `analog`, `lens` y `lens_blood`.** Solo cabecera y uniforms.
- **Scripts `bake_blood.py`, `bake_do_not_disturb.py`, `bake_hotel_note.py`, `make_exit_sign.py` y `make_icon.py`.** Solo docstring.
- **`ingest_dressing.py` y `check_ingest_pbr.py`.** Cuerpo completo no leído.
- **Licencias.** Tomadas del registro `docs/ASSETS.md`, no comparadas con las fichas de origen. La línea 397 del registro (Met 452567) está cortada y no se leyó la licencia.
- **Contenido de `rug.tres`.** No leído.
- **Qué `.tres` concreto carga cada builder de `tools/props/`.** Solo se verificó la carpeta en `build_camcorder.gd:13`, `build_elevator.gd:19`, `build_model_props.gd:6`, `build_door.gd:16`; y `wardrobe.tres` y `wardrobe_inside.tres` en `build_wardrobe.gd:156` y `:203`.
- **`hash()` de Array.** Determinismo entre máquinas y versiones de Godot: no comprobado.
- **Decals en gl_compatibility.** El comentario de `graphics_presets.gd:85-100` dice que no se dibujan. No se verificó en el motor.
- **Pruebas.** No ejecutadas.
- **Paso 5 de `assets/textures/README.md`.** Existencia de `tools/lighting/measure_albedo.gd` confirmada, pero su contenido no leído.
- **Fechas de descarga y versiones de los sets.** No revisadas.
- **Subida a Unreal.** Nada de lo anterior se ha comparado con Unreal ni con el motor 5.8.4 instalado.

## Anexos

- **Anexo A:** catálogo de los 105 `.tres` de `game/presentation/materials/` (generado).
- **Anexo B:** inventario de `assets/textures/` con dimensiones (generado por cabecera).
- **Anexo C:** líneas de los archivos leídos (generado con `wc -l`).


## Anexo A: catálogo de los 105 `.tres` de game/presentation/materials/ (generado)

| Archivo (bajo game/presentation/materials/) | Líneas | Tipo | Shader | Metadato scan | Parámetros numéricos, colores (conteo) y texturas |
|---|---:|---|---|---|---|
| `bed.tres` | 22 | StandardMaterial3D | - | - | texture_filter=5, metallic=1.0, metallic_texture_channel=2, roughness_texture_channel=1, normal_enabled=true, ao_enabled=true, ao_texture_channel=0; tex: bed_albedo.jpg, bed_orm.jpg, bed_normal.png |
| `bedspread.tres` | 19 | ShaderMaterial | finish.gdshader | quatrefoil_jacquard_fabric | roughness=0.95, finish=2, sheen=0.18, grime=0.15, map_metres=0.4, map_mode=1, map_roughness=0.15, map_metallic=0.0 (+4 colores) |
| `black.tres` | 11 | ShaderMaterial | finish.gdshader | - | roughness=0.42, grime=0.2 (+3 colores) |
| `camcorder_body.tres` | 20 | StandardMaterial3D | - | - | texture_filter=5, metallic=1.0, normal_enabled=true, ao_enabled=true; tex: body_albedo.jpg, body_metallic.jpg, body_roughness.jpg, body_normal.png, body_ao.jpg |
| `camcorder_lens.tres` | 17 | StandardMaterial3D | - | - | texture_filter=5, metallic_specular=0.8, roughness=0.35, normal_enabled=true (+1 colores); tex: lens_albedo.jpg, lens_roughness.jpg, lens_normal.png |
| `carpet.tres` | 15 | ShaderMaterial | carpet.gdshader | carpet016 | map_metres=0.9, map_mode=2, map_detail=1.8, map_no_tile=true, map_roughness=0.3, normal_strength=1.4 (+2 colores) |
| `ceiling.tres` | 14 | ShaderMaterial | ceiling.gdshader | ceiling_interior | map_metres=1.0, map_mode=2, map_detail=0.6, map_no_tile=true, map_roughness=0.19, normal_strength=0.35 (+1 colores) |
| `ceiling_service.tres` | 14 | ShaderMaterial | ceiling.gdshader | officeceiling001 | map_metres=3.6, map_mode=1, map_no_tile=false, stains=0.8, map_roughness=0.15 (+2 colores) |
| `ceramic.tres` | 12 | ShaderMaterial | finish.gdshader | - | roughness=0.28, specular=0.6, grime=0.35 (+3 colores) |
| `curtain.tres` | 7 | ShaderMaterial | curtain.gdshader | - | - (+1 colores) |
| `door.tres` | 15 | ShaderMaterial | wood.gdshader | lacquered_cherry_wood | object_space=true, door_panels=true, map_mode=1, map_metres=1.0 (+4 colores) |
| `door_frame.tres` | 17 | StandardMaterial3D | - | - | texture_filter=5, metallic=1.0, normal_enabled=true; tex: frame_basecolor.png, frame_metallic.png, frame_roughness.png, frame_normal.png |
| `door_leaf.tres` | 17 | StandardMaterial3D | - | - | texture_filter=5, metallic=1.0, normal_enabled=true; tex: leaf_basecolor.png, leaf_metallic.png, leaf_roughness.png, leaf_normal.png |
| `fabric.tres` | 19 | ShaderMaterial | finish.gdshader | velour_velvet | roughness=0.95, finish=2, sheen=0.18, grime=0.15, map_metres=0.3, map_mode=1, map_roughness=0.2, map_metallic=0.0 (+4 colores) |
| `gold.tres` | 18 | ShaderMaterial | finish.gdshader | metal048b | roughness=0.32, metallic=0.95, finish=1, grime=0.5, map_metres=0.6, map_mode=1, map_roughness=0.15 (+4 colores) |
| `green.tres` | 10 | ShaderMaterial | finish.gdshader | - | roughness=0.6 (+3 colores) |
| `leaf.tres` | 14 | ShaderMaterial | finish.gdshader | - | roughness=0.55, finish=4, detail_scale=3.0, backlight=0.5, grime=0.1 (+3 colores) |
| `leather.tres` | 18 | ShaderMaterial | finish.gdshader | brown_leather | roughness=0.5, finish=3, detail_scale=0.4, relief=0.15, grime=0.45, map_metres=0.4, map_mode=1 (+4 colores) |
| `lift_buttons.tres` | 21 | StandardMaterial3D | - | - | texture_filter=5, metallic=0.4, roughness=0.5, emission_enabled=true, emission_energy_multiplier=2.5, emission_operator=1 (+1 colores); tex: buttons.jpg, buttons_metal.jpg, buttons_emission.jpg |
| `lift_call.tres` | 11 | StandardMaterial3D | - | - | texture_filter=5, metallic=0.5, roughness=0.35; tex: call_buttons.jpg |
| `lift_floor.tres` | 11 | StandardMaterial3D | - | - | texture_filter=5, metallic=0.45, roughness=0.45; tex: floor.jpg |
| `lift_light.tres` | 10 | StandardMaterial3D | - | - | roughness=0.6, emission_enabled=true, emission_energy_multiplier=2.2 (+2 colores) |
| `lift_metal.tres` | 10 | StandardMaterial3D | - | - | metallic=0.55, roughness=0.34 (+1 colores) |
| `lift_metal_dark.tres` | 12 | StandardMaterial3D | - | - | texture_filter=5, metallic=0.5, roughness=0.4; tex: metal.jpg |
| `lift_screen.tres` | 9 | StandardMaterial3D | - | - | metallic=0.2, roughness=0.12 (+1 colores) |
| `lift_wood.tres` | 10 | StandardMaterial3D | - | - | texture_filter=5, roughness=0.38; tex: wood.jpg |
| `light.tres` | 8 | StandardMaterial3D | - | - | roughness=0.88, emission_enabled=true, emission_energy_multiplier=1.0 (+2 colores) |
| `linen.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.92, finish=3, grime=0.3, map_metres=0.6 (+3 colores) |
| `metal.tres` | 14 | ShaderMaterial | finish.gdshader | - | roughness=0.38, metallic=0.9, finish=1, grime=0.45, map_metres=0.5 (+3 colores) |
| `mirror.tres` | 7 | StandardMaterial3D | - | - | metallic=1.0, roughness=0.04, specular_mode=2 (+1 colores) |
| `monstera_leaf.tres` | 20 | StandardMaterial3D | - | - | texture_filter=5, transparency=2, alpha_scissor_threshold=0.5, cull_mode=2, normal_enabled=true, backlight_enabled=true (+1 colores); tex: leaf_albedo.png, leaf_roughness.png, leaf_normal.png |
| `monstera_pot.tres` | 14 | StandardMaterial3D | - | - | texture_filter=5, normal_enabled=true; tex: pot_albedo.png, pot_roughness.png, pot_normal.png |
| `office/block.tres` | 18 | ShaderMaterial | finish.gdshader | office_bricks019 | roughness=0.7, finish=0, grime=0.15, map_metres=0.9, map_mode=2, map_metallic=0.0, map_detail=0.35 (+4 colores) |
| `office/car_oak.tres` | 15 | ShaderMaterial | wood.gdshader | office_teak_veneer | ring_density=14.0, varnish=0.55, map_metres=1.0, map_mode=1 (+4 colores) |
| `office/cardboard.tres` | 17 | ShaderMaterial | finish.gdshader | office_cardboard004 | roughness=0.85, finish=0, grime=0.15, map_metres=0.6, map_mode=1, map_metallic=0.0 (+4 colores) |
| `office/carpet.tres` | 21 | ShaderMaterial | carpet.gdshader | office_fabric026 | pattern=0.0, wear=0.5, map_metres=1.0, map_mode=1, map_detail=1.6, map_no_tile=true, map_roughness=0.3, normal_strength=1.2 (+6 colores) |
| `office/carpet_exec.tres` | 21 | ShaderMaterial | carpet.gdshader | office_fabric028 | pattern=0.0, wear=0.5, map_metres=1.0, map_mode=0, map_detail=1.6, map_no_tile=true, map_roughness=0.3, normal_strength=1.2 (+6 colores) |
| `office/ceiling_service.tres` | 18 | ShaderMaterial | ceiling_tile.gdshader | officeceiling001 | map_metres=3.6, map_mode=2, map_detail=1.0, yellowed=0.45, ringed=0.22, cracked=0.12, map_roughness=0.15 (+4 colores) |
| `office/cloth_green.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.85, metallic=0.0, finish=2, grime=0.2 (+3 colores) |
| `office/cloth_navy.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.85, metallic=0.0, finish=2, grime=0.2 (+3 colores) |
| `office/cloth_red.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.85, metallic=0.0, finish=2, grime=0.2 (+3 colores) |
| `office/concrete.tres` | 18 | ShaderMaterial | finish.gdshader | office_painted_concrete_02 | roughness=0.5, finish=0, grime=0.15, map_metres=2.0, map_mode=1, map_roughness=-0.15, map_metallic=0.0 (+4 colores) |
| `office/cork.tres` | 17 | ShaderMaterial | finish.gdshader | office_cork003 | roughness=0.9, finish=0, grime=0.15, map_metres=0.5, map_mode=1, map_metallic=0.0 (+4 colores) |
| `office/dado_oak.tres` | 17 | ShaderMaterial | wood.gdshader | office_teak_veneer | ring_density=14.0, varnish=0.55, panel_spacing=1.2, map_metres=1.6, map_mode=1, map_no_tile=true (+4 colores) |
| `office/gate_steel.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.55, metallic=0.35, finish=0, grime=0.2 (+3 colores) |
| `office/glow_amber.tres` | 8 | StandardMaterial3D | - | - | roughness=0.3, emission_enabled=true, emission_energy_multiplier=1.6 (+2 colores) |
| `office/glow_green.tres` | 8 | StandardMaterial3D | - | - | roughness=0.3, emission_enabled=true, emission_energy_multiplier=1.4 (+2 colores) |
| `office/glow_red.tres` | 8 | StandardMaterial3D | - | - | roughness=0.3, emission_enabled=true, emission_energy_multiplier=1.8 (+2 colores) |
| `office/glow_strip.tres` | 8 | StandardMaterial3D | - | - | roughness=0.6, emission_enabled=true, emission_energy_multiplier=0.7 (+2 colores) |
| `office/glow_white.tres` | 8 | StandardMaterial3D | - | - | roughness=0.3, emission_enabled=true, emission_energy_multiplier=1.2 (+2 colores) |
| `office/laminate_light.tres` | 14 | ShaderMaterial | finish.gdshader | - | roughness=0.4, specular=0.5, metallic=0.0, finish=0, grime=0.25 (+3 colores) |
| `office/lamp_off.tres` | 5 | StandardMaterial3D | - | - | roughness=0.25 (+1 colores) |
| `office/mat_rib.tres` | 21 | ShaderMaterial | carpet.gdshader | office_fabric026 | pattern=0.0, wear=0.5, map_metres=0.5, map_mode=1, map_detail=1.35, map_no_tile=true, map_roughness=0.3, normal_strength=1.2 (+6 colores) |
| `office/oak_door.tres` | 16 | ShaderMaterial | wood.gdshader | office_teak_veneer | object_space=true, ring_density=14.0, varnish=0.55, map_metres=1.0, map_mode=1 (+4 colores) |
| `office/office_paint.tres` | 23 | ShaderMaterial | wallpaper.gdshader | wallpaper001a | roll_width=1.37, print_strength=0.0, stains=0.25, grime=0.35, ink_bleed=0.0, map_metres=1.2, map_mode=2, map_detail=0.9, map_no_tile=true, map_roughness=0.1, normal_strength=1.8 (+5 colores) |
| `office/office_paint_kept.tres` | 23 | ShaderMaterial | wallpaper.gdshader | wallpaper001a | roll_width=1.37, print_strength=0.25, stains=0.04, grime=0.08, ink_bleed=0.0, map_metres=1.2, map_mode=2, map_detail=0.35, map_no_tile=true, map_roughness=0.1, normal_strength=1.8 (+5 colores) |
| `office/paint_red.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.5, metallic=0.0, finish=0, grime=0.25 (+3 colores) |
| `office/paper.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.9, metallic=0.0, finish=0, grime=0.2 (+3 colores) |
| `office/paper_manila.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.9, metallic=0.0, finish=0, grime=0.2 (+3 colores) |
| `office/partition.tres` | 15 | ShaderMaterial | wallpaper.gdshader | - | roll_width=1.2, print_strength=0.0, stains=0.1, grime=0.45, ink_bleed=0.0 (+4 colores) |
| `office/partition_fabric.tres` | 17 | ShaderMaterial | finish.gdshader | office_hessian_380 | roughness=0.95, finish=2, grime=0.15, map_metres=0.27, map_mode=1, map_metallic=0.0 (+4 colores) |
| `office/plastic_beige.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.55, metallic=0.0, finish=0, grime=0.3 (+3 colores) |
| `office/quarry.tres` | 21 | ShaderMaterial | tile.gdshader | office_anti_skid_tiles | tile_size=0.2, grout_width=0.003, checker=0.2, grime=0.5, tile_count=6.0, map_metres=1.2, map_mode=1, map_roughness=0.0, map_metallic=0.0 (+5 colores) |
| `office/reception_low.tres` | 23 | ShaderMaterial | wallpaper.gdshader | wallpaper001a | roll_width=1.37, print_strength=0.25, stains=0.04, grime=0.08, ink_bleed=0.0, map_metres=1.2, map_mode=2, map_detail=0.35, map_no_tile=true, map_roughness=0.1, normal_strength=1.8 (+5 colores) |
| `office/reception_plaster.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.79, specular=0.32, grime=0.2, relief=0.34 (+3 colores) |
| `office/reception_steel.tres` | 16 | ShaderMaterial | finish.gdshader | - | roughness=0.24, metallic=0.8, finish=1, detail_scale=1.0, relief=0.25, grime=0.05, brush_across=true (+3 colores) |
| `office/reception_teak.tres` | 16 | ShaderMaterial | wood.gdshader | office_walnut_veneer | object_space=true, ring_density=30.0, varnish=0.7, map_metres=1.8, map_mode=1 (+4 colores) |
| `office/sign_red.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.35, metallic=0.0, finish=0, grime=0.12 (+3 colores) |
| `office/sign_white.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.35, metallic=0.0, finish=0, grime=0.12 (+3 colores) |
| `office/sign_yellow.tres` | 13 | ShaderMaterial | finish.gdshader | - | roughness=0.35, metallic=0.0, finish=0, grime=0.12 (+3 colores) |
| `office/slab.tres` | 18 | ShaderMaterial | finish.gdshader | office_concrete_wall_008 | roughness=0.85, finish=0, grime=0.45, map_metres=2.4, map_mode=2, map_detail=2.0, map_metallic=0.0 (+4 colores) |
| `office/steel_dark.tres` | 21 | ShaderMaterial | finish.gdshader | office_paintedmetal006 | roughness=0.7, metallic=0.0, finish=0, grime=0.15, map_metres=1.0, map_mode=2, map_detail=0.15, normal_strength=0.03, map_metallic=0.0, map_rough_keep=0.0 (+4 colores) |
| `office/steel_grey.tres` | 21 | ShaderMaterial | finish.gdshader | office_paintedmetal006 | roughness=0.45, metallic=0.0, finish=0, grime=0.03, map_metres=1.0, map_mode=2, map_detail=0.04, normal_strength=0.03, map_metallic=0.0, map_rough_keep=0.0 (+4 colores) |
| `office/steel_mint.tres` | 21 | ShaderMaterial | finish.gdshader | office_paintedmetal006 | roughness=0.45, metallic=0.0, finish=0, grime=0.03, map_metres=1.0, map_mode=2, map_detail=0.04, normal_strength=0.03, map_metallic=0.0, map_rough_keep=0.0 (+4 colores) |
| `office/steel_olive.tres` | 21 | ShaderMaterial | finish.gdshader | office_paintedmetal006 | roughness=0.45, metallic=0.0, finish=0, grime=0.03, map_metres=1.0, map_mode=2, map_detail=0.04, normal_strength=0.03, map_metallic=0.0, map_rough_keep=0.0 (+4 colores) |
| `office/steel_plate.tres` | 21 | ShaderMaterial | finish.gdshader | office_galvanizedsteel02 | roughness=0.4, metallic=0.0, finish=0, grime=0.15, map_metres=1.0, map_mode=2, map_detail=0.15, normal_strength=0.03, map_metallic=0.0, map_rough_keep=0.0 (+4 colores) |
| `office/taupe.tres` | 22 | ShaderMaterial | wallpaper.gdshader | wallpaper001a | roll_width=1.37, print_strength=0.0, stains=0.1, grime=0.6, ink_bleed=0.0, map_metres=1.2, map_mode=2, map_detail=1.2, map_no_tile=true, map_roughness=0.1 (+5 colores) |
| `office/terrazzo.tres` | 22 | ShaderMaterial | finish.gdshader | office_terrazzo003 | roughness=0.22, specular=0.5, finish=0, grime=0.15, relief=0.3, map_metres=0.35, map_mode=2, map_roughness=-0.12, normal_strength=0.4, map_metallic=0.0, map_detail=0.45 (+4 colores) |
| `office/tgrid.tres` | 6 | StandardMaterial3D | - | - | metallic=0.3, roughness=0.45 (+1 colores) |
| `office/threshold.tres` | 6 | StandardMaterial3D | - | - | metallic=0.8, roughness=0.4 (+1 colores) |
| `office/veneer.tres` | 17 | ShaderMaterial | wood.gdshader | office_walnut_veneer | ring_density=18.0, varnish=0.6, panel_spacing=1.2, map_metres=1.8, map_mode=1, map_no_tile=true (+4 colores) |
| `office/vinyl.tres` | 22 | ShaderMaterial | tile.gdshader | office_tiles110 | tile_size=0.3, grout_width=0.0012, checker=0.5, grime=0.35, tile_count=4.0, map_metres=1.2, map_mode=1, map_roughness=-0.17, normal_strength=0.4, map_metallic=0.0 (+5 colores) |
| `office/vinyl_hall.tres` | 17 | ShaderMaterial | tile.gdshader | - | tile_size=0.305, grout_width=0.0011, checker=1.0, grime=0.3, specular_level=0.5, marble=0.22, wear=0.6 (+4 colores) |
| `office/vinyl_polished.tres` | 25 | ShaderMaterial | tile.gdshader | office_tiles110 | tile_size=0.3, grout_width=0.0012, checker=0.5, grime=0.12, tile_count=6.0, map_metres=1.2, map_mode=1, map_roughness=-0.45, normal_strength=0.18, map_metallic=0.0, specular_level=0.6, tilt_always=true, tilt=0.07 (+5 colores) |
| `office/walnut.tres` | 16 | ShaderMaterial | wood.gdshader | office_walnut_veneer | ring_density=30.0, varnish=0.7, panel_spacing=0.9, map_metres=1.8, map_mode=1 (+4 colores) |
| `office/walnut_object.tres` | 16 | ShaderMaterial | wood.gdshader | office_walnut_veneer | object_space=true, ring_density=30.0, varnish=0.7, map_metres=1.8, map_mode=1 (+4 colores) |
| `office/wet_band.tres` | 21 | ShaderMaterial | tile.gdshader | office_tiles032 | tile_size=0.15, grout_width=0.0015, checker=0.15, grime=0.4, tile_count=8.0, map_metres=1.2, map_mode=1, map_roughness=-0.2, map_metallic=0.0 (+5 colores) |
| `office/wet_tile.tres` | 21 | ShaderMaterial | tile.gdshader | tiles036 | tile_size=0.15, grout_width=0.0015, checker=0.15, grime=0.4, tile_count=8.0, map_metres=1.2, map_mode=1, map_roughness=0.05, map_metallic=0.0 (+5 colores) |
| `painting.tres` | 7 | ShaderMaterial | painting.gdshader | - | - (+1 colores) |
| `panel.tres` | 14 | ShaderMaterial | wood.gdshader | dark_wood | panel_spacing=0.6, map_metres=2.0, map_mode=1 (+4 colores) |
| `plaster.tres` | 14 | ShaderMaterial | wallpaper.gdshader | wallpaper001a | map_metres=1.2, map_mode=2, map_detail=2.0, map_no_tile=true, map_roughness=0.16, normal_strength=1.5 (+1 colores) |
| `plaster_decrepit.tres` | 17 | ShaderMaterial | wallpaper.gdshader | decrepit_wallpaper | map_metres=2.5, map_mode=1, map_detail=1.0, map_no_tile=true, print_strength=0.3, stains=0.8, grime=0.8, map_roughness=-0.1 (+2 colores) |
| `screen.tres` | 12 | ShaderMaterial | finish.gdshader | - | roughness=0.07, specular=0.7, grime=0.15 (+3 colores) |
| `shade.tres` | 10 | StandardMaterial3D | - | - | roughness=0.95, backlight_enabled=true, emission_enabled=true, emission_energy_multiplier=0.3 (+3 colores) |
| `sofa.tres` | 18 | StandardMaterial3D | - | - | texture_filter=5, normal_enabled=true, ao_enabled=true (+1 colores); tex: albedo.jpg, roughness.jpg, normal.jpg, ao.jpg |
| `tile.tres` | 12 | ShaderMaterial | tile.gdshader | tiles036 | map_metres=1.6, map_mode=1, tile_count=8.0 (+2 colores) |
| `trim.tres` | 15 | ShaderMaterial | wood.gdshader | dark_wood | ring_density=40.0, varnish=0.8, map_metres=2.0, map_mode=1 (+4 colores) |
| `tv_body.tres` | 20 | StandardMaterial3D | - | - | texture_filter=5, metallic=1.0, normal_enabled=true, ao_enabled=true; tex: body_albedo.png, body_metallic.png, body_roughness.png, body_normal.png, body_ao.png |
| `vhs_tape.tres` | 19 | StandardMaterial3D | - | - | texture_filter=5, metallic=1.0, normal_enabled=true, ao_enabled=true; tex: albedo.jpg, metallic.jpg, roughness.jpg, normal.png, ao.jpg |
| `wall_lamp_bulb.tres` | 10 | StandardMaterial3D | - | - | emission_enabled=true, emission_energy_multiplier=14.0 (+2 colores) |
| `wall_lamp_cloth.tres` | 25 | StandardMaterial3D | - | - | texture_filter=5, normal_enabled=true, emission_enabled=true, emission_energy_multiplier=2.6, backlight_enabled=true (+2 colores); tex: cloth_albedo.png, cloth_roughness.png, cloth_normal.png |
| `wall_lamp_metal.tres` | 17 | StandardMaterial3D | - | - | texture_filter=5, metallic=1.0, normal_enabled=true; tex: metal_albedo.png, metal_metallic.png, metal_roughness.png, metal_normal.png |
| `wardrobe.tres` | 23 | StandardMaterial3D | - | - | texture_filter=5, cull_mode=2, metallic=1.0, normal_enabled=true, ao_enabled=true (+1 colores); tex: albedo.jpg, metallic.jpg, roughness.jpg, normal.png, ao.jpg |
| `wardrobe_inside.tres` | 24 | StandardMaterial3D | - | - | texture_filter=5, cull_mode=2, metallic=1.0, ao_enabled=true (+1 colores); tex: albedo.jpg, metallic.jpg, roughness.jpg, ao.jpg |
| `wood.tres` | 11 | ShaderMaterial | wood.gdshader | lacquered_cherry_wood | map_metres=1.0, map_mode=1 (+2 colores) |

Total: 105 archivos.


## Anexo B: inventario de assets/textures/ con dimensiones (generado por cabecera de imagen)

Cada línea: carpeta, y luego archivo y dimensiones. `lite/` son las imágenes del preset Muy bajo; los PNG de la raíz de `assets/textures/` no son sets.

```
brown_leather | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
carpet016 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
ceiling_interior | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
dark_wood | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
decrepit_wallpaper | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
lacquered_cherry_wood | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
lite | bedspread.png 128x128; black.png 128x128; carpet.png 512x512; ceiling.png 512x512; ceiling_service.png 512x512; ceramic.png 128x128; door.png 512x512; fabric.png 128x128; gold.png 128x128; green.png 128x128; leaf.png 128x128; leather.png 128x128; linen.png 128x128; metal.png 128x128; panel.png 512x512; plaster.png 1024x1224; plaster_decrepit.png 1024x1224; screen.png 128x128; tile.png 512x512; trim.png 512x512; wood.png 512x512
metal048b | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_anti_skid_tiles | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_bricks019 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_cardboard004 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_concrete_wall_008 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_cork003 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_dark_paneled_wood | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_fabric026 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_fabric028 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_galvanizedsteel02 | albedo.jpg 1024x1024; albedo_1k.jpg 1024x1024; normal.jpg 1024x1024; normal_1k.jpg 1024x1024; orm.jpg 1024x1024; orm_1k.jpg 1024x1024
office_hessian_380 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_painted_concrete_02 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_paintedmetal006 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_rug_met452567 | albedo.png 1024x1388
office_teak_veneer | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_terrazzo003 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_tiles032 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_tiles043 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_tiles110 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
office_walnut_veneer | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
officeceiling001 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
quatrefoil_jacquard_fabric | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
tiles036 | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
velour_velvet | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
wallpaper001a | albedo.jpg 2048x2048; albedo_1k.jpg 1024x1024; normal.jpg 2048x2048; normal_1k.jpg 1024x1024; orm.jpg 2048x2048; orm_1k.jpg 1024x1024
```

## Anexo C: líneas de los archivos leídos (wc -l)

```
      22 game/presentation/materials/bed.tres
      19 game/presentation/materials/bedspread.tres
      11 game/presentation/materials/black.tres
      20 game/presentation/materials/camcorder_body.tres
      17 game/presentation/materials/camcorder_lens.tres
      15 game/presentation/materials/carpet.tres
      14 game/presentation/materials/ceiling.tres
      14 game/presentation/materials/ceiling_service.tres
      12 game/presentation/materials/ceramic.tres
       7 game/presentation/materials/curtain.tres
      15 game/presentation/materials/door.tres
      17 game/presentation/materials/door_frame.tres
      17 game/presentation/materials/door_leaf.tres
      19 game/presentation/materials/fabric.tres
      18 game/presentation/materials/gold.tres
      10 game/presentation/materials/green.tres
      14 game/presentation/materials/leaf.tres
      18 game/presentation/materials/leather.tres
      21 game/presentation/materials/lift_buttons.tres
      11 game/presentation/materials/lift_call.tres
      11 game/presentation/materials/lift_floor.tres
      10 game/presentation/materials/lift_light.tres
      10 game/presentation/materials/lift_metal.tres
      12 game/presentation/materials/lift_metal_dark.tres
       9 game/presentation/materials/lift_screen.tres
      10 game/presentation/materials/lift_wood.tres
       8 game/presentation/materials/light.tres
      13 game/presentation/materials/linen.tres
      14 game/presentation/materials/metal.tres
       7 game/presentation/materials/mirror.tres
      20 game/presentation/materials/monstera_leaf.tres
      14 game/presentation/materials/monstera_pot.tres
       7 game/presentation/materials/painting.tres
      14 game/presentation/materials/panel.tres
      14 game/presentation/materials/plaster.tres
      17 game/presentation/materials/plaster_decrepit.tres
      12 game/presentation/materials/screen.tres
      10 game/presentation/materials/shade.tres
      18 game/presentation/materials/sofa.tres
      12 game/presentation/materials/tile.tres
      15 game/presentation/materials/trim.tres
      20 game/presentation/materials/tv_body.tres
      19 game/presentation/materials/vhs_tape.tres
      10 game/presentation/materials/wall_lamp_bulb.tres
      25 game/presentation/materials/wall_lamp_cloth.tres
      17 game/presentation/materials/wall_lamp_metal.tres
      23 game/presentation/materials/wardrobe.tres
      24 game/presentation/materials/wardrobe_inside.tres
      11 game/presentation/materials/wood.tres
      18 game/presentation/materials/office/block.tres
      15 game/presentation/materials/office/car_oak.tres
      17 game/presentation/materials/office/cardboard.tres
      21 game/presentation/materials/office/carpet.tres
      21 game/presentation/materials/office/carpet_exec.tres
      18 game/presentation/materials/office/ceiling_service.tres
      13 game/presentation/materials/office/cloth_green.tres
      13 game/presentation/materials/office/cloth_navy.tres
      13 game/presentation/materials/office/cloth_red.tres
      18 game/presentation/materials/office/concrete.tres
      17 game/presentation/materials/office/cork.tres
      17 game/presentation/materials/office/dado_oak.tres
      13 game/presentation/materials/office/gate_steel.tres
       8 game/presentation/materials/office/glow_amber.tres
       8 game/presentation/materials/office/glow_green.tres
       8 game/presentation/materials/office/glow_red.tres
       8 game/presentation/materials/office/glow_strip.tres
       8 game/presentation/materials/office/glow_white.tres
      14 game/presentation/materials/office/laminate_light.tres
       5 game/presentation/materials/office/lamp_off.tres
      21 game/presentation/materials/office/mat_rib.tres
      16 game/presentation/materials/office/oak_door.tres
      23 game/presentation/materials/office/office_paint.tres
      23 game/presentation/materials/office/office_paint_kept.tres
      13 game/presentation/materials/office/paint_red.tres
      13 game/presentation/materials/office/paper.tres
      13 game/presentation/materials/office/paper_manila.tres
      15 game/presentation/materials/office/partition.tres
      17 game/presentation/materials/office/partition_fabric.tres
      13 game/presentation/materials/office/plastic_beige.tres
      21 game/presentation/materials/office/quarry.tres
      23 game/presentation/materials/office/reception_low.tres
      13 game/presentation/materials/office/reception_plaster.tres
      16 game/presentation/materials/office/reception_steel.tres
      16 game/presentation/materials/office/reception_teak.tres
      13 game/presentation/materials/office/sign_red.tres
      13 game/presentation/materials/office/sign_white.tres
      13 game/presentation/materials/office/sign_yellow.tres
      18 game/presentation/materials/office/slab.tres
      21 game/presentation/materials/office/steel_dark.tres
      21 game/presentation/materials/office/steel_grey.tres
      21 game/presentation/materials/office/steel_mint.tres
      21 game/presentation/materials/office/steel_olive.tres
      21 game/presentation/materials/office/steel_plate.tres
      22 game/presentation/materials/office/taupe.tres
      22 game/presentation/materials/office/terrazzo.tres
       6 game/presentation/materials/office/tgrid.tres
       6 game/presentation/materials/office/threshold.tres
      17 game/presentation/materials/office/veneer.tres
      22 game/presentation/materials/office/vinyl.tres
      17 game/presentation/materials/office/vinyl_hall.tres
      25 game/presentation/materials/office/vinyl_polished.tres
      16 game/presentation/materials/office/walnut.tres
      16 game/presentation/materials/office/walnut_object.tres
      21 game/presentation/materials/office/wet_band.tres
      21 game/presentation/materials/office/wet_tile.tres
      19 game/presentation/materials/office/ceiling_halo.gdshader
      60 game/presentation/materials/office/ceiling_tile.gdshader
     286 game/presentation/shaders/analog.gdshader
      62 game/presentation/shaders/blood.gdshader
      87 game/presentation/shaders/blood_pool.gdshader
      60 game/presentation/shaders/blood_worn.gdshader
      82 game/presentation/shaders/carpet.gdshader
      34 game/presentation/shaders/ceiling.gdshader
      27 game/presentation/shaders/curtain.gdshader
      67 game/presentation/shaders/exit_panel.gdshader
      85 game/presentation/shaders/finish.gdshader
      92 game/presentation/shaders/lens.gdshader
      30 game/presentation/shaders/painting.gdshader
      89 game/presentation/shaders/tile.gdshader
      32 game/presentation/shaders/typewriter_ink.gdshader
      17 game/presentation/shaders/venetian_blind.gdshader
      84 game/presentation/shaders/wallpaper.gdshader
      30 game/presentation/shaders/wired_glass.gdshader
       4 game/presentation/shaders/wood.gdshader
       5 game/presentation/shaders/wood_lacquer.gdshader
     112 game/presentation/shaders/image_maps.gdshaderinc
     196 game/presentation/shaders/lens_blood.gdshaderinc
     205 game/presentation/shaders/surface.gdshaderinc
     142 game/presentation/shaders/wood.gdshaderinc
    3298 game/world/hotel/hotel_geometry.gd
    2841 game/world/office/office_geometry.gd
     365 game/presentation/graphics_presets.gd
     494 game/app/presentation_rig.gd
     507 game/services/settings_service.gd
      31 game/world/hotel/material_albedo.gd
     344 tools/textures/ingest_pbr.py
     210 tools/textures/bake_lite_maps.gd
     128 tools/textures/check_ingest_pbr.py
     189 tools/textures/ingest_dressing.py
     134 tools/textures/bake_blood.py
      83 tools/textures/bake_do_not_disturb.py
     198 tools/textures/bake_hotel_note.py
     272 tools/textures/make_exit_sign.py
      67 tools/textures/make_icon.py
      30 assets/textures/README.md
     529 docs/ASSETS.md
      74 project.godot
   13320 total
```
