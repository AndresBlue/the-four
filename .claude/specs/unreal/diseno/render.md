> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: render, iluminación y posprocesado (Unreal Engine 5.8.4)

Escrito el 15 de noviembre de 2026. No se ejecutó Godot ni Unreal y no se compiló nada. `UE:` es `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine`. Marcas: [M] leído hoy en el motor local, [G] leído hoy en el código de Godot, [F] tomado de una ficha o informe de `.claude/specs/unreal/` sin volver a comprobarlo, [D] deducción o propuesta mía. Todas las cifras de milisegundos y de memoria de Unreal son objetivos por medir, no medidas.

## 1. Qué hay hoy en Godot

- **Cadena** [F `fichas/render.md` §1]: escena 3D a escala interna 0,5 a 1,0; dos efectos de compositor antes del antialias temporal (`game/presentation/camera/motion_blur_effect.gd`, `camcorder_effect.gd`: medidor, iris, smear CCD, halo, fantasmas, rodilla de vídeo); TAA o FSR; curva tonal lineal (AgX si no hay etapa HDR); después, en capas de lienzo, lente (`game/presentation/lens.gdshader`, capa 2), OSD (3), interfaz (4) y filtro de cinta (`game/presentation/shaders/analog.gdshader`, capa 5), que graba todo lo anterior; los menús (capa 6) quedan fuera de la cinta.
- **Luz**: ambiente cero (`game/presentation/hotel_environment.tres:9`). Hotel: una `OmniLight3D` con sombra por sala (energía 4,25 o 4,5), apliques, lámparas de mueble y carteles (`game/world/hotel/hotel_geometry.gd:1348-1451, 2097-2125`). Oficina: luz de sala más dos focos por tubo, con un tope de 32 con sombra (`game/world/office/office_geometry.gd:195, 2569` [G]). Linterna: foco de energía 10, 32 grados, alcance 24 m, niebla 0,35 (`game/player/player.tscn:31-38` [G]). Perfiles fotométricos generados por código y color por temperatura contra un blanco fijo de cámara de 3200 K (`game/world/hotel/lighting.gd:26-33, 66-123` [F]).
- **Rebote y reflejos** [F §12]: un VoxelGI por sala horneado al cargar (solo Alto y Ultra, 8 visibles), sondas de reflexión por sala (24 visibles, atlas de 64 plazas) y SSR.
- **Contención** [F §11]: un atlas de sombras para todo (2048 a 8192); lo que no cabe alumbra sin sombra y cruza paredes; 16 capas de render por sala para taparlo.
- **Aire** [F §13]: niebla volumétrica de 48 a 96 celdas, 1960 motas en un MultiMesh en la oficina, partículas de polvo en el hotel.
- **Gradación** [G]: oficina `GRADE` = iris 0,05, blanco (1,2; 1,0; 1,15), contraste 1,16, saturación 0,85 (`office_geometry.gd:203`); hotel iris 0,065 y rodilla 0,72 (`camcorder_effect.gd:37, 73`); aire por planta 0,008 / 0,02 / 0,02 (`office_geometry.gd:210`).
- **Calidad y coste** [F §16, §20]: cinco presets y dos renderizadores (Forward+ y Compatibility). Alto: unos 10 ms de GPU y 2,0 a 2,2 GB de VRAM a 1080p en la RTX 4060 Ti; en el piso 2 Alto no pasa la prueba de CPU a 60 FPS. Muy bajo funciona en gráfica integrada (modelo, no medida).
- **Sombreadores** [F `fichas/shaders.md`]: 30 `.gdshader` (2 de pantalla completa, 1 de niebla, 4 que leen profundidad) y 10 bloques de cómputo GLSL dentro de GDScript.

## 2. Cómo queda en Unreal

### 2.1 Ajustes de proyecto (texto, `Config/DefaultEngine.ini`, sección `/Script/Engine.RendererSettings`)

