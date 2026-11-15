# La planta de oficinas, como el plano de una oficina real

Nota de diseño del director, 14 de noviembre de 2026. **Propuesta, sin construir.** Los hechos del código en los que se apoya están en `.claude/specs/fichas/planta.md`.

## 1. Lo que pide el autor

«Cambiar completamente la generación de habitaciones, actualmente la siento como una matriz de habitaciones cuadradas interconectadas por pasillos, muy similar al hotel. Me gustaría hacer un overhaul completo y detallado de una planta que parezca similar al plano de una oficina real. Que los 3 pisos sean coherentes con cómo lo diseñamos y cómo debiera ser en la realidad si realmente fuera operativa y tuviera trabajadores. Igual debe ser no "fácil" de recorrer, pero más directo que el hotel, que de manera premeditada era complejo como laberinto.»

## 2. Por qué hoy se siente como una matriz

- La planta sale del motor de rejilla del hotel sin cambios (`map_generator.lay_grid()`, `corridors()`, `open_doors()`, `make_halls()`); las oficinas solo sustituyen el reparto de tipos y el amueblado.
- Todas las salas son un módulo de 6 a 9 m de lado, casi cuadrado: un despacho mide lo mismo que una sala de descanso.
- Cada planta tiene de 81 a 99 salas y su propia rejilla, sorteada de nuevo: nada de una planta coincide con la de arriba salvo el hueco del montacargas, y `alike()` castiga que los pasillos se parezcan.
- Los pasillos salen de planes pensados para perderse (peine, brazos, madriguera, bloques con tramos quitados) y muchas salas dan a otras salas por sorteo.
- Los tipos se reparten por pesos, sin sitio: un aseo o un almacén puede caer en cualquier celda.

## 3. Qué tiene una planta de oficinas real (lo que se va a imitar)

1. **Un edificio.** Las tres plantas comparten contorno, ejes de estructura y núcleo. Lo que cambia entre plantas son los tabiques.
2. **Crujías.** La planta se mide en un módulo (3,6 m). Un despacho ocupa una crujía; una sala grande, varias. Las salas son rectángulos de proporciones distintas según para qué sirven, no cuadrados iguales.
3. **Bandas.** De la fachada hacia dentro: banda de despachos (5,4 m de fondo), pasillo, zona honda (7,2 a 9 m, una o dos filas) para lo que no necesita fachada: naves de trabajo, archivo, salas de juntas, núcleo. Detrás, la trastienda.
4. **Una circulación principal legible.** Un pasillo en anillo alrededor de la zona honda, o una espina con pasillo doble. Se entiende en un minuto; lo difícil está fuera de él.
5. **Un núcleo apilado.** Montacargas, aseos, cuarto de limpieza, montantes eléctricos y de aire, uno encima de otro en las tres plantas.
6. **Trastienda.** Una galería de servicio estrecha (2,4 m) sin falso techo, con puertas de acero, que une almacén, depósito, cuarto eléctrico, climatización y el montacargas de carga. Se entra a ella por dos o tres puertas desde la parte noble.
7. **Departamentos por alas.** Cada departamento ocupa un tramo continuo de planta con su puerta cortafuegos, no un parche repartido.
8. **Vecindades con sentido.** Recepción junto al ascensor; la ventanilla de Personal, a la vista desde la espera; secretaría delante del despacho de dirección; sala de juntas junto a Dirección; reprografía y descanso junto al núcleo; el puesto de seguridad, controlando la llegada.

## 4. El edificio (una vez por partida)

- **Una rejilla para las tres plantas.** Se sortea una vez (ejes de columnas y de filas, con sus tamaños) y las tres plantas la usan tal cual. `open_planta()` recibe la misma rejilla; `pin()` deja de hacer falta porque el hueco del montacargas cae en la misma celda arriba y abajo.
- **Columnas (crujías).** Anchos de {3,6, 3,6, 3,6, 4,5, 5,4, 7,2} m, sorteados **por ala**: el edificio se parte en dos o tres alas a lo largo y cada ala tiene su ritmo (un ala de crujías de 3,6 para despachos; otra de 7,2 para naves y archivo). Dos líneas de pasillo transversales (3,0 a 3,6 m) cierran el anillo y separan las alas.
- **Filas (bandas),** de fachada a fondo:

  | Fila | Fondo | Qué es |
  |---|---|---|
  | Banda norte | 5,4 (4,8 a 6,0) | despachos y salas pequeñas |
  | Pasillo norte | 3,0 a 3,6 | circulación principal |
  | Zona honda | 7,2 a 9,0, una o dos filas | naves, archivo, juntas, núcleo |
  | Pasillo sur | 3,0 a 3,6 | circulación principal |
  | Banda sur | 5,4 (4,8 a 6,0) | despachos y salas pequeñas |
  | Galería de servicio | 2,4 | trastienda |
  | Banda de servicio | 4,5 a 6,0 | cuartos técnicos, almacén, montacargas de carga |

  La trastienda va en un solo lado (el fondo) y a veces también en un testero.
- **Contorno.** El de `pick_shape()` (rectángulo, L, U, con patio), elegido una vez y compartido.
- **Tamaño.** A área 1,0, del orden de 65 a 85 m de largo por 35 a 45 de fondo y no más de 150 celdas por planta (hoy, 100 módulos de 6 a 9 m y sus pasillos). Escala con `drawing` como hoy. La escala de juego que hay que conservar es la de **metros andados**, no la de salas.
- **El núcleo.** Un bloque de la zona honda, el mismo en las tres plantas: aseos, cuarto de limpieza (STORE), el montante (un cuarto técnico pequeño con puerta de acero) y, pegado a él, el hueco de un montacargas.

## 5. Los ascensores (lo fija el diseño del piso, `docs/OFICINAS.md` §3)

| Hueco | Sirve | Dónde va |
|---|---|---|
| Ascensor del hotel | llega a la planta 1 | en un testero, con la recepción delante |
| Montacargas A | planta 1 → planta 2 | en la banda de servicio, al fondo: «escondido y hondo» por arquitectura (hay que encontrar la trastienda) |
| Montacargas B | planta 2 → planta 3 | en el otro extremo del edificio, en el núcleo o en el testero opuesto |
| Pozo de ventilación | salida de la planta 3 | desde la sala de climatización, en la banda de servicio |

Se conservan las reglas de profundidad de hoy (`DEPTHS`, `LEAST_WALKS`, `WINDOW_DEPTH`, `ELECTRICAL_DEPTH`, `SECURITY_DEPTH`, `MAIN_LENGTH`), medidas sobre la planta nueva; si la arquitectura pide otra banda, se cambia la cifra y se dice.

## 6. La circulación de cada planta

Todas usan los pasillos del edificio; cada una los usa a su manera. **Un tramo de pasillo que una planta no usa se lo queda la sala de al lado** (se funde con ella: un despacho de dirección de 8,4 m de fondo, una sala de lectura), nunca queda como hueco vacío.

- **Planta 1, Personal (con luz).** El anillo entero. La zona honda son las naves de oficina abierta y cubículos, que se cruzan por su pasillo central: son los atajos. Despachos en las dos bandas. Recepción en el testero del ascensor; la ventanilla de Personal, en el primer tramo del anillo, con su espera. Descanso y reprografía junto al núcleo. El montacargas A, en la trastienda.
- **Planta 2, Registro y Archivo (emergencia).** Medio anillo y una espina: la zona honda es el archivo, salones largos de estanterías que se atraviesan de punta a punta; la banda de un lado es de consulta, correo y microfichas; la del otro pierde su pasillo y son depósitos hondos que dan unos a otros. El cuarto eléctrico, en la trastienda a media planta. El montacargas B, al otro extremo de por donde se llega.
- **Planta 3, Dirección (a oscuras).** Pocas salas y grandes: suites de despacho con secretaría delante, sala de juntas en la zona honda, el puesto de seguridad junto a la llegada (se pasa por delante de su cristalera). El anillo está cortado por el cierre de seguridad: tramos fundidos con las suites, de modo que para dar la vuelta hay que cruzar antesalas. La climatización, en la trastienda del fondo.

