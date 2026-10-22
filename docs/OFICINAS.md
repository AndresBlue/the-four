# Piso 2: las oficinas secretas

La hoja de dirección del segundo piso: cómo se juega, cómo asusta, cómo se ve y cómo suena, y cómo se construye. **La aprobó el autor el 22 de octubre de 2026**, con sus decisiones (sección 14). **Del piso en sí no hay nada hecho todavía**: ni oficinas, ni sistemas de planta, ni el cerebro de The Lurker, que existe solo como la criatura que se ve ([LURKER.md](LURKER.md)). **De la fase 0 está hecho el paso 0a**, el contrato de criatura (sección 11.1), con sus once migraciones: el director, el aura, el audio, la cordura y sus fantasmas, los ascensores, las teles, la reaparición, el piso guardado, la captura, la red, el observador y los bots ya solo le preguntan a la criatura por el contrato, salvo lo que [DEVELOPMENT.md](DEVELOPMENT.md) deja dicho que sigue siendo de The Locust; el hotel juega igual. También el paso 0b: las teles y el código del hotel son manejadores de objetivo (`game/floors/objectives/`) y `host_gate()` los recorre. También el paso 0c: el tipo de piso se elige con `set_floor` y `--floor=N`, y el número de piso viaja en la sesión, en el punto de control y en la red (`floor`, versiones por piso, protocolo `the-four-net-21`). También el paso 0d: cada tabla de tipos de sala y cada constante de estructura del hotel viven en su paleta (`game/floors/palettes/hotel_palette.gd`), que el generador, el validador, la geometría y el juego leen con `FLOOR.palette(manifiesto)`, y una prueba de barrido falla si vuelve a aparecer un número de tipo suelto. También el paso 0f: la dificultad tiene las palancas propias de The Lurker encima de las compartidas (las ocho de la tabla de la sección 4 que tienen valor) y las reglas de la sala son de su criatura o de su piso (la embestida, el viaje por las teles y a plena vista, de The Locust; el apagón y el código, del hotel). También el paso 0e: `build_room()` se parte en pasos que se pueden sustituir (`floor_surface`, `ceiling`, `walls`, `fittings`, `room_lamp`, `extras`); `hotel.lit(sala)` junta el apagón, las salas oscuras, la corriente de la sala y su drenaje, y la cordura, los fantasmas y los bots le preguntan a ella; `ROOM_LAYERS.put_on_actor()` existe. Es el diseño que se sigue, y lo que no cuadre al jugarlo se cambia aquí.

- **Lo confirmado de la historia** está en [LORE.md](LORE.md). Lo que aquí es lore (los cuatro documentos, quién escribió qué) va como propuesta, y solo entra en LORE.md lo que el autor confirma.
- **Cuándo se hace cada fase**, en [PLAN.md](PLAN.md) (sección 5, `four-7ly.2`). El autor decide cuándo empezar según cómo vaya el desarrollo.
- **Los números** (velocidades, ventanas, presupuestos, relojes) son de partida: se afinan con bots y con gente.

**De dónde se parte** (comprobado en el código el 22 de octubre de 2026):

- El motor del hotel es reutilizable: rejilla, pasillos, refugio, ascensores, puertas, salas oscuras, zonas, contenedores, cuadros eléctricos, teclado, código y pistas.
- Pero está **cosido al hotel**:
  - los tipos de sala son números repartidos en unos ocho archivos;
  - `hotel_main` fija el tipo de piso, el generador y la geometría;
  - unos 22 scripts leen `level.locust` directamente;
  - la navegación es solo de suelo.
- **Encima de cada techo de 3,15 m quedan unos 2,35 m vacíos** hasta la planta de arriba: cabe un falso techo con su plénum y sus ductos sin tocar la separación de 6 m.
- **The Lurker existe solo como criatura que se ve**: modelo, esqueleto, ocho animaciones, la tinta y las manos que se agarran, y el banco «Pasillo del Lurker». No hay IA, ni sonidos, ni piso.

## 1. La idea del miedo: del «te persigue» al «te sigue»

En el hotel, The Locust **persigue**: se la oye, se corre, uno se esconde. En las oficinas, The Lurker **sigue**: nunca corre detrás de nadie, es más lenta que cualquier superviviente, y aun así es más peligrosa, porque **no se sabe dónde está y casi siempre está encima**.

### Tres pilares

1. **La sombra es suya.**
   - La oscuridad no esconde al jugador: lo expone.
   - La luz no es un arma: es terreno ganado.
   - Todo el piso es una negociación con las luces: dar la luz, que falle, que ella la beba.
2. **Lo que miras no avanza. Lo que alumbras huye.**
   - Mirada fija en una sala con luz, se queda quieta mirándote.
   - Con la linterna en la cara, retrocede de un salto (la animación `scare`) y se va a la oscuridad o a un ducto.
   - Si le das la espalda, avanza.
3. **Siempre hay algo encima.**
   - Falsos techos, ductos, placas que faltan, rejillas.
   - Nadie mira hacia arriba, y ella lo sabe.
   - El sonido de arriba es su presencia.

### El contrato con el jugador (reglas que se aprenden, nunca se rompen)

- **Antes de cogerte, siempre se oye detrás de ti**: el **aviso de la espalda**.
  - Es una exhalación húmeda y dos chasquidos de mandíbula, pegados a la nuca, en binaural.
  - Desde el aviso hay una **ventana para darte la vuelta**: 2,2 s en Apacible, 1,8 en Equilibrada, 1,5 en Desafiante y 1,2 en Pesadilla. En red se suma la latencia de quien la sufre.
  - Si en ese tiempo la tienes delante y la alumbras (o la sala tiene luz), se espanta. Si no, te coge.
  - Cumple «se la oye antes de verla» y «medio segundo limpio».
  - Con subtítulos, sale también como subtítulo.
- **No abre puertas.** Una puerta cerrada le corta el paso y la obliga a ir por los ductos. Cerrar puertas sirve, pero no salva.
- **Nunca coge a quien la está mirando en la luz**, ni a nadie en el vestíbulo del montacargas o dentro de él.
- **Las luces tiemblan cuando está cerca.** Su tinta bebe la luz: las lámparas de la sala bajan y suben **a la vez**, y el zumbido de los fluorescentes baja de tono.
  - Es distinto del tubo que falla solo, que parpadea a su aire.
- **Por los ductos se la oye y no se la ve.** El sonido sale por las rejillas, nunca a través de los muros.
- **Las alucinaciones no imitan nunca el aviso de la espalda** ni las luces que tiemblan juntas. Lo demás puede mentir.
- En cooperativo, **la linterna de un compañero también la espanta**. Cubrirse la espalda es la jugada del equipo.

### Por qué es más lenta y aun así da miedo

- Velocidades en el juego (escala 1,35): repta a ~1,35 m/s, se escabulle a ~3,5, en ducto va a ~0,75 y huye a ~2.
- Los supervivientes andan a 3,8. Huir de ella siempre es posible **si sabes dónde está**.
- El peligro está en **lo que obliga a dar la espalda**:
  - escribir la solicitud en la ventanilla;
  - recoger la ficha de una estación;
  - quedarse en el cuadro mientras los demás cruzan;
  - encender los ventiladores;
  - ir el último por el ducto;
  - leer un papel;
  - esconderse;
  - y la oscuridad, donde sin linterna no se le ve la cara.

### La escalada por plantas

| Planta | Qué es | Luz | Ella |
|---|---|---|---|
| 1 | **Personal**: la planta «presentable», con recepción interna, oficinas abiertas, cubículos, despachos acristalados, la ventanilla y el tubo neumático | **La luz se da**: casi toda encendida, salas oscuras ~23 % | Se presenta: se la oye en los ductos, asoma en los marcos, cruza un techo al borde de la vista, y sale en tu foto |
| 2 | **Registro y Archivo**: archivos con estanterías y pasillos de un metro, correo, microfichas, el cuarto eléctrico | **La luz se raciona**: corriente de emergencia y unas pocas zonas a la vez | Caza de verdad. Pasillos estrechos donde avanza **sostenida entre las dos estanterías** (la pose de la imagen, por fin en su sitio). Se la pastorea con la luz |
| 3 | **Dirección**: despachos con madera y moqueta, sala de juntas, puesto de seguridad y **la sala de climatización** | **No hay luz**: cierre de seguridad, sin corriente | En su casa. Los ventiladores la sacan a las salas, y el final es meterse en su ducto |

---

## 2. El lugar

### Qué eran (sin lore nuevo: solo lo que dice LORE.md)

- Las oficinas desde donde La Oficina **administraba y gestionaba** todo. Debajo del hotel, se baja a ellas.
- Se construyeron hacia los años 60, se reformaron a finales de los 70 y se abandonaron deprisa.
- La cámara fecha en 1990; el año de cada cosa sigue abierto en LORE.md.
- Burocracia de lo anómalo: expedientes, fichas, triplicados de papel carbón, sellos de CONFIDENCIAL, tubos neumáticos, teléfonos de disco y terminales de fósforo verde apagados.

