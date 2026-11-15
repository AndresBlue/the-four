# Ficha de hechos: render (cómo se ve The Four hoy)

Fecha de la lectura: 14 de noviembre de 2026. Repositorio: `E:/Projects/The Four`, rama `main`, último commit `e50a862`.

Esta ficha describe solo lo que hay en el código y los documentos. No propone diseño de Unreal. Las rutas van con su línea (`ruta:línea`). Las cifras de rendimiento vienen de `docs/PERFORMANCE.md` y `docs/REALISM.md` y dicen de qué fecha y de qué máquina son.

**Aviso de estado:** al empezar, `git status` mostraba cambios sin commit en `game/floors/palettes/office_palette.gd`, `game/world/generation/office_generator.gd`, `game/world/generation/office_recipes.gd` y varios tests y herramientas de la oficina. Esta ficha se hizo sobre el disco tal como estaba, no sobre `HEAD`.

---

## 0. Qué es el render en este juego, en una frase

Un motor Godot 4.7 dibuja un piso generado por código (hotel de planta 1, oficina de planta 2) como si lo grabara una camcorder doméstica de 1987: lente con barril y franjas, sensor CCD con smear, iris automático, video knee, cinta VHS con su filtro analógico y su OSD. Todo es posprocesado encima de una escena 3D con luces puntuales con sombra, sondas de reflexión y rebote por VoxelGI por sala.

---

## 1. Cadena de punta a punta (de la escena a la pantalla)

Orden tal como lo arma el código (de dentro hacia fuera):

1. **Escena 3D**, en la resolución interna `scaling_3d_scale` (0,5 a 1,0 según preset; ajuste de fábrica 0,67). `game/services/settings_service.gd:421`.
2. **Pases del render de Godot**, medidos por etapas con `--passes` (`docs/PERFORMANCE.md:31`): `viewport` (culling, mapas de sombra, prepasada, clústeres de luces), `opaque`, `sky`, `transparent`, `camera` (efectos propios), `post` (glow, escalado, tonemap, FXAA y lienzo).
3. **Compositor**, unido al `WorldEnvironment` del nodo `Presentation` (`game/app/presentation_rig.gd:63-66`). Dos efectos, en este orden, ambos en `POST_TRANSPARENT` (después del pase transparente y antes de TAA, FSR y el tonemapper; `game/presentation/camera/camcorder_effect.gd:2-6` y `:348`):
   - `motion_blur_effect.gd` (estela del giro de cámara, 1/60 s de obturador);
   - `camcorder_effect.gd` (etapa HDR: medidor, iris, smear CCD, halo y fantasmas, video knee).
4. **TAA o FSR 2.2 o FSR 1** según preset y ajuste del jugador (`game/presentation/graphics_presets.gd:245-276`). El callback del compositor corre antes de TAA y FSR 2 (`docs/REALISM.md:53`).
5. **Tonemapper.** Con la etapa HDR encendida el tonemapper es LINEAL y la exposición 1,0; si no, el de la escena (AgX, `game/presentation/hotel_environment.tres:10`). `presentation_rig.gd:80-82`.
6. **Capa 2 (`Presentation/Lens`), lente**: `game/presentation/lens.gdshader` sobre un `ColorRect` a pantalla completa, `CanvasLayer` con `layer = 2` (`presentation.tscn:17-26`).
7. **Capa 3 (`Camcorder`), OSD**: nodo `CanvasLayer` con `layer = 3` y el script `camcorder_osd.gd` (`camcorder_osd.gd:80`; `presentation.tscn:37-39`).
8. **Capa 4 (`HUD`, interfaz de planta)**: `game/ui/hotel_ui.gd:254` (`layer = 4`).
9. **Capa 5 (`Presentation/Analog`), filtro de cinta**: `game/presentation/shaders/analog.gdshader`, lee `hint_screen_texture` (todo lo de las capas 0 a 4 entra en la cinta). `presentation.tscn:27-36`.
10. **Capa 6 (`Outside`)**: menús, pantallas de carga y fin, arranque. No pasa por la cinta (`game/ui/hotel_ui.gd:128` y `:313-315`; comentario en `:300-313`).

Puntos que importan para un port:
- La cinta y la lente son pases de pantalla completa en canvas; los efectos HDR van dentro del pipeline 3D y antes de TAA/FSR.
- El filtro de cinta muestrea la pantalla ya compuesta por las capas inferiores (`screen_texture`), no el búfer de color del 3D.

---

## 2. Motor y ajustes de proyecto

Fuente: `project.godot` (74 líneas, leído entero).

| Clave | Valor | Línea |
|---|---|---|
| `config/features` | `"4.7"`, `"Forward Plus"` | 21 |
| `run/main_scene` | `res://game/app/hotel.tscn` | 19 |
| `window/size` | 1280×720 base; `mode=3` (pantalla completa, según `.claude/godot-api/doc/classes/DisplayServer.xml`, `WINDOW_MODE_FULLSCREEN = 3`) | 32-36 |
| `window/stretch` | `mode="canvas_items"`, `aspect="expand"` | 37-38 |
| `renderer/rendering_method.mobile` | `gl_compatibility` (el de escritorio no se fija aquí; `DEFAULTS.renderer = "forward_plus"` en `game/services/settings_service.gd:6`) | 57 |
| `lights_and_shadows/positional_shadow/soft_shadow_filter_quality` | 3 | 59 |
| `textures/default_filters/anisotropic_filtering_level` | 4 | 60 |
| `environment/defaults/default_clear_color` | `(0.025, 0.026, 0.021)` | 61 |
| `occlusion_culling/use_occlusion_culling` | true | 62 |
| `shader_globals/surface_detail` | 4.0 (lo sobrescribe el preset) | 66-68 |
| `config/project_settings_override` | `user://renderer.cfg` (guarda la elección de renderizador) | 20 |
| `[layer_names] 3d_render/layer_2` | "Local player body (hidden by own camera)" | 42 |
| `[layer_names] 3d_physics/layer_*` | Architecture (1), Players (3), Closed doors (4), Hiding interactions (5), Creatures (6), Door sight occlusion (7), Audio areas (10) | 43-49 |

Notas:
- `renderer.cfg` decide el renderizador al arrancar (`docs/PERFORMANCE.md:261`). Hay dos: Forward+ y Compatibility (OpenGL).
- La cámara del jugador tiene `cull_mask = 1048573` (`game/player/player.tscn:24`), que quita la capa 2 (el cuerpo propio).

Renderizador y funciones (lo que se apaga en Compatibility):
- Compatibility no tiene compositor: la etapa HDR y el motion blur no existen; queda AgX (`game/presentation/camcorder_effect.gd:30-31`; `game/app/presentation_rig.gd:58-59`).
- Compatibility no tiene SSAO, SSIL, SSR, niebla volumétrica, TAA, FSR, ni decals (`game/presentation/graphics_presets.gd:301-320`; `game/world/hotel/hotel_geometry.gd:802-803`).
- Compatibility no dibuja proyectores de luz: el haz de la linterna pasa a una forma con el propio falloff del cono (`game/player/hotel_player.gd:365-374`).
- En Compatibility el atlas de sombras se limita a 4096 y su profundidad va a 32 bits (`game/app/presentation_rig.gd:260-267`).

---

## 3. Entorno (`WorldEnvironment`)

Archivo: `game/presentation/hotel_environment.tres` (46 líneas, leído entero). Es un recurso `Environment` con `resource_local_to_scene = true` (línea 4), así que cada escena tiene su copia (`tests/hotel/scene_contract_test.gd:21` comprueba eso).

| Propiedad | Valor | Línea |
|---|---|---|
| `background_mode` | 1 = `BG_COLOR`, color (0,02; 0,02; 0,017) | 5-6 |
| `ambient_light_source` | 2 = `AMBIENT_SOURCE_COLOR`, color (0,56; 0,5; 0,4) | 7-8 |
| `ambient_light_energy` | **0.0** (luz ambiente nula en todo el hotel; el título la sube, `hotel_main.gd:1410`) | 9 |
| `tonemap_mode` | 4 = AgX | 10 |
| `tonemap_exposure` | 1.05 (se pone a 1,0 con la etapa HDR, `presentation_rig.gd:81`) | 11 |
| SSAO | radio 1.2, intensidad 2.6, power 1.6, detail 0.6, `light_affect` 0.15 (los sobrescribe el preset, `presentation_rig.gd:225-227`) | 12-16 |
| SSIL | radio 4.0, intensidad 1.2, sharpness 0.9 | 17-19 |
| SDFGI | parámetros escritos, pero `sdfgi_enabled` se pone a false en runtime (`presentation_rig.gd:235`) | 20-26 |
| Glow | intensidad 0.3, strength 1.0, bloom 0.0, `blend_mode` 1 = SCREEN, `hdr_threshold` 1.3 (con etapa HDR, 0.9; `presentation_rig.gd:82`), `hdr_scale` 1.2 | 27-32 |
| Niebla "de suelo" | `fog_enabled`, color (0,02; 0,018; 0,015), densidad 0.012, `sky_affect` 0 | 33-36 |
| Niebla volumétrica | densidad 0.006 (el oficio la escribe, `office_geometry.gd:210-217`), albedo (0,78; 0,72; 0,6), emisión 0, anisotropía 0.45 (oficina 0.6), longitud 48 (14 con luces en la niebla, `presentation_rig.gd:20` y `:248`), `ambient_inject` 0.15 | 37-42 |
| Ajustes de color | `adjustment_enabled`, brillo 1.0, contraste 1.06, saturación 0.84 (oficina: 1.16 y 0.85, `office_geometry.gd:203`) | 43-46 |

Por código, `presentation_rig.apply_settings()` (`game/app/presentation_rig.gd:214-319`) sobrescribe en cada cambio de preset: SSAO (`:223-227`), SSIL (`:228-229`), SSR (`:230-233`), glow y su bicúbico (`:236-237`), `gi_set_use_half_resolution` (`:238`, con `bounce_half`), niebla volumétrica (`:243-251`), atlas de sombras (`:261-269`), filtro de sombra blanda (`:271`), MSAA y antialias de pantalla (`:272-273`), TAA (`:277`), LOD (`:278`), oclusión (`:279`), anisotropía (`:280`), debanding (`:281`), limitador de rugosidad (`:282`), `surface_detail` global (`:285`).

---

## 4. Etapa HDR de la camcorder (compositor)

Archivo: `game/presentation/camera/camcorder_effect.gd` (477 líneas, leído entero). Es un `CompositorEffect` con ocho programas de cómputo GLSL (meter, iris, smear, spread, bright, blur, glare_mean, grade), compilados a SPIR-V en el hilo de render (`:349-382`) y despachados en nueve pasadas por fotograma (`:464-477`).

**Orden de despacho** por fotograma (`:464-477`):
1. `meter`: medidor centrado. Rejilla 64×36 (`:34`). Cuatro lecturas por celda (`:115-121`). Pondera con una gaussiana de centro (`:124`).
2. `iris`: una sola invocación (256 hilos) reduce las celdas y da la exposición objetivo y la aplica con velocidad distinta según suba o baje (`speed_up` 1.1, `speed_down` 2.4; `:43-44`). Escribe la exposición en una textura 1×1 RGBA32F (`:370-375`) que la lente lee en la GPU, sin lectura a CPU (`:79-83`).
3. `smear` (si `smear > 0`): una columna por píxel de ancho; suma el exceso sobre el umbral (`smear_threshold` 5.0, `:49`), con tope por píxel (`smear_clip` 12, `:53`). Cada columna lee una de cada dos filas (`:178`).
4. `spread`: difumina las columnas con gaussiana (`smear_spread` 0.008 del ancho, `:57`; alcance 3σ, `:202`).
5. `bright` (si `glare > 0`): a un cuarto de resolución, 4×4 píxeles por texel; solo lo que pasa `glare_threshold` 1.5 (`:62`), con tope 24 (`:234`).
6. `blur` en dos pasadas (horizontal y vertical) con gaussiana de σ ≈ 5.3 texels (`:262-292`, `SPREAD = 56`).
7. `glare_mean`: media del destello en una cuadrícula de 32×16 (`:240-261`), que atenúa halo y fantasmas cuando hay mucha luz (`CROWD` 400, `:69`).
8. `grade`: exposición, smear, halo (`HALO` 0.22, `:63`), tres fantasmas en posiciones 0.55, 1.0 y 1.6 con tintes verdes, violetas y naranjas (`:334`), balance de blancos (`white_balance`), toe 0.008 (`:76`), rodilla (`knee` 0.72, `:73`) y desaturación de altas luces por encima de luma 0.85 (`:342`).

**Tamaños:** los pases van a la resolución interna del 3D (`:439`, `:447`); las columnas, al ancho interno (`:441-446`); el cuarto de resolución del brillo, `(size + 3) / 4` (`:447`).

**Presets:** `ccd_smear` 0 en Bajo y Muy bajo, 0.28 en Medio, Alto y Ultra; `glare` 0 en Bajo y Muy bajo, 1.0 en el resto (`game/presentation/graphics_presets.gd:191`, `:201`, `:211`, `:221`, `:233`).

**Ajustes de la cámara** (`presentation_rig.gd:69-85`): con la etapa encendida, el tonemapper es LINEAL, exposición 1.0, `glow_hdr_threshold` 0.9, y el puntero `exposure_texture` va al material de la lente como `gain_map`.

**Cortes:** `reset = true` en `camcorder_effect.gd:78` salta la exposición al valor medido en el siguiente fotograma (cambio de piso, corte de cámara). Se pone en `presentation_rig.gd:88` (`camera_cut`) y al final del calentamiento en `game/presentation/shader_warmup.gd:172`.

