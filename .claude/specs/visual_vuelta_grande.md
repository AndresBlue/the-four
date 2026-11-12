# Frente visual del piso 2: la vuelta grande (12 de noviembre de 2026)

Estado al cerrar la vuelta, contado desde el código. Commits: `ff97bde` (cuatro modelos de Sketchfab), `43f1321` (tono, suelos, naves, carpintería), `c385f6f` (puertas y treinta modelos), `737345a` (lentes, techo, nogal, tubos), `0580306` (rendimiento y paredes) y `3f9c230` (generador). Lo que pidió el autor: sus capturas en `evidence/autor_12nov/1.webp` a `6.webp`, y su vara en la memoria `visual-bar-real-photo` (cada escena comparable con una foto de la época, juzgada en la vista de juego).

## Hecho

- **Luz** (`office_geometry.gd`; detalle en `spec_rediseno.md` 4):
  - gradación `GRADE` con `white` (1,2, 1,0, 1,15) y `ssao_light` 0,35, que `presentation_rig.apply_grade()` pone en `ssao_light_affect`;
  - poco especular: `LAMP_SPECULAR` 0,15 y `POOL_SPECULAR` 0,05; `POOL_ENERGY` 0,7; `LENS_MIRRORED` 30;
  - halo corto y débil (`HALO_REACH` 1,8, `HALO_ENERGY` 0,22) con caída suave en `ceiling_halo.gdshader`;
  - lentes con sus tubos: `lens_texture()` (`LENS_TUBES`, `LENS_DIFFUSER` 0,35), `lens_box()`, `LENS_LIT_DARK` 1 y `EMISSION_OP_MULTIPLY`; la perfilería ya no cruza una lente (`grid_spans()`);
  - la sonda solo cambia con el drenaje (`probe_strength()`, `PROBE_STEP`);
  - una sola lámpara de mueble encendida por sala (`office_models.LIT_MOST`).
- **Acabados:** vinilo y terrazo satinados (`map_roughness` −0,17 y −0,12), placa del techo más oscura y manchada (`ceiling_service.tres`), nogal más claro y con paneles (`walnut.tres`, `dado_oak.tres` con `panel_spacing`), pintura más sucia (`office_paint.tres`), tubos del correo neumático de latón gastado (`files_objective.gd`), molduras a 2 cm (`RAIL`, `DADO_CAP`).
- **Naves** (`office_layout.gd`, `office_generator.gd`, `office_palette.gd`): calles de `NAVE_STREET` 1,2 m (`streets()`, `way_out()`, `gap_of()`), islas de 4 o 6 puestos (`lay_islands()`, `desk_island`, `desk_island_6`, `ISLANDS_MOST` 3) con mamparas en cruz (`island_screens()`) y piezas en sus extremos (`island_ends()`, `ISLAND_ENDS`), paredes cerradas llenas (`lay_wall_rows()`, `NAVE_WALL_ROW`, `NAVE_WALL_DEPTH`), mampara de 1,2 m (`FURNITURE.partition`), y ella solo sale por placas sobre las calles (`free_tiles()`).
- **Recetas y paredes:** más piezas en las recetas de casi todas las salas, `tv_cart` en descanso y juntas, papeles junto a lo que se usaba (`floor_papers()`), objetos tirados por tipo (`office_palette.LITTER_KINDS`, `office_clutter.litter()`), cuadros y tablones en grupos que prueban primero la pared que se ve desde la puerta (`CLUSTERED`), y un elemento cada 2 m en los pasillos (`CORRIDOR_PITCH`), con su hueco libre de muebles (`HALL_SLOT_CLEAR`). Pasillos con mueble cada 5 a 8 m (`HALL_STEP`).
- **Modelos:** puertas (`DOOR_MODELS`, `STEEL_FRAME`, `service_door()`, marco de nogal moldurado en `door_frame_mesh()`), taquillas, archivador gris, detector de humo y unos cuarenta modelos más en `office_models.MODELS` (lista en `docs/OFICINAS.md` 12). Herramientas: `register_sketchfab.py`, `fit_model.py` con `fit_models.json`, `TINT` en `ingest_models.py`, `PLACED` en `build_catalogue.gd`.
- **Rendimiento:** solo proyectan sombra las piezas grandes de suelo (`office_models.casts()`, `CAST_LEAST`); plantas, papeleras, lo de pared y lo de encima de los muebles, no. Banco en `evidence/bench/piso2_dens6_final_forward_plus/` (cifras en `spec_rediseno.md` 10).
- **Generador:** `office_recipes.Near` prueba cada tramo como un solo rectángulo antes de hacer las piezas, una pieza «spare» que no cupo no se vuelve a probar con otra igual o mayor (`spare_fails`), y las naves no prueban sus «spare». El commit lo midió en un segundo por piso.

## No entró, y por qué

- De Sketchfab (quedan `pendiente` en `source_assets/oficinas/`): máquina de escribir de los años 30, expendedora de café (anuncio y rótulos en inglés), persiana (las del juego son un sombreador), archivador oxidado (se lee como ruina), puertas comerciales de Delly (piezas de varias puertas mezcladas), puerta doble (un solo objeto de 3 m), manilla y pomo (las puertas traen la suya), señal de salida (la del juego ya lo es), sofá de cuero (roto), cenicero de metal (ceniza y etiqueta), silla de aluminio y libros tirados (sin preparar).
- Horneados y sin usar: `escritorio_tanker_lenawachs`, `retro_oficina_yj_chair`, `portalapices_aspectstudio` (4,8 k triángulos en cada mesa de una nave), `libros_frodoundead_row_b`. `projector_screen` está en `MODELS` pero ninguna receta lo pone.
- Abrigo y toalla: la simulación de tela (`tools/props/cloth_pieces.py`, sin seguimiento) no salió; siguen en código.

## Pendiente

- `verify.ps1` y que el autor la juegue.
- Lo de `docs/PLAN.md` 3 («Lo que quedó de la vuelta grande»).
- Las puertas, en el juego: que no rocen el marco y que las bisagras queden en su canto.
