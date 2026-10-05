extends SceneTree
## Continuar gives a floor back as it was left (game/app/floor_save.gd,
## game_session.write_state()): a floor played alone is left half way through
## its second sector -- doors opened, a set lit, furniture gone through, a
## mind worn, the creature somewhere -- and gone on with from the menu. That
## it comes back where it was and not at its beginning; that a floor begun
## afresh has nothing of the old one; that a checkpoint with nothing kept
## beside it still starts its floor from the beginning; and that being caught
## with no stage left to be given back leaves nothing to go on with.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  · " + detail) if not passed and not detail.is_empty() else "")

func frames(count: int) -> void:
	for i in count: await physics_frame

func loaded() -> void:
	await frames(2)
	while level.session.state == level.session.State.LOADING: await process_frame
	await frames(2)

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var session = level.session
	await level.start_floor(81, false, [1], "equilibrada")
	check("Un piso recién empezado no tiene nada guardado de otro", session.read_state(81).is_empty())
	level.locust.set_physics_process(false)
	# Half way through the second sector.
	session.stage = 2
	level.last_stage = 2
	session.changed.emit()
	var sets: Array = level.stage_televisions(2)
	var lit := int(sets[0])
	level.apply_television(lit, true)
	var set: Node3D = level.televisions[lit]
	var stood: Vector3 = FLOOR.closest(level.player.get_world_3d().navigation_map, set.global_position + set.global_basis.z.normalized() * 2.2) + Vector3(0, 0.04, 0)
	level.player.global_position = stood
	level.player.rotation.y = 1.25
	level.player.camera.rotation.x = -0.2
	level.player.sanity = 63.0
	level.player.stamina = 41.0
	# With the torch on: in a dark room the plan sees no further than an arm.
	level.player.torch.visible = true
	session.elapsed = 321.0
	var opened: Array = []
	for index in [3, 17, 40]:
		level.hotel.doors[index].set_state(true)
		opened.append(index)
	# Two pieces gone through: one with a number of the code in it, one bare.
	var with_number := -1
	var bare := -1
	for index in level.containers.size():
		if int(level.containers[index].digit) >= 0 and with_number < 0: with_number = index
		if int(level.containers[index].digit) < 0 and bare < 0: bare = index
	level.apply_search(with_number, true)
	level.apply_search(bare, true)
	# And a line drawn on the sheet.
	level.ui.sheet.restore([["1:1", 0, PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.4, 0.3)])]])
	var den: Vector3 = level.revival.den_away(stood, 30.0)
	level.locust.global_position = den
	await frames(60)
	var seen_before := 0
	for value in level.floor_map.seen: seen_before += 1 if value >= 0.0 else 0
	var ledger_before: Dictionary = level.ledger.pack()
	var digits_before: Dictionary = level.found_digits.duplicate()
	var goal_before: Dictionary = session.goal.duplicate(true)
	# Left from the pause, as anybody leaves it.
	level.on_action("pause")
	await process_frame
	check("Pausar guarda el piso tal como está", FileAccess.file_exists(session.state_path()) and not session.read_state(81).is_empty())
	level.on_action("main")
	await process_frame
	check("En el menú, Continuar está a mano", session.state == session.State.MENU and not session.checkpoint().is_empty())
	level.on_action("continue")
	await loaded()
	var player = level.player
	check("Continuar vuelve al piso, jugando", session.state == session.State.PLAYING and session.run_seed == 81 and level.difficulty == "equilibrada")
	check("En el sector en que se dejó, con su reloj", session.stage == 2 and level.last_stage == 2 and absf(session.elapsed - 321.0) < 3.0, "%d · %0.1f" % [session.stage, session.elapsed])
	check("Donde estaba, mirando a donde miraba", player.global_position.distance_to(stood) < 0.3 and absf(angle_difference(player.rotation.y, 1.25)) < 0.05 and absf(player.camera.rotation.x + 0.2) < 0.05, str(player.global_position, " ", stood))
	check("Con la cordura y el aliento que le quedaban, y la linterna encendida", absf(player.sanity - 63.0) < 2.0 and absf(player.stamina - 41.0) < 8.0 and player.torch.visible, "%0.1f · %0.1f" % [player.sanity, player.stamina])
	check("Las puertas, como estaban", opened.all(func(index): return level.hotel.doors[index].opened))
	check("La tele encendida sigue encendida, y cuenta", level.televisions[lit].on and level.televisions_on() == 1 and int(session.goal.get("sets_done", 0)) == int(goal_before.get("sets_done", -1)))
	check("Los muebles registrados siguen registrados, y el número encontrado, encontrado", level.containers[with_number].searched and level.containers[bare].searched and level.found_digits == digits_before and not level.found_digits.is_empty())
	check("La criatura está donde estaba, con un momento antes de mirar", level.locust.global_position.distance_to(den) < 1.0 and level.locust.grace > 0.0 and level.locust.mode == level.locust.Mode.PATROL)
	var seen_after := 0
	for value in level.floor_map.seen: seen_after += 1 if value >= 0.0 else 0
	check("El plano recuerda lo que se había visto", seen_before > 0 and seen_after >= seen_before, "%d · %d" % [seen_before, seen_after])
	var ledger_after: Dictionary = level.ledger.pack()
	check("La cinta conserva lo que llevaba contado", ledger_after.events.size() >= ledger_before.events.size() and int(ledger_after.seats[1].searched) == int(ledger_before.seats[1].searched) and ledger_after.lit_by == ledger_before.lit_by, str(ledger_after.seats.get(1, {})))
	check("La hoja conserva lo dibujado", level.sheet_snapshot().size() == 1 and level.sheet_snapshot()[0][2].size() == 2)
	check("Y lo vuelve a guardar al momento, para no perderlo", not session.read_state(81).is_empty())
	# Being executed is nothing to go back to: the floor is not kept then.
	level.locust.set_physics_process(false)
	level.locust.grace = 0.0
	level.locust.global_position = player.global_position + Vector3(1.2, 0, 0)
	level.capture_survivor(player)
	check("Mientras la criatura lo tiene, no se guarda", not level.execution.is_empty() and not level.can_keep())
	await level.start_floor(4242, false, [1], "equilibrada")
	check("Un piso nuevo no hereda lo guardado del anterior", session.read_state(4242).is_empty() and session.read_state(81).is_empty() and session.stage == 1)
	# A checkpoint with nothing beside it (one from before floors were kept).
	level.on_action("pause")
	await process_frame
	level.on_action("main")
	await process_frame
	DirAccess.remove_absolute(session.state_path())
	level.on_action("continue")
	await loaded()
	check("Sin nada guardado junto al punto de control, el piso empieza de nuevo", session.state == session.State.PLAYING and session.run_seed == 4242 and session.stage == 1 and session.elapsed < 5.0)
	# Left inside a wardrobe: found inside it, and counted as hidden once.
	level.locust.set_physics_process(false)
	var place: Node3D = level.hotel.hides[0]
	level.player.enter_hide(place)
	await frames(4)
	var hides_before: int = level.ledger.hides
	level.on_action("pause")
	await process_frame
	level.on_action("main")
	await process_frame
	level.on_action("continue")
	await loaded()
	check("Dejado dentro de un armario, se vuelve dentro de él, sin contarlo dos veces", level.player.hidden and level.player.hiding_place == level.hotel.hides[0] and level.hotel.hides[0].occupant == level.player and level.ledger.hides == hides_before, "%s · %d · %d" % [level.player.hidden, level.ledger.hides, hides_before])
	# No stage left to be given back: caught, the floor is lost there and then.
	await level.start_floor(81, false, [1], "desafiante")
	level.keep_floor()
	level.locust.set_physics_process(false)
	level.locust.grace = 0.0
	level.locust.global_position = level.player.global_position + Vector3(1.2, 0, 0)
	level.capture_survivor(level.player)
	check("En Desafiante, la captura deja sin Continuar antes de que caiga el golpe", not level.execution.is_empty() and session.state == session.State.PLAYING and session.checkpoint().is_empty() and session.read_state(81).is_empty())
	# Let go alive (the stage closing under it): the floor goes on, and the
	# next keeping gives Continuar its floor back.
	level.release_execution()
	check("Soltado con vida, el piso se vuelve a guardar entero", level.keep_floor() and not session.checkpoint().is_empty() and not session.read_state(81).is_empty())
	var file := FileAccess.open("res://evidence/continue_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("CONTINUE_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)