**Liberación:** `release()` en `camcorder_effect.gd:387-395` y `_notification` en `:398-403`: al salir del árbol, para evitar el cierre con crash (`:384-386`; `docs/REALISM.md:146-151`).

---

## 5. Movimiento de cámara (motion blur) y entrelazado

**Motion blur** (`game/presentation/camera/motion_blur_effect.gd`, 190 líneas, leído entero):
- No usa el búfer de velocidad de Godot, que solo tiene el movimiento de los objetos (`:6-8`). Calcula la rotación entre la cámara de este fotograma y la del anterior (`game/presentation/camera/motion_blur_effect.gd:136-139`), reproyecta cada rayo de píxel a la vista anterior y mide la estela (`:51-81`).
- `SHUTTER = 1/60` (`:17`); `MAX_PIXELS = 48` escalado por `size.y / 1080` (`:20`, `:175`).
- Muestras: 0 en Bajo y Muy bajo, 6 en Medio, 8 en Alto, 12 en Ultra (`graphics_presets.gd:186`, `:196`, `:206`, `:216`; `presentation_rig.gd:76`).
- Necesita un fotograma anterior válido; si `dt` está fuera de (0; 0,25] la estela no se dibuja (`:138`).
- Antes de pasar el color a la estela hace una copia por cómputo, porque el búfer de color no admite copia (`:37-38`; `docs/REALISM.md:147`).

**Entrelazado** (`game/app/presentation_rig.gd:99-131`): la distancia que se movió la imagen en 1/60 s, desde la rotación de la cámara, desplaza el campo impar. Solo se nota si son más de 12 px (`FIELD_FROM`, `:106`), con el máximo en 30 px (`FIELD_TO`, `:108`) y nunca más de 48 px (`FIELD_MAX`, `:110`). Con «Efectos reducidos» no se aplica (`:120`).

---

## 6. Lente y zoom

**Constantes** (`game/presentation/camcorder_look.gd`, 52 líneas, leído entero):
- `BARREL = 0.05` (`:14`). Radio fuente = r·escala·(1 + BARREL·r²).
- `VIEW_FOV = 78` (`:22`). Campo vertical en el centro.
- `ZOOM_MAX = 6` (`:25`). Telefoto 6×.
- `barrel_for(zoom)` = BARREL / zoom (`:33-34`). A más zoom, menos barril.
- `corner_scale(aspect)` = 1 / (1 + BARREL·(aspect² + 1)) (`:38-39`).
- `render_fov(aspect, design)` (`:45-47`): el campo que se renderiza es más ancho que el que se muestra (la lente remapea después). Todas las cámaras que filman lo llaman (`:41-44`).
- `lens` (`:19`): si es false, no hay lente ni remapeo ni se renderiza más ancho. Lo apaga Muy bajo (`graphics_presets.gd:227`).

**Zoom** (`camcorder_osd.gd:172-179`; `presentation_rig.gd:161-181`): la barra W–T del OSD se muestra mientras se mueve y 1,6 s después (`ZOOM_HOLD`, `camcorder_osd.gd:75`). La cámara de jugador y las de observación reciben el FOV calculado en `update_zoom_lens()` (`:175-181`).

**Shader de lente** (`game/presentation/lens.gdshader`, 92 líneas, no leído en detalle): recibe `barrel`, `scale`, `field_shift` (entrelazado), `noise`, `chromatic`, `vignette` (0,45), `detail` (0,35) y `gain_map`. Su `screen_texture` es `hint_screen_texture` (`:9`).

**Enfoque** (`game/player/hotel_player.gd:517-570`): `CameraAttributesPractical` sobre la cámara del jugador (`:538-541`), con `dof_blur_amount` 0.15 (`FOCUS_BLUR`, `:528`). La distancia de enfoque va por `FOCUS_SPREAD` = (0,25; 0,75) (`:529`). El enfoque automático solo en Alto y Ultra (`graphics_presets.gd:211`, `:221`; `presentation_rig.gd:317`).

---

## 7. Cinta, OSD y lo que se graba

**OSD** (`game/presentation/camcorder_osd.gd`, 353 líneas, leído entero): `CanvasLayer` en `layer = 3`. Dibuja, con `Control.draw` (`:85`, `:213`):
- REC (etiqueta, con punto parpadeante que dura 0,7 s de cada 1 s, `LAMP_LIT`, `:49`);
- reloj del cinta, con fecha, generado de la semilla: `rng.seed = run_seed + 1989`, año 1986–1997 (`:143-158`);
- código y nota, marcas de enfoque (cuatro esquinas, `:305-319`), barra de zoom W–T (`:223-254`), medidor de estamina de 14 segmentos (`:255-268`) y, para la criatura, brújula de proximidad (`:320-353`) y espera de «chillido»/«rastro» (`:269-286`).

**Cinta** (`analog.gdshader`, no leído en detalle): filtro en la capa 5, por encima de todo lo de capas 0 a 4 (`docs/REALISM.md:110-112`). Lo que pone la interfaz dentro (`HUD`, capa 4) se graba con el grano, el sangrado y el barrido (`game/ui/hotel_ui.gd:250-265`). Lo que se escribe sobre la nieve («SEÑAL PERDIDA», rebobinado) se dibuja en un `SubViewport` propio (`marks_view`, `hotel_ui.gd:268-276`) y la cinta lo recibe como textura (`hotel_ui.gd:2174-2177`).

**Parámetros de la cinta que cambian por preset:** croma (`chroma_taps` 4, 7, 7, 7, 2) y `tape_lite` (solo Muy bajo: tres lecturas por píxel, sin suavizado ni realce de luma; `graphics_presets.gd:227`, `:148-150`). El resto (grano, aberración, VHS, líneas, enclaustrado) viene de los ajustes del jugador (`game/services/settings_service.gd:6`: `vhs` 0.3, `grain` 0.05, `chromatic` 0.25, `scanlines` 0.1).

**Corrupción de la señal:** los deslizadores `vhs`, `chromatic` y «frayed» (cordura) entran en `presentation_rig.gd:391-400`.

**Pantalla de muerte** (la cámara del jugador capturado): `game/app/death_tape.gd` encuadra la imagen con la máscara de la criatura (`locust_capture.gd:244-246`; `lurker_capture.gd:221-224`) y usa el `CameraAttributesPractical` del jugador (`death_tape.gd:393`).

---

## 8. Luces del hotel (piso 1): tipos, número y parámetros

### 8.1 Forma de la luz: perfiles fotométricos
`game/world/hotel/lighting.gd` (124 líneas, leído entero):
- Color: temperatura del cuerpo negro (aproximación de Tanner Helland, `:37-45`), balanceada con el blanco fijo de la cámara 3200 K (`CAMERA_WHITE`, `:33`; `light_color`, `:52-57`). Valores: incandescente 2700 K (`:26`), fluorescente viejo 4100 K con tinte verde (`:27`, `:29`).
- Perfiles, generados por código en una imagen de 256×128 (`:66-78`), usados como `light_projector`:
  - `dome` (plafón de cristal esmerilado, `:88`);
  - `tube` (regleta, perfil de alas de murciélago, `:96`);
  - `chandelier` (lámpara de araña, `:101`);
  - `troffer` (oficina, `:107`);
  - `box_sconce` (aplique de caja, `:117`);
  - `sconce` (aplique de tela, cono arriba y abajo, nada detrás, `:123`).
- `PROFILE_GAIN = 1.25` (`:23`): la energía se multiplica por 1,25 para compensar el perfil.
- Un proyector solo funciona si la luz da sombra (`lighting.gd:10-12`; `docs/REALISM.md:78`).

### 8.2 La luz de sala (una por sala)
`game/world/hotel/hotel_geometry.gd`:
- `room_lamp` → `lamp_fixture` (`:1348-1405`) → `lamp_light` (`:1409-1451`). Cada sala tiene **una** `OmniLight3D` en `lights[room.id]` (`:1412`), con:

| Tipo de sala (lo elige `lamp_of`) | Fijación | Energía | Perfil | Línea |
|---|---|---|---|---|
| "batten" (baños, lavandería, almacén, mantenimiento; `BATTEN_ROOMS` 4,7,8,9) | fluorescente de regleta, con `tube` y 0.35 de probabilidad de tubo que parpadea | 3.4 × 1.25 = **4.25** | `tube` | `hotel_geometry.gd:1372-1375` |
| "chandelier" (altura > 4.0 m, salvo recepción) | araña `Chandelier_02` escalada 1.5 | 3.6 × 1.25 = **4.5** | `chandelier` | `:1391-1394`; `hotel_palette.gd:215`, `:278-281` |
| "dome" (resto) | plafón esmerilado en anillo de latón | 3.6 × 1.25 = **4.5** | `dome` | `:1401-1404` |

- Alcance: `omni_range = max(10, 0.85 × lado mayor de la sala)` (`room_layers.gd:79-80`; `hotel_geometry.gd:1417`).
- `omni_attenuation` 1.25 (`:1418`). Tamaño de fuente `LAMP_SIZE` 0.12 × penumbra (`:1419`; `:304`).
- Sombra: `shadow_enabled` true, `shadow_bias` 0.03, `shadow_normal_bias` 0.6 (`:1421`, `:1426-1427`).
- Volumen de niebla: 0 (`:1434`); se sube a 1 solo con `lamp_fog` (`:2614-2616`).
- Caída por distancia: `distance_fade` con `lamp_fade` del preset (`:1439-1440`; `:2566-2571`).
- Apagado en sala oscura: `visible = false` y meta `off` (`:1445-1447`). Ver `may_be_dark` en `hotel_palette.gd:273-274`.
- Parpadeo de tubos: `flickers` con fase desde la posición (`:1450`; `_process` `:2636-2656`).

**Salas especiales:**
- **Recepción**: baliza roja `OmniLight3D` (energía 3.2, alcance 10.0, color (1,0; 0,1; 0,06); `:1489-1493`; `BEACON_GLOW` 9.0 en `:1454`). La lámpara de la sala baja a 0,3 de su energía (`:1493`). Sin araña (`hotel_palette.gd:280`).
- **Refugio** (`REFUGE`): dos carteles de salida (`:1464-1465`) y color de la lámpara verde pálido (`:1466`).

### 8.3 Aplique de pared (solo en vestíbulos, pasillos, galerías y recepción)
- Dónde: `hotel_palette.gd:208` (`SCONCE_ROOMS = [0, 10, 11, 12]`); `hotel_geometry.gd:1544-1556`: dos por hueco, a ±0,98 m, altura 1,6 m.
- Luz: `sconce_light` (`:2097-2125`): `OmniLight3D`, color 2600 K (`:2101`), energía `SCONCE_ENERGY` 1.6 (`:333`), alcance 3.4 (`:2103`), `omni_attenuation` 1.6 (`:2104`), sombra con bias 0.02 y normal bias 0.05 (`:2107-2109`), perfil `sconce` (`:2111`), fuera de la luz rebotada (`BAKE_DISABLED`, `:2119`), caída de 16 a 22 m (`set_fade(lamp, SCONCE_REACH - 8, 6)`, `:2121`).
- Cuántas: `SCONCE_REACH` 24 m (`:311`); las 12 más cercanas dan sombra (`SCONCES_LIT`, `:323`); las siguientes hasta 40 m dan luz sin sombra con energía 0,7 × (`SCONCE_FILL_REACH` `:332`, `SCONCE_FILL_ENERGY` `:334`; `set_sconce` `:3189`). Solo Ultra usa el relleno (`graphics_presets.gd:221`, `sconce_fill` true).
- Histéresis: una lámpara ya encendida cuenta 1,5 m más cerca (`:3118-3120`, `:3129`).

### 8.4 Lámparas de mueble (mesa y pie)
- `practical()` (`:2326-2350`): `OmniLight3D` con `omni_attenuation` 2.2 (`:2334`), sombra con bias 0.04 (`:2341`), `BAKE_DISABLED` (`:2338`), `light_specular` 0.25.
- Energía y alcance concretos (`game/world/hotel/prop_factory.gd:145` → energía 0.3, alcance 3.0, color `ffc27a`; `:151` → energía 0.38, alcance 3.6, color `ffb36b`).
- Visible según la distancia del ojo al mueble (`furniture_lamps`: 0, 28, 32, 40 m; `:3138-3141`).

### 8.5 Señalización y otras luces del hotel
- **Carteles de salida**: `exit_sign` (`hotel_geometry.gd:1865-1920`): `OmniLight3D` verde (0.25; 1.0; 0.45), energía **0.55**, alcance **2.8** (`:1902-1904`), sombra con bias 0.04 (`:1905-1906`), `light_size` 0.2 × penumbra (`:1908`), `BAKE_DISABLED` (`:1912`), `volumetric_fog_energy` 0.12 (`:1913`), caída. Visible a 14 m (`EXIT_REACH` `:124`; `:3147`). Panel con `exit_panel.gdshader` (`unshaded`, `cull_disabled`, `shadows_disabled`; `exit_panel.gdshader:12`).
- **Luces de cabina del ascensor**: `box_light` (`:1839-1851`): `OmniLight3D` (0.96; 0.94; 0.86), energía 2.4, alcance 5.5, sombra con bias 0.04 (`:1843-1847`). Solo las de coche se fuerzan a casting (`:3152-3154`).
- **Rutas de señal** (`ROUTE_SIGN`, `:1939-1948`): carteles de dirección, con luz verde del mismo tipo.

