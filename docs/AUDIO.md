# Audio del hotel — integración de sfx

## Implementado

Se catalogaron 33 archivos aportados en `sfx/`. Se asignaron **30** a funciones actuales; los otros tres permanecen reservados. Los originales no se editaron ni movieron. `sfx/` queda fuera de la importación de Godot y de Git; respáldala junto con `source_assets/`. Las copias que puede usar el proyecto están en `assets/audio/sfx/`.

- **Puertas cercanas:** cuatro aperturas y cuatro cierres, con elección aleatoria local que evita repetir inmediatamente la misma grabación. Apertura lenta: crujido prolongado. Pequeña variación de tono entre 0,98 y 1,02.
- **Puertas lejanas:** dos aperturas y dos cierres con distancia/eco ya presentes en la grabación. Se elige ese grupo a partir de 12 m al comenzar el sonido, sin cambiar de grabación a mitad del efecto. Ambos grupos se atenúan espacialmente; alcance máximo 32 m.
- **Cierre coherente:** el golpe de cierre espera a que termine el movimiento y la grabación arranca justo antes de su impacto, para que el pestillo coincida con la hoja. Si el umbral está ocupado y la puerta vuelve a abrirse, no se reproduce un cierre falso. Abrir puertas durante la construcción del mapa no produce sonidos.
- **Escondites:** cuatro entradas y cuatro salidas de armario, ligadas a las acciones que realmente se completan. Los armarios son ya los de doble puerta: solo la primera apertura de cada estancia cruje, y asomarse abriendo las hojas tiene su propio sonido.
- **Ambiente:** `dark terror ambience.wav` sustituye la cama ambiental global por una copia de trabajo estéreo. La ventilación conserva el audio anterior como fuente localizada. La música anterior sigue disponible a un nivel más bajo.
- **Identidad de Locust:** `terror ambience (dark presence).wav` es su presencia espacial, con origen en la criatura. Se oye dentro de 26 m, entra/sale gradualmente y no se activa durante la protección inicial ni dentro del refugio. Deja de sonar al terminar el desvanecimiento al entrar en refugio. Las paredes reducen su nivel y agudos. El aviso de ataque original se conserva y la presencia baja 16 dB durante su preparación.
- **Mezcla:** puertas/escondites en Effects, ambiente en Ambience, música en Music y presencia/aviso de amenaza en Threat. Máximo ocho efectos de interacción simultáneos; la presencia tiene su propio reproductor. Pausa conserva el estado; muerte, menú y reintento limpian los efectos.
- **Subtítulos:** puertas y presencia tienen texto, sujeto a los ajustes. Las señales de presencia no se repiten continuamente y no reemplazan el aviso de ataque.

La atenuación direccional usa AudioStreamPlayer3D; la oclusión por pared es una aproximación mediante rayo y reducción de nivel/agudos, no una simulación completa de acústica por habitaciones. Referencia técnica: [AudioStreamPlayer3D en Godot](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html).

## Preparados o reservados

- `paper/paper.ogg`: suena al leer un documento (sonido local, no es un ruido para la IA). También está previsto para abrir la futura hoja de dibujo.
- `heartbeat/1.ogg` y `2.ogg`: preparados para evaluar tensión/claustrofobia, sin reproducción automática por ahora.
- Cuatro grabaciones `hard-*`: se usan como portazo cuando el jugador abre o cierra una puerta mientras corre. Ese giro es más rápido y su ruido jugable llega a 18 m (normal: 12 m; lento: 3 m).
- `sub-riser-presence.wav`: reservado para una transición de presencia anunciada; no se suma al aviso corto de ataque para no ocultarlo.
- `big-hall-far-prop-glass-noise.wav`: reservado para un evento ambiental con origen válido en un salón existente.
- `metalic-sliding-long-door.wav`: reservado para un ascensor/puerta metálica compatible.

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

Ganancias actuales: apertura −5 dB, portazo −1 dB, apertura lenta −12 dB y escondites −13 dB. La escucha crítica con auriculares sigue pendiente.

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

`game/audio/dread_aura.gd` (nodo `WorldAudio/DreadAura`) calcula cada 0,25 s la distancia **por ruta caminable** entre jugador y criatura. La intensidad crece desde 38 m hasta 5 m y aumenta si investiga o persigue; es cero durante la protección inicial y en el refugio.

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

Lo usan los golpes de puerta, los pasos, la presencia y los gruñidos de The Locust. La criatura oye al jugador por la misma lógica de rutas pero hasta la distancia de cada ruido en la tabla `HEARD` de `noise_kinds.gd` (de 8 m agachado a 64 m corriendo sobre baldosa), y el aura empieza a 24 m de ruta: la criatura siempre detecta antes de lo que el jugador puede oírla.

## Gruñidos de persecución

**El aviso de la estocada también sale de la misma grabación**: 0,3 s antes de embestir suena uno de los trozos cortos de `grunts.ogg` (los que no llegan a 1,4 s: ladridos y respiraciones), con el tono bajado entre 0,78 y 0,9. Antes era un barrido sintetizado de 190 Hz hacia arriba, que no sonaba a animal. Sigue siendo la señal que te dice que esquives, y no la tapa nada: va por su propio reproductor (`$Warning`).

