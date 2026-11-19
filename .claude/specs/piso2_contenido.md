# Piso 2: historia y cosas que tocar

Nota de diseño. Decidida con el autor el 19 de noviembre de 2026. **Nada de esto está construido.**

## Por qué

El autor, 19 de noviembre de 2026: el piso 2 «se siente muy vacío, las habitaciones que no son de interés poco sirven ya que no dan ganas de visitarlas. A diferencia del hotel, que ponerse a revisar los muebles puede servir para encontrar cosas interesantes». Quiere llenarlo de lore, accesorios y herramientas: «cosas para usar que no revienten el gameplay en términos de 1v1 contra la bestia, pero cosas que te añadan QoL o lore».

## La regla de equilibrio

- Nada daña, aturde ni bloquea a The Lurker.
- Cada cosa se paga con algo que ella ya entiende:
  - tiempo de espaldas: quien está ocupado (leyendo, usando algo o quieto 2 s) ya pesa un 20 % al elegir presa (`docs/OFICINAS.md`, sección 4);
  - ruido que ella oye;
  - luz que delata.
- Nada da más cordura de la que ya hay en el piso (el café).

## Lo que entra

Los números son los de la propuesta que el autor fue aceptando.

**A. Rebuscar**

1. **Muebles registrables:** cajones, archivadores, ficheros y taquillas. Casi todos vacíos; algunos con un papel o un objeto. Mismo precio que en el hotel: un segundo de espaldas y ruido. Sin monedas (la máquina expendedora quedó fuera).
2. **Objetos personales sin texto,** que solo se miran. Tienen que casar con cómo se fueron, hace años: deprisa, llevándose lo que pudieron. Queda lo que no les dio tiempo a coger.

**B. Historia**

3. **Documentos de las oficinas:** los cuatro propuestos en `docs/OFICINAS.md` (sección 10) más unos veinte, seis por partida y como mucho dos por planta, como en el hotel.
4. **Terminales de pantalla verde que se encienden:** correo interno y registros. La pantalla alumbra la cara de quien lee. Aquí escribe el ente.
5. **Corchos y pizarras legibles de cerca.**
6. **El rastro de quien estuvo antes:** sus notas a mano por las tres plantas, con consejos verdaderos sobre el piso, su campamento en un almacén y sus restos en el ducto.
7. **Hilos de empleados:** un gafete encontrado lleva a su mesa, su taquilla y su papel. Tres o cuatro personas por partida, con nombre propio.
8. **Caja fuerte en un despacho de Dirección,** opcional: la combinación repartida en papeles y, dentro, el papel de más peso del piso.

**C. Escenas**

9. **Salas corrientes con una escena montada,** sorteada por partida, ocho o diez. Hay que proponerlas de nuevo sabiendo cómo se fue el personal (deprisa, hace años) y que el autor las apruebe.

**D. Cosas que se usan**

10. **Termo:** llevarse la taza de una cafetera para beberla después. No da más café: solo deja elegir cuándo.
16. **Plano de evacuación de la pared:** arrancarlo añade el plano de esa planta a las notas.
18. **Pruebas para la cinta:** lo encontrado (papeles, gafetes, escenas vistas) se cuenta en el informe final.

## Lo que queda fuera

- Máquina expendedora y monedas (11), teléfonos internos (12), fotocopiadora (13), bombillas de repuesto (14), flexos (15), temporizador de cocina (17).
- Grabaciones de voz en dictáfonos o contestadores.
- Lo que nunca se propuso en serio: extintor como cortina de humo, cámara con flash que la espante, cualquier cosa que la frene.

## Lore confirmado ese día

Está en `docs/LORE.md` («Confirmado el 19 de noviembre de 2026»):

- el personal de las oficinas sabía lo que había debajo;
- se fueron más o menos de golpe, años antes de la cinta: intentaron llevarse lo que pudieron y, por la velocidad, algunas cosas quedaron atrás (el autor eligió primero una evacuación ordenada y lo corrigió ese mismo día);
- los relojes y lo que marca la fecha por sí solo siguen andando; los calendarios manuales se quedaron en el día en que se fueron;
- los empleados tienen nombre propio;
- el ente escribe en los terminales.

## Lo que esto cambia en lo ya hecho

- **`game/world/office/office_clutter.gd` ya parte de «se fueron de golpe»** (sillas volcadas, un teléfono descolgado, papeles en montones): casa con lo confirmado y no se rehace. Le falta lo otro que dijo el autor: que intentaron llevarse lo que pudieron (cajas a medio llenar, archivadores abiertos y medio vacíos), y los años que han pasado.
- **Los cuatro documentos de `docs/OFICINAS.md`, sección 10,** siguen valiendo (los escribe gente que sabía), pero sus fechas han de caer antes de que se fueran.

## Lo que tiene que escribir o aprobar el autor

Lore: solo lo que él confirma.

- El texto de cada documento, con su narrativa: quién lo escribe, a quién, qué le pasó antes y qué deja entrever.
- Los nombres de los empleados.
- Qué escribe el ente en los terminales, y a quién.
- Qué hay en la caja fuerte.
- Quién es quien estuvo antes, si se llega a decir. Sus consejos tienen que ser verdad en el juego.
- Qué día marcan los calendarios parados.
- Las escenas de las salas, propuestas de nuevo.

## Orden de construcción propuesto

Cada tramo se puede jugar y juzgar solo.

1. **Rebuscar y documentos (1 y 3).** Es lo que más cambia el vacío y reutiliza lo del hotel (`hotel_container.gd`, `hotel_document.gd`, `game/discovery/discovery_catalog.gd`). Pide los primeros textos al autor.
2. **Escenas y lo que dejaron atrás (9, 2 y lo que le falta a `office_clutter.gd`).** Toca el generador: versión nueva.
3. **Terminales, corchos y pizarras (4 y 5).**
4. **El rastro, los hilos de empleados y la caja fuerte (6, 7 y 8).**
5. **Termo, plano de evacuación y pruebas para la cinta (10, 16 y 18).**

## Sin comprobar al escribir esta nota

- Que el contenedor y el documento del hotel sirvan en el piso 2 sin cambios: se leyeron sus cabeceras, no su código.
- Cómo viaja por la red y se guarda lo encontrado en el piso 2.
- Cuántas salas corrientes hay por planta para repartir escenas y papeles sin repetirse.

Antes de repartir trabajo, esta nota pasa por los críticos y por las fichas de hechos del código (flujo `encargos`), como pide `CLAUDE.md`.
