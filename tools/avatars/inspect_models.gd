extends SceneTree
func _initialize() -> void: inspect.call_deferred()
func inspect() -> void:
	var result := []
	for id in ["detective", "detective_woman", "realistic_female"]:
		var node: Node3D
		if id == "detective":
			node = MeshInstance3D.new()
			node.mesh = load("res://assets/players/%s/model.obj" % id)
		else: node = load("res://assets/players/%s/model.fbx" % id).instantiate()
		root.add_child(node)
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		if node is MeshInstance3D: meshes.append(node)
		var item := {"id":id,"meshes":[],"animations":[],"bones":[]}
		for mesh in meshes:
			var mats := []
			for i in mesh.mesh.get_surface_count():
				var mat: Material = mesh.get_active_material(i)
				mats.append({"name":mat.resource_name if mat else "", "texture":str(mat.albedo_texture.resource_path) if mat is StandardMaterial3D and mat.albedo_texture else ""})
			item.meshes.append({"name":str(mesh.name),"bounds":str(mesh.global_transform * mesh.get_aabb()),"materials":mats})
		for ap in node.find_children("*", "AnimationPlayer", true, false):
			for anim in ap.get_animation_list(): item.animations.append({"name":anim,"length":ap.get_animation(anim).length,"tracks":ap.get_animation(anim).get_track_count()})
		for rig in node.find_children("*", "Skeleton3D", true, false):
			for i in rig.get_bone_count(): item.bones.append(rig.get_bone_name(i))
		result.append(item)
		node.free()
	var file := FileAccess.open("res://evidence/player_model_inspection.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print(JSON.stringify(result))
	quit()
