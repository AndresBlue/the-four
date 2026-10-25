extends SceneTree
## Step 3f (.claude/specs/spec_f3_integration.md 7.4) on floor 2 with her: the
## bots' model of The Lurker at work, staged on a bot match whose own loop is
## stopped, its bots driven by hand. A worker gets a guard behind its back,
## facing the room; an expert turns to its own warning with its torch on, and
## the warning ends saved; one that turns too late is taken after its warning,
## and the watchdog finds nothing unfair in that.
const MATCH := preload("res://tools/bots/bot_match.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const BOT_BRAIN := preload("res://tools/bots/bot_brain.gd")
const MODEL := preload("res://tools/bots/bot_threat_lurker.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const DT := 1.0 / 60.0
var checks: Array = []
var failed := 0
var level
var bots
var lurker
var model

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.set_floor(2)
	level.creature_scene = "lurker"
	bots = MATCH.new()
	bots.setup(level, {"bots": 2, "seed": 81, "knowledge": "oracle", "difficulty": "desafiante", "verbose": false, "out": "", "stage_cap": 600.0, "run_cap": 1500.0})
	root.add_child(bots)
	if not await bots.begin():
		check("La partida de los bots arranca en el piso 2 con ella", false)
	else:
		bots.set_physics_process(false)
		if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
		lurker = level.creature
		model = bots.threat
		check("Los bots la miran con su modelo", model != null and model.get_script() == MODEL)
		lurker.grace = 0.0
		var rooms := dark_rooms()
		var wide := dark_rooms(7.0)
		if rooms.size() < 1 or wide.size() < 2:
			check("Salas a oscuras en la planta 1, dos de 7 m o más", false)
		else:
			await cover_case(rooms[0])
			await turn_case(wide[0], false)
			await turn_case(wide[1], true)
	var file := FileAccess.open("res://evidence/lurker_bots_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("LURKER_BOTS_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

## Rooms of planta 1, dark, hers to walk over, open offices and corridors
## first: room to stand in and nothing tall about; `least` metres a side.
func dark_rooms(least := 5.0) -> Array:
	var out: Array = []
	for kind in [1, OFFICE.CORRIDOR, 15, 3]:
		for room in level.manifest.rooms:
			var id := int(room.id)
			if int(room.type) != kind or FLOOR.is_void(room) or int(room.get("wing", -1)) != 0 or level.off_limits_rooms().has(id) or level.hotel.lit(id) or not lurker.shell.tray_of.has(id): continue
			if FLOOR.size_of(room).x < least or FLOOR.size_of(room).y < least: continue
			out.append(id)
	return out

func floor_point(room: int, offset := Vector3.ZERO) -> Vector3:
	return FLOOR.closest(level.get_world_3d().navigation_map, FLOOR.position_of(level.manifest.rooms[room]) + offset)

func park_her() -> void:
	lurker.thinking = false
	lurker.brain.prey = -1
	lurker.brain.enter(BRAIN.State.ROAM)
	lurker.motion.hold()

## One frame of the bots by hand: her model, then the brains asked.
func step(brains: Array) -> void:
	model.refresh()
	for brain in brains: brain.tick(DT)
	await physics_frame

func cover_case(room: int) -> void:
	park_her()
	var a = bots.brains[0]
	var b = bots.brains[1]
	var at := floor_point(room)
	a.body.place(at, 0.0)
	a.body.look_yaw = 0.0
	a.task = {"kind": "use", "stand": at, "label": "prueba"}
	a.state = BOT_BRAIN.State.ACT
	b.body.place(floor_point(room, Vector3(3.0, 0, 3.0)), 0.0)
	b.task = {}
	b.state = BOT_BRAIN.State.IDLE
	var noted := false
	for i in int(10.0 / DT):
		model.refresh()
		b.tick(DT)
		a.state = BOT_BRAIN.State.ACT
		await physics_frame
		if b.minding == "cubre": noted = true
	var spot: Vector3 = model.guard_spot(a)
	var me: Vector3 = b.body.global_position
	var away := Vector3(me.x - a.body.global_position.x, 0, me.z - a.body.global_position.z).normalized()
	var looks := Vector3(-sin(b.body.look_yaw), 0, -cos(b.body.look_yaw))
	check("Quien trabaja tiene un guardia: a su espalda y mirando a la sala", noted and Vector2(spot.x - me.x, spot.z - me.z).length() < 1.0 and rad_to_deg(looks.angle_to(away)) < 30.0, "%s %.2f m, %.0f grados" % [str(noted), Vector2(spot.x - me.x, spot.z - me.z).length(), rad_to_deg(looks.angle_to(away))])
	a.task = {}
	a.state = BOT_BRAIN.State.IDLE
	model.guards.clear()

## Her after the first bot from the dark ceiling 5 m behind it in its room, the other
## bot far off and still. The bot stands till its warning plays; then an
## expert is driven and turns with the torch on (saved); one made to turn
## 3 s late is left standing (driven, it runs, and running saves too) and is
## taken after its warning: the watchdog says nothing.
func turn_case(room: int, late: bool) -> void:
	park_her()
	var a = bots.brains[0] if not late else bots.brains[1]
	var other = bots.brains[1] if not late else bots.brains[0]
	if not a.alive():
		check("El bot de la prueba sigue vivo", false)
		return
	# The other far off, its torch off: a beam on her is a fright.
	var far := room
	for r in dark_rooms():
		if FLOOR.position_of(level.manifest.rooms[int(r)]).distance_to(FLOOR.position_of(level.manifest.rooms[room])) > FLOOR.position_of(level.manifest.rooms[far]).distance_to(FLOOR.position_of(level.manifest.rooms[room])): far = int(r)
	other.body.place(floor_point(far), 0.0)
	other.body.torch_wanted = false
	var at := floor_point(room, Vector3(0, 0, -2.0))
	a.body.place(at, 0.0)
	a.body.look_yaw = 0.0
	a.task = {}
	a.state = BOT_BRAIN.State.IDLE
	a.body.torch_wanted = false
	# Still, both: nothing left of where they were going before.
	a.halt()
	other.halt()
	if late: model.react_override[int(a.seat)] = 3.0
	await physics_frame
	# Five metres behind its back (it looks to -z), on her ceiling there.
	lurker.teleport(lurker.clue_point(at + Vector3(0, 0, 5.0)), PI, &"prueba")
	await physics_frame
	lurker.thinking = true
	lurker.brain.prey = int(a.seat)
	lurker.brain.enter(BRAIN.State.STALK)
	var takes_before: int = lurker.takes.size()
	var played := -1.0
	var faced := -1.0
	var lit_when_faced := false
	var clock := 0.0
	for i in int(40.0 / DT):
		clock += DT
		if played < 0.0 and model.cues.has(int(a.seat)): played = clock
		await step([a] if played >= 0.0 and not late else [])
		if played >= 0.0 and faced < 0.0 and a.alive():
			var look: Vector3 = -a.body.camera.global_basis.z
			var to_her: Vector3 = lurker.face_point() - a.body.camera.global_position
			if rad_to_deg(look.angle_to(to_her)) < 30.0:
				faced = clock - played
				lit_when_faced = bool(a.body.torch_wanted)
		if lurker.takes.size() > takes_before or (played >= 0.0 and model.cue_over(model.cues.get(int(a.seat), {"cue_id": -1})) and clock - played > 4.0): break
	var log: Array = lurker.capture_log()
	var last: Dictionary = log[log.size() - 1] if not log.is_empty() else {}
	if not late:
		check("Un aviso en su espalda en menos de 40 s", played >= 0.0, "%s" % lurker.brain.state_name())
		check("El experto se gira a ella con la linterna a tiempo", faced >= 0.0 and faced <= MODEL.REACT.experto + MODEL.REACT_JITTER + 0.4 and lit_when_faced, "%.2f s, linterna %s" % [faced, str(lit_when_faced)])
		check("Y el aviso acaba en salvada, sin captura", String(last.get("outcome", "")) == "saved" and lurker.takes.size() == takes_before, "%s %s" % [str(last.get("outcome")), str(last.get("reason"))])
	else:
		var reports: Array = []
		model.audit_creature(func(kind: String, _severity: String, _words: String, _extra: Dictionary): reports.append(kind))
		var tally: Dictionary = lurker.tally()
		check("Quien se gira tarde es cogido, después de su aviso", played >= 0.0 and lurker.takes.size() == takes_before + 1 and String(last.get("outcome", "")) == "taken", "%s %s %d, sonó %.1f, asiento %d, %s" % [str(last.get("outcome")), str(last.get("reason")), lurker.takes.size() - takes_before, played, int(a.seat), str(log.slice(-3).map(func(e): return [int(e.seat), String(e.outcome), String(e.reason)]))])
		check("Y el vigilante no ve nada injusto: ni captura sin aviso ni registro torcido", reports.is_empty() and int(tally.get("unpaired", -1)) == 0, "%s %s" % [str(reports), str(tally)])
	model.react_override.clear()
