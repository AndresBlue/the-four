# Ficha de hechos: reglas del piso (contrato de juego)

Ficha para el port de The Four a Unreal. Solo hechos del repo: qué hace el código de `game/floors/` y qué dicen los documentos, con ruta y línea. No contiene diseño de Unreal. Lo que no se ha leído está en el apartado 13.

Fecha de lectura: 14 de noviembre de 2026. Solo lectura: no se ha escrito código, no se ha ejecutado Godot y no se ha tocado git.

## 1. Cómo se leyó

- `game/floors/`: los 13 archivos `.gd` leídos completos (3.924 líneas). Los `.uid` no tienen contenido de juego.
- `docs/DIFFICULTY.md` (307 líneas) y `docs/LORE.md` (81): completos.
- `docs/GAME_DESIGN.md` (322): líneas 1 a 202 y 300 a 322, completas. Las líneas 203 a 299 (criaturas y ritmo) solo por búsqueda de términos y por las líneas 208, 210, 230 a 232, 272 y 282.
- `docs/PLAN.md` (917): sección 5 («Lo nuevo: los otros tres pisos», líneas 820 a 904) completa. El resto, solo por títulos.
- `docs/OFICINAS.md` (1031) y `docs/EXECUTION.md` (673): solo por títulos y lo citado en el apartado 11.
- `tests/` y `tools/`: no leídos por dentro. Solo cabeceras de comentario de algunos tests y listas por búsqueda de texto.

## 2. Inventario de archivos leídos

| Archivo | Líneas | Qué hace |
|---|---|---|
| game/floors/floor_index.gd | 52 | Registro de pisos por número: `KINDS` (1 hotel, 2 oficinas), `RELEASED := [1]`, `COUNT := 4`, títulos, hitos, versiones del generador. |
| game/floors/hotel_floor.gd | 111 | Piso 1 (el hotel): nombre, generador, validador, geometría, paleta, criatura, `PAR`, 18 hitos, 3 etapas con sus objetivos y textos, tabla de objetivos. |
| game/floors/office_floor.gd | 88 | Piso 2 (las oficinas): lo mismo; 3 niveles con objetivos `files`, `power`, `air`; salida por escalerilla; 12 hitos. |
| game/floors/match_rules.gd | 122 | Reglas que la sala cambia antes del piso: 10 reglas (y la constante `BY_DIFFICULTY`), valores, por defecto, alcance y lo que se envía. |
| game/floors/difficulty.gd | 209 | Cuatro dificultades: perfil compartido de la criatura (`PROFILES`), perfiles de The Lurker (`CREATURE_PROFILES`), nombres, rasgos y funciones de consulta. |
| game/floors/objectives/objective.gd | 177 | Clase base de un objetivo: progreso, metas, cuerpos, instantáneas, equipo visual (placas, luces, sonidos en punto). |
| game/floors/objectives/televisions_objective.gd | 65 | Objetivo `televisions` del hotel: enciende los televisores de un ala; apagón al faltar uno. |
| game/floors/objectives/code_objective.gd | 41 | Objetivo `code` del hotel: los cuatro números del código de la última puerta. |
| game/floors/objectives/files_objective.gd | 700 | Objetivo `files` de las oficinas (nivel 1): tubos neumáticos, fichas, foto de la cámara, recibo, red de tubos. |
| game/floors/objectives/power_objective.gd | 362 | Objetivo `power` de las oficinas (nivel 2): cuadro eléctrico, zonas, palanca roja, minuteros, montacargas. |
| game/floors/objectives/air_objective.gd | 483 | Objetivo `air` de las oficinas (nivel 3): compuerta, ventilación, ducto a gatas, escalerilla del pozo. |
| game/floors/palettes/hotel_palette.gd | 297 | Tipos de sala del hotel: nombres, alturas, luces, puertas, mobiliario, tamaños, planos de pasillo, oscuridad. |
| game/floors/palettes/office_palette.gd | 1217 | Tipos de sala de las oficinas: plantas, luces, techo y rejilla, ductos, mobiliario, acabados, dimensiones. |

## 3. Contrato de juego (lo que el port debe conservar)

### 3.1 Pisos

- Cuatro pisos previstos: `COUNT := 4` (game/floors/floor_index.gd:18). Construidos: 1 y 2 (floor_index.gd:7-10). Publicado: solo el 1 (floor_index.gd:16).
- Un número sin construir usa el script del hotel (floor_index.gd:23-24).
- Título visible: «PISO n: NOMBRE» si está publicado; si no, «PISO n» (floor_index.gd:34-35). Los hitos de un piso no publicado no se muestran (floor_index.gd:38-39).
- Versión del generador por piso: dos máquinas juegan juntas solo si coinciden en todas (floor_index.gd:47-52). Piso 1: `VERSION` de `floor_definition.gd` (hotel_floor.gd:30). Piso 2: `PALETTE.VERSION` = 2 (office_floor.gd:22; office_palette.gd:12).

### 3.2 Piso 1, el hotel (game/floors/hotel_floor.gd)

- Número 1, nombre «EL HOTEL» (hotel_floor.gd:19-20). Criatura `locust`, escena `res://game/enemies/locust/locust.tscn` (hotel_floor.gd:36-37). Aviso rojo del primer encuentro: «The Locust va a por ti…» (hotel_floor.gd:39). Papeles: el conjunto «hotel» (hotel_floor.gd:42).
- Tiempo de referencia `PAR = 2400.0` segundos (hotel_floor.gd:46). Cada segundo por debajo vale puntos al equipo (hotel_floor.gd:44-45).
- Tres etapas (`STAGES`, hotel_floor.gd:75-79):
  1. Objetivos: ninguno. Tarjeta «ENCUENTRA LA SALIDA». Aviso «Encuentra la salida del sector.»
  2. Objetivos: `televisions`. Tarjeta «ENCIENDE LOS TELEVISORES». Aviso «Enciende los televisores y busca la salida.»
  3. Objetivos: `televisions` y `code`. Tarjeta «DESCUBRE EL CÓDIGO». Aviso «Busca las notas con el código, enciende televisores y sal del piso.»
- Título de etapa: «SECTOR n» (hotel_floor.gd:98-99).
- Objetivos que puede pedir una etapa (`OBJECTIVES`, hotel_floor.gd:84-87): `televisions` (televisions_objective.gd) y `code` (code_objective.gd).
- Hitos (`MILESTONES`, hotel_floor.gd:52-71), 18 en total, con su regla (la evalúa `run_score.meets()`, no leído): `out` (won), `solo` (solo), `clean` (clean), `brave` (brave), `half` (time_under 1800), `quick` (time_under 1200), `three` (team_out 3), `four` (team_out 4), `again` (restarted), `sets` (mine tvs 4), `code` (mine digits 4), `slip` (mine escapes 3), `ghost` (unseen), `mvp` (mvp), `first` (grade A), `master` (grade S), `hunted` (versus_out), `hunter` (hunter_won).

### 3.3 Piso 2, las oficinas (game/floors/office_floor.gd)

- Número 2, nombre «LAS OFICINAS» (office_floor.gd:9-10). Criatura `lurker`, escena `res://game/enemies/lurker/lurker_creature.tscn` (office_floor.gd:25-26). Aviso rojo: «The Lurker acecha entre las sombras, no dejes que te atrape» (office_floor.gd:28). Sin papeles (office_floor.gd:30).
- `PAR = 2700.0` segundos (office_floor.gd:34): 45 minutos.
- Tres niveles (`STAGES`, office_floor.gd:56-58):
  1. Objetivos: `files`. Nivel «NIVEL 1», planta «PERSONAL». Tarjeta «PIDE TU FICHA».
  2. Objetivos: `power`. «NIVEL 2», «REGISTRO Y ARCHIVO». Tarjeta «ARRANCA EL MONTACARGAS».
  3. Objetivos: `air`. «NIVEL 3», «DIRECCIÓN». Tarjeta «SAL POR EL DUCTO».
