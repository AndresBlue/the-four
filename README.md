# THE FOUR — Hotel

**0.5 · Hotel variable, individual y en red (2–5 jugadores) · Godot 4.7.2 Steam**

Proyecto principal: `E:\Projects\The Four`. Repositorio local, sin publicación ni remoto público.

## Jugar

Abre **Jugar.cmd** y elige **Jugar · nuevo recorrido**. Un piso son **tres alas y tres etapas**, y de un ala a la siguiente solo se pasa por el **ascensor de servicio**: cuando la etapa se cumple, la puerta del refugio se abre, detrás está el coche esperando y meterse en él te lleva al ala siguiente. El coche sube contigo y tarda quince segundos en volver a bajar, así que quien se quede atrás espera, y la criatura, que cruza andando hasta él como todos, llega cuando llega. La primera etapa es llegar al refugio con los vivos dentro; la segunda, encender los televisores de ese ala (al penúltimo se va la luz del ala, que vuelve al cruzar a la siguiente); la tercera, encender los suyos y encontrar los cuatro números escondidos en cajones y muebles —los guardan cuatro muebles con una hoja asomando, y lo que se encuentra queda escrito en la cinta—, teclearlos en la cerradura de la última puerta y tomar ese último ascensor, que termina el piso.

**La oscuridad se paga.** Cada superviviente tiene una cordura que no se ve en ninguna parte: baja a oscuras y sobre todo encerrado en un armario, la linterna solo la frena, y se recupera en salas encendidas. Según baja, el piso empieza a mentir —puertas y armarios que nadie abre, y más abajo la voz de la criatura desde donde no está— y la cinta de la cámara se estropea. Si se agota del todo, el cuerpo suelta unas motas rojas que **la criatura percibe desde cualquier parte del piso**: esconderse a esperar deja de funcionar. Un minuto de luz las apaga.

Un recorrido nuevo empieza con una escena: despiertas de noche en una habitación donde solo está encendida la tele, The Locust se asoma en la pantalla y golpea el cristal desde dentro hasta agrietarlo; huyes, das un portazo y corres por el pasillo oscuro hasta la recepción, marcada por una luz roja que parpadea: ahí empieza el piso y ahí puedes volver para orientarte. Mantén **E** o pulsa **Esc** para saltarla. **Continuar** y **Reintentar** no la repiten.

En mesas y escritorios hay documentos: acércate y pulsa **E** para leerlos (el juego sigue mientras lees). Se guardan en **Archivo**, en el menú principal. De vez en cuando el hotel hace cosas: golpes, algo que cae o pasos cerca; la criatura puede acudir.

Controles iniciales: WASD para moverte, ratón para mirar, Shift para correr, Espacio para saltar, **Ctrl** para agacharte, **E** para puertas y escondites, **F** para linterna y **Esc** para pausa. Pulsa y suelta E para apertura normal; mantenla un segundo para apertura lenta; si corres, das un portazo que se oye más lejos. El HUD imita una videocámara: corchetes de enfoque sobre lo que puedes usar y un medidor de resistencia; los controles están en la pausa y en Ajustes. Puedes cerrar una puerta abierta cercana aunque le des la espalda. Dentro de un armario, mantén **W** para entreabrir las puertas y mueve el ratón para asomarte a un lado; suelta para cerrarlas. Los controles se pueden cambiar en Ajustes.

**Continuar** restaura el inicio del mismo piso, no la posición donde cerraste el juego. Reintentar conserva el mapa y restablece puertas/estado. Al completar esta demostración se borra su checkpoint. El juego arranca en pantalla completa. En Ajustes puedes pasar a ventana: se ajusta al área útil del monitor y queda centrada; cambiar otros ajustes gráficos no la mueve ni cambia su tamaño. Los cambios de pantalla necesitan confirmación; se revierten a los doce segundos si no se aceptan.

## Jugar en red

**Multijugador** en el menú principal. Escribe tu nombre, elige cómo conectaros y después **Crear sala** o **Unirse a una sala**:
- **Steam:** con Steam abierto, el anfitrión crea la sala y los amigos entran por invitación, desde su perfil (**Unirse a la partida**) o desde **Unirse a una sala**, que lista las salas abiertas de los amigos. No hay que abrir puertos.
- **IP / LAN:** el anfitrión elige el puerto (38430 por defecto) y la red de su equipo en que abrir la sala; los demás se unen con su dirección y ese puerto. En la misma red, la IP local que muestra la sala; por Internet, la IP pública del anfitrión con ese puerto UDP abierto en su router.

De 2 a 5 jugadores, todos con el mismo exe.

El anfitrión elige **Cooperativo contra IA** o **Versus** (un jugador es The Locust: elegido o al azar). En cooperativo hay que llegar al refugio con al menos la mitad de los jugadores (redondeando hacia arriba) y todos los vivos dentro. Si mueres, observas a un compañero (clic para cambiar). **Tab** abre la hoja compartida: izquierdo dibuja, derecho borra. **Esc** abre un menú sin detener la partida. Si pierdes la conexión, vuelve a unirte con el mismo nombre antes de 60 s.

