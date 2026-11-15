# Ficha de hechos: sombreadores (shaders)

Fecha de lectura: 14 de noviembre de 2026. Repo `E:/Projects/The Four`, rama `main`.
Alcance: los 34 archivos que git rastrea con extensión `.gdshader` (30) o `.gdshaderinc` (4), leídos enteros con `cat -n`. Además, los consumidores (GDScript, escenas `.tscn`, materiales `.tres`, pruebas, herramientas) leídos por línea con grep y, donde hacía falta, por tramos.
Solo lectura. No se ejecutó Godot ni Unreal, no se compiló nada, no se tocó git.

Convenciones: rutas relativas a la raíz del repo. `archivo:línea` usa la línea del propio archivo. "GD" = GDScript.

---

## 0. Resumen

- 34 archivos: 30 `.gdshader` y 4 `.gdshaderinc` (`surface`, `image_maps`, `lens_blood`, `wood`).
- Tipo de los 30 `.gdshader`: **spatial 23, canvas_item 6, fog 1**.
  - canvas_item de juego: `analog`, `lens`, `typewriter_ink`, `signal_wash`, `tape_noise`. Herramienta: `tools/dev/lens_blood_look.gdshader`.
  - fog: `ceiling_dust_veil.gdshader` (único shader de niebla volumétrica).
- Todos se usan desde el juego salvo `tools/dev/lens_blood_look.gdshader` (solo herramienta) y los `.gdshaderinc`, que se incluyen con `#include`.
- **Posprocesado de pantalla completa:** `analog.gdshader` (SCREEN_TEXTURE, ColorRect en CanvasLayer 5) y `lens.gdshader` (SCREEN_TEXTURE, CanvasLayer 2). Además `echo_field.gdshader` es un cuadrilátero de pantalla en 3D que lee DEPTH_TEXTURE.
- **Interfaz 2D:** `signal_wash`, `tape_noise`, `typewriter_ink`.
- **Compute GLSL embebido** (no es `.gdshader`): 10 bloques de texto en `game/presentation/camera/camcorder_effect.gd` (8) y `motion_blur_effect.gd` (2), ejecutados como CompositorEffect con RenderingDevice. Ver §5.
- Los cuatro puntos más difíciles de llevar a otro motor están en §1.2.

### 0.1 Funciones propias de Godot (lo que no tiene equivalente directo)

- **`hint_depth_texture` / DEPTH_TEXTURE** (echo_field, echo_points, ceiling_dust, lurker_darkness) junto con **`CURRENT_RENDERER == RENDERER_COMPATIBILITY`** (echo_field.gdshader:67, 89, 111; echo_points.gdshader:116; lurker_darkness.gdshader:109). El buffer de profundidad cambia de convención: Forward+ usa Z invertido (0 = lejano), Compatibility usa 1 = lejano (comentario en echo_field.gdshader:63-66).
- **`hint_screen_texture` / SCREEN_TEXTURE / SCREEN_PIXEL_SIZE / FRAGCOORD** en canvas_item (analog.gdshader:5, lens.gdshader:9).
- **`shader_type fog`** con SDF, SIZE, WORLD_POSITION (ceiling_dust_veil.gdshader:14-20), unido a `FogVolume` (GD: ceiling_dust.gd:181-200).
- **`void light()`** propia que ignora N·L (ceiling_dust.gdshader:105-107), con `ATTENUATION`, `LIGHT_COLOR`, `diffuse_lambert`.
- **Built-ins de capa**: `CLEARCOAT` y `CLEARCOAT_ROUGHNESS` (wood.gdshaderinc:121-136), `RIM` y `RIM_TINT` (curtain.gdshader:24-25, finish.gdshader:79-80), `BACKLIGHT` (finish.gdshader:82), `NORMAL_MAP` y `NORMAL_MAP_DEPTH` (blood.gdshader:60-61, blood_pool.gdshader:77-78), `CAMERA_POSITION_WORLD`, `TEXTURE` y `TEXTURE_PIXEL_SIZE` (canvas).
- **`world_vertex_coords`** (blood, blood_pool, blood_worn): VERTEX llega en coordenadas de mundo.
- **Reescritura de matrices y posición a mano**: `MODELVIEW_MATRIX` y `MODELVIEW_NORMAL_MATRIX` (ceiling_dust.gdshader:72-77), `POSITION` (echo_field.gdshader:53, echo_points.gdshader:100), `VERTEX` modificado (ceiling_dust.gdshader:85-86).
- **INSTANCE_CUSTOM / INSTANCE_ID** con `MultiMesh.use_custom_data` (blood.gdshader:28-31; echo_points.gdshader:66; ceiling_dust.gdshader:49; hotel_geometry.gd:601-606 para `room_data`).
- **`global uniform float surface_detail`** (surface.gdshaderinc:40). Se fija en `project.godot:64-69` (valor 4.0) y en ejecución en `game/app/presentation_rig.gd:285` y `tools/textures/bake_lite_maps.gd:111`.
- **`group_uniforms`**, **`#include "res://..."`** (rutas `res://` dentro de shaders), **`#define`** con `dFdx/dFdy` (surface.gdshaderinc:205), **`#ifdef LACQUER_COAT`** (wood.gdshaderinc:121).
- **Uniformes de arreglo**: `reach[16]` (blood_pool.gdshader:23), `wound_at[2]` vec3, `wound_frame[2]` mat3, `wound_age[2]` (blood_worn.gdshader:14-16), `roots_a[9]`, `roots_b[9]` vec3 y `roots_w[9]` float (lurker_darkness.gdshader:30-32). GDScript los rellena por frame.
- **Hints y filtros**: `hint_range`, `source_color`, `filter_linear_mipmap_anisotropic`, `filter_nearest`, `repeat_enable/disable`, `hint_normal`, `hint_default_white`, `hint_enum`, `group_uniforms`.
- **Macros de tangente**: `BUMPED_VIEW_NORMAL` (surface.gdshaderinc:205) con `bump_world` (194-201) que usa derivadas de pantalla.
- **Render modes concretos** (`depth_draw_never`, `depth_test_disabled`, `cull_front`, `blend_add`, `unshaded`, `shadows_disabled`, `diffuse_lambert`, `specular_disabled`, `depth_draw_opaque`, `world_vertex_coords`, `object_space` como uniform). Ver §2.

---

## 1. Tabla general (una fila por shader)

Leyenda: "DEPTH" = DEPTH_TEXTURE; "SCREEN" = SCREEN_TEXTURE; "sí (n)" = aparece TIME en esa línea; "—" = no aplica. Los valores por defecto van entre paréntesis en la columna de uniforms. Detalle de cada uniform, su función y su consumidor en §3.

