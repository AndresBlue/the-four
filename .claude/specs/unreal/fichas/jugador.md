# Ficha de hechos: el jugador

Ficha para el port de The Four a Unreal. Solo hechos del repo: qué hace el código del jugador, con ruta y línea. No contiene diseño de Unreal. Lo que no se ha leído o no se ha comprobado está en el apartado 17.

Fecha de lectura: 14 de noviembre de 2026. Motor de referencia: Godot 4.7.2 stable (`.claude/godot-api/VERSION`). Rutas relativas a la raíz del repo. Solo lectura: no se ha escrito código, no se ha ejecutado Godot ni Unreal y no se ha tocado git.

Aviso: `.claude/worktrees/` contiene dos copias antiguas del juego (`admiring-lamarr-90bf9d` y `stoic-mirzakhani-2e4718`) con las mismas rutas pero otros números de línea. Esta ficha cita solo la raíz.

## 1. Cómo se leyó

- Completos: `game/player/player.tscn` (49), `game/player/hotel_player.gd` (844), `game/player/survivor_gait.gd` (98), `game/player/pad_feel.gd` (92), `game/player/kit_sounds.gd` (100), `game/player/avatars/avatar_visual.tscn` (4), `game/player/avatars/avatar_visual.gd` (778), `game/player/avatars/survivor_clips.gd` (211), `game/presentation/camera/camcorder_effect.gd` (477), `game/presentation/camera/motion_blur_effect.gd` (190), `game/presentation/camcorder_look.gd` (52), `game/audio/noise_kinds.gd` (43), `tools/avatars/bake_survivor_clips.gd` (408), `project.godot` (74).
- Por tramos (lo citado): `game/services/settings_service.gd` (1-50, 185-200, 242-245, 311-312, 332-385), `game/app/interaction.gd` (1-60, 138-260), `game/app/presentation_rig.gd` (1-80, 140-185), `game/app/revival.gd` (227-292), `game/app/observer_view.gd` (1-103), `game/net/remote_player.gd` (1-30, 225-290), `game/presentation/camcorder_osd.gd` (51-75, 168-200), `game/presentation/graphics_presets.gd` (183-240), `game/app/sanity.gd` (39-47, 100), `game/world/generation/floor_definition.gd` (20-26), `game/app/hotel_main.gd` y `tools/bots/bot_body.gd` (solo búsquedas).
- Tests: solo las líneas `check(...)` de los archivos del apartado 14, y conteos por búsqueda.
- Defaults del motor: `.claude/godot-api/doc/classes/CharacterBody3D.xml`, `Camera3D.xml`, `Light3D.xml`, `SpotLight3D.xml` y `ProjectSettings.xml`.
- Activos: listado de `assets/players/` y tamaños de los `model.fbx`. No se abrieron `clips.res` ni los FBX (binarios).

## 2. Inventario de archivos leídos

| Archivo | Líneas | Qué hace |
|---|---|---|
| game/player/player.tscn | 49 | Escena del jugador: CharacterBody3D, cápsula, cámara, linterna, pasos y avatar. |
| game/player/hotel_player.gd | 844 | Controlador: movimiento, cámara, linterna, zoom, movimiento de mano, enfoque, asomarse, inclinarse, escondites, transición y captura. |
| game/player/survivor_gait.gd | 98 | Números de la marcha, compartidos por el jugador y los bots: velocidades, aceleración, gravedad, estamina, agacharse, zancada y ruido de pisada. |
| game/player/pad_feel.gd | 92 | Mando: giro de cabeza con el stick derecho, y correr o agacharse por pulsación. |
| game/player/kit_sounds.gd | 100 | Sonido del interruptor de la linterna y del motor del zoom. Solo presentación. |
| game/player/avatars/avatar_visual.tscn | 4 | Escena mínima del avatar, con su script. |
| game/player/avatars/avatar_visual.gd | 778 | Cuerpo visual: carga del FBX, esqueleto, materiales, pies anclados, sangre y pose de captura. |
| game/player/avatars/survivor_clips.gd | 211 | Mezcla de clips de marcha según dirección, velocidad, agachado y salto. |
| game/presentation/camera/camcorder_effect.gd | 477 | CompositorEffect de la etapa HDR de la cámara: medición, iris, estela, halo, fantasmas y curva de vídeo. |
| game/presentation/camera/motion_blur_effect.gd | 190 | CompositorEffect de desenfoque por el giro de la cámara (obturador de 1/60 s). |
| game/presentation/camcorder_look.gd | 52 | Lente: campo de visión de diseño, zoom máximo y barril. |
| game/audio/noise_kinds.gd | 43 | Radios de ruido que oye la criatura, por tipo de ruido. |
| tools/avatars/bake_survivor_clips.gd | 408 | Herramienta (SceneTree) que hornea los clips de Mixamo en `assets/players/<id>/clips.res`. |
| project.godot | 74 | Sin sección `[input]`. Gravedad 20.0 (l. 53), nombres de capas (l. 42-49), render. |
| assets/players/ | listado | Tres carpetas de modelos (apartado 9.1). |

## 3. Controlador del jugador

### 3.1 Cuerpo y colisión

- Nodo raíz `Player`: `CharacterBody3D`, `collision_layer = 4` (capa 3 "Players", project.godot:44), `collision_mask = 169` (bits 1+8+32+128: capas 1 "Architecture", 4 "Closed doors", 6 "Creatures" y la 8, sin nombre; el comentario de player.tscn:13-14 la llama "open leaves"). player.tscn:10-15.
- Cápsula: `CapsuleShape3D` de radio 0.3 y altura 1.8, con `resource_local_to_scene = true`, así que cada instancia tiene la suya (player.tscn:5-8). Nodo `BodyShape` en y = 0.91 (player.tscn:18-19).
- Al agacharse: altura 1.05 con centro en 0.54. De pie: altura 1.8 con centro en 0.91 (survivor_gait.gd:32-35). La forma se reescribe solo cuando cambia (survivor_gait.gd:46-49).
- Comprobación para levantarse: cápsula de 0.3 de radio y 1.8 de altura, a 0.95 m sobre el origen, máscara 1|8|128 (survivor_gait.gd:51-61).
- Altura de ojos (`camera.position.y` antes del balanceo): de pie 1.64 (player.tscn:23; hotel_player.gd:53 y :349), agachado 0.9 (hotel_player.gd:349), a gatas 0.62 (hotel_player.gd:41). Cambia a 5.0 por segundo (hotel_player.gd:349).
- Cuerpo en vista propia: `first_person = true` (player.tscn:48). Sus mallas van a la capa visual 2, que la cámara propia no dibuja (`cull_mask = 1048573`, es decir, todas las capas menos la 2; player.tscn:24; avatar_visual.gd:88).

