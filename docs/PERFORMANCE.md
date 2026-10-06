# Rendimiento gráfico — auditoría de septiembre de 2026

Auditoría técnica de GPU, CPU, VRAM, llamadas de dibujo, sombras, geometría y texturas del hotel (Forward+), con cambios medidos uno a uno. El aspecto se mantiene; la única excepción deliberada es un error de colocación de cuadros y apliques, que se corrigió (punto 11). Cada cambio está en su propio commit.

## Cómo se mide

`./tools/benchmarks/run_bench.ps1 -Label nombre` ejecuta `tools/benchmarks/hotel_benchmark.gd` a 1080p con la semilla 81 y deja `evidence/bench/<nombre>_<renderizador>/report.json`, más capturas de cada vista y calidad. Hay dos capturas por vista: `_raw` sin filtro de cinta, para comparar píxeles, y `_vhs`, tal como se juega. El faro y los fluorescentes quedan congelados encendidos en ambas.

Cada vista mide, por calidad:
- tiempo de fotograma (media, p95, p99 y máximo), de GPU y del hilo de render;
- llamadas de dibujo y primitivas, visibles y de sombra;
- VRAM.

Hay tres vistas quietas (recepción, sala 36 y salida) y un **tramo caminando** por la ruta desde la recepción, que reproduce los redibujados de sombra de una partida real. La medición espera 1,5 s antes de empezar: el atlas de sombras recoloca las luces 0,5 s después de asignarlas.

Además, por vista:
- **Llegadas** (`arrival`): la cámara aterriza en ocho salas que la pasada no ha dibujado nunca y se miden los 20 fotogramas siguientes **sin esperar a que nada se asiente**. Es lo que siente quien entra en una sala por primera vez.
- **Tirones:** fotogramas por encima del doble de la mediana de la vista, por encima de 20 ms y de 33 ms, y los tres peores.
- **Pipelines construidos** durante la vista (`pipelines_draw`, los que hacen esperar al fotograma, y `pipelines_all`), de los monitores `PIPELINE_COMPILATIONS_*` de Godot. Son totales acumulados desde el arranque: la herramienta resta fotograma a fotograma.

Para medir sin caché de shaders hay que borrar antes `.godot/shader_cache` y, en los datos de usuario, `shader_cache` y `vulkan` (la caché de pipelines). **Con el juego abierto no se mide:** comparte la GPU y el mismo recorrido llegó a dar 14 ms de GPU en una pasada y 24 en la siguiente.

**Este PC no pasa de 350 FPS, y no es el juego.** RivaTuner (RTSS, el de MSI Afterburner) tiene puesto un límite global de 350 FPS, la frecuencia del monitor, y se lo aplica a todo: una ventana de Godot vacía, sin 3D y a cualquier tamaño, marca exactamente 2,857 ms por fotograma. Ningún fotograma de este documento baja de ahí, así que **el tiempo de fotograma de los presets bajos es ese tope** y lo que hay que leer en ellos es la GPU y el reparto del procesador. Durante mucho tiempo este documento atribuyó esos 2,9 ms a la CPU o a «presentar la imagen»; era el limitador. El equipo modesto simulado (sección 10) queda por encima del tope en casi todas sus filas y no lo nota.

Herramientas relacionadas:
- `./tools/benchmarks/bench_table.ps1 base,final` pone dos informes en tabla.
- `tools/benchmarks/compare_captures.gd` compara dos juegos de capturas: da la diferencia media y máxima y el porcentaje de píxeles que cambian, y escribe una imagen de diferencias.
- `-Compatibility` mide con el otro renderizador; `-Extra '--shadow-filter=N'` o `'--atlas-quads=a,b,c,d'` sirven para pruebas A/B.
- `-Extra '--qualities=0,3'` mide solo esos presets y `'--set=clave:valor,...'` fuerza valores de `graphics_presets.gd` sobre todos, para medir un efecto solo (sección 6). Los presets se numeran como se guardan: 0 Bajo, 1 Medio, 2 Alto, 3 Ultra y 4 Muy bajo.
- `'--setting=clave:valor,...'` pone ajustes del jugador (`settings_service.gd`) después de cada preset, por ejemplo `--setting=upscaler:fsr2`, y `'--hide=Analog,Lens'` deja sin dibujar esas capas de la presentación (el filtro de cinta, la lente, `Camcorder` para el OSD). **Cada pasada parte de los ajustes de fábrica:** los de la anterior quedan guardados y se medirían otra vez.
- `'--passes'` reparte el tiempo de GPU de cada vista por **etapas del render 3D** (solo Forward+): `viewport` (culling, mapas de sombra, prepasada de profundidad, clústeres de luces), `opaque` (todas las superficies sombreadas e iluminadas), `sky`, `transparent`, `camera` (los efectos propios: desenfoque de movimiento y videocámara) y `post` (glow, escalado, tonemap, FXAA y el lienzo: lente, filtro de cinta y OSD). El perfil de fotograma de Godot no se puede leer desde un script; un efecto de compositor sí deja una marca de tiempo en cada etapa.
- Cada vista trae además **dónde se va el hilo principal** (`cpu`): un tick de física (los `_physics_process`, la física y la navegación), el `_process` de un fotograma y dibujarlo. Sin límite de FPS un fotograma solo lleva un tick de vez en cuando y su media los esconde; a 60 FPS cada fotograma lleva uno, así que lo que cuesta ahí es `at_60`: uno de cada.
- **Equipo modesto simulado** (sección 10): `-Modest` deja al juego cuatro núcleos a un hilo cada uno, con el otro hilo de cada núcleo ocupado, y `-Extra '--pixels=9'` lo dibuja todo con nueve veces los píxeles de la ventana.
- `tools/benchmarks/preset_sheet.gd` pone los cuatro presets de una vista en una hoja (`--view=room36`, `--crop=x,y,w,h`).

## Antes y después

PC de desarrollo (RTX 4060 Ti), 1080p, vsync desactivado. Tiempos en ms (media); llamadas por fotograma.

| Calidad · vista | Fotograma | GPU | Hilo de render | Llamadas visibles | Llamadas de sombra | Primitivas visibles |
|---|---|---|---|---|---|---|
| Baja · caminando | 3,95 → 2,87 | 3,10 → 1,65 | 1,85 → 1,02 | 446 → 89 | 1.343 → 431 | 187k → 31k |
| Media · caminando | 5,71 → 4,20 | 4,78 → 3,36 | 2,81 → 1,20 | 584 → 95 | 1.791 → 451 | 393k → 33k |
| Media · salón (sala 36) | 6,21 → 4,35 | 5,32 → 3,49 | 3,51 → 1,44 | 573 → 84 | 2.479 → 809 | 697k → 34k |
| Alta · caminando | 6,80 → 5,53 | 5,95 → 4,67 | 2,99 → 1,25 | 585 → 94 | 1.831 → 448 | 414k → 33k |
| Alta · salón (sala 36) | 7,44 → 5,10 | 6,57 → 4,29 | 3,54 → 0,83 | 573 → 84 | 2.479 → 0 | 697k → 34k |

- **p99 caminando:** 7,4 → 5,7 ms en Media y 8,6 → 7,1 ms en Alta.
- **Nodos del piso:** 11.907 → 9.852.
- **VRAM de texturas:** unos 15 MB menos con el personaje por defecto.
- **VRAM al elegir Exploradora:** unos 420 MB menos (525 → 105 MB). Detective femenino baja de 56 a 14 MB.
- En Baja el fotograma se queda en unos 2,9 ms aunque la GPU baje: es el limitador de 350 FPS de este PC («Cómo se mide»), no el juego.

Estas cifras son de una GPU rápida. Una gráfica modesta gana más con la reducción de llamadas, primitivas y oclusión, pero **está pendiente medirlo en un PC como los de las pruebas con amigos**.

## 1. Problemas encontrados, por impacto

1. **Todas las sombras se redibujaban en cada fotograma, con la escena quieta.** Hubo tres causas, aisladas con pruebas:
   - `update_visibility()` escribía `shadow_enabled` en cada lámpara cuatro veces por segundo. Godot redibuja la sombra en cada escritura, aunque el valor no cambie (`LightStorage::light_set_shadow`).
   - El polvo (`CPUParticles3D`), que se actualiza en cada fotograma, contaba como proyector de sombra alrededor del jugador.
   - La cortina usa `TIME` en su `vertex()`. Para Godot ese material está «animado», y redibuja en cada fotograma la sombra de toda lámpara que la alcance.
   - Era la mitad del tiempo de GPU en la sala 36.
2. **Unos 40 MultiMesh por sala**, uno por pared o mueble y material. Cada uno era una llamada en la pasada de cámara y en cada cara de cada sombra.
3. **Paredes compartidas dibujadas dos veces.** Las salas se tocan sin hueco y cada una levantaba sus cuatro paredes: dos copias superpuestas de núcleo, arrimadero y molduras. Eso duplicaba los fragmentos en las superficies más grandes de la pantalla.
4. **Sin occlusion culling.** Con salas visibles hasta 66 m, todo lo que caía en el cono de visión se dibujaba en la prepasada aunque estuviera tras varios muros.
5. **Filtro de sombras suaves en Soft Medium con PCSS en todos los presets.** Se paga por píxel y por lámpara con sombra; bajarlo ahorra alrededor de una décima parte de la GPU por escalón, sin diferencia visible.
6. **Mallas horneadas sin LOD.** El aplique de pared tiene 14,3k triángulos y hay hasta 16 por sala pública. Otras: monstera 9,3k, sofá 2,7k, avatar 34,8k.
7. **Texturas en *Lossless* sin detectar su uso 3D.**
   - Puertas: 8 de 1024², además sin mipmaps (parpadeo y ancho de banda).
   - Personajes: 525 MB para Exploradora y 56 MB para Detective femenino, con los mapas de normales sin marcar.
