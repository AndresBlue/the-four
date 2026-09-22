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
	# One door per connection, the last door of the floor among them: it is
	# the connection between the refuge and the landing behind it.
	check("Salones unidos físicamente sin puertas interiores", level.manifest.merged.size() > 5 and level.hotel.doors.size() == level.manifest.edges.size() - level.manifest.merged.size())
	Input.action_press("crouch")
	await frames(5)
	check("Agacharse reduce cápsula y altura", player.crouched and player.body_shape.shape.height < 1.1 and player.camera.position.y < 1.4)
	Input.action_release("crouch")
	await frames(5)
	check("Puede volver a ponerse de pie", not player.crouched)
	player.stamina = 4
	player.active = true
	Input.action_press("forward")
	Input.action_press("sprint")
	await frames(35)
	check("Correr agota resistencia sin regeneración instantánea", player.exhausted and player.stamina < 1)
	Input.action_release("sprint")
	Input.action_release("forward")
	await frames(560)
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
	# Hearing follows walkable routes: a free-standing wall does not stop it,
	# but a noise beyond its scaled reach is not heard.
	enemy.set_mode(enemy.Mode.PATROL)
	enemy.hear(player.position, 7)
	check("Oye pasos alrededor de una pared por la ruta", enemy.mode == enemy.Mode.INVESTIGATE)
	enemy.set_mode(enemy.Mode.PATROL)
	enemy.hear(player.position, 4.0 / enemy.HEARING_SCALE)
	check("No oye ruidos más allá de su alcance", enemy.mode == enemy.Mode.PATROL)
	enemy.set_mode(enemy.Mode.CHASE)
	enemy.last_known = player.position
	enemy.lost_time = 0
	enemy._physics_process(enemy.LOSE_AFTER + 0.5)
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
	check("Al verlo se detiene y chilla antes de correr", enemy.mode == enemy.Mode.ALERT)
	enemy._physics_process(enemy.ALERT_TIME * 0.5)
	check("La alerta da tiempo a reaccionar", enemy.mode == enemy.Mode.ALERT)
	# A survivor who keeps walking in sight is heard at every step: the steps
	# only say where, they must not start the alert over.
	enemy.hear(player.position, 20)
	check("Los pasos de quien ya ha visto no reinician la alerta", enemy.mode == enemy.Mode.ALERT)
	enemy._physics_process(enemy.ALERT_TIME)
	check("Tras la alerta persigue", enemy.mode == enemy.Mode.CHASE)
	# The chase has a voice of its own, not only the shriek.
	enemy.calls_made = 0
	enemy.grunt_clock = 0.0
	enemy.grunt_rest = 0.0
	enemy.chase_voice(0.1)
	check("La persecución tiene voz: gruñe mientras corre", enemy.calls_made == 1)
	check("Y ese gruñido va dirigido a quien persigue", enemy.aimed)
	enemy.chase_voice(0.1)
	check("Pero nunca dos gruñidos pegados", enemy.calls_made == 1)
	enemy.set_physics_process(true)
	var before: float = enemy.position.distance_to(player.position)
	await frames(12)
	enemy.set_physics_process(false)
	check("Persecución mueve cuerpo por navegación", enemy.position.distance_to(player.position) < before - 0.4)
	enemy.position = Vector3(0, 0.04, 1)
	face(enemy, player.position)
	enemy.set_mode(enemy.Mode.CHASE)
	enemy._physics_process(0.01)
	check("Ataque anuncia preparación", enemy.mode == enemy.Mode.WINDUP and enemy.signal_player.playing)
	enemy._physics_process(enemy.WINDUP_TIME * 0.5)
	check("La estocada no es instantánea", level.session.state == level.session.State.PLAYING)
	# Only a player already beyond its lunge survives the strike.
	player.position = Vector3(0, 0.04, -7)
	enemy._physics_process(enemy.WINDUP_TIME)
	check("Fuera del alcance de la estocada no hay captura", level.session.state == level.session.State.PLAYING and enemy.mode == enemy.Mode.RECOVER)
	player.position = Vector3(0, 0.04, 0)
	player.position = Vector3(0, 0.04, 0)
	enemy.position = Vector3(0, 0.04, 0.9)
	wall = obstacle(Vector3(0, 1.5, 0.45))
	await frames(2)
	check("Ataque cercano tampoco atraviesa paredes", not enemy.can_attack())
	wall.queue_free()
	await frames(2)
	var door = level.hotel.doors[0]
	var across: Vector3 = Basis(Vector3.UP, door.closed_rotation) * Vector3(0, 0, 1)
	player.position = FLOOR.position_of(level.manifest.rooms[level.refuge_room()]) + Vector3(0, 0.04, 0)
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
	# The doors take about half a second to swing shut behind the player.
	await frames(45)
	enemy.observed_hide = null
	check("Oculto no revela posición a distancia", not enemy.sees_player())
	enemy.observed_hide = hide
	check("Recuerda la entrada observada", enemy.sees_player())
	enemy.observed_hide = null
	player.active = true
	Input.action_press("forward")
	await frames(120)
	check("Asomarse por la puerta entreabierta lo delata", hide.ajar() and enemy.sees_player() and player.camera.position.z < -0.3)
	var creaks := [0]
	hide.peek_started.connect(func(_point): creaks[0] += 1)
	# Looking left opens the leaf on the right hand (wardrobe -X) and leans out there.
	player.rotation.y = player.hide_yaw + 1.2
	await frames(60)
	var lean: Vector3 = Basis(Vector3.UP, player.rotation.y - player.hide_yaw) * player.camera.position
	check("Mirar a un lado abre la puerta contraria y se asoma por ese hueco", hide.peek.left > 0.9 and hide.peek.right < 0.1 and lean.x > 0.2)
	player.rotation.y = player.hide_yaw - 1.2
	await frames(60)
	lean = Basis(Vector3.UP, player.rotation.y - player.hide_yaw) * player.camera.position
	check("Mirar al otro lado cambia de puerta", hide.peek.right > 0.9 and hide.peek.left < 0.1 and lean.x < -0.2)
	Input.action_release("forward")
	await frames(120)
	check("Con las puertas cerradas vuelve a ocultarlo", not hide.ajar() and not enemy.sees_player())
	Input.action_press("forward")
	await frames(30)
	Input.action_release("forward")
	await frames(60)
	check("Solo la primera apertura de las puertas hace ruido", creaks[0] == 0)
	enemy.observed_hide = hide
	check("Salida de escondite libre sin teletransporte a otra sala", player.leave_hide() and player.position.distance_to(hide.to_global(hide.exit_offset)) < 0.1)
	# The refuge of the stage in hand: walking the floor during this test can
	# have carried it on to the next wing already.
	var exit_room: Dictionary = level.manifest.rooms[level.refuge_room()]
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
	enemy._physics_process(enemy.WINDUP_TIME + 0.01)
	check("El golpe encadena una ejecución en vez de matar al instante", enemy.mode == enemy.Mode.EXECUTE and not level.execution.is_empty() and level.session.state == level.session.State.PLAYING)
	enemy.hear(player.position + Vector3(2, 0, 0), 20)
	check("Un ruido no la saca de su ejecución", enemy.mode == enemy.Mode.EXECUTE)
	await frames(30)
	check("Durante la ejecución la víctima queda en el aire delante de la bestia", player.global_position.y > 0.8 and player.global_position.distance_to(enemy.global_position) < 2.2)
	# The execution is longer now: the scream, the mask coming in, the blow.
	await frames(300)
	# Alone there is nobody to be forgiven with: the death lands and the floor
	# is over.
	check("La ejecución acaba con el superviviente", level.session.participants[1] == level.session.Life.DEAD and level.session.state == level.session.State.FAILED and level.session.restarts == 0)
	check("Al morir la imagen se pierde en estática", level.post_material != null and float(level.post_material.get_shader_parameter("signal_loss")) > 0.5)
	# The picture is not lost for ever: it clears itself even though the floor
	# is over and nobody is being driven any more.
	await frames(300)
	check("La estática se va sola cuando la partida ya ha terminado", level.post_material != null and float(level.post_material.get_shader_parameter("signal_loss")) < 0.05)
	await level.start_floor(81)
	check("Un piso nuevo empieza con la imagen limpia", level.post_material != null and float(level.post_material.get_shader_parameter("signal_loss")) == 0.0 and float(level.post_material.get_shader_parameter("strike_fill")) == 0.0)
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
	var ritual := {"started": -1.0, "right": -1.0, "left": -1.0, "kill": -1.0}
	var clock := 0.0
	for i in 900:
		await physics_frame
		clock += 1.0 / 60.0
		if ritual.started < 0.0 and enemy.mode == enemy.Mode.WARDROBE: ritual.started = clock
		if ritual.right < 0.0 and hide.wide.right > 0.5: ritual.right = clock
		if ritual.left < 0.0 and hide.wide.left > 0.5: ritual.left = clock
		if ritual.kill < 0.0 and not level.execution.is_empty(): ritual.kill = clock
		if level.session.state == level.session.State.FAILED or level.session.restarts >= 1: break
	check("Se planta ante el armario y lo abre puerta a puerta", ritual.started >= 0.0 and ritual.right > ritual.started and ritual.left > ritual.right)
	check("Abrir el armario le cuesta tiempo antes de alcanzar a nadie", ritual.kill > ritual.started + 1.4)
	check("Entrada observada permite inspeccionar y capturar dentro", ritual.kill >= 0.0 and (level.session.state == level.session.State.FAILED or level.session.restarts >= 1))
	if level.session.state != level.session.State.FAILED: print("HIDE_DEBUG enemy=",enemy.position," player=",player.position," mode=",enemy.mode," cansee=",enemy.sees_player()," path=",enemy.path," target=",enemy.destination)
	level.settings.set_value("reduced", true)
	level.hotel.update_visibility(player.position, true)
	check("Efectos reducidos apagan polvo y movimiento de cortinas", not level.hotel.dust.visible and level.hotel.curtain_material.get_shader_parameter("motion") == 0.0)
	level.settings.set_value("reduced", false)
	# The hand-held camera at a frame time no machine should ever see. The
	# explicit integration this replaced gained energy every frame below about
	# 8 FPS: measured on a real floor it left the camera in NaN at frame 54 at
	# 5 FPS, and a camera in NaN draws nothing -- back through the menu and
	# into the next match, because the body is the same node.
	player.handheld_enabled = true
	player.reset_handheld()
	var worst_sway := 0.0
	var worst_speed := 0.0
	for i in 200:
		player.turn_delta = Vector2(0.6 if i % 2 == 0 else -0.6, 0.35 if i % 3 == 0 else -0.35)
		player.update_handheld(0.2)
		worst_sway = maxf(worst_sway, player.sway.length())
		worst_speed = maxf(worst_speed, player.sway_velocity.length())
	check("El muelle de la cámara aguanta 5 FPS sin dispararse", player.camera.rotation.is_finite() and worst_sway < 0.06 and worst_speed < 1.0)
	# And whatever else might ever write an impossible number into the camera,
	# the picture comes back by itself instead of staying black until the game
	# is started again.
	player.camera.rotation = Vector3(NAN, 0.0, 0.0)
	player.update_handheld(1.0 / 60.0)
	check("Una cámara en NaN se repone sola", player.camera.rotation.is_finite() and is_finite(player.look_pitch()) and player.sway == Vector3.ZERO)
	player.handheld_enabled = false
	await cut_short_checks()
	var file := FileAccess.open("res://evidence/survival_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failed == 0,"checks": checks}, "\t"))
	file.close()
	print("SURVIVAL_RESULT ", checks.size()-failed,"/",checks.size())
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

## What happens when the floor moves on in the middle of something.
func cut_short_checks() -> void:
	var player = level.player
	var session = level.session
	# An execution the stage closes under lets its victim go instead of
	# leaving them held in the air, neither dead nor able to move.
	level.execution = {"seat": player.slot, "time": 1.0, "point": player.global_position, "yaw": 0.0, "stabs": 0, "dropped": false}
	player.held = true
	level.online_menu = true
	session.transition_time = 0.0
	session.set_state(session.State.TRANSITION)
	level._process(0.016)
	check("Una ejecución cortada por el cambio de etapa suelta a la víctima", level.execution.is_empty() and not player.held)
	check("El menú online no sobrevive al cambio de etapa", not level.online_menu)
	# A guest's session only moves on when the host says so.
	var stage: int = session.stage
	session.authority = false
	session.transition_time = 5.0
	session._process(0.1)
	check("La sesión de un invitado no avanza de etapa por su cuenta", session.stage == stage and session.state == session.State.TRANSITION)
	session.authority = true
	session.set_state(session.State.PLAYING)
	# The keypad does not stay open under the pause, taking digits.
	level.open_lock()
	session.set_state(session.State.PAUSED)
	check("Pausar cierra el teclado del código", not level.lock_open and not player.reading)
	session.set_state(session.State.PLAYING)
	# Nor over a death: caught at the keypad, it goes.
	level.open_lock()
	level.apply_execution(player.slot, player.global_position, 0.0)
	check("Si te atrapan en el teclado, el teclado se cierra", not level.lock_open)
	level.release_execution()
	# On this seed the deepest room of the first wing is the lift lobby behind
	# the refuge: the creature started there, shut in for the whole stage.
	await level.start_floor(673128)
	var start := int(FLOOR.room_at(level.manifest.rooms, level.locust.global_position).get("id", -1))
	check("La criatura no empieza en un refugio ni en el vestíbulo de un ascensor", start >= 0 and not level.off_limits_rooms().has(start))
