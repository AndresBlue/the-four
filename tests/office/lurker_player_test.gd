extends SceneTree
## The Lurker in Versus, remade after the author's first two games
## (.claude/specs/lurker_versus.md 13 and 13.9): her body driven by a person,
## here by a script that writes her driver's stick, look and buttons
## (lurker_player.gd, scripted). On floor 2: she starts in the plenum, her
## camera over her; on planta 1 she crawls it from end to end of a department,
## room by room, at her pace and back crawling slowly (silent, by her flags),
## never stuck, never over a core nor out of the building, never into the
## ducts by herself; from one department into the next over the ceiling (no
## fire walls there); pushed into a core or the building's edge at a slant she
## slides along it. On each planta: down by a tile into the room, her camera
## behind her and off her, and back up; into the
## ducts by a grille, the way out most where she looks picked, along them at
## her trip's pace (and no sooner than 1 s), up into the plenum where it comes
## out, and another trip refused within its wait; in again and back out where
## she went in. evidence/versus/rehecho/conductor.json and conductor.txt.
##   godot --headless --fixed-fps 60 --path . --script res://tests/office/lurker_player_test.gd -- --automation --test-profile --silent [--seed=81]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const PLAYER := preload("res://game/enemies/lurker/lurker_player.gd")
const DT := 1.0 / 60.0
const OUT := "res://evidence/versus/rehecho/"
var checks: Array = []
var failed := 0
var lines: Array = []
var level
var lurker
var driver
var shell

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail})
	if not passed: failed += 1
	var line := ("PASS " if passed else "FAIL ") + title + ("  (" + detail + ")" if not detail.is_empty() else "")
	print(line)
	lines.append(line)