### Las salas (catálogo propuesto)

| Sala | Tamaño | Luz | Qué tiene | Para ella |
|---|---|---|---|---|
| **Oficina abierta** | Salón (dos módulos o más) | Rejilla de fluorescentes; zonas apagadas | Mesas metálicas en filas, sillas, archivadores bajos | Techo largo de placas: se la oye correr por encima |
| **Cubículos** | Salón | Igual | Mamparas de tela de 1,5 m que cortan la vista: laberinto a la altura de los ojos | Se asoma por encima de una mampara; desde el techo ve todos los pasillos |
| **Despacho** | Módulo | Fluorescente o flexo en la mesa | Mesa, sillón, archivador, perchero, **cristalera con persiana al pasillo** | Su silueta pasa por detrás de las lamas |
| **Sala de juntas** | Módulo grande | Lámparas colgantes | Mesa larga, sillas, proyector, pizarra | El techo alto la deja colgar sobre la mesa |
| **Archivo** | Salón alargado | Tubos sueltos sobre los pasillos | **Estanterías de 2,1 m con pasillos de 1 m** | Su sitio: avanza sostenida entre las dos estanterías |
| **Archivo móvil** | Módulo | Igual | Estanterías sobre raíles con manivela: girarla abre un pasillo y hace ruido | Un pasillo que se abre y se cierra |
| **Correo** | Módulo | Fluorescente | Casilleros, carros, sacos y la central del tubo neumático | El tubo suena: no siempre es una cápsula |
| **Ventanilla de Personal** (planta 1) | Módulo | Fluorescente | Mostrador con cristal, máquina de escribir, el mapa de la red de tubos | Quien escribe le da la espalda a la sala |
| **Estación del tubo** (planta 1, en 8–14 salas) | En la pared | Su lucecita | Boca del tubo, bandeja y timbre | Se recoge de espaldas |
| **Cuarto eléctrico** (planta 2) | Módulo pequeño | Foco de emergencia | El cuadro general con sus palancas y la roja del montacargas | El más expuesto de la planta |
| **Reprografía y microfichas** | Módulo | Fluorescente | Fotocopiadora, lectores, cajas | |
| **Sala de descanso** | Módulo | Fluorescente | Máquina expendedora, fuente de agua, mesas, nevera | La máquina zumba: tapa el sonido |
| **Aseos y vestuario** | Módulo | Fluorescente | **Taquillas metálicas (escondite)** | Espera encima |
| **Sala de climatización** (planta 3) | Salón | Nada | Climatizadora, **ductos a escala humana**, la compuerta del ducto principal | Su nido |
| **Puesto de seguridad** (planta 3) | Módulo | La batería de seguridad | Mesa de control con monitores apagados, armero vacío; se abre con la ficha y desde aquí se encienden los ventiladores | |
| **Vestíbulo del montacargas** | Como el del ascensor del hotel | Siempre con luz (también en la 2) | El montacargas con reja; en la 1, su lector de fichas | Nunca entra |

- **Pasillos:** 2,2 a 3 m, con **franjas de color por departamento** pintadas en la pared a media altura. Orientan y dan identidad a cada zona sin un solo texto en pantalla.
- **Puertas:** del tamaño de las del hotel (2,65 m; decisión del autor: se prueban así), con ventanuco de vidrio armado. Las de servicio, metálicas con barra antipánico. Por eso el falso techo va a 2,95 m.
- **Una regla de construcción:** nada dentro de una sala pasa de 2,2 m (mamparas, estanterías, archivadores). Así **el techo de cada sala es un camino libre** para ella. Las cristaleras con persiana van solo en las paredes entre salas; los despachos son salas propias.

### Lo de arriba: el falso techo, el plénum y los ductos

- **Falso techo** a 2,95 m, por encima de las puertas del hotel: perfilería de aluminio y placas acústicas. Ya hay textura, `officeceiling001`. Debajo, entre 2,2 m (lo más alto de los muebles) y el techo, queda la franja por la que ella va.
- **El plénum**, entre el falso techo y la losa:
  - ductos rectangulares de chapa (troncos sobre los pasillos y ramales a las salas), bandejas de cables y tuberías;
  - solo se ve **donde faltan placas** (oscuridad con formas dentro) y en los pasillos de servicio sin falso techo, con los ductos a la vista;
  - el resto es oscuridad sin dibujar.
- **Rejillas** de 60 × 60 en el techo de cada sala: difusores de impulsión y rejillas de retorno. También algunas en la parte baja de la pared.
  - **Son sus puertas.** La rejilla doblada hacia fuera y las manchas negras alrededor dicen por dónde ha salido.
- **Placas que faltan, colgando o con manchas de agua:** las primeras plantas tienen pocas y las de abajo, muchas.
  - Una placa que se mueve, cruje en la perfilería y suelta un hilo de polvo **es ella arriba**.

### Escondites

- **Taquillas metálicas** (vestuarios, seguridad, despachos de servicio). Con la lógica de `hiding_place.gd` y otra piel. Ranura de lamas para mirar.
- **Con ella:**
  - no abre taquillas;
  - **espera encima**, en el techo, pegada, respirando por las lamas;
  - quien mira por la ranura puede verle la cara invertida a un palmo, sin peligro mientras no salga;
  - se cansa y se va; el aviso de que se ha ido es el ruido del ducto.
- **La cordura baja dentro**, como en el armario.

### Numeración y rótulos

- Cada sala con número por planta, como el hotel: 101 a 199, 201 a 299, 301 a 399, lo que el plano y las pistas ya saben leer.
- La placa lleva **la letra del departamento** (adoptado por el autor, por ahora): P-114 Personal, R-207 Registro, D-318 Dirección, S-322 Seguridad, M Mantenimiento.
- Rótulos de La Oficina: «ACCESO RESTRINGIDO», «PROHIBIDO EL PASO», «ARCHIVO CENTRAL», «SALIDA».
- Normas de seguridad en carteles de pared (ver 9). Sin «·» ni «—» en ningún texto.

---

## 3. Cómo se juega el piso: el correo, la corriente y el aire

### La idea

El hotel se juega en tres vueltas de un mismo ciclo: llegar, cumplir un encargo de una cuenta (salida, teles, código) y bajar. **Las oficinas no repiten ese ciclo.**

- **Cada planta es uno de los tres sistemas del edificio** (el correo, la corriente y el aire). Cada uno **cambia las reglas de la luz y del sonido**:
  - en la primera la luz **se da**;
  - en la segunda **se raciona**;
  - en la tercera **no hay**.
- **Lo que hay que hacer es distinto en su naturaleza:**
  - en la primera, un encargo personal que se sigue con el oído;
  - en la segunda, una estrategia compartida con la corriente;
  - en la tercera, una huida por su territorio.
- **Las tres juegan con su firma, la espalda**, cada vez más:
  - una foto tuya por detrás;
  - alguien de espaldas en el cuadro mientras los demás cruzan;
  - una fila de gente a gatas por un ducto, con el último mirando hacia atrás.
- **Un hilo las cose:**
  - La Oficina te procesa como a uno de los suyos: te da de alta, te asigna corriente, te encierra;
  - y al final te le escapas por donde vive ella.

**Lo que no cambia:**
- tres plantas, una debajo de otra (el motor y «se baja»);
- la cuota para pasar;
- los muertos vuelven entre plantas;
- la hoja y el plano.

**Lo que sí cambia:**
- no hay refugios que encontrar;
- no se cuentan objetos;
- no hay código;
- al llegar a cada planta, la tarjeta es la del montacargas de La Oficina: el nivel, el departamento y el encargo en dos o tres palabras («NIVEL 1» / «PERSONAL» / «PIDE TU FICHA»).

### Planta 1. Personal: el correo

**Cómo está:** la planta está **con luz**, tal como la dejaron a media jornada. Es la planta que la presenta.

**Llegar:** se llega en el ascensor del hotel, que aquí acaba, a la **recepción interna** de La Oficina.

**La salida es un montacargas** con reja y un **lector de fichas**: «SOLO PERSONAL REGISTRADO».
- Está escondido y hondo, colocado como el refugio del hotel (`place_refuge`, que no lo encuentra quien va con la mano en la pared).
- Para bajar hay que estar dado de alta.

**El encargo (cada uno el suyo):**
1. **Pedir tu ficha** en la ventanilla de Personal.
   - Se escribe la solicitud a máquina: sostener unos 5 s, **de espaldas a la sala**.
   - El tecleo se oye lejos, también ella.
   - Mientras escribes, **la cámara del techo te saca la foto de la ficha**: por detrás y desde arriba, como sacan las cámaras.
   - El resguardo dice adónde va: «ENVIADA A ESTACIÓN 7».