- Título de nivel: «NIVEL n» (office_floor.gd:76-77).
- Cómo se sale del último nivel: `LEAVE := "ladder"`, por la escalerilla del pozo y no en un coche (office_floor.gd:63-65).
- Objetivos (office_floor.gd:62): `files` (files_objective.gd), `power` (power_objective.gd), `air` (air_objective.gd).
- Hitos (`MILESTONES`, office_floor.gd:38-50), 12: DADO DE ALTA (won), SIN COMPAÑÍA (solo), PLANTILLA COMPLETA (clean), NI UNA TAQUILLA (brave), MEDIA JORNADA (menos de 1800 s), SALIDA ANTICIPADA (menos de 1200 s), DEPARTAMENTO ENTERO (team_out 3), LOS CUATRO (team_out 4), SEGUNDA CONVOCATORIA (restarted), EMPLEADO DEL MES (mvp), EXPEDIENTE LIMPIO (grade A), EXPEDIENTE EJEMPLAR (grade S).

### 3.4 Reglas de la sala (game/floors/match_rules.gd)

Pestañas de la pantalla de reglas (match_rules.gd:20): «EL EQUIPO», «EL PISO», «LA HOJA», «THE LOCUST».

`BY_DIFFICULTY := -2` (match_rules.gd:17): la regla deja el valor a la dificultad.

| id | Título | Línea | Valores (valor: etiqueta) | Por defecto | Alcance |
|---|---|---|---|---|---|
| restarts | Clemencia | 28 | -2 según la dificultad; 0 ninguna; 1 una vez; 2 dos; 3 tres; -1 sin límite | -2 | todos los pisos |
| sanity | Cordura | 30 | 1 se gasta; 0 no se gasta | 1 | todos |
| code | Código de la última puerta | 32 | 0 se puede adivinar; 1 hacen falta las cuatro notas | 0 | solo piso 1 (`kind` 1) |
| blackout | Apagón | 34 | 1 al faltar una tele; 0 nunca | 1 | solo piso 1 |
| plan | Plano en la hoja | 36 | 1 se dibuja solo; 0 sin plano | 1 | todos |
| plan_fade | El plano se borra | 38 | 60 al minuto; 180 a los 3 min; 300 a los 5; 600 a los 10; 0 nunca | 180 | todos |
| shared_sheet | Lo que se dibuja | 40 | 1 lo ven todos; 0 solo quien lo dibuja | 1 | todos |
| onslaught | Embestida | 42 | 0 no; 1 sí | 0 | criatura `locust` |
| tv_travel | Viaja por los televisores | 44 | 1 sí; 0 no | 1 | criatura `locust` |
| plain_sight | Vista del cazador | 46 | 0 lectura acústica; 1 ve como una persona | 0 | criatura `locust` y solo en versus |

Reglas de alcance (match_rules.gd:22-26): `creature` limita la regla a una criatura; `kind` a un número de piso; sin ninguno, vale en todos.

Funciones (match_rules.gd): `entry` 50-53; `applies` 58-61; `shown` 64-68; `defaults` 71-74; `clean` 78-86 (descarta valores que no existen); `settled` 91-97 (defaults más lo dicho, sin lo que no aplica al piso); `changed` 100-106 (solo lo distinto del defecto, que es lo que se envía); `label` 109-113; `described` 116-122 («Clemencia: una vez»).

Nota: `restarts` con valor distinto de -2 manda sobre el perdón de la dificultad (difficulty.gd:80-81 dice lo mismo).

### 3.5 Victoria, derrota y mínimo de supervivientes

- Cada etapa acaba con los vivos dentro del refugio (hotel_floor.gd:2-5, `game_session.can_depart()`).
- Mínimo para avanzar: `ceil(N / 2)` (GAME_DESIGN.md:59). Los objetivos lo llaman como `session.minimum_survivors()` (files_objective.gd:650, power_objective.gd:328, air_objective.gd:283, 330, 421). La función no está en game/floors/ y no se ha leído.
- Un objetivo dice si está listo con `progress(stage).ready`. El host lo lee con `host_gate()` (objective.gd:2-8; televisions_objective.gd:2-6). Que la etapa cierre cuando todos los objetivos que pide están listos y los vivos están dentro es lo que dice el diseño (GAME_DESIGN.md:33, 41, 53, 59, 61); el código de esa comprobación no se ha leído.
- Oficinas, nivel 2: el montacargas solo baja si el cuadro está armado y van el mínimo (power_objective.gd:326-328, `allows_ride`).
- Oficinas, nivel 3: la escalerilla solo baja si hay en el pozo el mínimo de vivos (air_objective.gd:283, 330).
- Captura: el jugador queda fuera hasta la siguiente etapa, donde vuelve de pie (GAME_DESIGN.md:63).
- Hundimientos perdonados: el perfil `restarts` de la dificultad (difficulty.gd:97, 112, 127, 142; ver 4.2). Si quedan menos vivos que el mínimo, el intento termina (GAME_DESIGN.md:63).
- Versus: el cazador gana con «CAZA COMPLETA» si quedan menos supervivientes que el mínimo, y pierde con «SE TE ESCAPARON» si salen del piso (GAME_DESIGN.md:196).

### 3.6 Objetivos: qué pide cada uno

Todos extienden `objective.gd` y tienen `level` (el nivel que los posee). `progress(stage)` devuelve `{ready, done, needed, kind, lines, extra}`. `idle()` devuelve «no aplica» (objective.gd:35-36).

- **televisions** (televisions_objective.gd): cuenta los televisores encendidos del ala de la etapa (`tvs.stage_televisions(stage)`, línea 21). `needed = TV_PLACEMENT.needed(session.roster_count)` (línea 23, función no leída). `ready = done >= needed` (línea 27). Línea de pantalla «TELEVISORES done / needed». `tick` (41-56): llama a `creature_channel_hop`; si la etapa pide televisores y la regla `blackout` es 1, cuando `done >= needed - 1` marca `session.goal["blackout"]`, llama `ledger.note_dark()` y emite `session.changed` (líneas 53-56).
- **code** (code_objective.gd): `ready = level.code.code_entered` (línea 19). `done` = números encontrados; `needed = DIGITS.COUNT` (línea 19; `digit_placement.gd`, no leído; el diseño dice 4, GAME_DESIGN.md:53). Línea «NÚMEROS DEL CÓDIGO». Sin mobiliario con número (`containers` vacío), queda «no aplica» (línea 18).
- **files** (files_objective.gd:648-661): `ready = swiped.size() >= session.minimum_survivors()`. Línea «FICHAS n / cuota». Línea «TU FICHA» con estación, «EN CAMINO», «EN LA BANDEJA», «EN LA MANO» o «PASADA». Las fichas se pasan por el lector junto al ascensor de carga.
- **power** (power_objective.gd:330-334): `ready = red == ARMED`. `done = on_order.size()`; `needed = budget` (3). Líneas «ZONAS done / budget» y, mientras corre, «MONTACARGAS n s».
- **air** (air_objective.gd:439-441): `ready = hatch_open`. `done = int(post_open) + int(released) + int(hatch_open)` de 3. Línea «CARGAS charges».

## 4. Dificultad (game/floors/difficulty.gd)

### 4.1 Uso y orden

- `ORDER` = apacible, equilibrada, desafiante, pesadilla (difficulty.gd:20). `REFERENCE` = desafiante, el juego de antes de las dificultades (difficulty.gd:22). `FIRST` = equilibrada, la primera vez (difficulty.gd:24). Nombres (difficulty.gd:26).
- `valid(id)` (186-187): un id desconocido cae en desafiante. `profile(id, creature)` (192-199): perfil compartido más lo propio de la criatura por encima; si la criatura no tiene perfil propio (The Locust), usa el compartido tal cual. `value(id, key)` (201-202). `title` (204-205). `rank` (208-209): de 0 a 3.
- Lo que toca (difficulty.gd:15-18): solo la criatura y el perdón. Aura, pantalla, cordura, apagón, teles sobrantes y notas son reglas del piso (match_rules.gd).
- Rasgos de cada una, las cuatro líneas que lee el jugador (difficulty.gd:36-41).

### 4.2 Perfil compartido (`PROFILES`, difficulty.gd:84-143)

Cada bloque tiene las mismas claves en el mismo orden. La línea de una clave es la base del bloque más k: Apacible 85, Equilibrada 100, Desafiante 115, Pesadilla 130, más k.

