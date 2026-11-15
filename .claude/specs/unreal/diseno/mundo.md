> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: generación procedural y construcción del mundo

15 de noviembre de 2026. Solo diseño: no se ha ejecutado Godot ni Unreal ni se ha compilado nada.
Abreviaturas de las fuentes: `GD:` = https://github.com/godotengine/godot/blob/4.7-stable/ (leído hoy; el juego usa 4.7.2, ver apartado 10). `UE:` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine/`. Las rutas sin prefijo son del repo.

## 1. Qué hay hoy en Godot

- **Generadores (lógica pura, sin nodos).** `game/world/generation/`: `map_generator.gd` (2116 líneas, hotel), `office_generator.gd` (3808, hereda del hotel y sustituye unas 18 funciones), `office_layout.gd` (384), `office_recipes.gd` (840), `floor_definition.gd` (321), `wall_walker.gd` (121), `conduit_graph.gd` y `conduit_metres.gd`, y las colocaciones `digit_`, `document_`, `hint_`, `tv_placement.gd` y `exit_route_signs.gd`. Tablas en `game/floors/palettes/hotel_palette.gd` (297) y `office_palette.gd` (1222).
- **Salida.** Un `Dictionary` sin esquema, el manifiesto: `rooms`, `edges`, `adjacency`, `doors`, `gates`, `plantas` y, en oficinas, `ducts`, `tubes`, `air`, `furniture` (fichas `gen_hotel.md` §4 y `gen_oficinas.md` §3).
- **Azar.** Solo instancias de `RandomNumberGenerator` con `seed = hash([semilla, "texto", ...])`, un flujo por sistema (`map_generator.gd:140-141, 161-162, 195-208`). No hay `randi()` global en la generación.
- **Validadores.** `map_validator.gd` (316) y `office_validator.gd` (1335, 19 grupos). Solo `validate_physics()` necesita el mundo de física ya montado.
- **Huella dorada.** `tests/hotel/manifest_golden.json`: 255 casos, cada uno el SHA-256 de `JSON.stringify(manifiesto, "", true, true)` (`tools/dev/record_manifest_golden.gd:53-55`). Solo cubre el hotel.
- **Montaje.** No hay escenas: `game/world/hotel/hotel_geometry.gd` (3298) y los 28 archivos de `game/world/office/` (9688) convierten el manifiesto en cajas (un cubo unitario escalado, agrupado en MultiMesh por sala, material y forma), modelos `.res` en MultiMesh, un cuerpo estático por sala con una caja de colisión por caja sólida, una luz de techo por sala, puertas a partir de las aristas y una región de navegación por planta (ficha `geo_hotel.md` §2, §8, §9, §11).
- **Variación cosmética.** `vary()` es un hash de seno sobre la posición, no consume el azar del generador (`hotel_geometry.gd:503-504`).
- **Navegación.** Las criaturas piden rutas a `NavigationServer3D` a través de `FLOOR.navigation_path` (`game/enemies/locust/hotel_locust.gd:738, 1353, 1833`).
- **Coste medido.** Piso 2, semilla 7: 413 salas, 26 358 nodos, carga de 19,5 s (ficha `geo_oficinas.md` §10).
- **Red.** Los clientes reciben la semilla (`hotel_main.gd:1022`, según la ficha) y generan cada uno su planta.

## 2. Cómo queda en Unreal

Tres capas. La regla: cuanto más abajo, menos motor.

### 2.1 `FourCore`: C++20 sin cabeceras de Unreal

Carpeta `Source/FourCore/`. Es un módulo de Unreal (tipo Runtime, sin dependencias, `FPSemantics = Precise`) y a la vez una biblioteca que se compila sola con `cl.exe` para las pruebas. Todo trabaja en el espacio de Godot (metros, Y arriba), con los mismos tipos numéricos que GDScript.

