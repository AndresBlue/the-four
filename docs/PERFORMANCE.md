# Rendimiento gráfico — auditoría de septiembre de 2026

Auditoría técnica de GPU, CPU, VRAM, llamadas de dibujo, sombras, geometría y texturas del hotel (Forward+), con cambios medidos uno a uno. El aspecto se mantiene; la única excepción deliberada es un error de colocación de cuadros y apliques, que se corrigió (punto 11). Cada cambio está en su propio commit.

## Cómo se mide

`./tools/benchmarks/run_bench.ps1 -Label nombre` ejecuta `tools/benchmarks/hotel_benchmark.gd` a 1080p con la semilla 81 y deja `evidence/bench/<nombre>_<renderizador>/report.json`, más capturas de cada vista y calidad. Hay dos capturas por vista: `_raw` sin filtro de cinta, para comparar píxeles, y `_vhs`, tal como se juega. El faro y los fluorescentes quedan congelados encendidos en ambas.

Cada vista mide, por calidad:
- tiempo de fotograma (media, p95, p99 y máximo), de GPU y del hilo de render;
- llamadas de dibujo y primitivas, visibles y de sombra;
- VRAM.

Hay tres vistas quietas (recepción, sala 36 y salida) y un **tramo caminando** por la ruta desde la recepción, que reproduce los redibujados de sombra de una partida real. La medición espera 1,5 s antes de empezar: el atlas de sombras recoloca las luces 0,5 s después de asignarlas.

Herramientas relacionadas:
- `./tools/benchmarks/bench_table.ps1 base,final` pone dos informes en tabla.
- `tools/benchmarks/compare_captures.gd` compara dos juegos de capturas: da la diferencia media y máxima y el porcentaje de píxeles que cambian, y escribe una imagen de diferencias.
- `-Compatibility` mide con el otro renderizador; `-Extra '--shadow-filter=N'` o `'--atlas-quads=a,b,c,d'` sirven para pruebas A/B.
- `-Extra '--qualities=0,3'` mide solo esos presets y `'--set=clave:valor,...'` fuerza valores de `graphics_presets.gd` sobre todos, para medir un efecto solo (sección 6).
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
- En Baja el fotograma se queda en unos 2,9 ms aunque la GPU baje: ahí el límite ya no es el render.

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
4. `darkness_capture.gd`, `doors_capture.gd`, `rooms_capture.gd`, `props_capture.gd`, `echo_capture.gd` (con `--automation`) y `tools/avatars/capture.gd`.
5. `run_bench.ps1 -Compatibility`.
6. Partida con `./tools/godot.ps1 playtest -Seed 81`:
   - pasillos con apliques, salas oscuras con puertas cerradas, linterna;
   - un armario y una persecución;
   - los cuatro presets.
7. `./tools/godot.ps1 locust -Seed 81` y `rehearsal`: la visión de eco sin tirones al chasquear.
8. Repetir el benchmark en un PC modesto y anotar sus cifras aquí.

## 6. Presets gráficos: Bajo, Medio, Alto y Ultra

Los tres niveles de calidad (Baja, Media, Alta) apenas se distinguían, y nada estaba pensado para gráficas integradas. Ahora hay cuatro presets con diferencias claras y acumulativas. Todo lo que cambia con la calidad está en una tabla, `game/presentation/graphics_presets.gd`, y ningún otro archivo guarda valores por calidad. La calidad guardada 0–2 conserva su significado (Bajo, Medio, Alto) y 3 es Ultra. Elegir un preset fija también su escala de render; el deslizador sigue libre.

### Qué cambia

| Parámetro | Bajo | Medio | Alto | Ultra |
|---|---|---|---|---|
| Escala de render | 0,67 + FSR 1 | 0,85 + FSR 1 | 1,0 | 1,0 |
| Antialiasing | FXAA | TAA | TAA + MSAA 2× | TAA + MSAA 4× |
| AA especular (limitador de rugosidad) | no | sí | sí | sí |
| Atlas de sombras | 4096 | 4096 | 8192 | 8192 |
| Filtro de sombras | Soft Very Low | Soft Low | Soft Medium | Soft High |
| Penumbra (tamaño de la fuente, PCSS) | ninguna (PCF simple) | la de siempre | la de siempre | ×2,5, como la cúpula esmerilada |
| Alcance de las lámparas (luz y sombra) | 42 m | 42 m | 48 m | 64 m |
| Salas dibujadas | 56 m | 66 m | 66 m | 82 m |
| Lámparas de muebles | apagadas | hasta 28 m | hasta 32 m | hasta 40 m |
| Sombra del cuerpo propio | no | sí | sí | sí |
| SSAO | no | Low, media resolución | Medium, media resolución | High, resolución completa |
| SSIL | no | no | Medium, media resolución | High, media resolución |
| Reflejos SSR | no | no | 32 pasos, rugosidad Low | 64 pasos, rugosidad High |
| Sondas de reflexión | no | 1 de cada 3 vestíbulos | todas las salas iluminadas, con sombras | igual que Alto |
| Rebote de luz (un VoxelGI por sala iluminada) | no | no | sí, media resolución | sí, resolución completa |
| Apliques que iluminan (con sombra) | no | no | sí, hasta 24 m | igual que Alto |
| Lámparas en la niebla volumétrica (niebla de 14 m) | no | sí | sí | sí |
| Niebla volumétrica | no | 48³ | 64³ | 96³ |
| Neblina de suelo en vestíbulos | no | no | sí | sí |
| Glow | sí | sí | sí, subida bicúbica | igual que Alto |
| Debanding | no | no | sí | sí |
| Polvo (partículas) | no | 60 | 90 | 140 |
| Detalle de superficies | 2 octavas, sin microdetalle | 3 octavas | 4 octavas | 4 octavas |
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
- **Sombras de las lámparas.** Toda lámpara visible conserva su sombra en todos los presets. Una lámpara sin sombra atraviesa paredes y puertas cerradas, así que la sombra se abarata (filtro, penumbra, cuerpo propio), nunca se quita. Por la misma razón el atlas no baja de 4096: con celdas más bastas, el sesgo crece más que el grosor de una hoja de puerta.
- **Luz ambiente cero y niebla casi negra.** Las salas oscuras son negras en todos los presets.
- **Números de puerta y rótulos (20 m), faro rojo, sellos de puerta y salas oscuras.** Son gameplay y orientación.
- **Filtro VHS.** Sus deslizadores y «Efectos reducidos» son ajustes del jugador.
- **GI.** SDFGI deja pasar luz por muros de 18 cm y los lightmaps no se hornean en partida. Desde Alto, el rebote es un VoxelGI por sala, horneado en hilos al cargar el piso ([REALISM.md](REALISM.md), prueba 8), más SSIL. Solo los 8 volúmenes que se dibujan tienen sus datos: con datos, un volumen ocupa unos 56 MB de vídeo aunque esté oculto, y los 51 de un piso llegaban a 2,9 GB.
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

- **Bajo:** unos 350 FPS en este PC, pero limitado por la CPU (lógica del juego, audio, IA): la GPU solo trabaja 0,74 ms.
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
2. **Filtrado de sombras.** Soft High es lo más caro de Ultra (un 18 % de su GPU), y solo compensa porque su penumbra es ancha.
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
- **Primer arranque con gráfica integrada** (`RenderingServer.get_video_adapter_type()`): el juego empieza en Bajo y el menú sugiere Compatibilidad.
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
