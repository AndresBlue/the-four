# THE FOUR — Plan de diseño y avance

Versión de diseño: 0.3 · Juego: 0.3-H1 · 16 de septiembre de 2026

Este documento define una propuesta jugable para el proyecto. Las reglas de las criaturas son adaptaciones para The Four, no afirmaciones sobre el canon de Doctor Nowhere. Los números son valores iniciales para pruebas, no un balance definitivo.

## 1. Estado real y objetivo de la siguiente entrega

Implementado: proyecto de Godot 4.7.2, mapa fijo con cuatro salas, jugador en primera persona, caminar/correr/saltar, colisiones, The Locust estático con modelo y texturas aportados, música en bucle y control de volumen. Repositorio local migrado a `E:\Projects\The Four` conservando el historial Git.

Implementado en H1: sesión individual, interacción a 2 m con línea de visión, puertas, tres fusibles únicos, inventario de misión, panel, arranque del ascensor de 3 s, pausa real, victoria de piso, muerte de prueba y reintento. Evidencia: [H1_VALIDATION.md](../H1_VALIDATION.md).

Pendiente del TODO actual (H2–H6): IA y captura por criaturas, supervivencia, inventario de consumibles, guardado, generación, otros tres pisos, cooperativo y presentación final. La ampliación H7–H10 sigue pendiente de la primera etapa.

**Siguiente entrega: hito 2, supervivencia frente a The Locust.** El piso fijo ya se completa y reintenta desde sus menús sin herramientas del editor. La derrota se valida con F9 en ejecución de desarrollo; el enemigo todavía es estático y no ataca. El siguiente hito añade percepción, persecución y captura con avisos y contramedidas.

Dirección: terror de anticipación y desorientación, con amenazas que el jugador pueda entender. La iluminación, el sonido y la distribución deben aportar información útil, además de ambiente. El jugador no combate ni mata a las criaturas.

Las secciones 2–9 conservan las reglas y valores del diseño base. Son requisitos del juego completo; solo las funciones identificadas en el estado anterior y en el informe H1 están implementadas.

## 2. Estructura de una partida

1. El jugador llega en un ascensor a un piso sin energía suficiente para continuar.
2. Una antesala protegida presenta el objetivo y una pista de comportamiento del enemigo.
3. Explora habitaciones, encuentra herramientas y activa tres objetivos del piso.
4. Las acciones ruidosas y ciertos hitos aumentan la presión de la criatura.
5. Regresa al ascensor y mantiene el control de arranque durante tres segundos.
6. El ascensor parte, guarda la transición y prepara el siguiente piso.
7. Tras completar los cuatro pisos, el ascensor alcanza la salida del edificio y concluye la partida.

Objetivo de duración: 10–18 minutos por piso; campaña de aproximadamente 45–75 minutos incluyendo transiciones. Primero se medirá el piso 1; los rangos se ajustarán con partidas reales.

El primer hito será para **un jugador**. Se conservarán identificadores estables de objetos y un controlador único de la sesión para facilitar una futura versión cooperativa. La implementación de red queda fuera de esta fase.

## 3. Reglas comunes del jugador

- Caminar: 3,8 m/s. Correr: 6 m/s. Agacharse: propuesta de 2 m/s, tecla C.
- Resistencia: 100 unidades; correr consume 20/s, recupera 15/s tras 1,5 s sin correr. Se puede caminar sin resistencia. No habrá penalización que impida escapar por completo.
- Ruido de referencia: agacharse 2 m, caminar 5 m, correr 12 m, abrir una puerta normalmente 6 m y golpearla/forzarla 16 m. Son radios iniciales de eventos de sonido, no simulación acústica definitiva. Una pared o puerta cerrada atenúa el evento.
- Linterna: F; autonomía objetivo de ocho minutos encendida, repuestos que recuperan 40%. La luz atrae a enemigos solo cuando su regla lo indique. Los objetivos obligatorios y la ruta de salida conservarán visibilidad mínima sin batería.
- Inventario: dos espacios para herramientas consumibles. Los objetos de misión van en una sección separada para evitar que una mochila llena bloquee la partida. Un objeto obligatorio nunca se destruye ni queda fuera del mapa.
- Interacción: E, alcance máximo 2 m, línea de visión despejada y un único objeto enfocado. Mostrar acción y requisito antes de ejecutarla. Las acciones prolongadas muestran progreso y se cancelan al alejarse.
- No se incluirán armas. Las herramientas permiten distraer, detectar, iluminar o retrasar; no eliminar a la criatura.
- Esc abre pausa real en la versión individual. Implementado en H1; perder el foco también pausa la partida.
- Opciones futuras: sensibilidad, inversión de eje, volumen separado de música/SFX, subtítulos de pistas, reducción de flashes, movimiento de cámara y jumpscares. Las pistas esenciales tendrán alternativa visual y sonora.

