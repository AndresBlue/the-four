# Ficha de hechos: capturas

Fecha de lectura: 14 de noviembre de 2026. Repositorio: `E:\Projects\The Four`, rama `main`, último commit `e50a862`.
Estado de git al inicio: `tools/capture/office_plan_capture.gd` tiene cambios sin confirmar (`M`). Esta ficha describe el árbol de trabajo tal como estaba en disco.

Método: lectura del código. No se ejecutó Godot, Blender ni ningún Python de las herramientas. Las rutas son relativas a la raíz del repo. Las líneas son las del archivo en disco. Lo que no se leyó va en «Sin comprobar» (sección 14).

---

## 1. Cómo se revisan hoy las visuales

- **Capturas de escena con cámara fija.** Son 55 scripts `.gd` y 1 `.py` en `tools/capture/` (56 entradas). La mayoría son un `SceneTree` que levanta `game/app/hotel.tscn`, fija una semilla, coloca la cámara del jugador y guarda un PNG o JPG con `get_image().save_png()`. Las hojas de contacto y `lurker_test` usan escenas propias. No hay un lanzador común: cada cabecera dice su propia línea de comando.
- **Lanzadores de `tools/godot.ps1`.** Solo hay modos para `gallery` (`tools/workbenches/module_gallery.tscn`), `lurker` (`lurker_test.tscn`), `lurker-arena` (`lurker_arena.tscn`, con `--test-profile`), `build-gallery` (`tools/editor/build_gallery.gd`), `bench` (`tools/dev/capture_bench.gd`) y `bench-films` (`godot.ps1:110-125`, con `--fixed-fps 60` y `--write-movie`). Las demás capturas no tienen modo en `godot.ps1`.
- **Comparación contra referencias.** Solo el piso 2 tiene fotos de referencia del autor (`docs/referencias/`, 15 JPEG). `office_rooms_capture.gd` las compara con su captura con dos criterios numéricos (sección 9.3). El resto de herramientas no compara nada: deja las imágenes para que se miren a ojo.
- **Hojas de contacto.** `lookdev_sheet.gd`, `office_pieces_sheet.gd`, `tools/props/catalogue_sheet.gd`, `avatar_gait_capture.gd`, `locust_gait_capture.gd`.
- **Medición de películas.** `tools/capture/film_check.py` mide la sonoridad (BS.1770) y los destellos (WCAG 2.3.1) de un AVI que escribe el `bench-films`.
- **Tráiler aparte.** `tools/trailer3d/` genera el tráiler con Three.js, no con el motor (sección 8).
- **Sin ninguna comparación con Unreal ni con imágenes doradas.** No hay nada en el repo que compare dos motores.

---

## 2. Inventario de archivos leídos

### 2.1 Leídos enteros

| Archivo | Líneas | Qué hace |
|---|---|---|
| `tools/capture/office_capture.gd` | 288 | 29 vistas del piso 2 (resguardo, cápsula, ventanilla, tubos, estación, mesas, archivo, cristal, hueco de placa, escalerilla, climatizadora, compuerta, seguridad, ducto, restos, pozo, planta 2 con y sin corriente, emergencia, cuadro, minutero). |
| `tools/capture/office_plan_capture.gd` | 124 | Hereda de `office_rooms_capture.gd`. Captura el plano real del piso 2 con la cámara del juego (anillo, despacho, galería, recepción, nave, aseos, archivo, dirección). Cambios sin confirmar. |
| `tools/capture/office_rooms_capture.gd` | 418 | Cada sala con referencia, encuadrada desde su puerta, comparada con su foto (criterios a y b) y con cifras en `cifras.json`. |
| `tools/capture/office_angles_capture.gd` | 268 | Cinco ángulos por tipo de sala del piso (puerta, rincón, mueble, techo, suelo), más la llegada y las salas a oscuras con linterna. |
| `tools/capture/office_pieces_sheet.gd` | 107 | Hoja con una muestra de cada pieza de `game/world/office/pieces/index.gd`. |
| `tools/capture/room_framing.gd` | 70 | Encuadre de las salas (constantes de cámara, puerta, vista). Lo usa también `tests/office/office_proportion_test.gd`. |
| `tools/capture/lurker_office_look.gd` | 646 | La criatura en el piso 2 (semilla 7): techos, rejillas, oscuridad, tinta, huida, secuencias v4 y v7, polvo. |
| `tools/capture/lookdev_capture.gd` | 180 | Siete tomas del piso 1 (semilla 81) más cuatro primeros planos, en crudo y como se juega. |
| `tools/capture/lookdev_sheet.gd` | 63 | Hojas de contacto de las tomas de `lookdev_capture`. |
| `tools/capture/camcorder_capture.gd` | 62 | Prop de la videocámara y la cinta sobre un suelo, en tres vistas. |
| `tools/capture/intro_capture.gd` | 28 | Fotogramas de la escena inicial en 15 instantes. |
| `tools/capture/background_window.gd` | 19 | Auxiliar: manda la ventana a otra pantalla y le quita el foco con `--background`. |
| `tools/capture/lurker_materials_probe.gd` | 27 | Imprime cómo importó Godot el GLB de la criatura (sin imagen). |
| `tools/capture/settings_capture.gd` | 32 | Pantalla de ajustes, una foto por pestaña. |
| `tools/workbenches/README.md` | 9 | Qué es el taller de módulos y las dos escenas de banco. |
| `tools/workbenches/lurker_arena.gd` | 81 | Banco de la criatura en el piso 2 con teclas para forzar estados. |
| `tools/workbenches/lurker_test.gd` | 398 | Pasillo de prueba con la criatura, la linterna y la videocámara; modelo de movimiento propio. |
| `tools/workbenches/lurker_arena.tscn`, `lurker_test.tscn` | pocas | Escenas que solo enlazan al script. |
| `tools/lighting/measure_albedo.gd` | 76 | Mide el color medio de cada material del hotel para el rebote de luz. |
| `tools/editor/build_gallery.gd` | 87 | Construye `module_gallery.tscn` (veinte módulos de referencia). |
| `tools/editor/preview_camera.gd` | 22 | Cámara libre de F6 para la galería. |
| `tools/import/strip_blend_shapes.gd` | 41 | Script de importación que quita las formas de mezcla de los modelos de personaje. |
| `tools/props/ingest_models.py` | 602 | Ingesta de modelos: texturas, materiales `.tres`, registro en `docs/ASSETS.md`. |
| `tools/props/decimate.py` | 130 | Decimado y conversión con Blender (`--tris`, `--drop`, `--weld`). |
| `tools/props/add_mesh_lods.gd` | 42 | Añade niveles de detalle a tres mallas horneadas. |
| `tools/props/fetch_models.py` | 57 | Descarga modelos de Poly Haven (CC0) con su md5. |
| `docs/TRAILER.md` | 67 | Cómo se hace el tráiler, su guion y sus licencias. |
| `docs/referencias/oficinas/LEEME.md` | completo | Qué son las referencias del piso 2 y lo que dijo el autor. |
| `tools/trailer3d/package.json` | completo | Dependencias del tráiler. |

### 2.2 Leídos por cabecera (primeras 15 a 32 líneas) y estructura

Del resto de `tools/capture/` (todos los que no están arriba) se leyó la cabecera y las primeras líneas del cuerpo, que es lo que pedía el encargo. Entran aquí `avatar_capture`, `avatar_gait_capture`, `boot_capture`, `character_capture`, `code_note_capture`, `continue_capture`, `darkness_capture`, `difficulty_capture`, `doors_capture`, `echo_capture`, `execution_capture`, `film_check.py`, `ghosting_capture`, `hint_capture`, `hold_capture`, `key_capture`, `lift_capture`, `locust_gait_capture`, `lurker_capture`, `lurker_hand_check`, `lurker_test_check`, `mask_capture`, `note_survey_capture`, `notes_capture`, `online_capture`, `phantom_capture`, `preset_tour`, `props_capture`, `records_capture`, `rooms_capture`, `route_signs_capture`, `rules_capture`, `sheet_capture`, `sheet_map_capture`, `television_capture`, `title_capture`, `torch_capture`, `transit_capture`, `ui_capture`, `upscale_capture`, `walkthrough_movie`, `catalog_capture`, y `office_*` ya listados arriba.

De `tools/props/` se leyó la cabecera de: `build_catalogue.gd` (555 líneas, más sus constantes), `build_model_props.gd` (75), `build_camcorder.gd` (113), `build_door.gd` (100), `build_elevator.gd` (97), `build_wardrobe.gd` (227), `catalogue_sheet.gd` (61), `check_ingest_models.py` (190), `cloth_pieces.py` (168), `bake_key.gd` (84), `prepare_key_textures.py` (42), `fit_model.py` (213), `register_sketchfab.py` (132), `ingest_camcorder.py` (240). `fit_models.json` solo se miró en estructura: 60 entradas (la clave `_doc` más 59 modelos).

De `tools/trailer3d/` solo se leyó lo que es: `package.json`, las cabeceras de `render.mjs`, `server.mjs`, `voice.mjs`, `encode.py`, `contact.py`, y la lista de `web/` y `audio/`.

De `docs/referencias/`: árbol completo y `LEEME.md`. De `evidence/rediseno/`: estructura y nombres de hojas (sección 5.3). De `evidence/autor_12nov/` y `evidence/autor_12nov_b/`: solo listas (sección 5.4).

---

## 3. Herramientas de captura (las 56 entradas)

Cada fila dice qué captura, desde qué cámara, con qué semilla y calidad, con qué argumentos y dónde deja los archivos. Donde pone «sin comprobar» es porque la línea no se leyó.

### 3.1 Piso 2 (oficinas)

