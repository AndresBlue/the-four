> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: estructura del proyecto, guardado, empaquetado y Steam

15 de noviembre de 2026. Solo plan: no se ha ejecutado ni compilado nada para escribirlo.

Abreviaturas: `GD:` = `E:/Projects/The Four/`. `UE:` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine/`. `<P>` = `E:/Projects/TheFourUE` (lo fija `diseno/metodo.md` D1). [M] = leído hoy en el motor instalado. [G] = leído hoy en el código de Godot. [F] = de una ficha o informe, sin recomprobar. [D] = deducción.

Este documento no repite lo que ya fija `diseno/metodo.md` (carpetas, órdenes de `Tools/ue.ps1`, capas de pruebas, git y LFS): lo cita y añade lo que falta del dominio.

## 1. Qué hay hoy en Godot

- **Proyecto.** `GD:project.godot`: nombre «THE FOUR — Hotel» (:17), versión 1.3.0 (:18), ajustes de render sobrescritos por `user://renderer.cfg` (:20), AppID de Steam 480 (:73). Etiquetas de git `v1.0.0` a `v1.3.0` [G]. `GD:docs/CHANGELOG.md` tiene un apartado por versión.
- **Servicios sin autoloads.** Nodos bajo `Services` en `GD:game/app/hotel.tscn`; `Discoveries` y `Records` los crea `GD:game/app/hotel_main.gd:225-232` [F `fichas/servicios.md`].
- **Guardado.** Cuatro JSON bajo `user://` más un binario [G]:

| Archivo | Quién | Ruta:línea |
|---|---|---|
| `hotel_settings.json` | `settings_service.gd` (507 líneas) | `GD:game/services/settings_service.gd:78` |
| `records.json` (VERSION 2) | `records_service.gd` (402) y `run_score.gd` (248) | `GD:game/services/records_service.gd:20` |
| `discoveries.json` | `discovery_service.gd` (28) | `GD:game/services/discovery_service.gd:6` |
| `hotel_checkpoint.json` | `game_session.gd` (337) | `GD:game/services/game_session.gd:63` |
| `hotel_checkpoint.state` (binario `store_var`, STATE_FORMAT 2, con `generator` y `seed`) | `game_session.gd`, `floor_save.gd` | `GD:game/services/game_session.gd:219-252` |
| `renderer.cfg` | elección de renderizador al arrancar | `GD:game/services/settings_service.gd:90` |

- **Escritura atómica.** `GD:game/services/save_file.gd` (36 líneas): escribe en `.tmp`, relee para confirmar, renombra; al leer recupera un `.tmp` huérfano y aparta como `.corrupt` lo que no se puede leer [G].
- **Perfil de prueba.** Con `--test-profile` o cuando se ejecuta un `.gd`, los cuatro archivos pasan a `user://test_hotel_<nombre>_*.json` (`GD:game/app/hotel_main.gd:195-231`) [G]. Viven en la misma carpeta que el perfil real, separados solo por el prefijo. El perfil real está en `%APPDATA%/Godot/app_userdata/THE FOUR — Hotel` (existe en esta máquina) [G].
- **Exportación.** `GD:exports/windows/`: `TheFour.exe` 109 MB, `TheFour.pck` 1 038 MB, dos DLL de Steam, dos `.bat`; 1,1 GB en total [G, medido hoy]. Hay un preset de macOS (`GD:export_presets.cfg:50-59`). Las versiones del ejecutable están vacías (`:36-37`).
- **Steam.** GodotSteam 4.22.1 (`GD:docs/DEVELOPMENT.md:75`). **El juego no tiene AppID propio**: usa 480 (Spacewar) «mientras se desarrolla» (`GD:docs/DEVELOPMENT.md:76`, `GD:game/net/steam_link.gd:30`), y los dieciocho logros esperan «cuando el juego tenga su AppID» (`GD:docs/PLAN.md:798-801`). Los logros se llaman `F<piso>_<ID>` (`GD:docs/DEVELOPMENT.md:77`). La sala lleva la cadena de protocolo (`GD:game/net/steam_link.gd:150, 221`).
- **Lanzadores.** 17 `.cmd` en la raíz y `GD:tools/export/` [G].
- **Hardware flojo.** Hay un perfil Compatibility (OpenGL) y un nivel Muy bajo (`GD:README.md:44`, `GD:docs/DEVELOPMENT.md:53`).

