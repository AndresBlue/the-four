extends SceneTree
## The camcorder and the tape as baked (evidence/camcorder_prop_*.png): on a
## plain floor under one lamp, from three sides, to check their size, which
## way the lens points and what their materials came out as.

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.05, 0.05, 0.06)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.4, 0.4, 0.45)
	environment.environment.ambient_light_energy = 0.5
	world.add_child(environment)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 4)
	floor_mesh.mesh = plane
	var carpet := StandardMaterial3D.new()
	carpet.albedo_color = Color(0.32, 0.12, 0.1)
	carpet.roughness = 0.95
	floor_mesh.material_override = carpet
	world.add_child(floor_mesh)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.6, 1.2, 0.8)
	lamp.light_energy = 2.5
	lamp.omni_range = 5.0
	lamp.shadow_enabled = true
	world.add_child(lamp)
	var camcorder := MeshInstance3D.new()
	camcorder.mesh = load("res://assets/props/camcorder/camcorder.res")
	# Standing as it is held: the lens at 12 cm, looking along -Z.
	camcorder.position = Vector3(0, 0.1, 0)
	world.add_child(camcorder)
	var tape := MeshInstance3D.new()
	tape.mesh = load("res://assets/props/vhs_tape/vhs_tape.res")
	tape.position = Vector3(0.35, 0.0, 0.1)
	tape.rotation.y = 0.4
	world.add_child(tape)
	# A second one, lying on its side as it would be found.
	var fallen := MeshInstance3D.new()
	fallen.mesh = camcorder.mesh
	fallen.transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(84.0)), Vector3(-0.45, 0.05, 0.1))
	world.add_child(fallen)
	var view := Camera3D.new()
	view.fov = 40.0
	world.add_child(view)
	view.current = true
	var shots := {"front": Vector3(0.25, 0.3, -1.0), "side": Vector3(1.1, 0.35, 0.2), "back": Vector3(-0.5, 0.45, 1.1)}
	for name in shots:
		view.global_position = shots[name]
		view.look_at(Vector3(0, 0.06, 0.1))
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/camcorder_prop_%s.png" % name)
	print("CAMCORDER_SHOTS ", shots.keys(), " camcorder=", camcorder.mesh.get_aabb(), " tape=", tape.mesh.get_aabb())
	quit()
