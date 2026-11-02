# Área 4d: la proporción de las salas

Estado: aprobada por el director el 2 de noviembre de 2026, tras dos críticos (`spec_proporcion_criticas.md`: sus cifras y líneas de código son la base de esta nota). Complementa `spec_rediseno.md`, que sigue mandando en lo demás. Va después del área 5 y antes de 4c.

## El problema

Las capturas de 4b (`evidence/rediseno/4b_final_sheet.png`, cada una junto a su referencia) enseñan salas enormes y vacías. Los muebles son correctos, pero quedan pequeños, lejos y sueltos por módulos de 8 a 12 m bajo un techo de 2,95 m. En las referencias las salas miden a ojo de 4 a 8 m por lado, los muebles van seguidos desde los rincones y ocupan del 20 al 35 % del suelo. Hoy ocupan del 2 al 9 %. Es lo que más nos separa de las referencias, y el autor pidió proporciones y composición.

## Decisiones

**D1. Orden: la arquitectura antes que lo menudo.** 4d va antes de 4c porque 4c cuelga lo suyo de las medidas finales. La objeción de que U8 de 4c cambia las esquinas se resuelve con D3: las esquinas reservan ya la huella real de su pieza de 4a, y U8 pondrá la pieza dentro de esa huella. Los encargos de 4c se levantan de nuevo después de 4d.

**D2. Primero la colocación, después las medidas.** Se arregla lo que hace que una sala pequeña no admita muebles, y se comprueba en verde con la lista actual antes de encoger nada.

**D3. Las esquinas no se comen la sala.**
- `keep_clear` reserva para cada pieza de esquina su huella real, no 2,3 x 1,4 m hasta el rincón. La medida sale de una tabla de la paleta, por clave de esquina, con la pieza de 4a que le toca.
- Los barridos de puerta van solo a las esquinas que tienen pieza, en los dos sitios (`office_layout.gd:161-165`, `office_validator.gd:1111`). `restore()` (`office_recipes.gd:240`) los respeta.
- La receta se coloca antes que las esquinas; una esquina que ya no quepa se pierde.

**D4. Tramos seguidos.** Modo nuevo `"run"` en `office_recipes.gd`: piezas distintas juntas, como un solo grupo, desde un rincón, sin `ITEM_GAP`. El validador ya exime a los grupos. `ALONG` llena desde el rincón en las entradas `"back"` y `"wall"`.

**D5. Lo principal, donde se ve.** Las piezas principales pasan de `"side"` a `"back"` o `"wall"`, porque con 55° y la puerta centrada las paredes laterales apenas entran en cuadro. `MIDDLE_DEPTHS` gana 1,1 a 1,7 y `MIDDLE_SIDES` llega a ±2,4 m; las piezas centrales van descentradas, como en las referencias.

**D6. El centro sigue libre.** No se abre el contrato de `position_of()` (radio 0,6 m y cápsula de cada puerta al centro, `map_validator.gd:245,316`). La mesa de juntas queda «casi central», descentrada unos 1,25 m, sin las sillas del lado cercano que invadan el centro o los barridos; las demás de ese lado se quedan, porque una mesa con sillas solo en un lado no se parece a la referencia.

**D7. Volumen.** Piezas nuevas en el sistema de 4a: `reception_counter_l` 3,6 x 2,2; `waiting_row_4` 3,2 x 0,8; `work_table` 2,4 x 1,8; `office_suite` 2,0 x 2,7 (aparador, sillón, mesa, dos sillas); `meeting_table_s`, `_m` y `_l` (3,6, 4,2 y 4,8 m de largo, huella con sillas, una silla en cada cabecera); `locker_bank` 2,7 x 0,5 (con candados, no se abre y no lo parece); `fan_unit` 1,5 x 1,2 (el tipo 22, distinta de la climatizadora real para que no engañe). Recetas: las de la tabla del crítico B, adaptadas a las bandas de D9. `most` alto y que falle lo que no quepa, en vez de mínimos que dependan del área.

**D8. Medidas, decididas con una sonda y una regla fijada aquí.** Candidatas, en este orden, todas con seis entradas (no cambia el número de sorteos de la rejilla) y con 7, 8 y 9 m porque las piden `lurker_bots_test`, `lurker_fairness_test` y `lurker_senses_test`:
1. `[6.0, 6.5, 7.0, 7.5, 8.0, 9.0]`
2. `[6.5, 7.0, 7.5, 8.0, 9.0, 10.0]`
3. `[7.0, 7.5, 8.0, 8.5, 9.0, 10.0]`

Se queda la primera que cumpla todo esto con D2 a D7 ya puestos: `office_metrics -- 200` con 1 piso de reserva o ninguno, y `-- 100 --survivors=1` y `=5` con 2 o menos, en todos los pases 0 rechazos y mediana de 2.000 ms o menos; `light_layers_scan -- 40 --floor=2` con 0 choques y 15 capas o menos; `lurker_shell_test`, `lurker_tiles_test`, `lurker_motion_test`, `lurker_senses_test`, `lurker_fairness_test` y `lurker_bots_test` en verde; al menos una placa libre en toda sala y salas de juntas con mesa en el 80 % de los pisos o más. Si falla, se pasa a la candidata siguiente, salvo que el revisor mande dentro de sus rondas un arreglo de los previstos en D10. El revisor del área anota las cifras de las candidatas probadas. Si ninguna cumple, sube al director.

**D9. Cada tipo en la celda que le toca.** Tabla `ROOM_BANDS` en la paleta (lado corto y lado largo, mínimo y máximo), aplicada al elegir el tipo por el patrón de `boardroom_fits` (`office_generator.gd:506-509,719`), en `place_musts` y en las salas especiales, y sin sorteos nuevos. Si ninguna celda encaja, se relaja la banda en vez de ir a un piso de reserva. Ojo con `suites()`, que intercambia tipos.

