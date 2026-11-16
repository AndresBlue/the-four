# Ficha de hechos: Versus con un jugador como The Locust (piso 1)

Lectura de solo lectura, 16 de noviembre de 2026. Rutas relativas a la raíz del repositorio, con línea. Donde algo no aparece en el código se escribe «no encontrado». Lo que dice un comentario del código se marca como comentario. Fuentes principales: game/net/net_session.gd, game/net/match_net.gd, game/floors/match_rules.gd, game/enemies/creature.gd, game/enemies/locust/hotel_locust.gd, game/enemies/locust/locust_player.gd, game/enemies/locust/echo_view.gd, game/enemies/locust/shaders/, game/app/presentation_rig.gd, game/app/hotel_main.gd, game/app/executions.gd, game/app/lifts.gd, game/services/game_session.gd, game/services/run_score.gd, game/app/run_ledger.gd, game/ui/hotel_ui.gd, game/ui/rules_screen.gd, game/floors/hotel_floor.gd, game/floors/difficulty.gd, game/floors/floor_index.gd, game/services/settings_service.gd, game/player/pad_feel.gd, game/enemies/lurker/lurker.gd, game/audio/world_audio.gd, game/director/pacing_director.gd, game/app/revival.gd, game/net/remote_player.gd, tests/net/net_test.gd, tests/hotel/echo_test.gd, tests/hotel/rules_test.gd, tests/hotel/creature_contract_test.gd, tools/net_test.ps1, tools/verify.ps1, docs/OFICINAS.md.

---

## 0. En corto

- Versus es una partida de un jugador contra hasta cinco supervivientes, en el piso 1. El cazador es una persona que maneja la misma clase que la IA (game/enemies/locust/hotel_locust.gd:1) con un nodo hijo que lee su entrada (locust_player.gd).
- El piso 1 es el único liberado: `RELEASED := [1]` (game/floors/floor_index.gd:16).
- Ve de dos maneras según la regla «Vista del cazador» (`plain_sight`): lectura acústica (por defecto) o cámara normal.
- Cámara en tercera persona por encima del hombro, brazo de 2,8 m, FOV 74 (locust_player.gd:44-118).
- Golpe: clic izquierdo o gatillo derecho. Carga de 0,3 s, enfriamiento de 1,2 s. El host decide a quién alcanza (match_net.gd:829-858).
- Chillido: clic derecho o gatillo izquierdo. Enfriamiento de 10 s. Durante 4 s el host marca a los supervivientes que se mueven (match_net.gd:875-921).
- Sin salto y sin luz propia. Corre con Shift o con el clic del stick. La resistencia dura unos 15 s corriendo.

## 1. Sala, modo y elección del cazador

| Dato | Valor | Dónde |
|---|---|---|
| Modos | `enum Mode { COOP, VERSUS }`; nombres «Coop. vs IA» y «Versus» | net_session.gd:43-44 |
| Quién elige el modo | Solo el anfitrión, con «Tipo de partida» | hotel_ui.gd:1054; set_option net_session.gd:368-378 |
| Quién es el cazador | «Al azar» (`RANDOM` = 0) o un asiento conectado | hotel_ui.gd:1066-1072; net_session.gd:45-46 |
| Sorteo | Cada vez que empieza una partida, si es RANDOM: `seats[randi() % seats.size()]` entre los conectados (net_session.gd:413-415). «No encontrado» código de rotación entre partidas | net_session.gd:413-415 |
| Cazador elegido desconectado | Bloquea el inicio: «El jugador elegido como The Locust ya no está.» | net_session.gd:401-402 |
| Mínimo | `MIN_PLAYERS` = 2 (un superviviente y el cazador) | net_session.gd:37; start_problem 396-400 |
| Máximo en Versus | `MAX_PLAYERS` = 6: `MAX_SURVIVORS` = 5 más el cazador | net_session.gd:30-31; seats_for 405-407 |
| Máximo en Coop | 5 asientos | net_session.gd:405-407 |
| Observadores | `OBSERVERS` = 2 plazas sin asiento; ENet admite `MAX_PLAYERS - 1 + OBSERVERS` pares | net_session.gd:36, 110 |
| Sala llena | «La sala está llena (máximo 6 jugadores).» | net_session.gd:318-319 |
| Protocolo | `PROTOCOL := "the-four-net-22"` | net_session.gd:39 |
| Dificultad de la criatura en Versus | Siempre `REFERENCE` (desafiante). El selector de dificultad solo sale en Coop | net_session.gd:431; hotel_ui.gd:1057 |

### 1.1 Por qué Versus fuerza el piso 1 y qué lo supone
- Línea que lo fuerza: net_session.gd:376-377. Comentario literal: «Versus is the hotel's only, until floor 2 has its own (phase 4).»
- Lo que lo supone:
  - El piso 2 está construido pero no liberado: `KINDS` tiene 1 y 2 (floor_index.gd:7-10), `RELEASED := [1]` (16), `released()` (30-31).
  - La rama `"player"` solo existe en la criatura del piso 1: `set_control` de hotel_locust.gd:1218-1221. La criatura del piso 2 (lurker.gd:541-555) solo tiene `"ai"` y `"puppet"`, y no hay `lurker_player.gd` en game/enemies/lurker/.
  - Las reglas de la criatura son de `&"locust"` (match_rules.gd:42, 44, 46).
  - Descender tras ganar: `ui.descend` excluye Versus (hotel_main.gd:1259-1260).
  - Los logros de Versus están en el piso 1 (hotel_floor.gd:69-70). La UI solo ofrece el selector de piso en Coop (hotel_ui.gd:1057-1063). `set_option("floor", 2)` no mira el modo (net_session.gd:373): la protección vive en la UI y en la reasignación de `floor = 1` al cambiar a Versus (377).

