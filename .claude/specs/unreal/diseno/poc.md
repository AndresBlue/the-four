> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño: prueba de concepto visual del piso 1 y del piso 2 en Unreal Engine 5.8.4

Escrito el 15 de noviembre de 2026. Solo diseño: no se ejecutó Godot ni Unreal, no se compiló nada y no se consultó la web (los datos web vienen de los informes). `UE:` es `C:/Program Files (x86)/UnrealEngine/UE_5.8/`. `<P>/` es la carpeta del proyecto de Unreal, que fija el diseño de aplicación. Marcas: [G] leído hoy en el código de Godot, [M] leído hoy en el motor o en el catálogo MCP, [F] tomado de una ficha, un informe o un diseño hermano sin releer, [D] deducción o propuesta. Los tiempos son estimaciones: el reloj lo lleva el director.

## 1. Qué hay hoy en Godot

- **Plantas generadas por código, sin escenas.** El hotel monta cajas (un cubo unitario escalado) en MultiMesh por sala, material y forma (`game/world/hotel/hotel_geometry.gd:530-545` [G]); las oficinas añaden piezas de código sin UV (`game/world/office/pieces/`, 16 archivos [F `fichas/geo_oficinas.md`]) y modelos `.res`.
- **Las paredes ya son cajas cerradas con grosor.** Muro del hotel de 0,18 m (`hotel_geometry.gd:846, 1254, 1978` [G]); tabique de 0,12 m (`:204` [G]). Oficina: 0,18 m con caras a ±0,09 [F]; loseta de techo de 1,5 cm, friso de 1,5 cm y cristal de 8 mm (`game/world/office/office_geometry.gd:115, 56, 75` [G]). Suelo 0,3 m y techo 0,2 m [F `fichas/geo_hotel.md`].
- **Capturas con semilla y marcas fijas.** Hotel: `tools/capture/lookdev_capture.gd`, semilla 81, 1920×1080 (`:29` [G]), siete tomas (recepcion, dormitorio, salon, pasillo, bano, servicio, oscura, `:32` [G]) y cuatro primeros planos (`:114` [G]); cada una en `_raw.png` (sin cámara) y `_vhs.png` (como se juega) (`:6-8` [G]). Oficinas: `tools/capture/office_rooms_capture.gd`, 17 salas, 15 con foto (`:18-37` [G]), encuadre de `tools/capture/room_framing.gd` (ojo 1,5 m, 0,2 m fuera del hueco, FOV horizontal 55, `:11-14` [G]) y tres criterios numéricos (estructura 0,6, luma 25 %, tono 20°, `office_rooms_capture.gd:49-51` [F]). `tools/capture/office_angles_capture.gd` da la toma «llegada» (`:217-231` [G]).
- **Referencias.** 15 fotos de oficina en `docs/referencias/*.jpeg` [G, listado] y la del autor para la recepción, `evidence/rediseno/recepcion/referencia_autor.jpg` [G, existe]. **El hotel no tiene foto de referencia en el repo**; `docs/REALISM.md:38` remite a `evidence/reference/`, sin versionar [G]. Las capturas del autor con sus quejas: `evidence/autor_12nov/1.webp` a `6.webp` [G, existen].
- **Banco.** `tools/benchmarks/hotel_benchmark.gd` anota memoria de vídeo (`:224` [G]); `run_bench.ps1`, `compare_captures.gd`. Alto: unos 10 ms de GPU y 2,0 a 2,2 GB a 1080p en la 4060 Ti [F `fichas/render.md`].
- **Exportación glTF.** No hay ninguna herramienta que exporte; `GLTFDocument` solo aparece en copias antiguas de `build_catalogue.gd` para importar (`evidence/4c_base/build_catalogue.gd:193` [G]). Hay que escribirla.
- **Oficinas en movimiento.** `REAL_PLAN` está apagado (`game/floors/palettes/office_palette.gd:17` [G]) y hay cambios sin confirmar en generador, paleta y geometría (estado de git de hoy).

## 2. Cómo queda en Unreal

La prueba es un proyecto real (el mismo que seguirá el port), con dos mapas desechables. La geometría llega volcada desde Godot; luz, materiales, posprocesado, vestimenta de las salas elegidas y medición se hacen en Unreal.

