extends SceneTree
## The creature's contract (game/enemies/creature.gd) on The Locust: each of
## its predicates is, mode by mode, the list of modes the game still asks
## with where it stands for one (docs/OFICINAS.md, 11.1); what it sends over
## the net comes back the same; teleport() drops everything the three places
## that move it drop by hand (lifts.apply_locust_ride,
## televisions.warp_creature, revival.relocate_creature); it says what it is
## and what it can do; and the level's creature is its locust.
const CREATURE := preload("res://game/enemies/creature.gd")
const LOCUST := preload("res://game/enemies/locust/hotel_locust.gd")
const LOCUST_SCENE := preload("res://game/enemies/locust/locust.tscn")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

## The lists of modes each predicate stands for, as the game writes them
## today, where it does.
static func literal_lists() -> Dictionary:
	return {
		# pacing_director.hostile()
		"is_hostile": [LOCUST.Mode.ALERT, LOCUST.Mode.CHASE, LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER, LOCUST.Mode.EXECUTE, LOCUST.Mode.LURK],
		# phantom_sight.allowed()
		"is_attacking": [LOCUST.Mode.ALERT, LOCUST.Mode.CHASE, LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER, LOCUST.Mode.EXECUTE],
		# dread_aura, its worst
		"is_hunting": [LOCUST.Mode.CHASE, LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER, LOCUST.Mode.ALERT],
		# match_net.warp_busy() and lifts.creature_crossing()'s `busy`
		"is_engaged": [LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER, LOCUST.Mode.EXECUTE, LOCUST.Mode.WARDROBE, LOCUST.Mode.LURK],
		# lifts.aim_at_lift() and lifts.apply_locust_ride()
		"is_roaming": [LOCUST.Mode.PATROL, LOCUST.Mode.SEARCH, LOCUST.Mode.INVESTIGATE],
		# pacing_director.update(): no lead unless PATROL or SEARCH
		"accepts_leads": [LOCUST.Mode.PATROL, LOCUST.Mode.SEARCH],
	}

## Two packed states alike: floats and vectors within rounding, the rest equal.
static func alike(one: Array, two: Array) -> bool:
	if one.size() != two.size(): return false
	for i in one.size():
		var a: Variant = one[i]
		var b: Variant = two[i]
		if typeof(a) != typeof(b): return false
		if a is float or a is Vector3:
			if not is_equal_approx_any(a, b): return false
		elif a != b: return false
	return true

