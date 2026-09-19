# Fotorrealismo: el hotel real visto por una camcorder de 1988

Plan en curso para que la imagen se acerque a Lost Fragment, Paranormal Tales, Silent Breath o Dreamcore. Aquí se anotan las decisiones, los resultados de cada prueba y los hitos. El rendimiento de cada paso va en [PERFORMANCE.md](PERFORMANCE.md) y los assets en [ASSETS.md](ASSETS.md).

**Dirección:** la escena debajo es fotorrealista y la cámara la graba como una camcorder real (lente, sensor CCD, procesado y cinta), no como un velo encima.

**Fuera de alcance:** supervivientes y criatura (otro plan).

**Rendimiento:** Alto a 60 FPS en una RTX 4060 Ti a 1080p. Bajo rinde como hoy.

**Assets:** CC0, CC-BY con créditos, y Fab/Megascans y Mixamo gratis.

**Orden por impacto:**
1. banco de pruebas;
2. cámara;
3. luz;
4. materiales;
5. ambientación y mobiliario;
6. kit de geometría.

## Punto de partida (antes del plan)

- **Arquitectura:** cajas y cilindros unitarios sin bisel ni UV. Materiales 100 % procedurales; `assets/textures/` está vacío.
- **Mobiliario:** 6 modelos reales y 4 huecos por sala.
- **Ambientación:** sin decals, objetos sueltos ni señales físicas.
- **Luz:** una omni centrada por sala y sin rebote.
- **Cámara:** 78° verticales en rectilíneo, sin exposición, lente, motion blur ni enfoque; el VHS es un velo 2D.

## Banco de pruebas (fase 0)

- `tools/capture/lookdev_capture.gd` toma siete vistas fijas del piso de la semilla 81, a 1920 × 1080:
  - recepción, dormitorio, salón, pasillo, baño, servicio, y sala oscura con linterna;
  - cada una en `_raw` (sin cinta ni OSD) y `_vhs`;
  - resultado en `evidence/lookdev/<etiqueta>_q<preset>/`;
  - `--setup=script.gd` modifica el piso antes de las tomas, para probar una idea sin tocar el juego.
- `tools/capture/lookdev_sheet.gd` compone la hoja: una carpeta en cuadrícula, o varias columnas lado a lado (antes/después, ahora/referencia).
- **Base:** `evidence/lookdev/base_q2` (Alto).
- **Referencias:** tus capturas de los juegos de referencia van en `evidence/reference/`, sin versionar.

## Pruebas de riesgo

### 1. Orden del compositor frente a TAA — resuelta

Prueba: un `CompositorEffect` en `POST_TRANSPARENT` pinta ruido distinto en cada fotograma. Varianza de la zona con ruido:

| Configuración | Varianza |
|---|---|
| Sin AA | 0,0345 |
| TAA | 0,0006 |
| MSAA 2× | 0,0352 |
| FSR2 | 0,0103 |

- **El callback corre antes de la resolución de TAA y FSR2.**
- **El búfer de velocidad existe siempre** con `needs_motion_vectors`, también sin TAA.

Consecuencias para la cámara:
- **En HDR (compositor, antes de TAA):** lo que es estable por píxel. Es decir, exposición, curva de vídeo, balance de blancos, halo, smear de CCD y motion blur.
- **En el lienzo (después de TAA y tonemap):** lo que TAA emborronaría o cuya reproyección rompería. Es decir, distorsión de lente, aberración lateral, viñeteado, ruido del sensor y realce de bordes. Va en una capa propia por debajo del OSD, porque la óptica no deforma el OSD pero la cinta sí lo graba.
- **La ganancia medida en la GPU** podía llegar al ruido del lienzo con `buffer_get_data_async`. Hay también `texture_copy`, `get_velocity_layer`, `get_depth_layer` y las matrices de cámara. (Después se cambió por una textura: la lectura asíncrona tumbaba el juego exportado al salir; ver la fase 1.)

### 3. Sonda por sala como luz ambiente — funciona, rebote débil

Prueba: una `ReflectionProbe` interior por sala iluminada (97 en la semilla 81), del tamaño de la sala, con `ambient_mode = ENVIRONMENT`, una actualización y sombras.

- **Efecto:** levanta las sombras de las salas iluminadas (el interior del armario y la mesa de servicio dejan de ser negros). La sala oscura no cambia.
- **Medida sin cinta:** brillo medio +1 a +1,5 de 255 y 1–3 puntos menos de píxeles negros. Subir `intensity` a 3 casi no cambia la luz ambiente, sobre todo el reflejo.
- **Sin fugas:** con puerta cerrada, la sala oscura contigua da en los cuatro presets lo mismo que sin sondas, 0,6–0,8 de 255.
- **Conclusión:** es un rebote plausible y confinado a la sala, pero débil. **Superada por la prueba 8:** el rebote es un `VoxelGI` por sala y las sondas quedan para los reflejos.
- **Aviso:** 97 sondas superan las 64 plazas del atlas de reflejos (`rendering/reflections/reflection_atlas/reflection_count`); en el piso solo se ven las cercanas, pero hay que medirlo.

### 4. Luz de los apliques y perfiles IES — funciona con sombra

Prueba: una `OmniLight3D` por aplique en las salas iluminadas (32 en la semilla 81), con un proyector equirectangular. La mitad trasera (el muro) va en negro y la delantera lleva un cono hacia arriba y otro hacia abajo.

