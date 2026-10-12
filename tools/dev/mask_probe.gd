extends SceneTree
## Where The Locust's mask is: the pale part of its face, measured on the model
## itself. Prints, in the head bone's own space, the centre of the mask, the
## way it faces, which way is up on it and how big it is -- the numbers
## locust_visual.MASK is written from. Run it again if the model changes.
##
##   godot --headless --path . --script res://tools/dev/mask_probe.gd -- --test-profile
const BONE := "ValveBiped.Bip01_"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var threshold := 0.45
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pale="): threshold = float(argument.trim_prefix("--pale="))
	var creature: Node3D = load("res://game/enemies/locust/locust.tscn").instantiate()
	root.add_child(creature)
	await process_frame
	var visual: Node3D = creature.get_node("Visual")
	var skeleton: Skeleton3D = visual.find_children("*", "Skeleton3D", true, false)[0]
	var head := skeleton.find_bone(BONE + "Head1")
	var neck := skeleton.find_bone(BONE + "Neck1")
	var head_rest := skeleton.get_bone_global_rest(head)
	print("SKELETON_WORLD ", skeleton.global_transform, " bones=", skeleton.get_bone_count())
	print("HEAD_REST origin=", head_rest.origin, " x=", head_rest.basis.x, " y=", head_rest.basis.y, " z=", head_rest.basis.z)
	var names: Array = []
	for id in skeleton.get_bone_count(): names.append(skeleton.get_bone_name(id).trim_prefix(BONE))
	print("BONES ", names)
	for name in ["Pelvis", "Spine", "Spine2", "Spine4", "Neck1", "Head1", "L_UpperArm", "L_Forearm", "L_Hand", "R_UpperArm", "R_Forearm", "R_Hand", "L_Foot", "R_Foot"]:
		var id := skeleton.find_bone(BONE + name)
		print("BONE %-12s rest=%s world=%s" % [name, skeleton.get_bone_global_rest(id).origin, skeleton.global_transform * skeleton.get_bone_global_rest(id).origin])
	var neck_height: float = skeleton.get_bone_global_rest(neck).origin.y
	var pale: Array = []
	for mesh_node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mesh_node.mesh
		var skin: Skin = mesh_node.skin
		print("MESH ", mesh_node.name, " surfaces=", mesh.get_surface_count(), " aabb=", mesh.get_aabb())
		for surface in mesh.get_surface_count():
			var material = mesh_node.get_active_material(surface)
			var image: Image = null
			if material is StandardMaterial3D and material.albedo_texture != null:
				image = material.albedo_texture.get_image()
				if image != null and image.is_compressed(): image.decompress()
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			var per: int = bones.size() / vertices.size() if vertices.size() > 0 else 4
			var histogram := {}
			var owners := {}
			var above := 0
			for index in vertices.size():
				# The mesh is in the skeleton's own space at rest.
				var point: Vector3 = vertices[index]
				if point.y < neck_height: continue
				above += 1
				var best := -1
				var best_weight := 0.0
				for k in per:
					if float(weights[index * per + k]) > best_weight:
						best_weight = float(weights[index * per + k])
						best = int(bones[index * per + k])
				var owner := str(best)
				if skin != null and best >= 0 and best < skin.get_bind_count():
					owner = String(skin.get_bind_name(best))
					if owner.is_empty(): owner = skeleton.get_bone_name(skin.get_bind_bone(best))
				elif skin == null and best >= 0 and best < skeleton.get_bone_count(): owner = skeleton.get_bone_name(best)
				owners[owner] = int(owners.get(owner, 0)) + 1
				if image == null or uvs.is_empty(): continue
				var uv: Vector2 = uvs[index]
				var pixel := image.get_pixel(clampi(int(fposmod(uv.x, 1.0) * image.get_width()), 0, image.get_width() - 1), clampi(int(fposmod(uv.y, 1.0) * image.get_height()), 0, image.get_height() - 1))
				var bucket := int(clampf(pixel.get_luminance(), 0.0, 0.999) * 10.0)
				histogram[bucket] = int(histogram.get(bucket, 0)) + 1
				if pixel.get_luminance() > threshold: pale.append([point, normals[index].normalized()])
			print("  SURFACE ", surface, " vertices=", vertices.size(), " above_neck=", above, " luma=", histogram, " owners=", owners, " texture=", material.albedo_texture.resource_path if material is StandardMaterial3D and material.albedo_texture != null else "")
	print("PALE ", pale.size())
	if pale.is_empty():
		quit()
		return
	var centre := Vector3.ZERO
	var facing := Vector3.ZERO
	var low := Vector3(INF, INF, INF)
	var high := -low
	for entry in pale:
		centre += entry[0]
		facing += entry[1]
		low = low.min(entry[0])
		high = high.max(entry[0])
	centre /= float(pale.size())
	facing = facing.normalized()
	print("MASK skeleton centre=", centre, " facing=", facing, " low=", low, " high=", high, " size=", high - low)
	var local := head_rest.affine_inverse()
	print("MASK head_local centre=", local * centre, " facing=", local.basis * facing, " up=", local.basis * Vector3.UP, " box_centre=", local * ((low + high) * 0.5))
	var scale: float = skeleton.global_transform.basis.get_scale().y
	print("MASK world size=", (high - low) * scale, " centre_world=", skeleton.global_transform * centre, " facing_world=", (skeleton.global_transform.basis * facing).normalized())
	creature.queue_free()
	await process_frame
	quit()