| Herramienta | Qué captura | Cámara y encuadre | Semilla, calidad, ventana | Argumentos | Salida |
|---|---|---|---|---|---|
| `office_capture.gd` | 29 vistas del piso 2 (resguardo, cápsula, ventanilla, central de tubos, estación, mesas, archivo, cristal, hueco de placa, escalerilla, climatizadora, compuerta, seguridad, ducto, restos, pozo, planta 2 con y sin corriente, emergencia, cuadro, minutero). | Cámara del jugador con `look()`. Puntos sacados del manifiesto (`m.tubes`, `m.mail`, `m.air`, `m.power`). | Semilla 7 (línea 55). Calidad -1 (línea 56), es decir, la del preset. Ventana 1280×720 (51). | `--test-profile`, `--seed=`, `--quality=` (4 es Muy bajo), `--prefix=` (cabecera 12-13). `creature_scene = "none"` (62). `start_floor(seed, false, [1], "", 2)` (63). | `evidence/office_capture_<prefijo><nombre>.png` |
| `office_rooms_capture.gd` | Cada sala con foto de referencia (15 en `ROOMS`), desde su puerta. Además las vistas de vano de seguridad, secretaría y montacargas (`THROUGH`, línea 39) y `edificio_pasillo.png`. | Encuadre de `room_framing.gd`, horizontal de 55°. Luz de todas las salas (`light_all`, línea 80). | Semilla 7 (295), calidad 2 (296), dificultad «apacible», `start_floor(..., 2)` (307). Ventana 1200×800 (312). | `--seed`, `--quality`, `--prefix` (cuelga de `evidence/rediseno/`), `--rooms=a,b`. | `evidence/rediseno/<prefijo>/<sala>.png` (referencia a la izquierda y captura a la derecha), `<sala>_juego.png` (cámara del juego), `vano_<sala>.png`, `edificio_pasillo.png`, `cifras.json` |
| `office_plan_capture.gd` (extiende `office_rooms_capture.gd`; cambios sin confirmar) | Plano real del piso 2 «como se juega». Planta 1: anillo, despacho (un módulo de 3,6 m), galería. Desde sus puertas: recepción, nave, aseos, archivo de planta 2, dirección de planta 3. | Cámara del juego, no el encuadre de 55° (`down()`, `inside()`). Mira 20 m hacia el este (`DOWN`, línea 13). | Semilla 7 (22), calidad 2 (23), ventana 1200×800 (57), `start_floor(seed, false, [1], "apacible", 2)` (32). | `--real-plan`, `--seed=`, `--quality=`. Lanzado con `--log-file` (cabecera 9). | `evidence/planta/capturas/<semilla>_{anillo,despacho,galeria,recepcion,nave,aseos,archivo,direccion}.png` |
| `office_angles_capture.gd` | Por cada tipo de sala del piso (la primera de cada tipo, planta 1 antes): cinco ángulos (`puerta`, `rincon`, `mueble`, `techo`, `suelo`; línea 18), más `llegada` (tres pasos y una mirada en picado de 15°). Después oficina y nave a oscuras con linterna. | Estatura de pie 1,6 m (`STANDING`, 20) o sentado 1,15 m (`SEATED`, 19). Ojo desplazado hasta que no toque nada (`clear_eye`, 52-59). | Semilla 7 (194), calidad 2 (195), ventana 1280×800 (211). Espera de asentado 1200 ms (69). | `--seed`, `--quality`, `--prefix` (cuelga de `evidence/rediseno/`), `--types=`, `--doors` (puertas de cada familia), `--triplets`. | `evidence/rediseno/<prefijo>/<tipo>_<n>.png`, `_linterna`, `puerta_<familia>_a/b_*.png`, y `indice.json` con tipo, ángulo, sala, archivo y pose |
| `office_pieces_sheet.gd` | Una muestra de cada pieza de `game/world/office/pieces/index.gd`, con suelo y sol propios. | Cámara a 35° de campo (línea 43), a 0,45 / 0,35 / 1,0 del centro de la pieza, escala de 3,3 radios (68). | Sin semilla. Celdas de 320 px, 8 columnas (9-10). | `--automation --test-profile --silent`. | `evidence/rediseno/piezas.png` y `piezas.json` (nombre, tamaño, triángulos, superficies) |
| `lurker_office_look.gd` | La criatura en el piso 2 vista con la cámara de la videocámara: sobre un techo con la linterna a 6 y 3 m, saliendo de una placa y de una rejilla, en oscuro, cruzando una sala iluminada, tinta cerca y lejos, quieta, asustada y huyendo. Secuencias `v4` y `v7`, y polvo (`dustgame`, `dust`, `lab3`). | Cámara a 1,6 m (`EYE`, 17) siguiendo a la criatura (`film`, `chase_eye`). Paso visto 1,35 m/s (`SEEN_PACE`, 15); huida 3,5 m/s (`FLEE_PACE`, 16). | Semilla 7 (13), dificultad «equilibrada» (45), `set_floor(2)` (44), ventana 1280×720 (37). Cuadros cada 2 o 3 fotogramas. JPG calidad 0,88 (151). | `--phase=` (cuelga de `evidence/lurker_look/`), `--shots=v4|v7|dustgame|lab3|dust`, `--trace`. Con `--fixed-fps 30` (cabecera 10). | `evidence/lurker_look/<fase>/*.jpg` |
| `lookdev_capture.gd` | Piso 1 (hotel): recepción, dormitorio, salón, pasillo, baño, servicio, oscura. Primeros planos: cama, cornisa, zócalo, azulejo. | Cámara fija en la esquina (`aim()`, 103-112): desde 10 % del ancho y a 1,6 m de la pared del fondo, mirando a -30 % del ancho. Inclinación -0,12 rad (111). | Semilla 81 fija (60). Calidad por defecto `PRESETS.HIGH` (40), es decir 2 (Alto). Ventana 1920×1080 (29). | `--label=`, `--quality=`, `--setup=<script>`, `--set=clave:valor,...`, `--only=`, `--automation --test-profile --no-enemy --silent`. | `evidence/lookdev/<etiqueta>_q<calidad>/<toma>_raw.png` (sin cámara, sin lente) y `<toma>_vhs.png` (como se juega) |
| `lookdev_sheet.gd` | Hojas de contacto de `lookdev_capture`. Siete tomas en tres columnas, o una fila por toma y una columna por carpeta. | Panel de 640×360. | Sin semilla. | `--dirs=a,b --kind=raw --out=` | `sheet_<kind>.png` |
| `camcorder_capture.gd` | Prop de la videocámara y la cinta sobre un suelo, con una lámpara. Un ejemplar apoyado y otro caído. | Cámara de 40° (51). Tres vistas: frente, lado, atrás. | Ventana 1280×720. | Ninguno. | `evidence/camcorder_prop_{front,side,back}.png` |

### 3.2 Piso 1 (hotel)

