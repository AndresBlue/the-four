# Guía de edición de The Four

Proyecto: `E:\Projects\The Four`. Godot 4.7.2 Steam. Esta organización conserva la versión de juego 0.4-S1 y el generador v3; no altera el diseño ni convierte tareas pendientes en implementadas.

## Empezar en Godot

1. Abre **Abrir en Godot.cmd**. La escena de entrada es `game/app/hotel.tscn`; F5 ejecuta la partida.
2. En esa escena encontrarás **Services**, **Player**, **Interface** y **Presentation**. Abre sus escenas originales para editar cada componente. El coordinador conecta sus dependencias antes de que se inicialicen los hijos.
3. Abre `tools/workbenches/module_gallery.tscn` para inspeccionar los veinte módulos. F6 ejecuta su cámara libre: botón derecho + WASD, Q/E para altura y Shift para acelerar. También puedes abrir **Taller de habitaciones.cmd**.
4. Durante una partida, cambia el árbol de escenas de **Local** a **Remoto**. `GeneratedHotel` contiene habitaciones con nombre, paredes, muebles, escondites y mallas agrupadas por material.

La galería es una referencia generada: muestra módulos aislados, techos ocultos y luz de inspección. No es el mapa de la partida. Sus cambios manuales no se incorporan al generador. Después de editar recetas o geometría, ejecuta `./tools/godot.ps1 build-gallery` para reconstruirla. Este comando reemplaza exclusivamente esa galería.

## Dónde cambiar cada aspecto