### 3.2 Movimiento

- Entrada: `Input.get_vector("left", "right", "forward", "backward")` si `active and not hidden and not reading` (hotel_player.gd:297). Empuje = longitud del vector, como mucho 1 (:299). Dirección = base del cuerpo × (x, 0, y), normalizada y multiplicada por el empuje (:300). Con mando, medio empuje da la mitad de la velocidad (survivor_gait.gd:82-84).
- Velocidades (survivor_gait.gd): agachado 2.0 m/s (:11), andar 3.8 (:12), correr 6.0 (:13). A gatas: 1.2 hacia delante y 0.6 hacia atrás (:38-39).
- Aceleración hacia la velocidad deseada: 22.0 m/s² (:15), con `move_toward` por eje horizontal (:85-88).
- Gravedad: 20.0 m/s² (survivor_gait.gd:16), aplicada a mano solo si el cuerpo no está en el suelo (:89). Este código no llama a `get_gravity()`, así que la gravedad del proyecto (project.godot:53, 20.0) no la usa el jugador.
- Salto: `velocity.y = 5.4` al pulsar "jump" en el suelo, sin estar agachado, oculto ni leyendo (hotel_player.gd:314-315). Emite el ruido de salto (:316).
- Correr: exige empuje mayor que 0.55 (`RUN_PUSH`, hotel_player.gd:12 y :309), no estar agachado (survivor_gait.gd:67), estamina mayor que 0 y no estar agotado. Con mando, "sprint" alterna (`pad_sprint_toggle`, por defecto true, settings_service.gd:6). El alternar se apaga tras 0.3 s sin mover el stick (`STOP_AFTER`, pad_feel.gd:28, :83-85) o al agotarse.
- Agacharse: "crouch" (Ctrl o B). Con mando alterna (`pad_crouch_toggle`, por defecto true, settings_service.gd:6; pad_feel.gd:66-71). Mientras lee documentos conserva su estado (hotel_player.gd:305).
- Estamina (survivor_gait.gd:18-21, :66-76): 100 como máximo. Correr resta 8.0 por segundo y al llegar a 0 queda agotado. Sin correr, tras un retardo de 3.0 s regenera 6.0 por segundo. Sale del agotamiento al llegar a 30 (`EXHAUSTED_UNTIL`). Cuenta mía: desde 100, correr hasta agotarse dura 12.5 s.
- Pasos por distancia: `step_phase` avanza `planar / stride × PI` (hotel_player.gd:326-331). Con empuje pequeño y no corriendo, el paso se oye como agachado (:337).
- `reset_survival()` pone `stamina = 100` directamente (hotel_player.gd:837).

### 3.3 Pendiente, escalones y suelo

- No hay ajustes de suelo en el código del jugador ni en player.tscn. Valores por defecto de Godot 4.7.2 (CharacterBody3D.xml): `floor_max_angle` 0.7853982 rad (45°), `floor_snap_length` 0.1, `floor_stop_on_slope` true, `floor_block_on_wall` true, `wall_min_slide_angle` 0.2617994 rad (15°), `max_slides` 6, `safe_margin` 0.001, `up_direction` (0, 1, 0), `motion_mode` 0 (GROUNDED).
- Escalones: no hay código de subida de escalón en estos archivos. El piso no tiene escaleras: floor_definition.gd:24 ("no stairs, no route a body could walk") y map_validator.gd:51 ("no door, no stair, only the lift"). La documentación de CharacterBody3D no menciona escalones (0 coincidencias de "step").
- Movimiento: `move_and_slide()` sin argumentos (hotel_player.gd:317). Snap: no se fija, así que vale el 0.1 por defecto.
- Plantas: `PITCH` 6.0 m por planta y `PLANTAS` 3 (floor_definition.gd:25-26). Si `position.y < planta_y(PLANTAS - 1) - 5.0`, vuelve a `spawn` y pierde la velocidad (hotel_player.gd:321-323).
- Física: 60 ticks por segundo por defecto (`physics/common/physics_ticks_per_second` = 60, ProjectSettings.xml). project.godot no lo cambia.

### 3.4 Estados que anulan el control

- `held` (ejecución): velocidad a cero y el cuerpo se coloca a mano (hotel_player.gd:285-291).
- `transit` (entrar o salir de un armario): el cuerpo se traslada con interpolación suavizada (:292-296, :750-766).
- `hidden`: no anda. La vista solo gira dentro de los límites del armario (:269-270, :297).
- `reading` (documentos, hoja, teclado): no anda ni mira (:46-47, :238, :242).
- `active == false`: sin entrada (:236) y `pad.reset()` (:311-312). Lo ponen hotel_main, revival, executions y observer (apartado 11).
- `crawling` (conducto): ver 3.6.

### 3.5 Mirar

- Ratón: `look_by(Vector2(-relative.x, -relative.y) * sensitivity / zoom)` (hotel_player.gd:241). Sensibilidad por defecto 0.0022 (settings_service.gd:6), rango 0.0005 a 0.008 (:196).
- Mando: `pad.look` (pad_feel.gd:38-51), con `pad_look` por defecto 2.6 y rango 0.6 a 6.0 (settings_service.gd:6, :197). Curva: 20 % lineal y el resto cuadrático (pad_feel.gd:19, :49). El eje vertical va al 75 % (`PITCH_SHARE`, :20, :51). Al llevar el stick al borde lateral, tras 0.15 s (`RIM_WAIT`, :24) el giro sube hasta ×1.8 (`RIM_BOOST`, :26) en 0.45 s (`RIM_RAMP`, :25, :47-48).
- Invertir vertical: `settings.values.invert` (por defecto false), en `look_by` (hotel_player.gd:261).
- Tope vertical: ±1.45 rad sobre `camera.rotation.x` (hotel_player.gd:271).
- Giro del cuerpo: `rotate_y(amount.x)` (:267). Oculto, el giro queda entre `hide_yaw` ± `lerpf(0.35, 0.7, peek)` (:269-270).

### 3.6 Conducto (a gatas)