## 4. Los cuatro pisos y sus criaturas

### Piso 1 — The Locust / Escuchar y escapar

Espacio: oficinas amarillas, moqueta, almacenes y pasillos de mantenimiento. Enseña movimiento silencioso, puertas y escondites.

Objetivo: localizar tres fusibles en salas distintas e instalarlos en el panel del ascensor. El tercer fusible dispara un evento de investigación cercano, nunca una aparición delante del jugador.

Regla propuesta: The Locust investiga ruidos y confirma al jugador mediante visión. Estados: reposo → patrulla → investigación → persecución → búsqueda → patrulla. No conoce la posición del jugador a través de paredes. Conserva únicamente la última posición observada y el último sonido válido.

Respuesta del jugador: caminar, cortar línea de visión con dos giros, cerrar una puerta y elegir un escondite que el enemigo no haya visto usar. Una botella lanzable desvía una investigación, pero no borra una persecución confirmada.

Valores iniciales: visión frontal de 80° y 14 m, confirmación tras 0,35 s visible; patrulla a 2,4 m/s y persecución a 5,2 m/s. Busca durante 8–12 s en la última zona conocida. El jugador puede ganar distancia corriendo, pero no indefinidamente.

Ataque: requiere proximidad inferior a 1,2 m, línea de visión y una anticipación audiovisual de 0,7 s. Si el jugador sale del alcance durante la anticipación, el ataque falla y deja una breve recuperación. No matar por contacto entre colisiones sin advertencia.

### Piso 2 — Sunman / Cruzar entre exposiciones

Espacio: atrio alto, ventanas opacas, oficinas con persianas y galerías de servicio. Su presencia debe sentirse demasiado grande para el edificio; la primera versión puede limitarlo al atrio para controlar navegación y escala.

Objetivo: cerrar tres sistemas de persianas y redirigir la alimentación al ascensor.

Regla propuesta: los espacios directamente iluminados por Sunman acumulan exposición. Una fase de aviso de dos segundos precede cada barrido. Muros y persianas bloquean la exposición; sombras meramente decorativas no bastan.

Respuesta: observar el patrón desde una zona protegida, cerrar persianas y cruzar cuando el barrido se aleja. Toda transición obligatoria incluye un refugio alcanzable caminando antes del siguiente barrido.

Valores iniciales: exposición de 0–100; +25/s bajo un barrido activo, −20/s en cobertura tras 1 s. A 70 aparecen avisos; a 100, captura. Ciclo orientativo: aviso 2 s, barrido 4 s, pausa 6 s. Se valida contra la distancia real de cada cruce.

No depender de flashes rápidos ni obligar a mirar directamente una fuente intensa. No usar cambios aleatorios de fase que eliminen la ventana de escape.

### Piso 3 — The Boiled One / Rechazar la señal

Espacio: archivo audiovisual, salas de proyección, televisores y cabinas de control.

Objetivo: desconectar tres transmisores y purgar la señal del panel del ascensor.

Regla propuesta: mantener la figura o una pantalla activa dentro del cono central de visión acumula intrusión. Mirar hacia otro lado o interponer una pared la reduce. La exposición necesita una prueba real de visibilidad, no solo distancia o presencia en el mismo cuarto.

Respuesta: navegar usando el entorno, cortar alimentación a las pantallas y usar persianas/cortinas. Las interacciones críticas se pueden realizar sin mirar la imagen peligrosa.

Valores iniciales: cono de atención de 25°, intrusión +18/s tras 0,5 s de mirada, recuperación −12/s cuando se corta la exposición. A 60, interferencia y advertencia accesible; a 85, una distorsión breve; a 100, captura. No congelar al jugador de forma inevitable antes del umbral final.

Una pantalla se anuncia con ruido y luz antes de activarse. No generar un transmisor obligatorio detrás de una exposición inevitable.

### Piso 4 — Guilt / Verificar antes de actuar

Espacio: oficinas repetidas, archivos personales, puertas aparentemente familiares y carteles contradictorios.

Objetivo: recuperar tres registros auténticos y cotejarlos en una terminal para abrir la salida final.

Regla propuesta: Guilt imita señales conocidas y ofrece atajos tentadores. Las inconsistencias son verificables mediante códigos, sellos o el registro del jugador. Elegir un señuelo aumenta la presión y provoca una investigación; nunca elimina un objeto obligatorio.