| Herramienta | Qué captura | Cámara y encuadre | Semilla, calidad, ventana | Argumentos | Salida |
|---|---|---|---|---|---|
| `rooms_capture.gd` | Pasillo sin armarios, dormitorio con armarios, entrada del hotel. | Altura de ojo 0,04 m y -0,08 rad (función `look_from`). | Semilla 81 (`start_floor(81)`). Ventana 1280×720. | Ninguno. | `evidence/rooms_<nombre>.png` |
| `props_capture.gd` | Sofá, planta, apliques de pasillo y documento sobre escritorio. | Ojo a 0,04 m (25). | Ventana sin comprobar. | Ninguno. | `evidence/props_<nombre>.png` |
| `preset_tour.gd` | Un piso en un preset: recepción, pasillo iluminado, sala apagada, puerta entre sala apagada y encendida, armario, televisor, lobby del ascensor, criatura en sala iluminada y en la oscura. | Cámara del jugador (`look()`, 47-60). | Calidad por defecto 4 (variable `quality`), es decir Muy bajo (`graphics_presets.gd:20`). Ventana 1280×720 con lectura de la imagen. | `--quality=N`, `--raw`, `--test-profile --automation --silent`. | `evidence/tour_q<n>_<lugar>.png` |
| `torch_capture.gd` | La linterna sola: pasillo, pared, techo y sala grande, con las luces del piso apagadas. | Cámara del jugador con `snap_torch()`. | Sin semilla. | `--prefix=` (defecto `torch`), `--quality=`, `--automation --silent`. Pensado para correrse con dos renderers (cabecera 4-12). | `evidence/<prefijo>_<nombre>.png` (línea 32) |
| `darkness_capture.gd` | Oscuridad y fugas de luz: puerta, sala a oscuras, linterna, pared, cortes de corriente, refugio. | Cámara del jugador. | Sin semilla en la cabecera. | `--prefix=` (defecto `darkness`), `--automation`. | `evidence/<prefijo>_<nombre>.png` (línea 35) |
| `doors_capture.gd` | Puerta vista desde dentro (con su número) y sala con la lámpara apagada. | Cámara a 2,5 m dentro de la sala. | Ventana 1280×720. | Ninguno. | `evidence/door_number.png`, `evidence/dark_room.png` (línea 18) |
| `lift_capture.gd` | Puerta del refugio, cabina esperando en el lobby, interior de la cabina y el piso de destino. | Cámara con `look_from()`. | Semilla 81. Ventana 1280×720. | Ninguno. | `evidence/lift_<nombre>.png` |
| `television_capture.gd` | Televisor del hotel en planta 2: apagado, al encender, encendido de lado, desde lejos (con la luz que da), de cerca, con linterna. | `stand()`: a una distancia en metros, de un lado y a una altura. | Sin semilla en la cabecera. Ventana con lectura de la imagen. | `--test-profile`. | `evidence/tv_<momento>.png` |
| `sheet_capture.gd` | Hoja compartida: vacía, con números, con cuatro manos dibujando. | Cámara sobre la hoja. | Semilla 81 (`start_floor(81)`). | `--silent`. | `evidence/sheet_<nombre>.png` |
| `sheet_map_capture.gd` | Hoja con su plano, con el jugador caminando hacia el refugio. | Cámara del jugador. | Semilla 81 (`--seed=`). Ventana 1600×900. | `--test-profile --automation --silent`. | `evidence/sheet_map_<nombre>.png` |
| `code_note_capture.gd` | Cuatro muebles con un número escrito: desde la puerta y desde un brazo, más el mismo mueble con el número tomado. | `look_from()`. | Semilla 81. Ventana 1280×720. | Ninguno. | `evidence/code_note_<nombre>.png` |
| `note_survey_capture.gd` | Cada tipo de lugar donde cabe una nota (cómoda, armario, consola, cajones, estantería en sus tres baldas, caja, cajón). De cerca, desde la sala, de detalle y de lado. | `look(eye, at)`. | Semillas por defecto 81, 777 y 202 (`--seeds=`). | `--seeds=` (cabecera 14-16 y el resto sin comprobar). | `evidence/note_<tipo>_{close,room,detail,side}.png` |
| `notes_capture.gd` | Todos los papeles del hotel: los ocho tipos (`limpieza`, `orden`, `indicaciones`, `polaroid`, `calco`, `plano`, `nomolestar`, `hoja`) y las páginas del código. | Cámara del jugador, fotos de sala y de detalle. | Semillas 81, 777, 202 (`--seeds=`). | `--test-profile --automation --silent`. | `evidence/notas_*.png` y `evidence/notas_index.json` |
| `hint_capture.gd` | Los ocho papeles de la tercera etapa lado a lado y la hoja con todos colgados. | Cámara del jugador. | Semilla 81 (`--seed=`), `--survivors=1`. Ventana 1600×900. | `--test-profile --automation --silent`. | `evidence/hints_<semilla>_papers.png` y `_sheet.png` |
| `key_capture.gd` | La llave del piso fuera de su cajón, y un cuadro eléctrico cerrado y abierto con la llave. | Cámara a la altura del ojo (`look(eye, at)`). | Semilla 81 (`--seed=`). Ventana 1600×900. | `--test-profile --automation --silent`. | `evidence/key_<nombre>.png` |
| `route_signs_capture.gd` | Carteles de salida del primer piso, de ambos lados y en cuatro direcciones (`WAYS`, línea 6). | `face()` hacia el punto del cartel. | Semilla 81 (`--seed=`). | `--test-profile --automation --silent`. | `evidence/route_sign_<n>_<front|back>.png` |
| `phantom_capture.gd` | La criatura que ve la mente (`game/app/phantom_sight.gd`): la cabeza tras una puerta abierta y al fondo de un pasillo. | Cámara del jugador (`face()`). | Semilla 81 (`start_floor`). | `--test-profile --automation --silent`. | `evidence/phantom_<nombre>.png` |
| `execution_capture.gd` | La ejecución vista de lado, o desde los ojos de la víctima con `--victim`. | Cámara lateral con luz de apoyo (`OmniLight3D` de energía 3 y alcance 12). | Semilla 81. Ventana 1280×720. | `--victim`. | `evidence/execution_*.png` y `execution_pov_*.png` |
| `mask_capture.gd` | La máscara de la criatura vista de cerca con la lente en varias distancias. | Cámara en el hueso `Head1` con el punto `MASK_CENTRE`. | Semilla 81. Ventana 1280×720. | Ninguno. | `evidence/mask_*.png` |
| `echo_capture.gd` | Vista acústica de la criatura: corredor, frente de onda, puerta, cuerpo visto, cuerpo detrás de pared, grito, memoria, reducido, presets 0 a 3, luz de la linterna, guías y canales. | Cámara del jugador. Espera por `physics_frame` (58-66). | Ventana con lectura de la imagen (no vale `--headless`). | `--prefix=echo`, `--automation --silent --test-profile`. | `evidence/<prefijo>_*.png` |
| `ghosting_capture.gd` | Fantasmas de reconstrucción: la criatura cruza la vista a velocidad fija. Mide contra la imagen completa en 0,6 de escala. | Cámara del jugador, cuadro fijo. | Semilla 81 (`--seed=`), `--scale=0.6`. Forward+ solamente. | `--fixed-fps 60`, `--rendering-method forward_plus`. | `evidence/ghost_<modo>.png` y líneas `GHOST` por consola |
| `upscale_capture.gd` | La misma vista por cada reescalador: nativo, bilineal, FSR 1.0 y FSR 2.2. | Cámara del jugador. Espera de 90 fotogramas (línea 22). | Semilla 81, escala 0,6. Forward+ solamente. | `--seed=`, `--scale=`. | `evidence/upscale_<modo>.png` |
| `walkthrough_movie.gd` | Un paseo grabado desde la recepción por la ruta de la planta. Películas con Movie Maker. | Cámara del jugador con entradas reales. | Semilla 81. Ventana 1280×720. Calidad 2. | `--write-movie evidence/lookdev/walk.avi --fixed-fps 30`, `--quality=`, `--seconds=24`, `--run`, `--handheld`. | `evidence/lookdev/walk.avi` |
| `title_capture.gd` | Menú principal sobre la sala de título, en tres instantes de la deriva de cámara (0, 22, 48 s), y el cierre de la puerta. | Cámara del título (`title.camera`, fov 20 en el primer plano). | Sin semilla. Ventana 1280×720. | Ninguno. | `evidence/title_<instante>.png`, `title_multiplayer.png` |
| `ui_capture.gd` | Todas las pantallas de menú, la intro y el HUD. | Cámara de la interfaz. | Semilla 81 (`FLOOR`). Ventana 1280×720. | `--prefix=`. | `evidence/<prefijo>_<nombre>.png` |
| `intro_capture.gd` | Escena inicial en 15 instantes (`MOMENTS`). | Escena de la intro a velocidad 2, que se detiene en cada instante. | Semilla 81. Calidad 2. Ventana 1280×720. | Ninguno. | `evidence/intro_<instante>.png` |
| `boot_capture.gd` | Arranque: aviso de auriculares, azul del VCR con PLAY y paso al menú. | Cámara de la intro con reloj de pared (16-17). | Ventana 1280×720. | `--silent`. | `evidence/boot_<nombre>.png` |
| `hold_capture.gd` | Anillo de mantener pulsado, la intro mientras se salta y el aviso del primer piso con su objetivo. | Cámara del jugador. | Semilla 81, dificultad «equilibrada». Ventana 1280×720. | `--test-profile`. | `evidence/hold_<momento>.png` |
| `continue_capture.gd` | «Continuar» fotografiado: piso jugado en su segundo sector, antes de salir y después de volver. | Cámara del jugador. | Semilla 81, dificultad «equilibrada». | `--test-profile`. | `evidence/continue_antes.png` y `continue_despues.png` |
| `difficulty_capture.gd` | Pantallas de dificultad («apacible», «pesadilla») y la sala con el anfitrión. | Menús. | Puerto 24690 (sala). Ventana 1280×720. | `--test-profile`. | `evidence/difficulty_<pantalla>.png` |
| `rules_capture.gd` | Reglas de la sala: la sala con reglas cambiadas, la pantalla de elección y la ayuda. | Menús. | Puerto 24689. Ventana 1280×720. | `--test-profile`. | `evidence/rules_<pantalla>.png` |
| `online_capture.gd` | Menús en línea: multijugador, unirse, unirse por Steam y la sala con invitados ficticios. | Menús. | Puerto 24650. Ventana 1280×720. | Ninguno. | `evidence/online_<pantalla>.png` |
| `records_capture.gd` | Resultados de la cinta que salió y la que no, menú principal, marcas, carrera, archivo y pantalla de carga. | Menús. | Datos ficticios por `member()`. Ventana 1280×720. | `--test-profile`. | `evidence/records_<pantalla>.png` |
| `character_capture.gd` | Pantalla de personaje, por cada sobreviviente, abierta y elegida. | Menú de personajes. | Tamaño por defecto 1264×681. | `--size=WxH`. | `evidence/character_<i>_open.png` y `character_<i>.png` |
| `settings_capture.gd` | Pantalla de ajustes, una foto por pestaña. | Menú de ajustes. | Tamaño por defecto 1280×720. | `--size=WxH`. | `evidence/settings_<pestaña>.png` |
| `transit_capture.gd` | Corte entre dos alas al subir al ascensor, con la tarjeta del ala y la vuelta a la imagen. | Cámara del ascensor. Tiempo de viaje por reloj (25-26). | Ventana sin comprobar. | `--silent`. | `evidence/transit_<nombre>.png` |
| `catalog_capture.gd` | Papeles del hotel, muebles que contienen papeles y el resto del mobiliario, uno de cada uno en una sala iluminada. | Cámara del jugador. | Semillas 81, 777, 202, 4242 (`--seeds=`). | `--test-profile --automation --silent`. | `evidence/cat_*.png` y `evidence/cat_index.json` |

### 3.3 Criatura (`The Locust`, sin piso fijo)

| Herramienta | Qué captura | Cámara y encuadre | Semilla, calidad, ventana | Argumentos | Salida |
|---|---|---|---|---|---|
| `lurker_capture.gd` | La criatura en un pasillo iluminado con la espalda a una pared. Modos `--walk` (manos sobre suelo, pared y techo) y `--passage` (pasaje de un metro). | Cámara baja desde el fondo (cabecera). | Ventana 1920×1080 (`SIZE`, 21) y 960×540 para `--walk` (22). | `--automation --test-profile --no-enemy --silent --label= --clip= --at= --walk --passage --raw --no-dark`, y `--fixed-fps 30` antes del `--` en `--walk`. | `evidence/lurker/<etiqueta>_*.png` y `_vhs.png`; `_walk_<fotograma>.jpg`; `_passage_<fotograma>.jpg` |
| `lurker_hand_check.gd` | Manos de la criatura sobre una pared, vistas de lado. | Ventana de 900×900. | Sin semilla. | `--lamp`. | `evidence/lurker/hands_<brazo>.png` y `hands_lamp_<brazo>.png` |
| `lurker_test_check.gd` | Corre `tools/workbenches/lurker_test.tscn` sin nadie a los mandos. Escribe cada cambio de estado. | Cámara fija sobre la criatura. | `--fixed-fps 30`. | `--label=`, `--torch-at=26`, `--for=40`, `--every=3`, `--stand=-4.5`. | `evidence/lurker/<etiqueta>_<segundos>_<humor>.jpg` y `_f<fotograma>.jpg` |
| `locust_gait_capture.gd` | Hoja de marcha de la criatura a varias velocidades, más poses de golpe. | Vista lateral, 960×640. Sin AI. | Sin semilla. | Ninguno. | `evidence/locust_gait.png` (línea 74) |
| `lurker_materials_probe.gd` | Imprime cómo importó Godot el GLB de la criatura: color de vértice, especular, rugosidad, clips y bucles. | Sin cámara. | Sin escena. | `--headless --glb=` (defecto `res://assets/enemies/lurker/lurker.glb`). | Solo consola |

### 3.4 Personajes y gráficos sin piso

| Herramienta | Qué captura | Cámara y encuadre | Semilla, calidad, ventana | Argumentos | Salida |
|---|---|---|---|---|---|
| `avatar_capture.gd` | Los tres sobrevivientes (`detective`, `detective_woman`, `realistic_female`) de cuerpo entero y de cara, en una sala blanca. | Sala propia con luz direccional de 1,6 de energía, tonemap filmic. MSAA 4×. | Ventana 1280×720. | Ninguno. | `evidence/avatar_<id>_body.png` y `_face.png` |
| `avatar_gait_capture.gd` | Hoja de marcha de un sobreviviente: quieto, andando, corriendo, agachado quieto, agachado andando, salto. Suelo con una marca por metro. | Vista lateral, 960×640 por ventana. Celdas de 480×320. | `--character=` por defecto 2. | `--character=N`. | `evidence/avatar_gait_<n>.png` (línea 145) |
| `background_window.gd` | Auxiliar, no captura. | — | — | `--background`. | — |
| `film_check.py` | Mide una película AVI del `bench-films`: sonoridad integrada, de cada toma y de la voz; destellos según WCAG 2.3.1. Requiere Pillow, numpy y scipy. | — | — | `<película.avi> [--caught=] [--scream=] [--sheet= --times=]`. | Consola y, con `--sheet`, una imagen |
| `room_framing.gd` | Auxiliar: encuadre compartido de `office_rooms_capture` y del test de proporción. | — | — | — | — |

### 3.5 Totales

- 56 entradas: 55 archivos `.gd` y 1 `.py` (`film_check.py`). Dos de ellas son auxiliares sin captura (`background_window.gd`, `room_framing.gd`) y una mide películas (`film_check.py`).
- Las carpetas de salida mezclan `evidence/` (raíz), `evidence/rediseno/`, `evidence/lookdev/`, `evidence/lurker/`, `evidence/lurker_look/`, `evidence/planta/capturas/`.

