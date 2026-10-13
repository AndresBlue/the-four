# The Four — Plan de trabajo

**Lo que falta, en el orden en que hay que hacerlo.** Nada de lo ya hecho vive
aquí: el juego que existe se describe en [el diseño](GAME_DESIGN.md), cómo está
montado en [la guía de desarrollo](DEVELOPMENT.md), y el registro de cómo se
llegó hasta aquí —con todo lo comprobado, medido y fechado— quedó en
[history/PLAN_2026-09-21.md](history/PLAN_2026-09-21.md).

Estado: juego **0.5**, generador de mapas **v7** (tres plantas enteras), protocolo de red
**the-four-net-16**, Godot 4.7.2. Cada casilla es trabajo por hacer; se marca
cuando está **comprobado**, no cuando está escrito. Lo que se comprueba con
`./tools/verify.ps1` y las demás herramientas está en la guía de desarrollo.

## Dónde estamos (25 de septiembre de 2026)

Hay un piso jugable de principio a fin, solo o acompañado: hotel procedural de
tres plantas y tres etapas, The Locust con su IA y su versus, supervivencia,
cordura, ascensores con botón, cuatro presets gráficos y un ejecutable de
Windows de 448 MB que funciona (exportado el 22 de septiembre; lo de después de
esa hora pide volver a exportar). Se ha jugado con gente real, en LAN y por
Internet, pero **no desde todo lo de abajo**.

Antes del 21 ya estaban arreglados los cinco fallos de la última partida, lo
que nadie entendía jugando y la deuda técnica entera; el detalle está en la
guía de desarrollo, en [REALISM.md](REALISM.md) y en
[history/PLAN_2026-09-21.md](history/PLAN_2026-09-21.md).

El 22 entraron, y **nadie los ha jugado todavía**:

- **Dos revisiones de fallos**, una general y otra más profunda, con unos
  cuarenta fallos reales arreglados y su prueba cada uno. Los que más se van a
  notar: la criatura **persigue de verdad** (quien seguía andando a su vista
  nunca era perseguido, porque cada paso reiniciaba su alerta), los coches de
  ascensor que se construían al revés y no se podían tomar —el «bloque sin
  ascensor» de la última partida—, la puerta del código que se abría sola al
  pasar al sector 3 con un muerto, las puertas que ahora frenan a la criatura
  (y las tres reglas para que no se quede plantada en ninguna), el sonido que
  de verdad se amortigua tras una puerta cerrada, la cordura que sube en el
  refugio y, en red, el parpadeo de las luces al cambiar de sector, las
  reconexiones y los armarios que se quedaban ocupados.
- **Ajustes repartidos en dos pestañas**: IMAGEN es la pantalla (modo de
  ventana, tamaño, escalado, escala, nitidez, suavizado, FPS, vsync) y
  GRÁFICOS es cómo se ve (preset, renderizador, sombras, los cuatro efectos
  pesados y la estética de la cinta). Con **FSR 2.2**, que a escala 0,6 da un
  74 % más de fotogramas que la resolución nativa y, con algo moviéndose, es el
  más fiel de los cuatro modos medidos. DLSS no se puede: no está en el motor y
  no se añade desde fuera.
- **El parte al salir del piso y los mejores tiempos**: la cinta que sale queda
  anotada, y hay dos tablones —en solitario y acompañado— con tres tablas cada
  uno.
- **Se juega entero con mando**, menús incluidos, con vibración y con el
  teclado del código marcable con la cruceta.

El 25, con las notas de la partida del 24 (cooperativo y versus), entró esto,
y **tampoco se ha jugado**:

- **Los refugios, la salida y los vestíbulos de los ascensores protegen
  siempre**, de pared a pared: pegado a una esquina de la salida ya no se
  muere, y quien espera el coche en un refugio cruzado está a salvo.
- **La criatura espera su turno en el ascensor**: 15 s en el vestíbulo y 20 s
  desde que bajaron los supervivientes, lo último de las dos. Donde sale, el
  hueco de una campanilla (falta el sonido).
- **Grita en todo el piso cuando empieza la caza**, al acabarse su protección.
- **El salto entre teles**: la IA ya no se queda plantada donde sale ni sale
  encima de nadie, y lo hace de verdad (casi nunca lo hacía); el cazador abre
  el armario al que apunta aunque tenga una tele al lado, y no salta a media
  estocada.
- **Fallos a la vista**: las motas rojas de quien muere sin cordura ya no se
  quedan en la lectura del cazador, las manchas de humedad ya no le tapan la
  pantalla contra una pared, y los pasillos ya no se ven por módulos en Alto
  y Ultra.

El 1 de octubre entró la vuelta entera a las marcas, y **tampoco se ha
jugado**:

- **El parte de la cinta, en pestañas**, al salir del piso y también al
  perderlo: resumen con puntaje y nota, equipo con el más valioso y el papel
  de cada uno, sectores contra la mejor marca, cronología del piso e hitos.
- **Marcas** en el menú principal: tres tablones por piso (solo, acompañado,
  contra el cazador) con cuatro tablas, la ficha de carrera, dieciocho hitos
  del hotel y la comparación con las fichas de la gente con la que se juega.

