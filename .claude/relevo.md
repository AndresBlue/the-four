# Nota de relevo

Lo que una sesión nueva tiene que saber para seguir. Se reescribe en cada relevo; lo que ya está en git o en los documentos no se repite aquí.

**Última actualización:** 23 de octubre de 2026, de madrugada. La semana va al 80 %: el autor subió su tope al **90 %** hasta que se renueve, el 24 de octubre a las 05:00.

**Última instrucción del autor:** seguir el desarrollo **sin workflows, solo con el agente principal**, hasta el 90 % semanal, **sin parar por la ventana de contexto** (23 de octubre: la regla del 60 % de CLAUDE.md no rige en esta tanda). 1b se hizo así entera, unidad a unidad de `encargos_1b.json`, cada una con su sonda en `evidence/1b_probe_U<n>.gd`.

## En qué estamos

**El piso 2, las oficinas secretas** ([docs/OFICINAS.md](../docs/OFICINAS.md)). La fase 0 está cerrada; de la fase 1, 1a y 1b están hechos y 1c, a medias.

| Paso | Estado |
|---|---|
| Fase 0 (0a a 0f) | Hecha: 0a `3b909f0`..`d32f23a`, 0b `86a4333`, 0c `9f759db`, 0d `592dce2`, 0f `1f09795`, 0e `db7eca1` |
| 1a Tipo de piso de oficina, paleta, criatura nula | Hecho (`54e99d9`): construido, sin publicar (`floor_index.RELEASED = [1]`) |
| 1b Generador de oficinas | **Hecho**: U1 a U5 `3bf5ab6`, U6 `6010f41`, U7 a U10 `8dcc122`, U11 y U12 `1231cb5` |
| 1c Validador y `office_metrics` | **Hecho**, sin encargos (el director solo): hechos el refactor de la física base (`room_sweeps()`, `passage_path()`), `office_validator.validate()` con los 15 grupos de la spec 3.1 y la sección «validador» de `office_test` (28 mutaciones y el piso de respaldo); `validate_physics()` de oficinas (3.2) escrito, sin probar hasta 1d; `tools/dev/office_metrics.gd` (3.3) hecho; falta la mutación de la altura de la sala de juntas; `duct_shortcuts` no se exige (ver «Enlaces sueltos») |
| Contrato para montar el piso 2 en escena | **Hecho** (commit siguiente a `b2a16ec`): `creature.gd` suma `start_room()`, `place_at()`, `arm()`, `presence_sound()` (no `sound_profile()`: The Locust ya tiene una variable con ese nombre), `hunter_camera()` y `blackout()`; `hotel_main` solo pregunta eso; `creature_contract_test` 177/177. Queda de las notas de 1a: el Continuar de un piso 2 fuera de `--test-profile` (`built(2)`) |
| 1d Geometría de oficinas | **Empezado**: los ganchos del hotel (spec_f1_geometry 3: H1 a H10 en `hotel_geometry.gd`, R1 a R4 en `room_dressing.gd`) hechos y sin cambio en el piso 1 (galería idéntica normalizada, golden, `stages_test`, `room_light_test`, contrato). H9 solo da `lift_sounds()` y `hum_path()`: `lifts.gd` y `world_audio.gd` siguen con sus rutas hasta que haya sonidos de oficina. `game/world/office/office_geometry.gd` existe, mínimo: hereda del hotel, `nav_agent_radius()` 0,3 y los acabados de oficina (`vinyl`, `terrazzo`, `concrete`, `office_paint`, `block`, `veneer`) como materiales del hotel provisionales (meta `stand_in`) hasta la ingesta; `office_floor.GEOMETRY` ya es él. Con eso **el piso 2 se monta** (`start_floor(7, ..., 2)`: 507 luces, la criatura nula), con aspecto de hotel, y la física de 1c lo rechaza: archivos sin estanterías propias (`archive_aisle_*`), las lámparas del hotel en la franja sobre el falso techo (`ceiling_band_*`) y algunos pasos y barridos de puerta. Después (mismo día): `office_props.gd` con las piezas de esquina procedurales de 9.3 (las que piden modelo, no: escritorio, archivadores, sillas, sillón, copiadora, lector, clasificador, vending), los archivos sin vestir (9.5), el generador quita las piezas de esquina del barrido de las puertas (y el validador lo mira), el barrido de los pasillos de archivo para un radio antes del fondo, y la franja del techo deja fuera las taquillas (2,3 m, `hiding_place.HEIGHT`, que 9.7 manda conservar: decisión del director). Luego las estanterías de archivo (9.4, `office_props.row()`, cada fila partida por celdas). **Tres pisos montados (7, 21, 33, con un superviviente) pasan la física**, y `office_test` lo comprueba con un nivel nuevo por semilla (en uno ya jugando, `start_floor()` no vuelve a montar; antes se comprobaba tres veces el mismo). Para eso, en la física de oficinas: los pasos por un archivo giran en la línea de su columna central (también para puertas en pared corta), los barridos de esquina no llegan a la pared del ascensor en un vestíbulo de 9 m ni se hacen en salas sin piezas de esquina, y los rayos bajo las rejillas no cuentan las taquillas. Luego el falso techo de placas (5.2, sin manchas de humedad ni detectores aún) con su colisionador sobre las placas, la perfilería en T, las luminarias (7.1: la luz de tubo de la sala, sin la cúpula del hotel), rejillas y lo oscuro del plénum sobre cada hueco; capturas en `evidence/office_look_*.png` (sin seguimiento). Luego las paredes (6.2 en parte): pintura lisa, rodapié, la franja del departamento en los pasillos, sin cuadros ni apliques del hotel (6.5); pintura, bloque y hormigón como colores lisos provisionales. La cabina del montacargas (7.4) y su puerta de tijera (7.5, `game/world/office/scissor_gate.gd`) también están. Sigue 1d (el rótulo de zona ya va en la franja, una vez por celda de pasillo): las persianas (6.4) y el sombreador de cristal armado (el cristal de 6.3 ya está, con un material transparente provisional), los tablones y relojes (6.5), las puertas de oficina (6.6), las luces de emergencia (7.2), y lo que pide ingesta. Las luminarias de 7.1 ya están (regletas sobre los pasillos de archivo, dos globos colgados en la sala de juntas, el cuarto eléctrico sin lámpara propia) y el vinilo y el terrazo son colores lisos provisionales. Los muebles de `room.furniture` (9.2) ya se montan (`office_props.build_item()`): escritorios y sillas procedurales en lugar de `metal_office_desk` y `school_chair_01` (sin ingerir; el catálogo salta el escritorio), mamparas, mesa de juntas con sus sillas, casillero, copiadora, vending y fichero. Falta todo lo demás de `office_geometry.gd` (secciones 4 a 11), los materiales de verdad, los sombreadores, las puertas y la ingesta de assets |
| 1e a 1i, fases 2 a 5 | Pendientes |

