# Ficha de hechos: audio

Fecha de lectura: 14 de noviembre de 2026. Rama `main`, árbol de trabajo con cambios sin confirmar. Las rutas son relativas a la raíz del repo. Cada hecho lleva su ruta:línea o su URL. Lo que no se ha leído o comprobado está en «Sin comprobar», al final.

Esta ficha describe lo que hay. No propone diseño de Unreal.

---

## 0. Resumen

- El sonido del mundo se concentra en un solo script: `game/audio/world_audio.gd` (816 líneas). Crea y enruta casi todas las voces 3D, y decide puertas, escondites, cues largos, eco, binaural, zumbidos y teles.
- Hay 11 buses en `default_bus_layout.tres` y un duodécimo (`Ducts`) que se crea en ejecución (`world_audio.gd:528-547`). Los efectos son reverberación por bus, retardos de eco, filtros paso bajo, un ecualizador de 6 bandas para los ductos y un limitador en Master.
- La posición no es solo volumen y paneo. Cada voz recibe una ruta caminable (navegación más rayos) y, en cada cambio, ajusta posición, volumen, filtro y si suena por el bus de eco (`world_audio.gd:439-476`, `:507-521`).
- La música es una sola pista (`the_four_theme.mp3`) en bucle forzado por código. Su volumen sigue a una tensión de 0 a 1 (`theme_mood.gd`). No hay música por compases: el importador tiene `bpm=0`, `beat_count=0`, `bar_beats=4` y ningún código los lee.
- Hay 202 archivos de audio en `assets/audio/` (163 WAV, 37 OGG, 1 MP3, 1 M4A que solo lee una herramienta), 79 MB. Además hay sonidos que se generan en ejecución (la voz de pasos de la criatura) y cuatro tablas generadas por herramientas (`cue_timing.gd`, `footstep_segments.gd`, `grunt_segments.gd`, `search_timing.gd`).

---

## 1. Inventario de archivos leídos

### 1.1 `game/audio/` (completo)

| Archivo | Líneas | Qué hace |
|---|---|---|
| `world_audio.gd` | 816 | Motor de sonido del mundo: buses, voces 3D, rutas, puertas, escondites, cues largos, eco, binaural, zumbidos, teles, ducking, subtítulos de sonido. |
| `dread_aura.gd` | 274 | Aura de presión de la criatura: drone, respiración, chasquidos, latidos y el filtro del bus Ambience. |
| `theme_mood.gd` | 115 | Tensión de 0 a 1 para quien escucha. Controla ancho y filtro del bus Music. |
| `cue_timing.gd` | 41 | Tabla generada: inicio audible y golpe de 33 archivos (`cue_timing.gd:4-37`). |
| `footstep_segments.gd` | 42 | Tabla generada: 3 conjuntos de pasos (12 + 12 + 8 recortes) con el instante del golpe. |
| `grunt_segments.gd` | 15 | Tabla generada: 10 gruñidos de `grunts.ogg` como [inicio, duración]. |
| `search_timing.gd` | 16 | Tabla generada: 8 instantes del último golpe de cajón. |
| `noise_kinds.gd` | 43 | Enumeración de 8 tipos de ruido y sus radios de oído de la criatura. El audio lo ignora; lo usa la vista acústica del cazador. |
| `creature_audio_profile.gd` | 15 | Recurso (`Resource`) con la identidad sonora de una criatura. |
| `world_audio.tscn` | 8 | Escena con el nodo `WorldAudio` (script `world_audio.gd`) y su hijo `DreadAura`. |
| `profiles/locust.tres` | 9 | Perfil de The Locust. |
| `profiles/lurker.tres` | 20 | Perfil de The Lurker. |

### 1.2 Documentación, mezcla y datos

| Archivo | Líneas | Qué hace |
|---|---|---|
| `docs/AUDIO.md` | 241 | Documento de diseño y medidas del audio. Algunas afirmaciones no coinciden con el código (sección 12). |
| `default_bus_layout.tres` | 197 | Layout de buses y sus efectos (sección 2). |
| `docs/hotel_audio_inventory.json` | 68 | Cinco fuentes de `source_assets/audio/` con sus métricas. Ninguna se usa en el código (sección 12). |
| `assets/audio/the_four_theme.mp3.import` | 19 | Importación de la música: `loop=false`, `bpm=0`, `beat_count=0`, `bar_beats=4`. |

### 1.3 `tools/audio/` (22 scripts; los `.uid` no cuentan)

Ver la tabla de la sección 9.

### 1.4 Código fuera de `game/audio/` leído para cerrar el contrato

- `game/app/presentation_rig.gd:405-480`: crea la cama, la música, la ventilación, el menú y los sonidos de evento.
- `game/app/hotel_main.gd:488-495`, `:1808-1830`, `:1854`: volumen de cama y música, ventilación en la rejilla, bus Threat silenciado.
- `game/services/settings_service.gd:50-53`, `:108`, `:209`, `:428-436`, `:444`, `:496-497`: sliders de volumen y curva.
- `game/enemies/locust/hotel_locust.gd:2`, `:72-73`, `:259-262`, `:325-326`, `:347-349`, `:415-555`, `:1134-1141`, `:2482`: voz, pasos, gruñidos, grito y chasquidos de The Locust.
- `game/enemies/lurker/lurker_voice.gd:17-62`, `:163-170`, `:177-184`, `:259-265`, `:286-297`: sonidos de The Lurker.
- `game/enemies/lurker/lurker.gd:36-37`: perfil de The Lurker.
- `game/intro/intro_sequence.gd:43`, `:51-53`, `:201-238`, `:402-409`, `:443-469`: escena de entrada.
- `game/app/sanity.gd:51`; `game/world/interactables/hotel_door.gd:56`, `:78`.
- `tools/verify.ps1:38-43`, `:45`, `:50-51`, `:60`.

---

## 2. Buses y efectos

Fuente: `default_bus_layout.tres`. Los números son los índices de bus. El bus Master no tiene `name` en el archivo, así que se llama Master por defecto.

| Idx | Bus | Envía a | Efectos (en orden) | Líneas |
|---|---|---|---|---|
| 0 | Master | salida | `AudioEffectHardLimiter`: techo `-0.5` dB, liberación `0.12` s | `:112-113`; sub-recurso `:3-7` |
| 1 | Ambience | Master | `AudioEffectLowPassFilter` «DreadMuffle»: corte 20000 Hz, resonancia 0.4 (lo baja el aura) | `:114-120`; `:8-12` |
| 2 | Music | Master | `AudioEffectStereoEnhance` «ThemeWidth» y `AudioEffectLowPassFilter` «ThemeMuffle» (20000 Hz, resonancia 0.4). **Los dos desactivados** por defecto; `theme_mood` los activa | `:122-131`; `:13-19` |
| 3 | Effects | Master | `AudioEffectReverb` «Space»: predelay 24 ms, realimentación 0.25, sala 0.5, amortiguación 0.6, spread 0.9, paso alto 0.12, húmedo 0.12 | `:132-139`; `:21-30` |
| 4 | Threat | Master | `AudioEffectReverb` «Space»: predelay 30 ms, realimentación 0.3, sala 0.6, paso alto 0.08, húmedo 0.16 | `:140-147`; `:31-38` |
| 5 | Aura | Threat | Ninguno | `:148-153` |
| 6 | EffectsEcho | Effects | `AudioEffectDelay` «EchoTaps»: toma 1 a 170 ms (−9 dB), toma 2 a 340 ms (−15 dB), paneo 0. `AudioEffectReverb` «EchoRoom»: predelay 60 ms, sala por defecto, seco 0.85, húmedo 0.55 | `:154-163`; `:39-55` |
| 7 | ThreatEcho | Threat | `AudioEffectDelay` «EchoTaps»: toma 1 a 190 ms (−8 dB), toma 2 a 380 ms (−14 dB). `AudioEffectReverb` «EchoRoom»: sala 0.85, seco 0.85, húmedo 0.42 | `:164-173`; `:57-74` |
| 8 | Steps | Master | `AudioEffectReverb` «StepsSpace»: predelay 12 ms, sala 0.35, amortiguación 0.7, spread 0.6, paso alto 0.2, húmedo 0.05 | `:174-181`; `:75-84` |
| 9 | Creature | Threat | `AudioEffectDelay` «Ears»: dos tomas a 0.05 ms, paneo −1 y +1, seco 0, sin realimentación. Es el efecto índice 0, y el código lo busca por ese índice | `:182-189`; `:85-97`; uso en `world_audio.gd:742` |
| 10 | CreatureEcho | ThreatEcho | `AudioEffectDelay` «Ears» (copia de Ears) | `:190-197`; `:98-110` |
| 11 | Ducts | Creature | **Creado en ejecución** por `world_audio.ensure_duct_bus()`: `AudioEffectEQ6` con ganancias [−12, −6, 0, +5, +2, −4] dB, y `AudioEffectReverb` (sala 0.18, amortiguación 0.15, spread 0.3, predelay 8 ms, realimentación 0.5, paso alto 0.2, seco 1.0, húmedo 0.28) | `world_audio.gd:528-547` |

Notas de bus:

- `world_audio.update_space()` (`:168-186`) solo toca las reverberaciones de los buses **Effects, Threat y Steps** (`:175`). Los buses de eco y Creature tienen valores fijos.
- Los buses `Steps` y el nombre `Aura` existen en el layout, pero el código de pasos del jugador (`game/player/hotel_player.gd`) no se ha leído.
- `settings_service.gd:428-436` crea los buses que falten (Master, Ambience, Music, Effects, Threat, Steps) y les fija el volumen con `slider_db`. **Steps usa el deslizador de Effects** (`:428`).
- Silencio: `settings_service.gd:436` silencia un bus si su valor es 0, y el bus Threat también si `mute_threat` es verdadero. `hotel_main.gd:493-495` pone `mute_threat` a verdadero y silencia Threat en el bloque que quita la criatura a esta máquina (`:489-495`).

### 2.1 Curva de deslizadores

- `slider_db(v) = linear_to_db(max(v × 2, 0.0002))` (`settings_service.gd:496-497`). Con los deslizadores al 50 % (valor 0.5 por defecto en `:6`, `master`, `ambience`, `music`, `effects`, `threat`): 0 dB. Al 100 %: +6.02 dB. Al 25 %: −6.02 dB.
- `AUDIO_CURVE := 2` (`settings_service.gd:53`). Si las preferencias guardadas tienen otra curva, se restablecen una vez (`:108`).
- Claves de audio: `AUDIO_KEYS` (`:50`).

