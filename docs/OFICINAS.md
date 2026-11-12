# Piso 2: las oficinas secretas

La hoja de dirección del segundo piso: cómo se juega, cómo asusta, cómo se ve y cómo suena, y cómo se construye. **La aprobó el autor el 22 de octubre de 2026**, con sus decisiones (sección 14). **Del piso en sí está construido lo que cuenta la sección 11** (el generador con sus sistemas de planta, los muebles de cada sala según su receta y las piezas hechas en código, y The Lurker con su cerebro), sin publicar (`--floor=2` lo juega). Cómo va cada fase y el rediseño visual está en `.claude/relevo.md`. **De la fase 0 está hecho el paso 0a**, el contrato de criatura (sección 11.1), con sus once migraciones: el director, el aura, el audio, la cordura y sus fantasmas, los ascensores, las teles, la reaparición, el piso guardado, la captura, la red, el observador y los bots ya solo le preguntan a la criatura por el contrato, salvo lo que [DEVELOPMENT.md](DEVELOPMENT.md) deja dicho que sigue siendo de The Locust; el hotel juega igual. También el paso 0b: las teles y el código del hotel son manejadores de objetivo (`game/floors/objectives/`) y `host_gate()` los recorre. También el paso 0c: el tipo de piso se elige con `set_floor` y `--floor=N`, y el número de piso viaja en la sesión, en el punto de control y en la red (`floor`, versiones por piso, protocolo `the-four-net-21`). También el paso 0d: cada tabla de tipos de sala y cada constante de estructura del hotel viven en su paleta (`game/floors/palettes/hotel_palette.gd`), que el generador, el validador, la geometría y el juego leen con `FLOOR.palette(manifiesto)`, y una prueba de barrido falla si vuelve a aparecer un número de tipo suelto. También el paso 0f: la dificultad tiene las palancas propias de The Lurker encima de las compartidas (las ocho de la tabla de la sección 4 que tienen valor) y las reglas de la sala son de su criatura o de su piso (la embestida, el viaje por las teles y a plena vista, de The Locust; el apagón y el código, del hotel). También el paso 0e: `build_room()` se parte en pasos que se pueden sustituir (`floor_surface`, `ceiling`, `walls`, `fittings`, `room_lamp`, `extras`); `hotel.lit(sala)` junta el apagón, las salas oscuras, la corriente de la sala y su drenaje, y la cordura, los fantasmas y los bots le preguntan a ella; `ROOM_LAYERS.put_on_actor()` existe. Y el paso 1a: el tipo de piso 2 en `floor_index.KINDS`, sin publicar (`RELEASED` solo tiene el piso 1); su paleta (`game/floors/palettes/office_palette.gd`); la criatura nula (`game/enemies/null_creature.gd`); y el generador y el validador mínimos, que son los del hotel con esa paleta y sacan manifiestos de piso 2. Es el diseño que se sigue, y lo que no cuadre al jugarlo se cambia aquí.

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

En el hotel, The Locust **persigue**: se la oye, se corre, uno se esconde. En las oficinas, The Lurker **sigue**: nunca corre detrás de nadie, a la vista es más lenta que cualquier superviviente, y aun así es más peligrosa, porque **no se sabe dónde está y casi siempre está encima**. Lo que miras no avanza; lo que no miras, vuela (la nota de la reconstrucción del 11 de noviembre de 2026, `.claude/specs/spec_lurker_rebuild.md`).

### Tres pilares

1. **La sombra es suya.**
   - La oscuridad no esconde al jugador: lo expone.
   - La luz no es un arma: es terreno ganado.
   - Todo el piso es una negociación con las luces: dar la luz, que falle, que ella la beba.
2. **Lo que miras no avanza. Lo que alumbras huye.**
   - Vista sin que se le distinga la cara, sigue, pero a ráfagas: quieta, una carrera corta, quieta otra vez, siempre más despacio que quien anda.
   - Mirada con luz (la de la sala o la linterna) o alumbrada, desaparece: sale disparada al techo y en menos de 0,4 s ya no está. Ya no se queda quieta mirándote ni retrocede despacio.
   - Con la linterna en la cara, además chilla, y la linterna queda bebida (abajo).
   - Si le das la espalda, avanza.
3. **Siempre hay algo encima.**
   - Falsos techos, ductos, placas que faltan, rejillas.
   - Nadie mira hacia arriba, y ella lo sabe.
   - El sonido de arriba es su presencia.

### El contrato con el jugador (reglas que se aprenden, nunca se rompen)

- **Antes de cogerte, siempre se oye detrás de ti**: el **aviso de la espalda**.
  - Es una exhalación húmeda y dos chasquidos de mandíbula, pegados a la nuca, en binaural.
  - Desde el aviso hay una **ventana para darte la vuelta**: 2,2 s en Apacible, 1,5 en Equilibrada, 0,9 en Desafiante y en Pesadilla (sección 4, «Dificultad»; no baja de 0,9 porque su aviso corto tiene que oírse entero). En red se suma la latencia de quien la sufre. Con menos de 1,2 s hasta la toma suena un aviso más corto, para que se oiga entero.
  - Si en ese tiempo la tienes delante y la alumbras (o la sala tiene luz), se espanta. Si no, te coge. **Una linterna que ella ha bebido no cuenta** (abajo).
  - Cumple «se la oye antes de verla» y «medio segundo limpio».
  - Con subtítulos, sale también como subtítulo.
- **No abre puertas.** Una puerta cerrada le corta el paso y la obliga a ir por los ductos. Cerrar puertas sirve, pero no salva.
- **Nunca coge a quien la está mirando en la luz**, ni a nadie en el vestíbulo del montacargas o dentro de él.
- **Las luces tiemblan cuando está cerca.** Su tinta bebe la luz: las lámparas de la sala bajan y suben **a la vez**, y el zumbido de los fluorescentes baja de tono.
  - Es distinto del tubo que falla solo, que parpadea a su aire.
  - **Puede beberse la sala entera** (de Equilibrada para arriba): si acecha a alguien en una sala con luz el tiempo de su dificultad, la deja a oscuras, y **a oscuras para todas las reglas**, mientras le dure el encuentro allí. Nunca un vestíbulo protegido ni una sala que no puede estar a oscuras.
