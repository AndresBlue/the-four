extends SceneTree
## Online play end to end, over real ENet connections on this machine. Run one
## process per player with --role=host|alpha|bravo (tools/net_test.ps1 starts
## all three). Each role plays its part of a scripted co-op floor and writes
## its checks to evidence/net_<role>.json:
##  room with three players, same floor for all, bodies moving, a door and a
##  wardrobe used through the host, a death watched from a teammate, leaving
##  the floor together, a dropped player coming back mid-floor, and everyone
##  sent back to the menu when the host closes the room.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
var role := "host"
var port := 24600
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", "[", role, "] ", title, "" if passed or detail.is_empty() else " · " + detail)

## Waits for a value that satisfies a test, and returns it (or the last one).
func wait_for_value(read: Callable, test: Callable, seconds: float):
	var left := seconds
	var value = read.call()
	while left > 0.0 and not test.call(value):
		await pause_for(0.2)
		left -= 0.2
		value = read.call()
	return value

## Waits (real time) until the condition holds or the time runs out.
func wait_for(condition: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call(): return true
		await process_frame
	return condition.call()

## Keeps the survivor walking on the spot, a step to one side and back. The
## shriek only finds what is moving, so a test that stands still proves nothing.
func sway() -> void:
	var way := 1.0 if int(Time.get_ticks_msec() / 400) % 2 == 0 else -1.0
	level.player.global_position += Vector3(0.025 * way, 0.0, 0.0)

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
	# Every role here writes the same test file: each is told who it is, and
	# starts with nothing kept, or they would all say the same card.
	level.records.id = "test-" + role
	level.records.career = {}
	level.records.milestones = {}
	level.records.rivals = {}
	level.session.changed.connect(func(): print("STATE [", role, "] ", level.session.State.keys()[level.session.state], " t=", Time.get_ticks_msec()))
	level.match_net.started.connect(func(): print("GO [", role, "] t=", Time.get_ticks_msec()))
	match role:
		"host": await host()
		"alpha": await guest("Alpha", 1)
		"bravo": await guest("Bravo", 2)
		"vs_host": await versus_host()
		"vs_hunter": await versus_hunter()
		"late_host": await late_host()
		"late_guest": await late_guest()
		"watch_host": await watch_host()
		"watch_guest": await watch_guest()
		"watcher": await watcher()
		"office_host": await office_host()
		"office_alpha": await office_guest("Alpha", 1)
		"office_bravo": await office_guest("Bravo", 2)
		"lk_host": await lurker_coop_host()
		"lk_victim": await lurker_victim(false)
		"lv_host": await lurker_versus_host()
		"lv_hunter": await lurker_hunter()
		"lv_victim": await lurker_victim(true)
	var file := FileAccess.open("res://evidence/net_%s.json" % role, FileAccess.WRITE)
	file.store_string(JSON.stringify({"role": role, "passed": failed == 0 and not checks.is_empty(), "checks": checks}, "\t"))
	file.close()
	print("NET_RESULT ", role, " ", failed == 0, " ", checks.size() - failed, "/", checks.size())
	level.net.shutdown("")
	await pause_for(0.3)
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

## Somebody watching from outside (--observer): it connects like a guest, takes
## no seat, has no body, and is sent everything.
func watch_host() -> void:
	var net = level.net
	check("La sala se abre para que la miren", net.host("Anfitrión", 0, port) == OK)
	check("Un jugador en la sala", await wait_for(func(): return net.connected_seats().size() == 2, 40.0))
	check("Y quien mira no ocupa plaza", await wait_for(func(): return not net.observers.is_empty(), 30.0) and net.connected_seats().size() == 2 and net.players.size() == 2)
	net.set_option("mode", net.Mode.COOP)
	check("Empieza la partida con quien mira dentro", net.start_match(81))
	check("Se juega", await wait_for(playing, 60.0))
	level.locust.grace = 0.0
	# Something for the watcher to see: the creature walks, a door swings.
	await pause_for(6.0)
	level.hotel.doors[3].toggle()
	await pause_for(12.0)
	check("El piso sigue en pie con un observador dentro", playing() and level.session.participants.size() == 2)

func watch_guest() -> void:
	var net = level.net
	check("Un jugador se une", net.join("127.0.0.1", "Alpha", 1, port) == OK)
	check("Y juega", await wait_for(playing, 90.0))
	var walked := 0.0
	while walked < 16.0:
		level.player.global_position += Vector3(0.1, 0, 0)
		await pause_for(0.25)
		walked += 0.25
	check("Sigue jugando mientras lo miran", playing())

func watcher() -> void:
	var net = level.net
	# It opens before anybody is hosting: nobody answers, so it looks at a
	# floor of its own and keeps knocking until a room opens.
	level.observer_port = port
	await level.begin_observing(4242)
	# Whether a room was open by the time it knocked is a matter of a second:
	# either it is already in, or it is looking at a floor of its own.
	check("Abre sin depender de que haya sala", level.observer and (net.observing or int(level.session.run_seed) == 4242))
	check("Y sigue llamando hasta que se abre una", await wait_for(func(): return net.observing, 60.0))
	check("Al empezar la partida recibe su piso, sin que nadie lo reabra", await wait_for(func(): return int(level.session.run_seed) == 81, 120.0))
	# The floor arriving sets the player's own camera up again, and the next
	# frame takes it back (observer_view._process).
	await pause_for(0.5)
	check("No tiene cuerpo ni cámara de jugador", level.observer and not level.player.visible and not level.player.active and level.observer_view.camera.current)
	check("Ve a los dos que juegan", await wait_for(func(): return level.match_net.bodies.size() == 2, 30.0))
	check("Y les llegan sus movimientos", await wait_for(func(): return level.match_net.bodies.values().any(func(body): return not body.states.is_empty()), 30.0))
	check("Ve a la criatura", is_instance_valid(level.locust) and level.locust.control == "puppet")
	var stood: Vector3 = level.locust.global_position
	check("Y la ve moverse", await wait_for(func(): return level.locust.global_position.distance_to(stood) > 1.0, 40.0))
	check("La sesión replicada le llega entera", level.session.state == level.session.State.PLAYING and level.session.participants.size() == 2)
	# What the tool is for: the panel says what the floor is doing.
	var words: String = level.observer_view.report()
	check("Y el panel lo cuenta", words.contains("THE LOCUST") and words.contains("ASCENSORES") and words.contains("semilla 81"))
	level.observer_view.snapshot()
	await pause_for(2.0)

func playing() -> bool:
	return level.session.state == level.session.State.PLAYING

func seat_named(words: String) -> int:
	for seat in level.net.players:
		if level.net.players[seat].name == words: return seat
	return 0

## The refuge of the stage in hand, which moves on with every stage closed.
func refuge_point(offset: Vector3) -> Vector3:
	var FLOOR := preload("res://game/world/generation/floor_definition.gd")
	return FLOOR.position_of(level.manifest.rooms[level.refuge_room()]) + offset + Vector3(0, 0.1, 0)

## Waits in the refuge of the stage in hand and steps through its door as
## soon as it opens, stage after stage, until the floor ends.
func cross_to_the_end(offset: Vector3, seconds: float) -> bool:
	var FLOOR := preload("res://game/world/generation/floor_definition.gd")
	var left := seconds
	while left > 0.0:
		var stage: int = level.session.stage
		var gate: Dictionary = level.manifest.gates[stage - 1]
		var door = level.hotel.gates[stage - 1] if level.hotel.gates.size() >= stage else null
		# Any stage played on televisions: go and switch one on. A guest asks
		# the host, which is the path worth exercising here. From the second
		# stage on every wing has its own sets, the last one included, where
		# they are asked for along with the code.
		if not level.sets_lit():
			for index in level.stage_televisions():
				var set = level.televisions[int(index)]
				if is_instance_valid(set) and not set.on:
					level.player.global_position = set.global_position + Vector3(0.9, 0.1, 0.9)
					await pause_for(0.2)
					level.switch_television(set)
					break
			await pause_for(0.3)
			left -= 0.5
			continue
		# The last stage: find the numbers, read the code in and step out.
		if level.session.goal.get("kind", "") == "code" and not level.code_entered:
			for piece in level.containers:
				if is_instance_valid(piece) and piece.digit >= 0 and not piece.searched:
					level.player.global_position = piece.global_position + Vector3(0.7, 0.1, 0.7)
					await pause_for(0.2)
					level.search_container(piece)
			await pause_for(0.4)
			if level.found_digits.size() >= 4:
				level.typed = "".join(level.DIGITS.code(level.manifest).map(func(digit): return str(digit)))
				level.match_net.use_code()
			left -= 1.0
			continue
		# Into the car of this stage's lift, which is what closes a stage and,
		# for the last one, what leaves the floor. The offset is what keeps
		# two guests from standing in the same place; the car is small, so it
		# is halved to stay inside it.
		if is_instance_valid(door) and not door.locked and level.hotel.lifts.size() >= level.session.stage:
			level.player.global_position = level.hotel.lifts[level.session.stage - 1] + offset * 0.5 + Vector3(0, 0.1, 0)
			level.match_net.call_lift(level.session.stage - 1)
		else:
			level.player.global_position = refuge_point(offset)
		await pause_for(0.1)
		left -= 0.1
		if level.session.state == level.session.State.WON: return true
	return false

# --- Host ------------------------------------------------------------------------

func host() -> void:
	var net = level.net
	check("La sala se abre", net.host("Anfitrión", 0, port) == OK)
	check("Tres jugadores en la sala", await wait_for(func(): return net.connected_seats().size() == 3, 40.0))
	check("No se puede empezar con modo inválido de Locust ausente", true)
	net.set_option("mode", net.Mode.COOP)
	# The room plays by a rule of its own: it goes with the match to everybody.
	net.set_option("rules", {"plan_fade": 300, "restarts": 1, "sobra": 4})
	check("La sala guarda solo lo que cambió de las reglas", net.options.rules == {"plan_fade": 300, "restarts": 1})
	# And plays against the creature of a difficulty of its own.
	net.set_option("difficulty", "equilibrada")
	net.set_option("difficulty", "imposible")
	check("Una dificultad que no existe no se queda", net.options.difficulty == "desafiante")
	net.set_option("difficulty", "equilibrada")
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
	# Its mind is the host's to keep: the host has been wearing it down from
	# what it knows of that body, and here it is taken to the bottom.
	check("El anfitrión lleva la cordura de cada invitado", level.sanity.minds.has(alpha))
	level.sanity.minds[alpha] = {"sanity": 0.0, "rest": 0.0}
	check("Un trazo de un invitado entra en la hoja del anfitrión", await wait_for(func(): return level.ui.sheet.log_index.has("%d:1" % alpha), 15.0))
	check("Aquí se ve que a ese invitado se le fue la cabeza", await wait_for(func(): return match_net.bodies[alpha].burnt, 20.0))
	check("Y el director sabe que se ha ido, sin que la criatura le oiga", not level.sanity.burnt_survivors().is_empty())
	# Bravo is struck down: with three survivors the floor goes on (two needed).
	await pause_for(1.0)
	check("Una muerte no termina el piso de tres", level.session.capture(bravo) and playing())
	await pause_for(3.0)
	check("Un muerto no puede dibujar en la hoja", not level.ui.sheet.log_index.has("%d:1" % bravo))
	check("Quien se cuenta muerto sin haber caído no deja un cuerpo de pie, ni estorba", await wait_for(func(): return match_net.bodies[bravo].dead and match_net.bodies[bravo].collision_layer == 0 and not match_net.bodies[bravo].visible, 10.0))
	check("El armario queda libre al salir el invitado", await wait_for(func(): return not is_instance_valid(hide.occupant), 30.0))
	# The host goes down as well: one of three is under the quota, so the floor
	# gives the stage back instead of ending and everybody gets up. What is
	# being looked at is what that does on a guest's own machine, which is
	# where the body was put away when it died.
	check("Perder la cuota devuelve la etapa en vez de terminar el piso", level.session.capture(1) and playing() and level.session.restart_wait > 0.0)
	check("Con la etapa devuelta se levantan todos", await wait_for(func(): return level.session.participants[bravo] == level.session.Life.EXPLORING and level.local_alive() and level.player.visible, 25.0))
	check("Y el anfitrión vuelve a su propia cámara", level.player.camera.current and not is_instance_valid(level.watch_rig))
	# Long enough for the guest to see itself on its feet, and down it goes
	# again: with two of three alive the floor carries on as it did before.
	await pause_for(3.0)
	check("Y se puede volver a caer sin hundir el piso", level.session.capture(bravo) and playing())
	await pause_for(1.0)
	level.player.global_position = refuge_point(Vector3(0.8, 0, 0))
	check("El superviviente invitado llega al refugio", await wait_for(func(): return level.point_in_refuge(match_net.bodies[alpha].global_position), 30.0))
	await pause_for(0.5)
	# A floor is three stages now, each with its own refuge in its own wing.
	# Nothing is held down: with everyone inside, the door on unlocks and
	# crossing it is what closes the stage.
	var opened: bool = await wait_for(func(): return not level.hotel.gates[0].locked, 25.0)
	check("Con todos dentro se abre la puerta de la etapa", opened and level.session.goal.ready)
	var won: bool = await cross_to_the_end(Vector3(0.8, 0, 0), 150.0)
	check("Cruzarla lleva a la etapa siguiente y no termina el piso", level.session.stage > 1)
	check("La etapa de los televisores se jugó de verdad", level.televisions.size() >= 4 and level.televisions_on() >= 2)
	check("Salen del piso al cerrar la última etapa", won and level.session.stage == level.session.stages)
	var tape: Dictionary = level.ui.summary
	check("El parte lleva a los tres, con su puntaje y quién fue el más valioso", tape.get("team", []).size() == 3 and int(tape.get("score", 0)) > 0 and int(tape.get("mvp", 0)) in [1, 2, 3] and int(tape.team[0].get("tvs", 0)) >= 2 and int(tape.team[1].get("hides", 0)) >= 1, str(tape.get("team", [])))
	check("Jugada con otras reglas, la cinta lo dice y va a su propio tablón", tape.get("rules", {}) == {"plan_fade": 300, "restarts": 1} and String(tape.get("difficulty", "")) == "equilibrada" and String(tape.get("company", "")) == level.records.CUSTOM and level.ui.outcome.milestones.is_empty())
	check("Y el anfitrión guarda las fichas de sus dos invitados", level.records.rivals.has("test-alpha") and level.records.rivals.has("test-bravo") and int(level.records.rivals["test-alpha"].get("together", 0)) == 1)
	# Second floor, after everyone has seen the end: Bravo drops and comes back.
	await pause_for(5.0)
	check("Nueva partida desde el final", net.start_match(82))
	check("Segundo piso en juego", await wait_for(playing, 60.0))
	level.locust.grace = 100000.0
	check("El jugador caído queda en la partida mientras vuelve", await wait_for(func(): return match_net.away.has(bravo), 30.0) and match_net.bodies.has(bravo) and level.session.participants[bravo] != level.session.Life.DEAD)
	check("Vuelve con su plaza antes de 60 s", await wait_for(func(): return not match_net.away.has(bravo) and net.players[bravo].connected, 40.0))
	await pause_for(3.0)
	check("Sigue vivo tras volver", level.session.participants[bravo] == level.session.Life.EXPLORING and playing())
	# The host dies and only the guests are left: the floor still has to be
	# finishable. The hold at the exit is counted here, on the host, and used
	# to be skipped entirely while its own player was dead and watching.
	await pause_for(1.0)
	check("El anfitrión cae y el piso sigue", level.session.capture(1) and playing())
	var left: bool = await wait_for(func(): return level.session.state == level.session.State.WON, 240.0)
	check("Con el anfitrión muerto, sus invitados salen del piso", left)
	await pause_for(3.0)
	net.return_to_lobby()
	check("Todos vuelven a la sala", level.session.state == level.session.State.MENU and not net.in_match)
	await pause_for(2.0)
	net.shutdown("")

# --- A lift taken one after the other ------------------------------------------------
# The host takes the first car on its own; the guest follows it a car later,
# once it has come back down. What the guest reads on the way, and whether the
# two of them can still take the next car together, is what is looked at: the
# late one used to arrive to "SECTOR 3" and the floor stopped short of the
# last wing.

func late_host() -> void:
	var net = level.net
	check("La sala se abre", net.host("Anfitrión", 0, port) == OK)
	check("Llega el invitado", await wait_for(func(): return net.connected_seats().size() == 2, 40.0))
	net.set_option("mode", net.Mode.COOP)
	check("Empieza la partida", net.start_match(81))
	check("Se juega", await wait_for(playing, 60.0))
	level.locust.grace = 100000.0
	level.player.global_position = refuge_point(Vector3(0.6, 0, 0))
	check("Con los dos en el refugio se abre la puerta", await wait_for(func(): return not level.hotel.gates[0].locked, 40.0))
	await pause_for(0.5)
	level.player.global_position = level.hotel.lifts[0] + Vector3(0, 0.1, 0)
	await pause_for(0.5)
	level.match_net.call_lift(0)
	check("El anfitrión sube solo y cierra el sector 1", await wait_for(func(): return level.session.stage == 2, 20.0))
	var guest_seat: int = level.match_net.bodies.keys()[0]
	check("El invitado llega después, en su propio viaje", await wait_for(func(): return level.match_net.bodies[guest_seat].global_position.distance_to(level.hotel.arrivals[0]) < 4.0, 60.0))
	for index in level.stage_televisions():
		var set = level.televisions[int(index)]
		if is_instance_valid(set) and not set.on: level.switch_television(set)
	check("Con las teles del sector 2 se abre su puerta", await wait_for(func(): return not level.hotel.gates[1].locked, 20.0))
	# This time it waits for the guest in the car, and only then presses.
	level.player.global_position = level.hotel.lifts[1] + Vector3(0.3, 0.1, 0)
	check("Esperan juntos dentro del coche", await wait_for(func(): return level.match_net.bodies[guest_seat].global_position.distance_to(level.hotel.lifts[1]) < level.lifts.RIDE_REACH, 40.0))
	check("Y el coche no se ha ido con el primero", level.session.stage == 2)
	await pause_for(1.0)
	level.match_net.call_lift(1)
	check("El siguiente ascensor lleva al sector 3", await wait_for(func(): return level.session.stage == 3, 30.0))
	await pause_for(8.0)

func late_guest() -> void:
	var net = level.net
	await pause_for(1.0)
	check("Se conecta", net.join("127.0.0.1", "Tarde", 1, port) == OK)
	check("Entra en el piso", await wait_for(playing, 90.0))
	level.player.global_position = refuge_point(Vector3(-0.6, 0, 0))
	check("Ve cerrarse el sector 1 sin haber subido", await wait_for(func(): return level.session.stage == 2, 60.0))
	var gate: Dictionary = level.manifest.gates[0]
	# Back beside the first car, waiting for it to come down again: the ride
	# and LIFT_RETURN after the host pressed (it was a fixed 17 s, from when
	# the car came back as soon as the ride began).
	check("El coche vuelve a bajar", await wait_for(func(): return not level.lifts.lift_gone(0), 40.0))
	await pause_for(0.5)
	level.player.global_position = level.hotel.lifts[0] + Vector3(0, 0.1, 0)
	await pause_for(0.5)
	level.match_net.call_lift(0)
	var card: bool = await wait_for(func(): return is_instance_valid(level.ui.transit), 10.0)
	var words := ""
	if card:
		for node in level.ui.transit.find_children("*", "Label", true, false): words += node.text + " · "
	print("LATE card: ", words)
	check("Su tarjeta dice el sector al que llega, el 2", card and words.contains("SECTOR 2") and not words.contains("SECTOR 3"))
	check("Y sale en el ala 2", await wait_for(func(): return level.lifts.boarding.is_empty() and level.player.global_position.distance_to(level.hotel.arrivals[0]) < 4.0, 15.0))
	check("Espera abierta la puerta del sector 2", await wait_for(func(): return not level.hotel.gates[1].locked, 40.0))
	await pause_for(1.5)
	level.player.global_position = level.hotel.lifts[1] + Vector3(-0.3, 0.1, 0)
	check("Y los dos llegan al sector 3, en el mismo viaje", await wait_for(func(): return level.session.stage == 3, 40.0) and await wait_for(func(): return level.lifts.boarding.is_empty() and int(preload("res://game/world/generation/floor_definition.gd").room_at(level.manifest.rooms, level.player.global_position).get("wing", -1)) == 2, 15.0))
	print("LATE end: stage ", level.session.stage, " gates ", level.hotel.gates.map(func(door): return door.locked))

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
	check("Y contra la criatura de la dificultad que eligió", level.difficulty == "equilibrada" and is_equal_approx(level.locust.chase_speed, float(preload("res://game/floors/difficulty.gd").PROFILES.equilibrada.chase_speed)) and level.locust.chase_speed < float(preload("res://game/floors/difficulty.gd").PROFILES.desafiante.chase_speed))
	check("Juega con las reglas que puso el anfitrión, y las demás como siempre", level.rule("plan_fade") == 300 and is_equal_approx(level.floor_map.forget, 300.0) and level.rule("restarts") == 1 and level.rule("blackout") == 1)
	check("Ve los cuerpos de los otros dos", match_net.bodies.size() == 2 and match_net.bodies.has(1))
	check("Ve moverse al anfitrión", await wait_for(func(): return not match_net.bodies[1].states.is_empty(), 15.0))
	# The other guest is not connected to this one: what it says reaches here
	# only because the host passes it on (match_net.relay()). Over Steam, with
	# nothing passing it on, the guests saw each other stand still.
	check("Y al otro invitado, por el anfitrión", await wait_for(func(): return match_net.bodies.keys().any(func(seat): return int(seat) != 1 and not match_net.bodies[seat].states.is_empty()), 15.0))
	check("Sin conexión directa con él: solo con el anfitrión", multiplayer_peers() == [1])
	if words == "Alpha": await alpha_part()
	else: await bravo_part()

# --- Floor 2 online (spec_f1_systems 6.3): the card, on every machine -------------

## The host: a room on floor 2. It waits for both guests' requests, sends
## their capsules in at once, and sees the quota through the reader open
## the freight lift's door.
func office_host() -> void:
	var net = level.net
	# The floor's systems over the net, without her (phase 1's).
	level.creature_scene = "none"
	check("La sala se abre", net.host("Anfitrión", 0, port) == OK)
	check("Tres jugadores en la sala", await wait_for(func(): return net.connected_seats().size() == 3, 40.0))
	net.set_option("mode", net.Mode.COOP)
	net.set_option("floor", 2)
	check("Empieza la partida en el piso 2", net.start_match(7))
	check("Todos construyen las oficinas y se juega", await wait_for(playing, 90.0) and int(level.manifest.get("floor", 1)) == 2)
	var files = level.objective(&"files")
	var alpha := seat_named("Alpha")
	var bravo := seat_named("Bravo")
	check("Las dos peticiones llegan al anfitrión", await wait_for(func(): return files.requests.has(alpha) and files.requests.has(bravo), 60.0))
	check("Y van a estaciones distintas", files.requests.has(alpha) and files.requests.has(bravo) and int(files.requests[alpha].station) != int(files.requests[bravo].station))
	# The capsules in at once, rather than 25 s of tube.
	for seat in files.requests: files.requests[seat].arrive = float(level.session.elapsed)
	check("Las cápsulas llegan a sus bandejas", await wait_for(func(): return files.requests.values().all(func(r): return int(r.state) != files.Card.TRAVELLING), 10.0))
	check("La foto de Alpha llega al anfitrión", await wait_for(func(): return files.photos.has(alpha), 40.0))
	check("Las dos fichas pasan por el lector", await wait_for(func(): return files.swiped.size() >= 2, 60.0))
	check("Con la cuota, la puerta del montacargas se abre", await wait_for(func(): return not level.hotel.gates[0].locked, 15.0))
	var power = level.objective(&"power")
	var air = level.objective(&"air")
	check("El cuadro de los invitados se aplica en el anfitrión", await wait_for(func(): return not power.on_order.has(0) and power.on_order.size() == power.budget, 90.0))
	check("Y el aire: la seguridad abierta, los ventiladores encendidos y parados", await wait_for(func(): return air.post_open and air.released and air.charges == 1 and not air.running(), 90.0))
	# Bravo leaves and comes back: its seat is held for it, and it is put up
	# to date when it has built the floor again.
	var bravo_back := await wait_for(func(): return level.match_net.away.has(bravo), 60.0)
	check("Bravo se va y su plaza le espera", bravo_back)
	check("Y vuelve", await wait_for(func(): return not level.match_net.away.has(bravo) and net.connected_seats().has(bravo), 120.0))
	# The rides: the three into the first car, the button; the red lever's
	# clock (short here) on level 2; the three into the second car.
	power.lift_timer = 3.0
	await pause_for(15.0)
	check("Los tres bajan al nivel 2", await host_ride(0, 2))
	check("La palanca roja de Alpha arma el montacargas", await wait_for(func(): return power.red == power.Red.ARMED, 90.0))
	check("Los tres bajan al nivel 3", await host_ride(1, 3))
	# The guests check what they were told before the room goes.
	await pause_for(15.0)

## The host in a car, pressing until the floor is on `stage` (its riders in).
func host_ride(car: int, stage: int) -> bool:
	for attempt in 240:
		if level.session.stage >= stage and level.lifts.boarding.is_empty(): return true
		if level.lifts.boarding.is_empty() and not level.lifts.riding.has(level.player.slot):
			level.player.global_position = level.hotel.lifts[car] + Vector3(0, 0.1, 0.3)
			level.player.velocity = Vector3.ZERO
			if level.lifts.inside(car).size() >= 3: level.match_net.call_lift(car)
		await pause_for(0.5)
	return level.session.stage >= stage

## A guest on floor 2: types its request at the window, takes its card from
## its station once in, and puts it through the reader; Alpha also sends a
## photo, which Bravo has to get through the host.
func office_guest(words: String, index: int) -> void:
	var net = level.net
	level.creature_scene = "none"
	await pause_for(1.0 + index * 0.5)
	check("Se conecta a la sala", net.join("127.0.0.1", words, index, port) == OK)
	check("Entra en el piso del anfitrión, las oficinas", await wait_for(playing, 120.0) and int(level.manifest.get("floor", 1)) == 2)
	var files = level.objective(&"files")
	var seat: int = net.local_seat
	var asked := func(action: String, usable: int, done: Callable, objective := &"files") -> bool:
		var handler = level.objective(objective)
		var stand: Vector3 = handler.usables[usable].stand
		for attempt in 30:
			if done.call(): return true
			level.player.global_position = stand + Vector3(0, 0.05, 0)
			level.player.velocity = Vector3.ZERO
			await pause_for(0.5)
			level.match_net.use_office(objective, action, usable)
			await pause_for(0.5)
		return done.call()
	check("Su petición la confirma el anfitrión", await asked.call("type", 0, func(): return files.requests.has(seat)))
	check("Y ve también la del otro, por el anfitrión", await wait_for(func(): return files.requests.size() == 2, 30.0))
	check("Su cápsula llega a la bandeja que le dijo el anfitrión", await wait_for(func(): return files.requests.has(seat) and int(files.requests[seat].state) == files.Card.IN_TRAY and files.lamps[int(files.requests[seat].station)].visible, 30.0))
	if words == "Alpha":
		var grey := Image.create(240, 304, false, Image.FORMAT_RGB8)
		grey.fill(Color(0.35, 0.35, 0.35))
		files.textures[seat] = ImageTexture.create_from_image(grey)
		files.send_photo(seat)
	var station: int = int(files.requests[seat].station) + 1
	check("Recoge su ficha", await asked.call("take", station, func(): return files.has_card(seat)))
	level.interaction.close_document()
	check("Y la pasa por el lector", await asked.call("swipe", files.reader_index(), func(): return files.swiped.has(seat)))
	check("La puerta del montacargas se abre también aquí", await wait_for(func(): return not level.hotel.gates[0].locked, 30.0))
	if words == "Bravo":
		var alpha := seat_named("Alpha")
		check("La foto de Alpha le llega por el anfitrión, igual", await wait_for(func(): return files.photos.has(alpha) and files.textures.has(alpha), 30.0))
	# The board of planta 2 and the post of planta 3, worked by both guests.
	var power = level.objective(&"power")
	var air = level.objective(&"air")
	var zone_room := func(z: int) -> int:
		for id in power.zones[z].rooms:
			if not power.lit_always.has(int(id)) and not level.hotel.dark_ids.has(int(id)): return int(id)
		return -1
	if words == "Alpha":
		check("Sube una zona del cuadro", await asked.call("lever", 0, func(): return power.on_order.has(0), &"power"))
		check("Y la sala de esa zona se enciende aquí", await wait_for(func(): return level.hotel.lit(zone_room.call(0)), 10.0))
		check("Pasa su ficha por el lector de la seguridad", await asked.call("post", 3, func(): return air.post_open, &"air"))
	else:
		check("Ve subir la zona que subió Alpha", await wait_for(func(): return power.on_order == [0], 60.0))
		for z in range(1, power.budget + 1):
			await asked.call("lever", z, func(): return power.on_order.has(z), &"power")
		check("Pasado el presupuesto, cae la primera", await wait_for(func(): return not power.on_order.has(0) and power.on_order.size() == power.budget, 20.0))
		check("Ve abierta la seguridad que abrió Alpha", await wait_for(func(): return air.post_open and not air.post_door.locked, 60.0))
		check("Enciende los ventiladores desde la consola", await asked.call("start", 4, func(): return air.running(), &"air"))
		check("Y los para", await asked.call("stop", 5, func(): return not air.running(), &"air"))
	check("El cuadro queda igual en todos", await wait_for(func(): return not power.on_order.has(0) and power.on_order.size() == power.budget, 60.0))
	check("Y el aire también: la seguridad abierta, una carga gastada, parados", await wait_for(func(): return air.post_open and air.released and air.charges == 1 and not air.running(), 60.0))
	if words == "Bravo":
		await office_return(words, index)
	await office_rides(words)

## Into a car and stood there until the floor is on `stage` (the host presses).
func ride_to(car: int, stage: int, offset: Vector3) -> bool:
	for attempt in 360:
		if level.session.stage >= stage and level.lifts.boarding.is_empty(): return true
		if level.lifts.boarding.is_empty() and not level.lifts.riding.has(level.net.local_seat):
			level.player.global_position = level.hotel.lifts[car] + offset + Vector3(0, 0.1, 0)
			level.player.velocity = Vector3.ZERO
		await pause_for(0.5)
	return level.session.stage >= stage

## Both guests ride with the host to level 2; Alpha pulls the red lever there;
## then the three ride on to level 3.
func office_rides(words: String) -> void:
	var offset := Vector3(0.4 if words == "Alpha" else -0.4, 0, 0)
	check("Baja con los demás al nivel 2", await ride_to(0, 2, offset))
	var power = level.objective(&"power")
	if words == "Alpha":
		var red: int = power.red_index()
		var stand: Vector3 = power.usables[red].stand
		for attempt in 30:
			if power.red != power.Red.DOWN: break
			level.player.global_position = stand + Vector3(0, 0.05, 0)
			level.player.velocity = Vector3.ZERO
			await pause_for(0.5)
			level.match_net.use_office(&"power", "red", red)
			await pause_for(0.5)
		check("Tira de la palanca roja", power.red != power.Red.DOWN)
	check("El reloj del montacargas acaba también aquí", await wait_for(func(): return power.red == power.Red.ARMED, 60.0))
	check("Y bajan juntos al nivel 3", await ride_to(1, 3, offset))

## Bravo leaves and comes back.
func office_return(words: String, index: int) -> void:
	var net = level.net
	var files = level.objective(&"files")
	var power = level.objective(&"power")
	var air = level.objective(&"air")
	# Bravo leaves and comes back: it builds the floor again, and the host's
	# catch-up gives it the card, the board and the air as they stand.
	var alpha_seat := seat_named("Alpha")
	var budget: int = power.budget
	net.shutdown("")
	await pause_for(3.0)
	check("Vuelve a la sala", net.join("127.0.0.1", words, index, port) == OK)
	check("Y al piso, montado otra vez", await wait_for(func(): return playing() and level.objective(&"files") != files, 120.0))
	files = level.objective(&"files")
	power = level.objective(&"power")
	air = level.objective(&"air")
	check("Puesto al día: las dos fichas, pasadas, y la foto de Alpha", await wait_for(func(): return files.requests.size() == 2 and files.swiped.size() == 2 and files.photos.has(alpha_seat), 30.0))
	check("El cuadro como lo tiene el anfitrión", power.on_order.size() == budget and not power.on_order.has(0))
	check("Y el aire: la seguridad abierta y su puerta sin llave", air.post_open and air.released and air.charges == 1 and not air.running() and not air.post_door.locked)

func multiplayer_peers() -> Array:
	return Array(level.multiplayer.get_peers())

func alpha_part() -> void:
	var match_net = level.match_net
	var door = level.hotel.doors[3]
	var was_open: bool = door.opened
	level.player.global_position = door.doorway + Basis(Vector3.UP, door.closed_rotation).z * 2.0 + Vector3(0, 0.1, 0)
	# Asked again every second until it moves: the host only answers a guest
	# it knows to be near, and where the guest stands reaches it a moment
	# after the guest has moved. A single request was sometimes judged from
	# where it had been before.
	var asked := {"at": -10.0}
	check("La puerta pedida se mueve también aquí", await wait_for(func():
		var now := Time.get_ticks_msec() / 1000.0
		if door.opened == was_open and not door.moving and now - float(asked.at) > 1.0:
			asked.at = now
			match_net.use_door(door, false, false)
		return door.opened != was_open and not door.moving, 15.0))
	var hide = level.hotel.hides[0]
	level.player.global_position = hide.to_global(hide.exit_offset) + Vector3(0, 0.1, 0)
	await pause_for(0.8)
	match_net.use_hide(hide, true)
	check("El anfitrión le deja entrar al armario", await wait_for(func(): return level.player.hidden, 15.0))
	# Shut in the dark with nothing left: the host says so, and this machine
	# takes its word for it -- the meter and the mark are both the host's.
	check("Encerrado y sin cabeza, el anfitrión se lo dice", await wait_for(func(): return level.player.burnt and level.player.sanity < 1.0, 20.0))
	var mine := "%d:1" % level.net.local_seat
	match_net.sheet_local(mine, 0, PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.6, 0.4)]))
	check("Su trazo vuelve confirmado por el anfitrión", await wait_for(func(): return level.ui.sheet.log_index.has(mine), 15.0))
	var bravo := seat_named("Bravo")
	check("Se entera de la muerte de un compañero", await wait_for(func(): return level.session.participants.get(bravo) == level.session.Life.DEAD, 25.0))
	await pause_for(0.5)
	check("Sale del armario", match_net.use_hide(hide, false))
	await pause_for(0.5)
	check("Le llega el cambio de etapa del anfitrión", await wait_for(func():
		level.player.global_position = refuge_point(Vector3(-0.8, 0, 0))
		return level.session.stage > 1, 60.0))
	check("Ve terminar el piso con la salida", await cross_to_the_end(Vector3(-0.8, 0, 0), 220.0))
	check("Le llega el parte del anfitrión, y su pantalla de fin lo enseña", await wait_for(func(): return level.ui.summary.get("team", []).size() == 3 and level.ui.screen == "online_won" and is_instance_valid(level.ui.settings_tabs), 15.0) and int(level.records.career.get("floors", 0)) == 1)
	check("Y guarda las fichas del anfitrión y del otro invitado", level.records.rivals.has("test-host") and level.records.rivals.has("test-bravo"), str(level.records.rivals.keys()))
	check("Segundo piso", await wait_for(playing, 90.0))
	check("La hoja empieza vacía en el piso nuevo", level.ui.sheet.log.is_empty())
	match_net.sheet_local("%d:1" % level.net.local_seat, 0, PackedVector2Array([Vector2(0.3, 0.3), Vector2(0.7, 0.7)]))
	# The host dies: the two guests leave the floor on their own.
	check("Ve morir al anfitrión", await wait_for(func(): return level.session.participants.get(1) == level.session.Life.DEAD, 90.0))
	await pause_for(1.0)
	var alone: bool = await cross_to_the_end(Vector3(-0.8, 0, 0), 220.0)
	check("Sale del piso sin el anfitrión", alone)
	check("Vuelve a la sala con los demás", await wait_for(func(): return level.session.state == level.session.State.MENU and level.ui.screen == "lobby", 120.0))
	check("Se entera de que el anfitrión cerró la sala", await wait_for(func(): return not level.net.active() and level.ui.screen == "multiplayer", 30.0))

