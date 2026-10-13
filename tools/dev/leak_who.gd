extends SceneTree
## Which lamp it is that lights a dark room it has no business in: the room's
## worst wall is measured (as tools/dev/light_leak.gd measures it), and then
## again with each lit lamp near it put out in turn. Whatever lamp the wall
## goes dark without is said: what it is, where, whether it casts a shadow,
## what layers it lights and what layers the wall's room and its own are on.
##
##   godot --rendering-method forward_plus --script res://tools/dev/leak_who.gd -- --test-profile --automation --seed=81 --quality=3 --rooms=22,102
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
var level
var view: SubViewport
var lens: Camera3D
## The brightest point of the last picture measured.
var peak := 0.0

func _initialize() -> void: run.call_deferred()

func seen(from: Vector3, at: Vector3, keep := "") -> float:
	lens.global_position = from
	lens.look_at(at, Vector3.UP)
	for i in 6: await process_frame
	var worst := 0.0
	peak = 0.0
	for sample in 4:
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := view.get_texture().get_image()
		if not keep.is_empty() and sample == 3: picture.save_png("res://evidence/%s.png" % keep)
		picture.convert(Image.FORMAT_RGBF)
		var total := 0.0
		var count := 0
		for y in range(0, picture.get_height(), 8):
			for x in range(0, picture.get_width(), 8):
				var pixel := picture.get_pixel(x, y)
				total += pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
				peak = maxf(peak, pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722)
				count += 1
		worst = maxf(worst, total / maxf(1.0, float(count)))
	return worst

func run() -> void:
	var run_seed := 81
	var quality := PRESETS.ULTRA
	var rooms: Array = []
	# "--types=7,8,9": every room of those kinds on the first planta instead,
	# its own lamps put out, looked at along the foot of each wall.
	var types: Array = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): run_seed = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--types="):
			for piece in argument.trim_prefix("--types=").split(","): types.append(int(piece))
		if argument.begins_with("--rooms="):
			for piece in argument.trim_prefix("--rooms=").split(","): rooms.append(int(piece))
	DisplayServer.window_set_size(Vector2i(640, 360))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(run_seed)
	level.settings.set_designed(quality)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	level.player.torch.visible = false
	level.player.visible = false
	while level.hotel.bounce.baking(): await process_frame
	view = SubViewport.new()
	view.size = Vector2i(640, 360)
	view.world_3d = level.get_viewport().world_3d
	view.own_world_3d = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	lens = Camera3D.new()
	lens.fov = 75.0
	view.add_child(lens)
	lens.make_current()
	var hotel = level.hotel
	if not types.is_empty():
		if OS.get_cmdline_user_args().has("--behind"): await behind_wall_lamps(types)
		else: await feet_of_walls(types)
		level.queue_free()
		await process_frame
		quit()
		return
	for id in rooms:
		var room: Dictionary = level.manifest.rooms[id]
		var eye := FLOOR.position_of(room) + Vector3(0, 1.6, 0)
		level.player.global_position = eye
		hotel.update_visibility(eye, true)
		for i in 20: await process_frame
		hotel.update_visibility(eye, true)
		var worst := Vector3.FORWARD
		var most := 0.0
		for way in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var here := await seen(eye, eye + way * 4.0)
			if here > most:
				most = here
				worst = way
		print("LEAK_WHO room ", id, " type=", room.type, " size=", FLOOR.size_of(room), " layer=%x" % int(hotel.room_layers.layer[id]), " lit=", not hotel.lights[id].has_meta("off"), " worst wall ", worst, " reads ", snappedf(most, 0.00001))
		await seen(eye, eye + worst * 4.0, "leak_who_%d" % id)
		var lamps: Array = []
		for group in [["ceiling", hotel.lights], ["wall", hotel.sconce_lights], ["furniture", hotel.practicals], ["exit", hotel.exit_lamps], ["car", hotel.car_lamps]]:
			for lamp in group[1]:
				if lamp.is_visible_in_tree() and lamp.global_position.distance_to(eye) < 40.0: lamps.append([group[0], lamp])
		for entry in lamps:
			var lamp: Light3D = entry[1]
			var strength: float = lamp.light_energy
			lamp.light_energy = 0.0
			var without := await seen(eye, eye + worst * 4.0)
			lamp.light_energy = strength
			if without < most * 0.8:
				var home: Dictionary = FLOOR.room_at(level.manifest.rooms, lamp.global_position)
				print("   it is a ", entry[0], " lamp ", snappedf(lamp.global_position.distance_to(eye), 0.1), " m off (", (lamp.global_position - eye).snapped(Vector3(0.1, 0.1, 0.1)), "), in room ", home.get("id", -1), " type ", home.get("type", -1), ": without it the wall reads ", snappedf(without, 0.00001), " · casts=", lamp.shadow_enabled, " mask=%x" % lamp.light_cull_mask, " range=", snappedf(lamp.get("omni_range") if lamp is OmniLight3D else 0.0, 0.1), " its room's layer=%x" % int(hotel.room_layers.layer[int(home.get("id", 0))]), " projector=", lamp.light_projector != null)
	print("LEAK_WHO done")
	level.queue_free()
	await process_frame
	quit()