func run() -> void:
	var seed_value := 81
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.creature_scene = "lurker"
	level.solo_locust = true
	await level.start_floor(seed_value, false, [1], "desafiante", 2)
	lurker = level.creature
	shell = lurker.shell
	level.hand_creature_to_player()
	driver = lurker.driver
	driver.scripted = true
	lurker.grace = 0.0
	level.player.active = false
	level.player.held = true
	level.player.global_position = Vector3(0, -60, 0)
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	await wait(0.3)
	check("Lleva su cuerpo un conductor y empieza en el plénum, con la cámara sobre ella", lurker.control == "player" and lurker.motion.plenum and driver.mode == "above", "%s %s" % [lurker.motion.plenum, driver.mode])
	await crawl_case()
	for planta in 3:
		lines.append("--- planta %d" % (planta + 1))
		await down_case(planta)
		await trip_case(planta)
	var file := FileAccess.open(OUT + "conductor.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"seed": seed_value, "checks": checks}, "\t"))
	var text := FileAccess.open(OUT + "conductor.txt", FileAccess.WRITE)
	if text != null:
		for line in lines: text.store_line(line)
	print("LURKER_PLAYER_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

# --- Driving ------------------------------------------------------------------------

func wait(seconds: float) -> void:
	for i in int(seconds / DT): await physics_frame

func until(done: Callable, seconds: float) -> bool:
	for i in int(seconds / DT):
		if done.call(): return true
		await physics_frame
	return done.call()

func face(way: Vector3) -> void:
	if Vector2(way.x, way.z).length() > 1e-4: driver.yaw = atan2(-way.x, -way.z)

func press(action: StringName) -> void:
	driver.asked[action] = true
	await physics_frame
	await physics_frame

func at() -> Vector3: return lurker.motion.anchor()

func flat(p: Vector3) -> Vector2: return Vector2(p.x, p.z)

## Into the plenum over a plan point of a room.
func up_over(room: int, p: Vector2) -> void:
	var r: Dictionary = level.manifest.rooms[room]
	driver.trip = {}
	driver.attack = {}
	driver.to_plenum(Vector3(p.x, float(r.py) + 1.0, p.y), room)
	for i in 3: await physics_frame

## Her department's rooms of a planta with a false ceiling, adjacent (a side
## shared) as the plenum lets her cross: room -> [rooms].
func plenum_rooms(planta: int) -> Dictionary:
	var out := {}
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != planta or not shell.tray_of.has(id) or not OFFICE.false_ceiling(room): continue
		var half := FLOOR.size_of(room) * 0.5
		var c := Vector2(float(room.px), float(room.pz))
		var near: Array = []
		for side in [Vector2(-half.x - 0.2, 0), Vector2(half.x + 0.2, 0), Vector2(0, -half.y - 0.2), Vector2(0, half.y + 0.2)]:
			var other := FLOOR.room_at(level.manifest.rooms, Vector3(c.x + side.x, float(room.py) + 1.0, c.y + side.y))
			if other.is_empty() or not shell.tray_of.has(int(other.id)) or not OFFICE.false_ceiling(other) or int(other.sector) != int(room.sector): continue
			near.append(int(other.id))
		out[id] = near
	return out

## The longest way of rooms in one department of a planta (from the room
## farthest from the first, to the one farthest from it).
func longest_way(planta: int) -> Array:
	var graph := plenum_rooms(planta)
	var best: Array = []
	var seen := {}
	for start in graph:
		if seen.has(start): continue
		var far: Array = farthest(graph, int(start))
		for r in far: seen[r] = true
		var way: Array = farthest(graph, int(far[far.size() - 1]))
		if way.size() > best.size(): best = way
	return best

## The rooms on the way from `start` to the room farthest from it (breadth first).
func farthest(graph: Dictionary, start: int) -> Array:
	var parent := {start: -1}
	var queue := [start]
	var last := start
	while not queue.is_empty():
		var r: int = queue.pop_front()
		last = r
		for n in graph[r]:
			if parent.has(n): continue
			parent[n] = r
			queue.append(n)
	var way: Array = []
	var r := last
	while r >= 0:
		way.push_front(r)
		r = int(parent[r])
	return way

## The middle of a room's tray, kept off its walls.
func middle_of(room: int) -> Vector2:
	var r: Dictionary = level.manifest.rooms[room]
	return Vector2(float(r.px), float(r.pz))

## Along a way of rooms, the stick on at full, the camera turned to each next
## room's middle. What was seen: {ok, seconds, metres, stuck, crossed, plan, fastest, flags}.
func crawl_along(way: Array, sneak: bool, seconds: float) -> Dictionary:
	var seen := {"ok": false, "seconds": 0.0, "metres": 0.0, "stuck": 0.0, "crossed": [], "plan": 0, "fastest": 0.0, "sneak_flag": true, "dropped": false}
	driver.sneak_held = sneak
	driver.axis = Vector2(0, -1)
	var k := 0
	var last := at()
	var still := 0.0
	for i in int(seconds / DT):
		var goal := middle_of(int(way[k]))
		if flat(at()).distance_to(goal) < 0.6:
			k += 1
			if k >= way.size():
				seen.ok = true
				break
			goal = middle_of(int(way[k]))
		face(Vector3(goal.x - at().x, 0, goal.y - at().z))
		await physics_frame
		seen.seconds += DT
		var now := at()
		var step := flat(now).distance_to(flat(last))
		seen.metres += step
		# Its pace once it has it (the one before eases off first).
		if float(seen.seconds) > 1.0: seen.fastest = maxf(float(seen.fastest), step / DT)
		still = still + DT if step / DT < 0.3 else 0.0
		seen.stuck = maxf(float(seen.stuck), still)
		last = now
		var room := FLOOR.room_at(level.manifest.rooms, Vector3(now.x, FLOOR.planta_y(FLOOR.planta_of(now.y - 0.5)) + 1.0, now.z))
		if room.is_empty() or not shell.tray_of.has(int(room.id)):
			if seen.crossed.size() < 3: seen.crossed.append(int(room.get("id", -1)))
		if driver.mode == "ducts": seen.plan += 1
		if not lurker.motion.plenum: seen.dropped = true
		if sneak and lurker.flags() & lurker.Flag.SNEAK == 0 and seen.seconds > 0.1: seen.sneak_flag = false
	driver.axis = Vector2.ZERO
	driver.sneak_held = false
	return seen

func said(seen: Dictionary) -> String:
	return "%.1f s, %.1f m, %.2f m/s de media, %.2f m/s de pico, quieta como mucho %.2f s, cruzó %s, plano %d" % [float(seen.seconds), float(seen.metres), float(seen.metres) / maxf(float(seen.seconds), 0.01), float(seen.fastest), float(seen.stuck), str(seen.crossed), int(seen.plan)]

# --- The cases ------------------------------------------------------------------------

## Planta 1: end to end of her largest department and back crawling slowly;
## into a fire wall at a slant, along it.
func crawl_case() -> void:
	var way := longest_way(0)
	lines.append("planta 1, recorrido de %d salas: %s" % [way.size(), str(way)])
	if way.size() < 3:
		check("P1 plénum: un recorrido de al menos tres salas", false, str(way))
		return
	await up_over(int(way[0]), middle_of(int(way[0])))
	var there: Dictionary = await crawl_along(way, false, 120.0)
	check("P1 plénum de punta a punta (%d salas) a su ritmo, sin quedarse pegada ni salir de sus techos ni entrar sola en los ductos" % way.size(), there.ok and float(there.stuck) < 0.5 and (there.crossed as Array).is_empty() and int(there.plan) == 0 and not bool(there.dropped), said(there))
	check("Su ritmo normal es unos 4,5 m/s", absf(float(there.fastest) - PLAYER.PACE) < 0.3, said(there))
	var back_way := way.duplicate()
	back_way.reverse()
	var back: Dictionary = await crawl_along(back_way.slice(0, mini(4, back_way.size())), true, 60.0)
	check("Y vuelve en sigilo: 1,5 m/s, en silencio (su bandera de sigilo) y sin quedarse pegada", back.ok and absf(float(back.fastest) - PLAYER.SNEAK_PACE) < 0.15 and bool(back.sneak_flag) and float(back.stuck) < 0.5 and (back.crossed as Array).is_empty(), said(back))
	# No fire walls over the ceiling: from a room of hers into one of hers of another department.
	var crossing := {}
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != 0 or not shell.tray_of.has(int(room.id)) or not OFFICE.false_ceiling(room): continue
		var half := FLOOR.size_of(room) * 0.5
		for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var out: Vector2 = Vector2(float(room.px), float(room.pz)) + side * ((Vector2(half.x, half.y) * side.abs()).length() + 1.0)
			var other := FLOOR.room_at(level.manifest.rooms, Vector3(out.x, float(room.py) + 1.0, out.y))
			if other.is_empty() or not shell.tray_of.has(int(other.id)) or not OFFICE.false_ceiling(other) or int(other.sector) == int(room.sector): continue
			crossing = {"from": int(room.id), "to": int(other.id), "goal": out}
			break
		if not crossing.is_empty(): break
	if crossing.is_empty(): lines.append("planta 1: ningún paso de un departamento a otro bajo techo suyo")
	else:
		await up_over(int(crossing.from), middle_of(int(crossing.from)))
		var goal: Vector2 = crossing.goal
		driver.axis = Vector2(0, -1)
		for i in int(4.0 / DT):
			face(Vector3(goal.x - at().x, 0, goal.y - at().z))
			await physics_frame
			if flat(at()).distance_to(goal) < 0.4: break
		driver.axis = Vector2.ZERO
		var over := int(FLOOR.room_at(level.manifest.rooms, Vector3(at().x, float(level.manifest.rooms[int(crossing.from)].py) + 1.0, at().z)).get("id", -1))
		check("Sin cortafuegos por arriba: pasa de la sala %d a la %d, de otro departamento" % [int(crossing.from), int(crossing.to)], over == int(crossing.to) and lurker.motion.plenum, "está sobre %d" % over)
	# What stops her: a room of the way with a side on a core or out of the building,
	# else any room of hers on the planta (the way need not run by one: seed 81's
	# since the reception took its cross's stub, 17 November 2026).
	var slid := {}
	var rooms_of_hers: Array = way.duplicate()
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) == 0 and shell.tray_of.has(int(room.id)) and OFFICE.false_ceiling(room) and not rooms_of_hers.has(int(room.id)): rooms_of_hers.append(int(room.id))
	for room in rooms_of_hers:
		var r: Dictionary = level.manifest.rooms[int(room)]
		var half := FLOOR.size_of(r) * 0.5
		for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var out: Vector2 = Vector2(float(r.px), float(r.pz)) + side * (Vector2(half.x, half.y) * side.abs()).length() + side * 0.3
			var along: Vector2 = Vector2(-side.y, side.x)
			# Shut along all its length (in the real building's plan a side may be
			# half on a core, half on a room of hers), and long enough to slide on.
			var length: float = (Vector2(half.y, half.x) * side.abs()).length()
			if length < 3.0: continue
			var shut := true
			for k in range(-4, 5):
				var probe: Vector2 = out + along * length * 0.95 * k / 4.0
				var other := FLOOR.room_at(level.manifest.rooms, Vector3(probe.x, float(r.py) + 1.0, probe.y))
				if not other.is_empty() and shell.tray_of.has(int(other.id)): shut = false
			if not shut: continue
			# From the middle, into that side at 35 degrees off it, while she is still along it.
			await up_over(int(room), middle_of(int(room)))
			var push: Vector2 = (side + along * 0.7).normalized()
			face(Vector3(push.x, 0, push.y))
			driver.axis = Vector2(0, -1)
			var start := at()
			var crossed := false
			var gone := 0.0
			for i in int(minf(3.0, length / 2.6) / DT):
				await physics_frame
				var p := at()
				var here := FLOOR.room_at(level.manifest.rooms, Vector3(p.x, float(r.py) + 1.0, p.z))
				if here.is_empty() or not shell.tray_of.has(int(here.id)): crossed = true
			driver.axis = Vector2.ZERO
			var moved := flat(at()) - flat(start)
			gone = moved.dot(along)
			slid = {"room": int(room), "crossed": crossed, "along": gone, "into": moved.dot(side), "half": (Vector2(half.x, half.y) * side.abs()).length()}
			break
		if not slid.is_empty(): break
	check("Contra un núcleo o el borde del edificio en diagonal desliza a lo largo, sin cruzarlo", not slid.is_empty() and not bool(slid.crossed) and float(slid.along) > 2.0 and float(slid.into) < float(slid.half), str(slid))

## Down by the tile under her and back up, in the biggest room of hers with tiles.
func down_case(planta: int) -> void:
	var room := -1
	var area := 0.0
	for id in lurker.ducts.room_tiles:
		var r: Dictionary = level.manifest.rooms[int(id)]
		if int(r.wing) != planta or not shell.tray_of.has(int(id)) or not OFFICE.false_ceiling(r): continue
		var a := FLOOR.size_of(r).x * FLOOR.size_of(r).y
		if a > area:
			area = a
			room = int(id)
	if room < 0:
		check("P%d bajar: una sala con placas" % [planta + 1], false)
		return
	await up_over(room, middle_of(room))
	await press(&"lurker_drop")
	var down: bool = await until(func() -> bool: return lurker.motion.surface() and lurker.motion.legs.is_empty(), 3.0)
	# Behind her, never at her eyes (13.9).
	var eyes: bool = driver.mode == "down" and lurker.motion.room() == room and driver.camera.global_position.distance_to(lurker.face_point()) > 0.8
	var tile_open := false
	for entry in lurker.ducts.open_tiles.get(room, []): tile_open = true
	await press(&"lurker_drop")
	var back: bool = await until(func() -> bool: return lurker.motion.plenum, 3.0)
	check("P%d baja por la placa a la sala %d con la cámara detrás de ella, y vuelve a subir al plénum" % [planta + 1, room], down and eyes and back and driver.mode == "above", "abajo %s, ojos %s, placa abierta %s, arriba %s" % [down, eyes, tile_open, back])

## Into the ducts by a grille near her, the far way out she looks at picked,
## along at the trip's pace, up where it comes out; another refused in its
## wait; in and back out where she went in.
func trip_case(planta: int) -> void:
	var ducts = lurker.ducts
	var pick := []
	for e in ducts.exits.size():
		if not driver.travel_exit(e) or int(ducts.node_wings[int(ducts.exits[e].node)]) != planta: continue
		var metres: PackedFloat64Array = ducts.distances_from(int(ducts.exits[e].node))
		for o in ducts.exits.size():
			if o == e or not driver.travel_exit(o) or metres[int(ducts.exits[o].node)] == INF: continue
			var d := flat(ducts.exits[o].position).distance_to(flat(ducts.exits[e].position))
			if d > 15.0 and d < 40.0:
				pick = [e, o, metres[int(ducts.exits[o].node)]]
				break
		if not pick.is_empty(): break
	if pick.is_empty():
		check("P%d ductos: una entrada con una salida lejana" % [planta + 1], false)
		return
	var e := int(pick[0])
	var target := int(pick[1])
	var exit: Dictionary = ducts.exits[e]
	await up_over(int(exit.room), flat(exit.position))
	driver.trip_ready_at = 0.0
	var near: int = driver.entrance()
	await press(&"lurker_enter")
	var picking: bool = String(driver.trip.get("phase", "")) == "pick" and driver.mode == "ducts"
	face((ducts.exits[target].position as Vector3) - (exit.position as Vector3))
	await physics_frame
	var picked: int = int(driver.trip.get("pick", -1))
	# Turned to it: the one most where she looks may be another on the same line; that one is hers.
	target = picked
	var started := Time.get_ticks_msec()
	await press(&"lurker_enter")
	var going: bool = await until(func() -> bool: return String(driver.trip.get("phase", "")) == "go", 1.0)
	var length := float(driver.trip.get("length", 0.0))
	var frames := Engine.get_physics_frames()
	var arrived: bool = await until(func() -> bool: return driver.trip.is_empty() and driver.up(), 30.0)
	var seconds := (Engine.get_physics_frames() - frames) * DT
	var expected := maxf(length / PLAYER.TRIP_SPEED, PLAYER.TRIP_LEAST)
	var where: int = int(FLOOR.room_at(level.manifest.rooms, Vector3(at().x, FLOOR.planta_y(planta) + 1.0, at().z)).get("id", -1))
	check("P%d ducto: entra por la rejilla %d y elige la salida que mira (%d)" % [planta + 1, e, target], near == e and picking and picked >= 0, "cerca %d, eligiendo %s, elegida %d" % [near, picking, picked])
	check("P%d y viaja por la red (%.1f m) en %.1f s (esperado %.1f s, nunca menos de 1 s) y sale al plénum de su sala" % [planta + 1, length, seconds, expected], going and arrived and seconds >= PLAYER.TRIP_LEAST - 0.05 and seconds <= expected + 1.2 and flat(at()).distance_to(flat(ducts.exits[target].position)) < 2.5, "sala %d (la de la salida %d); %d ms de reloj" % [where, int(ducts.exits[target].room), Time.get_ticks_msec() - started])
	var again: int = driver.entrance()
	check("P%d otro viaje no antes de su espera" % [planta + 1], again < 0 or not await enter_refused())
	# Back to where she came in: in, then turned back.
	driver.trip_ready_at = 0.0
	lurker.trip_at = -INF
	if driver.entrance() >= 0:
		var from: Vector3 = at()
		await press(&"lurker_enter")
		var in_again: bool = String(driver.trip.get("phase", "")) == "pick"
		await press(&"lurker_drop")
		var out: bool = await until(func() -> bool: return driver.up() and driver.trip.is_empty(), 1.0)
		check("P%d entra y se vuelve atrás: sale donde entró" % [planta + 1], in_again and out and flat(at()).distance_to(flat(from)) < 3.0, "%s %s %.2f m; viaje %s, cámara %s, plénum %s, techo %s, ducto %s, tramos %d, salida %s" % [in_again, out, flat(at()).distance_to(flat(from)), str(driver.trip.get("phase", "")), driver.mode, lurker.motion.plenum, lurker.motion.surface(), lurker.motion.in_duct, lurker.motion.legs.size(), str(ducts.exits[e].kind)])

## An enter asked within the wait: no trip begins.
func enter_refused() -> bool:
	await press(&"lurker_enter")
	return driver.trip.is_empty()
