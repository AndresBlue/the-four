> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: criaturas e inteligencia artificial (Unreal Engine 5.8.4)

Solo planificación. Marcas: [C] comprobado por mí en el código de Godot; [M] leído en el motor instalado (`UE:` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine`); [F] tomado de una ficha o de otro diseño sin releer el código; [D] deducción. `EN:` = `game/enemies`. Catálogo MCP = `.claude/specs/unreal/mcp_catalogo.md`.

## 1. Qué hay hoy en Godot

- **Contrato común.** `EN:/creature.gd` (418 líneas, 81 funciones [C]) extiende `CharacterBody3D`; listas de modos `HOSTILE`, `ATTACKING`, `HUNTING`... y control `ai`, `puppet` o `player` [F `fichas/locust.md` §2]. `null_creature.gd` (77) es la criatura vacía. `creature_sight.gd` (170) es la vista compartida de los supervivientes (máscara 1|8|64, un solo `intersect_ray` [C]).
- **The Locust (piso 1).** `EN:/locust/hotel_locust.gd` (2487): un solo archivo con IA, sentidos, movimiento y voz. `enum Mode` de 10 valores en `:6` [C]. 122 usos de `level.`, 6 `intersect_ray`, 13 consultas de navegación, 6 `move_and_slide` [C, recuento]. Rutas con `NavigationServer3D` a través de `FLOOR.navigation_path`, sin agente, reescritas por puertas en `door_threading.gd` (187) [F]. Semilla `manifest.seed + 71013` (`:446`) [C].
- **Cazador humano (versus).** `locust_player.gd` (491) y la vista de eco `echo_view.gd` (1153) con `echo_body.gd` y tres sombreadores: granos en `MultiMesh` con `INSTANCE_CUSTOM`, prioridades de dibujo 120 a 127, lectura del búfer de profundidad [F `fichas/locust.md` §8]. Semilla propia `seed + 90211` (`echo_view.gd:322`) [C].
- **Cuerpo de The Locust.** `locust_visual.gd` (406): 18 huesos Valve Biped movidos por código, IK de piernas de dos huesos, sin clips [F §9]. Modelo `assets/enemies/locust.glb`, **CC BY-NC-ND 4.0** (`docs/ASSETS.md:110-111, 433`) [C].
- **The Lurker (piso 2).** Ya está partida en piezas [C, `extends` de cada archivo]:
  - mente pura: `lurker_brain.gd` (1139, `RefCounted`, `enum State` de 15 valores en `:56`, **ningún** `level.` ni rayo), `lurker_warning.gd` (170, puro);
  - mundo de la mente: 14 funciones `world.*` (`room_point`, `clue_point`, `exit_of_room`, `behind_point`, `travel_metres`, `stalk_point`, `show_spot`, `scream`, `patrol_room`, `lead_rooms`, `emerge_point`, `dark_retreat`, `ambush_point`, `above_locker`) [C, grep en `lurker_brain.gd`];
  - dónde puede estar: `lurker_shell.gd` (1095, matemática pura, sin malla), `duct_graph.gd` (171), `lurker_routes.gd` (979, A* propio sobre salas, puertas y conductos; 10 `level.`), `lurker_motion.gd` (1189; 1 `level.`, 0 rayos);
  - sentidos: `lurker_senses.gd` (508; 27 `level.`, 1 consulta de navegación para el oído);
  - cuerpo: `lurker.gd` (1646, `_physics_process` en `:533`, luz bebida en `_process` `:1483`); semilla `hash([seed, "lurker"])` (`:200`) [C];
  - dibujo: `lurker_visual.gd` (463; interpola entre dos ticks de física, `:274`), `lurker_limbs.gd` (696, `SkeletonModifier3D`, `_process_modification_with_delta` en `:271`, 5 rayos y 1 forma) [C]; tinta `lurker_darkness.gdshader` (raymarch de 10 pasos con profundidad), polvo `ceiling_dust.gd` (404) [F `fichas/lurker.md` §8-9];
  - arte: `tools/art/lurker/` genera `lurker.glb` con Blender (142 huesos, 8 clips, hecho para el proyecto) [F; `docs/ASSETS.md:441`].
- **Pruebas y bots.** `tests/hotel/creature_contract_test.gd` (120 checks), `creature_test`, `echo_test`, `capture_test`, `difficulty_test`; `tests/office/lurker_{fairness,senses,shell,motion,forced,capture,bots,tiles,observer,mood_audio}_test.gd`, `conduit_graph_test` [C, listado]. `lurker_fairness_test.gd:1-40`: parte B, 200 aproximaciones con semilla «sin escena», la mente contra un `FakeWorld` de 6 funciones; parte A sobre un piso 2 montado [C]. Bots en `tools/bots/` (20 archivos, 4942 líneas) [C].
- **Paso.** `project.godot` no fija `physics_ticks_per_second`: vale el 60 de fábrica [C, grep vacío]. La vista de eco reparte rayos con la cifra 60 fija (`echo_view.gd:668`) [F].

## 2. Cómo queda en Unreal

Dos capas, la misma regla que el diseño del mundo (`diseno/mundo.md` §2): la decisión vive sin motor; el motor solo responde preguntas y dibuja.

### 2.1 `FourCore/Creature/` (C++20 sin cabeceras de Unreal, espacio de Godot, 60 Hz)

Usa lo que ya define `mundo.md`: `FGdRandom` (PCG32), `GdHash`, `FGdVec3`, `TGdDict`, `FManifest`.

| Clase | Origen | Firmas principales |
|---|---|---|
| `ICreature` + `FCreatureModes` | `creature.gd` | Las 81 funciones con el mismo nombre en PascalCase; `Activity() -> EActivity`; predicados `IsHostile()`... sobre las mismas listas |
| `FNullCreature` | `null_creature.gd` | Implementa `ICreature` con los valores por defecto |
| `CreatureSight` (funciones libres) | `creature_sight.gd` | `Watched(const ISightWorld&, FGdVec3 Target, Reach=70, Dot=0.35) -> bool`, `Regards(...)`, `Beside`, `RearOf`, `OverOf` |
| `FDifficultyTables`, `FNoiseKinds` | `game/floors/difficulty.gd`, `game/audio/noise_kinds.gd` | Tablas `constexpr`; `Radius(ENoise) -> float`, `HEARING_SCALE` 2,6 |
| `FLurkerBrain` | `lurker_brain.gd` | `Decide(const FLurkerPercept&, double Delta) -> FLurkerIntent`; `Force(ELurkerState)`; `ELurkerState` con los 15 valores en el mismo orden |
| `ILurkerWorld` | las 14 `world.*` | Mismos nombres; lo implementan el adaptador de Unreal y el mundo falso de las pruebas |
| `FLurkerWarning` | `lurker_warning.gd` | `Start(...)`, `Check(...) -> EVerdict {Saved, Aborted, Expired, Due, Running}`, `MayCapture(...)`, `Audit(const FCaptureLog&)` |
| `FDuctGraph`, `FLurkerShell` | `duct_graph.gd`, `lurker_shell.gd` | `Build(const FManifest&)`; parches `TRAY`, `BAND`, `CHANNEL` |
| `FLurkerRoutes` | `lurker_routes.gd` | `Plan(From, To, Opts) -> FLurkerPlan {bOk, Cost, Nodes, Legs, Pairs, Why}`, `TravelMetres`, `FleeExit`, `ArrivalExit`; pide puertas y luces por `IFloorState` |
| `FLurkerMotion` | `lurker_motion.gd` | `Tick(double Delta)`, `Bolt(...)`, `Leap(...)`; salida: transformación y velocidad del tick |
| `FLurkerSenses` | `lurker_senses.gd` | `Perceive(double Delta) -> FLurkerPercept`; `DrainRooms()`; rayos y rutas por `ISenseWorld` |
| `FLocustMind` | IA de `hotel_locust.gd` (modos, detección, búsqueda, acecho, golpe) | `Step(double Delta)`, `Hear(Point, Radius)`, `HearRoute(Point, Radius) -> FHeard {bAudible, Apparent, Distance, Muffle}`, `Sees(SurvivorId)`; `ELocustMode` con los 10 valores |
| `ILocustWorld` | los 122 `level.*` más rayos, rutas y `move_and_slide` | Se levanta en la unidad C6 (inventario antes de escribir) |
| `FDoorThreading` | `door_threading.gd` | `Thread(Route, Doors) -> Route` |
| `FEchoBudget`, `FEchoSpray` | parte sin dibujo de `echo_view.gd` | Reloj del clic, reparto de rayos por tick, direcciones de Fibonacci, búfer en anillo (índices) |

Interfaces de mundo comunes: `ISenseWorld` (`Ray(From, To, Mask) -> FHit`, `NavPath(From, To) -> puntos`, `Closest(Point)`), `IFloorState` (puerta abierta, sala encendida, `Drain(Room, Amount)`), `ISurvivors` (lista con posición, mirada, linterna, escondite). Máscaras como enumeración propia (`World`, `Survivor`, `DoorLeaf`, `Hide`, `OpenLeaf`), traducidas a canales en un solo sitio.

### 2.2 Módulo `FourCreatures` (Runtime; depende de `Engine`, `NavigationSystem`, `AnimationCore`, `Niagara`, `FourCore`, `FourWorld`)

| Clase | Base | Qué hace |
|---|---|---|
| `UFourCreatureWorld` | `UWorldSubsystem` | Implementa `ISenseWorld`, `IFloorState`, `ISurvivors`, `ILurkerWorld`, `ILocustWorld` sobre `UFloorSubsystem`, trazas por canal y `UNavigationSystemV1::FindPathSync` / `ProjectPointToNavigation` [M `UE:/Source/Runtime/NavigationSystem/Public/NavigationSystem.h:650-658, 712-718`]. Única frontera con `FFourSpace` |
| `AFourCreature` | `APawn` | Dueña del paso fijo de su mente (lo llama el reloj de simulación de 60 Hz del juego, no `Tick`), de `PackState`/`PushState`/`FollowState` (retardo 0,1 s, búfer 12, propios) y del control `ai`/`puppet`/`player` |
| `ALocustCreature` | `AFourCreature` | Cápsula 0,4 × 2,4 m; `ULocustSlideMove` (`UPawnMovementComponent`: `SafeMoveUpdatedComponent` y `SlideAlongSurface` [M `UE:/Source/Runtime/Engine/Classes/GameFramework/MovementComponent.h:63-64`], velocidad directa, gravedad 20 m/s² a mano) |
| `ALurkerCreature` | `AFourCreature` | Sin colisión de movimiento (hoy `collision_mask = 0` [F]); coloca la transformación que da `FLurkerMotion`; bebe luces y linternas |
| `ULurkerAnimInstance` + `FLurkerAnimProxy` | `UAnimInstance`, `FAnimInstanceProxy` | Animación entera en C++ sin Animation Blueprint: `CreateAnimInstanceProxy()` [M `UE:/Source/Runtime/Engine/Classes/Animation/AnimInstance.h:1716`] y `Evaluate(FPoseContext&)` [M `UE:/Source/Runtime/Engine/Public/Animation/AnimInstanceProxy.h:659`]: muestrea el clip (`UAnimSequence::GetAnimationPose` [M `AnimSequence.h:427`]) y escribe encima los huesos de manos, codos, dedos, cuello, ojos, mandíbula y vientre |
| `FLurkerLimbs` | clase C++ | Port de `lurker_limbs.gd`: 7 manos, 11 sondas, 2 por fotograma. Las trazas se lanzan en el hilo de juego (`NativeUpdateAnimation` [M `AnimInstance.h:1439`]); la solución de dos huesos con `AnimationCore::SolveTwoBoneIK` [M `UE:/Source/Runtime/AnimationCore/Public/TwoBoneIK.h:29-89`] o la fórmula propia de hoy si difiere |
| `ULocustAnimInstance` + proxy | igual | Port de `locust_visual.gd` y `locust_poser.gd`: piernas IK, `PoseBody`, `PoseArms`, `PoseHead`, `PoseCapture` |
| `ULurkerInkComponent` | `USceneComponent` | Esfera de tinta y vapor, manchas (`UDecalComponent`), y la absorción en la niebla (2.3) |
| `FCeilingDust` | funciones estáticas | `Fall(World, Point, bOpened)`, `Seep(...)`; lanza `NS_CeilingDust_*` y un `ULocalFogVolumeComponent` por velo (máx. 3) [M `UE:/Source/Runtime/Engine/Classes/Components/LocalFogVolumeComponent.h:21-53`: `RadialFogExtinction`, `FogAlbedo`, `FogEmissive`, `FogPhaseG`] |
| `ULocustDriver` | `UObject` | Port de `locust_player.gd`: golpe, chillido, salto por teles, contactos |
| `UEchoViewComponent` | `UActorComponent` del cazador | Port de `echo_view.gd`: una `UInstancedStaticMeshComponent` por nube con 4 flotantes por instancia (`SetNumCustomDataFloats`, `SetCustomDataValue`, `BatchUpdateInstancesTransforms` [M `UE:/Source/Runtime/Engine/Classes/Components/InstancedStaticMeshComponent.h:323, 327, 388`]), el plano de oscuridad hijo de la cámara y el material propio del cuerpo |

Módulo aparte `FourBots` (solo desarrollo, no se empaqueta): port de `tools/bots/`.

### 2.3 Assets (todos por guion o MCP)

| Asset | Cómo se crea |
|---|---|
| `SK_Lurker`, su esqueleto y 8 `AnimSequence` | `tools/art/lurker/` (Blender sin interfaz) exporta el glb; importación con `SkeletalMeshTools.import_file` (catálogo `:637`) o guion `-run=pythonscript` |
| `SK_Locust` | Pendiente de la pregunta 1 (licencia) |
| `M_LurkerInk`, `M_LurkerVapor` (translúcido sin luz, cara interior de una esfera, sin prueba de profundidad [M `bDisableDepthTest`, `UE:/Source/Runtime/Engine/Public/Materials/Material.h:659`]) | Cáscara con nodo Custom que incluye `Shaders/Private/Creatures/LurkerInk.ush` (patrón de `diseno/render.md` §2.2); `MaterialTools` del MCP |
| `M_LurkerInkVolume` (dominio Volume [M `UE:/Source/Runtime/Engine/Public/MaterialDomain.h:21`]) | Igual; albedo negro y extinción alta: la niebla volumétrica deja de dispersar luz dentro de ella |
| `M_LurkerStain` (calcomanía), `M_LurkerSkin`, `M_LurkerEyes` | `MaterialTools` + `MaterialInstanceTools` |
| `NS_CeilingDust_Thread`, `_Flakes`, `_Crumbs`, `_Puffs` | `NiagaraToolset_System` (46 herramientas, catálogo `:174-222`) |
| `M_EchoPoints`, `M_EchoField`, `M_EchoSelf` | Cáscaras con `EchoPoints.ush`, `EchoField.ush`, `EchoSelf.ush`; `SM_EchoQuad` (un cuadrado) |

No se crea ningún StateTree, Behavior Tree, Control Rig ni Animation Blueprint.

## 3. Correspondencia pieza a pieza

| Godot | Unreal | Dónde |
|---|---|---|
| `creature.gd` (81 funciones, listas de modos) | `ICreature`, `FCreatureModes`; `AFourCreature` delega | FourCore / FourCreatures |
| `control` ai / puppet / player | `ECreatureControl`; la mente solo corre con `Ai` | FourCreatures |
| `_physics_process` a 60 Hz | Paso fijo llamado por el reloj de simulación (dominio aplicación) en orden explícito: supervivientes, criatura, director | FourCreatures |
| `rng.seed = hash([seed,"lurker"])`, `seed + 71013`, `seed + 90211` | `FGdRandom` + `GdHash` con las mismas semillas | FourCore |
| `intersect_ray` con máscara 1\|8\|64, 1\|4, 1\|4\|8\|128 | `ISenseWorld::Ray` → `LineTraceSingleByChannel`/por objeto con los canales de `mundo.md` §3 | UFourCreatureWorld |
| `FLOOR.navigation_path`, `FLOOR.closest` | `FindPathSync`, `ProjectPointToNavigation` sobre la malla dinámica (`mundo.md` D10) | UFourCreatureWorld |
| `door_threading.gd` | `FDoorThreading` (igual, sobre la ruta que dé Recast) | FourCore |
| `move_and_slide` de The Locust | `ULocustSlideMove` | FourCreatures |
| A* de `lurker_routes.gd`, cáscara, conductos | `FLurkerRoutes`, `FLurkerShell`, `FDuctGraph`, sin malla de navegación | FourCore |
| `hear_route` (alcance, línea de vista, longitud de ruta, `apparent`, `muffle`) | `FLocustMind::HearRoute` y `FLurkerSenses` con las mismas fórmulas | FourCore |
| `hotel.drain(room, amount)`, `LIT_DRAIN` 0,9 | `IFloorState::Drain` → `UFloorSubsystem` atenúa las `AFourRoomLight` de la sala | FourWorld |
| `drink_torches`, `kill_torches` | Llamadas a la linterna del jugador (dominio jugador) | interfaz |
| `SkeletonModifier3D` (`lurker_limbs.gd`) | `FLurkerAnimProxy::Evaluate` + `FLurkerLimbs` | FourCreatures |
| `AnimationPlayer` (`idle` y 7 clips) | Muestreo de `UAnimSequence` en el proxy | FourCreatures |
| Interpolación `tick_before`/`tick_after` (`lurker_visual.gd:274`) | Igual: el visual interpola con la fracción del acumulador | FourCreatures |
| Capa de render 4 + `cull_mask` de calcomanías | `bReceivesDecals = false` en la malla [M `UE:/Source/Runtime/Engine/Classes/Components/PrimitiveComponent.h:489`] | código |
| `lurker_darkness.gdshader` | `M_LurkerInk` + `M_LurkerInkVolume` | asset + `.ush` |
| `Decal` de mancha y de manos | `UDecalComponent` con `M_LurkerStain` (mate) | código + asset |
| `GPUParticles3D` hilos, escamas, trozos | `NS_CeilingDust_*` (cantidades 600/360/210, 8, 6-7) | asset |
| `FogVolume` del velo (`VEIL_SIZE` 1,4×2,2×1,4, densidad 3, vida 9 s, máx. 3) | `ULocalFogVolumeComponent` animado por código | código |
| `puffs` sin niebla volumétrica | `NS_CeilingDust_Puffs` cuando la calidad apaga la niebla volumétrica | asset |
| `MultiMeshInstance3D` de granos + `INSTANCE_CUSTOM` | ISM con 4 datos por instancia y billboard en el material | código + asset |
| `render_priority` 120-127 | `TranslucencySortPriority` [M `PrimitiveComponent.h:892`] con los mismos números | código |
| `echo_field` (malla hija de la cámara, `ALPHA = 1`, lee profundidad) | `SM_EchoQuad` hijo de la cámara con `M_EchoField` (translúcido, sin prueba de profundidad, lee SceneDepth), prioridad 120 | código + asset |
| `material_override` propio (`echo_self`) | `SetMaterial` en cada sección y restauración | código |
| Apagar luces, niebla, SSAO y brillo para el cazador | Perfil «cazador» del volumen de posprocesado: GI y reflejos en «ninguno» (`DynamicGlobalIlluminationMethod`, `ReflectionMethod` [M `UE:/Source/Runtime/Engine/Classes/Engine/Scene.h:1767, 1839`]), exposición fija | dominio render |
| `creature_call`, `pack_state` (12 campos) | `FCreatureNetState` y llamadas con los mismos nombres; el transporte es del dominio red | interfaz |
| `tools/bots/*` | Módulo `FourBots` | C++ |
| `capture_log`, `audit`, `lurker_telemetry.gd`, `summary.json` | Mismos JSON en `Saved/Four/` | C++ |

## 4. Decisiones

**D1. Cerebros como máquinas de estado propias en C++ sin motor.** Se portan `lurker_brain`, `lurker_warning` y la IA de The Locust función a función, con las mismas constantes, el mismo orden de sorteos y `double`/`float` como en GDScript.
- Por qué: la mente de The Lurker ya es pura (0 `level.`, 0 rayos [C]) y su prueba de justicia ya corre «sin escena» contra un mundo falso [C `lurker_fairness_test.gd:5-8, 33-40`]: el port es mecánico y la prueba viaja con él. Texto puro, se compila con `cl.exe` y se prueba sin abrir el editor (la máquina es lo escaso).
- Descartado StateTree: es un asset binario; el MCP solo lo **inspecciona** (9 herramientas `get_*`, catálogo `:380-391`), así que un agente no puede crearlo ni revisarlo como texto. Además su orden de evaluación de transiciones no es el de `decide()` (gracia, tránsito, aviso, linterna, mirada, estado, vigilante [F]) y reproducirlo exigiría meter casi toda la lógica en tareas C++ de todos modos.
- Descartado Behavior Tree: mismo problema (7 herramientas de solo lectura, catálogo `:1034-1043`), más pizarra y servicios con tick propio, ajenos al paso fijo.
- Descartado portar dentro de actores con tipos de Unreal: pierde la prueba sin editor y mezcla centímetros y ejes en 6000 líneas de lógica.

**D2. Sentidos por interfaz, sin AIPerception.** Las mismas trazas, conos y cifras, pedidas a `ISenseWorld`. AIPerception tiene sus propios intervalos y edades de estímulo; la justicia depende de «visto este mismo tick» [F `fichas/lurker.md` §5]. El oído sigue siendo una función (`HearRoute`), llamada por quien hace el ruido en el anfitrión.

**D3. Navegación: cada criatura como hoy.**
- The Locust: rutas de la malla dinámica de Recast (decisión D10 de `mundo.md`) pedidas por `FindPathSync`; seguimiento, reintento cada 0,45 s, atasco y paso de puertas propios (`FDoorThreading`). Sin `AAIController`, `UPathFollowingComponent` ni multitudes: traen aceleración y evitación que cambian la sensación. Las hojas de puerta no afectan a la malla (la criatura las abre al pasar, como hoy con la máscara 9 [F]).
- The Lurker: su A* propio sobre salas, puertas y conductos y su cáscara matemática, portados tal cual. Descartado modelar techo y conductos como malla de navegación con enlaces: Recast no camina por techos, y hoy no hay malla alguna para ella.
- Paridad: las rutas de Recast no serán idénticas a las de Godot; se acepta igualdad con tolerancia en longitud (afecta al oído por ruta) y se vigila con casos volcados (C0).

**D4. Miembros de The Lurker: huesos movidos por código dentro de un `FAnimInstanceProxy` propio.**
- Por qué: es el equivalente directo del `SkeletonModifier3D`; todo queda en C++; no hace falta ningún grafo binario; el proxy permite evaluar sin Animation Blueprint [M `AnimInstanceProxy.h:659`].
- Descartado Control Rig: el MCP sí lo edita (44 herramientas, catálogo `:683-729`), pero 700 líneas de elección de apoyos, turnos de manos, codos en 12 pasos y dedos que se doblan hasta tocar serían cientos de nodos en un asset binario imposible de revisar; las sondas por trazas tendrían que venir igualmente de C++.
- Descartado nodo de animación propio (`FAnimNode_*`): exige un Animation Blueprint que lo aloje (binario) y un módulo de editor para el nodo de grafo.
- Descartado `UPoseableMeshComponent`: no evalúa clips; habría que reimplementar el muestreo.

**D5. Tinta: el mismo raymarch, más absorción real.** `M_LurkerInk` porta el sombreador (10 pasos, corte por profundidad de escena, derrame en la superficie) para que el tamaño y la lectura sean los de hoy. Encima, lo que Godot no podía: `M_LurkerInkVolume` quita luz de la niebla volumétrica dentro de la esfera (el haz de la linterna muere al entrar) y la luz bebida atenúa luces reales, con lo que Lumen oscurece también el rebote. Descartado solo niebla local negra: sin ruido ni derrame y desaparece cuando la calidad apaga la niebla volumétrica [F índice, `BaseScalability.ini:143,178`].

**D6. Polvo: Niagara y niebla local.** Hilos, escamas y trozos en tres sistemas con las cantidades de hoy; velo con `ULocalFogVolumeComponent` creado y animado por código (sin asset). Las manchas `puffs` quedan como reserva de calidad baja, igual que hoy. El azar del polvo sigue sin afectar a nada del juego.

**D7. Vista de eco: granos en el mundo, sin render a textura.** La vista ocupa toda la pantalla del cazador, así que no hace falta una segunda cámara ni `SceneCapture`: se porta la construcción actual (plano de oscuridad hijo de la cámara, nubes de granos en el mundo, orden por prioridad). El «qué se ve» sigue saliendo de `Sees()` de la mente.
- Descartado Niagara para los granos: el búfer en anillo de hasta 46 000 granos con edad, tipo y energía escritos desde C++ encaja 1:1 con datos por instancia; en Niagara pediría una interfaz de datos y un asset complejo.
- Descartado posprocesado para la oscuridad: los translúcidos se dibujan antes y quedarían tapados. La unidad R15 de `diseno/render.md` (que lo ponía como posprocesado) se ajusta a esto.
- Capas: lo que el cazador no debe ver se oculta por vista con `HiddenPrimitiveComponents` del controlador [M `UE:/Source/Runtime/Engine/Classes/GameFramework/PlayerController.h:327`].

**D8. Bots, telemetría y pruebas.**
- Pruebas puras (justicia parte B, cáscara, rutas, conductos, aviso, dificultad, contrato de modos): en `four_core_tests.exe`, sin editor, en paralelo.
- Pruebas con mundo (sentidos, justicia parte A, movimiento, captura): Automation en el editor con `-unattended -nullrhi`, una ejecución a la vez.
- La parte de `creature_contract_test` que lee el código como texto [F `fichas/pruebas.md`] pasa a ser un guion Python que escanea `Source/` (qué archivo nombra a qué).
- Bots: se portan a `FourBots` con el mismo esquema de `summary.json` y el vigilante de 120 s.
- Telemetría y `capture_log`: mismos campos, para comparar distribuciones entre los dos motores.

**D9. La conducta no lee nada del dibujo.** Las mejoras visuales (D5, apartado 5 y unidad C20) solo leen estado. Ninguna cifra de `FourCore` cambia por ellas; lo vigila que las pruebas puras no dependan de `FourCreatures`.

## 5. Prueba de concepto visual

**Entra** (una escena fija del piso 2, sin mente):
- `SK_Lurker` importado, colgado de un techo con el clip `idle`, material de piel y ojos.
- `FLurkerLimbs` reducido: las 7 manos apoyadas por trazas (sin pasos ni codos).
- Tinta (`M_LurkerInk` + volumen) y la luz bebida sobre las lámparas de una sala, para ver cómo responde Lumen.
- Una caída de polvo (hilos y velo) cruzada por la linterna.
- Medidas: ms de GPU de tinta y polvo, retraso de Lumen al beber la luz, sombra de los miembros con la linterna.

**No entra:** mentes, rutas, sentidos, The Locust (licencia), vista de eco, bots, red, capturas, voz.

## 6. Unidades de trabajo del port completo

∥ = puede ir en paralelo con las de su mismo bloque (archivos disjuntos, sin editor). «Editor» = necesita el único editor de Unreal, en serie.

| N.º | Unidad | Origen | Resultado | Aceptación |
|---|---|---|---|---|
| C0 | Volcados de referencia (única que ejecuta Godot; la lanza el director) | `tests/office/lurker_fairness_test.gd`, `tools/dev/lurker_route_probe.gd`, `lurker_telemetry.gd`, `hotel_locust.gd:730-766` | `golden/creatures/*.json`: resultado de las 200 aproximaciones, planes de ruta y tablas de cáscara en 3 semillas, 20 casos de `hear_route`, 10 de `door_threading`; capturas de tinta, polvo y eco | Los JSON se regeneran idénticos dos veces |
| C1 ∥ | Contrato | `creature.gd`, `null_creature.gd`, `creature_sight.gd` | `ICreature`, `FCreatureModes`, `FNullCreature`, `CreatureSight` | Los 81 nombres presentes; tabla de predicados por modo igual a `creature.gd:26-43` |
| C2 ∥ | Tablas | `difficulty.gd`, `noise_kinds.gd` | `FDifficultyTables`, `FNoiseKinds` | Port de `difficulty_test`; tabla `HEARD` igual |
| C3 ∥ | Mente y aviso de The Lurker | `lurker_brain.gd`, `lurker_warning.gd` | `FLurkerBrain`, `FLurkerWarning`, `ILurkerWorld` | Justicia parte B: las 200 aproximaciones dan el mismo veredicto una a una que C0; `Audit` sin faltas |
| C4 ∥ (tras `FManifest` de mundo) | Conductos y cáscara | `duct_graph.gd`, `lurker_shell.gd` | `FDuctGraph`, `FLurkerShell` | Port de `conduit_graph_test` y `lurker_shell_test`; tablas iguales a C0 |
| C5 (tras C4) | Rutas y motor | `lurker_routes.gd`, `lurker_motion.gd` | `FLurkerRoutes`, `FLurkerMotion` | Planes (nodos y coste) iguales a C0; port de `lurker_motion_test` |
| C6 ∥ | Mente de The Locust | `hotel_locust.gd`, `door_threading.gd` | Primero la lista de `ILocustWorld` (122 usos); luego `FLocustMind`, `FDoorThreading` | Mundo falso: patrulla → alerta → caza → pérdida a los 7 s → búsqueda con las cifras de la ficha; casos de puertas iguales a C0 |
| C7 ∥ | Sentidos de The Lurker | `lurker_senses.gd` | `FLurkerSenses` sobre `ISenseWorld` | Port de la parte sin escena de `lurker_senses_test` (20/4/35 m, cono 110°, olvido 12 s) |
| C8 (editor; tras mundo U11-U13) | Adaptador y base | — | `UFourCreatureWorld`, `AFourCreature`, canales | Automation: 20 casos de `HearRoute` con la decisión `audible` igual y longitud a ±10 %; `Sees` en 10 casos |
| C9 (editor; tras C5, C7, C8) | The Lurker jugable sin dibujo | `lurker.gd` | `ALurkerCreature` con caja de depuración; luz bebida y linternas | Justicia parte A y `lurker_forced_test` en un piso 2 montado; 10 min sin `stuck` |
| C10 (editor; tras C6, C8) | The Locust jugable sin dibujo | `hotel_locust.gd` (movimiento, puertas, armarios, ascensores) | `ALocustCreature`, `ULocustSlideMove` | Port de `creature_contract_test` (parte de conducta) y `creature_test`; semilla 81: ronda de 10 min sin atasco |
| C11 ∥ (guion) + editor | Importación de The Lurker | `tools/art/lurker/` | Guion de exportación e importación; `SK_Lurker`, 8 clips, materiales | Dos ejecuciones dan lo mismo; 142 huesos y 8 clips contados por `SkeletalMeshTools` |
| C12 (editor; tras C11) | Miembros | `lurker_limbs.gd`, `lurker_visual.gd` | `ULurkerAnimInstance`, `FLurkerAnimProxy`, `FLurkerLimbs` | Captura junto a la de Godot en 4 posturas (techo, dintel, pared, aviso); sonda: ningún codo atraviesa pared en 60 s de recorrido |
| C13 ∥ (tras C11) | Tinta, vapor y manchas | `lurker_darkness.gdshader`, `lurker_visual.gd:163-189, 381-399` | `LurkerInk.ush`, `M_LurkerInk`, `M_LurkerInkVolume`, `M_LurkerStain`, `ULurkerInkComponent` | Radio 0,95 × 1,62 m medido en captura; ms de GPU anotado; el haz se apaga dentro |
| C14 ∥ | Polvo de techo | `ceiling_dust.gd` y sus dos sombreadores | `FCeilingDust`, cuatro `NS_`, velo | Recuento de partículas 600/360/210, 8, 6-7; máximo 3 velos; captura con linterna |
| C15 (editor; tras C10 y pregunta 1) | Cuerpo de The Locust | `locust_visual.gd`, `locust_poser.gd`, `locust_look.gd` | `SK_Locust`, `ULocustAnimInstance` | Pasos emiten `footfall`; en la pose de captura la máscara queda a 0,17 m de la lente |
| C16 (tras C10) | Cazador humano | `locust_player.gd` | `ULocustDriver` | Golpe: enfriamiento 1,2 s, carga 0,3 s, alcance 3,2 m, 70°; el anfitrión valida |
| C17 (editor; tras C16) | Vista de eco | `echo_view.gd`, `echo_body.gd`, 3 sombreadores | `FEchoBudget`, `FEchoSpray`, `UEchoViewComponent`, 3 materiales | Port de `echo_test` (presupuesto, azar independiente, cuerpos solo si `Sees`); captura junto a la de Godot; ms anotado |
| C18 (tras C9, C10; con red) | Réplicas | `pack_state`, `follow_state`, `play_call` | `FCreatureNetState`, interpolación | Escenario de dos máquinas: la réplica a menos de 0,3 m del anfitrión con 0,1 s de retardo |
| C19 ∥ (tras C9, C10) | Bots y telemetría | `tools/bots/*`, `lurker_telemetry.gd` | Módulo `FourBots`, JSON | 3 bots, 10 pisos, `summary.json`; port de `lurker_bots_test`; reparto de veredictos comparable al de Godot |
| C20 (tras la prueba de concepto) | Pasada de aspecto | apartado 5 y D5 | Piel Substrate, brillo de ojos, sombras de miembros, desenfoque en la huida | Juicio del autor junto a la referencia; `four_core_tests.exe` sin cambios |

Bloques: C1, C2, C3, C4, C6, C7 arrancan a la vez (texto puro). C11, C13, C14 comparten editor: en serie entre sí, en paralelo con el texto.

## 7. Riesgos y cómo se detectan pronto

| Riesgo | Detección |
|---|---|
| La mente portada diverge en un sorteo o en un redondeo y cambia la sensación | C0 + C3: comparación aproximación por aproximación, no por totales |
| Rutas de Recast distintas de las de Godot cambian qué oye la criatura (umbral por longitud de ruta) | Casos de `hear_route` en C8, antes de portar los cuerpos |
| El paso fijo de 60 Hz no existe aún (es de otro dominio) | C8 no empieza sin él; mientras tanto las pruebas puras llaman `Step(1/60)` |
| Las trazas de los miembros solo pueden ir en el hilo de juego: un fotograma de retraso respecto al hueso | Prueba de concepto: manos sobre el techo en movimiento |
| Lumen tarda en reaccionar a la luz bebida (acumulación temporal) | Prueba de concepto: medir el retraso al beber una sala |
| TSR deja estelas en granos, tinta y polvo (hoy la vista de eco va sin suavizado temporal) | Captura en C13 y C17; si molesta, suavizado apagado en la vista del cazador |
| La niebla volumétrica se apaga en calidades baja y media: sin velo ni absorción | Reserva `puffs` y tinta de superficie, comprobadas en C13-C14 con esa calidad |
| Con `-nullrhi` los huesos no se actualizan y la captura o `echo_body` los leen | Forzar `AlwaysTickPoseAndRefreshBones` [M `UE:/Source/Runtime/Engine/Classes/Components/SkinnedMeshComponent.h:99`] en pruebas; comprobar en C15 |
| El MCP devuelve «Ok» con el error dentro y Niagara es su parte más frágil | C14 lee `GetSystemCompileState` y `GetStackIssues` (catálogo `:192-193`); reserva: guion Python |
| La vista del cazador renderiza la escena entera para taparla | Medir en C17 con el perfil «cazador» (sin GI ni reflejos) |
| Calcomanías con Substrate formato 0 (sin DBuffer [F índice]) | Mancha de prueba en la prueba de concepto |
| Modelo de The Locust no vendible | Pregunta 1 antes de C15 |

## 8. Preguntas para el autor

1. **El modelo de The Locust es CC BY-NC-ND** (no se puede vender ni modificar; `docs/ASSETS.md:110-111`). El port es el momento de sustituirlo. ¿Se hace uno propio por guion, como The Lurker (misma cadena de Blender, mismos 18 huesos para no tocar la animación por código), o lo aportas tú?
2. **¿Puede cambiar el aspecto de The Lurker** más allá de materiales y luz (más detalle en el modelo generado, piel, dientes), o la malla actual es la definitiva y solo se mejora cómo se ilumina?
3. **El versus (cazador humano y vista de eco) va al final del port** (C16-C17) porque no hace falta para el cooperativo. ¿De acuerdo, o lo quieres en la primera entrega jugable?

## 9. Qué conviene instalar o bajar

- Nada que descargar para este dominio: The Lurker es propio y el polvo, la tinta y el eco son procedurales.
- Plugins del motor a activar en el `.uproject`: `Niagara` (viene con el motor), y los de agentes ya previstos (`ModelContextProtocol`, `AllToolsets`). `ControlRig` y `StateTree` no hacen falta.
- Si la pregunta 2 abre la piel: mapas de detalle CC0 de Poly Haven o ambientCG (sin cuenta, https://polyhaven.com, https://ambientcg.com), por la misma ingesta que el dominio de materiales.
- Si la pregunta 1 pide modelo nuevo: se genera con Blender 5.2, ya instalado.

## 10. Sin comprobar

- No se ejecutó ni compiló nada. Ningún tiempo ni coste de GPU está medido.
- De las fichas, sin releer el código: todas las cifras de estados, sentidos, aviso, movimiento, miembros, polvo y eco; el contenido del glb (142 huesos, 8 clips); que `lurker_limbs` y `lurker_visual` no influyan en ninguna regla (lo dice la ficha; D9 depende de ello); el reparto anfitrión/réplica; que The Locust no use clips.
- La lista real de `ILocustWorld`: solo se contaron los 122 usos de `level.`; cuánto de `hotel_locust.gd` se separa limpio del movimiento es trabajo de C6.
- `lurker_senses.gd`, `lurker_routes.gd`, `lurker_motion.gd` y `lurker.gd` no se leyeron; su reparto entre `FourCore` y el adaptador se dedujo de los recuentos de `level.` y rayos.
- Los cuerpos de `creature_contract_test`, `echo_test`, `lurker_senses_test` y de `tools/bots/` no se leyeron.
- Motor, leído solo por firma: que `FAnimInstanceProxy::Evaluate` baste sin grafo en 5.8 con `SetAnimInstanceClass`; que `SolveTwoBoneIK` dé el mismo codo que la fórmula de Godot; que un material translúcido con `bDisableDepthTest` pueda leer SceneDepth y ordenarse solo por `TranslucencySortPriority`; rendimiento de ~10 000 escrituras de instancia por segundo en ISM; que un material de dominio Volume sobre una malla reste luz de la niebla volumétrica como se describe en D5; que `ULocalFogVolumeComponent` se pueda crear y animar en ejecución; que las hojas de puerta puedan excluirse de la malla dinámica sin efectos; colisión de partículas de Niagara para los trozos; Nanite en mallas con esqueleto (`r.Nanite.AllowSkinnedMeshes` existe, `UE:/Source/Runtime/Engine/Private/Rendering/NaniteResources.cpp:107`; estado no leído).
- Que las pruebas de Automation con trazas y malla de navegación funcionen con `-nullrhi`.
- Importación del glb de The Lurker por Interchange (huesos, clips, escala, eje) y el cambio de ejes para un esqueleto.
- Dónde vive el reloj de simulación de 60 Hz y el orden entre supervivientes y criatura: lo fija otro dominio; aquí solo se exige.
- Cómo quedan la voz (`lurker_voice.gd`, gruñidos de The Locust), las capturas (`game/app/capture_styles/`, `capture_score.gd`) y las alucinaciones (`game/app/hallucinations/`): son de audio y aplicación; este diseño solo les da `ICreature` y los `AnimInstance`.
- No se consultó la web: todo sale del repo, de las fichas y del motor local.