- **La linterna ya no salva siempre** (de Equilibrada para arriba). La que la espanta queda **bebida** unos segundos: el haz baja al 15 % y titila, y vuelve en el último segundo. A veces se **apaga del todo** y no vuelve hasta apagarla y encenderla (encendida antes de que acabe la bebida, solo chispea). Mientras tanto no la espanta, no sirve para distinguirle la cara y no salva del aviso. Siguen salvando la luz de la sala, la linterna de un compañero y alejarse corriendo.
- **Por los ductos se la oye y no se la ve.** El sonido sale por las rejillas, nunca a través de los muros.
- **Las alucinaciones no imitan nunca el aviso de la espalda** ni las luces que tiemblan juntas. Lo demás puede mentir.
- En cooperativo, **la linterna de un compañero también la espanta** (si no es una que ella ha bebido). Cubrirse la espalda es la jugada del equipo.

### Lenta a la vista, rápida donde no se la mira

- Los supervivientes andan a 3,8 m/s y corren a 6.
- **Vista** (alguien la tiene en su campo de visión), por una superficie va **a ráfagas**: quieta de 0,3 a 0,7 s y una carrera de 0,45 a 0,85 s a 3,3 m/s, unos 1,8 m/s de media.
- **Sin que nadie la vea**, por una superficie va de 3 a 5 m/s según la dificultad, y por un ducto oculto, de 3 a 5,8. Así ronda, acecha, vuelve y llega a sus emboscadas.
- **Al acercarse por tu espalda** va a tu paso más 0,6 m/s, con un tope de 3 a 5 m/s según la dificultad: en Apacible y Equilibrada basta con andar para dejarla atrás; en Desafiante y Pesadilla hay que correr, y correr hace ruido. **Nunca alcanza a quien corre.**
- **En el ducto principal**, el de tamaño humano, va a 1 m/s en todas.
- **Alumbrada**, entra en el techo en 0,3 s, de 8 a 40 m/s.
- Huir de ella siempre es posible **si sabes dónde está**.
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
| 3 | **Dirección**: despachos con madera y alfombras, sala de juntas, puesto de seguridad y **la sala de climatización** | **No hay luz**: cierre de seguridad, sin corriente | En su casa. Los ventiladores la sacan a las salas, y el final es meterse en su ducto |

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
| **Oficina abierta** | Salón de dos o tres módulos. En la planta 1, además, una nave de oficina abierta o de cubículos: un bloque de 2 × 2 o 2 × 3 módulos con un pasillo central de 3 m sobre la junta de sus dos filas y, donde caben, columnas exentas de 60 cm a los lados, a 2,1 m de su eje (si no cabe el bloque, una fila de tres a cinco módulos o una L de cuatro o cinco, sin columnas) | Rejilla de fluorescentes; zonas apagadas | Mesas metálicas en filas, sillas, archivadores bajos | Techo largo de placas: se la oye correr por encima; rodea las columnas |
| **Cubículos** | Salón de dos o tres módulos, o la nave de la planta 1 | Igual | Mamparas de tela de 1,5 m que cortan la vista: laberinto a la altura de los ojos | Se asoma por encima de una mampara; desde el techo ve todos los pasillos |
| **Despacho** | Módulo | Fluorescente o flexo en la mesa | Mesa, sillón, archivador, perchero, **cristalera con persiana al pasillo** | Su silueta pasa por detrás de las lamas |
| **Sala de juntas** | Módulo grande | Fluorescentes empotrados en el falso techo a 2,95 m, como los despachos | Mesa larga, sillas, proyector, pizarra | |
| **Archivo** | Salón alargado | Tubos sueltos sobre los pasillos | **Estanterías de 2,1 m con pasillos de 1 m** | Su sitio: avanza sostenida entre las dos estanterías |
| **Archivo móvil** | Módulo | Igual | Estanterías sobre raíles con manivela: girarla abre un pasillo y hace ruido | Un pasillo que se abre y se cierra |
| **Correo** | Módulo | Fluorescente | Casilleros, carros, sacos y una segunda central del tubo neumático, decorativa y sin función (4c) | El tubo suena: no siempre es una cápsula |
| **Ventanilla de Personal** (planta 1) | Módulo | Fluorescente | Mostrador con cristal, máquina de escribir, el mapa de la red de tubos y la central neumática de la que nacen los tubos | Quien escribe le da la espalda a la sala |
| **Estación del tubo** (planta 1, en 8–14 salas) | En la pared | Su lucecita | Boca del tubo, bandeja y timbre | Se recoge de espaldas |
| **Cuarto eléctrico** (planta 2) | Módulo pequeño | Foco de emergencia | El cuadro general con sus palancas y la roja del montacargas | El más expuesto de la planta |
| **Reprografía y microfichas** | Módulo | Fluorescente | Fotocopiadora, lectores, cajas | |
| **Sala de descanso** | Módulo | Fluorescente | Máquina expendedora, fuente de agua, mesas, nevera | La máquina zumba: tapa el sonido |
| **Aseos y vestuario** | Módulo | Fluorescente | **Taquillas metálicas (escondite)** | Espera encima |
| **Sala de climatización** (planta 3) | Salón | Nada | Climatizadora, **ductos a escala humana**, la compuerta del ducto principal | Su nido |
| **Puesto de seguridad** (planta 3) | Módulo | La batería de seguridad | Mesa de control con monitores apagados, armero vacío; se abre con la ficha y desde aquí se encienden los ventiladores; como un despacho, puede tener una cristalera a un pasillo, de vidrio armado y sin persiana | |
| **Vestíbulo del montacargas** | Como el del ascensor del hotel | Siempre con luz (también en la 2) | El montacargas con reja; en la 1, su lector de fichas | Nunca entra |

- **Pasillos:** de 3 a 3,6 m (alguno de 2,4), con un friso de dos tonos igual en todos (arrimadero de roble color miel hasta 1 m bajo una moldura de nogal, greige encima) y, en cada celda de pasillo, un rótulo negro de letras claras a 1,6 m con el nombre de su zona y un cuadradito del color de su departamento.
- **Puertas:** del tamaño de las del hotel (2,65 m; decisión del autor: se prueban así): hoja de roble color miel con manilla de latón en marco de nogal, algunas con un ventanuco estrecho de vidrio claro. Las de servicio y las de etapa, de acero verde gris con barra antipánico. Por eso el falso techo va a 2,95 m.
- **El pasillo central de una nave queda libre:** ni muebles ni piezas de esquina dentro (el validador lo mira, `nave_aisle_`). Los anillos de la planta no cuentan las costuras dentro de una nave: un bloque de módulos abierto no es una vuelta.
- **Una regla de construcción:** nada dentro de una sala pasa de 2,2 m (mamparas, estanterías, archivadores). Así **el techo de cada sala es un camino libre** para ella. Solo las columnas de las naves de la planta 1 suben hasta el techo, y ella las rodea. Excepción: lo plano contra la pared (0,2 m de fondo o menos y sin colisión, como el cuadro eléctrico y sus conducciones) puede pasar de 2,2 m y no quita placas al techo. Las cristaleras con persiana van solo en las paredes entre salas; los despachos son salas propias.