8. **Marcos y topes de las unas 108 puertas en la raíz**, visibles a cualquier distancia, con tres mallas sueltas por tope.
9. **Tirones de CPU.**
   - Visión de The Locust: cada chasquido generaba todas sus direcciones en un tick (1,3 / 2,6 / 7,4 ms, dos veces por segundo).
   - Rutas de sonido: buscaban un camino por todo el piso aunque la fuente estuviera fuera de alcance.
   - La cápsula del jugador se reescribía en cada tick.
10. **Menores.** Números de puerta transparentes e iluminados a cualquier distancia; etiquetas que se registraban como proyectores de sombra.
11. **Error visual.** Los cuadros y apliques de las paredes oeste y norte colgaban en la cara de la sala vecina, encima de los cuadros propios de esa sala (marcos en z-fighting). Por eso esas paredes estaban desnudas y había apliques de pasillo dentro de habitaciones.

## 2. Cambios realizados (un commit cada uno)

| Commit | Cambio | Efecto medido |
|---|---|---|
| Benchmark | GPU, hilo de render, llamadas, VRAM, p99, tramo caminando, capturas con y sin filtro, comparador | Base para medir |
| Sombras en caché | `shadow_enabled` solo al cambiar; polvo sin sombra; cortinas con copia quieta solo para sombrear (`SWAYING`); marcos y topes ocultos con su puerta; malla compartida para topes y sellos; números de puerta hasta 20 m; etiquetas sin sombra | Vistas quietas sin redibujado de sombras. Hilo de render caminando en Media: 2,81 → 1,45 ms |
| Texturas | Puertas y personajes en VRAM comprimida, con mipmaps y normales marcados | Exploradora 525 → 105 MB; Detective femenino 56 → 14 MB; puertas −13 MB |
| LOD | `tools/props/add_mesh_lods.gd`: LOD automáticos en aplique, monstera, sofá y detective, con superficies, materiales y límites intactos | Primitivas visibles −50 a −80 % |
| Agrupar por sala | Un MultiMesh por material y sala (`batch_roots`, `batch_target()`); colisiones intactas | Llamadas −40 a −50 % |
| Paredes una vez | Se dibuja solo la mitad propia del núcleo y la cara propia (`wall_core()`); el colisionador sigue siendo la caja entera de 18 cm; la galería conserva paredes completas (`full_walls`) | GPU −10 a −16 % |
| Oclusión | `use_occlusion_culling`; un `OccluderInstance3D` por sala con quads dentro de sus paredes, dinteles y alcobas; las nubes de eco lo ignoran; se desactiva durante una ejecución | Llamadas −70 %, primitivas −80 %; +0,2–0,3 ms de CPU de oclusión |
| Cuadros y apliques | Colocados en la cara interior (`inner`) | Cambio visual deliberado: ahora cada pared tiene los suyos |
| Filtro por preset | Baja Soft Very Low, Media Soft Low, Alta Soft Medium (hoy `shadow_filter` en `graphics_presets.gd`, sección 6) | GPU caminando: Baja 2,38 → 1,65 ms; Media 3,76 → 3,36 ms |
| CPU | Direcciones de eco bajo demanda; rutas de sonido sin búsqueda más allá de `ROUTE_LIMIT + ROUTE_SLACK`; cápsula solo al cambiar | Del orden de 1,3–7,4 ms por chasquido a unos 0,1 ms por tick |

## 3. Recomendaciones que no se aplicaron

- **Competencia en el atlas de sombras.**
  - En Media (atlas de 4096) y en algunas vistas, varias luces se disputan los huecos grandes y se redibujan en cada fotograma. En la sala 36 quedan unas 800 llamadas de sombra por fotograma.
  - Cambiar las subdivisiones de los cuadrantes lo evita en esa vista, pero cambia qué resolución recibe cada sombra.
  - Hay que probarlo con capturas A/B: `run_bench.ps1 -Extra '--atlas-quads=2,3,4,4'`.
- **MSAA 2× en Media y Alta.** Es redundante con TAA en Alta y con el emborronado VHS. Necesita comparación A/B. *Resuelto en los presets (sección 6): Medio usa solo TAA.*
- **Sombra del jugador local.** `shadow_caster_mask` evitaría que sus lámparas vecinas se redibujen al caminar, pero se perdería su propia sombra. *Resuelto en los presets: Bajo la quita (`body_shadow`).*
- **Sombras omni dual-paraboloid: descartadas.** Deforman las cajas grandes de pocos polígonos y abrirían fugas de luz.
- **Niebla volumétrica y SSIL a menor resolución.** Cambian el haz de la linterna y el rebote.
- **LOD en la hoja y el marco de puerta.** Se dejaron fuera a propósito, porque sellan la luz.
- **Sombra del avatar en una sola superficie.** Son 14 llamadas por pasada de sombra al caminar. Queda como mejora opcional; los LOD ya reducen sus triángulos.
- **Texturas ORM** (oclusión, rugosidad y metal empaquetados) para puertas, armario y aplique. Requiere rehacer los materiales.
- **Exploradora.** `model_38`/`40` y `model_41`/`43` son idénticas. (Las blend shapes ya se quitan al importar; la cabeza vuelve a 2048 porque a 1024 la cara se veía borrosa de cerca, unos 8 MB más de vídeo.)
- **Unos 111 MB de texturas no usadas en el PCK.** Solo afecta al tamaño del ejecutable, no al rendimiento. Reimportar un FBX vuelve a extraerlas.
- **Grietas de la tele en la entrada.** `crack_pattern.gd` pinta píxel a píxel, con un tirón estimado de 50–300 ms en cada golpe. Se podría precalcular o mover a un hilo.
- **CPU menor.**
  - `FLOOR.room_at` recorre todas las salas tres veces por tick.
  - `_physics_process` de puertas y armarios corre en reposo.
  - El OSD se repinta en cada fotograma.
  - El subtítulo se reescribe en cada fotograma.
- **FSR 1** cuando la escala 3D sea menor que 1. *Resuelto: `settings_service.apply()`.*

## 4. Posibles regresiones a revisar en partida

- **Fugas de luz** entre salas y a través de puertas: paredes a media visual, oclusión. Las capturas de `darkness_capture.gd` no muestran diferencias.
- **Salas, muebles o marcos que aparezcan tarde** al girar rápido en un vano de puerta (oclusión). Si pasa, se sube `rendering/occlusion_culling/occlusion_rays_per_thread`.
- **Cambios de LOD visibles** en apliques, monstera y sofá.
- **Sombras más granuladas en movimiento** en Baja y Media (filtro).
- **Cuadros y apliques nuevos** en paredes oeste y norte: posición y choque con muebles o puertas.
- **Cortinas.** Su sombra ya no se mece; el balanceo es de 3,5 cm.
- **Audio.** Presencia de The Locust y pisadas a 40–55 m: la lógica es equivalente, pero conviene escucharlo.
- **Visión de eco.** Mismo reparto de rayos, en otro orden de azar.

## 5. Checklist de pruebas antes/después

1. `./tools/verify.ps1`, sin fallos. Pasó en cada fase.
2. `./tools/benchmarks/run_bench.ps1 -Label x` y `bench_table.ps1 base,x`. Mirar GPU, hilo de render, p99 y llamadas de sombra caminando.
3. `compare_captures.gd` sobre las capturas `_raw`: diferencia inferior al 0,5 % de píxeles, salvo los cambios deliberados.
4. `darkness_capture.gd`, `doors_capture.gd`, `rooms_capture.gd`, `props_capture.gd`, `echo_capture.gd` (con `--automation`) y `character_capture.gd`.
5. `run_bench.ps1 -Compatibility`.
6. Partida con `./tools/godot.ps1 playtest -Seed 81`:
   - pasillos con apliques, salas oscuras con puertas cerradas, linterna;
   - un armario y una persecución;
   - los cuatro presets.
7. `./tools/godot.ps1 locust -Seed 81` y `rehearsal`: la visión de eco sin tirones al chasquear.
8. Repetir el benchmark en un PC modesto y anotar sus cifras aquí.

## 6. Presets gráficos: Bajo, Medio, Alto y Ultra

*Desde octubre de 2026 hay un quinto preset por debajo de Bajo, **Muy bajo**, para gráficas integradas: está en la sección 10, con lo que tiene de distinto.*

Los tres niveles de calidad (Baja, Media, Alta) apenas se distinguían, y nada estaba pensado para gráficas integradas. Ahora hay cuatro presets con diferencias claras y acumulativas. Todo lo que cambia con la calidad está en una tabla, `game/presentation/graphics_presets.gd`, y ningún otro archivo guarda valores por calidad. La calidad guardada 0–2 conserva su significado (Bajo, Medio, Alto) y 3 es Ultra. Elegir un preset fijaba también su escala de render; desde octubre de 2026 no toca ni la escala ni el escalado, que son ajustes aparte (sección 10).