---

## 4. Planos canónicos que ya existen

No se propone ninguno. Esto es lo que el repo ya fija.

### 4.1 Piso 1 (hotel)

- **Semilla 81**: es la semilla de referencia para casi todas las capturas del hotel (`lookdev_capture.gd:60`, `ghosting_capture.gd` y `upscale_capture.gd` por defecto, `sheet_capture.gd`, `hold_capture.gd`, `intro_capture.gd`, `route_signs_capture.gd`, `phantom_capture.gd`, entre otras).
- **Siete tomas de `lookdev_capture.gd`** (`SHOTS`, línea 32): `recepcion`, `dormitorio`, `salon`, `pasillo`, `bano`, `servicio` y `oscura`. Cada una tiene su propio punto de cámara en `aim()` (103-112). Cuatro primeros planos (`CLOSE`, línea 114): `cama`, `cornisa`, `zocalo` y `azulejo`.
- **Calidad**: `lookdev_capture` usa calidad 2 (Alto) por defecto; `preset_tour` usa calidad 4 (Muy bajo).
- **Herramientas de recorrido**: `walkthrough_movie.gd` (semilla 81, ruta desde la recepción, 24 s por defecto).
- Referencias de fotos para el piso 1: ninguna en `docs/referencias/`.

### 4.2 Piso 2 (oficinas)

- **Semilla 7** en casi todas las herramientas de oficinas (`office_capture.gd:55`, `office_rooms_capture.gd:295`, `office_angles_capture.gd:194`, `office_plan_capture.gd:22`, `lurker_office_look.gd:13`). Calidad 2 (Alto) en `office_rooms`, `office_angles` y `office_plan`.
- **Quinto argumento de `start_floor` igual a 2**: `office_capture.gd:63`, `office_rooms_capture.gd:307`, `office_angles_capture.gd:207`, `office_plan_capture.gd:32`. `lurker_office_look.gd:44` y `lurker_arena.gd:24` llaman a `set_floor(2)` aparte, sin quinto argumento. La firma es `start_floor(seed_value, force_fallback := false, slots := [1], difficulty_id := "", floor_number := 0)` (`game/app/hotel_main.gd:720`).
- **Quince salas con foto** (sección 5.1) y dos sin foto: `nave` (tipo 1) y `cubiculos` (tipo 2), en `office_rooms_capture.gd:35-36`.
- **Ocho tomas del plano real** (`office_plan_capture.gd`): anillo, despacho, galería, recepción, nave, aseos, archivo y dirección.
- **Ángulos por tipo**: cinco por cada tipo de sala presente en el piso, más la llegada y dos a oscuras con linterna (`office_angles_capture.gd:219-261`).
- **Semilla 29**: `office_capture.gd:9` y `:164-166` dicen que la semilla 29 acristala el puesto de seguridad. El script usa la semilla que se le pasa (por defecto 7), así que para verlo hace falta `--seed=29`. No comprobado que la 7 no lo tenga.

### 4.3 Qué se compara con qué

- Piso 2: `office_rooms_capture` compara cada sala con su foto. Las vistas del plano real (`office_plan_capture`) y de los ángulos (`office_angles_capture`) no tienen referencia: se miran a ojo.
- Piso 1: no hay ninguna referencia en el repo. Las tomas de `lookdev_capture` se comparan entre ellas con `lookdev_sheet.gd`. Su cabecera (líneas 2-4) dice que cada hito se pone al lado del anterior y de las referencias de `docs/REALISM.md` (ese documento no se leyó).

---

## 5. Referencias del autor

### 5.1 Las quince fotos que hay en el repo

Todas están en `docs/referencias/` y son JPEG. Su nombre trae la sala. La tabla dice a qué sala de `office_rooms_capture.gd` (`ROOMS`, líneas 18-37) corresponde cada una, con el tipo de sala del código (`office_palette.gd:107-135`, nombres en `NAMES`, línea 173).

| Archivo | Sala del script (etiqueta) | Tipos de sala (número) | Nombre en `NAMES` |
|---|---|---|---|
| `recepción.jpeg` | recepcion (línea 19) | 0 | Recepción interna |
| `ventanilla de personal.jpeg` | ventanilla (20) | 17 | Ventanilla de Personal |
| `correo.jpeg` | correo (21) | 14 | Correo |
| `archivo.jpeg` | archivo (22) | 6 y 13 | Archivo y Archivo móvil |
| `reprografía y microfichas.jpeg` | reprografia (23) | 7 | Reprografía y microfichas |
| `despacho.jpeg` | despacho (24) | 3 | Despacho |
| `despacho de dirección.jpeg` | direccion (25) | 16 | Despacho de dirección |
| `secretaría.jpeg` | secretaria (26) | 24 | Secretaría |
| `sala de juntas.jpeg` | juntas (27) | 5 | Sala de juntas |
| `sala de descanso.jpeg` | descanso (28) | 15 | Sala de descanso |
| `sala de aseos.jpeg` | aseos (29) | 4 | Aseos y vestuario |
| `puesto de seguridad.jpeg` | seguridad (30) | 21 | Puesto de seguridad |
| `cuarto eléctrico.jpeg` | electrico (31) | 18 | Cuarto eléctrico |
| `sala de climatización.jpeg` | climatizacion (32) | 23 y 22 | Climatizadora y Sala de climatización |
| `salida montacargas.jpeg` | montacargas (33) | 19 y 10 | Vestíbulo del montacargas y Vestíbulo de llegada |

Sin foto, en el mismo script: `nave` (tipo 1, Oficina abierta) y `cubiculos` (tipo 2, Cubículos), líneas 34-36.

Tres salas se miran además desde la sala de al lado (`THROUGH`, línea 39): `seguridad`, `secretaria` y `montacargas`.

Dimensiones de las fotos: no medidas (PIL no estaba disponible con `python -I`).

### 5.2 Lo que dice el LEEME

`docs/referencias/oficinas/LEEME.md` es el único texto del repo que describe las referencias. Hechos:

- Las tres fotos de la oficina abierta que el autor mandó por el chat (25 de octubre de 2026) **no están en el repo**. El LEEME dice que irán como `referencia_1.jpg`, `referencia_2.jpg` y `referencia_3.jpg` cuando el autor las copie. Búsqueda en `docs/referencias/`: no existen.
- Descripción de las tres por el chat (resumen de lo que dice el LEEME, no del contenido de la imagen):
  - Referencia 1: nave muy larga y ancha, pasillo central de unos 3 m, columnas de yeso crema cada pocos metros, falso techo con regletas a 2,8-3 m, moqueta granate, mamparas grises, archivadores beige, monitores CRT, una garrafa de agua azul.
  - Referencia 2: oficina de los noventa, escritorios en L de laminado claro, sillas azules o negras, monitores CRT, impresoras, desorden de papeles, luz ámbar.
  - Referencia 3: oficina de los ochenta con ventanales y persianas venecianas, despacho de vidrio con marco oscuro, moqueta gris verdosa, escritorios de esquina de laminado beige, terminales de texto verde, luz de tarde fría contra la cálida de los fluorescentes.
- Lista de lo que «se espera encontrar» en esa estética: columnas, mamparas, falsos techos, persianas, despachos de vidrio, puertas de vidrio esmerilado, escritorios, sillas, CRT, teléfonos de cable, archivadores, dispensador de agua, máquina de café, pizarra, tablón de corcho, plantas, fotocopiadora, relojes, extintores, pulsadores de alarma, papeles caídos.
- Lo que dijo el autor, en el LEEME: el piso «parece un hospital», «un hotel blanco y muy poco pulido», pasillos angostos y poca variedad; muchos props se ven mal porque no tienen un modelo 3D adecuado; hay que buscar modelos «en páginas diversas», no copiar las imágenes.
- Licencias que pide el LEEME: CC0 o CC BY, nunca NC, ND ni SA, y sin crear cuentas ni escribir contraseñas (`OFICINAS 12`).

### 5.3 Lo que faltaba según el LEEME y lo que hace el script

El LEEME dice que faltan la oficina abierta, los cubículos, el archivo móvil, el almacén, el depósito, los pasillos y el vestíbulo del montacargas. Pero el script asigna `archivo.jpeg` también a los tipos 6 y 13 (archivo y archivo móvil, `office_rooms_capture.gd:22`), y `salida montacargas.jpeg` a los tipos 19 y 10 (vestíbulo del montacargas y vestíbulo de llegada, línea 33). El LEEME nombra la salida como «salida del montacargas» y el archivo se llama «salida montacargas». Hay discrepancia (sección 13).

### 5.4 Capturas del autor de 12 de noviembre

- `evidence/autor_12nov/`: seis WebP (`1.webp` a `6.webp`), unos 0,9 MB en total, fecha 12 de noviembre de 2026.
- `evidence/autor_12nov_b/`: veinte archivos (`f01.webp` a `f20.webp`, salvo `f13.png`), 1,8 MB en total, fecha 12 de noviembre de 2026.
- Lo que dice `.claude/relevo.md:37` sobre esas capturas (cita de la nota de relevo, sin ver las imágenes): el tono es amarillo verdoso y el autor quiere anaranjado sutil como las referencias; hay reflejos de suelo mojado con esferas blancas; hay z-fighting en suelo y mesas; el ambiente está vacío; lo hecho a mano se ve mal (las puertas).
- Memoria del proyecto citada en `MEMORY.md`: «La vara visual: una foto de la época» (`visual-bar-real-photo.md`). Dice que se juzga en la vista de juego junto a la referencia, que lo hecho a mano que parezca 3D se cambia por modelos reales, y que el permiso de descarga es coherente con 1987.

### 5.5 Carpeta `evidence/rediseno/`

