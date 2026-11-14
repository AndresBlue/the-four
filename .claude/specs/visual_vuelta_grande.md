# Frente visual del piso 2: la vuelta grande (12 de noviembre de 2026)

Estado contado desde el código. Commits de la vuelta: `ff97bde` (cuatro modelos de Sketchfab), `43f1321` (tono, suelos, naves, carpintería), `c385f6f` (puertas y treinta modelos), `737345a` (lentes, techo, nogal, tubos), `0580306` (rendimiento y paredes) y `3f9c230` (generador). De la tarde: `776f0f7` (sillas y cajas de varios modelos), `48c025f` (lo que vio el autor jugando), `4e8dfb6` (lo que encontraron los críticos de imagen), `afe8937` (papel, alfombra, mesas) y `091b1db` (mostrador, cocina, pantalla de tela). Lo que pidió el autor: sus capturas en `evidence/autor_12nov/1.webp` a `6.webp`, y su vara en la memoria `visual-bar-real-photo` (cada escena comparable con una foto de la época, juzgada en la vista de juego).

## Hecho

- **Luz** (`office_geometry.gd`; detalle en `spec_rediseno.md` 4):
  - gradación `GRADE` con `white` (1,2, 1,0, 1,15) y `ssao_light` 0,35, que `presentation_rig.apply_grade()` pone en `ssao_light_affect`;
  - sin especular de las lámparas: `LAMP_SPECULAR` y `POOL_SPECULAR` a 0, y `wired_glass.gdshader` con `specular_disabled`; `POOL_ENERGY` 0,7; `LENS_MIRRORED` 15;
  - la lámpara de la sala con perfil uniforme (`LAMP_PROFILE` «even», `LAMP_ENERGY` 2,3), colgada a `LAMP_DROP` 0,9 m bajo las placas;
  - halo corto y débil (`HALO_REACH` 1,8, `HALO_ENERGY` 0,22) con caída suave en `ceiling_halo.gdshader`, que pasa a las celdas abiertas de la misma altura (`open_to()`);
  - un rebote sin sombra bajo cada pantalla encendida (`troffer_pools()`, `BOUNCE_*`), que va con los focos: solo en Alto y Ultra (`pools_shown()`);
  - lentes con sus tubos: `lens_texture()` (`LENS_TUBES`, `LENS_DIFFUSER` 0,35), `lens_box()`, `LENS_LIT_DARK` 1 y `EMISSION_OP_MULTIPLY`; la perfilería ya no cruza una lente (`grid_spans()`);
  - la sonda solo cambia con el drenaje (`probe_strength()`, `PROBE_STEP`);
  - una sola lámpara de mueble encendida por sala (`office_models.LIT_MOST`).
- **Acabados:** vinilo y terrazo satinados (`map_roughness` −0,17 y −0,12), placa del techo más oscura y manchada (`ceiling_service.tres`), nogal con paneles (`walnut.tres`, `dado_oak.tres` con `panel_spacing`), tubos del correo neumático de latón gastado (`files_objective.gd`), molduras a 2 cm (`RAIL`, `DADO_CAP`).
- **Naves** (`office_layout.gd`, `office_generator.gd`, `office_palette.gd`): calles de `NAVE_STREET` 1,2 m (`streets()`, `way_out()`, `gap_of()`), islas de 4 o 6 puestos (`lay_islands()`, `desk_island`, `desk_island_6`, `ISLANDS_MOST` 3) con mamparas en cruz (`island_screens()`) y piezas en sus extremos (`island_ends()`, `ISLAND_ENDS`), paredes cerradas llenas (`lay_wall_rows()`, `NAVE_WALL_ROW`, `NAVE_WALL_DEPTH`), mampara de 1,2 m (`FURNITURE.partition`), y ella solo sale por placas sobre las calles (`free_tiles()`).
- **Recetas y paredes:** más piezas en las recetas de casi todas las salas, `tv_cart` en descanso y juntas, papeles junto a lo que se usaba (`floor_papers()`), objetos tirados por tipo (`office_palette.LITTER_KINDS`, `office_clutter.litter()`), cuadros y tablones en grupos que prueban primero la pared que se ve desde la puerta (`CLUSTERED`), y un elemento cada 2 m en los pasillos (`CORRIDOR_PITCH`), con su hueco libre de muebles (`HALL_SLOT_CLEAR`). Pasillos con mueble cada 5 a 8 m (`HALL_STEP`).
- **Modelos:** puertas (`DOOR_MODELS`, `STEEL_FRAME`, `service_door()`, marco de nogal moldurado en `door_frame_mesh()`), taquillas, archivador gris, detector de humo y las 64 clases de `office_models.MODELS` (una, `waiting_chair`, sin modelo) (lista en `docs/OFICINAS.md` 12). Una clase con varios modelos elige uno por el sitio (`office_props.chair()`, `office_clutter`), y si falta un archivo pasa al siguiente (`mesh_of()`). Herramientas: `register_sketchfab.py`, `fit_model.py` con `fit_models.json` (`tilt` para tumbar una pieza), `TINT` y `PATCHES` en `ingest_models.py`, `PLACED` en `build_catalogue.gd`.
- **Rendimiento:** solo proyectan sombra las piezas grandes de suelo (`office_models.casts()`, `CAST_LEAST`); plantas, papeleras, lo de pared y lo de encima de los muebles, no. Banco en `evidence/bench/piso2_dens6_final_forward_plus/` (cifras en `spec_rediseno.md` 10).
- **Generador:** `office_recipes.Near` prueba cada tramo como un solo rectángulo antes de hacer las piezas, una pieza «spare» que no cupo no se vuelve a probar con otra igual o mayor (`spare_fails`), y las naves no prueban sus «spare». El commit lo midió en un segundo por piso.
- **Herramienta de ángulos:** `tools/capture/office_angles_capture.gd` (con ventana) saca cada tipo de sala desde cinco ángulos, y el despacho y la nave a oscuras con la linterna; `--types=` limita los tipos.

