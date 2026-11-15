> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: jugador, cámara, camcorder e interacción (Unreal Engine 5.8.4)

Escrito el 15 de noviembre de 2026. Solo lectura: no se ejecutó Godot ni Unreal ni se compiló nada. Marcas: **[G]** leído hoy en el código de Godot; **[M]** leído hoy en el motor (`UE:` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine`); **[F]** tomado de una ficha o informe de `.claude/specs/unreal/` sin releer el origen. Nombres de módulos y prefijo `Four` como en `diseno/mundo.md` y `diseno/render.md`.

## 1. Qué hay hoy en Godot

- **Cuerpo.** `CharacterBody3D` con cápsula de radio 0,3 y altura 1,8 (centro a 0,91; agachado 1,05 y 0,54). Capa 4, máscara 169 (mundo, hojas de puerta, criaturas, capa 8 «solo supervivientes») [F `fichas/jugador.md` §3.1; `game/player/player.tscn:5-19`]. Sin escaleras ni pendientes en las plantas [F `floor_definition.gd:24`].
- **Marcha** (`game/player/survivor_gait.gd`, 98 líneas, compartida con los bots) [G]: 2,0 / 3,8 / 6,0 m/s (:11-13), a gatas 1,2 y 0,6 (:38-39); aceleración 22 m/s² con `move_toward` **por eje del mundo** X y Z, también en el aire (:85-88); gravedad 20 a mano solo si no pisa suelo (:89); estamina 100, gasta 8/s, espera 3 s, recupera 6/s, agotado hasta 30 (:18-21, :66-76).
- **Tick de física a 60 Hz** (`game/player/hotel_player.gd:283-363`) [G], en este orden: agacharse, estamina, `accelerate` (lee el `is_on_floor()` del tick anterior), salto 5,4 m/s si pisa suelo (:314-316), `move_and_slide()` sin argumentos (:317), pose del avatar, pasos por distancia (:326-345), altura de ojos 1,64 / 0,9 / 0,62 a 5/s (:349), balanceo (:353-357), golpe de aterrizaje (:362).
- **Mirar** (:259-271) [G]: ratón `relative × 0,0022 / zoom` rad; mando con curva propia (`pad_feel.gd`, 92 líneas); tope ±1,45 rad; a gatas y escondido el giro se limita.
- **Cámara** [F §4]: FOV vertical 78°, zoom 1 a 6× (×1,42 por muesca, 2,4 log2/s), barril 0,05/zoom (`game/presentation/camcorder_look.gd`), mano (temblor, respiración, paso, muelle 110/13), suavizado propio entre ticks (`hotel_player.gd:617-622`), enfoque automático con rayo de 12 m.
- **Linterna** [F §5]: `SpotLight3D` suelta (`top_level`) que sigue a la mano a 9/s; energía 10, alcance 24 m, ángulo 32°, proyector radial de 7 paradas, sombra, niebla 0,35; calentamiento a 6/s con parpadeo; `torch_dim` lo baja The Lurker. Piloto rojo `OmniLight3D` de 0,7 m.
- **Camcorder.** Como vista: OSD, lente y cinta de `presentation.tscn` (dominios de render y de interfaz). Como objeto: modelo Panasonic NV-A3 (CC BY 4.0, `docs/ASSETS.md:54`), que en `game/` solo carga `game/app/executions.gd` [G, búsqueda]. Nadie la lleva en la mano en tercera persona.
- **Interacción** (`game/app/interaction.gd`) [F §7]: rayos desde la cámara de 2,0 m (máscara 1|8|16, con áreas), 2,4 m para puertas (1|8|64, con segundo intento desde dentro) y 8,0 m para compañeros (1|4|8); puerta a la espalda por distancia de 2,0 m; pulsación de hasta 0,28 s y mantener 1,0 s.
- **Entrada.** Sin `[input]` en `project.godot`; las acciones se crean en código (`game/services/settings_service.gd:336-380`) desde `KEYS` (:7 [G]) y las tablas de mando; zona muerta de stick 0,15 y de gatillo 0,5 [F §8].
- **Avatares** (`game/player/avatars/avatar_visual.gd` 778, `survivor_clips.gd` 211) [F §9]: tres FBX; 16 clips de Mixamo horneados por avatar (`tools/avatars/bake_survivor_clips.gd`, 408); la mezcla, la fase compartida y los pies anclados con IK de dos huesos están escritos a mano, hueso a hueso.
- **Remotos** (`game/net/remote_player.gd:240-267` [G]): estado a 20 Hz, interpolado con 0,1 s de retraso entre dos estados (posición, guiñada, cabeceo, vista, zoom, foco, velocidad); pasos por distancia. El estado lo empaqueta `game/net/match_net.gd:307` (`pack_local`) [G].

## 2. Cómo queda en Unreal

### 2.1 `FourCore/Player` (C++ sin cabeceras de Unreal, espacio de Godot: metros, Y arriba)

La regla de `diseno/mundo.md` §2.1: lo que es cuenta pura va aquí y se prueba con `cl.exe`, sin editor. Todas las cifras del apartado 1 viven en estos archivos como constantes con el mismo nombre que en GDScript.

| Archivo | Sale de | Firmas |
|---|---|---|
| `SurvivorGait.h` | `survivor_gait.gd` entero | `struct FGaitBody { FGdVec3 Velocity; double Stamina, RecoveryDelay; bool bExhausted, bCrouched, bCrawling, bCrawlBack, bOnFloor; }`; `bool Tire(FGaitBody&, bool bWantsRun, double Dt)`; `double Speed(bool bCrouched, bool bRunning, bool bCrawling, bool bBackwards)`; `void Accelerate(FGaitBody&, FGdVec3 Direction, bool bRunning, double Dt)`; `double Stride(bool, bool)`; `FFootfall Footfall(bool bCrouched, bool bRunning, bool bHard)` |
| `SurvivorTick.h` | `hotel_player.gd:283-363` | `struct FSurvivorInput { FGdVec2 Axis; bool bCrouch, bSprint, bJumpPressed; }`; `struct FSurvivorTickOut { bool bJumped; int StepIndex; double EyeHeight; FGdVec3 CameraRest; ... }`; `void PreMove(FSurvivorState&, const FSurvivorInput&, double Dt)`; `void PostMove(FSurvivorState&, FSurvivorTickOut&, double Dt)`. El barrido físico ocurre entre las dos, fuera de `FourCore` |
| `GdInput.h` | `Input.get_vector` de Godot | `FGdVec2 GetVector(double Left, double Right, double Up, double Down, double Deadzone)` |
| `PadFeel.h` | `pad_feel.gd` | `FGdVec2 Look(FPadState&, FGdVec2 Stick, double PadLook, double Zoom, double Dt)`; `bool Wants(...)`; `void Settle(...)` |
| `CamcorderLook.h` | `camcorder_look.gd` | `double ZoomFov(double Zoom)`; `double Barrel(double Zoom)`; `double RenderFov(double Aspect, double DesignFov, double Barrel)` |
| `Handheld.h` | `hotel_player.gd:446-490, 578-598` | `FGdVec3 Sway(FHandheldState&, const FHandheldIn&, double Dt)`; `double StepZoom(double Zoom, double Wanted, double Dt)` |
| `SurvivorClips.h` | `survivor_clips.gd` y `lock_feet` | `void Weights(const FClipIn&, TArray<FClipWeight>&)`; `double AdvancePhase(...)`; `void LockFeet(FFootLock&, ...)` (solo la cuenta; los huesos se tocan en `FourPlayer`) |

### 2.2 Módulo `FourPlayer` (Runtime; depende de `FourCore`, `FourWorld`, `EnhancedInput`, `AnimationCore`)

| Clase | Base | Qué hace |
|---|---|---|
| `AFourSurvivor` | `APawn` | Raíz `UCapsuleComponent` (radio 30, semialtura 90; agachado 52,5), tipo de objeto `ECC_Pawn`, bloquea `WorldStatic`, `DoorLeaf`, `Creature`, `SurvivorOnly` (la máscara 169, con los canales de `diseno/mundo.md:81-83`). Lleva los componentes de abajo. Una sola clase para local, remoto y bot: cambia quién escribe la entrada |
| `UFourSurvivorMovement` | `UPawnMovementComponent` | `void TickFixed(const FSurvivorInput&, double Dt)`: `PreMove`, `MoveAndSlide`, `PostMove`. `bool IsOnFloor() const`. `void MoveAndSlide(double Dt)` es el port de `CharacterBody3D::move_and_slide` (modo suelo) sobre `SafeMoveUpdatedComponent` [M `UE:/Source/Runtime/Engine/Classes/GameFramework/MovementComponent.h:316`], con los valores por defecto de Godot: 6 deslizamientos, suelo hasta 45°, pegado 0,1 m, margen 0,001 m [F §3.3] |
| `UFourCamcorderCamera` | `UCameraComponent` | Altura de ojos, balanceo, mano, asomarse e inclinarse; interpola entre el tick anterior y el actual con el alfa del reloj fijo; fija `FieldOfView` desde `CamcorderLook` y llama a `UFourPresentationSubsystem::SetZoom` (`diseno/render.md:45`) |
| `UFourTorch` | `USpotLightComponent` | Sin adjuntar a la cámara (transformación absoluta); sigue a la mano a 9/s, salta si se aleja 1,5 m; calentamiento, parpadeo, `TorchDim`. Los valores de luz salen de la fila `Torch` de `FourLightFixtures.h` (dominio de render) |
| `UFourInteraction` | `UActorComponent` | Port de `interaction.gd`: los tres rayos, la puerta a la espalda, pulsar y mantener. `FFourFocus Focused() const` |
| `IFourFocusable` | `UINTERFACE` (solo C++) | `EFourFocusKind FocusKind() const` (Door, Hide, Document, Hint, Panel, Teammate). Se declara donde viva `AFourDoor`; el componente no conoce las clases concretas |
| `UFourInputSubsystem` | `ULocalPlayerSubsystem` | Crea las `UInputAction` y el `UInputMappingContext` con `NewObject` al arrancar y los rellena desde los ajustes: `void ApplyBindings()`, `void Bind(FName Action, FKey)`, `void BindPad(FName Action, FKey)`. Sin assets |
| `AFourPlayerController` | `APlayerController` | Lee Enhanced Input, guarda el salto pulsado hasta el siguiente tick fijo, aplica el giro por evento (ratón) y por fotograma (mando) |
| `UFourAvatar` | `UPoseableMeshComponent` | Port de `avatar_visual.gd`: `void Configure(int32 Character, bool bLocalView)`, `void UpdatePose(FVector VelocityGd, bool bCrouched, double Dt, bool bGrounded)`, `void PoseCapture(...)`. Muestrea los `UAnimSequence` y escribe huesos |
| `UFourSteps`, `UFourKitSounds` | `UActorComponent` | Pasos (dos voces alternas, anticipo de 0,2 s) y clic de linterna y motor del zoom. El audio en sí lo fija el diseño de audio |
| `FSurvivorNetState` | `USTRUCT` | Los campos de `pack_local`. `AFourSurvivor::PushRemote(const FSurvivorNetState&, double ArrivalTime)` y la interpolación a 0,1 s con 12 estados. El transporte lo decide el diseño de red |

Reloj: el jugador no tiene `Tick` propio para la simulación. Expone `TickFixed(1/60)` y `TickFrame(Dt, Alpha)`, y los llama el reloj fijo común en orden explícito (lo define el diseño de la aplicación; hace falta según `briefs/experiencias.md` [F], porque el tick de Unreal es variable y sin orden dentro de un grupo).

Ejes: el cuerpo usa la convención de Unreal (frente +X). La guiñada pasa por `FFourSpace::Yaw` (`diseno/mundo.md:126`); con su regla de posición (x, z, y) × 100, guiñada de Godot θ equivale a guiñada de Unreal −90° − θ (cuenta propia, apartado 10).

### 2.3 Datos en texto

- Ajustes y teclas: el mismo JSON de ajustes de hoy (lo fija el diseño de servicios); `ApplyBindings` lo lee.
- `Content/Data/survivor_clips.json`: por avatar y clip, `speed`, `travel`, `phase0` y, en el salto, `takeoff`, `landing`, `settled`. Lo vuelca una vez un guion de Godot desde `assets/players/<id>/clips.res` (hoy son binarios [F §17]).
- Trazas de paridad: `Tests/Traces/player/<caso>.json` (apartado 4, D2).

### 2.4 Assets binarios (todos por guion, ninguno a mano)

| Asset | Cómo |
|---|---|
| `SK_Detective`, `SK_DetectiveWoman` y sus `USkeleton` | `Tools/import_avatars.py` con `UnrealEditor-Cmd -run=pythonscript` [F `briefs/agentes.md`] e Interchange FBX [M `UE:/Plugins/Interchange/Runtime/Source/Parsers/Fbx`] desde `assets/players/*/model.fbx` |
| 16 `UAnimSequence` (`A_Survivor_<clip>`) | El mismo guion, desde `models/mixamo/*.fbx` (30 archivos, fuera de git [G, listado]) sobre el esqueleto del detective |
| Materiales de avatar | Instancias del material maestro del dominio de materiales; las asigna el guion por nombre de ranura (`SkeletalMeshTools.set_material`, `mcp_catalogo.md:626`, o Python) |
| `PHYS_*` (solo si la captura lo pide) | `PhysicsAssetToolset.CreateFromMesh` (`mcp_catalogo.md:248`) |
| `SM_Camcorder` | Importación por guion del NV-A3; la usa la escena de muerte |
| IES `torch` | Lo genera `Tools/ies_from_profiles.py` del dominio de render (`diseno/render.md:58`) desde las 7 paradas de `hotel_player.gd:388-399` |

No hay Animation Blueprint, ni Blueprint de personaje, ni assets de Input Action, ni mapa propio de este dominio.

## 3. Correspondencia pieza a pieza

| Godot | Unreal | Dónde |
|---|---|---|
| `CharacterBody3D` + `CapsuleShape3D` | `AFourSurvivor` + `UCapsuleComponent` | `FourPlayer` |
| `survivor_gait.gd` | `SurvivorGait.h` | `FourCore/Player` |
| `_physics_process` del jugador | `SurvivorTick.h` + `UFourSurvivorMovement::TickFixed` | ambos |
| `move_and_slide()` | `UFourSurvivorMovement::MoveAndSlide` | `FourPlayer` |
| `can_stand` (cápsula a 0,95 m, máscara 1\|8\|128) | `OverlapAnyTestByObjectType` con `WorldStatic`, `DoorLeaf`, `SurvivorOnly` | `FourPlayer` |
| `Input.get_vector`, zonas muertas | `GdInput::GetVector` sobre valores crudos de Enhanced Input (sin modificadores) | `FourCore`, controlador |
| `InputMap` creado en `apply_bindings` | `UInputAction` y `UInputMappingContext` creados con `NewObject`; `MapKey` y `UnmapAll` [M `UE:/Plugins/EnhancedInput/Source/EnhancedInput/Public/InputMappingContext.h:228, 246`]; `AddMappingContext` [M `EnhancedInputSubsystemInterface.h:265`] | `UFourInputSubsystem` |
| `pad_feel.gd` | `PadFeel.h` | `FourCore` |
| `look_by` (ratón por evento, mando por fotograma) | `AFourPlayerController` | `FourPlayer` |
| `Camera3D` FOV 78 vertical, `near` 0,05, `far` 95 | `UFourCamcorderCamera`; `FieldOfView` horizontal calculado del aspecto (110,4° a 16:9 [F]); plano cercano 5 cm (`diseno/render.md:36`) | `FourPlayer`, ini |
| `camcorder_look.gd` | `CamcorderLook.h` | `FourCore` |
| Zoom, mano, balanceo, asomarse, inclinarse | `Handheld.h` + `UFourCamcorderCamera` | ambos |
| `smooth_camera` (tick anterior y actual) | `TickFrame(Dt, Alpha)` | `FourPlayer` |
| Enfoque automático (rayo de 12 m, `CameraAttributesPractical`) | El rayo en `UFourCamcorderCamera`; la distancia va al volumen de posprocesado de render | interfaz con render |
| `cull_mask` sin capa 2 (cuerpo propio oculto, con sombra) | `SetFirstPersonPrimitiveType(WorldSpaceRepresentation)` en el avatar del jugador local [M `UE:/Source/Runtime/Engine/Classes/Components/PrimitiveComponent.h:159-161, 2120`] | `UFourAvatar` |
| `SpotLight3D` + proyector radial | `UFourTorch` con `IESTexture` [M `LightComponent.h:219`], `VolumetricScatteringIntensity` y `bCastVolumetricShadow` [M `LightComponentBase.h:120, 82`], `SourceRadius` 3 cm [M `PointLightComponent.h:45`], conos [M `SpotLightComponent.h:23, 27`] | `FourPlayer` + tabla de render |
| `plain_beam()` (otra linterna fuera de Forward+) | No se porta: un solo renderizador | — |
| Piloto `OmniLight3D` | `UPointLightComponent` sin sombra, 70 cm | `AFourSurvivor` |
| `PhysicsRayQueryParameters3D` con máscara | `LineTraceSingleByObjectType` con la lista de tipos de objeto equivalente a la máscara | `UFourInteraction` |
| `collide_with_areas` | Volúmenes con tipo de objeto `Interactive`, solo consulta | `FourWorld` |
| `avatar_visual.gd` + `survivor_clips.gd` | `UFourAvatar` + `SurvivorClips.h`; IK con `AnimationCore::SolveTwoBoneIK` [M `UE:/Source/Runtime/AnimationCore/Public/TwoBoneIK.h:69`] | ambos |
| `clips.res` por avatar | 16 `UAnimSequence` del detective, leídos con `UAnimSequence::GetBoneTransform` [M `AnimSequence.h:508`] y aplicados por nombre de hueso | `UFourAvatar` |
| `bake_survivor_clips.gd` | `Tools/import_avatars.py` + volcado de metadatos a JSON | guion |
| `remote_player.gd` | `AFourSurvivor` en modo remoto + `FSurvivorNetState` | `FourPlayer` |
| `kit_sounds.gd`, pasos | `UFourKitSounds`, `UFourSteps` | `FourPlayer` |
| `observer_view.gd`, `watch_over` | `AFourObserverPawn` (cámara libre a 22 m/s) y `SetViewTarget` sobre el compañero | `FourPlayer` |
| Señales `noise` y `hiding_changed` | Delegados multidifusión con los mismos parámetros | `AFourSurvivor` |

Acciones (mismos nombres, creadas en `UFourInputSubsystem`):

| Acción | Tipo | Teclado y ratón | Mando |
|---|---|---|---|
| `forward`, `backward`, `left`, `right` | Axis1D | W, S, A, D | Stick izquierdo (4 semiejes) |
| `look_left/right/up/down` | Axis1D | — | Stick derecho |
| `look` (nueva, solo ratón) | Axis2D | `Mouse2D` | — |
| `sprint` | Bool | Mayús izquierda | L3, con alternar |
| `jump` | Bool | Espacio | Botón inferior |
| `crouch` | Bool | Ctrl izquierdo | Botón derecho, con alternar |
| `interact` | Bool | E | Botón izquierdo |
| `flashlight` | Bool | F | Botón superior |
| `sheet` | Bool | Tab | Back y panel táctil |
| `lean_left`, `lean_right` | Bool | 1, 3 | Cruceta izquierda y derecha |
| `zoom_in`, `zoom_out` (hoy eventos sueltos) | Bool | Rueda arriba y abajo | Cruceta arriba y abajo |
| `locust_trace` | Bool | Q | — |

## 4. Decisiones

**D1. Movimiento propio que replica `move_and_slide`, no `CharacterMovementComponent` ni Mover.**
- El movimiento del juego son unas 30 líneas: `move_toward` por eje del mundo (la diagonal acelera √2 veces más que el eje: es parte de la sensación), control total en el aire, gravedad a mano y un salto que asigna 5,4 [G `survivor_gait.gd:85-89`, `hotel_player.gd:314-317`]. Portarlo tal cual es más corto y más seguro que convencer a otro modelo de que dé lo mismo.
- Descartado `UCharacterMovementComponent` ajustado: su modelo acelera a lo largo del vector de entrada con fricción y frenado, sube escalones de 45 cm y parte el paso con `MaxSimulationTimeStep` [F `briefs/experiencias.md`; M `CharacterMovementComponent.h:748`]. Igualarlo exige sobrescribir `CalcVelocity` [M :1558] o un modo `PhysCustom` [M :2007] y aun así quedan suelo, repisas, caída y red por neutralizar. `ACharacter` crea ese componente siempre [M `UE:/Source/Runtime/Engine/Private/Character.cpp:111`], por eso la base es `APawn`.
- Descartado Mover: Experimental en 5.8 [M `UE:/Plugins/Experimental/Mover/Mover.uplugin:15`] y sin proyecto publicado [F `briefs/ue58.md`].
- Lo que se pierde (predicción de red de `ACharacter`, agacharse y saltar de serie) no se usa: hoy el cliente manda su estado a 20 Hz y los demás lo interpolan.
- Alcance del port de `move_and_slide`: solo lo que el juego ejercita (suelo plano, paredes, marcos, hojas de puerta, techo al saltar). Sin plataformas móviles salvo que el ascensor lo pida (apartado 10).

**D2. La paridad se demuestra con trazas, en dos niveles.**
- Nivel 1, cuenta pura (sin motor): un guion de Godot (`tools/dev/player_trace.gd`, nuevo, lo lanza el director en serie) reproduce una lista de entradas por tick sobre suelo plano sin obstáculos y escribe por tick posición, velocidad, suelo, estamina, `step_phase`, altura de ojos y posición de cámara. La prueba de `FourCore` aplica las mismas entradas a `SurvivorTick` con un suelo analítico. Tolerancia: 1 mm en posición y 1e-3 en el resto (Godot usa coma flotante de 32 bits). Casos: arrancar y parar, diagonal, medio stick, correr hasta agotarse y recuperar, salto parado y en carrera, agacharse en marcha, a gatas adelante y atrás.
- Nivel 2, con colisión (Automation en Unreal, `-nullrhi`): la misma sala de prueba construida en los dos motores (caja de 8 m, pared a 45°, marco de puerta de la anchura real, techo bajo). Casos: rozar pared a 30°, 45° y 80°, esquina interior, cruzar el marco en diagonal, saltar bajo el techo, levantarse bajo el techo. Tolerancia: 2 cm en posición, 0,1 m/s en velocidad, ±1 tick en los cambios de suelo y la misma lista de ticks con pisada.
- El nivel 1 es la garantía de «misma sensación»; el nivel 2 acota la diferencia entre motores de física, que no puede ser cero.

**D3. Paso fijo de 60 Hz con interpolación propia.** Igual que hoy (`tick_before`, `tick_after`). El salto pulsado se guarda hasta el siguiente tick. El ratón gira al llegar el evento y el mando en cada fotograma, como en Godot.

**D4. Primera persona: sin malla de primera persona; el cuerpo propio es `WorldSpaceRepresentation`.** Hoy no hay brazos ni objeto en pantalla: la camcorder es la vista. El avatar propio no se dibuja en su cámara pero da sombra, y ese tipo de primitiva hace exactamente eso (oculta al dueño y mantiene la sombra con sombras virtuales [M `PrimitiveComponent.h:159-161`]). `FirstPersonFieldOfView` y `FirstPersonScale` [M `CameraComponent.h:52, 60`] quedan sin usar hasta que haya algo en la mano (pregunta 2). Descartado `bOwnerNoSee` con `bCastHiddenShadow` a mano: el motor ya lo resuelve.

**D5. FOV.** Se conserva el vertical de 78°: el componente calcula el horizontal con el aspecto real en cada fotograma, y con zoom usa `CamcorderLook`. Una prueba mide el ángulo vertical real a 16:9, 21:9 y 4:3 (el motor tiene su propia regla de eje, apartado 10).

**D6. Linterna: foco con IES generado, sombra y volumétrica; sin función de luz.** El perfil radial de 7 paradas es simétrico, y eso es lo que describe un IES; además es texto y lo genera un guion. Descartada la función de luz (`LightFunctionMaterial` [M `LightComponent.h:205`]): pide un material más y no aporta nada a un haz simétrico; queda como salida si se quiere suciedad en el cristal. La intensidad en unidades físicas la calibra render en su tabla; este dominio solo multiplica (calor², vaivén, `TorchDim`). La linterna remota usa la misma fila (hoy 8 frente a 10, discrepancia 3 de la ficha).

**D7. La camcorder como vista es de render e interfaz; como objeto, una malla estática.** Este dominio entrega zoom, fracción de zoom, estamina, distancia de foco y giro por fotograma (para el desenfoque de movimiento). No se añade camcorder a la mano de los avatares sin que el autor lo pida.

**D8. Interacción: consultas por tipo de objeto y una interfaz mínima.** La máscara de Godot es una lista de capas de objeto, y `LineTraceSingleByObjectType` es lo mismo; no se inventan canales de traza. La lógica de pulsar o mantener sigue centralizada en `UFourInteraction` (como en `interaction.gd`); descartada una interfaz `Interact()` por actor, que repartiría los tiempos de 0,28 s y 1,0 s por cada clase. El segundo intento «desde dentro» de la puerta se sustituye por comprobar si el rayo empieza dentro de la hoja.

**D9. Enhanced Input creado en C++, sin assets y sin modificadores.** Es lo que ya hace Godot: acciones creadas al arrancar y reasignables. Zonas muertas y curvas se portan en `FourCore`, porque el modificador de serie (`UInputModifierDeadZone`, umbral 0,2 [M `UE:/Plugins/EnhancedInput/Source/EnhancedInput/Public/InputModifiers.h:170-193`]) no es la cuenta de `get_vector`. Descartados los assets de Input Action y de contexto: binarios que un agente no puede revisar. Descartado el sistema de teclas reasignables de Enhanced Input: el juego ya guarda las suyas.

**D10. Avatares: `UPoseableMeshComponent` y pose calculada en C++; sin Animation Blueprint.**
- El avatar de Godot ya es esto: pesos, fase y pies anclados calculados a mano y escritos hueso a hueso. `SetBoneTransformByName` [M `UE:/Source/Runtime/Engine/Classes/Components/PoseableMeshComponent.h:34`] permite el port línea a línea, con las mismas pruebas (`avatar_test.gd`).
- Descartado el Animation Blueprint: asset binario con grafo; el catálogo del MCP no tiene herramientas de AnimGraph (búsqueda de «animation blueprint» y «anim_blueprint» en `mcp_catalogo.md`, sin resultados) y la edición fina de grafos por MCP es frágil [F `briefs/agentes.md`].
- Descartado `UAnimInstance` en C++ con un grafo mínimo: sigue pidiendo el asset y un nodo propio con módulo de editor. Es la salida si más adelante hacen falta tela, LOD de esqueleto o evaluación en hilos.
- Los clips se importan una sola vez sobre el esqueleto del detective; la detective usa los mismos por nombre de hueso (los dos son `mixamorig_*` [F §9.2]) con sus propias longitudes en reposo, que es lo que hace hoy el horneado.

**D11. Tercera persona y sincronía: mismo estado, mismo ritmo.** 20 Hz, 0,1 s de retraso, 12 estados, pasos por distancia. No se usa el suavizado de red del motor para personajes.

## 5. Prueba de concepto visual

**Entra** (lo mínimo para juzgar la imagen andando por ella):
- `SurvivorGait.h`, `SurvivorTick.h` y `UFourSurvivorMovement` con la cuenta real: el autor nota si se siente igual.
- Cámara a 78° con zoom y altura de ojos; balanceo básico. Ratón y teclado, y mando con stick directo.
- Linterna con IES, sombra, volumétrica, seguimiento de mano y calentamiento.
- Un detective estático en pose de reposo, para ver la linterna sobre un personaje, y el cuerpo propio como `WorldSpaceRepresentation` para ver su sombra.

**No entra:** interacción, puertas, escondites, asomarse, a gatas, estamina en el OSD, `pad_feel` completo, reasignación, clips y pies anclados, remotos, pasos, observador, captura.

**Decide:** si la sombra del cuerpo propio funciona con MegaLights; si la linterna hace ruido al moverse (`diseno/render.md:205`); la calibración de la sensibilidad del ratón.

## 6. Unidades de trabajo del port completo

∥ = puede ir en paralelo con las demás ∥ de su bloque (archivos disjuntos, sin editor). Las que piden editor van en serie, una a la vez.

| N.º | Unidad | Origen | Resultado | Prueba de aceptación |
|---|---|---|---|---|
| J1 | Guion de trazas en Godot | `hotel_player.gd`, `survivor_gait.gd` | `tools/dev/player_trace.gd` y los JSON de D2 (niveles 1 y 2) | Dos ejecuciones dan los mismos JSON byte a byte |
| J2 ∥ | Marcha | `survivor_gait.gd` | `SurvivorGait.h` | Prueba con `cl.exe`: estamina 12,5 s hasta agotarse; tabla de velocidades |
| J3 ∥ | Entrada de Godot | `Input.get_vector` (fuente de Godot 4.7), `pad_feel.gd` | `GdInput.h`, `PadFeel.h` | Casos fijos: 0,15 da cero; medio stick; borde con ×1,8 a los 0,6 s |
| J4 ∥ | Lente y mano | `camcorder_look.gd`, `hotel_player.gd:446-490, 578-598` | `CamcorderLook.h`, `Handheld.h` | FOV 78 a zoom 1 y unos 15,4° a zoom 6; recorrido de zoom de 1,08 s |
| J5 | Tick del superviviente (tras J2) | `hotel_player.gd:283-363` | `SurvivorTick.h` | Trazas de nivel 1 dentro de tolerancia |
| J6 | Cuerpo y movimiento (tras J5; editor para la prueba) | `player.tscn`, `move_and_slide` de Godot | `AFourSurvivor`, `UFourSurvivorMovement` | Trazas de nivel 2 dentro de tolerancia; `can_stand` bajo techo |
| J7 ∥ | Entrada | `settings_service.gd:7-48, 336-380` | `UFourInputSubsystem`, `AFourPlayerController` | Las pruebas de `scene_contract_test.gd:56-99` portadas: acciones, alternar, reasignar |
| J8 ∥ | Cámara | `hotel_player.gd:349-362, 617-661` | `UFourCamcorderCamera` | FOV vertical medido 78° en tres aspectos; sin saltos a 144 fps con tick de 60 |
| J9 ∥ | Linterna y piloto | `hotel_player.gd:184-214, 365-439, 641-661` | `UFourTorch` | Con R10 de render: sombra y haz en niebla; salta si se aleja 1,5 m; calentamiento en 1/6 s |
| J10 | Interacción (tras puertas, U13 de mundo) | `interaction.gd` | `UFourInteraction`, `IFourFocusable` | Puerta a 2,4 m sí y a 2,5 m no; puerta a la espalda; toque de 0,28 s frente a mantener 1,0 s |
| J11 | Escondites, asomarse, inclinarse, a gatas | `hotel_player.gd:263-270, 686-766`, `hiding_place.gd` | Estados en `AFourSurvivor` | Casos de `survival_test.gd:309-408` portados |
| J12 | Importación de avatares (editor, guion) | `assets/players`, `models/mixamo`, `clips.res` | `Tools/import_avatars.py`, `survivor_clips.json`, assets de 2.4 | El guion corre dos veces desde cero y deja los mismos assets; 16 clips, 65 huesos en el detective |
| J13 ∥ | Mezcla de clips y pies | `survivor_clips.gd`, `avatar_visual.gd:240-331` | `SurvivorClips.h` | Prueba con `cl.exe`: pesos suman 1; fase continua al cambiar de marcha |
| J14 | Avatar (tras J12 y J13) | `avatar_visual.gd` | `UFourAvatar` | `avatar_test.gd` portado: pie plantado sin deslizar, caderas bajan al agacharse, salto |
| J15 ∥ | Pasos y sonidos del equipo | `hotel_player.gd:326-345, 400-431`, `kit_sounds.gd` | `UFourSteps`, `UFourKitSounds` | Desfase entre impacto y pisada de 1,05 fotogramas como máximo (`hotel_test.gd:412`) |
| J16 | Remotos (tras J14 y el diseño de red) | `remote_player.gd`, `match_net.gd:307` | `FSurvivorNetState`, modo remoto | Dos instancias: el remoto sigue al local con 0,1 s y sin saltos; linterna y agachado llegan |
| J17 ∥ | Observador y mirar al compañero | `observer_view.gd`, `revival.gd:227-292` | `AFourObserverPawn`, vista de compañero | Vuela a 22 m/s y ×4; al mirar a un compañero la vista es la suya suavizada |
| J18 | Pose de captura y sangre (tras el diseño de capturas) | `avatar_visual.gd:386-421, 617-778` | `UFourAvatar::PoseCapture` | Casos de `capture_test.gd` que tocan al avatar |

Bloques: J1 a solas (Godot). Después J2, J3, J4, J7, J13 en paralelo. Después J5, luego J6. Con J6 hecho: J8, J9, J15, J17 en paralelo. J12 en cualquier hueco de editor.

## 7. Riesgos y cómo se detectan pronto

| Riesgo | Detección temprana |
|---|---|
| Los barridos de Chaos no dan lo mismo que los de Godot en esquinas y marcos (el jugador se engancha o atraviesa) | Trazas de nivel 2 en J6, antes de cualquier otra pieza del cuerpo |
| La sombra del cuerpo propio con `WorldSpaceRepresentation` no sale con MegaLights (el motor la documenta para sombras virtuales) | Prueba de concepto; salida: sombra virtual solo para la linterna propia o renunciar a la sombra propia |
| El ratón gira distinto (unidades de `Mouse2D` frente a píxeles de Godot, aceleración del sistema) | J7: contar las unidades de una vuelta completa en los dos motores con el mismo ratón |
| El ascensor mueve al jugador y el movimiento propio no tiene plataformas | Leer `lifts` antes de J6; si lo pide, añadir la velocidad de plataforma de Godot al port |
| Interchange importa mal los FBX (escala ×100, huesos hoja, 28 MB de la detective, materiales) | J12 pronto, en un hueco de editor; comprobar 1,78 m de altura y nombres de hueso |
| `UPoseableMeshComponent` con 4 o 5 cuerpos y pose en el hilo de juego cuesta demasiado, o no da sombra o velocidades correctas para el desenfoque | Medir en J14 con cinco avatares; salida: nodo de animación propio (D10) |
| Pulsaciones perdidas o dobles entre fotograma y tick fijo (salto, linterna) | Prueba de J7 a 30 y 144 fps con la misma lista de entradas |
| El personaje por defecto (`character = 2`, Exploradora) no puede entrar: CC BY-SA choca con el EULA de Unreal [F `briefs/experiencias.md`; `docs/ASSETS.md:33`] | Pregunta 1, antes de J12 |
| El rayo que nace dentro de una hoja de puerta no devuelve la puerta | Caso propio en J10 |

## 8. Preguntas para el autor

1. La Exploradora (`realistic_female`, CC BY-SA) no puede ir en un juego de Unreal a la venta. ¿Se queda el juego con los dos detectives, o se busca un tercer personaje (CC0 o CC BY, con esqueleto compatible con Mixamo)? Hoy es el personaje por defecto.
2. ¿Quieres que en Unreal se vean en tercera persona la camcorder y la linterna en las manos de los compañeros? Hoy no se ven; sería una mejora visual, no un cambio de reglas, pero pide poses de brazos nuevas.
3. Los clips de Mixamo se bajaron con tu cuenta y siguen fuera de git. ¿Siguen en `models/mixamo/` en esta máquina para el guion de importación, o hay que volver a bajarlos? (Hoy están: 30 FBX.)

## 9. Herramientas, plugins o assets

| Qué | Fuente | Licencia y condición |
|---|---|---|
| Nada que instalar | — | Enhanced Input, Interchange (FBX e IES), `AnimationCore` y `UPoseableMeshComponent` vienen con 5.8.4 |
| Código de referencia de `move_and_slide` y `Input.get_vector` | https://github.com/godotengine/godot (`scene/3d/physics/character_body_3d.cpp`, `core/input/input.cpp`), etiqueta 4.7.2 | MIT: se puede portar con su aviso de copyright en el archivo |
| Clips de Mixamo | Ya en `models/mixamo/` | Uso comercial permitido; no redistribuir los archivos sueltos (`docs/ASSETS.md:37`). Los FBX siguen fuera de git |
| Detective y Detective Woman | Ya en `assets/players/` | CC BY 4.0, con atribución (`docs/ASSETS.md:31-32`) |
| Camcorder NV-A3 | Ya en `source_assets/camcorder/` | CC BY 4.0 (`docs/ASSETS.md:54`) |
| Tercer personaje (si el autor lo quiere) | Por decidir | Solo CC0 o CC BY; sin crear cuentas |

## 10. Sin comprobar

- Nada se ejecutó ni compiló: todas las tolerancias de D2 son propuestas; las reales salen de J5 y J6.
- El algoritmo interno de `move_and_slide` y de `Input.get_vector` de Godot 4.7.2 no se leyó (no hay fuente de Godot en el repo, solo la referencia de clases). Los valores por defecto de `CharacterBody3D` vienen de la ficha.
- Si el ascensor mueve al jugador dentro de la cabina (plataforma móvil) o lo traslada de otro modo: no leído.
- Si hay umbrales, zócalos o resaltes en el suelo que hoy el pegado de 0,1 m salva: no comprobado.
- La regla de eje de aspecto del motor para `FieldOfView` (el informe cita `CameraComponent.h:38-44` y `BaseEngine.ini:2899-2900`): no releída; por eso D5 lo mide con una prueba.
- La fórmula de guiñada −90° − θ es cuenta propia sobre la regla de `diseno/mundo.md` D8; manda `FFourSpace`.
- Que `spot_angle` de Godot (32°) y `OuterConeAngle` de Unreal sean ambos semiángulo; la equivalencia de energía 10 a candelas o lúmenes (la fija render mirando).
- Que `WorldSpaceRepresentation` dé sombra con MegaLights y con la linterna propia pegada a la cámara; que `UPoseableMeshComponent` escriba velocidades de movimiento correctas y admita Nanite o LOD.
- Unidades de `Mouse2D` frente a `relative` de Godot; el nombre de la tecla del panel táctil del mando en Unreal.
- Que la detective comparta jerarquía con el esqueleto del detective lo bastante para aplicar los clips por nombre; contenido de los FBX y de `clips.res` (binarios, no abiertos).
- Que Interchange importe estos FBX sin ventana y de forma repetible; las herramientas exactas de importación del MCP (`AssetTools`) no se revisaron: el diseño usa Python.
- `interaction.gd:260-431`, `hiding_place.gd`, `pad_feel.gd`, `camcorder_look.gd`, `avatar_visual.gd`, `survivor_clips.gd` y `observer_view.gd` no se releyeron hoy: sus cifras vienen de `fichas/jugador.md`. Releídos hoy: `survivor_gait.gd` entero, `hotel_player.gd:228-372`, `remote_player.gd:225-290`, `match_net.gd:303-318`, `settings_service.gd:6-7`.
- Las interfaces con otros dominios (`UFourPresentationSubsystem::SetZoom` y el foco, la fila `Torch`, el reloj fijo, el transporte de red, `AFourDoor`) son las que esos diseños nombran o tendrán que nombrar; no están cerradas entre sí.
