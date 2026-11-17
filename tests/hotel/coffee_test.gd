extends SceneTree
## The coffee machines (coffee.gd): three to five a floor, spread over its
## plantas, each against a wall with room in front; a cup brings the mind back
## whole a few seconds on, without a word written about it, and a machine
## serves each survivor once.
var failed := 0
## What the foot of the picture said until 16 November 2026.
const FEEL := "Te sientes mejor..."

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
	check("El hotel de un superviviente, el más pequeño, tiene 3 máquinas", machines.size() == 3, str(machines.size()))
	check("Repartidas por las plantas", wings.size() >= mini(3, machines.size()) and not wings.has(-1), str(wings.keys()))
	var start_room := int(level.manifest.start)
	check("Una en la sala donde se empieza", machines.any(func(machine): return int(level.FLOOR.room_at(level.manifest.rooms, machine.global_position).get("id", -1)) == start_room))
	var machine = machines[0]
	check("Se puede tomar un café", level.coffee.can_drink(machine))
	# Stood in front of it and looking at it, the look finds the machine (it
	# found its solid body, and no cup could be had).
	var map: RID = level.get_world_3d().navigation_map
	level.player.global_position = NavigationServer3D.map_get_closest_point(map, machine.global_position + machine.global_basis.z * 1.2) + Vector3(0, 0.04, 0)
	for frame in 5: await physics_frame
	var eye: Vector3 = level.player.camera.global_position
	var target: Vector3 = machine.global_position + Vector3(0, 1.2, 0)
	var flat := Vector3(target.x - eye.x, 0, target.z - eye.z)
	level.player.rotation.y = atan2(-flat.x, -flat.z)
	level.player.camera.rotation.x = atan2(target.y - eye.y, flat.length())
	for frame in 3: await physics_frame
	check("Mirándola de frente, la mirada da con la máquina", level.interaction.focused_area() == machine, str(level.interaction.focused_area()))
	var lamps: Array = Array(level.hotel.sconce_spots)
	check("Ninguna tapa un aplique ni el cuadro entre dos", machines.all(func(one): return lamps.all(func(lamp: Vector3): return Vector2(lamp.x - one.global_position.x, lamp.z - one.global_position.z).length() >= level.coffee.LAMP_CLEAR or absf(lamp.y - one.global_position.y) >= 3.0)))
	level.player.sanity = 20.0
	level.coffee.drink(machine)
	check("Una vez por superviviente y máquina", not level.coffee.can_drink(machine))
	for frame in int(level.coffee.BREW * 60.0) + 6: await physics_frame
	check("A los segundos no se escribe «Te sientes mejor...»: lo dice la imagen", not card_words(level).has(FEEL), str(card_words(level)))
	check("Y la cordura sube a lo largo de un segundo", level.player.sanity > 20.0 and level.player.sanity < 100.0, "%.1f" % level.player.sanity)
	for frame in int(level.coffee.EASE * 60.0) + 6: await physics_frame
	check("Y vuelve entera", level.player.sanity >= 99.9, "%.1f" % level.player.sanity)
	level.settings.values.control_hints = false
	level.coffee.brewing = level.coffee.BREW
	for frame in int(level.coffee.BREW * 60.0) + 6: await physics_frame
	check("Ni con las sugerencias apagadas", not card_words(level).has(FEEL), str(card_words(level)))
	level.settings.values.control_hints = true
	await level.start_floor(7, false, [1, 2, 3, 4, 5], "apacible", 2)
	var office: Array = level.coffee.machines
	check("El piso 2 de cinco supervivientes, el más grande, tiene 5", office.size() == 5, str(office.size()))
	var palette = level.FLOOR.palette(level.manifest)
	check("Alguna en una sala de descanso", office.any(func(one): return int(level.FLOOR.room_at(level.manifest.rooms, one.global_position).get("type", -1)) == palette.BREAK_ROOM))
	print("COFFEE_TEST_RESULT %d fallos" % failed)
	quit(1 if failed > 0 else 0)
