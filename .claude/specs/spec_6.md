# Área 6: el cierre del rediseño del piso 2

Nota de diseño del director, 10 de noviembre de 2026. Es la fila 6 de la sección 12 de `spec_rediseno.md`, que manda en lo que esta nota no cambie. Le precede el área 4e, cerrada en `ddcbace`: `office_proportion_test` da 52/55 y sigue fuera de `verify`.

## Lo que entra

1. **La versión del piso 2.** `office_palette.VERSION` pasa de 1 a 2 (`office_floor.GENERATOR_VERSION` la toma de ahí). Con eso, un punto de control o un Continuar del piso 2 de antes del rediseño deja de cargarse (`game_session.gd:279`, `match_net.gd:1228`): es lo que se quiere, porque el mismo número de semilla ya da otro piso. `office_test.gd:297` comprueba hoy `GENERATOR_VERSION == 1` y pasa a 2. El hotel no cambia: su versión sale de `floor_definition.gd`.
2. **Los créditos.** La línea «MODIFICACIONES» de `relleno_assets.md` («Créditos que faltan para el área 6») entra en `CREDITS` de `hotel_ui.gd`, tras «SONIDO DE LAS OFICINAS», con su texto literal. Las líneas de la silla y del difusor solo entran si la pieza está en el juego: hoy ninguna de las dos lo está (ni `old_computer_chair` ni «Airduct Vent» aparecen en `ASSETS.md` ni en el código), así que no entran. Ninguna línea lleva «·» ni «—».
3. **El encuadre de las capturas.** En `tools/capture/office_rooms_capture.gd`, la hoja de la puerta junto a la que se pone la cámara tapa parte del cuadro (sale en el borde derecho de las capturas `_juego`). Mientras se hace la captura, la herramienta oculta esa hoja (`visible = false` en su nodo), y solo esa. No se toca nada del juego. Que cada captura vea una sola pared se acepta.
4. **El rendimiento contra la base.** `hotel_benchmark.gd --floor=2 --difficulty=apacible` (lo que anota `docs/PERFORMANCE.md`, sección 13) se corre en Alto, Muy bajo y Compatibilidad, y su resultado se escribe en esa sección junto a la base, con el tiempo de montaje del piso. La meta es la de `spec_rediseno` 10: 60 FPS a 1080p en Alto, es decir, un tiempo de fotograma de 16,7 ms o menos en las vistas fijas. **Si no llega, esta área no lo arregla:** sube al director con la vista que falla y su cifra.
5. **Las capturas finales.** `office_rooms_capture` con el prefijo `final` (o la carpeta `evidence/rediseno/final/`, según admita la herramienta), en Alto y con el campo del juego en Muy bajo, más las vistas de edificio. Las mira el director. La sección 11 de `cifras.json` (criterios a y b) da `false` en las 15 salas desde 4d: no se persigue en esta área. Sus cifras se copian al informe final, y el criterio que vale es el visual del director (`spec_rediseno` 11, c a f).
6. **Los documentos, contra el código.** Cada documento lo audita una unidad, que corrige solo lo que no es verdad y no reescribe lo que sí lo es:
   - `docs/OFICINAS.md`: entre otras cosas, la línea 209, que dice que la cuota «abre la reja», cuando en el código abre la puerta de etapa;
   - las secciones del piso 2 de `docs/DEVELOPMENT.md`;
   - `docs/ASSETS.md`: las filas de las oficinas, contra `assets/props/office/` y `materials/office/`;
   - `docs/PERFORMANCE.md`, sección 13, con la cifra del punto 4.
7. **La exportación**, la única del rediseño (R8). La hace el director, después de los puntos 1 a 6 y con verify en verde: `tools/godot.ps1 export` y `exports/windows/Probar piso 2.bat` dentro del zip como `The Four/Probar piso 2.bat`. Después la subida a Drive, con el método de siempre (copia fechada y reemplazo del mismo archivo). Antes de exportar, el director pregunta al autor el número de versión (`project.godot` sigue en 1.2.0, y desde `v1.2.0` hay 187 commits).

## Lo que no entra

- Los tres tipos bajo su banda en `office_proportion_test` (ventanilla, dirección y juntas): quedan para el relleno o para el autor.
- Los defectos de `office_test` vistos en 4e B (`.claude/relevo.md`), al relleno. Arreglar el de `numbered_` puede destapar un FAIL, y no cabe en un cierre.
- La cuota de `cue_pose` (0,876 frente a 0,900), C6b y el p99 de `office_metrics`: son cifras anotadas, no defectos. Van al informe final.
- `evidence/4b_probe_props.gd` (48/49, el `glow_strip`), que es una sonda vieja, y el cruce de los tubos neumáticos con la franja del techo, que va al relleno.
- El umbral de `office_test_generator`: pasa (2.750 ms).

## Orden y máquina

- Los puntos 1, 2 y 6 no ejecutan Godot con ventana y escriben archivos disjuntos: van en paralelo. Las pruebas de Godot las corre después su revisor, en serie: `office_test_validator` por el punto 1 y `--check-only` de `hotel_ui.gd` por el 2.
- Los puntos 3, 4 y 5 abren ventana: en serie, de uno en uno y en ese orden (el 5 usa el encuadre del 3).
- La auditoría de `PERFORMANCE.md` va después del punto 4.

## Aceptación

- `verify.ps1` en verde, incluida la comprobación nueva de la versión 2.
- `CREDITS` con «MODIFICACIONES», y un `grep` sin «·» ni «—» en `hotel_ui.gd`.
- Las capturas finales en su carpeta, sin la hoja de la puerta en el cuadro, vistas por el director.
- `PERFORMANCE.md` con la cifra del piso 2 en los tres preajustes junto a su base, y el veredicto sobre los 16,7 ms.
- Los cuatro documentos auditados, con cada corrección citando la línea del código que la justifica.
- El zip con `The Four/Probar piso 2.bat`, y la subida a Drive con el mismo id de archivo.

