# Audio del hotel — integración de sfx

## Implementado

Se catalogaron 33 archivos aportados en `sfx/`. Se asignaron **30** a funciones actuales; los otros tres permanecen reservados. Los originales no se editaron ni movieron. `sfx/` queda fuera de la importación de Godot y de Git; respáldala junto con `source_assets/`. Las copias que puede usar el proyecto están en `assets/audio/sfx/`.

- **Puertas cercanas:** cuatro aperturas y cuatro cierres, con elección aleatoria local que evita repetir inmediatamente la misma grabación. Apertura lenta: crujido prolongado. Pequeña variación de tono entre 0,98 y 1,02.
- **Puertas lejanas:** dos aperturas y dos cierres con distancia/eco ya presentes en la grabación. Se elige ese grupo a partir de 12 m al comenzar el sonido, sin cambiar de grabación a mitad del efecto. Ambos grupos se atenúan espacialmente; alcance máximo 32 m.
- **Cierre coherente:** el golpe de cierre espera a que termine el movimiento y la grabación arranca justo antes de su impacto, para que el pestillo coincida con la hoja. Una puerta ya no se niega a cerrar ni rebota abierta con alguien en el marco, así que el pestillo suena siempre al terminar el cierre, una sola vez. Abrir puertas durante la construcción del mapa no produce sonidos.
- **Escondites:** cuatro entradas y cuatro salidas de armario, ligadas a las acciones que realmente se completan. Los armarios son ya los de doble puerta: solo la primera apertura de cada estancia cruje, y asomarse abriendo las hojas tiene su propio sonido.
- **Ambiente:** `dark terror ambience.wav` sustituye la cama ambiental global por una copia de trabajo estéreo. La ventilación conserva el audio anterior como fuente localizada. La música anterior sigue disponible a un nivel más bajo.
- **Identidad de Locust:** `terror ambience (dark presence).wav` es su presencia espacial, con origen en la criatura. Se oye dentro de 24 m (`audible_distance` de `profiles/locust.tres`), entra/sale gradualmente y no se activa durante la protección inicial ni dentro del refugio. Deja de sonar al terminar el desvanecimiento al entrar en refugio. Las paredes reducen su nivel y agudos. El aviso de ataque original se conserva y la presencia baja 16 dB durante su preparación.
- **Mezcla:** puertas/escondites en Effects, ambiente en Ambience, música en Music y presencia/aviso de amenaza en Threat. Máximo ocho efectos de interacción simultáneos; la presencia tiene su propio reproductor, y los sonidos largos también (ver «Sonidos largos»). Pausa conserva el estado; muerte, menú y reintento limpian los efectos.
- **Subtítulos:** puertas y presencia tienen texto, sujeto a los ajustes. Las señales de presencia no se repiten continuamente y no reemplazan el aviso de ataque.

La atenuación direccional usa AudioStreamPlayer3D; la oclusión por pared es una aproximación mediante rayo y reducción de nivel/agudos, no una simulación completa de acústica por habitaciones. Referencia técnica: [AudioStreamPlayer3D en Godot](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html).

## Preparados o reservados

- `paper/paper.ogg`: suena al leer un documento (sonido local, no es un ruido para la IA). También está previsto para abrir la futura hoja de dibujo.
- `heartbeat/1.ogg` y `2.ogg`: son los latidos del aura (`dread_aura.gd`, ver «Aura de The Locust»).
- Cuatro grabaciones `hard-*`: se usan como portazo cuando el jugador abre o cierra una puerta mientras corre. Ese giro es más rápido y su ruido jugable llega a 18 m (normal: 12 m; lento: 3 m).
- `sub-riser-presence.wav`: reservado para una transición de presencia anunciada; no se suma al aviso corto de ataque para no ocultarlo.
- `big-hall-far-prop-glass-noise.wav`: reservado para un evento ambiental con origen válido en un salón existente.
- `metalic-sliding-long-door.wav`: sin uso (el ascensor tiene sus propias grabaciones, «El ascensor»).

Los perfiles de Sunman, The Boiled One y Guilt se asignarán al integrar sus criaturas. No se reproduce una amenaza que todavía no existe en el nivel.

## Editar y ampliar

`game/audio/world_audio.tscn` expone distancia para grabaciones lejanas y límite de voces. `world_audio.gd` contiene los grupos y ganancias; sus sorteos usan un generador independiente, sin alterar semillas del mapa ni percepción de la IA. Las señales de ruido jugable existentes siguen separadas de los efectos audibles.

`game/audio/profiles/locust.tres` permite cambiar el audio, volumen, alcance y subtítulo desde el Inspector. El controlador de Locust expone `sound_profile`. `creature_audio_profile.gd` define el recurso reutilizable para futuros personajes.

Las dos copias WAV largas se convierten a 16 bits y la mitad de frecuencia con filtrado previo; presencia pasa a mono para localizar su origen. Se solapa un segundo entre final e inicio, sin tocar los originales. Ambiente: 24 kHz estéreo; presencia: 22,05 kHz mono. Se limita el pico a 0,8 sin amplificar grabaciones ya más silenciosas. Las copias de OGG/MP3 son idénticas a los archivos aportados.