## 2. El jugador-criatura: cuerpo, control, cámara

### 2.1 Mismo cuerpo, otro control
- Clase: `hotel_locust.gd` extiende `creature.gd` (hotel_locust.gd:1; creature.gd:1 `extends CharacterBody3D`). No hay clase distinta para el jugador. El Driver mueve el cuerpo con `move_and_slide()` (locust_player.gd:201, 220).
- `control` es un String (creature.gd:47-50): `"ai"` (cerebro propio), `"puppet"` (sigue el estado que envía la máquina que manda) o `"player"` (lo maneja una persona).
- `set_control("player")` crea el nodo hijo `Driver` (locust_player.gd, `extends Node`) la primera vez y llama `driver.setup(self)` (hotel_locust.gd:1218-1221).
- `_physics_process` (hotel_locust.gd:1565-1586): `"puppet"` → `follow_state` (1571-1573); `"player"` → `driver.drive(delta)` y `update_voice` (1574-1577); `"ai"` → su cerebro.
- Lo compartido: `set_mode` (927-958), voz (grunt, cry, howl, 516-643), `update_wardrobe` (1500-1511), `update_execution` (1518-1535), `validate_strike` (2247-2259), `pack_state`/`push_state` (1229-1250) y la tabla de dificultad.
- Lo que solo hace la IA: `hear()` (773-774: `if control != "ai": return`), `investigate()` (920-921), `lead_to()` (811-812), `aimed_at_local()` (561-562), el director (pacing_director.gd:51-53: «never in versus»), el cerebro de búsqueda y las emboscadas.

### 2.2 Entrada
| Acción | Teclado y ratón | Mando | Dónde |
|---|---|---|---|
| Mirar | Ratón con la sensibilidad de los ajustes; invertir Y | Stick derecho (`pad.look`) | locust_player.gd:134-136, 150, 155-160 |
| Andar | W A S D (`left`, `right`, `forward`, `backward`) | Stick izquierdo | locust_player.gd:179; settings_service.gd:7 |
| Correr (caza) | Shift (`sprint`) | Clic del stick izquierdo; con `pad_sprint_toggle` queda enganchado | locust_player.gd:184; pad_feel.gd:55-70; settings_service.gd:19 |
| Golpe | Clic izquierdo | Gatillo derecho (`locust_strike`, umbral 0,5) | locust_player.gd:137-138; settings_service.gd:32-33 |
| Chillido | Clic derecho | Gatillo izquierdo (`locust_shriek`) | locust_player.gd:139; settings_service.gd:32 |
| Rastro a tele | Q (`locust_trace`) | Botón Y (`flashlight`) | settings_service.gd:7; locust_player.gd:131-132, 173 |
| Interactuar | E (`interact`) | Botón X | locust_player.gd:236; settings_service.gd:19 |
| Salto | No existe: no hay acción `jump` en locust_player.gd | | «no encontrado» |

- Los gatillos son acciones del InputMap solo con mando (settings_service.gd:374-378). Con ratón, golpe y chillido se leen en `_unhandled_input` (locust_player.gd:127-139).
- `can_act()` exige `active`, `control == "player"`, sesión en `PLAYING` y que no haya menú online (locust_player.gd:141-142).

### 2.3 Velocidad, resistencia, gravedad
Constantes de locust_player.gd: `WALK_SPEED` 2,8 m/s (15); `HUNT_SPEED` 6,4 m/s (16); `STAMINA_DRAIN` 6,5/s (19); `STAMINA_RECOVERY` 22/s (20); `RECOVERY_DELAY` 0,6 s (21); `FRENZY_TIME` 6,0 s y `FRENZY_STAMINA` 30 (23-24).
- Sin movimiento mientras `creature.grace > 0`: `free` (178).
- Caza = correr: `hunting = free and axis > 0,1 and sprint and (stamina > 0 or free_hunt)` (184). `free_hunt` es verdadero con frenesí, con apagón o con `onslaught` = 1 (183). Con `free_hunt` no se gasta resistencia (187).
- Correr pone el modo `CHASE`; andar, `PATROL` (221-225). `activity()` devuelve a los demás sistemas `chase` o `roam` (hotel_locust.gd:2162, 2172).
- Velocidad hacia la deseada, con `CHASE_ACCELERATION` 3,2 (hotel_locust.gd:239) si sube y 9,0 si baja (locust_player.gd:215).
- Vertical: `velocity.y = -2` en el suelo, si no `velocity.y - 20·delta` (219). Cabeceo entre −1,1 y 0,6 rad (150).
- Puertas: al andar contra una cerrada la abre, a 2,4 m si corre y a 1,8 m si anda (open_doors 302-313; 229).
- En EXECUTE o WARDROBE el cuerpo no gira con el ratón (locust_player.gd:148-149).

### 2.4 Cámara
| Qué | Valor | Línea |
|---|---|---|
| Pivote en la cabeza | `EYE` (0; 2,35; 0) | locust_player.gd:44, 98 |
| Brazo de muelle | `ARM` 2,8 m | 45, 101 |
| Hombro | `SHOULDER` 1,0 m a un lado | 48, 106 |
| Máscara del brazo | 1 | 8 | 128; el cuerpo excluido | 104, 110 |
| Margen y esfera | margen 0,2; esfera de radio 0,2 | 105, 107-109 |
| Cámara | `HunterCamera`, FOV 74, plano lejano 240 | 113-118 |
| Hombro contra paredes | Rayo lateral que mete el hombro si hay pared | 291-299 |
| Cámara activa | Se apaga la del superviviente y se enciende la del cazador | hotel_main.gd:1080-1083 |