`assets/audio/sfx/chase/grunts.ogg` (aportado) se divide en gruñidos sueltos con `tools/audio/analyze_grunts.gd`, que escribe `game/audio/grunt_segments.gd`. Solo se usan los gruñidos completos (1,4 s o más; los trozos cortos son respiraciones), sin repetir el mismo dos veces seguidas. Suena uno en cuanto la criatura te ve y se gira hacia ti (alerta), el siguiente cuando termina ese y después uno cada 2,5–5 s mientras persigue, con la misma propagación. El corte respeta el tono aleatorio, así que no se truncan. Si cambias la grabación, vuelve a ejecutar el analizador.

Gruñe también el cazador humano en versus mientras corre (antes solo sonaba al chillar), con al menos 1,6 s entre llamadas y 6 dB más bajo para quien lleva la criatura, que la tiene en el oído. Un gruñido que nadie podía oír se reintenta a los 0,7 s en vez de gastar la espera entera, y recuperar de vista a la presa tras perderla más de 1,5 s vale otra llamada.

**La voz cambia de forma según lo que dice** (`VOICE_GRUNT` y `VOICE_SHRIEK` en `hotel_locust.gd`): el chillido empieza 3 dB más alto pero cae más rápido y se corta a 32 m, poco más allá de los 26 m de escucha que le compra al cazador; el gruñido de caza nunca es tan fuerte pero llega a 40 m. La voz cuelga de `world_audio`, no de la criatura, para que un sonido enrutado por un vano se quede en ese vano.

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

Tres grabaciones aportadas, preparadas por `tools/audio/prepare_execution_sfx.py` desde `sfx/` (los originales no se tocan): `execution_scream.wav` (el grito del agarre), `execution_hit.wav` (el golpe) y `execution_static.ogg` (el canal muerto). Procedencia y licencias en [ASSETS.md](ASSETS.md).

Los tiempos, contados desde el agarre:

- **0,0 s — el grito.** En la máquina de la víctima suena plano, a 0 dB, sin posición: no está en la sala, está en su cabeza. En las demás sale de la criatura por la propagación normal.
- **2,58 s — el brazo sale.** Empieza el silbido del golpe, cortado para que su impacto caiga 0,22 s después, que es justo lo que tarda el brazo en pasar de un punto a tapar la lente. El negro crece desde donde está su mano derecha en la pantalla, que desde los ojos de la víctima queda a la izquierda.
- **2,8 s — el impacto**, con la pantalla ya negra.
- **2,92 s — la estática.** El canal muerto arranca **en el mismo instante** en que la imagen se va (bus Effects, −2 dB): sonido e imagen son el mismo suceso.
- **3,1 s** cae el cuerpo, **en silencio**: un golpe tres décimas después del otro se oía como una segunda estocada.

En la ejecución no queda nada sintetizado: los golpes y el cuerpo generados de la versión anterior (`execution_stab_1..3.wav`, `execution_drop.wav`) se han borrado, y `generate_event_sfx.py` ya no los produce.

## Pasos de los compañeros

En red, cada superviviente suena con los mismos recortes grabados que el jugador local, desde su cuerpo y con la propagación por rutas. Van más bajos que antes (caminar −14 dB, correr −8, agachado −24, +2 en baldosa) para que un compañero corriendo en la sala de al lado no se confunda con la criatura. Pendiente de escucha humana.

La ruta de los sonidos ocluidos se calcula desde la cámara que escucha, no desde el cuerpo del jugador: al observar a un compañero tras morir, lo que se oye corresponde a lo que se ve.

## El oído de la criatura, medido una sola vez

`hotel_locust.hear_route(point, radius)` es la única medición de su oído: si lo oye, por qué abertura le llega, cuántos metros de ruta ha recorrido el sonido y cuánto llega amortiguado. `can_hear()` es esa misma función, así que ya no se consulta la navegación dos veces por ruido. Es el equivalente de `world_audio.route_source()` pero anclado en la criatura en vez de en quien escucha, y deliberadamente separado: el mezclador de audio no debe conocer la percepción de la criatura.

Cada ruido lleva además su clase (`game/audio/noise_kinds.gd`), que el audio ignora y la vista acústica del cazador usa para responder «qué lo produjo». El zumbido de las balastras que `update_ambient_sources()` ya enruta hace doble trabajo: en la máquina del cazador aparece también como contacto débil en su imagen (`docs/VISION_LOCUST.md`).

## Eventos del director

Sonidos sintetizados por `tools/audio/generate_event_sfx.py` en `assets/audio/events/`: dos caídas de un objeto de madera (inclinación, golpe, rebote y rodar) y dos series de tres golpes con los nudillos en una puerta. Se reproducen con `world_audio.play_at()`, así que llegan por la ruta caminable con eco como cualquier otro sonido. Los golpes en la puerta no los oye la criatura; la caída la manda a investigar directamente, sin pasar por su oído.