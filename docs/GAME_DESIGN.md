# The Four — Diseño

Qué es el juego y por qué reglas se rige. El estado, el orden de trabajo y lo que falta están en [el plan](PLAN.md); aquí se describe el juego, marcando lo que todavía no existe.

## Estado real y cambio de dirección

La versión **0.5** tiene un piso jugable solo, en cooperativo de 2 a 5 o en versus con un jugador llevando a The Locust. Están el hotel procedural con salida y refugio, la red por IP o LAN, la hoja compartida, los armarios, la ejecución, la visión de ecolocalización del cazador y la oscuridad real de las salas apagadas. Siguen sin existir los otros tres pisos y sus criaturas, las tres etapas que deben estructurar el piso (teles, cerradura de código y apagón), la cordura y las animaciones definitivas de los supervivientes. Las pruebas con amigos de septiembre de 2026 dejaron claro que el piso se resuelve demasiado rápido: eso es lo que se está corrigiendo. No se presenta como completo.

El antiguo H1 de fusibles se conserva como prototipo histórico en `legacy/fuse_prototype/main.tscn`; ya no es la escena principal ni determina la victoria del juego nuevo. Su informe no acredita la generación o supervivencia actuales. Los planes anteriores están archivados en `history/`.

La experiencia final será de terror ambiental cooperativo para **2–5 jugadores**, con modo individual y modo versus. El jugador explora un hotel imposible, escucha, investiga, se esconde y ayuda a otros a salir. La vulnerabilidad y el ritmo producen la sensación de estar inmerso en una película; el jugador conserva el control de su personaje.

- Encontrar y cruzar la salida sustituye todos los objetivos obligatorios de tres piezas.
- La salida está disponible desde la generación. No necesita fusibles, relés, transmisores, autenticaciones, llaves, consumibles ni tiempo mínimo de supervivencia.
- Investigar proporciona información y narrativa opcional. No desbloquea la salida.
- Cuatro pisos, una criatura principal por piso, sin combate, fabricación, mejoras permanentes o búsqueda sistemática de recursos.
- Linterna sin batería consumible en esta primera versión.
- Duración objetivo: **25–40 minutos por piso**, 100–160 minutos por campaña sin reintentos. Es una meta de balance pendiente de partidas humanas. Encontrar antes la salida es válido.

## Escena de entrada

Un recorrido nuevo empieza en un dormitorio a oscuras con solo un televisor grande (unos 80 cm) encendido. Se despierta despacio, se incorpora y se inclina hacia la pantalla apoyándose en la cama, que cruje. En la tele se ve The Locust (el mismo modelo del juego) en una esquina empapelada: se asoma desde el borde, mira, se abalanza hacia el objetivo y golpea el cristal desde dentro con el brazo; cada golpe raja el vidrio justo donde impacta. Antes de que se rompa, el personaje se levanta y va hacia la puerta con pasos marcados, sale, se gira de golpe para cerrarla (la pantalla estalla detrás) y corre por el pasillo oscuro mientras golpean la puerta. Cruza la habitación iluminada del fondo y abre su otra puerta hacia la recepción, donde parpadea la luz roja que marca el inicio del piso; la imagen se rompe en estática y empieza la partida. Dura unos 40 s, el ratón mueve un poco la mirada mientras está en la cama y se puede saltar manteniendo E (lo recuerda un texto pequeño arriba a la derecha durante los primeros segundos: «E  para saltar cinemática»). No se repite al continuar ni al reintentar.

La recepción inicial no tiene carteles: la señala una lámpara roja de emergencia que parpadea en el techo, para orientarse de vuelta al punto de partida.

The Locust usa en todo el juego un aspecto basado en la imagen de referencia `assets/images/the-locust.png`: cuerpo negro como tinta y máscara pálida con ojos y boca huecos.

## Supervivencia, refugio y progreso

**Un piso son tres alas y tres etapas.** El hotel se genera en tres bandas de habitaciones que **no se comunican entre sí**: el único paso de una a la siguiente es una puerta, la puerta de acceso de esa etapa, y la habitación que la contiene es el refugio de esa etapa. Se empieza en el ala primera, como hasta ahora; al cerrar la etapa se abre esa puerta y se pasa al ala siguiente, que es otro conjunto de habitaciones. El ala que queda atrás deja de servir para nada: ni los objetivos ni la criatura tienen ya nada que hacer allí. Detrás de la tercera puerta —la de la cerradura de código— termina el piso.

Cada refugio protege solo durante su etapa: mientras se espera a pasar, quien está dentro está a salvo; una vez cruzada la puerta, esa sala es una sala más.

Medido sobre mil semillas: 42, 38 y 35 habitaciones por ala de media (nunca menos de 30), y el camino más corto que recorre las tres etapas pasa por 41 habitaciones de media, nunca menos de 20. Antes, una partida entera terminaba en un solo trayecto hasta la salida.