- `crawling` se fija en cada tick desde `level.crawling_at(...)` (interaction.gd:219; hotel_main.gd:1690). Fuerza el agachado (hotel_player.gd:305). Velocidades a gatas (3.2), zancada 0.55 (survivor_gait.gd:40) y ojos a 0.62 (hotel_player.gd:41).
- El giro en yaw gasta un presupuesto que crece a 2.4 rad/s y tiene tope de 0.24 rad (`CRAWL_TURN_RATE`, hotel_player.gd:42, :263-265, :307).

## 4. Cámara

- Nodo `Camera` (Camera3D), hijo del jugador: posición (0, 1.64, 0), `fov = 78`, `far = 95`, `cull_mask = 1048573` (player.tscn:22-26). `near` no se fija y vale 0.05 por defecto (Camera3D.xml).
- FOV en juego: lo fija `presentation_rig.gd:161-181`. Con la lente activa, `fov = LOOK.render_fov(aspect, LOOK.zoom_fov(zoom), barrel)` (l. 176-180). Sin lente, `render_fov` devuelve el diseño (camcorder_look.gd:45-47). En la vista del cazador, el FOV vuelve a 78 (presentation_rig.gd:150).
- Campo de visión de diseño: `VIEW_FOV = 78.0` (camcorder_look.gd:22). Con zoom z: `2·atan(tan(39°)/z)` (camcorder_look.gd:28-29). Cuenta mía: a zoom 6 son unos 15.4° de diseño, antes de la corrección de render.
- Barril de la lente: `BARREL = 0.05` dividido por el zoom (camcorder_look.gd:14, :33-34).
- Zoom: rueda arriba y abajo, ×1.42 por muesca (`ZOOM_STEP`, hotel_player.gd:578, :242-245), y cruceta arriba y abajo (:248-250). `zoom_wanted` queda entre 1 y `ZOOM_MAX = 6.0` (hotel_player.gd:583-584; camcorder_look.gd:25). El zoom sigue a `ZOOM_SPEED = 2.4` unidades de log2 por segundo (hotel_player.gd:579, :587-590). Recorrido completo: unos 1.08 s (cuenta mía: log2(6) / 2.4).
- Sensibilidad con zoom: el giro del ratón y del mando se divide por el zoom (hotel_player.gd:241; pad_feel.gd:50).
- Movimiento de mano, todo multiplicado por `handheld_strength()` (hotel_player.gd:446-448, :488):
  - Temblor: `TREMOR = (0.0016, 0.0013, 0.0011)` rad (:138), con ruido 1/f de tres octavas (:452-461).
  - Respiración: `BREATH = (0.0022, 0, 0.0009)` (:139), multiplicada por `1 + (1 - stamina / 100) · 2` (:482-483).
  - Paso: `GAIT = (0.0055, 0.0022, 0.0035)` (:140), por 1.7 si va a más de 4.5 m/s y por 0.6 agachado (:487).
  - Muelle del giro: rigidez 110, amortiguación 13 y límite 0.1 rad (:149-151, :473-479). Integración implícita (:477).
  - Inclinación al asomarse: `offset.z -= lean_out / LEAN_REACH · LEAN_ROLL` (:490).
  - Aterrizaje: `sway_velocity.x -= 0.35` (:362).
- `handheld_strength()` = clamp(bob / 0.1, 0, 3) (hotel_player.gd:448). Con `reduced` o sin mano, vale 0 (:447). `bob` es el ajuste "Movimiento de cámara" (hotel_ui.gd:1610; rango 0 a 1, paso 0.05; settings_service.gd:199). Por defecto `bob = 0.4` (settings_service.gd:6), que da 3.0 (tope). Ver apartado 16.
- Balanceo al andar: amplitud = `bob × (0.1 agachado | 0.25 corriendo | 0.15 andando)` (hotel_player.gd:353). Altura = `(|sin(fase)| - 0.6) × amplitud × peso` (:354). Posición de cámara = (`sin(fase) × amplitud × 0.2 × peso`, `altura_ojos + altura`, 0) (:357). Cuenta mía con bob 0.4: subida máxima de 2.4 cm andando, 4.0 cm corriendo y 1.6 cm agachado.
- Suavizado entre ticks: `smooth_camera()` (hotel_player.gd:617-622) mezcla `tick_before` y `tick_after` con `Engine.get_physics_interpolation_fraction()` (:619). La interpolación de motor viene desactivada por defecto (ProjectSettings.xml) y el proyecto no la activa, así que el suavizado es propio.
- Enfoque automático: solo con el preset "autofocus" (hotel_player.gd:534-536). Crea un `CameraAttributesPractical` (:538-541). Rayo de 12 m con máscara 1|8|16 (:543). `FOCUS_BLUR = 0.15` (:528), `FOCUS_SPREAD = (0.25, 0.75)` (:529), `FOCUS_FADE_MOST = 20` (:532). Tras un salto grande de distancia, el foco "caza" y decae a 2.5 por segundo (:549-551), unos 0.4 s.
- Compositor: `presentation_rig.gd:59-66` crea `camcorder_effect` y `motion_blur_effect` y los pone en un `Compositor` del `WorldEnvironment` (presentation.tscn:15). Solo si hay `RenderingDevice` (presentation_rig.gd:58). Sin compositor en Compatibility (graphics_presets.gd:158-161).
- Desenfoque de movimiento: `samples` por preset, 0, 6, 8, 12 y 0 (graphics_presets.gd:191, 201, 211, 221, 233). Con `reduced`, 0 (presentation_rig.gd:76). Obturador `SHUTTER = 1/60` (motion_blur_effect.gd:17), `MAX_PIXELS = 48` a 1080 de alto (:20, :175). No se aplica por debajo de 0.5 px (:69-71).
- Etapa HDR (camcorder_effect.gd): cuadrícula de medición 64 × 36 (:34). Clave 0.065 (:37). EV entre -1.5 y 0.8 (:39-40). Subir 1.1 por segundo y bajar 2.4 (:43-44). Estela: umbral 5.0 (:49), tope por píxel 12.0 (:53), ancho 0.008 del ancho de la imagen (:57), tope de la estela 0.16 (:58), intensidad `ccd_smear` (0 o 0.28 según preset). Halo 0.22 (:63), fantasmas 0.035 (:64), suelo de fantasma 0.08 (:66), multitud 400 (:69). Umbral de brillo del halo 1.5 (:62). Rodilla 0.72 (:73). Punta 0.008 (:76). Orden de los pases: medición, iris, estela, extensión, brillo, desenfoque en dos pases, media de brillo y graduación (camcorder_effect.gd:435-477).