| Variante | Resultado |
|---|---|
| Sin proyector y sin sombra | Lava la pared de luz y el pasillo gana muchísimo, pero atraviesa el muro hacia la sala vecina |
| Proyector sin sombra | No ilumina nada: **un proyector de omni necesita `shadow_enabled`** |
| Proyector con sombra | Conos arriba y abajo en la pared y sombra del propio brazo del aplique, como un perfil IES real. La sombra impide además la fuga |
| Foco de 89° metido 3 cm en el muro | Apenas ilumina (la pared queda en rasante) |

- **En el proyector, el frente (hacia la sala) es −Z local de la luz.**
- **Adoptado para la fase 2:** proyector con sombra, en Alto y Ultra; en Bajo y Medio el aplique queda emisivo. Los perfiles se generan por código en `lighting.gd`; no hizo falta leer archivos IES.

### 7. Niebla volumétrica iluminada por las lámparas — funciona

Prueba: `volumetric_fog_length` de 14 m (antes 48) y `light_volumetric_fog_energy` 1 en las lámparas de techo.

- **Efecto:** una bruma suave en el aire de las salas iluminadas. Brillo medio +2 a +3 de 255 y un 5–6 % menos de píxeles negros. La sala oscura, igual.
- **Sin fugas:** los cuatro presets dan lo mismo que sin niebla. Con celdas más cortas, el resplandor ya no cruza el muro.
- **La linterna** también ilumina la niebla solo hasta 14 m. Juzgado en la fase 2: a esa distancia su haz ya es débil y el corte no se nota.

## Fase 1 — La camcorder (hecha)

La cámara se rehizo en el orden de una camcorder real. Todo es la cámara, no una calidad: es igual en los cuatro presets, salvo lo que se indica.

1. **Cámara en mano** (`hotel_player.update_handheld`):
   - un muelle rígido y algo subamortiguado se queda atrás en los giros rápidos y se inclina hacia el lado;
   - temblor de mano 1/f, respiración (más honda sin resistencia), cabeceo en cada pisada y sacudida al aterrizar;
   - el temblor se quita y se repone en cada fotograma, así que la mirada nunca lo acumula, y la red envía la mirada limpia (`look_pitch()`);
   - lo escala «Movimiento de cámara», «Efectos reducidos» lo quita, y las pruebas lo apagan salvo con `--handheld`.
2. **Óptica y sensor en el lienzo** (`lens.gdshader`, capa 2, entre la imagen 3D y el OSD):
   - distorsión de barril: se renderiza más ancho y se remapea, y el centro conserva los 78° de siempre (`camcorder_look.gd`, que da el FOV a todas las cámaras que filma: jugador, observación, entrada y portada);
   - aberración cromática lateral y viñeteado cos⁴;
   - ruido del sensor (fotónico con √señal y de lectura), que crece con la ganancia, con ruido de croma en la oscuridad;
   - realce de bordes de vídeo.
   Va después de TAA y por debajo del OSD. «Grano» y «Aberración cromática» pasan aquí; la vista de la criatura no tiene lente.
3. **Etapa HDR** (`camera/camcorder_effect.gd`, compositor, antes de TAA):
   - medidor centrado e iris automático con ganancia: abre despacio, cierra más rápido y tiene un tope de +0,8 pasos, así que una sala sin luz sigue negra;
   - smear vertical de CCD en las luces saturadas (desde Medio);
   - curva de vídeo con knee y pie de negros, que sustituye a AgX;
   - la ganancia llega a la lente sin pasar por el procesador: el iris la escribe en una textura de 1 × 1 que el shader de la lente lee.
4. **Motion blur** (`camera/motion_blur_effect.gd`, desde Medio): la estela de un giro durante un obturador de 1/60 s. Se calcula con la rotación entre fotogramas, porque el búfer de velocidad de Godot no lleva el movimiento de la cámara. Girando a 3 rad/s, la nitidez horizontal baja un 27 %.
5. **Autoenfoque** (Alto y Ultra): sigue el centro con retraso y «caza» tras un cambio grande. Solo desenfoca cuando hay algo cerca.
6. **Halo y reflejos fantasma** (desde Medio, añadidos después de la fase 2; preset `glare`), en la etapa HDR:
   - la luz por encima de un umbral se toma a un cuarto de resolución y se difumina;
   - vuelve como un halo cálido alrededor de cada lámpara, el velo de un cristal viejo;
   - y como tres reflejos fantasma tenues de color, reflejados a través del centro, como los que dejan las lentes de una camcorder barata;
   - una pasada mide el destello medio del cuadro y ambos bajan cuanto más luz fuerte hay: a la mitad en un pasillo lleno de apliques, al 86 % en un dormitorio con un solo plafón;
   - solo las luces grandes dejan reflejos, porque el destello difuminado de una bombilla pequeña queda por debajo de un umbral.
   Cuesta unos 0,07 ms en Medio y en Alto. Se suavizó tras probarlo en partida: con muchas fuentes de luz molestaba.
7. **Entrelazado** (lente, todos los presets): de las 480 líneas de un fotograma, una de cada dos es el campo grabado 1/60 s antes, desplazado lo que giró la cámara en ese tiempo (`hotel_main.update_fields`).
   - Solo peina en giros rápidos: nada por debajo de unos 12 píxeles de desplazamiento (a 1 rad/s no aparece), todo a partir de 30 y nunca más de 48.
   - «Efectos reducidos» lo quita.