### 8.6 Número aproximado de luces del hotel por sala
- 1 luz de sala siempre (incluidas las salas oscuras, con la luz apagada).
- 0 a 2 apliques de pared en las salas de `SCONCE_ROOMS` (con dos por hueco de pared decorado).
- 0 a N lámparas de mueble (`prop_factory.gd:145`, `:151`).
- Para los refugios, 2 carteles.
- Recepción: 1 baliza.
- Ascensores: cajas de luz de cabina.
- Números exactos por sala: no medido (ver «Sin comprobar»).

---

## 9. Luces de la oficina (piso 2)

`game/world/office/office_geometry.gd` (2841 líneas) extiende `hotel_geometry.gd` (`:1`). Solo se leyeron las secciones 126-262, 663-740, 1224-1372, 1924-2126, 2301-2330, 2533-2600, 2700-2722 y 2818-2841. El resto, por nombres y grep.

### 9.1 Luz de sala
- `LAMP_ENERGY` 2.3 (`:126`), perfil «even» (`:132`), colgada a `LAMP_DROP` 0.9 m bajo las placas (`:135`).
- Energía final: 2.3 × 1.25 × `dim_of` (recepción 0.9, `RECEPTION_DIM`, `:649`; ventanilla 0.7, `:662`). Ver `lamp_fixture` (`:1924-1950`).
- Alcance `lamp_range(span, OFFICE_LAMP_LEAST 8)` (`room_layers.gd:79`; `office_geometry.gd:2094`).
- `omni_attenuation` 1.25 con pools visibles (`LAMP_ATTENUATION`, `:141`) o 0.9 sin ellas (`LAMP_ATTENUATION_ALONE`, `:142`; `:2097`).
- Especular 0 (`LAMP_SPECULAR`, `:151`).
- Color: `LIGHTING.light_color(lamp_kelvin(room))` (`:1927`, `:2005`). Kelvin por tipo en `office_palette.gd:393` (2700 a 3500 K).
- Tipo de fijación (`office_palette.gd:909-912`): «troffer» (la mayoría), «batten» (archivo, almacén, servicio, zona de aire, depósito), «emergency» (cuarto eléctrico y vacío; sin luz propia, solo su unidad de batería). Las battens de archivo llevan además focos (ver 9.3).

### 9.2 Focos bajo cada tubo (troffer pools) y su rebote
- Un par de `SpotLight3D` por tubo (`pool_pair`, `office_geometry.gd:684-729`): el foco hacia abajo con ángulo 75° (`POOL_ANGLE`, `:197`), energía `POOL_ENERGY` 3.0 (`:195`) por el factor de la sala, alcance 7.0 (`POOL_RANGE`, `:199`), caída 1.0 (`POOL_FALL`, `:198`), tamaño `POOL_SIZE` 0.6 (`:2569`), sombra y bias 0.04. Y un rebote con `BAKE_DYNAMIC` (`:721`), ángulo 90° (`BOUNCE_ANGLE`, `:740`), alcance altura + 3,0 (`BOUNCE_REACH`, `:741`) y caída 0.5.
- Número de tubos: `troffers(room)` (`office_palette.gd:1042-1073`): n = round(lado/3,0 m) por eje; 3×3 en un módulo de 8 m y 4×4 en uno de 12 m (comentario en `:1040-1041`).
- Sombra: como mucho `POOLS_CAST` = 32 focos a la vez (`:2567`), los más cercanos al ojo, con `POOL_KEEP` 1,0 m de histéresis (`:2568`; `round_pools` `:2571-2586`).
- Solo existen en Alto y Ultra (`pools_shown()`, `:2533-2534`: capas, no estático y no Compatibility). Con la luz de sala ilumina «sola» y sin focos en Bajo y Medio.
- Una sala con focos no recibe luz de su lámpara de techo (`lit_by_fittings`, `:2545-2546`).

### 9.3 Regletas y archivos
- `batten_lights` (`:2042-2063`): un par de focos hacia abajo (`BATTEN_DOWN`: energía 4.0, ángulo 85°, tamaño 1.4, desenfoque 3.0; `:2038`), un foco hacia arriba (`BATTEN_UP`: energía 3.0, ángulo 88°, alcance 4.0; `:2039`), con rebote de caída 2.0 (`:2041`).
- Archivos: `archive_battens` (`:1954-1990`): un foco por pasillo de archivo, `BATTEN_CAST` (energía 2.2, ángulo 62°, alcance 6.0; `:1997`) si da sombra, `BATTEN_AISLE` (energía 1.4, ángulo 34°, alcance 4.5; `:1998`) si no. Las regletas en archivo móvil dan sombra (cuatro focos, `:1961-1966`).
- Modelo de regleta: `mounted_fluorescent_lights_batten.res` (`:2068`).

### 9.4 Emergencias
- `EMERGENCY_ENERGY` 1.4 (`:1098`), alcance 9.0 (`:1099`), ángulo 55° (`:1100`), `EMERGENCY_KELVIN` 2400 (`:1101`), sombra con bias 0.04 (`emergency_unit`, `:1121-1187`). Hasta `EMERGENCY_REACH` 18 m (`:1095`) y 6 con sombra (`EMERGENCY_CAST`, `:1096`; 3 en Compatibility, `:1097`). Su tubo se pinta en emisivo por encendido/apagado (`emergency_on`, `:1212`).
- Energía de la luz de emergencia en el aire: `EMERGENCY_AIR` 3.0 (`:1265`).

### 9.5 Acentos, ventanilla, carteles y hitos
- `accent_spot` (`:2626-2650`): `SpotLight3D` con sombra opcional, `ACCENT_SIZE` 0.08 (`:2619`). Hasta `ACCENTS.MOST` = 3 por sala (`office_accents.gd:6`).
- Acento de ventanilla: `WINDOW_LAMP_ENERGY` 7.0, `WINDOW_LAMP_ANGLE` 34° (`:1070-1071`); sala de la ventanilla con `WINDOW_DIM` 0.7 (`:662`).
- Aplique de ascensor: `accent_sconce` → `sconce_light` (`:2706-2717`), con perfil `box_sconce` y caja de cristal (`:2717-2722`).
- Hitos (`office_landmarks.gd`, leído solo con grep): focos de puerta `SpotLight3D` sin sombra (`:213-225`) y focal de la máquina de escribir (`:250-259`).
- Bolas de luz de techo sobre las pantallas: `ceiling_halo.gdshader` (`render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled`); `HALO_*` en `office_geometry.gd:172-174`.

### 9.6 Número aproximado de luces de la oficina por sala
- 1 luz de sala (`OmniLight3D`).
- 2 focos por tubo (`SpotLight3D` pool y bounce). Un módulo de 8 m: 9 tubos → 18 focos.
- Regletas: 2 focos (abajo y arriba) más 1 foco por pasillo en archivos.
- Emergencia: 1 foco por unidad de batería, en cuarto eléctrico, vacío y zonas sin luz.
- Acentos: hasta 3 por sala.
- Motas (no son luces): `MultiMeshInstance3D` de 140 × 14 = 1960 instancias (`office_geometry.gd:1320-1321`, `:1340`).

---

## 10. Linterna, piloto, televisión y otros

- **Linterna** (`game/player/player.tscn:28-39`): `SpotLight3D`, energía 10.0, `light_volumetric_fog_energy` 0.35, `light_size` 0.03, sombra con bias 0.04, alcance 24.0, `spot_attenuation` 0.85, ángulo 32°, `spot_angle_attenuation` 0.8.
  - En Forward+ lleva un proyector radial (gradiente de 7 paradas, 256×256) como perfil del haz (`hotel_player.gd:388-399`, uso en `:197-199`).
  - En Compatibility, o cuando no es Forward+: sin proyector, ángulo 26°, falloff 3.0, energía 11.0, bias 0.3, normal bias 4.0 (`PLAIN_BEAM`, `:374-385`).
  - Sombra: `shadow_enabled` según el ajuste «Sombras» (`presentation_rig.gd:311`); tamaño de fuente `torch_size` × penumbra, máximo 1 (`:312-313`).
  - Calentamiento: `torch_warmup` tras encenderla (`:253-258`, `:658-661`).
  - Se sostiene con inercia (`torch_follow` 9.0, `:124`). El haz se apunta 7 m delante de la cámara (`torch_target`, `:434-439`).
  - En la oficina, la niebla de la linterna es 3.0 (`TORCH_AIR`, `office_geometry.gd:212`).
- **Piloto de grabación** (la luz roja de la cámara): `OmniLight3D` (`hotel_player.gd:184-214`), color (1,0; 0,06; 0,03) (`:180`), en cámara (sin sombra, `:207`). Llevada: (0,035; 0,7; 1,4) (`PILOT_CARRIED` `:183`).
- **Televisor** (`game/world/interactables/hotel_television.gd:89-114`): `SpotLight3D` (`:89`) y `OmniLight3D` de relleno (`:104`). En Forward+ el relleno usa `SHADOW_DUAL_PARABOLOID` (`:114`), que Compatibility no tiene.
- **Bombillas de la escena de entrada y del título**: `game/intro/intro_sequence.gd` (19 apariciones de clases de render; `:603-660`), `game/title/title_scene.gd` (`:107-125`), `game/intro/tv_broadcast.gd` (un `SubViewport` con su `WorldEnvironment` tonemap FILMIC, `:29-40`, y una `SpotLight3D` y una `OmniLight3D`, `:60`, `:70`). Sin comprobar en detalle.
- **Cámara de observación**: `game/app/observer_view.gd` usa `DirectionalLight3D` (`:118`, `:155`) y siete `Camera3D`. Sin comprobar en detalle.

---

## 11. Sombras y contención de la luz

**Atlas de sombras** (`presentation_rig.gd:261-269`): un solo atlas posicional para todas las luces. Tamaño por preset: 2048 (Muy bajo), 4096 (Bajo y Medio), 8192 (Alto y Ultra); en Compatibility como mucho 4096 (`:261`). Profundidad 16 bits en Forward+ y 32 en Compatibility (`:267`). El primer cuadrante del atlas se subdivide en una celda con `static_light` (solo la linterna da sombra) y con la subdivisión de fábrica en otro caso (`:268-269`).

**Quién da sombra** (por preset, `graphics_presets.gd:97-104`; `hotel_geometry.gd:3018-3054`):
- Bajo, Medio: todas las lámparas visibles dan sombra (`lamps_cast` 0 = todas; `:197`, `:187`).
- Alto, Ultra: las 20 lámparas de techo más cercanas dan sombra; las demás alumbran sin sombra y solo dentro de su sala (`lamps_cast` 20; `cast_or_fill` en `hotel_geometry.gd:3168-3173`).
- Muy bajo: ninguna lámpara da sombra; cada lámpara alumbra solo su sala con capas de render (`static_light`, `:227`; `hotel_geometry.gd:2585-2589`).

**Capas de render** (`game/world/hotel/room_layers.gd`, leído solo con grep de `lamp_range`, `light_only`, `put_on`, `assign`): 16 capas (`COUNT` 16 desde la capa 4, `:28-29`), una por sala, repartidas como un mapa coloreado (`docs/PERFORMANCE.md:440`). Las luces solo se ven en las capas de su sala (`light_only`, `:71`; `keep_lamp`, `hotel_geometry.gd:2210-2212`). Cuerpos y puertas cambian de capa al cambiar de sala (`hotel_geometry.gd:2295-2344` y `:2317-2325`).

**Ventanas y puertas**: las hojas abiertas reciben luz de las dos salas; las puertas y marcos no reciben rebote (`docs/REALISM.md:447`). Un vano con puerta cerrada tiene una losa (`light_seal`, `jamb_seal`; `hotel_geometry.gd:893-911`).

**Hechos dichos por el código sobre la luz que cruza paredes**: sin sombra, una lámpara atraviesa paredes (`docs/REALISM.md:77-78`, `:210-218`); con sombra suave la penumbra depende de qué tan cerca está la lámpara del obstáculo (`docs/REALISM.md:519-525`).

**Oclusión**: `use_occlusion_culling` en el viewport (`hotel_main.gd:1795`, por `rig.occlusion`); un `OccluderInstance3D` por sala con `ArrayOccluder3D` de los cuadriláteros de sus paredes (`hotel_geometry.gd:2066-2085`). Se desactiva durante una ejecución (`hotel_main.gd:1791-1795`).

---

## 12. Rebote de luz (VoxelGI) y sondas de reflexión

### 12.1 Rebote (hotel)
- Solo en Alto y Ultra (`graphics_presets.gd:211`, `:221`). Un `VoxelGI` por sala iluminada (`game/world/hotel/bounce_light.gd:113-117`, `:148`).
- Subdivisión 64 o 128 si la caja mide más de 20 m (`bounce_light.gd:47-48`, `:126-127`).
- Horneado en hilos de trabajo (`WorkerThreadPool.add_group_task`, `bounce_light.gd:102`), desprendidos del árbol de escena (`docs/REALISM.md:257-259`). Un piso tarda unos 1,3 s con la mitad de los núcleos y unos 5,4 s en total (`docs/REALISM.md:256-257`).
- Entrada: un doble de cada sala, con cada material en su color medio (`game/world/hotel/material_albedo.gd`; `stand_in_mesh.gd`). Los apliques, lámparas de mueble y tubos quedan fuera (`BAKE_DISABLED`, `hotel_geometry.gd:2118-2119`, `:2338`; `bounce_light.gd:45` `SKIP`).
- Solo se muestran los 8 volúmenes más cercanos (`bounce_light.gd:47` `SHOWN` = 8; `:178-193`), con datos cargados solo mientras se muestran (`docs/REALISM.md:336-338`).
- Solo se hornea la planta desde la que se mira (`start_bounce(planta)`, `hotel_geometry.gd:2371`; `:3007`).
- Medio sin rebote; Alto a media resolución (`bounce_half` `:238`); Ultra a completa.