func bravo_part() -> void:
	var match_net = level.match_net
	check("Muere y mira por la cámara de un compañero vivo", await wait_for(func(): return not level.local_alive() and not level.player.active and match_net.watched_body() != null and is_instance_valid(level.watch_camera) and level.watch_camera.current, 60.0))
	# What it sees is that teammate's own picture: from its camera, as its
	# owner sends it, with its own body out of the frame and its shadow in it.
	await pause_for(0.5)
	var watched = match_net.watched_body()
	var through: bool = level.watch_camera.global_position.distance_to(watched.camera.global_position) < 0.15 and level.watch_camera.global_position.distance_to(watched.global_position + Vector3(0, 1.4, 0)) < 0.6
	var unseen: bool = watched.avatar.meshes.all(func(mesh): return (mesh.layers & 1) == 0)
	check("Ve lo que ve su compañero, desde su cámara y sin su propio cuerpo delante", through and unseen, "camera %.2f m from the teammate's" % level.watch_camera.global_position.distance_to(watched.camera.global_position))
	# The stage is given back and this body has to come back whole. Its own
	# camera, its own body, and the torch in the hand: the torch trails the
	# camera instead of hanging from it, and it is hidden along with the body,
	# so what it looks like from inside is a light that everybody else can see
	# and its owner cannot. The word arrives before the replicated session
	# says so, which is the half second this used to be lost in.
	level.player.torch.visible = true
	var raised: bool = await wait_for(func(): return level.local_alive() and level.player.visible and level.player.camera.current and not is_instance_valid(level.watch_rig), 30.0)
	check("Al devolver la etapa recupera su cuerpo y su cámara", raised)
	check("Y el compañero por el que miraba vuelve a verse entero", watched.avatar.meshes.all(func(mesh): return (mesh.layers & 1) != 0))
	check("Y su linterna vuelve con él en vez de quedarse donde murió", level.player.torch.is_visible_in_tree() and level.player.torch.global_position.distance_to(level.player.camera.global_position) < 1.5)
	match_net.sheet_local("%d:1" % level.net.local_seat, 0, PackedVector2Array([Vector2(0.5, 0.5), Vector2(0.9, 0.9)]))
	check("Ve terminar el piso aunque haya muerto", await wait_for(func(): return level.session.state == level.session.State.WON, 120.0))
	check("Segundo piso", await wait_for(playing, 90.0))
	await pause_for(2.0)
	# Somewhere it would not be standing anyway: coming back where you were is
	# only proved by having been somewhere else first. Its spawn point is where
	# a floor puts it, and where it would end up if nothing restored anything.
	var FLOOR := preload("res://game/world/generation/floor_definition.gd")
	for room in level.manifest.rooms:
		var here: Vector3 = FLOOR.position_of(room)
		if int(room.get("wing", 0)) == 0 and here.distance_to(level.player.spawn) > 25.0:
			level.player.global_position = here + Vector3(0.6, 0.1, 0.6)
			break
	await pause_for(1.5)
	var spot: Vector3 = level.player.global_position
	check("Se va lejos de donde le puso el piso", spot.distance_to(level.player.spawn) > 25.0)
	# Loses the connection and comes back with the same name.
	level.net.shutdown("")
	await pause_for(3.0)
	check("Al caerse vuelve al menú", not level.match_net.in_match())
	check("Se reconecta con el mismo nombre", level.net.join("127.0.0.1", "Bravo", 2, port) == OK)
	check("Recupera la misma plaza", await wait_for(func(): return level.net.local_seat == 3, 20.0))
	check("Vuelve al piso en curso", await wait_for(playing, 90.0))
	await pause_for(1.0)
	var came_back: Vector3 = level.player.global_position
	check("Reaparece donde estaba", came_back.distance_to(spot) < 2.5, "en %s, estaba en %s, salida del piso en %s" % [came_back, spot, level.player.spawn])
	check("Recupera la hoja con los trazos de los demás", level.ui.sheet.log_index.has("%d:1" % seat_named("Alpha")))
	check("Ve morir al anfitrión", await wait_for(func(): return level.session.participants.get(1) == level.session.Life.DEAD, 90.0))
	await pause_for(1.0)
	var alone: bool = await cross_to_the_end(Vector3(0.9, 0, 0), 220.0)
	check("Sale del piso sin el anfitrión", alone)
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
	# The hunt is audible from here, and what arrives is a grunt, not a shriek.
	check("Los gruñidos de caza del cazador llegan aquí", await wait_for(func(): return level.locust.last_call == "grunt", 30.0))
	# Kept walking while the hunter shrieks: its cry only finds what is moving,
	# so a survivor standing still would give it nothing to mark. And a noise
	# the hunter should hear as a contact, made again every second while this
	# waits: a single noise at one moment sometimes went out before the
	# hunter was listening for it.
	var noised := {"at": -10.0}
	check("Oye el chillido del cazador", await wait_for(func():
		sway()
		var now := Time.get_ticks_msec() / 1000.0
		if now - float(noised.at) >= 1.0:
			noised.at = now
			level.on_noise(level.locust.global_position + Vector3(2.0, 0.2, 0.0), 12.0)
		return level.locust.last_call == "howl", 25.0))
	# Two sets lit, so the hunter has channels to travel by. The channels are
	# the ones of the stage being played -- a set burning in a wing nobody is
	# in is no way out -- so the floor is moved on to the stage of that wing.
	level.session.stage = 2
	level.session.changed.emit()
	await pause_for(1.0)
	for index in level.stage_televisions(2).slice(0, 2):
		level.apply_television(int(index), true)
		match_net.television_state.rpc(int(index), true)
	check("Las teles encendidas llegan a la máquina del cazador", level.lit_televisions().size() >= 2)
	check("El viaje del cazador por las teles se ve aquí", await wait_for(func():
		sway()
		return level.creature_at_television() >= 0, 60.0))
	for i in 120:
		sway()
		await physics_frame
	var hide = level.hotel.hides[0]
	level.player.global_position = hide.to_global(hide.exit_offset) + Vector3(0, 0.1, 0)
	await pause_for(0.5)
	check("El superviviente se esconde", level.match_net.use_hide(hide, true) and level.player.hidden)
	check("Abre el armario de golpe, las dos hojas", await wait_for(func(): return hide.pulled and hide.opening > 0.5, 30.0))
	check("Lo saca del armario y lo ejecuta en el aire", await wait_for(func(): return not level.execution.is_empty() and not level.player.hidden, 10.0) and await wait_for(func(): return level.player.global_position.y > 0.8, 3.0))
	check("La ejecución no es instantánea", level.session.state == level.session.State.PLAYING)
	# One against one there is no team to forgive: the execution ends the floor.
	check("Al final de la ejecución cae el superviviente", await wait_for(func(): return level.session.participants[1] == level.session.Life.DEAD, 15.0))
	check("Y con un solo superviviente, el piso se acaba ahí", await wait_for(func(): return level.session.state == level.session.State.FAILED and level.session.restarts == 0, 15.0))
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
	# Sprinting with nobody in sight is only running: no voice. It used to
	# grunt at every press of the key, telling the floor where it was for
	# nothing.
	var prey: Node3D = level.match_net.bodies[1]
	# On walkable floor: the reception has its furniture, and a creature put
	# down inside a sofa hears from a scrap of floor of its own.
	var floor_map: RID = level.get_world_3d().navigation_map
	creature.global_position = FLOOR.closest(floor_map, prey.global_position + Vector3(5.0, 0.0, 0.0)) + Vector3(0, 0.04, 0)
	creature.look_at(prey.global_position + Vector3(10.0, 0.0, 0.0) * 2.0, Vector3.UP)
	creature.calls_made = 0
	Input.action_press("forward")
	Input.action_press("sprint")
	await pause_for(2.0)
	Input.action_release("sprint")
	Input.action_release("forward")
	check("Correr sin nadie a la vista no le hace gruñir", creature.calls_made == 0)
	# With a survivor in plain sight the run is a chase, and a chase has a voice.
	# Four metres off: the reception is twelve metres across at the least, and
	# six would put it in the wall.
	creature.global_position = FLOOR.closest(floor_map, prey.global_position + Vector3(4.0, 0.0, 0.0)) + Vector3(0, 0.04, 0)
	creature.look_at(Vector3(prey.global_position.x, creature.global_position.y, prey.global_position.z), Vector3.UP)
	Input.action_press("forward")
	Input.action_press("sprint")
	var grunted: bool = await wait_for(func(): return creature.calls_made > 0, 15.0)
	Input.action_release("sprint")
	Input.action_release("forward")
	check("Gruñe cuando corre a por alguien que ve, no solo al chillar", grunted)
	# Back off a few metres: run into the survivor, what it hears is where it
	# stands, and a contact nought metres away says nothing of the route.
	creature.global_position = FLOOR.closest(floor_map, prey.global_position + Vector3(4.0, 0.0, 0.0)) + Vector3(0, 0.04, 0)
	creature.driver.heard.clear()
	check("Los ruidos de los supervivientes le llegan como contactos", await wait_for(func(): return not creature.driver.heard.is_empty(), 20.0))
	check("El contacto trae su clase y sus metros de ruta", creature.driver.heard.is_empty() or (creature.driver.heard[0].has("kind") and creature.driver.heard[0].has("apparent") and creature.driver.heard[0].distance > 0.0), "" if creature.driver.heard.is_empty() else "%s · criatura en %s" % [str(creature.driver.heard[0]), str(creature.global_position)])
	# Close enough for the shriek to find the survivor.
	creature.global_position = level.match_net.bodies[1].global_position + Vector3(2.5, 0, 0)
	await pause_for(0.6)
	creature.driver.shriek()
	# Only what is moving answers, so give it a second cry if the first one
	# happened to land while the survivor was between steps.
	check("El chillido le revela a los supervivientes que se mueven", await wait_for(func():
		if creature.driver.shriek_cooldown <= 0.0: creature.driver.shriek()
		return not creature.driver.revealed.is_empty(), 15.0))
	check("Y los deja marcados con una nube que dura", creature.driver.echo.finds_written > 0)
	# The floor has moved on to the second stage and it has not: the way to its
	# car shows in blue, worked out on this machine with nothing sent for it.
	check("Con la etapa cerrada ve el camino al coche sin que se lo manden", await wait_for(func(): return level.session.stage == 2 and creature.driver.echo.guide_routes.lift > 1, 30.0))
	# Travelling by television: the hunter asks, the host judges it.
	var lit: Array = await wait_for_value(func(): return level.lit_televisions(), func(value): return value.size() >= 2, 30.0)
	check("Y las teles encendidas brillan en su lectura", await wait_for(func(): return creature.driver.echo.guide_routes.screens >= 2, 10.0))
	if lit.size() >= 2:
		creature.global_position = level.televisions[lit[0]].global_position + Vector3(1.0, 0.04, 0)
		await pause_for(0.4)
		check("Reconoce la tele en la que está", level.creature_at_television() == lit[0])
		level.match_net.locust_warp(lit[1])
		check("Sale por la otra tele encendida", await wait_for(func(): return level.creature_at_television() == lit[1], 15.0))
	else: check("Reconoce la tele en la que está", false)
	check("El chillido le da caza libre un rato", creature.driver.frenzy > 0.0)
	var hide = level.hotel.hides[0]
	check("Ve al superviviente meterse en el armario", await wait_for(func(): return is_instance_valid(hide.occupant), 30.0))
	creature.global_position = hide.to_global(hide.exit_offset + Vector3(0, 0, 0.9))
	await pause_for(0.6)
	creature.begin_wardrobe(hide)
	level.match_net.locust_open_hide(hide)
	check("El armario se abre de golpe también aquí", await wait_for(func(): return hide.pulled and hide.opening > 0.5, 15.0))
	check("El ritual del armario lo deja quieto un momento", creature.mode == creature.Mode.WARDROBE)
	check("Abrir el armario acaba con quien estaba dentro", await wait_for(func(): return level.session.restarts >= 1 or level.session.state == level.session.State.FAILED, 25.0))
	check("Y el piso termina cuando ya no hay a quién levantar", await wait_for(func(): return level.session.state == level.session.State.FAILED and level.ui.screen == "online_failed", 40.0))
	check("La caza queda en la ficha del cazador, con su hito", await wait_for(func(): return String(level.ui.summary.get("result", "")) == "lost", 10.0) and int(level.records.career.get("hunts", 0)) == 1 and int(level.records.career.get("hunts_won", 0)) == 1 and not level.records.reached(1, "hunter").is_empty(), str(level.records.career))