- Mirada de la cabeza: `visual.look_point = camera.global_position - camera.global_basis.z * 10` (locust_player.gd:232).
- Cuerpo visible en la cámara: «no encontrado» ningún `visible = false` del cuerpo del cazador en hotel_locust.gd ni en locust_visual.gd. Con la lectura acústica el cuerpo se pinta con `self_material` (echo_view.gd:621-627) y al apagarla se restaura (629-638).

### 2.5 Interactuar (E): `use()` (locust_player.gd:439-463), por orden
1. Canales de tele abiertos: `locust_warp(channel_target)` y se cierran (441-443).
2. Rayo de la cámara de 6,0 m (ARM + 3,2, línea 445):
   - puerta a menos de 3,4 m de su marco: `use_door(door, false, false)` (451-452);
   - armario a menos de 3,4 m (`WARDROBE_REACH` 2,6 + 0,8, línea 453): `begin_wardrobe` y `locust_open_hide` (455-456).
3. Si no mira nada y `tv_travel` = 1, está en una tele y hay más de una encendida: abre canales (461-463).

## 3. La vista de la cazadora

### 3.1 Dos lecturas según la regla «Vista del cazador»
- Regla `plain_sight` (match_rules.gd:46-47): 0 «Lectura acústica» (por defecto), 1 «Ve como una persona».
- Eco: `if kind == "player" and level.rule("plain_sight") == 0: driver.echo.enable()`; si no, `disable()` (hotel_locust.gd:1222-1226).
- Qué pinta la máquina (presentation_rig.gd:187-196):
  - `hunter_seat()`: este equipo maneja al cazador (o el observador mirando con el eco);
  - `echo_seat()`: `hunter_seat()` y (observador o `plain_sight` = 0).
- Con `echo_seat()` (presentation_rig.gd:222-306): sin SSAO (223), SSIL (228), SSR (230), brillo (236), luz ambiente a 0 (242), niebla (243-244), TAA (277), antialias (273) y tinte a `Vector3.ONE` (308). La lente se quita (300-305).
- Con `plain_sight` = 1, `echo_seat()` es falso: vuelven esos efectos y el eco se apaga (hotel_locust.gd:1225-1226). El cazador no oye su presencia ni el «dread» (`world_audio.set_creature(null)`, hotel_main.gd:1084-1085).

### 3.2 Cómo está hecha la lectura acústica
- Tres capas en una imagen (echo_view.gd:1-23): «la oscuridad» (un pase de pantalla sobre el búfer de profundidad), «los granos» (puntos estampados en cada clic) y «el propio cuerpo».
- Shader de pantalla `echo_field.gdshader` (con `echo_points.gdshader` y `echo_self.gdshader`):
  - pared: `colour = mix(vec3(0.74, 0.79, 0.82), vec3(1.35, 0.05, 0.02), shriek) * presence / (1.0 + eye_distance * 0.35)` (línea 80-81): gris-blanco que se apaga con la distancia, rojo con el chillido;
  - haz de linterna: `beam_origin`, `beam_axis`, color `vec3(0.9, 0.93, 1.0)` (39-41, 88-117);
  - grano de fondo `speck` (121-122); salida `ALBEDO` (124).
- Constantes de echo_view.gd: `CLICK_RATE` 2,0/s (37); `CLICK_JITTER` 0,22 (42); `BREATH_RATE` 0,14 (43); `BREATH_DEPTH` 0,25 (44); `REACH` 40 m por rayo (51); `MEMORY` 9,0 s (53); `FIND_LIFE` 3,2 s (124); `CONTACT_LIFE` 1,6 s (126); `SHRIEK_HOLD` 4,0 (128); `SHRIEK_RISE` 6,0 (129); `SHRIEK_FALL` 0,55 (130); `LANDMARK_NEAR` 14 y `LANDMARK_REACH` 28 (133-134); `POINT_PIXELS` 2,0 (143); `PRESENCE` 0,006 (148).
- El ritmo no cambia al cazar (comentario de echo_view.gd:39, «It does NOT speed up while hunting»; `click()` recibe `hunting` y no lo usa, 735-752). Un clic: intervalo `1/CLICK_RATE` con jitter y «respiración»; reparte rayos (`start_spray`); `aim_reflectors` lanza rayos propios a puertas y armarios; `stamp_bodies` en cada clic (`BODY_EVERY` = 1, línea 61).
- Cuerpos de supervivientes: solo si `creature.sees(body)` (echo_view.gd:837). `sees()` (hotel_locust.gd:651-665) usa:
  - alcance `sight_range * reach_scale` (desafiante: 70 m, difficulty.gd:115);
  - cono `sight_half_angle` (desafiante: 60°, difficulty.gd:126; const `SIGHT_HALF_ANGLE` 60 en hotel_locust.gd:174), salvo a menos de 1,5 m;
  - línea de visión desde los ojos a 2,4 m (`EYE_HEIGHT`, hotel_locust.gd:257; `clear_sight` 646-649);
  - escondido: solo con el armario entreabierto (660-661).