El 12 de octubre entró **la captura rehecha**, y **tampoco se ha jugado**:
lo que ve quien muere es lo que grabó su videocámara —la máscara a un palmo,
la cámara arrancada de las manos, la muerte desde el suelo, la cinta que se
corta—, distinto según cómo te coge, dónde cae la cámara y qué luz hay; la
finta del armario, de la que se escapa esperando; salir de un armario sin
ruido; la segunda muerte más corta, la cinta que se rebobina y «Sobresaltos
suaves». Tiene su banco (`Banco de capturas.cmd`). Con las películas vistas
(12 de octubre) el autor decidió: sin desgarro, sin embestida (te coge en el
acto en las cuatro dificultades), el armario de golpe, la cámara cayendo
como cae una cosa, el grito 0,05 s después de la máscara y el cuerpo sin
atravesar paredes. Hecho todo; falta que lo vea (apartado 1).

El 4 de octubre entró esto, y **tampoco se ha jugado**:

- **Las cuatro dificultades, elegibles**: «Nueva partida» pregunta cuál, y en
  la sala la elige el anfitrión. Por ahora cambian solo números (sentidos,
  persecución, búsqueda, director, ascensor, teles y clemencia); las
  conductas propias de cada una vienen después (DIFFICULTY.md).
- **Encuentros en el parte** y **bots novatos** para medir la dificultad.
- **Gráficos de fábrica**: Medio con FSR 2.2 en Calidad y la cinta como se
  ajustó jugando.
- **La regla «Clemencia»** es ahora la de las etapas devueltas en equipo (la
  de agarrar y soltar se quitó).
- **Apacible y Equilibrada, por episodios** (5 de octubre, tras probar con
  gente): respiro medido por lo vivido, a solas todo más espaciado, la
  bestia ve y oye menos y corre menos que quien huye. A solas con un bot
  novato, Apacible pasó de 0 a 7 pisos ganados de 12 y de 14,5 a 2,3 caídas;
  en equipo de tres, del 75 al 95 % (Equilibrada, del 0 al 60 %). Falta
  decidir Equilibrada a solas (un bot novato no la gana), si un piso a
  solas debe pedir menos, y probarlo con gente (DIFFICULTY.md, tercera
  medida). **Medidas las cuatro con 50 pisos por celda** (cuarta medida):
  en equipo, novatos 100/68/0/0 % y expertos 98/98/46/0 %; a solas con
  novato, 68/4/0/0 %. Pesadilla no la gana nadie (se buscaba 15–25 %).
- **A una etapa devuelta la criatura vuelve a su punto de aparición** y
  espera la gracia de la dificultad, también la de un cazador.
- **Continuar devuelve el piso como se dejó** (sitio, sector, puertas,
  teles, muebles, criatura, hoja, plano y cinta), guardado al pausar, al
  cerrar y cada 30 s. Falta probarlo jugando: dejar un piso a medias en
  cada sector y volver.
- **Los adornos ya no se hunden en los muebles**: `shelves()` leía los
  triángulos al revés y tomaba la cara de abajo de cada tabla.
- **La tele del tráiler** en el hotel: el CRT de la escena de entrada sobre
  una cómoda gótica, cristal oscuro apagada, la línea que se abre al
  encenderla y su luz hacia delante con un relleno, las dos con sombra.
  Falta verla jugando.
- **La señal perdida dice menos:** solo el número de la cinta y «Cinta
  perdida.»; la pestaña Equipo sin desglose ni destacado; el cursor ▶ pegado
  a su palabra.
- **Lo que se mantiene se ve** (un disco al registrar y al abrir despacio),
  **puertas a 2,4 m** (estaban a 3,2), el panel de controles con la rueda y
  el resto, «Mantén E para saltar la cinemática» y el aviso del primer piso
  («The Locust va a por ti…»), solo la primera vez.
- **A solas, en Apacible y Equilibrada, caer devuelve la etapa** como en
  equipo, y **Reintentar empieza siempre un piso nuevo** (perder borra el
  punto de control).

El 1 de octubre entraron también **las reglas de la sala**, y **tampoco se
han jugado**: once cosas que el anfitrión puede cambiar antes de empezar
(clemencia, derrumbes perdonados, cordura, el código con o sin notas, el
apagón, el plano de la hoja y cuánto dura, la hoja compartida o no, la
embestida, el viaje por las teles y la vista del cazador). Una cinta jugada
con otras reglas va a su propio tablón y no da hitos.

El 26, con las notas de jugar con mando en la tele, entró esto, y **tampoco
se ha jugado**:

- **Andar con el stick es analógico** (antes era quieto o andando) y **la
  cámara del mando se lee en cada fotograma**, suavizada y con aceleración al
  fondo. Correr (stick izquierdo pulsado) y agacharse se alternan con un toque.
- **Distribución nueva del mando:** cuadrado interactúa, triángulo linterna,
  cruz salta, círculo agacha, la hoja en Share/Vista y en el panel táctil.
  Los nombres de los botones siguen al mando (Xbox, PlayStation, Nintendo).
- **Los menús con mando:** bajar ya no salta a «Volver» dejando opciones sin
  alcanzar, y L1/R1 cambian de pestaña en Ajustes.
- **Dibujar en la hoja con mando:** el stick lleva el lápiz, R2 dibuja y L2
  borra. Con el dedo en el panel táctil no se puede: Godot 4.7 no da dónde
  está el dedo, solo el clic.

El 24 entró una vuelta entera a la criatura, al director, a la cordura y a
las alucinaciones, y **tampoco se ha jugado** (descrito en el diseño):

