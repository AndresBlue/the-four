extends SceneTree
## Light that gets into a room it does not belong to. Every room whose lamps
## are out is looked at from its own middle, one wall at a time, and what the
## picture comes out at is measured; then the floor's power is cut and the
## same views are measured again. A dark room is supposed to be black either
## way, so whatever it gains with the lamps on came through a wall, a door or
## the baked bounce of the room next door.
##
## The camera is its own: a plain one on the same world, with none of the
## camcorder's stages (the auto-iris alone would hide or invent differences).
##
##   godot --path . --rendering-method forward_plus \
##       --script tools/dev/light_leak.gd -- --automation --seed=81 [--rooms=12] [--shots]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
var view: SubViewport
var lens: Camera3D
var shots := false

func _initialize() -> void: run.call_deferred()

## The worst of SAMPLES consecutive frames of what the plain camera sees from
## `from` towards `at`, and the picture it was measured from when one is asked
## for. Several frames because the thing being looked for comes and goes: a
## lamp over the shadow atlas is drawn without its shadow for a frame here and
## a frame there, and one frame would catch it or miss it by luck.
const SAMPLES := 10
var brightest := 0.0
func brightness(from: Vector3, at: Vector3, keep := "") -> float:
	lens.global_position = from
	lens.look_at(at, Vector3.UP)
	# The level culls rooms round its own listener once a quarter second; the
	# body goes where the camera is so the two agree on what is drawn, and a
	# room does not fall out of the picture halfway through a measurement.
	level.player.global_position = from
	level.hotel.update_visibility(from, true)
	# Room culling, the shadow atlas and the probes all settle over a few
	# frames; reading the picture too early reads the one before this one.
	for i in 8: await process_frame
	var worst := 0.0
	brightest = 0.0
	for sample in SAMPLES:
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := view.get_texture().get_image()
		var shot_here := picture.duplicate()
		picture.convert(Image.FORMAT_RGBF)
		var total := 0.0
		# Every eighth pixel each way: the point is the level of the room, not
		# where in the frame it is.
		var count := 0
		for y in range(0, picture.get_height(), 8):
			for x in range(0, picture.get_width(), 8):
				var pixel := picture.get_pixel(x, y)
				total += pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
				count += 1
		var mean := total / maxf(1.0, float(count))
		if mean > worst:
			worst = mean
			if not keep.is_empty(): shot_here.save_png("res://evidence/%s.png" % keep)
	brightest = worst
	return worst

## The worst of the four walls, which is where a leak shows. With --shots the
## picture of that wall is kept, which is the only way to tell what is lighting
## it.
func worst_wall(room: Dictionary, tag := "") -> float:
	var centre := FLOOR.position_of(room)
	var eye := centre + Vector3(0, 1.6, 0)
	var most := 0.0
	var worst := Vector3.FORWARD
	for way in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var level_here := await brightness(eye, eye + way * 4.0)
		if level_here > most:
			most = level_here
			worst = way
	if shots and not tag.is_empty():
		await brightness(eye, eye + worst * 4.0, "leak_%s_%d" % [tag, int(room.id)])
		var lamps := 0
		for lamp in level.hotel.lights: if lamp.visible: lamps += 1
		var walls := 0
		for lamp in level.hotel.sconce_lights: if lamp.visible: walls += 1
		var tables := 0
		for lamp in level.hotel.practicals: if lamp.visible: tables += 1
		print("      · el peor muro de la sala %d: media %.5f, el píxel más claro %.5f · con sombra a la vez: %d de techo, %d apliques, %d de mueble (%d)" % [
			int(room.id), most, brightest, lamps, walls, tables, lamps + walls + tables])
		# And the same view with a torch on it, which is the only way to see
		# what is actually there: a wall, a doorway, or a room that should not
		# be visible from here at all.
		level.player.rotation.y = atan2(-worst.x, -worst.z)
		level.player.torch.visible = true
		level.player.snap_torch()
		await brightness(eye, eye + worst * 4.0, "leak_%s_%d_torch" % [tag, int(room.id)])
		level.player.torch.visible = false
	return most

