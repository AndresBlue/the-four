extends SceneTree
## The objectives as handlers (game/floors/objectives/, docs/OFICINAS.md 11.2,
## step 0b): host_gate(), the lifts' lines, the director's goals and the
## sets' settling ask the floor's handlers and name no objective of their own;
## and on the hotel, stage by stage, what the handlers give is what the code
## they replaced computed (copied here as it was): the goal with its keys in
## the same order and the door told as often, the pause screen's lines, the
## director's points and rooms, the sets kept of the manifest, and what a
## floor kept holds of each.
const CONTRACT := preload("res://tests/hotel/creature_contract_test.gd")
const TV := preload("res://game/world/generation/tv_placement.gd")
const DIG := preload("res://game/world/generation/digit_placement.gd")
const SAVE := preload("res://game/app/floor_save.gd")
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	var session = level.session
	level.locust.set_physics_process(false)
	texts()
	check("Se juega el piso", session.state == session.State.PLAYING, str(session.state))
	check("El piso tiene un manejador por objetivo, en el orden del hotel", level.objectives.keys() == ["televisions", "code"], str(level.objectives.keys()))
	check("Cada objetivo de las etapas tiene su manejador", level.kind.STAGES.all(func(stage): return stage.objectives.all(func(objective): return level.kind.OBJECTIVES.has(objective))))
	settling()
	for stage in [1, 2, 3]: compare(stage, "al empezar")
	# The sector 2's sets, all but one and then all of them: the blackout,
	# and the door.
	var second: Array = level.stage_televisions(2)
	var needed: int = TV.needed(session.roster_count)
	for step in needed - 1: level.apply_television(int(second[step]), true, true)
	compare(2, "a falta de una tele")
	check("A falta de una tele se va la luz, y la meta guarda su orden", session.goal.has("blackout") and session.goal.keys() == ["kind", "done", "needed", "ready", "sets_done", "sets_needed", "blackout"], str(session.goal.keys()))
	level.apply_television(int(second[needed - 1]), true, true)
	compare(2, "con las que pide")
	# The last sector: a number found.
	for index in level.containers.size():
		if int(level.containers[index].digit) >= 0:
			level.apply_search(index, true, true)
			break
	compare(3, "con un número encontrado")
	# The code in with the wing's sets dark: the door waits for both.
	level.code.code_entered = true
	compare(3, "con el código y sin las teles")
	check("Con el código y las teles apagadas la meta es el código, sin cumplir", session.goal.kind == "code" and not session.goal.ready, str(session.goal))
	# No furniture and the sets lit: the stage is the sets', and met.
	for index in level.stage_televisions(3): level.apply_television(int(index), true, true)
	var kept: Array = level.code.containers
	level.code.containers = []
	compare(3, "sin muebles y con las teles")
	check("Sin muebles la meta es la de las teles, y se cumple", session.goal.kind == "televisions" and session.goal.ready, str(session.goal))
	level.code.containers = kept
	compare(3, "con las teles y el código puesto")
	check("Con las teles y el código se cumple la meta del código", session.goal.kind == "code" and session.goal.ready, str(session.goal))
	saving()
	var file := FileAccess.open("res://evidence/objectives_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	print("OBJECTIVES_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

## The body of a function as written, comments out.
static func body_of(path: String, function: String) -> String:
	var lines: PackedStringArray = CONTRACT.code_of(path).split("\n")
	var kept: PackedStringArray = []
	var inside := false
	for line in lines:
		if line.begins_with("func %s(" % function) or line.begins_with("static func %s(" % function): inside = true
		elif inside and not line.strip_edges().is_empty() and not line.begins_with("\t"): break
		if inside: kept.append(line)
	return "\n".join(kept)

## Nobody that used to name an objective names one.
func texts() -> void:
	var gate := body_of("res://game/app/hotel_main.gd", "host_gate")
	check("host_gate() recorre los objetivos de la etapa", gate.contains("stage_objectives()") and gate.contains(".progress("))
	check("host_gate() da el tick a todos los objetivos del piso", gate.contains("for objective_name in objectives:") and gate.contains(".tick(delta)"))
	for word in ["\"televisions\"", "\"code\"", "TV_PLACEMENT", "DIGITS", "containers", "televisions_on", "creature_channel_hop"]:
		check("host_gate() no nombra %s" % word, not gate.contains(word))
	var lines := body_of("res://game/app/lifts.gd", "stage_progress")
	check("lifts.stage_progress() junta las líneas de los objetivos", lines.contains("stage_objectives()") and not lines.contains("\"televisions\"") and not lines.contains("\"code\""))
	for function in ["goal_rooms", "ambush"]:
		var body := body_of("res://game/director/pacing_director.gd", function)
		check("El director, en %s(), pregunta a los objetivos" % function, body.contains("level.goal_points()") and not body.contains("level.televisions") and not body.contains("level.containers") and not body.contains("level.lock") and not body.contains("code_entered") and not body.contains("stage_televisions"))
	var settle := body_of("res://game/world/generation/tv_placement.gd", "settle")
	check("tv_placement.settle() pregunta al piso que le dan", settle.contains("kind.stages_asking(\"televisions\")") and not settle.contains("HOTEL_FLOOR."))

## Only that the handler's settle() is the old one, on a manifest already
## settled; that build_floor() goes through it is stages_test's to show (no
## set would stand otherwise).
func settling() -> void:
	var before: Dictionary = level.manifest.duplicate(true)
	var after: Dictionary = level.manifest.duplicate(true)
	var old_sets: Dictionary = TV.settle(before, 2)
	var handler_script = load(level.kind.OBJECTIVES["televisions"])
	var new_sets: Dictionary = handler_script.settle(after, 2, level.kind)
	check("Las teles que se quedan son las de antes, y el manifiesto queda igual", not new_sets.is_empty() and new_sets == old_sets and after == before)

## On that stage, what the replaced code computed against what the handlers
## give.
func compare(stage: int, when: String) -> void:
	var session = level.session
	session.stage = stage
	# Reached, so the floor does not take it for a sector just arrived at.
	level.last_stage = stage
	session.goal = {"kind": "refuge", "done": 0, "needed": 1, "ready": false}
	var expected := old_goal()
	var told := [0]
	var count := func(): told[0] += 1
	session.changed.connect(count)
	level.host_gate(0.0)
	session.changed.disconnect(count)
	check("Etapa %d, %s: la meta es la de antes, en su orden" % [stage, when], session.goal == expected.goal and session.goal.keys() == expected.goal.keys(), "%s / %s" % [str(session.goal), str(expected.goal)])
	check("Etapa %d, %s: se avisa las mismas veces" % [stage, when], told[0] == int(expected.told), "%d / %d" % [told[0], int(expected.told)])
	check("Etapa %d, %s: la pausa dice lo mismo" % [stage, when], level.lifts.stage_progress() == old_lines(), "%s / %s" % [str(level.lifts.stage_progress()), str(old_lines())])
	check("Etapa %d, %s: el director va a los mismos sitios" % [stage, when], same(level.goal_points(), old_points()), "%s / %s" % [str(level.goal_points()), str(old_points())])
	check("Etapa %d, %s: y a las mismas salas" % [stage, when], is_instance_valid(level.director) and level.director.goal_rooms() == old_rooms())

static func same(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for index in a.size():
		if a[index] != b[index]: return false
	return true

## host_gate() as it was, on a copy of the goal: what it left and how often it
## told the floor.
func old_goal() -> Dictionary:
	var session = level.session
	var goal: Dictionary = session.goal.duplicate(true)
	var told := 0
	var sets: Array = level.stage_televisions() if level.kind.asks(session.stage, "televisions") else []
	var lit_enough := true
	if not sets.is_empty():
		var needed: int = TV.needed(session.roster_count)
		var done: int = level.televisions_on()
		lit_enough = done >= needed
		goal["sets_done"] = done
		goal["sets_needed"] = needed
		if level.rule("blackout") == 1 and done >= needed - 1 and not goal.get("blackout", false) and not goal.get("restored", false):
			goal["blackout"] = true
			told += 1
	var met := false
	if level.kind.asks(session.stage, "code") and not level.containers.is_empty():
		goal["kind"] = "code"
		goal["done"] = level.found_digits.size()
		goal["needed"] = DIG.COUNT
		met = level.code_entered and lit_enough
	elif not sets.is_empty():
		goal["kind"] = "televisions"
		goal["done"] = int(goal.get("sets_done", 0))
		goal["needed"] = int(goal.get("sets_needed", 0))
		met = lit_enough
	else: met = session.can_depart()
	if session.state == session.State.PLAYING and bool(goal.get("ready", false)) != met:
		goal["ready"] = met
		told += 1
	return {"goal": goal, "told": told}

## lifts.stage_progress() as it was.
func old_lines() -> Array:
	var lines: Array = []
	if level.kind.asks(level.session.stage, "televisions") and not level.stage_televisions().is_empty():
		lines.append(["TELEVISORES", "%d / %d" % [level.televisions_on(), TV.needed(level.session.roster_count)]])
	if level.kind.asks(level.session.stage, "code"):
		lines.append(["NÚMEROS DEL CÓDIGO", "%d / %d" % [level.found_digits.size(), DIG.COUNT]])
	return lines

## pacing_director.ambush()'s spots as they were.
func old_points() -> Array:
	var spots: Array = []
	for index in level.stage_televisions():
		var set = level.televisions[index]
		if is_instance_valid(set) and not set.on: spots.append(set.global_position)
	if int(level.session.stage) >= 3:
		for piece in level.containers:
			if is_instance_valid(piece) and int(piece.digit) >= 0 and not piece.searched: spots.append(piece.global_position)
		if is_instance_valid(level.lock) and not level.code_entered: spots.append(level.lock.global_position)
	return spots

## And its goal_rooms().
func old_rooms() -> Array:
	var rooms: Array = [int(level.refuge_room())]
	for point in old_points(): rooms.append(level.director.room_id(point))
	return rooms.filter(func(id): return id >= 0)

## What each handler keeps is what the floor keeps of it, and the sets come
## back from it.
func saving() -> void:
	var kept: Dictionary = SAVE.take(level)
	var sets: Dictionary = level.objectives["televisions"].snapshot()
	var code: Dictionary = level.objectives["code"].snapshot()
	check("Lo que guardan las teles es lo que guarda el piso", sets == {"sets": kept.sets}, "%s / %s" % [str(sets), str(kept.sets)])
	check("Lo que guarda el código es lo que guarda el piso", code == {"searched": kept.searched, "panels": kept.panels, "hints": kept.hints, "code": kept.code} and not code.searched.is_empty(), str(code))
	var lit := int(level.stage_televisions(2)[0])
	level.apply_television(lit, false, true)
	level.objectives["televisions"].restore(sets)
	check("Y las teles vuelven de lo guardado", level.televisions[lit].on)
