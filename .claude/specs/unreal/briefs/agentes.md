# Cómo trabaja Claude Code con Unreal 5.8

Informe para los analistas del port de The Four. Fecha: 14 de noviembre de 2026.
No se ejecutó Unreal ni Godot, no se compiló nada y no se instaló nada: todo sale de leer el código del motor instalado, el plugin de Epic ya presente en esta máquina y la web.

**Cómo leer las marcas**

| Marca | Significa |
|---|---|
| **[C]** | Comprobado leyendo el archivo local que se cita (ruta:línea). |
| **[W]** | Leído en la web (URL). No comprobado aquí; fiarse según la fuente. |
| **[D]** | Deducción mía a partir de hechos [C]. Razonable, pero sin ejecutar. |

**Abreviaturas de ruta**

- `ENG` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine`
- `MCP` = `ENG/Plugins/Experimental/ModelContextProtocol/Source`
- `TR` = `ENG/Plugins/Experimental/ToolsetRegistry`
- `TS` = `ENG/Plugins/Experimental/Toolsets`
- `ET` = `TS/EditorToolset/Content/Python/editor_toolset/toolsets`
- `PLG` = `%USERPROFILE%/.claude/plugins/cache/claude-plugins-official/unreal-engine-skills-for-claude-code/3.1.2`

---

## 1. Lo que hay en esta máquina

| Hecho | Fuente |
|---|---|
| Motor 5.8.4, changelist 58902052, rama `++UE5+Release-5.8`. | [C] `ENG/Build/Build.version` |
| Es una compilación instalada (del lanzador), no un árbol de código fuente compilable del motor. | [C] existe `ENG/Build/InstalledBuild.txt` |
| Trae `UnrealBuildTool.exe`, `AutomationTool.exe`, `UnrealEditor-Cmd.exe`, `zen.exe`, `zenserver.exe`, `ShaderCompileWorker.exe`, `UnrealPak.exe` y `Build.bat`, `RunUAT.bat`. | [C] `ENG/Binaries/DotNET/*`, `ENG/Binaries/Win64/*`, `ENG/Build/BatchFiles/*` |
| Trae su propio .NET 10 para UBT y UAT. | [C] `ENG/Binaries/ThirdParty/DotNet/10.0/win-x64` |
| Python embebido 3.11.8 (no el 3.14 del sistema). | [C] `ENG/Source/ThirdParty/Python3/Win64/include/patchlevel.h:26` |
| **El único MSVC instalado es 14.51.36231.** El motor prefiere 14.50.35717 a 14.50.99999 (VS2026 18.0) o 14.44.x. 14.51 no está vetado y supera el mínimo (14.38.33130), pero no es «preferido». | [C] `C:/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/VC/Tools/MSVC/`; `ENG/Config/Windows/Windows_SDK.json:31-33, 40-46` |
| Con un compilador más nuevo que el preferido UBT solo avisa («has not been heavily tested») y sigue, salvo que `ToolchainVersionWarningLevel` sea Error. | [C] `ENG/Source/Programs/UnrealBuildTool/Platform/Windows/UEBuildWindows.cs:376-381, 1543-1558` |
| El componente que el motor sugiere instalar es `Microsoft.VisualStudio.Component.VC.14.50.18.0.x86.x64`. | [C] `Windows_SDK.json:79-80` |
| Windows SDK instalado 10.0.26100.0; el motor prefiere 10.0.22621.0 y acepta de 10.0.19041 a 10.9.99999. | [C] `C:/Program Files (x86)/Windows Kits/10/Include`; `Windows_SDK.json:2-4` |
| El plugin de Epic para Claude Code **ya está instalado** (ámbito de usuario, versión 3.1.2, commit `0e27bde`, instalado hoy). Sus tres skills ya aparecen en las sesiones. | [C] `%USERPROFILE%/.claude/plugins/installed_plugins.json` |
| Git LFS 3.8.1 instalado; el repositorio actual no usa LFS (los `.png`, `.jpg`, `.glb` van como binarios normales). | [C] `git lfs version`; `E:/Projects/The Four/.gitattributes` |
| La cuenta de `gh` no ve `EpicGames/UnrealEngine` (404): no está enlazada a la organización de Epic. | [C] `gh api repos/EpicGames/UnrealEngine` |

**Riesgo abierto n.º 1 [D]:** nadie ha compilado todavía un módulo de 5.8.4 con MSVC 14.51. Es lo primero que debe medir la prueba de concepto; si falla, la salida es añadir el componente 14.50 con el instalador de Visual Studio.

---

## 2. El servidor MCP del motor

### 2.1 Qué es y cómo se activa

| Hecho | Fuente |
|---|---|
| Plugin «Unreal MCP», experimental, desactivado por defecto, `NoRedist`. Depende de `ToolsetRegistry`. | [C] `ENG/Plugins/Experimental/ModelContextProtocol/ModelContextProtocol.uplugin` |
| `ToolsetRegistry` es solo de editor (`EditorOnly`, `TargetAllowList: Editor`) y depende de `PythonScriptPlugin`, `EditorScriptingUtilities` y `FileSandbox`. Nada de esto viaja al juego empaquetado. | [C] `TR/ToolsetRegistry.uplugin` |
| El servidor sin toolsets no expone herramientas útiles. Las herramientas las dan los plugins de `Toolsets/*`; `AllToolsets` es un agregador que activa 21 de ellos. Todos vienen desactivados. | [C] `TS/AllToolsets/AllToolsets.uplugin:14-94`; [W] hilo del foro de Epic, 18 jun 2026: en 5.8 estable solo aparecía `AgentSkillToolset` hasta añadir `AllToolsets` al `.uproject` https://forums.unrealengine.com/t/5-8-stable-mcp-is-not-initializing-exposing-tools-was-no-an-issue-in-5-8-preview/2729455 |
| **`AllToolsets` no incluye `LiveCodingToolset`, `MVVMToolset`, `ChaosClothAssetToolset`, `MetaHumanGenerator` ni `SequencerAnimMixerToolset`.** Para compilar desde el MCP hay que activar `LiveCodingToolset` aparte en el `.uproject`. | [C] misma lista, `AllToolsets.uplugin:14-94` |

Para activarlo hacen falta, en el `.uproject`: `ModelContextProtocol`, `AllToolsets` y `LiveCodingToolset` (los tres con `"Enabled": true`). [C]+[D]

### 2.2 Arranque

| Vía | Detalle | Fuente |
|---|---|---|
| Consola del editor | `ModelContextProtocol.StartServer [puerto]`, `ModelContextProtocol.StopServer`, `ModelContextProtocol.RefreshTools` | [C] `MCP/ModelContextProtocol/Private/ModelContextProtocolModule.cpp:22-68` |
| Línea de órdenes | `-ModelContextProtocolStartServer` (el antiguo `-StartModelContextProtocolServer` está obsoleto) y `-ModelContextProtocolPort=N` | [C] `MCP/ModelContextProtocolEngine/Private/ModelContextProtocolSettings.cpp:20, 34-48` |
| Ajuste persistente | `bAutoStartServer=True` en `[/Script/ModelContextProtocolEngine.ModelContextProtocolSettings]`, que vive en `EditorPerProjectUserSettings` (por usuario, en `Saved/Config/WindowsEditor/`, fuera de git) | [C] `MCP/ModelContextProtocolEngine/Public/ModelContextProtocolSettings.h:17, 41-42`; [C] `PLG/skills/unreal-mcp/references/setup.md:37-46` |
| En un commandlet | El arranque por ajuste **se salta**; solo arranca con `-ModelContextProtocolStartServer`. El motivo que da el código: un commandlet competiría por el puerto con un editor abierto. | [C] `ModelContextProtocolSettings.cpp:50-58` |

El arranque automático ocurre al terminar la inicialización del editor, después de registrar los toolsets ya cargados. [C] `MCP/ModelContextProtocolEditor/Private/ModelContextProtocolEditor.cpp:49-70`

### 2.3 Transporte, puerto y seguridad

| Hecho | Fuente |
|---|---|
| HTTP con JSON-RPC 2.0 («Streamable HTTP»). Ruta por defecto `/mcp`, puerto por defecto 8000, nombre del servidor `unreal-mcp`. | [C] `MCP/ModelContextProtocol/Public/ModelContextProtocol.h:16, 45-47` |
| Versiones de protocolo admitidas: 2025-11-25, 2025-06-18 y 2024-11-05. | [C] `ModelContextProtocol.h:19-28` |
| Escucha solo en la interfaz local: el servidor HTTP del motor enlaza `localhost` salvo que un `.ini` diga otra cosa. | [C] `ENG/Source/Runtime/Online/HTTPServer/Private/HttpServerConfig.h:13`; `HttpListener.cpp:68-70` |
| **No hay autenticación**: ni token ni clave. La única defensa es validar la cabecera `Origin` (admite ausencia de `Origin`, `localhost`, `127.0.0.1` y `[::1]`). Cualquier proceso del mismo usuario puede conectarse. | [C] `MCP/ModelContextProtocol/Private/ModelContextProtocolServer.cpp:68-118`; [C] `PLG/README.md:88` |
| Sesiones con cabecera `Mcp-Session-Id`; sin ella, 400; con una desconocida, 404 (el cliente debe reinicializar). | [C] `ModelContextProtocolServer.cpp:23, 579-594, 664-671` |
| Métodos atendidos: `initialize`, `ping`, `notifications/initialized`, `notifications/cancelled`, `tools/list`, `tools/call`, `resources/list`, `resources/read`. **No hay `prompts`.** | [C] `ModelContextProtocolServer.cpp:26-36` |
| El GET (canal SSE aparte) devuelve «método no permitido». El flujo SSE solo se abre dentro de una llamada que pida progreso (`progressToken`). | [C] `ModelContextProtocolServer.cpp:831-837, 1063-1065` y `ProcessGetRequest` |
| Al arrancar escribe en el registro un aviso legal: lo que se envíe al LLM es «Licensed Technology» según la sección 6(e) del EULA de Unreal, y el usuario responde de que su proveedor no lo use para entrenar. | [C] `ModelContextProtocolServer.cpp:445-446` |

### 2.4 Ajustes

| Ajuste | Por defecto | Efecto | Fuente |
|---|---|---|---|
| `ServerUrlPath` | `/mcp` | Ruta base | [C] `ModelContextProtocolSettings.h:24-25` |
| `ServerPortNumber` | 8000 | Puerto | [C] `ModelContextProtocolSettings.h:37-38` |
| `bAutoStartServer` | false | Arranque con el editor | [C] `ModelContextProtocolSettings.h:41-42` |
| `bEnableToolSearch` | true | `tools/list` devuelve solo `list_toolsets`, `describe_toolset` y `call_tool`; las demás se descubren y se despachan por `call_tool`. En false, cada herramienta se registra como nativa. | [C] `ModelContextProtocolSettings.h:44-46`; `MCP/ModelContextProtocolEditor/Private/ModelContextProtocolToolsetRegistryAdapter.cpp` (`RegisterTools`) |
| `ToolsetBlockedNames` / `ToolsetAllowedNames` | vacías | Ocultar o limitar toolsets y herramientas por patrón | [C] `TR/Source/ToolsetRegistry/Public/ToolsetRegistry/ToolsetRegistrySubsystem.h:29-40` |
| `SetObjectPropertiesBlockedClasses` / `...BlockedProperties` | vacías | Vetar clases o propiedades a `set_properties` | [C] `ToolsetRegistrySubsystem.h:55-68` |
| CVars `ModelContextProtocol.ProgressIntervalSeconds` (1.0), `.PaginationPageSize` (0), `.WrapPODToolResultsInObject` (true) | | Latido de progreso, paginación, envoltorio de resultados simples | [C] `MCP/ModelContextProtocol/Private/ModelContextProtocol.cpp:45, 59, 65` |

### 2.5 El archivo `.mcp.json`

- La orden `ModelContextProtocol.GenerateClientConfig ClaudeCode` escribe `.mcp.json` con `{"mcpServers": {"unreal-mcp": {"type": "http", "url": "http://127.0.0.1:<puerto><ruta>"}}}`, conservando lo que ya hubiera en el archivo. [C] `MCP/ModelContextProtocolEngine/Private/ModelContextProtocolClientConfig.cpp:31, 83, 158`; `ModelContextProtocolEngineModule.cpp:40-70`
- **En un motor instalado (nuestro caso) lo escribe junto al `.uproject`.** [C] `ModelContextProtocolClientConfig.cpp:162-164`
- Se puede escribir a mano sin abrir el editor. [C] `PLG/skills/unreal-mcp/references/setup.md:68-79`
- **Consecuencia [D]:** si el `.uproject` va en una subcarpeta del repositorio y las sesiones de Claude Code arrancan en la raíz, el `.mcp.json` generado no quedará donde Claude Code lo busca. O el `.uproject` va en la raíz de la sesión, o el `.mcp.json` de la raíz se escribe a mano.

### 2.6 Cómo se usa desde el agente

1. `list_toolsets` da nombres y descripciones; `describe_toolset` da el esquema JSON de las herramientas de uno; `call_tool` recibe `toolset_name`, `tool_name` (sin prefijo) y `arguments`. [C] `MCP/ModelContextProtocolEditor/Private/ModelContextProtocolToolSearch.cpp:61, 93-122`
2. Los nombres completos tienen dos formas: C++ `EditorToolset.EditorAppToolset.GetSelectedActors` y Python `editor_toolset.toolsets.actor.ActorTools.set_actor_transform`. [C] `ET/programmatic.py:494-503`
3. Las llamadas se ejecutan en el hilo principal del editor. [C] `TR/Source/ToolsetRegistry/Private/ToolsetRegistry/RunOnMainThread.h:16-19`
4. **Todo resultado de un toolset vuelve como texto.** El adaptador usa siempre `MakeTextResult`; una imagen es un PNG en base64 dentro del JSON. [C] `ModelContextProtocolToolsetRegistryAdapter.cpp` (`RunAsync` y `DispatchToolCall`); `TR/Source/ToolsetRegistry/Public/ToolsetRegistry/ToolsetImage.h:22-24`; `TS/EditorToolset/Source/EditorToolset/Private/EditorAppToolset.h:168-170`
5. Un toolset propio del proyecto se escribe en C++ (clase que hereda de `UToolsetDefinition` con funciones estáticas `UFUNCTION(meta=(AICallable))`) o en Python (`@unreal.uclass()` + `@toolset_registry.tool_call`, registrado desde `init_unreal.py`). [C] `TR/Source/ToolsetRegistry/Public/ToolsetRegistry/ToolsetDefinition.h:12-18`; `ET/actor.py:10-17`; `TS/EditorToolset/Content/Python/init_unreal.py`

---

## 3. Toolsets y herramientas (inventario del 5.8.4 local)

Recuento hecho sobre el código: funciones con `@toolset_registry.tool_call` en Python y `UFUNCTION(meta=(AICallable))` en C++.

### 3.1 EditorToolset (el núcleo; va dentro de `AllToolsets`)

| Clase | N.º | Qué permite | Archivo |
|---|---|---|---|
| `ActorTools` | 17 | Etiqueta, tags, transformar, `look_at`, jerarquía, límites, añadir y quitar componentes | [C] `ET/actor.py` |
| `SceneTools` | 20 | `load_level`, buscar actores, crear actor desde clase o desde asset, borrar, carpetas del outliner, `trace_world`, `merge_actors`, instancias de nivel, guardar actor | [C] `ET/scene.py` |
| `AssetTools` | 21 | Carpetas, existe, duplicar, mover, borrar, buscar, metadatos, cargar, `save_assets` (lista vacía = todo lo sucio), dependencias y referencias, `read_file` y `write_file` | [C] `ET/asset.py` |
| `ObjectTools` | 6 | Reflexión genérica: buscar subclases, listar, leer, escribir y restablecer propiedades de cualquier `UObject` (JSON) | [C] `ET/object.py:81-94` |
| `BlueprintTools` | 53 | Crear Blueprint, compilar, grafos, funciones, eventos, variables (con replicación), nodos, pines, y un DSL de expresiones S para escribir o leer un grafo entero (`write_graph_dsl`, `read_graph_dsl`) | [C] `ET/blueprint.py:177, 1454` |
| `MaterialTools` | 22 | Crear material, función o colección de parámetros; añadir, conectar y borrar expresiones; conectar a las salidas; `recompile` (falla si el shader no compila) | [C] `ET/material.py:31, 486` |
| `MaterialInstanceTools` | 13 | Crear instancia; parámetros escalares, vectoriales, de textura y conmutadores estáticos; cambiar padre | [C] `ET/material_instance.py` |
| `StaticMeshTools` | 16 | `import_file` (malla desde disco, con o sin materiales y texturas), LOD, colisiones convexas, materiales por ranura, Nanite sí o no | [C] `ET/static_mesh.py:15` |
| `SkeletalMeshTools` | 22 | Importar, huesos, sockets, materiales, physics asset | [C] `ET/skeletal_mesh.py` |
| `TextureTools` | 2 | `import_file` (por Interchange) y tamaño | [C] `ET/texture.py:15-31` |
| `DataTableTools` | 10 | Crear, **importar de archivo**, esquema, filas | [C] `ET/data_table.py` |
| `CurveTableTools`, `StringTableTools`, `DataAssetTools` | 9, 8, 1 | Tablas de curvas y de texto (con importación de archivo); crear `DataAsset` de una clase | [C] `ET/curve_table.py`, `string_table.py`, `data_asset.py:16` |
| `PrimitiveTools` | 4 | Cubo, esfera, cilindro, cono | [C] `ET/primitive.py` |
| `ProgrammaticToolset` | 2 | `get_execution_environment` y `execute_tool_script`: un guion Python que encadena llamadas a herramientas en una sola ida y vuelta | [C] `ET/programmatic.py:885-906` |
| `EditorAppToolset` (C++) | 21 | Buscar CVars, capturas (`CaptureViewport`, `CaptureEditorImage`, `CaptureAssetImage`), selección, cámara del visor, navegador de contenido, abrir editores de asset, `StartPIE`, `StopPIE`, `IsPIERunning` | [C] `TS/EditorToolset/Source/EditorToolset/Private/EditorAppToolset.h:207-379` |
| `LogsToolset` (C++) | 4 o 5 | Leer entradas del registro, categorías, verbosidad, ruta del archivo de registro | [C] `TS/EditorToolset/Source/EditorToolset/Private/LogsToolset.h` |
| `AgentSkillToolset` | 3 o más | `ListSkills`, `GetSkills` y creación de «Agent Skills» del proyecto (instrucciones guardadas en el proyecto) | [C] `TR/Source/ToolsetRegistry/Public/ToolsetRegistry/AgentSkill.h:58-80` |

### 3.2 Los demás toolsets

| Toolset | En `AllToolsets` | N.º | Qué permite | Archivo |
|---|---|---|---|---|
| `AutomationTestToolset` | sí | 7 | `DiscoverTests`, `ListTests`, `RunTests`, `RunTestsByFilter`, `GetTestResults`, `GetTestStatus`, `StopTests`: las mismas pruebas de Automation que el Session Frontend, dentro del editor abierto | [C] `TS/AutomationTestToolset/Source/AutomationTestToolset/Public/AutomationTestToolset.h:11-92` |
| `LiveCodingToolset` | **no** | 1 | `CompileLiveCoding`: lanza Live Coding, espera al final y devuelve estado, salida y diagnósticos de MSVC | [C] `TS/LiveCodingToolset/Source/LiveCodingToolset/Public/LiveCodingToolset.h:23-27`; `.../Private/LiveCodingToolset.cpp:101-173` |
| `ConfigSettingsToolset` | sí | 8 | Listar contenedores («Editor», «Project»), categorías y secciones; leer esquema y valores; `SetSectionProperties`, `SaveSection`, `ResetSectionToDefaults` | [C] `TS/ConfigSettingsToolset/Source/ConfigSettingsToolset/Private/ConfigSettingsToolset.h` |
| `UMGToolSet` | sí | 23 | Crear Widget Blueprint, añadir, mover, renombrar y envolver widgets, ranuras con nombre, enlazar eventos, compilar | [C] `TS/UMGToolSet/Source/UMGToolSet/Private/UMGToolSet.h` |
| `MVVMToolset` | **no** | 9 | ViewModels y enlaces de vista | [C] `TS/MVVMToolset/Source/MVVMToolset/Private/MVVMToolset/MVVMToolset.h` |
| `NiagaraToolsets` | sí | unas 56 | Crear sistema; emisores, renderizadores, módulos, variables de usuario; leer esquemas y topología; estado de compilación y arreglos de la pila | [C] `TS/NiagaraToolsets/Source/NiagaraToolsets/Private/NiagaraToolset_*.h` |
| `PCGToolset` | sí | 31 | Crear grafo PCG, parámetros, nodos y conexiones, subgrafos, `SpawnGraphInstance` (volumen PCG en la escena), `ExecuteGraphInstance`, `DrawSpline`, `RunPCGInstantGraph` | [C] `TS/PCGToolset/Source/PCGToolset/Public/PCGToolset.h:100-120`, `PCGSpatialToolset.h:15-23` |
| `SlateInspectorToolset` | sí | 14 | Automatizar la interfaz del editor: `Snapshot`, `Screenshot`, `Click`, `Hover`, `Type`, `PressKey`, `SelectOption`, `Drag`, `WaitFor`, `FillForm` | [C] `TS/SlateInspectorToolset/Source/SlateInspectorToolset/Public/SlateInspectorToolset.h` |
| `PluginToolset` | sí | 17 | Listar, crear, activar plugins; dependencias | [C] `TS/PluginToolset/Source/PluginToolset/Private/PluginToolset.h` |
| `GameplayTagsToolset` | sí | 6 | Listar, añadir, quitar, renombrar tags | [C] `TS/GameplayTagsToolset/...` |
| `PhysicsToolsets` | sí | 17 | Physics assets: cuerpos, formas, restricciones | [C] `TS/PhysicsToolsets/...` |
| `AnimationAssistantToolset` | sí | más de 300 | Sequencer (140), Control Rig, keyframes, importar y exportar | [C] `TS/AnimationAssistantToolset/Content/Python/animation_toolset/toolsets/` |
| `AIModuleToolset`, `StateTreeToolset`, `WorldConditionsToolset` | sí | 7, 9, 2 | Behavior Trees; inspección de State Trees y condiciones | [C] `TS/<nombre>/` |
| `GASToolsets`, `GameFeaturesToolset`, `DataRegistryToolset`, `ConversationToolset`, `DataflowAgent`, `SemanticSearchToolset`, `MCPClientToolset` | sí | varios | GAS, Game Features, Data Registries, conversaciones, Dataflow, búsqueda semántica de assets, y un adaptador para que el motor sea cliente de otros MCP | [C] `TS/<nombre>/` |

### 3.3 Lo que el MCP del 5.8.4 **no** puede hacer

| Límite | Fuente |
|---|---|
| **No ejecuta Python arbitrario.** `execute_tool_script` corre en un recinto: solo importa `json`, `math`, `datetime`, `copy`, `re`, `time`; no hay `import unreal`; `open` solo lee dentro del proyecto; `exec`, `eval` y `compile` están quitados. Solo sirve para encadenar herramientas. (El README del plugin dice «arbitrary Python»: no es lo que hace el código local.) | [C] `ET/programmatic.py:51-76, 344-386, 696-705`; [W] lo confirma un usuario del foro, 7 sep 2026 https://forums.unrealengine.com/t/local-llms-i-ve-tested-for-unreal-engine-5-8-epic-mcp/2763362 |
| No hay herramienta para ejecutar órdenes de consola ni para fijar CVars (solo `SearchCVars`). | [C] lista completa en `EditorAppToolset.h:207-379`; búsqueda sin resultados de «ConsoleCommand» en `ET/` |
| No hace una compilación completa de C++: solo Live Coding, y solo si está activado para la sesión. | [C] `LiveCodingToolset.cpp:106-116` |
| No cocina, no empaqueta, no lanza UAT. | [C] no hay ninguna herramienta así en el inventario de `TS/` |
| No opera el control de versiones (solo consulta `is_checked_out`). | [C] `ET/asset.py`, `ET/scene.py:464-467` |
| No hay toolset de paisaje, follaje, construcción de iluminación, Movie Render Queue ni audio (MetaSounds). Las luces, el posprocesado y la niebla sí se pueden crear y ajustar por la vía genérica (`add_to_scene_from_class` + `ObjectTools.set_properties`). | [C] inventario de `TS/`; `ET/scene.py:102-123`, `ET/object.py:81-94` |
| `SceneTools` no crea un nivel nuevo: carga uno existente y se niega si tiene cambios sin guardar. | [C] `ET/scene.py:28-41` |
| `read_file` y `write_file` solo tocan `/Game/`, el `Content/` de un plugin activo o `Saved/`, y solo `.txt`, `.json`, `.csv`, `.html`, `.py`, `.md`. No sirven para editar C++. | [C] `ET/asset.py:522, 529-531` |
| Las imágenes llegan como base64 dentro de texto (ver 2.6). | [C] |
| El resultado de un guion es un diccionario estricto: `.get(clave, defecto)` lanza `TypeError`. | [C] `ET/programmatic.py:208-213` |
| Sin editor abierto no hay MCP. En 5.8.4 **no viene** el proxy que mantiene la sesión mientras el editor reinicia (`Extras/Proxy` no existe), ni la herramienta `execute_python`, ni los metadatos de instancia, ni el protocolo 2026-07-28 que el plugin 3.1.2 ya documenta para motores más nuevos. | [C] no existe `ENG/Plugins/Experimental/ModelContextProtocol/Extras`; búsqueda sin resultados de `execute_python`, `com.epicgames.unrealengine`, `server/discover` en `MCP`, `TR`, `TS`; [C] `PLG/skills/unreal-mcp/references/operations.md:46-47` |

---

## 4. El plugin de Epic para Claude Code

Repositorio: https://github.com/EpicGames/unreal-engine-skills-for-claude-code-plugin (MIT, creado el 8 jun 2026, último commit 23 oct 2026, unas 1 970 estrellas). [C] `gh api`. La copia local (3.1.2) coincide con el último commit `0e27bde`. [C]

| Pregunta | Respuesta | Fuente |
|---|---|---|
| Qué instala | Tres skills y un hook. **No instala ningún servidor MCP ni ningún `.mcp.json`**: el servidor es el del motor. | [C] `PLG/.claude-plugin/plugin.json`; `PLG/README.md:72` |
| Skill `unreal-mcp` | Cómo descubrir y llamar herramientas (`list_toolsets`, `describe_toolset`, `call_tool`), reglas de seguridad (guardar antes y después, esperar compilaciones, serializar llamadas dependientes, comprobar el resultado, cuidado con PIE) y consultar los «Agent Skills» del proyecto | [C] `PLG/skills/unreal-mcp/SKILL.md:14-46` |
| Skill `create-toolset` | Cómo escribir un toolset propio en C++ o Python | [C] `PLG/skills/create-toolset/SKILL.md` |
| Skill `unreal-skill` | Cómo escribir un «Agent Skill» registrado en el motor | [C] `PLG/skills/unreal-skill/SKILL.md` |
| Qué exige | Editor con `ModelContextProtocol` y `AllToolsets` activos; editor abierto con el servidor arrancado; `bash` en el PATH para el hook (en Windows, Git Bash o WSL) | [C] `PLG/README.md:15-28` |
| Hook de inicio de sesión | En `startup`, `resume` y `clear` ejecuta `bash hooks/unreal-context.sh` con 5 s de límite. Sube desde el directorio de trabajo buscando un `*.uproject` o `GenerateProjectFiles.*`. Si no encuentra nada, sale sin decir nada. Si lo encuentra, inyecta una nota corta: que es un proyecto de Unreal, el nombre del `.uproject`, que se prefieran las convenciones de Unreal, que se use el skill `unreal-mcp`, y si hay o no `.mcp.json` en esa raíz. No toca archivos ni red. | [C] `PLG/hooks/hooks.json`; `PLG/hooks/unreal-context.sh:13-84` |
| Instalación de equipo | `"enabledPlugins": {"unreal-engine-skills-for-claude-code@claude-plugins-official": true}` en `.claude/settings.json` | [C] `PLG/README.md:50-58` |
| Avisos del propio plugin | «Localhost is not a trust boundary»; con `--dangerously-skip-permissions` el agente puede cambiar mucho estado sin más permiso; guardar y confirmar en git antes de una sesión larga | [C] `PLG/README.md:84-94` |

**Consecuencias [D]:** hoy, en el repositorio de Godot, el hook no hace nada (no hay `.uproject`). Solo mira hacia arriba: si el `.uproject` queda en una subcarpeta y la sesión arranca en la raíz, tampoco se dispara.

---

## 5. Python del editor sin interfaz

| Vía | Cómo | Para qué sirve | Fuente |
|---|---|---|---|
| Commandlet | `UnrealEditor-Cmd.exe <proyecto.uproject> -run=pythonscript -script="<archivo.py o código>"` | Guiones reproducibles que crean o modifican assets y salen. Devuelve 0 si fue bien y -1 si el guion dio error; marca la ejecución como desatendida; fuerza Python aunque el proyecto no lo tenga activado. | [C] `ENG/Plugins/Experimental/PythonScriptPlugin/Source/PythonScriptPlugin/Private/PythonScriptCommandlet.cpp:20, 43, 63-73` |
| Editor completo | `UnrealEditor.exe <proyecto> -ExecutePythonScript="<archivo.py args>"` | Cuando el guion necesita el editor entero cargado; el propio código dice que por eso no es un commandlet | [C] `.../Private/EditorUtilities/EditorPythonExecuter.cpp:147`; `EditorPythonExecuter.h:7-11` |
| Ejecución remota | Ajuste `bRemoteExecution` (UDP multidifusión) | Mandar Python a un editor abierto desde fuera. Es la vía que usan varios MCP de terceros. | [C] `.../Private/PythonScriptPluginSettings.h:126-136` |
| Dentro del MCP | Un toolset Python propio del proyecto | Exponer al agente funciones `unreal` propias, ya que `execute_tool_script` no deja | [C] apartado 2.6, punto 5 |

Notas: el plugin de Python está desactivado por defecto y es beta, pero `ToolsetRegistry` lo arrastra. [C] `PythonScriptPlugin.uplugin:13-15`; `TR/ToolsetRegistry.uplugin`. Python se desactiva solo en los commandlets `Cook`, `CookShaders` y `GatherText`. [C] `ENG/Config/BaseEditor.ini:30-34`. Los interruptores `-ForceEnablePython`, `-EnablePython` y `-DisablePython` existen. [C] `PythonScriptPlugin.cpp:110-152`

---

## 6. Pruebas

| Tipo | Qué es | Cómo se lanza | Fuente |
|---|---|---|---|
| Automation (C++) | Pruebas registradas en el motor (`IMPLEMENT_SIMPLE_AUTOMATION_TEST` y similares) | `UnrealEditor-Cmd.exe <proyecto> -ExecCmds="Automation RunTests <filtro>; Quit" -unattended -nullrhi -nosplash -log -ReportExportPath=<carpeta>` | [C] órdenes `RunTests`, `RunFilter`, `RunAll`, `List`, `Quit`: `ENG/Source/Developer/AutomationController/Private/AutomationCommandline.cpp:610, 688, 726, 782-797`; [C] `-ReportExportPath=`: `AutomationControllerManager.cpp:233`; [C] `-testexit=`: `ENG/Source/Runtime/Launch/Private/LaunchEngineLoop.cpp:397-421` |
| CQTest | Marco de pruebas más cómodo sobre Automation; es un módulo del motor | Igual que Automation | [C] `ENG/Source/Developer/CQTest`; `ENG/Plugins/Tests/CQTest/CQTest.uplugin` |
| Desde el MCP | Las mismas pruebas, en el editor abierto, sin arrancar otro proceso | `AutomationTestToolset.RunTestsByFilter` | [C] apartado 3.2 |
| Funcionales | Actores `AFunctionalTest` colocados en un mapa de prueba; corren jugando el mapa | Como Automation, con filtro `Project.Functional Tests` | [C] `ENG/Source/Developer/FunctionalTesting/Classes/FunctionalTest.h:249` |
| De capturas | `AScreenshotFunctionalTest` y la comparación de `ScreenShotComparison` | Necesitan renderizar: **no valen con `-nullrhi`** | [C] `ENG/Source/Developer/FunctionalTesting/Classes/ScreenshotFunctionalTest.h`; `ENG/Source/Developer/ScreenShotComparison` |
| De bajo nivel | Ejecutables de prueba con Catch2, sin motor completo | Target propio de pruebas | [C] existe `ENG/Source/Developer/LowLevelTestsRunner` |

`-unattended` (o estar en pruebas de Automation) hace que `FApp::IsUnattended()` sea cierto. [C] `ENG/Source/Runtime/Core/Private/Misc/App.cpp:274-279`. `-RenderOffScreen` existe para renderizar sin ventana visible. [C] `LaunchEngineLoop.cpp:3111`

**Para el port [D]:** las 106 pruebas de GDScript son en su mayoría de lógica; su sitio natural es Automation o CQTest con `-nullrhi`. La «verify» equivalente sería una sola orden de Automation. Las pruebas visuales (capturas comparables con la referencia) necesitan GPU y por tanto van en serie.

---

## 7. Compilar sin Visual Studio

| Hecho | Fuente |
|---|---|
| `Build.bat <Target> <Plataforma> <Configuración> [args de UBT]`. Para el editor del juego: `Build.bat TheFourEditor Win64 Development -Project="<ruta>/TheFour.uproject" -WaitMutex`. | [C] forma de los argumentos: `ENG/Build/BatchFiles/Build.bat:9-12`; [W] forma habitual con `-Project` y `-WaitMutex` vista en registros del foro |
| `Build.bat` se bloquea a sí mismo: una segunda llamada espera a que acabe la primera («is already running, waiting»). No hay dos compilaciones a la vez. | [C] `Build.bat:16-33` |
| Empaquetar: `RunUAT.bat BuildCookRun -project=... -platform=Win64 -clientconfig=... -build -cook -stage -pak -archive`. | [C] existe `ENG/Build/BatchFiles/RunUAT.bat` y `AutomationTool.exe`; los parámetros son los habituales, sin ejecutar |
| Con motor instalado solo se compilan los módulos del proyecto; el motor ya viene compilado. | [C] `InstalledBuild.txt`; [D] |
| Con el editor abierto, una compilación completa no puede sustituir las DLL cargadas: para eso está Live Coding. | [D] conocimiento general, sin ejecutar |
| Unreal Build Accelerator viene en el motor. | [C] `ENG/Binaries/Win64/UnrealBuildAccelerator/x64` |

**Tiempos esperables: no hay cifra comprobada.** No se compiló nada y la web no da una medida fiable para un 5900X. Estimación orientativa [D], a sustituir por medidas de la prueba de concepto: primera compilación de un módulo de juego pequeño, de 1 a 4 minutos; cambio en un `.cpp`, de 10 a 40 segundos; cambio en una cabecera muy incluida, de 1 a 3 minutos; parche de Live Coding, de 5 a 20 segundos; primer arranque del editor con shaders sin caché, varios minutos.

---

## 8. Live Coding

| Hecho | Fuente |
|---|---|
| En la configuración base del motor viene **desactivado** (`bEnabled=False`), con `Startup=AutomaticButHidden`, `bEnableReinstancing=True`, `bAutomaticallyCompileNewClasses=True`. Es un ajuste por usuario. | [C] `ENG/Config/BaseEditorPerProjectUserSettings.ini:983-987`; `ENG/Source/Developer/Windows/LiveCoding/Private/LiveCodingSettings.h:17-45` |
| Se puede forzar por línea de órdenes con `-LiveCoding` o `-LiveCoding=true`. | [C] `ENG/Source/Developer/Windows/LiveCoding/Private/LiveCodingModule.cpp:490-495` |
| No arranca solo si la sesión es desatendida (`-unattended`). | [C] `LiveCodingModule.cpp:501` |
| Solo existe en Windows (el módulo vive en `Developer/Windows`). | [C] ruta del módulo |
| La herramienta del MCP devuelve `Success`, `NoChanges`, `Failure`, `CompileStillActive`, `NotStarted`, `Cancelled` o `InProgress`, más la salida y las líneas de error de `ENG/Programs/UnrealBuildTool/Log.txt`. | [C] `LiveCodingToolset.cpp:56-98, 132-173` |
| Límites conocidos: cambios en cabeceras que alteran la reflexión (clases nuevas, `UPROPERTY` nuevas, cambios de tamaño) dependen del «reinstancing» y son frágiles; los valores por defecto de constructores no se reaplican a lo ya guardado. Para eso, cerrar el editor y compilar completo. | [D] conocimiento general, sin comprobar aquí |

---

## 9. Caché de datos derivados (Zen) y varios procesos

| Hecho | Fuente |
|---|---|
| El motor lanza solo un `zenserver` local (`[Zen] AutoLaunch=true`), con datos en la carpeta de usuario del motor y puerto 8558 para conectarse a uno existente. | [C] `ENG/Config/BaseEngine.ini:2719-2734` |
| En motor instalado el grafo de caché es `ProjectPak, InstalledProjectPak, EnginePak, EnterprisePak, ZenLocal, Local=InstalledLocal, ZenShared, Shared, Cloud`; el `Local` instalado va a la carpeta de usuario, no al proyecto. | [C] `BaseEngine.ini:2770-2772, 2866-2867` |
| La caché es por máquina y la comparten todos los procesos del motor: un commandlet y el editor aprovechan los mismos shaders compilados. | [D] a partir de lo anterior |
| El compilador de shaders usa procesos trabajadores y reserva hilos (`NumUnusedShaderCompilingThreads=3`, 50 % por encima de cierto umbral de núcleos). | [C] `BaseEngine.ini:2178-2191` |
| Dos editores a la vez chocan en el puerto 8000 del MCP: el segundo no puede enlazarlo y el cliente hablaría con el primero. Si alguna vez hiciera falta, un puerto fijo por proyecto. | [C] `PLG/skills/unreal-mcp/references/setup.md:123-130` |
| Un commandlet no arranca el MCP por ajuste, justo para no competir con el editor abierto. | [C] `ModelContextProtocolSettings.cpp:50-58` |
| El MCP acepta peticiones concurrentes, pero el orden de llegada no garantiza el de ejecución; las mutaciones sobre el mismo asset deben ir en serie. Varios agentes pueden usar un editor, con riesgo de pisarse. | [C] `PLG/skills/unreal-mcp/SKILL.md:32` |

**Para el port [D]:** con un solo editor a la vez, el reparto natural es: muchos agentes editan C++ y datos en texto en paralelo (archivos disjuntos); un único agente a la vez habla con el editor por MCP; las compilaciones y las pruebas con GPU van en serie; los guiones de assets sin interfaz corren con el editor cerrado o se ejecutan dentro del editor abierto, nunca los dos sobre los mismos paquetes.

---

## 10. Experiencias publicadas en 2026

Todo este apartado es [W]. Son relatos de usuarios y artículos; varios son de empresas que venden un producto rival.

| Qué | Fuente y fecha |
|---|---|
| UE 5.8 salió el 17 jun 2026 con el MCP como experimental. | https://www.unrealengine.com/news/unreal-engine-5-8-is-now-available ; https://x.com/UnrealEngine/status/2067251500900839735 |
| **Sin señal de «listo».** Al arrancar, `list_toolsets` devolvió 1 toolset y más tarde 52; no hay aviso de que el registro haya terminado. | Foro de Epic, 23 jun 2026: https://forums.unrealengine.com/t/unreal-mcp-codex-issue-analysis-report/2730883 |
| **Fallos devueltos como éxito.** De 1 477 llamadas, 1 dio error formal; las demás fallidas volvieron «Ok» con el error en el texto. Hay que leer cada resultado. | Mismo hilo |
| No se pudo reapuntar un nodo de llamada a función de un Blueprint (`FunctionReference` no se deja leer ni escribir). Edición fina de grafos existentes: frágil. | Mismo hilo |
| En proyectos grandes, el resultado de la herramienta puede venir enterrado en miles de líneas de errores de Blueprint, y la escritura sí se aplicó: reintentar a ciegas duplica cambios. (Caso de UEFN, 22 sep 2026.) | https://forums.unrealengine.com/t/mcp-tool-calls-return-blueprint-runtime-errors-instead-of-the-tools-return-value/2833175 |
| `execute_tool_script` funciona bien para agrupar: 8 operaciones en una llamada. Consejos: pasar siempre `toolset_name` y `tool_name` sin puntos, saltarse el descubrimiento cuando ya se conoce la herramienta, enviar transformaciones completas, no inventar `refPath`. | Foro de Epic, 7 sep 2026: https://forums.unrealengine.com/t/local-llms-i-ve-tested-for-unreal-engine-5-8-epic-mcp/2763362 |
| Las descripciones de algunos toolsets son muy largas e inflan el contexto. | Mismo hilo |
| Claude Code rinde bien en C++ de Unreal y mal con Blueprints y assets binarios (no los lee del `.uasset`). Errores típicos del C++ generado: funciones del motor inventadas, macros de reflexión olvidadas, módulos que faltan en el `.Build.cs`. | https://ludusengine.com/blog/claude-code-for-unreal-engine (vendedor); https://dreamawakelabs.com/insights/unreal-engine-cpp-blueprints-claude-code (actualizado oct 2026) |
| Cada sesión empieza en frío y descubre el proyecto llamada a llamada. | https://ludusengine.com/blog/unreal-mcp-plugin-ue5-8-setup (vendedor, 13 sep 2026) |
| Servidores MCP de terceros activos: `ChiR24/Unreal_mcp` (MIT, activo, 13 nov 2026), `kevinpbuckley/VibeUE` (MIT, activo, 12 nov 2026). Parados: `chongdashu/unreal-mcp` (abr 2025), `runreal/unreal-mcp` (jun 2025, por ejecución remota de Python), `Natfii/UnrealClaude` (jun 2026, para 5.7). | [C] `gh api` de cada repositorio |

No encontré ningún relato publicado de un port completo de un juego hecho por agentes con el MCP de Epic.

---

## 11. Guion en texto: alternativas a C++

| Opción | Estado con 5.8 | Encaja | Fuente |
|---|---|---|---|
| **C++ del motor** | Nativo. Lo que mejor escriben los agentes. | Sí | apartado 10 |
| **AngelScript (Hazelight)** | Es un **fork del motor**: exige acceso al código de Epic en GitHub, compilar el motor entero y no admite plugins precompilados. Usado en producción (It Takes Two, Split Fiction). No pude ver a qué versión del motor va el fork. | No, hoy: el motor es instalado, la cuenta de `gh` no tiene acceso a Epic y compilar el motor rompe la velocidad | [W] https://angelscript.hazelight.se/getting-started/installation/ ; https://angelscript.hazelight.se/project/development-status/ ; [C] 404 de `gh` |
| AngelScript como plugin (UNREANGEL, UE-Angelscript) | Probado solo en 5.4; sin commits desde jun 2025; 6 y 18 estrellas | No | [C] `gh api repos/WillGordon9999/UNREANGEL`, `.../UE-Angelscript` |
| **UnrealSharp (C#)** | Declara 5.6 a 5.8 y .NET 10.0.5 o superior; MIT; beta; Windows y macOS; recarga en caliente; activo (commit del 10 nov 2026); 4 juegos en Steam listados | Posible, pero es una capa beta más entre el agente y el motor | [C] README y `.uplugin` de https://github.com/UnrealSharp/UnrealSharp leídos con `gh api` |
| **Verse** | El motor local trae el compilador (`UnrealEditor-VerseCompiler.dll`, `Source/Runtime/VerseCompiler`, `Solaris`), pero no hay flujo documentado para un proyecto normal de 5.8. Epic lo anuncia como modelo de gameplay de UE6, con acceso anticipado previsto para finales de 2027. | No | [C] `ENG/Binaries/Win64`, `ENG/Source/Runtime`; [W] https://www.unrealengine.com/news/state-of-unreal-2026-top-news-from-the-show |
| UnLua (Tencent) | Última versión 2.3.6, de nov 2023; sin commits de código desde entonces | No | [C] `gh api repos/Tencent/UnLua` |
| puerts (TypeScript, Tencent) | Activo, pero las versiones recientes son de Unity | No evaluado | [C] `gh api repos/Tencent/puerts` |
| Python del editor | Solo editor; no corre en el juego | Para guiones de assets, no para gameplay | apartado 5 |

**Lectura [D]:** para un juego que se quiere vender pronto, hecho por agentes que editan texto, C++ es la única opción sin dependencias frágiles. Lo que el autor ajusta a menudo (cifras, tablas) puede ir en datos de texto (`.ini`, CSV o JSON importados a DataTables, que el MCP sabe importar).

---

## 12. Repositorio: Git LFS, `.gitignore` y qué se versiona

| Hecho | Fuente |
|---|---|
| La plantilla estándar ignora `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/`, `Build/` (salvo excepciones), `.vs/`, `*.sln`, `*_BuiltData.uasset` y los mismos directorios dentro de `Plugins/`. | [W] https://raw.githubusercontent.com/github/gitignore/main/UnrealEngine.gitignore |
| Se versionan: `*.uproject`, `Source/`, `Config/`, `Content/`, `Plugins/<propios>/` (sin `Binaries` ni `Intermediate`) y los guiones que generan assets. | [D] complemento de lo anterior |
| `Saved/Config/WindowsEditor/EditorPerProjectUserSettings.ini` (donde vive `bAutoStartServer` y el ajuste de Live Coding) queda fuera de git: cada máquina lo fija, o se pasa por línea de órdenes. | [C] `ModelContextProtocolSettings.h:17`; `LiveCodingSettings.h:17` |
| `.uasset` y `.umap` son binarios: no se fusionan ni se leen en un diff. Con LFS, los patrones habituales son `*.uasset`, `*.umap` y los formatos fuente pesados (`*.fbx`, `*.wav`, `*.png`, `*.exr`...). | [D] conocimiento general |
| El repositorio actual no tiene ninguna regla de LFS. | [C] `E:/Projects/The Four/.gitattributes` |
| Los niveles con actores externos guardan cada actor en su propio paquete: muchos archivos pequeños, pero menos choques entre agentes. | [C] `ET/scene.py:445-462` (el toolset distingue actores externos) |

**Para el port [D]:** cuanto más salga de C++ y de guiones reproducibles, menos binarios hay que versionar. Las plantas generadas por código pueden construirse en tiempo de ejecución desde C++ (como hoy en Godot), sin `.umap` gigantes. Lo que un guion regenera de forma determinista (materiales, instancias, importaciones) puede incluso quedar fuera de git si el guion y sus fuentes están dentro; decidirlo es cosa del director.

---

## 13. Lo que esto condiciona del diseño del port

1. **Antes de nada, probar que 5.8.4 compila con MSVC 14.51.** Es barato y bloquea todo lo demás.
2. **`.uproject` con tres plugins de agente:** `ModelContextProtocol`, `AllToolsets`, `LiveCodingToolset`.
3. **Dónde va el `.uproject`** decide si el hook del plugin se dispara y dónde cae el `.mcp.json`.
4. **El MCP no ejecuta Python libre.** Para automatizar lo que los toolsets no cubren hay tres salidas: un toolset propio del proyecto (C++ o Python), guiones con `-run=pythonscript`, o más C++.
5. **Las capturas por MCP llegan en base64 como texto.** Para juzgar visuales conviene una vía que deje un PNG en disco (un toolset propio o una prueba de capturas) y leer el archivo.
6. **Cada llamada al MCP se comprueba leyendo el resultado y, si muta, releyendo el estado.** No reintentar a ciegas.
7. **Un solo agente a la vez con el editor;** el resto, texto en paralelo.
8. **La «verify» del port** puede ser una orden de Automation con `-nullrhi`; lo visual va aparte y en serie.
9. **Live Coding para el bucle corto, compilación completa con el editor cerrado para cambios de reflexión.** Hay que activarlo (viene apagado) o pasar `-LiveCoding`.
10. **El aviso del EULA (sección 6(e))** sobre enviar contenido del motor a un LLM lo debe conocer el autor.

---

## Sin comprobar

- Que un módulo de 5.8.4 compile con MSVC 14.51.36231 y Windows SDK 10.0.26100. Solo consta que UBT no lo veta.
- Todos los tiempos de compilación, de arranque del editor y de compilación de shaders en esta máquina.
- Que el servidor MCP funcione de verdad con Claude Code aquí: no se abrió el editor. En particular: cuánto tarda en registrar los toolsets, cómo muestra Claude Code una captura en base64 y cuántos tokens cuesta, y si `list_toolsets` da los 52 toolsets que cita el foro.
- Si el MCP puede servir desde un editor sin ventana (`-RenderOffScreen` o `-nullrhi`) o desde un commandlet con `-ModelContextProtocolStartServer`.
- El valor efectivo de Live Coding en un proyecto nuevo (el `.ini` base dice desactivado) y su comportamiento real con cambios de cabecera en 5.8.4.
- Que las pruebas de bajo nivel (Catch2) se puedan compilar con un motor instalado.
- Los parámetros exactos de `Build.bat` y `RunUAT.bat BuildCookRun` para este proyecto: se dan en su forma habitual, sin ejecutar.
- La documentación oficial de Epic sobre el MCP (dev.epicgames.com no se pudo leer): las frases «experimental» y «no pensado para uso remoto» vienen de terceros y del propio código.
- A qué versión del motor va el fork de AngelScript de Hazelight (el repositorio no es visible sin acceso a Epic).
- Que UnrealSharp funcione de verdad con 5.8.4 y con el .NET 10.0.403 instalado (su README pide 10.0.5 o superior del runtime; no se contrastó la numeración).
- Si existe un formato de asset en texto utilizable: hay un ajuste experimental `bTextAssetFormatSupport` (`ENG/Source/Editor/UnrealEd/Classes/Settings/EditorExperimentalSettings.h:128`), pero no se miró su estado.
- Las cuotas y el coste de Git LFS en el plan de GitHub del autor.
- Los relatos del apartado 10: son de terceros, algunos con interés comercial, y varios sobre versiones anteriores a 5.8.4 (no consta qué arreglaron los parches 5.8.1 a 5.8.4).
- Los límites de Live Coding y el bloqueo de DLL con el editor abierto: conocimiento general, no leído en el código.
