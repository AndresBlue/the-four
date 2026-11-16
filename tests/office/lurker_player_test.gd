extends SceneTree
## Phase 0 of The Lurker in Versus (.claude/specs/lurker_versus.md 11): her
## body driven by a person, here by a script that writes her driver's stick,
## look and buttons (lurker_player.gd, scripted). On floor 2, on each planta:
## over a ceiling and back; through a door and back; into an archive's aisle
## and out; into a grille and out by it; into a tile, through the ducts to
## another room and back; let down and up. Never stuck (each ends within its
## time), never through a wall (a ray between her anchors, tick to tick, off
## any logged jump), her eye never in a wall. evidence/versus/f0/conductor.json
## and conductor.txt.
## With --shots, and a window: her camera's view at Alto on each planta (a
## ceiling, over a door head, in an aisle, let down), evidence/versus/f0/.
##   godot [--headless] --fixed-fps 60 --path . --script res://tests/office/lurker_player_test.gd -- --automation --test-profile --silent [--seed=81] [--shots]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const PLAYER := preload("res://game/enemies/lurker/lurker_player.gd")
const DT := 1.0 / 60.0
const OUT := "res://evidence/versus/f0/"
var checks: Array = []
var failed := 0
var lines: Array = []
var level
var lurker
var driver
var shell
var shots := false

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, "  (" + detail + ")" if not detail.is_empty() else "")
	lines.append(("PASS " if passed else "FAIL ") + title + ("  (" + detail + ")" if not detail.is_empty() else ""))

func run() -> void:
	var seed_value := 81
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	shots = OS.get_cmdline_user_args().has("--shots") and DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if shots: DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	if shots: level.ui.finish_intro()
	level.creature_scene = "lurker"
	await level.start_floor(seed_value, false, [1], "desafiante", 2)
	lurker = level.creature
	shell = lurker.shell
	# Hers to drive from this machine, as --bots-hunt does; the survivor parked
	# out of the way, nothing leading her.
	level.solo_locust = true
	level.hand_creature_to_player()
	driver = lurker.driver
	driver.scripted = true
	lurker.grace = 0.0
	level.player.active = false
	level.player.held = true
	level.player.global_position = Vector3(0, -60, 0)
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	if shots:
		level.settings.values.quality = 2
		level.apply_settings()
	check("Lleva su cuerpo un conductor: control de jugador y su cámara", lurker.control == "player" and driver != null and lurker.hunter_camera() != null)
	for planta in 3:
		lines.append("--- planta %d" % (planta + 1))
		await ceiling_case(planta)
		await door_case(planta)
		await aisle_case(planta)
		await grille_case(planta)
		await tile_case(planta)
		await drop_case(planta)
		if shots: await shots_of(planta)
	var file := FileAccess.open(OUT + "conductor.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"seed": seed_value, "checks": checks}, "\t"))
	var text := FileAccess.open(OUT + "conductor.txt", FileAccess.WRITE)
	if text != null:
		for line in lines: text.store_line(line)
	print("LURKER_PLAYER_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

# --- Driving ------------------------------------------------------------------------

func motion(): return lurker.motion

## Looks flat along a world direction.
func face(way: Vector3, pitch := -0.2) -> void:
	if Vector2(way.x, way.z).length() > 1e-4: driver.yaw = atan2(-way.x, -way.z)
	driver.pitch = pitch

## On her ceiling over a plan point of a room, looking along `way`.
func put(room: int, x: float, z: float, way := Vector3.FORWARD) -> void:
	var r: Dictionary = level.manifest.rooms[room]
	lurker.teleport(Vector3(x, float(r.get("py", 0.0)) + 1.0, z), atan2(-way.x, -way.z), &"conductor")
	face(way)
	for i in 3: await physics_frame

## Ticks with the stick forward (toward `aim` each tick, if not INF), these
## buttons pressed on the first, until `done` or `seconds`. What was seen:
## {ok, seconds, kinds, through (walls crossed), eye (eye in a wall), rooms}.
func go(seconds: float, done: Callable, aim := Vector3.INF, presses: Array = [], stick := Vector2(0, -1)) -> Dictionary:
	var seen := {"ok": false, "seconds": 0.0, "kinds": {}, "through": [], "eye": 0, "rooms": {}}
	for press in presses: driver.asked[press] = true
	driver.axis = stick
	var last: Vector3 = motion().anchor()
	var jumps: int = motion().jump_id
	var space: PhysicsDirectSpaceState3D = lurker.get_world_3d().direct_space_state
	for i in int(seconds / DT):
		if aim != Vector3.INF and motion().legs.is_empty(): face(aim - motion().anchor(), driver.pitch)
		await physics_frame
		seen.seconds += DT
		var m = motion()
		if not m.legs.is_empty(): seen.kinds[String(m.legs[0].kind)] = true
		var now: Vector3 = m.anchor()
		if m.surface():
			seen.rooms[m.room()] = true
			if m.jump_id == jumps and last.distance_to(now) > 1e-4:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(last, now, 1, [lurker.get_rid()]))
				if not hit.is_empty() and seen.through.size() < 5: seen.through.append([snapped_point(last), snapped_point(now)])
			# Her camera's eye (lurker_player.eye_now()), from her anchor.
			var eye: Vector3 = driver.eye_to if driver.eye_to != Vector3.INF else lurker.face_point()
			var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(now, eye, 1, [lurker.get_rid()]))
			if not blocked.is_empty():
				seen.eye += 1
				if int(seen.eye) == 1: seen["eye_hit"] = [str(blocked.collider.name) if blocked.collider is Node else "?", snapped_point(blocked.position), snapped_point(now), snapped_point(eye)]
		jumps = m.jump_id
		last = now
		if done.call():
			seen.ok = true
			break
	driver.axis = Vector2.ZERO
	return seen