2. **Seguir la cápsula.**
   - La ficha viaja por el **tubo neumático**, por los techos y las paredes, hasta una de 8 a 14 estaciones repartidas por la planta.
   - Se sabe cuál de dos maneras:
     - leyendo el **mapa de la red** colgado junto a la ventanilla y el resguardo;
     - o **siguiendo el ruido** de la cápsula, un siseo que corre por encima y acaba en un timbre. La estación que la recibe enciende su lucecita.
   - Es el «gemelo amable» de su ruido en los ductos: se aprende a distinguirlos. La cápsula corre deprisa y acaba en timbre; ella va lenta y golpea.
3. **Recogerla** (la estación, contra la pared: otra vez de espaldas) y **leerla**.
   - La ficha lleva tu nombre, tu número y **la foto**: tu espalda en la ventanilla, hace unos minutos.
   - **Si ella estaba allí, sale en la foto**, porque la foto es el mundo de verdad renderizado en ese instante: una cara en una esquina del techo, detrás de ti.
   - Nadie la ha puesto ahí. Es información verdadera y es el susto de la planta.
4. **Pasarla por el lector** del montacargas.
   - Con las fichas de la cuota, se abre la reja.
   - La ficha queda en TUS NOTAS, con su foto, y **vuelve a servir abajo** (en Dirección).

**Por qué funciona con ella:**
- Cada uno va a una estación distinta, **así que el grupo se separa**, y ella va a por quien se queda solo.
- La planta enseña sus señales sin castigar demasiado:
  - las luces que tiemblan;
  - los ductos;
  - el primer aviso de la espalda, en la ventanilla.

**Alucinaciones de la planta:** cápsulas que corren y no llegan a ninguna estación; un teléfono que suena en un despacho.

### Planta 2. Registro y Archivo: la corriente

**Cómo está:** se llega en el montacargas a una planta **con la corriente de emergencia**.
- Solo hay focos ámbar de batería y carteles de salida.
- El vestíbulo tiene luz.
- Archivos de estanterías altas con pasillos de un metro, correo, microfichas.

**El grupo electrógeno da para poco.** En el **cuarto eléctrico** (hondo, entre el 40 y el 70 % del recorrido) está el **cuadro general**:
- una fila de palancas, **una por zona**, con el código de departamento pintado en las franjas de los pasillos (R-2 ARCHIVO, R-4 CORREO);
- y una más, roja: **MONTACARGAS**.

**La regla:**
- **Solo caben K zonas encendidas a la vez** (3 en Apacible y Equilibrada, 2 en Desafiante y Pesadilla).
- Subir una palanca de más **baja la más antigua**: se oye el chasquido y una zona entera se va a negro, que es justo donde ella va.
- **El MONTACARGAS se lo come todo:**
  - subirla apaga la planta entera salvo la emergencia y el vestíbulo;
  - arranca el **temporizador de arranque**, un reloj mecánico de 45 a 90 s que **se oye hacer tictac** en toda la planta;
  - el montacargas de bajada, al otro extremo (más allá del 80 %), solo baja **cuando el tictac acaba** y está dentro la cuota.

**Los minuteros:** en los pasillos hay **pulsadores de luz temporizada**, como los de las escaleras de toda la vida.
- Se pulsan y dan luz a ese pasillo 45–90 s, con su propio tictac, sin gastar del cuadro.
- Son la luz del que va solo.

**Cómo se juega:**
- **Cruzar la planta es encender un camino**:
  - ir al cuadro;
  - subir las zonas que llevan hacia el montacargas;
  - avanzar, bajar las de atrás, subir las de delante.
- En cooperativo, **alguien se queda en el cuadro**, que está contra la pared: el más expuesto. Los demás le dicen qué zona quieren.
- **Encender la zona en la que está ella la echa**: se va por los ductos a la oscuridad, y se oye adónde. Con la luz **se la pastorea**, sin poder encerrarla nunca, porque siempre queda algo a oscuras.
- **El final:**
  - todos junto al montacargas, menos quien sube la palanca roja;
  - con la planta a oscuras y el tictac corriendo, esa persona cruza sola de vuelta, con su linterna y los minuteros;
  - los del montacargas la esperan en lo protegido, oyendo el reloj.
  - En solitario, ese cruce es el clímax de la planta.

**Alucinaciones de la planta:** chasquidos de palanca que no han sido; un tictac donde no hay minutero.

### Planta 3. Dirección: el aire

**Cómo está:** Dirección está en **cierre de seguridad**.
- **No hay corriente**: es la planta más oscura, con moqueta (nadie se oye, tampoco ella), madera, despachos grandes, sala de juntas.
- No hay montacargas más abajo.
- **La única salida es el pozo de ventilación**, desde **la sala de climatización**: su nido.

**El encargo, en tres tiempos:**
1. **Encender la climatización desde el puesto de seguridad.**
   - Se abre con la ficha de la planta 1.
   - La batería de seguridad arranca los ventiladores **un rato** (60–90 s) y **tiene pocas cargas**: 2 en Apacible y Equilibrada, 1 en Desafiante y Pesadilla.
   - **Con los ventiladores en marcha:**
     - el aire **la echa de los ductos** y sale a las salas;
     - por primera vez está fuera, cazando con la vista en la oscuridad;
     - todo el edificio **ruge**: ella no oye a nadie, y nadie la oye ni a ella ni a los ductos.
   - **Se pierde la mejor señal**, y a cambio ella no puede seguir a nadie por el oído.
2. **Parar los ventiladores y abrir la compuerta del ducto principal** en la sala de climatización.
   - Con los ventiladores en marcha no se abre, por la presión.
   - Al pararlos **ella vuelve a los ductos**, y es una carrera por entrar antes.
3. **El ducto:**
   - 25 a 45 m de ducto de 1,2 m, **a gatas**, con codos y un cruce, hasta el pozo;
   - por detrás puede venir ella, porque es su casa;
   - quien va el último puede ir mirando hacia atrás, más despacio;
   - al llegar al pozo, una escalerilla hacia abajo: con la cuota en el pozo, se acaba el piso.

**Alguien estuvo antes** (confirmado: en todos los pisos hay restos de personas):
- en Dirección quedan las notas de quien intentó lo mismo;
- **en el ducto, sus restos**. No llegó.

**Alucinaciones de la planta:** ventiladores que arrancan y no han arrancado; golpes en un ducto con los ventiladores parados.

### Lo que esto pide al motor (detalle en la sección 11)

- **Para la red de tubos:** estaciones, máquina de escribir, lector de fichas.
- **Para la foto de la ficha:** la Polaroid del hotel, con el cuerpo del jugador visible para esa cámara.
- **Para la corriente:** el cuadro con presupuesto, los minuteros, la palanca del montacargas con reloj y la luz por zonas.
- **Para el aire:** la climatizadora (máscara de sonido y ductos cerrados para ella), la compuerta y **el ducto a gatas** del jugador.
- **Para todo el piso:** el montacargas con reja, que es el ascensor con otra piel.

---

## 4. The Lurker: cómo se comporta

### Sentidos (los suyos; el director nunca le dice dónde está nadie)

- **Ve en la oscuridad** a quien está a oscuras, hasta ~20 m, sin necesitar la linterna.
  - La luz la **ciega**: no ve dentro de las salas encendidas más allá de unos metros, ni a quien la alumbra.
- **Oye** con la cadena de ruidos de siempre (`noise_kinds`), y además oye a través de los ductos: lo que pasa junto a una rejilla le llega desde el otro extremo.
- **Elige presa**:
  - la primera persona que percibe, o la más sola y a oscuras;
  - la sigue con sus sentidos, sin trampas.
  - El director solo le da zonas, como a The Locust.

### Estados

| Estado | Qué hace | Cómo se nota |
|---|---|---|
| **Rondar** | Por ductos y plénum, de zona en zona (las del director o los ruidos) | Ducto que suena por encima, placas que crujen |
| **Escuchar** | Quieta en una rejilla | Silencio de pronto donde sonaba |
| **Acechar** | Sigue a su presa a 6–12 m, fuera de su vista: techos, paredes, salas oscuras, ductos | Tictac de garras en el techo; luces que tiemblan a su paso |
| **Asomarse** | En un marco, sobre una mampara o en una esquina del techo, al borde de la vista. Se va si se la mira más de un instante | Una cara pálida que no estaba (la animación `peek`) |
| **Quieta** | Vista en la luz: no se mueve y mira. Pasados unos segundos retrocede despacio (`retreat`) a lo oscuro | La cara, quieta |
| **Acercarse** | Presa a oscuras y de espaldas: se acerca por detrás o por arriba, a paso lento | Solo las garras, cada vez más cerca |
| **Aviso** | Detrás de ti, a 2–3 m, con la ventana de la dificultad | El aviso de la espalda |
| **Coger** | Ventana cumplida | La captura (sección 6) |
| **Espantarse** | La linterna en la cara, o vuelta a tiempo en la ventana: `scare` y huida por `crawl_fast` al ducto más cercano | Su chillido (no humano); golpe de cordura. Tarda en volver a por la misma presa |
| **Encima** | Sobre la taquilla de alguien escondido | Respiración por las lamas |

