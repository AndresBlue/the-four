# Ficha de hechos: polvo, niebla y haces de luz

Fecha de lectura: 14 de noviembre de 2026. Solo lectura del código y de los documentos; Godot no se ejecutó. Las rutas son relativas a la raíz del proyecto. Las líneas se dan como `archivo:línea`. Los valores por defecto de Godot se comprueban en `.claude/godot-api/doc/classes/` (versión 4.7.2.stable, según `.claude/godot-api/VERSION`).

## 0. Lo que más importa

- Hay un solo `Environment` en todo el juego: `game/presentation/hotel_environment.tres`. Hotel y oficinas lo comparten.
- La niebla volumétrica es una rejilla global (`RenderingServer`) que el preset enciende con `fog_size > 0`. El tamaño de la rejilla y el filtro son los únicos parámetros que cambian con la calidad. La densidad, el albedo y la anisotropía son fijos.
- Solo las luces con `light_volumetric_fog_energy` distinto de 0 aportan a la niebla. Casi todas las luces del juego lo fijan a 0. Las que aportan son: la linterna del jugador (0.35), las lámparas de sala del hotel y de las oficinas en presets Medio o superiores (1.0), la luz de salida (0.12) y los velos de polvo (`FogVolume`).
- En las oficinas no hay `FogVolume` de neblina de suelo. Los troffers, las regletas, los focos de emergencia y los acentos de recepción están a 0 y no aportan a la niebla.
- Solo existen dos sistemas de partículas en el código: el polvo que cae del techo (`game/enemies/lurker/ceiling_dust.gd`) y las motas de polvo del hotel (`build_dust` en `game/world/hotel/hotel_geometry.gd`). No hay partículas en ninguna escena `.tscn`.
- El benchmark de los dos informes disponibles mide solo el preset Alto (calidad 2). No hay un A/B de la niebla en esos informes.

## 1. Niebla volumétrica hoy

### 1.1 El Environment compartido

Conexión: `game/presentation/presentation.tscn:3` (ext_resource) y `:15-16` (WorldEnvironment con `environment = ExtResource("1")`). Es el único Environment de juego. Los demás `.tscn` que mencionan `Environment` son copias de galería en `evidence/` y `tools/workbenches/`.

Valores fijados en `game/presentation/hotel_environment.tres`:

| Propiedad | Valor | Línea |
|---|---|---|
| `fog_enabled` (niebla de profundidad) | true | :33 |
| `fog_density` | 0.012 | :35 |
| `fog_light_color` | (0.02, 0.018, 0.015) | :34 |
| `fog_sky_affect` | 0.0 | :36 |
| `volumetric_fog_density` | 0.006 | :37 |
| `volumetric_fog_albedo` | (0.78, 0.72, 0.6) | :38 |
| `volumetric_fog_emission` | (0, 0, 0) | :39 |
| `volumetric_fog_anisotropy` | 0.45 | :40 |
| `volumetric_fog_length` (valor autorizado; el rig lo cambia, ver 1.2) | 48.0 | :41 |
| `volumetric_fog_ambient_inject` | 0.15 | :42 |

Valores que no están en el `.tres` ni en el código del juego (quedan los de Godot):

- `volumetric_fog_temporal_reprojection_enabled` = true y `volumetric_fog_temporal_reprojection_amount` = 0.9 (`.claude/godot-api/doc/classes/Environment.xml:221-223`).
- `volumetric_fog_detail_spread` = 2.0 (Environment.xml:207), `volumetric_fog_emission_energy` = 1.0 (:211), `volumetric_fog_gi_inject` = 1.0 (:215), `volumetric_fog_sky_affect` = 1.0 (:219), `fog_light_energy` = 1.0 (:73), `fog_height` = 0.0 (:67).
- Ningún archivo del juego ni de herramientas escribe `temporal_reprojection`, `detail_spread`, `gi_inject` ni `emission_energy` (búsqueda vacía).

Otros valores del `.tres` que afectan a la imagen de la niebla o al tono:

- `tonemap_mode` = 4 (AgX, :10), `tonemap_exposure` = 1.05 (:11).
- Glow: `glow_intensity` 0.3 (:27), `glow_strength` 1.0 (:28), `glow_bloom` 0.0 (:29), `glow_blend_mode` = 1 (Screen, :30), `glow_hdr_threshold` 1.3 (:31), `glow_hdr_scale` 1.2 (:32). `glow_enabled` no está en el `.tres` (es false por defecto): lo pone el rig por preset.
- Ajuste de imagen: `adjustment_contrast` 1.06 (:45), `adjustment_saturation` 0.84 (:46).
- `ambient_light_energy` 0.0 (:9). `presentation_rig.gd:37` copia ese valor a `ambient_energy`, así que el 0.16 de `presentation_rig.gd:13` no llega a usarse.

### 1.2 Qué hace el rig con la niebla

Archivo: `game/app/presentation_rig.gd`.

