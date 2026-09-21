@tool
extends EditorScenePostImport
## Throws away the blend shapes of a character model as it is imported.
##
## The bought models come with a face rig: 585 shapes on one of them, 154 on
## another, each one a full copy of the vertices it moves. The game never
## touches them -- survivors are posed from their bones by avatar_visual.gd --
## and they were most of the package: the female model alone imported to 50 MB
## and comes out at about three.
##
## Skinning, materials and the skeleton are kept exactly as they were; what is
## rebuilt is each surface, from its own arrays, without the shape deltas.
## Hooked up from the model's .import file (import_script/path).

func _post_import(scene: Node) -> Object:
	var shapes := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := node.mesh as ArrayMesh
		if mesh == null or mesh.get_blend_shape_count() == 0: continue
		shapes += mesh.get_blend_shape_count()
		var bare := ArrayMesh.new()
		bare.resource_name = mesh.resource_name
		for surface in mesh.get_surface_count():
			bare.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), mesh.surface_get_arrays(surface), [], {}, mesh.surface_get_format(surface) & ~Mesh.ARRAY_FLAG_USES_EMPTY_VERTEX_ARRAY)
			bare.surface_set_material(surface, mesh.surface_get_material(surface))
			bare.surface_set_name(surface, mesh.surface_get_name(surface))
		node.mesh = bare
	if shapes > 0: print("strip_blend_shapes: ", shapes, " shapes dropped from ", scene.name)
	return scene
