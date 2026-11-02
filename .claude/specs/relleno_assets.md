# Relleno de assets del piso 2

Comprobado el 2 de noviembre de 2026 contra los archivos y los registros, sin abrir ninguna web. Triángulos: índices/3 de los glTF y glb; lo que sale del registro lo dice. La flecha es el diezmado de U1. Rutas bajo `source_assets/`. Hoy, en `assets/props/office/` solo están `fichero_vintage_wooden_drawer_01` y `skull`.

## Lo descargado sin usar, y dónde encaja en 4c

**Con unidad en 4c**

| Pieza | Licencia | Tris, disco | Dónde encaja | Unidades |
|---|---|---|---|---|
| `props/sofa_02` | CC0 | 2.728, 0,43 MB | Rincón de Dirección, 60 % de las veces | U1, U7, U8 |
| `props/mid_century_lounge_chair` | CC0 | 6.148, 2,09 MB | Rincón de Dirección, el otro 40 % | U1, U7, U8 |
| `props/potted_plant_01` | CC0 | 176.226 → 18.000, 6,33 MB | Esquinas `plant` | U1, U7, U8 |
| `props/pachira_aquatica_01` | CC0 | 76.914 → 46.000, 5,14 MB | `_d`: planta alta de Dirección y Secretaría. `_c`: `plant_bare`. `_a` y `_b` se hornean sin uso | U1, U7, U8 |
| `props/calathea_orbifolia_01` | CC0 | 16.688 → 11.000, 1,88 MB | `_a`: `plant_bare`. `_c`: `plant_small`. `_b` sin uso | U1, U7, U8, U15 |
| `props/anthurium_botany_01` | CC0 | 67.152 → 30.000, 3,24 MB | `_a`: `plant_bare`. `_c`: `plant_small`. `_b` sin uso | U1, U7, U8, U15 |
| `props/plastic_bottle_gallon` | CC0 | 13.728 → 4.000, 1,39 MB | Almacén y depósito (decisión 3) | U1, U7 y U12. **Ninguna lo coloca** |
| `office_tiles032` (material, ya ingerido) | CC0 | | Franja de aseos | U9, `wet_band.tres` |

**Sin unidad en 4c** (casi todo lo hace ya una pieza en código; solo se usaría para mejorarla)

| Pieza | Licencia | Tris, disco | Dónde encajaría | Qué hay en su lugar |
|---|---|---|---|---|
| `oficinas/muebles_a/silla_giratoria_old_computer_chair` | CC BY 4.0 | 3.908, zip de 34 MB, texturas de 4096 | Sillas de naves y puestos. Lleva regatones, no ruedas | `office_chair` sin modelo en U7, reserva en código de U2. El registro dice `needs_login`, pero el zip está y trae su licencia |
| `oficinas/muebles_a/fichero_vintage_wooden_drawer_01` (ya horneado) | CC0 | 5.184 | Fichero de Reprografía | `CABINETS.card_index` |
| `oficinas/muebles_b/mail_cart_steel_utility_cart` | CC0 | 29.394 (tope 20.000), 10,0 MB | Carrito metálico de Correo | `movables.cart` |
| `oficinas/muebles_b/mail_cart_hand_truck` | CC0 | 13.220, 3,3 MB | Correo o almacén | Nada |
| `oficinas/muebles_b/waste_bin_wire_basket` | Pixabay | 26.974, 0,67 MB, sin texturas, 2 m de alto | Cestas de alambre de Correo | **Nada: la nota las pide y ni el código ni 4c las hacen** |
| `oficinas/muebles_b/archive_shelving_slotted_angle_rack` | Pixabay | 58.464, 28,0 MB | Archivo y almacén | `storage.archive_shelving` |
| `oficinas/muebles_b/cubicle_partitions_3td_office` | CC0 | 96 por mampara (registro), 5,2 MB, Collada, 512 px | Nave de cubículos | `movables.partition_screen` |
| `oficinas/muebles_b/bulletin_board_cork_material` | CC0 | Material, 8,3 MB | Tablón del puesto de seguridad | `wall.notice_board` |
| `oficinas/equipos/pushbutton_phone_oga` | CC0 | FBX y .blend, 12,2 MB. Rojo, hay que recolorearlo | Teléfono del puesto de seguridad | Teléfono en código de U3 |
| `oficinas/equipos/ceiling_diffuser_oga` | CC0 | Solo .blend y mapas de 1K, 2,6 MB | Difusores del techo | En código, U2 |
| `oficinas/equipos/wall_grille_oga` | CC BY 4.0, textura CC0 | 197 cuadriláteros (registro), .7z con .blend, 6,3 MB | Rejilla de climatización | Ninguna unidad lo usa |
| `oficinas/equipos/electric_cables_switches_polyhaven` | CC0 | 42.078 (registro), 6,5 MB | Conducciones del cuarto eléctrico | El área 5 las hizo en código |
| `oficinas/equipos/pedestal_fan_oga` | CC0 | .blend, 5,1 MB | Climatización | Nada |
| `oficinas/_rechazados/props_polyhaven/desk_lamp_arm_01` | CC0 | Rechazado: lleva la marca LUXAR | Flexo de brazo | `desk_lamp` en código de U2 |
| `oficinas/materiales`: `acg_leather006`, `acg_fabric018`, `acg_fabric029` | CC0 | Sin ingerir | Sillas y tapicería, según el relevo | 4c no los cita |
| `oficinas/materiales`: `acg_plaster002`, `ph_white_stucco`, `ph_oak_veneer_01`, `ph_wooden_panels`, `acg_leather022`, `acg_fabric047`, `acg_corrugatedsteel006c`, `acg_concrete034` | CC0 | Sin ingerir | Sin destino | 4c no los cita |
| `props/modern_arm_chair_01`, `small_wooden_table_01`, `Ottoman_01`, `korean_fire_extinguisher_01`, `hanging_picture_frame_01` y `_02` | Ver «Licencias» | Sin ingerir, en `SKIP` de `build_catalogue.gd` | Sillón de recepción, mesita de secretaría, taburete de climatización, extintor de pasillo, marcos de juntas y despacho | Nada asignado |

