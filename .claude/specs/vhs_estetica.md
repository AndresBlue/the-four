# La estética VHS de la cámara y del PLAY inicial

Encargo del autor, 19 de noviembre de 2026. **Construido ese mismo día (apartado «Estado»); el autor no lo ha visto moverse.** Sus catorce referencias están en `evidence/referencias/vhs/` (fotogramas de vídeos de la época, solo para mirar: no entran en el juego ni en git).

## Estado (19 de noviembre de 2026)

Los siete puntos están en el juego. Cómo funciona cada uno está en `docs/DEVELOPMENT.md` («Iluminación y posprocesado» y «HUD, menús y ajustes»).

- **Decidido por el autor:** 4:3 solo en el PLAY inicial; el juego y los menús siguen a 16:9 con franjas estrechas.
- **Tipografía:** Home Video (GGBotNet, CC0), en `assets/fonts/home_video/`, para toda la interfaz, el PLAY y el texto de cámara (este, estrechado y engrosado). Por qué esa y no otra, en `docs/ASSETS.md`.
- **Capturas junto a las referencias:** `evidence/vhs/comparacion_1` a `6` (se rehacen con `tools/capture/boot_capture.gd` y `tools/capture/tape_capture.gd`).
- **Elegido por quien lo construyó, sin que el autor lo haya decidido:** el fotograma de color sale de media cada 26 s con el deslizador por defecto y más a menudo con la cordura baja (porque esta ya sube el desgaste de la cinta); la entrada del vídeo dura 1,1 s y sale cada vez que la cámara empieza a filmar; el texto de cámara mide 54 px sobre 720 (las referencias lo llevan algo mayor).
- **Lo que no se parece todavía:** la referencia 13 (el fallo de color con ráfagas blancas en la mitad inferior) no tiene equivalente propio: el fotograma de color solo hace bandas, a veces desde media altura. El grano fino del sensor (`lens.gdshader`, deslizador «Grano») no se tocó: lo rehecho en bloques es el ruido de la cinta (la nieve, la banda de tracking y la estática de los menús).
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