### La luz, de los dos lados

- **Bebe la luz**: a menos de ~3 m de una lámpara, la lámpara baja al 30–60 % y vuelve cuando se aleja.
  - Las de una misma sala bajan juntas, el zumbido cae de tono y los tubos titilan.
  - Es su señal más clara y la que la hace visible por donde pasa.
- **En una sala con luz no coge** a quien la tiene a la vista, pero puede cruzarla por el techo, deprisa, si nadie mira hacia arriba.
- **La linterna** sigue sin batería.
  - Es la única luz que se lleva, y el arma contra el aviso de la espalda: una vuelta a tiempo, con la linterna encendida, la espanta.
  - Con la linterna apagada y a oscuras, la vuelta a tiempo no basta: hay que alumbrarla.
  - Llevarla encendida baja menos la cordura, pero **la delata** (ella oye el clic y ve el haz desde lejos).

### Ductos

- **Una red real** (sección 11): entra y sale por rejillas y placas que faltan.
  - Por dentro va más deprisa que reptando: de 1,2 a 2,4 m/s según la dificultad.
  - La animación de ducto solo se ve cuando asoma.
  - Los ductos siguen la rejilla de la planta, no las puertas: **dan atajos**, sin ser teletransportes.
- **Nunca llega a los vestíbulos del montacargas**, ni pasa por encima. Allí no se oye nada.
- En la planta 3 **el ducto principal es suyo también**: por él viene detrás de quien huye.
- **Entre plantas no usa el ascensor**: baja por los ductos, sin que nadie la vea.
  - Llega a la planta nueva tras el tiempo que tardaría y aparece lejos del vestíbulo.
  - Si baja a la vez que ellos, **se la oye arañar por fuera del coche** durante el viaje. Solo es sonido; nunca entra en la cabina.

### En cooperativo

- Va a por el que se queda atrás.
- Dos que se cubren la espalda son casi intocables; separados, cada uno es una presa.
- **Los muertos** miran por la cámara de un compañero, como ahora, y desde ahí ven lo que el vivo no ve: la cara en el techo detrás de él.

### El director, adaptado

- **Mismas reglas:** zonas, nunca posiciones.
- **El encuentro garantizado** (cruzarse con quien lleva mucho sin señales) pasa a ser **un asomo o un cruce de techo al borde de la vista**.
- **El descanso** después de un susto o una muerte se respeta igual.
- **Lo de «menace»** (cuánto de cerca está) mide también la distancia por los ductos.

### Dificultad (claves propias, a afinar jugando)

| Clave | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| Ventana de la espalda | 2,2 s | 1,8 s | 1,5 s | 1,2 s |
| Coge en una sala con luz (de espaldas, tras el aviso) | No | Sí | Sí | Sí |
| Velocidad en los ductos | 1,2 m/s | 1,6 m/s | 2,0 m/s | 2,4 m/s |
| Distancia de acecho | 12 m | 10 m | 8 m | 6 m |
| Tiempo quieta en la luz antes de irse | 2 s | 3 s | 4 s | 6 s |
| Calma tras espantarse | 60 s | 45 s | 35 s | 25 s |
| Velocidad al acercarse | ×0,8 | ×0,9 | ×1 | ×1,15 |
| Lámpara que bebe | 3 m | 3 m | 3,5 m | 4 m |
| Asomos al borde de la vista | Muchos | Muchos | Normales | Pocos |

En Apacible, más asomos y menos capturas: miedo sin castigo.

---

## 5. Alucinaciones: el piso que miente

Con la cordura de siempre (oculta, local, solo en la máquina de cada uno), pero con contenido de ella y **más frecuentes**: cada 40–90 s por debajo de 60, frente a 1,5–3 min en el hotel. LORE.md dice «mucha alucinación».

**Mienten (todas grabadas, nada sintetizado):**
- Garras en el techo encima de ti, y una placa que suelta polvo sin que haya nada.
- Golpes que viajan por un ducto vacío.
- **Una cara al borde de la vista**: en el marco de una puerta a oscuras, sobre una mampara o en una esquina del techo. Se va al mirarla (`phantom_sight`, con el modelo del Lurker y la pose `peek`).
- **El piso hace oficina**:
  - un teléfono que suena en una mesa y calla al acercarse;
  - unas teclas de máquina de escribir;
  - el tubo neumático;
  - una fotocopiadora que arranca;
  - una silla de ruedas que rueda sola.
- La sombra de algo que pasa por detrás de una persiana.
- Una sola lámpara que tiembla. Nunca la sala entera.

- Las propias de cada planta (cápsulas que no llegan, palancas y tictacs que no son, ventiladores que no arrancan): en la sección 3.

**Nunca mienten:**
- el aviso de la espalda (decisión del autor: nada de avisos falsos, por ahora);
- las luces de una sala temblando juntas;
- la interfaz, la hoja ni el plano;
- el timbre de una estación con su luz, el tictac del montacargas ni los ventiladores de verdad.

Así lo que se aprende sigue sirviendo.

El autor aprueba que vayan **por encima del tope del hotel**.

---

## 6. La captura

Con lo que ya funciona (`executions.gd`, `death_tape.gd`, `capture_score.gd`, `camera_fall.gd`, `blood.gd`) y los principios de EXECUTION.md: causa sí, impacto no; medio segundo limpio; nunca dos iguales; lo que no se anima bien no se enseña.

- **Por la espalda** (la principal):
  1. Dos manos enormes entran por los lados de la imagen y se cierran sobre los hombros.
  2. La cámara gira con quien la lleva y la cara aparece **del revés**, colgando del techo, a un palmo de la lente. Los ojos negros, quietos.
  3. **Tira hacia arriba**: la imagen sube hacia la oscuridad del techo.
  4. La cámara se suelta, cae al suelo y queda mirando hacia arriba: el techo, una placa que se balancea, y después el golpe del cuerpo fuera de cuadro y **la sangre** (`blood.gd`).
- **Desde arriba** (en una sala de techo alto o en el archivo): baja del techo delante de quien no ha mirado hacia arriba, y lo mismo.
- **El cuerpo queda en el suelo** (decisión del autor; se puede revisar más adelante).
  - Lo levanta hacia el techo y lo suelta: la cámara ya ha caído y se oye el cuerpo detrás.
  - Al revivir entre plantas, como siempre, vuelve.
- **La cinta del que muere** encuadra su cara (el equivalente de `mask_transform()`).

---

## 7. Versus: ser The Lurker

- **Su vista**:
  - **la oscuridad es su luz**: ve lo oscuro en grises granulosos;
  - lo encendido **la quema**: blanco, sin detalle, con un sonido que molesta;
  - la linterna de un superviviente es un fogonazo que la ciega si la mira.
  - Ve a quien sus sentidos le dan (`sees()`), como el eco de The Locust.
- **Se mueve por cualquier superficie** (suelo, pared, techo, saltando de una a otra) y **entra en los ductos** por las rejillas. Dentro, un plano esquemático de la red y salidas marcadas.
- **Habilidades:**
  - **Beber la luz**: apaga una sala ~6 s; espera ~25 s.
  - **Asomarse**: un susto que baja la cordura de quien la ve.
  - **Coger**: solo desde detrás de alguien. Lanza el aviso de la espalda y la presa tiene su ventana, la misma que con la IA. Ninguna regla cambia por llevarla una persona.
- **Con los sistemas de cada planta:**
  - en la 2, no toca el cuadro, pero bebe la luz de las zonas encendidas;
  - en la 3, los ventiladores también la echan de los ductos cuando la lleva una persona, y el ruido le quita el oído.
- Gana y pierde como ahora: CAZA COMPLETA o SE TE ESCAPARON.

---

## 8. Dirección de arte

- **Época y tono:**
  - modernismo institucional feo, 1965 a 1980;
  - beige, verde oliva, mostaza, marrón de chapa de madera, gris acero;
  - luz **fría y plana**, 4.000–4.500 K. Es lo contrario del hotel, cálido, con moqueta y papel pintado: al bajar se nota.
- **Materiales:**
  - suelo de losetas vinílicas (beige con motas) y terrazo en vestíbulos;
  - bloque de hormigón pintado;
  - paneles de chapa de madera en Dirección, moqueta en losetas en los despachos de Dirección;
  - placas acústicas con perfilería de aluminio;
  - vidrio armado y mamparas de acero con persianas venecianas;
  - tela de mampara;
  - chapa galvanizada en los ductos;
  - corcho en los tablones.