**Puertas.** Un despacho da al pasillo y a nada más. Las puertas entre salas dejan de sortearse: solo las que tienen motivo (secretaría con su despacho, juntas con dos puertas, naves al anillo por varios puntos, depósitos en fila, archivo por sus dos extremos, almacén con la galería). Cortafuegos donde un pasillo recto pasa de 45 m (`OPEN_RUN`) y en la frontera de cada departamento.

**«No fácil, pero más directo».** La circulación principal se entiende; lo que cuesta es: puertas iguales en tramos largos, la zona honda que corta la vista (mamparas, estanterías), los departamentos que se cierran con cortafuegos, la trastienda como segunda red con pocas entradas, y en la planta 3 el anillo roto. Se mide: el camino de la llegada a la salida no baja de `LEAST_WALKS`, y el número de vueltas (`rings`) se mantiene.

## 7. Las salas

- Una sala es un **rectángulo de celdas** de la rejilla (1 × 1 hasta n × 2), más las L que ya admiten las naves. Sigue representada como hoy (celdas con el mismo `hall` y sus costuras en `merged`).
- Tamaños por tipo (a ajustar con las recetas):

  | Tipo | Crujías × fondo |
  |---|---|
  | Despacho | 1 × banda (3,6 × 5,4) |
  | Despacho de jefe, secretaría | 1 o 2 × banda (5,4 a 7,2 × 5,4) |
  | Despacho de dirección | 2 × banda, o banda + pasillo fundido |
  | Reprografía, correo, almacén | 2 × banda |
  | Sala de descanso, sala de juntas | 2 o 3 crujías en la zona honda |
  | Aseos | 2 × 1 en el núcleo |
  | Nave abierta o de cubículos | 4 a 8 crujías × 1 o 2 filas hondas |
  | Archivo | 3 a 6 crujías × 1 fila honda, recto |
  | Cuartos técnicos | 1 o 2 × banda de servicio |

- **Zonas en vez de pesos sueltos.** El tipo de una celda sale de dónde está (banda de fachada, zona honda, núcleo, trastienda, ala y departamento) y después del programa de la planta (`MUSTS`, `PLANTA_MIX`, que pasan a aplicarse dentro de cada zona).
- El número de salas por planta deja de ser 81 a 99: sale del edificio (previsión, 45 a 75). `rooms_window()`, `NUMBERED_MOST` y la numeración se ajustan a eso.

## 8. Lo que no cambia

- **El manifiesto y su esquema**: `rooms` por celda con `x, z, px, pz, span_x, span_z, kind, hall`, `merged`, `doors`, `edges`, `gates`, `mail`, `tubes`, `power`, `air`, `ducts`, `archives`. Geometría, paredes, techo, ductos, rutas de ella, objetivos, plano y red leen lo mismo que hoy. Sube `OFFICE.VERSION`.
- **El piso 1.** `map_generator.gd` solo recibe ganchos cuyo valor por defecto deja al hotel byte a byte igual (`manifest_golden_test`).
- **Las reglas de juego** de cada planta (§3 de `docs/OFICINAS.md`): estaciones del tubo (8 a 14, separadas), cuadro y zonas de circuito, minuteros, puesto con una sola puerta de tarjeta, ducto principal de 25 a 45 m con dos codos, salas prohibidas para ella, techo libre por encima de 2,2 m, pasillos de archivo de 0,95 m.
- **El amueblado por recetas**, que se adapta a los tamaños nuevos (un despacho de 3,6 × 5,4 debe amueblarse entero) pero no cambia de sistema.
- **La planta de reserva** (`candidate(404, 0, true)`) sigue saliendo siempre.

## 9. Lo que cambia de sitio en el código (previsión, a confirmar por los encargos)

- `office_generator.gd`: rejilla propia (`lay_grid()` del edificio, una vez), `corridors()` propio con las tres circulaciones, absorción de tramos sin usar, formación de salas por zonas (sustituye a `make_halls()` y al reparto de `finish()`), reglas de puertas (sustituye el sorteo de `open_doors()`), núcleo y trastienda, colocación de ascensores por arquitectura. `alike()` deja de aplicarse.
- `office_palette.gd`: tamaños (`MODULE_SIZES` por alas y bandas), `ROOM_BANDS`, `DECKS`, ventana de salas, programa por zona.
- `office_validator.gd`: reglas nuevas (toda sala es rectángulo o L admitida, despachos con puerta a pasillo, núcleo apilado, trastienda conexa con dos entradas o más, rejilla compartida) y cifras de las viejas.
- `office_recipes.gd` y `office_layout.gd`: que las recetas quepan en las salas nuevas.
- `map_generator.gd`: ganchos (`lay_grid` por edificio, lanes vivas como sala).
- Pruebas: `office_test`, `office_proportion_test`, `tools/dev/office_metrics.gd`.

## 10. Prueba de aceptación

1. **El plano.** Una herramienta nueva dibuja la planta desde el manifiesto (PNG cenital: muros, puertas, tipos por color, rótulos de sala). Doce planos (cuatro semillas × tres plantas), antes y después, puestos junto a planos reales de oficinas de los 70 y 80. Pregunta del autor: «¿parece el plano de una oficina real en la que trabajaba gente?».
2. **El edificio.** En cada semilla, las tres plantas superpuestas comparten contorno, ejes y núcleo (se comprueba en el validador y se ve en el plano).
3. **Mil semillas** (`office_metrics.gd`): ninguna cae en la planta de reserva más que hoy; metros de la llegada a la salida por planta, dentro de las bandas; reparto de tamaños de sala (más de la mitad por debajo de 30 m², ninguna familia de salas con todas iguales).
4. **Dentro.** Capturas en vista de juego de un despacho de una crujía, una nave, un tramo del anillo, la galería de servicio y una suite de dirección: amuebladas y creíbles.
5. **Verde.** `tools/verify.ps1` completo y el banco en Alto sin subir más de 1 ms por fotograma en el recorrido.

## 11. Fases

1. **Herramienta del plano** y los doce planos de hoy (la línea base).
2. **El edificio**: rejilla compartida, bandas y alas, contorno, núcleo.
3. **Circulación y salas**: los tres trazados, absorción, salas por zonas, puertas.
4. **Hitos y ascensores** sobre la planta nueva; ductos, tubos, zonas de circuito.
5. **Amueblado**: recetas en los tamaños nuevos.
6. **Validador, mil semillas, capturas, banco.**

Cada fase termina con sus planos; ninguna se da por buena sin verlos.

## 12. Preguntas abiertas para los críticos

- ¿Aguanta el motor celdas de carril vivas que no son pasillo (la absorción)? Si no, alternativa: las tres plantas usan el anillo entero y la diferencia la ponen las puertas cerradas y los tabiques.
- Con crujías de 3,6 m, ¿cuántas celdas salen y qué cuesta por celda en geometría, luces y techo?
- ¿Caben las reglas de profundidad de hoy (ventanilla 0,15 a 0,45; eléctrico 0,4 a 0,7; salida de la planta 2 más allá de 0,8) en un edificio de 75 × 40 m con la trastienda al fondo?
- ¿Qué recetas no caben en 3,6 × 5,4 y qué piezas hacen falta?
- ¿Las rutas de ella por el techo y la red de ductos suponen módulos de 6 m o más en algún sitio?

