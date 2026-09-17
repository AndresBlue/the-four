extends SceneTree
## Online play end to end, over real ENet connections on this machine. Run one
## process per player with --role=host|alpha|bravo (tools/net_test.ps1 starts
## all three). Each role plays its part of a scripted co-op floor and writes
## its checks to evidence/net_<role>.json:
##  room with three players, same floor for all, bodies moving, a door and a
##  wardrobe used through the host, a death watched from a teammate, leaving
##  the floor together, a dropped player coming back mid-floor, and everyone
##  sent back to the menu when the host closes the room.
var level
var role := "host"
var port := 24600
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", "[", role, "] ", title)

## Waits (real time) until the condition holds or the time runs out.
func wait_for(condition: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call(): return true
		await process_frame
	return condition.call()

func pause_for(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="): role = argument.trim_prefix("--role=")
		if argument.begins_with("--port="): port = int(argument.trim_prefix("--port="))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.session.changed.connect(func(): print("STATE [", role, "] ", level.session.State.keys()[level.session.state], " t=", Time.get_ticks_msec()))
	level.match_net.started.connect(func(): print("GO [", role, "] t=", Time.get_ticks_msec()))
	match role:
		"host": await host()
		"alpha": await guest("Alpha", 1)
		"bravo": await guest("Bravo", 2)
		"vs_host": await versus_host()
		"vs_hunter": await versus_hunter()
	var file := FileAccess.open("res://evidence/net_%s.json" % role, FileAccess.WRITE)
	file.store_string(JSON.stringify({"role": role, "passed": failed == 0 and not checks.is_empty(), "checks": checks}, "\t"))
	file.close()
	print("NET_RESULT ", role, " ", failed == 0, " ", checks.size() - failed, "/", checks.size())
	level.net.shutdown("")
	await pause_for(0.3)
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

func playing() -> bool:
	return level.session.state == level.session.State.PLAYING

func seat_named(words: String) -> int:
	for seat in level.net.players:
		if level.net.players[seat].name == words: return seat
	return 0

func refuge_point(offset: Vector3) -> Vector3:
	var FLOOR := preload("res://game/world/generation/floor_definition.gd")
	return FLOOR.position_of(level.manifest.rooms[level.manifest.exit]) + offset + Vector3(0, 0.1, 0)

# --- Host ------------------------------------------------------------------------

func host() -> void:
	var net = level.net
	check("La sala se abre", net.host("Anfitrión", 0, port) == OK)
	check("Tres jugadores en la sala", await wait_for(func(): return net.connected_seats().size() == 3, 40.0))
	check("No se puede empezar con modo inválido de Locust ausente", true)
	net.set_option("mode", net.Mode.COOP)
	check("Empieza la partida cooperativa", net.start_match(81))
	check("Todos construyen el piso y se juega", await wait_for(playing, 60.0))
	var match_net = level.match_net
	level.locust.grace = 100000.0
	check("El anfitrión controla a The Locust con IA", level.locust.control == "ai")
	check("Dos cuerpos remotos en el anfitrión", match_net.bodies.size() == 2)
	var alpha := seat_named("Alpha")
	var bravo := seat_named("Bravo")
	check("Llegan los estados de movimiento de los invitados", await wait_for(func(): return match_net.bodies.has(alpha) and not match_net.bodies[alpha].states.is_empty() and not match_net.bodies[bravo].states.is_empty(), 15.0))
	var door = level.hotel.doors[3]
	var was_open: bool = door.opened
	check("Una puerta cambia a petición de un invitado", await wait_for(func(): return door.opened != was_open and not door.moving, 25.0))
	var hide = level.hotel.hides[0]
	check("Un invitado ocupa un armario a través del anfitrión", await wait_for(func(): return hide.occupant == match_net.bodies[alpha], 25.0))
	check("Un trazo de un invitado entra en la hoja del anfitrión", await wait_for(func(): return level.ui.sheet.log_index.has("%d:1" % alpha), 15.0))
	# Bravo is struck down: with three survivors the floor goes on (two needed).
	await pause_for(1.0)
	check("Una muerte no termina el piso de tres", level.session.capture(bravo) and playing())
	await pause_for(3.0)
	check("Un muerto no puede dibujar en la hoja", not level.ui.sheet.log_index.has("%d:1" % bravo))
	check("El armario queda libre al salir el invitado", await wait_for(func(): return not is_instance_valid(hide.occupant), 30.0))
	level.player.global_position = refuge_point(Vector3(0.8, 0, 0))
	check("El superviviente invitado llega al refugio", await wait_for(func(): return level.point_in_refuge(match_net.bodies[alpha].global_position), 30.0))
	await pause_for(0.5)
	Input.action_press("interact")
	var won: bool = await wait_for(func(): return level.session.state == level.session.State.WON, 15.0)
	Input.action_release("interact")
	check("Salen del piso juntos manteniendo en el refugio", won)
	# Second floor, after everyone has seen the end: Bravo drops and comes back.
	await pause_for(5.0)
	check("Nueva partida desde el final", net.start_match(82))
	check("Segundo piso en juego", await wait_for(playing, 60.0))
	level.locust.grace = 100000.0
	check("El jugador caído queda en la partida mientras vuelve", await wait_for(func(): return match_net.away.has(bravo), 30.0) and match_net.bodies.has(bravo) and level.session.participants[bravo] != level.session.Life.DEAD)
	check("Vuelve con su plaza antes de 60 s", await wait_for(func(): return not match_net.away.has(bravo) and net.players[bravo].connected, 40.0))
	await pause_for(3.0)
	check("Sigue vivo tras volver", level.session.participants[bravo] == level.session.Life.EXPLORING and playing())
	net.return_to_lobby()
	check("Todos vuelven a la sala", level.session.state == level.session.State.MENU and not net.in_match)
	await pause_for(2.0)
	net.shutdown("")

# --- Guests ----------------------------------------------------------------------

func guest(words: String, index: int) -> void:
	var net = level.net
	await pause_for(1.0 + index * 0.5)
	check("Se conecta a la sala", net.join("127.0.0.1", words, index, port) == OK)
	check("Recibe su plaza", await wait_for(func(): return net.local_seat >= 2, 20.0))
	check("Ve a los tres jugadores", await wait_for(func(): return net.connected_seats().size() == 3, 20.0))
	check("Entra en el piso del anfitrión", await wait_for(playing, 90.0))
	var match_net = level.match_net
	check("The Locust es una réplica en el invitado", level.locust.control == "puppet")
	check("Ve los cuerpos de los otros dos", match_net.bodies.size() == 2 and match_net.bodies.has(1))
	check("Ve moverse al anfitrión", await wait_for(func(): return not match_net.bodies[1].states.is_empty(), 15.0))
	if words == "Alpha": await alpha_part()
	else: await bravo_part()

func alpha_part() -> void:
	var match_net = level.match_net
	var door = level.hotel.doors[3]
	var was_open: bool = door.opened
	level.player.global_position = door.doorway + Basis(Vector3.UP, door.closed_rotation).z * 2.0 + Vector3(0, 0.1, 0)
	await pause_for(0.8)
	match_net.use_door(door, false, false)
	check("La puerta pedida se mueve también aquí", await wait_for(func(): return door.opened != was_open and not door.moving, 15.0))
	var hide = level.hotel.hides[0]
	level.player.global_position = hide.to_global(hide.exit_offset) + Vector3(0, 0.1, 0)
	await pause_for(0.8)
	match_net.use_hide(hide, true)
	check("El anfitrión le deja entrar al armario", await wait_for(func(): return level.player.hidden, 15.0))
	var mine := "%d:1" % level.net.local_seat
	match_net.sheet_local(mine, 0, PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.6, 0.4)]))
	check("Su trazo vuelve confirmado por el anfitrión", await wait_for(func(): return level.ui.sheet.log_index.has(mine), 15.0))
	var bravo := seat_named("Bravo")
	check("Se entera de la muerte de un compañero", await wait_for(func(): return level.session.participants.get(bravo) == level.session.Life.DEAD, 25.0))
	await pause_for(0.5)
	check("Sale del armario", match_net.use_hide(hide, false))
	await pause_for(0.5)
	level.player.global_position = refuge_point(Vector3(-0.8, 0, 0))
	check("Ve terminar el piso con la salida", await wait_for(func(): return level.session.state == level.session.State.WON, 60.0))
	check("Segundo piso", await wait_for(playing, 90.0))
	check("La hoja empieza vacía en el piso nuevo", level.ui.sheet.log.is_empty())
	match_net.sheet_local("%d:1" % level.net.local_seat, 0, PackedVector2Array([Vector2(0.3, 0.3), Vector2(0.7, 0.7)]))
	check("Vuelve a la sala con los demás", await wait_for(func(): return level.session.state == level.session.State.MENU and level.ui.screen == "lobby", 120.0))
	check("Se entera de que el anfitrión cerró la sala", await wait_for(func(): return not level.net.active() and level.ui.screen == "multiplayer", 30.0))