- **Luz:**
  - pantallas de fluorescentes 60 × 120 con difusor prismático;
  - focos de emergencia con batería;
  - carteles de salida;
  - flexos cálidos en algunas mesas: islas cálidas en lo frío;
  - nada de monitores encendidos (las pantallas son de otra criatura pensada, The Boiled One).
- **Abandono:**
  - papeles por el suelo, sillas volcadas, cajones abiertos, abrigos en perchas, tazas;
  - placas caídas, cables colgando, manchas de agua;
  - un expediente a medio sellar: se fueron deprisa.
- **Su rastro:**
  - rejillas dobladas hacia fuera, manchas de tinta negra seca alrededor;
  - **arañazos en lo alto de las paredes y en las placas**, en grupos de siete.
- **El papel de La Oficina:** lo proponen los agentes (el autor lo rediseña después si hace falta).
  - Se hornea con Python, como la tarjeta de no molestar (`tools/textures/bake_oficina_forms.py`).
  - **Memorándum interno:**
    - papel verde agua pálido, con dos taladros de archivo a la izquierda;
    - el sello de La Oficina arriba (un cuadrado partido en cuatro, sobrio y sin texto);
    - casillas DE, PARA, ASUNTO, REF. y FECHA, y un recuadro para el sello de entrada;
    - abajo, la marca de copia: ORIGINAL, COPIA o ARCHIVO.
  - **Ficha de personal:**
    - cartulina beige, perforada por arriba;
    - recuadro de foto a la izquierda, con la foto pegada torcida;
    - casillas de NOMBRE, NÚMERO, DEPARTAMENTO, ALTA y NIVEL DE ACCESO, y una banda roja de «PROVISIONAL».
  - **Resguardo del tubo:** una tira de papel térmico con el número de estación.
  - Todo a máquina, con el sistema del impreso del hotel (`hotel_form.gd`), y su versión de lejos para verlo en el mundo.
- **La cámara sigue siendo la cinta:** lo frío del piso se ve a través del mismo vídeo de 1990.

---

## 9. Dirección de audio

- **Ambiente:**
  - la climatización respirando en el plénum (un rumor grave que va y viene);
  - zumbido de fluorescente más frío que el del hotel;
  - chapa de ductos que cruje al enfriarse;
  - goteo;
  - el zumbido del cuadro;
  - **silencio seco en los archivos** (el papel se lo come todo).
- **Pasos:** las losetas suenan más (el ruido llega más lejos). La moqueta de Dirección los apaga: allí se oye menos a todos, también a ella.
- **Ella:**
  - garra en placa (toque blando y crujido de perfilería);
  - garra en ducto (golpe de chapa con resonancia);
  - garra en pared (tictac);
  - respiración húmeda y lenta;
  - chasquido de mandíbula (hueso);
  - el **aviso de la espalda**;
  - el **chillido al espantarse**: animal, nunca humano.
  - Todo **grabado**: foley y animales con licencia, procesados. Nada de voces ni gritos humanos sintéticos.
- **Por dónde suena:** por las rutas y por los ductos, saliendo por las rejillas. Nada atraviesa muros (AUDIO.md).
- **La música sigue al miedo**, como ahora, con su propio color si el autor lo quiere.
- **Carteles de normas** (diegéticos, se leen; no son interfaz). Enseñan las reglas sin decirlas:
  - «MANTENGA ENCENDIDAS LAS LUCES DE LOS PASILLOS»
  - «NO TRABAJE DE ESPALDAS A LA PUERTA»
  - «NO SE QUEDE SOLO EN EL ARCHIVO»
  - «LAS REJILLAS NO SE ABREN»

---

## 10. Papeles

- **Documentos de lore (4 de The Lurker).** Al autor le interesan y se retocan después. Al formalizarlos, **cada uno con su narrativa**: quién lo escribe, a quién, qué le pasó antes y qué deja entrever sin decirlo. Nada va a LORE.md sin su sí.
  1. **Parte de mantenimiento:** tercera vez este mes que suenan los ductos de la R-214, y se pide sellar la rejilla. La respuesta, al pie y a mano: no.
  2. **Circular interna:** recuerda al personal mantener encendidas las luces y no quedarse solo en el archivo, «por la seguridad de todos». No dice de qué.
  3. **Libro del puesto de seguridad:** «Cámara 4, techo del archivo. Algo se mueve en la imagen. En la cinta no hay nada.»
  4. **Informe médico de un empleado:** dice ver una cara en el techo de su despacho y pide el traslado. Denegado.
  - Escritos por gente que **sí sabía** lo que había debajo, al revés que los del hotel. Es una inferencia, no lore confirmado.
- **Los papeles del juego:**
  - el resguardo del tubo y **la ficha de personal**, con su foto (planta 1);
  - el mapa de la red de tubos;
  - la leyenda del cuadro con las zonas (planta 2);
  - las instrucciones de la climatización en el puesto de seguridad (planta 3).

  Todos diegéticos: se leen en el mundo, nada en pantalla.
- **Alguien estuvo antes** (confirmado por el autor: en todos los pisos hay restos de personas):
  - en la planta 3, sus notas: quien intentó salir por el aire y lo apuntó;
  - en el ducto, sus restos;
  - y en el resto del piso, **restos del personal** donde los dejó la brecha.
  - Quién era sigue abierto en LORE.md.
- Los documentos siguen la regla del hotel: dos por piso, como mucho uno por planta. El paso a 24 documentos con cuatro por piso sigue en PLAN.md.

---

## 11. Dirección técnica

### 11.1 El contrato de criatura (el piso 1 no cambia)

- **Problema:** no hay interfaz de criatura. Unos 22 scripts leen `level.locust` y comparan sus `Mode` con listas sueltas, distintas en cada sitio:
  - `pacing_director.gd:233`, `dread_aura.gd:155`, `lifts.gd:177/205/251`, `match_net.gd:463`, `phantom_sight.gd:98`;
  - el mismo código de teletransporte está tres veces: `lifts.apply_locust_ride`, `televisions.warp_creature` y `revival`.
- **Clase base:** `game/enemies/creature.gd` (`extends CharacterBody3D`), no un adaptador, para que sigan valiendo `get_rid()`, `global_position` y las señales. `hotel_locust.gd` solo cambia su `extends`.
- **El contrato:**

| Grupo | Qué tiene |
|---|---|
| Identidad y control | `kind_id()`, `set_control()` y `control`, `grace`, `rng` (su azar), `tune()`, `can(&"lifts"/&"tv_travel"/&"ducts"/&"wardrobes"/&"shriek"/&"echo")` |
| Estado | `activity()` con nombres en vez de `Mode`, y en la base los predicados `is_hostile()`, `is_hunting()`, `is_chasing()`, `is_engaged()`, `is_roaming()`, `is_wary()` y `alarm_level()` |
| Sentidos | `eye_point()`, `face_point()`, `gaze()`, `sees()`, `hear()`, `hear_route()`, `watched()`, `quarry()` (a quién tiene en mente), `saw_enter()` (vio a alguien meterse en un escondite) |
| Director | `lead_to()`, `investigate()`, `dull`, `searched_lately()` (en The Locust, su `searched_until`), `noticing()`, `travel_metres()` (con ductos), `in_transit()` |
| Movimiento | `teleport()` (único, y lo que suelta según el motivo), `relocate()` (olvidar a todos y esperar), `search_from()`, `follow_to_planta()`, `den_point()`, `save_state()`, `restore_state()` |
| Red | `pack_state()`, `push_state()`, `play_call()`, `resume_state()` (su cazador vuelve), `validate_strike()` (en el anfitrión) |
| Su cazador (versus) | `sense_scale()` (lo que la embestida estira sus sentidos), `hunter_reveal()` y `hunter_contact()` (lo que se le enseña), `hunter_gone()` (la máquina la retoma), `apply_quality()` (su vista) |
| Captura | `capture_style()` (estrategia), `begin_capture()`, `end_capture()`, `capture_length()`, `wardrobe_steps()` (los tiempos de abrir un escondite) |
| Audio | `sound_route(listener)`, `presence_route(listener)`, `hushed()` |
| Mente | `hallucinations()`: su juego de mentiras |
| Observador | `debug_lines()`, `debug_state()`, `draw_gizmos()` |

- **Alias permanente** en `hotel_main.gd`: `var creature` y `locust` como propiedad que la devuelve, con el patrón de delegados que ya usa el archivo (líneas 1683–1866). `spawn_creature()` instancia `kind.CREATURE`.
- **El director separa dos distancias:**
  - `walk()`: de un superviviente a una sala, por puertas;
  - `reach()`: de la criatura a alguien, con ductos.