---

## 3. Posición, propagación y oclusión

### 3.1 Quién escucha

- `listener_camera()` (`world_audio.gd:215-217`): la cámara activa del viewport o la cámara del jugador. Un jugador muerto oye desde la cámara del compañero observado (comentario `:213-214`).
- `listener_position()` (`:219-220`).

### 3.2 Alcance

- `ROUTE_LIMIT = 42.0` m: longitud máxima de ruta caminable en la que un sonido aún se oye (`world_audio.gd:14-15`).
- `ROUTE_SLACK = 10.0` m: margen sobre `ROUTE_LIMIT` antes de no buscar la ruta (`:16-18`). Si la línea recta supera 52 m, no hay ruta (`:447`).
- `play_at()` descarta el sonido si la distancia recta supera `ROUTE_LIMIT` (`:391`).
- `play_long()` y `route_long()` usan `ROUTE_LIMIT` igual (`:357`).

### 3.3 Cómo llega un sonido: `route_source()` (`world_audio.gd:439-476`)

1. Si no hay nada sólido entre fuente y oyente (`occluded()`, `:558-562`, rayo con máscara `1|8|64`, excluye el emisor si lo hay), llega directo: ganancia 0, filtro 20000 Hz, sin eco (`:441-442`).
2. Si hay oclusión y la distancia recta supera 52 m, no se oye (`:447`).
3. Si la altura de los dos extremos está en plantas distintas (`FLOOR.planta_of`), no se oye (`:450`). Solo la escalera o el ascensor unen plantas.
4. Busca la ruta caminable con `walked_route()` (`:451`). Si no hay ruta de al menos 2 puntos, no se oye (`:452`). Si la ruta mide más de 42 m, no se oye (`:455`).
5. Busca la última abertura visible desde el oyente: recorre los puntos de la ruta con un rayo a 1.5 m de altura y se queda con el último que se ve (`:457-461`).
6. Rodeo: `detour = max(0, longitud_ruta − distancia_oyente_a_abertura)` (`:462`).
7. Ganancia: `−3 − 20·log10(1 + detour/5) − 8 × puertas_cerradas` dB (`:473`). `SHUT_DOOR_LOSS = 8.0` (`:437`).
8. Filtro: `lerp(5200, 900, clamp(detour/25, 0, 1))` (`:474`). Si hay una puerta cerrada en el camino, el filtro se limita a `SHUT_DOOR_CUTOFF = 1500` Hz (`:438`, `:475`).
9. Puertas cerradas: cada segmento de la ruta se prueba con un rayo a 1.2 m de altura y máscara 8 (`:466-472`). Cada puerta que corta el rayo cuenta una vez (`shut[hit.collider]`). Se excluye el emisor si es válido.
10. Devuelve `{audible, position: abertura, gain, cutoff, echo: true, distance: longitud}` (`:476`).

### 3.4 Cómo se aplica: `apply_route()` (`world_audio.gd:507-521`)

- Posición del nodo: la abertura (`route.position`).
- Bus: `EffectsEcho` o `ThreatEcho` si la ruta usa eco; si no, `Effects` o `Threat` (`:509`). Si la ruta trae `bus`, se usa ese (`:515`).
- Paneo: `PANNING[dry_bus]` = 1.15 para Effects y Threat (`:23`, `:510`).
- Si es una criatura (`creature=true`), el bus va a `Creature` o `CreatureEcho` y el paneo es 0 (`:511-513`, `CREATURE_BUS` en `:28`).
- Volumen: `gain + route.gain + REAR_GAIN × rear + AIR_GAIN × far` (`:518`). Con `REAR_GAIN = −4` (`:39`), `AIR_GAIN = −6` (`:46`).
- `far = clamp(distancia_ruta / AIR_REACH, 0, 1)` con `AIR_REACH = 45` m (`:45`, `:517`).
- `rear = behind(route.position)` (`:516`).
- Filtro: `min(route.cutoff, lerp(20000, REAR_CUTOFF, rear), lerp(20000, AIR_CUTOFF, sqrt(far)))` (`:521`). `REAR_CUTOFF = 3200` Hz (`:38`), `AIR_CUTOFF = 2000` Hz (`:47`).

### 3.5 Delante o detrás: `behind()` (`world_audio.gd:550-557`)

- Devuelve 0 delante o al costado y 1 detrás, con `smoothstep` sobre el componente z del punto en el sistema de coordenadas de la cámara, sin altura (`:553-556`).
- Si el oyente no tiene jugador (`level.player == null`), devuelve 0 (`:551`).

### 3.6 Binaural de la criatura: `update_ears()` (`world_audio.gd:727-747`)

- `ITD_MS = 0.65` ms (`:29`): diferencia máxima de tiempo entre oídos.
- `EAR_SHADOW = 18` dB (`:30`): el oído lejano pierde hasta 18 dB, con `pow(|side|, 0.7)` (`:735`).
- `EAR_NEAR = 1.5` dB (`:31`): el oído cercano gana hasta 1.5 dB (`:736`).
- `EAR_BASE_MS = 0.05` ms (`:33`): retardo mínimo de cada toma.
- `ear_side` se mueve hacia el lado objetivo a 6 unidades por segundo (`:733`), y de ahí sale el retardo y el nivel de las dos tomas de `Ears` y `EarsEcho` (`:737-747`).
- Recorre los buses `Creature` y `CreatureEcho` y escribe `tap1_delay_ms`, `tap2_delay_ms`, `tap1_level_db` y `tap2_level_db` del efecto índice 0 (`:739-747`).

### 3.7 Oclusión por fuentes fijas (ventiladores): `mask_db()` (`world_audio.gd:424-426`)

- `covered = level.sound_mask(point)` si el nivel lo implementa (`hotel_main.gd:1722`). Devuelve `linear_to_db(max(1 − covered, 0.05))`. El mínimo es −26 dB.

### 3.8 Ruta memorizada: `walked_route()` (`world_audio.gd:492-502`)

- Reutiliza la última ruta durante `ROUTE_MEMO = 0.3` s (`:487`) si los dos extremos se han movido menos de `ROUTE_NEAR = 1.6` m (`:490`).
- Usa **tiempo real** (`Time.get_ticks_msec()`, `:495`), no el delta del frame.
- Llama a `FLOOR.navigation_path(level.get_world_3d().navigation_map, from, to)` (`:499`). `FLOOR.navigation_path` es `floor_definition.gd:310`.

### 3.9 Voces de mundo: `play_at()` (`world_audio.gd:388-421`)

- Sale si el audio está apagado, si `hush` es verdadero, o si la distancia supera 42 m (`:391`).
- Tope de voces: `maximum_voices = 8` (`:65`). Si hay 8, para y libera la más antigua (`:395-398`).
- Nodo `AudioStreamPlayer3D`: bus `Effects`, `unit_size = 6` (`:405`), `max_distance = 40` (`:406`), `max_db = 6` (`:407`), `area_mask = 512` (`:408`).
- Tono: `rng.randf_range(0.98, 1.02) × pitch` (`:410`).
- Al terminar: quita la voz de la lista y la libera (`:417-420`).
- Metadatos: `base_gain`, `emitter`, `start` (`:411-413`).

### 3.10 Puertas y escondites

- `door_cue()` (`world_audio.gd:222-244`):
  - Ganancias en `GAIN` (`:48`): apertura +1 dB, portazo 0 dB, apertura lenta −12 dB, cierre −11 dB, cierre lento −12 dB, escondite −8 dB.
  - Lejos desde 12 m (`far_threshold`, `:64`).
  - Cierre lento: si está cerca (menos de 12 m), empieza el crujido con su inicio `max(onset, hit − SLOW_SWING)` (`:230`). Si está lejos, espera `SLOW_SWING = 1.5` s y reproduce solo el pestillo (`:233`). `SLOW_SWING` es `hotel_door.gd:56`.
  - Cierre normal: arranca `CLOSE_PREROLL = 0.08` s antes del golpe (`:10`, `:239`).
  - Subtítulo: `[Una puerta se cierra despacio]`, `[Una puerta cruje]`, `[Una puerta se cierra]`, `[Un portazo]`; solo a menos de 16 m (`:232`, `:242-244`).
- `hide_cue()` (`:246-254`): entrar en el escondite arranca `HIDE_PREROLL = 0.3` s antes del golpe (`:10`, `:252`). Salir en silencio (`quiet`) suena `open_slow` a −8 dB extra, 0.4 s, en `point + UP` (`:249`).
- Piscinas de archivos (`POOLS`, `:50-63`): cuatro aperturas cercanas y cuatro cierres cercanos, dos aperturas y dos cierres lejanos, y las variantes lentas, de portazo y de escondite. `choose()` evita repetir el último archivo de la misma piscina (`:206-211`).

### 3.11 Sonidos de todo el piso: `play_everywhere()` (`world_audio.gd:267-296`)

- Para la muerte, la campana del ascensor y el grito de la caza.
- Sin atenuación de Godot: `attenuation_model = ATTENUATION_DISABLED` (`:280`). Usa su propia caída `fall = −20·log10(1 + d/8)` (`:287`, `EVERYWHERE_UNIT = 8` en `:266`).
- Suelo: `max(fall + extra, EVERYWHERE_FLOOR = −24)` (`:265`, `:288`).
- Distancia efectiva: `straight × 1.4` si no hay ruta; si hay ruta, la de la ruta (`:274`).
- Extra de −6 dB si está lejos (`:288`).
- Va al grupo `everywhere_cues` (`:292`) para poder borrarlo al reiniciar (`:626-627`).
- Si `length > 0`, programa un `create_timer(length / pitch)` para liberarlo (`:295`).

### 3.12 Cues largos: `play_long()` (`world_audio.gd:302-320`)

- Son sonidos de más de unos segundos (estática de teles, apagón, salto por tele). Tienen su propio nodo, fuera de `voices`, para que no los corten las puertas (`:115-121`).
- Nodo: `unit_size = 6` (`:309`), `max_distance = 40` (`:310`), `max_db = 6` (`:311`).
- Se reenrutan cada `LONG_REROUTE = 0.25` s (`:122`, `:369-371`).
- Fundido final de `LONG_FADE = 0.4` s (`:124`, `:385`).
- Si la ruta no llega, queda **mudo, no parado** (`:359-361`).
- El fin de un cue con duración usa **tiempo real** (`:372-383`).
- `follow=true`: va con el oyente y usa offset (`:348-355`).
- `long_playing()` (`:338-343`) evita tocar dos veces el mismo archivo si ya suena uno que empezó hace menos de `within` segundos.
- `stop_long()` (`:325-333`).