| k | Clave | Apacible | Equilibrada | Desafiante | Pesadilla | Comentario de la clave (difficulty.gd:43-82) |
|---|---|---|---|---|---|---|
| 0 | sight_range | 55 | 60 | 70 | 85 | alcance de la vista, m |
| 0 | notice | 0.6 | 0.8 | 1.0 | 1.3 | multiplicador de fijarse |
| 0 | hearing | 0.7 | 0.75 | 1.0 | 1.2 | multiplicador de la tabla de ruidos |
| 0 | torch_range | 35 | 40 | 45 | 55 | m a los que la linterna la atrae |
| 1 | alert_time | 2.0 | 1.5 | 1.2 | 0.8 | s de aviso antes de perseguir |
| 1 | chase_start | 2.0 | 2.3 | 2.5 | 3.0 | velocidad inicial de persecución, m/s |
| 1 | chase_accel | 1.8 | 2.6 | 3.2 | 4.0 | aceleración, m/s2 |
| 1 | chase_speed | 6.0 | 6.0 | 6.4 | 6.7 | velocidad de caza, m/s |
| 1 | track_speed | 4.0 | 4.6 | 5.2 | 5.6 | velocidad de seguimiento, m/s |
| 2 | lose_after | 3.0 | 5.5 | 7.0 | 10.0 | s sin verte antes de dejar la persecución |
| 2 | give_up | [4, 6] | [7, 9] | [8, 10] | [12, 15] | s sin pistas antes de rendirse (intervalo) |
| 2 | peek_chance | 0.0 | 0.1 | 0.2 | 0.5 | probabilidad de abrir un armario al azar |
| 3 | attack_range | 1.6 | 2.0 | 2.4 | 2.6 | m; dentro, te tiene al instante |
| 3 | recover | 1.0 | 0.7 | 0.6 | 0.5 | s para rehacerse si falla |
| 3 | wardrobe | 1.28 | 1.12 | 1.0 | 0.8 | multiplicador del tiempo de abrir un armario |
| 4 | grace | 25 | 20 | 15 | 10 | s de gracia al empezar |
| 4 | tv_hop | 0 | 40 | 25 | 12 | s entre saltos por televisores (0: nunca) |
| 4 | lift_wait | 25 | 20 | 15 | 10 | s que espera en el vestíbulo |
| 4 | lift_hold | 30 | 25 | 20 | 12 | s desde que las puertas se abrieron abajo |
| 5 | lead_every | [30, 45] | [28, 42] | [25, 40] | [18, 30] | s entre pistas del director (intervalo) |
| 5 | prowl_min | 20 | 19 | 18 | 14 | m, distancia mínima a la que la manda el director |
| 5 | peak_max | 15 | 20 | 25 | 35 | s máximos de «pico» (cerca, manos fuera) |
| 5 | peak_tense | 10 | 12 | 15 | 22 | s de pico tenso |
| 6 | rest_chase | 35 | 35 | 30 | 20 | s de respiro tras una persecución |
| 6 | rest_death | 55 | 50 | 45 | 30 | s de respiro tras una muerte |
| 6 | death_ease | 10 | 9 | 8 | 4 | m que la aleja cada muerte reciente |
| 6 | double_back | 0.0 | 0.2 | 0.4 | 0.7 | proporción de retiradas que vuelven |
| 7 | distract_rest | 30 | 45 | 45 | 90 | s entre distracciones |
| 7 | burnt_every | [60, 90] | [45, 60] | [30, 45] | [20, 30] | s entre rondas con la cordura a cero (intervalo) |
| 8 | doubt | 1.2 | 0.6 | 0.0 | 0.0 | s que se queda mirando antes de reaccionar (0: ninguno) |
| 8 | chase_tire | 7.0 | 12.0 | 0.0 | 0.0 | s de persecución tras los que se cansa (0: nunca) |
| 8 | lost_cry | true | true | false | false | gruñido al rendirse |
| 8 | guess_hides | false | true | true | true | abre un armario que no vio ocupar |
| 8 | encounter_every | 150 | 150 | 0 | 90 | s sin encuentro tras los que el director provoca uno (0: nunca) |
| 8 | cross | 2.0 | 1.2 | 0.0 | 0.5 | ganas de cruzarse a la vista (0: no lo hace) |
| 9 | feint | 0.0 | 0.25 | 0.4 | 0.6 | probabilidad de esperar a que salga en vez de abrir |
| 9 | feint_wait | [8, 10] | [8, 11] | [9, 13] | [11, 15] | s que espera en la finta (intervalo) |
| 10 | calm | 100 | 80 | 0 | 0 | s que crece el descanso tras mucho trajín (0: fijo) |
| 10 | solo_ease | 1.6 | 1.4 | 1.0 | 1.0 | cuánto más separado va todo jugando solo |
| 10 | ambush | 0.0 | 0.7 | 2.0 | 2.0 | gusto por esperar en lo que el equipo tiene que hacer |
| 11 | sight_angle | 45 | 54 | 60 | 60 | grados que ve a cada lado de donde mira |
| 11 | cover | 0.6 | 0.45 | 0.0 | 0.0 | parte del cuerpo que tiene que verse (0: cualquiera) |
| 11 | glimpse | 4.0 | 2.0 | 0.0 | 0.0 | s que un cuerpo parcial tiene que estar a la vista |
| 11 | tired | 4.0 | 3.0 | 3.0 | 3.0 | s en que no hace caso a nadie tras cansarse |
| 12 | restarts | -1 | 2 | 1 | 0 | etapas perdonadas en equipo (-1: sin límite) |
| 12 | solo_restarts | -1 | 1 | 0 | 0 | etapas perdonadas a solas |

Las líneas por clave, por ejemplo `restarts`: difficulty.gd:97 (apacible), 112 (equilibrada), 127 (desafiante), 142 (pesadilla). `grace` está en 89, 104, 119 y 134.

### 4.3 Perfil propio de The Lurker (`CREATURE_PROFILES`, difficulty.gd:175-182)

Se superpone al perfil compartido para la criatura `lurker` (difficulty.gd:176-180: apacible 177, equilibrada 178, desafiante 179, pesadilla 180). Claves y valores:

| Clave | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| back_window (s desde su aviso a tu espalda hasta la captura) | 2.2 | 1.5 | 0.9 | 0.9 |
| lit_takes (captura también en sala con luz) | false | true | true | true |
| duct_speed (m/s en los ductos) | 1.2 | 1.6 | 2.4 | 2.8 |
| stalk_distance (m que guarda al acechar) | 12.0 | 8.0 | 4.0 | 3.5 |
| creep_scale (x velocidad mínima con que se acerca) | 0.8 | 0.9 | 1.5 | 1.7 |
| drain_reach (m desde una lámpara a la que la bebe) | 3.0 | 3.0 | 4.0 | 4.5 |
| unseen_speed (m/s sobre superficie sin que la vean) | 3.0 | 3.5 | 4.5 | 5.0 |
| unseen_duct (m/s en un ducto oculto sin que la vean) | 3.0 | 4.2 | 5.8 | 5.8 |
| attempts (intentos fallidos con un superviviente antes de dejarle) | 2 | 3 | 5 | 6 |
| encounter_rest (s que deja en paz tras un encuentro) | 120 | 90 | 45 | 30 |
| emerge_delay (s en el techo antes del siguiente intento) | [8, 12] | [4, 7] | [1, 2] | [0.7, 1.5] |
| emerge_mode | far | near | behind | behind |
| emerge_range (m de ellos donde vuelve a salir) | [10, 15] | [6, 10] | [3, 5] | [3, 4.5] |
| haunt (probabilidad de rondar cerca de donde supo de alguien; sin comentario en el código, ver OFICINAS.md §4) | 0.35 | 0.6 | 0.9 | 1.0 |
| forced_after (s sin atrapar a nadie antes de llevarla a una sala; 0: nunca) | 0 | 70 | 30 | 20 |
| stalk_time (s de acecho antes del silencio) | [25, 40] | [15, 25] | [4, 9] | [3, 6] |
| peek_odds (probabilidad de asomarse mientras acecha) | 0.7 | 0.5 | 0.15 | 0.1 |
| hush (s de silencio) | 3.0 | 2.5 | 1.5 | 1.0 |
| noise_react (s antes de que un ruido la gire) | 4.0 | 2.0 | 0.0 | 0.0 |
| sated (s sin tocar a los que están cerca de una captura) | 60 | 40 | 20 | 12 |
| approach_cap (m/s máximos al acercarse; por debajo de la carrera del superviviente, `survivor_gait.SPEED_RUN` menos 0,5; difficulty.gd:168) | 3.0 | 3.5 | 4.5 | 5.0 |
| torch_drunk (s que una linterna que la asustó se queda «bebida») | 0 | 3 | 10 | 14 |
| snuff_time (s acechando a alguien en sala iluminada antes de beberla a oscuras) | 0 | 12 | 4 | 2.5 |
| torch_kill (probabilidad de que una linterna que bebe se apague del todo) | 0 | 0.25 | 0.6 | 0.8 |
| ambush_odds (probabilidad de que un acecho empiece como emboscada) | 0.15 | 0.3 | 0.6 | 0.7 |