Inventario, huellas, datos WAV y tratamiento: `docs/assets/sfx_inventory.json`. Duraciones decodificadas por Godot: `sfx_runtime_inventory.json`. Esta asignación inicial usa nombres, análisis técnico y pruebas de reproducción; la selección auditiva final y el balance con auriculares en partidas humanas siguen pendientes. No se afirma haber realizado una escucha crítica completa de los 33 archivos.

Autoría/licencias: aportados por el usuario, pendientes de documentar antes de distribución. La integración no cambia ese estado.

## Comprobar

`./tools/verify.ps1` incluye `tests/hotel/spatial_audio_test.gd`, en tiempo real. Comprueba variación, grupos por distancia, cierre coherente, escondites, origen de presencia, reducción durante ataque, oclusión, panorama estéreo capturado, atenuación y limpieza tras muerte.

Resultado inicial: **18/18**. Las regresiones de hotel, supervivencia, contratos de escenas, audio anterior y prototipo histórico también se ejecutan. La captura estéreo automatizada verifica el funcionamiento; no sustituye la evaluación subjetiva de mezcla.

Para reproducir las copias desde los originales: `tools/audio/prepare_sfx.py` (Python 3 con NumPy), seguido de la importación de Godot y `tools/audio/catalog.gd`. El preparador localiza la raíz desde su propia ruta; no depende de la letra de unidad del equipo.

## Arranque sin silencio y portazos

`tools/audio/analyze_cue_timing.gd` reproduce cada efecto por el mezclador y mide su inicio audible (−24 dB respecto al máximo) y el momento de mayor energía. Genera `game/audio/cue_timing.gd`; no hay que editarlo a mano. `world_audio.gd` empieza las aperturas y salidas de escondite en su inicio audible, los cierres 0,08 s antes del impacto y las entradas a escondite 0,3 s antes. Las grabaciones no se modifican. Si se añaden o cambian sonidos, vuelve a ejecutar la herramienta con Godot en modo `--headless`.

Ganancias actuales (`GAIN` en `world_audio.gd`): apertura +1 dB, portazo 0 dB, apertura lenta −12 dB, cierre −11 dB y escondites −8 dB. La escucha crítica con auriculares sigue pendiente.

## Mezcla y volumen (revisión de audio espacial)

- **Curva de los deslizadores:** 50 % es la mezcla de referencia (0 dB en el bus); 100 % suma +6 dB y 25 % resta 6 dB. Un limitador en Master (techo −0,5 dBFS) evita saturación. Las preferencias guardadas con la curva anterior restablecen sus volúmenes una vez (`AUDIO_CURVE` en `settings_service.gd`).
- **Niveles medidos al 50 %** con `tools/audio/measure_mix.gd` (bus Master, dBFS): ambiente con música y ventilación −26 RMS; paso caminando pico −17; puerta abierta a 2,5 m pico −7; cierre pico −10; portazo al limitador; puerta a 20 m pico −25. Al 100 % todo sube unos 6 dB y el limitador contiene los picos.
- **Buses** (`default_bus_layout.tres`, editables en el panel Audio de Godot): Master con limitador; Ambience con filtro paso bajo que el aura cierra al acercarse la criatura; Music; Effects y Threat con reverberación que sigue la sala del oyente (habitación, salón largo o sala de azulejos); Aura, que envía a Threat y depende de su deslizador.

## Dirección con auriculares

Medido con `tools/audio/measure_spatial.gd` (pisadas de la criatura a 3,5 m de un oyente quieto, bus Master, tiempo real):

- **Sonidos del mundo** (puertas, eventos): paneo del motor con fuerza 1,15 (`PANNING` en `world_audio.gd`). Es el máximo útil: por encima de ~1,2 Godot separa menos (a 2,0 la izquierda quedaba casi en el centro).
- **The Locust, binaural:** sus pasos, gruñidos y presencia llegan en mono a los buses `Creature` y `CreatureEcho` (envían a `Threat` y `ThreatEcho`). Su efecto `Ears` es un retardo sin señal directa cuyas dos tomas van una a cada oído; `world_audio.update_ears()` las ajusta en cada fotograma según dónde se oye la criatura (su posición o la abertura por la que llega): el oído del lado de la criatura recibe el sonido hasta 0,65 ms antes (la diferencia de tiempo entre oídos alrededor de una cabeza) y el otro hasta 18 dB más bajo. Medido con 14 dB: a 90° retardo de 31 muestras y unos 15 dB de diferencia (antes 13 dB y sin retardo); a 45° 22 muestras y 11,5 dB (antes 7 dB). El cambio se suaviza para no dar saltos al girar la cabeza.
- **Delante o detrás:** todo sonido enrutado que llega por detrás del oyente pierde agudos (hasta 3,2 kHz) y 4 dB (`behind()`); en la medición, detrás tiene la cuarta parte de energía aguda que delante.
- Los ecos de `EffectsEcho` y `ThreatEcho` ya no se abren a izquierda y derecha (panorama 0) y la reverberación de ambos es más seca (directo 0,85), para que lo que llega por una esquina conserve su lado.

