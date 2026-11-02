# Críticas de la propuesta de proporción (2 de noviembre de 2026)

Informes de los dos críticos sobre el borrador de `spec_proporcion.md`. Son datos y código citado de ese día; las decisiones están en `spec_proporcion.md`, que manda.


## Crítico A

**Veredicto: la propuesta aguanta con cambios, no con `[6.5…10]` a secas.** No ejecuté Godot. Las cifras con «modelo» salen de portar a Python `clear_zones`, `lay` y `assign`, sobre la topología de `evidence/office_manifest_7.json` con tamaños re-sorteados (15 a 40 tiradas). Son orientativas.

## Lo que se rompe, por gravedad

1. **Las recetas dejan de caber y el suelo ocupado no sube.**
   - Modelo, piezas seguras: 97 % hoy, 73 % con la propuesta. Dirección queda en 41 % y recepción en torno al 50 %.
   - Eso pone en rojo `office_test.gd:410` (≥75 %) y `:415` (≥50 % por tipo).
   - Ocupación por muebles exentos: 3,6 % en 12×12, 6,7 % en 8×8 y 2,9 % en 6,5×6,5. Por debajo de 8 m baja, porque las piezas ya no entran.
   - Causas: los barridos a las cuatro esquinas (`office_layout.gd:161-165`, `office_validator.gd:1111`) y la zona de esquina de 2,3×1,4 hasta el rincón (`office_recipes.gd:88,202`).
   - Arreglo: barrer solo hacia las esquinas con pieza, en los dos sitios, y que `restore()` (`office_recipes.gd:240`) respete el barrido. Modelo sin barridos, cota alta: 91 % con la propuesta y 95 % con la lista que recomiendo.

2. **La sala de juntas desaparece.**
   - `BOARDROOM_SIDE` 10 (`office_palette.gd:373`; usos en `office_generator.gd:153,689,719`): las celdas válidas pasan del 44 % al 2,8 %.
   - En rojo: `office_test.gd:1116` y `office_metrics.gd:235` (0 < 80 %).
   - `lay_table` (`office_generator.gd:24,1691`) pide 8,92 m por el lado largo y 5,02 por el corto.
   - Arreglo: `boardroom_fits` con largo ≥9 y corto ≥6,5, y lo mismo en `office_test.gd:505`.

3. **La pieza central es imposible sin cambiar un contrato.**
   - El punto medio debe quedar libre: `map_validator.gd:245,316`, `office_layout.gd:158,168-177`. `position_of(` aparece 99 veces en `game/`.
   - Arreglo: casi central, no central. `TABLE_OFFSET` 1,25 pide 7,02 m por el lado largo.
   - `MIDDLE_DEPTHS` (`office_recipes.gd:24`) gana 1,2 y 1,6.
   - La mesa de largo variable exige tocar `office_validator.gd:851`, que fija el tamaño.

4. **`DEPTHS` no es lo que hay que revisar.** Son cuotas del paseo e invariantes de escala. Lo absoluto es `FIRST_WALK` y `LEAST_WALKS` (110 m, `office_palette.gd:158,160`), con literales en `office_validator.gd:173`, `office_test.gd:484` y `office_metrics.gd:210`.
   - El mínimo de `office_metrics.json` (1000 pisos) es 110,0: el suelo está en el límite. Semilla 7, modelo: paseo de 179 a 145 m (×0,81).
   - Sin arreglo suben los `refuge_*` y los pisos de reserva (`office_test.gd:399`).
   - Arreglo: 90 m con la lista recomendada (su modelo da ×0,85, así que este suelo queda algo más laxo que hoy), y que el validador lea la paleta.

