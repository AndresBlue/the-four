# Ficha de hechos: The Lurker manejada por la IA (estado actual)

Solo lectura, sin diseño. Cada dato lleva `archivo:línea`. Sin ruta, el archivo está en `game/enemies/lurker/`. Lo que no se leyó se dice.

## 0. Cobertura

- Leídos enteros: `lurker.gd` (1647), `lurker_brain.gd` (1139), `lurker_senses.gd` (508), `lurker_warning.gd` (170), `lurker_motion.gd` (1189), `game/enemies/creature_sight.gd` (170).
- Solo esqueleto (funciones y constantes) más los tramos citados: `lurker_shell.gd`, `lurker_routes.gd`, `duct_graph.gd`, `lurker_voice.gd`, `lurker_visual.gd`, `lurker_limbs.gd`, `ceiling_dust.gd`, `game/enemies/creature.gd` (base, esqueleto completo).
- Leídos en lo que toca: `game/floors/difficulty.gd` (tabla de Lurker), `game/player/hotel_player.gd` (linterna), `docs/OFICINAS.md` 4, 6 y 11.1 (la 1 solo en encabezados), las 11 pruebas `tests/office/lurker_*_test.gd` (encabezado y comprobaciones).
- No leídos: shaders de la carpeta, `lurker.tscn`, `lurker_creature.tscn`, `game/app/capture_styles/lurker_capture.gd`, `match_net.gd`, `tests/hotel/creature_contract_test.gd`.

## 1. Arquitectura y contrato (Q1)

Piezas, todas creadas en `arrive()` (`lurker.gd:208-231`) y `think_setup()` (`:878-890`):

| Pieza | Archivo | Variable (`lurker.gd`) |
|---|---|---|
| Cuerpo | `lurker.gd` (extiende `creature.gd`, `:1`) | — |
| Forma del techo | `lurker_shell.gd` | `shell` (`:58`) |
| Conductos | `duct_graph.gd` | `ducts` (`:59`) |
| Rutas | `lurker_routes.gd` | `routes` (`:60`) |
| Movimiento | `lurker_motion.gd` | `motion` (`:61`) |
| Sentidos | `lurker_senses.gd` | `senses` (`:857`) |
| Cerebro | `lurker_brain.gd` | `brain` (`:858`) |
| Aviso (única vía a una captura) | `lurker_warning.gd` | `warning` (`:860`) |
| Voz | `lurker_voice.gd` | `voice` (`:86`) |
| Visual | nodo `Visual` (`lurker_visual.gd`) | `visual` (`:62`) |

Cómo se hablan:
- Cada tick, `think()` (`:892-913`): `senses.perceive()` da un `Percept` (`:896`), los clics van a `brain.on_heard` (`:898`), `brain.tick()` da la intención (`:902`), y `apply_intent()` la aplica (`:906`, `:936-986`).
- Intención: un diccionario con `do` (`hold`, `pause`, `go`, `duct`/`listen`, `vanish`, `bolt`, `take`, `keep`), `clip`, `look` y sus campos (`to`, `speed`, `hidden`, `exit`, `from`, `seat`, `leap`). Se crea con `brain.intent()` (`lurker_brain.gd:250`).
- `apply_intent` manda cada `do` al movimiento: `hold`→`motion.hold()`, `pause`→`pause()`, `go`→`go_to(to, speed, surface)` (`:963-965`), `duct`/`listen`→`go_to_exit`, `vanish`→`place_in_duct`, `bolt`→`bolt(from)` (`:975-980`), `take`→`leap` o `hold` y luego `level.capture_survivor` (`:981-985`).
- Señales del cerebro: `cue_started`→`match_net.send_cue` (`:885`), `cue_ended`→`send_cue_over` (`:886`), `scared`→`tell("scare")` (`:887`).

Contrato que usa el resto del juego (todo en `lurker.gd`):
- Identidad y control: `kind_id()` `:145` (`&"lurker"`), `can(ability)` `:149` (solo `&"ducts"`), `set_control(kind)` `:233` (`"ai"` o `"puppet"`), `tune(profile)` `:151`, `activity()` `:165`, `mode_name()` `:167`.
- Ubicación: `eye_point()` `:169`, `face_point()` `:171`, `gaze()` `:173`, `teleport(point, yaw, reason)` `:276`, `relocate(point, rest)` `:291`, `follow_to_planta(stage, fresh)` `:300`, `den_point(stage)` `:327`, `start_room(stage)` `:334`.
- Estado: `save_state()` `:338` (`{at, heading, hang, in_duct, near, wing_goal, calm}`), `restore_state(data, rest)` `:351`.
- Tránsito: `in_transit()` `:180`, `transit_phase()` `:184`, `hushed()` `:187`.
- Vista para los demás: `view()` `:382` (`{drop, arriving, leaving, in_duct, hidden, duct_point, near}`), `voice_point()` `:395`, `presence_on()` `:401`, `room_of_point(p)` `:403`.
- Sonido: `sound_route(listener)` `:406`, `sound_route_from` `:418`, `presence_route` `:458`, `presence_sound()` `:1277`, `mood()` `:607`, `beat_now()` `:617`.
- Red: `pack_state()` `:490`, `push_state(data)` `:495`, `follow_state(delta)` `:514`, `flags()` `:473`, `tell(kind, data)` `:1295`, `on_event(kind, data)` `:1300`.
- Percepción: `sees(player, ignore_concealment)` `:1338`, `hear(point, radius)` `:1341`, `hear_route` `:1346`, `watched(point)` `:1349`, `quarry()` `:1351`, `saw_enter(hide, sure)` `:1355`, `noticing()` `:1358`, `forced_after()` `:1360`, `earned_rest()` `:1363`.
- Captura: `may_capture(body)` `:1367`, `cue_of(body)` `:1375`, `begin_capture(data)` `:1415`, `capture_style()` `:1422`, `capture_length()` `:1424`, `end_capture()` `:1426`, `play_cue(seat, cue_id, point, hold)` `:1431`, `cue_over` `:1448`, `capture_log()` `:1382`, `capture_records()` `:1384`, `tally()` `:1393`.
- Taller, pruebas y observador: `investigate(point)` `:1267`, `lead_to(...)` `:1264`, `searched_lately(room)` `:1270`, `hallucinations()` `:1280`, `place_over` `:1454`, `place_in_exit` `:1465`, `debug_lines` `:741`, `debug_state` `:760`, `draw_gizmos` `:786`.