## 5. Linterna

- Nodo `Flashlight`: `SpotLight3D` hijo de `Camera`, `visible = false` al empezar (player.tscn:28-29). Color (1, 0.9, 0.74) (:30), energía 10.0 (:31), niebla volumétrica 0.35 (:32), tamaño de luz 0.03 (:33), sombra activa con sesgo 0.04 (:34-35), alcance 24 m (:36), atenuación 0.85 (:37), ángulo 32° (:38) y atenuación angular 0.8 (:39).
- En `_ready` (hotel_player.gd:197-200): horneado de luz desactivado (`BAKE_DISABLED`). En Forward+, `light_projector` es una textura radial de 256 px con 7 paradas (:388-399). En los demás renderizadores (`plain_beam()`, :376-377): ángulo 26°, atenuación 3.0, energía 11.0, sesgo de sombra 0.3, sesgo normal 4.0 y sin proyector (:374, :379-385). `torch_energy` toma la energía del nodo al empezar (:200).
- Movimiento: `top_level = true` (:216). Posición objetivo: `HAND_OFFSET = (0.24, -0.3, -0.25)` respecto a la cámara (:123, :434-439), apuntando a 7 m (:438). Sigue con `torch_follow = 9.0` por segundo (:124, :652). Si se aleja más de 1.5 m, se teletransporta (:648).
- Balanceo propio al andar (:641-647): yaw 0.03, pitch 0.012 y roll 0.02 con el paso, y un temblor de 0.004 a 0.005 m.
- Encendido: acción "flashlight" (hotel_player.gd:251-255). Calentamiento a 6.0 por segundo (:658). Energía = `torch_energy × calor² × (1 - 0.06 × moviéndose × |sin| × sway) × torch_dim` (:659-661). Parpadea mientras calienta (:660). `torch_dim` lo baja The Lurker (`drink_torches`, no leído).
- Linterna remota: `TORCH_ENERGY = 8.0` (remote_player.gd:22), frente a 10.0 del nodo local.
- Batería: no hay batería ni cargas en el código de la linterna. Las "cargas" que aparecen en el repo son las del ventilador del piso 2 (air_objective.gd:49, :370).

## 6. Camcorder, en lo que toca al jugador

- No es un nodo del jugador. Vive en la escena de presentación: `Presentation/Camcorder` (CanvasLayer con `camcorder_osd.gd`, presentation.tscn:5, :37), `Presentation/Lens` (CanvasLayer con un `ColorRect` "Screen" que usa `lens.gdshader`, presentation.tscn:17-19) y `Presentation/Analog` (presentation.tscn:27-29).
- Lámpara de grabación: `OmniLight3D` "RecordingLamp", hijo de la cámara (hotel_player.gd:201-214). Color (1, 0.06, 0.03) (:180), energía 0 por defecto, alcance 0.7 m y atenuación 1.4 (:183, :205-206), posición (0.035, -0.02, -0.05) (:212). Solo se ve si hay cinta grabando y la lámpara está encendida (`set_pilot`, :665-671).
- Zoom al OSD: `camcorder.set_zoom(player.zoom_fraction(), delta)` (hotel_main.gd:1807). `zoom_fraction = log(zoom) / log(6)` (hotel_player.gd:597-598).
- Barra de estamina: `camcorder.set_stamina(stamina / 100, exhausted)` (interaction.gd:257; camcorder_osd.gd:168).
- Batería de la cámara: no existe en estos archivos (búsqueda de "battery", "batería" y "charge" en `game/presentation/` y en el jugador, sin resultados de la cámara). Lo que se "recarga" en el OSD son las esperas del cazador, "like the stamina itself" (camcorder_osd.gd:63-64).

## 7. Interacción (raycast, distancias, capas)

- Origen del rayo: `camera.global_position`. Dirección: `-camera.global_basis.z` (interaction.gd:144, :165, :184).
- Objeto cercano (puertas, armarios, documentos, pistas, paneles): `focused_area()`, 2.0 m, máscara 1|8|16 (capas 1, 4 "Closed doors" y 5 "Hiding interactions"), con `collide_with_areas = true` (interaction.gd:143-148). Lo usan `focused_hide`, `focused_document` y `focused_hint` (:150-161).
- Compañero (online): 8.0 m, máscara 1|4|8 (capas 1, 3 "Players" y 4). Excluye su propio cuerpo (interaction.gd:163-171).
- Puerta: `DOOR_REACH = 2.4` m (:174), máscara 1|8|64 (incluye la capa 7 "Door sight occlusion"). Si el rayo no da una puerta, segundo intento desde dentro con `hit_from_inside`, solo puertas y máscara 8|64 (:183-196).
- Puerta a la espalda: radio 2.0 m (`DOOR_BEHIND_REACH`, :178), entre las de `doors_near` (:201-213).
- Tiempos: pulsación de hasta 0.28 s para escondite (`HIDE_TAP`, :55; :428). Mantener 1.0 s para abrir o cerrar despacio (`SLOW_HOLD`, :181).
- Teclas: "interact" en E (KEY_E) y en X del mando (settings_service.gd:7, :19).
- Llamada: `hotel_main.step_physics` (hotel_main.gd:1600) llama a `drive_local` (:1645), que delega en `interaction.drive_local` (hotel_main.gd:2077; interaction.gd:217).

## 8. Acciones de entrada

- project.godot no tiene `[input]`. Las acciones se crean en tiempo de ejecución en `game/services/settings_service.gd`. `apply_bindings()` (:336-380) las rellena con eventos a partir de `KEYS` (:7), `PAD_KEYS` (:19), `MOVE_AXES` (:48), `LOOK_ACTIONS` (:47), `PAD_TRIGGERS` (:32), `UI_PAD` (:39) y `UI_STICK` (:42).
- Deadzone de sticks 0.15 (`STICK_DEADZONE`, :46). Deadzone de gatillos 0.5 (`TRIGGER_DEADZONE`, :33).