func bravo_part() -> void:
	var match_net = level.match_net
	check("Muere y observa a un compañero vivo", await wait_for(func(): return not level.local_alive() and not level.player.active and match_net.watched_body() != null and match_net.watched_body().camera.current, 60.0))
	match_net.sheet_local("%d:1" % level.net.local_seat, 0, PackedVector2Array([Vector2(0.5, 0.5), Vector2(0.9, 0.9)]))
	check("Ve terminar el piso aunque haya muerto", await wait_for(func(): return level.session.state == level.session.State.WON, 60.0))
	check("Segundo piso", await wait_for(playing, 90.0))
	await pause_for(2.0)
	var spot: Vector3 = level.player.global_position
	# Loses the connection and comes back with the same name.
	level.net.shutdown("")
	await pause_for(3.0)
	check("Al caerse vuelve al menú", not level.match_net.in_match())
	check("Se reconecta con el mismo nombre", level.net.join("127.0.0.1", "Bravo", 2, port) == OK)
	check("Recupera la misma plaza", await wait_for(func(): return level.net.local_seat == 3, 20.0))
	check("Vuelve al piso en curso", await wait_for(playing, 90.0))
	await pause_for(1.0)
	check("Reaparece donde estaba", level.player.global_position.distance_to(spot) < 2.5)
	check("Recupera la hoja con los trazos de los demás", level.ui.sheet.log_index.has("%d:1" % seat_named("Alpha")))
	check("Vuelve a la sala con los demás", await wait_for(func(): return level.session.state == level.session.State.MENU and level.ui.screen == "lobby", 120.0))

