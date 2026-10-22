extends SceneTree
## The creature's contract (game/enemies/creature.gd) on The Locust: each of
## its predicates is, mode by mode, the list of modes the game asked (or still
## asks) with where it stands for one (docs/OFICINAS.md, 11.1); what it sends
## over the net comes back the same; teleport() for any reason of its own
## drops everything the three places that moved it dropped between them; it
## says what it is and what it can do; and the level's creature is its locust.
##
## And the places already moved over to it (the director, the dread aura, the
## world's sound, the mind and its phantoms, the lifts, the sets, coming back
## and the floor kept) ask the creature nothing else, and get what they
## computed before: the director's distances, the dread's route, the
## presence's, the face and the stare, the lies of a mind going; each of the
## three places that move it (lifts.apply_locust_ride,
## televisions.warp_creature, revival.relocate_creature), for every way of
## driving it, leaves it exactly as its own hand did, its draws included;
## following the survivors to their planta, its den and what a floor kept
## holds of it are what they were; and a creature that rides no lift and
## steps out of no set is left alone by them, but for being told the
## survivors have gone on.
##
## And the capture (executions.gd, its tape and its blood) asks the creature
## only the contract, its own part of the scene asked of its capture style
## (game/app/capture_styles/locust_capture.gd): for captures staged from
## several places and ways of being caught, the style gives what
## executions.gd computed before, to the last draw -- where it ends up
## standing, which way it faces, how they were caught, how the body goes
## down -- and the same places at every beat of the scene; begin_capture()
## and end_capture() do what was done to it by hand; and a creature with no
## style catches nobody.
##
## And the net (match_net.gd), the observer (observer_view.gd and
## observer_gizmos.gd), the floor's ledger, the wardrobe got into, the
## settings and every bot file but The Locust's own threat model ask the
## creature only the contract: the RPCs are the ones they were, with their
## arguments; what is packed and pushed is the same bytes and does the same;
## a strike its hunter claims takes, over staged strikes from the open, a
## corner and a wardrobe, with one survivor and two, whom it took before;
## what its hunter is shown and how the machine takes over are what they
## were; the observer's lines, dump and marks are the ones it wrote and drew;
## and the bots mind it with the threat model of its kind.
const CREATURE := preload("res://game/enemies/creature.gd")
const LOCUST := preload("res://game/enemies/locust/hotel_locust.gd")
const LOCUST_SCENE := preload("res://game/enemies/locust/locust.tscn")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GENERATOR := preload("res://game/world/generation/map_generator.gd")
const SAVE := preload("res://game/app/floor_save.gd")
const SCORE := preload("res://game/app/capture_score.gd")
const REMOTE := preload("res://game/net/remote_player.gd")
const GIZMOS := preload("res://game/app/observer_gizmos.gd")
const THREATS := preload("res://tools/bots/bot_threats.gd")
const LIES_PATH := "res://game/app/hallucinations/locust_hallucinations.gd"
const STYLE_PATH := "res://game/app/capture_styles/locust_capture.gd"
## What plays a capture out: the creature read only through the contract,
## its own part of the scene asked of its capture style.
const CAPTURE := ["res://game/app/executions.gd", "res://game/app/death_tape.gd", "res://game/app/blood.gd"]
## What reads the creature only through the contract.
const CONSUMERS := ["res://game/director/pacing_director.gd", "res://game/audio/dread_aura.gd", "res://game/audio/world_audio.gd", "res://game/app/sanity.gd", "res://game/app/phantom_sight.gd", "res://game/app/phantom_passage.gd", "res://game/app/lifts.gd", "res://game/app/televisions.gd", "res://game/app/revival.gd", "res://game/app/floor_save.gd"]
## Of those, what holds nothing of The Locust's own either: its passage is
## one of its lies (locust_hallucinations), and knows whose.
const NEUTRAL := ["res://game/director/pacing_director.gd", "res://game/audio/dread_aura.gd", "res://game/audio/world_audio.gd", "res://game/app/sanity.gd", "res://game/app/phantom_sight.gd", "res://game/app/lifts.gd", "res://game/app/televisions.gd", "res://game/app/revival.gd", "res://game/app/floor_save.gd"]
## The last to move over (docs/OFICINAS.md 11.1, steps 9 to 11): the net, the
## observer and what else of the game still read The Locust; and, scanned
## from their folder, the bots but for The Locust's threat model, which is
## The Locust's to know.
const NET := "res://game/net/match_net.gd"
const MOVED := [NET, "res://game/app/observer_view.gd", "res://game/app/observer_gizmos.gd", "res://game/app/run_ledger.gd", "res://game/app/interaction.gd", "res://game/app/presentation_rig.gd"]
const BOTS := "res://tools/bots"
const THREAT_MODEL := "res://tools/bots/bot_threat.gd"
## The one thing of the Locust's folder each may still name: the observer's
## reading by ear is its echo_view (only for a creature that can(&"echo")),
## and the bots thread their own routes through doorways with
## door_threading, which knows nothing of it.
const KEPT := {"observer_view.gd": "res://game/enemies/locust/echo_view.gd", "bot_nav.gd": "res://game/enemies/locust/door_threading.gd"}
## match_net's RPCs and how many arguments each takes, as they were before it
## asked the contract: the wire is these.
const RPCS := {"begin": 2, "report_ready": 1, "go": 0, "player_state": 2, "locust_state": 1, "minds_state": 1, "session_state": 6, "request_door": 3, "door_swung": 4, "door_settled": 2, "request_television": 1, "television_state": 2, "request_warp": 1, "warp_state": 1, "request_container": 1, "container_state": 3, "request_panel": 2, "panel_state": 2, "request_code": 1, "code_state": 0, "revived_state": 3, "request_lift": 1, "ride_state": 2, "floor_left": 0, "locust_rode": 1, "request_hide": 3, "hide_state": 3, "hide_forced": 1, "player_noise": 3, "play_world_sound": 4, "locust_call": 3, "strike": 2, "request_force": 1, "request_shriek": 0, "shriek_reveal": 1, "heard_contact": 6, "execute_start": 4, "tell_lens": 3, "lens_settled": 3, "floor_summary": 1, "player_card": 2, "sheet_chunk": 3, "sheet_confirmed": 3, "restore": 7, "back_to_room": 0}
## The observer's words for The Locust's modes, as it wrote them (in the order
## of hotel_locust.Mode).
const OLD_WORDS := ["patrulla", "investiga", "persigue", "busca", "prepara", "se repone", "alerta", "armario", "ejecuta", "acecha"]
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
		# run_ledger.follow_hunt(): a chase
		"is_chasing": [LOCUST.Mode.CHASE, LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER],
		# match_net.warp_busy() and lifts.creature_crossing()'s `busy` (the
		# rest of that list is lifts_questions())
		"is_engaged": [LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER, LOCUST.Mode.EXECUTE, LOCUST.Mode.WARDROBE, LOCUST.Mode.LURK],
		# lifts.aim_at_lift() (now The Locust's own) and lifts.apply_locust_ride()
		"is_roaming": [LOCUST.Mode.PATROL, LOCUST.Mode.SEARCH, LOCUST.Mode.INVESTIGATE],
		# pacing_director.update(): no lead unless PATROL or SEARCH
		"accepts_leads": [LOCUST.Mode.PATROL, LOCUST.Mode.SEARCH],
		# televisions.creature_channel_hop()'s `looking`
		"is_wary": [LOCUST.Mode.SEARCH, LOCUST.Mode.INVESTIGATE],
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
	consumers()
	capture_readers()
	distances(it)
	director_questions(it)
	routes(it)
	stares(it)
	hallucinations(it)
	var copy = await puppet()
	round_trip(it, copy)
	teleport_puppet(copy)
	copy.queue_free()
	await process_frame
	teleport_machine(it)
	moved_sites(it)
	lifts_questions(it)
	dens(it)
	kept(it)
	capture_hold(it)
	it.control = "ai"
	it.mode = LOCUST.Mode.PATROL
	staged_captures(it)
	it.control = "ai"
	it.mode = LOCUST.Mode.PATROL
	moved_readers()
	await wire(it)
	await strikes(it)
	hunter(it)
	observed(it)
	threat_models(it)
	it.control = "ai"
	it.mode = LOCUST.Mode.PATROL
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
	var director_wrong: Array = []
	for value in LOCUST.Mode.values():
		it.mode = value
		var label: String = LOCUST.Mode.keys()[value]
		for predicate in lists:
			if bool(it.call(predicate)) != (lists[predicate] as Array).has(value):
				wrong[predicate] = wrong.get(predicate, []) + [label]
		# The director asks it now: hostile() is still its old list, and a
		# burnt-out mind's lead is still for a creature on its rounds.
		if level.director == null or bool(level.director.hostile()) != (lists["is_hostile"] as Array).has(value) or (it.activity() == &"roam") != (value == LOCUST.Mode.PATROL): director_wrong.append(label)
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
	check("El director ve hostil lo que veía, y de ronda solo a PATROL", director_wrong.is_empty(), "difiere en %s" % str(director_wrong))
	check("Cada modo tiene su palabra, y son todas distintas", words.size() == LOCUST.Mode.size() and not words.has(&""))
	check("mode_name() es el nombre del modo", names_right)

func identity(it) -> void:
	check("kind_id() es locust", it.kind_id() == &"locust")
	check("Sube en ascensor, sale por las teles, abre armarios, chilla y se la caza de oído", it.can(&"lifts") and it.can(&"tv_travel") and it.can(&"wardrobes") and it.can(&"shriek") and it.can(&"echo"))
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
	var lies = it.hallucinations()
	check("Sus alucinaciones son las suyas (locust_hallucinations.gd)", lies is Script and (lies as Script).resource_path == LIES_PATH)
	var style: Variant = it.capture_style()
	var made = level.executions.style()
	check("Sus capturas las juega su estilo (locust_capture.gd), hecho una vez y guardado", style is Script and (style as Script).resource_path == STYLE_PATH and made != null and made.get_script() == style and level.executions.style() == made and made.level == level)
	check("Unas líneas para el observador, la primera su nombre", not it.debug_lines().is_empty() and it.debug_lines()[0].begins_with("THE LOCUST (") and String(it.debug_state().get("modo", "")) == OLD_WORDS[it.mode])

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

## A script's code without its comments (a # inside a string stays).
static func code_of(path: String) -> String:
	var kept: PackedStringArray = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var quoted := false
		var cut := line.length()
		for i in line.length():
			if line[i] == "\"": quoted = not quoted
			elif line[i] == "#" and not quoted:
				cut = i
				break
		kept.append(line.substr(0, cut))
	return "\n".join(kept)

## Every name the contract answers to: creature.gd's own and its body's.
static func contract_names() -> Dictionary:
	var names := {}
	var base: Script = load("res://game/enemies/creature.gd")
	for method in base.get_script_method_list(): names[String(method.name)] = true
	for property in base.get_script_property_list(): names[String(property.name)] = true
	for constant in base.get_script_constant_map(): names[String(constant)] = true
	for method in ClassDB.class_get_method_list("CharacterBody3D"): names[String(method.name)] = true
	for property in ClassDB.class_get_property_list("CharacterBody3D"): names[String(property.name)] = true
	return names

## What the places moved over to the contract read of the creature (`it.` in
## the director, `creature.` elsewhere): only the contract, no mode of The
## Locust, never by level.locust; and, but for its passage, nothing of its own.
func consumers() -> void:
	var names := contract_names()
	var reads := RegEx.create_from_string("\\b(?:it|creature)\\.([A-Za-z_][A-Za-z0-9_]*)")
	var locust_ways := RegEx.create_from_string("\\bMode\\.|\\.mode\\b|\\blevel\\.locust\\b")
	for path in CONSUMERS:
		var code := code_of(path)
		var file: String = path.get_file()
		var asked := {}
		var foreign := {}
		for hit in reads.search_all(code):
			var member := hit.get_string(1)
			asked[member] = true
			if not names.has(member): foreign[member] = true
		check("%s le pregunta a la criatura solo lo del contrato" % file, not asked.is_empty() and foreign.is_empty(), "lee %s" % str(foreign.keys()))
		var found := locust_ways.search(code)
		check("%s no compara modos de The Locust ni la lee por level.locust" % file, found == null, "encuentra %s" % (found.get_string() if found != null else ""))
	for path in NEUTRAL:
		var code := code_of(path)
		check("%s no guarda nada propio de The Locust" % path.get_file(), not code.contains("enemies/locust") and not code.contains("hotel_locust") and not code.contains("chase/grunts"))

