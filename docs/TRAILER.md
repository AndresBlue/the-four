# The Four — Tráiler

Un tráiler de unos 60 s que explica el juego como lo explicaría el propio hotel: **una grabación de orientación por la megafonía**, amable y demasiado tranquila, que dicta las normas mientras las imágenes enseñan por qué existen. Termina recordando que este es el primer piso y quedan tres. Todo sale del juego mismo: cada toma se filma en el motor, sobre un piso real (semilla 81), con la cámara, la criatura y los supervivientes colocados a mano; nada es un render aparte ni un vídeo de otra cosa.

El resultado son 60 s exactos en `evidence/trailer/final/`: `The_Four_trailer_1080p.mp4` (1920×1080, 30 fps, H.264 a 14 Mb/s en dos pasadas, AAC) y `The_Four_trailer_720p.mp4` (6 Mb/s), a −14 LUFS integrados y −1 dBTP, sacados del máster `evidence/trailer/The_Four_trailer.mp4` (CRF 14, AAC 320 kb/s). No se versionan: `./tools/trailer/make.ps1` lo regenera todo (`-SkipShots` para no volver a filmar).

## Guion

| Tiempo | Imagen | Voz (megafonía) | Rótulo |
|---|---|---|---|
| 0:00 | El arranque del juego: auriculares, el azul del vídeo con ▶ PLAY, la imagen rompiéndose | — | — |
| 0:04 | Un pasillo largo de la tercera planta; al fondo, algo cruza, se para y mira | «Bienvenidos al hotel. Por su seguridad, respeten las normas.» | — |
| 0:10 | Tarjeta azul NORMA 1 → carrera con la videocámara → la criatura, de perfil, gira la cabeza y viene | «Uno. No corran por los pasillos. Él les oye.» | NO CORRAN POR LOS PASILLOS / ÉL LES OYE |
| 0:16 | NORMA 2 → a oscuras, la linterna, la tele se enciende → la criatura dentro de la tele se abalanza → el cristal | «Dos. Enciendan los televisores. Él también los usa.» | ídem |
| 0:23 | NORMA 3 → desde dentro del armario: se cierra, oscuridad, se entreabre, entra y se para delante | «Tres. Si les persigue, escóndanse. Y que nadie les vea entrar.» | ídem |
| 0:29 | NORMA 4 → el zoom entra en una puerta lejana; una cabeza asoma por el marco; la cinta se rasga y no hay nada | «Cuatro. No crean todo lo que ven.» | ídem |
| 0:34 | Dos compañeros por un pasillo → la hoja compartida dibujándose → la lectura acústica de la criatura, que chilla | «Salgan juntos. O que uno de ustedes… sea él.» | COOPERATIVO · UN HOTEL DISTINTO · VERSUS |
| 0:42 | Montaje al pulso de la música: apagón, carga, el golpe a la luz de la linterna, la ejecución, estática | — | — |
| 0:46 | Negro y silencio. El indicador de pisos de un ascensor: el 1 encendido; se encienden 2, 3 y 4, mal, y se apaga todo | «Esto es solo el primer piso. Quedan tres.» | — |
| 0:53 | La habitación de la portada: THE FOUR en la pared, la máscara asomando por la puerta 214, un tic de la cabeza | «Disfruten de su estancia.» | THE FOUR · PISO 1 · THE LOCUST |
| 0:58 | Cierre | — | Modos, «en desarrollo», créditos |

Los otros tres pisos no se nombran ni se enseñan: solo se anuncia que existen (las luces 2, 3 y 4, cada una de un color equivocado).

## Cómo se hace

Todo está en `tools/trailer/` y se regenera por partes:

1. **Voz** — `./tools/trailer/voice.ps1` sintetiza cada frase con las voces OneCore de Windows (Laura, es-ES; nada se descarga) en `evidence/trailer/voice/`. Las frases y los números de las normas van por separado: tras un punto la voz esperaba más de un segundo, y el montaje decide la pausa.
2. **Tomas** — `./tools/trailer/render.ps1 -All` filma cada toma de `shots.gd` en su propio proceso de Godot con `--fixed-fps 30` (el reloj del juego avanza exactamente 1/30 s por fotograma, tarde lo que tarde en dibujarse; unos 0,4 s por fotograma en Ultra a 1080p). Cada toma escribe sus fotogramas en `evidence/trailer/shots/<toma>/` y, en `events.json`, en qué fotograma pasa cada cosa (la cabeza que se gira, la tele que se enciende, cada pisada), que es lo que sincroniza el sonido. `-Preview` filma a un tercio y un fotograma de cada tres; `-Frames 30,90` solo esos, a tamaño completo. Antes de filmar, el script se compila una vez (`--check-only`), para que un error no se descubra toma a toma.
3. **Montaje** — `timeline.py` es la única fuente de verdad: qué fotogramas de qué toma van dónde, cuándo habla la voz y qué se escribe en pantalla. La imagen y el sonido la leen los dos.
4. **Sonido** — `python tools/trailer/audio.py` construye voz, música y efectos sobre el montaje y masteriza a −14 LUFS y −1 dBTP (limitador sobremuestreado a 4×). `dsp.py` son los filtros, la reverberación sintética, la dinámica y la medida de sonoridad (BS.1770-4); `instruments.py`, los instrumentos. `python tools/trailer/analyze.py` mide lo que no se puede escuchar aquí: la sonoridad por sección, cuánto sobresale la voz en cada frase (al menos 6 dB sobre el resto), cuánto trabaja el limitador y el reparto del espectro, con una gráfica en `evidence/trailer/audio/analysis.png`.
5. **Imagen** — `python tools/trailer/cut.py` compone cada fotograma (tarjetas azules de las normas, rótulos tecleados como un generador de caracteres, desgarros de cinta, el título y el cierre) y lo codifica con ffmpeg junto a la mezcla. `--stills 12.5,30` saca solo esos fotogramas; `--from 40 --to 48`, un trozo. `contact.py` hace hojas de contactos para revisar tomas de un vistazo, y `sync_check.py` mide en el archivo final dónde cambia la imagen y dónde ataca el sonido, contra los cortes y los golpes previstos.

Hace falta un ffmpeg con libx264 (el script busca uno conocido o toma la variable `FFMPEG`).

## Qué se usa y de quién

- **Imagen:** todo capturado en el motor del juego. Sale **The Locust**, que es un personaje de **Doctor Nowhere**, con el modelo de **Doumty** (licencia CC BY-NC-ND, permisos de distribución pendientes: [ASSETS.md](ASSETS.md)). El cierre lo dice, junto a «proyecto fan no oficial», como los créditos del juego.
- **Música:** original, sintetizada en `instruments.py` (una caja de música, cuerdas, pulsos, impactos). **No se usa `the_four_theme.mp3`**, cuyo autor y licencia están sin verificar.
- **Voz:** síntesis de voz de Windows, procesada como una grabación por megafonía.
- **Efectos:** sintetizados aquí o por las herramientas del propio proyecto (`assets/audio/dread`, `assets/audio/intro`: chasquidos, zumbidos, estática, golpes en el cristal y en la puerta). Una sola grabación ajena: el grito de la ejecución, «Jumpscare sound» de **EnclosureX_Studios** (CC BY 4.0), acreditado en el cierre. No se usan los sonidos aportados de licencia desconocida ni los NC.
