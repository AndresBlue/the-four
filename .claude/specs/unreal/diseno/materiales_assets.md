> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: materiales, sombreadores y cadena de assets (Unreal 5.8.4)

Escrito el 15 de noviembre de 2026. Nada se ejecutó ni se compiló. `UE/` es `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine/`. Las rutas `<P>/` son relativas al proyecto de Unreal, cuya ubicación fija otro documento. Las fichas citadas están en `.claude/specs/unreal/fichas/`.

## 1. Qué hay hoy en Godot

- **Sombreadores:** 30 `.gdshader` y 4 `.gdshaderinc` (23 espaciales, 6 de lienzo, 1 de niebla), más GLSL de cómputo dentro de `game/presentation/camcorder_effect.gd` y `motion_blur_effect.gd` (ficha `shaders.md` §1 y §5).
- **Superficies sin UV:** paredes, suelos y techos son cajas agrupadas en MultiMesh; el sombreador calcula la coordenada en metros desde la posición y la normal de mundo (`game/presentation/shaders/surface.gdshaderinc:70-75`, comprobado). El aspecto sale de ruido por código y, donde hay escaneo, de `image_maps.gdshaderinc`.
- **Materiales:** 105 `.tres` en `game/presentation/materials/` (71 ShaderMaterial sobre 9 sombreadores: finish 37, wood 11, wallpaper 7, tile 7, carpet 4, ceiling 2, ceiling_tile 1, painting 1, curtain 1; y 34 StandardMaterial3D). 46 llevan `metadata/scan` (ficha `materiales.md` §2).
- **Texturas:** 30 sets CC0 en `assets/textures/<set>/{albedo,normal,orm}.jpg` a 2048 px, normal en convención OpenGL y ORM con R oclusión, G rugosidad, B metal (`tools/textures/ingest_pbr.py:6-9`, vía ficha). 13 decals de 512 px, atlas de sangre 4x4 de 256 px, 14 cuadros.
- **Calidad:** el global `surface_detail` (2, 3, 4, 5 y 0) cambia octavas y ramas (`game/presentation/graphics_presets.gd:191-221`, comprobado).
- **Mallas:** 216 `.res` horneadas por `tools/props/build_*.gd` desde glTF o FBX de `source_assets/` (fuera de git), con giro, escala y despiece en `tools/props/build_catalogue.gd:23-36` y LOD de Godot en `:339` (comprobado), y con el encaje de 60 piezas de oficina en `tools/props/fit_models.json` (comprobado: 60 entradas).
- **Hecho por código en lugar de modelo:** 14 tipos de oficina sin modelo y los muebles de `game/world/hotel/prop_factory.gd` (ficha `assets.md` §3.4).
- **Valores en ejecución:** unos 197 `set_shader_parameter` (ficha `shaders.md` §0).

## 2. Cómo queda en Unreal

**Regla:** el texto manda. Un `.uasset` de material, instancia, textura o malla nunca se edita a mano: lo crea un guion a partir de datos en texto y se puede borrar y regenerar.

**En texto (git):**
- `<P>/Shaders/TheFour/*.ush`: el HLSL de lo que de verdad es propio (patrón de moqueta, motivo del papel, junta de baldosa, vidrio armado, sangre, tubo CRT). Los llaman nodos Custom, que admiten rutas de inclusión (`UE/Source/Runtime/Engine/Public/Materials/MaterialExpressionCustom.h:97`).
- `<P>/Tools/assets/materials.json`: una entrada por instancia (padre, escalares, vectores, texturas, interruptores estáticos). Sale de convertir los 105 `.tres`.
- `<P>/Tools/assets/meshes.json`: una entrada por malla (glb de origen, Nanite sí o no, colisión, material por ranura, metadatos `piece`, `casts`, `pivot`, `hands`, `parts`, `box`).
- `<P>/Tools/assets/build_materials.py`, `import_textures.py`, `import_meshes.py`, `build_decals.py`: guiones de Python del editor, lanzados con `UnrealEditor-Cmd.exe <uproject> -run=pythonscript -script=<archivo>` (informe `briefs/agentes.md`, vía índice).
- C++ en `<P>/Source/TheFour/Materials/`: `FTheFourModule` registra la carpeta de sombreadores; `UFourMaterialLibrary` (nombres de parámetros y de `MPC_World` como constantes); los parámetros en ejecución se fijan desde el código de cada sistema.

