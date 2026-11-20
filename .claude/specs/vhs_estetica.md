# La estética VHS de la cámara y del PLAY inicial

Encargo del autor, 19 de noviembre de 2026. **Construido ese mismo día (apartado «Estado»); el autor no lo ha visto moverse.** Sus catorce referencias están en `evidence/referencias/vhs/` (fotogramas de vídeos de la época, solo para mirar: no entran en el juego ni en git).

## Estado (19 de noviembre de 2026)

Los siete puntos están en el juego. Cómo funciona cada uno está en `docs/DEVELOPMENT.md` («Iluminación y posprocesado» y «HUD, menús y ajustes»).

- **Decidido por el autor:** 4:3 solo en el PLAY inicial; el juego y los menús siguen a 16:9 con franjas estrechas.
- **Segunda vuelta, tras verlo el autor esa misma noche.** Sus palabras: «Se ve demasiado digitales los cuadritos de la línea de barrido y el ruido en general. También al abrir la transición, esa ráfaga con bandas, la animación no se parece a los típicos VHS. Hay que hacer que los efectos y el ruido sean menos digitales, que parezcan más análogos»; y «los textos de menús y demás la idea es que tengan la borrosidad que tienen las grabaciones antiguas. Actualmente se ven demasiado definidas». Rehecho: el ruido ya no va en bloques sino suave a lo largo de cada línea, con caídas que se apagan como cometas; los bordes y los cortes de señal no tienen dientes; la entrada es continua (barras de ruido que bajan y se separan, la imagen tirada de lado que se endereza, rebote, y el color que vuelve con un destello); la suavidad se mide por ancho de imagen (antes, en píxeles: a más resolución, más nítido) y los menús llevan un pase propio de suavidad; sobre toda la imagen va un grano de cinta fino (siseo de luma y manchas de color a lo largo de la línea). Para juzgar el movimiento hay dos películas y sus GIF (`evidence/vhs/arranque.avi`, `entrada.avi`, `arranque_tira.gif`, `entrada_tira.gif`; `tools/capture/tape_movie.gd`). Los destellos, medidos con `film_check.py`, quedan dentro del límite (0 y 1 por segundo, con el máximo en 3); para eso la entrada no fuerza el contraste como en las referencias 09 y 10. 
- **Tercera vuelta, tras ver la segunda.** Sus palabras: «quedaría mejor si sólo PLAY fuera en 4:3, luego cuando está en nieve que ya esté a 16:9 para no tener que estirar la imagen»; «las bandas que rotan creo que están muy lentas y muy fluidas en su giro, quizás si se le hiciera más tosca y mucho más rápida»; «el efecto a la izquierda que se oscurece un poco muy exagerado, quizás menos banda negra y menos larga la oscuridad»; «la parte de PLAY se ve excelente. Es más un ajuste a lo ancho que se ve el texto de la UI de la portada The Four». Hecho: solo el azul del PLAY va en 4:3; la entrada dura 0,55 s y va a tirones; la franja izquierda mide la mitad y su quemado es más corto y más suave; la tipografía de la interfaz es Home Video al 85 % del ancho (el PLAY y el texto de cámara conservan su aspecto). 
- **Cuarta vuelta, tras jugarla.** Sus palabras: «los textos y los menús están demasiado borrosos, me gusta como queda cuando dejo el filtro VHS en 5%. Pero el resto de efectos están bien»; «cuando el juego abre y termina la animación de menú se ve bien, pero como al segundo se pone una borrosidad encima como un filtro»; «no hagas que se pierda esa borrosidad en los textos de la UI de la cámara [...] sólo los textos de esa parte se vean así de borroso, la imagen y menús sin tanto efecto»; y de la banda de tracking: «la línea de barrido tiene una textura con ruido cuadriculado [...] esos cuadritos no debieran verse tan definidos», «esa línea es constante [...] como si fuera una falla que ocurre a ratos, no constante». También pidió devolver el borde izquierdo del PLAY a como estaba (al adelgazarlo para el juego se veía «como si tuviera dos capas»). Hecho: imagen y menús con la suavidad del 5 %, el texto de cámara con la suya aparte, el pase de los menús encendido también en el arranque, la banda estirada a lo largo de las líneas y solo a ratos, y el PLAY con su borde ancho. 
- **Quinta vuelta, la letra.** Con el deslizador al 35 % seguía viendo los menús borrosos («textos pequeños son difíciles de leer») y la letra «demasiado marcado el cuadriculado [...] muy de juego como minecraft y no como un VHS». Se probaron y descartó él mismo dos caminos: cortar las escaleras en diagonales rectas («diagonales muy anticlimáticas») y redondear las esquinas («la idea es hacer un efecto de antialiasing no redondeamiento. Quiero que se vea como la primera "a" de la referencia», una letra de mapa de bits con grises en los bordes). Hecho: el pase de los menús casi no desenfoca, y la tipografía lleva el antialiasing horneado, proporcional al tamaño de la letra (`tools/dev/osd_font.py`). El autor la vio después y la dio por buena en letra pequeña.