## Lo que vio el autor jugando (20 puntos) y cómo quedó

Commit `48c025f`; lo que no se resolvió está en «Pendiente».

- **Discos blancos en cristales, espejos y pantallas:** sin especular de la lámpara ni de los focos (`LAMP_SPECULAR`, `POOL_SPECULAR` a 0) y el vidrio armado con `specular_disabled`; pantallas y tubos de vidrio a rugosidad 0,3 (`SCREEN_ROUGHNESS`).
- **La luz cortada en línea recta entre una celda encendida y otra a oscuras:** la lámpara de la sala con perfil uniforme (`LAMP_PROFILE`, `LAMP_ENERGY` 2,3), y el halo pasa a las celdas abiertas (`open_to()`).
- **La puerta de mirilla sin hoja:** rehorneada (`puerta_oficina_sousinho_leaf.res`; `fit_model.py` deja un solo mapa UV).
- **Aseos:** todas las paredes alicatadas hasta el falso techo, con remate oscuro (`TRIM`) donde el azulejo no llega a la esquina, y sobre cada espejo una regleta de esmalte con su tira `glow_white` y un foco de acento (`mirror_light()`, `BAR_ENERGY`) en vez del aplique.
- **Rejillas y placas colgantes en el plano de la perfilería:** la rejilla dentro de las alas (`EXIT_CLEAR`) y la placa colgante con la bisagra bajo lo oscuro del hueco.
- **Cosas planas que parpadeaban sobre su mesa:** bloc, papeles, carpetas y registro, 1,5 mm por encima (`office_clutter.FLAT`, `FLAT_LIFT`).
- **Modelos nuevos (CC BY, en `CREDITS`):** sillón de dirección de cuero (`sillon_mirey_a`), extintor con su abrazadera de chapa (`extintor_loic`), lector de microfichas con su pantalla en `glow_fiche` que se apaga con la sala (`office_props.fiche_screen()`), perchero de pared de madera con los ganchos vacíos y una toalla (`perchero_pared_ehnri`, `toalla_aprilpolubiec`). La lupa, tumbada (`tilt`).
- **Sillas y cajas de un solo modelo** (`776f0f7`): la de oficina alterna entre la de tela y la giratoria de contrachapado, y la caja de cartón entre dos modelos, por el sitio.

## Lo que encontraron los críticos de imagen y cómo quedó

Commits `4e8dfb6`, `afe8937` y `091b1db`.

