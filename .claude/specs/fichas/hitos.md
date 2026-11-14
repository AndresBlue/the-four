# Ficha de hechos: salas de hito de las oficinas (piso 2)

Lectura de solo lectura, 14 de noviembre de 2026. Rutas relativas a la raíz del repositorio, con línea. Donde algo no aparece en el código se escribe «no encontrado». Fuentes: game/floors/objectives/, game/floors/office_floor.gd, game/world/interactables/office/office_usable.gd, game/world/office/, game/world/generation/office_generator.gd, game/world/generation/map_generator.gd, game/floors/palettes/office_palette.gd, game/world/hotel/hotel_geometry.gd, game/world/interactables/hotel_door.gd, game/app/lifts.gd, game/app/interaction.gd, docs/OFICINAS.md (2, 3, 8, 10).

---

## 0. Qué es un hito aquí

- Un hito es una sala con un objeto de uso (`office_usable`) que su objetivo maneja. El piso tiene tres objetivos en orden: `files` (planta 1, NIVEL 1), `power` (planta 2, NIVEL 2) y `air` (planta 3, NIVEL 3) (game/floors/office_floor.gd:55-59, 62).
- No hay en el código ningún campo «hito» ni marca de sala de hito. La única diferencia entre hito y sala corriente es que el generador coloca el hito con una función propia (`place_specials`, `furnish_mail`, `furnish_power`, `furnish_air`) y el objetivo le añade sus usables.
- La hoja de hitos del juego no existe fuera de los tres objetivos: el piso 2 no usa `hint_placement.gd` (ver sección 7).

---

## 1. Lista de salas de hito por planta

### Planta 1 (Personal, wing 0, objetivo `files`)

| Sala (tipo OFFICE) | Objeto interactivo (acción) | Dónde se construye | Dónde se usa |
|---|---|---|---|
| Ventanilla de Personal (`OFFICE.WINDOW` = 17) | Máquina de escribir: usable `type` a 0.9 m sobre la mesa; palabra «ESCRIBIR» (`files_objective.gd:364`); sostener `TYPE_TIME` = 5.0 s (`:24`, `:377`). Mientras, `begin_use` pone el bucle `typing.wav` (`:383-388`) y `holding` dispara la foto de la cámara (`:391-392`, `snap()` `:397-433`). | `game/floors/objectives/files_objective.gd:79-151` (`place()`), máquina en `:96` (`add_usable`) y modelo `MODELS.mesh_of(..., "typewriter")` en `:98`. Mesa y ventanilla por `office_generator.gd` `furnish_mail()` (`:988-1124`) y `place_specials()` planta 0 (`:258-264`, banda `palette.WINDOW_DEPTH` = 0.15-0.45, `palette.gd:300`). | `office_usable.gd:30-50` (`word()` devuelve la palabra; `use()` envía `use_office`). |
| Mapa de la red («RED DE TUBOS») en la misma sala | Usable `read` (`files_objective.gd:139`) con la palabra «LEER» (`:361`). | `files_objective.gd:129-139`. | `office_usable.gd:47-48` abre `read_paper(paper_of(index))`; `paper_of()` devuelve el mapa `kind:"red"` (`:535-546`). |
| Estaciones del tubo (8 a 14 por planta, `palette.STATIONS` = Vector2i(8, 14), `office_palette.gd:311`) | Usable `take` por estación (`files_objective.gd:102`); palabra «RECOGER» si hay una ficha en la bandeja (`:366-368`); sostener `TAKE_TIME` = 1.5 s (`:25`, `:378`). Lámpara ámbar (`STATION_LAMP`, `:32`, `OmniLight3D` energía 0.6, alcance 1.5, `:113-120`) encendida cuando espera una ficha (`show_state()` `:331-339`). | `files_objective.gd:99-121`. Salas elegibles: `office_generator.gd` `furnish_mail()` (`:1022-1034`): planta 0, no pasillo, no `off_limits`, no ventanilla, recepción, archivo ni archivo móvil. Cantidad: `roundi(11.0 * sqrt(area)) ± 1` acotada a 8-14 (`:1026`). Punto en la pared: `station_spot()` (`:1176-1189`). | Ruido de la cápsula y campana (`tube_hiss.wav` `:304`, `tube_bell.wav` `:471`). |
| Lector de fichas del montacargas (sala de vestíbulo del montacargas, `OFFICE.REFUGE` = 19 en planta 1) | Usable `swipe` junto al lector (`files_objective.gd:143`); palabra «PASAR FICHA» si hay una ficha en mano sin pasar (`:370`); sostener `SWIPE_TIME` = 0.5 s (`:26`, `:379`). | `files_objective.gd:140-150`. Posición del lector: `office_generator.gd` `mail_reader()` (`:1125-1145`), en la pared de `gate.room`, la sala que la puerta de etapa separa de `gate.beyond` (`map_generator.gd:176`). | Pasar la ficha abre la puerta de etapa (ver sección 4). |
| Mapa de la red y cámara cenital | Cámara `cctv_camera` sobre la ventanilla (`files_objective.gd:124-128`); no es usable. | `files_objective.gd:124-128`. | Solo ve el jugador en la foto (`snap()`). |
| Central neumática («CORREO NEUMÁTICO») | Pieza decorativa en el hub (`files_objective.gd:88-92`). | `files_objective.gd:88-92`. | Lectura, sin acción. |

### Planta 2 (Registro y Archivo, wing 1, objetivo `power`)