### 2.1 Lado Godot (texto, en este repo)

| Archivo nuevo | Qué hace |
|---|---|
| `tools/unreal/export_floor_gltf.gd` | Levanta `game/app/hotel.tscn` como las capturas (`--floor`, `--seed`, `--planta`), quita los nodos ocultos y lo que no es malla, y escribe con `GLTFDocument` `planta.glb` más tres JSON |
| `luces.json` | Una fila por `Light3D`: clase, ruta del nodo, sala, posición, giro, energía, ángulo, alcance, color, si da sombra |
| `tomas.json` | Posición, base y FOV de cada toma de `lookdev_capture.gd`, `office_rooms_capture.gd` (vía `room_framing.gd`) y «llegada»: las mismas cámaras en los dos motores |
| `salas.json` | Id, tipo, caja y altura de cada sala; puertas (posición, giro, hoja) |

Salida en `<P>/SourceArt/poc/hotel_s81/` y `<P>/SourceArt/poc/oficinas_s7/`. Semillas 81 y 7: las de las capturas y el banco.

### 2.2 Lado Unreal

**C++ (texto).** Módulo `TheFour` y módulo `TheFourRender` (carpeta de sombreadores), como en `diseno/render.md` §2.2.

| Clase | Base | Para qué | Destino |
|---|---|---|---|
| `AFourPocCharacter` | `ACharacter`, partiendo de `HorrorCharacter` de la plantilla (`UE:Templates/TP_FirstPerson/Source/TP_FirstPerson/Variant_Horror/HorrorCharacter.h:9, 26` [M]: ya trae `USpotLightComponent`) | Andar, mirar, linterna (tecla), zoom. Velocidades y FOV leídos de `game/player/` | Desechable; la sustituye el dominio del jugador |
| `UFourPresentationSubsystem` (mínimo) | `UTickableWorldSubsystem` | `ApplyGrade(const FFourGrade&)`, `SetAir(float Density, float Anisotropy)`, `SetZoom(float)`; crea el volumen de posprocesado y la niebla | Se queda (R5 de render) |
| `FourLightFixtures.h` (filas usadas) | Tabla constante | `const FFourFixture& Fixture(EFourFixture)` | Se queda (R3) |
| `AFourPocBench` | `AActor` | Lee `tomas.json`; por toma: coloca la vista, espera, pide la captura, anota tiempos; después recorre una ruta fija. `void RunShots()`, `void RunWalk()` | Se queda como base de R18 |

**Sombreadores en texto:** `<P>/Shaders/Private/Camcorder/Lens.ush`, `Tape.ush`; `<P>/Shaders/TheFour/Tile.ush`.

**Guiones Python del editor (texto, `<P>/Tools/`):**

| Guion | Qué hace |
|---|---|
| `assets/import_textures.py`, `assets/build_materials.py` | Los de `diseno/materiales_assets.md` §2, limitados a `M_Surface`, `M_Prop`, `M_Decal`, `M_Emissive`, `M_Glass` y a las instancias que aparecen en las dos plantas |
| `poc/import_floor.py` | Importa `planta.glb` con Interchange a `/Game/Poc/<piso>/`, crea el mapa `L_Poc_<piso>`, pone colisión (caja en el cubo; compleja como simple en lo demás) y reasigna cada material de superficie por nombre a su `MI_*` |
| `poc/place_lights.py` | Lee `luces.json` y coloca luces según la tabla de reglas de 3; quita las mallas de puerta cerradas de las salas elegidas o las deja abiertas |
| `poc/dress_rooms.py` | En las salas elegidas: cambia piezas hechas a mano por modelos reales (tabla nombre de pieza a `SM_*`) y añade la vestimenta de `poc/dressing/<sala>.json` |
| `ies_from_profiles.py` | El de render R4, tres perfiles: `tube`, `dome`, `torch` |

**Assets (binarios, regenerables por los guiones):** mapas `L_Poc_Hotel` y `L_Poc_Oficinas`; mallas importadas; `MI_*`; `M_PP_Lens`, `M_PP_Tape`; `NS_DustMotes` (MCP, `NiagaraToolset_System`, `mcp_catalogo.md:174` [M]); tres `.ies`.

