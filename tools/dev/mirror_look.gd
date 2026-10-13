extends SceneTree
## The mirrors hung in lit rooms, each looked at from several sides and two
## distances: how bright its glass comes out in the picture, and from where
## it is at its worst. From that worst spot it is then shot again with one
## thing taken away at a time, to tell what it is that burns it out: the
## lamps' own highlight on the glass, the room's reflection probe, the
## reflections traced on the screen.
##
##   godot --rendering-method forward_plus --script res://tools/dev/mirror_look.gd -- --test-profile --automation --no-enemy --silent [--seed=81] [--quality=3] [--count=4] [--tall] [--at=20,2.5] [--label=mirror]
##
## "--tall": only rooms with a chandelier. "--at=20,2.5": from that one side
## (degrees off the glass's front) and distance (metres) and no other, to
## shoot the same view again after a change. Writes evidence/<label>_<room>.png:
## the variants side by side, in the order the log names them. Needs a window.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const VARIANTS := ["as it is", "no highlight of the lamps", "no probes", "no reflections on the screen"]
var level

func _initialize() -> void: run.call_deferred()

## Every hung mirror: [where its glass's middle is, the way it faces].
func mirrors() -> Array:
	var found: Array = []
	for instance in level.hotel.find_children("*", "MultiMeshInstance3D", true, false):
		var multi: MultiMesh = instance.multimesh
		if multi == null or multi.mesh == null or not "ornate_mirror_01" in multi.mesh.resource_path: continue
		for i in multi.instance_count:
			var hung: Transform3D = instance.global_transform * multi.get_instance_transform(i)
			found.append([hung * multi.mesh.get_aabb().get_center(), hung.basis.z.normalized()])
	return found

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = Vector3(from.x, from.y + 0.04, from.z)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	var eye: float = level.player.camera.global_position.y
	level.player.camera.rotation.x = atan2(at.y - eye, flat.length())
	level.player.snap_torch()

func picture(frames := 70) -> Image:
	for frame in frames: await process_frame
	await RenderingServer.frame_post_draw
	var seen: Image = root.get_texture().get_image()
	seen.convert(Image.FORMAT_RGB8)
	return seen

## How bright the picture is round a point of the room, 0 to 1.
func glass_reads(seen: Image, at: Vector3) -> float:
	var spot := Vector2i(level.player.camera.unproject_position(at) * Vector2(seen.get_size()) / Vector2(root.size))
	var total := 0.0
	var count := 0
	for y in range(spot.y - 5, spot.y + 6):
		for x in range(spot.x - 4, spot.x + 5):
			if x < 0 or y < 0 or x >= seen.get_width() or y >= seen.get_height(): continue
			total += seen.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxf(1.0, float(count))

## Whether a point is in plain view of somebody standing at `from`.
func seen_from(from: Vector3, at: Vector3) -> bool:
	var eye := Vector3(from.x, from.y + 1.6, from.z)
	var query := PhysicsRayQueryParameters3D.create(eye, at, 1 | 8)
	query.exclude = [level.player.get_rid()]
	var hit: Dictionary = level.player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(at) < 0.3

func every_lamp() -> Array:
	var hotel = level.hotel
	return hotel.lights + hotel.practicals + hotel.sconce_lights + hotel.exit_lamps + hotel.car_lamps

func run() -> void:
	var quality := PRESETS.ULTRA
	var seed_value := 81
	var label := "mirror"
	var count := 4
	var tall := false
	var sides: Array = [-70, -45, -20, 0, 20, 45, 70]
	var lengths: Array = [2.5, 6.0]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--at="):
			sides = [float(argument.trim_prefix("--at=").get_slice(",", 0))]
			lengths = [float(argument.trim_prefix("--at=").get_slice(",", 1))]
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		if argument.begins_with("--count="): count = int(argument.trim_prefix("--count="))
		if argument == "--tall": tall = true
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(seed_value)
	level.settings.set_designed(quality)
	await level.bounce_ready()
	level.player.set_physics_process(false)
	level.player.torch.visible = false
	if is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	var hotel = level.hotel
	var all := mirrors()
	var looked := 0
	var worst_of_all := 0.0
	for glass in all:
		var middle: Vector3 = glass[0]
		var out: Vector3 = glass[1]
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, middle + out * 0.5)
		if room.is_empty() or looked >= count: continue
		var id := int(room.id)
		if hotel.lights[id].has_meta("off") or (tall and hotel.room_nodes[id].get_node_or_null("Chandelier") == null): continue
		looked += 1
		var floor_y: float = FLOOR.position_of(room).y
		var worst := -1.0
		var worst_from := Vector3.ZERO
		var readings: Array = []
		for metres in lengths:
			for degrees in sides:
				var from: Vector3 = middle + out.rotated(Vector3.UP, deg_to_rad(degrees)) * metres
				from.y = floor_y
				if FLOOR.room_at(level.manifest.rooms, from).get("id", -1) != id or not seen_from(from, middle): continue
				look(from, middle)
				hotel.update_visibility(level.player.global_position, true)
				var reads := glass_reads(await picture(), middle)
				readings.append("%d deg %.1f m: %.2f" % [degrees, metres, reads])
				if reads > worst:
					worst = reads
					worst_from = from
		if worst < 0.0: continue
		worst_of_all = maxf(worst_of_all, worst)
		print("MIRROR_LOOK room ", id, " type ", room.type, " ", FLOOR.size_of(room), " x ", room.height, " m, chandelier=", hotel.room_nodes[id].get_node_or_null("Chandelier") != null, ": ", ", ".join(readings))
		# From where it is worst, with one thing taken away at a time.
		look(worst_from, middle)
		var page: Image
		var said: Array = []
		for index in VARIANTS.size():
			var lamps := every_lamp()
			var shines: Array = lamps.map(func(lamp): return lamp.light_specular)
			PRESETS.overrides = {}
			if index == 1:
				for lamp in lamps: lamp.light_specular = 0.0
			if index == 2: PRESETS.overrides = {"probes": 0}
			if index == 3: PRESETS.overrides = {"ssr_steps": 0}
			level.apply_settings()
			hotel.update_visibility(level.player.global_position, true)
			var seen := await picture()
			said.append("%s %.2f" % [VARIANTS[index], glass_reads(seen, middle)])
			if index == 0: page = Image.create(seen.get_width() * VARIANTS.size(), seen.get_height(), false, Image.FORMAT_RGB8)
			page.blit_rect(seen, Rect2i(Vector2i.ZERO, seen.get_size()), Vector2i(seen.get_width() * index, 0))
			for k in lamps.size(): lamps[k].light_specular = shines[k]
		PRESETS.overrides = {}
		level.apply_settings()
		# Which lamp's it is: each kind's highlight taken away in turn.
		for group in [["ceiling", hotel.lights], ["furniture", hotel.practicals], ["wall", hotel.sconce_lights]]:
			var shines: Array = group[1].map(func(lamp): return lamp.light_specular)
			for lamp in group[1]: lamp.light_specular = 0.0
			said.append("no highlight of the %s lamps %.2f" % [group[0], glass_reads(await picture(40), middle)])
			for k in group[1].size(): group[1][k].light_specular = shines[k]
		page.save_png("res://evidence/%s_%d.png" % [label, id])
		print("   at its worst (", snappedf(worst, 0.01), ") -> evidence/", label, "_", id, ".png: ", ", ".join(said))
	print("MIRROR_LOOK seed=", seed_value, " quality=", quality, ": ", all.size(), " mirrors, ", looked, " looked at, the brightest glass reads ", snappedf(worst_of_all, 0.01))
	level.queue_free()
	await process_frame
	quit()
