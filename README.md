# THE FOUR — Hotel

**0.5 · Hotel variable, individual y en red (2–5 jugadores) · Godot 4.7.2 Steam**

Proyecto principal: `E:\Projects\The Four`. Repositorio local, sin publicación ni remoto público.

## Jugar

Abre **Jugar.cmd** y elige **Jugar · nuevo recorrido**. Explora el hotel hasta encontrar la sala señalizada **SALIDA / REFUGIO**. Dentro puedes volver a explorar o mantener la interacción durante tres segundos para terminar el piso. No necesitas recoger fusibles ni completar puzles.

Un recorrido nuevo empieza con una escena: despiertas de noche en una habitación donde solo está encendida la tele, The Locust se asoma en la pantalla y golpea el cristal desde dentro hasta agrietarlo; huyes, das un portazo y corres por el pasillo oscuro hasta la recepción, marcada por una luz roja que parpadea: ahí empieza el piso y ahí puedes volver para orientarte. Mantén **E** o pulsa **Esc** para saltarla. **Continuar** y **Reintentar** no la repiten.

En mesas y escritorios hay documentos: acércate y pulsa **E** para leerlos (el juego sigue mientras lees). Se guardan en **Archivo**, en el menú principal. De vez en cuando el hotel hace cosas: golpes, algo que cae o pasos cerca; la criatura puede acudir.

Controles iniciales: WASD para moverte, ratón para mirar, Shift para correr, Espacio para saltar, **Ctrl** para agacharte, **E** para puertas y escondites, **F** para linterna y **Esc** para pausa. Pulsa y suelta E para apertura normal; mantenla un segundo para apertura lenta; si corres, das un portazo que se oye más lejos. El HUD imita una videocámara: corchetes de enfoque sobre lo que puedes usar y un medidor de resistencia; los controles están en la pausa y en Ajustes. Puedes cerrar una puerta abierta cercana aunque le des la espalda. Dentro de un armario, mantén **W** para entreabrir las puertas y mueve el ratón para asomarte a un lado; suelta para cerrarlas. Los controles se pueden cambiar en Ajustes.

**Continuar** restaura el inicio del mismo piso, no la posición donde cerraste el juego. Reintentar conserva el mapa y restablece puertas/estado. Al completar esta demostración se borra su checkpoint. El juego arranca en pantalla completa. En Ajustes puedes pasar a ventana: se ajusta al área útil del monitor y queda centrada; cambiar otros ajustes gráficos no la mueve ni cambia su tamaño. Los cambios de pantalla necesitan confirmación; se revierten a los doce segundos si no se aceptan.

## Jugar en red

**Multijugador** en el menú principal. Escribe tu nombre y elige **Crear sala** (anfitrión) o **Unirse a una sala** con la dirección del anfitrión. En la misma red usad la IP local que aparece en la sala; por Internet, la IP pública del anfitrión con el puerto **38430 UDP** abierto en su router. De 2 a 5 jugadores, todos con el mismo exe.

El anfitrión elige **Cooperativo contra IA** o **Versus** (un jugador es The Locust: elegido o al azar). En cooperativo hay que llegar al refugio con al menos la mitad de los jugadores (redondeando hacia arriba) y todos los vivos dentro. Si mueres, observas a un compañero (clic para cambiar). **Tab** abre la hoja compartida: izquierdo dibuja, derecho borra. **Esc** abre un menú sin detener la partida. Si pierdes la conexión, vuelve a unirte con el mismo nombre antes de 60 s.

En versus, The Locust se controla con cámara sobre el hombro: Shift caza a toda velocidad (dura mucho y se recupera rápido: no se le escapa nadie corriendo), clic izquierdo ataca, clic derecho chilla y E abre puertas y armarios.

No ve el hotel: lo reconstruye. Chasquea quince veces por segundo y la imagen se arma de esos pulsos, en grises, mezclando la geometría que le devuelve el eco con los ruidos que hacen los supervivientes; al chillar, todo se vuelve rojo. La oscuridad no le afecta: hay que romperle la visión o esconderse bien. Los detalles están en [docs/VISION_LOCUST.md](docs/VISION_LOCUST.md), y se puede mirar en solitario con `./tools/godot.ps1 locust`.

Alcanzar a alguien no lo mata al instante: la criatura lo levanta en el aire y lo clava tres veces, y la baja cuenta al terminar. Registrar un armario también le cuesta: se planta delante y lo abre hoja a hoja, inmóvil unos segundos. Al morir observas a un compañero desde detrás de su hombro.

## Qué contiene esta entrega

