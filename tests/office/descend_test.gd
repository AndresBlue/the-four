extends SceneTree
## Floor 1 won leads down (hotel_main "descend", unlock_floor2()): the end
## screen offers floor 2, the difficulty is kept as reached, a new game offers
## it beside that difficulty, and going down builds floor 2 on it.
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "none"
	level.settings.set_value("floor2", "")
	await level.start_floor(7, false, [1], "apacible", 1)
	level.session.set_state(level.session.State.WON)
	await process_frame
	check("Ganado el piso 1, se puede bajar", level.ui.descend)
	check("El piso 2 queda abierto en Apacible", String(level.settings.values.floor2).split(",").has("apacible"), String(level.settings.values.floor2))
	check("La pantalla final ofrece bajar", level.ui.buttons.has("descend"), str(level.ui.buttons.keys()))
	level.ui.menu("difficulty")
	check("Nueva partida ofrece el piso 2 junto a Apacible", level.ui.buttons["apacible"].get_parent().get_parent() is HBoxContainer)
	check("Pero no junto a Pesadilla", not (level.ui.buttons["pesadilla"].get_parent().get_parent() is HBoxContainer))
	level.on_action("descend")
	for frame in 1800:
		if level.session.floor_number == 2 and level.session.state == level.session.State.PLAYING: break
		await physics_frame
	check("Bajar construye el piso 2", level.session.floor_number == 2 and level.session.state == level.session.State.PLAYING, "%d, %d" % [level.session.floor_number, level.session.state])
	check("En la misma dificultad", level.difficulty == "apacible", level.difficulty)
	level.session.set_state(level.session.State.WON)
	await process_frame
	check("Ganado el piso 2, no se ofrece bajar", not level.ui.descend)
	print("DESCEND_TEST_RESULT %d fallos" % failed)
	quit(1 if failed > 0 else 0)
