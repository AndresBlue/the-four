extends SceneTree
## The hotel's four clocks with their hands turned to a given time, side by
## side and by themselves: to see that every hand turns about the middle of
## its dial, the right way round, and reads the hour it is told (the baking
## is tools/props/build_catalogue.gd, CLOCKS; the turning, hotel_geometry.gd).
##
##   godot --script res://tools/dev/clocks_look.gd -- [--times=3:00:00,10:10:30,2:51:26]
##
## Writes evidence/clocks_look.png: a row for each time. Needs a window.
##
## With "-- --floor --test-profile --automation --no-enemy --silent" it is a
## clock of the hotel itself instead: the first wall clock of a lit room of
## floor 81, filmed from in front of it by the camcorder, whose own hour is
## in the picture to read it against (evidence/clocks_floor.png), and again
## twenty seconds later.
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const CLOCKS := ["wall_clock", "alarm_clock_01", "mantel_clock_01", "vintage_grandfather_clock_01"]

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var times: Array = ["3:00:00", "10:10:30", "2:51:26"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--times="): times = Array(argument.trim_prefix("--times=").split(","))
	if OS.get_cmdline_user_args().has("--floor"):
		await on_the_floor()
		return
	DisplayServer.window_set_size(Vector2i(1600, 450))
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.15, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 0.96, 0.9)
	environment.ambient_light_energy = 0.9
	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-25, 20, 0)
	root.add_child(lamp)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Four dials across the picture, whatever shape the window came out.
	for frame in 3: await process_frame
	var size: Vector2i = root.size
	var wide := 2.2
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = wide
	camera.position = Vector3(0, 0, 2)
	root.add_child(camera)
	camera.make_current()
	# Each clock with its dial in the middle of its quarter of the picture
	# and as big as fits; the long-case one is its hood only.
	var hands: Array = []
	for index in CLOCKS.size():
		var body: Mesh = load("res://assets/props/hotel/%s.res" % CLOCKS[index])
		var names: PackedStringArray = body.get_meta("hands")
		var pivot: Vector3 = load("res://assets/props/hotel/%s_%s.res" % [CLOCKS[index], names[0]]).get_meta("pivot")
		var scale := 0.42 / minf(body.get_aabb().size.x, 0.42 if CLOCKS[index].begins_with("vintage") else body.get_aabb().size.y)
		var at := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3((float(index) + 0.5) / CLOCKS.size() * wide - wide * 0.5, 0, 0) - pivot * scale)
		var shown := MeshInstance3D.new()
		shown.mesh = body
		shown.transform = at
		# Its glass out of the way: here it is the hands that are looked at.
		for surface in body.get_surface_count():
			if body.surface_get_name(surface).to_lower().contains("glass"):
				var clear := StandardMaterial3D.new()
				clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				clear.albedo_color = Color(1, 1, 1, 0.04)
				shown.set_surface_override_material(surface, clear)
		root.add_child(shown)
		for hand in names:
			var piece: Mesh = load("res://assets/props/hotel/%s_%s.res" % [CLOCKS[index], hand])
			var turning := MeshInstance3D.new()
			turning.mesh = piece
			root.add_child(turning)
			hands.append([turning, at * Transform3D(Basis.IDENTITY, piece.get_meta("pivot")), String(hand)])
	# The middle band of the picture, where the dials are.
	var band := Rect2i(0, size.y / 2 - size.x / 8, size.x, size.x / 4)
	var page := Image.create(band.size.x, band.size.y * times.size(), false, Image.FORMAT_RGB8)
	for row in times.size():
		var parts: PackedStringArray = String(times[row]).split(":")
		var seconds := int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
		for entry in hands:
			(entry[0] as MeshInstance3D).transform = (entry[1] as Transform3D) * Transform3D(Basis(Vector3.BACK, -TAU * GEOMETRY.hand_turn(entry[2], seconds)), Vector3.ZERO)
		for frame in 6: await process_frame
		await RenderingServer.frame_post_draw
		var seen: Image = root.get_texture().get_image()
		seen.convert(Image.FORMAT_RGB8)
		page.blit_rect(seen, band, Vector2i(0, band.size.y * row))
	page.save_png("res://evidence/clocks_look.png")
	print("CLOCKS_LOOK ", times)
	quit()

## A clock of the hotel, by the camcorder: the hour on its dial against the
## hour on the tape.
func on_the_floor() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	level.player.set_physics_process(false)
	if is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	# The first wall clock (it has a second hand) that hangs in a lit room.
	var found := false
	var face := Transform3D.IDENTITY
	var floor_y := 0.0
	for entry in level.hotel.clock_hands:
		var multi: MultiMesh = entry.multi
		if String(entry.hand) != "second" or not multi.mesh.resource_name.begins_with("wall_clock"): continue
		for holder in level.hotel.find_children("*", "MultiMeshInstance3D", true, false):
			if (holder as MultiMeshInstance3D).multimesh != multi or found: continue
			var room: Dictionary = FLOOR.room_at(level.manifest.rooms, (holder as Node3D).global_transform * (entry.stands[0] as Transform3D).origin)
			if room.is_empty() or level.hotel.lights[int(room.id)].has_meta("off"): continue
			face = (holder as Node3D).global_transform * (entry.stands[0] as Transform3D)
			floor_y = FLOOR.position_of(room).y
			found = true
	if not found:
		print("CLOCKS_LOOK no wall clock in a lit room")
		quit(1)
		return
	var out := face.basis.z.normalized()
	var from := face.origin + out * 1.1
	level.player.global_position = Vector3(from.x, floor_y + 0.04, from.z)
	level.player.rotation.y = atan2(out.x, out.z)
	level.player.camera.rotation.x = atan2(face.origin.y - level.player.camera.global_position.y, 1.1)
	level.player.torch.visible = false
	level.hotel.update_visibility(level.player.position, true)
	var page: Image
	for shot in 2:
		for frame in (60 if shot == 0 else 1200): await process_frame
		await RenderingServer.frame_post_draw
		var seen: Image = root.get_texture().get_image()
		seen.convert(Image.FORMAT_RGB8)
		if shot == 0: page = Image.create(seen.get_width() * 2, seen.get_height(), false, Image.FORMAT_RGB8)
		page.blit_rect(seen, Rect2i(Vector2i.ZERO, seen.get_size()), Vector2i(seen.get_width() * shot, 0))
		print("CLOCKS_LOOK floor shot ", shot, ": the camcorder says ", level.camcorder.clock_text(level.tape_seconds()).get_slice("\n", 0), " and the clocks were told ", level.hotel.clock_time)
	page.save_png("res://evidence/clocks_floor.png")
	level.queue_free()
	await process_frame
	quit()
