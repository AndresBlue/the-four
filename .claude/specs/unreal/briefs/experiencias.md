# Experiencias de portar de Godot a Unreal, el aspecto buscado y los assets

Informe para los analistas del port de The Four a Unreal Engine 5.8.4. Fecha: 14 de noviembre de 2026. No se ejecutó Godot ni Unreal, no se compiló ni se descargó ningún asset; solo se leyó código, documentación y páginas web.

## 0. Cómo leer este informe

Cada hecho lleva una marca:

- **[C] Comprobado**: leído en el código local (repo o motor instalado), en el código fuente de Godot 4.7.2 en GitHub, o en la página oficial del titular (EULA de Epic, anuncio de Quixel, ficha y noticias de Steam del propio estudio).
- **[L] Leído**: lo dice un tercero (prensa, blog, foro, Wikipedia). Sirve de pista, no de base para una decisión.
- **[D] Deducido**: conclusión mía a partir de hechos [C]. Hay que confirmarla con una prueba.

Rutas del motor: relativas a `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine/`. Rutas de Godot: `modules/gltf/...` y `core/...` en la etiqueta `4.7.2-stable` de https://github.com/godotengine/godot (la versión local es 4.7.2.stable, `.claude/godot-api/VERSION`). Las cifras del repo se contaron con grep sobre `game/**/*.gd` el 14 de noviembre de 2026 (177 archivos, 72 816 líneas).

## 1. Lo esencial

1. **No hay relatos publicados de un port completo de Godot a Unreal** con detalle técnico. Cuatro búsquedas distintas solo devolvieron la dirección contraria (Unreal o Unity hacia Godot), opiniones de foro y una guía de equivalencias de 2023. El port se diseña con el código de los dos motores delante, no con experiencia ajena. [C: resultado de las búsquedas; sección 2]
2. **El glTF de Godot lleva la forma, no el aspecto.** Exporta mallas (también las generadas por código), una copia de nodo por cada instancia de MultiMesh, luces puntuales y colisiones en una extensión que Unreal ignora. Todo material con sombreador propio sale vacío (solo el nombre). El juego usa `ShaderMaterial` en 73 líneas y tiene 23 sombreadores espaciales. [C]
3. **Interchange 5.8 rechaza el archivo entero si lleva una extensión obligatoria que no conoce.** Godot marca `KHR_node_visibility` como obligatoria por defecto en cuanto hay un nodo oculto, e Interchange no la conoce. Hay que exportar con `visibility_mode` 2 (excluir) o 1 (opcional). [C]
4. **Las semillas no se reproducen gratis.** El juego siembra con `hash([...])` de Variant y genera con PCG32; Unreal trae un generador congruente lineal distinto. Si se quiere la misma planta para la misma semilla hay que portar PCG32, las conversiones a real de Godot y el hash de Variant. Es una decisión del director. [C los dos generadores; D la consecuencia]
5. **El movimiento del jugador no encaja con los valores por defecto de `CharacterMovementComponent`** (aceleración 2048, fricción 8, escalón de 45 cm, pasos de simulación variables). El juego asigna la velocidad a mano y llama a `move_and_slide()` a 60 Hz fijos. [C]
6. **Todos los juegos del listón son Unreal Engine 5 con Lumen**; ninguno declara luz horneada. Subliminal corre hoy sobre Unreal 5.8.4, la misma versión instalada aquí, con trazado de rayos por hardware como opción. [C: fichas y noticias de Steam]
7. **La RTX 4060 Ti de 8 GB está por encima de lo que esos juegos recomiendan** (RTX 3060 en Subliminal y Silent Breath, RTX 3070 en Fractured Mind). [C: requisitos en Steam]
8. **Megascans vuelve a ser gratis en Fab desde el 5 de noviembre de 2026**, bajo la licencia estándar de Fab (uso comercial, cualquier motor, sin atribución, sin redistribuir sueltos). Exige cuenta de Epic. [C: anuncio de Quixel]
9. **El EULA de Unreal prohíbe combinar el motor con contenido CC BY-SA** (lo nombra junto a GPL). La regla del proyecto de no usar SA pasa de prudencia a obligación contractual, y el personaje `realistic_female` (CC BY-SA, `docs/ASSETS.md:33`) no puede entrar en el port. [C]
10. **Además del 5 %**: avisar a Epic con un formulario antes de vender, informar cada trimestre con ingresos y poner dos avisos fijos en los créditos. El primer millón de dólares por producto está exento. [C]

## 2. Relatos y guías de ports de Godot a Unreal

### Lo que se encontró

| Fuente | Qué es | Qué aporta | Marca |
|---|---|---|---|
| https://duroxxigar.github.io/unreal/Godot-to-Unreal/ | Guía de equivalencias de Godot a Unreal (blog personal, actualizada el 6 de abril de 2023; Godot 3.5 y 4.0, Unreal 4 y 5.2) | Las equivalencias de la sección 3 y cinco avisos: no hay correspondencia uno a uno; `ChildActorComponent` da problemas; Unreal no garantiza el orden de inicialización entre actores; no usar Hot Reload (Live Coding solo para cuerpos de función; un cambio de cabecera pide reiniciar el editor); limpiar redirectores tras mover assets | [L] |
| https://fire-studi0.itch.io/experiment/devlog/832904/changing-the-engine | Entrada de devlog: pasó de Godot a Unreal 4 buscando realismo; Unreal 5 no le corría | Mismo motivo que este port; ningún detalle técnico | [L] |
| https://forum.godotengine.org/t/advice-on-moving-a-project-forward/40029 | Hilo de foro | Opiniones: Unreal cuesta más de aprender e itera más lento; el arte fotorrealista pide comprar assets o un equipo grande | [L] |
| https://dev.to/cosmictrinitygames/why-we-switched-from-godot-to-unity-5-hard-lessons-from-an-indie-studio-1ke4 | De Godot a Unity | Motivos: luz 3D y física. No es Unreal | [L] |

