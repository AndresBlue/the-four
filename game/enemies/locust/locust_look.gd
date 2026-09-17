extends RefCounted
## The Locust's look after the reference picture (assets/images/the-locust.png):
## ink-black body, pale mask of a face with hollow eyes. The recoloured texture
## comes from tools/art/make_locust_reference_texture.py and the material from
## tools/art/build_locust_reference_material.gd; the model file is untouched.
const MATERIAL := preload("res://assets/enemies/locust_reference_material.tres")

static func apply(model: Node) -> void:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.mesh.surface_get_material(surface)
			if material is StandardMaterial3D and material.albedo_texture != null and material.albedo_texture.resource_path.ends_with("locust_locust_by-doumty_basecolor_tex.png"):
				mesh.set_surface_override_material(surface, MATERIAL)
