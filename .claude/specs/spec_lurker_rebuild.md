# The Lurker, reconstruida (11 de noviembre de 2026)

El autor la jugó y dijo: «tiene un montón de flaws, se queda atascada, el movimiento no es fluido, los sonidos son constantes y no generan cambios de atmósfera, no persigue bien, no cumple la receta de diseño». Pide reconstruirla completa: funcional y aterradora, pulida, con dificultades que se noten y equilibrada en multijugador. Trabajo por iteraciones rápidas: cambios grandes primero, pulido después, sin validaciones largas de motor.

Manda la receta de `docs/OFICINAS.md` 1 y 4 y lo que el autor pidió el 24 de octubre (`spec_f3_aggression.md`). Esta nota dice cómo se cumple de verdad. Las cifras nuevas son del director y se afinan jugando.

## 0. Lo que NO cambia

- **El aviso** (`lurker_warning.gd`, su `audit()` y su registro): nunca coge sin avisar por la espalda, nunca antes de la ventana. Ni una línea.
- El contrato de criatura (`creature.gd`): solo se le AÑADE `mood()` (sección 4).
- La cáscara (`lurker_shell.gd`), el grafo de ductos, la captura, las mentiras, la red (el paquete de estado lleva `int(brain.state)`: el enum conserva su orden y los estados nuevos van AL FINAL).
- El piso 1 (el hotel): ni un byte de comportamiento. Todo cambio en código compartido (`dread_aura.gd`, `creature.gd`, `pacing_director.gd`, `world_audio.gd`) es inerte para The Locust (`mood()` vacío = como hoy).
- Lo que salva del aviso: girarse con luz o linterna, la linterna de un compañero, alejarse CORRIENDO.

## 1. La idea en una frase

**Lo que miras no avanza; lo que no miras, vuela.** Sin nadie mirándola es rápida en TODOS los estados (también al acechar y al acercarse); vista, va despacio o se va. Un encuentro tiene compases que se oyen: presencia, acecho, silencio de pronto, garras que se acercan, aviso, y después alivio.

## 2. El cerebro (se reescribe `lurker_brain.gd`)

### 2.1 Principios

- **Nunca `hold` por estar expuesta.** Si su camino por delante está vigilado con luz, va por el pleno (intención `go` con `hidden: true`) o cambia de punto; si la miran a oscuras y sin luz, sigue. Mirada con luz o alumbrada: se va al instante (como hoy), y cuenta como intento fallido solo si iba a por alguien.
- **Cada estado tiene tiempo máximo y salida obligada.** Un solo vigilante: fuera de ESCUCHAR, SILENCIO, ENCIMA y la espera dentro del techo, si pasa 6 s sin moverse 0,5 m, cambia de meta (y si repite, vuelve a RONDAR con otra sala). Sustituye a `GIVE_UP` y `HOLD_MOST`, que se borran.
- **La presa se conserva por memoria**, no por vista: punto, rumbo, velocidad y hora del último vistazo o ruido; la distancia se recalcula cada tick. La pierde pasado `forget` sin señal, y entonces busca en el último punto conocido (nunca en la posición real: sin trampas).
- **`arrived` es llegar a la meta pedida** (a menos de 0,6 m), y `failed` se reinicia con cada orden.
- Desempates al azar (su rng), nunca por asiento más bajo.

### 2.2 Estados

El enum conserva `ROAM, LISTEN, STALK, PEEK, FREEZE, CREEP, CUE, TAKE, RECOIL, FLEE, TRANSIT, WAIT_ABOVE` y añade al final `HUSH, RETURN`. `FREEZE` queda sin uso (solo `force()`).

