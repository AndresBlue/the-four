# Ficha de hechos: The Lurker (la criatura del piso 2)

Fecha de la lectura: 14 de noviembre de 2026. Rama `main`, sin tocar git ni ejecutar Godot.
Cada cifra lleva su ruta:línea del repo (raíz `E:/Projects/The Four`). Esta ficha no propone diseño de Unreal: solo recoge lo que hay en el código y en los documentos.

Método: lectura completa de los 12 `.gd`, los 3 `.gdshader` y las 2 escenas de `game/enemies/lurker/`; `docs/LURKER.md` y `.claude/specs/spec_lurker_rebuild.md` enteros; de `tools/art/lurker/` se leyeron las cabeceras, las constantes y lo que el flujo de exportación toca (ver «Sin comprobar»).

---

## 1. Inventario de lo leído

| Fichero | Líneas | Qué hace |
|---|---|---|
| `game/enemies/lurker/lurker.gd` | 1646 | Cuerpo de la criatura (`extends creature.gd`): ensambla mente, sentidos, motor, rutas, cáscara, sonido, luz que bebe, red, capturas y observador. Es el único que toca la escena y el nodo de física. |
| `game/enemies/lurker/lurker_brain.gd` | 1139 | Mente (`RefCounted`): máquina de estados de 15 estados, memoria de la presa, elección de presa, encuentros, intentos, descanso. No toca la escena. |
| `game/enemies/lurker/lurker_senses.gd` | 508 | Sentidos: vista, oído (por sala y por conductos), luz que bebe, percepción de cada superviviente. Clases internas `Seen` y `Percept`. |
| `game/enemies/lurker/lurker_warning.gd` | 170 | Aviso: la única forma de cogida. Libro de avisos (`ledger`), veredictos y `audit()`. |
| `game/enemies/lurker/lurker_motion.gd` | 1189 | Motor de movimiento: sigue los tramos fotograma a fotograma (techo, banda, canal, rejilla, conducto, salto, subida). Vigilante de avance. |
| `game/enemies/lurker/lurker_routes.gd` | 979 | Planificador A* sobre salas, puertas, salidas y conductos; coste en segundos; tramos (`legs`) para el motor. |
| `game/enemies/lurker/lurker_shell.gd` | 1095 | «Cáscara»: superficies donde puede estar (bandejas = techos, franjas = dinteles y paredes, canales = pasillos de archivo), calculadas del manifiesto. Sin malla ni nodos. |
| `game/enemies/lurker/duct_graph.gd` | 171 | Grafo de conductos y plenum que ella ve (extiende `conduit_graph.gd`); salidas, baldosas abiertas, cierre por planta. |
| `game/enemies/lurker/lurker_visual.gd` | 463 | Presentación: el modelo, la tinta (dos volúmenes de sombreador), las manchas (decals), el tirón, el tic, el estiramiento al huir. |
| `game/enemies/lurker/lurker_limbs.gd` | 696 | `SkeletonModifier3D`: las 7 manos (IK por rayos, codos, dedos, garras) y la cabeza que mira. |
| `game/enemies/lurker/lurker_voice.gd` | 339 | Sonido de ella: pasos por superficie, golpes en conducto, crujidos del plenum, tandas por compás, chillido. Pool de `AudioStreamPlayer3D`. |
| `game/enemies/lurker/ceiling_dust.gd` | 404 | Polvo de techo: hilos, velos (niebla volumétrica o manchas), escamas y trozos, todo como `GPUParticles3D` y `FogVolume`. Clase con funciones `static`. |
| `game/enemies/lurker/lurker_darkness.gdshader` | 138 | Sombreador de la tinta y del vapor: raymarch de 10 pasos por rayo dentro de una esfera. |
| `game/enemies/lurker/ceiling_dust.gdshader` | 107 | Sombreador de partículas de polvo: dispersa la luz que les llega, sin normales. |
| `game/enemies/lurker/ceiling_dust_veil.gdshader` | 21 | Sombreador de niebla (`shader_type fog`) del velo de polvo. |
| `game/enemies/lurker/lurker.tscn` | 9 | Escena visual: `Node3D` con `lurker_visual.gd` y una instancia de `lurker.glb` como hijo `Model`. |
| `game/enemies/lurker/lurker_creature.tscn` | 18 | Escena del cuerpo: `CharacterBody3D` con `lurker.gd`, `BodyShape` (esfera de radio 0.3) y el visual. |
| `docs/LURKER.md` | 124 | Documento de diseño y estado de la criatura (lo que se ve, cómo se mueve, cómo se hizo). |
| `.claude/specs/spec_lurker_rebuild.md` | 139 | Especificación de la reconstrucción del 11 de noviembre de 2026 (estados, dificultad, sonido por compases). |
| `tools/art/lurker/make.py` | 70 | Punto de entrada: modelo, esqueleto, animaciones, `.blend` y GLB (`export_glb`, líneas 20-47). |
| `tools/art/lurker/build.py` | 767 | Malla desde campos de distancia, esqueleto y pesos, colores, dientes, garras, púas, textura de la cara (`bake_face`, línea 364). |
| `tools/art/lurker/anatomy.py` | 632 | Medidas, `LIMB_SPECS` (líneas 48-55: 7 brazos), huesos (clase `Bone`, línea 124), campos de distancia por pieza. |
| `tools/art/lurker/sdf.py` | 540 | Campos de distancia en numpy y «surface nets» para convertirlos en malla (no leído línea a línea). |
| `tools/art/lurker/animate.py` | 708 | Ocho clips resueltos fotograma a fotograma; `SPEEDS` (línea 35); solver de dos huesos; `ARM_SPAN = 0.86` (línea 432). |
| `tools/art/lurker/poses.py` | 74 | Renders de poses para revisar a ojo (solo cabecera). |
| `tools/art/lurker/scene.py` | 300 | Escalera de referencia y cámara para la comparación (solo cabecera). |
| `tools/art/lurker/preview.py` | 193 | Renders de estudio de la criatura (solo cabecera). |
| `tools/art/lurker/beauty.py` | 78 | Primeros planos de cara y manos (solo cabecera). |
| `tools/art/lurker/grade.py` | 48 | Etalonado de «foto analógica» con PIL/numpy, fuera de Blender (solo cabecera). |
| `tools/art/lurker/compare.py` | 31 | Pone una captura del juego junto a la imagen de referencia (solo cabecera). |
| `tools/art/lurker/bake_ink_noise.gd` | 55 | Script de Godot que hornea un ruido 3D a `assets/enemies/lurker/ink_noise.res`. Ver discrepancias. |

Ficheros externos que se citan (no leídos a fondo, solo para ver a qué se conectan): `game/enemies/creature.gd` (padre de `lurker.gd`), `game/enemies/creature_sight.gd`, `game/world/generation/conduit_graph.gd` (padre de `duct_graph.gd`), `game/audio/world_audio.gd` (buses, línea 527 `DUCT_BUS`), `game/world/hotel/hotel_geometry.gd` (línea 102 `LIT_DRAIN = 0.9`), `game/floors/palettes/office_palette.gd` (línea 904 `may_be_dark`).

---

## 2. Escenas y nodos

- `lurker_creature.tscn` (raíz, la que se instancia en el piso):
  - `CharacterBody3D` «Lurker», `collision_layer = 32`, `collision_mask = 0`, script `lurker.gd`.
  - Hijo `BodyShape`: `CollisionShape3D` con `SphereShape3D` radio 0.3, transformada en (0, 0.42, 0.1).
  - Hijo `Visual`: instancia de `lurker.tscn`.
- `lurker.tscn`: `Node3D` «Lurker» con `lurker_visual.gd`; hijo `Model` = instancia de `res://assets/enemies/lurker/lurker.glb`.
- Dentro de `Model` aparecen en ejecución, creados por código: el `Skeleton3D` del GLB (busca `neck`, `head`, `eye.L`, `eye.R`, `jaw`, `abdomen`, `body`), un `AnimationPlayer` (arranca `idle`, `lurker_visual.gd:190`), un `SkeletonModifier3D` hijo del esqueleto (clase de `lurker_limbs.gd`, creada en `lurker_visual.gd:158-161`), dos `MeshInstance3D` de la tinta y del vapor (`lurker_visual.gd:163`, `:189`), un `Decal` de mancha bajo el cuerpo (`:165-172`), un `Decal` por cada mano agarrada (`:173-182`).
- Capa de render propia: `LAYER = 4` (valor de máscara; es la capa 3, `lurker_visual.gd:13-15`). Todas las mallas del modelo van a esa capa (`:153-154`) y los decals la excluyen con `cull_mask = 0xFFFFF ^ LAYER` (`:169`, `:178`).

---

