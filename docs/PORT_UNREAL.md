# Plan del port de The Four a Unreal Engine 5.8

15 de noviembre de 2026. Solo plan: para escribirlo no se ejecutó Godot ni Unreal, no se compiló nada y no se tocó git. Está hecho para dos lectores: el autor, que decide (apartado 10), y una sesión nueva, que puede arrancar la prueba de concepto con los apartados 2, 5 y 7 sin releer la investigación.

**Dónde está el detalle.** Este documento decide y remite. Los diseños por dominio están en `.claude/specs/unreal/diseno/` (abreviado `D/`): `render.md`, `mundo.md`, `materiales_assets.md`, `poc.md`, `metodo.md`, `jugador.md`, `criaturas.md`, `red.md`, `ui.md`, `audio.md`, `plataforma.md` y `aplicacion.md`. Los informes están en `.claude/specs/unreal/briefs/` (`ue58.md`, `agentes.md`, `experiencias.md`), las fichas del código de Godot en `.claude/specs/unreal/fichas/` y el índice de herramientas del MCP en `.claude/specs/unreal/mcp_catalogo.md`.

**Marcas.** [C] lo comprobé hoy leyendo el archivo que se cita. [E] comprobado en esta máquina el 15 de noviembre según el encargo. Sin marca y con cita a `D/...`: tomado de ese diseño, que da su ruta:línea, sin releer el origen. `UE:` es `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine/`. `<P>` es la carpeta del proyecto de Unreal. Las rutas sin prefijo son de este repo.

**El diseño que faltaba ya está.** `D/aplicacion.md` (aplicación, reglas de partida, director, interactivos y el reloj fijo) se escribió después de la primera versión de este plan y está integrado en 2, 3, 4.3, 6, 7.5, 9, 10 y 11. Ya no falta ningún dominio.

**Críticas aplicadas.** Tres críticos atacaron este plan el 15 de noviembre (`.claude/specs/unreal/criticas/`: cobertura, motor, prueba y método). Cada objeción se comprobó en el código de Godot o del motor antes de aceptarla; las aceptadas ya están en el texto (sobre todo 5.3 a 5.8, 6.2, 8 y 10) y no se repiten aquí.

## 1. Qué se busca y qué no

**Se busca** que cada escena del juego se sostenga junto a una fotografía o una grabación de 1987, al nivel de Subliminal, Lost Fragment o Fractured Mind. Todos los juegos de ese listón son Unreal Engine 5 con Lumen, y Subliminal corre sobre 5.8.4, la versión instalada (`briefs/experiencias.md`, resumen en `.claude/specs/unreal/indice.md:71-72`). Lo que hoy molesta al autor y el port tiene que resolver: el tono, los reflejos de suelo mojado, el z-fighting, lo vacío de los ambientes y las piezas hechas a mano que parecen 3D (apartado 4).

**Se conserva tal cual** el gameplay: reglas, cifras y sensación.

- Las cifras se copian del código de Godot con su mismo nombre, como constantes en C++ (`D/metodo.md:124`).
- Las plantas siguen saliendo de una semilla, y la misma semilla da la misma planta que en Godot mientras dure el port (`D/mundo.md:95`).
- El jugador se mueve con la misma cuenta que hoy, no con el movimiento de serie de Unreal (`D/jugador.md:125-130`).
- Las criaturas deciden con la misma máquina de estados y el mismo orden de sorteos (`D/criaturas.md:118-122`).
- El sonido se propaga con la regla propia de hoy, por vanos, rodeos y puertas (`D/audio.md:112`).
- La red reparte el trabajo igual: el anfitrión decide, cada cliente mueve su cuerpo, viaja la semilla y no la planta (`D/red.md:124, 137, 143`).
- La cadena de la camcorder (lente, cinta, OSD grabado bajo la cinta, menús fuera) se mantiene (`D/render.md:132-142`).

**Mejora:** la luz (rebote y reflejos reales, sombra en todas las luces), las superficies (escaneos fotográficos en lugar de ruido por código), la densidad de las salas (modelos reales y más vestimenta), el aire (niebla con sombra y polvo iluminado) y la tinta de The Lurker, que pasa a quitar luz de verdad (`D/criaturas.md:137`).

**Queda fuera:**

- Cambios de reglas, cifras o contenido nuevo. Pisos 3 y 4.
- El perfil Compatibility, el nivel Muy bajo y las gráficas sin DX12 con Shader Model 6 (`D/render.md:112`). macOS (`D/plataforma.md:108`).
- Todo lo que existía para suplir al motor: VoxelGI por sala, sondas, SSR, atlas de sombras, capas de render por sala, calentamiento de sombreadores, imágenes horneadas del nivel mínimo (`D/render.md:70-72`, `D/materiales_assets.md:119`).
- El ruido por código de las superficies: no se porta (`D/materiales_assets.md:108`).
- La partida a medias (Continuar) de Godot: no se migra. Récords y descubrimientos sí (`D/plataforma.md:81-88`).
- Blueprints con lógica, StateTree, Behavior Tree, Control Rig, Animation Blueprint, MetaSounds, Sequencer y PCG: son assets binarios que un agente no puede revisar como texto (`D/criaturas.md:120-121`, `D/jugador.md:153`, `D/audio.md:120`, `D/ui.md:143`, `D/mundo.md:118`).
- Niagara. Un guion de Python no puede construir un sistema: las herramientas de Niagara del MCP no están expuestas a guion [C `UE:Plugins/Experimental/Toolsets/NiagaraToolsets/Source/NiagaraToolsets/Private/NiagaraToolset_Assets.h:118`, `meta = (AICallable)`], y del editor de Niagara solo se expone el horneado [C búsqueda de `BlueprintCallable` en `UE:Plugins/FX/Niagara/Source/NiagaraEditor`]. Motas, polvo de techo y granos se dibujan con instancias escritas desde C++, como ya decide `D/criaturas.md:142` para los 46 000 granos.
- Mover (Experimental), `CharacterMovementComponent`, Iris (Beta), EOS, Steam Audio, DLSS y FSR (los dos últimos, solo si el autor los pide).
- Música nueva, segundo idioma y accesibilidad nueva: solo si el autor lo pide.

## 2. Decisiones de base

### 2.1 Tabla de decisiones

| Tema | Decisión | Por qué y dónde está el detalle |
|---|---|---|
| Motor | Unreal Engine 5.8.4, el instalado. No se actualiza durante el port | Es instalación de lanzador: el motor no se puede recompilar ni modificar (`indice.md:24, 99`). 5.9 entra en Preview este mes y UE 6 se anuncia para finales de 2027 (`indice.md:121`). Subliminal usa 5.8.4 con el motor modificado; aquí no hay esa opción |
| Compilador | MSVC 14.50 de las Build Tools 2026 y el SDK de .NET Framework 4.8 | `TP_Blank` compila con `Build.bat` en 78 s [E]. 14.50 es el rango probado por Epic (`indice.md:25`) |
| Lenguaje | C++ y nada más para el juego. Python solo para guiones del editor que crean assets | AngelScript pide recompilar el motor, UnrealSharp es beta, Verse no vale en 5.8, UnLua está parado; C++ es donde mejor rinden los agentes (`D/metodo.md:122`) |
| Nombre y carpeta | Proyecto `TheFour`, en `E:/Projects/TheFourUE`, con `TheFour.uproject` en la raíz. Versión 2.0.0 (la serie 1.x queda para Godot) | Sin espacios ni guion largo: el nombre es también la carpeta del perfil del jugador (`D/plataforma.md:35, 120`) |
| Repositorio | Repositorio nuevo y privado, aparte del de Godot. Git LFS para `SourceAssets/` y `Content/Hand/`. `Content/Gen/` no se versiona: se regenera con guiones | El plugin de Epic y el `.mcp.json` buscan el `.uproject` desde la raíz de la sesión; Godot importaría cualquier png o glb bajo su raíz; LFS se estrena limpio (`D/metodo.md:120, 136`). El repo de Godot se lee como referencia de solo lectura |
| Módulos | Cuatro: `FourCore` (C++20 sin cabeceras de Unreal), `TheFour` (juego), `TheFourRender` (sombreadores y extensión de vista, fase `PostConfigInit`), `TheFourEditor` (solo editor). Dentro de `TheFour`, una carpeta por dominio: `World/`, `Player/`, `Creatures/`, `Net/`, `UI/`, `Audio/`, `Platform/`, `Bots/`, `App/`, `Interact/`, `Scenes/` y `Dev/` (las cuatro últimas, de `D/aplicacion.md:31-34`). En `FourCore`: `Rules/`, `Director/`, `Capture/` y `App/` entre otras | Ver 2.3, fila 2. `Dev/` (observador, F8 y F9) queda fuera de Shipping como `Bots/` |
| Unidades y ejes | `FourCore` entero trabaja en el espacio de Godot (metros, Y arriba, 60 Hz). Un solo archivo, `FourSpace.h`, convierte: Unreal = (x, z, y) × 100; guiñada de Unreal = −guiñada de Godot. Ningún otro archivo multiplica por 100 ni cambia ejes, y una prueba de texto lo vigila | Es la misma regla que aplica Interchange al importar glTF, así un modelo importado y una posición calculada coinciden (`D/mundo.md:121-126`). El cuerpo del jugador usa el frente +X de Unreal (`D/jugador.md:53`) |
| Reloj | Paso fijo de 60 Hz propio: `UFourSimClock`, colgado de `FWorldDelegates::OnWorldPreActorTick`, que el motor emite antes de `TG_PrePhysics` [C `UE:Source/Runtime/Engine/Classes/Engine/World.h:4523-4524`, `UE:Source/Runtime/Engine/Private/LevelTick.cpp:1675, 1750`]. Da varios pasos por fotograma (tope 8) y recorre diez fases en el orden del código de Godot; los `Tick` de actor solo dibujan e interpolan. Sin subpasos de Chaos ni física asíncrona. Se quedan en el delta de fotograma, como hoy, el reloj del piso, la captura y la cinta de muerte | El tick de Unreal es variable y sin orden dentro de un grupo; el juego tiene 13 archivos con `_physics_process` (`indice.md:69`). Detalle y pruebas en `D/aplicacion.md:61-75, 184-189, 199`; orden de fases, 2.3 fila 15 |
| Azar | Se portan literal el PCG32 de Godot, `randf`, `randi_range`, el `hash()` de Variant y el introsort de `sort_custom`. `FRandomStream`, `TMap` y `std::sort` quedan prohibidos en la generación y en todo sorteo con semilla (director, renacer, llave, sangre, caída de cámara). Solo lo local por diseño (alucinaciones, apariciones) usa `FRandomStream` (`D/aplicacion.md:195`) | Sin eso la misma semilla da otra planta y no hay prueba barata de que 9 000 líneas de generador se han portado bien (`D/mundo.md:95-107`) |
| Iluminación | Lumen por hardware para rebote y reflejos, MegaLights con sombra trazada para la luz directa. Sin luz horneada, sin luz de cielo y sin ambiente. Unidades físicas (lúmenes y kelvin). `r.SkinCache.CompileShaders=True` en `DefaultEngine.ini`, que la tabla de `D/render.md:20-37` omite | Los interiores se generan al empezar la partida: no hay horneado posible. MegaLights da sombra en todas las luces con coste casi constante (`D/render.md:99-101, 124`). Epic lo da por listo para producción según el foro (`briefs/ue58.md:99`), pero el motor instalado aún lo rotula «Experimental feature» [C `UE:Source/Runtime/Renderer/Private/MegaLights/MegaLights.cpp:29`]; la salida es el nivel sin trazado (R14). Sin la caché de pieles, una malla con esqueleto no entra en el trazado [C `UE:Source/Runtime/Engine/Private/GPUSkinCache.cpp:92-99, 2328`]: criaturas y compañeros no darían sombra de MegaLights ni saldrían en los reflejos |
| Niveles de calidad | Cuatro: Sin trazado, Medio, Alto (objetivo de la RTX 4060 Ti a 1080p) y Ultra. Solo DX12 con SM6 | `D/render.md:103-112`. Cambia los requisitos mínimos: decisión del autor (apartado 10) |
| Geometría | Mallas estáticas construidas en el editor por guion (con Nanite) y colocadas en ejecución como instancias (`UInstancedStaticMeshComponent`). Nunca triángulos generados en ejecución ni HISM | Lo generado en ejecución pierde Nanite, campo de distancia, trazado y casi todas las tarjetas de Lumen (`D/mundo.md:113-119`). Es la apuesta técnica mayor y la prueba de concepto la comprueba (apartado 5) |
| Red | Servidor de escucha con las clases del motor (`AGameMode`, `AGameState`, controlador). `OnlineSubsystemSteam` con `SteamSockets`. Iris apagado. El cliente manda su movimiento a 20 Hz como hoy. Semilla en cada par y SHA-256 del manifiesto | `D/red.md:124-153` |
| Guardado | JSON propios con escritura atómica, no `USaveGame`. El perfil de pruebas se elige por construcción: una ejecución desatendida no puede resolver la carpeta real | `D/plataforma.md:112-118` |
| Textos | CSV con las claves de `docs/textos_juego.txt` y el texto sacado del literal del código de Godot congelado, no del catálogo, que no se toca desde el 23 de octubre y ya no lo recoge todo (falta «SONIDO DE LAS OFICINAS», `game/ui/hotel_ui.gd:112` [C]). Español nativo. Una prueba falla si aparece «·» o «—», y otra si un literal visible de `game/ui`, `app`, `intro`, `title` o `floors` no está en las tablas | `D/ui.md:58-62` |
| Mapa | Ningún `.umap` con contenido: todo se crea en ejecución | Ver 2.3, fila 12 |