- Ruidos: `hunter_contact` → `driver.heard` (locust_player.gd:467-476). Cada uno guarda `point`, `apparent`, `distance`, `muffle`, `blur` y `kind`. Hasta 8 m (`CONTACT_TRUTH`, línea 52) pinta el sitio real; desde 14 m (`CONTACT_BLUR`, línea 53) pinta la abertura por la que llega; entre los dos se desliza (470). Caducan a 1,6 s (239).
- Nubes por clase de ruido: `PUFF_DENSITY`, `PUFF_SIZE`, `PUFF_LIVES`, `PUFF_BELLS` (echo_view.gd:81-87).
- Puertas y armarios de su planta: `build_landmarks()` recorre `level.hotel.doors` y `level.hotel.hides` (echo_view.gd:475-560) y se rehace al cambiar de planta (715).
- Sets encendidos: `lit_screens()` (locust_player.gd:406-412) → `lay_screen` en amarillo (echo_view.gd:1024-1028, 1100-1116; `GUIDE_YELLOW` (1,5; 1,05; 0,03), línea 241).
- Camino al coche en azul: `lift_route()` (locust_player.gd:346-349) → `GUIDE_BLUE` (echo_view.gd:240).
- Camino de Q en amarillo: `trace_route()` (locust_player.gd:396-402).
- Zumbido de lámparas: `bloom_hums()` (echo_view.gd:999-1012; `HUM_LEVEL` 0,13, línea 179), no luz. Efectos reducidos (`apply_quality`, 645-683): sin temblor ni grano (677-678).
- Sonido del mundo con `hunter_ears()` (world_audio.gd:54-55): supervivientes +8 dB (`HUNTER_PREY_DB`, línea 51); aire que pierde menos (`HUNTER_AIR` 0,4, línea 52); su propio cuerpo −12 dB (`HUNTER_OWN_DB`, línea 53). Pasos de supervivientes: alcance 40 m frente a 26 m (remote_player.gd:297-298).

### 3.3 Qué datos usa la lectura y de dónde salen
| Dato | Quién lo calcula | Cómo llega al cazador |
|---|---|---|
| Supervivientes en vista | La máquina del cazador, con `creature.sees()` | Como cuerpos, solo si la visión lo permite |
| Ruidos | El host: `locust_hear` (hotel_main.gd:1148-1162) con `hear_route` (hotel_locust.gd:732-770) | `tell_hunter` (match_net.gd:931-937) → `heard_contact` (938-940; unreliable, authority) → `hunter_contact` (hotel_locust.gd:2267-2268) |
| Chillido | El host: `update_shriek` (match_net.gd:899-921) | `shriek_reveal` (923-925; unreliable) → `hunter_reveal` (hotel_locust.gd:2264-2265) |
| Puertas, armarios, sets, rutas | El manifiesto del piso y la navegación | Los tiene la máquina del cazador; no se envían |

- `hear_route` usa `hearing`, `reach_scale` y `dull` (hotel_locust.gd:736-737). El director baja `dull` para la IA, pero en Versus no corre (pacing_director.gd:51-53).

## 4. Captura por el jugador-criatura

### 4.1 Secuencia en la máquina del cazador
1. Clic izquierdo o gatillo derecho → `strike()` (locust_player.gd:315-321). Guardas: `cooldown` = 0, `grace` = 0 y modo fuera de WINDUP, RECOVER, EXECUTE y WARDROBE (318). Enfriamiento `COOLDOWN` 1,2 s (26, 319).
2. `set_mode(WINDUP)` (321): `warn()` local (hotel_locust.gd:956-958, 457-473) y `creature_call("warning", 0, 1.0)` a todos.
3. WINDUP (`creature.WINDUP_TIME` = 0,3 s, hotel_locust.gd:254): avanza a `HUNT_SPEED × 1,15` = 7,36 m/s con `velocity.y = -2` (locust_player.gd:199-201).
4. A los 0,3 s: `locust_strike(global_position, -global_basis.z)` (202-204); si sigue en WINDUP pasa a RECOVER (207).
5. RECOVER dura `creature.RECOVER_TIME` = 0,6 s (hotel_locust.gd:255; locust_player.gd:210). Es constante: no usa `recover_time`, que la dificultad sí cambia (hotel_locust.gd:35, 91).
6. Al acabar RECOVER: CHASE si corre, PATROL si no (210).

### 4.2 Autoridad: el host juzga
- `locust_strike` (match_net.gd:829-831): si esta máquina manda (`in_charge()`), `resolve_strike` directo; si no, `strike.rpc_id(1, origin, facing)` (reliable, any_peer, 833-836).
- `strike` del host (833-836): solo acepta el peer del cazador (`locust_peer()`) y solo en versus.
- `resolve_strike` (841-844): sale si no hay criatura o `grace > 0`; si no, `level.capture_survivor(strike_victim(origin, facing))`.
- `strike_victim` (848-858): de los supervivientes activos, el más cercano al que `validate_strike` da distancia finita.
- `validate_strike` (hotel_locust.gd:2247-2259):
  - si el origen está a más de 3,0 m de la criatura del host, se usa la posición del host (2248);
  - alcance `STRIKE_REACH` 3,2 m (250, 2253);
  - a más de 0,8 m, cono de 70° respecto a su mirada (`STRIKE_ANGLE`, 253-254);
  - escondido sin armario abierto: no (2255);
  - rayo desde los ojos (2,4 m) a la cámara del superviviente, máscara `1 | 8 | 64` (2256-2258).
