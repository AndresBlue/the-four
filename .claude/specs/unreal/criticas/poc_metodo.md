# Crítica: prueba de concepto y método del port a Unreal

15 de noviembre de 2026. Crítica de diseño de `docs/PORT_UNREAL.md` (abreviado `PLAN`) y de `.claude/specs/unreal/diseno/poc.md` y `metodo.md` (`D/`). No se ejecutó Godot ni Unreal ni se compiló nada. `UE:` es `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine/`. Solo lo que bloquea o importa, por gravedad.

## Bloquea

### B1. El sí del autor se apoya en fotos fijas, ya asentadas, de salas vestidas a mano

- **Apartado:** PLAN 5.1, 5.4, 5.5 y 5.7.
- **Evidencia:**
  - Lo que se juzga son tomas fijas tras una espera de asentamiento (`D/poc.md:146`: 3 s por toma). La única fila en movimiento es la del z-fighting (`PLAN:246`). La fila «Foto de época» (`PLAN:249`) se decide solo con las 11 tomas fijas.
  - Lumen, TSR y MegaLights acumulan entre fotogramas. Una foto asentada esconde justo lo que el autor verá al jugar: ruido, estela y retraso del rebote.
  - El propio diseño de render ya fija dos criterios en movimiento: estela de MegaLights con la linterna (`D/render.md:205`) y un apagón que baja en menos de 0,5 s (`D/render.md:206`). La prueba no los recoge.
  - En la prueba ninguna luz se apaga ni parpadea (`PLAN:178`: sin gameplay). El riesgo 12 dice detectarlo en el «vídeo en P9» (`PLAN:429`), pero en ese vídeo no ocurre nada que lo enseñe.
  - Las 11 salas que se juzgan son las vestidas, con vestimenta que puede colocarse «a ojo» (`D/poc.md:209`). Lo colocado a ojo se tira (`PLAN:275`).
  - La línea base sin vestir, «el port mecánico» (`D/poc.md:134`), no entra en ningún criterio ni en la pregunta (`PLAN:194`).
  - Riesgo: el autor diga sí a un techo que el port tiene que ganarse con el «trabajo largo» que el propio plan reconoce (`PLAN:168`).
- **Cambio que pido:**
  1. **Movimiento.** Añadir a la tabla de `PLAN` 5.4 dos filas:
     - «En el vídeo como se juega (con lente y cinta), con la linterna barriendo y a velocidad de marcha, el autor no ve ruido, estela ni manchas que no estén en la foto fija de la misma sala».
     - «Apagón: una sala iluminada pasa a negro en menos de 0,5 s, y un tubo que parpadea no deja estela (`D/render.md:205-206`)».

     Para eso, el recorrido de P12 incluye un apagón y un parpadeo de tubo programados por `UFourCaptureSubsystem` con un temporizador. No es gameplay.
  2. **La pregunta se parte en dos.** «¿Este techo vale?», con las salas vestidas. «¿Lo que da el port mecánico es aceptable como punto de partida?», con dos tomas por piso de salas sin vestir, añadidas a `tomas.json`.
  3. **Cada toma vestida enseña su origen** en la hoja: cuántas piezas se pusieron por regla y cuántas a ojo.

## Importantes

### I1. No hay una prueba de humo: lo que es solo texto se reparte antes de comprobar la cadena que lo ejecuta

- **Apartado:** PLAN 5.3 (orden, `PLAN:238`) y riesgos 3, 9 y 11.
- **Evidencia:**
  - P3 a P7 van en paralelo desde el principio. Su verificación real llega toda junta en P8.
  - Lo que puede cambiar su diseño está «sin comprobar» (`PLAN:500-503`): Python sin ventana que crea materiales e importa, PNG con `-RenderOffScreen` y tarjetas de Lumen en instancias colocadas en ejecución.
  - El riesgo 9 dice detectarlo en «P3 y P8, el primer día» (`PLAN:426`), pero P8 va detrás de P2 y de P3 a P7.
  - La prueba de P4 es «Compila» (`PLAN:227`). `Build.bat` no compila `.ush`: un sombreador incluido en un nodo Custom solo se compila al compilar el material, en el editor o en el juego.
  - `D/metodo.md:154` ya pide medir estas cosas en la prueba, pero no las pone por delante del reparto.
