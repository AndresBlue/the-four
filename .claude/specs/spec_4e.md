# Área 4e: las recetas llenas (10 de noviembre)

Viene de `spec_4c.md` («Tras la redacción»): 4c no añadió nada con huella en planta, así que `office_proportion_test` sigue en 42/55. Esta área llena las recetas con piezas de las referencias hasta que la prueba pase, y la devuelve a `verify`. Diseño de fondo: `spec_rediseno.md` (secciones 5 y 6) y `spec_proporcion.md`. Contrato de 4d que no cambia: lo que barre `validate_physics` lo reserva la colocación.

## Dónde estamos (sonda `evidence/4e_probe_gap.gd`, semillas de la prueba)

| Tipo | Suelo hoy (mediana) | Pide | Sala mediana | Falta |
|---|---|---|---|---|
| ventanilla | 15,9 | 20 | 42,6 m² | 1,7 m² |
| correo | 17,4 | 18 | 68,3 m² | 0,4 m² |
| archivo | 13,6 | 20 | 63,9 m² | 4,1 m² |
| archivo_movil | 30,1 | 40 | 45,7 m² | 4,5 m² |
| despacho | 17,5 | 20 | 49,4 m² | 1,2 m² |
| dirección | 16,8 | 22 | 42,6 m² | 2,2 m² |
| secretaría | 17,4 | 20 | 42,1 m² | 1,1 m² |
| juntas | 18,4 | 22 | 68,3 m² | 2,5 m² |
| seguridad | 19,7 | 20 | 39,2 m² | 0,1 m² |
| eléctrico | 11,1 | 16 | 45,0 m² | 2,2 m² |

Además:
- **La pieza principal en cuadro** queda bajo 30 en secretaría (29,8) y en aseos (21,2).
- **Las mesas para los papeles:** alguna planta tiene una sola mesa para los papeles (la prueba pide dos). `document_placement` solo deja papeles en las esquinas `desk` y `table` (`SURFACES`), y casi todas ceden ante los muebles de la receta: la esquina `desk` sale en el 19 % de las secretarías y en el 20 % de las direcciones.
- **Lo que no falla:** el suelo libre en cuadro, las bandas, los tramos y la silla cercana. No puede empezar a fallar.

## Decisiones

