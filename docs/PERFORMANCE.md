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
| Filtro por preset | `SHADOW_FILTER` en `hotel_main.gd`: Baja Soft Very Low, Media Soft Low, Alta Soft Medium | GPU caminando: Baja 2,38 → 1,65 ms; Media 3,76 → 3,36 ms |
| CPU | Direcciones de eco bajo demanda; rutas de sonido sin búsqueda más allá de `ROUTE_LIMIT + ROUTE_SLACK`; cápsula solo al cambiar | Del orden de 1,3–7,4 ms por chasquido a unos 0,1 ms por tick |

## 3. Recomendaciones que no se aplicaron

- **Competencia en el atlas de sombras.**
  - En Media (atlas de 4096) y en algunas vistas, varias luces se disputan los huecos grandes y se redibujan en cada fotograma. En la sala 36 quedan unas 800 llamadas de sombra por fotograma.
  - Cambiar las subdivisiones de los cuadrantes lo evita en esa vista, pero cambia qué resolución recibe cada sombra.
  - Hay que probarlo con capturas A/B: `run_bench.ps1 -Extra '--atlas-quads=2,3,4,4'`.
- **MSAA 2× en Media y Alta.** Es redundante con TAA en Alta y con el emborronado VHS. Necesita comparación A/B.
- **Sombra del jugador local.** `shadow_caster_mask` evitaría que sus lámparas vecinas se redibujen al caminar, pero se perdería su propia sombra.
- **Sombras omni dual-paraboloid: descartadas.** Deforman las cajas grandes de pocos polígonos y abrirían fugas de luz.
- **Niebla volumétrica y SSIL a menor resolución.** Cambian el haz de la linterna y el rebote.
- **LOD en la hoja y el marco de puerta.** Se dejaron fuera a propósito, porque sellan la luz.
- **Sombra del avatar en una sola superficie.** Son 14 llamadas por pasada de sombra al caminar. Queda como mejora opcional; los LOD ya reducen sus triángulos.
- **Texturas ORM** (oclusión, rugosidad y metal empaquetados) para puertas, armario y aplique. Requiere rehacer los materiales.
- **Exploradora.**
  - `size_limit` 1024.
  - Quitar sus 50 MB de blend shapes, que no se usan.
  - `model_38`/`40` y `model_41`/`43` son idénticas.
- **Unos 111 MB de texturas no usadas en el PCK.** Solo afecta al tamaño del ejecutable, no al rendimiento. Reimportar un FBX vuelve a extraerlas.
- **Grietas de la tele en la entrada.** `crack_pattern.gd` pinta píxel a píxel, con un tirón estimado de 50–300 ms en cada golpe. Se podría precalcular o mover a un hilo.
- **CPU menor.**
  - `FLOOR.room_at` recorre todas las salas tres veces por tick.
  - `_physics_process` de puertas y armarios corre en reposo.
  - El OSD se repinta en cada fotograma.
  - El subtítulo se reescribe en cada fotograma.
- **FSR 1** cuando la escala 3D sea menor que 1.

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
   - los tres presets.
7. `./tools/godot.ps1 locust -Seed 81` y `rehearsal`: la visión de eco sin tirones al chasquear.
8. Repetir el benchmark en un PC modesto y anotar sus cifras aquí.