Contrato formal (`docs/OFICINAS.md` 11.1, `:622-660`) frente a la base `creature.gd`:
- Predicados `is_hostile`, `is_attacking`, `is_hunting`, `is_chasing`, `is_engaged`, `is_roaming`, `is_wary`, `alarm_level`, `accepts_leads`: vienen de la base (`creature.gd:102-113`) y leen la palabra de `activity()` contra las listas de `creature.gd:26-43`. Ella no los redefine.
- Heredados sin redefinir (no-op o valor neutro): `search_from` `:220`, `play_call` `:270`, `resume_state` `:279`, `validate_strike` `:285` (INF), `sense_scale` `:292` (1.0), `hunter_reveal` `:295`, `hunter_contact` `:299`, `hunter_gone` `:304`, `apply_quality` `:308`, `arm` `:242`, `blackout` `:251`, `hunter_camera` `:248`. Son las piezas del versus que aún no existen en ella.
- `wardrobe_steps()` `creature.gd:360` (0.55 / 0.7 / 1.7): ella no abre armarios.
- `dull` (`creature.gd:58`, 1.0): lo lee `lurker_senses.gd:209`. `grace` (base 15.0, `creature.gd:54`): `lurker.gd:540` lo baja cada tick.
- `tests/hotel/creature_contract_test.gd`: no leído.

Red del cuerpo: `pack_state()` manda 12 valores (`PACK_SIZE` `:42`, `:490-493`): `[posición, cuaternión, velocidad, índice de palabra, flags, grace, look, clip, near_node, jump_id, brain.state, brain.prey]`. Flags (`:45`): IN_DUCT 1, HIDDEN 2, SURFACE 4, DRAINING 8, CUE 16, DROP 32, ARRIVING 64, TRAY 128, BAND 256, SCARED 512 (`:487`, en RECOIL o FLEE).

## 2. Estados del cerebro (Q2)

`enum State` (`lurker_brain.gd:56`): ROAM, LISTEN, STALK, PEEK, FREEZE, CREEP, CUE, TAKE, RECOIL, FLEE, TRANSIT, WAIT_ABOVE, HUSH, RETURN, AMBUSH. La palabra que se ve y el latido que se oye están en `WORDS` (`:60-62`) y `BEATS` (`:68-70`). Nombres de depuración en `NAMES` (`:63-65`).

Orden de decisión (`decide()`, `:275-308`):
1. Gracia: `hold` (`:279`). Tránsito: TRANSIT, y al salir ROAM (`:280-283`).
2. Linterna en la cara (`torch_by`, fuera de TAKE/RECOIL/FLEE): RECOIL al instante (`TORCH_SCARE` 0.0, `:34`, `:288-292`).
3. Mirada (`regard_time` > 0) en ROAM, LISTEN, STALK, HUSH, CREEP, WAIT_ABOVE o AMBUSH (o RETURN fuera de conducto): FLEE al instante, y cuenta como intento si acechaba (`:301-304`).

Estados (`state_tick`, `:310-325`):
- **ROAM** (`roam_tick` `:554`): primero el cruce del director; si `choose_prey` elige a alguien, `begin_hunt`. Si no, una meta (`pick_goal` `:598`): un ruido reciente (`noise_react`, dentro de `CLUE_FOR` 20 s, `:506`), la zona del director, su "haunt" (prob. 0.6 a ±9 m, `HAUNT_SPREAD` `:156`) o su ronda (`patrol_room` `:1213`). Al llegar, con prob. `LISTEN_P` 0.5 (`:501`) pasa a LISTEN.
- **LISTEN** (`listen_tick` `:627`): 3–6 s (`LISTEN_TIME` `:500`) quieta en una rejilla. Caza o ruido la sacan. Al acabar, `searched` 60 s (`SEARCHED_FOR` `:502`).
- **STALK** (`stalk_tick` `:687`): sin señal 12 s (`forget`) → `lose()` (`:451`) → ROAM. En un armario → WAIT_ABOVE. Cambia de presa si otra puntúa 0.3 más (`SWITCH_MARGIN` `:503`). Acaba con `stalk_left` (= `stalk_time` × `STALK_SCALE[team]` `:133`, `:673`). También por `occasion()` (`:683-685`: quieta ≥ 2 s, ocupada, o sola ≥ 6 s a oscuras y de espaldas), si está a ≤ `stalk_distance` + 4 m (`HUSH_SLACK` `:659`) → HUSH. Un asomarse (PEEK) con prob. `peek_odds`, entre el 30 y el 60 % del acecho (`PEEK_AT` `:663`, `:675`). Recalcula su punto cada 0.5 s (`STALK_REPATH` `:652`).
- **HUSH** (`hush_tick` `:719`): silencio. Si la presa se aleja más de la distancia + 4, STALK con 3 s mínimo (`STALK_SHORT` `:661`). Tras `hush_time` (2.5 s por defecto) o si la presa camina, → CREEP.
- **CREEP** (`creep_tick` `:854`): `cue_ready` → CUE. Oculta → WAIT_ABOVE. No justa u oculta → STALK. Si pasan 5 s sin quedar detrás (`CREEP_LOSE` `:49`) → STALK. Si no, va a `CUE_DIST` 2.4 m detrás (`:32`) a `clamp(vel. presa + 0.6, 1.0·creep_scale, approach_cap)` (`:875-876`).
- **AMBUSH** (`ambush_tick` `:814`): por el plénum a un techo oscuro 8–14 m delante de la presa (`lurker.gd:1040`). Espera quieta hasta 12 s (`AMBUSH_WAIT` `:788`). Si la presa se aleja más de 16 m (`:789`) o no llega en 10 s (`:790`) → STALK. `cue_ready` → CUE.
- **CUE** (`cue_tick` `:879`): el aviso corre (§7).
- **TAKE** (`take_tick` `:912`): 0.2 s (`TAKE_EMPTY` `:51`), luego `end_take()` (`:918`): `sated_until` = +40 s (`sated`), descanso de equipo `QUIET_BASE` 15 s × `PAUSE_SCALE[team]` (`:132`, `:134`, `:930-931`), y FLEE.
- **RECOIL** (`recoil_tick` `:994`): chilla una vez (`world.scream`) y da `bolt` con clip `"scare"` → FLEE.
- **FLEE** (`flee_tick` `:1023`): dentro de un conducto oculto, RETURN si hay `comeback`, si no ROAM tras `FLEE_HIDE` 6 s (`:44`). Fuera, `bolt` hacia la salida más alejada de la luz, y a los `FLEE_OUT` 0.4 s (`:45`) `vanish` → ROAM o RETURN.
- **RETURN** (`return_tick` `:1050`): espera `comeback.at`, elige a quien (`return_target` `:1084`, a ≤ 12 m de quien se escapó, el más solo), sale por `world.emerge_point` (`lurker.gd:1126`) a `FLEE_SPEED` 3.5. Luego acecha con `RETURN_STALK` 0.4 s. Abandona a los 20 s (`RETURN_MOST` `:1048`).
- **WAIT_ABOVE** (`wait_above_tick` `:1112`): 20–40 s sobre el armario (`WAIT_ABOVE_TIME` `:1103`). Si la presa sale y es justa → CREEP.
- **FREEZE** (`freeze_tick` `:1128`): solo por `force()` (`:216`). Si la miran 3 s (`FREEZE_TIME` `:37`), retrocede a 0.8 m/s (`RETREAT_SPEED` `:28`). Vuelve tras 1 s sin mirada (`UNFREEZE` `:38`).