## The same of what plays a capture out (executions.gd, death_tape.gd,
## blood.gd), by name as well (`creature.get("x")`, `"x" in creature`): its
## visual, its mask, its pounce and its execution are its style's to ask.
## blood.gd asks the creature nothing at all: the style says where it stands.
func capture_readers() -> void:
	var names := contract_names()
	var reads := RegEx.create_from_string("\\b(?:it|creature)\\.([A-Za-z_][A-Za-z0-9_]*)")
	var by_name := RegEx.create_from_string("\\b(?:it|creature)\\.(?:get|set)\\(\"([A-Za-z_][A-Za-z0-9_]*)\"|\"([A-Za-z_][A-Za-z0-9_]*)\" in (?:it|creature)\\b")
	var locust_ways := RegEx.create_from_string("\\bMode\\.|\\.mode\\b|\\blevel\\.locust\\b")
	for path in CAPTURE:
		var code := code_of(path)
		var file: String = path.get_file()
		var foreign := {}
		for hit in reads.search_all(code):
			if not names.has(hit.get_string(1)): foreign[hit.get_string(1)] = true
		for hit in by_name.search_all(code):
			var member: String = hit.get_string(1) if not hit.get_string(1).is_empty() else hit.get_string(2)
			if not names.has(member): foreign[member] = true
		check("%s le pregunta a la criatura solo lo del contrato" % file, foreign.is_empty(), "lee %s" % str(foreign.keys()))
		var found := locust_ways.search(code)
		check("%s no compara modos de The Locust ni la lee por level.locust" % file, found == null, "encuentra %s" % (found.get_string() if found != null else ""))
		check("%s no guarda nada propio de The Locust" % file, not code.contains("enemies/locust") and not code.contains("hotel_locust") and not code.contains("locust_visual") and not code.contains("capture_styles/locust"))
	check("executions.gd sí le pregunta: el estilo, la captura y lo que dura", code_of(CAPTURE[0]).contains("creature.capture_style()") and code_of(CAPTURE[0]).contains("creature.begin_capture(") and code_of(CAPTURE[0]).contains("creature.end_capture()") and code_of(CAPTURE[0]).contains("creature.capture_length()"))

## The director's two distances: walk() is the floor's walking between two
## rooms (FLOOR.route_metres), reach() the creature's own travel
## (travel_metres); for The Locust both are, room to room, what walk() was
## before, its walk_from().
func distances(it) -> void:
	var director = level.director
	if director == null:
		check("El piso tiene director", false)
		return
	var rooms: Array = level.manifest.rooms
	var differ: Array = []
	var pairs := 0
	for room in rooms:
		if FLOOR.is_void(room) or int(room.id) % 5 != 0: continue
		var from := int(room.id)
		var before: Dictionary = it.walk_from(from)
		for other in rooms:
			var to := int(other.id)
			var old := float(before.get(to, INF))
			if old != INF: pairs += 1
			if float(director.walk(from, to)) != old or float(director.reach(from, to)) != old: differ.append([from, to])
	check("walk() y reach() del director son, sala a sala, el walk_from() de antes (%d pares)" % pairs, differ.is_empty() and pairs > 100, "difieren %s" % str(differ.slice(0, 5)))
	var here := int(FLOOR.room_at(rooms, it.global_position).get("id", -1))
	var kept = level.creature
	level.creature = null
	var gone: bool = float(director.reach(here, here)) == INF and float(director.walk(here, here)) == 0.0
	level.creature = kept
	check("Sin criatura, reach() no llega a nada y walk() sigue siendo andar", gone)
	check("Ni a ni desde una sala que no hay", float(director.walk(-1, here)) == INF and float(director.reach(here, -1)) == INF)

## What else the director asks it: a room it has just searched round, whether
## it has begun to make somebody out, where it is going.
func director_questions(it) -> void:
	var searched: Dictionary = it.searched_until.duplicate()
	var detection: float = it.detection
	var rooms: Array = level.manifest.rooms
	it.searched_until = {1: it.clock + 10.0, 2: it.clock - 1.0, 3: it.clock}
	var same := true
	for id in [0, 1, 2, 3, 4]:
		if it.searched_lately(id) != (float(it.searched_until.get(id, -INF)) > it.clock): same = false
	check("searched_lately() es searched_until contra su reloj", same and it.searched_lately(1) and not it.searched_lately(2) and not it.searched_lately(0) and rooms.size() > 4)
	it.searched_until = searched
	same = true
	for value in [0.0, LOCUST.SUSPICION - 0.01, LOCUST.SUSPICION, 0.6, 1.3]:
		it.detection = value
		if it.noticing() != (it.detection >= LOCUST.SUSPICION): same = false
	it.detection = detection
	check("noticing() es su sospecha desde SUSPICION", same)
	check("control, grace, dull y su azar son del contrato", "control" in contract_names() and "grace" in contract_names() and "dull" in contract_names() and "rng" in contract_names())

## presence_route() and sound_route() on a live floor, with the creature put
## in rooms near and far of the listener (and the face it is looked at by):
## exactly what the dread aura and the presence computed from it before.
func routes(it) -> void:
	var audio = level.world_audio
	var aura = audio.aura
	var listener: Vector3 = audio.listener_position()
	var kept: Vector3 = it.global_position
	var spots: Array = []
	var ahead: Vector3 = -level.player.camera.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	for metres in [2.5, 5.0, 9.0]: spots.append(level.player.global_position + ahead * metres)
	var centres: Array = []
	for room in level.manifest.rooms:
		if not FLOOR.is_void(room): centres.append(FLOOR.position_of(room) + Vector3(0, 0.04, 0))
	centres.sort_custom(func(a, b): return a.distance_to(listener) < b.distance_to(listener))
	for i in range(0, mini(centres.size(), 40), 3): spots.append(centres[i])
	spots.append(centres[-1])
	var felt_wrong := 0
	var heard_wrong := 0
	var face_wrong := 0
	var walked := 0
	var echoed := 0
	var straight := 0
	for spot in spots:
		it.global_position = spot
		var felt_before: Array = aura.route_to(listener, it.global_position)
		var felt: Array = it.presence_route(listener)
		var heard_before: Dictionary = audio.route_source(it.global_position + Vector3(0, 1.4, 0), it.get_rid())
		var heard: Dictionary = it.sound_route(listener)
		if felt != felt_before: felt_wrong += 1
		if heard != heard_before or str(heard) != str(heard_before): heard_wrong += 1
		if it.face_point() != it.global_position + Vector3(0, LOCUST.EYE_HEIGHT, 0): face_wrong += 1
		if float(felt[0]) < INF and FLOOR.planta_of(spot.y) == FLOOR.planta_of(listener.y) and spot.distance_to(listener) < aura.start_distance * 1.3: walked += 1
		if bool(heard.get("audible", false)):
			if bool(heard.get("echo", false)): echoed += 1
			else: straight += 1
	it.global_position = kept
	check("presence_route() es el route_to() del aura desde donde está (%d sitios, %d andando)" % [spots.size(), walked], felt_wrong == 0 and walked > 0, "difiere en %d" % felt_wrong)
	check("sound_route() es el route_source() de su presencia (%d de frente, %d por las puertas)" % [straight, echoed], heard_wrong == 0 and echoed > 0 and straight > 0, "difiere en %d" % heard_wrong)
	check("face_point() es la cabeza que la cordura miraba", face_wrong == 0)

## sanity.sight_of_creature() through face_point() and gaze(): seen and
## stared at as it was, with The Locust's head turned and not, ahead of the
## camera and off it.
func stares(it) -> void:
	var body = level.player
	var kept: Vector3 = it.global_position
	var yaw: float = it.rotation.y
	var grace: float = it.grace
	var look: Vector3 = it.visual.look_point
	it.grace = 0.0
	var ahead: Vector3 = -body.camera.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	# Its body turned away from the player: only its head turned is a stare.
	it.rotation.y = atan2(-ahead.x, -ahead.z)
	var wrong := 0
	var seen := {}
	for metres in [2.0, 4.0, 7.0, 12.0, 30.0]:
		for side in [0.0, 1.5]:
			it.global_position = body.global_position + ahead * metres + ahead.cross(Vector3.UP) * side
			for turned in [false, true]:
				it.visual.look_point = body.camera.global_position if turned else Vector3.INF
				for lit in [true, false]:
					var now: int = level.sanity.sight_of_creature(body, lit)
					if now != old_sight(it, body, lit): wrong += 1
					seen[now] = true
	it.visual.look_point = look
	it.grace = grace
	it.rotation.y = yaw
	it.global_position = kept
	check("La cordura la ve y le sostiene la mirada como antes (%s)" % str(seen.keys()), wrong == 0 and seen.has(2) and seen.has(1), "difiere en %d" % wrong)

## sight_of_creature() as it was, reading The Locust itself.
func old_sight(it, body, lit: bool) -> int:
	if it.grace > 0.0 or not is_instance_valid(body.camera): return 0
	var eye: Vector3 = body.camera.global_position
	var towards: Vector3 = it.global_position + Vector3(0, 1.2, 0) - eye
	var gap := towards.length()
	if gap > level.sanity.SANITY_SEEN or gap < 0.01: return 0
	if not lit and not body.torch.visible and gap > 6.0: return 0
	if -body.camera.global_basis.z.dot(towards / gap) < 0.72: return 0
	var query := PhysicsRayQueryParameters3D.create(eye, eye + towards, 1 | 8 | 64)
	query.exclude = [body.get_rid()]
	if not level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return 0
	var head: Vector3 = it.global_position + Vector3(0, LOCUST.EYE_HEIGHT, 0)
	var gaze: Vector3 = -it.global_basis.z
	var visual = it.visual
	if is_instance_valid(visual) and "look_point" in visual and visual.look_point != Vector3.INF: gaze = visual.look_point - head
	var to_eye := eye - head
	if gaze.length() < 0.01 or to_eye.length() < 0.01: return 1
	return 2 if gaze.normalized().dot(to_eye.normalized()) >= cos(deg_to_rad(level.sanity.STARE_CONE)) else 1

## The lies of a mind going are The Locust's own, made under the mind: its
## call, it walking past, the model and poses it is seen in.
func hallucinations(it) -> void:
	var sight = level.sanity.ensure_sight()
	var lies = level.sanity.lies
	check("La cordura hace bajo ella las mentiras de su criatura", is_instance_valid(lies) and lies.get_script() == it.hallucinations() and lies.get_parent() == level.sanity)
	check("Que dicen su llamada, su paso, de dónde sale y su callar", lies.has_method("false_call") and lies.has_method("walk_past") and lies.has_method("walk_start") and lies.has_method("quiet"))
	check("Y la criatura que se ve donde no está sale de ellas", sight != null and sight.lies == lies and level.sanity.creature_lies() == lies)
	sight.ensure_model()
	check("Con el modelo de The Locust, a su tamaño y con quien la pose", is_instance_valid(sight.model) and sight.model.get_parent() == sight and sight.model.scale.is_equal_approx(Vector3.ONE * 1.95) and sight.poser != null and not sight.model.visible)
	check("Su cabeza es un hueso del modelo", sight.poser.index(lies.HEAD) >= 0 and lies.BODY_BONES.all(func(bone): return sight.poser.index(bone) >= 0))

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
	copy.teleport(point, 1.25)
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
	it.teleport(point, 2.0)
	var forgot := journey_forgotten(it)
	for what in forgot: check("La criatura trasladada queda %s" % what, forgot[what])
	check("Su ronda empieza en la sala adonde llega", int(it.patrol_room) == int(FLOOR.room_at(level.manifest.rooms, point).get("id", -1)))
	check("Lo que haga allí no lo decide el traslado", it.mode == LOCUST.Mode.SEARCH and is_equal_approx(it.ride_hold, hold) and it.global_position.is_equal_approx(point))
	it.mode = LOCUST.Mode.PATROL

# --- The three places that move it, the lifts' questions, its den, the floor kept

## A hunter's channels, as locust_player keeps them, on a body of its own.
static func stand_in_driver() -> Node:
	var source := GDScript.new()
	source.source_code = "extends Node\nvar channel_open := true\n"
	source.reload()
	var driver := Node.new()
	driver.set_script(source)
	return driver

## The bare contract, keeping a note of each time it is told the survivors
## have gone on (follow_to_planta()) and nothing else of its own.
static func following_creature() -> CharacterBody3D:
	var source := GDScript.new()
	source.source_code = "extends \"res://game/enemies/creature.gd\"\nvar followed: Array = []\nfunc follow_to_planta(stage: int, fresh := false) -> void: followed.append([stage, fresh])\n"
	source.reload()
	return source.new()

## The middle of a room of the first planta, not `but`, not in a corridor,
## and no car arriving there.
func room_point(but := -1) -> Vector3:
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != 0 or int(room.id) == but or FLOOR.is_void(room) or bool(room.get("corridor", false)): continue
		var point := FLOOR.position_of(room) + Vector3(0, 0.04, 0)
		if level.lifts.car_arriving_at(point) < 0: return point
	return Vector3.INF

