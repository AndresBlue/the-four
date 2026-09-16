# Taller de módulos

Abre `module_gallery.tscn` en Godot para ver los 20 tipos de espacio con sus muebles y colisiones. Los techos están ocultos para facilitar la inspección. F6 ejecuta una cámara libre: mantén botón derecho y WASD; Q/E cambia altura; Shift acelera.

**Es una referencia generada, no la fuente de los niveles.** Cambia `game/world/generation/floor_definition.gd`, `game/world/hotel/prop_factory.gd`, `hotel_geometry.gd` o los recursos de `game/presentation/materials/`, y reconstruye con `./tools/godot.ps1 build-gallery`. Esto reemplaza únicamente `module_gallery.tscn`. No guardes aquí cambios que quieras aplicar a la campaña.

La galería muestra habitaciones aisladas de 16 × 16 m. La variación, conexiones y salones combinados se comprueban en una partida con semilla fija: `./tools/godot.ps1 playtest -Seed 81`.