- `:19-20` `const LIT_FOG_LENGTH := 14.0`, con el comentario `:19` "How deep the volumetric fog reaches when lamps light it."
- `:55` guarda `authored_tone.fog_length` (48 del `.tres`).
- `apply_settings()` (`:214` a `:319`), lo que toca la niebla:
  - `:222` `hunter := echo_seat()`, la vista de la criatura.
  - `:235` `sdfgi_enabled = false`, con el comentario `:234` de que SDFGI filtra la luz a través de los muros.
  - `:243` `fog_enabled = not hunter`. La niebla de profundidad no depende del preset ni de "Efectos reducidos".
  - `:244` `volumetric_fog_enabled = preset.fog_size > 0 and not level.settings.values.reduced and not hunter`.
  - `:245-247` comentario: las lámparas que alumbran la niebla necesitan celdas cortas o el brillo de una sala pasa a la de al lado (docs/REALISM.md, prueba 7).
  - `:248` `volumetric_fog_length = LIT_FOG_LENGTH if preset.lamp_fog else authored_tone.fog_length` (14 o 48).
  - `:249-251` si `fog_size > 0`: `RenderingServer.environment_set_volumetric_fog_volume_size(fog_size, fog_depth)` y `environment_set_volumetric_fog_filter_active(fog_filter)`. Con `fog_size` 0 no se llaman y la rejilla anterior queda en memoria.
  - `:236` `glow_enabled = preset.glow and not hunter`; `:237` `RenderingServer.environment_set_glow_bicubic_upscale(preset.glow_bicubic)`.
  - `:311` `torch.shadow_enabled = settings.shadows`; `:312-313` `torch.light_size = torch_size * minf(preset.penumbra, 1.0)`.
  - `:318` `configure_hotel()` pasa el preset al suelo (`hotel.apply_quality`).
- `apply_camera()` (`:69-85`): con la cámara encendida, `tonemap_mode = LINEAR` (:80), `tonemap_exposure = 1.0` (:81), `glow_hdr_threshold = 0.9` (:82). Apagada, vuelven los valores autorizados.
- `apply_grade()` (`:333-343`): las oficinas cambian contraste, saturación, la llave y el balance de blancos de la cámara, y `ssao_light_affect`. No tocan densidad ni longitud de niebla.

### 1.3 Tabla por preset

Los presets están en `game/presentation/graphics_presets.gd`. Las líneas son las del bloque de cada preset: Bajo `:185-192`, Medio `:195-202`, Alto `:205-212`, Ultra `:215-222`, Muy bajo `:226-235`.

| Clave | Bajo (0) | Medio (1) | Alto (2) | Ultra (3) | Muy bajo (4) |
|---|---|---|---|---|---|
| `fog_size` / `fog_depth` (rejilla, en celdas por lado) | 0 / 0 (:189) | 48 / 48 (:199) | 64 / 64 (:209) | 96 / 96 (:219) | 0 / 0 (:231) |
| `fog_filter` (suavizado de la rejilla) | no (:189) | sí (:199) | sí (:209) | sí (:219) | no (:231) |
| `lamp_fog` (lámparas alumbran la niebla, niebla de 14 m) | no (:191) | sí (:201) | sí (:211) | sí (:221) | no (:233) |
| `floor_haze` (neblina de suelo, `FogVolume`) | no (:189) | no (:199) | sí (:209) | sí (:219) | no (:231) |
| `dust` (motas del hotel; ver 4) | 0 (:190) | 60 (:200) | 90 (:210) | 140 (:220) | 0 (:232) |
| `penumbra` (tamaño de fuente, PCSS) | 0.0 (:186) | 1.0 (:196) | 1.0 (:206) | 2.5 (:216) | 0.0 (:228) |
| `lamps_cast` (lámparas de techo con sombra) | 0 (:187) | 0 (:197) | 20 (:207) | 20 (:217) | 0 (:229) |
| `static_light` | no (:185) | no | no | no | sí (:227) |
| `glow` / `glow_bicubic` | sí / no (:190) | sí / no (:200) | sí / sí (:210) | sí / sí (:220) | no / no (:232) |
| `lens` (lente de la videocámara) | sí (:185) | sí (:195) | sí (:205) | sí (:215) | no (:227) |
| `scale` (escala de render de diseño) | 0.67 (:185) | 0.85 (:195) | 1.0 (:205) | 1.0 (:215) | 0.5 (:227) |

Efectos sobre la niebla que no vienen del preset:

- Motor Compatibility: `graphics_presets.gd:308-318` (en `of()`) pone `fog_size = 0`, `floor_haze = false`, `lamp_fog = false`, `ssao` y `ssil` a -1, `ssr_steps = 0`, `bounce = false`, `taa = false` y `sconce_lights = false`. El comentario de `:302` lo explica.
- Ajuste del jugador "Niebla volumétrica" (`fog`, valores -1, 0, 1): `graphics_presets.gd:290-295` (`SWITCHES`, con la etiqueta "Niebla volumétrica"), `:349-353` (`apply_choices`):
  - 0 (Desactivado): `fog_size = 0`, `fog_depth = 0`, `floor_haze = false`, `lamp_fog = false`.
  - 1 (Activado): si el preset tiene `fog_size <= 0`, pone `fog_size = 48`, `fog_depth = 48`, `fog_filter = true`, `lamp_fog = true`. No pone `floor_haze`, así que Bajo o Medio con Activado tienen rejilla y luces en la niebla, pero no neblina de suelo.
  - Rango del ajuste: `game/services/settings_service.gd:192` lo limita a -1..1. Valor por defecto: -1 (`settings_service.gd:6`).