## The same creature, the same way every time: driven by `control`, in
## `mode`, at `at`, with all that any of the three left behind (dirty()) and
## all that what is done with it once moved reads, and its draws at `draws`.
func pose(it, control: String, mode: int, at: Vector3, draws: int) -> void:
	it.control = control
	dirty(it)
	it.global_position = at
	it.rotation.y = 0.3
	it.mode = mode
	it.state_time = 1.5
	it.patrol_room = int(FLOOR.room_at(level.manifest.rooms, at).get("id", 0))
	it.last_known = Vector3(1.0, 0.0, 1.0)
	it.last_heading = Vector3(0.0, 0.0, 1.0)
	it.destination = Vector3(2.0, 0.0, 2.0)
	it.search_plan = []
	it.search_origin = Vector3.INF
	it.search_hide = null
	it.area_spent = 0.0
	it.clue_idle = 0.0
	it.grace = 0.0
	it.wardrobe = null
	it.focus = null
	it.detection = 0.0
	it.light_exposure = 0.3
	it.had_quarry = true
	it.doubting = 0.5
	it.lift_bound = false
	it.pause_time = 0.4
	it.leaving = true
	it.lead = {}
	it.observed_hide = null
	it.lurk = {}
	it.pouncing = false
	it.last_grunt = -1
	it.calls_made = 0
	it.aimed = false
	it.rng.state = draws
	if is_instance_valid(it.driver): it.driver.channel_open = true

## Everything of it that moving it, or what is done with it once there, may
## touch.
func state_of(it) -> Dictionary:
	return {
		"position": it.global_position, "yaw": it.rotation.y, "velocity": it.velocity, "speed": it.speed,
		"net_states": it.net_states.duplicate(true), "net_clock": it.net_clock, "ride_point": it.ride_point, "ride_hold": it.ride_hold,
		"channel_open": it.driver.get("channel_open") if is_instance_valid(it.driver) else null,
		"path": it.path, "path_index": it.path_index, "crossings": it.crossings.duplicate(true), "rounds": it.rounds.duplicate(true), "passing_time": it.passing_time,
		"dodge_left": it.dodge_left, "stuck_clock": it.stuck_clock, "stuck_linger": it.stuck_linger, "stuck_level": it.stuck_level, "stuck_origin": it.stuck_origin,
		"linger_goal": it.linger_goal, "linger_best": it.linger_best, "repath": it.repath, "patrol_room": it.patrol_room,
		"mode": it.mode, "state_time": it.state_time, "last_known": it.last_known, "last_heading": it.last_heading, "destination": it.destination,
		"search_plan": it.search_plan.duplicate(true), "search_origin": it.search_origin, "search_hide": it.search_hide, "area_spent": it.area_spent, "clue_idle": it.clue_idle,
		"grace": it.grace, "wardrobe": it.wardrobe, "focus": it.focus, "detection": it.detection, "light_exposure": it.light_exposure,
		"had_quarry": it.had_quarry, "doubting": it.doubting, "lift_bound": it.lift_bound, "pause_time": it.pause_time, "leaving": it.leaving,
		"lead": it.lead.duplicate(true), "observed_hide": it.observed_hide, "lurk": it.lurk.duplicate(true), "pouncing": it.pouncing,
		"last_grunt": it.last_grunt, "calls_made": it.calls_made, "aimed": it.aimed, "draws": it.rng.state,
	}

## The keys two states differ in.
static func differences(one: Dictionary, two: Dictionary) -> Array:
	var keys: Array = []
	for key in one:
		if not two.has(key) or one[key] != two[key]: keys.append(key)
	return keys

## What lifts.apply_locust_ride did to it by hand before teleport() (the
## car's doors and bell aside).
func old_lift(it, point: Vector3) -> void:
	it.global_position = point
	it.velocity = Vector3.ZERO
	it.net_states.clear()
	it.net_clock = 0.0
	if it.control == "puppet":
		it.ride_point = point
		it.ride_hold = 2.0
	if it.control == "ai":
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, point)
		if not room.is_empty(): it.patrol_room = int(room.id)
		if it.mode in [LOCUST.Mode.PATROL, LOCUST.Mode.SEARCH, LOCUST.Mode.INVESTIGATE]:
			it.last_known = point
			it.last_heading = Vector3.ZERO
			it.set_mode(LOCUST.Mode.SEARCH)

## What televisions.warp_creature did to it by hand (its static aside).
func old_television(it, index: int) -> void:
	var set = level.televisions[index]
	it.global_position = level.tvs.television_exit(index) + Vector3(0, 0.04, 0)
	it.rotation.y = set.rotation.y + PI
	if it.control == "puppet":
		it.ride_point = it.global_position
		it.ride_hold = 2.0
	it.velocity = Vector3.ZERO
	it.speed = 0.0
	it.net_states.clear()
	it.net_clock = 0.0
	if is_instance_valid(it.driver): it.driver.channel_open = false
	if it.control == "ai":
		it.forget_route()
		it.last_known = it.global_position
		it.last_heading = -it.global_basis.z
		it.set_mode(LOCUST.Mode.SEARCH)

## What revival.relocate_creature did to it by hand.
func old_revival(it, point: Vector3, rest: float) -> void:
	if it.control == "ai": old_relocate(it, point, rest)
	else:
		it.global_position = point
		it.grace = maxf(it.grace, rest)
		if it.control == "player" and it.mode != LOCUST.Mode.PATROL: it.set_mode(LOCUST.Mode.PATROL)
	it.velocity = Vector3.ZERO
	it.speed = 0.0
	if it.control == "puppet":
		it.ride_point = point
		it.ride_hold = 2.0
	it.net_states.clear()
	it.net_clock = 0.0

## hotel_locust.relocate() as it was: only ever asked of the machine.
func old_relocate(it, point: Vector3, rest: float) -> void:
	it.global_position = point
	it.velocity = Vector3.ZERO
	it.speed = 0.0
	it.forget_route()
	it.wardrobe = null
	it.focus = null
	it.detection = 0.0
	it.light_exposure = 0.0
	it.last_known = point
	var here := FLOOR.room_at(level.manifest.rooms, point)
	if not here.is_empty(): it.patrol_room = int(here.id)
	it.set_mode(LOCUST.Mode.PATROL)
	it.destination = point
	it.grace = maxf(it.grace, rest)
	it.had_quarry = false
	it.doubting = 0.0

## A set of the floor lit (quietly) for these, by index.
func light_one() -> int:
	for index in level.televisions.size():
		if is_instance_valid(level.televisions[index]):
			level.apply_television(index, true, true)
			return index
	return -1

## The car, the set and a stage given back, each for every way of driving it
## and several things it may be doing: from the same creature, teleport()
## and what each does after leave it exactly as each one's hand did before,
## to the last of its draws. And what each one keeps, said.
func moved_sites(it) -> void:
	var driver := stand_in_driver()
	it.add_child(driver)
	it.driver = driver
	var at := room_point()
	var to := room_point(int(FLOOR.room_at(level.manifest.rooms, at).get("id", -1)))
	var lit := light_one()
	var draws: int = it.rng.state
	check("Hay dos salas de la primera planta y una tele para probar", at != Vector3.INF and to != Vector3.INF and lit >= 0)
	var old_ways := {
		"lift": func(): old_lift(it, to),
		"television": func(): old_television(it, lit),
		"revival": func(): old_revival(it, to, 7.0),
	}
	var new_ways := {
		"lift": func(): level.lifts.apply_locust_ride(to),
		"television": func(): level.tvs.warp_creature(lit),
		"revival": func(): level.revival.relocate_creature(to, 7.0),
	}
	var modes := {
		"lift": [LOCUST.Mode.PATROL, LOCUST.Mode.SEARCH, LOCUST.Mode.INVESTIGATE, LOCUST.Mode.CHASE, LOCUST.Mode.LURK],
		"television": [LOCUST.Mode.PATROL, LOCUST.Mode.SEARCH, LOCUST.Mode.CHASE],
		"revival": [LOCUST.Mode.PATROL, LOCUST.Mode.CHASE, LOCUST.Mode.WARDROBE],
	}
	var names := {"lift": "El ascensor", "television": "La tele", "revival": "La etapa devuelta"}
	for way in old_ways:
		var differ: Array = []
		var cases := 0
		for control in ["ai", "puppet", "player"]:
			for mode in modes[way]:
				pose(it, control, mode, at, draws)
				(old_ways[way] as Callable).call()
				var before := state_of(it)
				pose(it, control, mode, at, draws)
				(new_ways[way] as Callable).call()
				var now := state_of(it)
				cases += 1
				for key in differences(before, now): differ.append("%s %s: %s" % [control, LOCUST.Mode.keys()[mode], key])
		check("%s la deja como la dejaba a mano, con teleport() (%d casos, de la IA, de una copia y de un cazador)" % [names[way], cases], differ.is_empty() and cases >= 9, str(differ.slice(0, 6)))
	var to_room := int(FLOOR.room_at(level.manifest.rooms, to).get("id", -1))
	var from_room := int(FLOOR.room_at(level.manifest.rooms, at).get("id", -1))
	# The car keeps its stride, its route and a hunter's channels, and its
	# rounds start from where it is let out.
	pose(it, "ai", LOCUST.Mode.CHASE, at, draws)
	level.lifts.apply_locust_ride(to)
	check("En el ascensor no suelta su paso, su ruta ni los canales, y su ronda empieza donde sale", is_equal_approx(it.speed, 4.0) and not it.path.is_empty() and it.stuck_level == 2 and driver.channel_open and it.patrol_room == to_room and it.net_states.is_empty() and it.mode == LOCUST.Mode.CHASE)
	# A set stops it dead and closes the channels; it forgets its route only
	# where it drives itself, and its rounds stay where they were.
	pose(it, "ai", LOCUST.Mode.CHASE, at, draws)
	level.tvs.warp_creature(lit)
	var machine: bool = is_zero_approx(it.speed) and it.path.is_empty() and not driver.channel_open and it.patrol_room == from_room and it.mode == LOCUST.Mode.SEARCH
	pose(it, "puppet", LOCUST.Mode.CHASE, at, draws)
	level.tvs.warp_creature(lit)
	check("Por una tele se para y cierra los canales; la ruta solo la olvida la IA, y su ronda sigue donde estaba", machine and not it.path.is_empty() and not driver.channel_open and it.ride_hold == 2.0 and it.mode == LOCUST.Mode.CHASE)
	# A stage given back stops it dead; a hunter's channels and route stay,
	# and what it was in the middle of is over; where it drives itself,
	# relocate() forgets the route and moves its rounds.
	pose(it, "player", LOCUST.Mode.CHASE, at, draws)
	level.revival.relocate_creature(to, 7.0)
	var hunter: bool = is_zero_approx(it.speed) and not it.path.is_empty() and driver.channel_open and it.mode == LOCUST.Mode.PATROL and it.grace >= 7.0 and it.patrol_room == from_room
	pose(it, "ai", LOCUST.Mode.CHASE, at, draws)
	level.revival.relocate_creature(to, 7.0)
	check("Devuelta la etapa se para y espera; el cazador conserva canales y ruta, la IA olvida a todos y su ronda empieza allí", hunter and it.path.is_empty() and driver.channel_open and it.mode == LOCUST.Mode.PATROL and it.patrol_room == to_room and it.detection == 0.0 and not it.had_quarry)
	unable(it, lit, to)
	level.apply_television(lit, false)
	it.driver = null
	driver.queue_free()
	it.control = "ai"
	it.rng.state = draws

## A creature that rides no lift and steps out of no set (the bare contract):
## standing where The Locust would have a car or a set, it has neither, and
## neither a set nor a car takes it anywhere; it is still told the survivors
## have gone on, to follow them its own way. Coming back still puts it where
## it is sent, to wait.
func unable(it, lit: int, to: Vector3) -> void:
	var set = level.televisions[lit]
	var set_stage: int = set.stage
	set.stage = level.session.stage
	var by_set: Vector3 = level.tvs.television_exit(lit) + Vector3(0, 0.04, 0)
	# Where The Locust would be: a wing behind the third stage, and at a lit
	# set of the stage in hand.
	var at := room_point()
	pose(it, "ai", LOCUST.Mode.SEARCH, at, it.rng.state)
	var locust_car: int = level.lifts.creature_car(3)
	it.global_position = by_set
	var locust_at_set: int = level.creature_at_television()
	var nobody = following_creature()
	root.add_child(nobody)
	level.creature = nobody
	nobody.global_position = at
	var no_car: bool = level.lifts.creature_car(3) == -1
	var lobby: Dictionary = level.lifts.lobby_time.duplicate()
	level.lifts.count_away(0.5)
	level.lifts.follow_players(3)
	var told: bool = nobody.followed == [[3, true]]
	level.lifts.creature_crossing(10.0)
	nobody.global_position = by_set
	var none_at_set: bool = level.creature_at_television(1000.0) == -1
	# Away from the set and from where the car lets out, facing anywhere but
	# out of the set: whichever of them took it would show.
	nobody.global_position = at
	nobody.rotation.y = wrapf(float(set.rotation.y) + PI + 1.0, -PI, PI)
	var still: Transform3D = nobody.global_transform
	level.tvs.warp_creature(lit)
	var not_by_set: bool = nobody.global_transform.is_equal_approx(still)
	level.lifts.apply_locust_ride(to)
	var not_by_car: bool = nobody.global_transform.is_equal_approx(still)
	var kept_save: Dictionary = SAVE.take(level).get("creature", {"x": 1})
	level.revival.relocate_creature(to, 5.0)
	var sent: bool = nobody.global_position.is_equal_approx(to) and nobody.grace >= 5.0 and nobody.velocity == Vector3.ZERO
	level.creature = it
	nobody.queue_free()
	set.stage = set_stage
	check("The Locust junto a una tele de su etapa la reconoce, y un ala atrás tiene coche", locust_at_set == lit and locust_car == 0)
	check("Una criatura que no viaja por las teles ni en ascensor no está en ninguna tele ni tiene coche", none_at_set and no_car and level.lifts.lobby_time == lobby)
	check("Una tele encendida no la saca por su pantalla", not_by_set)
	check("Ni el ascensor la deja en otra sala", not_by_car)
	check("Pero se le dice que los supervivientes se han ido, para que los siga a su manera", told)
	check("Del piso guardado no se guarda nada suyo, y devuelta la etapa va adonde se la manda a esperar", kept_save.is_empty() and sent)