| Sala (tipo OFFICE) | Objeto interactivo (acción) | Dónde se construye | Dónde se usa |
|---|---|---|---|
| Cuarto eléctrico (`OFFICE.ELECTRICAL` = 18) | Tablero general: palancas `lever`, una por zona (`power_objective.gd:90-106`), con la palabra «SUBIR» o «BAJAR» (`:226`) solo mientras la palanca roja está abajo (`red == Red.DOWN`). | `game/floors/objectives/power_objective.gd:61-132`; tablero `POWER_LOOK.power_board()` en `:82`, placa «TABLERO ELÉCTRICO» (font 40) en `:83`. Sala elegida por `office_generator.gd` `place_specials()` planta 1 (`:266-273`, banda `ELECTRICAL_DEPTH` 0.4-0.7, `palette.gd:301`; en `pick_special` (`:328-332`) peso ×3 con una puerta y ×1.5 si es de servicio). Circuitos `"R-%d"` (`furnish_power()` `:1286`). | `power_objective.gd` `word_of()` `:223-230`. |
| Palanca roja del montacargas | Usable `red` (`power_objective.gd:93`); palabra «SUBIR» con la palanca abajo (`:227`); sostener `RED_HOLD` = 1.0 s (`:21`, `:232`). Placa «MONTACARGAS» (font 18) (`:106`). | `power_objective.gd:90-106`. | Al subirla arranca `lift_timer` = 60 s (`:40`) y, con la palanca armada, `allows_ride()` (`:309-311`) deja bajar con `riders >= minimum_survivors()`. |
| Minuteros (pulsadores de luz temporizada) | Usable `switch` (`power_objective.gd:111`), palabra «PULSAR» (`:228`), sin sostener (`hold_of` `:232`). Piloto `OmniLight3D` naranja (`(1.0, 0.55, 0.2)`, alcance 0.6, energía 0.4, `:118-125`) y lentes ámbar (`:113-117`). | `power_objective.gd:107-126`. Puntos: `office_generator.gd` `timer_button()` (`:1346-1365`) en el extremo de un pasillo temporizado (`timed_lane()` `:1337-1338`). | Al pulsarlo, `switch_until` se fija a `elapsed + switch_time` (`power_objective.gd:277`; `switch_time` = 75.0 en `:41`); `powered()` (`:192-201`) da luz a su sala. |
| Memo «CUADRO GENERAL» (leyenda del cuadro) | Usable `read` junto al tablero (`power_objective.gd:128-130`). | `power_objective.gd:127-130`; texto `paper_of()` `:135-141`. | `office_usable.gd:47-48`. |
| Caja de alimentación («ALIMENTACIÓN PRINCIPAL») | Pieza sin usable (`power_objective.gd:151-167`); se pone solo si cabe en la pared del tablero. | `supply_box()` `power_objective.gd:151-167`. | Solo lectura. |
| Vestíbulo del montacargas de bajada | No hay usable propio en `power_objective.gd`. Quién baja lo decide `allows_ride()` (`:309-311`). | `power_objective.gd:309-311`. | `game/app/lifts.gd` (no leído en detalle). |

### Planta 3 (Dirección, wing 2, objetivo `air`)

| Sala (tipo OFFICE) | Objeto interactivo (acción) | Dónde se construye | Dónde se usa |
|---|---|---|---|
| Puesto de seguridad (`OFFICE.SECURITY` = 21) | Lector de ficha `post` (`air_objective.gd:93`, palabra «PASAR FICHA» si no está abierto y hay ficha, `:262`, sostener `POST_SWIPE` = 0.5 s, `:38`, `:275`). Consola `start` (`:94`, palabra «ENCENDER» con cargas y sin ventiladores, `:263`, sostener `START_HOLD` = 1.0 s, `:39`). Memo «VENTILACIÓN» `read` (`:148-158`, `paper_of()` `:355-356`). | `game/floors/objectives/air_objective.gd:77-209`; lector en `:113`, consola `security_console` en `:115`. Puesto por `office_generator.gd` `place_air()` (`:345-368`, banda `SECURITY_DEPTH` 0.25-0.55, `palette.gd:302`) y `try_security()` (`:374-413`, peso 4 si tiene una sola puerta). | `air_objective.gd` `apply("post")` (`:327-328`). |
| Sala de climatización (`OFFICE.AIR_ROOM` = 22; `place_air()` `:347` toma el refugio de la planta 3 como sala de aire y la une con la climatizadora, `:349`) | Compuerta del ducto principal: usable `hatch` (`air_objective.gd:90`), palabra «ABRIR» (`:261`, con los ventiladores parados y la compuerta cerrada), sostener `HATCH_TIME` = 2.0 s (`:24`, `:274`). Tras abrir, el mismo usable pasa a `climb` (`:252`) con palabra «ENTRAR» (`:266-267`), `CLIMB_HOLD` = 0.5 s (`:25`). | `air_objective.gd:89-96`, hoja de la compuerta con su volante y su placa en `:170-189`; posición en `office_generator.gd` `furnish_air()` (`:1369-1479`, `hatch` en `:1479`). | `air_objective.gd` `apply("hatch")` (`:323-326`). |
| Climatizadora (`OFFICE.AIR_PLANT` = 23) | Unidad AH-1 (`air_objective.gd:116-122`, placa «CLIMATIZADORA AH-1», font 36). Caja de paro `stop` (`:95`, palabra «PARAR» con los ventiladores en marcha, `:264`, sostener `STOP_HOLD` = 1.0 s, `:40`). Dos rotores `FanRotor` (`:123-130`). | `air_objective.gd:116-132`. Caja de paro: `furnish_air()` la pone en la pared de la sala de la planta (`office_generator.gd:1456-1468`, `p_room`). | `air_objective.gd` `apply("stop")` (`:338`); el sonido de los ventiladores `fans.wav` (`:337`). |
| Pozo (escalerilla al final del ducto principal) | Usable `ladder` (`air_objective.gd:92`), palabra «BAJAR» cuando `in_shaft() >= minimum_survivors()` (`:269`), sostener `LADDER_HOLD` = 1.2 s (`:26`, `:279`). | `air_objective.gd:92`; posición en `office_generator.gd:1470-1478` (`shaft`, `ladder.point`). | Termina el piso (`LEAVE := "ladder"`, `office_floor.gd:65`). |
| Ducto principal, boca de bajada | Usable `climb` índice 1 en la boca (`air_objective.gd:91`), palabra «BAJAR» si está dentro del ducto a menos de `MOUTH_REACH` = 1.0 m (`:268`, `:44`). | `air_objective.gd:91`. | `main_duct_geometry.gd` (`MAIN_DUCT.mouth`). |
| Placas del ducto principal («DUCTO PRINCIPAL / AIRE DE IMPULSIÓN») | Pieza sin usable, a ambos lados del último tramo (`air_objective.gd:202-208`, font 30). | `air_objective.gd:202-208`. | Solo lectura. |

### No hay en el código