| Carpeta | Contenido |
|---|---|
| `Gd/` | `FGdRandom` (PCG32), `GdHash` (hash de Variant), `GdSort` (introsort de Godot), `FGdVec2/FGdVec2i/FGdVec3/FGdRect2/FGdRect2i` (componentes `float` de 32 bits), `TGdDict<K,V>` (diccionario que conserva el orden de inserción), `GdMath` (`snappedf`, `fposmod`, `lerpf`, `clampi`, `ceili`), `FGdValue` (variante mínima: nulo, bool, entero de 64, real de 64, texto, lista, diccionario) |
| `Floor/` | `FFloorDef` (port de `floor_definition.gd` sin navegación), `FManifest` (estructuras con nombre: `FRoom`, `FDoor`, `FGate`, `FPlanta`...), `ManifestCanon` (volcado canónico y SHA-256) |
| `Gen/` | `FMapGenerator`, `FOfficeGenerator` (hereda), `FWallWalker`, `FMapValidator`, `FOfficeValidator` (solo la parte lógica), colocaciones, `FHotelPalette`, `FOfficePalette` como tablas `constexpr` |
| `Plan/` | `FBuildPlan`: lo que hay que montar, todavía en metros de Godot. Listas de `FPlanBox` (centro, tamaño, giro, material, sala, sólida, datos por instancia), `FPlanPiece` (id de pieza, transformación, sala), `FPlanLight`, `FPlanDoor`, `FPlanInteractive`, `FPlanNavBounds`. Lo producen `FHotelPlanner` y `FOfficePlanner` (port de la parte de `hotel_geometry.gd` y `office_*.gd` que decide dónde va cada cosa) |
| `Tests/` | `main.cpp` con las pruebas; ejecutable `four_core_tests.exe` |

Firmas clave (nombres, no código):

- `FGdRandom::SetSeed(uint64)`, `Randi() -> uint32`, `Randf() -> float`, `RandiRange(int32, int32) -> int32`, `RandfRange(float, float) -> float`, `GetState() -> uint64`.
- `GdHash::Of(const FGdValue&) -> uint32`.
- `FMapGenerator::Generate(int64 RunSeed, int32 Survivors, FManifest& Out) -> bool` y `Candidate(RunSeed, Attempt, bStandby)`.
- `ManifestCanon::Write(const FManifest&, std::string& Out)` y `ManifestCanon::Sha256(...)`.
- `FHotelPlanner::Build(const FManifest&, FBuildPlan& Out)`.

### 2.2 `FourWorld`: módulo Runtime de Unreal

Depende de `Core`, `CoreUObject`, `Engine`, `NavigationSystem`, `FourCore`.

- `FFourSpace` (un solo archivo, `FourSpace.h`): la única conversión de unidades y ejes (decisión D8).
- `AFloorBuilder`: recibe un `FBuildPlan` y monta. Un `UInstancedStaticMeshComponent` por planta y por par (malla, material); luces, puertas e interactivos como actores por sala. Monta por tramos (N instancias por fotograma) y avisa con `OnFloorReady`.
- `UFloorSubsystem` (`UWorldSubsystem`): guarda manifiesto y plan, lanza la generación en una tarea de fondo, expone `RoomAt(FVector)`, `PlantaOf(FVector)`, vecinos y puertas a los demás dominios, y lleva la visibilidad por planta y el encendido de luces por distancia en el grafo de salas (port de `update_visibility`).
- `AFourDoor`, `AFourRoomLight`, `AFourInteractive` (base): actores C++ creados en cada máquina a partir del plan, con nombre estable (`Door_a_b`, `Room_id_...`) para que la red pueda referirse a ellos.
- `FFourKit`: tabla en C++ de id de pieza y de material a ruta de asset (`/Game/Kit/...`).
- Navegación: `ARecastNavMesh` con `RuntimeGeneration=Dynamic` en `Config/DefaultEngine.ini` y un `ANavMeshBoundsVolume` por planta creado al montar.
- Canales de colisión en `Config/DefaultEngine.ini` (tabla del apartado 3).

### 2.3 Assets

- `SM_Box`: cubo de 1 m con colisión simple de caja y Nanite activado. Con él se montan muros, suelos, techos y losas, igual que hoy.
- Kit modular (marcos de puerta, zócalos, cornisas, losetas, luminarias, mobiliario): mallas estáticas con Nanite, creadas por guion (Blender 5.2 sin interfaz a glTF, importación con `StaticMeshTools.import_file` del MCP o con `-run=pythonscript`). Los modelos CC0 ya ingeridos se reimportan desde sus originales.
- Materiales del casco alineados al mundo (sin UV, como hoy): los decide el dominio de materiales.
- Ningún nivel `.umap` con contenido: un mapa vacío con el `AFloorBuilder`.

## 3. Tabla de correspondencia