Otros tiempos: CRAWL 1.35 m/s (`lurker.gd:20`), CREEP_SPEED 1.0 (`:23`), CREEP_LEAD 0.6 (`:24`), CUE_FOLLOW 3.8 (`:25`), SCURRY 3.5 (`:26`), CUE_RANGE 2.0–5.0 m (`:31`), ARRIVE_NEAR 0.6 m (`:654`).
- Descanso: `resting()` (`:335-336`) = en `quiet_until` o `sated_until`.
- Parada: `watch_progress()` (`:342-371`): 6 s sin 0.5 m (`STALL_TIME` `:106`, `STALL_MOVE` `:107`) → otra ruta. A la segunda, deja a la presa 10 s (`STALL_REST` `:109`) y vuelve a ROAM.
- Intentos: `failed_attempt()` (`:1007-1018`): a `tries` (3) → descanso `rest_after` 90 s (`:142`). Si no, vuelve en `emerge_delay` × `ESCALATE` [1, 0.7, 0.5, 0.4] (`:1021`).
- Valores por defecto de `tune()` (`:138-158`): window 1.5, lit_takes true, stalk_distance 8, tries 3, rest_after 90, emerge_mode "near", emerge_delay 4–7, emerge_range 6–10, creep_scale 0.9, sated 40, stalk_time 15–25, peek_odds 0.5, hush 2.5, noise_react 2, haunt 0.6, ambush_odds 0.3, approach_cap 3.5, forget 12.

## 3. Movimiento (Q3)

Puede ir por: techo (TRAY), franjas de banda sobre un marco de puerta o un muro (BAND, `lurker_shell.gd` `add_door_band` `:392`, `add_wall_band` `:420`), pasillos (CHANNEL, `add_channel` `:517`), conductos visibles, plénum (oculto), rejillas, huecos y losetas. Nunca abre puertas (`lurker.gd:6-7`). `enum Kind { TRAY, BAND, CHANNEL }` en `lurker_shell.gd:15`. Los tramos de conducto son visibles según `ducts.visible_kinds` (`lurker_motion.gd:1089-1090`); el plénum no lo es.

Velocidades y ritmos (`lurker_motion.gd`):

| Constante | Valor | Línea |
|---|---|---|
| pace por defecto (sobre superficie) | 1.35 m/s | `:111` |
| SCURRY_SPEED / RETREAT_SPEED | 3.5 / 0.8 m/s | `:17-18` |
| SQUEEZE_SPEED (rejilla o loseta) | 0.6 m/s | `:21` |
| ACCEL / BRAKE | 4.0 / 6.0 m/s² | `:24-25` |
| BURST_SPEED (ráfagas vista) | 3.3 m/s; tramos de 0.45–0.85 s; pausas de 0.3–0.7 s | `:32-34` |
| BURST_ACCEL / BURST_FROM | 20 m/s² / pace ≥ 1.0 | `:35-36` |
| BOLT_TIME / BOLT_MIN / BOLT_MAX | 0.3 s / 8 / 40 m/s | `:427-429` |
| LEAP_REACH / LEAP_TIME / LEAP_RISE | 7.5 m / 0.6 s / 0.3 m | `:72-74` |
| CLIMB_SPEED (suelo a techo) | 1.5 m/s | `:75` |
| RIDE_TIME (cambio de planta) | 8.5 s | `:84` |
| duct_speed por defecto (conducto oculto) | 1.6 m/s | `lurker.gd:73` |
| MAIN_DUCT_SPEED (conducto visible) | 1.0 m/s | `lurker_routes.gd:39` |