8. **Cortes de señal de la cinta** (`analog.gdshader`), rehechos: destellos blancos de una línea de campo, a veces dos, que duran un fotograma, más brillantes al empezar y con la cola deshilachada. En un tercio de los casos el aparato los tapa repitiendo la línea de arriba. Su frecuencia sigue a «Cinta VHS»: unos 4 por segundo con el valor por defecto, ninguno a cero.

**El encuadre sigue en 16:9:** el 4:3 opcional del plan se descartó.

**Calibración del iris** (`key` 0,065, sin cinta):

| Sala | Iris |
|---|---|
| Cálida | +0,4 a +0,5 EV |
| Fluorescente | −0,3 EV |
| Recepción | +0,8 EV |
| Sala oscura con linterna | +0,6 EV (tope) |

Brillo medio frente a antes: salas cálidas 34–37 de 255 (antes 21–29), fluorescentes 42–44 (antes 46–49), sala oscura igual.

**Coste** en la RTX 4060 Ti, 1080p, GPU caminando: +0,12 ms en Bajo, +0,31 en Medio, +0,79 en Alto y +1,04 en Ultra. Alto queda en 5,7 ms.

**Dos fallos resueltos por el camino:**
- La copia del color para el blur se hace con una pasada de cómputo: el búfer de Godot no admite `texture_copy`.
- **El juego se caía al salir** por dos motivos. Los efectos liberaban sus recursos cuando el dispositivo ya no existía: ahora el nivel los libera en `_exit_tree`. Y una lectura asíncrona de la ganancia seguía pendiente al salir:
  - primero se desvió a campos estáticos, lo que bastó con el binario del editor;
  - el juego exportado se seguía cayendo al salir en Forward+, cuando la lectura llegaba con los scripts ya descargados (encontrado en la fase 2);
  - ahora no hay lectura: la ganancia viaja por una textura en la GPU (`exposure_texture`).
  - **Comprobado con el `.exe` exportado:** sale con código 0 desde el menú y desde una partida, también en Compatibility.

**Hito:**
- vídeo `evidence/lookdev/fase1_alto.avi` (20 s de recorrido en Alto, grabado con `tools/capture/walkthrough_movie.gd` y Movie Maker);
- hoja `evidence/lookdev/fase1_antes_despues.png`.

## Fase 2 — Luz como en un hotel real (hecha)

La luz se describe como la de aparatos reales (`game/world/hotel/lighting.gd`). La jugabilidad no cambia: las mismas lámparas, con sombra, las salas oscuras sin luz y la linterna igual.

1. **Color por temperatura:**
   - incandescente a 2.700 K, apliques a 2.600 K, fluorescente viejo a 4.100 K con un tinte verde;
   - la cámara tiene un balance fijo de tungsteno (3.200 K), así que lo incandescente sale algo cálido y el fluorescente frío y verdoso, como en una cinta grabada en interiores;
   - el balance se aplica a cada luz y no a la imagen entera: la linterna, los cristales que brillan y los colores pintados conservan su aspecto.
2. **Forma de la luz:** perfiles fotométricos, como los de un archivo IES, generados por código y puestos como proyector en cada lámpara:
   - **plafón de cristal esmerilado:** un charco ancho hacia abajo, bastante luz hacia las paredes y un resplandor en el techo alrededor;
   - **regleta fluorescente:** reparto en «alas de murciélago», más fuerte a unos 40° a los lados del tubo, y algo de luz al techo;
   - **aplique de pantalla de tela:** un cono hacia arriba, otro hacia abajo, un brillo tenue a través de la tela y nada hacia atrás.
   Los perfiles restan luz fuera de su dirección principal; un 25 % más de energía mantiene el brillo de cada sala. Un proyector solo funciona con sombra: si los ajustes quitan las sombras, el perfil se retira con ellas.
3. **Apliques que iluminan** (Alto y Ultra): una luz con sombra por aplique en las salas iluminadas, apagada a partir de 24 m. En Bajo y Medio la pantalla solo brilla.
4. **Rebote de luz** (Alto y Ultra, `bounce_light.gd`): un `VoxelGI` por sala iluminada. La luz que cae en la moqueta, las paredes y el techo ilumina el resto de la sala con su color. Detalles en la prueba 8.
   - **Salas grandes:** las celdas unidas en un espacio abierto llevan un solo volumen sobre toda la sala, horneado con la geometría de todas sus celdas; con más de 20 m de lado, a subdivisión 128.
   - **Por qué:** con un volumen por celda, cada una se horneaba sin ver lo que había pasado su borde, y el rebote de dos celdas vecinas salía distinto. Godot da a cada superficie como mucho dos volúmenes y los normaliza, así que el cambio era brusco. El techo mostraba una línea recta en diagonal, con zonas de tono distinto centradas en cada lámpara (visto jugando, reproducido en la semilla 7).
   - **Salas en L** (unas 3 de cada 10 salas grandes): sin rebote, porque la caja que las envuelve tomaría la sala de su esquina.
   - El volumen termina en las paredes de su sala: el rebote no llega a la contigua, y una sala oscura no tiene.
   - Las lámparas se inyectan en vivo, así que un tubo que falla o una lámpara que se apaga se llevan su rebote.
   - Alto lo dibuja a media resolución (`bounce_half`), sin diferencia visible; Ultra, a resolución completa.