- Sala «de carga»: no existe tipo OFFICE de carga. Lo más cercano son `OFFICE.STORE` = 8 («Almacén») y `OFFICE.DEPOT` = 25 («Depósito»), ambos con puerta de acero (`office_geometry.gd:2047-2048`) y sin objetivo. Ver `game/floors/palettes/office_palette.gd:80`.
- «Mantención»: aparece como nombre de departamento de la planta 3, «MANTENIMIENTO», que sustituye al de la sala de climatización si difiere del de seguridad (`game/world/generation/office_generator.gd:735-736`). También la letra «M» de placa (sección 2).
- Usables de todas las salas: `game/world/interactables/office/office_usable.gd` es el único tipo de usable.

---

## 2. Qué distingue hoy a cada hito de una sala corriente

Todo lo siguiente sale de constantes del código. «Número» es la placa de puerta, con su número de sala (`office_palette.gd:795-807`).

| Sala | Número y letra de placa | Suelo (`FINISH_BY_TYPE`, `office_palette.gd:266`) | Muros (`BLOCK_WALLS` `:270`, `wall_material` `:744-749`) | Friso/zócalo (`wall_trim` `:752-758`) | Techo | Luz propia (`lamp_of` `:772-775`) | Puerta (sección 4) | Sombra y sonido |
|---|---|---|---|---|---|---|---|---|
| Ventanilla (17) | Sí; letra por planta: P (planta 1) | vinyl (`:17`) | office_paint | ninguno | falso techo 2.95 m (`HEIGHTS[17]`, `:119`) | troffer prismático, 3000 K (`LAMP_KELVIN[17]`, `:290`) | madera (vision o plain) | cristalera con cristal claro (`glazed_run`, `office_geometry.gd:1419-1436`); sonido de máquina |
| Cuarto eléctrico (18) | Sí; letra «M» (`TYPE_LETTERS` `:253`) | quarry (`:18`) | block | ninguno | falso techo 2.95 | solo unidad de emergencia (`lamp_of` `:774`); lámpara de emergencia `SpotLight3D` con sombra, energía 1.4, alcance 9, ángulo 55, 2400 K (`emergency_unit()` `office_geometry.gd:1086-1142`, `EMERGENCY_*` `:1062-1069`) | acero verde gris de servicio (`service_door`, sección 4) | tablero y palancas con placas; `tick`/`breaker` |
| Puesto de seguridad (21) | Sí; letra «S» | vinyl | office_paint | dado de nogal hasta 1.05 m (`DADO_ROOMS` `:278`, `DADO_TOP` `office_geometry.gd:53`) | falso techo 2.95 | troffer prismático 3000 K; planta 3 siempre con luz (`always_lit()` `:825-832`) | puerta de la planta: bloqueada por `post_door.locked` (`air_objective.gd:230-234`) | vidrio armado (`wired_glass`) con cualquier sala contigua (`office_geometry.gd:1436`); dos taquillas (`WARDROBES` `:76`, `21: 2`) |
| Sala de climatización (22) | Sí; letra «M» | vinyl | block (`:270`) | two-tone (`TWO_TONE_ROOMS` `:279`) | 4.4 m, sin falso techo (`HEIGHTS[22]` `:119`) | regletas de dos tubos (`BATTEN_ROOMS` `:221`), 3000 K | acero verde gris de servicio | sonido de la compuerta (`hatch.wav`) |
| Climatizadora (23) | No (`NO_NUMBER` `:127`) | vinyl | block | two-tone | 4.4 m, sin falso techo | regletas, 3000 K | acero verde gris de servicio | ventiladores (`fans.wav`); máscara de sonido `AIR_MASK` 0.65 (`air_objective.gd:42`, `:240-241`) |
| Vestíbulo del montacargas (19) | No (`NO_NUMBER`) | terrazo, que se ve como vinilo encerado (`VINYL_HALLS` `:646`, `floor_look` `:650-656`) | office_paint | friso de dos tonos (`FRIEZE_ROOMS` `:277`) | falso techo 2.95 | troffer, 3000 K; el hotel le da color `b8d4b6` y dos señales de salida (`hotel_geometry.gd:1458-1466`, heredado por `extras()` de `office_geometry.gd:2172-2174`) | puerta de etapa bloqueada (sección 4) | sin unidad de emergencia (`emergency_room` `office_geometry.gd:1079-1081` no la incluye) |

Notas de la tabla:
- `NEVER_DARK` (`office_palette.gd:125`) = [0, 9, 10, 17, 18, 19, 20, 21, 22, 23]: ventanilla, cuarto eléctrico, vestíbulo del montacargas, puesto de seguridad, sala de climatización y climatizadora nunca se apagan por zona (`may_be_dark()` `:767-768`).
- `OFF_LIMITS` (`:255`) = [9, 10, 19]: el vestíbulo del montacargas es zona prohibida para ella (`off_limits()` `:810`).
- Ningún hito tiene foco ni lámpara de mueble propia: `LIGHTS` (`office_models.gd:147-151`) solo tiene lámparas de mesa, de pie y la máquina expendedora, y la ventanilla no las usa. La única luz propia es la del cuarto eléctrico (emergencia), las lámparas de estación y de minutero, y la señal de salida del vestíbulo.
- Placa de puerta: `door_plaques()` (`office_geometry.gd:1957-1978`) pone la placa a 1.55 m (`PLAQUE_Y`, `:93`), de 0.26 m mínimo por 0.09 m, con texto de 20 en `#e8e4d6`, alcance 20 m (`NUMBER_REACH`, `hotel_geometry.gd:392`).
- Número de sala: `OFFICE.plaque()` (`office_palette.gd:804-807`), por ejemplo «P-114», con la letra de `TYPE_LETTERS` (`:253`) o la de la planta (`LETTERS`, `:252`: P, R, D).

---

## 3. Sistema de rótulos y carteles

### Cómo se hace un texto en pared

