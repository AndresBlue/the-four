extends SceneTree
## A floor is three chained stages, not one errand: closing one carries into
## the next and only the last one ends the floor. This drives a real floor from
## the refuge, the way a player does, and checks what the session does with it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const TV := preload("res://game/world/generation/tv_placement.gd")
const PROPS := preload("res://game/world/hotel/prop_factory.gd")
const DIG := preload("res://game/world/generation/digit_placement.gd")
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title)

## How many containers have a place for a note, and on how many the fold
## touches the piece's mesh (within 2 cm): the models are given a collider of
## their own triangles, just for this, where the floor stands them.
func notes_resting() -> Array:
	var placed := 0
	var resting := 0
	var bodies: Array = []
	var shapes := {}
	for piece in level.containers:
		var spot: Dictionary = piece.note_spot
		if spot.is_empty() or not spot.has("model"): continue
		placed += 1
		if not shapes.has(spot.model): shapes[spot.model] = load("res://assets/props/hotel/%s.res" % spot.model).create_trimesh_shape()
		var body := StaticBody3D.new()
		body.collision_layer = 1 << 19
		var shape := CollisionShape3D.new()
		shape.shape = shapes[spot.model]
		body.add_child(shape)
		root.add_child(body)
		body.global_transform = piece.global_transform * (spot.piece as Transform3D)
		bodies.append([body, piece])
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.02
	for pair in bodies:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = probe
		query.collision_mask = 1 << 19
		query.transform = Transform3D(Basis.IDENTITY, pair[1].global_transform * (pair[1].note_spot.at as Vector3))
		if space.intersect_shape(query, 8).any(func(hit): return hit.collider == pair[0]): resting += 1
	for pair in bodies: pair[0].queue_free()
	return [placed, resting]

## Whether a searched piece shows it (hotel_container.show_searched): its
## part out where it opens to, or one of its things moved.
func moved_out(piece) -> bool:
	var left: Dictionary = piece.left
	if left.has("node"): return (left.node as Node3D).transform.is_equal_approx(left.open) and not (left.open as Transform3D).is_equal_approx(left.closed)
	if left.has("thing"): return not (left.to as Transform3D).is_equal_approx(left.from) and piece.things.has(left.thing)
	return false

## Whether a click of the creature's (echo_view.RAY_MASK), sent at what a
## searched piece left open from a little in front of it, comes back from it.
func echo_found(piece) -> bool:
	var echoes: Array = piece.shown.filter(func(node): return node is StaticBody3D)
	if echoes.is_empty(): return false
	var echo: Node3D = echoes[0]
	var front: Vector3 = piece.global_transform.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(echo.global_position + front * 1.2, echo.global_position, preload("res://game/enemies/locust/echo_view.gd").RAY_MASK)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == echo

func frames(count: int) -> void:
	for i in count: await physics_frame

## Every piece of text under a node, which is how a screen is read back.
func words_under(node: Node) -> String:
	var found := ""
	var stack: Array = [node]
	while not stack.is_empty():
		var next: Node = stack.pop_back()
		if next is Label: found += (next as Label).text + " · "
		stack.append_array(next.get_children())
	return found

## How many surfaces of the hotel are still giving off light of their own:
## the domes and the shades and the battens (materials of this floor), the
## exit signs (a shader) and the wall lamps (the glow is inside the model, so
## it is put out with an override). A lamp that stops lighting the room but
## keeps glowing is the only thing left visible in a room nothing else lights.
func glowing() -> int:
	var count := 0
	for material in level.hotel.held_glows():
		if material.emission_energy_multiplier > 0.0: count += 1
	for sconce in level.hotel.lit_sconces:
		for surface in sconce.mesh.get_surface_count():
			var shade := sconce.mesh.surface_get_material(surface) as BaseMaterial3D
			if shade != null and shade.emission_enabled and sconce.get_surface_override_material(surface) == null: count += 1
	return count