**Configuración (texto):** `Config/DefaultEngine.ini` según `diseno/render.md` §2.1, sin cambios.

**Plugins:** Interchange, PythonScriptPlugin, Niagara, ModelContextProtocol, AllToolsets. Ninguno externo.

**MCP: solo para mirar y retocar.** `load_level`, `add_to_scene_from_class` (`mcp_catalogo.md:611, 607` [M]), `SetCameraTransform`, `CaptureViewport` (`:101, 117` [M]). No tiene herramienta para fijar cvars (solo `SearchCVars`, `:106` [M]) ni para crear una malla desde cero [F `diseno/mundo.md` §10]. Las capturas que se juzgan no salen del MCP sino del juego lanzado (apartado 5.4).

## 3. Correspondencia pieza a pieza

| Godot | En la prueba | Cómo |
|---|---|---|
| Cajas en MultiMesh | Un actor por caja, todos con la misma malla cubo (Godot exporta un nodo por instancia [F `briefs/experiencias.md`, `gltf_document.cpp:4405-4452`]) | glTF e Interchange |
| Molduras y piezas de código (`mouldings.gd`, `pieces/`) | Mallas estáticas tal cual | glTF |
| Modelos `.res` | Mallas con sus texturas | glTF (calidad por comprobar) |
| `ShaderMaterial` de superficie (sale solo el nombre [F `gltf_document.cpp:2672-2676`]) | `MI_<nombre>` de `M_Surface` | Reasignación por nombre |
| Luz de sala del hotel (4,25 o 4,5) | `UPointLightComponent` con IES `dome` o `tube`, lúmenes y kelvin de la tabla | `place_lights.py` |
| Aplique del hotel | `UPointLightComponent`, fila `sconce` | Ídem |
| Par de focos por tubo de oficina (pozo de 75° y rebote) | Un `URectLightComponent` del tamaño del difusor; el foco de rebote y la luz de sala se descartan | Ídem (render §3) |
| Regleta (85°), emergencia (55°) | Luz de punto con `SourceLength`; foco | Ídem |
| VoxelGI, sondas, SSR, capas de render | Nada: Lumen y MegaLights | — |
| Colisión (extensiones OMI que Interchange ignora [F]) | Colisión simple del cubo y compleja en el resto | `import_floor.py` |
| Decals, `Label3D`, partículas, `FogVolume` (no viajan por glTF) | 4 decals a mano en salas elegidas; rótulos fuera; niebla del motor; motas Niagara | Guion y MCP |
| Hojas de puerta | Mallas fijas, abiertas | `salas.json` |
| Linterna (foco 10, 32°, 24 m [F render §1]) | `USpotLightComponent` con IES `torch` | `AFourPocCharacter` |
| `lens.gdshader`, `analog.gdshader` | `M_PP_Lens`, `M_PP_Tape` | `.ush` |
| Medidor, iris, halo, grano | Exposición automática, resplandor y grano del volumen | Datos |
| Smear CCD, OSD, estela de giro propia | Fuera | — |
| `lookdev_capture.gd`, `office_rooms_capture.gd` | `AFourPocBench` con `tomas.json` | C++ |
| `hotel_benchmark.gd` | `AFourPocBench::RunWalk` con el perfilador CSV | C++ |

## 4. Decisiones

**D1. Camino elegido: volcar a glTF una planta de cada piso y rehacer en Unreal luz, materiales, posprocesado y la vestimenta de las salas elegidas.** Comparación:

| | A. Volcado glTF (elegido) | B. Tramo montado por guion | C. Portar ya el generador |
|---|---|---|---|
| Qué se pierde | Sombreadores (solo nombre), luces (sin unidades), colisión, decals, rótulos, partículas, instanciado (un actor por caja) | La planta real: distribución, proporciones, vistas largas entre salas | Nada, pero no añade nada que se vea |
| Geometría y Lumen | Sirve: muros, suelos y techos son cajas cerradas de 12 a 30 cm (apartado 1), por encima del mínimo de 10 cm de las tarjetas [F render D4]. El z-fighting viaja con ella: si existe en Godot, se verá | La que se quiera | Igual que A |
| Representatividad | Alta: es la planta que jugará el autor, con las mismas cámaras. Enseña también lo que da un port mecánico fuera de las salas elegidas | Baja: un decorado puede verse mejor de lo que el generador sabrá producir | Total |
| Tiempo | Una herramienta de Godot y tres guiones | Parecido, pero cada posición hay que decidirla a mano | Semanas: unas 9 000 líneas con paridad [F mundo D1] |
| Se reutiliza | Ajustes, materiales, tabla de luces, IES, cámara, banco, regla de ejes validada, lista de piezas a sustituir | Lo mismo, menos la validación sobre planta real | Todo |

B se descarta como base y se usa dentro de A: en las salas elegidas se sustituyen piezas y se añade vestimenta por guion. C se descarta: gasta semanas antes de saber si el autor quiere el port.

**D2. Diferencia con `diseno/mundo.md` §5 (se dice expresamente).** Aquel diseño mete en la prueba `FourCore/Gd`, un volcado del plan en JSON y `AFloorBuilder` con instancias de `SM_Box`. Aquí no entran: el plan en JSON no lleva las molduras ni las piezas de código (son mallas, no cajas), y escribir el constructor retrasa la respuesta visual. Consecuencia: las medidas de CPU de la prueba son pesimistas (miles de actores en vez de instancias) y el riesgo R3 de mundo (Lumen con cubos de escala desigual) sí queda cubierto, porque el cubo llega igual de escalado. `AFloorBuilder` y `FourCore/Gd` pasan a ser las primeras unidades tras el sí.

**D3. Diferencia con `diseno/render.md` §5.** Aquel propone cuatro escenas montadas por guion; aquí son salas de la planta volcada. Sus ajustes, su lista de efectos y lo que «decide» (D6, D9, ruido de MegaLights) se mantienen. Con `diseno/materiales_assets.md` §5 no hay conflicto: sus seis instancias y `Tile.ush` entran; sus 15 piezas llegan dentro del glb en vez de una a una.

**D4. Una planta entera por piso, no un sector.** Hace falta para medir memoria y fotograma con honradez y para andar sin encontrar el borde. Si Interchange no puede con ella (riesgo 1), la herramienta acepta `--sector=<sala>,<puertas>` y se vuelca el entorno de las salas elegidas.

**D5. Oficinas tal como están hoy en disco, con `REAL_PLAN` apagado.** La prueba juzga luz, materia y densidad, no la distribución. Si el autor prefiere el edificio real, se vuelca con `--real-plan` (`office_palette.gd:21` [G]) sin cambiar nada más.

**D6. Luces por reglas desde `luces.json`, no las del glTF.** Interchange lee la energía de Godot como candelas [F]; las reglas de la tabla 3 dan unidades físicas y reducen tres luces por tubo a una. Valores de partida, los de render D5.

**D7. El personaje sale de la plantilla de Epic, no de Mover ni de código nuevo.** Es desechable y ya trae linterna. Mover es Experimental [F `briefs/ue58.md`].

**D8. Las capturas se toman con el juego lanzado, no en el editor.** `UnrealEditor.exe <uproject> <mapa> -game -windowed -ResX= -ResY=` con `AFourPocBench`. Es lo que verá el jugador (posprocesado, TSR, exposición) y no depende del visor del editor. La captura la pide `HighResShot` (`UE:Engine/Source/Runtime/Engine/Private/UnrealClient.cpp:2470` [M]).

**D9. Sin Megascans ni cuentas en la prueba.** Se usan los originales CC0 que ya están en `source_assets/` y Poly Haven. Si el autor trae Megascans, mejora el techo, pero el veredicto no puede depender de ello.

**D10. Nivel de calidad único: Alto de render D3** (Lumen por hardware calidad 2, MegaLights con 4 muestras, TSR al 67 % a 1080p y 58 % a 1440p). Una segunda pasada a 1440p con el 50 % solo si la primera no cabe.

## 5. Qué entra y qué no

### 5.1 Salas