- `capture_survivor` (executions.gd:179-197) exige: superviviente en `EXPLORING`; no en un ascensor (`lifts.riding`); no en sala protegida (`point_protected`); `may_capture` = true (creature.gd:340); `capture_style()` no nulo (hotel_locust.gd:2216-2217, locust_capture.gd).
- Aviso de espalda: `cue_of` = -1 (creature.gd:344). La criatura del hotel no tiene aviso de espalda.
- `stage_capture` (executions.gd:201-232) fija entrada, lado, caída, mirada, armario y linterna.
- `execute_start` (match_net.gd:983-985; authority, reliable) lo aplica en todas las máquinas con `apply_execution` (executions.gd:261).
- En la criatura: `begin_capture` → `begin_execution()` (hotel_locust.gd:2221-2222, 1514-1516): modo EXECUTE, velocidad 0.
- Duración: `EXECUTION_TIME` 4,7 s (274); se suelta en `EXECUTION_TIME + 0,35` (1525) y pasa a PATROL en el cazador (1535). `EXECUTION_KILL` 3,3 s (275) existe como constante.

### 4.3 Armario
- E sobre un armario (locust_player.gd:452-456): `begin_wardrobe(target)` local y `locust_open_hide` → host `request_force` (match_net.gd:862-872), que exige el peer del cazador y distancia menor de `REACH` (5 m) a la criatura del host.
- Pasos (`wardrobe_steps`, hotel_locust.gd:171-173): estallido 0,55 s; alcance 0,70 s (estallido + 0,15); fin 1,7 s (`WARDROBE_TIME`, línea 270), escalados por la dificultad.

### 4.4 Lo que ve cada lado
- Cazador: el golpe en su lectura o su vista. Superviviente: la ejecución en el aire (`apply_execution`) y su cinta (`death_tape.gd`). Sobresalto en Versus: «no encontrado».

## 5. Habilidades y recursos de la criatura jugada

| Habilidad | Entrada | Valores | Enfriamiento | Dónde |
|---|---|---|---|---|
| Golpe | Clic izq. / RT | Carga 0,3 s; avance 7,36 m/s; recuperación 0,6 s; alcance 3,2 m; cono 70° | 1,2 s desde que se usa | locust_player.gd:26, 199-210, 318-319; hotel_locust.gd:250-255 |
| Chillido | Clic der. / LT | Aullido 4,0 s + caída 1,818 s (1/0,55); el host escucha 4,0 s (`SHRIEK_TIME`) a 5 Hz con 26 m × `sense_scale` | 10 s desde que se usa | locust_player.gd:30, 326-335; match_net.gd:819-821, 875-921 |
| Frenesí | Automático si el chillido encuentra a alguien | 6 s de caza libre y +30 de resistencia | Ninguno propio | locust_player.gd:23-24, 427-436 |
| Rastro (Q) | Q / botón Y | 15 s de ruta amarilla hasta una tele encendida alcanzable | 20 s desde que se pide | locust_player.gd:34-35, 358-402 |
| Viajar por teles | E con canales abiertos | Con `tv_travel` = 1 y dos o más encendidas | «no encontrado» enfriamiento propio | locust_player.gd:439-463; match_net.gd:516-541 |
| Armario | E | Estallido 0,55 s; alcance 0,70 s; fin 1,7 s | Ninguno | hotel_locust.gd:171-173, 270 |
| Puertas | Caminar o E | Abre a 2,4 m (corre) o 1,8 m (anda) | Ninguno | locust_player.gd:302-313, 451 |
| Ascensor | Entrar al coche | El host lo sube si `creature_may_ride` | Espera de 15 s en desafiante (`lift_wait`) | lifts.gd:93-95, 176-195; difficulty.gd:119 |

- Resistencia: máximo 100; gasta 6,5/s corriendo; se recarga a 22/s tras 0,6 s sin correr (locust_player.gd:19-21, 184-191).
- Gracia de inicio: 15 s (desafiante, difficulty.gd:119). Durante la gracia no hay movimiento, golpe ni chillido (178, 318, 327). Al acabar suena el grito de caza (hotel_locust.gd:555-559).
- Regla `onslaught` (Embestida): alcance × 1,25 y no afloja al perder de vista (hotel_locust.gd:13, 2480-2482; locust_player.gd:183).
- No tiene salto, linterna, luz propia (no apaga salas ni baja luces) ni habilidades del Lurker. Con apagón, `mark_blackout()` pinta las paredes de golpe (locust_player.gd:417-424).

## 6. Red: qué se replica y cómo

### 6.1 Mensajes (match_net.gd)
| Mensaje | Tipo | Quién lo envía | Frecuencia | Qué lleva | Línea |
|---|---|---|---|---|---|
| `locust_state` | unreliable_ordered, any_peer | La máquina que la controla (si no es puppet) | 20 Hz (`SEND_RATE`, línea 23; envío 278, 281-283) | `pack_state()`: posición, giro Y, velocidad, `mode` (entero), gracia y mirada | 342-354; hotel_locust.gd:1229-1230 |
| `locust_call` | reliable, any_peer | El peer del cazador o el host | Por evento | `kind`, `segment`, `pitch`: «warning», «grunt», «cry», «howl», «doubt», «lost» | 803-813 |
| `strike` | reliable, any_peer | Cazador (si es invitado) | Por golpe | origen y mirada | 833-836 |
| `request_shriek` | reliable, any_peer | Cazador | Por chillido | nada | 880-886 |
| `shriek_reveal` | unreliable, authority | Host | 5 Hz durante 4 s | puntos de supervivientes | 923-925 |
| `heard_contact` | unreliable, authority | Host | Por ruido | punto, aparente, distancia, fuerza, clase, amortiguación | 938-940 |
| `request_force` | reliable, any_peer | Cazador | Por armario | índice | 867-872 |
| `request_warp` / `warp_state` | reliable | Cazador / host | Por viaje | índice de tele | 525-541 |
| `request_door` / `door_swung` | reliable | Cualquiera / host | Por puerta | índice, sentido | 393-403 |
| `locust_ride` / `locust_rode` | reliable, authority | Host | Al subir al coche | punto de llegada | 668-674 |
| `execute_start` | reliable, authority | Host | Por captura | superviviente, punto, giro, datos | 983-985 |
| `player_noise` | unreliable, any_peer | Supervivientes invitados | Por ruido | punto, radio, clase | 764-766 |
| `creature_event_rpc` | reliable, any_peer | Cazador o host | Por evento | `kind`, `data` | 793-800. El Locust no implementa `on_event` (creature.gd:274 es `pass`) |

