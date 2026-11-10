# Área 4e, tramo B: lo que no llegó

Nota de diseño del director, 10 de noviembre de 2026. Sigue a `spec_4e.md`, que manda en todo lo que esta nota no cambie. El tramo A (17 unidades, `encargos_rd4e.json`) dejó `office_proportion_test` en 49/55, con verify en verde y la sonda (`evidence/4e_probe.gd`, `4e_probe_gen.gd`) con los criterios C de la a a la l en OK.

## Lo que falta

| Prueba | Hoy | Pide | Salas en la sonda |
|---|---|---|---|
| Suelo de ventanilla | 18,5 | 20 | 8 |
| Suelo de correo | 17,4 | 18 | 222 |
| Suelo de despacho | 18,7 | 20 | 224 |
| Suelo de dirección | 22,0 (por debajo, sin redondear) | 22 | 244 |
| Suelo de juntas | 19,0 | 22 | 131 |
| Pieza en cuadro de secretaría | 29,8 | 30 | 74 |

Seguridad (20,1 frente a 20, 8 salas) pasa hoy por poco y puede caer con cualquier cambio del flujo `recipes`.

## Decisiones

1. **La meta es la banda más 0,5**, no la banda más 2 del tramo A. El tramo A demostró que la banda + 2 no se alcanza con muebles razonables en la mayoría de los tipos, y la prueba solo pide la banda. Los umbrales de `office_proportion_test` no se tocan.
2. **Los tipos de 8 salas no se dan por llegados con un sorteo afortunado.** Ventanilla y seguridad (y eléctrico y climatización, que hoy pasan) se miden además con la sonda en las semillas 1 a 40: su mediana ahí tiene que quedar en la banda o más. La prueba sigue con sus 8 semillas.
3. **El tiempo** (criterio e): el ruido entre corridas es de unos 60 ms. Si una sonda pasa el tope, se repite dos veces y vale la mediana de las tres.
4. **Aseos:** la taquilla `run` unida a las cabinas se queda aunque su cuota sea 74,6 %. La regla del 75 % de la sonda es una guía; el freno es `office_test` (piezas seguras), que está en verde.
5. **Secretaría:** se ensancha la L, siempre con el ala a la derecha. `secretary_desk` pasa de 1,9 a 2,1 de ancho y el tablero de `desk_l_walnut` de 1,8 a 2,0; si no llega a 30,5, a 2,3 y 2,2. Lo que se apoya en la mesa (`TOPS`, la lámpara y la silla) se mueve con ella y no cambia de lado.
6. **Escaleras por tipo**, con las reglas B y C de `spec_4e.md` (palanca `row` o `run` con recuentos fijos; ninguna entrada `middle` nueva con `least` 1 o más; lo que entra en menos del 75 % de las salas va como `spare`). Se mide tras cada peldaño y se para en el primero que llega. Los peldaños los ordena quien redacta, con las fichas delante, entre estos candidatos:
   - **Dirección:** una planta (`plant_floor`, `spare`); el aparador (`sideboard`) de `spare` a `run` tras las librerías. Nada que quite el rincón de estar (U09 lo quitaba con cuatro librerías).
   - **Despacho:** un perchero o una planta como `spare`; un fichero (`card_index`) como `run`; una butaca de visita en la esquina libre. El segundo aparador sigue fuera (`office_suite` ya tiene el suyo) y `waiting_row` también.
   - **Correo:** el archivador (`filing`) de `spare` a `run` tras los casilleros; la mesa de clasificar (`sorting_table`) como `spare` en vez de `middle` con `least` 0. Ningún `mail_cart` suelto que pueda ser la primera pieza de la pared característica (`first_piece()`; por eso se deshizo U06).
   - **Ventanilla:** un fichero (`card_index`) como `run`; una estantería (`shelving`) como `side`.
   - **Juntas:** que la mesa sea la mayor de `TABLE_KINDS` que quepa (si hoy no lo es); la estantería (`wood_shelving`) de `spare` a `side`; un carro con el televisor o un rotafolios, si hay pieza dibujada. Juntas es el que más lejos está (3 puntos). Si con su escalera no llega, sube con la cifra y la parte de la sala que queda libre, y el director decide.
   - **Seguridad:** el peldaño 1 del tramo A (`filing` `run` 1, 1, 5), medido con la decisión 3.