- **La criatura recorre el ala** en vez de ir y volver entre dos salas, y
  **se rinde** si en 8–10 s no encuentra pistas: marca la zona como
  registrada y se va a otra parte. Un hundimiento la aleja de la entrada.
- **El director juega a la criatura** con pistas de zonas, nunca con la
  posición de nadie, en fases de acecho, pico y respiro; con la cordura a 0
  ya no le dice a la criatura dónde está nadie, solo la acerca a su zona.
- **La cordura dura tres veces más**, y verla de cara asusta más que verla de
  refilón.
- **Alucinaciones de la criatura**: la que pasa cerca (se oye igual que la de
  verdad) y la que se asoma por una puerta o espera al fondo de un pasillo.

El 23, después de la partida de ese día, entró lo que pedía, y **tampoco se
ha jugado**:

- **La criatura ya no se atasca en las puertas**: una hoja abierta no la para,
  su ruta la rodea, solo se detiene ante las puertas de su ruta y tiene un
  protocolo de cinco pasos para salir de cualquier atasco (300 trayectos
  medidos sin una sola parada).
- **El cazador ve adónde ir**: la ruta azul al ascensor, las teles encendidas
  en amarillo desde todo el piso, el rastro de la Q hasta la más cercana y los
  enfriamientos en pantalla; el chillido, cada 10 s.
- **El audio de esa partida**: el teclado del código suena a teclado, una tele
  que se enciende suena a la estática del apagón y luego sisea, y el ascensor
  cierra sus puertas una vez por viaje.
- **Un piso de tres plantas enteras**, una debajo de otra: cada una es un
  hotel de 84 a 96 habitaciones con sus pasillos, un refugio que no se repite
  y lo de dentro sorteado (puertas, salas oscuras, armarios, muebles). Se
  monta en unos 6 s.

Todo está descrito en el diseño, la guía de desarrollo, [AUDIO.md](AUDIO.md),
[VISION_LOCUST.md](VISION_LOCUST.md) y [PERFORMANCE.md](PERFORMANCE.md).

Lo que sigue sin estar bien, que es de donde sale el orden de abajo:

- **Nadie ha jugado nada de esto.** Es un piso distinto del que se jugó: tres
  plantas enteras en lugar de tres alas, una criatura que persigue, se para
  ante las puertas cerradas y rodea las abiertas, y un equilibrio que cambió
  con todo ello.
- Solo existe **un piso de los cuatro**: Sunman, The Boiled One y Guilt no
  están.

## El orden

**Primero se deja fino lo que ya se puede tocar, y solo después se añade nada.**
Dentro de eso: lo que rompe una partida antes que lo que molesta y lo que no se
entiende antes que lo que no se ve —de esos dos ya no queda ninguno—; lo que
solo se decide jugando antes que lo que se puede pulir a solas; y la deuda
técnica antes de que crezca. El acabado
—sonido, materiales, mobiliario— va después, porque afina algo que ya funciona.
Los otros tres pisos van al final: son el doble de juego, y montarlos sobre un
piso que todavía falla es multiplicar los fallos por cuatro.

---

## 1 · Lo que solo se decide jugando

No es trabajo de código: es tuyo, y sin ello no se cierra el Early Access. Las
herramientas para mirarlo están en la guía de desarrollo.

### Las partidas que cierran la etapa

- [ ] **Partidas con amigos en individual, cooperativo y versus**, midiendo
  duración, encuentros con la criatura y si se entienden las etapas. Es la
  única forma de saber si el problema de origen —partidas de 5 a 8 minutos
  frente a la meta de 25–40— está resuelto de verdad. Incluye los veinte
  recorridos y las cinco partidas de exploración que P1 dejó pendientes: no los
  sustituye el lote automático.
- [ ] **El ritmo de las tres plantas**, ahora de 84 a 96 habitaciones cada una:
  cuánto se tarda en cada una, si se entiende que la puerta se abrió, y si la
  criatura llega demasiado pronto o demasiado tarde a la planta nueva ahora que
  va a trote hasta el ascensor (entre 15 y 111 s medidos, 32 de mediana).
- [ ] **El bloque de etapas entero:** si el apagón asusta o solo estorba, si el
  reinicio de etapa perdona demasiado, y si el camino azul al ascensor en la lectura de
  la criatura le da demasiada ventaja.
- [ ] **Si el piso se siente un hotel explorable** o un laberinto arbitrario, si
  los pasillos se leen como los de un hotel, y si hay que ajustar tamaño y
  referencias. Lo medido dice que la numeración ya
  no lleva a ninguna parte y que ir pegado a la pared no encuentra ningún
  refugio; lo que no dice es cómo se siente.
- [ ] **Si los pisos se parecen entre sí a simple vista**, que era la queja de
  la partida del 23: con el observador (`./tools/godot.ps1 observer`), M para
  el plano de una planta, R para otro piso y Mayús+R para volver al anterior;
  el panel dice el plano de pasillos, el contorno, las habitaciones y el
  tamaño de la planta que se mira. Lo medido (`tools/dev/map_metrics.gd`) dice
  que se parecen poco; lo que no dice es si lo parece.
- [ ] **Si se entiende quién murió y por qué** en cooperativo, ahora que no hay
  avisos de texto.

### Lo que hay que oír

- [ ] **Los gruñidos:** nivel y frecuencia, sobre todo los del propio cazador
  (se oyen 6 dB más bajos para quien lleva la criatura). Y los dirigidos a ti
  en una persecución, que ahora suben 7 dB, suenan más cerca y apartan 9 dB
  el aura, los pasos, el ambiente y la música: si dominan sin tapar hacia
  dónde está.