- **Disco caliente en el techo:** la lámpara de la sala baja a `LAMP_DROP` 0,9 m.
- **Lo que no miraba a una lámpara caía al negro:** rebote sin sombra desde el suelo bajo cada pantalla (`BOUNCE_FROM` 0,1, `BOUNCE_ANGLE` 75°, `BOUNCE_ENERGY` 0,16, `BOUNCE_TINT`), que se apaga con su sala y, como los focos, solo existe en Alto y Ultra (`pools_shown()`).
- **Rejillas y huecos del techo en negro puro:** rejilla de conducto con lamas sobre fondo gris (`duct_grille()`, `GRILLE_SLATS` 9) en las salidas y en los huecos sin placa colgante.
- **Reflejo de las lentes como mancha blanca en el terrazo:** `LENS_MIRRORED` de 30 a 15.
- **Rótulo de salida que teñía el techo de verde:** `EXIT_ENERGY` 0,1 y `EXIT_RANGE` 1,2 m.
- **Placas de número:** crecen con su texto (`PLAQUE_LETTER`, `PLAQUE_MARGIN`), y sin las huellas dactilares del hotel (`decal()` sobrescrito).
- **Puertas de acero en salas donde se sienta gente:** `service_door()` solo en almacén y depósito (`service_room()`), salas técnicas y puertas de etapa.
- **Materiales:** terrazo de grano fino (`map_metres` 0,35, modo detalle), moqueta de las naves granate apagado, pintura menos sucia (`stains` 0,25, `grime` 0,35), friso de roble y chapado más oscuros y sin repetición (`map_no_tile`), bloque en modo detalle, cercos del techo de borde irregular (`ceiling_tile.gdshader`), aceros más claros (`steel_dark`) y menos metálicos (`gate_steel`), nogal de muebles más claro (`walnut_object`), papel crema más oscuro.
- **Papel como losa blanca:** hojas descuadradas y una carpeta manila de vez en cuando (`KIT.sheets()`, `paper_manila`).
- **Alfombra persa en código:** alfombra turca del siglo XVIII del Met (`assets/textures/office_rug_met452567/`, dominio público) en dirección y secretaría (`office_fittings.rug()`, `RUG_ORIENTAL`).
- **Mesas de puesto vacías:** lo de encima, más probable y con cenicero (`office_clutter.DESK_THINGS`).
- **La silla de banquero hacía rayas blancas:** la de secretaría y de lectura (`clerk_chair`) es ahora la butaca de madera y cuero (`butaca_madera_renend`).
- **Mostrador y cocina:** el mostrador de recepción con paneles de roble entre listones y repisa de nogal (`desks.make_reception_counter()`); los muebles de cocina en nogal (`storage.gd`); la pantalla de la lámpara de pie de tela en anillos (`stand_ins.make_floor_lamp()`).
- **La herramienta de ángulos** deja la cámara fuera de puertas y muebles (`clear_eye()`) y lee los tipos por la paleta (`OFFICE.label()`).

## 14 de noviembre: las doce fotos del autor, modelos y acabado

Sus capturas: `evidence/autor_14nov/f01` a `f12`. Commits `786d9e0` (luz), `17f533e` (cosas de cara a quien las usa), `73e8096` y `9e43fdd` (quince modelos de Sketchfab) y el del acabado. Capturas en `evidence/rediseno/rev5` a `rev9`.