7. **Las piezas nuevas** solo si ya tienen dibujo en `office_props.build_item()` o en `pieces/`. Una pieza sin dibujo no entra en este tramo.

## Tras los críticos (10 de noviembre): manda sobre las decisiones 2 a 7

Dos críticos Opus revisaron la nota contra el código y las sondas del tramo A. Donde esta sección contradiga lo de arriba, vale esta. La decisión 1 (banda + 0,5) y la 5 (ensanchar la L) se quedan, y la 5 con el apartado G.

**A. Cómo se ordenan los peldaños.**
- `side` y `spare` colocan igual (`walls_for()`, `office_recipes.gd:335-338`); solo cambia si la pieza cuenta como segura (`office_test.gd:809`). Ningún peldaño consiste en pasar de `spare` a `side`.
- `run` se une a `chain`, el último tramo de pared colocado, y no a la pieza que se nombra. Tras un `center` (el escritorio de dirección), `chain` no cambia y un `run` no se une a nada (`office_recipes.gd:367`). Cada encargo dice la posición literal de la entrada en la lista y a qué tramo se une.
- Por orden de preferencia:
  1. un tramo `run` de una clase que ya es segura y ya entra en todas las salas, al final de la receta;
  2. el recuento fijo de una entrada que ya lo tiene fijo (`least` igual a `most` antes y después);
  3. una clase nueva, solo como `spare`.
- **Los sorteos no se mueven.** Ninguna entrada que hoy sortea (`least` distinto de `most`) cambia sus recuentos. La primera unidad comprueba con una prueba de tres líneas si `randi_range(a, a)` consume el generador. Si no lo consume, una entrada nueva con recuento fijo no mueve nada, y está permitida.

**B. Peldaño 0, solo de clasificación.** `mail_cart` (correo, en el 63 % de sus salas) y `waiting_row` (secretaría, 65 %) pasan de `side` a `spare`. La colocación es idéntica; deja de contarlos como piezas seguras de un tipo al que no llegan en 3 de cada 4 salas, y eso da margen a la regla de `office_test` que pide todas las piezas seguras en la mitad de las salas de cada tipo. Hoy ventanilla está en 34 de 64, secretaría en 402 de 624 y correo en 959 de 1617. `work_table` de la ventanilla se queda `run`.

**C. Escaleras** (sustituyen a la decisión 6). Orden de las unidades: secretaría, dirección, despacho, correo, juntas y, las últimas, seguridad y ventanilla, porque cualquier cambio de otro tipo puede rehacer su piso.
- **Secretaría:** la L de la decisión 5, con G.
- **Dirección:**
  1. `["plant_floor", "spare", 1, 1, 1]`, detrás de `lounge` en la lista;
  2. la esquina `desk` de dirección en `PAPER_TOPS_KEPT`, medida con el rincón de estar dentro. U02_1 la subió de 16,8 a 19,3, y se deshizo por el correo.

  El aparador no se toca. Ninguna entrada va delante de `lounge`.
- **Despacho:**
  1. `["card_index", "run", 1, 1, 1]` al final de la receta;
  2. `bookcase` de `run` 2, 2 a 3, 3;
  3. una esquina dibujada (`plant` o `cabinet`) en el hueco vacío de `RECIPES[3]`, que es otro flujo (`sockets`) y entra en el recuento de la prueba.
- **Correo:**
  1. el peldaño 0;
  2. `MAIL: "table"` en `PAPER_TOPS_KEPT`, como pedía `spec_4e` E y no se hizo;
  3. `filing` como `run` en su sitio de la lista, unido al carro de la impresora, como mide la sonda.

  `sorting_table` no se toca, porque sortea.
- **Juntas:**
  1. `wood_shelving` de la fila 1 a la 2, como `spare` (U10_2 midió +1,1);
  2. un segundo `["wood_shelving", "run", 1, 1, 2]` justo detrás;
  3. `["plant_floor", "spare", 2, 2, 1]`;
  4. `["waiting_row", "spare", 1, 1, 1]`, las sillas contra la pared.

  Si con eso no llega a 22, sube con la cifra y la parte de suelo libre. No hay televisor ni rotafolios dibujado, y no se dibuja en este tramo.