| Godot | Unreal | Dónde |
|---|---|---|
| `RandomNumberGenerator` | `FGdRandom` | `FourCore/Gd` |
| `hash([..])` de Variant | `GdHash::Of` | `FourCore/Gd` |
| `Array.sort_custom` | `GdSort::Introsort` | `FourCore/Gd` |
| `Dictionary` (orden de inserción) | `TGdDict` | `FourCore/Gd` |
| `Vector2`, `Rect2`, `Vector3` (float de 32) y `float` (64) | `FGdVec*`, `FGdRect2*`, `double` | `FourCore/Gd` |
| `map_generator.gd`, `office_generator.gd` | `FMapGenerator`, `FOfficeGenerator` | `FourCore/Gen` |
| `hotel_palette.gd`, `office_palette.gd`, `office_recipes.gd` | tablas `constexpr` | `FourCore/Gen` |
| Manifiesto `Dictionary` | `FManifest` (estructuras) | `FourCore/Floor` |
| `manifest_golden.json` | `golden/manifest_canon.json`, compartido | repo |
| `map_validator.validate`, `office_validator` | `FMapValidator`, `FOfficeValidator` | `FourCore/Gen` |
| `validate_physics()` | prueba de Automation con barridos de cápsula | `FourWorld/Tests` |
| `hotel_geometry.box()` y `flush()` | `FPlanBox` y `AFloorBuilder` con ISM de `SM_Box` | `Plan`, `FourWorld` |
| `place()` de modelos `.res` | `FPlanPiece` e ISM por malla | `Plan`, `FourWorld` |
| `StaticBody3D` «Solid» por sala | colisión por instancia del ISM; las cajas no sólidas van en otro ISM sin colisión | `FourWorld` |
| `vary()` | `GdMath::Vary` | `FourCore/Gd` |
| Capa 1 mundo | `ECC_WorldStatic` | ini |
| Capa 4 supervivientes | `ECC_Pawn` | ini |
| Capas 8, 16, 32, 64, 128 | canales propios `DoorLeaf`, `Interactive`, `Creature`, `SenseOnly`, `SurvivorOnly` | ini |
| `OmniLight3D` por sala | `AFourRoomLight` (punto, rectángulo o foco) | `FourWorld` |
| `room_layers.gd` (16 capas de render) | no se porta: `MaxDrawDistance` y encendido por grafo de salas | `FourWorld` |
| `update_visibility` en 3 rondas, `put_away` | `UFloorSubsystem` (planta del ojo y luces cercanas) | `FourWorld` |
| VoxelGI horneado, sondas de reflejo | no se portan: Lumen | dominio render |
| `NavigationRegion3D` por planta | `ARecastNavMesh` dinámica y volumen por planta | `FourWorld` |
| `FLOOR.navigation_path`, `FLOOR.closest` | `UNavigationSystemV1::FindPathToLocationSynchronously`, `ProjectPointToNavigation` | `FourWorld` |
| `hotel_door.gd` | `AFourDoor` | `FourWorld` |
| Construcción con `await` de fotogramas | generación en tarea de fondo y montaje por tramos | `FourWorld` |

## 4. Decisiones

**D1. Paridad bit a bit del manifiesto con Godot, como prueba de que el port es fiel.** Son unas 9 000 líneas de lógica; comparar manifiestos es la única prueba barata de que se han portado bien. Descartado: «misma distribución, otras plantas» (obligaría a rehacer todos los validadores estadísticos antes de saber si el port es correcto). Cuando la paridad esté demostrada, la huella de C++ pasa a ser la verdad y Godot se congela.

**D2. El azar se porta literal.** Comprobado en el código de Godot:
- PCG32: `state = state * 6364136223846793005 + (inc|1)`, salida xorshift con rotación (`GD:thirdparty/misc/pcg.cpp:10-14`). El incremento es `PCG_DEFAULT_INC_64` y `seed()` llama a `pcg32_srandom_r` (`GD:core/math/random_pcg.h:61, 65-68`).
- `randi_range`: `min + pcg32_boundedrand(diff + 1)`, con rechazo por umbral `-bound % bound`; si `from == to` no consume azar (`GD:core/math/random_pcg.cpp:79-93`, `pcg.cpp:30-57`).
- `randf`: consume dos `rand()`; `ldexp(float(rand() | 0x80000001), -32 - clz(primero))`, y devuelve 0 con un solo `rand()` si el primero es 0 (`random_pcg.h:109-115`). Devuelve `float` de 32 bits.
- `randf_range(a, b)`: `randf() * (b - a) + a` en `float` de 32 bits (`random_pcg.cpp:75-76`; `GD:core/math/random_number_generator.h:55`).
- `hash()` de lista: `h = murmur3_one_32(tipo ARRAY)`, luego `murmur3_one_32(hash del elemento, h)` por elemento y `fmix32` al final (`GD:core/variant/array.cpp:195-207`). Entero: `hash_one_uint64` (`GD:core/variant/variant.cpp:2817-2818`, `GD:core/templates/hashfuncs.h:87-96`). Real: `hash_murmur3_one_double` con ±0 y NaN normalizados (`GD:core/templates/hashfuncs.cpp:51-67`). Texto: djb2 sobre los puntos de código de 32 bits, no sobre UTF-8 (`GD:core/string/ustring.cpp:2755-2767`). Semilla murmur `0x7F07C65` (`hashfuncs.h:108`).
- Descartado: `FRandomStream` (es congruente lineal, da otra planta; informe `experiencias.md`).

