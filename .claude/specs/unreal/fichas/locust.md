# Ficha de hechos: The Locust (`locust`)

Fecha: 14 de noviembre de 2026. Repo: `E:\Projects\The Four`, rama main. Solo lectura: no se ha tocado código, git ni ningún otro archivo.

Esta ficha describe lo que hay en el código, no propone diseño de Unreal. Las rutas van relativas a la raíz del repo. Cada cifra va como `archivo:línea`, con la línea tal como estaba al leer. Lo que no se ha leído o comprobado está en el apartado final «Sin comprobar».

Convención: "entero" significa que el archivo se leyó completo.

---

## 1. Inventario de archivos

### 1.1 Leídos enteros

| Archivo | Líneas | Qué hace |
|---|---|---|
| game/enemies/creature.gd | 418 | Contrato base de toda criatura (CharacterBody3D). 81 funciones; los valores por defecto dicen "nada". Define las listas de modos y los predicados que las usan. |
| game/enemies/creature_sight.gd | 170 | Vista compartida, sin estado: quién tiene a quién en vista (`watched`, `regards`, `torch_covers`), la cara a la vista, y estar detrás o encima. The Locust lo usa solo en `watched()`. |
| game/enemies/null_creature.gd | 77 | Criatura nula (piso 2 hasta que exista la del Lurker): responde el contrato y no hace nada. |
| game/enemies/locust/hotel_locust.gd | 2487 | El cerebro de The Locust: máquina de estados, sentidos, oído, rutas, sonidos, captura, acecho, director, red y observador. 137 funciones. |
| game/enemies/locust/echo_view.gd | 1153 | Vista de eco del cazador humano: clics, rayos, granos en el mundo, nubes de sonido, guías, chillido. 38 funciones. |
| game/enemies/locust/locust_player.gd | 491 | Control del cazador humano en versus: movimiento, resistencia, golpe, chillido, rastro (Q), puertas, televisores. |
| game/enemies/locust/locust_visual.gd | 406 | Animación procedural del esqueleto (pies con IK, brazos, cabeza, pose de captura). Solo presentación. |
| game/enemies/locust/echo_body.gd | 108 | Puntos de eco sobre la superficie de un superviviente: mangas por hueso o cápsula, solo la mitad que mira al oyente. |
| game/enemies/locust/door_threading.gd | 187 | Reescribe la ruta para cruzar puertas por el hueco y rodear las hojas abiertas. Solo para moverse. |
| game/enemies/locust/locust_poser.gd | 107 | Poses por hueso para escenas de presentación (televisor de apertura, menú). No es jugabilidad. |
| game/enemies/locust/locust_look.gd | 13 | Cambia el material del cuerpo por el de referencia (negro tinta, máscara pálida). |
| game/enemies/locust/locust.tscn | 34 | Escena: CharacterBody3D, cápsula de colisión, modelo importado, dos AudioStreamPlayer3D. |
| game/enemies/locust/shaders/echo_field.gdshader | 126 | Fondo negro de la vista de eco, grano del propio oído y haz de linterna. |
| game/enemies/locust/shaders/echo_points.gdshader | 135 | Granos en el mundo, uno por cada nube: onda, memoria, prueba de profundidad blanda, halo. |
| game/enemies/locust/shaders/echo_self.gdshader | 25 | Su propio cuerpo en la vista: aditivo, borde (fresnel) y franjas. |
| docs/VISION_LOCUST.md | 175 | Diseño de la vista de eco, lo implementado y lo que queda a juicio humano. |

### 1.2 Leídos en parte (dependencias, no son la ficha)

- game/world/generation/floor_definition.gd: líneas 47, 54-59, 78, 158, 310-320 (`planta_of`, `floor_point`, `closest`, `room_at`, `route_metres`, `navigation_path`).
- game/audio/noise_kinds.gd: líneas 1-44 (enum `Kind`, `SPREAD`, `HEARING_SCALE`, tabla `HEARD`).
- game/presentation/graphics_presets.gd: líneas 20-27 y 168-237 (presets y bloque `echo`).
- Pruebas y herramientas: solo nombres de funciones y recuento de referencias (grep).

### 1.3 Recuento de funciones y constantes (grep)

| Archivo | func | const |
|---|---|---|
| creature.gd | 81 | 9 |
| creature_sight.gd | 15 | 14 |
| null_creature.gd | 11 | 2 |
| hotel_locust.gd | 137 | 101 |
| echo_view.gd | 38 | 85 |
| locust_player.gd | 25 | 22 |
| locust_visual.gd | 19 | 7 |
| echo_body.gd | 4 | 4 |
| door_threading.gd | 11 | 11 |
| locust_poser.gd | 12 | 2 |
| locust_look.gd | 1 | 1 |

hotel_locust.gd tiene 3 señales: `area_abandoned` (1105), `route_abandoned` (1934), `stuck_escalated` (1998). locust_visual.gd tiene 1: `footfall` (8). creature.gd no tiene señales.

---

## 2. Contrato común (creature.gd)

### 2.1 Base y estado

- `extends CharacterBody3D` (creature.gd:1). Lo extienden hotel_locust.gd:1 y null_creature.gd:1.
- Quién decide (`control`): `"ai"` por defecto (creature.gd:50); `"puppet"` sigue el estado de la máquina que manda; `"player"` lo maneja un jugador (creature.gd:47-49).
- `grace := 15.0` (creature.gd:54): segundos antes de empezar. Se da al crear el piso (`difficulty`) y al devolver una etapa.
- `dull := 1.0` (creature.gd:58): cuánto de su oído tiene en ese momento (0 a 1). Lo baja el director.
- `rng := RandomNumberGenerator.new()` (creature.gd:63): sus propios sorteos, sembrados por la criatura.
- `WORLD_AUDIO` precargado (creature.gd:23).

### 2.2 Listas de modos (creature.gd:26-43)

| Constante | Línea | Valores |
|---|---|---|
| HOSTILE | 26 | alert, chase, strike, recover, capture, wait, stalk |
| ATTACKING | 28 | alert, chase, strike, recover, capture |
| HUNTING | 30 | chase, strike, recover, alert |
| CHASING | 32 | chase, strike, recover |
| ENGAGED | 35 | strike, recover, capture, open, wait |
| ROAMING | 38 | roam, search, investigate |
| LEADABLE | 40 | roam, search |
| WARY | 43 | investigate, search |

Predicados (creature.gd:102-109): `is_hostile`, `is_attacking`, `is_hunting`, `is_chasing`, `is_engaged`, `is_roaming`, `accepts_leads`, `is_wary` son `activity() in <lista>`. `alarm_level()` (113-115): 2 si caza, 1 si busca, 0 en el resto.

`activity()` por defecto es `&"roam"` (creature.gd:97). The Locust lo sobrescribe con `ACTIVITY` (hotel_locust.gd:2160).

### 2.3 Funciones del contrato (creature.gd)

- Identidad y control: `kind_id` 66, `can` 71, `set_control` 74, `tune` 77, `activity` 97, `mode_name` 100.
- Sentidos: `eye_point` 120 (origen + 1,7 m arriba), `face_point` 123, `gaze` 126, `sees` 128, `hear` 131, `hear_route` 134, `watched` 138, `quarry` 142, `saw_enter` 148.
- Director: `lead_to` 154, `investigate` 157, `travel_metres` 160, `in_transit` 163, `transit_phase` 167, `searched_lately` 171, `noticing` 175, `forced_after` 180, `earned_rest` 184.
- Movimiento: `teleport` 197, `forget_journey` 205, `relocate` 213, `search_from` 220, `follow_to_planta` 226, `den_point` 231, `start_room` 235, `place_at` 238, `arm` 242.
- Ajenos a la criatura: `presence_sound` 245, `hunter_camera` 248, `blackout` 251, `save_state` 255, `restore_state` 259.
- Red: `pack_state` 264, `push_state` 267, `play_call` 270, `on_event` 274, `resume_state` 279, `validate_strike` 285.
- Versus: `sense_scale` 292, `hunter_reveal` 295, `hunter_contact` 299, `hunter_gone` 304, `apply_quality` 308.
- Captura: `capture_style` 318, `begin_capture` 322, `end_capture` 327, `capture_length` 330, `turn_for_capture` 334, `may_capture` 340, `cue_of` 344, `capture_log` 348, `play_cue` 352, `cue_over` 356, `wardrobe_steps` 360.
- Sonido y mente: `hushed` 365, `mood` 370, `presence_route` 374, `sound_route` 379, `voice_point` 382, `presence_on` 385, `hallucinations` 393.
- Observador: `tally` 399, `capture_records` 403, `debug_lines` 407, `debug_state` 412, `draw_gizmos` 418.

### 2.4 Qué sobrescribe The Locust (hotel_locust.gd)

Sobrescribe: `kind_id` 2166, `can` 2168, `activity` 2170, `mode_name` 2174, `eye_point` 2177, `gaze` 2181, `sees` 649, `hear` 771, `hear_route` 730, `watched` 2154, `quarry` 2193, `saw_enter` 1282, `lead_to` 809, `investigate` 918, `travel_metres` 2185, `in_transit` 2187, `searched_lately` 2189, `noticing` 2191, `presence_route` 2197, `sound_route` 2202, `hallucinations` 2209, `capture_style` 2215, `begin_capture` 2219, `end_capture` 2225, `capture_length` 2228, `resume_state` 2235, `validate_strike` 2245, `sense_scale` 2260, `hunter_reveal` 2262, `hunter_contact` 2265, `hunter_gone` 2270, `apply_quality` 2275, `debug_lines` 2290, `debug_state` 2315, `draw_gizmos` 2321, `forget_journey` 2367, `search_from` 2383, `follow_to_planta` 2394, `den_point` 2455, `start_room` 2474, `place_at` 2476, `arm` 2478, `presence_sound` 2482, `hunter_camera` 2484, `blackout` 2486, `save_state` 2466, `restore_state` 2468, `relocate` 865, `set_control` 1213, `tune` 76, `pack_state` 1227, `push_state` 1235, `play_call` 1536, `hushed` 1375, `wardrobe_steps` 171.

No sobrescribe (queda el valor de creature.gd): `teleport`, `forced_after` (0,0), `earned_rest` (true), `may_capture` (true), `cue_of` (-1), `capture_log`, `cue_of`, `cue_over`, `play_cue`, `on_event`, `tally`, `capture_records`, `mood`, `presence_on`, `voice_point`, `transit_phase`, `turn_for_capture`, y todos los `is_*` y `alarm_level` (estos salen de `activity()`).

Habilidades (`can`, hotel_locust.gd:2164): `lifts`, `tv_travel`, `wardrobes`, `shriek`, `echo`. No tiene `ducts`.

---

## 3. Máquina de estados (hotel_locust.gd)

### 3.1 Modos

`enum Mode { PATROL, INVESTIGATE, CHASE, SEARCH, WINDUP, RECOVER, ALERT, WARDROBE, EXECUTE, LURK }` (línea 6), en ese orden de valor (0 a 9). El nombre en el observador (`MODE_WORDS`, 2282): patrulla, investiga, persigue, busca, prepara, se repone, alerta, armario, ejecuta, acecha.

| Modo | activity() (2160) | Qué hace | Entra desde | Sale a |
|---|---|---|---|---|
| PATROL | roam | Rondas: elige sala a 20-60 m de paseo, se para 1,0-2,5 s al llegar | arranque, `relocate`, `give_up_area`, `tire`, fin de `WARDROBE`, `EXECUTE` (control "player") | ALERT, INVESTIGATE |
| INVESTIGATE | investigate | Va al punto oído o visto | `hear`, `investigate`, `aim_at_lift`, detección ≥ 0,2 | SEARCH (llega o pasan 12 s), CHASE (escondite sospechoso), ALERT |
| SEARCH | search | Recorre hasta 4 puntos del plan y abre armarios | CHASE al perder, INVESTIGATE, WARDROBE, EXECUTE, `hunter_gone` | PATROL (`give_up_area`), INVESTIGATE (pista) |
| ALERT | alert | Se gira y chilla un aviso (`grunt`), 1,2 s | detección ≥ 1,0 | CHASE tras 1,2 s |
| CHASE | chase | Persigue | ALERT, LURK (sale del armario) | SEARCH (sin ver 7 s), tire (cansancio), `seize` |
| WINDUP | strike | Carga del golpe (solo versus; la IA pasa a CHASE, hotel_locust.gd:1703-1705) | `locust_player.strike` | RECOVER |
| RECOVER | recover | Parado tras el golpe, 0,6 s | `seize`, WINDUP | CHASE si ve a alguien, si no SEARCH |
| WARDROBE | open | Frente al armario, abriendo sus hojas | `begin_wardrobe` | SEARCH (IA) o PATROL (no IA) |
| EXECUTE | capture | Sostiene a la víctima | `begin_execution`, `begin_capture` | SEARCH (IA) o PATROL (versus), tras 5,05 s |
| LURK | wait | Espera junto a un armario (feint) | `begin_lurk` | ALERT, CHASE, SEARCH (`give_up_area`) |

Al cambiar de modo con `set_mode` (925-956): cualquier modo distinto de PATROL borra `lead` (931); volver a PATROL borra `observed_hide` (937); salir de LURK borra `lurk` (939-940); entrar a CHASE desde algo que no es CHASE, WINDUP ni RECOVER pone `chase_time` a 0 (943); entrar a CHASE desde otro modo fija `speed = max(speed, chase_start)` (946); SEARCH llama a `begin_search` (951); ALERT llama a `grunt()` (953); WINDUP llama a `warn()` y envía `creature_call("warning")` (954-956).

### 3.2 Transiciones de la IA (`_physics_process`, 1563-1742)

Orden dentro de un paso de física, para la IA (control "ai"):