## lifts.creature_busy() is, mode by mode and for every driver, the list
## creature_crossing() used to write; follow_players() and the reminder of
## creature_crossing() do through follow_to_planta() what aim_at_lift() did.
func lifts_questions(it) -> void:
	var at := room_point()
	var draws: int = it.rng.state
	var wrong: Array = []
	for control in ["ai", "puppet", "player"]:
		for value in LOCUST.Mode.values():
			it.control = control
			it.mode = value
			var busy: Array = [LOCUST.Mode.EXECUTE, LOCUST.Mode.WARDROBE, LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER, LOCUST.Mode.LURK]
			if control == "ai": busy += [LOCUST.Mode.CHASE, LOCUST.Mode.ALERT]
			if bool(level.lifts.creature_busy()) != busy.has(value): wrong.append("%s %s" % [control, LOCUST.Mode.keys()[value]])
	check("creature_busy() es, modo a modo y para cada mando, la lista del ascensor", wrong.is_empty(), "difiere en %s" % str(wrong))
	var car: Vector3 = level.hotel.lifts[0] if not level.hotel.lifts.is_empty() else Vector3.INF
	var differ: Array = []
	var cases := 0
	var aimed := 0
	for control in ["ai", "player"]:
		for value in [LOCUST.Mode.PATROL, LOCUST.Mode.SEARCH, LOCUST.Mode.INVESTIGATE, LOCUST.Mode.CHASE]:
			for noticed in [0.0, 0.5]:
				for near in [false, true]:
					for fresh in [true, false]:
						var setup := func():
							pose(it, control, value, at, draws)
							it.detection = noticed
							if near: it.destination = car
						setup.call()
						if fresh: old_follow(it, 3, true)
						else: old_aim(it, level.lifts.creature_car(3))
						var before := state_of(it)
						setup.call()
						if fresh: level.lifts.follow_players(3)
						else: it.follow_to_planta(3)
						var now := state_of(it)
						cases += 1
						if it.lift_bound: aimed += 1
						for key in differences(before, now): differ.append("%s %s %s %s %s: %s" % [control, LOCUST.Mode.keys()[value], noticed, near, fresh, key])
	check("Tras los supervivientes va al coche como antes, y gruñe al irse ellos (%d casos, %d al coche)" % [cases, aimed], differ.is_empty() and aimed > 0 and aimed < cases and level.lifts.creature_car(3) == 0, str(differ.slice(0, 6)))
	it.control = "ai"
	it.rng.state = draws

## follow_players() as it was, past its own guards.
func old_follow(it, stage: int, fresh: bool) -> void:
	var index: int = level.lifts.creature_car(stage)
	if index < 0 or index >= level.hotel.lifts.size(): return
	if fresh: it.grunt()
	old_aim(it, index)

## lifts.aim_at_lift() as it was.
func old_aim(it, index: int) -> void:
	if it.control != "ai" or index < 0 or index >= level.hotel.lifts.size(): return
	if it.mode not in [LOCUST.Mode.PATROL, LOCUST.Mode.SEARCH, LOCUST.Mode.INVESTIGATE]: return
	if it.detection >= LOCUST.SUSPICION: return
	var car: Vector3 = level.hotel.lifts[index]
	if it.mode == LOCUST.Mode.INVESTIGATE and it.destination.distance_to(car) < 1.0: return
	it.set_mode(LOCUST.Mode.INVESTIGATE)
	it.destination = car
	it.lift_bound = true
	var gates: Array = level.manifest.get("gates", [])
	if index < gates.size(): it.patrol_room = int(gates[index].get("beyond", it.patrol_room))
	it.repath = 0

## revival.stage_den() as it was.
func old_den(stage: int) -> int:
	var wing := stage - 1
	var entry := int(level.manifest.get("start", 0)) if wing <= 0 else FLOOR.entry_of(level.manifest, wing)
	var refuges: Array = level.manifest.get("refuges", [])
	var refuge := int(level.manifest.get("exit", -1)) if wing <= 0 or wing >= refuges.size() else int(refuges[wing])
	if entry < 0 or entry >= level.manifest.rooms.size(): return -1
	var distances: Array = GENERATOR.distance_map(level.manifest.adjacency, entry)
	var near_refuge: Array = GENERATOR.distance_map(level.manifest.adjacency, refuge) if refuge >= 0 else []
	var shut_out: Array = level.off_limits_rooms()
	var reach := 0
	for room in level.manifest.rooms:
		if int(room.get("wing", 0)) == wing and not shut_out.has(int(room.id)): reach = maxi(reach, int(distances[room.id]))
	var dens: Array = []
	for room in level.manifest.rooms:
		var hops: int = distances[room.id]
		if int(room.get("wing", 0)) != wing or shut_out.has(int(room.id)) or FLOOR.is_void(room) or hops <= 3: continue
		if not near_refuge.is_empty() and near_refuge[room.id] <= 2: continue
		if hops >= int(reach * 0.5) and hops <= int(ceil(reach * 0.8)): dens.append(int(room.id))
	if dens.is_empty(): return -1
	var draw := RandomNumberGenerator.new()
	draw.seed = hash([int(level.manifest.seed), "den"]) if wing <= 0 else hash([int(level.manifest.seed), "den", stage])
	return int(dens[draw.randi_range(0, dens.size() - 1)])

## Its den, stage by stage: the room revival.stage_den() drew, and the point
## revival.den_point() put it at.
func dens(it) -> void:
	var wrong: Array = []
	var found := 0
	for stage in range(1, level.session.stages + 1):
		var room := old_den(stage)
		var point := Vector3.INF
		if room >= 0:
			found += 1
			point = FLOOR.position_of(level.manifest.rooms[room])
			var map: RID = level.get_world_3d().navigation_map
			if NavigationServer3D.map_get_iteration_id(map) > 0: point = FLOOR.closest(map, point)
			point += Vector3(0, 0.04, 0)
		if int(it.den_room(stage)) != room or it.den_point(stage) != point: wrong.append(stage)
	check("den_point() es, etapa a etapa, la guarida que sorteaba la reaparición (%d con guarida)" % found, wrong.is_empty() and found > 0, "difiere en %s" % str(wrong))

## What a floor kept holds of it is what it held ({at, yaw}, the same bytes),
## and a checkpoint's put back does what floor_save.give() did by hand.
func kept(it) -> void:
	var at := room_point()
	var draws: int = it.rng.state
	pose(it, "ai", LOCUST.Mode.CHASE, at, draws)
	it.rotation.y = 0.85
	var old := {"at": it.global_position, "yaw": it.rotation.y}
	var saved: Dictionary = SAVE.take(level).get("creature", {})
	check("Lo que el piso guarda de ella es lo de siempre, byte a byte", saved == old and var_to_bytes(saved) == var_to_bytes(old) and it.save_state() == old)
	var to := room_point(int(FLOOR.room_at(level.manifest.rooms, at).get("id", -1)))
	var differ: Array = []
	for state in [{"at": to, "yaw": 1.1}, {"at": to}]:
		pose(it, "ai", LOCUST.Mode.CHASE, at, draws)
		old_relocate(it, state.at, SAVE.GRACE)
		it.rotation.y = float(state.get("yaw", 0.0))
		var before := state_of(it)
		pose(it, "ai", LOCUST.Mode.CHASE, at, draws)
		it.restore_state(state, SAVE.GRACE)
		for key in differences(before, state_of(it)): differ.append("%s: %s" % [str(state.keys()), key])
	check("Y un punto de control de antes la devuelve como la devolvía", differ.is_empty(), str(differ))
	it.rng.state = draws

# --- The capture, as executions.gd played it out --------------------------------

## What executions.apply_execution() did to it by hand.
func old_begin(it) -> void:
	if it.control != "puppet": it.begin_execution()

## What executions.release_execution() did to it by hand.
func old_end(it) -> void:
	if it.control != "puppet" and it.mode == LOCUST.Mode.EXECUTE: it.set_mode(LOCUST.Mode.SEARCH if it.control == "ai" else LOCUST.Mode.PATROL)

## begin_capture() and end_capture() leave it, for every way of driving it
## and whatever it was doing, exactly as executions.gd's own hand did.
func capture_hold(it) -> void:
	var at := room_point()
	var draws: int = it.rng.state
	var differ: Array = []
	var cases := 0
	var held := 0
	for control in ["ai", "puppet", "player"]:
		for mode in [LOCUST.Mode.PATROL, LOCUST.Mode.CHASE, LOCUST.Mode.EXECUTE, LOCUST.Mode.WARDROBE]:
			for ending in [false, true]:
				pose(it, control, mode, at, draws)
				if ending: old_end(it)
				else: old_begin(it)
				var before := state_of(it)
				pose(it, control, mode, at, draws)
				if ending: it.end_capture()
				else: it.begin_capture({"yaw": 0.3, "entry": "front"})
				var now := state_of(it)
				cases += 1
				if not ending and it.mode == LOCUST.Mode.EXECUTE and mode != LOCUST.Mode.EXECUTE: held += 1
				for key in differences(before, now): differ.append("%s %s %s: %s" % ["end" if ending else "begin", control, LOCUST.Mode.keys()[mode], key])
	check("begin_capture() y end_capture() la dejan como la dejaba executions.gd a mano (%d casos, %d sujetando)" % [cases, held], differ.is_empty() and held == 6, str(differ.slice(0, 6)))
	it.control = "ai"
	it.rng.state = draws

## executions.stage_capture() as it was, reading The Locust itself.
func old_stage(body: Node3D) -> Dictionary:
	var ex = level.executions
	var creature = level.locust
	var away: Vector3 = body.global_position - creature.global_position
	away.y = 0.0
	var distance := away.length()
	var wanted := clampf(distance, SCORE.HOLD_FAR.x, SCORE.HOLD_FAR.y)
	if distance >= 0.05 and absf(distance - wanted) > 0.02 and creature.control != "puppet" and not bool(body.hidden):
		creature.move_and_collide(away / distance * (distance - wanted))
		away = body.global_position - creature.global_position
		away.y = 0.0
		distance = away.length()
	var yaw: float = creature.rotation.y if distance < 0.05 else atan2(-away.x, -away.z)
	var chosen := old_entry(body, away)
	ex.captures += 1
	var seat := int(body.slot)
	var alone: bool = level.session.roster_count <= 1
	var look: bool = not bool(ex.glanced.get(seat, false)) and ex.rng.randi_range(1, ex.GLANCE_ALONE if alone else ex.GLANCE_TEAM) == 1
	if ex.forced.has("glance"): look = bool(ex.forced.glance)
	ex.glanced[seat] = look
	var side: float = float(ex.forced.get("side", chosen[1]))
	var feet: Vector3 = creature.global_position - Basis(Vector3.UP, yaw).z * SCORE.HOLD_NEAR
	var room := old_fall_room(feet, yaw, side, [body.get_rid(), creature.get_rid()])
	var hide: int = level.hotel.hides.find(body.hiding_place) if bool(body.hidden) and is_instance_valid(body.hiding_place) else -1
	return {
		"entry": String(ex.forced.get("entry", chosen[0])), "side": float(room[0]), "straight": bool(room[1]), "slump": bool(room[2]), "room": float(room[3]), "yaw": yaw, "hide": hide, "partner": ex.partner_of(body),
		"far": clampf(distance, SCORE.HOLD_FAR.x, SCORE.HOLD_FAR.y), "from": body.global_position, "facing": body.rotation.y,
		"crouched": bool(body.crouched), "torch": is_instance_valid(body.torch) and body.torch.visible,
		"glance": look, "seed": int(ex.forced.get("seed", ex.rng.randi() & 0x7fffffff)), "id": ex.captures,
	}

## executions.choose_entry() as it was.
func old_entry(body: Node3D, away: Vector3) -> Array:
	var creature = level.locust
	var chance := 1.0 if level.executions.rng.randf() < 0.5 else -1.0
	if bool(body.hidden) and is_instance_valid(body.hiding_place): return ["ambush" if creature.get("pouncing") == true else "wardrobe", chance]
	if bool(body.crouched): return ["above", chance]
	if away.length() < 0.05: return ["front", chance]
	var look := -Basis(Vector3.UP, body.rotation.y).z
	var towards := -away.normalized()
	var angle := rad_to_deg(look.angle_to(towards))
	if angle <= 50.0: return ["front", chance]
	if angle >= 130.0: return ["back", chance]
	return ["side", 1.0 if towards.dot(Basis(Vector3.UP, body.rotation.y).x) > 0.0 else -1.0]