## Aura de The Locust

`game/audio/dread_aura.gd` (nodo `WorldAudio/DreadAura`) calcula cada 0,25 s la distancia **por ruta caminable** entre jugador y criatura. La intensidad crece desde 30 m hasta 4 m (`start_distance`, `full_distance`) y aumenta si investiga o persigue; es cero durante la protección inicial y en el refugio.

- **Dirección sin revelar la posición:** respiración y chasquidos suenan unos metros por delante del jugador (7,5 m lejos, 2,5 m cerca) **sobre la ruta por la que llegaría**. Se oye por qué puerta o pasillo viene aunque haya paredes, pero no dónde está exactamente.
- **Presión:** dron grave desafinado (no direccional), ambiente amortiguado y música que se retira. Latidos desde intensidad 0,5, de 64 a 128 ppm.
- **Subtítulo direccional** al cruzar intensidad 0,3: `[Algo se acerca · izquierda/derecha/delante/detrás]`, como máximo cada 20 s.
- La presencia grabada sigue sonando desde la propia criatura, con oclusión por paredes. El aura es solo presentación: no altera percepción, rutas ni ataques.

Capas generadas por `tools/audio/generate_dread_layers.py` en `assets/audio/dread/` (WAV mono 16 bits, reproducibles): dron, respiración, cuatro chasquidos y zumbido de fluorescente. Se pueden sustituir por grabaciones propias con el mismo nombre.

**La crecida se retiró** (septiembre de 2026): `presence_riser.wav` era un barrido ascendente sintetizado —de 93 Hz a 4,7 kHz en cinco segundos— que se disparaba al cruzar intensidad 0,55, es decir justo cuando la criatura se te echaba encima, y sonaba a efecto de tráiler y no a bicho. El archivo se conserva porque la escena de entrada lo usa como golpe de la tele. Sin ella el aura sigue apuntando igual (medido en el bus `Aura`: entre 8 y 13 veces más energía en el oído del lado de la criatura), pero la prueba de sonido espacial necesita una ventana más larga, porque ya no hay un golpe garantizado dentro de ella.

## Atmósfera local

- Zumbido de fluorescentes: todos los tubos de las salas de servicio zumban, hasta dos fuentes en los más cercanos (13 m), que se apagan con cada parpadeo. Un tubo de otra sala solo llega por la abertura, como cualquier sonido. Medido al 50 % con `tools/audio/measure_hum.gd`: −31 dBFS RMS debajo, −34 a 3 m, −40 a 5 m.
- Pasos de The Locust: golpe seco sintetizado de pata punzante sobre un golpe hueco, en cada pisada real de la animación.

Pendiente: escucha crítica con auriculares, balance del aura en partidas humanas y perfiles de las otras criaturas.

## Propagación entre salas

`world_audio.route_source()` decide por dónde llega un sonido. Con línea libre llega directo desde su origen. Si hay muros de por medio sigue la ruta caminable y se oye desde la última abertura visible (una puerta o una esquina): más bajo según el rodeo, más apagado y por los buses `EffectsEcho` o `ThreatEcho` (retardos de 170/340 ms y reverberación amplia), que envían a Effects o Threat. Nada atraviesa muros. Más allá de 42 m de ruta no se oye.

**La distancia también se oye como distancia**, no solo como volumen: sobre la atenuación normal, cada sonido pierde hasta 6 dB y sus agudos con los metros de ruta (`AIR_REACH` 45 m, `AIR_GAIN`, `AIR_CUTOFF` 2 kHz en `world_audio.gd`, aplicados en `apply_route()`). La curva es una raíz, así que los primeros metros ya apagan algo: es lo que diferencia «en esta sala» de «al otro lado del piso». Antes, con línea libre, el filtro se quedaba en 20 kHz a cualquier distancia y un grito a cuarenta metros sonaba como uno a diez, solo más bajo.

El sonido de la criatura y el aura piden **la misma ruta** (`world_audio.walked_route()`), que se reutiliza durante 0,3 s mientras ni el oído ni el origen se hayan movido 1,6 m: pedirla dos veces costaba casi 5 ms de un fotograma ([PERFORMANCE.md](PERFORMANCE.md), sección 12). **Desde encima de un mueble** (una cama, un escritorio, un armario) la criatura se oía a cero metros, estuviera donde estuviera: la navegación tenía islas en lo alto de los muebles y la ruta acababa en su borde. Ya no las tiene (`hotel_geometry.keep_floor()`; lo comprueba `tools/dev/hearing_probe.gd`).

Lo usan los golpes de puerta, los pasos, la presencia y los gruñidos de The Locust. La criatura oye al jugador por la misma lógica de rutas pero hasta la distancia de cada ruido en la tabla `HEARD` de `noise_kinds.gd` (de 8 m agachado a 64 m corriendo sobre baldosa), y el aura empieza a 24 m de ruta: la criatura siempre detecta antes de lo que el jugador puede oírla.