Entre etapa y etapa hay un latido de 1,2 s: el personaje se queda quieto, sale el aviso de la etapa nueva y se sigue jugando en el mismo hotel, sin pantallas por el medio.

La condición de la **etapa 1** es llegar al refugio con la cuota de supervivientes y que todos los vivos estén dentro. **Ya no hay nada que mantener pulsado:** cumplida la condición, la puerta de acceso se abre y cualquiera puede cruzarla; cruzarla es lo que cierra la etapa, y desde ese momento ese refugio deja de proteger. Una puerta que se ha abierto no se vuelve a cerrar, aunque alguien salga del refugio después. La condición de la **etapa 2** son los **televisores** del ala que abre: hay que encender tantos como supervivientes haya, con un mínimo de dos, y se generan dos de más, así que siempre sobra alguno y nunca hay un único camino. Están repartidos por sectores distintos y lejos de la puerta por la que se entra al ala. Encender uno no es gratis: el chasquido se oye como una puerta abriéndose despacio, así que la criatura sabe que alguien acaba de pasar por ahí. Una vez encendido no se apaga. El generador garantiza ocho salas con televisor en ese ala, pasen lo que pasen los tipos de habitación.

**El apagón.** Cuando solo queda una tele por encender, el piso entero se queda sin luz: plafones, lámparas de mesa, apliques, fluorescentes y la baliza roja de recepción, todo a la vez y para siempre. Solo quedan las teles encendidas y las linternas. A partir de ahí **la criatura caza sin gastar resistencia**. No se dice con palabras: se oye el corte y, en su lectura, los techos que ya no zumban le vuelven de golpe desde todos lados.

**Entre etapas vuelven los muertos.** Al pasar de ala, quien cayó se levanta y aparece con los demás en la entrada del ala nueva. Y un piso perdona **un** hundimiento: si en una etapa quedan menos vivos que la cuota, en vez de terminar, todos se levantan y esa etapa vuelve a empezar como se la encontraron (las teles se apagan otra vez). La segunda vez ya no hay a quién levantar.

**Encender una tele es abrirle una puerta a la criatura.** Desde un televisor encendido puede salir por cualquier otro encendido. Quien la lleva ve, al ponerse delante de uno, un mapa que solo dice **dónde está cada tele respecto a las demás**: puntos, sin salas, sin paredes y sin números; gira la cabeza para apuntar a uno y vuelve a interactuar para salir por él. Suena en las dos teles y deja un ruido donde aparece, así que no es gratis ni silencioso. La IA hace lo mismo cuando lleva un rato buscando sin encontrar a nadie, como mucho cada 25 s: la ventaja no es solo del cazador humano.

La condición de la **etapa 3** son **cuatro números** escondidos en cajones, cómodas, libreros y vitrinas del ala que abre, uno por sala y repartidos por sectores. Cualquier mueble con cajones se puede registrar, en todo el piso: se mantiene la interacción un segundo, **hace ruido** (como una puerta abriéndose despacio) y, si escondía un número, dice cuál es y qué lugar ocupa en el código. Un mueble ya registrado no vuelve a dar nada. Con los cuatro se tiene el código. La cerradura está junto a **la última puerta**, en la pared exterior del refugio de esa etapa: un teclado con su pantallita verde donde se teclean los cuatro números. Si el código no es, se borra y hay que volver a empezar; si lo es, la puerta se abre para todos y detrás hay un rellano. **Pisar ese rellano es terminar el piso.** En una partida de cuatro, el código está repartido entre cuatro cajones de habitaciones distintas, así que hay que decirse los números en voz alta.

La puerta de acceso de cada etapa está **cerrada con llave** hasta que esa etapa se cumple: no la abren los jugadores, ni la criatura, ni un portazo. Al cumplirse la condición se abre sola y ya no vuelve a cerrarse. La criatura, además, **se va detrás de los jugadores**: en cuanto se abre la puerta se le manda al ala nueva, para que no se quede cazando un ala por la que ya no va a pasar nadie.

El número de participantes se fija al comenzar el piso. Para avanzar deben sobrevivir `ceil(N / 2)`: uno de dos, dos de tres, dos de cuatro; uno en individual. Desconectarse no reduce el requisito.

La salida conduce a un refugio protegido. Quien llega puede dibujar en la hoja o regresar al laberinto para ayudar; al regresar pierde la protección y deja de contar como refugiado. **No se abandona a compañeros vivos:** todos los supervivientes deben estar en el refugio y alcanzar el mínimo. Confirmar durante tres segundos inicia la transición; soltar la interacción o abandonar el refugio cancela el progreso.

La captura elimina al jugador hasta el final de la etapa: al pasar a la siguiente vuelve de pie. Además, un piso perdona un hundimiento (ver arriba); a la segunda vez se acabó. Si ya no quedan suficientes vivos para alcanzar el mínimo, termina el intento. Quienes murieron reaparecen en el siguiente piso. Salvar a todos es un resultado ideal registrado, sin ventajas estadísticas.

