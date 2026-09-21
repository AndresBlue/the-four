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
## unlock and steps into the lift behind it, which is what closes a stage now.
func cross_to_stage(stage: int, seconds := 12.0) -> bool:
	var session = level.session
	var left := seconds
	var car: Vector3 = level.hotel.lifts[session.stage - 1]
	while left > 0.0:
		if session.stage >= stage and session.state == session.State.PLAYING: return true
		# Once the lift has them, it is carrying them: pushing the body about
		# from here would undo the ride.
		if not level.boarding.is_empty():
			await physics_frame
			left -= 1.0 / 60.0
			continue
		if session.goal.get("ready", false):
			# Into the car: the lift takes it from there.
			level.player.global_position = car + Vector3(0, 0.04, 0)
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
	# The ride itself: held with no picture for a moment, and then standing in
	# the wing the lift arrives at. Counted by watching it happen, because a
	# busy frame runs several physics ticks at once.
	var blinded := 0.0
	var held_ticks := 0
	for i in 240:
		blinded = maxf(blinded, level.ride_static())
		if level.player.held: held_ticks += 1
		if i > 2 and level.boarding.is_empty(): break
		await physics_frame
	check("El viaje sujeta al jugador y le quita la imagen", held_ticks > 0 and blinded > 0.8)
	var arrival: Dictionary = level.manifest.rooms[int(level.manifest.gates[0].arrive)]
	# It comes out in the wing the lift serves. Where exactly is the session's
	# business: closing a stage puts everybody on their feet at the way in.
	var landed: Dictionary = FLOOR.room_at(level.manifest.rooms, level.player.global_position)
	check("Y le deja en el ala que abre ese ascensor", not level.player.held and int(landed.get("wing", -1)) == int(arrival.wing))
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
	var wing_of := func(index: int) -> int: return int(FLOOR.room_at(level.manifest.rooms, level.televisions[index].global_position).get("wing", -1))
	var sets_two: Array = level.stage_televisions(2)
	var sets_three: Array = level.stage_televisions(3)
	check("La etapa 2 se juega con televisores", session.goal.kind == "televisions" and session.goal.needed == needed)
	check("Cada etapa tiene su tanda, con dos de más, en su ala", sets_two.size() == needed + TV.SPARE and sets_three.size() == needed + TV.SPARE and sets_two.all(func(i): return wing_of.call(i) == 1) and sets_three.all(func(i): return wing_of.call(i) == 2))
	check("Ninguna está encendida al empezar la etapa", level.televisions_on() == 0 and not session.goal.ready)
	# The tally is the wing's own: a set burning in the wing ahead is not this
	# stage's business, and lighting one here says nothing about the next.
	level.apply_television(int(sets_three[0]), true)
	await frames(2)
	check("Una tele del ala siguiente no cuenta en esta etapa", level.televisions_on() == 0 and not session.goal.ready)
	level.apply_television(int(sets_three[0]), false)
	await frames(2)
	# Switching them on one by one: only the last one opens the door.
	for step in needed:
		level.switch_television(level.televisions[int(sets_two[step])])
		await frames(4)
		if step < needed - 1: check("Con %d de %d encendidas la puerta sigue cerrada" % [step + 1, needed], not session.goal.ready and level.hotel.gates[1].locked)
	await frames(6)
	check("Encendidas las que pide, se abre la puerta de la etapa", session.goal.ready and session.goal.done >= needed and not level.hotel.gates[1].locked)
	# The blackout: it fell when only the last set was left. It belongs to this
	# wing, and it is given back at the lift.
	check("Se fue la luz del piso entero", session.goal.get("blackout", false) and level.hotel.dark)
	check("Ninguna lámpara del hotel queda encendida", level.hotel.lights.all(func(light): return not light.visible) and level.hotel.practicals.all(func(lamp): return not lamp.visible) and level.hotel.sconce_lights.all(func(lamp): return not lamp.visible))
	check("Las teles encendidas siguen dando luz", level.televisions[0].lamp.visible)
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
	for index in sets_two:
		if not level.televisions[int(index)].on: dark = int(index)
	var standing: Vector3 = level.locust.global_position
	if dark >= 0: level.warp_creature(dark)
	check("Y no puede salir por una apagada", dark < 0 or level.locust.global_position.is_equal_approx(standing))
	check("Sin pantalla de fin de piso por el medio", level.ui.screen != "transition" and level.ui.screen != "won")
	check("Cerrar la etapa 2 lleva a la 3", await cross_to_stage(3))
	await frames(5)
	# The power that went belonged to the wing left behind: this one is found
	# lit, with no lamp still marked out by the cut.
	check("Al pasar de ala vuelve la corriente", not level.hotel.dark and not session.goal.get("blackout", false))
	check("Y ninguna lámpara queda apagada por el corte", level.hotel.lights.filter(func(light): return light.has_meta("off")).size() == level.hotel.dark_ids.size())
	# Stood in a room of the new wing that is not one of the dark ones: its
	# ceiling lamp is lit again. (Asking whether any lamp anywhere is visible
	# depended on where the lift happened to leave the body.)
	var lamp_room := -1
	for room in level.manifest.rooms:
		if int(room.wing) == 2 and not level.hotel.dark_ids.has(int(room.id)) and not bool(room.get("landing", false)) and int(room.id) != int(level.manifest.refuges[2]):
			lamp_room = int(room.id)
			break
	if lamp_room >= 0: level.hotel.update_visibility(FLOOR.position_of(level.manifest.rooms[lamp_room]), true)
	check("Las lámparas del ala nueva alumbran otra vez", lamp_room >= 0 and level.hotel.lights[lamp_room].visible)
	check("La etapa 3 tiene su propia tanda de teles, apagadas", level.stage_televisions().size() == needed + TV.SPARE and level.televisions_on() == 0)
	# Third stage: four numbers hidden in drawers and shelves of its wing.
	var hidden: Array = level.containers.filter(func(piece): return piece.digit >= 0)
	check("Hay cuatro números escondidos", hidden.size() == DIG.COUNT)
	check("Todos en el ala de la última etapa", hidden.all(func(piece): return int(FLOOR.room_at(level.manifest.rooms, piece.global_position).get("wing", -1)) == 2))
	check("Cada uno en una sala distinta", hidden.map(func(piece): return int(FLOOR.room_at(level.manifest.rooms, piece.global_position).id)).size() == hidden.size())
	check("Y cada uno ocupa su lugar del código", hidden.map(func(piece): return piece.slot).duplicate().size() == DIG.COUNT and hidden.all(func(piece): return piece.slot >= 1 and piece.slot <= DIG.COUNT))
	check("El código no se sabe hasta registrar", level.code_so_far() == "––––" and level.noted_code().is_empty())
	# Four pieces among more than two hundred: what says which four is a slip
	# of paper left showing on them.
	check("Los cuatro lo enseñan con una nota", hidden.all(func(piece): return is_instance_valid(piece.note)))
	check("Y ningún otro mueble la lleva", level.containers.filter(func(piece): return is_instance_valid(piece.note)).size() == DIG.COUNT)
	var muebles: int = level.containers.size()
	check("Se puede registrar cualquier mueble con cajones", muebles > 100 and level.containers.all(func(piece): return not piece.searched))
	for piece in hidden:
		level.search_container(piece)
		await frames(2)
	check("Registrar los cuatro da el código entero", level.found_digits.size() == DIG.COUNT and not level.code_so_far().contains("–"))
	check("Quien registra se lleva la nota", hidden.all(func(piece): return not is_instance_valid(piece.note)))
	check("Y los números quedan escritos en la cinta", level.camcorder.code_note.text.contains(level.code_so_far()))
	check("Un mueble registrado no se vuelve a registrar", hidden[0].searched and not hidden[0].set_searched(true))
	check("El código es el mismo que el del piso", level.code_so_far() == "".join(DIG.code(level.manifest).map(func(d): return str(d))))
	# Alone there is nothing to forgive: caught is the end of that floor.
	var before_stage: int = session.stage
	check("En solitario, que te cojan termina el piso", session.capture(1) and session.state == session.State.FAILED and session.restarts == 0)
	await frames(10)
	# With a team it is another matter: the floor gives the stage back once.
	session.set_state(session.State.PLAYING)
	session.participants = {1: session.Life.EXPLORING, 2: session.Life.EXPLORING}
	session.roster_count = 2
	# One set lit in this wing takes its power, the way it does in the second.
	var third_sets: Array = level.stage_televisions()
	level.switch_television(level.televisions[int(third_sets[0])])
	await frames(8)
	check("La tercera ala tiene su propio apagón", session.goal.get("blackout", false) and level.hotel.dark)
	check("Con equipo, perder a uno no hunde el piso", session.capture(2) and session.state == session.State.PLAYING and session.restart_wait <= 0.0)
	check("Caer los dos se perdona una vez", session.capture(1) and session.state == session.State.PLAYING)
	# It takes a moment: the death is seen and heard before anybody gets up.
	check("La muerte se cuenta antes de levantar a nadie", session.participants[1] == session.Life.DEAD and session.restart_wait > 0.0)
	await frames(int(session.RESTART_WAIT * 60) + 20)
	check("Vuelven todos de pie, en la misma etapa", session.participants[1] == session.Life.EXPLORING and session.stage == before_stage and session.restarts == 1)
	check("Y el jugador recupera su cuerpo y su cámara", level.player.visible and level.player.collision_layer == 4 and level.player.camera.current)
	# The stage is given back whole: its sets out and its power on.
	check("Una etapa devuelta empieza con la luz otra vez", level.televisions_on() == 0 and not level.hotel.dark and not session.goal.get("blackout", false))
	session.capture(2)
	check("La segunda vez sí se acaba", session.capture(1) and session.state == session.State.FAILED)
	await frames(10)
	# Back to a floor in hand for the rest of the checks.
	await level.start_floor(81)
	session = level.session
	level.locust.set_physics_process(false)
	level.locust.global_position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	check("Un piso nuevo perdona otra vez", session.restarts == 0)
	# Straight to the last stage: the numbers and the door are the point here.
	session.stage = 3
	session.goal = {"kind": "code", "done": 0, "needed": 4, "ready": false}
	await frames(4)
	# The last door: shut until the code is read into it, and the floor ends
	# on the landing behind it.
	var exit_door = level.hotel.gates[2]
	check("La última puerta está cerrada con código", exit_door.locked and not exit_door.opened and is_instance_valid(level.lock))
	check("Y el piso no termina por estar en el refugio", not session.goal.ready)
	# The last stage asks for two things: its wing's sets lit and the code. The
	# right code typed into a dark wing says so instead of opening nothing.
	var right: String = "".join(DIG.code(level.manifest).map(func(d): return str(d)))
	var third: Array = level.stage_televisions()
	level.open_lock()
	for character in right: level.type_code(character)
	await frames(4)
	check("Con las teles del ala apagadas, el código no abre", not level.code_entered and exit_door.locked)
	level.close_lock()
	for step in TV.needed(session.roster_count):
		level.switch_television(level.televisions[int(third[step])])
		await frames(3)
	check("Encender la tanda del ala no basta por sí sola", not session.goal.ready and exit_door.locked)
	level.open_lock()
	for character in right: level.type_code(character)
	await frames(4)
	check("Con el código puesto la puerta se abre", level.code_entered and not exit_door.locked)
	var won := false
	for i in 300:
		level.player.global_position = level.hotel.lifts[level.hotel.lifts.size() - 1] + Vector3(0, 0.1, 0)
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