static func snapped_point(p: Vector3) -> Array: return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]

## Settled on a surface (or in a duct) with no order running.
func free_on(room := -1) -> bool:
	var m = motion()
	return m.legs.is_empty() and m.surface() and (room < 0 or m.room() == room)

func clean(seen: Dictionary) -> bool: return seen.through.is_empty() and int(seen.eye) == 0

func said(seen: Dictionary) -> String:
	return "%.1f s, tramos %s, muros %s, ojo en muro %d%s" % [float(seen.seconds), str(seen.kinds.keys()), str(seen.through), int(seen.eye), (" " + str(seen.eye_hit)) if seen.has("eye_hit") else ""]

func rooms_of(planta: int) -> Array:
	var out: Array = []
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) == planta and shell.tray_of.has(int(room.id)): out.append(int(room.id))
	return out

func tray_rect(room: int) -> Rect2: return shell.patches[int(shell.tray_of[room])].rect

## The biggest ceiling of the planta with no columns and no aisles, offices first.
func big_room(planta: int) -> int:
	var best := -1
	var best_area := 0.0
	for room in rooms_of(planta):
		if shell.columns_of.has(room) or shell.channels_of.has(room): continue
		var area: float = tray_rect(room).get_area() * (2.0 if int(level.manifest.rooms[room].type) in [OFFICE.OPEN_OFFICE, OFFICE.OFFICE, OFFICE.CUBICLES] else 1.0)
		if area > best_area:
			best_area = area
			best = room
	return best

# --- The cases ------------------------------------------------------------------------

## Over the biggest ceiling of the planta to its far side and back.
func ceiling_case(planta: int) -> void:
	var room := big_room(planta)
	var rect := tray_rect(room)
	var a := rect.position + rect.size * 0.2
	var b := rect.position + rect.size * 0.8
	await put(room, a.x, a.y, Vector3(b.x - a.x, 0, b.y - a.y))
	var y: float = motion().anchor().y
	var there: Dictionary = await go(8.0, func() -> bool: return Vector2(motion().anchor().x, motion().anchor().z).distance_to(b) < 0.4, Vector3(b.x, y, b.y))
	var back: Dictionary = await go(8.0, func() -> bool: return Vector2(motion().anchor().x, motion().anchor().z).distance_to(a) < 0.4, Vector3(a.x, y, a.y))
	check("P%d techo: cruza la sala %d (%.1f m) y vuelve, sin atravesar nada" % [planta + 1, room, a.distance_to(b)], there.ok and back.ok and clean(there) and clean(back) and there.kinds.is_empty(), "ida %s; vuelta %s" % [said(there), said(back)])

