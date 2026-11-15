# Ficha de hechos: interfaz (ui)

Fecha de la lectura: 14 de noviembre de 2026. Repositorio: `E:/Projects/The Four`, rama `main`.
Alcance: `game/ui/` (14 .gd, `interface.tscn`, 2 shaders), `game/title/`, `game/intro/`, `docs/textos_juego.txt`, `assets/ui/`.
Método: lectura completa de todos los archivos listados (por tramos cuando son largos). No se ejecutó Godot, Unreal ni ningún otro programa del proyecto. No se usó git. Las rutas van como `ruta:línea`. Donde algo viene de un archivo fuera del alcance, se dice explícitamente.

---

## 0. Resumen

- La interfaz se construye casi toda en código GDScript. La única escena es `game/ui/interface.tscn` (90 líneas): un `CanvasLayer` con cinco nodos de HUD. Todo lo demás (menús, papeles, ajustes, intro overlay) se crea en tiempo de ejecución dentro de `hotel_ui.gd`, que hace de director de pantallas (`menu(kind)`, `hotel_ui.gd:584`).
- Los papeles del juego (hoja compartida, notas, cartas, formulario del hotel, documentos del archivo, plano) no son imágenes con texto encima: son dibujos con `draw_*` y tinta simulada (letra a letra con desplazamiento pseudoaleatorio sembrado, lápiz trazado con `Line2D`, manchas procedurales en `Image`).
- La tipografía principal no existe en el repositorio: `osd_style.gd` busca `res://assets/fonts/vcr_osd_mono.ttf`, que no está (no hay carpeta `assets/fonts`). En la práctica se usa una `SystemFont` con la lista "VCR OSD Mono, Consolas, Menlo, Lucida Console, Courier New, monospace" (`game/ui/osd_style.gd:4,18-30`).
- Hay 4 sombreadores de interfaz: `signal_wash.gdshader` (nieve de señal débil sobre notas y avisos), `tape_noise.gdshader` (estática de cinta en transiciones), `typewriter_ink.gdshader` (en `game/presentation/shaders/`, lo usan los papeles mecanografiados), y `tv_screen.gdshader` (la tele de la intro 3D, en `game/intro/`, es un shader 3D `spatial`).
- No hay sistema de traducción. Todo el texto visible está escrito a mano en español dentro del código (`tr()` no aparece en `game/ui`, `game/title` ni `game/intro`). `docs/textos_juego.txt` es un catálogo de revisión para el autor; el juego no lo carga (sólo lo citan `README.md`, `docs/README.md` y un spec).
- Tamaño del alcance: 5.297 líneas de GDScript en `game/ui/` (de ellas 2.370 en `hotel_ui.gd`), 165 en `game/title/`, 1.008 en `game/intro/` (sin contar el `.uid`).

---

## 1. Inventario de lo leído

### 1.1 `game/ui/` (14 GDScript + escena + shaders)

| Archivo | Líneas | Qué hace |
|---|---|---|
| `hotel_ui.gd` | 2.370 | Director de la interfaz: CanvasLayer 4. Marco de menús, todas las pantallas (`menu()`), ajustes, créditos, papel en mano, documentos, teclado de la puerta, tarjeta de sector, aviso de objetivo, señal perdida, rebobinado, intro overlay, entrada de teclado y mando. |
| `osd_style.gd` | 269 | Estilo común: fuente, paleta, `Theme` generado en código, sellos, medidores, figuras, columnas, sonidos sintéticos (beeps y tonos). |
| `paper_sheet.gd` | 546 | La hoja compartida: página de dibujo (lápiz de cuatro asientos, borrador), columna de notas, mano de mando (pad), envío de trazos. |
| `records_board.gd` | 290 | Records: pestañas TABLONES, FICHA, COMPARAR. |
| `tape_report.gd` | 367 | Parte de la cinta: pestañas RESUMEN, EQUIPO, SECTORES, CRONOLOGÍA, LOGROS. |
| `achievements_board.gd` | 108 | Pantalla de logros (lista de hitos con icono y fecha, comparación con amigos de Steam). |
| `rules_screen.gd` | 115 | Reglas de la sala: una fila por regla, selector para el anfitrión, nota que aparece bajo la lista. |
| `hint_view.gd` | 336 | Papeles de pista (hoja de limpieza, orden de trabajo, libreta, polaroid, calco, plano de evacuación, tarjeta "No molestar", resguardo neumático, memo, ficha de personal, mapa de tubos, hoja de otro). |
| `hotel_form.gd` | 263 | Impreso del hotel: campos mecanografiados, cruces con X, firma a pluma. |
| `ruled_paper.gd` | 140 | Hoja de carta doblada en cuatro y hoja de libreta: texto a máquina o a lápiz sobre renglones. |
| `torn_letter.gd` | 85 | Carta rota en cuatro trozos: cada trozo lleva un número del código. |
| `sheet_map.gd` | 215 | Plano sobre la hoja: muros dibujados como los ha visto el grupo, con tinta que se desvanece. |
| `handwork.gd` | 128 | Escritura a mano simulada (dígitos en trazos, líneas de letra, números de página, manchas de uso). |
| `hold_ring.gd` | 65 | Anillo de "mantener tecla" alrededor del punto de mira y junto al aviso de saltar. |
| `interface.tscn` | 90 | Escena: CanvasLayer "Interface" (layer 4) con HUD y MenuOverlay. |
| `shaders/signal_wash.gdshader` | 51 | Lavado de señal débil (rodar, arrastrar, nieve) sobre una imagen de texto. |
| `shaders/tape_noise.gdshader` | 20 | Estática de cinta en bloques de 2 px, 30 fps. |

### 1.2 `game/title/` y `game/intro/`

| Archivo | Líneas | Qué hace |
|---|---|---|
| `game/title/title_scene.gd` | 165 | Fondo 3D de la portada: habitación con la criatura asomada desde una puerta entornada. |
| `game/intro/intro_sequence.gd` | 665 | Escena de entrada en 3D (39,6 s): cama, tele, cuatro golpes al cristal, huida, puerta, pasillo, recepción. |
| `game/intro/tv_broadcast.gd` | 135 | SubViewport que dibuja a la criatura dentro de la tele. |
| `game/intro/crack_pattern.gd` | 107 | Dibuja las grietas del cristal en una textura RGBA (un canal por golpe). |
| `game/intro/tv_screen.gdshader` | 101 | Shader 3D de la pantalla de la tele (estática, líneas, grietas, apertura). |

### 1.3 Otros

| Archivo | Líneas | Qué hace |
|---|---|---|
| `docs/textos_juego.txt` | 1.687 | Catálogo de todos los textos visibles con su identificador, dónde salen y el texto actual; el autor escribe la corrección en la línea CORRECCIÓN. Ver sección 16. |
| `assets/ui/achievements/` | 18 PNG (+18 `.import`) | Iconos de logros, todos con prefijo `1_` (piso 1): `1_again`, `1_brave`, `1_clean`, `1_code`, `1_first`, `1_four`, `1_ghost`, `1_half`, `1_hunted`, `1_hunter`, `1_master`, `1_mvp`, `1_out`, `1_quick`, `1_sets`, `1_slip`, `1_solo`, `1_three`. |

### 1.4 Leídos sólo en parte, por dependencia directa

- `game/presentation/shaders/typewriter_ink.gdshader` (32 líneas, completo).
- `game/presentation/camcorder_look.gd`: sólo `fov_for` (líneas 50-52).
- `game/presentation/graphics_presets.gd`: nombres de presets, escalados, antialiasing y efectos pesados (líneas 20-27, 264-295).
- `game/floors/floor_index.gd`: `COUNT`, `RELEASED`, `milestones()` (líneas 16-42).
- `game/app/hotel_main.gd`: sólo las llamadas a la UI (líneas 22-23, 330-347, 1005, 1827 y 1402-1405).
- `game/services/settings_service.gd`: sólo `WINDOW_MODES` y `PAD_KEYS` (líneas 19, 61).

---

## 2. Cómo está montada la interfaz

### 2.1 Escena `interface.tscn`

- `[node name="Interface" type="CanvasLayer"]`, `layer = 4`, `process_mode = 3` (ALWAYS), script `hotel_ui.gd` (`interface.tscn:5-8`).
- `HUD` (Control, anclas de pantalla completa, `mouse_filter = 2`, ignora el ratón):
  - `Flash` (Label, 30 px, esquina superior izquierda, 48/34) (`:18-23`). Texto de avisos cortos (`ui.flash()`).
  - `Subtitle` (Label, 22 px, centrado abajo, ancho 940, ajuste de línea, alineado al final) (`:25-40`). Lo escribe `hotel_main` con `world_audio.caption_text` (`game/app/hotel_main.gd:1827`).
  - `InteractionHint` (Label, 22 px, centrado abajo, alto 32) (`:42-55`). Lo escriben `interaction.gd`, `executions.gd`, `hotel_floor.gd` y otros (no leídos).
  - `ExitProgress` (ProgressBar, centrado abajo, ancho 320, `max_value = 3.0`, sin porcentaje) (`:57-70`).
  - `Crosshair` (ColorRect 3×3 en el centro, color `(0.94, 0.94, 0.9, 0.55)`) (`:72-83`).
- `MenuOverlay` (Control de pantalla completa). En `_ready` se saca del árbol y se pone dentro de `outside` (ver 2.2).

### 2.2 Capas (orden de dibujo, de abajo arriba)

- Layer 4: esta CanvasLayer (HUD, `marks_view`, `signal_label`, `rewind_mark`, `rewind_clock`, `skip_label`, `hold_ring`, `skip_ring`, `sheet` y `brief`). `hotel_ui.gd:254`.
- Layer 5: el filtro de cinta analógica (`analog.gdshader`, en `presentation/`, no leído). Comentario en `hotel_ui.gd:127` y `:249-253`: lo que se escribe en pantalla se graba en la cinta.
- Layer 6 (`OUTSIDE_LAYER`, `hotel_ui.gd:128`): CanvasLayer `Outside` con el `MenuOverlay` (menús, carga, final, créditos, intro overlay). Estas pantallas no pasan por la cinta (comentario en `hotel_ui.gd:308-312`).
- `marks_view`: SubViewport de pantalla completa (`UPDATE_ONCE` por defecto, `UPDATE_ALWAYS` mientras hay algo escrito) (`hotel_ui.gd:268-277`, `:2223-2229`). Su textura se pasa al shader del filtro (`film_marks`, `:2174-2176`) para que "SEÑAL PERDIDA" y el REW se graben sobre la nieve.

### 2.3 Marco de menús (construido por código)

- `build_frame()` (`hotel_ui.gd:383-430`): `backdrop` (TextureRect con `GradientTexture2D` de 256×4: negro 0.94 → 0.72 → 0.18), `MarginContainer` con márgenes izquierda y derecha 96, arriba 110, abajo 90 (`:398-403`), `body` (HBox, separación 56), `column` (VBox, ancho mínimo 520, centrado) y `side` (VBox a la derecha, expandida).
- Esquinas del OSD: `osd_left` (arriba izquierda, 48/34), `osd_right` (arriba derecha, −48/34), `footer` (abajo izquierda, −58, 15 px, color SOFT). Fuente 28 en las esquinas (`corner_label`, `:432-445`).
- Ruido: `noise` (ColorRect de pantalla completa con `tape_noise.gdshader`) (`:424-430`).

### 2.4 Piezas de construcción

- `entry()` (`:500-529`): cada opción es un `Button` (texto en MAYÚSCULAS, sin fondo) con un `Label` "▶" a la izquierda que aparece con el foco. `FOCUS_ALL`, y el ratón la enfoca al pasar (`mouse_entered` → `grab_focus`).
- `button()` (`:531`): igual que `entry` con tamaño 22. `action(words, id, disabled)` (`:534`) crea una entrada que emite `action_requested(id)`; es el canal con `hotel_main.gd`.
- `label()`, `paragraph()` (ajuste de línea, ancho dado), `spacer()`, `title()` (título con dos "fantasmas" de color desplazados ±3 px, alfas 0.55 rojo y 0.45 cian, `:465-475`).
- `choice()` (`:1036`): fila con etiqueta de 240 px y `OptionButton`. `options()` (`:1875`): igual, ligado a `settings.values[key]`. `slider()` (`:1897`): `HSlider` de 300×30 con número a la derecha (porcentaje si el máximo es 1). `check()` (`:1856`): `CheckButton` con marco de foco. `field()` (`:936`): `LineEdit` de 300×40, longitud máxima 40, con guardado en cada cambio.
- `TabContainer` con `ScrollContainer` por pestaña (`page()`, `:1841`).
- Navegación con pad: `chain_settings()` (`:1772`) enlaza a mano `focus_neighbor_top` y `_bottom` de todas las filas de cada pestaña, con "Volver" al final. `aim_tab()` (`:1806`) mete la barra de pestañas entre la cabecera y las filas.

### 2.5 Pantallas por `menu(kind)` (`hotel_ui.gd:584-884`)

Cada llamada hace `clear()` (`:477-497`), oculta el panel de la pantalla anterior, pone el OSD y reconstruye. Al final, `transition(0.35)` (fundido de 0,28 s con retardo 0,06 s y estática 0,35) y `focus_first()`. Si el id no está en el `match`, no pasa nada.

| id de `menu()` | Línea | Construcción | Ver sección |
|---|---|---|---|
| `main` | 594 | `column` con título, opciones | 3.1 |
| `pause` | 610 | título PAUSA, objetivo, opciones, controles | 3.2 |
| `won` | 621 | parte de la cinta (`tape_screen`) | 5.1 |
| `failed` | 625 | parte de la cinta con SEÑAL PERDIDA | 5.2 |
| `loading` | 630 | CARGANDO CINTA + puntos animados | 3.3 |
| `transition` | 639 | FIN DEL PISO (sin columna lateral) | 3.3 |
| `archive` | 643 | ARCHIVO, 16 documentos | 5.5 |
| `records` | 670 | RECORDS con pestañas | 6.1 |
| `achievements` | 686 | LOGROS | 6.3 |
| `multiplayer` | 694 | MULTIJUGADOR | 7.1 |
| `mp_steam` | 711 | STEAM | 7.2 |
| `mp_ip` | 721 | IP / LAN | 7.3 |
| `host_ip` | 731 | CREAR SALA por IP | 7.4 |
| `join_steam` | 750 | UNIRSE por Steam | 7.5 |
| `steam_invite` | 780 | INVITAR (lista de amigos) | 7.6 |
| `steam_wait` | 810 | Conectando con Steam | 7.7 |
| `join` | 818 | UNIRSE por IP | 7.8 |
| `lobby` | 833 | SALA (`lobby_screen`, 960) | 7.9 |
| `difficulty` | 835 | DIFICULTAD (`difficulty_screen`, 890) | 7.10 |
| `rules` | 837 | REGLAS (`RULES_SCREEN.build`) | 7.11 |
| `online_pause` | 853 | MENÚ en partida en línea | 7.12 |
| `online_won`, `online_failed` | 864 | final en línea (`online_end`, 1049) | 7.13 |
| `credits` | 866 | CRÉDITOS | 9 |
| `settings` (no es `menu()`) | 1530 | `show_settings(back)` | 4 |
| `characters` (no es `menu()`) | 1917 | `show_characters(back)` | 7.14 |
| `tape` (no es `menu()`) | 1100 | `show_tape(line)`: PARTE DE LA CINTA | 6.2 |

Pantallas que no son `menu()`: `show_dossier` (1193, documento del archivo sobre la pantalla), `show_hint` (1269), `show_document` (1319), `show_lock` (1366), `show_transit` (2012), `show_brief` (2068), `show_rewind` (2183), `lost_signal` (2199), `show_skip` (1995), `play_intro` (2281).