- **Sexta vuelta, la entrada, los títulos y los carteles** (19 de noviembre de 2026).
  - **La entrada.** El autor dio veinte fotogramas de una grabación real (uno en blanco, dieciocho en blanco y negro y el primero ya en color; no están en el repositorio: llegaron pegados en la conversación) y pidió entenderla y copiarla: «no parece realmente que la imagen rote, sino que son algunos frames que quedan mal visualizados»; «durante este efecto de rotura por bandas, la imagen está en blanco y negro, para luego recuperar el color»; «en 18 frames de 30 fps se acaba la animación»; «duplicar los frames de cada paso, para hacerlo ver más trabado». Lo que es: pérdida del enganche horizontal. El vídeo mantiene la línea un rato (la imagen derecha, en una tira) y la suelta (el arranque de la línea se desliza una línea entera, la imagen corre de lado y el negro entre líneas cruza inclinado); cada paso tiene menos deslizamientos, y al final queda una sola banda, el negro entre líneas, que se endereza y sale. Sin enganche no hay color. Hecho: `ENTRY_STEPS` en `analog.gdshader`, diecinueve pasos de 1/30 s. Medido con `film_check.py`: 2 destellos por segundo como mucho; para eso la banda cruza una sola vez (en la grabación va y viene) y el contraste baja mientras se desliza.
  - **Los títulos.** «Las letras parecen ser blurry, me gustaría que se vieran un poco más los pixeles, pero con mayor densidad en vez de hacerlo borrosa [...] es como si tomara el texto de la UI y le hiciera zoom». Hecho: una tercera hornada de la tipografía para lo escrito desde 40 px, sobre una rejilla el doble de fina que la de la letra.
  - **Los carteles.** Pidió de vuelta la tarjeta de apertura de etapa y el aviso del objetivo (se habían quitado el 16 de noviembre por indicación suya de ese día), legibles, más cortos y sin cortes; la descripción de las reglas, legible y más rápida; «CERRAR» y los demás avisos del visor, nítidos; «Te sientes mejor...» abajo y al centro; y que nada de la interfaz se pise. Hecho, con dos causas de fondo corregidas: los recuadros de palabras se dibujaban a 1280 × 720 y se estiraban, y el shader que los trae los cubría dos veces.
  - **El autor no ha visto esta sexta vuelta en el juego.**
- **Tipografía:** Home Video (GGBotNet, CC0), en `assets/fonts/home_video/`, para toda la interfaz, el PLAY y el texto de cámara (este, estrechado y engrosado). Por qué esa y no otra, en `docs/ASSETS.md`.
- **Capturas junto a las referencias:** `evidence/vhs/comparacion_1` a `6` (se rehacen con `tools/capture/boot_capture.gd` y `tools/capture/tape_capture.gd`).
- **Elegido por quien lo construyó, sin que el autor lo haya decidido:** el fotograma de color sale de media cada 26 s con el deslizador por defecto y más a menudo con la cordura baja (porque esta ya sube el desgaste de la cinta); la entrada del vídeo dura 1,1 s y sale cada vez que la cámara empieza a filmar; el texto de cámara mide 54 px sobre 720 (las referencias lo llevan algo mayor).
- **Lo que no se parece todavía:** la referencia 13 (el fallo de color con ráfagas blancas en la mitad inferior) no tiene equivalente propio: el fotograma de color solo hace bandas, a veces desde media altura. El grano fino del sensor (`lens.gdshader`, deslizador «Grano») no se tocó: lo rehecho es el ruido de la cinta (la nieve, la banda de tracking y la estática de los menús).
- **Sin hacer:** verlo en movimiento con el autor, el piso 2 con este filtro (solo se capturó el hotel) y una versión con su apartado en `docs/CHANGELOG.md`.

## Lo que pidió, con sus palabras

«Ahora quiero trabajar un poco en la estética VHS. Quiero representar algo similar a esto. [...] Intenta imitar todo, investiga por esa tipografía y ponla en el juego para la UI. [...] Intenta replicar esa estética en general para todo el tema de la cámara y el PLAY inicial.»

## Las referencias y lo que señaló en cada una