### 12.2 Rebote (oficina)
- `office_bounce.gd` (126 líneas, solo grep): el mismo esquema de volúmenes (`INSET` 0.13, `OVERLAP` 1.2; `:19`, `:27`). Los volúmenes no reciben las lámparas de la sala contigua (`shines()`, `:97`). Si usa el mismo control `preset.bounce` (Alto y Ultra) no está verificado; la `apply_quality` heredada del hotel lo llama para el hotel (`hotel_geometry.gd:2608`).
- La oficina además tiene rebote con focos: la luz del foco sobre el suelo sube al techo (ver 9.2).

### 12.3 Sondas de reflexión
- Hotel (`hotel_geometry.gd:2535-2566`): `ReflectionProbe` del tamaño de la sala (`:2538`), `interior` (`:2539`), `box_projection` (`:2540`), `blend_distance` 0.1 (`:2541`), `intensity` 0.6 (`:2542`), `max_distance` 30 (`:2543`). Con `enable_shadows` en probes ≥ 2 y `AMBIENT_ENVIRONMENT` solo sin rebote (`:2561-2564`).
- Cuántas: `PROBES_SHOWN` 24 más cercanas y `PROBES_KEPT` 32 (`:388-389`; `round_probes` `:3078-3107`). Una sonda que existe se queda mientras esté entre las 32 más cercanas. Una sonda no se crea en una sala oscura (`:1209-1210`). Con preset 1: solo una de cada tres salas de vestíbulo (`every_third`, `:3093`). Con preset 2: todas las salas iluminadas.
- Por qué tan pocas: el atlas de reflejos de Godot tiene 64 plazas y una sonda ocupa la suya hasta destruirla (`hotel_geometry.gd:3082-3089`; `docs/REALISM.md:183-186`).
- Oficina: `PROBE_INTENSITY` 1.0 (`office_geometry.gd:231`), `PROBE_PAST` 0.05 (`:228`), capa de suelo 8 (`:232`), espejo de lentes 15 (`:240`), `LENS_MIRRORED` 15 (antes 30; `.claude/specs/visual_vuelta_grande.md:44`).
- Rebote de la sonda: sin rebote, su luz ambiente la hace la sonda (`AMBIENT_ENVIRONMENT`); con rebote, no (`:2563`). La sonda «apenas rebota» (`docs/REALISM.md:247`).

---

## 13. Niebla, polvo, motas y haces

- **Niebla volumétrica** (crece con el preset): 0 en Bajo, 48³ Medio, 64³ Alto, 96³ Ultra (`graphics_presets.gd:199`, `:209`, `:219`; `presentation_rig.gd:249-251`). Con `lamp_fog`, la celda mide 14 m (`presentation_rig.gd:20`, `:248`).
- **Luces en la niebla** (`light_volumetric_fog_energy`): 0 por defecto; 1 con `lamp_fog` (`hotel_geometry.gd:2614-2616`). Linterna 0.35 (`player.tscn:32`), en oficina 3.0 (`office_geometry.gd:212`).
- **Neblina de suelo en vestíbulos** (hotel): `FogVolume` de densidad 0.025 y albedo (0,506; 0,467; 0,373) (`81775f`), tamaño span × 0.65, alto 0,7, desplazado 0,45 m (`hotel_geometry.gd:1194-1204`), solo con Forward+ (`:1195`). Preset `floor_haze` (`graphics_presets.gd:209`, `:219`).
- **Polvo del hotel**: `CPUParticles3D` (`hotel_geometry.gd:3272-3298`): `amount` = `preset.dust` (0, 60, 90, 140; `graphics_presets.gd:190`, `:200`, `:210`, `:220`), semiextensiones de la caja de emisión 6, 1,2 y 6, vida 10 s, escala 0.006-0.017, quad con billboard y color (0,8; 0,73; 0,55; 0,22), sin sombra (`:3276`).
- **Motas de la oficina**: `MultiMeshInstance3D` de 1960 instancias con `ceiling_dust.gdshader` en modo `wrap`, caja de 4 m alrededor del ojo, alpha 0.6–1.0 (`office_geometry.gd:1318-1353`). Medio 840; Alto 1260; Ultra 1960 (`docs/PERFORMANCE.md:175`). Solo visibles con la sala de quien mira a oscuras en Medio (`office_geometry.gd:1359-1366`).
- **Velos de polvo del techo (lurker)**: `FogVolume` elipsoide con `ceiling_dust_veil.gdshader` (`game/enemies/lurker/ceiling_dust.gd:154-207`; `MAX_VEILS` 3, `:43`, `VEIL_DENSITY` 3.0, `:45`, `VEIL_LIFE` 9 s, `:47`), y `GPUParticles3D` para hilos, copos y migas (`:294`, `:346`). Sin niebla volumétrica se usan sprites (`:210-266`).
- **Haz de la linterna**: forma por proyector radial (Forward+) o por falloff del cono (Compatibility), ver §10.
- **Haz de la oficina**: las motas dispersan la luz solo donde les llega un foco (`office_geometry.gd:1307-1317`; `.claude/specs/visual_vuelta_grande.md:82`).

---

## 14. Materiales, shaders y texturas

### 14.1 Recursos (`game/presentation/materials/`)
- 49 recursos `.tres` del hotel (`game/presentation/materials/*.tres`) y 56 de la oficina (`materials/office/*.tres`). Se leyeron todos.
- Tres grupos:
  - **escaneados** (`metadata/scan = "..."`, que carga `hotel_geometry.apply_scan()` en `hotel_geometry.gd:446-493`): madera (`wood.gdshader`), moqueta (`carpet.gdshader`), papel pintado (`wallpaper.gdshader`), techo (`ceiling.gdshader`), baldosa (`tile.gdshader`), tela (`finish.gdshader` con `finish = 2`), y `finish.gdshader` con el parámetro `finish` (0 a 4 en los `.tres`: 0 la mayoría, 1 metal y latón, 2 tela, 3 cuero y lino, 4 hojas; nombres según el material, sin verificar en el shader);
  - **PBR de Godot** (`StandardMaterial3D` con `albedo_texture`, `roughness_texture`, `metallic_texture` y `ao_texture` ORM): puertas, marcos, camcorder, muebles de Poly Haven;
  - **simples**: `albedo_color`, `roughness`, `emission` (`light`, `wall_lamp_bulb` con `emission_energy_multiplier` 14.0, `glow_*` de la oficina, `lamp_off`, `tgrid`, `threshold`).
- Mapas de modo (`map_mode`, valores 0, 1 y 2): eligen cómo se mezcla el escaneo con el color del material (recolor, detalle o reemplazo; `docs/REALISM.md:284-288`; el número de cada modo no está verificado en `image_maps.gdshaderinc`).
- `texture_filter = 5`, anisotrópico según el comentario de los `.tres`; el nivel lo pone el preset (`presentation_rig.gd:280`).
- Escala de los escaneos: 2048 px o 1024 px (`small_maps`; `graphics_presets.gd:191`, `:201`).
- `surface_detail` (global, `shader_globals`; `presentation_rig.gd:285`): 0 usa una textura pequeña horneada por material (Muy bajo, `tools/textures/bake_lite_maps.gd`); 2 a 5 suma octavas de ruido, relieve y el barniz (`wood_lacquer.gdshader` en Ultra; `graphics_presets.gd:191-221`).

### 14.2 Shaders (`game/presentation/shaders/`)
- 18 `.gdshader` y 4 `.gdshaderinc` en `game/presentation/shaders/`, y 2 `.gdshader` en `materials/office/` (`ceiling_halo`, `ceiling_tile`).
- Tipos: `canvas_item` para la cinta (`analog`), la lente (`lens`), el OSD escrito (`typewriter_ink`); `spatial` para el resto (`blood`, `blood_pool`, `blood_worn`, `carpet`, `ceiling`, `curtain`, `exit_panel`, `finish`, `painting`, `tile`, `venetian_blind`, `wallpaper`, `wired_glass`, `wood`, `wood_lacquer`).
- Modos de render relevantes (grep): `blood*` con `blend_mix, depth_draw_never, cull_back, shadows_disabled, world_vertex_coords`; `exit_panel` con `unshaded, shadows_disabled, cull_disabled`; `venetian_blind` con `cull_disabled`; `wired_glass` con `blend_mix, cull_disabled, depth_draw_opaque, specular_disabled`; `ceiling_halo` con `blend_add, unshaded, depth_draw_never, shadows_disabled, fog_disabled`.
- Lectura de textura de profundidad o pantalla: `analog` y `lens` (`hint_screen_texture`); `echo_field` y `echo_points` (`game/enemies/locust/shaders/`, `:22` y `:54`), `ceiling_dust` y `lurker_darkness` (`game/enemies/lurker/`, `:39`), con `hint_depth_texture`. Comentario: `DEPTH_TEXTURE` no es un built-in y hay que pedirlo (`echo_field.gdshader:20`).
- Shaders de la interfaz (`game/ui/shaders/signal_wash.gdshader`, `tape_noise.gdshader`) y la pantalla de la TV de la entrada (`game/intro/tv_screen.gdshader`, `render_mode unshaded, cull_back`).
- Los shaders no se leyeron en detalle (solo tipo, modo y lectura de textura).

### 14.3 Proyectores de luz y geometría generada
- Los perfiles de luz son imágenes generadas en código y puestas como `light_projector` (`lighting.gd:62-78`). Las proyecciones de Godot son equirectangulares: la dirección z de la textura es el opuesto de la z local de la luz y la fila superior es hacia abajo (`lighting.gd:14-17`).
- Filtro de proyectores: `LIGHT_PROJECTOR_FILTER_LINEAR` (`presentation_rig.gd:48`). Los perfiles se leen sin copias reducidas: una copia más pequeña dejaba una raya oscura bajo cada lámpara (`presentation_rig.gd:39-47`).
- Molduras y paneles del kit (`game/world/hotel/mouldings.gd`, no leído): rodapié, moldura, cornisa, rosetones, interruptores y rejillas, generados en código por sección extruida (`docs/REALISM.md:466-478`).
- Modelos glTF (`assets/props/hotel/*.res`, `assets/props/office/...`): mallas precompiladas con superficies y materiales por archivo (`docs/REALISM.md:349-352`).

---

## 15. Decals, oclusión, batching y LOD

- **Decals** (`hotel_geometry.gd:762-803`): `Decal` con `normal_fade` 0.4, `upper_fade` y `lower_fade` 0.2, fade de distancia desde 14 m con longitud 4 (`:771-776`, `DECAL_REACH` 14 en `:799`). Cantidad por sala 4, 9 o 16 según estado (`docs/REALISM.md:386`); preset: 0 (Bajo, Muy bajo), 0.5 (Medio), 1.0 (Alto, Ultra) (`graphics_presets.gd:190`, etc.). Sin decals en Compatibility (`:802-803`) y sin decals en la recepción de la oficina (`office_geometry.gd:2301-2305`).
- **Lotes**: un `MultiMeshInstance3D` por material y por sala (`batch_roots`, `batch_target()`; `docs/PERFORMANCE.md:87`). Unas 150 000 primitivas visibles en Alto tras fase 4 (`docs/REALISM.md:408`).
- **LOD**: `mesh_lod_threshold` del preset (`presentation_rig.gd:278`): 8 px (Muy bajo), 4 (Bajo), 2 (Medio), 1 (Alto, Ultra). Las mallas de aplique, monstera, sofá y detective llevan LOD automáticos (`docs/PERFORMANCE.md:86`).
- **Distancia de detalle** del kit (molduras): 16 m para paneles, interruptores y rejillas; 26 m para lo demás (`hotel_geometry.gd:158-159`, `KIT_NEAR`/`KIT_FAR`; `docs/REALISM.md:478`).
- **Sombras que no se dibujan**: lo que mide menos de 60 cm y lo que está encima de un mueble no proyecta (`docs/REALISM.md:394`). Lo de menos de 30 cm deja de dibujarse a 16 m. En la oficina, solo las piezas grandes del suelo dan sombra (`office_models.casts()`, `CAST_LEAST`; `.claude/specs/visual_vuelta_grande.md:20`).
- **Oclusión**: ver §11.
- **Ocultación por rondas**: cada 0,25 s, en tres fotogramas (`hotel_main.gd:1826-1852`; `hotel_geometry.gd:2981`, `:2988-2999`). Solo se dibuja la planta desde la que se mira (`hotel_geometry.gd:2993`).
- **Pipelines**: Godot compila pipelines al primer dibujo. El calentamiento dibuja el piso una vez, pequeño, en una `SubViewport` de 192×108 (`shader_warmup.gd:36`, `:45-71`), con 3 habitaciones por tipo (`PER_TYPE` `:38`) y dos ángulos (`YAWS` `:39`). Coste: unos 4 s de carga y no más de 0,15 s sin fotograma (`shader_warmup.gd:26-29`; `docs/PERFORMANCE.md:343-348`).

---

## 16. Presets de calidad

Archivo: `game/presentation/graphics_presets.gd` (365 líneas, leído entero). Orden del menú: `ORDER` = Muy bajo, Bajo, Medio, Alto, Ultra (`:27`). Las claves guardadas: 0 Bajo, 1 Medio, 2 Alto, 3 Ultra, 4 Muy bajo (`:7-8`).