| Ajuste | Valor | Estado leído en el motor |
|---|---|---|
| `r.DynamicGlobalIlluminationMethod`, `r.ReflectionMethod` | 1 y 1 (Lumen) | Lo escribe el asistente de proyecto nuevo [F `briefs/ue58.md` §4.1, `GameProjectUtils.cpp:119-130`] |
| `r.RayTracing` | True | Necesario para Lumen por hardware y MegaLights; exige SM6 y reinicio del editor [F `RendererSettings.h:673-677`] |
| `r.RayTracing.EnableOnDemand` | 1 (valor de fábrica, solo lectura) | Permite apagar el trazado en ejecución con `r.RayTracing.Enable` [M `UE:/Source/Runtime/RenderCore/Private/RenderUtils.cpp:47-55`; `UE:/Source/Runtime/Engine/Private/Rendering/RayTracingGeometryManager.cpp:34-38`] |
| `r.RayTracing.RayTracingProxies.ProjectEnabled` | True | Proxies de trazado para mallas Nanite [M `RenderUtils.cpp:58-60`] |
| `r.Lumen.HardwareRayTracing` | 1 | Valor de fábrica 1 [M `UE:/Source/Runtime/Renderer/Private/Lumen/LumenHardwareRayTracingCommon.cpp:17`] |
| `r.Lumen.HardwareRayTracing.LightingMode` | 0 de base; 2 solo en el preset más alto | Tres modos [M `LumenHardwareRayTracingCommon.cpp:33`]; la escalabilidad solo permite iluminar en el impacto con GI en Epic [M `UE:/Config/BaseScalability.ini:363, 410, 458`] |
| `r.MegaLights.EnableForProject` | True | Fábrica 0 [M `UE:/Source/Runtime/Renderer/Private/MegaLights/MegaLights.cpp:27`] |
| `r.MegaLights.DefaultShadowMethod` | 0 (trazado de rayos) | 0 = coste fijo y sombras de área correctas; 1 = sombras virtuales con coste por luz [M `MegaLights.cpp:372-380`] |
| `r.Shadow.Virtual.Enable` | 1 | Sigue haciendo falta para el nivel sin trazado [F §4.4] |
| `r.GenerateMeshDistanceFields` | True | Respaldo de Lumen por software [F §4.1] |
| `r.AllowStaticLighting` | False | Sin luz horneada; habilita efectos de primera persona [F §4.9] |
| `r.Substrate`, `r.Substrate.ProjectGBufferFormat` | True, 0 | Lo que escribe el asistente; se fija una vez, cambiarlo recompila todo [F §4.6] |
| `r.AntiAliasingMethod` | 4 (TSR) | Valor de fábrica [F §4.8] |
| `r.DefaultFeature.AutoExposure` y exposición local | Automática; exposición local neutra (1,0) | El asistente pone exposición local 0,8 [F §4.11]; aquí se anula en el volumen |
| `NearClipPlane` (`/Script/Engine.Engine`) | 5 | Fábrica 10 [M `UE:/Config/BaseEngine.ini:361`]; la plantilla de primera persona usa 5 [F §4.11] |
| Formatos de sombreador | Solo DX12 con SM6 | Sin SM6 no hay Nanite ni trazado [F §4.5] |

### 2.2 Código C++ (todo texto)

Módulo de juego `TheFour` (nombre provisional, lo fija el diseño de la aplicación) y un módulo pequeño `TheFourRender` con fase de carga `PostConfigInit`, porque registra la carpeta de sombreadores del proyecto con `AddShaderSourceDirectoryMapping` [M `UE:/Source/Runtime/RenderCore/Public/ShaderCore.h:1654`].

| Clase | Base | Qué hace | Firmas principales |
|---|---|---|---|
| `UFourPresentationSubsystem` | `UTickableWorldSubsystem` | Sustituye a `presentation_rig.gd`. Crea un volumen de posprocesado sin límites, guarda las instancias dinámicas de los materiales de lente y cinta y escribe exposición, gradación, niebla y zoom | `void ApplyGrade(const FFourGrade&)`, `void CameraCut()`, `void SetZoom(float Zoom)`, `void SetSignal(float Vhs, float Chroma, float Frayed)`, `void SetFieldShift(float Pixels)`, `void SetAir(float Density, float Anisotropy)` |
| `FFourGrade` | `USTRUCT` | Datos por piso: sesgo de exposición, temperatura y tinte de blanco, contraste, saturación | Campos: `ExposureBias`, `WhiteTemp`, `WhiteTint`, `Contrast`, `Saturation` |
| `UFourQualitySubsystem` | `UGameInstanceSubsystem` | Sustituye a `graphics_presets.gd`. Aplica un preset: grupos de escalabilidad más una lista corta de cvars | `void ApplyPreset(EFourQuality)`, `bool SupportsRayTracing() const`, `void SetScreenPercentage(float)` |
| `FFourCamcorderViewExtension` | `FSceneViewExtensionBase` | Smear CCD (dos de las ocho etapas de `camcorder_effect.gd`) en HDR, antes del reescalado temporal | `PrePostProcessPass_RenderThread(FRDGBuilder&, const FSceneView&, const FPostProcessingInputs&)` [M `UE:/Source/Runtime/Engine/Public/SceneViewExtension.h:210`] |
| `FourLightFixtures.h` | Tabla constante | Una fila por luminaria: clase de luz, lúmenes, temperatura, perfil IES, tamaño de fuente, alcance, distancia de dibujo, dispersión en niebla | `const FFourFixture& Fixture(EFourFixture)` |
| `UFourLightDirector` | `UTickableWorldSubsystem` | Parpadeo de tubos y, solo en el nivel sin trazado, qué luces dan sombra (las N más cercanas con histéresis, como `round_pools`) | `void Register(ULocalLightComponent*, EFourFixture, uint32 Phase)` |