## 13. Decisiones del director tras la crítica (mandan sobre todo lo anterior)

Las críticas completas, con sus pruebas en el código, están en `.claude/specs/fichas/criticas_planta.md`. Donde esta sección contradice a las anteriores, vale esta.

**Qué ordena la planta**
1. Es un sótano bajo un hotel: no hay fachada. Ordenan la planta el muro de contención del perímetro, la estructura que baja del hotel y los núcleos. Las bandas se llaman **perimetral** (contra el muro: despachos, depósitos, almacenes) y **central** (núcleos, naves, archivo, salas grandes). Contorno: rectángulo, con una muesca como macizo sin excavar; fuera `ell`, `you`, `court` y `aitch`.
2. **Una sola luz de estructura, 7,2 m**, y tabiques a media luz: las celdas miden 3,6 o 7,2 de ancho, nada más. Todas las cotas son múltiplos de 0,6 (banda perimetral 4,8, 5,4 o 6,0; zona central 7,2, siempre dos filas; pasillo principal 2,4 o 3,0; tramo de recepción y pasillo de nave 3,0 o 3,6; galería de servicio 2,4) y el origen se ajusta a la retícula de placas. El edificio alterna **tramos de despachos** (dos celdas de 3,6 por vano) y **tramos de salas** (una de 7,2).
3. **Tamaño:** a área 1,0, de 86 a 94 m de largo por 36 a 40 de fondo en la tipología de anillo. `LEAST_WALKS[0]` baja de 90 a 75 m («más directo»).

**Qué puede ser una sala**
4. **Toda sala que no sea nave, archivo o despacho de dirección es una sola celda.** El amueblado, las taquillas, el centro libre y las bandas siguen yendo por celda, como hoy. Cada tipo encuentra su celda por el tramo: 3,6 × banda para despachos y almacenes; 7,2 × banda para jefes, secretaría, correo y reprografía; 3,6 × 7,2 en la zona central para aseos (dos, juntos) y cuartos del núcleo; 7,2 × 7,2 para juntas, descanso, vestíbulos de montacargas y climatización. `ROOM_BANDS` se rehace con estas medidas, también `REFUGE` y `AIR_ROOM`.
5. Hace falta una receta de **despacho pequeño** (3,6 × 5,4: mesa de 1,5 × 1,4, credenza y archivador contra la pared lateral) y una mesa de juntas que quepa en 7,2. Una nave con columnas por planta, como hoy; las demás oficinas abiertas son salones corrientes.

**Circulación**
6. **Sin absorción en la primera construcción.** Los pasillos del edificio se apilan en las tres plantas (por ellos van la evacuación y los troncos de aire). Cada planta se diferencia por los tabiques, el programa y los **cortes**: una arista que falta entre dos celdas de pasillo es un muro o una persiana de seguridad. La planta 3 tiene el anillo cortado; la 2 pierde un tramo. La absorción (celdas de carril marcadas `kind = "module"` en un `cell()` propio) queda como fase posterior, solo si los planos lo piden.
7. **Tipologías.** Una por edificio, la misma en las tres plantas. La primera construcción trae dos: **anillo** (pasillo doble con la zona central entre los dos) y **espina** (un pasillo con salas a los dos lados, edificio largo y estrecho). El **peine** (pasillo de cabecera con dos o tres ramas) va después de aceptar las dos primeras. La tipología es una tabla de filas y columnas, no código por caso.
8. **`map_generator.gd` no se toca.** Todo es sobrescritura en `office_generator.gd` (`lay_grid`, `pick_shape`, `corridors`, `plant_service`, `open_doors` con `fire_doors`, `join`, `make_halls`, `trim`, `tidy`, `loops`, `alike`, `place_refuge`, `pick_start`, `expose`). `trim`, `tidy` y `loops` no vacían celdas ni sortean puertas. En la planta de reserva (`standby`), todas llaman a `super`.
9. **El programa se decide antes que las puertas:** zonas, tipos y departamentos salen del `corridors()` de oficinas; `finish()` solo los confirma. Los departamentos son tramos dentro del edificio, de 5 a 7 por planta (son también las zonas de circuito de la planta 2).
10. **Vueltas y pasillos expuestos salen de la arquitectura.** Vueltas: el anillo, las transversales, las naves y la sala de juntas con dos puertas, el archivo por sus dos extremos, la galería con dos entradas o más. Si la planta 3 no llega a `rings()`, se baja su cifra y se dice. Pasillo expuesto (20 m en la planta 2, 28 m en la 3): un tramo entre muros ciegos (núcleo, lomo del archivo, juntas, climatización), reservado por la circulación y medido por el validador.

**Dónde va cada hito**
11. **Los montacargas y la climatización, en núcleos interiores**, dentro del anillo y nunca contra el perímetro, para que la mano en la pared no los encuentre (`hits == 0` se conserva). Dos núcleos, uno en cada extremo de la zona central: el del montacargas A, lejos de la recepción; el del B, en el extremo contrario. Con cada uno van los aseos y el montante. La climatización de la planta 3 ocupa el núcleo opuesto a su llegada. `place_refuge` de oficinas pasa `[]` como rumbos. El vestíbulo de cada montacargas mide 4,5 m o más a lo largo del eje de la cabina y sus celdas no llevan `service`.
12. **La galería de servicio**, en un lado largo del perímetro: sin falso techo, con almacén, depósito y cuartos técnicos. El cuarto eléctrico de la planta 2 va en ella, a unos dos tercios desde la llegada (`ELECTRICAL_DEPTH`), y **no comparte núcleo ni galería directa con el montacargas B**: el camino del cuadro al B cruza tres zonas de circuito o más, casi todo bajo falso techo (lo mide el validador).
13. **Recepción** en una esquina o en un lateral, según la semilla (`pick_start` propio). **Ventanilla de Personal** en el primer tramo del anillo, con su espera. **Puesto de seguridad** en la puerta de la mitad cerrada de Dirección, con su cristalera al pasillo, dentro de `SECURITY_DEPTH`.
14. La posición relativa de recepción, A, B y climatización se sortea de una lista de sitios por tipología, y su dispersión se mide en las mil semillas: no pueden caer siempre en los mismos extremos.

**Lo demás**
15. **Un superviviente** (`areas = [1, 0.5, 0.5]`): el edificio se dimensiona para el área mayor y las plantas de 0,5 tienen un tramo clausurado tras un cortafuegos cerrado (celdas `VOID`).
16. **Taquillas y minuteros:** `hide_free` comprueba el largo del muro (en 3,6 m no cabe a ±1,8). Cada tramo de pasillo de la planta 2 tiene un muro de 7,2 o del núcleo donde va su minutero.
17. **Topes de render** (8 volúmenes de rebote, 24 sondas, 16 capas de luz, lotes por sala): se miden en cuanto haya plantas sin muebles (`light_layers_scan --floor=2` en 40 semillas y el banco en Alto), no al final.
18. **Pruebas.** Se reescriben las que fijan cifras de hoy (`office_test` 143, 418, 504 a 568; métricas de taquillas, paseo y placas; `rings`; filtros de tamaño de `lurker_bots_test` y `lurker_capture_test`; `office_proportion_test`). Pasan sin tocar: `manifest_golden_test`, el hotel intacto tras generar oficinas, el doble generado idéntico, `physics_checks`, `lurker_shell_test`, `net_test`, `creature_contract_test`.
19. Subir `OFFICE.VERSION` invalida un punto de control guardado en las oficinas: se dice en `docs/CHANGELOG.md`.
20. **Ventana de salas y tamaños, por planta**; la regla de «más de la mitad por debajo de 30 m²» se mide en las plantas 1 y 2.