### Qué cambia

| Parámetro | Bajo | Medio | Alto | Ultra |
|---|---|---|---|---|
| Escala de render y escalado con los que se diseñó y se midió (elegir un preset no los pone: son ajustes del jugador; con el escalado en «Automático», el de fábrica, el escalado sí es este) | 0,67 + FSR 1 | 0,85 + FSR 2.2 | 1,0 | 1,0 |
| Antialiasing | FXAA | El de FSR 2.2 (TAA si se elige otro escalado) | TAA + MSAA 2× | TAA + MSAA 4× |
| AA especular (limitador de rugosidad) | no | sí | sí | sí |
| Atlas de sombras | 4096 | 4096 | 8192 | 8192 |
| Filtro de sombras | Soft Very Low | Soft Low | Soft Medium | Soft Medium (era Soft High: sección 11) |
| Penumbra (tamaño de la fuente, PCSS) | ninguna (PCF simple) | la de siempre | la de siempre | ×2,5, como la cúpula esmerilada |
| Alcance de las lámparas (luz y sombra) | 42 m | 42 m | 48 m | 64 m |
| Salas dibujadas | 56 m | 66 m | 66 m | 82 m |
| Lámparas de muebles | apagadas | hasta 28 m | hasta 32 m | hasta 40 m |
| Lámparas de techo con sombra a la vez | todas las encendidas | todas | todas | las 20 más cercanas; las demás alumbran solo su sala, sin sombra (sección 11) |
| Sombra del cuerpo propio | no | sí | sí | sí |
| SSAO | no | Low, media resolución | Medium, media resolución | High, resolución completa, y oscurece también la luz de las lámparas (0,6 frente a 0,15) |
| SSIL | no | no | Medium, media resolución | High, media resolución |
| Reflejos SSR | no | no | 32 pasos, rugosidad Low | 64 pasos, rugosidad High |
| Sondas de reflexión | no | 1 de cada 3 vestíbulos | todas las salas iluminadas, con sombras | igual que Alto |
| Rebote de luz (un VoxelGI por sala iluminada) | no | no | sí, media resolución | sí, resolución completa |
| Apliques que iluminan (con sombra) | no | no | sí, hasta 24 m | igual que Alto, y los que no caben entre los doce alumbran sin sombra hasta 40 m, cada uno solo su sala |
| Lámparas en la niebla volumétrica (niebla de 14 m) | no | sí | sí | sí |
| Niebla volumétrica | no | 48³ | 64³ | 96³ |
| Neblina de suelo en vestíbulos | no | no | sí | sí |
| Glow | sí | sí | sí, subida bicúbica | igual que Alto |
| Debanding | no | no | sí | sí |
| Polvo (partículas) | no | 60 | 90 | 140 |
| Detalle de superficies | 2 octavas, sin microdetalle | 3 octavas | 4 octavas | 4 octavas, y lo que distingue una superficie de un plano dibujado: barniz en capa propia, paredes y techos que no son planos, baldosas cada una con su inclinación, pelo de moqueta (sección 11) |
| Cuadros | lienzo | lienzo | lienzo | tras un cristal |
| Materiales escaneados | 1024 px, sin antirrepetición | 2048 px | 2048 px | 2048 px |
| Decals (humedad, manchas, huellas) | no | la mitad | todos | todos |
| Filtro VHS | 4 lecturas de croma | 7 | 7 | 7 |
| Umbral de LOD | 4 px | 2 px | 1 px | 1 px |
| Filtrado anisotrópico | 2× | 4× | 8× | 16× |
| Smear de CCD | no | sí | sí | sí |
| Halo y reflejos fantasma de las lámparas | no | sí | sí | sí |
| Motion blur (muestras) | no | 6 | 8 | 12 |
| Autoenfoque | no | no | sí | sí |
| Visión de eco (criatura) | ½ de granos, ×2 de tamaño | base | más densa | algo más fina + halo de fósforo |

**Lo que no cambia, a propósito:**
- **Sombras de las lámparas.** Toda lámpara visible conserva su sombra en estos cuatro presets (Muy bajo no tiene sombras de lámpara y las confina de otra manera: sección 10). Una lámpara sin sombra atraviesa paredes y puertas cerradas, así que la sombra se abarata (filtro, penumbra, cuerpo propio), nunca se quita. Por la misma razón el atlas no baja de 4096: con celdas más bastas, el sesgo crece más que el grosor de una hoja de puerta.
- **Luz ambiente cero y niebla casi negra.** Las salas oscuras son negras en todos los presets.
- **Números de puerta y rótulos (20 m), faro rojo, sellos de puerta y salas oscuras.** Son gameplay y orientación.
- **Filtro VHS.** Sus deslizadores y «Efectos reducidos» son ajustes del jugador.
- **GI.** SDFGI deja pasar luz por muros de 18 cm y los lightmaps no se hornean en partida. Desde Alto, el rebote es un VoxelGI por sala, horneado en hilos al cargar el piso ([REALISM.md](REALISM.md), prueba 8), más SSIL. Solo los 8 volúmenes que se dibujan tienen sus datos: con datos, un volumen ocupa unos 56 MB de vídeo aunque esté oculto, y los 51 de un piso llegaban a 2,9 GB. Con un volumen por tramo recto de pasillo (25 de septiembre) una planta pasa de 125 a 110 volúmenes y hornea en 0,9 s en vez de 1,0, pero los tramos largos (hasta 43 m, a subdivisión 128) cuestan en Alto unos 170–195 MB más de vídeo (1687 → 1860 MB, ventana de 960×540) y 0,24 ms de GPU (4,83 → 5,07 ms; Ultra 6,80 → 7,34 ms).
- **Decals.** No hay ninguno.
- **Streaming de texturas.** Godot 4.7 no lo tiene. Las texturas ya van comprimidas (sección 2).

### Rendimiento medido

PC de desarrollo (RTX 4060 Ti, Ryzen 9 5900X), 1080p, sin límite de FPS. Tiempos en ms (media); `run_bench.ps1 -Label presets`. Es la medida de antes del plan de fotorrealismo: lo que suman la cámara y la luz está en [REALISM.md](REALISM.md) (Alto caminando: 5,71 ms con la cámara y 6,90 ms con la luz, en una medida posterior de la misma escena).

| Preset | GPU caminando | Fotograma caminando | p99 caminando | GPU salón (sala 36) | GPU recepción | Llamadas de sombra caminando | Memoria de vídeo |
|---|---|---|---|---|---|---|---|
| Bajo | 0,74 | 2,85 | 3,5 | 0,77 | 0,69 | 26 | 842 MB |
| Medio | 2,35 | 3,27 | 5,1 | 2,44 | 1,96 | 447 | 935 MB |
| Alto | 4,92 | 5,78 | 7,2 | 4,53 | 3,93 | 558 | 1.256 MB |
| Ultra | 6,87 | 7,73 | 9,8 | 6,82 | 6,24 | 588 | 1.375 MB |

Frente a los tres niveles anteriores (sección «Antes y después», GPU caminando): Baja 1,65 → Bajo 0,74; Media 3,36 → Medio 2,35; Alta 4,67 → Alto 4,92. Alto añade SSR, sondas en todos los vestíbulos y lámparas hasta 48 m. De Bajo a Ultra la GPU se multiplica por 9.

- **Bajo:** unos 350 FPS en este PC, que es el tope del limitador de fotogramas de este equipo («Cómo se mide») y no la CPU, como decía aquí: la GPU solo trabaja 0,74 ms.
- **Ultra:** unos 130 FPS a 1080p en este PC. No está medido a 1440p ni en gráficas de gama media.
- **Diferencia visual entre presets vecinos** (capturas sin VHS, píxeles que cambian más de 12 niveles): Bajo → Medio del 0,8 al 3,7 %; Medio → Alto del 2,0 al 5,2 %; Alto → Ultra del 0,3 al 1,9 %. Donde más se nota Alto → Ultra es en las penumbras, en el salón.
- **Hojas comparativas:** `evidence/bench/presets_forward_plus/sheet_*.png`, con `preset_sheet.gd`.

Lo que más se nota en partida no sale en una foto fija: antialiasing en movimiento, haz volumétrico de la linterna, polvo en el haz y lámparas lejanas encendidas en pasillos largos.

### Coste de cada efecto

Medido forzando un valor sobre el preset (`-Extra '--qualities=N --set=clave:valor'`). GPU caminando, en ms; el ruido entre medidas es de ±0,1–0,2 ms.