5. **Capas de luz.** `room_layers.gd:35,77,135` usa alcances absolutos.
   - Hoy se usan 12 de 16 (`evidence/0u1_layers_office.out`). Modelo: 16 de 16 con la propuesta, sin choques en esas tiradas.
   - `verify.ps1:103` no pasa `--floor=2`, así que nadie lo vería: solo saltaría el aviso de `hotel_geometry.gd:2151` y fugas en Muy bajo.
   - Arreglo: añadir el trabajo con `--floor=2`. Si sale rojo, alcance propio de oficinas (`LATE_REACH` 6, lámpara mínima 8: modelo 10-11 capas). Eso toca la luz de 3b.

6. **Salidas sobre el conducto principal.** `office_generator.gd:2014` deja libre una banda de 3,6 m.
   - A 6,5 m: 1 a 8 placas, y ninguna en el 10 % de los codos. A 7 m: 4 o más.
   - Sin placa cae a `wall_exit` y, si falla, a `duct_exit`, que pierde el intento.

7. **`duct_bridge` puede empeorar** (`office_generator.gd:1774`). Ya cuesta 798 reintentos por 1000 pisos. Los carriles no encogen, así que `longitud/paseo` baja un poco contra `SHORTCUT_MIN` 0,55. No cambiarlo sin medir: es diseño.

8. **`EXPOSED` en metros** (`office_palette.gd:190,193`): los mismos metros tapian un 25 % más de salas. Pasar a `[0, 20, 28]` y 56.

## The Lurker: no se rompe nada duro
- **«Cualquier placa»:** `free_tiles` nunca sale vacío, con 25 o más placas a 6,5 m (modelo en sala cuadrada y cerrada). `duct_graph.gd:76` sigue valiendo.
- **Sin dependencia de sala:** `TAKE_REACH` (`lurker_warning.gd:16`) es independiente. `clear_point` no cambia, porque la lámpara sigue en el centro.
- **Cambia la frecuencia:** `cue_pose` (`lurker_shell.gd:1049`) falla más con la espalda cerca de una pared. Da menos capturas, no capturas injustas.
- **Equilibrio:**
  - Sus velocidades y sentidos son absolutos (`CHASE_EARSHOT` 9 m), y con el edificio un 15 % menor llega antes.
  - «Por tu espalda 3-5 m» saldrá más a menudo tras una pared (`lurker.gd:885`).
  - Hay que medirlo. No lo he demostrado.

## Pruebas y coste a ojo
| Prueba | Efecto | Coste |
|---|---|---|
| `office_test.gd:484,505,1116`, metrics 210 | los puntos 2 y 4 | 15 min |
| `office_test.gd:410,415` | se arreglan con el punto 1 | 1-2 h, código y validador |
| `lurker_senses_test.gd:97` (≥9 m), `lurker_fairness_test.gd:362` (≥8 m), `lurker_bots_test.gd:52` (≥7 m) | aguantan si la lista conserva esos tamaños | 0 |
| `office_bots_test` | más fácil, porque el tope no cambia | 0 |

Las semillas se mueven, pero con 6 entradas el número de sorteos de la rejilla no cambia. La red (`office_coop`) no la leí a fondo: la cubre `verify`.

## La palanca
- **`MODULE_SIZES` es la correcta**, pero con la cola baja acotada.
- **La paleta no puede dar medidas por tipo.** Se sortean por columna y fila (`map_generator.gd:289`) antes de que existan los tipos (`office_generator.gd:446`).
- **Sí cabe «tipo según medida»** sin tocar el hotel: el patrón de `boardroom_fits` en `office_generator.gd:506-509,719`, sin sorteos nuevos. Ojo con `suites()`, que intercambia tipos.
- **Por planta** cabría sobrescribir `axis()` con `laying`. No hace falta de entrada.

## Valores mínimos
| Lado | Por qué |
|---|---|
| 6,3 | Columna de nave frente al paso (`COLUMN_OFF`) |
| 6,5 | `most` de enchufes en vestíbulo con ascensor llega a 0 (`office_generator.gd:1368`) |
| **7,0** | Salidas sobre el principal; mobiliario de despacho con el punto 1 arreglado |
| 7,5 | El mismo mobiliario sin ese arreglo (a 7×7, 0 %; a 7,5, 76 %) |