- **Orden de migración, un commit por paso, todo en verde:**
  1. base y alias;
  2. director;
  3. aura y audio;
  4. cordura y fantasmas;
  5. ascensores;
  6. teles;
  7. reaparición y guardado;
  8. capturas;
  9. red (mismos nombres de RPC);
  10. observador;
  11. bots (un modelo de amenaza por criatura).

### 11.2 El tipo de piso seleccionable

- **El script de tipo** (`hotel_floor.gd` y el nuevo `office_floor.gd`) suma:
  - `GENERATOR`, `VALIDATOR`, `GEOMETRY`, `PALETTE`, `CREATURE`, `CREATURE_KEY`;
  - `OBJECTIVES` (sus manejadores), `PAPERS` (el juego de pistas) y `GENERATOR_VERSION`.
  - `floor_index.KINDS = {1: hotel, 2: office}`.
- **Paletas** (`game/floors/palettes/hotel_palette.gd`, `office_palette.gd`):
  - se llevan todos los números de tipo de sala y las constantes de estructura que hoy están en `floor_definition`, `map_generator`, `map_validator`, `hotel_geometry`, `room_dressing`, `prop_factory`, `world_audio`, `blood`, `code_lock` y `hint_placement`;
  - preguntas en vez de listas: `hard_floor()`, `may_be_dark()`, `lamp_of()`, `height_of()`, `label()`...;
  - los papeles estructurales conservan su número en las dos paletas: 0 inicio, 9 rellano, 10 vestíbulo, 11 pasillo, 12 galería, 19 refugio, 20 vacío.
- **El hotel queda idéntico:**
  - el manifiesto del hotel no lleva la clave `floor`;
  - una prueba «dorada» compara el manifiesto de ~50 semillas antes y después;
  - otra prueba falla si vuelve a aparecer un número de tipo suelto fuera de las paletas.
- **El número de piso viaja:**
  - `game_session` (`stages` y el punto de control);
  - la configuración de red (`floor`), el registro (versiones por piso) y `PROTOCOL` subido;
  - `--floor=N` para pruebas y herramientas.
- **Objetivos como manejadores** (`game/floors/objectives/`). Cada uno tiene:
  - `settle()` (antes de construir);
  - `place()`, `progress()`, `goal_points()` (para el director y los bots);
  - `tick()`, `snapshot()` y `restore()`.

  `host_gate()` deja de ser un `switch` y recorre los de la planta.
  - Del hotel: televisores y código.
  - Del piso 2: **fichas** (`files_objective.gd`), **corriente** (`power_objective.gd`) y **aire** (`air_objective.gd`).
  - La «salida» de cada planta (refugio en el hotel, montacargas o pozo aquí) también es un manejador, con la cuota de siempre.
- **Dificultad y reglas por criatura:**
  - `CREATURE_PROFILES[&"lurker"]` añade sus claves y sus ajustes del director;
  - los rasgos del menú y las reglas de sala se filtran por la criatura del piso.

### 11.3 El generador y la geometría de las oficinas

- **`office_generator.gd`:**
  - el motor de rejilla del hotel con la paleta de oficinas (módulos de 8 a 12 m, pasillos de 2,4 a 3 m);
  - su propio `finish()`: tipos, falso techo a 2,95, taquillas en vez de armarios, muebles;
  - y lo de cada planta:
    - en la 1, la ventanilla, las estaciones y la red de tubos;
    - en la 2, el cuarto eléctrico y las zonas de circuito;
    - en la 3, el puesto de seguridad, la sala de climatización, el ducto principal y el pozo;
    - el montacargas, colocado como el refugio del hotel;
  - genera la red de **ductos** y los **pasillos de archivo** en el manifiesto, que la huella de red ya compara.
- **Ductos en el manifiesto:**
  - `plenum {ceiling, slab, duct_y}`;
  - `ducts {nodes, edges, exits}`, siguiendo la rejilla de la planta: troncos sobre los pasillos, un ramal por sala y lazos sueltos (p ≈ 0,3);
  - una rejilla por sala, apartada de la lámpara, y placas que faltan en el 3–6 % de las celdas;
  - nada sobre refugios, vestíbulos ni la salida (`off_limits_rooms()`).
- **`office_validator.gd`:**
  - la red de cada planta es conexa;
  - toda sala se alcanza con todas las puertas cerradas (solo ductos);
  - los atajos quedan en una banda (0,55–0,9 del camino por puertas);
  - pasillos de archivo de 0,95 m o más.

  Y en físico: rayos desde cada salida, barridos por los pasillos de archivo. **Mil semillas** con `tools/dev/office_metrics.gd`.
- **`office_geometry.gd`**, que hereda de `hotel_geometry`. Antes, `build_room()` se parte en pasos que se pueden sustituir. Añade:
  - la perfilería y las placas del falso techo (MultiMesh);
  - pantallas de fluorescentes con el perfil `tube`;
  - rejillas, placas que faltan y el plénum (solo se dibuja lo que se ve por un hueco);
  - cristaleras con persiana; las puertas, las del hotel;
  - los muebles de oficina (`room_dressing`, con su juego `office` ampliado).
- **Luz por sala** (en el hotel también):
  - `hotel.lit(room)`: hay corriente, no es oscura y no la está bebiendo;
  - `set_room_power()` y `drain()` (bajar la energía de una lámpara);
  - reemplazan las lecturas sueltas de `hotel.dark` y `dark_ids` en la cordura, los fantasmas y los bots.
- **Navegación de los jugadores:** la del hotel con radio 0,3, para que los pasillos de archivo entren en la malla del audio y los bots.

### 11.4 Cómo se mueve ella

- **No usa la malla de navegación del suelo.**
- **Grafo de rutas** (`lurker_routes.gd`):
  - salas, puertas abiertas y salidas de ducto, con A*;
  - salas con luz, caras; circuitos con corriente, carísimos; refugios, nunca;
  - si se cierra una puerta en su ruta, vuelve a planear.
- **Su «cáscara»** (`lurker_shell.gd`): dentro de cada sala se mueve por **parches analíticos**:
  - el techo (rectángulo);
  - los **canales** (pasillos de archivo y pasos de menos de 1,6 m, donde va sostenida entre las dos paredes: la sección del banco de pruebas generalizada);
  - las franjas de dintel de cada puerta;
  - con costuras redondeadas.

  Su estado es (parche, u, v, rumbo, cuelgue) y se convierte en la transformación que ya entiende `lurker_visual` (+Y la superficie, +Z hacia dónde va).
- **Cinemática, sin gravedad ni cápsula.** Un rayo hacia abajo cada 0,25 s ajusta lo que cuelga; las manos tienen sus propios rayos.
- **Grafo de ductos** (`duct_graph.gd`):
  - Dijkstra, salidas más cercanas, rutas de audio;
  - mismo en todas las máquinas, porque sale del manifiesto.

### 11.5 Sentidos y cerebro

- **`creature_sight.gd`** (compartido). Saca de The Locust:
  - `watched()`;
  - `torch_covers()` (sin el mínimo de 5 m, a la cara);
  - `regards()`: cámara a menos de 30° (45° en remotos), rayo libre y luz en la sala o linterna en la cara;
  - `beside_view()`.
- **`lurker_brain.gd`:** los estados de la sección 4.
  - Solo se mueve por un tramo si nadie la tiene **expuesta**: mirada y con luz o linterna.
  - A oscuras y sin linterna, aunque la miren, avanza: nadie la ve.
- **La garantía del aviso, en código.** Una captura solo sale de `CUE`:
  - con la misma víctima y tras la ventana más la latencia;
  - si en cualquier fotograma de la ventana la víctima la mira con luz, o la linterna de alguien le da en la cara, pasa a espantarse;
  - el aviso va por RPC fiable a la máquina de la víctima y suena en su posición real, en binaural;
  - cada captura guarda su par aviso→captura, y una comprobación del contrato exige que exista.

### 11.6 Red, captura, versus, cordura, bots

- **Red:**
  - el estado empaquetado lleva la **orientación entera** (cuaternión) y banderas: en ducto, oculta, superficie, bebiendo luz, avisando;
  - eventos fiables: aviso, fin de aviso, espanto, entrar y salir de ducto, circuito dado, sala apagada (versus);
  - el invitado puede reclamar «la estaba mirando» y el anfitrión lo acepta si su propia comprobación coincide con margen.
- **Captura:**
  - `executions.gd` conserva la orquestación;
  - la coreografía pasa a estrategias:
    - `capture_styles/locust_capture.gd`: lo de hoy, movido sin cambios;
    - `capture_styles/lurker_capture.gd`: «levantar y soltar». Deja el cuerpo en el suelo, `camera_fall` prefiere quedar mirando hacia arriba y `death_tape` encuadra su cara del revés;
  - la puntuación de la escena tiene sus tiempos propios.