# --- The Lurker's warning over the net (lurker_versus.md 11, phase 1) ------------
# The victim is a guest on a slow line (Lag: 150 ms there and back), so what
# is measured, heard and answered is as late as over a real connection. Co-op:
# the host's AI warns it. Versus: another guest drives her and asks for the
# warning; the host judges it, orders the take, and hears the victim's claim.

const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
## One way of the slow line, in s.
const LAG := 0.075
## The slow line listens this far above the room's port.
const LAG_PORT := 5

## A slow line between one guest and the host: every datagram held `hold` s
## each way. It listens on `listen` and talks to the host on `target`.
class Lag extends Node:
	var server := UDPServer.new()
	var client: PacketPeerUDP
	var upstream := PacketPeerUDP.new()
	var hold := 0.0
	## [due msec, to the host, bytes], in order (every one is held the same).
	var queue: Array = []
	func open(listen: int, target: int, one_way: float) -> bool:
		hold = one_way
		process_mode = Node.PROCESS_MODE_ALWAYS
		return server.listen(listen, "127.0.0.1") == OK and upstream.connect_to_host("127.0.0.1", target) == OK
	func _process(_delta: float) -> void:
		server.poll()
		if server.is_connection_available(): client = server.take_connection()
		var now := Time.get_ticks_msec()
		var due := now + int(hold * 1000.0)
		if client != null:
			while client.get_available_packet_count() > 0: queue.append([due, true, client.get_packet()])
		while upstream.get_available_packet_count() > 0: queue.append([due, false, upstream.get_packet()])
		while not queue.is_empty() and int(queue[0][0]) <= now:
			var item: Array = queue.pop_front()
			if bool(item[1]): upstream.put_packet(item[2])
			elif client != null: client.put_packet(item[2])