## executions.fall_room(), clear_along() and fall_way() as they were.
func old_fall_room(feet: Vector3, yaw: float, side: float, exclude: Array) -> Array:
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for way in [side, -side]:
		if old_clear_along(space, feet, old_fall_way(yaw, float(way)), [0.35], exclude) >= SCORE.LIE_ROOM: return [float(way), false, false, SCORE.LIE_ROOM]
	var behind := old_clear_along(space, feet, old_fall_way(yaw, 0.0), [0.2, 0.6], exclude)
	if behind >= SCORE.LIE_ROOM: return [side, true, false, behind]
	return [side, false, true, behind]

func old_clear_along(space: PhysicsDirectSpaceState3D, feet: Vector3, along: Vector3, heights: Array, exclude: Array) -> float:
	var least: float = SCORE.LIE_ROOM
	for height in heights:
		var from: Vector3 = feet + Vector3.UP * float(height)
		var query := PhysicsRayQueryParameters3D.create(from, from + along * SCORE.LIE_ROOM, 1 | 8)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if not hit.is_empty(): least = minf(least, from.distance_to(hit.position))
	return least

static func old_fall_way(yaw: float, side: float) -> Vector3:
	return (Basis(Vector3.UP, yaw + PI) * Vector3(side * 0.62, 0.0, 0.78)).normalized()

## Where everything of the scene was, as executions.gd worked it out from The
## Locust itself.
func old_point(execution: Dictionary) -> Vector3:
	return level.locust.global_position if is_instance_valid(level.locust) else execution.point

func old_forward(execution: Dictionary) -> Vector3:
	return -Basis(Vector3.UP, float(execution.yaw)).z

func old_hold(execution: Dictionary) -> Vector3:
	var time := float(execution.time)
	var far := float(execution.get("far", SCORE.HOLD_FAR.y))
	var reach := lerpf(far, SCORE.HOLD_NEAR, SCORE.closing(time))
	return old_point(execution) + old_forward(execution) * reach + Vector3(0, SCORE.HOLD_STAND * (1.0 - SCORE.fall(time)) + SCORE.lift(time) * SCORE.LIFT_HEIGHT, 0)

func old_lens(execution: Dictionary) -> Vector3:
	var far := float(execution.get("far", SCORE.HOLD_FAR.y))
	var eyes := 0.9 if bool(execution.get("crouched", false)) else 1.64
	return old_point(execution) + old_forward(execution) * far + Vector3(0, SCORE.HOLD_STAND + eyes, 0)

func old_mask_from(execution: Dictionary) -> Vector3:
	if bool(execution.get("crouched", false)): return (Vector3.UP * 0.9 - old_forward(execution) * 0.35).normalized()
	return (-old_forward(execution) + Vector3.UP * 0.2).normalized()

func old_drop(execution: Dictionary) -> Vector3:
	return old_point(execution) + old_forward(execution) * SCORE.HOLD_NEAR

func old_fall_dir(execution: Dictionary) -> Vector3:
	var straight: bool = bool(execution.get("straight", false)) or bool(execution.get("slump", false))
	return old_fall_way(float(execution.yaw), 0.0 if straight else float(execution.get("side", 1.0)))

func old_body_rest(execution: Dictionary) -> Vector3:
	var room := float(execution.get("room", 0.0))
	return old_drop(execution) + old_fall_dir(execution) * (SCORE.seat_back(room) + 0.3 * sin(SCORE.seat_lean(room)))

func old_head_rest(execution: Dictionary) -> Vector3:
	var room := float(execution.get("room", 0.0))
	return old_drop(execution) + old_fall_dir(execution) * (SCORE.seat_back(room) + 0.1 + 0.7 * sin(SCORE.seat_lean(room)))

func old_head_away(execution: Dictionary) -> float:
	var lens = execution.get("lens")
	var side := float(execution.get("side", 1.0))
	if not (lens is Transform3D): return side
	var level_way := Vector3(0.0 if bool(execution.get("straight", false)) or bool(execution.get("slump", false)) else side * 0.62, 0.0, 0.78).normalized()
	var its_right := Basis(Vector3.UP, float(execution.yaw) + PI + atan2(level_way.x, level_way.z)) * Vector3.RIGHT
	var beside := ((lens as Transform3D).origin - old_head_rest(execution)).dot(its_right)
	if absf(beside) < 0.05: return side
	return 1.0 if beside > 0.0 else -1.0

func old_staging(execution: Dictionary) -> Dictionary:
	var far := float(execution.get("far", SCORE.HOLD_FAR.y))
	return {
		"lens": old_lens(execution), "middle": old_point(execution) + old_forward(execution) * far * 0.5, "hold": old_drop(execution), "body": old_body_rest(execution),
		"head": old_head_rest(execution), "creature": old_point(execution),
	}

func old_scene_for(execution: Dictionary) -> Dictionary:
	var time := float(execution.time)
	var hold := old_hold(execution)
	var low := (1.0 - SCORE.lift(time)) if bool(execution.get("crouched", false)) else 0.0
	var lens = execution.get("lens")
	return {
		"time": time, "entry": String(execution.get("entry", "front")), "side": float(execution.get("side", 1.0)),
		"ending": String(execution.get("ending", "leave")), "lens": old_lens(execution), "mask_from": old_mask_from(execution),
		"chest": hold + Vector3.UP * lerpf(1.2, 0.68, low), "face": hold + Vector3.UP * lerpf(1.58, 0.88, low),
		"body": old_body_rest(execution) + Vector3.UP * 0.12, "glance": (lens as Transform3D).origin if lens is Transform3D else Vector3.INF,
	}

func old_torch_rest(execution: Dictionary) -> Transform3D:
	var draw := RandomNumberGenerator.new()
	draw.seed = int(execution.get("seed", 0)) ^ 0x51ed
	var forward := old_forward(execution)
	var right := forward.cross(Vector3.UP)
	var side := float(execution.get("side", 1.0))
	var out := (forward * draw.randf_range(0.5, 0.9) - right * side * draw.randf_range(0.6, 1.0)).normalized()
	var from := old_lens(execution) - Vector3.UP * 0.3
	var spot := old_drop(execution) + out * draw.randf_range(2.1, 2.9)
	var query := PhysicsRayQueryParameters3D.create(from, spot + Vector3.UP * 0.2, 1)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var back := from - (hit.position as Vector3)
		back.y = 0.0
		spot = (hit.position as Vector3) + back.normalized() * 0.25
	spot.y = old_point(execution).y + 0.035
	var aim := old_drop(execution).lerp(old_point(execution), 0.5) + Vector3.UP * 0.9 - spot
	return Transform3D(Basis(Vector3.UP, atan2(-aim.x, -aim.z) + draw.randf_range(-0.22, 0.22)) * Basis(Vector3.RIGHT, deg_to_rad(4.0)), spot)

## blood.snapshot() as it was, reading The Locust itself.
func old_snapshot(execution: Dictionary) -> Dictionary:
	var yaw := float(execution.yaw)
	var forward := -Basis(Vector3.UP, yaw).z
	var point: Vector3 = level.locust.global_position if is_instance_valid(level.locust) else execution.point
	var exclude: Array = level.executions.scene_bodies()
	var straight: bool = bool(execution.get("straight", false)) or bool(execution.get("slump", false))
	return {
		"seed": int(execution.get("seed", 0)), "point": point, "forward": forward, "right": forward.cross(Vector3.UP),
		"far": float(execution.get("far", SCORE.HOLD_FAR.y)), "crouched": bool(execution.get("crouched", false)),
		"side": float(execution.get("side", 1.0)), "exclude": exclude,
		"fall": old_fall_way(yaw, 0.0 if straight else float(execution.get("side", 1.0))),
		"room": float(execution.get("room", SCORE.LIE_ROOM)), "sill": level.executions.seat_floor(),
	}

## The biggest room of the first planta the creature may take somebody in,
## and the long way of it.
func capture_room() -> Dictionary:
	var best := {}
	var area := 0.0
	for room in level.manifest.rooms:
		if int(room.get("wing", 0)) != 0 or FLOOR.is_void(room) or level.point_protected(FLOOR.position_of(room)): continue
		var span: Vector2 = FLOOR.size_of(room)
		if span.x * span.y > area:
			area = span.x * span.y
			best = room
	return best

## The survivor at a spot looking a way, and the creature somewhere, turned to
## them and still, driven by `control`.
func put_pair(it, at: Vector3, looking: Vector3, from: Vector3, control: String) -> void:
	var body = level.player
	body.global_position = at
	body.velocity = Vector3.ZERO
	body.rotation.y = atan2(-looking.x, -looking.z)
	it.control = control
	it.global_position = from
	it.velocity = Vector3.ZERO
	var to_them := at - from
	to_them.y = 0.0
	it.rotation.y = atan2(-to_them.x, -to_them.z) if to_them.length() > 0.01 else 0.4

## At each beat of a capture applied as the host staged it, the places the
## style gives and the ones executions.gd and blood.gd worked out: the keys
## that differ.
func places_differ(execution: Dictionary) -> Array:
	var style = level.executions.style()
	var differ: Array = []
	for time in [0.0, 0.05, 0.3, 0.62, 1.2, 1.9, 2.6, 3.4, 4.2, 4.75]:
		execution.time = time
		var pairs := {
			"hold": [style.victim_hold_point(execution), old_hold(execution)],
			"hold (level)": [level.victim_hold_point(), old_hold(execution)],
			"lens": [style.lens_point(execution), old_lens(execution)],
			"lens (executions)": [level.executions.lens_point(), old_lens(execution)],
			"point": [style.creature_point(execution), old_point(execution)],
			"forward": [style.creature_forward(execution), old_forward(execution)],
			"mask_from": [style.mask_from(execution), old_mask_from(execution)],
			"drop": [style.drop_point(execution), old_drop(execution)],
			"fall_dir": [style.fall_dir(execution), old_fall_dir(execution)],
			"body_rest": [style.body_rest(execution), old_body_rest(execution)],
			"head_rest": [style.head_rest(execution), old_head_rest(execution)],
			"head_away": [style.head_away(execution), old_head_away(execution)],
			"staging": [level.executions.staging(), old_staging(execution)],
			"scene_for": [style.scene_for(execution), old_scene_for(execution)],
			"torch_rest": [style.torch_rest(execution), old_torch_rest(execution)],
			"blood": [level.executions.blood.snapshot(execution), old_snapshot(execution)],
			"mask": [style.mask_transform(), level.locust.visual.mask_transform()],
		}
		for key in pairs:
			if pairs[key][0] != pairs[key][1] or typeof(pairs[key][0]) != typeof(pairs[key][1]): differ.append("%s a %0.2f" % [key, time])
		style.pose(execution)
		if level.locust.visual.scene != old_scene_for(execution): differ.append("pose a %0.2f" % time)
	style.unpose()
	if not level.locust.visual.scene.is_empty(): differ.append("unpose")
	execution.time = 0.0
	return differ