- 353 entradas en la raíz y 5,5 GB en total.
- Hojas en la raíz: `4b_final_sheet.png`, `4b_sheet.png`, `4b_r3_sheet.png`, `4b_fix2_probe_sheet*.png`, `4d_sheet.png`, `5_sheet.png`, `piezas.png` y `piezas.json`, `piezas_giro.png`, `nave_columna_*.png`, `nave_pasillo_*.png`, y decenas de `probe_*.png`.
- Carpetas de pases con `cifras.json` (mismo formato que `office_rooms_capture`): `antes`, `antes_muybajo`, `antes3b_alto`, `antes3b_muybajo`, `3b_alto`, `3b_medio`, `3b_muybajo`, `4b`, `4b_fix`, `4c`, `4c_b`, `4c_muybajo`, `4d`, `4e`, `4e_21`, `4e_b`, `4e_b_21`, `5`, `final`, `final_muybajo`, `iter2`, `iter3`, `lit_check`, `luz1` a `luz7a`, `mod1`, `mod2`, `dens1` a `dens6b`, `piezas2`, `relleno_alto`, `relleno_alto2`, `sk1`, `vg0`.
- Carpetas con `indice.json` (de `office_angles_capture`): `rev1`, `rev2`, `rev3`, `rev4`, `vuelta_antes_s101`, `vuelta_antes_s33`, `vuelta_compat_retest`, `vuelta_compat_s7`, `vuelta_despues_s33`, `vuelta_despues_s7`, `vuelta_final_s101`, `vuelta_final_s33`, `vuelta_final_s7`, `vuelta_final_salas`, `vuelta_it1_s7`, `vuelta_puertas_s7`, `vuelta_reflejos_alto`, `vuelta_reflejos_compat`, `vuelta_reflejos_ultra`.
- Carpetas `rev5` a `rev13`: sin `cifras.json` ni `indice.json`; contienen PNG.
- Carpeta `recepcion`: 159 archivos sin PNG (no se miró qué son).
- `planta/capturas/`: solo tres PNG (`1_anillo.png`, `1_despacho.png`, `1_galeria.png`), de una corrida con semilla 1 (no 7). Faltan recepción, nave, aseos, archivo y dirección.
- No se abrió ninguna imagen de `evidence/rediseno/`.

---

## 6. Escritura de salidas y convenciones

- Todas las salidas van a `res://evidence/...`, es decir, a la carpeta `evidence/` del proyecto. No se versionan los binarios de `evidence/rediseno/` (5,5 GB).
- Formato: PNG para casi todo; JPG con calidad 0,88 en `lurker_office_look.gd:151` y calidad 90 de PIL en `ingest_models.py` (líneas 292, 313 y 328); AVI para las películas (`walkthrough_movie.gd` y `bench-films`); JSON para `cifras.json`, `indice.json`, `notas_index.json`, `cat_index.json` y `piezas.json`.
- Nombres: `<prefijo>_<nombre>.png`, `<etiqueta>_q<calidad>/<toma>_raw.png` y `_vhs.png`.
- Modo «crudo» frente a modo «como se juega»: `lookdev_capture.gd:165-178` oculta `Presentation/Analog/Screen`, `Presentation/Lens` y `Presentation/Camcorder` para el crudo y los vuelve a mostrar para el «vhs»; `office_rooms_capture.gd:107-137` hace lo mismo con `grab(clean)` y además oculta el HUD (`level.ui.visible`).

---

## 7. Cadena de ingesta de modelos

### 7.1 Entrada

- **Descargas de Poly Haven** en `source_assets/props/<id>/` (fuera de git): un glTF, sus texturas y `info.json`. Las baja `fetch_models.py` desde `https://api.polyhaven.com` (línea 20), a 1k por defecto y a 2k con `--2k` (líneas 8 y 55), con comprobación de md5 (línea 30).
- **Descargas de Sketchfab y otros** en `source_assets/oficinas/<grupo>/<slug>/` con su `registro.json`, grupos `muebles_a`, `muebles_b`, `equipos`, `carpinteria`, `muebles_c`, `objetos` (`ingest_models.py:49`), y las de Poly Haven en `source_assets/props/<slug>/` con `registro_polyhaven_modelos.json`. Las entrega `register_sketchfab.py`: mueve el zip, lo desempaqueta en `_zip/` (sin rutas absolutas ni `..`), y escribe la licencia y el crédito en `registro.json`. Rechaza NC, ND y SA (cabecera de `register_sketchfab.py`).
- **Descargas de `ingest_camcorder.py`**: `models/*.zip` (un OBJ con dos materiales y un DAE de la cinta) a `source_assets/<nombre>/`.
- **Blender** (`decimate.py`, `fit_model.py`, `cloth_pieces.py`) convierte o decima a glTF en `_gltf/` de cada descarga.

### 7.2 Pasos y qué transforma cada uno

1. **`decimate.py`** (Blender, `-b --factory-startup`): lee GLB, glTF, FBX u OBJ (`load()`, líneas 48-58). Con `--tris N` escala todas las mallas con la misma proporción (`ratio = budget / before`, línea 119) y usa el modificador de colapso (`shrink()`, 66-92). Limpia las caras degeneradas con distancia 1e-6 (línea 85) y los vértices duplicados (línea 86). `--weld` une vértices a 1e-5 antes de colapsar (línea 98). `--drop <regex>` quita los objetos que coincidan. Exporta `GLTF_SEPARATE` (línea 125). Presupuesto documentado: piezas pequeñas bajo 5 000 triángulos y grandes bajo 20 000 (cabecera líneas 3-4). Con `--tris 0` solo convierte.
2. **`fit_model.py`** (Blender) y **`fit_models.json`** (60 entradas): ajusta una descarga a las cajas del juego (estirar, espejar, repetir, poner en varias cajas). Solo se leyó la cabecera (sección 14).
3. **`ingest_models.py`** (Python con `-E -P`): recorre `source_assets/props/`, salta los nombres de `SKIP` (líneas 65-81) y lo que tenga licencia NC, ND o SA (`BANNED`, línea 54). Por modelo escribe:
   - **Texturas** (`copy_image`, líneas 276-296): pinta encima de los rectángulos de `PATCHES` (líneas 122-187: rótulos, logos, textos en inglés), aplica `TINT` (192-213) multiplicando por un color, redimensiona a `MAX_SIZE` = 1024 (línea 60), o a 2048 para los de `KEEP_2K` (línea 215). Guarda PNG si hay alfa y JPG a calidad 90 si no.
   - **`.import`** de cada textura (plantilla `IMPORT`, líneas 217-243): `compress/mode=2` (VRAM), `lossy_quality=0.7`, mipmaps generados, normal map según el caso.
   - **Máscara de brillo** (`glow_mask`, 299-317): píxeles pálidos (todos los canales mayores de 140) sin color (diferencia menor de 45), desenfocados 1,5 px.
   - **Rugosidad desde brillo** (`rough_from_gloss`, 320-332) para materiales de especular-brillo.
   - **Materiales `.tres`** (`material_tres`, 335-427): `ORMMaterial3D` si la misma imagen trae oclusión y rugosidad y metal; si no, `StandardMaterial3D`. Ajustes por modelo: `LEAST_ROUGH` (107), `SRGB_FACTOR` (112), `COLOUR_OF` (115), `NO_HIGHLIGHT` (99, `specular_mode = 2`), `CLEAR_GLASS` (101, alfa 0,3 en el vidrio), `GLASS_WORDS` (104), `EMISSION` (87), `GLOW_WHITE` (91).
   - **Registro**: bloque `MODELS` de `docs/ASSETS.md` (línea 149), bloque `OFFICE_MODELS` (línea 276) y `assets/props/office/sources.json` (línea 52).
   - **Créditos**: cualquier licencia que no empiece por CC0 imprime `CREDIT` (línea 571).
   - **Destinos**: `assets/props/hotel/<id>/` y `assets/props/office/<slug>/`.
4. **`build_catalogue.gd`** (Godot, `--headless`): hornea cada glTF en un único `.res` con una superficie por material, a tamaño real, suelo en y=0, centrado en X y Z, frente hacia +Z y LOD automático (cabecera líneas 1-18). Tablas por modelo: `YAW` (línea 23), `SCALE` (25), `PARTS` (36), `PLACED` (73), `CLOCKS` (82), `MOVING` (101), `SHUT` (114), `LAID` (122), `ASKEW = 0.06` (124). Escribe `assets/props/hotel/<id>.res` y `assets/props/office/<slug>.res`. Sin comprobar el cuerpo de sus 555 líneas.
5. **`add_mesh_lods.gd`** (Godot): añade niveles de detalle a `wall_lamp`, `monstera` y `sofa` con `ImporterMesh.generate_lods(60.0, 25.0, [])` (línea 28). Comprueba que las superficies, los materiales y la caja no cambian; si cambian, no guarda (líneas 31-39). Puerta y marco quedan fuera (cabecera 6-8).
6. **`build_model_props.gd`** (Godot): cinco trabajos con tamaño y ancla: televisor (`TV_body_low`, `TV_screen_low`, 0,62 m a lo largo), cama (2,1 m en z), sofá (2,15 m en x), apliques (0,42 m en y, ancla de pared), monstera (1,35 m en y). Líneas 12-16.
7. **Piezas a medida** (Godot, `--headless`):
   - `build_door.gd`: hoja y marco de la puerta (`door_leaf.res`, `door_frame.res`) ajustados a la abertura del juego, `OPENING_HIGH = 2.65` (línea 18), `CRACK = 0.012` (21).
   - `build_wardrobe.gd`: armario de 1,25 × 2,3 × 0,78 m (`SIZE`, línea 12), dos hojas con bisagra y una rendija de 5 mm (`SLIT`, línea 22). Partes de las puertas en `DOOR_PARTS` (línea 10).
   - `build_elevator.gd`: cabina y puertas del ascensor con `LIFT_SCALE = 0.8` (línea 22), origen en `ORIGIN` (25) y ranuras de material en `SLOTS` (26). Escribe `lift_car.res`, `lift_door_a.res`, `lift_door_b.res`, `lift_call.res`, `lift_screen.res`.
   - `build_camcorder.gd`: videocámara de 0,27 m (`CAMCORDER_LENGTH`, línea 15) y cinta de 0,187 m (`TAPE_LENGTH`, 17). Escribe `assets/props/camcorder/camcorder.res` y `assets/props/vhs_tape/vhs_tape.res`.
   - `bake_key.gd`: llave de 0,075 m (`LENGTH`, línea 16) de `source_assets/props/key_chain/KeyChain.FBX`, a `assets/props/hotel/key_chain.res`.
   - `prepare_key_textures.py`: mapas de la llave a 512 px, con oclusión, rugosidad y metal empaquetadas en R, G y B.
   - `cloth_pieces.py` (Blender): toalla y abrigo simulados, en `source_assets/oficinas/tela/<slug>/_gltf/`. Las texturas son del proyecto, CC0.
8. **`catalogue_sheet.gd`** (Godot, con ventana): hoja de todos los modelos de `assets/props/hotel/` desde el frente (+Z), a 256 px por celda, 8 columnas. Comprueba frentes y tamaños. Salida `evidence/catalogue_sheet.png` (y `_office.png` con `--target=`).
9. **`check_ingest_models.py`** (Python): comprueba que los `.tres` y el bloque `MODELS` salen byte a byte iguales, y prueba con archivos sintéticos los casos de especular-brillo y de zip.
10. **`tools/import/strip_blend_shapes.gd`** (`@tool`, `EditorScenePostImport`): quita las formas de mezcla de los modelos de personaje (585 en uno y 154 en otro, cabecera 5-9) y reconstruye cada superficie sin sus deltas. Quita también las pistas de tipo `TYPE_BLEND_SHAPE` de los clips (líneas 28-39). Se engancha desde el `.import` del modelo con `import_script/path`. `tests/hotel/scene_contract_test.gd:329` comprueba ese enganche.