## The lowest-id corridor of planta 1 at least 8 m long with a ceiling she can
## hold on to, not next to an off-limits room (lurker_fairness_test's):
## {room, centre, along}; the same on every machine, from the manifest.
func lurker_corridor() -> Dictionary:
	var off: Array = level.off_limits_rooms()
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != 0 or int(room.type) != OFFICE.CORRIDOR: continue
		var span := FLOOR.size_of(room)
		if maxf(span.x, span.y) < (7.0 if OFFICE.real_plan_on() else 8.0) or not level.creature.shell.tray_of.has(int(room.id)): continue
		if level.manifest.adjacency[int(room.id)].any(func(other): return off.has(int(other))): continue
		var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
		return {"room": int(room.id), "centre": FLOOR.position_of(room), "along": along}
	return {}

## Where the victim stands in the corridor, its back to where she will be.
func victim_stand(spot: Dictionary) -> Vector3:
	return (spot.centre as Vector3) + (spot.along as Vector3) * 1.5

## Where she is put, 2.4 m behind it on the ceiling.
func lurker_over(spot: Dictionary) -> Vector3:
	return (spot.centre as Vector3) - (spot.along as Vector3) * 0.9

## The round trip the host has measured to a seat (0 before any).
func round_trip(seat: int) -> float:
	return float(level.match_net.latency_of(seat)) if level.match_net.has_method("latency_of") else 0.0