## 2. Cómo queda en Unreal

### 2.1 Proyecto y módulos

Nombre `TheFour`, carpeta `<P>`, `TheFour.uproject` en la raíz, repositorio nuevo (`diseno/metodo.md` §2.1 y D1). Sin espacios ni guion largo: el nombre del proyecto es también la carpeta del perfil del jugador (2.3).

| Módulo | Tipo | Qué lleva de este dominio |
|---|---|---|
| `FourCore` | Runtime, C++20 sin cabeceras de Unreal | Reglas de `records` y `run_score` sobre estructuras planas; números de versión de los formatos |
| `TheFour` | Runtime | Las clases de 2.2; sus pruebas en `Private/Tests/Platform/` |
| `TheFourRender` | Runtime | Nada de este dominio |
| `TheFourEditor` | Editor | Nada de este dominio. No viaja al juego (obligación de licencia, apartado 4 D9) |

Plugins propios del proyecto: ninguno. Plugins del motor de este dominio: `OnlineSubsystemSteam` (con Steamworks 1.64) y `SteamSockets` [F `briefs/ue58.md`]; existen en `UE:Plugins/Online/OnlineSubsystemSteam` y `UE:Plugins/Runtime/Steam/SteamSockets` [M]. Cuáles se activan lo decide el documento de red; aquí solo se fijan el AppID y el empaquetado.

**Content.** `Content/Gen/` (sale de guiones, fuera de git) y `Content/Hand/` (se espera vacío) [`diseno/metodo.md` §2.1]. Subcarpetas de `Gen`: `Maps/`, `Meshes/<Hotel|Office|Shared>/`, `Materials/`, `Textures/`, `Audio/`, `UI/`. Un único mapa de arranque, `L_Boot`, vacío: las plantas se generan en ejecución.

**Nombres.** C++: prefijos de Epic más `Four` (`UFourSettings`, `AFourCharacter`, `FFourSaveFile`). Assets: `SM_`, `M_`, `MI_`, `T_`, `SW_` (sonido), `WBP_`, `L_` (mapa). Sin tildes, espacios ni «—» en ninguna ruta. Pruebas: `TheFour.Platform.<Caso>`.

### 2.2 Clases (firmas, todas en `TheFour` salvo indicación)

| Clase | Base | Firmas |
|---|---|---|
| `FFourSaveFile` | funciones estáticas | `static bool Write(const FString& Path, const FString& Text)`; `static bool Read(const FString& Path, TSharedPtr<FJsonObject>& Out)`; mismo contrato que `save_file.gd`: `.tmp`, releer, `IFileManager::Move`, recuperar `.tmp`, apartar `.corrupt` |
| `UFourProfileSubsystem` | `UGameInstanceSubsystem` | `FString Dir() const`; `FString File(FName Name) const`; `bool IsTestProfile() const`. Resuelve la carpeta según 2.3 |
| `UFourSettings` | `UGameInstanceSubsystem` | `void Load()`; `bool Save()`; `void Apply()`; delegado `OnChanged`. Archivo `settings.json` |
| `UFourRecords` | `UGameInstanceSubsystem` | Envoltorio de `FourCore::FRecords` (tableros, hitos, rivales, eventos): `Load`, `Save`, `Commit(const FRunResult&)`. Archivo `records.json`, VERSION 3 |
| `UFourDiscoveries` | `UGameInstanceSubsystem` | `bool Has(FName)`, `void Add(FName)`. Archivo `discoveries.json` |
| `UFourCheckpoint` | `UGameInstanceSubsystem` | `bool WriteCheckpoint()`, `bool WriteState(const FFourFloorState&)`, `bool ReadState(int64 Seed, FFourFloorState& Out)`, `void Forget()`. Archivos `checkpoint.json` y `checkpoint_state.json` con `format`, `generator`, `seed` |
| `FFourGodotImport` | funciones estáticas | `static bool Run(const FString& GodotDir, const FString& ProfileDir)`: copia única de `records.json`, `discoveries.json` y parte de `hotel_settings.json` (2.4) |
| `FFourVersion` | funciones estáticas | `static FString Game()` (lee `ProjectVersion`), `static FString Label()` (lo que enseña el menú) |