| Efecto | Preset | Coste |
|---|---|---|
| Soft High frente a Soft Medium | Ultra | 1,25 |
| SSIL a resolución completa frente a media (no adoptado: sin diferencia visible) | Ultra | 1,65 |
| Escala 0,85 frente a 1,0 | Medio | 0,63 |
| SSIL Medium | Alto | 0,46 |
| SSR 64 pasos | Ultra | 0,44 |
| SSAO a resolución completa frente a media | Ultra | 0,41 |
| Escala 0,67 frente a 1,0 | Bajo | 0,36 |
| MSAA 2× | Alto | 0,37 |
| Niebla volumétrica 96³ frente a 64³ | Ultra | 0,27 |
| SSAO Low | Medio | 0,27 |
| TAA | Medio | 0,20 |
| SSR 32 pasos | Alto | 0,20 |
| Penumbra (PCSS) frente a PCF simple | Bajo | 0,13 |
| Sombra del cuerpo propio al caminar | Bajo | 0,13 (y unas 420 llamadas de sombra) |
| Glow | Bajo | 0,10 |
| Niebla volumétrica 48³ / 64³ | Medio / Alto | ~0,10 |
| Lámparas hasta 64 m frente a 48 m | Ultra | ~0 caminando; 0,17 en el salón |

**Lo que más cambia los FPS:**
1. **Escala de render.** El coste de casi todo es por píxel: 0,85 quita un 27 % de la GPU en Medio. En gráficas modestas, que se quedan cortas por píxeles, pesa aún más.
2. **Filtrado de sombras.** Soft High era lo más caro de Ultra (un 18 % de su GPU) y se puso por su penumbra ancha; medido después, Soft Medium dibuja la misma penumbra bajo TAA y Ultra ya no lo usa (sección 11).
3. **Efectos de pantalla:** SSIL, SSAO, SSR y MSAA, entre 0,2 y 0,5 ms cada uno.
4. **Sombra del propio cuerpo al caminar.** En Bajo quitarla deja las llamadas de sombra en 26 (frente a unas 450), porque ya nada obliga a redibujar las lámparas de alrededor en cada paso.
5. **El detalle de shaders y el filtro VHS reducido casi no se notan en esta GPU** (0,04 ms). Ahorran cálculo, que pesa más en una integrada; en Bajo, además, quitan el grano de aliasing del techo.

### Visión de eco por preset

Bajo tenía presupuesto cero y dejaba al jugador de The Locust a oscuras. Ahora:
- **Bajo:** la mitad de granos que Medio, del doble de tamaño. Puertas y armarios conservan sus rayos.
- **Ultra:** algo más fino que Alto (más granos, más pequeños), para no dar más información; su atractivo es un halo tenue de fósforo alrededor de cada grano.

Detalle en [VISION_LOCUST.md](VISION_LOCUST.md). Capturas: `echo_capture.gd` (`preset_0` a `preset_3`).

### Renderizador y gráficas integradas

- **Opción en Ajustes ▸ Gráficos ▸ Renderizador:** Forward+ o Compatibilidad (OpenGL). Se guarda en `user://renderer.cfg`, que `project.godot` usa como override, y se aplica al reiniciar; desde el menú principal hay un botón para reiniciar.
- **Primer arranque** (`settings_service.first_run`): Medio al 67 % con FSR 2.2 («Calidad»). Con gráfica integrada (`RenderingServer.get_video_adapter_type()`), Muy bajo con su escala (era Bajo hasta la sección 10), y el menú sugiere subir de preset si va sobrado y Compatibilidad si no.
- **Compatibility probado con los cuatro presets** en este PC, sin errores. En una gráfica dedicada no es más rápido: Bajo 1,47 ms de GPU frente a 0,74 en Forward+. Su ventaja esperada está en integradas, **sin medir: este PC no tiene gráfica integrada** (el 5900X no trae GPU).
- **Fugas de luz** con la sala oscura y la puerta cerrada: brillo medio inferior a 1/255 en los cuatro presets, también con la penumbra de Ultra.
- **El atlas de sombras guarda la profundidad en 32 bits en Compatibilidad** (unos 32 MB más de memoria de vídeo con el atlas de 4096): con 16 bits la linterna se rayaba a sí misma en bandas diagonales en las paredes que alumbra de frente, a partir de un módulo de distancia (en la guía de desarrollo).

### Pendiente

- Medir Bajo, en Forward+ y en Compatibilidad, en un PC con gráfica integrada, y Ultra en una gráfica de gama media a 1440p. Con las plantas enteras (apartado 7), medir también cuánto tarda en montarse un piso en un PC como los de las pruebas con amigos.
- Revisar en partida:
  - TAA de Medio en movimiento (estela del polvo y de la linterna);
  - penumbras anchas de Ultra con las lámparas que parpadean;
  - la visión de eco de Bajo y el halo de Ultra con jugadores reales.

## 7. Un piso de tres plantas enteras (generadores 5 a 7)

Desde el 23 de septiembre de 2026 un piso son tres plantas y cada una es un hotel entero: unas 410 salas en lugar de 121, y tres mallas de navegación. Medido en este PC.

**Montar un piso** (`start_floor`, sin ventana, ocho semillas): de 5,1 a 5,9 s, mediana 5,7 (con el generador 6 eran de 5,8 a 6,8); antes de las plantas eran 3,9 s. En la semilla 81:
- generar el manifiesto, unos 0,1 s;
- `hotel_geometry.build()`, 3,1 s: salas y puertas de las tres plantas, 1,0; los lotes y los cuerpos, 0,15; leer la geometría para la navegación, 0,04; hornear las tres mallas, 1,9;
- la validación física, 23 ms;
- esperar a que el servidor de navegación acepte las tres mallas, 2,8 s. Son fotogramas de espera: la ventana sigue respondiendo.

**Sin «No responde».** Windows marca así una ventana que no atiende nada durante cinco segundos. `build()` devuelve un fotograma entre planta y planta y antes de la navegación (`building`: mientras dura, el hotel está oculto y `update_visibility()` no lo toca). Lo más largo que queda sin soltar son los tres horneados juntos, unos 2 s; antes eran 2,9 s de una vez, y más en un PC lento. Un fotograma entre horneado y horneado, en cambio, hacía que la navegación tomara cada planta por separado, y el piso tardaba 2,2 s más en estar listo.

**Nodos** (semilla 81): de 50.616 a 36.220, y de 35.000 a 38.000 en las ocho semillas. El tope del plan era 40.000; antes de las plantas eran 14.761.
- **Un cuerpo por sala.** Cada caja sólida era un `StaticBody3D` con su `CollisionShape3D`. Ahora es una forma del cuerpo `Solid` de su sala: los cuerpos estáticos pasan de 11.563 a 1.705, las formas no cambian, y la navegación y la validación física salen igual.
- **Fuera los contenedores vacíos.** Paredes, tramos de muebles y muebles eran nodos solo por su transformación mientras se construía la sala. Lo que dibujan va en los lotes de la sala, así que al terminar (`drop_empty()`) se quitan los que se quedan vacíos: los `Node3D` pasan de 6.135 a 1.597.
- **Topes de puerta** sin nodo propio: la franja es la malla misma (369 menos).

**Con ventana, 1080p** (`run_bench.ps1 -Label plantas`, semilla 81):

| Preset | Fotograma caminando (media / p99) | GPU caminando | Memoria de vídeo |
|---|---|---|---|
| Bajo | 3,1 / 7,3 ms (unos 325 FPS) | 1,40 ms | 520 MB |
| Medio | 5,8 / 11,9 ms (unos 170 FPS) | 4,68 ms | 713 MB |
| Alto | 10,8 / 15,4 ms (unos 93 FPS) | 9,75 ms | 1.873 MB |
| Ultra | 14,1 / 19,0 ms (unos 71 FPS) | 13,15 ms | 2.031 MB |

- **No es la misma medida que la de la sección 6:** el recorrido es otro, por otro hotel, así que la comparación es orientativa. Caminando, la GPU sube entre un 9 y un 32 % según el preset, y el p99 de Bajo y Medio pasa de 3,8 y 6,4 ms a 7,3 y 11,9, con muchos más redibujados de sombra (llamadas de sombra caminando: de 24 a 931 en Bajo y de 469 a 1.507 en Medio).
- **Cargar el primer piso con el juego recién abierto: 8,9 s.** De ellos, 2,1 s son los dos primeros fotogramas del render, antes de generar nada. El montaje son 3,8 s (3,1 sin ventana) y la espera de la navegación, 2,8 s.
- **Memoria estática máxima:** de 0,88 a 1,05 GB en dos medidas; antes de las plantas, 0,70 GB.
- **El rebote de luz**, en Alto y Ultra, solo se hornea para la planta desde la que se mira (`start_bounce(planta)`, [REALISM.md](REALISM.md)): antes se horneaban las tres al empezar, a unos 55 ms por sala, y sus datos se quedaban para siempre.

**La espera de la red** (`READY_TIMEOUT`) se queda en 30 s: aquí un piso tarda unos 6 s en montarse, y el anfitrión espera a los invitados hasta cinco veces eso.

## 8. Bots de prueba

Medido el 23 de septiembre de 2026 en este PC (24 hilos), con `./tools/bots.ps1`: cada piso es un proceso de Godot sin ventana a `--fixed-fps 60`, así que corre tan deprisa como da la máquina.

| Partida | Tiempo de juego por segundo real |
|---|---|
| Sin criatura, sabiéndolo todo (1 / 3 / 5 bots) | ×10–11 / ×7–7,5 / ×5,5–6 |
| Sin criatura, descubriéndolo todo (1 / 3 / 5 bots) | ×12–14 / ×9–10 / ×7–8 |
| Con criatura, 3 bots, cinco pisos a la vez | ×3,5–4,5 |