- Todo texto de oficina es un nodo `Label3D`, no una textura horneada. No hay fuente propia: no encontrado un `font_file` en los rótulos 3D de oficina (la fuente `vcr_osd_mono.ttf` solo la usa `game/ui/osd_style.gd:4`, la interfaz).
- Parámetros comunes de `plate_text()`:
  - `font_size`: 12 a 44 según el caso;
  - `pixel_size` 0.0015 (`office_walls.gd:60`, `office_props.gd:637`, `objective.gd:123`) para placas; 0.007 en `hotel_geometry.gd:815` para las placas de puerta (`text()`);
  - `outline_size` 0, `shaded` true, `cast_shadow` apagado;
  - alcance: `visibility_range_end` 20 en `office_walls.gd:68` (`TEXT_REACH`) y `office_props.gd:638` (`PLATE_REACH`); ninguno en `objective.gd:163-177`.
- Color: `PLATE_INK` = `#e8e2cf` (`objective.gd:124`), `PLATE_DARK` = `#1c1b19` (`:125`); en `office_walls.gd:67` `INK` = `#e8e4d6`; en `office_props.gd:639-640` `PLATE_LIGHT` = `#e8e4d6` y `PLATE_DARK` = (0.07, 0.06, 0.05); «PERSONAL» en `#d3bd8e` (`office_geometry.gd:1486`).
- La placa sobre la que va el texto es un `ArrayMesh` negro de `WALL.sign_plate()` (`game/world/office/pieces/wall.gd:24-37`), con metadato `text_plate` = centro, tamaño y normal. `plate_text()` coloca el `Label3D` en `centre + normal * PLATE_OFF` (`PLATE_OFF` 0.0015, `office_walls.gd:61`).

### Rótulos de pared (reglas y avisos)

- `SIGN_FONT` = 33 (`office_walls.gd:62`), `CENTRAL_FONT` = 22 (`:63`), `SIGN_MOUNT` = 1.45 (`:64`), `OVER_DOOR` = 2.76 (`:66`).
- `sign_size()` (`office_walls.gd:375-380`): ancho = 0.62 × letra × línea más larga + 0.08; alto = 1.3 × letra × número de líneas + 0.05, con letra = 33 × 0.0015.
- Dónde se cuelgan: `hang()`/`dress()` (`office_walls.gd:94-117`, `:194`) con `WALL_DRESSING` (`office_palette.gd:600-621`), cuyo tercer campo es el índice de `RULE_TEXTS` (`office_palette.gd:623`). Los pasillos usan `CORRIDOR_RHYTHM` (`:627`) y `CORRIDOR_PITCH` = 2.0 m (`:629`).
- Archivos: solo una regla sobre cada puerta, `RULE_TEXTS[2]`, a 2.76 m (`archive_signs()`, `office_walls.gd:244-255`).

### Textos literales que existen hoy

| Texto (literal) | Dónde | Font / color |
|---|---|---|
| `CORREO NEUMÁTICO` | `game/floors/objectives/files_objective.gd:92` (hub), `office_walls.gd:326` | 22 / `e8e2cf` |
| `TABLERO ELÉCTRICO` | `game/floors/objectives/power_objective.gd:83` | 40 |
| `MONTACARGAS` (palanca roja) | `power_objective.gd:106` | 18 |
| `R-n` + nombre de circuito (pasillo, zona 2) | `power_objective.gd:106`, `palette.zone_label()` `:846-857` | 14 |
| `ALIMENTACIÓN` / `PRINCIPAL` | `power_objective.gd:167` | 22 |
| `CLIMATIZADORA` / `AH-1` | `game/floors/objectives/air_objective.gd:122` | 36 |
| `COMPUERTA` / `DUCTO PRINCIPAL` | `air_objective.gd:189` (hoja de la compuerta) | 30 |
| `DUCTO PRINCIPAL` / `AIRE DE IMPULSIÓN` | `air_objective.gd:208` (dos placas) | 30 |
| `RED DE TUBOS` | `files_objective.gd:138` | 24 |
| `1. INSERTE FICHA` / `2. ESPERE SEÑAL` / `3. RETIRE FICHA` | `files_objective.gd:147` | 17 |
| `USO EXCLUSIVO` / `DE PERSONAL` (cartel del lector) | `files_objective.gd:150` | 30 |
| `PERSONAL` (sobre el cristal del mostrador) | `office_geometry.gd:1486` | 14 |
| `CORREO` (sacas) | `game/world/office/office_props.gd:309` | 60 |
| Números de estación | `files_objective.gd:107` | 36 |
| Número de sala en el último tramo de una estantería | `office_props.gd:215` (`ROW_FONT` `:184` = 44) | 44 |
| Reglas (`RULE_TEXTS`, 8 textos) | `office_palette.gd:623`: «MANTENGA ENCENDIDAS / LAS LUCES / DE LOS PASILLOS»; «NO TRABAJE / DE ESPALDAS / A LA PUERTA»; «NO SE QUEDE SOLO / EN EL ARCHIVO»; «LAS REJILLAS / NO SE ABREN»; «MANTENGA / EL ORDEN / Y LA LIMPIEZA»; «REPROGRAFÍA»; «FOTOCOPIAS / PLANOS / MICROFICHAS / ENCUADERNACIÓN»; «USO LECTOR DE MICROFICHAS / 1. ENCIENDA EL LECTOR / 2. COLOQUE LA FICHA / 3. AJUSTE EL FOCO / 4. APAGUE AL TERMINAR» | 33 |
| Nombres de sala (`NAMES`, 26) | `office_palette.gd:80`, p. ej. «Ventanilla de Personal», «Cuarto eléctrico», «Puesto de seguridad», «Sala de climatización», «Climatizadora», «Vestíbulo del montacargas» | - |
| Nombres de departamento (`DEPARTMENTS`) | `office_palette.gd:358-362`, p. ej. «REGISTRO», «ARCHIVO CENTRAL», «SEGURIDAD», «MANTENIMIENTO» (estos dos los fija `office_generator.gd:732-736`) | - |
| Rótulos de La Oficina propuestos en docs | `docs/OFICINAS.md:152`: «ACCESO RESTRINGIDO», «PROHIBIDO EL PASO», «ARCHIVO CENTRAL», «SALIDA». Solo «ARCHIVO CENTRAL» está en código (como departamento). «ACCESO RESTRINGIDO» y «PROHIBIDO EL PASO»: no encontrado. «SALIDA»: solo como grabado de la señal de salida en textura (comentario `hotel_geometry.gd:1850-1855`). | - |
| Carteles de salida | Textura `EXIT_ENGRAVING`, no texto (`hotel_geometry.gd` y `office_geometry.gd:2151-2159`) | - |