| Piso | Sala | Toma de Godot | Referencia | Queja que ataca |
|---|---|---|---|---|
| 2 | Recepción y llegada | `office_angles_capture` «llegada», `recepcion` | `recepción.jpeg`, `referencia_autor.jpg` | Tono; reflejo del suelo encerado |
| 2 | Pasillo | la de `llegada` o tramo contiguo | la general de `docs/referencias/oficinas/LEEME.md` | Charcos de luz, z-fighting de suelo |
| 2 | Despacho | `despacho` | `despacho.jpeg` | Vacío; piezas hechas a mano |
| 2 | Sala de aseos | `aseos` | `sala de aseos.jpeg` | Reflejos de suelo mojado |
| 2 | Nave de cubículos | `cubiculos` (sin foto) | la general | Vacío; 9 a 16 luminarias (MegaLights) |
| 2 | Archivo, a oscuras | `archivo` | `archivo.jpeg` | Linterna, sombras, motas |
| 1 | Recepción | `recepcion` | la que dé el autor | Tono; baliza roja |
| 1 | Pasillo con apliques | `pasillo` | ídem | Charcos de luz, moqueta |
| 1 | Dormitorio | `dormitorio`, `cama` | ídem | Piezas hechas a mano (cama, armario) |
| 1 | Baño | `bano`, `azulejo` | ídem | Baldosa, reflejos |
| 1 | Sala oscura | `oscura` | ídem | Linterna |

El resto de cada planta se recorre con materiales y luces por regla, sin vestir: es la línea base honrada.

### 5.2 Luces y efectos que entran

Lumen por hardware, MegaLights con sombra trazada, sin luz de cielo ni ambiente; luces de sala, apliques, luminarias rectangulares, regletas y emergencias por regla; linterna con IES; niebla de altura volumétrica con los valores por piso; `NS_DustMotes`; exposición automática con máscara centrada; blanco a 3200 K y gradación por piso; resplandor y grano del motor; `M_PP_Lens` y `M_PP_Tape`; TSR; cuatro decals (mancha de techo, suciedad de zócalo, charco, desgaste).

### 5.3 Assets que entran

Seis instancias de `M_Surface` por piso (pared, suelo, techo, madera, metal, baldosa) con sus sets CC0 de `assets/textures/` a 2048 px; `Tile.ush`; los modelos que ya trae el glb; y, en las salas elegidas, sustitutos reales para lo hecho a mano: hoja y marco de puerta, cama, armario, mostrador, y los tipos de oficina sin modelo que caigan en esas salas (lista en materiales §6, unidad 13). Tope: 20 modelos nuevos.

### 5.4 Protocolo de comparación

1. **Mismas cámaras.** `AFourPocBench::RunShots` recorre `tomas.json`; 3 s de espera por toma [D]; dos PNG por toma: sin `M_PP_Lens` ni `M_PP_Tape` (equivale a `_raw`) y con ellos (`_vhs`). Parpadeo congelado.
2. **Lado a lado.** Tres columnas: Godot `_vhs` de hoy, Unreal, foto de referencia; una fila por toma. Se compone con `tools/capture/lookdev_sheet.gd` (ya hace columnas, `docs/REALISM.md:36` [G]). Salida en `evidence/unreal_poc/`.
3. **Cifras de imagen.** A las tomas de oficina se les aplican los tres criterios de `office_rooms_capture.gd` (bandas techo, pared y suelo, `:42` [G]) como dato, no como veredicto.
4. **Rendimiento.** `RunWalk`: ruta fija de 60 s por las salas elegidas, linterna encendida la mitad. Dos pasadas, 1920×1080 y 2560×1440, nivel Alto, sin límite de fotogramas. Se anota: fps medio, p95 y p99 de fotograma, ms de hilo de juego, de render y de GPU con el perfilador CSV (`CsvProfile`, `-csvCaptureFrames=`, `-csvGpuStats`: `UE:Engine/Source/Runtime/Core/Private/ProfilingDebugging/CsvProfiler.cpp:1118, 5049, 5098` [M]); desglose por pasada con `ProfileGPU` en tres tomas (`UE:Engine/Source/Runtime/RHI/Private/GPUProfiler.cpp:2199` [M]); VRAM con `nvidia-smi --query-gpu=memory.used` cada segundo, restando la lectura con el juego cerrado.
5. **Godot, misma mesa.** Los números de Godot salen de `tools/benchmarks/run_bench.ps1` en Alto con las mismas semillas y de `docs/PERFORMANCE.md`; la VRAM, también con `nvidia-smi` para que sea la misma vara.
6. **Vídeo.** Un clip de 60 s del recorrido por piso, para juzgar z-fighting, ruido de MegaLights y respuesta de Lumen, que una foto no enseña.

