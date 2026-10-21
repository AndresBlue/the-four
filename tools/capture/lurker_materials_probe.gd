extends SceneTree
## Prints how Godot imported a GLB (the creature's by default): whether each
## material uses its vertex colours, its specular and roughness, and each
## clip's length and loop mode.
##   godot --headless --path . --script res://tools/capture/lurker_materials_probe.gd -- [--glb=res://...]

func _initialize() -> void:
	var path := "res://assets/enemies/lurker/lurker.glb"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--glb="): path = argument.trim_prefix("--glb=")
	var scene: Node = load(path).instantiate()
	for mesh_instance in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mesh_instance.mesh
		for surface in mesh.get_surface_count():
			var material = mesh.surface_get_material(surface)
			if material is BaseMaterial3D:
				var colors: PackedColorArray = mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				print("PROBE %s/%d %s vertex_color=%s specular=%.2f rough=%.2f cull=%d colors=%d first=%s" % [mesh_instance.name, surface, material.resource_name,
					material.vertex_color_use_as_albedo, material.metallic_specular, material.roughness, material.cull_mode,
					colors.size(), colors[0] if colors.size() else "-"])
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	if player:
		for clip in player.get_animation_list():
			var animation := player.get_animation(clip)
			print("PROBE clip %s %.2fs loop=%d" % [clip, animation.length, animation.loop_mode])
	scene.free()
	quit()