- Hay también 4 papeles en docs que no son texto de pared (docs/OFICINAS.md:591-611): el resguardo, la ficha, el mapa y la leyenda, cuyo texto ya está en código (sección 7).

### Zonas de pasillo (rótulo de zona)

- `zone_sign()` (`office_geometry.gd:1352-1365`): placa negra de alto `SIGN_HIGH` = 0.12, fondo `SIGN_DEPTH` = 0.006, a `SIGN_Y` = 1.6 m (`:61-63`); un cuadradito de color (`SWATCH` 0.05, `:66`) y el texto de 12 en `#e8e4d6`. Ancho = 3 × `SIGN_MARGIN` (0.03) + `SWATCH` + `SIGN_LETTER` (0.055) × longitud (`:1359`).
- Dónde: `wall_run()` (`:1296-1302`), solo en celdas de `OFFICE.CORRIDOR` y `GALLERY`, con un tramo de al menos 3.0 m, una vez por sala (`labelled`).
- Texto: `zone_label()` (`office_palette.gd:846-857`): en la planta 2 es «código nombre» del circuito; en las plantas 1 y 3 es el nombre del departamento del sector.
- Color: `stripe_color()` (`office_palette.gd:836-842`), según `STRIPES` (`:355`); gris `#6f6a5e` si el sector no tiene departamento.

### Placas de puerta

- Ver sección 2 (`door_plaques()`).

---

## 4. Puertas

### Tipos de puerta (modelo)

- `DOOR_MODELS` (`office_geometry.gd:2037`): «vision» = `puerta_oficina_sousinho_leaf.res` (roble con ventanuco), «plain» = `puerta_lisa_sousinho_leaf.res`, «service» = `puerta_metal_tboiston_leaf.res`; marco de acero `puerta_metal_tboiston_frame.res` (`:2038`).
- `leaf_mesh()` (`:2050-2054`): acero si `service_door()`; si no, ventanuco si `vary(portal, 172) < VISION` (0.35, `office_geometry.gd:105`); si no, lisa.
- Puerta de acero con barra antipánico a 1.0 m (`door_leaf_mesh()` `:2081-2085`).

### Cómo se decide qué puerta es de servicio

- `service_door(a, b)` (`office_geometry.gd:2044-2045`): verdadero si cualquiera de las dos salas es `service_room()` (`STORE` o `DEPOT`, `:2047-2048`), si alguna es `ELECTRICAL`, `AIR_ROOM` o `AIR_PLANT`, o si `gate_stage(...) > 0` (puerta de etapa). Por tanto: cuarto eléctrico, sala de climatización y climatizadora tienen siempre puerta de acero; el puesto de seguridad no, a menos que su otra sala sea una de esas (no encontrado un caso fijo para la puerta del puesto).
- Las salas de hito sin puerta de acero por tipo son la ventanilla y el puesto de seguridad.

### Puerta de etapa (la de la planta)

- En la generación: `map_generator.gd:176` crea la puerta de etapa entre `refuge` (room) y `landing` (beyond) con `stage = planta + 1`. En la planta 3 el segundo gate se convierte en el pozo (`office_generator.gd:1477-1478`, `kind = "shaft"`).
- En el hotel_geometry, al construir la puerta: `door.gate_stage = stage; door.locked = true; gates.append(door)` (`game/world/hotel/hotel_geometry.gd:1154-1158`).
- Abrirla: `open_gates(stage, ready)` (`hotel_geometry.gd:2048-2056`) cuando la etapa está lista; `relock_gate(stage)` la vuelve a cerrar en un reinicio (`:2060-2064`).
- Bloqueo: `hotel_door.gd:23` (`var locked := false`) y `hotel_door.gd:61-62` (`toggle()` devuelve falso si `locked or moving`).

### Puerta de tarjeta (el puesto de seguridad)

- `air_objective.gd:159-166`: busca la puerta del puesto (`air.security.door` = «sala:sala») por `FLOOR.portal_between()` y la guarda en `post_door`.
- `show_post()` (`air_objective.gd:230-234`): `post_door.locked = not post_open`; si está abierta, la abre; si no, la cierra.
- `apply("post")` (`:327-328`): `post_open = true` y `show_post()`.
- Palabra en el lector: «PASAR FICHA» (`:262`), con `has_card()` de la planta 1 (`:359-361`).

### Lectores, teclados, luces de estado o cerraduras en puertas

- No encontrado: ningún lector, teclado, cerradura visible ni luz de estado en el modelo de puerta (`office_geometry.gd` 2037-2112, `hotel_door.gd`).
- Los lectores existen como pieza aparte junto a la puerta: `card_reader()` de `game/world/office/pieces/mail_equipment.gd:132` (planta 1 y puesto de seguridad, `air_objective.gd:113`).
- Luces de estado que sí existen: lentes ámbar de estación (`mail_equipment.gd:164`, `lamp_lens`), lentes de minutero, piloto de la emergencia (`office_geometry.gd:1122-1127`, pipa roja).

### Vista de la puerta

- Marco y umbral: `door_frame_mesh()` (`office_geometry.gd:2112`), umbral de metal `box(... "threshold")` (`:1966`), placas de número (sección 2).

---

## 5. Luces de acento y reutilizables