### Lo de arriba: el falso techo, el plénum y los ductos

- **Falso techo** a 2,95 m, por encima de las puertas del hotel: perfilería de aluminio y placas acústicas. Ya hay textura, `officeceiling001`. Debajo, entre 2,2 m (lo más alto de los muebles) y el techo, queda la franja por la que ella va. En las naves de la planta 1 la cortan las columnas.
- **El plénum**, entre el falso techo y la losa:
  - ductos rectangulares de chapa (troncos sobre los pasillos y ramales a las salas), bandejas de cables y tuberías;
  - solo se ve **donde faltan placas** (oscuridad con formas dentro) y en los pasillos de servicio sin falso techo, con los ductos a la vista;
  - el resto es oscuridad sin dibujar.
- **Rejillas** de 60 × 60 en el techo de cada sala: difusores de impulsión y rejillas de retorno. También algunas en la parte baja de la pared.
  - **Son sus puertas.** La rejilla doblada hacia fuera y las manchas negras alrededor dicen por dónde ha salido.
- **Placas que faltan, colgando o con manchas de agua:** las primeras plantas tienen pocas y las de abajo, muchas.
  - Una placa que se mueve, cruje en la perfilería y suelta un hilo de polvo **es ella arriba**.
- **Cualquier placa entera es también su puerta** (el autor, 24 de octubre de 2026): menos las de las lámparas, las que tienen el centro de una lámpara a menos de 0,9 m y, fuera de los pasillos, las que tienen una pared a menos de 1 m, y las que tienen el centro a menos de 0,6 m de una columna. En las salas prohibidas, ninguna.
  - Para salir la empuja desde arriba con una mano y la deja **colgando a medio abrir** (60°) sobre su hueco oscuro. Una placa abierta dice por dónde ha salido.
  - Si vuelve a entrar por esa placa, la cierra tras de sí. Si entra por una cerrada, la levanta hacia el plénum y la placa cae cerrada.
  - Cada placa que mueve llega a todas las máquinas por el evento de la criatura (paso 3e); falta verlo en una partida en red.

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
   - Con las fichas de la cuota, se abre la puerta de la etapa.
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
- una fila de palancas, **una por zona**, con el código que llevan los rótulos de zona de los pasillos (R-2 ARCHIVO, R-4 CORREO);
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
- **No hay corriente**: es la planta más oscura, con alfombras (nadie se oye, tampoco ella), madera, despachos grandes, sala de juntas.
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
- **Elige presa** entre quienes percibe (nunca alguien en una sala protegida, escondido, en su descanso o junto a su última captura):
  - por cuánto está solo (35 %), a oscuras (25 %), rezagado del centro del grupo (20 %) y ocupado (20 %: leyendo, usando algo o quieto 2 s); los empates, a suertes;
  - mientras acecha, cambia a otra si puntúa claramente más;
  - **la guarda por memoria**, no por vista: dónde la vio u oyó por última vez, hacia dónde iba y a qué paso. Pasados 12 s sin señal la pierde, y la busca donde la vio por última vez (nunca donde está de verdad).
  - El director solo le da zonas, como a The Locust (salvo el encuentro forzado, abajo).

### Estados

Cada estado tiene un tiempo máximo y una salida, y nunca se queda quieta por miedo a que la vean: si alguien vigila con luz el camino que tiene por delante, va por el plénum. Un solo vigilante (`lurker_brain.watch_progress`): si pide moverse y en 6 s no avanza medio metro, prueba el otro camino (superficies o plénum); si vuelve a pasar, deja a su presa y vuelve a rondar por otra sala.

| Estado | Qué hace | Cómo se nota |
|---|---|---|
| **Rondar** | Siempre en marcha, deprisa si nadie la ve. Su meta: un ruido nuevo (pasado el tiempo de reacción de su dificultad, aunque fuera a otro sitio), la zona del director, cerca de donde supo de alguien por última vez (una parte de las veces según la dificultad, por el plénum) o su patrulla. Al llegar, la mitad de las veces escucha | Golpes de ducto en tandas, más seguidas cuanto más cerca |
| **Escuchar** | Quieta en una rejilla de 3 a 6 s, oyendo más lejos | Nada |
| **Acechar** | Sigue a su presa a la distancia de su dificultad, fuera de su cono de vista (120 grados alrededor de hacia dónde va): un techo o una pared detrás de ella, a oscuras si puede, en su sala o en una vecina. Dura el tiempo de su dificultad (menos con más supervivientes) y se corta antes si hay **ocasión**: la presa quieta 2 s, ocupada, o sola, a oscuras y de espaldas. A veces se asoma una vez | Garras en el techo y la pared; luces que tiemblan; por el plénum, tandas cortas y silencios largos |
| **Asomarse** | Va a un punto al borde de la vista de alguien y mira hasta 4 s. Vista 0,1 s, desaparece (sin contar intento) y vuelve más tarde. Si nadie la ve, en Desafiante y Pesadilla encadena el silencio; en las demás, vuelve a acechar | Una cara pálida que no estaba (la animación `peek`) |
| **Silencio** | Quieta y callada del todo donde está, los segundos de su dificultad; si la presa echa a andar, se acerca enseguida, y si se aleja más de 4 m sobre su distancia de acecho, vuelve a acechar | Lo que sonaba se calla de pronto |
| **Acercarse** | Al punto del aviso, 2,4 m detrás de la presa, a su paso más 0,6 m/s con el tope de su dificultad. Si la presa se gira, rodea hasta su espalda; solo tras 5 s sin lograrlo vuelve a acechar | Solo sus garras, fuertes aunque vaya despacio |
| **Aviso** | Detrás de ti, de 2 a 5 m, con la ventana de la dificultad | El aviso de la espalda |
| **Coger** | Ventana cumplida | La captura (sección 6) |
| **Espantarse** | La linterna en la cara (una que no haya bebido), o vuelta a tiempo en la ventana: chilla, bebe esa linterna y sale disparada | Su chillido (no humano); golpe de cordura |
| **Huir** | Al techo por la entrada más cercana lejos de la luz (la placa de encima, una rejilla, un hueco), de modo que esté dentro en 0,3 s; si no hay ninguna a mano o a los 0,4 s sigue fuera, entra donde esté. Mirada con luz, alumbrada o con la luz de la sala encendida, huye igual, sin chillar | Golpes rápidos que se alejan |
| **Volver** | Tras un intento fallido, espera en el techo el tiempo de su dificultad (cada fallo lo acorta: ×0,7, ×0,5, ×0,4), sale cerca de donde sabe que está la presa (o de quien esté más solo cerca de ella) y vuelve a acechar, más corto | Callada en el techo; solo cruje la placa o la rejilla por la que sale |
| **Emboscada** | A veces, con la presa andando (1 m/s o más), en vez de seguirla va por el plénum a un techo oscuro de 8 a 14 m por delante de ella, fuera de su vista, sale y espera quieta hasta 12 s. Avisa desde ahí cuando pasa por debajo o la deja atrás. Si la presa se aleja 16 m del punto, se esconde o no llega en 10 s, vuelve a acechar; una emboscada fallida no cuenta como intento | Nada hasta el aviso |
| **Encima** | Sobre la taquilla de alguien escondido, de 20 a 40 s; si sale, se acerca | Una placa arrastrada al llegar; respiración por las lamas |

