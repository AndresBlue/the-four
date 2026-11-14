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