- **Versus:**
  - `lurker_player.gd` (moverse por el parche actual; contra una pared o un techo, se sube);
  - entrar en un ducto abre el mapa de ductos, reutilizando la brújula de canales de las teles;
  - `lurker_view.gd`: su vista, con exposición alta, sin color, grano y brillo que quema lo encendido;
  - peticiones validadas en el anfitrión: coger (siempre con su ventana), ducto, apagar una sala;
  - `--lurker` para probarlo en local.
- **Cordura:** `creature.hallucinations()` sustituye lo que hoy está fijo en `sanity.gd`. Las de The Locust se mudan sin cambios; las de The Lurker, las de la sección 5.
- **Bots:**
  - `bot_threat_lurker.gd`: reaccionan al aviso con un retraso según su pericia, llevan la linterna a oscuras, se cubren en cooperativo;
  - el vigilante de bots comprueba en cada partida que toda captura tuvo su aviso.

### 11.7 Los sistemas de cada planta

- **Una red de conductos genérica** (`conduit_graph.gd`) para los ductos de ella y los tubos neumáticos.
  - Mismo manifiesto, mismo Dijkstra, misma ruta de audio que sale por las bocas.
  - La cápsula es una fuente de sonido que recorre su camino a velocidad fija.
- **Planta 1:**
  - `typewriter_desk.gd` (sostener para escribir, ruido de tecleo con su radio);
  - `tube_station.gd` (timbre, lucecita, bandeja; se recoge como un documento);
  - `card_reader.gd` (pasa la ficha; cuenta la cuota).
  - **La foto de la ficha:** `code_lock.develop_photo()` generalizado a `photo_desk.gd`.
    - Una cámara en una esquina del techo detrás de la ventanilla.
    - El cuerpo del jugador visible para ella: incluir su capa de render en la máscara de esa cámara.
    - Se saca **en el momento de escribir**, así que si ella está, sale.
    - Se guarda con la ficha, en TUS NOTAS, y se ve igual en todas las máquinas: cada una saca la de su propio jugador y la envía al resto como textura pequeña, o cada máquina la saca con el avatar remoto (a decidir al hacerlo, midiendo).
- **Planta 2:**
  - `main_board.gd`: palancas por zona, presupuesto K, la que sobra baja la más antigua; la roja con su reloj.
  - `timer_switch.gd`: minutero con tictac.
  - La luz por zonas con `set_room_power()`; las zonas son los `sector` del manifiesto.
  - El montacargas de bajada solo arranca con la roja cumplida.
  - Todo pasa por el anfitrión y se reparte como el estado de las teles.
- **Planta 3:**
  - `air_handler.gd`: cargas, tiempo en marcha.
    - Con los ventiladores en marcha: ruido de toda la planta que tapa sonidos (el oído de ella y el de todos baja con un factor); `conduit_graph` cerrado para ella, que sale por la boca más cercana.
  - `duct_hatch.gd`: se abre solo con los ventiladores parados.
  - **El ducto a gatas del jugador:**
    - geometría de ducto de 1,2 m con colisión;
    - el jugador agachado cabe (comprobar la altura de agachado de `player.tscn`);
    - mirar atrás va más lento;
    - al llegar al pozo, la escalerilla es una interacción que acaba el piso.
- **El montacargas:** `lifts.gd` con otra piel (reja de tijera que se ve pasar por el hueco, luz de jaula).
  - Si ella baja a la vez, sus garras se oyen fuera de la reja.

### 11.8 Rendimiento (detalle de la sección 13)

- **Tinta:**
  - ruido de una textura 3D de 64³ (5 lecturas por paso en vez de ~40 hashes);
  - pasos por calidad: 10, 8, 6, 5, 4;
  - salida temprana con alfa > 0,98;
  - sin capa de vapor en Bajo y Muy bajo;
  - más allá de 15 m, una capa y 4 pasos;
  - nada en un ducto ni en otra planta.
  - Escenario propio en `hotel_benchmark.gd` a 1,5, 4 y 10 m en todas las calidades.
- **Manos:** sin rayos fuera de pantalla o a más de 18 m; un sondeo por fotograma entre 8 y 18 m; completas a menos de 8.
- **Muy bajo:** `ROOM_LAYERS.put_on_actor()` lleva su cara, ojos y dientes a la capa de la sala en que está. La tinta no recibe luz y se queda en su capa.
- **Beber la luz:** un parámetro por instancia en la pantalla de la sala. Sin materiales nuevos ni luces nuevas.

---

## 12. Obtención de assets (autónoma, autorizada por el autor)

El autor autoriza (22 de octubre de 2026) que **los agentes busquen y descarguen por su cuenta** modelos, materiales, texturas, audio y lo que haga falta para el piso 2, con su criterio, en cualquier plataforma cuya licencia lo permita. Lo que no quede bien se ajusta después.

**Licencias:**
- CC0 o dominio público primero.
- Luego **CC BY**, con crédito en ASSETS.md y en los créditos del juego (`hotel_ui.gd`, `CREDITS`).
- Luego licencias libres de regalías que permitan uso comercial sin atribución (Sonniss GDC, Pixabay).
- **Nunca** NC (no comercial), ND (sin derivadas) ni SA (compartir igual). La meta es poder vender el juego, y hoy el único NC es The Locust.

**Fuentes:**
- **Sin cuenta:** Poly Haven (modelos, texturas y HDRI CC0), ambientCG (materiales CC0), Kenney y Quaternius (CC0), OpenGameArt (filtrando licencia), Sonniss GDC (lotes de audio).
- **Con cuenta:** Sketchfab (filtro «descargable» y licencia CC BY o CC0) y Freesound (CC0 y CC BY).
  - Solo con la sesión del autor ya abierta en su Chrome. **No se crean cuentas ni se escriben contraseñas**: si algo pide iniciar sesión, se le deja el enlace al autor.

**Criterio de selección:**
- Época (nada posterior a 1990) y escala real.
- PBR completo.
- Presupuesto de triángulos: un mueble pequeño menos de 5 k, uno grande menos de 20 k; si no, se diezma.
- Sin marcas, logos ni textos en otro idioma (por eso se descartaron el extintor y el teléfono coreanos).
- Audio grabado, limpio y sin música; 44,1 o 48 kHz.

**Cómo se trae cada uno:**
1. Se descarga a su propia carpeta nueva en `source_assets/<fuente>/<nombre>/`, fuera de git y sin ejecutar nada de lo descargado.
2. Se mira antes de usarlo: la página de su licencia y el archivo.
3. Pasa por las herramientas que ya existen:
   - `tools/props/ingest_models.py` y `build_catalogue.gd` para modelos;
   - `tools/textures/ingest_pbr.py` para materiales;
   - los `prepare_*.py` de audio.
4. Queda registrado en ASSETS.md (fuente, autor, licencia, enlace), en `docs/asset_hashes.json` y, si es CC BY, en los créditos.
5. Se ve en el catálogo de capturas y en el banco del piso antes de darlo por bueno.

**La lista de lo que hace falta:**

| Tipo | Qué |
|---|---|
| Modelos | Mesa metálica de oficina (ya en `source_assets`, `metal_office_desk`), sillas de oficina, archivadores de 2 y 4 cajones, fichero de fichas, estanterías de archivo, archivo móvil con manivela, mamparas de cubículo, mesa de juntas, perchero, taquillas metálicas, **máquina de escribir**, teléfono de disco, terminal y fotocopiadora (apagadas), lector de microfichas, **estación y tubos neumáticos**, **lector de fichas**, **cuadro general de palancas**, **pulsador de minutero**, máquina expendedora, fuente de agua, carros de correo, casilleros, pantalla de fluorescente, foco de emergencia, rejilla de techo, ductos (`modular_airduct_rectangular_01` ya está) y **ducto grande con compuerta**, bandejas de cables, **climatizadora y ventiladores**, **montacargas con reja de tijera**, **escalerilla de pozo**, restos humanos (huesos y ropa, sin gore explícito) |
| Materiales | Loseta vinílica, terrazo, bloque de hormigón pintado, chapa de madera, moqueta en losetas, tela de mampara, vidrio armado, chapa galvanizada, corcho, losa de hormigón del plénum, cartulina y papel térmico |
| Audio | Climatizadora en bucle y **ventiladores a pleno**, zumbido de fluorescente frío, chapa que cruje, golpes y arrastres en ducto, garras en placa, pared y metal, polvo que cae, placa que se mueve, chasquidos de hueso, respiración animal húmeda, chillido animal, teléfono antiguo, **máquina de escribir**, **tubo neumático (siseo, cápsula que corre, timbre)**, **palancas y diferenciales**, **reloj mecánico (tictac)**, fotocopiadora, máquina expendedora, puertas metálicas con barra, taquillas, persianas venecianas, fluorescente que arranca, **reja de montacargas y motor**, escalerilla metálica, gatear sobre chapa |