- Relay: el host reenvía estado y llamadas del cazador a los demás (`relay`, match_net.gd:297-300; 352; 811).
- Frecuencia: creature.gd:263 dice «What the machine in charge sends about fifteen times a second», pero el envío real es a `SEND_RATE` 20 (match_net.gd:23, 278).

### 6.2 Autoridad
- Simula el cazador (su máquina): movimiento, mirada, modos WINDUP y RECOVER, llamadas y lectura.
- Juzga el host: golpes (`resolve_strike`), capturas, puertas, armarios, teles, ascensor, ruidos (`locust_hear` solo en el host, hotel_main.gd:1154) y chillido (`update_shriek`). Su copia pasa a `puppet` mientras el cazador manda (match_net.gd:350).
- El host acepta `locust_state` solo del peer del cazador (346-348). No compara la posición con nada: «no encontrado» validación de posición.
- El host no comprueba enfriamientos: `resolve_strike` mira solo la gracia (841-844) y `request_shriek` no mira nada (881-886). El enfriamiento vive solo en la máquina del cazador (locust_player.gd:318, 327).
- En puppet, `push_state` asigna `mode` directamente (hotel_locust.gd:1244-1247) y no pasa por `set_mode`: el aviso y el grito que `set_mode` dispara en la máquina del cazador no suenan ahí; llegan por `locust_call`.
- Interpolación: estados de hace 0,1 s (`net_clock - 0.1`, hotel_locust.gd:1259), buffer de 10 (1243) y ejecución fijada en el punto del host (1274-1277). Ascensor: `ride_hold` de 2 s en puppet descarta estados del coche anterior (1235-1241, 2375-2376).

### 6.3 Caída y reconexión del cazador
- `seat_dropped` (match_net.gd:1121-1133): el asiento del cazador queda en `away` con `RECONNECT_GRACE` 60 s (línea 26). En el host, si la criatura es puppet, pasa a `set_control("ai")` y `hunter_gone()` (1130-1132): la IA del host la toma en SEARCH (hotel_locust.gd:2272-2274).
- A los 60 s: `session.drop(seat)` (match_net.gd:264-266), que no hace nada con el cazador porque `participants` solo tiene supervivientes (game_session.gd:86-87, 150-151).
- `seat_returned` (match_net.gd:1138-1147): envía `begin` a quien vuelve. `restore` (1183-1214) lleva `pack_state()` de la criatura; si quien vuelve es el cazador, `resume_state` (hotel_locust.gd:2237-2241) la deja donde estaba, con su gracia.

## 7. Reglas de la partida versus (game/floors/match_rules.gd)

### 7.1 Con `"versus": true`
- Solo `plain_sight` (match_rules.gd:46). El campo no se lee: `applies()` (58-61) mira `creature` y `kind`, no `versus`. Un grep de `"versus"` en game/, tools/ y tests/ solo encuentra esa línea y el comentario de la línea 23.

### 7.2 Con `"creature": &"locust"`
- `onslaught` «Embestida» (42-43): 0 «No» (por defecto) o 1 «Sí». Ve y oye un 25 % más lejos y no afloja.
- `tv_travel` «Viaja por los televisores» (44-45): 1 «Sí» (por defecto) o 0 «No».
- `plain_sight` «Vista del cazador» (46-47): 0 «Lectura acústica» (por defecto) o 1 «Ve como una persona».

### 7.3 Otras reglas que el piso 1 aplica a la criatura jugada
- `restarts` «Clemencia» (28-29; por defecto BY_DIFFICULTY). En Versus la dificultad REFERENCE da `restarts` = 1 (difficulty.gd:127), aplicado por `apply_tuning` (hotel_main.gd:171-173).
- `sanity` (30-31), `plan` (36-37), `plan_fade` (38-39) y `shared_sheet` (40-41) no son del cazador. `code` (32-33) y `blackout` (34-35) tienen `kind` = 1 (piso 1, el de Versus).

### 7.4 Cómo se muestran
- La pantalla de reglas lista `RULES.shown(CREATURE_KEY, NUMBER)` (rules_screen.gd:31, 37). Como `applies()` no mira el modo, «Vista del cazador» también sale en Coop, donde no tiene efecto (presentation_rig.gd:187-196 necesita un cazador local).

## 8. Cómo gana cada lado, muertos y logros

### 8.1 Partida
- Estados: `State { MENU, LOADING, PLAYING, PAUSED, TRANSITION, WON, FAILED, CUTSCENE }` (game_session.gd:7); `Life { EXPLORING, REFUGE, DEAD }` (8).
- Ganan los supervivientes: al cerrar la última etapa, `set_state(State.WON)` (game_session.gd:337; `update_goal` 123-129; `finish_stage` 132-139).
- Mínimo: `minimum_survivors()` = `max(1, ceil(roster_count / 2))` (game_session.gd:103). `roster_count` cuenta supervivientes; el cazador no entra (net_session.gd:426).
- Gana el cazador: `check_quota()` (game_session.gd:160-193). Si los vivos bajan del mínimo y no quedan reintentos: `message = "No quedan suficientes supervivientes."`, se olvida el punto de guardado y `set_state(State.FAILED)` (191-192).
- Reintentos: `restarts_allowed` (hotel_main.gd:173); en desafiante son 1 (difficulty.gd:127).
- Textos de fin para el cazador (hotel_ui.gd:1133-1136): «CAZA COMPLETA» si pierden los supervivientes; «SE TE ESCAPARON» si ganan. Para los supervivientes: «SALISTE DEL PISO» o «SEÑAL PERDIDA».