- Ráfagas (`in_bursts` `:544`): solo si la ven, sobre superficie, con pace ≥ 1.0. Alterna quieta y carrera, para una media de unos 1.8 m/s (comentario `:27-31`).
- Aceleración (`ramp` `:566-571`): sube a ACCEL, baja a BRAKE, y a BURST_ACCEL en ráfagas.
- Pausa (`pause` `:311`) frena manteniendo el camino. `hold` (`:288`) frena en seco, salvo en medio de una rejilla, caída, salto, escalada o giro, que termina antes (`:291-296`).
- Altura: `ease_hang` (`:821`) a 0.5 m/s (`HANG_RATE` `:40`). Un rayo abajo cada 0.25 s (`RAY_EVERY` `:48`, máscara `1|4` `:50`) limita la altura (`hang_limit`) y encoge el cuerpo entre `SQUASH_MIN` 0.4 y 1.0 (`:77-78`, `:742`). Cuerpo: `BODY_DEPTH` 0.77 (`:45`), `HEAD_CLEAR` 0.25 (`:47`). Constantes de la forma: `DEFAULT_HANG` 0.35, `HANG_MIN` 0.05, `HANG_MAX` 0.9, `BAND_CLEAR` 0.35, `CH_HANG` 0.25, `SEAM_TOL` 0.02 (`lurker_shell.gd:21-51`).
- Giro: HEADING_RATE 3.0 rad/s en superficie (`:38`), TURN_RATE 4.0 en conducto y giros (`:39`).
- Banda: a 0.8 m de su inicio gira hacia ella (`LOOKAHEAD` `:54`). Entra cuando su orientación está a menos de 0.3 rad (`DOOR_ALIGN` `:69`, `band_switch` `:946-966`).
- Puerta: si se cierra con ella a menos de media banda, da la vuelta (`follow_band` `:976-983`). Vigila `routes.door_open` (`lurker_routes.gd:323-333`: abierta, quieta y sin bloquear).
- Subir: `follow_climb` `:1169-1189`, a 1.5 m/s. Bajar de un techo: `leap(to, seconds)` `:497-510`. Solo desde superficie, con `to.y < from.y`, a ≤ 7.5 m en horizontal, y sin pilar en medio (`column_near`). Dura 0.6 s y sube 0.3 m como mucho (`follow_leap` `:1148-1167`).
- Cambio de planta: `start_transit` `:650` (`transit` = leaving, 8.5 s). Exige `ready_to_go()` (`:644-648`): sin aviso, sin estar ocupada (`busy` = cazando, encuentro o aviso) y sin superviviente vivo y activo en su planta (`left_behind` `lurker.gd:266-272`). `begin_drop` `:663` la mete en el conducto troncal (`trunk_nearest`). `finish_drop` `:679` la deja en la sala de destino que da `routes.arrival_exit`.
- Entrar a un conducto: `place_in_duct(node)` `:236-249`. Salir: `follow_squeeze` `:995-1053`. Rejilla o loseta a 0.6 m/s, o a `bolt_speed` si escapa. Al entrar, `hidden` = no visible. Loseta: `tile_turned` (`:1015`, `:1036`) → `lurker.gd:turn_tile` (`:1165-1180`): la mano agarra `TILE_HAND` "a.R" con `TILE_GRIP` 0.4 s (`:1163-1164`).
- Conducto: `follow_duct` `:1063-1110`. En un tramo visible se para si hay un superviviente a menos de 2.5 m delante (`DUCT_GAP` 1.5 `:56`, `:1097-1098`).
- Ventilador: si el ala 2 (planta 3) tiene los conductos cerrados, la expulsa (`fans()` `:725-731`, `eject()` `:477-484`).

Costes de ruta (`lurker_routes.gd`):
- `REPLAN_EVERY` 2.0 s (`:29`), `BAN_TIME` 10 s (`:31`, veta una puerta tras dos paradas).
- `edge_cost` `:386-405`: sala = metros · factor de sala / `CRAWL_SPEED` 1.35. Puerta suma `PORTAL_COST` 0.5 s (`:25`). Entrar o salir de un conducto suma 1.5 s (`:26-27`). Ala cerrada: no entra salvo que escape (`:396-400`).
- `room_factor` `:357-361`: 25 si la energía la acota (`POWER_FACTOR` `:23`), 6 si la sala está iluminada (`LIT_FACTOR` `:21`), 1 si no.
- Escotilla (`hatch`): solo si el aire la tiene abierta (`exit_usable` `:363-367`). Búsqueda: `plan` `:495`, `nearest_exit` `:920`, `flee_exit` `:929`, `arrival_exit` `:949`, `travel_metres` `:865`.

Ruido por superficie (`lurker_voice.gd`):
- Pisada (`footfall` `:156-170`): `STEP_DB` por material (`:21`): tile -11, metal -8, hard -12, wood -11, soft -20 dB, más -6 a 0 dB según la fuerza. Al acercarse, la fuerza es al menos `CREEP_FORCE` 0.8 (`:28`). Material `soft`: corte a 1200 Hz (`:23`). Medio (`medium()` `:129-135`): sala, conducto o plénum (nodo `gap` o `plenum`).
- Garra en pared: al acechar o acercarse, sobre pared de madera o duro, arrastra con prob. 0.25 (`WALL_CHANCE` `:30`, `:169-170`).
- Conducto: `travel(delta, speed)` `:186-219` suena solo dentro de un conducto, y calla en sala, en `hushed` o si el latido es `return`.
- Losa que se mueve: `tile_shift` `:236-244`, crujido a -10 dB (`CREAK_DB` `:32`) y polvo a -16 dB (`DUST_DB` `:50`).
- Coche: `outside_car` `:272-285`, raspados a -8 dB (`CAR_DB` `:51`). Plénum: -6 dB y corte de 1800 Hz (`lurker.gd:25-26`, `:448-456`).

## 4. Sentidos (Q4)

Vista (`lurker_senses.gd`, `sees()` `:179-192`; geometría en `creature_sight.gd`):
- Mira desde su cara o, en conducto, desde la rejilla donde sale (`eye_point` `:169-177`). Por una loseta cerrada no ve nada (`:175`).
- Alcances: 20 m a oscuras (`SIGHT_DARK` `:97`); 35 m a un jugador con la linterna encendida (`BEAM_SEEN` `:100`); 4 m dentro de una sala iluminada (`SIGHT_LIT` `:98`, `:187`).
- Cono: 110° a cada lado (`SIGHT_HALF` `:103`), salvo a menos de 1.5 m (`SIGHT_NEAR` `:104`). Atrás no ve.
- Línea de visión: `SIGHT.clear` con máscara `1|8|64` (`creature_sight.gd:12`, `:62-65`): muros, puertas y escondites tapan; los cuerpos no. Comprueba la cámara y luego 0.6 m más abajo (`:192`).
- Escondido (`hidden`): solo lo ve si vio entrar al escondite (`saw_enter` `:195-197`, `:181`).
- `grace` propio > 0 cancela su vista (`:180`).
- Rayos: cada 0.1 s (`SENSE_EVERY` `:106`); con más de 4 supervivientes, uno por tick (`perceive` `:341-349`). Memoria 12 s (`forget` `:141`, `:359`).