**Orden de construcción**
1. Herramienta del plano y los doce planos de hoy.
2. El edificio en `office_generator.gd`: rejilla compartida, tipología de anillo, cortes, sin vaciar celdas, reserva con `super`. Planos y medida de render.
3. Los cuatro huecos y los hitos con sus cifras; mil semillas antes de seguir.
4. Bandas por celda nueva, programa por zonas, puertas con motivo, vueltas y expuestos.
5. Receta de despacho pequeño, taquillas, minuteros, amueblado.
6. Tipología de espina. Validador, pruebas reescritas, capturas, banco.

**Pendiente del autor (no bloquea):** un sótano real tiene dos escaleras de emergencia. Por defecto no se ponen; si el autor las quiere, serían núcleos con la puerta cortafuegos cerrada y su rótulo, sin uso en el juego.

## Estado de la construcción (14 de noviembre de 2026)

Hechas las fases 1, 2 y 3 del orden de 13. La planta nueva vive junto a la de hoy, **apagada**.

**Cómo se enciende.** `office_palette.REAL_PLAN` (hoy `false`); sin tocarla, `--real-plan` en la línea de órdenes o `office_palette.real_plan_test = true` en una herramienta. Con el interruptor apagado, el manifiesto de las semillas 7, 33, 101 y 404 (2 supervivientes), 5 (1), 12 (5) y la planta de reserva es byte a byte el de antes (hash del JSON). La planta de reserva sigue siendo la de hoy con el interruptor encendido.

**Qué hay.**
- `tools/dev/office_plan.gd`: plano PNG por planta y hoja con las tres, desde el manifiesto. Planos de hoy en `evidence/planta/hoy/`, nuevos en `evidence/planta/nueva/` (y `nueva/otros/` para 1 y 5 supervivientes).
- `office_generator.gd`, sección «The real building»: `draw_building()` sortea una vez por intento el edificio desde la tabla `TYPOLOGIES.ring` de la paleta (filas: banda delantera, pasillo, dos filas centrales de 7,2, pasillo, banda trasera, galería de 2,4, banda de servicio; columnas: testeros, tres pasillos transversales, cinco vanos de 7,2 por mitad, de despachos (dos celdas de 3,6) o de salas (una de 7,2)). Todas las cotas son múltiplos de 0,6, y la recepción mide múltiplos de 1,2 para que el origen caiga en la retícula. Las tres plantas usan la misma rejilla. El contorno es rectangular o, con probabilidad 0,35, con muesca (sin galería ni banda de servicio en un extremo). Ninguna celda viva se vacía: `trim`, `tidy`, `loops` (sin sortear puertas), `alike` y `expose` quedan neutralizados. Cortes: en la planta 2, la galería junto al transversal de B; en la 3, un tramo de un pasillo principal (sorteado en cada intento).
- Núcleos: uno en cada extremo de la zona central, vano de montacargas y vano de despachos. A tiene el montacargas hacia dentro (contra el testero, A pasaba de 0,9 en DEPTHS[0]); B lo tiene contra el transversal, y la planta 3 sale de él a ese pasillo. Climatización en el núcleo de A. Recepción en el extremo de B, en una esquina de la banda delantera o en el testero. Ventanilla y puesto de seguridad en las bandas perimetrales; cuarto eléctrico en la banda de servicio. Ducto principal solo por pasillos, la climatización y salas de 7,2 cruzadas en recto.
- Un superviviente: el edificio es el del área mayor, y las plantas de 0,5 cierran la mitad sin núcleos (celdas VOID). Los dos núcleos quedan en la mitad abierta, B junto al cruce central, y una sala de paso entre ellos separa sus caras para la mano en la pared.
- Cifras nuevas, solo con el interruptor encendido: LEAST_WALKS[0] 75 (`REAL_LEAST_WALKS`, también en el validador) y ventana de salas 45 a 99 (`REAL_ROOMS`; el 99 es para que la planta de reserva, la de hoy, quepa en la misma ventana).

**Ronda 1, cifras** (`evidence/planta/metricas.md`): 250 de 250 semillas con planta; 113 rechazadas por el validador (taquillas); los tipos aún salían de `PLANTA_MIX` celda a celda.

### Ronda 2 (fases 4 y 5, 14 y 15 de noviembre de 2026)

Sigue **apagada** (`REAL_PLAN = false`). Planos en `evidence/planta/ronda2/` (semillas 7, 33, 101, 404; `s1/` y `s5/` con 1 y 5 supervivientes), métricas en `metricas_300.txt`, `metricas_s1.txt` y `metricas_s5.txt`, pruebas en `pruebas_on/` y `pruebas_off/`, capturas en `evidence/planta/capturas/`. Con el interruptor apagado, los hashes de los manifiestos de las semillas de la ronda 1 y de la planta de reserva no cambian (`hashes_off.txt`).

**El edificio, retocado.** Los vanos de los testeros y los cabos de los transversales hacia el muro delantero y hacia la banda de servicio quedan sin excavar (VOID en las tres plantas): el anillo se cierra en los transversales de los extremos, ningún pasillo llega al muro y no quedan despachos sueltos en los extremos (pedido del director, 15 de noviembre). La recepción va siempre a la esquina de la banda delantera del extremo de B. Excepción: en un piso para un superviviente se conservan los testeros (las plantas de media superficie necesitan ese tramo para la cuota de B), y sus cabos siguen siendo vestíbulos con puerta.

**Programa por zonas** (`draw_programme()`, desde el `corridors()` de oficinas, antes de las puertas). Cada celda tiene zona por su fila y su columna (`zone_of()`): «office» (banda, vano de despachos, 3,6), «bay» (banda, vano de sala o de montacargas, 7,2), «corner» y «end» (testeros, solo en pisos para uno), «deep» y «narrow» (zona central), «core», «lift» (la celda del vano de montacargas que no usa un ascensor) y «service». Tablas en la paleta: `REAL_ZONES` (pesos por zona y planta), `REAL_MUSTS` (lo que cada planta debe tener y en qué zonas, antes del sorteo), `REAL_ROOM_BANDS` (medidas de cada tipo en el edificio, con `fits_band_now()`), `REAL_DEPARTMENTS` (5 a 7). Orden: salones, aseos de dos en dos en una fila de cada núcleo con el almacén de limpieza en la otra, lo obligatorio, el sorteo.
- Planta 1: dos naves (una por mitad, del núcleo al cruce central, las dos filas centrales; la más larga con columnas, solo en las líneas de estructura, entre vanos: `nave_spots()`); despachos de 3,6 en fila en las bandas (los vanos de 7,2, despachos de jefe); juntas y descanso en el vano libre del núcleo de B; reprografía en el núcleo; un correo; la ventanilla solo en un despacho de banda.
- Planta 2: un archivo por fila central y mitad, recto, de punta a punta (cuatro), con puerta en cada extremo; la banda junto a la galería, depósitos en fila que dan unos a otros (puerta al pasillo en los extremos y en medio); la otra banda, archivo móvil, despachos de consulta, reprografía y correo; otro correo junto al vestíbulo de llegada.
- Planta 3: en la zona central, por fila y mitad, un despacho de dirección de dos vanos de 7,2 con su secretaría al lado y una puerta entre ellos, y el resto salas de juntas y de descanso (sin naves, pedido del director); en las bandas, cada despacho de dirección es un vano de 7,2 con la secretaría al lado; el puesto de seguridad junto al corte del anillo, del lado de la llegada; juntas en el vano libre del núcleo de B. El ducto principal no pasa sobre una sala de juntas.
- Departamentos (`departments_of()`): tramos de vanos a lo largo, de 5 a 7, sin cruzar un transversal; el de la llegada es el sector 0. Son los `sector` (`zones()` sobrescrito) y en la planta 2 las zonas de circuito.