El estado **Quieta** ya no se usa: solo lo ponen a mano las herramientas.

### La luz, de los dos lados

- **Bebe la luz**: a menos de la distancia de su dificultad (de 3 a 4,5 m) de una lámpara, la lámpara baja al 30–60 % y vuelve cuando se aleja.
  - Las de una misma sala bajan juntas, el zumbido cae de tono y los tubos titilan.
  - Es su señal más clara y la que la hace visible por donde pasa.
  - Este drenaje no deja la sala a oscuras para las reglas.
- **Se bebe la sala entera** (de Equilibrada para arriba; `lurker.snuff_step()`): si acecha a alguien que está en una sala con luz el tiempo de su dificultad seguido (12 s en Equilibrada, 4 en Desafiante, 2,5 en Pesadilla), la apaga temblando en unos segundos, y **queda a oscuras para las reglas** (`hotel.lit()`). La devuelve en un segundo cuando acaba su encuentro allí, cuando la presa lleva 3 s fuera de la sala o a los 25 s, y no vuelve a beberse la misma en 45 s. Solo salas que pueden estar a oscuras, ni protegidas ni prohibidas. Que la devuelva no la espanta, como sí lo hace que alguien encienda la luz.
- **En una sala con luz no coge** a quien la tiene a la vista, pero puede cruzarla por el techo, deprisa, si nadie mira hacia arriba. Sus emboscadas, nunca bajo un techo con luz.
- **La linterna** sigue sin batería.
  - Es la única luz que se lleva, y el arma contra el aviso de la espalda: una vuelta a tiempo, con la linterna encendida, la espanta.
  - Con la linterna apagada y a oscuras, la vuelta a tiempo no basta: hay que alumbrarla.
  - Llevarla encendida baja menos la cordura, pero **la delata** (ella oye el clic y ve el haz desde 35 m).
  - **Ella la bebe** (`lurker.drink_torches()`): cada vez que una linterna la espanta, las que tenía en la cara quedan bebidas los segundos de su dificultad (nunca en Apacible): el haz al 15 % con un parpadeo irregular, de vuelta en rampa el último segundo, con un clic donde está. Con una probabilidad de su dificultad, **se apaga del todo** y no vuelve hasta que su dueño la apaga y la enciende (encendida antes de que acabe la bebida, solo chispea un instante). Una linterna bebida o apagada no la espanta, no sirve para distinguirle la cara (quien la lleva solo se la ve con la luz de la sala o a 1,2 m) y no salva del aviso.

### Ductos

- **Una red real** (sección 11): entra y sale por rejillas, placas que faltan y cualquier placa entera.
  - El plénum de cada sala con falso techo se une al ducto de la sala y al plénum de las salas con las que tiene puerta o lado abierto. Por él va a la velocidad de los ductos ocultos.
  - Se mete en el techo por la placa que tiene encima, o por la que dejó abierta si está a menos de 2,5 m, y sale por la placa más cercana a donde va.
  - Por una placa cerrada no entra ni sale el sonido, y desde el plénum no ve nada.
  - Por dentro va más deprisa que reptando: de 1,2 a 2,8 m/s según la dificultad, y sin que nadie la vea, de 3 a 5,8.
  - **En el ducto principal, el de tamaño humano, va a 1 m/s en todas las dificultades** (decisión del autor, 23 de octubre): un superviviente repta a 1,2, así que huir de ella por él siempre es posible.
  - La animación de ducto solo se ve cuando asoma.
  - Los ductos siguen la rejilla de la planta, no las puertas: **dan atajos**, sin ser teletransportes.
- **Nunca llega a los vestíbulos del montacargas**, ni pasa por encima. Allí no se oye nada.
- En la planta 3 **el ducto principal es suyo también**: por él viene detrás de quien huye.
- **Entre plantas no usa el ascensor**: baja por los ductos, sin que nadie la vea.
  - Llega a la planta nueva tras el tiempo que tardaría y aparece lejos del vestíbulo.
  - Si baja a la vez que ellos, **se la oye arañar por fuera del coche** durante el viaje. Solo es sonido; nunca entra en la cabina.

### En cooperativo

- **Va a por el que se queda atrás**: elige presa por quién está más solo, a oscuras, rezagado y ocupado (arriba, «Sentidos»).
- **Cada presa lleva su cuenta**: sus intentos fallidos y su descanso.
- **El encuentro se reparte** según cuántos supervivientes vivos hay en su planta (1, 2, 3 o 4):
  - la pausa en la que no empieza encuentro con nadie, tras dejar en paz a una presa o tras una captura, es de 15 s por 1, 0,75, 0,55 o 0,4;
  - el acecho dura su tiempo por 1, 0,85, 0,7 o 0,6.
- **Tras una captura**, el descanso de su dificultad solo protege a quien estaba a menos de 8 m de ella.
- **Tras un intento fallido**, vuelve a por quien esté más solo entre los que tenía a menos de 12 m de la presa que se le escapó: puede ser otro.
- Dos que se cubren la espalda son casi intocables; separados, cada uno es una presa.
- **Los muertos** miran por la cámara de un compañero, como ahora, y desde ahí ven lo que el vivo no ve: la cara en el techo detrás de él.

### El director, adaptado

- **Mismas reglas:** zonas, nunca posiciones.
- **El encuentro garantizado** (cruzarse con quien lleva mucho sin señales) pasa a ser **un asomo al borde de la vista** de alguien que ella perciba.
- **El descanso** del director solo llega cuando acaba un encuentro suyo (`creature.earned_rest()`: tras dejar en paz a una presa o tras una captura), no cada vez que se acerca: casi siempre está cerca. Mientras no, el director sigue en tensión creciente.
- **El encuentro forzado** (`pacing_director.forced_due()`): si pasa el tiempo de su dificultad sin que alcance a nadie, el director la lleva a la sala de quien está más solo o más rezagado en su ala y no escondido (`lonely_target()`), nunca junto a quien se esconde; la sala es adonde va andando (su posición 6 s por delante), no la que deja, y la vuelve a llevar cada 8 s hasta que alcanza a alguien. La pista vale también en salas con luz (ella llega por el plénum), y en plena huida la acepta pasados 8 s.
- **Lo de «menace»** (cuánto de cerca está) mide también la distancia por los ductos, y en algunos compases lo dice ella (sección 9).