Ajuste de fábrica: `quality` 1 (Medio), `scale` 0.67, `upscaler` auto, `sharpness` 0.85, `vsync` true (`game/services/settings_service.gd:6`). Primer arranque con gráfica integrada: Muy bajo (`docs/PERFORMANCE.md:262`).

| Parámetro | Muy bajo (4) | Bajo (0) | Medio (1) | Alto (2) | Ultra (3) | Línea (`graphics_presets.gd`) |
|---|---|---|---|---|---|---|
| Escala 3D (ajuste de fábrica) | 0,5 | 0,67 | 0,85 | 1,0 | 1,0 | 186/196/206/216/228 |
| Escalado (`upscaler`) | bilineal | FSR 1 | FSR 2.2 | FSR 2.2 | FSR 2.2 | 185/195/205/215/227 |
| Antialias | ninguno (lo hace la cinta) | FXAA | TAA | TAA + MSAA 2× | TAA + MSAA 4× | 185/195/205/215/227 |
| Limitador de rugosidad | no | no | sí | sí | sí | 185/195/205/215/227 |
| Atlas de sombras (posicional) | 2048 | 4096 | 4096 | 8192 | 8192 | 186/196/206/216/228 |
| Filtro de sombra suave | hard | soft very low | soft low | soft medium | soft medium | 186/196/206/216/228 |
| Penumbra (PCSS) | 0 | 0 (PCF) | 1.0 | 1.0 | 2.5 | 186/196/206/216/228 |
| `static_light` (luz por sala) | sí | no | no | no | no | 227 |
| Alcance lámparas `lamp_fade` | 30+12 | 30+12 | 30+12 | 36+12 | 50+14 | 187/197/207/217/229 |
| `room_reach` (salas dibujadas) | 56 m | 56 m | 66 m | 66 m | 82 m | 187/197/207/217/229 |
| `furniture_lamps` | 0 | 0 | 28 m | 32 m | 40 m | 187/197/207/217/229 |
| `lamps_cast` (sombras de techo) | todas por sala, sin sombra | todas | todas | 20 más cercanas | 20 más cercanas | 187/197/207/217/229 |
| Sombra del cuerpo propio | no | no | sí | sí | sí | 191/201/211/221/233 |
| SSAO | no | no | Low, media res. | Medium, media res. | High, completa | 188/198/208/218 |
| `ssao_shape` (radio, intensidad, luz) | 1.2 / 2.6 / 0.15 | igual | igual | igual | 0.7 / 4.0 / 0.6 | 188/198/208/218 |
| SSIL | no | no | no | Medium, media | High, media | 208/218 |
| SSR (pasos, rugosidad) | no | no | no | 32, Low | 64, High | 208/218 |
| Niebla volumétrica (rejilla) | no | no | 48 | 64 | 96 | 199/209/219 |
| Neblina de suelo (`floor_haze`) | no | no | no | sí | sí | 209/219 |
| `lamp_fog` (luces en la niebla, 14 m) | no | no | sí | sí | sí | 191/201/211/221 |
| Glow / bicúbico | no / no | sí / no | sí / no | sí / sí | sí / sí | 190/200/210/220/232 |
| Debanding | no | no | no | sí | sí | 210/220 |
| Sondas de reflexión (`probes`) | 0 | 0 | 1 (1 de cada 3 vestíbulos) | 2 (todas las iluminadas) | 2 | 190/200/210/220 |
| Rebote VoxelGI (`bounce`) | no | no | no | sí, media res. | sí, completa | 211/221 |
| Apliques con sombra (`sconce_lights`) | no | no | no | sí (24 m) | sí | 211/221 |
| Relleno de apliques sin sombra (`sconce_fill`) | no | no | no | no | sí (40 m) | 221 |
| Polvo partículas (`dust`) | 0 | 0 | 60 | 90 | 140 | 190/200/210/220 |
| Motas oficina | 0 | 0 | 840 (a oscuras) | 1260 | 1960 | `office_geometry.gd:1320-1321` |
| Decals | 0 | 0 | 0,5 | 1,0 | 1,0 | 190/200/210/220 |
| Mapas escaneados | 1024 (no se cargan, `surface_detail` 0) | 1024 | 2048 | 2048 | 2048 | 191/201/211/221 |
| `surface_detail` (octavas) | 0 | 2 | 3 | 4 | 5 | 191/201/211/221/233 |
| Antisotropía | off | 2× | 4× | 8× | 16× | 191/201/211/221/233 |
| LOD `mesh_lod_threshold` | 8 px | 4 px | 2 px | 1 px | 1 px | 191/201/211/221/233 |
| Croma del filtro (`chroma_taps`) | 2 | 4 | 7 | 7 | 7 | 191/201/211/221/233 |
| Filtro de cinta lite (`tape_lite`) | sí | no | no | no | no | 227 |
| Lente (`lens`) | no | sí | sí | sí | sí | 185/195/205/215/227 |
| CCD smear (`ccd_smear`) | 0 | 0 | 0,28 | 0,28 | 0,28 | 191/201/211/221/233 |
| Halo y fantasmas (`glare`) | 0 | 0 | 1,0 | 1,0 | 1,0 | 191/201/211/221/233 |
| Motion blur (muestras) | 0 | 0 | 6 | 8 | 12 | 191/201/211/221/233 |
| Enfoque automático (`autofocus`) | no | no | no | sí | sí | 211/221 |
| Cuadros tras cristal (`glazed_art`) | no | no | no | no | sí | 221 |
| Molduras y kit (`detail_kit`) | caja lisa | caja lisa | caja lisa | caja lisa | sí | 221 |

Notas del código sobre los presets (`graphics_presets.gd:2-24`):
- Lo que no cambia: sombras de lámpara en Bajo a Ultra; luz ambiente cero; niebla casi negra; números de puerta y rótulos a 20 m; el faro rojo; sellos de puerta; salas oscuras.
- Muy bajo cambia la imagen a propósito: materiales de una sola textura pequeña; sin lente; sin glow; sin FXAA; luz por sala sin sombra; la cinta filtra en tres lecturas (`docs/PERFORMANCE.md:423-453`).

**Diferencias en Compatibility** (`graphics_presets.gd:301-327`): fuerza a -1 o 0 (desactivado) SSAO, SSIL, SSR, niebla, neblina de suelo, TAA, autoenfoque, luces en la niebla, relleno de apliques, rebote; FXAA sustituye a TAA si no hay MSAA. Escalado bilineal (`:268`). Los pasos de la oficina en Compatibility: solo la luz de la recepción y la ventanilla se sigue con `cast_or_fill` (`office_geometry.gd:1226-1232`), 3 luces de emergencia con sombra (`:1097`), focos sin uso (`:2533-2534`), acentos solo en la recepción (`:2782`).

---

## 17. Escalado y antialiasing

- Escala 3D: `viewport.scaling_3d_scale` = `values.scale` (`game/services/settings_service.gd:421`). Valores de la UI: `SCALING_MODES` = 1,0; 0,77; 0,67; 0,59; 0,5; 0,33 (`graphics_presets.gd:282`). Mínimo 0,33 (`settings_service.gd:198`).
- Modo de reescalado: `scaling_3d_mode` = `PRESETS.scaling_mode(values)` (`settings_service.gd:425`). Automático = el de cada preset; si la escala es 1,0, bilineal (`graphics_presets.gd:267-276`). Cada reescalado a 1,0 se hace bilineal.
- Nitidez de FSR: `fsr_sharpness = lerp(2.0, 0.0, sharpness)` (`settings_service.gd:426`; 0,85 de fábrica).
- Con FSR 2.2, TAA, FXAA, SMAA y MSAA se apagan (`graphics_presets.gd:321-327`).
- Motion vectors: el compositor corre antes de TAA y FSR 2 (`docs/REALISM.md:53`), y el búfer de velocidad existe siempre con `needs_motion_vectors` (`docs/REALISM.md:54`).
- TAA en el modo de la creature se apaga (`presentation_rig.gd:277`).

---

## 18. Gradación y cambios por piso

**Hotel (piso 1):** un solo entorno para las tres plantas (`hotel_environment.tres`). Diferencias por planta:
- Estado de las salas (cuidadas, descuidadas, abandonadas): planta 1: 83, 16 y 1 %; planta 2: 56, 37 y 7 %; planta 3: 29, 47 y 24 %; el salón vacío nunca está cuidado (`docs/REALISM.md:374`; `hotel_palette.gd:188-191` `WEAR` 0.25, `KEPT` (0.25, 0.55)).
- Probabilidad de sala oscura: `DARK_OWN` = 0,23, 0,29 y 0,36 (`hotel_palette.gd:185`; el comentario dice «más cuanto más abajo», el índice de planta no está verificado); las salas oscuras se agrupan con `DARK_SPREAD` 0,45 (`:186`).
- Papel deteriorado en salones vacíos y almacenes (`plaster_decrepit`; `hotel_palette.gd:200-201`).
- Ajuste de la cámara: el hotel no cambia la gradación; `apply_grade` la devuelve al valor autorizado (`presentation_rig.gd:334-350`).

**Oficina (piso 2):** `GRADE` aplicada a todo el piso (`office_geometry.gd:203`): iris `key` 0.05 (hotel 0.065, `camcorder_effect.gd:37`); balance de blancos (1.2; 1.0; 1.15); contraste 1.16; saturación 0.85; luz de oclusión 0.35 (`ssao_light`). Se aplica en `presentation_rig.apply_grade()` (`:334-350`). El aire del piso va por planta: densidad `AIR_DENSITY` 0.008 (planta 1), 0.02 (planta 2), 0.02 (planta 3) (`office_geometry.gd:210`); anisotropía 0.6 (`:211`); se reescribe en cada cambio de planta (`presentation_rig.gd:356-357`, `follow_grade()`).

Por planta: plantas de la oficina (`office_palette.gd:349-353`): PERSONAL, REGISTRO Y ARCHIVO, DIRECCIÓN. Mezcla de tipos (`PLANTA_MIX`, `:475-479`). Suelos por tipo (`FINISH_BY_TYPE`, `:369`). Moqueta: en salas de dirección (`CARPET`, `:362`) y en las naves de la planta 1 (`NAVE_CARPET`, `:363`).

Dificultad y oscuridad (oficina): en Apacible la planta 1 queda entera con luz; en Equilibrada, la del manifiesto; en Desafiante, casi todo menos un 10 % (`LIT_LEFT` 0.1, `office_geometry.gd:1014`; `tests/office/office_dark_test.gd:1-6`).

---

## 19. Capturas de muerte (`game/app/capture_styles/`)

Leídos los tres archivos completos. Son cómo la criatura sujeta y se ve la captura, no son render en sí, pero fijan posiciones de cámara y de cuerpo.

- `locust_capture.gd` (246 líneas): la cinta de la víctima se encuadra en la máscara de la criatura (`mask_transform`, `:244-246`); la linterna se deja en el suelo con semilla `seed ^ 0x51ed` (`:188-207`).
- `lurker_capture.gd` (284 líneas): la criatura cuelga del techo. La teja de techo se mueve con `swing_tile` (`:185-209`, con `ceiling_service`). Encuadre de la cinta: `far` 0.6, `held` 0.34, `near` 0.24 (`:221-224`). La cámara sube con la criatura (`tape_pose`, `:227-230`).
- `lurker_score.gd` (135 líneas): tiempos del golpe (`GRAB` 0.3, `ARM_TIME` 3.0, `KILL_TIME` 3.15, `DROP_TIME` 3.6, `CUT_TIME` 5.4, `END_TIME` 5.7) y mezcla de cuerpo (`HOLD_FAR` (0.35; 0.55), `LIE_ROOM` 1.4; `:13-55`).

---

## 20. Rendimiento medido y hardware objetivo

**Objetivo declarado:** Alto a 60 FPS en RTX 4060 Ti a 1080p. Bajo, como hoy (`docs/REALISM.md:9`). Meta del piso 2: 60 FPS a 1080p en Alto (`docs/PERFORMANCE.md:659`).

**Hardware de desarrollo:** RTX 4060 Ti de 8 GB (dato del encargo) y Ryzen 9 5900X, 1080p (`docs/PERFORMANCE.md:7`, `:201`). El PC del autor, según `docs/PERFORMANCE.md:572`, es una RTX 4060 Ti con unos 89 FPS en Ultra.

**Limitador:** 350 FPS en este PC por RTSS (`docs/PERFORMANCE.md:23`). Las medidas de Bajo y Muy bajo quedan clavadas en 2,85–2,90 ms por eso.

**Medidas de los presets (GPU caminando, ms; fotograma medio y p99)** — `docs/PERFORMANCE.md:461-467` (§6, «Medidas», octubre de 2026, semilla 81):

| Preset | GPU caminando | Fotograma (media · p99) | GPU quieto | Llamadas · sombra | VRAM | Carga |
|---|---|---|---|---|---|---|
| Muy bajo | 0,52 | 2,85 · 4,04 | 0,48 | 156 · 0 | 359 MB | 10,1 s |
| Bajo | 1,36 | 2,90 · 4,80 | 1,28 | 154 · 65 | 494 MB | 10,4 s |
| Medio | 4,68 | 5,77 · 7,44 | 3,81 | 177 · 1 066 | 1 251 MB | 13,0 s |
| Alto | 9,87 | 11,10 · 14,37 | 7,82 | 178 · 1 898 | 1 982 MB | 13,9 s |
| Ultra | 14,58 | 15,83 · 20,23 | 12,31 | 200 · 1 944 | 2 182 MB | 14,0 s |