## Rooms of some kinds with their own lamps out: what still falls on the floor
## along each wall came from next door.
func feet_of_walls(types: Array) -> void:
	var hotel = level.hotel
	var found := 0
	for room in level.manifest.rooms:
		if not int(room.type) in types or int(room.get("wing", 0)) != 0 or found >= 14: continue
		var id := int(room.id)
		var centre := FLOOR.position_of(room)
		var span: Vector2 = FLOOR.size_of(room)
		var eye := centre + Vector3(0, 1.6, 0)
		level.player.global_position = eye
		hotel.update_visibility(eye, true)
		for i in 20: await process_frame
		hotel.update_visibility(eye, true)
		# Its own: the ceiling lamp and whatever lamp stands in it.
		var own: Array = [hotel.lights[id]]
		for lamp in hotel.practicals + hotel.sconce_lights:
			if FLOOR.room_at(level.manifest.rooms, lamp.global_position).get("id", -1) == id: own.append(lamp)
		# (By their strength: the floor decides four times a second which lamps
		# are lit, and would light them again.)
		var were: Array = own.map(func(lamp): return lamp.light_energy)
		for lamp in own: lamp.light_energy = 0.0
		var said := false
		for way in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var half: float = (span.y if absf(way.z) > 0.5 else span.x) * 0.5
			var foot: Vector3 = centre + way * (half - 0.4) + Vector3(0, 0.05, 0)
			var mean := await seen(eye, foot)
			if peak > 0.02:
				if not said: print("LEAK_FEET room ", id, " type=", room.type, " size=", span, " layer=%x" % int(hotel.room_layers.layer[id]))
				said = true
				found += 1
				await seen(eye, foot, "leak_feet_%d_%d" % [id, found])
				print("   towards ", way, ": mean ", snappedf(mean, 0.00001), " brightest ", snappedf(peak, 0.0001), " -> evidence/leak_feet_%d_%d.png" % [id, found])
				var most := peak
				for group in [["ceiling", hotel.lights], ["wall", hotel.sconce_lights], ["furniture", hotel.practicals], ["exit", hotel.exit_lamps]]:
					for lamp in group[1]:
						if not lamp.is_visible_in_tree() or lamp.global_position.distance_to(eye) > 30.0: continue
						if lamp in own: continue
						var strength: float = lamp.light_energy
						lamp.light_energy = 0.0
						await seen(eye, foot)
						lamp.light_energy = strength
						if peak < most * 0.6:
							var home: Dictionary = FLOOR.room_at(level.manifest.rooms, lamp.global_position)
							print("      a ", group[0], " lamp ", (lamp.global_position - eye).snapped(Vector3(0.1, 0.1, 0.1)), " in room ", home.get("id", -1), " type ", home.get("type", -1), ": without it the brightest is ", snappedf(peak, 0.0001), " · casts=", lamp.shadow_enabled, " mask=%x" % lamp.light_cull_mask, " its room's layer=%x" % int(hotel.room_layers.layer[int(home.get("id", 0))]))
		for k in own.size(): own[k].light_energy = were[k]
	print("LEAK_FEET done, ", found, " walls with light on their feet")

