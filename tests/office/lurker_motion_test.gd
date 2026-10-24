extends SceneTree
## The Lurker's motion (game/enemies/lurker/lurker_motion.gd, spec_f2_movement
## 7) with no body and no physics: on the four-cell plan of
## tests/office/lurker_fixture.gd and on a generated floor, with stub doors,
## a stub ray and stub bodies, sixty ticks a second. She gets where she is
## sent by the doors, by the ducts when one is shut or shuts on her way, and
## after waiting at a door she cannot pass; she never moves more in a tick
## than her pace allows and logs every jump; she leaps from the ceiling and
## climbs back, shrinks under a short lane, stops short of a survivor, goes
## down to the next planta in a ride's time only once nobody is left on hers,
## and leaves a duct the fans shut.
const FIX := preload("res://tests/office/lurker_fixture.gd")
const MOTION := preload("res://game/enemies/lurker/lurker_motion.gd")
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const GEN := preload("res://game/world/generation/office_generator.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const DT := 1.0 / 60.0
var checks: Array = []
var failed := 0
var figures := {}

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var started := Time.get_ticks_msec()
	doors_open()
	door_shut()
	door_shuts_on_the_way()
	waits_then_bans()
	leap_and_climb()
	shrinks()
	stops_short()
	planta()
	fans()
	same_twice()
	figures["total_ms"] = Time.get_ticks_msec() - started
	var file := FileAccess.open("res://evidence/lurker_motion_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks, "figures": figures}, "\t"))
	print("LURKER_MOTION_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

## A motion on a manifest, put on the tray of `room` at its middle.
func motion_on(m: Dictionary, lvl, room: int):
	var routes = FIX.routes_on(m, lvl)
	var motion = MOTION.new()
	motion.setup(routes.shell, routes, routes.ducts, lvl)
	motion.rng.seed = 3
	var r: Dictionary = m.rooms[room]
	motion.place_at(Vector3(float(r.px), float(r.get("py", 0.0)) + 1.0, float(r.pz)), Vector3.RIGHT, &"start")
	motion.jumps = []
	motion.jump_id = 0
	return motion

## Ticks until `done` or `seconds`; what it saw: {frames, worst (step over
## its allowance), kinds (seen leg kinds), hidden, in_duct, rooms, bad_basis}.
func drive(motion, seconds: float, done: Callable, each := Callable()) -> Dictionary:
	var seen := {"frames": 0, "worst": 0.0, "kinds": {}, "hidden": false, "in_duct": false, "rooms": {}, "bad_basis": 0}
	var last: Vector3 = motion.anchor()
	for i in int(seconds / DT):
		if each.is_valid(): each.call(motion, i)
		if not motion.legs.is_empty(): seen.kinds[String(motion.legs[0].kind)] = true
		var leaping: bool = not motion.legs.is_empty() and String(motion.legs[0].kind) == "leap"
		var jumps_before: int = motion.jump_id
		motion.tick(DT)
		seen.frames += 1
		var t: Transform3D = motion.transform()
		var b := t.basis
		if absf(b.determinant() - 1.0) > 1e-3 or absf(b.x.length() - 1.0) > 1e-3: seen.bad_basis += 1
		var allowance: float = (MOTION.SCURRY_SPEED + 0.5) * DT + 1e-3
		if leaping: allowance = MOTION.LEAP_REACH / MOTION.LEAP_TIME * 1.6 * DT + 1e-3
		if motion.jump_id == jumps_before: seen.worst = maxf(seen.worst, t.origin.distance_to(last) - allowance)
		last = t.origin
		if motion.hidden: seen.hidden = true
		if motion.in_duct: seen.in_duct = true
		seen.rooms[motion.room()] = true
		if done.call(motion): break
	return seen

func at_goal(motion) -> bool: return motion.at_goal()

## The first room of a planta with a ceiling for her.
func first_room(m: Dictionary, planta: int) -> int:
	var shell = SHELL.build(m)
	for room in m.rooms:
		if int(room.get("wing", -1)) == planta and shell.tray_of.has(int(room.id)): return int(room.id)
	return -1

func doors_open() -> void:
	var m := FIX.fixture()
	var lvl := FIX.stub_level(m)
	var motion = motion_on(m, lvl, 0)
	motion.go_to_room(2, 1.35)
	var seen := drive(motion, 40.0, at_goal)
	figures["doors_open_s"] = snappedf(seen.frames * DT, 0.01)
	check("Movimiento: con las puertas abiertas llega a la sala por sus franjas", motion.at_goal() and motion.room() == 2 and seen.kinds.has("band") and not seen.in_duct, "%s %d" % [str(seen.kinds.keys()), motion.room()])
	check("Movimiento: nunca se mueve más de lo que su paso deja, y sin saltos", seen.worst <= 0.0 and motion.jumps.is_empty() and seen.bad_basis == 0, "%f %d %d" % [seen.worst, motion.jumps.size(), seen.bad_basis])

func door_shut() -> void:
	var m := FIX.fixture()
	var lvl := FIX.stub_level(m)
	lvl.hotel.doors["Door_1_2"].opened = false
	var motion = motion_on(m, lvl, 0)
	motion.go_to_room(2, 1.35)
	var seen := drive(motion, 60.0, at_goal)
	figures["by_ducts_s"] = snappedf(seen.frames * DT, 0.01)
	check("Movimiento: con la puerta cerrada va por los ductos, sin que se la vea", motion.at_goal() and motion.room() == 2 and seen.in_duct and seen.hidden and not motion.in_duct and not motion.hidden, "%s %d" % [str(seen.kinds.keys()), motion.room()])
	check("Movimiento: por los ductos tampoco salta", seen.worst <= 0.0 and motion.jumps.is_empty() and seen.bad_basis == 0, "%f %d" % [seen.worst, seen.bad_basis])

func door_shuts_on_the_way() -> void:
	var m := FIX.fixture()
	var lvl := FIX.stub_level(m)
	var motion = motion_on(m, lvl, 0)
	motion.go_to_room(2, 1.35)
	var shut := [false]
	var door = lvl.hotel.doors["Door_1_2"]
	var seen := drive(motion, 80.0, at_goal, func(mo, _i):
		if not shut[0] and mo.room() == 1 and mo.surface() and int(mo.shell.patches[mo.state.patch].kind) == SHELL.Kind.TRAY:
			shut[0] = true
			door.shut())
	check("Movimiento: si le cierran la puerta por delante, busca otro camino y llega", shut[0] and motion.at_goal() and motion.room() == 2 and seen.in_duct, "%s %d %s" % [str(shut[0]), motion.room(), motion.stuck])

func waits_then_bans() -> void:
	var m := FIX.fixture()
	var lvl := FIX.stub_level(m)
	var motion = motion_on(m, lvl, 0)
	var banned := [false]
	# Something tall under the head of door 0-1: no room to go through.
	motion.clearance = func(at: Vector3, _s) -> float: return 0.2 if at.x > 2.0 and at.x < 4.5 else SHELL.HANG_MAX
	motion.go_to_room(2, 1.35)
	var seen := drive(motion, 80.0, at_goal, func(mo, _i):
		if mo.routes.bans.has(Vector2i(0, 1)): banned[0] = true)
	check("Movimiento: sin sitio bajo un dintel espera, deja esa puerta y va por otro lado", banned[0] and motion.at_goal() and motion.room() == 2 and seen.in_duct, "%s %d" % [str(banned[0]), motion.room()])

func leap_and_climb() -> void:
	var m := FIX.fixture()
	var lvl := FIX.stub_level(m)
	var motion = motion_on(m, lvl, 0)
	var target := Vector3(2.0, 0.0, 1.0)
	var started: bool = motion.leap(target)
	var seen := drive(motion, 2.0, func(mo): return mo.on_floor and mo.legs.is_empty())
	var landed: bool = motion.on_floor and motion.anchor().distance_to(target) < 1e-3
	motion.climb_back()
	var back := drive(motion, 6.0, func(mo): return mo.surface() and mo.legs.is_empty())
	check("Movimiento: salta del techo sobre un punto y vuelve a subir", started and landed and motion.surface() and motion.room() == 0 and not motion.leap(Vector3(20.0, 0.0, 0.0)), "%s %s" % [str(started), str(landed)])
	check("Movimiento: el salto y la subida son seguidos, sin saltos en el registro", seen.worst <= 0.0 and back.worst <= 0.0 and motion.jumps.is_empty() and seen.bad_basis == 0 and back.bad_basis == 0, "%f %f" % [seen.worst, back.worst])

func shrinks() -> void:
	var m := FIX.fixture()
	var lvl := FIX.stub_level(m)
	var motion = motion_on(m, lvl, 0)
	motion.clearance = func(_at, _s) -> float: return -0.3
	drive(motion, 2.0, func(_mo): return false)
	check("Movimiento: bajo un hueco corto su cuerpo se encoge, no menos de lo dicho", motion.squash < 1.0 and motion.squash >= MOTION.SQUASH_MIN and motion.clearance_short > 0.0, "%f" % motion.squash)
	motion.clearance = func(_at, _s) -> float: return SHELL.HANG_MAX
	drive(motion, 2.0, func(_mo): return false)
	check("Movimiento: con sitio vuelve a su tamaño", is_equal_approx(motion.squash, 1.0))

func stops_short() -> void:
	var m := FIX.fixture()
	var lvl := FIX.stub_level(m)
	var motion = motion_on(m, lvl, 0)
	motion.hang_goal = SHELL.HANG_MAX
	drive(motion, 3.0, func(_mo): return false)
	motion.bodies_ahead = func(_from, _dir, _reach) -> float: return 0.2
	var before: Vector3 = motion.anchor()
	# A point of the same room: one leg, at the hang she has.
	motion.go_to(Vector3(3.0, 1.0, 2.5), 1.35)
	drive(motion, 2.0, func(_mo): return false)
	var held: bool = motion.anchor().distance_to(before) < 0.05
	motion.bodies_ahead = func(_from, _dir, _reach) -> float: return INF
	drive(motion, 2.0, func(_mo): return false)
	check("Movimiento: colgada a la altura de la cabeza no empuja a nadie, se para y sigue", held and motion.anchor().distance_to(before) > 0.5, "%s %f" % [str(held), motion.anchor().distance_to(before)])

func planta() -> void:
	var m: Dictionary = GEN.new().generate(7, 2)
	var lvl := FIX.stub_level(m)
	var motion = motion_on(m, lvl, first_room(m, 0))
	var someone := [true]
	motion.left_behind = func() -> bool: return someone[0]
	motion.follow_to_planta(1)
	drive(motion, 1.0, func(_mo): return false)
	var stayed: bool = motion.transit.is_empty() and motion.pending_wing == 1
	someone[0] = false
	var dropped := [-1, -1]
	var seen := drive(motion, 120.0, func(mo): return mo.transit.is_empty() and mo.pending_wing < 0 and mo.wing() == 1 and mo.legs.is_empty(), func(mo, i):
		if mo.transit_phase() == &"drop" and dropped[0] < 0: dropped[0] = i
		if mo.transit_phase() != &"drop" and dropped[0] >= 0 and dropped[1] < 0: dropped[1] = i)
	var drop_s := float(dropped[1] - dropped[0]) * DT
	figures["planta_drop_s"] = snappedf(drop_s, 0.01)
	var reasons: Array = motion.jumps.map(func(j): return j.reason)
	check("Movimiento: no baja de planta mientras queda alguien en la suya", stayed)
	check("Movimiento: baja por los ductos, tarda lo de un viaje y sale en la planta nueva", motion.wing() == 1 and motion.surface() and absf(drop_s - MOTION.RIDE_TIME) < 0.05 and reasons == [&"planta"], "%d %f %s" % [motion.wing(), drop_s, str(reasons)])
	check("Movimiento: de una planta a otra, solo ese salto", seen.worst <= 0.0 and seen.bad_basis == 0, "%f" % seen.worst)

func fans() -> void:
	var m: Dictionary = GEN.new().generate(7, 2)
	var lvl := FIX.stub_level(m)
	var air := FIX.StubAir.new()
	lvl.objectives["air"] = air
	var motion = motion_on(m, lvl, first_room(m, 2))
	var node: int = motion.ducts.trunk_nearest(motion.anchor(), 2)
	motion.place_in_duct(node)
	air.shut = true
	drive(motion, 60.0, func(mo): return not mo.in_duct and mo.legs.is_empty())
	check("Movimiento: con los ventiladores en marcha sale del ducto de su planta", not motion.in_duct and motion.surface() and motion.wing() == 2, "%s %d" % [str(motion.in_duct), motion.wing()])

func same_twice() -> void:
	var ends: Array = []
	for i in 2:
		var m := FIX.fixture()
		var lvl := FIX.stub_level(m)
		lvl.hotel.doors["Door_1_2"].opened = false
		var motion = motion_on(m, lvl, 0)
		motion.go_to_room(2, 1.35)
		var seen := drive(motion, 60.0, at_goal)
		ends.append([seen.frames, motion.anchor()])
	check("Movimiento: lo mismo dos veces da lo mismo", ends[0] == ends[1], str(ends))