### 8.2 Muertos
- Captura o desconexión: `capture(id)` (game_session.gd:143-149) y `drop(id)` (150-155) pasan al superviviente a DEAD y llaman a `check_quota()`.
- Muerto en línea: `watch_teammates()` (revival.gd:243-246) mira por la cámara de un compañero vivo; `watch_over` (267).
- Revivir tras perder una etapa: `on_revived` (revival.gd:20); la criatura va a un lugar lejano con `relocate_creature` (95-100). Comentario (87-90): un cazador «cannot strike, shriek or trace while that lasts».
- El cazador no puede morir: «no encontrado» estado de muerte para la criatura jugada.

### 8.3 Logros y fichas de Versus
- `hotel_floor.gd:69` «hunted», «A SALVO DEL CAZADOR»: «Salir con un jugador haciendo de The Locust.» Regla `versus_out`.
- `hotel_floor.gd:70` «hunter», «CAZA COMPLETA»: «Como The Locust, no dejar salir a nadie.» Regla `hunter_won`.
- `run_score.gd:224-248` (`meets`): `hunter_won` (229) exige versus, partida no ganada, y que el asiento consultado sea el del cazador (no el 0); `versus_out` (247) exige versus y escapar.
- Excluyen Versus: `solo` (237), `unseen` (244) y `FANTASMA` (182). `mvp` (243) exige más de un jugador.
- Cinta de Versus (run_ledger.gd:349-371): `mode` «versus» (353), `company` `RECORDS.VERSUS` (354), `hunter` = {seat, name} (370).
- Persecuciones del cazador: `follow_hunt` (run_ledger.gd:257-273) cuenta «chases» solo con `creature.control == "ai"`. La criatura jugada no suma persecuciones.
- Tablón: `records_service.gd:28` (`VERSUS := "versus"`) y `:33` («CONTRA EL CAZADOR»).
- Cinta: en Versus no sale la dificultad (tape_report.gd:51). Línea del cazador en la cinta: tape_report.gd:223-227.

## 9. Pruebas que cubren Versus

### 9.1 Red (procesos reales en 127.0.0.1)
- `tools/verify.ps1:120-124`: escenario `versus`, puerto 24610, lanza `tools/net_test.ps1 -Scenario versus`.
- `tools/net_test.ps1`: parámetro `Scenario` con `versus` (línea 1); roles `vs_host` y `vs_hunter` (línea 12).
- `tests/net/net_test.gd`:
  - `versus_host()` (671-728) comprueba: la sala versus se abre; llega el cazador; se elige quién es The Locust; empieza el versus; en el host la criatura es una réplica (`control == "puppet"`); solo el host es superviviente; llega el movimiento; termina la gracia; llegan los gruñidos de caza (`last_call == "grunt"`); oye el chillido (`"howl"`); las teles encendidas llegan; el cazador viaja por ellas; el superviviente se esconde; el armario se abre de golpe; lo saca y lo ejecuta en el aire; cae; con un solo superviviente el piso acaba en FAILED sin reintentos.
  - `versus_hunter()` (730-806) comprueba: el cazador se conecta y entra; `control == "player"`, driver y cámara activa; su jugador no cuenta como superviviente; correr sin nadie no hace gruñir (`calls_made == 0`); correr hacia alguien que ve, sí; los ruidos llegan como contactos con clase y metros de ruta; el chillido revela a quien se mueve; la nube dura (`finds_written > 0`); el camino al coche sin que se lo manden (`guide_routes.lift > 1`); las teles brillan; reconoce la tele en la que está y sale por la otra; el chillido da caza libre (`frenzy > 0`); el superviviente se mete en el armario, que se abre con `locust_open_hide`; el piso acaba en FAILED en `online_failed`; la caza queda en la ficha del cazador (`career.hunts`, `hunts_won` y el hito `hunter`).
- Medición de latencia o de reconexión del cazador: «no encontrado».

### 9.2 Lectura acústica y reglas (un proceso, sin GPU)
- `tests/hotel/echo_test.gd`: cadencia de pulsos (85-88); presupuesto de rayos entre fotogramas (98-99); anillo de puntos dentro de presupuesto (101-103); cuerpo visible solo con `sees()` (119-132); ruidos cercanos pintados donde ocurren y lejanos pintados por la abertura (141-158); clases de ruido (169-186); armario oído desde otra habitación (215); camino al coche en azul (226-230); chillido rojo y su duración (325-338); enfriamiento de 10 s (348); rastro: 20 s de enfriamiento y 15 s de duración (239-265); efectos reducidos (458).
- `tests/hotel/rules_test.gd`: reglas por criatura (51-56); embestida (113-119); `plain_sight` y `echo_seat` (121-127); `tv_travel` (145-156).
- `tests/hotel/creature_contract_test.gd`: `hunter(it)` (1842-1886) prueba el cazador con un Driver falso (`hunter_reveal`, `hunter_contact`, `sense_scale`, `hunter_gone`); copia en Versus (1386); canales del cazador al subir al coche, entrar en una tele y devolver una etapa (620-640, 834-900); lista de métodos que llaman la red y otros sistemas (1596).
- `tests/hotel/creature_test.gd:148` (gracia y grito) y `tests/hotel/stages_test.gd:424` (cruce del cazador por el ascensor, no leído en detalle) solo lo mencionan.

