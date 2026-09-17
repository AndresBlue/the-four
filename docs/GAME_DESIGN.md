# The Four — Diseño v0.4

## Estado real y cambio de dirección

La entrega **0.4-S1** amplía el hotel individual con módulos de dimensiones variables, salones unidos, distribuciones asimétricas, polvo, cortinas móviles, niebla localizada y reflejos iniciales. The Locust ya patrulla, oye, persigue y captura; existen agacharse, resistencia y escondites. Conserva menú, ajustes, salida libre, refugio y checkpoint. Cooperativo, hoja y campaña siguen pendientes. La aceptación de duración, balance y acabado visual requiere partidas humanas; no se presenta como completa.

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

El número de participantes se fija al comenzar el piso. Para avanzar deben sobrevivir `ceil(N / 2)`: uno de dos, dos de tres, dos de cuatro; uno en individual. Desconectarse no reduce el requisito.

La salida conduce a un refugio protegido. Quien llega puede dibujar en la hoja o regresar al laberinto para ayudar; al regresar pierde la protección y deja de contar como refugiado. **No se abandona a compañeros vivos:** todos los supervivientes deben estar en el refugio y alcanzar el mínimo. Confirmar durante tres segundos inicia la transición; soltar la interacción o abandonar el refugio cancela el progreso.

La captura elimina al jugador hasta el siguiente piso. No hay reanimación. Si ya no quedan suficientes vivos para alcanzar el mínimo, termina el intento. Quienes murieron reaparecen en el siguiente piso. Salvar a todos es un resultado ideal registrado, sin ventajas estadísticas.

En 0.4-S1 solo hay un participante real. La sesión separa su estado individual —explorando, refugiado o muerto— del estado global de partida. La cuota está preparada y probada como regla, pero eso **no constituye implementación de red**. F9 prueba la derrota únicamente en ejecución de desarrollo y fuera del refugio.

Checkpoint al inicio de cada piso; volver a Continuar o reintentar restaura esa distribución y el estado inicial, no la posición donde se salió. Guardar formato, versión del generador, semilla, piso y uso de respaldo. Escritura mediante archivo temporal y copia anterior; incompatibilidad explícita, sin reemplazo silencioso de mapas. En 0.4-S1 completar el primer piso termina la demostración y elimina el checkpoint completado.

## Menú y ajustes

Menú principal: Nueva partida, Continuar, Multijugador, Archivo, Ajustes, Créditos y Salir. Personaje está dentro de Multijugador (ver «Multijugador en red»). Continuar solo se habilita con un checkpoint compatible. Preferencias locales separadas del guardado de campaña.

Portada: detrás del menú se ve una habitación de hotel normal, iluminada por su lámpara, con una cámara en mano que deriva despacio. Al fondo, a la derecha y fuera del centro de la imagen, la puerta al pasillo está entreabierta (bisagra a la derecha) y The Locust se asoma desde detrás del marco izquierdo: por la rendija solo se ve la cara pálida, ladeada, con algún tic de cabeza. Es pequeño y oscuro a propósito, para que sorprenda a quien lo descubra.

- Gráficos: ventana/pantalla completa, resolución, escala de render, calidad baja/media/alta, sombras, límite de FPS y sincronización vertical.
- Imagen: intensidad VHS, grano, aberración cromática, movimiento de cámara y efectos reducidos. Sin desenfoque de movimiento.
- Controles: sensibilidad, inversión vertical, reasignación sin conflictos y restauración de controles. Esc, F9 y F11 se reservan.
- Audio: buses general, ambiente, música, efectos y peligro; subtítulos para sonidos relevantes.
- Pantalla: confirmación durante doce segundos con reversión automática si no se acepta.
- Esc pausa en individual; en línea abre un menú local sin detener el mundo. Perder el foco pausa solo la versión individual.

La versión actual conserva caminar a 3,8 m/s, correr a 6 m/s y salto. Interacción con línea de visión: puertas a 3,2 m y armarios a 2 m. Una puerta abierta a menos de 3 m se puede cerrar sin mirarla (a la espalda, huyendo). Puertas de hotel de apertura normal al pulsar/soltar, o lenta al mantener un segundo. Solo impide cerrar un cuerpo dentro del propio marco (±0,45 m); la hoja atraviesa a quien esté al lado y no empuja al jugador contra el marco.

## Hotel procedural

### Lenguaje espacial