### 2.6 Estado que la interfaz guarda

- `screen` (id actual), `settings_open`, `rebind_action`, `rebind_pad`, `rebind_button`, `focus_wanted`, `buttons` (id → Button), `fields`, `records_view` (pestaña, tablón, tabla y empresa), `achievements_view` (amigo que se compara), `rules_view`, `rule_pickers`, `rule_rows`, `rule_detail`, `summary`, `places`, `outcome`, `elapsed`, `descend`, `briefing` (sector, objetivo y progreso para el pausa), `snatches` (papeles arrancados), `dossier`, `reading`, `lock_panel`, `sheet`, `intro`, `intro_tween`, `brief`, `transit`, `flash_time`, `noise_amount`, `noise_floor`, `clock` (`hotel_ui.gd:125-245`).

---

## 3. Menús principales

### 3.1 Menú principal (`main`, `hotel_ui.gd:594-609`)

- OSD izquierda: `▶ PLAY`. Título `THE FOUR` a 104 px. Subtítulo `H  O  T  E  L` a 24 px en SOFT (dos espacios entre letras).
- Opciones, en este orden (texto mostrado en MAYÚSCULAS):
  1. `Nueva partida` (id `new`).
  2. `Continuar` (id `continue`); desactivada si `can_continue` es falso.
  3. `Multijugador` (id `multiplayer`).
  4. `Records` (id `records`); sólo si `has_records()` (hay algo en el tablón).
  5. `Logros` (id `achievements`).
  6. `Archivo` (id `archive`); sólo si `discoveries.found` no está vacío.
  7. `Ajustes` (id `settings`).
  8. `Créditos` (id `credits`).
  9. `Salir` (id `quit`).
- Aviso de primer arranque con gráfica integrada (`:878-882`): si `settings.integrated_gpu` y el renderizador es `forward_plus`, se escribe en ámbar: "Gráfica integrada: preset Muy bajo. Si va sobrado, sube el preset en Ajustes ▸ Gráficos; si aun así va lento, prueba ahí el renderizador Compatibilidad."
- Las acciones se emiten; lo que pasa después está en `hotel_main.gd` (no leído).

### 3.2 Pausa (`pause`, `:610-620`)

- OSD `❚❚ PAUSA`, fondo al 0,9. Título `PAUSA` a 72 px.
- `briefing_panel(column)`: el sector (en ámbar, 22 px), el objetivo (20 px, ancho 520) y, en filas, el progreso (clave a 260 px de ancho en SOFT 18; valor en ámbar 18).
- Opciones: `Continuar` (`resume`), `Ajustes` (`settings`), `Reintentar piso` (`retry`), `Menú principal` (`main`).
- Columna derecha: `controls_panel(side)` (sección 3.5).

### 3.3 Carga, transición y fin de piso

- Carga (`loading`, `:630-638`): OSD `◀◀ REW`. Título `CARGANDO CINTA` a 58 px. Línea `EL HOTEL ESTÁ TOMANDO FORMA` a 22 px en SOFT; sus puntos suspensivos cambian (`".".repeat(int(clock * 3.0) % 4)`, `:2213`). Segunda línea `loading_step` (18 px, ámbar), la escribe `loading_note(words)` (`:543`). Abajo a la derecha, `controls_panel(side)`.
- Transición (`transition`, `:639-642`): OSD `■ STOP`. Título `FIN DEL PISO` a 64 px. Oculta la columna lateral.
- Textos de carga que se escriben desde fuera: `PREPARANDO LA IMAGEN %d %` está en `game/presentation/shader_warmup.gd` (no leído).

### 3.4 Textos del OSD por pantalla

| Pantalla | Esquina superior izquierda |
|---|---|
| Menú principal, archivo, records, logros, créditos | `▶ PLAY` |
| Reglas de la sala | `SALA ▸ REGLAS` |
| Ajustes | `MENU ▸ AJUSTES` |
| Dificultad | `MENU ▸ NUEVA PARTIDA` |
| Multijugador | `MENU ▸ MULTIJUGADOR` |
| Sala | `MULTIJUGADOR ▸ SALA` |
| Pausa | `❚❚ PAUSA` |
| Menú en partida en línea | `❚❚ MENÚ` con pie `LA PARTIDA SIGUE` |
| Fin de piso | `■ STOP` |
| Señal perdida | `SEÑAL PERDIDA` en ALERT; parpadea (ver 3.6) |
| Carga | `◀◀ REW` |
| Ajustes | `MENU ▸ AJUSTES` |
| Multijugador y subpantallas | `MULTIJUGADOR ▸ …` |

### 3.5 Panel de controles (`controls_panel`, `:1501-1524`)

- Panel oscuro (0,02 negro al 0,86), borde FAINT, margen 20, a la derecha, 15 px, separación 12 (`CONTROLS_SIZE`, `CONTROLS_SPACING`, `:1527-1528`).
- Título `CONTROLES` en ámbar 18 px.
- Teclado (filas): `W A S D` (de `settings.key_name` de cada acción) "Moverse"; correr "Correr"; agacharse "Agacharse"; saltar "Saltar"; interactuar "Interactuar"; linterna "Linterna"; asomarse "Asomarse"; `RUEDA DEL RATÓN` "Zoom de la cámara"; hoja "Hoja"; `ESC` "Pausa".
- Con mando conectado y en uso (`settings.using_pad`): `STICK IZQ.` "Moverse"; correr y agacharse con su botón y `(ALTERNA)` si están en modo alternar; saltar, interactuar, linterna, asomarse (`CRUCETA ← →` en el texto de la ayuda), `CRUCETA ↑ ↓` "Zoom de la cámara", hoja, y `START` "Pausa" (botón de `button_name(JOY_BUTTON_START)`).

### 3.6 Señal perdida y parpadeo

- `failed` pone `noise_floor = 0.16` (`:628`) y el OSD izquierdo parpadea: alfa 1,0 o 0,25 según `fposmod(clock, 1.0) < 0.6` (`:2211`).
- `lost_signal(seconds)` (`:2199-2201`) muestra en el centro "SEÑAL PERDIDA" (ALERT, 30 px en `signal_label`) durante `seconds` (por defecto 2,6 s); el texto parpadea con alfa 1,0 o 0,0 según `fposmod(flash_time, 0.4) < 0.25` (`:2216`). Lo usan `death_tape.gd:419` y `executions.gd:389,417` (no leídos).

---

## 4. Ajustes (`show_settings(back)`, `hotel_ui.gd:1530-1696`)

- OSD `MENU ▸ AJUSTES`. Título `AJUSTES` a 58 px. Si hay mando: línea "[LB] CAMBIA DE PESTAÑA [RB]" a 16 px en SOFT (`:1542-1545`).
- `TabContainer` de 1000×380, letra 20 px (`:1546-1549`). Cuatro pestañas: `IMAGEN`, `GRÁFICOS`, `CONTROLES`, `AUDIO`.
- Pie: `Volver` (`leave`: apaga `settings_open`, revierte la pantalla si queda pendiente, emite `return_action`) y la fila de confirmación de pantalla.

### 4.1 IMAGEN (`:1553-1582`)

1. **Modo de ventana** — `WINDOW_MODES` = "Pantalla completa", "Ventana sin bordes", "Ventana" (`settings_service.gd:61`). Clave `window_mode`.
2. **Tamaño de ventana** — si está a pantalla completa, un desplegable desactivado con el tamaño de la pantalla (`DisplayServer.screen_get_size`) (`:1559-1568`). Si no: "1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440". Clave `resolution`.
3. **Escalado** — `PRESETS.UPSCALER_NAMES`: "Automático", "Bilineal (sin reconstrucción)", "FSR 1.0 (espacial)", "FSR 2.2 (temporal)". Clave `upscaler`. Desactivado si el renderizador no es `forward_plus` (`:1571-1572`).
4. **Calidad del escalado** — `PRESETS.SCALING_NAMES`: "Nativa (sin reescalado)", "Ultra calidad (77%)", "Calidad (67%)", "Equilibrado (59%)", "Rendimiento (50%)", "Ultra rendimiento (33%)"; si la escala no coincide con ninguna, aparece "Personalizada (N%)" (`:1734-1755`). Cambia la clave `scale` y reconstruye la pantalla.
5. **Escala de render** — deslizador de 0,33 a 1,0 con paso 0,01 (`:1574`); reconstruye la pantalla al soltar.
6. **Nitidez del escalado** — deslizador de 0 a 1, paso 0,05; desactivado con escalado bilineal (`:1576`).
7. **Suavizado de bordes** — `PRESETS.ANTIALIASING_NAMES`: "Del preset", "Sin suavizado", "FXAA (rápido)", "SMAA (mejor)", "TAA (temporal)", "MSAA 2×", "MSAA 4×". Desactivado con FSR 2.2 (`:1580`).
8. **Límite de FPS** — "Sin límite", 30, 60, 120, 144 (`:1581`).
9. **Sincronización vertical** — casilla `vsync` (`:1582`).

### 4.2 GRÁFICOS (`:1583-1617`)

10. **Preset gráfico** — `PRESETS.NAMES` en el orden `PRESETS.ORDER`: "Muy bajo", "Bajo", "Medio", "Alto", "Ultra" (`game/presentation/graphics_presets.gd:20,27`; `hotel_ui.gd:1584`). Aviso en ámbar si el preset es Muy bajo o Bajo y el escalado es FSR 2.2 (`:1587-1588`).
11. **Renderizador** — "Forward+ (completo)" / "Compatibilidad (gráfica integrada)" → `forward_plus` / `gl_compatibility` (`:1589`). Si cambió, aviso ámbar "El renderizador cambia al reiniciar el juego." (`:1590-1591`) y botón `REINICIAR AHORA` sólo si `return_action == "main"` y no hay partida en línea (`:1593-1605`). El botón llama a `OS.set_restart_on_exit(true, args)` y `get_tree().quit()`.
12. **Sombras** — casilla `shadows` (`:1606`).
13. **Efectos pesados** — cuatro desplegables con "Del preset", "Desactivado", "Activado" (`:1608`): `ao` "Oclusión ambiental (SSAO/SSIL)", `fog` "Niebla volumétrica", `reflections` "Reflejos en superficies", `blur` "Desenfoque de movimiento" (`graphics_presets.gd:290-295`).
14. **Deslizadores de imagen** (0 a 1, paso 0,05) (`:1610`): "Cinta VHS" (`vhs`), "Grano" (`grain`), "Aberración cromática" (`chromatic`), "Líneas de barrido" (`scanlines`), "Movimiento de cámara" (`bob`).
15. **Marcas de videocámara** — casilla `osd` (`:1611`).
16. **Efectos reducidos** — casilla `reduced` (`:1612`).
17. **Sobresaltos suaves** — casilla `startle_soft` (`:1615`). Texto en el código: la captura sin el rostro en la lente corta a la cámara ya en el suelo.
18. **Sangre** — casilla `gore` (`:1617`).

### 4.3 CONTROLES (`:1618-1667`)

19. **Sensibilidad** — deslizador de 0,0005 a 0,008, paso 0,0001 (`:1619`).
20. **Invertir mirada vertical** — casilla `invert` (`:1620`).
21. Sólo con mando conectado (`:1621-1625`): **Sensibilidad del mando** (0,6 a 6,0, paso 0,2, clave `pad_look`); **Alternar correr (mando)** (`pad_sprint_toggle`); **Alternar agacharse (mando)** (`pad_crouch_toggle`); **Vibración del mando** (`rumble`).
22. **Acciones reasignables** (`:1626-1657`): en este orden: Adelante (`forward`), Atrás (`backward`), Izquierda (`left`), Derecha (`right`), Correr (`sprint`), Saltar (`jump`), Interactuar (`interact`), Linterna (`flashlight`), Agacharse (`crouch`), Hoja (`sheet`), Asomarse a la izquierda (`lean_left`), Asomarse a la derecha (`lean_right`), The Locust: rastro a la tele (`locust_trace`). Cada una tiene un botón de tecla (240×38). Al pulsarlo: "PULSA UNA TECLA, ESC CANCELA"; si la tecla está reservada o en uso: "TECLA RESERVADA O EN USO" (`_input`, `:2269-2277`). Con mando, una segunda columna (200×38) para el botón: "PULSA UN BOTÓN, %s CANCELA"; si el botón no vale: "BOTÓN RESERVADO, %s CANCELA". Las acciones sin botón de mando (`locust_trace`, y cualquiera fuera de `PAD_KEYS`) muestran "EL DE LA LINTERNA" o "STICK IZQ." y el botón queda desactivado (`:1643-1651`).
23. **RESTAURAR CONTROLES** — botón que llama a `settings.reset_controls()` y reconstruye la pantalla (`:1658-1667`).

Botones de mando por defecto (`settings_service.gd:19`): interactuar X, agacharse B, linterna Y, saltar A, correr stick izquierdo, hoja BACK, asomarse D-pad izquierda y derecha.

### 4.4 AUDIO (`:1668-1670`)

24. **General** (`master`), **Ambiente** (`ambience`), **Música** (`music`), **Efectos** (`effects`), **Señales de peligro** (`threat`): deslizadores de 0 a 1, paso 0,05.
25. **Subtítulos de sonidos** — casilla `subtitles`.

### 4.5 Confirmación de pantalla (`:1671-1692`)

- Aviso en ámbar: "Confirma la pantalla: se revertirá en %d s." (cuenta atrás de `settings.countdown`, `_display_changed` en `:2231-2239`).
- Botones (sólo visibles mientras hay un cambio pendiente): `CONSERVAR PANTALLA` (`settings.confirm_display()`) y `REVERTIR PANTALLA` (`settings.revert_display()` y reconstruye).

---

## 5. Papel, notas y documentos

### 5.1 Parte de la cinta: fin de piso y señal perdida (`tape_screen`, `:1069-1094`)

- Pantalla de fin: título (44 px, color `ink`), encabezado de la cinta (15 px SOFT), las pestañas (`REPORT.build`) y una fila de botones (`entry` 21 px).
- Sin cinta (un invitado que aún no recibió el parte): "TIEMPO DE GRABACIÓN  %s" (22 px SOFT) (`:1078`, textos FIN.04).
- Botones de `won` (`:621-624`): `Bajar al piso 2` (sólo si `descend`), `Nueva partida`, `Records`, `Menú principal`.
- Botones de `failed` (`:629`): `Reintentar`, `Records`, `Menú principal`. Un botón de "records" no aparece si el tablón está vacío (`:1092`).
- El final en línea (`online_end`, `:1049-1064`): el titular depende del bando: cazador y ganó → "SE TE ESCAPARON"; humano y ganó → "SALISTE DEL PISO"; cazador y perdió → "CAZA COMPLETA"; humano y perdió → "SEÑAL PERDIDA". Para el anfitrión: "Reintentar piso" (si perdió), "Bajar al piso 2" (si ganó y `descend`), "Nueva partida", "Volver a la sala", "Records", "Cerrar la sala". Para el invitado: nota "El anfitrión decide cómo seguir…" y "Records", "Salir de la sala".

### 5.2 Parte de la cinta: pestañas (`tape_report.gd`)