1. **Las cifras se suben con muebles de las referencias, nunca bajando umbrales** ni cambiando qué cuenta la prueba como suelo o como pieza principal. Cada tipo que falla tiene que quedar con su mediana al menos **2 puntos por encima** de su banda, para que una semilla no lo tumbe. El tope de 45 (100 en `archivo_movil`) sigue igual.
2. **Lo añadido entra como `spare` o con `least` 0** salvo donde se diga otra cosa. Si una pieza no cabe, la sala se queda sin ella, pero el piso no cae al de reserva. Si con `spare` la mediana no llega, se sube a `side` o a `least` 1 solo en ese tipo, midiendo cuántos pisos de reserva salen en las semillas 1 a 40 (hoy, ninguno).
3. **Qué entra en cada tipo** (todo existe ya en `FURNITURE` y `build_item()`, salvo lo marcado como nuevo):
   - **Ventanilla:** la mesa del empleado detrás del cristal, `work_desk` como `side`, con su máquina de escribir y su papelera (como en la referencia).
   - **Correo:** `mail_cart` con `most` 2 y `sorting_table` con `least` 1 donde quepa. Le basta con 0,4 m².
   - **Archivo:** dos palancas, por este orden:
     - las filas llegan a la pared en las salas de una unidad: `wall_gap` 0, como las estanterías de la referencia, y el pasillo perimetral se queda solo en los archivos de varias salas;
     - una mesa de consulta (`work_desk`) y un carro (`cart_boxes`) en la banda de la puerta (`end_min`/`door_depth`), que es lo que se ve al entrar.

     Las fichas dicen si `furnish_furniture` puede poner muebles en un archivo, cuyas filas salen de `furnish_archives`, y con qué zonas.
   - **Archivo móvil:** las filas compactas llegan de pared a pared (`wall_gap` 0 siempre). Si no basta, se acorta `end_min` en el lado sin puerta.
   - **Despacho:** `wood_shelving` como `side` y `sideboard` como `spare`. Es el aparador y la estantería baja de la referencia.
   - **Dirección (nuevo): el rincón de estar** de la referencia como mueble de receta, `lounge`: el sofá, el sillón de dirección, la mesa baja de nogal y la lámpara de pie. Son los modelos de 4c que hoy pone la esquina `armchair`, que solo sale en el 10 % de las salas.
     - Huella: la de `CORNER_SIZES.armchair` (2,3 x 1,4).
     - Colocación: `side`.
     - Sustituye a esa esquina (`CORNERS_REPLACED`: `armchair` → `lounge`).
     - Se dibuja con el mismo código que hoy dibuja la esquina, movido y no copiado.
   - **Secretaría:** `secretary_desk` pasa a ser la mesa en L de la referencia: la mesa y el ala de la máquina de escribir. La huella crece de 1,9 a unos 2,5 de ancho, lo que sube a la vez el suelo y la pieza en cuadro. El ala va del lado contrario a la puerta.
   - **Juntas:** `sideboard` con `least` 2 donde quepa (el aparador largo de la referencia), `plant_floor` como `spare` y `wood_shelving` con `most` 2.
   - **Seguridad:** `wood_shelving` con `least` 2. Le basta con 0,1 m².
   - **Eléctrico:** `shelving` con `least` 2 y `cart_boxes` con `least` 2 (el almacén de repuestos de la referencia: estanterías de cajas). Con ellas, `filing` como `spare`.
   - **Aseos, la pieza principal:** dos `locker_bank` seguidos en la pared que se encuadra, como la fila larga de taquillas de la referencia. El segundo entra como `spare` (o `run` sobre el primero), así que en una sala estrecha queda uno. Hay que medir cuántos aseos se quedan sin cabinas (la sonda de 4d, `evidence/4d_aseos_probe.gd`). La cifra no puede pasar de la de hoy, que se mide primero.
4. **Las mesas para los papeles:** dos por planta, sin tocar `document_placement.gd`, que es del hotel también. Lo primero es averiguar qué planta tiene una sola y por qué. Después, que una esquina `desk` o `table` que ya está en una receta deje de ceder ante un mueble de la receta en un tipo que esté en todas las plantas, reservándola antes de colocar la receta. Las fichas dicen cuál. Si no se puede sin tocar `document_placement`, se sube al director con la cifra.
5. **Lo menudo que dejó 4c:**
   - la mesa de juntas lleva encima papeles, la jarra (`jug`) y un cenicero (`TOPS` de `office_clutter.gd`, para las tres `meeting_table_*`);
   - `paper_clear()` de `office_dressing_test` mide también los lados abiertos y la recta entre accesos, como `clear_of_route()`.
6. **Lo que no se hace en 4e:**
   - las revistas de las mesitas de espera;
   - las manchas de agua;
   - el expediente a medio sellar (OFICINAS.md §8).

   Se anotan en `docs/PLAN.md` como pendientes del piso 2. El diseño no se cambia.
7. **Ninguna unidad toca `verify.ps1`.** Al cerrar, el director devuelve `office_proportion_test` a `verify`.

## Prueba de aceptación del área

- `office_proportion_test` 55/55, cada tipo que fallaba con 2 puntos de margen, y en `verify`.
- `verify.ps1` entero en verde, con 40 de 40 pisos pasando la física y ningún piso de reserva en las semillas 1 a 40.
- Aseos sin cabinas: no más que hoy.
- `manifest_golden_test` y `creature_contract_test` en verde (el hotel no cambia).
- Capturas con ventana de dirección, secretaría, archivo, juntas y aseos (`office_rooms_capture`), que enseñen el rincón de estar, la mesa en L, las filas a la pared y la fila de taquillas.

## Preguntas para las fichas