### 3.13 Silencio: `hush`

- `hush` (`world_audio.gd:129`) impide que suene nada nuevo (`play_at`, `play_long`, `play_cue`). Lo usa el reinicio al volver a una partida. `reset()` lo borra (`:630`).

---

## 4. Ambiente

### 4.1 Cama ambiental

- `presentation_rig.gd:445-455`: `AudioStreamPlayer` (no 3D), bus `Ambience`, `volume_db = −17`, archivo `res://assets/audio/sfx/ambience/dark_hotel.wav` en bucle hacia delante (`loop_mode = LOOP_FORWARD`, `loop_begin = 0`, `loop_end = longitud × mix_rate`).
- Cada frame, `hotel_main.gd:1819-1820`: `volume_db = −17 − dread × 9 + duck_db()`, donde `dread = world_audio.aura.intensity`.

### 4.2 Ventilación

- `presentation_rig.gd:464-472`: `AudioStreamPlayer3D` «Ventilation», bus `Ambience`, `volume_db = −19`, `max_distance = 16`, `area_mask = 512`, archivo `res://assets/audio/hotel/ambience.wav` en bucle (`loop_stream()`).
- Se recoloca en cada frame en la rejilla de 12 m, a la altura de la planta + 2.8 m (`hotel_main.gd:1854`).

### 4.3 Zumbido de fluorescentes: `hums`

- Dos `AudioStreamPlayer3D` «FluorescentHum» en `Ambience` (`world_audio.gd:146-149`). `HUM_UNIT = 4` (`:97`), `HUM_REACH = 13` m (`:98`), `max_db = HUM_DB + 3` (`:148`) con `HUM_DB = −28` (`:94`).
- `update_ambient_sources()` (`:751-771`): elige las dos luminarias más cercanas a menos de 13 m (`:758`). Si la apagada (`level.hotel.dark`, `:754`), las para. Cada una pasa por `route_source()`.
- Inicio aleatorio: `rng.randf() × 1.5` s (`:768`).
- Nivel por luminaria (`update_hum_levels`, `:809-816`): `HUM_DB + route_gain + 20·log10(light_energy / energy)`. El tono baja con la luz drenada: `pitch = 1 − HUM_DRAIN_PITCH × drained(room)`, con `HUM_DRAIN_PITCH = 0.08` (`:96`, `:816`).
- `tubes` y `flickers` vienen de `hotel_geometry.gd:82-84`.

### 4.4 Teles encendidas: `tv_hiss`

- Dos `AudioStreamPlayer3D` «TelevisionHiss» (`world_audio.gd:150-153`), `unit = 3`, `reach = 11` m, `max_db = TV_HISS_DB + 3`, con `TV_HISS_DB = −27` (`:109`).
- `update_tv_hiss()` (`:776-798`): las dos teles encendidas más cercanas a menos de 11 m, con `on` y `now >= hiss_after`.
- `update_hiss_levels()` (`:801-806`): sube durante `TV_HISS_RISE = 1.5` s a partir de `hiss_after`. Usa **tiempo real**.
- Archivo: `res://assets/audio/intro/tv_static.wav` (`:108`).

### 4.5 Subtítulos del sonido: `show_caption()` (`world_audio.gd:574-582`)

- `caption_time = 2.5` s por defecto (`:578`). Un subtítulo con `hold` lo mantiene más tiempo (`:579-581`).
- Presencias: enfriamiento de 18 s entre ellas (`:582`).
- Lo lee la interfaz: `hotel_main.gd:1826-1827`, si `settings.values.subtitles` está activo.

### 4.6 Aura de la criatura: `dread_aura.gd`

Ver también la sección 5. Hechos del aura:

- `start_distance = 30` (`:16`), `full_distance = 4` (`:17`). `use_profile()` los sustituye por los del perfil (`:222-232`).
- `cue_distance_far = 7.5` m (`:19`), `cue_distance_near = 2.5` m (`:20`). El punto de los cues está a esa distancia por delante a lo largo de la ruta (`:137`).
- Ruta: `route_to()` (`:126-137`). A más de `start_distance × 1.3` (39 m) usa la distancia recta × 1.3 (`:128`). Si la planta es distinta, `INF` (`:130`). Si no, usa `world_audio.walked_route()` (`:133`).
- Refresco de la ruta: cada 0.25 s (`:176-178`).
- Intensidad objetivo (`:181-182`): `target = pow(clamp((start − d)/(start − full), 0, 1), 1.3)`; `near = clamp((1.5·start − d)/(0.5·start), 0, 1)`.
- Por estado de la criatura (`:189-196`): alarma 2 → `max(target + 0.25·near, 0.7·near)`; alarma 1 → `target + 0.08·near`. Si la criatura dice algo (`creature.mood()`, `:187`), eso manda (`:198-202`).
- Escondite quieto: `target *= HUSHED = 0.15` (`:26`, `:207`).
- Subida de intensidad: `0.6`/s (`:211`). Bajada: `0.18`/s, o `FAST_FALL = 2.0`/s si la criatura dice «rápido» (`:210-211`, `:29`).
- Forma: `shaped = intensity^1.4` (`:212`).
- Drone (`:242`): `lerp(−42, −15, shaped)` dB más duck. Tono: `0.97 + sin(clock × 0.21) × 0.015 + shaped × 0.02` (`:243`).
- Respiración (`:244-245`): `lerp(−24, 6, shaped)` dB más duck. Tono `0.9 + sin(clock × 0.13) × 0.04`.
- Muffle del bus Ambience (`:246-247`): `lerp(20000, deepest, intensity^1.8)`, con `deepest = 1400` si la sala está drenada (`DRUNK_FLOOR_HZ`, `:32`) o `650` si no (`:246`).
- Chasquidos (`update_chitters`, `:249-259`): aleatorios, cada `lerp(5.5, 0.6, intensity) × rand(0.6, 1.5)` s (`:259`). Con intensidad ≥ 0.15 (`:251`). Volumen `lerp(−6, 6, intensity)` más duck (`:257`). Tono `rand(0.82, 1.18)` (`:256`). Posición del punto de ruta con jitter de ±1.4 m horizontal y 0.8 a 2.4 m de altura (`:253`).
- Latidos (`update_heart`, `:261-274`): desde intensidad `0.5` (`:22`). BPM de `64` a `128` (`:23`, `:266`). Alternan `lub` (`1.ogg`) y `dub` (`2.ogg`) (`:271`). Volumen `lerp(−20, −8)` más duck (`:272`). Tono `1 + strength × 0.08` (`:273`).
- Nodos: `DreadDrone` (`AudioStreamPlayer`, bus Aura, `:71-75`), `DreadBreath` (3D, unidad 3, alcance 22, `:76`), `DreadChitter` (3D, unidad 3.5, alcance 26, `:77`), `Heartbeat` (`AudioStreamPlayer`, bus Threat, `:78-81`). Los 3D tienen `max_db = 6` y `panning_strength = 1.4` (`:95-99`).
- Subtítulo direccional: **no existe en el código** (sección 12).

---

## 5. Sonidos de criatura

### 5.1 Identidad sonora: `creature_audio_profile.gd` y los perfiles

Valores por defecto del recurso (`creature_audio_profile.gd:3-15`):

| Campo | Defecto | Línea |
|---|---|---|
| `presence` (archivo en bucle) | `null` | `:3` |
| `volume_db` | −18 | `:4` |
| `audible_distance` (m) | 26 | `:5` |
| `caption` | `[Una presencia retumba cerca]` | `:6` |
| `aura_start` (m) | 30 | `:11` |
| `aura_full` (m) | 4 | `:12` |
| `aura_breath` | verdadero | `:13` |
| `aura_clicks` (lista de `AudioStream`) | vacía | `:14` |
| `aura_rise` (m) | 1.5 | `:15` |

Perfiles:

- `profiles/locust.tres`: `presence = sfx/presence/locust_presence.wav`, `volume_db = −6`, `audible_distance = 24`, caption `[Una presencia grave se desplaza por el hotel]`. No fija `aura_*`, así que usa los defectos: 30 m y 4 m. Sin `aura_clicks`, así que usa `CHITTERS` del aura (`dread_aura.gd:230-231`).
- `profiles/lurker.tres`: `presence = sfx/lurker/presence.wav`, `volume_db = −14`, `audible_distance = 14`, caption `[Algo respira encima]`, `aura_start = 22`, `aura_full = 3`, `aura_breath = false`, `aura_clicks` = `hard_2`, `tile_3`, `metal_2`, `wood_5` (`lurker.tres:19`), `aura_rise = 0`.
- `hotel_locust.gd:2` carga `locust.tres` como `sound_profile`. `lurker.gd:37` carga `lurker.tres`.

### 5.2 Presencia (`CreaturePresence`, `world_audio.gd:134-143`, `:689-722`)

- `AudioStreamPlayer3D`, bus Threat, `unit_size = 9`, `max_db = 4`, `volume_db = −80` al empezar, `panning_strength = 0` (`:136-141`).
- Se oye si: estado PLAYING, la criatura sin gracia (o es fantasma), no está en refugio, la ruta es audible, la distancia es menor que `audible_distance`, no está «hushed» y `presence_on()` (`:706-710`).
- Fade de `presence_gain` a 0.6/s (`:714`).
- Volumen: `profile.volume_db + route.gain + REAR_GAIN × rear + linear_to_db(presence_gain)` (`:720`). Refresco de ruta cada 0.25 s (`:696-699`).
- Subtítulo si `presence_gain > 0.5` y distancia < 12 m (`:722`).

### 5.3 The Locust (`game/enemies/locust/hotel_locust.gd`)

