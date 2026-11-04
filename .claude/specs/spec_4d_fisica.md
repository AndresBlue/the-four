# Área 4d, tramo final: la física de aseos y juntas

Sigue a `spec_proporcion.md` (manda en todo lo que esta nota no cambia) y al apartado «Dónde se paró» de `.claude/relevo.md`.

## El problema

La sonda U15 terminó en la tercera candidata de `MODULE_SIZES`, `[7.0, 7.5, 8.0, 8.5, 9.0, 10.0]`, que es la que está hoy en `game/floors/palettes/office_palette.gd`. Esa candidata cumple la regla de D8, pero la regla no miraba la física. Con ella, `validate_physics` rechaza 36 de 40 pisos y se monta el piso de respaldo, la semilla 404 (`evidence/4d_revD2_phys_probe.gd` y su registro `evidence/4d_revD2_phys.log`). `office_test_physics` sale en rojo. Con la lista anterior, `[8.0, 9.0, 10.0, 10.0, 11.0, 12.0]`, pasaba.

En 29 de los 36 pisos solo hay dos clases de error:

- **Aseos (tipo 4) con lado corto de 7 a 7,5 m:** `hide_approach` 46 y `hide_entry` 21. El barrido hasta la taquilla se corta en 0,91 a 0,98 de su largo, y la entrada en 0,06. Las taquillas van en `(±(ancho/2 - 0,8), ±1,8)`. Todas estas salas llevan la esquina `basin`.
- **Juntas (tipo 5):** `boardroom` 13. El paso del lado lejano de la mesa `meeting_table_l` (4,8 x 1,85, en `y = ±1,55`) se corta en 0,94, por algo a unos 1,55 a 1,6 m de la pared lateral. Todas estas salas llevan la esquina `plant`.

El colisionador es el `Solid` de toda la sala, así que el registro no dice qué pieza bloquea. Las piezas de cada sala están en `evidence/4d_revD2_phys_rooms.stdout`.

**Pista sin comprobar:** el arreglo C7 de `relleno_4d_costuras.md` dejó `plant` y `basin`, que dibuja `prop_factory`, fuera de su reserva de esquina (`CORNER_SIZES`, `corner_rect()`, `restore()`) hasta 4c. Con salas de 8 m o más no alcanzaban los barridos, y con 7 m sí.

## Decisiones del director

1. **Se arregla la causa en la colocación**, en recetas, generador, reserva de esquina o pieza, no en el validador. Los barridos de `validate_physics` son el contrato del juego: la taquilla alcanzable y el paso del lado lejano de la mesa. No se relaja ninguno ni se exime ninguna sala. Si la causa es que una pieza dibujada es mayor que su reserva, lo correcto es que la reserva diga la verdad, para que la colocación y el validador de planta la vean.
2. **Solo se prueba la candidata 1**, `[6.0, 6.5, 7.0, 7.5, 8.0, 9.0]`, con la fila a de la tabla de U15 aplicada para `most_layers` (estaba en 16, con tope 15). Con esa lista los aseos caben en su banda y la proporción sale mejor (42/55). No se repiten C2 ni C3. Si C1 no cumple, al director con las cifras.
3. **La regla de U15 suma la física:** `evidence/4d_revD2_phys_probe.gd` en sus 40 semillas da 1 rechazo o ninguno, y `office_test_physics` sale en verde. Los fallos de `lurker_tiles_test` y `lurker_bots_test` de C1 parecían venir del piso de respaldo: tienen que salir en verde sin tocarlos. No se cambia `office_metrics`.
4. **El resto de la regla de U15 sigue igual:** respaldo, validador, placas, juntas, p50 en `-- 200` de 2.000 ms o menos (con una repetición si solo falla eso por debajo de 2.600), capas, y las seis pruebas de The Lurker en verde. La medida corre sola en la máquina.
5. **Se anota sin entrar en la regla:** `office_proportion_test`, `office_lies_test`, la silla cercana y las secretarías. El director decide con esas cifras qué umbrales de suelo esperan a 4c. No se baja ninguno.
6. **El hotel no cambia** (`manifest_golden_test`, `creature_contract_test`, y el diff vacío en `hotel_geometry`, `map_validator` y `room_layers` salvo la fila a, que no cambia el hotel). `map_generator.gd` solo con los ganchos `refuge_fits` y `attempts`.

## La causa y lo que decidió el director tras los encargos (`encargos_rd4d3.json`)

**La causa, comprobada con la aritmética del código.** El arreglo G2 de `relleno_4d_costuras.md` (unidad C7 de `encargos_rd4d2.json`) cambió en `CORNER_SIZES` las filas de `plant` y `basin` a la medida de las piezas de 4c. Pero quien las dibuja sigue siendo el `prop_factory` del hotel (`HOTEL_KINDS`), que mide 0,55 x 0,55 la planta y 1,1 x 0,75 el lavabo. La reserva no era la pieza, y `restore()` no podía quitarla de los barridos.