Todo es C++ y JSON en texto. Ningún asset binario en este dominio.

### 2.3 Dónde vive el perfil y cómo no se toca el real

Hechos del motor [M]:
- Un ejecutable Shipping de escritorio cuenta como «instalado» (`UE:Source/Runtime/Core/Private/Misc/App.cpp:218-219`) y entonces guarda en la carpeta de usuario (`UE:Source/Runtime/Core/Private/Misc/Paths.cpp:183-191`): `ProjectUserDir()` es `%LOCALAPPDATA%/<nombre del proyecto>/` (`Paths.cpp:460-466`; `FOLDERID_LocalAppData` en `UE:Source/Runtime/Core/Private/Windows/WindowsPlatformProcess.cpp:1459-1471`). El perfil real del jugador queda en `%LOCALAPPDATA%/TheFour/Saved/`.
- El editor y `-game` lanzados desde el proyecto no son «instalados»: `ProjectUserDir()` es la carpeta del proyecto (`Paths.cpp:468-471`), es decir `<P>/Saved/`.
- `-UserDir=<carpeta>` sustituye `ProjectUserDir()` entero (`Paths.cpp:451-458`, `:1940-1948`).

Diseño:
- Carpeta del perfil: `<ProjectSavedDir>/Profile/`. Con `-FourProfile=<nombre>`: `<ProjectSavedDir>/Profiles/<nombre>/`.
- **Equivalente de `--test-profile`, dos barreras.** (1) `UFourProfileSubsystem` nunca devuelve `Profile/` si hay pruebas de Automation en curso, `-unattended`, `-nullrhi` o `-FourCapture=`: usa `Profiles/auto/` aunque no se pase `-FourProfile`. (2) `Tools/ue.ps1` añade `-UserDir=<P>/Saved/PackagedUser` siempre que lanza un ejecutable empaquetado, que es el único caso en que el motor miraría `%LOCALAPPDATA%/TheFour`.
- Regla para agentes: no se lanza ningún proceso del juego fuera de `Tools/ue.ps1`, y ninguna herramienta escribe en `%LOCALAPPDATA%/TheFour` ni en la carpeta de datos de Godot.

### 2.4 Migración del perfil de Godot

Al primer arranque sin `records.json` propio, y solo fuera del perfil de prueba, `FFourGodotImport::Run` lee `%APPDATA%/Godot/app_userdata/THE FOUR — Hotel/` y **copia**; no escribe ni borra nada allí. Deja en `records.json` la marca `imported_from` con la fecha.

| Dato | Se migra | Por qué |
|---|---|---|
| `records.json` (tableros, hitos y logros, rivales) | Sí, VERSION 2 a 3 | Es lo que el jugador ha ganado |
| `discoveries.json` | Sí | Ídem |
| `hotel_settings.json`: volúmenes, sensibilidad, dificultad, idioma | Sí | Valores sin motor |
| `hotel_settings.json`: teclas (códigos físicos de Godot), botones `JOY_*`, ventana, calidad, escalado | No | Son enumeraciones y niveles de Godot [F `fichas/servicios.md`]; el port tiene otros niveles (`diseno/render.md` D3) |
| `hotel_checkpoint.json` y `.state` (Continuar) | No | El binario es `store_var` de Variant y solo vale con el mismo `generator`; la partida a medias se pierde. Hay que decirlo en las notas de la versión |
| `renderer.cfg` | No | No existe el concepto |