- Entre 100 y 132 módulos en cinco sectores, distribución reproducible, rutas alternativas y salida distante.
- Veinte definiciones de habitaciones/espacios y más de quince tipos de muebles originales provisionales.
- Módulos rectangulares de 12–18 × 12–20 m, salones unidos de dos/tres módulos, distribuciones interiores asimétricas, puertas físicas y navegación derivada de colisiones.
- Menú principal, ajustes persistentes de gráficos/imagen/controles/audio, créditos y pausa real.
- Refugio reversible, salida libre, checkpoint individual y reintento.
- Forward+, perfil Compatibility, iluminación cálida/fría, moqueta y papel mural procedurales, niebla y filtro analógico regulable.
- The Locust patrulla, escucha, investiga, persigue y busca; ataque anunciado de 0,7 s con alcance y visión comprobados.
- Resistencia, agacharse y armarios para esconderse en las habitaciones (no en pasillos); refugio seguro.
- Polvo, cortinas con movimiento reducido opcional, niebla localizada y reflejos en espacios comunes.
- Ambiente aportado por el usuario en bucle y música en buses separados.

**Todavía no hay cuatro pisos jugables; el juego en red falta probarlo con sesiones humanas.** La supervivencia individual tiene pruebas funcionales, pero todavía requiere balance en partidas humanas. El mobiliario y materiales siguen siendo provisionales; no se presenta como una entrega fotorrealista. La duración de 25–40 minutos por piso necesita pruebas humanas de exploración.

F9 activa una derrota de prueba en ejecución de desarrollo, fuera del refugio. Locust está activo en el hotel. El reintento reinicia resistencia, criatura y 15 s de protección inicial. Su movimiento y preparación usan animación procedural provisional. Los checkpoints del generador anterior (v2) son incompatibles con v3 y se conservan sin convertirlos silenciosamente.

## Ejecutable para Windows

`./tools/godot.ps1 export` genera `exports/windows/TheFour.exe`: un único archivo de unos 400 MB con todo el juego (plantilla release de Godot 4.7.2, sin consola ni atajos de depuración como F9). La configuración está en `export_presets.cfg` y excluye `tests/`, `tools/` y `legacy/`. `exports/` no se versiona. Antes de distribuirlo deben resolverse los permisos de los assets.

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
```

Las pruebas nuevas usan archivos `test_hotel_*` separados de las preferencias/checkpoints normales. Las regresiones de arquitectura usan `--no-enemy`; `survival-test` mantiene la IA real. `hotel-batch` construye mil mapas y recorre veinte con movimiento real automatizado; puede tardar varios minutos. `hotel-walkthrough` abre una ventana, recorre un piso y guarda capturas.

Herramientas adicionales: `hotel_audio_test.gd` comprueba la mezcla y el bucle del ambiente; `hotel_benchmark.gd` mide tres vistas quietas y un tramo caminando con cada preset gráfico a 1080p (`tools/benchmarks/run_bench.ps1` lo lanza). Ejecutarlas con Godot, `--path` al proyecto, `--script res://tests/hotel/hotel_audio_test.gd o res://tools/benchmarks/hotel_benchmark.gd` y, tras `--`, `--automation --test-profile --silent`.

## Prototipo anterior

`./tools/godot.ps1 legacy` abre el H1 de fusibles con Locust estático. `legacy-test`, `h1-test`, `audio-test` y `walkthrough` conservan sus pruebas históricas. `build` reconstruye exclusivamente la escena histórica y sobrescribe esa escena; no genera el hotel actual.

## Estructura y documentación

- `game/`: escenas, scripts y recursos agrupados por función. Entrada: `game/app/hotel.tscn`.
- `tools/workbenches/module_gallery.tscn`: galería de los veinte módulos.
- `docs/DEVELOPMENT.md`: guía para localizar, editar y comprobar cada sistema.
- `legacy/fuse_prototype/main.tscn` y scripts anteriores: prototipo histórico de fusibles.
- `docs/GAME_DESIGN.md`, `ROADMAP.md`, `TODO.md`: diseño v0.4, orden y estado real.
- `docs/V04_VALIDATION.md`: informe histórico de P1.
- `docs/SURVIVAL_VALIDATION.md`: validación actual del hotel variable y la amenaza.
- `docs/PLAYTEST_HOTEL.md`: protocolo pendiente de evaluación humana.
- `docs/ASSETS.md`, `hotel_audio_inventory.json`: procedencia, créditos y análisis técnico.
- `docs/history/`: plan v0.3 conservado.
- `evidence/`: resultados y capturas regenerables, excluidos de Git.

El proyecto usa los archivos locales compartidos entre Codex y Godot; no incorpora una API de ChatGPT en el juego. Los audios originales y paquetes de personajes aportados se conservan. Antes de distribuir deben resolverse los permisos pendientes de los assets; no se descargó ni acreditó como usado un modelo de Sketchfab que no se haya incorporado.

## Audio espacial y siguientes efectos

Puertas con variantes cercanas/lejanas, escondites con sonidos de entrada/salida y presencia de Locust desde su posición. Con auriculares, The Locust se oye en binaural (diferencia de tiempo y de nivel entre oídos) y lo que viene de detrás suena más apagado. [Asignaciones y edición](docs/AUDIO.md). El papel está preparado para la futura hoja; el efecto claustrofóbico de armario con ojo de pez está registrado como pendiente, no implementado.