Recepción, habitaciones, baños, salones, comedor, lavandería, almacenes, mantenimiento, vestíbulos, galerías, sala de lectura, televisión, oficina, guardarropa y jardín interior. Veinte definiciones base combinan función, altura y recetas de decoración. Las zonas domésticas incluyen subdivisiones interiores; no todo es un corredor de laboratorio.

Moqueta, papel mural, zócalos de madera, lámparas cálidas y fluorescentes. Alrededor de una de cada cinco habitaciones, salones o pasillos (nunca recepción, salas de servicio, salones unidos ni refugio) tiene la lámpara del techo apagada: solo la iluminan la linterna, las lámparas de los muebles y lo que entra por las puertas. Cada cara de una puerta lleva el número de la habitación que hay **detrás**: desde dentro de la 100, sus puertas muestran los números de los módulos vecinos. Techos de 3,15 m y salones seleccionados de 4,2 m y espacios comunes unidos de 4,8 m. Referencias reconocibles: mobiliario, números, cuadros, tapizados y, en etapas siguientes, manchas y fuentes de sonido.

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

Forward+ es el render principal de escritorio. Un lanzador Compatibility ofrece una alternativa reducida con la misma geometría y reglas. Calidades y efectos no deben alterar rutas o pistas.

0.4-P1 incorpora materiales procedurales de moqueta y papel mural, luces localizadas, sombras próximas, niebla de profundidad, oclusión ambiental, niebla volumétrica en calidad alta y filtro VHS moderado. Menús, subtítulos e indicaciones se dibujan después del filtro. Las instancias se agrupan por habitación/material y se limita la presentación lejana; las colisiones y el mapa permanecen cargados.

El fotorrealismo sigue siendo una meta visual pendiente. Esta ampliación añade madera procedural, sondas de reflexión iniciales, polvo, cortinas móviles y niebla localizada. Siguen pendientes materiales PBR finales, composición definitiva, efectos de conductos y una colección coherente de sonidos. No se considerará logrado por aplicar un filtro.

Audio inicial: copia de `ambience.wav`, bucle a volumen reducido, fuente ambiental espacial y música anterior en su propio bus. Los cinco nuevos sonidos tienen inventario técnico con hashes y formatos. La selección auditiva definitiva y el catálogo completo de eventos pertenecen a la etapa 2. No usar la voz estridente como amenaza aleatoria sin aviso.

Separar ambiente, fuentes espaciales, eventos ocasionales, música y peligro. Dar espacio al silencio; reducir capas cuando aparezca una señal esencial. Los eventos ambientales iniciales no hacen daño ni simulan ataques inevitables.

Conservar originales. Priorizar mobiliario CC0/CC BY de escala compatible, con autor, fuente y licencia registrados. Si un modelo no es adecuado o no está disponible, usar geometría propia. La cama de Alex Jung revisada en Sketchfab tiene unas 738.000 caras y se descartó para repetición masiva; no fue descargada. El navegador accesible no comparte la sesión iniciada por el usuario en otro navegador.

Sunman se conserva como candidato para su piso. The Boy and The Bath es material adicional en evaluación y no sustituye a ninguno de los cuatro enemigos. Los permisos del Locust y la canción anterior continúan pendientes para distribución. Véase [ASSETS.md](ASSETS.md).

## Multijugador en red — implementado (pendiente de sesiones humanas)

**Conexión.** ENet con un anfitrión y hasta cuatro invitados (**2–5 jugadores**), por IP directa o LAN, puerto UDP 38430. Por Internet, el anfitrión abre ese puerto en su router. Sin Steam, matchmaking, voz ni migración de anfitrión: para hablar, Discord o similar. Todos deben usar el mismo exe (se comprueba versión de red y del generador).

**Menú Multijugador.** Nombre del jugador, **Crear sala**, **Unirse a una sala** (dirección del anfitrión), **Personaje** y Volver. La **Sala** muestra las plazas (1 anfitrión, 2–5 invitados), su personaje y las direcciones locales del anfitrión. Solo el anfitrión cambia las opciones:
- **Tipo de partida:** *Cooperativo contra IA* (todos sobreviven contra The Locust controlado por la IA) o *Versus* (un jugador es The Locust).
- **The Locust (versus):** *Al azar* o un jugador concreto de la sala.
- **Retomar el piso guardado** si existe su checkpoint en línea.
Empezar exige al menos dos jugadores conectados. Nombres repetidos se numeran.