### 7.3 Lo que se escribe, resumen

- `assets/props/hotel/<id>/` (texturas y `.tres`), `assets/props/hotel/<id>.res` (mallas horneadas).
- `assets/props/office/<slug>/` y `assets/props/office/<slug>.res`, más `assets/props/office/sources.json`.
- `assets/props/door/`, `wardrobe/`, `elevator/`, `camcorder/`, `vhs_tape/`, `hotel/key_chain.res`.
- `docs/ASSETS.md`: bloques `MODELS` (línea 149) y `OFFICE_MODELS` (línea 276), que genera la ingesta.

### 7.4 Licencias del pipeline

- La ingesta de oficinas salta NC, ND y SA (`ingest_models.py:54`, `:560`). La de hotel no lo comprueba, pero su bloque de `docs/ASSETS.md` dice «Poly Haven, CC0» (línea 460).
- El modelo de The Locust (`assets/enemies/lurker/lurker.glb`) no entra por esta cadena. Está registrado como **CC BY-NC-ND 4.0** en `docs/ASSETS.md:110` (dice que prohíbe el uso comercial y que mientras siga en el juego no se puede vender) y en `docs/ASSETS.md:433` (comprobado por última vez el 19 de octubre de 2026 en la API de Sketchfab).
- `docs/TRAILER.md:63` repite la misma licencia para el tráiler y dice «permisos de distribución pendientes».

---

## 8. Tráiler (`tools/trailer3d/`, `docs/TRAILER.md`)

- **Qué es**: un tráiler de 65 s generado con Three.js y Chromium sin ventana (Playwright, GPU por ANGLE y D3D11). No se filma en el motor (`docs/TRAILER.md:5`).
- **Versiones**: `three` 0.186.1 y `kokoro-js` 1.2.1 (`package.json`). La voz es Kokoro-82M (Apache-2.0).
- **Salida**: máster de 1920×1080 a 30 fps, H.264 CRF 14, AAC 320 kb/s (`docs/TRAILER.md:7`), en `evidence/trailer3d/`, sin versionar.
- **Guion**: `tools/trailer3d/timeline.json` tiene 17 líneas con la clave `module` (conteo sin revisar el contenido).
- **Cómo replica el juego**: medidas del juego (muros de 0,18 m, puertas de 1,30 × 2,65 m, techos de 3,15 y 4,2 m; `docs/TRAILER.md:47`), materiales portados a `MeshStandardMaterial` con los ajustes de sus `.tres`, y el shader del tubo de las teles (`web/engine/screens.js`). La criatura es el GLB del juego, posada con un port de `locust_poser.gd` y `locust_visual.gd` (`web/engine/locust.js`, `docs/TRAILER.md:48`).
- **Por qué existe**: `docs/TRAILER.md:5` dice que Godot no da la imagen que se quiere.
- **Archivos**: `server.mjs` sirve la página y POST `/save` escribe en `evidence/trailer3d/`. `render.mjs` dibuja fotogramas; `encode.py` los une con la mezcla.

---

## 9. Constantes y cifras que definen cómo se ve (ruta:línea)

### 9.1 Encuadre y cámara (piso 2)

- `tools/capture/room_framing.gd:11` `EYE = 1.5` (altura de ojo en la puerta, metros).
- `room_framing.gd:12` `OUT = 0.2` (metros de retroceso desde la puerta).
- `room_framing.gd:13` `AIM = 1.5` (altura a la que se mira).
- `room_framing.gd:14` `FOV = 55.0` (campo horizontal).
- `room_framing.gd:17` `ASIDE = 0.9` (coseno: pared de rasgo más de 25° de lado se encuadra desde dentro).
- `room_framing.gd:18` `INSIDE = 1.2` (metros dentro de la sala en ese caso).
- `room_framing.gd:22` `ACROSS_OFF = 1.2` (cuando la pared de rasgo es la de la puerta, se encuadra desde el otro lado).
- `office_angles_capture.gd:19` `SEATED = 1.15`; `:20` `STANDING = 1.6`; `:23` `PAST_DOOR = 0.5`; `:24` `EYE_ROOM = 0.22` (radio de la esfera libre alrededor del ojo); `:55-56` paso de 0,25 m y nueve pasos para despejar el ojo.
- `office_angles_capture.gd:139` techo: mira a `room.height + 0,6` al fondo de la sala. `:141` suelo: rasante a 0,35 m hacia el fondo.
- `office_pieces_sheet.gd:43` campo de 35°; `:68` cámara a `(0,45; 0,35; 1,0)` normalizado por `radius * 3,3`; `:49` albedo del suelo `(0,3; 0,29; 0,27)`; `:31` luz ambiental 0,6; `:35` sol `rotation (-0,8; 0,5; 0)`; `:39-40` relleno con energía 0,35.
- `office_plan_capture.gd:13` `DOWN = 20.0` (alcance de la mirada por el pasillo).
- `office_plan_capture.gd:69` oficina de 3,6 m: `min(span) < 3.7`.
- `office_capture.gd:41-43` lámpara de apoyo para `lit_shot`: alcance 14, energía 1,2, atenuación 0,6.

### 9.2 Ventanas y calidades

- Ventanas: `office_rooms_capture.gd:312` 1200×800; `office_angles_capture.gd:211` 1280×800; `office_plan_capture.gd:57` 1200×800; `office_capture.gd:51` 1280×720; `lookdev_capture.gd:29` 1920×1080; `lurker_capture.gd:21` 1920×1080 y `:22` 960×540 para `--walk`; `upscale_capture.gd` 1280×720.
- Calidades (`graphics_presets.gd:20`): `NAMES = ["Bajo", "Medio", "Alto", "Ultra", "Muy bajo"]`. `:21-24` `LOW = 0`, `MEDIUM = 1`, `HIGH = 2`, `ULTRA = 3`. Por tanto calidad 4 es Muy bajo (`office_capture.gd:13`).

### 9.3 Criterios de `office_rooms_capture.gd` (la comparación con las fotos)

- `:42` `BANDS`: techo `(0; 0,15)`, pared `(0,35; 0,55)`, suelo `(0,85; 1,0)`, en fracciones de la imagen.
- `:43` `COLUMNS = (0,2; 0,8)`: columnas centrales que se muestrean (criterio b).
- `:45` `SMALL = (64, 43)`: tamaño al que se reducen las dos imágenes antes de comparar (criterio a). Se desenfocan con dos pasadas de media 3×3 (`blurred()`, 217-240).
- `:49` `STRUCTURE_MIN = 0.6`: correlación mínima entre las dos imágenes reducidas (criterio a, `structure()` 242-262).
- `:50` `LUMA_SHARE = 0.25`: diferencia relativa de luma de una banda para el criterio b.
- `:51` `HUE_MAX = 20.0`: diferencia de tono en grados (criterio b).
- `:54` `DARK_LUMA = 0.02`: si las tres bandas están por debajo, la imagen es oscura sin importar el estado de la sala.
- Línea 47-48: «Las cifras se escriben de cualquier modo; no se bloquea nada».
- Criterio de «techo visto»: `depth + OUT >= reach(...)` (líneas 347-348). `reach()` (207-212) calcula desde qué distancia la banda del techo o del suelo llena el campo vertical.

### 9.4 Luz y color de las capturas

- `lookdev_capture.gd:111` `camera.rotation.x = -0.12` (inclinación de la cámara en la toma).
- `lookdev_capture.gd:106-107` punto de vista: 10 % del ancho y 50 % del fondo; mira a -30 % del ancho y al fondo.
- `lookdev_capture.gd:40` calidad por defecto `PRESETS.HIGH` (2).
- `lurker_test.gd:208-210` tonemap `TONE_MAPPER_LINEAR`, exposición 1,0, umbral de brillo 0,9 (`glow_hdr_threshold`).
- `lurker_test.gd:161-171` luz de cada lámpara: `light_color (1; 0,84; 0,62)`, energía 1,4, alcance 5, atenuación 1,6, `shadow_bias` 0,03, `shadow_normal_bias` 0,6, `light_size` 0,06.
- Geometría y constantes de movimiento de la criatura: `lurker_test.gd:30-57` (ver también 9.6).
- `tools/lighting/measure_albedo.gd:13-14` `PATCH = 3.0` m y `PIXELS = 128`; `:28-31` luz ambiental blanca de energía 1,0, sin reflejo y tonemap lineal; `:45` escala del cubo `PATCH * 1,2` por `PATCH * 1,2` por 0,2.
- Motivo de `measure_albedo.gd` (líneas 4-6): el horneado de VoxelGI solo lee el color de los materiales estándar, y los del hotel son shaders, así que los toma por blancos.

### 9.5 Materiales y modelos

- `tools/props/ingest_models.py:60` `MAX_SIZE = 1024`; `:215` `KEEP_2K` (15 modelos a 2048).
- `ingest_models.py:228-242` plantilla `IMPORT`: `compress/mode=2`, `lossy_quality=0.7`, `hdr_compression=1`, `mipmaps/generate=true`.
- `ingest_models.py:305-306` máscara de brillo: pálido si todos los canales superan 140; sin color si la diferencia es menor de 45. `:308` desenfoque de 1,5.
- `ingest_models.py:372` `CLEAR_GLASS`: alfa 0,3 en el vidrio que llega con alfa 1.
- `ingest_models.py:107` `LEAST_ROUGH = {"lavabo_juang3d": 0.2}`.
- `ingest_models.py:115` `COLOUR_OF`: el lavabo en porcelana blanca (14 de noviembre de 2026, según el comentario de la línea 114).
- `add_mesh_lods.gd:28` `generate_lods(60.0, 25.0, [])`.
- `decimate.py:26` `tris` por defecto 0 (solo convierte); `:119` proporción de decimado igual para todas las mallas.
- `build_door.gd:18` `OPENING_HIGH = 2.65`; `:21` `CRACK = 0.012`.
- `build_wardrobe.gd:12` `SIZE = (1,25; 2,3; 0,78)`; `:22` `SLIT = 0.005`; `:27` `HARDWARE_BEHIND = 0.07`; `:43` `BOARD_BEHIND = 0.003`.
- `build_elevator.gd:22` `LIFT_SCALE = 0.8`; `:25` `ORIGIN = (0,023; -0,02; 1,17)`.
- `build_camcorder.gd:15` `CAMCORDER_LENGTH = 0.27`; `:17` `TAPE_LENGTH = 0.187`.
- `bake_key.gd:16` `LENGTH = 0.075`.
- `build_catalogue.gd:124` `ASKEW = 0.06`.