**Assets generados (binarios, regenerables):**
- Materiales maestros: `M_Surface`, `M_Prop`, `M_Decal`, `M_BloodDecal`, `M_Emissive`, `M_Glass`, `M_CRT`.
- Funciones: `MF_WorldFaceUV` (la regla de `face_uv`, una sola muestra por la cara dominante, con interruptor de espacio de objeto para hojas de puerta), `MF_ScanMaps` (albedo, normal, ORM con tinte, metros por repetición y sin repetición visible), `MF_Grime` (suciedad y desgaste por máscara de mundo), `MF_Pattern` (envoltorio del nodo Custom).
- `MPC_World`: reloj común y valores globales.
- Instancias `MI_<clave>` bajo `/Game/Materials/Hotel` y `/Game/Materials/Office`; texturas `T_<set>_{D,N,ORM}`; mallas `SM_<id>`.

**Parámetros de `M_Surface` (nombres cerrados, los usa `materials.json`):**
- Texturas: `Albedo`, `Normal`, `ORM`, `GrimeMask`.
- Escalares: `MapMetres` (de `map_metres`), `NormalStrength`, `RoughnessOffset` (de `map_roughness`), `MetallicScale`, `Grime`, `Wear`, `Wet`, `CoatAmount`, `CoatRoughness`, `EmissiveEnergy`.
- Vectores: `Tint` (de `map_tint`), `GrimeColor`, y hasta cuatro colores de patrón `PatternA` a `PatternD`.
- Interruptores estáticos: `UsePattern`, `UseCoat`, `ObjectSpace`, `UseEmissive`.
- `M_Prop` usa los mismos nombres de textura y `Tint`, `RoughnessOffset`, `Grime`, con las UV de la malla.
- `M_Decal`: `Albedo`, `Normal`, `Opacity`, `Roughness`, `Tint`; dominio Decal diferido con respuesta DBuffer de color, normal y rugosidad.

**API del editor que usan los guiones (comprobada en cabeceras):**
- `UMaterialEditingLibrary`: `CreateMaterialExpression` (:168), `ConnectMaterialProperty` (:232), `ConnectMaterialExpressions` (:242), `RecompileMaterial` (:267), `CreateMaterialExpressionInFunction` (:373), `SetMaterialInstanceParent` (:408), `SetMaterialInstanceTextureParameterValue` (:430), en `UE/Source/Editor/MaterialEditor/Public/MaterialEditingLibrary.h`.
- Interchange: `FImportAssetParameters` con canalización de sustitución (`UE/Source/Runtime/Interchange/Engine/Public/InterchangeManager.h:407-440`); `bBuildNanite = true` por defecto (`UE/Plugins/Interchange/Runtime/Source/Pipelines/Public/InterchangeGenericMeshPipeline.h:134`), `bCollision` (:101); instancias desde un padre con `ParentMaterial` (`InterchangeGenericMaterialPipeline.h:107-115`).
- Geometry Script, módulo de editor: `CreateNewStaticMeshAssetFromMesh` con `bEnableNanite` (`UE/Plugins/Runtime/GeometryScripting/Source/GeometryScriptingEditor/Public/GeometryScript/CreateNewAssetUtilityFunctions.h:59, 177`).
- MCP, para retoques y para inspeccionar, no como camino principal: `MaterialTools` (22), `MaterialInstanceTools` (13), `StaticMeshTools` (16, con `set_nanite_enabled`, `set_material`, `import_file`) y `TextureTools` (2) (`.claude/specs/unreal/mcp_catalogo.md:528-681`).

**Plugins:** Interchange (ya en el motor), GeometryScripting, PythonScriptPlugin. Ninguno externo.

**Ajustes de proyecto (`<P>/Config/DefaultEngine.ini`):** `r.Substrate=True` con `r.Substrate.ProjectGBufferFormat=0`, que es lo que escribe el asistente (`UE/Source/Editor/GameProjectGeneration/Private/GameProjectUtils.cpp:199-211`); `r.DBuffer=True` (`UE/Source/Runtime/Engine/Classes/Engine/RendererSettings.h:939-942`); texturas virtuales apagadas; `r.Streaming.PoolSize` fijado por nivel de calidad.