## 3. Qué hace cada pieza (una pasada)

- `lurker.gd` (cuerpo): en `_ready` crea la voz (`VOICE`), lee la semilla (`rng.seed = hash([semilla, "lurker"])`, línea 200), construye la cáscara, los conductos, las rutas y el motor (`arrive()`, líneas 208-231). En cada tick de física: `step_physics` (539-558).
- `lurker_brain.gd`: decide el intento de cada tick a partir de la percepción; no mueve nada. Devuelve un intent (`{do, clip, look, to, speed, hidden...}`); `lurker.gd:936-986` lo traduce a órdenes del motor.
- `lurker_senses.gd`: produce la percepción `Percept` (`perceive`, línea 315) con el reparto por superviviente (`Seen`).
- `lurker_warning.gd`: el aviso, dueño de la única cogida (`may_capture`, línea 117 de `lurker_warning.gd`; ver sección 5).
- `lurker_motion.gd`: avanza por los tramos; no decide qué hacer.
- `lurker_routes.gd`: sabe cómo llegar (A*); el motor le pide planes.
- `lurker_shell.gd`: sabe dónde puede estar (superficies); no conoce la escena.
- `duct_graph.gd`: sabe dónde están los conductos y el plenum.
- `lurker_visual.gd` y `lurker_limbs.gd`: dibujo; leen la transformada del cuerpo y dibujan entre dos ticks de física (`present`, línea 250; `smooth`, línea 263).
- `lurker_voice.gd`: sonido por compás; lee `beat` y `mood` del cuerpo.
- `ceiling_dust.gd`: polvo que se crea donde se mueve una baldosa; lo llaman la voz y las mentiras.

---

## 4. Máquina de estados de la mente

Enum `State` en `lurker_brain.gd:56`, en este orden (los estados nuevos van al final, `AMBUSH` es el 14):
`ROAM 0, LISTEN 1, STALK 2, PEEK 3, FREEZE 4, CREEP 5, CUE 6, TAKE 7, RECOIL 8, FLEE 9, TRANSIT 10, WAIT_ABOVE 11, HUSH 12, RETURN 13, AMBUSH 14`.

`decide()` (línea 275) en orden: `grace` → `hold`; `transit` → `keep`; `CUE` → `cue_tick`; luz en la cara de quien lleva linterna (`torch_by`) → `RECOIL`; mirada a luz → huida (`FLEE`) y el intento cuenta si se acercaba; luego `state_tick` (línea 310) despacha por estado; al final `watch_progress`.

| Estado | Qué hace (cifras con su origen) | Sale a | Líneas |
|---|---|---|---|
| ROAM | Ronda. Meta en este orden: ruido nuevo (tras `noise_react`), zona del director (`lead`), recuerdo (con `haunt_odds` 0.6, ±9 m), patrulla. Anda a `CRAWL_SPEED` 1.35 m/s. Al llegar, con 50 % (`LISTEN_P`) escucha si la sala tiene rejilla. | STALK o AMBUSH (si elige presa), LISTEN, RECOIL (linterna), FLEE (mirada) | `lurker_brain.gd:554-595`, `598-625` |
| LISTEN | Quieta en rejilla 3 a 6 s (`LISTEN_TIME`). Oye más lejos (`LISTEN_EAR` 1.4 en `lurker_senses.gd:108`). | STALK/AMBUSH si ve presa; ROAM si oye algo o pasa el tiempo | `627-648` |
| STALK | Sigue a la presa a `stalk_distance` (8 m por defecto, `:140`) fuera de su cono (`stalk_point`). Dura `stalk_time` (15 a 25 s por defecto, `:148`) × `STALK_SCALE[equipo]` (1, 0.85, 0.7, 0.6). Puede asomarse (`peek_odds` 0.5). Cambia de presa si otra puntúa 0.3 más. | HUSH (ocasión o tiempo), PEEK, WAIT_ABOVE (se esconde en taquilla conocida), ROAM (pierde la memoria a los 12 s) | `687-715` |
| PEEK | Va a un techo a 5-16 m de la mirada de la presa (`show_spot`, `lurker.gd:1251-1262`). Espera 4 s (`PEEK_TIME`) o huye si la miran 0.1 s (`PEEK_SEEN`). Si no llega en 10 s (`SHOW_WAIT`), vuelve. | STALK, HUSH (si `emerge_mode` = `behind`), FLEE, ROAM | `752-779` |
| FREEZE | Solo lo fuerza `force()`. Tras 3 s mirada, se retira 0.8 m/s. | resume o retirada | `1128-1139` |
| CREEP | Va a `behind_point(seen, 2.4)`. Velocidad `clamp(v_presa + 0.6, 1.0 × creep_scale, approach_cap)`. Si 5 s sin llegar a la espalda, vuelve a STALK. | CUE si `cue_ready`; STALK; WAIT_ABOVE si la presa se esconde | `854-876` |
| CUE | El aviso corre; se revisa cada tick con `warning.check`. Veredictos: `saved` → RECOIL; `aborted` o `expired` → STALK; `due` → TAKE. Mientras corre mantiene su distancia (`CUE_FOLLOW` 3.8 m/s si está lejos). | RECOIL, STALK, TAKE | `879-910` |
| TAKE | Espera `TAKE_EMPTY` 0.2 s y cierra el encuentro (`end_take`). | FLEE | `912-928` |
| RECOIL | Grita una vez (`world.scream`) y sale hacia el techo (`bolt`). | FLEE | `994-1002` |
| FLEE | En conducto: hasta `FLEE_HIDE` 6 s; fuera del techo, tras `FLEE_OUT` 0.4 s se da por dentro (`vanish`). Con `comeback` pendiente, pasa a RETURN. | RETURN, ROAM, bolt | `1023-1041` |
| TRANSIT | Entre plantas: `keep` mientras dura el tránsito (caída por conducto, 8.5 s, `RIDE_TIME`). | ROAM | `decide`, `280-283` |
| WAIT_ABOVE | Espera encima de la taquilla donde vio meterse a la presa, 20 a 40 s (`WAIT_ABOVE_TIME`, `:1103`). | CREEP si la presa aparece justa y visible; ROAM | `1112-1126` |
| HUSH | Silencio: quieta `hush_time` (2.5 s en Equilibrada, `:150`); si la presa se aleja más de `stalk_distance + 4`, vuelve a STALK. | CREEP | `719-729` |
| RETURN | Espera en el techo `comeback.at`; elige salida con la posición conocida de la presa (`emerge_point`); sale a `FLEE_SPEED` 3.5 m/s y, al llegar, acecha con 40 % del tiempo (`RETURN_STALK` 0.4). Si falla o pasan 20 s, ROAM. | STALK, ROAM | `1050-1079` |
| AMBUSH | Emboscada: se oculta por el plenum a un techo delante de la presa (`ambush_point`, `lurker.gd:1040-1061`), espera y da el aviso desde arriba. Sin pasar `AMBUSH_WAIT` 12 s. Solo si la presa va a ≥ 1.0 m/s (`AMBUSH_MOVING`) con probabilidad `ambush_odds` 0.3. | CUE, STALK | `814-842`, `802-812` |

Transiciones de forzado: `force(next)` (líneas 216-232) no admite CUE ni TAKE.

Encuentro (`lurker_brain.gd:672-678`, `:1007-1019`): un encuentro por presa con `tries` intentos (3 por defecto, `:141`). Cada fallo multiplica la espera de la vuelta por `ESCALATE` (1.0, 0.7, 0.5, 0.4, línea 1021). Tras el último intento deja a esa persona `rest_after` (90 s por defecto, `:142`). Tras una captura, `sated` (40 s, `:147`) para los que estén a menos de `SATED_NEAR` 8 m (`:136`). Pausa entre encuentros: `QUIET_BASE` 15 s (`:134`) × `PAUSE_SCALE[equipo]` (1, 0.75, 0.55, 0.4, `:132`), aplicada en `:931`.

Elección de presa: `score = 0.35·min(solo/15, 1) + 0.25·(a oscuras) + 0.2·min(rezagado/15, 1) + 0.2·(ocupado)` (`:481-483`); desempate con `rng·0.001` (`:486`, `:492`). Solo son candidatos los vistos este tick, justos, no escondidos, no protegidos, no dejados en paz y no «saciados» (`candidates`, `:472-478`).

---

## 5. Sentidos y aviso