Respuesta: comparar una pista con el registro, marcar habitaciones ya visitadas, ignorar llamadas sin respaldo y elegir cuándo gastar una carga del verificador portátil.

Valores iniciales: presión 0–100. Un señuelo activado suma 20; autenticar un registro reduce 20. A 60 aumenta la frecuencia de manifestaciones. A 100 se inicia una cacería anunciada de 20 s; no es muerte automática. Sobrevivir la reduce a 60. La captura física sigue las reglas de anticipación y alcance.

Los señuelos usan un vocabulario aprendido en el mismo piso. No se basan en conocer información externa del universo ni en adivinar una opción sin pistas. La geometría crítica no se modifica durante una persecución.

## 5. Interacciones y objetos

**Puertas.** E abre/cierra. Mantener E durante un segundo permite apertura lenta y silenciosa; una acción explícita de apertura rápida genera más ruido. El enemigo puede empujar una puerta normal con retraso; una puerta no constituye inmunidad permanente. Cada estado debe coincidir en animación, colisión y navegación.

**Panel de ascensor.** Muestra tres indicadores de objetivo, requisitos pendientes y acción de salida. Instalar un objeto de misión consume únicamente ese objeto y solo si el panel lo acepta. Una instalación confirmada persiste durante la vida actual.

**Armarios y huecos bajo escritorios.** Entrada/salida con E; vista limitada y ruido reducido. No eliminan la memoria del enemigo: si observa la entrada puede inspeccionarlos. Nunca generar un escondite sin espacio seguro para salir ni situarlo dentro de una colisión.

**Fusibles y objetos de misión.** Recogida inmediata, identificación visible, registro de procedencia. Tienen identificador único; no reaparecen ni duplican progreso por pulsar E repetidamente.

**Botellas o piezas metálicas.** Recoger y lanzar para crear un evento de ruido en el impacto. Máximo dos herramientas. El señuelo no debe atravesar puertas cerradas ni sonar antes de golpear.

**Baterías.** Reponen linterna hasta su máximo; no se consumen si ya está llena. No se usan como llave para completar objetivos.

**Persianas e interruptores.** Cambian estados de luz y cobertura de forma determinista. El jugador puede prever el efecto con un indicador local; cerrar una persiana no bloquea la única salida.

**Transmisores y televisores.** Los tres transmisores son objetivos; los televisores secundarios son fuentes de peligro opcionales. Cortar energía afecta únicamente al circuito indicado y deja iluminación de emergencia.

**Terminales de archivo.** Guardan pistas y permiten contrastar registros. Se sale instantáneamente con Esc; el juego no requiere leer párrafos largos durante una persecución.

**Marcas de orientación.** Tiza reutilizable con límite de ocho marcas activas por piso. Colocación sobre superficies válidas y visibles; eliminar la más antigua al superar el límite. No sustituyen la comprobación de rutas del generador.

**Puertas de servicio bloqueadas.** Como máximo una dependencia llave-cerradura en el primer generador. La llave siempre es alcanzable sin atravesar su propia cerradura. Introducir más dependencias solo tras validar el orden de acceso.

**Ascensor/antesala.** Zona segura únicamente antes de iniciar la exploración y después de confirmar la salida. Un icono y el estado de la puerta indican cuándo está protegido; no ofrecer un refugio invisible que pueda explotarse durante toda la persecución.

## 6. Reglas de generación de mapa

### Representación y módulos

Generar primero un grafo de habitaciones y conexiones; después colocar módulos físicos. Cada módulo declara: tipo, tamaño, conectores con orientación, altura, puertas, puntos de navegación, zonas de interacción, posibles escondites, coberturas y puntos de aparición.

Cuadrícula base: 4 m. Habitaciones típicas: 8 × 8 o 8 × 12 m; corredor: 4 m de ancho; techo normal: 3,6 m. Sunman usa un conjunto de módulos de atrio más altos. Conectores enfrentados deben tener posición, ancho y altura compatibles. No unirlos por proximidad aproximada.

Cada partida guarda `run_seed`, `generator_version` y el estado de entrada al piso. Derivar semillas separadas para topología, decoración, objetos y encuentros. Cambiar decoración no debe alterar las posiciones de misión ni la secuencia de decisiones de la IA.

### Restricciones obligatorias