- Voz de gruñidos: `voice`, `AudioStreamPlayer3D` bus Threat, `unit_size = 7`, `max_distance = 40`, `max_db = 4`, `area_mask = 512` (`:430-437`). Cuelga de `world_audio` (`:441`), no de la criatura, para que el sonido siga al vano (`:438-440`).
- Archivo de gruñidos: `res://assets/audio/sfx/chase/grunts.ogg` (`:426`, `:433`; `CRY_SOUND` en `:259`).
- Segmentos: `GRUNTS.SEGMENTS` (10). `AGGRESSIVE_GRUNT = 1.4` s (`:262`): hay 6 gruñidos de 1.4 s o más y 4 ladridos cortos.
- Aviso de estocada (`warn()`, `:457-472`): ladrido corto, tono `rand(0.78, 0.9)` (`:463`), enrutado (`:467-470`). Sin ganancia extra; la ganancia la pone la ruta.
- Pasos (`claw_sound()`, `:475-490`; `on_footfall()`, `:493-502`): sonido **generado en código**, WAV de 22050 Hz, 16 bits, 5512 muestras (0.25 s). Mezcla un tic de 3100 Hz con un golpe de 118 Hz. Semilla de ruido `4401` (`:483`). Nivel `lerp(−9, −1, strength)` dB, −6 dB más si el jugador lleva la criatura (`:499`). Tono `rand(0.82, 1.08)` (`:501`).
- Gruñido (`grunt()`, `:506-530`): elige un segmento agresivo distinto del anterior (`:510-511`). Tono `rand(0.85, 1.0)` (`:514`). Nivel `shape_voice(false)` (`:524`), −6 dB si la lleva un jugador. Retiene `grunt_left = duración / tono`.
- Grito de caza (`cry()`, `:534-544`; `play_cry()`, `:546-549`): elige segmentos de **2 s o más** (`CRY_LONGEST = 2.0`, `:347`; hay 3). Tono `rand(0.78, 0.88)` (`:348`). Ganancia `CRY_GAIN = 0` (`:349`). Se oye en todo el piso con `play_everywhere()` (`:549`).
- Voces: `VOICE_SHRIEK = {unit 5.5, reach 32, level +3}` y `VOICE_GRUNT = {unit 7.0, reach 40, level 0}` (`:325-326`). `shape_voice(shriek)` (`:576`).
- Chasquidos de duda (`CHITTERS`, `:1134-1141`): tres archivos (`:73`), a `play_at` con ganancia −4 dB.
- Cada llamada se manda a los demás con `match_net.creature_call(...)` (`:516`, `:542`, `:601`, `:956`, `:1136`, `:1158`, `:1370`). Viajan el índice de segmento y el tono. Cada máquina la toca desde su propia posición.
- Las voces de la criatura usan `apply_route(..., "Threat", true)`, o sea, binaural (`:524`, `:500`).

### 5.4 The Lurker (`game/enemies/lurker/lurker_voice.gd`)

- Carpetas de sonidos: `res://assets/audio/sfx/lurker/` (`:17`). Conjuntos (`SETS`, `:19`): `tile` 6, `metal` 4, `hard` 8, `wood` 8. Chasquidos `KNOCKS = 8` (`:20`).
- Volúmenes por material (`STEP_DB`, `:21`): tile −11, metal −8, hard −12, wood −11, soft −20. Ruido de alfombra = «hard» con filtro de 1200 Hz (`SOFT_CUTOFF`, `:23`).
- Nombres generados: `"%s_%d.wav"` (`pick()`, `:177-181`). No repite el último archivo de su conjunto (`:178-180`).
- Pasos en tandas (`RUN`, `RUN_STEP`, `RUN_REST`, `RUN_DB`, `:38-41`): tandas de 6 a 8 pasos separados 0.06 a 0.09 s, y descansos de 1.2 a 2.6 s. `RUN_DB = −4`. Por cada estado de la criatura (`RUNS`, `:48-49`): `roam_far`, `rest`, `stalk` y `scare`.
- Rascados: `SCRAPE_CHANCE = 0.35` (`:42`), `WALL_CHANCE = 0.25` (`:30`), `KNOCK_DB = −6` (`:31`), `CREAK_DB = −10` (`:32`), `DUST_DB = −16` (`:50`), `CAR_DB = −8` (`:51`).
- Todo va por `play_routed()` (`:286-297`): `apply_route(..., "Threat", true)` (binaural) y el corte de `min(cutoff, …)`.
- Susto: `SHRIEK_CAPTION = "[Un chillido]"` a menos de 16 m (`:261-262`, `:264-265`).
- Sonidos de advertencia: `cue_*.wav`, `cue_short_*.wav`, `scare_*.wav`, generados por `prepare_lurker_sfx.py` (sección 9).

### 5.5 Intro (`game/intro/intro_sequence.gd`, referencia)

- Golpes en la tele: `BLOWS` (`:43`), `HIT_DB = [−8.2, −5.0, −5.5]` (`:51`), `KNOCK_DB = [−19.2, −16.3, −11.5]` (`:52`), `SHATTER_DB = 10` (`:53`).
- Latido: `bpm = lerp(70, 140, clamp((t − 21)/12, 0, 1))` (`:406`). Tono de los latidos `heart_0/1` entre −22 y −13 dB (`:409`).
- Voces: `static` (−1.5 dB), `whine` (−24 dB) (`:444-445`), golpes del vidrio, portazos, pasos, la cama (seis movimientos `bed_*`, `:459-461`).

---

## 6. Música dinámica (`theme_mood.gd`) y compases

### 6.1 La tensión (`theme_mood.gd`)

Constantes (líneas en `theme_mood.gd`):

- `RISE = 0.6` por segundo (`:27`).
- `CALM_HOLD = (5, 15)` s (`:29`): la espera de calma va de 5 s (después de un susto) a 15 s (después de lo peor), según `worst` (`:97`).
- `GONE = 0.5` (`:30`): por encima de ahí, la música está fuera del todo.
- `RETURN = 10` s (`:31`), `FALL = GONE / RETURN` = 0.05 (`:32`).
- `FALL_SILENT = 1.0` (`:33`): bajada rápida mientras la música ya está fuera del todo.
- `MUFFLED_HZ = 700` (`:34`), `OPEN_HZ = 20000` (`:35`).
- `EXECUTION_REACH = 25` m (`:36`).
- `GRUNT = 0.8` (`:37`), `MIND = 0.35` (`:38`).
- `RELEASE = 0.4` por segundo (`:41`).

Quién sube la tensión (`felt()`, `:75-85`):

1. El aura (`world_audio.aura.menace`, `:77`). No sigue la finta: `menace` es la intensidad sin el multiplicador de escondite (`dread_aura.gd:39`, `:198-201`).
2. Ejecución: si alguien está atrapado a 25 m o menos, o el jugador es el que la sufre, pasa a 1.0 (`:78-80`).
3. Gruñido dirigido a quien escucha (`world_audio.duck_hold > 0`): al menos `GRUNT = 0.8` (`:81`).
4. Cordura por debajo de 60 (`sanity.gd:51`): `MIND × clamp((60 − cordura)/60, 0, 1)` (`:82-84`), hasta 0.35 con la cordura a cero.
5. Si la máquina lleva a la criatura (`match_net.local_is_locust()`), devuelve 0 (`:76`).

Cómo se mueve (`step()`, `:89-100`):

- Si la tensión pedida (`now`) es igual o mayor que la actual, sube hacia ella a `RISE` (`:90-92`).
- Si `release` (la criatura ha huido, `dread_aura.release`), baja a `RELEASE` (`:93-94`).
- Si no, acumula `calm`. Cuando `calm` supera `lerp(5, 15, worst)`, baja (`:96-97`): a `FALL_SILENT` si está por encima de `GONE`, y a `FALL` si no.
- `worst` guarda el máximo desde la última calma (`:98`). Se reinicia a 0 si la tensión queda por debajo de 0.02 (`:99`).

Efectos (`gain()` y `apply()`, `:103-115`):

- `gain() = 1 − smoothstep(0.05, GONE, tension)` (`:104`). Lo usa `hotel_main.gd:1825`.
- `drawn = smoothstep(0, GONE, tension)` (`:108`).
- Filtro `ThemeMuffle`: `cutoff = 700 × (20000/700)^(1 − drawn)` (`:111`). Activo si `drawn > 0.001` (`:109-112`).
- Ancho `ThemeWidth`: `pan_pullout = 1 − drawn` (`:114`). Activo si `drawn > 0.001` (`:115`).
- `setup()` (`:55-66`) busca los dos efectos en el bus Music por tipo, no por posición.

### 6.2 Volumen de la música (`hotel_main.gd:1823-1825`)

- `music_power` sube a 1 en `MUSIC_RETURN = 2.0` s si hay luz, o baja a 0 en `MUSIC_CUT = 0.12` s si hay apagón (`presentation_rig.gd:484-488`; uso en `hotel_main.gd:1823-1824`; puente en `hotel_main.gd:2118-2122`).
- `theme.volume_db = −24 + linear_to_db(max(mood.gain() × music_power, 1e−4)) + duck_db()` (`:1825`).
- `duck_db() = −DUCK_DEPTH × duck` con `DUCK_DEPTH = 9` dB (`world_audio.gd:647-658`).

### 6.3 Compases y latido: lo que hay

- No hay música por compases en el código. El tema es una sola pista continua (`presentation_rig.gd:461`).
- `the_four_theme.mp3.import` (`[params]`): `loop=false`, `loop_offset=0`, `bpm=0`, `beat_count=0`, `bar_beats=4`. Son propiedades nativas de `AudioStreamMP3` (`modules/mp3/doc_classes/AudioStreamMP3.xml`).
- Ningún código lee `bpm`, `beat_count` ni `bar_beats`. La búsqueda por nombre solo da `intro_sequence.gd:406` (un `bpm` local del latido de la intro) y `tools/trailer3d/audio/mix.py:159` (fuera del juego).
- El latido de la intro sigue 70 a 140 BPM entre los segundos 21 y 33 (`intro_sequence.gd:406`).
- El latido del aura va de 64 a 128 BPM según la intensidad (`dread_aura.gd:23`, `:266`).

### 6.4 Quién oye la música y el tema

- `presentation_rig.gd:456-463`: `theme` es un `AudioStreamPlayer` en bus `Music`, `process_mode = PAUSABLE`, −24 dB, bucle forzado (`theme.stream.loop = true`, `:462`).
- `presentation_rig.gd:473-480`: `menu_music` es otro `AudioStreamPlayer` en `Music`, `process_mode = ALWAYS`, −12 dB, mismo archivo y bucle. No lo afecta `mood`.
- `AUDIO.md:90` dice que en versus, quien lleva a la criatura conserva el tema. El código lo cumple con `theme_mood.gd:76`.

---

## 7. Qué se genera por código y qué son archivos

### 7.1 Archivos de `assets/audio/`

- **Total:** 202 archivos de audio sin contar los `.import` (201 `.import`). Ocupan 79 MB (`du`).
- **WAV:** 163. Desglose por tasa, bits y canales (lectura de cabecera):
  - 120 a 44100 Hz, 16 bits, mono.
  - 33 a 48000 Hz, 16 bits, mono.
  - 8 a 22050 Hz, 16 bits, mono.
  - 1 a 24000 Hz, 16 bits, estéreo: `sfx/ambience/dark_hotel.wav`, 451.11 s.
  - 1 a 11025 Hz, 8 bits, estéreo: `hotel/ambience.wav`, 410.46 s (es el mismo formato que la fuente del inventario, `docs/hotel_audio_inventory.json`).
  - Duración total de los WAV: 1141.9 s.
