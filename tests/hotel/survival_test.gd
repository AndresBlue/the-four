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
## Distance on the floor from a point to a door's leaf (hotel_door.leaf_line).
func door_gap(point: Vector3, leaf: Array) -> float:
	var p := Vector2(point.x, point.z)
	var a := Vector2(leaf[0].x, leaf[0].z)
	var span := Vector2(leaf[1].x, leaf[1].z) - a
	var t := clampf((p - a).dot(span) / span.length_squared(), 0.0, 1.0)
	return p.distance_to(a + span * t)
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
	check("Ruido audible solicita investigación, al suelo junto a él", enemy.mode == enemy.Mode.INVESTIGATE and Vector2(enemy.destination.x - player.position.x, enemy.destination.z - player.position.z).length() < 0.6 and absf(enemy.destination.y - player.position.y) < 0.5)
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
	# Out of its reach nothing happens; within it, it has them that instant.
	player.position = Vector3(0, 0.04, -7)
	enemy._physics_process(0.01)
	check("Fuera de su alcance no hay captura", level.execution.is_empty() and enemy.mode == enemy.Mode.CHASE)
	player.position = Vector3(0, 0.04, 0)
	enemy._physics_process(0.01)
	check("A su alcance te tiene en el acto, sin preparar nada", enemy.mode == enemy.Mode.EXECUTE and not level.execution.is_empty() and level.session.state == level.session.State.PLAYING)
	level.release_execution()
	enemy.set_mode(enemy.Mode.CHASE)
	enemy.set_physics_process(false)
	player.position = Vector3(0, 0.04, 0)
	player.position = Vector3(0, 0.04, 0)
	enemy.position = Vector3(0, 0.04, 0.9)
	wall = obstacle(Vector3(0, 1.5, 0.45))
	await frames(2)
	check("Ataque cercano tampoco atraviesa paredes", not enemy.can_attack())
	wall.queue_free()
	await frames(2)
	# A door between two rooms of the first planta, with open floor where the
	# leaf opens and three metres out the other side: the corner behind its
	# open leaf is part of a room, not the width of a corridor nor a piece of
	# furniture. (Those are other cases; this one is the leaf.)
	var door = level.hotel.doors[0]
	var nav_map: RID = level.get_world_3d().navigation_map
	for each in level.hotel.doors:
		var side: Vector3 = Basis(Vector3.UP, each.closed_rotation).z
		var one: Dictionary = FLOOR.room_at(level.manifest.rooms, each.doorway + side * 1.0)
		var two: Dictionary = FLOOR.room_at(level.manifest.rooms, each.doorway - side * 1.0)
		if each.gate_stage != 0 or one.is_empty() or two.is_empty() or one.kind != "module" or two.kind != "module" or int(one.wing) != 0: continue
		var open_leaf: Array = each.leaf_line(true)
		var leaf_way: float = signf((open_leaf[1] - each.doorway).dot(side))
		var hinge_way: float = signf((open_leaf[0] - each.doorway).dot(each.along()))
		var corner: Vector3 = each.doorway + side * (leaf_way * 0.75) + each.along() * (hinge_way * 1.35)
		var out_there: Vector3 = each.doorway - side * (leaf_way * 3.0)
		var free := true
		for spot in [corner, out_there, corner + side * (leaf_way * 1.0)]:
			var snapped := NavigationServer3D.map_get_closest_point(nav_map, spot)
			if Vector2(snapped.x - spot.x, snapped.z - spot.z).length() > 0.05: free = false
		if free:
			door = each
			break
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
	# An open leaf is solid for survivors and not for it. Standing beside the
	# doorway, where every route round the jamb goes, it kept the creature
	# pressed into the wood: the stuck creature of every playtest.
	door.open_immediately()
	await frames(4)
	check("Una hoja abierta frena a los supervivientes y no a la criatura", door.collision_layer == door.OPEN_SOLID and (player.collision_mask & door.collision_layer) != 0 and (enemy.collision_mask & door.collision_layer) == 0)
	# And its route goes round the leaf, not through it: in through the doorway
	# to the corner behind the leaf, and from that corner back out across. The
	# two ways it used to end up against the wood.
	var map: RID = level.get_world_3d().navigation_map
	var leaf: Array = door.leaf_line(true)
	var leaf_side: float = signf((leaf[1] - door.doorway).dot(across))
	var hinge_side: float = signf((leaf[0] - door.doorway).dot(door.along()))
	var pocket: Vector3 = NavigationServer3D.map_get_closest_point(map, door.doorway + across * (leaf_side * 0.75) + door.along() * (hinge_side * 1.35))
	var beyond: Vector3 = NavigationServer3D.map_get_closest_point(map, door.doorway - across * (leaf_side * 3.0))
	for trip in [[beyond, pocket, "Entra por el vano y rodea la hoja hasta el rincón de detrás"], [pocket, beyond, "Sale de detrás de la hoja y cruza sin atravesarla"]]:
		enemy.position = trip[0] + Vector3(0, 0.04, 0)
		enemy.velocity = Vector3.ZERO
		enemy.speed = 0.0
		enemy.set_mode(enemy.Mode.INVESTIGATE)
		enemy.destination = trip[1]
		enemy.stuck_counts = [0, 0, 0, 0, 0, 0]
		enemy.stuck_level = 0
		enemy.stuck_origin = Vector3.INF
		var closest := INF
		var closest_at := Vector3.ZERO
		var arrived := false
		enemy.set_physics_process(true)
		for i in 600:
			await physics_frame
			if door_gap(enemy.global_position, leaf) < closest:
				closest = door_gap(enemy.global_position, leaf)
				closest_at = enemy.global_position
			if Vector2(enemy.global_position.x - trip[1].x, enemy.global_position.z - trip[1].z).length() < 0.9:
				arrived = true
				break
		enemy.set_physics_process(false)
		var jammed: int = enemy.stuck_counts[3] + enemy.stuck_counts[4] + enemy.stuck_counts[5]
		check(trip[2], arrived and closest > 0.25 and jammed == 0)
		if not arrived or closest <= 0.25 or jammed > 0: print("LEAF_DEBUG ", trip[2], " at=", enemy.global_position, " to=", trip[1], " closest=", closest, " at ", closest_at, " leaf=", leaf, " doorway=", door.doorway, " counts=", enemy.stuck_counts, " path=", enemy.path)
	# A shut door with a lock on it still stops it: it gives that way up instead
	# of pressing into the wood for the rest of the mode.
	door.set_state(false)
	door.locked = true
	await frames(3)
	enemy.position = door.doorway - across * 2.6 + Vector3(0, 0.04, 0)
	enemy.velocity = Vector3.ZERO
	enemy.set_mode(enemy.Mode.INVESTIGATE)
	enemy.destination = door.doorway + across * 3.0
	var start_side := signf((enemy.position - door.doorway).dot(across))
	var went_through := false
	enemy.set_physics_process(true)
	for i in 240:
		await physics_frame
		if signf((enemy.position - door.doorway).dot(across)) != start_side: went_through = true
	enemy.set_physics_process(false)
	check("Una puerta cerrada con llave la sigue parando, y busca otra cosa", not went_through and enemy.mode != enemy.Mode.INVESTIGATE)
	door.locked = false
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
	check("Entrar es un movimiento: el cuerpo no aparece dentro de golpe", not player.transit.is_empty() and player.global_position.distance_to(hide.to_global(hide.inside_of(player))) > 0.5)
	# The body steps in and the doors shut behind it: about a second.
	await frames(70)
	check("Y acaba dentro, mirando hacia las puertas", player.transit.is_empty() and player.global_position.distance_to(hide.to_global(hide.inside_of(player))) < 0.05 and absf(wrapf(player.rotation.y - player.hide_yaw, -PI, PI)) < 0.05)
	# Shut in, the head stays in the middle and a thin line of the room shows
	# through the crack the two leaves leave between them (cut into the model:
	# tools/props/build_wardrobe.gd); the crack is in what is drawn and not in
	# what blocks.
	await frames(40)
	var eye: Vector3 = hide.to_local(player.camera.global_position)
	var crack: Vector3 = hide.LEAVES.left.get_meta("slit", Vector3.ZERO)
	check("Las hojas del armario dejan una línea fina entre ellas, y encerrado la cabeza queda en medio", crack.y > 0.002 and crack.y < 0.008 and absf(eye.x) < 0.02 and eye.z < 0.0 and eye.z > -0.15 and not hide.ajar())
	# And they turn where they meet the carcass, at their back: turning about
	# a point in front of them and out past their edge, they came away from it.
	var axis: Vector3 = hide.pivots.left.position
	check("Las hojas giran desde su canto, contra el costado, y las bisagras se quedan en el mueble", absf(absf(axis.x) - 0.544) < 0.01 and axis.z < hide.hinge.z - 0.04 and hide.BODY.get_surface_count() == 2)
	enemy.observed_hide = null
	check("Oculto no revela posición a distancia", not enemy.sees_player())
	enemy.observed_hide = hide
	check("Recuerda la entrada observada", enemy.sees_player())
	enemy.observed_hide = null
	player.active = true
	Input.action_press("forward")
	await frames(120)
	check("Asomarse por la puerta entreabierta lo delata", hide.ajar() and enemy.sees_player() and player.camera.position.z < -0.2)
	# The head comes up to the gap and stays behind the doors: leaning out
	# past them, what was seen from a wardrobe was the whole room.
	var looking: Vector3 = hide.to_local(player.camera.global_position)
	check("Y se asoma sin sacar la cabeza del armario, con las dos hojas entornadas y no abiertas", looking.z < hide.hinge.z - 0.1 and absf(looking.x) < 0.02 and hide.leaf_angle("left") < 0.65 and hide.leaf_angle("right") < 0.65)
	var creaks := [0]
	hide.peek_started.connect(func(_point): creaks[0] += 1)
	# Looking left opens the leaf on the right hand (wardrobe -X) and leans out there.
	player.rotation.y = player.hide_yaw + 1.2
	await frames(60)
	var lean: Vector3 = Basis(Vector3.UP, player.rotation.y - player.hide_yaw) * player.camera.position
	check("Mirar a un lado abre la puerta contraria y se asoma por ese hueco", hide.peek.left > 0.9 and hide.peek.right < 0.1 and lean.x > 0.12)
	check("Sin volver la vista más de cuarenta grados ni abrir la hoja más de cuarenta y tantos", absf(wrapf(player.rotation.y - player.hide_yaw, -PI, PI)) < 0.71 and hide.leaf_angle("left") < 0.76 and hide.to_local(player.camera.global_position).z < hide.hinge.z - 0.1)
	player.rotation.y = player.hide_yaw - 1.2
	await frames(60)
	lean = Basis(Vector3.UP, player.rotation.y - player.hide_yaw) * player.camera.position
	check("Mirar al otro lado cambia de puerta", hide.peek.right > 0.9 and hide.peek.left < 0.1 and lean.x < -0.12)
	Input.action_release("forward")
	await frames(120)
	check("Con las puertas cerradas vuelve a ocultarlo", not hide.ajar() and not enemy.sees_player())
	Input.action_press("forward")
	await frames(30)
	Input.action_release("forward")
	await frames(60)
	check("Solo la primera apertura de las puertas hace ruido", creaks[0] == 0)
	enemy.observed_hide = hide
	var out: bool = player.leave_hide()
	await frames(30)
	check("Salida de escondite libre sin teletransporte a otra sala", out and player.position.distance_to(hide.to_global(hide.exit_offset)) < 0.1)
	# Leaning round a corner (1 and 3): the head goes to one side, the picture
	# tips with it, and both come back when the key is let go.
	player.active = true
	Input.action_press("lean_right")
	await frames(60)
	var leant: Vector3 = player.camera.position
	var tipped: float = player.camera.rotation.z
	Input.action_release("lean_right")
	Input.action_press("lean_left")
	await frames(90)
	var other_way: Vector3 = player.camera.position
	Input.action_release("lean_left")
	await frames(90)
	check("Con 1 y 3 se asoma a un lado, inclinando la imagen, y vuelve", leant.x > 0.15 and tipped < -0.03 and other_way.x < -0.15 and absf(player.camera.position.x) < 0.02)
	if leant.x <= 0.15 or other_way.x >= -0.15: print("  lean right=%.2f tip=%.3f left=%.2f back=%.2f" % [leant.x, tipped, other_way.x, player.camera.position.x])
	# Beside the wardrobe, with its side a hand and a half to the left: the
	# head stops at it and does not go through.
	player.position = hide.to_global(Vector3(-(hide.width * 0.5 + 0.3), 0.04, 0.0))
	player.rotation.y = hide.global_rotation.y + PI
	await frames(3)
	Input.action_press("lean_left")
	await frames(90)
	var eyes: Vector3 = player.to_global(Vector3(0.0, player.eye_height, 0.0))
	var through := PhysicsRayQueryParameters3D.create(eyes, player.camera.global_position, 1 | 8)
	through.exclude = [player.get_rid()]
	var blocked: bool = not level.get_world_3d().direct_space_state.intersect_ray(through).is_empty()
	check("Contra un mueble o una pared, la cabeza se queda en él y no lo atraviesa", player.lean_out > -0.19 and player.lean_out < -0.02 and not blocked)
	print("  lean against the wardrobe: %.2f m, through it: %s" % [player.lean_out, blocked])
	Input.action_release("lean_left")
	await frames(90)
	# The refuge of the stage in hand: walking the floor during this test can
	# have carried it on to the next wing already.
	var exit_room: Dictionary = level.manifest.rooms[level.refuge_room()]
	player.position = FLOOR.position_of(exit_room) + Vector3(0, 0.04, 0)
	level.session.set_refuge(1, true)
	enemy.position = player.position + Vector3(0, 0, 1)
	face(enemy, player.position)
	check("Refugio impide percepción y captura", not enemy.sees_player() and not enemy.can_attack() and not level.session.capture(1))
	# Pressed into a corner of it, where the refuge used to end 0.55 m short
	# of the wall: still out of reach, not seen, not heard, not taken -- even
	# with the session not counting it in (it did not, there).
	var span := FLOOR.size_of(exit_room)
	var corner: Vector3 = FLOOR.position_of(exit_room) + Vector3(span.x * 0.5 - 0.4, 0.04, span.y * 0.5 - 0.4)
	player.position = corner
	level.session.set_refuge(1, false)
	enemy.position = corner - Vector3(1.0, 0, 1.0)
	face(enemy, player.position)
	check("Pegado a la pared del refugio sigue protegido", level.point_protected(corner) and not level.survivor_active(player))
	check("Y la criatura no lo ve, no lo oye ni lo atrapa", not enemy.sees_player() and not enemy.can_attack() and not enemy.hear_route(corner, 12.0).audible)
	level.capture_survivor(player)
	check("Ni una ejecución empieza ahí", level.execution.is_empty())
	player.position = Vector3(0, 0.04, 0)
	level.session.set_refuge(1, false)
	enemy.position = Vector3(0, 0.04, 0.9)
	face(enemy, player.position)
	enemy.set_mode(enemy.Mode.CHASE)
	enemy.focus = player
	enemy._physics_process(0.01)
	check("El golpe encadena una ejecución en vez de matar al instante", enemy.mode == enemy.Mode.EXECUTE and not level.execution.is_empty() and level.session.state == level.session.State.PLAYING)
	enemy.hear(player.position + Vector3(2, 0, 0), 20)
	check("Un ruido no la saca de su ejecución", enemy.mode == enemy.Mode.EXECUTE)
	await frames(30)
	# The face first: held on the arm in front of it, feet still on the floor.
	# It is lifted once its own camera is on the floor to see it.
	check("Durante el rostro la víctima queda sujeta delante de la bestia, en el suelo", player.global_position.y < 0.3 and player.global_position.distance_to(enemy.global_position) < 1.3 and player.held)
	check("Su cámara ya no está en sus manos: la lleva la cinta", level.tape.recording() and player.camera.top_level)
	await frames(135)
	check("Después la levanta: queda en el aire delante de la bestia", player.global_position.y > 0.8 and player.global_position.distance_to(enemy.global_position) < 2.2)
	check("Y la cámara está en el suelo, grabando", player.camera.global_position.y < 0.4 and not level.tape.take.is_empty())
	# The execution is longer now: the scream, the mask coming in, the blow.
	await frames(200)
	# Alone there is nobody to be forgiven with: the death lands and the floor
	# is over.
	check("La ejecución acaba con el superviviente", level.session.participants[1] == level.session.Life.DEAD and level.session.state == level.session.State.FAILED and level.session.restarts == 0)
	check("Al morir la imagen se pierde en estática", level.post_material != null and float(level.post_material.get_shader_parameter("signal_loss")) > 0.5)
	# The picture is not lost for ever: it clears itself even though the floor
	# is over and nobody is being driven any more.
	await frames(300)
	check("La estática se va sola cuando la partida ya ha terminado", level.post_material != null and float(level.post_material.get_shader_parameter("signal_loss")) < 0.05)
	await level.start_floor(81)
	check("Un piso nuevo empieza con la imagen limpia", level.post_material != null and float(level.post_material.get_shader_parameter("signal_loss")) == 0.0 and float(level.post_material.get_shader_parameter("tape_hit")) == 0.0 and float(level.post_material.get_shader_parameter("tape_fray")) == 0.0)
	check("Reintento reinicia amenaza, resistencia y escondite", level.locust.grace == 15 and not player.hidden and player.stamina == 100 and level.session.state == level.session.State.PLAYING)
	enemy = level.locust
	hide = get_nodes_in_group("hotel_hides")[0]
	player.enter_hide(hide)
	# In, and its doors shut behind it, before anything comes for it.
	await frames(70)
	enemy.position = hide.to_global(Vector3(0, 0.04, 3.5))
	enemy.grace = 0
	enemy.observed_hide = hide
	enemy.last_known = player.position
	face(enemy, player.position)
	enemy.set_mode(enemy.Mode.CHASE)
	enemy.set_physics_process(true)
	var ritual := {"started": -1.0, "burst": -1.0, "wide": -1.0, "kill": -1.0}
	var clock := 0.0
	for i in 900:
		await physics_frame
		clock += 1.0 / 60.0
		if ritual.started < 0.0 and enemy.mode == enemy.Mode.WARDROBE: ritual.started = clock
		if ritual.started >= 0.0 and ritual.burst < 0.0 and minf(hide.leaf_angle("left"), hide.leaf_angle("right")) > 0.05: ritual.burst = clock
		if ritual.burst >= 0.0 and ritual.wide < 0.0 and minf(hide.leaf_angle("left"), hide.leaf_angle("right")) > hide.OPEN_ANGLE * 0.95: ritual.wide = clock
		if ritual.kill < 0.0 and not level.execution.is_empty(): ritual.kill = clock
		if level.session.state == level.session.State.FAILED or level.session.restarts >= 1: break
	check("Se planta ante el armario y abre las dos hojas de golpe", ritual.started >= 0.0 and ritual.burst > ritual.started + 0.3 and ritual.wide > 0.0 and ritual.wide - ritual.burst < 0.15)
	check("Y lo tiene en cuanto las puertas se abren", ritual.kill >= ritual.burst and ritual.kill - ritual.burst < 0.25)
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
	# Four on the floor: the third death brings the restart, and a fourth
	# during its countdown is part of the same collapse, not a second one.
	session.start(session.run_seed, false, [1, 2, 3, 4])
	for seat in [2, 3, 4]: session.capture(seat)
	var restarting: bool = session.restart_wait > 0.0 and session.state == session.State.PLAYING
	session.capture(1)
	check("Una muerte durante la cuenta del reinicio no acaba el piso", restarting and session.state == session.State.PLAYING and session.restart_wait > 0.0)
	# Lost for the floor stays lost: the next stage raises the others only.
	session.start(session.run_seed, false, [1, 2])
	session.drop(2)
	session.raise_everyone()
	check("Quien se cayó y no volvió no revive al cambiar de sector", session.participants[2] == session.Life.DEAD and session.participants[1] == session.Life.EXPLORING)
	session.returned(2)
	session.raise_everyone()
	check("Si vuelve, cuenta otra vez desde el sector siguiente", session.participants[2] == session.Life.EXPLORING)
	session.start(session.run_seed, false, [1])
	# From stage 2 to 3 with somebody dead: nothing may be told about the new
	# stage while the old goal, met, is still in hand -- the door of the stage
	# ahead opened on its own.
	session.start(session.run_seed, false, [1, 2])
	session.stage = 2
	session.goal = {"kind": "televisions", "done": 2, "needed": 2, "ready": true}
	session.participants[2] = session.Life.DEAD
	var told := {"early": false}
	var listen := func(): if session.stage == 3 and bool(session.goal.get("ready", false)): told.early = true
	session.changed.connect(listen)
	session.set_state(session.State.TRANSITION)
	session.transition_time = 5.0
	session._process(0.1)
	session.changed.disconnect(listen)
	check("Pasar al sector 3 con un muerto no abre la puerta siguiente", session.stage == 3 and not told.early and session.participants[2] == session.Life.EXPLORING)
	# Two of three lost for good: no restart can bring the quota back.
	session.start(session.run_seed, false, [1, 2, 3])
	session.drop(2)
	session.drop(3)
	check("Si ni reiniciando se llega a la cuota, el piso se pierde", session.state == session.State.FAILED)
	session.start(session.run_seed, false, [1])
	# The ride waits under the pause like everything else.
	level.lifts.boarding = {"point": player.global_position + Vector3(4, 0, 0), "time": 0.0}
	session.set_state(session.State.PAUSED)
	level._physics_process(2.0)
	check("Un viaje en ascensor no avanza con el juego en pausa", float(level.lifts.boarding.get("time", -1.0)) == 0.0)
	level.lifts.boarding = {}
	player.held = false
	session.set_state(session.State.PLAYING)
	# A wardrobe leaf ajar is still wood in front of whoever is inside.
	var wardrobe = get_nodes_in_group("hotel_hides")[0]
	wardrobe.peek = {"left": 0.4, "right": 0.0}
	wardrobe.apply_angles()
	await frames(2)
	var leaf: CollisionShape3D = wardrobe.leaf_bodies.left.get_child(0)
	var front: Vector3 = wardrobe.global_basis.z.normalized()
	var through := PhysicsRayQueryParameters3D.create(leaf.global_position + front * 2.0, leaf.global_position - front * 0.3, 1 | 8 | 64)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(through)
	check("Una hoja entreabierta del armario sigue tapando la vista", wardrobe.leaf_angle("left") > wardrobe.COLLISION_LIMIT and hit.get("collider") == wardrobe.leaf_bodies.left)
	check("Y no estorba al moverse", wardrobe.leaf_bodies.left.collision_layer & 4 == 0 and wardrobe.leaf_bodies.left.collision_layer & 8 == 0)
	wardrobe.peek = {"left": 0.0, "right": 0.0}
	wardrobe.apply_angles()
	# Two kinds of wardrobe (hiding_place.gd): the small one takes one, the big
	# one two, side by side, each asking of the doors on their own; and nobody
	# walks into either -- with a leaf ajar it stops being solid, and whoever
	# stood outside used to step in beside the one peeking.
	var beast = level.locust
	var beast_awake: bool = is_instance_valid(beast) and beast.is_physics_processing()
	# And out of the way: it plants itself square in front of a wardrobe it
	# opens (hotel_locust.settle_before), which is where these walk from.
	var beast_was: Vector3 = beast.global_position if is_instance_valid(beast) else Vector3.ZERO
	if is_instance_valid(beast):
		beast.set_physics_process(false)
		beast.global_position += Vector3(0, 40, 0)
	var small = get_nodes_in_group("hotel_hides").filter(func(place) -> bool: return not place.big)[0]
	var large = get_nodes_in_group("hotel_hides").filter(func(place) -> bool: return place.big)[0]
	# Somebody else's body, as this machine has it: moved from elsewhere.
	var mate := CharacterBody3D.new()
	mate.collision_layer = 4
	mate.collision_mask = 0
	root.add_child(mate)
	var third := CharacterBody3D.new()
	third.collision_layer = 4
	third.collision_mask = 0
	root.add_child(third)
	small.enter(mate)
	check("En el armario pequeño cabe uno: con alguien dentro no entra nadie más", small.capacity == 1 and not small.has_room() and not player.enter_hide(small) and not player.hidden)
	await frames(50)
	small.set_peek(1.0, 1.0, mate)
	await frames(3)
	var walk_at := func(place, plugged: bool) -> float:
		place.plug.disabled = not plugged
		player.position = place.to_global(place.exit_offset)
		player.rotation.y = place.global_rotation.y
		player.velocity = Vector3.ZERO
		player.active = true
		await frames(3)
		Input.action_press("forward")
		await frames(100)
		Input.action_release("forward")
		await frames(3)
		return place.to_local(player.global_position).z
	var unplugged: float = await walk_at.call(small, false)
	var plugged: float = await walk_at.call(small, true)
	check("Con una hoja entreabierta se entraba andando al armario de otro (el fallo de asomarse); ahora el armario no deja pasar", small.ajar() and unplugged < small.hinge.z - 0.2 and plugged > small.hinge.z - 0.12)
	small.leave(mate)
	player.position = large.to_global(large.exit_offset)
	player.rotation.y = large.global_rotation.y
	await frames(3)
	check("En el armario grande caben dos", large.capacity == 2 and player.enter_hide(large) and large.has_room())
	await frames(40)
	large.enter(mate)
	var apart: float = (large.inside_of(player) - large.inside_of(mate)).length()
	check("Uno al lado del otro, y un tercero se queda fuera", not large.has_room() and large.holds(player) and large.holds(mate) and not large.holds(third) and apart > 0.6 and player.global_position.distance_to(large.to_global(large.inside_of(player))) < 0.1)
	await frames(50)
	large.set_peek(1.0, 0.0, mate)
	await frames(3)
	check("Cada uno pide lo suyo a las puertas: se abren lo que pide el que más", large.peek.left > 0.9 and large.peek_of(player) == [0.0, 0.0] and large.ajar())
	large.leave(mate)
	await frames(170)
	check("Sale uno y las puertas vuelven a cerrarse sobre el que queda", player.hidden and large.holds(player) and not large.ajar() and large.has_room())
	check("Y el que queda sale por su lado", player.leave_hide() and not player.hidden and large.occupant == null)
	mate.queue_free()
	third.queue_free()
	if is_instance_valid(beast):
		beast.global_position = beast_was
		beast.set_physics_process(beast_awake)
	# Whatever a model brings to look with stays out of the body.
	var explorer = preload("res://game/player/avatars/avatar_visual.tscn").instantiate()
	explorer.character = 2
	root.add_child(explorer)
	check("La Exploradora no trae su propia cámara", explorer.find_children("*", "Camera3D", true, false).is_empty())
	explorer.queue_free()
	# On this seed the deepest room of the first wing is the lift lobby behind
	# the refuge: the creature started there, shut in for the whole stage.
	await level.start_floor(673128)
	var start := int(FLOOR.room_at(level.manifest.rooms, level.locust.global_position).get("id", -1))
	check("La criatura no empieza en un refugio ni en el vestíbulo de un ascensor", start >= 0 and not level.off_limits_rooms().has(start))