Comentario de la fuente (difficulty.gd:146-174): la tabla viene de `docs/OFICINAS.md` sección 4; `back_window` no baja de 0,9. Según `docs/DIFFICULTY.md:266`, el autor guardó como «desafiante» la Pesadilla que jugó el 11 de noviembre de 2026, y la «pesadilla» de hoy es una fila nueva. La tabla de `docs/OFICINAS.md` §4 (líneas 398 a 440) coincide con `difficulty.gd` fila a fila, salvo `creep_scale` (apartado 4.4, punto 7). La fila «primera etapa a oscuras» de esa tabla no está en `difficulty.gd`: vive en `office_geometry.darken_first_stage` (no leído).

### 4.4 Discrepancias entre documentos y código (sin decidir)

El código manda en el juego. Lo siguiente va para que alguien decida.

1. Oído: `docs/DIFFICULTY.md:51` dice ×0,85 (apacible) y ×0,9 (equilibrada). `difficulty.gd:85` y `:100` dan 0.7 y 0.75.
2. Encuentro garantizado: `docs/DIFFICULTY.md:76` dice 1,5 min (apacible) y 2 min (equilibrada). `difficulty.gd:93` y `:108` dan 150 s para ambas (2,5 min). Pesadilla coincide: 90 s (`:138`).
3. Respiros: `docs/DIFFICULTY.md:81` dice 20 s / 40 s (apacible) y 30 s / 50 s (equilibrada). `difficulty.gd:91` y `:106` dan rest_chase/rest_death 35/55 y 35/50.
4. Pista del director (`lead_every`): `docs/DIFFICULTY.md:77` dice 20–30 s (apacible) y 25–35 s (equilibrada). `difficulty.gd:90` y `:105` dan [30, 45] y [28, 42]. La correspondencia fila a clave es inferencia mía.
5. Cercanía del equipo (`prowl_min`): `docs/DIFFICULTY.md:78` dice 14 m y 16 m. `difficulty.gd:90` y `:105` dan 20 y 19. Correspondencia inferida, igual que en 4.
6. Protección al empezar: `docs/GAME_DESIGN.md:49` dice «12 como mínimo» para pesadilla. `difficulty.gd:134` y `docs/DIFFICULTY.md:66` dan 10 s.

7. `creep_scale` de The Lurker: `difficulty.gd:177-180` lo define como multiplicador («x the least speed she closes in at»), y `docs/OFICINAS.md` §4 lo muestra en m/s («0,8 m/s», «1,7 m/s»). Los números son los mismos; la unidad del documento no es la del comentario del código.

Coinciden con el código: alcance de vista, notice, torch_range, alert_time, arranques, velocidades de caza, lose_after, give_up, attack_range, recover, chase_tire, double_back, distract_rest, burnt_every, feint, feint_wait, lift_wait, lift_hold, peak_max, death_ease, restarts (cooperativo e individual), tv_hop.

## 5. Cómo se define un piso (interfaz de un piso nuevo)

Lo que el código pide hoy a un piso nuevo, con sus referencias:

1. Una línea en `KINDS` de `floor_index.gd` (7-10). Entrar en `RELEASED` el día que se publica (16). Subir `COUNT` si hace falta (18).
2. Un script con estas constantes (mismas que `hotel_floor.gd` y `office_floor.gd`): `NUMBER`, `NAME`, `GENERATOR` (generador), `VALIDATOR`, `GEOMETRY`, `GENERATOR_VERSION`, `PALETTE`, `CREATURE` (ruta de la escena, cargada al ponerla), `CREATURE_KEY` (clave de `difficulty.gd` y de `match_rules.gd`), `FIRST_LEAD`, `PAPERS`, `PAR`, `MILESTONES`, `STAGES`, `OBJECTIVES` (nombre a ruta del script). Solo en oficinas: `LEAVE` (hotel_floor.gd:19-42, 46-87; office_floor.gd:9-65).
3. Funciones estáticas: `count()`, `stage(n)`, `title_of(n)`, `asks(n, objetivo)`, `stages_asking(objetivo)` (hotel_floor.gd:89-111; office_floor.gd:67-88, misma forma).
4. Por cada objetivo, un script que extiende `objective.gd` y usa `level`. Puede tener `settle(manifest, supervivientes, tipo)` estática antes de construir (objective.gd:13-16), `place()` (21), `reset()` (26), `progress(etapa)` (32), `goal_points(etapa)` (39-41), `snapshot()` y `restore()` (111-113), `tick(delta)` (107), `allows_ride(etapa, pasajeros)` (104), `bot_errands(equipo)` (73), `on_death(asiento, punto)` (76), `paper_of(índice)` (79), `snapshotted()` (66), `sound_mask(punto)` (69), `own_papers(asiento)` (100).
5. Paleta: tiene que tener todos los nombres de `hotel_palette.gd` (office_palette.gd:5-7, comprobado por `tests/office/office_test.gd`). Lo que no usa, lo deja en el valor del hotel o vacío, y lo dice.
6. Criatura: una clave en `CREATURE_PROFILES` si tiene perfil propio (difficulty.gd:146-150).
7. Reglas de la sala: una regla puede limitarse a un piso (`kind`) o a una criatura (`creature`) (match_rules.gd:22-26).
8. Versión del generador para la red (floor_index.gd:47-52).

## 6. Previsto y sin hacer

- Pisos 3 y 4 sin criatura: `docs/LORE.md:15-18` (Radiation Lab, sin criatura; The Containment, sin criatura, donde estaba guardado The Locust). `docs/LORE.md:71`: las cuatro criaturas previstas eran The Locust, Sunman, The Boiled One y Guilt; The Locust tiene el piso 1 y The Lurker el 2; las otras tres siguen sin piso.
- `docs/LORE.md:74-81`, «Por decidir»: qué criaturas llevan los pisos 3 y 4; qué son «los cuatro» del título; cómo se llama el ente y cómo se le nota; del archivero; quién juega y por qué baja; en qué año pasa cada cosa; cómo acaba (qué hay al fondo de The Containment).
- `docs/GAME_DESIGN.md:7`: siguen sin existir los otros tres pisos y sus criaturas, y las animaciones definitivas de los supervivientes. `:16`: los cuatro pisos son el hotel, las oficinas secretas, Radiation Lab y The Containment.
- `docs/GAME_DESIGN.md:306`: las campañas de dos y cuatro jugadores necesitan los otros tres pisos.
- `docs/PLAN.md`, sección 5 (líneas 820-904): tabla de estado (piso 3 y 4, «Sin asignar / Sin empezar»); tareas `four-7ly.1` a `.11`: decidir criaturas (.1), piso 2 (.2), Radiation Lab (.3), The Containment (.4), Sunman (.5), The Boiled One (.6), Guilt (.7), perfiles sonoros (.8), tres conjuntos procedurales con mil semillas cada uno (.9), campaña de cuatro pisos con checkpoints, reaparición y victoria final (.10), campañas de dos y cuatro jugadores sin bloqueos (.11).
- Criaturas pensadas y sin piso (`docs/GAME_DESIGN.md:230-232`): Sunman, aviso 2 s, barrido 4 s, descanso 6 s, exposición +25/s, recuperación −20/s tras 1 s protegido, aviso a 70 y captura a 100. The Boiled One, mirada central de 25°, exposición real tras 0,5 s, intrusión +18/s, recuperación −12/s, avisos a 60 y 85, captura a 100. Guilt, señuelos +20 de presión, aviso a 60, cacería anunciada de 20 s a 100, reducción a 60 tras sobrevivir.
- Piso 2, acabado pendiente (`docs/PLAN.md`, sección 5): «provisional en arte, sonido y acabado». Pendiente de la fase 4e (10 de noviembre de 2026): revistas de las mesitas de espera (`.claude/specs/spec_4e.md`, decisión 6), manchas de agua y expediente a medio sellar (`docs/OFICINAS.md` sección 8), según `docs/PLAN.md`.
- Dificultad: fases 3 (valores), 5 (conductas y números de pesadilla), 7 (marcas), 8 (con gente) siguen pendientes (`docs/DIFFICULTY.md:282-289`). Las conductas de la pesadilla de la criatura del hotel están sin hacer (DIFFICULTY.md:286).
- Pesadilla de The Lurker: «a afinar jugando» (`docs/DIFFICULTY.md:266`).
- Piso 2, criatura, decisión del 24 de octubre de 2026 («Más agresiva», `docs/OFICINAS.md` §4): avisa desde hasta 5 m y su salto largo llega a 7,5 m. El código de la criatura no se ha leído.