1. `count_grace` (1576); si `grace > 0` solo se actualiza el visual y se sale (1580-1582).
2. `mark_rooms` cada 0,5 s (1583, 1017-1030).
3. `noticed_survivor` (1584) y detección (1585-1608).
4. Doubt (1598-1599, 1614-1615).
5. Cansancio de la caza (1616-1620).
6. ALERT desde detección ≥ 1,0 (1625-1626); INVESTIGATE desde detección ≥ 0,2 en PATROL o SEARCH (1627-1630).
7. Antorcha (1632-1641).
8. Ruta, según el modo (1645-1712).
9. Movimiento: `update_wardrobe`, `update_execution`, ALERT, RECOVER, LURK o `move_on_path` (1717-1741).

Umbrales y tiempos:

- Detección: sube con `delta * notice_rate(seen)`, con tope 1,5 (1597). Baja con `NOTICE_DECAY` 0,12 por segundo cuando no hay vista (1606). Tope 0,2 (`SUSPICION`) para INVESTIGATE (180, 1627). Tope 1,0 para ALERT (1625).
- `notice_rate` (694-700): `lerpf(NOTICE_NEAR 3,2, NOTICE_FAR 0,9, t)` con `t = clamp((d - 4) / (sight_range * reach_scale - 4), 0, 1)`, multiplicado por `notice`. Agachado ×0,55 (697). Velocidad horizontal > 4,6 ×1,35 (698). Antorcha encendida ×1,4 (699).
- Duda (`DOUBT_FROM` 0,05 en 53; `DOUBT_CAP` 0,95 en 54; `DOUBT_REST` 6,0 en 55): cuando la detección cruza 0,05 en PATROL, SEARCH o INVESTIGATE y ha pasado `doubt_rest`, se para `doubt_time` segundos y gruñe un chitter (1130-1137). Mientras duda la detección no pasa de 0,95 (1599).
- Cansancio (`TIRED_FOR` 3,0 en 64, `tired_for` por perfil): si `chase_time >= chase_tire` (perfil, 0 = nunca), `tire()` (1146-1150): `tired_until = clock + tired_for`, detección 0, sin foco, y `give_up_area` (que deja PATROL).
- Vuelve a no atender a nadie mientras `clock < tired_until`: la detección se capa a `SUSPICION * 0,9` (1610).
- Pérdida de la caza: `lost_time > lose_after` (LOSE_AFTER 7,0 en 187) lleva a SEARCH (1687).
- Ataque (IA): `can_attack()` (1171-1176) = jugador a menos de `attack_range` (ATTACK_RANGE 2,4 en 249), línea de vista desde `camera`, y no oculto o detrás de un armario abierto. Entonces `seize()` (1181-1184): `level.capture_survivor(target())` y RECOVER (si no está en EXECUTE).
- ALERT → CHASE a los `alert_time` (ALERT_TIME 1,2 en 236; `tune` lo cambia).
- LURK: entra por `feints(player)` (1326-1330): la IA lo elige con probabilidad `feint` (perfil; 0 por defecto en 46) si certifica quién entró (`certain`) y nadie más la ve.

### 3.3 Velocidades (`desired_speed`, 1191-1211)

| Modo | Velocidad (m/s) | Línea |
|---|---|---|
| PATROL | 1,9 + sin(reloj·0,37)·0,5 + sin(reloj·1,13)·0,2; 0 si pausa; LEAVE_PACE 2,6 si se va | 1196-1197 |
| INVESTIGATE | lerp(1,2; 2,9; min(1, (distancia-1,5)/5)); LIFT_PACE 4,0 si `lift_bound` | 1200 |
| CHASE | chase_speed (6,4 por defecto, CHASE_SPEED 227) si `lost_time < 0,4` o `relentless`; si no, track_speed (5,2, TRACK_SPEED 229) | 1202 |
| SEARCH | 0 si pausa; si no 1,5 | 1204 |
| LURK | aside 1,9; pounce chase_speed; resto 0 | 1208-1209 |
| doubting | 0 | 1193 |

Aceleración en `move_on_path` (1886-1887): POUNCE_ACCELERATION 10,0 (1316) en acecho, `chase_accel` 3,2 (239) en CHASE, 3,5 en el resto. Frenado 9,0. Giro: `lerpf(0,35; 1,0; ...)` según el ángulo (1884); velocidad de giro POUNCE_TURN 12 (1317), 8 en CHASE, 4,5 en el resto (1892).

### 3.4 Cifras de decisión (resumen)

| Constante | Valor | Línea |
|---|---|---|
| SIGHT_RANGE | 70 m | 10 |
| ONSLAUGHT_REACH (rango de vista y oído con onslaught) | 1,25 | 13 |
| SIGHT_HALF_ANGLE | 60° a cada lado | 174 |
| NOTICE_NEAR / NOTICE_FAR / NOTICE_DECAY | 3,2 / 0,9 / 0,12 por s | 176-178 |
| SUSPICION | 0,2 | 180 |
| TORCH_NOTICE_RANGE / TORCH_NOTICE_ANGLE | 45 m / 32° | 240, 244 |
| ALERT_TIME | 1,2 s | 236 |
| CHASE_START_SPEED / CHASE_ACCELERATION | 2,5 / 3,2 | 238-239 |
| CHASE_SPEED / TRACK_SPEED | 6,4 / 5,2 m/s | 227, 229 |
| LOSE_AFTER | 7,0 s sin ver | 187 |
| GIVE_UP / GIVE_UP_HARD | 8 s / 10 s sin pistas | 211-212 |
| SEARCHED_RADIUS / SEARCHED_FOR | 18 m / 75 s | 213-214 |
| LEAVE_MIN / LEAVE_PACE | 38 m / 2,6 m/s | 215-216 |
| SEARCH_PEEK_CHANCE | 0,2 | 218 |
| AREA_CAP / AREA_SAME / LOUD | 40 s / 15 m / 30 m | 223-225 |
| PATROL_NEAR / PATROL_FAR | 20 m / 60 m de paseo | 195-196 |
| STALE_FULL | 150 s | 197 |
| DEAD_END_PEEK | 0,35 | 198 |
| RECENT_ROOMS | 6 | 199 |
| SCAN_TIME | 1,0-2,5 s | 201 |
| DOUBT_FROM / DOUBT_CAP / DOUBT_REST | 0,05 / 0,95 / 6 s | 53-55 |
| TIRED_FOR | 3,0 s | 64 |
| LIFT_PACE | 4,0 m/s | 233 |
| APPARENT_NEAREST | 3,5 m | 185 |
| CHASE_EARSHOT | 9,0 m | 770 |

---

## 4. Sentidos: vista y oído

### 4.1 Vista de la criatura (hotel_locust.gd)

`seen_survivor()` (664-674) devuelve el foco si lo ve, o el más cercano que vea. `sees(player)` (649-660) cumple, en orden:

1. Superviviente activo (`level.survivor_active`, 650).
2. Distancia ≤ `sight_range * reach_scale` (652).
3. Si está escondido y `observed_hide == player.hiding_place`: visto, sin más (654). La criatura sabe en qué armario entró, con las puertas cerradas.
4. Cono: si la distancia es mayor de 1,5 m, `facing · dir ≥ cos(sight_half_angle)` (655-656). `facing = -global_basis.z`.
5. Línea de vista: `clear_sight(camera.global_position)` (657, 644-646): rayo desde `global_position + (0, 2,4, 0)` a la cámara, máscara `1 | 8 | 64` (paredes, puertas, armarios).
6. Si está escondido: solo si `hiding_place.ajar()` (659).

`shown(player)` (124-135): fracción de cuerpo a la vista, de 0 a 1, con 1 de los ojos y 6 de `BODY_POINTS` (120), siete rayos en total.

`overlooks` (139-146) y `noticed_survivor` (150-168): ocultación parcial. Solo aplica si `cover > 0` (perfil). Con menos de `cover` del cuerpo visible, el superviviente se queda sin notar hasta `glimpse` segundos (perfil).

`notice_rate` (694-700) y la detección (1597-1606): ver sección 3.2.

`lit_by_torch()` (703-714): un superviviente con antorcha encendida, no escondido, a entre 5 m y `torch_range * reach_scale` (45 m), dentro de 0,85·32° del eje, y con un rayo libre desde la antorcha al pecho (`global_position + (0, 1,6, 0)`), máscara 1|8|64. Si la luz le llega más de 0,35 s (`light_exposure`, 1633-1641), va a investigar ese punto.

`watched(point)` (2154-2155): `SHARED_SIGHT.watched(level, point + (0; 1,2; 0), [rid], SIGHT_RANGE, 0,35)`. Lo usa `hop()` para no saltar a la vista de nadie (2133).

### 4.2 Oído de la criatura

`hear(point, radius)` (771-802) solo actúa si `control == "ai"` (772). Se ignora si hay gracia, si está en WINDUP, RECOVER, EXECUTE, WARDROBE o LURK (775), si está cansada (`clock < tired_until`, 778), o si `can_hear()` es falso (779). Además, si es una zona ya dada (`area_spent > AREA_CAP` y el punto está a menos de `AREA_SAME` del origen de búsqueda y el ruido es menor que `LOUD`), se ignora (781).

Cuando oye: `clue()` (782, reinicia `clue_idle`); si caza, un ruido a menos de 9 m de `last_known` (`CHASE_EARSHOT`) actualiza el último punto conocido (790-792); si está en ALERT solo cambia `last_known` (794-799); si no, va a investigar (800-802).

`hear_route(point, radius)` (730-766) es la única medida del oído. Devuelve `{audible, apparent, distance, muffle}`:

1. `level.point_protected(point)` → no oye (732).
2. Alcance `reach = radius * HEARING_SCALE * hearing * reach_scale * dull` (733). `HEARING_SCALE` = 2,6 (noise_kinds.gd:25).
3. Distancia en línea recta > alcance → no oye (734-735).
4. Si hay línea de vista a `point + (0,1,0)` (736): oye directo, `muffle = 0`.
5. Si no, camino por `FLOOR.navigation_path(map, position, point)` (738). Si el camino no llega a menos de 1,5 m del punto (744-746) o su longitud supera el alcance (749), no oye.
6. `apparent`: el último punto de la ruta que aún se ve, a 1,5 m de altura (752-758). Si queda a menos de `APPARENT_NEAREST` 3,5 m del inicio, se recoloca a 3,5 m en la dirección de la primera curva (760-764).
7. `muffle = clamp((longitud - distancia_a_apparent) / 25, 0, 1)` (765-766).

Radios por tipo de ruido (game/audio/noise_kinds.gd, tabla `HEARD`, líneas 28-41). Son el alcance en metros para la IA con `hearing = 1`, porque `radius(noise) = HEARD / HEARING_SCALE` y `hear_route` vuelve a multiplicar por 2,6:

| Tipo | Alcance (m) | Tipo | Alcance (m) |
|---|---|---|---|
| peek | 10,5 | walk | 20 |
| crouch | 8 | walk_hard | 25 |
| crouch_hard | 12 | jump | 32 |
| door_slow | 9 | door | 45 |
| wardrobe | 12 | wardrobe_hunter | 45 |
| wardrobe_slow | 12 × 0,75 (QUIET) | slam | 62 |
| run | 52 | run_hard | 64 |

Para el cazador humano, `hear()` no se usa: el cazador recibe contactos por `hunter_contact` → `driver.hear_contact` (locust_player.gd:467-476).

### 4.3 Vista compartida de los supervivientes (creature_sight.gd)

Sin estado, solo estáticas. Lo que importa para el port:

- `MASK = 1 | 8 | 64` (12): paredes, puertas, escondites. Los cuerpos (capa 4) nunca bloquean.
- `watched(level, target, exclude, reach = 70, dot = 0,35)` (70-79).
- `regards(level, body, face, exclude, lit_face)` (99-100) y `look_of` (103-116): el superviviente mira la cara con `REGARD_LOCAL` 30° (16), `REGARD_REMOTE` 45° para un puppet (17), alcance `REGARD_REACH` 30 m (19), rayo libre, y la cara iluminada, con antorcha (`TORCH_FACE_ANGLE` 20°, `TORCH_REACH` 20 m, 26-27) o a menos de `DARK_FACE` 1,2 m (22).
- `beside(eye, forward, point, band)` (148-150): banda de (0,45; 0,85) del producto escalar (32).
- `rear_of` (160-165): detrás, con `REAR_DOT` -0,26 (35); `over_of` (167-170): por encima, `OVER_SIN` 0,77 (36) y `OVER_LOOK` 0,5 (37).

---

## 5. Movimiento y rutas

### 5.1 Cuerpo y colisión (locust.tscn)

- Raíz: CharacterBody3D (`locust.tscn:8`), `collision_layer = 32` (9), `collision_mask = 9` (16): paredes y muebles (capa 1) y hojas de puerta cerradas (capa 8).
- Forma: `CapsuleShape3D` radio 0,4 m, alto 2,4 m, centrada en y = 1,22 (5-7, 18-20).
- Visual: instancia de `assets/enemies/locust.glb` con base diagonal (-1,95; 1,95; -1,95), es decir escala 1,95 y giro de 180° (21-22), con el script `locust_visual.gd` (23).
- `Warning`: AudioStreamPlayer3D, bus `Threat`, `max_distance` 40, posición y 2,2, `area_mask` 512 (24-28).
- `Footsteps`: AudioStreamPlayer3D, bus `Threat`, `unit_size` 6, `max_distance` 34, `panning_strength` 1,3 (29-34).
- `move_and_slide`: ocho en la carpeta; seis en hotel_locust.gd (1465, 1505, 1519, 1724, 1735, 1893) y dos en locust_player.gd (201, 220).
- Gravedad: `velocity.y = -2` si hay suelo, o `velocity.y - 20·delta` (hotel_locust.gd:1891). Otras veces `-2` fijo (locust_player.gd:219; hotel_locust.gd:1464, 1518, 1723, 1734).