Sombreadores en texto: `Shaders/Private/Camcorder/Lens.ush`, `Tape.ush`, `Smear.usf`. Los materiales son cáscaras con un nodo Custom que incluye el `.ush` (`IncludeFilePaths` [M `UE:/Source/Runtime/Engine/Public/Materials/MaterialExpressionCustom.h:97`]): la lógica se revisa como texto y el asset binario casi no cambia.

### 2.3 Assets (creados por guion o por el MCP, nunca a mano)

| Asset | Cómo se crea | Nota |
|---|---|---|
| `M_PP_Lens`, `M_PP_UIComposite`, `M_PP_Tape` (dominio Post Process, `BL_SceneColorAfterTonemapping`) | `MaterialTools` (22 herramientas) y `MaterialInstanceTools` (13) del MCP [`mcp_catalogo.md:528, 554`] o guion Python del editor | Prioridades 10, 20 y 30: lente, interfaz encima, cinta. Mismo orden que las capas 2, 3 a 4 y 5 de Godot |
| `IES/*.ies` (dome, tube, chandelier, troffer, box_sconce, sconce, torch) | `Tools/ies_from_profiles.py` escribe archivos IES (formato de texto) desde las curvas de `lighting.gd`; se importan con Interchange [M `UE:/Plugins/Interchange/Runtime/Source/Import/Private/Texture/InterchangeIESTranslator.cpp`] | Sustituyen a los proyectores equirectangulares |
| `NS_DustMotes` | `NiagaraToolset_System` (46 herramientas) [`mcp_catalogo.md:174`] | Motas iluminadas por el volumen de translúcidos |
| `T_TapeNoise`, `T_FilmGrain`, máscara del medidor | Guion Python (PNG) e importación | La máscara centrada va en `AutoExposureMeterMask` [M `UE:/Source/Runtime/Engine/Classes/Engine/Scene.h:1966`] |
| Niebla (`AExponentialHeightFog`) y volumen de posprocesado | Los crea el código al cargar el piso | Sin asset. `bEnableVolumetricFog` [M `UE:/Source/Runtime/Engine/Classes/Components/ExponentialHeightFogComponent.h:136`] |

Sin consola por MCP [F `briefs/agentes.md`]: los cvars se fijan en `.ini` y desde C++.

## 3. Correspondencia pieza a pieza

| Godot | Unreal | Queda como |
|---|---|---|
| VoxelGI por sala (`bounce_light.gd`, `office_bounce.gd`) y foco de rebote por tubo | Lumen GI | Desaparece el código |
| Sondas de reflexión, SSR, SSIL, SSAO | Reflejos de Lumen; sin sondas | Desaparece |
| Atlas de sombras, `lamps_cast`, `POOLS_CAST`, `SCONCES_LIT`, capas por sala (`room_layers.gd`) | MegaLights con sombra trazada en todas las luces | Desaparece; queda una versión mínima solo en el nivel sin trazado |
| `OmniLight3D` de sala del hotel con proyector | `UPointLightComponent` con `IESTexture`, `Temperature`, `SourceRadius` [M `LightComponent.h:57, 219`; `PointLightComponent.h:45`] | Fila de `FourLightFixtures.h` |
| Luz de sala de oficina + par de focos por tubo + halo (`ceiling_halo.gdshader`) | Un `URectLightComponent` por luminaria, del tamaño del difusor, con `BarnDoorAngle` [M `RectLightComponent.h:46`]; el difusor es una malla emisiva solo para verse | Una luz por tubo en vez de tres |
| Regletas y pasillos de archivo | `UPointLightComponent` con `SourceLength` [M `PointLightComponent.h:59`] o luz rectangular estrecha | Fila de tabla |
| Emergencias, acentos, carteles de salida, baliza | `USpotLightComponent` y `UPointLightComponent` | Fila de tabla |
| Linterna con proyector radial | `USpotLightComponent` con IES `torch`, `VolumetricScatteringIntensity` [M `LightComponentBase.h:120`] | La misma para el jugador local y los remotos |
| Alcance y desvanecido de lámparas (`lamp_fade`, `set_fade`) | `MaxDrawDistance` y `MaxDistanceFadeRange` de la luz [M `LightComponent.h:61, 65`] | Dato |
| Color por cuerpo negro contra 3200 K | `bUseTemperature` en cada luz y `WhiteTemp` 3200 en el volumen [M `Scene.h:1507`] | Dato |
| Niebla volumétrica, `light_volumetric_fog_energy` | Niebla de altura con volumétrica; `r.MegaLights.Volume` [M `MegaLights.cpp:246`] | Dato por piso |
| `FogVolume` de suelo y velos de polvo (`ceiling_dust_veil.gdshader`) | Malla con material de dominio Volume [M `UE:/Source/Runtime/Engine/Public/MaterialDomain.h:21`] | Asset por guion |
| Motas MultiMesh (`ceiling_dust.gdshader`), `CPUParticles3D` del hotel | `NS_DustMotes` | Asset por MCP |
| Medidor e iris de `camcorder_effect.gd` | Exposición automática del motor con máscara centrada, `AutoExposureSpeedUp` y `SpeedDown`, mínimo y máximo [M `Scene.h:1933, 1994, 2002, 2006, 2010`] | Datos |
| Halo y fantasmas | `BloomIntensity` y `LensFlareIntensity` del volumen [M `Scene.h:1629, 2119`] | Datos |
| Smear CCD | `FFourCamcorderViewExtension` | C++ y `.usf` |
| `grade` (rodilla, toe, desaturación de altas luces) | Curva del motor (`FilmSlope`, `FilmToe`, `FilmShoulder`, `ToneCurveAmount` [M `Scene.h:1594-1607`]); `M_PP_VideoKnee` en `BL_ReplacingTonemapper` si no convence (decisión D6) | Datos |
| `motion_blur_effect.gd` | Desenfoque de movimiento del motor con `MotionBlurTargetFPS` 60 y `MotionBlurMax` [M `Scene.h:2405, 2413`] | Datos |
| Enfoque (`CameraAttributesPractical`) | `DepthOfFieldFocalDistance` y `DepthOfFieldFstop` desde un trazo en C++ [M `Scene.h:1918, 2316`] | C++ |
| `lens.gdshader` (barril, franjas, viñeta, campo impar) | `M_PP_Lens` | `.ush` |
| `analog.gdshader` (croma, realce, grano, líneas) | `M_PP_Tape` | `.ush` |
| OSD e interfaz grabados en la cinta | Los widgets se dibujan a una textura y `M_PP_UIComposite` la pone bajo la cinta | Contrato con el diseño de interfaz |
| `graphics_presets.gd` (5 presets, 2 renderizadores) | `UFourQualitySubsystem` (4 niveles, un renderizador) | C++ |
| `shader_warmup.gd` | Precaché de PSO del motor más espera en la pantalla de carga | C++ mínimo |
| Decals | Calcomanías del motor (con Substrate formato 0 no hace falta DBuffer [F §4.6]) | Dominio de geometría |
| `echo_field`, `echo_points`, `lurker_darkness` (leen profundidad) | Material de posprocesado con SceneDepth en `BL_SceneColorBeforeDOF` | Unidad R15, compartida con criaturas |