1. ¿Cómo pone una receta sus piezas (`office_recipes.gd`: `lay`, `lay_run`, `lay_center`, `restore`) y qué pasa cuando no cabe una pieza con `least` 1? ¿Cae el piso o se salta la pieza?
2. ¿Puede un archivo (tipo 6 o 13) tener `ROOM_FURNITURE`? ¿Qué zonas despejadas dejan sus filas, su espina y sus pasillos, y cómo los barre `validate_physics`?
3. `ARCHIVE_LAYOUT.wall_gap` y su uso en `lay_archive()`: ¿qué cambia en los pasillos y en `passage_path()` si vale 0 en las salas de una unidad?
4. ¿Qué planta se queda con una sola mesa para los papeles en cada semilla de la prueba, y qué esquinas `desk` y `table` tenía su receta antes de ceder?
5. `secretary_desk` (`office_props.build_item()`, `pieces/desks.gd`): cómo se dibuja, de dónde sale su huella y qué la lee (`office_clutter.TOPS`, la silla, `MAIN_KINDS`).
6. La esquina `armchair` (`office_props.build()`): su código, sus modelos (`MODELS.put` del sofá y del sillón, `MODELS.lamp` de la lámpara de pie) y quién más lee `"armchair"`.
7. `locker_bank`: su pieza (`pieces/room_equipment.gd`), sus reservas (`hides`, `LOCKER`) y la sonda de aseos de 4d.
8. `office_clutter.TOPS` y el marco de `meeting_table_*` (la altura del tablero, el largo).

## Tras los críticos (10 de noviembre): manda sobre las decisiones 1 a 6

Dos críticos Opus revisaron la nota contra el código. Esta sección manda: donde contradiga lo de arriba, vale esto.

**A. La cifra a la que se apunta es la banda más 2.** La columna «Falta» de la tabla medía la distancia hasta la banda. Lo que falta de verdad, sobre la sala mediana, es:

| Tipo | Falta |
|---|---|
| ventanilla | 2,6 m² |
| correo | 1,8 m² |
| archivo | 5,4 m² |
| archivo móvil | 5,4 m² |
| despacho | 2,2 m² |
| dirección | 3,1 m² |
| secretaría | 1,9 m² |
| juntas | 3,8 m² |
| seguridad | 0,9 m² |
| eléctrico | 3,1 m² |

La sonda pasa a medir contra banda + 2.

**B. Cómo se sube:**
- Cada pasada de `lay()` es un grupo propio y tiene que guardar `ITEM_GAP` (0,9) con los demás (`office_recipes.gd:62-64, 353`). Por eso las segundas pasadas sueltas ya no caben hoy, y subir `least` o `most` apenas mueve la mediana.
- La palanca es `row`, varias piezas en un grupo, o `run`, unidas al tramo anterior sin `ITEM_GAP`, con recuentos fijos (`least` igual a `most`).
- No se añade ninguna entrada `middle` con `least` 1 o más.

**C. El criterio de seguridad no son los pisos de reserva.** `least` no hace caer el piso. El freno es `office_test`: pide las piezas seguras (las que tienen `least` 1 o más y no son `spare`) en 3 de cada 4 salas, y en la mitad de las de cada tipo. Lo que la sonda mida que entra en menos del 75 % de las salas de su tipo va como `spare`. Además, se miden siempre:
- el tiempo de `generate()` en las semillas 1 a 40, antes y después: como mucho un 10 % más;
- los márgenes de los tipos que hoy pasan (descanso, reprografía, recepción y montacargas), porque todas las recetas comparten el flujo `recipes`;
- los tramos unidos;
- la silla cercana.

**D. Escalera por tipo.** Se mide tras cada peldaño y se para en el primero que deja la mediana en banda + 2 sin romper C. Si se acaba la escalera, el tipo sube al director con su cifra.
- **Ventanilla:**
  1. `work_desk` como `side`; la máquina de escribir la pone `build_item()` solo en WINDOW. La exclusión de `office_clutter.dress()` en la ventanilla se queda, porque es paso de la ficha.
  2. `filing` como `run` con `most` 2.
  3. `bin_floor` como `spare`.
- **Correo:**
  1. El segundo `mail_cart` como `middle` y `spare`, con `mail_cart` en `ANY_WAY` (suelto, como en la referencia).
  2. `filing` con `row` 2.
