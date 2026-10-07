extends SceneTree
const GEN := preload("res://game/world/generation/map_generator.gd")
const WALKER := preload("res://game/world/generation/wall_walker.gd")
const VALIDATOR := preload("res://game/world/generation/map_validator.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const ROUTE_SIGNS := preload("res://game/world/generation/exit_route_signs.gd")
var checks: Array = []
var failed := 0

const PRESETS := preload("res://game/presentation/graphics_presets.gd")
func _initialize() -> void: run.call_deferred()
func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title)

## Floors generated here. A thousand are measured by tools/dev/map_metrics.gd;
## three hundred is what fits in the time a test has.
const SEEDS := 300

## Rooms on a planta as the game counts them (map_validator.gd): every room,
## a salon once, not the corridors and not the lobbies of the lifts.
static func rooms_on(data: Dictionary, planta: int) -> int:
	var grid: Dictionary = data.plantas[planta]
	var halls := {}
	var count := 0
	for local in int(grid.width) * int(grid.height):
		var room: Dictionary = data.rooms[int(grid.base) + local]
		if int(room.type) == 20 or room.kind != "module" or bool(room.get("landing", false)) or (planta > 0 and int(room.id) == int(data.entries[planta])): continue
		if int(room.hall) >= 0:
			if halls.has(int(room.hall)): continue
			halls[int(room.hall)] = true
		count += 1
	return count

## The way from where the player stands with the most floor ahead before a
## wall or a shut door.
func clearest_heading(scene) -> float:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	# A body, not a ray: a ray through a doorway at a slant clears the jamb
	# and the open leaf beside it (128: solid to survivors) that a body hits.
	var body := CapsuleShape3D.new()
	body.radius = 0.4
	body.height = 1.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body
	query.collision_mask = 1 | 8 | 128
	query.transform = Transform3D(Basis.IDENTITY, scene.player.global_position + Vector3(0, 0.95, 0))
	var best := 0.0
	var best_length := -1.0
	for step in 16:
		var yaw := TAU * step / 16.0
		query.motion = Basis(Vector3.UP, yaw) * Vector3(0, 0, -30.0)
		var length: float = space.cast_motion(query)[0] * 30.0
		if length > best_length:
			best_length = length
			best = yaw
	return best