- **Lo que cuesta con criatura** es mirarla: cada bot pregunta varias veces por segundo si alguno de sus ojos (el de ahora, los de su camino y su destino) lo vería, y si su oído llegaría a sus pasos, que es una ruta de la malla cada vez.
- **Montar el piso** son los mismos 6 s de siempre, más el arranque del proceso.
- **La grabación** ocupa unos 90 KB por minuto de juego con tres bots: 2,7 MB una partida de 36 minutos, la mayor parte en `events.jsonl` (cada pisada es una línea, para dibujar sus ruidos en el repaso).
- **Varios a la vez:** con `-Parallel 4` o `5` los pisos van un poco más lentos cada uno, pero el lote entero termina mucho antes.

## 9. Pipelines en la carga y relleno de apliques (A/B/C)

Medido el 25 de septiembre de 2026 en este PC, con el juego cerrado: Ultra, semilla 81, 1080p, `run_bench.ps1 -Extra '--qualities=3'`. Cada estado se midió dos veces, con la caché de shaders y de pipelines borrada («fría») y llena («caliente»); abajo va la caliente, y la fría cuando dice algo distinto.

- **A:** el estado de partida.
- **B:** A más el calentamiento de pipelines en la carga (`presentation/shader_warmup.gd`).
- **C:** B más los apliques que pasan del límite de doce iluminando solo el rebote (máscara de culling a cero, sin sombra). **Se probó y se retiró.**

| | A | B | C |
|---|---|---|---|
| Carga del piso | 9,4 s | 13,6 s | 13,3 s |
| Recorrido: media · p95 · p99 · máximo | 15,5 · 19,3 · 20,7 · 23,4 ms | 15,4 · 19,0 · 20,2 · 20,4 ms | 15,5 · 18,5 · 19,6 · 19,8 ms |
| Recorrido: GPU · CPU de render (media) | 14,5 · 3,4 ms | 14,5 · 3,3 ms | 14,7 · 3,0 ms |
| Llegadas: media · p95 · p99 · máximo | 9,0 · 14,6 · 29,5 · 36,7 ms | 8,6 · 15,1 · 24,7 · 26,3 ms | 8,6 · 15,0 · 29,0 · 30,6 ms |
| Llegadas en frío: máximo | 35,6 ms | 28,9 ms | 28,4 ms |
| Llegadas: fotogramas sobre 33 ms | 1 | 0 | 0 |
| Pipelines construidos al llegar (de dibujo · todos) | 28 · 91 | 7 · 44 | 7 · 50 |
| Fuga, `light_leak.gd --quality=3`: peor · mediana | = B (el calentamiento no toca la luz) | 0,0359 · 0,0085 | 0,0359 · 0,0157 |
| Memoria de vídeo | 2058 MB | 2086 MB | 2087 MB |

**B, el calentamiento: se queda.**
- **Cuánto era crear pipelines:** una parte, no todo. Al llegar a salas nuevas Godot construía 28 pipelines de dibujo; con el calentamiento, 7. El peor fotograma baja de 36,7 a 26,3 ms y ninguno pasa de 33 ms; el peor del recorrido, de 23,4 a 20,4 ms.
- **Lo que no era:** el resto del pico al llegar sigue ahí (p99 de 25 ms, cinco a siete fotogramas por encima del doble de la mediana) con los pipelines ya construidos. Es trabajo de CPU al entrar en una sala (visibilidad, sondas de reflexión, volúmenes de rebote), no compilación.
- **Medias y GPU no cambian**, y la escena sale idéntica: las capturas de A y B solo difieren en el rótulo de objetivo del HUD, que aparece en otro momento porque la carga dura más.
- **La carga:** unos 4 s más, fría o caliente (la mayor parte es recorrer las salas, no compilar). El fotograma más largo de la pantalla de carga es de 0,15 s, así que no parece colgada, y dice cuánto le falta.
- Lo que queda sin cubrir son 7 pipelines en las ocho llegadas. Cubrirlos pediría visitar más salas o más ángulos, y no se hizo.

**C, el relleno de los apliques lejanos: medido y descartado.**
- **No arregla lo que se buscaba.** Desde un extremo del pasillo solo cuatro apliques más entran en el relleno, y el brillo medio del pasillo sube un 1,5 %. En el cuadro, como se juega, no se distingue de B: los apliques del fondo siguen siendo pantallas encendidas sin luz en la pared. VoxelGI solo da luz rebotada, suave y escasa para una lámpara de este tamaño.
- **Coste:** ninguno relevante, ni siquiera con los 238 apliques de la planta en relleno (prueba `C_all`): todo dentro del ruido entre pasadas.
- **Fugas:** la peor no cambia (0,0359, la misma en B, C y `C_all`). La mediana sube de 0,0085 a 0,0157 en C pero no en `C_all` (0,0089), que es un caso más amplio del mismo cambio, así que parece variación entre pasadas; no se repitió para confirmarlo.
- Como no aporta a la vista, se retiró para no sumar complejidad. Capturas lado a lado en `evidence/abc_capturas.png`.

**Pendiente de revisar, de antes de estos cambios:** la peor fuga del piso actual (tres plantas, 571 salas) es 0,0359 en B, y cuando se fijó el límite de doce apliques era 0,00013 (comentario de `SCONCES_LIT` en `hotel_geometry.gd`, con el piso de entonces). No la causó nada de esto (es igual con y sin relleno), pero conviene buscar qué sala es.

## 10. Equipos modestos: auditoría y preset «Muy bajo»

Octubre de 2026. La pregunta era qué se lleva el fotograma en una gráfica integrada con un procesador de cuatro núcleos, y qué hay que quitar —aunque se note— para sostener 60 FPS ahí. Salen de ella un quinto preset, **Muy bajo**, que cambia el aspecto a propósito, y varios arreglos de procesador que valen para todos los presets. La primera versión de Muy bajo pintaba cada material de un color liso; se veía demasiado mal y duró una tarde: ahora cada material lleva una textura pequeña de sí mismo, que cuesta lo mismo.

### El equipo modesto, simulado

Este PC no tiene gráfica integrada (RTX 4060 Ti, Ryzen 9 5900X), así que se le hace parecer uno peor por los dos lados: `run_bench.ps1 -Modest -Extra '--pixels=9'`.

- **Procesador (`-Modest`).** El juego se queda con cuatro núcleos y un solo hilo en cada uno, y el otro hilo de esos cuatro núcleos se mantiene ocupado. Los dos hilos de un núcleo se lo reparten, así que el juego corre todo el tiempo a más o menos el 60 % de lo que este procesador rinde por hilo, de forma pareja y sin los tirones que daría quitarle tiempo de CPU a ratos: un cuatro núcleos de portátil de hace unos años.
- **Gráfica (`--pixels=N`).** Todo se dibuja con N veces los píxeles de la ventana (la ventana raíz se renderiza a √N veces su lado y se estira de vuelta). Lo que le falta a una integrada es sobre todo relleno de píxeles, y esta tarjeta con nueve veces los píxeles hace de una nueve veces más lenta con los de siempre. Como referencia de cuánto más lenta, la puntuación gráfica de 3DMark Time Spy: unos 13.500 puntos una RTX 4060 Ti, entre 1.250 y 1.800 una Iris Xe de 96 EU según el portátil, unos 390 una UHD 620. Así que **×9 es una Iris Xe corriente, ×16 una floja** (o con la memoria en un solo canal) **y ×36 una UHD 620**.
- **Memoria.** La de vídeo de esta tarjeta no se puede recortar: se mide lo que el juego ocupa, que en una integrada sale de la memoria del sistema.

**Lo que esto no es.** Es un modelo, no una medida. No escala lo que no depende de los píxeles (vértices, mapas de sombra, el trabajo del driver por llamada de dibujo), da por hecho que lo demás escala en proporción, y una integrada comparte con el procesador un ancho de banda de memoria que aquí sobra. Sirve para ordenar los costes y para saber si se está cerca o lejos de los 60 FPS; el número de verdad sigue pendiente de un portátil real (abajo, «Pendiente»).

### Dónde se iba el fotograma

Bajo como se entregaba, caminando, en el equipo modesto simulado con ×9 (`--passes`; GPU en ms):

| Etapa | GPU |
|---|---|
| `post`: glow, escalado, tonemap, FXAA y el lienzo (lente, filtro de cinta, OSD) | 12,7 |
| `opaque`: todas las superficies, sombreadas e iluminadas | 4,6 |
| `camera`: la etapa de la videocámara (iris, rodilla de vídeo) | 0,3 |
| `viewport`: culling, mapas de sombra, prepasada, clústeres de luces | 0,1 |
| **Total** | **17,9** (fotograma de 19,0 ms: 53 FPS) |

Y quitando una cosa cada vez, sobre Bajo con estirado bilineal (9,0 ms; dos pasadas iguales dieron 9,0 y 9,1; aquí sin frenar el procesador, que a la GPU le da igual):

| Qué | Coste en GPU |
|---|---|
| FSR 2.2 frente a estirar sin reconstruir | 8,5 |
| Sombrear las superficies (lo que queda de `opaque` sin sombras, a escala 0,67) | 3,7 |
| Escala 0,67 frente a 0,5 | 2,6 |
| FSR 1 frente a estirar sin reconstruir | 1,8 |
| Filtro de cinta | 1,45 |
| Lente (barril, franjas, entrelazado, ruido del sensor) | 1,2 |
| Sombras de las lámparas, con la escena quieta | 0,8 |
| Glow | 0,6 |
| FXAA | 0,6 |
| OSD | ~0 |

