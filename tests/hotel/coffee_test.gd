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

## Every machine LIFT_CLEAR or more from the doors of each lift in its room.
func clear_of_lifts(level, machines: Array) -> bool:
	return machines.all(func(one): return level.coffee.lift_fronts(level.FLOOR.room_at(level.manifest.rooms, one.global_position)).all(func(lift: Vector3): return Vector2(lift.x - one.global_position.x, lift.z - one.global_position.z).length() >= level.coffee.LIFT_CLEAR))

## How far each machine's side stands from the wall beside it, along its own
## wall (the author, 17 November 2026: tucked into a corner).
func corner_gaps(level, machines: Array) -> Array:
	return machines.map(func(one) -> float:
		var room: Dictionary = level.FLOOR.room_at(level.manifest.rooms, one.global_position)
		var local: Vector3 = one.global_position - level.FLOOR.position_of(room)
		var along: Vector3 = one.global_basis.x.normalized()
		var half: Vector2 = level.FLOOR.size_of(room) * 0.5
		var length: float = half.y if absf(along.z) > 0.5 else half.x
		return snappedf(length - 0.09 - absf(local.dot(along)) - level.coffee.HALF.x, 0.01))

## The machines more than 0.4 m off a corner whose room had a corner free for
## them all the same (coffee.spot_at(), the machine itself left out): mid wall
## only where no corner takes one.
func corner_skipped(level, machines: Array) -> Array:
	var gaps := corner_gaps(level, machines)
	var bad: Array = []
	for k in machines.size():
		if float(gaps[k]) <= 0.4: continue
		var room: Dictionary = level.FLOOR.room_at(level.manifest.rooms, machines[k].global_position)
		for corner: Array in level.coffee.corners(room):
			if not level.coffee.spot_at(room, int(corner[0]), float(corner[1]), machines[k]).is_empty(): bad.append("%s sala %d" % [machines[k].name, int(room.id)])
	return bad

## Each machine and what hangs on its own wall lower than its top (pictures,
## boards, signs, switches, sockets), in plan: those that overlap.
func over_hung(level, machines: Array) -> Array:
	var bad: Array = []
	for one in machines:
		var out: Vector3 = -one.global_basis.z.normalized()
		var along: Vector3 = one.global_basis.x.normalized()
		var at: Vector3 = one.global_position
		for entry: Array in level.hotel.hung:
			var a: Vector3 = entry[0]
			var b: Vector3 = entry[1]
			if float(entry[2]) > at.y + level.coffee.MACHINE.SIZE.y: continue
			var depth: float = ((a + b) * 0.5 - at).dot(out)
			if absf(a.y - at.y) > 1.0 or depth < 0.0 or depth > 0.6: continue
			var ua: float = (a - at).dot(along)
			var ub: float = (b - at).dot(along)
			if minf(ua, ub) < level.coffee.MACHINE.SIZE.x * 0.5 and maxf(ua, ub) > -level.coffee.MACHINE.SIZE.x * 0.5: bad.append("%s %.2f..%.2f" % [one.name, minf(ua, ub), maxf(ua, ub)])
	return bad

## The nearest of the floor's upright runs (coffee.drops()) to any machine, in
## plan from its footprint, metres; INF with none.
func nearest_drop(level, machines: Array) -> float:
	var least := INF
	for one in machines:
		for drop: Vector3 in level.coffee.drops(level.manifest):
			if absf(drop.y - one.global_position.y) > 2.5: continue
			var d: Vector3 = drop - one.global_position
			var gap := Vector2(maxf(absf(d.dot(one.global_basis.x.normalized())) - level.coffee.MACHINE.SIZE.x * 0.5, 0.0), maxf(absf(d.dot(one.global_basis.z.normalized())) - level.coffee.MACHINE.SIZE.z * 0.5, 0.0)).length()
			least = minf(least, gap)
	return least

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
	check("Ninguna delante de un ascensor", clear_of_lifts(level, machines))
	check("Lo que cuelga de las paredes del hotel está anotado", level.hotel.hung.size() > 50, str(level.hotel.hung.size()))
	var gaps := corner_gaps(level, machines)
	check("Cada una en un rincón, a 0,4 m o menos de la pared de al lado", gaps.all(func(g: float): return g <= 0.4), str(gaps))
	check("A media pared, ninguna que tuviera un rincón libre en su sala", corner_skipped(level, machines).is_empty(), str(corner_skipped(level, machines)))
	check("Ninguna tapa en planta un cuadro, un cartel, un interruptor ni un enchufe de su pared", over_hung(level, machines).is_empty(), str(over_hung(level, machines)))
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
	# Floor 2 (the author, 18 November 2026): two a planta, one where it is walked
	# into and one far from it and from the planta's landmarks.
	check("El piso 2 tiene dos por planta", office.size() == 6 and range(3).all(func(p: int) -> bool: return office.filter(func(one): return level.FLOOR.planta_of(one.global_position.y) == p).size() == 2), str(office.map(func(one): return level.FLOOR.planta_of(one.global_position.y))))
	var by_door := []
	var far_enough := true
	for p in 3:
		var entry: int = level.FLOOR.entry_of(level.manifest, p)
		var metres: Dictionary = level.FLOOR.route_metres(level.manifest, entry)
		var here: Array = office.filter(func(one): return level.FLOOR.planta_of(one.global_position.y) == p)
		var ways: Array = here.map(func(one): return float(metres.get(int(level.FLOOR.room_at(level.manifest.rooms, one.global_position).get("id", -1)), INF)))
		ways.sort()
		by_door.append(ways)
		# The near one in the way in or the room beside it (the reception's annex is 18 m off its middle); the far one past half the planta's farthest room.
		var farthest: float = metres.values().max()
		if ways.size() < 2 or float(ways[0]) > 20.0 or float(ways[1]) < farthest * 0.5: far_enough = false
	check("En cada planta, una en la llegada y otra lejos de ella", far_enough, str(by_door))
	check("Beber el café dice que te sientes mejor", level.coffee.FELT == "Te sientes mejor...")
	check("Ninguna delante del ascensor de la recepción ni de otro", clear_of_lifts(level, office))
	check("Lo que cuelga de las paredes del piso 2 está anotado", level.hotel.hung.size() > 50, str(level.hotel.hung.size()))
	var office_gaps := corner_gaps(level, office)
	# Floor 2's break rooms have their kitchen and tables in the corners, and the
	# reception's are by its doors or open to its annex: there one goes mid wall.
	check("En el piso 2, la mitad o más en un rincón, a 0,4 m o menos de la pared de al lado", office_gaps.filter(func(g: float): return g <= 0.4).size() * 2 >= office.size(), str(office_gaps))
	check("En el piso 2, a media pared solo la que no tenía ningún rincón libre en su sala", corner_skipped(level, office).is_empty(), str(corner_skipped(level, office)))
	check("En el piso 2, ninguna tapa en planta un cuadro, un cartel, un interruptor ni un enchufe de su pared", over_hung(level, office).is_empty(), str(over_hung(level, office)))
	check("Hay bajadas de tubo en el piso 2, y ninguna máquina a menos de 0,6 m de una", not level.coffee.drops(level.manifest).is_empty() and nearest_drop(level, office) >= 0.6 - 0.001, "%.2f" % nearest_drop(level, office))
	print("COFFEE_TEST_RESULT %d fallos" % failed)
	quit(1 if failed > 0 else 0)