### 5.2 Navegación

- No hay `NavigationAgent3D` ni `AStar` en `game/` (grep vacío). La ruta sale de `NavigationServer3D` a través de `FLOOR`:
  - `FLOOR.closest(map, point)` → `NavigationServer3D.map_get_closest_point(map, floor_point(point))` (floor_definition.gd:58-59).
  - `FLOOR.navigation_path(map, origin, target)` → `NavigationServer3D.query_path` (floor_definition.gd:310-320).
- Llamadas a esas dos funciones desde locust: hotel_locust.gd (12), locust_player.gd (4), door_threading.gd (2).
- `NavigationServer3D.map_get_iteration_id(map)` se mira en hotel_locust.gd:913 (`== 0`: mapa sin sincronizar) y en 2460 (`> 0`: ya sincronizado).
- La ruta se recalcula cada 0,45 s (`repath`, 1840) o al terminar un paso de puerta (1831). Si la ruta acaba a más de `UNREACHABLE` 2,5 m del destino (1950), se da por perdida (`give_up_route`, 1844).
- Un punto de ruta se da por alcanzado a menos de `REACHED` 0,3 m (1819), o si se ha pasado (1905-1909, distancia < 1,0 m).
- `PASSING_MOST` 2,5 s (1822): si se queda más en una puerta, la ruta deja de atar la puerta (1827).

### 5.3 Puertas: door_threading.gd

Pipeline `thread(route, doors, map)` (80-124):

1. `crossing(door, a, b)` (51-59): si el segmento a-b cruza el plano de la puerta dentro de `PASS_WIDTH` 0,9 m (36) y de 1,5 m en altura, devuelve el parámetro `t`.
2. Las marcas de paso (`passes`) se ordenan (88).
3. Se descartan los puntos de ruta dentro de `ZONE_DEPTH` 1,25 m (33) y `ZONE_WIDTH` 1,3 m (34) de la puerta (91-92).
4. Para cada paso: `line_up(door, side, map, y)` (63-72) en `LEAF_CLEAR` 1,7 m (18) del lado de la hoja abierta, o `APPROACH` 0,8 m (15) del otro, con `LATCH_SHIFT` 0,15 (21). Si no encaja (`SNAP_SLACK` 0,3 m, 30), prueba a `reach -= 0,3`. Dentro de la puerta ya alineado (`LINED_UP` 0,5 m, 38) no vuelve a salir.
5. Solo cuentan las hojas de su propia planta (114-118).
6. `bend(path, leaves, map, rounds)` (135-149): si un tramo cruza la hoja abierta por el tablero (`crosses`, 177-187), lo sustituye por el punto de la punta más `TIP_CLEAR` 0,9 m (25) hacia fuera (`round_point`, 163-170). `LEAF_MARGIN` 0,5 (28) amplía el margen de la punta.

`hotel_locust.gd` lo usa en `move_on_path` (1834): ruta cruda → `THREAD.thread` → ruta con `crossings` (`enter`, `exit`) y `rounds`.

La ruta con puertas es solo para moverse. El oído y el audio usan la ruta sin partir (comentario door_threading.gd:13).

### 5.4 Atasco y pasos de rescate

`watch_progress` (2000-2024) vigila el progreso:

- `STUCK_STEPS` [0,6; 0,9; 1,5; 2,0; 3,0] s (1964), `STUCK_GAIN` 0,3 m (1965).
- `STUCK_LINGER` 5,0 s (1974) y `LINGER_GAIN` 0,5 m (1975): si no se acerca a la ruta, cuenta aparte.
- `STUCK_FREE` 2,5 m (1976): fuera de esa distancia, el contador vuelve a 0.
- Escalones (`escalate`, 2034-2064): 1 esquivar a un lado (`free_side`, `DODGE_TIME` 0,5 s, 1978); 2 retroceder (`BACK_TIME` 0,6 s, 1979) y rehacer ruta; 3 abrir la puerta cercana (`shut_door_at_hand`, 2083) o `detour` (2091-2109); 4 en CHASE, rehacer; en otro modo `give_up_route`; 5 `hop()` (2115-2139), salto de hasta `HOP` 2,0 m (1981), solo en la IA y sin que nadie vea el origen ni el destino.

### 5.5 Puertas que abre al pasar

`door_ahead` (1921-1928): primera puerta de la ruta todavía no libre. Si está a menos de 2,4 m (CHASE) o 1,8 m (resto) (1868):

- cerrada y bloqueada: en no-caza, `give_up_route`; se para (1869-1873);
- si no, `ahead.toggle(not hunting, false, hunting)` y se para ante la puerta (1875-1877).

En versus, el cazador humano abre puertas al andar hacia ellas (`open_doors`, locust_player.gd:302-313): `use_door(door, not hunting, hunting)` a menos de 2,4 m (cazando) o 1,8 m, y con `heading · dir > 0,3`.

---

## 6. Ataque, captura, chillido, acecho

### 6.1 Golpe de la IA

`can_attack` (1171-1176), `seize` (1181-1184), `target` (680-690), `validate_strike` (no aplica a la IA). Rango `attack_range` 2,4 m (249).

### 6.2 Golpe del cazador humano (locust_player.gd)

- `strike()` (315-321): cooldown `COOLDOWN` 1,2 s (26). Entra en WINDUP.
- WINDUP (`creature.WINDUP_TIME` 0,3 s, hotel_locust.gd:254): avanza en `-global_basis.z` a `HUNT_SPEED · 1,15` = 7,36 m/s, con `velocity.y = -2` (200). A los 0,3 s llama `level.match_net.locust_strike(pos, facing)` (204) y pasa a RECOVER (207).
- El anfitrión lo juzga con `validate_strike(origin, facing, body)` (hotel_locust.gd:2245-2257): si el origen dista más de 3 m de la criatura, usa la criatura (2246). Más de `STRIKE_REACH` 3,2 m → INF (250, 2251). Ángulo de 70° (`STRIKE_ANGLE` 253) si la distancia pasa de 0,8 m (2252). Escondido sin armario abierto → INF (2253). Rayo desde `EYE_HEIGHT` 2,4 m a la cámara con máscara 1|8|64 (2254-2256). Se devuelve la distancia.

### 6.3 Captura (ejecución)

- `EXECUTION_TIME` 4,7 s (274), `EXECUTION_KILL` 3,3 s (275): momento del golpe mortal (usado por locust_visual.gd:227-235).
- `begin_execution` (1512-1514), `update_execution` (1516-1533): quieto, sostiene; tras `EXECUTION_TIME + 0,35` (5,05 s) suelta a SEARCH (IA) o PATROL (versus), salvo puppet.
- Escena de captura: `capture_style` devuelve `CAPTURE_STYLE` (2214-2215) = `game/app/capture_styles/locust_capture.gd` (no leído).
- `begin_capture` (2219-2220) y `end_capture` (2225-2226): solo si `control != "puppet"`.
- `capture_length` = `EXECUTION_TIME` (2228).

### 6.4 Armarios (WARDROBE)

- `WARDROBE_TIME` = `{burst 0,55; reach 0,15; done 1,7}` (270). `wardrobe_steps()` (171-173) las escala por `wardrobe_scale` (perfil): burst = 0,55·s; reach = burst + 0,15; done = 1,7·s.
- `begin_wardrobe` (1489-1495): para la criatura ante el armario; si es IA llama `level.open_wardrobe(hide)` (1494).
- `update_wardrobe` (1498-1509): se coloca delante con `settle_before` (`WARDROBE_SETTLE` 2,4 m/s, 1313) y mira al armario a velocidad 7; al cabo de `done` pasa a SEARCH (IA) o PATROL.
- `WARDROBE_STAND` 0,9 m (1297): distancia para empezar a esperar delante.

### 6.5 Acecho (feint, LURK)

Las cifras están en 1297-1317 y 1361-1441.

| Fase | Duración | Qué hace | Línea |
|---|---|---|---|
| look | 1,0-1,4 s (`LURK_LOOK`, 1301) | Mira las puertas | 1364, 1419 |
| aside | hasta 2,5 s (`LURK_STEP`, 1302) | Se aparta un paso a un lado (`lurk_spot`, 1337-1359) | 1422-1424 |
| wait | `feint_wait` 9-13 s (perfil; 47) | Quieta, sin ruido, mirando las puertas | 1430, 1433-1441 |
| pounce | 0,15 s de abrir (`POUNCE_BURST`, 1307) | Carrera de vuelta (aceleración 10, giro 12) y abre las hojas | 1469-1486 |

- Hay acecho solo si la IA está segura de quién hay (`certain`) y `feints(player)` (1326-1330).
- `LURK_AJAR` 0,3 s (1305): hoja entreabierta durante ese tiempo = alguien se muestra, va a por él (1408-1416).
- Si sale alguien a la vista, pasa a CHASE (1398-1406). Si otro entra a la vista, ALERT (1389-1395). Si el armario deja de valer, SEARCH (1381-1383).
- `hushed()` (1375-1376): el acecho se calla a los `LURK_HUSH` 2,4 s (1303), salvo en la fase pounce.
- El fallo de la fase `wait`: `give_up_area` y se va (1436-1441).

### 6.6 Chillido del cazador humano (locust_player.gd:326-334)

- `shriek()`: no si `shriek_cooldown > 0`, si hay gracia, o en WARDROBE o EXECUTE (327). Cooldown `SHRIEK_COOLDOWN` 10 s (30).
- `creature.howl(ECHO.SHRIEK_HOLD = 4,0, 1 / ECHO.SHRIEK_FALL = 1,818)` (331). Llama `echo.flash_shriek()` (333) y `level.match_net.locust_shriek()` (334).
- `howl(hold, fade, tell)` (598-602): `howl_left = hold + fade`. Encadena gruñidos agresivos (`howl_next`, 605-621) mientras dura. Desvanece la voz a lo largo de `fade` (`update_voice`, 630-637).
- `reveal(points)` (locust_player.gd:427-436): si encuentra a alguien, `frenzy = 6,0` (`FRENZY_TIME`, 23) y `stamina += 30` (`FRENZY_STAMINA`, 24), sin pasar de 100.

### 6.7 Resistencia y ritmo del cazador (locust_player.gd)

- `WALK_SPEED` 2,8 (15); `HUNT_SPEED` 6,4 (16); `STAMINA_DRAIN` 6,5 por s (19); `STAMINA_RECOVERY` 22 por s (20); `RECOVERY_DELAY` 0,6 s (21).
- `TRACE_TIME` 15 s (34), `TRACE_COOLDOWN` 20 s (35) para el rastro Q.
- `WARDROBE_REACH` 2,6 m (37).
- Cámara: `EYE` (0; 2,35; 0) (44), `ARM` 2,8 m (45), `SHOULDER` 1,0 m (48), `fov` 74° (114), `far` 240 m (118). La vara del brazo tiene una esfera de radio 0,2 (107-108) y máscara 1|8|128 (104).

---

## 7. Búsqueda, rondas, director, ascensores, den

### 7.1 Rondas (PATROL)

`choose_patrol(away_from)` (965-1006):

- Sala de su ala, a un paseo entre `PATROL_NEAR` 20 m y `PATROL_FAR` 60 m (987).
- Peso = `clamp((reloj - room_seen) / 150, 0,05, 1)` (990). ×0,05 si la sala se buscó hace poco (991). ×0,3 si está en `recent_rooms` (992). ×0,35 en un callejón sin salida (993).
- Escoge entre las 5 mejores al azar (1003).
- En `leaving` (tras dar un sitio por perdido), elige salas a al menos `LEAVE_MIN` 38 m del origen (984). Con un `lead` del director, solo sus salas (980-981).
- `walk_from(room)` (1011-1013) = `FLOOR.route_metres(manifest, room)`, una caché por sala.
- `mark_rooms` (1017-1030): cada 0,5 s marca la sala en la que está como vista, y las vecinas a menos de 16 m y con línea de vista.

### 7.2 Búsqueda (SEARCH)

- `begin_search` (1039-1049): mismo sitio (dentro de `AREA_SAME` 15 m) conserva el tiempo gastado.
- `plan_search` (1066-1094): el punto, la puerta de la sala más alineada con la última dirección del perseguido, la sala de detrás, y a veces un armario (`PEEK` 0,2 en 218). Luego, una sala lateral.
- `next_search_point` (1051-1063). En cada punto, pausa de 0,6-1,4 s (1700).
- `give_up_area` (1106-1127): marca las salas a `SEARCHED_RADIUS` 18 m de la planta como buscadas durante 75 s (1115). Detección a min(detección, 0,1). Va a PATROL, con `leaving = true`, y elige una sala lejos (`choose_patrol(origin)`).
- `area_abandoned` se emite con el origen y el destino (1127).

### 7.3 Director (`lead_to` / `sniffing`)

- `lead_to` (809-831): solo en PATROL, sin `lift_bound`. Guarda `lead = {point, radius, until, kind, rooms, once, sniff}`. Las salas son de su ala, a `radius` del punto, en la misma planta y fuera de `off_limits_rooms` y de `avoid`.
- `sniffing()` (832-853): en un `lead` con `sniff`, va a un armario de sus salas, y lo abre con `begin_wardrobe`.
- `lead_active()` (855-856): `clock < lead.until`.
- `set_mode` (no PATROL) borra `lead` (931).

### 7.4 Ascensores

`aim_at_lift(index)` (2403-2416): solo IA, solo en PATROL, SEARCH o INVESTIGATE, y sin detección ≥ 0,2 (2406). Pasa a INVESTIGATE con `destination = car`, `lift_bound = true` (2411), y cambia `patrol_room` a la sala de la antesala del ascensor (2415).

`follow_to_planta` (2394-2400): usa `level.lifts.creature_car(stage)`. Si es fresco, grita (`grunt`, 2397).

