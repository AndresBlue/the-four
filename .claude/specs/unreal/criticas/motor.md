# Crítica del plan del port: verdad técnica sobre Unreal 5.8.4

15 de noviembre de 2026. Crítico de diseño, enfoque «motor». Leí `docs/PORT_UNREAL.md` entero y las partes de `D/render.md`, `D/metodo.md`, `D/plataforma.md` y `D/criaturas.md` que tocan cada objeción. Todo lo marcado como comprobado lo leí hoy en el código fuente instalado. `UE:` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine/`. No ejecuté nada.

Ninguna objeción bloquea. Las tres importantes son afirmaciones del plan que el código del motor contradice, y cada una tiene un arreglo barato si se aplica antes de P0.

## Importante

### I1. El plugin del MCP no es «solo de editor»: tiene módulos de juego

**Apartado:** 2.1 y 6.2 fase 6 («el paquete … no lleva módulos de editor ni de MCP»); `D/metodo.md:41` («Plugins de agente, todos solo de editor»); `D/plataforma.md:128` (D9).

**Evidencia:**
- `UE:Plugins/Experimental/ModelContextProtocol/ModelContextProtocol.uplugin`: los módulos `ModelContextProtocol` y `ModelContextProtocolEngine` son de tipo `"Runtime"`. Solo `ModelContextProtocolEditor` es de editor. El plugin no lleva `"EditorOnly": true` y sí lleva `"NoRedist": true`. `AllToolsets.uplugin` y `ToolsetRegistry.uplugin` sí son `"EditorOnly": true`.
- El arranque del servidor por línea de órdenes está en el módulo de juego: `UE:Plugins/Experimental/ModelContextProtocol/Source/ModelContextProtocolEngine/Private/ModelContextProtocolSettings.cpp:34` (`-ModelContextProtocolStartServer`).
- Además depende de `ToolsetRegistry`, que es solo de editor (mismo `.uplugin`, bloque `Plugins`).

**Consecuencia:** si se activa en el `.uproject` como pide `D/metodo.md:41`, sus módulos de juego entran en los objetivos `Game` (Development y Shipping). Pasará una de dos cosas: el objetivo de juego no compila porque falta su dependencia de editor, o el paquete lleva un servidor HTTP sin autenticación que se enciende con un argumento. La segunda también incumple la licencia (`NoRedist`). En los dos casos falla P13 y la prueba de PL11.

**Cambio que pido:** en `D/metodo.md` §2.2 y en `D/plataforma.md` D9, que la entrada de `ModelContextProtocol` en el `.uproject` lleve `"TargetAllowList": ["Editor"]`. Es la clave que lee `UE:Source/Runtime/Projects/Private/PluginReferenceDescriptor.cpp:161` y que aplica la línea 73. Se pone igual en `PythonScriptPlugin` si se activa a mano. Hay que corregir la frase «todos solo de editor». Y añadir a la prueba de P13: «el paquete Development no contiene `ModelContextProtocol*.dll` ni `ToolsetRegistry*.dll`».

### I2. Sin `r.SkinCache.CompileShaders`, las criaturas y los jugadores no proyectan sombra con MegaLights

**Apartado:** 2.1 (Iluminación) y la tabla de ajustes que P0 copia de `D/render.md:20-37`.

**Evidencia:**
- Una malla con esqueleto solo entra en el trazado de rayos si la caché de pieles de la GPU está activa: `UE:Source/Runtime/Engine/Private/GPUSkinCache.cpp:2328` (`IsRayTracingAllowed() && SupportSkeletalMeshes && IsGPUSkinCacheEnabled(...)`).
- La caché solo existe si se compilan sus sombreadores: `UE:Source/Runtime/RenderCore/Private/RenderUtils.cpp:1644-1646`.
- `r.SkinCache.CompileShaders` vale 0 de fábrica y es de solo lectura (`UE:Source/Runtime/Engine/Private/GPUSkinCache.cpp:92-99`).
- El asistente de proyecto nuevo lo pone a `True` al activar el trazado (`UE:Source/Editor/GameProjectGeneration/Private/GameProjectUtils.cpp:179-183`), pero la tabla de `D/render.md:20-37` no lo incluye.
- MegaLights con sombra trazada depende de lo que haya en el BVH (`UE:Source/Runtime/Renderer/Private/MegaLights/MegaLights.cpp:377`).

**Consecuencia:** The Lurker, The Locust y los compañeros no proyectarían sombra trazada de las luminarias ni de la linterna. Tampoco saldrían en los reflejos de Lumen. Solo quedarían las trazas de pantalla. Es justo lo que da miedo en el juego.

**Cambio que pido:** añadir a la tabla de `D/render.md` §2.1 la fila `r.SkinCache.CompileShaders = True` (y dejar `r.RayTracing.Geometry.SupportSkeletalMeshes` en su 1 de fábrica, `UE:Source/Runtime/Engine/Private/SkeletalMeshSceneProxy.cpp:59-60`). Y añadir a la prueba de la primera unidad que monte un esqueleto (J o C, la que llegue antes) una captura con la linterna detrás del cuerpo: el cuerpo deja sombra en la pared.

### I3. Niagara no se puede construir con Python: solo con el MCP

**Apartado:** 2.2 (fila «Assets binarios generados»: «lo que deba existir acaba en un guion»), 7.2 («Para qué se usa») y 10, decisión 2 («si no la aceptas, el plan funciona sin MCP, solo con guiones de Python; Niagara sale más lento»); `D/criaturas.md:208` («reserva: guion Python»); `D/render.md:60` (`NS_DustMotes`).

**Evidencia:**
- Las herramientas de Niagara del MCP son `UFUNCTION(meta = (AICallable))`, no `BlueprintCallable`. Por ejemplo, `UE:Plugins/Experimental/Toolsets/NiagaraToolsets/Source/NiagaraToolsets/Private/NiagaraToolset_Assets.h:118, 139, 160`, en una carpeta `Private`. Python solo ve funciones expuestas a guion, así que un guion de `Tools/assets/` no puede llamarlas.
- El editor de Niagara solo expone a guion el horneado: buscando `BlueprintCallable` en `UE:Plugins/FX/Niagara/Source/NiagaraEditor` aparecen `NiagaraBakerFunctionLibrary.h` y `UpgradeNiagaraScriptResults.h`, y ninguna función de módulos, emisores ni pila.

**Consecuencia:** el «guion reproducible» de un sistema Niagara no puede ser Python. Si el autor no acepta la cláusula 6(e), los sistemas `NS_DustMotes` y `NS_CeilingDust_*` no tienen camino. Si la acepta, quedan hechos con llamadas sueltas al MCP, que es justo lo que `D/metodo.md` D7 descarta.

**Cambio que pido:** la opción más corta es quitar Niagara del port. Las motas y el polvo del techo pasan a instancias escritas desde C++ con un material translúcido iluminado por el volumen, como ya hace `D/criaturas.md:142` con los 46 000 granos. Eso deja Niagara fuera de `Tools/assets/` y de la decisión 2. Si se quiere conservar Niagara, el guion es un archivo de llamadas al MCP (`Tools/assets/niagara/*.json`) que `mcp.ps1` reproduce y comprueba con `GetSystemCompileState`. En ese caso hay que corregir la decisión 2 del apartado 10: sin MCP no hay Niagara.

## Menor

### M1. MegaLights se da por «Production-Ready» cuando el motor instalado lo marca como experimental

**Apartado:** 2.1 (Iluminación); `D/render.md:101` («Es Production-Ready en 5.8»).

**Evidencia:**
- El texto de ayuda del motor 5.8.4 termina en «Experimental feature.» en dos sitios: `UE:Source/Runtime/Renderer/Private/MegaLights/MegaLights.cpp:29` y `UE:Source/Runtime/Engine/Classes/Engine/RendererSettings.h:652`.
- El estado «Production-Ready» sale de un hilo del foro (`briefs/ue58.md:99, 145`).
- `briefs/ue58.md:146` ya avisa de que los dos no cuadran.
- El plan descarta Mover precisamente por ser experimental (apartado 1).

**Cambio que pido:** en 2.1, escribir «Production-Ready según Epic [web]; el motor instalado aún lo rotula como experimental» y no tratarlo como hecho comprobado. No cambia la decisión: el nivel «Sin trazado» (R14) ya es la salida.

### M2. La comprobación de tarjetas de Lumen de P8 no se puede hacer con el MCP

**Apartado:** 5.3, P8 («vista Lumen Scene con tarjetas en los muros»); `D/render.md:207` («captura por MCP»).

**Evidencia:**
- La planta solo existe con el juego en marcha (5.2, paso 3), así que el visor del editor queda vacío salvo que se lance PIE.
- El MCP se comprobó con `-nullrhi`, que no dibuja.
- La vista existe en el juego: `r.Lumen.Visualize` (`UE:Source/Runtime/Renderer/Private/Lumen/LumenVisualize.cpp:29`) y la bandera `VisualizeLumen`, accesible siempre (`UE:Source/Runtime/Engine/Public/ShowFlagsValues.inl:78`).

**Cambio que pido:** en P8, la prueba se hace con `ue.ps1 capture` y una toma con `r.Lumen.Visualize`, no con `CaptureViewport`. Hay que corregirlo también en `D/render.md:207`.

Dato útil para el riesgo 3: las instancias de una ISM reciben tarjetas de Lumen una a una (`UE:Source/Runtime/Renderer/Private/Lumen/LumenScene.cpp:1345-1380`). Solo se fusionan con `r.LumenScene.SurfaceCache.MeshCardsMergeInstances`, que vale 0 de fábrica (`UE:Source/Runtime/Renderer/Private/Lumen/LumenMeshCards.cpp:37`). Lo que queda por ver en P8 es la calidad de la caché en un cubo muy alargado, no si existen las tarjetas. El guion de materiales no debe activar `bCompatibleWithLumenCardSharing` en `M_Surface` (de fábrica vale `false`, `UE:Source/Runtime/Engine/Private/Materials/Material.cpp:1195`): con coordenada de mundo, compartir tarjetas daría a todos los muros la misma captura.

### M3. Sombra trazada de los modelos con Nanite: sale de la malla de respaldo

**Apartado:** 4.2 (Mallas: «Nanite en todo lo opaco y rígido») y 5.4.

**Evidencia:**
- El trazado usa de fábrica la malla de respaldo de Nanite (`r.RayTracing.Nanite.Mode` 0, `UE:Source/Runtime/Engine/Private/Rendering/NaniteResources.cpp:194-198`).
- MegaLights avisa de que su sombra «depende de la calidad del BVH» (`MegaLights.cpp:377`).
- El plan activa `r.RayTracing.RayTracingProxies.ProjectEnabled` (`D/render.md:25`), pero los ajustes por malla (`FMeshRayTracingProxySettings`, `UE:Source/Runtime/Engine/Classes/Engine/StaticMesh.h:1350`) no los fija ningún guion.

**Consecuencia:** en muebles escaneados o de muchos polígonos puede aparecer sombra que se cuela o que se pinta sobre la propia pieza. Se nota en el contacto con el suelo, que es lo que vende la foto.

**Cambio que pido:** que el guion de importación de mallas fije de forma explícita los ajustes de proxy de trazado de cada malla y los anote en `Tools/assets/*.json`. Y añadir a P9 una toma de contacto (silla o mesa sobre el suelo, bajo una luminaria) para comparar la sombra de MegaLights con `r.MegaLights.DefaultShadowMethod=1`.

## Sin comprobar

- No pude ejecutar nada, así que no sé si el objetivo `Game` falla al compilar o compila e incluye el servidor (I1). Las dos salidas piden el mismo arreglo.
- No comprobé si existe alguna puerta Python genérica hacia `ToolsetRegistry` (un `call_tool` expuesto a guion) que permitiera a Python invocar las herramientas `AICallable` (I3). Busqué `BlueprintCallable` en `UE:Plugins/Experimental/ToolsetRegistry` y solo aparecen clases de prueba.
- Memoria de vídeo y fotograma con Lumen por hardware, MegaLights y Nanite en 8 GB: no se puede comprobar leyendo código. Sigue siendo el riesgo 1 del plan.
- Que la conversión de ejes de `FourSpace.h` coincida con la que aplica Interchange en toda la cadena. Solo comprobé la del lector de glTF: `(X, Z, Y)` y el cuaternión `(-X, -Z, -Y, W)`, en `UE:Plugins/Interchange/Runtime/Source/Parsers/GLTFCore/Private/GLTF/ConversionUtilities.h:16-44`. Cuadra con la regla del plan. No comprobé si la canalización de Interchange añade un giro de escena encima.
- Calidad visual del formato 0 de Substrate en suelos encerados. El motor dice que fuerza un cierre por píxel y que se pierde fidelidad (`UE:Source/Runtime/RenderCore/Private/RenderUtils.cpp:2088`). Las calcomanías de GBuffer siguen existiendo sin DBuffer (`RenderUtils.cpp:1608-1613`).