**Lo que decidió:**
- **F1 corre sola.** F2 se lanza aparte, cuando F1 esté aceptada.
- **La sonda de C3 se repite**, como diagnóstico para demostrar la causa.
- **Lo que basta para seguir:** las semillas 3, 21, 100 y 103 quedan limpias, y como mucho otra semilla de 40 conserva alguno de esos errores.
- **Efecto visible aceptado:** el aseo pequeño sin lavabo y la junta sin planta esperan a 4c, que trae piezas más pequeñas.
- **Pendiente para 4c:** cuando U8 saque `plant` y `basin` de `HOTEL_KINDS`, tiene que volver a mover sus filas de `CORNER_SIZES`, con `plant` a `[0.55, 0.55, -0.7]` y `basin` a la medida de su `BASIN_Z`. La comprobación nueva de `office_pieces_test` deja de vigilarlas en ese momento.
- **Fallo sin causa conocida:** el SCRIPT ERROR «Invalid assignment of property or key 'thinking' … on a base object of type 'Nil'» salió en `office_lies_test` y en la sonda de caras con C1. Si se repite en F2, sube al director antes de U16.

## Segunda causa: el paso por la puerta en salas pequeñas (tras F2)

**Lo medido.** F1 y F2 quedaron aceptadas. Con C1 y la fila a, el árbol queda así, y así se queda.
- **La sonda de física:** rechaza 3 de 40 pisos, siempre por `passage_a_b`. Son la semilla 19 (`passage_28_29`), la 104 (`passage_302_303`) y la 121 (`passage_316_327`), y además la 7 (`passage_244_245`), que la sonda no cuenta.
- **El piso de respaldo 404 tampoco pasa la física con C1:** da `passage_249_250`, `leaf_arc_249_250` y `passage_319_332`. Si la semilla pedida y su respaldo fallan los dos, la partida no arranca. De ahí sale el FAIL «Ella en el piso» de `lurker_tiles_test`, que monta la semilla 7.
- **`office_test_physics`** da 2/3, con `built [404, 21, 33, 3, 12, 404, 28, 38]`.
- **`lurker_senses_test`** dio una vez 36/37, FAIL «Acechar tiene palabra propia: stalk». Antes daba 37/37 y no se ha repetido.

**El barrido.** `passage_path` de `map_validator.gd:312` y `office_validator.gd:1130` lleva la cápsula a 0,94 m de altura. Va en línea recta del centro de la sala a un metro antes de la puerta, la cruza, sigue un metro más allá y llega al centro de la otra.

**Las salas.** El volcado está en `evidence/4d_fis_passage_rooms.stdout`, y lo saca la sonda `evidence/4d_fis_passage_rooms.gd`. Ojo: allí la semilla 404 se volcó con `generate(404, 1)`, y la sala 332 no tiene puerta a la 319. El piso de respaldo real sale de `candidate(404)` en `hotel_main.gd:845-851`, así que ese volcado no le corresponde. En todos los casos las salas son pequeñas, de 6 a 7,5 m, y la puerta de ese par está desplazada ±1,5 m. En una pared de 6 m eso es cerca de la esquina, donde están las taquillas (`hides` en ±1,8 o ±2,2), las estanterías o la pieza de despacho.

**Decisión del director, la misma que en F1:** lo que barre la física lo tiene que reservar la colocación. Se arregla en el generador, en las zonas libres de cada puerta o en dónde se pone la puerta, el mueble o la taquilla, y no en el validador. Hay que encontrar pieza a pieza qué corta cada barrido y por qué el validador de planta no lo ve. El piso de respaldo tiene que pasar la física con cualquier lista de `MODULE_SIZES`.

**Aceptación de este tramo:**
- con C1 y la fila a, la sonda de física rechaza 1 piso de 40 como mucho, y la semilla 7 queda limpia;
- `office_test_physics` sale en verde, sin 404 en `built`;
- el piso de respaldo pasa la física;
- `lurker_tiles_test` y `lurker_senses_test` salen en verde, repetidos una vez;
- se cumple la regla de U15 entera, con el hotel igual.

**La causa** (`encargos_rd4d4.json`, calculada con el código y comprobada por P1). Es la taquilla de esconderse (`hiding_place.gd`, 1,25 x 0,78) puesta en la pared de al lado, junto a la esquina de una puerta desplazada 1,5 m. Su frente queda a 0,31 m de la línea de la puerta, y la cápsula tiene 0,32 de radio. `place_hides` y el validador de planta solo apartan la taquilla de las puertas de su misma pared.