## 3. Correspondencia pieza a pieza

### 3.1 Sombreadores

| Godot | Destino en Unreal | Nota |
|---|---|---|
| `surface.gdshaderinc` | `MF_WorldFaceUV` + `MF_Grime` | Se porta `face_uv`; el ruido por octavas y `surface_detail` desaparecen |
| `image_maps.gdshaderinc` | `MF_ScanMaps` | Pasa de opción a camino único |
| `finish.gdshader` (37) | `M_Surface` o `M_Prop`, instancias | El acabado (metal cepillado, tela, lino) lo da el escaneo |
| `wood.gdshader`, `wood.gdshaderinc` (11) | `M_Surface`, instancias con escaneo de madera | `object_space` pasa a interruptor estático |
| `wood_lacquer.gdshader` | Ya no hace falta | La laca es un parámetro de capa transparente de `M_Surface` |
| `wallpaper.gdshader` (7) | `M_Surface` + `MF_Pattern` (`Wallpaper.ush`) | Motivo y ancho de rollo 0,53 m se conservan si el autor lo confirma (pregunta 1) |
| `carpet.gdshader` (4) | `M_Surface` + `MF_Pattern` (`Carpet.ush`) | Medallones sobre escaneo de moqueta |
| `tile.gdshader` (7) | `M_Surface` + `MF_Pattern` (`Tile.ush`) | Junta, damero y mojado (rugosidad baja por máscara) |
| `ceiling.gdshader`, `ceiling_tile.gdshader` | `M_Surface`, instancias | Manchas y anillos de agua pasan a decals |
| `painting.gdshader` | Ya no hace falta | Los cuadros usan las 14 láminas reales |
| `curtain.gdshader` | `M_Prop` con desplazamiento de vértice (World Position Offset) | Sin Nanite en la cortina |
| `venetian_blind.gdshader` | Ya no hace falta | Lamas reales generadas con Geometry Script |
| `wired_glass.gdshader` | `M_Glass` + `WiredGlass.ush` | Translúcido: sin Nanite (informe `briefs/ue58.md`, vía índice) |
| `exit_panel.gdshader` | `M_Emissive`, instancia con la máscara de `make_exit_sign.py` | |
| `ceiling_halo.gdshader` | Ya no hace falta | El halo lo da la luz rebotada de la lente emisiva |
| `tv_screen.gdshader` | `M_CRT` (`CRT.ush`), sin iluminar | La imagen llega por render a textura |
| `blood.gdshader` | `M_BloodDecal` sobre malla instanciada | Los 4 canales por instancia pasan a datos por instancia (`UE/Source/Runtime/Engine/Classes/Components/InstancedStaticMeshComponent.h:181`) |
| `blood_pool.gdshader` | `M_BloodDecal`, variante charco | `reach[16]` pasa a 4 parámetros vectoriales |
| `blood_worn.gdshader` | Función de material en el material del personaje | Diseño en el dominio de personajes |
| `echo_field`, `echo_points`, `echo_self` | Posprocesado y Niagara | Diseño en el dominio de The Locust |
| `lurker_darkness.gdshader` | Material translúcido volumétrico o Niagara | Diseño en el dominio de The Lurker |
| `ceiling_dust.gdshader` | Niagara (partículas iluminadas) | Dominio de render |
| `ceiling_dust_veil.gdshader` (fog) | Material de dominio Volumen en niebla volumétrica | Dominio de render |
| `analog.gdshader`, `lens.gdshader`, `lens_blood.gdshaderinc` | Posprocesado (material tras la curva tonal o extensión de vista) | Dominio de render |
| GLSL de `camcorder_effect.gd`, `motion_blur_effect.gd` | Ajustes de serie del volumen de posprocesado y extensión de vista | Dominio de render |
| `signal_wash`, `tape_noise`, `typewriter_ink` | Materiales de dominio Interfaz | Dominio de interfaz |
| `tools/dev/lens_blood_look.gdshader` | No se porta | Herramienta |

### 3.2 Materiales, texturas y herramientas