| Tipo | Corto | Largo |
|---|---|---|
| Recepción | ≥6,5 | ≥7 |
| Correo | ≥6 | ≥6,5 |
| Archivo | ≥6,5 | |
| Reprografía | ≥6 | |
| Despacho | | ≤7,5 |
| Dirección | | ≤8 |
| Secretaría | | ≤7,5 |
| Juntas | ≥6,5 | ≥8 |
| Descanso | ≥7 | ≥8 |
| Aseos | ≤6,5 | ≥7 |
| Seguridad | | ≤7 |
| Eléctrico | ≤6,5 | |
| Climatización | ≥7 | ≥8 |
| Vestíbulo del montacargas | ≥6 | ≤7 |

La ventanilla va en el hub, con ≤7,5 de lado largo si la colocación lo permite. Las naves conservan un mínimo de 12 x 16 m y módulos de 6,5 m o más a lo largo de la columna (`COLUMN_OFF` pide 6,3).

**D10. Lo que se ajusta con el cambio de medidas.**
- `boardroom_fits` y `make_nave`: lado largo ≥8, corto ≥6,5, con las mesas de D7, en lugar de `BOARDROOM_SIDE` 10 (también `office_test.gd:505,1116`, `office_metrics.gd:235`).
- `FIRST_WALK` y `LEAST_WALKS` a 90 m, y el validador, la prueba y las métricas leen la paleta (`office_validator.gd:173`, `office_test.gd:484`, `office_metrics.gd:210`). `DEPTHS` no se toca.
- `EXPOSED` a `[0, 20, 28]` y `EXPOSED_LONGEST` a 56.
- `verify.ps1` gana un trabajo de capas con `--floor=2`. Si sale rojo, alcance propio de oficinas por gancho, con el hotel igual: `LATE_REACH` 6 y lámpara mínima 8.
- Salidas sobre el conducto principal (`office_generator.gd:2014`, banda de 3,6 m): medir placas por celda. Se puede bajar la banda hasta 3,0 m si hace falta. `duct_bridge` y `SHORTCUT_MIN` no cambian sin medir: si los reintentos crecen más de un 50 % sobre la base, sube al director.
- `MAIN_LENGTH` y `STATION_*`: se revisan con las medidas y se escalan si la prueba lo pide.

**D11. Dos defectos que se ven en la hoja.**
- La pared de madera de dirección y secretaría sale como una cuadrícula de casetones (`evidence/rediseno/4b/secretaria.png`, `direccion.png`). La referencia lleva paneles verticales lisos de nogal: arreglar la escala o el material, igual en todo el edificio.
- La luz roja del techo de recepción (`evidence/rediseno/4b/recepcion_juego.png`): identificar qué es y que no tiña el techo. Un piloto pequeño no pinta nada alrededor.

**D12. Capturas que sirvan de prueba.** El cuarto eléctrico se captura con luz. Climatización se compara con el tipo 23, que tiene la climatizadora.

## Lo que no se hace

Salas por debajo de 6 m; mesa de largo continuo; tocar la puerta de 2,65 x 1,3 m o el techo de 2,95 m; recetas nuevas de archivo; perseguir el primer plano de las fotos; cambiar el hotel (`hotel_geometry.gd`, `map_generator.gd`, `map_validator.gd` y `room_layers.gd` solo por ganchos con el hotel igual byte a byte).

## Prueba de aceptación

Sin ventana, sobre 8 semillas, con la misma cámara que `office_rooms_capture`, en una prueba nueva que se queda en `verify`.

1. **Suelo ocupado por tipo**, contando muebles, esquinas con huella real, consola, cuadro, climatizadora, mesa de la ventanilla y taquillas. Mediana por tipo igual o superior al umbral, y ninguno por encima del 45 %. Umbrales, en %: recepción 16, ventanilla 20, correo 18, archivo fijo 20, archivo móvil 40 (sin tope), reprografía 22, despacho 20, dirección 22, secretaría 20, juntas 22, descanso 18, aseos 16, seguridad 20, eléctrico 16, climatización 15, vestíbulo 3.
2. **Pieza principal en cuadro:** proyectando su caja, ocupa el 30 % del ancho de imagen o más. Piezas: mostrador, mesa, cuadro, climatizadora, casilleros, taquillas, copiadora con mesa central y cocina con comedor.
3. **Suelo libre en cuadro:** 30 % o menos (35 % en recepción, aseos y climatización).
4. **Lo que ya existe sigue en verde**, `verify.ps1` incluido, con el hotel igual.
5. **Las capturas sala por sala junto a su referencia**, que juzga el director.
6. **La partida:** el paseo del cuadro al montacargas cabe en los 60 s de `lift_timer`; física en las semillas 7, 21 y 33 con `columns_test` y en 5 semillas de 1 a 40; medida en `lurker_shell_test` (semillas 1 a 10) de cuántas veces falla `cue_pose`, contra la base.

La línea base se mide antes de tocar nada: `office_metrics -- 200` y `light_layers_scan -- 40 --floor=2`.

## Riesgos

- The Lurker llega antes en un edificio menor, con sentidos y velocidades absolutos. No se corrige por adelantado: se mide con `lurker_fairness_test` y `lurker_bots_test`, y lo que no cuadre sube al director.
- Las semillas se mueven: las pruebas que fijan semillas pueden pedir otra. Cambiar de semilla vale solo si la comprobación sigue probando lo mismo.
- `office_test_generator` ya tarda 433 s. Si crece, se parte por semillas en esta misma área.