La sesión separa el estado de cada jugador —explorando, refugiado o muerto— del estado global de partida, y la misma regla vale en individual y en red. F9 prueba la derrota únicamente en ejecución de desarrollo y fuera del refugio.

Checkpoint al inicio de cada piso; volver a Continuar o reintentar restaura esa distribución y el estado inicial, no la posición donde se salió. Guardar formato, versión del generador, semilla, piso y uso de respaldo. Escritura mediante archivo temporal y copia anterior; incompatibilidad explícita, sin reemplazo silencioso de mapas. Completar el primer piso termina esta entrega y elimina el checkpoint completado: los otros tres pisos todavía no existen.

## Menú y ajustes

Menú principal: Nueva partida, Continuar, Multijugador, Archivo, Ajustes, Créditos y Salir. Personaje está dentro de Multijugador (ver «Multijugador en red»). Continuar solo se habilita con un checkpoint compatible. Preferencias locales separadas del guardado de campaña.

Portada: detrás del menú se ve una habitación de hotel normal, iluminada por su lámpara, con una cámara en mano que deriva despacio. Al fondo, a la derecha y fuera del centro de la imagen, la puerta al pasillo está entreabierta (bisagra a la derecha) y The Locust se asoma desde detrás del marco izquierdo: por la rendija solo se ve la cara pálida, ladeada, con algún tic de cabeza. Es pequeño y oscuro a propósito, para que sorprenda a quien lo descubra.

- Gráficos: ventana/pantalla completa, resolución, preset gráfico Bajo/Medio/Alto/Ultra (fija también la escala de render), renderizador Forward+/Compatibilidad (al reiniciar), escala de render, sombras, límite de FPS y sincronización vertical.
- Imagen: intensidad VHS, grano, aberración cromática, movimiento de cámara y efectos reducidos. Sin desenfoque de movimiento.
- Controles: sensibilidad, inversión vertical, reasignación sin conflictos y restauración de controles. Esc, F9 y F11 se reservan.
- Audio: buses general, ambiente, música, efectos y peligro; subtítulos para sonidos relevantes.
- Pantalla: confirmación durante doce segundos con reversión automática si no se acepta.
- Esc pausa en individual; en línea abre un menú local sin detener el mundo. Perder el foco pausa solo la versión individual.

La versión actual conserva caminar a 3,8 m/s, correr a 6 m/s y salto. Interacción con línea de visión: puertas a 3,2 m y armarios a 2 m. Una puerta abierta a menos de 3 m se puede cerrar sin mirarla (a la espalda, huyendo). Puertas de hotel de apertura normal al pulsar/soltar, o lenta al mantener un segundo. Solo impide cerrar un cuerpo dentro del propio marco (±0,45 m); la hoja atraviesa a quien esté al lado y no empuja al jugador contra el marco.

## Hotel procedural

### Lenguaje espacial

Recepción, habitaciones, baños, salones, comedor, lavandería, almacenes, mantenimiento, vestíbulos, galerías, sala de lectura, televisión, oficina, guardarropa y jardín interior. Veinte definiciones base combinan función, altura y recetas de decoración. Las zonas domésticas incluyen subdivisiones interiores; no todo es un corredor de laboratorio.

Moqueta, papel mural, zócalos de madera, lámparas cálidas y fluorescentes. **Habitaciones a oscuras de verdad.** Alrededor del 40 % de las habitaciones, salones o pasillos que pueden apagarse (nunca recepción, salas de servicio, salones unidos ni refugio) tienen todo apagado: lámpara del techo, lámparas de pie y de mesa, y sus pantallas no brillan. Además la oscuridad se contagia: una sala apta junto a una oscura se apaga también con un 55 % de probabilidad, así que vienen en tramos (en las semillas medidas, entre el 39 y el 57 % de las salas aptas, 19 a 28 por piso, dos tercios con alguna vecina oscura). El hotel no tiene luz ambiente, así que en una sala apagada no se ve nada sin linterna: ni paredes, ni números de puerta (que ya no brillan solos), ni muebles. Una puerta cerrada no deja pasar la luz de la sala de al lado. Cada cara de una puerta lleva el número de la habitación que hay **detrás**: desde dentro de la 100, sus puertas muestran los números de los módulos vecinos. Techos de 3,15 m y salones seleccionados de 4,2 m y espacios comunes unidos de 4,8 m. Referencias reconocibles: mobiliario, números, cuadros, tapizados y, en etapas siguientes, manchas y fuentes de sonido.

Mobiliario inicial original y provisional: cama, mesita, lámpara, sofá, escritorio, televisión, teléfono, cuadros, maleta, carro, estantería, planta, papelera, cortina, recepción, mesa, armario, lavadora y lavabo. Son piezas geométricas reconocibles, no assets fotorrealistas terminados.

### Generación y garantías