| Luz | Función que la crea | Parámetros | ¿Sombra? | ¿Cuenta en el presupuesto de luces? |
|---|---|---|---|---|
| Foco de emergencia (`luz_emergencia_sousinho`) | `emergency_unit()` `office_geometry.gd:1086-1142`, llamado desde `extras()` `:2176` | `SpotLight3D`, energía `EMERGENCY_ENERGY` 1.4, alcance 9.0, ángulo 55°, 2400 K, apuntada 35° hacia abajo (`:1128-1141`) | sí (`shadow_enabled = true`, `:1134`) | no entra en `accents`; solo en salas de `emergency_room()` (`:1079-1081`: landing, lobby, corredor, galería, cuarto eléctrico, con corriente) |
| Señal de salida | `exit_sign()` `office_geometry.gd:2151-2159` (sobrescribe el del hotel), heredada de `extras()` del hotel para el vestíbulo del montacargas | luz `OmniLight3D` energía `EXIT_ENERGY` 0.1, alcance `EXIT_RANGE` 1.2 (`:2161-2162`) | no encontrado | no |
| Balizas (baliza roja) | `start_beacon()` `office_geometry.gd:2166-2167`: no hace nada; «No red beacon in the offices' reception» (comentario `:2164`) | - | - | - |
| Lámpara de mesa / flexo / lámpara de pie / expendedora | `office_models.gd` `light()` `:290-299` → `accent_spot()` | `LIGHTS` (`:147-151`): `desk_lamp_banker`, `desk_lamp_arm`, `floor_lamp`, `vending`, con `colour`, `energy` (1.4, 1.4, 1.0, 0.7), `reach` (2.8, 2.6, 2.4, 3.5), `angle` (42, 40, 70, 70) | sí (`casts` por defecto `true`, `office_geometry.gd:2463`) | sí: `OFFICE.MOST` = 3 por sala (`office_accents.gd:6`); `LIT_MOST` = 1 lámpara de mueble encendida por sala (`office_models.gd:142`, `:293-296`) |
| Foco de acento genérico | `accent_spot()` `office_geometry.gd:2463-2488` | `SpotLight3D`, `light_size` = `ACCENT_SIZE` × `preset.penumbra`, specular 0 en la recepción | `casts` (por defecto sí) | sí (`accents.has_room`, `:2464`) |
| Apliques (`accent_sconce`) | `accent_sconce()` `office_geometry.gd:2546-2570`; solo lo llama el ascensor de llegada (`:1684`) | `OmniLight3D` con `omni_attenuation` = `BOX_LAMP_FALL` (0.9) en la caja del ascensor | no (la caja no proyecta) | sí, `sconce` (`office_accents.gd:28`) |
| Foco de la barra del mostrador de recepción (`BAR`) y tres focos de su hornacina | `accent_spot()` en `office_fittings.gd:217` y en `office_props.gd:451` (tres latas de riel) | `colour` `(1.0, 0.84, 0.66)`, energía 3.6, alcance 2.7, ángulo 32 | no (`casts = false`) | sí (cap `RECEPTION_ACCENTS` = 7, `office_geometry.gd:1598`, `:965`) |
| Regleta de dos tubos (lámpara de la sala) | `batten_spot()` `office_geometry.gd:1840-1855` | `BATTEN_CAST` (energía 2.2, ángulo 62°, alcance 6), `BATTEN_AISLE` (1.4, 34°, 4.5) | sí solo en `BATTEN_CAST` | - |
| Lámpara de estación del tubo | `files_objective.gd:113-120` | `OmniLight3D` color `(1.0, 0.62, 0.25)`, energía 0.6, alcance 1.5 | no encontrado | no |
| Piloto de minutero | `power_objective.gd:118-125` | `OmniLight3D` color `(1.0, 0.55, 0.2)`, energía 0.4, alcance 0.6 | no encontrado | no |

- `accents.caps` (`office_accents.gd:10`) y `cap_of()` (`:22-23`) dan a cada sala su tope (3 por defecto, 7 en la recepción).

---

## 6. Modelos y piezas disponibles para marcar una sala

### `game/world/office/office_models.gd` (catálogo `MODELS`, líneas 21-129)

- Mobiliario y accesorios (relevantes para marcar): `extinguisher` (`extintor_loic`), `fire_alarm` (en `assets/props/hotel/fire_alarm.res`), `smoke_detector` (`detector_humo_sousinho`), `sprinkler` (`rociador_tashakosaykina`), `thermostat` (`termostato_alarma_ladylionstudios`), `cctv_camera` (`camara_cctv_smoggybeard`, usada en la ventanilla), `emergency_unit` + `emergency_glass` (`luz_emergencia_sousinho_body` y `_glass`), `hose` (`armario_manguera_red2000`), `ceiling_diffuser`, `hand_dryer`, `lockers` (`taquilla_zambur`), `filing_grey` (`archivador_gris_ahmagh2e`), `typewriter` (`typewriter_1930s_unbranded_sketchfab`), `microfiche` (`microfichas_maxdragonn`), `microfiche_reader`(procedural, ver abajo), `desk_lamp_arm` (`flexo_sousinho`), `desk_lamp_banker` (`lampara_banquero_meunier`), `floor_lamp` (`lampara_pie_bilgehankorkmaz`), `coat_wall_rack`, `towel`, `coat_stand`, `cooler` (`water_cooler_bottle_tboiston`), `fridge` (`nevera_dylanheyes`), `vending` (`expendedora_attheseedof`), `projector_screen`, `television` (`Television_01`), `boombox`, `crt` (`crt_terminal_ibm3278_sketchfab`), `terminal_3178` (`terminal_ibm3178_maxdragon`), `phone` (`rotary_phone_black_sketchfab`), `coffee_maker` (`cafetera_kird3rf`), `dot_matrix_printer` (`impresora_okidata_papaj`), `wall_clock` (hotel), `ashtray`, `tray`, `archive_box`, `globe`, `binders`, `step_ladder` (`wooden_ladder_02`), `broom`, `dustpan`, `mousetrap`, `toolbox` (`metal_toolbox`), `shoes`, `cord_floor` (`alargador_evan4129`), `magnifier`, `spectacles`, `stapler`, `thermos`, `desk_clock`, `desk_fan` (`ventilador_joshsmith`).
- Puertas: `puerta_lisa_sousinho`, `puerta_oficina_sousinho`, `puerta_metal_tboiston` (en `assets/props/office/`, usadas por `office_geometry.gd:2037-2038`).
- Sin modelo en el catálogo: conos, cintas de balizamiento, balizas giratorias, botiquín. No encontrado en `assets/props/office/` ni en `office_models.gd`. Existe `WetFloorSign_01` en `assets/props/hotel/` (cartel de suelo mojado), sin uso en `office_models.gd` (no encontrado en el catálogo de oficina).

### Nombres de carpeta de `assets/props/office/`

