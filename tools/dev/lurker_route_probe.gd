extends SceneTree
## The Lurker on a built floor 2 (spec_f2_movement 11.2): trips between rooms
## of each planta, every frame held to her rules (no jump she did not log,
## an upright basis, never in an off-limits room, never onto a band whose
## door is shut, hidden only inside the ducts, her default stops clear of the
## lamps), and the special trips of seed 7: a door shut on her way, a planta
## with every door shut, the cue holding her, the way down to the next
## planta, saved and given back mid-way, a puppet fed her packets, and her
## contract.
##
##   godot --headless --path . --rendering-method forward_plus --fixed-fps 60 \
##       --script res://tools/dev/lurker_route_probe.gd -- --test-profile --seeds=7 --trips=2 --short --strict
##
## A line per seed and a total; --trace adds a line per trip; --strict exits
## 1 on any failure. evidence/lurker_route_probe.json keeps every failure.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const DIFFICULTY := preload("res://game/floors/difficulty.gd")
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const MOTION := preload("res://game/enemies/lurker/lurker_motion.gd")
const BODY := preload("res://game/enemies/lurker/lurker_creature.tscn")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
var level
var lurker
var trace := false
var short := false
var failures: Array = []
var figures := {}
var passed := 0
var total := 0
var seed_now := 0
var trip_now := -1

func _initialize() -> void: run.call_deferred()

func fail(reason: String, at := Vector3.ZERO) -> void:
	failures.append({"seed": seed_now, "trip": trip_now, "frame": Engine.get_physics_frames(), "reason": reason, "position": [at.x, at.y, at.z]})

func check(title: String, ok: bool, detail := "") -> void:
	total += 1
	if ok: passed += 1
	else: fail(title + (" " + detail if detail != "" else ""))
	if trace or not ok: print("  %s %s%s" % ["ok" if ok else "FALLA", title, ("  (" + detail + ")") if not ok and detail != "" else ""])

func run() -> void:
	var seeds: Array = [7]
	var trips := 2
	var strict := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="): seeds = Array(argument.trim_prefix("--seeds=").split(",")).map(func(text): return int(text))
		if argument.begins_with("--trips="): trips = int(argument.trim_prefix("--trips="))
		if argument == "--trace": trace = true
		if argument == "--short": short = true
		if argument == "--strict": strict = true
	var started := Time.get_ticks_msec()
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.set_floor(2)
	for run_seed in seeds:
		seed_now = int(run_seed)
		await level.start_floor(seed_now, false, [1], "equilibrada")
		level.player.set_physics_process(false)
		level.player.global_position = Vector3(0, -200, 0)
		lurker = spawn("ai")
		var result := await trips_of(trips)
		print("SEED %d, %d trayectos, %d llegaron, %.0f s en ductos" % [seed_now, result.trips, result.arrived, result.duct_seconds])
		if seed_now == int(seeds[0]): await specials()
		lurker.queue_free()
		await physics_frame
	figures["wall_ms"] = Time.get_ticks_msec() - started
	var verdict := "PASS" if failures.is_empty() else "FAIL"
	print("LURKER_ROUTE_PROBE %s %d/%d" % [verdict, passed, total])
	var file := FileAccess.open("res://evidence/lurker_route_probe.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"failures": failures, "figures": figures, "passed": passed, "total": total}, "\t"))
	quit(1 if strict and not failures.is_empty() else 0)

func spawn(control: String):
	var body = BODY.instantiate()
	body.level = level
	body.control = control
	level.add_child(body)
	body.grace = 0.0
	body.tune(DIFFICULTY.profile("equilibrada", &"lurker"))
	return body

## Rooms of a planta with a ceiling for her.
func rooms_of(wing: int) -> Array:
	var out: Array = []
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) == wing and lurker.shell.tray_of.has(int(room.id)): out.append(int(room.id))
	return out

func centre(room: int) -> Vector3:
	var r: Dictionary = level.manifest.rooms[room]
	return Vector3(float(r.px), float(r.get("py", 0.0)) + 1.0, float(r.pz))