### 7.5 Den (guarida)

`den_room(stage)` (2430-2452): la sala de la planta de la etapa, entre la mitad y los 4/5 de la distancia (en saltos) desde la entrada de los supervivientes hasta la sala más lejana. Descarta salas a 3 o menos saltos de la entrada, salas a 2 o menos de la salida de refugio, y las cerradas. El sorteo: `RandomNumberGenerator` con semilla `hash([manifest.seed, "den"])` para la primera etapa, o `hash([seed, "den", stage])` para las demás (2449-2452).

`den_point(stage)` (2455-2461) = centro de la sala + (0; 0,04; 0), ajustado por `FLOOR.closest` si el mapa está sincronizado.

`null_creature.gd` tiene su propia `den_room` estática (58-70), con el criterio de la sala más lejos del punto de entrada (`route_metres`).

---

## 8. Vista de eco (echo_view.gd y shaders)

### 8.1 Qué es y cómo se activa

- Solo para el cazador humano (versus). Creada en `setup` (locust_player.gd:123-125), con `echo.setup(self)`.
- `set_control` (hotel_locust.gd:1213-1224): activa la vista si `control == "player"` y la regla `plain_sight` vale 0. Si no, la desactiva.
- Los granos y las nubes son nodos del nivel (`level.add_child(clouds)`, echo_view.gd:396), en espacio de mundo. La pantalla la cubre una malla de 1×1 que es hija de la cámara (`camera.add_child(field)`, 354), con `custom_aabb` enorme (352) y un vértice que escribe `POSITION` a pantalla completa (echo_field.gdshader:50-54).

### 8.2 Clic

- `CLICK_RATE` 2,0 por segundo (37). Intervalo = 1/2 × respiración (`BREATH_RATE` 0,14, `BREATH_DEPTH` 0,25; 43-44, 737) × azar (±`CLICK_JITTER` 0,22; 42, 738).
- `advance(delta, hunting)` (712-731) se llama desde `drive()` (locust_player.gd:233), dentro del paso de física del cazador. `hunting` no cambia el ritmo.
- `click` (735-761): cadena de rayos (`start_spray`), reflectores (`aim_reflectors`), cuerpos (`stamp_bodies`), sonidos (`bloom_contacts`), motas (`bloom_motes`), guías (`bloom_guides`).
- `WAVE_SPEED` 16 m/s (48): el frente llega a 40 m (`REACH`, 51) en unos 2,5 s.
- `MEMORY` 9 s (53) como vida máxima de un punto recordado (el límite real se sigue del tamaño del búfer en `push_uniforms`, 985).

### 8.3 Rayos y reparto por fotograma

- Rayos por clic: `budget.rays` (3 veces si es el grito, 745) y `budget.aimed` para reflectores (574).
- `start_spray(count)` (769-777): marco `Basis.looking_at(forward)`, giro aleatorio, `spray_ahead = count × FORWARD_BIAS` (0,62; 66), `spray_left = count`.
- `spray_direction(i)` (779-791): Fibonacci esférico con `GOLDEN` = π(3 - √5) (768). Los rayos de delante van en cono (`FORWARD_CONE` 1,0 rad; 67). Ruido gaussiano de 0,012 (790).
- `cast_pending()` (796-826): en cada paso de física lanza `per_tick` rayos. `per_tick = max(1, ceil((rays + aimed) / (60 / CLICK_RATE)))` (668). La cifra 60 está fija en el código (ver 12.1).
- El rayo de reflector se acepta solo si aterriza a menos de `INTEREST_HIT` 0,25 m del objetivo (`reflect`, 603-612; 159). Entonces escribe `INTEREST_GRAINS` 2 granos (812-814, 161).
- Rayo general: el punto de impacto escribe un grano en `walls` con energía `0,30 + 0,70 · facing` (826).

### 8.4 Granos: el búfer

- Cada nube es un `MultiMeshInstance3D` con `use_custom_data = true` (`make_cloud`, 368-391). `custom_data` = `Color(at, span, kind, energy)` (876).
- `write(cloud, point, span, kind, energy, at, reach)` (849-878): búfer en anillo; `wall_at`, `puff_at`, `find_at`, `frame_at`, `body_at`, `mote_at`. `written` cuenta para `write_rate` (877).
- Prioridad de dibujo (echo_view.gd y shaders):

| Nube | Prioridad | Material | `through` | Línea |
|---|---|---|---|---|
| Oscuridad (EchoField) | 120 | echo_field | - | 344 |
| Marcas fijas (puertas y armarios) | 121 | echo_points | 0,55 | 406 |
| Paredes (memoria) | 122 | echo_points | 0,35 | 400 |
| Reflectores (marcos) | 123 | echo_points | 0,2 | 402 |
| Sonidos (puffs) | 124 | echo_points | 0,8 | 403 |
| Chillido (finds) | 125 | echo_points | 0,8 | 404 |
| Guías | 125 | echo_points | 1,0 | 427 |
| Cuerpos | 126 | echo_points | 0,0 | 405 |
| Motas | 127 | echo_points | 1,0 | 411 |
| Su cuerpo | 127 | echo_self | - | 330 |

Las motas no aparecen en la tabla de VISION_LOCUST.md (líneas 25-35).

- `through` = 1 traspasa las paredes; 0 es la prueba de profundidad completa (echo_points.gdshader:109-128).

### 8.5 Reparto de presupuesto por preset

Fuente: game/presentation/graphics_presets.gd, bloque `echo` (192, 202, 212, 222, 235). El índice es el de `PRESETS` (0 Bajo, 1 Medio, 2 Alto, 3 Ultra, 4 Muy bajo).

| Campo | 0 Bajo | 1 Medio | 2 Alto | 3 Ultra | 4 Muy bajo |
|---|---|---|---|---|---|
| rays (por clic) | 950 | 1900 | 3600 | 4800 | 950 |
| aimed (reflectores) | 600 | 600 | 1200 | 1400 | 600 |
| points (paredes) | 12000 | 24000 | 46000 | 64000 | 12000 |
| bodies (cuerpos) | 400 | 700 | 1400 | 1800 | 400 |
| puff_points | 13 | 26 | 44 | 56 | 13 |
| puffs | 2400 | 4800 | 9600 | 12000 | 2400 |
| find_points | 20 | 40 | 70 | 90 | 20 |
| finds | 300 | 600 | 1200 | 1600 | 300 |
| frames (marcos) | 7000 | 7000 | 14000 | 18000 | 7000 |
| grain (tamaño) | 2,0 | 1,0 | 1,0 | 0,8 | 2,0 |
| halo | 0 | 0 | 0 | 1,0 | 0 |

`apply_quality` (645-707) lee `settings.values.quality` y lo limita a `PRESETS.count() - 1` (646). `reduced` (`settings.values.reduced`, 648) baja presencia y contraste.

- `COMPAT_LIFT` 1,6 (362): Compatibility sube la luminosidad de cada grano para compensar el tonemap (363-364).
- `PRESENCE` 0,006 (148) y `PRESENCE_CALM` 0,016 (149).

### 8.6 Reflectores (puertas y armarios)

- `build_reflectors` (524-566): para cada puerta del piso, marcos de 24/12/8/8 puntos (REVEAL/BAND/SOFFIT/HEADER, 171-174), y el panel de 40 puntos si la puerta está cerrada (548, 595). Para cada armario, un frente de 112 puntos (`WARDROBE_SPOTS`, 177).
- Los puntos se sortean de nuevo en cada clic (`reflector_spots`, 561-566).
- `aim_reflectors` (571-599): reflectores de su planta, a menos de `REACH` 40 m, no detrás salvo que esté a menos de 3 m (589). Primero los más cercanos, hasta agotar `aimed`.
- Marcas fijas (`build_landmarks`, 475-518): jambas (22 granos por jamba, `JAMB_GRAINS`) y dintel (13, `LINTEL_GRAINS`) de las puertas y armarios de su planta. Son estáticas y de `LANDMARK_LEVEL` 0,16 (134), con alcance `LANDMARK_NEAR` 14 m y `LANDMARK_REACH` 28 m (132-133).

### 8.7 Cuerpos (echo_body.gd)

- `echo_view.stamp_bodies` (831-844): solo si `level.survivors()`, `survivor_active`, a menos de 40 m (`REACH`), y `creature.sees(body)` (836-837). Es la regla de presentación más importante: la imagen nunca muestra más de lo que la criatura ve.
- `BODY.points(body, from, out, rng)` (echo_body.gd:44-48): si el avatar tiene rig, `rigged` (51-68); si no, `capsule` (94-108).
- `rigged`: diez mangas (`SLEEVES`, 17-28) entre pares de huesos del avatar. Cada manga muestrea `ALONG` 4 × `AROUND` 7 (31-32). Se descartan las caras que miran de lado (`outward · towards ≤ 0`, 90). Cabeza en `spine + 0,42` (61); manos y pies, extrapolados (62-65). La cabeza y los pies vienen de los huesos `head`, `lhand`, `rhand`, `lfoot`, `rfoot` que no existen en el modelo.
- `capsule`: anillos de `RINGS` (34-37) × `AROUND` 7. Agachado: escala 0,59 (96).
- Cada grano lleva la distancia a su origen; el frente barre el cuerpo (echo_view.gd:843-844).
- `body_material` tiene `residue` 0,32 (464), `flare` 2,4 (465), `BODY_FADE` 0,75 s (62, 987).

### 8.8 Sonidos (puffs)

- Entrada: `driver.heard`, cada contacto con `{id, point, apparent, at, time, strength, kind, distance, muffle, blur}` (locust_player.gd:467-476).
- `bloom_contacts` (905-929): solo los contactos nuevos (`id > puffed`, 909-910) y con menos de `CONTACT_LIFE` 1,6 s de edad real (911).
- Tablas por tipo (`KINDS.Kind`: FOOTSTEP, RUN, JUMP, DOOR, SLAM, WARDROBE, PEEK, HUM):
  - `PUFF_DENSITY` [1,5; 3,4; 2,0; 6,0; 7,0; 6,0; 2,0; 1,0] (81);
  - `PUFF_SIZE` [1,15; 1,45; 1,2; 1,35; 1,5; 1,35; 1,0; 1,0] (82);
  - `PUFF_LIVES` [2,2; 2,2; 2,2; 4,0; 4,0; 2,5; 2,2; 2,2] (83);
  - `PUFF_BELLS` = DOOR, SLAM, WARDROBE, PEEK (84-87).
- `puff_radius` (934-938): `(0,30 + 1,25·loud) · SPREAD[kind] · PUFF_SIZE[kind]`, con `blur` (`PUFF_BLUR` 0,4, `BELL_BLUR` 0,35), y tope `PUFF_MAX_RADIUS` 1,8 m (108). Pasos lejanos: tope `FAR_STEP_RADIUS` 0,9 m (115), con `FAR_STEP_GRAINS` 0,45 (116).
- Campana (`bell_offset`, 899-901): gaussiana de `PUFF_BELL` 0,22 del radio, recortada a 1,6 radios. El núcleo brilla `PUFF_CORE_GAIN` 2,5 (100) veces más.
- `PUFF_STAND_OFF` 1,1 m hacia la criatura si el sonido viene de lejos (97, 925-926).
- `PUFF_TWINKLE` 0,7 (93), `PUFF_WHITE` 2,2 (92), `PUFF_PIXELS` 3,2 (91), `PUFF_GAIN` 1,8 (90).
- `write_life(seconds)` = `2 · round(seconds · 10)` (943-944): la vida viaja en el canal `kind` del grano. El shader la decodifica (echo_points.gdshader:73-74).
- `shape_of_noise` (959-978): si el ruido es de cerca (`blur ≤ 0,01`) y hay un superviviente a menos de 1,4 m del punto, dibuja su silueta densa (3 granos por muestra, `NOISE_SHAPE` 3, 73).
- Armario (`before_wardrobe`, 948-952): el sonido del armario cuelga delante de sus puertas a `WARDROBE_PUFF_UP` 1,15 m y `WARDROBE_PUFF_OUT` 0,55 m (120-121).
- Zumbido de fluorescentes (`bloom_hums`, 999-1003): cada 1,4 s, desde `world_audio.hums` (level.world_audio), con `HUM_LEVEL` 0,13 (179).

### 8.9 Chillido (lo que dibuja)

- `flash_shriek` (1150-1153): `shriek_hold = 4,0` (128), `shriek_click = true`, `next_click = clock`. El clic siguiente lanza tres veces los rayos (745).
- `shriek` se sube a `SHRIEK_RISE` 6,0 por segundo y se baja a `SHRIEK_FALL` 0,55 por segundo (128-130, 728). El fundido dura 1/0,55 = 1,82 s, igual que el del sonido (locust_player.gd:331).
- `mark_found` (1125-1128): `scatter(finds, point, 0,55, find_points, 1, 1, clock)`. Dura `FIND_LIFE` 3,2 s (124, shader `age_limit`, 990).
- Los shaders pintan el rojo con `shriek_cold` y `shriek_hot` (echo_points.gdshader:40-41, 132).

### 8.10 Motas (una mente quemada)

- `bloom_motes` (1013-1019): hasta `MOTE_BODIES` 5 (214) supervivientes de `level.sanity.burnt_survivors()` (1015), 10 granos por cada uno (`MOTE_GRAINS` 213) con `MOTE_SPREAD` 0,38 (215), y `through` = 1.
- Se repone entera en cada clic (`visible_instance_count`, 1019).

### 8.11 Guías (lift, teles, rastro Q)