Quién la mira (`creature_sight.gd` `regarders` `:121-135`):
- Mirada (`regarded_by`): la vista (30°; 45° si es remota, `REGARD_LOCAL`/`REMOTE` `:16-17`) apunta a su cara a ≤ 30 m (`REGARD_REACH` `:19`), con línea despejada, y la cara se ve (sala iluminada, linterna sobre ella, o a ≤ 1.2 m `DARK_FACE` `:22`).
- Linterna en la cara (`torch_by`): dentro de 20° (`TORCH_FACE_ANGLE` `:26`) y a ≤ 20 m (`TORCH_REACH` `:27`).

Oído (`hear_route` `:204-217`):
- Alcance: `radius · HEARING_SCALE · hearing · dull · (1.4 si escucha) · (1 − 0.7 · mascara)` (`:209`; `LISTEN_EAR` `:108`, `FAN_DEAF` `:110`, `hearing` 1.0 `:140`).
- Por sala (`room_route` `:220-247`) o por conducto (`duct_route` `:250-268`).
- Clic de linterna: encender o apagar se oye a 8 m (`TORCH_CLICK` `:113`, `:430-439`).

Qué le tapa: muros, puertas, escondites, conductos y plénum (está dentro), y supervivientes escondidos o protegidos (`fair` falso, `:412-413`).

Luz de la sala y linterna (efectos en lo que percibe):
- Sala iluminada: el que la mire la ve (`regards`, `creature_sight.gd:116`), y ella ve solo 4 m.
- Linterna encendida: la ve desde 35 m. Si apunta a su cara, la regarda y la asusta (§5). Una linterna bebida no cuenta para ella (`drank()` `lurker_senses.gd:483-484`, `drop_drunk` `:494-508`).

## 5. La luz: arma y debilidad (Q5)

Beber una sala (`lurker_senses.gd` `drain_rooms` `:301-311`; `lurker.gd` `drain_step` `:1473`, `_process` `:1483-1521`):
- Lámparas de su planta a ≤ `drain_reach` (3.5 por defecto `lurker.gd:868`; tabla §9). Cuanto más cerca, más bebe: `lerpf(DRAIN.y, DRAIN.x, nearest/reach)` con `DRAIN` = (0.4, 0.7) (`senses:118`, `:310`).
- La luz se acerca al objetivo a `DRAIN_EASE` 1.5/s al bajar, o a `DEEP_FALL` 1.0/s al soltar si estaba por encima de 0.78 (`:1500`). Trémolo de `DRAIN_WOBBLE` 0.08 (`senses:123`, `:1509`).
- Encendida o no: `hotel.lit(room)` (`game/world/hotel/hotel_geometry.gd:2924-2925`) es verdadero mientras `drains[room] < LIT_DRAIN` = 0.9 (`hotel_geometry.gd:102`). Beber normal llega como mucho a 0.7 (`DRAIN.y`), o sea, la sala queda encendida con el 30 % de luz. Solo el apagado profundo la apaga del todo.
- Apagado profundo (G8, `snuff_step` `:1600-1615`): si acecha a una presa en una sala iluminada `snuff_time` segundos seguidos, la sala baja a `DEEP` = 0.93 (`:134`), con subida de 0.3/s (`DEEP_RISE` `:135`). Se queda mientras dura el encuentro allí. La devuelve con `DEEP_FALL` 1.0/s, si la presa lleva fuera 3 s (`DEEP_OUT` `:138`) o pasan 25 s (`DEEP_MOST` `:137`). No vuelve a apagar la misma sala en 45 s (`DEEP_AGAIN` `:139`, `may_snuff` `:1619-1623`). Temblor: `DEEP_WOBBLE` 0.12, `DEEP_REST_WOBBLE` 0.02 (`:140-141`, `:1504-1508`). Evento `"snuff"` `[room]` (`:1634`).

Linterna del jugador que bebe (`drink_torches` `:1525-1532`, `torch_step` `:1535-1558`):
- Tras un susto con linterna, las linternas de la cara se beben `torch_drunk` segundos (`:1529`): brillo a `DRUNK_BEAM` 0.15 con parpadeo irregular, y vuelve en `DRUNK_RAMP` 1.0 s (`:105`, `:1545-1548`). Sonido `off_2.wav` a -6 dB (`:106-107`).
- Apagado para siempre (H1, `kill_torches` `:1561-1567`): con prob. `torch_kill`. Queda apagada hasta que el dueño la encienda de nuevo (`dead_torch_step` `:1570-1578`). Un chispazo dura `SPARK` 0.2 s (`:116`, `:1549-1557`).

Parpadeo al pasar cerca o encima (Q5):
- No encontrado: ningún código hace parpadear las luces de forma automática cuando ella pasa. Lo que hay es el temblor del drenaje (`DRAIN_WOBBLE`, `DEEP_WOBBLE`, arriba), aplicado con `hotel.drain` (`hotel_geometry.gd:2949`). Los docs (§4) lo llaman "los tubos titilan".
- Lo que sí reacciona: `watch_systems` (`lurker.gd:916-932`) avisa a la mente de `on_room_lit` si se enciende la luz de su sala (salvo que la haya devuelto ella, `:923-925`) y `on_ducts_open` si se paran los ventiladores (`:929-931`). El cerebro pasa a FLEE (`on_room_lit`, `lurker_brain.gd:935-940`) o pone una pista en la salida más cercana (`on_ducts_open`, `:944-948`).

