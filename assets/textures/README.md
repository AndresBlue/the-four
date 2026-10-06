# Materiales escaneados

Cada carpeta es un set escaneado (fase 3 de `docs/REALISM.md`), generado por `tools/textures/ingest_pbr.py` a partir de las descargas en `source_assets/textures/` (fuera de git):

```
assets/textures/<set>/albedo.jpg    color (sRGB)
assets/textures/<set>/normal.jpg    normal map, convención OpenGL (verde hacia arriba)
assets/textures/<set>/orm.jpg       oclusión, rugosidad y metal en R, G y B
assets/textures/<set>/*_1k.jpg      lo mismo a 1024 px, para el preset Bajo (small_maps)
```

`assets/textures/lite/` no es un set escaneado: son las texturas pequeñas con las que el preset Muy bajo dibuja cada material (una por material de `hotel_geometry.MATERIALS`, más `lite.json` con los metros que cubre cada una). Las genera `tools/textures/bake_lite_maps.gd` a partir de estos mismos sets y de los shaders, así que no se editan a mano: se vuelven a hornear.

Un material usa un set con el metadato `scan` de su `.tres` en `game/presentation/materials/` (Inspector → Metadata). `hotel_geometry.apply_scan()` le asigna los mapas al construir. Los parámetros del grupo `image_maps` deciden cómo se combina con el shader:

- **`map_mode`:**
  - `Replace`: el escaneo por `map_tint`;
  - `Recolour`: `map_tint`, aclarado y oscurecido como el escaneo;
  - `Detail`: el color procedural, variado por el escaneo (moqueta, papel pintado y techo).
- **`map_metres`:** tamaño real de una repetición.
- **`map_roughness` y `map_metallic`:** ajuste de la rugosidad y del metal del ORM.
- **`normal_strength`:** relieve del escaneo.
- **`map_no_tile`:** antirrepetición, solo para escaneos de aspecto aleatorio; nunca para azulejo ni tablas.

Para añadir un set:
1. Descarga el ZIP 2K-JPG de ambientCG, o los mapas 2K JPG `diff`, `nor_gl` y `arm` de Poly Haven, en `source_assets/textures/`.
2. Añádelo a `SETS` en `ingest_pbr.py` y ejecuta `python tools/textures/ingest_pbr.py`, que también actualiza `docs/ASSETS.md`.
3. Importa las imágenes con el editor o con `--import`.
4. Pon `metadata/scan` en el material.
5. Vuelve a medir los colores para el rebote con `tools/lighting/measure_albedo.gd`.