- [ ] **La música que se va con el apagón** y vuelve en el ala siguiente: si
  el corte se nota como parte del apagón o como un fallo.
- [ ] **Las distancias con auriculares:** si 10, 20 y 40 m se distinguen de
  verdad, si las puertas lejanas se siguen leyendo con la absorción nueva, y si
  la dirección de la criatura se acierta en esquinas y con dos puertas.
- [ ] **La segunda vuelta de la captura (12 de octubre), por ver.** Lo que
  pediste con las películas delante está hecho y medido, pero no lo has
  visto: (a) **te coge en el acto**, sin preparación, en las cuatro
  dificultades —¿se siente justo en Apacible, que antes daba 0,6 s para
  esquivar?—; (b) **el armario revienta** las dos hojas y te tiene 0,15 s
  después —la bestia se planta delante medio segundo antes: ¿ese medio
  segundo avisa demasiado, o demasiado poco?—; (c) **la cámara cae** con su
  peso (0,6–0,7 s), rebota y vuelca dos o tres veces de canto en canto, y la
  escena dura por eso 4,7 s en vez de 4,2: ¿la caída se lee como una caída, y
  el medio segundo de más pesa?; (d) **el grito** llega 0,05 s después de la
  máscara; (e) **el cuerpo** ya no atraviesa paredes ni suelo (medido en 56
  escenas), y tendido queda de espaldas: mira si alguna postura quedó rara
  contra una pared. Películas nuevas: `evidence/captura_frente.avi`,
  `captura_espalda.avi` y `captura_armario.avi`.
- [ ] **La tercera vuelta (12 de octubre), por ver.** (a) **El desplome del
  cuerpo:** ya no gira de una pieza; cae, le ceden las piernas, queda sentado
  y doblado un instante y se va de espaldas, con la cabeza y los brazos por
  detrás. Son curvas, no física de articulaciones: ¿se lee como alguien que
  cae, o hace falta un ragdoll de verdad (más trabajo, y no saldría igual en
  todas las máquinas)? (b) **Los materiales del cuerpo:** más mates, sin
  brillo, la ropa un tono más abajo. Es el techo de lo que se arregla sin
  tocar los modelos: si sigue pareciendo de plástico, es cosa de texturas o
  de modelos (apartado 4). (c) **La máscara que se te viene encima** justo
  antes del manotazo (de 13 a 8 cm en 0,07 s): ¿asusta más, es demasiado, o
  la quieres aún más cerca?
- [ ] **La captura rehecha (12 de octubre), con gente** (EXECUTION.md, 18.2):
  quien no la ha visto, ¿salta, y dice que vio una cara?; ¿sabe qué le mató y
  dónde quedó la cámara?; a la tercera y a la quinta muerte, ¿molesta, o nota
  que no es igual?; a oscuras, ¿se entiende con solo el piloto rojo?; con
  auriculares, ¿el grito hace quitárselos? —medido, su medio segundo está a
  −2 LUFS, unos 11 LU por encima de la caza que lo precede: es el nivel que ya
  tenía, y si molesta se baja aquí—; y de testigo, en cooperativo, si ver caer
  a otro da miedo o da información. Y la de otro a lo lejos, que se
  oye desde cualquier punto del piso: si se entiende como «han pillado a
  alguien» y hacia dónde.
- [ ] **La finta del armario:** si se entiende que de ella se escapa
  esperando y que sus pasos no mienten, cuántas muertes cuesta aprenderlo, y
  si las veces que finge (una de cada cuatro en Equilibrada, dos de cada
  cinco en Desafiante, tres de cada cinco en Pesadilla) y lo que espera (de 8
  a 15 s) son los números buenos: están puestos a ojo, sin medir con bots ni
  con gente. En el banco, la tecla 4 la fuerza y N te pone ante un armario.
- [ ] **Salir del armario sin ruido** (mantener E tres segundos, un 25 % menos
  de distancia de escucha): si tres segundos son muchos o pocos y si se usa.
- [ ] **El piloto rojo:** si jugando se nota lo justo (dentro de un armario
  tiñe las puertas; en una sala a oscuras no se ve nada de él).
- [ ] **Los pasos grabados y el zumbido de fondo**, en partida y no en una
  prueba.
- [ ] **Escucha crítica del reparto de buses y del aura**, con los eventos
  ambientales de los salones.
- [ ] **Las teles y el teclado nuevos (23 de septiembre):** si los 14 s de
  estática al encender una tele (−6 dB desde la pantalla) cansan o tapan a la
  criatura, si el siseo que queda (−27 dB, 11 m) se oye como una tele y no
  como una avería, y si los pitidos del teclado dicen «no» y «sí» sin leer la
  pantalla.
- [ ] **El viaje en ascensor**, que suena a la nieve que se ve mientras llega
  su sonido propio: si se entiende como el viaje o molesta.

### Lo que hay que mirar

- [ ] **Cómo se ven las animaciones de los supervivientes** ahora que van por
  pies plantados e IK.
- [ ] **Las guías del cazador (23 de septiembre):** si la ruta azul al
  ascensor se lee como un camino que seguir, si las teles amarillas desde todo
  el piso le dan demasiado (hoy sabe siempre dónde se han encendido), y si la Q
  —15 s cada 20— se usa o sobra. Y si el azul lejano, donde los granos se
  amontonan, se sigue viendo azul en una pantalla de verdad.