| Acción | Teclado | Mando (por defecto) | Uso en el jugador |
|---|---|---|---|
| forward | W | Stick izquierdo arriba (MOVE_AXES, :48) | Andar; asomarse (hotel_player.gd:297, :686) |
| backward | S | Stick izquierdo abajo | Andar; retroceder a gatas (:306) |
| left / right | A / D | Stick izquierdo a los lados | Andar |
| sprint | Mayús | Botón L3 (LEFT_STICK), con alternar | Correr (:309) |
| jump | Espacio | A (el de abajo) | Saltar (:314) |
| crouch | Ctrl | B, con alternar | Agacharse (:305) |
| interact | E | X (el de la izquierda) | Puertas, escondites, documentos (interaction.gd) |
| flashlight | F | Y (el de arriba) | Linterna (:251) |
| sheet | Tab | BACK, y el panel táctil | Hoja (interaction.gd:59-70) |
| lean_left / lean_right | 1 / 3 | Cruceta izquierda / derecha | Asomarse por la esquina (:713-716) |
| look_left / look_right / look_up / look_down | (no) | Stick derecho (LOOK_ACTIONS, :47) | Mirar (pad_feel.gd:38-51) |
| locust_trace | Q | (no) | Solo la criatura |

- Ratón: movimiento relativo (sin acción) y rueda para el zoom (hotel_player.gd:241-245). La cruceta arriba y abajo también hace zoom (:248-250), por eventos, no por acciones.
- Reasignar: `bind(action, code)` (settings_service.gd:311), `bind_pad` (:242). Revisión del mando `PAD_REVISION = 2` (:24).

## 9. Avatares

### 9.1 Modelos

- Tres identificadores (avatar_visual.gd:3-4): `detective` ("Detective Masculino"), `detective_woman` ("Detective Femenino") y `realistic_female` ("Exploradora").
- Por defecto en ajustes: `character = 2` (Exploradora, settings_service.gd:6), acotado entre 0 y 2 (:193). Se cambia con `set_character(index)` (hotel_player.gd:843-844) y `configure(index, local_view)` (avatar_visual.gd:48-109).
- Escala: altura objetivo 1.78 m (avatar_visual.gd:90-91), giro de 180° en Y (:93), y el modelo sube para que el pie quede en el suelo (:92).
- Archivos (`assets/players/`):
  - `detective/model.fbx`, 1.98 MB; además `model.obj`, `model.mtl` y 28 archivos en `textures/` (14 pares de diffuse y normal, cada uno con su `.import`).
  - `detective_woman/model.fbx`, 28.5 MB; 30 PNG `model_N` y 6 PNG `model_alpha_N`.
  - `realistic_female/model.fbx`, 70.6 MB; 60 PNG `model_N` y 11 PNG `model_alpha_N`.
  - Cada carpeta trae `clips.res`, de 1.43, 1.43 y 1.15 MB.
- Vestido del detective: `dress_detective()` asigna los materiales del OBJ por nombre de parte (avatar_visual.gd:114-125).
- Materiales (`refine_materials`, avatar_visual.gd:193-225): copia por superficie. Relieve por nombre, cambiando `_diffuse` por `_normal` (:207). Rugosidad por palabra clave (:173-178). Especular 0.22 (`SPECULAR`, :186) y 0.36 en la piel (`SKIN_SPECULAR`, :187). Lo que no es ojo, dientes, lengua ni gafas (`WET`, :190) recibe tinte WORN (0.74, 0.7, 0.64) (:188), salvo la piel, que recibe LIVED (0.96, 0.93, 0.9) (:189). Se le quitan clearcoat y rim (:216-220). Pelo y cejas van con alfa a cobertura (:170, :221-224). `lod_bias = 6.0` (:191). Las mallas "eyeocclusion" se ocultan (:195-196).
- Sombras: `body_shadow` (por defecto true; según preset, graphics_presets.gd:187-229). Con `first_person` y sin sombra propia, la malla no proyecta sombra (avatar_visual.gd:89, :227-232).

### 9.2 Esqueleto, clips y pies

- Dos mapas de huesos: `MIXAMO` (`mixamorig_*`, avatar_visual.gd:12-18) para los dos detectives y `CHARACTER_CREATOR` (`CC_Base_*`, :19-25) para la Exploradora (:99).
- El esqueleto es el de más huesos de la escena (:94-98). Longitudes de miembros en reposo con `bone_gap` (:103-105).
- AnimationPlayer del FBX: en los detectives se paran (:78). En la Exploradora se quitan las pistas de la cámara importada (`forget_strays`), se reproduce el primer clip, se avanza 0 y se pausa (:72-77, :130-137).
- Clips: 16 horneados por `tools/avatars/bake_survivor_clips.gd` (`CLIPS`, :40-57): idle, walk, hurry, run, walk_back, run_back, walk_left, walk_right, run_left, run_right, crouch_idle, crouch_walk, crouch_back, crouch_left, crouch_right y jump. Tasa de 30 fotogramas por segundo (:81). Fuente: `models/mixamo/*.fbx` (:36), carpeta ignorada por git (`.gitignore:21`). Metadatos por clip: `speed`, `travel`, `phase0` (:406-408) y, en el salto, `takeoff`, `landing` y `settled` (:359-364).
- Mezcla (survivor_clips.gd):
  - Grupos: de pie, adelante (walk, hurry, run), atrás, izquierda y derecha. Agachado, los cuatro de agachado (:30-41). Ángulos en `HEADINGS` (:43).
  - Peso por dirección: `1 - |Δángulo| / (π/2)` (:127). Peso por velocidad en `by_speed` (:163-172).
  - Quieto por debajo de `STILL = 0.15` m/s (:46). El paso entra del todo hacia el 80 % del clip más lento (:123).
  - Transición: `BLEND = 0.12` s y `BLEND_RUNNING = 0.22` s, según velocidad / 6 (:49-50, :104-110).
  - Fase compartida: `phase += delta · speed · total / stride` (:175-184). Cada clip toma `phase0 + phase · length` (:155).
  - Salto: `JUMP_SPEED = 5.4` (:52) y `LANDS_AFTER = 0.25` s (:53). El instante del salto depende de `rising` (:150-153). El aterrizaje es el clip `land` (:133-140).
  - Aplicación: `reset_bone_poses()` y pose por hueso, con cuaterniones y posiciones (:186-211).