- Valor por defecto del preset elegido: `quality` = 1, Medio (`settings_service.gd:6`).
- Overrides de medición: `graphics_presets.gd:297-299` (`static var overrides`), usados solo por `tools/benchmarks/hotel_benchmark.gd --set=`.

Las cuatro salidas de la niebla a la vez (en `presentation_rig.gd` y en otros):

- `presentation_rig.gd:244`: volumétrica apagada con "Efectos reducidos" o con la criatura mirando.
- `observer_view.gd:442-450`: el observador (vista de la cámara libre) enciende su propia `DirectionalLight3D` (`observer_view.gd:155-158`, energía 1.1, sin sombra). Con la luz encendida apaga la niebla volumétrica (`:450`) y la de profundidad (`:449`) y sube la luz ambiente (`:446-447`).

## 2. Qué luces entran en la niebla

Por defecto, `light_volumetric_fog_energy` vale 1.0 (`.claude/godot-api/doc/classes/Light3D.xml:66`). Cuando el código no escribe el valor, la luz aporta a la niebla con 1.0.

Columnas: luz, nodo y tipo, dónde se crea y fija el valor, valor, comentario sobre el 0.

| # | Luz | Archivo:línea | Valor de niebla | ¿Comentario que explica? |
|---|---|---|---|---|
| 1 | Linterna del jugador: `Flashlight`, SpotLight3D bajo `Camera` | `game/player/player.tscn:28` (nodo), `:32` (valor) | 0.35, fijo, no cambia con el preset | No |
| 2 | Piloto de grabación `RecordingLamp`, OmniLight3D bajo la cámara | `game/player/hotel_player.gd:201-209` | 0.0 | No (la energía inicial también es 0.0, `:204`) |
| 3 | Linterna de los remotos: `Flashlight`, SpotLight3D | `game/net/remote_player.gd:88-101` | 0.0 | Sí, `:96-100`: el haz de un compañero debe quedarse en su sala (se veía en la sala de al lado); la neblina de la propia linterna se conserva, solo la ve su dueño |
| 4 | Antorcha caída `FallenTorch`, SpotLight3D | `game/app/executions.gd:635-640` | 0.0 | No |
| 5 | Chispa de la antorcha caída `spill`, OmniLight3D | `game/app/executions.gd:658-664` (`TORCH_SPILL` `:115`) | 0.0 | No |
| 6 | Lámpara de sala del hotel, OmniLight3D (cúpula o regleta de tubos) | `game/world/hotel/hotel_geometry.gd:1409-1443` (creación en `lamp_light`), `:1434` (0.0 al crear) | 0.0 al crear; `apply_quality` (`:2614-2616`) lo pone a 1.0 si `preset.lamp_fog`, si no a 0.0 | Sí, `:1431-1433`: "Lamps light the volumetric fog only on presets with lamp_fog, where the fog is short enough (14 m) for its cells not to straddle walls: at 48 m a lit room's haze glowed in the dark room next door" |
| 6b | Lámpara de sala en lámparas "void" (celdas sin sala, invisibles) | `game/world/hotel/hotel_geometry.gd:1078-1085` | energía 0, `visible = false`; entra en `lights` y recibe 1.0 con `lamp_fog` | No (sin efecto por ser invisible) |
| 6c | Lámpara de sala de oficina (la misma `lamp_light`, con `fitted`) | `game/world/office/office_geometry.gd:1930-1956` (`room_lamp`), `:2387-2394` (`light_lamp`) | igual que 6 | No. `light_lamp` quita capas, sombra y proyector, pero no pone la energía a 0. No se ha comprobado si la niebla respeta las capas de render; no se encontró ningún comentario que lo diga |
| 6d | Lámpara de sala de oficina de tipo "emergency" (tubo sin energía, oculta) | `office_geometry.gd:1947-1949` (`room_lamp`) | energía 0 y `visible = false`; recibe 1.0 con `lamp_fog` | No |
| 7 | Focos de los troffers: `TrofferPool`, SpotLight3D (`pool_pair`) | `game/world/office/office_geometry.gd:663-675` (valor `:675`) | 0.0 | No |
| 8 | Rebote de los troffers: `TrofferBounce`, SpotLight3D | `office_geometry.gd:689-701` (valor `:701`) | 0.0 | No (el comentario `:698-700` habla de BAKE_DYNAMIC) |
| 9 | Regletas de oficina: `BattenPool` y `BattenBounce` (mismo `pool_pair`, etiqueta "Batten") | `office_geometry.gd:1883-1908` (`batten_lights`), `:663-701` | 0.0 | No |
| 10 | Regleta de oficina `BattenUp`, SpotLight3D | `office_geometry.gd:1888-1898` (valor `:1898`) | 0.0 | No |
| 11 | Regleta de archivo `BattenSpot`, SpotLight3D | `office_geometry.gd:1840-1853` (valor `:1853`) | 0.0 | No |
| 12 | Regleta del hotel (tubo, `lamp_light` con `tube`) | `hotel_geometry.gd:1355-1407` (`lamp_fixture`) | igual que 6 | Ver 6 |
| 13 | Foco de emergencia ámbar `EmergencyLight`, SpotLight3D (2400 K) | `game/world/office/office_geometry.gd:1128-1137` (valor `:1137`); energía `EMERGENCY_ENERGY` 1.4 (`:1066`), alcance 9 (`:1067`), ángulo 55 (`:1068`), `EMERGENCY_KELVIN` 2400 (`:1069`) | 0.0 | No |
| 14 | Luz de salida `ExitGlow`, OmniLight3D verde (hotel) | `hotel_geometry.gd:1899-1913` (valor `:1913`); energía 0.55 (`:1903`), alcance 2.8 (`:1904`) | 0.12 | No. El comentario de `:1910-1912` habla del rebote, no de la niebla |
| 14b | Luz de salida de oficina (hereda 14 y baja la energía) | `office_geometry.gd:2151-2161`: `EXIT_ENERGY` 0.1 (`:2161`), `EXIT_RANGE` 1.2 (`:2162`) | 0.12 (heredado) | No |
| 15 | Baliza roja de inicio `StartBeacon`, OmniLight3D | `hotel_geometry.gd:1486-1497` (valor `:1495`); energía 3.2 (`:1490`) | 0.0 | No |
| 16 | Lámpara de mesa y de pie (`practical`), OmniLight3D | `hotel_geometry.gd:2326-2352` (valor `:2343`); usada desde `game/world/hotel/prop_factory.gd:145` y `:151` | 0.0 | No |
| 17 | Apliques de pared `sconce_light`, OmniLight3D | `hotel_geometry.gd:2097-2110` (valor `:2110`) | 0.0 (no están en `lights`, así que `apply_quality` no los toca) | No |
| 18 | Lámpara de la cabina del ascensor `CarLight` (`box_light`) | `hotel_geometry.gd:1839-1849` (valor `:1849`) | 0.0 | No |
| 19 | Acento de recepción `AccentSpot`, SpotLight3D | `office_geometry.gd:2463-2478` (valor `:2478`) | 0.0 | No (el comentario `:2475-2476` habla de la especular) |
| 20 | Acento de recepción `AccentStrip`, AreaLight3D (tira del mostrador) | `office_geometry.gd:2493-2505` (valor `:2505`) | 0.0 | No |
| 21 | Televisor: `Glow`, SpotLight3D; `Fill`, OmniLight3D | `game/world/interactables/hotel_television.gd:89-101` (valor `:101`) y `:104-117` (valor `:117`) | 0.0 | No |
| 22 | Lucecita de estación (lámpara ámbar de la estación de tarjetas), OmniLight3D `STATION_LAMP` | `game/floors/objectives/files_objective.gd:32` (color), `:113-118` (energía 0.6, alcance 1.5) | sin fijar: 1.0 | No (no se fija el valor) |
| 23 | Piloto ámbar del lector de energía `pilot`, OmniLight3D | `game/floors/objectives/power_objective.gd:118-122` (energía 0.4, alcance 0.6) | sin fijar: 1.0 | No |
| 24 | Flash de la foto del código, OmniLight3D dentro de un SubViewport | `game/app/code_lock.gd:332-334` (energía 2.4) | sin fijar: 1.0 | No |
| 25 | Luz de la cámara del observador, DirectionalLight3D `ObserverLamp` | `game/app/observer_view.gd:155-158` | sin fijar: 1.0. La niebla volumétrica se apaga cuando está encendida (`:450`) | No |
| 26 | Luces de la intro, el título y la UI | `game/title/title_scene.gd:107,118,125`; `game/intro/intro_sequence.gd:603,614,622,643,650,658`; `game/intro/tv_broadcast.gd:60,70`; `game/ui/hotel_ui.gd:1959` (SpotLight3D `key_light`) | sin fijar: 1.0 | No. No se comprobó si su escena tiene niebla volumétrica activa |