## 4. Decisiones

**D1. Luz global y reflejos: Lumen por hardware.** Los interiores se generan al empezar la partida, así que no hay horneado posible. El camino por software de detalle está abandonado desde 5.6 y el global por campo de distancia queda como respaldo [F §4.2]. Los juegos del listón usan Lumen y Subliminal corre sobre 5.8.4 con trazado opcional [F `briefs/experiencias.md` §6]. Descartado: Lumen solo por software (peor en interiores estrechos y sin MegaLights); trazado de trayectorias (no es de tiempo real); luz horneada (incompatible con la semilla).

**D2. Luz directa: MegaLights con sombra trazada.** Una oficina tiene 9 a 16 luminarias por sala y la linterna de hasta cuatro jugadores; hoy eso obliga a un tope de 32 focos con sombra y a capas por sala. MegaLights da coste casi constante y sombra en todas, admite IES, funciones de luz y luces rectangulares con textura [M `MegaLights.cpp:197-218`] y tiene volumen propio para la niebla [M `:246`]. Es Production-Ready en 5.8 [F §4.3]. Descartado: sombras virtuales para todo (coste por luz; repetiría el problema del atlas); sombras por campo de distancia (blandas e imprecisas en marcos de puerta).

**D3. Cuatro niveles, uno de ellos sin trazado.** [D]

| Nivel | GI | Reflejos | Sombras y niebla | Para quién |
|---|---|---|---|---|
| Sin trazado | Lumen por software, calidad 1 (`r.Lumen.FinalGatherMethod=0` [M `BaseScalability.ini:333`]) | Pantalla | `r.RayTracing.Enable=0`, `r.MegaLights.Allowed=0` [M `MegaLights.cpp:34`], sombras virtuales con tope de luces con sombra; niebla forzada a 1 con rejilla de 16 px | GPU DX12 con SM6 sin trazado |
| Medio | Calidad 1 con trazado | Pantalla | MegaLights con 2 muestras; niebla forzada (la escalabilidad la apaga en Baja y Media [M `BaseScalability.ini:143, 178`]) | RTX 2060, 3050 |
| Alto (objetivo de la 4060 Ti) | Calidad 2 | Lumen, mitad de resolución [M `BaseScalability.ini:527-528`] | MegaLights con 4 muestras; niebla 16 px y 64 cortes [M `:213-215, 229`] | RTX 3060 en adelante |
| Ultra | Calidad 3, iluminación en el impacto para reflejos | Lumen a resolución completa | Niebla 8 px y 128 cortes [M `:252-253`] | RTX 4070 en adelante |

Descartado: conservar Muy bajo y Compatibility. Unreal sin SM6 pierde Nanite, sombras virtuales y trazado; sería un segundo juego visual. Esto cambia los requisitos mínimos y es pregunta para el autor.