- Caja de 1040×372, `TabContainer` con letra 18 px (`:18,22-34`). Pestañas: `RESUMEN`, `EQUIPO`, `SECTORES`, `CRONOLOGÍA` y `LOGROS`. La última sólo aparece si hay `outcome.milestones` y (se ganó o hay logros nuevos) (`:33`).
- Encabezado: `CINTA Nº %d   <piso>   <empresa>   [N SUPERVIVIENTES]   <dificultad>   <fecha>` (`heading()`, `:46-53`). En pérdida de señal sólo `CINTA Nº %d`.
- **RESUMEN** (`:77-147`): cifras con cuenta ascendente de 1,1 s (`count_up`, `:62-66`): TIEMPO DE GRABACIÓN (ámbar si se ganó, rojo si no) y PUNTAJE (retardo 0,3 s). NOTA como sello (`stamp`, 40 px, ámbar si la nota es A o mejor). Si no se ganó: "SECTOR ALCANZADO n / k". Segunda fila: MUERTES (rojo si > 0), SALIDAS, TELEVISORES, VECES EN ARMARIOS, METROS ANDADOS. Comparación con la mejor marca del tablón: "PRIMERA CINTA DE ESTE TABLÓN", o "MEJORA LA MEJOR MARCA EN %s" / "A %s DE LA MEJOR MARCA", y lo mismo con el puntaje: "SUPERA EL MEJOR PUNTAJE EN %s" / "A %s DEL MEJOR PUNTAJE". Puestos: "Nº %d EN %s". Sellos de méritos (`RECORDS.badges`) con retardo 0,9 s y +0,35 s cada uno. Si hubo reglas distintas: "CON OTRAS REGLAS: SIN LOGROS, Y EN SU PROPIO TABLÓN" y la lista de reglas. Si no se ganó: "Cinta perdida." Tarjeta de la derecha (`spotlight`, `:151-182`): rótulo "MÁS VALIOSO", "TU PAPEL", "SU PAPEL" o "QUIEN MÁS HIZO", nombre (30 px), papel y motivo, puntos y hazañas.
- **EQUIPO** (`:190-234`): tabla con columnas `JUGADOR` 180, `PAPEL` 152, `PUNTOS` 82, `ENCUENTROS` 104, `TV` 36, `CÓDIGOS` 76, `SALIDAS` 70, `MUERTES` 70, `METROS` 72, y la última columna `SALIÓ` o `SE QUEDÓ` (`COLUMNS`, `:187`). Estrella `★` ante el más valioso. Bajo cada fila, una barra de la proporción de puntos (`meter`, 196 px) y el motivo. Fila del cazador: `THE LOCUST, %d captura(s)` (en inglés dentro del texto español). Pie: "LO QUE GANÓ EL EQUIPO JUNTO" (o "Y POR LA CINTA ENTERA") con los bonos, con signo `+` o `−` (U+2212).
- **SECTORES** (`:241-281`): una fila por sector con "SECTOR n", el encargo del sector (`kind.stage(i).errand`), una barra de 250 px, el tiempo y la diferencia con el mejor del tablón ("NO SE CERRÓ", o "−mm:ss" en amarillo si es más rápido, o "+mm:ss"). Bajo cada fila, lo que pasó (`sector_facts`, `:284-297`). Nota al pie: "A LA DERECHA, CADA SECTOR CONTRA EL MÁS RÁPIDO QUE HA TENIDO ESTE TABLÓN."
- **CRONOLOGÍA** (`:301-331`): una fila por momento: hora (`tape_time`), `S%d` y el texto del momento (tabla de `moment()`). Si la cinta no trae momentos: "Esta cinta se grabó antes de que el hotel anotara sus momentos."
- **LOGROS** (`:335-367`): "LOGROS NUEVOS" (o "Esta cinta no trae ningún logro nuevo."), sellos con retardo 0,5 s y +0,3 s, nota de cada uno. Con reglas distintas: "Con otras reglas que las del juego no se alcanzan logros." Pie: "PISO 1: EL HOTEL:  n DE m LOGROS", "QUEDAN POR HACER" (los 4 primeros pendientes) y "TODOS, EN LOGROS.".

### 5.3 Hoja compartida (`paper_sheet.gd`, `sheet_map.gd`)

- Página de 1.600×1.000 px (`:32`), centrada con desplazamiento de medio `STRIP` (250 px) a la izquierda. Fondo `PAPER` (0,86; 0,82; 0,71) con borde (0,62; 0,55; 0,42), sombra de 22 px (`:40,112-118`). Lo cubre un fondo negro al 0,62 (`:106-107`).
- Renglones: una línea cada 36 px desde 48 (azul 0,32; 0,42; 0,66 al 0,2), y un margen rojo en x = 72 (`:146-147`). Desgaste con `HAND.wear(256×160, seed 1187, marked=false)` (`:150`).
- Cuatro lápices por asiento (`INKS`, `:41`): negro para el anfitrión, azul marino, rojo oscuro, verde oscuro; más marrón y púrpura para asientos 5 y 6. Grosor de lápiz 3,0; borrador 30 (`:42-43`). Los trazos se dibujan con `Line2D` de redondeo (`line_for`, `:486-503`).
- Envío: distancia mínima entre puntos 3 px (`SPACING`); trozos de hasta 96 puntos (`CHUNK`), o cada 0,1 s (`FLUSH`); hasta 3.000 operaciones por piso (`MAX_OPS`) (`:47-53`).
- Trazos que empiezan sobre el plano se guardan en coordenadas del edificio: tipo `MAP_KIND + planta*2 (+1 si borra)`, `MAP_KIND = 10` (`:22-29`).
- Mando: el pad mueve una punta con el stick izquierdo (`TIP_SPEED` 820 px/s, lento al dibujar, `TIP_DRAWING` 0,55; disparador derecho dibuja, izquierdo borra; umbral `TRIGGER` 0,35) (`:92-99`, `:406-452`). Puede recoger una pista si la mueve sobre ella y pulsa el disparador.
- Columna de notas (`fill_slips`, `:244-303`): título "TUS NOTAS" (18 px SOFT). Sin nada: "NADA TODAVÍA" (16 px FAINT). Carta (ancho de columna por 1,5 de alto) con los trozos encontrados, cada uno en su cuarto (`torn_letter.gd`). Las pistas van debajo, en miniatura de 112 px, en dos columnas, con un paso de hasta 84 px.
- Mostrar una pista: `hold_up` (`:307-329`), a tamaño de la página, con sombra al 0,5; un clic la baja.
- Plano (`sheet_map.gd`): "PLANTA %d" en la esquina a 18 px (`:175`). Ver sección 5.6.
- Cuando no se puede escribir (muerto): "SOLO PUEDES MIRAR, %s CIERRA" (`:216`).
- Apertura: fundido de 0,12 s, escala de 0,965 a 1,0 en 0,16 s, notas con retardo de 0,07 s (`open`, `:206-230`). Escala de la página: `fit = clamp(…, 0.3, 1.6)`.

### 5.4 Papeles (`hint_view.gd`, `hotel_form.gd`, `ruled_paper.gd`, `torn_letter.gd`, `handwork.gd`)

- `hint_view.gd` elige el papel por el `kind` de la pista (`:51-70`, `:80-89`). Tamaños de cada uno (`SIZES`, `:33`): `red` 960×680, `memo` 520×720, `resguardo` 300×620, `ficha` 720×450, `polaroid` 440×540, `calco` 460×600, `plano` 640×480, `nomolestar` 500×590, `hoja` 1.491×1.055. Formularios del hotel: `limpieza` y `orden` (`FORMS`, `:22`) usan `hotel_form`. `indicaciones` usa `ruled_paper` con la libreta.
- `hotel_form.gd`: 1.024×1.536 px (`CARD`, `:24`); mecanografiado con `TYPE` 26, `FIELD` 24, `FIELD_TOP` 21, `BOXED` 24 px (`:30-33`). Campos y líneas de la hoja en coordenadas fijas (`FIELDS`, `DATE`, `TIME`, `TYPES`, `ACTIONS`, `PRIORITIES`, `STATES`, `SIGNATURE`, `NOTES`, `:44-64`). Los renglones de detalle empiezan en 461 px, separación 31,78 px, 24 renglones, desde x 72 a x 968 (`:36-40`). Firma a pluma `PEN` (0,10; 0,12; 0,28; 0,9) (`:27`). Cinta negra `RIBBON` (0,08; 0,075; 0,09) (`:26`). Cada tecla: desplazamiento de letra por la tecla (±0,8/±1,8 px) y por el golpe (±0,8/±1,0 px), y opacidad `0,74 + (…)·0,26` (`type_line`, `:212-223`). Sombra del papel: 5,7 px.
- `ruled_paper.gd`: dos papeles. `carta` (`carta.png`, texto de 66 a 966, tipo 26, 33 renglones en y = 158…1409) y `libreta` (`libreta.png`, de 100 a 948, tipo 28, 23 renglones en y = 182…1413; recorte redondeado de 34 px) (`:15-26`). A lápiz (`GRAPHITE` (0,16; 0,15; 0,15; 0,92)), 32 px (`HANDWRITTEN`), o a máquina con `FORM.type_line` (`setup`, `:40-67`). Si está rota: 46 px bajo la última línea y 18 de irregularidad (`TEAR_BELOW`, `TEAR_RAGGED`, `:30-31`).
- `torn_letter.gd`: el punto de los dobleces en la imagen de la carta es (515, 767) px (`:16`). Cuatro cuartos (`quarter`, `:23-29`). El borde roto tiene 18 dientes y amplitud 9 (`:19-20`). Cada trozo lleva un dígito a lápiz (`GRAPHITE` (0,13; 0,12; 0,12)) y un texto de lugar bajo él (fuente 11 px, `:17,84`).
- `handwork.gd`: dígitos 0-9 como trazos de puntos en una caja unitaria (`STROKES`, `:14-25`); cada trazo se dibuja dos veces, la segunda un poco distinta (desplazamiento 0,045 / 0,03, grosor 1,0 / 0,65, opacidad 1,0 / 0,5) (`write_digit`, `:37-56`). Curvas Catmull-Rom con 10 pasos por tramo (`:59-65`). Línea de letra: fuente de sistema (`ThemeDB.fallback_font`), inclinación de hasta 0,035 rad y sombra en (0,7; 0,4) al 0,38 (`write_line`, `:70-76`). Manchas y pliegue: textura `Image` RGBA8 por píxel, cacheada por tamaño y semilla (`wear`, `:92-128`).

### 5.5 Archivo de documentos (`archive`, `show_dossier`, `show_document`)

- Pantalla `archive` (`:643-669`): título `ARCHIVO`, contador "DOCUMENTOS  n / 16" (`CATALOG.TOTAL`) en ámbar, lista de 16 entradas numeradas `%02d   título` o `sin descubrir` (desactivadas), en un `ScrollContainer` de 760×440. Columna de 760 px.
- Ficha al pulsar un documento leído (`show_dossier`, `:1193-1247`): papel `PAPER` (0,86; 0,84; 0,77), 780 px de ancho, tinta `PAPER_INK` (0,12; 0,11; 0,10). Cabecera "ARCHIVO DEL HOTEL" (15 px), "DOCUMENTO N.º %02d / %d" (22 px), sello "RESERVADO" en rojo (0,62; 0,10; 0,08) girado −0,12. Campos: DOCUMENTO, PROCEDENCIA y RELACIONADO CON (el nombre de la criatura: `CREATURES` = locust "THE LOCUST", sunman "SUNMAN", boiled "THE BOILED ONE", guilt "GUILT", `:1191`). Luego TRANSCRIPCIÓN (18 px, ancho 720), "FIN DEL DOCUMENTO" y `Cerrar`. Se cierra con el botón, con clic fuera (sombra al 0,78) o con ESC (`:2246-2249`).
- Documento sostenido en mano (`show_document`, `:1319-1361`): si tiene `form`, `FORM` con la cabecera en mayúsculas y la procedencia; si tiene `paper`, `RULED` con semilla `String(item.id).hash() % 1000`; si no, una tarjeta oscura de 720 px (cuerpo de 640 px) con título 28, procedencia 16 y cuerpo 20 px. Pie: "[TECLA] GUARDAR" (la tecla de interactuar, `settings.prompt_name("interact")`, o "E" si no hay ajustes).
- Pistas en mano (`show_hint` y `hold_paper`, `:1269-1313`): subtítulos sólo para `calco`, `plano` y `hoja` (`HINT_CAPTIONS`, `:1286`): "ZONA MARCADA EN EL MAPA" o "ZONAS MARCADAS EN EL MAPA". Escala por tamaño: 0,8 del ancho o 0,62 si no es "hoja entera"; hasta 0,93 del alto si lo es; tope de 1,4.

### 5.6 Plano de la hoja (`sheet_map.gd`)

- Muros vistos por el grupo, en tinta de agalla `INK` (0,32; 0,17; 0,09) y fantasma `GHOST` (0,48; 0,10; 0,24) (`:16-17`). Grosor 2,6 (`:18`). Desplazamiento fantasma (1,6; −1,1) (`:23`).
- Aparición: al ver un muro nuevo, una mancha de 0,9 s (`BLOOM`) con grosor 1,4 extra (`:21-22`).
- Desvanecimiento: un trazo se va rompiendo en trozos con su propio momento dentro de `FRAYING` = 0,35 y suavidad 0,1 (`fading`, `:144-147`).
- Temblor fijo por punto: `WANDER` = 0,45 px (`wander`, `:64-68`). Redibujado cada 1/24 s (`REDRAW`, `:29`).
- Encuadre: mínimo 40 m (`LEAST`, `:35`) con transición de 1,5 s (`EASE`, `:36`).
- Pinturas de otros (círculos de pistas): `marks` (`:50`).
- Cámara propia: un punto y una marca de dirección en tinta fantasma, pulsando con `Time.get_ticks_msec()` (`:207-215`). Lee `get_viewport().get_camera_3d()`.

### 5.7 Escritura a mano de la letra (`handwork.gd`)

Ver 5.4. Es el único lugar donde se usa `ThemeDB.fallback_font` para texto con aspecto manuscrito. Las pistas de tipo `calco` y `plano` usan `draw_string` con la fuente de `osd_style`.

---

## 6. Records, logros y parte de la cinta

### 6.1 Records (`records_board.gd`, `hotel_ui.gd:670-685`)

- Caja 1040×404 (`:16`). Pestañas `TABLONES`, `FICHA`, `COMPARAR` (`:25-27`). Se recuerda la pestaña (`view.tab`, `:29`).
- **TABLONES** (`:37-111`): dos desplegables de 290 y 250 px: `TABLÓN` (empresas de `RECORDS.COMPANIES`) y `TABLA` (`RECORDS.TABLES`). Lista con columnas: `""` 44, `TIEMPO` 104, `PUNTOS` 84, `""` 30 (la nota), `QUIÉN` 330, `CINTA Nº` 150, `FECHA` 110 (`COLUMNS`, `:35`). Cada fila es un `Button` de 27 px que abre la cinta (`show_tape`). La cinta recién terminada se resalta en ámbar. Sin líneas: "Todavía no hay ninguna cinta en este tablón."
- **FICHA** (`:136-172`): campo "Tu nombre" con marcador "Ingresa tu nombre" (`field` con `player_name`, 40 caracteres). Dos columnas de estadísticas: izquierda: PISOS SUPERADOS, CINTAS PERDIDAS, TIEMPO GRABADO, MEJOR TIEMPO A SOLAS, MEJOR TIEMPO EN EQUIPO, MEJOR PUNTAJE, MEJOR NOTA, VECES MÁS VALIOSO, LOGROS ("n / m"). Derecha: TELEVISORES ENCENDIDOS, NÚMEROS ENCONTRADOS, CÓDIGOS MARCADOS, MUEBLES REGISTRADOS, SALIDAS, MUERTES, VECES EN UN ARMARIO, METROS ANDADOS, PAPEL HABITUAL, y COMO THE LOCUST ("n caza(s), n captura(s)") sólo si hubo cazas.
- **COMPARAR** (`:217-272`): sin fichas de nadie, un texto explicativo y "Todavía no has jugado con nadie desde que existen las fichas." Con fichas: la propia (con el nombre del ajuste `player_name` o "TÚ") y hasta 3 más por página (`RIVALS_SHOWN`, `:18`). Filas de `RECORDS.CARD_ROWS`; la que lidera se marca en ámbar. Fila "PISOS JUNTOS". Paginación con `BoxButton` "◀ ANTERIORES" y "SIGUIENTES ▶" y "n DE m" (`:259-273`).
- Función `milestones(ui, page)` en `records_board.gd:181-212` (lista de logros por piso) **no tiene llamadas** en el repositorio (búsqueda por `milestones(`); sólo `tape_report.gd` tiene una función homónima que sí se usa.

