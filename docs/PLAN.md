# The Four — Plan de trabajo

**Lo que falta, en el orden en que hay que hacerlo.** Nada de lo ya hecho vive
aquí: el juego que existe se describe en [el diseño](GAME_DESIGN.md), cómo está
montado en [la guía de desarrollo](DEVELOPMENT.md), y el registro de cómo se
llegó hasta aquí —con todo lo comprobado, medido y fechado— quedó en
[history/PLAN_2026-09-21.md](history/PLAN_2026-09-21.md).

Estado: juego **0.5**, generador de mapas **v7** (tres plantas enteras), protocolo de red
**the-four-net-9**, Godot 4.7.2. Cada casilla es trabajo por hacer; se marca
cuando está **comprobado**, no cuando está escrito. Lo que se comprueba con
`./tools/verify.ps1` y las demás herramientas está en la guía de desarrollo.

## Dónde estamos (23 de septiembre de 2026)

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
- [ ] **La ejecución:** el grito (¿asusta o solo molesta?), los 4,2 s, y si la
  estática se entiende como «te mataron» sin leer nada. Y la de otro, que
  ahora se oye desde cualquier punto del piso: si a lo lejos (−24 dB como
  mucho por debajo, con eco) se entiende como «han pillado a alguien» y hacia
  dónde.
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
- [ ] **La linterna en Compatibilidad en Alto y Ultra**, a más de diez metros,
  ahora que el atlas de sombras se queda en 4096 en ese renderizador.
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
  - El desgarro de la cinta y el silencio antes de un golpe solo salen si la
    criatura está a menos de 10 m.
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

- [ ] **La cordura:** dos minutos de armario, dos y medio a oscuras, cuatro de
  luz para recuperarse, y la frecuencia de las alucinaciones. Decidir además si
  el aura (`dread_aura.gd`) debe mentir con la cordura baja, como las
  alucinaciones sueltas.
- [ ] **La criatura:** balance de su alerta, de su agresividad y de la
  propagación del ruido, en partidas humanas.
- [ ] **El chillido del cazador cada 10 s** (antes 3 s, y se encadenaba): si
  sigue valiendo lo que cuesta o se queda corto para encontrar a nadie.
- [ ] **Rendimiento en un PC modesto:** medir `tools/benchmarks/run_bench.ps1`
  en uno de los de las pruebas con amigos, en Forward+ y en Compatibilidad, y
  anotarlo en [PERFORMANCE.md](PERFORMANCE.md).

## 2 · Deuda técnica

Nada de esto se ve jugando, y todo cuesta caro más adelante. Lo que había está
hecho y descrito en la guía de desarrollo. Lo que aparezca va aquí.

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
- [ ] Cuando se cierra la sala de una partida que el observador miraba, se
  queda en ese piso, parado y sin criatura, y el panel sigue diciendo «en la
  sala» (`net.observing` no se apaga al salir). Debería volver a un piso suyo;
  mientras, R.

## 3 · Acabado de lo que ya existe

Afina algo que funciona: va después de que funcione bien. Del cierre del piso
de The Locust ya están el mando, el parte al salir y los mejores tiempos, todos
descritos en el diseño; queda el sonido del ascensor (apartado 4), que tapa un
silencio que hoy se oye raro al cerrar cada sector, y probar el mando en
partida: que la sensibilidad por defecto no se quede corta ni larga, y que se
pueda jugar entero sin tocar el teclado.

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

## 4 · Assets que faltan (tuyos)

- [ ] **El sonido propio del ascensor**: motor y hojas. Hoy solo se oye la
  puerta que ya existía, y es el silencio más audible del piso: cada cierre de
  sector pasa por él.
- [ ] **Un detective masculino con esqueleto.** El de ahora es un OBJ sin
  huesos: se queda con su movimiento viejo hasta que se reemplace, y la mano
  que se apoya en el suelo al agacharse llega al suelo pero no reparte el peso.

## 5 · Lo nuevo: los otros tres pisos

No empieza hasta que lo de arriba esté cerrado.

- [ ] **Sunman** en atrios y galerías: cobertura y barridos anunciados.
- [ ] **The Boiled One** en habitaciones y salones con pantallas, con su
  exposición comprobada.
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
- [ ] **Balance del director** (frecuencia y distancia de los eventos) y
  revisión de los textos de los documentos.
- [ ] **Desafíos opcionales** sin condiciones ocultas de derrota.
- [ ] **Balance con datos locales:** objetivo 60 FPS a 1080p y perfiles
  reducidos que se sostengan.
- [ ] **Permisos** de criaturas, modelos y canción, créditos, y exportaciones
  sin editor.