Cifras de `lurker_senses.gd`:
- Vista: a oscuras `SIGHT_DARK` 20 m (`:97`); a una luz (la sala de la presa) `SIGHT_LIT` 4 m (`:98`); con linterna encendida se delata a `BEAM_SEEN` 35 m (`:100`); cono de `SIGHT_HALF` 110° (`:103`), salvo a menos de `SIGHT_NEAR` 1.5 m (`:104`). Mira cada `SENSE_EVERY` 0.1 s (`:106`); un superviviente por tick si hay más de cuatro (`:343-349`).
- Oído: alcance `radio × NOISE.HEARING_SCALE × hearing × dull × (1.4 si escucha) × (1 − 0.7 × fans)` (`:209`). Por salas con línea de vista o `navigation_path` (`:220-247`); por conductos (`:250-268`).
- Clic de linterna: audible a `TORCH_CLICK` 8 m (`:113`, `:430-439`).
- Memoria: `forget` 12 s (`:141`); extrapola la presa hasta `PREDICT` 2 s (brain `:389`).
- Luz que bebe: `DRAIN = (0.4, 0.7)` (`:118`): del borde del alcance (0.4) a justo bajo la lámpara (0.7). Ver sección 8.

Aviso (`lurker_warning.gd`):
- `TAKE_HOLD` 0.6 s después del plazo (`:14`); `TAKE_REACH` 3.4 m (`:16`); `TAKE_REACH_WALKED` = 3.4 + 4.0 = 7.4 m si no corre (`:19`); corriendo = velocidad ≥ `RUNNING` 5.0 m/s (`:22`); latencia máxima `LATENCY_CAP` 0.5 s (`:24`); `LONG_CUE` 1.2 s (`:32`).
- El plazo es `clock + window + latencia` (línea 61); `window` viene de `back_window` (brain `:138` por defecto 1.5 s; la tabla real está en `difficulty.gd`, no leído).
- Veredictos en `check()` (`:75-95`): salvo por mirada (`mirada`), linterna (`linterna`) o correr al llegar el plazo (`corriendo`); abortos por `fuera`, `protegida`, `escondida`, `con luz`, `movida`; expira `lejos`. Solo cogen si `may_capture` (`:117-122`) ve la misma tick.
- Subtítulos de aviso: «[Algo respira a tu espalda]», «[Algo respira cerca]», «[Algo respira sobre ti]» (`:34-37`).
- Sonidos de aviso: `cue_0..2.wav` y `cue_short_0..2.wav` (`:28-31`), elegidos por el `hold` (`cue_sounds`, `:33`).
- `audit(log)` (`:149-170`) es la comprobación de justicia del libro.

---

## 6. Rutas por techo, conductos y cáscara

Cáscara (`lurker_shell.gd`): solo se construye en la planta 2 (`build`, `:244-248`). Es matemática pura: no hay malla ni nodo.
- Tipos de parche (`Kind`, línea 15): `TRAY` (techo de una sala), `BAND` (franja que sube por un dintel o baja por una pared, o por el frente de una taquilla), `CHANNEL` (pasillo de archivo estrecho, `CHANNEL_MAX` 1.6 m, `:50`).
- Altura del techo de una sala: `py + altura de falso techo` si hay falso techo; si no, `py + EXPOSED_CEILING` 3.05 m (`:35`, `:292-294`).
- Anclaje: 0.35 m bajo el techo (`BAND_CLEAR`, `:21`); cuelga hasta 0.9 m en bandeja (`HANG_MAX`, `:26`), 1.5 m si baja para un aviso (`CUE_HANG_MAX`, `:61`).
- Dintel de puerta a 2.65 m (`OPEN`, `:32`); radio de los acuerdos `BEND` 0.45 m (`:17`); mínimo `R_MIN` 0.05 m (`:19`).
- Columnas: se rodean con margen `RADIUS` 0.45 + `COLUMN_MARGIN` 0.3 (`:80-81`); aproximación `APPROACH` 0.8 m (`lurker_routes.gd:55`).

Grafo de rutas (`lurker_routes.gd`):
- Nodos 0..R-1 = salas; R+k = nodo de conducto k (`:74`, `:117-131`).
- Aristas: `OPEN` (sala abierta), `DOOR` (puerta; `+0.5 s` `PORTAL_COST`), `IN` y `OUT` (rejilla, hueco o baldosa; `ENTER_COST` y `LEAVE_COST` 1.5 s), `DUCT` (conducto; coste en metros entre velocidad del tramo: 1.0 m/s en el principal, 1.6 m/s en el resto, `duct_speed`) (`:25-27`, `:36-39`, `:386-403`).
- Factores por sala: `LIT_FACTOR` 6 si la sala tiene luz (`:21`); `POWER_FACTOR` 25 si la sala la marca el equipo (`:23`, `:357-360`).
- Puertas: abiertas solo si el nodo dice `opened`, sin `moving` ni `locked` (`:323-331`); una puerta sin nodo cuenta como cerrada y avisa con `push_error` (`:327-329`). Ella nunca la abre.
- Vetos: `BAN_TIME` 10 s (`:31`) que pone el vigilante de avance del motor (sección 6).
- Cruce del principal: si un superviviente repta por el principal a menos de `CROSS_CLEAR` 1.0 m del cruce hacia el pozo, cierra la arista de cruce (`:45`, `:194-203`, `:376`).
- Búsqueda: A* con montículo (`search`, `:445-487`), heurística distancia/velocidad más rápida; `plan` devuelve `{ok, cost, nodes, legs, pairs, why}` (`:495-532`).
- Tramos (`legs`): `tray` (punto del techo), `band` (franja), `squeeze` (rejilla o baldosa), `duct` (puntos de conducto con su tipo), `channel`, `into_channel`, `turn`, `leap`, `climb` (tipos que lee `lurker_motion.gd:853-865`).
- Salida tras bajar de planta: `arrival_exit` elige una salida entre el 50 % y el 90 % del paseo de la entrada, ponderada (`:949-979`; único uso del azar de rutas).
- Huida: `flee_exit` pena 8 s (`FLEE_TOWARD`, `:36`) a las salidas que miran hacia la amenaza; las baldosas nunca hacia nadie (`:929-944`).
- Distancias para el director y el sonido: `travel_metres` (Dijkstra en metros, con caché por firma de puertas, `:865-896`).

Conductos (`duct_graph.gd`):
- Se construye desde `manifest.ducts` (`of`, `:28-32`); nodos con planta (`node_wings`), tipo (`node_kinds`: `trunk`, `branch`, `main`, `cross`, `gap`, `plenum`) y aristas `[a, b, metros, tipo]` (`:108`).
- Salidas (`exits`): tipos `ceiling`, `wall`, `duct`, `gap`, `tile`, `hatch` (la trampilla solo abre si el objetivo de aire lo deja, `routes:363-366`).
- Plenum: un nodo por sala con falso techo, sobre la baldosa libre más cercana al centro; las baldosas válidas son `OFFICE.free_tiles(room)` menos las ya tomadas (`:66-94`).
- Visibles: solo `main` y `cross` (`:16`). Ventiladores de la planta 3 cierran sus conductos (`closed_wings`, `:18`, `:168-171`).

Movimiento (`lurker_motion.gd`):
- Cada tick (`tick`, `:693-722`): `routes.tick`; cada 0.25 s `fans()` y `ray()`; vigilancia de puertas; si toca, cambio de planta; cuenta atrás de la caída; `follow(delta)` por tramo; `watch_progress`; `velocity` = desplazamiento / delta.
- Velocidades: andar 1.35 m/s (`CRAWL` de `routes:19`); `SCURRY_SPEED` 3.5 m/s (`:17`); `RETREAT` 0.8 m/s (`:18`); en rejilla `SQUEEZE_SPEED` 0.6 m/s (`:21`); rafagas vigiladas `BURST_SPEED` 3.3 m/s con tiempos `BURST_TIME` (0.45-0.85 s) y `STILL_TIME` (0.3-0.7 s) (`:32-34`); aceleración `ACCEL` 4 y frenada `BRAKE` 6 m/s² (`:24-25`); rafagas `BURST_ACCEL` 20 (`:35`).
- Giro: `HEADING_RATE` 3 rad/s (`:38`), `TURN_RATE` 4 rad/s (`:39`); altura `HANG_RATE` 0.5 (`:40`).
- Cuelgue: `BODY_DEPTH` 0.77 m (`:45`), `HEAD_CLEAR` 0.25 m (`:47`); rayo cada `RAY_EVERY` 0.25 s (`:48`), máscara `RAY_MASK` = 1 | 4 (`:50`).
- Vigilante de avance (`watch_progress`, `:783-819`): `PROGRESS_METRES` 0.1 m en `PROGRESS_TIME` 1.5 s. Nivel 1 replanifica; nivel 2 veta la primera puerta 10 s y replanifica; nivel 3 pone `stuck = "sin avance"`.
- Salto largo (`leap`, `:497-510`): `LEAP_REACH` 7.5 m, `LEAP_TIME` 0.6 s, `LEAP_RISE` 0.3 m (`:72-74`); no pasa por columnas (`:502`).
- Subida tras el salto: `CLIMB_SPEED` 1.5 m/s (`:75`).
- Encogimiento bajo techo bajo: `SQUASH_MIN` 0.4 (`:78`), `SQUASH_RATE` 1.0 (`:78`).
- Ante un superviviente: a `SURVIVOR_TOP` 1.85 m de altura (`:81`) se para a `BODY_GAP` 0.45 m (`:82`).
- Huida por rayo (`bolt`, `:427-447`): `BOLT_TIME` 0.3 s, velocidad = clamp(metros hasta dentro / 0.3 s, 8, 40) m/s (`:427-429`, `:443`).
- Entre plantas: `RIDE_TIME` 8.5 s (`:84`).
- Las puertas se cruzan sin parar si va alineada a menos de `DOOR_ALIGN` 0.3 rad (`:69`).