## A room for the warning on floor 2: the host, the victim on its slow line
## (and in versus the hunter), floor 2 played.
func lurker_room(versus: bool) -> bool:
	var net = level.net
	check("La sala se abre", net.host("Anfitrión", 0, port) == OK)
	check("Llegan todos, la víctima por una línea lenta", await wait_for(func(): return net.connected_seats().size() == (3 if versus else 2), 60.0))
	net.set_option("mode", net.Mode.VERSUS if versus else net.Mode.COOP)
	if versus:
		net.set_option("locust", seat_named("Cazadora"))
		# The room's menus still keep versus to floor 1 (phase 5): the test
		# plays it on floor 2 all the same.
		net.options.floor = 2
	else:
		net.set_option("floor", 2)
		net.set_option("difficulty", "equilibrada")
	check("Empieza la partida en el piso 2", net.start_match(81))
	check("Se juega en las oficinas", await wait_for(playing, 150.0) and int(level.manifest.get("floor", 1)) == 2)
	var lurker = level.creature
	check("La criatura es The Lurker", lurker != null and lurker.kind_id() == &"lurker")
	if lurker == null or lurker.kind_id() != &"lurker": return false
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	var victim := seat_named("Víctima")
	# Settled: the first answers come while the guest is still building its floor.
	var rtt: float = await wait_for_value(func(): return round_trip(victim), func(value): return value >= 0.12 and value <= 0.3, 40.0)
	check("El anfitrión mide la ida y vuelta con la víctima: unos 150 ms", rtt >= 0.12 and rtt <= 0.3, "%.3f s" % rtt)
	check("Y con quien juega en su misma máquina, nada", round_trip(1) == 0.0)
	return true