## Captures staged as the host stages them, from several places and ways of
## being caught: from the same place and the same draws, stage_capture()
## through the style gives what it gave before (where the creature ends up,
## which way it faces, how they were caught, how the body goes down, the
## draws), and once applied, every place of the scene is the old one.
func staged_captures(it) -> void:
	var ex = level.executions
	var body = level.player
	var room := capture_room()
	var centre: Vector3 = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	var span: Vector2 = FLOOR.size_of(room)
	var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
	var right_hand: Vector3 = Basis(Vector3.UP, atan2(-along.x, -along.z)).x
	var corner: Vector3 = centre + Vector3((span.x * 0.5 - 0.45), 0, (span.y * 0.5 - 0.45))
	var inward: Vector3 = (centre - corner).normalized()
	var hide = level.hotel.hides[0] if not level.hotel.hides.is_empty() else null
	var cases: Array = [
		{"name": "de frente", "at": centre, "looking": along, "from": centre + along * 1.5},
		{"name": "demasiado cerca", "at": centre, "looking": along, "from": centre + along * 0.35},
		{"name": "por la espalda", "at": centre, "looking": -along, "from": centre + along * 1.4},
		{"name": "de lado", "at": centre, "looking": along, "from": centre + right_hand * 1.2},
		{"name": "agachado y con linterna", "at": centre, "looking": along, "from": centre + along * 0.9, "crouched": true, "torch": true},
		{"name": "en el mismo sitio", "at": centre, "looking": along, "from": centre},
		{"name": "una copia, en versus", "at": centre, "looking": along, "from": centre + along * 1.6, "control": "puppet"},
		{"name": "en un rincón", "at": corner, "looking": inward, "from": corner + inward * 1.3},
		{"name": "forzada", "at": centre, "looking": along, "from": centre + along * 1.2, "forced": {"entry": "back", "side": -1.0, "glance": true, "seed": 1234}},
	]
	if hide != null:
		for pouncing in [false, true]:
			cases.append({"name": "en un armario" + (", tras la finta" if pouncing else ""), "at": hide.to_global(hide.inside_offset), "looking": -hide.global_basis.z, "from": hide.to_global(hide.exit_offset), "hide": hide, "pouncing": pouncing})
	var draws: int = ex.rng.state
	var counted: int = ex.captures
	var glanced: Dictionary = ex.glanced.duplicate()
	var stage_wrong: Array = []
	var place_wrong: Array = []
	var entries := {}
	var falls := {}
	var moved := 0
	var applied := 0
	var staged := 0
	var drawn := {}
	for case in cases:
		var now := {}
		# From several points of its chance, so that the side drawn and the
		# look at the lens come out both ways.
		for round in 6:
			var seeded := RandomNumberGenerator.new()
			seeded.seed = hash([String(case.name), round])
			var start: int = seeded.state
			var setup := func():
				put_pair(it, case.at, case.looking, case.from, String(case.get("control", "ai")))
				body.crouched = bool(case.get("crouched", false))
				body.torch.visible = bool(case.get("torch", false))
				body.hidden = case.has("hide")
				body.hiding_place = case.get("hide")
				it.pouncing = bool(case.get("pouncing", false))
				ex.forced = case.get("forced", {}).duplicate()
				ex.rng.state = start
				ex.captures = counted
				ex.glanced = glanced.duplicate()
			setup.call()
			var old := old_stage(body)
			var old_at: Vector3 = it.global_position
			var old_draws: int = ex.rng.state
			var old_glanced: Dictionary = ex.glanced.duplicate()
			setup.call()
			now = ex.stage_capture(body)
			staged += 1
			if now != old: stage_wrong.append("%s %d: %s" % [case.name, round, str(differences(old, now))])
			if not it.global_position.is_equal_approx(old_at) or it.global_position != old_at: stage_wrong.append("%s %d: dónde queda" % [case.name, round])
			if ex.rng.state != old_draws or ex.glanced != old_glanced or ex.captures != counted + 1: stage_wrong.append("%s %d: azar" % [case.name, round])
			if round == 0 and not (case.from as Vector3).is_equal_approx(old_at): moved += 1
			drawn["lado %d" % int(now.side)] = true
			drawn["mira la lente" if bool(now.glance) else "no la mira"] = true
		entries[String(now.entry)] = true
		falls["recto" if bool(now.straight) else ("doblado" if bool(now.slump) else "de lado")] = true
		if case.has("hide"): continue
		# Played out on every beat: the same places, the old way and the style's.
		level.apply_execution(body.slot, it.global_position, float(now.yaw), now)
		if level.execution.is_empty() or int(level.execution.get("id", -1)) != int(now.id):
			place_wrong.append("%s: no empieza" % case.name)
			continue
		applied += 1
		for wrong in places_differ(level.execution): place_wrong.append("%s: %s" % [case.name, wrong])
		if bool(now.torch) and (level.executions.torch.is_empty() or level.executions.torch.rest != old_torch_rest(level.execution)): place_wrong.append("%s: la linterna" % case.name)
		level.release_execution()
	body.crouched = false
	body.torch.visible = false
	body.hidden = false
	body.hiding_place = null
	body.active = true
	body.held = false
	it.pouncing = false
	ex.forced = {}
	ex.rng.state = draws
	ex.captures = counted
	ex.glanced = glanced
	check("stage_capture() da con su estilo lo que daba, sorteos incluidos (%d sitios, %d veces, %d con la criatura movida; %s; caídas %s; %s)" % [cases.size(), staged, moved, ", ".join(PackedStringArray(entries.keys())), ", ".join(PackedStringArray(falls.keys())), ", ".join(PackedStringArray(drawn.keys()))], stage_wrong.is_empty() and moved >= 3 and entries.size() >= 5 and drawn.size() == 4, str(stage_wrong.slice(0, 4)))
	check("Y en cada momento de la escena, todo está donde estaba: víctima, lente, máscara, suelo, cuerpo, cabeza, linterna, la cinta y la sangre (%d capturas)" % applied, place_wrong.is_empty() and applied >= 7, str(place_wrong.slice(0, 6)))
	# A creature with no capture style catches nobody; with its own, the same
	# survivor is caught.
	put_pair(it, centre, along, centre + along * 1.2, "ai")
	var nobody = CREATURE.new()
	level.creature = nobody
	level.capture_survivor(body)
	var spared: bool = level.execution.is_empty()
	if not spared: level.release_execution()
	level.creature = it
	put_pair(it, centre, along, centre + along * 1.2, "ai")
	level.capture_survivor(body)
	var caught: bool = not level.execution.is_empty() and it.mode == LOCUST.Mode.EXECUTE
	if not level.execution.is_empty(): level.release_execution()
	var let_go: bool = it.mode == LOCUST.Mode.SEARCH
	nobody.free()
	body.active = true
	body.held = false
	ex.rng.state = draws
	ex.captures = counted
	ex.glanced = glanced
	check("Una criatura sin estilo no coge a nadie; la suya coge, y soltada la deja buscando", spared and caught and let_go)

## A creature with nothing of its own: the defaults say so.
func bare() -> void:
	var nobody = CREATURE.new()
	check("Una criatura sin nada propio no es nadie ni puede nada", nobody.kind_id() == &"" and not nobody.can(&"lifts") and nobody.activity() == &"roam" and nobody.is_roaming() and nobody.accepts_leads() and not nobody.is_hostile() and nobody.alarm_level() == 0 and nobody.pack_state().is_empty() and nobody.capture_length() == 0.0 and nobody.capture_style() == null)
	var felt: Array = nobody.presence_route(Vector3.ZERO)
	check("Ni se la siente venir, ni se la oye, ni miente, ni ha registrado nada ni ve a nadie", float(felt[0]) == INF and not bool(nobody.sound_route(Vector3.ZERO).audible) and nobody.hallucinations() == null and not nobody.searched_lately(0) and not nobody.noticing() and not nobody.in_transit())
	nobody.follow_to_planta(2, true)
	nobody.search_from(Vector3.ONE, Vector3.FORWARD)
	check("Ni tiene guarida, ni guarda nada de sí con el piso, ni anda buscando a nadie", nobody.den_point(1) == Vector3.INF and nobody.save_state().is_empty() and not nobody.is_wary() and nobody.activity() == &"roam")
	var steps: Dictionary = nobody.wardrobe_steps()
	check("Ni golpea a nadie, ni va a por nadie, ni se la caza de oído; y abre un armario al paso de siempre", nobody.validate_strike(Vector3.ZERO, Vector3.FORWARD, level.player) == INF and nobody.quarry() == null and not nobody.can(&"echo") and is_equal_approx(nobody.sense_scale(), 1.0) and not nobody.is_chasing() and steps == {"burst": 0.55, "reach": 0.7, "done": 1.7})
	# Where it stands is asked of it in the tree, as the observer asks it.
	nobody.collision_layer = 0
	nobody.collision_mask = 0
	root.add_child(nobody)
	var lines: Array = Array(nobody.debug_lines())
	check("Y el observador la nombra por su clase, con su mando, lo que hace y dónde", lines.size() == 2 and String(lines[0]) == " (ai)" and String(lines[1]).begins_with("  roam, gracia") and nobody.debug_state().modo == "roam" and nobody.debug_state().mando == "ai")
	var defaults: bool = nobody.control == "ai" and is_equal_approx(nobody.grace, 15.0) and is_equal_approx(nobody.dull, 1.0)
	nobody.set_control("puppet")
	check("Con su mando, su gracia y su oído enteros, y el mando es el que se le da", defaults and nobody.control == "puppet")
	nobody.free()

# --- The net, the observer and the bots, on the contract ----------------------------

## Every `it.` and `creature.` of the net, the observer, the ledger, the
## wardrobe got into, the settings and the bots (but The Locust's own threat
## model) against the contract, by name too; no mode of The Locust, nothing
## of LOCUST and never level.locust; nothing of its folder but what each is
## let keep (KEPT). And match_net asks it what it says: what it packs and
## pushes, its calls, whether it is engaged, its verdict on a strike, what its
## hunter is shown and how it is left to the machine.
func moved_readers() -> void:
	var names := contract_names()
	var reads := RegEx.create_from_string("\\b(?:it|creature)\\.([A-Za-z_][A-Za-z0-9_]*)")
	var by_name := RegEx.create_from_string("\\b(?:it|creature)\\.(?:get|set)\\(\"([A-Za-z_][A-Za-z0-9_]*)\"|\"([A-Za-z_][A-Za-z0-9_]*)\" in (?:it|creature)\\b")
	var locust_ways := RegEx.create_from_string("\\b(?:it|creature)\\.(?:mode|Mode)\\b|\\bLOCUST\\b|\\blevel\\.locust\\b")
	var bots: Array = []
	for file in DirAccess.get_files_at(BOTS):
		var path := BOTS.path_join(file)
		if file.ends_with(".gd") and path != THREAT_MODEL: bots.append(path)
	var bot_foreign := {}
	var bot_modes: Array = []
	var bot_own: Array = []
	for path in MOVED + bots:
		var code := code_of(path)
		var file: String = path.get_file()
		var foreign := {}
		for hit in reads.search_all(code):
			if not names.has(hit.get_string(1)): foreign[hit.get_string(1)] = true
		for hit in by_name.search_all(code):
			var member: String = hit.get_string(1) if not hit.get_string(1).is_empty() else hit.get_string(2)
			if not names.has(member): foreign[member] = true
		var found := locust_ways.search(code)
		var own: String = code.replace(String(KEPT[file]), "") if KEPT.has(file) else code
		var keeps: bool = own.contains("enemies/locust") or own.contains("hotel_locust")
		if path in bots:
			for member in foreign: bot_foreign["%s: %s" % [file, member]] = true
			if found != null: bot_modes.append("%s: %s" % [file, found.get_string()])
			if keeps: bot_own.append(file)
			continue
		check("%s le pregunta a la criatura solo lo del contrato" % file, foreign.is_empty(), "lee %s" % str(foreign.keys()))
		check("%s no compara modos de The Locust ni la lee por level.locust" % file, found == null, "encuentra %s" % (found.get_string() if found != null else ""))
		check("%s no guarda nada propio de The Locust%s" % [file, (", salvo %s" % String(KEPT[file]).get_file()) if KEPT.has(file) else ""], not keeps)
	check("Los bots (%d archivos, sin su modelo de The Locust) le preguntan solo lo del contrato" % bots.size(), bot_foreign.is_empty() and bots.size() >= 10, str(bot_foreign.keys()))
	check("Ni comparan sus modos, ni la nombran, ni la leen por level.locust", bot_modes.is_empty(), str(bot_modes))
	check("Ni guardan nada suyo, salvo door_threading en bot_nav.gd", bot_own.is_empty(), str(bot_own))
	var net := code_of(NET)
	var asked: Array = ["creature.pack_state()", "creature.push_state(", "creature.play_call(", "level.creature.is_engaged()", "creature.validate_strike(", "creature.hunter_reveal(", "level.creature.hunter_contact(", "level.creature.resume_state(", "creature.hunter_gone()", "creature.sense_scale()", "creature.saw_enter(", "level.creature.wardrobe_steps()"]
	var missing: Array = asked.filter(func(said): return not net.contains(said))
	check("match_net.gd sí le pregunta: lo que manda y recibe, sus llamadas, si está ocupada, su veredicto de un golpe y lo que se enseña a su cazador", missing.is_empty(), "no pregunta %s" % str(missing))

## pack_state() as it was: where, which way, how fast, its mode, its grace and
## where its head is turned.
func old_pack(it) -> Array:
	return [it.global_position, it.rotation.y, it.velocity, it.mode, it.grace, it.visual.look_point if is_instance_valid(it.visual) and "look_point" in it.visual else Vector3.INF]

## push_state() as it was, on a copy.
func old_push(copy, data: Array) -> void:
	if data.size() < 6: return
	if copy.ride_hold > 0.0:
		if (data[0] as Vector3).distance_to(copy.ride_point) > 3.0: return
		copy.ride_hold = 0.0
	copy.net_states.append({"time": copy.net_clock, "position": data[0], "yaw": data[1], "velocity": data[2]})
	while copy.net_states.size() > 10: copy.net_states.pop_front()
	var next: int = data[3]
	if next != copy.mode:
		copy.mode = next
		copy.state_time = 0.0
	copy.grace = data[4]
	copy.net_look = data[5]

## A copy as it stands before a state arrives: just carried by a lift (and
## the state from far from the car, or from beside it) or not.
static func ready_copy(copy, sent: Array, case: int) -> void:
	copy.net_states.clear()
	for i in case % 12: copy.net_states.append({"time": 0.1 * i, "position": Vector3.ONE * i, "yaw": 0.0, "velocity": Vector3.ZERO})
	copy.net_clock = 0.7
	copy.ride_hold = 1.0 if case % 2 == 1 else 0.0
	copy.ride_point = (sent[0] as Vector3) + (Vector3(5, 0, 0) if case % 3 == 0 else Vector3(1, 0, 0))
	copy.mode = LOCUST.Mode.PATROL
	copy.state_time = 2.0
	copy.grace = 9.0
	copy.net_look = Vector3.ONE