### 5.5 Qué no entra

Gameplay, criaturas, puertas que se abren, interactivos, sonido, interfaz, OSD, red, generador, validadores, `FourCore`, `AFloorBuilder`, niveles de calidad distintos de Alto, nivel sin trazado, smear CCD, cinta de muerte, visión de eco, sangre, televisor, DLSS y FSR, espera de PSO, empaquetado. Las tres plantas de cada piso: solo una.

### 5.6 Criterios de aceptación y la pregunta

| Vara del autor | Se da por cumplido si |
|---|---|
| Tono anaranjado sutil, no amarillo verdoso | En las tomas de oficina, el tono de la banda de pared queda a 20° o menos de su referencia, y el autor lo confirma a ojo |
| Reflejos de suelo | En recepción y aseos el suelo refleja la forma de las luminarias; ninguna mancha blanca redonda |
| Z-fighting | Ningún parpadeo de superficie en los dos vídeos de 60 s |
| Ambiente vacío | En las salas elegidas no queda superficie horizontal desnuda que en la referencia esté ocupada |
| Hecho a mano que parece 3D | En las salas elegidas, ninguna pieza visible es de cajas de código (lista cerrada en `dress_rooms.py`) |
| Foto de época | En al menos 8 de las 11 parejas el autor dice que la toma de Unreal se sostiene junto a la referencia |
| Máquina | 1080p Alto: p95 de fotograma de 16,6 ms o menos y VRAM de 6,5 GB o menos (render D9). 1440p: se mide y se informa; no bloquea |

**La pregunta al autor (sí o no):** «Con estas 11 parejas, los dos vídeos y la tabla de rendimiento delante: ¿se porta The Four a Unreal?» Si es no, se le pide en una frase qué pareja lo decide.

## 6. Unidades de trabajo

«∥» = pueden ir en paralelo entre sí (solo texto, archivos disjuntos). Lo que abre el editor o Godot va en serie: una sola instancia.

| # | Unidad | Origen | Resultado | Prueba de aceptación |
|---|---|---|---|---|
| P0 | Proyecto y ajustes (editor) | `TP_Blank`, render §2.1 | `<P>` con `TheFour`, `TheFourRender`, `DefaultEngine.ini`, plugins | `Build.bat` en verde; el editor arranca sin el aviso de MegaLights; primer arranque cronometrado |
| P1 ∥ | Exportador de Godot | `lookdev_capture.gd`, `office_rooms_capture.gd`, `room_framing.gd`, `office_angles_capture.gd` | `tools/unreal/export_floor_gltf.gd` | `--check-only` limpio (revisor) |
| P2 | Volcado (Godot, director o un agente) | P1 | `planta.glb`, `luces.json`, `tomas.json`, `salas.json` de hotel 81 y oficinas 7 | El glb no declara extensiones obligatorias; recuento de nodos y de luces anotado |
| P3 ∥ | Materiales en texto | `surface.gdshaderinc`, `tile.gdshader`, `.tres` de las dos plantas | `build_materials.py`, `import_textures.py`, `materials.json` reducido, `Tile.ush` | Cada nombre de material del glb tiene entrada |
| P4 ∥ | Cámara en texto | `lens.gdshader`, `analog.gdshader`, `office_geometry.gd:203-217`, `camcorder_effect.gd:37, 73` | `Lens.ush`, `Tape.ush`, `UFourPresentationSubsystem` mínimo, `FFourGrade` de cada piso | Compila |
| P5 ∥ | Luces en texto | `lighting.gd:66-123`, constantes de luz de ambas geometrías | `FourLightFixtures.h` (filas usadas), `ies_from_profiles.py`, reglas de `place_lights.py` | Cada combinación clase, energía y ángulo de `luces.json` tiene regla |
| P6 ∥ | Personaje y banco en texto | `HorrorCharacter` de la plantilla, `game/player/` | `AFourPocCharacter`, `AFourPocBench` | Compila |
| P7 ∥ | Lista de sustituciones y vestimenta | Referencias de 5.1, `source_assets/`, materiales §6 unidad 13 | Tabla pieza a modelo, `poc/dressing/<sala>.json`, altas en `docs/ASSETS.md` | Cada modelo con licencia CC0 o CC BY registrada |
| P8 | Importación (editor) | P2, P3 | `L_Poc_Hotel`, `L_Poc_Oficinas`, `MI_*` | Ninguna malla con el material por defecto; el personaje anda sin atravesar muros; vista «Lumen Scene» con tarjetas en muros |
| P9 | Luz, aire y cámara (editor) | P4, P5, P8 | Luces, niebla, motas, posprocesado | Ninguna luz cruza una pared en las salas elegidas; primera hoja de comparación |
| P10 | Vestir las salas elegidas (editor) | P7, P9 | Salas de 5.1 vestidas y con decals | Lista de piezas de código visibles: vacía |
| P11 | Calibrar contra referencia (editor, 2 rondas como mucho) | P10 | Lúmenes, kelvin, `FFourGrade`, curva (render D6) | Criterio de tono de 5.6 |
| P12 | Medición y entrega | P11 | Hojas, vídeos, tabla de 5.4 en `evidence/unreal_poc/` | Tabla completa a 1080p y 1440p |

