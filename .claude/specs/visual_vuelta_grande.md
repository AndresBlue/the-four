# Frente visual del piso 2: la vuelta grande (12 de noviembre de 2026)

Estado de trabajo, no diseño cerrado. Lo escribió el director al quedarse sin ventana de cuota a media vuelta. Manda `.claude/relevo.md`; esto guarda lo que no cabe allí.

## Lo que pidió el autor

Sus capturas están en `evidence/autor_12nov/1.webp` a `6.webp` y su vara en la memoria `visual-bar-real-photo`: que cada escena se pueda comparar con una fotografía de la época, juzgada en la vista de juego (con la cinta).

## El árbol de trabajo NO está comprobado

Hay cambios sin confirmar de tres agentes y **ninguno ha pasado por Godot entero** (ni `--check-only`). El último estado bueno es el commit `ff97bde` (más `d581c7d`, solo la nota de relevo).

- **Un proceso de Godot quedó colgado (PID 2800)**: una captura del agente de luz. El sistema de permisos denegó cerrarlo; se le pidió al autor. Antes de lanzar Godot, comprobar con `tasklist` que no sigue.
- **Luz, ronda 4** (`office_geometry.gd`, `presentation_rig.gd`, `ceiling_halo.gdshader`, `vinyl.tres`, `terrazzo.tres`, `wet_tile.tres`):
  - tono: `GRADE.white` (1,2, 1,0, 1,15); la vista de juego medida queda en matiz 29,5° (referencias 28,6°; las capturas del autor, 39,8°). El verde lo ponía la cadena de la cinta. Comprobado en `evidence/rediseno/luz4/`;
  - reflejos: `LAMP_SPECULAR` 0,15, `POOL_SPECULAR` 0,05, vinilo `map_roughness` −0,17, terrazo −0,12, `LENS_MIRRORED` 30. Visto en `luz4/archivo_juego.png`;
  - techo: `HALO_REACH` 2,6, `HALO_ENERGY` 0,45, caída suave. Sin ver en una nave;
  - lentes con tubos (`LENS_LIT_DARK`, `LENS_TUBES`, `LENS_DIFFUSER`, `lens_texture()`, `lens_box()`) y azulejo de los aseos: **sin verificar** (la captura falló);
  - sombra de contacto: `POOL_ENERGY` 0,7 y `ssao_light` 0,35 en la gradación;
  - z-fighting: descartados cámara (`near` 0,05, `far` 95) y suelos solapados; corregida una moldura (`RAIL.y`, `DADO_CAP.y` 0,02). Sin causa única; los objetos de mesa, sin revisar.
  - Le falta: pasada de cuatro salas, pasada completa `--prefix=luz4`, las siete pruebas cortas y `office_pieces_test`.
- **Densidad, ronda 2** (`office_layout.gd`, `office_generator.gd`, `office_validator.gd`, `office_recipes.gd`, `office_palette.gd`, `office_clutter.gd`, `office_props.gd`, `office_walls.gd`, `tests/office/office_test.gd`): naves con calles fijas de 1,2 m (`NAVE_STREET`, `streets()`, `way_out()`), islas de 4 o 6 puestos con mamparas en cruz (`lay_islands()`, `desk_island`, `desk_island_6`), pared del fondo llena (`lay_wall_rows()`, `NAVE_WALL_ROW`), `DESKS_MOST_NAVE` 16, mampara de cubículo a 1,2 m (cambia la sección 6.17 de `spec_rediseno.md`), ella aterriza solo en calles (`free_tiles()`), más ocupación en 19 tipos de sala, ninguna superficie desnuda, papeles por el suelo (`floor_papers()`), pasillos con algo cada 5 a 8 m. Ocupación estimada de la nave fuera del pasillo: 33 a 41 %. Le falta todo lo de Godot: `--check-only` de sus archivos, sonda de ocupación y tiempo del generador, captura de una nave, `office_test_generator`, `_validator`, `_physics`, `office_walk_test`, `lurker_tiles_test`, `office_dressing_test`, `office_lies_test`, `lurker_bots_test`. Dos mentiras de `lurker_hallucinations.gd` («silla», «mampara») pierden sitio en las naves de oficina abierta.
- **Ingesta, ronda 2** (`office_models.gd`, `office_props.gd`, `office_clutter.gd`, `office_fittings.gd`, `hotel_ui.gd`, `office_dressing_test.gd`, `tools/props/*`, `docs/ASSETS.md`, `docs/asset_hashes.json`, `docs/DEVELOPMENT.md`): seis piezas ingeridas y sin hornear. `office_dressing_test` falla hasta hornearlas.