## 3. Correspondencia pieza a pieza

| Godot | Unreal | Dónde |
|---|---|---|
| `project.godot` nombre y versión | `Config/DefaultGame.ini`, `[/Script/EngineSettings.GeneralProjectSettings]`: `ProjectName`, `ProjectVersion`, `CompanyName`, `ProjectDisplayedTitle` (`UE:Source/Runtime/EngineSettings/Classes/GeneralProjectSettings.h:20-64` [M]) | Datos |
| `user://` | `<ProjectSavedDir>/Profile/` | C++ |
| `save_file.gd` | `FFourSaveFile` | C++ |
| `--test-profile`, detección de `.gd` | `-FourProfile=`, guarda de Automation, `-UserDir=` en `ue.ps1` | C++ y guion |
| `settings_service.gd` | `UFourSettings`; la ventana y la calidad se aplican al motor desde aquí, sin guardar `GameUserSettings.ini` | C++ |
| `records_service.gd`, `run_score.gd` | `FourCore::FRecords`, `FourCore::FRunScore`, `UFourRecords` | C++ |
| `discovery_service.gd` | `UFourDiscoveries` | C++ |
| `game_session.gd` (checkpoint y estado) | `UFourCheckpoint`; el resto de la sesión es del documento de reglas | C++ |
| `renderer.cfg`, Compatibility | Desaparece (apartado 4 D7) | — |
| `steam/initialization/app_data/app_id=480` | `Config/DefaultEngine.ini`, `[OnlineSubsystemSteam]`: `SteamDevAppId=480`, `bRelaunchInSteam=false` (los lee `UE:Plugins/Online/OnlineSubsystemSteam/Source/Private/OnlineSubsystemSteam.cpp:106-116` [M]) | Datos |
| `export_presets.cfg`, `tools/godot.ps1`, `Exportar.cmd` | `Tools/ue.ps1 package` sobre `RunUAT BuildCookRun` | Guion |
| `TheFour.pck` | Contenedores pak e IoStore del empaquetado | Producto |
| Etiquetas `vX.Y.Z` y `docs/CHANGELOG.md` | Igual, en el repositorio nuevo, desde 2.0.0 | Texto |
| 17 `.cmd` | Subórdenes de `ue.ps1`; `.cmd` solo para Jugar, Verificar y Empaquetar | Guion |
| Preset de macOS | Fuera del port (apartado 8, pregunta 5) | — |

## 4. Decisiones

**D1. Archivos JSON propios, no `USaveGame`.** `USaveGame` escribe un binario en `Saved/SaveGames/<ranura>.sav` (`UE:Source/Runtime/Engine/Public/SaveGameSystem.h:169-171` [M]). Se descarta: la migración desde Godot pasa a ser copiar y subir una versión; los agentes y las pruebas leen y comparan texto; y se conserva tal cual el contrato de `save_file.gd` (no perder lo guardado con el disco lleno o un corte), que `USaveGame` no da por sí solo. Coste: escribir a mano campo por campo, igual que hoy.

**D2. El estado del piso también en JSON.** Hoy es binario porque lleva vectores y tablas por asiento. En el port va como JSON compacto para tener un solo formato. Si al medir pasa de 1 MB o tarda más de 5 ms cada 30 s, se cambia a `FArchive` con la misma cabecera (`format`, `generator`, `seed`).

**D3. Se migran récords, descubrimientos y los ajustes sin motor; Continuar no.** Alternativa descartada: leer el `store_var` de Godot desde C++ (hay que portar el formato binario de Variant para rescatar una partida a medias por jugador).