| Estado | Regla | Sale a |
|---|---|---|
| ROAM (rondar) | Siempre en marcha. Meta: ruido nuevo (tras `noise_react` s, cambia la meta aunque ya tuviera otra) > zona del director > patrulla. Al llegar, a veces ESCUCHAR. | STALK al percibir a un candidato; LISTEN |
| LISTEN (escuchar) | Quieta en una rejilla 3 a 6 s, oye más lejos. | STALK, ROAM |
| STALK (acechar) | Sigue a la presa a `stalk_distance`, fuera de su cono de vista: `world.stalk_point()` (sección 2.4). Rápida si nadie la ve. Dura `stalk_time`; se corta antes si hay **ocasión**: presa quieta 2 s, ocupada (usando algo, leyendo, escribiendo), o sola, a oscuras y de espaldas. Puede asomarse una vez (probabilidad `peek_chance`). | HUSH (ocasión o tiempo cumplido), PEEK, WAIT_ABOVE (la vio esconderse), ROAM (la perdió) |
| PEEK (asomarse) | Va a un punto al borde de la vista, mira hasta 4 s, se va en cuanto se la mira 0,35 s. Si el director pidió «cruce», tiene prioridad sobre elegir presa. | RETURN/STALK (misma presa), HUSH en Pesadilla y Desafiante (encadena ataque) |
| HUSH (silencio) | Quieta `hush` s donde está, callada del todo (sección 4). Es el «silencio de pronto donde sonaba». | CREEP; STALK si la presa se aleja más de `stalk_distance` + 4 |
| CREEP (acercarse) | Va al punto del aviso detrás de la presa (2,4 m). Velocidad: `clamp(velocidad de la presa + 0,6, 1,0 × creep_scale, approach_cap)`: alcanza a quien anda, nunca a quien corre. Si la presa se gira, no se rinde: recoloca (el rumbo de la presa se suaviza 1 s, no sigue al ratón) y solo vuelve a STALK tras 5 s sin lograr la espalda. | CUE (`cue_ready`, como hoy), STALK |
| CUE, TAKE, RECOIL | Como hoy. | |
| FLEE (huir) | Al techo por la placa de encima o la entrada más cercana; máximo 8 s fuera del techo, después se da por dentro (entra por donde esté: `begin_drop`). | RETURN (queda intento), ROAM (descanso) |
| RETURN (volver) | En el techo `emerge_delay` s; elige la salida con la posición CONOCIDA de la presa en ese momento (`emerge_mode`, `emerge_range`), sale y entra en STALK sobre la misma presa con `stalk_time` × 0,4. | STALK, ROAM |
| WAIT_ABOVE (encima) | Como hoy. | CREEP, ROAM |
| TRANSIT | Como hoy. | ROAM |

### 2.3 El encuentro

- Un encuentro por presa: `tries` intentos (clave `attempts`). Un intento falla por salvarse del aviso o por alumbrarla o mirarla con luz mientras acecha de cerca (menos de `stalk_distance`), se silencia o se acerca.
- Tras el último, deja a esa presa `encounter_rest` s. Tras una captura, `sated` s solo para elegir presa nueva.
- **Cooperativo.** Con `n` supervivientes vivos en su planta:
  - la pausa global entre encuentros (15 s base tras el descanso de una presa o una captura) se multiplica por 1 / 0,75 / 0,55 / 0,4 para n = 1 / 2 / 3 / 4;
  - `stalk_time` por 1 / 0,85 / 0,7 / 0,6;
  - `sated` deja de ser global: solo protege a los que están a menos de 8 m de la captura;
  - tras un intento fallido, RETURN apunta al candidato más aislado de los que estaban a menos de 12 m (puede cambiar de presa: «va a por el que se queda atrás»); cada presa lleva su propia cuenta de intentos y su propio descanso (el `comeback` deja de ser un solo hueco).
- **Elegir presa:** `0,35·solo + 0,25·oscuro + 0,2·rezagado + 0,2·ocupado`, donde rezagado es la distancia al centro del grupo (0 con un solo superviviente) y ocupado es usar algo, leer o estar quieto. Nunca alguien en sala protegida ni en descanso.
- **Encuentro forzado** (`pacing_director`): elige al más solo o rezagado, no al más lejano; la pista vale también en salas con luz (ella llega por el pleno) y FLEE acepta la pista si lleva más de 8 s.

### 2.4 El puerto (`lurker.gd`)

