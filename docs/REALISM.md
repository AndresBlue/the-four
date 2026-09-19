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
   - El volumen termina en las paredes de su sala: el rebote no llega a la contigua, y una sala oscura no tiene.
   - Las lámparas se inyectan en vivo, así que un tubo que falla o una lámpara que se apaga se llevan su rebote.
   - Alto lo dibuja a media resolución (`bounce_half`), sin diferencia visible; Ultra, a resolución completa.
5. **Reflejos:** una sonda por sala iluminada en Alto y Ultra, renderizada con sombras, y una de cada tres salas de pasillo en Medio. Solo se muestra con la lámpara de su sala encendida, para que la única captura que hace no se quede a oscuras. Su luz ambiente solo se usa si se quita el rebote.
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

### Pruebas que se hacen al empezar su fase

- **5. Decals** (límite de elementos agrupados, atlas): fase 4.
- **6. Bisel en shader:** fase 5.