**Lo que se encontró, por lo que pesa:**

1. **Bajo se entregaba con FSR 2.2.** El ajuste de fábrica del escalado era FSR 2.2, y elegir el preset Bajo —o estrenar el juego en una integrada, que empezaba ahí— no lo tocaba: la mitad del fotograma de Bajo era reconstruir la imagen. La tabla de la sección 6 dice «0,67 + FSR 1», y eso solo era verdad con el escalado en «Automático».
2. **El posprocesado pesaba más que la escena.** Sin contar FSR, la cinta y la lente son dos pasadas a pantalla completa y a resolución nativa, con nueve o más lecturas de la imagen por píxel la primera y cinco la segunda, y cada una con su copia del fotograma: 2,6 ms entre las dos, más 1,2 de glow y FXAA.
3. **Las superficies.** Cada material procedural calcula ruido de varias octavas, lee tres mapas escaneados y saca su relieve por derivadas: 3,7 ms de los 4,5 de `opaque`.
4. **Las sombras cuestan poco quietas.** Leerlas son 0,8 ms; dibujarlas, casi nada mientras nada se mueve (sección 1). Lo que cuestan es al moverse —cada lámpara que aparece dibuja sus seis mapas: más de 4.000 llamadas de sombra en un solo fotograma, caminando en Bajo— y, en Compatibilidad, que cada lámpara con sombra es una pasada más sobre todo lo que alumbra: 1.580 llamadas de dibujo por fotograma caminando en Bajo, y 7,8 ms de procesador para enviarlas en el simulado.
5. **`update_visibility()` eran 3 ms cuatro veces por segundo**, en todos los presets (4,6 en Ultra): recorría las 571 salas, 369 puertas y 624 apliques de las tres plantas preguntando a cada nodo dónde estaba, y ordenaba todos los apliques aunque el preset no encendiera ninguno. En el procesador simulado, entre 6 y 9 ms: un fotograma de cada quince con medio presupuesto de 60 FPS gastado.
6. **Un tick de física eran 1,2 ms**, de los que 0,5 eran no hacer nada: el `_physics_process` de 369 puertas y 309 armarios en reposo (0,24 ms), buscar una puerta abierta a la espalda entre las 369 del piso (0,2 ms) y lanzar cinco veces el mismo rayo para saber qué hay bajo la mano.
7. **Memoria de vídeo**, en una partida arrancada en cada preset, a 1080p: Bajo 494 MB, Medio 1.251 MB, Alto 1.982 MB y Ultra 2.182 MB (en Compatibilidad, Bajo 262 MB). De Bajo a Medio saltan FSR 2.2 y los mapas escaneados a 2048; lo que ocupan los modelos (puertas, armarios, muebles, personajes, decals, carteles) son unos 175 MB en todos. La memoria del proceso llega a unos 715 MB en Forward+ y 355 MB en Compatibilidad. Nada de esto aprieta a un portátil de 8 GB en los presets bajos.

### Arreglos para todos los presets

| Cambio | Efecto medido |
|---|---|
| **El escalado de fábrica es «Automático»**, que usa el del preset (clave `upscaler`): bilineal en Muy bajo, FSR 1 en Bajo, FSR 2.2 de Medio en adelante. **Y elegir un preset no toca ni la escala ni el escalado**, que son ajustes del jugador: lo que se elige a mano se queda con cualquier preset (durante unas horas elegir un preset los devolvía a los suyos, y obligaba a volver a poner FSR cada vez). Con FSR 2.2 puesto a mano en Bajo o Muy bajo, Ajustes avisa de lo que cuesta | Bajo en el equipo simulado (×9), caminando: GPU 17,9 → 10,9 ms; fotograma 19,0 → 12,0 ms (53 → 83 FPS) |
| **`update_visibility()` por planta.** Solo se dibuja la planta desde la que se mira: lo de las otras se guarda una vez al cambiar de planta (`put_away()`). Las posiciones se guardan (nada de eso se mueve), y los apliques, las sondas y el rebote no se recorren si el preset no los usa y no queda ninguno encendido | Por llamada: Bajo 3,13 → 0,19 ms; Medio 3,05 → 0,27; Alto 3,36 → 0,49; Ultra 4,61 → 0,79 |
| **Puertas y armarios dormidos.** Una puerta sin nada que esperar apaga su `_physics_process`, y `moving` la despierta; un armario, igual con su temporizador | Tick: −0,24 ms |
| **La puerta a la espalda** se busca entre las de alrededor (`doors_near()`), y lo que hay bajo la mano, con un solo rayo | `drive_local()`: 0,27 → 0,06 ms |
| En total, tick de física (este PC a su velocidad) | 1,19 → 0,70 ms |
| En total, procesador simulado, Bajo o Muy bajo a 1080p: tick · peor `_process` · p99 del fotograma | 1,5 → 0,8 ms · 9,1 → 1,5 ms · 9,8 → 4,5 ms |
| **Las teles no piden sombras de doble paraboloide en Compatibilidad**, que no las tiene y lo decía en el registro por cada tele | Sin errores en el registro |

Bajo y Muy bajo marcan aquí casi el mismo tiempo de fotograma (2,85–2,90 ms, unos 350 FPS) porque los dos chocan con el limitador de fotogramas de este PC («Cómo se mide»): la comparación entre ellos hay que leerla en la GPU. Sin ese tope, por lo que suman el procesador y la GPU, saldrían hacia los 600 FPS; no se midió, porque habría que tocar el limitador.

### Muy bajo

El quinto preset (índice 4 en `graphics_presets.gd`, el primero de la lista en Ajustes). El juego es el mismo; la imagen es, a la vista, otra más barata. Frente a Bajo:

| | Bajo | Muy bajo |
|---|---|---|
| Luz de las lámparas | Con sombra: cada lámpara dibuja sus seis mapas y se leen en cada píxel | **Sin sombra, confinada por sala** (`static_light`): cada lámpara alumbra solo lo que pertenece a su sala. Nada vuelve a dibujarse nunca por una lámpara |
| Linterna | Sombra suave (Soft Very Low), en un atlas de 4096 compartido con las lámparas | Sombra dura, una lectura por píxel, con el primer cuarto de un atlas de 2048 para ella sola: el mismo mapa de 1024 que le tocaba en Bajo |
| Superficies | 2 octavas de ruido, tres mapas escaneados a 1024 y relieve | **Una sola textura pequeña por material** (`surface_detail` 0): lo que el mismo shader dibuja a pleno detalle, fotografiado plano y hecho repetible (`tools/textures/bake_lite_maps.gd`; 512 px para papel, moqueta, baldosa, madera y techos, 128 para telas y metales), algo más oscura hacia las esquinas de la sala. Sin mapas escaneados (ni se cargan), sin ruido, sin relieve |
| Escala de render y escalado con los que se midió (los del jugador mandan) | 0,67 + FSR 1 | 0,5, estirada sin reconstruir |
| Suavizado de bordes | FXAA | Ninguno: lo hace el filtro de cinta |
| Glow | Sí | No |
| Lente | Sí | No (`lens`): la imagen se dibuja recta, y el grano y la viñeta los pone la cinta |
| Filtro de cinta | 9 lecturas por píxel o más | 3 (`tape_lite`): sin suavizado ni realce de luma |
| Umbral de LOD · anisotropía | 4 px · 2× | 8 px · ninguna |
| Lo demás (salas a 56 m, lámparas a 42 m, sin lámparas de muebles, SSAO, niebla, sondas, decals ni polvo; visión de eco) | — | Igual que Bajo |

**Cómo se queda cada lámpara en su sala sin sombra** está en la guía de desarrollo («Luz sin sombras»): dieciséis capas de render repartidas como un mapa coloreado (`room_layers.gd`), las puertas dibujadas en dos mitades y los cuerpos cambiando de capa al cambiar de sala. En 200 semillas ninguna lámpara alcanza otra sala de su misma capa, y nunca hacen falta más de doce. Lo de «iluminación prerenderizada» no puede ser un lightmap: Godot solo los hornea en el editor y un piso se genera al cargarlo. Esto es lo equivalente en coste —una luz que nunca redibuja nada y no lee ninguna sombra— sin hornear nada.

**Lo que cambia a la vista, a sabiendas:**
- Paredes, moqueta, madera y techos tienen su dibujo de siempre —el estampado del papel, los medallones de la alfombra, la veta—, pero pintado: sin relieve, sin brillo que cambie con la textura y, de cerca, borroso. Lo que en los otros presets es azar (una mancha, una zona gastada) aquí se repite cada pocos metros, y la moqueta va sin desgaste para que no se repita la misma mancha. Puertas, muebles y personas conservan sus texturas.
- En una sala iluminada nada le hace sombra a nada: el suelo bajo una mesa está tan iluminado como la mesa, y el interior de un armario abierto, como la sala.
- **Por una puerta abierta no entra luz.** Una sala a oscuras es negra del todo aunque la de al lado esté encendida y la puerta abierta; la sala encendida se ve por el hueco, pero no alumbra el suelo de este lado. La hoja abierta sí recibe la luz de las dos.
- La imagen es más blanda y con bordes de sierra (media resolución, sin suavizado), y no tiene la curvatura de la lente.