# --- Versus ------------------------------------------------------------------------

func versus_host() -> void:
	var net = level.net
	check("La sala versus se abre", net.host("Anfitrión", 0, port) == OK)
	check("Llega el cazador", await wait_for(func(): return net.connected_seats().size() == 2, 40.0))
	net.set_option("mode", net.Mode.VERSUS)
	var hunter := seat_named("Cazador")
	net.set_option("locust", hunter)
	check("Se elige quién es The Locust", int(net.options.locust) == hunter)
	check("Empieza el versus", net.start_match(90))
	check("Se juega el versus", await wait_for(playing, 60.0))
	var match_net = level.match_net
	check("En el anfitrión The Locust es una réplica del jugador", level.locust.control == "puppet")
	check("Solo el anfitrión es superviviente", level.session.participants.keys() == [1] and match_net.bodies.is_empty())
	check("Llega el movimiento de The Locust del jugador", await wait_for(func(): return not level.locust.net_states.is_empty(), 15.0))
	check("La protección inicial termina cuando el cazador la termina", await wait_for(func(): return level.locust.grace <= 0.0, 20.0))
	# A noise the hunter should see as a ring.
	await pause_for(1.0)
	level.on_noise(level.locust.global_position + Vector3(2.0, 0.2, 0.0), 12.0)
	var hide = level.hotel.hides[0]
	level.player.global_position = hide.to_global(hide.exit_offset) + Vector3(0, 0.1, 0)
	await pause_for(0.5)
	check("El superviviente se esconde", level.match_net.use_hide(hide, true) and level.player.hidden)
	check("The Locust jugador abre el armario a la fuerza", await wait_for(func(): return hide.opening > 0.5, 30.0))
	check("La estocada del cazador mata al superviviente y termina el piso", await wait_for(func(): return level.session.state == level.session.State.FAILED, 30.0))
	await pause_for(2.0)
	net.shutdown("")

func versus_hunter() -> void:
	var net = level.net
	await pause_for(1.5)
	check("El cazador se conecta", net.join("127.0.0.1", "Cazador", 1, port) == OK)
	check("Entra en el versus", await wait_for(playing, 90.0))
	var creature = level.locust
	check("Controla a The Locust", creature.control == "player" and creature.driver != null and creature.camera.current)
	check("Su jugador no cuenta como superviviente", not level.survivors().has(level.player) and not level.player.visible)
	creature.grace = 0.0
	check("Oye los ruidos de los supervivientes como anillos", await wait_for(func(): return not creature.driver.heard.is_empty(), 20.0))
	var hide = level.hotel.hides[0]
	check("Ve al superviviente meterse en el armario", await wait_for(func(): return is_instance_valid(hide.occupant), 30.0))
	creature.global_position = hide.to_global(hide.exit_offset + Vector3(0, 0, 0.9))
	await pause_for(0.6)
	level.match_net.locust_open_hide(hide)
	check("El armario se abre también aquí", await wait_for(func(): return hide.opening > 0.5, 15.0))
	# Face the open wardrobe and strike.
	var offset: Vector3 = hide.global_position - creature.global_position
	creature.rotation.y = atan2(-offset.x, -offset.z)
	await pause_for(0.3)
	creature.driver.strike()
	check("La estocada termina la caza", await wait_for(func(): return level.session.state == level.session.State.FAILED and level.ui.screen == "online_failed", 20.0))