## Gruñidos de persecución

**El aviso de la estocada también sale de la misma grabación** (solo cuando la bestia la lleva un jugador: la IA ya no embiste, coge en el acto y sin aviso): 0,3 s antes de embestir suena uno de los trozos cortos de `grunts.ogg` (los que no llegan a 1,4 s: ladridos y respiraciones), con el tono bajado entre 0,78 y 0,9. Antes era un barrido sintetizado de 190 Hz hacia arriba, que no sonaba a animal. Sigue siendo la señal que te dice que esquives, y no la tapa nada: va por su propio reproductor (`$Warning`). **Se enruta como sus gruñidos y sus pasos** (`hotel_locust.warn()`): tras una pared llega por el vano o no llega. Hasta septiembre de 2026 era el único sonido suyo que atravesaba muros.

`assets/audio/sfx/chase/grunts.ogg` (aportado) se divide en gruñidos sueltos con `tools/audio/analyze_grunts.gd`, que escribe `game/audio/grunt_segments.gd`. Solo se usan los gruñidos completos (1,4 s o más; los trozos cortos son respiraciones), sin repetir el mismo dos veces seguidas. Suena uno en cuanto la criatura te ve y se gira hacia ti (alerta), el siguiente cuando termina ese y después uno cada 2,5–5 s mientras persigue, con la misma propagación. El corte respeta el tono aleatorio, así que no se truncan. Si cambias la grabación, vuelve a ejecutar el analizador.

**El grito del comienzo de la caza.** Cuando se acaba la protección del principio —los 15 s en los que la criatura no se mueve, y también los 12 tras una etapa devuelta— grita, y **ese grito se oye en todo el piso** como una muerte (`world_audio.play_everywhere`, con su suelo de volumen): todo el mundo sabe que ya se ha puesto en marcha, y solo de cerca dónde. Es uno de los gruñidos más largos de `grunts.ogg` (2 s o más) con el tono bajado entre 0,78 y 0,88. Grita igual la criatura de la máquina y la del cazador humano en versus: lo decide la máquina que la lleva (`hotel_locust.count_grace()`) y se oye igual en todas (`creature_call("cry", …)`). Salir a perseguir a alguien no es otro grito: eso sigue siendo el gruñido de la alerta.

**La campana del ascensor** (`lifts.LIFT_DING`, `assets/audio/sfx/lift/bell.wav`) suena en todo el piso donde el coche deja a la criatura en el ala siguiente.

Gruñe también el cazador humano en versus mientras corre (antes solo sonaba al chillar), con al menos 1,6 s entre llamadas y 6 dB más bajo para quien lleva la criatura, que la tiene en el oído. Un gruñido que nadie podía oír se reintenta a los 0,7 s en vez de gastar la espera entera, y recuperar de vista a la presa tras perderla más de 1,5 s vale otra llamada.

**La voz cambia de forma según lo que dice** (`VOICE_GRUNT` y `VOICE_SHRIEK` en `hotel_locust.gd`): el chillido empieza 3 dB más alto pero cae más rápido y se corta a 32 m, poco más allá de los 26 m de escucha que le compra al cazador; el gruñido de caza nunca es tan fuerte pero llega a 40 m. La voz cuelga de `world_audio`, no de la criatura, para que un sonido enrutado por un vano se quede en ese vano.

## Lo que se oye con la cordura baja

Por debajo de 60 de cordura el piso empieza a mentirle a quien la está perdiendo: cada cierto tiempo suena una puerta lejana (`close_far`, `open_far`), un armario abriéndose (`hide_leave`) o una puerta lenta (`open_slow`) en un punto sorteado a 4–14 m, **puesto siempre sobre la malla de navegación** para que salga de una sala y no de dentro de un muro. Con menos de 30 empieza a sonar también **la voz de la criatura** —un gruñido completo de `grunts.ogg`, con el tono entre 0,8 y 0,95— desde donde la criatura no está; va por su propio reproductor (`$Phantom`, bus Threat) para no cortar nunca una llamada de verdad, se enruta como cualquier sonido (tras una pared llega por el vano) y se para al terminar el trozo. **Nunca es uno de los ladridos cortos**, que son el aviso de la estocada: el piso miente sobre dónde está la criatura, no sobre eso. La espera entre mentiras va de 40 s a 13 s según lo baja que esté la cordura, con un ±30 % de azar.