---

## 7. Miembros procedurales

Lo que es malla importada: solo el `lurker.glb` (cuerpo, cara, ojos, dientes, esqueleto de 142 huesos según el documento, 8 clips). Todo lo demás se calcula en cada tick o en cada fotograma.

Manos (`lurker_limbs.gd`):
- Siete manos `["a.L", "a.R", "b.L", "c.R", "d.L", "e.R", "f.L"]` (`:26`), dos conjuntos que se turnan: `{a.L, c.R, d.L}` y `{a.R, b.L, e.R, f.L}` (`:28`).
- Hábito por brazo `HABIT` (`:32-33`): inclinación hacia techo (+) o suelo (−) y ritmo; `PLANE` por brazo (`:158`) y `SWAY` 0.14 (`:159`).
- Sondas: 11 rayos en abanico desde el hombro, de 70° por debajo del plano del cuerpo a 86° por encima (`PROBES`, `:47`; positivo = hacia abajo); 2 sondas por fotograma (`:289-291`).
- Elección del apoyo: distancia de la muñeca dentro de `CLOSEST` 0.4 y `REACHABLE` 0.8 (× alcance), ideal `IDEAL` 0.58 (`:50`, `:83`, `:86`); puntaje con `REACH_UP` 0.12 (`:34`), `cling` (0.22) y la anticipación `SWEEP` 0.9 (`:37`).
- Alcance del brazo: `ARM_SPAN` 0.88 × (l1 + l2) (`:51`, `:233`).
- Paso: `STEP` = (0.85, 0.28) s entre andar y correr; `STEP_FAST` 3.4 m/s (`:75-76`); altura `LIFT` 0.22 × longitud del brazo (`:77`); `DWELL` 0.6 s antes de cambiar de apoyo (`:40`); `DUE` 0.85 y `MUST` 0.97 de estiramiento (`:94-95`); corre si la velocidad supera `RUNNING` 1.8 m/s (`:42`).
- Codos: `KNEES` 1.6 (`:96`); se giran en pasos de π/12 hasta el primer hueco libre (`ELBOW_STEPS` 12, `:91`); radio de la bola del codo `ELBOW` 0.05 (`:88`); se comprueba con `_room` (esfera), `_clear` (rayo) y la máscara `solid_mask` (`:108`).
- Dedos: cada uno se dobla hasta que la punta de la garra quede en `DIG` 0.012 m del apoyo (`_touch`, `:599-617`); `CLAW` = (0.25, 0.55, 1.0) (`:60`); `CLAW_SPREAD` 0.3 (`:61`); `WRIST` 0.06 × longitud de mano (`:62`).
- Cabeza y ojos: cuello `LEAD` 0.09 m (`:98`); el cuello gira a 0.5 del peso con tope 55°, la cabeza 1.0 con tope 70° (`:649`); la cara vertical con `UPRIGHT` = π (`:101`); suavizado `TURN` 5/s (`:102`); los ojos giran con tope 40° (`:690`).
- Mandíbula: se abre si mira a menos de `JAW_NEAR` 4 m (`:151`), `JAW_OPEN` 0.45 rad (`:152`).
- Máscaras: `world_mask` = 1 (`:104`); `solid_mask` = 1 | 4 | 8 | 128 (`:108`): mundo y muebles, supervivientes, puertas y hojas de taquilla, hojas abiertas.

Cuerpo y tirones (`lurker_visual.gd`): tirón por cada mano que se posa `SURGE_KICK` 1.2 (`:113`), muelle de `SURGE_HZ` 1.8 y amortiguación `SURGE_DAMP` 0.45 (`:114-115`), tope `SURGE_MOST` 0.07 m (`:116`), cabeceo `SURGE_PITCH` 0.25 (`:117`); vientre `ABDOMEN_LAG` 0.7 y `ABDOMEN_SWAY` 0.08 (`:118-119`). Zancada `STRIDE` 0.9 m, `BOB` 0.018, `ROLL` 0.05, `LEAN` 0.025 con tope 0.22 (`:85-89`). Agarre: `CONTACT` 0.3 m, `PRESS_MOST` 0.3, `TRUNK` 0.22 (`:102-104`). Estiramiento al huir: `STRETCH` 0.3 y `SWEPT_FROM` 6 m/s (`:128`, `:81`).

Tinta y vapor: ver sección 8 y 3. Radio de la tinta `0.95 × size` (1.54 m con `size` 1.62), grosor `0.2 × size`, densidad 40 (`lurker_visual.gd:163`); vapor radio `0.6 × size`, `gloom` 4.0 (`:189`, `:23`).

Manchas: decal bajo el cuerpo (`:165-172`, `Vector3(1.1, 0.9, 1.1) × size`); una por mano agarrada que aparece y se desvanece (`stain_grips`, `:381-399`, subida 5/s y bajada 2/s).

Tic y sacudida: `TIC` 0.349-0.698 rad (20 a 40°, `:68`), `TIC_HOLD` 0.6-1.8 s (`:69`), `TIC_GAP` 1.2-3.8 s (`:70`), `TIC_SNAP` 14 (`:71`); sacudida `SHUDDER` 0.012 cada 2 a 6 s solo quieta (`:72`, `:425-427`).

Tamaño: `size` = 1.62 (`:26`) sobre el modelo construido (en el documento, antes 1.35).

---

## 8. La oscuridad que bebe luces

- Dónde se cuenta: `SENSES.lamp_points` (lámparas por sala; troffer, batten, la del cuarto o las de emergencia) (`lurker_senses.gd:275-296`) y `drain_rooms` (`:301-311`): una sala se bebe si está encendida (`level.hotel.lit(id)`) y su planta coincide. Cantidad: `lerp(0.7, 0.4, cercanía/alcance)` (`:310`).
- Alcance: `drain_reach` = 3.5 m (`lurker.gd:868`), sobrescribible por el perfil.
- Cada `DRAIN_EVERY` 0.1 s (`lurker_senses.gd:119`, `lurker.gd:1473-1478`) se fijan los objetivos, salvo si está en tránsito, oculta (`hushed`), con gracia o sin nivel (`:1477`).
- Cada fotograma (`_process`, `lurker.gd:1483-1521`): cada sala se acerca a su objetivo a 1.0/s si ya estaba muy bebida (más de 0.78) o a 1.5/s si no (`lurker.gd:1500`), con temblor `DRAIN_WOBBLE` 0.08; cada cambio se escribe con `hotel.drain(room, cantidad)` y, al llegar a 0, se devuelve con `drain(room, 0)`; `hotel.LIT_DRAIN` = 0.9 (`hotel_geometry.gd:102`) es la cantidad a partir de la cual la sala cuenta como a oscuras (comentario de `lurker.gd:1506-1507`).
- Bebida profunda («snuff», `snuff_step` `lurker.gd:1600-1615`): si acecha a alguien en una sala encendida durante `snuff_time`, bebe la sala entera (`DEEP` 0.93, subida `DEEP_RISE` 0.3/s, bajada `DEEP_FALL` 1.0/s, tope `DEEP_MOST` 25 s, `DEEP_OUT` 3 s, `DEEP_AGAIN` 45 s, temblor `DEEP_WOBBLE` 0.12, `DEEP_REST_WOBBLE` 0.02) (`lurker.gd:134-141`). Se propaga por el evento «snuff» (`tell`, `:1634`).
- Linternas bebidas: `drink_torches` (`:1525-1532`), `DRUNK_BEAM` 0.15 (`:104`), `DRUNK_RAMP` 1.0 s (`:105`), sonido `off_2.wav`, ganancia −6 dB (`:106-107`). Apagadas para siempre: `kill_torches` (`:1561-1566`), `SPARK` 0.2 s (`:116`).
- Para las reglas, beber la luz (`DRAIN`) no deja la sala a oscuras; solo la bebida profunda sí (`docs/LURKER.md:93`).