**D4. Geometría: qué pide el render** (lo ejecuta el diseño de geometría).
- Mallas estáticas construidas en el editor por guion y colocadas como instancias; nada de triángulos generados en ejecución (pierden Nanite, campo de distancia, trazado y casi todas las tarjetas de Lumen [F `briefs/ue58.md` §5]).
- Paredes, suelo y techo como piezas separadas y cerradas, con grosor real. La pared de oficina ya mide 0,18 m [F `fichas/geo_oficinas.md`]; mínimo aceptado 0,10 m. Ningún plano de una sola cara como cerramiento.
- Ninguna pieza menor de 10 cm cuenta para Lumen (`r.LumenScene.SurfaceCache.MeshCardsMinSize` 10 [M `UE:/Source/Runtime/Renderer/Private/Lumen/LumenMeshCards.cpp:15-16`]): el detalle pequeño no rebota luz, lo cual es correcto.
- Campo de distancia: densidad 0,2 vóxeles por unidad y tope de 256 por malla [M `UE:/Source/Runtime/Engine/Private/DistanceFieldAtlas.cpp:69-77`]. Una pieza de pared de 4 m sale con unos 80 vóxeles de largo; no usar piezas de más de unos 12 m.
- Menos de 100 000 instancias con trazado por piso cargado (aviso del motor [F §4.2]); el piso 2 tiene hoy 26 358 nodos [F]. Solo se mantiene cargada la planta en la que se está, como hoy.
- Nanite en todo lo opaco; translúcidos (cristal, difusores) por el camino clásico [F §4.5].
- Nada coplanario: lo pegado a una pared es calcomanía o lleva separación real. Es la única cura del z-fighting.
- Las hojas de puerta son mallas móviles normales; cierran la luz por sí mismas y sobran `light_seal` y `jamb_seal`.

**D5. Clave baja y charcos de luz.** Sin luz de cielo y sin ambiente: lo que no recibe luz directa o rebote queda negro. Unidades físicas (lúmenes y kelvin) y exposición automática con margen estrecho, de modo que la cámara no «vea en la oscuridad». Valores de partida por calibrar [D]: luminaria de dos tubos 3000 lm a 4100 K; plafón del hotel 800 lm a 2700 K; aplique 250 lm a 2600 K; linterna 60 lm con pico estrecho. Los haces con polvo salen de la niebla volumétrica con sombra (MegaLights en el volumen) y de `NS_DustMotes`, que solo brilla donde llega luz porque se ilumina con el volumen de translúcidos (`r.MegaLights.TranslucencyVolume` [M `MegaLights.cpp:322`]). Los valores de energía de Godot no se trasladan.

**D6. Cámara.**
- Exposición automática del motor (`AEM_Histogram` [M `Scene.h:36`]) con máscara centrada, velocidades asimétricas y máximo de brillo acotado. Reproduce el iris de la camcorder sin código propio. Descartado: manual (se pierde el bombeo del iris, que es parte de la sensación) e iris propio en C++ (duplica lo que el motor da).
- Tinte de 1987: sale de la física, no de un filtro. Blanco de cámara a 3200 K con incandescentes de 2700 K (cálido anaranjado) y fluorescentes de 4100 K (verdoso frío), más `WhiteTint`, `ColorSaturation` y `ColorContrast` por piso [M `Scene.h:1510-1517`]. Partida: saturación 0,84 y contraste 1,06 (hotel), 0,85 y 1,16 (oficina). Sin LUT de entrada: un LUT es un asset binario opaco.
- Curva tonal: primero la del motor con `ToneCurveAmount` rebajado y `ExpandGamut` 0. Si junto a la referencia las altas luces se leen como película y no como vídeo, se añade `M_PP_VideoKnee` en `BL_ReplacingTonemapper` [M `BlendableInterface.h:66`] con la rodilla 0,72 y la desaturación de altas luces. Se decide en la prueba de concepto.
- Exposición local desactivada: no existe en una cámara de 1987.

**D7. Cadena de la camcorder.** Orden del motor: materiales tras la profundidad de campo, reescalado temporal, desenfoque de movimiento, antes del resplandor, curva tonal, tras la curva tonal [M `UE:/Source/Runtime/Renderer/Private/PostProcess/PostProcessing.cpp:507-514`; `BlendableInterface.h:23-75`].

| Paso | Punto | Coste objetivo a 1080p |
|---|---|---|
| Smear CCD (suma por columnas y difusión) | `PrePostProcessPass_RenderThread`, HDR, resolución interna | 0,3 ms |
| Profundidad de campo, desenfoque de movimiento, resplandor, destellos, curva, grano | Motor, por ajustes del volumen | 1,0 ms |
| `M_PP_Lens`: barril, franjas hacia las esquinas, viñeta, desplazamiento del campo impar | `BL_SceneColorAfterTonemapping`, prioridad 10 | 0,15 ms |
| `M_PP_UIComposite`: OSD e interfaz | Ídem, prioridad 20 | 0,05 ms |
| `M_PP_Tape`: croma en 7 lecturas horizontales, realce de luma, ruido, líneas, corrupción de señal | Ídem, prioridad 30 | 0,3 ms |