**Lo primero al retomar:**
1. Leer el uso (`mcp__ccd_session_mgmt__get_usage`). Hasta el 24 de octubre a las 05:00, el tope es el 90 %.
2. Si el commit de 1c no está hecho (`git log`): estaba pendiente de un `verify.ps1` en verde. Archivos: `game/world/generation/map_validator.gd`, `game/world/generation/office_validator.gd`, `tests/office/office_test.gd` (124 checks, unos 205 s solo), `tools/verify.ps1` (600 s para `office_test`), `docs/DEVELOPMENT.md`, `.claude/relevo.md`.
3. 1c está cerrado. `office_metrics -- 1000` (23 de octubre, con los troncos rectos): **54/56**; respaldo 0,2 %, 0 rechazados, mediana 1.281 ms; FAIL atajos 5 % (spec 10 %) y p99 2.924 ms (spec 700). Con 200 pisos: 1 superviviente 54/56 (los mismos dos FAIL); 5 supervivientes 52/56: además, respaldo 0,5 % (el límite es menos de 0,5 %) y mediana 1.851 ms (pisos más grandes). Con 20 pisos (y los troncos rectos) falla la parte de atajos (5,8 %, decisión 2) y el p99 del tiempo (más de 2.000 ms contra 700 de la spec; la mediana, unos 1.400).
4. Después: 1d (geometría de oficinas, `spec_f1_geometry.md`), que necesita los assets que piden sesión (ver «Assets»); y probar `--floor=2` de punta a punta. Probado el 23 de octubre sin ventana (`start_floor(7, ..., 2)`): el manifiesto sale (507 salas) con la criatura nula, pero el montaje se para en la geometría del hotel, que no tiene materiales para los acabados de oficina (`vinyl`, `block`); eso es de 1d.