## 7. Decisiones del autor con fecha (constan por escrito)

- 4 de octubre de 2026: Desafiante es el juego de hoy, sin tocar un número (DIFFICULTY.md:295; difficulty.gd:10-13). De fábrica, Equilibrada (DIFFICULTY.md:272, 296; difficulty.gd:24). El perdón cambia con la dificultad (DIFFICULTY.md:297). La dificultad toca solo a la criatura y al perdón (DIFFICULTY.md:298; difficulty.gd:15-18). El aura no cambia (DIFFICULTY.md:300). No se cambia de dificultad a mitad de un piso (DIFFICULTY.md:301).
- 5 de octubre: a solas, la etapa vuelve a empezar como en equipo (DIFFICULTY.md:304). Un piso no se repite nunca tras perderlo; Reintentar empieza otro piso (DIFFICULTY.md:305; GAME_DESIGN.md:77).
- 12 de octubre: Equilibrada individual pasa de 2 a 1 etapa devuelta (DIFFICULTY.md:96, 209). Se quita la estocada lenta: el golpe es instantáneo en las cuatro (DIFFICULTY.md:68 y 114).
- 13 de octubre: las dos fáciles corren a 6,0 m/s (DIFFICULTY.md:68). Las cuatro líneas de cada dificultad (difficulty.gd:28-30; DIFFICULTY.md:111). Los relojes del hotel andan y marcan la hora de la cinta (GAME_DESIGN.md:105). Regla de la cansada: se va y, si vuelve a ver a alguien, lo persigue (DIFFICULTY.md:112).
- 20 de octubre: el tamaño de cada planta depende de los supervivientes (hotel_palette.gd:37; GAME_DESIGN.md:111). Carteles de salida, distancias de la primera planta (GAME_DESIGN.md:27). La primera planta sale a 150 m walking como mínimo (hotel_palette.gd:149-150; GAME_DESIGN.md:115). Pistas de la etapa 3: ocho papeles que dicen dónde están (GAME_DESIGN.md:55, decisión del 20 de octubre).
- 21 de octubre: The Lurker (LORE.md:45). Los papeles de la maleta: como mucho uno por piso (GAME_DESIGN.md:53).
- 22 de octubre: el piso 2 se aprueba y se juega desde el piso 1 (GAME_DESIGN.md:17). La llave de los cuadros eléctricos (GAME_DESIGN.md:47). La tiza se quita (GAME_DESIGN.md:55).
- 24 de octubre: el minutero de la planta 2 aleja a la criatura como las zonas del cuadro (power_objective.gd:220-222). La oscuridad por dificultad en la primera etapa del piso 2 (office_dark_test, cabecera).
- 11 de noviembre de 2026: las claves de The Lurker (DIFFICULTY.md:266; difficulty.gd:146-174).
- 12 de noviembre de 2026: las particiones de 1,2 m (office_palette.gd:522); la fila de armarios en las naves (office_palette.gd:676-677).
- 14 de noviembre de 2026: los pasillos y vestíbulos de llegada con vinilo encerado, no terrazo oscuro (office_palette.gd:787).
- Otras decisiones de piso 2 (25 de octubre, rediseño de la generación): `docs/PLAN.md`, sección 5.

### 7.1 Decisiones de `docs/OFICINAS.md` sección 14 (22 y 24 de octubre de 2026; 12 de noviembre)

Lo que consta por escrito en OFICINAS.md, §14 (tabla de «Decidido» y lista del 24 de octubre):

- Se continúa desde el piso 1. Una vez desbloqueado, se elige el piso 2 en la dificultad en que se desbloqueó. Hecho el 12 de noviembre: al ganar el piso 1 aparece «Bajar al piso 2» (en solitario, y para el anfitrión en cooperativo), y en «Nueva partida» aparece «Piso 2» junto a cada dificultad alcanzada, guardado en el ajuste `floor2`. Prueba: `tests/office/descend_test.gd`. El piso sigue sin publicar en `floor_index.RELEASED` (§14, punto 12).
- Restos de personas en todos los pisos (§14, punto 2; también en `docs/LORE.md`). El cuerpo se queda en el suelo (punto 3).
- Puertas las del hotel; falso techo a 2,95 m (punto 9).
- Coger de espaldas en una sala con luz: sí, tras el aviso, salvo en Apacible (punto 10). Coincide con `lit_takes`.
- Avisos de espalda falsos: no, por ahora (punto 11).
- No hay llave de cuadros eléctricos en el piso 2 (punto 13).
- Del 24 de octubre (fases 2 y 3): en salas altas va por paredes y techo y salta desde el techo con un salto largo; se encoge bajo muebles altos (se mide en el juego); alejarse durante el aviso salva solo corriendo; hay aviso desde arriba en salas altas; su cara a oscuras solo se ve de muy cerca; los golpes del director en puertas se quedan en el piso 2; sus codos esquivan lo que tiene colisión; el vano se tapa a altura de cabeza; el plénum es una capa oculta sobre las placas; su nido en la planta 3 es la sala de climatización; entre plantas tarda lo del montacargas; no abre taquillas; bebe la luz también desde un ducto, nunca en vestíbulos; la mirada con luz de un compañero también salva; cuenta solo la latencia de la víctima, hasta 0,5 s; acechar tiene palabra propia.
- Abierto, menor (§14): si la foto de la ficha en red la saca cada máquina o con el avatar remoto; las cifras de cada planta (estaciones, presupuesto K, relojes, cargas de los ventiladores, largo del ducto), que se afinan con bots y con gente.

### 7.2 Lo que `docs/OFICINAS.md` §11.2 dice que debe tener un tipo de piso (contraste con el apartado 5)

- El script de tipo suma `GENERATOR`, `VALIDATOR`, `GEOMETRY`, `PALETTE`, `CREATURE`, `CREATURE_KEY`, `OBJECTIVES`, `PAPERS` y `GENERATOR_VERSION`. `floor_index.KINDS = {1: hotel, 2: office}`.
- Las paletas llevan los números de tipo de sala y las constantes de estructura que hoy están en `floor_definition`, `map_generator`, `map_validator`, `hotel_geometry`, `room_dressing`, `prop_factory`, `world_audio`, `blood`, `code_lock` y `hint_placement`. Los papeles estructurales conservan su número en las dos paletas (0 inicio, 9 rellano, 10 vestíbulo, 11 pasillo, 12 galería, 19 refugio, 20 vacío). Esto sí se ve en `hotel_palette.gd:13-22` y `office_palette.gd:107-114`.
- El número de piso viaja en `game_session` (etapas y punto de control), en la configuración de red (`floor`), en el registro de versiones y en `PROTOCOL`; y `--floor=N` lo fija para pruebas y herramientas. Nada de esto se ha leído en el código.
- La salida de cada planta también es un manejador (refugio en el hotel; montacargas o pozo en el piso 2). En el código del piso 2 solo aparece `LEAVE := "ladder"` (office_floor.gd:65); el ascensor de carga está en `lifts.gd`, no leído.
- Dificultad y reglas por criatura: `CREATURE_PROFILES[&"lurker"]` añade sus claves; rasgos y reglas se filtran por la criatura del piso (difficulty.gd:146-150; match_rules.gd:22-26).

## 8. Cifras que definen cómo se siente o se ve (ruta:línea)

### 8.1 Hotel: tamaño, forma y oscuridad (hotel_palette.gd)