**Autoridad.** Todas las máquinas generan el mismo piso desde la semilla del anfitrión y lo comprueban con una huella; nadie hace sorteos propios. Cada jugador mueve su cuerpo y lo envía unas veinte veces por segundo; los demás lo ven interpolado, con animación, linterna y pasos. El anfitrión decide puertas (índice estable por orden de construcción), armarios (quién entra), la criatura, las muertes, la salida y el final. Los ruidos de cada jugador se envían al anfitrión, donde escucha la criatura. El director de ritmo solo actúa en cooperativo, en el anfitrión, y sus sonidos se oyen en todas las máquinas.

**Cooperativo.** The Locust vigila y persigue a un superviviente cada vez (el que ve, o el más cercano). Mínimo para salir: `ceil(N / 2)` supervivientes (1/2, 2/3, 2/4, 3/5), todos los vivos dentro del refugio y cualquiera manteniendo la interacción tres segundos. Mirar a un compañero cercano muestra su nombre en los corchetes de enfoque.

**Muertes.** Quien muere observa a un compañero vivo desde su cámara (clic para cambiar), sin cámara libre ni edición de la hoja. Esc abre un menú local sin detener la partida.

**Reconexión.** Si un jugador se cae, su cuerpo se queda en el piso, expuesto, durante 60 s. Si vuelve con el mismo nombre recupera su plaza, reconstruye el piso y recibe el estado actual: puertas, armarios, posiciones, la criatura y la hoja. Pasado el plazo cuenta como baja de ese piso sin reducir el mínimo. Si se cae el anfitrión, los demás ven la explicación y vuelven al menú; el anfitrión puede retomar el piso con su checkpoint en línea.

**Final.** Solo el anfitrión elige: reintentar (tras perder), nueva partida, volver a la sala o cerrarla. Los invitados esperan o salen.

**Versus.** El jugador elegido controla a The Locust con cámara sobre el hombro. Anda a 2,8 m/s y **caza** a 6,4 m/s (más que el sprint de un superviviente) mientras dura su resistencia de caza (unos 8 s, se recupera tras 1,5 s de descanso). **Clic izquierdo:** estocada con la misma preparación de 0,3 s y aviso sonoro que la IA; el anfitrión decide si alcanza a alguien (3,2 m, dentro de 70° de su frente, línea de visión; a un escondido solo con las puertas del armario abiertas). **Clic derecho:** chillido. **E:** puertas y abrir armarios a la fuerza; andar contra una puerta la abre y cazando la abre de golpe. Los ruidos que la criatura oiría (pasos, puertas, armarios, saltos) le aparecen en pantalla como anillos rojos, también a través de paredes si llegan por una ruta: es su oído de largo alcance. Empieza con los mismos 15 s de protección, inmóvil. No oye su propia presencia ni el aura. Gana si quedan menos supervivientes que el mínimo («CAZA COMPLETA»); pierde si salen del piso («SE TE ESCAPARON»). Sin director en versus.

## Hoja paranormal — implementada

Hoja vacía por piso, abierta con **Tab** (reasignable). Botón izquierdo dibuja y derecho borra bajo el cursor. Sin mapa, posiciones, norte, salida ni enemigos automáticos. Abrirla detiene al personaje y oscurece la vista, pero no pausa el mundo; suena el papel una vez al abrirla. También existe en individual.

En línea es compartida por los supervivientes vivos: el anfitrión ordena trazos y borrados, quien dibuja los ve al instante y ocupan su lugar al confirmarse. Los trazos viajan en fragmentos diez veces por segundo con un límite de 30 fragmentos por segundo por jugador y 3.000 operaciones por hoja. Los muertos pueden mirarla sin editar; The Locust nunca la ve. Se restaura al reconectar y empieza vacía en cada piso o reintento. Guilt nunca falsifica esta superficie.

## Criaturas y ritmo — Locust individual implementado; resto pendiente

The Locust individual implementa: patrulla, oído, visión, investigación, persecución, búsqueda y registro de armarios. Percibe al jugador desde mucho más lejos de lo que el jugador lo percibe a él: visión de 120° y 70 m con línea libre y sospecha gradual (3,2/s de cerca, 0,9/s a 70 m; más rápida con linterna o corriendo, más lenta agachado; baja 0,12/s sin visión). A 0,2 investiga. A 1, si te ve, primero se detiene, se gira hacia ti y chilla durante 1,2 s; después persigue, arrancando desde 2,5 m/s y acelerando a 3,2 m/s² (algo más de un segundo hasta la velocidad máxima). Ese margen es el momento de romper la línea de visión. Oye los ruidos del jugador a 2,6 veces su radio siguiendo rutas caminables (atraviesa salas y puertas, no muros). Una linterna que lo ilumina desde más de 5 m y hasta 45 m lo atrae. Persecución a 6,4 m/s, más rápida que el sprint; sin visión va a 5,2 m/s hacia la última posición vista u oída. Cada ruido durante la persecución actualiza su objetivo; sin verte 7 s pasa a búsqueda. Al perseguir abre las puertas de golpe sin esperar. Estocada: empieza a menos de 2,4 m, embiste durante 0,3 s y mata a menos de 3,2 m con línea de visión; desde el alcance de ataque es casi inevitable. Es un 18 % más grande (≈2,9 m) con zancadas más largas y se agacha bajo los dinteles. No mata por contacto ni atravesando muros.

