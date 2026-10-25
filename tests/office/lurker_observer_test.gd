extends SceneTree
## Step 3e (.claude/specs/spec_f3_integration.md 6) on floor 2: her pack of
## twelve (her mind's state, her prey and the flag of a fright), her marks for
## the observer on its three layers (the ducts the seventh), her moments told
## to every machine (the tile a puppet turns as the one who drives her did)
## and what a bots' recording keeps of her and how a replay puts her back.
const GIZMOS := preload("res://game/app/observer_gizmos.gd")
const THREATS := preload("res://tools/bots/bot_threats.gd")
const RECORDER := preload("res://tools/bots/bot_recorder.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const LURKER := preload("res://game/enemies/lurker/lurker.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var checks: Array = []
var failed := 0

## What the observer's gizmos are to her draw_gizmos(): the layer, the
## colours, here() and the three ways of drawing, counted.
class Pen extends RefCounted:
	var layer := &""
	var COLOURS: Dictionary = GIZMOS.COLOURS
	var planta := 0
	var lines: Array = []
	var marks := 0
	var rings: Array = []
	func here(point: Vector3) -> bool: return FLOOR_DEF.planta_of(point.y) == planta
	func line(from: Vector3, to: Vector3, colour: Color) -> void: lines.append([from, to, colour])
	func mark(_point: Vector3, _colour: Color, _size := 0.5) -> void: marks += 1
	func ring(point: Vector3, radius: float, colour: Color, _steps := 24) -> void: rings.append([point, radius, colour])
	func coloured(colour: Color) -> int: return lines.filter(func(l): return (l[2] as Color).is_equal_approx(colour)).size()
	const FLOOR_DEF := preload("res://game/world/generation/floor_definition.gd")

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "lurker"
	level.set_floor(2)
	await level.start_floor(7, false, [1], "pesadilla")
	var lurker = level.creature
	if lurker == null or lurker.kind_id() != &"lurker":
		check("Ella en el piso", false)
	else:
		if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
		level.player.set_physics_process(false)
		lurker.thinking = false
		await physics_frame
		pack(lurker)
		await gizmos(level, lurker)
		events(level, lurker)
		recording(level, lurker)
	var file := FileAccess.open("res://evidence/lurker_observer_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("LURKER_OBSERVER_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)

func pack(lurker) -> void:
	lurker.brain.prey = int(lurker.level.player.slot)
	lurker.brain.enter(BRAIN.State.FLEE)
	var sent: Array = lurker.pack_state()
	check("Su paquete lleva doce: los diez de 2a, su estado y su presa", sent.size() == 12 and LURKER.PACK_SIZE == 12 and int(sent[10]) == int(BRAIN.State.FLEE) and int(sent[11]) == int(lurker.level.player.slot), str(sent.slice(10)))
	check("Huyendo, la bandera del espanto", int(sent[4]) & LURKER.Flag.SCARED != 0 and LURKER.Flag.SCARED > LURKER.Flag.BAND)
	lurker.push_state(sent)
	var read: bool = lurker.net_mind == int(BRAIN.State.FLEE) and lurker.net_prey == int(lurker.level.player.slot)
	lurker.net_mind = -7
	lurker.push_state(sent.slice(0, 10))
	check("Quien la recibe lee su estado y su presa; un paquete de otro tamaño, nada", read and lurker.net_mind == -7)
	lurker.net_mind = -1
	lurker.brain.prey = -1
	lurker.brain.enter(BRAIN.State.ROAM)

func gizmos(level, lurker) -> void:
	var shown: Dictionary = GIZMOS.new().shown
	check("El observador tiene la séptima capa, los ductos, y sus colores", shown.has("ducts") and ["shell", "duct", "duct_path", "exit", "closed", "cue", "drain"].all(func(k): return GIZMOS.COLOURS.has(k)))
	# On a ceiling of the player's planta, two rooms from another.
	var trays: Array = lurker.shell.tray_of.keys().filter(func(r): return int(level.manifest.rooms[int(r)].get("wing", -1)) == FLOOR.planta_of(level.player.global_position.y))
	trays.sort()
	lurker.teleport(lurker.room_point(int(trays[0])), 0.0, &"test")
	await physics_frame
	var pen := Pen.new()
	pen.planta = FLOOR.planta_of(lurker.global_position.y)
	var ducts = lurker.ducts
	var on_planta := 0
	for e in ducts.edges:
		if pen.here(ducts.nodes[int(e[0])]) and pen.here(ducts.nodes[int(e[1])]): on_planta += 1
	pen.layer = &"ducts"
	lurker.draw_gizmos(pen)
	check("En la capa de los ductos, la red de la planta y sus entradas", on_planta > 0 and pen.coloured(GIZMOS.COLOURS.duct) + pen.lines.filter(func(l): return (l[2] as Color).a < 0.5).size() >= on_planta and pen.marks > 0, "%d de %d, %d marcas" % [pen.lines.size(), on_planta, pen.marks])
	# On her way somewhere, with a lead from the director and a warning in hand.
	lurker.motion.go_to(lurker.room_point(int(trays[trays.size() - 1])), 1.35)
	lurker.brain.lead = {"point": lurker.global_position, "radius": 6.0, "until": lurker.brain.clock + 30.0, "kind": "merodea", "rooms": [], "once": false, "sniff": false}
	lurker.warning.active = {"seat": int(level.player.slot), "due": lurker.brain.clock + 0.75, "window": 1.5}
	pen = Pen.new()
	pen.planta = FLOOR.planta_of(lurker.global_position.y)
	pen.layer = &"path"
	lurker.draw_gizmos(pen)
	var cue_ring: Array = pen.rings.filter(func(x): return (x[2] as Color).is_equal_approx(GIZMOS.COLOURS.cue))
	check("En la del camino, su ruta, su techo, la pista del director y el aviso que se cierra", pen.coloured(GIZMOS.COLOURS.path) > 0 and pen.coloured(GIZMOS.COLOURS.shell) > 0 and pen.rings.any(func(x): return (x[2] as Color).is_equal_approx(GIZMOS.COLOURS.lead)) and pen.coloured(GIZMOS.COLOURS.cue) == 1 and cue_ring.size() == 1 and absf(float(cue_ring[0][1]) - 0.9) < 0.05, "%d %d %s" % [pen.coloured(GIZMOS.COLOURS.path), pen.coloured(GIZMOS.COLOURS.shell), str(cue_ring)])
	lurker.warning.active = {}
	lurker.brain.lead = {}
	lurker.motion.hold()
	pen = Pen.new()
	pen.planta = FLOOR.planta_of(lurker.global_position.y)
	pen.layer = &"sight"
	lurker.draw_gizmos(pen)
	check("En la de la vista, los dos bordes de lo que ve", not lurker.motion.in_duct and pen.coloured(GIZMOS.COLOURS.sight) == 2, str(pen.lines.size()))
	lurker.drained = {int(lurker.motion.room()): 0.6}
	var said: Array = lurker.debug_lines()
	check("En el panel, su mente y lo que bebe", said.any(func(s): return String(s).begins_with("  mente ")) and said.any(func(s): return String(s) == "  bebe %d (0.60)" % int(lurker.motion.room())) and lurker.debug_state().has("bebe"), str(said))
	lurker.drained = {}

func events(level, lurker) -> void:
	check("La red tiene el evento de la criatura, que manda quien la lleva", level.match_net.has_method("creature_event") and level.match_net.has_method("creature_event_rpc") and not level.match_net.in_match())
	var ducts = lurker.ducts
	var room := -1
	for id in ducts.room_tiles:
		if lurker.shell.tray_of.has(int(id)):
			room = int(id)
			break
	var tile: Vector2i = ducts.room_tiles[room][0]
	# A puppet's: the event alone turns its tile.
	lurker.on_event("tile", [room, tile.x, tile.y, true, false])
	var hinge = level.hotel.moved_tiles.get(Vector3i(room, tile.x, tile.y))
	check("Con el evento de la placa, cada máquina la abre como quien la lleva", hinge != null and (ducts.open_tiles.get(room, []) as Array).has(tile))
	lurker.on_event("tile", [room, tile.x, tile.y, false, true])
	check("Y la cierra igual", not (ducts.open_tiles.get(room, []) as Array).has(tile))

func recording(level, lurker) -> void:
	var model = THREATS.make(level)
	check("Los bots la miran con su propio modelo", model != null and model.get_script().resource_path.ends_with("bot_threat_lurker.gd"))
	if model == null: return
	lurker.brain.prey = int(level.player.slot)
	lurker.brain.enter(BRAIN.State.STALK)
	var row: Array = model.recorded_row()
	var turn: Quaternion = lurker.global_basis.get_rotation_quaternion()
	check("Su fila de la grabación: dónde, su giro entero, su estado, su presa, el ducto y el aviso", row.size() == RECORDER.CREATURE_FIELDS and Vector3(row[0], row[1], row[2]).is_equal_approx(lurker.global_position) and Quaternion(row[3], row[4], row[5], row[6]).is_equal_approx(turn) and int(row[7]) == int(BRAIN.State.STALK) and int(row[8]) == int(level.player.slot), str(row))
	var watch: Dictionary = model.recorded_watch()
	check("Lo que vigila el registro: su estado y a quién va", int(watch.get("mode", -9)) == int(BRAIN.State.STALK) and int(watch.get("focus", -9)) == int(level.player.slot))
	# A replay between two frames: halfway along, halfway round.
	var a := PackedFloat32Array([0.0, 0.0, 0.0] + row)
	var later: Array = row.duplicate()
	later[0] = float(row[0]) + 2.0
	var turned: Quaternion = turn * Quaternion(Vector3.UP, PI / 2.0)
	later[3] = turned.x
	later[4] = turned.y
	later[5] = turned.z
	later[6] = turned.w
	var b := PackedFloat32Array([0.0, 0.0, 0.0] + later)
	var was: Vector3 = lurker.global_position
	model.replay_row(a, b, 3, 0.5, 1.0)
	var halfway := turn.slerp(turned, 0.5)
	check("Una repetición la pone donde y como la tiene la grabación", lurker.global_position.is_equal_approx(was + Vector3(1.0, 0, 0)) and lurker.global_basis.orthonormalized().is_equal_approx(Basis(halfway)), "%s %s" % [str(lurker.global_position - was), str(lurker.global_basis)])
	model.replay_mode(int(BRAIN.State.CREEP))
	check("Y haciendo lo que hacía", lurker.word == &"chase" and lurker.net_mind == int(BRAIN.State.CREEP))