## Tras los críticos (10 de noviembre): manda sobre lo de arriba

Dos críticos Opus revisaron la nota contra el código. Donde esta sección contradiga lo anterior, vale esta.

**A. La exportación y el `.bat`.** `tools/godot.ps1 export` borra el zip y lo rehace con cuatro archivos fijos (`godot.ps1:145-155`), y `exports/` está en `.gitignore`. El `.bat` de hoy entró a mano y no está en git.
- `Probar piso 2.bat` pasa a git en `tools/export/Probar piso 2.bat`, con el contenido de `exports/windows/Probar piso 2.bat`.
- `godot.ps1 export` lo copia a `exports/windows/` y lo añade al zip como `The Four/Probar piso 2.bat`, tras el bucle de los cuatro archivos.
- `Observador.bat` se queda fuera del zip.
- Aceptación: las entradas del zip, listadas con `ZipFile.OpenRead`, son cinco.

**B. La prueba de la versión.** La comprobación de `office_test.gd:297` está en `kind_checks()`, que corre en `office_test_generator` y no en `office_test_validator`. El revisor del punto 1 corre `office_test_generator`. Se cambian el título («su generador es la versión 2») y `GENERATOR_VERSION == 2`.

**C. El número del juego.** `docs/DEVELOPMENT.md` («Versiones») pide al menos un parche por un cambio de `GENERATOR_VERSION`, y MENOR por un piso nuevo. El director pregunta el número al autor. Una unidad redacta el apartado de `docs/CHANGELOG.md` desde `git log v1.2.0..HEAD`, con el número como `X.Y.Z` y su fila en la tabla, y el director pone el número. `project.godot:18` cambia antes de exportar, para que lo lleve el ejecutable. La etiqueta va sobre el commit exportado.

**D. Lo que el punto 1 no prueba**, y va al relleno o al informe final:
- Ninguna prueba escribe un punto de control del piso 2 con una versión vieja (`continue_test.gd:159-175` solo usa el hotel y el piso 3).
- Los récords y las grabaciones de bots se sellan con la versión del hotel (`records_service.gd:92` y `253`, `bot_recorder.gd:63`, `bot_replay.gd:71`). Antes de publicar el piso 2 tendrían que sellarse con la de su piso.

**E. Los créditos** siguen el patrón de la videocámara (`hotel_ui.gd:39`), que dice la modificación en la línea de la obra:
- la línea del ascensor (`hotel_ui.gd:37`) añade «, reescalado y sin su pared» (`ASSETS.md:58`);
- en vez del bloque «MODIFICACIONES», el bloque «SONIDO DE LAS OFICINAS» acaba con la línea «Estos sonidos están recortados o procesados para el juego.».

Así ninguna frase general cae sobre el bloque PERSONAJES.

**F. El punto 3, cómo se oculta la hoja.** Con `layered` (Alto y Muy bajo), `Leaf` ya está oculto y la hoja la dibujan `Leaf_0`, `Leaf_1` y las placas. Además, `round_rooms` vuelve a mostrar el nodo de la puerta (`hotel_geometry.gd:2229-2264`, `3051`).
- Se ocultan todos los `GeometryInstance3D` descendientes (`find_children("*", "GeometryInstance3D", true, false)`) de las puertas que devuelve `level.hotel.doors_near(door.portal, 1.2)`, las mismas que abre `open_doors` (`office_rooms_capture.gd:164`).
- Se ocultan después de `open_doors` y se restauran al acabar la sala. El nodo de la puerta no se oculta.
- No se ocultan en las vistas `vano_`.

**G. El punto 4, las órdenes literales.**
- `./tools/benchmarks/run_bench.ps1 -Label piso2_final -Extra '--floor=2 --seed=7 --difficulty=apacible --qualities=2,4'`, y la misma con `-Compatibility`.
- La comparación con `./tools/benchmarks/bench_table.ps1 piso2_base,piso2_final`, y la misma con `-Renderer gl_compatibility`.

Las vistas se comparan por papel (inicio, medio y lejos) y no por id. La tabla anota el id y el tipo de sala de cada vista, en la base y ahora.

**El veredicto:** cada vista fija de Forward+ en Alto pasa si cumple dos cosas:
- `frame_ms.p95` es 16,7 o menos;
- `max(gpu_ms.mean, cpu.at_60.p95)` es 16,7 o menos.

Una cifra que ya fallaba en la base se compara con la base. Muy bajo, Compatibilidad, `arrival` y `walk` se anotan sin veredicto. El montaje se anota junto a los 13.199 ms de la base, también sin veredicto. `PERFORMANCE.md` dice que el banco cubre tres salas de la planta 1 y no comprueba el tope de triángulos.

**El banco corre solo.** Antes se comprueba con `tasklist` que no hay otro Godot ni `TheFour.exe`. Si `TheFour.exe` está abierto, se avisa al director y nunca se mata.

**H. El punto 5: dos pasadas**, en serie y después del punto 3:
- `--prefix=final --quality=2`;
- `--prefix=final_muybajo --quality=4`.

Las dos van con la semilla 7, y las vistas de edificio salen en ambas.

**I. La auditoría** añade dos documentos:
- `docs/GAME_DESIGN.md:17`, que dice que el piso 2 está «sin hacer»;
- `docs/PLAN.md:836-837`, que da el rediseño por pendiente.

En `OFICINAS.md`, la frase es la de la línea 210: «Con las fichas de la cuota, se abre la reja».