## What a copy holds of what it is sent.
static func received(copy) -> Dictionary:
	return {"net_states": copy.net_states.duplicate(true), "mode": copy.mode, "state_time": copy.state_time, "grace": copy.grace, "net_look": copy.net_look, "ride_hold": copy.ride_hold}

## match_net.restore() for its hunter coming back, as it was.
func old_resume(it, data: Array) -> void:
	it.global_position = data[0]
	it.rotation.y = data[1]
	if data.size() > 4: it.grace = float(data[4])

## What crosses the wire is what crossed it: match_net's RPCs are the ones
## they were, with their arguments; what the machine in charge sends is the
## same bytes in every mode, and a copy given it does with it what it did; a
## hunter coming back is put where it was as by hand.
func wire(it) -> void:
	var script: Script = level.match_net.get_script()
	var config: Variant = script.get_rpc_config()
	var rpcs := {}
	if config is Dictionary:
		for key in config: rpcs[String(key)] = true
	var args := {}
	for method in script.get_script_method_list(): args[String(method.name)] = (method.args as Array).size()
	var wrong: Array = []
	for name in RPCS:
		if not rpcs.has(name) or int(args.get(name, -1)) != int(RPCS[name]): wrong.append(name)
	check("Las RPC de la red son las de antes, con sus argumentos (%d)" % RPCS.size(), wrong.is_empty() and rpcs.size() == RPCS.size(), "difieren %s; hay %d" % [str(wrong), rpcs.size()])
	var copy = await puppet()
	var twin = await puppet()
	var at := room_point()
	var draws: int = it.rng.state
	var look: Vector3 = it.visual.look_point
	var bytes_wrong: Array = []
	var pushed_wrong: Array = []
	var resumed_wrong: Array = []
	var cases := 0
	for mode in LOCUST.Mode.values():
		for turned in [false, true]:
			pose(it, "ai", mode, at, draws)
			it.rotation.y = 0.2 + 0.3 * mode
			it.velocity = Vector3(0.5 * mode, 0.0, -1.5)
			it.grace = 0.75 * mode
			it.visual.look_point = it.global_position + Vector3(1.0, 1.5, 0.2 * mode) if turned else Vector3.INF
			var sent: Array = it.pack_state()
			var bytes: PackedByteArray = var_to_bytes(sent)
			var label := "%s%s" % [LOCUST.Mode.keys()[mode], ", mirando" if turned else ""]
			if bytes != var_to_bytes(old_pack(it)) or sent.size() != 6: bytes_wrong.append(label)
			# As it arrives, on two copies alike, one of them the old way.
			var arrived: Array = bytes_to_var(bytes)
			ready_copy(copy, arrived, cases)
			ready_copy(twin, arrived, cases)
			copy.push_state(arrived)
			old_push(twin, arrived)
			if received(copy) != received(twin): pushed_wrong.append(label)
			# Its hunter back: from where it stood, in full and without grace.
			for data in [arrived, arrived.slice(0, 4)]:
				pose(it, "player", LOCUST.Mode.PATROL, at, draws)
				old_resume(it, data)
				var before := state_of(it)
				pose(it, "player", LOCUST.Mode.PATROL, at, draws)
				it.resume_state(data)
				for key in differences(before, state_of(it)): resumed_wrong.append("%s: %s" % [label, key])
			cases += 1
	it.visual.look_point = look
	it.velocity = Vector3.ZERO
	it.control = "ai"
	it.rng.state = draws
	copy.queue_free()
	twin.queue_free()
	await process_frame
	check("Lo que manda es lo de antes, byte a byte, en cada modo (%d casos)" % cases, bytes_wrong.is_empty() and cases == LOCUST.Mode.size() * 2, str(bytes_wrong.slice(0, 6)))
	check("Y una copia lo recibe como antes, recién bajada de un ascensor o no", pushed_wrong.is_empty(), str(pushed_wrong.slice(0, 6)))
	check("Su cazador de vuelta la retoma donde estaba y con su gracia, como a mano", resumed_wrong.is_empty(), str(resumed_wrong.slice(0, 6)))

## resolve_strike() as it was, reading The Locust itself: whom a strike took.
## `why` counts what spared each one it did not take.
func old_strike(it, origin: Vector3, facing: Vector3, why: Dictionary) -> Node3D:
	if origin.distance_to(it.global_position) > 3.0: origin = it.global_position
	facing.y = 0.0
	var best: Node3D = null
	var best_distance: float = LOCUST.STRIKE_REACH
	for body in level.survivors():
		if not level.survivor_active(body): continue
		var offset: Vector3 = body.global_position - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance >= best_distance:
			why["lejos"] = int(why.get("lejos", 0)) + 1
			continue
		if distance > 0.8 and facing.length() > 0.1 and rad_to_deg(facing.angle_to(offset)) > 70.0:
			why["de lado"] = int(why.get("de lado", 0)) + 1
			continue
		if body.hidden and not (is_instance_valid(body.hiding_place) and body.hiding_place.ajar()):
			why["escondido"] = int(why.get("escondido", 0)) + 1
			continue
		var ray := PhysicsRayQueryParameters3D.create(origin + Vector3(0, LOCUST.EYE_HEIGHT, 0), body.camera.global_position, 1 | 8 | 64)
		ray.exclude = [it.get_rid()]
		if not it.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			why["tapado"] = int(why.get("tapado", 0)) + 1
			continue
		best = body
		best_distance = distance
	return best

## Strikes its hunter claims, judged on the host: from the middle of a room
## and from a corner (the walls between), with the claimed spot its own, a
## step off or too far off to be taken, facing ahead, up, behind or nowhere,
## at every reach and side; at a wardrobe shut and ajar; and with a second
## survivor, nearer and further. match_net takes, through validate_strike(),
## whom the old judgement took, and the metres it gives are the old ones.
func strikes(it) -> void:
	var body = level.player
	var room := capture_room()
	var centre: Vector3 = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	var span: Vector2 = FLOOR.size_of(room)
	var corner: Vector3 = centre + Vector3(span.x * 0.5 - 0.6, 0, span.y * 0.5 - 0.6)
	var kept_body: Transform3D = body.global_transform
	var kept_it: Transform3D = it.global_transform
	var grace: float = it.grace
	it.grace = 0.0
	var why := {}
	var differ: Array = []
	var cases := 0
	var taken := 0
	for from in [centre, corner]:
		for yaw in [0.0, 2.2]:
			it.global_position = from
			it.rotation.y = yaw
			var ahead: Vector3 = -it.global_basis.z
			for claim in [Vector3.ZERO, Vector3(1.0, 0.0, 0.5), Vector3(5.0, 0.0, 0.0)]:
				for facing in [ahead, ahead + Vector3(0, 0.8, 0), -ahead, Vector3.ZERO, ahead * 0.05]:
					for metres in [0.5, 1.5, 2.6, 3.15, 3.3]:
						for turn in [0.0, 45.0, 69.0, 72.0, 120.0, 180.0]:
							body.global_position = from + ahead.rotated(Vector3.UP, deg_to_rad(turn)) * metres
							var origin: Vector3 = from + claim
							var old: Node3D = old_strike(it, origin, facing, why)
							var now: Node3D = level.match_net.strike_victim(origin, facing)
							var metres_now: float = it.validate_strike(origin, facing, body)
							var flat: Vector3 = body.global_position - (origin if origin.distance_to(from) <= 3.0 else from)
							flat.y = 0.0
							var active: bool = level.survivor_active(body)
							cases += 1
							if now == body: taken += 1
							if old != now or (active and (now == body) != (metres_now < INF)) or (now == body and not is_equal_approx(metres_now, flat.length())): differ.append("%s %0.1f %s %s %0.2f %0.0f" % ["rincón" if from == corner else "centro", yaw, claim, facing, metres, turn])
	# In a wardrobe, its doors shut and ajar.
	var hide = level.hotel.hides[0] if not level.hotel.hides.is_empty() else null
	var hidden_cases := 0
	if hide != null:
		var inside: Vector3 = hide.to_global(hide.inside_offset)
		var front: Vector3 = hide.to_global(hide.exit_offset)
		var towards: Vector3 = inside - front
		towards.y = 0.0
		for ajar in [false, true]:
			hide.set_ease(1.0 if ajar else 0.0, body)
			for back in [0.0, 0.8]:
				it.global_position = front - towards.normalized() * back
				it.rotation.y = atan2(-towards.x, -towards.z)
				body.global_position = inside
				body.hidden = true
				body.hiding_place = hide
				for facing in [towards, -towards]:
					var old: Node3D = old_strike(it, it.global_position, facing, why)
					var now: Node3D = level.match_net.strike_victim(it.global_position, facing)
					hidden_cases += 1
					if now == body: taken += 1
					if old != now: differ.append("armario %s %0.1f %s" % [ajar, back, facing])
		hide.set_ease(0.0, body)
		body.hidden = false
		body.hiding_place = null
	# Two survivors: whichever is nearer, the first of two as near, nobody
	# reached but one.
	var other = REMOTE.new()
	other.setup(level, 4, "Otro", 1)
	level.add_child(other)
	level.match_net.bodies[4] = other
	level.session.participants[4] = level.session.Life.EXPLORING
	await process_frame
	var pairs := 0
	var others := 0
	it.global_position = centre
	it.rotation.y = 0.0
	var ahead: Vector3 = -it.global_basis.z
	for one in [0.6, 1.4, 2.2, 3.0, 3.5]:
		for two in [0.6, 1.4, 2.2, 3.0, 3.5]:
			for side in [0.0, 40.0, 100.0]:
				body.global_position = centre + ahead * one
				other.global_position = centre + ahead.rotated(Vector3.UP, deg_to_rad(side)) * two
				var old: Node3D = old_strike(it, centre, ahead, why)
				var now: Node3D = level.match_net.strike_victim(centre, ahead)
				pairs += 1
				if now == other: others += 1
				if old != now: differ.append("dos %0.1f %0.1f %0.0f" % [one, two, side])
	level.match_net.bodies.erase(4)
	level.session.participants.erase(4)
	other.queue_free()
	await process_frame
	body.global_transform = kept_body
	it.global_transform = kept_it
	it.grace = grace
	check("Un golpe del cazador se lleva a quien se llevaba (%d golpes, %d en un armario, %d con dos; %d alcanzados, %d el otro; %s)" % [cases, hidden_cases, pairs, taken, others, str(why)], differ.is_empty() and taken > 0 and others > 0 and why.size() == 4 and hidden_cases == 8, str(differ.slice(0, 6)))

## seat_dropped()'s own hand on the creature, as it was.
func old_hunter_gone(it) -> void:
	it.patrol_room = it.nearest_room()
	if it.mode not in [LOCUST.Mode.EXECUTE, LOCUST.Mode.WARDROBE]: it.set_mode(LOCUST.Mode.SEARCH)

## What its hunter is shown goes to its hunter's side as it went; with its
## hunter gone, the machine takes it up as seat_dropped() did by hand; the
## room's onslaught stretches its cry; who it is after; seen getting into a
## wardrobe, it is sure of it, and of a bot getting in only as sure as it was.
func hunter(it) -> void:
	var source := GDScript.new()
	source.source_code = "extends Node\nvar channel_open := true\nvar echo: Node\nvar revealed: Array = []\nvar heard: Array = []\nfunc reveal(points): revealed.append(points)\nfunc hear_contact(point, apparent, distance, strength, kind, muffle): heard.append([point, apparent, distance, strength, kind, muffle])\n"
	source.reload()
	var reading := GDScript.new()
	reading.source_code = "extends Node\nvar applied := 0\nfunc apply_quality(): applied += 1\n"
	reading.reload()
	var driver := Node.new()
	driver.set_script(source)
	var echo := Node.new()
	echo.set_script(reading)
	driver.add_child(echo)
	driver.set("echo", echo)
	it.add_child(driver)
	it.driver = driver
	var points := PackedVector3Array([Vector3(1, 2, 3), Vector3(4, 5, 6)])
	it.hunter_reveal(points)
	it.hunter_contact(Vector3.ONE, Vector3(2, 0, 2), 7.5, 0.6, 3, 0.4)
	it.apply_quality()
	var shown: bool = driver.get("revealed") == [points] and driver.get("heard") == [[Vector3.ONE, Vector3(2, 0, 2), 7.5, 0.6, 3, 0.4]] and int(echo.get("applied")) == 1
	it.driver = null
	it.hunter_reveal(points)
	it.hunter_contact(Vector3.ONE, Vector3.ONE, 1.0, 1.0, 0, 1.0)
	it.apply_quality()
	driver.queue_free()
	check("A su cazador le llega lo que encontró su chillido, lo que oye y la calidad de su lectura; sin cazador, nada", shown)
	# The rounds it had are another room's: where the hunter last took it.
	var before_rounds := int(FLOOR.room_at(level.manifest.rooms, room_point()).get("id", -1))
	var at := room_point(before_rounds)
	var here := int(FLOOR.room_at(level.manifest.rooms, at).get("id", -1))
	var draws: int = it.rng.state
	var differ: Array = []
	var moved := 0
	for mode in LOCUST.Mode.values():
		pose(it, "puppet", mode, at, draws)
		it.patrol_room = before_rounds
		it.set_control("ai")
		old_hunter_gone(it)
		var before := state_of(it)
		pose(it, "puppet", mode, at, draws)
		it.patrol_room = before_rounds
		it.set_control("ai")
		it.hunter_gone()
		if it.patrol_room == here: moved += 1
		for key in differences(before, state_of(it)): differ.append("%s: %s" % [LOCUST.Mode.keys()[mode], key])
	check("Sin su cazador, la máquina la retoma como lo hacía la red a mano, modo a modo", differ.is_empty() and moved == LOCUST.Mode.size() and here != before_rounds, str(differ.slice(0, 6)))
	it.control = "ai"
	it.rng.state = draws
	var scale: float = it.reach_scale
	it.reach_scale = LOCUST.ONSLAUGHT_REACH
	var stretched: bool = is_equal_approx(it.sense_scale(), LOCUST.ONSLAUGHT_REACH)
	it.reach_scale = 1.0
	check("Su chillido llega tan lejos como la embestida estira sus sentidos", stretched and is_equal_approx(it.sense_scale(), 1.0))
	it.reach_scale = scale
	var focus = it.focus
	it.focus = level.player
	var after: bool = it.quarry() == level.player
	it.focus = null
	check("quarry() es a quien tiene en mente (focus)", after and it.quarry() == null)
	it.focus = focus
	var hides: Array = level.hotel.hides
	var sure := false
	var unsure := false
	if hides.size() >= 2:
		it.observed_hide = null
		it.saw_enter(hides[0], false)
		unsure = it.observed_hide == hides[0] and not it.certain
		it.saw_enter(hides[1])
		sure = it.observed_hide == hides[1] and it.certain
		it.saw_enter(hides[0], false)
		unsure = unsure and it.observed_hide == hides[0] and it.certain
		it.observed_hide = null
	check("Vista entrar a un jugador en un armario, está segura; a un bot, solo sabe cuál y no está más segura que antes", sure and unsure and not it.certain)