- **Archivo** (sin muebles: `keep_clear` y `fits()` no ven las filas):
  1. `wall_gap` 0 en todas las unidades de una sala. El sorteo se hace igual y su resultado no se usa, para no mover el flujo `archives`.
  2. En los archivos de salón, `wall_gap` 0 en un lado, con el pasillo perimetral en el otro.

  Antes de nada, la sonda separa las celdas de salón de las unidades de una sala. Si con los dos peldaños no llega, sube al director con la cifra.
- **Archivo móvil:** `wall_gap` 0 y `end_min` 0 en el extremo sin puerta. Si un móvil tiene puerta en una pared larga, conserva 0,9 en ese lado (sus filas no se cortan ante las puertas). La sonda cuenta cuántos hay, y `archives_ok` lo comprueba. Se mide con salas de 7 y de 7,5 de lado corto.
- **Despacho:**
  1. `wood_shelving` con `row` 2 como `side`.
  2. Las dos sillas de visita, `waiting_row`, como `spare`.

  Sin segundo aparador: `office_suite` ya dibuja el suyo.
- **Dirección:** el rincón de estar `lounge`:
  - huella 2,3 x 1,4 con el fondo en -0,7, y altura 1,6, la de la lámpara (`CORNER_HEIGHT.armchair`), para que `office_walls` no le cuelgue nada encima;
  - su dibujo pasa a una función estática que llaman `build()` (la esquina `armchair`, que `restore()` puede devolver) y `build_item()`;
  - sustituye a la esquina `armchair` y se intenta primero en su rincón;
  - si no llega, `bookcase` como `run` con `most` 4.

  Hay que medir cuántas salas reciben el rincón: dirección tiene cristal, y `usable()` descarta esas paredes.
- **Secretaría:** `secretary_desk` ya es una L (`desk_l_walnut`, con el ala a la derecha).
  1. El ala se alarga, siempre a la derecha (sin espejo, para que `TOPS`, la lámpara y la silla no cambien de lado), hasta que la pieza en cuadro pase de 32. La huella crece igual.
  2. Si no llega, un segundo tramo de `filing` como `run`.

  Si la silla queda dentro del ángulo, `secretary_desk` entra en `CROWDED`.
- **Juntas:**
  1. `sideboard` con `row` 2 como `side` (3,6 m).
  2. `wood_shelving` con `row` 2.
- **Seguridad:**
  1. `filing` con `row` 5 (antes 3).
  2. `wood_shelving` con `row` 2.
- **Eléctrico:**
  1. `shelving` con `row` 2.
  2. `cart_boxes` como `run`.
  3. `work_table` como `middle` y `spare`.
- **Aseos:** la primera taquilla como `run` unida a las cabinas, en la misma pared encuadrada (0,12 + 2,7 + 2,7 caben en 5,8). La segunda, como `spare`. Se miden la pieza en cuadro, la cuota de `bench_slat` y la cuota de aseos con todas sus piezas seguras.

**E. Las mesas para los papeles.**
- Primero se mide qué planta se queda con una sola mesa, en cada semilla, contando solo las salas pasada la distancia mínima.
- Después se reserva, en cada planta, la esquina del tipo que es obligatorio en ella (MUSTS):
  - planta 0: descanso, con su `table`;
  - planta 1: correo, con su `table`;
  - planta 2: secretaría o dirección, con su `desk`.
- Se mide antes y después del ala y del rincón de estar.
- Si así no llega, la otra salida es que `document_placement` cuente también las mesas de los muebles del piso 2. Para el hotel no cambia nada, porque sus salas no tienen `furniture`, y la prueba las contaría porque los papeles sí irían allí. Esa decisión es del director, con la cifra delante.

**F. Fuera de 4e:**
- **La mesa de juntas:** ya lleva papeles, jarra y cenicero (`MEETING_TOP`, ff016bf). Solo se comprueba en la captura.
- **Las revistas, las manchas de agua y el expediente:** como en la decisión 6.

`paper_clear()` sigue dentro.

**G. Orden.** Primero la sonda nueva y las medidas de E, porque deciden qué esquinas se reservan. Después el rincón de estar y el ala, que son código de dibujo. Por último, las escaleras de las recetas, tipo a tipo y en serie, porque todas tocan `office_palette.gd` y comparten el flujo `recipes`.