El campo impar se calcula como hoy, desde la rotación de cámara, y entra como parámetro: no hace falta historia. Los menús se dibujan con Slate por encima y quedan fuera de la cinta, igual que la capa 6. Descartado: toda la cadena en una extensión de vista (más C++ de render del necesario); un paquete VHS de Fab (de pago, y la cámara del juego ya está diseñada).

**D8. Antialias y reescalado.** TSR. Porcentaje de pantalla de fábrica 67 % a 1080p (720p internos) y 58 % a 1440p (835p internos): la cinta tiene poca resolución de luma por naturaleza y tapa la blandura. `r.TSR.History.ScreenPercentage` 100 salvo en Ultra [M `BaseScalability.ini:56-89`]. DLSS y FSR quedan para una unidad tardía y opcional: son plugins externos y hay un informe de imagen fantasma con DLSS en 5.8 [F §4.8].

**D9. Presupuesto en la RTX 4060 Ti (objetivos, nivel Alto, 60 FPS = 16,6 ms).** [D]

| Partida | 1080p (67 %) | 1440p (58 %) |
|---|---|---|
| Nanite, GBuffer y translúcidos | 2,5 | 3,0 |
| MegaLights (directa) | 2,5 | 3,0 |
| Lumen GI | 3,0 | 3,5 |
| Reflejos de Lumen | 1,5 | 1,8 |
| Niebla volumétrica | 1,0 | 1,0 |
| Escena de trazado (TLAS) y sombras virtuales restantes | 1,0 | 1,0 |
| TSR | 1,2 | 1,8 |
| Posprocesado y camcorder | 1,8 | 2,2 |
| **Total** | **14,5** | **17,3 (no cabe: 1440p pide el 50 % o el nivel Medio)** |

VRAM, tope 6,5 GB de 8: texturas en flujo 1500 MB (`r.Streaming.PoolSize`; Epic usa 1000 [M `BaseScalability.ini:782`]), BLAS y TLAS 800, Nanite 500, caché de superficie de Lumen 300 (atlas 3584 [M `:377`]), sombras virtuales 150 (2048 páginas [M `:219`]), campos de distancia 250, GBuffer e historias 600, resto 900. Hoy Alto usa 2,2 GB: el salto es grande y es lo primero que mide la prueba de concepto.

**D10. Sombreadores y tirones.** Precaché de PSO activo, estrategia de fábrica (retrasar el objeto hasta tener sus PSO) [M `UE:/Source/Runtime/Engine/Private/PSOPrecache.cpp:36, 68`]. La pantalla de carga del piso no se retira hasta que `PipelineStateCache::NumActivePrecacheRequests()` llega a cero [M `UE:/Source/Runtime/RHI/Public/PipelineStateCache.h:286`]: sustituye a `shader_warmup.gd`. Pocos materiales maestros (objetivo: 6 de superficie más los de cámara) con instancias, para tener pocas permutaciones. Los ajustes que recompilan todo (Substrate, trazado, SM6) se fijan en la primera unidad y no se vuelven a tocar.

## 5. Prueba de concepto visual

**Entra:** un mapa pequeño montado por guion con cuatro escenas: módulo de oficina de 8 m con 9 luminarias, pasillo, recepción con suelo encerado y una habitación de hotel con plafón y aplique; ajustes de proyecto de 2.1; luces con unidades físicas y tres IES; niebla y motas; linterna; exposición, blanco a 3200 K y gradación; `M_PP_Lens` y `M_PP_Tape` portados; TSR. Se entrega una captura por escena junto a su referencia de `docs/referencias/` y las cifras de `stat GPU` y de VRAM a 1080p y 1440p en Alto.

**Decide:** D6 (curva del motor o rodilla propia), D9 (si el presupuesto cabe), si MegaLights hace ruido visible con la linterna en movimiento, y si las piezas instanciadas conservan tarjetas de Lumen y proxies de trazado.

**No entra:** niveles de calidad, nivel sin trazado, smear, OSD en la cinta, cinta de muerte, visión de eco, pisos enteros, DLSS y FSR, espera de PSO.

## 6. Unidades de trabajo del port completo

Las marcadas ∥ pueden ir en paralelo entre sí (archivos disjuntos). Todo paso que abra el editor va en serie: un solo editor a la vez.

