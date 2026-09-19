# Fotorrealismo: el hotel real visto por una camcorder de 1988

Plan en curso para que la imagen se acerque a Lost Fragment, Paranormal Tales, Silent Breath o Dreamcore. Aquí se anotan las decisiones, los resultados de cada prueba y los hitos. El rendimiento de cada paso va en [PERFORMANCE.md](PERFORMANCE.md) y los assets en [ASSETS.md](ASSETS.md).

**Dirección:** la escena debajo es fotorrealista y la cámara la graba como una camcorder real (lente, sensor CCD, procesado y cinta), no como un velo encima.

**Fuera de alcance:** supervivientes y criatura (otro plan).

**Rendimiento:** Alto a 60 FPS en una RTX 4060 Ti a 1080p. Bajo rinde como hoy.

**Assets:** CC0, CC-BY con créditos, y Fab/Megascans y Mixamo gratis.

**Orden por impacto:**
1. banco de pruebas;
2. cámara;
3. luz;
4. materiales;
5. ambientación y mobiliario;
6. kit de geometría.

## Punto de partida (antes del plan)

- **Arquitectura:** cajas y cilindros unitarios sin bisel ni UV. Materiales 100 % procedurales; `assets/textures/` está vacío.
- **Mobiliario:** 6 modelos reales y 4 huecos por sala.
- **Ambientación:** sin decals, objetos sueltos ni señales físicas.
- **Luz:** una omni centrada por sala y sin rebote.
- **Cámara:** 78° verticales en rectilíneo, sin exposición, lente, motion blur ni enfoque; el VHS es un velo 2D.

## Banco de pruebas (fase 0)

- `tools/capture/lookdev_capture.gd` toma siete vistas fijas del piso de la semilla 81, a 1920 × 1080:
  - recepción, dormitorio, salón, pasillo, baño, servicio, y sala oscura con linterna;
  - cada una en `_raw` (sin cinta ni OSD) y `_vhs`;
  - resultado en `evidence/lookdev/<etiqueta>_q<preset>/`;
  - `--setup=script.gd` modifica el piso antes de las tomas, para probar una idea sin tocar el juego.
- `tools/capture/lookdev_sheet.gd` compone la hoja: una carpeta en cuadrícula, o varias columnas lado a lado (antes/después, ahora/referencia).
- **Base:** `evidence/lookdev/base_q2` (Alto).
- **Referencias:** tus capturas de los juegos de referencia van en `evidence/reference/`, sin versionar.

## Pruebas de riesgo

### 1. Orden del compositor frente a TAA — resuelta

Prueba: un `CompositorEffect` en `POST_TRANSPARENT` pinta ruido distinto en cada fotograma. Varianza de la zona con ruido:

| Configuración | Varianza |
|---|---|
| Sin AA | 0,0345 |
| TAA | 0,0006 |
| MSAA 2× | 0,0352 |
| FSR2 | 0,0103 |

- **El callback corre antes de la resolución de TAA y FSR2.**
- **El búfer de velocidad existe siempre** con `needs_motion_vectors`, también sin TAA.

Consecuencias para la cámara:
- **En HDR (compositor, antes de TAA):** lo que es estable por píxel. Es decir, exposición, curva de vídeo, balance de blancos, halo, smear de CCD y motion blur.
- **En el lienzo (después de TAA y tonemap):** lo que TAA emborronaría o cuya reproyección rompería. Es decir, distorsión de lente, aberración lateral, viñeteado, ruido del sensor y realce de bordes. Va en una capa propia por debajo del OSD, porque la óptica no deforma el OSD pero la cinta sí lo graba.
- **La ganancia medida en la GPU** llega al ruido del lienzo con `buffer_get_data_async`, que está disponible, igual que `texture_copy`, `get_velocity_layer`, `get_depth_layer` y las matrices de cámara.

### 3. Sonda por sala como luz ambiente — funciona, rebote débil

Prueba: una `ReflectionProbe` interior por sala iluminada (97 en la semilla 81), del tamaño de la sala, con `ambient_mode = ENVIRONMENT`, una actualización y sombras.

- **Efecto:** levanta las sombras de las salas iluminadas (el interior del armario y la mesa de servicio dejan de ser negros). La sala oscura no cambia.
- **Medida sin cinta:** brillo medio +1 a +1,5 de 255 y 1–3 puntos menos de píxeles negros. Subir `intensity` a 3 casi no cambia la luz ambiente, sobre todo el reflejo.
- **Sin fugas:** con puerta cerrada, la sala oscura contigua da en los cuatro presets lo mismo que sin sondas, 0,6–0,8 de 255.
- **Conclusión:** es un rebote plausible y confinado a la sala. Su fuerza real la dará la exposición de la cámara (fase 1). Si hace falta más relleno, el modo `COLOR` permite fijarlo por sala.
- **Aviso:** 97 sondas superan las 64 plazas del atlas de reflejos (`rendering/reflections/reflection_atlas/reflection_count`); en el piso solo se ven las cercanas, pero hay que medirlo.

### 4. Luz de los apliques y perfiles IES — funciona con sombra

Prueba: una `OmniLight3D` por aplique en las salas iluminadas (32 en la semilla 81), con un proyector equirectangular. La mitad trasera (el muro) va en negro y la delantera lleva un cono hacia arriba y otro hacia abajo.

| Variante | Resultado |
|---|---|
| Sin proyector y sin sombra | Lava la pared de luz y el pasillo gana muchísimo, pero atraviesa el muro hacia la sala vecina |
| Proyector sin sombra | No ilumina nada: **un proyector de omni necesita `shadow_enabled`** |
| Proyector con sombra | Conos arriba y abajo en la pared y sombra del propio brazo del aplique, como un perfil IES real. La sombra impide además la fuga |
| Foco de 89° metido 3 cm en el muro | Apenas ilumina (la pared queda en rasante) |

- **En el proyector, el frente (hacia la sala) es −Z local de la luz.**
- **Adoptado para la fase 2:** proyector con sombra, en Alto y Ultra; en Bajo y Medio el aplique queda emisivo. Los perfiles se generarán desde archivos IES (`tools/lighting/ies_to_projector.gd`).

### 7. Niebla volumétrica iluminada por las lámparas — funciona

Prueba: `volumetric_fog_length` de 14 m (antes 48) y `light_volumetric_fog_energy` 1 en las lámparas de techo.

- **Efecto:** una bruma suave en el aire de las salas iluminadas. Brillo medio +2 a +3 de 255 y un 5–6 % menos de píxeles negros. La sala oscura, igual.
- **Sin fugas:** los cuatro presets dan lo mismo que sin niebla. Con celdas más cortas, el resplandor ya no cruza el muro.
- **Pendiente:** la linterna también ilumina la niebla solo hasta 14 m; se juzgará en la fase 2.

### Pruebas que se hacen al empezar su fase

- **5. Decals** (límite de elementos agrupados, atlas): fase 4.
- **6. Bisel en shader:** fase 5.
- **8. VoxelGI por sala frente a las sondas:** fase 2.