| Godot | Unreal |
|---|---|
| 71 ShaderMaterial `.tres` | `MI_<clave>` de `M_Surface`, descritos en `materials.json` |
| 34 StandardMaterial3D y 192 ORMMaterial3D de `assets/props` | `MI_<id>` de `M_Prop`, creados por `import_meshes.py` |
| `metadata/scan` | Parámetros de textura de la instancia |
| `INSTANCE_CUSTOM` con la sala | Ya no hace falta en superficies (la suciedad de borde va en `MF_Grime` y decals) |
| `set_shader_parameter` global (reloj) | `MPC_World` |
| `set_shader_parameter` por pieza (energía de lámpara, apertura) | Datos de primitiva (Custom Primitive Data) desde C++, sin instancia dinámica |
| `surface_detail`, `small_maps`, imágenes `lite` | Grupos de textura y niveles de calidad del motor |
| `Decal` de Godot | `ADecalActor` con `MI_Decal_<nombre>` (DBuffer) |
| `tools/textures/ingest_pbr.py` | Se conserva tal cual; `import_textures.py` lee su salida |
| `tools/textures/ingest_dressing.py` | Se conserva; `SIZE` sube de 512 a 2048 para decals |
| `bake_blood.py`, `make_exit_sign.py`, `bake_hotel_note.py`, `bake_do_not_disturb.py` | Se conservan; su PNG se importa |
| `tools/textures/bake_lite_maps.gd` | Se abandona |
| `tools/props/fetch_models.py`, `ingest_models.py`, `register_sketchfab.py`, `fit_model.py`, `fit_models.json` | Se conservan: siguen siendo la entrada |
| `tools/props/build_*.gd` | Se conservan como etapa que deja la pieza en el marco del juego; se les añade la exportación a glb |
| `tools/props/decimate.py`, `add_mesh_lods.gd` | Ya no hacen falta para lo que lleve Nanite |
| `docs/ASSETS.md`, `docs/asset_hashes.json` | Siguen siendo el registro de licencias y de integridad |

## 4. Decisiones

1. **Las superficies pasan a escaneo fotográfico; el ruido por código no se porta.** El autor quiere foto de época y hoy le molesta lo hecho a mano. Ya hay 30 sets CC0 y 46 materiales los usan. Solo se porta a HLSL lo que es identidad del lugar (moqueta, papel, baldosa). Descartado: traducir los 9 sombreadores línea a línea (mucho trabajo para repetir el aspecto que se quiere dejar atrás).
2. **Coordenada de mundo propia, no la función del motor.** `WorldAlignedTexture` existe (`UE/Content/Functions/Engine_MaterialFunctions01/Texturing/`), pero mezcla tres muestras; `MF_WorldFaceUV` toma una por la cara dominante, como hoy, y deja las cajas sin UV. Descartado: dar UV a cada caja en el generador.
3. **Un maestro por familia, pocas permutaciones.** `M_Surface` con cuatro interruptores estáticos (patrón, capa transparente, espacio de objeto, emisión). Todo lo demás son instancias. Descartado: un maestro por sombreador de Godot (nueve grafos que mantener por guion).
4. **Substrate sí, formato 0 (mezclable), con las entradas clásicas del material.** Es lo que nace en un proyecto 5.8 y la capa transparente cubre la laca y el suelo mojado. Descartado: formato 1 adaptativo (más memoria por píxel según `RendererSettings.h:1262-1271`, con 8 GB) y apagar Substrate (aparta el proyecto del camino por defecto del motor).
5. **Texturas a 2048 px, ORM empaquetado, sin texturas virtuales.** Los escaneos cubren alrededor de un metro (`game/presentation/materials/office/wet_tile.tres:16`: 1,2 m), así que 2048 px ya da unos 17 px por centímetro. 30 sets con tres mapas comprimidos caben en unos cientos de MB (estimación). El reparto de memoria lo hace el streaming de mips con `r.Streaming.PoolSize` (400 a 1000 MB según nivel en `UE/Config/BaseScalability.ini:749-782`) y `r.Streaming.LimitPoolSizeToVRAM=1`. Descartado: texturas virtuales (no hay UDIM ni terreno, y añaden una pasada y un fondo de memoria propio) y 4K (no se ve a 17 px/cm).
6. **La normal se importa invirtiendo el canal verde.** Los sets están en convención OpenGL y Unreal usa la contraria.
7. **Las mallas entran como glb exportado desde Godot de cada `.res`, no desde la fuente.** Los `.res` ya llevan giro, escala, despiece y encaje, que son medidas de gameplay; rehacer `YAW`, `SCALE`, `PARTS` y `fit_models.json` en otro sitio es duplicar reglas. Un guion de Godot sin interfaz exporta cada `.res` a `<P>/SourceArt/meshes/<id>.glb` y vuelca los metadatos a `meshes.json`. Descartado: importar la fuente original y reaplicar las transformaciones en Blender o en Python (más fiel en triángulos, pero cada pieza habría que volver a validarla); queda como mejora pieza a pieza donde una captura lo pida.
8. **Interchange por Python, no el MCP, para la importación en lote.** El guion corre sin editor abierto, se repite igual y no gasta turnos de agente. El MCP devuelve fallos como éxito (`briefs/agentes.md`, vía índice). Descartado: `StaticMeshTools.import_file` pieza a pieza.
9. **Nanite en todo lo opaco y rígido; fuera lo translúcido, la cortina y lo que se deforma.** Nanite no admite translúcidos (`briefs/ue58.md`, vía índice).
10. **Manchas, sangre y rótulos son decals, no geometría coplanar.** Quita el z-fighting de raíz.
11. **El suelo mojado es rugosidad, no un truco.** Máscara de charcos en `Tile.ush` y decals de charco que bajan la rugosidad; el reflejo lo pone Lumen.
12. **No hay preset «Muy bajo» con imágenes horneadas.** Las 21 imágenes `lite` y `bake_lite_maps.gd` se abandonan; la escala la dan los niveles de calidad del motor.