**La criatura que pasa** (`game/app/phantom_passage.gd`, de `sanity.walk_past()`): entre una de cada cinco mentiras y casi la mitad, según lo baja que esté la cordura, una criatura que no existe recorre la ruta entre dos salas vecinas a 12–20 m andando del oyente, fuera de su vista y sin pasar nunca a menos de 8 m, a 1,9 m/s durante hasta 10 s. **Suena con los sonidos de la de verdad**, no con copias: sus garras son `hotel_locust.claw_sound()` a su ritmo de paso, enrutadas como `on_footfall`; y el punto que camina se escribe en `world_audio.phantom_point`, que la presencia (`world_audio`, con su subtítulo) y el aura (`dread_aura.update_route()`: drone, respiración, chasquidos, latido y el filtro del ambiente) toman como la criatura siempre que esté más cerca que la real. No empieza con la de verdad a menos de 30 m de ruta o con el aura ya por encima de 0,2, ni en el refugio.

Son **locales de cada máquina**: no pasan por `match_net.noise()`, así que la criatura no las oye, no la mandan a ninguna parte y los compañeros no las oyen tampoco. En una ejecución silenciosa (pruebas, capturas) la cadencia se cuenta igual aunque no suene nada, como con los gruñidos.

## Armarios

Entrar y salir suenan con las grabaciones de armario y hacen un ruido que la criatura oye hasta 12 m (45 m si la lleva un jugador). La primera vez que se entreabren las puertas en cada estancia cruje en voz baja (se oye hasta 10,5 m); cambiar de lado o volver a abrir no suena.

## Apertura lenta

La puerta abierta despacio y el asomarse del armario usan `door/opening/slow-opening-clean.wav`, sacado de `creaky-wooden-door-slow-opening.mp3` por `tools/audio/clean_recordings.py`: filtro de graves bajo 120 Hz y puerta espectral contra el ruido de micrófono, y un descenso de 10 dB a lo largo del sonido con un desvanecimiento final, para que no termine fuerte. Suena 5 dB por debajo que antes (−12 dB, frente a +1 de una apertura normal; asomarse, −25).

## Pasos del jugador

Las tomas aportadas están en `sfx/footsteps/` (fuera de git): moqueta caminando, moqueta corriendo y suelo duro caminando. `tools/audio/slice_footsteps.py` las corta en pasos sueltos (`assets/audio/sfx/footsteps/`, WAV mono) y escribe `game/audio/footstep_segments.gd` con el instante del golpe dentro de cada recorte. Las grabaciones de moqueta traen mucha energía por debajo de 35 Hz, que se filtra antes de cortar; cada juego se normaliza a un pico común. Si cambias una toma, vuelve a ejecutar el script.

Las tomas no van al ritmo del juego (moqueta 0,56 s por paso, carrera 0,34 s, suelo duro 0,84 s con talón y punta), así que no se reproducen seguidas: cada pisada del jugador lanza un recorte suelto y, como la pisada sale de la distancia recorrida, el recorte empieza antes lo justo para que su golpe coincida con ella y con la bajada de la cámara (comprobado en `hotel_test`, error ≤ 1 fotograma). Suelo: baldosa en baños, lavandería y mantenimiento; moqueta en el resto. Correr sobre baldosa reutiliza la toma de caminar, más aguda y fuerte. Dos voces alternas evitan cortar la cola del paso anterior.

Los pasos propios van por el bus `Steps` (sigue el deslizador de efectos), con una reverberación corta que toma solo un 30 % de la de la sala y nunca el tamaño de un salón: en los salones unidos ya no retumban. Medido al 50 % con `tools/audio/measure_steps.gd` (promedio de ocho pasos): caminar pico −18 dBFS y correr −13 (antes −6 y −8); la cola de eco en un salón bajó de −43 a −64 dBFS. **Bajados 5 dB más (septiembre de 2026)** porque en pruebas con amigos cansaban: el mismo script da en un dormitorio caminar pico −20 dBFS y correr −15 (antes −16 y −11; la medición es en tiempo real y varía un par de dB entre pasadas). Los pasos de los compañeros (`remote_player.gd`) y los de The Locust (`hotel_locust.on_footfall`) bajaron también 5 dB, y los de la criatura otros 6 dB en la pantalla de quien la lleva, que los tiene debajo de la oreja. El reproductor 3D de los pasos tiene `max_db = 12`: con el tope por defecto (3 dB) el volumen de carrera quedaba recortado y no respondía.

## Escena de entrada

Grabaciones aportadas en `assets/audio/glass/`: `glass-hit-1..3` para los golpes al cristal (con un golpe grave sintetizado debajo, bajo) y `glass-break` para la pantalla que estalla, oída amortiguada a través de la puerta. Sintetizados por `tools/audio/generate_intro_sfx.py` en `assets/audio/intro/`: estática de canal muerto más intensa (siseo de banda ancha con subidas, chasquidos y zumbido de campo a 59,94 Hz), zumbido del tubo, pisadas fuertes para ir hacia la puerta y golpes contra la puerta. La cama es la grabación aportada `assets/audio/bed-sound.m4a` (alguien moviéndose en una cama, 34 s): `tools/audio/clean_recordings.py` la decodifica con `tools/audio/decode_media.ps1` (Media Foundation de Windows, sin instalar nada), le quita ruido y la corta en seis movimientos (`bed_stir`, `bed_sit`, `bed_lean`, `bed_shift`, `bed_press`, `bed_rise`) con los golpes de las manos contra el colchón suavizados. Se reutilizan respiración, dron, crecida de presencia, latidos, portazos, un gruñido y los pasos grabados. `tools/audio/analyze_cue_timing.gd` incluye ahora `assets/audio/glass` para arrancar las grabaciones en su ataque. Niveles al 50 % con `tools/audio/measure_intro.gd`: estática mirando la tele unos −22 dBFS RMS; golpes al cristal pico −2; portazo y rotura pico −1. Incorporarse y apoyarse en la cama: pico −4 y RMS −23 dBFS con la estática debajo.