Lo que aporta a la niebla de verdad: la linterna (0.35, siempre), las lámparas de sala del hotel y de la oficina en Medio, Alto y Ultra (1.0, cuando su `lights` están visibles), la luz de salida (0.12), los velos de polvo (`FogVolume`), y las luces sin fijar (todas las de la fila 22 a la 26, si su escena tiene niebla). Las luces de troffer, regleta, emergencia y acento de oficina no aportan (0.0).

## 3. FogVolume

### 3.1 Neblina de suelo del hotel (`floor_haze`)

- Creación: `game/world/hotel/hotel_geometry.gd:1194-1204`. Solo en celdas de pasillo (`room.hall == room.id and room.hall >= 0`) y solo con renderizador `forward_plus` (`:1195`).
- `FogVolume.new()` con `size = (span.x × 0.65, 0.7, span.y × 0.65)` y `position.y = 0.45` (`:1196-1198`). La forma no se fija: queda el valor por defecto 3 de `FogVolume.xml:12`.
- Material: `FogMaterial` con `density = 0.025` (`:1200`) y `albedo = Color("81775f")` (`:1201`). `edge_fade` y `height_falloff` quedan por defecto (0.1 y 0.0, `.claude/godot-api/doc/classes/FogMaterial.xml`).
- Lista `fog_volumes` (`:75`).
- Visibilidad: `hotel_geometry.gd:3017`, `fog.visible = preset.floor_haze and not reduced and not echo_view`, dentro de `round_rooms()` (`:3000`).
- Presets: solo Alto y Ultra (ver tabla 1.3).
- Las oficinas no crean `FogVolume` de neblina de suelo: no hay ninguno en `office_geometry.gd`.