| # | Ruta (líneas) | Tipo | render_mode | Uniforms principales (tipo, valor por defecto) | Texturas que muestrea | SCREEN / DEPTH | TIME | Vértice | discard / light() | Dónde se usa | Efecto visual (una frase) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | game/enemies/locust/shaders/echo_field.gdshader (126) | spatial | unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled | depth_map (sampler, hint_depth), now (float 0), shriek (0..1, 0), presence (0..0.05, 0.006), grain_amount (1), jitter_amount (1), beam_origin (vec4 0), beam_axis (vec4 0,0,-1,0.9), beam_range (20) | depth_map | DEPTH sí / SCREEN no | no (usa now) | POSITION fija a pantalla (l.53) | no | echo_view.gd:24 (FIELD_SHADER); field_material | Fondo negro de la lectura del eco, con grano y el temblor del haz de una antorcha; no dibuja formas. |
| 2 | game/enemies/locust/shaders/echo_points.gdshader (135) | spatial | unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled | now, wave_speed (42), age_limit (5), point_scale (0.004), point_min (0.010), point_max (0.085), through (0..1, 0.35), steady (0..1, 0), steady_fade_from (12), steady_fade_to (20), shriek (0..1, 0), gain (0..4, 1), tone_cold / tone_hot / shriek_cold / shriek_hot (vec3 source_color), residue (0..2, 0.11), flare (0..4, 1.8), twinkle (0..1, 0), halo (0..1, 0), depth_map | depth_map | DEPTH sí / SCREEN no | no (usa now) | billboard: POSITION = PROJECTION * (centro + VERTEX.xy * radio) (l.100) | no | echo_view.gd:25 (POINT_SHADER) y varios ShaderMaterial de echo_view | Granos de luz que aparecen con el frente del eco y se apagan despacio; frío o cálido, rojo con el chillido. |
| 3 | game/enemies/locust/shaders/echo_self.gdshader (25) | spatial | unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled (sin depth_test_disabled) | now, shriek (0..1, 0), gain (0..2, 1), slice_step (0.16) | ninguna | no / no | no (usa now) | ninguno | no | echo_view.gd:26 (SELF_SHADER); self_material | Contorno fantasmal del propio cuerpo: borde y franjas horizontales. |
| 4 | game/enemies/lurker/ceiling_dust.gdshader (107) | spatial | blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled | shape (sampler source_color), billboard (bool true), axial (bool false), scatter (1), min_pixels (2.5), twinkle (0), wrap (0), drift (0.03), speck (vec2 0.003, 0.008), bokeh (0), focus (1.2), depth_map | shape (UV), depth_map | DEPTH sí / SCREEN no | sí (58-59, 95) | MODELVIEW_MATRIX reescrita (72-77), VERTEX.xy * grow (85-86), desplazamiento por wrap (59-63) | `light()` propia: DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * scatter / PI (l.106) | ceiling_dust.gd:18 (SHADER); office_geometry.gd:1334-1344 (motas en MultiMesh) | Motas de polvo y hilos que brillan al cruzar un haz o un tubo y son negros fuera de él. |
| 5 | game/enemies/lurker/ceiling_dust_veil.gdshader (21) | fog | (sin render_mode) | noise_tex (sampler3D repeat_enable), density (0), albedo (vec3 1), eye (vec3 0,-1000,0) | noise_tex (WORLD_POSITION) | no / no | sí (15) | no | no (escribe DENSITY) | ceiling_dust.gd:21 (ruta en texto, cargada al crear un velo), 166-200 (NoiseTexture3D, FogVolume) | Velo de polvo en niebla volumétrica bajo un desprendimiento; se borra a menos de un metro del ojo. |
| 6 | game/enemies/lurker/lurker_darkness.gdshader (138) | spatial | unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled | axis_a, axis_b (vec3), face (vec3), face_clear (0.17), radius (0.8), thickness (0.34), density (40), vapour (0..1, 0), roots_a[9], roots_b[9] (vec3), roots_w[9] (float), spill (0), FILM (const 0.1), depth_texture | depth_texture (sin muestreo de ruido: el ruido es procedural) | DEPTH sí / SCREEN no | sí (120, 127, 133) | solo world_vertex (l.92) | discard (l.103, 122) | lurker_visual.gd:12 (DARKNESS), 215-231 (fog(): ShaderMaterial y parámetros), 356-363 (por frame), 164 (spill) | Tinta o vapor negro que envuelve al Lurker: masa densa con bordes rasgados y volutas. |
| 7 | game/intro/tv_screen.gdshader (101) | spatial | unshaded, cull_back | screen_rect (vec4), power (1), static_amount (1), image (sampler source_color), image_amount (0), cracks (sampler), crack_level (0), flash (0), roll (0), unstable (0), flicker (0), brightness (1), open (0..1, 1), tint_blue (0) | image, cracks | no / no | sí (48) | no | no | intro_sequence.gd:576-580; hotel_television.gd:18 (CRT) y 78-84, 151-152 | Tubo CRT: estática, líneas de barrido, rejilla de fósforo, grietas y apertura de encendido. |
| 8 | game/presentation/materials/office/ceiling_halo.gdshader (19) | spatial | blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled | glow (vec3 source, 1), energy (0), inner (vec2 0.6, 0.3), reach (1.2) | ninguna | no / no | no | ninguno | no | office_geometry.gd:257 (HALO_SHADER), 587-591, 2347, 2472 | Halo de luz en el techo alrededor de cada fluorescente. |
| 9 | game/presentation/materials/office/ceiling_tile.gdshader (60) | spatial | (por defecto) | base_color, yellow_color, stain_color (vec4 source), tile (0.6), yellowed (0.3), ringed (0.12), cracked (0.05) + include surface e image_maps | albedo_map, normal_map, orm_map, lite_map (solo si hay escaneo o lite) | no / no | no | SURFACE_VERTEX | no | presentation/materials/office/ceiling_service.tres:3; tests/office/office_finishes_test.gd:116 | Placa acústica de oficina, amarillenta, con anillos de agua y grietas. |
| 10 | game/presentation/shaders/analog.gdshader (286) | canvas_item | (por defecto) | screen_texture (hint_screen_texture), vhs (0.18), grain (0.12), chromatic (0.08), scanlines (0.35), tint (vec3 1.02, 1.0, 0.9), vignette (0.45), enclosure (0), signal_loss (0), tape_hit (0), tape_band (-1), tape_fray (0), rewinding (0), lens_blood / lens_seed / lens_down (del include), marked (bool false), marks (sampler), chroma_taps (int 7, rango 2..7), lite (bool false) | screen_texture, marks | SCREEN sí / DEPTH no | sí (93) | no | no | presentation.tscn:4-9 y 27-31 (ColorRect "Analog/Screen", CanvasLayer 5) | Filtro de cinta VHS y cámara de consumo sobre toda la imagen: ruido, bandas, color y estática. |
| 11 | game/presentation/shaders/blood.gdshader (62) | spatial | blend_mix, depth_draw_never, cull_back, shadows_disabled, world_vertex_coords | atlas (sampler filter_linear_mipmap), clock (1000), film_color (vec3 source), deep_color (vec3 source) | atlas (assets/decals/blood_atlas.png) | no / no | no (usa clock) | VERTEX += normal hacia el ojo (l.35-36) | discard (l.41, 50) | blood.gd:28 (STAIN), 317-356, 452 | Manchas de sangre sobre superficies, gotas y regueros: mate en moqueta, brillante en suelo duro. |
| 12 | game/presentation/shaders/blood_pool.gdshader (87) | spatial | igual que blood | age (1000), span (1.5), radius (0.42), spread_time (30), reach[16] (float), soak (0), seed (0), film_color, deep_color | ninguna | no / no | no (usa age) | VERTEX += hacia el ojo (l.30-31) | discard (l.62, 67) | blood.gd:29 (POOL), 392-398, 452-453, 537 | Charco que se extiende con la raíz cúbica del tiempo, con borde de gota, frenado por las paredes. |
| 13 | game/presentation/shaders/blood_worn.gdshader (60) | spatial | blend_mix, depth_draw_never, cull_back, shadows_disabled, world_vertex_coords | wound_at[2] (vec3), wound_frame[2] (mat3), wound_age[2] (float), reach (0.17), spread_time (3.5), film_color, deep_color | ninguna | no / no | no | VERTEX += hacia el ojo 0.0015 (l.28-29) | discard (l.55) | avatar_visual.gd:386 (WORN_BLOOD), 397 (stain.shader), 419-421 | Sangre que sale de las heridas y corre por la ropa y la piel. |
| 14 | game/presentation/shaders/carpet.gdshader (82) | spatial | (por defecto) | base_color, field_color, line_color, accent_color (vec4 source), tile_size (0.62), pattern (1), wear (0.6), fibre_bleed (0.035) + includes | albedo/normal/orm y lite (si hay escaneo) | no / no | no | SURFACE_VERTEX | no | presentation/materials/carpet.tres:3; office/carpet.tres:3; office/carpet_exec.tres:3; office/mat_rib.tres:3 | Moqueta del hotel con medallones octogonales, pelo y desgaste. |
| 15 | game/presentation/shaders/ceiling.gdshader (34) | spatial | (por defecto) | base_color (vec4 source), stain_color (vec4 source), stains (0.6) + includes | albedo/normal/orm y lite | no / no | no | SURFACE_VERTEX | no | presentation/materials/ceiling.tres:3; ceiling_service.tres:3; tests/office/office_finishes_test.gd:114 | Techo de gotelé amarillento por el humo, con manchas de humedad. |
| 16 | game/presentation/shaders/curtain.gdshader (27) | spatial | (por defecto) | motion (1), color (vec4 source), fold_color (vec4 source) + surface | ninguna | no / no | sí (11) | VERTEX.z += sin(TIME*0.7 + VERTEX.x*8) * 0.035 * motion * (1 - UV.y) (l.11) | no | presentation/materials/curtain.tres:3; hotel_geometry.gd:3011 (motion) | Cortina de terciopelo con pliegues que se mece. |
| 17 | game/presentation/shaders/exit_panel.gdshader (67) | spatial | blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled | engraving, engraving_back (sampler), two_faced (bool false), glow (vec3 source), core (vec3 source), energy (5), diodes (int 5), sheet (0.09), sheen (0.45), level (1) | engraving, engraving_back | no / no | no | no | no | hotel_geometry.gd:1857-1886; tools/textures/make_exit_sign.py | Letrero de salida de acrílico: diodos en el borde, letra que dispersa la luz. |
| 18 | game/presentation/shaders/finish.gdshader (85) | spatial | (por defecto) | albedo, variation_color (vec4 source), roughness (0.7), metallic (0), specular (0.5), finish (enum 0..4, 0), detail_scale (1), relief (1), sheen (0), grime (0.35), backlight (0), map_rough_keep (1), brush_across (bool false) + includes | albedo/normal/orm y lite | no / no | no | SURFACE_VERTEX | no | 37 .tres (materials/*.tres y materials/office/*.tres); office_finishes_test.gd:80-106 | Acabado de mobiliario: metal cepillado, tela tejida, lino arrugado, hoja, con suciedad. |
| 19 | game/presentation/shaders/lens.gdshader (92) | canvas_item | (por defecto) | screen_texture (hint_screen_texture), barrel (0.05), scale (0.8), chromatic (0.3), vignette (0.45), noise (0.35), gain_map (sampler, 1x1 de exposición), field_shift (vec2 0), detail (0.35) | screen_texture, gain_map | SCREEN sí / DEPTH no | sí (81) | no | no | presentation.tscn:6, 12, 17-20 (CanvasLayer 2); presentation_rig.gd:85, 131, 143-146, 177-178 | Óptica y sensor de la videocámara: barril, color en los bordes, viñeteado, ruido, campos entrelazados. |
| 20 | game/presentation/shaders/painting.gdshader (30) | spatial | (por defecto) | sky, land, accent, varnish (vec4 source) + surface | ninguna | no / no | no | SURFACE_VERTEX | no | presentation/materials/painting.tres:3 | Cuadro de paisaje desvaído bajo barniz, generado por posición. |
| 21 | game/presentation/shaders/tile.gdshader (89) | spatial | (por defecto) | tile_color, alternate_color, grout_color (vec4 source), tile_size (0.3), grout_width (0.0035), checker (0.35), grime (0.6), tile_count (8), specular_level (0.42), marble (0), wear (0), tilt_always (bool false), tilt (0.045) + includes | albedo/normal/orm | no / no | no | SURFACE_VERTEX | no | presentation/materials/tile.tres:3; office/quarry, vinyl, vinyl_hall, vinyl_polished, wet_band, wet_tile (.tres) | Baldosa vidriada o vinilo con junta, suciedad y grietas. |
| 22 | game/presentation/shaders/typewriter_ink.gdshader (32) | canvas_item | (por defecto) | grain (0.5) | ninguna | no / no | no | local = VERTEX (l.23) | no (escribe COLOR.a) | game/ui/hotel_form.gd:22; game/ui/ruled_paper.gd:10 | Tinta de cinta de máquina de escribir: irregular, con grano del tejido. |
| 23 | game/presentation/shaders/venetian_blind.gdshader (17) | spatial | cull_disabled | pitch (0.022), open (0.3), drop (1), height (1.7), color (vec4 source) | ninguna | no / no | no | ninguno | discard (l.13-14) | office_geometry.gd:87 (BLIND), 1613-1621 | Persiana veneciana: lamas simuladas por descarte sobre un solo quad. |
| 24 | game/presentation/shaders/wallpaper.gdshader (84) | spatial | (por defecto) | paper_color, print_color, stain_color, edge_color (vec4 source), roll_width (0.53), motif_height (0.46), print_strength (0.55), stains (0.55), grime (0.5), ink_bleed (0.03) + includes | albedo/normal/orm y lite | no / no | no | SURFACE_VERTEX | no | office/office_paint.tres, office_paint_kept.tres, partition.tres, reception_low.tres, taupe.tres; hotel: plaster.tres, plaster_decrepit.tres | Papel pintado envejecido: rollos, motivo, manchas de agua y suciedad. |
| 25 | game/presentation/shaders/wired_glass.gdshader (30) | spatial | blend_mix, cull_disabled, depth_draw_opaque, specular_disabled | glass_color (vec4 source, alfa 0.16), wire_color (vec4 source, alfa 0.75), pitch (0.025), wire (0.06) | ninguna | no / no | no | world = MODEL_MATRIX * VERTEX (l.18) | no | office_geometry.gd:88 (WIRED_GLASS), 267-274; office_finishes_test.gd:80 | Vidrio armado: malla de alambre sobre cristal verdoso. |
| 26 | game/presentation/shaders/wood.gdshader (4) + wood.gdshaderinc (142) | spatial | (por defecto) | light_color, dark_color (vec4 source), ring_density (22), varnish (0.65), lacquer_edge (0.04..1, 0.06), scuffs (0.5), panel_spacing (0), door_panels (bool false), object_space (bool false) | albedo/normal/orm | no / no | no | SURFACE_VERTEX, o espacio objeto si object_space | no | 11 .tres (door, panel, trim, wood, office/car_oak, dado_oak, oak_door, reception_teak, veneer, walnut, walnut_object); hotel_geometry.gd:2712 (WOOD) | Madera lacada del hotel: anillos, poros, paneles y arañazos. |
| 27 | game/presentation/shaders/wood_lacquer.gdshader (5) | spatial | (por defecto) | igual que wood, con `#define LACQUER_COAT` | igual | no / no | no | igual | no | hotel_geometry.gd:2713-2718 (WOOD_LACQUER, cambio según surface_detail > 4.5 en l.2594) | Igual que wood, con el barniz como capa propia (CLEARCOAT). |
| 28 | game/ui/shaders/signal_wash.gdshader (51) | canvas_item | (por defecto) | wash (0..1, 0) | TEXTURE (la del nodo) | no / no | sí (21, 24, 29) | no | no | game/ui/hotel_ui.gd:2059, 2134-2139; game/ui/rules_screen.gd:17, 98, 113-114 | Aviso que pierde señal: las líneas ondulan, la imagen se arrastra y entra la nieve. |
| 29 | game/ui/shaders/tape_noise.gdshader (20) | canvas_item | (por defecto) | amount (0..1, 0), tint (vec4 source) | ninguna | no / no | sí (14) | no | no | game/intro/intro_sequence.gd:22, 120, 241; game/ui/hotel_ui.gd:6, 428, 2210, 2333 | Estática de cinta para transiciones de menú y pérdida de señal. |
| 30 | tools/dev/lens_blood_look.gdshader (11) | canvas_item | (por defecto) | ground (vec3 0.92, 0.92, 0.9), wide (1.7778) | ninguna | no / no | no | no | no | tools/dev/lens_blood_look.gd:24 | Solo herramienta: dibuja las gotas sobre fondo neutro. Fuera del juego. |
| 31 | game/presentation/shaders/surface.gdshaderinc (205) | include | — | surface_detail (global), flat_color, use_lite, lite_map, lite_metres; varyings wp, wn, room_data | lite_map | — | — | macros SURFACE_VERTEX (l.16), BUMPED_VIEW_NORMAL (l.205) | — | 11 shaders la usan: 9 directamente y 2 por wood.gdshaderinc (ver §4) | Funciones comunes: ruido, cara de la superficie, borde de habitación, suciedad, niveles de detalle. |
| 32 | game/presentation/shaders/image_maps.gdshaderinc (112) | include | — | use_maps, albedo_map, normal_map, orm_map, map_mode (1), map_tint, map_detail (1), normal_strength (1), map_roughness (0), map_metallic (1), map_metres (1), map_no_tile (false) | albedo_map, normal_map, orm_map | — | — | — | — | 7 shaders la incluyen directamente (ceiling_tile, carpet, ceiling, finish, tile, wallpaper, wood.gdshaderinc) y 9 contando wood y wood_lacquer; hotel_geometry.gd:452-470 | Escaneos fotográficos (albedo, normal, orm) que sustituyen al procedimiento. |
| 33 | game/presentation/shaders/lens_blood.gdshaderinc (196) | include | — | lens_blood (0), lens_seed (0), lens_down (vec2 0, 1) | ninguna | — | — | — | — | analog.gdshader:35; tools/dev/lens_blood_look.gdshader:4 | Gotas de sangre sobre el cristal de la cámara. |
| 34 | game/presentation/shaders/wood.gdshaderinc (142) | include | — | ver fila 26 | ver fila 26 | — | — | ver fila 26 | — | wood.gdshader:4; wood_lacquer.gdshader:5 | Cuerpo de la madera, compartido por wood y wood_lacquer. |

---

## 1.2 Lo que más cuesta llevar a otro motor (hechos del código)

1. **Profundidad y reconstrucción de posición**: echo_field, echo_points, ceiling_dust y lurker_darkness leen DEPTH_TEXTURE y reconstruyen la posición con `INV_PROJECTION_MATRIX`. El código bifurca por renderer (ver §0.1). `echo_field.gdshader:20-21` advierte que el muestreo de profundidad debe ser `filter_nearest`.
2. **Pantalla completa con SCREEN_TEXTURE y dos capas de cámara**: analog y lens leen la imagen ya renderada (tonemapping incluido). El orden es 3D, luego lens (CanvasLayer 2), OSD (CanvasLayer 3) y analog (CanvasLayer 5) (`presentation.tscn:17-38`; `lens.gdshader:2-8` describe el orden físico).
3. **Compute en RenderingDevice**: la cadena de HDR (medidor, iris, smear, glare, grade) es GLSL 450 embebido en GD, compilado en ejecución (`camcorder_effect.gd:352-366`). No es un `.gdshader`. Ver §5.
4. **Estado por instancia en MultiMesh**: blood y ceiling_dust leen INSTANCE_CUSTOM y COLOR por instancia. En Unreal sería un atributo por instancia de un Instanced Static Mesh o un material con parámetro por instancia.
5. **Matrices de instancia reescritas en vertex**: ceiling_dust hace billboard y eje de estela a mano (ceiling_dust.gdshader:67-78). echo_points arma un billboard de pantalla (l.89-100).
6. **Niebla volumétrica con shader propio**: ceiling_dust_veil es `shader_type fog`, dependiente de Forward+ (ceiling_dust.gd:146 solo crea velos si `volumetric_fog_enabled`; check_shaders.gd:45 salta los shaders fog en Compatibility).
7. **Coordenadas por mundo, no por UV**: casi todas las superficies calculan UV desde `wp` (mundo) y `wn` (normal) con `face_uv()` (surface.gdshaderinc:70-75). Las cajas no tienen UV significativos (comentario surface.gdshaderinc:1-3).
8. **Nivel de detalle por preset**: `surface_detail` cambia el número de octavas de `fbm` (surface.gdshaderinc:42-58), apaga los finos (`fine_noise`, l.63-66), activa el lacquer (`finest_surface`, l.157) y decide si la superficie se "hornea" en una textura (`baked_surface`, l.182).

---

## 2. Render modes y estado de mezcla (resumen para el port)

| Shader | blend | depth | cull | luz | otros |
|---|---|---|---|---|---|
| echo_field | blend_mix | depth_draw_never, depth_test_disabled | disabled | unshaded | fog_disabled |
| echo_points | blend_add | depth_draw_never, depth_test_disabled | disabled | unshaded | fog_disabled |
| echo_self | blend_add | depth_draw_never | disabled | unshaded | fog_disabled (prueba de profundidad normal) |
| ceiling_dust | blend_mix | depth_draw_never | disabled | diffuse_lambert, specular_disabled | light() propia |
| lurker_darkness | blend_mix | depth_draw_never, depth_test_disabled | front | unshaded | shadows_disabled |
| tv_screen | opaco | — | back | unshaded | — |
| ceiling_halo | blend_add | depth_draw_never | disabled | unshaded | shadows_disabled, fog_disabled |
| blood / blood_pool / blood_worn | blend_mix | depth_draw_never | back | iluminado | shadows_disabled, world_vertex_coords |
| exit_panel | blend_mix | depth_draw_never | disabled | unshaded | shadows_disabled |
| venetian_blind | opaco | — | disabled | iluminado | discard |
| wired_glass | blend_mix | depth_draw_opaque | disabled | iluminado | specular_disabled |
| canvas (analog, lens, signal_wash, tape_noise, typewriter_ink) | blend por defecto del canvas | — | — | — | SCREEN o TEXTURE |

Los shaders sin render_mode (carpet, ceiling, curtain, painting, tile, wallpaper, finish, ceiling_tile, wood) usan los valores por defecto de Godot: opaco, con luz, sombra y culling normal.

---

## 3. Detalle por sombreador

Formato: propósito; uniforms con tipo, valor por defecto y uso; flujo vertex/fragment con líneas; consumidores; dependencias en tiempo de ejecución.

### 3.1 echo_field.gdshader (126 líneas)
- **Propósito**: el fondo negro sobre el que se leen los granos del eco. Ya no dibuja geometría (comentario l.2-17). Dos cosas que no son geometría: el grano del propio oído (`speck`, l.120-122) y la interferencia de una antorcha encendida (`beam`, l.84-118).
- **Uniforms**: `depth_map` sampler2D `hint_depth_texture, repeat_disable, filter_nearest` (l.22). `now` float 0 (l.24, reloj del eco que escribe GD). `shriek` 0..1 (l.26): 0 gris, 1 rojo. `presence` 0..0.05 = 0.006 (l.30): el único término que aún describe forma (comentario l.27-29). `grain_amount` (l.31), `jitter_amount` (l.32), ambos 0..1 = 1. `beam_origin` vec4 (l.39): posición de la antorcha (xyz) y fuerza (w). `beam_axis` vec4 (l.40): dirección (xyz) y coseno del semiángulo (w). `beam_range` float 20 (l.41). `const BEAM_STEPS = 24` (l.42).
- **Vértice**: `POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0)` (l.53). Malla QuadMesh 1×1 que no debe redimensionarse (l.51-52).
- **Fragmento**: desplazamiento horizontal de tape con `hash12` por línea y frame (l.59, constante 0.0016 y 240 líneas). Lectura de profundidad (l.60). Bifurcación por renderer (l.63-73). Color del muro `mix(vec3(0.74,0.79,0.82), vec3(1.35,0.05,0.02), shriek) * presence / (1 + d*0.35)` (l.80-81). Haz: marcha de 24 pasos a lo largo de cada rayo hasta el primer muro (l.88-118), `smoothstep(beam_axis.w, mix(w, 1, 0.7), cos)` (l.107), brillo `0.03` (l.110), gamma `0.4545` solo en Compatibility (l.115). Grano final `(speck - 0.5) * 0.010 * grain_amount` (l.121-122). `ALBEDO = max(colour, 0)`, `ALPHA = 1.0` (l.124-125).
- **Consumidor**: echo_view.gd:24 (FIELD_SHADER). `field_material` recibe `presence` (echo_view.gd:669), `grain_amount` y `jitter_amount` (677-678, en reducido a 0), `beam_*` (1138-1147; `beam_origin` a cero si no hay antorcha).
- **Dependencias**: `now` es el reloj propio del eco, no TIME (echo_view.gd:185-187, avanza en `advance()`, l.712-717). Los granos del mismo eco comparten ese reloj.

### 3.2 echo_points.gdshader (135 líneas)
- **Propósito**: una nube de granos en el mundo. Cada clic dispara rayos desde la cabeza y cada impacto deja un punto en un buffer en anillo; la forma de la sala queda registrada donde está (comentario l.2-6).
- **Un shader, cinco nubes**: arquitectura, cuerpo, ruido guardado, lo que el chillido encuentra, marcas conocidas (comentario l.8-12).
- **Uniforms** (todos con su default): `now` (0), `wave_speed` (42, l.19; el eco de GD lo fija en `WAVE_SPEED = 16.0`, echo_view.gd:48, y en `PUFF_SPEED = 4.5`, echo_view.gd:70), `age_limit` (5, l.22; GD lo fija cada frame en echo_view.gd:986-990), `point_scale` (0.004, l.25), `point_min` (0.010, l.26), `point_max` (0.085, l.27), `through` (0..1, 0.35, l.30: cuánto del eco pasa un muro; un cuerpo tiene 0), `steady` (0..1, 0, l.32; 1 para marcas fijas), `steady_fade_from` (12), `steady_fade_to` (20) (l.33-34), `shriek` (l.35), `gain` (0..4, 1, l.36), `tone_cold`, `tone_hot`, `shriek_cold`, `shriek_hot` (vec3 source_color, l.38-41), `residue` (0..2, 0.11, l.44), `flare` (0..4, 1.8, l.45), `twinkle` (0..1, 0, l.49; GD usa 0.7 para las bocanadas, echo_view.gd:93), `halo` (0..1, 0, l.53; el preset Ultra lo pone a 1.0, graphics_presets.gd:222), `depth_map` (l.54).
- **Varyings planos** (l.61-63): `echo` (vec4), `strength`, `from_eye`. `echo` = INSTANCE_CUSTOM: x = instante del clic, y = metros desde el origen del clic, z = tipo (0 arquitectura, 1 carne) más 2 por cada décima de vida propia, w = cuánto volvió (l.57-60).
- **Vértice**: `flash = exp(-gap²/2.5)` (l.71), `since`, `life` (l.72-75, `tenths > 0.5 ? tenths*0.1 : age_limit`), `memory` (l.75), `live = (residue + flare * flash) * memory * echo.w` (l.81). Parpadeo por instancia con `fract(sin(id*12.9898 + floor(now*12)*78.233)*43758.5453)` (l.82-85). Billboard: `centre = (VIEW_MATRIX * MODEL_MATRIX * (0,0,0,1)).xyz` (l.89), `from_eye = length(centre)` (l.92), `strength` con `mix(live, echo.w * faded, steady) * gain` (l.94), `radius = clamp(from_eye * point_scale, point_min, point_max) * (1 + flash*0.8*(1-steady))` (l.95). Si `strength <= 0.002` el radio es cero (l.98). `radius *= 1 + halo*2` (l.99). `POSITION` (l.100).
- **Fragmento**: disco `smoothstep(1.0, 0.15, r)` (l.106) y halo `exp(-r²*0.35)*halo*0.3` (l.107). Prueba de profundidad hecha a mano si `through < 0.999` (l.109-128): `weight *= mix(1, through, smoothstep(0.15, 0.9, from_eye - wall))` (l.126). Tono por `pick = echo.z - 2*floor(echo.z*0.5 + 0.001)` (l.130), `mix(tone_cold, tone_hot, pick)` (l.131) y el chillido (l.132). `ALBEDO = tone`, `ALPHA = clamp(disc * weight, 0, 1)` (l.133-134).
- **Consumidor**: echo_view.gd:25. Varios ShaderMaterial: `mote_material` (420-426), `guide_material` (431-439, `age_limit = 60` en l.435, rutas azules y amarillas), `frame_material` (443-446), `puff_material` (450-459, bocanadas de sonido con `twinkle` 0.7), `find_material` (460-461, hallazgos con chillido rojo), `body_material` (464-465, cuerpos), `mark_material` (466-468, marcas con `steady = 1`), `wall_material` (675-676, 681, 986: `age_limit = span`), `field_material` (no aquí, ver 3.1). Varios se reescalan por frame con `point_scale`, `point_min`, `point_max`, `halo` (695-707).
- **Compatibilidad**: `lift()` multiplica `gain` por 1.6 en Compatibility (echo_view.gd:362-364). El comentario explica que el tonemap por grano se come los granos tenues (echo_view.gd:26-28).

### 3.3 echo_self.gdshader (25 líneas)
- **Propósito**: su propio cuerpo, lo único que conoce sin escuchar (l.2-7). Es aditivo y no escribe profundidad: el campo reconstruye el muro detrás y los brazos quedan como fantasma de rayos X.
- **Uniforms**: `now` (l.10), `shriek` (l.11), `gain` (0..2, 1, l.12), `slice_step` (0.16, l.15).
- **Fragmento**: `rim = pow(1 - |dot(normalize(NORMAL), normalize(-VERTEX))|, 2)` (l.19; NORMAL y VERTEX ya están en espacio de vista). `height = (INV_VIEW_MATRIX * VERTEX).y` (l.20). `slices = pow(1 - |fract((height + now*0.05)/slice_step) - 0.5|*2, 6)` (l.21). `level = (rim*0.85 + slices*0.22 + 0.035) * gain` (l.22). `ALBEDO` mezcla `(0.82, 0.86, 0.9)` con rojo `(1.3, 0.10, 0.06)` (l.23). `ALPHA = clamp(level)` (l.24).
- **Consumidor**: echo_view.gd:26 (SELF_SHADER), `self_material.gain = 0.08 * lift()²` (l.333).
- **Orden**: el comentario (l.2-3) dice que se dibuja sobre el campo y las nubes; depende del orden de dibujo de Godot (sin ningún control explícito en el shader).

### 3.4 ceiling_dust.gdshader (107 líneas)
- **Propósito**: el polvo en el aire se ve porque dispersa luz desde todos lados, no porque una cara mire a la lámpara (l.1-2). `light()` suma lo que llega, con sombra, sin N·L (l.105-107). Tres modos: cara a la cámara (`billboard`), franjas que siguen su velocidad (`axial`), o polvo colgado en MultiMesh con `wrap` (l.8-16).
- **Uniforms**: `shape` (sampler2D source_color, filter_linear_mipmap, l.20; textura de la mota), `billboard` (bool, true, l.21), `axial` (bool, false, l.22), `scatter` (1, l.24; cuánta luz envía al ojo), `min_pixels` (2.5, l.26; ancho mínimo en píxeles de una imagen de 720 líneas), `twinkle` (0, l.28), `wrap` (0, l.29; lado de la caja de polvo alrededor del ojo), `drift` (0.03 m/s, l.32), `speck` (vec2 0.003, 0.008 m, l.33), `bokeh` (0, l.37), `focus` (1.2 m, l.38), `depth_map` (l.39).
- **Varyings**: `thin` (grosor por tamaño), `spark` (fase de parpadeo) (l.41-42).
- **Vértice**: `centre = MODEL_MATRIX[3].xyz` (l.45). Modo `wrap > 0`: hash entero por `INSTANCE_ID` (l.49-56; constantes 1664525u, 22695477u, 2891336453u, 1013904223u, 0x7feb352d, 0x846ca68b), posición `seed*wrap + way*2*drift*TIME + sway` (l.58-59), escala `mix(speck.x, speck.y, fract(seed.x*13.7 + seed.y*5.3))` (l.60), envoltura alrededor del ojo `mod(centre - eye + wrap*0.5, wrap) - wrap*0.5` (l.61-63), borde `edge = 1 - smoothstep(0.7, 1.0, max(far))` (l.64-65). Modo `axial`: matriz con `along = MODEL_MATRIX[1]` y `side` (l.67-73). Modo `billboard` (l.74-77). Tamaño mínimo: `least = dist*2/PROJECTION_MATRIX[1][1] * max(min_pixels, bokeh*(1 - smoothstep(0.2, focus, dist))) / 720` (l.82), `grow = max(1, least/size)` (l.83), `VERTEX.x *= grow` (l.85), `VERTEX.y *= grow` si no es axial (l.86), `thin = inversesqrt(grow) * edge` (l.87), `spark = fract(sin(id*12.9898)*43758.5453)` (l.88).
- **Fragmento**: `tex = texture(shape, UV)` (l.92), `ALBEDO = COLOR.rgb` (l.93), `a = COLOR.a * tex.a * thin` (l.94), parpadeo `1 - twinkle*(0.5+0.5 sin(TIME*(6+spark*14) + spark*40))` (l.95). Suavizado contra superficies con `texture(depth_map, SCREEN_UV)` (l.97-100) y `clamp((VERTEX.z - behind.z)/0.06, 0, 1)` (l.100). Cerca del objetivo `smoothstep(0.12, 0.4, -VERTEX.z)` (l.101). `ALPHA = clamp(a, 0, 1)` (l.102).
- **Consumidor**: ceiling_dust.gd:18 (SHADER). Mismo shader para hilos, copos, migas y bocanadas: `shape`, `billboard` y el diccionario `look` se fijan en ceiling_dust.gd:359-361. Motas de oficina: office_geometry.gd:1329-1344 con MultiMesh, `set_instance_transform(identity)` y `set_instance_color(Color(DUST_COLOUR, rng.randf_range(...)))`. Las motas aparecen con `visible_instance_count` (office_geometry.gd:1366).
- **Dependencias**: `TIME` (l.58-59, 95) y el azar del MultiMesh (rng de office_geometry).

### 3.5 ceiling_dust_veil.gdshader (21 líneas, fog)
- **Propósito**: velo fino de polvo bajo un desprendimiento, dentro de la niebla volumétrica: mechones en cortinas, cayendo despacio, adelgazado en los bordes del volumen y a menos de un metro del ojo (l.1-6).
- **Uniforms**: `noise_tex` (sampler3D repeat_enable, filter_linear, l.9), `density` (0, l.10), `albedo` (vec3 1, l.11), `eye` (vec3 0,-1000,0, l.12; GD lo fija cada frame en ceiling_dust.gd:200).
- **fog()**: `p = WORLD_POSITION * (1.6, 0.5, 1.6) + (0, TIME*0.06, 0)` (l.15); `wisp = smoothstep(0.45, 0.85, texture(noise_tex, p).r)` (l.16); `edge = clamp(-SDF / (0.5*min(SIZE.x, SIZE.z)), 0, 1)` (l.17); `near = smoothstep(0.5, 1.4, distance(WORLD_POSITION, eye))` (l.18); `DENSITY = density * wisp * edge² * near` (l.19); `ALBEDO = albedo` (l.20).
- **Consumidores**: ceiling_dust.gd:21 (ruta en cadena, carga diferida), 166 (`NoiseTexture3D`), 174 (`noise_tex`), 175 (`density` 0), 180 (`albedo`), 181 (`FogVolume.new()`), 190 (tween de vida), 200 (`eye`). Constantes: `MAX_VEILS = 3` (l.43), `VEIL_DENSITY = 3.0` (l.45), `VEIL_SIZE = (1.4, 2.2, 1.4)` (l.46), `VEIL_LIFE = 9.0` (l.47), `VEIL_GLOW = 16.0` (l.51), `VEIL_TORCH = 0.35` (l.52).
- **Compatibilidad**: no existe en Compatibility (comentario ceiling_dust.gd:19 y check_shaders.gd:43-45).

### 3.6 lurker_darkness.gdshader (138 líneas)
- **Propósito**: la tinta o la vapor oscura del Lurker. No es una bola suave: es tinta en agua, con borde desgarrado donde es densa, y volutas. Se dibuja en las caras traseras de una esfera y se integra a lo largo de cada rayo (l.1-10). La cara queda libre (l.5-7).
- **Uniforms**: `axis_a`, `axis_b` (vec3, l.15-16; eje de la masa, desde el frente hasta el abdomen). `thickness` (0.34, l.18). `radius` (0.8, l.19; esfera donde se dibuja). `density` (40, l.20). `vapour` (0..1, 0, l.22; 0 tinta, 1 vapor). `face` (vec3, l.24). `face_clear` (0.17, l.25). `roots_a[9]`, `roots_b[9]` (vec3, l.30-31), `roots_w[9]` (float, l.32): hombros, cuello y cola, cada uno un segmento con su peso (0 = no hay). `spill` (0, l.37; extensión sobre la superficie). `const FILM = 0.1` (l.38). `depth_texture` (l.39).
- **Funciones**: `hash` (l.43-47), `noise` 3D de valor con suavizado (l.49-57), `segment` (l.59-63), `dark(p, t, eye, centre, widen)` (l.65-89).
  - `dark`: `stir` = ruido de dominio (l.67-70), `n = noise(p*6 + stir*2.4 + ...)*0.6 + noise(p*14 + stir*3.2 + ...)*0.4` (l.71-72), `r = segment/thickness` y mínimo sobre los 9 segmentos (l.73-76), `ink = smoothstep(1.0, 0.84, r + (n-0.5)*1.15)` (l.78), `wisps` (l.79), `rags = smoothstep(1.9, 1.15, r + (n-0.5)*0.9) * smoothstep(0.48, 0.56, n)` (l.83), `d = mix(max(ink, wisps*0.45), rags, vapour)` (l.84), `clear` (l.85), `inside = smoothstep(radius, radius*0.8, |p - centre|)` (l.87).
- **Vértice**: `world_vertex = MODEL_MATRIX * VERTEX` (l.92).
- **Fragmento**: rayo desde el ojo (l.96-98) e intersección con la esfera (l.99-106; `discard` si no corta, l.103). Profundidad de la escena (l.108-116). `t_scene`, `lies` si `spill > 0` (l.117), `bleed = 0.16 * noise(...)` (l.120), `t1 = min(t1, t_scene + bleed)` (l.121), `discard` si `t1 <= t0` (l.122). Integración de 10 pasos (l.124-134), `widen = spill * (1 + 0.07 sin(1.3 TIME) + 0.05 sin(2.3 TIME + 1.7))` (l.127). `ALBEDO = 0` y `ALPHA = clamp(1 - exp(-sum*density))` (l.136-137).
- **Consumidor**: lurker_visual.gd:12 (DARKNESS). Se crean dos nubes con `fog()` (función en l.215; llamadas en l.163 para «Ink» y l.189 para «Vapour»): `radius`, `thickness`, `density`, `vapour` (rags), `face_clear` se fijan en l.220-230. Por frame (l.356-363): `axis_a = front + drag*0.3`, `axis_b = back + drag`, `face = head`, `roots_a`, `roots_b`, `roots_w = ink_w o vapour_w`. Densidad de la vapor por `gloom` (l.363). `spill` = `SPILL = 1.7` (l.164, lurker_visual.gd:105).
- **Nota**: lurker_visual.gd:136-150 usa `tic_rng.randomize()` (azar sin semilla).

### 3.7 tv_screen.gdshader (101 líneas)
- **Propósito**: el tubo CRT de la apertura del juego y de los televisores del hotel (l.3-8). Recibe la imagen de un SubViewport (la habitación de la criatura).
- **Uniforms**: `screen_rect` (vec4, l.11; zona visible de la malla, 0.0128, 0.1364, 0.9745, 0.7213), `power` (1, l.12), `static_amount` (1, l.13), `image` (sampler2D source_color, l.14), `image_amount` (0, l.15), `cracks` (sampler2D, l.18; cuatro grietas por canal RGBA), `crack_level` (0, l.19; 0..4 golpes), `flash` (0, l.20), `roll` (0, l.22), `unstable` (0, l.23), `flicker` (0, l.25), `brightness` (1, l.26), `open` (0..1, 1, l.30; apertura con línea central), `tint_blue` (0, l.32; tono frío del televisor apagado).
- **Fragmento**: `uv = (UV - screen_rect.xy) / screen_rect.zw` (l.46). `field = floor(TIME*60)` (l.49). Grietas: `crack_at` (l.40-43) con diferencias de píxel (l.51-55), desplaza `uv` 0.012 (l.55). Roll y líneas (l.57-61; 240 líneas, tear con umbral `0.985 - unstable*0.06`, l.60). Misconvergence RGB ±0.0015 (l.63-66). Nieve: `snow = hash(floor(uv*(260,240)) + field*7)` (l.68), `streak` (l.69), `noise` (l.70). Barra de zumbido (l.75-76). Líneas entrelazadas 480 (l.77-78). Rejilla de apertura con 1100 franjas (l.80-82; `mix(1, grille*1.35, 0.45)`). Viñeta (l.84-85). Apertura: `opened`, `band`, `shown`, `line_glow` (l.88-93). Tinte (l.94), brillo (l.95). Grietas oscuras con destellos (l.97-99). `ALBEDO = colour` (l.100).
- **Consumidores**: intro_sequence.gd:576-580 (`screen.shader = load(...)`, parámetros `crack_level`, `image`, `cracks`, `image_amount`, `static_amount`, `unstable`, `flicker`, `flash`). Cada golpe: `crack_level` (l.228). `image_amount` (l.370). `static_amount` (l.372). `unstable` (l.373). `flicker` (l.379). `flash` (l.381). Tween de parámetros (l.424-426). hotel_television.gd:18 (`CRT`), 78-80 (`image_amount` 0, `tint_blue` 0.35, `brightness`), 84 (`material_override`), 151-152 (`open`, `brightness`).
- **Dependencias**: `TIME`; `intro_sequence.gd:99` siembra `rng` con 1987 y lo usa en `_process` (l.327-383) para temblores y parpadeos. Escritos también en `hotel_television.gd:140-144` con `flicker` y `opening` por delta.

### 3.8 ceiling_halo.gdshader (19 líneas)
- **Propósito**: el resplandor en el techo alrededor de un fluorescente. Se suma a lo que hay detrás, sin luz ni sombra (l.2-5).
- **Uniforms**: `glow` (vec3 source, 1, l.8), `energy` (0, l.9), `inner` (vec2 0.6, 0.3, l.10), `reach` (1.2, l.11).
- **Fragmento**: `outside = max(|UV| - inner, 0)` (l.14), `d = length(outside)` (l.15), `fall = 1 - smoothstep(0, reach, d)` (l.17), `ALBEDO = glow * energy * fall² * step(0.0001, d)` (l.18).
- **Consumidor**: office_geometry.gd:257 (HALO_SHADER), 587-591 (`glow`, `reach = HALO_REACH` (1.8, l.172), `energy = 0`), 2347 (`glow` por color de sala), 2472 (`energy = HALO_ENERGY * light_energy / base * far`; HALO_ENERGY = 0.22, l.174), 2463.

### 3.9 ceiling_tile.gdshader (60 líneas)
- **Propósito**: placas acústicas de oficina con variación por celda de 0.6 m (l.2-5): color cremoso amarillento, algunas más amarillas, un anillo de agua en algunas, una grieta en otras.
- **Include**: surface.gdshaderinc e image_maps.gdshaderinc (l.6-7).
- **Uniforms** (l.9-15): `base_color` (vec4 source, 0.70, 0.66, 0.55), `yellow_color` (0.66, 0.58, 0.40), `stain_color` (0.47, 0.39, 0.25), `tile` (0.6), `yellowed` (0.3), `ringed` (0.12), `cracked` (0.05).
- **Fragmento**: `cell = wp.xz / tile` (l.20). `laid = step(0.95, -wn.y)` (l.25; solo las placas colocadas en la rejilla siguen la celda). `yellow` (l.26). Rama `baked_surface()` (l.27-30): `baked_albedo(face_uv(), NODE_POSITION_WORLD, true)` y `ROUGHNESS = 0.95`. Rama procedural (l.31-58): `map_lookup(map_uv())` (l.34), `stipple` (l.35), `scan_albedo` (l.37), anillo de agua con radio deformado por `fbm` (l.38-46), grieta (l.48-50), borde oscuro (l.52-53), `ao = scan_occlusion(l)` (l.54), `room_grime` (l.55), `ROUGHNESS = scan_roughness(l, 0.95)` (l.57), `NORMAL = BUMPED_VIEW_NORMAL(scan_normal(l, wn), ...)` (l.58).
- **Consumidor**: presentation/materials/office/ceiling_service.tres:3. tests/office/office_finishes_test.gd:116 comprueba que la placa de oficina use este shader.

### 3.10 analog.gdshader (286 líneas)
- **Propósito**: cinta VHS y cámara de consumo para toda la imagen 3D, incluido lo que el juego escribe sobre la nieve (l.2-4, 36-43). Cada término escala con los controles del usuario, y las opciones reducidas los ponen a 0 (l.4).
- **Uniforms** (con línea):
  - `screen_texture` (sampler2D hint_screen_texture, filter_linear, l.5).
  - `vhs` (0..1, 0.18, l.6): grado de cinta. Multiplica desplazamientos, croma, dropouts y grano.
  - `grain` (0..1, 0.12, l.7), `chromatic` (0..1, 0.08, l.8), `scanlines` (0..1, 0.35, l.9).
  - `tint` (vec3, 1.02, 1.0, 0.9, l.11): gradación de cinta.
  - `vignette` (0..1, 0.45, l.12), `enclosure` (0..1, 0, l.14; dentro de un armario, bordes oscuros y leve bombeo).
  - `signal_loss` (0..1, 0, l.18): cámara que pierde la señal.
  - `tape_hit` (0..1, 0, l.25), `tape_band` (-1, l.26; altura de la banda del golpe), `tape_fray` (0..1, 0, l.29): golpe y desgaste.
  - `rewinding` (0..1, 0, l.32): cinta rebobinando.
  - `lens_blood`, `lens_seed`, `lens_down` (del include, lens_blood.gdshaderinc:24-30).
  - `marked` (bool false, l.44), `marks` (sampler2D filter_linear repeat_disable, l.45): textura de lo escrito sobre la nieve (hotel_ui.gd:2176, `marks_view`).
  - `chroma_taps` (int 7, rango 2..7, l.48; número de lecturas para el croma).
  - `lite` (bool false, l.52; lectura reducida a 3 muestras).
- **Funciones**: `hash` (l.54-58), `noise1` (l.60-64), `rgb_to_yiq` (l.66-68), `yiq_to_rgb` (l.70-72), `tap` (l.74-76, clamp de UV a 0.0005..0.9995), `mark_tap` (l.78-80), `graded` (l.83-88).
- **Fragmento** (orden de operaciones):
  - Curvatura por encierro (l.94-95).
  - Transporte de cinta: `wobble = (noise1(uv.y*38 + t*1.3) - 0.5)*0.0022 + sin(uv.y*190 + t*3)*0.00035` (l.99); banda de seguimiento `band_pos = fract(t*0.043)` (l.100-101); `jitter = (hash - 0.5) * 0.004 * band` (l.102); cabeza `head = smoothstep(0.035, 0, 1 - uv.y)` (l.103); `tear = head * (0.012 + ...)` (l.104). Aplicación `uv.x += (wobble + jitter)*vhs + tear*vhs` (l.105).
  - Daño (l.106-124): `damage = max(tape_hit, tape_fray)` (l.107); volteo de líneas superiores (l.112-113); banda de ruido (l.116-119); salto de cabeza (l.121); deslizamiento del marco `uv.y = fract(uv.y + tape_fray² * 0.07 * step(0.72, hash))` (l.123).
  - Luma y croma: `soft = 1 + vhs*2.5` (l.127), `chroma_width = px.x*(1.5 + vhs*9)` (l.131), `chroma_delay = px.x*vhs*3` (l.132). Rama `lite` (l.133-136) o completa (l.137-153): luma con desenfoque y realce de bordes `luma += (luma - far_luma)*0.35*vhs` (l.144), croma con `chroma_taps` muestras repartidas de -3 a +3 anchos (l.147-152).
  - Lente con sangre (l.156-162) usando `through_lens_blood` y cuatro lecturas a 0.12 (l.161).
  - Franjas de color de lente (l.164-169) con `chromatic * 0.045` (l.165).
  - Gradación `graded(color)` (l.170). Nieve de banda (l.172-173).
  - Dropouts (l.179-198): `chance = vhs*0.0012 + tape_hit*0.03 + tape_fray*0.02` (l.181); 240 líneas por campo (l.179); un tercio de los dropouts repite la línea de arriba (l.193-194), el resto pinta una línea blanca `mix(color, (0.92,0.92,0.9), strength*clamp(0.5+vhs, 0, 0.9))` (l.196).
  - Cabeza con nieve `mix(color, snow*0.8, head*vhs*0.55)` (l.199). Daño: cromatismo perdido (l.200-207).
  - Grano `g = hash(uv*(1731,977) + fract(t*23)) - 0.5` (l.209) con `grain * (0.08 + dark*0.14)` (l.211).
  - Barras de campo `scan = 0.5 + 0.5 cos(SCREEN_UV.y*240*2π)` (l.213), `lit` (l.215), viñeta (l.217-218), parpadeo `(noise1(t*11) - 0.5)*0.03*vhs` (l.219), encierro (l.220-221).
  - Pérdida de señal (l.226-259): `rolled`, `tear`, nieve de 260×240 (l.238), barra de zumbido (l.242), líneas (l.244-245), rebobinado con dos barras y `2.0`, `1.9`, `0.62..0.7`, `0.16 + 0.95*bars` (l.252-253), mezcla final con `smoothstep(0.1, 0.85, loss)` (l.255), inestabilidad (l.256-258).
  - Lo escrito sobre la nieve (l.260-284): luma suavizada, croma desplazado, gradación "como sobre negro" `written = graded(written) - graded(0)*(1 - body.a)` (l.281), grano propio (l.282), mezcla `color*(1-a) + written*lit` (l.283).
  - Salida `COLOR = max(color, 0)`, alfa 1 (l.285).
- **Consumidores**: presentation.tscn:4 (ext id 2) y :9 (SubResource Analog). El ColorRect "Analog/Screen" está en CanvasLayer `layer = 5` (presentation.tscn:27-31). Los parámetros se escriben en presentation_rig.gd:286-400: `chroma_taps` (l.286), `lite` (l.287), `vhs`/`scanlines` (l.301), `grain` (l.302), `chromatic` (l.303), `vignette` (l.304), `tint` (l.308), `enclosure` (l.310, 392), `signal_loss` (l.387), `vhs` con `frayed` (l.399), `chromatic` (l.400). Efectos de la muerte: death_tape.gd:446-450 (`lens_blood`, `lens_seed`, `lens_down`), 566 y hotel_main.gd:1461 (`lens_blood` a 0). hotel_ui.gd:2176, 2229 (`marks`, `marked`). Existe una versión JS en `tools/trailer3d/web/engine/looks.js:2-3` ("ported line by line").
- **Discrepancia**: el comentario de `chroma_taps` (l.46-47) dice "7, o 4 en el preset más bajo". Los presets dan 4 en Bajo (graphics_presets.gd:191), 7 en Medio, Alto y Ultra (201, 211, 221) y 2 en Muy bajo (233). Ver §11.

### 3.11 blood.gdshader (62 líneas)
- **Propósito**: una mancha del atlas sobre un cuadrilátero puesto en lo que golpeó. Iluminada como cualquier cosa de la sala (l.2-5).
- **INSTANCE_CUSTOM** (l.7-12): r = índice de celda del atlas, g = instante en que cae, b = duración de la carrera si baja por una pared (0 = no baja), a = cuánto la absorbe la superficie (0 dura, 1 moqueta).
- **Uniforms**: `atlas` (sampler2D filter_linear_mipmap, repeat_disable, l.15), `clock` (1000, l.17; reloj de la sangre, en segundos desde la captura), `film_color` (vec3 source, 0.34, 0.012, 0.008, l.19), `deep_color` (vec3 source, 0.045, 0.002, 0.002, l.20).
- **Vértice** (l.27-37): `VERTEX += normalize(to_eye) * (0.002 + 0.0025*|to_eye|)` (l.36): la mancha se acerca al ojo para no quedar bajo la superficie, más cuanto más lejos se ve.
- **Fragmento**: `age = clock - born`, `discard` si `age < 0` (l.40-41). Celda del atlas `index = floor(cell + 0.5)`, `stain = texture(atlas, (vec2(mod(index,4), floor(index/4)) + inside) * 0.25)` (l.42-44): **atlas 4×4**, celdas de 256 px (tools/textures/bake_blood.py:26-27). `cover = stain.a * smoothstep(0, 0.05, age + 0.02)` (l.45-48). Carrera: `cover *= smoothstep(0.03, -0.03, UV.y - clamp(age/run, 0, 1))` (l.49). `discard` si `cover < 0.03` (l.50). `thick = stain.b` (l.51). `color = mix(film, deep, smoothstep(0, 0.55, thick))` (l.52). `ALBEDO = mix(color, deep, soak)` (l.56). `ALPHA = cover * mix(mix(0.7, 0.97, smoothstep(0, 0.5, thick)), 0.9, soak)` (l.57). `ROUGHNESS = mix(mix(0.2, 0.09, thick), 0.46, soak)` (l.58). `SPECULAR = mix(0.6, 0.28, soak)` (l.59). `NORMAL_MAP = vec3(stain.rg, 1)`, `NORMAL_MAP_DEPTH = mix(1.4, 0.2, soak)` (l.60-61).
- **Consumidor**: blood.gd:28 (STAIN), 30 (ATLAS = res://assets/decals/blood_atlas.png), 317-318 (`atlas`, `clock = 0`), 339-356 (MultiMesh con `use_custom_data = true` y `set_instance_custom_data(index, Color(cell, born, run, soak))`), 452 (`clock` por frame).

### 3.12 blood_pool.gdshader (87 líneas)
- **Propósito**: el charco bajo un cuerpo, en el suelo (l.2-8). Crece con la raíz cúbica del tiempo (como un líquido espeso en un suelo llano, l.3-4). Se frena con lo que tiene delante, en 16 direcciones (`reach`, l.6-7). Sobre moqueta (`soak = 1`) no hay charco: hay una mancha húmeda de dos tercios del tamaño (l.10-12).
- **Uniforms**: `age` (1000, l.16), `span` (1.5 m, l.18; ancho del cuadrilátero), `radius` (0.42 m, l.19), `spread_time` (30 s, l.21), `reach[16]` (float, l.23; distancia por dirección de 16), `soak` (0, l.24), `seed` (0, l.25), `film_color`, `deep_color` (l.26-27).
- **Funciones**: `hash` (l.34-36, sin-hash), `noise` (l.38-43), `depth_at(p, grown)` (l.46-59): ángulo a ranura (`atan`, `TAU`, l.47-48), `held` por interpolación entre dos entradas de `reach` (l.49-51), `lobes = 0.72 + 0.5 noise + 0.16 noise` (l.55), `edge = min(grown*lobes, held - 0.015)` (l.56), `ragged` (l.57), `return edge - |p| + ragged` (l.58).
- **Vértice**: igual que blood (l.29-31).
- **Fragmento**: `discard` si `age < 0` (l.62). `grown = radius * mix(1, 0.7, soak) * pow(clamp(age/spread_time), 0.3333)` (l.63), la raíz cúbica. `p = (UV - 0.5)*span` (l.64). Borde `cover = smoothstep(0, mix(0.008, 0.03, soak), inside)` (l.66). Gota de borde con `exp(-((inside - 0.014)/0.009)²) * 0.35` (l.71). Pendiente para la normal (l.70-77). `fresh` (l.81), `dull` (l.82). `ALBEDO`, `ALPHA` (l.83-84). `ROUGHNESS = mix(0.07, mix(0.3, 0.46, dull), soak)` (l.85).
- **Consumidor**: blood.gd:29 (POOL), 70 (`POOL_SPAN = 1.5`), 72 (`POOL_TIME = 30`), 392-398 (`age = -1`, `span`, `radius`, `spread_time`, `reach`, `soak` = 0 en suelo duro o 1 en otro caso, `seed = int(scene.seed) % 997`), 452-453 (`age = clock - pool_from` por frame), 537 (`reach` en el charco de segunda categoría).

### 3.13 blood_worn.gdshader (60 líneas)
- **Propósito**: segunda pasada sobre ropa y piel de un cuerpo que la criatura atravesó. Dibuja solo lo que se ha empapado alrededor de cada herida, más abajo que arriba porque corre (l.2-6).
- **Uniforms**: `wound_at[2]` (vec3, l.14; posición de la herida en mundo), `wound_frame[2]` (mat3, l.15; marco del hueso), `wound_age[2]` (float, l.16; segundos desde la herida, menor que 0 = todavía no), `reach` (0.17 m, l.18), `spread_time` (3.5 s, l.19), `film_color` (vec3 source, 0.3, 0.012, 0.008), `deep_color` (0.05, 0.002, 0.002) (l.20-21).
- **Vértice** (l.25-30): `place = VERTEX` (en mundo por `world_vertex_coords`); `VERTEX += normalize(to_eye) * 0.0015`.
- **Fragmento** (l.44-59): bucle de 2 heridas (l.46); `continue` si `wound_age < 0` (l.47); `from = wound_frame * (place - wound_at)` (l.48); `from.y *= from.y < 0 ? 0.5 : 1.5` (l.50); `grown = reach * (0.25 + 0.75 * pow(clamp(age/spread_time), 0.5))` (l.51); `ragged` (l.52, ruido a 34 y 90); `soaked = max(soaked, smoothstep(grown, grown*0.55, |from| + ragged))` (l.53). `discard` si `soaked < 0.03` (l.55). `ALBEDO`, `ALPHA = soaked*0.94`, `ROUGHNESS = mix(0.5, 0.22, soaked)`, `SPECULAR = 0.45` (l.56-59).
- **Consumidor**: avatar_visual.gd:386 (WORN_BLOOD), 419-421: `wound_at` (PackedVector3Array), `wound_frame` (frames), `wound_age` (PackedFloat32Array con `since - 0.03` y `since - kill_time`). Es el único `set_shader_parameter` de avatar_visual.gd. `reach` y `spread_time` no se fijan desde GD (quedan los valores por defecto).

### 3.14 carpet.gdshader (82 líneas)
- **Propósito**: moqueta de hotel con medallones entrelazados, pelo de tufo y desgaste (l.2).
- **Includes**: surface.gdshaderinc e image_maps.gdshaderinc (l.3-4).
- **Uniforms** (l.6-14): `base_color` (vec4 source, 0.32, 0.27, 0.20, 1), `field_color` (0.19, 0.075, 0.055), `line_color` (0.33, 0.22, 0.11), `accent_color` (0.13, 0.075, 0.05), `tile_size` (0.62), `pattern` (0..1, 1), `wear` (0..1, 0.6), `fibre_bleed` (0.035 m).
- **Fragmento**: `baked_surface()` (l.19-21). Procedural (l.22-80): `tufts` desde la normal map (l.30), celda `(uv + tufts)/tile_size` (l.31), octágono `max(max(a.x, a.y), (a.x + a.y)*0.72)` (l.36), anillo `smoothstep(0.022, 0.01, |octagon - 0.32|)` (l.37), cruz (l.39), celosía `smoothstep(0.02, 0.008, |(|q.x| + |q.y| - 0.9)*0.7|)` (l.40), esquina (l.41), mezclas de color (l.42-47), `color *= 0.94 + hash12(id)*0.06` (l.50). `scan_albedo` (l.55). Pelo: `pile` (l.58), `brush` (l.59), `color *= 0.84 + pile*0.22 + (brush - 0.5)*0.14` (l.60). Desgaste `traffic` (l.62). Solo con `finest_surface()` (l.63-70), dirección del pelo con `lie = fbm * 12.566` (4π) y `dot(toward, lie)` (l.67-69). Manchas (l.72-73). `ao` (l.74), `room_grime` (l.75), `ROUGHNESS = scan_roughness(l, 0.97) - traffic*0.05` (l.78), `height = pile*0.002 - motif*0.0006*pattern` (l.79), `NORMAL` (l.80).
- **Consumidores**: presentation/materials/carpet.tres:3; office/carpet.tres:3; office/carpet_exec.tres:3; office/mat_rib.tres:3.

### 3.15 ceiling.gdshader (34 líneas)
- **Propósito**: techo de gotelé (popcorn), amarillento por el humo y con manchas de agua (l.2).
- **Uniforms**: `base_color` (vec4 source, 0.66, 0.63, 0.53), `stain_color` (0.45, 0.37, 0.22), `stains` (0..1, 0.6).
- **Fragmento**: `blotch = fbm(uv*0.45)` (l.21), `damp = smoothstep(0.6, 0.72, blotch) * stains` (l.24), `edge = smoothstep(0.015, 0, |blotch - 0.66|) * stains` (l.25), mezcla con `stain_color * 0.55` (l.26), `color *= 1 - edge*0.25` (l.27), `ao`, `room_grime`, `ROUGHNESS = scan_roughness(l, 0.95)` (l.31), `NORMAL = BUMPED_VIEW_NORMAL(scan_normal(l, wn), stipple*0.004 + plane_swell(uv), 1)` (l.32).
- **Consumidores**: presentation/materials/ceiling.tres:3; ceiling_service.tres:3. tests/office/office_finishes_test.gd:114 comprueba que la placa de servicio del hotel use `ceiling.gdshader`.

### 3.16 curtain.gdshader (27 líneas)
- **Propósito**: cortina de terciopelo pesada. El balanceo es solo de presentación y se apaga con efectos reducidos; no mueve colisiones (l.2-3).
- **Uniforms**: `motion` (1, l.6), `color` (vec4 source, 0.30, 0.08, 0.07, 1), `fold_color` (vec4 source, 0.10, 0.03, 0.03, 1).
- **Vértice**: `VERTEX.z += sin(TIME*0.7 + VERTEX.x*8)*0.035*motion*(1 - UV.y)` (l.11). Luego `SURFACE_VERTEX` (l.12).
- **Fragmento**: `folds = 0.5 + 0.5 sin(uv.x*31 + sin(uv.y*1.3)*0.8)` (l.17), `nap = fine_noise(uv*(90, 30))` (l.18), `dust = fbm(uv*2)*0.2` (l.19), `base = mix(fold, color, 0.35 + folds*0.65)` (l.20), `base *= 0.9 + nap*0.12 + dust*0.3` (l.21), `ROUGHNESS = 0.9` (l.23), `RIM = 0.7`, `RIM_TINT = 0.7` (l.24-25), `NORMAL = BUMPED_VIEW_NORMAL(wn, folds*0.02 + nap*0.0004, 1)` (l.26).
- **Consumidores**: presentation/materials/curtain.tres:3. hotel_geometry.gd:3011 escribe `motion`. survival_test.gd:492 comprueba `motion == 0` con efectos reducidos.

### 3.17 exit_panel.gdshader (67 líneas)
- **Propósito**: rótulo de salida de metacrilato con diodos en el borde superior. La lámina guía la luz; la letra grabada la dispersa, así que la letra se dibuja con luz y no pintada (l.2-8).
- **Generador de la textura**: tools/textures/make_exit_sign.py (R = cara grabada, G = borde de corte; l.10-11). La imagen es de 1024×512 (make_exit_sign.py:24).
- **Uniforms**: `engraving` (sampler2D filter_linear_mipmap, l.14), `two_faced` (bool false, l.17; dos caras con texto distinto), `engraving_back` (l.18), `glow` (vec3 source, 0.07, 1.0, 0.33, l.20), `core` (vec3 source, 0.62, 1.0, 0.8, l.21), `energy` (5, l.22), `diodes` (int 5, l.24), `sheet` (0.09, l.27), `sheen` (0.45, l.28), `level` (1, l.30; atenuación con las lámparas).
- **Fragmento**: `uv = UV` con espejo si `!FRONT_FACING` (l.35-36). `cut` (l.37). Bucle de diodos (l.43-48): `across`, `cones += exp(-across²/(0.0006 + depth²*0.07))` (l.46), `lamps += exp(-across²/0.00004) * exp(-depth*90)` (l.47). `cones *= exp(-depth*2.6)/diodes` (l.49). `guided = mix(0.62, 1, exp(-depth*1.1))` (l.51). `letters = (cut.r*0.7 + cut.g*2.1)*guided` (l.53). Borde de la lámina (l.55-57). `lit` (l.60). Color `mix(glow, core, clamp(lit*0.55))` (l.62). Reflejo rasante `pow(1 - |dot(NORMAL, VIEW)|, 3)` (l.64). `ALBEDO = colour * lit * energy + vec3(0.35, 0.45, 0.4)*grazing*sheen*level` (l.65). `ALPHA = clamp(sheet + grazing*sheen + lit*1.4)` (l.66).
- **Consumidores**: hotel_geometry.gd:1857-1886: `EXIT_PANEL` (l.1859), `ShaderMaterial.new()` (l.1881), `engraving` (l.1883), `two_faced` y `engraving_back` (l.1885-1886). tests/hotel/stages_test.gd:660 comprueba `level` en los carteles de salida. tools/workbenches/module_gallery.tscn:43 también lo referencia.

### 3.18 finish.gdshader (85 líneas)
- **Propósito**: acabados de mobiliario: metal cepillado, tela tejida, lino arrugado, hoja, plano (l.2-3). Añade relieve fino y suciedad irregular.
- **Uniforms** (l.7-22): `albedo` (vec4 source, 0.5), `variation_color` (vec4 source, 0.4), `roughness` (0..1, 0.7), `metallic` (0..1, 0), `specular` (0..1, 0.5), `finish` (enum Plain=0, Brushed=1, Weave=2, Crumpled=3, Leaf=4), `detail_scale` (1), `relief` (1), `sheen` (0..1, 0; si > 0 activa RIM), `grime` (0..1, 0.35), `backlight` (0..1, 0; BACKLIGHT = color*backlight), `map_rough_keep` (0..1, 1; cuánto de la rugosidad del escaneo se conserva), `brush_across` (bool false; cepillado girado 90°).
- **Fragmento**: `uv = face_uv() * detail_scale` (l.32), `large = fbm(uv*1.3 + plane_offset*9)` (l.33). Bloques por acabado: Brushed (l.37-42, `streak`, `rough`), Weave (l.43-48, `abs(sin)` de 180), Crumpled (l.49-53), Leaf (l.54-57, vetas), Plain (l.58-61). Escaneo (l.65-67), `height *= 0.2` con escaneo (l.67). Suciedad `dirt = smoothstep(0.6, 0.9, fbm(uv*1.7 + 5))*grime*0.6 + smoothstep(0.35, 0, wp.y)*grime*0.4` (l.69-70), `color *= 1 - clamp(dirt)*0.35` (l.71). `ao` (l.72), `METALLIC = scan_metallic` (l.75), `SPECULAR` (l.76), `ROUGHNESS = clamp(rough_mix + dirt*0.25, 0.02, 1)` (l.77), `RIM = sheen` y `RIM_TINT = 0.6` si sheen > 0 (l.78-81), `BACKLIGHT` (l.82), `NORMAL` (l.83).
- **Consumidores**: 37 materiales `.tres` (lista en §6). office_finishes_test.gd:80-106 comprueba `clear_glass` (`wire` 0), `map_mode`, `map_tint`, `map_rough_keep` (0 en steel), `object_space` en walnut_object y oak_door (l.104-105), y `walnut` sin `object_space` (l.106).

### 3.19 lens.gdshader (92 líneas)
- **Propósito**: óptica y sensor de la videocámara sobre la imagen final, después de TAA y del tonemapping, y debajo del OSD (l.2-8). Orden: lente (barril, aberración lateral, viñeta), luego sensor (campos entrelazados, ruido con la ganancia, croma en la oscuridad), luego la mejora de detalle de la cámara (l.5-8).
- **Uniforms**: `screen_texture` (hint_screen_texture filter_linear, l.9), `barrel` (0.05, l.13), `scale` (0.8, l.14), `chromatic` (0..1, 0.3, l.16), `vignette` (0..1, 0.45, l.18), `noise` (0..1, 0.35, l.23), `gain_map` (sampler2D filter_nearest hint_default_white, l.24; canal B = ganancia del iris), `field_shift` (vec2 0, l.29; desplazamiento del campo impar en UV), `detail` (0..1, 0.35, l.32).
- **Funciones**: `hash` 3D (l.34-38), `distort(uv, aspect, amount)` (l.40-45): `p *= scale*(1 + barrel*r²)*amount`.
- **Fragmento**: `aspect = px.y/px.x` (l.53), `spread = chromatic*0.004` (l.56), `field_line = floor(FRAGCOORD.y*px.y*480)` (l.57; líneas impares desplazadas por `field_shift`, l.58), colores R, G, B con distintos aumentos (l.59-63), realce `edge*detail*0.9` con muestras a ±1.5 px (l.65-69), viñeta `falloff = pow(1/(1 + r²*0.55), 2)` (l.73) y `mix(1, falloff*(1 - smoothstep(0.55, 1, r²)*0.35), vignette)` (l.74). Ruido (l.78-90): `frame = floor(TIME*30)` (l.81), `n = hash + hash - 1` (l.83), `c` croma (l.84), `gain = texture(gain_map, (0.5,0.5)).b` (l.85), `sigma = (sqrt(luma)*0.06 + 0.012)*gain` (l.86), `dark = 1 - smoothstep(0, 0.25, luma)` (l.87), `linear += (n*sigma + c*sigma*0.9*dark)*noise*2` (l.88), `color = sqrt(linear)` (l.89). `COLOR = max(color, 0)` (l.91).
- **Consumidores**: presentation.tscn:6, 12 (ext id 4 y SubResource Lens), 17-20 (CanvasLayer `layer = 2`, ColorRect "Lens/Screen"). presentation_rig.gd:85 (`gain_map` = `camera_effect.exposure_texture`), 131 (`field_shift`), 143-146 (`noise`, `chromatic`, `vignette` 0.45, `detail` 0.35; a 0 con efectos reducidos), 177-178 (`barrel`, `scale = LOOK.corner_scale(aspect, barrel)`). camcorder_look.gd:33-47 (`barrel_for`, `corner_scale`, `render_fov`).
- **Nota**: el shader es lo que el juego llama "lente". Fuera del `analog`.

### 3.20 painting.gdshader (30 líneas)
- **Propósito**: cuadro de paisaje desvaído bajo barniz amarillento, con una composición distinta por posición (l.2-3). No hay textura: todo es procedural.
- **Uniforms**: `sky`, `land`, `accent`, `varnish` (vec4 source; 0.42, 0.44, 0.38 / 0.22, 0.24, 0.14 / 0.45, 0.30, 0.16 / 0.86, 0.74, 0.50; l.6-9).
- **Fragmento**: `seed = hash13(floor(wp*0.8))*50` (l.15), `p`, `horizon = fract(-uv.y*1.28 + seed)` (l.16-17), `hills = fbm(...)*0.35 + 0.35` (l.18), `ground = smoothstep(hills + 0.03, hills - 0.03, fract(horizon))` (l.19), `strokes = fbm(p*(9,4))` (l.20), `figure` (l.22-23), barniz `*= varnish*1.1` (l.24), craquelado `smoothstep(0.02, 0, |vnoise(uv*60) - 0.5|)` (l.25-26), `ROUGHNESS = 0.45 + strokes*0.2` (l.28), `NORMAL` (l.29).
- **Consumidor**: presentation/materials/painting.tres:3.

### 3.21 tile.gdshader (89 líneas)
- **Propósito**: baldosas vidriadas de zona de servicio con junta sucia, esmalte irregular y grietas finas (l.2). Variantes: vinilo en losetas con "marble" (l.17-18), pasillo con "wear" (l.20-21), pendiente por baldosa (l.22-27).
- **Uniforms** (l.6-27): `tile_color`, `alternate_color` (vec4 source, 0.58/0.5), `grout_color` (0.36, 0.34, 0.28), `tile_size` (0.3 m), `grout_width` (0.0035 m), `checker` (0..1, 0.35), `grime` (0..1, 0.6), `tile_count` (8; baldosas por repetición de un escaneo), `specular_level` (0..1, 0.42; comentario: lo que da la capa de cera del vestíbulo, l.15-16), `marble` (0..1, 0), `wear` (0..1, 0; pasillo central), `tilt_always` (bool false), `tilt` (0.045).
- **Fragmento**: `baked_surface()` (l.32-35). Procedural (l.36-87): `size = use_maps ? map_metres/tile_count : tile_size` (l.41), `grout`, `bevel` (l.46-47), `check` (l.48), `color` (l.49-50), vinilo `marble` (l.51-56), pasillo `lane` con `room_data` (l.58-64), `scan_albedo` (l.65), `scan_grout` (l.67), `dirt` (l.68), `crack` (l.69), mezclas (l.70-72), `ao` (l.73), `ALBEDO` (l.74), `ROUGHNESS` (l.77), `SPECULAR = specular_level` (l.78), `height` (l.79), `n` (l.80), pendiente por baldosa `lean` (l.81-86) solo con `finest_surface()` o `tilt_always`, `NORMAL` (l.87).
- **Consumidores**: presentation/materials/tile.tres:3; office/quarry.tres, vinyl.tres, vinyl_hall.tres, vinyl_polished.tres, wet_band.tres, wet_tile.tres (cada uno con `tile.gdshader` en su ext_resource 3).

### 3.22 typewriter_ink.gdshader (32 líneas, canvas_item)
- **Propósito**: tinta de la cinta de tela de una máquina de escribir, nunca uniforme. Donde la cinta se gastó o la tecla bajó blanda, la letra es más fina; el tejido se ve como grano (l.2-6). Se mide en píxeles del formulario (VERTEX, antes de escalar), así que una hoja en mano y su miniatura llevan el mismo moteado (l.4-6).
- **Uniforms**: `grain` (0..1, 0.5, l.7).
- **Vértice**: `local = VERTEX` (l.22-24).
- **Fragmento**: `weave = noise(local*0.85)` (l.28), `dry = noise(local*(0.012, 0.05))` (l.29), `ink = mix(1, 0.45 + 0.55*weave, grain) * mix(0.72, 1, dry)` (l.30), `COLOR.a *= clamp(ink, 0, 1)` (l.31).
- **Consumidores**: game/ui/hotel_form.gd:22 (INK_SHADER), game/ui/ruled_paper.gd:10 (INK_SHADER).

### 3.23 venetian_blind.gdshader (17 líneas)
- **Propósito**: persiana veneciana sobre un solo quad: lamas cada `pitch` metros a lo largo de `height`, con hueco `open` del paso, y solo la parte superior `drop` cubierta (l.2-5).
- **Uniforms**: `pitch` (0.022, l.6), `open` (0.3, l.7), `drop` (1.0, l.8), `height` (1.7, l.9), `color` (vec4 source, 0.8, 0.78, 0.72, 1, l.10).
- **Fragmento**: `discard` si `UV.y > drop` (l.13) o si `fract(UV.y*height/pitch) < open` (l.14). `ALBEDO = color.rgb`, `ROUGHNESS = 0.6` (l.15-16).
- **Consumidor**: office_geometry.gd:87 (BLIND), 1613-1621: `pitch = BLIND_PITCH` (0.022, l.76), `height = band`, `color = BLIND_COLOR` (cbbf9f, l.86), `open = 0.05 si roll < 0.33; 0 si roll >= 0.66; si no 0.35 + vary(spot, 171)*0.3` (l.1618), `drop`.

### 3.24 wallpaper.gdshader (84 líneas)
- **Propósito**: papel pintado envejecido: juntas de rollo, motivo estampado, manchas de agua y suciedad (l.2).
- **Includes**: surface e image_maps (l.3-4).
- **Uniforms** (l.6-16): `paper_color` (vec4 source, 0.62, 0.55, 0.40), `print_color` (0.47, 0.40, 0.27), `stain_color` (0.33, 0.25, 0.14), `edge_color` (0.55, 0.52, 0.46), `roll_width` (0.53 m), `motif_height` (0.46 m), `print_strength` (0..1, 0.55), `stains` (0..1, 0.55), `grime` (0..1, 0.5), `ink_bleed` (0.03 m).
- **Fragmento**: `baked_surface()` (l.21-25): `baked_albedo(vec2(face_uv().x, lite_metres.y - (wp.y - NODE_POSITION_WORLD.y)), ...)`, con franja de la altura de la sala más alta (l.22-24). Techos y frente de pared: `fbm(wp.xz*9)` (l.30-34). Muros (l.35-82): `bleed` (l.40), `roll = floor(u/roll_width)` (l.43), `cell`, `ogee = smoothstep(0.23, 0.2, |(|q.x| - 0.25cos(q.y*6.2831))|)` (l.48), `dots` (l.49), `stripe` (l.50), `print_mask` (l.51), `fibre`, `mottling` (l.52-53), `base` (l.54-61), juntas `seam` (l.63-65), manchas `stain_field = fbm(...)` (l.67-72), suciedad baja y de manos (l.73-75), `ao`, `ALBEDO` (l.76-77), `ROUGHNESS` (l.79), `height` (l.80), `NORMAL` (l.81).
- **Consumidores**: office/office_paint.tres, office_paint_kept.tres, partition.tres, reception_low.tres, taupe.tres; presentation/materials/plaster.tres, plaster_decrepit.tres (cada uno con `wallpaper.gdshader`).

### 3.25 wired_glass.gdshader (30 líneas)
- **Propósito**: vidrio armado de oficina: un cristal verdoso con malla de alambre, en metros de mundo, para que un panel largo y uno corto lleven la misma malla (l.2-5). No tiene reflejo de la lámpara (l.6-7).
- **Render mode**: `blend_mix, cull_disabled, depth_draw_opaque, specular_disabled` (l.8).
- **Uniforms**: `glass_color` (vec4 source, 0.72, 0.8, 0.78, 0.16), `wire_color` (vec4 source, 0.22, 0.23, 0.22, 0.75), `pitch` (0.025), `wire` (0.06).
- **Vértice**: `world = MODEL_MATRIX * VERTEX` (l.17-19). **Fragmento**: `cell = vec2(world.x + world.z, world.y)/pitch` (l.22), `from_middle` (l.23), `on_wire = step(0.5 - wire*0.5, max(from_middle))` (l.24), `ALBEDO`, `ALPHA` (l.25-26), `ROUGHNESS` (0.05 / 0.6, l.27), `METALLIC` (0 / 0.5, l.28), `SPECULAR = 0.8` (l.29).
- **Consumidores**: office_geometry.gd:88 (WIRED_GLASS), 267-268 (`glass`), 271-274 (`clear`: `wire = 0`, `glass_color` 0.78, 0.8, 0.76, 0.12). tests/office/office_finishes_test.gd:80 (`clear_glass.wire == 0`).

### 3.26 wood.gdshaderinc, wood.gdshader y wood_lacquer.gdshader
- **Propósito**: madera lacada del hotel (`wood.gdshaderinc:1-6`). El barniz como capa propia va en un shader aparte, porque un shader que escribe CLEARCOAT paga esa segunda luz en cada píxel bajo cada lámpara, aunque sea el preset más alto (comentario l.3-6; el comentario cita "un cuarto de milisegundo de un fotograma de Alto a 1080p", cifra no comprobada aquí).
- **Uniforms** (l.10-21): `light_color` (vec4 source, 0.36, 0.21, 0.11), `dark_color` (0.17, 0.09, 0.05), `ring_density` (22), `varnish` (0..1, 0.65), `lacquer_edge` (0.04..1, 0.06; cuánto del reflejo de la sala ve un barniz de vista rasante, l.14-16), `scuffs` (0..1, 0.5), `panel_spacing` (0; separación de juntas de tablero), `door_panels` (bool false), `object_space` (bool false; el grano sigue a la pieza, p. ej. una hoja de puerta; l.21 y varios `.tres` lo activan).
- **Vértice** (l.36-67): modo `object_space` (l.37-45): `wp = VERTEX`, `wn = NORMAL`, `room_data = 0`, `grain = face_uv()`, `object_x/y/z = MODEL_MATRIX[0..2].xyz`. Modo normal (l.46-65): `SURFACE_VERTEX`; ejes de grano `u`, `v` por la normal y la escala (l.48-56); `grain_t = normalize(MODEL_MATRIX * u)` (l.57); `bitangent` (l.61); `cut = (hash13(floor(origin*7.1)), hash13(floor(origin*5.3)+2)) * (5, 3)` (l.64): cada pieza se corta de un punto distinto de la tabla; `grain = (dot(wp - origin, grain_t), -dot(wp - origin, bitangent)) + cut` (l.65).
- **Fragmento**: `baked_surface()` (l.70-83): `baked_albedo(grain, ...)`, con `cut` de paneles (l.74-77) y puertas (l.78-81), `ROUGHNESS = 0.6`. Procedural (l.84-141): `warp = fbm(g*(0.6, 7) + plane_offset*17)` (l.89), `rings = fract((g.y + warp*0.12)*ring_density)` (l.90), `ring_line = smoothstep(0, 0.55, rings)*smoothstep(1, 0.8, rings)` (l.91), `pores = smoothstep(0.62, 0.8, fine_noise(g*(8, 420)))` (l.92), `color` (l.93-94), escaneo `scan_albedo(l, color)` (l.96-97), juntas y puertas (l.98-108), `scratch` (l.110), `dull` (l.111), `ALBEDO` (l.114), `ROUGHNESS = (use_maps ? mix(scan_roughness(l, lacquer), lacquer, 0.5) : lacquer) + dull*0.25 + scratch*0.2` con `lacquer = mix(0.75, 0.28, varnish)` (l.118-119), `SPECULAR = 0.5` (l.120). Bloque `LACQUER_COAT` (l.121-136): `CLEARCOAT = varnish*(1 - dull*0.7)*(1 - scratch*0.8)*(1 - groove)` (l.125), `edge_on = 0.04 + 0.96*pow(1 - clamp(dot(N, VIEW)), 5)` (l.131), `CLEARCOAT *= min(1, lacquer_edge/edge_on)` (l.132), `CLEARCOAT_ROUGHNESS = 0.6 + dull*0.4` (l.135). `height` (l.137), `n = bump_world(...)` (l.138), `NORMAL` (l.139-140).
- **Consumidores**: 11 `.tres` con `wood.gdshader` (door, panel, trim, wood; office/car_oak, dado_oak, oak_door, reception_teak, veneer, walnut, walnut_object). hotel_geometry.gd:2712 (`WOOD`), 2713 (`WOOD_LACQUER`), 2714-2718 (`lacquer(coated)` cambia `material.shader` entre ambos), 2594 (llamada con `surface_detail > 4.5`), 420-421 (`object_space = true`, `panel_spacing = 0`). tests/hotel/hotel_test.gd:477 comprueba que en Ultra se use `WOOD_LACQUER`. tests/office/office_finishes_test.gd:104-106 comprueba `object_space` en walnut_object y oak_door.

### 3.27 signal_wash.gdshader (51 líneas, canvas_item, interfaz)
- **Propósito**: una imagen que pierde señal analógica: las líneas se hinchan y ondulan como agua, la imagen se corre en un borrón y la nieve la come. `wash` 0 = limpia, 1 = nada (l.2-4).
- **Uniforms**: `wash` (0..1, 0, l.5).
- **Funciones**: `hash` (l.7-11), `inside(uv)` (l.14-16; fuera del borde no hay nada, no se repite el borde), macro `PICTURE(at) = texture(TEXTURE, at) * inside(at)` (l.17).
- **Fragmento**: `frame = floor(TIME*24)` (l.21). Ondulación `swell = sin(uv.y*24 + TIME*5)*0.022 + sin(uv.y*71 - TIME*13)*0.009` (l.24). Filas que saltan: `row = floor(uv.y*22)`, `tear = step(1 - w*0.8, hash)*(hash - 0.5)*0.14` (l.26-27). `uv.x += (swell + tear)*w` (l.28), `uv.y += sin(uv.x*5 + TIME*3)*0.025*w` (l.29). Arrastre `step_x = TEXTURE_PIXEL_SIZE.x*(1 + 9w)` (l.31), `step_y = TEXTURE_PIXEL_SIZE.y*3w` (l.32), pesos 0.28 / 0.18 / 0.1 / 0.08 (l.33-36), `mix(PICTURE(uv), col, clamp(w*3))` (l.37), canal rojo arrastrado `w` (l.38). Nieve con `FRAGCOORD/2` y `FRAGCOORD/3` (l.40-41), `mix(col.rgb, (0.85,0.85,0.82)*snow, w*0.75)` (l.42), alfa `smoothstep(w*1.2 - 0.2, w*1.2, grain)` (l.43) y `1 - w²*0.6` (l.44). Halo de nieve en el hueco del aviso con borde difuso (l.47-48). `COLOR = col * COLOR` (l.50).
- **Consumidores**: game/ui/hotel_ui.gd:2059 (WASH), 2134 (`look.shader = WASH`), 2135-2139 (`wash` 1 → 0 con tween); game/ui/rules_screen.gd:17, 98, 113-114 (`wash` 1 → 0 en `DETAIL_IN`).

### 3.28 tape_noise.gdshader (20 líneas, canvas_item, interfaz)
- **Propósito**: estática de cinta para transiciones de menú y pérdida de señal. `amount` 0 = invisible (l.2).
- **Uniforms**: `amount` (0..1, 0, l.3), `tint` (vec4 source, 0.85, 0.85, 0.82, 1, l.4).
- **Fragmento**: `cell = floor(FRAGCOORD.xy/2)` (l.13), `frame = floor(TIME*30)` (l.14), `snow = hash(cell + frame*17)` (l.15), `line = hash(vec2(floor(FRAGCOORD.y/3), frame))` (l.16), `bands = smoothstep(0.82, 1, line)` (l.17), `value = snow*0.75 + bands*0.35` (l.18), `COLOR = vec4(tint.rgb*value, amount*(0.55 + 0.45*snow))` (l.19).
- **Consumidores**: game/intro/intro_sequence.gd:22 (NOISE), 120 (`static_veil.shader`), 241 (tween de `amount`); game/ui/hotel_ui.gd:6 (NOISE), 428, 2210 (`amount`), 2333, 2341.

### 3.29 typewriter_ink, venetian_blind, wired_glass
Ver §3.22, §3.23 y §3.25.

### 3.30 lens_blood_look.gdshader (11 líneas, herramienta)
- Solo para `tools/dev/lens_blood_look.gd`, que dibuja las gotas sobre un fondo neutro (l.2-3). `COLOR = through_lens_blood(ground, blood_on_lens(UV*(wide,1), wide), ground)` (l.10). `ground` (vec3, 0.92, 0.92, 0.9), `wide` (1.7778).

---

## 4. Includes

### 4.1 surface.gdshaderinc (205 líneas)
- **Varyings** (l.7-13): `wp` (posición de mundo), `wn` (normal de mundo), `room_data` (flat vec4, de INSTANCE_CUSTOM: media anchura y media profundidad de la sala, altura del techo, lados abiertos 1 -x, 2 +x, 4 -z, 8 +z; 0 fuera de sala). Lo rellena hotel_geometry.gd:599-606.
- **Macro** `SURFACE_VERTEX` (l.16): `wp`, `wn`, `room_data = INSTANCE_CUSTOM`.
- **Global** `surface_detail` (l.40), uniforme global. Sus valores por preset están en graphics_presets.gd:191, 201, 211, 221, 233 (ver §8).
- **Funciones**: `hash12` (l.18-22), `hash13` (l.24-28), `vnoise` (l.30-35), `fbm` con octavas `clamp(int(surface_detail), 1, 4)` (l.42-58; las que faltan suman su media), `fine_noise` (l.63-66; con `surface_detail < 2.5` devuelve 0.5), `face_uv` (l.70-75), `face_tangent` (l.77-82), `face_bitangent` (l.84-88), `is_floor_face` (`wn.y > 0.5`, l.90), `is_ceiling_face` (l.91), `plane_offset` (l.95-97), `map_normal_world` (l.101-106), `room_edge` (l.112-133), `room_grime` (l.136-148), `finest_surface()` (`surface_detail > 4.5`, l.157), `plane_swell` (l.162-165), `baked_surface()` (`surface_detail < 0.5`, l.182), `baked_albedo` (l.185-190), `bump_world` (l.194-201), macro `BUMPED_VIEW_NORMAL` (l.205).
- **Uniforms de lite** (l.177-180): `flat_color` (vec4 source, 0.5), `use_lite` (bool false), `lite_map` (sampler2D source_color filter_linear_mipmap repeat_enable), `lite_metres` (vec2 1).
- **Constantes**: `room_edge`: 0.12 (l.121-122), 10000 para lados abiertos (l.119), 3.2 (l.128), 0.4 (l.128), 6 (l.130), 2.5 (l.131). `room_grime`: 0.55 (l.141), 0.22 (l.142), 0.72/0.78/0.86/0.6/0.45 (l.144-146). `plane_swell`: 1.9, 31, 0.012, 0.7, 5, 0.02 (l.164). `baked_albedo`: 0.3 (l.189).
- **Consumidores**: 9 shaders la incluyen directamente (ceiling_tile, carpet, ceiling, curtain, finish, painting, tile, wallpaper, wood.gdshaderinc) y 2 por medio de wood.gdshaderinc (wood, wood_lacquer). exit_panel, analog, lens, blood y los demás no la usan (grep de `#include`, verificado).
- **Consumidores de la lógica de preset**: presentation_rig.gd:283-285 (`surface_detail` global); hotel_geometry.gd:433, 599, 1239 (comentarios que citan el include).

### 4.2 image_maps.gdshaderinc (112 líneas)
- **Uniforms** (l.9-34, grupo `image_maps`): `use_maps` (bool false, l.10), `albedo_map` (sampler2D source_color filter_linear_mipmap_anisotropic repeat_enable, l.11), `normal_map` (sampler2D hint_normal, l.12), `orm_map` (sampler2D hint_default_white, l.14; R = oclusión, G = rugosidad, B = metálico), `map_mode` (enum Replace=0, Recolour=1, Detail=2, default 1, l.19), `map_tint` (vec4 source, 1, l.20), `map_detail` (0..2, 1, l.21), `normal_strength` (1, l.22), `map_roughness` (-1..1, 0, l.24), `map_metallic` (0..1, 1, l.26), `map_metres` (1 m, l.28), `map_no_tile` (bool false, l.33).
- **Funciones**: `map_uv` = `face_uv()/max(map_metres, 0.01)` (l.46), `map_lookup` con desplazamiento para rompe-repetición si `map_no_tile && surface_detail >= 2.5` (l.50-65; `vnoise(uv*0.7)*8`, `sin(vec2(3,7)*i)`, `smoothstep(0.25, 0.75, fract(k))`), `map_sample` (l.67-71, `textureGrad`), `scan_albedo` (l.73-82: Replace = `scan * map_tint` (l.76); Recolour con media por luminancia a mip 12 (l.78-80); Detail = `procedural * max(mix(1, ratio, map_detail), 0)` (l.81)), `scan_roughness` (l.84-87, `g + map_roughness` clamp 0.02..1), `scan_metallic` (l.89-92, `b * map_metallic`), `scan_occlusion` (l.94-97, `r`), `scan_normal` (l.100-103), `scan_normal_frame` (l.106-112).
- **Constante**: `LUMA = (0.2126, 0.7152, 0.0722)` (l.36).
- **Consumidores**: carpet, ceiling, ceiling_tile, finish, tile, wallpaper, wood.gdshaderinc. Carga de escaneos: hotel_geometry.gd:452-470 (`albedo_map`, `normal_map`, `orm_map`, `use_maps`, `use_lite`, `lite_map`, `lite_metres`). Los escaneos se generan con tools/textures/ingest_pbr.py (image_maps.gdshaderinc:2).

### 4.3 lens_blood.gdshaderinc (196 líneas)
- **Uniforms** (l.24-30): `lens_blood` (float, 0; segundos desde la primera gota, 0 = ninguna), `lens_seed` (float, 0), `lens_down` (vec2, (0, 1); "abajo" en la imagen: x a la derecha, y hacia abajo de la pantalla; 0 = el cristal está plano).
- **Funciones**: `lens_hash` (l.32-34), `lens_grain` (l.36-41), `lens_join` (l.44-47, unión con filete `soft`), `lens_drop(which, wide)` (l.56-64): posición, tamaño (dos grandes 0.098-0.13, dos medias 0.06-0.082, tres pequeñas 0.03-0.05; l.62), `lens_lands(which)` (l.68-70: `0.035*which` o `0.3 + 0.045*which`), `blood_on_lens(p, wide)` (l.74-182): siete gotas (l.82-163), `blur = 0.007` (l.81), `weight` (l.89), `sags = smoothstep(0.24, 0.34, weight)` (l.116), `gives = smoothstep(0.56, 0.66, weight)` (l.117), `held` (l.119), `pace` (l.122), `most` (l.123), `gone` (l.124), `head` (l.131), ondas de borde `lumpy` con `wave` de 2 a 7 (l.105-109, `TAU`), dieciséis motas (l.167-180), `speck = 0.0025 + 0.0075*pow(hash, 2)` (l.174). `through_lens_blood(color, film, around)` (l.190-196): `passed = color * exp(-film*(3.2, 9.5, 10.5))` (l.193), `own = (0.54, 0.02, 0.014) * exp(-film*(0.72, 1.9, 1.9)) * (1 - exp(-film*3.5)) * (0.13 + 0.95*lit)` (l.194).
- **Consumidores**: analog.gdshader:35 (include), tools/dev/lens_blood_look.gdshader:4, tools/dev/lens_blood_look.gd:24-39 (`lens_seed`, `lens_down`, `lens_blood`).
- **Lo que lo escribe en juego**: death_tape.gd:446-450 (`lens_blood`, `lens_seed = float(id % 89) + 0.37`, `lens_down = Vector2(-lens.x.y, lens.y.y)`), 566 y hotel_main.gd:1461 (`lens_blood = 0`).

### 4.4 wood.gdshaderinc (142 líneas)
Ver §3.26. Es el cuerpo de madera; `wood.gdshader` y `wood_lacquer.gdshader` lo incluyen (y el segundo define `LACQUER_COAT` antes).

---

## 5. Compute GLSL embebido (fuera de `.gdshader`, pero es shader)

Son cadenas GLSL 450 dentro de GDScript, compiladas en ejecución con `RDShaderSource`, `shader_compile_spirv_from_source` y `compute_pipeline_create`. Se ejecutan como `CompositorEffect` (`presentation_rig.gd:22, 31, 56-66`).

### 5.1 camcorder_effect.gd (477 líneas; CompositorEffect, POST_TRANSPARENT)
- Cabecera de propósito y etapas: l.1-33. Antes del TAA y del tonemap; no hace nada sin RenderingDevice (Headless o Compatibility) (l.30-33).
- Constantes: `GRID = Vector2i(64, 36)` (l.34), `key = 0.065` (l.37), `min_ev = -1.5`, `max_ev = 0.8` (l.39-40), `speed_up = 1.1`, `speed_down = 2.4` (l.43-44), `smear = 0.28` (l.48), `smear_threshold = 5.0` (l.49), `smear_clip = 12.0` (l.53), `smear_spread = 0.008` (l.57), `SMEAR_CAP = 0.16` (l.58), `glare = 1.0` (l.61), `glare_threshold = 1.5` (l.62), `HALO = 0.22` (l.63), `GHOSTS = 0.035` (l.64), `GHOST_FLOOR = 0.08` (l.66), `CROWD = 400.0` (l.69), `knee = 0.72` (l.73), `toe = 0.008` (l.76).
- Cadenas GLSL: `HEADER` (l.105, `#version 450`); `METER` (l.106-129, medidor centrado sobre rejilla); `IRIS` (l.130-166, iris automático y escritura de `exposure_image` 1×1 para la lente); `SMEAR` (l.167-186, estela de la columna); `SPREAD` (l.193-212, desenfoque lateral de la estela); `BRIGHT` (l.213-237, umbral de luz para el halo); `GLARE_MEAN` (l.240-261, media del halo); `BLUR` (l.262-292, desenfoque del halo); `GRADE` (l.293-345, exposición, estela, halo, balance de blancos y rodilla de vídeo; sustituye al tonemapper, l.27-29 del cabecero).
- Entrada de compilación: `setup()` (l.351-366): compila las ocho etapas (l.355-365) y lanza `push_error` si una falla. Buffer de muestras (l.366).
- Consumidor de su salida: `exposure_texture` (Texture2DRD, l.84, asignado a `texture_rd_rid` en l.375) lo lee lens.gdshader como `gain_map`.
- Nota: la cabecera y el nombre de las etapas cubren el propósito. El cuerpo de cada GLSL no se leyó (ver §12).

### 5.2 motion_blur_effect.gd (190 líneas; CompositorEffect, POST_TRANSPARENT)
- Cabecera (l.1-16): desenfoque por giro de cámara, como el obturador de 1/60 s de la cámara. Calcula el giro entre el frame anterior y el actual, sin profundidad (l.4-13).
- Constantes: `SHUTTER = 1/60` (l.17), `MAX_PIXELS = 48` (l.20), `samples = 8` (l.15; lo fija el preset, "motion_blur" 0/6/8/12 en graphics_presets.gd:201, 211, 221 y 0 en 191, 233).
- Cadenas GLSL: `COPY` (l.39-50), `SOURCE` (l.51-81; muestras a lo largo de la estela, con `r0`, `r1`, `r2` = matriz del giro, push constant `shutter`, `samples`, `max_px`).
- Compilación y despacho: l.91-94 (RDShaderSource), l.166 y l.189 (`compute_list_dispatch`).
- Lo usa presentation_rig.gd:22 (`blur_effect`), y se inserta en el compositor (presentation_rig.gd:64-66).

---

## 6. Inventario de archivos leídos

### 6.1 Los 34 archivos de shader (leídos enteros con cat -n)

| Archivo | Líneas | Qué hace |
|---|---|---|
| game/enemies/locust/shaders/echo_field.gdshader | 126 | Fondo negro del eco, con grano, temblor y haz de antorcha. |
| game/enemies/locust/shaders/echo_points.gdshader | 135 | Granos de luz del eco en un buffer en anillo; cinco nubes con un shader. |
| game/enemies/locust/shaders/echo_self.gdshader | 25 | Contorno del propio cuerpo del Locust, aditivo. |
| game/enemies/lurker/ceiling_dust.gdshader | 107 | Motas y hilos de polvo que dispersan la luz (light() propia). |
| game/enemies/lurker/ceiling_dust_veil.gdshader | 21 | Velo de polvo en niebla volumétrica (fog). |
| game/enemies/lurker/lurker_darkness.gdshader | 138 | Tinta y vapor del Lurker: ray marching sobre una esfera. |
| game/intro/tv_screen.gdshader | 101 | Tubo CRT de la apertura y de los televisores. |
| game/presentation/materials/office/ceiling_halo.gdshader | 19 | Halo aditivo en el techo, alrededor de cada fluorescente. |
| game/presentation/materials/office/ceiling_tile.gdshader | 60 | Placa acústica de oficina con variación por celda. |
| game/presentation/shaders/analog.gdshader | 286 | Filtro de cinta VHS y cámara de consumo (canvas, SCREEN_TEXTURE). |
| game/presentation/shaders/blood.gdshader | 62 | Mancha de sangre del atlas 4×4, con carrera y absorción. |
| game/presentation/shaders/blood_pool.gdshader | 87 | Charco de sangre que se extiende con la raíz cúbica del tiempo. |
| game/presentation/shaders/blood_worn.gdshader | 60 | Sangre empapada alrededor de las heridas de la ropa y la piel. |
| game/presentation/shaders/carpet.gdshader | 82 | Moqueta de hotel con medallones y desgaste. |
| game/presentation/shaders/ceiling.gdshader | 34 | Techo de gotelé con manchas. |
| game/presentation/shaders/curtain.gdshader | 27 | Cortina de terciopelo con balanceo por TIME. |
| game/presentation/shaders/exit_panel.gdshader | 67 | Rótulo de salida: diodos y letra grabada que dispersa la luz. |
| game/presentation/shaders/finish.gdshader | 85 | Acabados de mobiliario (cepillado, tejido, arrugado, hoja). |
| game/presentation/shaders/image_maps.gdshaderinc | 112 | Include de escaneos (albedo, normal, orm) y sus modos. |
| game/presentation/shaders/lens.gdshader | 92 | Óptica y sensor de la videocámara (canvas, SCREEN_TEXTURE). |
| game/presentation/shaders/lens_blood.gdshaderinc | 196 | Include de gotas de sangre sobre el cristal. |
| game/presentation/shaders/painting.gdshader | 30 | Cuadro de paisaje procedural bajo barniz. |
| game/presentation/shaders/surface.gdshaderinc | 205 | Include común: ruido, cara, sala, niveles de detalle y macro de normal. |
| game/presentation/shaders/tile.gdshader | 89 | Baldosa vidriada o vinilo con junta y desgaste. |
| game/presentation/shaders/typewriter_ink.gdshader | 32 | Tinta de cinta de máquina de escribir (canvas). |
| game/presentation/shaders/venetian_blind.gdshader | 17 | Persiana por descarte de píxeles. |
| game/presentation/shaders/wallpaper.gdshader | 84 | Papel pintado envejecido. |
| game/presentation/shaders/wired_glass.gdshader | 30 | Vidrio armado con malla de alambre. |
| game/presentation/shaders/wood.gdshader | 4 | Envoltorio: incluye wood.gdshaderinc. |
| game/presentation/shaders/wood.gdshaderinc | 142 | Madera lacada (cuerpo común; barniz opcional). |
| game/presentation/shaders/wood_lacquer.gdshader | 5 | Envoltorio de wood con LACQUER_COAT (barniz como capa propia). |
| game/ui/shaders/signal_wash.gdshader | 51 | Imagen de aviso con señal que se pierde (canvas, interfaz). |
| game/ui/shaders/tape_noise.gdshader | 20 | Estática de cinta para transiciones (canvas, interfaz). |
| tools/dev/lens_blood_look.gdshader | 11 | Herramienta: gotas de lente sobre fondo neutro. |

### 6.2 Consumidores leídos (grep por línea y tramos; no leídos por completo)
- GD: game/enemies/locust/echo_view.gd (preset de nubes, `set_shader_parameter` 65 llamadas, reloj y rng en 185-187, 314, 322, 712-765, 905-909, 986-994, 1138-1147); game/enemies/locust/locust_player.gd (165 drive, 233 echo.advance); game/enemies/locust/hotel_locust.gd (1563 `_physics_process`, 1573 driver.drive); game/app/observer_view.gd (428 `_process`, 457 advance); game/enemies/lurker/ceiling_dust.gd (18, 21, 67-68, 137-200, 359-361, 386-389, 404); game/enemies/lurker/lurker_visual.gd (12, 136-150, 164, 196, 204, 226-231, 251-274, 300, 356-363); game/app/blood.gd (28-30, 70-72, 98-99, 116-124, 191-272, 317-356, 392-398, 420-431, 440-453, 521-542); game/player/avatars/avatar_visual.gd (386, 419-421); game/intro/intro_sequence.gd (22, 83, 99, 120, 228, 241, 243-244, 327-383, 400, 576-580); game/world/interactables/hotel_television.gd (18, 78-84, 140-152); game/world/office/office_geometry.gd (76-88, 174, 257, 267-274, 587-599, 855-894, 1329-1344, 1613-1621, 2347, 2434, 2463-2476); game/world/hotel/hotel_geometry.gd (414-421, 452-470, 596-606, 637-641, 1857-1886, 2580-2594, 2622, 2711-2718, 3011); game/world/hotel/mouldings.gd (19); game/app/presentation_rig.gd (22, 29-31, 50-66, 85, 104-146, 177-178, 285-310, 369-400); game/presentation/camera/camcorder_effect.gd (1-33, 34-104, 105-345 cadenas GLSL, 351-366, 375, 452-460); game/presentation/camera/motion_blur_effect.gd (1-190); game/presentation/camcorder_look.gd (31-47); game/presentation/graphics_presets.gd (20-27, 183-235, 264-290); game/app/death_tape.gd (446-450, 566); game/app/hotel_main.gd (1461, 1774-1815, 2099, 2115); game/ui/hotel_ui.gd (6, 428, 2059, 2134-2139, 2174-2176, 2203, 2210, 2229, 2333, 2341); game/ui/rules_screen.gd (17, 74, 98, 113-114); game/ui/hotel_form.gd (22); game/ui/ruled_paper.gd (10); game/services/settings_service.gd (90, 153, 157); game/player/hotel_player.gd (377).
- Escenas y materiales: game/presentation/presentation.tscn (3-38); 71 `.tres` que referencian un `.gdshader` (materiales en game/presentation/materials/ y office/); tools/workbenches/module_gallery.tscn:43.
- Herramientas: tools/dev/check_shaders.gd (68 líneas, completo); tools/dev/lens_blood_look.gd (24-39); tools/dev/wood_look.gd (18, 61); tools/textures/bake_blood.py (1-43); tools/textures/make_exit_sign.py (1-99); tools/textures/bake_lite_maps.gd (111, 167); tools/textures/ingest_pbr.py (citado en image_maps.gdshaderinc:2); tools/art/lurker/bake_ink_noise.gd (1-27); tools/art/lurker/scene.py (135, docstring); tools/verify.ps1 (108-115, 145); tools/trailer3d/web/engine/looks.js (1-3, port de analog), screens.js (1, port de tv_screen), kit.js (228, port de exit_panel), materials.js (102, port de surface), shots/versus.js (2, port de echo_points).
- Pruebas: ver §10.

---

## 7. Clases y nodos de Godot que usa esta parte (con apariciones)

Contadores sobre `game/` (solo `.gd` salvo que se indique). Son apariciones de texto, no instancias.

| Clase / API | Apariciones | Dónde se concentra | Para el port |
|---|---|---|---|
| `set_shader_parameter` | 197 (.gd) | echo_view 65, hotel_geometry 16, office_geometry 15, presentation_rig 20, intro_sequence 12, blood 13, lurker_visual 13, hotel_ui 6, ceiling_dust 7, rules_screen 2, avatar_visual 3 | Es el canal de datos de GD a los shaders. Cada parámetro hay que mapearlo a un Material Instance o a un parámetro de Material Parameter Collection. |
| `ShaderMaterial` | 75 (.gd) + 73 (`type="ShaderMaterial"` en .tres) | echo_view 21, office_geometry 11, blood 7, lurker_visual 4, intro_sequence 4, hotel_geometry 6, hotel_ui 6 | Materiales. |
| `Shader` (`type="Shader"`) | 73 (.tres) + 2 (.gd) | Un recurso por archivo `.gdshader` | Equivalente: un Material Function o un Material base. |
| `MultiMeshInstance3D` | 31 | hotel/office geometría, blood, echo | Instanced Static Mesh / Niagara. |
| `MultiMesh` | 41 | blood 6, office_geometry 5, hotel_geometry 8, echo_view 6 | Idem. |
| `set_instance_custom_data` | 11 (`use_custom_data` 7) | blood 3, hotel_geometry 1, office_geometry 2 | Atributo por instancia (INSTANCE_CUSTOM). |
| `set_instance_transform` | 26 | hotel_geometry, office_geometry, blood | Transform por instancia. |
| `set_instance_color` | 1 | office_geometry.gd:1344 | Color por instancia (COLOR). |
| `MeshInstance3D` | 127 | Todo el juego | Static Mesh Component. |
| `ArrayMesh` | 345 | Geometría generada en código (sin desglosar) | Procedural Mesh / Geometry Script. |
| `SurfaceTool` | 23 | Geometría | Idem. |
| `BoxMesh` / `QuadMesh` / `PlaneMesh` / `SphereMesh` | 29 / 19 / 8 / 3 | Geometría primitiva | Static Mesh primitives. |
| `ColorRect` (overlay de pantalla) | 18 (.gd) + 3 (.tscn/.tres) | presentation.tscn (Lens y Analog), hotel_ui | Post-process o Widget con material. |
| `CanvasLayer` | 8 | presentation.tscn (layer 2, 3, 5), hotel_ui | Orden de la UI y los postprocesos. |
| `TextureRect` | 14 | hotel_ui y menús | Widgets. |
| `SubViewport` | 27 | intro (TV), marks_view (huella de la cinta), capturas | Render Target. |
| `ImageTexture` | 24 | blot de lurker, texturas de decal | Texture2D generada en ejecución. |
| `NoiseTexture3D` | 2 | ceiling_dust.gd:166 | Textura 3D de ruido. |
| `FogVolume` / `FogMaterial` | 5 / 1 | ceiling_dust.gd:181-200 | Volumetric Fog con material. |
| `WorldEnvironment` / `Environment` | 6 / 15 | presentation.tscn, hotel_environment.tres | Post-process volume y exposición. |
| `CompositorEffect` / `Compositor` | 4 / 2 | camcorder_effect, motion_blur_effect, presentation_rig.gd:22-31, 56-66 | Post-process material o compute en Unreal. |
| `RenderingDevice` / `RDShaderSource` / `Texture2DRD` | 36 / 2 / 1 | camcorder_effect.gd, motion_blur_effect.gd | Compute pass. |
| `RenderingServer` | 84 (16 consultas de `get_current_rendering_method`, 1 `global_shader_parameter_set`) | Todo el juego | Mapa de renderer y parámetros globales. |
| `OmniLight3D` / `ReflectionProbe` / `Decal` | 50 / 6 / 7 | Iluminación de sala | Luces y sondas (afectan a los shaders por la luz que llega). |
| `Tween` / `create_tween` | 46 / 26 | Animación de parámetros (intro_sequence 424-426, hotel_ui 2135-2139) | Timelines. |
| `Time.get_ticks_msec` / `Time.get_ticks_usec` | 25 / 26 | echo_view.gd:907, camcorder_effect.gd:459 | Reloj de pared. |
| `Engine.get_physics_frames` | 8 | lurker_visual.gd:251-268 | Frames de física. |
| `_physics_process` | 18 | hotel_locust.gd:1563 (drive del eco), otros | Tick de física. |
| `_process` | 25 | blood.gd:440, intro_sequence.gd:243, lurker_visual.gd:300, hotel_geometry.gd:2622, hotel_ui.gd:2203, office_geometry.gd:2434, hotel_main.gd:1774, observer_view.gd:428 | Tick de frame. |
| `RandomNumberGenerator` | 152 | ceiling_dust, blood, echo_view, intro_sequence, office_geometry | Azar con semilla o sin ella. |
| `randf` | 156 | Todo el juego | Azar global, no reproducible. |
| `PackedVector3Array` / `PackedFloat32Array` | 122 / 33 | Arreglos de uniformes (wound_at, roots) | Arreglos de parámetros. |
| `load` / `preload` | 113 / 564 (todo el juego) | Carga de shaders y materiales | Asset references. |
| `DisplayServer` / `headless` | en check_shaders.gd | Compilación de shaders | Cook / shader compile. |

---

## 8. Constantes y cifras que definen cómo se ve o se siente

### 8.1 Presets gráficos (todo el efecto de calidad depende de esto)
- `NAMES` = Bajo, Medio, Alto, Ultra, Muy bajo (graphics_presets.gd:20). `PRESETS` de la línea 183, con cinco bloques en orden (185, 195, 205, 215, 227; el primero es Bajo, el último Muy bajo; ver test de Bajo en echo_test.gd:472 y de Muy bajo en hotel_test.gd:508).
- `surface_detail` por preset: Bajo **2.0** (l.191), Medio **3.0** (l.201), Alto **4.0** (l.211), Ultra **5.0** (l.221), Muy bajo **0.0** (l.233). Valor por defecto del proyecto **4.0** (project.godot:66-68).
- `chroma_taps` por preset: Bajo **4** (l.191), Medio 7 (l.201), Alto 7 (l.211), Ultra 7 (l.221), Muy bajo **2** (l.233).
- `tape_lite` (lectura de 3 muestras): true solo en Muy bajo (l.227).
- `motion_blur` por preset: 0 (Bajo), 6 (Medio), 8 (Alto), 12 (Ultra), 0 (Muy bajo) (l.191, 201, 211, 221, 233).
- `echo.halo`: 0 en Bajo, Medio, Alto y Muy bajo; **1.0** en Ultra (l.192, 202, 212, 222, 235).
- `echo.points` (granos del eco): 12000 (Bajo), 24000 (Medio), 46000 (Alto), 64000 (Ultra), 12000 (Muy bajo) (l.192, 202, 212, 222, 235).
- `echo.grain`: 2.0 (Bajo), 1.0 (Medio), 1.0 (Alto), 0.8 (Ultra), 2.0 (Muy bajo) (l.192, 202, 212, 222, 235).
- Renderer: `renderer/rendering_method.mobile = "gl_compatibility"` (project.godot:57). El renderer de escritorio no se fija en project.godot; el valor por defecto de Godot 4 es Forward+ (**no comprobado en el repo**). El jugador puede cambiarlo con `user://renderer.cfg` (settings_service.gd:90, 153).

### 8.2 Cifras por shader (ruta:línea)
- **echo_field** (`game/enemies/locust/shaders/echo_field.gdshader`): `presence` 0.006 (l.30); jitter 0.0016 y 240 líneas (l.59); tono de muro (0.74, 0.79, 0.82) y rojo (1.35, 0.05, 0.02) (l.80); atenuación `1 + d*0.35` (l.81); grano 0.010 (l.122); haz: 24 pasos (l.42), alcance 20 (l.41), `0.03` (l.110), `0.45 + 0.55*h` (l.110), gamma 0.4545 (l.115).
- **echo_points** (`echo_points.gdshader`): `wave_speed` 42 (l.19); `age_limit` 5 (l.22); `point_scale` 0.004 (l.25); `point_min` 0.010 (l.26); `point_max` 0.085 (l.27); `through` 0.35 (l.30); `steady_fade` 12 a 20 (l.33-34); `residue` 0.11 (l.44); `flare` 1.8 (l.45); `exp(-gap²/2.5)` (l.71); `radius * 0.8` del destello (l.95); `strength <= 0.002` apaga el grano (l.98); `halo*2` (l.99, 105, 107: 0.35 y 0.3); `smoothstep(0.15, 0.9, from_eye - wall)` (l.126).
- **echo_self** (`echo_self.gdshader`): `slice_step` 0.16 (l.15); `pow(rim, 2)` (l.19); `pow(slices, 6)` (l.21); `0.85`, `0.22`, `0.035` (l.22); colores (0.82, 0.86, 0.9) y (1.3, 0.10, 0.06) (l.23).
- **ceiling_dust** (`ceiling_dust.gdshader`): `drift` 0.03 (l.32); `speck` 0.003-0.008 (l.33); `min_pixels` 2.5 (l.26); 720 líneas (l.82); `smoothstep(0.2, focus, dist)` (l.82); `focus` 1.2 (l.38); velo: `0.06` (l.101, `near` 0.12-0.4 l.101); `0.06` (l.100); borde `smoothstep(0.7, 1.0, far)` (l.65); parpadeo `6 + spark*14` (l.95); hash entero de 1664525u, 22695477u, 2891336453u, 1013904223u, 0x7feb352d, 0x846ca68b (l.50-55); `sway` 0.12 (l.58); `/PI` (l.106).
- **ceiling_dust_veil**: `(1.6, 0.5, 1.6)` (l.15), `TIME*0.06` (l.15), `smoothstep(0.45, 0.85)` (l.16), `0.5*min(SIZE)` (l.17), `smoothstep(0.5, 1.4)` (l.18).
- **lurker_darkness**: `thickness` 0.34 (l.18); `radius` 0.8 (l.19); `density` 40 (l.20); `face_clear` 0.17 (l.25); `FILM` 0.1 (l.38); 9 segmentos (l.30, 74); `noise(q)` con 3.0 (l.67); `p*6` y `p*14` (l.71-72); `1.0 → 0.84` (l.78); `1.7 → 1.15` (l.79); `1.9 → 1.15` (l.83); `0.48 → 0.56` (l.83); `0.8` (l.87); `widen` con 0.07, 1.3, 0.05, 2.3 (l.127); `0.16` bleed (l.120); 10 pasos (l.124).
- **tv_screen**: 1024×768 (l.51); `0.985 - unstable*0.06` (l.60); 240 líneas (l.58); 260×240 nieve (l.68); 480 entrelazado (l.77); 1100 franjas de rejilla (l.80); `mix(1, grille*1.35, 0.45)` (l.82); viñeta 0.16-0.5 y 0.75 (l.85); 0.012 refracción de grieta (l.55); línea de apertura `max(0.004, opened*0.08 + 0.003)` y `*3` (l.92).
- **ceiling_halo**: `inner` (0.6, 0.3) (l.10); `reach` 1.2 (l.11); `fall²` (l.18); `HALO_REACH` 1.8 y `HALO_ENERGY` 0.22 en office_geometry (l.172, 174).
- **analog**: `vhs` 0.18 (l.6); `grain` 0.12 (l.7); `chromatic` 0.08 (l.8); `scanlines` 0.35 (l.9); `tint` (1.02, 1.0, 0.9) (l.11); `vignette` 0.45 (l.12); `chroma_taps` 7 (l.48); `wobble` 0.0022 y 0.00035 (l.99); `38`, `190` (l.99); `band_pos` `fract(t*0.043)` (l.100); banda `0.06` (l.101); jitter 0.004 (l.102); cabeza 0.035 (l.103); tear 0.012 (l.104); `soft = 1 + vhs*2.5` (l.127); `chroma_width = px*(1.5 + vhs*9)` (l.131); `chroma_delay = px*vhs*3` (l.132); `spacing = 6/(taps - 1)` (l.147); `0.35*vhs` (l.144); 240 líneas (l.179, 213, 229); `chance = vhs*0.0012 + tape_hit*0.03 + tape_fray*0.02` (l.181); `0.33` (l.193); `0.02 + 0.13*h` span (l.188); `0.92, 0.92, 0.9` (l.196); grano `1731, 977`, `23` (l.209); `0.08 + dark*0.14` (l.211); `2π*240` (l.213); viñeta `0.12-0.6` (l.218); `0.03*vhs` (l.219); `0.05-0.42` enclosure (l.220); `0.96 - loss*0.05` (l.231); `260×240` (l.238); `2.0`, `1.9`, `0.62..0.7`, `0.16 + 0.95 bars` (l.252-253); 0.85 (l.234).
- **blood** (`blood.gdshader`): fade `0.05` (l.48); `run` 0.03 (l.49); offset `0.002 + 0.0025*d` (l.36); `ALPHA` 0.7/0.97/0.9 (l.57); `ROUGHNESS` 0.2/0.09/0.46 (l.58); `SPECULAR` 0.6/0.28 (l.59); `NORMAL_MAP_DEPTH` 1.4/0.2 (l.61); atlas 4×4 (l.44).
- **blood_pool** (`blood_pool.gdshader`): `span` 1.5 (l.18; blood.gd:70); `radius` 0.42 (l.19); `spread_time` 30 (l.21; blood.gd:72); `^0.3333` (l.63); `lobes` 0.72 + 0.5 + 0.16 (l.55); `edge - 0.015` (l.56); `ragged` 0.02-0.045 (l.57); `0.008-0.03` (l.66); bead `0.014` y `0.009`, `0.35` (l.71); `0.012` pendiente (l.76); `1.5*spread` (l.81); `ROUGHNESS` 0.07/0.3/0.46 (l.85).
- **blood_worn** (`blood_worn.gdshader`): `reach` 0.17 (l.18); `spread_time` 3.5 (l.19); `pow 0.5` (l.51); `0.25 + 0.75*` (l.51); `from.y` 0.5 / 1.5 (l.50); `0.05` y `0.02` (l.52); `0.94` (l.57); `0.5/0.22` (l.58); `0.45` (l.59); offset 0.0015 (l.29).
- **carpet**: `tile_size` 0.62 (l.10); `fibre_bleed` 0.035 (l.14); octágono 0.32 y `0.022/0.01` (l.37); cruz `0.03/0.015` (l.39); celosía `0.9` (l.40); esquina `0.1/0.08` (l.41); `0.84 + pile*0.22 + (brush - 0.5)*0.14` (l.60); `traffic` `0.45/0.8` y `0.22` (l.62); `12.566` (l.67); `0.1` (l.69); `stain` `0.7/0.76` (l.72); `0.35` (l.73); `0.002` y `0.0006` (l.79).
- **ceiling**: `stains` 0.6 (l.8); `damp` `0.6/0.72` (l.24); `edge` `0.015` (l.25); `0.55` (l.26); `0.25` (l.27); `0.004` (l.32).
- **curtain**: `0.7` (l.11); `8` (l.11); `0.035` (l.11); `31`, `1.3`, `0.8` (l.17); `90, 30` (l.18); `0.3` (l.19); `0.35 + folds*0.65` (l.20); `0.9 + nap*0.12 + dust*0.3` (l.21); `RIM` 0.7 (l.24); `RIM_TINT` 0.7 (l.25); `0.02` y `0.0004` (l.26).
- **exit_panel**: `energy` 5 (l.22); `diodes` 5 (l.24); `0.0006 + depth²*0.07` (l.46); `0.00004`, `exp(-depth*90)` (l.47); `exp(-depth*2.6)` (l.49); `guided` 0.62 → 1 con `1.1` (l.51); `0.7/2.1` (l.53); `0.02/0.5/0.8/0.7/1.6` (l.55-57); `lit*0.55` (l.62); `pow 3` (l.64); `sheen` 0.45 (l.28); `sheet` 0.09 (l.27); `1.4` (l.66).
- **finish**: `roughness` 0.7 (l.9); `0.5` specular (l.11); `finish` (l.12); `detail_scale` 1 (l.13); `1.3` (l.33); `0.2`/`0.0002` (l.42); `weave` `180`, `6.2831` (l.44-45); `400` (l.46); altura de crumple `0.012` (l.53); `300` (l.51); `0.0008`, `0.003` (l.57); `0.02` (l.59); `0.6-0.9` dirt, `0.35` (l.69-71); `0.25` (l.77); `0.02..1` (l.77); `RIM_TINT` 0.6 (l.80); `BACKLIGHT` (l.82).
- **lens**: `barrel` 0.05 (l.13); `scale` 0.8 (l.14); `chromatic` 0.3 (l.16); `chromatic*0.004` (l.56); `480` líneas (l.57); `*0.9` detail (l.68); `1.5 px` (l.66); `0.55` (l.73); `0.55..1` y `0.35` (l.74); `TIME*30` (l.81); `0.06 y 0.012` (l.86); `0.25` (l.87); `2.0` (l.88).
- **painting**: `1.6` (l.16); `1.28` (l.17); `50` (l.15); `0.8` (l.15); `9`, `4` (l.20); `1.1` (l.24); `60` (l.25); `0.15`, `0.02` (l.25-26); `0.45 + strokes*0.2` (l.28); `0.001` y `0.0003` (l.29).
- **tile**: `tile_size` 0.3 (l.9); `grout_width` 0.0035 (l.10); `checker` 0.35 (l.11); `grime` 0.6 (l.12); `tile_count` 8 (l.14); `specular_level` 0.42 (l.16); `tilt` 0.045 (l.27); `0.85/0.15` (l.62); `0.7` (l.62); `26` y `17` (l.53); `150`, `0.86` chip (l.54); `0.86` crack (l.69); `0.34 + dirt*0.3 + lane*0.22` (l.77).
- **typewriter_ink**: `grain` 0.5 (l.7); `0.85` (l.28); `(0.012, 0.05)` (l.29); `0.45 + 0.55*weave` (l.30); `0.72..1` (l.30).
- **venetian_blind**: `pitch` 0.022 (l.6); `open` 0.3 (l.7); `drop` 1 (l.8); `height` 1.7 (l.9); `0.6` rugosidad (l.16).
- **wallpaper**: `roll_width` 0.53 (l.10); `motif_height` 0.46 (l.11); `print_strength` 0.55 (l.12); `stains` 0.55 (l.13); `grime` 0.5 (l.14); `ink_bleed` 0.03 (l.16); `ogee 0.23/0.2, 0.25, 6.2831` (l.48); `dots 0.06/0.04` (l.49); `stripe 0.035/0.02, 0.6` (l.50); `stain 0.62 → 0.7` (l.69); `top 1.6..3.2` (l.68); `low 1.4..0.9` (l.73); `hand 1.15` (l.74); `0.9` rugosidad (l.25); `0.012` seam (l.63).
- **wired_glass**: `glass_color` alfa 0.16 (l.10); `wire_color` alfa 0.75 (l.11); `pitch` 0.025 (l.12); `wire` 0.06 (l.13); `0.8` spec (l.29); `0.5` metal (l.28).
- **wood** (`wood.gdshaderinc`): `ring_density` 22 (l.12); `varnish` 0.65 (l.13); `lacquer_edge` 0.06 (l.17); `scuffs` 0.5 (l.18); `hash13` tabla `5.0, 3.0` (l.64); `7.1, 5.3` (l.64); `0.6, 7.0` warp (l.89); `0.12` (l.90); `8, 420` poros (l.92); `0.25` poros (l.94); `0.93` arañazo (l.110); `2.2` polvo (l.111); `0.75/0.28` lacquer (l.118); `0.5` spec (l.120); `0.04 + 0.96*pow(...,5)` (l.131); `0.6 + 0.4*dull` (l.135); `0.0004`, `0.0005` altura (l.137); `0.012` groove (l.76); `0.36`, `0.5`, `0.025` puertas (l.80); `2.24 × 2.58 m` (comentario l.104).
- **signal_wash**: `TIME*24` (l.21); `24`, `5`, `0.022` (l.24); `71`, `13`, `0.009` (l.24); `22` (l.26); `0.8`, `0.14` (l.27); `0.025` (l.29); `9.0` (l.31); pesos 0.28, 0.18, 0.1, 0.08 (l.33-36); `2.0`, `3.0` (l.40-41); `0.85, 0.85, 0.82` (l.42); `1.2`, `0.2`, `0.6` (l.43-44); `0.08`, `0.25`, `0.3` (l.47); `1.8` (l.48); `12`, `6` (l.48).
- **tape_noise**: `2` (l.13), `TIME*30` (l.14), `3` (l.16), `0.82` (l.17), `0.75` y `0.35` (l.18), `0.55 + 0.45*snow` (l.19).
- **lens_blood**: `blur` 0.007 (l.81); tamaños de gota (l.62): 0.098-0.13, 0.06-0.082, 0.03-0.05; `lens_lands` 0.035, 0.3, 0.045 (l.69); pesos `(size - 0.03)/0.1` (l.89); `sags` 0.24/0.34 (l.116); `gives` 0.56/0.66 (l.117); `held` 0.06 + 0.2 (l.119); `pace` 2.6 + 1.8 (l.122); `most` 0.22/0.3, 1.6/2.0/0.9 (l.123); `head` (l.131); `wave` 2..7, `0.26/turns` (l.105-109); 16 motas (l.167); `speck` 0.0025 + 0.0075 (l.174); `through` 3.2, 9.5, 10.5 (l.193); `own` (0.54, 0.02, 0.014), 0.72/1.9 (l.194); `3.5` (l.194); `0.13 + 0.95*lit` (l.194).
- **surface.gdshaderinc**: `vec2(0.12)` cuadro de sala (l.121-122); 10000 (l.119); 3.2, 0.4 (l.128); 6 (l.130); 2.5 (l.131); 0.55 (l.141); 0.22 (l.142); 0.72, 0.78, 0.86, 0.6, 0.45, 0.5, 0.5, 0.92 (l.144-146, 0.6-0.5); `plane_swell` 1.9, 31, 0.012, 0.7, 5, 0.02 (l.164); `baked_albedo` 0.3 (l.189); `fine_noise` 2.5 (l.64); `finest_surface` 4.5 (l.157); `baked_surface` 0.5 (l.182).
- **image_maps**: `LUMA` (l.36); `mip 12` (l.78); `map_no_tile` 2.5 (l.57); `8`, `0.7`, `3, 7`, `0.25, 0.75` (l.58-62).
- **camcorder_effect** (compute): ver §5.1.
- **motion_blur_effect** (compute): ver §5.2.

### 8.3 Escenas y otras cifras que influyen en lo que se ve
- `presentation.tscn`: CanvasLayer `Lens` layer 2 (l.17-18), `Camcorder` layer 3 (l.37-38), `Analog` layer 5 (l.27-28).
- `lurker_visual.gd`: `SPILL` 1.7 (l.105); `LAYER` 4 (l.15); `SphereMesh` con `radial_segments` 24 y `rings` 12 (l.14-18).
- `echo_view.gd`: `CLICK_RATE` 2.0 (l.37), `CLICK_JITTER` 0.22 (l.42), `WAVE_SPEED` 16.0 (l.48), `BODY_FADE` 0.75 (l.62), `PUFF_SPEED` 4.5 (l.70), `PUFF_LIFE` 2.2 (l.71), `PUFF_BELL` 0.22 (l.88), `PUFF_GAIN` 1.8 (l.90), `PUFF_PIXELS` 3.2 (l.91), `PUFF_WHITE` 2.2 (l.92), `PUFF_TWINKLE` 0.7 (l.93), `FIND_LIFE` 3.2 (l.124), `CONTACT_LIFE` 1.6 (l.126), `SHRIEK_RISE` 6.0 (l.129), `SHRIEK_FALL` 0.55 (l.130), `LANDMARK_NEAR` 14 (l.132), `LANDMARK_REACH` 28 (l.133), `DOORWAY_HIGH` 2.6 (l.140), `POINT_PIXELS` 2.0 (l.143), `PRESENCE` 0.006 (l.148), `PRESENCE_CALM` 0.016 (l.149), `FRAME_MEMORY` 5.0 (l.163), `FRAME_PIXELS` 2.6 (l.164), `GUIDE_HEIGHT` 0.08 (l.230), `GUIDE_SCATTER` 0.06 (l.231), `GUIDE_FLOW` 9.0 (l.234), `GUIDE_BLUE` (0.02, 0.22, 1.6) (l.240), `GUIDE_YELLOW` (1.5, 1.05, 0.03) (l.241), `COMPAT_LIFT` 1.6 (l.362).
- `ceiling_dust.gd`: `THREAD_GRAINS` 600 (l.36), `PUFFS` 40 (l.37), `FLAKES` 8 (l.38), `CRUMBS` 6 (l.39), `MAX_VEILS` 3 (l.43), `VEIL_DENSITY` 3.0 (l.45), `VEIL_SIZE` (1.4, 2.2, 1.4) (l.46), `VEIL_LIFE` 9.0 (l.47), `VEIL_GLOW` 16 (l.51), `VEIL_TORCH` 0.35 (l.52), `DUST_COLOUR` (0.86, 0.83, 0.76) (l.31).
- `blood.gd`: `POOL_SPAN` 1.5 (l.70), `POOL_TIME` 30 (l.72), `rng.seed = scene.seed ^ 0xb100d` (l.99), `POOL` (l.29).
- `intro_sequence.gd`: `rng.seed = 1987` (l.99).

---

## 9. Orden de ejecución, física y azar

### 9.1 Reloj de cada shader (qué fija el ritmo)
- **TIME (reloj del motor de render)**: analog (93), lens (81), tv_screen (48), signal_wash (21, 24, 29), tape_noise (14), curtain (11), ceiling_dust (58-59, 95), ceiling_dust_veil (15), lurker_darkness (120, 127, 133). Cada frame de render, a la velocidad que haga la máquina. No es el reloj del juego.
- **`now`** (reloj propio del eco, GD): echo_field (24), echo_points (18), echo_self (10). Se fija por GD en echo_view.gd:993 (`material.set_shader_parameter("now", clock)`).
- **`clock` de la sangre** (blood.gdshader:17): fijado en blood.gd:452 por frame. Si la captura del evento está activa, usa `level.execution.time` (blood.gd:449); si no, `+ delta` mientras juega (blood.gd:450).
- **`age` de la piscina** (blood_pool): `clock - pool_from` (blood.gd:453).
- **`lens_blood`** (lens_blood.gdshaderinc:24): segundos desde la primera gota; GD lo fija en death_tape.gd:446-450 y lo reinicia a 0 en death_tape.gd:566 y hotel_main.gd:1461.
- **`wound_age`** (blood_worn): segundos desde la herida (avatar_visual.gd:421), calculados desde `since` (avatar_visual.gd:392-394).
- **`wash` y `amount`** (UI): tweens de GD (hotel_ui.gd:2135-2139, rules_screen.gd:113-114, intro_sequence.gd:241).
- **`crack_level`, `image_amount`, `static_amount`, `unstable`, `flicker`, `flash`** (tv_screen): los escribe intro_sequence.gd:228-381 y hotel_television.gd:140-152 cada frame o con tween.
- **`signal_loss`, `vhs`, `enclosure`, `tape_hit`, `tape_fray`, `marked`, `chroma_taps`, `lite`, `vignette`, `grain`, `chromatic`, `tint`** (analog): los escribe presentation_rig.gd:286-400 por frame.
- **`field_shift`** (lens): calculado en presentation_rig.gd:116-131 a partir del giro de cámara y `FIELD_TIME = 1/60` (l.104).

### 9.2 Quién llama a qué (orden de ejecución)
- **Eco del Locust (hotel)**: `hotel_locust.gd:1563 _physics_process` → `driver.drive(delta)` (l.1573) → `locust_player.gd:165 drive` → `echo.advance(delta, hunting)` (locust_player.gd:233) → `echo_view.gd:712-717` (`clock += delta`) → `click()` (l.729, 735) → `bloom_contacts()` (l.760, 905-909).
  - Es decir: el reloj del eco avanza en el tick de física.
- **Eco del observador**: `observer_view.gd:428 _process` → `echo.advance(delta, ...)` (l.457). Reloj en `_process`.
- **Eco, puffs**: `bloom_contacts` usa `Time.get_ticks_msec()` (echo_view.gd:907) y compara con `mark.time` de `driver.heard`. Mezcla el reloj de pared con el reloj de simulación (un riesgo de desincronía si el juego se pausa o se acelera).
- **Presentación del juego**: `hotel_main.gd:1774 _process` → `step_frame` (1779) → `update_fields` (1800; `presentation_rig.gd:116`) y `update_screen_cues` (1815; `presentation_rig.gd:369`).
- **Sangre**: `blood.gd:440 _process`. La lógica de caída y de salpicadura va con `rng` (blood.gd:98-99, 116-272; con semilla `int(scene.seed) ^ 0xb100d`), y usa **raycasts de física** para posar las manchas (`PhysicsDirectSpaceState3D`, blood.gd:242-272).
- **Lurker**: `lurker_visual.gd:251-274 present()` usa `Engine.get_physics_frames()` y `get_physics_interpolation_fraction()` (interpolación de física). `lurker_visual.gd:300 _process(delta)` suaviza el movimiento.
- **Cámara de la intro**: `intro_sequence.gd:243 _process`; el `rng` (seed 1987) mueve la cámara y elige clips (l.327-383).

### 9.3 Azar
- **Con semilla**: echo_view.gd:314, 322 (`manifest.seed + 90211`, separado del generador del mapa); ceiling_dust.gd:67-68 (semilla = hash de la posición redondeada), 386-387 (`blot` con semilla); blood.gd:98-99 (semilla de escena ^ 0xb100d), 398 (`seed = int(scene.seed) % 997` para el charco); intro_sequence.gd:83, 99 (1987); lurker_visual.gd:196 (`noise.seed = 11`).
- **Sin semilla**: lurker_visual.gd:136 (`tic_rng`), 150 (`tic_rng.randomize()`); hotel_ui y otros usan `randf()` global (156 usos en `game/`).
- **En shaders**: todo el ruido de los shaders es hash determinista (por píxel, por frame o por INSTANCE_ID). Lo que cambia entre frames son `TIME`, `now`, `clock`, `age`. Los shaders no usan `randf`.
- **Entre renderers**: `CURRENT_RENDERER` cambia el resultado (echo_field, echo_points, lurker_darkness), y `COMPAT_LIFT` 1.6 compensa en Compatibility (echo_view.gd:362-364).

### 9.4 Dependencias de orden que los shaders no controlan
- echo_self "se dibuja encima" del campo y de las nubes (comentario echo_self.gdshader:2-3): depende del orden de dibujo de Godot (render priority / orden de transparentes).
- analog y lens leen la pantalla ya escrita: dependen de que las CanvasLayer se dibujen en el orden de `layer` (presentation.tscn: lens 2, camcorder 3, analog 5).
- `camcorder_effect` (POST_TRANSPARENT) corre antes del TAA y del tonemap; `lens.gdshader` después (comentario lens.gdshader:2-3).
- ceiling_dust, lurker_darkness y echo_points leen el buffer de profundidad: dependen de que el pase opaco haya escrito la profundidad antes de los transparentes (ver `depth_draw_never` en cada uno).

---

## 10. Pruebas de tests/ que vigilan esta parte

### 10.1 Pruebas que leen parámetros de shader (ruta:línea)
- **tests/hotel/echo_test.gd**: 55 (rojo y a través de todo: `tone_cold` y `mote_material`), 102 (`age_limit`), 226-227 (guía azul y chillido sin tinte rojo: `shriek_cold == tone_cold`), 242 (`tone_hot.r > 1` en teles), 458 (`jitter_amount` y `grain_amount` a 0 con efectos reducidos), 461 (`residue`), 466 (`point_scale`), 472 (mitad de granos y doble tamaño en Bajo), 477 (Ultra: más granos y `point_scale` menor).
- **tests/hotel/hotel_test.gd**: 445 (`vhs == 0` con efectos reducidos), 477 (Ultra: barniz en capa propia, `WOOD_LACQUER`, cuadros acristalados, oclusión), 508 (Muy bajo: media resolución, sin glow, sin lente), 529 (Medio: lámparas y mapas).
- **tests/hotel/intro_test.gd**: 37-39 (`crack_level` 0 y 1 en los golpes de la tele), 56 (`signal_loss` 0 al empezar).
- **tests/hotel/sanity_test.gd**: 151-159 (`vhs` sube y baja con la cordura; 0 con efectos reducidos).
- **tests/hotel/survival_test.gd**: 456-462 (`signal_loss` > 0.5 al morir, < 0.05 después, 0 en piso nuevo), 492 (`motion == 0` de cortinas y polvo apagado con efectos reducidos).
- **tests/hotel/capture_test.gd**: 156-167 (`tape_hit` y `tape_fray` a 0 tras la captura), 246 (`reach` de la piscina de sangre).
- **tests/hotel/difficulty_test.gd**: 408-412 (`marked` solo mientras se rebobina).
- **tests/hotel/scene_contract_test.gd**: 22-23 (los dos ColorRect "Presentation/Analog/Screen" son el mismo material), 32 (orden de capas: OSD, interfaz y analog).
- **tests/hotel/stages_test.gd**: 660 (`level` de los carteles de salida; siguen encendidos).
- **tests/office/office_finishes_test.gd**: 80 (`clear_glass` es ShaderMaterial con `wire` 0), 85 (ShaderMaterial con su escaneo), 88-97 (`map_mode`, `map_tint`, `map_rough_keep` 0 en acero, `roughness`), 101-106 (`object_space` en walnut_object y oak_door, no en walnut), 114 (`ceiling.gdshader` en el techo de servicio), 116 (`ceiling_tile.gdshader` en la placa de oficina), 281 (`color` de una hoja).
- **tests/office/office_light_test.gd**: 41 (`flat_color` de un material con shader), 302 y 332-333 (`glow` del halo igual al color de la luz de la sala).
- **tests/office/office_pieces_test.gd**: 99 (material propio de la oficina con `lite`, sin `stand_in`).

### 10.2 Pruebas que pasan por la compilación de shaders
- **tools/dev/check_shaders.gd** (68 líneas): carga cada `.gdshader` bajo `res://game`, lo dibuja en un quad con ventana y avisa de `BROKEN` o `NO_UNIFORMS`. Salta los shaders `fog` en Compatibility (l.43-45). **Sólo** recoge `.gdshader` (no `.gdshaderinc` ni `tools/dev`), y en headless imprime `SHADERS_SKIPPED`.
- **tools/verify.ps1:108-115**: ejecuta `check_shaders.gd` dos veces, con Forward+ y con Compatibility; l.145 falla si el log contiene `SHADER ERROR`, `Shader compilation failed` o `SCRIPT ERROR:`.
- **tools/godot.ps1:90-97**: el "shader baker" del exportado no hornea en Windows para Metal (comentario).

### 10.3 Pruebas de rendimiento y de captura (sin desglosar)
- tools/benchmarks/hotel_benchmark.gd, tools/capture/*, tools/dev/glare_look.gd, tools/dev/wood_look.gd, tools/dev/lens_blood_look.gd: herramientas de mirar, no pruebas automáticas.

---

## 11. Discrepancias entre comentario y código (hechos)

1. **chroma_taps**: el comentario de analog.gdshader:46-47 dice "7, o 4 en el preset más bajo". El código da 4 en Bajo (graphics_presets.gd:191), 7 en Medio, Alto y Ultra, y **2** en Muy bajo (graphics_presets.gd:233), que es el preset más bajo y además el de `tape_lite`. Dos cosas distintas: el comentario quedó desfasado.
2. **Tinta del Lurker**: tools/art/lurker/bake_ink_noise.gd:3-7 dice que lurker_darkness.gdshader "lee" una textura 64×64×64 horneada en `assets/enemies/lurker/ink_noise.res`. El shader actual no tiene `sampler3D` ni textura: el ruido es procedural (lurker_darkness.gdshader:43-57). Ningún archivo de `game/` referencia `ink_noise`. El horneado no lo usa nadie.
3. **Cifra de rendimiento en un comentario**: wood.gdshaderinc:5-6 cita "un cuarto de milisegundo de un fotograma de Alto a 1080p". No hay medición en este repo que yo haya visto (sin comprobar).
4. **Includes de surface**: el texto de surface.gdshaderinc:150-156 habla de "el preset más alto" y de `finest_surface()` (`surface_detail > 4.5`), coherente con graphics_presets.gd:221 (5.0). Sin discrepancia, pero el comentario dice "tiles bedded each at its own tilt" y la pendiente solo se aplica con `finest_surface() || tilt_always` (tile.gdshader:81). Coherente.
5. **check_shaders.gd y los includes**: el comentario del script habla de "todos los shaders bajo game/", pero solo recoge `.gdshader`. Los `.gdshaderinc` no se comprueban de forma directa; se comprueban de forma indirecta a través de los `.gdshader` que los incluyen.
6. **echo_points.gdshader:20-21**: el comentario dice que `age_limit` se empuja "desde la tasa de escritura medida". En echo_view.gd:986-990 se fija desde `span`. No se comprobó cómo se calcula `span`.
7. **surface.gdshaderinc:9-12**: el comentario dice que el `room_data` viene de `hotel_geometry.flush()`. En el código de hotel_geometry.gd:599-606 el `room_data` se escribe en `set_instance_custom_data` solo cuando `room != null` (l.601), y `use_custom_data = room != null`. Coherente.
8. **Fog y Compatibility**: check_shaders.gd:43-44 dice que el renderer de OpenGL "rechaza el tipo fog". Es un comentario de terceros (no lo verifiqué en el motor). Ver §12.

---

## 12. Sin comprobar

- **No se ejecutó nada.** Ni Godot, ni compilación, ni capturas. Todos los hechos son de lectura de código.
- **Cuerpo de las cadenas GLSL de compute**: camcorder_effect.gd (l.106-345) y motion_blur_effect.gd (l.39-81) no se leyeron línea a línea. Se inventariaron los límites, los nombres de etapa, los push constants visibles y el flujo de compilación. El propósito de cada etapa viene de la cabecera (camcorder_effect.gd:1-33) y de sus nombres, no de su cuerpo.
- **Consumidores GD**: no se leyeron completos. echo_view.gd, office_geometry.gd, hotel_geometry.gd, presentation_rig.gd, hotel_ui.gd, blood.gd y lurker_visual.gd se revisaron por líneas con grep y en tramos. Las funciones que los rodean (por ejemplo, la lógica de `lurker_visual.gd:300-400` o `hotel_geometry.gd:2580-2720`) no se leyeron completas.
- **Pruebas**: solo las líneas que citan shaders o parámetros. No se leyó ninguna prueba entera ni se comprobó si pasan.
- **Escaneos y texturas**: no se abrió ningún PNG, JPG ni `.tres` de textura. No se sabe el contenido de `assets/decals/blood_atlas.png` ni del `ingest_pbr.py`, salvo lo que dicen sus comentarios y su nombre.
- **Preset ↔ nombre**: el orden de los cinco bloques de `PRESETS` (graphics_presets.gd:185, 195, 205, 215, 227) se infirió de NAMES (l.20) y de los tests de echo_test.gd:472 y hotel_test.gd:508. No se verificó línea a línea.
- **Renderer de escritorio**: el valor por defecto de Forward+ no está escrito en project.godot; lo sé por Godot 4, no lo comprobé en el repo.
- **Versión de Godot**: el encargo dice 4.7. No consulté `.claude/godot-api/VERSION` ni los uniformes del motor. Las palabras clave que cito (`hint_depth_texture`, `hint_screen_texture`, `group_uniforms`, `CLEARCOAT`, `shader_type fog`) existen en Godot 4.x, pero no comprobé su firma exacta en 4.7.
- **Qué hace Unreal con cada built-in**: no se consultó el código de Unreal (fuera del encargo). Ningún hecho aquí es sobre Unreal.
- **Riesgo**: algunas cifras de §8 son las del texto del shader, y pueden haber cambiado desde la última captura del repo. Con `git log` no lo comprobé.
- **Otros archivos que citan shaders** (no leídos): tools/trailer3d/web/* (solo las líneas de cabecera), tools/capture/*, tools/dev/glare_look.gd, tests/hotel/palette_scan_test.gd (nombre sugiere escaneo; no leído), tests de lurker_* y office_audio_test.gd (aparecen en la búsqueda por "blood|echo|lens|shader" sin líneas de shader).
- **Carpeta `.claude/worktrees/`**: contiene copias de shaders de otra rama (`admiring-lamarr-90bf9d`). No se leyeron ni se usaron.
