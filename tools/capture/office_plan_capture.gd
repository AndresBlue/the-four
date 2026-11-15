extends "res://tools/capture/office_rooms_capture.gd"
## The real plan (.claude/specs/planta_real.md 13) seen in play: a floor of it
## put up as the game does, every room lit, and three pictures with the game's
## own camera on the first planta: a stretch of the ring corridor looked down,
## an office one bay wide (3.6 m) from its doorway, and the service gallery
## looked down; then from their doorways the reception, a nave, a core's
## toilets, an archive of the second planta and a director's office of the
## third. With a window:
##   godot --path . --script res://tools/capture/office_plan_capture.gd --log-file <log> -- --automation --test-profile --silent --real-plan [--seed=7] [--quality=2]
## Writes evidence/planta/capturas/<seed>_{anillo,despacho,galeria,...}.png. Quits
## saying so when the floor that came up is not the real plan's.
## How far down a corridor the eye looks.
const DOWN := 20.0

## The rooms capture's lighting, framing and grabbing, with a run of its own.
func _initialize() -> void: plan_run.call_deferred()

func plan_run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var seed_value := 7
	var quality := 2
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
	var out_dir := "res://evidence/planta/capturas"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	level.settings.values = level.settings.DEFAULTS.duplicate()
	level.settings.set_designed(quality)
	level.creature_scene = "none"
	await level.start_floor(seed_value, false, [1], "apacible", 2)
	level.apply_settings()
	await level.bounce_ready()
	var manifest: Dictionary = level.manifest
	print("PLAN_CAPTURE seed %d fallback %s plan %s" % [seed_value, str(manifest.get("fallback", false)), str(manifest.get("plans", [{}])[0].get("plan", ""))])
	if bool(manifest.get("fallback", false)):
		# The game put up the standby floor: the real one is put up here anyway,
		# as the game would, and what its physical checks say is printed.
		var drawn: Dictionary = level.kind.GENERATOR.new().generate(seed_value, 1)
		if bool(drawn.get("fallback", false)):
			print("PLAN_CAPTURE the generator gave the standby floor")
			quit(1)
			return
		level.remove_child(level.hotel)
		level.hotel.queue_free()
		level.manifest = drawn
		level.tv_sets = level.settle_objectives(1).get("televisions", {})
		await level.mount_geometry("apacible")
		await physics_frame
		await physics_frame
		level.validate_floor_physics()
		print("PLAN_CAPTURE physical %s" % str(level.physical_errors))
		level.player.position = Vector3(0, 0.04, 0)
		manifest = drawn
		await level.bounce_ready()
	DisplayServer.window_set_size(Vector2i(1200, 800))
	for i in 30: await process_frame
	level.player.set_physics_process(false)
	level.player.torch.visible = false
	light_all()
	await bake_bounce()
	var rooms: Array = manifest.rooms.filter(func(r): return int(r.wing) == 0 and not FLOOR.is_void(r))
	# The ring: a corridor cell across a module, a cross corridor at its west end, looked east.
	var ring: Array = rooms.filter(func(r): return int(r.type) == OFFICE.CORRIDOR and String(r.kind) == "lane" and float(r.span_z) < 3.5 and float(r.span_x) >= 3.5)
	ring.sort_custom(func(a, b): return float(a.px) < float(b.px) or (float(a.px) == float(b.px) and int(a.id) < int(b.id)))
	await down(ring, out_dir + "/%d_anillo.png" % seed_value)
	# An office one bay wide, from its doorway.
	var offices: Array = rooms.filter(func(r): return int(r.type) == OFFICE.OFFICE and minf(float(r.span_x), float(r.span_z)) < 3.7 and int(r.hall) < 0)
	if offices.is_empty(): print("PLAN_CAPTURE no office of 3.6")
	else:
		var room: Dictionary = offices[0]
		var door: Dictionary = FRAMING.door_of(manifest.rooms, room)
		open_doors(door.portal)
		var hidden: Array = hide_leaves(door.portal)
		var view := FRAMING.view_of(room, door)
		look(view.from, view.at)
		(await grab(false)).save_png(out_dir + "/%d_despacho.png" % seed_value)
		for mesh in hidden: mesh.visible = true
		print("PLAN_CAPTURE despacho %d %.1f x %.1f" % [int(room.id), float(room.span_x), float(room.span_z)])
	# The gallery, looked down from its west end.
	var gallery: Array = rooms.filter(func(r): return int(r.type) == OFFICE.GALLERY and float(r.span_z) < 3.0)
	gallery.sort_custom(func(a, b): return float(a.px) < float(b.px) or (float(a.px) == float(b.px) and int(a.id) < int(b.id)))
	await down(gallery, out_dir + "/%d_galeria.png" % seed_value)
	# And from their doorways: the reception, a nave, a core's toilets, an
	# archive of the second planta and a director's office of the third.
	var all: Array = manifest.rooms.filter(func(r): return not FLOOR.is_void(r))
	await inside(manifest, all.filter(func(r): return int(r.id) == int(manifest.start)), out_dir + "/%d_recepcion.png" % seed_value)
	await inside(manifest, all.filter(func(r): return int(r.wing) == 0 and int(r.type) in [OFFICE.OPEN_OFFICE, OFFICE.CUBICLES] and int(r.hall) >= 0), out_dir + "/%d_nave.png" % seed_value)
	await inside(manifest, all.filter(func(r): return int(r.wing) == 0 and int(r.type) == OFFICE.TOILETS), out_dir + "/%d_aseos.png" % seed_value)
	await inside(manifest, all.filter(func(r): return int(r.wing) == 1 and int(r.type) == OFFICE.ARCHIVE and int(r.hall) >= 0), out_dir + "/%d_archivo.png" % seed_value)
	await inside(manifest, all.filter(func(r): return int(r.wing) == 2 and int(r.type) == OFFICE.EXEC_OFFICE), out_dir + "/%d_direccion.png" % seed_value)
	quit()

## The first of `rooms` with a doorway, looked into from it.
func inside(manifest: Dictionary, rooms: Array, path: String) -> void:
	# A cell with a doorway of its own first: a salon's others only open on to it.
	rooms.sort_custom(func(a, b): return FLOOR.doorways(a).size() > FLOOR.doorways(b).size())
	for room in rooms:
		var door: Dictionary = FRAMING.door_of(manifest.rooms, room)
		open_doors(door.portal)
		var hidden: Array = hide_leaves(door.portal)
		var view := FRAMING.view_of(room, door)
		look(view.from, view.at)
		(await grab(false)).save_png(path)
		for mesh in hidden: mesh.visible = true
		print("PLAN_CAPTURE %s from %d (%s %.1f x %.1f)" % [path, int(room.id), OFFICE.label(room), float(room.span_x), float(room.span_z)])
		return
	print("PLAN_CAPTURE nothing for %s" % path)

## Looking east down the first stretch of `cells` (sorted west to east) from the
## middle of its second cell, at eye height.
func down(cells: Array, path: String) -> void:
	if cells.size() < 2:
		print("PLAN_CAPTURE nothing for %s" % path)
		return
	var start: Dictionary = cells[1]
	var from := FLOOR.position_of(start) + Vector3(0, FRAMING.EYE, 0)
	var at := from + Vector3(DOWN, 0, 0)
	for door in level.hotel.doors_near(from + Vector3(DOWN * 0.5, 0, 0), DOWN * 0.5):
		if door.has_method("open_immediately"): door.open_immediately()
	look(from, at)
	(await grab(false)).save_png(path)
	print("PLAN_CAPTURE %s from %d" % [path, int(start.id)])