- Área por número de supervivientes: 1 → 0,5; 4 → 1,2; 5 → 1,35 (`AREA`, línea 37). Alone: la primera planta queda como la de dos o tres (51-53).
- Habitaciones por planta: 81 a 99 (`ROOMS`, 42). Con número en la puerta, como mucho 96 (`NUMBERED_MOST`, 43).
- Televisores por planta de la etapa 2 y 3: 6 si el área es menor que 1, si no 8 (`tv_rooms`, 61-62). Anillos: 4 o 6 (`rings`, 64-65).
- Alturas (`HEIGHTS`, 108): 4,2 m para recepción, lounge, comedor, jardín y salón vacío; 3,15 m el resto. Salón de varios módulos: 4,8 m (`HALL_HEIGHT`, 109).
- Oscuridad propia por planta (`DARK_OWN`, 185): 0,23 / 0,29 / 0,36. Contagio a salas vecinas (`DARK_SPREAD`, 186): 0,45. Pasillos (`DARK_CORRIDOR`, 187): 0,03 y 0,05. Salas que no se apagan nunca (`NEVER_DARK`, 112).
- Desgaste (`WEAR`, 190; `KEPT`, 191): 0,25; kept entre 0,25 y 0,55.
- Pasillos expuestos (`EXPOSED`, 167; `EXPOSED_CHANCE`, 168; `EXPOSED_LONGEST`, 170): 0/30/50 m con probabilidad 0/0,5/1; máximo 90 m.
- Primera planta: refugio a 150 m andando como mínimo (`FIRST_WALK`, 150); profundidad del refugio 0,55 a 0,9 y 0,65 a 0,9 en la primera (`DEPTH` 144, `FIRST_DEPTH` 149).
- Salones por planta (`HALLS`, 154): de 2 a 6.
- Puertas: posiciones en la pared (`DOOR_PLACES`, 176): 0; 0; 1,5; -1,5; 2; -2 (las de dormitorio, 177).
- Mobiliario por corner: `RECIPES` (80-102). Muebles por tipo de sala: `MODULE_SET` (219).
- Ancho de módulos: `MODULE_SIZES` 12–16 m (126); carriles `LANE_WIDTHS` 3–4 m (127).
- Estado de la sala: `HARD_FLOORS` (71): baños, lavandería, mantenimiento. Luces: batten en 4, 7, 8, 9 (`BATTEN_ROOMS`, 212); lámpara de araña si mide más de 4 m salvo recepción (`CHANDELIER_HEIGHT`, 215).

### 8.2 Hotel: lo que dice el diseño (docs/GAME_DESIGN.md)

- Escena de entrada: unos 40 s; se salta manteniendo E (GAME_DESIGN.md:23).
- Ascensor: viaje de 8,5 s; el coche tarda 15 s en volver; el vestíbulo espera 15 s y 20 s desde que se abrieron abajo; según el texto, la criatura va al coche a trote, 4 m/s, y tarda entre 15 y 111 s en cruzar la planta (mediana unos 32 s; GAME_DESIGN.md:33).
- Refugios y vestíbulos protegen de pared a pared (GAME_DESIGN.md:35).
- Etapa 2: televisores a más de 25 m del vestíbulo o al 20 % del camino más largo; mínimo dos y dos de más (GAME_DESIGN.md:41).
- Etapa 3: cuatro números a más de 30 m o al 25 %; uno pasado el 80 % del camino (GAME_DESIGN.md:53).
- Cordura (GAME_DESIGN.md:67-71): baja a oscuras en 7,5 min y con linterna en casi 20 min; la linterna frena la bajada a 0,4 (×0,4); recuperarla pide 4 min de luz; de refilón, 4 puntos; de cara, a menos de 30°, 15 puntos; descanso de 5 s; por debajo de 60 el piso miente; para dejar de soltar alucinaciones hay que subir por encima de 25 (un minuto de luz); frecuencia de alucinaciones sonoras de una cada 40 s a una cada 13 s; a cero aparecen motas rojas.
- Puerta de acceso cerrada hasta cumplir la etapa; se abre sola y no vuelve a cerrar (GAME_DESIGN.md:57).
- Mínimo `ceil(N/2)` (GAME_DESIGN.md:59).
- Captura (GAME_DESIGN.md:63).
- Versus: caza a 6,4 m/s; anda a 2,8 m/s; caza unos 15 s seguidos; se recupera en unos 4,5 s (GAME_DESIGN.md:187). Estocada a 3,2 m, dentro de 70° (189). Chillido de unos 4 s; se puede repetir a los 10 s, dura unos 6 (192).

### 8.3 Oficinas: objetivos (constantes en el código)

- `files`: `PICK_TIME` 1,0 s (files_objective.gd:21); `TYPE_TIME` 5,0 s (24); `TAKE_TIME` 1,5 s (25); `SWIPE_TIME` 0,5 s (26); `SEND_DELAY` 1,2 s (28); `CAPSULE_SPEED` 6,0 m/s (29); `USE_REACH` 2,5 m y `SLACK` 0,5 (30-31); `STATION_LAMP` (1,0; 0,62; 0,25) (32); `PHOTO_SIZE` 240 × 304 (57); `TYPE_PHOTO_AT` 0,6 (58); `PHOTO_QUALITY` 0,7 (60); `PHOTO_MAX_BYTES` 24576 (61); `TUBE_RADIUS` 0,055 m (64); `DESK_TOP` 0,755 (68); `CAMERA_LENS` (0; 0,1; -0,175) (71); cápsula de radio 0,045 y alto 0,26 (files_objective.gd:263-264); luz de la estación `omni_range` 1,5, energía 0,6 (113-116); cámara de la foto con `fov` 48 (406) y `cull_mask` 1048573 (409); tono de la foto: gris con pesos 0,3 / 0,59 / 0,11, grano ±0,05 y tinte (×0,92; ×1; ×0,9) (429-431).
- `power`: `RED_HOLD` 1,0 s (power_objective.gd:21); `USE_REACH` 2,5 m, `SLACK` 0,5 (22-23); `BOARD` (2,6; 1,9; 0,12) m (25); `LEVER_Y` 1,35 (26); `LEVER_PITCH` 0,3 (27); `RED_GAP` 0,2 (28); `LEVER_SWING` 70° (29); `budget` 3 (39); `lift_timer` 60 s (40); `switch_time` 75 s (41); luz de la palanca roja `omni_range` 0,7, energía 0,25 (115-118).
- `air`: `HATCH_TIME` 2,0 s (air_objective.gd:24); `CLIMB_HOLD` 0,5 (25); `LADDER_HOLD` 1,2 (26); `CLIMB_UP` 2,4 s (27); `CLIMB_DOWN` 2,0 s (28); `USE_REACH` 2,5 y `SLACK` 0,5 (31-32); `POST_SWIPE` 0,5 (38); `START_HOLD` 1,0 (39); `STOP_HOLD` 1,0 (40); `FAN_SPIN` 2,5 s (41); `AIR_MASK` 0,65 (42); `MOUTH_REACH` 1,0 m (44); `HATCH_SWING` 100° y `SWING_TIME` 1,0 s (46-47); `charges` 2 (51); `fan_time` 80 s (52); rotación de los ventiladores 18 (tick, 382); `sound_mask` = 0,65 × giro (254-255).

### 8.4 Oficinas: planta y techo (office_palette.gd)

- Rejilla de techo: `TILE` 0,6 m (1003); troffer cada 3 m (`TROFFER_PITCH`, 1004); `WALL_HALF` 0,09 (1006); `GRILLE_CLEAR` 0,9 (1007); `GRILLE_WALL` 1,0 (1008); columnas 0,6 m (`COLUMN`, 280) a 2,1 m del eje de la nave (`COLUMN_OFF`, 281); pasillo de la nave 3,0 m (`NAVE_AISLE`, 272).
- Plenum (409): cielo falso 2,95 m; forjado 4,4 m; conducto de 3,7 m; principal 1,2 m; conducto 1,0 × 0,8; ramal 0,5 × 0,3.
- Temperatura de color de las lámparas, en kelvin (`LAMP_KELVIN`, 393): 2700 a 3500 según sala.
- Mobiliario sobre 2,2 m (`FURNITURE_TOP`, 455). Módulos de 6 a 9 m (`MODULE_SIZES`, 241). Pasillos 2,4 a 3,6 m (`LANE_WIDTHS`, 242).
- Estaciones de correo: 8 a 14 (`STATIONS`, 414); separación 15 m × √área (`STATION_APART`, 416); tubo mínimo 25 m (`STATION_TUBE_MIN`, 418).
- Ducto principal: longitud 25 a 45 m (`MAIN_LENGTH`, 419); ideal 35 m (`MAIN_IDEAL`, 420); 2 codos (`MAIN_BENDS`, 421). Escalerilla del pozo 2,2 × 2,2 m (`SHAFT`, 431). Climatizadora 3,0 × 2,2 × 1,5 m (`AIR_UNIT`, 433).
- Hueco sin lámpara (`GAP_SHARE`, 437): 3 %, 4,5 %, 6 % por planta.
- Anchos de pasillo de cámara: `HALL_WIDTH` 3,0; `HALL_STEP` 5 a 8 m (810-815).