5. **Reflejos:** una sonda por sala iluminada en Alto y Ultra, renderizada con sombras, y una de cada tres salas de pasillo en Medio. Solo se crea con la lámpara de su sala encendida, para que la única captura que hace no se quede a oscuras. Su luz ambiente solo se usa si se quita el rebote.
   - **Solo existen las cercanas:** se crean las 24 más próximas y una ya creada se conserva mientras esté entre las 32 más próximas; las demás se destruyen.
   - **Por qué:** Godot reserva a cada sonda un hueco de su atlas de reflejos (64) la primera vez que la dibuja, y no lo devuelve hasta destruirla, aunque se oculte. Con una sonda en cada sala iluminada, al explorar un piso grande se llenaba el atlas:
     - las sondas nuevas no tenían dónde dibujarse;
     - poco después el juego se cerraba.
     Las zonas de tono distinto que se veían entonces en los techos eran otra cosa: las costuras entre volúmenes de rebote (punto 4).
     Encontrado jugando; reproducido recorriendo las 104 salas iluminadas de la semilla 7 en Ultra, que se caía siempre y ahora no, con un máximo de 30 sondas vivas.
6. **Niebla iluminada** (desde Medio): las lámparas iluminan la niebla volumétrica, que entonces llega a 14 m en vez de 48. La linterna también la ilumina hasta esa distancia; a 14 m su haz ya es débil y el corte no se nota.

**Resultado** (Alto, sin cinta, brillo medio / porcentaje de píxeles negros):

| Vista | Fase 1 | Luz (paso 1) | Con rebote |
|---|---|---|---|
| Recepción | 23,2 / 8 % | 28,1 / 5 % | 36,7 / 3 % |
| Dormitorio | 37,2 / 13 % | 36,1 / 9 % | 40,7 / 9 % |
| Salón | 33,6 / 11 % | 34,5 / 4 % | 40,5 / 4 % |
| Pasillo | 36,7 / 8 % | 40,0 / 3 % | 42,9 / 3 % |
| Baño | 44,4 / 15 % | 43,9 / 22 % | 45,8 / 13 % |
| Servicio | 42,1 / 16 % | 42,3 / 24 % | 45,1 / 13 % |
| Sala oscura | 3,1 / 91 % | 3,3 / 91 % | 3,2 / 91 % |

- Los apliques lavan la pared en festones y el pasillo gana profundidad.
- La luz de los fluorescentes toma el tono frío y verdoso. La regleta tapa el techo, que sin rebote quedaba negro; con él recibe la luz que devuelve el suelo.
- Con el rebote, techos y paredes reciben un relleno cálido del color de la sala, y las sombras dejan de ser negras.
- La sala oscura queda igual.
- La mancha de humedad del techo del salón se ve más, porque ahora el techo está iluminado.

**Sin fugas:** con la puerta cerrada, la sala oscura contigua a una iluminada da lo mismo con la luz nueva que sin apliques, sondas, niebla iluminada ni rebote, en los cuatro presets (8,9–9,0 de 255 con el ruido del sensor, sin lente ni OSD).

**Coste** (RTX 4060 Ti, 1080p, GPU caminando, frente a la fase 1):

| Preset | GPU | p99 del fotograma |
|---|---|---|
| Bajo | 0,86 → 0,90 ms | 3,5 → 3,4 ms |
| Medio | 2,66 → 2,79 ms | 4,9 → 5,1 ms |
| Alto | 5,71 → 6,90 ms | 8,3 → 11,6 ms |
| Ultra | 7,91 → 10,86 ms | 11,2 → 18,8 ms |

- **Apliques:** la mayor parte. Su sombra se redibuja al pasar junto a ellos.
- **Rebote:** +0,5 ms en Alto (media resolución) y +1,5 ms en Ultra.
- Alto sigue por debajo de los 16,7 ms de 60 FPS también en el p99. Ultra baja de 60 FPS en algunos fotogramas.
- **Carga del piso:** +0,9 s en Alto y Ultra (1,4–1,6 s frente a 0,6 s en Medio), por el horneado del rebote.

### 8. VoxelGI por sala frente a las sondas

Prueba: un `VoxelGI` de subdivisión 64 por sala de las vistas, horneado en la carga con su geometría real, con las lámparas inyectadas en cada fotograma y sin la luz ambiente de las sondas. Se compara con la sonda y con ningún rebote (`evidence/lookdev/rebote_sondas_voxelgi.png`).

| Vista | Sin rebote | Sonda | VoxelGI |
|---|---|---|---|
| Recepción | 28,0 / 6 % | 28,1 / 5 % | 31,4 / 3 % |
| Dormitorio | 35,6 / 10 % | 36,1 / 9 % | 45,1 / 1 % |
| Salón | 34,4 / 4 % | 34,5 / 4 % | 45,7 / 0 % |
| Pasillo | 39,9 / 3 % | 40,0 / 3 % | 42,7 / 0 % |
| Baño | 43,7 / 22 % | 43,9 / 22 % | 46,7 / 10 % |
| Servicio | 42,3 / 24 % | 42,3 / 24 % | 46,2 / 12 % |

- **La sonda apenas rebota:** su luz ambiente es la media de una captura oscura.
- **VoxelGI da el rebote de verdad:** el interior del armario, las esquinas y las paredes bajo el fluorescente reciben luz de la sala. Es el cambio que más acerca la imagen a una foto.
- **Pero así no sirve tal cual:**
  - El horneado lee el color solo de los materiales estándar. Los del hotel son shaders propios, así que los ve blancos y el rebote sale sin color y demasiado fuerte.
  - Hornear la geometría real cuesta 220–860 ms por sala, y el piso tiene unas 97 iluminadas.
  - Godot solo muestra 8 volúmenes a la vez.