- **Entrada y flujo de partida:** `game/app/hotel.tscn` y `hotel_main.gd`. Conectan sistemas, refugio, interacciones y carga del piso.
- **Movimiento, resistencia y cámara:** `game/player/player.tscn` y `hotel_player.gd`. La escena expone cámara, linterna, cápsula y pasos; las alturas de agachado y velocidades siguen en el controlador.
- **Locust:** `game/enemies/locust/locust.tscn` para modelo, escala y colisión (el modelo está girado 180° porque mira hacia +Z); `hotel_locust.gd` para percepción, navegación, estados, velocidades y ataque, con constantes al principio; `locust_visual.gd` para la animación procedural (pisadas, IK de piernas, brazos, cabeza) y la señal `footfall` que dispara sus pasos. `tools/capture/locust_gait_capture.gd` genera una hoja de fotogramas de la marcha. Se integra desde el coordinador con una sesión asignada.
- **Escena de entrada:** `game/intro/intro_sequence.gd` construye el dormitorio, el pasillo, la habitación iluminada y un trozo de recepción con los mismos materiales del hotel (usa `hotel_geometry.gd` como constructor), y reproduce una línea de tiempo: claves de cámara (`build_camera_keys`, con tipo de paso y rigidez del giro) y eventos con tiempo, método y argumentos (`build_events`; los golpes están en `BLOWS`). La cámara sigue las claves con muelles, balanceo al andar o correr, inclinación en los giros y temblor de mano. `tv_broadcast.gd` es un SubViewport con el modelo de The Locust posado hueso a hueso (asomarse, abalanzarse y golpear con alcance de dos huesos hasta el punto exacto del cristal). `crack_pattern.gd` dibuja en tiempo de ejecución las grietas de cada golpe (núcleo triturado, radiales, anillos) en un canal por golpe, y `tv_screen.gdshader` compone imagen, estática, líneas entrelazadas, rejilla de fósforo, barra de zumbido, parpadeo, destellos y grietas con refracción. La cama y la tele salen de `tools/props/build_intro_props.gd` (modelos en `assets/props/bedroom/` y `assets/props/tv/`); sus sonidos, de `tools/audio/generate_intro_sfx.py` y, la cama, de `tools/audio/clean_recordings.py`. `hotel_main.gd` la abre con **Nuevo recorrido** (estado `CUTSCENE` de la sesión), la salta con E mantenida o Esc y al terminar genera el piso. Captura de fotogramas: `tools/capture/intro_capture.gd`; niveles: `tools/audio/measure_intro.gd`.
- **Director de ritmo:** `game/director/pacing_director.gd`, creado con cada piso. Decide cuándo puede ocurrir algo (descanso tras persecuciones, separación, un solo evento con consecuencias, quedarse quieto solo trae señales ambientales) y lanza los eventos de The Locust: golpes en una puerta, un objeto que cae (la criatura va a mirar con `investigate()`) y pasos (patrulla guiada con `guide()` a una sala vecina). Constantes al principio; `history` registra cada intento. Sonidos de `tools/audio/generate_event_sfx.py`.
- **Documentos y archivo:** textos en `game/discovery/discovery_catalog.gd`; colocación reproducible sobre mesas, escritorios y mesillas en `game/world/generation/document_placement.gd`; la hoja en el mundo es `game/world/interactables/hotel_document.gd`; lo leído se guarda en `user://discoveries.json` (`game/services/discovery_service.gd`) y se consulta en **Archivo** del menú.
- **Muebles de modelo:** `tools/props/build_model_props.gd` hornea tele, cama, sofá, aplique y monstera (una superficie por material, suelo en y = 0, frente +Z). `prop_factory.gd` los coloca dentro de los huecos de mueble conservando los colisionadores de caja validados. Captura: `tools/capture/props_capture.gd`.
- **Aspecto de The Locust:** `game/enemies/locust/locust_look.gd` sustituye el material del cuerpo por `assets/enemies/locust_reference_material.tres` (textura recoloreada con `tools/art/make_locust_reference_texture.py` y material guardado con `tools/art/build_locust_reference_material.gd`) en el juego y en la escena de entrada. El material se guarda como recurso: un duplicado en memoria provocaba un error al cerrar con el renderizador de pruebas.
- **Multijugador:** `game/net/net_session.gd` (nodo `Services/Net`) abre la sala o se une con ENet, asigna plazas y guarda las opciones del anfitrión; `game/net/match_net.gd` (`Services/Net/Match`) replica el piso: arranque coordinado, estados de jugadores, puertas, armarios, ruidos, criatura, sesión, muertes, reconexión, hoja y versus. `game/net/remote_player.gd` es el cuerpo de otro superviviente. `game/enemies/locust/locust_player.gd` controla a The Locust en versus; `hotel_locust.gd` tiene tres modos de control (`ai`, `puppet`, `player`). La hoja es `game/ui/paper_sheet.gd`. Todos los RPC viven en esos dos nodos de ruta fija; si cambias un mensaje, sube `PROTOCOL` en `net_session.gd`.
- **Portada:** `game/title/title_scene.gd` construye, lejos del hotel (`TITLE_ORIGIN`), la habitación del fondo del menú con los ayudantes de decorado de `hotel_geometry.gd` (`set_wall`, `set_door`, que también usa la escena de entrada) y posa a The Locust con `game/enemies/locust/locust_poser.gd` (girar y apuntar huesos, alcance de dos huesos; lo comparte con la tele de la entrada). `hotel_main.update_title_scene()` activa su cámara solo en el estado `MENU`. Capturas: `tools/capture/title_capture.gd`.
- **Distribución:** `game/world/generation/map_generator.gd`. `floor_definition.gd` define tipos, recetas, tamaños auxiliares y versión del manifiesto. `map_validator.gd` valida grafo y física.
- **Arquitectura y colocación:** `game/world/hotel/hotel_geometry.gd`. Construye habitaciones, puertas, escondites, colisiones, navegación y efectos locales.
- **Muebles provisionales:** `game/world/hotel/prop_factory.gd`. Cada receta recibe el constructor para conservar agrupación de mallas y colisiones. Los modelos externos futuros deben respetar los puntos reservados y el espacio de circulación.
- **Puertas y escondites:** `game/world/interactables/`. Sus nodos se generan con el piso porque dependen de sus conexiones. `hiding_place.gd` es el armario: cuerpo, marco con colisión y dos hojas con bisagra; las hojas usan la capa de puertas y tapan la vista cerradas. Las mallas salen de `tools/props/build_wardrobe.gd`, que divide el modelo `assets/props/wardrobe/wardrobe.fbx` por la junta central; vuelve a ejecutarlo si cambias el modelo.
- **Iluminación y posprocesado:** `game/presentation/presentation.tscn`, `hotel_environment.tres` y `shaders/`. Los ajustes del usuario controlan efectos/calidad durante la partida. `analog.gdshader` simula cinta VHS/videocámara (croma de baja resolución, oscilación de cinta, banda de tracking, ruido de cabezales, grano en sombras, líneas de barrido, viñeta). `camcorder_osd.gd` dibuja REC, fecha y hora por debajo del filtro; la fecha deriva de la semilla. Calidad baja: FXAA; media: SSAO, SSIL, niebla volumétrica y MSAA 2×; alta: además SDFGI y TAA.
- **Materiales:** `game/presentation/materials/*.tres`, editables desde el Inspector. El generador duplica los materiales al construir para que los cambios temporales no contaminen otra instancia. Los shaders comparten `surface.gdshaderinc` (proyección en espacio mundial por cara, ruido y relieve) e `image_maps.gdshaderinc` (mapas fotográficos opcionales). `finish.gdshader` configura tela, lino, metal cepillado, cerámica, cuero y hojas. Las texturas colocadas en `assets/textures/<material>/` se aplican solas; ver su `README.md`.
- **Luces:** `hotel_geometry.gd` crea plafones cálidos, fluorescentes fríos (algunos parpadean, nunca con efectos reducidos) y `practical()` para lámparas de pie y recepción. Todas proyectan sombra para no atravesar paredes y se desvanecen con la distancia (`FADE_BEGIN`, `FADE_LENGTH`, `SHADOW_FADE`) en lugar de encenderse de golpe. SDFGI está desactivado porque filtraba luz a través de muros de 18 cm. Solo son presentación: no alteran rutas, percepción ni colisiones.
- **HUD, menús y ajustes:** `game/ui/interface.tscn` contiene posiciones del HUD (mensaje breve, subtítulos, indicación del refugio y barra de salida); `hotel_ui.gd` genera cada pantalla (intro, principal, pausa con controles, ajustes, personaje, créditos, carga, victoria y señal perdida). `osd_style.gd` define la fuente, colores, tema de controles y pitidos de menú compartidos. Subtítulos e indicaciones quedan por encima del filtro VHS. Una fuente `assets/fonts/vcr_osd_mono.ttf`, si existe, sustituye a la del sistema.
- **Marcas de videocámara:** `game/presentation/camcorder_osd.gd` dibuja bajo el filtro REC, fecha, hora, corchetes de enfoque con la acción disponible y el medidor de resistencia.
- **Linterna:** `hotel_player.gd` la mueve fuera de la cámara (`top_level`) con retraso, balanceo al caminar y calentamiento del filamento; los efectos reducidos lo atenúan.
- **Pantalla:** `settings_service.gd` separa `apply_display()` (modo y tamaño, solo al cambiar pantalla completa o tamaño de ventana, al arrancar o al revertir) del resto de ajustes. Arranca en pantalla completa (`window/size/mode=3`); en ventana ajusta el tamaño al área útil manteniendo 16:9 y la centra. Con `--automation` o `--test-profile` no toca la ventana, para que pruebas y capturas fijen su propio tamaño.
- **Guardado y preferencias:** `game/services/game_session.gd` y `settings_service.gd`. Conservan archivos separados en `user://`; no se guardan preferencias personales en Git.
- **Audio:** archivos de uso real en `assets/audio/`; reproducción/mezcla en `hotel_main.gd`, buses y volúmenes en `settings_service.gd`. Los avisos de Locust usan Threat.