- `bloom_guides` (1024-1036): pantallas de los televisores encendidos (`lit_screens`, locust_player.gd:406-412), ruta al ascensor (`lift_route`, 346-349) y ruta a la tele del rastro Q (`trace_route`, 396-402).
- `lay_route` (1042-1073): grano cada `GUIDE_STEP` 0,35 m (228) o más si la ruta es larga (`length * GUIDE_PER_STEP / room`, 1049). `GUIDE_PER_STEP` 3 (229). Dispersión `GUIDE_SCATTER` 0,06 (231), altura `GUIDE_HEIGHT` 0,08 (230). Columna final de `GUIDE_END_GRAINS` 24 (237), que late en `beat` 0,35 o 1,6 según el clic (1066).
- `GUIDE_GRAINS` 2400 (226). `GUIDE_FLOW` 9 m/s (234): frente que recorre la ruta.
- Colores: azul `GUIDE_BLUE` (0,02; 0,22; 1,6) (240) para el ascensor; amarillo `GUIDE_YELLOW` (1,5; 1,05; 0,03) (241) para tele y rastro.
- `rounded(route)` (1081-1098): cada esquina se redondea hasta `ROUND_CORNER` 1,2 m (1079) con `ROUND_STEPS` 6 (1080). Solo cambia la imagen.
- `lay_screen` (1102-1120): `SCREEN_GRAINS` 48 (245), `SCREEN_HALO` 16 (246), `SCREEN_BEACON` 14 (247), energías 1,6, 0,8 y 1,2.

### 8.12 Shaders

echo_field.gdshader (126 líneas):
- `render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled` (18).
- `uniform sampler2D depth_map : hint_depth_texture, repeat_disable, filter_nearest` (22). Lee la profundidad en `ALPHA = 1` (125).
- Desplazamiento de jitter horizontal: hash por línea y por 24 Hz (59).
- Profundidad: Forward+ es Z invertido (`raw > 0.0000001`, 71-72); Compatibility es OpenGL (`raw < 0.9999999`, 68-69). Macro `CURRENT_RENDERER == RENDERER_COMPATIBILITY` (67, 70).
- Presencia: `colour = mix(...) * presence / (1 + d * 0,35)` (80-81). Es el único término que lee la distancia para pintar algo.
- Haz de linterna: `beam_origin` vec4 (39), `beam_axis` (40), `beam_range` (41), `BEAM_STEPS` 24 (42), recorrido en 24 pasos por el rayo del píxel, cortado por `wall_distance` (95). Brillo `bloom = w · through · ... · 0,03` (110).
- Grano del oído: `(speck - 0,5) · 0,010 · grain_amount` (122).

echo_points.gdshader (135 líneas):
- `render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled` (16).
- Vértice (65-101): `echo = INSTANCE_CUSTOM` (66); `front = age · wave_speed` (68); `flash = exp(-gap²/2,5)` (71); `memory` con `life` por grano (73-75); `live = (residue + flare·flash)·memory·w` (81); `twinkle` (82-85); billboard en espacio de vista (89-100); tamaño con `point_scale` 0,004, `point_min` 0,010, `point_max` 0,085 (25-27, 95); `halo` (99).
- Fragmento (103-135): círculo suave (106); con `through < 0,999`, prueba de profundidad blanda (109-128; lee `depth_map` en 113 y compara con `from_eye - wall` en 126); tonos (130-132); `ALPHA = clamp(disc·weight, 0, 1)` (134).

echo_self.gdshader (25 líneas):
- `render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled` (8). Aditivo, no escribe profundidad (4-7).
- `rim = (1 - |n·(-v)|)²` (19); `slices = (1 - |fract((y + now·0,05)/0,16) - 0,5|·2)^6` (21); `level = (rim·0,85 + slices·0,22 + 0,035)·gain` (22); `ALBEDO` lerp entre (0,82; 0,86; 0,9) y (1,3; 0,10; 0,06) con `shriek` (23).

### 8.13 Aplicación de su propio cuerpo

`enable` (616-627) sustituye `material_override` de cada `MeshInstance3D` del visual por `self_material` (render_priority 127, 330), guardando el anterior en meta `echo_kept` (626). `disable` lo restaura (629-638). `self_material` tiene `gain` = 0,08·lift²(333).

### 8.14 Presentación de la vista (VISION_LOCUST.md lo dice; no comprobado en el código de la vista)

Apagar SSAO, SSIL, glow, niebla, sombras y luces (`presentation_rig.apply_settings`). Sin TAA ni FXAA. Ver sección 16.

---

## 9. Aspecto del cuerpo (locust_visual.gd, locust_look.gd, locust_poser.gd)

### 9.1 Modelo y material

- `locust.tscn:3` carga `assets/enemies/locust.glb` (existe).
- `locust_look.apply` (locust_look.gd:8-13): busca superficies `StandardMaterial3D` cuya textura base acabe en `locust_locust_by-doumty_basecolor_tex.png` (12) y las sustituye por `assets/enemies/locust_reference_material.tres` (locust_look.gd:6). El look viene de `tools/art/make_locust_reference_texture.py` y `tools/art/build_locust_reference_material.gd` (locust_look.gd:4-5).
- Negro tinta con máscara pálida (locust_look.gd:2-3).
- Esqueleto de Valve Biped: prefijo `ValveBiped.Bip01_` (locust_visual.gd:10, locust_poser.gd:5).
- Huesos usados (locust_visual.gd:63): `Pelvis`, `Spine`, `Spine2`, `Spine4`, `Neck1`, `Head1`, `L_UpperArm`, `L_Forearm`, `L_Hand`, `R_UpperArm`, `R_Forearm`, `R_Hand`, `L_Thigh`, `L_Calf`, `L_Foot`, `R_Thigh`, `R_Calf`, `R_Foot`.
- Modelo mirando a +Z (locust_visual.gd:4).
- Máscara: `MASK_CENTRE` (-0,0014; 0,079; 0,0358) en el espacio del hueso de la cabeza (40), 12 cm de ancho y 14 de alto. `MASK_REACH` 0,17 m ante la lente (45). `BLADE` 0,36 m (42).
- `stance_width` 0,21 m (13), `run_speed` 6,4 m/s (15).

### 9.2 Pies y pasos

- `step_feet` (107-147): zancada `lerpf(0,8; 1,9; ratio)` (109), duración `clamp(stride/speed·0,5; 0,17; 0,42)` (111), elevación `0,1 + ratio·0,12` (112), alcance `stride·0,45·min(1, speed/0,8)` (113).
- Un paso empieza si el pie queda atrás más de `reach` o de lado más de 0,28 m, o si está parado y se ha desplazado más de 0,16 m (135). Los pies alternan; al correr se puede empezar antes (137).
- Si el pie se aleja más de 2,5 m de su sitio, se recoloca (118-119).
- Al pisar, `footfall.emit(point, ratio)` (128), que escucha `hotel_locust.on_footfall` (429, 493-502).

### 9.3 IK y cuerpo

- Piernas: `solve_leg` (181-199) con dos huesos (muslo y pantorrilla), la rodilla con `pole` (0,15 o -0,15; 0; 1) (193).
- `pose_body` (165-179): pelvis hacia abajo `lerpf(0,05; 0,15; ratio) + attack·0,08 + duck·0,12 - bob·0,025` (168); inclinación `hunch` (171-175) con `lean_target` = ratio·0,32 + aggression·0,12 + attack·0,25 - recovering·0,1 + duck·0,55 + searching·0,35 - execute·0,15.
- Brazos (`pose_arms`, 201-247): combinaciones de `aggression` (`lerp` a 0,45/0,4/0,8), `attack`, `recovering`, `searching`, `execute`. Blend por `delta·26` (ejecución), `18` (recuperación) u `8`.
- Cabeza (`pose_head`, 249-262): mira `look_point` con cuello 0,45 y cabeza 0,4 del ángulo.

### 9.4 Captura (pose_capture, 311-390)

Función de escena, toda ella de `scene` (`time`, `entry`, `side`, `ending`, `lens`, `mask_from`, `chest`, `face`, `body`, `glance`). Usa `SCORE` (`game/app/capture_score.gd`, no leído) para el tiempo: `stoop`, `ramp`, `smooth`, `JERK_TIME`, `JERK_LENGTH`, `DROP_TIME`, `BACK_TURN_FROM/TO`, `SWIPE_REACH`, `SWIPE_LENGTH`, `LIFT_FROM`, `GLANCE_COCK`, `thrust`, `face_end`, `swipe`, `glance`.

`reach_arm(side, target, pole)` (296-297) y `bend_to` (282-293) resuelven los brazos hacia un punto del mundo. `hanging(side)` (301-305) es el punto del filo cuando el brazo cuelga.

### 9.5 Poses de escena (locust_poser.gd)

Usa `skeleton.find_children` para hallar el esqueleto (12). Poses de escena `pose_peek` (75-85) y `pose_stare` (88-93). `reach` IK de brazos (49-69). `BLADE` 0,36 (7). `hang_arms` (95-99). `ease_out`/`ease_in` (101-107). No afecta la jugabilidad (2-3).

Usos (grep): game/app/hallucinations/locust_hallucinations.gd, game/app/phantom_sight.gd, game/intro/tv_broadcast.gd, game/presentation/shader_warmup.gd, game/title/title_scene.gd, tools/trailer3d/web/engine/locust.js. Cuál de los cinco nombres de clase usa cada uno: sin comprobar.

---

## 10. Audio

### 10.1 Voz (hotel_locust.gd)

- `voice` = AudioStreamPlayer3D creado en `_ready` (430-437): bus `Threat`, `unit_size` 7, `max_distance` 40, `max_db` 4, `area_mask` 512, stream `assets/audio/sfx/chase/grunts.ogg` (433).
- Se cuelga de `world_audio` (441) para sobrevivir a la criatura: `_exit_tree` lo libera (452-453).
- Segmentos del archivo: `GRUNTS.SEGMENTS` (game/audio/grunt_segments.gd). Son `[inicio, duración]`. "Agresivos" los de duración ≥ 1,4 s (`AGGRESSIVE_GRUNT`, 262); los demás son ladridos y resuellos (459-461).
- `warn()` (457-472): el ladrido previo al golpe, `pitch` 0,78-0,9 (463), `warn_left` = duración / pitch (472).
- `grunt()` (506-530): nunca el mismo dos veces seguidas (`last_grunt`, 510). `pitch` 0,85-1,0 (514). Envía `creature_call("grunt", segment, pitch)` (516). Si el audio está apagado, solo cuenta el tiempo (519). `aimed = aimed_at_local()` (517).
- `cry()` (534-544): segmentos de duración ≥ `CRY_LONGEST` 2,0 s (347), `pitch` 0,78-0,88 (348, 540). Se reproduce por `world_audio.play_everywhere` con `CRY_SOUND` (549; `CRY_GAIN` 0,0; 349).
- `chase_voice(delta)` (585-590): un gruñido cada `GRUNT_WAIT` 2,5-5,0 s (315), o `GRUNT_RETRY` 0,7 s si nadie lo oye (590). Mínimo `GRUNT_MIN` 1,6 s entre dos (320).
- `howl` / `update_voice` (598-637) ya citados en 6.6.
- `frustrated()` (1153-1159) y `play_lost` (1161-1169): gruñido más corto, `LOST_PITCH` 0,66 (72).
- `play_doubt` (1139-1141): chitter `CHITTERS` (73) a -4 dB, `play_at`.
- Perfil de sonido: `sound_profile` (hotel_locust.gd:2) = `game/audio/profiles/locust.tres` (existe; no leído).

### 10.2 Enrutado

- Todos los sonidos de la criatura pasan por `level.world_audio.route_source(point, rid)` y `apply_route(player, route, level_db, bus, flag)` (hotel_locust.gd:468-469, 496-500, 520-524, 615-617, 1163-1165, 1555-1557). `world_audio.duck_db()` (500) y `duck_under(seconds)` (572) para bajar el resto mientras suena un grito dirigido a ti.
- `route.audible` falso → no suena (469-470, 496-498, 521-522).
- Los pasos (`on_footfall`): nivel `lerpf(-9, -1, strength) - 6` si lo lleva el cazador (499).
- Gruñido dirigido a ti (`aim_voice`, 566-572): `+7` dB (`AIMED_GAIN`), `unit_size` 13 (`AIMED_UNIT`), `cutoff` 12 kHz (`AIMED_CUTOFF`) si no hay eco, y `duck_under`. Solo si `aimed_at_local()` (559-563): IA persiguiendo a este superviviente, o cazador a menos de 24 m y con visión.
- `shape_voice(shriek)` (576-580): gritos `VOICE_SHRIEK` {unit 5,5; reach 32; level 3} (325); gruñidos `VOICE_GRUNT` {unit 7; reach 40; level 0} (326).

### 10.3 Pasos y sonido de la garra

- `claw_sound()` (475-490): onda generada en código. 5512 muestras a 22050 Hz (0,25 s). Golpe de 3100 Hz con caída `exp(-320t)` y ruido `exp(-500t)·0,8`, más un golpe de 118 Hz `exp(-34t)`. Semilla `4401` (483).
- `footstep.pitch_scale` aleatorio 0,82-1,08 (501).

### 10.4 Chillido (sonido)

- Ver 6.6 y 8.9. `howl(hold, fade)`: el grito encadena gruñidos agresivos durante `hold` (4,0 s) y luego se apaga en `fade` (1,82 s). La voz baja en dB según `linear_to_db(howl_left/howl_fade)` (637).
- `howl_db` guarda el nivel de partida (618).

---

## 11. Qué decide el anfitrión frente a cada cliente

### 11.1 Control

- `"ai"` (creature.gd:47): su propio comportamiento. Es el caso sin red o el anfitrión de una partida cooperativa.
- `"puppet"`: sigue los estados enviados (`follow_state`, hotel_locust.gd:1250-1277).
- `"player"` (versus): lo maneja un jugador (`driver.drive`, 1572-1575).

El despacho de `_physics_process` (1569-1575): `puppet` → `follow_state`; `player` → `driver.drive` y voz; `ai` → toda la IA.