1. Presupuesto de 100–140 módulos en 4–6 sectores. El generador v3 usa 100–132 módulos de 12/14/18 m por 12/16/20 m y cinco sectores. Agrupa módulos vecinos en salones de dos/tres piezas, incluidos contornos en L, retirando físicamente sus paredes y puertas interiores. La topología base sigue siendo ortogonal; no se promete geometría libre arbitraria.
2. Construir un grafo conectado, añadir ciclos, elegir tipos y salida y, por último, decorar. Inicio y salida son distintos.
3. Elegir salida entre posiciones cuya distancia desde el inicio sea al menos el 85% de la máxima del grafo. Existen distintos emplazamientos posibles por semilla.
4. Al menos cuatro ciclos; reducir las ramas sin salida demasiado largas. No encadenar más de tres módulos rectos de pasillo sin cambio espacial o bifurcación.
5. Semillas separadas para distribución, decoración y ambiente. Misma semilla y versión reproducen el mapa; geometría fija durante la partida.
6. Armarios solo en módulos que parecen habitaciones, como en un hotel: los pasillos, vestíbulos, salones unidos y espacios públicos no tienen; habitaciones dobles, simples, suites y guardarropa tienen dos (en paredes opuestas); sala de lectura, sala de TV, oficina y almacén tienen uno. Van junto a los perímetros. Sus accesos y salidas se comprueban físicamente; el balance para cuatro jugadores se validará con el cooperativo.
7. Decoración en posiciones reservadas, sin ocupar conectores ni pasos. Puertas de hotel: vano de 1,3 m y hoja de 1,2 m, por donde también pasa la criatura agachándose; comprobar con cápsula de jugador, no solo con un grafo.
8. Validar después de construir: centros libres, accesos a posiciones reservadas, barridos físicos entre habitaciones y ruta de navegación completa hasta la salida. Las hojas de puertas se verifican como mecanismos abribles por separado.
9. Hasta veinte intentos de distribución, luego respaldo fijo validado. Si falla la validación física, intentar respaldo; nunca habilitar un piso que no tenga ruta de salida validada.
10. Guardar cuándo se utilizó respaldo para reproducirlo al continuar o reintentar.

La navegación se calcula desde los cuerpos estáticos construidos, incluyendo interiores y accesos de escondites. Las puertas son obstáculos dinámicos tratados por la IA: apertura lenta y espera, sin atravesarlas. Durante el giro siguen bloqueando la visión de la criatura aunque se desactive su empuje sobre personajes. Las consultas de rutas largas eliminan el límite predeterminado de polígonos para validar la salida completa.

## Presentación y assets

Forward+ es el render principal de escritorio. Compatibility, elegible en Ajustes y sugerido en gráficas integradas, ofrece una alternativa reducida con la misma geometría y reglas. Presets y efectos no deben alterar rutas o pistas: toda lámpara visible conserva su sombra en todos, y la visión de eco de The Locust nunca da más información por calidad (Bajo reparte menos granos más grandes; Ultra, algo más finos y con halo).

El hotel usa materiales procedurales de moqueta y papel mural, luces localizadas, sombras próximas, niebla de profundidad, oclusión ambiental, niebla volumétrica en calidad alta y filtro VHS moderado. Menús, subtítulos e indicaciones se dibujan después del filtro. Las instancias se agrupan por habitación/material y se limita la presentación lejana; las colisiones y el mapa permanecen cargados.

El fotorrealismo sigue siendo una meta visual pendiente. Esta ampliación añade madera procedural, sondas de reflexión iniciales, polvo, cortinas móviles y niebla localizada. Siguen pendientes materiales PBR finales, composición definitiva, efectos de conductos y una colección coherente de sonidos. No se considerará logrado por aplicar un filtro.

Audio inicial: copia de `ambience.wav`, bucle a volumen reducido, fuente ambiental espacial y música anterior en su propio bus. Los cinco nuevos sonidos tienen inventario técnico con hashes y formatos. La selección auditiva definitiva y el catálogo completo de eventos pertenecen a la etapa 2. No usar la voz estridente como amenaza aleatoria sin aviso.

Separar ambiente, fuentes espaciales, eventos ocasionales, música y peligro. Dar espacio al silencio; reducir capas cuando aparezca una señal esencial. Los eventos ambientales iniciales no hacen daño ni simulan ataques inevitables.

Conservar originales. Priorizar mobiliario CC0/CC BY de escala compatible, con autor, fuente y licencia registrados. Si un modelo no es adecuado o no está disponible, usar geometría propia. La cama de Alex Jung revisada en Sketchfab tiene unas 738.000 caras y se descartó para repetición masiva; no fue descargada. El navegador accesible no comparte la sesión iniciada por el usuario en otro navegador.

Sunman se conserva como candidato para su piso. The Boy and The Bath es material adicional en evaluación y no sustituye a ninguno de los cuatro enemigos. Los permisos del Locust y la canción anterior continúan pendientes para distribución. Véase [ASSETS.md](ASSETS.md).

## Multijugador en red — implementado