### 9.6 Criatura, piso de pruebas

- `lurker_test.gd:30` `WIDTH = 1.9`; `:31` `HEIGHT = 2.5`; `:32` `LENGTH = 22`; `:34` lámparas en `-1,5; -8; -15,5`; `:35` `FLICKERING = 1`.
- `lurker_test.gd:37` `BEND = 0.45` (radio de las esquinas); `:41` `SUSPEND = 0.5`.
- `lurker_test.gd:44-49` `CRAWL = 1.0`, `SCURRY = 1.8`, `ACCEL = 5.0` (m/s²), `ROUND = 0.7`.
- `lurker_test.gd:51-57` `STARE_AT = 3.0`, `TOO_NEAR = 2.0`, `CAUGHT = 0.35` s, `CLOSING = 3.5`, `FACE_HEIGHT = 1.45`.
- `lurker_office_look.gd:15-17` `SEEN_PACE = 1.35`, `FLEE_PACE = 3.5`, `EYE = 1.6`.
- `lurker_arena.gd:9-10` semilla 7 y dificultad «equilibrada».

### 9.7 Medidas de calidad fijadas en código

- `ghosting_capture.gd:11-13` (medido con semilla 81 a 0,6; niveles 0 a 255, menor es más cercano al real): suelo 0,45; TAA a resolución completa 6,66; estiramiento simple 6,20; FSR 1.0 5,66; FSR 2.2 1,86.
- `docs/TRAILER.md:7` máster 1920×1080 a 30 fps, H.264 CRF 14, AAC 320 kb/s, sonido a -14 LUFS.

---

## 10. Dependencias de orden de ejecución, física, azar y tiempo

### 10.1 Azar

- Semillas fijas en todas las herramientas (sección 3). Los scripts no usan `randomize()`; el azar del juego sale del generador por semilla (lo que hace el generador no se revisó).
- `lurker_test.gd:87` `RandomNumberGenerator`, `:91` `rng.seed = 2610`. Usado en `pick_spot()` (274-277), `on_wall()`, `go()` (360-372) y el parpadeo de la lámpara (310-311). Es la única fuente de azar propia del banco.
- `lurker_test.gd:104` `camcorder.start_tape(81)`: la cinta de la videocámara tiene semilla 81.

### 10.2 Tiempo de pared (reloj, no fotogramas)

Estas esperas dependen de cuántos fotogramas da la máquina:

- `boot_capture.gd:16-17` (`Time.get_ticks_msec` por segundos).
- `transit_capture.gd:25-26` (por segundos, para la animación del aviso).
- `lookdev_capture.gd:158-159` (1500 ms para que converja el TAA y la sombra).
- `lurker_capture.gd:313-314` (1500 ms).
- `office_angles_capture.gd:75-76` (`settle_ms` por defecto 1200 ms, línea 69).
- `office_rooms_capture.gd:131-132` (1500 ms).

Las demás esperan un número fijo de fotogramas (`process_frame`). Ejemplos: `office_capture.gd:31` 40 fotogramas, `lookdev_capture.gd:169` y `:176` 3 fotogramas.

### 10.3 Física

- Muchas herramientas paran la física del jugador y de la criatura: `player.set_physics_process(false)` y `locust.set_physics_process(false)` (por ejemplo `catalog_capture.gd:40` y `:94`, `darkness_capture.gd:51-53`, `lookdev_capture.gd:66-68`, `office_rooms_capture` mediante `level.player.set_physics_process(false)` en 316).
- Las que esperan `physics_frame` (no `process_frame`): `echo_capture.gd:58-66`, `darkness_capture.gd:66` y `:92`, `lurker_capture.gd:121` y `:218`, `catalog_capture.gd:57`, `hint_capture.gd:68`.
- Las consultas de rayos y esferas se hacen contra el espacio de física en el momento de la captura: `office_angles_capture.gd:41-48` (`intersect_shape` con esfera de radio 0,22), `lurker_office_look.gd:327-334` (`intersect_ray`), `lurker_test.gd:396-398` (`intersect_ray` para la linterna).

### 10.4 Congelar el parpadeo y el humo

- `flicker_clock = 0.4`, `hotel._process(0.0)` y `hotel.set_process(false)` para que el parpadeo de la baliza y de los tubos no cambie la imagen (`lookdev_capture.gd:154-156`, `office_rooms_capture.gd:111-113`, `office_angles_capture.gd:71-72`). Se desbloquea después (`lookdev_capture.gd:179`, `office_rooms_capture.gd:412-413`).
- `level.creature_scene = "none"` o `level.locust.position = Vector3(0, -80, 0)` para sacar a la criatura de la escena (`office_rooms_capture.gd:306`, `office_plan_capture.gd:31`, `lookdev_capture.gd:69`).

### 10.5 Rebote de luz (hilos)

- `level.bounce_ready()` espera a que el horneado de rebote termine (`lookdev_capture.gd:63`, `office_rooms_capture.gd:116` y `:309`, `office_angles_capture.gd:73` y `:210`). Lookdev dice: «Presets with bounce light bake it now, on worker threads.» (línea 62).
- `office_rooms_capture.gd:97-103` `bake_bounce()`: sólo con preset que tenga `bounce` (Alto y Ultra), libera y rehace el rebote con `hotel.bounce.release(-1)` y `start_bounce()`.

### 10.6 Bucles de tiempo fijo

- `--fixed-fps 30` en `lurker_office_look.gd` (cabecera 10), `lurker_test_check.gd` (13), `walkthrough_movie.gd` (cabecera), `lurker_capture.gd` para `--walk` y `--passage` (10 y 15).
- `--fixed-fps 60` en `ghosting_capture.gd` (16) y en el `bench-films` de `godot.ps1` (línea 125).
- `lurker_test.gd:303-313` `_process(delta)`: la criatura se mueve por `delta`. Sin `--fixed-fps` el resultado depende de la máquina.

### 10.7 Forzar estados

- `lurker_office_look.gd:46-48` `lurker.thinking = false`, `grace = 0.0`.
- `lurker_office_look.gd:348-354` `brain.spurned.erase(seat)`, `sated_until = -INF`, `drunk.clear()` y `brain.force(&"stalk", {...})`.
- `continue_capture.gd:24-30` fuerza `session.stage = 2`, `last_stage = 2` y emite `session.changed`.

### 10.8 Lo que vale la semilla de piso y no el reloj

- Las herramientas de oficinas tienen un orden fijo: primero la sala sin luz, después la luz (`light_all()`, `office_rooms_capture.gd:80-92`), después el rebote (`bake_bounce`), y solo después la captura.
- `office_plan_capture.gd:37-56`: si el manifiesto dice `fallback` (piso de reserva), dibuja el plano real con el generador. Sale con código 1 solo si el generador también da reserva (líneas 41-44).

---

## 11. Clases y nodos del motor Godot que usa esta parte

Número aproximado de apariciones en `tools/capture/`, `tools/workbenches/`, `tools/lighting/`, `tools/editor/`, `tools/import/` y `tools/props/` (todos los `.gd`; conteo por `grep`, sin distinguir por carpeta). Cuenta también los comentarios, así que es una cota.

| Clase o tipo | Apariciones | Dónde se usa, sobre todo |
|---|---|---|
| `Vector3` | 880 | En todas las cámaras y puntos |
| `Transform3D` | 81 | Props, lift, puerta, armario, criatura |
| `Mesh` | 76 | Construcción de mallas y LOD |
| `RenderingServer` | 66 | `frame_post_draw`, dispositivo de render |
| `SceneTree` | 63 | Base de casi todas las herramientas (`extends SceneTree`) |
| `Basis` | 63 | Orientación de cámaras y puertas |
| `DisplayServer` | 59 | Tamaño de ventana, posición, foco, pantallas |
| `Image` | 54 | `get_image()`, `save_png`, `save_jpg`, `resize`, `blit_rect`, `get_pixel` |
| `Node3D` | 44 | Contenedores |
| `Color` | 41 | Colores de luz y de fondo |
| `OS` | 40 | `get_cmdline_user_args()` para los argumentos |
| `MeshInstance3D` | 39 | Mallas de prueba |
| `AABB` | 37 | Cajas de mallas y de salas |
| `SurfaceTool` | 29 | Mallas de `add_mesh_lods.gd` y `build_*` |
| `Environment` | 29 | Entorno de la escena de prueba |
| `Input` | 28 | Ratón y teclado |
| `Camera3D` | 23 | Cámaras (`keep_aspect`, `fov`, `look_at`) |
| `ResourceSaver` | 16 | Escribe `.res` y `.tscn` |
| `ProjectSettings` | 15 | Rutas globales |
| `DirAccess` | 15 | Crea carpetas |
| `FileAccess` | 14 | Escribe `cifras.json`, `indice.json`, `piezas.json` |
| `Viewport` | 12 | Ventanas |
| `WorldEnvironment` | 11 | Entorno |
| `OmniLight3D` | 11 | Luces de apoyo |
| `SubViewport` | 10 | Hojas y muestras (`office_pieces_sheet`, `lookdev_sheet`) |
| `Node` | 10 | Base |
| `ArrayMesh` | 9 | Mallas horneadas |
| `CanvasLayer` | 8 | Capas de la presentación (lente, cinta, OSD) |
| `StandardMaterial3D` | 7 | Materiales de prueba |
| `PhysicsRayQueryParameters3D` | 6 | Rayos de visibilidad y de linterna |
| `InputMap` | 6 | Acciones de teclado en el banco |
| `DirectionalLight3D` | 6 | Sol de las hojas |
| `BoxMesh` | 6 | Suelos y muros de prueba |
| `Skeleton3D` | 5 | Huesos de la criatura (`Head1`) |
| `Label` | 5 | Rótulos de hojas y del banco |
| `InputEventKey` | 5 | Teclas del banco |
| `AnimationPlayer` | 5 | Clips de la criatura |
| `StaticBody3D`, `CollisionShape3D`, `BoxShape3D` | 4, 3, 3 | Suelo y pared de prueba |
| `ResourceLoader` | 4 | Carga de escenas |
| `PlaneMesh` | 4 | Suelos de prueba |
| `ImporterMesh` | 4 | `generate_lods` |
| `Animation` | 4 | Pistas de forma de mezcla (`strip_blend_shapes.gd`) |
| `BaseMaterial3D` | 3 | Materiales de importación |
| `Area3D` | 3 | `build_gallery.gd:13` y otros sin desglosar |
| `TextureRect` | 2 | Fondo de hojas |
| `ShaderMaterial` | 2 | Material de la lente (`lurker_test.gd:212-215`) |
| `ParticleProcessMaterial` | 2 | Polvo de `lurker_office_look.gd:637-644` |
| `MultiMeshInstance3D` | 2 | Mallas de la galería |
| `ImageTexture` | 2 | Hojas |
| `VoxelGI` | 1 | Solo en un comentario de `measure_albedo.gd` |
| `ThemeDB` | 1 | Fuente de las hojas |
| `SpotLight3D` | 1 | Linterna en `lurker_test.gd:390` |
| `SphereShape3D` | 1 | Esfera de libre paso (`office_angles_capture.gd:42`) |
| `RandomNumberGenerator` | 1 | `lurker_test.gd:87` |
| `PhysicsShapeQueryParameters3D` | 1 | `office_angles_capture.gd:44` |
| `PackedScene` | 1 | `build_gallery.gd:81` |
| `ORMMaterial3D` | 1 | `build_*` |
| `Compositor` | 1 | `lurker_test.gd:205` (con `CompositorEffect` de la presentación) |
| `Label3D` | 1 | `office_capture.gd:101` (busca el rótulo «PERSONAL») |
| `CylinderMesh` | 1 | `lurker_test.gd:152` (bombilla) |
| `EditorScenePostImport` | 1 | `strip_blend_shapes.gd` |
| `Engine`, `Movie`, `Light3D` | 1 cada una | Varios |