## Estructura del repositorio

`game/` reúne código, escenas y recursos propios por función. `assets/` contiene únicamente archivos importados que usa el juego. `tests/hotel/` y `tests/legacy/` separan regresiones actuales e históricas. `tools/editor/`, `capture/`, `benchmarks/` y `legacy/` reúnen utilidades. `legacy/fuse_prototype/` conserva el H1 completo, accesible con `./tools/godot.ps1 legacy`.

`docs/` contiene diseño, hoja de ruta, tareas, validación y esta guía. `docs/history/` conserva planes anteriores; `docs/assets/` registra la migración de rutas y las huellas de originales trasladados. Los informes históricos no son pruebas nuevas.

`source_assets/` conserva originales locales y paquetes aún sin integrar; `source_assets/audio/` y `characters/` contienen los antiguos archivos sueltos. Esta carpeta está ignorada por Godot y Git: **su copia de seguridad debe incluirla por separado**. Los archivos originales anteriores `song.mp3` y `locust.zip` mantienen su ruta histórica. `evidence/` contiene resultados regenerables y capturas; queda fuera del explorador de Godot y sus resultados no se versionan automáticamente.

## Verificar cambios

Desde PowerShell en la raíz:

```powershell
./tools/verify.ps1
./tools/godot.ps1 playtest -Seed 81
./tools/godot.ps1 hotel-batch
./tools/godot.ps1 compatibility
```