- **Cambio que pido:** un paso P0b de humo, en serie tras P0 y antes de lanzar P3 a P7:
  - un guion con `-run=pythonscript` crea un material con un nodo Custom que incluye un `.ush` trivial, y una instancia de ese material;
  - el C++ coloca en ejecución tres instancias de `SM_Box` (un muro de 0,18 × 4 × 3 m), una luz rectangular y la linterna;
  - `ue.ps1 capture humo` deja dos PNG: normal y con `r.Lumen.Visualize=3` (`UE:Source/Runtime/Renderer/Private/Lumen/LumenVisualize.cpp:29-37`).

  Se acepta si están los dos PNG y si quedan anotados la compilación incremental, el primer arranque con RHI y la primera compilación de sombreadores. Si algo falla, se rediseña antes de repartir. La prueba de P4 pasa a ser «el material que incluye `Lens.ush` y `Tape.ush` compila sin errores en el humo».

### I2. Las capturas y la medida no esperan a sombreadores ni a PSO

- **Apartado:** PLAN 5.5; `D/poc.md` 5.4 punto 1 y 5.5 («espera de PSO» queda fuera, `D/poc.md:155`).
- **Evidencia:**
  - En el juego sin cocinar los sombreadores se compilan en segundo plano: `bAllowAsynchronousShaderCompiling=True` (`UE:Config/BaseEngine.ini:2179`).
  - `r.PSOPrecache.ProxyCreationStrategy` vale 1 de fábrica: «Delay proxy creation when PSOs are still compiling» (`UE:Source/Runtime/Engine/Private/PSOPrecache.cpp:34-41`). Las instancias creadas en ejecución pueden faltar o salir tarde en una foto tomada a los 3 s.
  - El p95 del recorrido de 60 s recoge los tirones de la primera compilación.
  - La comprobación de `TP_Blank` se hizo con `-nullrhi` (encargo): todavía no se ha compilado ningún sombreador SM6 del proyecto.
- **Cambio que pido:**
  - `UFourCaptureSubsystem` no toma ninguna foto ni empieza `RunWalk` hasta que se cumplan, durante 30 fotogramas seguidos, `GShaderCompilingManager->GetNumRemainingJobs() == 0` (`UE:Source/Runtime/Engine/Public/ShaderCompiler.h:1214`) y `PipelineStateCache::NumActivePrecacheRequests() == 0` (`UE:Source/Runtime/RHI/Public/PipelineStateCache.h:286`). Después espera los fotogramas de asentamiento.
  - El recorrido se corre dos veces seguidas y cuenta la segunda. La primera se informa aparte como «tirones de primera vez».

### I3. La cifra que decide la máquina se mide en el binario del editor, y el paquete llega después del sí

- **Apartado:** PLAN 5.3 (P12 y P13), 5.4 fila «Máquina» y riesgo 17.
- **Evidencia:**
  - Las capturas y el recorrido se lanzan con `UnrealEditor-Cmd.exe ... -game` (`D/metodo.md:54`), sin cocinar.
  - P13, el empaquetado, va «tras el sí» (`PLAN:236`). La fila «Máquina» (`PLAN:250`) y el riesgo 1, que «tumba la premisa» (`PLAN:418`), se juzgan con un binario que no es el del jugador.
  - En este montaje todo se carga por ruta desde JSON en ejecución. El cocinado no descubre esos assets por referencia. Hay que declararlos en `DirectoriesToAlwaysCook` y montar `planta.json` con `DirectoriesToAlwaysStageAsNonUFS` (`UE:Source/Developer/DeveloperToolSettings/Classes/Settings/ProjectPackagingSettings.h:568, 599`). Es el mismo fallo que el port tendrá con un mundo montado en ejecución, y conviene verlo ya.