**Conexión.** ENet con un anfitrión y hasta cuatro invitados (**2–5 jugadores**), por IP directa o LAN, puerto UDP 38430. Por Internet, el anfitrión abre ese puerto en su router. Sin Steam, matchmaking, voz ni migración de anfitrión: para hablar, Discord o similar. Todos deben usar el mismo exe (se comprueba versión de red y del generador).

**Menú Multijugador.** Nombre del jugador, **Crear sala**, **Unirse a una sala** (dirección del anfitrión), **Personaje** y Volver. La **Sala** muestra las plazas (1 anfitrión, 2–5 invitados), su personaje y las direcciones locales del anfitrión. Solo el anfitrión cambia las opciones:
- **Tipo de partida:** *Cooperativo contra IA* (todos sobreviven contra The Locust controlado por la IA) o *Versus* (un jugador es The Locust).
- **The Locust (versus):** *Al azar* o un jugador concreto de la sala.
- **Retomar el piso guardado** si existe su checkpoint en línea.
Empezar exige al menos dos jugadores conectados. Nombres repetidos se numeran.

**Autoridad.** Todas las máquinas generan el mismo piso desde la semilla del anfitrión y lo comprueban con una huella; nadie hace sorteos propios. Cada jugador mueve su cuerpo y lo envía unas veinte veces por segundo; los demás lo ven interpolado, con animación, linterna y pasos. El anfitrión decide puertas (índice estable por orden de construcción), armarios (quién entra), la criatura, las muertes, la salida y el final. Los ruidos de cada jugador se envían al anfitrión, donde escucha la criatura. El director de ritmo solo actúa en cooperativo, en el anfitrión, y sus sonidos se oyen en todas las máquinas.

**Cooperativo.** The Locust vigila y persigue a un superviviente cada vez (el que ve, o el más cercano). Mínimo para salir: `ceil(N / 2)` supervivientes (1/2, 2/3, 2/4, 3/5), todos los vivos dentro del refugio y cualquiera manteniendo la interacción tres segundos. Mirar a un compañero cercano muestra su nombre en los corchetes de enfoque.

**Muertes.** Quien muere observa a un compañero vivo **desde detrás del hombro**, con un brazo de cámara que choca con las paredes y los armarios: nunca se ve a través de ellos ni por dentro del modelo del compañero. Clic cambia de compañero. Sin cámara libre ni edición de la hoja. Esc abre un menú local sin detener la partida.

**Cuerpos.** Los jugadores nunca frenan a la criatura: su cuerpo no la bloquea. Al morir, el cuerpo desaparece de las pantallas de los demás y deja de estorbar en puertas y pasillos; un cuerpo desconectado o muerto tampoco impide cerrar una puerta.

**Reconexión.** Si un jugador se cae, su cuerpo se queda en el piso, expuesto, durante 60 s. Si vuelve con el mismo nombre recupera su plaza, reconstruye el piso y recibe el estado actual: puertas, armarios, posiciones, la criatura y la hoja. Pasado el plazo cuenta como baja de ese piso sin reducir el mínimo. Si se cae el anfitrión, los demás ven la explicación y vuelven al menú; el anfitrión puede retomar el piso con su checkpoint en línea.

**Final.** Solo el anfitrión elige: reintentar (tras perder), nueva partida, volver a la sala o cerrarla. Los invitados esperan o salen.

**Versus.** El jugador elegido controla a The Locust con cámara sobre el hombro. Anda a 2,8 m/s y **caza** a 6,4 m/s, más que el sprint de un superviviente. La caza dura unos 15 s seguidos y se recupera entera en unos 4,5 s tras medio segundo de descanso: **no se le escapa nadie corriendo en línea recta**; hay que romperle la línea de visión o esconderse bien.