### 6.2 Parte de una cinta guardada (`show_tape`, `:1100-1110`)

- OSD `▶ PLAY`. Título `PARTE DE LA CINTA`. Pestañas igual que el parte de fin de piso, con una sola opción "Volver a los records" (`menu("records")`).

### 6.3 Logros (`achievements_board.gd`, `hotel_ui.gd:686-693`)

- Caja 1040×430 con `ScrollContainer`. Cabecera: "n / m" (22 px ámbar), medidor de 260 px y porcentaje entero (`:33-40`).
- Comparación (sólo con Steam listo y amigos): desplegable `COMPARAR CON` con "Nadie" y los amigos (`:41-60`). Al elegir: `compare_achievements(id, name)` pide los logros al amigo (`net.steam.ask_achievements`), y llega por la señal `friend_achievements` (`hotel_ui.gd:1167-1179`).
- Cada fila (`:82-105`): icono de 52 px (si existe el PNG; si no, hueco), título 19 px (INK si está; SOFT si no), nota 14 px, fecha de la vez que se consiguió (15 px ámbar) o nada. Sin conseguir: icono con modulate `(0.55, 0.55, 0.55, 0.4)` (`:90`). Con comparación, una segunda columna con la fecha del amigo (150 px) (`:100-105`). Si Steam no tiene logros del amigo: "STEAM NO TIENE LOGROS DE %s EN ESTE JUEGO" (14 px FAINT, `:106-108`).
- Iconos: `res://assets/ui/achievements/%d_%s.png` (`:17`), con el piso y el id del hito. Sólo existen los del piso 1 (18 archivos).

### 6.4 Hitos del juego (dato de `game/floors/`, no leído en detalle)

- `floor_index.gd:16`: `RELEASED := [1]`. Sólo el piso 1 está liberado. `milestones(n)` devuelve `[]` para los pisos no liberados (`floor_index.gd:38-39`). Por eso el logro de la oficina (`office_floor.gd:38`) no sale en la pantalla de logros ni en la ficha.
- Según el catálogo (HITO.01 de `docs/textos_juego.txt`) el piso 1 tiene 18 hitos, y hay 18 iconos. No leí la lista `MILESTONES` de `hotel_floor.gd:52`. Los nombres del catálogo: PRIMERA CINTA, A SOLAS, SIN BAJAS, SIN ESCONDERSE, CINTA CORTA, CINTA DE VEINTE, EQUIPO ENTERO, LOS CUATRO, SEGUNDA TOMA, MANITAS, LOS CUATRO NÚMEROS, POR LOS PELOS, NI TE VIO, MÁS VALIOSO, CINTA DE PRIMERA, CINTA MAESTRA, A SALVO DEL CAZADOR, CAZA COMPLETA.

---

## 7. Multijugador, sala, reglas y dificultad

### 7.1 Multijugador (`multiplayer`, `:694-710`)

- Título `MULTIJUGADOR` a 64 px. Línea "%d A %d JUGADORES" con `NET.MIN_PLAYERS` y `NET.MAX_SURVIVORS` (20 px SOFT).
- Campo de nombre sin etiqueta, marcador "Ingresa tu nombre" (`player_name`). Si se deja vacío, la sala lo llama "Jugador" (comentario `:699`).
- Opciones: `Steam` (id `mp_steam`, desactivada si Steam no está listo; en ese caso aparece `net.steam.problem()` en 16 px), `IP / LAN` (`mp_ip`), `Volver` (`main`).

### 7.2 Steam (`mp_steam`, `:711-720`)

- Título `STEAM` (64). Línea "CON TUS AMIGOS DE STEAM, SIN ABRIR PUERTOS" (20). Opciones: `Crear sala` (`host_steam`), `Unirse a una sala` (`join_steam`), `Volver` (`multiplayer`).

### 7.3 IP / LAN (`mp_ip`, `:721-730`)

- Título `IP / LAN`. Línea "EN TU RED LOCAL, O POR INTERNET CON UN PUERTO ABIERTO". Opciones: `Crear sala` (`host`), `Unirse a una sala` (`join`), `Volver` (`multiplayer`).

### 7.4 Crear sala por IP (`host_ip`, `:731-749`)

- Campo `Puerto` (`host_port`, por defecto `NET.PORT`). Desplegable `Red` con "Todas las redes de este equipo" y las direcciones de `NET.local_addresses()`; guarda `host_bind` (`:739-743`).
- Opciones: `Abrir la sala` (`host_open`), `Volver` (`mp_ip`). Párrafo: "En tu red local basta con esto. Para jugar por Internet, el puerto tiene que estar abierto en tu router hacia este equipo (UDP); si no puedes abrirlo, usa Steam." (16 px, ancho 560).

### 7.5 Unirse por Steam (`join_steam`, `:750-779`)

- OSD `MULTIJUGADOR ▸ UNIRSE`, pie `STEAM`. Título `UNIRSE` (64), línea "STEAM" (20). Si no hay salas: "No se encuentran salas" (19).
- Caja derecha de 440×300 con lista de salas (una por amigo, con el nombre de la sala): al pulsar, `net.join_steam(lobby_id, name, character)` y `menu("steam_wait")`.
- Botones: `Volver` (`mp_steam`) y `Actualizar` (emite `join_steam`).

### 7.6 Invitar (`steam_invite`, `:780-809`)

- Título `INVITAR`. Línea "TUS AMIGOS CONECTADOS A STEAM". Si no hay ninguno: "Ninguno de tus amigos está conectado ahora." Si hay: lista con desplazamiento de altura `min(n, 7) × 38`, un botón por amigo que llama `steam.invite(id)` y recarga la pantalla con el aviso "Invitación enviada a %s: le llega al chat de Steam." o "Steam no dejó enviar la invitación a %s."
- Botones: `Abrir la ventana de Steam` (sólo si `overlay_ready()`), `Actualizar`, `Volver a la sala` (`lobby_back`).

### 7.7 Esperando a Steam (`steam_wait`, `:810-817`)

- Título `STEAM`. Línea de estado (`net.status`, o "Conectando…") en ámbar 20 px. Botón `Cancelar` (`lobby_leave`).

### 7.8 Unirse por IP (`join`, `:818-832`)

- Campos: `Dirección del anfitrión` (`join_address`, marcador "192.168.1.20", longitud 40) y `Puerto` (`join_port`, `NET.PORT`).
- Si la red ya está activa: el estado en ámbar. Si no: `Conectar` (`connect`). `Volver` a `lobby_leave` si hay red activa, o a `mp_ip` si no.

### 7.9 Sala (`lobby_screen`, `:960-1034`)

- Título `SALA` (64). OSD `MULTIJUGADOR ▸ SALA`, pie `ANFITRIÓN` si es el anfitrión.
- Para el anfitrión (`:969-1002`):
  - `Tipo de partida` (`NET.MODE_NAMES`, ancho 260) → `set_option("mode")`.
  - Si el modo es cooperativo (`COOP`): `Dificultad` (los nombres de `DIFFICULTY.ORDER`) y `Piso` (`FLOORS.numbers()`, "Piso n"). La dificultad también se guarda en los ajustes (`settings.set_value`).
  - Si es versus (`VERSUS`): `The Locust` con "Al azar" y los asientos conectados.
  - Casilla `Retomar el piso guardado` si hay un punto de control guardado.
- Para los demás: el modo, "Dificultad: …", "Piso n" y "The Locust: al azar" o el nombre (sólo lectura).
- Botones: `Empezar` (`lobby_start`, desactivado si `net.start_problem()` no está vacío; el motivo sale en 17 px SOFT), o "Esperando a que el anfitrión empiece…" (19 px) para los demás; `Personaje` (`lobby_character`), `Reglas` (`lobby_rules`), `Cerrar la sala` o `Salir de la sala` (`lobby_leave`).
- Columna derecha: "JUGADORES n / m" en ámbar 20 (`NET.seats_for(mode)`). Nombres en mayúsculas, 22 px: en ámbar el propio, en FAINT los desconectados, y "anfitrión" (15 px) bajo el asiento 1. Para el anfitrión: `Invitar amigos` (con Steam: abre la ventana o `steam_invite`), o con IP la dirección donde unirse (`net.where_to_join()[0]`, 16 px, ancho 340).

### 7.10 Dificultad (`difficulty_screen`, `:890-918`)

- OSD `MENU ▸ NUEVA PARTIDA`. Título `DIFICULTAD` (64). Línea "LA BESTIA QUE TE ESPERA EN EL HOTEL" (20).
- Un botón por dificultad (`DIFFICULTY.ORDER`, 30 px): nombre en `DIFFICULTY.title`. Al pulsar: `settings.set_value("difficulty", id)` y emite `begin`. Si el ajuste `floor2` tiene esa dificultad, aparece también `Piso 2` (emite `begin_floor2`) a su lado.
- Al enfocar una dificultad, la caja de la derecha (`describe_difficulty`, `:920-933`) muestra su nombre en ámbar 30 px y sus cuatro rasgos (`DIFFICULTY.TRAITS`, 18 px, ancho 470).
- Empieza enfocada la última elegida (`focus_wanted`, `:917`). `Volver` (`main`).

### 7.11 Reglas de la sala (`rules_screen.gd`, `hotel_ui.gd:837-852`)

- Título `REGLAS` (44). Ancho de 1040 px.
- Una fila por regla de `RULES.shown(creature_key, number)`: nombre en MAYÚSCULAS (18 px, 360 px de ancho; en ámbar si difiere del valor del juego). Para el anfitrión, un `OptionButton` de 380 px (17 px) con `rule.labels`; cambiarlo llama `net.set_option("rules", next)` con el resto de reglas cambiadas (`:55-61`). Para los demás, el valor en MAYÚSCULAS (18 px).
- Al posar el ratón o enfocar una regla (`tell`, `:105-115`) aparece su nota en una caja de 1.000×76 px (`DETAIL_SIZE`, `:23`): texto 18 px dentro de un `SubViewport` transparente, mostrado con `signal_wash` que va de 1 a 0 en 0,9 s (`DETAIL_IN`, `:24`). Una nota igual no vuelve a empezar.
- Pie: `Volver a la sala` (`lobby`) y, si es anfitrión, `Default` (`rules_reset`).

### 7.12 Menú en partida en línea (`online_pause`, `:853-863`)

- OSD `❚❚ MENÚ` con pie `LA PARTIDA SIGUE`, fondo al 0,75. Título `MENÚ` (72). Línea "LA PARTIDA NO SE DETIENE" (ámbar 20). Objetivo y progreso (`briefing_panel`), opciones `Continuar` (`online_resume`), `Ajustes` (`online_settings`), `Cerrar la sala` o `Salir de la partida` (`online_quit`), y `controls_panel(side)`.

### 7.13 Final en línea (`online_end`)

- Ver 5.1.

### 7.14 Personaje (`show_characters`, `:1917-1980`)

- OSD `MULTIJUGADOR ▸ PERSONAJE`. Título `PERSONAJE` (64). Una opción por nombre de `avatar_visual.gd:4` ("Detective Masculino", "Detective Femenino", "Exploradora"). Al elegir: guarda `character` y, si hay red, `net.set_character(index)`. `Volver` (por defecto a `multiplayer`).
- Vista previa 3D: `SubViewportContainer` de 460×500 a la derecha, `SubViewport` con mundo propio, fondo transparente, `UPDATE_ALWAYS`. Luz ambiental `#d8c9a8` energía 0,45, AgX. Foco `SpotLight3D` `#ffcf94` energía 6, alcance 8, ángulo 35 en `(1.4, 2.6, −2.2)`. Cámara FOV 38 en `(0.35, 1.05, −3.3)` mirando a `(0, 0.92, 0)`.
- Rótulo "SELECCIONADO: %s" en MAYÚSCULAS, ámbar, alineado a la derecha (`PJ.07`).

---

## 8. HUD y avisos en partida

### 8.1 Tarjeta de sector (`show_transit`, `hotel_ui.gd:2012-2045`)

- Pantalla negra (ColorRect) con título (54 px), regla de 280×2 en FAINT y el encargo (26 px ámbar), centrados. Llamada desde `hotel_main.gd:1005` con `kind.title_of(stage)`, `lifts.stage_errand(stage)` y `lifts.OPENING_CARD` (segundos).
- Tiempos según la duración `span = max(1,2; seconds)`: espera de 0,12·span; fundido a negro en 0,14·span; mantener 0,5·span; fundido de salida 0,16·span; luego se borra (`:2039-2045`).

### 8.2 Aviso de objetivo (`show_brief`, `:2068-2143`)

- Caja de 560×170 px (`BRIEF_SIZE`), en la esquina superior izquierda, a 30/112 px. Renderizado en un `SubViewport` y mostrado con `signal_wash` (entra de 1 a 0 en `BRIEF_IN` = 0,45 s; sale de 0 a 1 en `BRIEF_OUT` = 1,5 s; mantiene `hold − IN − OUT`; `BRIEF_HOLD` = 6,0 s por defecto).
- Dentro: "OBJETIVO, %s" (18 px ámbar), aviso opcional en ALERT 26 px (`lead`), y el objetivo (24 px, ajuste de línea). Si hay aviso, el objetivo aparece tras `BRIEF_LEAD` = 2,2 s y en 0,6 s.
- Detrás del velo de la hoja (`move_child` bajo `sheet`, `:2077`). Sombra de fondo (degradado radial, negro 0,66 en el centro).
- Textos de sector (`OBJETIVO, SECTOR 1 · …`) viven en el código del nivel (no leído). Ver sección 16.

### 8.3 Rebobinado (`show_rewind`, `hide_rewind`, `:2183-2196`)

- Marca `<< REW` + salto de línea + `SP` (30 px) arriba a la derecha (`:288-289`, un salto de línea literal, ver 21.1) y el contador `clock_words` (30 px) abajo a la izquierda. Se muestran sobre la nieve, en `marks_view`.

### 8.4 Aviso de salto y anillo (`show_skip`, `hold_ring.gd`)

- `skip_label` arriba a la derecha (17 px SOFT): "Mantén %s para saltar la cinemática" (`show_skip`, `:1995-2000`). Se queda 6 s y se desvanece en 1,2 s. Tecla = la de interactuar.
- `skip_ring` a la izquierda del texto (ancho 43 px, el tamaño de `HOLD_RING`; su borde derecho queda a −444 px de la derecha, centro en y = 36) (`:341-350`).
- `hold_ring` centrado en el punto de mira (`:332-340`). Se llena en sentido de las agujas del reloj desde arriba.

### 8.5 Anillo de mantener (`hold_ring.gd`)

- Radio 15, grosor 2,5 (`:13-14`). Se muestra desde 0,12 (`SHOW_FROM`). Sigue a lo pedido con `EASE` = 18 por segundo; se desvanece con `FADE` = 9 por segundo. Si no le llega una llamada a `hold()` en 0,08 s (`STALE`), se va. Pulso al llenarse: radio ×1,18 que decae a 3,5 por segundo (`:17-22`, `:40-53`).
- Color: `STYLE.INK`, que pasa a `AMBER` con el pulso. Trazo de fondo FAINT. Punto en la punta de 1,875 px (`:55-65`).
- Lo llama `hotel_main.gd` (no leído) en cada fotograma mientras se mantiene una tecla. `hold(fraction)` de `hotel_ui.gd:1984` y `hold_skip` (`:1988`).