## 5. Prueba de concepto visual

**Entra** (un pasillo y un despacho de oficinas):
- `M_Surface` con `MF_WorldFaceUV`, `MF_ScanMaps` y `MF_Grime`; seis instancias: pintura de pared, moqueta, placa de techo, vinilo mojado, puerta de roble, metal pintado.
- `Tile.ush` como único patrón portado.
- `import_textures.py` con seis sets y `import_meshes.py` con unas 15 piezas de oficina exportadas desde Godot.
- `M_Decal` con cuatro decals reingestados a 2048 px y una lente emisiva de fluorescente.
- Medidas: memoria de vídeo, tiempo de la cadena completa desde cero, y una captura junto a la referencia de 1987.

**No entra:** sangre, eco, oscuridad de The Lurker, polvo, cinta y lente, interfaz, hotel, CRT, Geometry Script, modelos nuevos.

## 6. Unidades de trabajo del port completo

Las marcadas (P) pueden ir en paralelo entre sí mientras solo escriben texto. La ejecución de cualquier guion del editor va en serie: un solo editor a la vez.

| # | Unidad | Origen | Resultado | Aceptación |
|---|---|---|---|---|
| 1 | Carpeta de sombreadores y ajustes | — | Módulo que registra `/TheFour` y `DefaultEngine.ini` | Un nodo Custom que incluye un `.ush` del proyecto compila |
| 2 | `build_materials.py`: maestros y funciones | `surface.gdshaderinc`, `image_maps.gdshaderinc` | 7 maestros, 4 funciones, `MPC_World` | Se borra `/Game/Materials` y el guion lo rehace sin errores en el registro |
| 3 (P) | Conversor `.tres` a `materials.json` | 105 `.tres` | `materials.json` | 105 entradas; cada parámetro de Godot tiene destino o figura como abandonado |
| 4 (P) | `import_textures.py` | `assets/textures/`, `assets/decals/`, `assets/paintings/` | `T_*` con compresión y sRGB correctos | Una esfera con cada set se ve igual que la ficha de su fuente; normal sin relieve invertido |
| 5 | Instancias desde `materials.json` | 2, 3, 4 | `MI_*` | Hoja de contacto: una captura con todas las instancias sobre cajas de 1 m |
| 6 (P) | `Tile.ush`, `Carpet.ush`, `Wallpaper.ush` | `tile`, `carpet`, `wallpaper` `.gdshader` | Patrones con las mismas cifras (0,3 m, 0,62 m, 0,53 m) | Captura junto a la de Godot con una regla de 1 m en escena |
| 7 (P) | Exportador de Godot a glb y `meshes.json` | `assets/props/**/*.res`, `build_*.gd` | 216 glb y sus metadatos | 216 archivos; caja envolvente de cada glb igual a la del `.res` con 1 mm de margen |
| 8 | `import_meshes.py` (Interchange, Nanite, colisión, ranuras) | 7 | `SM_*` y `MI_*` de `M_Prop` | Hoja de contacto de las 216; ninguna ranura con el material por defecto; medidas en centímetros igual a `meshes.json` |
| 9 (P) | `M_Glass`, `WiredGlass.ush`, `M_Emissive`, `M_CRT` | `wired_glass`, `exit_panel`, `tv_screen` | Instancias | Captura de vidrio armado, rótulo de salida y televisor |
| 10 (P) | Decals: reingesta y `build_decals.py` | `ingest_dressing.py`, 13 decals | `MI_Decal_*` | Un decal sobre moqueta y otro sobre baldosa sin parpadeo al mover la cámara |
| 11 | Sangre: `Blood.ush`, `M_BloodDecal` | `blood`, `blood_pool` `.gdshader`, `bake_blood.py` | Manchas y charco con datos por instancia | El charco crece con la misma curva (raíz cúbica, 30 s) medida en tres instantes |
| 12 (P) | Piezas con Geometry Script | `venetian_blind`, lista de abajo | `SM_*` generadas | Regenerables desde cero; lamas visibles de perfil |
| 13 | Modelos reales que sustituyen a los hechos por código | Lista de abajo | Entradas nuevas en `meshes.json` y en `docs/ASSETS.md` | Cada tipo deja de usar sustituto; licencia registrada |
| 14 | Parámetros en ejecución | Los 197 `set_shader_parameter` | Tabla nombre de Godot a `MPC_World`, dato de primitiva o instancia dinámica | Ningún nombre de la tabla queda sin destino |