## 9. Motor: clases y nodos que usa esta parte (apariciones aproximadas)

Recuento por grep de `X.new(` en `game/floors/` (todos los archivos):

| Clase | Apariciones | Dónde se ve (archivo) |
|---|---|---|
| MeshInstance3D | 6 | objective.gd:87 entre ellos (`pin_memo`) |
| Node3D | 3 | sin desglosar |
| OmniLight3D | 3 | power (2), files (1) |
| StandardMaterial3D | 4 | objective.gd:91 entre ellos |
| MultiMeshInstance3D | 2 | files (tubos, collares) |
| MultiMesh | 2 | files |
| BoxMesh | 2 | air (hoja), files (tarjeta caída) |
| QuadMesh | 1 | objective (hoja de memo) |
| CylinderMesh | 1 | files (tubo) |
| CapsuleMesh | 1 | files (cápsula) |
| Label3D | 1 | objective (`plate_text`) |
| StaticBody3D | 1 | air (hoja de la compuerta) |
| CollisionShape3D | 1 | air |
| BoxShape3D | 1 | air |
| Camera3D | 1 | files (foto) |
| SubViewport | 1 | files (foto) |
| Image | 1 | files (foto) |
| RandomNumberGenerator | 2 | files (grano y estación) |
| USABLE / office_usable (clase propia) | 5 | files, power, air (se cuentan aparte) |

Tipos mencionados en declaraciones (no siempre con `.new()`): Node3D (10), MeshInstance3D (9), Node (2), Label3D (2), OmniLight3D (3), ImageTexture (3), SubViewport (3), Image (2), StaticBody3D (2), MultiMesh (4), MultiMeshInstance3D (2), PhysicsRayQueryParameters3D (1), CollisionShape3D (1), Camera3D (1), GDScript (3). Tipos de valor usados con mucha frecuencia: Vector3 (179), Dictionary (147), Array (126), Vector2 (86), Transform3D (38), Basis (30), Vector2i (30), Color (21), Rect2 (20), AABB (8).

Llamadas de motor (con línea):

- `create_tween().tween_property` para girar la hoja (air_objective.gd:263).
- `RenderingServer.frame_pre_draw` y `frame_post_draw` (files_objective.gd:416, 422).
- `DisplayServer.get_name() == "headless"` (files_objective.gd:398).
- `PhysicsRayQueryParameters3D.create(...)` y `get_world_3d().direct_space_state.intersect_ray(...)` (files_objective.gd:604-605), máscara 1.
- `Image.save_jpg_to_buffer`, `load_jpg_from_buffer`, `get_pixel`, `set_pixel`, `ImageTexture.create_from_image` (files_objective.gd:423, 429-432, 573-574, 583, 585).
- `Basis.looking_at` (files_objective.gd:127).
- `ResourceLoader.exists` y `load()` (air_objective.gd:146, 150, 236; files_objective.gd:179-180).
- `OS.get_cmdline_user_args()` (office_palette.gd:21). Variables `static var` de caché (office_palette.gd:18, 1169-1172).
- `collision_layer`, `collision_mask`, `process_mode` (air_objective.gd:202-203, 265).
- `visibility_range_end`, `cast_shadow` (objective.gd:135-136, 171).
- `set_meta` y `get_meta` (objective.gd:133, files_objective.gd:201, air_objective.gd:212).
- `MultiMesh.set_instance_transform` (files_objective.gd:194, 217-218).
- `rotate_object_local` (air_objective.gd:382).
- `add_child`, `queue_free` (en casi todos).

## 10. Dependencias de orden, física y azar

### 10.1 Tiempo

- Todo el reloj del piso es `level.session.elapsed`, no `_process` ni `_physics_process`. Lugares: air_objective.gd:347, 383; files_objective.gd:280, 459, 644; power_objective.gd:211, 281, 294, 303, 333.
- Ningún archivo de `game/floors/` define `_process` ni `_physics_process` (búsqueda por grep, vacía).
- `tick(delta)` se llama desde el nivel. En files (638) y power (301) el `delta` no se usa. En air (379) se usa para girar los ventiladores (`FAN_SPIN`).
- Señal `session.changed.emit()` (televisions_objective.gd:56).
- Dos fotogramas de render antes de leer la foto: `await RenderingServer.frame_pre_draw` y `frame_post_draw` (files_objective.gd:415-422). En headless sale antes (398).
- Tween de la hoja de la compuerta (air_objective.gd:263); si el nodo se borra, el tween no se detiene por el código del piso.

### 10.2 Azar

- Con semilla y comparable entre máquinas:
  - Foto del jugador: `RandomNumberGenerator`, semilla `hash([manifest.seed, "photo", seat])` (files_objective.gd:425-426); ruido de grano dentro de la imagen (430).
  - Estación de cada solicitud: semilla `hash([manifest.seed, "station", seat, restarts])` (files_objective.gd:511-512), barajado con `randi_range` (513-514). `restarts` se lee con `level.session.get("restarts")` (512).
  - Número de ficha: `hash([manifest.seed, "ficha", seat])` (files_objective.gd:527).
  - Los valores de `hash()` de Godot sobre arrays no se han comprobado como estables entre versiones (apartado 13).
- Sin semilla: `randf()` para girar la tarjeta caída en el suelo (files_objective.gd:632). Es solo visual y no entra en el estado guardado (la rotación no se escribe).
- Las paletas (`hotel_palette.gd`, `office_palette.gd`) no usan azar (búsqueda por grep: ninguna coincidencia).
- `power` y `air` no usan azar.

### 10.3 Física

- Raycast hacia abajo desde el punto donde cae un superviviente, 0,5 m por encima y 2 m por debajo, máscara 1 (files_objective.gd:603-606). Solo en el anfitrión (603: `if level.net.is_client(): return`).
- Hoja de la compuerta: `StaticBody3D` con capa 1 y máscara 0 (air_objective.gd:202-203). Se desactiva al abrirse (`process_mode`, 265).
- Ninguna otra física en `game/floors/`.

### 10.4 Red y autoridad

- Solo el anfitrión decide, y el resto lo aplica con el indicador `quiet`:
  - `level.net.is_client()` en air_objective.gd:365 (la escalerilla deja el piso solo en el anfitrión), 383 (los ventiladores se paran en el anfitrión), files_objective.gd:603, 644, power_objective.gd:314.
  - Cartas: el anfitrión avanza las cápsulas hasta la bandeja (files_objective.gd:644-646).
- Mensajes que salen del piso: `level.match_net.tell_office(ID, acción, índice, asiento, datos)` (files_objective.gd:609, 646; power_objective.gd:316; air_objective.gd:385). `level.match_net.send_photo(asiento, bytes)` (files_objective.gd:578). Acciones que se envían: `"drop"`, `"arrived"`, `"armed"`, `"stopped"`.
- La foto se manda como JPEG: calidad 0,7; si pasa de 24 576 bytes, reintenta con 0,55; si sigue pasando, no se manda (files_objective.gd:571-575). Se imprime `PHOTO_BYTES` (577).

### 10.5 Orden de ejecución que el port debe respetar

- `televisions.tick` cambia `session.goal` (sets_done, sets_needed, blackout) antes de que `host_gate()` lea la meta (televisions_objective.gd:37-40, comentario y líneas 46-54).
- `refresh_power()` recorre `manifest.rooms` en el orden de la lista y solo escribe las salas cuyo estado cambió (power_objective.gd:227-235).
- Las zonas se ordenan por número de palanca (power_objective.gd:76). `on_order` guarda el orden de subida; al pasar `budget`, sale la más antigua (273-278).
- Cápsula: su posición es `along(camino, (now - sent) × CAPSULE_SPEED)` (files_objective.gd:300-303). Es función del reloj de la sesión, no del `delta`.
- La foto se toma cuando la fracción de escritura llega a 0,6 y solo en la máquina de quien escribe (files_objective.gd:391-392).
- Instantáneas (`snapshot()` y `restore()`): los pisos guardan sus claves en el orden que escribe `floor_save.gd` (no leído; objective.gd:109-110). Claves: televisions `sets` (60); code `searched`, `panels`, `hints`, `code` (33-37); files `requests`, `swiped`, `photos` (689); power `on`, `red`, `started`, `switches` (353); air `charges`, `running_until`, `released`, `post`, `hatch` (474).
- Claves de la meta de sesión que escriben los objetivos: `sets_done`, `sets_needed`, `blackout`, `restored` (televisions_objective.gd:47-54).