---

## 13. Rendimiento

- **Medir antes de nada lo que cuesta ella en partida:**
  - la tinta hace unas 100 evaluaciones de ruido por píxel cubierto;
  - las manos lanzan unos 22 rayos por fotograma, más los codos.
- **Presupuesto:** 60 FPS a 1080p en Alto, como el hotel.
- **En las calidades bajas:**
  - menos pasos en la tinta;
  - manos con menos rayos o cada dos fotogramas;
  - **la cara en la capa de luz de la sala en que está**, para que en Muy bajo se le vea la cara igual. Ninguna calidad da ventaja.
- **Más cosas que medir:**
  - el falso techo como MultiMesh, igual que el resto;
  - el plénum solo se dibuja donde falta una placa;
  - las luces que bebe son las mismas de la sala, sin luces nuevas;
  - probarlo en Compatibilidad.

---

## 14. Decisiones del autor (22 de octubre de 2026) y lo que queda abierto

**Decidido:**

| # | Pregunta | Decisión |
|---|---|---|
| 1 | Lo que pide cada planta | No repetir el ciclo del hotel. Rehecho: sección 3, el correo, la corriente y el aire |
| 2 | ¿Alguien estuvo antes? | **Sí: siempre hay restos de personas en todos los pisos** (va a LORE.md) |
| 3 | El cuerpo | Se queda en el suelo, por ahora |
| 4 | Documentos de lore | Interesantes; se retocan después, cada uno con buena narrativa al formalizarlos |
| 5 | Numeración con letra de departamento | Se adopta por ahora |
| 6 | Más alucinaciones que en el hotel | Sí |
| 7 | El impreso de La Oficina | Lo proponen los agentes (sección 8); el autor lo rediseña si hace falta |
| 8 | Adelantar lo que no toca el piso 1 | Se decide más adelante, según cómo vaya el desarrollo |
| 9 | Puertas | Las del hotel; falso techo a 2,95 m |
| 10 | Coger de espaldas en una sala con luz | Sí, tras el aviso (salvo en Apacible) |
| 11 | Avisos de espalda falsos | No, por ahora |
| 12 | Cómo se llega | **Se continúa desde el piso 1.** Una vez desbloqueado, se puede elegir, **en la dificultad en que se desbloqueó** |
| 13 | La llave de los cuadros | No hay en el piso 2 |

**Abierto, menor** (se resuelve al hacerlo, salvo que el autor diga otra cosa):
- La foto de la ficha en red: si cada máquina saca la suya y la envía, o si cada una la saca con el avatar remoto.
- Las cifras de cada planta: estaciones, presupuesto K, relojes, cargas de los ventiladores y largo del ducto. Se afinan con bots y con gente.

---

## 15. Fases y verificación

Cada fase termina con:
- `tools/verify.ps1` entero;
- los escenarios de red;
- un lote de bots con semillas fijas comparado con el anterior.

**El piso 1 sigue idéntico en todo momento.**

### Lo que se puede adelantar sin tocar el piso 1

- **A. Assets** (sección 12): búsqueda, descarga, ingesta y catálogo de capturas.
- **B. Banco del Lurker:** cáscara, ductos y cerebro sobre una oficina fija hecha a mano.

### Fase 0: cimientos (refactor, el hotel no se mueve ni un byte)

| Paso | Qué | Verificación nueva |
|---|---|---|
| 0a | Contrato de criatura y alias (11.1) | `hotel/creature_contract_test`: tabla de verdad de cada predicado contra las listas de `Mode` que sustituye; ida y vuelta del estado; el teletransporte limpia lo mismo que las tres copias |
| 0b | Objetivos como manejadores | `objectives_test` (nueva), `stages_test`, `rules_test`, `continue_test`, `bots_test`, red `late` |
| 0c | Tipo de piso seleccionable, número de piso en sesión, punto de control y red | `continue_test` con un punto de control del formato viejo |
| 0d | Paletas | `hotel/manifest_golden_test` (~50 semillas y la 404), prueba de números sueltos, `light_layers_scan`, comparación de capturas de salas |
| 0e | Pasos de `build_room`, `hotel.lit()`, `set_room_power()`, `drain()`, `put_on_actor()` | Pruebas de luces de `hotel_test`, recorrido de calidades, `darkness_capture` |
| 0f | Dificultad y reglas por criatura | `difficulty_test`, `rules_test` |

### Fase 1: las oficinas, sin ella

Se juega contra una criatura nula (`null_creature.gd`), que cumple el contrato y no coge a nadie: así también se prueba el contrato.
- **Construcción:** paleta, generador, validador y geometría de oficinas.
- **Los sistemas de cada planta** (11.7):
  - planta 1: tubos, ventanilla, estaciones, lector y la foto de la ficha;
  - planta 2: cuadro, minuteros y la roja del montacargas;
  - planta 3: climatizadora, compuerta, ducto a gatas y pozo;
  - el montacargas con reja;
  - el impreso de La Oficina y la ficha.
- **Verificación:**
  - `office/office_test` (40 semillas en manifiesto, 3 en físico, alcance de la malla y de los pasillos de archivo; red de tubos conexa; cuarto eléctrico, sala de climatización y pozo alcanzables);
  - `office/office_stages_test`:
    - planta 1: pedir, seguir y leer la ficha, y pasarla por el lector con la cuota;
    - planta 2: el presupuesto baja la zona más antigua; la roja apaga la planta, el reloj corre y el montacargas solo baja al acabar;
    - planta 3: sin cargas no hay ventiladores, con ventiladores no se abre la compuerta, el ducto llega al pozo;
  - `office_metrics` con mil semillas (aparte, a demanda);
  - `light_layers_scan` en el piso 2;
  - red `office_coop`;
  - `bots_test --floor=2`;
  - capturas en `tools/capture/office_capture.gd` (salas, pasillo, archivo, el plénum por un hueco; Muy bajo y Compatibilidad).

### Fase 2: su cerebro, en un banco

- **Archivos:** `lurker.gd`, `lurker_shell.gd`, `duct_graph.gd`, `lurker_routes.gd`, `lurker_senses.gd`, `lurker_brain.gd` y `creature_sight.gd`.
- **Banco** `tools/workbenches/lurker_arena`: una oficina fija, con superposición de estado, cronómetro del aviso, ruta y ducto, y teclas para forzar estados (`./tools/godot.ps1 lurker-arena`).
- **Verificación:**
  - `office/lurker_shell_test` (continuidad, costuras);
  - **`office/lurker_fairness_test`**:
    - de espaldas a oscuras: aviso, captura y ventana cumplida en las cuatro dificultades;
    - darse la vuelta con linterna a falta de 0,3 s: sin captura y espanto;
    - la linterna de un compañero: sin captura;
    - vestíbulo del montacargas y dentro de él: nunca aviso;
    - 200 aproximaciones con semilla: toda captura con su aviso.
  - `office/lurker_senses_test`;
  - `dev/lurker_route_probe` (viajes terminados, sin saltos fuera de los declarados, nunca dentro de una sala vedada).

### Fase 3: el piso 2 jugable en solitario

- **Qué se conecta:**
  - ella en el piso, el director con sus claves;
  - el temblor de las luces, el pastoreo con las zonas, la máscara de los ventiladores, las alucinaciones;
  - el audio de ductos y tubos y el aura, la captura de levantar y soltar;
  - la sangre, el guardado (fichas, zonas, cargas);
  - los gizmos del observador (ductos, cáscara, aviso).
- **Verificación:** `office_survival_test`, `office_capture_test`, `body_clip_probe --floor=2`, `office_audio_test` (lo que sale de un ducto suena en la rejilla; fuera de alcance no se oye), `sanity_test --floor=2` y un lote de equilibrio con bots (muertes, avisos, salvadas, espantos).

### Fase 4: en red y versus

- Estado y eventos, latencia, reincorporación y protocolo.
- `lurker_player`, `lurker_view`, el mapa de ductos y las habilidades.
- **Verificación:** red `office_versus` y `office_late`, capturas del cazador.

### Fase 5: acabado

- **Rendimiento medido otra vez:** tinta con textura 3D y por calidad, Compatibilidad, Muy bajo.
- **Mezcla:** del bus de ductos y de las alucinaciones.
- **Dificultad:** medida con bots y luego **con gente**, que es lo que cierra el piso.
- **Contenido:**
  - hitos y logros del piso 2, documentos de lore confirmados;
  - **la continuación desde el piso 1**: la cinta del hotel acaba y el ascensor sigue bajando hasta la recepción de La Oficina;
  - el desbloqueo para elegirlo después en su dificultad (es parte de `four-7ly.10`, la campaña).
- **Documentos:** LURKER, GAME_DESIGN, DIFFICULTY, PERFORMANCE, DEVELOPMENT, ASSETS y CHANGELOG, con versión nueva.