Sombreador de la tinta (`lurker_darkness.gdshader`): `render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled` (línea 12). Dibuja la cara trasera de una esfera y para cada rayo integra en `STEPS` = 10 (`:124`) pasos entre la entrada en la esfera y la primera superficie opaca (lectura de `hint_depth_texture`, `:108-116`). Ruido con dos octavas (`:71-72`) y «remoción» del espacio (`:67-70`); el hash y el ruido se calculan en el propio shader (`:43-57`). `ALPHA = 1 − exp(−suma × densidad)` (`:137`). Franja de derrame `spill` en la superficie (`:117-135`, `FILM` 0.1 en `:38`). Rama para el renderer de compatibilidad (`:109-113`).

---

## 9. El polvo de techo

Clase `ceiling_dust.gd` con funciones `static` (no es un nodo). Entrada: `fall(level, point, opened)` (`:62-77`), `seep(level, point, ceiling_y)` (`:81-90`) y las mentiras; `share(level)` = 0.35 en la calidad más baja si `hotel.preset.dust <= 0` (`:93-97`).
- Hilos (`thread`, `:101-140`): `GPUParticles3D` con `ParticleProcessMaterial`; `gravity` (0, −1.8, 0); amortiguación 5-7 con curva; turbulencia `scale` 1.6 (`:114-119`); `life` 1.6 s; `scatter` 7.0 y `min_pixels` 2.5 en el sombreador (`:133`). Cantidad `THREAD_GRAINS` 600 × `HEFT` (1.0, 0.6, 0.35) (`:36`, `:41`).
- Velo con niebla volumétrica (`veil`, `:154-207`): `FogVolume` elipsoidal; tamaño `VEIL_SIZE` (1.4, 2.2, 1.4) (`:46`); densidad `VEIL_DENSITY` 3.0 (`:45`) en 0.5 s; vida `VEIL_LIFE` 9 s (`:47`); `MAX_VEILS` 3 (`:43`); el velo sube en 0.5 s, se hunde y se disipa; el ojo lo aclara (`follow`, `:198-201`). Albedo `VEIL_GLOW` 16 × `VEIL_TORCH` 0.35 (`:51-52`, `:180`).
- Sin niebla volumétrica (`puffs`, `:210-233`): `PUFFS` 40 manchas de 0.1-0.3 m (`:27`, `:37`).
- Escamas (`flakes`, `:236-267`): `FLAKES` 8 (`:38`), `life` 4.5 s, velocidad limitada a 0.45 m/s (`:248`), rotación 3D.
- Trozos (`crumbs`, `:271-322`): `CRUMBS` 6 (`:39`), `GPUParticles3D` con colisión rígida y un suelo `GPUParticlesCollisionBox3D` de 4 × 0.2 × 4 (`:317-319`), vida 10 s.
- Sombreador de dispersión (`ceiling_dust.gdshader`, `:105-107`): `DIFFUSE_LIGHT += LIGHT_COLOR × ATTENUATION × scatter / PI`; sin N·L; `billboard` o `axial` (la partícula se alinea con su trayectoria); `wrap` para polvo en el aire (`:11-16`).
- Carga por placa abierta: unas 1.185 partículas (600 + 360 + 210 hilos, 8 escamas, 7 trozos) más un `FogVolume`, o 40 manchas sin niebla (cifras del documento y de las constantes; coinciden).

Número de hilos por fallo: `fall()` usa 3 hilos si se abre la placa, 2 si se mueve (`:69`).

---

## 10. Audio

Pasos (`lurker_voice.gd`):
- Material por superficie (`material_at`, `:137-146`): conducto → `metal`; plenum → `tile`; techo de falso techo → `tile`; suelo duro → `hard`; moqueta → `soft` (`-20 dB`, corte 1200 Hz, `:21`, `:23`); archivo (franja de 0.25 m) → `metal`; pared de madera → `wood`; resto → `hard`.
- Ganancia por material (`STEP_DB`, `:21`): tile −11, metal −8, hard −12, wood −11, soft −20. Más `lerp(−6, 0, fuerza)`, y el `duck_db` del ambiente (`:164`).
- Pasos: como mucho uno cada `STEP_GAP` 0.09 s (`:25`); hasta `STEP_VOICES` 3 voces a la vez (`:26`); con `CREEP_FORCE` 0.8 si acerca (`:28`).
- Arrastre por pared: `WALL_CHANCE` 0.25 si acecha o se acerca (`:30`, `:168`).
- Tandas (`RUNS` por compás, `:48-49`): `roam_far` 6-8 pasos muy rápidos y silencio 6-12 s; `rest` silencio 9-16 s; `stalk` 2-4 pasos y 2.5-5 s; `scare` 12-16 pasos seguidos. `RUN_STEP` 0.06-0.09 s; `RUN_REST` 1.2-2.6 s (`:38-41`).
- Conductos: golpes `knock_1..8` con `KNOCK_DB` −6 (`:20`, `:31`), arañazo `scrape_1` con `SCRAPE_CHANCE` 0.35 (`:42`); plenum: crujido `tile_creak_1..3` (`CREAK_DB` −10, `:32`), polvo `SEEP_CHANCE` 0.35 (`:14`). Silencio mientras `hushed()` o `beat == return` (`:190`).
- Ruta de sonido: `play_routed` (`:286-299`) pregunta `creature.sound_route_from` y ajusta el reparto; `apply_route(player, route, gain + mask_db, "Threat", true)`, `attenuation_filter_cutoff_hz`. Voces `AudioStreamPlayer3D`: `unit_size` 6.0, `max_distance` 40.0, `max_db` 4.0, `pitch_scale` 0.9-1.08, `area_mask` = `world_audio.ACOUSTIC_MASK` (`:329-333`).
- Bus de conducto `DUCT_BUS` = `&"Ducts"` (`world_audio.gd:527`). Buses `Threat`, `Creature` (`world_audio.gd:19-28`).
- Desde conducto (`lurker.gd:432-444`): `ducts.sound_route` por rejillas, con memoria `ROUTE_MEMO` 0.25 s (`:28`) con reloj de pared (`Time.get_ticks_msec`, línea 434). Desde plenum (`:448-456`): `PLENUM_LOSS` −6 dB (`:25`) y corte `PLENUM_CUTOFF` 1800 Hz (`:26`).
- Chillido: «[Un chillido]» a menos de `CAPTION_NEAR` 16 m (`lurker_voice.gd:261-267`); asusta con `SHRIEK_FRIGHT` 12 m (`lurker.gd:33`, `:1317-1327`) a quien tenga línea despejada.
- Presencia: el sonido es el perfil `game/audio/profiles/lurker.tres` (`lurker.gd:37`, `:1277`); `world_audio.gd:136` lo pone en el bus `Threat`; solo suena sobre una taquilla (`lurker.gd:401`). El subtítulo que pide el documento no está en el código (ver discrepancias).
- Compases (`mood()` y `MOODS`, `lurker.gd:584-613`): `aura`, `clicks`, `menace`, `fast`, `silent` por cada beat (`roam_far`, `roam_near`, `listen`, `stalk`, `peek`, `hush`, `creep`, `cue`, `scare`, `return`, `rest`, `above`, `transit`, `ambush`). `silent` corta la voz (`lurker_voice.gd:109`).
- Ducking: `HOLD_BEATS` = `[hush, cue]` (`:60`); `HOLD_REACH` 14 m (`:61`); `HOLD_TICK` 0.2 s (`:62`); `duck_under` del ambiente (`:117-125`).
- Coche del montacargas (`outside_car`, `:272-282`): cada 0.6 a 1.3 s (`CAR_SCRATCH`, `lurker.gd:31`) rasguño fuera de la chapa del coche, sin enrutar (bus `Creature`, −8 dB `:51`).
- Aviso (`lurker_warning.gd:28-37`): archivos y subtítulos (ver sección 5). El aviso se oye limpio: `CLEAN` 0.5 s antes de su plazo ni un sonido suyo empieza en la máquina de la víctima (`lurker_voice.gd:52-54`, `:113`).

---

## 11. Cadena de arte