### 2.2 Qué va en C++, qué en datos y qué en assets

| Va en | Qué | Regla |
|---|---|---|
| C++ sin motor (`Source/FourCore/`) | Azar y tipos de Godot, generadores, validadores, plan de montaje, cifras del jugador, mentes de las criaturas, rutas y matemática de audio, récords y puntuación | Si una regla no necesita mundo, va aquí. Se compila con `cl.exe` y se prueba en segundos, sin editor y en paralelo (`D/metodo.md:128`) |
| C++ con motor (`Source/TheFour/`, `TheFourRender/`) | Actores, componentes, subsistemas, interfaz (UMG nativo), red, audio, presentación | Sin Blueprints. Las pruebas de Automation van en `Private/Tests/` |
| Sombreadores en texto (`Shaders/`) | `.ush` y `.usf`: lente, cinta, smear, patrones de moqueta, papel y baldosa, tinta, eco | El material es una cáscara con un nodo Custom que incluye el `.ush` (`UE:Source/Runtime/Engine/Public/Materials/MaterialExpressionCustom.h:97`, vía `D/render.md:52`) |
| Datos en texto | `Config/*.ini` (render, red, entrada de proyecto), `Tools/assets/*.json` (materiales, mallas, audio), `Tools/capture/*.json` (tomas), `Content/Text/*.csv`, `golden/` (huellas compartidas con Godot) | Las cifras del juego no van en DataTables ni DataAssets: son binarios sin diff (`D/metodo.md:124`) |
| Guiones (`Tools/`) | `ue.ps1` (único lanzador), `verify.ps1`, `core_tests.ps1`, `mcp.ps1`, `build_content.ps1`, y los Python del editor que crean materiales, texturas, mallas, IES, audio y avatares | Todo asset binario sale de un guion y se puede borrar y regenerar |
| Assets binarios generados (`Content/Gen/`, fuera de git) | Materiales maestros e instancias, texturas, mallas estáticas y de esqueleto, clips, `USoundWave`, perfiles IES | El MCP sirve para explorar y comprobar; lo que deba existir acaba en un guion (`D/metodo.md:132`) |
| Assets a mano (`Content/Hand/`, en LFS) | Se espera vacío | Cada archivo aquí pide permiso del director |

### 2.3 Contradicciones entre diseños y cómo quedan

| N.º | Asunto | Qué decía cada uno | Decisión |
|---|---|---|---|
| 1 | Geometría de la prueba de concepto | `D/render.md:166`: cuatro escenas montadas por guion. `D/mundo.md:140-147`: `FourCore/Gd`, plan en JSON y `AFloorBuilder` con instancias. `D/materiales_assets.md:123-128`: un pasillo y un despacho con 15 piezas. `D/poc.md:86-98`: una planta entera volcada a glTF e importada con Interchange, un actor por caja | Camino mixto, apartado 5.2: las plantas reales de `D/poc.md`, pero montadas por instancias en ejecución como pide `D/mundo.md`, sin portar nada del generador. Motivo: es el único que responde a la vez a la pregunta del autor y a la apuesta técnica de 2.1 |
| 2 | Módulos | `D/metodo.md:40`: cuatro. `D/mundo.md:43`, `D/jugador.md:35`, `D/criaturas.md:50, 66` y `D/ui.md:24` añaden `FourWorld`, `FourPlayer`, `FourCreatures`, `FourBots` y `FourUI` | Cuatro módulos y carpetas por dominio. Menos `.Build.cs`, menos macros `*_API` y menos dependencias cruzadas que un agente pueda romper; las carpetas disjuntas dan el mismo paralelismo. `Bots/` se excluye de Shipping por condición de compilación |
| 3 | Ajustes | `D/plataforma.md:56`: `UFourSettings`, `settings.json` en el perfil, migra los valores sin motor. `D/ui.md:66, 141`: `UFourUserSettings` sobre `UGameUserSettings`, `GameUserSettings.ini`, sin migrar | Gana `D/plataforma.md`: un solo formato y el perfil de pruebas por construcción, que resuelve el riesgo 7 de `D/ui.md:184`. Ventana, resolución y sincronía se aplican con las funciones del motor sin guardar su `.ini`. La tabla `FFourSettingRow` y la pantalla de `D/ui.md:69` se mantienen |
| 4 | Perfil de pruebas | `D/metodo.md:100`: `-FourTestProfile`. `D/plataforma.md:73-75`: `-FourProfile=<nombre>` y `Profiles/auto/` forzado en ejecuciones desatendidas | `D/plataforma.md` |
| 5 | Carpeta de guardados | `D/red.md:115`: `Saved/SaveGames/`. `D/plataforma.md:73`: `<ProjectSavedDir>/Profile/` | `D/plataforma.md` |
| 6 | Personaje de la prueba de concepto | `D/poc.md:108`: desechable, de la plantilla de Epic. `D/jugador.md:161-165`: el movimiento real ya portado | El de la plantilla, con las velocidades, la altura de ojos y el FOV del juego. La prueba juzga la imagen, no la sensación, y así se le dice al autor. El movimiento real es de la fase 2 |
| 7 | Capturas | `D/poc.md:39, 110`: `AFourPocBench` con `HighResShot`. `D/metodo.md:70`: `UFourCaptureSubsystem` con `FScreenshotRequest` y tomas en JSON | Una sola clase, la de `D/metodo.md`, con el recorrido de medición dentro. No se escriben dos |
| 8 | FOV del encuadre de salas | `D/metodo.md:110, 256`: 55° vertical, 85,6° horizontal. `D/poc.md:9`: 55° horizontal | Es horizontal [C `tools/capture/room_framing.gd:9-14`; `tools/capture/office_rooms_capture.gd:195-196` fija `KEEP_WIDTH`]. En Unreal se usa 55 tal cual |
| 9 | Oscuridad de la vista de eco | `D/render.md:95`: material de posprocesado. `D/criaturas.md:141-143`: plano translúcido hijo de la cámara | `D/criaturas.md`: los translúcidos se dibujan antes que el posprocesado y quedarían tapados |
| 10 | Calcomanías con Substrate | `D/render.md:94`: con formato 0 no hace falta DBuffer. `D/materiales_assets.md:49, 161`: `r.DBuffer=True`, y avisa de que el informe y el código del motor no cuadran | No se decide leyendo: cuatro calcomanías en la prueba de concepto lo resuelven |
| 11 | Nombres de carpeta | `SourceArt/` en `D/poc.md` y `D/materiales_assets.md`; `SourceAssets/` en `D/metodo.md:29`. `tools/` en `D/mundo.md` | `SourceAssets/` y `Tools/` |
| 12 | Mapa de arranque | `L_Main` (`D/metodo.md:54`), `L_Boot` (`D/plataforma.md:46`, también `D/aplicacion.md:50`), «mapa vacío» (`D/mundo.md:60`) | Primero se prueba el mapa vacío del propio motor, `/Engine/Maps/Entry` (existe: `UE:Content/Maps/Entry.umap` [C]); el modo de juego crea todo en C++. Si no sirve, `L_Boot` creado por guion. Evita un binario y el hueco del MCP, que no tiene herramienta para crear un nivel [C `mcp_catalogo.md:589-611`: solo `load_level` y `get_current_level`]. El flujo de `D/aplicacion.md` vale con cualquiera de los dos: solo reabre el mapa de arranque con `?listen` |
| 15 | Orden del paso fijo | `D/criaturas.md:88`: supervivientes, criatura, director. `D/aplicacion.md:66, 189`: el del código, con el director antes que la criatura | El del código, por el criterio 2 (misma sensación) y porque el volcado del director solo coincide así. Comprobado: el director es hijo del hotel y la criatura se añade al nivel después que el hotel [C `game/app/hotel_main.gd:990, 1544`]. `EFourPhase` queda: `Level`, `Net`, `Phantoms`, `LocalPlayer`, `WorldAudio`, `Doors`, `Hides`, `Director`, `Creature`, `Remotes` |
| 16 | Sangre | 4.3 de este plan: manchas y sangre como calcomanías. `D/aplicacion.md:91`: instancias como el MultiMesh de hoy, porque da por hecho que Substrate en formato 0 no admite calcomanías DBuffer | Lo decide la fila 10. `FBloodPlan` (gotas, manchas y charco con su semilla) es el mismo en los dos casos; solo cambia cómo dibuja `UFourBlood`. Si las calcomanías funcionan, calcomanías, que no hacen z-fighting; si no, instancias separadas del suelo |
| 17 | Argumento del perfil de pruebas | `D/aplicacion.md:115` y `D/metodo.md:100` conservan `-FourTestProfile` | Se queda la fila 4: solo `-FourProfile=<nombre>` y la carpeta `Profiles/auto/` forzada (`D/plataforma.md:73-74`). `FLaunchArgs` no analiza `-FourTestProfile` |
| 18 | Números de unidad | `D/aplicacion.md` numera sus unidades A0 a A24; `D/audio.md` usa A1 a A13 | En este plan las de aplicación se citan como AP0 a AP24 (AP0 es su A0). El diseño no se toca |
| 19 | Motas y polvo de techo | `D/render.md:60`: `NS_DustMotes` por el MCP. `D/criaturas.md:186` (C14): cuatro sistemas `NS_`, con un guion de Python de reserva (`:208`) que no puede existir | Instancias escritas desde C++, como los granos de `D/criaturas.md:142` (apartado 1). C14 conserva sus recuentos de partículas como aceptación |
| 13 | Entrada de las mallas | `D/mundo.md:58`: reimportar desde los originales. `D/materiales_assets.md:114`: glb exportado desde cada `.res` de Godot | `D/materiales_assets.md`: los `.res` ya llevan giro, escala, despiece y encaje, que son medidas de gameplay. El original entra pieza a pieza donde una captura lo pida |
| 14 | Huesos movidos por código | `D/jugador.md:151-155`: `UPoseableMeshComponent`. `D/criaturas.md:131-135`: `FAnimInstanceProxy` propio | Se prueba primero el más simple (`UPoseableMeshComponent`) con el primer esqueleto que se importe. Si da sombra y velocidades correctas, vale para los tres cuerpos; si no, el proxy para los tres. No se escriben los dos a ciegas |

### 2.4 El dominio de aplicación y reglas

