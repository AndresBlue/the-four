extends SceneTree
## Her forced encounters (the author, 24 October 2026;
## .claude/specs/spec_f3_aggression.md, unit 6), on floor 2 in Pesadilla:
## not before her forced_after() without getting at anybody, never towards
## somebody hidden, and after it the director leads her into the room of
## somebody out there (the one they walk to, again every FORCED_REFRESH s
## while she gets at nobody) -- where she finds them on her own, by her senses.
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
	# Her wait read from the profiles: never on Apacible, and sooner the harder.
	var waits: Array = DIFFICULTY.ORDER.map(func(id): return float(DIFFICULTY.profile(id, &"lurker").forced_after))
	var sooner := true
	for i in range(2, waits.size()): sooner = sooner and float(waits[i]) > 0.0 and float(waits[i]) <= float(waits[i - 1])
	var after: float = lurker.forced_after()
	check("En Apacible nunca; en las demás, antes cuanto más difícil, y el suyo es el de su perfil (%s)" % str(waits), float(waits[0]) == 0.0 and float(waits[1]) > 0.0 and sooner and after == float(DIFFICULTY.profile("pesadilla", &"lurker").forced_after), str(after))
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
	director.last_contact = director.clock - after - 1.0
	player.hidden = true
	var hidden_due: bool = director.forced_due()
	player.hidden = false
	check("Nunca a por alguien escondido", not hidden_due and lurker.brain.lead.is_empty())
	# Somebody walking: led to where they are going, FORCED_AHEAD s on, not to
	# the room they are leaving.
	var next := -1
	for other in level.manifest.adjacency[room]:
		if not FLOOR.is_void(level.manifest.rooms[int(other)]) and int(level.manifest.rooms[int(other)].get("wing", -1)) == wing:
			next = int(other)
			break
	if next >= 0:
		player.velocity = (FLOOR.position_of(level.manifest.rooms[next]) - player.global_position) / director.FORCED_AHEAD
		director.last_contact = director.clock - after - 1.0
		var ahead_due: bool = director.forced_due()
		var ahead_lead: Dictionary = lurker.brain.lead
		player.velocity = Vector3.ZERO
		check("A quien camina, la lleva a la sala a la que va, no a la que deja", ahead_due and String(ahead_lead.get("kind", "")) == "encuentro" and (ahead_lead.point as Vector3).is_equal_approx(FLOOR.position_of(level.manifest.rooms[next])), "%d %d %s" % [room, next, str(ahead_lead)])
	director.last_contact = director.clock - after - 1.0
	var due: bool = director.forced_due()
	var lead: Dictionary = lurker.brain.lead
	check("Pasado su tiempo, el director la lleva a la sala de alguien, y la vuelve a llevar cada FORCED_REFRESH s mientras no alcance a nadie", due and String(lead.get("kind", "")) == "encuentro" and lead.get("rooms", []) == [room] and String(director.current.get("kind", "")) == "encuentro" and is_equal_approx(director.last_contact, director.clock - after + director.FORCED_REFRESH), "%s %d %s %s" % [str(due), room, str(lead), str(director.history.back() if not director.history.is_empty() else {})])
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
	# With every door of her planta shut there is no way over her surfaces to
	# another room: going there with somebody in her eye, by the plenum.
	lurker.thinking = false
	var shut: Array = []
	for door in level.hotel.doors:
		if is_instance_valid(door) and bool(door.opened) and FLOOR.planta_of(door.doorway.y) == FLOOR.planta_of(lurker.global_position.y):
			door.set_state(false)
			shut.append(door)
	lurker.teleport(lurker.room_point(room), 0.0, &"prueba")
	await physics_frame
	var here: int = lurker.motion.room()
	var there := -1
	for r in level.manifest.rooms:
		var id := int(r.id)
		if id != here and int(r.get("wing", -1)) == wing and lurker.shell.tray_of.has(id) and not level.off_limits_rooms().has(id) and float(lurker.travel_metres(here).get(id, INF)) > 15.0 and not lurker.motion.go_to(lurker.room_point(id), 1.35, true):
			there = id
			break
	lurker.last_order = {}
	if there >= 0: lurker.apply_intent({"do": &"go", "to": lurker.room_point(there), "speed": 1.35, "look": level.player.global_position})
	var kinds: Array = lurker.motion.legs.map(func(leg): return String(leg.kind))
	check("Sin camino por los techos, una ida mirando a alguien va por el pleno, no se queda colgada", there >= 0 and not lurker.order_failed and kinds.has("duct"), "%d %s" % [there, str(kinds)])
	for door in shut: door.set_state(true)