Más reciente (6 de octubre, tras el recuento de lámparas y el kit de molduras): Alto 9,9–10,1 ms; Ultra 13,0–13,2 ms; Muy bajo 0,51 ms (`docs/PERFORMANCE.md:548-555`).

**Equipo modesto simulado** (cuatro núcleos al 60 %, GPU a ×9; `docs/PERFORMANCE.md:364`, `:474-483`): Muy bajo, Forward+: 2,99 ms de GPU, 240 FPS. Bajo como se entregaba (FSR 2.2): 17,9 ms, 53 FPS. Bajo con FSR 1: 10,9 ms, 83 FPS. Medio: 36,9 ms, 26 FPS. Muy bajo en ×16: 5,20 ms, 156 FPS. Muy bajo en ×36 (UHD 620): 11,2 ms, 79 FPS (`:478-483`). **Esto es un modelo, no una medida** (`:370`).

**Piso 2, línea base y final** (`docs/PERFORMANCE.md:630-659`, semilla 7, 1080p, RTX 4060 Ti; resultados del 10 de noviembre de 2026):
- Alto, vista de inicio: fotograma p95 16,47 ms, p99 20,54 ms; GPU media 10,09 ms; CPU a 60 FPS (p95) 17,64 ms → **NO PASA**.
- Alto, vista del medio: p95 16,62 ms, p99 20,24 ms; GPU media 9,48 ms; CPU (p95) 18,87 ms → **NO PASA**.
- Alto, vista de lejos: p95 8,75 ms; CPU (p95) 9,89 ms → pasa.
- Carga del piso: 15,2 s en Forward+ (13,2 s antes), 51,1 s en Compatibility (13,2 s antes) (`:657`).
- VRAM en Alto: 2 215,6 MB (Forward+) y 820,6 MB (Compatibility) (`:657`).

**Compatibility contra Forward+** (medidas, `docs/PERFORMANCE.md:469`, `:489-491`): Bajo, 3,01 ms de GPU en Compatibility contra 1,36 en Forward+. Muy bajo: 1,14 contra 0,52. En una gráfica dedicada Compatibility no es más rápido (`:263`).

**Pendiente de medir:** una integrada real (`docs/PERFORMANCE.md:497`; Bajo en Compatibility en una integrada; Ultra a 1440p en gama media; `:269`).

**Tirones:** en Ultra, alrededor de uno de cada nueve fotogramas es un diente por el tick de física (`docs/PERFORMANCE.md:597`). Los picos de la primera vez que se ve una sala siguen (`:598`).

**Otros:** picos al ver una sala por primera vez (`docs/PERFORMANCE.md:598`); 7 pipelines no cubiertos por el calentamiento (`:348`).

---

## 21. Problemas visuales abiertos (los que señaló el autor y los que quedan en los documentos)

Del piso 2, `.claude/specs/visual_vuelta_grande.md`, sección «Pendiente» y los puntos «Queda» y «sin resolver»:
1. **Foto 4 (14 de noviembre): z-fighting blanco en una pared.** Sin resolver. No se reproduce en 32 capturas. Hace falta la semilla y el sitio de la partida del autor (`visual_vuelta_grande.md:63`).
2. **Recepción:** motas del suelo más gruesas que la referencia (`:75`).
3. **Pasillo:** las vetas del suelo se notan mucho (`:75`).
4. **Luz de emergencia:** muy oxidada (`:75`).
5. **Halo de la emergencia:** es una bola, no un cono; la niebla de 64³ no da bordes (`:84`).
6. **Linterna de un compañero:** sigue fuera de la niebla (`remote_player.gd`, `:84`).
7. **Luz de una sala que sale por la puerta:** casi no se ve en el aire (`:84`).
8. **Motas en la linterna:** se ven poco (`:84`).
9. **Huecos negros junto a algunas pantallas** en naves y cubículos, sin causa confirmada (`:112`).
10. **Churretes de pared a la misma altura:** pide tocar un sombreado compartido con el hotel (`:113`).
11. **Materiales y modelos (piso 2):** carros del archivo móvil, climatizadora, taquillas en silueta, tubos del correo que acaban en el aire, repetición de cajas y tablones de corcho, zócalo del mostrador, fregadero, reja del montacargas en bandas (`:106-115`).
12. **Sin comprobar en captura:** placa colgante, silla azul de cerca, blocs, perchero, puerta de mirilla, rebote en Medio y Bajo (en el código no sale allí, `:116`).

Del hotel, `docs/REALISM.md` y `docs/PERFORMANCE.md`:
13. **Fase 4:** nueve modelos CC-BY de Sketchfab pendientes (teléfono, sanitarios, lavadoras, carro de limpieza, timbre, cenicero, toallas); sus huecos siguen como estaban (`docs/REALISM.md:347-348`).
14. **Fase 6, falta:** manillas y bisagras propias; variedad de perfiles por tipo de sala; un extintor y un teléfono sin rótulos en coreano; colocar el marco y los conductos (`docs/REALISM.md:508`).
15. **Ultra cae de 60 FPS** en algunos fotogramas (`docs/REALISM.md:231`, `:334`, `:407`).
16. **Muy bajo:** el papel pintado de las plantas 2 y 3 sale con la mugre del zócalo y sin manchas arriba, porque el shader calcula la altura en el mundo (`docs/PERFORMANCE.md:498`).
17. **Interruptor «Sombras»** de Bajo a Ultra: al apagarse deja pasar las lámparas por las paredes; las capas de Muy bajo servirían (`docs/PERFORMANCE.md:499`).
18. **Revisar en partida:** TAA de Medio en movimiento (estela del polvo y de la linterna); penumbras anchas de Ultra con lámparas que parpadean; visión de eco de Bajo y halo de Ultra con jugadores reales (`docs/PERFORMANCE.md:271-273`).
19. **Competencia en el atlas de sombras de Medio:** unas 800 llamadas de sombra por fotograma en la sala 36 (`docs/PERFORMANCE.md:96-99`).
20. **Grietas de la tele en la entrada:** pintadas píxel a píxel, con un tirón estimado de 50 a 300 ms por golpe (`docs/PERFORMANCE.md:109`).
21. **Peor fuga del piso de tres plantas:** 0,0359 en la luz de los apliques (`docs/PERFORMANCE.md:356-357`).

---

## 22. Lo que depende del orden de ejecución, de la física o del azar

**Orden y tiempo (no reproducible fuera de Godot):**
- Ronda de visibilidad: cada 0,25 s del reloj de `_process`, en tres fotogramas; `visibility_clock += delta` (`game/app/hotel_main.gd:1826-1852`; `game/world/hotel/hotel_geometry.gd:2981`, `:2988-2999`).
- Histéresis de la luz más cercana: una lámpara encendida cuenta 1,5 m más cerca (sconces, `hotel_geometry.gd:3118-3129`), 1,0 m para los focos de oficina (`office_geometry.gd:2568`, `:2580`). Las sondas: `probes_at_once` 1 al caminar (`hotel_main.gd:1848-1850`).
- Exposición del iris: depende del fotograma anterior (`camcorder_effect.gd:156-166`, `:159-160` con `dt` y velocidades). `reset` corta la exposición (`:466`, `presentation_rig.gd:88`).
- Motion blur: depende de la base de la cámara del fotograma anterior (`motion_blur_effect.gd:137-140`) y se descarta si `dt` no está entre 0 y 0,25 s (`:138`).
- Entrelazado: depende de la cámara del fotograma anterior y de `delta` (`presentation_rig.gd:116-131`).
- `frame_delta` lo escribe cada fotograma `hotel_main.gd:1797-1799`; si no hay, se usa el reloj de pared `Time.get_ticks_usec` (`camcorder_effect.gd:459-460`; `motion_blur_effect.gd:133-134`).
- Cámara en el movimiento: `Engine.get_physics_interpolation_fraction()` (`game/player/hotel_player.gd:617-619`; `docs/PERFORMANCE.md:589`).
- Parpadeo de las luces: `flicker_clock` acumula `delta` (`hotel_geometry.gd:2628`); fase de cada tubo por posición (`:1450`); baliza con `fposmod(flicker_clock, 1.6)` (`:2631`).
- Carga del piso: `await get_tree().process_frame` entre plantas (`hotel_geometry.gd:1065-1068`) y entre fotogramas del calentamiento (`shader_warmup.gd:84-89`).
- Horneado del rebote en hilos de trabajo (`bounce_light.gd:102`, `WorkerThreadPool`), con poll por fotograma (`bounce_light.gd:130`).
- El calentamiento depende de `RenderingServer.frame_post_draw` (`shader_warmup.gd:85`).
- Señales: `get_viewport().size_changed` reconfigura la lente (`presentation_rig.gd:54`); `settings.changed` reaplica el preset (`hotel_main.gd:327`); `canvas.draw` del OSD (`camcorder_osd.gd:85`).
- Activación de la oclusión según estado de ejecución (`hotel_main.gd:1791-1795`).
- Liberación al salir: `release()` y `_notification(PREDELETE)` (`camcorder_effect.gd:387-403`; `hotel_main.gd:1923-1927`).
- `call_on_render_thread(setup)` (`camcorder_effect.gd:349`, `motion_blur_effect.gd:85`): el compositor se compila en el hilo de render.

**Azar y semillas:**
- Fecha de la cinta: `RandomNumberGenerator` con semilla `run_seed + 1989` (`camcorder_osd.gd:143-149`). Determinista.
- Variación del decorado: `vary(position, salt)` con hash de posición, `looks` del piso (`hotel_geometry.gd:503-504`); `looks_of(seed)` (`:494-496`). Determinista. «Nunca consume el generador de azar» (`:500-502`).
- Motas de la oficina: `RandomNumberGenerator` con semilla 6113 (`office_geometry.gd:1327-1328`). Determinista.
- Escombros del techo (lurker): `rng.seed = hash(point...)` (`game/enemies/lurker/ceiling_dust.gd:67-68`) y `rng.seed = seed_value` (`:386-387`). Pero `randf_range` y `randf()` **globales sin semilla** en `ceiling_dust.gd:88` y `:90`, que no son deterministas.
- Captura: `torch_rest` con semilla `seed ^ 0x51ed` (`locust_capture.gd:188-190`); el lado y el orden de la captura salen de `rng.randf()` (`locust_capture.gd:62-64`, `lurker_capture.gd:62`).
- Semilla de cada piso nuevo: `randi_range` del azar global, sin semilla fija (`hotel_main.gd:555-566`).

**Física:**
- Cámara de jugador: el cuerpo avanza a 60 Hz, la cámara se interpola por fotograma (`hotel_player.gd:608-619`).
- Rayos de física en las capturas: `torch_rest` (`locust_capture.gd:199-200`, máscara 1) y `ceiling_over` (`lurker_capture.gd:101-104`, máscara 1|8).
- Cuerpos con luz: `light_body` y `follow_bodies` mueven el cuerpo a su capa de sala (`hotel_geometry.gd:2302-2325`).

---

## 23. Tests que vigilan esta parte

Ejecutados en el repositorio: no. Solo se leyeron sus cabeceras y las líneas que tocan render.

- `tests/hotel/hotel_test.gd` (líneas 445-530 y 600-650): presets (cinco, cada uno aplicado entero; orden; Ultra con barniz en capa propia; Muy bajo con luz sin sombra; lente; luz de sala por preset; rebote; `SpotLight3D` de prueba).
- `tests/hotel/echo_test.gd` (líneas 455-477): presets de la visión de eco.
- `tests/hotel/scene_contract_test.gd` (líneas 21, 132, 288): el entorno es local a cada escena; espejos; presets.
- `tests/hotel/room_light_test.gd` (218 líneas): luz por sala, apagón, drenaje, `put_on_actor` y `follow_bodies`.
- `tests/hotel/palette_scan_test.gd` (302 líneas): ningún tipo de sala es un número fuera de las paletas (escanea `game/` y `tools/`).
- `tests/hotel/manifest_golden_test.gd` y `tests/hotel/creature_contract_test.gd`: el piso 1 no cambia sin encargo y lo vigilan estas dos (`CLAUDE.md`, «Reglas de este proyecto para todos los agentes»).
- `tests/office/office_light_test.gd` (747 líneas): color por tipo de sala y familias de luminarias; lentes y tubos apagados con la sala; luces de apliques de ascensor.
- `tests/office/office_finishes_test.gd` (346 líneas): acabados y suelos por tipo; sin rayas ni cornisa del hotel.
- `tests/office/office_dark_test.gd` (63 líneas): oscuridad según dificultad.
- `tests/hotel/intro_test.gd`, `tests/hotel/sanity_test.gd`, `tests/hotel/difficulty_test.gd`, `tests/hotel/capture_test.gd`: parámetros de cinta y de la cámara.
- `tools/verify.ps1`: ejecuta las pruebas; el chequeo de shaders es `tools/dev/check_shaders.gd` (`:11`); la lista de comprobaciones está en `docs/PERFORMANCE.md:130-139`.

---

## 24. Clases y nodos de Godot que usa esta parte

Conteo de ocurrencias en `game/` (`.gd`, `.tscn`, `.tres`, `.gdshader`, `.gdshaderinc`), incluidos comentarios. Son aproximados.