Era el que faltaba: `game/app/` (27 archivos, 11 247 líneas), `game/director/pacing_director.gd` (893), las reglas de `game/floors/` (5 archivos, 582 líneas, más 6 objetivos, 1 828 [C, recuento de hoy]), los interactivos que no son puertas y el reloj fijo que piden `D/jugador.md:51`, `D/criaturas.md:88, 236` y `D/audio.md:44`. Lo cubre ahora `D/aplicacion.md`. Lo que fija:

- **El nivel se parte en cuatro, por quién manda** (`D/aplicacion.md:182`): lo que decide el anfitrión, en `AFourGameMode` (dueño de `FourCore::FSession`); lo que todos leen, en `AFourGameState`; lo que cada máquina monta, en `UFourFloor`; las pantallas, en `UFourFlow`, que vive en la instancia del juego para sobrevivir al cambio de mundo de un invitado.
- **El reloj** de 2.1, con el orden de 2.3 fila 15.
- **Reglas, dificultad, pisos y objetivos en `FourCore`** como tablas `constexpr`, no DataTables (`D/aplicacion.md:191`). Un objetivo son dos mitades: la lógica pura y unos actores finos.
- **El director se porta literal**, con dos interfaces (lo que pide al nivel y a la criatura) y 20 volcados grabados en Godot que la capa 1 repite línea a línea (`D/aplicacion.md:193`).
- **Los interactivos**: un actor sin replicar por pieza, con el índice de hoy y las RPC de `D/red.md` (`D/aplicacion.md:131-145`).
- **Modos de herramienta** por argumentos `-Four…` sobre un solo camino de arranque (`D/aplicacion.md:111-127`).

No entra nada en la prueba de concepto (`D/aplicacion.md:207`). Sus unidades, AP0 a AP24, se reparten en las fases de 6.2.

## 3. Mapa de sistemas

Tamaños contados hoy con `find` y `wc` sobre los `.gd` [C]. `game/` suma 72 952 líneas. Tamaño relativo: S (hasta 5 unidades de trabajo), M (6 a 12), L (13 a 20), XL (más de 20).

| Área de Godot | Rutas y tamaño | Destino en Unreal | Enfoque | Riesgo | Tamaño |
|---|---|---|---|---|---|
| Generación de plantas | `game/world/generation/` (15 archivos, 10 668 líneas) y paletas de `game/floors/palettes/` (2, 1 526) | `FourCore/Gd`, `Floor`, `Gen` | Port literal, con paridad bit a bit contra una huella nueva grabada desde Godot (`D/mundo.md:111`) | Alto: funciones trascendentes, empates de ordenación, anchos de coma flotante | XL |
| Montaje del hotel | `game/world/hotel/` (10, 5 124) | `FourCore/Plan` y `TheFour/World` (`AFloorBuilder`, `UFloorSubsystem`) | Se separa la decisión (plan en metros de Godot) del montaje (instancias). Desaparecen rebote, sondas y capas | Medio: hoy decisión y nodos van mezclados (`D/mundo.md:181`) | L |
| Montaje de las oficinas | `game/world/office/` (28, 9 690) | Lo mismo, más el kit de piezas | Igual. Se porta cuando el generador de Godot esté congelado | Alto: sigue cambiando (`REAL_PLAN` apagado [C `game/floors/palettes/office_palette.gd:17`]) | XL |
| Interactivos | `game/world/interactables/` (9, 1 516) | `TheFour/World` (`AFourDoor`) y `TheFour/Interact` (nueve actores por índice y `UFourLifts`, `UFourTelevisions`, `UFourCodeLock`) | Port. Puertas en `D/mundo.md:168`; el resto en `D/aplicacion.md:129-145` | Medio | M |
| Jugador | `game/player/` (6, 2 123) | `FourCore/Player` y `TheFour/Player` | Port literal del tick y de `move_and_slide`, demostrado con trazas grabadas en Godot (`D/jugador.md:132-135`) | Medio: los barridos de Chaos no son los de Godot | L |
| Criaturas | `game/enemies/` (23, 14 416: Locust 4 952, Lurker 8 799) | `FourCore/Creature` y `TheFour/Creatures` | Mentes literales sin motor; cuerpo, tinta, polvo y eco rehechos sobre el motor | Alto: paridad de sorteos, rutas de Recast distintas, modelo de The Locust sin licencia de venta | XL |
| Aplicación y reglas | `game/app/` (27, 11 247), `game/director/` (1, 893), reglas de `game/floors/` (unas 2 400), `game/discovery/` (52) | `FourCore/Rules`, `Director`, `Capture`, `App`; `TheFour/App`, `Scenes`, `Dev` (2.4) | Reglas, sesión, director y partituras sin motor, con volcados de Godot; flujo, reloj y escenas sobre el motor | Alto: es el centro del juego y el dueño del reloj; paridad del director | XL |
| Red | `game/net/` (5, 2 352), 55 RPC | `TheFour/Net` | Cada RPC conserva nombre y argumentos sobre las clases del motor (`D/red.md:66-100`) | Medio: orden entre RPC fiables, topes de tamaño | L |
| Servicios y plataforma | `game/services/` (6, 1 558), `project.godot`, exportación | `TheFour/Platform`, parte en `FourCore` | Port directo a JSON; Steam por ini; empaquetado por `RunUAT` | Bajo | L |
| Interfaz | `game/ui/` (14, 5 297), `game/title/` (165), `game/intro/` (3, 907) | `TheFour/UI` | UMG con clases nativas, pantallas construidas por código como hoy; papeles con `NativePaint` (`D/ui.md:123, 139`) | Medio: widget nativo sin Blueprint, interfaz dibujada a textura bajo la cinta | L |
| Audio | `game/audio/` (9, 1 377) y 202 archivos de sonido | `FourCore` (ruta, oídos, tensión, aura) y `TheFour/Audio` | Se traslada la lógica; Unreal pone mezclador, efectos y paneo. Sin MetaSounds (`D/audio.md:25`) | Medio: cambiar de bus una voz que suena | L |
| Render y cámara | `game/presentation/` (6 `.gd`, 1 631) y 34 archivos de sombreador [C] | `Config/DefaultEngine.ini`, `TheFourRender`, `Shaders/` | Se sustituye por Lumen y MegaLights; la camcorder se porta | Alto: memoria de vídeo y fotograma en 8 GB | L |
| Materiales y assets | 105 materiales `.tres`, 216 mallas `.res`, 30 sets de texturas (`D/materiales_assets.md:9-12`) | `Tools/assets/` y `Content/Gen/` | Rehecho por guion: 7 materiales maestros, escaneos en lugar de ruido | Medio: guiones de Python sin ventana | L |
| Pruebas | `tests/` (54 `.gd`, 48 de ellos `*_test.gd`, 18 780 líneas [C]) | Tres capas (`D/metodo.md:77-85`) | Cada dominio porta las suyas dentro de sus unidades. M12, en la fase 1, deja `golden/test_map.md`: cada prueba con su unidad y su fase, o el motivo de no portarla. Hoy 14 no las nombra ningún diseño, casi todas de oficinas (`office_test`, 1 381 líneas; `office_light_test`, 747) y de The Lurker, más `room_light_test` [C, búsqueda de cada nombre en `D/`] | Medio | L |
| Herramientas | `tools/` (205 guiones [C]); capturas | `Tools/ue.ps1`, `verify.ps1`, tomas en JSON | Un programa de captura con datos, no un guion por captura | Bajo | L |
| Bots | `tools/bots/` (20 archivos, 4 942 líneas, `D/criaturas.md:19`) | `TheFour/Bots` | Port tardío | Medio | M |

El encargo habla de 106 archivos de pruebas; lo contado hoy son 54 `.gd` en `tests/`. Fuera de `.claude/` hay 55 `*_test.gd`, pero los que sobran son copias en `evidence/` y un banco de `tools/workbenches/` [C].

## 4. Las visuales

### 4.1 Qué se quiere conseguir

Clave baja con charcos de luz: lo que no recibe luz directa o rebote queda negro, y la cámara no ve en la oscuridad (`D/render.md:124`). Tinte de 1987 que sale de la física y no de un filtro. Superficies fotográficas. Salas llenas. Y la camcorder de hoy encima.

### 4.2 Con qué

| Pieza | Decisión | Detalle |
|---|---|---|
| Rebote y reflejos | Lumen por hardware | `D/render.md:99` |
| Luz directa | MegaLights con sombra trazada. Una luz rectangular por luminaria de oficina en lugar de las tres de hoy; apliques y plafones con perfil IES generado desde las curvas de `lighting.gd` | `D/render.md:74, 59` |
| Unidades | Lúmenes y kelvin en una tabla (`FourLightFixtures.h`). Las energías de Godot no se trasladan. Valores de partida por calibrar: luminaria de dos tubos 3000 lm a 4100 K, plafón 800 lm a 2700 K, aplique 250 lm a 2600 K, linterna 60 lm | `D/render.md:124`; son de memoria, no de catálogo (`D/render.md:239`) |
| Aire | Niebla de altura volumétrica con sombra por MegaLights y motas que solo brillan donde llega luz: instancias escritas desde C++ con un material translúcido iluminado por el volumen, no Niagara (apartado 1) | `D/render.md:80, 124`; `D/criaturas.md:142` |
| Exposición | La automática del motor con máscara centrada y velocidades asimétricas: reproduce el iris sin código propio. Exposición local apagada | `D/render.md:127-130` |
| Tinte | Blanco de cámara a 3200 K, incandescentes a 2700 K (cálido) y fluorescentes a 4100 K (verdoso frío), más saturación y contraste por piso. Sin LUT | `D/render.md:128` |
| Curva tonal | Primero la del motor rebajada; si se lee como cine y no como vídeo, rodilla propia. Se decide en la prueba de concepto | `D/render.md:129` |
| Camcorder | Smear CCD en HDR antes del reescalado; lente y cinta como materiales tras la curva tonal; la interfaz de juego se dibuja a textura y entra bajo la cinta | `D/render.md:134-142`, `D/ui.md:34` |
| Reescalado | TSR al 67 % a 1080p. DLSS y FSR, opcionales y tardíos | `D/render.md:144` |
| Superficies | `M_Surface` con coordenada de mundo propia (una muestra por la cara dominante, como hoy) y los 30 sets CC0 a 2048 px. Solo se porta a HLSL lo que es identidad del lugar: moqueta, papel y baldosa | `D/materiales_assets.md:108-112` |
| Substrate | Sí, formato 0 | `D/materiales_assets.md:111` |
| Mallas | Nanite en todo lo opaco y rígido. Las 216 mallas entran como glb exportado desde Godot. Persianas, rejilla de techo, rodapiés y conductos, con Geometry Script en el editor. El guion de importación fija y anota en `Tools/assets/*.json` los ajustes de proxy de trazado de cada malla: la sombra trazada sale de la malla de respaldo de Nanite y no de la malla entera [C `UE:Source/Runtime/Engine/Private/Rendering/NaniteResources.cpp:194-198`; `UE:Source/Runtime/Engine/Classes/Engine/StaticMesh.h:1350`]. `M_Surface` no activa `bCompatibleWithLumenCardSharing`: con coordenada de mundo, todos los muros compartirían una captura | `D/materiales_assets.md:114-116, 155` |
| Fuentes de assets | Lo que ya hay en `source_assets/`, Poly Haven y ambientCG (CC0, sin cuenta). Megascans solo si lo trae el autor con su cuenta de Epic | `D/materiales_assets.md:180-189` |

### 4.3 Los problemas de hoy y qué los resuelve

