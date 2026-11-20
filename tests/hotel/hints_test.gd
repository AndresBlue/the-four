extends SceneTree
## The control hints of the first games (control_hints.gd): none as the floor
## starts; keys in keycaps, side by side; each thing is shown once a game; a dark room entered
## with the torch off says F; five games and they turn off by themselves, and
## stay on once turned on by hand; floor 2 turns them on for its own five.
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func card_words(level) -> Array:
	var words: Array = []
	if level.ui.controls_card == null or not level.ui.controls_up: return words
	for line in level.ui.controls_card.get_children():
		if not line.is_queued_for_deletion() and not line.get_meta("gone", false): words.append(String(line.get_child(line.get_child_count() - 1).text))
	return words

func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "none"
	var settings = level.settings
	settings.set_value("control_hints", true)
	settings.set_value("hint_games", 0)
	settings.set_value("hint_floor", 1)
	await level.start_floor(7, false, [1], "apacible", 1)
	check("Una partida empezada cuenta", int(settings.values.hint_games) == 1, str(settings.values.hint_games))
	for frame in 150: await physics_frame
	check("Al empezar no sale nada", card_words(level).is_empty(), str(card_words(level)))
	var hints = level.hints
	hints.clear()
	hints.aimed("door")
	check("La puerta: E abre o cierra, mantenida va despacio", card_words(level) == ["Abrir o cerrar", "Despacio, sin ruido"], str(card_words(level)))
	var first: Node = level.ui.controls_card.get_child(0)
	check("Una al lado de la otra, cada tecla en su keycap", level.ui.controls_card is HFlowContainer and first.get_child(0) is PanelContainer)
	hints.clear()
	hints.aimed("door")
	check("Una vez por partida", card_words(level).is_empty())
	# In a wardrobe (out of it, its card goes).
	level.player.hidden = true
	hints.aimed("inside")
	check("En el armario: asomarse, salir y salir sin ruido", card_words(level) == ["Asomarte", "Salir", "Salir sin ruido"], str(card_words(level)))
	# Done what it says, it goes HEEDED seconds later, alone: the others stay.
	await physics_frame
	# Held HOLD seconds, gone HEEDED after: 0.7 s.
	Input.action_press("forward")
	for frame in 30: await physics_frame
	Input.action_release("forward")
	for frame in 20: await physics_frame
	check("Mantenida W, solo se va asomarte", card_words(level) == ["Salir", "Salir sin ruido"], str(card_words(level)))
	check("Y las otras siguen un rato", hints.left >= hints.REST_AFTER - 0.5, "%.2f" % hints.left)
	level.player.hidden = false
	hints.clear()
	check("Al quitarla se apaga despacio, no de golpe", level.ui.controls_card.visible and card_words(level).is_empty())
	for frame in 40: await physics_frame
	check("Y ya no está", not level.ui.controls_card.visible)
	hints.clear()
	hints.aimed("usable", "ESCRIBIR", true)
	check("Lo del piso 2 con su palabra, y MANTÉN si se mantiene", card_words(level) == ["Escribir"] and level.ui.controls_card.get_child(0).get_child(0) is Label, str(card_words(level)))
	hints.clear()
	level.hotel.dark = true
	level.player.torch.visible = false
	hints.last_room = -2
	hints.tick(0.016)
	check("A oscuras con la linterna apagada: F", card_words(level) == ["Encender la linterna"], str(card_words(level)))
	level.hotel.dark = false
	for game in 4: hints.begin()
	check("Cinco partidas, siguen", bool(settings.values.control_hints) and int(settings.values.hint_games) == 5)
	hints.begin()
	check("En la sexta se apagan solas", not bool(settings.values.control_hints))
	hints.aimed("tv")
	check("Apagadas, no sale nada", card_words(level).is_empty())
	settings.set_value("control_hints", true)
	hints.begin()
	check("Encendidas a mano, se quedan", bool(settings.values.control_hints))
	level.set_floor(2)
	hints.begin()
	check("El piso 2 las enciende para sus cinco", bool(settings.values.control_hints) and int(settings.values.hint_floor) == 2 and int(settings.values.hint_games) == 1, "%s %s %s" % [settings.values.control_hints, settings.values.hint_floor, settings.values.hint_games])
	level.set_floor(1)
	hints.begin()
	check("El piso 1 ya no cuenta", int(settings.values.hint_games) == 1)
	settings.set_value("control_hints", true)
	settings.set_value("hint_games", 0)
	settings.set_value("hint_floor", 1)
	settings.save_settings()
	print("HINTS_TEST_RESULT %d fallos" % failed)
	quit(1 if failed > 0 else 0)
