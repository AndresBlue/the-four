> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: método de trabajo con agentes, compilación y pruebas (Unreal Engine 5.8.4)

Escrito el 15 de noviembre de 2026. Nada se ejecutó ni se compiló para este documento. Abreviaturas: `UE:` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine/`; `AG` = informe `.claude/specs/unreal/briefs/agentes.md` (leído sobre el motor instalado); `CAT` = `.claude/specs/unreal/mcp_catalogo.md`; `<P>` = raíz del proyecto de Unreal (la fija D1). Marcas: [M] leído hoy en el motor o en el repo; [AG §n] tomado del informe, que cita ruta y línea; [E] dato del encargo, comprobado en esta máquina el 15 de noviembre; [D] deducción.

## 1. Qué hay hoy en Godot

- **Una orden de verificación.** `tools/verify.ps1` (194 líneas [M]): tres lotes. Todo a 60 FPS fijos (`--fixed-fps 60`, `:40`), los escenarios de red con un puerto fijo cada uno (`:121`: 24600 a 24650) y el audio en reloj real. Criterio: código 0 y ningún `ERROR:` en el log (`:143-145`). Resultado en `evidence/verification.json` (`:25`). Según la ficha `pruebas.md`: 63 comprobaciones, 8 a la vez, 2 724 s sumados en la última ejecución.
- **Pruebas.** 54 `.gd` en `tests/{hotel,net,office}` y 81 archivos `*_test.gd` en todo el repo [M, `find`]. Contratos que hay que conservar (ficha `pruebas.md`): manifiesto dorado, contrato de la criatura (120 comprobaciones), justicia de La Acechadora (200 aproximaciones con semilla) y dificultad.
- **Capturas.** 110 archivos en `tools/capture/` [M]. Encuadre común en `tools/capture/room_framing.gd:11-14`: ojo a 1,5 m, 0,2 m fuera del umbral, mira a 1,5 m, FOV 55 [M]. Comparación con foto en `tools/capture/office_rooms_capture.gd:49-54`: estructura mínima 0,6, luma 25 %, tono 20 grados, sobre una muestra de 64 x 43 (`:45`) [M]. Referencias: 15 fotos en `docs/referencias/` [M].
- **Envoltorios.** `tools/godot.ps1` (170 líneas), `tools/net_test.ps1` (39), `tools/bots.ps1` (214) [M].
- **Método.** `CLAUDE.md` (tres niveles, una sola `verify` a la vez, sin árboles de trabajo, el director hace commit) y los flujos `.claude/workflows/{encargos,frente,arreglo,frente_resumen}.js` [M].
- **Repositorio.** Sin Git LFS: `.gitattributes` solo marca `*.png`, `*.jpg` y `*.glb` como binarios [M]. `.git` pesa 4,3 GB (798 MiB empaquetados) [M]. `source_assets/` y `models/` están fuera de git (`.gitignore`) [M]. Git LFS 3.8.1 está instalado [M].

## 2. Cómo queda en Unreal

### 2.1 Carpeta del proyecto (`<P>` = `E:/Projects/TheFourUE`, repositorio nuevo)

| Ruta | Contenido | En git |
|---|---|---|
| `TheFour.uproject` | Módulos y plugins (2.2) | sí |
| `Source/FourCore/` | C++20 sin cabeceras de Unreal: reglas, azar de Godot, generadores, plan (lo define `diseno/mundo.md` §2.1) | sí |
| `Source/TheFour/` | Módulo de juego. Las pruebas de Automation van en `Private/Tests/` de cada módulo | sí |
| `Source/TheFourRender/` | Sombreadores y extensión de vista (`diseno/render.md` §2.2) | sí |
| `Source/TheFourEditor/` | Módulo de editor: `UFourToolset` (2.4). No viaja al juego | sí |
| `Source/TheFour.Target.cs`, `TheFourEditor.Target.cs` | Objetivos `TheFour` y `TheFourEditor` | sí |
| `Shaders/` | `.ush` y `.usf` | sí |
| `Config/Default*.ini` | Ajustes de proyecto, en texto | sí |
| `Tools/` | Guiones: `ue.ps1`, `verify.ps1`, `core_tests.ps1`, `mcp.ps1`, `build_content.ps1`, `capture/*.json`, `assets/*.py` y `*.json`, `compare.py` | sí |
| `SourceAssets/` | Originales con licencia apta: glb, png, jpg, wav, ies | sí, por LFS |
| `golden/` | Huellas y vectores compartidos con Godot (`diseno/mundo.md` D6) | sí |
| `Content/Gen/` | Todo `.uasset` y `.umap` que sale de un guion | no (se regenera) |
| `Content/Hand/` | Lo que no se pueda generar. Se espera vacío | sí, por LFS |
| `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/` | Productos | no |
| `.mcp.json`, `CLAUDE.md`, `.claude/` | Método | sí |

Nota: `diseno/mundo.md` escribe `tools/core_tests.ps1` en minúscula; la carpeta es `Tools/` (git distingue mayúsculas).

### 2.2 `TheFour.uproject`

- Módulos: `FourCore` (Runtime), `TheFour` (Runtime), `TheFourRender` (Runtime, fase `PostConfigInit`), `TheFourEditor` (Editor).
- Plugins de agente, todos solo de editor: `ModelContextProtocol`, `AllToolsets`, `LiveCodingToolset` [AG §2.1: `AllToolsets.uplugin:14-94` no incluye el de Live Coding]. `PythonScriptPlugin` lo arrastra `ToolsetRegistry` [AG §5].
- Los plugins de gameplay y render los fijan sus documentos.

### 2.3 Órdenes del ciclo (todas pasan por `Tools/ue.ps1`, que es el único que lanza procesos del motor)

`ENG` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine`. `UPROJ` = `E:/Projects/TheFourUE/TheFour.uproject`.

| Verbo de `ue.ps1` | Orden que ejecuta | Necesita | Fuente |
|---|---|---|---|
| `core` | `Tools/core_tests.ps1`: `cl.exe` (MSVC 14.50) sobre `Source/FourCore`, ejecuta `four_core_tests.exe` | Solo CPU | `diseno/mundo.md` D13; 14.50.35717 instalado [M] |
| `build` | `"ENG/Build/BatchFiles/Build.bat" TheFourEditor Win64 Development -Project="UPROJ" -WaitMutex` | Editor cerrado | Argumentos: `UE:Build/BatchFiles/Build.bat:9-12` [M]; `-WaitMutex`: `UE:Source/Programs/UnrealBuildTool/UnrealBuildTool.cs:447` [M]; TP_Blank compila así en 78 s [E] |
| `auto <filtro>` | `"ENG/Binaries/Win64/UnrealEditor-Cmd.exe" "UPROJ" -ExecCmds="Automation RunTests <filtro>; Quit" -unattended -nullrhi -nosplash -nosound -UseFixedTimeStep -FPS=60 -abslog=<P>/Saved/verify/auto.log -ReportExportPath=<P>/Saved/verify/auto` | Sin GPU | [AG §6]; informe en `index.json`: `UE:Source/Developer/AutomationController/Private/AutomationControllerManager.cpp:233, 369` [M]; paso fijo: `UE:Source/Runtime/Launch/Private/LaunchEngineLoop.cpp:2460, 4725-4728` [M] |
| `render <filtro>` | Igual que `auto`, con `-RenderOffScreen` en lugar de `-nullrhi` | GPU | `UE:Source/Runtime/Launch/Private/LaunchEngineLoop.cpp:3111` [M]; las pruebas de captura no valen con `-nullrhi` [AG §6] |
| `capture <set>` | `UnrealEditor-Cmd.exe "UPROJ" /Game/Gen/Maps/L_Main -game -RenderOffScreen -unattended -ResX=1920 -ResY=1080 -UseFixedTimeStep -FPS=60 -FourCapture=<P>/Tools/capture/<set>.json` | GPU | 2.4 |
| `py <guion>` | `UnrealEditor-Cmd.exe "UPROJ" -run=pythonscript -script="<P>/Tools/assets/<guion>.py"` (0 bien, -1 error) | Editor cerrado | [AG §5: `PythonScriptCommandlet.cpp:20-73`] |
| `editor` | `UnrealEditor.exe "UPROJ" -ModelContextProtocolStartServer -ModelContextProtocolPort=8000 -RenderOffScreen` | GPU | [AG §2.2]; sin ventana responde con 52 toolsets y 830 herramientas [E] |
| `stop` | Cierra el editor que lanzó `editor` | | |
| `package` | `RunUAT.bat BuildCookRun -project="UPROJ" -platform=Win64 -clientconfig=Shipping -build -cook -stage -pak -archive` | Solo el director | [AG §7], parámetros sin ejecutar |

Reglas de `ue.ps1`: toma un cerrojo (`Saved/ue.lock`) y se niega si ya hay un proceso `UnrealEditor*` que no lanzó él; escribe cada log en `Saved/verify/`; da por rojo un código distinto de 0, una línea `Error:` del registro o un `index.json` con fallos; recorta la salida a las líneas de error.

Ciclo normal de un agente (sin editor): editar C++ o datos, `ue.ps1 core` (segundos), y lo demás lo corre su revisor en serie: `build`, `auto <filtro del área>` y, si el área se ve, `capture <set>`.

Ciclo con editor abierto (un solo agente, el operador): `ue.ps1 editor`, llamadas por `Tools/mcp.ps1`, pruebas con `AutomationTestToolset.RunTestsByFilter` (CAT:15-23), `ue.ps1 stop`. Live Coding no entra en el ciclo normal: viene apagado, no arranca en sesiones desatendidas y es frágil con cambios de cabecera [AG §8]; con compilaciones de un minuto y arranque de 10 a 30 s [E] no compensa. Se reserva para ajustar cuerpos de `.cpp` durante una sesión de aspecto, con `-LiveCoding` y `LiveCodingToolset.CompileLiveCoding`.

### 2.4 Clases propias del método

| Clase | Módulo | Qué hace |
|---|---|---|
| `UFourCaptureSubsystem` (`UGameInstanceSubsystem`) | `TheFour` | Con `-FourCapture=<json>`: por cada toma construye el piso con su semilla, coloca la cámara, espera N fotogramas de convergencia (no reloj de pared), pide el PNG con `FScreenshotRequest::RequestScreenshot(const FString& InFilename, bool bInShowUI, bool bAddFilenameSuffix, ...)` y sigue al recibir `OnScreenshotRequestProcessed` (`UE:Source/Runtime/Engine/Public/UnrealClient.h:219, 266` [M]). Escribe `Saved/Captures/<set>/<id>.png` y `manifest.json`, y sale con código 0 o 1 |
| `FRoomFraming` | `FourCore` | Port de `room_framing.gd`: `Pose(const FManifest&, FName RoomType) -> (ojo, mira, fov)`. La misma pose en los dos motores |
| `FFourTestWorld` | `TheFour`, `Private/Tests/` | Ayuda de pruebas: mundo vacío, piso con semilla, avance de N pasos de 1/60 s |
| `UFourToolset` (`UToolsetDefinition`, funciones estáticas `UFUNCTION(meta=(AICallable))`) | `TheFourEditor` | `CaptureToFile(Pose, Path, ResX, ResY) -> FString` y `ExecConsole(Command) -> FString`. Cubre dos huecos del MCP: las capturas llegan en base64 dentro de texto y no hay orden de consola [AG §3.3; `ToolsetDefinition.h:12-18`] |

Formato de `Tools/capture/<set>.json`: lista de tomas con `id`, `floor`, `seed`, `room` (tipo de sala) o `pose` explícita, `fov_v`, `mode` (`raw` o `played`: sin o con lente, cinta y OSD, como hoy [ficha `capturas.md`]), `warmup_frames`, `reference` (ruta de la foto, opcional). `Tools/compare.py` (Python 3.14 del sistema) aplica los tres criterios de `office_rooms_capture.gd:42-54` y monta la lámina captura junto a referencia.

### 2.5 Tres capas de pruebas

| Capa | Dónde | Qué prueba | Orden | Tiempo esperado |
|---|---|---|---|---|
| 1. Núcleo | `Source/FourCore/Tests/` | Azar, hash, generadores, validadores, huella dorada, encuadres, reglas y cifras puras | `ue.ps1 core` | segundos [D] |
| 2. Automation sin render | `Source/TheFour/Private/Tests/*.cpp`, nombres `TheFour.<Área>.<Caso>` | Lo que necesita `UWorld`: movimiento, sentidos y contrato de criaturas, director, cordura, colisiones, navegación, guardado | `ue.ps1 auto TheFour.` | arranque de 10 a 30 s [E] más las pruebas |
| 3. Con render | Mismas carpetas, prefijo `TheFour.Render.`; y los juegos de capturas | Sombreadores que compilan, luces que no cruzan paredes, capturas comparadas | `ue.ps1 render`, `ue.ps1 capture` | por medir |

Pruebas de bajo nivel del motor (Catch2, `UE:Source/Programs/LowLevelTestsRunner` [M, existe]): no se usan; la capa 1 con `cl.exe` da lo mismo sin depender de que compilen con motor instalado (`diseno/mundo.md` D13). CQTest (`UE:Plugins/Tests/CQTest` [M]) se admite en la capa 2 cuando la prueba necesita esperas entre fotogramas.

### 2.6 `Tools/verify.ps1` (equivalente de la actual)

En serie: `core`, `build`, `auto TheFour.` y, con `-Render`, `render TheFour.Render.` más `capture humo` (4 tomas). Con `-Net`, los escenarios de red: varios procesos `-game -nullrhi -port=<n>` de la misma sesión, como hoy `tools/net_test.ps1`. Escribe `Saved/verify/verification.json` con una entrada por comprobación (nombre, pasó, segundos, log). Nunca dos a la vez; exige editor cerrado. Objetivo: menos de 3 minutos sin `-Render` (hoy 5 a 8).

## 3. Correspondencia pieza a pieza

| Godot | Unreal | Nota |
|---|---|---|
| `tools/godot.ps1` | `Tools/ue.ps1` | Único lanzador |
| `tools/verify.ps1` | `Tools/verify.ps1` | 2.6 |
| `--headless --script res://x.gd` | Prueba de capa 1 o 2; herramienta suelta: `ue.ps1 py` o argumento `-Four...` | No hay guion suelto de juego |
| `--fixed-fps 60` | `-UseFixedTimeStep -FPS=60` | Más el acumulador propio de 60 Hz del juego (`briefs/experiencias.md`, vía índice) |
| `--check-only` | `ue.ps1 core` para `FourCore`; para el resto, `build` | No hay chequeo de un segundo para código con cabeceras del motor |
| `--test-profile` | `-FourTestProfile`: guardados en `Saved/TestProfile/` | El perfil real del jugador no se toca |
| `ERROR:` en el log | Código de salida, `Error:` en el log e `index.json` | |
| `evidence/verification.json` | `Saved/verify/verification.json` | Fuera de git |
| `tests/**/*_test.gd` con `check()` | Capas 1 y 2 | Cada dominio porta las suyas |
| `manifest_golden_test` | `four_core_tests.exe` contra `golden/manifest_canon.json` | `diseno/mundo.md` |
| `creature_contract_test` (lee `.gd` como texto, ficha `pruebas.md`) | Capa 2 para el comportamiento; la parte de quién lee qué pasa a `Tools/scan_contract.py` sobre los `.cpp` o se retira | Pregunta 8.4 |
| `palette_scan_test` (escanea el código) | `Tools/scan_palette.py` dentro de `verify.ps1` | Texto sobre texto |
| `net_test.ps1`, puertos fijos | `verify.ps1 -Net` | En serie |
| `tools/bots.ps1`, `bot_run.gd` | `ue.ps1 bots`: `-game -nullrhi -FourBot=<json>` con latido | Unidad tardía |
| `tools/capture/*.gd` (110) | `UFourCaptureSubsystem` y un `.json` por juego de tomas | Datos, no un programa por captura |
| `room_framing.gd` | `FRoomFraming` | FOV 55 vertical; Unreal usa el horizontal: 85,6 grados a 16:9 (cálculo propio) |
| Espera de 1 500 ms para converger (ficha `capturas.md`) | `warmup_frames` a paso fijo | Reproducible |
| `office_rooms_capture.gd` (criterios) | `Tools/compare.py` | Mismos umbrales |
| `docs/referencias/*.jpeg` | Se leen del repo de Godot por ruta; no se copian | |
| `tools/props/*.py`, `tools/textures/*.py` | Se conservan en el repo de Godot; su salida entra en `SourceAssets/` | `diseno/materiales_assets.md` §3 |
| `.godot/` (caché de importación) | `Content/Gen/` más la caché Zen de la máquina | Se regenera |
| Flujos `encargos`, `frente`, `arreglo` | Los mismos, copiados; la etapa en serie del revisor llama a `ue.ps1` | |

## 4. Decisiones

**D1. Carpeta y repositorio nuevos: `E:/Projects/TheFourUE`, con el `.uproject` en la raíz.** Motivos: el hook del plugin de Epic solo busca un `.uproject` subiendo desde el directorio de trabajo, y el `.mcp.json` va junto al `.uproject` [AG §2.5 y §4]; Godot importaría cualquier png, wav o glb que apareciera bajo su raíz; el `CLAUDE.md` actual es de Godot; la ruta actual tiene un espacio; y LFS se estrena limpio en vez de mezclarse con 4,3 GB de historia sin LFS. Las sesiones del port arrancan en la carpeta nueva y leen el repo de Godot como directorio adicional de solo lectura. Descartado: subcarpeta `unreal/` en el repo actual (falla lo anterior, salvo con `.gdignore` y un `.mcp.json` escrito a mano en la raíz); rama huérfana del mismo repo (no se pueden tener los dos árboles a la vez sin árboles de trabajo).

**D2. C++ y nada más para el juego (pregunta f).** Datos de noviembre de 2026 [AG §11]: AngelScript de Hazelight es un fork del motor que hay que compilar entero y aquí el motor es instalado; sus versiones como plugin están paradas desde 2025; UnrealSharp declara 5.6 a 5.8 pero es beta y añade .NET y otra capa que depurar; Verse no tiene flujo para proyectos 5.8 y Epic lo sitúa en UE 6 (finales de 2027); UnLua está parado desde 2023. Los relatos de 2026 coinciden en que donde mejor rinden los agentes es en C++ [AG §10]. La ventaja real de un lenguaje de guion, iterar sin recompilar, aquí pesa poco: módulo pequeño, motor ya compilado. Python queda para guiones de assets, que no corren en el juego.

**D3. Las cifras del juego, como constantes en C++ (`FourCore`); los ajustes de render, en `Config/*.ini`; los assets, descritos en JSON bajo `Tools/assets/`.** Descartado: DataTables y DataAssets para cifras (binarios, sin diff, y el criterio es conservar el gameplay, no reequilibrarlo desde el editor). Descartado: Blueprints para lógica; solo cáscaras sin grafo si un asset lo exige.

**D4. Un único lanzador con cerrojo (`Tools/ue.ps1`).** Hace cumplir «un solo proceso del motor a la vez» sin depender de que cada agente lo recuerde. `Build.bat` ya se bloquea solo (`UE:Build/BatchFiles/Build.bat:16-33` [M]), pero dos editores chocarían en el puerto 8000 y en los paquetes [AG §9].

**D5. Tres capas de pruebas, y cuanto más abajo mejor.** Una regla nueva va a `FourCore` si no necesita mundo: se prueba en segundos, sin editor y en paralelo. Descartado: todo en Automation (ocupa el único editor en cada unidad).

**D6. Capturas con el juego sin ventana (`-game -RenderOffScreen`) y tomas en datos.** Es el mismo camino de render que verá el jugador, incluye la cadena de la cámara y no necesita MCP. Descartado como vía principal: `CaptureViewport` del MCP (visor del editor, imagen en base64 dentro de texto [AG §2.6]); `AScreenshotFunctionalTest` (exige colocar actores en mapas binarios); `UAutomationBlueprintFunctionLibrary::TakeHighResScreenshot` (`UE:Source/Developer/FunctionalTesting/Public/AutomationBlueprintFunctionLibrary.h:143` [M], devuelve una tarea de editor); Movie Render Queue (sin toolset [AG §3.3] y sobra para fotos fijas).

**D7. MCP: se usa para lo que no es texto y nada más.** Crear y revisar assets de forma interactiva, inspeccionar la escena, mirar el registro, correr pruebas con el editor ya abierto. Todo asset que deba existir en el juego acaba en un guion de `Tools/assets/` (reproducible); el MCP sirve para explorar cómo se hace y para comprobar el resultado. Descartado: construir el contenido a base de llamadas MCP sueltas (no queda rastro en git, y los fallos vuelven como «Ok» [AG §10]).

**D8. Los agentes hablan con el MCP por `Tools/mcp.ps1` (HTTP directo), no por la conexión MCP de la sesión.** El servidor es JSON-RPC por HTTP [AG §2.3]; un cliente fino (`initialize`, `list`, `describe`, `call <toolset> <tool> <json>`) funciona igual en la sesión principal y en agentes de un flujo, no depende de que el editor estuviera abierto al empezar la sesión, espera a que el número de toolsets se estabilice (no hay señal de listo [AG §10]) y guarda en disco los PNG que lleguen en base64. El `.mcp.json` se versiona igualmente para sesiones interactivas.

**D9. Lo generado no se versiona; sus fuentes, sí.** `Content/Gen/` fuera de git; `SourceAssets/` y los guiones dentro. `Tools/build_content.ps1` lanza los guiones en orden y se salta los que no han cambiado (huella de entradas). Motivo: cada regeneración reescribe cientos de `.uasset` y llenaría LFS; y obliga a que los guiones sean de verdad la fuente. Coste: un clon limpio necesita una pasada de `build_content` antes de abrir el juego. Descartado: versionar todo `Content/` (lo habitual, pero con binarios que nadie puede revisar).

**D10. Servidor MCP solo por línea de órdenes y solo mientras dura la sesión de editor.** Nunca `bAutoStartServer`. Puerto fijo 8000. Ver 4.1.

### 4.1 MCP y plugin de Epic: activación, límites y riesgos (pregunta b)

Activación: (1) los tres plugins en el `.uproject` (2.2); (2) `<P>/.mcp.json` escrito a mano con `{"mcpServers": {"unreal-mcp": {"type": "http", "url": "http://127.0.0.1:8000/mcp"}}}` [AG §2.5]; (3) `"enabledPlugins": {"unreal-engine-skills-for-claude-code@claude-plugins-official": true}` en `<P>/.claude/settings.json` [AG §4]; (4) `ue.ps1 editor`; (5) `mcp.ps1 list` hasta ver al menos 52 toolsets.

Qué da (CAT, 52 toolsets y 830 herramientas con `AllToolsets`): actores y escena (17 y 20), assets (21), propiedades de cualquier objeto (6), materiales e instancias (22 y 13), mallas estáticas con importación, LOD, colisión y Nanite (16), texturas (2), DataTables (10), Blueprints (53), UMG (23), Niagara (56), PCG (31), pruebas de Automation (7), ajustes de configuración (8), registro (4), capturas y PIE (`EditorAppToolset`, 21), automatización de la interfaz del editor (14), Sequencer y Control Rig (más de 300).

Qué no hace [AG §3.3]: Python libre (`execute_tool_script` solo encadena herramientas), órdenes de consola, compilación completa, cocinar, empaquetar, git, crear un nivel nuevo, paisaje, Movie Render Queue, audio; `write_file` solo escribe txt, json, csv, html, py y md dentro de `Content/` o `Saved/`. El plugin de Claude Code solo aporta tres skills y un hook que inyecta una nota; no instala servidor; documenta cosas que 5.8.4 no trae (proxy de reconexión, `execute_python`) [AG §4].

Riesgos: escucha en `127.0.0.1:8000` sin autenticación, solo valida `Origin` [AG §2.3]: cualquier proceso del usuario puede mandar al editor. Puede borrar y mover assets, cambiar ajustes de proyecto (`ConfigSettingsToolset`), crear y activar plugins (`PluginToolset`) y pulsar cualquier control del editor (`SlateInspectorToolset`). Los fallos suelen volver como éxito con el error en el texto, y reintentar a ciegas duplica cambios [AG §10]. Al arrancar deja un aviso legal: lo que se envía al modelo es «Licensed Technology» según la sección 6(e) del EULA [AG §2.3].

Reglas: un solo operador a la vez; `git status` limpio antes de abrir; leer el texto de cada resultado y releer el estado tras cada cambio; no reintentar sin comprobar; guardar con `AssetTools.save_assets`; lista de bloqueo (`ToolsetBlockedNames` [AG §2.4]) para `SlateInspectorToolset`, `PluginToolset`, `MCPClientToolset` y los toolsets de Sequencer, Control Rig, GAS y Dataflow (seguridad y contexto); cerrar el editor al acabar.

## 5. Prueba de concepto visual

**Entra (lo mínimo del método para que las otras pruebas de concepto existan):** M0 (repositorio y esqueleto que compila), M1 (`ue.ps1` con `build`, `py`, `capture`, `editor`, `stop`), M4 reducido (`UFourCaptureSubsystem` con poses explícitas, sin generador) y M5 (MCP con `mcp.ps1`). Medidas que salen de aquí y sustituyen estimaciones: compilación incremental tras tocar un `.cpp` y una cabecera; arranque de `-game -RenderOffScreen` hasta el primer PNG; primera compilación de sombreadores; si `-run=pythonscript` compila materiales sin ventana; tiempo hasta que `list_toolsets` se estabiliza.

**No entra:** `verify.ps1` completo, capa 2 de pruebas, red, bots, banco, empaquetado, `UFourToolset`, `compare.py` (en la prueba de concepto la comparación con la foto la hace quien mira).

## 6. Unidades de trabajo del port completo

∥ = puede ir en paralelo con las demás marcadas (archivos disjuntos, sin procesos del motor).

| N.º | Unidad | Origen | Resultado | Prueba de aceptación |
|---|---|---|---|---|
| M0 | Repositorio y esqueleto (director) | Plantilla `TP_Blank` | Carpeta, `git init`, `.gitignore`, `.gitattributes`, `.uproject` con cuatro módulos vacíos y tres plugins | `Build.bat` en verde; tiempo anotado; `git lfs track` lista los patrones |
| M1 | `Tools/ue.ps1` | `tools/godot.ps1` | Verbos de 2.3 con cerrojo y recorte de logs | Dos llamadas simultáneas: la segunda se niega; un error de compilación sale en menos de 20 líneas |
| M2 ∥ | `Tools/core_tests.ps1` | `diseno/mundo.md` U1 | Es la unidad U1 de ese documento | La suya |
| M3 | Primera prueba de capa 2 y `FFourTestWorld` | — | `TheFour.Humo.Arranque` | `ue.ps1 auto TheFour.` deja `index.json` con 1 de 1; tiempo anotado |
| M4 | Capturas | `room_framing.gd`, `lookdev_capture.gd`, `office_rooms_capture.gd` | `UFourCaptureSubsystem`, `FRoomFraming`, `Tools/capture/humo.json` | Dos ejecuciones seguidas dan PNG idénticos o con diferencia media menor del 1 %; sin ventana visible |
| M5 | MCP | [AG §2] | `.mcp.json`, `Tools/mcp.ps1`, lista de bloqueo, ajuste del plugin | Crear una instancia de material por `mcp.ps1`, releer su parámetro, guardarla; puerto cerrado tras `stop` |
| M6 ∥ | `Tools/compare.py` | `office_rooms_capture.gd:42-54` y sus funciones de medida | Criterios y lámina junto a la referencia | Sobre una captura de Godot ya aprobada da el mismo veredicto que la herramienta actual |
| M7 | `Tools/build_content.ps1` | `diseno/materiales_assets.md` §2 | Orden de guiones y huellas | Borrar `Content/Gen/` y regenerar deja el juego igual (mismas capturas de humo) |
| M8 | `Tools/verify.ps1` | `tools/verify.ps1` | 2.6 | Una prueba rota a propósito en cada capa sale en rojo con su nombre |
| M9 ∥ | `CLAUDE.md` y flujos | `CLAUDE.md`, `.claude/workflows/*.js` | Reglas del apartado 6.1; flujos con la etapa en serie por `ue.ps1` | Un frente de prueba de dos unidades cierra sin intervención |
| M10 | `UFourToolset` | [AG §2.6] | `CaptureToFile`, `ExecConsole` | `mcp.ps1 call` deja un PNG en disco desde el editor abierto |
| M11 ∥ | Escaneos de texto | `palette_scan_test.gd`, parte textual de `creature_contract_test.gd` | `Tools/scan_palette.py`, `Tools/scan_contract.py` | Detectan una violación sembrada |
| M12 | Pruebas por área | `tests/**` | Cada dominio porta las suyas a la capa 1 o 2 dentro de sus unidades | Tabla de equivalencia prueba a prueba sin huecos sin justificar |
| M13 | Red en `verify` | `tools/net_test.ps1`, `tests/net/net_test.gd` | `verify.ps1 -Net`, cinco escenarios | Los cinco en verde dos veces seguidas |
| M14 | Bots | `tools/bots.ps1`, `tools/bots/` (4 942 líneas, ficha) | `ue.ps1 bots` con latido y `summary.json` | Tres bots completan un piso sin interfaz |
| M15 | Banco | `tools/benchmarks/`, `docs/PERFORMANCE.md` | Recorrido fijo que vuelca ms de GPU y VRAM | Tabla por nivel de calidad (con `diseno/render.md` R18) |
| M16 | Empaquetado (director) | `tools/export/` | `ue.ps1 package` | El ejecutable arranca en la máquina y no contiene módulos de editor |

Orden: M0, M1, luego M3, M4 y M5 en serie (usan el motor) mientras M2, M6, M9 y M11 van en paralelo; M7 y M8 después; el resto, con los dominios.

### 6.1 Borrador de reglas para el `CLAUDE.md` del proyecto de Unreal (pregunta e)

Se conservan tal cual del actual: los tres niveles y sus modelos, el regulador de la ventana, encargos, revisión por área, git (solo el director hace commit, rutas explícitas, mensaje en inglés, push cada 3 o 4), heredocs, textos sin «·» ni «—», lore, sonido, licencias de assets. Cambia el apartado de la máquina y las reglas para agentes:

- **La máquina es lo escaso: Unreal.** Un solo proceso del motor a la vez (editor, commandlet, juego o compilación). Todo se lanza con `Tools/ue.ps1`; nunca `UnrealEditor*.exe`, `Build.bat` ni `RunUAT.bat` a mano.
- **Unidades en paralelo:** editan archivos disjuntos y solo pueden ejecutar `ue.ps1 core`. `build`, `auto`, `render`, `capture` y `py` los corre el revisor del área, en serie.
- **`Tools/verify.ps1`:** nunca dos a la vez; con el editor cerrado; una por área.
- **Editor y MCP:** solo el operador que nombre el encargo. Antes, `git status` limpio. Cada llamada se comprueba leyendo el texto del resultado y releyendo el estado. No se reintenta a ciegas. Al acabar, `ue.ps1 stop`.
- **Nada a mano en el editor.** Todo asset sale de un guion de `Tools/assets/` o del código. Lo explorado por MCP se pasa al guion antes de dar la unidad por hecha. No se versiona nada de `Content/Gen/`.
- **C++:** estilo de Epic (prefijos `U`, `A`, `F`, `E`, `b`); comentarios breves en inglés que dicen el porqué. Antes de usar una clase o firma del motor que no esté ya en el proyecto, buscarla en `UE:Source` o `UE:Plugins` con la búsqueda acotada a un módulo; no se inventan funciones. Clase nueva: revisar `UCLASS`, `GENERATED_BODY`, el `*_API` y el módulo en el `.Build.cs`.
- **Lógica sin mundo va a `FourCore`** (sin cabeceras de Unreal) con su prueba en `Source/FourCore/Tests/`.
- **Cambios de cabecera o de reflexión:** editor cerrado y `ue.ps1 build`. Live Coding solo para cuerpos de `.cpp` en una sesión de aspecto.
- **Blueprints:** ninguno con lógica.
- **Capturas:** siempre por `ue.ps1 capture <set>`; se juzgan en la vista de juego junto a su referencia.
- **Perfil:** pruebas y herramientas con `-FourTestProfile`. Nunca matar un proceso del juego del autor.
- **El repo de Godot** (`E:/Projects/The Four`) es referencia de solo lectura: el gameplay se copia de ahí con ruta y línea; no se cambia desde este proyecto.
- **Si el encargo no encaja con el motor**, se informa; no se rediseña.

### 6.2 `.gitignore` y `.gitattributes`

- Ignorar: `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/`, `Content/Gen/`, `.vs/`, `*.sln`, `Build/` salvo iconos y recursos (plantilla de GitHub, https://raw.githubusercontent.com/github/gitignore/main/UnrealEngine.gitignore, vía [AG §12]).
- LFS: `*.uasset`, `*.umap`, y dentro de `SourceAssets/`: `*.glb`, `*.fbx`, `*.png`, `*.jpg`, `*.exr`, `*.hdr`, `*.wav`, `*.ogg`.
- Texto con fin de línea fijo: `*.cpp`, `*.h`, `*.cs`, `*.ini`, `*.ush`, `*.usf`, `*.json`, `*.py`, `*.ps1`, `*.md`, `*.uproject`, `*.ies`.

## 7. Riesgos y cómo se detectan pronto

| Riesgo | Detección |
|---|---|
| `-game -RenderOffScreen` no deja PNG, o tarda minutos por sombreadores | M4 en la prueba de concepto, el primer día. Salida: prueba de capa 3 con `TakeHighResScreenshot`, o `UFourToolset.CaptureToFile` con el editor abierto |
| Las capturas no son repetibles (TSR, Lumen y exposición acumulan historia) | Aceptación de M4: dos pasadas y diferencia. Se sube `warmup_frames` o se fija la exposición por toma |
| El arranque del editor para la capa 2 hace lenta cada revisión | Tiempo anotado en M3. Remedio: bajar pruebas a la capa 1 |
| Un proceso del motor huérfano bloquea a todos | El cerrojo de `ue.ps1` guarda PID y hora; `ue.ps1 stop` lo cierra; tope de tiempo por verbo |
| Compilación completa con el editor abierto | `ue.ps1 build` se niega si hay editor |
| El MCP informa éxito sin haber hecho el cambio | Regla de releer; `mcp.ps1` marca como fallo los resultados cuyo texto contiene `error` o `failed` |
| Otro programa usa el puerto 8000 | `ue.ps1 editor` lo comprueba antes; el puerto es un parámetro |
| Los guiones de Python no pueden crear algo y se hace a mano | `Content/Hand/` debe seguir vacío; cada archivo ahí pide permiso del director |
| LFS se llena | `SourceAssets/` solo lleva lo que el juego usa; cuota mirada en M0 |
| Errores típicos del C++ de agentes (funciones inventadas, macros, módulos) [AG §10] | Regla de buscar en el motor; `build` en la revisión de cada unidad |
| Godot y Unreal divergen porque se sigue tocando Godot | Pregunta 8.2; `golden/` anota el commit de Godot del que salió |
| El motor se actualiza desde el lanzador (5.8.5 o 5.9) a mitad del port | No actualizar sin decisión del director; versión anotada en `CLAUDE.md` |

## 8. Preguntas para el autor

1. **Repositorio nuevo.** ¿De acuerdo con una carpeta `E:/Projects/TheFourUE` y un repositorio privado nuevo en GitHub (lo crea el director con `gh` si lo autorizas)? ¿Qué nombre?
2. **Godot durante el port.** ¿Se congela el juego de Godot (solo arreglos) o sigue el desarrollo del piso 2 a la vez? De esto depende cuánto se rehace.
3. **EULA, sección 6(e).** El MCP envía contenido del motor al modelo y Epic hace responsable al usuario de que el proveedor no entrene con ello. ¿Lo aceptas para este uso?
4. **Contrato de la criatura.** Hoy una parte comprueba, leyendo el código, qué archivo puede leer qué. ¿Se conserva esa vigilancia sobre el C++ o basta con las pruebas de comportamiento?
5. **Git LFS.** Si `SourceAssets/` supera la cuota de LFS de tu cuenta de GitHub, ¿pagas el paquete de datos o prefieres guardar esos originales fuera de GitHub?

## 9. Herramientas, plugins o assets que conviene instalar o bajar

| Qué | Fuente | Licencia | Estado |
|---|---|---|---|
| Plugins del motor `ModelContextProtocol`, `AllToolsets`, `LiveCodingToolset` | `UE:Plugins/Experimental/` | EULA de Unreal; experimentales, solo editor | Ya en el motor; activar en el `.uproject` |
| `unreal-engine-skills-for-claude-code` 3.1.2 | https://github.com/EpicGames/unreal-engine-skills-for-claude-code-plugin | MIT | Instalado; activar en `.claude/settings.json` |
| MSVC 14.50 y SDK de .NET Framework 4.8 | Build Tools 2026 | Microsoft | Instalados [E] |
| Git LFS 3.8.1 | git-lfs.com | MIT | Instalado; falta `git lfs install` en el repo nuevo |
| Pillow o NumPy para `compare.py` | PyPI | HPND, BSD | Solo si hacen falta; comprobar si ya están |

No hace falta nada más. No se instala ningún MCP de terceros, ni UnrealSharp, ni AngelScript.

## 10. Sin comprobar

- Todo lo que depende de ejecutar: que `-game -RenderOffScreen` con `UnrealEditor-Cmd.exe` renderice y escriba el PNG pedido con `FScreenshotRequest` en esta máquina; tiempos de compilación incremental, de sombreadores y de las tres capas; el objetivo de 3 minutos de `verify`.
- Que el editor lanzado con `-RenderOffScreen` (sin `-nullrhi` ni `-unattended`) sirva el MCP igual que en la comprobación del encargo, y que Live Coding arranque en él con `-LiveCoding`.
- Que `-run=pythonscript` pueda crear niveles, compilar materiales e importar con Interchange sin ventana (lo marca también `diseno/materiales_assets.md` §7).
- En qué archivo `.ini` vive `ToolsetBlockedNames` y si se puede fijar por proyecto (solo se conoce la cabecera citada en [AG §2.4]); los nombres exactos de los toolsets a bloquear salen de CAT.
- Que `-ResX`, `-ResY`, `-nosound` y `-abslog` se comporten como es habitual en 5.8.4 (no se buscaron en el código); la forma exacta del filtro de `Automation RunTests` para prefijos.
- Que las pruebas de red con varios procesos `-game -nullrhi` y Steam desactivado se conecten por IP en local.
- Que la conexión MCP nativa de Claude Code se recupere si el editor arranca después de la sesión (por eso D8 no depende de ella).
- Que las pruebas de bajo nivel del motor compilen con motor instalado (no se usan).
- La cuota actual de Git LFS de la cuenta del autor y el tamaño real de `SourceAssets/`.
- Los 85,6 grados de FOV horizontal son un cálculo propio (2·atan(tan(27,5°)·16/9)).
- Los recuentos de la ficha `pruebas.md` (63 comprobaciones, 2 724 s) y las 4 942 líneas de bots no se recontaron; sí se comprobaron las constantes de encuadre y de comparación, los puertos y el criterio de `verify.ps1`.
- Estado de UnrealSharp, AngelScript y Verse: tomado de [AG §11] (consultas del 14 de noviembre de 2026); no se repitió la consulta web hoy.
- El formato de asset en texto del motor (`bTextAssetFormatSupport`) no se evaluó.