- [ ] **La vista de la criatura:** término base, separación de los frentes,
  legibilidad en salones grandes (ver [VISION_LOCUST.md](VISION_LOCUST.md)) y
  el peso de cada tipo de ruido en la imagen, con `./tools/godot.ps1 rehearsal`.
- [ ] **Lo que se sortea dentro de las plantas:** si las puertas desplazadas y
  sus giros se leen como un hotel, si seis de cada diez abiertas al empezar
  son muchas o pocas, si la tercera planta (casi la mitad de las salas a
  oscuras) pesa demasiado, y si un pasillo apagado de vez en cuando asusta
  como suceso.
- [ ] **La oscuridad nueva:** sin luz ambiente, los rincones en sombra de las
  salas iluminadas también son negros. Si resulta excesivo, no conviene subir
  `ambient_light_energy` (aclara también las salas apagadas): mejor dar relleno
  propio a las salas iluminadas.
- [ ] **El armario:** comodidad del efecto de asomarse en partidas humanas y a
  distintas resoluciones.
- [ ] **Los controles del mando, en revisión** (26 de septiembre): la
  distribución por defecto del superviviente y la de The Locust (hoy R2
  estoca, L2 chilla, triángulo rastro, cuadrado puertas y teles, L3 caza),
  si L1 y R1 deben hacer algo en partida (hoy nada: ¿zoom de la cámara?), la
  sensibilidad por defecto y el empuje del borde, y la velocidad del lápiz en
  la hoja. Queda por probar el giroscopio de los mandos de PlayStation y
  Nintendo para el lápiz, que Godot sí lee.
- [ ] **La escena de entrada:** ritmo y cámara.
- [ ] **Los tres personajes dentro del hotel**, con la cinta encima y a
  oscuras: los ojos de la Exploradora, el pelo fundido, el relieve del
  detective y el brillo de la piel. Solo se han visto con luz de estudio
  (`tools/capture/avatar_capture.gd`).
- [ ] **Lo que se escribe en pantalla, ya jugando:** el objetivo de cada sector
  arriba a la izquierda y cómo se deshace, la tarjeta de sector (también en
  cada reintento, que añade 2,6 s de negro) y la pausa con su progreso.
- [ ] **Las puertas que ya no se niegan:** cerrarlas estando en el marco,
  volver a abrirlas desde dentro, y si poder atravesar una puerta que uno se
  cerró encima se nota como trampa.
- [ ] **Shift y Ctrl:** confirmar que correr ya no se queda pegado. El arreglo
  suelta la tecla en cuanto el sistema avisa de que está arriba; si vuelve a
  pasar, apuntar qué se estaba pulsando.
- [ ] **El botón del ascensor** en partida: si se encuentra sin que nadie lo
  explique, y si esperar al equipo dentro del coche funciona o alguien acaba
  pulsando antes de tiempo.
- [ ] **La linterna en Compatibilidad**, a más de diez metros y de frente a
  una pared, ahora que el atlas de sombras se queda en 4096 y guarda la
  profundidad en 32 bits: las bandas diagonales del 23 de septiembre (en
  Medio, a un módulo de distancia) eran la precisión de 16 bits, y en este PC
  no salían. Mirarlo en la máquina donde se vieron.
- [ ] **La criatura persigue de verdad.** Hasta el 22 de septiembre, quien
  seguía andando a su vista nunca era perseguido: cada paso que oía reiniciaba
  su alerta, y se quedaba parada gruñendo. Ahora la alerta acaba en
  persecución. Es otra dificultad, sobre todo en solitario: volver a medirla,
  y ver si los gruñidos, que salían de ese bucle, se quedan en su sitio.
- [ ] **Lo que se arregló de la revisión de fallos del 22 de septiembre**, en
  partida online: el paso del sector 2 al 3 en los invitados (antes parpadeaban
  las luces), volver a una partida (cajones, código y cartel del sector al
  día), y los armarios de quien muere o se desconecta dentro.
- [ ] **La segunda revisión de fallos (22 de septiembre)** cambió cosas que se
  notan jugando y conviene mirar:
  - La criatura ya no atraviesa puertas cerradas. Y desde el 23 de
    septiembre las abiertas no la frenan: su ruta rodea la hoja. Mirar que no
    se la vea atravesar ninguna, que no dé rodeos raros al cruzar un vano y
    que no se quede quieta en ningún sitio (300 trayectos medidos sin una sola
    parada).
  - En cooperativo cada uno ve solo los números que encontró: ¿se entiende
    que hay que decírselos?
  - Una puerta cerrada ahora amortigua el sonido de verdad (8 dB y sin
    agudos): ¿se sigue oyendo lo bastante a la criatura?
  - La cordura sube también dentro del refugio.
- [ ] **El escalado nuevo**, en una máquina de verdad. Medido: a 0,6 da un
  74 % más de fotogramas que la resolución nativa, y con la criatura cruzando
  la vista es el modo más fiel a la imagen entera de los cuatro
  (`tools/capture/ghosting_capture.gd`), así que las estelas que se temían no
  aparecen en la medida. Falta verlo jugando, sobre todo con la criatura
  corriendo hacia ti y con la linterna barriendo, y decidir si en Bajo se
  queda FSR 1 o pasa también a 2.2.
- [ ] **La linterna en la vista de la criatura**, vista de lado y no solo de
  frente, ahora que es el cono real del haz.