**Lo que decidió el director sobre los encargos:**
- **P1 corre sola.** El piso de respaldo sigue en la aceptación: es la red de seguridad. Si P1 dice que su corte no es una taquilla, se escribe P2b con lo que P1 muestre, y P3 no corre hasta entonces.
- **Se aprueba el gancho `hide_free()`** en `map_generator.gd`, idéntico en la base. Se descarta copiar `place_hides`.
- **La reserva `LOCKER`** (1,3 x 0,7) se queda corta frente a la taquilla real, que llega a 1,1 m de la pared. No se cambia aquí, porque movería muebles y las bandas de The Lurker. Pendiente para 4c.
- **Se quitan de P3 las cuatro corridas de la orden 12,** que no entran en la regla. Las cubre la `verify` de integración.

## Tras P2: dos taquillas en una esquina y los aseos pequeños (`encargos_rd4d5.json`)

P1 y P2 quedaron aceptadas. Las semillas 19, 104 y 121 y el piso de respaldo salen limpios, `golden` da 513/513 y `office_test_validator` 39/39. Quedan dos cosas.

**1. La semilla 7 da `hide_entry_336`.** En unos aseos de 8 x 6,5, la regla nueva deja sin sitio la pared opuesta a la primera taquilla. La segunda va entonces a la pared de al lado, en la misma esquina, y el costado de una corta la entrada de la otra. `place_hides`, en `map_generator.gd:1902-1909`, solo aparta las taquillas de su misma pared (`HIDE_APART`), aunque su comentario promete «well apart». Lo midió el revisor con `evidence/4d_sonda/c1g_rev_hide_probe.gd`.
- **Decisión del director:** se arregla con un gancho de la oficina, `hide_apart()`, en el filtro tras cada toma. En la base, el gancho deja la regla de hoy, solo misma pared, y el hotel sigue igual byte a byte. La oficina añade que dos taquillas de paredes vecinas no compartan esquina: ni sus cuerpos ni sus entradas se cortan. Lo comprueba `golden` 513/513.

**2. `office_test_generator` da FAIL en «Cada tipo con receta y 4 salas o más tiene todas sus piezas seguras en la mitad o más»:** `aseos 415 de 1578`. Ya fallaba con C1 antes de P2 (412). Con C1, los aseos caen en su banda (lado corto de 6,5 o menos), y su receta no cabe entera en esas salas.
- **Decisión del director:** hay que averiguar qué pieza segura de la receta de aseos no cabe y por qué. Se arregla en la receta, para que una sala de aseos de banda lleve sus piezas seguras. No se toca el umbral de la prueba, ni la banda, ni `MODULE_SIZES`. La receta de aseos se compara con su referencia, `docs/referencias/`: cabinas, lavabos, taquillas y banco.

**Lo que decidió el director sobre estos encargos:**
- **Q2 elige receta por regla fija,** en este orden: V1, V4, V5, V2, V3. Si sale NINGUNA o CALIBRACION, el área para con las cifras.
- **Lo que no se decide antes de ver datos:** si en las oficinas se prefiere ±1,8 a 0 en la pared vecina. Se decide con las cifras de ASEOS_MISS si hace falta.
- **Admisión de las secretarías:** se mantiene acotada, como la escribió el revisor.
- **Se anota y no entra en la regla:** las taquillas que faltan (`lacking`) y los lavabos que se pierden.
- **El validador de planta no aprende `lockers_meet`:** ya lo vigila `validate_physics`.
- **Q1 y Q2 van en el mismo lanzamiento,** y Q3 en otro.

**Tras Q1 y Q2,** aceptadas las dos:
- **Las piezas seguras de los aseos:** la prueba pasa, con 1134 de 1578 aseos (71,9 %).
- **Las cabinas** siguen faltando en 108 aseos, y lo que las quita son las reservas de las taquillas. No se arregla: la prueba pasa. Queda anotado para 4c, con la reserva `LOCKER`.
- **Los lavabos de esquina** bajan de 207 a 163 aseos, y se da por bueno: 4c los cambia por su pieza.
- **Escondites:** ninguna sala se queda con menos de los pedidos (`lacking=0`).
- **Las secretarías** siguen en PASS.

## Prueba de aceptación

Con C1 y la fila a:

- la sonda de física da 1 rechazo o ninguno en 40 pisos;
- `office_test_physics` sale en verde, con `built` sin 404;
- se cumple la regla de U15 entera;
- en las salas de aseos y juntas que antes se rechazaban, los barridos pasan sin quitar la taquilla ni la mesa.

Después siguen U16 (capturas) y U17 (documentos y `verify`) de `encargos_rd4d.json`.

## Al cerrar (4 de noviembre)

`office_proportion_test` sale de `verify` hasta 4e (ver `spec_4c.md`): da 42/55, con el suelo ocupado bajo su banda en 10 tipos y una mesa para los papeles por planta. Sus umbrales no se bajan. `lurker_route_probe` y su variante `--unseen` pasan a la semilla 8, porque la 7 no tiene nave con C1 (39/39 y 14/14).