- Pies anclados (`lock_feet`, avatar_visual.gd:275-303): `PLANTED = 0.05`, `LIFTED = 0.03`, `LOCK_SPEED = 0.3`, `LOCK_REACH = 0.3`, `LOCK_GONE = 1.0` y `LOCK_RELEASE = 0.08` (:267-272). La pierna se corrige con IK de dos huesos (`reach_foot`, :308-331).
- Pose en cada tick: `update_pose(velocity, crouching, delta, grounded)` (:240-249), con `crouch_blend` a 6.0 por segundo y `air_blend` a 9.0 al tocar suelo o 5.0 al despegar (:243-244).

### 9.3 Sincronía

- Local: `avatar.update_pose(velocity, crouched, delta, is_on_floor())` en cada tick (hotel_player.gd:318), y en el tramo de transición (:760).
- Remoto: `avatar.update_pose(velocity, ...)` con el estado interpolado con `DELAY = 0.1` s (remote_player.gd:15, :240-267). Los estados llegan a 20 por segundo (`SEND_RATE`, match_net.gd:23, :278-280).
- Muerte y captura: `pose_capture` (avatar_visual.gd:617-778) escribe la pose en cada fotograma en lugar de `update_pose`. Sangre con `WORN_BLOOD` (:386-421).

## 10. Pasos y sonido propio

- Disparo: cada vez que `floori(step_phase / PI)` cambia (hotel_player.gd:333-339).
- Zancada (`stride`): a gatas, `CRAWL_STRIDE` 0.55 (survivor_gait.gd:40). Si no, agachado 1.333 (2.0 / 1.5), correr 2.4 (6.0 / 2.5) y andar 1.9 (3.8 / 2.0) (survivor_gait.gd:28-30, :91-92).
- Anticipo: el clip arranca si quedan 0.2 s o menos para el paso (hotel_player.gd:342-345). `step_impact_frame` queda para las pruebas (:431).
- Conjuntos de clips: `carpet_walk`, `carpet_run` y `hard_walk`, de `game/audio/footstep_segments.gd` (no leído en detalle; nombres en :3, :4, :18, :32). Elección al azar (`randi`, hotel_player.gd:418).
- Tono: aleatorio entre 0.95 y 1.05. Agachado, entre 0.9 y 0.97. Corriendo sobre suelo duro, entre 1.04 y 1.12 (hotel_player.gd:420-422).
- Volumen (dB): agachado -41, corriendo -22, andando -31, y +2 en suelo duro (hotel_player.gd:429). A gatas, `crawl_1.wav` y `crawl_2.wav` a -30 dB, con tono entre 0.92 y 1.05 (:404, :411-413).
- Dos voces que se turnan, `Footsteps` y `FootstepsTail` (player.tscn:41-45; hotel_player.gd:227-230). Bus "Steps" (default_bus_layout.tres:174). `max_db 12`, `max_distance 24` y `area_mask 512` (capa 10 "Audio areas", project.godot:49).
- Ruido que oye la criatura (noise_kinds.gd:25-43). `HEARD`, en metros: peek 10.5; crouch 8.0 y crouch_hard 12.0; walk 20.0 y walk_hard 25.0; jump 32.0; run 52.0 y run_hard 64.0; door 45.0; slam 62.0. El radio es `HEARD / HEARING_SCALE` con `HEARING_SCALE = 2.6` (:25, :42-43). Cuenta mía: andar 7.7 m de radio, correr 20.0, agachado 3.1 y salto 12.3.
- Tipo de ruido: `RUN` si corre sin estar agachado, y `FOOTSTEP` en el resto (survivor_gait.gd:96-98). Ruido de salto: `NOISE.Kind.JUMP` (hotel_player.gd:316).
- Quién lo oye: la señal `noise` (hotel_player.gd:22) se conecta en hotel_main.gd:1545, y cada puerta en :1546.
- Interruptor de la linterna: un `AudioStreamPlayer3D` en la linterna, con `unit_size 2.0`, `max_distance 14` y `area_mask 512` (kit_sounds.gd:34-42). Lo oyen el dueño y los cercanos (según la cabecera de kit_sounds.gd:6-10). Tres grabaciones de encendido y tres de apagado, nunca la misma dos veces seguidas (kit_sounds.gd:18-19, :45-54). Volumen -17 dB con ±1.5 dB al azar, tono entre 0.96 y 1.04.
- Motor del zoom: `AudioStreamPlayer` sin posición, solo para el dueño (kit_sounds.gd:66-69, :75-94). Se mantiene mientras el lente se mueve y se apaga en 0.06 s (`MOTOR_STOP`, :27).

## 11. Modo espectador

- Observador (`--observer`): sin cuerpo. `enter_observer_mode()` (hotel_main.gd:480) aparta al jugador (`player.active = false`, :482). La cámara libre es `observer_view.gd`: vuela a 22.0 m/s (`SPEED`, :76), entre 2 y 200 (:77), y ×4 al correr (`QUICK`, :79). Teclas en observer_view.gd:22-35.
- Compañero (muerto que mira): `revival.watch_teammates()` (revival.gd:244) llama a `watch_over(body)` (:267). Crea `WatchRig` (Node3D) con `WatchCamera`, que copia `fov`, `near`, `far` y `cull_mask` de la cámara propia (:274-279). La vista sale de `body.smooth_view()` (remote_player.gd:273-276) o de `body.camera.global_transform`. El cuerpo propio no se dibuja en la cámara del compañero.
- Fin: `stop_watching()` (revival.gd:227-242) devuelve la cámara propia.
- Quién pone `player.active`: hotel_main.gd:482, :772, :794, :1113 y :1171; revival.gd:200 y :245; executions.gd:300 y :415; observer_view.gd:435.

## 12. Clases y nodos de Godot que usa esta parte

Apariciones aproximadas de cada identificador en los archivos del jugador: `game/player/` (incluido avatars/), `game/presentation/camera/` y `player.tscn`. No incluye `tools/avatars/bake_survivor_clips.gd` ni `Compositor` (presentation_rig.gd:64).