**D4. Perfil de prueba por construcción, no por disciplina.** En Godot basta olvidar `--test-profile` para tocar el perfil real; aquí las ejecuciones desatendidas no pueden resolver `Profile/`. Descartado: depender solo de `-UserDir` (un agente puede olvidarlo).

**D5. Nombre `TheFour`, versión 2.0.0.** La serie 1.x queda para Godot; así una etiqueta o un informe de fallo dicen de qué motor son. La versión vive solo en `ProjectVersion`, como hoy solo en `project.godot`.

**D6. Steam: una sola aplicación, ramas para convivir.** Hoy no hay AppID propio, así que no hay nada que conservar todavía: cuando el autor lo tenga, la rama por defecto lleva el juego vigente y una rama con contraseña el otro. Antes del relevo: por defecto Godot 1.3.x, rama `unreal` para el port. Después: por defecto Unreal 2.x, rama `godot` con la última 1.x para quien no pueda con el port. Las ramas se gestionan en la página Builds de Steamworks (https://partner.steamgames.com/doc/store/application/branches, leído hoy). Las dos versiones no juegan entre sí: la cadena de protocolo de la sala ya separa versiones (`GD:game/net/steam_link.gd:221`) y el port lleva la suya. Descartado: un AppID nuevo para el port (parte a los jugadores, sus amigos y sus logros).

**D7. No se conserva Compatibility ni Muy bajo.** Lo decide `diseno/render.md` D3: mínimo DX12 con Shader Model 6. La salida para el hardware flojo es la rama `godot`, no un segundo aspecto en Unreal.

**D8. Informes de fallos locales.** El empaquetado sin `-crashreporter` (el parámetro existe: `UE:Source/Programs/AutomationTool/AutomationUtils/ProjectParams.cs:1452` [M]) no lleva la ventana de Epic; el volcado y el registro quedan en `Saved/Crashes/` y `Saved/Logs/` del perfil. Los símbolos (`.pdb`) de cada versión se archivan fuera del paquete para leer los volcados. Descartado: Sentry, BugSplat y similares (piden cuenta y envían datos de jugadores a un tercero).

**D9. Shipping sin módulos de editor ni plugins de agente.** `ModelContextProtocol`, `AllToolsets` y `LiveCodingToolset` son solo de editor (`diseno/metodo.md` §2.2); `TheFourEditor` es de tipo Editor. La licencia prohíbe distribuirlos [F `briefs/experiencias.md:215`].

**D10. Sin instalador.** Se entrega la carpeta del empaquetado con `-prereqs` (`ProjectParams.cs:2472` [M]; el redistribuible está en `UE:Extras/Redist/en-us/vc_redist.x64.exe` [M]); Steam instala la carpeta.

### Obligaciones de la licencia además de la regalía [F `briefs/experiencias.md` §8, :199-215]

1. Formulario de lanzamiento a Epic antes de vender (unrealengine.com/release).
2. Informe por producto dentro de los 45 días siguientes a cada trimestre con ingresos sujetos a regalía; los trimestres por debajo de 10 000 USD están exentos de pago.
3. Dos avisos fijos de Unreal en los créditos; ningún derecho sobre logotipos de Epic.
4. El EULA del juego excluye garantías sobre el motor.
5. No distribuir el editor ni módulos de Developer o Editor.
6. No combinar el motor con contenido GPL, LGPL enlazada estáticamente ni CC BY-SA: el personaje `realistic_female` (CC BY-SA) no entra.
7. Lo que se envía a un LLM a través del MCP del motor es «Licensed Technology» según la sección 6(e) [F `briefs/agentes.md`]: afecta al método de trabajo, no al juego.

### Requisitos que resultan

| | Hoy (Godot) | Port |
|---|---|---|
| API gráfica | Vulkan (Forward+) u OpenGL (Compatibility) | Solo DX12 con Shader Model 6 |
| Mínimo | Gráficas integradas con Compatibility | GPU DX12 SM6 sin trazado, en el nivel «Sin trazado» (`diseno/render.md:107`) |
| Para el aspecto buscado | — | RTX 2060 o 3050 (`diseno/render.md:108`); los juegos del listón recomiendan RTX 3060 [F] |
| Sistema | Windows y macOS | Windows 10 u 11 de 64 bits |
| Disco | 1,1 GB | Sin medir (unidad PL11) |

## 5. Prueba de concepto visual

**Entra:** el esqueleto del proyecto con los nombres y carpetas de 2.1 (es la unidad M0 de `diseno/metodo.md` y P0 de `diseno/poc.md`). Y, si la prueba se da por buena, **un empaquetado Development de la escena de la prueba**, para medir tres cosas baratas de saber pronto: que el empaquetado funciona con el motor instalado y MSVC 14.50, cuánto tarda, y cuánto pesa una escena.

**No entra:** guardado, perfil, migración, ajustes, récords, Steam, versiones, informes de fallos, créditos, lanzadores.

## 6. Unidades de trabajo del port completo

Las marcadas ∥ escriben archivos disjuntos y pueden ir a la vez; sus pruebas de Automation las corre después el revisor, en serie (un solo editor).

| N.º | Unidad | Origen | Resultado | Prueba de aceptación |
|---|---|---|---|---|
| PL1 | Esqueleto (es M0 de `metodo.md`) | plantilla `TP_Blank` | `<P>` con cuatro módulos, `DefaultGame.ini` con `ProjectName=TheFour`, `ProjectVersion=2.0.0` | `Build.bat` en verde; `FFourVersion::Game()` devuelve `2.0.0` en una prueba |
| PL2 ∥ | `FFourSaveFile` | `GD:game/services/save_file.gd` | `Private/Platform/FourSaveFile.{h,cpp}` y su prueba | `TheFour.Platform.SaveFile`: escribe y relee; un `.tmp` huérfano se recupera; un archivo cortado acaba en `.corrupt` y la lectura da vacío |
| PL3 ∥ | `UFourProfileSubsystem` | `GD:game/app/hotel_main.gd:195-231` | Subsistema y su prueba | `TheFour.Platform.Profile`: bajo Automation la carpeta es `Profiles/auto/`; con `-FourProfile=x`, `Profiles/x/`; tras la pasada, `<P>/Saved/Profile/` no existe |
| PL4 ∥ | Récords y puntuación en `FourCore` | `GD:game/services/records_service.gd`, `run_score.gd` | `Source/FourCore/Records.*`, `RunScore.*` | `ue.ps1 core`: un `records.json` generado por Godot con perfil de prueba (fixture en `golden/profile/`) da los mismos tableros, hitos y puntuaciones |
| PL5 ∥ | `UFourDiscoveries` | `GD:game/services/discovery_service.gd` | Subsistema | Añadir, guardar, releer |
| PL6 | `UFourSettings` | `GD:game/services/settings_service.gd` | Subsistema, `settings.json`, aplicación de ventana y calidad | Cambiar cada ajuste, reiniciar la prueba y leer el mismo valor; los valores por defecto coinciden con la tabla sacada de Godot. Depende de los niveles de `diseno/render.md` y de las acciones de entrada del documento del jugador |
| PL7 | `UFourRecords` | PL2, PL3, PL4 | Subsistema | Una partida simulada deja en `records.json` lo mismo que `FourCore` |
| PL8 | `FFourGodotImport` | apartado 2.4 | Función y prueba con el fixture de PL4 | Con una copia del perfil en una carpeta temporal: los tres archivos se importan, la carpeta de origen queda byte a byte igual, y una segunda llamada no hace nada |
| PL9 | `UFourCheckpoint` | `GD:game/services/game_session.gd:213-252`, `GD:game/app/floor_save.gd` | Subsistema | Guardar a mitad de un piso, cerrar, Continuar: mismo piso y mismo estado; con otro `generator` o `seed`, vacío. Va después de las unidades de mundo y de sesión |
| PL10 | Steam en el ini y arranque | `GD:game/net/steam_link.gd:53-96` | `[OnlineSubsystemSteam]` en `DefaultEngine.ini` | Con Steam abierto, el registro dice `[AppId: 480] Client API initialized 1` (`OnlineSubsystemSteam.cpp:583` [M]). Lo lanza el director |
| PL11 | Empaquetado (es M16 de `metodo.md`) | `GD:tools/export/`, `GD:tools/godot.ps1` | `ue.ps1 package`: `BuildCookRun` Shipping, Win64, pak, IoStore, comprimido, `-prereqs`, `-nodebuginfo`, archivo en `<P>/Saved/Package/`; símbolos aparte | El ejecutable arranca con `-UserDir=`; no hay DLL de editor ni de MCP en la carpeta; tamaño y minutos anotados. Solo el director |
| PL12 | Fallos | D8 | Orden de consola de depuración que provoca un fallo, solo fuera de Shipping | En el paquete Development, el fallo deja volcado y registro en `Saved/Crashes/` y el `.pdb` archivado lo resuelve |
| PL13 ∥ | Créditos y avisos legales | `GD:docs/ASSETS.md`, apartado 4 | Texto de créditos con los avisos de Unreal y las atribuciones CC BY | Revisión contra la lista de licencias; ningún asset BY-SA, NC ni ND en `SourceAssets/` |
| PL14 | Subida a Steam | D6 | `Tools/steam/app_build.vdf` y `depot_build.vdf` en texto; `ue.ps1 steam` | Bloqueada hasta que haya AppID. La sesión de `steamcmd` la inicia el autor; la rama `unreal` recibe la compilación y un segundo equipo la descarga |
| PL15 ∥ | Lanzadores y `CHANGELOG` | los 17 `.cmd` | `Jugar.cmd`, `Verificar.cmd`, `Empaquetar.cmd`; `docs/CHANGELOG.md` con el apartado 2.0.0 y la nota de que Continuar no se migra | Cada `.cmd` llama a una suborden de `ue.ps1` que existe |

Orden: PL1; después PL2, PL3, PL4, PL5 a la vez; PL6, PL7, PL8; PL10 cuando exista la red; PL9 cuando exista el piso; PL11 y PL12 al final de cada hito jugable; PL13, PL15 en cualquier momento; PL14 cuando el autor tenga AppID.

## 7. Riesgos y cómo se detectan pronto

| Riesgo | Detección |
|---|---|
| El empaquetado falla con motor instalado o con el compilador de esta máquina | Empaquetado Development en la prueba de concepto (apartado 5), no en M16 |
| Un agente lanza el juego fuera de `ue.ps1` y escribe en `Saved/Profile/` del proyecto | No es el perfil real (ese está en `%LOCALAPPDATA%`), pero la prueba PL3 falla si `Profile/` existe tras una pasada |
| El tamaño se dispara (texturas escaneadas, Nanite) frente a 1,1 GB | Anotar el tamaño en cada PL11 y compararlo con el anterior |
| Un fallo en casa de un jugador sin forma de leerlo | PL12 antes de la primera versión que salga de esta máquina |
| El `records.json` real tiene campos que el fixture no cubre (perfiles viejos, VERSION 1) | PL8 acepta lo desconocido sin perderlo: lo que no entiende lo deja en el archivo; y el autor prueba una vez con una copia de su perfil |
| Jugadores sin DX12 SM6 se quedan fuera al cambiar la rama por defecto | El relevo de ramas (D6) es decisión del autor y se anuncia; la rama `godot` existe antes del relevo |
| Sin AppID no se puede probar la subida ni los logros reales | PL10 con 480 cubre el arranque; PL14 queda marcada como bloqueada |
| Contenido con licencia incompatible con el EULA entra por descuido | PL13 y el registro de licencias de `SourceAssets/` en cada integración |

## 8. Preguntas para el autor

1. **AppID.** El juego usa hoy el 480 de pruebas. ¿Existe ya una aplicación en Steamworks, o se pedirá antes del port? De eso depende PL14 y cuándo se crean los logros.
2. **Hardware flojo.** El port exige DX12 con Shader Model 6. ¿Vale dejar la versión de Godot 1.3.x en una rama `godot` para quien no llegue, sin más actualizaciones, o hay jugadores concretos a los que no se puede dejar atrás?
3. **Continuar.** La partida a medias no se migra (récords, logros y descubrimientos sí). ¿De acuerdo?
4. **Informes de fallos.** ¿Basta con que el jugador envíe a mano la carpeta `Saved/Crashes`, o quieres envío automático (pide un servicio con cuenta)?
5. **macOS.** Hay un preset de exportación para Mac. ¿Se abandona con el port?
6. **Regalía y trámites.** El formulario de lanzamiento y los informes trimestrales a Epic son tuyos; ¿los anoto en `PLAN.md` como tareas del autor?

## 9. Herramientas, plugins y assets

| Qué | Fuente | Licencia | Nota |
|---|---|---|---|
| `OnlineSubsystemSteam`, `SteamSockets`, Steamworks 1.64 | Ya en el motor (`UE:Plugins/Online/OnlineSubsystemSteam`, `UE:Plugins/Runtime/Steam`) | EULA de Unreal; el SDK, acuerdo de Steamworks | Nada que bajar |
| `steamcmd` y ContentBuilder | SDK de Steamworks, partner.steamgames.com | Acuerdo de Steamworks | Pide la cuenta de socio del autor: lo baja e inicia sesión él |
| Redistribuible de Visual C++ | `UE:Extras/Redist/en-us/vc_redist.x64.exe` | Microsoft, redistribuible | Lo incluye `-prereqs` |

Nada más para este dominio. Ningún asset.

## 10. Sin comprobar

- La forma exacta de la orden `RunUAT BuildCookRun` (solo se comprobó que existen los parámetros `pak`, `iostore`, `stage`, `archive`, `nodebuginfo`, `prereqs`, `distribution`, `crashreporter` en `ProjectParams.cs`); que empaquete con motor instalado; tiempo y tamaño.
- Que el empaquetado Shipping deje fuera por sí solo los plugins de editor y de MCP.
- Dónde escribe exactamente el volcado un Shipping sin `CrashReportClient`, y si sin `-crashreporter` se pierde algo más que la ventana. No se encontró `DataRouterUrl` en `UE:Config/*.ini` (búsqueda acotada).
- Que `-UserDir=` mueva también configuración y registros en un ejecutable Shipping (leído en `Paths.cpp`, no ejecutado).
- El comportamiento de `steam_appid.txt` y de `bRelaunchInSteam` en Shipping; cómo se declaran los logros en el ini de `OnlineSubsystemSteam`.
- Ramas de Steam: solo se leyó la cabecera de la página oficial; contraseñas, depósitos por rama y `setlive` son conocimiento previo, sin releer. Tampoco el coste y los plazos de dar de alta la aplicación.
- El contenido real de `records.json`, `discoveries.json` y `hotel_settings.json` (no se abrió ningún perfil); las claves que se migran salen de la ficha.
- `floor_save.gd`, `records_service.gd`, `run_score.gd` y `settings_service.gd` no se leyeron enteros: tamaños y constantes vienen de `fichas/servicios.md`.
- Las obligaciones del EULA vienen de `briefs/experiencias.md` §8; no se releyó el EULA.
- La GPU mínima concreta del nivel «Sin trazado» y el rendimiento: son de `diseno/render.md` y están sin medir.
- Si el estado del piso en JSON cabe en el presupuesto de D2.
- Si hoy algún jugador usa Steam Cloud o macOS.
