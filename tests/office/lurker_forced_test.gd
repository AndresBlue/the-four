extends SceneTree
## Her forced encounters (the author, 24 October 2026;
## .claude/specs/spec_f3_aggression.md, unit 6), on floor 2 in Pesadilla:
## not before her forced_after() without getting at anybody, never towards
## somebody hidden, and after it the director leads her into the room of
## somebody out there -- where she finds them on her own, by her senses.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const DIFFICULTY := preload("res://game/floors/difficulty.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
var checks: Array = []
var failed := 0

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
	await play(level)
	var file := FileAccess.open("res://evidence/lurker_forced_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("LURKER_FORCED_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)

func play(level) -> void:
	var lurker = level.creature
	var director = level.director
	if lurker == null or lurker.kind_id() != &"lurker" or director == null:
		check("Ella y el director en el piso", false)
		return
	director.process_mode = Node.PROCESS_MODE_DISABLED
	var player = level.player
	player.set_physics_process(false)
	lurker.grace = 0.0
	var profiles: Dictionary = DIFFICULTY.CREATURE_PROFILES.lurker
	check("En Apacible nunca; en las demás, a los 150, 90 y 60 s sin alcanzar a nadie", float(profiles.apacible.forced_after) == 0.0 and lurker.forced_after() == 60.0 and float(profiles.equilibrada.forced_after) == 150.0 and float(profiles.desafiante.forced_after) == 90.0, str(lurker.forced_after()))
	# A dark room of her planta far from her by her own ways: the player
	# stands in its middle.
	var from: int = FLOOR.room_at(level.manifest.rooms, lurker.global_position).get("id", -1)
	var metres: Dictionary = lurker.travel_metres(from)
	# A corridor first, else an open office, a rest room or an office: nothing
	# tall between her and them.
	var wing := int(level.manifest.rooms[from].get("wing", -1)) if from >= 0 else -1
	var room := -1
	for kind in [OFFICE.CORRIDOR, 1, 15, 3]:
		for r in level.manifest.rooms:
			var id := int(r.id)
			if room >= 0 or int(r.type) != kind or FLOOR.is_void(r) or int(r.get("wing", -1)) != wing or level.off_limits_rooms().has(id) or not lurker.shell.tray_of.has(id) or level.hotel.lit(id): continue
			if float(metres.get(id, INF)) >= 18.0 and float(metres.get(id, INF)) < 60.0: room = id
	if room < 0:
		check("Una sala a oscuras de su planta a 18 m o más de ella", false, "%d %d %s" % [from, wing, str(metres)])
		return
	player.global_position = FLOOR.position_of(level.manifest.rooms[room]) + Vector3(0, 0.05, 0)
	await physics_frame
	lurker.brain.lead = {}
	# Its clock well past the start, and no rest in hand (counted from its end).
	director.clock = 300.0
	director.phase = director.Phase.BUILD
	director.rest_until = 0.0
	director.last_contact = director.clock
	check("Antes de su tiempo, no la trae", not director.forced_due() and lurker.brain.lead.is_empty())
	director.last_contact = director.clock - 61.0
	player.hidden = true
	var hidden_due: bool = director.forced_due()
	player.hidden = false
	check("Nunca a por alguien escondido", not hidden_due and lurker.brain.lead.is_empty())
	director.last_contact = director.clock - 61.0
	var due: bool = director.forced_due()
	var lead: Dictionary = lurker.brain.lead
	check("Pasado su tiempo, el director la lleva a la sala de alguien", due and String(lead.get("kind", "")) == "encuentro" and lead.get("rooms", []) == [room] and String(director.current.get("kind", "")) == "encuentro" and director.clock - director.last_contact < 0.01, "%s %d %s %s" % [str(due), room, str(lead), str(director.history.back() if not director.history.is_empty() else {})])
	# And there she finds them herself.
	Engine.time_scale = 3.0
	var found := false
	var took := 0.0
	for i in 60 * 45:
		await physics_frame
		took += 1.0 / 60.0
		if int(lurker.brain.prey) == int(player.slot) and lurker.brain.state in [BRAIN.State.STALK, BRAIN.State.PEEK, BRAIN.State.CREEP, BRAIN.State.CUE]:
			found = true
			break
	Engine.time_scale = 1.0
	check("Llevada allí, da con esa persona por sus sentidos y va a por ella", found, "%0.1f s, %s, prey %d" % [took, lurker.brain.state_name(), int(lurker.brain.prey)])
	director.last_contact = director.clock - 30.0
	director.tick(1.0 / 60.0)
	check("Y eso cuenta como contacto: el reloj del encuentro forzado vuelve a cero", found and is_equal_approx(director.last_contact, director.clock))