**Puertas con motivo** (`open_doors()` real). Cada sala, una puerta a un pasillo principal o a un transversal (la banda de servicio, a la galería); la recepción, a un pasillo que sigue. Un pasillo que acaba contra un corte acaba en la puerta de una sala. Naves y sala de paso: una puerta en cada pasillo principal, en extremos opuestos (los atajos). Archivo: una en cada extremo. Depósitos: en fila. Despacho de dirección: solo a su secretaría. Juntas: segunda puerta donde pasa otro pasillo. El vestíbulo de llegada de las plantas 2 y 3 da a la sala de al lado de su vano (correo, juntas). Si la mano en la pared obliga a abrir el vestíbulo de un montacargas a la sala de al lado, nunca a los aseos: el núcleo cambia sus filas (`off_the_toilets()`). Cortafuegos en cada frontera de departamento de los pasillos principales, además de los de `OPEN_RUN`. La regla provisional de la ronda 1 (segunda puerta a la galería de cualquier sala) ya no está: `loops()` solo da segunda puerta a almacenes y depósitos, si faltan vueltas.

**Monotonía del anillo**: cortafuegos por departamento; cristaleras por departamento (`REAL_GLAZED`: un departamento con sus despachos acristalados al pasillo, otro casi ciego); el anillo cerrado en los extremos. No hecho: el ensanche de espera ante la ventanilla y la nave abierta al pasillo (las dos piden fundir carril y sala: la absorción).

**Taquillas y minuteros**: `hide_free()` real: la taquilla dentro del largo de su muro y más cerca de él que del de al lado (el muro que deduce el validador); en celdas de 3,6, en los muros cortos, salvo los aseos, que las llevan en los largos (el fondo es de las cabinas). `timer_button()` real: cualquier celda del tramo y cualquier punto de `TIMER_SPOTS` dentro del muro.

**Amueblado**: `SMALL_FURNITURE` (paleta), con el ancho por debajo del cual vale y su receta: despacho de 3,6 (mesa `work_desk` de 1,5 × 1,4 en el centro del muro del fondo entre dos archivadores, credenza `sideboard` y archivador en un muro lateral), secretaría, aseos (cabinas contra un muro largo, al fondo), ventanilla, reprografía, correo y despacho de dirección de banda. `recipe_of()` elige; `office_recipes.kinds()` admite las dos. El ascensor del hotel en la recepción va al muro exterior (sección 5), y la rejilla de pared no se arrima a él. El pozo de la planta 3 nunca sobre una celda que use otra planta.

**Cifras** (`tools/dev/office_plan_metrics.gd`, primer intento que sale de cada semilla, validado; `tools/dev/office_plan_physics.gd`, montado como en el juego):
- 300 semillas, 2 supervivientes: 300 con planta, **0 rechazadas por el validador**; intento que sale p50 0, p90 1, máx 4. Intentos fallidos: `electrical` 96, `security` 26, `planta` 17 y `duct_exit` 64 (aseos, despachos de dirección y secretarías sin placa ni muro libre para la rejilla); los absorbe el intento siguiente.
- Llegada a salida, p50: 79,8, 87,0 y 88,8 m (planta 1: mín 75,6, con `REAL_LEAST_WALKS` 75). Mano en la pared: 0. Salas por planta, p50: 52, 53 y 62. De menos de 30 m²: 0,58 y 0,57 en las plantas 1 y 2. Vueltas p50 18, 18 y 7 (tope 6; la planta 3 llega justa, mín 6). Taquillas p50 19, 17 y 20 (mín 13, 12 y 13). Superficie por planta, de 2707 a 3197 m².
- Salas por tamaño (las 300 juntas; plantas 1, 2 y 3): de 15 a 30 m², 8510, 8510 y 10310; de 30 a 50 m², 5755 en las tres; de 50 a 100 m², 900, 600 y 1796; de 100 m² o más, 600, 1200 y 902.
- Capas de luz: 16 de 16 como mucho, sin choques; 103 de 300 pisos llegan a 16.
- 60 semillas con 1 superviviente: 60 con planta, 0 rechazadas, pero con muchos intentos (`real_refuge_1_depth` 621: la cuota de B en la media planta); plantas 2 y 3 de 33 a 41 salas. 40 semillas con 5: 40 con planta, 0 rechazadas, 61 a 100 salas, de 98 a 168 m de llegada a salida.
- Física al montar (semillas 1 a 40, antes de dejar sin excavar los testeros): 39 de 40 con 2 supervivientes y 37 de 40 con 1 (una cae a la reserva por el generador). Fallos: `passage` y `leaf_arc` entre un depósito de la planta 2 y su galería: un panel del muro de la galería de la planta 1, de 12,05 m de alto (de y −7,65 a 4,4), baja hasta la planta 2 delante de esa puerta (colisión hallada con `evidence/planta/ronda2/debug_passage.gd`; sin resolver).

**Qué sigue en rojo**: ver la tabla de pruebas del informe de la ronda. Espina, absorción, `OFFICE.VERSION` y el banco, para después.

### Ronda 3 (15 de noviembre de 2026): la tipología de anillo, lista para encenderse

Sigue **apagada**. Pruebas, métricas, planos y capturas en `evidence/planta/ronda3/`. Con el interruptor apagado, los hashes de `ronda2/hashes_off.txt` no cambian.

- **La física al montar.** El panel de 12,05 m era el corte del ducto principal de la planta 3 en un muro alto de la planta 1 que queda encima en planta: `office_geometry.duct_cuts()` aceptaba un ducto por debajo del suelo del muro y el trozo «por encima del hueco» iba de su techo hasta la planta 3. Ahora un ducto bajo el muro no lo corta. 80 de 80 semillas sin errores físicos (antes 16 de 80).
- **Las pruebas que estaban en rojo.** `lurker_fairness_test`: el compañero a 4 m del centro de una celda de 7,2 quedaba tras el cortafuegos de la celda siguiente; a 3 m con la planta nueva. `office_audio_test`: el chillido a 3 m del centro de un despacho de 3,6 salía por la pared; a 2 m a lo largo de la sala con la planta nueva. `office_dressing_test`: las celdas de pasillo de 3,6 entre dos puertas de despacho no tienen muro libre (cada puerta reserva 2,5 m, `DOOR_HALF`) y no cuentan con la planta nueva, como los cruces. `office_lies_test`: la nave de cubículos solo recibía islas de dos mesas, que no llevan mampara; en el edificio real una isla de dos en una nave de cubículos cierra sus extremos con mamparas (`island_screens()`), y las dos naves de la planta 1 son una de cada tipo.
- **Planta 3.** Las bandas son suites de vano entero (`band_suites()`): en cada tramo entre cruces, despacho de dirección y secretaría alternados, los despachos en los vanos de despachos (sus dos celdas de 3,6, una sala, con la receta `NARROW_EXEC`: la mesa de dirección de 2,2 × 2,3 no cabe en una celda de 3,6, y lleva mesa de trabajo entre dos archivadores, librería y, en la otra celda, el tresillo) y las secretarías en los de 7,2; cada director con puerta a una secretaría y cada secretaría a un director al menos, así que para cruzar una banda de suites se pasa por las antesalas. En la zona central, la única sala de juntas obligatoria más, como mucho, otra en el vano libre de B; el resto, despacho de gabinete o sala de descanso. El puesto de seguridad ya no cae en cualquier celda de banda si los del corte no valen: el intento se repite. Se intenta acristalar su muro al pasillo, pero el lector de tarjeta de su puerta está en esa cara y `glazable()` lo impide casi siempre.
- **Recetas por medidas.** `recipe_of()` ya no mira el interruptor: la receta estrecha se elige porque el lado corto de la celda está por debajo de su cifra, y todas las cifras están por debajo del módulo menor de hoy (6 m). Las de ventanilla, reprografía, correo y dirección bajan de 6,5 a 6,0, así que una banda de 6,0 m del edificio real lleva la receta de hoy.
- **Un superviviente.** Planta 2: la sala más honda era la banda de servicio detrás de un núcleo, a la que solo se llega por los extremos de la galería. El depósito del medio de la fila junto a la galería se abre también a ella (solo en las plantas pequeñas de un piso para uno), y el cuarto eléctrico de esas plantas va en esa banda, no en la de servicio.
- **`office_proportion_test`** mide la banda con `fits_band_now()` y reconoce la mesa de trabajo (despacho, secretaría y dirección de 3,6) y las cabinas (aseos de 3,6) como pieza principal.
- **La mesa de juntas.** En la sala de 7,2 × 7,2 con dos puertas, los caminos desde las dos cruzaban los dos sitios de la mesa: en el edificio real también se prueba la mesa corrida 0,6 y 1,0 m a lo largo (`lay_table()`); las sillas del lado cercano salen del eje de la mesa, no de su centro. En 40 semillas, 65 de 87 salas de juntas con mesa.