**Lo que no cambia** (y se comprobó):
- **Las salas a oscuras son negras** y ninguna lámpara alumbra la sala de al lado: `light_leak.gd --quality=4`, en las 40 primeras salas a oscuras de la semilla 81, no encuentra nada en ninguna habitación cerrada, ni en Forward+ ni en Compatibilidad. (Las dos que marca, la 57 y la 101, son tramos de pasillo apagados y abiertos a uno encendido: las marca igual en Bajo, y es la luz haciendo su trabajo.)
- La linterna proyecta sombra y no atraviesa puertas ni paredes.
- Números de puerta, rótulos de salida, el faro rojo, las teles, el apagón y el parpadeo de los fluorescentes.
- La criatura en una sala a oscuras no se ve desde la de al lado: los cuerpos solo reciben la luz de la sala en la que están (`preset_tour.gd`, tomas `criatura_*`).
- La visión de eco de The Locust es la de Bajo.

### Medidas

Cada preset en su propia pasada (una partida arrancada en él), semilla 81. Tiempos en ms.

**Este PC** (RTX 4060 Ti, Ryzen 9 5900X), 1080p, Forward+, sin límite de FPS:

| Preset | GPU caminando | Fotograma caminando (media · p99) | GPU quieto (sala intermedia) | Llamadas de dibujo · de sombra, caminando | Memoria de vídeo | Carga del piso |
|---|---|---|---|---|---|---|
| **Muy bajo** | 0,52 | 2,85 · 4,04 | 0,48 | 156 · 0 | 359 MB | 10,1 s |
| Bajo | 1,36 | 2,90 · 4,80 | 1,28 | 154 · 65 | 494 MB | 10,4 s |
| Medio | 4,68 | 5,77 · 7,44 | 3,81 | 177 · 1.066 | 1.251 MB | 13,0 s |
| Alto | 9,87 | 11,10 · 14,37 | 7,82 | 178 · 1.898 | 1.982 MB | 13,9 s |
| Ultra | 14,58 | 15,83 · 20,23 | 12,31 | 200 · 1.944 | 2.182 MB | 14,0 s |

En Compatibilidad, aquí mismo: Bajo 3,01 ms de GPU, 5,53 de fotograma y 1.169 llamadas de dibujo, con 262 MB de vídeo; Muy bajo 1,14 ms, 3,19 y 189, con 211 MB. De Bajo a Muy bajo la GPU baja a algo más de un tercio en los dos renderizadores; el fotograma de Forward+ no se mueve en este PC porque los dos están en el tope de 350 FPS.

**Equipo modesto simulado** (`-Modest`, cuatro núcleos al 60 %, y la gráfica en ×N), caminando:

| Preset y renderizador | Gráfica | GPU | Fotograma: media · p99 · máximo | FPS (media) |
|---|---|---|---|---|
| Medio, Forward+ | ×9 (Iris Xe) | 36,9 | 38,1 · 43,2 · 44,0 | 26 |
| Bajo como se entregaba (FSR 2.2), Forward+ | ×9 | 17,9 | 19,0 · 23,0 · 23,8 | 53 |
| Bajo (FSR 1), Forward+ | ×9 | 10,9 | 12,0 · 13,6 · 13,7 | 83 |
| **Muy bajo, Forward+** | ×9 | **2,99** | **4,17 · 6,4 · 7,2** | **240** |
| Bajo, Compatibilidad | ×9 | 16,1 | 16,7 · 20,6 · 21,8 | 60 |
| **Muy bajo, Compatibilidad** | ×9 | **3,77** | **4,70 · 7,1 · 7,2** | **213** |
| Bajo, Forward+ | ×16 (Iris Xe floja) | 19,5 | 20,8 · 23,6 · 23,8 | 48 |
| **Muy bajo, Forward+** | ×16 | **5,20** | **6,43 · 8,1 · 8,4** | **156** |
| **Muy bajo, Forward+** | ×36 (UHD 620) | **11,2** | **12,6 · 14,8 · 15,5** | **79** |
| Muy bajo con FSR 2.2 al 67 % puesto a mano, Forward+ | ×9 | 11,4 | 12,5 · 14,3 · 14,5 | 80 |

- **Muy bajo cuesta una cuarta parte de lo que Bajo en la GPU** (y una sexta de Bajo como se entregaba), en los dos renderizadores. En el modelo sostiene 60 FPS con margen hasta en ×36; aunque una integrada de verdad rinda la mitad de lo que el modelo dice, en ×9 y ×16 sigue por encima (y en ×9, aunque rinda la tercera parte).
- **Por etapas**, Muy bajo en ×9: `post` 1,69 ms (estirar, tonemap y el filtro de cinta ligero), `opaque` 0,97, `camera` 0,20, `viewport` 0,09. En ×36: 6,0, 4,3, 0,7 y 0,26.
- **En Compatibilidad** quitar las sombras quita también las pasadas: las llamadas de dibujo caminando bajan de 1.582 a 184 y el procesador para enviarlas, de 7,8 a 3,2 ms. Forward+ sale más rápido que Compatibilidad en el modelo también en Muy bajo (2,99 frente a 3,77 ms), pero eso es esta tarjeta y su driver: qué renderizador conviene en una integrada sigue sin medir.
- **El procesador ya no es el límite.** En el simulado, a 1080p, un fotograma de Muy bajo a 60 FPS son 0,8 ms de tick, 0,4 de `_process` y alrededor de 1 de preparar el render: unos 2,3 ms de 16,7, sin criatura ni sonido (el benchmark corre con `--no-enemy --silent`). El peor fotograma al llegar a salas nunca vistas son unos 23 ms, igual en Bajo que en Muy bajo.
- **Las texturas pequeñas no cuestan nada medible** frente al color liso de la primera versión (en ×9, 2,89 → 2,95 ms de GPU, dentro del ruido), y tampoco lo costaba leer las de los modelos dos mipmaps más abajo, que se probó y se quitó (2,90 frente a 2,89 ms). Son 4 MB de vídeo.
- **Con FSR 2.2 al 67 % puesto a mano**, Muy bajo en ×9 son 11,4 ms de GPU y 12,5 de fotograma (80 FPS) en lugar de 2,99 y 4,17: la reconstrucción sola pesa casi el triple que todo lo demás.
- **Fugas de luz en Muy bajo:** ninguna en habitaciones cerradas (arriba, «Lo que no cambia»). **Capas:** `light_layers_scan.gd` sobre 200 semillas, 0 lámparas que alcancen otra sala de su capa, 0 vecinos abiertos sin alumbrar, 12 capas como mucho y 56 ms el reparto más lento.
- **Capturas:** `evidence/tour_q4_*.png` (`preset_tour.gd`), `evidence/bench/g_n_q4_forward_plus/` y la hoja de los cinco presets, `evidence/bench/muybajo_forward_plus/sheet_*.png`.

### Pendiente

- **Medirlo en una integrada de verdad.** Todo lo de arriba sale de un modelo; lo que diga un portátil con una Iris Xe o una Vega manda sobre él, y dirá también qué renderizador conviene ahí. El primer arranque en una gráfica integrada ya elige Muy bajo; si sobra, lo siguiente es Bajo, que ahora usa FSR 1.
- **La sonda de atascos de la criatura** (`verify.ps1`) no termina en sus cinco minutos (tarda unos nueve) y deja 4 de 12 trayectos sin acabar. Pasa igual sin ninguno de estos cambios (medido en el commit anterior), así que viene de antes y no se ha tocado; mientras siga así, `verify.ps1` se para ahí y no llega a los bots, los shaders ni la red, que se pasaron aparte.
- **El papel pintado de las plantas de abajo.** El shader completo calcula la mugre del zócalo y las manchas de humedad con la altura en el mundo, no sobre el suelo de la sala, así que en la segunda y la tercera planta (a −6 y −12 m) todo el paño tiene que salir con la mugre del zócalo y sin manchas arriba (leído en `wallpaper.gdshader`; no se comparó en capturas). La textura de Muy bajo se mide desde el suelo de cada sala y sale como en la primera planta en las tres. No se ha tocado el shader completo: puede que ese deterioro de abajo guste como está.
- **El interruptor «Sombras»** de los otros presets sigue dejando a las lámparas atravesar paredes cuando se apaga. Las capas de Muy bajo servirían también ahí; no se ha hecho. (En Ultra, que desde la sección 11 usa las capas, las lámparas de techo sí quedan confinadas a su sala al apagarlo; los apliques se apagan, como siempre.)
- Si en una integrada real pesara el número de llamadas de dibujo, lo siguiente a mirar es `room_reach` (56 m en los dos presets bajos): en este PC, bajarlo a 40 m o quitar la oclusión no movió nada.

## 11. Ultra: que se distinga de Alto

*Octubre de 2026. La queja: Ultra costaba un tercio más que Alto (de ~80 a ~55 FPS en el equipo del autor) y no se veía la diferencia.*

### Qué pagaba Ultra y qué se veía