| Archivo | Qué es | Lo que dijo el autor |
|---|---|---|
| `01_play_pantalla_azul.png` | Pantalla azul de vídeo con PLAY arriba a la izquierda | «a pesar de ser un cuadrado, tiene unos bordes negros con el azul texturizado en los laterales, le da una estética perfecta, el PLAY en la esquina [...] con esa tipografía antigua» |
| `02_play_sobre_cocina.webp` | El mismo PLAY sobre la imagen | La tipografía |
| `03_fecha_3_31_91.webp` | Fecha de cámara «3.31.91» | La tipografía |
| `04_nieve_bordes_y_banda_inferior.webp` | Nieve con «12:00 AM / 01.01.86» | «el borde lateral aparte de ser difuso, tiene errores y tiene unas aberraciones de coloración, como un quemado a la izquierda. A la derecha tiene como un brillito, y en la parte inferior se mantiene ese artifact de desplazamiento de una línea de píxeles. Nuevamente la tipografía gana gran relevancia» |
| `05` a `08` | Ruido de cinta | «las líneas son gruesas y muy flashy, con aberración cromática de vez en cuando, actualmente nosotros tenemos un ruido de grano muy delgado y como con puntillismo, acá es más como si la unidad de ruido se presentara en formas rectangulares, de movimiento muy rápido» |
| `09` y `10` | La imagen entrando | «se ve como una imagen cortada varias veces, es como si estuviera encuadrando antes de desplegar el video. Ese efecto es demasiado bueno» |
| `11_fotograma_aberracion_cromatica.webp` | Un fotograma con bandas de color | «Era común que en la época eso sucediera de vez en cuando en la grabación, solía ser en un solo frame de vez en cuando» |
| `12_banda_inferior_desplazada.webp` | Sala con un hombre de pie | «Se ve mejor cómo la banda inferior queda desplazada respecto al video original» |
| `13_fallo_de_color.webp` | Fallo de color en la mitad inferior | Sin comentario propio |
| `14_texto_am_11_59_jun_15_1986.webp` | «AM 11:59 / JUN. 15 1986» | «mira ese texto, es perfecto para The Four» |

Lo que no se ve en una foto y contó: «los bordes de la imagen es inestable en el video, no son definidos a lo largo de la cinta, tiene un "borboteo"».

## Lo que hay que hacer

1. **Tipografías.** Buscar la del PLAY de las referencias 01 y 02 y la del texto de cámara de la 14, con licencia que deje vender el juego (nunca NC, ND ni SA; `docs/OFICINAS.md` sección 12 y `docs/ASSETS.md`), con tildes y eñe, y ponerlas en la interfaz y en el texto de la cámara.
2. **Los bordes de la imagen.** Franjas negras en los laterales, con el borde difuso e inestable a lo largo del tiempo, un quemado de color a la izquierda y un brillo a la derecha.
3. **La banda inferior.** Las últimas líneas de la imagen, desplazadas hacia un lado respecto al resto, siempre.
4. **El ruido.** En unidades rectangulares y líneas gruesas, rápido y con destellos, con aberración cromática de vez en cuando, en lugar del grano fino de hoy.
5. **El fotograma suelto con bandas de color,** un solo fotograma cada cierto tiempo.
6. **La entrada del vídeo:** la imagen cortada en varias bandas inclinadas que se encuadran antes de asentarse.
7. **El PLAY inicial** con todo lo anterior.

## Lo que ya existe (por donde empezar)

- **`game/presentation/shaders/analog.gdshader`:** el filtro de la cinta sobre la imagen 3D y el texto de cámara. Sus términos van con los deslizadores del jugador (`vhs`, `grain`, `chromatic`, `scanlines`, `vignette`) y los efectos reducidos los ponen a 0. Ya tiene `signal_loss`, `tape_hit`, `tape_band`, `tape_fray`, `rewinding` y un modo `lite`.
- **`game/presentation/camcorder_osd.gd`:** REC, velocidad de cinta, fecha y hora, bajo el filtro. Ya escribe «AM 2:07:53 / NOV. 27 1992», el formato de la referencia 14.
- **`game/ui/osd_style.gd`:** `FONT_PATH` apunta a `res://assets/fonts/vcr_osd_mono.ttf`, **que no existe**: hoy sale la tipografía de reserva del sistema.
- **`game/ui/hotel_ui.gd`** (hacia las líneas 330 y 619 a 695): el arranque con su aviso de auriculares y su «▶ PLAY».
- **`game/app/presentation_rig.gd`:** quien alimenta el filtro cada fotograma.
- **`game/ui/shaders/tape_noise.gdshader` y `signal_wash.gdshader`:** la estática de los menús.
- **`assets/fonts/`** ya existe, con dos tipografías y sus licencias (las de la hoja de las oficinas).

## Sin decidir

- **Si la imagen sigue a pantalla completa con sus franjas laterales, o pasa a 4:3.** Las referencias son 4:3; el juego es 16:9. Pasarlo a 4:3 cambia el campo de visión y toda la interfaz: es decisión del autor. Esta nota supone 16:9 con franjas estrechas.
- **Cada cuánto** salen el fotograma de color y los destellos del ruido, y si la cordura los sube.

## Lo que no se puede romper

- Los efectos reducidos y los deslizadores siguen mandando: quien los baja deja de ver todo esto.
- Los dos renderizadores (Forward+ y Compatibilidad) y el modo `lite` de Muy bajo: `verify.ps1` compila los shaders en los dos.
- El juego tiene que seguir leyéndose: ni las franjas ni el ruido pueden tapar a la criatura ni los rótulos.
- El rendimiento: medir con `tools/benchmarks/run_bench.ps1` antes y después (`docs/PERFORMANCE.md`).
- Ningún texto del juego lleva «·» ni raya larga.

## Cómo se da por bueno

Capturas del juego puestas al lado de cada referencia: el PLAY, la imagen quieta con sus bordes y su banda inferior, un fotograma de ruido, la entrada del vídeo y el texto de cámara. El autor las juzga en la vista de juego, no en un banco de pruebas.