| # | Unidad | Origen (Godot) | Resultado | Prueba de aceptación |
|---|---|---|---|---|
| R1 | Ajustes de render del proyecto | `project.godot`, `hotel_environment.tres` | `Config/DefaultEngine.ini` según 2.1 | El editor arranca sin el aviso de MegaLights sin trazado [F `MegaLights.cpp:2596-2636`]; los cvars leídos por guion coinciden con la tabla |
| R2 | Módulo `TheFourRender` y carpeta de sombreadores | — | Módulo que compila y sirve `/TheFour/...` | `Build.bat` en verde; un material de prueba incluye un `.ush` |
| R3 ∥ | Tabla de luminarias | `lighting.gd`, constantes de luz de `hotel_geometry.gd`, `office_geometry.gd`, `prop_factory.gd`, `player.tscn` | `FourLightFixtures.h` | Prueba de automatización: una fila por cada luminaria de `fichas/render.md` §8 a §10 |
| R4 ∥ | Perfiles IES | `lighting.gd:66-123` | `Tools/ies_from_profiles.py` y 7 `.ies` importados | Captura de cada perfil sobre una pared junto a la de Godot |
| R5 ∥ | Presentación: exposición, curva, gradación, niebla, zoom | `presentation_rig.gd`, `camcorder_look.gd`, `office_geometry.gd:203-217` | `UFourPresentationSubsystem`, `FFourGrade` | Al pasar de sala oscura a iluminada la exposición tarda lo mismo que en Godot (medido en vídeo, ±0,2 s); cambio de piso sin salto de imagen |
| R6 ∥ | Lente | `lens.gdshader`, `camcorder_look.gd` | `Lens.ush`, `M_PP_Lens` | Rejilla de prueba: misma curvatura que Godot en las esquinas (±2 px a 1080p) |
| R7 ∥ | Cinta | `analog.gdshader`, `tape_noise.gdshader`, `signal_wash.gdshader` | `Tape.ush`, `M_PP_Tape` | Carta de barras de color: mismo corrimiento de croma; los cuatro deslizadores del jugador actúan |
| R8 ∥ | Smear CCD | `camcorder_effect.gd` (etapas smear y spread) | `FFourCamcorderViewExtension`, `Smear.usf` | Un tubo mirado de frente da columna vertical; coste menor de 0,4 ms en `ProfileGPU` |
| R9 | Aire: niebla por piso y motas | `office_geometry.gd:210-217, 1307-1366`, `hotel_geometry.gd:1194-1204, 3272-3298` | `SetAir`, `NS_DustMotes`, material de volumen | Haz de linterna visible con motas solo dentro del cono; la luz de una sala se ve salir por la puerta |
| R10 | Linterna, piloto y televisor | `hotel_player.gd:184-214, 365-439`, `hotel_television.gd:89-114` | Componentes de luz del jugador (con el diseño del jugador) | La linterna de un compañero ilumina la niebla y da sombra |
| R11 ∥ | Luces del hotel en el generador | `hotel_geometry.gd` (luz de sala, apliques, carteles, baliza) | Llamadas del generador a la tabla | Una planta: ninguna luz cruza una pared (recorrido por guion con capturas) |
| R12 ∥ | Luces de la oficina en el generador | `office_geometry.gd` (luminarias, regletas, emergencias, acentos), `office_accents.gd`, `office_landmarks.gd` | Ídem | Ídem, más un módulo de 12 m con 16 luminarias a 60 FPS en Alto |
| R13 | Niveles de calidad y ajustes | `graphics_presets.gd`, `settings_service.gd` | `UFourQualitySubsystem` | Cambiar de nivel en partida sin reiniciar; cada nivel cumple su fila de D3 |
| R14 | Nivel sin trazado | `round_pools`, `cast_or_fill` | Tope de sombras en `UFourLightDirector` | Con `r.RayTracing.Enable=0` no hay luz que cruce paredes a menos de 10 m |
| R15 | Efectos que leen profundidad | `echo_field.gdshader`, `echo_points.gdshader`, `ceiling_dust_veil.gdshader` | Materiales de posprocesado y de volumen | Comparación con captura de Godot (con el diseño de criaturas) |
| R16 | OSD e interfaz dentro de la cinta | `camcorder_osd.gd`, `hotel_ui.gd:250-276` | Textura de interfaz y `M_PP_UIComposite` (con el diseño de interfaz) | El texto REC muestra grano y corrimiento; el menú de pausa no |
| R17 | Espera de PSO en la carga | `shader_warmup.gd` | Condición en la pantalla de carga | Primer recorrido de un piso sin fotograma de más de 50 ms atribuible a PSO |
| R18 | Banco y capturas comparadas | `tools/` de banco y captura, `docs/PERFORMANCE.md` | Guion que recorre vistas fijas y vuelca ms, VRAM y PNG | Tabla de D9 rellenada con medidas |
| R19 | DLSS y FSR (opcional) | — | Plugins y selector | Solo si el autor lo pide |

Orden: R1, R2; después R3 a R8 en paralelo; R9 y R10; R11 y R12 cuando el generador de cada piso exista; R13 a R18.

## 7. Riesgos y cómo se detectan pronto