static func is_equal_approx_any(a: Variant, b: Variant) -> bool:
	if a is Vector3: return (a as Vector3).is_equal_approx(b as Vector3)
	return is_equal_approx(float(a), float(b))

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	var it = level.locust
	check("Empezado un piso, su criatura es una criatura del contrato", is_instance_valid(it) and it is CREATURE and it is LOCUST)
	check("level.creature es level.locust", level.creature == level.locust and level.creature != null)
	var kept = level.locust
	level.creature = null
	var emptied: bool = level.locust == null
	level.creature = kept
	check("Y darle otra a level.creature se la da a level.locust", emptied and level.locust == kept)
	it.set_physics_process(false)
	predicates(it)
	identity(it)
	senses(it)
	var copy = await puppet()
	round_trip(it, copy)
	teleport_puppet(copy)
	copy.queue_free()
	await process_frame
	teleport_machine(it)
	bare()
	var file := FileAccess.open("res://evidence/creature_contract_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	print("CREATURE_CONTRACT_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

## Every mode, every predicate: each one is its list, no more and no less.
func predicates(it) -> void:
	var lists := literal_lists()
	var before: int = it.mode
	var wrong := {}
	var alarms: Array = []
	var words := {}
	var names_right := true
	for value in LOCUST.Mode.values():
		it.mode = value
		var label: String = LOCUST.Mode.keys()[value]
		for predicate in lists:
			if bool(it.call(predicate)) != (lists[predicate] as Array).has(value):
				wrong[predicate] = wrong.get(predicate, []) + [label]
		# dread_aura's match: the hunt at its worst, looking for somebody a
		# little, anything else nothing.
		var dread: int = 0
		if value in [LOCUST.Mode.CHASE, LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER, LOCUST.Mode.ALERT]: dread = 2
		elif value in [LOCUST.Mode.INVESTIGATE, LOCUST.Mode.SEARCH]: dread = 1
		if int(it.alarm_level()) != dread: alarms.append(label)
		words[it.activity()] = true
		if it.mode_name() != label: names_right = false
	it.mode = before
	for predicate in lists:
		check("%s() es, modo a modo, su lista" % predicate, not wrong.has(predicate), "difiere en %s" % str(wrong.get(predicate, [])))
	check("alarm_level() es el grado del aura en cada modo", alarms.is_empty(), "difiere en %s" % str(alarms))
	check("Cada modo tiene su palabra, y son todas distintas", words.size() == LOCUST.Mode.size() and not words.has(&""))
	check("mode_name() es el nombre del modo", names_right)

func identity(it) -> void:
	check("kind_id() es locust", it.kind_id() == &"locust")
	check("Sube en ascensor, sale por las teles, abre armarios y chilla", it.can(&"lifts") and it.can(&"tv_travel") and it.can(&"wardrobes") and it.can(&"shriek"))
	check("Por los ductos no, ni nada que no exista", not it.can(&"ducts") and not it.can(&"nada"))
	check("capture_length() es lo que dura su ejecución", is_equal_approx(it.capture_length(), LOCUST.EXECUTION_TIME))
	var bound: bool = it.lift_bound
	it.lift_bound = true
	var going: bool = it.in_transit()
	it.lift_bound = false
	check("in_transit() es ir hacia un ascensor", going and not it.in_transit())
	it.lift_bound = bound
	var here := FLOOR.room_at(level.manifest.rooms, it.global_position)
	check("travel_metres() es su walk_from()", not here.is_empty() and it.travel_metres(int(here.id)) == it.walk_from(int(here.id)) and not it.travel_metres(int(here.id)).is_empty())
	check("Sin alucinaciones propias todavía", it.hallucinations() == null)
	check("Unas líneas para el observador", not it.debug_lines().is_empty() and it.debug_state().get("kind") == &"locust")

func senses(it) -> void:
	var eye: Vector3 = it.eye_point()
	check("eye_point() a la altura de sus ojos", eye.is_equal_approx(it.global_position + Vector3(0, LOCUST.EYE_HEIGHT, 0)) and it.face_point().is_equal_approx(eye))
	var look: Vector3 = it.visual.look_point
	it.visual.look_point = eye + Vector3(3, -1, 0)
	var turned: Vector3 = it.gaze()
	it.visual.look_point = Vector3.INF
	var ahead: Vector3 = it.gaze()
	it.visual.look_point = look
	check("gaze() es hacia donde vuelve la cabeza, o hacia donde mira su cuerpo", turned.is_equal_approx(Vector3(3, -1, 0)) and ahead.is_equal_approx(-it.global_basis.z))

## Another of it, standing far under the floor, as a guest's copy: driven by
## the states it is sent.
func puppet():
	var copy = LOCUST_SCENE.instantiate()
	copy.collision_layer = 0
	copy.collision_mask = 0
	root.add_child(copy)
	copy.global_position = Vector3(0, -300, 0)
	copy.set_control("puppet")
	await process_frame
	return copy

func round_trip(it, copy) -> void:
	it.rotation.y = 0.7
	it.velocity = Vector3(1.0, 0.0, -2.0)
	var before: int = it.mode
	it.mode = LOCUST.Mode.SEARCH
	var grace: float = it.grace
	it.grace = 3.5
	var look: Vector3 = it.visual.look_point
	it.visual.look_point = it.global_position + Vector3(2.0, 1.5, 0.0)
	var sent: Array = it.pack_state()
	it.mode = before
	it.grace = grace
	it.visual.look_point = look
	it.velocity = Vector3.ZERO
	copy.push_state(sent)
	var got: Dictionary = copy.net_states[-1] if not copy.net_states.is_empty() else {}
	check("Lo que manda llega igual: sitio, giro, velocidad, modo, gracia y adónde mira", not got.is_empty() and (got.position as Vector3).is_equal_approx(sent[0]) and is_equal_approx(float(got.yaw), float(sent[1])) and (got.velocity as Vector3).is_equal_approx(sent[2]) and copy.mode == sent[3] and is_equal_approx(copy.grace, float(sent[4])) and copy.net_look == sent[5])
	# As the copy stands once it has caught up with it, sent on again.
	copy.global_position = got.position
	copy.rotation.y = float(got.yaw)
	copy.velocity = got.velocity
	copy.visual.look_point = copy.net_look
	check("Y mandado de nuevo desde la copia es lo mismo", alike(copy.pack_state(), sent))
	copy.global_position = Vector3(0, -300, 0)
	copy.velocity = Vector3.ZERO

## What any of the three left behind, put on it.
func dirty(it) -> void:
	it.velocity = Vector3(3.0, 0.0, 1.0)
	it.speed = 4.0
	it.net_states = [{"time": 0.0, "position": Vector3.ONE, "yaw": 0.0, "velocity": Vector3.ZERO}]
	it.net_clock = 7.0
	it.ride_point = Vector3(9, 9, 9)
	it.ride_hold = 0.0
	it.path = PackedVector3Array([Vector3.ONE, Vector3(2, 0, 2)])
	it.path_index = 1
	it.crossings = [{"door": null, "enter": 0, "exit": 1}]
	it.rounds = {1: true}
	it.passing_time = 1.0
	it.dodge_left = 1.0
	it.stuck_clock = 1.0
	it.stuck_linger = 1.0
	it.stuck_level = 2
	it.stuck_origin = Vector3.ONE
	it.linger_goal = Vector3.ONE
	it.linger_best = 3.0
	it.repath = 1.0

## Nothing of the way it was going: lifts, sets and revival between them.
func journey_forgotten(it) -> Dictionary:
	return {
		"quieta": it.velocity == Vector3.ZERO and is_zero_approx(it.speed),
		"sin estados de red": it.net_states.is_empty() and is_zero_approx(it.net_clock),
		"sin ruta": it.path.is_empty() and it.path_index == 0 and it.crossings.is_empty() and it.rounds.is_empty() and is_zero_approx(it.passing_time) and is_zero_approx(it.repath),
		"sin atasco": is_zero_approx(it.dodge_left) and is_zero_approx(it.stuck_clock) and is_zero_approx(it.stuck_linger) and it.stuck_level == 0 and it.stuck_origin == Vector3.INF and it.linger_goal == Vector3.INF and it.linger_best == INF,
	}

func teleport_puppet(copy) -> void:
	# A hunter's channels, as locust_player keeps them.
	var stand_in := GDScript.new()
	stand_in.source_code = "extends Node\nvar channel_open := true\n"
	stand_in.reload()
	var driver := Node.new()
	driver.set_script(stand_in)
	copy.add_child(driver)
	copy.driver = driver
	dirty(copy)
	var point := Vector3(4.0, -300.0, 2.0)
	copy.teleport(point, 1.25, &"television")
	var forgot := journey_forgotten(copy)
	for what in forgot: check("Una copia trasladada queda %s" % what, forgot[what])
	check("En el sitio y mirando adonde se le dice", copy.global_position.is_equal_approx(point) and is_equal_approx(copy.rotation.y, 1.25))
	check("Y no hace caso un rato de lo que aún llegue de donde estaba", copy.ride_point == point and is_equal_approx(copy.ride_hold, 2.0))
	check("Con los canales del cazador cerrados", driver.get("channel_open") == false)
	copy.teleport(point + Vector3(1, 0, 0), NAN, &"lift")
	check("Sin giro dado, mira adonde miraba", is_equal_approx(copy.rotation.y, 1.25))
	copy.driver = null
	driver.queue_free()

func teleport_machine(it) -> void:
	var to := {}
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) == 0 and int(room.id) != int(it.patrol_room) and not FLOOR.is_void(room) and not bool(room.get("corridor", false)):
			to = room
			break
	var point := FLOOR.position_of(to) + Vector3(0, 0.04, 0)
	dirty(it)
	var hold: float = it.ride_hold
	it.mode = LOCUST.Mode.SEARCH
	it.teleport(point, 2.0, &"revival")
	var forgot := journey_forgotten(it)
	for what in forgot: check("La criatura trasladada queda %s" % what, forgot[what])
	check("Su ronda empieza en la sala adonde llega", int(it.patrol_room) == int(FLOOR.room_at(level.manifest.rooms, point).get("id", -1)))
	check("Lo que haga allí no lo decide el traslado", it.mode == LOCUST.Mode.SEARCH and is_equal_approx(it.ride_hold, hold) and it.global_position.is_equal_approx(point))
	it.mode = LOCUST.Mode.PATROL

## A creature with nothing of its own: the defaults say so.
func bare() -> void:
	var nobody = CREATURE.new()
	check("Una criatura sin nada propio no es nadie ni puede nada", nobody.kind_id() == &"" and not nobody.can(&"lifts") and nobody.activity() == &"roam" and nobody.is_roaming() and nobody.accepts_leads() and not nobody.is_hostile() and nobody.alarm_level() == 0 and nobody.pack_state().is_empty() and nobody.capture_length() == 0.0)
	nobody.free()