El directorio tiene 95 archivos `.res` y varias carpetas con su textura. Carpetas (sin extensión), en orden alfabético: Television_01, alargador_evan4129, anthurium_botany_01, archivador_gris_ahmagh2e, archivadores_palanca_janexx, armario_manguera_red2000, bandeja_sinnervoncrawsz, boombox, butaca_madera_renend, cafetera_kird3rf, caja_carton_krolzuzanna, cajas_archivo_cozmoth, calathea_orbifolia_01, camara_cctv_smoggybeard, cenicero_vidrio_red2000, crt_terminal_ibm3278_sketchfab, detector_humo_sousinho, dustpan, escritorio_madera_collings, escritorio_tanker_lenawachs, expendedora_attheseedof, extintor_loic, fichero_vintage_wooden_drawer_01, flexo_sousinho, globo_collings, impresora_okidata_papaj, lampara_banquero_meunier, lampara_pie_bilgehankorkmaz, lavabo_juang3d, libreria_libros_collings, libros_frodoundead, luz_emergencia_sousinho, magnifying_glass_01, metal_stool_01, metal_toolbox, microfichas_maxdragonn, mid_century_lounge_chair, mousetrap, nevera_dylanheyes, pachira_aquatica_01, perchero_coat_rack_whostea, perchero_pared_ehnri, pilea_terracota_allquad, plastic_thermos, portalapices_aspectstudio, potted_plant_01, potus_colgante_kemowolfpaw, projector_screen, puerta_lisa_sousinho, puerta_metal_tboiston, puerta_oficina_sousinho, reloj_mesa_sousinho, retro_oficina_yj, rociador_tashakosaykina, rotary_phone_black_sketchfab, round_spectacles, round_wooden_table_01, secamanos_ladylionstudios, silla_banquero_zamzam, silla_giratoria_old_computer_chair, silla_tela_projectkaizen, sillas_espera_connorwassall, sillon_mirey_a, skull, small_wooden_table_01, sofa_02, standing_picture_frame_02, steel_frame_shelves_02, taquilla_zambur, terminal_ibm3178_maxdragon, termostato_alarma_ladylionstudios, toalla_aprilpolubiec, typewriter_1930s_unbranded_sketchfab, unidad_hvac_kubassa, ventila_techo_ahmagh2e, ventilador_joshsmith, vintage_stapler, water_cooler_bottle_tboiston, wooden_broom, wooden_ladder_02, zapato_inciprocal.

(Comprobado por nombre de carpeta con grep en `office_models.gd`: no aparecen `skull`, `retro_oficina_yj`, `standing_picture_frame_02`, `steel_frame_shelves_02`, `metal_stool_01`, `round_wooden_table_01` ni `small_wooden_table_01`. Sí aparecen, por ejemplo, `portalapices_aspectstudio` y `potted_plant_01`.)

### `game/world/office/pieces/` (piezas procedurales)

- `wall.gd`: `sign_plate` (placa negra con texto, `:24`), `picture_frame` (`:46`), `clock_square` (`:62`), `directory_board` (`:82`), `notice_board` (`:115`), `key_cabinet` (`:192`), `roll_screen` (`:248`), `mirror` (`:217`), `coat_hook_rail` (`:231`).
- `mail_equipment.gd`: `mail_central` (`:40`), `station_receiver` (`:85`), `typewriter` (`:109`), `card_reader` (`:132`), `tube_collar` (`:151`), `lamp_lens` (`:164`), `network_map` (`:178`), `instruction_plate` (`:210`).
- `power_equipment.gd`: `power_board` (`:52`), `board_conduits` (`:106`), `lever_handle` (`:126`), `main_supply_box` (`:143`), `timer_switch` (`:169`).
- `air_equipment.gd`: `air_handler` (`:38`), `fan_rotor` (`:83`), `hand_wheel` (`:97`), `control_box` (`:116`), `security_console` (`:136`).
- `stand_ins.gd`: `extinguisher` (`:373`), `work_light` (`:388`), `step_ladder` (`:406`), `water_cooler` (`:308`), `fridge` (`:323`), `microwave` (`:339`), `globe` (`:356`), `plant_pot` (`:422`), `wall_fountain` (`:447`), `coat_hanging` (`:464`), `towel` (`:480`), `desk_lamp` (`:148`), `office_chair` (`:33`), `exec_chair` (`:54`), `visitor_chair` (`:113`), `vending_machine` (`:221`).
- `desk_things.gd`: `phone` (`:25`), `mug` (`:70`), `ashtray` (`:97`), `pen_cup` (`:110`), `paper_scatter` (`:140`), `cable_run` (`:154`), `drawer_out` (`:171`), `rug_persian` (`:190`), `microfiche_reader` (`:215`).
- `machines.gd`: `copier` (`:22`), `dot_matrix_printer` (`:57`), `computer_tower` (`:76`), `crt_monitor` (`:96`), `keyboard` (`:122`), `calculator` (`:142`), `overhead_projector` (`:162`).
- `cabinets.gd`: `filing_cabinet` (`:24`), `card_index` (`:43`), `sideboard` (`:65`), `bookcase` (`:87`), `pigeonholes` (`:124`), `pigeon_counter` (`:162`).
- `storage.gd`: `archive_shelving` (`:23`), `mobile_archive` (`:64`), `wood_shelving` (`:108`), `gun_rack` (`:128`), `kitchen_base` (`:154`), `kitchen_wall` (`:210`).
- `desks.gd`: `desk_walnut` (`:25`), `desk_l` (`:56`), `desk_steel` (`:101`), `security_desk` (`:105`), `meeting_table` (`:140`), `front_desk` (`:223`), `reception_counter` (`:257`), `low_table` (`:297`).
- `movables.gd`: `cart` (`:21`), `mail_cart` (`:48`), `whiteboard_mobile` (`:73`), `partition_screen` (`:98`), `slat_bench` (`:115`), `castors` (`:136`).
- `fixtures.gd`: `toilet_cubicles` (`:18`), `box_sconce` (`:57`), `rug` (`:71`), `curtain` (`:90`), `blind` (`:107`).
- `stationery.gd`: `binders` (`:23`), `folders` (`:35`), `archive_box` (`:52`), `books` (`:66`), `paper_stack` (`:78`), `tray` (`:91`), `register_book` (`:120`).
- `room_equipment.gd`: `locker_bank` (`:16`).

---