| Queja del autor | Causa hoy | Remedio en el port | Dónde se demuestra |
|---|---|---|---|
| El tono | La gradación es un filtro sobre luces sin unidades | Temperatura real de cada luz contra el blanco de 3200 K | Prueba de concepto: tono de la banda de pared a 20° o menos de la referencia (criterio de `tools/capture/office_rooms_capture.gd:49-51`, vía `D/poc.md:161`) |
| Reflejos de suelo mojado | SSR y sondas con atlas de 64 plazas (`D/render.md:9`) | Reflejos de Lumen. El mojado es rugosidad: máscara de charcos y calcomanías que la bajan (`D/materiales_assets.md:118`) | Recepción y aseos de la prueba: el suelo refleja la forma de las luminarias |
| Z-fighting | Piezas pegadas y coplanares | Nada coplanario: manchas, sangre y rótulos son calcomanías (`D/materiales_assets.md:117`; la sangre, según 2.3 fila 16), y una prueba pura falla si dos caras coplanares se solapan (`D/mundo.md:163`) | Vídeo de 60 s en la prueba; después, la prueba de U8 en 50 semillas |
| Ambientes vacíos | Pocas piezas y 14 tipos de oficina sin modelo | Vestimenta con modelos reales, más calcomanías, polvo y niebla; más fuentes de sonido de ambiente si el autor lo acepta (`D/audio.md:129`) | Salas elegidas de la prueba |
| Hecho a mano que parece 3D | Muebles de cajas (`game/world/hotel/prop_factory.gd`), piezas de código sin UV y superficies de ruido | Modelos reales (lista en `D/materiales_assets.md:153`), piezas regulares por Geometry Script y escaneos | Lista cerrada de piezas de código visibles en las salas elegidas: vacía |

Aviso honrado: el motor resuelve el tono, los reflejos y las sombras. Lo vacío y lo hecho a mano no los resuelve el motor: los resuelven los assets y las reglas de vestimenta, que son el trabajo largo. Y el z-fighting que exista en la planta de Godot viaja con ella a la prueba; allí se ve dónde está.

### 4.4 Presupuesto (objetivos por medir, no medidas)

Nivel Alto en la RTX 4060 Ti: 14,5 ms a 1080p, que cabe en 16,6. A 1440p salen 17,3 ms: no cabe, pide el 50 % de resolución interna o el nivel Medio. Memoria de vídeo: tope de 6,5 GB de 8; hoy Alto usa 2,2 GB (`D/render.md:146-160`). Es lo primero que mide la prueba de concepto.

## 5. La prueba de concepto del piso 1 y del piso 2

### 5.1 Alcance y la pregunta

Una planta entera del hotel (semilla 81) y otra de las oficinas (semilla 7), que son las de las capturas y el banco de hoy, vistas en Unreal con la luz, los materiales y la cámara del port. Once salas vestidas y calibradas contra su referencia; el resto de cada planta, con materiales y luces por regla y sin vestir, como línea base honrada. Sin gameplay, criaturas, sonido, interfaz ni red.

| Piso | Sala | Qué queja ataca |
|---|---|---|
| 2 | Recepción y llegada | Tono; reflejo del suelo encerado |
| 2 | Pasillo | Charcos de luz; z-fighting de suelo |
| 2 | Despacho | Vacío; piezas hechas a mano |
| 2 | Sala de aseos | Reflejos de suelo mojado |
| 2 | Nave de cubículos | Vacío; 9 a 16 luminarias a la vez |
| 2 | Archivo, a oscuras | Linterna, sombras, motas |
| 1 | Recepción | Tono; baliza roja |
| 1 | Pasillo con apliques | Charcos de luz; moqueta |
| 1 | Dormitorio | Cama y armario hechos a mano |
| 1 | Baño | Baldosa; reflejos |
| 1 | Sala oscura | Linterna |

Tabla completa con tomas y referencias en `D/poc.md:120-132`. Además, dos tomas por piso de salas sin vestir, que enseñan lo que da el port mecánico. La pregunta al autor, de sí o no, va en tres partes con todo delante (11 parejas, 4 tomas sin vestir, dos vídeos, tabla de rendimiento y coste rehecho, 5.8):

1. ¿Este techo vale? (salas vestidas).
2. ¿Lo que da el port mecánico vale como punto de partida? (salas sin vestir).
3. ¿Se porta The Four a Unreal, sabiendo que cuesta las ventanas que dice la estimación rehecha?

### 5.2 Camino elegido

**Volcar cada planta desde Godot en datos y montarla en Unreal por instancias, en ejecución.** Es la decisión de 2.3, fila 1.

1. Una herramienta nueva de Godot levanta `game/app/hotel.tscn` como las capturas y recorre el árbol ya construido. El montaje de hoy deja un `MultiMeshInstance3D` por sala y grupo, llamado `Mesh_<material y forma>` para las cajas y `Model_<nombre>` para los modelos [C `game/world/hotel/hotel_geometry.gd:590-664`; las oficinas usan el mismo patrón, `game/world/office/office_geometry.gd:470, 875`]. De ahí salen:
   - `planta.json`: por cada lote, clave de malla, nombre de material, sala y la transformación de cada instancia, en metros de Godot; y las cajas de colisión de cada sala.
   - `mallas/<clave>.glb`: un archivo por cada malla distinta que no sea el cubo (molduras, piezas de código, modelos). Son cientos, no decenas de miles.
   - `luces.json`, `tomas.json` y `salas.json`, como en `D/poc.md:23-26`.
2. En Unreal, un `AFloorBuilder` mínimo lee `planta.json` y crea un componente de instancias por cada par de malla y material; las cajas son instancias de `SM_Box` con su colisión. Las luces las crea el C++ desde `luces.json` con la tabla de luminarias. La vestimenta de las salas elegidas es otro JSON con el mismo formato.
3. Todo aparece al arrancar el juego sobre un mapa vacío. Las capturas se toman con el juego lanzado, no en el editor.

Por qué este y no los otros:

- **Frente al glTF de la planta entera (`D/poc.md` D1):** aquel deja miles de actores sueltos colocados en un mapa. No dice si las instancias colocadas en ejecución conservan Nanite, tarjetas de Lumen y proxies de trazado, que es justo lo que `D/render.md:168` y `D/mundo.md:177` piden saber y de lo que depende todo el port. Además evita su riesgo principal (Interchange con una planta de 26 358 nodos, `D/poc.md:201`) y lo que dejó sin comprobar (que Interchange cree una malla por nodo, `D/poc.md:237`), y da medidas de CPU honradas.
- **Frente a `D/mundo.md` §5:** no entra `FourCore/Gd` ni nada del generador. El plan no se calcula: se copia de la escena ya montada, con molduras y piezas incluidas.
- **Frente a las cuatro escenas de `D/render.md` §5:** un decorado puede verse mejor de lo que el generador sabrá producir. Aquí se juzga la planta que se va a jugar.
- **Menos desechable:** `AFloorBuilder`, `FourSpace.h`, el guion de importación de mallas y las reglas de luz en C++ se quedan para el port.
- **Salida si el volcado por malla da guerra:** las cajas van siempre por JSON; lo que no es caja puede viajar en un solo glb, que es el camino de `D/poc.md` reducido a su parte fácil. Si una planta entera no cabe, la herramienta acepta un sector (`D/poc.md:102`).

Las oficinas se vuelcan como están en el último commit, con `REAL_PLAN` apagado, y el hash del commit queda en `salas.json`: hoy hay cinco archivos de oficinas modificados sin confirmar [C `git status` del 15 de noviembre], y un volcado de lo que hay en disco no se podría repetir. La prueba juzga luz, materia y densidad, no la distribución (`D/poc.md:104`).

### 5.3 Pasos

«∥» = solo texto, archivos disjuntos, en paralelo. Lo que lanza Godot o Unreal va en serie: un proceso del motor a la vez.

| N.º | Paso | Resultado | Prueba de aceptación |
|---|---|---|---|
| P0 | Proyecto y ajustes (director) | Carpeta y repo nuevos, cuatro módulos, `DefaultEngine.ini` de `D/render.md:20-37` más la caché de pieles (2.1), plugins, `Tools/ue.ps1` con `build`, `py`, `capture`, `editor`, `stop`. Es R1, R2, M0 (= PL1) y la unidad 1 de materiales | `Build.bat` en verde; el editor arranca sin el aviso de MegaLights; primer arranque cronometrado |
| P0b | Humo de la cadena (director, en serie, antes de repartir P3 a P7) | Un guion con `-run=pythonscript` crea un material con un nodo Custom que incluye un `.ush` trivial y una instancia suya; el C++ coloca en ejecución tres instancias de `SM_Box` (un muro de 0,18 × 4 × 3 m), una luz rectangular y la linterna; `ue.ps1 capture humo` | Dos PNG, normal y con `r.Lumen.Visualize=3` [C `UE:Source/Runtime/Renderer/Private/Lumen/LumenVisualize.cpp:29-37`]; anotados la compilación incremental, el primer arranque con render y la primera compilación de sombreadores. Si algo falla, se rediseña antes de repartir |
| P1 ∥ | Herramienta de volcado de Godot | `tools/unreal/export_floor.gd` en este repo | `--check-only` limpio |
| P2 | Volcado (Godot, uno a la vez) | `planta.json`, `mallas/`, `luces.json`, `tomas.json`, `salas.json` de hotel 81 y oficinas 7 en `<P>/SourceAssets/poc/` | Recuento de instancias, mallas y luces anotado; ningún glb declara extensiones obligatorias |
| P3 ∥ | Materiales en texto | `build_materials.py`, `import_textures.py`, `materials.json` reducido, `Tile.ush` | Cada nombre de material de `planta.json` tiene entrada |
| P4 ∥ | Cámara en texto | `Lens.ush`, `Tape.ush`, `UFourPresentationSubsystem` mínimo, gradación de cada piso | Compila, y el material que incluye `Lens.ush` y `Tape.ush` compila sin errores por el camino de P0b (`Build.bat` no compila `.ush`) |
| P5 ∥ | Luces en texto | `FourLightFixtures.h` (filas usadas), `ies_from_profiles.py`, regla de cada luz de `luces.json` a su fila | Cada combinación de clase, energía y ángulo tiene regla |
| P6 ∥ | Montaje, personaje y capturas en texto | `FourSpace.h`, `AFloorBuilder` mínimo, personaje de la plantilla, `UFourCaptureSubsystem` con tomas y recorrido | Compila; prueba de ida y vuelta de `FourSpace` |
| P7 ∥ | Sustituciones y vestimenta | Tabla de pieza a modelo, un JSON de vestimenta por sala, altas en `docs/ASSETS.md`. Fuentes: `source_assets/`, Poly Haven y ambientCG; Sketchfab solo si el autor baja los modelos (5.6) | Cada modelo con licencia CC0 o CC BY registrada; tope de 20 modelos nuevos |
| P8 | Importación y primer montaje (editor y juego) | Mallas con sus ajustes de proxy de trazado (4.2), texturas e instancias de material; la planta en pantalla | Ninguna malla con el material por defecto; el personaje no atraviesa muros; PNG de `ue.ps1 capture` con `r.Lumen.Visualize=3` y `=5` (la planta solo existe con el juego en marcha: el visor del editor y el MCP no la ven); memoria de vídeo anotada antes de vestir |
| P9 | Luz, aire y cámara | Luces, niebla, motas, posprocesado | Ninguna luz cruza una pared en las salas elegidas; una toma de contacto (silla o mesa bajo una luminaria) con sombra de MegaLights trazada y con `r.MegaLights.DefaultShadowMethod=1`; primera hoja de comparación |
| P10 | Vestir las salas elegidas | Once salas vestidas y con calcomanías | Lista de piezas de código visibles: vacía; cada toma anota cuántas piezas se pusieron por regla y cuántas a ojo |
| P11 | Calibrar contra referencia (dos lanzamientos como mucho) | Lúmenes, kelvin, gradación y curva se leen al arrancar de `Tools/capture/calib.json`, sin recompilar; cada lanzamiento saca cada toma en tres variantes y el autor elige. Al cerrar, los valores pasan a `FourLightFixtures.h` | Criterio de tono de 5.4 |
| P12 | Empaquetado Development (director) | Carpeta empaquetada con `/Game/Gen` en `DirectoriesToAlwaysCook` y la carpeta de los JSON en `DirectoriesToAlwaysStageAsNonUFS` [C `UE:Source/Developer/DeveloperToolSettings/Classes/Settings/ProjectPackagingSettings.h:568, 599`]: todo se carga por ruta y el cocinado no lo descubre solo | Arranca; minutos y tamaño anotados (`D/plataforma.md:154`); no lleva ningún módulo `ModelContextProtocol*` ni responde a `-ModelContextProtocolStartServer` (8) |
| P13 | Medición y entrega | Hojas, PNG a tamaño completo, vídeos, tabla y estimación rehecha en `evidence/unreal_poc/` | Tabla completa a 1080p y 1440p, medida en el paquete de P12 (si P12 falla, en el editor, y la tabla lo dice); ritmo medido de la prueba (unidades por ventana, compilación incremental, arranque) y estimación del port rehecha con él |