`lever_switch_oga` (CC BY 3.0) queda fuera: el área 5 lo descartó por tosco. Aseos y vestuario, pasillos de servicio y puesto de seguridad no tienen ninguna descarga utilizable sin retocarla.

## Licencias

Ninguna entrada `ok` de los registros de `source_assets/oficinas/` lleva NC, ND ni SA. Los problemas están en lo que ya hay en el juego. La exportación usa `export_filter="all_resources"` y no excluye `assets/`: lo que está ahí se distribuye aunque el código no lo cargue. Para sacar algo hay que borrarlo o filtrarlo, no basta con no colocarlo.

**Impiden vender**

1. The Locust, `assets/enemies/locust.glb`: CC BY-NC-ND 4.0 (`ASSETS.md`:110-111 y :322). Lo cargan `hotel_main.gd`, el título, la intro, las alucinaciones y el calentamiento de sombreadores. Hay que sustituirlo o conseguir permiso. Cambiar el modelo no cubre el personaje, que `CREDITS` atribuye a Doctor Nowhere, ni la línea «Proyecto fan no oficial, sin ánimo de lucro» (`hotel_ui.gd`:21 y :29).
2. «Realistic Female», `assets/players/realistic_female/`: CC BY-SA 4.0. Es «Exploradora» en el menú de personaje (`avatar_visual.gd`:3-4, `hotel_ui.gd`:1853).

**Sin licencia comprobada** (aportado por el autor)

3. Armario, puerta de madera, televisor y cama (`ASSETS.md`:72, `hotel_ui.gd`:42). El piso 2 usa los armarios, las medidas de la hoja de la puerta y precarga el televisor sin colocarlo.
4. 28 sonidos marcados `integrated` en `docs/assets/sfx_inventory.json` con autor y permiso pendientes: 16 de puerta, 8 de armario, 2 de latido y 2 de ambiente. `slow-opening.wav` y `slow-closing.wav` no entran: son CC0 (`ASSETS.md`:92-93).
5. La música, `assets/audio/the_four_theme.mp3` (`ASSETS.md`:397).

**Confirmar antes de publicar**

6. Puertas y bajada del ascensor, `assets/audio/sfx/lift/`: CC0 según `AUDIO.md`:238 y `prepare_lift_sfx.py`, sin autor ni enlace. Sin enlace también la campana (`ASSETS.md`:87) y el ascensor de EFX (:53).
7. `chair_roll.wav`, CC BY 4.0: lo subió un anónimo en nombre de la autora (`ASSETS.md`:350 y su registro).
8. El diseño de The Lurker sale de una imagen de origen no comprobado (`ASSETS.md`:331).
9. Las 11 piezas de `SKIP` tienen `info.json` con el formato de Poly Haven, sin campo de licencia y sin fila en `ASSETS.md`. Antes de ingerir una, comprobar su ficha y añadir la fila.

**Comprobado sin problema**

- Pixabay Content License: la admite `OFICINAS.md`:787. Los registros la confirman en cada página: uso comercial sin atribución, prohibida la reventa suelta. Vale también para `tile_*`, cuyo original de Freesound ya no existe.
- El zumbido y la respiración de `assets/audio/dread/` los genera `generate_dread_layers.py`. El juego no lleva la grabación de Pixabay de `fluorescent_hum`.

## Créditos que faltan para el área 6

Hoy no falta ninguna línea: todo CC BY que `ASSETS.md` da por incorporado está en `CREDITS`, y `hotel_ui.gd` no tiene punto medio ni guion largo. Los siete modelos de 4c son CC0 y U1 les pone su fila en `ASSETS.md`.

**A añadir.** CC BY 4.0 pide indicar las modificaciones, y `CREDITS` solo lo hace con la videocámara. El ascensor está reescalado a 0,8 y sin su pared (`ASSETS.md`:58), y los sonidos, cortados y procesados. Tras «SONIDO DE LAS OFICINAS»:

```
["MODIFICACIONES", [
	"Varios de estos modelos y sonidos están modificados para el juego: reescalados, recortados o procesados.",
]],
```

**Solo si la pieza entra** (en «MOBILIARIO Y OBJETOS», con su fila en `ASSETS.md`):

```
"«Old Computer Chair», de Guantanamera (Sketchfab, CC BY 4.0).",
"«Airduct Vent», de bobjh (OpenGameArt, CC BY 4.0).",
```

El autor de la silla es Guantanamera en el `license.txt` del zip; el registro lo llama Slava Izvekov.

**No quitar** «VHS», de Terizmeh (`hotel_ui.gd`:40): ningún código coloca la cinta, pero `assets/props/vhs_tape/` se exporta.

## Decisiones del director para los encargos de 4c

- `plastic_bottle_gallon` se coloca en almacén y depósito, como dice la decisión 3: una unidad de 4c lo hace.
- La silla `old_computer_chair` entra como modelo de `office_chair`, con texturas a 2k y su fila en `ASSETS.md` y `CREDITS`. Sigue valiendo la reserva en código si el modelo no pasa el tope de triángulos.
- Las cestas de alambre de Correo se hacen como pieza en código, sin la descarga de 26.974 triángulos.
- La línea «MODIFICACIONES» de `CREDITS` entra en el área 6.
- Los problemas de «Licencias» son anteriores al rediseño: no se tocan aquí y van en el informe final al autor.