**Cómo quedó** (`game/world/hotel/bounce_light.gd`):
- **Doble de la sala.** El horneado recibe un doble de cada sala: sus mismas cajas agrupadas, una superficie por material en el color medio de ese material. `tools/lighting/measure_albedo.gd` mide esos colores dibujando cada material bajo luz ambiente blanca y los escribe en `material_albedo.gd`; hay que volver a ejecutarlo si cambia un material. Las lámparas, los tubos y las pantallas quedan fuera del doble, porque sus vóxeles ahogarían su propia luz.
- **Coste por sala.** El horneado relee de la GPU cada instancia de malla, a 1,5–2 ms por caja. Con una malla por sala baja de 60–180 ms a unos 55 ms, que es el trazado de vóxeles en sí. Aun así son 5,4 s por piso.
- **En hilos.** Las salas se hornean en hilos de trabajo, desprendidas del árbol de escena: un nodo del árbol no se puede tocar fuera del hilo principal. Con la mitad de los núcleos, un piso tarda unos 1,3 s y el juego sigue dibujando mientras tanto.
  - **Sin bloqueos.** El doble es una malla que vive solo en memoria (`stand_in_mesh.gd`) y responde al horneador sin pedir nada al servidor de render. Si se lo pidiera, un hilo esperaría al hilo principal, y el hilo principal esperando al horneado (al cambiar de piso a medias) se bloquearía.
  - **Errores silenciados.** Desprendido del árbol, el horneador lee cada transformación global como la identidad y se queja de cada una. Por eso el doble se da ya en el marco del volumen, y los mensajes de error se apagan mientras dura el horneado.
- **Presentación.** La carga del piso espera al horneado (`hotel_main.bounce_ready()`), así que el rebote no aparece de golpe. Solo se muestran los 8 volúmenes más cercanos, que es el máximo que dibuja Godot.
- **Resultado.** El rebote de color es menor que el de la prueba blanca pero de la misma forma (tabla de la fase 2): la hoja `evidence/lookdev/rebote_antes_despues.png` compara la luz del paso 1 con el rebote.
- **Descartado:**
  - **Compartir el horneado entre salas iguales:** con cada lado distinguido entre pared, puerta o abierto, casi todas las salas son únicas (102 claves en 121 salas).
  - **La luz ambiente de las sondas:** no rebota.

**Hito:**
- hojas `evidence/lookdev/fase2_antes_despues.png` (sin cinta) y `fase2_antes_despues_vhs.png` (como se juega), que comparan la fase 1 con la fase 2 completa;
- vídeo `evidence/lookdev/fase2_alto.avi` (20 s de recorrido en Alto).

## Fase 3 — Materiales escaneados (hecha)

Doce materiales escaneados CC0 de Poly Haven y ambientCG, registrados en [ASSETS.md](ASSETS.md). La identidad del hotel se conserva: los medallones de la moqueta y el motivo del papel siguen siendo procedurales y se imprimen sobre la materia real. En el resto de materiales, el escaneo manda y se tiñe a la paleta de antes.

**1. Ingesta.** `tools/textures/ingest_pbr.py` lee las descargas de `source_assets/textures/` (fuera de git) y escribe en `assets/textures/<set>/`:
- color, normal (convención OpenGL) y ORM (oclusión, rugosidad y metal en R, G y B);
- cada mapa a 2048 px y a 1024 px (`_1k`);
- un `.import` junto a cada imagen: comprimida en VRAM (BC1, y las normales en BC5) y con mipmaps;
- la tabla de créditos, entre las marcas `SCANS` de `ASSETS.md`.

Ocupan 63 MB en el repositorio.

**2. Carga.** Cada material dice su set en el metadato `scan` de su `.tres`, y `hotel_geometry.apply_scan()` le da los mapas. Se cargan una vez y los comparten todos los constructores (piso, intro y portada). En Bajo (preset `small_maps`) se usan los de 1024 px; al cambiar de preset se sueltan los del otro tamaño, para no tener nunca los dos en memoria de vídeo.

**3. Cómo se combina el escaneo** (`image_maps.gdshaderinc`, uniforme `map_mode`):
- **Recolour.** El tinte del material, aclarado y oscurecido como el escaneo, que conserva la veta, el pelo y las manchas. Va por luminancia: al dividir por canal, la colcha (un escaneo rojo saturado, con un verde medio de 0,01) salía carmesí.
- **Detail.** El color procedural, variado por el escaneo. Se usa en la moqueta, el papel pintado y el techo.
- **Replace.** El escaneo tal cual, por el tinte.

La rugosidad y la oclusión salen del ORM, con un ajuste por material (`map_roughness`). Sin él, la moqueta brillaba bajo la lámpara (el escaneo tiene 0,65 de rugosidad), y el latón a su color real saturaba la cámara y dibujaba una columna de smear.

**4. Proyección:**
- **Madera:** la veta sigue el lado largo de cada cara de cada caja (tablón, pata o marco), en metros. Cada pieza toma el escaneo desde otro punto, para que dos baldas iguales no sean idénticas.
- **Papel, yeso y techo:** siguen con `face_uv`.
- **Antirrepetición** (`map_no_tile`): cada repetición se desplaza con un ruido, con dos lecturas mezcladas y las derivadas tomadas antes del desplazamiento, para que las costuras no bajen de mip. Solo en escaneos de aspecto aleatorio (estuco, pelo, papel liso) y solo donde el preset trabaja el detalle fino (`surface_detail` ≥ 2,5; en Bajo, no). Nunca en azulejo ni en tablas.