Orden: P0 y P1 a la vez; P2; P3 a P7 en paralelo desde el principio (no esperan a P2 salvo su prueba); P8 a P12 en serie. **Duración estimada con el método de agentes [D]:** 4 a 6 ventanas de cuota, 2 a 3 días de calendario; el tramo en serie (P8 a P12) manda.

**Desechable:** los glb y JSON del volcado, los dos mapas, `import_floor.py`, `place_lights.py`, `dress_rooms.py`, `AFourPocCharacter`. **Queda para el port:** el proyecto y sus ajustes (render R1, R2), `Lens.ush` y `Tape.ush` (R6, R7), la tabla de luces y los IES (R3, R4), `UFourPresentationSubsystem` (R5), la cadena de materiales (materiales 1, 2 y 4), `AFourPocBench` (R18), `tomas.json` como contrato de capturas, la lista de sustituciones (materiales 13) y las medidas.

**Tras un sí, el port sigue por los otros diseños en este orden:** mundo U0 y U1; render R3 a R8 y materiales 3 a 10 en paralelo; mundo U2 a U11; después el resto de dominios.

## 7. Riesgos y cómo se detectan pronto

| # | Riesgo | Detección |
|---|---|---|
| 1 | Interchange tarda demasiado o falla con una planta de miles de nodos | P2 anota el recuento; P8 empieza por el hotel; salida `--sector` (D4) |
| 2 | El glb declara `KHR_node_visibility` obligatoria y la importación aborta [F] | P1 quita los ocultos; P2 lo comprueba leyendo la cabecera JSON del glb |
| 3 | Mallas de código abiertas o de una cara (molduras, lentes) dan fugas o caras negras en Lumen | Vista «Lumen Scene» y una toma con la luz apagada en P8 |
| 4 | Los modelos pierden calidad de textura o canales ORM al pasar por glTF | Tres piezas mirando de cerca en P8; salida: importarlas desde `source_assets/` |
| 5 | VRAM por encima de 8 GB con trazado | `nvidia-smi` en la primera carga de P8, antes de vestir |
| 6 | Ruido o estela de MegaLights con la linterna en movimiento | Vídeo en P9 |
| 7 | La curva tonal se lee como cine y no como vídeo | Primera hoja de P9 (render D6) |
| 8 | El guion de Python no guarda mapas o no compila materiales sin ventana | P8 primer intento con `-run=pythonscript`; salida: editor abierto con `-ExecutePythonScript=` |
| 9 | La prueba se ve mejor de lo que el generador portado sabrá producir | La vestimenta de P10 solo usa reglas expresables por sala y tipo; lo que se coloque «a ojo» se anota |
| 10 | El hotel se juzga sin referencia y la calibración no acaba | Pregunta 1 antes de P11; tope de dos rondas |
| 11 | La ruta del repo lleva un espacio («The Four») y alguna herramienta de Unreal falla | P0; salida: proyecto en una ruta sin espacios |
| 12 | 1440p no se puede lanzar en ventana si el monitor es menor | P12; salida: `r.ScreenPercentage` equivalente y decirlo en la tabla |