## Lo que 1b hizo distinto de la especificación (decisiones del director)

- **Puentes de conductos:** el árbol de ramas cuelga cada sala de un solo padre, así que dos salas con puerta entre ellas podían quedar en trozos distintos; se unen primero esas puertas (como andar, 1,0), por par menor, y solo después vecinas sin puerta con L / paseo >= 0,55. Sin esto, 19 de 20 semillas caían al piso de respaldo.
- **Tubos:** los tramos van a 0,3 m de la cara interior de la pared (no del borde de la celda), para que el vano y la boca de una misma pared queden alineados.
- **Piso de respaldo:** con todas las paredes con puerta, el cuadro, la mesa de la ventanilla y la consola de la seguridad pueden ir en una pared con vano (lejos de él, como una taquilla).
- **Musts:** `place_musts` bloquea las salas con las que cuenta cada must (las primeras unidades por id, un salón como una) y los aseos que ya hay, porque los aseos y `cap_numbers` se llevaban la única sala de juntas o los aseos dibujados por la mezcla.
- **office_test:** los aseos se exigen solo en sectores con alguna sala libre junto a un pasillo (la regla de `place_musts`), y la sala de juntas solo donde hay un módulo grande libre.
- **Cachés** por piso de las tejas libres y de la línea del conducto principal (la mediana bajó de unos 1.500 ms a unos 1.400).
- **Enlaces sueltos (decisión del autor, 23 de octubre):** el atajo se mide contra el paseo de puerta a puerta (`conduit_metres.door_metres()`: del centro a la puerta, de puerta a puerta cruzando cada sala y al centro de la otra), con el umbral de 0,55. Pasan pocos pares (de 0 a 6 de unos 70 por planta): si el sorteo deja una planta sin ninguno, el generador pone el mejor que pase. Exigir uno en cada planta tiraba demasiados pisos (4 de respaldo en 40), así que es lo mejor posible: `office_test` pide que lo tengan tres de cada cuatro plantas o más. El validador no exige `duct_shortcuts`.
- **Validador (1c):** acepta `bridge` entre salas con puerta (las que une el árbol de ramas), mide el despeje de las salidas aunque estén fuera de su sala, y agrupa por sala los puntos de pared una vez por piso (sin eso `office_test` tardaba 253 s; ahora unos 205).

## Decisiones que esperan al autor

1. **Muebles de las oficinas abiertas:** la especificación pide una mediana de 2 piezas por celda y sale 1 (de 927 celdas, 270 vacías). Las zonas de paso (`clear_zones`: el centro, los barridos a las esquinas, las puertas, las taquillas, los props de esquina) se comen la retícula. `office_test` vigila «1 o más» hasta decidir: ajustar las zonas, la retícula (probar otras esquinas) o el umbral.
2. **Cuánto atajan los conductos:** por decisión del autor hay troncos rectos (`express`, 30 por planta) por encima de las salas. `office_metrics` (conducto de nodo a nodo, sin las bajadas a las rejillas, contra el paseo de puerta a puerta) da ahora un 5,8 % de pares de salidas a 12 m o más que atajan entre 0,55 y 0,9 (la spec pide 10 %). Con 60 troncos llega al 7,8 %, pero el piso tarda unos 1.800 ms: cada tronco solo une sus dos extremos, porque una parada intermedia entre salas vecinas bajaría de 0,55. Decidir: aceptar el 5 % como meta, o pagar más tiempo.
3. **Tiempo del generador:** mediana de unos 1.400 ms por piso (tope de la prueba, 1.500). Con el validador de 1c y los recortes (`free_tiles()` sin lambda, el validador agrupando los puntos de pared por sala) quedó en unos 1.270 ms solo; dentro de `verify`, con la máquina ocupada, sube a unos 1.550, así que `office_test` pide 2.000 y el presupuesto de 1.500 queda para `office_metrics`, que corre solo.
4. Las secciones «Pending decisions» de `spec_f2_movement` (§15, 13 para el autor), `spec_f2_mind` (§14) y `spec_f3_integration` (§15, 11 para el autor).
5. **Dificultad de The Lurker:** los asomos por dificultad, `sated`, `forget`, las seis claves de sistema de `spec_f1_systems` 1.8 y los ajustes del director.
6. **Textos:** en el piso 2, al empezar, el objetivo en pantalla dijo «The Locust va a por ti…» (texto del piso 1; una captura del 23 de octubre, a los pocos segundos; después muestra el de oficinas). Además, las cuatro líneas de The Lurker en el menú de dificultad (`TRAITS`), y una revisión de los textos del piso 2 que entraron con 1a (nombres de sala, departamentos, hitos, encargos de planta) y de los artículos (`ARTICLES`).