func trips_of(count: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_now * 7919 + 13
	var out := {"trips": 0, "arrived": 0, "duct_seconds": 0.0}
	for wing in 3:
		var ids := rooms_of(wing)
		if ids.size() < 2: continue
		for i in count:
			var a: int = -1
			var b: int = -1
			for attempt in 40:
				a = ids[rng.randi_range(0, ids.size() - 1)]
				b = ids[rng.randi_range(0, ids.size() - 1)]
				if a != b and centre(a).distance_to(centre(b)) >= 10.0: break
			trip_now = out.trips
			lurker.teleport(centre(a), 0.0, &"probe")
			var plan: Dictionary = lurker.routes.plan({"room": a}, {"room": b})
			if not bool(plan.ok):
				fail("sin plan %d -> %d" % [a, b], centre(a))
				continue
			lurker.motion.go_to_room(b, 1.35)
			var seen: Dictionary = await watch(3.0 * float(plan.cost) + 10.0, func(): return lurker.motion.at_goal())
			out.trips += 1
			out.duct_seconds += float(seen.duct_seconds)
			var arrived: bool = lurker.motion.at_goal() and lurker.motion.room() == b
			if arrived: out.arrived += 1
			check("trayecto %d -> %d llega" % [a, b], arrived, "%s %d %s" % [String(lurker.motion.route_state()), lurker.motion.room(), where()])
			if arrived: check("trayecto %d -> %d acaba lejos de las lámparas" % [a, b], clear_of_lamps(b))
			if trace: print("   planta %d, %d -> %d, %.1f s, ductos %.1f s" % [wing, a, b, seen.seconds, seen.duct_seconds])
	return out

## Where she is stuck, for a failure: the leg, her place, the ray.
func where() -> String:
	var m = lurker.motion
	var leg: Dictionary = m.legs[0] if not m.legs.is_empty() else {}
	var place := "ducto %s" % str(m.duct_point) if m.in_duct else "suelo" if m.on_floor else ""
	if m.surface(): place = "parche %d (%d) u %.2f v %.2f cuelga %.2f, tope %.2f" % [m.state.patch, int(lurker.shell.patches[m.state.patch].kind), m.state.u, m.state.v, m.state.hang, m.hang_limit]
	var shown := {}
	for key in leg: shown[key] = leg[key] if not (leg[key] is PackedVector3Array) else "%d puntos" % (leg[key] as PackedVector3Array).size()
	return "%s; tramo %s; quedan %d; espera %.1f" % [place, str(shown), m.legs.size(), m.wait_clock]

func clear_of_lamps(room: int) -> bool:
	var at: Vector3 = lurker.global_position
	var lamps: PackedVector2Array = lurker.shell.lamps_of.get(room, PackedVector2Array())
	var want: Vector2 = lurker.shell.clear_point(room, float(level.manifest.rooms[room].px), float(level.manifest.rooms[room].pz))
	return Vector2(at.x, at.z).distance_to(want) < 0.05 or lamps.size() == 0

## Physics frames until `done` or `seconds`, every frame held to checks 1 to
## 6 of 11.2; {seconds, duct_seconds}.
func watch(seconds: float, done: Callable, each := Callable()) -> Dictionary:
	var off: Array = OFFICE.off_limits_rooms(level.manifest)
	var last: Transform3D = lurker.global_transform
	var last_patch := -1
	var was_hidden := false
	var duct_seconds := 0.0
	var frames := int(seconds * 60.0)
	var i := 0
	while i < frames:
		var jumps_before: int = lurker.motion.jump_id
		await physics_frame
		i += 1
		if each.is_valid(): each.call(i)
		var now: Transform3D = lurker.global_transform
		var m = lurker.motion
		var delta := 1.0 / 60.0
		var jumped: bool = m.jump_id != jumps_before
		var leaping: bool = not m.legs.is_empty() and String(m.legs[0].kind) == "leap"
		var fastest: float = maxf(MOTION.SCURRY_SPEED, lurker.duct_speed)
		if not jumped and not leaping and now.origin.distance_to(last.origin) > fastest * delta * 1.25 + 0.01:
			fail("salto de %.3f m" % now.origin.distance_to(last.origin), now.origin)
		var b := now.basis
		if absf(b.determinant() - 1.0) > 1e-3 or absf(b.x.length() - 1.0) > 1e-3 or absf(b.x.dot(b.y)) > 1e-3:
			fail("base torcida", now.origin)
		var room := int(FLOOR.room_at(level.manifest.rooms, now.origin).get("id", -1))
		if room >= 0 and off.has(room): fail("en una sala prohibida %d" % room, now.origin)
		if m.surface():
			var record: Dictionary = lurker.shell.patches[m.state.patch]
			if m.state.patch != last_patch and int(record.kind) == SHELL.Kind.BAND and (record.pair as Vector2i).x >= 0 and not lurker.routes.door_open(record.pair):
				fail("a una franja con la puerta cerrada %s" % str(record.pair), now.origin)
			last_patch = m.state.patch
		else: last_patch = -1
		if m.hidden and not m.in_duct and m.transit_phase() != &"drop": fail("oculta fuera de un ducto", now.origin)
		if m.in_duct: duct_seconds += delta
		was_hidden = m.hidden
		last = now
		if done.call(): break
	return {"seconds": float(i) / 60.0, "duct_seconds": duct_seconds}

# --- Seed 7's special trips -----------------------------------------------------------------

func specials() -> void:
	trip_now = -1
	await door_shut_on_her()
	await ducts_only()
	await cue_holds()
	await planta_transit()
	await saved_mid_transit()
	await puppet_follows()
	contract()

## A door band two legs ahead, its door toggled shut: she finds another way
## or says she is blocked.
func door_shut_on_her() -> void:
	var ids := rooms_of(0)
	for a in ids:
		for b in ids:
			if a == b: continue
			lurker.teleport(centre(a), 0.0, &"probe")
			if not lurker.motion.go_to_room(b, 1.35): continue
			var legs: Array = lurker.motion.legs
			var ahead := -1
			for k in range(2, legs.size()):
				if String(legs[k].kind) == "band" and (lurker.shell.patches[int(legs[k].patch)].pair as Vector2i).x >= 0:
					ahead = k
					break
			if ahead < 0: continue
			var pair: Vector2i = lurker.shell.patches[int(legs[ahead].patch)].pair
			var door = lurker.routes.door_nodes.get(pair)
			if door == null: continue
			door.toggle()
			await physics_frame
			await physics_frame
			check("una puerta que se cierra sale de su camino en un fotograma", not lurker.motion.remaining_pairs().has(pair) or lurker.motion.committed())
			var from: Dictionary = lurker.motion.plan_start()
			var again: Dictionary = lurker.routes.plan(from.start, {"room": b}, from.from_state, from.from_point) if not from.is_empty() else {"ok": false, "cost": 0.0}
			var budget: float = 3.0 * float(again.cost) + 10.0 if bool(again.ok) else 10.0
			await watch(minf(budget, 600.0), func(): return lurker.motion.at_goal() or lurker.motion.route_state() == &"blocked")
			check("con la puerta cerrada llega o se queda parada", lurker.motion.at_goal() or lurker.motion.route_state() == &"blocked", where())
			door.toggle()
			await watch(1.0, func(): return false)
			return
	fail("ningún trayecto con una puerta delante")

## Every door of planta 2 shut with no signal: by the ducts, at their speed.
func ducts_only() -> void:
	var with_exit := {}
	for e in lurker.ducts.exits: with_exit[int(e.room)] = true
	var ids := rooms_of(1).filter(func(r): return with_exit.has(r))
	if ids.size() < 2:
		fail("planta 2 sin salas con salida")
		return
	var far := [ids[0], ids[1]]
	var best := 0.0
	for a in ids:
		for b in ids:
			var d := centre(a).distance_to(centre(b))
			if d > best:
				best = d
				far = [a, b]
	var doors: Array = []
	for pair in lurker.routes.door_nodes:
		var door = lurker.routes.door_nodes[pair]
		if door != null and int(level.manifest.rooms[pair.x].get("wing", -1)) == 1 and bool(door.opened):
			door.set_state(false)
			doors.append(door)
	var ids_speed := ["equilibrada"] if short else ["apacible", "equilibrada", "desafiante", "pesadilla"]
	for id in ids_speed:
		lurker.tune(DIFFICULTY.profile(id, &"lurker"))
		lurker.teleport(centre(far[0]), 0.0, &"probe")
		await physics_frame
		lurker.motion.go_to_room(far[1], 1.35)
		var metres := 0.0
		var expected := 0.0
		for leg in lurker.motion.legs:
			if String(leg.kind) != "duct": continue
			var points: PackedVector3Array = leg.points
			var kinds: PackedStringArray = leg.kinds
			for k in range(1, points.size()):
				var piece := points[k].distance_to(points[k - 1])
				metres += piece
				expected += piece / float(lurker.routes.segment_speed(kinds[k - 1] if k - 1 < kinds.size() else ""))
		var seen := await watch(240.0, func(): return lurker.motion.at_goal())
		check("planta 2 cerrada a %s: llega por los ductos" % id, lurker.motion.at_goal() and metres > 0.0, "%.1f m" % metres)
		check("planta 2 cerrada a %s: el tiempo en ductos es el de sus metros" % id, absf(float(seen.duct_seconds) - expected) <= expected * 0.1 + 0.5 + 2.0 * MOTION.SQUEEZE_SPEED, "%.1f s, %.1f s" % [float(seen.duct_seconds), expected])
	lurker.tune(DIFFICULTY.profile("equilibrada", &"lurker"))
	for door in doors: door.set_state(true)
	await physics_frame

## With the cue set nothing of 2a moves her.
func cue_holds() -> void:
	var a: int = rooms_of(0)[0]
	lurker.teleport(centre(a), 0.0, &"probe")
	await physics_frame
	lurker.cue = true
	lurker.motion.hold()
	var at: Vector3 = lurker.global_position
	lurker.follow_to_planta(2, true)
	await watch(3.0, func(): return false)
	check("con el aviso en marcha no se mueve", lurker.global_position.distance_to(at) <= 1e-3)
	lurker.cue = false
	await watch(1.0, func(): return lurker.motion.transit_phase() != &"")
	check("al acabar el aviso empieza el viaje que esperaba", lurker.motion.transit_phase() != &"" or lurker.motion.wing() == 1)
	await watch(90.0, func(): return lurker.motion.transit.is_empty() and lurker.motion.wing() == 1 and lurker.motion.legs.is_empty())

## Down to planta 2 from planta 1: one jump, hushed while dropping, never seen
## between going in and coming out, out in the arrival band.
func planta_transit() -> void:
	var a: int = rooms_of(0)[0]
	lurker.teleport(centre(a), 0.0, &"probe")
	await physics_frame
	var before: int = lurker.motion.jumps.size()
	lurker.follow_to_planta(2, true)
	var seen_visible := [false]
	var hushed_wrong := [false]
	var inside := [false]
	await watch(120.0, func(): return lurker.motion.transit.is_empty() and lurker.motion.wing() == 1 and lurker.motion.legs.is_empty(), func(_i):
		var phase: StringName = lurker.motion.transit_phase()
		if lurker.motion.in_duct: inside[0] = true
		if inside[0] and phase != &"" and lurker.visual.visible and phase != &"leaving": seen_visible[0] = true
		if (phase == &"drop") != lurker.hushed(): hushed_wrong[0] = true)
	var reasons: Array = lurker.motion.jumps.slice(before).map(func(j): return j.reason)
	check("baja de planta con un solo salto", reasons == [&"planta"], str(reasons))
	check("baja de planta sin que se la oiga ni se la vea", not seen_visible[0] and not hushed_wrong[0])
	check("sale en la planta 2", lurker.motion.wing() == 1 and lurker.motion.surface())

## Saved leaving, dropping and arriving, then given back on a fresh body.
func saved_mid_transit() -> void:
	for phase in [&"leaving", &"drop", &"arriving"]:
		var a: int = rooms_of(0)[0]
		lurker.teleport(centre(a), 0.0, &"probe")
		await physics_frame
		lurker.follow_to_planta(2, true)
		var saved := {}
		await watch(90.0, func(): return not saved.is_empty(), func(_i):
			if saved.is_empty() and lurker.motion.transit_phase() == phase: saved.merge(lurker.save_state()))
		if saved.is_empty():
			fail("no llegó a %s" % String(phase))
			continue
		var fresh = spawn("ai")
		await physics_frame
		fresh.restore_state(saved, 0.0)
		await watch(90.0, func(): return fresh.motion.transit.is_empty() and fresh.motion.pending_wing < 0 and fresh.motion.legs.is_empty(), Callable())
		check("guardada en %s vuelve a la planta 2, fuera de los ductos" % String(phase), fresh.motion.wing() == 1 and not fresh.motion.in_duct and fresh.motion.transit.is_empty(), "%d %s" % [fresh.motion.wing(), str(fresh.motion.in_duct)])
		fresh.queue_free()
		lurker.teleport(centre(a), 0.0, &"probe")
		await physics_frame

## A puppet fed her packets at 15 Hz renders where she was 0.1 s before.
func puppet_follows() -> void:
	var puppet = spawn("puppet")
	await physics_frame
	var ids := rooms_of(0)
	lurker.teleport(centre(ids[0]), 0.0, &"probe")
	await physics_frame
	lurker.motion.go_to_room(ids[ids.size() - 1], 1.35)
	var kept: Array = []
	var worst := [0.0]
	var frame := [0]
	var connected := false
	for door in lurker.routes.door_nodes.values():
		if door != null and door.swung.get_connections().any(func(c): return c.callable.get_object() == puppet.routes): connected = true
	await watch(40.0, func(): return lurker.motion.at_goal(), func(_i):
		frame[0] += 1
		kept.append([puppet.net_clock, lurker.global_transform])
		if frame[0] % 4 == 0: puppet.push_state(lurker.pack_state())
		var wanted: float = puppet.net_clock - 0.1
		for k in range(kept.size() - 1):
			if float(kept[k][0]) <= wanted and float(kept[k + 1][0]) >= wanted:
				var t := (wanted - float(kept[k][0])) / maxf(float(kept[k + 1][0]) - float(kept[k][0]), 1e-4)
				var host: Vector3 = (kept[k][1] as Transform3D).origin.lerp((kept[k + 1][1] as Transform3D).origin, t)
				if frame[0] > 12: worst[0] = maxf(worst[0], host.distance_to(puppet.global_position))
				break)
	figures["puppet_worst_m"] = snappedf(worst[0], 0.001)
	check("la marioneta va donde ella iba hace una décima", worst[0] <= 0.1 + 0.25, "%.3f m" % worst[0])
	check("la marioneta no vigila puertas", not connected)
	check("el paquete tiene su tamaño", lurker.pack_state().size() == lurker.PACK_SIZE)
	puppet.queue_free()

func contract() -> void:
	check("es The Lurker", lurker.kind_id() == &"lurker")
	check("solo puede los ductos", lurker.can(&"ducts") and not lurker.can(&"lifts") and not lurker.can(&"wardrobes") and not lurker.can(&"sets") and not lurker.can(&"shriek"))
	var here: int = lurker.motion.room()
	var metres: Dictionary = lurker.travel_metres(here)
	var off: Array = OFFICE.off_limits_rooms(level.manifest)
	check("los metros a su planta, sin salas prohibidas", not metres.is_empty() and not metres.keys().any(func(r): return off.has(int(r))))
	for stage in [1, 2, 3]:
		var den: Vector3 = lurker.den_point(stage)
		check("su guarida de la etapa %d está en su planta" % stage, den != Vector3.INF and FLOOR.planta_of(den.y) == stage - 1)
	var den3: Vector3 = lurker.den_point(3)
	check("su guarida de la planta 3 es la sala de climatización", int(FLOOR.room_at(level.manifest.rooms, den3).get("id", -1)) == int(level.manifest.air.room))
	lurker.teleport(centre(rooms_of(0)[0]), 0.0, &"probe")
	var saved: Dictionary = lurker.save_state()
	var at: Vector3 = lurker.global_position
	lurker.restore_state(saved, 0.0)
	check("guardar y volver la deja donde estaba", lurker.global_position.distance_to(at) < 1e-3, "%s %s %s" % [str(at), str(lurker.global_position), str(saved)])
	var before: int = lurker.motion.jump_id
	lurker.teleport(at, 0.0, &"probe")
	check("un teleport se apunta como salto", lurker.motion.jump_id == before + 1)
	var node: int = lurker.ducts.trunk_nearest(at, 0)
	lurker.motion.place_in_duct(node)
	var in_duct: Dictionary = lurker.save_state()
	lurker.teleport(at, 0.0, &"probe")
	lurker.restore_state(in_duct, 0.0)
	check("guardada en un ducto vuelve oculta a su nodo", lurker.motion.in_duct and lurker.motion.hidden and lurker.motion.near_node == node)