## Carpintería: lista para hornear

En `source_assets/oficinas/carpinteria/` (registro propio). Hornear con `--import` y luego `build_catalogue.gd --only=<slug>`:
`puerta_oficina_sousinho` (madera con mirilla), `puerta_lisa_sousinho` (madera lisa), `puerta_metal_tboiston` (hoja y marco de acero), `taquilla_zambur`, `archivador_gris_ahmagh2e` (cerrado, cuerpo y cajón), `detector_humo_sousinho`.

No valen (quedan `pendiente`): Commercial doors de Delly (piezas mezcladas), Double door (un solo objeto de 3 m), manilla y pomo (las puertas traen la suya), señal de salida (la del juego ya es eso).

### El cambio pendiente en `office_geometry.gd` para las puertas

Aplicarlo cuando la luz esté cerrada (mismo archivo). Junto a `var office_doors`:

```gdscript
## The doors' downloads by leaf_mesh()'s key (tools/props/fit_model.py); the leaf made in code where one is missing.
const DOOR_MODELS := {"vision": "res://assets/props/office/puerta_oficina_sousinho_leaf.res", "plain": "res://assets/props/office/puerta_lisa_sousinho_leaf.res", "service": "res://assets/props/office/puerta_metal_tboiston_leaf.res"}
const STEEL_FRAME := "res://assets/props/office/puerta_metal_tboiston_frame.res"
```

Sacar a `service_door(a, b)` la condición de acero que hoy está dentro de `leaf_mesh()`; en `leaf_mesh()`, cargar `DOOR_MODELS[key]` si existe y si no `door_leaf_mesh(steel, key == "vision")`; en `frame_mesh()`, el marco de acero para las de servicio y `door_frame_mesh()` para las demás. Las hojas usan el espacio de la del hotel (eje en el origen, hoja hacia +X, suelo en y = 0). Comprobar en el juego que no rozan el marco, que las bisagras quedan en su canto y la luz por las rendijas.

## Descargas sin tocar todavía

Todas con licencia CC Attribution comprobada en la página al bajarlas (Sketchfab, con la sesión del autor; el navegador guarda en `models/`, carpeta del autor e ignorada por git). Procedimiento del agente de ingesta: `tools/props/register_sketchfab.py`, `fit_models.json` y `fit_model.py` para lo que se monta por partes, `decimate.py --drop --weld`, `PATCHES` en `ingest_models.py`, hornear.

**Muebles y aparatos** (zip en `models/`, autor, para qué, qué tapar):
- `steelcase_tanker_desk.zip`, lena-wachs: `desk_steel`, el puesto de las naves. Lo mejor de la búsqueda.
- `game-asset-chair.zip`, projectkaizen: `office_chair` de tela azul (37 k: diezmar).
- `retro_office_props.zip`, YJ_: sacar solo el escritorio verde y la silla cromada; descartar el teléfono con pantalla y el ratón.
- `antique_desk.zip`, Matthew Collings: `desk_walnut` de dirección y secretaría.
- `wooden_office_chair.zip`, M. Zamzam: silla de banquero de madera.
- `herman_miller_-_eames_aluminum_chair.zip`, Photonic Studio: `exec_chair`; recolorear el naranja a negro o marrón; comprobar que no lleva logo.
- `vintage_wooden_armchair_-_low_poly__game_ready.zip`, Renend Studio: `visitor_chair` y sillas de espera.
- `wooden_bookcases_with_books.zip`, Matthew Collings: `bookcase`.
- `vending_machine.zip`, AtTheSpeedOf: `vending_machine`; tapar el rótulo «Dandee Lion» y los botones en inglés.
- `old_fridge.zip`, dylanheyes: `fridge` (32 k: diezmar).
- `monstera_deliciosa_potted_mid-century_plant.zip`, Giora: planta grande de pasillos y naves.
- `okidata_microline_320_turbo.zip`, Remik.Papaj: `dot_matrix_printer`; tapar el rótulo del frontal.
- `vintage_fan.zip`, Josh Smith: ventilador de mesa.
- `old_vintage_leather_sofa.zip`, atomizr: sofá de espera.