Flujo real (`tools/art/lurker/`):
1. `make.py` (entrada, 70 líneas): `blender -b --factory-startup -P tools/art/lurker/make.py -- --blend art/lurker/lurker.blend --glb assets/enemies/lurker/lurker.glb` (comando de `docs/LURKER.md:25`, verificado en la cabecera de `make.py:1-7`).
2. `build.py`: `build.build(opts)` construye las piezas (`part_list`, `:301-316`). Presupuestos antes de diezmar: cabeza 19 000 triángulos (`:303`), cuerpo 7 000 (`:306`), cada brazo 2 400 (`:310`), cada mano 6 000 × max(escala, 0.65) (`:315`); diezmado por la función `decimate` (`:93-100`, modo `COLLAPSE`); `--fast` multiplica por 1.6 (`:302`).
3. `sdf.py`: campos de distancia en numpy y «surface nets» (cabecera de `sdf.py`); `anatomy.py`: formas y medidas.
4. `bake_face(ob, node, feats, size=1024)` (`build.py:364`) hornea la cara a 1024 px y crea `face_material` (`:724`).
5. `animate.build_all(rig)` (`make.py`, tras `build.build`): ocho clips resueltos y escritos como acciones de huesos, una clave por fotograma, 30 fps (`docs/LURKER.md:40`; `write_action` en `animate.py:227`, `bake` en `:273`; importación `animation/fps=30`).
6. `export_glb` (`make.py:20-47`): `export_format` GLB, `export_yup`, `export_apply`, `export_skins`, `export_influence_nb` 4, `export_animations` por ACCIONES, `export_optimize_animation_size`, `export_vertex_color` MATERIAL, sin cámaras ni luces.
7. Resultado: `assets/enemies/lurker/lurker.glb` (5 527 156 bytes, medido).
8. Importación de Godot (`lurker.glb.import`): `meshes/generate_lods=true`, `meshes/create_shadow_meshes=true`, `skins/use_named_skins=true`, `animation/fps=30`, `animation/remove_immutable_tracks=true`, `nodes/apply_root_scale=true`.
9. Materiales que sustituyen a los del GLB (los aplica la importación por carpeta, `docs/LURKER.md:72`): `lurker_body.tres` (`StandardMaterial3D`, sin sombreado, albedo negro), `lurker_face.tres` (textura `lurker_lurker_face.png` de 496 KB, rugosidad 1, especular 0), `lurker_matte.tres` (color por vértice, rugosidad 1). Fuente: `docs/LURKER.md:72`.
10. Revisión: `poses.py`, `preview.py`, `beauty.py`, `scene.py`, `grade.py`, `compare.py`: renders y comparación con la foto; no entran en el juego.
11. Ruido de la tinta: `bake_ink_noise.gd` (huérfano, ver discrepancias).

Clips (`animate.py`): `idle` (`:509`), `crawl` (`:542`), `crawl_fast` (`:553`), `vent_crawl` (`:565`), `retreat` (`:586`), `loom` (`:598`), `scare` (`:621`), `peek` (`:651`); velocidades `SPEEDS` = crawl 1.0, crawl_fast 2.6, vent_crawl 0.55, retreat −1.5 (`:35`). El juego usa la lista `CLIPS` de `lurker.gd:39` (mismos nombres).

Brazos: `LIMB_SPECS` de `anatomy.py:48-55`: siete entradas, cada una `(ángulo en grados, tamaño, brazo, antebrazo)`: `a.L` (30, 1.00, 1.00, 1.08), `a.R` (38, 0.90, 1.12, 0.94), `b.L` (60, 0.58, 0.90, 1.18), `c.R` (80, 0.80, 1.06, 1.00), `d.L` (102, 0.86, 0.98, 1.14), `e.R` (124, 0.70, 1.16, 0.90), `f.L` (146, 0.66, 0.94, 1.12). Los nombres de hueso son `clavicle_<mano>`, `upperarm_<mano>`, `forearm_<mano>`, `hand_<mano>` y `<dedo>_0<1..3>_<mano>` con dedos `thumb, index, middle, ring, pinky` (`build.py:305-315`).

---

## 12. Qué decide el anfitrión frente a cada cliente

- `control` = `"ai"` (quien la mueve) o `"puppet"` (réplica) (`lurker.gd:233-237`). `step_physics` (`:539-558`): solo `"ai"` piensa, mueve y aplica; `"puppet"` sigue la transformada recibida (`follow_state`, `:514-529`, con retardo de 0.1 s en `:517`).
- En cada máquina, cada tick: `sound_beat` (`:626-639`), `drain_step` (`:556`), `show_body` (`:557`), `sound_step` (`:558`). Por tanto, la luz que bebe, la forma de caminar, el sonido y la visibilidad se calculan en todas las máquinas a partir de los datos que llegan.
- Red: el paquete de estado tiene 12 campos (`PACK_SIZE`, `:42`, `pack_state` `:490-493`): posición, rotación, velocidad, palabra, banderas, gracia, mirada, clip, nodo cercano, contador de saltos, estado de la mente, presa. `push_state` (`:495-512`) reajusta la posición al cambiar el contador de saltos.
- Eventos fiables (`tell`, `:1295-1298`; `on_event`, `:1300-1313`): `scare` (grito y luz bebida o apagada), `torch`, `snuff`, `tile`. Se aplican aquí y se envían a `match_net.creature_event`.
- Solo el anfitrión: aviso (`lurker_warning.gd` y `may_capture`, `lurker.gd:1367-1373`), la mente (`think`, `:893`), las capturas, el susto colectivo (`frighten` solo si `match_net.in_charge()`, `:1321`), las emisiones del aviso a la red (`send_cue` `:885-886`), la lectura de las linternas apagadas (`dead_torch_step`, `:1570-1577`).
- Capturas forzadas por una herramienta: `executions.forced` las acepta y las anota (`:1370-1372`).
- Mentiras (`lurker_hallucinations.gd`, 631 líneas, no leído): se separan en otro módulo y no bebe luz ni toca objetivos (según el documento, `docs/LURKER.md:102`).

---

## 13. Constantes y cifras que definen cómo se siente y se ve

Movimiento y velocidad (con ruta:línea): ver las secciones 4, 6 y 7. Las más importantes para el aspecto:

- Tamaño del modelo `size` 1.62 (`lurker_visual.gd:26`); tinta radio 0.95 × size, grosor 0.2 × size, densidad 40 (`:163`); vapor 0.6 × size, grosor 0.22 × size, densidad `gloom` 4 (`:23`, `:189`); `SPILL` 1.7 (`:105`).
- Estela de la tinta: `TRAIL_CATCH` 7.0 (`:64`), `TRAIL_MOST` 0.55 (`:65`), cola de 0.5 (`:351`); `SWEPT_FROM` 6 m/s (`:81`).
- Pose: `CROUCH` 0.07 (`:66`), `TORSO_FROM` 1.35 y `TORSO_MOST` 0.8 (`:73-74`), `TORSO_RATE` 5 (`:78`); `NECK` 0.32 y `SHOULDER` 0.24 de tinta (`:76-77`).
- Suavizado de la cámara (presentación): `TURN_MOST` 6 rad/s (`:44`), `LAG_TIME` 0.08 s (`:45`), `LAG_MOST` 0.15 m (`:46`).
- Manos: `ARM_SPAN` 0.88 (`lurker_limbs.gd:51`) frente a 0.86 en `animate.py:432`; `IDEAL` 0.58 (`:50`); `PROBES` (`:47`); `STEP` (0.85, 0.28) s y `STEP_FAST` 3.4 m/s (`:75-76`); `LIFT` 0.22 (`:77`); `DWELL` 0.6 s (`:40`).
- Luz: `SIGHT_DARK` 20, `SIGHT_LIT` 4, `BEAM_SEEN` 35 m (`lurker_senses.gd:97-100`); `DRAIN` (0.4, 0.7) (`:118`); `DRAIN_EASE` 1.5/s (`:121`); `DRAIN_WOBBLE` 0.08 (`:123`).
- Polvo: `THREAD_GRAINS` 600, `PUFFS` 40, `FLAKES` 8, `CRUMBS` 6 (`ceiling_dust.gd:36-39`); `VEIL_SIZE` (1.4, 2.2, 1.4), `VEIL_LIFE` 9 s, `MAX_VEILS` 3 (`:43-47`).
- Aviso: `TAKE_REACH` 3.4 m (`lurker_warning.gd:16`); `TAKE_REACH_WALKED` 7.4 m (`:19`); `RUNNING` 5.0 m/s (`:22`); `TAKE_HOLD` 0.6 s (`:14`).
- Sonido: `STEP_DB` (`lurker_voice.gd:21`); `RUNS` (`:48-49`); `CAR_DB` −8 (`:51`); `DUST_DB` −16 (`:50`).

---

## 14. Orden de ejecución, física, azar y reloj

Orden de un tick de física (`lurker.gd:539-558`):
1. `grace` decrece (`:540`).
2. Si `ai`: `think(delta)` (`:892-913`): `senses.perceive` (percepción, con sus `SIGHT.clear` y raycasts), `watch_systems` (luz de la sala y ventiladores, cada 0.25 s), `brain.tick` (la decisión), `apply_intent` (órdenes al motor), `snuff_step`.
3. `motion.cue`, `motion.unseen = unseen_now()`, `motion.watched = SIGHT.watched(...)` (`:546-549`).
4. `motion.tick(delta)` (`lurker_motion.gd:693-722`) y `apply_motion()` (`lurker.gd:671-675`).
5. `sound_beat`, `drain_step`, `show_body`, `sound_step`.