**Recomiendo:** `MODULE_SIZES := [7.0, 7.5, 8.0, 8.5, 9.0, 10.0]` (media −17 %, suelo −31 %), con el punto 1. Sin él, `[7.5, 8, 8.5, 9, 9.5, 10]`.

## Cómo cambiar la nota
1. Primero los barridos, después las medidas.
2. Quitar `DEPTHS` y poner `FIRST_WALK`, `LEAST_WALKS` y `EXPOSED`.
3. Juntas por largo y corto.
4. «Casi central» en vez de «central».
5. Fijar la aceptación con cifras reales: encoger solo lleva la ocupación del 5 % al 6-7 %. Lo que llena son las recetas más ricas, y las limitan las zonas libres.

## Sonda para después (sin interfaz, sin dos Godot a la vez)
1. **Línea base antes de tocar nada:** `office_metrics.json` es del 23 de octubre y `office_metrics_100.json` del 25, los dos anteriores al rediseño. Volver a correr `office_metrics -- 200`.
2. **Con el cambio:**
   - `office_metrics -- 200`, y `-- 100 --survivors=1` y `=5`.
   - Pisos de reserva <0,5 %, 0 rechazos, p50 ≤2000 ms.
   - Reintentos por motivo contra la base: `refuge_*`, `duct_bridge`, `main_duct`, `duct_exit`.
3. `light_layers_scan -- 40 --floor=2`: 0 choques y capas ≤15.
4. **Medidas nuevas en `floor_measures`:**
   - piezas seguras y ocupación por tipo y lado mínimo;
   - placas por sala (mínimo ≥1) y en celdas del principal;
   - salas de juntas con mesa;
   - paseo del cuadro al montacargas contra los 60 s de `lift_timer`;
   - media de salas a menos de 9 m;
   - en `lurker_shell_test` (semillas 1 a 10), cuota de `cue_pose`.
5. **Física:** semillas 7, 21 y 33 con `columns_test`, más las 5 semillas de 1 a 40 con módulos más pequeños.

Scripts del modelo:
- `C:\Users\Poblete\AppData\Local\Temp\claude\E--Projects-The-Four\30ec7d89-bfbc-4c56-b84b-8bc1cdb0c707\scratchpad\recipes.py`
- `C:\Users\Poblete\AppData\Local\Temp\claude\E--Projects-The-Four\30ec7d89-bfbc-4c56-b84b-8bc1cdb0c707\scratchpad\recipes2.py`
- `C:\Users\Poblete\AppData\Local\Temp\claude\E--Projects-The-Four\30ec7d89-bfbc-4c56-b84b-8bc1cdb0c707\scratchpad\rescale.py`
- `C:\Users\Poblete\AppData\Local\Temp\claude\E--Projects-The-Four\30ec7d89-bfbc-4c56-b84b-8bc1cdb0c707\scratchpad\layers2.py`
- `C:\Users\Poblete\AppData\Local\Temp\claude\E--Projects-The-Four\30ec7d89-bfbc-4c56-b84b-8bc1cdb0c707\scratchpad\tiles.py`


## Crítico B

# Crítica de la propuesta 4d (proporción de las salas)

**Veredicto:** encoger es necesario, pero con esa lista no basta y por sí solo rompe recetas. Sin cambiar cómo se coloca, más volumen tampoco cabe.

Las medidas de referencia son a ojo, con un margen de ±20 %. Las fracciones están calculadas a mano con las huellas de `FURNITURE`, que incluyen las sillas. No he ejecutado nada.

## Lo que tumba o corrige la propuesta