## Through a door of the planta (opened for it if shut) and back.
func door_case(planta: int) -> void:
	var picked := Vector2i(-1, -1)
	var roomiest := 0.0
	for pair in shell.band_of_pair:
		var record: Dictionary = shell.patches[int(shell.band_of_pair[pair])]
		var a := int(record.rooms[0])
		var b := int(record.rooms[1])
		if int(level.manifest.rooms[a].get("wing", -1)) != planta or lurker.routes.door_nodes.get(pair) == null: continue
		var least: float = minf(minf(tray_rect(a).size.x, tray_rect(a).size.y), minf(tray_rect(b).size.x, tray_rect(b).size.y))
		if least > roomiest:
			roomiest = least
			picked = pair
	if picked.x < 0:
		check("P%d puerta: hay una entre dos techos" % [planta + 1], false)
		return
	var door = lurker.routes.door_nodes[picked]
	if not lurker.routes.door_open(picked): door.set_state(true)
	var band := int(shell.band_of_pair[picked])
	var record: Dictionary = shell.patches[band]
	var a := int(record.rooms[0])
	var b := int(record.rooms[1])
	var origin: Vector3 = record.origin
	var across: Vector3 = record.across
	var from_a := clamp_into(origin - across * 2.4, a)
	await put(a, from_a.x, from_a.y, across)
	var there: Dictionary = await go(12.0, func() -> bool: return free_on(b), origin)
	var shut_ok := true
	var back: Dictionary = await go(12.0, func() -> bool: return free_on(a), origin)
	# Shut, it stops her: pushed at it for three seconds she stays in her room.
	door.set_state(false)
	for i in 30: await physics_frame
	var stopped: Dictionary = await go(3.0, func() -> bool: return motion().room() != a, origin)
	shut_ok = not stopped.ok and not stopped.kinds.has("band")
	door.set_state(true)
	check("P%d puerta %d-%d: por encima del dintel a la otra sala y vuelve" % [planta + 1, a, b], there.ok and back.ok and there.kinds.has("band") and back.kinds.has("band") and clean(there) and clean(back), "ida %s; vuelta %s" % [said(there), said(back)])
	check("P%d puerta %d-%d cerrada: no pasa" % [planta + 1, a, b], shut_ok, said(stopped))

func clamp_into(p: Vector3, room: int) -> Vector2:
	var r := tray_rect(room).grow(-0.1)
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.z, r.position.y, r.end.y))

## Into an archive's aisle from its mouth, along it, and out.
func aisle_case(planta: int) -> void:
	var channel := -1
	for room in rooms_of(planta):
		if shell.channels_of.has(room):
			channel = int(shell.channels_of[room][0])
			break
	if channel < 0:
		lines.append("P%d canal: no hay archivo con pasillo en esta planta" % [planta + 1])
		return
	var record: Dictionary = shell.patches[channel]
	var room := int(record.room)
	var axis: Vector3 = record.axis
	var start := clamp_into((record.origin as Vector3) - axis * 0.6, room)
	await put(room, start.x, start.y, axis)
	var into: Dictionary = await go(10.0, func() -> bool: return motion().on_channel() and motion().legs.is_empty())
	var deep: float = motion().state.v if motion().on_channel() else 0.0
	var along: Dictionary = await go(1.0, func() -> bool: return false)
	var further: float = motion().state.v if motion().on_channel() else 0.0
	face(-axis)
	var out: Dictionary = await go(10.0, func() -> bool: return free_on() and not motion().on_channel())
	check("P%d canal de archivo (sala %d): entra, avanza por él y sale a su techo" % [planta + 1, room], into.ok and out.ok and further > deep + 0.3 and clean(into) and clean(along) and clean(out), "entra %s; avanza de %.2f a %.2f m, %s; sale %s" % [said(into), deep, further, said(along), said(out)])

## A way in of hers on the planta that is not a tile.
func grille_of(planta: int) -> int:
	var ducts = lurker.ducts
	for e in ducts.exits.size():
		var exit: Dictionary = ducts.exits[e]
		if String(exit.kind) == "tile" or not driver.usable(e) or int(ducts.node_wings[int(exit.node)]) != planta: continue
		return e
	return -1