- **OGG Vorbis:** 37 (importer `oggvorbisstr`).
- **MP3:** 1 (`the_four_theme.mp3`, 6154797 bytes, importer `mp3`).
- **M4A:** 1 (`assets/audio/bed-sound.m4a`). No tiene `.import`. Solo lo lee `tools/audio/clean_recordings.py` (`:170`). No se usa en el juego.
- **Recuento por carpeta (sin `.import`):** `intro` 17, `dread` 7, `events` 7, `glass` 4, `hotel` 1, `sfx/ambience` 1, `sfx/blood` 5, `sfx/camera` 2, `sfx/chase` 1, `sfx/door/closing` 9, `sfx/door/opening` 9, `sfx/flashlight` 6, `sfx/footsteps` 32, `sfx/heartbeat` 2, `sfx/lift` 4, `sfx/lurker` 56, `sfx/office` 19, `sfx/paper` 1, `sfx/presence` 1, `sfx/search` 8, `sfx/wardrobe` 8, y dos sueltos en la raíz (`bed-sound.m4a`, `the_four_theme.mp3`).
- `assets/audio/blood/` existe y está **vacía** (sección 12).

### 7.2 Importación (`*.import`)

- **WAV (163):** `force/mono=false`, `force/max_rate=false`, `edit/loop_mode=0`, `edit/loop_begin=0`, `edit/loop_end=-1`, `edit/trim=false`, `edit/normalize=false`, `compress/mode=2`, `force/8_bit=false`.
- **OGG (37):** `loop=false`, `loop_offset=0`, `bpm=0`, `beat_count=0`, `bar_beats=4`.
- **MP3 (1):** los mismos campos que el OGG.
- `compress/mode=2` en los WAV: en la referencia de clases, `AudioStreamWAV` tiene `FORMAT_IMA_ADPCM = 2` y `FORMAT_QOA = 3` (`.claude/godot-api/doc/classes/AudioStreamWAV.xml:54,56`). **No he comprobado qué modo del importador corresponde al valor 2.**

### 7.3 Bucles

- **WAV en bucle en código:** `world_audio.loop_stream()` (`world_audio.gd:188-195`) fija `LOOP_FORWARD`, `loop_begin = 0` y `loop_end = longitud × mix_rate`. Lo usan los zumbidos, las teles, la estática de la tele, la ventilación, el drone, la respiración y la presencia. La cama de `presentation_rig.gd:450-453` hace lo mismo a mano.
- **OGG y MP3 en bucle en código:** `copy.loop = true` (`world_audio.gd:194`) y `theme.stream.loop = true` (`presentation_rig.gd:462`, `:479`). El importador deja `loop=false`.
- **Cruce de bucle en los archivos:** `prepare_sfx.py` cruza 1 s entre el final y el principio (`prepare_sfx.py:38-41`, campo `loop_crossfade_seconds: 1` en el procesado). `prepare_office_sfx.py` usa `XFADE = 0.3` s (`:52`, `:108-117`). Los dos son herramientas.

### 7.4 Generado por código en ejecución

- `claw_sound()` (`hotel_locust.gd:475-490`): un WAV de 22050 Hz, 16 bits, creado en código y con semilla fija.
- `ensure_duct_bus()` (`world_audio.gd:528-547`): crea el bus Ducts con su EQ y su reverberación.
- `loop_stream()` (`world_audio.gd:188-195`) crea una copia del recurso con su bucle.
- `AudioStreamPlayer3D` y `AudioStreamPlayer` se crean en código en casi todo el audio (ver sección 8).

### 7.5 Generado por herramientas en el repo

Ver sección 9. Estas salidas se escriben en el repo y el juego las carga:

- `game/audio/cue_timing.gd`: lo escribe `analyze_cue_timing.gd` (ejecutado con Godot).
- `game/audio/grunt_segments.gd`: lo escribe `analyze_grunts.gd` (ejecutado con Godot).
- `game/audio/search_timing.gd`: lo escribe `prepare_search_sfx.py`.
- `game/audio/footstep_segments.gd`: lo escribe `slice_footsteps.py`.

### 7.6 Originales fuera de git

- `.gitignore:11` excluye `source_assets/`. `.gitignore:18-19` excluye `/sfx/`.
- En esta máquina existen `sfx/` (61 archivos) y `source_assets/audio`, `source_assets/oficinas`.
- `docs/assets/sfx_inventory.json` y `docs/assets/sfx_runtime_inventory.json` existen (inventario de copias).

---

## 8. Clases y nodos de Godot que usa el audio

Conteo de apariciones de cada nombre en `game/audio/*.gd` (aproximado, por tokens). Esto es lo que habrá que sustituir.

| Clase o API | Apariciones en `game/audio/` | Dónde |
|---|---|---|
| `AudioStreamPlayer3D` | 22 | `world_audio.gd` (voces, presencia, zumbidos, teles), `dread_aura.gd` (respiración, chasquidos) |
| `AudioStreamPlayer` (no 3D) | 4 | `dread_aura.gd:42`, `:45`, `:71`, `:78` (drone y latido) |
| `AudioServer` (bus index, mute, effects, add_bus) | 22 | `world_audio.gd`, `theme_mood.gd`, `dread_aura.gd` |
| `AudioStream` (tipo base) | 11 | voces, perfiles, carga |
| `AudioStreamWAV` | 2 | `world_audio.gd:190-193` (bucles) |
| `AudioStreamOggVorbis` | 1 | `world_audio.gd:194` |
| `AudioStreamMP3` | 1 | `world_audio.gd:194` |
| `AudioEffectLowPassFilter` | 4 | `dread_aura.gd:53`, `:88`; `theme_mood.gd:48`, `:60`; buses `Ambience` y `Music` |
| `AudioEffectReverb` | 2 | `world_audio.gd:180` (ajuste por sala), `:538` (bus Ducts) |
| `AudioEffectStereoEnhance` | 2 | `theme_mood.gd:49`, `:63` (`pan_pullout`) |
| `AudioEffectDelay` | 1 | `world_audio.gd:743` (`tap1_delay_ms`, `tap2_delay_ms`, niveles) |
| `AudioEffectEQ6` | 1 | `world_audio.gd:534-536` (bus Ducts) |
| `AudioEffectHardLimiter` | 0 | solo en `default_bus_layout.tres` |
| `AudioEffectCapture` | 0 | solo en `tools/audio/` |
| `PhysicsRayQueryParameters3D` | 3 | `world_audio.gd:460`, `:468`, `:560` |
| `PhysicsDirectSpaceState3D` | 1 | `world_audio.gd:456` |
| `get_world_3d()` | 3 | `world_audio.gd:456`, `:499`, `:562` |
| `Time.get_ticks_msec()` | 7 | `world_audio.gd:314`, `:339`, `:372`, `:495`, `:592`, `:781`, `:802` |
| `Time.get_ticks_usec()` | 1 | `world_audio.gd:663` (traza) |
| `create_timer()` | 2 | `world_audio.gd:233`, `:295` |
| `.connect(...)` (señales) | 6 | `world_audio.gd:233`, `:289`, `:295`, `:318`, `:417`, `:614` |
| `RandomNumberGenerator` | 2 | `world_audio.gd:68`, `dread_aura.gd:58` |
| `Camera3D` | 2 | `world_audio.gd:215-216` |
| `get_tree()` | 3 | `world_audio.gd:233`, `:295`, `:626` |
| `process_mode` | 2 | `world_audio.gd:132`, `dread_aura.gd:68` |
| `_physics_process` | 2 | `world_audio.gd:660`, `dread_aura.gd:162` |
| `randomize()` | 2 | `world_audio.gd:133`, `dread_aura.gd:70` |
| `set_meta` / `get_meta` / `has_meta` | 8 / 5 / 1 | `world_audio.gd` (sobre todo `:411-413`, `:764-770`, `:791-805`, `:811-816`) |
| `add_child` / `queue_free` | 9 / 9 | creación y liberación de voces |
| `load` / `preload` | 12 / 8 | `world_audio.gd` (`load` en `:146`, `:151`, `:275`, `:305`, `:394`, `:590`; `preload` de scripts en `:3-6`, `:49`, `:82`) |
| `is_instance_valid` | 12 | validación de voces y criaturas |
| `group` (`add_to_group`, `get_nodes_in_group`) | 2 | `world_audio.gd:292`, `:626` |
| `NavigationServer3D` (directo) | 0 | no aparece. La navegación entra por `floor_definition.gd:310` |
| `Tween` | 0 | no aparece en `game/audio/` |

Fuera de `game/audio/`, los nodos de audio aparecen en estos archivos (conteo de `AudioStream*`, `AudioServer`, `AudioEffect*`, `AudioStreamPlayer`): `death_tape.gd` 13, `presentation_rig.gd` 10, `hotel_main.gd` 10, `intro_sequence.gd` 9, `hotel_locust.gd` 7, `osd_style.gd` 6, `settings_service.gd` 6, `kit_sounds.gd` 6, `hotel_ui.gd` 5, `hotel_player.gd` 3, `remote_player.gd` 3, `lurker_voice.gd` 3, `phantom_passage.gd` 2, `locust_hallucinations.gd` 2, `hotel_television.gd` 1, `televisions.gd` 1, `lurker_hallucinations.gd` 1.

### 8.1 Quién llama a `WorldAudio` (conteo de `world_audio.` en `game/`, sin `game/audio/`)

- Por archivo: `hotel_locust.gd` 29, `hotel_main.gd` 28, `lurker_hallucinations.gd` 15, `lurker_voice.gd` 12, `lurker.gd` 10, `televisions.gd` 7, `phantom_passage.gd` 7, `match_net.gd` 5, `objective.gd` 5, `echo_view.gd` 5, `creature.gd` 5, `presentation_rig.gd` 5, `lifts.gd` 5, `interaction.gd` 4, `executions.gd` 4, `code_lock.gd` 4, `conduit_graph.gd` 3, `remote_player.gd` 3, `death_tape.gd` 3, `hotel_geometry.gd` 2, `director/pacing_director.gd` 2, `sanity.gd` 2, `observer_view.gd` 2, `locust_hallucinations.gd` 2, `floor_save.gd` 2, `hotel_television.gd` 1, `hotel_door.gd` 1, `intro_sequence.gd` 1, `air_objective.gd` 1, `blood.gd` 1.
- Métodos y campos más usados: `enabled` (42), `play_at` (15), `route_source` (14), `play_long` (10), `duck_db` (10), `aura` (9), `apply_route` (9), `phantom_point` (7), `stop_long` (6), `mood` (5), `set_creature` (4), `play_everywhere` (4), `loop_stream` (4), `hush` (4), `duck_under` (4), `walked_route` (3), `reset` (3), `long_cues` (3), `listener_position` (3), `hide_cue` (3), `long_playing` (2), `door_cue` (2), `choose` (2), `caption_text` (2), `update_tv_hiss` (1), `ensure_duct_bus` (1), `duck_hold` (1), `hums` (1), `voices` (1), `listener_camera` (1).