Linterna apuntándole a la cara:
- En `decide()` (`lurker_brain.gd:288-292`): RECOIL al instante con causa "linterna" (`recoil()` `:980-990`). Sigue el evento `"scare"` (`lurker.gd:887-890`).
- Dentro de un aviso: `check()` devuelve "saved" con razón "linterna" (`lurker_warning.gd:84-85`) si la víctima tiene la linterna en la cara, o "mirada" si la mira (`:84`, `:86`).
- Ángulo 20° y 20 m (`creature_sight.gd:26-27`). Reacción en el mismo tick (`TORCH_SCARE` 0.0, `lurker_brain.gd:34`).

## 6. La linterna del jugador (Q6)

Archivo: `game/player/hotel_player.gd`.
- Encendido: la acción `"flashlight"` alterna `torch.visible` (`:253-256`). No hay enfriamiento ni batería (los docs §4 dicen "la linterna sigue sin batería").
- Calentamiento: cada pulsación pone `torch_warmup` a 0 (`:255`); sube `delta · 6` por segundo (`:660`), o sea unos 0.17 s hasta el brillo pleno. Brillo `w²`, con parpadeo si `w < 0.6` (`:661-662`). Energía: `torch_energy · warm · (1 − 0.06 · moving · |sin(step)| · sway) · torch_dim` (`:663`).
- Apagado al esconderse: `torch.visible = false` (`:786`).
- Lo que fija el Lurker: `torch_dim` (`hotel_player.gd:132`, por defecto 1.0). Baja a 0.0 si la linterna está muerta, o a `lerpf(1.0, 0.15, …)` mientras se bebe (`lurker.gd:1548`). Vuelve a 1.0 al acabar la bebida (`:1542`). Un chispazo la deja en 0.8 durante 0.2 s (`:1557`).
- Pulsar sin parar es posible sin límite: cada pulsación reinicia el calentamiento. Sonidos: `kit_sounds.gd:18-19`, `torch_switched` `:71`.

## 7. El ataque (Q7)

Acecho y punto de salto:
- Techo fuera del cono de la presa (`stalk_point` `lurker.gd:1077-1097`): `STALK_CONE` 60° (`:1074`), giros de hasta ±105° (`:1075`), alcance `STALK_REACH` [1.0, 0.75, 1.3] (`:1076`). Prefiere la sombra (+1.0 si está iluminado).
- Detrás de la presa en CREEP: `behind_point` a 2.4 m (`lurker.gd:1024-1031`, `lurker_brain.gd:32`). "Detrás" según `creature_sight.gd:157-170`: más de 105° o por encima (`OVER_SIN` 0.77, `OVER_LOOK` 0.5).
- Sobre un armario: WAIT_ABOVE (§2).
- Emboscada: techo oscuro 8–14 m delante, sin luz, no protegido, y no en la ruta de la presa (`ambush_point` `lurker.gd:1040-1061`, `AMBUSH_AHEAD` `:1038`).

Cuándo puede empezar el aviso (`cue_ready` `lurker_brain.gd:847-852`): estado CREEP o AMBUSH; la víctima la ve, es justa, no está escondida ni en el conducto ni en límites prohibidos; está entre 2.0 y 5.0 m (`CUE_RANGE`); está detrás (`behind`); nadie la mira y no hay linterna en su cara; `lit_takes` o sin luz; el aviso está libre; no sateada ni dejada en paz.

Aviso (`lurker_warning.gd`):
- Plazo: `due = at + window + latency`, con latencia ≤ 0.5 s (`LATENCY_CAP` `:24`, `:60`). `window` = 1.5 s por defecto (`back_window`, §9).
- Captura: a ≤ 3.4 m (`TAKE_REACH` `:16`) al vencer. A 3.4–7.4 m y sin correr, también (`TAKE_REACH_WALKED` `:19`), y completa con salto (`leap`, §3). Correr es ≥ 5.0 m/s (`RUNNING` `:22`).
- Toma: `take(clock)` en `[due − EPS, due + 0.6]` (`TAKE_HOLD` `:14`; `:106-114`). Luego TAKE y `intent(&"take")` (`lurker_brain.gd:900-906`, `leap = distancia > 3.4`).
- Gate: `may_capture` (`lurker.gd:1367-1373`) solo en la máquina a cargo y solo si hay una toma de ese seat en este tick (`lurker_warning.gd:117-122`). Una captura de herramienta se registra y pasa (`forced_take` `:125-129`).
- `begin_capture` (`lurker.gd:1415-1421`) guarda la toma. La duración es `SCORE.CUT_TIME` (`:1424`). `end_capture` libera (`lurker_brain.gd:965-967`).

Avisos previos:
- Sonido (`CUE_SOUNDS` `lurker_warning.gd:28`, o `CUE_SOUNDS_SHORT` `:31` si el aviso dura menos de `LONG_CUE` 1.2 s `:32`): se oye entero antes de la captura.
- Subtítulos: "[Algo respira a tu espalda]" (`CUE_CAPTION` `:34`), "[Algo respira cerca]" a lo lejos (`:35`), "[Algo respira sobre ti]" desde arriba (`:37`). `play_cue` (`lurker.gd:1431-1446`) pone el sonido en los oídos de la víctima, y su voz calla mientras dura (`voice.quiet_until`, `:1445`).
- Polvo y placas: `tile_shift` (`lurker_voice.gd:236`) y `ceiling_dust.gd` (solo esqueleto; quién lo llama, no verificado).

Veredictos de `check()` (`lurker_warning.gd:75-95`):

| Razón | Veredicto | Condición |
|---|---|---|
| mirada | saved | la víctima la mira, o alguien la mira |
| linterna | saved | una linterna le apunta a la cara |
| corriendo | saved | corre (≥ 5 m/s) y al vencer está a más de 3.4 m |
| fuera | aborted | la víctima ya no está en juego |
| protegida | aborted | la víctima o la sala están protegidas |
| escondida | aborted | se esconde (`to_locker` si la vio, `lurker_brain.gd:890`) |
| con luz | aborted | en luz y `lit_takes` falso (solo Apacible) |
| movida | aborted | un teletransporte o un cambio de etapa |
| lejos | expired | pasan 0.6 s después del plazo sin captura |