1. **La lista propuesta deja salas demasiado grandes.** Su mínimo es 6,5 × 6,5 (42 m²), y el despacho de referencia ronda los 18 m². Con receta más volumen se llega al 17 %, y la referencia está en el 30 %.
2. **Las esquinas se comen las salas pequeñas.**
   - `keep_clear` reserva a cada pieza de esquina unos 4,5 m² (2,3 × 1,4 centrado a 1,3 m, hasta el rincón), sea cual sea su tamaño real.
   - Cuatro esquinas son el 46 % del suelo a 6,5 m y el 78 % a 5 m.
   - El tramo libre entre dos esquinas es de S − 4,9 m. No caben `office_desk` por debajo de 6,7 m, `reception_counter` por debajo de 7,3 m ni `kitchen` por debajo de 7,9 m.
   - Por eso 6,5 ya rompe la receta. Primero tiene que colocarse la receta, y después las esquinas con su huella real.
3. **`ITEM_GAP` de 0,9 m impide los tramos seguidos.** En las referencias casi todo va seguido: archivador con aparador, casilleros en L, copiadora con papelera y lector. Hoy `row` solo junta piezas iguales. Hace falta un modo nuevo, `"run"`: varias piezas distintas en un mismo grupo, desde un rincón. El validador ya exime a los grupos.
4. **Se coloca donde no se ve.**
   - Con 55° y la puerta centrada, una pared lateral solo entra en cuadro a partir de 0,96 × el ancho de la sala. En una sala de 6 × 6 se ven sus últimos 0,24 m.
   - Hay 24 entradas `"side"`, y `"side"` prueba primero las paredes que no son la característica.
   - `ALONG` va del centro hacia fuera, y las referencias llenan desde los rincones.
   - Las piezas principales deben pasar a `"back"` o `"wall"`, con `ALONG` desde el rincón.
5. **Una pieza justo en el centro no cabe.**
   - `clear_zones` mantiene libre un radio de 0,6 m y una cápsula de cada puerta al centro, y hay 99 usos de `position_of()` en `game/` (buena parte, el centro como destino).
   - Correo, reprografía y descanso no lo necesitan: sus piezas van descentradas en la referencia. Basta añadir `MIDDLE_DEPTHS` de 1,1 a 1,7 y `MIDDLE_SIDES` hasta ±2,4.
   - Juntas sí lo necesitaría. Sin abrir ese contrato, la mesa queda 1,2 m descentrada y sin la silla central del lado cercano. **Esto lo decide el director.**
6. **`DEPTHS` no es el fondo de las salas.** Es la cuota de recorrido hasta el refugio: no se toca. Lo que hay que escalar es `FIRST_WALK`/`LEAST_WALKS`, de 110 a unos 80 m. También hay que revisar `MAIN_LENGTH` y `STATION_*`.
7. **`BOARDROOM_SIDE` de 10 deja casi sin sitio a juntas.** Con la lista propuesta, solo 1 de cada 36 celdas valdría (hoy, 16 de 36). Hay que cambiarlo en los dos sitios que lo leen (`make_nave` y `boardroom_fits`).
8. **Las naves no siguen grandes por sumar módulos.** 2 × 2 de 5 m da 10 × 10, con 3 m de pasillo. Hace falta un mínimo de 12 × 16.
9. **Dos capturas no sirven de prueba.**
   - El tipo 22 (climatización) no tiene climatizadora: esa está en el 23.
   - El cuarto eléctrico sale negro.
10. **La mesa de juntas necesita otra medida.** Su huella deja fuera las sillas y `furniture_ok` exige la medida exacta, así que no puede escalar de forma continua: hacen falta tres tipos de mesa.

## Tabla por sala

- **Ref:** ancho × fondo, m² y fracción de suelo.
- **Hoy:** m² máximos de la receta (entre paréntesis, % en una celda de 10 × 10).
- **Banda:** lados mínimo y máximo de la celda.
- **Objetivo:** fracción de suelo que da la receta propuesta en esa banda.