### 8.6 Mensajes del HUD (`flash`)

- `flash(words, seconds)` (`:2160`): texto en `flash_label`, parpadea en los últimos segundos (`:2214-2219`). Se usa para "LLAVE DEL CUADRO ELÉCTRICO" (`code_lock.gd:425`) o "VISION ACUSTICA - PRUEBA LOCAL" (`hotel_main.gd:523`).

### 8.7 Hojas del plano y cerraduras

- Teclado de la última puerta (`show_lock`, `:1366-1407`): cuatro huecos (64 px) con los dígitos escritos (o "_"). Si hay `known`, "ANOTADO <texto>" (22 px SOFT). Con mando: fila de dígitos 0-9 (30 px), el elegido en ámbar (`dial`). Pie: con mando, "CRUCETA: ELIGE   %s: MARCA   %s: BORRA   %s: SALIR" (A, X, B); sin mando, "TECLEA EL CÓDIGO   [ESC] SALIR". La palabra de estado (`word`) en 18 px, en ALERT si es "NO ES".
- Sonidos del teclado (`keypad`, `:379-380`): "key" (1.900 Hz, 0,035 s), "wrong" (190 Hz ×2 con pausa, borde 0,6), "right" (1.046,5 y 1.568 Hz).
- Velo de fondo al 0,45.

### 8.8 Sonido de la interfaz (`hotel_ui.gd:355-361`, `osd_style.gd:230-269`)

- Todos son tonos generados en código, no archivos: `tick` 2.400 Hz 0,018 s nivel 0,12; `confirm` 1.250 Hz 0,07 s nivel 0,25. Los jugadores `AudioStreamPlayer` van al bus `Effects` con −6 dB.
- Frecuencias y duraciones de los tonos de teclado: ver arriba.

---

## 9. Créditos (`credits`, `hotel_ui.gd:866-874`, `:12-124`, `:1701-1729`)

- OSD `▶ PLAY`. Pie: `%s   PROYECTO FAN NO OFICIAL`, con `version()` (`"v" + ProjectSettings application/config/version`, `:10-11`). Título `CRÉDITOS` (64). `Volver` (`main`).
- `CREDITS` (`:18-124`): siete bloques de texto: "THE FOUR", "MOTOR", "PERSONAJES", "MOBILIARIO Y OBJETOS", "SONIDO DE FREESOUND", "SONIDO DE LAS OFICINAS", "EL RESTO DEL SONIDO", "LICENCIAS PENDIENTES".
- Lista de 720×384 con desplazamiento automático: 2,5 s de pausa, luego baja a 26 px por segundo (`:1724-1725`); se detiene con la rueda o el gesto del ratón (`:1726-1729`). Encabezados en ámbar 18 px; líneas 17 px con ancho 660.
- Dos líneas de "LICENCIAS PENDIENTES" (`:120-123`) dicen que el modelo de The Locust tiene CC BY-NC-ND y "Realistic Female" CC BY-SA, y que mientras sigan no se puede vender. Esto es un hecho del código, no una opinión.
- Línea 66: "YouniqueĪdeaStudio" (con Ī, U+012A); sin comprobar si es el nombre correcto.
- Línea 42: indentación con dos tabuladores (sólo estilo).

---

## 10. Intro overlay de arranque (`play_intro`, `hotel_ui.gd:2281-2370`)

Se muestra al arrancar, sólo si no es automatización ni observador ni repetición (`hotel_main.gd:347`).

Cronología (segundos desde el arranque):

- 0,0-0,3: fondo negro con el azul de vídeo (`VCR_BLUE` (0,09; 0,16; 0,62)) a alfa 0.
- 0,3-0,75: aparece el aviso "AURICULARES SUGERIDOS" (30 px MUTED) con el dibujo de auriculares (`STYLE.headphones(104)`) (`:2314-2328`).
- 0,75-2,35: aviso fijo. 2,35-2,8: desaparece. 2,8-3,1: silencio.
- 3,1: sonido de confirmación (`confirm_player`).
- 3,1-3,15: azul "VIDEO 1" (34 px, arriba a la izquierda, `:2298-2300`) y "▶ PLAY" (44 px, centro) (`:2301-2308`).
- 3,15-4,95: espera.
- 4,95-5,85: el sonido de estática sube de −60 a −16 dB; la estática del shader sube de 0 a 0,65.
- 5,85-6,35: estática de 0,65 a 1,0.
- 6,35-6,85: azul y negro ocultos. Espera.
- 6,85-8,45: la estática baja de 1,0 a 0 (SINE), el sonido baja a −60 dB.
- 8,45: `finish_intro()` (`:2364-2370`): quita la intro, `transition(0.6)` y `focus_first()`.

Saltar: cualquier tecla del teclado la termina (`_input`, `:2242-2244`). El ratón no (comentario `:2280`). Tiempos exactos: `intro_tween` (`:2342-2362`).

Fondo del overlay: `ColorRect` negro, `ColorRect` azul, textos. Ruido: `NOISE` (tape_noise) con `amount` (`:2332-2335`, `:2341`).

---

## 11. Intro en 3D: la escena de entrada (`game/intro/`)

### 11.1 Escena y tiempos (`intro_sequence.gd`)

- Nodo `Node3D` (`:1`). Duración `LENGTH` = 39,6 (`:39`). `speed` = 1,0 por defecto (`:56`), los tests lo suben (`intro_test.gd`). El tiempo avanza `time += delta * speed` en `_process` (`:245-246`).
- Golpes en la tele (`BLOWS`, `:43`): `[t, punto en el tubo (u,v), grieta]`: 26,4 s (0,46; 0,44; 0) · 28,0 s (0,47; 0,45; 0) · 29,5 s (0,6; 0,38; 0,9) · 32,95 s (0,4; 0,55; 1,0). Los dos primeros sólo sacuden; el tercero agrieta; el cuarto rompe el cristal a la espalda del jugador.
- Sonidos de los golpes (`:51-54`): `HIT_DB` [−8,2; −5,0; −5,5]; `KNOCK_DB` [−19,2; −16,3; −11,5]; `SHATTER_DB` 10,0; `BLOW_MAX_DB` 12,0.
- Cronología de eventos (`build_events`, `:177-200`): 0,3 respiración; 8,0 cama; 9,4 cama; 12,9 cama inclinándose; 16,5 `roll` de la tele de 0 a 1 en 0,6 s; 19,0 zumbido (drone) con fade a −20 dB en 8 s; 21,0 latido; 19,2 y 20,4 cama; 25,2 embestida (`lunge`); 29,9 cama se levanta; 32,5 puerta del dormitorio abre; 33,62 cierra de golpe; 34,2 gruñido; 34,8, 35,5, 36,1, 36,8 golpes de puerta; 37,25 empuje de la puerta siguiente; 37,6 golpe; 38,45 puerta lejana; 38,9 corte a negro (`cut`, 0,5 s).
- Cámara (`key()`, `:145-173`): keyframes de posición, mirada, FOV y tipo de paso. Ejemplos: 0,0 tumbado (FOV 72); 9,5 acerca a la tele (FOV 70); 15,8 inclinado (FOV 50); 30,3 (FOV 35, rigidez 60); 30,95 "pánico" (rigidez 140); 32,4-33,2 paso "pesado" y "corre" (rigidez 60-90); 33,52 giro brusco para cerrar la puerta (rigidez 420); 37,0-39,3 corredor; 39,3 a 39,6 "paso" hacia la recepción (`:172-173`).
- Muelles (`update_camera`, `:293-331`): amortiguación `2·√k·0,72` (`:296`), subpasos de 0,006 s (`:297`). Cabeceo de paso (`amplitude` 0,035 "walk", 0,06 "heavy", 0,07 "run", `:309`). Temblor de mano: `0,0035 + ground·0,004 + shake·0,02`, multiplicado por `motion` (`:319`). Inclinación al girar: `clamp(−yaw_vel·0,05, ±0,16)` (`:323`). `motion` (`:292`) lo fija la configuración "Movimiento de cámara" (el nivel lo pasa; no leído).
- Ojos cerrados al despertar (`update_lids`, `:349-359`): tramos de 2,0 a 7,0 s y cierre entre 39,1 y 39,55 s (`clamp((time − 39.1)/0.45)`).
- Tele (`update_screen`, `:363-383`): `peek` = smoothstep de 19 a 22 s; `lunge` = ease-out de 25,2 durante 0,4 s; `twitch` de 22 a 25 s; `image_amount` sube de 18,2 s en 1,5 s; `static_amount` de 1,0 a 0,3 según `peek`, más ráfagas al 4 % por fotograma; parpadeos (`flicker`) con probabilidad 0,02 + hasta 0,06 según el tiempo (`:376-378`); luz de la tele `(0,55 + rand·0,2 − peek·0,12)·(1 − flicker)·1,4 + flash·3,0` (`:382`).
- Latido (`update_heartbeat`, `:402-409`): de 70 a 140 bpm entre 21 y 33 s; volumen de −22 a −13 dB.
- Pesado: `flash` (`:215`, `:229`, decae 3 por segundo); `shake` (decae 1,6 por segundo); `jolt` (decae 4 por segundo).
- Mirada con el ratón sólo antes de 30 s (`_unhandled_input`, `:268-271`; sensibilidad 0,0015; límites ±0,45 y ±0,3).
- Fin: cuando `time >= LENGTH` emite `finished` (`:264-267`).

### 11.2 Escenografía y luces (`build_set`, `build_furniture`, `build_lights`, `:507-665`)

- Habitación (dormitorio −2,6..2,6 × −3,2..3,2), pasillo (2,6..5,0 × −14..4), sala iluminada (5..9 × −13,5..−8,5) y recepción (9..13,5). Muros con huecos (`set_wall`). Puertas con número `107`, `112`, `109`, `108`, `110` (`intro_sequence.gd:533-539`). Cama, cómoda de 1,6 m con la tele de `TV_SCALE` 1,45 (`:33`), luminaria, cuadros.
- Luces: la tele (`OmniLight3D`, color `(0.72, 0.82, 1.0)`, alcance 8, atenuación 1,4, sombras; `light_cull_mask = ~2` para no iluminar su propia carcasa) (`:602-612`); lámpara cálida `#ffb877` 3,0 (`:614-620`); lámpara roja de la recepción `(1,0; 0,1; 0,06)` 2,4 que parpadea 1,6 s (`:262-263`); cartel de salida verde 0,07; resplandor de noche 0,24 en el pasillo.
- Sonido: buses `Effects`, `Threat` y `Steps` (`:447-470`). Cada golpe es un `AudioStreamPlayer3D` con `unit_size` 4 o 6, atenuación de 3.000 Hz (`:453`) y `max_db` 12 (`:449-450`). Ficheros: `assets/audio/intro/tv_static.wav`, `tv_whine.wav`, `glass_knock_1..3.wav`, `door_bang_1..3.wav`, `stomp_1..3.wav`, `bed_*.wav`; `assets/audio/glass/glass-hit-1..3.ogg` y `shatter.wav`; puertas en `assets/audio/sfx/door/…`; latido en `assets/audio/sfx/heartbeat/1.ogg` y `2.ogg`.
- Solo se reproduce si `audible` (`:442`): `get_parent().world_audio.enabled` si existe.

---

## 12. Portada (`game/title/title_scene.gd`)

- `Node3D`, `process_mode = ALWAYS` (`:39`). Se instancia desde `hotel_main.gd:330-333` en `TITLE_ORIGIN`. Visible sólo mientras el menú está (`set_active`, `:162-165`; `update_title_scene` en `hotel_main.gd:1402-1405`).
- Habitación de 6,4 × 7,2 m (`:65`), con pasillo al fondo (`:66`), y puerta (`DOORWAY` (1,7; 0; −3,6)) entornada (`AJAR` = 0,44 rad, `:25`).
- Criatura (`MODEL` = `locust.glb`, escala 1,95, `:52`) en `LOCUST_AT` (0,99; 0; −3,95) (`:23`), pose de asomarse con `POSER.pose_peek` (`:159`) y "tics" de cabeza cada 6 a 14 s (`:148-153`).
- Cámara propia (FOV 58 con `CAMCORDER.fov_for`, `:59,140`; en `CAMERA_AT` (−2,3; 1,5; 1,5), mirando a `LOOK_AT` (−1; 1,35; −3,6), `:26-27`). Deriva a mano con senos de frecuencias 0,05-0,23 (`:141-143`).
- Luces: domo cálido `#ffcf94` 2,3 (alcance 7,5, sombras), luz de noche 0,12, resplandor 0,55 cerca de la criatura (`:105-132`).
- Semilla del azar: `rng.seed = 2204` (`:40`).

---

## 13. Tipografía y tema

### 13.1 Fuentes

- **Fuente principal (`osd_style.gd`)**: `FONT_PATH = res://assets/fonts/vcr_osd_mono.ttf` (`:4`). **No existe en el repositorio** (no hay carpeta `assets/fonts`; búsqueda de `*.ttf`, `*.otf`, `*.woff`, `*.fnt` sin resultados). Por tanto se usa `SystemFont` con `font_names = ["VCR OSD Mono", "Consolas", "Menlo", "Lucida Console", "Courier New", "monospace"]`, `font_weight = 600`, `antialiasing = GRAY` (`:23-29`). El comentario (`:24-25`) dice que Menlo es la alternativa de Mac.
- **Mecanografía (`hotel_form.gd:76-84`)**: `SystemFont` con `["Courier New", "Courier", "Nimbus Mono PS", "Liberation Mono", "monospace"]` y `FontVariation` con `variation_embolden = 0.5`.
- **Escritura a mano (`handwork.gd:71`)**: `ThemeDB.fallback_font` (la fuente de respaldo de Godot), con un `sin`/`cos` para inclinar y desplazar (ver 5.4).
- **Tema (`osd_style.gd:46-125`)**: `Theme` creado en código. `default_font` = la fuente OSD; `default_font_size` = 20. Sombra de 2 px `SHADE` (0; 0; 0; 0,85) en `Label`, `Button`, `CheckButton`, `OptionButton`, `TabBar`, `TabContainer` y `PopupMenu` (`:52-55`).
- Tamaños usados: desde 11 px (textos de la pista) hasta 104 px (título del menú principal). Los más usados: 15-22 px en pantallas de datos; 17-19 px en columnas; 64 px en títulos de pantalla (`title(…, 64)`).

### 13.2 Paleta (`osd_style.gd:5-14`)

- `INK` (0,94; 0,94; 0,90). `SOFT` = INK con alfa 0,62. `FAINT` = INK con alfa 0,22. `ALERT` (0,93; 0,22; 0,14). `AMBER` (0,96; 0,78; 0,40). `SHADE` (0; 0; 0; 0,85). `MUTED` (0,58; 0,58; 0,56). `VCR_BLUE` (0,09; 0,16; 0,62).
- Papel (`paper_sheet.gd:40`): `PAPER` (0,86; 0,82; 0,71). Tintas de la hoja (`:41`): (0,10; 0,10; 0,11), (0,11; 0,16; 0,38), (0,44; 0,09; 0,09), (0,09; 0,29; 0,13), (0,36; 0,20; 0,06), (0,29; 0,10; 0,33).
- Papeles sueltos: `hint_view.gd:23-31` (PAPER, PRINT (0,13; 0,12; 0,11), GRAPHITE, RED (0,62; 0,10; 0,08), CARBON (0,11; 0,11; 0,19; 0,62), OTHER (0,29; 0,10; 0,33), PLAN_INK (0,32; 0,17; 0,09)). `hotel_form.gd:26-27` (RIBBON, PEN). `hotel_ui.gd:1186-1187` (PAPER (0,86; 0,84; 0,77), PAPER_INK (0,12; 0,11; 0,10)).

