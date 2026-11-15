# Crítica del plan del port: cobertura y fidelidad del gameplay

15 de noviembre de 2026. Crítico de diseño. Leí entero `docs/PORT_UNREAL.md`, las tablas de unidades de los diseños de `.claude/specs/unreal/diseno/` y el código y las pruebas de Godot que se citan. No ejecuté nada. Abreviaturas: `D/` = `.claude/specs/unreal/diseno/`; `PLAN` = `docs/PORT_UNREAL.md`. Las unidades de aplicación se citan como AP (fila 18 de 2.3).

## Bloquea

### B1. Unidades que ninguna fase recoge, y de las que dependen otras

**Apartado:** 6.2 (tabla de fases).

**Evidencia:** comparé los números de unidad de cada diseño con los de la tabla de 6.2. Estos no aparecen en ninguna fase, ni en ningún otro sitio de `PLAN` (búsqueda de cada número en el archivo):

- **U16**, «Carga de punta a punta y red»: generación en tarea, comparación de SHA entre procesos y `OnFloorReady` (`D/mundo.md:171`). La fase 2 se queda en U15 y la 5 nombra U6, U7, U8 y U15. Y **N3** (arranque coordinado, fase 4) va «tras N2 y `mundo` U16» (`D/red.md:168`). Sin U16, la fase 4 no puede empezar y la regla de 2.1 «viaja la semilla y no la planta, SHA-256 del manifiesto» no tiene unidad que la construya.
- **M12**, «Pruebas por área», la única con la aceptación «Tabla de equivalencia prueba a prueba sin huecos sin justificar» (`D/metodo.md:176`). La fase 1 nombra «M1 a M9 y M11». La consecuencia está en I1.
- **M13**, red en `verify` (`D/metodo.md:177`). Es lo mismo que N14, así que basta con decirlo.
- **A12** de audio, «Humo de señal y calibración A/B»: diferencia de nivel de ±2 dB por bus en cinco escenas, grabadas igual en los dos motores (`D/audio.md:161`). La fase 3 nombra «A1 a A11» y la 6, A13. Es la única prueba medible de que el sonido «se siente igual», que es el criterio 2.
- **R15**, efectos que leen profundidad: `echo_field`, `echo_points` y `ceiling_dust_veil` (`D/render.md:192`). Son la vista de eco y el velo de polvo de The Lurker.
- **M10** (`UFourToolset`, `D/metodo.md:174`) y **M16** (empaquetado, `D/metodo.md:180`).

**Cambio que pido:**

- Añadir U16 a la fase 2, después de U11 a U15. Su prueba (dos procesos con la misma semilla dan el mismo SHA) pasa a la aceptación de la fase 2.
- Añadir M12 a la fase 1.
- A12 a la fase 3, con su cifra de ±2 dB en la aceptación.
- R15 a las fases 5 (velo) y 6 (eco).
- M13 se da por igual a N14; M10 y M16, donde el director diga.
- Una frase en 6.2: «Toda unidad de un diseño está en una fase o se descarta aquí, con su motivo».

### B2. Dependencias al revés entre fases

**Apartado:** 6.2, columnas «Qué entra» y «Depende de», y el párrafo «Qué va en paralelo».

**Evidencia:**

- **La fase 5 necesita la 4 y el plan dice que no.** Su hito es «Completar el piso 2 en cooperativo» y su aceptación incluye el escenario `office_coop`. Mete N9, que va «tras N6» (`D/red.md:174`), y N6 es de la fase 4. Aun así, la columna dice «Fases 2 y 3» y el párrafo siguiente dice que «las fases 4 y 5 se pueden solapar».
- **La fase 4 necesita unidades de las fases 5 y 6.**
  - C18 (réplicas) va «tras C9, C10» (`D/criaturas.md:190`), y C9, The Lurker jugable, es de la fase 5.
  - N7, que entra por «N2 a N8», va «tras N4 y `criaturas` C10, C16» (`D/red.md:172`), y C16, el cazador, es de la fase 6.
  - N14 entra en la fase 4 con sus cinco escenarios, versus y `office_coop` incluidos (`D/red.md:179`).