- **Seguridad:** `filing` `run` 1, 1, 5 (U11_1 dio 22,0), medido con el criterio de tiempo de D.
- **Ventanilla:** `["filing", "run", 1, 1, 3]` al final de la receta (filing ya es segura y entra en todas). Después de cada peldaño de cualquier tipo, la sonda mide de nuevo la ventanilla con las 8 semillas de la prueba.

**D. La sonda para el tramo B** (sustituye a las decisiones 2 y 3).
- Una tercera referencia, `evidence/4e_probe_base_b.txt`, con las líneas de `4e_probe_U16_final.log`. Los criterios i y k comparan con ella; e y h siguen con la base vieja. `MARGIN := 0.5` en `4e_probe.gd`.
- **`P4E_ATTEMPTS`:** el intento con que sale cada piso (`manifest.attempt`), sumado en las semillas 1 a 40 y uno a uno en las 8 de la prueba. Si sube en alguna de las 8, el peldaño no cuenta como llegado: el cambio ha rehecho un piso, y la cifra es de otro sorteo.
- **El tiempo** se compara con el paso anterior medido en la misma sesión. Como mucho un 10 % sobre la mediana de la base B, medida al empezar. La regla de la mediana de tres sobra.
- **Los cuatro tipos de una sala por planta** (ventanilla, seguridad, eléctrico y climatización) miden también el suelo en las semillas 1 a 40, en `sixty_four()`. El criterio es que el percentil 30 quede en la banda o más. Si eléctrico o climatización no llegan, suben al director con la cifra: no tienen escalera.
- **Las cuotas por entrada**, con su índice en la receta, para que la taquilla `run` de aseos se lea aparte de la `spare`.
- **Lo que no puede empeorar frente a U16:**
  - `P4E_SURE_TYPE` de cada tipo; ventanilla, correo y secretaría paran además si bajan del 55 %;
  - aseos `sin_banco`;
  - `P4E_TOPS` de cada planta, frente a prev;
  - `P4E_LOUNGE` (223 o más) y la cuota de `lounge` en dirección (89 % o más).

**E. Aseos** (sustituye a la decisión 4). La taquilla `run` se queda. Lo que bajó del 75 % es el banco (`bench_slat`, del 80 al 72 %), y se queda también: `office_test` está en verde. Ni el banco ni la cuota de aseos con todas sus piezas pueden empeorar en el tramo B.

**F. Verify.** `'office/office_proportion_test'` se añade al array `$tests` de la línea 45 de `tools/verify.ps1` y se borra el comentario de la línea 46. En la verify de cierre se anota la mediana de tiempo de `office_test_generator` (2750 ms con la máquina ocupada, `office_test.gd:435`).

**G. La L ancha.**
- Primer escalón, 2,1 y 2,0, como la decisión 5. El ala va de `w/2 - 0,6` a `w/2` (`desks.gd:73`).
- A los `TOPS` que caen sobre el ala (el teléfono y las carpetas, `office_clutter.gd:45`) se les suma `(w - 1,8) / 2` en x, como ya se hace en z (`office_clutter.gd:100`).
- Un assert nuevo en `office_dressing_test`: cada `TOPS` de `secretary_desk`, con su desplazamiento, cae dentro de uno de los dos colliders de `make_desk_l`.
- El segundo escalón (2,3 y 2,2) solo con ese assert en verde.

## Aceptación

- `office_proportion_test` 55/55 y de vuelta en `tools/verify.ps1` (F); verify entero en verde.
- La sonda, con C de la a a la l en OK y con D: `P4E_TOPS` sin bajar de prev, los intentos sin subir y el percentil 30 de los cuatro tipos de una sala.
- Capturas con ventana de los tipos tocados en `evidence/rediseno/4e_b/`, con el director mirándolas: la L de la secretaría con su ala a la derecha y lo de encima sin flotar, el rincón de estar de dirección todavía en su sala, y nada atravesando paredes.
- `docs/DEVELOPMENT.md` con la cifra nueva de la prueba y los muebles nuevos.
