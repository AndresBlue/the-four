# Audio del hotel — integración de sfx

## Implementado

Se catalogaron 33 archivos aportados en `sfx/`. Se asignaron **30** a funciones actuales; los otros tres permanecen reservados. Los originales no se editaron ni movieron. `sfx/` queda fuera de la importación de Godot y de Git; respáldala junto con `source_assets/`. Las copias que puede usar el proyecto están en `assets/audio/sfx/`.

- **Puertas cercanas:** cuatro aperturas y cuatro cierres, con elección aleatoria local que evita repetir inmediatamente la misma grabación. Apertura lenta: crujido prolongado. Pequeña variación de tono entre 0,98 y 1,02.
- **Puertas lejanas:** dos aperturas y dos cierres con distancia/eco ya presentes en la grabación. Se elige ese grupo a partir de 12 m al comenzar el sonido, sin cambiar de grabación a mitad del efecto. Ambos grupos se atenúan espacialmente; alcance máximo 32 m.
- **Cierre coherente:** el golpe de cierre espera a que termine el movimiento y la grabación arranca justo antes de su impacto, para que el pestillo coincida con la hoja. Si el umbral está ocupado y la puerta vuelve a abrirse, no se reproduce un cierre falso. Abrir puertas durante la construcción del mapa no produce sonidos.
- **Escondites:** cuatro entradas y cuatro salidas de armario, ligadas a las acciones que realmente se completan. La geometría actual sigue siendo el escondite provisional de madera/cortinas; los armarios con puertas y abertura visual quedan pendientes.
- **Ambiente:** `dark terror ambience.wav` sustituye la cama ambiental global por una copia de trabajo estéreo. La ventilación conserva el audio anterior como fuente localizada. La música anterior sigue disponible a un nivel más bajo.
- **Identidad de Locust:** `terror ambience (dark presence).wav` es su presencia espacial, con origen en la criatura. Se oye dentro de 26 m, entra/sale gradualmente y no se activa durante la protección inicial ni dentro del refugio. Deja de sonar al terminar el desvanecimiento al entrar en refugio. Las paredes reducen su nivel y agudos. El aviso de ataque original se conserva y la presencia baja 16 dB durante su preparación.
- **Mezcla:** puertas/escondites en Effects, ambiente en Ambience, música en Music y presencia/aviso de amenaza en Threat. Máximo ocho efectos de interacción simultáneos; la presencia tiene su propio reproductor. Pausa conserva el estado; muerte, menú y reintento limpian los efectos.
- **Subtítulos:** puertas y presencia tienen texto, sujeto a los ajustes. Las señales de presencia no se repiten continuamente y no reemplazan el aviso de ataque.

La atenuación direccional usa AudioStreamPlayer3D; la oclusión por pared es una aproximación mediante rayo y reducción de nivel/agudos, no una simulación completa de acústica por habitaciones. Referencia técnica: [AudioStreamPlayer3D en Godot](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html).

## Preparados o reservados

- `paper/paper.ogg`: copia preparada para abrir la hoja de dibujo. **Sin disparador todavía:** la hoja no está implementada. Será un sonido local de interfaz, no un evento de ruido para la IA, y se disparará una vez al abrir, no por cada trazo.
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

## Aura de The Locust

`game/audio/dread_aura.gd` (nodo `WorldAudio/DreadAura`) calcula cada 0,25 s la distancia **por ruta caminable** entre jugador y criatura. La intensidad crece desde 38 m hasta 5 m y aumenta si investiga o persigue; es cero durante la protección inicial y en el refugio.

- **Dirección sin revelar la posición:** respiración, chasquidos y crecidas suenan unos metros por delante del jugador (7,5 m lejos, 2,5 m cerca) **sobre la ruta por la que llegaría**. Se oye por qué puerta o pasillo viene aunque haya paredes, pero no dónde está exactamente.
- **Presión:** dron grave desafinado (no direccional), ambiente amortiguado y música que se retira. Latidos desde intensidad 0,5, de 64 a 128 ppm.
- **Subtítulo direccional** al cruzar intensidad 0,3: `[Algo se acerca · izquierda/derecha/delante/detrás]`, como máximo cada 20 s.
- La presencia grabada sigue sonando desde la propia criatura, con oclusión por paredes. El aura es solo presentación: no altera percepción, rutas ni ataques.

Capas generadas por `tools/audio/generate_dread_layers.py` en `assets/audio/dread/` (WAV mono 16 bits, reproducibles): dron, respiración, cuatro chasquidos y zumbido de fluorescente; más una copia mono de `sub-riser-presence.wav` (crecida). Se pueden sustituir por grabaciones propias con el mismo nombre.

## Atmósfera local