## Into a grille looking at it, and out of it again looking out of it.
func grille_case(planta: int) -> void:
	var e := grille_of(planta)
	if e < 0:
		check("P%d rejilla: hay una suya" % [planta + 1], false)
		return
	var exit: Dictionary = lurker.ducts.exits[e]
	var room := int(exit.room)
	# A metre and a bit short of it, into her room, looking at it.
	var way: Vector2 = lurker.routes.exit_way(e)[0]
	var at: Vector3 = exit.position
	var inward := Vector2(float(level.manifest.rooms[room].px), float(level.manifest.rooms[room].pz)) - way
	var stand := way + (inward.normalized() * 1.2 if inward.length() > 0.01 else Vector2.ZERO)
	await put(room, stand.x, stand.y, Vector3(at.x - stand.x, 0, at.z - stand.y))
	driver.pitch = -0.3
	var into: Dictionary = await go(15.0, func() -> bool: return motion().in_duct and motion().legs.is_empty(), Vector3.INF, [&"lurker_enter"], Vector2.ZERO)
	# Her driver names the mouth on its next tick.
	await physics_frame
	var mouth: int = motion().mouth_exit
	var normal: Vector3 = exit.normal
	if absf(normal.y) > 0.9: face(Vector3.FORWARD, -1.4)
	else: face(normal, 0.0)
	var out: Dictionary = await go(15.0, func() -> bool: return free_on(room), Vector3.INF, [&"lurker_enter"], Vector2.ZERO)
	check("P%d rejilla %d (%s, sala %d): entra mirándola y sale por ella" % [planta + 1, e, String(exit.kind), room], into.ok and mouth == e and out.ok and into.kinds.has("squeeze") and out.kinds.has("squeeze") and clean(into) and clean(out), "entra %s, boca %d; sale %s" % [said(into), mouth, said(out)])

## Into a tile of a false ceiling, through the ducts to a way out of another
## room, and back to the first by the ducts again.
func tile_case(planta: int) -> void:
	var ducts = lurker.ducts
	# The false ceiling whose nearest grille is farthest from its middle.
	var room := -1
	var clear := -1.0
	for r in rooms_of(planta):
		if not ducts.room_tiles.has(r): continue
		var centre := FLOOR.position_of(level.manifest.rooms[r])
		var nearest := INF
		for e in ducts.exits.size():
			if String(ducts.exits[e].kind) != "tile": nearest = minf(nearest, Vector2((ducts.exits[e].position as Vector3).x - centre.x, (ducts.exits[e].position as Vector3).z - centre.z).length())
		if nearest > clear:
			clear = nearest
			room = r
	if room < 0:
		check("P%d placa: hay un falso techo" % [planta + 1], false)
		return
	var r: Dictionary = level.manifest.rooms[room]
	var p: Vector2 = shell.clear_point(room, float(r.px), float(r.pz))
	await put(room, p.x, p.y)
	# Looking up at it.
	driver.pitch = 1.2
	var into: Dictionary = await go(15.0, func() -> bool: return motion().in_duct and motion().legs.is_empty(), Vector3.INF, [&"lurker_enter"], Vector2.ZERO)
	await physics_frame
	var by_tile: bool = motion().mouth_exit >= 0 and String(ducts.exits[motion().mouth_exit].kind) == "tile"
	# Out by a way of another room 6 to 20 m off, looking towards it.
	var target := -1
	var here: Vector3 = motion().duct_point
	for e in ducts.exits.size():
		var exit: Dictionary = ducts.exits[e]
		if not driver.usable(e) or int(ducts.node_wings[int(exit.node)]) != planta or int(exit.room) == room: continue
		var d := Vector2((exit.position as Vector3).x - here.x, (exit.position as Vector3).z - here.z).length()
		if d >= 6.0 and d <= 20.0:
			target = e
			break
	if target < 0:
		check("P%d placa y ducto: hay otra salida a 6-20 m" % [planta + 1], false)
		return
	face((ducts.exits[target].position as Vector3) - here, 0.0)
	var away: Dictionary = await go(30.0, func() -> bool: return free_on() and motion().room() != room, Vector3.INF, [&"lurker_enter"], Vector2.ZERO)
	var landed: int = motion().room()
	# Back, as a player who sees nothing in there would: in by what is nearest
	# where she looks, out towards the first room, up to three times.
	var into_again := {}
	var home := {}
	for hop in 3:
		face(Vector3(p.x - motion().anchor().x, 0, p.y - motion().anchor().z), 0.0)
		into_again = await go(15.0, func() -> bool: return motion().in_duct and motion().legs.is_empty(), Vector3.INF, [&"lurker_enter"], Vector2.ZERO)
		face(Vector3(p.x - motion().duct_point.x, 0, p.y - motion().duct_point.z), 0.0)
		home = await go(30.0, func() -> bool: return free_on(), Vector3.INF, [&"lurker_enter"], Vector2.ZERO)
		lines.append("  vuelta %d: sale en la sala %d" % [hop + 1, motion().room()])
		if motion().room() == room or not into_again.ok or not home.ok: break
	check("P%d placa (sala %d): entra por una placa del falso techo" % [planta + 1, room], into.ok and by_tile and clean(into), "%s, por placa %s" % [said(into), str(by_tile)])
	check("P%d ducto: sale en otra sala mirando hacia ella (%d)" % [planta + 1, landed], away.ok and away.kinds.has("duct") and clean(away), said(away))
	check("P%d y vuelve por los ductos a la sala %d" % [planta + 1, room], into_again.ok and home.ok and motion().room() == room and clean(home), "entra %s; vuelve %s, en la sala %d" % [said(into_again), said(home), motion().room()])

