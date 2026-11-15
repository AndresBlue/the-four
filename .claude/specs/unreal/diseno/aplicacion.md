> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: aplicación, reglas de partida, director e interactivos (Unreal Engine 5.8.4)

Marcas: [G] leído hoy en el código de Godot; [F] ficha (`fichas/app.md`, `reglas.md`, `geo_hotel.md`), sin releer; [M] leído hoy en el motor (`UE:` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine`); [D] deducción. No se ejecutó ni compiló nada.

## 1. Qué hay hoy en Godot

- **Un nivel que lo orquesta todo.** `game/app/hotel_main.gd` (2 123 líneas) es la raíz de `game/app/hotel.tscn`; no hay autoloads. Crea catorce servicios como hijos de `Services` (`hotel_main.gd:228-287` [G]) y les da `level = self`. La escena fija el orden de hijos: `Services`, `Player`, `Interface`, `Presentation`, `WorldAudio` (`hotel.tscn:16-25` [G]).
- **Estados.** `State { MENU, LOADING, PLAYING, PAUSED, TRANSITION, WON, FAILED, CUTSCENE }` y `Life { EXPLORING, REFUGE, DEAD }` (`game/services/game_session.gd:7-8` [G]). Mínimo para avanzar `max(1, ceil(N/2))` (`:103` [G]).
- **Dos relojes.** La lógica va en `_physics_process` a 60 Hz; la presentación en `_process`. **El reloj del piso (`session.elapsed`) avanza en `_process` con el delta de fotograma** (`game_session.gd:310-311` [G]), y de él cuelgan los objetivos del piso 2 [F reglas §10.1]. Cordura, mentiras y dedupe de puertas usan reloj de pared [F app §14.1].
- **Orden real del paso de física** (orden del árbol; solo hay prioridades en `_process`: sangre 90 y cinta 100, `blood.gd:87`, `death_tape.gd:142` [G]): 1) nivel (`step_physics`, `hotel_main.gd:1600` [G]); 2) servicios (red, apariciones); 3) jugador local; 4) audio del mundo; 5) hotel: puertas y armarios, y **el director como último hijo del hotel** (`hotel_main.gd:953, 990` [G]); 6) **la criatura, añadida después del hotel** (`:1544` [G]). `criaturas.md:88` dice «supervivientes, criatura, director»: no es lo que hace el código; aquí se fija el orden del código (D2).
- **Flujo** [F app §3]: título en (-600,0,0), sala de espera por eventos de red, apertura en (600,0,0) saltable a 0,8 s, Continuar (`floor_save.gd`, cada 30 s), construcción con esperas (2 fotogramas, 2 de física, hasta 90 de navegación, rebote de luz, precalentado), juego, captura decidida por el anfitrión, cinta solo en la víctima, renacer, final (`file_run`).
- **Reglas** [F reglas]: `game/floors/` (6 archivos, 582 líneas [G]) más `objectives/` (6). `difficulty.gd`: perfil compartido por 4 niveles y perfil propio de The Lurker; `match_rules.gd`: 10 reglas de sala; `floor_index.gd`: `KINDS` 1 y 2, `RELEASED [1]`, `COUNT 4` (`:7-18` [G]).
- **Director.** `game/director/pacing_director.gd` (893 líneas [G]): fases acecho, pico y respiro; 24 líneas con sorteos [G]; lee del nivel sesión, supervivientes, manifiesto, refugio, puertas, audio y red [G, recuento de `level.*`]. Semilla `hash([seed, "director"])` (`:217` [F]). Corre en `_physics_process` solo en PLAYING (`:242-247` [G]). No existe en versus [F app §10.1].
- **Interactivos** [F geo_hotel §7.3]: `game/world/interactables/` (8 archivos más `office/office_usable.gd` [G]): áreas en capa 16; lógica en `game/app/` (`interaction.gd`, `televisions.gd`, `code_lock.gd`, `lifts.gd`). El ascensor no mueve al jugador como plataforma: lo coloca por asignación de posición (`lifts.gd:467-522`, `level.player.global_position = boarding.point` [G]).
- **Pruebas** [F app §16]: `creature_contract_test`, `capture_test`, `continue_test`, `observer_test`, `loop_test`, `sanity_test`, `difficulty_test`, `objectives_test`, `rules_test`, `stages_test`, `intro_test`, y las de oficina (`lurker_capture`, `lurker_forced`, `descend`, `jump`).

## 2. Cómo queda en Unreal

Todo C++ y texto. **Este dominio no crea ningún asset binario propio**: los modelos de televisores, cajones y cabinas son de `materiales_assets.md`; los materiales de cinta, de `render.md`.

### 2.1 Módulos

Se siguen los cuatro de `metodo.md` §2.2 (`FourCore`, `TheFour`, `TheFourRender`, `TheFourEditor`). Otros diseños nombran `FourWorld`, `FourPlayer`, `FourCreatures`, `FourUI`: el director elige; aquí cada pieza va a una carpeta que sirve en los dos repartos.

| Dónde | Qué lleva |
|---|---|
| `FourCore/Rules/` | `FDifficulty`, `FMatchRules`, `FFloorKind`, `FFloorIndex`, `FSession`, `FSanity`, `FRunLedger`, lógica pura de los cinco objetivos |
| `FourCore/Director/` | `FPacingDirector`, `IDirectorWorld`, `IDirectorCreature` |
| `FourCore/Capture/` | `FCaptureScore`, `FLurkerScore`, `FCameraFall`, `FBloodPlan`, `FRevivalPlan` (toda la parte analítica y sembrada) |
| `FourCore/App/` | `FFixedClock` (acumulador), `FLaunchArgs` (análisis de argumentos sobre texto), `FFloorSave` (qué se guarda) |
| `TheFour/App/` | `UFourGameInstance`, `UFourFlow`, `UFourSimClock`, `UFourFloor`, ampliaciones de `AFourGameMode` y `AFourGameState` |
| `TheFour/Interact/` | `AFourTelevision`, `AFourContainer`, `AFourHide`, `AFourPanel`, `AFourLock`, `AFourPaper`, `AFourKey`, `AFourLiftCar`, `AFourOfficeUsable`; `UFourLifts`, `UFourTelevisions`, `UFourCodeLock` |
| `TheFour/Scenes/` | `UFourExecutions`, `UFourDeathTape`, `UFourBlood`, `UFourRevival`, `UFourLies` (alucinaciones), `UFourFloorMap` |
| `TheFour/Dev/` (no Shipping) | `UFourObserverTools`, saltos de sector, F8 y F9 |

`FourCore` usa `double` para tiempos y umbrales (el `float` de GDScript es de 64 bits [D, conocimiento del lenguaje]) y el PCG32 y el hash de Variant de `mundo.md` §2.1.

### 2.2 Reparto del flujo (pregunta a), encajado con `red.md` §2.2 y §2.4

| Clase | Base | Qué lleva de `hotel_main.gd` |
|---|---|---|
| `UFourGameInstance` | `UGameInstance` | `Init()` (`UE:Source/Runtime/Engine/Classes/Engine/GameInstance.h:217` [M]): lee la línea de órdenes a `FLaunchArgs` (2.6) y la deja para todos. Nada más |
| `UFourFlow` | `UGameInstanceSubsystem` | La máquina de pantallas de **esta** máquina: lo que hace `on_state()` (`:1162-1259`): menú que toca, ratón, sala de título, apertura (`StartIntro(Seed)`, `FinishIntro()`), `NewGame(Difficulty, Floor)`, `Continue()`, `HostOpen()`, `Join(Address)`, `LeaveToTitle(Message)`. Vive en la instancia porque un invitado cambia de mundo al entrar y el flujo debe sobrevivirlo [D] |
| `AFourGameMode` (de `red.md`) | `AGameMode` | Solo anfitrión o partida a solas: dueña de `FourCore::FSession` (port de `game_session.gd`), `StartFloor(FFourMatchConfig)`, `PopulateFloor()` (criatura, objetivos, llave, director), `HostGate(Dt)` (`:1743-1773`), `Capture(Seat)`, `FileRun(bWon)`, `KeepFloor()` cada 30 s, desbloqueo del piso 2 |
| `AFourGameState` (de `red.md`) | `AGameStateBase` | Copia replicada: `Session`, `Seats`, `Minds`. Se añade `double FloorClock() const` (el `elapsed`) y el delegado `OnSessionChanged` (hoy `session.changed`) |
| `UFourFloor` | `UWorldSubsystem` | «El nivel» de cada máquina: `Build(Config)` (generar, `FBuildPlan`, `AFloorBuilder`, navegación, espera de PSO), el manifiesto, los registros por índice (`Doors`, `Hides`, `Televisions`, `Containers`, `Panels`, `Lifts`), los manejadores de objetivos y las funciones que hoy son `level.X` (`Rule(Id)`, `Survivors()`, `RefugeRoom()`, `GoalPoints()`, `OffLimitsRooms()`, `PointInRefuge(P)`). Implementa `IDirectorWorld` |
| `UFourSimClock` | `UWorldSubsystem` | El paso fijo (2.3) |
| `AFourPlayerController` (de `red.md`) | `APlayerController` | Además de `UFourMatchLink`: `UFourDeathTape`, `UFourLies`, `UFourInteraction` (de `jugador.md`), todos componentes de la máquina local |

Flujo, sobre el mapa único `L_Boot` (`red.md` §2.4.1, `plataforma.md` §2.1):

1. **Arranque.** `UFourGameInstance::Init` → `UFourFlow` abre el título salvo modo de herramienta (2.6).
2. **Título y sala.** Sala de título en (-600,0,0) m de Godot; menús de `ui.md`. Crear sala reabre `L_Boot?listen` (`red.md` §2.4.2).
3. **Empezar.** `AFourGameMode::StartMatch(Seed)` → `ClientBegin` → en cada máquina `UFourFloor::Build` → `ServerReportReady(Sha)` → `ClientGo` (`red.md` §2.4.4). A solas es el mismo camino en `NM_Standalone`.
4. **Construcción.** `LOADING` hasta `AFloorBuilder::OnFloorReady` (`mundo.md:48`). Las esperas de Godot se sustituyen: validación física por prueba (`mundo.md` D9), navegación por «hay ruta de (0,0,0) a la salida» con tope de 90 pasos fijos y el mismo mensaje de error, rebote de luz desaparece (Lumen), precalentado por espera de PSO (`render.md`).
5. **Juego.** `UFourSimClock` a 60 Hz; presentación en `Tick` variable.
6. **Muerte.** El anfitrión decide en `UFourExecutions::Stage()` y manda `ClientExecuteStart(FFourExecution)`; cada máquina aplica; la cinta, solo en el controlador de la víctima.
7. **Renacer y repetición.** `FSession` devuelve la etapa; `UFourRevival` reparte cuerpos y manda a la criatura a su hueco. Nunca se repite un piso perdido: «Reintentar» pide otra semilla [F reglas §7].
8. **Final.** `WON`/`FAILED` en `FSession` → `FileRun` → `UFourRecords::Commit` (`plataforma.md` §2.2) → menú.

### 2.3 Reloj fijo de 60 Hz y orden (pregunta b)

- **`FourCore::FFixedClock`**: `int32 Advance(double FrameDt)` devuelve cuántos pasos de `1.0/60` tocan (tope 8 por fotograma) y guarda `double Fraction()` para interpolar. Sin motor: se prueba en la capa 1.
- **`UFourSimClock`** se engancha a `FWorldDelegates::OnWorldPreActorTick` (`UE:Source/Runtime/Engine/Classes/Engine/World.h:4523-4524` [M]), que se emite antes de `TG_PrePhysics` (`UE:Source/Runtime/Engine/Private/LevelTick.cpp:1675, 1750` [M]). En cada fotograma ejecuta N pasos y, en cada paso, recorre **fases en orden fijo**; dentro de una fase, orden de alta. Los `Tick` de actores (que el motor no ordena dentro de un grupo, `EngineBaseTypes.h:86-101` [M]) solo dibujan: leen `Fraction()`.
- Firmas: `void Register(EFourPhase Phase, IFourFixedStep* Who)`; `void Unregister(IFourFixedStep*)`; `double Fraction() const`; `int64 StepCount() const`; `IFourFixedStep::FixedStep(double Dt)`.
- **`EFourPhase`**, en el orden comprobado en §1: `Level` (ascensores, plano, interacción local, cordura; en el anfitrión `HostGate` y libro), `Net` (envío de estado a 20 Hz), `Phantoms`, `LocalPlayer`, `WorldAudio`, `Doors`, `Hides`, `Director`, `Creature`, `Remotes`.
- **No se usa el paso fijo del motor.** Ni subpasos de Chaos (`bSubstepping`, `UE:Source/Runtime/Engine/Classes/PhysicsEngine/PhysicsSettings.h:325` [M]) ni física asíncrona (`bTickPhysicsAsync`, `:333` [M]): el juego no simula cuerpos; jugador y criatura se mueven con barridos propios (`jugador.md` D1, `criaturas.md:56`) y las caídas son analíticas [F app §14.3].
- **Reloj del piso**: `FSession::Elapsed` avanza en el `Tick` variable de `AFourGameMode`, solo en `PLAYING`, como hoy; se replica en `Session` a 2 Hz (`red.md` §2.2).
- **Reloj de pared** (cordura, mentiras, televisor, dedupe de puertas): `FPlatformTime::Seconds()`, como hoy.
- **Pausa**: en `PAUSED` el reloj no da pasos. Lo que hoy sigue vivo en pausa queda en §10.
- **Cómo se demuestra** (pruebas `TheFour.App.Clock.*` y capa 1):
  1. `FFixedClock`: 600 fotogramas de 1/144, de 1/30 y uno de 0,25 s dan 250, 1 200 y 8 pasos (capa 1).
  2. Orden: dos espías por fase anotan su turno; el registro de 10 pasos es exactamente la lista de `EFourPhase`.
  3. Independencia del fotograma: mundo de prueba con jugador guiado y criatura; 600 pasos alimentados a 30, 60 y 144 fps dan las mismas posiciones bit a bit.
  4. Con `-UseFixedTimeStep -FPS=60` (`UE:Source/Runtime/Launch/Private/LaunchEngineLoop.cpp:2460, 4730` [M]) hay un paso por fotograma: `StepCount()` igual al número de fotogramas.

### 2.4 Reglas (pregunta c): destino de cada pieza

| Pieza | Origen | FourCore (puro) | Módulo de juego |
|---|---|---|---|
| Pisos y objetivos de cada piso | `hotel_floor.gd`, `office_floor.gd`, `floor_index.gd` | `FFloorKind` (2.5), `FFloorIndex` | Nada |
| Dificultad | `difficulty.gd:84-143, 175-182` | `FDifficulty`: tabla `constexpr` con las claves del perfil compartido (46 [F]) y las de The Lurker (25 [F]) por 4 niveles; `Profile(Id, CreatureKey)`, `Valid`, `Rank`; `ORDER`, `REFERENCE = desafiante`, `FIRST = equilibrada`. Cada clave con su tipo: número, intervalo `[a, b]`, booleano o nombre (`emerge_mode`) | Nada |
| Reglas de sala | `match_rules.gd` | `FMatchRules`: las 10 reglas (`restarts`, `sanity`, `code`, `blackout`, `plan`, `plan_fade`, `shared_sheet`, `onslaught`, `tv_travel`, `plain_sight`), `BY_DIFFICULTY = -2`, `Clean`, `Settled`, `Changed`, `Described` | Viajan en `FFourMatchConfig.rules` (`red.md` §2.3) |
| Sesión, renacer (cuántas veces) | `game_session.gd` | `FSession`: estados, vidas, `Start`, `Capture`, `FinishStage`, `CanDepart`, `MinimumSurvivors`, `RESTARTS 1`, `RESTART_WAIT 2.6`, `RESTART_WAIT_AGAIN 0.6` | `AFourGameMode` la posee; `AFourGameState` la refleja |
| Cordura | `sanity.gd` | `FSanity`: 100/450 por s a oscuras, ×0,4 con linterna, +100/240 por s, umbral 60, sustos 4, 15 y 5 s, vista 28 m y cono 0,72 [F] | `UFourLies`: la consulta de luz y de vista, y lanzar la mentira |
| Renacer (dónde) | `revival.gd` | `FRevivalPlan`: hueco de la criatura con `hash([seed, "restart den", stage, restarts])` | `UFourRevival`: colocar, mirar a un compañero |
| Ejecuciones | `executions.gd`, `capture_score.gd`, `capture_styles/` | `FCaptureScore`, `FLurkerScore` (tiempos y curvas), elección de entrada y de mirada (1 de 3, 1 de 6) | `UFourExecutions`: escena en el reloj común, cuerpo, linterna, cámara. Avanza con delta de **fotograma**, como hoy (`executions.gd:345` [F]) |
| Cinta de muerte | `death_tape.gd` | `FCameraFall` (candidatos y ruta, con trazas inyectadas `ITraceWorld`) | `UFourDeathTape`: parámetros de `M_PP_Tape` (`render.md` R7), efectos del submix maestro (`audio.md:62`). Va después del jugador: `AddTickPrerequisiteActor` |
| Vista del observador | `observer_view.gd`, `observer_gizmos.gd` | Nada | `AFourObserverPawn` (`jugador.md` J17) y `UFourObserverTools` (marcas con `ULineBatchComponent`, registro, volcado) |
| Alucinaciones | `sanity.gd:236-302`, `hallucinations/`, `phantom_*.gd` | Nada: son locales y sin semilla por diseño [F app §14.2] | `UFourLies` con `FRandomStream` local; modelos y voces de `criaturas.md` y `audio.md` |
| Sangre | `blood.gd` | `FBloodPlan`: gotas, manchas y charco desde `seed ^ 0xb100d`, trazas inyectadas | `UFourBlood`: `UInstancedStaticMeshComponent` con 4 datos por instancia (como el MultiMesh de hoy). Sin calcomanías DBuffer: Substrate en formato 0 no las admite [índice, `briefs/ue58.md`] |
| Libro y puntuación | `run_ledger.gd`, `run_score.gd` | `FRunLedger`, `FRunScore` (este ya en `plataforma.md` §2.1) | Nada |
| Guardado de piso | `floor_save.gd` | `FFloorSave`: lista de lo que se guarda y `GRACE 8` | `UFourCheckpoint` (`plataforma.md` §2.2) |

Las cifras del director, de la captura, de la cinta y de los ascensores no se repiten aquí: están con ruta:línea en `fichas/app.md` §10.3 y §12, que es la fuente de los encargos.

### 2.5 Interfaz de piso (pregunta f)

`FourCore::FFloorKind` (una fila por piso, `constexpr`): `Number`, `Name`, `GeneratorVersion`, `CreatureKey` (`locust`, `lurker` o `none`), `FirstLead`, `Papers`, `Par` (2400, 2700), `Leave` (`car` o `ladder`), `Stages[]` (título, tarjeta, aviso y objetivos que pide), `Milestones[]` (18 y 12), más punteros a su generador, validador, planificador y paleta (`mundo.md` §2.1). `FFloorIndex`: `Kind(n)`, `Built`, `Released`, `Title`, `Versions()`, `Count = 4`.

Un objetivo es dos mitades:
- `FourCore::IObjective`: `Settle(Manifest, Survivors)`, `Reset()`, `Progress(Stage) -> FProgress{bReady, Done, Needed, Kind, Lines, Extra}`, `GoalPoints(Stage)`, `Tick(Dt, FloorClock)`, `AllowsRide(Stage, Riders)`, `OnDeath(Seat, Point)`, `Snapshot()`/`Restore()` como texto JSON. Port de `objective.gd` [F reglas §5].
- `UFourObjectiveActors` (juego): `Place()` crea sus actores y traduce `ClientOfficeState` y `tell_office`.

**Un piso nuevo aporta**: una fila `FFloorKind`; generador, validador, planificador y paleta; sus `IObjective` y sus actores; la clave de criatura (o `none`) y, si tiene perfil propio, sus columnas en `FDifficulty`; las reglas de sala con alcance `Kind` o `Creature`; sus hitos.

**Pisos 3 y 4**: sin fila. `Kind(3)` y `Kind(4)` devuelven el hotel, como hoy (`floor_index.gd:23-24` [G]); no se publican. No se diseña nada de Radiation Lab ni The Containment: no tienen criatura ni decisión del autor [F reglas §6]. Lo único que el diseño garantiza es que `CreatureKey = none` es válido (hoy existe `--creature=none`) y que ninguna clase del módulo de juego nombra «hotel» u «oficina» fuera de las filas.

### 2.6 Línea de órdenes y modos de herramienta (pregunta g)

`FourCore::FLaunchArgs::Parse(const TCHAR*)`, leída una vez en `UFourGameInstance::Init`. Mismos nombres con el prefijo `-Four` que ya usan `metodo.md` y `plataforma.md`.

| Godot | Unreal | Nota |
|---|---|---|
| `--test-profile`, `--profile-tag=` | `-FourTestProfile`, `-FourProfile=<nombre>` | Los resuelve `UFourProfileSubsystem` |
| `--automation`, `--background`, `--silent` | `-FourAutomation`, `-FourBackground`, `-FourSilent` | Sin intro, sin tarjeta de sector, sin audio del mundo |
| `--observer`, `--address=`, `--port=` | `-FourObserver`, `-FourAddress=`, `-port=` | Entra con `?SpectatorOnly=1` (`red.md` §2.4.3) |
| `--playtest-seed=`, `--locust` | `-FourSeed=`, `-FourHunter` | Partida local directa |
| `--floor=`, `--creature=`, `--stage=`, `--jumps`, `--no-enemy` | `-FourFloor=`, `-FourCreature=`, `-FourStage=`, `-FourJumps`, `-FourNoEnemy` | Solo no Shipping salvo `-FourFloor` |
| `--steam-host` | `-FourSteamHost` | |
| `--bots*`, `--seed=`, `--knowledge=`, `--mercy` | `-FourBot=<json>` | Un JSON en vez de siete argumentos (`metodo.md:108`); los bots son de `criaturas.md` (`FourBots`) |
| `--perf-log=`, `--perf-seed=` | `-FourPerfLog=`, `-FourSeed=` | Traza: `session_perf.gd` → CSV del motor o JSONL propio (§10) |
| `--no-warmup` | `-FourNoWarmup` | Salta la espera de PSO |
| `*.gd` como argumento | No existe | Las pruebas son Automation (`metodo.md` §2.5) |
| (nuevo) | `-FourCapture=<json>`, `-FourNetRole=<rol>` | De `metodo.md` y `red.md` |

Modos: **automatización** (`-FourAutomation`, siempre con `-unattended`), **observador** (peón libre y herramientas; nunca tiene `FSession` propia en línea), **bots** (proceso `-game -nullrhi -FourBot=`). F8 marca en la traza, F9 mata al jugador local y F9 con `-FourJumps` salta de sector: solo no Shipping.

### 2.7 Interactivos que no son puertas (pregunta e)

Regla de red (`red.md` D8): actores locales creados por `AFloorBuilder` desde `FPlanInteractive`, sin replicar, nombrados por el mismo índice entero de hoy. Petición por `UFourMatchLink::Server…`, validada en el anfitrión con `NearSender` (5 m), resultado por `Client…` a todos. Todos heredan de `AFourInteractive` (`mundo.md:50`) e implementan `IFourFocusable` (`jugador.md:44`); la lógica de pulsar (0,28 s) o mantener (1,0 s) sigue en `UFourInteraction`.

| Actor | Origen | Estado y cifras | RPC (familia de `red.md` §2.2) |
|---|---|---|---|
| `AFourTelevision` | `hotel_television.gd`, `televisions.gd` | `bOn`, apertura, parpadeo; caja 1,25×1,2×0,95 a 1,45 m | `ServerUseTelevision(Index)` → `ClientTelevision(Index, bOn)`; salto de la criatura: evento de su actor |
| `AFourContainer` | `hotel_container.gd`, `code_lock.gd` | `bSearched`, quién; cajón sale 0,5×fondo, puerta 1,1 rad, tapa 1,45 rad; nota o llave dentro | `ServerSearch(Index)` → `ClientSearched(Index, Seat)` |
| `AFourHide` | `hiding_place.gd` | Ocupantes, asomarse 0,75 rad, abierta 1,75, tiempos 0,5/0,34/3,0/0,6 | `_Hides`: `ServerUseHide(Index, bIn, bQuiet)`; `ClientHideForced` |
| `AFourPanel` | `hotel_panel.gd` | `bOpened`; 1,75 rad en 0,7 s; la llave abre cualquiera | `ServerUsePanel(Index, Action)` con `open` o `power` |
| `AFourLock` | `hotel_lock.gd`, `code_lock.gd` | 4 cifras; verde si espera | `ServerEnterCode(Digits)` → `ClientCodeEntered` |
| `AFourPaper` | `hotel_document.gd`, `hotel_hint.gd` | Documento, pista, polaroid o tarjeta | Leer es local; `ClientHintRead(Id, Seat)` |
| `AFourKey` | `code_lock.gd:187` | Sitio por `hash([seed, "key"])` | `ServerTakeKey` → `ClientKeyTaken(Seat)` |
| `AFourLiftCar` + `UFourLifts` | `lifts.gd`, `hotel_geometry.gd:1674-1699` | Viaje 8,5 s (cierre 1,7, campana 7,3, abre 7,7), salida 4,0 s; coloca al jugador por posición | `_Lifts`: llamar, salir, llegada; `FinishStage` en el anfitrión |
| `AFourOfficeUsable` | `office/office_usable.gd`, objetivos del piso 2 | `Handler`, `Action`, `Index` | `_Office`: `ServerOffice(Id, Action, Index, Seat, FFourBlob)` |

`EFourFocusKind` de `jugador.md:44` (Door, Hide, Document, Hint, Panel, Teammate) se amplía con `Television`, `Container`, `Lock`, `Key`, `LiftCall`, `OfficeUsable`: es un añadido a ese diseño, no una contradicción.

## 3. Correspondencia pieza a pieza

| Godot | Unreal | Dónde |
|---|---|---|
| `hotel.tscn` raíz y `Services` | `UFourGameInstance` y subsistemas; `L_Boot` vacío | juego |
| `hotel_main.gd` arranque y `on_state` | `UFourFlow` | juego |
| `hotel_main.gd` `build_floor`, registros, `level.X` | `UFourFloor` | juego |
| `hotel_main.gd` `start_floor`, `populate_floor`, `host_gate`, `file_run` | `AFourGameMode` | juego |
| `_physics_process` (13 archivos) | `IFourFixedStep` dado de alta en `UFourSimClock` | juego |
| `_process` | `Tick` de actor o componente | juego |
| `process_priority` 90 y 100 | `AddTickPrerequisiteActor/Component` (`EngineBaseTypes.h:426` [M]) | juego |
| `game_session.gd` | `FSession` + `AFourGameState::Session` | FourCore / juego |
| `difficulty.gd`, `match_rules.gd`, `floor_index.gd`, `*_floor.gd` | `FDifficulty`, `FMatchRules`, `FFloorIndex`, `FFloorKind` | FourCore |
| `objectives/*.gd` | `IObjective` (5) + `UFourObjectiveActors` | FourCore / juego |
| `pacing_director.gd` | `FPacingDirector` + `UFourDirectorHost` (adaptador en la fase `Director`) | FourCore / juego |
| `executions.gd`, `capture_score.gd`, `capture_styles/*` | `FCaptureScore`, `FLurkerScore`, `UFourExecutions` | FourCore / juego |
| `death_tape.gd`, `camera_fall.gd` | `UFourDeathTape`, `FCameraFall` | juego / FourCore |
| `blood.gd` | `FBloodPlan`, `UFourBlood` | FourCore / juego |
| `revival.gd` | `FRevivalPlan`, `UFourRevival` | FourCore / juego |
| `sanity.gd`, `hallucinations/*`, `phantom_*.gd` | `FSanity`, `UFourLies` | FourCore / juego |
| `interaction.gd` | `UFourInteraction` (`jugador.md` J10) | juego |
| `televisions.gd`, `code_lock.gd`, `lifts.gd` | `UFourTelevisions`, `UFourCodeLock`, `UFourLifts` | juego |
| `interactables/*.gd` | Actores de 2.7 | juego |
| `floor_map.gd` | `FFloorMapMemory` (olvido a 180 s) + `UFourFloorMap` (rayos) | FourCore / juego |
| `floor_save.gd` | `FFloorSave` + `UFourCheckpoint` | FourCore / juego |
| `run_ledger.gd` | `FRunLedger` | FourCore |
| `observer_view.gd`, `observer_gizmos.gd` | `AFourObserverPawn`, `UFourObserverTools` | juego (Dev) |
| `presentation_rig.gd` | `UFourPresentationSubsystem` (`render.md:45`) | otro dominio |
| `session_perf.gd` | Traza (§10) | juego (Dev) |
| `discovery_catalog.gd` | Tabla `constexpr` de 4 entradas | FourCore |
| Señales (`session.changed`, `lobby_changed`, `revived`) | Delegados multicast de C++ | juego |
| `OS.get_cmdline_user_args()` | `FLaunchArgs` | FourCore |

## 4. Decisiones

**D1. El nivel se parte en cuatro, por quién manda.** Lo que decide el anfitrión a `AFourGameMode`; lo que todos leen a `AFourGameState`; lo que cada máquina monta a `UFourFloor`; las pantallas a `UFourFlow`. Descartado: un `AFourLevel` único que copie `hotel_main.gd` (el motor no deja a un cliente llamar a RPC de servidor en un actor ajeno, `red.md` D1; y mezclaría lo que existe solo en el anfitrión con lo local). Descartado: estados de partida del motor (`AGameMode::MatchState`) como máquina principal: los ocho estados de hoy no casan con los suyos y `FSession` debe probarse sin motor.

**D2. Reloj propio en `OnWorldPreActorTick`, con fases, y el orden del código de Godot.** Descartados:
- `TickGroup` y prerrequisitos para todo: ordenan dentro de un fotograma, no dan pasos fijos ni varios pasos por fotograma.
- `UTickableWorldSubsystem`: los tickables corren después de `TG_PostPhysics` (`LevelTick.cpp:1821` [M]), es decir, después de que los actores ya dibujaron con el estado viejo.
- `-UseFixedTimeStep` en el juego publicado: ata el tiempo del juego a los fotogramas; solo sirve para pruebas.
- Física asíncrona de Chaos a paso fijo: es para cuerpos simulados, que aquí no hay.
- Orden «supervivientes, criatura, director» de `criaturas.md:88`: **se contradice a sabiendas**; el código hace director antes que criatura (§1). Si el director de la sesión prefiere el de `criaturas.md`, es cambiar dos entradas de `EFourPhase`, pero el volcado de referencia de D4 dejaría de coincidir en un paso.

**D3. Reglas y tablas en `FourCore` como `constexpr`, no en DataTable ni DataAsset.** Son texto, se prueban en segundos y un agente las edita sin editor. Descartado DataTable (`.uasset` binario o CSV que hay que importar con el editor abierto) y `GameplayTags` para las claves (añade un ini y no aporta comprobación de tipos).

**D4. Director: port literal con dos interfaces y volcado de referencia.** `FPacingDirector` conserva nombres de función, constantes y el orden de los sorteos (cada `rng.randf*` en el mismo sitio; si se altera uno, cambia todo lo que sigue). `IDirectorWorld` e `IDirectorCreature` son la lista exacta de lo que hoy pide a `level` y a la criatura [F app §10.1, §4.5]. Pruebas: (1) **volcado**: un guion de Godot monta el director con un nivel falso (planta fija de 12 salas, supervivientes en rutas guionizadas, criatura que anota pistas) y escribe `golden/director/<dificultad>_<semilla>.json` con `history` durante 20 min a 60 Hz; la capa 1 repite el mismo nivel falso y compara línea a línea (4 dificultades × 5 semillas). (2) Port de los casos del director de `loop_test`, `difficulty_test`, `rules_test` y `lurker_forced_test`. Descartado: StateTree o Behavior Tree (assets binarios, tick propio ajeno al paso fijo, `criaturas.md:121`); reescribirlo «a la Unreal» (rompe el criterio 2).

**D5. Azar: el que se comparte, PCG32 con hash de Variant; el local, `FRandomStream`.** Los sorteos con semilla de [F app §14.2] (director, hueco de renacer, llave, sangre, caída de cámara, foto, estación, ficha) usan el generador de `mundo.md`; así todas las máquinas ven lo mismo y los volcados coinciden. Los locales por diseño (mentiras, apariciones, sonido de cajón, llegada del ascensor) no necesitan coincidir. Descartado: enviar por red cada resultado (más RPC y no hace falta).

**D6. Interactivos: un actor por pieza, sin replicar, lógica de uso centralizada.** Sigue `red.md` D8 y `jugador.md` D8. Descartado: componentes sueltos dentro del actor de la sala (el foco por traza necesita un actor con su volumen); actores Blueprint (binarios).

**D7. La captura sigue en delta de fotograma y la cinta después del jugador.** Es lo que hace hoy (`executions.gd:345`, `death_tape.gd:142` [F/G]); pasarlas al paso fijo cambiaría la sensación.

**D8. Objetivos en dos mitades.** La lógica (progreso, instantánea, relojes sobre `FloorClock`) es pura y se prueba con el `objectives_test` portado; los actores quedan finos. Descartado: un actor por objetivo con todo dentro (no se prueba sin mundo).

**D9. Modos de herramienta por argumentos `-Four…`, no por mapas ni GameModes distintos.** Un solo camino de arranque, como hoy. Descartado: un GameMode por modo (duplica el flujo).

## 5. Prueba de concepto visual

**Entra: nada de este dominio.** `poc.md` §5.5 deja fuera gameplay, interactivos, red, cinta de muerte y sangre; la toma la gobierna `-FourCapture` (`metodo.md` §2.4). **No entra:** flujo, reloj, reglas, director, interactivos, modos. Lo único útil que este dominio puede adelantar sin editor, en paralelo a la prueba de concepto, es A1 a A4 (FourCore puro).

## 6. Unidades de trabajo del port completo

∥ = puede ir en paralelo con las de su mismo bloque (archivos disjuntos, sin editor). Las de `FourCore` no abren Unreal.

| N.º | Unidad | Origen | Resultado | Prueba de aceptación |
|---|---|---|---|---|
| A0 | Volcados de referencia (única que ejecuta Godot; la lanza el director) | `difficulty.gd`, `match_rules.gd`, `*_floor.gd`, `pacing_director.gd`, `capture_score.gd`, `lurker_score.gd` | `golden/rules/*.json`, `golden/director/*.json`, `golden/capture/*.json` | Los JSON existen y el de dificultad tiene 4 perfiles por criatura |
| A1 ∥ | Tablas de reglas | `difficulty.gd`, `match_rules.gd`, `floor_index.gd`, `hotel_floor.gd`, `office_floor.gd`, `discovery_catalog.gd` | `FDifficulty`, `FMatchRules`, `FFloorKind`, `FFloorIndex` | Volcado igual al de A0 clave a clave; casos de `difficulty_test` y `rules_test` sin mundo |
| A2 ∥ | Sesión | `game_session.gd` | `FSession` | Casos de `stages_test` sin mundo: 3 etapas, mínimo `ceil(N/2)`, perdones por dificultad |
| A3 ∥ | Reloj y argumentos | (nuevo), `hotel_main.gd:194-222` | `FFixedClock`, `FLaunchArgs` | 250, 1 200 y 8 pasos (2.3); cada fila de 2.6 se analiza |
| A4 ∥ | Director puro (tras A0) | `pacing_director.gd` | `FPacingDirector`, interfaces | 20 volcados idénticos línea a línea |
| A5 ∥ | Partituras y planes | `capture_score.gd`, `lurker_score.gd`, `camera_fall.gd`, `blood.gd` (parte analítica), `revival.gd:81` | `FCaptureScore`, `FLurkerScore`, `FCameraFall`, `FBloodPlan`, `FRevivalPlan` | Curvas iguales al volcado en 100 instantes; misma ruta de caída con trazas falsas |
| A6 ∥ | Cordura, libro, plano, guardado | `sanity.gd`, `run_ledger.gd`, `floor_map.gd`, `floor_save.gd` | `FSanity`, `FRunLedger`, `FFloorMapMemory`, `FFloorSave` | 7,5 min a oscuras y 4 min de vuelta; el plano olvida a 180 s |
| A7 ∥ | Lógica de objetivos | `objectives/*.gd` | 5 `IObjective` | Casos de `objectives_test`: progreso e instantánea de ida y vuelta |
| A8 | Reloj en el mundo (tras A3; primera con editor) | (nuevo) | `UFourSimClock`, `IFourFixedStep` | Pruebas 2 a 4 de 2.3 |
| A9 | Instancia y flujo (tras A2, A8, red U-sala) | `hotel_main.gd:187-369, 554-669, 1162-1259` | `UFourGameInstance`, `UFourFlow` | Con `-FourAutomation -FourSeed=81` llega a `PLAYING` sin tocar nada y lo escribe en el log |
| A10 | Nivel local (tras mundo U11) | `hotel_main.gd:720-1007` | `UFourFloor::Build`, registros | Semilla 81: tantos actores por registro como entradas del manifiesto; ruta a la salida |
| A11 | Modo de juego (tras A9, A10) | `hotel_main.gd:1012-1076, 1273-1292, 1743-1773` | `AFourGameMode` completo | Port de `stages_test`: tres sectores encadenados hasta `WON` |
| A12 ∥ | Televisores | `hotel_television.gd`, `televisions.gd` | `AFourTelevision`, `UFourTelevisions` | Encender N cumple la etapa 2; apagón al faltar una con la regla a 1 |
| A13 ∥ | Cajones, notas, llave, paneles, teclado | `hotel_container.gd`, `hotel_document.gd`, `hotel_hint.gd`, `hotel_panel.gd`, `hotel_lock.gd`, `code_lock.gd` | Cinco actores, `UFourCodeLock` | Las cuatro cifras abren la última puerta; con la regla `code` a 1 no se puede adivinar |
| A14 ∥ | Armarios (tras puertas, mundo U13) | `hiding_place.gd` | `AFourHide` | Entrar 0,5 s, salir 0,34 s; hoja sólida bajo 0,25 rad |
| A15 ∥ | Ascensores | `lifts.gd`, `hotel_geometry.gd:1638-1851` | `AFourLiftCar`, `UFourLifts` | Viaje de 8,5 s con sus cuatro marcas; el coche que sale cierra el sector |
| A16 | Director en el mundo (tras A4, A11, criaturas C8) | `pacing_director.gd` (lecturas del nivel) | `UFourDirectorHost`, `UFourFloor` como `IDirectorWorld` | Port de `loop_test` (parte del director) y `lurker_forced_test` |
| A17 | Ejecuciones (tras A5, A11, jugador J18) | `executions.gd`, `capture_styles/*` | `UFourExecutions` | Port de `capture_test`: marcas a 3,3, 3,5 y 5,0 s (Locust) y 3,15 y 5,4 s (Lurker) |
| A18 ∥ | Cinta de muerte (tras A17, render R7, audio A11) | `death_tape.gd` | `UFourDeathTape` | Solo en la víctima; los efectos del maestro no dejan restos |
| A19 ∥ | Sangre (tras A17) | `blood.gd` | `UFourBlood` | Misma semilla, mismas manchas en dos procesos |
| A20 ∥ | Renacer y cordura en el mundo | `revival.gd`, `sanity.gd` | `UFourRevival`, `UFourLies` | Port de `sanity_test`; tras renacer, criatura a 45 m y gracia de 12 s |
| A21 ∥ | Objetivos del piso 2 en el mundo (tras A7, mundo oficinas) | `files_`, `power_`, `air_objective.gd`, `office_usable.gd` | Actores y `AFourOfficeUsable` | Port de `descend_test` y `jump_test` |
| A22 | Continuar (tras A11 a A15) | `floor_save.gd`, `hotel_main.gd:739-811` | Guardado cada 30 s y vuelta | Port de `continue_test` |
| A23 ∥ | Observador y herramientas | `observer_view.gd`, `observer_gizmos.gd` | `UFourObserverTools` | Port de `observer_test` |
| A24 | Contrato completo | `creature_contract_test.gd` (parte de app) | Casos portados | Los casos de app pasan con `ue.ps1 auto TheFour.App.` |

Orden: A0; A1 a A7 en paralelo; A8; A9 a A11 en serie; A12 a A15 en paralelo; A16 y A17; el resto.

## 7. Riesgos y cómo se detectan pronto

| Riesgo | Detección |
|---|---|
| El orden de fases no reproduce un caso que depende de él (por ejemplo, `televisions.tick` antes de `HostGate`, [F reglas §10.5]) | Prueba 2 de 2.3 en A8 y el `stages_test` portado en A11 |
| El hash de Variant o PCG32 de `mundo.md` no están cuando A4 empieza | A4 depende de la unidad de azar de mundo (U1); mientras, no arranca |
| El volcado del director difiere por coma flotante (32 bits de `Vector3` frente a 64 de `float`) | A4 con una semilla antes de portar las 893 líneas: portar primero `tick` y `build`, comparar, y seguir |
| El flujo no sobrevive al cambio de mundo de un invitado | A9: escenario de red de dos procesos (`red.md` D14) antes de A11 |
| El tope de 8 pasos por fotograma cambia el comportamiento con tirones largos | Medir en Godot cuántos pasos da tras una pausa de 0,5 s (§10) antes de fijar el tope |
| Lo que se actualiza en `PAUSED` hoy no se conoce | Leer `process_mode` de cada servicio antes de A9 |
| La captura en delta de fotograma se desajusta entre máquinas a distinto ritmo | `capture_test` portado a 30 y 144 fps: mismas marcas ±1 fotograma |
| `OnWorldPreActorTick` es estático y llega para todos los mundos (editor, vista previa) | `UFourSimClock` filtra por su `UWorld`; prueba con dos mundos de prueba a la vez |

## 8. Preguntas para el autor

1. Las seis discrepancias entre `docs/DIFFICULTY.md`/`GAME_DESIGN.md` y `difficulty.gd` [F reglas §4.4] (oído, encuentro garantizado, respiros, pistas, cercanía, protección de 10 o 12 s): el port copia el código. ¿Vale, o alguna cifra del documento es la buena?
2. Las teclas de depuración (F9 mata al jugador, saltos de sector) ¿se quedan fuera del juego publicado, como hoy quedan fuera las de bots?

## 9. Herramientas, plugins o assets

Nada que instalar ni bajar. Todo usa módulos del motor ya presentes (`Engine`, `Core`) y lo que ya activan `red.md` y `metodo.md`.

## 10. Sin comprobar

- Las cifras y funciones marcadas [F] vienen de las fichas; hoy solo se releyó lo marcado [G]. En particular no se recontaron las 46 y 25 claves de dificultad (A0 las vuelca).
- Dónde entran en el orden del paso fijo los cuerpos remotos (`match_net.gd:138` los añade al nivel; depende de cuándo) y `match_net._physics_process`. La fase `Remotes` al final es una suposición.
- Qué sigue actualizándose en `PAUSED` y en `LOADING` (la raíz tiene `process_mode = 3`).
- El tope de pasos de física por fotograma de Godot (se supone 8, el valor por defecto; `project.godot` no lo cambia según la búsqueda de hoy, pero el valor por defecto no se miró en `.claude/godot-api`).
- Quién manda en la cordura en línea (cada máquina la suya y el anfitrión publica `Minds`, o solo el anfitrión): `sanity.gd` no se leyó entero.
- Que el `float` de GDScript sea de 64 bits y `Vector3` de 32 en este ejecutable: es conocimiento general del motor, no leído hoy.
- Los nombres exactos de las RPC de `match_net.gd` para televisores, cajones, llave, teclado y ascensores: los de 2.7 son propuestos; el encargo los toma de `fichas/red.md`.
- Que `OnWorldPreActorTick` se emita también en un proceso `-nullrhi` y con el mundo en pausa del motor: leído el punto de emisión, no las condiciones que lo rodean.
- `session_perf.gd` (traza con hilo escritor): no se decidió entre el CSV del motor y un JSONL propio.
- Los contratos por nombre con interfaz, audio y presentación (`fichas/app.md` §4.5) no se cruzaron uno a uno con `ui.md`, `audio.md` y `render.md`.
- El catálogo MCP (`mcp_catalogo.md`) no se consultó: este dominio no afirma que un agente cree nada por MCP.
- No se consultó la web.