Otros bucles:
- `lurker.gd:_process` (`:1483-1521`): cada fotograma, lectura y escritura de la luz de cada sala (`hotel.drain`) y de las linternas (`torch_step`, `:1535`). Usa `Time.get_ticks_usec` solo para medir (`:1486`).
- `lurker_visual.gd:_process` (`:300-313`): `smooth` (interpolación de física con `Engine.get_physics_interpolation_fraction`, `:274`; contadores `Engine.get_process_frames`, `:264`), velocidades de las manos, `hold_on` (un `cast_motion` por fotograma, `:375`), `pose_body` (tics, sacudidas, torso), `stain_grips`.
- `lurker_limbs.gd:_process_modification_with_delta` (`:271`): se ejecuta después del reproductor de animación (`SkeletonModifier3D`), con raycasts del estado del espacio de física en el frame de proceso (`:280`).
- `lurker_motion` usa `Engine.get_physics_frames()` en `log_jump` (`:216`) y `lurker_routes` en las firmas de puertas (`:336`, `:222`).
- `lurker_visual.present` compara `Engine.get_physics_frames()` (`:251-252`).
- `lurker_voice.now()` usa el reloj de pared `Time.get_ticks_msec()` (`lurker_voice.gd:102`) para la ventana del aviso (`may_sound`, `:113`). No es tiempo de simulación.
- `lurker.gd:434`: memo de rutas de conducto con `Time.get_ticks_msec()`.
- Tweens y temporizadores: `create_timer` para liberar partículas (`ceiling_dust.gd:375`, `lurker_voice.gd:241`) y `create_timer(TILE_GRIP)` para soltar la mano de la baldosa (`lurker.gd:1180`). Tweens de los velos (`ceiling_dust.gd:190-207`) y de las partículas (`:137-140`).
- `Tween` y `GPUParticles3D` no son deterministas entre máquinas (lo emite el motor).

Azar (semillas y usos):
- `lurker.gd:200`: `rng.seed = hash([semilla, "lurker"])`. Ese mismo `rng` lo usa el cerebro (`lurker.gd:883`, `brain.setup(self, rng, warning)`).
- `lurker.gd:222`: `motion.rng.seed = rng.seed` (solo `tick_bursts` y `arrival_exit` lo usan: `lurker_motion.gd:562`, `:681`).
- `lurker.gd:324-325`: cuarto de descanso (`den`) con semilla `hash([semilla, "lurker_den", planta])`.
- `lurker_voice.gd:95`: `rng.seed = hash(["lurker voice", semilla])`. Pitch de cada voz con ese rng (`:333`).
- `lurker_senses.gd`: sin azar propio.
- `lurker_limbs.gd`: sin azar.
- `ceiling_dust.gd:67-68`: rng por hash del punto de la caída (determinista por punto). Pero `:88` (`randf_range`) y `:90` (`randf`) usan el rng GLOBAL del motor sin semilla.
- `lurker_visual.gd:150`: `tic_rng.randomize()`; los tics y las sacudidas no son reproducibles (solo dibujo).
- Las decisiones del cerebro dependen del orden de las llamadas a `rng` (`choose_prey`, `pick_goal`, `begin_stalk`, `failed_attempt`, `return_target`, `to_locker`, `begin_hunt`): cualquier cambio de orden cambia el resultado con la misma semilla.

Qué depende de la física: `clock` del cerebro suma `delta` de física (`lurker_brain.gd:276`); los tiempos del aviso (plazo, `due`) son de ese reloj (`lurker_warning.gd:61`). Los sentidos hacen raycasts y `cast_motion` (`lurker_senses.gd:184-192`; `lurker.gd:244-262`; `lurker_visual.gd:375`).

Señales: `cue_started`, `cue_ended`, `scared`, `took` (brain, `:74-77`); `footfall` (visual, `lurker_visual.gd:16`; limbs, `lurker_limbs.gd:23`); `arrived`, `tile_turned`, `blocked` (motion, `lurker_motion.gd:86-91`); `swung` y `settled` de cada puerta (routes `:153-156`, `:218-225`); `cue_played` (lurker.gd `:35`).

---

## 15. Clases y nodos de Godot que usa esta parte

Conteo de apariciones (aproximado) en `game/enemies/lurker/*.gd` y `*.gdshader`, más las dos escenas. Es lo que habría que sustituir:

| Clase o API | Apariciones | Dónde se usa (ejemplo) |
|---|---|---|
| `Dictionary`, `Array`, `PackedVector3Array`, `PackedInt32Array`, `PackedFloat32Array`, `PackedStringArray` | 227 / 165 / 18 / 18 / 7 | Datos de todo el sistema (planos, rutas, percepciones, paquetes de red). |
| `Basis`, `Transform3D`, `Quaternion`, `Rect2`, `Vector3` | 46 / 28 / 14 / 30 | Transformadas de la cáscara, del cuerpo y de los huesos. |
| `RefCounted` | 13 | Mente, sentidos, aviso, motor, rutas, cáscara, polvo (clases sin nodo). |
| `Node3D` / `Node` | 17 / 5 | Cuerpo visual, nodos de humo y decals. |
| `CharacterBody3D` | 1 (tscn) | Cuerpo (`lurker_creature.tscn`). |
| `Skeleton3D`, `SkeletonModifier3D` | 6 / 2 | IK de manos y cabeza (`lurker_limbs.gd`). |
| `AnimationPlayer` | 3 | Reproducción de los 8 clips (`lurker_visual.gd:31-32`, `:190`, `:245`). |
| `MeshInstance3D` | 5 | Tinta y vapor sobre `SphereMesh`. |
| `ShaderMaterial` | 6 | Tinta, vapor, polvo, velo. |
| `Decal` | 4 | Manchas de la cara y de las manos (`lurker_visual.gd:165`, `:174`). Según el propio código no se dibujan en el renderer de compatibilidad (`lurker_visual.gd:93-94`, en comentario). |
| `FogVolume`, `RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID` | 2 / 1 | Velo de polvo con niebla volumétrica (`ceiling_dust.gd:181-183`). Solo se crea si `volumetric_fog_enabled` (`:145-146`). |
| `Shader` tipo `fog` | 1 | `ceiling_dust_veil.gdshader` (`shader_type fog`). |
| `GPUParticles3D`, `ParticleProcessMaterial` | 3 / 11 | Hilos, escamas, trozos, manchas (`ceiling_dust.gd:100-140`, `:236-267`, `:271-322`). |
| `GPUParticlesCollisionBox3D` | 1 | Suelo de los trozos (`ceiling_dust.gd:317`). |
| `CurveTexture`, `CurveXYZTexture`, `Curve` | 2 / 1 / 1 | Curvas de vida de las partículas (`ceiling_dust.gd:324-329`). |
| `ImageTexture`, `Image` | 7 / 4 | Manchas y formas de polvo generadas en código (`ceiling_dust.gd:378-404`; `lurker_visual.gd:193-205`). |
| `NoiseTexture3D`, `FastNoiseLite` | 2 / 2 | Ruido 3D del velo (`ceiling_dust.gd:162-171`). |
| `SphereMesh`, `QuadMesh`, `BoxMesh` | 1 / 1 / 1 | Volúmenes de la tinta, partículas en plano, trozos. |
| `StandardMaterial3D` | 1 (+3 .tres) | Material de trozos (`ceiling_dust.gd:305`) y los tres `.tres` de la carpeta de assets. |
| `AudioStreamPlayer3D` | 3 | Voz de la criatura (`lurker_voice.gd:326-339`). |
| `PhysicsRayQueryParameters3D`, `PhysicsShapeQueryParameters3D`, `PhysicsDirectSpaceState3D` | 7 / 3 / 7 | Sondas de suelo, de pared y de codos (`lurker_limbs.gd:340-586`; `lurker_senses.gd:184-192`; `lurker.gd:244-262`). |
| `SphereShape3D`, `CollisionShape3D`, `CollisionObject3D` | 4 / 1 / 1 | Esfera de 0.3 m para los supervivientes delante (`lurker.gd:253-254`) y bola del codo (`lurker_limbs.gd:161`, `:571-576`). |
| `RandomNumberGenerator` | 9 | Azar de la mente, la voz, el motor y el polvo (sección 14). |
| `Tween` | 10 | Velos, polvo, decals (sección 14). |
| `Time`, `Engine` | 9 / 7 | Reloj de pared (`Time.get_ticks_msec`) y contadores de fotogramas. |
| `Callable`, `Signal` | 5 / varias | Vigilantes del motor (`motion.clearance`, `bodies_ahead`, `busy`, `left_behind`) y conexiones de señales. |
| `Geometry2D`, `Callable`, `Resource` | 1 / 5 / 2 | Punto más cercano y perfiles (`lurker_shell.gd`); recurso de sonido de presencia (`lurker.gd:37`). |
| `Camera3D`, `Viewport` | 1 / 2 | Cámara que mira la criatura (`lurker_visual.gd:309-310`). |