---

## 9. Herramientas de `tools/audio/`

| Script | Líneas | Entrada | Salida | Para qué |
|---|---|---|---|---|
| `catalog.gd` | 17 | `docs/assets/sfx_inventory.json` | `docs/assets/sfx_runtime_inventory.json` | Comprueba que cada copia de trabajo decodifica en Godot y anota su duración. |
| `analyze_cue_timing.gd` | 106 | `door/`, `wardrobe/`, `paper/`, `heartbeat/`, `glass/` | `game/audio/cue_timing.gd` | Reproduce cada efecto por el mezclador y mide inicio audible (−24 dB) y golpe. Necesita Godot en tiempo real. |
| `analyze_grunts.gd` | 60 | `sfx/chase/grunts.ogg` | `game/audio/grunt_segments.gd` | Divide `grunts.ogg` en gruñidos. Ventana 0.02 s, umbral 0.12 del máximo, mínimo 0.15 s, une huecos de menos de 0.12 s. |
| `measure_mix.gd` | 91 | escena del hotel | `evidence/audio_mix_<etiqueta>.json` | Mide RMS y pico del Master en momentos típicos. Usa `level.locust`, `level.settings.set_value` y `level.locust.set_mode`: los tres existen hoy. |
| `measure_hum.gd` | 56 | escena del hotel | consola | Mide el zumbido bajo un tubo y a 3, 5 y 11 m. |
| `measure_intro.gd` | 52 | escena del hotel | consola | Mide la intro en ventanas de tiempo. |
| `measure_blows.gd` | 62 | `intro_sequence.gd` | consola | Mide cada golpe de la tele; comprueba que suben. |
| `measure_spatial.gd` | 80 | escena del hotel | consola | Mide la diferencia izquierda y derecha y el brillo de los pasos de la criatura por dirección. |
| `measure_steps.gd` | 61 | escena del hotel | consola | Mide pasos del jugador caminando y corriendo en un dormitorio y en un salón. |
| `decode_media.ps1` | 20 | m4a o mp3 | WAV de 16 bits | Decodifica con Windows Media Foundation (WinRT). |
| `prepare_sfx.py` | 50 | `sfx/` | `assets/audio/sfx/*` y `docs/assets/sfx_inventory.json` | Copia OGG y MP3, procesa los WAV largos (presencia y ambiente) y escribe el inventario. Retira `sub-riser-presence.wav` y `creaky-wooden-door-slow-opening.mp3` (licencia). |
| `clean_recordings.py` | 180 | `sfx/door-new/`, `sfx/glass/`, `assets/audio/bed-sound.m4a` | puertas lentas, `glass/shatter.wav`, `intro/bed_*.wav` | Filtro de graves, recorte de cola, fundido y limitado de picos. Usa `tools/trailer3d/audio/dsp.py` (ffmpeg). |
| `generate_dread_layers.py` | 129 | nada | `assets/audio/dread/*.wav` | Sintetiza drone, respiración, cuatro chasquidos y zumbido. Semilla 1989. 22050 Hz. |
| `generate_event_sfx.py` | 50 | nada | `assets/audio/events/door_raps_*.wav` y `object_fall_*.wav` | Caídas y golpes en puerta. Importa `generate_intro_sfx.py`. Semilla 3141. |
| `generate_intro_sfx.py` | 147 | nada | `assets/audio/intro/*.wav` | Sintetiza estática, zumbido de tubo, golpes de vidrio, portazos y pisadas. 44100 Hz. Semilla 1987. |
| `prepare_camera_sfx.py` | 129 | `sfx/flashlight/`, `sfx/cam/` | `assets/audio/sfx/flashlight/on_*`, `off_*` y `camera/zoom_*` | Corta los clics de la linterna y los dos tramos del motor del zoom. |
| `prepare_execution_sfx.py` | 105 | `sfx/screamer/`, `sfx/hit/`, `sfx/static/` | `assets/audio/events/execution_*` | Grito, golpe y canal muerto de la ejecución. Golpe en 0.22 s. |
| `prepare_lift_sfx.py` | 85 | `sfx/elevator/` | `assets/audio/sfx/lift/*.wav` | Puertas, bajada y campana del ascensor. Fija la duración del viaje. |
| `prepare_lurker_sfx.py` | 321 | `source_assets/oficinas/audio_criatura/` | `assets/audio/sfx/lurker/*.wav` | Advertencias (`cue_*`), gritos (`scare_*`), pasos y `presence.wav`. Falla si un cue arranca después de 20 ms. |
| `prepare_office_sfx.py` | 138 | `source_assets/oficinas/audio_oficina/` y `audio_edificio/` | `assets/audio/sfx/office/*.wav` | Teclado, tubo neumático, palancas, ventiladores, teléfono, copiadora y sillas. |
| `prepare_search_sfx.py` | 139 | `sfx/drawer/` | `assets/audio/sfx/search/*.wav` y `game/audio/search_timing.gd` | Cajones y cajas. Escribe el instante del último golpe. |
| `slice_footsteps.py` | 147 | `sfx/footsteps/` | `assets/audio/sfx/footsteps/*.wav` y `game/audio/footstep_segments.gd` | Corta pasos. Filtro de 35 Hz a Nyquist, pico común de −3 dBFS. |

Los scripts de Python necesitan NumPy. `clean_recordings.py` y `prepare_search_sfx.py` además usan SciPy. Los que llaman a `ffmpeg()` pasan por `tools/trailer3d/audio/dsp.py`. Los de Godot necesitan el ejecutable de Godot en modo `--headless`.

---

## 10. Orden de ejecución, física, azar y tiempo

### 10.1 Orden de procesado

- `world_audio.gd:660` (`_physics_process`) llama a `step_physics()` (`:667`). Ahí se llama a `mood.step(mood.felt(...), delta, aura.release)` (`:679`). `felt()` lee `aura.menace` (`theme_mood.gd:77`).
- `dread_aura.gd:162` (`_physics_process`) escribe `menace` y `release` (`:172-173`, `:187-208`).
- `DreadAura` es hijo de `WorldAudio` (`world_audio.tscn:7-8`). **Según el orden de Godot (el padre procesa antes que el hijo en el mismo frame), el tema lee el valor del frame anterior.** No lo he comprobado ejecutando nada.
- `world_audio.gd:689` lee `level.creature` cada frame. Si no existe o no está PLAYING, no hace nada más (`:690`).

### 10.2 Física y navegación

- `route_source()` y `occluded()` lanzan rayos en el espacio físico (`world_audio.gd:456`, `:460`, `:468`, `:471`, `:560-562`). Sus respuestas dependen de los colliders en ese instante.
- `walked_route()` depende del mapa de navegación (`:499`, `floor_definition.gd:310`).
- `update_hum_levels()` (`:813`) sigue `light_energy` de cada luminaria cada frame. El parpadeo de la luz mueve el volumen del zumbido.

### 10.3 Tiempo real frente a delta

Usan **tiempo real** (`Time.get_ticks_msec`), no delta:

- fin de cues con duración (`world_audio.gd:372-383`);
- memo de ruta, 0.3 s (`:495-496`);
- `long_playing` (`:339-342`);
- `last_cue` (`:592`);
- subida de la estática de tele (`:781`, `:802-806`).

Usan **delta del frame** (`_physics_process`):

- `duck` (`:668-669`), caption (`:670-672`), `ears_hold` (`:674-676`), `presence_gain` (`:714`), `intensity` de `dread_aura` (`:211`), `tension` de `theme_mood` (`:91-97`);
- reenrutado de cues largos (`:369-371`);
- `ambient_clock` 0.5 s (`:681-684`), `route_clock` 0.25 s (`:696-698`).

Consecuencia: en pausa o con el juego a otra velocidad, los dos relojes no coinciden. `process_mode = PAUSABLE` en `world_audio` (`:132`) y en `dread_aura` (`:68`).

### 10.4 Azar

- `WorldAudio.rng.randomize()` (`world_audio.gd:133`) y `DreadAura.rng.randomize()` (`dread_aura.gd:70`). **No sembrados por el mapa.** Elegir archivo, tono, inicio y posición de chasquidos son aleatorios en cada partida. `AUDIO.md:31` dice que el audio usa un generador aparte; el código lo confirma.
- `claw_sound()` usa semilla fija `4401` (`hotel_locust.gd:483`). Su resultado es el mismo en todas las máquinas.
- La criatura de The Locust usa `rng.seed = manifest.seed + 71013` (`hotel_locust.gd:446`) para sus decisiones. Su tono de gruñido sale de ese `rng` (`:514`) y se manda por la red (`:516`).
- `generate_*.py`: semillas `1989`, `700+k`, `3141`, `1987`. Solo para regenerar archivos.

### 10.5 Señales y temporizadores

- `finished.connect` en cuatro sitios (`world_audio.gd:289`, `:318`, `:417`, `:614`). Al terminar una voz se quita de la lista y se libera.
- `create_timer().timeout.connect` en dos sitios (`:233`, `:295`).
- `hotel_locust.gd:429` conecta `visual.footfall` a `on_footfall`. Los pasos de la criatura dependen de esa señal.
- Grupos: `everywhere_cues` (`world_audio.gd:292`, `:626`), `hotel_actors` (`hotel_locust.gd:420`).

### 10.6 Red

- Los sonidos de la criatura se replican por llamadas `match_net.creature_call(tipo, índice, tono)`. Así se envía el segmento y el tono, no el audio (`hotel_locust.gd:516`, `:542`).
- La tabla de RPC que comprueba `tests/hotel/creature_contract_test.gd:88` incluye `play_world_sound` (4 argumentos), `locust_call` (3) y `creature_event_rpc` (2). No he leído `game/net/match_net.gd`.
- `AUDIO.md:208` dice que los pasos de los compañeros suenan con los mismos recortes desde su cuerpo. No he leído `game/net/remote_player.gd` para ver si se replican por red.