- `stalk_point(seen, metros) -> Vector3`: un punto de techo o pared fuera del cono de vista de la presa (120 grados alrededor de su rumbo suavizado), cerca de `metros`, en su sala o en una vecina con paso abierto; preferencia: detrás de su rumbo, a oscuras. Nunca `INF`: si no hay, la placa libre más cercana a su espalda; si no hay falso techo, el punto de techo más cercano dentro de la sala.
- `behind_point()` usa el rumbo suavizado (1 s) y nunca devuelve un punto sin techo.
- `emerge_point()` recibe el punto conocido de la presa en ese momento.
- Velocidad: `unseen_now()` vale en ROAM, LISTEN, STALK, PEEK (yendo), FLEE, RETURN y entre plantas; en CREEP manda su fórmula; en CUE, lo de hoy. Vista (alguien la tiene en su vista), 1,35 m/s.
- Intención nueva `pause`: frena sin borrar las piernas (HUSH, mirar un instante). `hold` queda para lo que de verdad se queda quieto.
- `mood()` (sección 4), calculado del estado del cerebro, o de `net_mind` en las réplicas.

### 2.5 Dificultad (`difficulty.gd`; las claves de hoy se conservan)

| Clave nueva | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| `stalk_time` (s) | 25 a 40 | 15 a 25 | 8 a 15 | 4 a 9 |
| `peek_chance` | 0,7 | 0,5 | 0,3 | 0,15 |
| `hush` (s) | 3,0 | 2,5 | 2,0 | 1,5 |
| `noise_react` (s) | 4 | 2 | 0,8 | 0 |
| `sated` (s) | 60 | 40 | 30 | 20 |
| `approach_cap` (m/s) | 3,0 | 3,5 | 4,0 | 4,5 |

`approach_cap` nunca llega a la velocidad de carrera del superviviente menos 0,5 (quien redacte el encargo la lee del código y, si hace falta, baja la de Pesadilla). Se borran las claves muertas `freeze_time` y `scare_calm` si nada más las lee. En Apacible (3,0 frente a los 3,8 de andar) basta con andar para dejarla atrás; en Pesadilla hay que correr, y correr hace ruido.

## 3. El movimiento (`lurker_motion.gd`, `lurker_visual.gd`, y lo suyo de `lurker.gd`)

Por orden de impacto:

1. **Interpolación entre ticks** en el visual (`get_physics_interpolation_fraction()`, como `smooth_camera()` del jugador): `lurker.apply_motion` guarda la transformación anterior y la actual; se corta cuando cambia `motion.jump_id`.
2. **Capa de presentación** en el mismo sitio: la base con slerp y límite de velocidad angular (unos 6 rad/s), la posición con un muelle críticamente amortiguado (retraso máximo 0,15 m), salto directo si cambia `jump_id`. La colisión, los sentidos y la red siguen con la transformación cruda.
3. **Sobrante y velocidad continua:** el resto del paso pasa al tramo siguiente en el mismo fotograma; `pick_clip` no baja a `idle` hasta 0,15 s por debajo de 0,05 m/s.
4. **Un único vigilante de progreso** en `motion.tick`: con piernas en curso y menos de 0,1 m en 1,5 s (fuera de los tramos por reloj): replanifica, después bloquea la puerta o el tramo, después `stuck = "sin avance"`. Sustituye a `stall`, `BAND_WAIT` y las esperas sin límite (superviviente delante, ducto principal ocupado). `set_legs` deja de poner `wait_clock` a 0.
5. **Persecución sin zigzag:** si la meta nueva cae en la misma sala que el último tramo de techo, se mueve `legs[-1].to` en vez de replanificar; una replanificación cada 0,3 s como mucho; `pause` y `hold` frenan con rampa (v²/2a), no en seco; toda velocidad cambia con aceleración (también en ductos y al pasar de no vista a vista: 6 m/s² al frenar, 4 al arrancar).
6. **Puertas sin parar:** `band_switch` deja pasar a la franja sin frenar a cero si va alineada a menos de 0,3 rad.
7. **Salidas por placa o rejilla:** el `squeeze` de salida empieza con la base ya boca abajo; `crawling` sigue activo durante el squeeze (los brazos no saltan del IK al clip).
8. **Esquinas** (si cabe en la iteración): punto adelantado sobre `ahead()` y velocidad de giro proporcional a la velocidad, con `DETOUR` a 0,3 m.