### 11.2 Reparto de funciones

| Función | IA (host o sin red) | Puppet (otra máquina) | Player (cazador) |
|---|---|---|---|
| `_physics_process` (1563) | IA completa | Solo `follow_state` | `driver.drive` |
| `hear` (771) | Sí (gate `control != "ai"`, 772) | No hace nada | No hace nada |
| `hear_route` (730) | Sí (lo calcula el anfitrión) | No | No (recibe el contacto ya calculado por `match_net.tell_hunter`; comentario en locust_player.gd:465-466) |
| `seize` / capturas | Sí, `level.capture_survivor` (1182) | No | Por `validate_strike` del anfitrión (2245) |
| `validate_strike` (2245) | No (solo el anfitrión juzga el golpe del cazador) | No | No |
| `count_grace` (553) | En `_physics_process` (1576) | No | En `drive` (locust_player.gd:166) |
| `grunt`, `cry`, `howl` | Decide y llama `creature_call` | Recibe con `play_call` (1536) | Llama `creature_call` (via `howl`, 601) |
| `warn` (457) | Al entrar en WINDUP (954-956) | Por `play_call("warning")` (1539-1541) | Local, al entrar en WINDUP |
| `pack_state` (1227) | Lo envía la red, ~15 veces por segundo (creature.gd:263) | Lo recibe por `push_state` (1235) | Lo envía |
| `relocate` (865) | Puesta de sala, reinicia la IA | Solo `grace` y modo | Solo `grace` y modo PATROL |
| Vista de eco | No | No | Sí (`echo_view`, solo `control == "player"`) |

### 11.3 Llamadas de red (nombres del código)

- `level.match_net.creature_call(kind, data, pitch)` (7 sitios): `"grunt"` (516), `"cry"` (542), `"howl"` (601), `"warning"` (956), `"doubt"` (1136 y 1370), `"lost"` (1158).
- `level.match_net.locust_strike(pos, facing)` (locust_player.gd:204).
- `level.match_net.locust_shriek()` (locust_player.gd:334).
- `level.match_net.locust_warp(index)` (locust_player.gd:441).
- `level.match_net.locust_open_hide(hide)` (locust_player.gd:456).
- `level.match_net.use_door(door, close_it, slam)` (locust_player.gd:313, 452).
- `level.match_net.local_is_locust()` (hotel_locust.gd:560).
- Recepción en la criatura: `hunter_contact` (2265), `hunter_reveal` (2262), `play_call` (1536), `push_state` (1235), `resume_state` (2235), `on_event` (creature.gd:274, no sobrescrito).

### 11.4 Qué decide solo el anfitrión

- La detección y el paso de estados de la IA (1576-1742), que solo corre en la máquina que manda.
- Todo lo que llega por `hear()` (772): los ruidos de los demás jugadores llegan por la red al anfitrión.
- El juicio de cualquier golpe del cazador (`validate_strike`, 2245).
- La captura: `seize()` y `level.capture_survivor` (1181-1182, 1479-1480).
- El armario: `level.open_wardrobe(hide)` (1494, 2 sitios en el nivel).

### 11.5 Lo que decide cada cliente por su cuenta

- La vista de eco del cazador: `echo_view.click` usa `creature.sees(body)` (echo_view.gd:836-837) con los supervivientes que tenga en local.
- El cuerpo y la animación de cualquier criatura (`locust_visual`, `_process`).
- El ritmo de la vista (`CLICK_RATE` y `rng` propios, echo_view.gd:314, 322).
- Las guías (`lift_route`, `trace_route`) se calculan en cada máquina, "sin enviar nada" (locust_player.gd:339-342).

---

## 12. Orden, física, reloj y azar

### 12.1 Física

- `_physics_process` (hotel_locust.gd:1563) hace la IA, el movimiento y los sentidos. El cazador humano actúa por `drive()` desde el mismo paso (locust_player.gd:233, dentro de `drive`).
- Consultas de rayos (`PhysicsRayQueryParameters3D`, `intersect_ray`, `intersect_shape`) necesitan el espacio de física sincronizado. Se hacen en: `clear_sight` (644-646), `hear_route` (736), `sees` (657), `lit_by_torch` (712-713), `doors_seen_from` (1449-1451), `body_fits` (2141-2150), `hop` (2133), `detour` (2100-2102), `free_side` (2075-2077), `place_shoulder` (locust_player.gd:294-296), `use` (locust_player.gd:445-449), `reflect` y `cast_pending` (echo_view.gd:603-612, 796-826), `stamp_bodies` (sin consulta directa, usa `sees`), `push_beam` (lee la antorcha).
- `cast_pending` (echo_view.gd:796) reparte los rayos entre pasos de física. `per_tick` (668) usa la cifra fija 60 para los pasos por segundo; si el proyecto cambia `physics_ticks_per_second`, cambia el reparto. No comprobado en `project.godot` (ver Sin comprobar).
- `move_and_slide` y `is_on_floor` (CharacterBody3D). `velocity.y` es la gravedad aplicada a mano (1891).
- Los disparos de física dependen de la posición de otros cuerpos en el mismo paso: los supervivientes se mueven en su propio `_physics_process` y el orden no está fijado en estos archivos (sin comprobar, depende del árbol de la escena).

### 12.2 Reloj de pared (`Time.get_ticks_msec()`)

Cinco lugares usan el reloj real, no el de la física:

- locust_player.gd:238-239: `heard` se filtra a 1,6 s de edad real.
- locust_player.gd:429-430: `reveal` guarda la marca del tiempo real.
- locust_player.gd:474: `hear_contact` guarda `time`.
- locust_player.gd:490-491: `revealed` se filtra a 1,2 s de edad real.
- echo_view.gd:907-911: `bloom_contacts` compara `seconds - mark.time > CONTACT_LIFE` (1,6 s). Después convierte esa edad al reloj del eco: `when = clock - (seconds - mark.time)` (920).

El reloj del eco (`clock`, echo_view.gd:716) suma `delta` y no usa el tiempo real. El comentario de la línea 185-186 dice por qué.

### 12.3 Azar

Generadores (RandomNumberGenerator) y sus semillas:

| Generador | Semilla | Dónde | Línea |
|---|---|---|---|
| `rng` de la criatura | sin semilla propia; el propio nodo la siembra (`rng.seed = manifest.seed + 71013`) | hotel_locust.gd | 446 |
| `wander_clock` | `rng.randf() * 100` | hotel_locust.gd | 448 |
| `rng` del eco | `manifest.seed + 90211` | echo_view.gd | 322 |
| `noise` del golpe de la garra | 4401 (fija) | hotel_locust.gd | 482-483 |
| den (guarida) | `hash([seed, "den"])` / `hash([seed, "den", stage])` | hotel_locust.gd | 2449-2451 |
| `rng` de `creature.gd` | sin semilla | creature.gd | 63 |
| echo_body | usa el `rng` que le pasa el eco | echo_body.gd | 44 |

Consumos del azar que afectan a la IA (orden de llamadas):

- Gruñidos: `last_grunt` (511), tono (514), intervalo (590).
- Búsqueda: `plan_search` (1080, 1088, 1092), `pick` en `choose_patrol` (1003), pausa (1667, 1700), `SCAN_TIME` (1653).
- Acecho: `first` (1339), fase `look` (1364), `wait` (1430), chitter (1368-1369).
- Pasos sin ruta (`detour`): ángulo (2095), distancia (2098).
- Fase de duda (1134-1135).
- Con `feint`: `rng.randf() >= feint` (1327).

El eco tiene su propio `rng` (`rng.seed` en 322) y los clics usan los suyos: el azar de la vista no consume el del mapa (la prueba `echo_test` lo cubre según VISION_LOCUST.md:160; no comprobado en el test).

Los valores que llegan a otras máquinas viajan por la red (`creature_call`): el segmento y el tono. Así, otras máquinas no sortean ruido sino que lo reproducen.

### 12.4 Orden entre nodos y señales

- `_ready` de hotel_locust (419-448): `visual = $Visual` (421), conexión de `footfall` (429), creación de `voice` (430-442), semilla (446). Si `level == null`, se apaga la física (444).
- `visual._ready` (locust_visual.gd:57-74) se ejecuta antes que el de la criatura en Godot (los hijos antes que el padre). Comportamiento de Godot, no comprobado en el código (sin comprobar).
- `locust_visual._process` (90) lee lo que la criatura escribe en `_physics_process`. El orden entre `_process` y `_physics_process` depende del frame; el visual usa `delta` de cuadro.
- `locust_player._process` (162-163) lee el stick derecho cada cuadro (`pad_look`); `drive` lo hace en física (165+).
- Señales: `area_abandoned` (1105, emitida en 1127), `route_abandoned` (1934, emitida en 1936), `stuck_escalated` (1998, emitida en 2041), `footfall` (locust_visual.gd:8, emitida en 128; conectada en hotel_locust.gd:429).
- `set_control` (1213) reinicia `net_states` y crea el driver la primera vez (1216-1219).

---

## 13. Motor Godot: clases y nodos que usa esta parte

Recuento por grep sobre `game/enemies/locust/*.gd` y `shaders/`. Es aproximado (una aparición por línea de código o de tipo).

### 13.1 Clases y nodos

| Clase o API | Apariciones | Dónde se usa |
|---|---|---|
| Vector3 | 393 | Todo el cálculo de posición |
| Node3D | 47 | Tipo de nodos y pivotes |
| Vector2 | 45 | Distancias en el plano |
| Dictionary | 40 | Estados, perfiles, mensajes |
| PackedVector3Array | 36 | Rutas y puntos de eco |
| Basis | 24 | Orientación |
| Transform3D | 11 | Granos en MultiMesh |
| Quaternion | 2 | Huesos |
| Color | 18 | Datos de los granos (`custom_data`) y tonos |
| ShaderMaterial | 21 | Nubes y cuerpo (echo_view.gd) |
| MultiMeshInstance3D | 12 | Nubes de granos |
| MultiMesh | 6 | Búferes de granos |
| QuadMesh | 3 | Pantalla de la vista y granos |
| MeshInstance3D | 5 | Malla de la pantalla y cuerpo propio |
| Skeleton3D | 5 | Esqueleto del modelo |
| Camera3D | 5 | Cámara del cazador |
| SpringArm3D | 2 | Brazo de la cámara |
| SpotLight3D | 2 | Antorcha (`lit_by_torch`, `push_beam`) |
| AudioStreamPlayer3D | 4 | Voz, pasos, avisos (+2 en la escena) |
| AudioStreamWAV | 3 | Sonido de la garra |
| PhysicsRayQueryParameters3D | 10 | Consultas de rayo |
| PhysicsDirectSpaceState3D | 3 | Espacio de física |
| PhysicsShapeQueryParameters3D | 1 | Cápsula en `body_fits` |
| CapsuleShape3D | 1 | `body_fits` (y la escena, locust.tscn) |
| SphereShape3D | 1 | Brazo de la cámara |
| NavigationServer3D | 2 | Cierre de `FLOOR` (`map_get_iteration_id`) |
| get_world_3d | 22 | Acceso a espacio de física y navegación |
| get_rid | 18 | Exclusiones |
| find_children | 5 | Búsqueda de esqueleto |
| add_child | 10 | Nodos creados en tiempo de ejecución |
| get_tree | 3 | `get_nodes_in_group("hotel_hides")` (846, 1099, 1187) |
| RandomNumberGenerator | 7 | Azar propio (ver 12.3) |
| Time.get_ticks_msec | 5 | Reloj de pared (ver 12.2) |
| Input | 3 | Entrada del cazador (`get_vector`, `is_action_just_pressed`) |
| InputMap | 1 | `has_action` |
| InputEventMouseButton | 1 | Clic del ratón |
| RenderingServer | 1 | `get_current_rendering_method()` (echo_view.gd:364) |
| StandardMaterial3D | 1 | Comprobación de tipo (locust_look.gd:11) |
| StringName | 7 | Nombres de actividad y modos |
| Resource | 2 | `sound_profile` |
| RefCounted | 4 | Clases auxiliares (`door_threading`, `echo_body`, `locust_look`, `locust_poser`) |
| move_and_slide | 8 | Movimiento de CharacterBody3D |
| is_on_floor | 2 | Gravedad |
| lerp_angle | 3 | Giros suaves |
| load / preload | 3 / 25 | Recursos (grunts.ogg, locust_player.gd en tiempo de ejecución) |
| queue_free | 2 | Liberar voz y nubes |

Los recursos que cita la parte: `assets/enemies/locust.glb`, `assets/enemies/locust_reference_material.tres`, `game/audio/profiles/locust.tres`, `assets/audio/sfx/chase/grunts.ogg`, `assets/audio/dread/chitter_0.wav` (y _1, _2), los tres shaders `.gdshader`, `game/app/capture_styles/locust_capture.gd`, `game/app/hallucinations/locust_hallucinations.gd`, `game/app/capture_score.gd`. Todos existen (comprobado).

### 13.2 Esqueleto (API de Skeleton3D)

| Llamada | Apariciones |
|---|---|
| get_bone_global_pose | 22 |
| get_bone_global_rest | 12 |
| set_bone_global_pose | 5 |
| get_bone_pose | 2 |
| set_bone_pose_rotation | 2 |
| get_bone_parent | 2 |
| find_bone | 2 |
| reset_bone_poses | 2 |
| get_bone_rest | 1 |

### 13.3 Nodos de la escena (locust.tscn)

CharacterBody3D (raíz), CollisionShape3D (BodyShape), Node3D instancia del .glb (Visual) con script, AudioStreamPlayer3D ×2 (Warning, Footsteps).

Nodos creados en ejecución:

