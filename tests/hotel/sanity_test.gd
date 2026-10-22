extends SceneTree
## The mind: a meter nobody sees, which falls in the dark and comes back in
## the light, makes the floor lie on the way down, and at the bottom marks the
## body with motes the creature senses from anywhere. This drives it on a real
## floor and checks what each part of it actually does.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
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

## A room of the floor with its lamps out, and one with them on.
func room_of(dark: bool) -> Dictionary:
	for room in level.manifest.rooms:
		# A room to stand in: not the refuge, its lobby, a corridor or a cell
		# the planta does not use.
		if int(room.type) == 19 or bool(room.get("landing", false)) or bool(room.get("corridor", false)) or FLOOR.is_void(room): continue
		if level.hotel.dark_ids.has(int(room.id)) == dark: return room
	return {}

## Stands the player in a room and lets the meter run for so many seconds.
func stand(room: Dictionary, seconds: float, torch := false, hidden := false) -> float:
	level.player.global_position = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	level.player.velocity = Vector3.ZERO
	level.player.torch.visible = torch
	level.player.hidden = hidden
	var before: float = level.player.sanity
	await frames(int(seconds * 60.0))
	return before - level.player.sanity

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	# The floor as two or three play it (hotel_main.drawn_for): what follows
	# walks known places of it.
	level.drawn_for = 2
	await level.start_floor(81)
	var player = level.player
	# The creature would come looking and move the player about.
	level.locust.set_physics_process(false)
	level.locust.global_position = Vector3(0, -80, 0)
	check("Un piso empieza con la cabeza entera", is_equal_approx(player.sanity, 100.0) and not player.burnt)
	var dark := room_of(true)
	var lit := room_of(false)
	check("El piso tiene salas apagadas y encendidas", not dark.is_empty() and not lit.is_empty())

	# --- Falling and coming back ---------------------------------------------------
	var in_dark: float = await stand(dark, 2.0)
	player.sanity = 100.0
	var with_torch: float = await stand(dark, 2.0, true)
	player.sanity = 100.0
	var shut_in: float = await stand(dark, 2.0, false, true)
	check("A oscuras la cordura baja", in_dark > 0.0)
	check("La linterna la frena sin detenerla", with_torch > 0.0 and with_torch < in_dark * 0.6)
	check("Encerrado en un armario baja lo mismo que a oscuras", absf(shut_in - in_dark) < in_dark * 0.1)
	player.sanity = 40.0
	var lost: float = await stand(lit, 2.0)
	check("En una sala encendida se recupera", lost < 0.0 and player.sanity > 40.0)
	# Time to burn out, as the design says: seven and a half minutes of dark
	# (or wardrobe), and with the torch on well over a quarter of an hour.
	var dark_seconds: float = 100.0 / level.sanity.SANITY_DARK
	var torch_seconds: float = dark_seconds / level.sanity.SANITY_TORCH
	check("A oscuras, quemarse del todo cuesta siete minutos y medio", dark_seconds > 420.0 and dark_seconds < 480.0 and absf(in_dark - 2.0 * level.sanity.SANITY_DARK) < 0.05)
	check("Con la linterna, casi veinte", torch_seconds > 1000.0 and torch_seconds < 1250.0)

	# --- Seeing it ----------------------------------------------------------------
	player.sanity = 100.0
	level.sanity.sight_rest = 0.0
	level.locust.global_position = FLOOR.position_of(lit) + Vector3(3.0, 0.04, 0)
	level.locust.grace = 0.0
	# Its back to the player, looking at nothing in particular.
	level.locust.rotation.y = 0.0
	level.locust.visual.look_point = Vector3.INF
	player.global_position = FLOOR.position_of(lit) + Vector3(-1.5, 0.04, 0)
	player.rotation.y = -PI / 2
	player.camera.rotation.x = 0.0
	player.torch.visible = true
	await frames(4)
	var frightened: float = 100.0 - player.sanity
	check("Verla de refilón cuesta poco", frightened >= level.sanity.SANITY_GLIMPSE * 0.9 and frightened < level.sanity.SANITY_GLIMPSE * 1.5)
	# And then it turns its head to the player: the bigger fright, charged
	# once and only for what the glimpse did not cost.
	level.locust.visual.look_point = player.camera.global_position
	await frames(4)
	var stared: float = 100.0 - player.sanity
	check("Que te mire de cara cuesta mucho más", stared >= level.sanity.SANITY_STARE * 0.9 and stared < level.sanity.SANITY_STARE * 1.2)
	var again: float = player.sanity
	await frames(30)
	# Standing in a lit room it is coming back, so what is checked is that
	# looking at it again did not take a second bite.
	check("Mirarla un rato es un susto, no uno por fotograma", player.sanity >= again)
	level.locust.global_position = Vector3(0, -80, 0)

	await door_sight_regression()

	# --- The floor lying ----------------------------------------------------------
	player.sanity = 100.0
	level.sanity.hallucination_wait = 0.0
	await frames(8)
	check("Con la cabeza entera el piso no miente", level.sanity.hallucination_wait <= 0.0)
	player.sanity = 5.0
	level.sanity.hallucination_wait = 0.0
	player.global_position = FLOOR.position_of(lit) + Vector3(0, 0.04, 0)
	await frames(8)
	check("Con la cordura baja suenan cosas que no están", level.sanity.hallucination_wait > 0.0)
	var heard_before: int = level.locust.driver.heard.size() if is_instance_valid(level.locust.driver) else 0
	for i in 12:
		level.sanity.hallucination_wait = 0.0
		await frames(4)
	var heard_after: int = level.locust.driver.heard.size() if is_instance_valid(level.locust.driver) else 0
	check("Las alucinaciones no son ruido: la criatura no oye ninguna", heard_after == heard_before)

	# --- Burnt out ----------------------------------------------------------------
	# In the dark, where it happens: in a lit room it would be coming back up
	# before the meter ever hit the bottom.
	player.global_position = FLOOR.position_of(dark) + Vector3(0, 0.04, 0)
	player.torch.visible = false
	player.sanity = 0.0
	await frames(4)
	check("A cero, el cuerpo queda marcado", player.burnt)
	check("Y no se le ve nada encima: es cosa de la criatura", player.avatar.find_children("*", "GPUParticles3D", true, false).is_empty())
	check("La marca aparece en lo que sabe el director", level.sanity.burnt_survivors().size() == 1)
	# The creature is no longer told where: the director is, and plays it
	# (loop_test checks how). Standing still for a while, it is not sent here.
	level.locust.global_position = FLOOR.position_of(room_far_from(player.global_position)) + Vector3(0, 0.04, 0)
	level.locust.set_mode(level.locust.Mode.PATROL)
	await frames(90)
	check("La criatura no recibe el sitio de quien se quemó", not level.locust.has_method("smell_burnt") and level.locust.mode == level.locust.Mode.PATROL and level.locust.destination.distance_to(player.global_position) > 3.0)
	# Coming back takes light and time, not a step into a lit room.
	player.sanity = level.sanity.SANITY_BACK - 1.0
	await frames(4)
	check("Volver en sí no es instantáneo", player.burnt)
	player.global_position = FLOOR.position_of(lit) + Vector3(0, 0.04, 0)
	player.sanity = level.sanity.SANITY_BACK + 1.0
	await frames(4)
	check("Con cordura suficiente deja de estar marcado", not player.burnt)

	# --- What the screen says -----------------------------------------------------
	player.global_position = FLOOR.position_of(lit) + Vector3(0, 0.04, 0)
	player.sanity = 100.0
	await frames(3)
	var calm: float = level.post_material.get_shader_parameter("vhs")
	player.sanity = 1.0
	await frames(3)
	var frayed: float = level.post_material.get_shader_parameter("vhs")
	check("La cinta se estropea conforme se va la cabeza", frayed > calm * 1.5)
	level.settings.values.reduced = true
	level.apply_settings()
	await frames(3)
	check("Con efectos reducidos no se toca la imagen", is_equal_approx(level.post_material.get_shader_parameter("vhs"), 0.0))
	level.settings.values.reduced = false
	level.apply_settings()

	# --- The creature where it is not ------------------------------------------------
	await phantom_passage_checks(lit)
	await phantom_sight_checks()

	# --- A new floor ---------------------------------------------------------------
	level.drawn_for = 2
	await level.start_floor(81)
	check("Un piso nuevo empieza con la cabeza entera otra vez", is_equal_approx(level.player.sanity, 100.0) and not level.player.burnt)
	var file := FileAccess.open("res://evidence/sanity_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("SANITY_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

## A room of the first wing as far from a point as the floor allows.
func room_far_from(point: Vector3) -> Dictionary:
	var best: Dictionary = level.manifest.rooms[int(level.manifest.start)]
	for room in level.manifest.rooms:
		if int(room.wing) != 0 or bool(room.get("landing", false)) or FLOOR.is_void(room): continue
		if FLOOR.position_of(room).distance_to(point) > FLOOR.position_of(best).distance_to(point): best = room
	return best

## A real swinging door in an isolated space: closed, moving, then clear.
func door_sight_regression() -> void:
	var player = level.player
	var player_before: Transform3D = player.global_transform
	var creature_before: Transform3D = level.locust.global_transform
	player.set_physics_process(false)
	player.global_position = Vector3(1, 100, 3)
	player.rotation = Vector3.ZERO
	level.locust.global_position = Vector3(1, 100, -3)
	level.locust.grace = 0.0
	var door = preload("res://game/world/interactables/hotel_door.gd").new()
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	collision.shape = box
	door.add_child(collision)
	level.add_child(door)
	door.global_position = Vector3(0, 101.5, 0)
	door.set_state(false)
	await frames(3)
	check("Una puerta cerrada impide el susto visual", not level.sanity.sees_creature(player, true))
	# Its leaf remains an occluder while temporarily non-solid to bodies.
	door.moving = true
	door.collision_layer = door.GHOST
	await frames(2)
	check("La hoja en movimiento sigue ocultando a la criatura", not level.sanity.sees_creature(player, true))
	door.set_state(true)
	await frames(3)
	check("Una puerta abierta permite verla por el hueco", level.sanity.sees_creature(player, true))
	door.queue_free()
	player.global_transform = player_before
	level.locust.global_transform = creature_before
	player.set_physics_process(true)
	await frames(2)

## The creature that walks past and is not there: heard like the real one,
## the aura and all, and nothing on the floor hears it.
func phantom_passage_checks(lit: Dictionary) -> void:
	var player = level.player
	var audio = level.world_audio
	var was_enabled: bool = audio.enabled
	audio.enabled = true
	player.global_position = FLOOR.position_of(lit) + Vector3(0, 0.04, 0)
	player.sanity = 20.0
	level.locust.global_position = Vector3(0, -80, 0)
	var known_before: Vector3 = level.locust.last_known
	var mode_before: int = level.locust.mode
	# One may be walking already, from the lies told above.
	if is_instance_valid(level.sanity.passage): level.sanity.passage.stop()
	audio.aura.reset()
	var started: bool = level.sanity.walk_past()
	check("Con la cabeza yéndose, la criatura pasa cerca sin estar", started and level.sanity.passage.walking())
	check("Y sus mentiras dicen de dónde sale", level.sanity.lies.walk_start() == level.sanity.passage.path[0])
	var peak := 0.0
	var nearest := INF
	var presence := false
	for i in 240:
		await physics_frame
		peak = maxf(peak, float(audio.aura.intensity))
		presence = presence or audio.presence_phantom
		if audio.phantom_point != Vector3.INF: nearest = minf(nearest, audio.phantom_point.distance_to(player.global_position))
	check("Y suena como ella: el aura sube sin criatura cerca (%.2f)" % peak, peak > 0.1 and presence)
	check("Sin acercarse nunca a menos de 8 m", nearest >= level.sanity.passage.CLOSEST - 0.5)
	check("Pero no es un ruido: la criatura no se entera", level.locust.last_known == known_before and int(level.locust.mode) == mode_before)
	level.sanity.passage.stop()
	await frames(2)
	check("Y al acabar no queda nada", audio.phantom_point == Vector3.INF and level.sanity.lies.walk_start() == Vector3.INF)
	audio.enabled = was_enabled

## The creature seen where it is not: only where it could be (its head round
## an open door with its body behind the wall, or at the end of a long
## corridor), gone at a quick turn or out of view, and nothing of it is
## anything to anybody else.
func phantom_sight_checks() -> void:
	var player = level.player
	var camera: Camera3D = player.camera
	player.sanity = 20.0
	player.torch.visible = true
	var sight = level.sanity.ensure_sight()
	sight.ensure_model()
	var placed := 0
	var wrong := 0
	var peeks := 0
	var kept := {}
	for room in level.manifest.rooms:
		if int(room.wing) != 0 or FLOOR.is_void(room) or level.off_limits_rooms().has(int(room.id)): continue
		for turn in 12:
			player.global_position = FLOOR.closest(level.get_world_3d().navigation_map, FLOOR.position_of(room)) + Vector3(0, 0.04, 0)
			player.rotation.y = TAU * turn / 12.0
			camera.rotation.x = 0.0
			if not sight.place(camera): continue
			placed += 1
			var eye: Vector3 = camera.global_position
			var gap: float = sight.face_point.distance_to(eye)
			if sight.kind == "peek":
				peeks += 1
				if not sight.clear(eye, sight.face_point) or not sight.hidden_body(eye) or gap < sight.PEEK_RANGE.x - 2.0 or gap > sight.PEEK_RANGE.y + 3.0:
					wrong += 1
					print("MAL asomada a %.1f m · cabeza %s · cuerpo tapado %s" % [gap, sight.clear(eye, sight.face_point), sight.hidden_body(eye)])
			elif gap < sight.STAND_RANGE.x - 2.0 or gap > sight.STAND_RANGE.y + 3.0:
				wrong += 1
				print("MAL de pie a %.1f m" % gap)
			if kept.is_empty(): kept = {"position": player.global_position, "yaw": player.rotation.y, "kind": sight.kind}
			sight.kind = ""
	check("La bestia imaginada tiene dónde asomarse (%d sitios, %d puertas)" % [placed, peeks], placed > 0)
	check("Y solo donde puede: la cabeza a la vista y el cuerpo tras la pared, o al fondo de un pasillo", wrong == 0)
	# Put back where it was found, then looked at, then the head turned away fast.
	player.global_position = kept.get("position", player.global_position)
	player.rotation.y = float(kept.get("yaw", 0.0))
	var again: bool = sight.place(camera)
	if again:
		sight.begin()
		var towards: Vector3 = sight.face_point - camera.global_position
		player.rotation.y = atan2(-towards.x, -towards.z)
		await frames(3)
		check("Mirada, se deja ver", sight.showing() and sight.seen_for >= 0.0 and sight.model.visible)
		check("Y no es de nadie más: sin cuerpo, sin grupos, fuera de los supervivientes", sight.model.find_children("*", "CollisionObject3D", true, false).is_empty() and sight.model.get_groups().is_empty() and not level.survivors().has(sight.model))
		player.rotation.y += deg_to_rad(12.0)
		await frames(2)
		check("Un giro rápido de cabeza y se esfuma", not sight.showing() and not sight.model.visible and sight.last_end in ["giro", "fuera de vista"])
		sight.rest = 0.0
		player.rotation.y = float(kept.get("yaw", 0.0))
		if sight.place(camera):
			sight.begin()
			towards = sight.face_point - camera.global_position
			player.rotation.y = atan2(-towards.x, -towards.z)
			await frames(3)
			player.rotation.y += PI
			await frames(2)
			check("Y en cuanto sale de la vista, también", not sight.showing() and sight.last_end == "fuera de vista")
	else: check("Mirada, se deja ver", false)
	level.bot_match = true
	check("Nunca para los bots ni el observador", not sight.allowed())
	level.bot_match = false
	player.sanity = 100.0
	player.torch.visible = false