Orden: P0 y P1 a la vez; P0b y P2; P3 a P7 en paralelo después de P0b; P8 a P13 en serie. El empaquetado va antes de medir y antes del sí, porque la cifra de la máquina tiene que salir del binario del jugador.

### 5.4 Criterios de aceptación

| Vara | Se da por cumplido si |
|---|---|
| Tono anaranjado sutil, no amarillo verdoso | En las tomas de oficina, el tono de la banda de pared queda a 20° o menos de su referencia, y el autor lo confirma a ojo. La hoja da la diferencia con su signo (hacia amarillo y verde, o hacia rojo) y la saturación de la banda: 20° no separan naranja de amarillo |
| Reflejos de suelo | En recepción y aseos el suelo refleja la forma de las luminarias; ninguna mancha blanca redonda |
| Z-fighting | Ningún parpadeo de superficie en los dos vídeos de 60 s |
| Ambiente vacío | En las salas elegidas no queda superficie horizontal desnuda que en la referencia esté ocupada |
| Hecho a mano | En las salas elegidas ninguna pieza visible es de cajas de código |
| Foto de época | En al menos 8 de las 11 parejas el autor dice que la toma de Unreal se sostiene junto a la referencia |
| En movimiento | En el vídeo como se juega (con lente y cinta), con la linterna barriendo y a paso de marcha, el autor no ve ruido, estela ni manchas que no estén en la foto fija de la misma sala. Las fotos se toman asentadas, y Lumen, TSR y MegaLights acumulan entre fotogramas |
| Apagón | Una sala iluminada pasa a negro en menos de 0,5 s y un tubo que parpadea no deja estela (`D/render.md:205-206`). El recorrido de P13 los programa con un temporizador de `UFourCaptureSubsystem`; no es gameplay |
| Máquina | Medida en el paquete de P12. 1080p en Alto: p95 de fotograma de 16,6 ms o menos y memoria de vídeo de 6,5 GB o menos. 1440p se mide y se informa; no bloquea |
| Apuesta técnica (añadido de este plan) | Los muros hechos de instancias de un cubo escalado tienen tarjetas de Lumen y sombra trazada; la planta de oficinas queda por debajo de 100 000 instancias trazadas (`D/render.md:119`) |

Si la última fila falla y lo demás pasa, el port sigue pero cambia el montaje: paneles de 0,5 a 4 m en lugar de cubos escalados, sin tocar el generador (`D/mundo.md:119`).

### 5.5 Medición de rendimiento

- **Mismas cámaras** en los dos motores, desde `tomas.json`. Dos PNG por toma: sin lente ni cinta, y como se juega. Hoja de tres columnas: Godot hoy, Unreal, referencia; y cada PNG también a tamaño completo, para juzgarlo en la vista de juego.
- **Esperar a los sombreadores.** En el juego sin cocinar se compilan en segundo plano [C `UE:Config/BaseEngine.ini:2179`] y el motor retrasa las mallas cuyo PSO no está listo [C `UE:Source/Runtime/Engine/Private/PSOPrecache.cpp:34-41`]. `UFourCaptureSubsystem` no toma ninguna foto ni empieza el recorrido hasta 30 fotogramas seguidos sin trabajos de sombreador ni de PSO pendientes [C `UE:Source/Runtime/Engine/Public/ShaderCompiler.h:1214`; `UE:Source/Runtime/RHI/Public/PipelineStateCache.h:286`], y después espera los fotogramas de asentamiento.
- **Recorrido fijo de 60 s** por las salas elegidas, con la linterna encendida la mitad, el apagón y el parpadeo de 5.4, a 1920×1080 y 2560×1440, nivel Alto, sin límite de fotogramas y sin `-UseFixedTimeStep` (con paso fijo el motor falsea su velocidad [C `UE:Source/Runtime/Engine/Private/UnrealEngine.cpp:3017`]). Se corre dos veces seguidas y cuenta la segunda; los tirones de la primera se informan aparte. Se anota fps medio, p95 y p99 de fotograma y los milisegundos de hilo de juego, de render y de GPU con el perfilador CSV del motor; desglose por pasada con `ProfileGPU` en tres tomas (`D/poc.md:149`).
- **Memoria de vídeo** con `nvidia-smi` cada segundo, restando la lectura con el juego cerrado. Los números de Godot se toman con la misma vara (`D/poc.md:150`).
- **Un vídeo de 60 s por piso**, para juzgar z-fighting, ruido de MegaLights con la linterna en movimiento y la respuesta de Lumen, que una foto no enseña. En esta máquina no hay `ffmpeg` [C `which ffmpeg`, 15 de noviembre] y Movie Render Queue está descartado (`D/metodo.md:130`): cómo se graba lo decide el autor (decisión 37).
- **Pasada informativa sin trazado:** las 11 tomas otra vez con `r.RayTracing.Enable=0` y `r.MegaLights.Allowed=0`, para que la decisión 6 se tome viendo el nivel mínimo. No bloquea.

### 5.6 Qué necesita del autor

1. **Referencias del hotel.** En el repo hay 15 fotos de oficina [C `docs/referencias/`] y ninguna del hotel (`D/poc.md:10`). Sin una por sala, la calibración del piso 1 no tiene fin.
2. **Megascans y Sketchfab:** si trae Megascans con su cuenta de Epic y si baja los modelos de Sketchfab de la lista de P7 (piden su sesión, `D/poc.md:228`). Si no, la prueba se queda con `source_assets/`, Poly Haven y ambientCG. El veredicto no debe depender de ello.
3. **Oficinas:** como están hoy o con el edificio real.
4. **Monitor:** si es de 1440p. Si no, esa medida se hace por resolución interna equivalente.
5. **Permisos:** la carpeta y el repositorio nuevos, la cláusula 6(e) del EULA para usar el MCP y cómo se graban los vídeos (apartado 10, decisiones 1, 2 y 37).
6. Al final, sentarse con las 11 parejas, los dos vídeos y la tabla.

### 5.7 Qué se reutiliza y qué se tira

**Se queda para el port:** el proyecto y sus ajustes, `Tools/ue.ps1`, la cadena de materiales y texturas, la tabla de luminarias con los valores calibrados y los IES, `Lens.ush` y `Tape.ush`, `UFourPresentationSubsystem`, `AFloorBuilder` y `FourSpace.h`, el guion de importación de mallas, `UFourCaptureSubsystem` y el formato de tomas, la lista de sustituciones y todas las medidas.

**Se tira:** la herramienta de volcado y sus archivos, el personaje de la plantilla, las reglas que traducen energías de Godot a luminarias y lo que se haya colocado a ojo en la vestimenta (se anota, porque el port solo podrá repetir lo que sea expresable como regla por sala y tipo, `D/poc.md:209`).

### 5.8 Cuánto tarda

Estimación: de 5 a 8 ventanas de cuota y 3 o 4 días de calendario. `D/poc.md:191` daba de 4 a 6 para el camino glTF; el elegido añade `AFloorBuilder`, `FourSpace.h`, un glb por malla, el humo P0b y el empaquetado antes de medir. Manda el tramo en serie, P8 a P13. Depende sobre todo de tres cosas sin comprobar, que P0b mide el primer día: que los guiones de Python creen materiales e importen mallas sin ventana, cuánto tarda la primera compilación de sombreadores y cuánto la compilación incremental. La calibración ya no recompila (P11).

## 6. El port completo por fases

### 6.1 Cómo se ordena

Tres carriles a la vez, como hoy:

- **Núcleo sin motor** (`FourCore`): generadores, mentes, cifras, matemática de audio. Solo texto y `cl.exe`: va siempre en paralelo y por delante.
- **Juego con motor** (`TheFour`): cada unidad se escribe en paralelo y la compila y prueba su revisor, en serie.
- **Assets:** guiones que necesitan el editor. Un operador a la vez.

Las fases son hitos de integración, no turnos: el texto de una fase posterior puede adelantarse mientras el editor está ocupado. Las unidades se citan por su número en cada diseño (U de `D/mundo.md`, R de `D/render.md`, números sueltos de `D/materiales_assets.md`, J de `D/jugador.md`, C de `D/criaturas.md`, N de `D/red.md`, UI-n de `D/ui.md`, A de `D/audio.md`, PL de `D/plataforma.md`, M de `D/metodo.md`, AP de `D/aplicacion.md`, según 2.3 fila 18).

### 6.2 Fases