Pasos por distancia recorrida con cadencia adulta: unos 2 pasos/s caminando, 2,5 corriendo (más fuertes) y 1,5 agachado; balanceo de cámara ligado a cada pisada y de pocos centímetros. Suenan pasos grabados sobre moqueta o, en baños, lavandería y mantenimiento, sobre baldosa (se oyen un 30 % más lejos); cada grabación arranca antes para que su golpe caiga en la pisada. Implementado agacharse a 2 m/s, resistencia 100, gasto al correr 8/s y recuperación 6/s tras 3 s de descanso; agotado no vuelve a correr hasta 30. La resistencia se muestra como un medidor segmentado de videocámara que desaparece al llenarse. Escondites: armarios grandes con doble puerta. Dentro, las puertas cerradas tapan la vista como una pared; manteniendo avanzar se entreabren despacio y la cabeza se asoma, con el campo de visión más amplio cuanto más abiertas. Mirando al frente se abren las dos a medias; al girar la vista a un lado se abre la puerta contraria, se cierra la otra y la cabeza sale por ese hueco, con la puerta abierta cubriéndola. Una puerta entreabierta delata al jugador si la criatura tiene línea de visión. Solo la primera apertura de cada estancia cruje. Si la criatura vio la entrada, o investiga un ruido junto a un armario ocupado, abre sus puertas y ataca. Dentro, la imagen se cierra con bordes oscuros y un leve ojo de pez que se abre al asomarse (desactivado con efectos reducidos). Escondites con entrada y salida libres; observar una entrada permite inspeccionarla. Las puertas retrasan, no conceden inmunidad fuera del refugio. Se añaden 15 s de protección inicial y aparición distante al empezar/reintentar, sin tiempo mínimo exigido para salir. Movimiento y preparación procedural del modelo son provisionales; las animaciones finales y permisos siguen pendientes.

- Sunman: atrios y galerías; aviso 2 s, barrido 4 s, descanso 6 s. Exposición +25/s, recuperación −20/s tras 1 s protegido, aviso a 70 y captura a 100. Cada cruce cabe en su ventana caminando más 1 s de margen.
- The Boiled One: televisores en habitaciones y salones; mirada central de 25°, exposición real tras 0,5 s. Intrusión +18/s, recuperación −12/s; avisos a 60/85 y captura a 100. No paralizar inevitablemente antes del umbral.
- Guilt: habitaciones repetidas y señales contradictorias, verificables con observación. Señuelos +20 de presión; aviso a 60, cacería anunciada de 20 s a 100 y reducción a 60 tras sobrevivir. Retirar la autenticación obligatoria y ajustar la recuperación mediante exploración segura al desarrollar ese piso.

Persianas, televisores y documentos son herramientas/pistas opcionales, nunca listas obligatorias de tareas. Las reglas son adaptaciones de juego, no afirmaciones sobre el canon.

Director (implementado para The Locust): 30 s sin nuevos eventos después de persecuciones o ataques, separación mínima de 45 s y como máximo un evento activo. Explorando, cada segundo hay una probabilidad de 1/25 de un evento con consecuencias: un objeto que cae en una sala a 9–26 m de recorrido (la criatura va a mirar ese punto) o pasos (su patrulla se desvía hasta una sala vecina a la del jugador). Tras 60 s sin encuentros ni salas nuevas solo se permiten golpes en una puerta, sin efecto sobre la criatura: quedarse quieto no provoca ataques. Nunca apunta a la posición del jugador, no altera capacidades, geometría ni recursos, y el refugio sigue siendo seguro.

Catálogo de doce eventos: golpes, objeto caído y pasos para Locust (implementados); sombra de aviso, persiana y zumbido para Sunman; pantalla anunciada, interfono e interferencia legible para Boiled One; indicación contrastable, puerta que imita un sonido y silueta sin ataque para Guilt. Cada uno tendrá condiciones, duración, enfriamiento y efecto; cancelar si no hay posición válida. Nunca falsificar controles, guardado, menús, accesibilidad ni hoja.

