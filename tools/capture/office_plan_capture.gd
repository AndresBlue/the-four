extends "res://tools/capture/office_rooms_capture.gd"
## The real plan (.claude/specs/planta_real.md 13) seen in play: a floor of it
## put up as the game does, every room lit, and three pictures with the game's
## own camera on the first planta: a stretch of the ring corridor looked down,
## an office one bay wide (3.6 m) from its doorway, and the service gallery
## looked down; then the reception from its doorway, the biggest nave down its
## aisle, the window from across its corridor (its glass and its wait) and from
## its doorway; from their doorways a core's toilets, an archive of the second
## planta and a director's office of the third; the reception from its lift's
## doors, a director's office from its secretary's, the third's boardroom and
## its security post from the corridor, on the side away from its door; the
## reception towards its lift; the third's central zone, a director's office of
## two bays and the corridor along it.
## With a window:
##   godot --path . --script res://tools/capture/office_plan_capture.gd --log-file <log> -- --automation --test-profile --silent --real-plan [--seed=7] [--quality=2] [--survivors=1] [--out=evidence/planta/capturas]
## Writes <out>/<seed>_{anillo,despacho,galeria,...}.png. Quits
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
	var survivors := 1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--survivors="): survivors = int(argument.trim_prefix("--survivors="))
	var out_dir := "res://evidence/planta/capturas"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out_dir = "res://" + argument.trim_prefix("--out=").trim_prefix("res://")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	level.settings.values = level.settings.DEFAULTS.duplicate()
	level.settings.set_designed(quality)
	level.creature_scene = "none"
	await level.start_floor(seed_value, false, range(1, survivors + 1), "apacible", 2)
	level.apply_settings()
	await level.bounce_ready()
	var manifest: Dictionary = level.manifest
	print("PLAN_CAPTURE seed %d fallback %s plan %s" % [seed_value, str(manifest.get("fallback", false)), str(manifest.get("plans", [{}])[0].get("plan", ""))])
	if bool(manifest.get("fallback", false)):
		# The game put up the standby floor: the real one is put up here anyway,
		# as the game would, and what its physical checks say is printed.
		var drawn: Dictionary = level.kind.GENERATOR.new().generate(seed_value, survivors)
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
	# A nave down its length from its aisle at one end, its islands either side.
	var nave_cells: Array = all.filter(func(r): return int(r.wing) == 0 and int(r.type) in [OFFICE.OPEN_OFFICE, OFFICE.CUBICLES] and int(r.hall) >= 0)
	var halls := {}
	for r in nave_cells: halls[int(r.hall)] = int(halls.get(int(r.hall), 0)) + 1
	var biggest := -1
	for h in halls:
		if biggest < 0 or int(halls[h]) > int(halls[biggest]): biggest = int(h)
	if biggest >= 0:
		var cells: Array = nave_cells.filter(func(r): return int(r.hall) == biggest)
		var low := INF
		var high := -INF
		var mid := 0.0
		for r in cells:
			low = minf(low, float(r.px) - float(r.span_x) * 0.5)
			high = maxf(high, float(r.px) + float(r.span_x) * 0.5)
			mid += float(r.pz) / cells.size()
		var from := Vector3(low + 0.6, FRAMING.EYE + 0.4, mid)
		look(from, Vector3(high, 0.9, mid))
		(await grab(false)).save_png(out_dir + "/%d_nave.png" % seed_value)
		print("PLAN_CAPTURE nave %d, %d celdas, %.1f m" % [biggest, cells.size(), high - low])
	# The window: from the corridor, its glass and its wait; and inside, from its doorway.
	for w in all.filter(func(r): return int(r.wing) == 0 and int(r.type) == OFFICE.WINDOW):
		for n in manifest.adjacency[int(w.id)]:
			var c: Dictionary = manifest.rooms[int(n)]
			if not bool(c.get("corridor", false)): continue
			var portal := FLOOR.portal_between(w, c)
			var out := FLOOR.position_of(c) - FLOOR.position_of(w)
			out.y = 0.0
			out = out.normalized()
			var along := Vector3(out.z, 0, -out.x)
			# Along the corridor from a few metres off, by the counter's wall: its
			# glass to one side and the wait on the wall across from its doorway.
			var wide := minf(float(c.span_x), float(c.span_z))
			# Toward the side the corridor goes on.
			for way in [along, -along]:
				var spot := FLOOR.room_at(manifest.rooms, Vector3(portal.x, 0.5, portal.z) + out * 0.7 + way * 3.5)
				if not spot.is_empty() and bool(spot.get("corridor", false)):
					along = way
					break
			var from := Vector3(portal.x, 0, portal.z) + out * 0.7 + along * 3.5 + Vector3(0, FRAMING.EYE, 0)
			look(from, Vector3(portal.x, 0.6, portal.z) + out * wide * 0.85 - along * 0.5)
			var wait: Array = []
			for r in manifest.rooms.filter(func(r): return int(r.wing) == 0 and bool(r.get("corridor", false))):
				for it in r.get("furniture", []):
					var at_it := Vector3(float(r.px) + float(it.at[0]), 0, float(r.pz) + float(it.at[1]))
					if String(it.kind) == "bench_slat" and at_it.distance_to(Vector3(portal.x, 0, portal.z)) < 5.0: wait.append(snappedf(at_it.distance_to(Vector3(portal.x, 0, portal.z)), 0.1))
			print("PLAN_CAPTURE bancos a menos de 5 m de la puerta de la ventanilla: %s" % str(wait))
			(await grab(false)).save_png(out_dir + "/%d_ventanilla_pasillo.png" % seed_value)
			print("PLAN_CAPTURE ventanilla %d desde %d (%.1f x %.1f)" % [int(w.id), int(n), float(w.span_x), float(w.span_z)])
			break
		await inside(manifest, [w], out_dir + "/%d_ventanilla.png" % seed_value)
	await inside(manifest, all.filter(func(r): return int(r.wing) == 0 and int(r.type) == OFFICE.TOILETS), out_dir + "/%d_aseos.png" % seed_value)
	await inside(manifest, all.filter(func(r): return int(r.wing) == 1 and int(r.type) == OFFICE.ARCHIVE and int(r.hall) >= 0), out_dir + "/%d_archivo.png" % seed_value)
	await inside(manifest, all.filter(func(r): return int(r.wing) == 2 and int(r.type) == OFFICE.EXEC_OFFICE), out_dir + "/%d_direccion.png" % seed_value)
	# The reception as the hotel's lift opens on it: from just inside its doors.
	var start: Dictionary = manifest.rooms[int(manifest.start)]
	if manifest.has("arrival_lift"):
		var way := Vector3(float(manifest.arrival_lift[0]), 0, float(manifest.arrival_lift[1]))
		var reach: float = (float(start.span_x) if absf(way.x) > 0.5 else float(start.span_z)) * 0.5 - 0.5
		var from := FLOOR.position_of(start) + way * reach + Vector3(0, FRAMING.EYE, 0)
		look(from, from - way * 6.0 - Vector3(0, 0.3, 0))
		(await grab(false)).save_png(out_dir + "/%d_recepcion_ascensor.png" % seed_value)
		print("PLAN_CAPTURE recepcion desde el ascensor %d" % int(start.id))
		# And the other way: from its far wall towards the lift, the reference's view.
		var back := FLOOR.position_of(start) - way * reach + Vector3(0, FRAMING.EYE, 0)
		look(back, back + way * 6.0 - Vector3(0, 0.2, 0))
		(await grab(false)).save_png(out_dir + "/%d_recepcion_hacia_ascensor.png" % seed_value)
		print("PLAN_CAPTURE recepcion hacia el ascensor %d (%.1f x %.1f)" % [int(start.id), float(start.span_x), float(start.span_z)])
	# Dirección: a director's office seen from its secretary's, the door between open.
	for s in all.filter(func(r): return int(r.wing) == 2 and int(r.type) == OFFICE.SECRETARY):
		var exec := -1
		for n in manifest.adjacency[int(s.id)]:
			if int(manifest.rooms[int(n)].type) == OFFICE.EXEC_OFFICE: exec = int(n)
		if exec < 0: continue
		var e: Dictionary = manifest.rooms[exec]
		var portal := FLOOR.portal_between(s, e)
		open_doors(portal)
		var hidden: Array = hide_leaves(portal)
		var into := (portal - FLOOR.position_of(s))
		into.y = 0.0
		var from := portal - into.normalized() * minf(into.length() + 1.0, 3.2) + Vector3(0, FRAMING.EYE, 0)
		look(from, FLOOR.position_of(e) + Vector3(0, 1.1, 0))
		(await grab(false)).save_png(out_dir + "/%d_suite.png" % seed_value)
		for mesh in hidden: mesh.visible = true
		print("PLAN_CAPTURE suite: secretaria %d, direccion %d" % [int(s.id), exec])
		break
	await inside(manifest, all.filter(func(r): return int(r.wing) == 2 and int(r.type) == OFFICE.BOARDROOM), out_dir + "/%d_juntas.png" % seed_value)
	# Dirección's central zone: a director's office of two bays from its doorway,
	# and the main corridor along the zone, its doors.
	var central: Array = all.filter(func(r): return int(r.wing) == 2 and int(r.type) == OFFICE.EXEC_OFFICE and int(r.hall) >= 0 and minf(float(r.span_x), float(r.span_z)) > 7.1)
	await inside(manifest, central, out_dir + "/%d_central_direccion.png" % seed_value)
	for c in central:
		var lane: Dictionary = {}
		for n in manifest.adjacency[int(c.id)]:
			if bool(manifest.rooms[int(n)].get("corridor", false)) and float(manifest.rooms[int(n)].span_z) < 3.5: lane = manifest.rooms[int(n)]
		if lane.is_empty(): continue
		var line: Array = all.filter(func(r): return int(r.wing) == 2 and bool(r.get("corridor", false)) and is_equal_approx(float(r.pz), float(lane.pz)))
		line.sort_custom(func(a, b): return float(a.px) < float(b.px))
		await down(line, out_dir + "/%d_central_pasillo.png" % seed_value)
		break
	# The security post from the corridor it is come to by.
	for post in all.filter(func(r): return int(r.wing) == 2 and int(r.type) == OFFICE.SECURITY):
		for n in manifest.adjacency[int(post.id)]:
			var c: Dictionary = manifest.rooms[int(n)]
			if not bool(c.get("corridor", false)): continue
			var across := FLOOR.position_of(c) - FLOOR.position_of(post)
			across.y = 0.0
			var along := Vector3(across.z, 0, -across.x).normalized()
			# From the side away from its door, whose leaf is hidden: the glass whole.
			var portal := FLOOR.portal_between(post, c)
			if (portal - FLOOR.position_of(post)).dot(along) > 0.0: along = -along
			var hidden: Array = hide_leaves(portal)
			var from := FLOOR.position_of(c) + across.normalized() * 0.6 + along * 3.0 + Vector3(0, FRAMING.EYE, 0)
			look(from, FLOOR.position_of(post) - along * 0.8 + Vector3(0, 1.3, 0))
			(await grab(false)).save_png(out_dir + "/%d_seguridad.png" % seed_value)
			for mesh in hidden: mesh.visible = true
			print("PLAN_CAPTURE seguridad %d desde %d, cristal %s" % [int(post.id), int(n), str(post.get("glazed", []))])
			break
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