---

## 11. Tests que vigilan el audio

### 11.1 Tests de audio

- `tests/hotel/hotel_audio_test.gd` (62 líneas). Solo `_initialize()` y `run()`. Contenido no leído en detalle.
- `tests/hotel/spatial_audio_test.gd` (361 líneas). Funciones: `check`, `wait`, `energy`, `sample_at`, `room_door`, `theme_checks`, `run`. `docs/AUDIO.md:43-45` dice 18/18 (no reejecutado).
- `tests/office/office_audio_test.gd` (416 líneas). Funciones: `check`, `wait`, `find_room`, `listen_at`, `knock`, `in_duct_at_e`, `bus`, `grille`, `walls`, `real_audio`, `knock_peak`, `surfaces`, `step`, `clean_cue`, `knocks_since`, `aura`, `hum`, `shriek_and_car`, `presence`, `finish`.
- `tests/office/lurker_mood_audio_test.gd` (70 líneas). Funciones: `back_after`, `theme`, `runs`.

### 11.2 Otros tests que tocan audio (por búsqueda de nombres, sin leerlos)

- `tests/hotel/`: `capture_test`, `creature_contract_test` (lista de consumidores de `sound_profile` en `:66`, `:69`), `creature_test`, `echo_test`, `palette_scan_test`, `sanity_test`, `survival_test`.
- `tests/office/`: `lurker_capture_test`, `lurker_senses_test`, `office_lies_test`, `office_walk_test`.

### 11.3 Cómo los ejecuta `verify.ps1`

- `Godot-Arguments` (`tools/verify.ps1:38-43`) siempre pasa `--headless`. Solo añade `--fixed-fps 60` si el tercer argumento es verdadero.
- Los tests de audio (`hotel_audio_test`, `spatial_audio_test`, `office_audio_test`) van con `$fixed = false` (tiempo real). Se lanzan al final y se reintentan hasta 3 veces (`:50-51`, `:60`).
- `lurker_mood_audio_test` está en la lista general (`:45`), no en la de tiempo real.

---

## 12. Discrepancias entre documentación y código

1. **Distancia del aura.** `docs/AUDIO.md:115` dice que «el aura empieza a 24 m de ruta». `AUDIO.md:72` dice 30 m. El código da 30 m para The Locust (`creature_audio_profile.gd:11`, `dread_aura.gd:16`, sin cambio en `locust.tres`). Los 24 m de `AUDIO.md:115` coinciden con `audible_distance` del perfil, así que probablemente sea un error de redacción.
2. **Subtítulo direccional del aura.** `docs/AUDIO.md:76` describe «[Algo se acerca · izquierda/derecha/delante/detrás]» al cruzar intensidad 0.3, como máximo cada 20 s. La búsqueda de «Algo se acerca», «se acerca», «direccional» y «izquierda/derecha» en `game/` y `tools/` no da nada. `dread_aura.gd` no emite ningún subtítulo (no hay `caption` ni `show_caption`). El texto también usa un punto medio (·), que el proyecto no permite en texto de juego.
3. **Carpeta vacía.** `assets/audio/blood/` existe y no tiene archivos. El código usa `res://assets/audio/sfx/blood/` (`game/app/blood.gd:36-37`). Los cinco archivos están en `sfx/blood/`.
4. **Chasquidos de duda de The Locust.** `hotel_locust.gd:73` usa tres archivos (`chitter_0` a `chitter_2`). `dread_aura.gd:10` usa cuatro (incluye `chitter_3`). `AUDIO.md` dice «cuatro chasquidos» para el aura, que es correcto.
5. **Fuentes no usadas.** Cinco entradas de `docs/hotel_audio_inventory.json` (`ambience.wav`, `deep_atmosphere_short.wav`, `piercing-glitchy-voice-sfx.wav`, `deep_ambiance.flac`, `726475__ultraameise__liminal-beep.mp3`). Los nombres solo aparecen en `docs/ASSETS.md` y `docs/assets/originals_manifest.json`. Ningún archivo de `game/` ni de `tools/` los usa. Las cuatro «reservadas» que no están en el juego siguen sin asignar. El inventario tiene el campo `license` como «Pendiente de verificar» para todas.
6. **Afirmaciones de `AUDIO.md` sin contrastar.** Las cifras de niveles medidos (−26 RMS, −17 pico, etc.), las distancias de la criatura al cazador (`AUDIO.md:129`), `UNTIMED_OPEN` (0.8 s, `AUDIO.md:156`) y las fórmulas de la presencia de la fase de cordura (`AUDIO.md:133`, `:136`) no las he comprobado en el código.
7. **Caso del `Music` y `menu_music`.** `AUDIO.md:89` dice que la música suena a −24 dB en calma. Es correcto para `theme` (`presentation_rig.gd:460`). `menu_music` está a −12 dB (`:477`), y eso no aparece en la documentación.
8. **Compás.** No hay documentación de compás. `the_four_theme.mp3.import` tiene `bpm=0`, `bar_beats=4` (valores por defecto). No es una contradicción, pero **no existe música por compases en el proyecto**.

---

## 13. Contrato de dependencias externas

El audio lee del resto del juego estos nombres. Hay que tenerlos en cuenta al portar (no es una propuesta de diseño):

- `level` (la escena del piso, `hotel_main.gd`): `session.state` y `State.PLAYING` (`:49`), `manifest` (`rooms`, `seed`; `:53`), `player` (`:51`: `camera`, `slot`, `sanity`, `footstep`, `hard_floor`, `play_step`), `creature` (`:15`: `grace`, `voice_point()`, `sound_route()`, `hushed()`, `presence_on()`, `alarm_level()`, `mood()`, `presence_route()`), `locust` (`:11`), `match_net` (`:94`: `local_is_locust()`, `creature_call()`), `sanity` (`:97`), `execution` (`:2014`: `seat`, `point`), `televisions` (`:1943`: `on`, `hiss_after`, `screen_point()`), `hotel` (`:50`: `tubes`, `flickers`, `dark`, `drained(room)`), `perf` (`:5`: `begin`, `end`, `timed`), `intro` (`:80`).
- `level.in_refuge()` (`hotel_main.gd:1423`), `local_alive()` (`:1439`), `sound_mask(point)` (`:1722`).
- `FLOOR` (`game/world/generation/floor_definition.gd`): `room_at` (`:78`), `planta_of` (`:47`), `planta_y` (`:42`), `position_of` (`:39`), `floor_point` (`:54`), `navigation_path` (`:310`), `palette(manifest).hard_floor(room)` y `palette(...).TYPES`.
- `sanity.gd:51`: `SANITY_UNEASY = 60`.
- `hotel_door.gd:56`: `SLOW_SWING = 1.5`.
- `noise_kinds.gd`: `HEARING_SCALE` (`:25`), `QUIET` (`:27`), `HEARD` (`:28-40`), `radius()` (`:42-43`). Los usa la criatura para oír, no el audio.

---

## 14. Cifras que definen cómo suena (con ruta:línea)

### 14.1 Volumen y ganancias

| Qué | Valor | Ruta:línea |
|---|---|---|
| Curva de deslizadores | 50 % = 0 dB; 100 % = +6.02 dB; 25 % = −6.02 dB | `settings_service.gd:496-497` |
| Limitador de Master | techo −0.5 dB, liberación 0.12 s | `default_bus_layout.tres:5-6` |
| Ganancias de puertas | apertura +1, portazo 0, apertura lenta −12, cierre −11, cierre lento −12, escondite −8 dB | `world_audio.gd:48` |
| Suelo de sonidos de todo el piso | −24 dB | `world_audio.gd:265` |
| Escala de `play_everywhere` | `−20 log10(1 + d/8)` | `world_audio.gd:266`, `:287` |
| Zumbido | −28 dB, máximo −25 dB | `world_audio.gd:94`, `:148` |
| Estática de tele | −27 dB, máximo −24 dB | `world_audio.gd:109`, `:152` |
| Presencia | `max_db 4`; volumen del perfil (−18 defecto, −6 Locust, −14 Lurker) | `world_audio.gd:138`; `creature_audio_profile.gd:4`, `locust.tres:7`, `lurker.tres:13` |
| Voz de la criatura | `max_db 4`; `VOICE_SHRIEK` +3 dB, `VOICE_GRUNT` 0 dB | `hotel_locust.gd:325-326`, `:436` |
| Gruñido con la criatura en manos de un jugador | −6 dB | `hotel_locust.gd:524` |
| Pasos de la criatura | `lerp(−9, −1, strength)` dB; −6 si lo lleva un jugador | `hotel_locust.gd:499` |
| Chasquido de duda | −4 dB | `hotel_locust.gd:1141` |
| Grito de caza | ganancia 0; tono 0.78 a 0.88 | `hotel_locust.gd:348-349` |
| Pasos de The Lurker | tile −11, metal −8, hard −12, wood −11, soft −20 dB | `lurker_voice.gd:21` |
| Rascados, golpes, polvo, coche | knock −6, creak −10, dust −16, car −8, run −4 dB | `lurker_voice.gd:31-51` |
| Cama ambiental | −17 dB; −9 dB más con el aura al máximo | `presentation_rig.gd:449`; `hotel_main.gd:1820` |
| Ventilación | −19 dB, alcance 16 m | `presentation_rig.gd:468-469` |
| Música | −24 dB base; −12 dB el menú | `presentation_rig.gd:460`, `:477` |
| Eco de puertas y ruta | Effects −9/−15 dB; Threat −8/−14 dB | `default_bus_layout.tres:42-45`, `:59-63` |
| Ducking | 9 dB, ataque 0.08 s, liberación 0.6 s | `world_audio.gd:647-649` |
| Presencia cerca | subtítulo si > 0.5 y < 12 m | `world_audio.gd:722` |

### 14.2 Distancias y alcances