Descubrimientos opcionales persistentes: dieciséis entradas, cuatro por criatura, sin ventajas estadísticas. Implementados los cuatro de The Locust: documentos sobre mesas, escritorios y mesillas (dos por piso, lejos del inicio y en sectores distintos, fijos por semilla). Leer detiene al personaje sin pausar el juego, suena el papel y la entrada queda en **Archivo** del menú, también entre partidas. Dan contexto y pistas sobre la criatura, nunca mejoras. Registro de supervivientes, causas de muerte y campaña; códigos con semilla y versión. Desafíos de campaña sin reintentos y salida de todos con vida. Se retira el desafío basado en distractores obligatorios del diseño anterior. Ningún desafío añade derrota oculta.

## Orden y aceptación

1. Niveles y presentación básica: menú, ajustes, hotel, props, salida, refugio y checkpoint individual.
2. Atmósfera analógica: audios seleccionados, materiales, efectos, sonido espacial y perfiles.
3. Cooperativo y hoja: red, dibujos, cuotas, regreso, reconexión y transición con muertes de prueba.
4. Escondite y Locust: captura real, percepción, ruido, resistencia y ayuda entre jugadores.
5. Campaña: los otros tres pisos y enemigos, reaparición de fallecidos y progreso completo.
6. Consolidación: director, descubrimientos, códigos, balance, accesibilidad, permisos y exportación.

Validación exigida: 1.000 semillas por conjunto soportado con ningún mapa aceptado bloqueado; veinte recorridos manuales del primer piso; persistencia y reversión de ajustes; sesiones de 2/3/4 y dibujos concurrentes; mínimos 1/2, 2/3, 2/4; captura y puertas fiables; cinco partidas completas de exploración y campañas de dos/cuatro jugadores. Los recorridos automáticos se registran por separado de las partidas humanas.

Rendimiento objetivo: 60 FPS a 1080p en la RTX 4060 Ti del equipo, con tiempos de fotograma, carga y memoria. Medir, no asumir. Estado y límites de la entrega en [V04_VALIDATION.md](V04_VALIDATION.md); tareas en [TODO.md](TODO.md).

Fuentes técnicas consultadas: [renderizadores de Godot](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html), [multijugador](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html) y [sincronización de navegación](https://docs.godotengine.org/en/4.7/classes/class_navigationserver3d.html).

## Adenda — Audio de presencia y armarios (16 de septiembre de 2026)

**Implementado en individual:** un aura de The Locust que se oye en la dirección de la ruta por la que se acerca, sin revelar su posición exacta, y las asignaciones de [AUDIO.md](AUDIO.md): variación de puertas por acción/distancia, sonidos de escondite, ambiente y presencia de Locust emitida desde su posición. La identidad sonora anuncia una criatura real; su mezcla no cambia sus reglas de detección ni ataque. Grabaciones reservadas y futuras identidades no equivalen a nuevos sistemas implementados.

**Pendiente — armario claustrofóbico:** al entrar, cerrar puertas que tapen físicamente el cuerpo desde fuera. Desde dentro queda una abertura frontal estrecha; un efecto gradual oscurece/distorsiona la periferia y amplía la abertura con ojo de pez, buscando sensación de encierro y una visión parcial de presencias próximas. No genera imágenes de enemigos ni permite ver a través de superficies opacas. Mantener control de mirada dentro de los límites del escondite y una salida accesible.

Separar la geometría/ocultación del posprocesado: apagar o reducir la distorsión no revela al personaje desde fuera ni cambia reglas de visión de Locust. El efecto no afecta menús, hoja, subtítulos o señales esenciales; al salir, morir o reintentar vuelve al estado normal. Intensidad regulable y modo reducido con abertura legible, sin oscilaciones ni distorsión intensa. Evaluar los latidos reservados como complemento opcional, siempre por debajo de los avisos de peligro.

Validación pendiente: comparar vista interior/exterior, entrada vista por enemigo, amenaza frente a abertura y detrás de pared, escondite vacío/ocupado, salida bloqueada, pausa, muerte y reintento. Comprobar resoluciones/perfiles, efectos reducidos, música apagada y, cuando exista red, ocultación coherente para los demás jugadores. La abertura no anula el riesgo de inspección ni concede inmunidad.

**Hoja pendiente:** el papel se oye una vez al abrirla, como acción local de interfaz. Dibujar/borrar no repite ese sonido. Se implementará con la hoja, sin añadir un atajo de teclado que todavía no cumpla su función.