- **Cambio que pido:**
  - P13 pasa delante de P12.
  - La fila «Máquina» se mide en el paquete Development, con `/Game/Gen` en `DirectoriesToAlwaysCook` y `SourceAssets/poc` (o la carpeta del JSON) en `DirectoriesToAlwaysStageAsNonUFS`.
  - Si el empaquetado falla, se mide en el editor y la tabla lo dice.

### I4. Cada retoque de la calibración pide recompilar C++

- **Apartado:** PLAN 5.3, P11, y 4.2, fila «Unidades».
- **Evidencia:**
  - Lúmenes y kelvin viven en `FourLightFixtures.h`, una «tabla constante» (`D/render.md:49`), y la gradación vive en `FFourGrade` (C++).
  - P11 ajusta justo esos valores. Cada ronda es `build`, arrancar el juego y capturar, y nada más puede usar el motor mientras tanto.
  - Va contra el criterio 3 del autor: velocidad y pulido sin vueltas.
- **Cambio que pido:**
  - En la prueba, lúmenes, kelvin, gradación y curva se leen al arrancar de `Tools/capture/calib.json`, o de `-FourCalib=<archivo>`.
  - Una sola ejecución saca cada toma con tres variantes (por ejemplo tres blancos de cámara o tres exposiciones), y el autor elige en una ronda.
  - Al cerrar P11, los valores elegidos se copian a `FourLightFixtures.h`.
  - El tope de rondas se cuenta en lanzamientos, no en compilaciones.

### I5. El vídeo, la única prueba en movimiento, no tiene herramienta

- **Apartado:** PLAN 5.5, último punto (`PLAN:260`).
- **Evidencia:**
  - El plan no dice cómo se graba.
  - `ffmpeg` no está en esta máquina (`which ffmpeg` sin resultado, 15 de noviembre).
  - Movie Render Queue está descartado (`D/metodo.md:130`).
  - El lanzador de capturas usa `-UseFixedTimeStep -FPS=60` (`D/metodo.md:54`), y con paso fijo el motor «lie about how fast it is going» (`UE:Source/Runtime/Engine/Private/UnrealEngine.cpp:3017`). Un vídeo hecho a paso fijo no enseña el movimiento por fotograma que tendrá el jugador si el juego va por debajo de 60.
- **Cambio que pido:**
  - Una decisión nueva del autor en PLAN 10, antes de la prueba: o graba él los dos recorridos con su herramienta de captura de pantalla, o autoriza bajar `ffmpeg` (LGPL o GPL, sin cuenta) para montar el vídeo desde una secuencia de PNG.
  - El recorrido del vídeo se lanza sin `-UseFixedTimeStep`.

### I6. La estimación de la prueba es de otro camino, y la del port no se contrasta con el histórico

- **Apartado:** PLAN 5.8 y 6.3.
- **Evidencia:**
  - `PLAN:279` toma «de 4 a 6 ventanas» de `D/poc.md:191`, que lo calculó para el camino glTF.
  - El camino elegido (2.3 fila 1 y 5.2) añade `AFloorBuilder`, `FourSpace.h`, un glb por malla, `UFourCaptureSubsystem` en lugar de `AFourPocBench` y P13.
  - El juego entero se hizo entre el 16 de septiembre y el 15 de noviembre de 2026 (604 commits, `git log`). El plan pone el port en «entre mes y medio y tres meses» (`PLAN:311`): igual o menos que crearlo, con estas diferencias:
    - un ciclo más lento: `Build.bat` 78 s en la plantilla vacía, frente a `--check-only` de un segundo (`CLAUDE.md`);
    - una paridad bit a bit que antes no existía;
    - un ritmo de 3 o 4 unidades por ventana que el plan llama «suposición mía» (`PLAN:525`).
- **Cambio que pido:**
  1. Rehacer 5.8 para el camino elegido.
  2. Que P12 entregue, junto a las 11 parejas, el ritmo medido en la prueba (unidades cerradas por ventana, minutos de compilación incremental y de arranque) y la estimación del port rehecha con él.
  3. Que la pregunta del autor lleve ese coste: «¿se porta, sabiendo que cuesta X ventanas?».
  4. Que el director añada como cota el número de ventanas que gastaron los dos meses de Godot, si lo tiene.

