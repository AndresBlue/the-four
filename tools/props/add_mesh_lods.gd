extends SceneTree
## Adds automatic levels of detail to meshes baked by the prop tools, which
## build them with SurfaceTool and so come out without any. Surfaces keep their
## order, materials and names (switch_off() and the door stop read them).
##   godot --headless --path . --script res://tools/props/add_mesh_lods.gd
## Run it again after re-baking one of these meshes. The door leaf and casing
## are left alone: they seal light, and a coarser far version is not worth a
## crack.
const MESHES := [
	"res://assets/props/wall_lamp/wall_lamp.res",
	"res://assets/props/monstera/monstera.res",
	"res://assets/props/sofa/sofa.res",
]

func _initialize() -> void:
	var failed := false
	for path in MESHES:
		var mesh: ArrayMesh = load(path)
		var importer := ImporterMesh.new()
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_INDEX] == null:
				var tool := SurfaceTool.new()
				tool.create_from_arrays(arrays, mesh.surface_get_primitive_type(surface))
				tool.index()
				arrays = tool.commit_to_arrays()
			importer.add_surface(mesh.surface_get_primitive_type(surface), arrays, [], {}, mesh.surface_get_material(surface), mesh.surface_get_name(surface))
		importer.generate_lods(60.0, 25.0, [])
		var result := importer.get_mesh()
		result.resource_name = mesh.resource_name
		var same := result.get_surface_count() == mesh.get_surface_count() and result.get_aabb().is_equal_approx(mesh.get_aabb())
		for surface in result.get_surface_count():
			same = same and result.surface_get_material(surface) == mesh.surface_get_material(surface)
		var lods := []
		for surface in importer.get_surface_count(): lods.append(importer.get_surface_lod_count(surface))
		if not same:
			failed = true
			print("LODS_SKIPPED ", path, " (surfaces, materials or bounds changed)")
			continue
		ResourceSaver.save(result, path)
		print("LODS ", path, " levels per surface=", lods)
	quit(1 if failed else 0)