Los teletransportes de canal y squeeze (`into_channel_now`, `follow_squeeze` a `from`) se arreglan de raíz si es un cambio local; si no, la capa 2 los tapa y se anota.

## 4. El sonido y la atmósfera

**Contrato nuevo:** `creature.mood() -> Dictionary`, vacío por defecto (todo como hoy). Ella devuelve `{"aura": 0..1, "clicks": bool, "menace": 0..1 o -1, "fast": bool, "silent": bool}`:
- `aura` multiplica el objetivo del aura (`dread_aura`), en lugar del `match alarm`;
- `clicks`: si el aura puede poner sus chasquidos falsos;
- `menace` >= 0 sustituye a la amenaza que usa la música (-1: por distancia, como hoy);
- `fast`: el aura cae a 2,0 por segundo en vez de 0,18;
- `silent`: su voz (`lurker_voice`) no emite nada.

| Compás | aura | clicks | menace | fast | Qué suena de ella |
|---|---|---|---|---|---|
| Rondar lejos (más de 12 m por ruta) | 0,35 | no | -1 | no | golpes de ducto en tandas |
| Rondar cerca | 0,6 | no | -1 | no | golpes y placas del pleno |
| Escuchar | 0 | no | -1 | sí | nada |
| Acechar | 0,85 | solo si va por pleno o ducto | -1 | no | garras reales en techo y pared; luces bebidas |
| Asomarse | 0,3 | no | -1 | sí | nada |
| **Silencio (HUSH)** | 0 | no | 1 | sí | **nada; `silent`**; al entrar, `duck_under()` del ambiente |
| Acercarse | 1,0 | no | 1 | no | solo sus garras, fuerza >= 0,8 aunque vaya lenta |
| Aviso | 0 | no | 1 | sí | solo el aviso; `silent` desde el principio de la ventana y `duck_under(ventana)` |
| Espantada y huida | 0 | no | 0 | sí | chillido, después golpes rápidos que se alejan |
| Volver (en el techo) | 0,5 | no | -1 | no | la placa o la rejilla que cruje al salir |
| Descanso (nadie elegible cerca) | 0,2 | no | 0 | no | golpes lejanos; **vuelve la música** |
| Encima | 0,6 | no | -1 | no | su presencia por las lamas (como hoy) |

Además:
- los chasquidos del aura no usan `metal_2` en una sala; las garras reales no bajan de volumen por ir despacio en CREEP;
- los ritmos del ducto dependen del compás: rondar, tandas de hoy; acechar por el pleno, tandas cortas (2 a 4 golpes) y silencios largos (2,5 a 5 s); huir, tanda continua que se aleja;
- se usan las grabaciones sin usar: `wood_scratch_1-2` y `drag_1-2` para la garra en pared (el «tictac»), `tile_grind` al llegar encima de una taquilla;
- el paso bajo del bus Ambience no baja de 1.400 Hz mientras ella bebe la luz de la sala de quien escucha (hoy tapa la bajada de tono del zumbido);
- tras un aviso salvado, la música no tarda más de 6 s en volver.

El ambiente propio de las oficinas (climatización, goteo, cuadro, silencio de los archivos) no existe y va en una iteración posterior.

## 5. Cómo se revisa cada iteración

- `tools/dev/lurker_telemetry.gd` (partida de bots con la criatura real; 2 a 3 minutos): atascos, saltos, giros, cambios de velocidad, tiempo hasta el primer aviso, avisos y capturas por minuto, sonidos por estado. Es la revisión de la iteración.
- Pruebas cortas que deben seguir en verde: `lurker_fairness_test` (el aviso), `lurker_motion_test`, `creature_contract_test`. Las demás pruebas de The Lurker que afirmen el cerebro viejo se adaptan al cerrar el frente, no en cada iteración.
- `verify.ps1` entero, una vez, al cerrar el frente.

## 6. Iteraciones

1. **Esta:** movimiento 1 a 7, el cerebro nuevo con su puerto y su dificultad, `mood()` con el aura y la voz.
2. Lo que enseñe la telemetría; esquinas; equilibrio por dificultad y por número de jugadores con lotes de bots.
3. Pulido: ambiente de oficina, pruebas adaptadas, documentos (OFICINAS 4, LURKER), verify, exportación.