| Familia | Clases o API (apariciones) | Total aprox. |
|---|---|---|
| Cuerpo y formas | CharacterBody3D (2), move_and_slide (1), is_on_floor (6), CollisionShape3D (2), CapsuleShape3D (2), SphereShape3D (2) | 15 |
| Consultas de física | PhysicsRayQueryParameters3D (3), PhysicsShapeQueryParameters3D (2), PhysicsDirectSpaceState3D (1), direct_space_state (4), get_world_3d (4) | 14 |
| Cámara | Camera3D (3), CameraAttributesPractical (3) | 6 |
| Luces y texturas | SpotLight3D (3), OmniLight3D (2), Light3D (3), Gradient (1), GradientTexture2D (2), Texture2D (1) | 12 |
| Audio | AudioStreamPlayer3D (8), AudioStreamPlayer (2), load (7) | 17 |
| Entrada | Input (11), is_action_pressed (5), get_vector (2), get_action_strength (2), is_action_just_pressed (1), InputMap (2), InputEventJoypadButton (2), InputEventMouseMotion (1) | 26 |
| Motor y tiempo | Engine (4), Time (2), OS (2) | 8 |
| Esqueleto y animación | Skeleton3D (4), AnimationPlayer (2), Animation (5), AnimationLibrary (1), get_bone_global_pose (13), set_bone_global_pose (3), set_bone_pose_rotation (1), reset_bone_poses (2), find_bone (2), rotation_track_interpolate (1), position_track_interpolate (1) | 35 |
| Mallas y materiales | MeshInstance3D (4), StandardMaterial3D (4), ShaderMaterial (2) | 10 |
| Compositor y GPU | CompositorEffect (2), RenderingDevice (32), RenderingServer (7), RDUniform (10), RDShaderSource (2), RDTextureFormat (3), RDSamplerState (2), Texture2DRD (1) | 59 |
| Nodos | Node (1), Node3D (7) | 8 |
| Matemáticas | Basis (13), Transform3D (7), Quaternion (3) | 23 |
| Aleatorio | randi (3), randf_range (7) | 10 |

- Fuera del recuento: `Compositor` y `RenderingServer.get_rendering_device()` (presentation_rig.gd:58-66); `CanvasLayer` y `ColorRect` de la lente y el OSD (presentation.tscn).
- Carga de FBX, solo en la herramienta: FBXDocument y FBXState (bake_survivor_clips.gd:124-128).

## 13. Dependencias de orden, física y azar

### 13.1 Orden de ejecución

- `_unhandled_input` (hotel_player.gd:235-254): mando (`pad.pressed`), ratón, rueda y cruceta de zoom, y linterna. Corre al recibir el evento, que puede caer antes o después de la física del mismo fotograma.
- `_physics_process` (:283-363): movimiento, salto, pasos, altura de ojos, inclinación y asomarse. A 60 ticks por segundo (apartado 3.3).
- `_process` (:624-661): suavizado de la cámara, `pad_look` (lee el stick en cada fotograma, pad_feel.gd:38-51), zoom, movimiento de mano, enfoque y la linterna en pantalla.
- Entre `_physics_process` y `_process`: `smooth_camera` usa los ticks guardados en `_physics_process` (hotel_player.gd:285, :359, :617-622). El orden se sostiene porque la interpolación es propia.
- `Input.is_action_just_pressed("jump")` se lee dentro de `_physics_process` (:314). `is_action_pressed` se lee en `_physics_process` (:297, :305, :309) y en `_process` (interaction.gd).
- `hotel_main.step_physics` (hotel_main.gd:1600) llama a `drive_local` (:1645), que fija `crawling` (interaction.gd:219) y `hard_floor` (interaction.gd:258-259; hotel_player.gd:115-116).
- Si `settings == null` al empezar, se apaga `_physics_process` (hotel_player.gd:231).

### 13.2 Física

- Gravedad propia: 20.0 m/s² (survivor_gait.gd:16), distinta de la del proyecto por no usar `get_gravity()`.
- Capas y máscaras: apartados 3.1 y 7.
- `move_and_slide()` con los valores por defecto de suelo (apartado 3.3).
- Consultas: rayos de 2.0 m (objeto cercano), 2.4 (puerta), 8.0 (compañero) y 12.0 (enfoque). La puerta a la espalda no usa rayo: es una distancia de 2.0 m a las puertas de `doors_near` (interaction.gd:201-213). Al asomarse, `cast_motion` de una esfera de 0.13 m con máscara 1|8 (hotel_player.gd:715-732).

### 13.3 Azar

- Sin semilla en estos archivos. Pasos: `randi()` (hotel_player.gd:411, :418) y `randf_range` (:412, :420-422). Interruptor y motor: `randi` y `randf_range` en kit_sounds.gd:49, :52-53, :83. No hay `RandomNumberGenerator`, `seed` ni `randomize()`.
- Estado estático: `static var last_click` (kit_sounds.gd:31) recuerda el último clic para todos los interruptores.
- Automatización: con `--automation` el movimiento de mano queda apagado, salvo que se pase `--handheld` (hotel_player.gd:233). Las pruebas de pasos miran `step_impact_frame` (:118, :431).

### 13.4 Señales

- `noise(point, radius, kind)` (hotel_player.gd:22) → hotel_main.gd:1545 (`on_noise`, :1565) y las puertas (:1546).
- `hiding_changed(entering, point, quiet)` (hotel_player.gd:24) → hotel_main.gd:299-300 (`world_audio.hide_cue` y `on_hide_changed`, :1559) y capture_test.gd:724.

## 14. Pruebas de tests/ que vigilan esta parte

- tests/hotel/survival_test.gd, funciones `kit_checks` (l. 37-85): clic de linterna con tres grabaciones y sin repetir (l. 51-52). Motor del zoom de 50 a 80 fotogramas y paro al llegar (l. 70). Paso de la rueda hacia atrás de 8 a 22 fotogramas (l. 80). Agacharse reduce cápsula y altura (l. 105), levantarse (l. 108), agotamiento (l. 115), recuperación (l. 119) y sin errores físicos (l. 95). Armarios y asomarse (l. 309-377). Inclinación con 1 y 3 (l. 395-408).
- tests/hotel/avatar_test.gd: esqueleto (l. 55), pie plantado sin deslizar (l. 71), rodilla al andar (l. 81), brazos (l. 89), agacharse baja caderas (l. 93) y mano al suelo (l. 95-98), salto (l. 110), amortiguación al caer (l. 117), vestido del detective (l. 127-128), ojos sin bolas blancas (l. 137), pelo y piel (l. 149-150).
- tests/hotel/hotel_test.gd: golpe de cada paso grabado frente a la pisada (l. 412, desfase máximo de 1.05 fotogramas), linterna con sombra en "Muy bajo" (l. 516), FOV de diseño con lente (l. 523) y proyector en Forward+ (l. 645).
- tests/hotel/scene_contract_test.gd: nodos `Player/Camera/Flashlight` (l. 13), cápsula de 1.8 tras agacharse en otra instancia (l. 17), acciones de mando (l. 56-99), correr y agacharse por pulsación (l. 80-90), reasignación (l. 92-93).
- tests/hotel/sanity_test.gd: cordura al empezar (l. 51), a oscuras (l. 62), con linterna (l. 63), en armario (l. 64), en sala encendida (l. 67) y siete minutos y medio a oscuras (l. 72).
- tests/hotel/capture_test.gd: 69 `check` (poses de captura, `hiding_changed` en l. 724). No leído por dentro.
- tests/hotel/bots_test.gd y tools/bots/bot_body.gd: los bots usan survivor_gait.gd (bot_body.gd:96-117). Solo búsqueda.
- tests/net/net_test.gd (l. 623 y 634): capas de malla de los compañeros.
- tests/office/lurker_fairness_test.gd (44 referencias) y tests/hotel/hotel_walkthrough.gd y hotel_batch.gd (acciones con `Input.action_press`): no leídos.