- **Clic izquierdo:** estocada, con la misma preparación de 0,3 s y aviso sonoro que la IA. El anfitrión decide si alcanza a alguien (3,2 m, dentro de 70° de su frente, línea de visión; a un escondido solo con las puertas del armario abiertas). Que atrapó a alguien lo dice el propio movimiento de la ejecución, sin texto.
- **Pantalla despejada:** el cazador no ve controles, avisos de muerte ni las marcas de la videocámara (REC, reloj, enfoque: la criatura no graba nada). Solo quedan la barra de resistencia de caza y la cuenta atrás «LA CAZA EMPIEZA EN n», con la letra de la cámara y bajo el mismo filtro analógico que la imagen (fleco de color, grano).
- **Clic derecho, chillido:** un grito que dura lo mismo que el rojo de su vista (unos 4 s y 1,8 s de desvanecido, encadenando gruñidos agresivos) y se apaga con él; chillar otra vez mientras suena empieza un grito nuevo y lo alarga, así que quien lo repite no deja de sonar. Todos lo oyen desde su sitio. Delata dónde está, y a cambio le da información. Durante unos 4 s marca a los supervivientes a menos de 26 m con una nube que sigue ahí más de tres segundos después de callarse, y si encuentra a alguien, la caza no le cuesta resistencia durante 6 s y recupera parte de ella. **Solo encuentra lo que se mueve y está a la vista:** quien se queda helado al oír el grito, o está metido en un armario, no le devuelve nada. Es un intercambio: ruido por información y persecución, con una respuesta para el superviviente.
- **E:** puertas, y el ritual del armario (abajo). Andar contra una puerta la abre; cazando, la abre de golpe.
- **No ve el hotel: lo reconstruye.** Su pantalla es una imagen acústica en grises, hecha solo de puntos que siembran dos pulsos por segundo, con la memoria de lo que ya barrió, los cuerpos de quien tiene a la vista (congelados de pulso a pulso) y los ruidos que oye como nubes de puntos en el aire; puertas y armarios responden más fuerte que el resto. Al chillar, todo se vuelve rojo. Un ruido cerca se pinta donde ocurrió; de lejos, solo en la puerta por la que llega. La luz no existe para ella, así que **la oscuridad no esconde de un cazador humano**: hay que romperle la visión o esconderse bien en un armario. Meterse en un armario o salir de él lo oye desde las habitaciones vecinas, tan lejos como una puerta, 45 m (la IA, en cambio, solo de cerca), aunque su nube se apaga antes. Sustituye por completo los anillos rojos en 2D que había antes. Detalles en `docs/VISION_LOCUST.md`.
- Empieza con los mismos 15 s de protección, inmóvil. No oye su propia presencia ni el aura. Gana si quedan menos supervivientes que el mínimo («CAZA COMPLETA»); pierde si salen del piso («SE TE ESCAPARON»). Sin director en versus.

## Hoja paranormal — implementada

Hoja vacía por piso, abierta con **Tab** (reasignable). Botón izquierdo dibuja y derecho borra bajo el cursor. Sin mapa, posiciones, norte, salida ni enemigos automáticos. Abrirla detiene al personaje y oscurece la vista, pero no pausa el mundo; suena el papel una vez al abrirla. También existe en individual.

En línea es compartida por los supervivientes vivos: el anfitrión ordena trazos y borrados, quien dibuja los ve al instante y ocupan su lugar al confirmarse. Los trazos viajan en fragmentos diez veces por segundo con un límite de 30 fragmentos por segundo por jugador y 3.000 operaciones por hoja. Los muertos pueden mirarla sin editar; The Locust nunca la ve. Se restaura al reconectar y empieza vacía en cada piso o reintento. Guilt nunca falsifica esta superficie.

## Criaturas y ritmo — The Locust implementado; las otras tres criaturas, pendientes

The Locust individual implementa: patrulla, oído, visión, investigación, persecución, búsqueda y registro de armarios. Percibe al jugador desde mucho más lejos de lo que el jugador lo percibe a él: visión de 120° y 70 m con línea libre y sospecha gradual (3,2/s de cerca, 0,9/s a 70 m; más rápida con linterna o corriendo, más lenta agachado; baja 0,12/s sin visión). A 0,2 investiga. A 1, si te ve, primero se detiene, se gira hacia ti y chilla durante 1,2 s; después persigue, arrancando desde 2,5 m/s y acelerando a 3,2 m/s² (algo más de un segundo hasta la velocidad máxima). Ese margen es el momento de romper la línea de visión. Oye los ruidos siguiendo rutas caminables (atraviesa salas y puertas, no muros; en línea recta si tiene el sitio a la vista), hasta estas distancias (`HEARD` en `game/audio/noise_kinds.gd`, una sola tabla para todo): asomarse en un armario 10,5 m; pasos agachado 8 m (12 en baldosa); puerta abierta despacio 9 m; entrar o salir de un armario 12 m (45 m para un cazador humano); pasos caminando 20 m (25 en baldosa); salto 32 m; puerta normal 45 m; pasos corriendo 52 m (64 en baldosa); portazo 62 m. Una linterna que lo ilumina desde más de 5 m y hasta 45 m lo atrae. Persecución a 6,4 m/s, más rápida que el sprint; sin visión va a 5,2 m/s hacia la última posición vista u oída. Cada ruido durante la persecución actualiza su objetivo; sin verte 7 s pasa a búsqueda. Al perseguir abre las puertas de golpe sin esperar. Estocada: empieza a menos de 2,4 m, embiste durante 0,3 s y mata a menos de 3,2 m con línea de visión; desde el alcance de ataque es casi inevitable. Es un 18 % más grande (≈2,9 m) con zancadas más largas y se agacha bajo los dinteles. No mata por contacto ni atravesando muros.

**Ritual del armario (individual y en red).** Registrar un armario cuesta tiempo, a la IA y al jugador que lleva a la criatura: se planta delante, abre una hoja, luego la otra y mete el brazo; en total unos 2,5 s inmóvil. Si hay alguien dentro, ahí empieza la ejecución; si no, se queda un momento más antes de recuperar el control. Ya no puede recorrer una habitación abriendo armarios de pasada sin penalización.