### 3.2 Velos de polvo del techo (`ceiling_dust.gd`)

- Creación: `game/enemies/lurker/ceiling_dust.gd:153-202` (`veil()`). Se crea solo si `environment.volumetric_fog_enabled` (`:143-148`, `haze()`); si no, se usan sprites (`puffs()`, `:205-228`).
- `FogVolume.new()` con `shape = FOG_VOLUME_SHAPE_ELLIPSOID` (`:177`, valor 0 en RenderingServer).
- `ShaderMaterial` con `game/enemies/lurker/ceiling_dust_veil.gdshader` (shader `fog`). Parámetros: `noise_tex` (ruido 3D de 32³, frecuencia 0.15, 3 octavas, `:161-170`), `density` (de 0 a `VEIL_DENSITY × sqrt(strength)` en 0.5 s, `:189`; `VEIL_DENSITY` = 3.0, `:45`), `albedo` = `DUST_COLOUR × VEIL_GLOW` (`:175`; `VEIL_GLOW` = 16.0, `:51`), `eye` (cada frame, `:193-196`).
- Tamaño: `VEIL_SIZE` = (1.4, 2.2, 1.4) (`:46`), crece en 1.5 s (`:190`), se hunde y se adelgaza hasta `VEIL_LIFE` = 9.0 s (`:47`, `:198-202`).
- Máximo de velos vivos: `MAX_VEILS` = 3 (`:43`). Un velo nuevo acelera el más viejo en 0.6 s (`:154-160`).
- Shader (`ceiling_dust_veil.gdshader:14-21`): ruido estirado en el mundo, `wisp = smoothstep(0.45, 0.85, ...)`, `edge` por la SDF y `near = smoothstep(0.5, 1.4, distance(eye))` para que no tape la lente.
- Quién lo llama: `game/enemies/lurker/lurker_voice.gd:213` (`seep`, cuando la criatura repta por el plénum) y `:257` (`fall`, cuando la voz cae sobre una baldosa).
- Las oficinas usan velos (son de la criatura del techo). No usan `floor_haze`.

## 4. Partículas

### 4.1 Polvo que cae del techo (GPUParticles3D), `game/enemies/lurker/ceiling_dust.gd`

- `thread()` (`:100-139`): `ParticleProcessMaterial` con emisión en caja, gravedad (0, -1.8, 0), amortiguación 5 a 7, turbulencia; `GPUParticles3D` con `fixed_fps = 0` (`:134`, el valor por defecto es 30 en `GPUParticles3D.xml:83`); se apaga con `amount_ratio` en `seconds` (`:136-138`).
- `emitter()` (`:339-363`): `GPUParticles3D` con `QuadMesh` y `ShaderMaterial` del shader `game/enemies/lurker/ceiling_dust.gdshader` (`render_mode blend_mix, depth_draw_never, ...`, `shader_type spatial`), con `billboard` y `axial` según el caso. `cast_shadow` apagado (`:348`).
- Cantidades: `THREAD_GRAINS` = 600 (`:36`) por `HEFT` = [1.0, 0.6, 0.35] (`:41`) × `share`; `PUFFS` = 40 (`:37`); `FLAKES` = 8 (`:38`); `CRUMBS` = 6 (`:39`).
- `share()` (`:92-96`): devuelve 0.35 si `preset.dust <= 0` (Bajo y Muy bajo), y 1.0 en cualquier otro caso. La cantidad de `preset.dust` (60, 90, 140) no escala las partículas: solo cuenta si es cero o no.
- `flakes()` (`:231-262`): escamas de yeso, `FLAKE` = (0.02, 0.04) m, `velocity_limit_curve` de 0.45 (`:243`).
- `crumbs()` (`:266-317`): `BoxMesh`, `COLLISION_RIGID` (`:284`), `GPUParticlesCollisionBox3D` de 4 × 0.2 × 4 m bajo el suelo (`:312-315`), `one_shot` (`:292`).
- Shader de polvo (`ceiling_dust.gdshader`, cabecera `:1-10`): `light()` suma la luz que llega con sus sombras, sin N·L. Un grano brilla en el haz de la linterna o bajo un tubo y es negro en la oscuridad. `min_pixels` mantiene un ancho mínimo en pantalla. `axial` alinea el grano con su caída.

### 4.2 Motas de polvo del hotel (CPUParticles3D), `game/world/hotel/hotel_geometry.gd`