### Dificultad (claves propias, a afinar jugando)

Sus claves están en `game/floors/difficulty.gd` (`CREATURE_PROFILES`), encima de las compartidas con el hotel. Estas son las de hoy:

| Clave | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| Ventana de la espalda (`back_window`) | 2,2 s | 1,5 s | 0,9 s | 0,9 s |
| Coge en una sala con luz, de espaldas y tras el aviso (`lit_takes`) | No | Sí | Sí | Sí |
| Velocidad en los ductos (`duct_speed`) | 1,2 m/s | 1,6 m/s | 2,4 m/s | 2,8 m/s |
| Distancia de acecho (`stalk_distance`) | 12 m | 8 m | 4 m | 3,5 m |
| Sin que nadie la vea, por una superficie (`unseen_speed`) | 3 m/s | 3,5 m/s | 4,5 m/s | 5 m/s |
| Sin que nadie la vea, por un ducto oculto (`unseen_duct`) | 3 m/s | 4,2 m/s | 5,8 m/s | 5,8 m/s |
| Lo menos que va al acercarse (`creep_scale`, por 1 m/s) | 0,8 m/s | 0,9 m/s | 1,5 m/s | 1,7 m/s |
| Lo más que va al acercarse (`approach_cap`) | 3 m/s | 3,5 m/s | 4,5 m/s | 5 m/s |
| Tiempo de acecho antes del silencio (`stalk_time`) | 25 a 40 s | 15 a 25 s | 4 a 9 s | 3 a 6 s |
| Probabilidad de asomarse una vez al acechar (`peek_odds`) | 70 % | 50 % | 15 % | 10 % |
| Duración del silencio (`hush`) | 3 s | 2,5 s | 1,5 s | 1 s |
| Probabilidad de que un acecho empiece en emboscada (`ambush_odds`) | 15 % | 30 % | 60 % | 70 % |
| Tarda en ir hacia un ruido nuevo (`noise_react`) | 4 s | 2 s | Al instante | Al instante |
| Ronda cerca de donde supo de alguien, esta parte de las veces (`haunt`) | 35 % | 60 % | 90 % | 100 % |
| Intentos de un encuentro (`attempts`) | 2 | 3 | 5 | 6 |
| Tras un intento fallido, vuelve a salir a los (`emerge_delay`, antes de acortarlo) | 8 a 12 s | 4 a 7 s | 1 a 2 s | 0,7 a 1,5 s |
| Por dónde vuelve a salir: una rejilla, un hueco o cualquier placa (`emerge_mode`, `emerge_range`) | Lejos (10 a 15 m) | Cerca (6 a 10 m) | Por tu espalda (3 a 5 m) | Por tu espalda (3 a 4,5 m) |
| Deja en paz a esa presa tras el último intento (`encounter_rest`) | 120 s | 90 s | 45 s | 30 s |
| Deja en paz a quien estaba cerca de una captura (`sated`) | 60 s | 40 s | 20 s | 12 s |
| Sin alcanzar a nadie, el director la lleva a la sala de alguien a los (`forced_after`) | Nunca | 70 s | 30 s | 20 s |
| Distancia a la que bebe una lámpara (`drain_reach`) | 3 m | 3 m | 4 m | 4,5 m |
| Se bebe la sala de su presa a los (`snuff_time`) | Nunca | 12 s | 4 s | 2,5 s |
| Linterna que la espanta, bebida durante (`torch_drunk`) | Nunca | 3 s | 10 s | 14 s |
| Probabilidad de que una linterna bebida se apague del todo (`torch_kill`) | 0 % | 25 % | 60 % | 80 % |
| Primera etapa a oscuras (`office_geometry.darken_first_stage`) | Todo con luz | Las salas oscuras del manifiesto | Todas las que pueden estarlo, menos un 10 % | Todas las que pueden estarlo |

El tope al acercarse queda siempre por debajo de la carrera de un superviviente (6 m/s) menos medio metro. Las demás claves (el director, los ascensores, los reintentos de etapa y el oído) son las compartidas con el hotel, las de The Locust.

En Apacible, más asomos y menos capturas: miedo sin castigo.

**Más agresiva** (el autor, 24 de octubre de 2026, tras su primera partida; el detalle en `.claude/specs/spec_f3_aggression.md`): la primera etapa se oscurece con la dificultad (la última fila de la tabla); avisa desde hasta 5 m y su salto largo llega a 7,5 m.

**La reconstrucción** (11 de noviembre de 2026, `.claude/specs/spec_lurker_rebuild.md`): el autor la jugó y pidió rehacerla entera, con dificultades que se noten y equilibrada en cooperativo. Las claves nuevas (`stalk_time`, `peek_odds`, `hush`, `noise_react`, `sated`, `approach_cap`, `haunt`, `torch_drunk`, `snuff_time`, `torch_kill`, `ambush_odds`) son del director, a afinar jugando, como los cambios de `forced_after` y `unseen_duct` de la primera iteración. Tras jugar la tercera iteración, el autor dijo: «Está bastante mejor en pesadilla, esta dificultad la guardaría como desafiante». Así que **la fila de Pesadilla que jugó es ahora la de Desafiante**, también su primera etapa a oscuras (todo menos un 10 %). **La Pesadilla de hoy es una fila nueva, del director, a afinar jugando**: más dura en casi todas las claves y con todas las salas que pueden estar a oscuras apagadas. Apacible y Equilibrada no cambiaron, y las claves compartidas con el hotel tampoco: las de Desafiante no son las de la Pesadilla que jugó el autor.

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
  - modernismo institucional feo, de finales de los 80 y principios de los 90;
  - beige, verde oliva, mostaza, marrón de chapa de madera, gris acero;
  - luz de fluorescente **cálido**, en clave baja desde el 11 de noviembre de 2026 (rediseño, `.claude/specs/spec_rediseno.md` 4): un charco de luz bajo cada pantalla, rincones y lo alto de las paredes en penumbra, lentes que queman y una gradación propia del piso, más contrastada y menos saturada, cuyo balance compensa el amarillo verdoso de la cinta para que la vista de juego quede en el naranja apagado de las referencias (12 de noviembre de 2026); unos 3.000 K en las salas y 3.500 en los pasillos, ámbar (2.700) en la recepción y la sala de descanso, y neutra (3.300) en las juntas y la dirección, vista con el balance fijo de 3.200 K de la cámara. El vestíbulo del montacargas conserva la luz verdosa del hotel y el cuarto eléctrico solo tiene su unidad de emergencia.
