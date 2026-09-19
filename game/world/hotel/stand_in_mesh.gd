extends Mesh
## A mesh kept in memory only, never sent to the GPU: the bounce light's stand-in
## (bounce_light.gd). VoxelGI's baker reads a mesh's triangles back from the
## RenderingServer, which answers only on the main thread; a bake on a worker
## thread would wait for it, and the main thread waiting for the bake would
## never answer. This one answers the baker itself.
var surfaces: Array[Dictionary] = []
var bounds := AABB()

## Adds a surface of unindexed triangles in one material.
func add(vertices: PackedVector3Array, normals: PackedVector3Array, material: Material) -> void:
	if vertices.is_empty(): return
	var arrays := []
	arrays.resize(ARRAY_MAX)
	arrays[ARRAY_VERTEX] = vertices
	arrays[ARRAY_NORMAL] = normals
	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	arrays[ARRAY_TEX_UV] = uvs
	surfaces.append({"arrays": arrays, "material": material})
	var box := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices: box = box.expand(vertex)
	bounds = box if surfaces.size() == 1 else bounds.merge(box)

func _get_surface_count() -> int: return surfaces.size()
func _surface_get_array_len(index: int) -> int: return surfaces[index].arrays[ARRAY_VERTEX].size()
func _surface_get_array_index_len(_index: int) -> int: return 0
func _surface_get_arrays(index: int) -> Array: return surfaces[index].arrays
func _surface_get_blend_shape_arrays(_index: int) -> Array[Array]: return []
func _surface_get_lods(_index: int) -> Dictionary: return {}
func _surface_get_format(_index: int) -> int: return ARRAY_FORMAT_VERTEX | ARRAY_FORMAT_NORMAL | ARRAY_FORMAT_TEX_UV
func _surface_get_primitive_type(_index: int) -> int: return PRIMITIVE_TRIANGLES
func _surface_set_material(index: int, material: Material) -> void: surfaces[index].material = material
func _surface_get_material(index: int) -> Material: return surfaces[index].material
func _get_blend_shape_count() -> int: return 0
func _get_blend_shape_name(_index: int) -> StringName: return &""
func _set_blend_shape_name(_index: int, _name: StringName) -> void: pass
func _get_aabb() -> AABB: return bounds