**Ejecución.** Alcanzar a un superviviente no lo mata al instante. En el instante del agarre salta un grito muy feo, plano y alto en los oídos de la víctima y desde la criatura para todos los demás. La levanta en el aire ensartada en un brazo y **se la va acercando despacio a la cara**, mirándola, con el otro brazo echado atrás; a los 2,58 s ese brazo sale disparado hacia la cámara —desde la izquierda de la imagen, que es donde está su mano derecha— y en dos décimas pasa de un punto a tapar la lente entera de negro, y a los 2,8 s cae el golpe. Entonces la imagen de la víctima se va: nieve de canal muerto, con sus barras rodando y sus rayas de sincronismo, sonando de verdad, y sobre esa estática aparece SEÑAL PERDIDA. La señal vuelve sola: se limpia al pasar a mirar por encima del hombro de un compañero, y un piso nuevo siempre empieza con la imagen entera. Las marcas de la cámara (REC, reloj) desaparecen con la imagen. En individual eso lleva a la pantalla final; en cooperativo la partida sigue, así que la víctima se queda sin señal un par de segundos y después pasa a mirar por encima del hombro de un compañero. Dura 4,2 s en total (la baja se registra al final, así que el piso no se pierde hasta que acaba) y durante todos ellos la criatura está inmóvil. La criatura tampoco se ve frenada por los cuerpos de los jugadores.

**Se la oye antes de verla.** The Locust arrastra un aura —dron, respiración, chasquidos y latidos— que llega por la ruta caminable por la que se acerca, no en línea recta a través de los muros: dice por dónde viene sin decir exactamente dónde está. Se oye dentro de 26 m, entra y sale gradualmente, calla durante la protección inicial y dentro del refugio, y baja 16 dB mientras prepara la estocada, para que el aviso de ataque se distinga. Con auriculares es binaural (diferencia de tiempo y de nivel entre oídos) y lo que viene de detrás suena más apagado. El jugador que la lleva en versus no oye ni su propia presencia ni el aura. Asignaciones completas en [AUDIO.md](AUDIO.md).

Pasos por distancia recorrida con cadencia adulta: unos 2 pasos/s caminando, 2,5 corriendo (más fuertes) y 1,5 agachado; balanceo de cámara ligado a cada pisada y de pocos centímetros. Suenan pasos grabados sobre moqueta o, en baños, lavandería y mantenimiento, sobre baldosa (se oyen más lejos: entre un 25 y un 50 % según el paso); cada grabación arranca antes para que su golpe caiga en la pisada. Implementado agacharse a 2 m/s, resistencia 100, gasto al correr 8/s y recuperación 6/s tras 3 s de descanso; agotado no vuelve a correr hasta 30. La resistencia se muestra como un medidor segmentado de videocámara que desaparece al llenarse. Escondites: armarios grandes con doble puerta. Dentro, las puertas cerradas tapan la vista como una pared; manteniendo avanzar se entreabren despacio y la cabeza se asoma, con el campo de visión más amplio cuanto más abiertas. Mirando al frente se abren las dos a medias; al girar la vista a un lado se abre la puerta contraria, se cierra la otra y la cabeza sale por ese hueco, con la puerta abierta cubriéndola. Una puerta entreabierta delata al jugador si la criatura tiene línea de visión. Solo la primera apertura de cada estancia cruje. Si la criatura vio la entrada, o investiga un ruido junto a un armario ocupado, abre sus puertas y ataca. Dentro, la imagen se cierra con bordes oscuros y un leve ojo de pez que se abre al asomarse (desactivado con efectos reducidos). Escondites con entrada y salida libres; observar una entrada permite inspeccionarla. Las puertas retrasan, no conceden inmunidad fuera del refugio. Se añaden 15 s de protección inicial y aparición distante al empezar/reintentar, sin tiempo mínimo exigido para salir. Movimiento y preparación procedural del modelo son provisionales; las animaciones finales y permisos siguen pendientes.

- Sunman: atrios y galerías; aviso 2 s, barrido 4 s, descanso 6 s. Exposición +25/s, recuperación −20/s tras 1 s protegido, aviso a 70 y captura a 100. Cada cruce cabe en su ventana caminando más 1 s de margen.
- The Boiled One: televisores en habitaciones y salones; mirada central de 25°, exposición real tras 0,5 s. Intrusión +18/s, recuperación −12/s; avisos a 60/85 y captura a 100. No paralizar inevitablemente antes del umbral.
- Guilt: habitaciones repetidas y señales contradictorias, verificables con observación. Señuelos +20 de presión; aviso a 60, cacería anunciada de 20 s a 100 y reducción a 60 tras sobrevivir. Retirar la autenticación obligatoria y ajustar la recuperación mediante exploración segura al desarrollar ese piso.

Persianas, televisores y documentos son herramientas/pistas opcionales, nunca listas obligatorias de tareas. Las reglas son adaptaciones de juego, no afirmaciones sobre el canon.