Tras saved (mirada, linterna o corriendo) ella recula con `recoil(…, counts=true)` (`lurker_brain.gd:886`), que cuenta un intento. Tras aborted o expired, STALK con 3 s mínimos (`:891-898`). `audit(log)` (`lurker_warning.gd:149-170`) revisa el plazo, los límites de latencia, las capturas en su ventana y el orden de ids.

## 8. El chillido y sus otros sonidos (Q8)

- Cuándo: en RECOIL, una sola vez por susto (`screamed`, `lurker_brain.gd:994-1002`). Causas: linterna en la cara, mirada, o un aviso salvado. Sonido: uno de `SCARE_SOUNDS` (`:53`, `scare_0.wav` o `scare_1.wav`) a -2 dB (`SCARE_GAIN` `:54`), en `world.scream` (`lurker.gd:1330-1334`). Lo oye la sala (`play_at`) y la red lo reenvía (`match_net.world_sound`, `:1334`).
- Cordura: `frighten(at)` (`lurker.gd:1317-1327`) asusta (`mind.fright(body, SANITY_SHRIEK)`) a los supervivientes con vista limpia a ≤ 12 m (`SHRIEK_FRIGHT` `:33`), en su planta y sin oclusión. Solo lo hace la máquina a cargo (`:1321`).
- Luces: el chillido no apaga luces. Solo beber a fondo (§5) apaga una sala.
- Linternas: las que la asustaron se beben (`:889`, `:1306`), y las de `torch_kill` se apagan para siempre (`:890`, `:1307`).
- Subtítulo: `shriek_heard` (`lurker_voice.gd:263-270`) muestra "[Un chillido]" (`SHRIEK_CAPTION` `:261`) a ≤ 16 m (`CAPTION_NEAR` `:262`).
- Latidos (`MOODS` `lurker.gd:584-599`): 14 estados con aura, clics, amenaza, rapidez y silencio. Al llegar sobre un armario, `voice.arrive_above()` (`lurker_voice.gd:246`).

## 9. Dificultad (Q9)

Archivo: `game/floors/difficulty.gd`. La tabla propia de Lurker es `CREATURE_PROFILES[&"lurker"]` (líneas 177-180), que `profile(id, creature)` mezcla sobre `PROFILES` compartidos. Desafiante es la referencia (`REFERENCE`).

| clave | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| back_window (s, aviso hasta la captura) | 2.2 | 1.5 | 0.9 | 0.9 |
| lit_takes (captura en sala con luz) | no | sí | sí | sí |
| duct_speed (m/s en conductos) | 1.2 | 1.6 | 2.4 | 2.8 |
| stalk_distance (m que guarda al acechar) | 12.0 | 8.0 | 4.0 | 3.5 |
| creep_scale (× su paso mínimo al acercarse) | 0.8 | 0.9 | 1.5 | 1.7 |
| drain_reach (m desde una lámpara para beberla) | 3.0 | 3.0 | 4.0 | 4.5 |
| unseen_speed (m/s en techo sin que la vean) | 3.0 | 3.5 | 4.5 | 5.0 |
| unseen_duct (m/s en conducto oculto sin verla) | 3.0 | 4.2 | 5.8 | 5.8 |
| attempts (intentos fallidos antes de dejarla) | 2 | 3 | 5 | 6 |
| encounter_rest (s que la deja en paz) | 120 | 90 | 45 | 30 |
| emerge_delay (s en el techo hasta el siguiente intento) | 8–12 | 4–7 | 1–2 | 0.7–1.5 |
| emerge_mode | far | near | behind | behind |
| emerge_range (m de la salida) | 10–15 | 6–10 | 3–5 | 3–4.5 |
| haunt (prob. de volver a su zona sin presa) | 0.35 | 0.6 | 0.9 | 1.0 |
| forced_after (s sin captura antes de forzar; 0 nunca) | 0 | 70 | 30 | 20 |
| stalk_time (s de acecho) | 25–40 | 15–25 | 4–9 | 3–6 |
| peek_odds (prob. de asomarse al acechar) | 0.7 | 0.5 | 0.15 | 0.1 |
| hush (s de silencio) | 3.0 | 2.5 | 1.5 | 1.0 |
| noise_react (s hasta que un ruido la gira) | 4.0 | 2.0 | 0.0 | 0.0 |
| sated (s que deja en paz a los cercanos a una captura) | 60 | 40 | 20 | 12 |
| approach_cap (m/s máximos al acercarse) | 3.0 | 3.5 | 4.5 | 5.0 |
| torch_drunk (s de linterna bebida tras un susto; 0 nunca) | 0 | 3 | 10 | 14 |
| snuff_time (s acechando en sala iluminada antes de apagarla; 0 nunca) | 0 | 12 | 4 | 2.5 |
| torch_kill (prob. de apagar para siempre una linterna bebida) | 0 | 0.25 | 0.6 | 0.8 |
| ambush_odds (prob. de emboscada con presa en movimiento) | 0.15 | 0.3 | 0.6 | 0.7 |

- `hearing` (`lurker_senses.gd:162`) viene de `PROFILES` compartidos: 0.7 / 0.75 / 1.0 / 1.2.
- La clave compartida `ambush` (0 / 0.7 / 2.0 / 2.0) es de The Locust. Ella usa `ambush_odds`.
- `forget` no está en la tabla: rige el 12.0 de `lurker_brain.gd:158`.
- Lo que la dificultad no toca de ella: `lurker_brain.gd:138-158` (defaults), `lurker.gd:151-163` y `lurker_senses.gd:161-164` (ver §2, §4 y §5).

## 10. Red (Q10)

