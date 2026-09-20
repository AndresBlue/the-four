extends SceneTree
const GEN := preload("res://game/world/generation/map_generator.gd")
const WALKER := preload("res://game/world/generation/wall_walker.gd")
const VALIDATOR := preload("res://game/world/generation/map_validator.gd")
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()
func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title)

func run() -> void:
	var generator := GEN.new()
	var fallback_count := 0
	var failures: Array = []
	var used_types := {}
	var wing_leaks: Array = []
	var small_wings: Array = []
	var walked: Array = []
	var number_faults: Array = []
	var climbing := 0
	var falling := 0
	var one_door: Array = []
	var wall_solved: Array = []
	var sealed_landing: Array = []
	for seed_value in 1000:
		var data := generator.generate(seed_value)
		if data.fallback: fallback_count += 1
		if not VALIDATOR.new().validate(data).is_empty(): failures.append(seed_value)
		for room in data.rooms: used_types[room.type] = true
		# Wings: no way from one to the next except its gate, and each one big
		# enough to be a stage of its own.
		var gate_keys := {}
		for gate in data.gates:
			if int(gate.get("beyond", -1)) >= 0: gate_keys["%d:%d" % [mini(int(gate.room), int(gate.beyond)), maxi(int(gate.room), int(gate.beyond))]] = true
		var counts := [0, 0, 0]
		for room in data.rooms: counts[int(room.wing)] += 1
		if counts.min() < 20: small_wings.append(seed_value)
		for edge in data.edges:
			if int(data.rooms[int(edge[0])].wing) == int(data.rooms[int(edge[1])].wing): continue
			if not gate_keys.has("%d:%d" % [mini(int(edge[0]), int(edge[1])), maxi(int(edge[0]), int(edge[1]))]): wing_leaks.append(seed_value)
		var entrance: int = int(data.start)
		var rooms_walked := 0
		for gate in data.gates:
			var distances: Array = GEN.distance_map(data.adjacency, entrance)
			rooms_walked += maxi(0, int(distances[int(gate.room)]))
			if int(gate.get("beyond", -1)) >= 0: entrance = int(gate.beyond)
		walked.append(rooms_walked)
		# Every refuge is entered by one door and no other. The last one has
		# the locked door to the landing behind it as well, and that landing
		# is a dead end: nothing else opens on to it.
		var landing := int(data.gates[data.gates.size() - 1].get("beyond", -1))
		for wing in 3:
			var refuge: int = int(data.refuges[wing])
			var ways: Array = data.adjacency[refuge].filter(func(id): return int(data.rooms[id].wing) == wing and id != landing)
			if ways.size() != 1: one_door.append([seed_value, wing, ways.size()])
		if landing < 0 or data.adjacency[landing].size() != 1 or not bool(data.rooms[landing].get("landing", false)): sealed_landing.append(seed_value)
		# And the exit room is not found by walking with a hand on the wall:
		# not with either hand, not setting off any of the four ways.
		var last_wing: int = int(data.gates[1].beyond) if int(data.gates[1].get("beyond", -1)) >= 0 else int(data.start)
		if WALKER.hits(data.rooms, data.adjacency, int(data.width), int(data.height), last_wing, int(data.refuges[2])) > 0: wall_solved.append(seed_value)
		# The numbers: each wing its hundred, never two doors the same, and
		# only the rooms let to somebody carry one.
		var seen_numbers := {}
		for room in data.rooms:
			var number := int(room.get("number", 0))
			if number == 0:
				if GEN.numbered(room): number_faults.append(seed_value)
				continue
			if not GEN.numbered(room) or seen_numbers.has(number): number_faults.append(seed_value)
			if number / 100 != int(room.wing) + 1: number_faults.append(seed_value)
			seen_numbers[number] = true
		# And they are no longer a compass: whether they climb or fall as one
		# walks into a wing is drawn, so over a thousand floors it is a coin.
		var wing_entrance: int = int(data.start)
		for wing in 3:
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
			if wing < data.gates.size() and int(data.gates[wing].get("beyond", -1)) >= 0: wing_entrance = int(data.gates[wing].beyond)
	check("1.000 semillas: grafos y módulos válidos", failures.is_empty())
	check("Cada refugio se entra por una sola puerta", one_door.is_empty())
	check("Detrás de la última puerta solo hay el rellano, sin otra entrada", sealed_landing.is_empty())
	check("Ir pegado a una pared no encuentra la habitación de salida", wall_solved.is_empty())
	check("La numeración es de hotel: una centena por ala, sin repetir y sin placa en servicio", number_faults.is_empty())
	var drawn: float = float(climbing) / maxf(1.0, float(climbing + falling))
	check("Subir de número no lleva a ninguna parte", drawn > 0.35 and drawn < 0.65)
	check("Las alas solo se comunican por su puerta de etapa", wing_leaks.is_empty())
	check("Ningún ala se queda sin habitaciones", small_wings.is_empty())
	var shortest: int = walked.min()
	check("Las tres etapas obligan a recorrer el piso", shortest >= 20 and float(walked.reduce(func(a, b): return a + b, 0)) / walked.size() >= 30.0)
	check("Tasa de respaldo inferior al 1%", fallback_count < 10)
	check("20 tipos de módulo presentes en el lote", used_types.size() == 20)
	check("Semilla reproducible", JSON.stringify(generator.generate(81)) == JSON.stringify(generator.generate(81)))
	check("Semillas distintas cambian el mapa", JSON.stringify(generator.generate(81)) != JSON.stringify(generator.generate(82)))
	var scene = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check("Menú principal y cursor libre", scene.ui.buttons.has("new") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	check("El menú principal lleva Multijugador y no Personaje", scene.ui.buttons.has("multiplayer") and not scene.ui.buttons.has("characters"))
	scene.on_action("multiplayer")
	check("Personaje está dentro de Multijugador", scene.ui.screen == "multiplayer" and scene.ui.buttons.has("characters"))
	scene.on_action("main")
	await scene.start_floor(81)
	await physics_frame
	check("Se inicia un hotel grande y libre de objetivos", scene.manifest.rooms.size() >= 100 and scene.session.state == scene.session.State.PLAYING)
	check("Validación física de todos los pasos y coberturas", scene.physical_errors.is_empty())
	# Each face of a door shows the number of the room behind it.
	var FLOOR := preload("res://game/world/generation/floor_definition.gd")
	var numbers_ok := true
	var plaques_ok := true
	for each in scene.hotel.doors:
		var labels: Array = each.find_children("*", "Label3D", true, false)
		for label in labels:
			# Measured with the door shut, whatever its leaf is doing now.
			var facing := Basis(Vector3.UP, each.closed_rotation + label.rotation.y).z
			var in_front: Dictionary = FLOOR.room_at(scene.manifest.rooms, each.doorway + facing * 1.5)
			var behind: Dictionary = FLOOR.room_at(scene.manifest.rooms, each.doorway - facing * 1.5)
			if in_front.is_empty() or behind.is_empty() or label.text != str(int(behind.get("number", 0))): numbers_ok = false
		# And only the rooms that have a number show a plaque: service,
		# circulation and the refuge show a bare leaf.
		var across := Basis(Vector3.UP, each.closed_rotation).z
		var wanted := 0
		for step in [1.5, -1.5]:
			var room: Dictionary = FLOOR.room_at(scene.manifest.rooms, each.doorway + across * step)
			if int(room.get("number", 0)) > 0: wanted += 1
		if labels.size() != wanted: plaques_ok = false
	check("El número de cada cara de puerta indica la habitación de detrás", numbers_ok)
	check("Servicio, pasillo y refugio no llevan placa", plaques_ok)
	var dark: Array = scene.hotel.lights.filter(func(light): return light.has_meta("off"))
	var reception_lit: bool = scene.manifest.rooms.all(func(room): return int(room.type) != 0 or not scene.hotel.lights[room.id].has_meta("off"))
	check("Algunas habitaciones tienen la luz apagada, nunca la recepción", dark.size() > 0 and float(dark.size()) < float(scene.hotel.lights.size()) * 0.4 and reception_lit and dark.all(func(light): return not light.visible))
	var door = scene.hotel.doors[0]
	door.open_immediately()
	var across: Vector3 = Basis(Vector3.UP, door.closed_rotation) * Vector3(0, 0, 1)
	scene.player.position = door.doorway + across * 0.15 + Vector3(0, 0.04, 0)
	check("Puerta no cierra con jugador en el umbral", not door.toggle())
	scene.player.position = door.doorway + across * 0.8 + Vector3(0, 0.04, 0)
	check("Puerta cierra con el jugador ya pasado el marco", door.toggle(false, false))
	scene.player.position = Vector3(0, 0.04, 0)
	for frame in 45: await physics_frame
	check("Puerta cerrada recupera colisión", not door.opened and door.collision_layer == 8)
	scene.player.position = door.doorway + across * 2.8 + Vector3(0, 0.04, 0)
	scene.player.rotation.y = door.closed_rotation
	scene.player.camera.rotation = Vector3.ZERO
	await physics_frame
	check("Interacción enfoca puerta a casi 3 m", scene.focused_door() == door)
	scene.player.position = door.doorway + across * 4.2 + Vector3(0, 0.04, 0)
	await physics_frame
	check("Interacción no alcanza puerta distante", scene.focused_door() != door)
	door.open_immediately()
	scene.player.position = door.doorway + across * 2.0 + Vector3(0, 0.04, 0)
	scene.player.rotation.y = door.closed_rotation + PI
	await physics_frame
	check("Puerta abierta a la espalda se puede cerrar", scene.focused_door() != door and scene.door_behind() == door)
	door.toggle(false, false)
	for frame in 45: await physics_frame
	scene.player.position = Vector3(0, 0.04, 0)
	door.toggle(true)
	for frame in 20: await physics_frame
	check("Apertura lenta respeta su duración", door.moving)
	for frame in 90: await physics_frame
	check("Puerta abierta recupera colisión sin empujar", door.opened and not door.moving and door.collision_layer == 8)
	scene.player.rotation.y = -PI / 2 if scene.manifest.adjacency[0].has(1) else PI
	check("Quince tipos de prop como mínimo", preload("res://game/world/generation/floor_definition.gd").RECIPES.reduce(func(acc, recipe):
		for prop in recipe: acc[prop] = true
		return acc, {}).size() >= 15)
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
	# Graphics presets (graphics_presets.gd): four, each applied whole, the
	# render scale with it.
	settings.set_value("quality", 3)
	settings.load_settings()
	check("El preset Ultra se guarda y un valor fuera de rango se corrige", settings.values.quality == 3 and settings.sanitize("quality", 9) == 3 and settings.sanitize("quality", -2) == 0)
	var viewport: Viewport = scene.get_viewport()
	settings.set_value("quality", 0)
	check("Bajo: escala 0,67 con FSR, FXAA, sin SSAO ni volumétrica y sin sombra propia", is_equal_approx(viewport.scaling_3d_scale, 0.67) and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR and viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA and not scene.environment.ssao_enabled and not scene.environment.volumetric_fog_enabled and scene.player.avatar.meshes.all(func(mesh): return mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	settings.set_value("quality", 1)
	check("Medio: TAA, SSAO sin SSIL y lámparas hasta 42 m", viewport.use_taa and scene.environment.ssao_enabled and not scene.environment.ssil_enabled and is_equal_approx(scene.hotel.lights[0].distance_fade_shadow, 42.0) and scene.player.avatar.meshes.all(func(mesh): return mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
	settings.set_value("quality", 3)
	check("Ultra: MSAA 4×, SSR, lámparas hasta 64 m y salas hasta 82 m", viewport.msaa_3d == Viewport.MSAA_4X and scene.environment.ssr_enabled and is_equal_approx(scene.hotel.lights[0].distance_fade_shadow, 64.0) and scene.hotel.preset.room_reach == 82.0)
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
	# The first collapse of a floor is forgiven; the second ends it.
	session.capture(1)
	session._process(session.RESTART_WAIT + 0.1)
	session.capture(1)
	check("Muerte de prueba permite reintento", session.state == session.State.FAILED)
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