Medido a 1080p en el paseo del benchmark, efecto a efecto (`--set`), y comparando la misma vista píxel a píxel con y sin cada uno:

| Lo que Ultra tenía sobre Alto | ms de GPU | Píxeles que cambian en una captura |
|---|---|---|
| Soft High y penumbra ×2,5 | 3,44 | 0,7–3 % (la penumbra; el filtro en sí, nada) |
| Rebote a resolución completa | ~0,5 | no se aprecia |
| Niebla 96³ | 0,52 | 0,00–0,04 % |
| Motion blur 12, polvo 140, anisotropía 16× | 0,46 | 0,00–0,04 % |
| MSAA 4× | 0,42 | 0,00–0,04 % |
| SSAO High a resolución completa | 0,34 | 0,00–0,04 % |
| SSIL High | 0,21 | 0,00–0,04 % |
| SSR 64 pasos | 0,05 | 0,00–0,04 % |
| Lámparas y salas más lejos | ~0 | — |

De los 5,3 ms que Ultra costaba de más, lo único que cambiaba la imagen era la penumbra ancha de las sombras. El resto eran los mismos efectos de Alto con más muestras, y además **el filtro de cinta se come el detalle fino**: lo que sobrevive a la cinta son cosas grandes —qué lámparas alumbran, dónde hay un brillo, qué está en sombra—, no la nitidez de una textura. Los materiales ya son escaneos de 2048 px por un par de metros de pared: más resolución de textura no se vería.

### Lo que Ultra tiene ahora y los demás no

Todo detrás de claves que solo Ultra enciende (`graphics_presets.gd`); ningún otro preset cambia de imagen ni de coste.

- **Los apliques lejanos alumbran** (`sconce_fill`). Solo los doce apliques más cercanos pueden tener sombra (más no caben en el atlas), y uno sin sombra atravesaba la pared, así que los demás estaban apagados: un vestíbulo grande tenía dieciséis apliques y doce encendidos. Ahora los que quedan fuera, hasta 40 m, alumbran su pared sin sombra y confinados a su sala por las capas de render que Muy bajo ya usaba (sección 10). Es lo que más se nota: una recepción o un salón con todas sus luces de pared.
- **Lámparas de techo con sombra, contadas** (`lamps_cast`: 20). Ver abajo, «El atlas desbordado»: arregla una fuga y abarata.
- **Cuadros tras un cristal** (`glazed_art`): una capa transparente sobre el lienzo en la que se ve el aplique de al lado y la linterna, y que a ras refleja la sala en vez de dejar ver el cuadro.
- **Barniz en capa propia** sobre la madera (`surface_detail` 5): un segundo brillo, más fino, encima del de la veta, que desaparece donde el barniz está gastado o rayado. En un shader aparte (`wood_lacquer.gdshader`, mismo cuerpo que `wood.gdshader`): un shader que escribe `CLEARCOAT` paga ese segundo brillo por cada lámpara y cada píxel aunque escriba cero, y así los demás presets no lo pagan.
- **Superficies que no son planos dibujados** (`surface_detail` 5, `finest_surface()`): paredes y techos con la panza de unos milímetros que tiene cualquier pared empapelada o techo de yeso, que solo se ve donde una lámpara los roza (`plane_swell()`); cada baldosa asentada con su propia inclinación, de modo que el reflejo del fluorescente en un suelo de baño se rompe pieza a pieza; y el pelo de la moqueta tumbado hacia un lado u otro, más oscuro mirado a contrapelo, con manchas que se mueven al caminar.
- **Oclusión que oscurece también la luz de las lámparas** (`ssao_shape`): casi toda la luz de una sala es de sus lámparas, y con la oclusión actuando solo sobre la luz ambiente los encuentros —pared y techo, zócalo, las patas de una silla— quedaban tan claros como el paño abierto. Radio más corto (0,7 m) para que oscurezca rincones y no pasillos enteros.
- **Filtro de sombras Soft Medium** en vez de Soft High, con la misma penumbra ×2,5. En capturas quietas las dos son iguales (0,0–1 % de píxeles, y ese 1 % era otra cosa); en un paneo, con poco historial de TAA, tampoco se distinguen, y el ruido entre fotogramas es menor con Medium (`evidence/lookdev/grain_*`). Son 2,3 ms que pagan todo lo anterior.

### El atlas desbordado (venía de antes)

`light_leak.gd --quality=3` daba luz en una sala a oscuras con las puertas cerradas (la 70 de la semilla 81: 0,012 de media) en unas pasadas sí y en otras no, y solo en Ultra. Cada lámpara con sombra a la vista pide sitio en el atlas de sombras, que tiene 88 huecos y da dos a cada lámpara redonda; con el alcance de Ultra (64 m) había en ese piso hasta 63 lámparas de techo encendidas a la vez, más los doce apliques y las de mueble, y **a la que no le toca hueco Godot la dibuja sin sombra, a través de las paredes**. En una sala quieta, donde nada se mueve y ninguna sombra tendría que redibujarse, Ultra hacía ~1100 llamadas de sombra por fotograma: lo que encaja con lámparas quitándose el hueco unas a otras.

Ahora en Ultra solo proyectan sombra las 20 lámparas de techo más cercanas; las demás, que están a decenas de metros, alumbran sin sombra y solo las capas de su sala (`cast_or_fill()`). La sala 70 mide 0,00000 en todas las pasadas, las llamadas de sombra en la sala quieta son 0, y las salas que siguen saliendo en la lista (22, 23, 15, 16, 57, 62) son las mismas y con los mismos valores que en Alto: celdas de pasillo a oscuras abiertas a otras iluminadas, que es luz que entra por donde debe. **Alto y Medio no se han tocado.** Alto llega a ~43 lámparas de techo encendidas en ese piso y en la misma prueba no dio fuga, pero también redibuja sombras sin parar en la sala quieta (360–850 llamadas por fotograma). Probado sin dejarlo puesto (`--set=lamps_cast:20` sobre Alto): 0 llamadas, el trabajo de render en CPU baja de 1,66 a 0,96 ms y el fotograma de 9,31 a 8,84 ms en esa sala; caminando no cambia. No se ha aplicado porque cambia cómo se dibuja Alto (puertas en mitades, lámparas lejanas sin sombra) y nadie lo había pedido; es una clave en la tabla.

### Medidas

1080p, Forward+, RTX 4060 Ti, el mismo benchmark de las secciones anteriores (semilla 81). El ruido entre pasadas es de ±0,2 ms.

| | Alto | Ultra antes | Ultra ahora |
|---|---|---|---|
| GPU caminando | 9,6–10,0 ms | 14,5 ms | 12,3–12,5 ms |
| Fotograma caminando | 10,9–11,4 ms | 15,8 ms | 13,7–14,2 ms |
| GPU en la sala quieta | 7,8–8,2 ms | 12,8 ms | 10,2–10,7 ms |
| Llamadas de sombra en la sala quieta | ~360–850 | ~1090 | 0 |
| Memoria de vídeo | 1982 MB | 2182 MB | 2131 MB |

Ultra cuesta ahora un 14 % menos de GPU que antes con todo lo nuevo dentro. **Quedan sin gastar unos 2 ms para igualar al Ultra anterior y unos 4 para el 15 % de más que se había dado de margen**: no se han gastado porque lo que queda por hacer no es de este tipo (abajo). Medio (4,68 ms) y Alto miden lo mismo que antes del cambio.

Capturas: `evidence/lookdev/ultra_antes_despues_vhs.png` (como se juega) y `_raw.png` (sin cámara), Alto / Ultra antes / Ultra ahora en cinco vistas; `tools/capture/lookdev_capture.gd` acepta ahora `--set=clave:valor` y `--only=vista,...`.

### Lo que se probó y se descartó

- **Estampado satinado en el papel pintado** (bajar la rugosidad del motivo): por debajo de ~0,6 de rugosidad el SSR toma la pared por un espejo y la llena de un moteado en bloques. Fuera.
- **Capa transparente afilada.** La de Godot es un espejo en 0 y sigue siendo un pulido en 1, y dibuja el disco entero de la lámpara al máximo del lóbulo: con 0,06 el aplique salía en el cristal a muchas veces su brillo, el iris automático de la cámara se cerraba y todo el pasillo perdía un 19 % de luz. Cristal y barniz van en 1 y 0,6–1.
- **Oclusión de radio largo** (1,7 m): oscurecía pasillos enteros, no rincones.
- **Más resolución de textura, MSAA, SSR, SSIL o niebla más finos:** es lo que Ultra ya tenía y no se veía.

### Pendiente: de dónde saldría el salto grande

Con la misma geometría, las mismas lámparas y la cinta encima, lo de arriba es más o menos lo que hay que rascar en luz y materiales. Lo que separa estas salas de una foto es **geometría de detalle**: las paredes se encuentran con el techo y el suelo en una arista recta, sin cornisa ni rodapié con perfil; no hay interruptores, enchufes, rejillas, rociadores ni rosetones de techo; los paneles del friso son un dibujo sobre una tabla lisa. Es la fase 6 de [REALISM.md](REALISM.md) (kit de molduras y detalles), que no está aprobada ni empezada, y es donde irían los ~4 ms que sobran. Parte se puede generar (perfiles extruidos a lo largo de cada pared) y parte son modelos CC0.