**Objetos pequeños**:
- `old_vintage_desk_lamp.zip`, Jeff_Meunier: lámpara de banquero verde.
- `old_lamp.zip`, Sousinho: flexo de cuello de cisne.
- `vintage_metal_ashtray.zip`, mattyu, y `glass_ashtray.zip`, RED2000: ceniceros.
- `antique_book_set.zip`, FrodoUndead: 31 libros sueltos; elegir los de lomo sobrio.
- `2_boxes.zip`, Cozmoth: cajas de archivo; virar el blanco a kraft.
- `pencils_w_holder.zip`, AspectStudio: portalápices (diezmar).
- `document_letter_tray__documents_organizer.zip`, sinnervoncrawsz: bandeja de tres pisos.
- `retro_antique_desk_clock.zip`, Sousinho: reloj de mesa.
- `antique_globe.zip`, mtcollings: globo de dirección.
- `old_oxford_shoe.zip`, inciprocal.com: zapato (duplicar en espejo).
- `pile_of_books.zip`, mreslan: libros tirados; recolorear una cubierta azul con estrellas.
- `dirty_damaged_fatigued_cardboard_box.zip`, krolzuzannapl: caja sucia.
- `several_folders.zip`, janexx: archivadores de palanca; repintar las etiquetas manuscritas en inglés.
- `extension_cord_scan_medpoly.zip`, evan4129: alargador en el suelo (diezmar).

**De Poly Haven (CC0), bajados y registrados como `pendiente`** en `source_assets/props/`: `vintage_stapler` (tapar «Haven Penworks»), `plastic_thermos` (tapar «THERMOS»), `modified_thermos`, `metal_toolbox`, `dustpan`, `wooden_ladder_02`, `wooden_broom`, `mousetrap`, `magnifying_glass_01`, `round_spectacles`, `projector_screen`, `Television_01` (tapar el logo «VTECH»), `boombox` (tapar pegatinas y rótulos). Faltan en `SKIP` de `ingest_models.py` y `build_catalogue.gd`: por eso `check_ingest_models.py` da 18 diferencias en el hotel hasta añadirlos.

## Lo que no existe con licencia válida y seguirá en código

Difusores y rejillas de techo, rociadores, interruptores de época, mamparas de cubículo, paneles de madera de pared, fotocopiadora de los 80, máquina de escribir eléctrica, fax, retroproyector, cafetera de época, mesa de comedor de laminado y sillas apilables, escritorio en L, abrigo colgado y toalla (hacerlos con simulación de tela en Blender), papeles y periódicos sin texto, calculadora, perforadora.

## Orden para seguir

1. Con Godot libre: `--check-only` de todos los `.gd` cambiados; arreglar lo que no compile.
2. Cerrar la luz (cuatro salas, pasada `luz4`, pruebas cortas) y confirmarla sola.
3. Hornear carpintería, aplicar el cambio de puertas, capturar y confirmar.
4. Verificar la densidad (sonda, captura de nave, pruebas) y confirmar.
5. Ingerir muebles y objetos, cablear por clases (las recetas no cambian), capturar.
6. Comparar cada sala con su referencia en `_juego.png` y decir qué delata el 3D.
7. `verify.ps1` al cerrar el frente; documentos al día.

Lección de esta sesión: mientras un agente captura con Godot, nadie más escribe en el árbol código que carga el juego (una captura cayó con `office_generator.gd` a medio escribir).