**5. Tejido e impresión.**
- **Moqueta:** el pelo del escaneo desplaza los bordes de los medallones unos centímetros (`fibre_bleed`), así que el dibujo parece tejido y no pintado.
- **Papel pintado:** el motivo se corre con la fibra del papel (`ink_bleed`).

**6. Suciedad por sala** (`surface.gdshaderinc`, `room_grime()`), sin decals:
- **Dónde:** donde se juntan dos de las superficies de la sala (paredes, suelo y techo), con un oscurecimiento que también quita luz indirecta (AO).
- **Qué:**
  - polvo y agua de fregar a lo largo del zócalo;
  - humedad y humo amarillentos bajo el techo.
- **Datos de la sala:** cada caja lleva su sala en los datos propios de su instancia del MultiMesh: medio ancho, medio fondo, altura y lados abiertos.
  - Los lados abiertos de un salón que sigue en la celda de al lado no acumulan nada.
  - Primero se probó con `instance uniform`, pero cada lote de cada sala ocupaba sitio en un búfer global. En Compatibility (4.096 elementos) se desbordaba con unos 2.000 lotes.

**7. Materiales nuevos:**
- falso techo de placas en lavandería, almacén, mantenimiento y oficina (`ceiling_service`);
- papel deteriorado en salones vacíos y almacenes (`plaster_decrepit`);
- colcha de jacquard (`bedspread`).

El resto de los sets van a `plaster`, `carpet`, `ceiling`, `wood`, `door`, `panel`, `trim`, `tile`, `gold`, `fabric` y `leather`.

**8. Colores del rebote.** `tools/lighting/measure_albedo.gd` se volvió a ejecutar y los colores medios apenas cambian (el tinte es el color de antes).

**9. Shaders precompilados.** Hay dos niveles:
- **Ya lo hace Godot:** desde la 4.4 compila las variantes (pipelines) al instanciar cada malla, así que la pantalla de carga del piso las absorbe.
- **Nuevo, el bakeador de shaders** (`shader_baker/enabled` en `export_presets.cfg`): mete en el ejecutable el código ya compilado de cada shader, para que el primer arranque en otro equipo no los compile.
  - Solo funciona si la exportación tiene GPU: con `--headless` se lo salta sin avisar.
  - Por eso `tools/godot.ps1 export` exporta con ventana (oculta).

**Coste** (`run_bench.ps1`, recorrido, GPU media; antes, las etiquetas `bounce` y `hotfix`):

| Preset | GPU media antes | GPU media ahora | p99 del fotograma antes | p99 ahora |
|---|---|---|---|---|
| Bajo | 0,92 ms | 1,00 ms | 4,07 ms | 3,44 ms |
| Medio | 2,96 ms | 3,24 ms | 8,12 ms | 5,24 ms |
| Alto | 6,77 ms | 7,40 ms | 10,67 ms | 10,97 ms |
| Ultra | 10,53 ms | 11,18 ms | 17,0 ms | 17,9 ms |

- **Alto:** sigue muy por debajo de los 16,7 ms.
- **Ultra:** ya estaba en el límite en los fotogramas más lentos y queda para el cierre.
- **Memoria de vídeo:** los mapas comprimidos son unos 130 MB. Al medirla apareció una fuga de la fase 2, arreglada aquí:
  - los 51 volúmenes de rebote de un piso guardaban sus texturas en la GPU aunque solo se dibujaran los 8 más cercanos, unos 56 MB cada uno, 2,9 GB en total;
  - ahora un volumen solo recibe sus datos mientras se muestra (`bounce_light.show_near()`);
  - Alto pasa de 4,30 a 1,94 GB y Ultra de 4,45 a 2,09 GB, ya dentro del presupuesto de 3 GB;
  - el p99 del recorrido no cambia (Alto 10,8 ms, Ultra 17,3 ms) y la imagen tampoco: menos de medio nivel de diferencia media en las tomas de look-dev.

**Hito:**
- hojas `evidence/lookdev/fase3_antes_despues.png` (sin cinta) y `fase3_antes_despues_vhs.png` (como se juega);
- `fase3_primeros_planos.png`: cama con linterna, cornisa, zócalo y azulejo. Son las tomas cercanas nuevas de `lookdev_capture.gd`: `cama`, `cornisa`, `zocalo` y `azulejo`.

## Fase 4 — Ambientación y mobiliario real (hecha, salvo lo de Sketchfab)

Muebles y objetos de Poly Haven, decals de ambientCG y cuadros del Art Institute of Chicago, todo CC0 y registrado en [ASSETS.md](ASSETS.md). Pendientes los nueve modelos CC-BY de Sketchfab (teléfono, sanitarios, lavadoras, carro de limpieza, timbre, cenicero y toallas), que requieren cuenta: sus huecos siguen como estaban.