| Sala | Ref | Hoy | Banda | Receta propuesta | Objetivo |
|---|---|---|---|---|---|
| Recepción | 7,5×6,5, 48, 22 % | 6,8 (7 %) | ≥6, ≥7 | Nuevo `reception_counter_l` 3,6×2,2 en `"wall"`; nuevo `waiting_row_4` 3,2×0,8 con butacas; 2 `filing` en `"run"` tras el mostrador; 2 `plant_floor`; `bin_floor` | 23 % |
| Ventanilla | 5×4, 20, 30 % | 1,5 + mesa del correo | ≥5, ≤6,5 | `filing` fila 3 en `"back"`; `work_table` en `"run"` contra el fondo; `wood_shelving` 1..1 | 26 % |
| Correo | 7,5×6,5, 49, 28 % | 6,6 (7 %) | ≥6, ≥6,5 | `pigeonholes` fila 3 en `"back"` y fila 2 en `"run"` en L; `pigeon_counter` en `"middle"`; `mail_cart` fila 3 cerca de la puerta; `printer_cart`; `filing` fila 2; `sorting_table` | 22 % |
| Archivo | 7×18 o más, nave, 50 % | filas propias | lado ≥6,5 | Sin cambio de receta. Banda porque `ROW_TRAMO` no cabe bien en 5 m (sin comprobar) | ≥40 % |
| Reprografía | 6,5×6, 39, 32 % | 7,7 (8 %) | ≥5,5, ≥6 | `copier` fila 2; `reader_table` fila 2 en `"back"` y otra en `"side"`; `card_index` en `"run"`; `wood_shelving`; `printer_cart`; `work_table` nuevo 2,4×1,8 en `"middle"` | 30 % |
| Despacho | 4,5×4, 18, 30 % | 5,2 (5 %) | ≥5, ≤6,5 | Nuevo `office_suite` 2,0×2,7 (aparador, sillón, mesa, dos sillas) en `"back"`; `filing` fila 2 en `"run"`; quitar la esquina `desk` | 25 % |
| Dirección | 7×6, 42, 35 % | 6,7 (7 %) | ≥6, ≤8 | `exec_desk` en `"back"`; `bookcase` 2..2 a sus lados; `sideboard` 1..1; el rincón de 4c | 26 % |
| Secretaría | 6×5, 30, 30 % | 6,8 (7 %) | ≥5, ≤7 | Mínimos a 1: `printer_cart`, `waiting_row`. `filing` fila 3 en `"run"`; mesa en la pared con acceso a dirección si cabe | 25 % |
| Juntas | 5,5×8, 44, 38 % | 6,1 sin sillas (6 %) | ≥6,5, ≥8 | `meeting_table_s`/`_m`/`_l` (3,6/4,2/4,8 de largo, huella con sillas, sillas según largo, una en cada cabecera); `sideboard`; `whiteboard` en `"back"` | 28 % |
| Descanso | 8,5×7,5, 64, 28 % | 8,3 (9 %) | ≥7, ≥8 | `dining_set` 3..4; `kitchen`; `vending` en `"wall"`; `filing` con `work_desk` al fondo | 23 % |
| Aseos | 4,6×9, 40, 25 % | 4,3 (4 %) | ≤5,5, ≥7 | `cubicles` en `"back"`; nuevo `locker_bank` 2,7×0,5 con candados, que no se abre y no miente, 1..2; `bench_slat` fila 2 en `"middle"` (hay que dar `row` a `lay_middle`) | 24 % |
| Seguridad | 4,2×3,8, 16, 30 % | 0,65 + consola | ≤6 | `filing` fila 3 en `"run"` junto a la consola | 21 % (consola sin medir) |
| Eléctrico | 5,8×3,7, 22, 24 % | 2,1 (2 %) | ≤6, ≥6 | `work_desk` cerca de la puerta. Banda para que quepa el cuadro entero. Hay que capturarlo con luz | 20 % (cuadro sin medir) |
| Climatización | 8×7, 56, 22 % | 2,1 (2 %) | ≥7, ≥8 | En el tipo 22: `fan_unit` nueva 1,5×1,2, distinta de la real para no engañar, y `work_table`. La captura se compara con el tipo 23 | 15 % |
| Vestíbulo del montacargas | 6×5, 30, 7 % | 0,8 (1 %) | ≥5,5, ≤6,5 | `filing` fila 2 en `"closed"`; maceta | 4 % |