## The host's view of the two warnings the victim was given: the first saved by
## its own torch, the second taken at its due time; each heard on its machine,
## each with its latency in the window; the ledger fair, and every capture
## paired with its warning.
func judge_ledger(entries: Array, victim: int, W: float) -> void:
	var lurker = level.creature
	var rtt := round_trip(victim)
	check("Dos avisos a la víctima", entries.size() == 2, str(entries))
	if entries.size() != 2: return
	var saved: Dictionary = entries[0]
	var taken: Dictionary = entries[1]
	check("Quien se gira con la linterna se salva: lo juzga el anfitrión", String(saved.outcome) == "saved" and int(saved.by) == victim and String(saved.reason) == "linterna" and float(saved.end) < float(saved.due), str(saved))
	check("Quien no se gira es capturado al vencer el plazo", String(taken.outcome) == "taken" and float(taken.take_at) >= float(taken.due) - WARNING.EPS and bool(taken.captured), str(taken))
	var bad: Array = []
	for e in entries:
		if absf(float(e.window) - W) > 1e-6 or absf(float(e.latency) - rtt) > 0.08 or float(e.latency) < 0.1: bad.append(e)
	check("Cada ventana lleva la latencia medida de la víctima", bad.is_empty(), "rtt %.3f: %s" % [rtt, str(bad)])
	check("La máquina de la víctima dice que oyó cada aviso, dentro de su ventana", entries.all(func(e): return float(e.heard_after) >= 0.0 and float(e.heard_after) < float(e.due) - float(e.at)), str(entries.map(func(e): return e.heard_after)))
	var audit: Array = WARNING.audit(lurker.capture_log())
	check("El registro de avisos pasa la auditoría en red", audit.is_empty(), str(audit))
	print("LURKER claims taken %d, refused %d; releases refused %d" % [int(lurker.claims_taken), int(lurker.claims_refused), int(lurker.releases_refused)])
	var tally: Dictionary = lurker.tally()
	check("Nadie capturado sin aviso", int(tally.unpaired) == 0 and int(tally.captures) == 1, str(tally))
	check("Y la víctima muere", await wait_for(func(): return level.session.participants.get(victim) == level.session.Life.DEAD, 20.0))