- Creación: `build_dust()` (`:3272-3300`), llamada desde `build()` (`:1170`).
- `CPUParticles3D` (`:3273`): `cast_shadow` apagado (`:3276`), `amount = max(1, preset.dust)` (`:3277`), `lifetime = 10` (`:3278`), caja de emisión de 6 × 1.2 × 6 m (`:3280`), velocidad 0.03 a 0.09, `scale_amount` de 0.006 a 0.017 (`:3286`).
- Material: `StandardMaterial3D` con `albedo_color = (0.8, 0.73, 0.55, 0.22)` (`:3291`), transparencia alfa, billboard.
- Posición que sigue al jugador: `hotel_geometry.gd:3013` `dust.position = player_position + (0, 1.2, 0)`.
- Emisión: `:3014` `dust.emitting = preset.dust > 0 and not reduced and not echo_view`. Cantidad: `apply_quality` (`:2620`) cambia `dust.amount` si el preset cambia.

### 4.3 Otros

- No hay `GPUParticles3D` ni `CPUParticles3D` en ningún `.tscn` ni en `game/`, salvo los de los dos archivos anteriores. No se encontraron chispas ni hilos de polvo en placas.
- Los `.tscn` de galería no se revisaron a fondo (solo se buscó `Environment`).

## 5. La linterna

- Nodo: `Flashlight`, `SpotLight3D`, hijo de `Camera` (`game/player/player.tscn:28`). En el `_ready` del jugador (`game/player/hotel_player.gd:193`): `torch = $Camera/Flashlight`.
- Valores del `.tscn`: `visible = false` (:29), `light_color = (1, 0.9, 0.74)` (:30), `light_energy = 10.0` (:31), `light_volumetric_fog_energy = 0.35` (:32), `light_size = 0.03` (:33), `shadow_enabled = true` (:34), `shadow_bias = 0.04` (:35), `spot_range = 24.0`, `spot_attenuation = 0.85`, `spot_angle = 32.0`, `spot_angle_attenuation = 0.8`.
- Alcance 24 m, ángulo 32°, atenuación 0.85 (forward+). Energía 10.0 (forward+).
- Forma del haz en Forward+: `light_projector = beam_pattern()` (`hotel_player.gd:199`, `:388-402`): un degradado radial de 256 px.
- En cualquier renderizador que no sea Forward+ (`plain_beam()`, `:376-377`): `shape_plain_beam()` (`:379-385`) quita el proyector y pone el ángulo 26°, `spot_angle_attenuation` 3.0, energía 11.0, `shadow_bias` 0.3 y `shadow_normal_bias` 4.0. Lo que justifica el cambio está en `:367-373` (comentario sobre bandas de sombra en Compatibility).
- `light_bake_mode = BAKE_DISABLED` (`:197`).
- Energía en cada frame: `torch.light_energy = torch_energy × warm × (1 − 0.06 × moving × |sin(step)| × sway) × torch_dim` (`:661`). `torch_energy` se toma de la luz al arrancar (`:200`). `torch_dim` lo baja la criatura al beber la linterna (`game/enemies/lurker/lurker.gd:1542-1566`, 0.0, 0.8 o interpolado).
- Tamaño de fuente según el preset (`presentation_rig.gd:313`): `light_size = 0.03 × min(preset.penumbra, 1.0)`. Bajo y Muy bajo: 0 (PCF simple). Medio, Alto y Ultra: 0.03 (Ultra queda limitado a 1.0 de su 2.5).
- Sombras: `presentation_rig.gd:311` `torch.shadow_enabled = settings.values.shadows` (ajuste "Sombras", por defecto true, `settings_service.gd:6`).
- Niebla: energía 0.35 en todos los presets. Solo se ve si la rejilla volumétrica está encendida (`fog_size > 0`, `reduced` apagado, sin criatura).
- Compañero: `game/net/remote_player.gd:88-101` tiene la linterna remota con `light_volumetric_fog_energy = 0.0` (ver fila 3 de la tabla 2).

## 6. Filtro de cinta, tonemap y glow: el orden

Lo que dicen el código y las cabeceras de los shaders. La referencia de la API no documenta el orden entre la niebla volumétrica y los callbacks del compositor (`CompositorEffect.xml` solo lista los identificadores de callback, valores 1 a 4). Lo marcado como "según el código" es lo que dicen los comentarios del propio juego.