- **La fase 3 necesita unidades de la fase 4.**
  - AP9 (instancia y flujo) va «tras A2, A8, red U-sala» (`D/aplicacion.md:224`), es decir, N2, de la fase 4.
  - M14 (bots del hotel) monta el piso con los asientos y los cuerpos de la red: `level.match_net.spawn_point(seat)` y `level.match_net.bodies[seat]` (`tools/bots/bot_match.gd:80, 123-124`), que son N3 y N4, de la fase 4. Además, el módulo de bots también está en C19 (`D/criaturas.md:191`), que va en la fase 6.
  - AP16 pide portar `lurker_forced_test` y AP17 pide las marcas de captura de The Lurker, 3,15 y 5,4 s (`D/aplicacion.md:231-232`). Las dos cosas necesitan C9, de la fase 5.
- **La fase 2 necesita una unidad de la fase 3.** J11 (escondites, con los casos de `survival_test.gd:309-408`) necesita `AFourHide` (`D/jugador.md:187`), y `AFourHide` es AP14, de la fase 3 (`D/aplicacion.md:229`).

**Cambio que pido:**

- La fase 5 depende de las fases 2, 3 y 4. Se borra «las fases 4 y 5 se pueden solapar»; solo puede adelantarse el texto de `FourCore`.
- En la fase 4: C18 se parte en C18a, The Locust (fase 4), y C18b, The Lurker (fase 5). La parte versus de N7 pasa a la fase 6. Los escenarios versus y `office_coop` de N14 pasan a las fases 6 y 5, y la aceptación de la fase 4 nombra solo coop, late y observer, como ya hace.
- En la fase 3:
  - entra N2, o AP9 queda escrito para funcionar sin sala;
  - M14 pasa a la fase 4, o se reescribe para poner los bots sin `match_net`, y se dice cuál de M14 y C19 es dueño de `TheFour/Bots`;
  - lo de The Lurker en AP16 y AP17 pasa a la fase 5.
- AP14 pasa a la fase 2 junto a J11, o J11 se queda solo con asomarse, inclinarse y gatear, y los escondites se van a la fase 3.

## Importante

### I1. 4 866 líneas de pruebas de Godot que ningún diseño nombra

**Apartado:** 3, fila «Pruebas» («cada dominio porta las suyas dentro de sus unidades»), y 6.2, fase 5.

**Evidencia:** busqué el nombre de cada `*_test.gd` de `tests/` en `D/` y en `PLAN`. Quince no aparecen en ningún sitio, y suman 4 866 líneas:

- **Pruebas de las oficinas:** `office_test` (1 381), `office_light_test` (747), `office_dressing_test` (351), `office_lies_test` (349), `office_finishes_test` (346), `office_proportion_test` (312), `office_walk_test`, `office_pieces_test`, `office_dark_test` y `office_bots_test`.
- **Pruebas de The Lurker:** `lurker_tiles_test`, `lurker_observer_test` y `lurker_capture_test`.
- **Prueba del hotel:** `tests/hotel/room_light_test.gd` (218).
- **Archivos auxiliares sin nombrar:** `office_test_generator`, `office_test_physics` y `office_test_validator`.

Vigilan reglas del piso 2: lo vedado y lo siempre encendido (`tests/office/office_test.gd:171-173`), y las mentiras de The Lurker por planta (`tests/office/office_lies_test.gd:2-6`). La aceptación de la fase 5 solo nombra `descend_test`, `jump_test`, la justicia y `office_coop`. Además, `D/mundo.md:221` reconoce que no sabe si hay una huella de semillas de oficinas, pero la fase 5 pide «Huellas de oficinas iguales».

**Cambio que pido:**

- M12 entra en la fase 1 (B1) y produce `golden/test_map.md`: cada `*_test.gd` de `tests/` con su unidad de destino, o el motivo de que no se porte.
- La aceptación de cada fase incluye «todas las pruebas de Godot asignadas a esta fase, portadas y en verde».
- U0 graba también la huella de oficinas, o la fase 5 deja de pedirla.

### I2. Los récords importados pueden desaparecer de los tableros

**Apartado:** 1 («Récords y descubrimientos sí»); 10, decisión 15.

