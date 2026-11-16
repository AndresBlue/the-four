# Ficha de hechos: vista de la criatura y presentación de un jugador-criatura (The Lurker)

Lectura del 16 de noviembre de 2026. Solo código y documentos; no se ha ejecutado Godot ni editado nada. Rutas relativas a `E:\Projects\The Four\`. Líneas comprobadas con grep o sed sobre el archivo actual.

## 0. Resumen

- El postproceso es un compositor (dos `CompositorEffect` sobre la cámara) más dos `CanvasLayer` de pantalla: lente (`lens.gdshader`) y cinta (`analog.gdshader`). El modo "cazadora" lo apaga casi todo.
- La visión de la criatura del piso 1 (The Locust) es una pantalla de eco: un quad sobre la cámara con tres shaders, y las lámparas del hotel se ocultan (`echo_view`). No existe ninguna vista térmica ni colormap en el código.
- Las luces de las oficinas se identifican por nodo (`TrofferPool`, `EmergencyLight`, `BattenSpot`, `LandmarkLamp`, `AccentSpot`) y por registro (`troffer_lamps`, `halos`, `emergency`, `landmark_lamps`, `accents`). En el hotel: `lights[room_id]`, `practicals`, `sconce_lights`, `exit_lamps`, `tubes`, `televisions`.
- Las 20 capas de render están todas asignadas (`0xFFFFF`). Ninguna queda libre.
- Hoy no hay jugador de la criatura en el piso 2: `Lurker.can()` solo da `ducts` (`lurker.gd:149`) y `control` vale `"ai"` por defecto (`creature.gd:50`).
- No hay efecto de destello al iluminar a la criatura. Solo existe la regla: una linterna que le cubre la cara impide que la vea (`lurker_senses.gd:184`).

## 1. Postproceso

### 1.1 Cadena (de dentro hacia fuera)

1. Cámara del jugador: `Camera` en `game/player/player.tscn` (fov 78, far 95, `cull_mask = 1048573`, línea 24). El zoom la cambia en `presentation_rig.gd:161-181`.
2. Compositor del `WorldEnvironment` (`game/presentation/presentation.tscn`), armado en `presentation_rig.gd:59-66`: `compositor_effects = [blur_effect, camera_effect]`. El desenfoque va antes porque "the light smears while it is being exposed" (L62). Ambos son `POST_TRANSPARENT` (`camcorder_effect.gd:348`).
3. `Environment` (`game/presentation/hotel_environment.tres`): con la etapa de cámara encendida, tonemapper lineal y `glow_hdr_threshold = 0.9` (`presentation_rig.gd:80-82`). Si no, lo autorizado (`authored_tone`, L55).
4. CanvasLayer "Lens" (`layer = 2`, presentation.tscn:17-20): `lens.gdshader` en su ColorRect "Screen". Visible si `LOOK.lens and not hunter and not level.observer` (`presentation_rig.gd:141`).
5. CanvasLayer "Analog" (`layer = 5`, presentation.tscn:27-30): `analog.gdshader`. Siempre activa. Es `level.post_material` (`presentation_rig.gd:38`).
6. CanvasLayer "Camcorder" (`camcorder_osd.gd`, presentation.tscn:37): OSD.
7. Por encima: `ObserverPanel`, `layer = 7` (`observer_view.gd:149-151`).

Sin RenderingDevice (headless, Compatibility) no hay compositor y se mantiene AgX (`presentation_rig.gd:56-58`).

### 1.2 Shaders de pantalla y uniformes

`game/presentation/shaders/analog.gdshader` (canvas_item, `screen_texture` L5, hint_screen_texture):
- `vhs` (L6, 0.18), `grain` (L7, 0.12), `chromatic` (L8, 0.08), `scanlines` (L9, 0.35), `tint` vec3 (L11, (1.02,1.0,0.9)), `vignette` (L12, 0.45), `enclosure` (L14), `signal_loss` (L18, nieve), `tape_hit` (L25), `tape_band` (L26), `tape_fray` (L29), `rewinding` (L32), `marked` bool y `marks` sampler (L44-45, textos sobre la nieve), `chroma_taps` int 2..7 (L48), `lite` bool (L52).
- Funciones: `hash`, `noise1`, `rgb_to_yiq`, `yiq_to_rgb`, `tap`, `mark_tap`, `graded`, `fragment` (L54-90 en adelante).

`game/presentation/shaders/lens.gdshader` (canvas_item, `screen_texture` L9):
- `barrel` (L13, 0.05), `scale` (L14, 0.8), `chromatic` (L16, 0.3), `vignette` (L18, 0.45), `noise` (L23, 0.35), `gain_map` sampler (L24, exposición de la etapa de cámara leída en GPU), `field_shift` vec2 (L29, peine de campos entrelazados), `detail` (L32, 0.35).
- Funciones: `hash`, `distort`, `tap`, `fragment` (L34-51 en adelante).

`game/presentation/camera/camcorder_effect.gd` (CompositorEffect, compute GLSL 450 embebido en strings): `METER`, `IRIS`, `SMEAR`, `SPREAD`, `BRIGHT`, `BLUR`, `GLARE_MEAN`, `GRADE` (L106-300). Pasadas en `_render_callback` (L435-477): meter, iris, smear+spread (si `smear > 0`), bright+blur+blur+glare_mean (si `glare > 0`), grade (L63-76).
- Parámetros: `key` 0.065 (L37), `min_ev`/`max_ev` -1.5/0.8 (L39-40), `smear` 0.28 (L48), `glare` 1.0 (L61), `white_balance` ONE (L72), `knee` 0.72 (L73), `toe` 0.008 (L76), `HALO` 0.22 (L63), `GHOSTS` 0.035 (L64).
- `exposure_texture` (L84): textura 1x1 que lee la lente como `gain_map`.

`game/presentation/camera/motion_blur_effect.gd`: `samples` 8 (L15; lo fija el preset), `SHUTTER` 1/60 y `MAX_PIXELS` 48 (L17-22). El blur sale del giro de la cámara entre cuadros, no del velocity buffer (cabecera L2-13).

Materiales de postproceso: no encontrado ninguno fuera de los shaders anteriores. Los `.tres` de `game/presentation/materials/` son de superficie.

Escalares que escribe `presentation_rig` en cada ajuste: `vhs`, `grain`, `chromatic`, `scanlines`, `tint`, `vignette` (L301-308); `chroma_taps`, `lite` (L286-287); `gain_map` (L85); `field_shift` (L131); `noise`, `detail`, `vignette`, `chromatic`, `barrel`, `scale` (en `apply_lens` L143-146 y `update_zoom_lens` L177-178); `signal_loss`, `enclosure`, `vhs`, `chromatic` por cuadro (L387-400).

### 1.3 Cambio de modo

Un único punto de decisión:
- `hunter_seat()` (`presentation_rig.gd:187-189`): `level.observer and level.observer_view.echoing`, o `level.match_net.local_is_locust()`.
- `echo_seat()` (L194-196): `hunter_seat()` y (`level.observer` o `level.rule("plain_sight") == 0`).
- Consumidores: `apply_settings` (L222, `var hunter := echo_seat()`), `apply_camera(preset, hunter)` (L69-88), `apply_lens(hunter, reduced)` (L135-152), `configure_hotel` (L322-327, `hotel.echo_view = echo_seat()`).

| Modo | Activación | Qué cambia |
|---|---|---|
| Jugador | ninguna | lente (si preset), etapa de cámara, tonemapper lineal, cinta con tinte cálido (L308) |
| Cazadora (Locust) | `echo_seat()` | ver §2 |
| Observador, sin lectura | `level.observer` | sin lente (L141), luz propia del observador (`observer_view.gd:437-452`) |
| Observador, lectura de criatura (V) | `echoing` | ver §2; `observer_view.gd:317` llama `level.apply_settings()` |
| Ejecución | `execution` no vacía | sin shader propio. La cinta corta a nieve al morir su dueño (`presentation_rig.gd:383`, `static_level = 1.0`), `signal_loss` sube (L387) y `level.camcorder.signal_lost` (L388) |
| Menú | `session.state == MENU` | `apply_grade` devuelve lo autorizado (L336) |
| Cámara de un compañero | `WatchCamera` | copia `fov`, `near`, `far`, `cull_mask` de la del jugador (`revival.gd:272-279`) |

## 2. Lo que hace hoy la vista de cazadora al render

Con `echo_seat() == true`, `presentation_rig.apply_settings` (L214-319) hace:
- SSAO off (L223), SSIL off (L228), SSR off (L230), glow off (L236).
- Luz ambiente a 0 (L242). Comentario L239-241: lo iluminado "leaks the seen hotel into a reading that is supposed to be made of echoes".
- Niebla off (L243) y niebla volumétrica off (L244).
- AA: FXAA/SMAA off (L273); TAA off (L277). Autofocus off (L317).
- Etapa de cámara off (`camera_effect.enabled`, L70-72). Desenfoque de movimiento off (L76-77). Tonemapper autorizado (L80-82).
- Lente off (`lens_layer.visible = false`, L141). Fov fijo `LOOK.VIEW_FOV` = 78 (L147-152; `camcorder_look.gd:22`).
- Cinta: tinte a `Vector3.ONE`, monocromo (L308). `chromatic` del post a mitad de ajuste (L303). Grano y viñeta pasan a la cinta porque no hay lente (L300-304).
- Hotel: `hotel.echo_view = true` (L325). En `hotel_geometry.gd`: sin decals (`decal_shown`, L793, `and not echo_view`), y sin luces visibles (`light.visible = ... and not echo_view`, L3038 y L3045).

Lectura de eco (`game/enemies/locust/echo_view.gd`, cabecera L1-17). Tres lecturas en una imagen:
- "the dark": pantalla que sustituye el hotel por negro (`echo_field.gdshader`).
- "the grains": puntos estampados al clic (`echo_points.gdshader`).
- "the self": su propio cuerpo (`echo_self.gdshader`).
- Quad: `build_field()` (L340-352): `QuadMesh` hijo de la cámara, `custom_aabb` enorme, `render_priority = 120`, `ignore_occlusion_culling = true`.
- `echo_field.gdshader` L18 `render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled`; uniformes `now`, `shriek` (L26), `presence` (L30), `grain_amount`, `jitter_amount` (L31-32), `beam_origin`/`beam_axis`/`beam_range` (L39-41), `depth_map` (L22, hint_depth_texture).
- `echo_points.gdshader` L16 (`blend_add`): `wave_speed` 42, `age_limit`, `point_scale`/`point_min`/`point_max`, `through`, `steady`, `shriek`. `echo_self.gdshader` L8 (`blend_add`): `gain`, `slice_step`.
- Ritmo: `CLICK_RATE` 2.0 por segundo (`echo_view.gd:37`), `CLICK_JITTER` 0.22 (L42). La imagen se redibuja cada cuadro desde la cámara.

Observador con V (`observer_view.gd:294-319`, `toggle_echo`): crea `Ears` (L45-72; `EYE` (0,2.35,0), `ARM` 2.8 L50, `SHOULDER` 1.0 L51) y el `ECHO` de echo_view. Cada cuadro, `echo.advance(delta, creature.activity() == &"chase")` (L457). `fly()` pone la cámara en la cabeza de la criatura (L474-481: `global_position = creature.global_position + Ears.EYE`, `camera.position = Vector3(SHOULDER, 0, ARM)`, `camera.rotation.x = 0`).

Cámara del Locust jugador (`game/enemies/locust/locust_player.gd`): `CameraPivot` en EYE (L97-99), `SpringArm3D` con `spring_length = ARM` y `collision_mask = 1|8|128` (L100-111), `HunterCamera` fov 74 (L114), far 240 (L118), posición (0,0,ARM) (L120), `creature.camera = camera` (L121). La cámara hereda la base de la criatura.

## 3. Fuentes de luz y aparatos eléctricos

Convención: "nodo" es el `name` en escena; "meta" es `set_meta`. Emisión: `game/presentation/materials/*.tres` (hotel: `light`, `lift_light`, `wall_lamp_bulb`, `shade`, `lift_buttons`, `wall_lamp_cloth`) y `game/presentation/materials/office/glow_*.tres` (`glow_amber`, `glow_green`, `glow_red`, `glow_strip`, `glow_white`).

### 3.1 Hotel (piso 1, referencia)

| Fuente | Dónde | Tipo y valores | Identificación | Registro |
|---|---|---|---|---|
| Lámpara de techo de sala | `hotel_geometry.gd:1409-1456` (`lamp_light`); `room_lamp` L1348 | `OmniLight3D`, energía del spec (L1412), `omni_range` (L1441), `omni_attenuation` 1.25 (L1443) | meta `profile` (L1415), `room` (L1442), `off` (L1446) | `lights[room_id]` (L59; `drain()` L2950) |
| Tubo de servicio (batten del hotel) | `lamp_fixture` L1355-1407 | tubo emisivo | `tube`, `failing` | `tubes` (L84, append L1448), `flickers` (L82, L1450) |
| Apliques de pared | `sconce_light` L2097-2136 | `OmniLight3D`, `SCONCE_ENERGY` 1.6 (L333), range 3.4, perfil `"sconce"`, sombra on | meta `own_room` (L2132) | `sconce_lights` (L310, append L2135), `lit_sconces` (L116), `SCONCES_LIT` 12 (L323) |
| Lámparas de mesa y pie | `practical()` L2326-2351 | `OmniLight3D`, sombra on | sin nombre | `practicals` (L80, append L2349) |
| Cartel SALIDA | `exit_sign()` L1865-1938 (`OmniLight3D` L1899) | panel `exit_panel.gdshader` | sin nombre | `exit_lamps` (L121, append L1917), `exit_panels` (L120) |
| Luz de cabina del ascensor | `box_light()` L1839-1853 | `OmniLight3D`, energía 2.4, range 5.5, sombra on | nombre `CarLight` | `car_lamps` (L128, append L1850) |
| Baliza | `start_beacon()` L1470-1497 | `OmniLight3D` | sin nombre | `beacons` (L87) |
| Televisor encendido | `game/world/interactables/hotel_television.gd` L89-112 | `SpotLight3D` "lamp": `GLOW` (0.72,0.82,1.0) L33, `RANGE` 8 L34, `CONE` 55 L35, `ENERGY` 2.2 L37; `OmniLight3D` "Fill": `FILL` 0.5 L39, `FILL_RANGE` 4.5 L38 | pantalla con `tv_screen.gdshader` (L18) | `televisions` (`game/app/televisions.gd:15`), `lit_televisions()` L107 |
| Destello de foto (no es luz de sala) | `game/app/code_lock.gd:342-346` | `OmniLight3D` energía 2.4, range 7 | variable local `flash` | ninguno |

### 3.2 Oficinas (piso 2)

| Fuente | Dónde | Tipo y valores | Identificación | Registro |
|---|---|---|---|---|
| Lámpara de techo (troffer) | `office_geometry.gd` `lamp_fixture` L1954-1982; `room_lamp` L2119-2145 llama `lamp_light` (hotel L1409) | `OmniLight3D`; `LAMP_ENERGY` 2.3 (L126) x `PROFILE_GAIN` x `dim_of`; perfil `LAMP_PROFILE` "even" (L132); atenuación 1.25 (L141) o 0.9 si está sola (L142) | meta `fitted` (L2131) | `troffer_lamps` (L144; append L2128) |
| Luz de troffer sin sombra | `light_lamp` L2580-2587 | `light_only(light, 0)` si `lit_by_fittings` (L2575): la lámpara no ilumina y la luz la dan los pools | - | - |
| Pool de troffer | `pool_pair()` L684-737 (`troffer_pools` L672) | `SpotLight3D` "TrofferPool" (`label + "Pool"`), `POOL_ENERGY` 3.0 (L195), `POOL_ANGLE` 75 (L197), `POOL_RANGE` 7 (L199), `POOL_SIZE` 0.6 (L2599); sombra solo en `POOLS_CAST` 32 (L2597) | meta `energy` (L694), `casts` (L702), `own_room` (L703) | `round_pools()` L2601 (lista por `has_meta("casts")`) |
| Bounce de troffer | `pool_pair` L710-725 | `SpotLight3D` "TrofferBounce", `BOUNCE_REACH` 3 (L741) | meta `own_room` (L724), `energy` (L725) | - |
| Lente de troffer (emisiva) | `lens_key()` L432-446; `LENS_GLOW` 4.0 (L178) | material `troffer_lens_<kelvin>` con `emission` = color de la luz | mallas `Mesh_troffer_lens*` (`lenses_of` L1052-1059) | `room_lenses` (L1051); `dim_lenses` L2624 |
| Halo de techo | `ceiling_halo()` L557-605 | `MeshInstance3D`, shader `ceiling_halo.gdshader` (`HALO_SHADER` L257) | nombre `CeilingHalo` (L593) | `halos[room.id]` (L260, L599) |
| Ghost de lente (reflejo) | `lens_ghosts()` L606-633 | mesh emisivo solo para sondas | nombre `LensGhosts` (L624), capa `PROBE_ONLY` (L627) | - |
| Batten (fluorescente de instalación) | `batten_spot()` L2029-2065; `batten_lights()` L2072-2097 | `SpotLight3D` "BattenSpot" (L2032); "BattenUp" (L2077-2078); `BATTEN_DOWN` 4.0 (L2068), `BATTEN_UP` 3.0 (L2069) | mesh `Mesh_light_batten_%d` (L2101), `glow_surface` (L2107), `lit_glass` (L2113); modelo `mounted_fluorescent_lights_batten.res` (L2098) | `set_room_power` L1029-1049 |
| Emergencia (unidad de sala eléctrica) | `emergency_unit()` L1121-1189 | `SpotLight3D` "EmergencyLight" (L1170-1171); `EMERGENCY_ENERGY` 1.4 (L1098), range 9 (L1099), ángulo 55 (L1100), kelvin 2400 (L1101); piloto rojo `pip_material` emisivo 2.0 (L1166-1168) | nodo `EmergencyUnit` (L1150) | `emergency` (L1108, append L1188), `emergency_runs` (L1110) |
| Techo de sala de emergencia | `room_lamp` L2137-2139 | sin luz (`visible = false`, meta `off`) | - | - |
| Aplique de puerta de hito | `office_landmarks.gd` `door_light()` L221-236 | `SpotLight3D`, sombra off | nodos `LandmarkDoorHalo`, `LandmarkDoorWash` (`title`), meta `own_room` (L233) | `b.landmark_lamps` (L235); `landmark_lamps` (`office_geometry.gd:1288`) |
| Lámpara focal de hito | `office_landmarks.gd` L258-272 | `SpotLight3D` "LandmarkLamp", `FOCAL_ENERGY`/`FOCAL_REACH`/`FOCAL_ANGLE` | nodo `LandmarkLamp` | `landmark_lamps` (L272) |
| Color de hito | `office_landmarks.gd` `KINDS` L30-40 | window (1.0,0.86,0.66); electrical (1.0,0.58,0.2); security y machines (1.0,0.2,0.12) | - | - |
| Cartel de salida (oficina) | `exit_sign()` L2342-2355 | `EXIT_ENERGY` 0.1 (L2352), `EXIT_RANGE` 1.2 (L2353) | - | `exit_lamps` del hotel |
| Lámparas de mueble (flexo, banker, pie, expendedora) | `office_models.gd` `LIGHTS` L146-151; `light()` L283-300; `accent_spot` `office_geometry.gd:2656-2685` | `SpotLight3D` "AccentSpot" (L2661); `desk_lamp_banker` 1.4 (rango 2.8); `vending` 0.7 (rango 3.5, color (0.86,0.92,1.0)) | - | `accents` (`office_accents.gd`: `MOST` 3 L6, `rooms` L14, `by_sconce` L16); una luz de mueble por sala (`LIT_MOST` 1) |
| Expendedora | `office_props.gd:698-710` `vending()`; tubo `glow_white` L705; modelo `expendedora_attheseedof.res` (`office_models.gd:77`) | tubo emisivo + la luz de mueble de arriba | - | - |
| Lucecita de estación (buzón neumático) | `game/floors/objectives/files_objective.gd:104-123` | `OmniLight3D` "lamp", energía 0.6, range 1.5, `visible = false` hasta haber tarjeta; `STATION_LAMP` (1.0,0.62,0.25) L32; lentes `glow_amber`/`lamp_off` | locales `lamps`, `lenses` | - |
| Piloto del cuadro eléctrico | `game/floors/objectives/power_objective.gd:115-120` | `OmniLight3D` "glow", color (1.0,0.15,0.08), range 0.7, energía 0.25; `RED_PILOT` L56-57 | - | `red_pilot` |
| Minuteros (interruptores de temporizador) | `power_objective.gd` L121-141; `POWER_LOOK.timer_switch` `power_equipment.gd:169-172` | `OmniLight3D` "pilot", color (1.0,0.55,0.2), range 0.6, energía 0.4, `visible = false` hasta que corre | lentes `glow_amber`/`lamp_off` | `pilots`, `pilot_lenses` |
| Cuadro eléctrico (tablero) | `power_equipment.gd` `power_board` L52, `main_supply_box` L143, `lever_handle` L126; `BOARD` (2.6, 2.4, 0.2) L7 | sin luz propia; pilotos arriba | - | - |
| Lector de microfichas | `office_props.gd:731-744` | material `glow_fiche`, emisión `FICHE_GLOW`/`FICHE_ENERGY` | mesh con `glow_fiche` | - |
| Terminal IBM 3178 | `office_props.gd:471-472` (modelo `terminal_3178`) | pantalla: no encontrado material emisivo | - | - |
| Monitor CRT | `pieces/machines.gd:96-117`; pantalla `KIT.block(p, "screen", ...)` L112 | material `screen` sin emisión (`presentation/materials/screen.tres` no es emisivo) | - | - |
| Máquina de escribir | `pieces/mail_equipment.gd:109-131` | sin luz propia; el flexo de la ventanilla "sobre la máquina de escribir" está en OFICINAS.md:156 | - | - |
| Tiras de luz de mueble | `office_props.gd:449-453`, `458` (meta `light_strip`), `631-636` | emisivo `glow_strip` sin `Light3D` | meta `light_strip` | - |
| Lentes de aviso de los pilotos | `pieces/mail_equipment.gd:162-177` `lamp_lens(... key)` | claves `glow_amber`, `lamp_off`, `glow_red` | - | - |

### 3.3 Linternas y luces de los jugadores

- Linterna propia: nodo `Camera/Flashlight` (`game/player/player.tscn:28-39`): `SpotLight3D`, `visible = false`, `light_color` (1, 0.9, 0.74), `light_energy` 10.0, `light_volumetric_fog_energy` 0.35, `light_size` 0.03, `shadow_enabled` true, `shadow_bias` 0.04, `spot_range` 24, `spot_angle` 32, `spot_attenuation` 0.85, `spot_angle_attenuation` 0.8.
  - `hotel_player.gd:195` `torch = $Camera/Flashlight`; L199 `light_bake_mode = DISABLED`; L202 `torch_energy = torch.light_energy`; L253-256 la acción `flashlight` alterna `visible`; L660-663 calentamiento y energía (`torch_energy * warm * ... * torch_dim`); L132 `torch_dim` la baja la criatura. Forma: `plain_beam()` L378 (`PLAIN_BEAM` L376) o `beam_pattern()`.
  - Registro central: no encontrado. Lo lee `creature_sight.gd:84-92` (`torch_covers`) por `body.torch.visible`.
- Linterna remota: `game/net/remote_player.gd:88-112`: `SpotLight3D` "Flashlight", `TORCH_ENERGY` 8.0 (L22), volumetric 0 (L101), `light_size` 0.03, `spot_range` 24, `spot_angle` 32, hija de `camera` (L112), posición (0.24,-0.3,-0.25) (L111). Visible con `flags & 2` (L165), y apagada si la lleva la criatura.
- Piloto de grabación: `hotel_player.gd:203-216`: `OmniLight3D` "RecordingLamp", `PILOT_COLOR` (1,0.06,0.03) (L182), `PILOT_CARRIED` (0.035,0.7,1.4) (L185), hija de `camera`, visible solo si graba (`set_pilot` L667-673).

## 4. Capas de render y de luz

- Máscara total: `const ALL := 0xFFFFF` (`game/world/hotel/room_layers.gd:32`): 20 bits.
- Cámaras con `cull_mask = 1048573` (= 0xFFFFD, todas menos la capa 2): `player.tscn:24`, `remote_player.gd:86`, `observer_view.gd:144`, `files_objective.gd:409`. `revival.gd:278` copia la del jugador.

| Capa (valor) | Uso | Dónde |
|---|---|---|
| 1 (bit 0, valor 1) | por defecto: mallas de hotel y oficina; avatar de tercera persona | `avatar_visual.gd:92` (`2 if first_person else 1`) |
| 2 (bit 1, valor 2) | cuerpo propio en primera persona; cámara caída propia; `PROBE_ONLY` (cuerpos que solo ven las sondas) | `avatar_visual.gd:92`; `executions.gd:580` (`prop.layers = 2`); `office_geometry.gd:241` |
| 3 (bit 2, valor 4) | cuerpo de The Lurker (`LAYER`), su tinta y su vapor | `lurker_visual.gd:15` (`const LAYER := 4`), L154, L233 (`cloud.layers`) |
| 4 (bit 3, valor 8) | `FLOOR_LAYER` de suelo de oficina, para sondas de reflejo | `office_geometry.gd:232`, L2540, L2555 |
| 5 a 20 (bits 4 a 19, `ROOMS` = 0xFFFF0) | 16 capas de sala; geometría y lámparas de cada sala | `room_layers.gd:28-31` (`FIRST` 4, `COUNT` 16); `assign()` L107; `layer[room] = bit` L211; `mask[room] = lit` L219 |

- Capa libre: no encontrado. Las 20 están asignadas.
- Decals de la criatura excluyen su propia capa: `stain.cull_mask = 0xFFFFF ^ LAYER` (`lurker_visual.gd:169`), `grip_stain.cull_mask` (L178).
- `put_on` (room_layers.gd:54-59) solo toca mallas que tengan el bit 1 activo (`(mesh.layers & 1) == 0` → return). Una malla de capa 2 pura no se mueve de capa.
- Máscara de luz: sala por sala con `light_only` (`room_layers.gd:71-75`); en el hotel, `kept_lamps` (`hotel_geometry.gd:2212`); en oficina `light_only(light, 0)` (`office_geometry.gd:2584`); intro `tv_light.light_cull_mask = ~2` (`game/intro/intro_sequence.gd:611`).
- El "tope de 16" es de capas de sala (`COUNT`), no de luces: varias luces pueden compartir capa.
- Muy bajo (preset `static_light`, sin sombras): las lámparas iluminan por capa de sala (comentario `room_layers.gd:1-23`).

## 5. Cuerpo del jugador y de los remotos

- Propio, primera persona: `avatar_visual.gd:10` `@export var first_person`; L92 `mesh.layers = 2 if first_person else 1`; L93 sombra ON solo si `body_shadow`. `show_to_owner` (L363-366) pone capa 1 cuando lo ve el dueño desde fuera. `put_on_layers` (L368-375) oculta, cambia y muestra.
- Remoto: `remote_player.gd:77-80` crea `avatar` con `first_person = false`: capa 1, sombra on (`avatar_visual.gd:93`).
- Materiales por parte: `avatar_visual.gd:117-129` (`set_surface_override_material` por nombre de material), `refine_materials` L186-206 (duplica cada material y añade normal y roughness), `drop_materials` L134-140.
- Material distinto solo para la cámara de la criatura: no encontrado mecanismo. Opciones que el código permite: una malla duplicada en otra capa (no hay capa libre, §4), o un postproceso que mire la lectura de la criatura (no existe, §1).
- Colisión propia: `CapsuleShape3D` radio 0.3, altura 1.8 (`player.tscn`, sub-recurso "Capsule"); `collision_layer = 4`, `collision_mask = 169`.

## 6. Cuerpo de The Lurker

### 6.1 Escena y modelo

- Cuerpo físico: `game/enemies/lurker/lurker_creature.tscn`: `CharacterBody3D` "Lurker", `collision_layer = 32` (= `BODY_LAYER` de `lurker.gd:53`), `collision_mask = 0`, esfera de 0.3 en (0, 0.42, 0.1), hija `Visual` = `lurker.tscn`.
- Visual: `game/enemies/lurker/lurker.tscn`: `Node3D` "Lurker" con `lurker_visual.gd` y `Model` = `assets/enemies/lurker/lurker.glb` (5.5 MB).
- GLB (leído de su cabecera JSON): 143 nodos, 1 malla `lurker_body.001`, 1 skin, materiales `lurker_face`, `lurker_body`, `lurker_eyes`, `lurker_teeth`. Huesos clave: `body`, `abdomen`, `head` (`lurker_visual.gd:157`). Brazos con sufijos de letra (`clavicle_a.L`, `upperarm_a.L`, `forearm_a.L`, `hand_a.L`, dedos `thumb`/`index`/`middle`/`ring`/`pinky` en 3 segmentos), hasta `_f.L`.
- Materiales: `assets/enemies/lurker/lurker_body.tres`: `shading_mode = 0` (sin sombreado) y `albedo_color` (0,0,0): el cuerpo es negro y no recibe luz. `lurker_face.tres`: textura `lurker_lurker_face.png`, `roughness` 1. `lurker_matte.tres`: `vertex_color_use_as_albedo`.
- Escala: `@export var size := 1.62` (`lurker_visual.gd:26`).

### 6.2 Animaciones (lista literal del GLB)

`["crawl", "crawl_fast", "idle", "loom", "peek", "retreat", "scare", "vent_crawl"]`. Coincide con `CLIPS` (`lurker.gd:39`). No hay clips de salto, agarre, techo, pared ni esquina.

### 6.3 Agarre, asomada, esquina y salto

- Agarre de manos: procedural. `lurker_limbs.gd` es un `SkeletonModifier3D` con 7 cadenas (`LIMBS` L26: `a.L a.R b.L c.R d.L e.R f.L`). Cada mano busca apoyo en cualquier dirección (cabecera L1-24). `limbs.hands = crawling` (`lurker_visual.gd:162`, setter L240). Parámetros: `grip` (L112), `cling` (L115), `grips` diccionario de manos fijadas (L124).
- Fijación de una loseta: `lurker.gd:1164-1180` (`TILE_GRIP` 0.4 s).
- Tipo de superficie: `lurker.gd:49-51` `CLING_TRAY` 0.3, `CLING_BAND` 0.5, `CLING_CHANNEL` 0.6 (valor de `visual.cling`).
- Pared y techo: `lurker_shell.gd:700-703` `transform_of` (base con normal de la superficie); `lurker_motion.gd:193-203` `surface()`, `clinging()`, `transform()`.
- Asomada, esquina y partición (solo en alucinaciones, no en el cuerpo real): `lurker_hallucinations.gd`:
  - "peek" en marco (spot L579; cabeza a 1.7-2.0 m, `PEEK_HEAD` L30).
  - "partition" (L586-592): cabeza sobre la partición (`OVER_PARTITION` 0.25).
  - "corner" (L595-600): boca abajo en la esquina del techo (`up = Vector3.DOWN`, cabeza `top - UNDER_CEILING`, 0.35).
  - Posado: `lurker_poser.gd` `pose_peek` (L23-26, clip "peek" en 0.6-1.6 s), `pose_stare` (L29-31, clip "idle" en 0.8 s), `hold` (L33-37).
- Salto de techo a suelo: `lurker_motion.gd:497` `leap(to, seconds := LEAP_TIME)`. Constantes `LEAP_REACH` 7.5 (L72), `LEAP_TIME` 0.6 (L73), `LEAP_RISE` 0.3 (L74), `CLIMB_SPEED` 1.5 (L75). Condiciones: solo desde superficie (`surface()`), hacia abajo (`to.y < from.y`), sin columna en medio (L502). Sin clip: trayectoria procedural; `lurker.gd:675` `visual.present(...)`.
- Huida al techo: `lurker_motion.gd:432` `bolt(threat)`; clip "scare" (`lurker_brain.gd:1002`) o "crawl_fast" (L1041).
- Espera y quietud (`lurker_brain.gd`): `hold(look, "loom" if on_channel else "idle")` (L910); `hold(look, "peek")` (L779); `hold(locker, "idle")` (L1126); `go(..., "retreat")` (L1138).
- Estados del cerebro (`lurker_brain.gd:56`): `ROAM, LISTEN, STALK, PEEK, FREEZE, CREEP, CUE, TAKE, RECOIL, FLEE, TRANSIT, WAIT_ABOVE, HUSH, RETURN, AMBUSH`. Clips por estado en `BEATS` (L68-69): `STALK`→stalk, `PEEK`→peek, `FREEZE`→peek, `CREEP`→creep, `RECOIL`→scare, `FLEE`→scare, `TRANSIT`→transit, entre otros.

### 6.4 Piezas procedurales

- 7 manos y brazos: `lurker_limbs.gd` (`PROBES` L47: sondeos de 70 a -86 cm; `set_bone_global_pose` L494-517).
- Cabeza y ojos: `lurker_limbs.gd:645-691`. La cara se mantiene arriba aunque el cuerpo cuelgue (`UPRIGHT` L101, `upright_share` L127, bloque L661-677). Mira `look_point` (la cámara que dibuja, `lurker_visual.gd:309-310`).
- Cola (abdomen): `lurker_limbs.gd:282-284`.
- Suavizado de la presentación: `lurker_visual.gd:44-46` (`TURN_MOST` 6.0 rad/s, `LAG_TIME` 0.08 s, `LAG_MOST` 0.15 m); `present()` L250.
- Tinta y vapor: `fog()` (`lurker_visual.gd:215-235`) crea esferas con `lurker_darkness.gdshader`. Instancias "Ink" (L163, radio 0.95 x size) y "Vapour" (L189, radio 0.6 x size, `gloom` 4.0). El shader: `render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled` (L12); uniformes `axis_a`, `axis_b` (L15-16), `thickness`, `radius`, `density`, `vapour`, `face`, `face_clear`, `roots_a/b/w[9]` (L30-32), `spill` (L37), `depth_texture` (L39).
- Manchas: `Decal` "Stain" (L166-170) y siete "GripStain" (L171-180), cada una con `cull_mask = 0xFFFFF ^ LAYER`.
- Polvo del techo: `game/enemies/lurker/ceiling_dust.gd` (`ceiling_dust.gdshader`, `ceiling_dust_veil.gdshader`): partículas del techo, no la criatura.

### 6.5 Luz propia

- Ningún `Light3D` en `game/enemies/lurker/` (grep de `Light3D.new`). La criatura no emite luz.

## 7. Cámaras

- Jugador: `Camera` de `player.tscn` (pos (0,1.64,0), fov 78, far 95). Zoom por `LOOK.zoom_fov` y `LOOK.render_fov` (`presentation_rig.gd:161-181`; `camcorder_look.gd:28-47`). Movimiento de mano: consts `TREMOR` (`hotel_player.gd:140`), `BREATH` (L141), `GAIT` (L142), `SWAY_STIFFNESS` 110 (L151), `SWAY_DAMPING` 13 (L152), `SWAY_LIMIT` 0.1 (L153), `handheld_enabled` (L154). Muelle del giro en `_physics_process` (L285).
- Autoenfoque: preset `autofocus`, `var autofocus` (`hotel_player.gd:168`).
- Observador: `ObserverCamera` (`observer_view.gd:138-145`): far 400, fov 75, `cull_mask` 1048573. Vuelo libre, o seguimiento (`fly()` L471-496): por detrás (`following.global_basis.z * 3.2`, altura 2.4) con `look_at(following + (0,1.6,0))` (L487), que usa el "up" de mundo por defecto. Sin rotación de superficie.
- Cazadora (Locust): `HunterCamera` en `CameraPivot` (`locust_player.gd:97-121`). Hereda la base de la criatura.
- Ejecución: la víctima ve por su propia `Camera`. La cámara caída es el `MeshInstance3D` "FallenCamcorder" (`executions.gd:573-587`, `leave_camcorder`), colocada por `camera_fall.gd` (16 direcciones x 3 radios: `DIRECTIONS` L31, `RADII` L32; si la captura la levantó hacia arriba, `UP_PITCH` 55-84 grados (L25), `UP_ROLL` 18 (L26), `UP_REACH` 1.2 (L27)). `lurker_capture.gd:68` lee `body.camera.rotation.x`; comentario L140: "The tape is told to look up as the camera falls, at where she hangs."
- Compañero observado: `WatchCamera` (`revival.gd:272-279`).
- Mareo, lo que hay en el código:
  - La cara de la criatura queda derecha aunque el cuerpo cuelgue (`lurker_limbs.gd:661-677`).
  - El visual se suaviza (`lurker_visual.gd:44-46`). Un salto registrado o una reaparición se dibujan de golpe (comentario L40-43).
  - La cámara del observador no sigue la base de la criatura en el techo (`look_at` con "up" de mundo, `observer_view.gd:487`).
  - No encontrado código que rote la cámara del jugador con la superficie.

## 8. Sonido de presentación

- Buses (`default_bus_layout.tres`, `bus/n/name`): 1 Ambience (L114), 2 Music (L122), 3 Effects (L132), 4 Threat (L140), 5 Aura (L148), 6 EffectsEcho (L154), 7 ThreatEcho (L164), 8 Steps (L174), 9 Creature (L182; efecto `Ears` L188), 10 CreatureEcho (L190; efecto `EarsEcho` L196).
- Presencia de la criatura (`game/audio/world_audio.gd:142-150`): `AudioStreamPlayer3D` "CreaturePresence", bus `Threat`, `unit_size` 9.0 (L145), `max_db` 4.0 (L146), `volume_db` -80 (L147), `area_mask = ACOUSTIC_MASK` (512; L12, L148), `panning_strength` 0. Ruta: ver `route_source` (L486).
- Límites: `ROUTE_LIMIT` 42 m (L15), `ROUTE_SLACK` 10 m (L18): una ruta no se busca más allá.
- Eco de la ruta: `ECHO_BUS` (L19): `Effects` pasa a `EffectsEcho`, `Threat` a `ThreatEcho`. `PANNING` 1.15 (L23).
- Binaural: `CREATURE_BUS` (L28) elige `Creature` o `CreatureEcho`; `ITD_MS` 0.65 (L29), `EAR_SHADOW` 18 dB (L30). Los sonidos de la criatura llegan mono al bus y el efecto `Ears` reparte oído izquierdo y derecho.
- Voz de la criatura: `lurker_voice.gd:302` `play_direct(path, point, gain, bus := &"Creature")`, sin ruta. Uso en L282 (`CAR_DB` -8.0, L51).
- Lo que oye la cazadora: `hotel_locust.gd:732-738` `hear_route(point, radius)`: `reach = radius * HEARING_SCALE * hearing * reach_scale`, con `HEARING_SCALE` = 2.6 (`game/audio/noise_kinds.gd:25`, usado en `hotel_locust.gd:183`) y `hearing` (L23). Tipos de ruido: `game/audio/noise_kinds.gd:10` `NAMES` (Pasos, Carrera, Salto, Una puerta, Un portazo, Un armario, Una rendija, Un zumbido), `SPREAD` L13.
- Capacidades del Locust: `hotel_locust.gd:2166` `ABILITIES = [&"lifts", &"tv_travel", &"wardrobes", &"shriek", &"echo"]`; `can()` L2170.
- Oído de la criatura del piso 2: `lurker_senses.gd:204` `hear_route`; `lurker.gd:1346` la delega. `lurker.gd:149`: `can(ability)` solo responde a `&"ducts"`.

## 9. Rendimiento (`docs/PERFORMANCE.md`)

- L402: "El posprocesado pesaba más que la escena". La cinta y la lente son dos pasadas a pantalla completa, con 9 o más lecturas la primera y 5 la segunda, cada una con su copia del fotograma: "2,6 ms entre las dos, más 1,2 de glow y FXAA".
- L436: cinta, 9 lecturas por píxel o más, pasa a 3 (`tape_lite`) en Muy bajo. L438: en Muy bajo, "visión de eco" igual que en Bajo.
- L188: visión de eco por preset. Bajo: ½ de granos y x2 de tamaño. Medio: base. Alto: más denso. Ultra: algo más fino y halo de fósforo.
- L251-257: "Visión de eco por preset". Bajo tenía presupuesto cero. Detalle en `docs/VISION_LOCUST.md`.
- L73: antes, cada chasquido de The Locust generaba todas sus direcciones en un tick (1,3 / 2,6 / 7,4 ms, dos veces por segundo). L92: ya se hace "bajo demanda... unos 0,1 ms por tick".
- L103: la niebla volumétrica y el SSIL a menor resolución "cambian el haz de la linterna y el rebote".
- L30-31: `--hide=Analog,Lens` quita la cinta y la lente de las capturas; `--passes` reparte la GPU por etapas (solo Forward+).
- No encontrado en el documento ningún dato medido de la vista de criatura del piso 2 ni de la vista de cazadora con el render completo.

## 10. Cómo ve hoy la criatura del piso 2 (dato para una vista térmica)

- Luz de un punto: `creature_sight.gd:55-58` `lit_point(level, point)`: sala con `hotel.lit(room.id)`; un hueco de gateo (`crawling_at`) cuenta como oscuro.
- Alcance de visión (`lurker_senses.gd:97-104`): `SIGHT_DARK` 20 m a oscuras; `SIGHT_LIT` 4 m en la luz ("the light blinds her", comentario L96); `BEAM_SEEN` 35 m con linterna encendida (L100); `SIGHT_HALF` 110 grados (L103); `SIGHT_NEAR` 1.5 m (L104).
- Linterna sobre la cara: `creature_sight.gd:84-92` `torch_covers()`: linterna encendida, cono `TORCH_FACE_ANGLE` 20 grados (L26), alcance `TORCH_REACH` 20 m (L27), rayo libre. `lurker_senses.gd:184`: si cubre la cara y no está bebida, `sees()` devuelve falso.
- Cara en la oscuridad: `DARK_FACE` 1.2 m (`creature_sight.gd:22`).
- Beber luz: `lurker_senses.gd:118` `DRAIN` (0.4, 0.7); `DRAIN_EASE` 1.5 (L120); `DRAIN_WOBBLE` 0.08 (L121). Aplicado en `lurker.gd` (bucle en `_process`, L1483-1517): `hotel.drain(room, sent)` (L1512, L1516), que escala `light.light_energy` sin crear luces (`hotel_geometry.gd:2949-2957`).
- Linterna bebida: `lurker.gd:1525` `drink_torches(seats, seconds)` y `lurker.gd:1535` `torch_step` (el haz baja y parpadea). `OFICINAS.md:362-370` describe el 15 % y el apagado total (no verificado línea a línea).
- Apagado de sala ("snuff"): evento `"snuff"` en `lurker.gd:1310` con `deep_room`; `DEEP` en el bucle de drenaje.
- Efecto visual de deslumbramiento: no encontrado. Búsqueda `flash|blind|dazzl|glare` en `game/enemies/lurker/` y `game/presentation/`: solo comentarios.

## 11. Lo que dicen los documentos de diseño

- `docs/OFICINAS.md` §4 "The Lurker: cómo se comporta" (L313): Sentidos (L315), Estados (L326), "La luz, de los dos lados" (L348-361), Ductos (L362), En cooperativo (L378), Dificultad (L398).
- §6 "La captura" (L471).
- §7 "Versus: ser The Lurker" (L488-506). Su vista (L490-493): "la oscuridad es su luz: ve lo oscuro en grises granulosos; lo encendido la quema: blanco, sin detalle, con un sonido que molesta; la linterna de un superviviente es un fogonazo que la ciega si la mira. Ve a quien sus sentidos le dan (sees()), como el eco de The Locust."
- §7 Habilidades (L494-500): "Beber la luz: apaga una sala ~6 s; espera ~25 s." "Asomarse: un susto que baja la cordura de quien la ve." "Coger: solo desde detrás de alguien."
- §7, con los sistemas de cada planta (L502-504): en la 2, "no toca el cuadro, pero bebe la luz de las zonas encendidas"; en la 3, los ventiladores la echan de los ductos cuando la lleva una persona.
- §4, "La luz, de los dos lados" (L348-361): bebe la luz a 3-4,5 m; se bebe la sala entera con 12 s, 4 s o 2,5 s según dificultad; la linterna "sigue sin batería" y, encendida, la delata (oye el clic y ve el haz desde 35 m).
- Contraste de hecho: la vista descrita en OFICINAS §7 (grises granulosos en lo oscuro, blanco sin detalle en lo encendido) no coincide con la propuesta del autor (térmica tipo plasma: oscuridad morada y azul, fuentes eléctricas amarillas y blancas, linternas sobre todas las luces). Se señala solo como hecho.
- Otros apartados útiles: §11.1 contrato de criatura (L622), §11.4 cómo se mueve (L736), §11.5 sentidos y cerebro (L755), §11.8 rendimiento (L826).

## 12. No encontrado (resumen)

- Vista térmica, colormap o shader de plasma: no encontrado (grep `thermal|termic|infrar|plasma|heat`: solo `game/ui/hint_view.gd:178`, un comentario).
- Jugador de la criatura del piso 2: no encontrado. No hay script de jugador en `game/enemies/lurker/`. `control` vale `"ai"` (`creature.gd:50`) y `set_control(kind)` existe (`creature.gd:74`; `lurker.gd:235`).
- Cámara de la criatura para un jugador: no encontrado.
- Capa libre de render: no encontrado (20 de 20 en uso).
- Material por cámara para un superviviente: no encontrado.
- Destello en pantalla al iluminar a la criatura: no encontrado.
- Clips de salto, agarre, techo, pared o esquina en el GLB: no encontrados. Los agarres son procedurales.
- Luz propia de la máquina de escribir: no encontrado.
- Material emisivo de la pantalla del IBM 3178: no encontrado.
- No leídos en detalle: `game/app/hallucinations/lurker_hallucinations.gd` (solo las funciones de poses, L545-603); `lurker_warning.gd`; `lurker_voice.gd` (salvo `play_direct`); `camcorder_osd.gd`; `hotel_locust.gd` (salvo `hear_route`); `docs/VISION_LOCUST.md`; `docs/LURKER.md`.