### 13.3 Temas de botones (`osd_style.gd:58-82`)

- `Button` sin fondo, texto SOFT, con foco INK, pulsado AMBER, desactivado FAINT.
- `BoxButton` (variación de `Button`): fondo negro 0,35, borde FAINT 1 px, margen interior 8, con estados de foco e INK y pulsado AMBER.
- `OptionButton` y `CheckButton`: caja con borde, flecha dibujada en 12×8 (`:89`). Casilla: iconos de 22×22 dibujados por código (`pixel()`, `:79-82`).
- `HSlider`: línea de 2 px FAINT, relleno INK, controlador de 10×22 INK (AMBER al foco) (`:95-106`).
- `ProgressBar`, `PanelContainer` (negro 0,5, borde FAINT, margen 18), `TabContainer` (pestaña seleccionada con fondo blanco 0,08), `ScrollContainer` (barra de 1 px) (`:107-123`).
- `LineEdit`: borde 1 px FAINT, foco INK, cursor AMBER (`:84-88`).
- `PopupMenu`: fondo negro 0,96 (`:90-93`).

### 13.4 Estilo de cajas

- `STYLE.flat(color, border, width, margin)` (`osd_style.gd:38-44`).
- Paneles: `Color(0.02, 0.02, 0.02, 0.82)` o `0.86` con borde FAINT y margen interior 16-22 (`hotel_ui.gd:767`, `:926`, `:1505`).

---

## 14. Sombreadores de interfaz

### 14.1 `game/ui/shaders/signal_wash.gdshader` (51 líneas)

- `canvas_item`. Uniform `wash` (0-1, por defecto 0; `:5`). El 0 es la imagen limpia y el 1 no deja nada.
- Por fotograma: `frame = floor(TIME * 24.0)` (`:21`). Ondulación: `sin(uv.y·24 + TIME·5)·0,022 + sin(uv.y·71 − TIME·13)·0,009` (`:24`). Desgarros por filas: 22 filas (`:26`), probabilidad `step(1 − w·0,8, hash)`, desplazamiento ±0,07 (`:27`). Cabeceo vertical `sin(uv.x·5 + TIME·3)·0,025·w` (`:29`).
- Arrastre: paso horizontal `TEXTURE_PIXEL_SIZE.x·(1 + 9·w)` (`:31`), paso vertical ·3·w (`:32`); pesos 0,28 / 0,18 / 0,10 / 0,08 (`:33-36`); el canal rojo se desplaza 1,5 pasos (`:38`).
- Nieve: `hash(floor(FRAGCOORD.xy/2) + frame·17)` (`:40`), grano de 3 px (`:41`), tono nieve `(0,85; 0,85; 0,82)`, mezcla 0,75 (`:42`), alfa `1 − w²·0,6` (`:44`).
- Nieve en el espacio vacío (`haze`, `:47-49`) con bordes suaves (`smoothstep` de 0,08, 0,25, 0,3) y tope de 1,8.
- Lo usan: el aviso de objetivo (`hotel_ui.gd:2059`), el detalle de reglas (`rules_screen.gd:17`).

### 14.2 `game/ui/shaders/tape_noise.gdshader` (20 líneas)

- Uniforms `amount` (0-1) y `tint` (0,85; 0,85; 0,82). Celdas de 2 px (`:13`), fotograma de 30 Hz (`:14`), banda que sube (`smoothstep(0,82; 1,0)`, `:17`), valor `nieve·0,75 + bandas·0,35` (`:18`), alfa `amount·(0,55 + 0,45·nieve)` (`:19`).
- Lo usan el fondo de menús (`hotel_ui.gd:424-430`) y la intro (`intro_sequence.gd:119-122`, `:2332-2335`). Lo carga también `intro_sequence.gd:22`.

### 14.3 `game/presentation/shaders/typewriter_ink.gdshader` (32 líneas, fuera de `game/ui`)

- `canvas_item`. Uniform `grain` 0-1, 0,5 por defecto (`:7`). Usa `VERTEX` en coordenadas locales (`vertex()`, `:22`) para que el ruido sea del papel y no de la pantalla.
- Ruido de tejido `noise(local·0,85)` y "sequedad" `noise(local·(0,012; 0,05))` (`:28-29`). Tinta: `mix(1, 0,45 + 0,55·weave, grain) · mix(0,72, 1, dry)` (`:30`), que multiplica el alfa.
- Lo usan `hotel_form.gd:22` y `ruled_paper.gd:10` (en el papel mecanografiado; el papel a lápiz no lo usa, `ruled_paper.gd:60-64`).

### 14.4 `game/intro/tv_screen.gdshader` (101 líneas, `spatial`, sin luces)

- `render_mode unshaded, cull_back` (`:2`). Uniforms (`:11-32`): `screen_rect` (0,0128; 0,1364; 0,9745; 0,7213) (`:11`), `power`, `static_amount`, `image` (la textura del SubViewport de `tv_broadcast.gd`), `image_amount`, `cracks` (textura de `crack_pattern.gd`), `crack_level` (0-4), `flash`, `roll`, `unstable`, `flicker`, `brightness`, `open` (apertura de la línea central), `tint_blue` (tono frío de la tele apagada).
- Fotograma de 60 Hz (`:49`). Líneas de barrido: 240 líneas (`:58`), con alternancia de campo (`:77`, `sin(·480…)`). Rejilla de apertura: 1.100 franjas (`:80`). Viñeta `smoothstep(0,16; 0,5)` ×0,75 (`:85`). Grietas: desplazamiento `·0,012` (`:55`), oscurecimiento al 0,75 y brillos (`:97-99`).
- Lo carga `intro_sequence.gd:576`.

### 14.5 Shaders del filtro de cinta (fuera de alcance)

- `analog.gdshader` en `game/presentation/` (no leído). Recibe `marks` (`hotel_ui.gd:2174-2176`) y `marked` (`:2229`).

---

## 15. Teclado, ratón y mando en los menús

### 15.1 Teclado

- Enfoque y navegación: el propio `Button`/`Control` de Godot (flechas, Tab, Enter). El ratón enfoca al pasar (`entry`, `:523`).
- `_input` (`hotel_ui.gd:2241-2277`), en este orden:
  1. Si hay intro overlay: cualquier tecla la termina (`:2242-2244`).
  2. Si hay un documento abierto: `ui_cancel` o ESC lo cierra (`:2246-2249`).
  3. Si se está reasignando un botón de mando: el botón elegido; B cancela (`:2250-2257`).
  4. Si hay pestañas: `JOY_BUTTON_LEFT_SHOULDER` / `RIGHT_SHOULDER` cambian de pestaña (`:2260-2264`).
  5. Si hay pestañas y no es Ajustes: Q y E cambian de pestaña, salvo si el foco está en un `LineEdit` (`:2265-2268`).
  6. Si se está reasignando una tecla: ESC cancela, otra tecla se asigna (o avisa "TECLA RESERVADA O EN USO") (`:2269-2277`).
- Teclas usadas en la interfaz: ESC (cancelar, pausa), Q y E (pestañas de records, parte y marcas), tecla de interactuar (guardar un papel, la pantalla de documento, teclado), y la tecla de la hoja.
- Teclado de la cerradura sin mando: se teclea el código y ESC sale (`hotel_ui.gd:1404`). Con mando, la cruceta elige el número y los botones marcan, borran y salen (ver 8.7).

### 15.2 Ratón

- `mouse_entered` enfoca el botón (`entry`, `:523`; `line_button`, `:121`). Clic en un botón: `confirm()` + acción.
- Clic fuera de un documento: cierra (`:1204`). Clic en una pista sostenida sobre la hoja: la baja (`paper_sheet.gd:313-314`).
- En la hoja compartida: botón izquierdo dibuja, botón derecho borra; la rueda no se usa en la interfaz (la cámara sí, fuera de alcance).
- Velo de ratón en la intro: el ratón no salta la intro del arranque (`:2280`).

### 15.3 Mando

- `settings.pad_present()` y `settings.using_pad` deciden qué textos y botones se muestran (`:1119-1121`, `:1542`, `:1621`, `:1643`).
- Pestañas: hombros LB/RB (botones de `JOY_BUTTON_LEFT_SHOULDER` y `RIGHT_SHOULDER`) (`:2261-2263`).
- Navegación en pantallas con filas: `chain_settings()` enlaza las filas de cada pestaña en orden, con "Volver" al final (`:1772-1791`). Entre la barra de pestañas y la primera fila (`aim_tab`, `:1806-1816`).
- Pantallas sin filas (créditos, partes de la cinta): la acción `look_up`/`look_down` desplaza el `ScrollContainer` (qué stick o cruceta la liga no lo comprobé; el mapa de entrada no está leído), con `Input.get_axis("look_up", "look_down") · 900 px/s` (`:2206-2208`, `pad_scroll` `:1765`).
- Teclado de cerradura con mando: la cruceta elige el dígito, A marca, X borra, B sale (`:1403-1404`).
- En la hoja compartida: stick izquierdo mueve la punta del lápiz (`Input.get_vector("left", "right", "forward", "backward")`, `paper_sheet.gd:413`); disparador derecho dibuja, izquierdo borra (`JOY_AXIS_TRIGGER_RIGHT` / `LEFT`, umbral 0,35). Detecta mandos con `Input.get_connected_joypads()` (`:402,407`).
- Anillo de mantener: la tecla de interactuar (o su botón) (texto en `show_skip`).

---

## 16. Idiomas y dónde viven los textos

- **Idioma único: español.** No hay `tr()`, `TranslationServer`, `.po`, `.csv` de traducción ni `locale` en el proyecto (búsqueda en `game/`). Los textos están escritos en los `.gd` y en `docs/textos_juego.txt` sólo como catálogo.
- **Textos en `game/ui/`, `game/title/`, `game/intro/`:** literales en el código (`hotel_ui.gd`, `records_board.gd`, `tape_report.gd`, `achievements_board.gd`, `rules_screen.gd`, `paper_sheet.gd`, `hint_view.gd`, `hotel_form.gd`, `ruled_paper.gd`, `torn_letter.gd`, `sheet_map.gd`, `handwork.gd`, `intro_sequence.gd`). `interface.tscn` no contiene texto.
- **Nombres de los textos en el código** (cuenta aproximada): `label(` 89 llamadas en la carpeta; `STYLE.cell(` 51; `STYLE.text(` 23; `paragraph(` 27; `action(` 44; `entry(` 16; `spacer(` 77.
- **Textos que vienen de otros archivos** (no leídos): el encargo de cada tarjeta de sector (`lifts.stage_errand`, `kind.title_of`) en `game/app/` y `game/floors/`; las palabras de `InteractionHint` (`game/app/interaction.gd`, `executions.gd`, `hotel_floor.gd`, `objectives/*.gd`); los nombres de las reglas (`game/floors/match_rules.gd`); los nombres de las dificultades y sus rasgos (`game/floors/difficulty.gd`); los nombres de las empresas y tablas (`game/services/records_service.gd`); los nombres de los presets (`game/presentation/graphics_presets.gd`, leído en parte); los títulos de los pisos (`game/floors/floor_index.gd:34`); los nombres de los papeles y sus motivos (`game/services/run_score.gd`); el mensaje "PREPARANDO LA IMAGEN" (`game/presentation/shader_warmup.gd`); "LA CAZA EMPIEZA EN" (`game/enemies/locust/locust_player.gd`).
- **Mayúsculas:** `entry()` pone el texto en MAYÚSCULAS (`:513`); `title()` no. Los textos de la hoja y de los papeles se escriben tal cual.
- **Inglés dentro del texto español:** "THE LOCUST" (`hotel_ui.gd:1191`, `tape_report.gd:228`, `records_board.gd:172` "COMO THE LOCUST", `tape_report.gd:327` "The Locust atrapó a %s"), "SUNMAN", "THE BOILED ONE", "GUILT" (`hotel_ui.gd:1191`), "Freesound" y "Sketchfab" (créditos). Son literales del código y aparecen igual en el catálogo.
- **Caracteres no ASCII usados en la interfaz** (contados en `game/ui/`, `game/title/` y `game/intro/`): « » (81 cada uno, en créditos y en textos de la sala), vocales acentuadas y ñ (en el texto español), ▸ (15), ▶ (9), ❚ (4), ■ (4), ◀ (3), … (6), × (6), − U+2212 (2), ↑ ↓ (1 cada uno), □ (1), ★ (1), © (3), ² (1), Ī (1), y cirílico (sólo en el nombre de un modelo de créditos). No aparecen el punto medio (U+00B7) ni la raya (U+2014) en el código de la interfaz (verificado). Hay un guion medio (U+2013) sólo en un comentario (`crack_pattern.gd:6`).
- **Catálogo de revisión** (`docs/textos_juego.txt`, 1.687 líneas): 22 secciones con identificadores (ARRANQUE, MENÚ, PAUSA, CONTROLES, CARGA, FIN, MUERTE, RECORDS, CRÉDITOS, MULTIJUGADOR, AJUSTES, HUD, HOJA, CÁMARA, SUBTÍTULOS, ERRORES, CARTELES, OTROS, DOCUMENTOS, LOCUST, OBSERVADOR, PISTAS). No lo carga ningún programa (la búsqueda por `textos_juego` sólo lo cita en `README.md`, `docs/README.md` y `.claude/specs/spec_f3_integration.md`).

---

## 17. Clases y nodos de Godot que usa esta parte (recuento aproximado)

Recuento de `Clase.new(` en `game/ui/`, `game/title/` y `game/intro/`:

| Clase | Apariciones | Dónde se usa (principal) |
|---|---|---|
| `VBoxContainer` | 28 | columnas de todas las pantallas |
| `Control` | 24 | cajas de dibujo, capas, anclas |
| `HBoxContainer` | 19 | filas de datos y botones |
| `ColorRect` | 15 | velos, cajas de color, fondos de transición |
| `OmniLight3D` | 10 | luces de la intro y de la portada |
| `ShaderMaterial` | 8 | ruido, lavado, tinta, tele |
| `Button` | 8 | entradas de menú, casillas de filas, BoxButton |
| `PanelContainer` | 7 | paneles de la ficha, de controles y de reglas |
| `OptionButton` | 7 | desplegables de ajustes, sala, reglas, tablones |
| `MeshInstance3D` | 7 | muebles de la intro y de la portada |
| `TextureRect` | 6 | fondos y papeles |
| `ScrollContainer` | 6 | listas largas |
| `RandomNumberGenerator` | 6 | semillas (portada, hoja, papeles) |
| `Node3D` | 6 | escenas 3D y pedestal de personaje |
| `CenterContainer` | 5 | centrado de avisos y documentos |
| `SubViewport` | 4 | marcas sobre la nieve, aviso de objetivo, detalle de reglas, pista |
| `Camera3D` | 4 | intro, portada, personaje |
| `TabContainer` | 3 | records, parte de cinta, ajustes |
| `Label` | 2 | `Label.new` directo (el resto por `STYLE.text`) |
| `CheckButton` | 2 | casillas de la sala y de ajustes |
| `HFlowContainer` | 2 | fila de reglas y de finales |
| `GradientTexture2D` | 3 | degradado de fondo, halo de aviso, viñeta |
| `Gradient` | 3 | ídem |
| `AudioStreamPlayer` | 3 | tonos de la interfaz, tecla, confirmación |
| `AudioStreamPlayer3D` | 1 | sonidos de la intro |
| `AudioStreamWAV` | 2 | tonos y pitidos sintéticos (`osd_style.gd`) |
| `WorldEnvironment` | 2 | intro y personaje |
| `Environment` | 2 | intro y personaje |
| `SystemFont` | 2 | fuente OSD y mecanografía |
| `FontVariation` | 1 | mecanografía en negrita ligera |
| `StyleBoxFlat` | 2 | cajas generadas (`flat()`) |
| `StyleBoxEmpty` | 1 | botones sin fondo |
| `Theme` | 1 | tema de la interfaz |
| `SpotLight3D` | 2 | intro y personaje |
| `Line2D` | 1 | trazos de lápiz de la hoja |
| `HSlider` | 1 | deslizadores de ajustes |
| `LineEdit` | 1 | campo de nombre y de dirección |
| `GridContainer` | 1 | cuadrícula de hitos (sólo en el archivo sin llamadas) |
| `MarginContainer` | 1 | márgenes del marco de menús |
| `Panel` | 1 | página de la hoja |
| `SubViewportContainer` | 1 | vista previa del personaje |
| `BoxMesh` | 2 | suelo y paredes de la portada |
| `SphereMesh` | 1 | lente del piloto de la intro |
| `StandardMaterial3D` | 1 | material de la lente |
| `Image` (`create`) | 6+ | texturas procedurales (`handwork`, `osd_style`, `crack_pattern`) |
| `ImageTexture` | 3 | ídem |