1. Pasada 3D de Godot: iluminación, sombras, niebla volumétrica y niebla de profundidad (`fog_enabled`). La niebla no tiene callback propio en el código.
2. Compositor del `WorldEnvironment` (`presentation_rig.gd:58-66`): primero `blur_effect` (`motion_blur_effect.gd`, `effect_callback_type = POST_TRANSPARENT`, `:84`), después `camera_effect` (`camcorder_effect.gd`, `POST_TRANSPARENT`, `:348`). Según `camcorder_effect.gd:4-6`, corre después de la pasada transparente y antes de TAA y del tonemapper.
3. Etapa HDR de la cámara (`camcorder_effect.gd:20-29`, comentarios): medidor, iris, `smear` (CCD), `glare` (halo y fantasmas de la lente), `grade` (exposición, balance de blancos y "rodilla" de vídeo, que reemplaza al tonemapper). Con la cámara encendida el entorno pasa a `LINEAR` (`presentation_rig.gd:80`).
4. Glow: `glow_enabled = preset.glow and not hunter` (`presentation_rig.gd:236`), `glow_bicubic` por preset (`:237`), `glow_hdr_threshold` 0.9 con cámara (`:82`). Si el orden del glow respecto a la niebla no está documentado, queda sin comprobar.
5. Antialiasing: FSR 2.2 reemplaza a TAA, FXAA, SMAA y MSAA (`graphics_presets.gd:321-327`). FSR 1 y bilineal no.
6. CanvasLayer `Lens` (capa 2, `presentation.tscn:17-18`): `lens.gdshader` aplica barril, aberración cromática, viñeteo, entrelazado (`field_shift`, de `presentation_rig.gd:99-131`) y ruido del sensor. Es "bajo el OSD" según la cabecera de `lens.gdshader:1-7`.
7. CanvasLayer `Camcorder` (capa 3, `presentation.tscn:37-38`): el OSD (marcas de la videocámara, `camcorder_osd.gd`).
8. CanvasLayer `Analog` (capa 5, `presentation.tscn:27-28`): `analog.gdshader`, la cinta. Se aplica encima del OSD y de la lente (la cabecera de `lens.gdshader:4-6` dice "the tape records both"). Parámetros: `vhs`, `grain`, `chromatic`, `scanlines`, `tint`, `vignette`, `signal_loss`, `tape_hit` (cabecera de `analog.gdshader:1-25`).
9. Filtro de la cinta sin lente (Muy bajo, `lens: false`): `presentation_rig.gd:300-304` deja `grain` y `vignette` al filtro de cinta.

Hay glow en Bajo, Medio, Alto y Ultra. Muy bajo no lo tiene (`glow: false`, `graphics_presets.gd:232`).

## 7. Rendimiento

### 7.1 Qué mide el banco, `tools/benchmarks/hotel_benchmark.gd`

- Cabecera `:1-45`: coste del hotel a 1080p por calidad. Vistas fijas (`room66`, `room126`, `room179`, `llegada`, 120 fotogramas cada una), la llegada a 8 salas (20 fotogramas), y un paseo de 240 fotogramas desde la recepción (6 m/s).
- Opciones: `--qualities=0,3` (presets), `--set=key:value` (fuerza valores del preset, p. ej. `fog_size:0`), `--setting=key:value` (ajustes del jugador), `--passes` (desglose por etapas de la pasada 3D, solo Forward+), `--hide=Analog,Lens` (capas que no se dibujan), `--pixels=N` (simula una GPU N veces más lenta), `--floor=2` (oficinas), `--seed=N`, `--difficulty=`.
- Mide: `frame_ms`, `gpu_ms`, `cpu` (tick, process y draw; `at_60`), `draws`, `primitives`, `shadow_draws`, `hitches`, memoria de vídeo y de búferes.
- Salida: `evidence/bench/<etiqueta>/report.json`, y por vista y calidad `<vista>_q<n>_raw.png` (sin cinta) y `_vhs.png` (como se juega).

### 7.2 Los dos informes disponibles

Los dos: adaptador NVIDIA GeForce RTX 4060 Ti, ventana 1920×1080, `pixels` = 1.0, planta 2 (oficinas), dificultad "apacible", y solo calidad 2 (Alto). Los dos ejecutan el mismo recorrido. Medias en ms.

| Vista | regletas: fotograma / GPU | suelo: fotograma / GPU |
|---|---|---|
| still_room66 | 9.962 / 7.865 | 9.240 / 7.770 |
| still_room126 | 8.669 / 7.492 | 8.139 / 7.352 |
| still_room179 | 9.339 / 8.439 | 8.855 / 8.275 |
| still_llegada | 11.923 / 10.246 | 10.955 / 9.626 |
| arrival (100 muestras) | 11.700 / 7.751 | 11.600 / 7.395 |
| walk (240 fotogramas) | 9.799 / 7.700 | 9.151 / 7.504 |

Fuentes: `evidence/bench/regletas_forward_plus/report.json` (etiqueta "regletas") y `evidence/bench/suelo_forward_plus/report.json` (etiqueta "suelo"). Las etiquetas no dicen qué cambió entre ellos. Ningún informe trae un A/B de la niebla (no hay `--set=fog_size:0` ni similares).

### 7.3 Comentarios sobre el coste de la niebla

Código (sin cifras de coste):

- `graphics_presets.gd:80-81` (`fog_size`, `fog_depth`, `floor_haze`): sin coste.
- `graphics_presets.gd:124-125` (`lamp_fog`): "ceiling lamps light the volumetric fog, which is then 14 m long: short cells do not straddle walls". Sin cifra.
- `remote_player.gd:97-100`: la niebla de un compañero hacía brillar la pared de la sala de al lado: "measured: the far face of a wall brightened by two thirds with fog, not at all without". Sin coste en tiempo.
- `hotel_geometry.gd:1431-1433`: lo mismo para las lámparas del hotel (48 m frente a 14 m).

Documentos (`docs/PERFORMANCE.md`, cifras con su fecha; no están en el código):