- [ ] **Las puertas nuevas** a mano: escala del modelo, número en el panel
  superior, rendija de 1,2 cm, y las del dormitorio y la portada, que usan la
  misma hoja.
- [ ] **Los presets en partida**, que las capturas fijas no enseñan: TAA de
  Medio en movimiento, penumbras de Ultra, eco de Bajo, halo de Ultra, sombras
  con el filtro más barato en Baja y Media andando, y salas que aparezcan tarde
  al girar en un vano.

### Números que salen del diseño y no de jugar

- [ ] **La cordura:** siete minutos y medio a oscuras o en un armario, casi
  veinte con linterna, cuatro de luz para recuperarse, 4 puntos por verla de
  refilón y 15 de cara, y la frecuencia de las alucinaciones: la criatura que
  pasa (con su aura entera, que ahora sí miente) y la que se asoma por una
  puerta o espera al fondo de un pasillo.
- [ ] **La criatura:** balance de su alerta, de su agresividad y de la
  propagación del ruido, en partidas humanas; y su ronda nueva y su búsqueda
  (se rinde a los 8–10 s sin pistas y se va a más de 38 m): si se siente
  menos tonta y si esconderse ahora sirve lo que tiene que servir.
- [ ] **El puntaje y la nota** (`game/services/run_score.gd`,
  `hotel_floor.PAR`): lo que vale cada cosa, los 40 minutos de referencia y
  los cortes de S/A/B/C salen de cuentas, no de partidas. Mirar qué notas dan
  las primeras cintas de verdad, si el más valioso es quien el equipo diría,
  y si los hitos de 30 y 20 minutos están donde deben.
- [ ] **El chillido del cazador cada 10 s** (antes 3 s, y se encadenaba): si
  sigue valiendo lo que cuesta o se queda corto para encontrar a nadie.
- [ ] **Rendimiento en un PC modesto:** medir `tools/benchmarks/run_bench.ps1`
  en uno de los de las pruebas con amigos, en Forward+ y en Compatibilidad, y
  anotarlo en [PERFORMANCE.md](PERFORMANCE.md).

## 2 · Deuda técnica

Nada de esto se ve jugando, y todo cuesta caro más adelante. Lo que había está
hecho y descrito en la guía de desarrollo. Lo que aparezca va aquí.

### Bots de prueba

Juegan el piso entero solos, lo recorren mirando, se graban y se repasan en el
observador (todo descrito en la guía de desarrollo). Falta:

- [ ] **Mirar con la repetición lo que ya encontraron** (lote
  `20260923-165656-f4_clemencia_v2` y siguientes): bots que se atascan contra
  una puerta abierta con el siguiente punto de su ruta a medio metro
  (habitación 121 de la planta 1 en la semilla 86, habitación 218 de la
  planta 2 en la 82) —en la 82, la criatura agota su protocolo de atascos en
  esa misma sala y el vigilante la da por encerrada—, y la criatura
  encerrada o atascada en otras semillas (83, 90). Decidir cuáles son del
  juego y cuáles del bot.
- [ ] **La tabla de lo que se ve** (`tools/bots/bot_senses.gd`): contrastarla
  con una partida de verdad, sobre todo las notas (9 m con luz, 12 con
  linterna, 1,5 a oscuras) y las teles en el nicho de las suites.

### Fallos menores conocidos

Salieron en la revisión del 22 de septiembre y se dejaron para más adelante:
no rompen nada.

- [ ] Los subtítulos no se borran al morir ni en las pantallas de pausa y fin
  (`ui.subtitle` solo se limpia desde `drive_local` con el jugador vivo).
- [ ] Al apagarse la luz, el volumen de luz rebotada se oculta y
  `hotel.update_visibility` lo vuelve a mostrar a los 0,25 s: no mira `dark`.
- [ ] El apagón también apaga el panel del coche del ascensor: comparte el
  material `"light"` que `held_glows` pone a cero.
- [ ] Los nombres de las teclas salen con la distribución de EE. UU. (en un
  teclado español la Ñ se ve como «;»): `settings_service.key_name`.
- [ ] Mover un deslizador de ajustes guarda en disco y reaplica la calidad de
  todo el piso en cada paso.
- [ ] Órdenes de red que se aceptan de cualquier peer y solo importan con un
  cliente modificado: `locust_call` sin comprobar el remitente, y
  `request_lift`, `request_container` y `request_television` aceptadas del
  cazador.
- [ ] «Reintentar» online falla sin avisar si el asiento del cazador se ha
  ido (`start_match` devuelve un error que nadie mira).
- [ ] Los efectos de la cinta y la lente se miden en píxeles de pantalla
  (`analog.gdshader`, `lens.gdshader`, el halo de `camcorder_effect.gd`): a
  4K el borrón de color y el halo son unas tres veces más finos que a 720p.
- [ ] El negro del golpe empieza unos centímetros al lado de la mano: se
  proyecta antes de la curvatura de la lente (`strike_on_screen`).
- [ ] El cazador oye como contactos las puertas que abre él mismo y el ruido
  de su propia salida por una tele.
- [ ] Cuando el anfitrión no oye un gruñido de la IA, lo reintenta a los 1,6 s
  aunque ya se haya mandado a todos: los invitados la oyen gruñir más a menudo.
- [ ] El bucle de presencia de la criatura sigue a su último nivel durante
  los 1,2 s del cambio de etapa.
