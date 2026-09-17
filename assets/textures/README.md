# Texturas fotográficas

Cada carpeta con el nombre de un material de `game/presentation/materials/` sustituye automáticamente la base procedural al construir el hotel. No hace falta tocar código ni materiales.

```
assets/textures/<material>/albedo.png     color (sRGB)
assets/textures/<material>/normal.png     normal map formato OpenGL (verde hacia arriba)
assets/textures/<material>/roughness.png  rugosidad (canal verde)
```

Se aceptan `.png`, `.jpg`, `.jpeg` y `.webp`. Cualquiera de los tres mapas es opcional. Las manchas, suciedad y desgaste procedurales se siguen aplicando encima para que la repetición se note menos.

Tamaño real de una repetición: `map_metres` en el `.tres` del material (editable desde el Inspector). Tinte opcional: `map_tint`.

| Carpeta | Uso | `map_metres` |
|---|---|---|
| `plaster` | Papel pintado de paredes | 0.6 |
| `carpet` | Moqueta | 1.5 |
| `ceiling` | Techo | 1.2 |
| `tile` | Suelo de baños, lavandería y mantenimiento | 1.0 |
| `wood` | Muebles y escondites | 1.0 |
| `panel` | Zócalo de madera de las paredes | 1.0 |
| `trim` | Molduras, marcos y rodapiés | 0.8 |
| `door` | Hojas de puerta (coordenadas locales) | 1.0 |
| `fabric` | Sofás, colchas, cabeceros | 0.5 |
| `linen` | Sábanas, almohadas, pantallas | 0.6 |
| `leather` | Maletas | 0.5 |
| `metal`, `gold` | Metal cepillado y latón | 0.5 |

Registra autor, fuente y licencia de cada textura en `docs/ASSETS.md` antes de distribuir.