func run() -> void:
	var run_seed := 81
	var wanted := 12
	var without := []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--without="): without = Array(argument.trim_prefix("--without=").split(","))
		if argument.begins_with("--seed="): run_seed = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--rooms="): wanted = int(argument.trim_prefix("--rooms="))
		if argument == "--shots": shots = true
	DisplayServer.window_set_size(Vector2i(640, 360))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(run_seed)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	level.player.torch.visible = false
	# The body is lit like anything else and would be in every shot.
	level.player.visible = false
	# The bounce is baked on worker threads while the floor starts: measuring
	# before it lands would be measuring half a floor.
	while level.hotel.bounce.baking(): await process_frame
	for i in 60: await physics_frame
	view = SubViewport.new()
	view.size = Vector2i(960, 540)
	view.world_3d = level.get_viewport().world_3d
	view.own_world_3d = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	lens = Camera3D.new()
	lens.fov = 78.0
	lens.far = 95.0
	view.add_child(lens)
	lens.current = true
	# Every door shut: light through an open doorway is light doing its job.
	for door in level.hotel.doors:
		if door.opened: door.set_state(false)
	for i in 30: await physics_frame
	# Put out for good, not just hidden: update_visibility() writes `visible`
	# on every lamp of the floor each time it runs, so anything switched off
	# here has to be taken out of its list as well (the ceiling lamps have
	# their own way of staying out: the `off` mark the dark rooms use).
	if without.has("bounce") and is_instance_valid(level.hotel.bounce):
		level.hotel.bounce.show_near(Vector3(0, -9000, 0), false)
		level.hotel.bounce.volumes.clear()
	if without.has("practicals"):
		for lamp in level.hotel.practicals: lamp.visible = false
		level.hotel.practicals.clear()
	if without.has("sconces"):
		for lamp in level.hotel.sconce_lights: lamp.visible = false
		level.hotel.sconce_lights.clear()
	if without.has("lamps"):
		for lamp in level.hotel.lights: lamp.set_meta("off", true)
	if without.has("probes"):
		for slot in level.hotel.probe_slots:
			if slot.probe != null: level.hotel.drop_probe(slot)
		level.hotel.probe_slots.clear()
	if without.has("glows"):
		for material in level.hotel.held_glows(): material.emission_energy_multiplier = 0.0
		for sconce in level.hotel.lit_sconces: level.hotel.switch_off(sconce)
		for panel in level.hotel.exit_panels: panel.set_shader_parameter("level", 0.0)
	var darks: Array = level.manifest.rooms.filter(func(room): return level.hotel.lights[int(room.id)].has_meta("off"))
	print("LEAK piso %d · %d salas, %d a oscuras%s" % [run_seed, level.manifest.rooms.size(), darks.size(),
		("" if without.is_empty() else " · sin " + ", ".join(without))])
	var rooms: Array = darks.slice(0, wanted)
	var lit := {}
	for room in rooms: lit[int(room.id)] = await worst_wall(room, "lit")
	# Nothing lighting the floor at all: what each of these rooms reads when
	# there is nothing to leak.
	level.hotel.blackout(true)
	var cut := {}
	for room in rooms: cut[int(room.id)] = await worst_wall(room)
	level.hotel.blackout(false)
	var rows := []
	for id in lit: rows.append({"id": id, "lit": lit[id], "cut": cut[id]})
	rows.sort_custom(func(a, b): return (a.lit - a.cut) > (b.lit - b.cut))
	for row in rows:
		print("   sala %3d · con las lámparas %.5f · sin corriente %.5f · de más %+.5f (%.0f %%)" % [
			row.id, row.lit, row.cut, row.lit - row.cut,
			100.0 * (row.lit / maxf(row.cut, 0.00001) - 1.0)])
	var gained := rows.map(func(row): return row.lit - row.cut)
	gained.sort()
	print("LEAK_WORST %.5f · LEAK_MEDIAN %.5f" % [gained[gained.size() - 1], gained[gained.size() / 2]])
	quit()