Director (implementado para The Locust): 30 s sin nuevos eventos después de persecuciones o ataques, separación mínima de 45 s y como máximo un evento activo. Explorando, cada segundo hay una probabilidad de 1/25 de un evento con consecuencias: un objeto que cae en una sala a 9–26 m de recorrido (la criatura va a mirar ese punto) o pasos (su patrulla se desvía hasta una sala vecina a la del jugador). Tras 60 s sin encuentros ni salas nuevas solo se permiten golpes en una puerta, sin efecto sobre la criatura: quedarse quieto no provoca ataques. Nunca apunta a la posición del jugador, no altera capacidades, geometría ni recursos, y el refugio sigue siendo seguro.

Catálogo de doce eventos: golpes, objeto caído y pasos para Locust (implementados); sombra de aviso, persiana y zumbido para Sunman; pantalla anunciada, interfono e interferencia legible para Boiled One; indicación contrastable, puerta que imita un sonido y silueta sin ataque para Guilt. Cada uno tendrá condiciones, duración, enfriamiento y efecto; cancelar si no hay posición válida. Nunca falsificar controles, guardado, menús, accesibilidad ni hoja.

Descubrimientos opcionales persistentes: dieciséis entradas, cuatro por criatura, sin ventajas estadísticas. Implementados los cuatro de The Locust: documentos sobre mesas, escritorios y mesillas (dos por piso, lejos del inicio y en sectores distintos, fijos por semilla). Leer detiene al personaje sin pausar el juego, suena el papel y la entrada queda en **Archivo** del menú, también entre partidas. Dan contexto y pistas sobre la criatura, nunca mejoras. Registro de supervivientes, causas de muerte y campaña; códigos con semilla y versión. Desafíos de campaña sin reintentos y salida de todos con vida. Se retira el desafío basado en distractores obligatorios del diseño anterior. Ningún desafío añade derrota oculta.

## Aceptación

El orden de trabajo y lo que falta están en [PLAN.md](PLAN.md). Aquí queda solo lo que hay que demostrar para dar algo por bueno.

Hecho: las mil semillas del único conjunto que existe hoy, sin mapas aceptados que bloqueen (`./tools/godot.ps1 hotel-batch`, resultado en `evidence/hotel_batch.json`); persistencia y reversión de ajustes; sesiones reales de 2 a 5 jugadores con dibujos simultáneos, muertes y mínimos `ceil(N/2)`; captura, puertas y armarios fiables en individual y en red, comprobados por procesos reales en `./tools/verify.ps1`.

Pendiente: veinte recorridos manuales del primer piso y cinco partidas completas de exploración con la duración medida (hoy muy por debajo de la meta); campañas de dos y cuatro jugadores, que necesitan los otros tres pisos. Los recorridos automáticos se registran aparte de las partidas humanas y no las sustituyen; el protocolo está en [PLAYTEST_HOTEL.md](PLAYTEST_HOTEL.md).

Rendimiento objetivo: 60 FPS a 1080p en la RTX 4060 Ti del equipo, con tiempos de fotograma, carga y memoria. Medir, no asumir. Medidas por preset y vista en [PERFORMANCE.md](PERFORMANCE.md); estado y tareas en [PLAN.md](PLAN.md).

Fuentes técnicas consultadas: [renderizadores de Godot](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html), [multijugador](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html) y [sincronización de navegación](https://docs.godotengine.org/en/4.7/classes/class_navigationserver3d.html).

## Reglas que no se rompen

Todo lo de esta sección está implementado; se deja escrito porque son límites que ningún cambio posterior debe cruzar.

- **El posprocesado no cambia las reglas.** El encierro y el ojo de pez del armario, el filtro de videocámara y los efectos reducidos alteran lo que se ve, nunca lo que la criatura percibe ni lo que los demás jugadores ven desde fuera. Apagar la distorsión no revela ni esconde a nadie.
- **Los efectos no tocan lo esencial.** Menús, hoja, subtítulos y señales de peligro se dibujan por encima del filtro y no se distorsionan. Al salir del armario, morir o reintentar, la vista vuelve al estado normal.
- **Esconderse retrasa, no protege.** Un armario no concede inmunidad: si la criatura vio la entrada, o investiga un ruido al lado, lo abre. Solo el refugio es seguro.
- **El juego no miente sobre su propia interfaz.** Ninguna criatura falsifica controles, guardado, menús, accesibilidad ni la hoja compartida. Guilt engañará con señales del mundo, verificables observando, no con la interfaz.
- **Los eventos del director no hacen daño.** Nunca apuntan a la posición del jugador, no cambian capacidades, geometría ni recursos, y estarse quieto no provoca ataques.
- **El audio anuncia, no castiga.** La identidad sonora de una criatura no altera sus reglas de detección ni de ataque, y nada se reproduce como amenaza aleatoria sin aviso.
- **La calidad gráfica no da ventaja.** Toda lámpara visible conserva su sombra en todos los presets, y la visión de eco de The Locust no entrega más información por subir la calidad.