### 9.3 Sin prueba automática
- `--bots-hunt` (hotel_main.gd:397-416): el jugador es el cazador contra bots, sin conexión. `tools/bots/bot_watch.gd` lo menciona.
- `--locust` (hotel_main.gd:378, 526-533): vista del cazador contra un superviviente parado.
- `tools/dev/check_shaders.gd` (con ventana, verify.ps1:115). `tools/capture/echo_capture.gd` (imagen revisada a ojo, echo_test.gd:6-7), `tools/dev/echo_rehearsal.gd` y `tools/capture/online_capture.gd`. Existen; no se leyeron.

## 10. Lo que docs/OFICINAS.md dice del Versus de The Lurker

### 10.1 Sección 7, copia literal (docs/OFICINAS.md:488-505)

> ## 7. Versus: ser The Lurker
>
> - **Su vista**:
>   - **la oscuridad es su luz**: ve lo oscuro en grises granulosos;
>   - lo encendido **la quema**: blanco, sin detalle, con un sonido que molesta;
>   - la linterna de un superviviente es un fogonazo que la ciega si la mira.
>   - Ve a quien sus sentidos le dan (`sees()`), como el eco de The Locust.
> - **Se mueve por cualquier superficie** (suelo, pared, techo, saltando de una a otra) y **entra en los ductos** por las rejillas. Dentro, un plano esquemático de la red y salidas marcadas.
> - **Habilidades:**
>   - **Beber la luz**: apaga una sala ~6 s; espera ~25 s.
>   - **Asomarse**: un susto que baja la cordura de quien la ve.
>   - **Coger**: solo desde detrás de alguien. Lanza el aviso de la espalda y la presa tiene su ventana, la misma que con la IA. Ninguna regla cambia por llevarla una persona.
> - **Con los sistemas de cada planta:**
>   - en la 2, no toca el cuadro, pero bebe la luz de las zonas encendidas;
>   - en la 3, los ventiladores también la echan de los ductos cuando la lleva una persona, y el ruido le quita el oído.
> - Gana y pierde como ahora: CAZA COMPLETA o SE TE ESCAPARON.

### 10.2 Sección 11.6, red y Versus, copia literal (docs/OFICINAS.md:774-776 y 783-788)

> - **Red:**
>   - el estado empaquetado lleva la **orientación entera** (cuaternión) y banderas: en ducto, oculta, superficie, bebiendo luz, avisando;
>   - eventos fiables: aviso, fin de aviso, espanto, entrar y salir de ducto, circuito dado, sala apagada (versus);
>   - el invitado puede reclamar «la estaba mirando» y el anfitrión lo acepta si su propia comprobación coincide con margen.
> - **Versus:**
>   - `lurker_player.gd` (moverse por el parche actual; contra una pared o un techo, se sube);
>   - entrar en un ducto abre el mapa de ductos, reutilizando la brújula de canales de las teles;
>   - `lurker_view.gd`: su vista, con exposición alta, sin color, grano y brillo que quema lo encendido;
>   - peticiones validadas en el anfitrión: coger (siempre con su ventana), ducto, apagar una sala;
>   - `--lurker` para probarlo en local.

### 10.3 Otros puntos de docs/OFICINAS.md que tocan a la criatura de Versus (solo referencia)
- Sección 11.1, fila «Su cazador (versus)» (docs/OFICINAS.md:638): `sense_scale()`, `hunter_reveal()` y `hunter_contact()`, `hunter_gone()`, `apply_quality()`.
- Secciones 4 («Sentidos», 315-321; «La luz», 348-361) y 6 («La captura», 471-487): describen a The Lurker.
- Sección 15, fase 4 (1016-1020): estado y eventos, latencia, reincorporación y protocolo; `lurker_player`, `lurker_view`, mapa de ductos y habilidades; verificación con `office_versus` y `office_late`.
- Comparación de hechos: la sección 7 pide grises granulosos para lo oscuro y blanco para lo encendido. Hoy la lectura de The Locust pinta las paredes en gris-blanco (echo_field.gdshader:80), las pantallas de las teles encendidas en amarillo (echo_view.gd:1100-1116) y la linterna como un resplandor (echo_view.gd:1135-1147). El shader no tiene un color para «fuente eléctrica».

## 11. No encontrado
- Rotación del cazador entre partidas.
- Salto del cazador.
- Rama de control `"player"` para la criatura del piso 2 (lurker.gd:541-555 solo tiene `"ai"` y `"puppet"`).
- Enfriamiento propio de los viajes por teles.
- Ocultación del cuerpo del cazador en su cámara de tercera persona.
- Deslumbramiento o efecto de la linterna de un superviviente sobre el cazador (no hay «blind», «flash», «glare» ni «dazzle» en locust_player.gd, echo_view.gd, presentation_rig.gd ni hotel_locust.gd, salvo el flash del chillido).
- Validación de posición del cazador en el host, y de cadencia de golpes y chillidos.
- Uso de `"versus": true` en ninguna parte.
- Efecto del parámetro `hunting` en `echo_view.click()` (se pasa, no se usa).
- Pruebas de latencia o de reconexión del cazador (net_test.gd prueba el armario, la ejecución y la caza, no la reconexión del cazador).