- **Materiales:**
  - suelo de terrazo oscuro en pasillos, vestíbulos, correo y archivo, y de losetas vinílicas beige con motas, enceradas, en las salas (los dos satinados, no mojados, desde el 12 de noviembre de 2026), salvo las naves de la planta 1 (moqueta), el cuarto eléctrico (baldosa con relieve) y el almacén, la galería y el depósito (hormigón sellado);
  - bloque de hormigón pintado;
  - chapa esmaltada lisa, con poco desgaste y algo de brillo, en los archivadores verde oliva y verde menta, las puertas de acero y lo gris de acero; papel, laminado claro y plástico beige, un quinto más oscuros que antes, para que bajo las lentes no quemen en blanco;
  - paneles de chapa de nogal de tono medio (`veneer`, aclarada al doble el 11 de noviembre de 2026 para que se lea como madera; el nogal y el roble de las piezas, más claros y con juntas de panel desde el 12) en el despacho de dirección, una pared de nogal en secretaría y zócalo de nogal en despachos, juntas y seguridad; vinilo pulido bajo una alfombra grande en Dirección (persa en el despacho y la secretaría, lisa en juntas), que suena como moqueta, y moqueta en las naves de la planta 1;
  - placas acústicas envejecidas (más amarillas, con cercos y alguna fisura) con perfilería blanco roto;
  - latón gastado en los tubos del correo neumático;
  - vidrio claro (armado solo junto a seguridad) en marco de nogal, con persianas venecianas beige salvo en la ventanilla y en seguridad;
  - tela de mampara;
  - chapa galvanizada en los ductos;
  - corcho en los tablones.
- **Luz:**
  - pantallas de fluorescentes 60 × 120, por familias: difusor prismático en general; estrecha con rejilla en la recepción y en las juntas; parabólica de cuatro celdas a lo ancho en la secretaría; de superficie, con difusor envolvente, en el despacho de dirección. Cada lente encendida enseña sus tres tubos tras el difusor. La lámpara de la sala sigue siendo la que manda y la que ella bebe; en Alto y Ultra, bajo cada pantalla, un foco sin sombra que la sigue; un halo corto y débil en las placas alrededor de cada pantalla encendida, también con su lámpara; y en el suelo, el reflejo de las lentes por la sonda de cada sala encendida (en Alto y Ultra en todas, en Medio en algunas), que baja cuando ella bebe la sala. La lámpara apenas deja brillo propio en el suelo encerado;
  - focos de emergencia con batería;
  - carteles de salida;
  - luces de acento (flexos, lámpara de pie, la luz de la expendedora en el suelo, apliques), como mucho tres por sala, y de ellas una sola lámpara de mueble encendida (decisión del director del 12 de noviembre de 2026, por el rendimiento en Alto): se apagan con la sala y bajan cuando ella la bebe. Los apliques son los dos del ascensor de llegada de la recepción y los de los lavabos;
  - nada de monitores encendidos (las pantallas son de otra criatura pensada, The Boiled One).
- **Abandono:**
  - papeles por el suelo, sillas volcadas, cajones abiertos, abrigos en perchas, tazas;
  - placas caídas, cables por el suelo y las mesas, manchas de agua;
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
- **La cámara sigue siendo la cinta:** la luz del piso se ve a través del mismo vídeo de 1990.

---

## 9. Dirección de audio

- **Ambiente:**
  - la climatización respirando en el plénum (un rumor grave que va y viene);
  - zumbido de fluorescente más frío que el del hotel;
  - chapa de ductos que cruje al enfriarse;
  - goteo;
  - el zumbido del cuadro;
  - **silencio seco en los archivos** (el papel se lo come todo).
- **Pasos:** las losetas suenan más (el ruido llega más lejos). Las alfombras de Dirección y la moqueta de las naves de la planta 1 los apagan: allí se oye menos a todos, también a ella.
- **Ella:**
  - garra en placa (toque blando y crujido de perfilería);
  - garra en ducto (golpe de chapa con resonancia);
  - garra en pared (tictac);
  - respiración húmeda y lenta;
  - chasquido de mandíbula (hueso);
  - el **aviso de la espalda**;
  - el **chillido al espantarse**: animal, nunca humano.
  - Todo **grabado**: foley y animales con licencia, procesados. Nada de voces ni gritos humanos sintéticos.