**Cifras** (`evidence/planta/ronda3/metricas_*.log`, física en `fisica_*.log`, pruebas en `pruebas_on/` y `pruebas_off/`):
- Las 46 pruebas de `verify.ps1`, una a una con sus argumentos: 46 de 46 encendido y 46 de 46 apagado. `office_proportion_test` (fuera de `verify`): apagado falla solo la ventanilla (18,6 % de suelo, mínimo 20), como antes; encendido fallan ventanilla 14,3, archivo 18,4, archivo móvil 27,4, dirección 18,9 de suelo, la pieza principal de reprografía en cuadro (25,4) y «dos mesas para los papeles por planta» (0).
- Física al montar: 60 semillas con 2 supervivientes, 30 con 1 y 30 con 5: ninguna a la reserva, ningún error físico.
- 300 semillas, 2 supervivientes: 300 con planta, 0 rechazadas; intento que sale p50 0, p90 1, máx 3. Fallidos: `electrical` 96, `security` 58, `planta` 17, `duct_exit` 82 (dirección 37, secretaría 20, aseos 17, reprografía 7, seguridad 1). Salas p50 52, 53 y 57 (la planta 3 bajó de 62). Vueltas p50 18, 18 y 13. Taquillas p50 20, 17 y 20. Llegada a salida p50 79,8, 87,0 y 93,6 m. Capas de luz 16 como mucho, sin choques.
- 60 semillas con 1 superviviente: intento que sale p50 1, p90 3 (antes `real_refuge_1_depth` 621 intentos fallidos; ahora 138). 40 con 5: p50 0, p90 1.
- Las vueltas: los pasillos solos dan 4 (3 con el corte); el resto son los salones con más de una puerta (una nave de 8 celdas tiene 9 puertas al anillo y cuenta 8) y las salas con dos puertas (depósitos en fila, secretarías entre dos despachos). La cuenta es correcta como número de caminos alternativos, pero no son 18 vueltas que un jugador recorra.

**Capturas** (`evidence/planta/ronda3/capturas/`, semilla 7, Alto): la recepción desde las puertas del ascensor (`7_recepcion_ascensor`), una suite de dirección desde su secretaría (`7_suite`), la sala de juntas de la planta 3 (`7_juntas`, una de las que se queda sin mesa) y el puesto de seguridad desde su pasillo (`7_seguridad`, sin cristal).

**Qué no está**: una de cada cuatro salas de juntas sigue sin mesa. El puesto de seguridad casi nunca tiene su cristalera (4 de 60): `glazable()` no acristala un muro con algo en sus caras y el lector de tarjeta de su puerta está en la del pasillo. Las naves siguen escasas: una calle de puerta y las columnas no dejan islas de 4 o 6 mesas en celdas de 7,2 ni nada en las de 3,6.

### Ronda 4 (15 de noviembre de 2026): remates del anillo

Sigue **apagada**. Todo en `evidence/planta/ronda4/` (guiones de depuración incluidos; `medidas_final.sh` repite las medidas). Con el interruptor apagado, los hashes de `ronda2/hashes_off.txt` no cambian (`ronda4/hashes_off.txt`). La espina no está construida (ver al final).

**Hecho, por punto**
1. **Mesas para los papeles.** `document_placement` deja los papeles solo en las piezas de esquina «table», «desk» y «nightstand» a 25 m o más de la llegada; la planta 2 no tenía ninguna (su correo junto al vestíbulo queda cerca) y la planta 1 una. Ahora: `REAL_MUSTS` de la planta 2 lleva la sala de descanso de los archiveros y el correo del registro; un tipo con mesa (`PAPER_TOPS_KEPT`) va primero a `REAL_TOPS_FROM` (0,35 del largo) de la llegada; y en el edificio real esa mesa, si su esquina queda tapada, pasa a una esquina libre (`furnish_sockets()`). La prueba da 2 o más en cada planta.
2. **El coste del recorrido.** El paseo del banco son los primeros 24 m de la ruta. Sonda propia (`render_probe.gd`, semilla 81, Alto, 10 puntos, ocultando por tipo solo la geometría): de media 1818 objetos y 703 mil primitivas por punto con la planta nueva frente a 593 y 351 mil con la de hoy. De dónde: los muebles de la nave (4288 objetos sumados en los 10 puntos, 26 % de las primitivas), las salas acristaladas (3605: un departamento al 90 % de cristal deja ver cada despacho) y los despachos y pasillos. La causa de fondo es el lote **por sala**: un despacho de 3,6 lleva 11 lotes de cajas y 31 de modelos para 45 piezas (`node_dump.gd`), y una celda de nave 19 de modelos; con salas de la mitad de ancho, el doble de lotes por metro de vista. Lo que se dibuja se ve (la oclusión funciona; la sonda primera, sin esperar a que se asiente tras saltar de punto, daba cifras falsas). No arreglado: juntar los modelos de un salón en un solo lote pide que sus celdas compartan capa de luz y que la sala no se oculte por celdas (`room_layers.assign()`, `update_visibility()`). Capas de luz: 16 de 16 en 113 de 300 pisos, sin choques: no hay margen.
3. **Naves.** Las dos naves de Personal son naves (pasillo central e islas; columnas solo la primera, 13.5). `join()` daba una puerta a cada celda de la nave porque los salones se hacían después: ahora `open_doors()` los hace antes (`real_halls()`), y la nave tiene sus dos puertas. Columnas del edificio real con `REAL_COLUMN_CLEAR` 0,6 (`column_clear()`, por medidas como `recipe_of()`). En 60 semillas: 2724 puestos en 916 celdas (antes 1608), 4,2 por celda de 7,2, islas de seis en 170 celdas.
4. **Puesto de seguridad.** El lector de tarjeta queda en un tramo de muro macizo junto al marco (`office_geometry.reader_stretch()`), la cristalera en el resto; `glazable()` y el validador lo admiten. 52 de 60 con cristal.
5. **Juntas.** Como mucho dos puertas, la segunda en un muro de al lado, y las puertas hacia una esquina (`hang_doors()`); la mesa prueba más sitios. 108 de 108 con mesa. Rejilla: en el edificio real se prueba cada 0,6 m del muro; `duct_exit` 34 intentos fallidos en 300 semillas (antes 82).
6. **Planta 3.** Las celdas centrales de un vano de despachos son un archivo de dirección de vano entero. La banda de servicio no: su archivo daba a ella un canal fuera del pasillo del archivo (`lurker_shell_test`, semilla 3). Salas p50 56 (antes 57).
7. **`office_proportion_test`.** Lee en el edificio real cifras propias de archivo (18), archivo móvil (18), dirección (15) y pieza en cuadro de reprografía y secretaría (25), con el porqué en la prueba. Sigue roja la ventanilla (14,1; apagado 18,6).
- Además: la galería sin falso techo tiene salida de ducto en cada celda (`office_audio_test`: se la oía por la rejilla del almacén detrás del muro), y `office_recipes.prepare()` crece un milímetro los límites de las cápsulas (empates que el generador dejaba y la prueba no).