## Walks into the refuge of the stage in hand, waits for the door on to
## unlock and steps into the lift behind it, which is what closes a stage now.
var waited_in_car := false
var car_waits := false
func cross_to_stage(stage: int, seconds := 12.0) -> bool:
	var session = level.session
	var left := seconds
	var car: Vector3 = level.hotel.lifts[session.stage - 1]
	while left > 0.0:
		if session.stage >= stage and session.state == session.State.PLAYING: return true
		# Once the lift has them, it is carrying them: pushing the body about
		# from here would undo the ride.
		if not level.lifts.boarding.is_empty():
			await physics_frame
			left -= 1.0 / 60.0
			continue
		if session.goal.get("ready", false):
			# Into the car, and the button: the lift takes it from there. The
			# first time, it stands in it a moment first -- a car no longer
			# leaves with whoever steps in.
			level.player.global_position = car + Vector3(0, 0.04, 0)
			if not waited_in_car:
				waited_in_car = true
				var stage_before: int = session.stage
				for i in 40: await physics_frame
				car_waits = session.stage == stage_before and level.lifts.boarding.is_empty()
			level.match_net.call_lift(session.stage - 1)
		else:
			level.player.global_position = FLOOR.position_of(level.manifest.rooms[level.refuge_room()]) + Vector3(0, 0.04, 0)
		level.player.velocity = Vector3.ZERO
		await physics_frame
		left -= 1.0 / 60.0
	return false

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	# The board is written to disk and outlives a run: this one starts empty,
	# or what it counts would be whatever the last run left there.
	level.records.runs.clear()
	level.records.career = {}
	level.records.milestones = {}
	level.records.save()
	await level.start_floor(81)
	var session = level.session
	level.locust.set_physics_process(false)
	# Out of the way, where it was born: deep in the first wing, on its planta.
	# (Parked under the floor, as it used to be, it would be on no planta and in
	# no wing at all, now that there are three of them stacked.)
	var den: Vector3 = level.locust.global_position
	level.player.set_physics_process(false)
	check("Un piso empieza en la etapa 1", session.stage == 1 and session.STAGES == 3)
	check("Y su condición es la del refugio", session.goal.kind == "refuge")
	# Every car opens on to its lobby. On this seed two of them backed on to
	# a +X or +Z wall and were built the other way round: a shut box with the
	# mirror to the room, which nobody could walk into.
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var open_cars := 0
	for index in level.hotel.lifts.size():
		var car: Vector3 = level.hotel.lifts[index]
		var lobby: Vector3 = FLOOR.position_of(level.manifest.rooms[int(level.manifest.gates[index].beyond)])
		var front: Vector3 = Vector3(lobby.x - car.x, 0, lobby.z - car.z).normalized()
		var out := PhysicsRayQueryParameters3D.create(car + Vector3.UP, car + Vector3.UP + front * 1.4, 1)
		if space.intersect_ray(out).is_empty(): open_cars += 1
	check("Todos los coches se abren hacia su vestíbulo", open_cars == level.hotel.lifts.size())
	# The last door finds its own collision shape, to know who stands in it.
	check("La última puerta encuentra su colisión", level.hotel.gates[level.hotel.gates.size() - 1].get_node_or_null("CollisionShape3D") != null)
	# Every piece with drawers is found by looking at its front, the way the
	# hand finds it (hotel_main.focused_area): past the furniture's own box.
	await frames(3)
	var searchable := 0
	for piece in level.containers:
		var ahead: Vector3 = piece.global_transform * Vector3(0, 0.6, 1.4)
		var look := PhysicsRayQueryParameters3D.create(ahead, piece.global_transform * Vector3(0, 0.6, -0.2), 1 | 8 | 16)
		look.collide_with_areas = true
		# Past any other target standing in front of it (a wardrobe, a set).
		for attempt in 4:
			var met: Dictionary = space.intersect_ray(look)
			if met.is_empty(): break
			if met.collider == piece:
				searchable += 1
				break
			look.exclude = look.exclude + [met.rid]
	check("Cada mueble con cajones se registra mirándolo de frente", searchable == level.containers.size())
	# Every piece's note would sit on the piece and not in the air beside it:
	# its fold touches the model's own mesh, set where the dressing set it.
	var resting: Array = await notes_resting()
	check("Cada mueble sabe dónde dejar su nota", resting[0] == level.containers.size())
	check("Y la nota se apoya en el mueble, no flota", resting[1] == level.containers.size())
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
	check("El coche no sale solo: espera a que alguien pulse el botón", car_waits)
	check("Sigue jugándose, en la etapa 2", session.state == session.State.PLAYING and session.stage == 2)
	# The ride itself: held with no picture for a moment, and then standing in
	# the wing the lift arrives at. Counted by watching it happen, because a
	# busy frame runs several physics ticks at once.
	var blinded := 0.0
	var held_ticks := 0
	var card := ""
	var doors_seen := false
	# The ride is as long as its recordings: the doors, the car going down,
	# the bell and the doors down there (lifts.RIDE_TIME, 8.5 s).
	for i in 700:
		blinded = maxf(blinded, level.lifts.ride_static())
		# Seen shutting before the picture goes.
		if level.lifts.ride_static() == 0.0 and float(level.lifts.door_state.get(0, 1.0)) < 0.5 and not level.lifts.boarding.is_empty(): doors_seen = true
		if level.player.held: held_ticks += 1
		# The cut itself: what the tape puts up on the black while the car
		# moves, which is the one moment the next stage can be read.
		if is_instance_valid(level.ui.transit) and card.is_empty():
			for node in level.ui.transit.get_child(0).get_children():
				if node is Label: card += node.text + " · "
		if i > 2 and level.lifts.boarding.is_empty(): break
		await physics_frame
	check("El viaje sujeta al jugador y le quita la imagen", held_ticks > 0 and blinded > 0.8)
	check("Y el corte dice a qué sector se va y qué pide, sin repetir la etapa", card.contains("SECTOR 2") and not card.contains("ETAPA") and card.contains(level.lifts.stage_errand(2)))
	check("Al abrirse las puertas la tarjeta ya no está", not is_instance_valid(level.ui.transit))
	check("Las puertas del coche se ven cerrarse antes de que se vaya la imagen", doors_seen)
	check("Y abajo se abren las del coche al que llegan", float(level.lifts.arrival_state.get(0, 0.0)) > 0.5)
	check("El viaje dura lo que su sonido: puertas, bajada, campana y puertas", level.lifts.RIDE_TIME >= 8.0 and level.lifts.RIDE_OPEN > level.lifts.RIDE_BELL)
	# Out of the car, the notice of the sector: what it wants, said whole, for
	# six seconds, and gone the way an analogue set goes off.
	await frames(4)
	check("Al salir del ascensor aparece el objetivo del sector", is_instance_valid(level.ui.brief) and words_under(level.ui.brief).contains(level.lifts.stage_brief(2)) and words_under(level.ui.brief).contains("SECTOR 2"))
	var arrival: Dictionary = level.manifest.rooms[int(level.manifest.gates[0].arrive)]
	# It comes out in the wing the lift serves. Where exactly is the session's
	# business: closing a stage puts everybody on their feet at the way in.
	var landed: Dictionary = FLOOR.room_at(level.manifest.rooms, level.player.global_position)
	check("Y le deja en el ala que abre ese ascensor", not level.player.held and int(landed.get("wing", -1)) == int(arrival.wing))
	check("La puerta de la etapa cumplida queda abierta", not gate.locked and gate.opened)
	check("El refugio pasa a ser el de la etapa nueva", level.refuge_room() == int(level.manifest.gates[1].room) and level.refuge_room() != int(level.manifest.gates[0].room))
	# The creature may walk through the old one now (to its car), but whoever
	# is in it, or in the lobby of that car, is as safe as before.
	var old_refuge := FLOOR.position_of(level.manifest.rooms[int(level.manifest.gates[0].room)]) + Vector3(0, 0.1, 0)
	var old_lobby := FLOOR.position_of(level.manifest.rooms[int(level.manifest.gates[0].beyond)]) + Vector3(0, 0.1, 0)
	check("El anterior deja de ser el refugio de la etapa", not level.point_in_refuge(old_refuge))
	check("Pero él y el vestíbulo de su ascensor siguen protegiendo", level.point_protected(old_refuge) and level.point_protected(old_lobby) and level.point_protected(level.hotel.lifts[0] + Vector3(0, 0.1, 0)))
	check("Y una sala cualquiera no protege", not level.point_protected(den))
	# The creature is not carried anywhere: it is put on the trail of the car
	# they took, and it has to walk there and ride it like they did.
	check("La criatura se queda en el ala de atrás, yendo a por el ascensor", int(level.manifest.rooms[level.locust.patrol_room].wing) == 0 and level.locust.destination.distance_to(level.hotel.lifts[0]) < 1.0)
	check("El coche se ha ido con ellos", level.lifts.lift_gone(0))
	check("Y sus puertas, arriba, quedan cerradas", float(level.lifts.door_state.get(0, 1.0)) < 0.05)
	# The creature's wait counts from the doors opening on them down there.
	check("La espera de la criatura cuenta desde que se abren las puertas abajo", float(level.lifts.creature_hold.get(0, 0.0)) > level.lifts.CREATURE_HOLD - 3.0)
	# Standing in the lobby with the car upstairs: it waits, like anybody else.
	level.locust.global_position = level.hotel.lifts[0] + Vector3(0, 0.04, 0)
	await frames(20)
	check("Con el coche arriba no puede seguirlos", int(FLOOR.room_at(level.manifest.rooms, level.locust.global_position).get("wing", -1)) == 0)
	check("Y quince segundos son quince segundos", level.lifts.LIFT_RETURN == 15.0 and float(level.lifts.lift_away[0]) > 12.0)
	# The car back down is not enough: CREATURE_HOLD has to have gone by since
	# they left, and it has to have stood CREATURE_WAIT at the doors.
	level.lifts.lift_away[0] = 0.02
	await frames(20)
	var wing_now := func() -> int: return int(FLOOR.room_at(level.manifest.rooms, level.locust.global_position).get("wing", -1))
	check("Con el coche abajo, recién llegada tras ellos, espera", wing_now.call() == 0 and float(level.lifts.creature_hold.get(0, 0.0)) > 10.0 and float(level.lifts.lobby_time.get(0, 0.0)) > 0.3)
	level.lifts.creature_hold.erase(0)
	await frames(20)
	check("Pasados sus veinte segundos, aún le faltan los quince en la puerta", wing_now.call() == 0 and float(level.lifts.lobby_time.get(0, 0.0)) < level.lifts.CREATURE_WAIT)
	check("Y para ella el coche sigue arriba", not level.lifts.creature_may_ride(0))
	level.lifts.lobby_time[0] = level.lifts.CREATURE_WAIT - 0.05
	await frames(20)
	check("Cuando vuelve el ascensor, lo toma y sale en el ala nueva", int(FLOOR.room_at(level.manifest.rooms, level.locust.global_position).get("wing", -1)) == 1 and level.locust.global_position.distance_to(level.hotel.arrivals[0]) < 1.5)
	check("Y el coche vuelve a irse con él", level.lifts.lift_gone(0))
	level.locust.global_position = den
	check("La puerta de la tercera ala sigue cerrada", level.hotel.gates[1].locked)
	# The notice of the sector goes by itself, about six seconds after it came.
	await frames(int((level.ui.BRIEF_HOLD + 0.6) * 60))
	check("Y se va solo a los seis segundos", not is_instance_valid(level.ui.brief))
	# The pause screen keeps it, with how the sector is going.
	level.refresh_briefing()
	check("La pausa guarda el objetivo del sector", level.ui.briefing.sector == "SECTOR 2" and level.ui.briefing.objective == level.lifts.stage_brief(2))
	check("Y en el sector 2 cuenta los televisores", level.ui.briefing.progress.size() == 1 and String(level.ui.briefing.progress[0][0]) == "TELEVISORES")
	# Second stage: the sets of that wing, and it asks for as many as there
	# are survivors, with two spare.
	# A few frames for the authority to look at the new stage.
	await frames(5)
	var needed: int = TV.needed(session.roster_count)
	var wing_of := func(index: int) -> int: return int(FLOOR.room_at(level.manifest.rooms, level.televisions[index].global_position).get("wing", -1))
	var sets_two: Array = level.stage_televisions(2)
	var sets_three: Array = level.stage_televisions(3)
	check("La etapa 2 se juega con televisores", session.goal.kind == "televisions" and session.goal.needed == needed)
	# No set on the floor that does not come on: the rest are only the
	# cabinets they stood on, and every set stands on a cabinet of its own.
	var sets_left := 0
	var stands := 0
	for room in level.manifest.rooms:
		for prop in room.props:
			if prop.kind == "tv": sets_left += 1
			if prop.kind == "tv_stand": stands += 1
	check("Las únicas teles del hotel son las que se encienden", sets_left == level.televisions.size() and stands > 0)
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
	await frames(20)
	check("Y la música se fue con ella", level.music_power < 0.05)
	check("Ninguna lámpara del hotel queda encendida", level.hotel.lights.all(func(light): return not light.visible) and level.hotel.practicals.all(func(lamp): return not lamp.visible) and level.hotel.sconce_lights.all(func(lamp): return not lamp.visible))
	check("Las teles encendidas siguen dando luz", level.televisions[0].lamp.visible)
	check("Una tele encendida da luz y no se apaga", level.televisions[0].on and level.televisions[0].lamp.visible and not level.televisions[0].set_on(true))
	# The set is the trailer's CRT on its commode: the channel lies on the
	# tube's own glass, and the screen the rest of the game reads (its sound,
	# the hunter's view, the observer) is where that glass is.
	var set: Node3D = level.televisions[0]
	var face: AABB = PROPS.tv_transform() * PROPS.TV_SCREEN.get_aabb()
	var glass := Vector3(face.get_center().x, face.get_center().y, face.end.z)
	check("La pantalla de la tele está en el cristal del aparato", set.SCREEN.distance_to(glass) < 0.01 and absf(set.SCREEN_SIZE.x - face.size.x) < 0.01 and absf(set.SCREEN_SIZE.y - face.size.y) < 0.01)
	check("Encendida, la nieve cubre el cristal y la luz sale hacia delante, con sombras", set.screen.visible and set.screen.mesh == PROPS.TV_SCREEN and set.opening >= 1.0 and set.lamp.shadow_enabled and set.fill.visible and set.fill.shadow_enabled and (-set.lamp.global_basis.z).normalized().dot(set.global_basis.z.normalized()) > 0.8)
	# Travelling by television: a lit set is a way in and a way out.
	var lit: Array = level.lit_televisions()
	check("Las teles encendidas son las que aparecen en su mapa", lit.size() == needed)
	level.locust.global_position = level.televisions[lit[0]].global_position + Vector3(1.0, 0.04, 0)
	await frames(2)
	check("La criatura reconoce la tele en la que está", level.creature_at_television() == lit[0])
	var before: Vector3 = level.locust.global_position
	level.warp_creature(lit[1])
	check("Sale por otra tele encendida, lejos de donde estaba", level.locust.global_position.distance_to(before) > 5.0 and level.creature_at_television() == lit[1])
	check("Y mira alrededor, sin ir a investigar su propia llegada", level.locust.mode == level.locust.Mode.SEARCH and level.locust.path.is_empty() and level.locust.crossings.is_empty())
	var dark := -1
	for index in sets_two:
		if not level.televisions[int(index)].on: dark = int(index)
	var standing: Vector3 = level.locust.global_position
	if dark >= 0: level.warp_creature(dark)
	check("Y no puede salir por una apagada", dark < 0 or level.locust.global_position.is_equal_approx(standing))
	# On its own: looking for nobody at a lit set, it steps out of another --
	# never one with somebody in front of it.
	var parked: Vector3 = level.player.global_position
	level.locust.global_position = level.television_exit(lit[0]) + Vector3(0, 0.04, 0)
	level.locust.set_physics_process(false)
	level.locust.set_mode(level.locust.Mode.SEARCH)
	level.hop_rest = 0.0
	level.hop_wait = 0.0
	level.player.global_position = level.television_exit(lit[1]) + Vector3(0, 0.1, 0)
	await frames(int((level.HOP_PATIENCE + 1.5) * 60))
	check("No sale de una tele con alguien delante", level.creature_at_television() == lit[0])
	level.player.global_position = Vector3(0, -200, 0)
	await frames(int((level.HOP_PATIENCE + 1.0) * 60))
	check("Buscando a nadie junto a una tele, sale por otra al rato", level.creature_at_television() == lit[1] and level.hop_rest > 0.0)
	level.locust.set_physics_process(true)
	level.player.global_position = parked
	check("Sin pantalla de fin de piso por el medio", level.ui.screen != "transition" and level.ui.screen != "won")
	check("Cerrar la etapa 2 lleva a la 3", await cross_to_stage(3))
	await frames(5)
	# The power that went belonged to the wing left behind: this one is found
	# lit, with no lamp still marked out by the cut.
	check("Al pasar de ala vuelve la corriente", not level.hotel.dark and not session.goal.get("blackout", false))
	await frames(150)
	check("Y con la corriente vuelve la música", level.music_power > 0.95)
	check("Y ninguna lámpara queda apagada por el corte", level.hotel.lights.filter(func(light): return light.has_meta("off") and not light.has_meta("void")).size() == level.hotel.dark_ids.size())
	# Stood in a room of the new wing that is not one of the dark ones: its
	# ceiling lamp is lit again. (Asking whether any lamp anywhere is visible
	# depended on where the lift happened to leave the body.)
	var lamp_room := -1
	for room in level.manifest.rooms:
		if int(room.wing) == 2 and not FLOOR.is_void(room) and not level.hotel.dark_ids.has(int(room.id)) and not bool(room.get("landing", false)) and int(room.id) != int(level.manifest.refuges[2]):
			lamp_room = int(room.id)
			break
	if lamp_room >= 0: level.hotel.update_visibility(FLOOR.position_of(level.manifest.rooms[lamp_room]), true)
	check("Las lámparas del ala nueva alumbran otra vez", lamp_room >= 0 and level.hotel.lights[lamp_room].visible)
	check("La etapa 3 tiene su propia tanda de teles, apagadas", level.stage_televisions().size() == needed + TV.SPARE and level.televisions_on() == 0)
	# The hunter crosses by the same car: the machine that drives the creature
	# owns where it stands, so the floor has to carry it over by hand.
	level.locust.control = "player"
	level.lifts.lift_away.erase(1)
	level.lifts.creature_hold.erase(1)
	level.lifts.lobby_time[1] = level.lifts.CREATURE_WAIT
	level.locust.global_position = level.hotel.lifts[1] + Vector3(0, 0.04, 0)
	await frames(20)
	check("Un cazador humano también cruza en el ascensor", int(FLOOR.room_at(level.manifest.rooms, level.locust.global_position).get("wing", -1)) == 2)
	level.locust.control = "ai"
	# Two wings behind (it spent the whole second stage after a straggler):
	# its own wing's car is the one that takes it on, not the last stage's.
	level.lifts.lift_away.erase(0)
	level.lifts.creature_hold.erase(0)
	level.lifts.lobby_time[0] = level.lifts.CREATURE_WAIT
	level.locust.set_mode(level.locust.Mode.EXECUTE)
	level.locust.global_position = level.hotel.lifts[0] + Vector3(0, 0.04, 0)
	await frames(10)
	check("En plena ejecución el ascensor no se la lleva", int(FLOOR.room_at(level.manifest.rooms, level.locust.global_position).get("wing", -1)) == 0)
	level.locust.set_mode(level.locust.Mode.PATROL)
	await frames(10)
	check("Dos alas atrás toma el coche de su propia ala", int(FLOOR.room_at(level.manifest.rooms, level.locust.global_position).get("wing", -1)) == 1)
	level.locust.global_position = den
	# Held on the blade is not standing in the car.
	var stood: Vector3 = level.player.global_position
	# Just off the last ride: that one is over.
	level.lifts.riding.erase(level.player.slot)
	level.player.global_position = level.hotel.lifts[1] + Vector3(0, 0.1, 0)
	level.execution = {"seat": level.player.slot, "time": 0.5, "point": level.player.global_position, "yaw": 0.0, "stabs": 0, "dropped": false}
	var in_car_held: bool = level.lifts.inside(1).has(level.player)
	level.execution = {}
	var in_car_free: bool = level.lifts.inside(1).has(level.player)
	check("Una víctima en plena ejecución no sube al coche", not in_car_held and in_car_free)
	level.player.global_position = stood
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
	# And the hints in drawers show one too (hint_placement.gd): from outside,
	# nobody can tell a page from a hint.
	var in_drawers: int = level.code.hints.filter(func(hint): return String(hint.place) == "container").size()
	check("Y solo la llevan los otros muebles con una pista", level.containers.filter(func(piece): return is_instance_valid(piece.note)).size() == DIG.COUNT + in_drawers and level.containers.filter(func(piece): return is_instance_valid(piece.note)).all(func(piece): return piece.digit >= 0 or piece.hint >= 0))
	var muebles: int = level.containers.size()
	check("Se puede registrar cualquier mueble con cajones", muebles > 100 and level.containers.all(func(piece): return not piece.searched))
	# Each sounds like what it is when gone through (hotel_container.SEARCH_SOUNDS):
	# it knows which piece it is, and those with a recording of their own use it.
	var models := {}
	for piece in level.containers: models[String(piece.note_spot.get("model", ""))] = true
	var CONTAINER := preload("res://game/world/interactables/hotel_container.gd")
	var recorded: bool = CONTAINER.SEARCH_SOUNDS.values().all(func(paths): return paths.all(func(path): return load(path) is AudioStream and (load(path) as AudioStream).get_length() > 0.5))
	check("Cada mueble suena como lo que es al registrarlo", recorded and not models.has("") and models.has("GothicCommode_01") and models.has("drawer_cabinet") and models.has("cardboard_box_01") and level.containers.all(func(piece): return piece.search_sounds() == CONTAINER.SEARCH_SOUNDS.get(String(piece.note_spot.model), [CONTAINER.SEARCH_SOUND])))
	for piece in hidden:
		level.search_container(piece)
		await frames(2)
	check("Registrar los cuatro da el código entero", level.found_digits.size() == DIG.COUNT and not level.code_so_far().contains("–"))
	check("Quien registra se lleva la nota", hidden.all(func(piece): return not is_instance_valid(piece.note)))
	check("Y los números quedan escritos en la cinta", level.camcorder.code_note.text.contains(level.code_so_far()))
	check("Un mueble registrado no se vuelve a registrar", hidden[0].searched and not hidden[0].set_searched(true))
	# Gone through, each is left open for anybody to see, the creature's clicks
	# too: a drawer or a door out of the piece, drawn in its parts, or one of its
	# things moved; and a box on the layer the clicks come back from.
	await frames(120)
	var opened: bool = hidden.all(func(piece): return moved_out(piece) and piece.shown.any(func(node): return node is StaticBody3D and node.collision_layer == piece.ECHO and node.collision_mask == 0) and echo_found(piece))
	# Drawn in its parts: a body and every part, the whole piece out of its batch.
	var swapped: bool = hidden.filter(func(piece): return not piece.main.is_empty()).all(func(piece): return piece.shown.filter(func(node): return node is MeshInstance3D).size() == 1 + (piece.shown[0].mesh.get_meta("parts") as PackedStringArray).size())
	# A stack shoves its top box, of its own stack.
	var stacks: Array = level.containers.filter(func(piece): return piece.kind == "boxes")
	var stacked: bool = stacks.all(func(piece): return piece.things.size() >= 1 and piece.things.size() <= 6)
	check("Lo registrado queda abierto, y la criatura lo encuentra con sus chasquidos", opened and swapped and stacked and level.containers.filter(func(piece): return not piece.searched).all(func(piece): return piece.shown.is_empty()))
	# Somebody coming back into a floor already gone through finds it so at
	# once (a quiet search, match_net.catch_up), one that opens and one that
	# does not.
	var quiet_ones: Array = []
	for opens in [true, false]:
		var found: Array = level.containers.filter(func(piece): return not piece.searched and piece.main.is_empty() != opens)
		if not found.is_empty(): quiet_ones.append(found[0])
	for piece in quiet_ones: level.apply_search(level.containers.find(piece), true, true)
	check("Quien vuelve a un piso ya registrado lo encuentra abierto, sin esperar", quiet_ones.size() == 2 and quiet_ones.all(func(piece): return moved_out(piece)))
	var pieces_by_kind := {}
	for piece in level.containers: pieces_by_kind[String(piece.kind) + ("·abre" if not piece.main.is_empty() else "")] = true
	print("  muebles registrables: ", pieces_by_kind.keys())
	check("El código es el mismo que el del piso", level.code_so_far() == "".join(DIG.code(level.manifest).map(func(d): return str(d))))
	# And they can be read back: the slips hang beside the shared sheet, with
	# the number and the room it came out of. Nobody has to remember a thing.
	level.ui.sheet.seat = 1
	level.ui.sheet.open(true, "TAB", level.notes_found())
	var slip_text := words_under(level.ui.sheet.slips)
	check("Las notas se pueden releer en la hoja, con su habitación", slip_text.contains("TUS NOTAS") and not String(level.found_where.get(4, "")).is_empty() and slip_text.contains(String(level.found_where[4])))
	check("Y son cuatro páginas, una por número del código", level.ui.sheet.pages.get_child_count() == DIG.COUNT)
	# The third sector counts both: the sets, and the numbers found.
	level.refresh_briefing()
	check("En el sector 3 la pausa cuenta televisores y números", level.ui.briefing.progress.size() == 2 and String(level.ui.briefing.progress[1][1]) == "%d / %d" % [DIG.COUNT, DIG.COUNT])
	check("Y cada mano escribe con su lápiz, el anfitrión en negro", level.ui.sheet.ink_of(1) != level.ui.sheet.ink_of(2) and level.ui.sheet.ink_of(2) != level.ui.sheet.ink_of(3) and level.ui.sheet.ink_of(1).get_luminance() < 0.15)
	# A stroke begun on the plan belongs to the building: it follows the walls
	# as the plan is framed again, and shows only on its planta.
	var sheet = level.ui.sheet
	var plan_stroke := PackedVector2Array([Vector2(10.0, 20.0), Vector2(14.0, 20.0)])
	sheet.apply_confirmed("2:900", sheet.MAP_KIND, plan_stroke)
	sheet.map.origin = Vector2(100, 50)
	sheet.map.fit = 5.0
	sheet.map.lay_pencil(0)
	var pencil: Line2D = sheet.map.pencil_lines["2:900"].line
	var first := pencil.points[1]
	sheet.map.fit = 10.0
	sheet.map.lay_pencil(0)
	check("Un trazo sobre el plano sigue al edificio al reencuadrarse", first.is_equal_approx(Vector2(170, 150)) and pencil.points[1].is_equal_approx(Vector2(240, 250)) and pencil.get_parent() == sheet.map_pencil)
	sheet.map.lay_pencil(1)
	check("Y en otra planta no se ve", not pencil.visible)
	level.ui.sheet.close()
	# The hints of the third stage (hint_placement.gd): eight papers about
	# where the pages are, four in sight (one for each page), three in drawers
	# for three pages, and the other sheet; none in its own page's zone.
	var hints: Array = level.code.hints
	var page_room := {}
	for piece in hidden: page_room[int(piece.slot)] = FLOOR.room_at(level.manifest.rooms, piece.global_position)
	var in_sight: Array = hints.filter(func(hint): return String(hint.place) == "surface")
	check("La tercera etapa tiene ocho pistas: cuatro a la vista, una por página, y cuatro en muebles", hints.size() == 8 and in_sight.size() == 4 and [1, 2, 3, 4].all(func(slot): return in_sight.any(func(hint): return int(hint.slot) == slot)) and hints.filter(func(hint): return String(hint.place) == "container").size() == 4)
	check("Ninguna en la zona de su página ni en una sala con página", hints.all(func(hint): return (int(hint.slot) == 0 or int(level.manifest.rooms[int(hint.room)].sector) != int(page_room[int(hint.slot)].sector)) and not page_room.values().any(func(room): return int(room.id) == int(hint.room))))
	var walked := FLOOR.route_metres(level.manifest, FLOOR.entry_of(level.manifest, 2))
	var other: Array = hints.filter(func(hint): return String(hint.kind) == "hoja")
	check("La que las marca todas está en un mueble, más a trasmano que las otras siete", other.size() == 1 and String(other[0].place) == "container" and hints.all(func(hint): return float(walked.get(int(hint.room), 0.0)) <= float(walked.get(int(other[0].room), 0.0)) + 0.01))
	var said := JSON.stringify(hints)
	check("Ninguna dice nada con punto medio ni guion largo", not said.contains("·") and not said.contains("—"))
	# The maid's sheet and the work order are the hotel's own paperwork: typed
	# on its form (hotel_form.gd), whatever the paper is shown in.
	var paperwork: Array = hints.filter(func(hint): return String(hint.kind) in ["limpieza", "orden"])
	var typed := true
	for hint in paperwork:
		var view: Control = load("res://game/ui/hint_view.gd").new()
		view.setup(hint, [])
		if String(hint.get("form", {}).get("subject", "")).is_empty() or view.get_child_count() != 1 or view.card != load("res://game/ui/hotel_form.gd").CARD: typed = false
		view.free()
	check("El parte de limpieza y la orden de trabajo van a máquina en el impreso del hotel", typed)
	# What they put on the plan is true: the circle holds its page, the corner
	# of the plan has it under its cross, the other sheet's four are the four.
	var truthful := true
	for hint in hints:
		if int(hint.slot) == 0: continue
		var page := Vector2(hidden.filter(func(piece): return piece.slot == int(hint.slot))[0].global_position.x, hidden.filter(func(piece): return piece.slot == int(hint.slot))[0].global_position.z)
		if String(hint.kind) == "calco" and (hint.centre as Vector2).distance_to(page) > float(hint.radius): truthful = false
		if String(hint.kind) == "plano" and (not (hint.window as Rect2).has_point(page) or (hint.cross as Vector2).distance_to(page) > 0.5): truthful = false
	check("Lo que marcan en el plano es verdad", truthful and (other[0].points as Array).size() == DIG.COUNT)
	var chalked: Array = hints.filter(func(hint): return String(hint.kind) == "tiza")
	check("La tiza está en las paredes cuando una pista habla de ella", chalked.all(func(hint): return level.hotel.find_children("*Chalk*", "MeshInstance3D", true, false).size() >= (hint.marks as Array).size()))
	# A hint in a drawer goes to whoever finds it, held up at once.
	var drawer: Dictionary = hints.filter(func(hint): return String(hint.place) == "container" and String(hint.kind) != "hoja")[0]
	level.search_container(level.containers[int(drawer.container)])
	await frames(2)
	check("Una pista en un mueble se la lleva quien registra, y se lee al momento", int(level.code.hints_taken.get(int(drawer.id), -1)) == level.player.slot and level.interaction.reading_hint == int(drawer.id) and is_instance_valid(level.ui.reading))
	level.close_document()
	# One in sight is read where it lies and stays there.
	var paper = level.hotel.find_children("Hint_*", "Area3D", true, false)[0]
	level.interaction.read_hint(paper.hint_id)
	level.close_document()
	check("Una a la vista se lee donde está, y se queda allí", is_instance_valid(paper) and level.code.hints_read.has(paper.hint_id) and not level.interaction.reading())
	# Both hang on the sheet, under the pages, and are held up from there.
	level.interaction.toggle_sheet()
	check("Las pistas leídas cuelgan en la hoja, bajo las páginas", level.ui.sheet.thumbs.size() == 2)
	level.ui.sheet.hold_up(level.ui.sheet.thumbs[0].hint)
	check("Y se levantan para leerlas otra vez", is_instance_valid(level.ui.sheet.held))
	level.interaction.toggle_sheet()
	check("Cerrar la hoja las baja", not is_instance_valid(level.ui.sheet.held))
	# The other sheet puts the four on the plan.
	level.search_container(level.containers[int(other[0].container)])
	await frames(2)
	level.close_document()
	check("La hoja de otro pone las cuatro páginas en el plano", level.code.hint_marks().filter(func(mark): return mark.ink == level.code.OTHER_MARK).size() == DIG.COUNT)
	# Alone there is nothing to forgive: caught is the end of that floor.
	var before_stage: int = session.stage
	check("En solitario, que te cojan termina el piso", session.capture(1) and session.state == session.State.FAILED and session.restarts == 0)
	await frames(10)
	# With a team it is another matter: the floor gives the stage back once.
	session.set_state(session.State.PLAYING)
	session.participants = {1: session.Life.EXPLORING, 2: session.Life.EXPLORING}
	session.roster_count = 2
	# What glows with the floor's power on, to be compared with what glows
	# without it.
	var lit_surfaces := glowing()
	# One set lit in this wing takes its power, the way it does in the second.
	var third_sets: Array = level.stage_televisions()
	level.switch_television(level.televisions[int(third_sets[0])])
	await frames(8)
	check("La tercera ala tiene su propio apagón", session.goal.get("blackout", false) and level.hotel.dark)
	check("Y con la corriente cortada no queda nada brillando", lit_surfaces > 0 and glowing() == 0)
	# Except the exit signs, which are the one thing with a battery: sign and
	# green spill both, so the refuge can still be found in the dark.
	check("Salvo los carteles de salida, que siguen encendidos", not level.hotel.exit_panels.is_empty() and level.hotel.exit_panels.all(func(panel): return panel.get_shader_parameter("level") == null or float(panel.get_shader_parameter("level")) > 0.0))
	check("Con equipo, perder a uno no hunde el piso", session.capture(2) and session.state == session.State.PLAYING and session.restart_wait <= 0.0)
	# With the torch in hand when it goes down: the light trails the camera
	# instead of hanging from it, so a body that is put somewhere else leaves
	# it behind unless somebody brings it.
	level.player.torch.visible = true
	# Where it killed them is at the stage's door: that is where everybody is
	# raised, and it used to be left there.
	level.locust.global_position = level.revival_point() + Vector3(1.5, 0.04, 0)
	check("Caer los dos se perdona una vez", session.capture(1) and session.state == session.State.PLAYING)
	# It takes a moment: the death is seen and heard before anybody gets up.
	check("La muerte se cuenta antes de levantar a nadie", session.participants[1] == session.Life.DEAD and session.restart_wait > 0.0)
	await frames(int(session.RESTART_WAIT * 60) + 20)
	check("Vuelven todos de pie, en la misma etapa", session.participants[1] == session.Life.EXPLORING and session.stage == before_stage and session.restarts == 1)
	check("Y el jugador recupera su cuerpo y su cámara", level.player.visible and level.player.collision_layer == 4 and level.player.camera.current)
	check("Y su linterna vuelve a la mano", level.player.torch.is_visible_in_tree() and level.player.torch.global_position.distance_to(level.player.camera.global_position) < 1.5)
	var door_room: Dictionary = FLOOR.room_at(level.manifest.rooms, level.revival_point())
	var den_room: Dictionary = FLOOR.room_at(level.manifest.rooms, level.locust.global_position)
	var walk: float = float(FLOOR.route_metres(level.manifest, int(door_room.id)).get(den_room.get("id", -1), 0.0)) if not den_room.is_empty() else 0.0
	check("Y la criatura, lejos de la puerta y quieta un momento", walk >= 40.0 and int(den_room.get("wing", -1)) == session.stage - 1 and level.locust.grace > 0.0 and level.locust.mode == level.locust.Mode.PATROL)
	# Not anywhere far: where it starts this stage, which is neither the door
	# they come in by nor the one they have to reach, and for as long as it
	# waited when the floor began.
	var den_id: int = level.revival.stage_den(session.stage)
	var refuges: Array = level.manifest.get("refuges", [])
	var way_out: int = int(refuges[session.stage - 1]) if session.stage - 1 < refuges.size() else int(level.manifest.exit)
	var from_exit: int = level.GENERATOR.distance_map(level.manifest.adjacency, way_out)[den_id] if den_id >= 0 else -1
	check("Vuelve a su punto de aparición de la etapa, lejos también de la salida", den_id >= 0 and int(den_room.get("id", -1)) == den_id and from_exit > 2)
	check("Y espera lo que esperó al empezar el piso", level.locust.grace >= float(level.tuning().grace) - 1.0 and level.locust.grace >= level.revival.RESTART_GRACE - 1.0)
	check("El primer sector empieza en ese mismo sitio", level.revival.stage_den(1) >= 0 and int(level.manifest.rooms[level.revival.stage_den(1)].get("wing", -1)) == 0)
	# A creature somebody drives goes back too, and waits too: it used to be
	# left where it stood, at the door, free to strike.
	var kept_control: String = level.locust.control
	var kept_grace: float = level.locust.grace
	level.locust.control = "puppet"
	level.locust.grace = 0.0
	level.locust.global_position = level.revival_point() + Vector3(1.5, 0.04, 0)
	level.revival.relocate_creature(level.revival.den_point(den_id), level.revival.restart_grace())
	check("La bestia que lleva un jugador también vuelve y espera", level.locust.global_position.distance_to(level.revival.den_point(den_id)) < 0.5 and level.locust.grace >= level.revival.RESTART_GRACE)
	level.locust.control = kept_control
	level.locust.grace = kept_grace
	# What a guest goes through, played out on one machine: the word that it
	# is on its feet arrives before the session that says so, which is pushed
	# twice a second. In between, the loop puts the body away every frame --
	# and the torch with it, because the light trails the camera and is hidden
	# along with the body: lit for everybody else, dark for its owner.
	level.match_net.config = {"seed": 81, "mode": 0, "survivors": [1, 2], "locust_seat": 0}
	# Somebody who dropped comes back where they were -- unless the floor has
	# crossed to another wing while they were away, in which case where they
	# were is behind a stage door with half a hotel in between, and nobody
	# would call that coming back.
	var in_play := Vector3.ZERO
	var left_behind := Vector3.ZERO
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) == session.stage - 1 and not FLOOR.is_void(room):
			in_play = FLOOR.position_of(room)
			break
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) == 0 and not FLOOR.is_void(room):
			left_behind = FLOOR.position_of(room)
			break
	check("Quien vuelve de una caída vuelve donde estaba", level.return_place(in_play).distance_to(in_play) < 0.2)
	var brought: Vector3 = level.return_place(left_behind)
	check("Y si el piso cambió de ala sin él, al ala que se juega", brought.distance_to(left_behind) > 10.0 and int(FLOOR.room_at(level.manifest.rooms, brought).get("wing", -1)) == session.stage - 1)
	# (Any stage given back above has finished rewinding its tape by now.)
	await frames(int(level.REWIND_TIME * 60.0) + 10)
	session.participants[1] = session.Life.DEAD
	level.drive_local(1.0 / 60.0)
	check("Muerto en un invitado, el cuerpo y su luz se guardan", not level.player.visible and not level.player.torch.is_visible_in_tree())
	level.apply_revival({1: Vector3(0, 0.04, 0)}, false)
	check("La resurrección no espera a la sesión replicada", level.local_alive() and level.player.visible and level.player.torch.is_visible_in_tree())
	level.drive_local(1.0 / 60.0)
	check("Y el cuadro siguiente no vuelve a guardarlo", level.player.visible and level.player.camera.current)
	# And a body put away by a single frame of believing itself dead comes
	# back on its own as soon as the session catches up.
	session.participants[1] = session.Life.DEAD
	level.drive_local(1.0 / 60.0)
	session.participants[1] = session.Life.EXPLORING
	level.drive_local(1.0 / 60.0)
	check("Un cuadro de más como muerto no deja el cuerpo escondido", level.player.visible and level.player.torch.is_visible_in_tree())
	level.match_net.config = {}
	level.player.torch.visible = false
	# The stage is given back whole: its sets out and its power on.
	check("Una etapa devuelta empieza con la luz otra vez", level.televisions_on() == 0 and not level.hotel.dark and not session.goal.get("blackout", false))
	check("Y las lámparas vuelven a brillar donde brillaban", glowing() == lit_surfaces)
	session.capture(2)
	check("La segunda vez sí se acaba", session.capture(1) and session.state == session.State.FAILED)
	await frames(10)
	# Back to a floor in hand for the rest of the checks.
	await level.start_floor(81)
	session = level.session
	level.locust.set_physics_process(false)
	den = level.locust.global_position
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
	var dark_first := false
	var went_black := false
	for i in 480:
		level.player.global_position = level.hotel.lifts[level.hotel.lifts.size() - 1] + Vector3(0, 0.1, 0)
		level.match_net.call_lift(level.hotel.lifts.size() - 1)
		await physics_frame
		if i == 10: dark_first = session.state == session.State.PLAYING and level.lifts.leaving >= 0.0
		went_black = went_black or level.lifts.ride_static() >= 1.0
		if session.state == session.State.WON:
			won = true
			break
	check("El último ascensor también es un viaje: a oscuras antes del fin", dark_first and went_black)
	check("Salir por esa puerta termina el piso", won and session.stage == 3)
	check("Y entonces sale la pantalla de fin", level.ui.screen == "won")
	# The tape that got out is written down: its three sectors, who walked out
	# and what it earned, and it takes its place on the board.
	var line: Dictionary = level.ui.summary
	check("La cinta queda anotada, con su tiempo y su número", int(line.get("seed", 0)) == 81 and float(line.get("time", 0.0)) > 0.0 and not line.get("sectors", []).is_empty() and is_equal_approx(float(line.sectors[line.sectors.size() - 1]), float(line.time)))
	check("Y con quién la jugó y si salió", line.get("team", []).size() == 1 and bool(line.team[0].escaped))
	check("Sola cuenta como solitario y sin bajas", String(line.get("company", "")) == level.records.SOLO and int(line.get("deaths", 0)) == 0 and level.records.badges(line).has("SIN BAJAS"))
	check("Y entra en el tablón, la primera de su tabla", level.records.table_of("time", 1, level.records.SOLO).size() == 1 and int(level.ui.places.get("time", 0)) == 1)
	# The board is read from what is saved, not from what is in hand.
	var kept = load("res://game/services/records_service.gd").new()
	kept.save_path = level.records.save_path
	kept.load_records()
	check("El tablón sobrevive a cerrar el juego", kept.table_of("time", 1, kept.SOLO).size() == 1)
	# What was done on the floor is in the line, to whoever did it, and the
	# tape is worth what that comes to.
	var me: Dictionary = line.team[0]
	check("Lo que hizo queda a su nombre: las teles, el código, los sectores", int(me.get("tvs", 0)) >= TV.needed(1) and int(me.get("code", 0)) == 1 and int(me.get("sectors", 0)) >= 2 and int(me.get("metres", -1)) >= 0)
	var kinds: Array = line.get("events", []).map(func(event): return String(event.k))
	check("Y la cinta lleva su puntaje, su nota y sus momentos", int(line.get("score", 0)) > 0 and int(me.get("score", 0)) > 0 and not String(line.get("grade", "")).is_empty() and kinds.has("sector") and kinds.has("tv") and kinds.has("code") and kinds.has("out"))
	check("Los hitos del piso se anotan la primera vez, y la ficha suma el piso", level.ui.outcome.milestones.has("out") and level.ui.outcome.milestones.has("solo") and not level.records.reached(1, "out").is_empty() and int(level.records.career.get("floors", 0)) == 1)
	check("La pantalla de fin es el parte, en pestañas", is_instance_valid(level.ui.settings_tabs) and level.ui.settings_tabs.get_tab_count() == 5 and words_under(level.ui.column).contains("PUNTAJE"))
	level.on_action("records")
	check("Y las marcas enseñan la cinta en su tablón", level.ui.screen == "records" and words_under(level.ui.column).contains(level.ui.tape_time(float(line.time))) and level.ui.records_back == "won")
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