## The observer's lines on it as observer_view.report() wrote them.
func old_lines(it) -> Array:
	var lines: Array = []
	var session = level.session
	lines.append("THE LOCUST (%s)" % it.control)
	lines.append("  %s, vista %0.0f m, oído ×%0.2f, aviso %0.1f s, caza %0.1f m/s, sin ver %0.1f s, se rinde %0.0f–%0.0f s" % [level.DIFFICULTY.title(level.difficulty).to_upper(), it.sight_range * it.reach_scale, it.hearing * it.reach_scale, it.alert_time, it.chase_speed, it.lose_after, it.give_up, it.give_up_hard])
	lines.append("  %s, gracia %0.1f, velocidad %0.1f, detección %0.2f" % [OLD_WORDS[it.mode], it.grace, it.speed, it.detection])
	lines.append("  ala %d, %0.0f, %0.0f, sin ver %0.1f s" % [int(FLOOR.room_at(level.manifest.rooms, it.global_position).get("wing", -1)), it.global_position.x, it.global_position.z, it.lost_time])
	lines.append("  destino a %0.1f m, camino %d puntos, repath %0.2f, %d puertas en la ruta" % [it.global_position.distance_to(it.destination), it.path.size(), it.repath, it.crossings.size()])
	var counts: Array = it.stuck_counts
	lines.append("  atascos, paso %d ahora, %d/%d/%d/%d/%d (pasos 1 a 5)" % [it.stuck_level, counts[1], counts[2], counts[3], counts[4], counts[5]])
	var nearest := -1
	var gap := INF
	for index in level.hotel.lifts.size():
		var to_car: float = it.global_position.distance_to(level.hotel.lifts[index])
		if to_car < gap:
			gap = to_car
			nearest = index
	if nearest >= 0: lines.append("  ascensor más cerca: %d a %0.1f m%s" % [nearest, gap, " (arriba)" if level.lifts.lift_gone(nearest) else ""])
	lines.append("  el coche que le toca: %s" % ("ninguno, ya está en el ala en juego" if level.lifts.creature_car(session.stage) < 0 else str(level.lifts.creature_car(session.stage))))
	if is_instance_valid(it.focus): lines.append("  va a por %s" % it.focus.name)
	if it.leaving: lines.append("  se va: dejó una zona sin encontrar nada")
	if it.mode == LOCUST.Mode.SEARCH: lines.append("  busca, %d sitios por mirar, %0.1f s sin pistas" % [it.search_plan.size(), it.clue_idle])
	return lines

## The observer's dump (F5) of it as observer_view.snapshot() wrote it.
func old_dump(it) -> Dictionary:
	return {"modo": OLD_WORDS[it.mode], "mando": it.control, "donde": [it.global_position.x, it.global_position.y, it.global_position.z], "ala": int(FLOOR.room_at(level.manifest.rooms, it.global_position).get("wing", -1)), "destino": [it.destination.x, it.destination.z], "camino": it.path.size(), "atascos": it.stuck_counts, "paso": it.stuck_level}

## observer_gizmos' draw_creature() and draw_sight() as they drew it, past
## their guards.
func old_marks(g, it) -> void:
	for i in range(1, g.lift_route.size()): g.line(g.lift_route[i - 1] + Vector3(0, 0.2, 0), g.lift_route[i] + Vector3(0, 0.2, 0), g.COLOURS.lift_route)
	var before: Vector3 = it.global_position + Vector3(0, 0.1, 0)
	for point in it.path:
		g.line(before, point + Vector3(0, 0.1, 0), g.COLOURS.path)
		before = point + Vector3(0, 0.1, 0)
	g.mark(it.destination, g.COLOURS.path, 0.7)
	g.mark(it.last_known, g.COLOURS.aim, 0.4)
	if it.lead_active() and g.here(it.lead.point): g.ring(it.lead.point, float(it.lead.radius), g.COLOURS.lead, 32)
	if it.search_origin != Vector3.INF and g.here(it.search_origin): g.ring(it.search_origin, it.AREA_SAME, g.COLOURS.search, 28)
	if level.session.state != level.session.State.PLAYING or level.replaying: return
	var eye: Vector3 = it.global_position + Vector3(0, it.EYE_HEIGHT, 0)
	var half := deg_to_rad(it.sight_half_angle)
	var reach: float = minf(it.SIGHT_RANGE, 22.0)
	for side in [-half, half]:
		g.line(eye, eye + (-it.global_basis.z).rotated(Vector3.UP, side) * reach, Color(g.COLOURS.sight, 0.5))
	var seen = it.seen_survivor() if it.has_method("seen_survivor") else null
	if is_instance_valid(seen): g.line(eye, seen.global_position + Vector3(0, 1.5, 0), g.COLOURS.aim)

## The lines a gizmo mesh holds once `drawing` has drawn on it.
static func drawn(g, drawing: Callable) -> Array:
	g.mesh.clear_surfaces()
	g.mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	drawing.call()
	g.mesh.surface_end()
	var arrays: Array = g.mesh.surface_get_arrays(0) if g.mesh.get_surface_count() > 0 else []
	g.mesh.clear_surfaces()
	return [arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_COLOR]] if not arrays.is_empty() else []

## The observer's panel lines, its dump and its marks are the ones it wrote
## and drew itself: in every mode, after somebody and not, walking off,
## searching with a plan, stuck and led by the director, seen and unseen.
func observed(it) -> void:
	var g = GIZMOS.new()
	g.setup(level)
	level.add_child(g)
	g.set_process(false)
	g.lift_route = PackedVector3Array([it.global_position, it.global_position + Vector3(3, 0, 0), it.global_position + Vector3(3, 0, 4)])
	var at := room_point()
	var draws: int = it.rng.state
	var counts: Array = it.stuck_counts.duplicate()
	var body = level.player
	var kept_body: Transform3D = body.global_transform
	var lines_wrong: Array = []
	var dump_wrong: Array = []
	var marks_wrong: Array = []
	var cases := 0
	var marked := 0
	for mode in LOCUST.Mode.values():
		for busy in [false, true]:
			pose(it, "ai" if not busy else "player", mode, at, draws)
			it.grace = 0.0
			it.rotation.y = 0.4
			if busy:
				it.focus = body
				it.leaving = true
				it.search_plan = [{"point": at + Vector3(2, 0, 0)}, {"point": at + Vector3(0, 0, 2)}]
				it.stuck_counts = [0, 3, 2, 1, 1, 0]
				it.stuck_level = 2
				it.path = PackedVector3Array([at + Vector3(1, 0, 0), at + Vector3(2, 0, 1), at + Vector3(4, 0, 1)])
				it.search_origin = at + Vector3(0, 0, 1)
				it.lead = {"point": at + Vector3(1, 0, 1), "radius": 6.0, "until": it.clock + 10.0}
				# In its sight, ahead of it.
				body.global_position = at - Basis(Vector3.UP, 0.4).z * 4.0
			else:
				it.leaving = false
				it.stuck_counts = [0, 0, 0, 0, 0, 0]
				it.stuck_level = 0
				body.global_transform = kept_body
			var label := "%s%s" % [LOCUST.Mode.keys()[mode], ", ocupada" if busy else ""]
			if Array(it.debug_lines()) != old_lines(it): lines_wrong.append(label)
			var dump: Dictionary = it.debug_state()
			if dump != old_dump(it) or JSON.stringify(dump) != JSON.stringify(old_dump(it)): dump_wrong.append(label)
			g.lift_route_clock = 1000.0
			var before: Array = drawn(g, func(): old_marks(g, it))
			g.lift_route_clock = 1000.0
			var now: Array = drawn(g, func():
				g.draw_creature()
				g.draw_sight())
			cases += 1
			if before.is_empty() or now != before: marks_wrong.append(label)
			elif (before[0] as PackedVector3Array).size() > marked: marked = (before[0] as PackedVector3Array).size()
	pose(it, "ai", LOCUST.Mode.PATROL, at, draws)
	it.stuck_counts = counts
	it.stuck_level = 0
	it.path = PackedVector3Array()
	it.search_origin = Vector3.INF
	it.lead = {}
	it.rng.state = draws
	body.global_transform = kept_body
	g.queue_free()
	check("Las líneas del panel del observador son las que escribía, modo a modo (%d casos)" % cases, lines_wrong.is_empty() and cases == LOCUST.Mode.size() * 2, str(lines_wrong.slice(0, 6)))
	check("Lo que vigila su registro y guarda su volcado, lo de antes", dump_wrong.is_empty(), str(dump_wrong.slice(0, 6)))
	check("Y sus marcas sobre el piso, las que dibujaba, trazo a trazo (hasta %d vértices)" % marked, marks_wrong.is_empty() and marked > 100, str(marks_wrong.slice(0, 6)))

## The bots' threat model is the one of its kind: The Locust's for The Locust
## (and for no creature, which it then does not mind), none for a creature
## they have no model of. And what a recording keeps of it is what the
## recorder kept itself.
func threat_models(it) -> void:
	var made = THREATS.make(level)
	var kept = level.creature
	level.creature = null
	var none = THREATS.make(level)
	var nobody = CREATURE.new()
	level.creature = nobody
	var unknown = THREATS.make(level)
	level.creature = kept
	nobody.free()
	check("Los bots la miran con el modelo de su clase: el de The Locust para ella y sin criatura, ninguno para una que no conocen", made != null and made.get_script().resource_path == THREAT_MODEL and none != null and none.get_script().resource_path == THREAT_MODEL and unknown == null)
	var at := room_point()
	var draws: int = it.rng.state
	pose(it, "ai", LOCUST.Mode.SEARCH, at, draws)
	it.focus = level.player
	it.detection = 0.37
	it.path = PackedVector3Array([at + Vector3(1, 0, 0), at + Vector3(2, 0, 1)])
	var c: Vector3 = it.global_position
	var row := [c.x, c.y, c.z, it.rotation.y, int(it.mode), int(level.player.slot), float(it.detection), int(it.stuck_level), it.destination.x, it.destination.z, it.last_known.x, it.last_known.z]
	var route := PackedVector3Array()
	for i in range(int(it.path_index), mini(it.path.size(), int(it.path_index) + 16)): route.append(it.path[i])
	var watch := {"mode": int(it.mode), "focus": int(level.player.slot)}
	var change := {"where": [snappedf(c.x, 0.01), snappedf(c.y, 0.01), snappedf(c.z, 0.01)], "detection": snappedf(0.37, 0.01)}
	var kept_row: bool = made.recorded_row() == row and made.recorded_route() == route and made.recorded_watch() == watch and made.recorded_mode_change() == change
	# Refreshed as it is refreshed in a match: with the creature moving.
	it.set_physics_process(true)
	made.refresh()
	it.set_physics_process(false)
	var words: bool = made.activity == it.activity() and made.leaving() == bool(it.leaving) and is_equal_approx(made.chase_earshot(), LOCUST.CHASE_EARSHOT)
	pose(it, "ai", LOCUST.Mode.PATROL, at, draws)
	it.path = PackedVector3Array()
	it.rng.state = draws
	check("Lo que la grabación guarda de ella lo dice su modelo, como lo guardaba la grabadora", kept_row)
	check("Y lo que hace, si se va y hasta dónde oye en una persecución", words)