| Riesgo | Detección |
|---|---|
| 8 GB de VRAM no bastan con trazado, Nanite y texturas de 2K | Medir en la prueba de concepto con un módulo repetido 50 veces; si pasa de 6,5 GB, bajar texturas a 1K y el fondo de flujo |
| Ruido o estela de MegaLights con la linterna en movimiento y tubos que parpadean | Vídeo en la prueba de concepto; salida: `r.MegaLights.NumSamplesPerPixel` 4 y parpadeo por emisivo en vez de por intensidad |
| Lumen tarda varios fotogramas en reaccionar al apagar una sala | Vídeo de un apagón; se acepta si baja en menos de 0,5 s |
| Las instancias colocadas en ejecución no tienen tarjetas de Lumen o proxies de trazado | Vista «Lumen Scene» en la primera sala generada (captura por MCP) |
| La niebla del motor a 16 px da halos en bola, como hoy | Comparar 16 y 8 px en la escena de emergencia; coste en `ProfileGPU` |
| La curva del motor no se lee como vídeo | Comparación con referencia en la prueba de concepto (D6) |
| Más de 100 000 instancias trazadas en un piso | Contar instancias al generar el piso 2; salida: fusionar por sala |
| Compilación inicial de sombreadores larga con un solo editor | Medir el primer arranque tras R1; no cambiar después los ajustes que recompilan todo |
| El material tras la curva tonal corre a resolución de salida y sube de coste a 1440p | `ProfileGPU` a 1440p en R7 |
| CPU: el piso 2 ya no llega a 60 FPS en Godot por número de nodos | Banco R18 en cuanto exista un piso; depende del instanciado del diseño de geometría |

## 8. Preguntas para el autor

1. **Requisitos mínimos.** El port deja fuera las gráficas integradas y todo lo que no tenga DX12 con SM6; el aspecto buscado pide además trazado de rayos (RTX 2060 o equivalente). ¿Se acepta, o hay que conservar un nivel sin trazado como mínimo real (unidad R14)?
2. **Referencia de tono.** ¿Qué imagen de `docs/referencias/` manda para calibrar el naranja de cada piso? Sin una por piso la calibración no tiene fin.
3. **DLSS.** Es un plugin de NVIDIA con licencia propia que tendría que aceptar y quizá descargar con su cuenta. ¿Lo quiere, o basta TSR?
4. **1440p.** Con el presupuesto de D9, 1440p a 60 FPS en la 4060 Ti pide el nivel Medio o el 50 % de resolución interna. ¿Vale como objetivo 1080p en Alto y 1440p en Medio?

## 9. Herramientas, plugins y assets

| Qué | Fuente | Licencia y condición |
|---|---|---|
| Nada obligatorio | — | Lumen, MegaLights, TSR, Niagara, Interchange y el importador IES vienen con el motor |
| Plugin DLSS para 5.8 (opcional) | https://developer.nvidia.com/rtx/dlss | Licencia de NVIDIA; sin comprobar si pide cuenta. Lo trae el autor |
| Plugin FSR 4.1.2 (opcional) | https://gpuopen.com/learn/ue-fsr/ | De AMD, unos 2,5 GB, solo DX12; licencia sin comprobar |
| Texturas de ruido, grano y máscara | Generadas por guion en el repo | Propias |
| Archivos IES | Generados desde `lighting.gd` | Propios; no se bajan fotometrías de fabricante |

## 10. Sin comprobar

- Todo rendimiento y memoria en Unreal: las tablas de D7 y D9 son objetivos.
- Que `BL_SceneColorAfterTonemapping` corra a resolución de salida con TSR, y que `PrePostProcessPass_RenderThread` vea el color HDR antes del reescalado.
- Calidad de MegaLights sin trazado por hardware (por eso D3 lo apaga en ese nivel) y su comportamiento con luces que parpadean.
- Que las instancias de malla estática colocadas en ejecución conserven Nanite, campo de distancia, tarjetas de Lumen y proxies de trazado.
- Que un material de dominio Volume sobre una malla baste para la neblina de suelo y los velos; no se leyó el voxelizado.
- Los lúmenes de partida de D5 son de memoria, no de catálogos de 1987.
- El grosor de pared del hotel (`room_dressing.gd:23` da una cara a 0,11 m; no se leyó el muro) y los números exactos de luces por sala.
- Que `FWidgetRenderer` o equivalente dibuje la interfaz a textura sin coste apreciable (lo decide el diseño de interfaz).
- Que 6 materiales maestros basten para los 9 sombreadores de superficie (dominio de materiales).
- Licencias y forma de descarga de los plugins de DLSS y FSR; no se consultó la web en este encargo: los datos web vienen de los informes.
- La equivalencia entre las velocidades del iris de Godot (1,1 y 2,4) y `AutoExposureSpeedUp` y `SpeedDown`, y entre densidades de niebla de ambos motores.
- Los cuerpos de `lens.gdshader`, `analog.gdshader` y de las etapas de cómputo no se leyeron línea a línea.
- La línea 2596-2636 del aviso de MegaLights y las citas marcadas [F] no se volvieron a abrir.