1. Un inicio y una salida por piso; tres salas de objetivo distintas y alcanzables. Para el primer piso, inicio y salida pueden ser el mismo ascensor; la ruta incluye el regreso.
2. Entre 18 y 26 módulos transitables en dificultad normal. Longitud orientativa del recorrido completo de objetivos: 180–280 m; medir en rutas de navegación, no en distancia recta.
3. Todos los módulos de juego pertenecen al componente conectado del inicio. Ningún objetivo queda detrás de un salto preciso, un objeto aleatorio o una puerta cuya llave sea inaccesible.
4. Construir un árbol conectado y añadir conexiones hasta obtener al menos dos ciclos independientes. El 30–50% de los módulos serán parte de rutas alternativas, no solo apéndices.
5. Máximo tres módulos consecutivos de pasillo recto sin referencia visual o bifurcación. Las referencias no garantizan seguridad, pero ayudan a aprender el espacio.
6. Un callejón sin salida tiene como máximo dos módulos. Si contiene un objetivo, necesita un escondite validado o una vía de retorno con cobertura; no colocar el punto de aparición de la criatura bloqueando su único acceso.
7. Habitación inicial sin amenaza durante los primeros 20 s y sin aparición dentro de un radio de navegación de 20 m. El primer encuentro se anuncia antes de permitir un ataque.
8. Criatura y jugador nunca aparecen en el mismo módulo. Las apariciones posteriores requieren al menos 12 m de distancia navegable, ausencia de línea de visión y espacio libre para toda la cápsula. Se cancela el evento si no hay un punto válido; no se relajan las reglas para forzarlo.
9. Un escondite o cobertura útil cada 20–30 m de la ruta principal. Los escondites tienen entrada y salida libres, capacidad definida y ruta transitable desde el pasillo.
10. Consumibles separados de objetos de misión. Añadir 2–4 baterías y 2–4 distractores como punto inicial; ninguna tirada aleatoria puede dejar la misión sin sus tres objetos obligatorios.
11. Sin solapamientos entre módulos ni entre geometría y volúmenes de paso. Para las cápsulas propuestas, dejar al menos 1,4 m de ancho libre y 2,1 m de alto para jugador; validar también la cápsula y el volumen visual del enemigo de cada piso.
12. El encuentro no bloquea permanentemente la salida ni se mantiene inmóvil sobre un objeto obligatorio. Tras una búsqueda fallida, la patrulla abandona esa zona y ofrece una ventana de acceso.
13. Toda trampa o amenaza específica permite advertencia y respuesta. Los cruces de Sunman deben caber en su ventana caminando más 1 s de margen; las interacciones ante The Boiled One tienen una orientación segura; Guilt deja una pista comprobable para cada señuelo.
14. No reconstruir geometría ni cambiar cerraduras mientras el jugador está dentro de un módulo o durante una persecución. Cualquier cambio posterior debe preservar la conectividad de objetivos restantes y salida.

### Orden del generador

1. Seleccionar conjunto de módulos según piso y dificultad.
2. Reservar inicio, tres objetivos y salida; generar el grafo conectado.
3. Añadir ciclos, coberturas y ramas opcionales con los límites indicados.
4. Colocar los módulos respetando conectores y cajas de ocupación.
5. Asignar objetos de misión y, si procede, la única llave en un nodo previo a su cerradura.
6. Construir navegación; comprobar acceso del jugador y de la criatura por separado.
7. Decorar sin invadir corredores, interacciones ni posiciones de aparición.
8. Ejecutar todas las validaciones. Si fallan, registrar semilla y motivo y reintentar con una subsecuencia determinista, máximo 20 intentos.
9. Si se agotan los intentos, cargar un mapa fijo ya validado del piso y registrar el uso de respaldo. Nunca iniciar una partida imposible ni ocultar el fallo en los registros.

### Criterio para aceptar el generador

Probar 1.000 semillas por piso y dificultad en validación automática: cero mapas aceptados con objetivos inaccesibles, solapamientos o dependencias circulares; registrar la tasa de reintentos y de respaldo. Meta inicial de respaldo inferior al 1%. Con la misma semilla y versión se deben repetir topología y objetos. Recorrer manualmente al menos 20 semillas del primer piso; una validación de grafo no demuestra que una persecución sea justa.

## 7. Victoria, derrota y muerte

### Victoria de piso

Los tres objetivos están confirmados, el panel está listo, el jugador está vivo y dentro de la cabina, y se completa el arranque de tres segundos. Al confirmarse el arranque se bloquean nuevos ataques, se cierra la cabina y se realiza la transición. Entrar en la cabina antes de cumplir requisitos no gana automáticamente.

### Victoria de campaña

Los cuatro pisos están completados en la sesión guardada y se confirma la salida final. Mostrar resumen: tiempo, muertes/reintentos y registros encontrados. Los coleccionables no condicionan la victoria básica.