| Clase | Ocurrencias | Dónde (principal) |
|---|---|---|
| `OmniLight3D` | 50 | hotel_geometry.gd (luz de sala, apliques, cajas, salida, baliza); office_geometry.gd (acentos, ventanilla); hotel_player.gd (piloto); intro/title |
| `SpotLight3D` | 27 | player.tscn (linterna); office_geometry.gd (focos, emergencia, regletas); office_landmarks.gd; hotel_television.gd; hotel_player.gd; executions.gd (linterna en la mano) |
| `DirectionalLight3D` | 2 | observer_view.gd |
| `AreaLight3D` | 3 | office_geometry.gd (`accent_strip`) |
| `Light3D` (tipo base) | 49 | varios |
| `VoxelGI` | 16 | bounce_light.gd; office_bounce.gd |
| `ReflectionProbe` | 6 | hotel_geometry.gd; office_geometry.gd |
| `FogVolume` | 5 | hotel_geometry.gd (neblina de vestíbulo); ceiling_dust.gd (velos) |
| `Decal` | 7 | hotel_geometry.gd (decals); lurker_visual.gd (manchas) |
| `CPUParticles3D` | 3 | hotel_geometry.gd (polvo) |
| `GPUParticles3D` | 3 | ceiling_dust.gd (hilos, copos, migas) |
| `WorldEnvironment` | 8 | presentation.tscn; hotel_ui.gd; tv_broadcast.gd |
| `Environment` | 15 | hotel_environment.tres; presentation_rig.gd; ui; intro |
| `CameraAttributesPractical` | 6 | hotel_player.gd (enfoque); death_tape.gd; revival.gd |
| `Camera3D` | 53 | player.tscn; observer_view.gd; hotel_ui.gd; echo_view.gd |
| `CompositorEffect` | 4 | camcorder_effect.gd; motion_blur_effect.gd |
| `Compositor` | 2 | presentation_rig.gd; shader_warmup.gd |
| `RenderingServer` | 84 | presentation_rig.gd; shader_warmup.gd; hotel_geometry.gd; settings_service.gd; y otros |
| `RenderingDevice` | 36 | camcorder_effect.gd; motion_blur_effect.gd |
| `RDUniform` | 10 | camcorder_effect.gd; motion_blur_effect.gd |
| `RDTextureFormat` | 3 | camcorder_effect.gd; motion_blur_effect.gd |
| `RDShaderSource`, `RDSamplerState`, `RenderSceneBuffersRD`, `RenderData`, `RenderSceneData`, `UniformSetCacheRD` | 2 a 3 cada una | camcorder_effect.gd; motion_blur_effect.gd |
| `Texture2DRD` | 1 | camcorder_effect.gd (`exposure_texture`) |
| `SubViewport` | 28 | shader_warmup.gd; hotel_ui.gd (`marks_view` y otros); code_lock.gd; files_objective.gd; tv_broadcast.gd; rules_screen.gd |
| `Viewport` | 44 | varios (`get_viewport()`, `scaling_3d_scale`, `msaa_3d`, `use_taa`, `positional_shadow_atlas_size`, `use_occlusion_culling`, `screen_space_aa`, `anisotropic_filtering_level`, `mesh_lod_threshold`) |
| `MultiMeshInstance3D` | 31 | office_geometry.gd (motas); echo_view.gd (12); blood.gd (4); observer_view.gd |
| `MultiMesh` | 44 | varios |
| `OccluderInstance3D` | 1 | hotel_geometry.gd (`build_occluder`) |
| `ArrayOccluder3D` | 1 | hotel_geometry.gd |
| `ShaderMaterial` | 148 | varios |
| `StandardMaterial3D` | 92 | varios |
| `Shader` | 75 | varios |
| `CanvasLayer` | 12 | presentation.tscn; camcorder_osd.gd; hotel_ui.gd; intro_sequence.gd; observer_view.gd |
| `ColorRect` | 21 | presentation.tscn (lente, análogo); hotel_ui.gd (12); observer_view.gd |
| `Label3D` | 15 | office_props.gd (2); office_walls.gd (2); varios |
| `ImageTexture` | 24 | lighting.gd (perfiles); varios |
| `GradientTexture2D` | 10 | hotel_player.gd (proyector de la linterna) |
| `NoiseTexture3D` | 2 | ceiling_dust.gd |
| `ImmediateMesh` | 1 | game (no se leyó su uso) |
| `Tween` | 46 | varios (animaciones de la niebla de velo, puertas, etc.) |

Nodos del archivo de la escena: `presentation.tscn` tiene `WorldEnvironment` (`:15`), `Lens` (`CanvasLayer` `:17`), `Analog` (`CanvasLayer` `:27`), `Camcorder` (`CanvasLayer` `:37`).

---

## 25. Constantes clave (ruta:línea)

**Cámara y lente**
- `game/presentation/camcorder_look.gd:14` `BARREL` = 0.05.
- `game/presentation/camcorder_look.gd:22` `VIEW_FOV` = 78.
- `game/presentation/camcorder_look.gd:25` `ZOOM_MAX` = 6.
- `game/player/player.tscn:25-26` FOV 78, lejano 95.
- `game/presentation/camcorder_osd.gd:49` `LAMP_LIT` = 0.7.
- `game/presentation/camcorder_osd.gd:75` `ZOOM_HOLD` = 1.6.

**Etapa HDR**
- `game/presentation/camera/camcorder_effect.gd:34` `GRID` = (64, 36).
- `:37` `key` = 0.065; `:39-40` `min_ev` -1.5, `max_ev` 0.8.
- `:43-44` `speed_up` 1.1, `speed_down` 2.4.
- `:48` `smear` = 0.28; `:49` `smear_threshold` = 5.0; `:53` `smear_clip` = 12; `:57` `smear_spread` = 0.008; `:58` `SMEAR_CAP` = 0.16.
- `:61` `glare` = 1.0; `:62` `glare_threshold` = 1.5; `:63` `HALO` = 0.22; `:64` `GHOSTS` = 0.035; `:66` `GHOST_FLOOR` = 0.08; `:69` `CROWD` = 400.
- `:73` `knee` = 0.72; `:76` `toe` = 0.008.
- `:268` `SPREAD` (desenfoque) = 56.

**Motion blur**
- `game/presentation/camera/motion_blur_effect.gd:17` `SHUTTER` = 1/60; `:20` `MAX_PIXELS` = 48.

**Entrelazado**
- `game/app/presentation_rig.gd:104-110`: `FIELD_TIME` 1/60; `FIELD_FROM` 12; `FIELD_TO` 30; `FIELD_MAX` 48.

**Presentación del entorno**
- `game/app/presentation_rig.gd:20` `LIT_FOG_LENGTH` = 14.
- `game/app/presentation_rig.gd:82` `glow_hdr_threshold` = 0.9 con etapa HDR.

**Hotel: luces**
- `game/world/hotel/lighting.gd:23` `PROFILE_GAIN` = 1.25; `:26` `INCANDESCENT` = 2700; `:27` `FLUORESCENT` = 4100; `:33` `CAMERA_WHITE` = 3200.
- `game/world/hotel/hotel_geometry.gd:304-306` `LAMP_SIZE` 0.12, `PRACTICAL_SIZE` 0.2, `SCONCE_SIZE` 0.05.
- `:311` `SCONCE_REACH` = 24; `:323` `SCONCES_LIT` = 12; `:332` `SCONCE_FILL_REACH` = 40; `:333` `SCONCE_ENERGY` = 1.6; `:334` `SCONCE_FILL_ENERGY` = 0.7.
- `:388` `PROBES_SHOWN` = 24; `:389` `PROBES_KEPT` = 32; `:392` `NUMBER_REACH` = 20.
- `:799` `DECAL_REACH` = 14.
- `:1372-1375` fluorescente: 3.4 × PROFILE_GAIN; `:1391-1394` araña: 3.6 × PROFILE_GAIN; `:1401-1404` plafón: 3.6 × PROFILE_GAIN.
- `:1417-1418` alcance y atenuación de la luz de sala.
- `:1454` `BEACON_GLOW` = 9.0; `:1490-1491` baliza: energía 3.2, alcance 10.0; `:1493` la luz de la sala a 0,3.
- `:1902-1904` salida: energía 0.55, alcance 2.8.
- `:1843-1845` caja de ascensor: energía 2.4, alcance 5.5.
- `:2101-2104` aplique: 2600 K, alcance 3.4, atenuación 1.6.
- `:2326-2334` mueble: atenuación 2.2.
- `:2536-2543` sonda: intensidad 0.6, alcance 30, blend 0.1.
- `:1194-1204` neblina de vestíbulo: densidad 0.025.
- `game/world/hotel/room_layers.gd:79-80` `lamp_range` = max(10, 0,85 × lado).
- `game/world/hotel/bounce_light.gd:47-48` `SHOWN` 8, `BIG_SIDE` 20.

**Oficina: luces**
- `game/world/office/office_geometry.gd:126` `LAMP_ENERGY` = 2.3; `:135` `LAMP_DROP` = 0.9; `:141-142` atenuación 1.25 y 0.9; `:151` `LAMP_SPECULAR` = 0.
- `:162-168`: familias de lente (narrow, louvre, parabolic, wrap).
- `:172-174` `HALO_REACH` 1.8, `HALO_BELOW` 0.002, `HALO_ENERGY` 0.22; `:178` `LENS_GLOW` 4.0.
- `:195-199` pools: `POOL_ENERGY` 3.0, `POOL_SPECULAR` 0, `POOL_ANGLE` 75, `POOL_FALL` 1.0, `POOL_RANGE` 7.0.
- `:203` `GRADE` = {key 0.05, white (1.2, 1.0, 1.15), contrast 1.16, saturation 0.85, ssao_light 0.35}.
- `:210-212` `AIR_DENSITY` [0.008, 0.02, 0.02]; `AIR_ANISOTROPY` 0.6; `TORCH_AIR` 3.0.
- `:228-241` probes: `PROBE_PAST` 0.05, `PROBE_INTENSITY` 1.0, `FLOOR_LAYER` 8, `LENS_MIRRORED` 15, `PROBE_ONLY` 2.
- `:649` `RECEPTION_DIM` 0.9; `:662` `WINDOW_DIM` 0.7.
- `:684-740` pool_pair y rebote: `BOUNCE_FROM` 0.1, `BOUNCE_ANGLE` 90, `BOUNCE_REACH` 3.0, `BOUNCE_SHARE` 0.75, `FLOOR_SHARE` 0.25, `ROOM_REFLECT` 0.32.
- `:1070-1071` `WINDOW_LAMP_ENERGY` 7.0, `WINDOW_LAMP_ANGLE` 34.
- `:1094-1101` emergencia: `EMERGENCY_Y` 2.45, `EMERGENCY_REACH` 18, `EMERGENCY_CAST` 6, `EMERGENCY_CAST_COMPAT` 3, `EMERGENCY_ENERGY` 1.4, `EMERGENCY_RANGE` 9.0, `EMERGENCY_ANGLE` 55, `EMERGENCY_KELVIN` 2400.
- `:1265-1269`: `EMERGENCY_AIR` 3.0, `ACCENT_AIR` 1.5, `EXIT_AIR` 4.0, `POOL_AIR` 0.12, `LAMP_AIR` 0.25.
- `:1319-1321` motas: `MOTES_BOX` 4.0, `MOTES_PER_DUST` 14, `MOTES_MOST` 140.
- `:1997-1998` `BATTEN_CAST` (2.2, 62°, 6.0), `BATTEN_AISLE` (1.4, 34°, 4.5).
- `:2038-2041` `BATTEN_DOWN` (4.0, 85°, 1.4, blur 3.0), `BATTEN_UP` (3.0, 88°, 4.0), `BATTEN_UP_FROM` 0.35, `BATTEN_BOUNCE_FALL` 2.0.
- `:2322-2323` `EXIT_ENERGY` 0.1, `EXIT_RANGE` 1.2.
- `:2567-2570` `POOLS_CAST` 32, `POOL_KEEP` 1.0, `POOL_SIZE` 0.6, `POOL_UNDER_TUBES` 0.1.
- `:2619` `ACCENT_SIZE` 0.08.
- `:1014` `LIT_LEFT` 0.1 (oscuridad por dificultad).
- `game/floors/palettes/office_palette.gd:393` `LAMP_KELVIN` (2700 a 3500 K por tipo).
- `game/floors/palettes/office_palette.gd:222` `HEIGHTS` (2.95 falso techo; 4.4 losa en pasillo de servicio, sala de climatización y climatizadora).
- `game/floors/palettes/office_palette.gd:1003-1008` `TILE` 0.6; `TROFFER_PITCH` 3.0; `GRILLE_CLEAR` 0.9; `GRILLE_WALL` 1.0.

**Paletas del hotel**
- `game/floors/palettes/hotel_palette.gd:108-109` `HEIGHTS` (4.2 en recepción, salón, comedor, jardín y salón vacío; 3.15 en el resto), `HALL_HEIGHT` 4.8.
- `:112` `NEVER_DARK` [0, 4, 7, 8, 9, 10, 19, 20].
- `:185-186` `DARK_OWN` [0.23, 0.29, 0.36], `DARK_SPREAD` 0.45.
- `:190-191` `WEAR` 0.25, `KEPT` (0.25, 0.55).
- `:208` `SCONCE_ROOMS` [0, 10, 11, 12].
- `:212` `BATTEN_ROOMS` [4, 7, 8, 9].
- `:215` `CHANDELIER_HEIGHT` 4.0.

**Calidad**
- `game/presentation/graphics_presets.gd:27` `ORDER`; `:264` `UPSCALERS`; `:282` `SCALING_MODES`; `:290` `SWITCHES`; `:303-328` `of()`.

**Compatibilidad y atlas**
- `game/app/presentation_rig.gd:201` `COMPAT_SHADOW_ATLAS` = 4096.

---

## 26. Inventario de archivos leídos

Lecturas completas (todas las líneas, salvo lo que se indica):