- [ ] La lectura acústica dentro del observador (`V`) sale mucho más pobre que
  la del cazador: los granos se escriben (8000 cerca de la cámara, medidos)
  pero apenas se dibujan. Mientras, la vista de verdad es
  `./tools/godot.ps1 locust`.
- [ ] En Compatibilidad en Ultra, en una de dos capturas iguales la linterna
  no alumbró nada en dos tomas de cuatro (sala oscura, 65 luces con sombra a
  la vista); en la otra, sí. No es el límite de luces por objeto (se probó con
  32). Puede ser la compilación de una variante de shader: mirar si se ve
  jugando.
- [ ] Cuando se cierra la sala de una partida que el observador miraba, se
  queda en ese piso, parado y sin criatura, y el panel sigue diciendo «en la
  sala» (`net.observing` no se apaga al salir). Debería volver a un piso suyo;
  mientras, R.

## 3 · Acabado de lo que ya existe

Afina algo que funciona: va después de que funcione bien. Del cierre del piso
de The Locust ya están el mando, el parte al salir y las marcas, todos
descritos en el diseño; queda el sonido del ascensor (apartado 4), que tapa un
silencio que hoy se oye raro al cerrar cada sector, y probar el mando en
partida: que la sensibilidad por defecto no se quede corta ni larga, y que se
pueda jugar entero sin tocar el teclado.

- [ ] **La captura, lo que queda de código** (rehecha el 12 de octubre:
  sobresalto, cámara caída, cinta, finta de armario y repetición; qué se hizo,
  con qué se comprobó y qué falta, en [EXECUTION.md](EXECUTION.md), sección
  18). Lo que hay que juzgar jugando está en el apartado 1.
  - [ ] Sin la embestida, lo que DIFFICULTY.md mide de cada dificultad
    (cuántas persecuciones acaban en huida) está sin volver a medir con bots.
  - [ ] Los brazos de la propia bestia atraviesan paredes en sitios
    estrechos (no se ha tocado: solo el cuerpo de la víctima), y el
    Detective Masculino, sin esqueleto, no se puede corregir hueso a hueso.
  - [ ] La estocada del jugador que lleva a la bestia (versus) conserva sus
    0,3 s de preparación y su ladrido: decidir si también va a 0.
  - [ ] Las poses del cuerpo en la captura (colgando, tendido, sentado) están
    hechas mirando a la Exploradora: ajustarlas al Detective Femenino, que
    las hereda por los huesos comunes. El Detective Masculino no tiene
    esqueleto y solo se inclina (apartado 4).
  - [ ] Una prueba de red que mire la escena desde la máquina de un testigo
    (hoy los cuatro escenarios pasan, y uno ejecuta a alguien sacándolo de un
    armario, pero ninguno compara lo que ve cada máquina).
  - [ ] Los 4,7 s de la bestia quieta (eran 4,2; el medio segundo es la caída
    de la cámara), que el autor quiere revisar después.
  - [ ] Idea aparcada: el final «se lo lleva» (EXECUTION.md, 7.4).
- [ ] **Que dos partidas no se recuerden iguales.** Los tres sectores son
  siempre refugio, televisores y código, y en ese orden: la planta cambia y la
  partida no. Basta una condición alternativa que pueda salir en el sector 2 o
  en el 3. Es la única de esta lista que es decisión de diseño, no de código.
- [ ] **Sonido del hotel:** fuentes espaciales fijas, acústica por recinto,
  pasos, conductos, tuberías y silencio contextual.
- [ ] **Los cinco audios aportados:** escucha y selección definitiva, edición de
  las copias y procedencia documentada.
- [ ] **Materiales PBR terminados**, reflejos y composición de las escenas de
  referencia; efectos de conductos y variedad artística.
- [ ] **Texturas fotográficas CC0** seleccionadas e importadas con su licencia
  registrada, y revisión visual de la legibilidad en las zonas oscuras.
- [ ] **Sustituir el mobiliario provisional** por assets adecuados y
  acreditados, poco a poco.
- [ ] **Accesibilidad, mezcla y rendimiento sostenido** en la escena más
  exigente.
- [ ] **Cuatro dificultades de la IA** (Apacible, Equilibrada, Desafiante y
  Pesadilla), en individual y en cooperativo. Lo de hoy es Desafiante, y en
  las cuatro la bestia aparece a menudo: lo que sube es lo difícil que es
  salir de cada encuentro. La hoja de ruta entera —palancas, conductas,
  objetivos y lo decidido el 4 de octubre— está en
  [DIFFICULTY.md](DIFFICULTY.md). Por fases:
  - [ ] 3 · Apacible y Equilibrada, por números.
  - [ ] 4 · Las conductas de Apacible: la escena de «me salvé». Están
    hechas (duda, cansancio, gruñido, armarios, encuentros del director) y
    medidas (DIFFICULTY.md, segunda medida): más encuentros y huidas en
    Apacible, pero once caídas por piso, Equilibrada con expertos al 60 %, y
    ratos largos sin ella tras cada caída. Falta: un cruce al acabar el
    descanso, salir más de una persecución en Equilibrada y novatos que se
    escondan.
  - [ ] 5 · Las conductas y los números de Pesadilla.
  - [ ] 6 · Individual frente a equipo: el tamaño del equipo (la etapa
    devuelta a solas ya está).
  - [ ] 7 · La dificultad en las marcas.
  - [ ] 8 · Los números finales, con gente.