func run() -> void:
	var generator := GEN.new()
	var fallback_count := 0
	var failures: Array = []
	var used_types := {}
	var wing_leaks: Array = []
	var counts: Array = []
	var walked: Array = []
	var number_faults: Array = []
	var climbing := 0
	var falling := 0
	var one_door: Array = []
	var wall_solved: Array = []
	var sealed_landing: Array = []
	var misaligned: Array = []
	# What 4.C draws by seed: doors along their walls, dark rooms by planta,
	# dark corridors now and then.
	var off_middle := 0
	var room_doors := 0
	var dark_by_planta := [0, 0, 0]
	var can_be_dark := [0, 0, 0]
	var dark_corridors := 0
	var corridors := 0
	for seed_value in SEEDS:
		var data := generator.generate(seed_value)
		if data.fallback: fallback_count += 1
		if not VALIDATOR.new().validate(data).is_empty(): failures.append(seed_value)
		for room in data.rooms: used_types[room.type] = true
		# Each planta a hotel of its own: between 81 and 99 rooms.
		for planta in 3: counts.append(rooms_on(data, planta))
		# Nothing joins one planta to another: the lift is the only way down.
		for edge in data.edges:
			if int(data.rooms[int(edge[0])].wing) != int(data.rooms[int(edge[1])].wing): wing_leaks.append(seed_value)
		var rooms_walked := 0
		for gate in data.gates:
			var distances: Array = GEN.distance_map(data.adjacency, int(data.entries[int(gate.stage) - 1]))
			rooms_walked += maxi(0, int(distances[int(gate.room)]))
			# Each lift goes straight down to the lobby under it.
			var arrive := int(gate.arrive)
			if arrive >= 0:
				var above: Dictionary = data.rooms[int(gate.beyond)]
				var below: Dictionary = data.rooms[arrive]
				if absf(float(above.px) - float(below.px)) > 0.001 or absf(float(above.pz) - float(below.pz)) > 0.001 or int(below.wing) != int(above.wing) + 1: misaligned.append(seed_value)
		walked.append(rooms_walked)
		for key in data.doors:
			var pair: PackedStringArray = String(key).split(":")
			if bool(data.rooms[int(pair[0])].corridor) and bool(data.rooms[int(pair[1])].corridor): continue
			room_doors += 1
			if absf(float(data.doors[key].offset)) > 0.1: off_middle += 1
		for room in data.rooms:
			if bool(room.get("corridor", false)):
				corridors += 1
				if bool(room.dark): dark_corridors += 1
			elif FLOOR.may_be_dark(room):
				can_be_dark[int(room.wing)] += 1
				if bool(room.dark): dark_by_planta[int(room.wing)] += 1
		# Every refuge is entered by one door and no other, with the locked
		# door to its lift lobby besides, and that lobby is a dead end:
		# nothing else opens on to it. And none of the three is found by a
		# hand on the wall, either hand, any of the four ways of setting off.
		for wing in 3:
			var refuge: int = int(data.refuges[wing])
			var lobby := int(data.gates[wing].get("beyond", -1))
			var ways: Array = data.adjacency[refuge].filter(func(id): return int(data.rooms[id].wing) == wing and id != lobby)
			if ways.size() != 1: one_door.append([seed_value, wing, ways.size()])
			if lobby < 0 or data.adjacency[lobby].size() != 1 or not bool(data.rooms[lobby].get("landing", false)): sealed_landing.append(seed_value)
			if WALKER.hits(data.rooms, data.adjacency, int(data.entries[wing]), refuge) > 0: wall_solved.append(seed_value)
		# The numbers: each planta its hundred, never two doors the same, and
		# only the rooms let to somebody carry one.
		var seen_numbers := {}
		for room in data.rooms:
			var number := int(room.get("number", 0))
			if number == 0:
				if int(room.type) != 20 and GEN.numbered(room): number_faults.append(seed_value)
				continue
			if not GEN.numbered(room) or seen_numbers.has(number): number_faults.append(seed_value)
			if number / 100 != int(room.wing) + 1: number_faults.append(seed_value)
			seen_numbers[number] = true
		# And they are no longer a compass: whether they climb or fall as one
		# walks into a planta is drawn, so over the lot it is a coin.
		for wing in 3:
			var wing_entrance: int = int(data.entries[wing])
			var reach: Array = GEN.distance_map(data.adjacency, wing_entrance)
			var by_distance: Array = data.rooms.filter(func(room): return int(room.wing) == wing and int(room.get("number", 0)) > 0 and reach[int(room.id)] >= 0)
			by_distance.sort_custom(func(one, two): return reach[int(one.id)] < reach[int(two.id)])
			var third: int = by_distance.size() / 3
			if third > 0:
				var near := 0.0
				var far := 0.0
				for index in third:
					near += int(by_distance[index].number) % 100
					far += int(by_distance[by_distance.size() - 1 - index].number) % 100
				if far > near: climbing += 1
				elif far < near: falling += 1
	check("300 semillas: grafos y módulos válidos", failures.is_empty())
	check("Cada refugio se entra por una sola puerta", one_door.is_empty())
	check("Detrás de la puerta de cada refugio solo está su ascensor, sin otra entrada", sealed_landing.is_empty())
	check("Ir pegado a una pared no encuentra ningún refugio", wall_solved.is_empty())
	check("Cada ascensor baja al vestíbulo que tiene justo debajo", misaligned.is_empty())
	check("Más de la mitad de las puertas no están en el centro de su pared", float(off_middle) / room_doors > 0.5)
	var dark_share: Array = [0, 1, 2].map(func(planta): return float(dark_by_planta[planta]) / can_be_dark[planta])
	check("Cuanto más abajo, más salas a oscuras (entre el 20 y el 55 %%): %s" % str(dark_share.map(func(share): return snappedf(share, 0.01))), dark_share[0] < dark_share[1] and dark_share[1] < dark_share[2] and dark_share[0] > 0.2 and dark_share[2] < 0.55)
	check("Un pasillo a oscuras es un suceso (menos del 10 % de los tramos)", float(dark_corridors) / corridors < 0.1)
	# The standby floor, drawn only if every try fails. It never is here,
	# which is exactly why it has to be held to its promises: that it is a
	# floor like the others to walk, whatever else it gives up.
	var standby: Dictionary = generator.candidate(404, 0, true)
	check("El piso de respaldo es válido y obliga a recorrerlo", VALIDATOR.new().validate(standby).is_empty() and int(standby.walk) >= GEN.MIN_WALK)
	check("La numeración es de hotel: una centena por planta, sin repetir y sin placa en servicio", number_faults.is_empty())
	var drawn: float = float(climbing) / maxf(1.0, float(climbing + falling))
	check("Subir de número no lleva a ninguna parte", drawn > 0.35 and drawn < 0.65)
	check("Las plantas solo se comunican por su ascensor", wing_leaks.is_empty())
	check("Cada planta tiene más de 80 habitaciones y menos de 100", counts.min() > 80 and counts.max() < 100)
	var shortest: int = walked.min()
	check("Las tres etapas obligan a recorrer el piso", shortest >= GEN.MIN_WALK and float(walked.reduce(func(a, b): return a + b, 0)) / walked.size() >= 40.0)
	check("Tasa de respaldo inferior al 1%", fallback_count < SEEDS / 100)
	check("Los 21 tipos de celda presentes en el lote", used_types.size() == 21)
	check("Semilla reproducible", JSON.stringify(generator.generate(81)) == JSON.stringify(generator.generate(81)))
	check("Semillas distintas cambian el mapa", JSON.stringify(generator.generate(81)) != JSON.stringify(generator.generate(82)))
	# The floors themselves, pinned: a guest rebuilds the host's from the seed,
	# and a checkpoint is a seed. A change here is a change to every floor
	# (and wants FLOOR.VERSION bumped); moving code about must not make one.
	# The floor's rules and its plantas are counted in three places that have to
	# agree: the rules (hotel_floor.gd), the session and the generator.
	check("Las reglas del hotel tienen una etapa por planta", preload("res://game/floors/hotel_floor.gd").count() == preload("res://game/services/game_session.gd").STAGES and preload("res://game/services/game_session.gd").STAGES == FLOOR.PLANTAS)
	check("Los pisos 81 y 777 son los de siempre", hash(JSON.stringify(generator.generate(81))) == 3692823199 and hash(JSON.stringify(generator.generate(777))) == 3876374441)
	var scene = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check("Menú principal y cursor libre", scene.ui.buttons.has("new") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	check("El menú principal lleva Multijugador y no Personaje", scene.ui.buttons.has("multiplayer") and not scene.ui.buttons.has("characters"))
	scene.on_action("multiplayer")
	# The connection first (Steam or IP / LAN); the character is chosen in the room.
	check("Multijugador pide primero la conexión", scene.ui.screen == "multiplayer" and scene.ui.buttons.has("mp_steam") and scene.ui.buttons.has("mp_ip") and not scene.ui.buttons.has("characters"))
	scene.on_action("main")
	await scene.start_floor(81)
	await physics_frame
	check("Se inicia un hotel grande y libre de objetivos", scene.manifest.rooms.size() >= 100 and scene.session.state == scene.session.State.PLAYING)
	check("Validación física de todos los pasos y coberturas", scene.physical_errors.is_empty())
	# The corridors' way-out signs: four to six a planta, in the circulation,
	# each arrow a real way on, and the arrows followed from any of them end
	# at that planta's refuge without going round.
	var per_planta := [0, 0, 0]
	var signs_ok := true
	for sign in scene.hotel.route_signs:
		per_planta[int(sign.planta)] += 1
		var room: Dictionary = scene.manifest.rooms[int(sign.room)]
		var on: int = FLOOR.beside(room, sign.way)
		# In a corridor, and pointing along the corridors (or on to open
		# ground), never into a room.
		if not bool(room.get("corridor", false)) or on < 0 or not scene.manifest.adjacency[int(sign.room)].has(on) or not ROUTE_SIGNS.circulation(scene.manifest.rooms[on]): signs_ok = false
		if int(sign.front) != ROUTE_SIGNS.way_for(-sign.normal, sign.way) or int(sign.back) != ROUTE_SIGNS.way_for(sign.normal, sign.way): signs_ok = false
	# Three, four or five by how much corridor the planta has.
	check("Cada planta tiene de 3 a 5 carteles de salida en sus pasillos (%s)" % str(per_planta), per_planta.all(func(n): return n >= 3 and n <= 5))
	check("Cada cartel cuelga en un pasillo y señala a lo largo de los pasillos, nunca a una habitación", signs_ok)
	check("Una flecha hacia la derecha se lee a la izquierda desde el otro lado", ROUTE_SIGNS.way_for(Vector2i(0, -1), Vector2i(1, 0)) == ROUTE_SIGNS.Way.RIGHT and ROUTE_SIGNS.way_for(Vector2i(0, 1), Vector2i(1, 0)) == ROUTE_SIGNS.Way.LEFT and ROUTE_SIGNS.way_for(Vector2i(1, 0), Vector2i(1, 0)) == ROUTE_SIGNS.Way.AHEAD)
	# The plan on the shared sheet: the walls of every planta, the plaster
	# partitions of the alcoves among them, drawn by what the survivors see
	# and gone three minutes after it was last seen.
	var fmap = scene.floor_map
	fmap.reset()
	var alcoves: int = scene.hotel.plan_walls.filter(func(wall): return absf(wall[0].distance_to(wall[1]) - 3.2) < 0.01).size()
	var per_planta_pieces := [0, 0, 0]
	for planta in fmap.piece_planta: per_planta_pieces[planta] += 1
	check("El plano tiene las paredes de las tres plantas, con los tabiques de yeso (%s, %d)" % [str(per_planta_pieces), alcoves], per_planta_pieces.all(func(n): return n > 200) and alcoves > 0)
	scene.player.position = FLOOR.position_of(scene.manifest.rooms[int(scene.manifest.get("start", 0))]) + Vector3(0, 0.04, 0)
	for turn in 4:
		scene.player.rotation.y = TAU * turn / 4.0
		await physics_frame
		fmap.look_now()
	var fresh_here := range(fmap.piece_a.size()).filter(func(index): return fmap.freshness(index) > 0.0)
	check("Lo que el jugador tiene delante queda en el plano, y solo en su planta", fresh_here.size() > 10 and fresh_here.all(func(index): return fmap.piece_planta[index] == 0))
	fmap.clock += fmap.FORGET + 1.0
	check("Y a los tres minutos se ha borrado", range(fmap.piece_a.size()).all(func(index): return fmap.freshness(index) <= 0.0))
	# Each face of a door shows the number of the room behind it.
	var numbers_ok := true
	var plaques_ok := true
	for each in scene.hotel.doors:
		var labels: Array = each.find_children("*", "Label3D", true, false)
		for label in labels:
			# Measured with the door shut, whatever its leaf is doing now.
			var facing := Basis(Vector3.UP, each.closed_rotation + label.rotation.y).z
			var in_front: Dictionary = FLOOR.room_at(scene.manifest.rooms, each.doorway + facing * 1.2)
			var behind: Dictionary = FLOOR.room_at(scene.manifest.rooms, each.doorway - facing * 1.2)
			if in_front.is_empty() or behind.is_empty() or label.text != str(int(behind.get("number", 0))): numbers_ok = false
		# And only the rooms that have a number show a plaque: service,
		# circulation and the refuge show a bare leaf.
		var across := Basis(Vector3.UP, each.closed_rotation).z
		var wanted := 0
		for step in [1.2, -1.2]:
			var room: Dictionary = FLOOR.room_at(scene.manifest.rooms, each.doorway + across * step)
			if int(room.get("number", 0)) > 0: wanted += 1
		if labels.size() != wanted: plaques_ok = false
	check("El número de cada cara de puerta indica la habitación de detrás", numbers_ok)
	check("Servicio, pasillo y refugio no llevan placa", plaques_ok)
	# The cells a planta does not use have a lamp in the list that is never on.
	var lamps: Array = scene.hotel.lights.filter(func(light): return not light.has_meta("void"))
	var dark: Array = lamps.filter(func(light): return light.has_meta("off"))
	var reception_lit: bool = scene.manifest.rooms.all(func(room): return int(room.type) != 0 or not scene.hotel.lights[room.id].has_meta("off"))
	check("Algunas habitaciones tienen la luz apagada, nunca la recepción", dark.size() > 0 and float(dark.size()) < float(lamps.size()) * 0.4 and reception_lit and dark.all(func(light): return not light.visible))
	# A door between two rooms of the first planta, with room to stand either
	# side of it at every distance measured below.
	var door = scene.hotel.doors[0]
	for each in scene.hotel.doors:
		var a: Dictionary = FLOOR.room_at(scene.manifest.rooms, each.doorway + Basis(Vector3.UP, each.closed_rotation).z * 1.0)
		var b: Dictionary = FLOOR.room_at(scene.manifest.rooms, each.doorway - Basis(Vector3.UP, each.closed_rotation).z * 1.0)
		if not a.is_empty() and not b.is_empty() and a.kind == "module" and b.kind == "module" and int(a.wing) == 0 and each.gate_stage == 0:
			door = each
			break
	door.open_immediately()
	var across: Vector3 = Basis(Vector3.UP, door.closed_rotation) * Vector3(0, 0, 1)
	# Somebody standing in the frame: the door shuts all the same, does not
	# move them, and stays a ghost to them until they have stepped out of it.
	for frame in 4: await physics_frame
	scene.player.position = door.doorway + across * 0.1 + Vector3(0, 0.04, 0)
	for frame in 4: await physics_frame
	var standing: Vector3 = scene.player.global_position
	check("La puerta cierra aunque haya alguien en el umbral", door.toggle(false, false))
	for frame in 45: await physics_frame
	check("Y no lo empuja: se queda donde estaba", not door.opened and scene.player.global_position.distance_to(standing) < 0.05)
	check("Mientras está dentro de la hoja la puerta no es sólida", door.collision_layer == door.GHOST)
	scene.player.rotation.y = door.closed_rotation
	scene.player.camera.rotation = Vector3.ZERO
	await physics_frame
	check("Y se puede volver a abrir desde dentro", scene.focused_door() == door)
	scene.player.position = Vector3(0, 0.04, 0)
	for frame in 4: await physics_frame
	check("En cuanto sale, la puerta cerrada recupera colisión", not door.opened and door.collision_layer == door.SOLID)
	door.open_immediately()
	scene.player.position = door.doorway + across * 0.8 + Vector3(0, 0.04, 0)
	check("Puerta cierra con el jugador ya pasado el marco", door.toggle(false, false))
	scene.player.position = Vector3(0, 0.04, 0)
	for frame in 45: await physics_frame
	check("Puerta cerrada recupera colisión", not door.opened and door.collision_layer == 8)
	# A floor has several hundred doors: one with nothing to wait for is not
	# asked anything sixty times a second (hotel_door._physics_process).
	await physics_frame
	check("Una puerta en reposo duerme", not door.is_physics_processing())
	# Doors are reached from 2.4 m (interaction.DOOR_REACH): from across a
	# room, as at the old 3.2 m, they are not.
	scene.player.position = door.doorway + across * 2.1 + Vector3(0, 0.04, 0)
	scene.player.rotation.y = door.closed_rotation
	scene.player.camera.rotation = Vector3.ZERO
	await physics_frame
	check("Interacción enfoca puerta a algo más de 2 m", scene.focused_door() == door)
	scene.player.position = door.doorway + across * 2.9 + Vector3(0, 0.04, 0)
	await physics_frame
	check("Interacción ya no alcanza una puerta a casi 3 m", scene.focused_door() != door)
	scene.player.position = door.doorway + across * 4.2 + Vector3(0, 0.04, 0)
	await physics_frame
	check("Interacción no alcanza puerta distante", scene.focused_door() != door)
	door.open_immediately()
	scene.player.position = door.doorway + across * 1.6 + Vector3(0, 0.04, 0)
	scene.player.rotation.y = door.closed_rotation + PI
	await physics_frame
	check("Puerta abierta a la espalda se puede cerrar", scene.focused_door() != door and scene.door_behind() == door)
	scene.player.position = door.doorway + across * 2.6 + Vector3(0, 0.04, 0)
	await physics_frame
	check("Pero no desde más lejos que DOOR_BEHIND_REACH", scene.door_behind() != door)
	door.toggle(false, false)
	for frame in 45: await physics_frame
	scene.player.position = Vector3(0, 0.04, 0)
	door.toggle(true)
	for frame in 20: await physics_frame
	check("Apertura lenta respeta su duración, y la puerta está despierta mientras gira", door.moving and door.is_physics_processing())
	for frame in 90: await physics_frame
	check("Puerta abierta recupera colisión sin empujar", door.opened and not door.moving and door.collision_layer == door.OPEN_SOLID)
	scene.player.rotation.y = float(scene.manifest.start_facing)
	check("Quince tipos de prop como mínimo", preload("res://game/world/generation/floor_definition.gd").RECIPES.reduce(func(acc, recipe):
		for prop in recipe: acc[prop] = true
		return acc, {}).size() >= 15)
	# Walking where there is room to walk: the reception's door can be a few
	# metres ahead, and a body that has run into it takes no steps.
	scene.player.rotation.y = clearest_heading(scene)
	var start_position: Vector3 = scene.player.position
	Input.action_press("forward")
	for frame in 35: await physics_frame
	Input.action_release("forward")
	check("Movimiento físico", scene.player.position.distance_to(start_position) > 1.0)
	# Recorded steps start early so their impact lands on the footfall.
	var offsets := []
	for gait in ["walk", "run"]:
		scene.player.position = start_position
		scene.player.step_phase = 0.0
		scene.player.step_scheduled = -1
		if gait == "run": Input.action_press("sprint")
		Input.action_press("forward")
		var last_step := 0
		for frame in 150:
			await physics_frame
			var step := floori(scene.player.step_phase / PI)
			# physics_frame fires before the player's own update: its step count
			# is from the previous frame, and a crossing is only seen on the frame after it.
			if step != last_step and frame > 30: offsets.append(absf(Engine.get_physics_frames() - 1 - scene.player.step_impact_frame))
			last_step = step
		Input.action_release("forward")
		Input.action_release("sprint")
		for frame in 20: await physics_frame
	check("Golpe de cada paso grabado coincide con la pisada", offsets.size() >= 4 and offsets.max() <= 1.05)
	scene.session.pause()
	var pause_position: Vector3 = scene.player.position
	var time_before: float = scene.session.elapsed
	Input.action_press("forward")
	for frame in 10: await physics_frame
	Input.action_release("forward")
	check("Pausa real detiene movimiento y tiempo", scene.player.position.is_equal_approx(pause_position) and scene.session.elapsed == time_before)
	scene.session.set_state(scene.session.State.PLAYING)
	var saved: Dictionary = scene.session.checkpoint()
	check("Checkpoint de inicio contiene semilla", saved.get("seed", -1) == 81)
	var settings = scene.settings
	settings.set_value("ambience", 0.35)
	settings.set_value("invert", true)
	settings.bind("flashlight", KEY_L)
	settings.values = settings.DEFAULTS.duplicate()
	settings.bindings = settings.KEYS.duplicate()
	settings.load_settings()
	check("Ajustes y controles persistentes", is_equal_approx(settings.values.ambience, 0.35) and settings.values.invert and settings.bindings.flashlight == KEY_L)
	check("Reasignación rechaza conflictos y Escape", not settings.bind("forward", KEY_L) and not settings.bind("forward", KEY_ESCAPE))
	var previous_resolution: int = settings.values.resolution
	settings.set_value("resolution", (previous_resolution + 1) % 4)
	settings._process(13)
	check("Resolución se revierte sin confirmación", settings.values.resolution == previous_resolution and settings.previous_display.is_empty())
	settings.set_value("resolution", (previous_resolution + 1) % 4)
	settings.confirm_display()
	settings.load_settings()
	check("Resolución confirmada persiste", settings.values.resolution == (previous_resolution + 1) % 4)
	settings.set_value("resolution", previous_resolution)
	settings.confirm_display()
	settings.reset_controls()
	check("Restaurar controles", settings.bindings.flashlight == KEY_F and not settings.values.invert)
	settings.set_value("reduced", true)
	check("Efectos reducidos eliminan VHS", scene.post_material.get_shader_parameter("vhs") == 0.0)
	settings.set_value("reduced", false)
	# Graphics presets (graphics_presets.gd): five, each applied whole. Muy
	# bajo is the last index and the first listed. The render scale and the
	# upscaler are not a preset's to set: they are the player's own.
	settings.set_value("quality", 3)
	settings.load_settings()
	check("El preset Ultra se guarda y un valor fuera de rango se corrige", settings.values.quality == 3 and settings.sanitize("quality", 9) == PRESETS.VERY_LOW and settings.sanitize("quality", -2) == 0)
	check("Los presets se listan del más barato al más caro", PRESETS.ORDER == [PRESETS.VERY_LOW, PRESETS.LOW, PRESETS.MEDIUM, PRESETS.HIGH, PRESETS.ULTRA])
	var viewport: Viewport = scene.get_viewport()
	settings.set_value("upscaler", "fsr1")
	settings.set_value("scale", 0.77)
	for quality in PRESETS.ORDER: settings.set_value("quality", quality)
	check("Cambiar de preset no toca ni la escala ni el escalado", is_equal_approx(settings.values.scale, 0.77) and settings.values.upscaler == "fsr1" and is_equal_approx(viewport.scaling_3d_scale, 0.77) and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR)
	settings.set_value("upscaler", "fsr2")
	settings.set_value("quality", 3)
	check("Ultra con FSR 2.2 pedido a mano se queda con FSR 2.2", viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2)
	# From here each preset as it was designed: its own scale, and "auto".
	settings.set_designed(0)
	check("Bajo: escala 0,67 con FSR, FXAA, sin SSAO ni volumétrica y sin sombra propia", is_equal_approx(viewport.scaling_3d_scale, 0.67) and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR and viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA and not scene.environment.ssao_enabled and not scene.environment.volumetric_fog_enabled and scene.player.avatar.meshes.all(func(mesh): return mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	settings.set_designed(1)
	# Medio se dibuja al 85% y lo sube FSR 2.2, que reconstruye con el
	# movimiento de cada píxel y es ya el suavizado: el TAA sobra debajo.
	check("Medio: FSR 2.2 en lugar de TAA, SSAO sin SSIL y lámparas hasta 42 m", viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 and not viewport.use_taa and scene.environment.ssao_enabled and not scene.environment.ssil_enabled and is_equal_approx(scene.hotel.lights[0].distance_fade_shadow, 42.0) and scene.player.avatar.meshes.all(func(mesh): return mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
	settings.set_designed(3)
	check("Ultra: MSAA 4×, SSR, lámparas hasta 64 m y salas hasta 82 m", viewport.msaa_3d == Viewport.MSAA_4X and scene.environment.ssr_enabled and is_equal_approx(scene.hotel.lights[0].distance_fade_shadow, 64.0) and scene.hotel.preset.room_reach == 82.0)
	# What Ultra alone works out (PERFORMANCE.md, section 11): the lacquer as a
	# coat of its own -- in a shader of its own, so no other preset pays for
	# it --, the paintings behind glass, and an occlusion that darkens what
	# the lamps light. Back on Alto all of it is as it was.
	var wood_shaders := func() -> Array: return ["wood", "panel", "trim", "door"].map(func(key: String) -> Shader: return scene.hotel.materials[key].shader)
	var canvas: StandardMaterial3D = scene.hotel.paintings()[0].mesh.material
	check("Ultra: barniz en capa propia, cuadros acristalados y oclusión sobre la luz de las lámparas", wood_shaders.call().all(func(shader: Shader) -> bool: return shader == scene.hotel.WOOD_LACQUER) and canvas.clearcoat_enabled and scene.environment.ssao_light_affect > 0.5 and scene.hotel.preset.surface_detail == 5.0)
	# The moulded kit (hotel_geometry.gd, "The moulded kit"): built with every
	# floor, shown by the preset. On Ultra its pieces are drawn and the plain
	# ones only stand in from far; anywhere else the plain ones are all there is.
	var kit_pieces := func() -> Array: return scene.hotel.kit_shown.filter(func(piece) -> bool: return is_instance_valid(piece))
	var plain_pieces := func() -> Array: return scene.hotel.kit_replaced.filter(func(piece) -> bool: return is_instance_valid(piece))
	var kinds := {}
	for piece in kit_pieces.call(): kinds[String(piece.name).rstrip("0123456789@")] = true
	check("El piso lleva el kit de molduras: rodapié, moldura, cornisa, paneles, rosetón, interruptores y rejilla", ["Model_moulding_skirting", "Model_moulding_rail", "Model_moulding_cornice", "Model_moulding_panel", "Model_moulding_rose", "Mesh_gold-detail", "Mesh_metal-detail"].all(func(kind: String) -> bool: return kinds.has(kind)) and not plain_pieces.call().is_empty())
	check("Ultra: el kit a la vista, de cerca, y las piezas lisas solo de lejos", scene.hotel.kit and kit_pieces.call().all(func(piece) -> bool: return piece.visible and piece.visibility_range_end > 15.0) and plain_pieces.call().all(func(piece) -> bool: return piece.visible and piece.visibility_range_begin > 20.0))
	var moulded: Script = scene.hotel.MOULDINGS
	var sound := true
	for mesh: ArrayMesh in [moulded.run("skirting"), moulded.run("rail"), moulded.run("cornice"), moulded.corner("skirting"), moulded.corner("rail"), moulded.corner("cornice"), moulded.panel(), moulded.rose()]:
		var arrays := mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if points.is_empty() or points.size() % 3 != 0 or points.size() != normals.size(): sound = false
		for corner in range(0, points.size(), 3):
			# Every face looks the way its normals say (clockwise is the front).
			var facing := (points[corner + 1] - points[corner]).cross(points[corner + 2] - points[corner])
			if facing.length() < 0.0000001 or facing.dot(normals[corner] + normals[corner + 1] + normals[corner + 2]) > 0.0 or absf(normals[corner].length() - 1.0) > 0.001: sound = false
	check("Las piezas del kit son mallas cerradas en su cara vista: normales de longitud uno y caras hacia donde dicen", sound and is_equal_approx(moulded.run("cornice").get_aabb().size.x, moulded.UNIT) and moulded.run("cornice").get_aabb().size.y < 0.17 and absf(moulded.panel().get_aabb().size.x - moulded.PANEL_WIDTH) < 0.001)
	settings.set_designed(2)
	check("Alto: sin kit, las piezas lisas a cualquier distancia", not scene.hotel.kit and kit_pieces.call().all(func(piece) -> bool: return not piece.visible) and plain_pieces.call().all(func(piece) -> bool: return piece.visible and piece.visibility_range_begin == 0.0))
	check("Alto: la madera con su shader de siempre, cuadros sin cristal y la oclusión de antes", wood_shaders.call().all(func(shader: Shader) -> bool: return shader == scene.hotel.WOOD) and not canvas.clearcoat_enabled and is_equal_approx(scene.environment.ssao_light_affect, 0.15) and is_equal_approx(scene.environment.ssao_radius, 1.2))
	# Muy bajo (PERFORMANCE.md, section 10): no lamp of the hotel casts a
	# shadow, and each lights only the layers of its own room; the torch
	# still casts. Back on another preset the lamps light everything again.
	settings.set_designed(PRESETS.VERY_LOW)
	scene.hotel.update_visibility(scene.player.position, true)
	var here_rooms: PackedInt32Array = scene.hotel.things_on(preload("res://game/world/generation/floor_definition.gd").planta_of(scene.player.position.y)).rooms
	check("Muy bajo: media resolución sin reconstruir, sin suavizado ni glow, superficies de una sola textura pequeña y sin lente", is_equal_approx(viewport.scaling_3d_scale, 0.5) and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR and viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED and not viewport.use_taa and not scene.environment.glow_enabled and scene.hotel.preset.surface_detail == 0.0 and scene.hotel.materials.plaster.get_shader_parameter("use_lite") == true and scene.hotel.materials.plaster.get_shader_parameter("albedo_map") == null and not preload("res://game/presentation/camcorder_look.gd").lens)
	var kept := true
	for i in here_rooms:
		var lamp: OmniLight3D = scene.hotel.lights[i]
		if lamp.has_meta("void"): continue
		if lamp.shadow_enabled or lamp.light_cull_mask != scene.hotel.room_layers.mask[i] or (lamp.light_cull_mask & scene.hotel.room_layers.layer[i]) == 0: kept = false
	check("Muy bajo: ninguna lámpara de sala proyecta sombra y cada una alumbra solo las capas de la suya", kept and not here_rooms.is_empty())
	check("Las dieciséis capas alcanzan: ninguna sala comparte capa con una lámpara que la alcance", int(scene.hotel.room_layers.clashes) == 0)
	check("Muy bajo: la linterna sigue proyectando sombra", scene.player.torch.shadow_enabled)
	check("Muy bajo: cada puerta se dibuja en dos mitades, una por sala", scene.hotel.door_halves.size() == scene.hotel.doors.size() and not scene.hotel.doors.is_empty())
	var plain_view: float = scene.player.camera.fov
	settings.set_designed(1)
	scene.hotel.update_visibility(scene.player.position, true)
	# The lens renders wider than it shows (camcorder_look.gd): without it the
	# camera has the designed field of view, and with it back, the wider one.
	check("Sin lente la cámara dibuja su campo de visión de diseño, y con ella de vuelta, el ancho", is_equal_approx(plain_view, preload("res://game/presentation/camcorder_look.gd").VIEW_FOV) and scene.player.camera.fov > plain_view + 5.0)
	var restored := true
	for i in here_rooms:
		var lamp: OmniLight3D = scene.hotel.lights[i]
		if lamp.has_meta("void"): continue
		if not lamp.shadow_enabled or lamp.light_cull_mask != 0xFFFFFFFF: restored = false
	check("Al volver a Medio las lámparas recuperan su sombra y alumbran todas las capas, y los materiales, sus mapas", restored and preload("res://game/presentation/camcorder_look.gd").lens and scene.hotel.materials.plaster.get_shader_parameter("use_lite") == false and scene.hotel.materials.plaster.get_shader_parameter("albedo_map") != null)
	settings.set_value("quality", 3)
	# Wall lamps are the many -- eight or sixteen to a public room -- and what
	# does not fit in the shadow atlas Godot draws without a shadow, which goes
	# straight through the wall into the dark room on the other side. Only the
	# nearest twelve cast, wherever the player stands. On Ultra the ones past
	# them are lit too (sconce_fill): with no shadow, and so each with nothing
	# to light but the layers of its own room.
	var floor_plan := preload("res://game/world/generation/floor_definition.gd")
	var every_room: int = scene.hotel.ROOM_LAYERS.ROOMS
	for quality in [3, 2]:
		settings.set_value("quality", quality)
		var most_casting := 0
		var most_filling := 0
		var in_place := true
		# The ceiling lamps too, on Ultra: twenty cast, the lit ones past them
		# light their own rooms' layers and no more (lamps_cast).
		var most_lamps := 0
		var lamps_filling := 0
		var lamps_in_place := true
		for room in scene.manifest.rooms:
			scene.hotel.update_visibility(floor_plan.position_of(room) + Vector3(0, 1.6, 0), true)
			var casting := 0
			var filling := 0
			for lamp in scene.hotel.sconce_lights:
				if not lamp.visible: continue
				if lamp.shadow_enabled:
					casting += 1
					if (lamp.light_cull_mask & every_room) != every_room or lamp.light_projector == null: in_place = false
				else:
					filling += 1
					if (lamp.light_cull_mask & every_room) == every_room or lamp.light_projector != null: in_place = false
			most_casting = maxi(most_casting, casting)
			most_filling = maxi(most_filling, filling)
			var lamps_casting := 0
			for lamp in scene.hotel.lights:
				if not lamp.visible: continue
				if lamp.shadow_enabled:
					lamps_casting += 1
					if (lamp.light_cull_mask & every_room) != every_room: lamps_in_place = false
				else:
					lamps_filling += 1
					if (lamp.light_cull_mask & every_room) == every_room or lamp.light_projector != null: lamps_in_place = false
			most_lamps = maxi(most_lamps, lamps_casting)
		if quality == 3:
			check("Nunca más de doce apliques proyectando sombra a la vez", most_casting > 0 and most_casting <= scene.hotel.SCONCES_LIT)
			check("Ultra: los apliques de más allá alumbran sin sombra y solo las capas de su sala", most_filling > 0 and in_place and scene.hotel.layered and not scene.hotel.static_light)
			check("Ultra: nunca más de veinte lámparas de techo con sombra, y las demás solo alumbran su sala", most_lamps > 0 and most_lamps <= 20 and lamps_filling > 0 and lamps_in_place)
		else:
			check("Alto: doce apliques con su sombra y ninguno más encendido, y veinte lámparas de techo con la suya como en Ultra", most_casting > 0 and most_casting <= scene.hotel.SCONCES_LIT and most_filling == 0 and in_place and scene.hotel.layered and most_lamps > 0 and most_lamps <= 20 and lamps_filling > 0 and lamps_in_place)
	# Medio keeps every lamp's shadow, and nothing is kept in its room by layers.
	settings.set_value("quality", 1)
	var medio_whole := true
	for room in scene.manifest.rooms:
		scene.hotel.update_visibility(floor_plan.position_of(room) + Vector3(0, 1.6, 0), true)
		for lamp in scene.hotel.lights:
			if lamp.visible and (not lamp.shadow_enabled or (lamp.light_cull_mask & every_room) != every_room): medio_whole = false
	check("Medio: todas las lámparas de techo encendidas con su sombra y alumbrando todas las capas", medio_whole and not scene.hotel.layered)
	settings.set_value("quality", 3)
	# The rooms with high ceilings hang a chandelier where the rest have a
	# dome: the room's own lamp, lit or out with it. Not the reception, which
	# keeps its red lamp.
	var hung := 0
	var hung_right := true
	for room in scene.manifest.rooms:
		if floor_plan.is_void(room): continue
		var fitting := scene.hotel.room_nodes[int(room.id)].get_node_or_null("Chandelier") as MeshInstance3D
		var wanted: bool = float(room.height) > scene.hotel.CHANDELIER_HEIGHT and int(room.type) != 0 and not (int(room.type) in [4, 7, 8, 9])
		if (fitting != null) != wanted: hung_right = false
		if fitting == null: continue
		hung += 1
		var lit_bulb: bool = fitting.get_surface_override_material(1) == null and (fitting.mesh.surface_get_material(1) as BaseMaterial3D).emission_enabled
		var out_bulb: bool = fitting.get_surface_override_material(1) != null and not (fitting.get_surface_override_material(1) as BaseMaterial3D).emission_enabled
		if (out_bulb if scene.hotel.dark_room(room) else lit_bulb) == false: hung_right = false
		var lamp: OmniLight3D = scene.hotel.lights[int(room.id)]
		if lamp.get_meta("profile") != scene.hotel.LIGHTING.profile("chandelier") or lamp.position.y > float(room.height) - 0.5: hung_right = false
	check("Las salas de techo alto cuelgan una lámpara de araña, encendida o apagada con su sala, y la recepción conserva la suya", hung > 0 and hung_right)
	# Bounce light (hotel_geometry.bounce_groups()): a volume is at full
	# strength up to its edge, so a lit stretch of corridor's is carried on
	# over the dark cell it runs on into -- or the light stopped in a straight
	# line across an open corridor. Never three volumes over a cell, and
	# every group still a rectangle of its own cells.
	var groups: Dictionary = scene.hotel.bounce_groups(0)
	var covered := {}
	var boxes_sound := true
	for hall in groups.halls:
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var area := 0.0
		for i: int in groups.halls[hall]:
			covered[i] = int(covered.get(i, 0)) + 1
			var span: Vector2 = floor_plan.size_of(scene.manifest.rooms[i])
			var at: Vector3 = scene.hotel.room_nodes[i].position
			low = Vector2(minf(low.x, at.x - span.x * 0.5), minf(low.y, at.z - span.y * 0.5))
			high = Vector2(maxf(high.x, at.x + span.x * 0.5), maxf(high.y, at.z + span.y * 0.5))
			area += span.x * span.y
		# (A hall that is not a rectangle has no volume: only stretches count.)
		if bool(scene.manifest.rooms[groups.halls[hall][0]].get("corridor", false)) and absf((high.x - low.x) * (high.y - low.y) - area) > 0.5: boxes_sound = false
	var seams_left := 0
	var seams := 0
	for pair in scene.manifest.get("merged", []):
		var a: Dictionary = scene.manifest.rooms[int(pair[0])]
		var b: Dictionary = scene.manifest.rooms[int(pair[1])]
		if floor_plan.planta_of(floor_plan.position_of(a).y) != 0 or scene.hotel.dark_room(a) == scene.hotel.dark_room(b): continue
		seams += 1
		if not covered.has(int(a.id if scene.hotel.dark_room(a) else b.id)): seams_left += 1
	check("El rebote de un pasillo iluminado sigue sobre la celda a oscuras en la que continúa, sin tres volúmenes sobre ninguna", seams > 0 and seams_left == 0 and boxes_sound and covered.values().all(func(count: int) -> bool: return count <= 2))
	# The torch on the renderer of the modest machines: Compatibility draws no
	# light projectors at all, so there the beam is the cone itself, narrower
	# and with its own falloff, and its shadow needs a bias for the depth it
	# has or it stripes every wall it is pointed at.
	var torch_owner := preload("res://game/player/hotel_player.gd")
	check("En Forward+ el haz de la linterna lleva su proyector", not torch_owner.plain_beam() and scene.player.torch.light_projector != null)
	var plain := SpotLight3D.new()
	plain.light_projector = torch_owner.beam_pattern()
	torch_owner.shape_plain_beam(plain)
	check("Y en Compatibilidad se dibuja con el cono y su propio sesgo", plain.light_projector == null and plain.spot_angle < 32.0 and plain.spot_angle_attenuation > 1.0 and plain.shadow_bias > 0.2 and plain.shadow_normal_bias > 2.0)
	plain.free()
	# The tape does not start until it has asked for headphones: the floor is
	# played by ear, and whoever opens the game on speakers has no way of
	# knowing what they are missing. It goes on the black, before the blue.
	scene.ui.play_intro()
	for i in 60: await scene.get_tree().process_frame
	var notice: Control = scene.ui.intro.get_node_or_null("Headphones")
	var tape: ColorRect = scene.ui.intro.get_node_or_null("Tape")
	check("La cinta pide auriculares antes de arrancar", notice != null and notice.modulate.a > 0.5 and tape != null and tape.modulate.a == 0.0)
	scene.ui.finish_intro()
	check("Y saltar la entrada se lo lleva con ella", not is_instance_valid(scene.ui.intro))
	settings.set_value("quality", 1)
	var session = scene.session
	check("Cuotas correctas", quota(session, 1) == 1 and quota(session, 2) == 1 and quota(session, 3) == 2 and quota(session, 4) == 2)
	session.roster_count = 1
	session.set_refuge(1, true)
	session.update_goal(0.1, session.can_depart())
	check("Con la cuota dentro, la puerta de la etapa se da por abierta", session.goal.ready)
	session.set_refuge(1, false)
	session.update_goal(0.1, session.can_depart())
	check("Salir del refugio deja de cumplir la condición", not session.goal.ready and not session.can_depart())
	session.set_refuge(1, true)
	check("Refugio protege de captura de prueba", not session.capture(1))
	# Crossing is what closes a stage; at this level of the game there is no
	# door, so the stage is closed by hand, as hotel_main does when somebody
	# steps through it.
	session.update_goal(0.1, true)
	session.finish_stage()
	check("Salida libre sin objetos", session.state == session.State.TRANSITION)
	session._process(1.3)
	check("Cerrar una etapa deja el piso en marcha", session.state == session.State.PLAYING and session.stage == 2)
	# Through to the last one, which is the only one that ends the floor: in a
	# real floor that is done by stepping through the door with the code lock,
	# which at this level of the game is the same call.
	while session.more_stages():
		session.finish_stage()
		session._process(1.3)
	session.finish_stage()
	session._process(1.3)
	check("Victoria y eliminación de checkpoint completado", session.state == session.State.WON and session.checkpoint().is_empty())
	await scene.start_floor(81)
	# Alone there is nobody to be forgiven with: the floor ends at the first
	# collapse (a team gets one over, which stages_test drives).
	session.capture(1)
	check("Muerte de prueba permite reintento", session.state == session.State.FAILED and session.restarts == 0)
	await scene.start_floor(81)
	check("Reintento reproduce piso y limpia estado", session.state == session.State.PLAYING and scene.manifest.seed == 81 and session.stage == 1 and not session.goal.ready)
	var file := FileAccess.open(session.checkpoint_path, FileAccess.WRITE)
	file.store_string('{"format":1,"generator":999,"seed":81,"floor":1}')
	file.close()
	check("Checkpoint incompatible no se sustituye", session.checkpoint().is_empty() and session.message.contains("incompatible") and FileAccess.get_file_as_string(session.checkpoint_path).contains("999"))
	await scene.start_floor(123, true)
	var fallback_snapshot := JSON.stringify(scene.manifest)
	var fallback_checkpoint: Dictionary = session.checkpoint()
	check("Uso de respaldo registrado en checkpoint", fallback_checkpoint.get("fallback", false) and fallback_checkpoint.seed == 123)
	await scene.start_floor(int(fallback_checkpoint.seed), fallback_checkpoint.fallback)
	check("Continuar reproduce también el mapa de respaldo", JSON.stringify(scene.manifest) == fallback_snapshot)
	session.write_checkpoint()
	var report := FileAccess.open("res://evidence/hotel_tests.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failed == 0, "checks": checks, "seed_count": 1000, "fallbacks": fallback_count, "seed_failures": failures}, "\t"))
	report.close()
	print("HOTEL_RESULT=", checks.size() - failed, "/", checks.size())
	paused = false
	scene.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

func quota(session, count: int) -> int:
	session.roster_count = count
	return session.minimum_survivors()