### Derrota

Captura física válida por una criatura, exposición máxima a Sunman o intrusión máxima de The Boiled One. No hay derrota por perder una batería, tirar una herramienta o caer accidentalmente bajo el mapa: esos últimos casos deben recuperar al jugador en una posición válida o reportar un error de nivel.

### Secuencia de muerte

1. El controlador de sesión acepta una única transición de `PLAYING` a `DYING`; ignora impactos posteriores.
2. Bloquea movimiento, interacción y objetivos. Detiene o desvanece música y señales de persecución.
3. Presenta una secuencia breve de 1–2 s según criatura, con alternativa reducida y opción de omitir.
4. Muestra causa concreta y pista útil: por ejemplo, "The Locust oyó la puerta. Prueba a abrirla lentamente". La pista debe corresponder al evento real.
5. Ofrece reintentar piso, volver al menú o salir. Nunca reiniciar automáticamente sin permitir elegir.

### Guardado y reintento

Modo normal: checkpoint al entrar en cada piso. Al morir, se conserva el progreso de pisos anteriores, se reinicia el piso actual con la misma semilla y se restaura exactamente el inventario del checkpoint; objetivos, enemigos y consumibles vuelven al estado inicial. No mezclar inventario posterior con objetos regenerados, para evitar duplicaciones.

Registrar al guardar: versión del formato, piso, semilla, versión del generador, inventario de entrada, ajustes y estadísticas. Escribir primero un archivo temporal, validar y reemplazar el guardado. Si la versión es incompatible, conservar una copia y explicar la recuperación disponible.

Un modo sin checkpoints puede añadirse después. No será el modo predeterminado durante el desarrollo.

## 8. Plan de avance por hitos

### Hito 1 — Interacción y sesión completa sobre el mapa fijo

**Implementado y validado — 0.3-H1.** Véase [H1_VALIDATION.md](../H1_VALIDATION.md). Muerte de prueba; IA y ataques pertenecen a H2.

Implementar `GameSession`, estados de partida, foco de interacción, puertas, tres fusibles, panel, ascensor, pausa y pantallas de victoria/derrota. El estado del nivel vive en el controlador; el HUD lo presenta.

Se acepta cuando se puede completar el piso, reintentarlo desde muerte de prueba y volver al menú diez veces sin duplicar objetos ni conservar controles bloqueados. Pulsar E repetidamente no duplica instalaciones. La partida se puede terminar sin usar herramientas del editor.

### Hito 2 — The Locust y supervivencia

Navegación, patrulla, visión con rayos, eventos de ruido, persecución, búsqueda, anticipación de ataque, resistencia, agacharse y escondites. Sustituir la pose estática por animaciones adecuadas cuando el asset y su permiso lo permitan.

Se acepta cuando no detecta al jugador a través de muros, distingue un señuelo de una persecución confirmada, puede perder el rastro y no mata a través de puertas. Completar al menos diez partidas de prueba, registrando duración, encuentros, muertes y causa; ajustar la dificultad con esos datos.

### Hito 3 — Módulos, generación y persistencia

Convertir habitaciones y conectores en escenas reutilizables, implementar la generación descrita, validación, mapa de respaldo y checkpoint por piso.

Se acepta con el lote de 1.000 semillas del primer piso, recorrido manual de 20, reproducción de una semilla fallida y reintentos sin pérdida o duplicación de inventario.

### Hito 4 — Tres pisos nuevos

Implementar en orden Sunman, The Boiled One y Guilt, cada uno primero en un mapa fijo de prueba. Integrar después sus módulos y restricciones al generador. Reutilizar el sistema común de objetivos, muerte y transición.

Se acepta cuando cada regla se puede aprender sin conocer el canon, existe una contramedida verificable y se puede completar la campaña de principio a fin sin saltos del editor.

### Hito 5 — Presentación y rendimiento

Música contextual, SFX espaciales, subtítulos, materiales, iluminación y VFX. La música ambiental debe bajar durante pistas esenciales y persecuciones; no ocultar el aviso que salva al jugador. Separar buses Master, Music, Ambience, Threat y UI.

Evaluar Forward+ y luces más complejas en una escena representativa antes de cambiar el proyecto completo. Meta propuesta: 60 FPS a 1080p en la RTX 4060 Ti de este equipo, midiendo tiempo de fotograma y picos, no solo FPS promedio. Mantener un modo de calidad reducido. El render actual usa Compatibility.

Se acepta con una campaña recorrida, sin errores de recursos, señales legibles con los ajustes accesibles y perfil de rendimiento guardado para la escena de mayor carga.