- Zumbido de fluorescentes: todos los tubos de las salas de servicio zumban, hasta dos fuentes en los más cercanos (13 m), que se apagan con cada parpadeo. Un tubo de otra sala solo llega por la abertura, como cualquier sonido. Medido al 50 % con `tools/audio/measure_hum.gd`: −31 dBFS RMS debajo, −34 a 3 m, −40 a 5 m.
- Pasos de The Locust: golpe seco sintetizado de pata punzante sobre un golpe hueco, en cada pisada real de la animación.

Pendiente: escucha crítica con auriculares, balance del aura en partidas humanas y perfiles de las otras criaturas.

## Propagación entre salas

`world_audio.route_source()` decide por dónde llega un sonido. Con línea libre llega directo desde su origen. Si hay muros de por medio sigue la ruta caminable y se oye desde la última abertura visible (una puerta o una esquina): más bajo según el rodeo, más apagado y por los buses `EffectsEcho` o `ThreatEcho` (retardos de 170/340 ms y reverberación amplia), que envían a Effects o Threat. Nada atraviesa muros. Más allá de 42 m de ruta no se oye.

Lo usan los golpes de puerta, los pasos, la presencia y los gruñidos de The Locust. La criatura oye al jugador por la misma lógica de rutas pero a 2,6 veces el radio de cada ruido, y el aura empieza a 24 m de ruta: la criatura siempre detecta antes de lo que el jugador puede oírla.

## Gruñidos de persecución

`assets/audio/sfx/chase/grunts.ogg` (aportado) se divide en gruñidos sueltos con `tools/audio/analyze_grunts.gd`, que escribe `game/audio/grunt_segments.gd`. Solo se usan los gruñidos completos (1,4 s o más; los trozos cortos son respiraciones), sin repetir el mismo dos veces seguidas. Suena uno en cuanto la criatura te ve y se gira hacia ti (alerta), el siguiente cuando termina ese y después uno cada 2,5–5 s mientras persigue, con la misma propagación. El corte respeta el tono aleatorio, así que no se truncan. Si cambias la grabación, vuelve a ejecutar el analizador.

## Armarios

Entrar y salir suenan con las grabaciones de armario y hacen un ruido que la criatura puede oír (radio 4). La primera vez que se entreabren las puertas en cada estancia cruje en voz baja (radio 2); cambiar de lado o volver a abrir no suena.

## Pasos del jugador

Las tomas aportadas están en `sfx/footsteps/` (fuera de git): moqueta caminando, moqueta corriendo y suelo duro caminando. `tools/audio/slice_footsteps.py` las corta en pasos sueltos (`assets/audio/sfx/footsteps/`, WAV mono) y escribe `game/audio/footstep_segments.gd` con el instante del golpe dentro de cada recorte. Las grabaciones de moqueta traen mucha energía por debajo de 35 Hz, que se filtra antes de cortar; cada juego se normaliza a un pico común. Si cambias una toma, vuelve a ejecutar el script.

Las tomas no van al ritmo del juego (moqueta 0,56 s por paso, carrera 0,34 s, suelo duro 0,84 s con talón y punta), así que no se reproducen seguidas: cada pisada del jugador lanza un recorte suelto y, como la pisada sale de la distancia recorrida, el recorte empieza antes lo justo para que su golpe coincida con ella y con la bajada de la cámara (comprobado en `hotel_test`, error ≤ 1 fotograma). Suelo: baldosa en baños, lavandería y mantenimiento; moqueta en el resto. Correr sobre baldosa reutiliza la toma de caminar, más aguda y fuerte. Dos voces alternas evitan cortar la cola del paso anterior.

Los pasos propios van por el bus `Steps` (sigue el deslizador de efectos), con una reverberación corta que toma solo un 30 % de la de la sala y nunca el tamaño de un salón: en los salones unidos ya no retumban. Medido al 50 % con `tools/audio/measure_steps.gd` (promedio de ocho pasos): caminar pico −18 dBFS y correr −13 (antes −6 y −8); la cola de eco en un salón bajó de −43 a −64 dBFS. El reproductor 3D de los pasos tiene `max_db = 12`: con el tope por defecto (3 dB) el volumen de carrera quedaba recortado y no respondía.

## Escena de entrada

Sonidos sintetizados por `tools/audio/generate_intro_sfx.py` en `assets/audio/intro/`: estática y zumbido de la tele (en bucle), tres golpes en el cristal desde dentro (golpe sordo, resonancia de vidrio y grietas que crecen), la rotura de la pantalla y tres golpes contra la puerta oídos desde el pasillo. Se reutilizan la respiración, el dron y la crecida de presencia, los latidos, los portazos de puerta, un gruñido de persecución y los pasos de carrera sobre moqueta. La rotura, los golpes y el gruñido pasan por un filtro que los apaga, porque llegan a través de la puerta cerrada. Niveles al 50 % medidos con `tools/audio/measure_intro.gd`: tele y respiración al despertar −33 dBFS RMS; golpes al cristal pico −8; portazo y rotura pico −1, sin llegar al limitador.