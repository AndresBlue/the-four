# Audio del hotel â€” integraciÃ³n de sfx

## Implementado

Se catalogaron 33 archivos aportados en `sfx/`. Se asignaron **23** a funciones actuales; los otros diez permanecen reservados. Los originales no se editaron ni movieron. `sfx/` queda fuera de la importaciÃ³n de Godot y de Git; respÃ¡ldala junto con `source_assets/`. Las copias que puede usar el proyecto estÃ¡n en `assets/audio/sfx/`.

- **Puertas cercanas:** cuatro aperturas y cuatro cierres, con elecciÃ³n aleatoria local que evita repetir inmediatamente la misma grabaciÃ³n. Apertura lenta: crujido prolongado. PequeÃ±a variaciÃ³n de tono entre 0,98 y 1,02.
- **Puertas lejanas:** dos aperturas y dos cierres con distancia/eco ya presentes en la grabaciÃ³n. Se elige ese grupo a partir de 12 m al comenzar el sonido, sin cambiar de grabaciÃ³n a mitad del efecto. Ambos grupos se atenÃºan espacialmente; alcance mÃ¡ximo 32 m.
- **Cierre coherente:** el golpe de cierre espera a que termine el movimiento. Si el umbral estÃ¡ ocupado y la puerta vuelve a abrirse, no se reproduce un cierre falso. Abrir puertas durante la construcciÃ³n del mapa no produce sonidos.
- **Escondites:** cuatro entradas y cuatro salidas de armario, ligadas a las acciones que realmente se completan. La geometrÃ­a actual sigue siendo el escondite provisional de madera/cortinas; los armarios con puertas y abertura visual quedan pendientes.
- **Ambiente:** `dark terror ambience.wav` sustituye la cama ambiental global por una copia de trabajo estÃ©reo. La ventilaciÃ³n conserva el audio anterior como fuente localizada. La mÃºsica anterior sigue disponible a un nivel mÃ¡s bajo.
- **Identidad de Locust:** `terror ambience (dark presence).wav` es su presencia espacial, con origen en la criatura. Se oye dentro de 26 m, entra/sale gradualmente y no se activa durante la protecciÃ³n inicial ni dentro del refugio. Deja de sonar al terminar el desvanecimiento al entrar en refugio. Las paredes reducen su nivel y agudos. El aviso de ataque original se conserva y la presencia baja 16 dB durante su preparaciÃ³n.
- **Mezcla:** puertas/escondites en Effects, ambiente en Ambience, mÃºsica en Music y presencia/aviso de amenaza en Threat. MÃ¡ximo ocho efectos de interacciÃ³n simultÃ¡neos; la presencia tiene su propio reproductor. Pausa conserva el estado; muerte, menÃº y reintento limpian los efectos.
- **SubtÃ­tulos:** puertas y presencia tienen texto, sujeto a los ajustes. Las seÃ±ales de presencia no se repiten continuamente y no reemplazan el aviso de ataque.

La atenuaciÃ³n direccional usa AudioStreamPlayer3D; la oclusiÃ³n por pared es una aproximaciÃ³n mediante rayo y reducciÃ³n de nivel/agudos, no una simulaciÃ³n completa de acÃºstica por habitaciones. Referencia tÃ©cnica: [AudioStreamPlayer3D en Godot](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html).

## Preparados o reservados

- `paper/paper.ogg`: copia preparada para abrir la hoja de dibujo. **Sin disparador todavÃ­a:** la hoja no estÃ¡ implementada. SerÃ¡ un sonido local de interfaz, no un evento de ruido para la IA, y se dispararÃ¡ una vez al abrir, no por cada trazo.
- `heartbeat/1.ogg` y `2.ogg`: preparados para evaluar tensiÃ³n/claustrofobia, sin reproducciÃ³n automÃ¡tica por ahora.
- Cuatro grabaciones `hard-*`: reservadas para golpes/portazos explÃ­citos. No se hacen pasar aperturas normales por un portazo ni se altera su ruido jugable.
- `sub-riser-presence.wav`: reservado para una transiciÃ³n de presencia anunciada; no se suma al aviso corto de ataque para no ocultarlo.
- `big-hall-far-prop-glass-noise.wav`: reservado para un evento ambiental con origen vÃ¡lido en un salÃ³n existente.
- `metalic-sliding-long-door.wav`: reservado para un ascensor/puerta metÃ¡lica compatible.

Los perfiles de Sunman, The Boiled One y Guilt se asignarÃ¡n al integrar sus criaturas. No se reproduce una amenaza que todavÃ­a no existe en el nivel.

## Editar y ampliar

`game/audio/world_audio.tscn` expone distancia para grabaciones lejanas y lÃ­mite de voces. `world_audio.gd` contiene los grupos y ganancias; sus sorteos usan un generador independiente, sin alterar semillas del mapa ni percepciÃ³n de la IA. Las seÃ±ales de ruido jugable existentes siguen separadas de los efectos audibles.

`game/audio/profiles/locust.tres` permite cambiar el audio, volumen, alcance y subtÃ­tulo desde el Inspector. El controlador de Locust expone `sound_profile`. `creature_audio_profile.gd` define el recurso reutilizable para futuros personajes.

Las dos copias WAV largas se convierten a 16 bits y la mitad de frecuencia con filtrado previo; presencia pasa a mono para localizar su origen. Se solapa un segundo entre final e inicio, sin tocar los originales. Ambiente: 24 kHz estÃ©reo; presencia: 22,05 kHz mono. Se limita el pico a 0,8 sin amplificar grabaciones ya mÃ¡s silenciosas. Las copias de OGG/MP3 son idÃ©nticas a los archivos aportados.

Inventario, huellas, datos WAV y tratamiento: `docs/assets/sfx_inventory.json`. Duraciones decodificadas por Godot: `sfx_runtime_inventory.json`. Esta asignaciÃ³n inicial usa nombres, anÃ¡lisis tÃ©cnico y pruebas de reproducciÃ³n; la selecciÃ³n auditiva final y el balance con auriculares en partidas humanas siguen pendientes. No se afirma haber realizado una escucha crÃ­tica completa de los 33 archivos.

AutorÃ­a/licencias: aportados por el usuario, pendientes de documentar antes de distribuciÃ³n. La integraciÃ³n no cambia ese estado.

## Comprobar

`./tools/verify.ps1` incluye `tests/hotel/spatial_audio_test.gd`, en tiempo real. Comprueba variaciÃ³n, grupos por distancia, cierre coherente, escondites, origen de presencia, reducciÃ³n durante ataque, oclusiÃ³n, panorama estÃ©reo capturado, atenuaciÃ³n y limpieza tras muerte.

Resultado inicial: **18/18**. Las regresiones de hotel, supervivencia, contratos de escenas, audio anterior y prototipo histÃ³rico tambiÃ©n se ejecutan. La captura estÃ©reo automatizada verifica el funcionamiento; no sustituye la evaluaciÃ³n subjetiva de mezcla.

Para reproducir las copias desde los originales: `tools/audio/prepare_sfx.py` (Python 3 con NumPy), seguido de la importación de Godot y `tools/audio/catalog.gd`. El preparador localiza la raíz desde su propia ruta; no depende de la letra de unidad del equipo.
