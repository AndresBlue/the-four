extends SceneTree
## The Lurker's hands on a wall, seen from the side: whether the points of the
## claws are really on the surface (lurker_limbs.gd). A floor and a wall, a
## lamp, the creature held up beside the wall without its darkness; for every
## hand on the wall, a frame looking along the wall at it, and how far each
## finger curls. Writes evidence/lurker/hands_<arm>.png.
##   godot --path . --script res://tools/capture/lurker_hand_check.gd
const LURKER := preload("res://game/enemies/lurker/lurker.tscn")
var out_dir := "res://evidence/lurker"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DisplayServer.window_set_size(Vector2i(900, 900))
	var world := Node3D.new()
	root.add_child(world)
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.75, 0.72, 0.66)
	for slab in [[Vector3(8, 0.1, 8), Vector3(0, -0.05, 0)], [Vector3(0.1, 4, 8), Vector3(-1.0, 2, 0)]]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = slab[0]
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = slab[0]
		mesh.mesh = cube
		mesh.material_override = pale
		body.add_child(mesh)
		body.position = slab[1]
		world.add_child(body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.3, 0.3, 0.35)
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.fov = 40.0
	world.add_child(camera)
	camera.current = true
	var beast: Node3D = LURKER.instantiate()
	world.add_child(beast)
	beast.ink.visible = false
	beast.vapour.visible = false
	beast.cling = 1.0
	# its side to the wall, held up off the floor
	beast.global_transform = Transform3D(Basis(), Vector3(-0.2, 0.75, 0.0))
	for i in 90: await process_frame
	var limbs = beast.limbs
	var skeleton: Skeleton3D = beast.skeleton
	for limb in limbs.limbs:
		print("HOOK %s free=%s swing=%s normal=%s miss=%.1fcm wrist %.1fcm off, hooked=%s, claws %s cm" % [limb.name, limb.free, limb.swing,
			limb.normal.snapped(Vector3.ONE * 0.1), float(limb.miss) * 100.0, float(limb.wrist_up) * limbs.size * 100.0,
			(limb.hooked as Array).map(func(k): return snappedf(k, 0.01)), (limb.touch as Array).map(func(t): return snappedf(float(t) * limbs.size * 100.0, 0.1))])
	for limb in limbs.limbs:
		if limb.free or limb.swing: continue
		var hold: Vector3 = limb.hold
		var normal: Vector3 = limb.normal
		# looking along the surface at the hand, from a metre off to its side
		var along := normal.cross(Vector3.FORWARD if absf(normal.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		camera.global_position = hold + along * 1.1 + normal * 0.12
		camera.look_at(hold + normal * 0.12, normal if absf(normal.dot(along)) < 0.9 else Vector3.UP)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir + "/hands_%s.png" % String(limb.name).replace(".", ""))
	quit()
