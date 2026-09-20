extends SceneTree
## A floor is three chained stages, not one errand: closing one carries into
## the next and only the last one ends the floor. This drives a real floor from
## the refuge, the way a player does, and checks what the session does with it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const TV := preload("res://game/world/generation/tv_placement.gd")
const DIG := preload("res://game/world/generation/digit_placement.gd")
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title)

func frames(count: int) -> void:
	for i in count: await physics_frame

## Walks into the refuge of the stage in hand, waits for the door on to
## unlock and steps through it, which is what closes a stage now.
func cross_to_stage(stage: int, seconds := 12.0) -> bool:
	var session = level.session
	var left := seconds
	var gate: Dictionary = level.manifest.gates[session.stage - 1]
	while left > 0.0:
		if session.stage >= stage and session.state == session.State.PLAYING: return true
		if session.goal.get("ready", false) and int(gate.get("beyond", -1)) >= 0:
			# Through the door: one step into the wing beyond.
			level.player.global_position = FLOOR.position_of(level.manifest.rooms[int(gate.beyond)]) + Vector3(0, 0.04, 0)
		else:
			level.player.global_position = FLOOR.position_of(level.manifest.rooms[level.refuge_room()]) + Vector3(0, 0.04, 0)
		level.player.velocity = Vector3.ZERO
		await physics_frame
		left -= 1.0 / 60.0
	return false

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	var session = level.session
	level.locust.set_physics_process(false)
	level.locust.global_position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	check("Un piso empieza en la etapa 1", session.stage == 1 and session.STAGES == 3)
	check("Y su condición es la del refugio", session.goal.kind == "refuge")
	# Wings and gates: one door on, shut and locked until its stage is closed.
	check("Tres alas, tres refugios y tres puertas de etapa", level.manifest.wings == 3 and level.manifest.refuges.size() == 3 and level.manifest.gates.size() == 3)
	check("Cada refugio está en su ala", level.manifest.refuges.all(func(id): return int(level.manifest.rooms[int(id)].wing) == level.manifest.refuges.find(id)))
	check("El refugio de la etapa 1 es la sala de su puerta", level.refuge_room() == int(level.manifest.gates[0].room))
	var gate = level.hotel.gates[0]
	check("La puerta a la segunda ala empieza cerrada con llave", level.hotel.gates.size() == 3 and gate.locked and not gate.opened)
	check("Y no se abre por mucho que se insista", not gate.toggle() and not gate.opened)
	check("Nada que mantener: la condición es estar dentro con la cuota", not session.goal.ready)
	check("La criatura empieza en la primera ala", int(level.manifest.rooms[level.locust.patrol_room].wing) == 0)
	# Outside the refuge the hold counts for nothing.
	level.player.global_position = Vector3(0, 0.04, 0)
	for i in 240: await physics_frame
	check("Fuera del refugio la puerta sigue cerrada", session.stage == 1 and not session.goal.ready and gate.locked)
	check("Cerrar la etapa 1 no termina el piso", await cross_to_stage(2))
	check("Sigue jugándose, en la etapa 2", session.state == session.State.PLAYING and session.stage == 2)
	check("La puerta de la etapa cumplida queda abierta", not gate.locked and gate.opened)
	check("El refugio pasa a ser el de la etapa nueva", level.refuge_room() == int(level.manifest.gates[1].room) and level.refuge_room() != int(level.manifest.gates[0].room))
	check("Y el anterior deja de proteger", not level.point_in_refuge(FLOOR.position_of(level.manifest.rooms[int(level.manifest.gates[0].room)])))
	check("La criatura se va detrás de los jugadores al ala nueva", int(level.manifest.rooms[level.locust.patrol_room].wing) == 1)
	check("La puerta de la tercera ala sigue cerrada", level.hotel.gates[1].locked)
	# Second stage: the sets of that wing, and it asks for as many as there
	# are survivors, with two spare.
	# A few frames for the authority to look at the new stage.
	await frames(5)
	var needed: int = TV.needed(session.roster_count)
	check("La etapa 2 se juega con televisores", session.goal.kind == "televisions" and session.goal.needed == needed)
	check("Hay dos teles de más y todas en el ala nueva", level.televisions.size() == needed + TV.SPARE and level.televisions.all(func(set): return int(FLOOR.room_at(level.manifest.rooms, set.global_position).get("wing", -1)) == 1))
	check("Ninguna está encendida al empezar la etapa", level.televisions_on() == 0 and not session.goal.ready)
	# Switching them on one by one: only the last one opens the door.
	for index in needed:
		level.switch_television(level.televisions[index])
		await frames(4)
		if index < needed - 1: check("Con %d de %d encendidas la puerta sigue cerrada" % [index + 1, needed], not session.goal.ready and level.hotel.gates[1].locked)
	await frames(6)
	check("Encendidas las que pide, se abre la puerta de la etapa", session.goal.ready and session.goal.done >= needed and not level.hotel.gates[1].locked)
	check("Una tele encendida da luz y no se apaga", level.televisions[0].on and level.televisions[0].lamp.visible and not level.televisions[0].set_on(true))
	# Travelling by television: a lit set is a way in and a way out.
	var lit: Array = level.lit_televisions()
	check("Las teles encendidas son las que aparecen en su mapa", lit.size() == needed)
	level.locust.global_position = level.televisions[lit[0]].global_position + Vector3(1.0, 0.04, 0)
	await frames(2)
	check("La criatura reconoce la tele en la que está", level.creature_at_television() == lit[0])
	var before: Vector3 = level.locust.global_position
	level.warp_creature(lit[1])
	check("Sale por otra tele encendida, lejos de donde estaba", level.locust.global_position.distance_to(before) > 5.0 and level.creature_at_television() == lit[1])
	var dark := -1
	for index in level.televisions.size():
		if not level.televisions[index].on: dark = index
	var standing: Vector3 = level.locust.global_position
	if dark >= 0: level.warp_creature(dark)
	check("Y no puede salir por una apagada", dark < 0 or level.locust.global_position.is_equal_approx(standing))
	check("Sin pantalla de fin de piso por el medio", level.ui.screen != "transition" and level.ui.screen != "won")
	check("Cerrar la etapa 2 lleva a la 3", await cross_to_stage(3))
	await frames(5)
	# Third stage: four numbers hidden in drawers and shelves of its wing.
	var hidden: Array = level.containers.filter(func(piece): return piece.digit >= 0)
	check("Hay cuatro números escondidos", hidden.size() == DIG.COUNT)
	check("Todos en el ala de la última etapa", hidden.all(func(piece): return int(FLOOR.room_at(level.manifest.rooms, piece.global_position).get("wing", -1)) == 2))
	check("Cada uno en una sala distinta", hidden.map(func(piece): return int(FLOOR.room_at(level.manifest.rooms, piece.global_position).id)).size() == hidden.size())
	check("Y cada uno ocupa su lugar del código", hidden.map(func(piece): return piece.slot).duplicate().size() == DIG.COUNT and hidden.all(func(piece): return piece.slot >= 1 and piece.slot <= DIG.COUNT))
	check("El código no se sabe hasta registrar", level.code_so_far() == "––––")
	var muebles: int = level.containers.size()
	check("Se puede registrar cualquier mueble con cajones", muebles > 100 and level.containers.all(func(piece): return not piece.searched))
	for piece in hidden:
		level.search_container(piece)
		await frames(2)
	check("Registrar los cuatro da el código entero", level.found_digits.size() == DIG.COUNT and not level.code_so_far().contains("–"))
	check("Un mueble registrado no se vuelve a registrar", hidden[0].searched and not hidden[0].set_searched(true))
	check("El código es el mismo que el del piso", level.code_so_far() == "".join(DIG.code(level.manifest).map(func(d): return str(d))))
	# The last door: shut until the code is read into it, and the floor ends
	# on the landing behind it.
	var exit_door = level.hotel.gates[2]
	check("La última puerta está cerrada con código", exit_door.locked and not exit_door.opened and is_instance_valid(level.lock))
	check("Y el piso no termina por estar en el refugio", not session.goal.ready)
	level.typed = "".join(DIG.code(level.manifest).map(func(d): return str(d)))
	level.match_net.use_code()
	await frames(4)
	check("Con el código puesto la puerta se abre", level.code_entered and not exit_door.locked)
	var won := false
	for i in 300:
		level.player.global_position = level.hotel.landings[0] + Vector3(0, 0.1, 0)
		await physics_frame
		if session.state == session.State.WON:
			won = true
			break
	check("Salir por esa puerta termina el piso", won and session.stage == 3)
	check("Y entonces sale la pantalla de fin", level.ui.screen == "won")
	# A floor started again begins at the first stage.
	await level.start_floor(81)
	check("Un piso nuevo vuelve a la etapa 1", level.session.stage == 1 and level.session.state == level.session.State.PLAYING)
	var file := FileAccess.open("res://evidence/stages_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("STAGES_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