## Valores recomendados

```text
MODULE_SIZES = [5.0, 5.5, 6.0, 6.5, 7.0, 8.0, 9.0]
```

Una lista global, con bandas por tipo. Media de 6,7 m (hoy 10 m), o sea 0,45 del área por celda; la lista propuesta da 0,61.

- **Por qué global:** los módulos salen de ejes de cuadrícula, así que no puede haber medidas por tipo.
- **Las bandas no necesitan piso de reserva.** Se aplican en la elección de tipo (`weights.erase` si no encaja, como ya hace `boardroom_fits`), en `place_musts` y en la colocación de salas especiales. Si no hay celda que encaje, se relaja la banda.
- **Celdas que encajan:** juntas 24 %, descanso 16 %, aseos 24 %, despacho 33 %.
- **5 m es el suelo:** por debajo, las esquinas ya no caben. Las celdas de 5 m, con 2 puertas como mucho.
- **`BOARDROOM_SIDE`** pasa a ser lado corto ≥6,5 y largo ≥8.

**¿Basta con encoger? No.** El despacho pasa del 5 % al 21 % con solo encoger (receta entera en 5,5 × 5), pero el correo se queda en el 13 % y juntas en el 12 %. Sin volumen, las salas seguirán pareciendo vacías. Hacen falta las dos cosas, más los puntos 2, 3 y 4.

## Prueba de aceptación

Sin ventana, sobre 8 semillas, con la misma cámara que `office_rooms_capture`.

1. **Fracción de suelo por tipo.**
   - Cuenta muebles, esquinas con huella real, consola, cuadro, climatizadora, mesa de la ventanilla y taquillas.
   - Mediana por tipo ≥ umbral, y ningún tipo por encima del 45 %.
   - Umbrales: recepción 16, ventanilla 20, correo 18, archivo 40, reprografía 22, despacho 20, dirección 22, secretaría 20, juntas 22, descanso 18, aseos 16, seguridad 20, eléctrico 16, climatización 15, vestíbulo 3.
2. **Pieza principal en cuadro.**
   - Proyectando su caja, ocupa ≥30 % del ancho de imagen. En las referencias va del 35 al 60 %. Hoy, el despacho no pasa del 15 %.
   - Piezas: mostrador, mesa, cuadro, climatizadora, casilleros, taquillas, copiadora con mesa central y cocina con comedor.
3. **Suelo libre en cuadro ≤30 %** (≤35 % en recepción, aseos y climatización), proyectando el suelo menos las cajas de los muebles.
   - En las referencias va del 10 al 30 %. Hoy, a ojo, del 35 al 40 %.
4. **Lo que ya existe sigue en verde,** y la hoja de capturas junto a su referencia la juzga el director.

## Lo que no compensa

- **Mínimos y máximos que dependan del área:** con bandas, el área ya es casi fija. Basta poner `most` alto y dejar que falle lo que no quepa.
- **Mesa de longitud continua:** tres medidas bastan.
- **Abrir el contrato del centro para las cuatro salas:** como mucho, para juntas, y solo si el director acepta el riesgo.
- **Celdas por debajo de 5 m para clavar los 16 a 20 m²** de seguridad y ventanilla.
- **Tocar la puerta de 2,65 × 1,3 m,** aunque en las referencias ronda los 2,1 × 1 m: la comparten el hotel y The Lurker (`lurker_shell.OPEN`). Tampoco el techo: 2,95 m coincide con las referencias.
- **Perseguir el primer plano de las fotos** (sofá, sillas pegadas a cámara): el ojo está a 1,5 m y en ellas parece estar hacia 1,2 m. Por eso se mide proyección, no parecido.
- **Recetas nuevas de archivo:** lo que falla ahí es el encuadre y la banda.
- **Orden:** 4d debe ir después de 4c, porque U8 cambia las esquinas que aquí se reservan, y los umbrales se miden con ellas puestas.