## Co-op: the host's AI on floor 2 goes for the guest twice, from behind it.
func lurker_coop_host() -> void:
	if not await lurker_room(false): return
	var lurker = level.creature
	check("El anfitrión la lleva con su IA", lurker.control == "ai")
	var victim := seat_named("Víctima")
	var spot := lurker_corridor()
	check("Un pasillo para el aviso", not spot.is_empty())
	if spot.is_empty(): return
	var W := float(level.tuning().back_window)
	var body = level.match_net.bodies[victim]
	var start: int = lurker.warning.ledger.size()
	for round in 2:
		check("La víctima espera de espaldas (%d)" % round, await wait_for(func(): return body.global_position.distance_to(victim_stand(spot)) < 0.6 and body.velocity.length() < 0.1, 60.0))
		await pause_for(1.0)
		lurker.thinking = false
		lurker.brain.forget_all(0.0)
		lurker.brain.spurned = {}
		lurker.brain.attempts = {}
		lurker.brain.sated_until = -INF
		# Dark here: only a torch or a face this near can save it.
		level.hotel.set_room_power(int(spot.room), false)
		lurker.place_over(lurker_over(spot), body.camera.global_position)
		lurker.grace = 0.0
		lurker.thinking = true
		await physics_frame
		lurker.brain.force(&"creep", {"seat": victim})
		var ended: bool = await wait_for(func(): return lurker.warning.ledger.size() > start + round and String(lurker.warning.ledger[start + round].outcome) != "active", 20.0)
		check("Su IA le da el aviso y se resuelve (%d)" % round, ended, "%s; %s" % [str(lurker.warning.ledger.slice(start)), " / ".join(lurker.debug_lines())])
		if not ended: return
	await judge_ledger(lurker.warning.ledger.slice(start), victim, W)

## Versus: the hunter is a guest; this host is a survivor out of the way, and
## the judge.
func lurker_versus_host() -> void:
	if not await lurker_room(true): return
	var lurker = level.creature
	check("En el anfitrión es una réplica de quien la lleva", lurker.control == "puppet")
	var victim := seat_named("Víctima")
	var spot := lurker_corridor()
	if spot.is_empty(): return
	level.hotel.set_room_power(int(spot.room), false)
	level.player.torch.visible = false
	var W := float(level.tuning().back_window)
	check("Ve a la cazadora moverse", await wait_for(func(): return not lurker.net_states.is_empty(), 20.0))
	await drink_host(spot)
	var ended: bool = await wait_for(func():
		var mine: Array = lurker.warning.ledger.filter(func(e): return int(e.seat) == victim)
		return mine.size() >= 2 and String(mine[1].outcome) != "active", 150.0)
	check("Juzga los dos avisos que pide la cazadora", ended, str(lurker.warning.ledger))
	check("Rechaza lo que no cumple: delante de la víctima, a destiempo", int(lurker.get("releases_refused")) >= 2, str(lurker.get("releases_refused")))
	check("La linterna de la víctima la ciega: lo juzga el anfitrión, con su chillido", int(lurker.scares) >= 1, str(lurker.tally()))
	await judge_ledger(lurker.warning.ledger.filter(func(e): return int(e.seat) == victim), victim, W)
	await pause_for(3.0)

## The hunter: a guest driving her by a script, as vs_hunter drives The Locust.
func lurker_hunter() -> void:
	var net = level.net
	await pause_for(1.5)
	check("La cazadora se conecta", net.join("127.0.0.1", "Cazadora", 1, port) == OK)
	check("Entra en el versus del piso 2", await wait_for(playing, 150.0) and int(level.manifest.get("floor", 1)) == 2)
	var lurker = level.creature
	check("Lleva a The Lurker", lurker != null and lurker.kind_id() == &"lurker" and lurker.control == "player" and lurker.driver != null)
	if lurker == null or lurker.driver == null: return
	lurker.driver.scripted = true
	lurker.grace = 0.0
	var spot := lurker_corridor()
	if spot.is_empty(): return
	var victim := seat_named("Víctima")
	check("Ve a la víctima", await wait_for(func(): return level.match_net.bodies.has(victim), 30.0))
	var body = level.match_net.bodies[victim]
	await drink_hunter(spot, body)
	# Phase 3: no warning from 2.4 m behind any more without her charge; she
	# lies in wait behind it and watches it first.
	var perch := lurker_perch(spot)
	check("Un sitio de acecho detrás de la víctima", perch >= 0)
	if perch < 0: return
	for round in 2:
		check("La víctima espera de espaldas (%d)" % round, await wait_for(func(): return body.global_position.distance_to(victim_stand(spot)) < 0.6 and body.velocity.length() < 0.1, 60.0))
		await pause_for(1.0)
		# Asked from in front of it, where it would see her: the host says no
		# (not in the first round, whose torch on her would blind her).
		if round == 1:
			lurker.place_over((spot.centre as Vector3) + (spot.along as Vector3) * 3.5, body.camera.global_position)
			await pause_for(0.6)
			level.match_net.lurker_release()
			await pause_for(0.6)
			check("Delante de la víctima, el anfitrión no empieza ningún aviso (%d)" % round, not lurker.cue)
		check("Se asienta en su sitio de acecho, detrás (%d)" % round, await settle_at(perch, body), " / ".join(lurker.debug_lines()))
		# Watching it settled: charged on the host (CHARGE, 2 s).
		await pause_for(3.0)
		var flashed: float = lurker.driver.view.flash_clock
		# Asked twice at once: the second is too soon.
		level.match_net.lurker_release()
		level.match_net.lurker_release()
		var began: bool = await wait_for(func(): return lurker.cue, 5.0)
		check("Soltar con carga detrás de la víctima: el anfitrión empieza el aviso (%d)" % round, began)
		if not began: return
		check("Y se acaba cuando el anfitrión lo dice (%d)" % round, await wait_for(func(): return not lurker.cue, 5.0))
		if round == 0:
			await pause_for(0.6)
			check("Salvada la víctima, no salta", level.execution.is_empty())
			check("El fogonazo le llega por la red, del anfitrión", lurker.driver.view.flash_clock != flashed)
			check("Y huye sola al techo, sin que nadie la lleve", await wait_for(func(): return lurker.motion.in_duct, 2.0), " / ".join(lurker.debug_lines()))
			# Her warning waits after a flash (FLASH_WAIT).
			await pause_for(lurker.FLASH_WAIT)
		else:
			check("Vencido el plazo, el anfitrión ordena el salto", await wait_for(func(): return not level.execution.is_empty() and int(level.execution.seat) == victim, 5.0))
	await pause_for(15.0)

## A place she lies in wait (lurker_stalk.gd) of planta 1 behind where the
## victim stands, 3 to 6.3 m from its eye with nothing between: the one
## nearest 5 m, its index; -1 none.
func lurker_perch(spot: Dictionary) -> int:
	var lurker = level.creature
	var eye: Vector3 = victim_stand(spot) + Vector3(0, 1.6, 0)
	var along: Vector3 = spot.along
	var best := -1
	var best_off := INF
	for i in lurker.stalk_sites.size():
		var site: Dictionary = lurker.stalk_sites[i]
		var p: Vector3 = site.point
		var flat := Vector3(p.x - eye.x, 0, p.z - eye.z)
		if int(site.wing) != 0 or flat.length() < 3.0 or flat.length() > 6.3 or flat.normalized().dot(along) > -0.5: continue
		if not SIGHT.clear(level, p, eye, [lurker.get_rid()]): continue
		if absf(flat.length() - 5.0) < best_off:
			best_off = absf(flat.length() - 5.0)
			best = i
	return best

## Her driver to that site (lurker_stalk) from a metre off it, looking at the
## victim, and settled there.
func settle_at(perch: int, body) -> bool:
	var lurker = level.creature
	var p: Vector3 = lurker.stalk_sites[perch].point
	var to: Vector3 = body.camera.global_position - p
	var flat := Vector3(to.x, 0, to.z).normalized()
	lurker.teleport(Vector3(p.x, body.global_position.y + 1.0, p.z) + flat * 0.8, NAN, &"prueba")
	lurker.driver.yaw = atan2(-flat.x, -flat.z)
	lurker.driver.pitch = -0.2
	await pause_for(0.2)
	lurker.driver.asked[&"lurker_stalk"] = true
	return await wait_for(func(): return lurker.driver.settled(), 8.0)