## The lamps that hang or stand just on the far side of a room's walls (wall
## lamps, furniture lamps, exit signs): for each, the floor of this room under
## where it is, with the lamp lit and with it out. Whatever the floor gains
## with it lit came through the wall.
func behind_wall_lamps(types: Array) -> void:
	var hotel = level.hotel
	var worst := 0.0
	var checked := 0
	var tried := 0
	var kinds := {}
	var lamps: Array = []
	for group in [["wall", hotel.sconce_lights], ["furniture", hotel.practicals], ["exit", hotel.exit_lamps]]:
		for lamp in group[1]:
			kinds[lamp] = group[0]
			lamps.append(lamp)
	for room in level.manifest.rooms:
		if not int(room.type) in types or int(room.get("wing", 0)) != 0: continue
		var id := int(room.id)
		var centre := FLOOR.position_of(room)
		var span: Vector2 = FLOOR.size_of(room)
		var eye := centre + Vector3(0, 1.6, 0)
		level.player.global_position = eye
		hotel.update_visibility(eye, true)
		for i in 20: await process_frame
		hotel.update_visibility(eye, true)
		for i in 6: await process_frame
		for k in lamps.size():
			var lamp: Light3D = lamps[k]
			var at: Vector3 = lamp.global_position
			var off := Vector3(at.x - centre.x, 0, at.z - centre.z)
			# Outside this room, within half a metre of one of its walls.
			var past := Vector2(absf(off.x) - span.x * 0.5, absf(off.z) - span.y * 0.5)
			if not lamp.is_visible_in_tree() or absf(at.y - eye.y) > 3.0 or maxf(past.x, past.y) < 0.0 or maxf(past.x, past.y) > (0.6 if kinds[lamp] == "wall" else 1.2) or minf(past.x, past.y) > 0.0: continue
			# The floor of this room just inside that wall, under the lamp.
			var inward := Vector3(-signf(off.x), 0, 0) if past.x > past.y else Vector3(0, 0, -signf(off.z))
			var foot := Vector3(at.x, centre.y + 0.02, at.z) + inward * 0.9
			var from := foot + inward * 2.2 + Vector3(0, 1.6, 0)
			var strength: float = lamp.light_energy
			await seen(from, foot)
			var lit := peak
			lamp.light_energy = 0.0
			await seen(from, foot)
			var out := peak
			lamp.light_energy = strength
			checked += 1
			if lit - out > 0.02 and tried < 2 and lamp is OmniLight3D:
				# What of the lamp it is that lets it through: one thing changed at a time.
				tried += 1
				var kept := {"shadow_bias": lamp.shadow_bias, "shadow_normal_bias": lamp.shadow_normal_bias, "light_size": lamp.light_size, "omni_shadow_mode": lamp.omni_shadow_mode, "light_projector": lamp.light_projector, "rotation": lamp.rotation, "shadow_blur": lamp.shadow_blur}
				for change in [["no bias", {"shadow_bias": 0.0, "shadow_normal_bias": 0.0}], ["big bias", {"shadow_bias": 0.1, "shadow_normal_bias": 1.0}], ["point light", {"light_size": 0.0}], ["two paraboloids", {"omni_shadow_mode": OmniLight3D.SHADOW_DUAL_PARABOLOID}], ["no profile", {"light_projector": null}], ["turned 45", {"rotation": lamp.rotation + Vector3(0, PI / 4.0, 0), "light_projector": null}], ["no blur", {"shadow_blur": 0.0}]]:
					for key in change[1]: lamp.set(key, change[1][key])
					for i in 10: await process_frame
					await seen(from, foot, "leak_change_%d_%s" % [k, String(change[0]).replace(" ", "_")])
					print("      ", change[0], ": the floor reads ", snappedf(peak, 0.001), " (it read ", snappedf(lit, 0.001), " as it is, ", snappedf(out, 0.001), " without the lamp)")
					for key in kept: lamp.set(key, kept[key])
				for i in 10: await process_frame
			if lit - out > 0.02:
				worst = maxf(worst, lit - out)
				await seen(from, foot, "leak_behind_%d_%d" % [id, k])
				var home: Dictionary = FLOOR.room_at(level.manifest.rooms, at)
				print("LEAK_BEHIND room ", id, " type ", room.type, " layer=%x" % int(hotel.room_layers.layer[id]), ": ", kinds[lamp], " lamp ", k, " of room ", home.get("id", -1), " type ", home.get("type", -1), " layer=%x" % int(hotel.room_layers.layer[int(home.get("id", 0))]), " lights its floor: ", snappedf(lit, 0.001), " with it, ", snappedf(out, 0.001), " without · casts=", lamp.shadow_enabled, " mask=%x" % lamp.light_cull_mask, " -> evidence/leak_behind_%d_%d.png" % [id, k])
	print("LEAK_BEHIND done: ", checked, " lamps looked at from behind, worst gain ", snappedf(worst, 0.001))