Otros nodos del mundo a los que habla por duck typing (no leídos): `level.hotel` (`lit`, `drain`, `drain_emergency`, `drained`, `turn_tile`, `LIT_DRAIN`, nodos `Door_a_b` con `swung`, `settled`, `opened`, `moving`, `locked`, `leaf_line`), `level.world_audio` (`duck_under`, `route_source`, `apply_route`, `play_cue`, `show_caption`, `ACOUSTIC_MASK`, `DUCT_BUS`, `ensure_duct_bus`, `listener_position`, `duck_db`, `mask_db`), `level.survivors()`, `level.survivor_active()`, `level.point_protected()`, `level.off_limits_rooms()`, `level.objective(&"air"|&"power")`, `level.match_net` (`send_cue`, `send_cue_over`, `creature_event`, `world_sound`, `in_charge`), `level.executions`, `level.lifts`, `level.perf`, `level.session`.

---

## 16. Pruebas que vigilan esta parte

Nombres y tamaños (líneas), sin leer sus aserciones:
- `tests/office/lurker_fairness_test.gd` (718): el aviso y su justicia (200 acercamientos sorteados contra un oráculo, según `docs/LURKER.md:107`).
- `tests/office/lurker_shell_test.gd` (947): la cáscara.
- `tests/office/lurker_senses_test.gd` (525): sentidos.
- `tests/office/lurker_motion_test.gd` (329): el motor.
- `tests/office/lurker_tiles_test.gd` (216): baldosas y plenum.
- `tests/office/lurker_bots_test.gd` (181): los bots contra ella.
- `tests/office/lurker_observer_test.gd` (161): observador y red.
- `tests/office/lurker_capture_test.gd` (129): captura.
- `tests/office/lurker_forced_test.gd` (136): capturas forzadas.
- `tests/office/lurker_mood_audio_test.gd` (70): compases y música.
- `tests/office/lurker_fixture.gd` (104): ayudante del piso de prueba.
- `tests/office/office_audio_test.gd` (416) y `tests/office/office_lies_test.gd` (349): sonido de la criatura y las mentiras.
- `tests/office/office_test.gd` y `tests/office/conduit_graph_test.gd`: mencionan a la criatura.
- `tests/hotel/creature_contract_test.gd` (2079): contrato de criatura; el piso 1 no debe cambiar (`spec_lurker_rebuild.md:7-12` y la regla de `CLAUDE.md`).
- `tests/hotel/difficulty_test.gd`, `tests/hotel/palette_scan_test.gd`, `tests/hotel/rules_test.gd`: mencionan a la criatura.
- Sondas de `tools/dev/`: `lurker_elbow_probe.gd` (157, en `verify` según el documento), `lurker_depth_probe.gd` (102), `lurker_route_probe.gd` (459), `lurker_telemetry.gd` (468, revisión de cada iteración).
- Capturas de `tools/capture/`: `lurker_capture.gd`, `lurker_office_look.gd`, `lurker_test_check.gd`, `lurker_hand_check.gd`, `lurker_materials_probe.gd`.
- Espacios de trabajo: `tools/workbenches/lurker_test.gd` (398 líneas) y `lurker_arena.gd` (81), con sus escenas `.tscn`.

---

## 17. Discrepancias y cosas que conviene saber

1. Subtítulo de presencia: `docs/LURKER.md:100` dice que la presencia lleva el subtítulo «[Algo respira encima]» (propuesta del autor). No aparece en ningún `.gd` de `game/` ni de `tools/`. Sí existen «[Algo respira a tu espalda]», «[Algo respira cerca]» y «[Algo respira sobre ti]» (`lurker_warning.gd:34-37`).
2. Ruido de la tinta: `tools/art/lurker/bake_ink_noise.gd:13` escribe `assets/enemies/lurker/ink_noise.res`, que no existe en el repo. `lurker_darkness.gdshader` no declara ninguna textura de ruido: el ruido se calcula en el propio shader (`:43-57`, `:71-72`). El script no alimenta el sombreador actual.
3. Brazos en la cabecera de `anatomy.py`: el texto dice «the eight arms» en la cabecera, pero `LIMB_SPECS` (`anatomy.py:48-55`) y el comentario de `anatomy.py:40-47` dicen siete. El juego usa siete (`lurker_limbs.gd:26`).
4. Alcance del brazo: `docs/LURKER.md:40` dice 86 % para el solver de animación (`animate.py:432`, correcto) y `docs/LURKER.md:59` dice 88 % para el juego (`lurker_limbs.gd:51`, correcto). No es un error; conviene no mezclarlos.
5. `CHASE_EARSHOT` está declarada en `lurker_brain.gd:504` y no se usa en el propio cerebro; sí se usa en `hotel_locust.gd` y en las pruebas.
6. `TAKE_EMPTY` (`lurker_brain.gd:51`) solo lo lee el cerebro (`:913`).
7. El documento dice que la criatura tiene 142 huesos y 86 132 triángulos (`docs/LURKER.md:33`, `:35`). No lo he comprobado en el GLB.
8. Hay dos vigilantes de progreso, como describe el spec (`spec_lurker_rebuild.md:24` y `:88`): uno en la mente (`STALL_TIME` 6 s y `STALL_MOVE` 0.5 m, `lurker_brain.gd:106-107`) y otro en el motor (`PROGRESS_TIME` 1.5 s y `PROGRESS_METRES` 0.1 m, `lurker_motion.gd:66-67`).
9. La voz usa el reloj de pared (`lurker_voice.gd:102`) para la ventana de silencio del aviso, y `lurker.gd:434` para la memoria de rutas. El resto de la criatura usa el reloj de física. Si el port quiere reproducibilidad, estas dos son las que no lo son.
10. El polvo usa el rng global sin semilla en `ceiling_dust.gd:88` y `:90`.

---

## 18. Sin comprobar

- No leí a fondo: `game/enemies/creature.gd` (contrato base), `creature_sight.gd`, `conduit_graph.gd`, `floor_definition.gd`, `office_palette.gd`, `office_layout.gd`, `conduit_metres.gd`, `session_perf.gd`, `world_audio.gd` (solo las líneas de buses), `hotel_geometry.gd` (solo `LIT_DRAIN`), el hotel (nodos `Door_a_b`, `lit`, `drain`, `turn_tile`), `difficulty.gd` (las tablas por dificultad: los valores por defecto del código son los de Equilibrada según `lurker_brain.gd:137`), `pacing_director.gd`, `match_net`, `lurker_capture.gd` (284 líneas), `lurker_score.gd` (135), `lurker_hallucinations.gd` (631), `tools/bots/*`, `tools/dev/*`, `tools/capture/*`.
- Tests: solo leí nombres y tamaños. No sé si `verify.ps1` los ejecuta todos ni qué afirman en detalle.
- `tools/art/lurker/`: leí las cabeceras de todos los `.py` y la parte de `build.py`, `make.py` y `animate.py` que dice la cadena de exportación. No leí el cuerpo de `sdf.py`, `anatomy.py` ni `animate.py` línea a línea, ni `scene.py`, `preview.py`, `beauty.py`, `grade.py`, `compare.py`, `poses.py` por dentro.
- El `.blend` (`art/lurker/lurker.blend`) no está comprobado; tampoco que la versión de Blender sea 5.2 (la afirma `docs/ASSETS.md:441`).
- El GLB: no abrí su contenido. Sé su tamaño (5 527 156 bytes) y los ajustes de importación del `.import`, no el número de huesos, de triángulos ni de clips.
- Rendimiento: no medí el coste de la tinta (10 pasos con ruido), del IK (2 sondas por fotograma; en el peor caso, `_clear_elbow` prueba 26 ángulos con hasta 3 consultas cada uno, por brazo y fotograma, `lurker_limbs.gd:544-566`) ni del polvo.
- Comportamiento de los renderers (Forward+ y compatibilidad): lo tomo de los comentarios y de las ramas del código; no lo he probado.
- Lore, fechas y decisiones del autor: las tomo de `docs/LURKER.md` y del spec; no las he cruzado con `LORE.md` ni `OFICINAS.md` (no leídos).
- No he comprobado el orden exacto de los `tween`s de los velos en la práctica ni la duración real de las partículas.