- pivot Node3D (locust_player.gd:96-99), SpringArm3D (100), Camera3D "HunterCamera" (112-119), SphereShape3D (107).
- EchoView (Node) (locust_player.gd:123-125), con `EchoField` (MeshInstance3D + QuadMesh, echo_view.gd:345-354), `EchoClouds` (Node3D, 394-396), y 8 MultiMeshInstance3D (`EchoWalls`, `EchoFrames`, `EchoPuffs`, `EchoFinds`, `EchoBodies`, `EchoLandmarks`, `EchoMotes`, `EchoGuides`; 400-411, 427).
- Voice (AudioStreamPlayer3D, hotel_locust.gd:430).

---

## 14. Constantes y cifras (ruta:línea)

### 14.1 Criatura (hotel_locust.gd, salvo que se indique)

| Constante | Valor | Línea | Qué es |
|---|---|---|---|
| SIGHT_RANGE | 70 | 10 | Alcance de vista |
| ONSLAUGHT_REACH | 1,25 | 13 | Factor de alcance con onslaught |
| SIGHT_HALF_ANGLE | 60 | 174 | Semiángulo de vista por defecto |
| NOTICE_NEAR | 3,2 | 176 | Ganancia de detección cerca |
| NOTICE_FAR | 0,9 | 177 | Ganancia de detección lejos |
| NOTICE_DECAY | 0,12 | 178 | Pérdida de detección por s |
| SUSPICION | 0,2 | 180 | Umbral para investigar |
| HEARING_SCALE | 2,6 | 183 (noise_kinds.gd:25) | Escala del alcance de oído |
| APPARENT_NEAREST | 3,5 | 185 | Distancia mínima del sonido doblado |
| LOSE_AFTER | 7 | 187 | s sin ver antes de buscar |
| PATROL_NEAR / PATROL_FAR | 20 / 60 | 195-196 | Paseo de una ronda (m) |
| STALE_FULL | 150 | 197 | s para una sala "fría" |
| DEAD_END_PEEK | 0,35 | 198 | Peso de un callejón |
| RECENT_ROOMS | 6 | 199 | Salas recordadas |
| SCAN_TIME | 1,0-2,5 | 201 | Mirada en una sala |
| GIVE_UP / GIVE_UP_HARD | 8 / 10 | 211-212 | s sin pistas |
| SEARCHED_RADIUS / SEARCHED_FOR | 18 / 75 | 213-214 | Zona dada por buscada |
| SEARCH_PEEK_CHANCE | 0,2 | 218 | Abrir un armario al buscar |
| AREA_CAP / AREA_SAME / LOUD | 40 / 15 / 30 | 223-225 | Zona y ruido fuerte |
| CHASE_SPEED | 6,4 | 227 | Persecución (m/s) |
| TRACK_SPEED | 5,2 | 229 | Ir al último punto (m/s) |
| LIFT_PACE | 4,0 | 233 | Ir al ascensor (m/s) |
| ALERT_TIME | 1,2 | 236 | Giro antes de perseguir (s) |
| CHASE_START_SPEED / CHASE_ACCELERATION | 2,5 / 3,2 | 238-239 | Arranque de caza |
| TORCH_NOTICE_RANGE / ANGLE | 45 / 32 | 240, 244 | Antorcha |
| ATTACK_RANGE | 2,4 | 249 | Alcance del golpe IA |
| STRIKE_REACH / STRIKE_ANGLE | 3,2 / 70 | 250, 253 | Golpe del cazador |
| WINDUP_TIME / RECOVER_TIME | 0,3 / 0,6 | 254-255 | Golpe y recuperación |
| EYE_HEIGHT | 2,4 | 257 | Altura de ojos |
| AGGRESSIVE_GRUNT | 1,4 | 262 | Gruñido "agresivo" (s) |
| WARDROBE_TIME | 0,55 / 0,15 / 1,7 | 270 | Armario (burst, reach, done) |
| EXECUTION_TIME / EXECUTION_KILL | 4,7 / 3,3 | 274-275 | Captura |
| WARDROBE_STAND / WARDROBE_SETTLE | 0,9 / 2,4 | 1297, 1313 | Armario |
| LURK_LOOK / LURK_STEP / LURK_HUSH | 1-1,4 / 2,5 / 2,4 | 1301-1303 | Acecho |
| LURK_AJAR | 0,3 | 1305 | Hoja abierta para acecho |
| POUNCE_BURST / POUNCE_REACH / POUNCE_PATIENCE | 0,15 / 0,5 / 1,5 | 1307-1311 | Salto del acecho |
| POUNCE_ACCELERATION / POUNCE_TURN | 10 / 12 | 1316-1317 | Carrera de acecho |
| DOUBT_FROM / DOUBT_CAP / DOUBT_REST | 0,05 / 0,95 / 6 | 53-55 | Duda |
| TIRED_FOR | 3 | 64 | s de no atender tras cansarse |
| GRUNT_WAIT / GRUNT_RETRY / GRUNT_MIN | 2,5-5 / 0,7 / 1,6 | 315-320 | Gruñidos |
| GRUNT_REGAIN | 1,5 | 357 | Volver a gruñir al volver a ver |
| CRY_LONGEST / CRY_PITCH | 2,0 / 0,78-0,88 | 347-348 | Grito de inicio de caza |
| VOICE_SHRIEK | unit 5,5, reach 32, level 3 | 325 | Voz del grito |
| VOICE_GRUNT | unit 7, reach 40, level 0 | 326 | Voz de gruñido |
| AIMED_GAIN / AIMED_UNIT / AIMED_REACH / AIMED_CUTOFF | 7 dB / 13 / 24 / 12000 | 336-339 | Gruñido dirigido a ti |
| LOST_PITCH | 0,66 | 72 | Gruñido de pérdida |
| CHASE_EARSHOT | 9 | 770 | Ruido que sigue a la caza |
| REACHED / PASSING_MOST / UNREACHABLE | 0,3 / 2,5 / 2,5 | 1819, 1822, 1950 | Rutas |
| STUCK_STEPS | 0,6 / 0,9 / 1,5 / 2,0 / 3,0 | 1964 | Atasco (s) |
| STUCK_GAIN / STUCK_LINGER / LINGER_GAIN / STUCK_FREE | 0,3 / 5 / 0,5 / 2,5 | 1965-1976 | Atasco |
| DODGE_TIME / BACK_TIME / HOP | 0,5 / 0,6 / 2,0 | 1978-1981 | Escapes |
| 1,9 + sin(0,37)·0,5 + sin(1,13)·0,2 | patrulla | 1197 | Velocidad de ronda |
| aceleración en movimiento | 10 / 3,2 / 3,5; frenada 9 | 1886-1887 | m/s² |
| giro | 12 / 8 / 4,5 | 1892 | velocidad de giro |

### 14.2 Cazador humano (locust_player.gd)

| Constante | Valor | Línea |
|---|---|---|
| WALK_SPEED | 2,8 | 15 |
| HUNT_SPEED | 6,4 | 16 |
| STAMINA_DRAIN / STAMINA_RECOVERY | 6,5 / 22 (por s) | 19-20 |
| RECOVERY_DELAY | 0,6 | 21 |
| FRENZY_TIME / FRENZY_STAMINA | 6 / 30 | 23-24 |
| COOLDOWN (golpe) | 1,2 | 26 |
| SHRIEK_COOLDOWN | 10 | 30 |
| TRACE_TIME / TRACE_COOLDOWN | 15 / 20 | 34-35 |
| WARDROBE_REACH | 2,6 | 37 |
| EYE | (0; 2,35; 0) | 44 |
| ARM | 2,8 | 45 |
| SHOULDER | 1,0 | 48 |
| CONTACT_TRUTH / CONTACT_BLUR | 8 / 14 | 52-53 |
| CHANNEL_MARGIN / CHANNEL_LEAST | 1,15 / 12 | 89-90 |
| Esfera del brazo | radio 0,2 | 107-108 |
| FOV de cámara | 74 | 114 |
| far de cámara | 240 | 118 |

### 14.3 Vista de la criatura compartida (creature_sight.gd)

| Constante | Valor | Línea |
|---|---|---|
| MASK | 1 \| 8 \| 64 | 12 |
| REGARD_LOCAL / REGARD_REMOTE | 30° / 45° | 16-17 |
| REGARD_REACH | 30 m | 19 |
| DARK_FACE | 1,2 m | 22 |
| TORCH_FACE_ANGLE / TORCH_REACH | 20° / 20 m | 26-27 |
| WATCH_REACH / WATCH_DOT | 70 m / 0,35 | 29-30 |
| BESIDE | (0,45; 0,85) | 32 |
| REAR_DOT | -0,26 | 35 |
| OVER_SIN / OVER_LOOK | 0,77 / 0,5 | 36-37 |

### 14.4 Vista de eco (echo_view.gd)

| Constante | Valor | Línea | Qué es |
|---|---|---|---|
| CLICK_RATE | 2,0 /s | 37 | Clics por segundo |
| CLICK_JITTER | 0,22 | 42 | ±22% del intervalo |
| BREATH_RATE / BREATH_DEPTH | 0,14 / 0,25 | 43-44 | Respiración |
| WAVE_SPEED | 16 m/s | 48 | Frente de onda |
| REACH | 40 m | 51 | Alcance útil |
| MEMORY | 9 s | 53 | Vida máxima de un punto |
| BODY_EVERY | 1 | 61 | Cuerpos en cada clic |
| BODY_FADE | 0,75 s | 62 | Desvanecido de cuerpos |
| FORWARD_BIAS / FORWARD_CONE | 0,62 / 1,0 rad | 66-67 | Cono de rayos |
| PUFF_SPEED / PUFF_LIFE | 4,5 m/s / 2,2 s | 70-71 | Nubes de sonido |
| NOISE_SHAPE | 3 | 73 | Granos por muestra de silueta |
| PUFF_DENSITY | [1,5; 3,4; 2,0; 6,0; 7,0; 6,0; 2,0; 1,0] | 81 | Por tipo |
| PUFF_SIZE | [1,15; 1,45; 1,2; 1,35; 1,5; 1,35; 1,0; 1,0] | 82 | Por tipo |
| PUFF_LIVES | [2,2; 2,2; 2,2; 4; 4; 2,5; 2,2; 2,2] | 83 | s por tipo |
| PUFF_BELL | 0,22 | 88 | Campana |
| PUFF_GAIN / PUFF_PIXELS / PUFF_WHITE | 1,8 / 3,2 / 2,2 | 90-92 | Brillo de sonidos |
| PUFF_TWINKLE | 0,7 | 93 | Titileo |
| PUFF_STAND_OFF | 1,1 m | 97 | Separación del marco |
| PUFF_CORE_GAIN | 2,5 | 100 | Núcleo de la campana |
| PUFF_BLUR / BELL_BLUR | 0,4 / 0,35 | 106-107 | Borrón por distancia |
| PUFF_MAX_RADIUS | 1,8 m | 108 | Radio máximo |
| FAR_STEP_RADIUS / FAR_STEP_GRAINS | 0,9 m / 0,45 | 115-116 | Pasos lejanos |
| WARDROBE_PUFF_OUT / WARDROBE_PUFF_UP | 0,55 / 1,15 | 120-121 | Armario |
| FIND_LIFE | 3,2 s | 124 | Chillido: vida de lo encontrado |
| CONTACT_LIFE | 1,6 s | 126 | Vida de un contacto |
| SHRIEK_HOLD / RISE / FALL | 4 s / 6 /s / 0,55 /s | 128-130 | Grito |
| LANDMARK_NEAR / REACH / LEVEL | 14 / 28 / 0,16 | 132-134 | Marcas fijas |
| JAMB_GRAINS / LINTEL_GRAINS | 22 / 13 | 137-138 | Marco de puerta |
| DOORWAY_HIGH | 2,6 m | 140 | Altura libre |
| POINT_PIXELS | 2,0 | 143 | Tamaño en píxeles |
| PRESENCE / PRESENCE_CALM | 0,006 / 0,016 | 148-149 | Presencia |
| INTEREST_HIT / INTEREST_GRAINS | 0,25 m / 2 | 159, 161 | Reflectores |
| FRAME_MEMORY / FRAME_PIXELS | 5 s / 2,6 | 163-164 | Marcos |
| REVEAL_SPOTS / BAND_SPOTS / SOFFIT_SPOTS / HEADER_SPOTS / PANEL_SPOTS | 24 / 12 / 8 / 8 / 40 | 171-175 | Puntos por clic |
| WARDROBE_SPOTS | 112 | 177 | Armario |
| HUM_LEVEL | 0,13 | 179 | Zumbido |
| COMPAT_LIFT | 1,6 | 362 | Compatibility |
| MOTE_GRAINS / MOTE_BODIES / MOTE_SPREAD | 10 / 5 / 0,38 | 213-215 | Motas |
| GUIDE_GRAINS | 2400 | 226 | Guías |
| GUIDE_STEP / GUIDE_PER_STEP | 0,35 m / 3 | 228-229 | Guías |
| GUIDE_HEIGHT / GUIDE_SCATTER | 0,08 / 0,06 | 230-231 | Guías |
| GUIDE_FLOW | 9 m/s | 234 | Frente de la guía |
| GUIDE_END_GRAINS | 24 | 237 | Columna final |
| GUIDE_BLUE / GUIDE_YELLOW | (0,02; 0,22; 1,6) / (1,5; 1,05; 0,03) | 240-241 | Colores |
| SCREEN_GRAINS / HALO / BEACON | 48 / 16 / 14 | 245-247 | Pantallas |
| ROUND_CORNER / ROUND_STEPS | 1,2 m / 6 | 1079-1080 | Curvas |
| GOLDEN | π(3 - √5) | 768 | Ángulo áureo |

### 14.5 Cuerpo, rutas y puertas (visual, eco del cuerpo y door_threading)