### Lo que no se encontró

- Ningún postmortem de un juego 3D portado de GDScript a C++ de Unreal: qué costó más, cuánto tardó, qué se tradujo mal.
- Ninguna herramienta que convierta escenas o guiones de Godot a Unreal. Las que aparecen van de Unreal a Godot (por ejemplo https://github.com/vortechU/UnrealToGodot) y solo mueven assets.
- Ningún hilo sobre importar en Unreal un glTF exportado por Godot. Lo más cercano es una corrección en un repositorio de herramientas de Blender (https://github.com/TMHSDigital/Blender-Developer-Tools/pull/417): si el glTF ya viene en centímetros, Interchange lo vuelve a multiplicar por 100, y un glTF con Z arriba llega girado 90 grados. [L]

**Consecuencia [D]:** las secciones 3 a 5 salen de leer los dos motores. Lo que diga un blog sobre este port es, como mucho, una pista.

## 3. De GDScript a C++: dónde se traduce mal

| Tema | En Godot (este juego) | En Unreal 5.8 | Riesgo y qué hacer |
|---|---|---|---|
| **Variant y Dictionary** | 1 804 líneas con `Dictionary` o `Variant` en 126 archivos. El `Dictionary` de Godot 4 conserva el orden de inserción | `TMap` no promete orden de iteración; no hay tipo dinámico general en el C++ de juego | Cada diccionario pasa a ser un `USTRUCT` con campos, o un `TMap` más un `TArray` de claves si el orden importa. Recorrer un `TMap` donde el orden decide un resultado (generación, elección de sala) cambia el juego sin dar error. [C las cifras; D el riesgo] |
| **Señales** | 66 `signal` declaradas y 84 `.emit(` en 27 archivos | Delegados: dinámicos multidifusión para lo visible desde Blueprint, multidifusión simple en C++ puro. La guía citada los da como equivalente [L] | Los delegados no traen conexión diferida ni de un solo uso; hay que escribirlas. Enlazar en `BeginPlay`, no en el constructor |
| **`await`** | 45 líneas en 7 archivos | El C++ de Unreal no trae corrutinas de juego; hay temporizadores y acciones latentes | Cada `await` se reescribe como máquina de estados o temporizador. Son pocos: se pueden listar uno a uno |
| **Árbol de nodos** | 10 escenas `.tscn` en `game/`; casi todo se monta por código | Actores con componentes. `MeshInstance3D` equivale a `UStaticMeshComponent`; una escena reutilizable, a una clase de actor; un autoload, a un `UGameInstanceSubsystem` [L: guía citada] | Favorece el port: con pocas escenas, el montaje por código pasa a C++ sin assets binarios intermedios, que es lo que piden los agentes. [D] |
| **Orden de `_process`** | 24 archivos con `_process` y 13 con `_physics_process`. Godot recorre el árbol en orden, con prioridades | Grupos de tick `TG_PrePhysics`, `TG_DuringPhysics`, `TG_PostPhysics`, `TG_PostUpdateWork` (`Source/Runtime/Engine/Classes/Engine/EngineBaseTypes.h:86-101`). Dentro de un grupo el orden no está garantizado salvo que se declare un prerrequisito | Donde el juego dependa de quién se actualiza antes (jugador, criatura, cámara, director) hay que declararlo. Lo más fiel: un solo tick central que llame a los sistemas en el orden de Godot. [C los grupos; D la receta] |
| **Paso fijo** | `_physics_process` a 60 Hz (el proyecto no cambia `physics_ticks_per_second`; `game/player/hotel_player.gd:431` lo lee). La cámara interpola con `Engine.get_physics_interpolation_fraction()` (`hotel_player.gd:619`) | El tick de Unreal es de paso variable. Existen `bSubstepping` y `bTickPhysicsAsync` con `AsyncFixedTimeStepSize` (`Source/Runtime/Engine/Classes/PhysicsEngine/PhysicsSettings.h:325-345`), pero gobiernan la física de Chaos, no el tick de los actores | Para conservar las cifras hace falta un acumulador propio de 1/60 s que ejecute la simulación y deje la interpolación a la cámara, como hace hoy el juego. [D] |
| **`CharacterBody3D`** | 3 clases (`game/player/hotel_player.gd`, `game/enemies/creature.gd`, `game/net/remote_player.gd`) y 9 llamadas a `move_and_slide`. La velocidad se asigna a mano; salto de 5,4 m/s (`hotel_player.gd:315`); gravedad 20 m/s² (`project.godot`, `3d/default_gravity=20.0`) | `UCharacterMovementComponent`: `MaxAcceleration 2048`, `GroundFriction 8`, `BrakingDecelerationWalking 2048`, `MaxStepHeight 45`, `JumpZVelocity 420`, `MaxWalkSpeed 600`, `AirControl 0.05`, `MaxSimulationTimeStep 0.05`, `MaxSimulationIterations 8` (`Source/Runtime/Engine/Private/Components/CharacterMovementComponent.cpp:677-736`). Gravedad por defecto −980 cm/s² (`Config/BaseEngine.ini:3408`) | Los valores por defecto dan otra sensación: inercia al arrancar y al frenar, sube solo escalones de 45 cm y parte el paso en trozos de hasta 50 ms. Dos caminos: (a) el componente con aceleración y frenado muy altos, escalón a 0 y gravedad a 2 000; (b) un modo de movimiento propio que reproduzca `move_and_slide`. Se decide midiendo en la prueba de concepto. [C los valores; D los caminos] |
| **Azar** | `RandomNumberGenerator` en 152 líneas de 41 archivos. Es PCG32 (`core/math/random_pcg.h` y `thirdparty/misc/pcg.h`). `randf()` construye el real con `ldexp` y un recuento de ceros (`random_pcg.h:109-115`). Las semillas salen de `hash([semilla, "texto"])` (`game/director/pacing_director.gd:217`, `game/enemies/lurker/lurker.gd:200`, `game/app/code_lock.gd:187`) y de `hash(Vector3)` (`game/enemies/lurker/ceiling_dust.gd:68`) | `FRandomStream` es congruente lineal: `Seed = Seed * 196314165 + 907633515` (`Source/Runtime/Core/Public/Math/RandomStream.h:364`) | Con `FRandomStream` la misma semilla da otra planta. Para que coincida hay que portar tres cosas: PCG32, las conversiones `randf`, `randi_range` y `randf_range` de Godot, y el hash de Variant para Array, String, int y Vector3. También el ruido `FastNoiseLite` (`game/enemies/locust/hotel_locust.gd:483`, `game/enemies/lurker/lurker_visual.gd:196`). Si no se exige la coincidencia, las pruebas de manifiesto dorado no se trasladan tal cual. [C; D la consecuencia] |
| **Precisión** | En GDScript `float` es de 64 bits; los componentes de `Vector3` son de 32 bits en la compilación estándar | `FVector` es de doble precisión (`Source/Runtime/Core/Public/Math/MathFwd.h:47`); `float` de C++ es de 32 bits; `FVector3f` es el vector de 32 bits (`MathFwd.h:73`) | Escalares como `double` y vectores como `FVector` dan igual o más precisión que Godot. El peligro es el contrario: usar `float` de C++ para tiempos y acumuladores que en GDScript eran de 64 bits. Las comparaciones exactas de las pruebas pueden diferir en el último dígito. [C los tipos; D el consejo] |
| **Red** | 55 `@rpc` en 2 archivos y 70 llamadas `.rpc(` en 6; no usa `MultiplayerSynchronizer` ni `MultiplayerSpawner` | Replicación de propiedades y RPC por actor | Al ser RPC explícitas concentradas en dos archivos, el protocolo se puede listar entero. Lo trata otro informe |
| **Memoria** | Cuenta de referencias | Recolector de basura: un puntero a `UObject` sin `UPROPERTY()` puede quedar colgando (https://unrealcommunity.wiki/garbage-collection-36d1da) [L] | Regla de estilo para los agentes: todo puntero miembro a `UObject` lleva `UPROPERTY()` o es `TObjectPtr` |

## 4. Unidades y ejes

| | Godot | Unreal | Fuente |
|---|---|---|---|
| Unidad | metro | centímetro | Interchange multiplica por 100: `Plugins/Interchange/Runtime/Source/Import/Private/Gltf/InterchangeGltfPrivate.h:24` [C] |
| Arriba | +Y | +Z | `Plugins/Interchange/Runtime/Source/Parsers/GLTFCore/Private/GLTF/ConversionUtilities.h:16-20` [C] |
| Mano | derecha | izquierda | mismo archivo [C] |
| Frente de una cámara | −Z | +X | convención de cada motor |

- **Lo que hace Interchange con un glTF [C]:** la posición `(x, y, z)` pasa a `(x, z, y) × 100`; el cuaternión `(qx, qy, qz, qw)` pasa a `(−qx, −qz, −qy, qw)` (`ConversionUtilities.h:16-44`). Con esa regla, lo que en Godot mira a −Z acaba mirando a −Y en Unreal, no a +X.
- **Para el código propio del port [D]:** una sola función de conversión, usada en todas partes. Una que deja el frente de Godot en el frente de Unreal es `X = −z × 100`, `Y = x × 100`, `Z = y × 100`; su determinante es −1, así que cambia de mano como debe, y el giro en Y de Godot pasa a guiñada con el signo contrario. Hay que elegir entre esta regla y la de Interchange y no mezclarlas: si la geometría entra por glTF y la lógica por código, la misma regla en los dos lados.
- **Campo de visión [C + D]:** el juego usa 78 grados verticales (`game/presentation/camcorder_look.gd:20`). En Unreal `FieldOfView` es horizontal (`Source/Runtime/Engine/Classes/Camera/CameraComponent.h:38-44`) y el jugador local mantiene el vertical por defecto (`Config/BaseEngine.ini:2899-2900`, `AspectRatio_MaintainYFOV`). 78 verticales a 16:9 son unos 110,4 horizontales (cálculo propio: 2·atan(tan 39° × 16/9)).
- **Cifras que cambian de escala [C]:** gravedad 20 m/s² pasa a 2 000 cm/s²; salto 5,4 m/s a 540 cm/s; altura de ojos 1,64 m a 164 cm (`hotel_player.gd:349`).
- **Luz [C]:** Godot exporta la energía de cada luz tal cual, sin unidades (`modules/gltf/extensions/gltf_light.cpp:133-158`), e Interchange la lee como candelas (`Plugins/Interchange/Runtime/Source/Import/Private/Gltf/InterchangeGltfTranslator.cpp:805-850`). El número no significa lo mismo: las intensidades se recalibran en Unreal.

## 5. glTF: qué sale de Godot 4.7.2 y qué entra en Unreal 5.8

### 5.1 Lo que exporta `GLTFDocument` en tiempo de ejecución

`GLTFDocument.append_from_scene()` y `write_to_filesystem()` (`.claude/godot-api/modules/gltf/doc_classes/GLTFDocument.xml:28-35 y 85-91`) son de uso en ejecución: la documentación de la clase remite a la guía de carga y guardado de archivos en ejecución, y el módulo registra sus extensiones fuera del bloque de editor (`modules/gltf/register_types.cpp:106-141`). El repo ya la usa desde guiones, para leer modelos (`tools/props/build_catalogue.gd:219-220`). Fuera del editor exporta también los nodos creados por código sin dueño: el descarte de nodos sin dueño solo ocurre dentro del editor (`modules/gltf/gltf_document.cpp:4210-4215`). [C]

| Elemento | Qué sale | Fuente (`gltf_document.cpp` salvo que se diga) | Marca |
|---|---|---|---|
| `MeshInstance3D` con cualquier `Mesh` (`ArrayMesh` generada, cajas, cilindros) | La malla completa, con los materiales activos de la instancia. En el juego: 368 líneas con `ArrayMesh`, `SurfaceTool` o `ImmediateMesh` en 25 archivos | líneas 4102-4131 y 4232-4234 | [C] |
| `MultiMeshInstance3D` | Un nodo hijo por instancia, todos con la misma malla. No usa `EXT_mesh_gpu_instancing`. No lleva el material sobrescrito de la instancia ni los colores o datos por instancia. En el juego: 30 líneas | líneas 4405-4452 | [C] |
| Material `BaseMaterial3D` | Color, textura de color, oclusión-rugosidad-metal empaquetada, normal, emisión con su fuerza, modo alfa, doble cara, sin iluminar, transformación de UV1 | líneas 2672-2932 | [C] |
| `ShaderMaterial` | Solo el nombre: ni texturas ni parámetros | líneas 2672-2676 | [C] |
| Luces `OmniLight3D`, `SpotLight3D`, `DirectionalLight3D` | Tipo, color, energía sin unidades, alcance y cono. No salen sombras, proyector, energía de niebla volumétrica ni curva de atenuación | `extensions/gltf_light.cpp:133-158` | [C] |
| Cámaras, `AnimationPlayer`, CSG, `GridMap`, esqueletos | Sí | líneas 4239-4266 | [C] |
| Colisiones (`CollisionShape3D`, cuerpos y áreas) | Sí, en las extensiones `OMI_physics_shape` y `OMI_physics_body`, no obligatorias. La extensión está registrada también fuera del editor | `extensions/physics/gltf_document_extension_physics.cpp:531-572 y 705-730`; `register_types.cpp:136-139` | [C] |
| Nodos ocultos | Salen con `KHR_node_visibility`, que queda como **obligatoria** con el modo por defecto (0) | líneas 396-405; valores del modo en `GLTFDocument.xml:106 y 120-125` | [C] |
| Transformación de UV | Si un material la usa, `KHR_texture_transform` queda como obligatoria | líneas 213-215 | [C] |
| Decals, partículas, sondas de reflexión, `VoxelGI`, niebla, entorno, audio | No salen: no tienen rama en el conversor de nodos | líneas 4232-4266 | [C] |

### 5.2 Lo que importa Interchange de Unreal 5.8

| Punto | Qué hace | Fuente (`Plugins/Interchange/Runtime/Source/...`) | Marca |
|---|---|---|---|
| Tipos | Materiales, mallas y animaciones; en importación de escena, también luces y cámaras | `Import/Private/Gltf/InterchangeGltfTranslator.cpp:473 y 795-850` | [C] |
| Extensiones que conoce | Luces puntuales e IES, variantes de material, sin iluminar, IOR, barniz, transmisión, brillo de tela, especular, especular-brillo, fuerza de emisión, iridiscencia, volumen, los dos empaquetados de Microsoft, transformación de textura, cuantización de malla y Draco | `InterchangeGltfTranslator.cpp:57-82` | [C] |
| Extensiones que no conoce | `KHR_node_visibility`, `EXT_mesh_gpu_instancing`, `OMI_physics_shape`, `OMI_physics_body`, `KHR_animation_pointer` | misma lista | [C] |
| Extensión obligatoria desconocida | La importación falla entera con un error | `InterchangeGltfTranslator.cpp:567-614` | [C] |
| Colisión | El traductor no lee colisiones del glTF: no hay ninguna mención en el traductor ni en el lector de mallas | grep sobre `InterchangeGltfTranslator.cpp` e `InterchangeGltfMesh.cpp` | [C] |
| Unidades y ejes | Por 100 y cambio de ejes (sección 4) | `InterchangeGltfPrivate.h:24`; `ConversionUtilities.h:16-44` | [C] |
| Luces | Puntual y foco en candelas, con el alcance por 100 y los conos en grados | `InterchangeGltfTranslator.cpp:805-850` | [C] |
| Malla repetida | Cada nodo apunta a la misma malla: un solo asset de malla y un componente por nodo | `InterchangeGltfTranslator.cpp:325` | [C] |
| Sin diálogos | `UInterchangeManager::ImportScene` y `ScriptedImportSceneAsync` son invocables desde guiones, con `bIsAutomated` | `Source/Runtime/Interchange/Engine/Public/InterchangeManager.h:421 y 752-765` | [C las firmas; D que corra sin ventana] |

### 5.3 Qué se sigue de esto [D]

- **El glTF de Godot sirve para la prueba de concepto y como referencia, no como camino del port.** Las plantas se generan por código en cada partida: el generador hay que escribirlo en C++. Un volcado a glTF de una planta de la semilla 81 sí da en una tarde la geometría exacta dentro de Unreal para juzgar luz y materiales, y da después una referencia de posiciones contra la que comparar el generador portado.
- **Para ese volcado:** `visibility_mode` a 2, y contar con que llegan en blanco todas las superficies con sombreador propio (moqueta, papel pintado, madera, azulejo, techo, cortinas, persianas, vidrio armado). Los materiales se rehacen en Unreal de todos modos.
- **Una planta con miles de instancias llega como miles de componentes sueltos.** Para la prueba vale; en el port, las repeticiones van a componentes de malla instanciada creados por código.
- **Los props de terceros no deben pasar por Godot.** Los `.res` horneados por `tools/props/build_catalogue.gd` son de Godot. Lo limpio es importar en Unreal los originales de `source_assets/` (glTF de Poly Haven, FBX y glTF de Sketchfab). Esa carpeta está fuera de git (`docs/ASSETS.md:118`): conviene comprobar que está completa antes de empezar; los registros y `docs/asset_hashes.json` permiten verificarla.
- **Las colisiones se generan en Unreal** (colisión simple por malla o cajas creadas por el generador). Las del glTF no llegan.

## 6. El aspecto: con qué lo consiguen los juegos del listón

### 6.1 Los juegos

| Juego | Estudio y estado | Motor y técnica declarada | Requisitos | Fuente y marca |
|---|---|---|---|---|
| **Subliminal** | Accidental Studios; a la venta desde el 31 de marzo de 2026; 9,99 USD; 20 GB | Unreal Engine 5 con Lumen y Nanite, según su ficha. Desde la v1.0.9 (octubre de 2026) corre sobre **Unreal 5.8.4**, con el motor modificado por el estudio. Ofrece trazado de rayos por hardware como opción, un modo de iluminación en el impacto, un preajuste Bajo con la variante ligera de Lumen, reconstrucción de rayos de DLSS y HDR. Niveles hechos a mano | Mínimo GTX 1060; recomendado RTX 3060 | Ficha de Steam 2300840 y sus noticias del 5 y el 19 de octubre de 2026 (https://store.steampowered.com/app/2300840/Subliminal/) [C] |
| **Lost Fragment** | Nihil Inane Studio (Osaka); solo un avance de agosto de 2023; sin ficha en Steam ni fecha | Unreal Engine 5. El estudio dice que todo está hecho a mano y sin fotogrametría | No publicados | https://www.relyonhorror.com/latest-news/lost-fragment-unreal-engine-5/ y https://automaton-media.com/en/news/20230831-21275/ [L] |
| **Fractured Mind** | ACid (un autor); demo desde febrero de 2024; la ficha de Steam dice 2026 y gratuito | Unreal Engine 5, estilo de cámara corporal, inspirado en P.T. No publica cómo ilumina | Mínimo GTX 1080 Ti; recomendado RTX 3070 o RX 6800; 5 GB | Ficha de Steam 2885330 [C]; https://acidulatul.itch.io/fractured-mind-demo/devlog [C: etiquetas del autor] |
| **Dreamcore** | Montraluz; a la venta desde enero de 2025; 17,99 USD | Unreal Engine 5.6 desde octubre de 2025. Pide una tarjeta con trazado de rayos porque su sistema de luz depende de él; sin ella hay zonas en negro. Mapas de sombra virtuales. Filtro VHS que se puede apagar | Mínimo declarado GTX 760, con la nota anterior | Ficha de Steam 2453060 y noticias del 30 de octubre de 2025 [C] |
| **Silent Breath** | Exodiac Studios; versión completa el 20 de agosto de 2026; 9,99 USD | Unreal Engine 5 con Lumen (ajustes rehechos por rendimiento), DLSS y FSR; efecto VHS y ojo de pez rediseñados en la versión completa | Recomendado RTX 3060 de 12 GB | Ficha de Steam 2796180 y noticias [C] |
| **Paranormal Tales** | Digital Cybercherries; sin fecha | Unreal Engine 5; cámaras corporales, teléfonos y videocámaras VHS | Mínimo GTX 1050 Ti; recomendado GTX 1070 | Ficha de Steam 2193600 [C] |
| **Bodycam** | Reissad; acceso anticipado desde junio de 2024 | Unreal Engine 5; Lumen e imágenes HDRI de luz real; Megascans y assets de la tienda de Epic; ojo de pez desde el volumen de posprocesado, aberración cromática, ruido, y el borde de la cámara como una imagen delante de la lente que reacciona al movimiento. Ajuste de grano desde septiembre de 2026 | Mínimo RTX 2070 de 8 GB | Entrevista en 80.lv del 28 de septiembre de 2023 (https://80.lv/articles/developing-a-game-with-realistic-graphics-in-unreal-engine/) [L: palabra del estudio vía prensa]; ficha 2406770 y noticias [C] |
| **Unrecord** | DRAMA; sin fecha | Unreal Engine 5; escenas montadas a mano con Megascans, assets de la tienda y piezas propias | No publicados | https://en.wikipedia.org/wiki/Unrecord [L] |

Aviso: hay más de un juego llamado Fractured Mind. Aquí se tomó el de cámara corporal en Unreal 5, que es el que encaja con los otros dos; conviene que el autor lo confirme.

### 6.2 Lo que tienen en común

- **Todos usan Unreal Engine 5 y luz global dinámica (Lumen).** Ninguno declara luz horneada. Tres de ellos (Subliminal, Dreamcore, Bodycam) mencionan trazado de rayos. [C]
- **En 5.8 la variante ligera de Lumen existe en el motor instalado [C + D]:** la calidad media de iluminación global usa un volumen de irradiancia en vez del muestreo por sondas de pantalla (`Config/BaseScalability.ini:326-333`, `r.Lumen.FinalGatherMethod=0`; `Source/Runtime/Renderer/Private/Lumen/Lumen.cpp:55-56 y 199-211`). Que eso sea lo que la prensa y Subliminal llaman Lumen Lite es deducción mía: la cadena exacta no aparece en esos archivos.
- **MegaLights está en el motor [C]:** ajuste de proyecto `r.MegaLights.EnableForProject` (`Source/Runtime/Engine/Classes/Engine/RendererSettings.h:651-653`) y por volumen (`Source/Runtime/Engine/Classes/Engine/Scene.h:1881-1887`). Su propia descripción dice que necesita trazado de rayos por hardware y Shader Model 6. Importa para el piso 2, con muchas pantallas de fluorescente con sombra.
- **Luz horneada no encaja con plantas generadas [D]:** la geometría se decide al empezar la partida. Lumen es el camino natural, igual que en los juegos del listón.
- **El realismo se apoya en la cámara tanto como en la escena [L]:** Bodycam degrada la imagen a propósito y añade ojo de pez, aberración y ruido; Silent Breath y Dreamcore llevan filtro VHS. Es la misma dirección que ya fijó `docs/REALISM.md:5` (una escena fotorrealista grabada por una videocámara real).
- **Densidad de assets [L]:** los dos estudios que lo cuentan (Reissad y DRAMA) llenan las escenas con Megascans y assets comprados, y hacen a mano solo lo que no existe. Lost Fragment dice lo contrario (todo a mano, sin fotogrametría), pero solo ha enseñado un pasillo.

### 6.3 La cinta y la lente en Unreal

**Lo que el motor trae de serie [C]** (`Source/Runtime/Engine/Classes/Engine/Scene.h`): aberración cromática (`SceneFringeIntensity`, línea 1621), viñeteado (2143), grano de película con textura propia (2181 y 2220), nitidez (2171), temperatura de blanco (1507), tabla de color LUT (2300), cantidad de curva tonal (1594), exposición local (2038-2047), desenfoque de movimiento (2402) y destellos de lente (2119). Hay además un plugin de distorsión de lente en `Plugins/Compositing/LensDistortion` (existe; no se leyó).

**Dónde se engancha un efecto propio [C]:**

| Punto | Para qué | Fuente |
|---|---|---|
| Material de posprocesado en `BL_SceneColorAfterDOF` | Efectos en HDR, tras la profundidad de campo (que vaya antes del reescalado temporal está sin comprobar, sección 9) | `Source/Runtime/Engine/Classes/Engine/BlendableInterface.h:29-32` |
| `BL_SSRInput` | Recibe la salida del reescalado temporal | misma cabecera, líneas 46-49 |
| `BL_SceneColorBeforeBloom` | Tras el desenfoque de movimiento, antes del resplandor | líneas 54-57; orden en `Source/Runtime/Renderer/Private/PostProcess/PostProcessing.cpp:507-514` |
| `BL_ReplacingTonemapper` | Sustituir la curva tonal entera | líneas 63-66 |
| `BL_SceneColorAfterTonemapping` | Efectos sobre la imagen final (ruido de cinta, líneas, OSD grabado) | líneas 72-75 |
| Extensión de vista (`FSceneViewExtensionBase`) | Varias pasadas, texturas intermedias e historia del fotograma anterior, en C++ | `Source/Runtime/Engine/Public/SceneViewExtension.h:122-138, 210 y 222` |

- **Un material de posprocesado es una sola pasada sobre el fotograma actual [L]:** no guarda resultados intermedios ni ve su salida anterior. El halo en varias pasadas, el submuestreo de croma bien hecho y el entrelazado con historia piden una extensión de vista (https://www.strayspark.studio/blog/ue5-post-process-materials-vs-scene-view-extensions, 3 de junio de 2026).
- **Receta publicada de la pila VHS, en orden [L]:** distorsión de barril suave, aberración que crece hacia las esquinas, halo de las altas luces, submuestreo de croma (el color corrido en horizontal con la luminancia nítida), entrelazado, grano más fuerte en las sombras y viñeteado (https://www.strayspark.studio/blog/vhs-found-footage-look-unreal-engine-5, 3 de junio de 2026). Según ese texto, lo que hace que se lea como cinta son el croma y el entrelazado.
- **El juego ya resolvió este reparto en Godot [C]:** lo estable por píxel va en HDR antes del antialias temporal y lo que el antialias emborronaría va después (`docs/REALISM.md`, prueba de riesgo 1). El mismo reparto se traslada a `BL_SceneColorAfterDOF` y `BL_SceneColorAfterTonemapping`. Los sombreadores de lienzo de la cámara (`analog` y `lens` en `game/presentation/shaders/`, `tape_noise` y `signal_wash` en `game/ui/shaders/`) se reescriben como materiales de posprocesado; cambia el lenguaje, no las cuentas. [D]
- **Hay paquetes de pago en Fab con filtros VHS hechos** (por ejemplo https://www.fab.com/listings/f6825e2e-ef62-432b-a459-623059347084, para 5.4 o posterior) [L]. No hacen falta: la cámara del juego ya está diseñada y medida.

### 6.4 Las cinco quejas del autor frente a lo que cambia con Unreal [D]

| Queja | Qué cambia | Qué no arregla el motor |
|---|---|---|
| El tono | La gradación de Unreal va en el volumen de posprocesado (temperatura, LUT, curva). El juego usa hoy la curva AgX (`game/presentation/hotel_environment.tres:10`, modo 4); la de Unreal es otra | Hay que volver a ajustar el naranja apagado mirando las referencias (`docs/referencias/`); los números de Godot no se trasladan |
| Reflejos de suelo mojado | Lumen da reflejos coherentes con la rugosidad en vez de reflejos de pantalla y sondas | Un suelo con rugosidad demasiado baja seguirá pareciendo mojado: es calibración de material |
| Z-fighting | Ninguno por sí solo | Dos caras coplanarias parpadean en cualquier motor. Se arregla en el generador: sin caras coincidentes, y lo pegado a una pared como decal o con separación |
| Ambientes vacíos | Megascans gratis y Nanite permiten más piezas y más densas | Hay que colocarlas: es trabajo de catálogo y de reglas de colocación |
| Piezas a mano que parecen 3D | Las piezas en código de `game/world/office/pieces/` se sustituyen por modelos reales | Elegir cada modelo de época y tapar marcas sigue siendo trabajo |

## 7. Assets: fuentes, licencia y cuenta

### 7.1 Fuentes

| Fuente | Qué hay | Licencia | Cuenta | Precio en 2026 | Encaja con las reglas |
|---|---|---|---|---|---|
| **Poly Haven** | Modelos, materiales y HDRI escaneados | CC0; sin crédito obligatorio (https://polyhaven.com/license) [C] | No. El guion del repo usa su API pública sin credenciales (`tools/props/fetch_models.py:20-24`) [C] | Gratis | Sí. Ya es la fuente principal del juego |
| **ambientCG** | Materiales PBR | CC0; sin crédito obligatorio (https://docs.ambientcg.com/license/) [C] | No (`docs/OFICINAS.md:853`) [C: documento del repo] | Gratis | Sí |
| **Fab: Megascans (Quixel)** | Más de 23 000 superficies, objetos y decals escaneados [L] | Licencia estándar de Fab: uso comercial, cualquier motor, modificar, compartir con el equipo; no redistribuir sueltos; sin crédito obligatorio (https://www.fab.com/eula) [C] | **Sí, cuenta de Epic**, también para lo gratuito [L: https://digitalproduction.com/2026/11/13/quixel-megascans-free-again/]. El plugin Fab del editor es un navegador con inicio de sesión (`Plugins/Fab/Source/Fab/Private/FabBrowserApi.h:120-144`) [C] | **Gratis desde el 5 de noviembre de 2026**; quien compró desde enero de 2025 recibe reembolso en saldo (https://quixel.com/news/update-megascans-are-going-free-again) [C] | Sí en licencia. La cuenta tiene que ser la del autor, con su sesión: los agentes no la abren |
| **Fab: otros vendedores** | Paquetes de entornos y props; hay de oficina retro y de los años ochenta | La misma licencia estándar. Dos tramos de precio, Personal y Profesional, con los mismos derechos; el corte son 100 000 USD de ingresos en 12 meses [L: foro de Epic] | Sí | De pago. Un ejemplo: megapaquete de 119 props retro a 79,99 USD (https://www.fab.com/listings/8cf27f59-8fe7-4ffa-931a-c75436fd9a17) [L] | Licencia sí; es gasto y pide la cuenta del autor |
| **Fab: contenido gratuito CC BY** | Modelos que venían de Sketchfab | CC BY: crédito obligatorio [L] | Sí | Gratis | Sí, con crédito |
| **Sketchfab** | Modelos de la comunidad | Cada ficha la suya: CC0, CC BY, y también SA, NC y ND, que no valen | Sí para descargar (`docs/ASSETS.md:138`: los descarga el autor) [C: documento del repo] | Gratis lo descargable | Solo CC0 y CC BY, con la sesión del autor |
| **Mixamo (Adobe)** | Animaciones y esqueleto automático | Uso en juegos permitido; no redistribuir los archivos sueltos (`docs/ASSETS.md:37`) [C: documento del repo] | Sí | Gratis | Sí; ya se usa |

- **Sobre Sketchfab [L]:** los modelos gratuitos siguen descargables allí; los gratuitos con licencia CC0, SA, NC o ND no pudieron pasar a Fab (https://sketchfab.com/blogs/community/fab-publishing-portal-open-for-sketchfab-migration/). Wikipedia dice que KitBash compró Sketchfab el 12 de agosto de 2026 (https://en.wikipedia.org/wiki/Sketchfab); es una sola fuente.
- **Megascans y la época [D]:** Megascans es sobre todo superficies, escombro, vegetación y objetos escaneados sin fecha. Sirve para suelos, paredes, techos, suciedad, decals y desorden, que es lo que hoy delata el render. El mobiliario de 1987 (terminales, máquinas de escribir, archivadores) seguirá viniendo de Poly Haven, Sketchfab y, si el autor lo decide, de paquetes de pago.

### 7.2 Lo que ya hay en el repo y condiciona el port [C]

- **No puede entrar:** `realistic_female`, CC BY-SA (`docs/ASSETS.md:33`), por la cláusula del EULA de la sección 8; y The Locust, CC BY-NC-ND (`docs/ASSETS.md:110-111`), que ya impedía vender.
- **Sin licencia comprobada:** el televisor, el dormitorio de la escena de entrada, la puerta de madera y el armario (`docs/ASSETS.md:72`).
- **Los CC BY piden crédito en pantalla.** La lista vive en `game/ui/hotel_ui.gd` (`CREDITS`) y en `docs/ASSETS.md`; se traslada tal cual a los créditos del port.
- **Los originales están fuera de git** (`source_assets/`, `models/`). El port los necesita para importarlos en Unreal.

## 8. Licencia de Unreal: qué obliga además del 5 %

Todo leído el 14 de noviembre de 2026 en https://www.unrealengine.com/en-US/eula/unreal [C].

| Obligación | Detalle |
|---|---|
| **Regalía** | 5 % de los ingresos brutos mundiales del producto. Exentos el primer 1 000 000 USD de por vida por producto y cualquier trimestre con menos de 10 000 USD |
| **Sobre el bruto** | Se calcula sobre lo que paga el comprador, antes de la comisión de la tienda. Cuentan también DLC, anticipos de editor, micromecenazgo ligado al acceso y servicios de suscripción |
| **Lo vendido en Epic Games Store** | No genera regalía. Si el juego sale en la tienda de Epic a la vez que en las demás y con paridad de contenido, funciones y promoción, la tasa baja al 3,5 % en todas las tiendas |
| **Aviso previo** | Antes de distribuir un producto que genere ingresos hay que enviar a Epic el formulario de lanzamiento (unrealengine.com/release) |
| **Informe y pago** | Dentro de los 45 días siguientes a cada trimestre natural con ingresos sujetos a regalía, por producto. Lo impagado devenga interés |
| **Libros y auditoría** | Llevar registros suficientes; Epic puede auditarlos con aviso |
| **Créditos** | Si el juego tiene créditos, dos avisos fijos con el año en curso: uno dice que el producto usa Unreal Engine y que Unreal es marca de Epic; el otro es el aviso de derechos, que dice «Unreal® Engine, Copyright 1998 – xxxx, Epic Games, Inc. All rights reserved.» (EULA de Unreal, apartado de avisos y atribución). El texto exacto del primero se copia de ese apartado |
| **Marcas y logotipos** | El EULA no concede ningún otro uso de las marcas ni de los logotipos de Epic. Usar el logotipo de Unreal (pantalla de arranque, tráiler, tienda) va por las directrices de marca de Epic, aparte |
| **EULA del juego** | El acuerdo con el usuario final tiene que excluir expresamente garantías y responsabilidades respecto del motor |
| **Licencias incompatibles** | No se puede combinar el motor con código o contenido bajo GPL, LGPL (salvo enlace dinámico) ni Creative Commons Atribución-CompartirIgual |
| **Herramientas del motor** | El juego distribuido no puede incluir el editor ni módulos de las carpetas Developer o Editor |
| **Código del motor** | Solo se comparte con otros licenciatarios; en público, fragmentos de hasta 30 líneas. El repositorio del juego no debe llevar código fuente del motor |
| **Asientos** | Un juego vendido al público no paga suscripción por puesto |
| **Assets hechos con el motor** | Los modelos y animaciones propios creados con el motor, salvo el contenido inicial de Epic, se pueden usar en productos de otros motores |

**Assets de Fab fuera de Unreal:** la licencia estándar de Fab no limita el uso a Unreal [C: resumen oficial en https://www.fab.com/eula, que avisa de que el resumen no es el texto vinculante]. Hay contenido marcado solo para Unreal en acuerdos anteriores (Megascans obtenido con un plan de Unreal, MetaHuman, muestras de Epic) [L: foros y PDF antiguos del EULA]. Para este port no estorba, porque el juego correrá sobre Unreal; sí importa no llevar esos assets de vuelta a la versión de Godot sin mirar la ficha de cada uno.

## 9. Sin comprobar

- **Nada se ejecutó.** La exportación a glTF de una planta real y su importación con Interchange están leídas en el código, no probadas: tamaño del archivo, tiempo de importación, cuántos componentes crea y si `ImmediateMesh` exporta bien.
- **Que la importación con `bIsAutomated` corra sin ventana** desde un guion de Python o desde el MCP del editor.
- **El orden exacto de `BL_SceneColorAfterDOF` respecto del reescalado temporal** se apoya en los comentarios de la cabecera; no se leyó la parte del renderizador anterior al desenfoque de movimiento.
- **Que Lumen Lite sea `r.Lumen.FinalGatherMethod=0`:** deducido del comentario del archivo de escalabilidad.
- **Rendimiento en la RTX 4060 Ti de 8 GB** con Lumen, trazado de rayos por hardware, MegaLights y Nanite a la vez: no hay medida. Los requisitos de otros juegos son una pista, no una prueba.
- **Cómo ilumina cada juego del listón por dentro** (ajustes de Lumen, exposición, cuántas luces con sombra): ninguno lo publica. De Lost Fragment y Unrecord solo hay prensa.
- **Cuál es el Fractured Mind que el autor tiene en mente.**
- **El texto vinculante completo del EULA de Fab** (la página carga por JavaScript; se leyó su resumen oficial), el corte de 100 000 USD entre tramos y qué contenido sigue marcado solo para Unreal.
- **El acuerdo de contenido de Epic** (https://www.unrealengine.com/en-US/eula/content) y **las directrices de marca**: devolvieron 403 o una página vacía.
- **Si hay una vía sin interfaz para traer assets de Fab al proyecto.** Solo se vio el navegador del plugin, con inicio de sesión.
- **La compra de Sketchfab por KitBash** y el estado de su API de descarga en 2026: una sola fuente secundaria.
- **Que Sketchfab y Fab exijan cuenta para descargar** está tomado de los documentos del repo y de prensa, no de sus condiciones.
- **Las fórmulas propias** de la sección 4 (regla de ejes para el código del port, signo de la guiñada, 110,4 grados): cálculo mío, a confirmar con una escena de prueba.
- **Precios de paquetes de Fab:** cambian; el citado es de un resultado de búsqueda.
- **El hash de Variant de Godot** (qué algoritmo usa para Array, String y Vector3) no se leyó; solo se comprobó que el juego depende de él.
