extends SceneTree
## The coffee machines (coffee.gd): three to five a floor, spread over its
## plantas, each against a wall with room in front; a cup brings the mind back
## whole a few seconds on, says so at the foot of the picture, and a machine
## serves each survivor once.
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func card_words(level) -> Array:
	var words: Array = []
	if level.ui.controls_card == null or not level.ui.controls_up: return words
	for line in level.ui.controls_card.get_children():
		if not line.is_queued_for_deletion(): words.append(String(line.get_child(line.get_child_count() - 1).text))
	return words

func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "none"
	await level.start_floor(7, false, [1], "apacible", 1)
	var machines: Array = level.coffee.machines
	var wings := {}
	for machine in machines: wings[int(level.FLOOR.room_at(level.manifest.rooms, machine.global_position).get("wing", -1))] = true
	check("El hotel tiene de 3 a 5 máquinas", machines.size() >= 3 and machines.size() <= 5, str(machines.size()))
	check("Repartidas por las plantas", wings.size() >= mini(3, machines.size()) and not wings.has(-1), str(wings.keys()))
	var start_room := int(level.manifest.start)
	check("Una en la sala donde se empieza", machines.any(func(machine): return int(level.FLOOR.room_at(level.manifest.rooms, machine.global_position).get("id", -1)) == start_room))
	var machine = machines[0]
	check("Se puede tomar un café", level.coffee.can_drink(machine))
	level.player.sanity = 20.0
	level.coffee.drink(machine)
	check("Una vez por superviviente y máquina", not level.coffee.can_drink(machine))
	for frame in int(level.coffee.BREW * 60.0) + 6: await physics_frame
	check("A los segundos: «Te sientes mejor...» abajo", card_words(level) == [level.coffee.FEEL], str(card_words(level)))
	check("Y la cordura sube a lo largo de un segundo", level.player.sanity > 20.0 and level.player.sanity < 100.0, "%.1f" % level.player.sanity)
	for frame in int(level.coffee.EASE * 60.0) + 6: await physics_frame
	check("Y vuelve entera", level.player.sanity >= 99.9, "%.1f" % level.player.sanity)
	level.settings.values.control_hints = false
	level.coffee.brewing = level.coffee.BREW
	for frame in int(level.coffee.BREW * 60.0) + 6: await physics_frame
	check("El aviso sale aunque las sugerencias estén apagadas", card_words(level) == [level.coffee.FEEL], str(card_words(level)))
	level.settings.values.control_hints = true
	await level.start_floor(7, false, [1], "apacible", 2)
	var office: Array = level.coffee.machines
	check("El piso 2 tiene de 3 a 5", office.size() >= 3 and office.size() <= 5, str(office.size()))
	var palette = level.FLOOR.palette(level.manifest)
	check("Alguna en una sala de descanso", office.any(func(one): return int(level.FLOOR.room_at(level.manifest.rooms, one.global_position).get("type", -1)) == palette.BREAK_ROOM))
	print("COFFEE_TEST_RESULT %d fallos" % failed)
	quit(1 if failed > 0 else 0)