## Cómo se trabaja sin flujos (aprendido en 1b)

- Leer la unidad: `PYTHONIOENCODING=utf-8 python -c "import json;p=json.load(open('.claude/specs/encargos_1b.json',encoding='utf-8'));print(p['unidades'][n]['encargo'])"`.
- Bloques de código largos: Write a un archivo del scratchpad y un script de Python que sustituya el stub (los heredocs con apóstrofos fallan).
- Sondas con `timeout 500` delante: un error de análisis deja a Godot parado sin salir. Si se cuelga, cerrar solo ese proceso de Godot (nunca `TheFour.exe`).
- En `office_generator.gd`, todo lo que se lee de `palette.` es Variant: nada de `:=` con él (ni con comparaciones como `x == palette.TIPO`).
- No tocar archivos de Godot mientras corre `verify.ps1` en segundo plano: la pasada los compila a medias.

## Cómo se trabaja con los flujos (aprendido el 22 de octubre)

- **Siempre por `scriptPath`** (`E:/Projects/The Four/.claude/workflows/frente.js` o `encargos.js`). Por nombre se ejecuta la copia cargada al abrir la sesión.
- `frente` admite `archivo` (lee del JSON de `encargos` el contexto, la aceptación, las pruebas y el texto de cada unidad; en `unidades` basta `{id, archivos}`) y `primero` (unidades que van antes y solas).
- Antes de un frente que no debe cambiar nada visible, el director saca la línea base sin ventana: la galería (`tools/editor/build_gallery.gd`, comparada normalizada con el sed de `evidence/gallery_twice.txt`) y `light_layers_scan` con 40 semillas (todo menos `slowest_ms`).
- Coste medido: unos `encargos`, de 1 a 2 puntos semanales; un frente, de 1 a 2.

## Especificaciones (en `.claude/specs/`)

| Archivo | Estado |
|---|---|
| `fase0_pasos.md` | Fase 0 hecha |
| `encargos_0b` a `encargos_1b.json` | Construidos |
| `spec_f1_generator.md` | Revisado; al día con 0d y 1a; falta anotar 1b (punto 3 de arriba) |
| `spec_f1_geometry.md` | Revisado; R2 y H8 al día con 0d |
| `spec_f1_systems.md` | Revisado; notas de 0e al final |
| `spec_f2_movement.md`, `spec_f2_mind.md` | Revisados por críticos, **no aprobados**; decisiones pendientes al final de cada uno |
| `spec_f3_integration.md` | Revisado, **no aprobado**; no se parte en unidades hasta reconciliar 2a y 2b |

## Assets del piso 2 (`source_assets/oficinas/`, fuera de git)

- `RESUMEN.md` y un `registro.json` por grupo: 98 se quedan, con su licencia auditada.
- **91 piden sesión** (44 modelos de Sketchfab, 47 sonidos de Freesound). Las descargas de Sketchfab por la extensión se cortan hacia los 10 MB. Hacen falta en 1d.

## Pendientes menores

- `evidence/` tiene líneas base, sondas y registros sin seguimiento: se pueden borrar (las sondas `1b_probe_U*.gd` sirven de ejemplo para 1c).
- `assets/props/comprobante.pdf` apareció sin seguimiento y no es de ningún paso: no se ha tocado.
- Los scripts nuevos (`objectives_test`, `palette_scan_test`, `room_light_test`, `hotel_palette`, los del piso 2) no tienen `.uid`: Godot los creará al abrir el editor.
- beads `four-7ly.2.1` y `docs/PLAN.md`: el piso en las grabaciones de bots, `presentation_rig`, el control de piso en la sala y `tools/godot.ps1 -Floor`.