**Cifras** (`metricas_*.log`, física en `fisica_s2.log`):
- 300 semillas, 2 supervivientes: 300 con planta, 0 rechazadas; intento que sale p50 0, p90 1, máx 4. Fallidos: `security` 342, `electrical` 96, `planta` 37, `duct_exit` 34. Salas p50 52, 53 y 56. Vueltas p50 7, 11 y 7 (mín 6, 10 y 6): bajan porque las celdas de los salones ya no tienen puerta cada una. Llegada a salida p50 79,8, 87,0 y 98,4 m. Manos en la pared: 0.
- 60 con 1 superviviente: 60 con planta, intento p90 2, máx 7. 40 con 5: p90 0, máx 2.
- Física al montar, 60 semillas: 0 a la reserva, 0 errores.

- Las 46 pruebas de `verify.ps1`, una a una con sus argumentos (`pruebas_on/`, `pruebas_off/`): 46 de 46 encendido y 46 de 46 apagado. `office_proportion_test`: 54 de 55 en los dos (la ventanilla).
- Banco, Alto, encendido (`bench.out`): el paseo da 7,20 ms de media, 727 objetos y 362 mil primitivas (ronda 3: 10,43 ms, 1630 y 669 mil; con la ruta de esta ronda).

**Qué no convence**: `security` falla seis veces más que en la ronda 3 (lo absorbe el intento siguiente): al sellar el puesto a una puerta, la planta 3 baja de las 6 vueltas (`debug_security.gd`, 60 semillas: 59 rechazos por vueltas, de 2 a 5), porque sus vueltas ya están en el mínimo. Las capturas `7_nave` y `7_seguridad` de `office_plan_capture.gd` no enseñan lo pedido: la de la nave encuadra la fila de armarios de una celda del extremo, y la del puesto queda tapada por la hoja abierta de su puerta; hace falta encuadrarlas de nuevo en la herramienta.

**La espina, no construida.** Lo que impide escribirla como tabla sin tocar el código del anillo: `draw_building()` lee `TYPOLOGIES["ring"]` y `deal()` devuelve el anillo; el sitio de cada montacargas elige vestíbulo y cabina entre dos filas centrales (`site`), y la espina tiene una; los transversales conservan siempre las mismas filas y el del medio es `crossings[1]`; las naves y archivos solo abren a pasillos principales (`corridor_of` excluye la galería), y en la espina la galería es la única segunda vía; `real_refuge()` gira vestíbulo y cabina; la ventana de salas (`REAL_ROOMS`, 45) es una para todo el piso real y una espina de 90 a 100 por 20 a 24 m da unas 35 a 42. Propuesta: filas banda, pasillo, fila central de 7,2, galería, banda de servicio; los transversales de los extremos, pasos con puerta del pasillo a la galería por la fila central y el del medio macizo; el pasillo, esos pasos y la galería forman la única vuelta de pasillo, y la fila central queda dentro, como el centro del anillo: montacargas y climatización en sus núcleos, con la cabina en la celda de 3,6 del núcleo; la mano en la pared desde la recepción no entra. Vueltas: esa, las naves y archivos con puerta al pasillo y a la galería y los depósitos en fila; propuesta `rings` de 4 para la espina. Los cortafuegos cada 45 m ya los pone `fire_doors()` por tramo recto.


### Ronda 5 (15 de noviembre de 2026): los bots, la ventanilla y la variedad del anillo

Sigue **apagada**. Todo en `evidence/planta/ronda5/` (guiones de depuración incluidos; `controles.sh` corre uno a uno los 76 controles de `verify.ps1` con sus argumentos y los que se le añadan). Con el interruptor apagado, los hashes de `ronda4/hashes_off.txt` no cambian (`ronda5/hashes_off.txt`). La espina no está construida (ver al final).

**1. Los bots atascados (semilla 33).** No era la planta sino una hoja: el cortafuegos del anillo entre los pasillos 76 y 77, colgado junto a la pared lateral (como manda `hang_doors()` para los cortafuegos), abierto hacia el tramo 76 quedaba a lo largo de la pared de la ventanilla, a 0,3 m de ella y encima de su puerta (sonda de colisiones `dbg_probe.gd`: `Door_76_77` en (10,2; 22,5)). Los dos bots salían de la ventanilla y chocaban con ella. Arreglo, solo en el edificio real (`office_generator.hang_doors()` y `leaf_covers()`): una hoja que, abierta, quedaría a lo largo de una pared lateral sobre una puerta de esa pared se cuelga del otro lado; un cortafuegos se abre hacia el otro tramo o pasa a la otra pared lateral, siempre junto a ella y colgado de esa jamba (`map_validator`), y nunca hacia un cruce. Semillas 7 y 33 con `--real-plan`: ganan sin ninguna incidencia grave.

**2. La ventanilla.** Siempre en una celda de vano entero (7,2 × banda) de una banda cuyo pasillo mide 3,0 m (`special_fits()`); el pasillo principal junto a la banda de la recepción mide siempre 3,0 (el tramo de recepción de 13.2), así que siempre hay sitio. Su espera: hasta dos bancos (`bench_slat`) en el pasillo, contra la pared de enfrente lo más de cara a la puerta que quepan, o en su propia pared junto a la puerta, con las reglas del mobiliario de pasillo (`office_recipes.lay_wait()`, antes de `lay_halls()`), salvo una: `lay_line()` aparta cada pieza de los huecos de los accesorios de pared (cada 2 m) y un banco de 1,5 m no cabe nunca entre ellos (por eso ningún pasillo tenía bancos); la espera solo evita los accesorios montados por debajo de 0,5 m (extintor y enchufe, `WAIT_LOW`). Resultado: un banco frente a la ventanilla en las semillas 7 y 33, ninguno en la 101 (no cabe: puertas y rótulos de la pared de enfrente). Receta de la celda de 7,2 × 4,8 o 5,4 (`SMALL_FURNITURE[WINDOW]`): archivadores, estantería, mesa de clasificar, fichero, mostrador de formularios, mesa de trabajo y carro. **Sigue por debajo del mínimo de suelo**: `office_proportion_test` da 12,5 % (mínimo 20; ronda 4, 14,1 en celdas de 3,6). Los repuestos no encuentran pared: en 7,2 × 4,8 se colocan los archivadores, la estantería y la mesa de clasificar (3,1 m²) y nada más; la mesa de trabajo (1,8 m de fondo) no deja libre el centro de una banda. Con el interruptor apagado no se puede tocar su receta (los manifiestos deben seguir byte a byte): sigue en 18,6.