## Menores

### M1. La comprobación de las tarjetas de Lumen en P8 no dice dónde se mira

- **Apartado:** P8 (`PLAN:231`).
- **Evidencia:** la planta solo existe en ejecución (`PLAN:205`), así que el visor del editor y `CaptureViewport` del MCP no la ven sin PIE (`mcp_catalogo.md:101, 117`).
- **Cambio que pido:** «PNG de `ue.ps1 capture` con `r.Lumen.Visualize=3` y `=5`, cobertura de la caché de superficie (`LumenVisualize.cpp:29-37`)».

### M2. El criterio de tono no distingue amarillo de naranja

- **Apartado:** 5.4, fila de tono.
- **Evidencia:**
  - 20° (`tools/capture/office_rooms_capture.gd:50`) es más de lo que separa el naranja del amarillo, que es justo la queja.
  - En bandas oscuras y poco saturadas, el tono es inestable.
- **Cambio que pido:** informar la diferencia de tono con su signo (hacia amarillo o verde, o hacia rojo) y la saturación de la banda. Sigue siendo un dato, no un veredicto.

### M3. Las referencias del hotel pueden cambiar la vara

- **Apartado:** 10, decisión 3 (`PLAN:447`).
- **Evidencia:** el plan acepta capturas de juegos como referencia, pero la vara del autor es una foto o una grabación de 1987.
- **Cambio que pido:** las capturas de juegos sirven para fijar el nivel de calidad. El tono y la luz se calibran solo contra fotos de época.

### M4. La hoja reducida esconde el ruido y la blandura del TSR al 67 %

- **Apartado:** 5.5, primer punto.
- **Cambio que pido:** entregar también cada PNG a tamaño completo, para juzgarlo en la vista de juego.

### M5. El volcado de oficinas «como están hoy en disco» no se puede repetir

- **Apartado:** 5.2, último párrafo.
- **Evidencia:** `game/world/generation/office_generator.gd` y otros cuatro archivos de oficinas están modificados sin confirmar (`git status`, 15 de noviembre).
- **Cambio que pido:** volcar desde un commit y anotar su hash en `salas.json`.

### M6. Falta en 5.6 lo que el autor tiene que bajar

- **Apartado:** 5.6.
- **Evidencia:** los modelos de Sketchfab necesitan la sesión del autor (`D/poc.md:228`), y 5.6 no lo pide.
- **Cambio que pido:** o la prueba se limita a `source_assets/`, Poly Haven y ambientCG, o 5.6 añade «bajar los modelos de Sketchfab de la lista de P7» con su fecha.

### M7. El nivel mínimo que se pide aceptar no se ve

- **Apartado:** 10, decisión 6.
- **Evidencia:** el autor acepta que el aspecto pida trazado sin ver el nivel «Sin trazado» (`D/render.md:107`).
- **Cambio que pido:** una pasada más de las 11 tomas con `r.RayTracing.Enable=0` y `r.MegaLights.Allowed=0` por anulación de ini. Es informativa y no bloquea.

## Sin comprobar

- **Tirones y fotos tardías.** No medí si, con la estrategia 1 de PSO y la compilación en segundo plano, una foto a los 3 s sale de verdad sin mallas o con el material por defecto. Lo deduzco del código citado.
- **Herramienta de vídeo del autor.** En el PATH aparece una carpeta de la NVIDIA App, pero no comprobé que tenga grabación instantánea.
- **Licencia de `ffmpeg`.** No la miré en la web: depende de la compilación.
- **Ventanas del histórico.** No sé cuántas ventanas de cuota gastó el desarrollo en Godot; solo cuento fechas y commits.
- **Cocinado.** No comprobé que el editor sin cocinar mida una memoria de vídeo distinta de la del paquete; propongo medir en el paquete por prudencia.
- **Visualización en el juego.** No comprobé que `r.Lumen.Visualize` funcione en `-game` con `-RenderOffScreen`; solo que el cvar existe y no es de solo lectura en su declaración.