## 15. Cifras que definen cómo se siente (resumen, con referencia)

- Velocidades: 2.0, 3.8 y 6.0 m/s (survivor_gait.gd:11-13). Aceleración 22.0 (:15). Salto 5.4 (hotel_player.gd:315).
- Estamina: drena 8.0 por segundo, regenera 6.0 tras 3.0 s, agotado hasta 30 (survivor_gait.gd:18-21).
- Cámara: 78° de diseño (camcorder_look.gd:22); altura de ojos 1.64 (player.tscn:23); zoom hasta 6× con unos 1.08 s de recorrido (camcorder_look.gd:25; hotel_player.gd:579).
- Movimiento de mano: depende de `bob`, 0.4 por defecto (settings_service.gd:6; hotel_player.gd:448).
- Linterna: energía 10 (player.tscn:31), alcance 24 m (:36), ángulo 32° (:38); fuera de Forward+, 11 y 26° (hotel_player.gd:374).
- Pasos: la criatura oye andar a 20 m y correr a 52 m (noise_kinds.gd:34, :39).
- Cordura: 100/450 por segundo a oscuras, ×0.4 con linterna, 100/240 por segundo de recuperación en luz (sanity.gd:39-41).

## 16. Discrepancias encontradas en el código

1. `bob`: por defecto 0.4 (settings_service.gd:6). El comentario de hotel_player.gd:444-445 dice que "0.1 by default gives 1". Con 0.4 la fuerza es 3, el tope (hotel_player.gd:448). Cuenta mía.
2. Subida al andar: el comentario de hotel_player.gd:352-353 dice "about 1.5 cm walking and 2.5 cm running at the default setting". Con la fórmula de :353-354 y bob 0.4 salen 2.4 cm y 4.0 cm (cuenta mía).
3. Linterna remota: `TORCH_ENERGY = 8.0` (remote_player.gd:22), frente a 10 del nodo local (player.tscn:31).
4. Pasos remotos: la zancada y el umbral de carrera (`planar > 4.6`) están escritos a mano en remote_player.gd:283-285, no salen de survivor_gait.gd.
5. El proyecto no tiene sección `[input]` (project.godot). Quien busque ahí las acciones no las encontrará; están en settings_service.gd:336-380.
6. `models/mixamo/` está en la raíz del repo, pero `.gitignore:21` (`/models/`) lo ignora. El comentario de bake_survivor_clips.gd:6-9 dice que se guarda "outside the project".
7. Copias antiguas del juego en `.claude/worktrees/` (apartado de aviso): mismas rutas, otras líneas.

## 17. Sin comprobar

- No se ejecutó Godot ni se midió nada en pantalla. Las cifras de "cómo se ve" son las que dice el código.
- `Engine.get_physics_interpolation_fraction()` (hotel_player.gd:619 y remote_player.gd:275): la entrada de la API en el XML no tiene descripción, y la interpolación del motor está apagada. Qué devuelve con la interpolación apagada no está comprobado.
- Valores de `clips.res` (velocidades, fases, tiempos del salto) y contenido de los FBX: binarios, no abiertos. Los `speed` y `phase0` no están comprobados.
- `game/app/hotel_main.gd`: solo búsquedas. No están comprobados quién llama a `step_physics`, el orden completo de procesos, ni el origen de `frame_delta` en camcorder_effect.gd:103 y motion_blur_effect.gd:35.
- `game/presentation/lens.gdshader`, `analog.gdshader` y `hotel_environment.tres`: no leídos.
- `game/audio/footstep_segments.gd`: solo los nombres de los conjuntos.
- `game/world/hotel/hotel_door.gd` (`OPEN_SOLID`) y `hiding_place.gd` (`ENTER_TIME`, `LEAVE_TIME`, `QUIET_LEAVE_TIME`, `QUIET_EXIT`, `PEEK_AHEAD`): no leídos. Los tiempos de entrar y salir de un armario no están comprobados.
- `game/app/death_tape.gd` (cámara al morir, l. 190 y 567): no leído.
- `game/app/sanity.gd`: solo las constantes de las líneas 39-47 y 100. La lógica de `tick` no se leyó.
- `game/app/interaction.gd` (l. 260-431): no leído (sostener, soltar, armarios).
- `game/app/observer_view.gd`: solo las líneas 1-103 y las constantes 76-79.
- `game/app/revival.gd`: solo 227-292.
- `game/presentation/camcorder_osd.gd`: solo 51-75, 168 y 186-200.
- `graphics_presets.gd`: PRESETS en 183-240, por entradas. Que el orden de `NAMES` (l. 20) coincida con el de PRESETS no está comprobado.
- Cuentas mías (aritmética sobre el código, no medidas): FOV de unos 15.4° a zoom 6, subida al andar, estamina de 12.5 s, radios de ruido en metros.
- Gravedad del motor: no se comprobó que Godot 4.7 no aplique la gravedad del proyecto a CharacterBody3D. Lo que sí se comprobó es que este código no llama a `get_gravity()` (búsqueda en game/player, hotel_main.gd y game/world).
- Semilla del generador global al arrancar Godot: no comprobado.
- Estado de git: no se ejecutó git. El `git status` del arranque salía truncado y no se sabe si alguno de estos archivos está modificado.
- Los valores de `CharacterBody3D` (`max_slides`, `floor_max_angle`, etc.) son los de la documentación XML de `.claude/godot-api`, no de una ejecución.