**Sustituir por modelos reales (unidad 13):** los 14 tipos sin modelo (`cable`, `crt_black`, `folders`, `keyboard`, `microwave`, `mug`, `paper_scatter`, `paper_stack`, `pen_cup`, `phone_off`, `register`, `tray_wire`, `waiting_chair`, `work_light`; `game/world/office/office_models.gd:245-281`, vía ficha), los muebles de cajas de `game/world/hotel/prop_factory.gd` (camas, mesas, armarios, mostradores) y las faltas de `source_assets/oficinas/RESUMEN.md` (fotocopiadora, archivo móvil, estación de tubo neumático).

**Generar con Geometry Script (unidad 12), en el editor y guardado como Static Mesh con Nanite:** persianas de lamas, rejilla en T del falso techo, rodapiés y marcos, bandejas de cables, compuerta y tramos de conducto. La envolvente (paredes, suelos, techos) es del dominio de geometría; aquí solo se le exige que no necesite UV.

## 7. Riesgos y detección temprana

| Riesgo | Cómo se ve pronto |
|---|---|
| Los decals DBuffer con Substrate no se comportan como se espera. El motor trae una pasada propia apagada por defecto y de solo lectura (`r.Substrate.DBufferPass`, `UE/Source/Runtime/RenderCore/Private/RenderUtils.cpp:2135-2138, 2498-2508`), y el informe `ue58.md` dice que el formato 0 no admite DBuffer, lo que no cuadra con ese código | Unidad 10 dentro de la prueba de concepto |
| Los guiones de materiales no compilan sombreadores en modo sin ventana | Unidad 2 lanzada con `-run=pythonscript` el primer día; si falla, se lanza con el editor abierto y `-ExecutePythonScript=` |
| La exportación glb de Godot degrada texturas (recompresión) o pierde canales del ORM | Unidad 7 con tres piezas antes de las 216; comparar tamaño y aspecto de la textura |
| Las mallas ya diezmadas (5 000 y 20 000 triángulos) se ven pobres con Nanite | Hoja de contacto de la unidad 8; las que fallen entran por la fuente original |
| La proyección de mundo marca costuras en esquinas y en piezas giradas | Captura de una esquina y de una puerta abierta en la prueba de concepto |
| 8 GB de memoria de vídeo con Lumen, Nanite y 216 mallas con sus texturas | Medida en la prueba de concepto y otra vez al cerrar la unidad 8 |
| Datos por instancia en un decal de malla (sangre) | Unidad 11 empieza con una prueba mínima; alternativa: quad opaco con máscara y desplazamiento de profundidad |
| Demasiadas permutaciones de `M_Surface` alargan la compilación | Contar permutaciones tras la unidad 5 |
| Licencias que impiden vender (televisor, dormitorio, puerta y armario sin ficha; `docs/ASSETS.md:72`) | Unidad 13 los trata como pendientes de sustituir |