### Hito 6 — Cooperativo y entrega pública

Cooperativo acordado: 2–4 jugadores; concretar alcance de red al abrir H6. Servidor autoritativo para objetos, objetivos, IA y muerte. Diseño propuesto: primera captura deja incapacitado 25 s; un compañero puede reanimar manteniendo interacción 5 s si la zona es segura. Una segunda captura en el mismo piso elimina hasta la transición. Si nadie puede actuar, derrota del grupo. Espectador sin capacidad de revelar información oculta.

Este modo requiere pruebas propias de desconexión, reconexión y duplicación de objetos; no se considera una simple activación de los sistemas individuales.

Antes de distribuir: resolver permisos de personajes/modelos, sustituir o licenciar la canción y añadir créditos completos. Preparar exportación, menú, ajustes persistentes y pruebas en un equipo sin editor instalado.

## 9. Organización técnica propuesta

- `GameSession`: única autoridad sobre estados, objetivos, muerte, transición y guardado.
- `Player`: movimiento y cámara; componentes separados para resistencia e inventario.
- `Interactor`: rayo de cámara, acción contextual y validación del objetivo.
- `Interactable`: contrato común para puertas, objetos, paneles y escondites.
- `EnemyController`: estados compartidos y configuración por criatura; no decide el estado global de la partida.
- `NoiseSystem`: emite eventos con posición, intensidad y origen; la IA escucha eventos, no consulta la posición global del jugador sin percepción.
- `FloorDefinition`: recursos de Godot con conjunto de módulos, objetivos, criatura, iluminación y reglas específicas.
- `MapGenerator` y `MapValidator`: construcción y comprobación separadas, con reporte de semilla y causas de fallo.
- `AudioDirector`: estados de exploración, amenaza, persecución, muerte y transición, con control independiente del volumen.

No construir todos estos sistemas a la vez. El primer hito incorpora solo los necesarios para jugar y terminar un piso; los siguientes extraen y amplían lo que ya esté probado.

## 10. Decisiones acordadas para v0.3

Conservar los seis hitos de la sección 8 como **primera etapa / TODO actual**. La segunda etapa comienza solo después de completarlos y validarlos. Su prioridad es terror y rejugabilidad, no combate ni progresión de poder.

- La progresión permanente conserva descubrimientos, secretos y desafíos. No mejora velocidad, resistencia o inventario.
- El ritmo de encuentros es adaptativo; las reglas y capacidades de las criaturas permanecen estables.
- Se mantienen cuatro pisos, una amenaza principal por piso y checkpoints entre pisos.
- No se incorporan anticipadamente al prototipo los sistemas de la segunda etapa.

Esta es la versión **0.3 del diseño**, no una declaración de que el juego haya alcanzado esos hitos. La versión jugable es **0.3-H1**, con el primer hito implementado y validado; H2–H6 siguen pendientes. El estado de tareas y dependencias se registra en [TODO.md](TODO_v0.3.md), y el orden resumido en [ROADMAP.md](ROADMAP_v0.3.md).

### Condición de entrada a la segunda etapa

Los hitos 1–6 deben tener implementación y evidencia de aceptación: campaña completa jugable, objetivos y muerte fiables, generador validado, cooperativo comprobado y entrega preparada con sus permisos resueltos. No debe haber errores conocidos que bloqueen partidas.

Cada cierre de hito registra revisión Git, prueba ejecutada, resultado y ubicación de la evidencia. Una descripción, un checkbox o una prueba del prototipo 0.2 no acreditan sistemas que todavía no existen. Si falla cualquier condición, los hitos 7–10 permanecen pendientes de sus dependencias.

## 11. Segunda etapa — Terror y rejugabilidad

### Hito 7 — Ritmo adaptativo y eventos ambientales

**Objetivo:** evitar tanto la persecución constante como los periodos largos sin acontecimientos. **Dependencia:** primera etapa aceptada.

Añadir un `TensionDirector` que observe persecuciones, exposición a amenazas, objetivos completados y tiempo desde el último encuentro. Solicita eventos; `GameSession` valida y autoriza. No reemplaza la percepción ni la máquina de estados del enemigo.

Reglas iniciales:

- Tras terminar una persecución, conceder **30 segundos sin nuevos eventos hostiles programados**. Las criaturas conservan su percepción normal; el jugador puede provocar otro encuentro.
- Tras **60 segundos sin amenaza ni progreso de objetivos**, permitir una señal ambiental. No iniciar automáticamente un ataque.
- Completar un objetivo puede solicitar una investigación, respetando las restricciones de aparición y el descanso anterior. Esta restricción se aplica también a la investigación del tercer fusible del piso 1; no introduce una aparición forzada ni una excepción al descanso.
- Como máximo un evento con consecuencias jugables activo; separación mínima de **45 segundos** entre esos eventos.
- No alterar velocidad, alcance, daño, umbrales de exposición ni percepción para castigar al jugador.
- No modificar geometría, retirar recursos o bloquear rutas para aumentar tensión.
- En cooperativo, usar el estado del equipo y no iniciar un evento hostil programado durante una incapacitación o reanimación.

Catálogo inicial de **12 eventos**, tres por piso:

**The Locust**

1. Golpes tras una pared.
2. Objeto que cae y genera ruido.
3. Pasos audibles de la criatura sobre una ruta existente.

**Sunman**

4. Sombra que anticipa un barrido.
5. Persiana secundaria que vibra.
6. Zumbido del circuito que señala el siguiente ciclo.

**The Boiled One**

7. Pantalla secundaria que se enciende con aviso.
8. Llamada por interfono.
9. Interferencia breve que no oculta controles ni señales esenciales.

**Guilt**

10. Indicación falsa contrastable con el registro.
11. Puerta que imita un sonido conocido.
12. Silueta ambiental sin capacidad de ataque.

Cada evento declara condiciones, duración, enfriamiento y efecto. Si no existe una posición válida, se cancela. Los eventos de Guilt nunca falsifican avisos de accesibilidad, controles, guardado ni menús.

**Aceptación:** pruebas de descansos, exclusión de eventos simultáneos, cancelación por ubicación inválida y respeto de capacidades originales. Comprobar los 12 eventos con música desactivada, subtítulos y efectos visuales reducidos; ninguna pista obligatoria puede desaparecer por estos ajustes.

### Hito 8 — Objetivos alternativos y decisiones de riesgo

**Objetivo:** que una nueva distribución no sea la única diferencia entre partidas. **Dependencia:** hito 7 aceptado.

Mantener **tres objetivos obligatorios por piso** y añadir una alternativa al objetivo original de cada criatura:

- **The Locust:** tres fusibles, o tres relés que se reparan y producen ruido durante su activación.
- **Sunman:** cerrar tres conjuntos de persianas, o orientar tres pantallas protectoras desde posiciones de cobertura.
- **The Boiled One:** desconectar tres transmisores, o aislar sus circuitos desde tres cabinas protegidas.
- **Guilt:** autenticar tres registros, o identificar tres puertas verdaderas comparando sus sellos con pistas accesibles.

Seleccionar **una sola variante por piso al crear la partida**. Guardarla con la semilla y explicarla en la antesala. No mezclar instrucciones de ambas variantes ni cambiar el objetivo después de comenzar. Las reglas originales de la sección 4 se conservan para la variante base.

Añadir salas opcionales:

- **Almacén:** ofrece un consumible; abrirlo genera ruido.
- **Archivo:** contiene un descubrimiento y exige un desvío. Su persistencia se habilita en el hito 9; no debe declarar todavía un desbloqueo guardado.
- **Atajo:** reduce el recorrido y atraviesa una zona de mayor exposición.

Estas salas no alojan objetos obligatorios ni recursos imprescindibles para ganar. Anunciar el riesgo antes de aceptar la interacción. Respetar límites de inventario y presupuesto de consumibles; no aumentar indiscriminadamente su abundancia.

**Aceptación:** 1.000 semillas por piso, variante y dificultad soportada, sin aceptar mapas que bloqueen objetivos o salida. Validar cada combinación, no solo las variantes originales. Recorrer al menos cinco partidas individuales por variante de piso, documentando duración, fallos y causas de muerte.

### Hito 9 — Descubrimientos y rejugabilidad persistente

**Objetivo:** dar motivos para volver sin convertir el terror en acumulación de poder. **Dependencia:** hito 8 aceptado.

Añadir:

- **Archivo de descubrimientos:** 16 entradas iniciales, cuatro por criatura; dos explican pistas observables de comportamiento y dos desarrollan narrativa ambiental.
- **Registro de campaña:** pisos completados, variantes vistas, secretos encontrados, tiempo y causas de muerte.
- **Repetición por código de partida:** conserva semilla, versión del generador, dificultad y variantes de objetivos.
- **Dos desafíos opcionales:** completar una campaña sin reintentos; completar un piso sin usar distractores.

Reglas:

- Los descubrimientos persisten tras morir. Los objetos y objetivos se restauran según el checkpoint.
- Diferenciar observar una pista de haber encontrado una criatura. No revelar automáticamente contramedidas que aún no se descubrieron.
- Evaluar los desafíos al terminar; no añadir condiciones ocultas de derrota.
- No incluir mejoras permanentes, monedas, tiendas ni ventajas estadísticas.
- Un código reproduce mapa, distribución y objetivos. Los encuentros adaptativos pueden variar según las acciones del jugador; no se promete una repetición idéntica de toda la sesión.
- Rechazar códigos de versiones incompatibles con un mensaje claro; no sustituir silenciosamente el mapa.

**Aceptación:** morir, cargar y reintentar sin duplicar recursos; conservar descubrimientos sin conservar indebidamente el progreso del piso. Verificar reproducción de códigos compatibles y rechazo de incompatibles, y que los desafíos no cambien las condiciones de victoria.

### Hito 10 — Balance y consolidación

**Dependencia:** hito 9 aceptado. Completar esta consolidación antes de añadir más contenido.

- Registrar localmente duración, encuentros, tiempo de persecución, causas de muerte, objetivos y variantes.
- Identificar muertes sin advertencia suficiente, habitaciones evitadas y objetivos desproporcionadamente lentos.
- Ajustar primero pistas, espacios y ventanas de respuesta; después los valores de dificultad.
- Comprobar que cada criatura mantiene una estrategia reconocible pese a las variaciones.
- Publicar una versión estable de la ampliación antes de plantear nuevos pisos o enemigos, manteniendo las condiciones de permisos y entrega del hito 6.

**Aceptación:** campaña completable, variaciones comprensibles, ausencia de ataques programados durante descansos y conservación del objetivo de rendimiento de la sección 8. Completar dos campañas cooperativas, una con dos jugadores y otra con cuatro, además de los recorridos individuales de cada variante. Registrar resultados; no reemplazar estas partidas con pruebas unitarias.

**Fuera de esta ampliación:** combate, árboles de habilidades, mapas infinitos, editor de mods, clasificaciones en línea, nuevos monstruos y geometría que se reorganiza durante persecuciones.

## 12. Integración de la segunda etapa

Extender los sistemas de la sección 9, sin duplicar su autoridad:

- `TensionDirector` solicita eventos; `GameSession` valida el estado de la partida y autoriza su ejecución.
- `EncounterDefinition` describe requisitos, efecto, duración y enfriamiento.
- `FloorDefinition` incorpora variantes de objetivos y salas opcionales compatibles.
- `MapValidator` conserva las garantías de accesibilidad y conectividad para cada variante.
- El perfil persistente almacena descubrimientos y desafíos separado del checkpoint de campaña.
- El guardado incorpora la variante elegida y el estado necesario del director. Reintentar restaura el inicio del piso, incluido su periodo de protección.
- En cooperativo, el servidor decide y replica los eventos. Los clientes no sortean encuentros independientemente.
- Los registros permanecen locales. Esta etapa no requiere servicios externos.

Las ampliaciones anteriores son requisitos futuros. GameSession existe desde H1, pero aún no autoriza eventos adaptativos ni guarda campañas. El catálogo y las variantes se diseñan como datos; sus definiciones no se confunden con la lógica que autoriza efectos de juego.

## 13. Validación de la ampliación

- **Regresión:** conservar, a medida que existan, las pruebas de la primera etapa para interacción, IA, muerte, guardado, generación y cooperativo. Las pruebas actuales de movimiento/modelo/audio no cubren estas funciones futuras.
- **Director:** comprobar descansos, exclusión de eventos simultáneos, cancelación de posiciones inválidas y capacidades estables de las criaturas.
- **Generación:** 1.000 semillas por piso, variante y dificultad soportada; cero mapas aceptados con objetivos o salida bloqueados.
- **Persistencia:** ausencia de duplicaciones y separación correcta entre descubrimientos y progreso del checkpoint.
- **Cooperativo:** todos reciben el mismo evento; una desconexión no duplica objetivos, recompensas o efectos.
- **Accesibilidad:** comprobar los 12 eventos con música desactivada, subtítulos y efectos reducidos, sin perder pistas obligatorias.
- **Pruebas de juego:** al menos cinco partidas individuales por variante de piso y dos campañas cooperativas completas, de dos y cuatro jugadores.
- **Aceptación final:** campaña completable, variaciones comprensibles, descansos respetados y rendimiento dentro del objetivo establecido.

Orden de ejecución: **hitos 1–6 → validar entrada a segunda etapa → ritmo y eventos → variantes y riesgo opcional → descubrimientos y desafíos → balance**. Cada hito se valida antes de abrir el siguiente.