**Evidencia:** cada línea de `records.json` lleva `generator` (`game/services/records_service.gd:92`). Los tableros solo muestran las líneas con `generator == FLOOR.VERSION` (`:251-253`), y la del hotel es 8 (`game/world/generation/floor_definition.gd:9`). La de las oficinas es `PALETTE.VERSION` (`game/floors/office_floor.gd:22`), que cambiará al congelar el edificio real. `D/plataforma.md:79-87` migra `records.json` de la VERSION 2 a la 3 sin hablar de `generator`. Si el port arranca su propio número de generador, o la fase 5 porta otro edificio, los récords de los jugadores actuales quedan copiados pero invisibles.

**Cambio que pido:** añadir a PL7-PL9 tres cosas.

- Las constantes de versión de generador del hotel y de las oficinas se copian con su valor de Godot.
- `FFourGodotImport` conserva `generator` línea a línea.
- Una prueba de capa 2: un `records.json` real de Godot, importado, muestra los mismos tableros y puestos que en Godot.

Si las oficinas cambian de generador, el plan debe decir qué ven sus récords del piso 2.

### I3. El catálogo de textos está desfasado respecto al código

**Apartado:** 2.1, fila «Textos» («CSV con las claves de `docs/textos_juego.txt`»).

**Evidencia:** `docs/textos_juego.txt` se tocó por última vez el 23 de octubre (`155e141`). Desde entonces hay 44 commits en `game/ui`, `game/app`, `game/intro` y `game/title`. Ejemplo: «SONIDO DE LAS OFICINAS» (`game/ui/hotel_ui.gd:112`) no está en el catálogo. La aceptación de UI-2 comprueba que estén las «317 claves del catálogo» (`D/ui.md`, apartado 6, U2), no que el texto sea el que hoy se ve.

**Cambio que pido:**

- El `SourceString` sale del literal del código de Godot en la versión congelada, y el catálogo solo da las claves.
- La aceptación de UI-2 añade una prueba que extrae todos los literales visibles de `game/ui`, `game/app`, `game/intro`, `game/title` y `game/floors`, y falla si alguno no está en las tablas.

### I4. La fase 3 se juzga sin la portada ni la intro 3D

**Apartado:** 6.2, fase 3 (hito «del título al parte de la cinta» y «el autor juega y dice si se siente igual») frente a la fase 6 (UI-14 y UI-15).

**Evidencia:** UI-14, la portada y la escena de entrada 3D de `game/title/` y `game/intro/` (907 líneas), va «tras mundo, render y criaturas» (`D/ui.md`, apartado 6, U14) y el plan la pone en la fase 6. La sensación que juzga el autor en la fase 3 empieza en esa portada.

**Cambio que pido:** UI-14 pasa a la fase 3, porque sus dependencias ya están hechas al acabar las fases 2 y 3 con The Locust. Si no, el hito de la fase 3 dice «desde el menú principal», y el juicio del autor se repite en la fase 6.

## Menor

- **3, nota bajo la tabla, y fila «Pruebas»:** «81 `*_test.gd` en todo el repo» cuenta las copias de `.claude/worktrees/`. Fuera de `.claude/` hay 55, y en `tests/` hay 54 `.gd`, de los que 49 son `*_test.gd` distintos. Cambio: dar el recuento sin `.claude/`.
- **6.2, fase 3:** J15 (pasos y sonidos del equipo, fase 2) suena antes de que exista el mezclador de A1 (fase 3). Cambio: J15 a la fase 3, o aceptarlo con un bus provisional y decirlo.

## Sin comprobar

- No leí `D/aplicacion.md` ni `D/red.md` enteros; solo sus tablas de unidades y las filas citadas. Puede que algún texto suyo resuelva una dependencia de B2 sin reflejarse en la tabla.
- No comprobé si la VERSION de `office_palette.gd` ya cambió con `REAL_PLAN`, ni si hay jugadores con récords del piso 2.
- No comprobé uno a uno todos los textos del catálogo frente al código: solo un caso y el recuento de commits.
- No comprobé si las pruebas de I1 están cubiertas con otro nombre (por ejemplo, «casos de lo vedado») dentro de alguna unidad.