En versus, The Locust se controla con cámara sobre el hombro: Shift caza a toda velocidad (dura mucho y se recupera rápido: no se le escapa nadie corriendo), clic izquierdo ataca, clic derecho chilla y E abre puertas y armarios.

No ve el hotel: lo reconstruye. Chasquea dos veces por segundo y la imagen se arma de esos pulsos, en grises: el frente de onda cruza la sala despacio, deja los puntos que devuelve la geometría y se apaga hasta el siguiente. A eso se suman los ruidos que hacen los supervivientes, cada uno con su nube; al chillar, todo se vuelve rojo. La oscuridad no le afecta: hay que romperle la visión o esconderse bien. Los detalles están en [docs/VISION_LOCUST.md](docs/VISION_LOCUST.md), y se puede mirar en solitario con `./tools/godot.ps1 locust`.

Alcanzar a alguien no lo mata al instante: la criatura lo levanta en el aire y lo clava tres veces, y la baja cuenta al terminar. Registrar un armario también le cuesta: se planta delante y lo abre hoja a hoja, inmóvil unos segundos. Al morir observas a un compañero desde detrás de su hombro.

## Qué contiene esta entrega

- Entre 100 y 132 módulos en cinco sectores, distribución reproducible, rutas alternativas y salida distante.
- Veinte definiciones de habitaciones/espacios y más de quince tipos de muebles originales provisionales.
- Módulos rectangulares de 12–18 × 12–20 m, salones unidos de dos/tres módulos, distribuciones interiores asimétricas, puertas físicas y navegación derivada de colisiones.
- Menú principal, ajustes persistentes de gráficos/imagen/controles/audio, créditos y pausa real.
- Refugio reversible, salida libre, checkpoint individual y reintento.
- Forward+, perfil Compatibility, iluminación cálida/fría, moqueta y papel mural procedurales, niebla y filtro analógico regulable.
- The Locust patrulla, escucha por rutas caminables, investiga, persigue, registra armarios y ejecuta; su estocada se anuncia 0,3 s antes y alcanza 3,2 m con línea de visión.
- Resistencia, agacharse y armarios para esconderse en las habitaciones (no en pasillos); refugio seguro.
- Polvo, cortinas con movimiento reducido opcional, niebla localizada y reflejos en espacios comunes.
- Ambiente aportado por el usuario en bucle y música en buses separados.
- Cooperativo y versus por IP o LAN de 2 a 5 jugadores, con hoja compartida, reconexión y observación tras morir.
- Visión de ecolocalización para quien lleva a The Locust en versus: no ve el hotel, lo reconstruye a pulsos.
- Habitaciones a oscuras de verdad, sin luz ambiente ni fugas por las puertas, y puerta de madera antigua con su marco.
- Cuatro presets gráficos desde una sola tabla, medidos a 1080p, y elección de renderizador.

**Solo hay un piso de los cuatro.** Sunman, The Boiled One y Guilt todavía no existen. La red ya se ha jugado con gente real, en LAN y por Internet, y de ahí salió el problema principal de ahora: **las partidas se acaban demasiado pronto** —desde minuto y medio, una media de 5 a 8 minutos frente a la meta de 25–40— porque el piso se resuelve siguiendo la numeración de las puertas, a menudo sin cruzarse con la criatura. La estructura que debe arreglarlo —tres etapas, televisores, cerradura de código y apagón— ya está puesta, y la planta se rehizo para que ni la numeración ni ir pegado a una pared resuelvan el piso; **lo que falta es volver a jugarlo con gente y medir si ahora dura lo que debe**. El mobiliario y los materiales siguen siendo provisionales y no se presenta como una entrega fotorrealista. Lo que falta, en orden, en [docs/PLAN.md](docs/PLAN.md).

F9 activa una derrota de prueba en ejecución de desarrollo, fuera del refugio. Locust está activo en el hotel. El reintento reinicia resistencia, criatura y 15 s de protección inicial. Su movimiento y preparación usan animación procedural provisional. Los checkpoints del generador anterior (v2) son incompatibles con v3 y se conservan sin convertirlos silenciosamente.

## Ejecutable para Windows

`./tools/godot.ps1 export` genera `exports/windows/TheFour.exe`: un único archivo con todo el juego (plantilla release de Godot 4.7.2, sin consola ni atajos de depuración como F9). La configuración está en `export_presets.cfg`, que excluye `tests/`, `tools/`, `evidence/`, `models/`, `sfx/`, `source_assets/`, `exports/`, `docs/` y los `.zip` de origen; `evidence/`, `models/`, `sfx/` y `exports/` llevan además un `.gdignore` para que Godot ni siquiera los importe. `exports/` no se versiona.

**Pesa unos 970 MB**, demasiado: el paquete lleva a la vez los archivos de origen y su copia ya importada, y las texturas de los personajes son de 4K. Está anotado como pendiente en [docs/PLAN.md](docs/PLAN.md). Antes de distribuirlo deben resolverse los permisos de los assets.