| Archivo | Líneas | Qué hace |
|---|---|---|
| `project.godot` | 74 | Ajustes del proyecto: renderizador, pantalla, capas, shader globals. |
| `game/presentation/presentation.tscn` | 39 | Escena de presentación: WorldEnvironment, lente, OSD y cinta. |
| `game/presentation/hotel_environment.tres` | 46 | Entorno del hotel: tonemap, SSAO, SSIL, glow, niebla. |
| `game/presentation/camcorder_look.gd` | 52 | Constantes de la lente: barril, FOV, zoom, `render_fov`. |
| `game/presentation/camcorder_osd.gd` | 353 | OSD: REC, reloj, marcas de enfoque, zoom, brújula. |
| `game/presentation/camera/camcorder_effect.gd` | 477 | Etapa HDR del compositor: medidor, iris, smear, halo, grado. |
| `game/presentation/camera/motion_blur_effect.gd` | 190 | Estela de giro de cámara por obturador de 1/60 s. |
| `game/presentation/graphics_presets.gd` | 365 | Tabla de los cinco presets y funciones de escalado y de elección. |
| `game/presentation/shader_warmup.gd` | 194 | Dibujo previo del piso para compilar pipelines. |
| `game/presentation/materials/*.tres` (49) | varios | Materiales del hotel. |
| `game/presentation/materials/office/*.tres` (56) | varios | Materiales de la oficina. |
| `game/presentation/shaders/*.gdshader(inc)` (18+4) | — | Solo tipo, modo, lectura de textura; no leídos en detalle. |
| `game/floors/palettes/hotel_palette.gd` | 297 | Paleta del hotel: tipos, altura, luz, dark, sconces, batten. |
| `game/floors/palettes/office_palette.gd` | 1217 | Paleta de la oficina: tipos, kelvin, troffers, techo, suelos, paredes. |
| `game/app/capture_styles/locust_capture.gd` | 246 | Posturas de captura de la criatura y de la cinta. |
| `game/app/capture_styles/lurker_capture.gd` | 284 | Captura de la criatura del techo. |
| `game/app/capture_styles/lurker_score.gd` | 135 | Tiempos de la captura de la criatura del techo. |
| `game/app/presentation_rig.gd` | 494 | Montaje del entorno, compositor, lente, zoom, ajustes del preset. |
| `game/world/hotel/lighting.gd` | 124 | Perfiles fotométricos y color por temperatura. |
| `docs/REALISM.md` | 538 | Diario del fotorrealismo: fases, pruebas, coste y decisiones. |
| `docs/PERFORMANCE.md` | 683 | Auditoría de rendimiento, presets, medidas y piso 2. |
| `.claude/specs/visual_vuelta_grande.md` | 118 | Estado visual del piso 2 y pendientes del autor. |
| `game/player/player.tscn` | 48 | Cámara y linterna del jugador. |
| `game/world/hotel/hotel_geometry.gd` | 3298 (parcial) | Luces, sondas, decals, polvo, rondas, apliques, baliza. Leídos: 45-47, 280-312, 762-803, 1054-1100, 1182-1215, 1348-1453, 1458-1500, 1542-1558, 1839-1868, 1865-1920, 2066-2126, 2326-2352, 2535-2660, 3078-3160, 3272-3298, más greps. |
| `game/world/office/office_geometry.gd` | 2841 (parcial) | Constantes, grade, pools, rondas de luz, aire, motas, lámparas, acentos, emergencia. Leídos: 126-262, 663-740, 1224-1372, 1924-2126, 2301-2330, 2533-2600, 2700-2722, 2774-2790, 2818-2841, más greps. |
| `game/world/hotel/bounce_light.gd` | 269 (parcial) | Rebote: constantes y funciones (grep), cabecera. |
| `game/world/office/office_bounce.gd` | 126 (grep) | Rebote de la oficina. |
| `game/world/hotel/room_layers.gd` | (grep) | Capas de render y `lamp_range`. |
| `game/player/hotel_player.gd` | 844 (parcial) | Linterna, piloto, enfoque, cámara. Leídos: 170-214, 360-440, 517-575, 600-665. |
| `game/app/hotel_main.gd` | 2123 (parcial) | Enlaces del render, ronda de visibilidad, oclusión. Leídos: 1788-1856. |
| `game/world/interactables/hotel_television.gd` | (parcial) | Luz de la tele. |
| `game/services/settings_service.gd` | (parcial) | Ajustes de fábrica y escalado. Leídos: 6-8, 415-430. |
| `game/ui/hotel_ui.gd` | 2370 (parcial) | Capas de la interfaz y `marks_view`. Leídos: 120-130, 246-318, 1941-1960, 2078-2082, 2165-2180. |
| `game/enemies/lurker/ceiling_dust.gd` | 404 (parcial) | Polvo y velos. Leídos: 1-30, 60-90, 140-210, 380-400 (aprox.). |
| `game/world/office/office_landmarks.gd` | 630 (grep) | Focos de hitos. |
| `game/world/office/office_accents.gd` | (grep) | `MOST` = 3. |
| `game/world/hotel/prop_factory.gd`, `room_dressing.gd`, `mouldings.gd`, `material_albedo.gd`, `stand_in_mesh.gd` | (grep) | Lámparas de mueble, decals, molduras, albedo del rebote. |
| `game/world/office/office_props.gd`, `office_walls.gd`, `office_fittings.gd` | (grep) | Clases de render (Label3D, MultiMesh). |
| `game/app/observer_view.gd`, `game/app/death_tape.gd`, `game/app/blood.gd`, `game/enemies/locust/echo_view.gd`, `game/enemies/lurker/lurker_visual.gd` | (grep) | Clases de render (Camera3D, MultiMesh, Decal, DirectionalLight3D). |
| `game/app/hotel.tscn` | 25 | Escena principal: instancia `Presentation`. |
| `tests/` (cabeceras y greps) | — | Tests listados en §23. |
| `.claude/godot-api/doc/classes/Environment.xml`, `DisplayServer.xml`, `RenderingServer.xml`, `Viewport.xml` | (grep) | Verificación de valores de enum. |

---

## 27. Hechos que complican portarlo a otro motor (sin diseño)

1. **Sin lightmaps en partida:** el piso se genera al cargarlo; los lightmaps solo se hornean en el editor (`docs/PERFORMANCE.md:440`). El rebote es un VoxelGI por sala horneado en hilos al cargar (`docs/REALISM.md:254-261`).
2. **Contención de la luz por capas de render:** la luz de cada sala se queda en su sala por capas de render (16 capas, `room_layers.gd:28-29`) y por máscaras de culling de la luz. El VoxelGI inyecta la luz sin mirar la máscara (`docs/REALISM.md:449`).
3. **Proyectores de luz con forma fotométrica:** solo funcionan con sombra (`lighting.gd:10-12`); son equirectangulares con orientación fija (`lighting.gd:14-17`).
4. **Atlas de sombras compartido:** todas las lámparas con sombra comparten un atlas de 2048 a 8192 con profundidad 16 o 32 bits; lo que no tiene hueco se dibuja sin sombra y atraviesa paredes (`docs/PERFORMANCE.md:538`; `presentation_rig.gd:253-259`).
5. **Sondas de reflexión con atlas de 64 plazas**; se crean y destruyen por cercanía para no llenarlo (`hotel_geometry.gd:3082-3089`).
6. **Compositor con pases de cómputo GLSL compilados en el hilo de render**, con texturas 1×1 de exposición que la lente lee en la GPU; leer la exposición a CPU rompía el cierre del ejecutable exportado (`camcorder_effect.gd:79-83`, `:384-386`; `docs/REALISM.md:146-151`).
7. **Estela de giro calculada desde la cámara**, no desde el búfer de velocidad (`motion_blur_effect.gd:6-8`).
8. **Copia del búfer de color por cómputo** (el búfer no admite copia; `motion_blur_effect.gd:37-38`).
9. **Lectura de la pantalla (`hint_screen_texture`)** para el filtro de cinta y la lente, en capas canvas numeradas (`analog.gdshader:5`, `lens.gdshader:9`, `presentation.tscn:17-36`), con la interfaz filmada y el exterior no filmado (`hotel_ui.gd:300-315`).
10. **Dos renderizadores con funciones distintas:** Compatibility sin compositor, sin SSAO ni SSR, sin decals, sin proyectores de luz, con atlas de 32 bits y haz de linterna distinto (§2). Las dos rutas tienen que existir.
11. **Shader warmup:** Godot compila al primer dibujo. El juego dibuja el piso en una `SubViewport` pequeña antes de jugar (`shader_warmup.gd:5-11`).
12. **Parámetros de color por temperatura:** la cámara tiene un blanco fijo de 3200 K y el balance se aplica a cada luz, no a la imagen (`lighting.gd:30-32`, `:47-51`).
13. **Pantalla de carga:** el piso tarda entre 10 y 14 s en Forward+ y hasta 51 s en Compatibility (`docs/PERFORMANCE.md:462-467`, `:657`).
14. **Mallas y LOD generados por herramientas Godot:** las molduras y el kit se generan en código a partir de secciones (`docs/REALISM.md:466-471`); el catálogo de modelos se hornea desde glTF con `GLTFDocument` (`docs/REALISM.md:351`).
15. **Decals solo con Forward+.**
16. **Ajustes de la cámara por preset:** la lente, la cinta y el compositor se cambian en tiempo de ejecución (`presentation_rig.apply_settings()`, `:214-319`), no en carga.
17. **Licencias pendientes de los modelos:** el propio juego declara en `game/ui/hotel_ui.gd:120-123` que el modelo de The Locust lleva cláusulas no comerciales y de no obra derivada, y que «Realistic Female» es CompartirIgual, por lo que «no se puede vender». El piso 2 tiene modelos CC-BY, CC0 y dominio público (`visual_vuelta_grande.md:19`, `:34`). Esto es un hecho de los assets, no de render, pero afecta a lo que se puede portar.

---

## Sin comprobar

- **Shaders (cuerpo):** no se leyeron. Solo tipo, modo y lectura de textura (§14.2). Incluyen `lens.gdshader`, `analog.gdshader`, `ceiling_dust.gdshader`, `ceiling_halo.gdshader`, `finish.gdshader`, `wood_lacquer.gdshader`, `image_maps.gdshaderinc`, `surface.gdshaderinc`.
- **`hotel_geometry.gd` (3298 líneas):** no leídos en su mayoría (paredes, suelos, techos, `fittings`, `start_bounce` y `bounce_groups`, `corridor_runs`, `run_on`, `assign_layers`, `apply_static_light`, navegación, mallas, `build_navigation`, `decide_dark`, `set_room_power`, `drain`, `update_visibility` en detalle). Los conteos de luces por sala son estimados a partir de lo leído, no medidos.
- **`office_geometry.gd` (2841 líneas):** no leídos en su mayoría (`ceiling()` `:323-431`, `walls`, `columns`, `round_accents` cuerpo, `round_pools` cuerpo, `probes` de oficina `:2459-2520`, `emergency_unit` cuerpo, `landmarks`, `build_lifts`).
- **`office_bounce.gd` (126 líneas) y `bounce_light.gd` (269 líneas):** solo funciones y constantes (grep). `start`, `finish`, `bake` y `release` no se leyeron en detalle.
- **`room_layers.gd`:** solo las funciones `lamp_range`, `light_only` y `put_on` (grep). La asignación de capas de render no se leyó.
- **`echo_view.gd` (1153 líneas), `intro_sequence.gd`, `title_scene.gd`, `observer_view.gd`, `death_tape.gd`, `blood.gd`, `lurker_visual.gd`, `office_landmarks.gd`, `office_accents.gd`, `office_props.gd`, `office_walls.gd`, `office_fittings.gd`, `room_dressing.gd`, `prop_factory.gd`, `mouldings.gd`, `material_albedo.gd`, `stand_in_mesh.gd`, `hotel_television.gd`:** solo grep o parcial.
- **Las dos cifras de carga del piso en Forward+ (13,2 s y 15,2 s) y la de Compatibility (51 s):** tomadas de `docs/PERFORMANCE.md`; no comprobadas por una ejecución.
- **Cifras de rendimiento:** tomadas de los documentos (fechas entre septiembre y noviembre de 2026). No se midió nada en esta lectura. Los informes de `evidence/bench/` no se abrieron.
- **Números exactos de luces por sala:** no contados en una partida. Son el resultado de leer el código y los presets.
- **Documentos no leídos:** `docs/OFICINAS.md` (diseño aprobado del piso 2), `docs/ASSETS.md`, `docs/PLAN.md`, `docs/VISION_LOCUST.md`, `.claude/relevo.md`, `.claude/specs/spec_rediseno.md`, `.claude/specs/planta_real.md` y la mayoría de `.claude/specs/*.md`. Pueden contener más pendientes visuales del autor.
- **Ajustes del jugador** (`game/ui/hotel_ui.gd` `Ajustes`, `settings_service.gd` completo): solo los valores de fábrica y el escalado. No se leyeron las funciones de cada ajuste.
- **Lo que pasa en el hilo de render** (`_render_callback` en cada pase): leído en el código, no comprobado con un perfilador.
- **Shaders de la oficina de techo:** `ceiling_tile.gdshader` (60 líneas) y `ceiling_halo.gdshader` (19 líneas): no leídos.
- **Herramientas `tools/`:** no leídas (`lookdev_capture.gd`, `benchmarks/hotel_benchmark.gd`, `tools/dev/leak_who.gd`, `tools/dev/light_leak.gd` y otras que se citan en la documentación).
- **Ningún test se ejecutó.** No se hizo ninguna compilación ni ejecución de Godot en esta lectura.
