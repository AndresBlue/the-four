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
		if int(room.type) == 19 or bool(room.get("landing", false)): continue
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
	check("Encerrado en un armario baja más deprisa que a oscuras", shut_in > in_dark)
	player.sanity = 40.0
	var lost: float = await stand(lit, 2.0)
	check("En una sala encendida se recupera", lost < 0.0 and player.sanity > 40.0)
	# Time to burn out in the worst case, as the design says: minutes, not
	# seconds, and a wardrobe is the fastest way there.
	var wardrobe_seconds: float = 100.0 / (level.sanity.SANITY_DARK * level.sanity.SANITY_HIDDEN)
	check("Quemarse del todo cuesta minutos, no segundos", wardrobe_seconds > 90.0 and wardrobe_seconds < 180.0)

	# --- Seeing it ----------------------------------------------------------------
	player.sanity = 100.0
	level.sanity.sight_rest = 0.0
	level.locust.global_position = FLOOR.position_of(lit) + Vector3(3.0, 0.04, 0)
	level.locust.grace = 0.0
	player.global_position = FLOOR.position_of(lit) + Vector3(-1.5, 0.04, 0)
	player.rotation.y = -PI / 2
	player.camera.rotation.x = 0.0
	player.torch.visible = true
	await frames(4)
	var frightened: float = 100.0 - player.sanity
	check("Verla de cerca cuesta un mordisco de cordura", frightened >= level.sanity.SANITY_SIGHT * 0.9)
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
	check("La marca aparece en lo que el nivel le cuenta a la criatura", level.sanity.burnt_survivors().size() == 1)
	# It is told where they are and it goes, however far away it is.
	level.locust.global_position = FLOOR.position_of(room_far_from(player.global_position)) + Vector3(0, 0.04, 0)
	level.locust.set_mode(level.locust.Mode.PATROL)
	level.locust.smell_burnt(player.global_position)
	check("La criatura sabe dónde está y va", level.locust.mode == level.locust.Mode.INVESTIGATE and level.locust.destination.distance_to(player.global_position) < 0.5)
	# Not into the refuge: that is still the one safe room.
	level.locust.set_mode(level.locust.Mode.PATROL)
	var refuge: Vector3 = FLOOR.position_of(level.manifest.rooms[level.refuge_room()])
	level.locust.smell_burnt(refuge)
	check("Pero no entra al refugio por ellas", level.locust.mode == level.locust.Mode.PATROL)
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

	# --- A new floor ---------------------------------------------------------------
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
	var best: Dictionary = level.manifest.rooms[0]
	for room in level.manifest.rooms:
		if int(room.wing) != 0 or bool(room.get("landing", false)): continue
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