- **Foto 1, aplique del ascensor:** la luz sale de la caja (`accent_sconce()`, `set_sconce()`, perfil `box_sconce`). Queda una banda algo más oscura en el centro del cristal.
- **Foto 2, botonera tapada:** fuera del marco de teca (`LIFT_CALL_GAP`).
- **Foto 3, mostrador:** tablero de 0,60 m (`FRONT_DESK.z` 1,0) con el terminal IBM 3178 y su teclado de cara al asiento.
- **Foto 4, z-fighting blanco en una pared:** **sin resolver**. No se reproduce (32 capturas de lejos y con zoom en dirección y secretaría, `rev9/panel/`) y un escáner de caras coplanarias (`rev9/coplanar_scan.gd`) no encuentra nada: friso y panel están a 1,5 cm. Hace falta la semilla y el sitio de la partida del autor.
- **Foto 5, fugas de luz a oscuras:** eran los volúmenes de rebote (VoxelGI), no las lámparas: `office_bounce.shines()`, `show_near()`, `INSET` y `OVERLAP`. Medido a 0 en salas cerradas en la semilla 7.
- **Fotos 6 y 7, cosas de lado:** el lector de microfichas y la nevera estaban horneados a 90° (`build_catalogue.gd` `YAW`); `office_models.FRONTED` y `office_dressing_test.fronts_face_seats()` vigilan 241 cosas con frente.
- **Foto 8, z-fighting en el dintel:** `SOFFIT_DROP` 4 mm en `door_frame_mesh()`. El marco de acero, sin tocar; no se vio en captura.
- **Fotos 9 y 10, luz que no sigue las luminarias y cortes por módulo:** a medias. La luz baja de las pantallas (`POOL_ENERGY` 2,4, `BOUNCE_ENERGY` 0,4; la lámpara de la sala con perfil `troffer` en Alto y Ultra) y las juntas de pasillo se solapan. Sin tratar: juntas nave con pasillo, la capa de lámparas de relleno y las galerías de servicio. Acabarlo pide cambiar el contrato de una lámpara por celda: decisión del autor.
- **Fotos 11 y 12, archivo móvil:** cuatro regletas que emiten, con foco y sombra (`archive_battens()`, `batten_spot()`).
- **Modelos:** de 48 bajados entran 15 (ventila de techo, rociador, luz de emergencia, armario de manguera, termostato y alarma, cámara, unidad de aire, lavabo, secamanos, terminal 3178, cafetera, lámpara de pie, butacas de espera, pilea y potus); los descartados están en `source_assets/oficinas/_rechazados/` y los que esperan, en su carpeta como `pendiente`. De los tres enlaces del autor solo la ventila era gratuita; la luz de emergencia (5,00 USD) y los ductos (6,90 USD) no se compraron. Los dos kits de ductos CC BY están bajados y sin usar: poner ductos a la vista es diseño nuevo.
- **Acabado:** butacas de espera en la esquina del ascensor (`office_recipes.wait_corner()`, `office_props.waiting_seats()`; `waiting_row_4` mide 3,5 m con largos `shorter`), mesa baja con la pilea, potus colgado, papelera de acero en código (`PROPS.steel_bin()`); suelo de pasillos `vinyl_hall.tres` (`marble` y `wear` en `tile.gdshader`); recepción con rugosidad −0,24 y `tilt_always`.
- **Queda:** el reflejo de la recepción sigue más tenue que la referencia; las butacas entran solo por el borde del encuadre de llegada (una pareja en la semilla 7); las vetas del suelo de pasillo se notan mucho; lavabo verde oliva por un error de conversión de color; la luz de emergencia muy oxidada; `fire_alarm` sin sustituto en código; todo visto en Alto y en las semillas 7, 33 y 101.

## No entró, y por qué

- De Sketchfab (quedan `pendiente` en `source_assets/oficinas/`): máquina de escribir de los años 30, expendedora de café (anuncio y rótulos en inglés), persiana (las del juego son un sombreador), archivador oxidado (se lee como ruina), puertas comerciales de Delly (piezas de varias puertas mezcladas), puerta doble (un solo objeto de 3 m), manilla y pomo (las puertas traen la suya), señal de salida (la del juego ya lo es), sofá de cuero (roto), cenicero de metal (ceniza y etiqueta), silla de aluminio y libros tirados (sin preparar).
- Horneados y sin usar: `escritorio_tanker_lenawachs`, `retro_oficina_yj_chair`, `silla_banquero_zamzam` (desde `afe8937`), `portalapices_aspectstudio` (4,8 k triángulos en cada mesa de una nave), `libros_frodoundead_row_b`. `projector_screen` está en `MODELS` pero ninguna receta lo pone.

## Pendiente

- Carros del archivo móvil.
- Climatizadora: parece dos lavadoras; una escalera de pie en mitad de la sala; la compuerta con volante, suelta.
- Taquilla escondite lisa (`hide_skin()`) y taquillas de aseos en silueta.
- Tubos de la central del correo que acaban en el aire, y tubos del correo neumático sin soportes.
- Repetición de cajas de archivo y de tablones de corcho.
- Zócalo del mostrador; fregadero con grifo.
- Huecos negros junto a algunas pantallas en naves y cubículos, sin causa confirmada.
- Churretes de pared a la misma altura: pide tocar un sombreado compartido con el hotel.
- Reja del montacargas en bandas.
- Centros de sala vacíos y objetos que definen la sala fuera de vista: fotocopiadora en reprografía, lavabos en aseos, mostrador con cristal en ventanilla, mesa de juntas pequeña.
- Sin comprobar en captura: placa colgante del techo, silla azul de cerca, blocs en la mesa de juntas, silla de secretaría, perchero en su sala, la puerta de mirilla girando y cerrada, el rebote en Medio y Bajo (en el código no sale allí: va con los focos, `pools_shown()`).
- Abrigo colgado sin modelo.
- El Art Institute bloquea la descarga automática.