## 8. Preguntas para el autor

1. **Referencias del hotel.** No hay fotos del hotel en el repo. ¿Cuáles valen para recepción, pasillo, dormitorio y baño (o se toman capturas de Subliminal y los otros juegos del listón)?
2. **Megascans.** ¿Lo traes con tu cuenta de Epic para la prueba, o se juzga solo con CC0 sin cuenta?
3. **Oficinas.** ¿Se vuelca el piso 2 como está hoy o con el edificio real (`REAL_PLAN`)?
4. **1440p.** ¿Tu monitor es de 1440p o más? Si no, esa medida se hace por resolución interna equivalente.

## 9. Herramientas, plugins y assets

| Qué | Fuente | Licencia | Cuenta |
|---|---|---|---|
| Software nuevo | Ninguno: Interchange, Python, Niagara, MCP y la plantilla de primera persona vienen con el motor | — | No |
| `nvidia-smi` | Viene con el controlador de NVIDIA | — | No |
| Texturas y modelos | `assets/textures/`, `source_assets/` (ya en disco), Poly Haven, ambientCG | CC0 | No |
| Hasta 20 modelos de época | Poly Haven; Sketchfab solo CC0 o CC BY | CC0, CC BY | Sketchfab pide la sesión del autor |
| Megascans (opcional) | Fab | Estándar de Fab, comercial [F] | Sí, la del autor |

Fuera: The Locust (CC BY-NC-ND) y Realistic Female (CC BY-SA) no entran en el proyecto de Unreal [F `briefs/experiencias.md`]; la prueba no lleva personajes.

## 10. Sin comprobar

- Nada se ejecutó: ni la exportación glTF de una planta (tamaño, tiempo, nodos), ni su importación, ni un solo fotograma en Unreal. Todos los tiempos y presupuestos son estimaciones.
- Que `GLTFDocument` exporte bien en ejecución las mallas de código y los `ORMMaterial3D` con sus texturas, y la opción exacta para la visibilidad de nodos.
- Que Interchange cree una sola malla para el cubo repetido y no una por nodo; el nombre de su API en Python; que conserve los nombres de material de Godot.
- Que las mallas de código sean cerradas; solo se comprobó que muros y cajas lo son. Suelo de 0,3 m y techo de 0,2 m vienen de la ficha.
- Que no haya caras coplanares en la planta volcada.
- Que Nanite, activado por defecto al importar, se lleve bien con cubos de escala desigual y con mallas de material translúcido.
- Cómo se nombran y distinguen los nodos de luz en Godot (las reglas usan clase, energía y ángulo; puede hacer falta otra pista).
- Velocidad de marcha y parámetros de zoom del jugador: no se leyó `game/player/`. La equivalencia de 78° verticales con 110,4° horizontales es del informe.
- Que `HighResShot` y el perfilador CSV funcionen con `-game` en una compilación de editor de motor instalado; solo se comprobó que existen.
- Que `lookdev_sheet.gd` y los criterios de `office_rooms_capture.gd` acepten imágenes que no hizo Godot.
- Que `nvidia-smi` esté en esta máquina y que su lectura por proceso valga en Windows (por eso se resta la base).
- Que `evidence/reference/` exista y qué contiene; no se abrió ninguna imagen de referencia ni las capturas del autor.
- Qué semilla de oficinas tiene todas las salas de 5.1 en una misma planta; puede hacer falta otra semilla o dos plantas.
- Gratuidad y licencia de Megascans y condiciones de Sketchfab: vienen de los informes; no se consultó la web en este encargo.
- Los puntos marcados [F] no se releyeron.