## 7. Cómo sabe hoy el jugador a dónde ir

- Tarjeta de llegada por planta: `lifts.gd:440` `show_transit(title_of(n), stage_errand(n), RIDE_TIME)`; `hotel_main.gd:1005` y `:1592` usan `OPENING_CARD` (2.6 s, `lifts.gd:465`). El texto sale de `game/floors/office_floor.gd:56-58`:
  - NIVEL 1 / PERSONAL / «PIDE TU FICHA»;
  - NIVEL 2 / REGISTRO Y ARCHIVO / «ARRANCA EL MONTACARGAS»;
  - NIVEL 3 / DIRECCIÓN / «SAL POR EL DUCTO».
- Textos de la tarjeta: `lifts.gd:16` (`stage_errand`) y `lifts.gd:20` (`stage_brief`); `lifts.gd:45` muestra el aviso de la planta con `show_brief`; `hotel_main.gd:1121` `set_briefing(title, brief, progress)` la repite en la pausa.
- Líneas de progreso de la pausa, por objetivo:
  - `files`: «TU FICHA» con ESTACIÓN n, EN CAMINO, EN LA BANDEJA, PASADA o EN LA MANO; «FICHAS a / cuota» (`files_objective.gd:648-661`);
  - `power`: «ZONAS a / budget» y «MONTACARGAS n s» (`power_objective.gd:313-318`);
  - `air`: «CARGAS n» (`air_objective.gd:425-427`).
- Hoja del jugador: `interaction.gd:68` `sheet.open(..., level.own_papers(), level.code.hint_walls())`; `own_papers()` (`hotel_main.gd:1703-1705`) reúne los de cada objetivo. Solo `files` da papeles: el resguardo y las fichas que tenga (`files_objective.gd:564-568`). `power` y `air` devuelven `[]` (`objective.gd:100`).
- Papeles leíbles en el mundo (usable `read`, `office_usable.gd:47-48`):
  - mapa de la red de tubos (`files_objective.gd:535-546`);
  - leyenda «CUADRO GENERAL» (`power_objective.gd:135-141`);
  - memo «VENTILACIÓN» (`air_objective.gd:355-356`).
- Lo que el jugador ve del resguardo y de la ficha: `receipt()` (`files_objective.gd:550-554`, «ENVIADA A ESTACIÓN n») y `office_card()` (`:557-561`, con el departamento fijo «SERVICIOS GENERALES», no el de la planta).
- Planos de pared: `office_pictures.gd:147-172` dibuja el plano de la planta con todas sus salas, corredores en verde y el vestíbulo del montacargas en rojo, sin marca de hitos. Hay un `plan` como cuadro en `WALL_DRESSING` de OPEN_OFFICE, CUBICLES, COPY_ROOM, LOBBY, REFUGE, MAIL, BREAK_ROOM, WINDOW y SECURITY (`office_palette.gd:603-620`).
- Pistas de la hoja del hotel (hint_placement.gd: «plano», «calco», «nomolestar») son solo del hotel: `hint_placement.gd:2-14` y `code_lock.gd:241-242`; `code_objective.gd` solo envuelve al hotel.
- Sonidos como pista: `typing.wav`, `typing_bell.wav`, `tube_bell.wav`, `tube_hiss.wav` (planta 1); `lever_N.wav`, `breaker.wav`, `tick.wav` en bucle, `lift_motor.wav` (planta 2); `hatch.wav`, `fans.wav` en bucle, `ladder.wav` (planta 3). Cada llamada está en `files_objective.gd:304-500`, `power_objective.gd:255-278`, `air_objective.gd:326-343`.
- Señales de luz como pista: lámpara de estación encendida, piloto de minutero, luz de emergencia del cuarto eléctrico (secciones 2 y 5).

---

## 8. Reglas de texto del juego

- `CLAUDE.md` (raíz, «Reglas de este proyecto»): «ningún texto del juego lleva "·" ni "—"»; los documentos van en español y dicen solo lo que es verdad; «Lore: solo lo que el autor confirma»; «Sonido: nada de voces ni gritos humanos sintéticos»; «El piso 1 (el hotel) no cambia salvo que el encargo lo diga».
- `docs/OFICINAS.md:153`: «Sin «·» ni «—» en ningún texto.»
- `docs/OFICINAS.md:5`, `:593` y `:598`: el lore de los papeles es propuesta; «Nada va a LORE.md sin su sí»; lo escrito por quien sabía es «una inferencia, no lore confirmado».
- Comprobación hecha: búsqueda de «·» y «—» en `game/`: solo aparece en dos comentarios de archivos generados (`game/audio/cue_timing.gd:2`, `game/audio/grunt_segments.gd:2`), ninguno en texto de juego ni de oficina. En `docs/OFICINAS.md` aparece solo en la regla de la línea 153.
- Memoria del usuario (`MEMORY.md`, «La interfaz dice poco»): sin párrafos explicativos ni entradas vacías en menús; controles junto a su nombre. No es regla de CLAUDE.md.
- Mayúsculas en los rótulos: todos los literales de `RULE_TEXTS`, placas y departamentos van en mayúsculas sin punto final, salvo las instrucciones numeradas («1. ENCIENDA EL LECTOR») y la frase de la leyenda «NO MÁS DE %d ZONAS A LA VEZ.» (`power_objective.gd:139`).
- Diferencia con docs: el docs pide «SOLO PERSONAL REGISTRADO» en el montacargas (`docs/OFICINAS.md:197`); el código pone «USO EXCLUSIVO / DE PERSONAL» (`files_objective.gd:150`).

---

## 9. Lo que no se encontró

- Ningún campo ni marca «hito» en código: los hitos son solo la combinación de tipo de sala y usable.
- Ningún lector, teclado, cerradura visible ni luz de estado en el modelo de puerta.
- Ningún modelo de cono, cinta, baliza giratoria ni botiquín en el catálogo de oficina.
- Ninguna fuente propia para `Label3D` de oficina.
- Textos «ACCESO RESTRINGIDO» y «PROHIBIDO EL PASO»: solo en docs.
- Lógica de bloqueo para la puerta de la sala de seguridad salvo la de tarjeta.
- Usable propio del montacargas de bajada: no está en `power_objective.gd` (solo `allows_ride`).