`verify.ps1` ejecuta contratos de escenas, hotel, supervivencia, audio y regresión histórica, secuencialmente, y después la prueba en red (`tools/net_test.ps1`): un anfitrión y dos invitados en cooperativo, y un anfitrión contra un invitado que es The Locust en versus, como procesos reales conectados por 127.0.0.1 (puertos 24600 y 24610). Para revisar solo la red: `./tools/net_test.ps1 -Scenario coop` o `-Scenario versus`. `tools/dev/check_scripts.gd` carga todos los scripts para encontrar errores de compilación de una vez. Guarda un resumen en `evidence/verification.json` y un registro por prueba. Usa preferencias/checkpoints de prueba separados; no toca la partida normal. La prueba de audio funciona en tiempo real. El lote físico de mil mapas es independiente y más largo.

Para otro equipo, configura la variable `GODOT_PATH` o pasa `-GodotPath` a los lanzadores. La galería no modifica checkpoints. Las escenas de jugador, enemigo e interfaz son componentes; para probar jugabilidad usa F5, y para inspección visual usa el taller.

## Convenciones para continuar

- Mantén escenas y controladores de una función en la misma carpeta; usa `snake_case` para archivos y nombres descriptivos para nodos.
- Mueve recursos desde Godot cuando sea posible y conserva los `.uid` de scripts/shaders. Actualiza referencias en herramientas y documentación; ejecuta las regresiones después.
- Edita la fuente de cada sistema, no los nodos generados de una partida ni la galería. Nunca introduzcas una segunda autoridad de generación en una escena de prueba.
- Si cambia la distribución reproducible, revisa explícitamente la versión del generador y la compatibilidad del checkpoint. Esta reorganización mantiene v3.
- Importa copias de trabajo en `assets/`, guarda originales en `source_assets/` y registra procedencia/licencia en `docs/ASSETS.md` antes de distribuir.
- No versionar `.godot/`, registros, preferencias o exportaciones. Sí versionar escenas, scripts, `.uid`, materiales y configuración de importación de assets activos.

## Límites que se mantienen

Las habitaciones siguen siendo procedurales y los menús se rellenan por código; no se ha creado un editor visual de mapas ni se han reemplazado los muebles por assets finales. Otros pisos, sesiones humanas en red y balance siguen pendientes según `TODO.md`.

## Audio espacial incorporado

Dirección con auriculares (paneo del mundo, buses binaurales de la criatura, filtro trasero): ver la sección «Dirección con auriculares» de [AUDIO.md](AUDIO.md); medición con `tools/audio/measure_spatial.gd`.

`game/audio/world_audio.tscn` se instancia en la escena principal. Sus grupos y recursos están documentados en [AUDIO.md](AUDIO.md); `profiles/locust.tres` cambia la presencia de Locust desde el Inspector. Puertas y jugador emiten señales de presentación separadas del ruido que percibe la IA. `sfx/` contiene masters locales ignorados; conservarlos en copias de seguridad.