| Fase | Qué entra | Depende de | Hito | Prueba de aceptación | Ventanas (estimación) |
|---|---|---|---|---|---|
| 0. Prueba de concepto | Apartado 5 | Nada | Dos plantas vistas en Unreal | El sí del autor a las tres preguntas de 5.1 (5.4) | 5 a 8 |
| 1. Cimientos | Método completo: M1 a M9, M11 y M12 (`golden/test_map.md`, 3). Huellas grabadas en Godot: U0, C0, J1 y AP0 (reglas, director y partituras; las lanza el director, en serie). `FourCore/Gd`: U1, U2, U9. Reloj y argumentos: AP3. Guardado y perfil: PL2 a PL5 | Fase 0 | No es jugable: es la cadena de trabajo | `Tools/verify.ps1` en verde con las tres capas, y una prueba rota a propósito en cada capa sale en rojo con su nombre (`D/metodo.md:172`); `FourCore` reproduce todos los vectores de azar, hash y ordenación de Godot (`D/mundo.md:156`); `FFixedClock` da 250, 1 200 y 8 pasos con fotogramas de 1/144, 1/30 y 0,25 s (`D/aplicacion.md:72`); `golden/test_map.md` sin pruebas sin destino ni motivo | 3 a 5 |
| 2. Hotel andable | Generador, colocaciones y validador del hotel: U3 a U5. Plan y montaje: U8 (hotel), U10 a U15 y U16 (carga en tarea y SHA, de la que depende N3, `D/red.md:168`). Luz y cámara: R3 a R11. Materiales 2 a 14 en su parte de hotel. Jugador: J2 a J10 y J12 a J14. Reloj en el mundo: AP8. Ajustes: PL6 | Fase 1 | Andar por un hotel generado de cualquier semilla, con el movimiento real, puertas, linterna y la cámara definitiva | 255 de 255 huellas iguales a las de Godot; dos procesos con la misma semilla dan el mismo SHA (U16); un cuerpo con esqueleto deja en la pared sombra trazada de la linterna (2.1); las diez fases del reloj corren en su orden y 600 pasos a 30, 60 y 144 fps dan las mismas posiciones bit a bit (`D/aplicacion.md:73-75`); trazas del jugador dentro de tolerancia (1 mm sin colisión, 2 cm con ella, `D/jugador.md:133-134`); ninguna pareja de caras coplanares en 50 semillas; hoja de capturas del hotel junto a sus referencias; planta entera en Alto a 1080p con p95 de 16,6 ms o menos y 6,5 GB o menos | 8 a 12 |
| 3. Hotel jugable en solitario | Aplicación y reglas del piso 1: AP1, AP2, AP4 a AP7, AP9 a AP20 (AP16 y AP17 solo en su parte de The Locust), AP22 y AP24, con la pose de captura del jugador, J18, que esperaba este diseño. Escondites y pasos: J11 (necesita `AFourHide`, AP14, `D/jugador.md:187`) y J15 (necesita el mezclador de A1). The Locust: C1, C2, C6, C8, C10, C15. Audio: A1 a A12. Interfaz: UI-1 a UI-8, UI-10, UI-12, UI-13, con R16. Récords y Continuar: PL7 a PL9, con las versiones de generador copiadas con su valor de Godot y `generator` conservado línea a línea al importar (los tableros solo enseñan las líneas de la versión actual, `game/services/records_service.gd:92, 251-253` [C]). Red para que en solitario las peticiones pasen por el mismo camino: N0, N1 y N2 (la sala, que AP9 necesita, `D/aplicacion.md:224`) | Fase 2 | Completar el piso 1 en solitario, del menú principal al parte de la cinta. La portada 3D llega en la fase 6 y el juicio del autor se repite allí | Con `-FourAutomation -FourSeed=81` llega solo a `PLAYING`; los 20 volcados del director iguales línea a línea; el contrato de la criatura (parte de conducta y parte de aplicación), dificultad, etapas, captura, cordura y Continuar portados y en verde (`D/aplicacion.md:216-239`); nivel por bus a ±2 dB del de Godot en cinco escenas (A12, `D/audio.md:161`); un `records.json` real de Godot, importado, enseña los mismos tableros y puestos; el autor juega y dice si se siente igual | 10 a 15 |
| 4. Cooperativo | Arranque, supervivientes, interactivos, captura, hoja, volver y mirar: N3 a N6, N7 sin el versus, N8, N10, N11, y N14 con sus escenarios coop, late y observer. Remotos y observador: J16, J17, AP23. Réplica de The Locust: C18a (la parte de The Lurker es C18b, fase 5; C18 va tras C9, `D/criaturas.md:190`). Bots del hotel: M14, que monta a los bots en los asientos y cuerpos de la red (`tools/bots/bot_match.gd:80, 123-124` [C]) y es el dueño de `TheFour/Bots`. Interfaz de sala y hoja: UI-9, UI-11. Steam: N12, N13, PL10 | Fase 3 | De 2 a 5 jugadores completan el hotel por IP y por Steam | Escenarios coop, late y observer en verde dos veces seguidas (`D/red.md:179`); tres bots completan un piso sin interfaz; prueba manual con dos equipos y dos cuentas (N12) | 5 a 8 |
| 5. Oficinas | Generador y validador: U6, U7, con la huella de oficinas grabada otra vez en Godot sobre el generador congelado (U0 se graba antes de congelarlo). Plan, kit y vestimenta de oficinas: U8, U15, materiales 12 y 13. Luces: R12. The Lurker: C3 a C5, C7, C9, C11 a C14, C18b y el velo de polvo de R15. Lo de The Lurker en AP16 y AP17 (`lurker_forced_test`, marcas de 3,15 y 5,4 s). Objetivos del piso 2: AP21, y su red: N9 (tras N6, `D/red.md:174`), con el escenario office_coop de N14 | Fases 2, 3 y 4; el generador de Godot congelado | Completar el piso 2 en cooperativo con The Lurker | Huellas de oficinas iguales; las 200 aproximaciones de la prueba de justicia dan el mismo veredicto una a una (`D/criaturas.md:175`); `descend_test` y `jump_test` portados; hojas de las 15 salas con los tres criterios numéricos; un módulo con 16 luminarias a 60 FPS en Alto (`D/render.md:189`); escenario office_coop en verde | 10 a 14 |
| 6. Versus, niveles y entrega | Versus: C16, C17, la parte versus de N7, la vista de eco de R15 y el escenario versus de N14. Bots y telemetría de The Lurker: C19, sobre el módulo de M14. Pasadas de aspecto: C20, A13. Niveles de calidad y nivel sin trazado: R13, R14, R17. Banco: R18, M15. Portada, intro 3D y mando: UI-14, UI-15. Empaquetado (PL11, que es M16), fallos, créditos, lanzadores: PL11 a PL13, PL15. Subida a Steam: PL14, si hay AppID | Fases 4 y 5 | Paquete Shipping 2.0.0 en una rama `unreal` de Steam | Escenario versus en verde; cada nivel de calidad cumple su fila (`D/render.md:105-110`); el paquete arranca y no lleva módulos de editor ni de MCP; el autor lo recorre entero desde la portada | 6 a 10 |

**Toda unidad de un diseño está en una fase o se descarta aquí.** R1, R2, M0 (= PL1) y la unidad 1 de materiales son P0. R19 y UI-16 (DLSS y FSR, segundo idioma) solo si el autor los pide (decisiones 23 y 27). M13 es N14. M10 (`UFourToolset`) se descarta: las capturas van por `ue.ps1 capture` y no por el MCP; vuelve solo si el operador del editor lo necesita. La aceptación de cada fase incluye además las pruebas de Godot que `golden/test_map.md` le asigna, portadas y en verde.

**Qué va en paralelo.** La fase 5 espera a la 4: N9 y el escenario office_coop necesitan la red de la fase 4. Lo que sí se adelanta de la fase 5 es su texto de `FourCore` (mente, sentidos y conductos de The Lurker), y U6 cuando el autor congele el generador. Desde la fase 1 pueden adelantarse como texto C1 a C3, C6 y C7 (mentes y sentidos), A2 a A2e (matemática de audio), J2 a J4, N1 (tipos y cabeceras de las 55 RPC), UI-2 (tablas de texto) y AP1, AP2, AP4 a AP7 (reglas, sesión, director, partituras, cordura y objetivos sin motor; AP4 no empieza sin U1 y AP0, `D/aplicacion.md:248`). El generador de oficinas (U6) no se adelanta: sigue cambiando en Godot (`D/mundo.md:182`).

**Cambios grandes primero.** En cada fase entra antes la función y después el pulido. La excepción es la base visual (luz, materiales, cámara), que llega hecha desde la fase 0 porque es el motivo del port.

### 6.3 Duración: una estimación y de qué depende

Es una estimación, no un compromiso. Método: los otros diseños suman unas 170 unidades de trabajo y `D/aplicacion.md` trae 25 (AP0 a AP24), en el borde bajo de las 25 a 35 que la primera versión calculaba por tamaño; la tabla no cambia, porque la fase 3 ya contaba con ellas. Si se cierran 3 o 4 unidades por ventana de cuota de 5 horas, con su revisión y hasta dos rondas de corrección, salen de **47 a 72 ventanas**, que es la suma de la tabla. En calendario, **entre mes y medio y tres meses**, según cuántas ventanas llenas permita el límite semanal. Contraste: el juego entero se hizo en Godot entre el 16 de septiembre y el 15 de noviembre de 2026, en 604 commits [C `git log`]. El port tiene un ciclo más lento (78 s de `Build.bat` en la plantilla vacía frente a un segundo de `--check-only`) y una paridad bit a bit que entonces no existía, así que el borde bajo es optimista. P13 rehace esta cifra con el ritmo medido en la prueba, y la tercera pregunta de 5.1 la lleva.

Depende de:

- **El ritmo real de unidades por ventana**, que hoy es una suposición. Se mide en las fases 0 y 1 y la estimación se rehace entonces.
- **La paridad del generador.** Si un bit de diferencia en `sin` o `cos` cambia una planta, la fase 2 se alarga o se baja a paridad estructural (`D/mundo.md:175`).
- **El tramo en serie.** Compilar, probar y capturar ocupan el único proceso del motor. Si el arranque del editor o la compilación incremental salen lentos, mandan ellos.
- **El autor:** modelos que solo él puede bajar (Megascans, Sketchfab), las licencias pendientes, el AppID y la prueba con dos equipos.
- **Que Godot se congele o no** mientras dura el port (apartado 10).

## 7. Método de trabajo

Detalle en `D/metodo.md`. Se conservan los tres niveles del `CLAUDE.md` actual (director, revisores, batería), el regulador de la ventana, los encargos cerrados, la revisión por área y los flujos `encargos`, `frente` y `arreglo`. Cambia la parte de la máquina.

### 7.1 Ciclo del agente

- **Un único lanzador, `Tools/ue.ps1`**, con cerrojo: se niega si ya hay un proceso del motor que no lanzó él. Nadie llama a `UnrealEditor*.exe`, `Build.bat` ni `RunUAT.bat` a mano (`D/metodo.md:60, 126`).
- **Unidad en paralelo (batería):** edita C++ o datos y solo puede ejecutar `ue.ps1 core`, que compila `FourCore` con `cl.exe` y corre sus pruebas en segundos.
- **Revisor del área, en serie:** `ue.ps1 build` (`Build.bat TheFourEditor Win64 Development`, editor cerrado), `ue.ps1 auto <filtro>` (Automation sin render, `-unattended -nullrhi`, paso fijo de 60) y, si el área se ve, `ue.ps1 capture <set>`.
- **Operador del editor:** `ue.ps1 editor`, llamadas al MCP, `ue.ps1 stop`. Uno a la vez.
- Live Coding no entra en el ciclo normal: viene apagado, no arranca en sesiones desatendidas y con compilaciones de un minuto no compensa (`D/metodo.md:64`).

### 7.2 MCP y plugin de Epic

- **Qué da:** 52 toolsets y 830 herramientas [E], entre ellas materiales e instancias, mallas estáticas con importación y Nanite, Niagara, UMG, propiedades de cualquier objeto, pruebas de Automation y capturas del visor (secciones en `mcp_catalogo.md:15-1034` [C]).
- **Qué no hace:** Python libre, órdenes de consola, compilación completa, cocinar, empaquetar, git, crear un nivel, audio (`D/metodo.md:146`). Los fallos suelen volver como éxito con el error dentro del texto, y reintentar a ciegas duplica cambios (`D/metodo.md:148`).
- **Para qué se usa:** para lo que no es texto, y nada más: explorar cómo se crea un asset y comprobar el resultado. Todo asset que deba existir acaba en un guion de `Tools/assets/`.
- **Cómo:** por `Tools/mcp.ps1`, un cliente HTTP fino que funciona igual en la sesión principal y en agentes de un flujo, espera a que el número de toolsets se estabilice y guarda en disco las capturas que llegan en base64 (`D/metodo.md:134`).
- **Seguridad:** el servidor escucha en `127.0.0.1` sin autenticación y puede borrar assets, cambiar ajustes y activar plugins. Se arranca solo por línea de órdenes y solo mientras dura la sesión de editor; con `git status` limpio antes; lista de bloqueo para los toolsets que no hacen falta (`D/metodo.md:138, 148-150`).
- **El plugin de Claude Code de Epic** (3.1.2, instalado) aporta tres skills y un aviso al iniciar la sesión; no instala servidor y documenta cosas que 5.8.4 no trae (`D/metodo.md:146`).

### 7.3 Pruebas y verificación

| Capa | Dónde | Qué prueba | Orden |
|---|---|---|---|
| 1. Núcleo | `Source/FourCore/Tests/` | Azar, generadores, huella dorada, mentes, cifras, matemática de audio | `ue.ps1 core`, segundos |
| 2. Automation sin render | `Source/TheFour/Private/Tests/`, nombres `TheFour.<Área>.<Caso>` | Lo que necesita mundo: movimiento, sentidos, colisión, navegación, guardado, interfaz | `ue.ps1 auto` |
| 3. Con render | Prefijo `TheFour.Render.` y los juegos de capturas | Sombreadores, luces que no cruzan paredes, capturas comparadas | `ue.ps1 render`, `ue.ps1 capture` |

- **`Tools/verify.ps1`** corre en serie `core`, `build` y `auto`; con `-Render` añade la capa 3, y con `-Net` los escenarios de red con varios procesos `-game -nullrhi -nosteam`. Objetivo sin medir: menos de 3 minutos sin render, frente a los 5 a 8 de hoy (`D/metodo.md:89`).
- **Paridad con Godot.** Tres huellas grabadas una vez desde Godot y guardadas en `golden/`: manifiestos y estados del azar por etapa (`D/mundo.md:155`), trazas del jugador (`D/jugador.md:177`) y veredictos y rutas de las criaturas (`D/criaturas.md:172`). Son las únicas unidades del port que ejecutan Godot y las lanza el director, en serie.
- **Capturas** con el juego sin ventana y las tomas en JSON; `Tools/compare.py` aplica los tres criterios de hoy (estructura 0,6, luma 25 %, tono 20°) y monta la lámina junto a la referencia (`D/metodo.md:75`). El encuadre de salas usa 55° horizontales (2.3, fila 8).