- **Ella suena por compases** (`creature.mood()`, que `lurker.gd` saca de su estado con `MOODS`): cada compás dice cuánto aura deja (`dread_aura`), si la música sigue la distancia o la amenaza que ella da, si el aura cae de golpe y si su voz calla.
  - **Lejos** (rondando a más de 12 m de camino de quien sea): golpes de ducto en tandas de 6 a 8 con silencios de 6 a 12 s; aura baja.
  - **Cerca** (a 12 m o menos): tandas de 6 a 8 con silencios de 1,2 a 2,6 s; más aura.
  - **Acecho**: sus garras de verdad en el techo y la pared, y a veces un arañazo o un arrastre pared abajo; por el plénum o un ducto, tandas cortas de 2 a 4 golpes y silencios de 2,5 a 5 s, y solo entonces los chasquidos falsos del aura. Casi todo el aura.
  - **Silencio**: nada suyo; el aura cae de golpe, la música pasa a amenaza plena, y el ambiente, el aura y el tema se apartan para quien esté a menos de 14 m en su planta.
  - **Acercarse**: solo sus garras, cada mano tan fuerte como si fuera deprisa; el aura entera y la música en amenaza plena.
  - **Aviso**: solo el aviso; ella calla desde que empieza y lo demás se aparta como en el silencio.
  - **Huida**: el chillido y una tanda seguida de 12 a 16 golpes que se aleja; el aura cae de golpe y la música vuelve en menos de 6 s.
  - **Descanso** (nadie elegible cerca): golpes lejanos, con silencios de 9 a 16 s; poca aura y **vuelve la música**.
  - **Emboscada**: nada suyo y nada de aura hasta el aviso.
  - Además: **escuchando** (quieta, sin un ruido) y **asomada**, el aura cae de golpe; **volviendo** por el techo calla, y solo cruje la placa o la rejilla por la que sale; **encima** de una taquilla, una placa arrastrada al llegar y su respiración por las lamas.
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
  - el motor de rejilla del hotel con la paleta de oficinas (módulos de 6 a 9 m, pasillos de 3 a 3,6 m y alguno de 2,4);
  - su propio `finish()`: tipos, falso techo a 2,95, taquillas en vez de armarios, muebles;
  - y lo de cada planta:
    - en la 1, la ventanilla, las estaciones y la red de tubos;
    - en la 2, el cuarto eléctrico y las zonas de circuito;
    - en la 3, el puesto de seguridad, la sala de climatización, el ducto principal y el pozo;
    - el montacargas, colocado como el refugio del hotel;
  - genera la red de **ductos** y los **pasillos de archivo** en el manifiesto, que la huella de red ya compara.
  - amuebla cada sala por la receta de su tipo (`office_recipes.gd`, con un sorteo propio; las tablas por tipo están en la paleta: `ROOM_FURNITURE`, `FEATURE_WALLS`, `CORNERS_REPLACED`). Lo que ocupa suelo va a `room.furniture`: contra su pared característica (`room.feature`, la que miran las capturas de `office_rooms_capture.gd`; en las salas de `FEATURE_FIRST_PIECE`, cuyas recetas no tienen entradas contra esa pared, pasa a ser la pared donde cayó su primera pieza), contra otra pared libre o exento hacia esa pared. De las otras paredes prueba antes las que no tienen puerta y la de enfrente de la característica la última, y en cada una empieza por la esquina que se ve desde la puerta (`walls_for()`, `feature_end()`): lo que queda junto al ojo no se ve. Un salón de dirección pone su único escritorio en la celda con la puerta al pasillo, o si no cabe en la siguiente que lo admita (`ONE_PER_HALL`, `hall_heads()`), y todas sus celdas comparten `room.feature`. Deja libres las puertas, las taquillas, las estaciones, los lectores, el cuadro, los minuteros, la consola, la climatizadora y, en un vestíbulo o refugio con montacargas, el sitio donde la etapa levanta a los caídos (`RAISE_AWAY`, `RAISE_REACH`), con un paso hasta cada uno para los muebles de pared y los exentos; no pone nada a menos de 0,6 m de una cristalera (tampoco las piezas de esquina más altas que el antepecho), y las piezas de esquina que la receta sustituye solo vuelven si su sustituta no cupo;
  - en una celda de nave de oficina abierta o de cubículos (desde el 12 de noviembre de 2026; detalle en `.claude/specs/spec_rediseno.md` 3.3) deja calles fijas de 1,2 m (el pasillo central, los lados abiertos, de cada puerta al pasillo y entre grupos), pone hasta tres islas de mesas rectas con mamparas de 1,2 m en cruz y una pieza en cada extremo (`lay_islands()`), y llena de punta a punta cada pared cerrada con archivadores, estanterías y carros, con una planta al final de cada tramo (`lay_wall_rows()`);
  - en las celdas de oficina abierta que no son nave, donde los pares de mesas no llegan a dos, pone mesas sueltas si sientan a más gente que los pares;
  - cuando puede, pone cada secretaría junto a un despacho de dirección, con puerta entre los dos, cambiándole el tipo con una sala corriente o con otro despacho de dirección, y deja esa puerta abierta;
  - en los pasillos de 3 m o más, cada 5 a 8 m de pared, pone una papelera, un banco o una planta, de 0,5 m de fondo como mucho, con 2 m o más de paso y fuera de los barridos de las puertas, las estaciones, los minuteros, las salidas, el sitio del rótulo de zona y los huecos donde la pared del pasillo lleva lo que se cuelga cada 2 m (`HALL_SLOT_CLEAR`); los vestíbulos llevan archivador, papelera y planta, y la climatización, una mesa de acero con su taburete;
  - abre cada puerta de una sala con luz con probabilidad 0,6 (no las de los refugios ni la de tarjeta), para que se vean las vecinas encendidas.
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
  - los muebles de cada sala, de los tipos de su receta y fuera de las zonas de paso, nada delante de una cristalera y, en los pasillos, el ancho, el fondo y el paso.

  Y en físico: rayos desde cada salida, barridos por los pasillos de archivo. **Mil semillas** con `tools/dev/office_metrics.gd`.
- **`office_geometry.gd`**, que hereda de `hotel_geometry`. Antes, `build_room()` se parte en pasos que se pueden sustituir. Añade:
  - la perfilería y las placas del falso techo (MultiMesh);
  - pantallas de fluorescentes con el perfil `tube`, del color de su sala (`lamp_kelvin()` de la paleta) y de su familia (`troffer_look()`);
  - rejillas, placas que faltan y el plénum (solo se dibuja lo que se ve por un hueco);
  - cristaleras con persiana; las puertas con la mecánica del hotel y hojas descargadas (desde el 12 de noviembre de 2026, `DOOR_MODELS`): de madera con mirilla o lisa sobre un marco de nogal moldurado (`door_frame_mesh()`), y de acero con su propio marco de acero en servicio, salas técnicas y puertas de etapa (`service_door()`, `STEEL_FRAME`); si falta el archivo, la hoja hecha en código;
  - los muebles de oficina (`room_dressing`, con su juego `office` ampliado).
  - los muebles sueltos de cada sala (`room.furniture`): las piezas hechas en código (`game/world/office/pieces/`) con su colisión, y los modelos de `office_models.gd`. Las sillas: la de oficina (de tela), la de dirección (de madera) y la de confianza (butaca de madera) son modelos descargados; la de espera es la pieza en código de nogal y cuero; la apilable, el sillón y la de comedor, modelos del hotel. Solo proyectan sombra las piezas grandes de suelo (`office_models.casts()`);
  - las filas de los archivos (`office_props.row()`): tramos de `archive_shelving` o `mobile_archive`, cada uno con su variante, un solo colisionador por fila y el número de la fila en el extremo que da a la espina.
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
  - Nunca se queda quieta porque su camino esté vigilado: si alguien lo vigila con luz, va por el plénum (spec_lurker_rebuild 2.1). Mirada con luz o alumbrada, huye.
  - A oscuras y sin linterna, aunque la miren, avanza (a ráfagas): nadie le distingue la cara.
