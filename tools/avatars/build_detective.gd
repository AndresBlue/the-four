extends SceneTree
## The supplied OBJ has no skeleton. Bake a provisional relaxed arm pose.
func _initialize() -> void:
	var original: ArrayMesh = load("res://assets/players/detective/model.obj")
	var result := ArrayMesh.new()
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in vertices.size():
			var v := vertices[i]
			var weight := smoothstep(20.0, 36.0, absf(v.x)) * smoothstep(105.0, 125.0, v.y)
			var rotation := Basis(Vector3.FORWARD, deg_to_rad(73) * signf(v.x) * weight)
			var pivot := Vector3(signf(v.x) * 19.0, 143.0, 0)
			vertices[i] = pivot + rotation * (v - pivot)
			if normals.size() > i: normals[i] = rotation * normals[i]
			if tangents.size() > i * 4 + 2:
				var tangent := rotation * Vector3(tangents[i*4], tangents[i*4+1], tangents[i*4+2])
				tangents[i*4] = tangent.x
				tangents[i*4+1] = tangent.y
				tangents[i*4+2] = tangent.z
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, original.surface_get_material(surface))
	var error := ResourceSaver.save(result, "res://game/player/avatars/detective_relaxed.res")
	print("DETECTIVE_POSE ", error)
	quit(error)