## 8. Preguntas para el autor

1. ¿El dibujo de la moqueta del hotel y el motivo del papel pintado son identidad del juego y se conservan, o pueden pasar a ser los del escaneo fotográfico?
2. ¿Traes tú assets de Fab (Megascans) con tu cuenta de Epic? Sin eso, las fuentes son solo las que no piden cuenta.
3. ¿Descargas tú con tu sesión los 82 modelos de Sketchfab que quedaron en `needs_login`, o se buscan sustitutos sin cuenta?
4. ¿Se sustituyen ya el televisor, el dormitorio, la puerta y el armario, que no tienen licencia comprobada?

## 9. Qué conviene instalar o bajar

| Qué | Fuente | Licencia | Cuenta |
|---|---|---|---|
| Nada nuevo de software | Interchange, Geometry Script y Python vienen en el motor; Blender 5.2 ya está | — | No |
| Materiales y modelos de Poly Haven | polyhaven.com (su API ya la usa `tools/props/fetch_models.py`) | CC0 | No |
| Materiales y decals de ambientCG | ambientcg.com (ya en `ingest_pbr.py` e `ingest_dressing.py`) | CC0 | No |
| Materiales de cgbookcase | cgbookcase.com (ya hay un set) | CC0 | No |
| Megascans | Fab | Licencia estándar de Fab, comercial (`briefs/experiencias.md`, vía índice) | Sí, la del autor |
| Modelos de época de Sketchfab | sketchfab.com | Solo CC0 y CC BY | Sí, para descargar |
| Láminas y papeles | Art Institute of Chicago (ya en uso) | CC0 según el registro | No |
| Dos máscaras de suciedad para `MF_Grime` | ambientCG o Poly Haven | CC0 | No |

## 10. Sin comprobar

- Nada se ejecutó: ni los guiones de Python del editor, ni la importación con Interchange, ni la exportación glb desde Godot.
- Que una carpeta de sombreadores del proyecto se registre desde un módulo de juego con motor instalado y que el nodo Custom la incluya (solo se comprobó que el nodo tiene `IncludeFilePaths`).
- Que con Substrate activo las entradas clásicas del material y la capa transparente se conviertan solas y den el aspecto de laca y de mojado.
- El comportamiento real de los decals DBuffer con Substrate en formato 0 (ver riesgo 1), y los decals de malla con datos por instancia.
- Los nombres exactos en Python de Interchange (`unreal.InterchangeManager`, clases de canalización) y si Interchange invierte el verde de la normal en glTF.
- Que `bBuildNanite` y `bEnableNanite` basten sin ajustes de malla de respaldo para el trazado de rayos.
- El tamaño real en memoria de las texturas y el valor adecuado de `r.Streaming.PoolSize` en la RTX 4060 Ti; la línea 793 de `BaseScalability.ini` (3000) no se identificó con su nivel.
- Qué exporta Godot de un `ORMMaterial3D` a glTF y con qué calidad de textura.
- Las licencias de Poly Haven, ambientCG, cgbookcase, Fab y Sketchfab no se releyeron en la web en este encargo: vienen de `docs/ASSETS.md` y de `briefs/experiencias.md`. La gratuidad de Megascans desde el 5 de noviembre de 2026 viene de ese informe.
- Los `.gdshader` no se releyeron enteros: la tabla 3.1 se apoya en la ficha `shaders.md`, salvo `face_uv` y los presets.
- El recuento de 71 y 34 materiales, los 192 ORMMaterial3D y los 14 tipos sin modelo vienen de las fichas.
- El destino de eco, oscuridad, polvo, cinta, lente e interfaz es orientativo: lo fijan sus dominios.