Llamadas de dibujo y de API (apariciones en la carpeta): `draw_line` 19, `draw_rect` 16, `draw_texture_rect` 12, `draw_colored_polygon` 10, `draw_circle` 10, `draw_string` 7, `draw_arc` 6, `draw_polyline` 5, `draw_set_transform` 3, `draw_char` 2, `draw_polyline_colors` 2, `draw_set_transform_matrix` 2, `Geometry2D.intersect_polyline_with_polygon` 1, `set_pixel` 4, `get_pixel` 2.

Tweens: `create_tween` 15, `tween_property` 17, `tween_method` 9, `tween_interval` 13, `tween_callback` 7; enums `Tween.TRANS_SINE` 3, `TRANS_CUBIC` 2, `TRANS_QUAD` 1, `EASE_OUT` 5, `EASE_IN` 2.

Parámetros de shader (`set_shader_parameter`, 20 llamadas): `wash` (4), `amount` (3), `unstable`, `static_amount`, `marks`, `marked`, `image_amount`, `image`, `flicker`, `flash`, `cracks`, `crack_level`.

Otras APIs: `get_viewport()` 13, `get_tree()` 6, `call_deferred` 10, `grab_focus` 11, `queue_redraw` 8, `is_visible_in_tree` 6, `Input.` 5, `OS.` 6, `DisplayServer` 2, `RenderingServer` 1, `ProjectSettings` 1 (`hotel_ui.gd:11`), `Time.` (`achievements_board.gd:103`, `sheet_map.gd:213`), `ResourceLoader.exists` (`achievements_board.gd:88`, `osd_style.gd:20`), `load()` de PNG y `.res`, `String.hash()` (`hotel_ui.gd:1341`), `Viewport.SCALING_3D_MODE_*` (`hotel_ui.gd:1576,1580,1587`), `Environment.TONE_MAPPER_AGX` (`hotel_ui.gd:1957`) y `TONE_MAPPER_FILMIC` (`tv_broadcast.gd:40`), `Node.PROCESS_MODE_ALWAYS` (`hotel_ui.gd:248,316`, `title_scene.gd:39`), `TextServer.AUTOWRAP_WORD_SMART` (`hotel_ui.gd:454`, `rules_screen.gd:88`), `SubViewport.UPDATE_ALWAYS/ONCE` (`hotel_ui.gd:274,1945`, `rules_screen.gd:84`).

Del motor de GodotSteam (usado desde la interfaz, en `net`): `steam.ready_to_play`, `steam.problem`, `steam.friends`, `steam.online_friends`, `steam.friend_rooms`, `steam.invite`, `steam.overlay_ready`, `steam.ask_achievements`, señal `steam.friend_achievements`.

Clases propias (preload): `osd_style`, `handwork`, `hotel_form`, `ruled_paper`, `hint_view`, `paper_sheet`, `sheet_map`, `torn_letter`, `tape_report`, `records_board`, `achievements_board`, `rules_screen`, `hold_ring`, `tv_broadcast`, `crack_pattern`, `title_scene`, `intro_sequence`, y de otras carpetas: `graphics_presets`, `camcorder_look`, `hotel_geometry`, `floor_definition`, `locust_look`, `locust_poser`, `avatar_visual`, `net_session`, `records_service`, `run_score`, `match_rules`, `difficulty`, `discovery_catalog`, `footstep_segments`, `grunt_segments`, `cue_timing`, `floor_index`.

---

## 18. Constantes y cifras que definen cómo se siente o se ve

### 18.1 Interfaz general

- Medidas de los menús: columna 520 (`hotel_ui.gd:410`); márgenes 96/110/90 (`:398-403`); separación entre columnas 56 (`:406`); columna de logros 1040 (`:689`), de reglas 1040 (`rules_screen.gd:18`), de parte 1040 (`tape_report.gd:18`), de records 1040×404 (`records_board.gd:16`), de ajustes 1000 (`hotel_ui.gd:1539,1548`), de créditos 720 (`:870`).
- Estática del menú: `noise_amount` sube con `transition(strength)` (`:569-574`), baja hacia `noise_floor` a 2,2 por segundo (`:2209`). `failed` pone 0,16 (`:628`).
- Transición: fundido 0,28 s con retardo 0,06 s (`:573`); la fuerza de la estática por defecto 0,5 (`:569`), 0,35 en menús normales y 0,9 al perder (`:883`).
- Texto de avisos: 17 px (`:1007`), 15 px en el pie de la sala, 14 px en pistas de logros.
- `Flash` 30 px a 48 px desde la izquierda (interface.tscn:18-23); `Subtitle` 22 px, centrado (interface.tscn:25-40).
- Velocidad de desplazamiento del stick en listas: 900 px por segundo (`:2208`).
- Cuenta ascendente de cifras: 1,1 s con cúbica de salida (`tape_report.gd:66`).
- Sellos de la cinta: aparecen cada 0,35 s desde 0,9 s (`:138-141`), o cada 0,3 s desde 0,5 s en los logros (`:350-352`).
- Rotación del sello "RESERVADO" −0,12 rad (`hotel_ui.gd:1228`); del sello de la nota −0,1 (`tape_report.gd:95`); de las marcas de logros −0,03 (`:140,351`).

### 18.2 Hoja compartida y papeles

- Página 1.600×1.000 (`paper_sheet.gd:32`), tiras 250 px (`:45`), miniatura 112 px (`:200`), paso entre miniaturas 84 px (`:284`).
- Lápiz 3,0; borrador 30 (`:42-43`). Espaciado de puntos 3 px (`:49`). Trozo de 96 puntos (`:51`). Envío cada 0,1 s (`:47`). Máximo 3.000 trazos por piso (`:53`).
- Mando: velocidad de la punta 820 px/s (`:92`), 0,55 al dibujar (`:93`), umbral de disparador 0,35 (`:94`). Curva de aceleración `(0,25 + 0,75·push)` (`:421`).
- Abrir la hoja: alfa 0,12 s; escala de 0,965 a 1 en 0,16 s; notas con retardo de 0,07 s (`:221-230`).
- Plano: desde 0,22 de alto y 0,335 de ancho (`:35`). Intervalo de redibujado 1/24 s (`sheet_map.gd:29`). Mínimo de encuadre 40 m (`:35`); transición 1,5 s (`:36`).
- Hoja de limpieza 1.024×1.536 (`hotel_form.gd:24`).
- Renglones de la libreta 23 y los de la carta 33 (`ruled_paper.gd:18,23`).
- Tinta de la pista: alfa 0,74 a 1,0 por tecla (`hotel_form.gd:221`).

### 18.3 Intro 3D

- `LENGTH` 39,6 (`intro_sequence.gd:39`). Golpes en 26,4 / 28,0 / 29,5 / 32,95 s (`:43`). Corte a negro en 38,9 s (`:199`); cierre de ojos 39,1 s (`:358`).
- Tiempo de bloqueo de golpes: `hit − 0,1` a `hit` para la preparación; `hit + 0,12` para el golpe; recuperación 0,43 s (`tv_broadcast.gd:126-133`).
- Pantalla de la tele: 640×480 (`tv_broadcast.gd:26`); la textura de grietas 1.024×768 (`crack_pattern.gd:8-9`).
- Pulso del latido: 70 a 140 bpm entre 21 y 33 s (`:406`).
- Cámara: FOV entre 35 (acercarse a la tele, `:158`) y 76 (la huida, `:165-167`). Muelles con rigidez de 20 a 420 (`:150-173`).
- Tiempos de la tele: `peek` 19-22 s (`:364`); `twitch` 22-25 s (`:367`); `lunge` 25,2 s en 0,4 s (`:366`).

### 18.4 Portada

- Criatura: escala 1,95 (`title_scene.gd:52`), altura de la sala 2,9 (`:16`), FOV 58 (`:59`), tic cada 6 a 14 s (`:150`), decaimiento 5 por segundo (`:153`). Semilla 2204 (`:40`).

### 18.5 Shaders

- `signal_wash`: 24 fotogramas por segundo (`:21`); 22 filas de desgarro (`:26`); tono nieve 0,85 (`:42`).
- `tape_noise`: 2 px por celda (`:13`); 30 fotogramas por segundo (`:14`).
- `typewriter_ink`: grano 0,5 (`:7`); escala de la tinta 0,85 (`:28`).
- `tv_screen`: 240 líneas (`:58`), 1.100 franjas (`:80`), 60 fotogramas (`:49`), viñeta (`:85`).

### 18.6 Otros

- Anillo de mantener: radio 15, grosor 2,5, mostrar desde 0,12, ajuste 18/s, desvanecido 9/s, obsolescencia 0,08 s (`hold_ring.gd:13-22`).
- Aviso de objetivo: `BRIEF_HOLD` 6,0 s, `BRIEF_LEAD` 2,2 s, `BRIEF_IN` 0,45 s, `BRIEF_OUT` 1,5 s (`hotel_ui.gd:2053-2057`).
- Arrancado de papeles: `SNATCH_TIME` 0,045 s, `SNATCH_TO` (0,34; −1,3), `SNATCH_TURN` 0,4 (`hotel_ui.gd:1422-1424`).
- Separación de teclas: `KEYCAP_ROOM` 40 px (`:1126`); cajas de tecla de 13 px (`:1160`).
- Notas al pie de las pistas: `TEAR_BELOW` 46, `TEAR_RAGGED` 18 (`ruled_paper.gd:30-31`).
- Cerradura: `NO ES` en rojo; 4 huecos de 64 px (`hotel_ui.gd:1387`).
- Sonidos: tono de tecla 1.900 Hz; de confirmación 1.250 Hz; del teclado "wrong" 190 Hz; "right" 1.046,5 y 1.568 Hz (`hotel_ui.gd:355-360`).
- Ejemplo de un tono generado: 44.100 Hz, 16 bits, envolvente de ataque 800 y de caída 300 (`osd_style.gd:230-242`).

---

## 19. Orden de ejecución, física y azar

### 19.1 Sin física

- Ninguno de los archivos de `game/ui/`, `game/title/` ni `game/intro/` define `_physics_process` (búsqueda verificada). La intro y la portada corren en `_process` (`intro_sequence.gd:243`, `title_scene.gd:134`).

### 19.2 Orden de `_process` y de `_input`

- `hotel_ui._process` (`:2203-2229`): reloj, desplazamiento de papeles desprendidos, desplazamiento de pantalla con el stick, ruido, parpadeo del OSD en fallo, puntos de la carga, parpadeo de `flash`, espejo de `signal_label`, actualización de `marks_view`.
- `hotel_ui._input` (`:2241-2277`): ver 15.1, con su orden exacto.
- `hold_ring._process`: el anillo se apaga si no le llega `hold()` en 0,08 s. Depende de que el llamador lo haga en cada fotograma (`hotel_main.gd`, no leído).
- `sheet_map._process` (`:55-60`): redibuja cada 1/24 s con `redraw_clock`. El encuadre (`frame`) avanza con `REDRAW / EASE · 3` (`:116`), así que depende del reloj de fotogramas.
- `paper_sheet._process` (`:479-483`): primero `steer_pencil(delta)` (mando), después envía trazos cada 0,1 s (`flush_clock`).
- `hint_view._process` (`:74-77`): se redibuja una vez y se apaga (`set_process(false)`), salvo la polaroid sin foto: sigue activa hasta que `hint.has("photo")` (`code_lock.develop_photo()`, no leído).
- `title_scene._process` (`:134-135`): sólo cuando la portada es visible.
- `intro_sequence._process` (`:243-266`): `step = delta * speed`; los eventos se disparan en el primer fotograma en que `time >= t` (`:247-250`), así que llegan con un desfase de hasta un fotograma. Los muelles de cámara avanzan en subpasos de 0,006 s (`:297-305`). El ruido de la tele y de la cámara usa `rng.randf()` cada fotograma (`:327-331`, `:371-377`), así que el aspecto de la estática depende del número de fotogramas.
- `intro_sequence._unhandled_input` (`:268-271`).
- Tween de la intro (`play_intro`, `:2342-2362`): crea `intro_tween` con `create_tween()` desde `hotel_ui` (`:2342`), que tiene `process_mode` ALWAYS (`:248`); el overlay `outside` también lo tiene (`:316`). Corre aunque el juego esté en pausa.
- `start_roll` (créditos): espera dos fotogramas (`await get_tree().process_frame` ×2, `:1718-1719`) antes de medir la lista.
- `grunt()` (intro): `get_tree().create_timer(segment[1] / speed)` (`intro_sequence.gd:400`).
- `call_deferred`: `show_settings.call_deferred(return_action)` (`:1665, 1753, 1871, 1890, 2239`), `ui.menu.call_deferred("records")` (`records_board.gd:271`), `grab_focus.call_deferred()` (`hotel_ui.gd:1247`). Reconstruir la pantalla en el fotograma siguiente.
- `Input.get_axis("look_up", "look_down")` (`:2207`) y `Input.get_vector("left","right","forward","backward")` (`paper_sheet.gd:413`) leen acciones del mapa de entrada del proyecto (no leídas).

### 19.3 Azar

- Con semilla fija:
  - `title_scene.gd:40` `rng.seed = 2204`. Además el tic de la cabeza usa `rng.randf_range(6, 14)` (`:150`).
  - `intro_sequence.gd:99` `rng.seed = 1987`. Usa `rng.randf()` en cada fotograma para la estática y la cámara (`:327-331`, `:371-377`), y `rng.randi() % clips.size()` al elegir pisadas (`:338`). Las pisadas no son reproducibles entre máquinas si cambia el número de fotogramas.
  - `tv_broadcast.gd:30` `rng.seed = 713`; uso en el tic de la cabeza (`:105`).
  - `crack_pattern.gd:14` `_init(seed_value := 4411)`; la intro llama `CRACKS.new()` sin semilla (`intro_sequence.gd:571`), así que siempre es 4411. Las grietas dependen del orden de los golpes.
  - `handwork.gd:98-99` `wear()` con `rng.seed = seed_value`; caché por tamaño, semilla y `marked` (`:92-97`).
  - `hint_view.gd:98-99`: `rng.seed = 911` para el calco.
  - `hotel_form.gd` y `ruled_paper.gd`: semillas que vienen del `form.seed` y del `hint.room` (`hotel_ui.gd:1341` usa `String(item.id).hash() % 1000`; depende de `String.hash()`, sin comprobar si es estable entre versiones).
- Sin azar: `handwork.jitter()` (`:28-29`) es una función pura de (a, b); `hotel_form.type_line` usa semillas por tecla (`:212-223`); `sheet_map.wander` y `chance` son funciones puras (`:64-68`, `:160-162`).
- Reloj de pared: `Time.get_ticks_msec()` en `sheet_map.gd:213` (pulso de la cámara); `Time.get_date_string_from_unix_time` en `achievements_board.gd:103` (fecha de logro; sin comprobar si usa hora local o UTC).