**1. Catálogo** (46 descargas, 52 modelos: las que traen varios objetos, como la papelera, las maletas y las botellas, se separan):
- `tools/props/ingest_models.py` copia las texturas (1024 px, 2048 en los muebles grandes) y escribe un material por material del glTF;
- `tools/props/build_catalogue.gd` hornea cada glTF, leído con `GLTFDocument` desde `source_assets/` (que Godot no importa), en una malla por modelo en `assets/props/hotel/<id>.res`: una superficie por material, suelo en y = 0, frente hacia +Z, a tamaño real y con LOD automáticos;
- `tools/props/catalogue_sheet.gd` dibuja la hoja `evidence/catalogue_sheet.png`, para comprobar frentes y tamaños.

Arreglos del camino:
- las estanterías metálicas venían en centímetros;
- en glTF, `BLEND` es transparencia alfa y no el prepaso de profundidad (el cristal de los relojes salía negro);
- los flecos y agujeros con `BLEND` pasan a recorte, para que sigan proyectando sombra.

**2. Huecos de siempre** (`prop_factory.gd`), con sus colisionadores intactos:
- cama tallada con mesilla y despertador;
- mesillas a 0,84 m, la altura a la que `document_placement.gd` deja los documentos (su colisionador se ajusta al mueble);
- sillas reales en mesas y escritorios, con papeles y lápices fuera del centro, donde puede caer un documento;
- tres sofás que se alternan;
- estanterías rellenas: metálicas con cajas y botes en las salas de servicio, librerías con enciclopedias en el resto;
- caja registradora en recepción, maletas, papeleras metálicas y carro metálico en servicio.

**3. Paredes** (`room_dressing.gd`). Cada pared cerrada tiene dos tramos libres: desde pasado el vano (la hoja nunca barre más allá de su bisagra) hasta antes del hueco de la esquina o del tabique de la alcoba, y nunca donde hay un armario-escondite.
- Cada tipo de sala tiene su juego de piezas: cómoda con espejo, consola, butaca con velador, sillas, maletas, planta, librería, estanterías, cajas, papeleras, cestos...
- Encima o dentro van jarrones, relojes, libros, cajas y botes, colocados en las alturas reales de cada modelo: `shelves()` busca sus caras planas hacia arriba.
- Las piezas grandes llevan colisionador de caja; lo de menos de unos 30 cm, no.
- **Validación física: 0 errores en 8 semillas**, sin caer al piso de reserva.

**4. Estado de cada sala** (por posición):
- cuidada (50 %), descuidada (35 %) o abandonada (15 %); el salón vacío nunca está cuidado;
- en los tramos vacíos, lo descuidado deja botellas, papeles, cajas y colillas, y lo abandonado además alguna silla volcada.

**5. Densidad:** mediana de 35–43 objetos por sala (entre 7 y 151; lo alto son las estanterías llenas).

**6. Cuadros:** 14 obras de dominio público en `assets/paintings/`.
- En el marco tallado de Poly Haven, sin su lienzo, o en uno de madera lisa.
- Los retratos cuelgan en vertical, con el marco girado en lugar de estirado, y se recortan conservando la parte de arriba.
- Qué cuadro va en cada sitio sale de la posición.

**7. Decals** (prueba 5), 13 de ambientCG preparados por `tools/textures/ingest_dressing.py`: 512 px, alfa desde su opacidad (las pisadas desde el relieve y la mancha desde la rugosidad) y bordes difuminados.
- **Dónde:** humedad bajo el techo y desde el suelo, huellas junto a los vanos, manchas, chicles en zonas públicas y pisadas en salas abandonadas.
- **Cuántos por sala:** 4, 9 o 16 según el estado. Se crean todos al construir, y el preset muestra una parte (`decals`: ninguno en Bajo, la mitad en Medio, todos en Alto y Ultra). Compatibility no tiene decals.
- **Cómo:** solo se pintan en superficies que miran al decal (`normal_fade`) y se desvanecen a 14 m. Con eso y las salas ocultas nunca hay más de unas decenas en el clúster, lejos del límite de 512.
- **Tintes:** las pisadas en arena pasan a ser barro y la mano blanca, mugre; la mancha se suaviza y queda para baños y servicio.

**8. Letrero de salida y placas:**
- en el refugio, dos letreros de salida verdes iluminados colgados del techo sustituyen al texto flotante;
- los números de puerta van en placas de latón, en letra oscura.

**9. Sombras.** Lo que mide menos de 60 cm, y todo lo que está encima de otro mueble, no proyecta sombra; lo de menos de 30 cm deja de dibujarse a 16 m.
- **Descartado:** una copia simplificada por modelo para la sombra. Tuvo el efecto contrario (1,9 M de primitivas de sombra frente a 0,98 M), porque en las sombras Godot ya usa los LOD de la malla, y la copia no los tenía.

**Coste** (recorrido, GPU media; antes, `scans2`):

| Preset | GPU media antes | GPU media ahora | p99 del fotograma ahora | Memoria de vídeo |
|---|---|---|---|---|
| Bajo | 1,00 ms | 1,25 ms | 4,9 ms | 1,46 GB |
| Medio | 3,24 ms | 3,78 ms | 6,6 ms | 1,53 GB |
| Alto | 7,40 ms | 8,11 ms | 12,9 ms | 2,21 GB |
| Ultra | 11,21 ms | 11,92 ms | 19,8 ms | 2,37 GB |

- **Alto:** sigue dentro de los 16,7 ms.
- **Ultra:** su p99 empeora (17,3 → 19,8 ms). La GPU del p99 sube menos (15,6 → 16,2 ms), así que el resto son picos de CPU al entrar en salas nuevas; queda para el cierre.
- **Primitivas visibles:** unas 150 000, cuatro veces las de antes.