## Let down and back up in the biggest room.
func drop_case(planta: int) -> void:
	var room := big_room(planta)
	var r: Dictionary = level.manifest.rooms[room]
	var p: Vector2 = shell.clear_point(room, float(r.px), float(r.pz))
	await put(room, p.x, p.y)
	await go(2.0, func() -> bool: return false, Vector3.INF, [&"lurker_drop"], Vector2.ZERO)
	var low: float = motion().state.hang
	var limit: float = motion().hang_limit
	await go(1.5, func() -> bool: return false, Vector3.INF, [&"lurker_drop"], Vector2.ZERO)
	var up: float = motion().state.hang
	check("P%d descolgada: baja hasta 1,5 m (o lo que deja el rayo) y vuelve a subir" % [planta + 1], low >= minf(SHELL.CUE_HANG_MAX, limit) - 0.05 and low > SHELL.HANG_MAX and up <= SHELL.DEFAULT_HANG + 0.05, "baja a %.2f (límite %.2f), sube a %.2f" % [low, limit, up])

# --- Pictures -------------------------------------------------------------------------

func shot(planta: int, title: String) -> void:
	var eye: Vector3 = driver.camera.global_position
	level.hotel.update_visibility(eye, true)
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "p%d_%s.png" % [planta + 1, title])
	lines.append("captura p%d_%s.png desde %s" % [planta + 1, title, str(snapped_point(eye))])

## Her view at Alto on the planta: a ceiling, over a door head, in an aisle,
## let down. Lit rooms first: in the dark there is little to see.
func shots_of(planta: int) -> void:
	var room := big_room(planta)
	for r in rooms_of(planta):
		if level.hotel.lit(r) and tray_rect(r).get_area() > 20.0:
			room = r
			break
	var rect := tray_rect(room)
	await put(room, rect.position.x + 1.0, rect.position.y + 1.0, Vector3(rect.size.x, 0, rect.size.y))
	face(Vector3(rect.size.x, 0, rect.size.y), -0.35)
	await shot(planta, "techo")
	for pair in shell.band_of_pair:
		var band := int(shell.band_of_pair[pair])
		var record: Dictionary = shell.patches[band]
		if int(level.manifest.rooms[int(record.rooms[0])].get("wing", -1)) != planta: continue
		var s = shell.band_start(band, int(record.rooms[0]))
		s.u = float(record.profile.length) / 2.0
		motion().state = s
		lurker.apply_motion()
		face(record.across, -0.3)
		for i in 3: await physics_frame
		await shot(planta, "dintel")
		break
	for r in rooms_of(planta):
		if not shell.channels_of.has(r): continue
		var channel := int(shell.channels_of[r][0])
		var record: Dictionary = shell.patches[channel]
		var mouth = shell.channel_mouth(channel)
		await put(r, (record.origin as Vector3).x, (record.origin as Vector3).z)
		# Where her driver holds her along an aisle: up a shelf.
		mouth.v = float(record.length) / 2.0
		mouth.u = shell.channel_u_on_wall(channel, 1.0, PLAYER.AISLE_HOLD)
		shell.clamp_state(mouth)
		motion().state = mouth
		lurker.apply_motion()
		face(record.axis, -0.15)
		for i in 3: await physics_frame
		await shot(planta, "canal")
		break
	await put(room, rect.get_center().x, rect.get_center().y, Vector3(rect.size.x, 0, rect.size.y))
	await go(2.0, func() -> bool: return false, Vector3.INF, [&"lurker_drop"], Vector2.ZERO)
	face(Vector3(rect.size.x, 0, rect.size.y), -0.2)
	await shot(planta, "descolgada")
	await go(1.5, func() -> bool: return false, Vector3.INF, [&"lurker_drop"], Vector2.ZERO)