Eventos (`tell` → `on_event`, `lurker.gd:1295-1314`; lista en el comentario `:1282-1294`):
- `"scare"` `[by_seat, cause, at, seats, seconds, killed_seats]` (`:1302-1307`).
- `"torch"` `[seat, "back" | "spark"]` (`:1308-1309`, `:1577`).
- `"snuff"` `[room]` (`:1310-1311`, `:1634`).
- `"tile"` `[room, tx, ty, open, from_below]` (`:1312-1313`, `:1015`, `:1036`).
- `"room_off"`: el comentario lo cita (`:1292`), pero `on_event` no lo trata. No encontrado.
- Vía: `level.match_net.creature_event(kind, data)` (`:1297-1298`).
- Otros mensajes de `match_net`: `send_cue(seat, id, point, hold)` (`:885`), `send_cue_over(id, outcome)` (`:886`), `world_sound(path, point, gain, 0.0)` (`:1334`), y `in_charge()` (`:1321`, `:1368`). Sus definiciones no se leyeron.

Estado (`pack_state` / `push_state`): 12 valores por tick (§1). `push_state` guarda 10 entradas (`:504`) y `follow_state` reproduce 0.1 s atrás (`:514-528`). Un cambio de `jump_id` reinicia el buffer (`:498-502`).

Qué simula cada máquina:
- La que manda (`control == "ai"`): cerebro, sentidos, movimiento, drenaje de luz (`drain_step`, `_process`), linterna bebida (`torch_step`) y capturas (`may_capture`).
- Las demás (`"puppet"`): solo interpolan posición y vista (`follow_state`). Su latido sale del estado enviado (`beat_now` `:617-622`), y "cerca" se calcula cada 0.5 s por distancia de ruta (`sound_beat` `:626-639`).
- Todas: su sonido por la ruta propia (`sound_route` `:406-428`), los conductos y losetas (`sound_step` `:562-580`), el aura y los eventos.

## 11. Pruebas de `tests/office/` (Q11)

Cada una por su encabezado y sus `check()`:
- `lurker_senses_test.gd`: ve a oscuras a 20 m sin linterna; la luz la ciega (a 6 m no ve, a 3 m sí); la linterna en la cara le impide ver a quien la alumbra; las paredes tapan.
- `lurker_fairness_test.gd`: la garantía (§7): 200 partidas acaban como dice el oráculo, cada captura con su aviso, ninguna antes de la ventana más la latencia, ningún aviso con la víctima mirando o protegida, auditoría del registro.
- `lurker_motion_test.gd`: con puertas abiertas llega por las franjas; no se mueve más de lo que el paso deja; con puerta cerrada va por conductos sin verse; por conductos no salta; si le cierran la puerta busca otra vía; bajo un dintel sin sitio espera.
- `lurker_shell_test.gd`: perfiles de esquinas, pasillos y secciones de archivo; banco frente a `lurker_test.gd`; constantes del dintel, del ancho de puerta y de la curva.
- `lurker_tiles_test.gd`: cada techo falso tiene su plénum y una placa; pasa a la sala de al lado por el plénum; una placa cerrada no deja pasar el sonido; ninguna placa a menos de 0.6 m de una columna; entra por la placa de encima; iluminada, huye por la placa.
- `lurker_capture_test.gd`: captura en falso techo: la coge, el anfitrión manda dónde cuelga y cuánto la levanta; la cámara cae mirando arriba; sangre al agarrar; cuelga cabeza abajo con las manos en los hombros.
- `lurker_forced_test.gd`: encuentros forzados: no antes de `forced_after()`, nunca en Apacible, antes cuanto más difícil; no a por alguien escondido; a quien camina lo lleva a la sala a la que va.
- `lurker_observer_test.gd`: su paquete de 12 valores, el observador con sus capas (conductos) y colores, y sus momentos enviados.
- `lurker_mood_audio_test.gd`: tras espantarla, la música vuelve en 6 s o menos; sin espantada, más de 6 s; tandas de pasos según el compás; huyendo, una tanda que no para.
- `lurker_bots_test.gd`: partida de bots en el piso 2 con ella; los bots la miran con su modelo; un aviso en la espalda en menos de 40 s.
- `lurker_fixture.gd`: apoyo (plano de cuatro celdas), no es prueba.
- Las pruebas no tienen funciones `test_*`: usan `check()` y `run()`.

## 12. docs/OFICINAS.md (secciones 4, 6 y 11.1 leídas; la 1 solo en encabezados)

Cruce del docs con el código:
- §4 "Acechar, 120° alrededor de hacia dónde va": coincide con `STALK_CONE` = 60° a cada lado (`lurker.gd:1074`).
- §4 "Se bebe la sala entera (de Equilibrada para arriba)": coincide (`snuff_time` 0 en Apacible).
- §4 "En una sala con luz no coge a quien la tiene a la vista": **diferencia**. En el código depende de `lit_takes` (`lurker_brain.gd:851`): Apacible no, las demás sí. Lo que impide la captura es que la víctima la mire (`regarded_by` vacío, `:852`), no la luz.
- §4 "Huye: dentro en 0,3 s; a los 0,4 s sigue fuera, entra donde esté": coincide (`BOLT_TIME`, `FLEE_OUT`).
- §4 "Drenaje a 3–4,5 m; la lámpara baja al 30–60 %": coincide (`drain_reach`, `DRAIN`).
- §4 "Emboscada, nunca bajo un techo con luz": coincide (`lurker.gd:1054`).
- §4 "La linterna sigue sin batería" y "Quieta ya no se usa": coinciden.
- §6 (captura por la espalda: manos, cámara, sangre): no verificado; el estilo está en `game/app/capture_styles/lurker_capture.gd`, que no se leyó.

## No encontrado

- Vista infrarroja o colormap tipo plasma para la criatura: ningún archivo de `game/enemies/lurker/` lo tiene. Fuera de la carpeta, las coincidencias de la búsqueda son ajenas a la criatura (TV, geometría, `echo_points.gdshader` de The Locust).
- Parpadeo automático de luces al pasar ella cerca o encima (§5).
- Evento `"room_off"` en `on_event` (§10).
- Contrato en `tests/hotel/creature_contract_test.gd`: no leído.