### 19.4 Señales

- `hotel_ui`: `action_requested(action)` (`:4`), que escucha `hotel_main.gd` (no leído).
- `paper_sheet`: `chunk_drawn(op_id, kind, points)` (`:20`), para enviar trazos por red.
- `hotel_ui` conecta `settings.display_pending` (`:362`) y `get_tree().root.size_changed` (`fit_marks`, `:278`), y `net.steam.friend_achievements` (`:1171`).
- `intro_sequence`: `finished` (`:13`), emitida al llegar a `LENGTH`.
- Conexiones de botones y de cambios de valor: cada control de ajustes usa `connect` con una lambda que guarda con `settings.set_value` (`:1867-1872`, `:1885-1891`, `:1914`).

---

## 20. Pruebas de tests/ que vigilan esta parte

Hay 54 archivos `.gd` en `tests/`. Los que tocan la interfaz (por referencia directa al archivo, a un método o a un nodo):

- `tests/hotel/intro_test.gd` (69 líneas). Vigila la intro 3D: portada visible y con cámara (`:26`), la escena abre en `CUTSCENE` (`:29`), cámara propia y ambiente (`:32`), que no haya menú (`:33`), los tiempos de los golpes y de las grietas (`:38-41`: `crack_level` 0 y 1; `cracked == 2` en 33,1-33,6 s; puerta a más de 0,5 rad), que se disparen todos los eventos (`:42`), que la partida empiece (`:43`), que vuelva la cámara del jugador (`:44`), que se restaure la luz (`:45`), que la portada quede oculta (`:46`), que se pueda reabrir (`:54`) y que mantener la tecla de interactuar la salta (`:58-61`). Usa `level.ui.finish_intro()` y `ui.play_intro()`.
- `tests/hotel/scene_contract_test.gd` (339 líneas). Vigila la estructura de capas (`ui.outside.layer > Analog.layer`, `overlay.get_parent() == outside`, `sheet.get_parent() == ui`, `:36`), que el anillo de mantener esté centrado en el punto de mira (`:40-43`, `ui.hold_ring`), que el anillo de saltar quede a la izquierda del texto (`:45-46`, `ui.skip_ring`, `ui.skip_label`) y la liberación de una tecla modificadora (`:48` y siguientes).
- `tests/hotel/rules_test.gd` (185 líneas). Vigila las reglas (`RULES.settled`, `changed`, `described`, `shown`, `applies`) y la pantalla: `ui.menu("lobby")` (`:163`), `ui.screen == "rules"` (`:166`), `ui.rule_rows` y `ui.rule_pickers` con todas las reglas (`:166-167`), que posarse en una regla trae su nota (`:169-170`, `rule_detail.words`), y que elegir un valor lo pone en la sala (`:174`).
- `tests/hotel/difficulty_test.gd` (445 líneas). Vigila datos (perfiles de dificultad, `DIFFICULTY.valid`, `ORDER`, `TRAITS`); toca la UI sólo en `:144` (ajuste por defecto) y `:93` (valor no conocido vuelve a Desafiante).
- `tests/hotel/stages_test.gd` (líneas 577-596). Vigila que las pistas creen un único hijo: `hint_view` con `hotel_form.CARD` cuando el papel es el formulario (`:581-583`), y con `ruled_paper` cuando el papel es la libreta y cabe en la página (`:594-596`).
- `tests/hotel/loop_test.gd` (línea 243). Elige el script de papel (`hotel_form.gd` o `ruled_paper.gd`) según `item.has("form")`.
- `tests/hotel/spatial_audio_test.gd` (línea 23). Usa `osd_style.gd`'s `beep()` para generar un tono de prueba.
- Pruebas que llaman a métodos de la UI en general (`ui.menu`, `ui.show_settings`, `ui.show_tape`, `ui.show_characters`, `ui.close_dossier`, `ui.hide_transit`, `ui.tape_time`): `tests/hotel/hotel_test.gd`, `continue_test.gd`, `capture_test.gd`, `hotel_walkthrough.gd`, `tests/net/net_test.gd`, `tests/office/descend_test.gd`. (Búsqueda por patrón amplio, no leídos.)
- Scripts de captura (no son pruebas, pero generan imágenes de la interfaz): `tools/capture/title_capture.gd`, `catalog_capture.gd`, `hint_capture.gd`, `notes_capture.gd`, `sheet_map_capture.gd`; `tools/audio/measure_blows.gd` (volumen de los golpes de la intro). Y los generadores de textura: `tools/textures/bake_hotel_note.py`, `bake_do_not_disturb.py`, `tools/art/make_achievement_icons.py` (los 18 iconos).

Cosas que las pruebas NO vigilan (según lo leído): el texto exacto de las pantallas (no hay pruebas de cadenas), el tamaño y la posición de los textos, la legibilidad, el orden de las pestañas de ajustes, la paleta, la fuente.

---

## 21. Hallazgos que el porte debe conocer

### 21.1 Cadenas con salto de línea literal

- `game/ui/hotel_ui.gd:288-289`: `STYLE.text("<< REW` y salto de línea `SP", 30)`. Verificado con `od`: hay un byte 0x0A entre "REW" y "SP".
- `game/ui/hotel_ui.gd:1340-1341`: `Array(String(item.body).split("` y salto de línea `")` (el separador es un salto de línea real).
- No comprobé si el analizador de Godot 4.7 acepta estas cadenas (no ejecuto Godot en este encargo). Lo que sí consta es que el texto pretendido es "<< REW" más "SP" en otra línea, y un separador de salto de línea.

### 21.2 Discrepancias entre `docs/textos_juego.txt` y el código

- AJ.14 (`textos:1023`) pone los presets "Bajo / Medio / Alto / Ultra"; el código tiene "Muy bajo" primero (`graphics_presets.gd:20,27`; `hotel_ui.gd:1584`).
- AJ.14f (`textos:1043`) dice "preset Bajo. Si aun así va lento, prueba Ajustes ▸ Gráficos ▸ Renderizador: Compatibilidad." El código dice "preset Muy bajo. Si va sobrado, sube el preset en Ajustes ▸ Gráficos; si aun así va lento, prueba ahí el renderizador Compatibilidad." (`hotel_ui.gd:879`).
- OSD.REW (`textos:1087`) tiene una sola línea "<< REW"; el código tiene dos líneas (`hotel_ui.gd:288-289`).
- CRED.02 (`textos:601`) dice "hoy v0.5"; la versión sale de `application/config/version` (`hotel_ui.gd:11`), cuyo valor no leí (`project.godot` no está en el alcance).
- MP.03 (`textos:705`) dice "hoy 2 y 5" para jugadores; el código usa `NET.MIN_PLAYERS` y `NET.MAX_SURVIVORS` (`hotel_ui.gd:697`), no leídos.
- El catálogo y el código coinciden en casi todo lo demás que comprobé (títulos de pantalla, opciones de menú, nombres de pestañas y de los logros).

### 21.3 Cosas que dependen de otros archivos y que el porte tendrá que traer

- Lista de acciones del mapa de entrada (`left`, `right`, `forward`, `backward`, `look_up`, `look_down`, `interact`, y las de `PAD_KEYS`). Están en `settings_service.gd`, no leído.
- Ajustes persistentes (`settings.values`): claves como `window_mode`, `resolution`, `upscaler`, `scale`, `sharpness`, `aa`, `fps`, `vsync`, `quality`, `renderer`, `shadows`, `vhs`, `grain`, `chromatic`, `scanlines`, `bob`, `osd`, `reduced`, `startle_soft`, `gore`, `sensitivity`, `invert`, `pad_look`, `pad_sprint_toggle`, `pad_crouch_toggle`, `rumble`, `master`, `ambience`, `music`, `effects`, `threat`, `subtitles`, `player_name`, `character`, `difficulty`, `floor2`, `host_port`, `host_bind`, `join_address`, `join_port`, `renderer`.
- Registros (`records_service`): `career`, `card`, `table_of`, `best`, `reached`, `reached_count`, `rival_cards`, `usual_part`, `anything`, `CARD_ROWS`, `COMPANIES`, `TABLES`, `KEPT`, `TABLES`, `badges()`.
- Red (`net_session`): `is_host`, `options`, `set_option`, `players`, `connected_seats`, `player_name`, `status`, `local_seat`, `transport`, `start_problem`, `where_to_join`, `join_steam`, `set_character`, `match_net.saved_checkpoint`, `match_net.local_is_locust`, `floor_summary`, `MODE_NAMES`, `Mode.COOP`, `Mode.VERSUS`, `seats_for`, `MIN_PLAYERS`, `MAX_SURVIVORS`, `PORT`, `RANDOM`, `local_addresses`, `host`, `active`.
- Descubrimientos (`discovery_catalog`): `TOTAL` (16), `ENTRIES` (título, encabezado, cuerpo, `form`, `paper`, `creature`).
- Dificultad (`difficulty.gd`): `ORDER`, `title()`, `TRAITS`, `valid()`, `rank()`, `REFERENCE`.
- Reglas (`match_rules.gd`): `shown()`, `settled()`, `changed()`, `label()`, `described()`, `RULES`, `GROUPS`.

### 21.4 Piezas que el porte tiene que reconstruir (no son un control estándar)

- Textos en papel: cada carácter se dibuja con un desplazamiento pseudoaleatorio propio (`hotel_form.gd:212-223`, `handwork.gd:70-76`). Hay que reproducir el "desplazamiento por tecla", no sólo el texto.
- Trazos de lápiz de la hoja: `Line2D` con redondeo, la punta de un mando, borrador de 30 px, y la sincronización por fragmentos (`paper_sheet.gd`).
- Textos superpuestos sobre nieve: la pantalla de señal perdida y la marca REW se pintan en un `SubViewport` que luego pasa por el filtro de cinta (`hotel_ui.gd:268-277`, `:2174-2176`).
- Tarjetas de sector y aviso de objetivo: un `SubViewport` 560×170 con `signal_wash`, y la escena detrás (`:2068-2143`).
- La tele de la intro es un `SubViewport` 640×480 con la criatura animada por código (`tv_broadcast.gd`), más grietas en textura generada por píxel (`crack_pattern.gd`).
- Escritura en `Image` píxel a píxel (manchas `wear()`, `handwork.gd:109-125`; tono de cajas de icono, `osd_style.gd:79-82`).
- Plano dibujado con paredes de un `Vector2` por tramo, con temblor fijo por punto (`sheet_map.gd:64-68`) y "desvanecido por trozos" (`:144-147`).
- Fuentes del sistema con nombres de Windows y Mac (`osd_style.gd:26`, `hotel_form.gd:79`). No hay fuente incluida.

### 21.5 Recursos rotos o ausentes

- `res://assets/fonts/vcr_osd_mono.ttf`: no existe (`osd_style.gd:4`). Las copias en `.claude/worktrees/*` la referencian igual, pero tampoco existe en el repositorio principal.
- `assets/textures/carta-trozo.png`: lo cita un comentario (`torn_letter.gd:11`). Sí existe, pero no lo carga ningún código de `game/ui` (búsqueda por nombre en la carpeta: sólo el comentario). Sin comprobar si lo carga otro archivo.
- Iconos de logros: sólo existen los del piso 1; los demás hitos no tendrán icono (`achievements_board.gd:87-90`).
- `records_board.gd:181-212` (`milestones`): función sin llamadas (ver 6.1).

### 21.6 Licencias visibles en la interfaz

- Los créditos (`hotel_ui.gd:18-124`) nombran licencias CC BY-NC-ND (modelo de The Locust) y CC BY-SA 4.0 ("Realistic Female"). El propio texto dice "mientras sigan aquí, esto no se puede vender". Es un hecho del código para el porte: si el port se va a vender, esas dos entradas son bloqueantes según el propio texto.

---

## 22. Sin comprobar

- **No ejecuté nada.** Ni Godot, ni Unreal, ni pruebas. Todo lo anterior sale de leer el código.
- **Parser de Godot con cadenas de salto de línea literal** (`hotel_ui.gd:288-289`, `1340-1341`): no comprobado.
- **Fuente real que usa el juego en Windows**: depende de qué fuentes del sistema estén instaladas (Consolas, Courier New). No comprobado qué glifos tienen esas fuentes (▶ ◀ ■ ❚ ▸ ★ □ ↑ ↓ − ×). Godot usará su respaldo para los que falten. No comprobado.
- **Ficheros de `game/presentation/`** (`analog.gdshader`, `camcorder_look.gd` completo, `graphics_presets.gd` completo, `shader_warmup.gd`) y **de `game/services/`** (`settings_service.gd` completo, `records_service.gd`, `run_score.gd`): sólo se leyeron las líneas citadas, o nada.
- **`game/app/`** (`hotel_main.gd` completo, `interaction.gd`, `executions.gd`, `death_tape.gd`, `code_lock.gd`, `presentation_rig.gd`): sólo las líneas de llamada a la UI. No comprobé la lógica de los botones (`action_requested`) ni el orden de los estados.
- **`game/net/`** (`net_session.gd`, `steam_link.gd`): sólo los nombres de los métodos que usa la interfaz.
- **`game/floors/`** (`floor_index.gd` completo, `hotel_floor.gd`, `office_floor.gd`, `match_rules.gd`, `difficulty.gd`): sólo `RELEASED`, `milestones()` y los nombres citados.
- **`game/enemies/`, `game/world/`, `game/player/avatars/`**: sólo `avatar_visual.gd:4` (los nombres) y `locust_look.gd`/`locust_poser.gd` por su nombre.
- **El valor de `application/config/version`** (`project.godot`): no leído.
- **La tabla `RECORDS.CARD_ROWS`, `RECORDS.COMPANIES`, `RECORDS.TABLES`, `FLOORS.title`, `DIFFICULTY.TRAITS`**: no leídas; sólo citadas.
- **La fecha de logros con zona horaria**: `Time.get_date_string_from_unix_time` (`achievements_board.gd:103`): no comprobé si usa UTC o local.
- **`String.hash()` estable entre versiones** (`hotel_ui.gd:1341`): no comprobado.
- **Distribución de fotogramas con `rng.randf()` en cada fotograma de la intro** (`intro_sequence.gd:371-377`): no medido. Sólo sé que el código lo hace.
- **Tiempos reales de las animaciones**: calculados a partir del código (tiempos y duraciones), no medidos en pantalla.
- **Contenido de `docs/textos_juego.txt` líneas 1-1687**: leído completo; no comprobé que cada cadena esté en el código (sólo una muestra: 10 cadenas).
- **Archivo `.uid`** de cada script: no leídos, sólo existen.
- **Cómo se ve la interfaz**: no hay capturas. Todas las posiciones están dadas por el código, no por una imagen.
- **Lista exacta de los iconos del juego**: sólo se comprobaron los 18 PNG del piso 1 (`assets/ui/achievements/`) por nombre; no se abrieron.
- **El número exacto de documentos del archivo**: `CATALOG.TOTAL` no leído; el texto y el código dicen 16 (`hotel_ui.gd:662`, `textos ARCH.02`).
- **Luces, sombras y cámara de la portada en el renderizador de la plataforma**: no comprobado.
- **Calidad del `tv_screen.gdshader` en el móvil o en pantallas de 4K**: no comprobado.
- **Lo que hacen los presets con la nitidez y el escalado**: sólo se leyeron las opciones.
- **Lo que hace `hotel_main` cuando se pulsa un botón de `action_requested`**: no leído.
- **Escenas de `tools/capture/*.gd`**: sólo se sabe que citan los archivos de la UI.