## Ejecución

La escena, su diseño y sus porqués están en [EXECUTION.md](EXECUTION.md) (sección 11); aquí, lo que suena y de dónde sale. Tres grabaciones aportadas, preparadas por `tools/audio/prepare_execution_sfx.py` desde `sfx/` (los originales no se tocan): `execution_scream.wav` (el grito del agarre), `execution_hit.wav` (el golpe) y `execution_static.ogg` (el canal muerto). Procedencia y licencias en [ASSETS.md](ASSETS.md). **No hay voz humana de la víctima ni se sintetiza ninguna:** todo lo demás son sonidos que el juego ya tenía.

Los tiempos, contados desde el agarre (`game/app/capture_score.gd`). Lo que oye la víctima lo lleva su cinta (`game/app/death_tape.gd`); lo que suena en la sala, `executions.gd`.

- **0,05 s después de que la máscara esté en la lente — el grito** (`capture_score.scream_time`: a los 0,05 s de frente, de lado, desde arriba y en un armario; a los 0,39 s por la espalda, que es cuando la han girado hacia la cara; antes sonaba siempre en el agarre, y por la espalda se oía un tercio de segundo antes de que hubiera nada que ver). En la máquina de la víctima suena plano, a 0 dB, sin posición: no está en la sala, está en su cabeza. En las demás sale de la criatura y se oye en todo el piso (`play_everywhere`). Con «Sobresaltos suaves», 8 dB menos.
- **0,55–1,1 s — el grito se queda atrás.** Cuando la cámara sale de las manos deja de ser una capa: baja de tono (hasta 0,9), se hunde 42 dB y se corta antes de 1,1 s.
- **Desde que la cámara vuela, se oye por su micrófono.** Tres efectos puestos sobre el bus Master mientras dura: paso alto a 120 Hz, paso bajo a 6,5 kHz y una ganancia que hace de control automático. Con ellos entra el siseo de la cinta (`intro/tv_static.wav` en bucle, −33 dB).
- **Al tocar el suelo (hacia 1,3 s de frente: la cámara cae lo que cae una cosa) — la carcasa:** `events/object_fall_1/2.wav` a 0,72 de tono. **Y otra vez por cada golpe que da después** —al acabar el rebote y en cada canto sobre el que vuelca, dos o tres—: el mismo sonido, cada vez más flojo (de −12 a −16 dB) y más agudo (0,88 a 1,06). El micrófono se cierra de golpe (−14 dB) y vuelve a abrirse a 7 dB/s hasta 6 dB por encima: en ese hueco el siseo y la sala vuelven hinchándose, y los sonidos pequeños llegan enormes.
- **1,8 y 2,4 s — roces**, mientras la levanta: `intro/bed_shift.wav` y `bed_stir.wav`.
- **3,08 s — el brazo sale.** El silbido del golpe (`execution_hit.wav`), cortado para que su impacto caiga a los **3,3 s**. Suena desde donde está la criatura, también para su víctima, y el micrófono vuelve a cerrarse (−9 dB).
- **~4,27 s — el cuerpo en el suelo** (lo suelta a 3,5 y tarda 0,9 s en desplomarse; el golpe es el de la espalda contra el suelo): `intro/stomp_1..3.wav` a 0,74 de tono y −7 dB, desde donde cae. Antes caía en silencio, porque con la pantalla ya en negro sonaba a segunda estocada; viéndolo caer, hace falta. El micrófono se cierra por tercera vez.
- **4,27–4,7 s — la cinta se deshace**, desde que el cuerpo toca el suelo, y el sonido con ella: le faltan trozos de cuatro centésimas, cada vez más seguidos (`death_tape.dropout`: catorce trozos por segundo, hasta algo más de la mitad ausentes al final, 22 dB abajo), a la vez que la imagen se rompe. Con «Efectos reducidos», no.
- **4,7 s — el corte.** El canal muerto arranca en el mismo instante en que la imagen se va (bus Effects, −2 dB), y el micrófono y el siseo se quitan. En la versión breve la imagen se va antes —al asentarse la cámara— y la nieve suena baja (−15 dB) por debajo de lo que el micrófono sigue recogiendo, hasta el corte de verdad.