- **La garantía del aviso, en código.** Una captura solo sale de `CUE`:
  - con la misma víctima y tras la ventana más la latencia;
  - si en cualquier fotograma de la ventana la víctima la mira con luz, o la linterna de alguien le da en la cara, pasa a espantarse (una linterna bebida o apagada por ella no cuenta: `lurker_senses.drop_drunk()` la quita antes de que llegue al aviso);
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
    - `game/app/capture_styles/locust_capture.gd`: lo de hoy, movido sin cambios;
    - `game/app/capture_styles/lurker_capture.gd`: «levantar y soltar». Deja el cuerpo en el suelo, `camera_fall` prefiere quedar mirando hacia arriba y `death_tape` encuadra su cara del revés;
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
| Ya en código (`game/world/office/pieces/`; las coloca `office_props.gd`, salvo el perchero y la terminal) | Mesa metálica (`desk_steel`), archivadores de 2 y 4 cajones (`filing_cabinet`), fichero de fichas (`card_index`), estanterías de archivo (`archive_shelving`), archivo móvil con manivela (`mobile_archive`), mamparas de cubículo (`partition_screen`), mesa de juntas (`meeting_table`), perchero (`coat_hook_rail`), terminal (`computer_tower` y `crt_monitor`), fotocopiadora (`copier`), carros de correo (`mail_cart` y `cart`), casilleros (`pigeonholes` y `pigeon_counter`) |
| Siguen siendo modelo | Sillas de oficina, **máquina de escribir**, teléfono de disco, lector de microfichas, **estación y tubos neumáticos**, **lector de fichas**, **cuadro general de palancas**, **pulsador de minutero**, máquina expendedora, fuente de agua. El resto de la fila Modelos no es de esta área |
| Ya traídos (`assets/props/office/` y `assets/paintings/office/`, registrados en ASSETS.md) | En uso (`office_models.gd`, `office_props.gd`, `office_geometry.gd`, `office_fittings.gd`). De Poly Haven (CC0): el sofá, el sillón del rincón de dirección, las plantas, y desde el 12 de noviembre la grapadora, el termo, la caja de herramientas, el recogedor, la escoba, la ratonera, la lupa, las gafas, la escalera, el televisor del carro de descanso y juntas y el radiocasete (con sus marcas tapadas). De Sketchfab, CC BY 4.0 y en los créditos (`hotel_ui.gd`): el teléfono de disco colgado, la pantalla de los puestos (un terminal sin teclado, marcas tapadas y pantalla apagada), la fuente de agua, el perchero de pie del despacho y de dirección, y desde el 12 de noviembre las tres puertas (madera con mirilla y madera lisa de Sousinho, acero con su marco de tboiston, con las bisagras de Mehdi Shahsavan), las taquillas (Zambur), el archivador gris (Mehdi Shahsavan), el detector de humo (Sousinho), el escritorio verde de los puestos (YJ_), la silla de oficina de tela (projectkaizen), la de dirección de madera (Zamzam2003), la butaca de las visitas (Renend Studio), el escritorio de madera del despacho y la librería con libros (Matthew Collings), el globo (mtcollings), la expendedora (AtTheSpeedOf), la nevera (dylanheyes), las lámparas de banquero (Jeff Meunier) y de brazo (Sousinho), el cenicero de vidrio (RED2000), la bandeja (YouniqueĪdeaStudio), la caja de archivo virada a kraft (Cozmoth), las filas de libros (FrodoUndead), la impresora (Remik.Papaj), el ventilador (Josh Smith), el reloj de mesa (Sousinho), los archivadores de palanca (janexx), la caja de cartón (SusanKing), el alargador (EFX) y los zapatos (inciprocal). De la silla de tela falta anotar en su registro la URL de la ficha y el título exacto: el zip no traía `license.txt`. Horneados y sin usar: la silla giratoria «Old Computer Chair» (sigue en la lista de `office_chair`, pero `office_props.chair()` toma siempre la primera, la de tela), el escritorio tanker de lena-wachs, la silla cromada de YJ_, el portalápices de AspectStudios (4,8 k triángulos en cada mesa de una nave), la pantalla de proyección de Poly Haven (ninguna receta la pone) y, de Poly Haven, el fichero de madera, el taburete metálico, la mesa redonda y la pequeña de madera, el marco de pie y la estantería de acero. Diecisiete láminas del Art Institute of Chicago (CC0) que cuelga `office_pictures.gd` |
| Descargados que no entran (`pendiente` en sus registros de `source_assets/oficinas/`) | Máquina de escribir de los años 30 (sin preparar), expendedora de café (anuncio y rótulos en inglés), persiana (las del juego son un sombreador), archivador oxidado (se lee como ruina), puertas comerciales de Delly (piezas de varias puertas en los mismos objetos), puerta doble (sus dos hojas son un objeto de 3 m), manilla y pomo (las puertas traen la suya), señal de salida (la del juego ya es un panel grabado con su luz), sofá de cuero (roto), cenicero de metal (ceniza y una etiqueta con letras), silla de aluminio y libros tirados (registrados, sin preparar). De Poly Haven: el microondas, el hervidor y los marcos colgados (rótulos en sus texturas), y otros sin preparar (`registro_polyhaven_modelos.json`) |
| Sin modelo que valga, siguen en código | Fotocopiadora de los 80, máquina de escribir eléctrica, fax, retroproyector, cafetera de época, mesa de comedor de laminado y sillas apilables de época, escritorio en L, rociadores, interruptores, paneles de madera de pared, papeles, calculadora y perforadora. Difusores, rejillas y mamparas tienen candidatos registrados como `ok` y sin ingerir (`ceiling_diffuser_oga` CC0 y `wall_grille_oga` CC BY, en `equipos/`; `cubicle_partitions_3td_office` CC0, en `muebles_b/`), todos sin PBR. El abrigo y la toalla colgados no tienen descarga que se pueda vender, y la simulación de tela que se probó no dio un resultado usable |
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
  - el plénum solo se dibuja donde falta una placa o donde ella ha dejado una abierta;
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

**Decidido el 24 de octubre de 2026** (las preguntas de las fases 2 y 3; las demás, como recomendaron los agentes):

- **Por dónde va en las salas altas** (pasillos de servicio, climatización, máquinas): **por las paredes y por el techo**; con un jugador cerca, **salta desde el techo** sobre él con un salto largo.
- **Bajo los muebles más altos** su cuerpo **se encoge** para pasar; se rectificará midiéndolo en el juego.
- **Alejarse durante el aviso salva solo corriendo**, no andando.
- **Hay aviso desde arriba** en las salas altas.
- **Su cara a oscuras** solo se ve **muy de cerca**.
- **Los golpes del director en las puertas se quedan** en el piso 2: asustan cuando no hay peligro.
- **Sus codos** esquivan todo lo que tiene colisión.
- Lo demás, como se recomendó: tapa el vano a la altura de la cabeza y los supervivientes chocan con ella sin que los empuje; el plénum es también una capa oculta sobre las placas; su nido en la planta 3 es la sala de climatización; entre plantas tarda lo del montacargas y va primero a por quien se queda atrás; no abre taquillas; bebe la luz también desde un ducto, nunca en los vestíbulos, y sin dejar ninguna sala a oscuras para las reglas; la mirada con luz de un compañero también salva; cuenta solo la latencia de la víctima, hasta 0,5 s; acechar tiene palabra propia.

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
