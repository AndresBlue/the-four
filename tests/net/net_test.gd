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
	check("Salen del piso al cerrar la última etapa", won and level.session.stage == level.session.STAGES)
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
	check("Y contra la criatura de la dificultad que eligió", level.difficulty == "equilibrada" and is_equal_approx(level.locust.chase_speed, float(preload("res://game/floors/difficulty.gd").PROFILES.equilibrada.chase_speed)) and level.locust.chase_speed < 6.0)
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
	check("Muere y observa a un compañero vivo desde detrás", await wait_for(func(): return not level.local_alive() and not level.player.active and match_net.watched_body() != null and is_instance_valid(level.watch_camera) and level.watch_camera.current, 60.0))
	check("La cámara de observación no atraviesa paredes", level.watch_camera.global_position.distance_to(match_net.watched_body().global_position) < 3.2)
	# The stage is given back and this body has to come back whole. Its own
	# camera, its own body, and the torch in the hand: the torch trails the
	# camera instead of hanging from it, and it is hidden along with the body,
	# so what it looks like from inside is a light that everybody else can see
	# and its owner cannot. The word arrives before the replicated session
	# says so, which is the half second this used to be lost in.
	level.player.torch.visible = true
	var raised: bool = await wait_for(func(): return level.local_alive() and level.player.visible and level.player.camera.current and not is_instance_valid(level.watch_rig), 30.0)
	check("Al devolver la etapa recupera su cuerpo y su cámara", raised)
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