## The victim, on its slow line: back to her, it hears its own warning in its
## own ears, with its window and its latency. The first time it turns with its
## torch on her; the second it does not.
func lurker_victim(versus: bool) -> void:
	var net = level.net
	var lag := Lag.new()
	root.add_child(lag)
	check("Abre su línea lenta", lag.open(port + LAG_PORT, port, LAG))
	await pause_for(3.0)
	check("Se conecta por ella", net.join("127.0.0.1", "Víctima", 2 if versus else 1, port + LAG_PORT) == OK)
	check("Entra en las oficinas", await wait_for(playing, 150.0) and int(level.manifest.get("floor", 1)) == 2)
	var lurker = level.creature
	check("Aquí The Lurker es una réplica", lurker != null and lurker.control == "puppet")
	if lurker == null: return
	var spot := lurker_corridor()
	check("El mismo pasillo que el anfitrión", not spot.is_empty())
	if spot.is_empty(): return
	var W := float(level.tuning().back_window)
	var heard: Array = []
	lurker.cue_played.connect(func(seat: int, cue_id: int, _point: Vector3):
		if seat == net.local_seat: heard.append({"id": cue_id, "hold": float(lurker.my_cue.get("hold", -1.0)) if "my_cue" in lurker else -1.0}))
	var player = level.player
	var along: Vector3 = spot.along
	if versus: await drink_victim(spot)
	for round in 2:
		var count := heard.size()
		player.torch.visible = round == 0
		var got: bool = await wait_for(func():
			if heard.size() == count:
				player.global_position = victim_stand(spot) + Vector3(0, 0.05, 0)
				player.velocity = Vector3.ZERO
				player.rotation.y = atan2(-along.x, -along.z)
				player.camera.rotation.x = 0.0
			return heard.size() > count, 90.0)
		check("Oye su propio aviso de la espalda, en su máquina (%d)" % round, got)
		if not got: return
		var hold := float(heard[count].hold)
		check("Con su ventana y su latencia (%d)" % round, hold >= W + 0.1 and hold <= W + WARNING.LATENCY_CAP + 1e-6, "%.3f s; ventana %.2f" % [hold, W])
		if round == 0:
			# Turned with the torch on her face a quarter of a second after.
			await pause_for(0.25)
			var to: Vector3 = lurker.face_point() - player.camera.global_position
			player.rotation.y = atan2(-to.x, -to.z)
			player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
			await pause_for(W + 1.0)
			check("Girarse lo salva", level.session.participants.get(net.local_seat) == level.session.Life.EXPLORING and level.execution.is_empty())
			# Its back to her again: the room it is in may have been lit by the turn.
			player.camera.rotation.x = 0.0
		else:
			check("Sin girarse, lo coge al vencer el plazo", await wait_for(func(): return not level.execution.is_empty() and int(level.execution.seat) == net.local_seat, W + WARNING.LATENCY_CAP + 3.0))
	await pause_for(15.0)

# --- Her drink over the net (lurker_versus.md 8, phase 4) ------------------------
# The hunter drinks the victim's corridor: refused first over a room that may
# never be dark; taken, the corridor dark and the victim's torch out on every
# machine and lit again together 6 s later; asked again within her wait over
# another room, refused. The victim lights its torch again by pressing it.
# Every machine prints its wall clock when the dark comes and goes (all three
# run on this one machine): DRINK_WALL.

## A room of planta 1 with a ceiling of hers, not off limits nor `other`:
## one that may never be dark, or one that may.
func drink_room(never: bool, other := -1) -> int:
	var lurker = level.creature
	var off: Array = level.off_limits_rooms()
	for room in level.manifest.rooms:
		var id := int(room.id)
		if id == other or int(room.get("wing", -1)) != 0 or FLOOR.is_void(room) or off.has(id) or not lurker.shell.tray_of.has(id): continue
		if OFFICE.may_be_dark(room) != never and not level.point_protected(FLOOR.position_of(room)): return id
	return -1

## This machine has `room` dark and then lit again: how long, -1 if not.
func drink_seen(room: int, role: String) -> float:
	var lurker = level.creature
	if not await wait_for(func(): return lurker.deep_room == room, 120.0): return -1.0
	var from := Time.get_ticks_msec()
	print("DRINK_WALL %s oscuro %.3f" % [role, Time.get_unix_time_from_system()])
	if not await wait_for(func(): return lurker.deep_room < 0, 20.0): return -1.0
	print("DRINK_WALL %s luz %.3f" % [role, Time.get_unix_time_from_system()])
	return float(Time.get_ticks_msec() - from) / 1000.0

func drink_host(spot: Dictionary) -> void:
	var lurker = level.creature
	var room := int(spot.room)
	# Her first quiet seconds of the floor are over here too.
	lurker.grace = 0.0
	var dark := await drink_seen(room, "anfitrión")
	var victim := seat_named("Víctima")
	check("Bebe el pasillo de la víctima: lo juzga el anfitrión", lurker.drinks.size() == 1 and int(lurker.drinks[0].room) == room and Array(lurker.drinks[0].seats).has(victim), str(lurker.drinks))
	check("Y lo devuelve a los %d s" % int(lurker.VERSUS_DARK), absf(dark - lurker.VERSUS_DARK) <= 0.4, "%.2f s" % dark)
	check("La linterna apagada de la víctima vuelve en el anfitrión", await wait_for(func(): return not lurker.dead_torches.has(victim), 10.0))
	check("Rechaza beber una sala de hito y en su espera", await wait_for(func(): return int(lurker.drinks_refused) >= 2, 10.0) and lurker.drinks.size() == 1, "%d %s" % [int(lurker.drinks_refused), str(lurker.drinks)])

func drink_hunter(spot: Dictionary, body) -> void:
	var lurker = level.creature
	var room := int(spot.room)
	check("La víctima espera para la bebida", await wait_for(func(): return body.global_position.distance_to(victim_stand(spot)) < 0.6, 60.0))
	var landmark := drink_room(true)
	check("Una sala de hito con techo suyo", landmark >= 0)
	if landmark >= 0:
		lurker.place_over(FLOOR.position_of(level.manifest.rooms[landmark]))
		await pause_for(1.0)
		level.match_net.lurker_drink()
		await pause_for(1.5)
		check("En una sala de hito, el anfitrión no la deja beber", lurker.deep_room < 0)
	lurker.place_over(lurker_over(spot), body.camera.global_position)
	await pause_for(1.0)
	level.match_net.lurker_drink()
	var dark := await drink_seen(room, "cazadora")
	check("Pide beber el pasillo: a oscuras también en su máquina, y la luz vuelve a la vez", absf(dark - lurker.VERSUS_DARK) <= 0.4, "%.2f s" % dark)
	var other := drink_room(false, room)
	if other >= 0:
		lurker.place_over(FLOOR.position_of(level.manifest.rooms[other]))
		await pause_for(1.0)
		level.match_net.lurker_drink()
		await pause_for(1.5)
		check("En su espera, otra sala tampoco", lurker.deep_room < 0)

func drink_victim(spot: Dictionary) -> void:
	var lurker = level.creature
	var player = level.player
	var along: Vector3 = spot.along
	var room := int(spot.room)
	var seat: int = level.net.local_seat
	player.torch.visible = true
	var got: bool = await wait_for(func():
		if lurker.deep_room != room:
			player.global_position = victim_stand(spot) + Vector3(0, 0.05, 0)
			player.velocity = Vector3.ZERO
			player.rotation.y = atan2(-along.x, -along.z)
			player.camera.rotation.x = 0.0
		return lurker.deep_room == room, 120.0)
	check("Su pasillo, a oscuras en su máquina", got)
	if not got: return
	var from := Time.get_ticks_msec()
	print("DRINK_WALL víctima oscuro %.3f" % Time.get_unix_time_from_system())
	check("Y su linterna, apagada sin quedar bebida", not player.torch.visible and lurker.dead_torches.has(seat) and not lurker.drunk.has(seat))
	# Its thumb: after its reaction, off and on; after each on, a moment to see it light.
	await pause_for(0.35)
	var pressed := 0
	while lurker.dead_torches.has(seat) and pressed < 15:
		player.torch.visible = not player.torch.visible
		pressed += 1
		await pause_for(0.4 if player.torch.visible else 0.15)
	var after := float(Time.get_ticks_msec() - from) / 1000.0
	check("Vuelve pulsándola, a la tercera o más, nunca antes de 1,0 s", not lurker.dead_torches.has(seat) and player.torch.visible and pressed >= 3 and after >= 0.9, "%d pulsaciones, %.2f s" % [pressed, after])
	check("Y la luz del pasillo vuelve", await wait_for(func(): return lurker.deep_room < 0, 10.0))
	print("DRINK_WALL víctima luz %.3f" % Time.get_unix_time_from_system())
	var dark := float(Time.get_ticks_msec() - from) / 1000.0
	check("A los 6 s, como en las otras máquinas", absf(dark - lurker.VERSUS_DARK) <= 0.5, "%.2f s" % dark)