**La sangre** (`game/app/blood.gd`, `sounds()` y `heard()`; EXECUTION.md, 8.7). Cinco archivos en `assets/audio/sfx/blood/`, cortados por el autor de dos grabaciones de dominio público: `blood-gush-1..4.ogg` (1,5 a 2 s: un trapo mojado escurrido) y `hemorrhage.ogg` (5,6 s: un chorro que acaba en borbotones). Suenan desde la herida, por la ruta de cualquier sonido de la sala (`world_audio.play_at`, bus Effects): **0,04 s** — un borboteo por la espalda, a −12,5 dB, debajo del grito; **3,32 s** — el chorro del golpe, a −6 dB, que sigue cinco segundos, más allá del corte de la cinta de quien muere; **3,54 / 3,75 / 3,96 / 4,17 s** — cuatro borboteos del pecho mientras cae, a −10, −13,5, −17 y −20,5 dB. (Estaban unos 4 dB más altos; el autor los pidió algo más sutiles.) Con «Efectos reducidos» no hay los cuatro últimos; con «Sangre» apagada, ninguno. El goteo bajo el cuerpo no suena: no hay grabación.

**Nada baja antes del golpe.** La presencia, el ambiente y la música no se apartan (la presencia bajaba 16 dB durante la embestida): era una señal nueva en el medio segundo anterior, justo donde menos conviene (EXECUTION.md, 5.3). El autor comparó las dos versiones y se quedó sin ella; el interruptor (`windup_tear`) ya no existe, y la embestida de la IA tampoco.

**La finta calla lo que la delata.** Esperando junto a un armario (`hotel_locust.hushed()`), su presencia grabada se apaga del todo en menos de dos segundos y el aura baja al 15 % en unos cinco (`dread_aura.HUSHED`); vuelven cuando salta o se va. Sus pasos no se tocan: los que da para apartarse y los que da para irse se oyen como siempre.

**Salir de un armario en silencio** (la tecla mantenida tres segundos) se oye a tres cuartos de la distancia de salir de golpe: `noise_kinds.HEARD.wardrobe_slow = 12 m × QUIET (0,75)`, para la IA y para el cazador, y el golpe de las puertas suena más bajo.

En la ejecución no queda nada sintetizado: los golpes y el cuerpo generados de la versión anterior (`execution_stab_1..3.wav`, `execution_drop.wav`) se borraron, y `generate_event_sfx.py` ya no los produce. **Medido** (`python tools/capture/film_check.py evidence/captura_frente.avi --caught=5.54`, sobre las tres películas de `./tools/godot.ps1 bench-films` —de frente, por la espalda y en el armario—, con los volúmenes por defecto, tras la segunda vuelta del 12 de octubre): la caza previa, −14 a −15 LUFS; la captura entera (4,7 s), de −6,7 a −10,5; el medio segundo del grito —que empieza 0,05 s después de la máscara: a 0,39 s por la espalda—, de −1,9 a −2,7 con el pico en −0,5 dBFS; con la cámara ya quieta en el suelo, hasta el golpe, de −13,5 a −21 (antes de −18 a −23: los golpes de los vuelcos cierran el micrófono menos que el primero y vuelve a abrirse antes). El cedazo de destellos de la misma herramienta da las tres películas dentro de tres por segundo, con las bandas de cada golpe de la caída incluidas. **Pendiente:** escucharla con auriculares y decidir si el grito se baja; grabaciones propias para la carcasa, los roces y el cuerpo (hoy son sonidos prestados de otras escenas, bajados de tono).

## Pasos de los compañeros

En red, cada superviviente suena con los mismos recortes grabados que el jugador local, desde su cuerpo y con la propagación por rutas. Van más bajos que antes (caminar −14 dB, correr −8, agachado −24, +2 en baldosa) para que un compañero corriendo en la sala de al lado no se confunda con la criatura. Pendiente de escucha humana.

La ruta de los sonidos ocluidos se calcula desde la cámara que escucha, no desde el cuerpo del jugador: al observar a un compañero tras morir, lo que se oye corresponde a lo que se ve.

## El oído de la criatura, medido una sola vez

`hotel_locust.hear_route(point, radius)` es la única medición de su oído: si lo oye, por qué abertura le llega, cuántos metros de ruta ha recorrido el sonido y cuánto llega amortiguado. `can_hear()` es esa misma función, así que ya no se consulta la navegación dos veces por ruido. Es el equivalente de `world_audio.route_source()` pero anclado en la criatura en vez de en quien escucha, y deliberadamente separado: el mezclador de audio no debe conocer la percepción de la criatura.

Cada ruido lleva además su clase (`game/audio/noise_kinds.gd`), que el audio ignora y la vista acústica del cazador usa para responder «qué lo produjo». El zumbido de las balastras que `update_ambient_sources()` ya enruta hace doble trabajo: en la máquina del cazador aparece también como contacto débil en su imagen (`docs/VISION_LOCUST.md`).

## Sonidos largos