- [ ] **Cosas que hacen mucho ruido, para distraer a la bestia** (idea del
  25 de septiembre): radios, despertadores y parecidos repartidos por el
  piso, que un superviviente pone en marcha y suenan fuerte y seguido; la
  criatura va a por ellos y tiene que romperlos para que callen. Por decidir:
  cuántos por planta, si se gastan, cuánto la retienen y cómo lo usa el
  director (que hoy tira sus propias distracciones).
- [ ] **Cajas y basureros que se empujan y delatan** (idea del 6 de octubre
  de 2026): al pasar junto a una caja se la empuja suavemente y cae con
  buenas físicas y algo de ruido; un basurero, si se pasa por encima, se
  vuelca y suena a metal, más o menos fuerte según dónde caiga y con qué
  fuerza. Da calidad de vida y realismo, y el ruido tiene que delatar a quien
  lo hace ante la bestia. Los sonidos de cajas y basureros los trae el autor
  (apartado 4). Por decidir al hacerlo: qué objetos de los que ya hay pasan a
  ser físicos, cómo se sincronizan en red y cuánto oye la criatura.

## 4 · Assets que faltan (tuyos)

- [ ] **El sonido propio del ascensor**: motor y hojas. Hoy solo se oye la
  puerta que ya existía, y es el silencio más audible del piso: cada cierre de
  sector pasa por él.
- [ ] **La campanilla del ascensor que trae a la criatura**
  (`assets/audio/events/lift_ding.ogg`): el hueco está hecho
  (`lifts.LIFT_DING`, en todo el piso donde sale) y suena en cuanto el
  archivo exista; hasta entonces, silencio.
- [ ] **Sonidos de cajas y basureros** (cartón que cae, metal que se vuelca
  y rueda, a varias fuerzas), para los objetos que se empujan del apartado 3.
- [ ] **Un detective masculino con esqueleto.** El de ahora es un OBJ sin
  huesos: se queda con su movimiento viejo hasta que se reemplace, y la mano
  que se apoya en el suelo al agacharse llega al suelo pero no reparte el peso.
  En la captura es el único cuerpo que no cuelga, ni cae tendido, ni queda
  sentado: solo se inclina.
- [ ] **Sonidos propios para la captura.** Lo que hoy suena al caer la
  videocámara, al rozar la ropa mientras la bestia levanta el cuerpo y al
  caer el cuerpo son grabaciones prestadas de otras escenas, bajadas de tono
  (`object_fall_*`, `bed_shift`/`bed_stir`, `stomp_*`). Hacen falta: una
  carcasa de plástico contra moqueta y contra baldosa, roces de ropa, un
  cuerpo que cae sobre moqueta, y si se quiere, respiración o voz de la
  víctima —grabadas, no sintetizadas—.

## 5 · Lo nuevo: los otros tres pisos

No empieza hasta que lo de arriba esté cerrado. **Qué son los cuatro pisos**
quedó dicho el 5 de octubre de 2026 (la historia entera, en
[LORE.md](LORE.md)): se baja de la fachada a lo que escondía.

| Piso | Nombre | Criatura | Estado |
|---|---|---|---|
| 1 | El hotel | The Locust | Jugable |
| 2 | Las oficinas secretas (La Oficina) | Sin definir | Sin empezar |
| 3 | Radiation Lab | Sin asignar | Sin empezar |
| 4 | The Containment | Sin asignar | Sin empezar |

- [ ] **Decidir qué criatura lleva cada piso** (la del 2 está sin definir) y
  lo demás que LORE.md deja abierto: quién juega, cómo se nota el ente que
  dirige a la bestia, cómo acaba.
- [ ] **Las oficinas secretas:** su conjunto procedural, su criatura y sus
  papeles.
- [ ] **Radiation Lab:** lo mismo, con lo que la radiación le hace al sitio.
- [ ] **The Containment:** lo mismo; es donde estaban guardadas todas.

Las tres criaturas ya pensadas, todavía sin piso:

- [ ] **Sunman**: cobertura y barridos anunciados (se pensó para atrios y
  galerías).
- [ ] **The Boiled One**: pantallas, con su exposición comprobada (se pensó
  para habitaciones y salones).
- [ ] **Guilt** con señales contrastables; nunca falsifica la hoja ni la
  interfaz esencial.
- [ ] **Perfiles sonoros propios** para las tres.
- [ ] **Tres conjuntos procedurales más**, con mil semillas validadas cada uno.
- [ ] **La campaña de cuatro pisos:** checkpoints entre ellos, reaparición de
  los caídos y victoria final.
- [ ] **Campañas completas de dos y cuatro jugadores sin bloqueos.**

## 6 · Consolidación y cierre

- [ ] **Los nueve eventos** de las otras criaturas.
- [ ] **Los doce descubrimientos restantes**, registro de partidas y códigos
  compatibles, sin progresión de poder.
- [ ] **Balance del director**, jugado por personas: si las pistas acercan
  demasiado o demasiado poco, si el pico dura lo que tiene que durar y si el
  respiro se nota (constantes al principio de `pacing_director.gd`); y
  revisión de los textos de los documentos.
- [ ] **Desafíos opcionales** sin condiciones ocultas de derrota.
- [ ] **Balance con datos locales:** objetivo 60 FPS a 1080p y perfiles
  reducidos que se sostengan.
- [ ] **Permisos** de criaturas, modelos y canción, créditos, y exportaciones
  sin editor.
