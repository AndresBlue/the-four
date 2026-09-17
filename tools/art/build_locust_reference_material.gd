extends SceneTree
## Saves The Locust's body material with the reference texture as a resource
## (assets/enemies/locust_reference_material.tres), copied from the model's own
## material so normal maps and settings stay the same. Run after
## make_locust_reference_texture.py.
##   godot --headless --path . --script res://tools/art/build_locust_reference_material.gd
func _initialize() -> void:
	var model: Node = load("res://assets/enemies/locust.glb").instantiate()
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.mesh.surface_get_material(surface)
			if material is StandardMaterial3D and material.albedo_texture != null and material.albedo_texture.resource_path.ends_with("locust_locust_by-doumty_basecolor_tex.png"):
				var look: StandardMaterial3D = material.duplicate()
				look.resource_name = "LocustReference"
				look.albedo_texture = load("res://assets/enemies/locust_reference_basecolor.png")
				look.roughness = 0.75
				print("SAVED ", ResourceSaver.save(look, "res://assets/enemies/locust_reference_material.tres"))
				model.free()
				quit()
				return
	model.free()
	quit()