Los sonidos de más de unos segundos —la estática de una tele que se enciende, la del apagón, la del salto por tele— no van por el grupo de ocho voces de los efectos cortos: con catorce segundos eran siempre los más viejos de ese grupo y las siguientes puertas los cortaban a medias. Tienen reproductores propios (`world_audio.play_long()`, `long_cues`), que se vuelven a enrutar cada 0,25 s mientras el oyente se mueve (como los zumbidos) y se quedan mudos, no parados, mientras la ruta no llega. Se pueden parar antes (`stop_long()`) y darles una duración con desvanecido final. Los que suenan «desde arriba, estés donde estés» (el apagón) siguen al oyente en vez de quedarse en un sitio. `long_playing()` dice si la misma grabación acaba de empezar y se oye aquí, para no tocarla dos veces.

## Las teles

Encender una tele suena a **tele**: la estática entera del canal muerto del apagón (`execution_static.ogg`, unos 14 s) desde su pantalla, a −6 dB y enrutada como todo (paredes y puertas cerradas la tapan). Cuando se acaba, la tele **se queda siseando** mientras siga encendida: `assets/audio/intro/tv_static.wav` en bucle, a −27 dB y con 11 m de alcance, en las dos teles encendidas más cercanas a quien escucha (`world_audio.update_tv_hiss()`, como los zumbidos de los fluorescentes), que sube en 1,5 s bajo la cola de la estática. Las teles siguen encendidas durante el apagón, así que su siseo no se corta con la luz.

- Hasta septiembre de 2026 encender una tele sonaba a `closing1.ogg`, el pestillo de una puerta, más fuerte que el cierre de una puerta de verdad: parecía un portazo. Nunca tuvo otro sonido. La estática que se oía era la del apagón, que con uno o dos supervivientes salta al encender la primera tele.
- **El apagón que dispara una tele no suena dos veces:** si la misma estática acaba de empezar y se oye aquí, `apply_blackout()` no la repite. Si no (lejos de esa tele), suena desde encima de quien escucha, esté donde esté.
- **Al volver la luz**, en el ala siguiente, quien va en el ascensor oye 1,6 s de esa estática encima (`restore_power()`); antes se colocaba en el cuerpo, que en ese momento del viaje sigue en el coche que se deja.
- Una tele que se apaga (una etapa que se vuelve a jugar) calla al instante. Quien vuelve a una partida recibe las teles encendidas sin oírlas encenderse.
- Para la criatura nada cambia: encender una tele sigue siendo un ruido de puerta abierta despacio (9 m).

## El teclado del código

El teclado suena a teclado: un clic por tecla, un zumbido grave doble para «NO ES» y «FALTAN TELEVISORES» y dos tonos subiendo para el código bueno, sintetizados como los pitidos del menú (`osd_style.tones()`, `hotel_ui.keypad()`). Los oye solo quien teclea y no son ruido para la criatura. Hasta septiembre de 2026 un código erróneo sonaba al crujido de una puerta y el bueno al pestillo del último coche: parecía que se estaba probando una puerta sin que nada se moviera.

## El ascensor

Cuatro grabaciones aportadas en `sfx/elevator/` (las puertas y la bajada, CC0; la campana, «toaster oven or lift/elevator bell» de azumarill, CC BY 3.0), preparadas por `tools/audio/prepare_lift_sfx.py` en `assets/audio/sfx/lift/`: mono, cortadas de su primer sonido a donde se apagan, con fundidos y el mismo pico. **El viaje se mide en ellas** (`lifts.RIDE_*`): las puertas se cierran (`doors_close.wav`, 2,8 s, en el coche que se deja) mientras se ven correr las hojas (`DOOR_CLOSING`, 1,7 s, hasta el golpe de la grabación), y la imagen se va cuando han cerrado (`RIDE_SHUT`). A los 0,8 s empieza la bajada (`descent.wav`, 7,1 s, oída desde dentro, solo quien viaja). La campana suena a los 7,3 s y las puertas se abren a los 7,7 (`DOOR_OPENING`, 1,6 s); su sonido (`doors_open.wav`, 2 s) empieza 0,2 s antes, que es lo que tarda en arrancar la grabación. Las dos suenan en el coche de llegada y las oye quien esté allí. La imagen vuelve con ellas y a los 8,5 s el cuerpo se suelta. El último coche: puertas y 4 s de bajada. **Una vez por viaje** aunque vayan cuatro (`lifts.car_doors()`, por sonido y sitio). Cuando baja la criatura, se abren las puertas donde sale y **la campana suena en todo el piso** (`play_everywhere`). Durante el corte sigue la nieve que se ve: `tv_static.wav` a −20 dB siguiendo la imagen, en `presentation_rig.update_ride_hiss()`.

## Eventos del director

Sonidos sintetizados por `tools/audio/generate_event_sfx.py` en `assets/audio/events/`: dos caídas de un objeto de madera (inclinación, golpe, rebote y rodar) y dos series de tres golpes con los nudillos en una puerta. Se reproducen con `world_audio.play_at()`, así que llegan por la ruta caminable con eco como cualquier otro sonido. Los golpes en la puerta no los oye la criatura (son una jugada del director, solo sonido); la caída es la **distracción** del director para un equipo escondido, lejos, y la manda a investigar directamente, sin pasar por su oído.