### 7.4 Reglas de la máquina

- Un solo proceso del motor a la vez: editor, commandlet, juego o compilación.
- `Tools/verify.ps1`: nunca dos a la vez, con el editor cerrado, una por área.
- Godot y Unreal tampoco a la vez mientras se mide: comparten GPU.
- Las pruebas de red, con puertos fijos, en serie.
- El motor no se actualiza desde el lanzador sin decisión del director.

### 7.5 Borrador de reglas para el `CLAUDE.md` del proyecto de Unreal

Se copian del actual los tres niveles y sus modelos, el regulador de la ventana, encargos, revisión por área, git (solo el director hace commit, rutas explícitas, mensaje en inglés, push cada 3 o 4), heredocs, textos sin «·» ni «—», lore, sonido y licencias. Y se añade (`D/metodo.md:186-200`, con los cambios de 2.3):

- **La máquina es lo escaso: Unreal.** Un solo proceso del motor a la vez. Todo se lanza con `Tools/ue.ps1`.
- **Unidades en paralelo:** archivos disjuntos y solo `ue.ps1 core`. `build`, `auto`, `render`, `capture` y `py` los corre el revisor del área, en serie.
- **Editor y MCP:** solo el operador que nombre el encargo. Antes, `git status` limpio. Cada llamada se comprueba leyendo el texto del resultado y releyendo el estado. No se reintenta a ciegas. Al acabar, `ue.ps1 stop`.
- **Nada a mano en el editor.** Todo asset sale de un guion de `Tools/assets/` o del código. No se versiona nada de `Content/Gen/`. `Content/Hand/` pide permiso del director.
- **C++:** estilo de Epic (prefijos `U`, `A`, `F`, `E`, `b`), comentarios breves en inglés que dicen el porqué. Antes de usar una clase o una firma del motor que no esté ya en el proyecto, buscarla en `UE:Source` o `UE:Plugins` con la búsqueda acotada a un módulo; no se inventan funciones. Clase nueva: revisar `UCLASS`, `GENERATED_BODY`, el `*_API` y el `.Build.cs`.
- **Lógica sin mundo va a `FourCore`**, sin cabeceras de Unreal, con su prueba. En `FourCore/Gen` no se usan `TMap`, `std::unordered_map`, `std::sort` ni `FRandomStream`.
- **Unidades y ejes:** solo `FourSpace.h` multiplica por 100 o intercambia ejes.
- **Reloj:** la lógica de juego corre en el paso fijo de `UFourSimClock`, en su fase; un `Tick` de actor solo dibuja. Las excepciones son las de hoy: reloj del piso, captura y cinta de muerte van por fotograma.
- **Blueprints:** ninguno con lógica. Sin StateTree, Behavior Tree, Control Rig, Animation Blueprint, Sequencer ni MetaSounds.
- **Capturas:** siempre por `ue.ps1 capture <set>`; se juzgan en la vista de juego junto a su referencia.
- **Perfil:** ninguna herramienta escribe en `%LOCALAPPDATA%/TheFour` ni en la carpeta de datos de Godot. Nunca matar un proceso del juego del autor.
- **El repo de Godot** (`E:/Projects/The Four`) es referencia de solo lectura: el gameplay se copia de ahí con ruta y línea. Solo el director ejecuta Godot, para grabar huellas.
- **Versión del motor:** 5.8.4. No se actualiza.
- **Si el encargo no encaja con el motor**, se informa; no se rediseña.

## 8. Herramientas

**Ya instalado:**

| Qué | Estado |
|---|---|
| Unreal Engine 5.8.4 con código fuente | `C:/Program Files (x86)/UnrealEngine/UE_5.8` [E] |
| Build Tools 2026 con MSVC 14.50 y SDK de .NET Framework 4.8 | `TP_Blank` compila en 78 s [E] |
| Plugins del motor para agentes: `ModelContextProtocol`, `AllToolsets`, `LiveCodingToolset` | En el motor, apagados; se activan en el `.uproject` (`D/metodo.md:41`). No son todos de solo editor: `ModelContextProtocol` y `ModelContextProtocolEngine` son módulos de tipo `Runtime`, el arranque por línea de órdenes vive en el segundo y el plugin es `NoRedist` [C `UE:Plugins/Experimental/ModelContextProtocol/ModelContextProtocol.uplugin`]. Su entrada en el `.uproject` lleva `"TargetAllowList": ["Editor"]` [C `UE:Source/Runtime/Projects/Private/PluginReferenceDescriptor.cpp:73, 161`], y lo mismo `PythonScriptPlugin` (su módulo de precarga también es `Runtime`). Sin eso, el juego empaquetado llevaría un servidor HTTP sin autenticación que se enciende con un argumento, o no compilaría |
| Plugin de Claude Code de Epic, 3.1.2 | Instalado [E]; se activa en `<P>/.claude/settings.json` |
| Plugins del motor que usa el juego: Interchange, Python, Geometry Script, Enhanced Input, Synthesis, `OnlineSubsystemSteam`, `SteamSockets` | En el motor; nada que bajar |
| Blender 5.2, Git LFS, Node 24, Python 3.14 | Instalados [E] |
| Godot 4.7.2 | Para grabar huellas y volcar plantas |

**Falta, y es poco:**

| Qué | Para qué | Fuente y licencia |
|---|---|---|
| `git lfs install` y los patrones en el repo nuevo | Originales y `.uasset` a mano | `D/metodo.md:204-206` |
| Copia de una decena de archivos fuente de Godot 4.7.2 (azar, hash, ordenación, `move_and_slide`, `get_vector`) | Referencia del port literal | https://github.com/godotengine/godot, MIT |
| Fuentes: VT323 o Share Tech Mono (OSD), Courier Prime, Reenie Beanie | El OSD apunta a una fuente que nunca estuvo en el repo (`D/ui.md:11`) | `github.com/google/fonts`, OFL, sin cuenta (`D/ui.md:197-205`) |
| Pillow o NumPy | `Tools/compare.py`, solo si hacen falta | PyPI |

**Opcional, solo si el autor lo pide o lo trae:**

- Megascans (Fab): gratis con licencia comercial desde el 5 de noviembre de 2026 según `briefs/experiencias.md`; pide la cuenta de Epic del autor.
- Modelos de Sketchfab, solo CC0 y CC BY: pide su sesión.
- `steamcmd` y la cuenta de socio de Steamworks, para subir compilaciones.
- Plugins de DLSS (NVIDIA) y FSR (AMD).
- Respuestas de impulso con licencia CC0 para la reverb de convolución (`D/audio.md:191`).

**No se instala:** UnrealSharp, AngelScript, MCP de terceros, Steam Audio, Wwise, FMOD ni servicios de informes de fallos con cuenta.

## 9. Riesgos, por gravedad

| N.º | Riesgo | Por qué es grave | Cómo se detecta pronto |
|---|---|---|---|
| 1 | 8 GB de memoria de vídeo o el fotograma no dan para Lumen por hardware, MegaLights y Nanite en Alto a 1080p | Tumba la premisa del port en la máquina del autor | Prueba de concepto, P8: `nvidia-smi` en la primera carga, antes de vestir. Salida: texturas a 1K, nivel Medio |
| 2 | El aspecto no llega al listón ni en Unreal, porque el límite son los assets y la vestimenta y no el motor | El port no cumpliría su único objetivo | El veredicto de 8 de 11 parejas. Por eso el resto de la planta se deja sin vestir: enseña lo que da un port mecánico |
| 3 | Las instancias colocadas en ejecución pierden tarjetas de Lumen o proxies de trazado, o el cubo escalado se ve mal | Todo el montaje del mundo se apoya en eso (2.1) | P0b con tres instancias y P8 con la planta: `r.Lumen.Visualize` 3 y 5 en `ue.ps1 capture`. Las instancias de una ISM reciben tarjetas una a una [C `UE:Source/Runtime/Renderer/Private/Lumen/LumenScene.cpp:1345-1380`; `LumenMeshCards.cpp:37`], así que lo que se mira es su calidad en un cubo muy alargado. Salida prevista: paneles (5.4) |
| 4 | El reloj propio o el director portado no reproducen a Godot: el orden de fases no da un caso que depende de él, el director difiere por coma flotante (`Vector3` de 32 bits frente a `float` de 64), el tope de 8 pasos cambia la conducta tras un tirón, o `OnWorldPreActorTick` llega a todos los mundos | Unas 14 600 líneas y el reloj del que dependen jugador, criaturas y audio | Pruebas del reloj en AP3 y AP8; AP4 porta primero `tick` y `build` y compara una semilla antes del resto; medir en Godot los pasos tras una pausa de 0,5 s antes de fijar el tope (`D/aplicacion.md:247-254`) |
| 5 | La paridad bit a bit del generador no se consigue | Sin ella no hay prueba barata de que el port es fiel | Vectores en U1 y estados del azar por etapa en U3. Salida: paridad estructural (`D/mundo.md:175`) |
| 6 | Licencias: The Locust es CC BY-NC-ND, la Exploradora (personaje por defecto) es CC BY-SA y el EULA de Unreal prohíbe combinarla, y televisor, dormitorio, puerta y armario no tienen licencia comprobada (`indice.md:79, 144`) | Impiden vender | Decisiones del apartado 10 antes de la fase 3; escaneo de licencias en cada integración (PL13) |
| 7 | El generador de oficinas sigue cambiando en Godot | Portarlo antes de congelarlo es portarlo dos veces | Decisión del autor; U6 no empieza sin ella |
| 8 | El movimiento se siente distinto | Rompe el criterio 2 | Trazas de nivel 1 en J5 y de nivel 2 en J6, antes de cualquier otra pieza del cuerpo |
| 9 | Los guiones de Python sin ventana no compilan materiales, no importan con Interchange o no guardan | Sin ellos los assets no son reproducibles | P0b, antes de repartir nada. Salida: editor abierto con `-ExecutePythonScript=` o MCP |
| 10 | Errores típicos del C++ de agentes (funciones inventadas, macros, módulos) y el MCP que devuelve «Ok» con el error dentro | Rojo constante y cambios duplicados | Regla de buscar en el motor; `build` en la revisión de cada unidad; releer tras cada llamada |
| 11 | `-game -RenderOffScreen` no deja el PNG, o las capturas no se repiten por la historia de TSR, Lumen y exposición | Sin capturas fiables no se juzga nada | P0b y P8; las capturas esperan a sombreadores y PSO (5.5). Salida: más fotogramas de calentamiento o exposición fija por toma (`D/metodo.md:212-213`) |
| 12 | Ruido de MegaLights con la linterna en movimiento y tubos que parpadean; Lumen tarda en apagar una sala | Molesta justo en el momento de terror | Vídeos de P13, con apagón y parpadeo programados y su fila en 5.4. Salida: 4 muestras por píxel, parpadeo por emisivo (`D/render.md:205`) |
| 13 | Las rutas de Recast no son las de Godot | Cambia qué oye la criatura, que usa la longitud de ruta | 20 casos de oído en C8, antes de portar los cuerpos |
| 14 | Una voz no puede cambiar de bus mientras suena | El audio de hoy lo hace en cada voz | A1, lo primero del audio (`D/audio.md:170`) |
| 15 | Red: orden entre RPC fiables de actores distintos, topes de tamaño, cuatro procesos del editor a la vez | Reincorporaciones corruptas o pruebas que no caben | N0 mide dos procesos; escenario late de N11 |
| 16 | Los requisitos mínimos suben: DX12 con SM6, y trazado de rayos para el aspecto buscado | Deja fuera a jugadores de hoy | Decisión del autor; nivel sin trazado (R14) y rama `godot` en Steam |
| 17 | El empaquetado falla con motor instalado | Se descubriría al final | P12: un empaquetado Development antes de medir y antes del sí, sin módulos del MCP |
| 18 | Calcomanías con Substrate en formato 0 | Son el remedio del z-fighting y los diseños no coinciden (2.3, fila 10) | Cuatro calcomanías en P10 |
| 19 | La estimación se queda corta | Agota cuota a medio hito | Medir unidades por ventana en las fases 0 y 1 y rehacer 6.3 |
| 20 | El motor instalado no se puede modificar, y Subliminal usa el suyo modificado | Parte de aquel aspecto puede depender de cambios de motor | Sin detección directa: lo dirá la prueba de concepto |