- Sección 6, "Rendimiento medido" (`:198-216`): RTX 4060 Ti, 1080p, caminando, GPU en ms: Bajo 0.74, Medio 2.35, Alto 4.92, Ultra 6.87. Es la medida previa al plan de fotorrealismo, no incluye la cámara ni la luz nueva.
- Sección 6, "Coste de cada efecto" (`:222-240`, sin unidad en el encabezado): niebla 96³ frente a 64³ en Ultra, 0.27; niebla 48³ o 64³ en Medio y Alto, ~0.10.
- Sección 11, "Qué pagaba Ultra" (`:504-512`, en ms de GPU): niebla 96³, 0.52 ms de GPU (`:512`), y 0.00 a 0.04 % de píxeles que cambian en la captura.
- `docs/PERFORMANCE.md:216` (sección 6, "Rendimiento medido"): "Lo que más se nota en partida no sale en una foto fija: ... haz volumétrico de la linterna, polvo en el haz y lámparas lejanas". Lo que el documento deja fuera de la foto es justo lo que el polvo y la niebla producen.

### 7.4 Herramienta de la trailer (no es el juego)

- `tools/trailer3d/web/engine/volumetric.js:1-4`: "Haze lit by the lamps: torch beams marched through the air with their own shadow (anything in the beam, the creature too, cuts it), and the glow of point lights round their bulbs (closed form)." Clase `Volumetrics` en `:120`, hasta 4 focos (`MAX_SPOTS`, `:7`) y 24 puntos (`MAX_POINTS`, `:8`). Se llama desde `core.js:121` y `:276-277`.
- Su intención es la misma que la del juego (neblina iluminada por los focos, con la sombra del haz). No comparte código con el juego.

## 8. Ajustes del usuario que apagan la niebla

| Ajuste | Dónde | Efecto sobre la niebla | Efecto sobre polvo y neblina |
|---|---|---|---|
| "Efectos reducidos" (`reduced`, por defecto false) | `game/ui/hotel_ui.gd:1612` (la etiqueta es "Efectos reducidos"); `settings_service.gd:6` | Niebla volumétrica off (`presentation_rig.gd:244`). La niebla de profundidad sigue encendida (`:243`) | Motas del hotel off (`hotel_geometry.gd:3014`); neblina de suelo off (`:3017`); velos de polvo: `ceiling_dust.gd:145` los cambia por sprites (`puffs`) porque la niebla volumétrica está apagada |
| "Niebla volumétrica" (`fog`: -1 del preset, 0 apagada, 1 encendida) | `hotel_ui.gd:1608` (bucle sobre `PRESETS.SWITCHES`), `graphics_presets.gd:290-295` y `:349-353`, `settings_service.gd:192` | Apagada: `fog_size = 0`, `fog_depth = 0`, `floor_haze = false`, `lamp_fog = false`. Encendida: rejilla de 48 y `lamp_fog` aunque el preset no los tenga | Igual que el preset (la neblina de suelo solo se enciende con el preset) |
| Preset Bajo o Muy bajo | `graphics_presets.gd:185-236` (`fog_size` 0) | Apagada | Motas en 1 (Bajo y Muy bajo `dust` 0; `build_dust` usa `max(1, ...)`) |
| Renderizador Compatibility | `hotel_ui.gd` (opción "Renderizador"); `graphics_presets.gd:308-318` | Apagada a la fuerza | Sprites en vez de velos; `share()` de polvo da 0.35 con `dust` 0 |
| Vista de la criatura (`echo_seat`) | `presentation_rig.gd:222`, `:243-244` | Apagada | Motas off (`hotel_geometry.gd:3014`) y neblina off (`:3017`) |
| Observador con luz encendida | `observer_view.gd:442-450` | Apagada | No aplica |
| "Sombras" (`shadows`, por defecto true) | `hotel_ui.gd:1606`, `presentation_rig.gd:311` | No toca la niebla; apaga la sombra de la linterna | No aplica |

Ajuste de medición (no del jugador): `--set=fog_size:0` en el banco (`graphics_presets.gd:297-299`).

## 9. No encontrado

- Ningún archivo del juego fija `temporal_reprojection`, `detail_spread`, `gi_inject` ni `emission_energy`. Quedan los valores por defecto de Godot.
- Orden entre la niebla volumétrica y los callbacks del compositor: no documentado en `.claude/godot-api/` (solo ids de callback). No está confirmado con código ni con la referencia.
- Orden entre glow y niebla: no documentado en la referencia.
- `RenderingServer.environment_set_volumetric_fog_filter_active` no tiene descripción en la referencia (`RenderingServer.xml:1329-1334`).
- Comentario que explique el 0.35 de la linterna: no encontrado.
- Comentario que explique el 0.12 de la luz de salida: no encontrado (solo el de rebote, `hotel_geometry.gd:1910-1912`).
- Comentario en el código con un coste en ms de la niebla: no encontrado (las cifras están en `docs/PERFORMANCE.md`).
- Informe de banco con A/B de niebla: no encontrado (solo `regletas` y `suelo`, ambos en Alto).
- Si las lámparas de oficina con la meta `fitted` aportan niebla con energía no nula: no comprobado (ver fila 6c).
- Si las luces sin fijar de la intro, el título y la UI tienen niebla volumétrica activa en su escena: no comprobado.
- Efecto de `volumetric_fog_gi_inject` (1.0 por defecto) con SDFGI apagado: no comprobado.