| Constante | Valor | Línea | Archivo |
|---|---|---|---|
| stance_width | 0,21 m | 13 | locust_visual.gd |
| run_speed | 6,4 m/s | 15 | locust_visual.gd |
| zancada | 0,8 a 1,9 m | 109 | locust_visual.gd |
| duración de paso | 0,17 a 0,42 s | 111 | locust_visual.gd |
| elevación del pie | 0,1 + 0,12·ratio m | 112 | locust_visual.gd |
| umbral de paso | 0,28 m de lado, 0,16 m parado | 135 | locust_visual.gd |
| recolocación del pie | 2,5 m | 118 | locust_visual.gd |
| MASK_CENTRE | (-0,0014; 0,079; 0,0358) | 40 | locust_visual.gd |
| MASK_REACH | 0,17 m | 45 | locust_visual.gd |
| BLADE | 0,36 m | 42 | locust_visual.gd |
| SLEEVES | 10 mangas | 17-28 | echo_body.gd |
| ALONG × AROUND | 4 × 7 | 31-32 | echo_body.gd |
| RINGS | 8 anillos | 34-37 | echo_body.gd |
| APPROACH / LEAF_CLEAR / LATCH_SHIFT | 0,8 / 1,7 / 0,15 m | 15-21 | door_threading.gd |
| TIP_CLEAR / LEAF_MARGIN / SNAP_SLACK | 0,9 / 0,5 / 0,3 m | 25-30 | door_threading.gd |
| ZONE_DEPTH / ZONE_WIDTH / PASS_WIDTH | 1,25 / 1,3 / 0,9 m | 33-36 | door_threading.gd |
| LINED_UP | 0,5 m | 38 | door_threading.gd |
| collision_layer / mask del cuerpo | 32 / 9 | locust.tscn:9, 16 | locust.tscn |
| cápsula | radio 0,4 / alto 2,4 / y 1,22 | locust.tscn:5-7, 19 | locust.tscn |

---

## 15. Pruebas y herramientas que vigilan esta parte

### 15.1 Pruebas (tests/)

Recuento de referencias a las piezas de locust (grep):

| Archivo | Refs | Qué sabemos |
|---|---|---|
| tests/hotel/creature_contract_test.gd | 22 | Vigila el contrato: predicados por modo (función en la línea 200), identidad (233), sentidos (253), consumidores (292), lectores de la captura (316), distancias del director (336). Cabecera (1-90) describe el alcance completo: red, observador, bots, criatura nula. |
| tests/hotel/echo_test.gd | 2 | Funciones: `check` 19, `frames` 24, `click_passes` 30, `far_room` 38, `run` 45. El alcance de cada comprobación lo recoge docs/VISION_LOCUST.md:160 (cadencia, presupuesto de rayos, anillos, caducidad, cuerpo a la vista y tras la pared, contactos, chillido, marcas, orden de dibujo, modo reducido, calidad 0, azar, salida del asiento). Los asertos no se han leído. |
| tests/hotel/creature_test.gd | 0 | Pruebas de la criatura (`searching` 72, `leading` 111, `after_a_kill` 139, `crying` 150). No nombra piezas de locust directamente. |
| tests/hotel/difficulty_test.gd | 1 | Sin comprobar |
| tests/hotel/observer_test.gd | 1 | Sin comprobar |
| tests/hotel/stages_test.gd | 2 | Sin comprobar |
| tests/hotel/survival_test.gd | 1 | Sin comprobar |
| tests/office/lurker_fairness_test.gd | 1 | Sin comprobar |

El CLAUDE.md del repo dice que `hotel/manifest_golden_test` y `hotel/creature_contract_test` vigilan el piso 1. `manifest_golden_test` no se ha leído.

### 15.2 Orden de verificación (tools/verify.ps1)

`verify.ps1:45` lista, entre otras, `hotel/echo_test`, `hotel/creature_test`, `hotel/creature_contract_test`, `hotel/manifest_golden_test`, `hotel/sanity_test`, `hotel/observer_test`, `hotel/hotel_audio_test`, `hotel/spatial_audio_test`, `hotel/capture_test`, `hotel/stages_test`, `hotel/survival_test`, `hotel/difficulty_test`. `verify.ps1` no se ha leído completo.

VISION_LOCUST.md:161 indica que `tools/dev/check_shaders.gd` necesita ventana: sin GPU informa `SHADERS_SKIPPED`.

### 15.3 Herramientas que tocan esta parte (grep)

- Capturas: `tools/capture/echo_capture.gd`, `locust_gait_capture.gd`, `mask_capture.gd`, `execution_capture.gd`, `doors_capture.gd`, `hearing_probe.gd`... (la lista completa está en la salida del grep; no todas se han leído).
- Herramientas de desarrollo: `tools/dev/echo_probe.gd`, `echo_rehearsal.gd`, `creature_stuck_probe.gd`, `creature_crossing.gd`, `hearing_probe.gd`, `wardrobe_look.gd`, `searched_look.gd`, `mask_probe.gd`, `body_clip_probe.gd`, `pause_chase_probe.gd`, `light_leak.gd`, `wood_look.gd`, `zfight_scan.gd`.
- Bots: `tools/bots/bot_threats.gd`, `bot_threat.gd`, `bot_nav.gd`, `bot_threat_none.gd`.
- Audio: `tools/audio/measure_*.gd` (4 archivos).

---

## 16. Discrepancias: docs/VISION_LOCUST.md contra el código

1. **VISION_LOCUST.md:152** da presupuestos por calidad "[0, 2200, 4200]" para rayos por clic y "[0, 2600, 5200]" para granos de sonido. En graphics_presets.gd (192-235) las cifras son 950, 1900, 3600 y 4800 para rayos, y 2400, 4800, 9600 y 12000 para `puffs`. Ninguna de las dos series coincide. La tabla de VISION_LOCUST.md:43-48 sí coincide con el código.
2. **VISION_LOCUST.md:170** dice que `presence` es "el único término que aún toca la profundidad". En el código, `echo_points.gdshader:109-128` también lee `depth_map` para la prueba de profundidad blanda de cada grano (los que tienen `through < 0,999`), y `echo_field.gdshader:77` y `95` usan la distancia reconstruida de la pared para cortar el haz. La profundidad no dibuja forma, pero sí interviene.
3. **VISION_LOCUST.md:104** dice "una línea de motas sobre el suelo cada 35 cm". El código usa `GUIDE_STEP` 0,35 como mínimo; si la ruta es larga el paso crece (`lay_route`, echo_view.gd:1049).
4. **VISION_LOCUST.md** no nombra las motas (`EchoMotes`, prioridad 127, echo_view.gd:411) en la tabla de prioridades (líneas 25-35).
5. **VISION_LOCUST.md:126** dice que un superviviente quieto no se encuentra y mide el chillido "cinco por segundo". La lógica del chillido está en `match_net.gd`, que no se ha leído: sin comprobar.

Coincidencias comprobadas: 2,0 clics por segundo (37); 16 m/s (48); ±22% (42); 46.000 granos del preset Alto (212); 3.600 y 1.200 del Alto (212); 2.400 granos de guía (226); 10 s de cooldown del chillido (locust_player.gd:30); `SHOULDER` 1,0 (48); `PUFF_MAX_RADIUS` 1,8 (108); `APPARENT_NEAREST` 3,5 (185); 8 y 14 m de ruta (52-53); colores de guía (240-241); presencia 0,006 y 0,016 (148-149); `ALPHA = 1` en el campo (125).

---

## Sin comprobar

Lo que no se ha leído, o lo que se ha visto solo por grep:

1. **Lo que la criatura llama y no está en esta carpeta.** `level.*` (hotel_main.gd: `survivors()`, `survivor_active()`, `capture_survivor()`, `open_wardrobe()`, `burst_wardrobe()`, `point_protected()`, `point_in_refuge()`, `off_limits_rooms()`, `lit_televisions()`, `creature_at_television()`, `rule()`, `local_alive()`, `execution`, `difficulty`, `DIFFICULTY`, `WARP_REACH`). `level.match_net.*` (match_net.gd, sus RPC y su envío de `creature_call`, `tell_hunter`, `use_door`, `locust_strike`, `locust_shriek`, `locust_warp`, `locust_open_hide`, `local_is_locust`). `level.lifts`, `level.televisions`, `level.camcorder`, `level.world_audio` (`route_source`, `apply_route`, `duck_under`, `duck_db`, `play_at`, `play_everywhere`, `hums`, `aura.route_to`, `PRESENCE_RISE`, `enabled`), `level.sanity.burnt_survivors()`, `level.observer_view`, `level.settings`, `level.session` (`goal`, `State`, `participants`).
2. **Puertas.** `game/world/interactables/hotel_door.gd` no se ha leído: `doorway`, `across()`, `along()`, `leaf_line()`, `closed_rotation`, `opened`, `moving`, `locked`, `toggle()`, `OPEN_SOLID` (capas 64 y 128 según locust.tscn:10-15).
3. **Armarios.** `game/world/interactables/hiding_place.gd` no se ha leído: `hinge`, `width`, `height`, `exit_offset`, `exit_of()`, `ajar()`, `occupant`, `QUIET_EXIT`.
4. **Navegación del piso.** Solo se ven las firmas de `floor_definition.gd` (líneas 47, 58-59, 78, 158, 310-320). No se ha leído el cuerpo de `navigation_path` ni de `route_metres` (ni si el mapa cubre una o varias plantas).
5. **Perfiles de dificultad.** `game/floors/difficulty.gd` no se ha leído: los valores de `tune()` (`sight_range`, `notice`, `hearing`, `torch_range`, `alert_time`, `chase_*`, `lose_after`, `give_up`, `peek_chance`, `attack_range`, `recover`, `wardrobe`, `doubt`, `chase_tire`, `lost_cry`, `guess_hides`, `feint`, `feint_wait`, `tired`, `sight_angle`, `cover`, `glimpse`) por dificultad.
6. **Señal de la IA en el piso.** `game/enemies/locust/` usa `survivor.avatar` (echo_body.gd:45-46, con `rig` y `bones` y las claves `hip`, `spine`, `la`, `lf`, `lhand`, `ra`, `rf`, `rhand`, `lt`, `lk`, `lfoot`, `rt`, `rk`, `rfoot`). `avatar_visual.gd` no se ha leído.
7. **Supervivientes.** `hotel_player.gd`, `remote_player.gd`, `bot_body.gd`: propiedades `camera`, `torch`, `hidden`, `hiding_place`, `crouched`, `slot`, `velocity`.
8. **Captura.** `game/app/capture_styles/locust_capture.gd` y `game/app/capture_score.gd` (constantes `JERK_TIME`, `DROP_TIME`, `BACK_TURN_*`, `SWIPE_*`, funciones `stoop`, `ramp`, `smooth`, `thrust`, `swipe`, `glance`, `face_end`).
9. **Ruidos.** `game/audio/noise_kinds.gd` en sus líneas 45 en adelante (`radius`, `SPREAD` completo, la asignación de `Kind` a `HEARD`).
10. **Presets.** `graphics_presets.gd` (`of()`, `apply_choices`, cómo se traduce `settings.values.quality` a índice, ORDER frente a índice directo, `count()`). `presentation_rig.apply_settings()`: lo que VISION_LOCUST.md:144-146 dice que apaga (SSAO, SSIL, glow, niebla, sombras, TAA, FXAA).
11. **El modelo y su esqueleto.** `assets/enemies/locust.glb` no se ha abierto: nombres exactos de huesos (solo los que el código pide), número de mallas, texturas, escala real.
12. **Perfil de sonido.** `game/audio/profiles/locust.tres` (contenido).
13. **Shaders en Compatibility.** Solo Forward+ está probado (VISION_LOCUST.md:156). `echo_field` y `echo_points` tienen ramas para Compatibility (`CURRENT_RENDERER`), pero no se han compilado.
14. **Configuración del proyecto.** `project.godot`: `physics_ticks_per_second` (la cifra 60 de echo_view.gd:668 asume 60), `max_fps`, y el orden de nodos en la escena principal.
15. **Orden de física entre cuerpos.** Dónde se fija el orden en que se mueven criaturas y supervivientes, y si el `_physics_process` de la criatura ve posiciones del mismo paso.
16. **Pruebas.** Los asertos internos de `tests/hotel/echo_test.gd`, `creature_contract_test.gd`, `difficulty_test.gd`, `observer_test.gd`, `stages_test.gd`, `survival_test.gd`, `tests/office/lurker_fairness_test.gd`, y `manifest_golden_test.gd`. Solo se han visto sus nombres de función y el recuento de referencias.
17. **Herramientas.** Ningún archivo de `tools/` se ha leído; solo se han visto sus nombres.
18. **docs/** citados en comentarios y no leídos: docs/OFICINAS.md (11.1, 11.5, 11.6), docs/EXECUTION.md (13.3), docs/DEVELOPMENT.md (qué sigue leyendo a The Locust), docs/PERFORMANCE.md (sección 10).
19. **Red.** Cómo se envía `pack_state` (la frecuencia real y el tamaño), y las rutas RPC de `match_net` (`creature_call` argumentos exactos).
20. **Orden de `_ready` entre el visual y la criatura.** Lo supone Godot (hijos antes que el padre); no comprobado en el proyecto.
21. **Medidas de la cadencia real.** Que `write_rate` y `MEMORY` 9 s cuadren con la memoria del búfer (echo_view.gd:985) en la práctica, no solo en el código.
22. **La cadena de cámara del cazador.** `place_shoulder` y `arm.margin` 0,2 (locust_player.gd:105) en el caso real.
23. **tools/trailer3d/web/engine/locust.js.** Parece ser una reimplementación en JavaScript para tráileres. No se ha leído ni comparado.
24. **Lo que la criatura hace en el piso 1 y el piso 2** (la regla "el piso 1 no cambia" de CLAUDE.md): no se ha comprobado a qué piso pertenece cada cifra. Esta ficha no lo afirma.