Nodos por ruta que usan las herramientas (cadenas literales):

- `Presentation/Analog/Screen`, `Presentation/Lens`, `Presentation/Camcorder` (`office_rooms_capture.gd:118-120`, `lookdev_capture.gd:160-162`). `Lens/Screen`, `Analog/Screen`, `WorldEnvironment` (`lurker_test.gd:201-214`).
- `AnimationPlayer` (`strip_blend_shapes.gd:31`), clips «idle», «crawl», «crawl_fast» (`lurker_test.gd:365-385`).
- Nodos de puerta: `Leaf`, `Leaf_0`, `Leaf_1` (`office_rooms_capture.gd:176-182`, `office_angles_capture.gd:152`).
- Mallas de la galería: `Mesh_ceiling` se oculta (`build_gallery.gd:15`).
- Hueso `Head1` de la criatura (`mask_capture.gd:19-20`).

Métodos del juego que usan las herramientas (contrato, no revisado en su cuerpo):

- De `level` (la escena `hotel.tscn`): `start_floor`, `set_floor`, `apply_settings`, `bounce_ready`, `settle_objectives`, `mount_geometry`, `validate_floor_physics`, `physical_errors`, `objective(&"...")`, `ui`, `settings`, `interaction`, `net`, `player`, `hotel`, `locust`, `creature`, `intro`, `title_scene`, `manifest`, `creature_scene`, `kind.GENERATOR`.
- De `level.hotel`: `update_visibility`, `set_room_power`, `lit`, `lights[id]`, `dark_ids`, `emergency`, `flicker_clock`, `bounce`, `start_bounce`, `doors_near`, `doors`, `room_nodes`, `car_frames`, `vary`, `preset`, `DOOR_MODELS`.
- Del jugador: `torch`, `camera`, `eye_height`, `snap_torch()`, `handheld_enabled`, `zoom`, `slot`, `spawn`.
- Del manifiesto (datos): `rooms`, `start`, `start_facing`, `mail`, `air`, `power`, `tubes`, `ducts`, `archives`.

---

## 12. Pruebas de `tests/` que vigilan esta parte

- `tests/office/office_proportion_test.gd`: usa `tools/capture/room_framing.gd` (línea 12) para medir la proporción de cada sala desde la misma cámara que `office_rooms_capture` (`FRAMING.FOV` línea 135, `view_of` y `door_of` línea 235). Es la única prueba de tests/ que depende de un auxiliar de captura para decidir algo.
- `tests/hotel/avatar_test.gd:6`: menciona `tools/capture/avatar_gait_capture.gd` (solo en un comentario).
- `tests/hotel/echo_test.gd:6`: la imagen de eco se revisa a ojo con `tools/capture/echo_capture.gd` (comentario).
- `tests/hotel/palette_scan_test.gd:74`: lista de archivos tocados que incluye `tools/capture/catalog_capture.gd`, `doors_capture.gd`, `darkness_capture.gd`, `echo_capture.gd`, `lookdev_capture.gd`, `lurker_capture.gd`, `props_capture.gd`, `rooms_capture.gd`, `torch_capture.gd` y `tools/editor/build_gallery.gd`.
- `tests/hotel/scene_contract_test.gd:312`: carga `tools/workbenches/module_gallery.tscn`. `:329`: comprueba que el `.import` de los modelos de personaje llama a `tools/import/strip_blend_shapes.gd`.
- `tests/hotel/survival_test.gd:330`: comentario sobre `build_wardrobe.gd`.
- `tests/office/lurker_shell_test.gd:131` y `:149`: carga `tools/workbenches/lurker_test.gd` y lee su constante `BEND`.
- `tests/office/office_dressing_test.gd:20`: comentario sobre `build_catalogue.gd`.
- `tools/props/check_ingest_models.py`: no es prueba de Godot. Comprueba `ingest_models.py` (sección 7.2 paso 9).
- Ninguna prueba compara imágenes capturadas. Las capturas se miran a ojo, y las cifras de `office_rooms` son las únicas métricas automáticas de imagen.

---

## 13. Discrepancias y riesgos documentados en el propio código

1. **`office_plan_capture.gd`**: la cabecera (líneas 10-11) dice que «sale diciendo que el piso que subió no es el del plano real». El código (líneas 37-56) pone el plano real aunque el piso haya caído en reserva, y solo sale con código 1 si el generador también da reserva (líneas 41-44). Son dos comportamientos distintos. Cambios sin confirmar en este archivo.
2. **LEEME frente al script**: el LEEME dice que faltan el archivo móvil y el vestíbulo del montacargas, y el script asigna `archivo.jpeg` al tipo 13 (archivo móvil) y `salida montacargas.jpeg` al tipo 10 y al 19 (`office_rooms_capture.gd:22` y `:33`). Son dos fuentes que no coinciden.
3. **Referencias del chat**: no están en el repo (`docs/referencias/oficinas/LEEME.md`). Las mencionan `docs/referencias/` y el LEEME, pero no hay ningún `referencia_*.jpg`.
4. **Número de herramientas**: el encargo decía 55 archivos en `tools/capture/`. Hay 56 entradas: 55 `.gd` y 1 `.py`.
5. **Licencia de The Locust**: CC BY-NC-ND 4.0 (`docs/ASSETS.md:110` y `:433`). Dice explícitamente que prohíbe el uso comercial. Es el mismo modelo que usa el tráiler (`docs/TRAILER.md:63`), con permisos de distribución pendientes.
6. **Ventanas distintas**: 1200×800, 1280×800, 1280×720, 1600×900 y 1920×1080 según la herramienta. `ghosting` y `upscale` usan escala 0,6 y piden Forward+, mientras `torch_capture` debe correr también en Compatibility (cabecera 4-12).
7. **Argumento que no se lee**: la cabecera de `office_plan_capture.gd` (línea 9) pide `--real-plan`, pero el código solo lee `--seed=` y `--quality=` (líneas 24-26). El plano real se usa siempre.

---

## 14. Sin comprobar

- **Imágenes**: ninguna imagen de `docs/referencias/` ni de `evidence/` se abrió. El contenido de las fotos, sus dimensiones y sus colores no se han comprobado. Tampoco las 26 capturas del autor (`autor_12nov` y `autor_12nov_b`), salvo sus nombres y fechas.
- **Ejecución**: ningún script se ejecutó (Godot, Blender ni Python). Los resultados de `cifras.json` y `indice.json` no se han leído.
- **Cuerpo de los scripts**: solo cabecera o primeras líneas de la mayoría de `tools/capture/` (ver sección 2.2). Sin leer por completo: `avatar_capture`, `avatar_gait_capture`, `boot_capture`, `character_capture`, `code_note_capture`, `continue_capture`, `darkness_capture`, `difficulty_capture`, `doors_capture`, `echo_capture` (193), `execution_capture`, `film_check.py` (209), `ghosting_capture` (120), `hint_capture`, `hold_capture`, `key_capture`, `lift_capture`, `locust_gait_capture`, `lurker_capture` (335), `lurker_hand_check`, `lurker_test_check`, `mask_capture`, `note_survey_capture`, `notes_capture` (158), `online_capture`, `phantom_capture`, `preset_tour` (151), `props_capture`, `records_capture` (145), `rooms_capture`, `route_signs_capture`, `rules_capture`, `sheet_capture`, `sheet_map_capture`, `television_capture` (96), `title_capture`, `torch_capture` (118), `transit_capture`, `ui_capture`, `upscale_capture`, `walkthrough_movie`, `catalog_capture` (292). De `darkness_capture` y `torch_capture` se leyó la línea de guardado (`:35` y `:32`). De `hint_capture` y `catalog_capture` solo se leyó la cabecera.
- **Props**: cuerpo de `build_catalogue.gd` (555 líneas), `build_wardrobe.gd` (227), `fit_model.py` (213), `check_ingest_models.py` (190), `register_sketchfab.py` (132), `ingest_camcorder.py` (240), `cloth_pieces.py` (168), `build_camcorder.gd`, `build_door.gd`, `build_elevator.gd`, `build_model_props.gd`, `catalogue_sheet.gd`, `bake_key.gd`, `prepare_key_textures.py`, `fetch_models.py` (leído entero). `fit_models.json` solo en estructura: 60 entradas, sin contenido.
- **Tráiler**: `tools/trailer3d/web/**`, `audio/*.py` y los `shots/*.js` no se leyeron. Solo `package.json`, las cabeceras de tres `.mjs` y dos `.py`, y las listas de carpetas.
- **Módulos**: `tools/workbenches/module_gallery.tscn` (2,1 MB) no se abrió; `lurker_arena.tscn` y `lurker_test.tscn` solo como texto corto.
- **Registros**: `source_assets/oficinas/**/registro.json` no existen en el repo (están fuera de git). `docs/ASSETS.md` se miró solo en las líneas que cita la ficha.
- **Contrato con el juego**: las funciones de `game/app/hotel_main.gd` que llaman las capturas se identificaron por nombre; su cuerpo no se revisó, salvo la firma de `start_floor` (línea 720).
- **Unidades de Godot**: la descripción de `ImporterMesh.generate_lods` en `.claude/godot-api/doc/classes/ImporterMesh.xml` no se leyó, así que no se confirma si los ángulos son grados.
- **Lo que significa `floor_number` = 0 por defecto**: no se ha comprobado qué piso representa.
- **Fuera de alcance** (pero citado): `tools/dev/capture_bench.gd` (modo `bench` de `godot.ps1`), `tools/dev/office_plan_metrics.gd` (modificado sin confirmar) y `docs/REALISM.md`.
- **Qué lleva `evidence/rediseno/recepcion/`** (159 archivos sin PNG): no se miró.