## Abrir y validar

**Abrir en Godot.cmd** abre el proyecto; F5 ejecuta el hotel. La escena principal contiene componentes editables. El mapa se construye desde el manifiesto; el taller permite inspeccionar sus veinte módulos en el editor. Consulta [la guía de edición](docs/DEVELOPMENT.md).

Desde PowerShell en la carpeta del proyecto:

```powershell
./tools/verify.ps1
./tools/godot.ps1 gallery
./tools/godot.ps1 play
./tools/godot.ps1 compatibility
./tools/godot.ps1 editor
./tools/godot.ps1 test
./tools/godot.ps1 survival-test
./tools/godot.ps1 playtest -Seed 81
./tools/godot.ps1 hotel-batch
./tools/godot.ps1 hotel-walkthrough
./tools/godot.ps1 locust -Seed 81
./tools/godot.ps1 rehearsal -Seed 81
./tools/godot.ps1 execution -Seed 81
./tools/net_test.ps1 -Scenario coop
./tools/benchmarks/run_bench.ps1 -Label prueba
```

`verify.ps1` es la comprobación completa: contratos de escenas, hotel, supervivencia, intro, visión de eco, bucle de partida, audio, audio espacial, compilación de shaders con ventana y, al final, dos partidas en red con procesos reales (cooperativo de tres y versus de dos) por 127.0.0.1. Deja `evidence/verification.json` y un registro por prueba. `locust` abre el piso con la vista de ecolocalización; `rehearsal` añade supervivientes autónomos para juzgarla con algo pasando dentro; `execution` monta la escena de la muerte —la criatura enfrente, te ve, gruñe, te persigue y te ejecuta— y escribe cada golpe en la consola con el segundo en que ocurre, volviéndola a montar cada vez que mueres.

Las pruebas nuevas usan archivos `test_hotel_*` separados de las preferencias/checkpoints normales. Las regresiones de arquitectura usan `--no-enemy`; `survival-test` mantiene la IA real. `hotel-batch` construye mil mapas y recorre veinte con movimiento real automatizado; puede tardar varios minutos. `hotel-walkthrough` abre una ventana, recorre un piso y guarda capturas.

Herramientas adicionales: `hotel_audio_test.gd` comprueba la mezcla y el bucle del ambiente; `hotel_benchmark.gd` mide tres vistas quietas y un tramo caminando con cada preset gráfico a 1080p (`tools/benchmarks/run_bench.ps1` lo lanza). Ejecutarlas con Godot, `--path` al proyecto, `--script res://tests/hotel/hotel_audio_test.gd o res://tools/benchmarks/hotel_benchmark.gd` y, tras `--`, `--automation --test-profile --silent`.

## Estructura y documentación

- `game/`: escenas, scripts y recursos agrupados por función. Entrada: `game/app/hotel.tscn`.
- `tools/workbenches/module_gallery.tscn`: galería de los veinte módulos.
- `docs/DEVELOPMENT.md`: guía para localizar, editar y comprobar cada sistema.
- `docs/README.md`: índice de la documentación, por si no sabes dónde mirar.
- `docs/GAME_DESIGN.md`: el diseño vigente. `docs/PLAN.md`: estado, orden de trabajo y pendientes, en un solo documento.
- `docs/VISION_LOCUST.md`, `docs/AUDIO.md`, `docs/PERFORMANCE.md`, `docs/REALISM.md`: la visión de la criatura, el sonido, el rendimiento medido y el plan de imagen.
- `docs/textos_juego.txt`: todos los textos que aparecen en pantalla, para corregirlos en un solo sitio.
- `docs/V04_VALIDATION.md` y `docs/SURVIVAL_VALIDATION.md`: informes históricos; registran cuándo se comprobó algo, no el estado de hoy.
- `docs/PLAYTEST_HOTEL.md`: protocolo pendiente de evaluación humana.
- `docs/ASSETS.md`, `hotel_audio_inventory.json`: procedencia, créditos y análisis técnico.
- `docs/history/`: plan v0.3 conservado.
- `evidence/`: resultados y capturas regenerables, excluidos de Git.

El proyecto usa los archivos locales compartidos entre Codex y Godot; no incorpora una API de ChatGPT en el juego. Los audios originales y paquetes de personajes aportados se conservan. Antes de distribuir deben resolverse los permisos pendientes de los assets; no se descargó ni acreditó como usado un modelo de Sketchfab que no se haya incorporado.

## Audio espacial y siguientes efectos

Puertas con variantes cercanas/lejanas, escondites con sonidos de entrada/salida y presencia de Locust desde su posición. Con auriculares, The Locust se oye en binaural (diferencia de tiempo y de nivel entre oídos) y lo que viene de detrás suena más apagado. [Asignaciones y edición](docs/AUDIO.md). El papel está preparado para la futura hoja; el efecto claustrofóbico de armario con ojo de pez está registrado como pendiente, no implementado.