| Qué | Valor | Ruta:línea |
|---|---|---|
| Límite de ruta | 42 m (42 + 10 de margen) | `world_audio.gd:15-18` |
| Atenuación por distancia de ruta | −6 dB a 45 m; filtro 2 kHz | `world_audio.gd:45-47`, `:517-521` |
| Detrás | −4 dB; filtro 3.2 kHz | `world_audio.gd:38-39` |
| Puerta cerrada | −8 dB por puerta; filtro 1500 Hz | `world_audio.gd:437-438` |
| Filtro por rodeo | de 5200 a 900 Hz en 25 m de rodeo | `world_audio.gd:474` |
| Puerta lejana | 12 m | `world_audio.gd:64` |
| Voces máximas | 8 | `world_audio.gd:65` |
| Voces de mundo | `unit 6`, `max_distance 40`, `max_db 6` | `world_audio.gd:405-407` |
| Presencia | `unit 9`, `max_db 4` | `world_audio.gd:137-138` |
| Cues largos | `unit 6`, `max 40`, `max_db 6` | `world_audio.gd:309-311` |
| Zumbido | `unit 4`, alcance 13 m | `world_audio.gd:97-98` |
| Estática de tele | `unit 3`, alcance 11 m | `world_audio.gd:110-111` |
| Ventilación | alcance 16 m | `presentation_rig.gd:469` |
| Voz de la criatura | `unit 7`, alcance 40 m | `hotel_locust.gd:434-435` |
| `VOICE_SHRIEK` | unidad 5.5, alcance 32 m | `hotel_locust.gd:325` |
| `VOICE_GRUNT` | unidad 7.0, alcance 40 m | `hotel_locust.gd:326` |
| Aura: inicio y plena | 30 m y 4 m (defecto); 22 y 3 en Lurker | `dread_aura.gd:16-17`; `creature_audio_profile.gd:11-12`; `lurker.tres:16-17` |
| Aura: cues a lo largo de la ruta | 7.5 m lejos; 2.5 m cerca | `dread_aura.gd:19-20` |
| Respiración del aura | unidad 3, alcance 22 m | `dread_aura.gd:76` |
| Chasquido del aura | unidad 3.5, alcance 26 m | `dread_aura.gd:77` |
| Distancia audible del perfil | 14 m (Lurker), 24 m (Locust) | `lurker.tres:14`, `locust.tres:8` |
| Subtítulo de sonido | 16 m (puertas); 12 m (presencia) | `world_audio.gd:232`, `:722` |
| Alcance de la ejecución para la tensión de la trama | 25 m | `theme_mood.gd:36` |

### 14.3 Tiempos

| Qué | Valor | Ruta:línea |
|---|---|---|
| Preroll de cierre | 0.08 s | `world_audio.gd:9` |
| Preroll de escondite | 0.3 s | `world_audio.gd:10` |
| Refresco de ruta de presencia | 0.25 s | `world_audio.gd:696-698` |
| Refresco de cues largos | 0.25 s | `world_audio.gd:122` |
| Fundido de cues largos | 0.4 s | `world_audio.gd:124` |
| Memo de ruta | 0.3 s, 1.6 m | `world_audio.gd:487-490` |
| Subida de la estática de tele | 1.5 s | `world_audio.gd:113` |
| Cierre lento de puerta | 1.5 s | `hotel_door.gd:56` |
| Subtítulo de puerta | 2.5 s | `world_audio.gd:578` |
| Enfriamiento de subtítulo de presencia | 18 s | `world_audio.gd:582` |
| Refresco de ambiente | 0.5 s | `world_audio.gd:682-684` |
| Chasquido del aura | `lerp(5.5, 0.6, intensidad) × rand(0.6, 1.5)` s | `dread_aura.gd:259` |
| Liberación de la trama | 0.4/s | `theme_mood.gd:41` |
| Caída de la trama | 0.05/s (0.5 / 10) | `theme_mood.gd:31-32` |
| Espera de calma | 5 a 15 s | `theme_mood.gd:29` |
| Música: corte y vuelta | 0.12 s corte; 2.0 s vuelta | `presentation_rig.gd:486-488` |
| Latido de la intro | 70 a 140 BPM entre los segundos 21 y 33 | `intro_sequence.gd:406` |
| Gruñido de cacería mínimo | 2 s | `hotel_locust.gd:347` |
| Gruñido agresivo | 1.4 s | `hotel_locust.gd:262` |

### 14.4 Espacio (reverberación, ecos y oído)

| Qué | Valor | Ruta:línea |
|---|---|---|
| Sala por defecto (Effects) | sala 0.5, húmedo 0.12, amortiguación 0.6 | `world_audio.gd:169`; `default_bus_layout.tres:25-29` |
| Salón unido (hall) | sala 0.86, húmedo 0.24, amortiguación 0.42 | `world_audio.gd:173` |
| Suelo duro | sala 0.42, húmedo 0.2, amortiguación 0.25 | `world_audio.gd:174` |
| Extra húmedo de Threat | +0.04 | `world_audio.gd:181` |
| Pasos (Steps) | sala ≤ 0.45, húmedo × 0.3 | `world_audio.gd:183-184` |
| Velocidad de cambio de sala | 0.8 (sala y amortiguación), 0.3 (húmedo) por segundo | `world_audio.gd:184-186` |
| Binaural | ITD 0.65 ms; sombra 18 dB; cercano +1.5 dB; base 0.05 ms | `world_audio.gd:29-33` |
| Paneo de mundo | 1.15 | `world_audio.gd:23` |
| Alcance de la tele | 11 m | `world_audio.gd:111` |
| Muffle de Music | 700 a 20000 Hz | `theme_mood.gd:34-35` |
| Aura: muffle del bus Ambience | 650 Hz (o 1400 si drenada) a 20000 Hz | `dread_aura.gd:246-247` |
| Ancho de la trama | `pan_pullout = 1 − drawn` | `theme_mood.gd:114` |
| Ductos (EQ) | −12, −6, 0, +5, +2, −4 dB | `world_audio.gd:535` |
| Ductos (reverberación) | sala 0.18, húmedo 0.28 | `world_audio.gd:538-546` |

---

## 15. Duplicidad y restos a tener en cuenta

- `world_audio.gd:83` crea `mood` con `THEME_MOOD.new()`. Es la única instancia; no hay duplicado.
- `presentation_rig.gd:443` crea `ride_hiss` con `world_audio.loop_stream()`, y `world_audio.gd` tiene `TV_HISS` por separado. El de ascensor sigue la imagen con su propio volumen (`presentation_rig.gd:405-414`).
- `world_audio.gd:127-129` (`hush`) y `hotel_main.gd:493-495` (silenciar Threat) son mecanismos distintos para la misma idea (no sonar).
- `lurker_voice.gd:241` (`create_timer(0.15)`) y `world_audio.gd:295` (`create_timer(length/pitch)`) usan el mismo patrón.

---

## Sin comprobar

- **No leí entero:** `game/app/hotel_main.gd` (solo `:11`, `:15`, `:48-59`, `:80`, `:94`, `:97`, `:488-495`, `:634`, `:720`, `:1722`, `:1808-1830`, `:1854`, `:1423`, `:1439`, `:1943`, `:2014`); `game/app/presentation_rig.gd` (solo `:405-480`); `game/intro/intro_sequence.gd` (solo las partes citadas); `game/enemies/locust/hotel_locust.gd` (solo `:2`, `:72-73`, `:259-262`, `:325-326`, `:347-349`, `:415-555`, `:575-601`, `:1134-1141`, `:2482`); `game/enemies/lurker/lurker_voice.gd` (solo `:17-62`, `:163-297` en parte); `game/enemies/lurker/lurker.gd` (solo `:36-37`).
- **No leí:** `game/app/lifts.gd`, `game/app/hotel_container.gd` (`SEARCH_SOUNDS` y `noise_radius`), `game/app/blood.gd` (solo `:36-37`), `game/app/death_tape.gd`, `game/app/executions.gd`, `game/app/televisions.gd`, `game/world/interactables/hotel_television.gd`, `game/player/kit_sounds.gd`, `game/player/hotel_player.gd` (solo `:107`, `:116`, `:406`), `game/net/remote_player.gd`, `game/net/match_net.gd` (solo nombres de RPC), `game/app/phantom_passage.gd`, `game/app/sanity.gd` (solo `:51`), `game/ui/osd_style.gd`, `game/ui/hotel_ui.gd`, `game/world/hotel/hotel_geometry.gd` (solo `:82-84`), `game/world/generation/floor_definition.gd` (solo firmas).
- **No reproduje nada:** no ejecuté Godot, ni `verify.ps1`, ni las herramientas. Los números de «18/18», los niveles medidos y los tiempos de cordura de `AUDIO.md` son afirmaciones del documento.
- **Orden de procesado padre e hijo:** lo deduzco del orden de Godot. No lo he probado.
- **Modo de importación de WAV `compress/mode=2`:** no sé qué modo corresponde al valor 2 del importador. La clase `AudioStreamWAV` lo documenta con otros números (`FORMAT_IMA_ADPCM = 2`, `FORMAT_QOA = 3`), pero no he confirmado la relación.
- **Atenuación por defecto de `AudioStreamPlayer3D`:** el código no fija `attenuation_model` salvo en las voces de todo el piso (`world_audio.gd:280`). No he comprobado el valor por defecto en la referencia.
- **`area_mask = 512`:** se asigna en varios sitios (`world_audio.gd:12`, `:162`, `:408`, `:470`; `hotel_locust.gd:437`; `locust.tscn:28,33`; `lurker`, `remote_player`, `kit_sounds`), pero no he encontrado un `Area3D` con audio de bus que lo use. No sé si tiene efecto práctico.
- **Licencias:** `docs/ASSETS.md`, `docs/assets/originals_manifest.json` y `docs/hotel_audio_inventory.json` (campo license) no los he leído en detalle. Solo sé que `AUDIO.md` cita licencias CC0, CC BY y «no comercial» y que `prepare_sfx.py` retira las no comerciales.
- **`tools/trailer3d/audio/dsp.py` y `mix.py`:** los usan varios scripts (`ffmpeg()`); no los he leído.
- **`docs/AUDIO.md` completo:** lo he leído, pero no contrasté todas sus cifras (sección 12).
- **Otros documentos citados:** `docs/PERFORMANCE.md` (sección 12), `docs/EXECUTION.md` (8.7), `docs/OFICINAS.md`, `docs/VISION_LOCUST.md`, `docs/PLAN.md`: no leídos.
- **Lógica de `phantom_passage`, `sanity`, `lifts` y `televisions`:** citadas en `AUDIO.md` pero no leídas.
- **Valores de `kit_sounds.gd`, `hotel_door.gd` (`SWING`, `FORCEFUL_SWING`), `remote_player.gd` (pasos de compañeros), `hotel_player.gd` (pasos del jugador, `max_db = 12` que dice `AUDIO.md:174`):** no confirmados.
- **Audio de la oficina (`office_*`):** los sonidos y su lógica (`game/floors/`, `game/enemies/lurker/`) solo se citan por carpeta; no se ha leído su código.
- **Subtítulo de presencia del Lurker y de pasos de compañeros:** no confirmados.
