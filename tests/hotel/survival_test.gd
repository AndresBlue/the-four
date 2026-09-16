extends SceneTree
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
func face(enemy, point: Vector3) -> void:
	var d: Vector3 = point - enemy.position
	enemy.rotation.y = atan2(-d.x, -d.z)
func obstacle(at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = at
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3(3, 3, 0.2)
	shape.shape = cube
	wall.add_child(shape)
	level.add_child(wall)
	return wall
func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	Engine.max_fps = 0
	await level.start_floor(81)
	var enemy = level.locust
	var player = level.player
	enemy.set_physics_process(false)
	await frames(3)
	check("Supervivencia inicia sin fallos físicos", level.session.state == level.session.State.PLAYING and level.physical_errors.is_empty())
	check("Inicio con protección y amenaza lejos", enemy.grace == 15 and enemy.position.distance_to(player.position) > 35)
	var spans := {}
	for room in level.manifest.rooms: spans[str(FLOOR.size_of(room))] = true
	check("Habitaciones rectangulares de tamaños distintos", spans.size() >= 5)
	check("Salones unidos físicamente sin puertas interiores", level.manifest.merged.size() > 5 and level.hotel.doors.size() == level.manifest.edges.size() - level.manifest.merged.size())
	Input.action_press("crouch")
	await frames(5)
	check("Agacharse reduce cápsula y altura", player.crouched and player.body_shape.shape.height < 1.1 and player.camera.position.y < 1.4)
	Input.action_release("crouch")
	await frames(5)
	check("Puede volver a ponerse de pie", not player.crouched)
	player.stamina = 10
	player.active = true
	Input.action_press("forward")
	Input.action_press("sprint")
	await frames(35)
	check("Correr agota resistencia sin regeneración instantánea", player.exhausted and player.stamina < 1)
	Input.action_release("sprint")
	Input.action_release("forward")
	await frames(240)
	check("Resistencia se recupera después del descanso", player.stamina > 25 and not player.exhausted)
	player.position = Vector3(0, 0.04, 0)
	player.velocity = Vector3.ZERO
	enemy.position = Vector3(0, 0.04, 4)
	enemy.grace = 0
	face(enemy, player.position)
	await frames(2)
	check("Visión frontal con línea libre", enemy.sees_player())
	enemy.rotation.y += PI
	check("No ve a su espalda", not enemy.sees_player())
	face(enemy, player.position)
	var wall := obstacle(Vector3(0, 1.5, 2))
	await frames(2)
	check("Pared bloquea visión y ataque", not enemy.sees_player() and not enemy.clear_sight(player.camera.global_position))
	enemy.set_mode(enemy.Mode.PATROL)
	enemy.hear(player.position, 7)
	check("Pared atenúa pasos suaves", enemy.mode == enemy.Mode.PATROL)
	enemy.set_mode(enemy.Mode.CHASE)
	enemy.last_known = player.position
	enemy.lost_time = 0
	enemy._physics_process(3.0)
	check("Perder visión cambia persecución a búsqueda", enemy.mode == enemy.Mode.SEARCH)
	enemy._physics_process(10.1)
	check("Búsqueda termina sin perseguir posición omnisciente", enemy.mode == enemy.Mode.PATROL)
	wall.queue_free()
	await frames(2)
	enemy.hear(player.position, 7)
	check("Ruido audible solicita investigación", enemy.mode == enemy.Mode.INVESTIGATE and enemy.destination.distance_to(player.position) < 0.1)
	enemy.set_mode(enemy.Mode.PATROL)
	enemy.detection = 0
	face(enemy, player.position)
	enemy._physics_process(0.2)
	check("No detecta instantáneamente", enemy.mode != enemy.Mode.CHASE)
	enemy._physics_process(0.2)
	check("Confirma visión antes de perseguir", enemy.mode == enemy.Mode.CHASE)
	enemy.set_physics_process(true)
	var before: float = enemy.position.distance_to(player.position)
	await frames(12)
	enemy.set_physics_process(false)
	check("Persecución mueve cuerpo por navegación", enemy.position.distance_to(player.position) < before - 0.4)
	enemy.position = Vector3(0, 0.04, 1)
	face(enemy, player.position)
	enemy.set_mode(enemy.Mode.CHASE)
	enemy._physics_process(0.01)
	check("Ataque anuncia preparación", enemy.mode == enemy.Mode.WINDUP and not enemy.warning.is_empty())
	enemy._physics_process(0.5)
	check("No mata antes de 0,7 s", level.session.state == level.session.State.PLAYING)
	player.position = Vector3(0, 0.04, -2)
	enemy._physics_process(0.21)
	check("Alejarse evita ataque y abre recuperación", level.session.state == level.session.State.PLAYING and enemy.mode == enemy.Mode.RECOVER)
	player.position = Vector3(0, 0.04, 0)
	enemy.position = Vector3(0, 0.04, 0.9)
	wall = obstacle(Vector3(0, 1.5, 0.45))
	await frames(2)
	check("Ataque cercano tampoco atraviesa paredes", not enemy.can_attack())
	wall.queue_free()
	await frames(2)
	var door = level.hotel.doors[0]
	var across: Vector3 = Basis(Vector3.UP, door.closed_rotation) * Vector3(0, 0, 1)
	player.position = FLOOR.position_of(level.manifest.rooms[level.manifest.exit]) + Vector3(0, 0.04, 0)
	enemy.position = door.doorway - across * 2.6 + Vector3(0, 0.04, 0)
	door.rotation.y = door.closed_rotation
	door.opened = false
	door.moving = false
	door.collision_layer = 8
	enemy.set_mode(enemy.Mode.INVESTIGATE)
	enemy.destination = door.doorway + across * 3
	enemy.set_physics_process(true)
	var crossed := false
	for i in 480:
		await physics_frame
		if (enemy.position - door.doorway).dot(across) > 0.6:
			crossed = true
			break
	enemy.set_physics_process(false)
	check("Criatura abre lentamente puerta y cruza sin atravesarla", door.opened and crossed)
	if not crossed: print("DOOR_DEBUG ",door.doorway," enemy=",enemy.position," target=",enemy.destination," mode=",enemy.mode," moving=",door.moving," opened=",door.opened," path=",enemy.path)
	player.position = Vector3(0, 0.04, 0)
	await frames(2)
	var hide = get_nodes_in_group("hotel_hides")[0]
	player.position = hide.to_global(hide.exit_offset)
	player.rotation.y = hide.global_rotation.y
	player.camera.rotation = Vector3.ZERO
	await frames(2)
	check("Escondite interactuable desde fuera", level.focused_hide() == hide)
	enemy.position = hide.to_global(Vector3(0, 0.04, 3.5))
	face(enemy, player.position)
	check("Entrada al escondite físicamente disponible", player.enter_hide(hide))
	await frames(15)
	enemy.observed_hide = null
	check("Oculto no revela posición a distancia", not enemy.sees_player())
	enemy.observed_hide = hide
	check("Recuerda la entrada observada", enemy.sees_player())
	check("Salida de escondite libre sin teletransporte a otra sala", player.leave_hide() and player.position.distance_to(hide.to_global(hide.exit_offset)) < 0.1)
	var exit_room: Dictionary = level.manifest.rooms[level.manifest.exit]
	player.position = FLOOR.position_of(exit_room) + Vector3(0, 0.04, 0)
	level.session.set_refuge(1, true)
	enemy.position = player.position + Vector3(0, 0, 1)
	face(enemy, player.position)
	check("Refugio impide percepción y captura", not enemy.sees_player() and not enemy.can_attack() and not level.session.capture(1))
	player.position = Vector3(0, 0.04, 0)
	level.session.set_refuge(1, false)
	enemy.position = Vector3(0, 0.04, 0.9)
	face(enemy, player.position)
	enemy.set_mode(enemy.Mode.WINDUP)
	enemy._physics_process(0.71)
	check("Captura real con alcance y visión causa derrota", level.session.state == level.session.State.FAILED)
	await level.start_floor(81)
	check("Reintento reinicia amenaza, resistencia y escondite", level.locust.grace == 15 and not player.hidden and player.stamina == 100 and level.session.state == level.session.State.PLAYING)
	enemy = level.locust
	hide = get_nodes_in_group("hotel_hides")[0]
	player.enter_hide(hide)
	enemy.position = hide.to_global(Vector3(0, 0.04, 3.5))
	enemy.grace = 0
	enemy.observed_hide = hide
	enemy.last_known = player.position
	face(enemy, player.position)
	enemy.set_mode(enemy.Mode.CHASE)
	enemy.set_physics_process(true)
	for i in 600:
		await physics_frame
		if level.session.state == level.session.State.FAILED: break
	check("Entrada observada permite inspeccionar y capturar dentro", level.session.state == level.session.State.FAILED)
	if level.session.state != level.session.State.FAILED: print("HIDE_DEBUG enemy=",enemy.position," player=",player.position," mode=",enemy.mode," cansee=",enemy.sees_player()," path=",enemy.path," target=",enemy.destination)
	level.settings.set_value("reduced", true)
	level.hotel.update_visibility(player.position, true)
	check("Efectos reducidos apagan polvo y movimiento de cortinas", not level.hotel.dust.visible and level.hotel.curtain_material.get_shader_parameter("motion") == 0.0)
	level.settings.set_value("reduced", false)
	var file := FileAccess.open("res://evidence/survival_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failed == 0,"checks": checks}, "\t"))
	file.close()
	print("SURVIVAL_RESULT ", checks.size()-failed,"/",checks.size())
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