**D3. La ordenación se porta literal.** `sort_custom` usa el introsort de Godot (umbral 16, mediana de tres, inserción final; `GD:core/templates/sort_array.h:51, 202-245, 289-301`; `array.cpp:738-740`) y no es estable (`GD:doc/classes/Array.xml:788, 819`). El generador tiene comparadores con empates (`map_generator.gd:686, 992`; la ficha cita además 1179, 1472, 1499 y `office_generator.gd:3252`). Descartado: `std::sort` o `Algo::Sort` (otro orden en los empates) y añadir desempates en Godot (cambiaría la huella actual del hotel).

**D4. Diccionarios.** Godot conserva el orden de inserción (`GD:doc/classes/Dictionary.xml:7`). `TGdDict` hace lo mismo (lista más índice). `TMap` y `std::unordered_map` quedan prohibidos en `FourCore/Gen`. El manifiesto pasa a estructuras con nombre; los diccionarios de trabajo (`alive`, `cost`, `flow`, `on`) usan `TGdDict`.

**D5. Aritmética.** `float` de GDScript es `double`; los componentes de `Vector2`, `Rect2` y `Vector3` son `float` de 32 bits; `randf` devuelve 32 bits que se ensanchan. El port respeta cada ancho y el orden de las operaciones. `FourCore` se compila con coma flotante estricta (`UE:Source/Programs/UnrealBuildTool/Platform/Windows/VCToolChain.cs:1335-1345`: `/fp:precise` frente a `/fp:fast`). Las funciones trascendentes son pocas en el hotel (`cos` y `sin` en `map_generator.gd:437`, `atan2` en `:1827`) y más en oficinas (27 líneas con funciones de este tipo o de longitud en `office_generator.gd`, contadas con grep): son el único punto donde dos compiladores pueden diferir en el último bit (riesgo R1).

**D6. Huella compartida nueva, no la de JSON.** La huella actual depende de cómo Godot escribe los decimales (`String::num_scientific`, `GD:core/io/json.cpp:98-105`); reproducir eso no aporta nada. Se define un volcado canónico propio, idéntico en los dos motores: recorrido en profundidad, claves ordenadas por bytes, cada valor con su tipo (`i` entero decimal, `f` los 64 bits del real en hexadecimal, `s` texto, `b`, listas y diccionarios) y SHA-256 del resultado. Una herramienta nueva de Godot (`tools/dev/record_manifest_canon.gd`, junto a la actual) graba `golden/manifest_canon.json` con: los 255 casos del hotel, casos de oficinas, el `state` de cada flujo de azar al acabar cada etapa (planes, cada planta, decoración, números, puertas, desgaste, cada paso de `furnish`) y tres manifiestos completos en texto para comparar a mano. Las etapas dicen a un agente dónde se rompe la paridad sin depurar a ciegas. Descartado: portar el formateo de JSON de Godot.