## 11. Pruebas que vigilan esta parte

Los tests son `.gd` en `tests/` (54 archivos). De los de piso, por cabecera:

- `tests/hotel/difficulty_test.gd`: la dificultad (Desafiante = el juego de antes; cada palanca va igual).
- `tests/hotel/rules_test.gd`: las reglas de la sala (lo que se dice de ellas y lo que se guarda).
- `tests/hotel/objectives_test.gd`: los objetivos como manejadores (`host_gate()`, líneas de los ascensores, metas del director).
- `tests/hotel/stages_test.gd`: el piso son tres etapas encadenadas; solo la última acaba el piso.
- `tests/hotel/palette_scan_test.gd`: ningún tipo de sala es un número suelto fuera de las paletas.
- `tests/hotel/manifest_golden_test.gd`: el manifiesto del hotel sale igual que el grabado (vigila el piso 1).
- `tests/hotel/creature_contract_test.gd`: el contrato de la criatura en The Locust (vigila el piso 1).
- `tests/hotel/hotel_test.gd`: pisos generados; 300 semillas en la prueba.
- `tests/hotel/continue_test.gd`: continuar devuelve el piso como se dejó (`floor_save.gd`).
- `tests/hotel/survival_test.gd`: distancias a las hojas de puerta (`hotel_door.leaf_line`).
- `tests/office/office_test.gd`: el piso 2 tal como lo dejan los pasos 1a y 1b; la paleta tiene todos los nombres del hotel.
- `tests/office/descend_test.gd`: el piso 1 ganado lleva al piso 2; la dificultad se conserva.
- `tests/office/lurker_fairness_test.gd`: la garantía de The Lurker: nunca atrapa a nadie sin avisar por la espalda.
- `tests/office/office_proportion_test.gd`: la proporción de ocho plantas.
- `tests/office/office_pieces_test.gd`: las piezas de oficina hechas en código.
- `tests/office/office_dark_test.gd`: la primera etapa del piso 2 a oscuras según dificultad.
- Otros de The Lurker: `lurker_bots_test`, `lurker_capture_test`, `lurker_forced_test`, `lurker_observer_test`, `lurker_senses_test`, `lurker_shell_test`, `lurker_tiles_test`, `lurker_fixture`. Sin leer por dentro.
- Otros de oficina: `office_dressing_test`, `office_finishes_test`, `office_light_test`, `office_lies_test`, `office_audio_test`, `office_walk_test`, `jump_test`, `office_test_generator`. Sin leer por dentro.
- `tests/net/net_test.gd`: la red (sin leer por dentro).

Herramientas que leen pisos, reglas o dificultad (por grep; 17 archivos): `tools/bots.ps1`, `tools/art/make_achievement_icons.py`, `tools/bots/bot_threat.gd`, `tools/capture/lurker_office_look.gd`, `tools/capture/office_angles_capture.gd`, `tools/capture/office_capture.gd`, `tools/capture/office_rooms_capture.gd`, `tools/dev/body_clip_probe.gd`, `tools/dev/capture_bench.gd`, `tools/dev/light_layers_scan.gd`, `tools/dev/lurker_route_probe.gd`, `tools/dev/lurker_telemetry.gd`, `tools/dev/office_metrics.gd`, `tools/dev/office_plan.gd`, `tools/dev/office_plan_metrics.gd`, `tools/dev/office_plan_physics.gd`, `tools/dev/pause_chase_probe.gd`.

Regla del proyecto (CLAUDE.md, sección «El piso 1 (el hotel) no cambia»): salvo que el encargo lo diga, el piso 1 no cambia, y lo vigilan `manifest_golden_test` y `creature_contract_test`.

## 12. Lo que los objetivos piden al nivel (`level`) y a la sesión

Los objetivos no tienen estado de partida propio: leen y escriben el nivel. Esto es lo que habrá que sustituir en el port:

- Nivel: `level.kind` (`asks`), `level.session` (`stage`, `goal`, `roster_count`, `participants`, `Life.DEAD`, `elapsed`, `changed`, `minimum_survivors()`, `restarts` vía `get`), `level.manifest`, `level.rule(id)`, `level.ledger.note_dark()`, `level.hotel` (`add_child`, `room_nodes`, `plan_walls`, `doors`, `set_room_power`, `adopt`, `lifts`), `level.tvs` (`stage_televisions`, `place_televisions`, `televisions`, `televisions_on`, `apply_television`, `creature_channel_hop`), `level.code` (`place_containers`, `containers`, `found_digits`, `code_entered`, `lock`, `found_by`, `opened_panels`, `hints_read`, `note_read`), `level.lifts` (`riding`, `leave_floor()`), `level.net` (`is_client()`), `level.match_net` (`tell_office`, `send_photo`), `level.world_audio` (`enabled`, `play_at`, `play_long`, `loop_stream`, `long_cues`, `stop_long`), `level.player` (`slot`, `transit`, `global_position`, `hidden`), `level.body_of_seat(seat)`, `level.survivors()`, `level.bot_match`, `level.interaction.read_paper(...)`, `level.camcorder` (`start_seconds`, `date_parts`), `level.tape_seconds()`, `level.seat_name(seat)`, `level.objective(&"files")`, `level.catch_up_progress(...)`, `level.get_world_3d()`, `level.add_child(...)`.
- `session.minimum_survivors()` lo llaman `files`, `power` y `air`. `session.goal` lo escribe `televisions` (líneas 47-54).

## 13. Sin comprobar

- No se leyó el código que usan estos objetos (por nombre, sin ver su contenido): `hotel_main`, `game_session`, `session`, `lifts`, `net`, `match_net`, `floor_save`, `televisions.gd`, `code_lock.gd`, `tv_placement.gd` (`needed`, `settle`), `digit_placement.gd` (`COUNT`), `run_score.gd` (`meets`), `records_service`, `pacing_director.gd`, `map_generator.gd`, `map_validator.gd`, `hotel_geometry.gd`, `office_geometry.gd`, `office_generator.gd`, `floor_definition.gd`, `office_usable.gd`, `hint_placement.gd`, `camcorder`, `world_audio`, `mail_equipment.gd`, `power_equipment.gd`, `air_equipment.gd`, `main_duct_geometry.gd`, `survivor_gait.gd`. Lo que digo de ellos viene de lo que los objetivos llaman, no de lo que hacen.
- `docs/OFICINAS.md`: leídas las secciones 4 (Dificultad de The Lurker, líneas 398 a 440), 11.2 (líneas 661 a 692) y 14 (líneas 907 a 944). El resto solo por títulos: secciones 1 a 3 (planta, correo, corriente y aire, líneas 1 a 313), 5 a 10, 11.1, 11.3 a 11.8, 12, 13 y 15.
- `docs/EXECUTION.md`: solo títulos. Sin leer: la captura, la cámara, la cinta y los armarios.
- `docs/PLAN.md`: sección 5 completa. El resto, solo títulos.
- `docs/GAME_DESIGN.md`, líneas 203 a 299: solo búsqueda de términos y las líneas 208, 210, 230 a 232, 272 y 282.
- Valores de hashes de Godot (`hash()`) y de `RandomNumberGenerator` entre versiones de Godot y plataformas: no comprobados.
- Lo de la red (`tell_office`, `send_photo`): solo cómo se llama, no qué hace al recibirlo.
- `tests/`: solo cabeceras; no se ejecutó nada.
- Cifras de tiempo que dice el diseño («tarda entre 15 y 111 s», «unos 32 de mediana», «91 ms»): tomadas del diseño, no medidas.
- Textos de juego con «·» o «—» en las cadenas de `game/floors/`: búsqueda por grep sin coincidencias (comprobado). Los documentos sí los usan (`docs/DIFFICULTY.md:273`).
- Versión del generador del hotel (`floor_definition.gd` VERSION): no leído.