**3. Variedad entre partidas.** Lo sortea `draw_building()` de la tabla `TYPOLOGIES.ring` (claves nuevas `bays`, `lean`, `second_cross`, `starts`, `pools`):
- 11 o 12 vanos (antes 10 siempre; un piso de área mayor que 1 conserva sus 2 × `half_bays` de antes: con 15 o 16 vanos quedaban tramos rectos por encima de `OPEN_RUN`, 19 de 40 rechazados), repartidos entre las dos mitades con el transversal del medio desplazado hasta un vano; con 11 vanos, 4 de cada 10 llevan un segundo transversal en la mitad larga (dos vanos o más a cada lado); el edificio de 12 vanos lleva transversales de 2,4 y ninguno más, para quedarse en el largo de 13.3.
- La recepción, en una esquina de la banda delantera o de la trasera. El pasillo principal de su lado mide 3,0. El testero (la celda del extremo de una fila central, excavada solo en la planta 1, con su puerta al transversal del extremo) está escrito en `draw_building()` pero fuera de la tabla: con él, en la semilla 81, `lurker_bots_test` pierde a su presa (ella pasa de ACECHAR a RONDAR en 2 s con la línea de vista libre, `dbg_ray.gd`); quitado el testero, 7 de 7. La causa no se encontró.
- Planta 1: en cada tramo entre transversales, una de las dos bandas (sorteada) convierte parte de sus vanos de despachos (35 a 70 %) en una sala de mecanógrafas (oficina abierta del vano entero, dos celdas, salón corriente de 13.5): las dos bandas y las dos alas no van iguales.
- Ya existían y se conservan: el espejo (columnas al revés), el lado de la galería (filas al revés), la fila del vestíbulo de cada montacargas y la muesca (sin galería ni banda de servicio en un extremo, 0,35).
- No se hace el giro de 90°: toda la sección del edificio real lee filas como bandas y columnas como vanos (`zone_of()`, `bays_of()`, `open_doors()` con `way.x`), y en un sótano sin brújula no se notaría.
- Qué núcleo lleva A y cuál B no se puede sortear con las reglas de profundidad: A tiene que quedar en el extremo contrario de la recepción (`DEPTHS[0]` 0,65 a 0,9 y 75 m), B en el contrario de A (`DEPTHS[1]` desde 0,8) y la climatización en el contrario de B; así que la recepción y B van siempre al mismo extremo y A y la climatización al otro. Cambia de qué extremo (espejo), en qué fila y, con la recepción, en qué esquina.

**Cifras, 300 semillas, 2 supervivientes** (`metricas_300.log`): 300 con planta, 0 rechazadas; intento que sale p50 0, p90 1, máx 3; fallidos `security` 138, `electrical` 42, `duct_exit` 33, `planta` 10, `real_refuge_2_depth` 7. Largo 86,4 a 93,6 m (p50 91,2; antes 79,2 siempre), fondo 36,6 a 40,8 (p50 38,4); 11 vanos en 2 de cada 3, 12 en el resto; 3 transversales en 237, 4 en 63; el del medio entre 0,37 y 0,63 del largo; recepción en esquina delantera 155, trasera 145; muesca en 108; 243 órdenes de vanos distintos en 300 edificios; bandas de la planta 1 con el mismo reparto de salas en 62 de 300. Posiciones relativas: A respecto de la recepción, B respecto de A y la climatización respecto de B, siempre a lo largo del edificio (sectores 0 y 4, mitad y mitad): lo fijan las reglas de profundidad en un edificio lineal. Llegada a salida p50 88,2, 96,6 y 108,6 m (planta 1, mín 76,2). Manos en la pared: 0. Salas p50 58, 61 y 65. Vueltas mín 6, 10 y 6. Capas de luz: 16 como mucho, sin choques, 176 de 300 llegan a 16 (ronda 4: 113; más salas por edificio).

**Además**: el vestíbulo de un montacargas se acepta solo si también cumple su banda medido sobre toda la planta, como lo mide `office_test` (la semilla 32 dejaba B a 0,79999999 con los edificios nuevos).

**Las otras cifras**: 60 semillas con 1 superviviente, 60 con planta, 0 rechazadas, intento p90 1, máx 3; salas p50 64, 37 y 36. 40 con 5: 40 con planta, 0 rechazadas, 108,0 a 112,8 m de largo, 3 o 4 transversales. Física al montar, semillas 1 a 60 con 2 supervivientes: 0 a la reserva, 0 errores. `office_proportion_test` encendido 53 de 55 (la ventanilla, 13,3 de suelo; y la pieza principal de dirección en cuadro, 0,0: la cámara encuadra un despacho de dirección de 3,6 cuya mesa está en la otra celda; en la ronda 4 pasaba con otro edificio), apagado 54 de 55 (la ventanilla, 18,6, como antes).

**Los 76 controles de `verify.ps1`, uno a uno con sus argumentos** (`controles.sh`; `controles_on/` y `controles_off/`; los escenarios de red con `net_test.ps1 -RealPlan`, interruptor nuevo): apagado, 76 de 76; encendido, 75 de 76 (en la última pasada `office_audio_test` falló una vez, «antes de su medio segundo limpio suena»; repetido solo dos veces, pasa: de reloj real). En rojo, `lurker_route_probe` (semilla 8, un superviviente): sus 37 comprobaciones pasan, pero `door_shut_on_her()` no encuentra en la planta 1 ningún trayecto con una banda de puerta a dos tramos o más («ningún trayecto con una puerta delante»). No lo causan la regla de las hojas, las salas de mecanógrafas, el testero ni el segundo transversal (probado quitando cada uno). Sin resolver. Tras el último cambio (el largo de los pisos de área mayor que 1) se repitieron encendidos `office_test_generator` y `office_test_validator` (los únicos que construyen pisos de 4 y 5): pasan.

**Planos** (`anillo/`): semillas 7, 33, 101, 404, 2026, 5, 12 y 77, sus tres plantas y la hoja; `anillo/s1/` con 1 superviviente (7 y 33). Se distinguen por el largo (86,4 a 93,6), dónde cae el transversal del medio y si hay dos, el lado de la galería, la esquina de la recepción, la muesca y el ritmo de salas de mecanógrafas en una banda u otra de la planta 1. Lo que no cambia: la recepción y B en un extremo, A y la climatización en el otro.

**Capturas** (`capturas/`, semilla 7, Alto): `7_nave` (la nave mayor por su pasillo central, de punta a punta), `7_seguridad` (el puesto desde el lado contrario a su puerta, con la hoja oculta: la cristalera entera), `7_ventanilla` (desde su puerta) y `7_ventanilla_pasillo` (desde el pasillo: el cristal; la herramienta monta el piso para un superviviente y en él no cupo ningún banco); las de rondas anteriores, igual.

**Qué no convence**: la ventanilla sigue con poco mueble; la dispersión de A, B y la climatización es la que dejan las reglas de profundidad (dos rumbos, este y oeste); el testero y el giro no están.

**La espina, no construida.** En esta ronda no hubo margen: los 76 controles uno a uno tardan de 1,5 a 2 horas por estado y se corrieron cuatro veces. Lo que la ronda añade a lo que ya decía la ronda 4: `draw_building()` lee ya la tipología de la tabla (`building.typology`, y `pools` se lee por tipología), y las claves nuevas (`bays`, `lean`, `second_cross`, `starts`, `pools`) valen para una espina tal cual. Siguen pendientes las piezas que la ronda 4 listó (un `site` con una sola fila central, naves y archivos con puerta a la galería, `real_refuge()`, la ventana de salas por tipología y `rings` propio).