**D7. Montaje: instancias de mallas estáticas, no malla dinámica ni PCG.**
- `UInstancedStaticMeshComponent` con malla Nanite crea un proxy de Nanite (`UE:Source/Runtime/Engine/Private/InstancedStaticMesh.cpp:2602-2604`); el HISM también (`UE:.../HierarchicalInstancedStaticMesh.cpp:2999-3001`), pero su proxy sin Nanite queda fuera de la escena de Lumen (`:806-807`, «Dynamic draw path without Nanite isn't supported by Lumen»). Regla: ISM siempre, HISM nunca.
- `UDynamicMeshComponent`: campo de distancia obsoleto (`UE:Source/Runtime/GeometryFramework/Public/Components/BaseDynamicMeshComponent.h:94`), trazado de rayos apagado por defecto (`.../BaseDynamicMeshSceneProxy.h:64`) y tarjetas de Lumen solo desde la caja envolvente (`:335`, `UpdateLumenCardsFromBounds`). Descartado para el casco.
- `ProceduralMeshComponent`: tiene geometría de trazado de rayos (`UE:Plugins/Runtime/ProceduralMeshComponent/.../ProceduralMeshComponent.cpp:157-178`) pero no Nanite ni campo de distancia (grep sin resultados en el componente). Descartado.
- Construir mallas estáticas en ejecución (`UStaticMesh::BuildFromMeshDescriptions`, `UE:Source/Runtime/Engine/Classes/Engine/StaticMesh.h:1838-1891`): fuera del editor obliga a `bFastBuild` y no construye Nanite (informe `ue58.md` §4.5). Descartado.
- PCG: genera en ejecución (`UE:Plugins/PCG/Source/PCG/Public/PCGComponent.h:79-81`), pero el trazado de la planta ya lo decide el generador con su semilla, y un grafo PCG es un asset binario con su propio azar. Descartado para trazado y vestimenta. Puede volver más adelante solo para relleno cosmético.
- El casco sigue siendo un cubo escalado (`SM_Box`): una caja es el mejor caso para las tarjetas de Lumen, la colisión sale gratis por instancia y el `FBuildPlan` se puede comparar con Godot. Si la escala no uniforme da mal resultado en Lumen (riesgo R3), el plan se trocea en paneles de 0,5, 1, 2 y 4 m sin tocar el generador.

**D8. Unidades y ejes en un solo sitio.** `FourCore` entero vive en el espacio de Godot. Solo `FFourSpace` convierte:
- Posición: Unreal = (x, z, y) × 100. Es la misma regla que aplica Interchange al importar glTF (multiplicador 100 en `UE:Plugins/Interchange/Runtime/Source/Import/Private/Gltf/InterchangeGltfPrivate.h:24`; el intercambio de ejes lo cita el informe `experiencias.md`), así que un modelo importado y una transformación calculada coinciden.
- Tamaño de caja: (sx, sz, sy) × 100.
- Giro sobre la vertical: guiñada de Unreal en grados = −(ángulo de Godot en grados). Giro general: la base de Godot conjugada con el intercambio de Y y Z.
- Consecuencia: el frente −Z de Godot queda en −Y de Unreal, no en +X. Para el mundo no importa; para personajes lo fija el dominio del jugador.
- Firmas: `FFourSpace::Pos(FGdVec3) -> FVector`, `Size(FGdVec3) -> FVector`, `Yaw(double) -> double`, `Xform(FGdTransform) -> FTransform` y sus inversas `ToGd(...)`. Ningún otro archivo multiplica por 100 ni intercambia ejes; una prueba de texto lo vigila (unidad U9).

**D9. Colisión.** La da la colisión simple de cada malla, por instancia del ISM. Cajas sólidas y no sólidas en componentes distintos. Canales propios según la tabla del apartado 3. `validate_physics` pasa a ser una prueba de Automation, no un paso de la carga.

**D10. Navegación: malla dinámica del motor.** `RuntimeGeneration=Dynamic` (el valor base es `Static`, `UE:Config/BaseEngine.ini:3043`; modos en `UE:Source/Runtime/NavigationSystem/Public/NavigationData.h:523-533`). Parámetros de partida iguales a Godot: radio 0,4 m (0,3 en oficinas), altura 1,8 m, celda 0,1 m (la celda por defecto del motor es 25 cm, `.../NavMesh/RecastNavMesh.h:559`; si el tiempo de generación se dispara, se sube). Descartado: búsqueda de caminos propia sobre el grafo de salas (las criaturas hoy siguen esquinas de una malla; cambiaría la sensación) y generar solo alrededor de invocadores (`NavigationSystem.h:391`; las criaturas planifican a toda la planta). Las rutas solo las calcula el anfitrión, así que no tienen que coincidir entre máquinas.

**D11. Luces y ocultación.** Una `AFourRoomLight` por luminaria del plan. `UFloorSubsystem` enciende solo las de la planta del ojo y las de salas a menos de N puertas, y fija `MaxDrawDistance` (`UE:Source/Runtime/Engine/Classes/Components/LightComponent.h:59-65`). No se portan las capas de render ni el VoxelGI. Las plantas que no son la del ojo se ocultan enteras (como `put_away`); dentro de la planta, la oclusión del motor (`r.HZBOcclusion`, `r.AllowOcclusionQueries`, `UE:Source/Runtime/Renderer/Private/SceneVisibility.cpp:125, 398`) y la de Nanite. Sombras y método (MegaLights o no) son del dominio de render; este dominio entrega la lista de luces y el servicio de encendido.

**D12. Misma planta en todos los jugadores.** El anfitrión replica (semilla, piso, supervivientes, versión del generador, SHA-256 canónico). Cada cliente genera en una tarea de fondo y compara su SHA con el del anfitrión antes de montar; si difiere, error visible y no entra. Todos ejecutan el mismo binario de Windows, así que hasta las funciones trascendentes coinciden. Puertas e interactivos se crean en local con nombre estable; su estado lo sincroniza el dominio de red.

**D13. Pruebas sin editor.** `tools/core_tests.ps1` compila `Source/FourCore/**/*.cpp` con `cl.exe` (MSVC 14.50) y ejecuta `four_core_tests.exe` contra `golden/manifest_canon.json`. Sin UBT ni editor. Descartado por ahora: objetivo de tipo Program o `LowLevelTestsRunner` (existe en `UE:Source/Programs/LowLevelTestsRunner`, pero no está comprobado que compile con un motor instalado) y Automation con `-nullrhi` (arranca el editor de 10 a 30 s y ocupa el único editor).

## 5. Prueba de concepto visual

**Entra:**
- `FourCore/Gd` completo con sus pruebas (U1): es pequeño y demuestra la vía de pruebas sin editor.
- Una herramienta de Godot que vuelca a JSON el manifiesto y el plan de montaje (cajas, piezas, luces, puertas) de una planta de oficinas con una semilla fija.
- `FFourSpace`, `AFloorBuilder` y `SM_Box`: el plan volcado se monta en Unreal con ISM, con Lumen y Nanite, colisión y malla de navegación dinámica.
- Medidas: tiempo de montaje, tiempo de la malla de navegación, memoria de vídeo, fotograma, y la vista de la escena de Lumen sobre muros de cubo escalado.
- Diez o veinte piezas del kit rehechas con modelos reales para dos salas (las que elija el dominio de arte).

**No entra:** portar los generadores, validadores, colocaciones, puertas que funcionan, interactivos, red, el hotel.

## 6. Unidades de trabajo del port completo

Orden de dependencia. «∥» marca las que pueden ir en paralelo entre sí (archivos disjuntos, sin editor). Las que usan el editor van de una en una.

| N.º | Unidad | Origen | Resultado | Prueba de aceptación |
|---|---|---|---|---|
| U0 | Huella canónica en Godot (única unidad que ejecuta Godot) | `tools/dev/record_manifest_golden.gd`, generadores | `tools/dev/record_manifest_canon.gd`, `golden/manifest_canon.json` con etapas y tres manifiestos completos; vectores de prueba de `hash()`, `randi`, `randf`, `randi_range`, `randf_range` y `sort_custom` con empates en `golden/gd_vectors.json` | Dos ejecuciones dan el mismo archivo; `manifest_golden_test` sigue en verde |
| U1 ∥ | `FourCore/Gd` | fuentes de Godot citadas en D2 a D4 | `FGdRandom`, `GdHash`, `GdSort`, `TGdDict`, vectores, `GdMath`, `FGdValue`; `tools/core_tests.ps1` | El ejecutable reproduce todos los vectores de `gd_vectors.json` |
| U2 ∥ | Paletas y definición de planta | `hotel_palette.gd`, `office_palette.gd`, `office_recipes.gd`, `floor_definition.gd` | Tablas `constexpr`, `FFloorDef`, `FManifest`, `ManifestCanon` | Volcado de las tablas igual al de Godot (U0 las vuelca); SHA de los tres manifiestos completos leídos de texto coincide |
| U3 | Generador del hotel | `map_generator.gd`, `wall_walker.gd` | `FMapGenerator`, `FWallWalker` | 255 de 255 SHA iguales; antes, etapa a etapa con los estados del azar |
| U4 ∥ (tras U3) | Colocaciones del hotel | `digit_`, `document_`, `hint_`, `tv_placement.gd`, `exit_route_signs.gd` | Mismas clases en `Gen/` | SHA de televisores de los 255 casos; volcado de dígitos, documentos y pistas igual en 50 semillas |
| U5 ∥ (tras U3) | Validador lógico del hotel | `map_validator.gd` salvo `validate_physics` | `FMapValidator` | Mismos veredictos que Godot en 300 semillas (U0 los vuelca) |
| U6 (tras U3) | Generador de oficinas | `office_generator.gd`, `office_layout.gd`, `conduit_*.gd` | `FOfficeGenerator` | SHA iguales en los casos de oficinas de la huella, con `REAL_PLAN` en el valor que fije el autor (pregunta 2) |
| U7 ∥ (tras U6) | Validador de oficinas | `office_validator.gd` | `FOfficeValidator` | Mismos motivos de fallo en 300 semillas |
| U8 ∥ (tras U2) | Planificador del casco | parte de colocación de `hotel_geometry.gd`, `office_geometry.gd`, `office_walls.gd` | `FBuildPlan`, `FHotelPlanner`, `FOfficePlanner` (muros, suelos, techos, huecos, puertas, luces) | Lista de cajas igual a la de Godot (volcado de `flush()`) en tres semillas; prueba pura «ninguna pareja de caras coplanares solapadas» en 50 semillas (ataca el z-fighting de raíz) |
| U9 ∥ | `FFourSpace` | D8 | `FourSpace.h` y pruebas | Ida y vuelta exacta; casos fijos de posición, tamaño y guiñada; grep: ningún `* 100` ni intercambio de ejes fuera del archivo |
| U10 | Kit base y proyecto (editor) | D7 | `SM_Box`, canales de colisión, mapa vacío, guion reproducible de importación | El guion se ejecuta dos veces desde cero y deja los mismos assets |
| U11 | `AFloorBuilder` (editor) | `flush()`, `build()` | Montaje por tramos con ISM, colisión, volúmenes de navegación | Semilla 81 del hotel y 7 de oficinas montadas; recuento de instancias igual al del plan; tiempo medido; Lumen ve los muros |
| U12 (tras U11) | Navegación | `floor_definition.gd:58-59, 310-321` | Malla dinámica, `FindPath`, `Closest` | Ruta de la entrada al refugio en las tres plantas en 20 semillas; tiempo de generación anotado |
| U13 ∥ (tras U11) | Puertas | `hotel_door.gd`, aristas | `AFourDoor` con los tiempos y canales de hoy | Barrido de cápsula por cada hueco con la puerta abierta y bloqueo con ella cerrada (sustituye a `validate_physics`) |
| U14 ∥ (tras U11) | Luces y visibilidad | `update_visibility`, `put_away`, `lamp_light` | `AFourRoomLight`, encendido por grafo en `UFloorSubsystem` | Solo la planta del ojo visible; número de luces activas bajo el tope que fije render |
| U15 (tras U8, U11) | Vestimenta y piezas | `room_dressing.gd`, `office_props.gd`, `office_models.gd`, `pieces/` | `FPlanPiece` por sala y tabla `FFourKit` | Cada id de pieza del plan tiene asset; ninguna sala sin vestir en 20 semillas |
| U16 (tras U12 a U15) | Carga de punta a punta y red | `hotel_main.gd:836-931` | Generación en tarea, comparación de SHA, `OnFloorReady` | Dos procesos con la misma semilla dan el mismo SHA; uno con el generador alterado es rechazado; tiempo total de carga medido |

## 7. Riesgos y cómo se detectan pronto

- **R1. Funciones trascendentes distintas entre el binario de Godot y MSVC.** Un bit de diferencia en `sin` o `cos` puede cambiar una planta. Se detecta en U3 con los estados por etapa. Salida si ocurre: U0 vuelca los valores de esas llamadas para localizarlo; si no hay arreglo exacto, paridad estructural (enteros iguales, reales con tolerancia) en las semillas afectadas y la huella de C++ pasa a ser la verdad.
- **R2. Empates en ordenaciones y tipos entero frente a real.** `2` y `2.0` son distintos en el volcado canónico. Se detecta en U1 (vectores con empates) y U3.
- **R3. Lumen con cubos de escala muy desigual** (un muro de 12 × 3 × 0,18 m sale de un cubo de 1 m). Sin comprobar. Se mide en la prueba de concepto; alternativa ya prevista en D7.
- **R4. Memoria de vídeo de 8 GB** con Nanite, Lumen y cientos de luces. Se mide en la prueba de concepto con la planta entera, no con una sala.
- **R5. Tiempo de la malla de navegación** con celda de 0,1 m en tres plantas. Se mide en U12 y en la prueba de concepto; se sube la celda si hace falta.
- **R6. Precaché de PSO**: el motor puede retrasar la aparición de objetos hasta compilar sus sombreadores (informe `ue58.md` §4.10). Al montar en ejecución puede verse la planta incompleta. Se mira en U11.
- **R7. El planificador mezcla hoy decisión y nodos** en 13 000 líneas de geometría. Separarlo en `FBuildPlan` es el trabajo más grande del dominio y además cambiará por las visuales. Se acota portando primero solo el casco (U8) y dejando la vestimenta para cuando arte decida las piezas.
- **R8. El generador de oficinas sigue cambiando** (`office_generator.gd` y `office_palette.gd` tienen cambios sin confirmar; la ficha contaba 3686 líneas y hoy son 3808). Portarlo antes de congelarlo obliga a portar dos veces.
- **R9. Compilar `FourCore` como módulo de Unreal y con `cl.exe` a la vez** puede dar resultados distintos si las opciones de coma flotante difieren. La prueba de U16 compara el SHA calculado dentro del juego con el del ejecutable de pruebas.

## 8. Preguntas para el autor

1. ¿Se congela el generador de Godot en una fecha para portarlo, o el piso 2 sigue cambiando en Godot mientras se porta? De esto depende si U6 se hace una vez o dos.
2. ¿Qué edificio de oficinas se porta: el actual o el «edificio real» (`REAL_PLAN`, hoy apagado en `office_palette.gd:17` según la ficha)?
3. ¿Importa que una semilla concreta dé en Unreal exactamente la misma planta que en Godot (por ejemplo, la 81 de las capturas y los bots), o basta con que las reglas y las cifras sean las mismas? Si no importa, R1 deja de ser un problema.
4. Las partidas guardadas de Godot (Continuar) ¿tienen que abrirse en la versión de Unreal?

## 9. Qué conviene instalar o bajar

Nada nuevo para este dominio. Se usa lo que ya hay:

| Qué | Para qué | Fuente y licencia |
|---|---|---|
| MSVC 14.50 de las Build Tools 2026 | `tools/core_tests.ps1` | Ya instalado; licencia de Microsoft |
| Blender 5.2 | Piezas del kit por guion | Ya instalado; GPL (la herramienta, no lo que produce) |
| Fuentes de Godot 4.7 | Referencia de D2 a D4; conviene guardar una copia de los nueve archivos citados en `.claude/specs/unreal/godot_src/` | https://github.com/godotengine/godot, MIT |
| SHA-256 para `FourCore` | Huella canónica | Se escribe (unas 80 líneas) o se toma una versión de dominio público; no añade dependencia |
| Plugins del motor | `NavigationSystem` (módulo del motor), `ModelContextProtocol`, `AllToolsets`, Python | Incluidos en 5.8.4 |
| Modelos y texturas | Kit y vestimenta | Poly Haven y ambientCG, CC0, sin cuenta (informe `experiencias.md`); Megascans solo si el autor lo trae con su cuenta |

## 10. Sin comprobar

- Nada se ha ejecutado ni compilado: ni un solo valor de `FGdRandom` o `GdHash` se ha contrastado con Godot. Lo hace U1 con los vectores de U0.
- Las fuentes de Godot se leyeron en la etiqueta `4.7-stable`; el juego usa `4.7.2.stable.steam.ed1daf0bf` (`.claude/godot-api/VERSION`). No se comprobó que esos archivos no cambien entre 4.7 y 4.7.2.
- Con qué compilador y biblioteca matemática está hecho el Godot de Steam, y si sus `sin`, `cos`, `atan2` coinciden con los de MSVC (R1).
- Que el Godot de Steam tenga `CLZ32` definido (si no, `randf` usa otra fórmula, `random_pcg.h:117-119`).
- La fórmula de guiñada de D8 y la conjugación de la base son deducción propia. El intercambio de ejes de Interchange se tomó del informe `experiencias.md` (`ConversionUtilities.h:16-20`), no se releyó; el multiplicador 100 sí.
- Que un ISM de malla sin Nanite entre bien en la escena de Lumen (solo se comprobó que el HISM sin Nanite no entra). Por eso el kit va con Nanite.
- Calidad de Lumen y de Nanite con cubos de escala no uniforme; coste de cientos de componentes ISM por planta; tiempos de montaje, de navegación y de generación en C++; memoria de vídeo.
- Que la navegación dinámica acepte volúmenes creados en ejecución sin pasos extra, y que las instancias de ISM entren en la malla (`AddInstances` tiene `bUpdateNavigation`, `UE:Source/Runtime/Engine/Classes/Components/InstancedStaticMeshComponent.h:275`; no se siguió más).
- Valor por defecto de `FPSemantics` en UBT (no se encontró `ModuleRules.cs` en la ruta esperada; solo se leyó `VCToolChain.cs`) y que `/fp:precise` de MSVC no fusione multiplicación y suma.
- Que un módulo sin ninguna dependencia de Unreal compile limpio con UBT (PCH, unity, avisos como errores).
- Que un objetivo Program o `LowLevelTestsRunner` compile con motor instalado.
- Cómo tratan las puertas la navegación en Godot (si la malla pasa por los huecos con la puerta cerrada) y cómo abren puertas las criaturas: no se leyó.
- Cuántas líneas de `hotel_geometry.gd` y `office_*.gd` son decisión pura y cuántas son nodos; la partición de U8 y U15 es una estimación.
- Las cifras y números de línea tomados de las fichas (`validate_physics`, `update_visibility`, `put_away`, `REAL_PLAN`, `hotel_main.gd:836-931, 1022`, capas de colisión) no se releyeron en el código. Sí se releyeron `map_generator.gd:140-208, 437, 686, 992, 1827` y `hotel_geometry.gd:503-504`.
- Si existe una huella o prueba de semillas fijas para oficinas equivalente a la del hotel (solo se vio la lista de `tests/office/`).
- Que los nombres estables basten para que la red de Unreal se refiera a actores creados en local; lo decide el dominio de red.
- PCG, Geometry Script y la creación de mallas por el MCP no se probaron; del catálogo solo se leyó `StaticMeshTools` (16 herramientas: Nanite, colisión convexa, LOD, material, importación; `.claude/specs/unreal/mcp_catalogo.md:639-657`) y `PCGToolset` (`:273-310`). No hay en el catálogo leído una herramienta que cree una malla estática desde cero: por eso el kit se hace en Blender y se importa.