## 10. Decisiones que le tocan al autor

**Antes de la prueba de concepto:**

| N.º | Decisión | Recomendación |
|---|---|---|
| 1 | Carpeta `E:/Projects/TheFourUE` y repositorio privado nuevo en GitHub | Sí. Lo crea el director con `gh` si lo autorizas |
| 2 | Cláusula 6(e) del EULA de Unreal: lo que el MCP envía al modelo es «Licensed Technology» y Epic te hace responsable (`D/metodo.md:148`) | Es tuya y es legal, no técnica. Si no la aceptas, el plan funciona sin MCP, solo con guiones de Python: ya no depende de Niagara, que solo el MCP sabe construir (apartado 1) |
| 3 | Referencias del hotel para recepción, pasillo, dormitorio y baño | Hacen falta antes de calibrar. Tono y luz se calibran solo contra fotos o grabaciones de época; las capturas de los juegos del listón sirven para fijar el nivel de calidad, no el tono |
| 4 | Megascans con tu cuenta de Epic | Tráelo si puedes: sube el techo. La prueba se juzga también sin él |
| 5 | Oficinas de la prueba: como están hoy o con el edificio real | Como están en el último commit (5.2) |
| 37 | Cómo se graban los dos vídeos de 60 s: en la máquina no hay `ffmpeg` | Bajar una compilación de `ffmpeg` sin cuenta y grabar con ella la ventana del juego en tiempo real: así un agente repite el vídeo. Es una herramienta y no va en el juego, así que su licencia no toca la venta. Si no, los grabas tú con tu herramienta de captura de pantalla |

**Antes del port completo:**

| N.º | Decisión | Recomendación |
|---|---|---|
| 6 | Requisitos mínimos: DX12 con SM6, y RTX 2060 o equivalente para el aspecto buscado | Aceptarlo. Mantener el nivel sin trazado como mínimo real y dejar Godot 1.3.x en una rama `godot` de Steam para el hardware flojo |
| 7 | Godot durante el port | Congelar el hotel ya (solo arreglos). El piso 2 no se desarrolla en los dos motores a la vez |
| 8 | Qué edificio de oficinas se porta | Decidirlo antes de la fase 5 y congelarlo entonces |
| 9 | Paridad exacta de semillas con Godot | Sí, como prueba del port. Cuando esté demostrada, la huella de C++ pasa a ser la verdad |
| 10 | Modelo de The Locust (no se puede vender ni modificar) | Uno propio por guion, con la misma cadena de Blender que The Lurker y los mismos 18 huesos, y lo juzgas tú junto a la referencia |
| 11 | La Exploradora no puede ir en un juego de Unreal a la venta | Quedarse con los dos detectives y cambiar el personaje por defecto. Un tercero solo si aparece uno CC0 o CC BY |
| 12 | Televisor, dormitorio, puerta y armario sin licencia comprobada | Sustituirlos ya, dentro de la lista de modelos reales |
| 13 | Los 82 modelos de Sketchfab que piden sesión (`D/materiales_assets.md:175`) | Bajarlos tú cuando la lista esté cerrada. Lo que no se pueda, sustituto sin cuenta |
| 14 | Moqueta del hotel y motivo del papel pintado | Conservar el dibujo, sobre el escaneo: son identidad del lugar |
| 15 | Continuar no se migra; récords, logros y descubrimientos sí | De acuerdo, con nota en el registro de cambios |
| 16 | AppID de Steam (hoy se usa el 480 de pruebas) | Pedirlo antes de la fase 4. No bloquea nada anterior |
| 17 | El versus (cazador y vista de eco) va al final | Sí |
| 18 | Objetivo de resolución | 1080p en Alto y 1440p en Medio en la RTX 4060 Ti |
| 19 | Fuente del OSD | VT323, que es libre (OFL), salvo que aportes una con licencia de venta |

**Pueden esperar:**

| N.º | Decisión | Recomendación |
|---|---|---|
| 20 | Más fuentes de sonido de ambiente por sala | Sí, tras un interruptor y después del traslado: ataca lo vacío |
| 21 | Música por capas o compases | No: se queda el tema único con su tensión |
| 22 | Sonido con carácter de cinta fuera de la cinta de muerte | No por ahora |
| 23 | Segundo idioma | No ahora; las tablas quedan preparadas |
| 24 | Accesibilidad nueva (filtro de daltonismo, escala de interfaz) | Después de la entrega |
| 25 | Camcorder y linterna visibles en las manos de los compañeros | Después: pide poses nuevas |
| 26 | Aspecto de The Lurker más allá de materiales y luz | Primero solo materiales y luz; el modelo, si la captura lo pide |
| 27 | DLSS | No por ahora: basta TSR |
| 28 | macOS | Se abandona con el port |
| 29 | Informes de fallos | Locales; el jugador envía la carpeta a mano |
| 30 | Juego por IP y observadores | Se conservan: las pruebas de red los usan |
| 31 | Vigilancia por texto del contrato de la criatura | Basta con las pruebas de conducta y un escaneo barato de que `FourCore` no incluye cabeceras del motor |
| 32 | Cuota de Git LFS si `SourceAssets/` la supera | Decidir cuando se mida en P0 |
| 33 | Trámites de Epic: formulario de lanzamiento, informe trimestral, avisos en créditos (`D/plataforma.md:132-140`) | Anotarlos en `docs/PLAN.md` como tareas del autor |
| 34 | Prueba de Steam con dos equipos y dos cuentas | La haces tú con alguien, al cerrar la fase 4 |
| 35 | Seis cifras en que `docs/DIFFICULTY.md` y `GAME_DESIGN.md` no dicen lo que hace `difficulty.gd` (oído, encuentro garantizado, respiros, pistas, cercanía, protección de 10 o 12 s; `D/aplicacion.md:258`) | El port copia el código, que es lo que hoy se juega. Si una cifra del documento es la buena, se corrige primero en Godot |
| 36 | Teclas de depuración (F9 mata al jugador, saltos de sector) | Fuera del juego publicado, como los bots (`D/aplicacion.md:259`) |

## 11. Sin comprobar

Nada de este plan se ha ejecutado. Lo que sigue es lo que más pesa; cada diseño tiene su propio apartado «Sin comprobar» con el resto.

**Del motor y de la máquina:**

- Todo rendimiento y memoria en Unreal. Las cifras de 4.4 son objetivos (`D/render.md:234`).
- Que las instancias de malla estática colocadas en ejecución conserven Nanite, campo de distancia, tarjetas de Lumen y proxies de trazado, y cómo trata Lumen un cubo de escala muy desigual (`D/mundo.md:212-213`).
- Que `-run=pythonscript` cree materiales, importe con Interchange y guarde sin ventana (`D/metodo.md:249`).
- Que `-game -RenderOffScreen` renderice y escriba el PNG pedido, y que el perfilador CSV funcione así con motor instalado (`D/metodo.md:247`, `D/poc.md:243`).
- Que el mapa `/Engine/Maps/Entry` sirva de mapa de juego sin efectos secundarios. Solo comprobé que existe.
- Que el editor lanzado con `-RenderOffScreen` sirva el MCP igual que con `-nullrhi`, que es como se comprobó [E].
- Tiempos: compilación incremental, primera compilación de sombreadores, arranque de las tres capas de pruebas y el objetivo de 3 minutos de `verify`.
- Que el empaquetado funcione con motor instalado y deje fuera los plugins de editor (`D/plataforma.md:216-217`), y que `TargetAllowList` baste para que el objetivo de juego compile sin los módulos del MCP: leí dónde se aplica la clave, no lo compilé.
- Que las motas y el polvo de techo hechos con instancias desde C++ se vean como se veían con Niagara. Si la prueba lo pide, Niagara vuelve solo como llamadas al MCP grabadas en texto y repetidas por `mcp.ps1`.
- Que con la estrategia de PSO de fábrica una foto a los 3 s salga de verdad sin mallas: se deduce del código, no se midió. Y que `r.Lumen.Visualize` funcione en `-game` con `-RenderOffScreen`.
- Que una compilación de `ffmpeg` sin cuenta grabe en tiempo real la ventana del juego en Windows 11 (decisión 37); no busqué cuál ni su origen.
- Que `nvidia-smi` esté en esta máquina y que su lectura valga en Windows.
- Calcomanías DBuffer con Substrate en formato 0.
- El orden de las RPC fiables entre actores y los topes de tamaño en parámetros: conocimiento del motor, no releído en 5.8 (`D/red.md:217-218`).
- Que un submix creado en código acepte envíos por voz como uno de asset (`D/audio.md:197`).
- Que un `UUserWidget` nativo sin Blueprint se construya como se espera, y que las fuentes desde archivo funcionen dentro de un paquete (`D/ui.md:209-211`).

**De Godot y de la paridad:**

- Ningún valor del azar, del hash ni de la ordenación portados se ha contrastado con Godot. Las fuentes se leyeron en la etiqueta 4.7 y el juego usa 4.7.2 (`D/mundo.md:207-210`).
- Si `sin`, `cos` y `atan2` del Godot de Steam coinciden bit a bit con los de MSVC.
- El algoritmo interno de `move_and_slide` y de `Input.get_vector` no se leyó (`D/jugador.md:232`).
- La fórmula de guiñada y la conjugación de ejes de `FourSpace` son deducción (`D/mundo.md:211`).
- Si el ascensor mueve al jugador como plataforma (`D/jugador.md:233`). `D/aplicacion.md:14` dice que no, que lo coloca por posición; no lo releí.
- Del dominio de aplicación (`D/aplicacion.md:265-278`): qué sigue vivo en `PAUSED` y en `LOADING`; en qué fase entran los cuerpos remotos (`Remotes` al final es una suposición); el tope de pasos por fotograma de Godot; quién manda en la cordura en línea; que `OnWorldPreActorTick` se emita con `-nullrhi` y con el mundo en pausa; los nombres de las RPC de los interactivos, que son propuestos.

**De este plan:**

- La herramienta de volcado de 5.2: solo comprobé cómo nombra y agrupa Godot los lotes al montar. No está comprobado que `GLTFDocument` exporte en ejecución una malla suelta de código o un modelo con sus texturas, ni cómo distinguir por nodo cada tipo de luz.
- Que haya una semilla de oficinas con todas las salas de 5.1 en una misma planta (`D/poc.md:247`).
- Las ventanas por fase y el ritmo de 3 o 4 unidades por ventana son suposición mía, sin medida detrás. El recuento de unas 170 unidades es la suma de las tablas de los diseños, más las 25 de `D/aplicacion.md`.
- De `D/aplicacion.md` solo comprobé el punto de emisión de `OnWorldPreActorTick` en el motor y el orden director antes que criatura en `hotel_main.gd`; el resto se toma del diseño.
- No abrí ninguna imagen de referencia ni las capturas del autor del 12 de noviembre (`evidence/autor_12nov/`, existen).
- No releí en el código las cifras que este plan toma de los diseños. Las fichas las levantó Haiku y hay que comprobarlas al usarlas (`indice.md:3`).
- Licencias: la gratuidad de Megascans, las condiciones de Fab y Sketchfab y las obligaciones del EULA vienen de los informes; no se releyeron hoy en la web.
- Cuál es el Fractured Mind que el autor tiene en mente (`indice.md:82`).