**Hito:**
- hojas `evidence/lookdev/fase4_antes_despues.png` y `_vhs.png`;
- `fase4_primeros_planos.png`;
- catálogo `evidence/catalogue_sheet.png`.

## Ajustes tras probar el piso (después de la fase 4)

**1. Zoom óptico** (fase 1, la camcorder). La cámara tiene el zoom de 6 aumentos de una camcorder doméstica:
- se mueve con la rueda del ratón, adelante hacia T y atrás hacia W; cada muesca lo empuja un 42 %, así que un golpe de rueda lo lleva de un extremo al otro;
- el motor recorre todo su viaje en algo más de un segundo y avanza parejo en pasos de lente, no de ángulo;
- a más zoom, el barril de la lente se endereza (`camcorder_look.barrel_for()`), como en un teleobjetivo real, y la vista gira más despacio con el mismo movimiento de ratón, así que sigue siendo manejable;
- el temblor de la mano no cambia, pero a 6 aumentos se ve seis veces mayor, como en una cinta de verdad;
- el OSD muestra la barra `W ├───■───┤ T` en su marco, centrada en la parte de arriba del cuadro, mientras el zoom se mueve, y se desvanece 1,6 s después;
- cada piso empieza con la lente abierta, y la criatura no tiene zoom.

**2. Smear de CCD: que lo pinte la luz, no el brillo de un punto.** La raya vertical se repartía poco y no tenía tope, así que un fluorescente de frente pintaba una barra blanca sólida. En una primera pasada se repartió sobre nueve columnas, se le puso tope y le subió el umbral. Seguía mal, y la sonda dijo por qué: **la raya la pintaban los destellos, no las lámparas**. Cada píxel sumaba a su columna todo lo que pasara del umbral, y un reflejo especular (la esfera de un reloj, un pomo de latón) en luz lineal vale cientos de veces lo que una lámpara. Medido en la semilla 81, con la columna ya normalizada:

| Toma | Antes | Ahora |
|---|---|---|
| Dormitorio (destello de un objeto) | 70,4 → velo al tope (0,160) | 0,002 → 0,0005 |
| Salón (el plafón del techo) | 2,58 → 0,074 | 0,128 → 0,031 |
| Pasillo (seis apliques) | 1,51 → 0,049 | 0,033 → 0,009 |

Tres cambios en `camcorder_effect.gd`:
- **Tope por píxel** (`smear_clip`, 12 sobre el umbral): lo que cuenta es cuánta parte de la columna está quemada, no lo fiero que sea su píxel más brillante. Un destello de un píxel deja de mandar.
- **Paso `spread`:** la columna de carga se difumina a lo ancho con una gaussiana de σ = 0,8 % del ancho (unos 15 px a 1920), así que queda una banda suave y no una línea. De paso pone en su sitio a lo estrecho: un destello de un píxel sale unas treinta veces más flojo de un difuminado así, mientras que una lámpara conserva su ancho.
- **Más translúcido y menos cuando hay muchas luces:** `SMEAR_CAP` baja de 0,28 a 0,16 y el velo se divide por el brillo medio del cuadro, como ya hacían el halo y los fantasmas.

Con eso, en el pasillo de seis apliques casi no hay raya, y la que queda es la del plafón que se mira de frente.

**Coste** (recorrido, medido después de estos ajustes): Alto 8,02 ms de GPU media y 12,3 ms de p99; Ultra 12,06 ms y 19,9 ms; memoria de vídeo 2,17 GB en Alto. El paso nuevo es una pasada de 1920 hilos, y a cambio el grado lee una columna en vez de nueve, así que sale a cuenta.

**3. Placas de puerta.** El número no cabía en la placa: la placa pasa de 0,26 × 0,13 m a 0,34 × 0,19 m y el número baja de 24 a 20, con 4,5 cm de margen a los lados.

**4. Luz de los apliques a través de las paredes (bug).** Reproducido con una sonda: desde una sala, la pared contigua se aclaraba con la forma de los apliques del otro lado. Tres causas, todas en el rebote:
- **Las caras exteriores del doble.** Cada sala hornea su volumen con un doble de sus cajas; la media pared del borde llevaba también la cara que mira a la sala vecina. Esos vóxeles del borde se encendían con las lámparas de enfrente (el horneador ilumina un vóxel desde cualquier lado) y daban su luz a esta sala: un almacén de luz fría junto a un baño salía un 12 % más claro y amarillento. Ahora el doble pierde las caras que miran fuera del volumen (`bounce_light.outer_faces_removed()`); no se dibuja nunca, así que no se nota en nada más.
- **Los vanos.** En el doble, cada vano se tapa con una losa del tamaño de la hoja, así que por el hueco ya no entra la luz de la sala de al lado.
- **Puertas y marcos.** Una hoja está metida en los volúmenes de las dos salas y Godot la iluminaba con los dos, así que la cara de este lado brillaba con las lámparas de la otra. Las puertas y sus marcos ya no reciben luz rebotada.
- **Medida:** apagar el rebote de las lámparas de la sala vecina ya no cambia lo que se ve (antes hasta un 12 %). Queda una diferencia del 1,6 % junto a un vano, sin forma reconocible.
- **Descartado:** la máscara de culling de las luces (`light_cull_mask`) no sirve, porque VoxelGI inyecta la luz igual.

### Pruebas que se hacen al empezar su fase

- **6. Bisel en shader:** fase 5.
