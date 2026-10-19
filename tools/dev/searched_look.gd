extends SceneTree
## The four pieces of furniture that open when gone through, side by side and
## by themselves, drawn in their parts (tools/props/build_catalogue.gd,
## MOVING) with every drawer and door out as a searched piece leaves one
## (hotel_container.motion): to see that each drawer comes out of the front
## and each door turns about its own hinge, out into the room.
##
##   godot --script res://tools/dev/searched_look.gd
##
## Writes evidence/searched_look.png, seen from in front and a little to the
## side and above. Needs a window.
##
## With "-- --floor --test-profile --automation --no-enemy --silent" it is the
## hotel itself instead: on floor 81, one piece of each kind that can be gone
## through, in a lit room, filmed by the survivor's camcorder before and after
## it is searched (evidence/searched_floor.png: a row each, before on the
## left).
const CONTAINER := preload("res://game/world/interactables/hotel_container.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const KINDS := ["commode", "cabinet", "drawers", "bookcase", "console", "boxes"]
const MODELS := ["GothicCommode_01", "painted_wooden_cabinet", "drawer_cabinet", "vintage_cabinet_01"]

func _initialize() -> void: run.call_deferred()

func run() -> void:
	if OS.get_cmdline_user_args().has("--floor"):
		await on_the_floor()
		return
	DisplayServer.window_set_size(Vector2i(1600, 700))
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.15, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 0.96, 0.9)
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-35, 30, 0)
	lamp.shadow_enabled = true
	root.add_child(lamp)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 6)
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)
	var x := -3.3
	for model in MODELS:
		var body: Mesh = load("res://assets/props/hotel/%s_body.res" % model)
		var stood := Transform3D(Basis.IDENTITY, Vector3(x + body.get_aabb().size.x * 0.5, 0, 0))
		add(body, stood)
		for part_name in body.get_meta("parts"):
			var part: Mesh = load("res://assets/props/hotel/%s_%s.res" % [model, part_name])
			add(part, stood * Transform3D(Basis.IDENTITY, part.get_meta("pivot")) * CONTAINER.motion(part_name, part))
		x += body.get_aabb().size.x + 0.45
	var camera := Camera3D.new()
	camera.fov = 40.0
	root.add_child(camera)
	camera.look_at_from_position(Vector3(1.2, 2.3, 5.6), Vector3(0.1, 0.8, 0), Vector3.UP)
	camera.make_current()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence"))
	root.get_texture().get_image().save_png("res://evidence/searched_look.png")
	print("SEARCHED_LOOK evidence/searched_look.png")
	quit()

func on_the_floor() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	level.player.set_physics_process(false)
	level.player.torch.visible = false
	level.world_audio.enabled = false
	if is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	var page: Image
	var row := 0
	for kind in KINDS:
		var piece = null
		for candidate in level.containers:
			if candidate.kind != kind or candidate.searched: continue
			var room: Dictionary = FLOOR.room_at(level.manifest.rooms, candidate.global_position)
			if room.is_empty() or level.hotel.lights[int(room.id)].has_meta("off"): continue
			piece = candidate
			break
		if piece == null:
			print("SEARCHED_LOOK no ", kind, " in a lit room")
			continue
		var out: Vector3 = piece.global_transform.basis.z.normalized()
		var side: Vector3 = piece.global_transform.basis.x.normalized()
		var from: Vector3 = piece.global_position + out * 1.7 + side * 0.6
		var floor_y: float = FLOOR.position_of(FLOOR.room_at(level.manifest.rooms, piece.global_position)).y
		level.player.global_position = Vector3(from.x, floor_y + 0.04, from.z)
		var aim: Vector3 = piece.global_position + Vector3(0, 0.75, 0) - from
		level.player.rotation.y = atan2(aim.x, aim.z) + PI
		level.player.camera.rotation.x = atan2(floor_y + 0.75 - level.player.camera.global_position.y, Vector2(aim.x, aim.z).length())
		level.hotel.update_visibility(level.player.position, true)
		for shot in 2:
			if shot == 1:
				level.apply_search(level.containers.find(piece), true)
				for frame in 150: await process_frame
			for frame in 30: await process_frame
			await RenderingServer.frame_post_draw
			var seen: Image = root.get_texture().get_image()
			seen.convert(Image.FORMAT_RGB8)
			seen.resize(seen.get_width() / 2, seen.get_height() / 2)
			if page == null: page = Image.create(seen.get_width() * 2, seen.get_height() * KINDS.size(), false, Image.FORMAT_RGB8)
			page.blit_rect(seen, Rect2i(Vector2i.ZERO, seen.get_size()), Vector2i(seen.get_width() * shot, seen.get_height() * row))
		print("SEARCHED_LOOK ", kind, " (", String(piece.note_spot.get("model", "")), "): ", piece.left.get("part", "a thing moved"))
		row += 1
	if page != null: page.save_png("res://evidence/searched_floor.png")
	level.queue_free()
	await process_frame
	quit()

func add(mesh: Mesh, at: Transform3D) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	root.add_child(node)
	node.transform = at
