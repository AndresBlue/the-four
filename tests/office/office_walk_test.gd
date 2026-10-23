extends SceneTree
## Floor 2 played from its first stage to its end (spec_f1_systems 2 and 4):
## on level 1 the request typed, the card taken from its station and through
## the reader; on level 2 the board, a minutero and the red lever's clock; the
## freight lift down each time; and on the third the post opened with the
## card, the fans started and stopped, the hatch, the climb into the main duct
## and back, the crouched body passing all of it, and the shaft's
## ladder ending the floor.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const MAIN_DUCT := preload("res://game/world/office/main_duct_geometry.gd")
## A floor whose plant ladder stands in the air salon's way (33) and one whose
## duct ends over a corridor (7).
const SEEDS := [7, 33]
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	var began := Time.get_ticks_msec()
	for seed_asked in SEEDS: await walk(int(seed_asked))
	var seconds := float(Time.get_ticks_msec() - began) / 1000.0
	print("OFFICE_WALK_RESULT ", checks.size() - failed, "/", checks.size(), " in %.1f s" % seconds)
	quit(1 if failed > 0 else 0)

## One floor, in a level of its own: one already playing does not build again.
func walk(seed_asked: int) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await frames(2)
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(seed_asked, false, [1], "", 2)
	var session = level.session
	var tag := "semilla %d" % seed_asked
	check("%s: se monta la semilla pedida" % tag, int(level.manifest.seed) == seed_asked and int(level.manifest.get("floor", 1)) == 2, str(level.manifest.seed))
	level.player.set_physics_process(false)
	await the_card(tag)
	# Each level, into the car and the button; level 2 asks for the power
	# first (the_power), once its car is reached.
	var powered := false
	var left := 60.0
	while left > 0.0 and not (session.stage == 3 and session.state == session.State.PLAYING and level.lifts.boarding.is_empty()):
		if session.stage == 2 and not powered and level.lifts.boarding.is_empty() and session.state == session.State.PLAYING and not level.lifts.riding.has(level.player.slot):
			powered = true
			await the_power(tag)
		if level.lifts.boarding.is_empty() and session.state == session.State.PLAYING:
			var car: Vector3 = level.hotel.lifts[session.stage - 1]
			if session.goal.get("ready", false) and car != Vector3.ZERO:
				level.player.global_position = car + Vector3(0, 0.04, 0)
				level.match_net.call_lift(session.stage - 1)
			else:
				level.player.global_position = FLOOR.position_of(level.manifest.rooms[level.refuge_room()]) + Vector3(0, 0.04, 0)
			level.player.velocity = Vector3.ZERO
		await physics_frame
		left -= 1.0 / 60.0
	check("%s: del nivel 1 al 3 por el montacargas" % tag, session.stage == 3 and session.state == session.State.PLAYING, "nivel %d, estado %d" % [session.stage, session.state])
	if session.stage != 3: return
	# Off the ride: nothing is worked while it still counts (lifts.riding).
	for i in 600:
		await physics_frame
		if not level.lifts.riding.has(level.player.slot): break
	var m: Dictionary = level.manifest
	var air = level.objective(&"air")
	var player = level.player
	check("%s: el nivel 3 pide el aire" % tag, String(session.goal.get("kind", "")) == "air")
	var memo = air.usables.back()
	check("%s: en la seguridad, las instrucciones" % tag, String(memo.action) == "read" and String(air.paper_of(memo.index).form.subject) == "VENTILACIÓN")
	# The post: its door locked until the card from level 1 goes through.
	check("%s: la puerta de la seguridad, cerrada con llave" % tag, air.post_door != null and air.post_door.locked)
	player.global_position = air.usables[3].stand + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: en el lector de la seguridad, PASAR FICHA" % tag, air.word_of(air.usables[3], player.slot) == "PASAR FICHA")
	level.match_net.use_office(&"air", "post", 3)
	check("%s: con la ficha se abre la seguridad" % tag, air.post_open and not air.post_door.locked and air.post_door.opened)
	player.global_position = air.usables[4].stand + Vector3(0, 0.04, 0)
	await frames(3)
	level.match_net.use_office(&"air", "start", 4)
	await frames(30)
	check("%s: la consola enciende los ventiladores con una carga" % tag, air.running() and air.released and air.charges == 1 and air.spin > 0.0)
	for i in 200:
		await physics_frame
		if air.spin >= 1.0: break
	var below: Vector3 = player.global_position
	check("%s: en marcha tapan el sonido de la planta 3 y no el de la 2" % tag, is_equal_approx(level.sound_mask(below), air.AIR_MASK) and level.sound_mask(below + Vector3(0, 6, 0)) == 0.0 and air.ducts_closed() and level.world_audio.mask_db(below) < -8.0)
	player.global_position = MAIN_DUCT.foot(m).origin + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: con los ventiladores en marcha la compuerta no se abre" % tag, air.word_of(air.usables[0], player.slot) == "")
	player.global_position = air.usables[5].stand + Vector3(0, 0.04, 0)
	await frames(3)
	level.match_net.use_office(&"air", "stop", 5)
	for i in 300:
		await physics_frame
		if air.spin == 0.0: break
	check("%s: parados, se quedan quietos" % tag, not air.running() and air.spin == 0.0)
	player.global_position = MAIN_DUCT.foot(m).origin + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: al pie de la escalerilla, ABRIR" % tag, air.word_of(air.usables[0], player.slot) == "ABRIR")
	level.match_net.use_office(&"air", "hatch", 0)
	check("%s: la compuerta se abre y da paso" % tag, air.hatch_open and air.word_of(air.usables[0], player.slot) == "ENTRAR")
	player.set_physics_process(true)
	level.match_net.use_office(&"air", "climb", 0)
	await settle(player)
	check("%s: sube al ducto, a gatas" % tag, level.crawling_at(player.global_position) and player.crouched and is_equal_approx(player.eye_height, player.CRAWL_EYE), str(player.global_position))
	check("%s: dentro del ducto no hay luz, y nada de la sala de abajo lo alumbra" % tag, not level.sanity.lit_at(player.global_position) and level.hotel.body_bit(player.global_position) == -1)
	check("%s: en la boca, BAJAR" % tag, air.word_of(air.usables[1], player.slot) == "BAJAR")
	level.match_net.use_office(&"air", "climb", 1)
	await settle(player)
	check("%s: y vuelve a bajar a la sala" % tag, not level.crawling_at(player.global_position) and player.global_position.distance_to(MAIN_DUCT.foot(m).origin) < 0.3, str(player.global_position))
	# The crouched capsule along the whole duct, node to node, to the landing.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.05
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var y := MAIN_DUCT.floor_y(m) + 0.57
	var line: Array = [MAIN_DUCT.mouth(m).origin]
	for n in m.air.main.nodes.slice(1):
		var node: Array = m.ducts.nodes[int(n)]
		line.append(Vector3(float(node[0]), 0, float(node[2])))
	var r: Array = m.air.shaft.rect
	line.append(Vector3(float(r[0]), 0, float(r[1])))
	var blocked: Array = []
	for i in range(1, line.size()):
		var a: Vector3 = line[i - 1]
		var b: Vector3 = line[i]
		a.y = y
		b.y = y
		query.transform = Transform3D(Basis.IDENTITY, a)
		query.motion = b - a
		if space.cast_motion(query)[0] < 0.999: blocked.append(i)
	check("%s: agachado se pasa todo el ducto hasta el pozo" % tag, blocked.is_empty(), "tramos %s" % str(blocked))
	# The landing and the ladder down: the floor is over.
	player.global_position = Vector3(float(r[0]), MAIN_DUCT.floor_y(m) + 0.05, float(r[1]))
	player.velocity = Vector3.ZERO
	await frames(20)
	check("%s: en el pozo, BAJAR" % tag, MAIN_DUCT.on_landing(m, player.global_position) and air.word_of(air.usables[2], player.slot) == "BAJAR")
	level.match_net.use_office(&"air", "ladder", 2)
	for i in 900:
		await physics_frame
		if session.state == session.State.WON: break
	check("%s: la escalerilla del pozo acaba el piso" % tag, session.state == session.State.WON, "estado %d" % session.state)

## Level 1: the request typed at the window, the card taken from its
## station's tray once the capsule is in, and through the reader.
func the_card(tag: String) -> void:
	var files = level.objective(&"files")
	var player = level.player
	var session = level.session
	await frames(3)
	check("%s: el nivel 1 pide la ficha" % tag, files != null and String(session.goal.get("kind", "")) == "files" and files.usables.size() >= 3)
	if files == null or files.usables.size() < 3: return
	player.global_position = files.usables[0].stand + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: en la ventanilla, ESCRIBIR" % tag, files.word_of(files.usables[0], player.slot) == "ESCRIBIR")
	level.match_net.use_office(&"files", "type", 0)
	var request: Dictionary = files.requests.get(player.slot, {})
	check("%s: la petición sale hacia una estación" % tag, not request.is_empty() and int(request.state) == files.Card.TRAVELLING)
	if request.is_empty(): return
	# A photo (headless takes none: a grey one stands in) goes out as a JPEG
	# and comes back from one.
	var grey := Image.create(240, 304, false, Image.FORMAT_RGB8)
	grey.fill(Color(0.4, 0.4, 0.4))
	files.textures[player.slot] = ImageTexture.create_from_image(grey)
	files.send_photo(player.slot)
	var bytes: PackedByteArray = files.photos.get(player.slot, PackedByteArray())
	files.textures.clear()
	files.keep_photo(player.slot, bytes)
	check("%s: la foto de la ficha viaja como JPEG y vuelve" % tag, bytes.size() > 2 and bytes.size() <= files.PHOTO_MAX_BYTES and bytes[0] == 0xFF and files.textures.has(player.slot))
	var receipt: Dictionary = files.receipt(player.slot)
	check("%s: se sostiene el resguardo con su estación" % tag, level.interaction.reading_hint == files.PAPER_BASE + player.slot * 10 and String(receipt.form.station) == str(int(files.station_exits[int(request.station)].number)))
	level.interaction.close_document()
	var station: int = int(request.station) + 1
	var waited := 0
	while int(files.requests[player.slot].state) != files.Card.IN_TRAY and waited < 60 * 60:
		await physics_frame
		waited += 1
	check("%s: la cápsula llega a la bandeja (%.0f s de tubo)" % [tag, float(files.station_exits[station - 1].tube) / files.CAPSULE_SPEED], int(files.requests[player.slot].state) == files.Card.IN_TRAY and files.lamps[station - 1].visible)
	player.global_position = files.usables[station].stand + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: en su estación, RECOGER" % tag, files.word_of(files.usables[station], player.slot) == "RECOGER")
	level.match_net.use_office(&"files", "take", station)
	check("%s: la ficha en la mano, y a la vista" % tag, files.has_card(player.slot) and not files.lamps[station - 1].visible and level.interaction.reading_hint == files.PAPER_BASE + player.slot * 10 + 1)
	level.interaction.close_document()
	# Fallen with it in hand, it lies there; picked up, it is in hand again.
	level.objectives_on_death(player.slot, player.global_position)
	check("%s: quien cae suelta su ficha donde estaba" % tag, int(files.requests[player.slot].state) == files.Card.DROPPED and files.pickups.has(player.slot))
	check("%s: en el suelo, COGER" % tag, files.word_of(files.pickups[player.slot], player.slot) == "COGER")
	level.match_net.use_office(&"files", "pick", player.slot)
	check("%s: y se recoge" % tag, files.has_card(player.slot) and not files.pickups.has(player.slot))
	level.interaction.close_document()
	var kinds: Array = level.own_papers().map(func(paper): return String(paper.kind))
	check("%s: TUS NOTAS guarda el resguardo y la ficha" % tag, kinds.has("resguardo") and kinds.has("ficha"), str(kinds))
	var reader: int = files.reader_index()
	player.global_position = files.usables[reader].stand + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: en el lector, PASAR FICHA" % tag, files.word_of(files.usables[reader], player.slot) == "PASAR FICHA")
	level.match_net.use_office(&"files", "swipe", reader)
	await frames(10)
	# What a guest catching up, or Continuar, would be given, given back to a
	# handler forgetting it: it stands as it was.
	var kept: Dictionary = level.objective_snapshots()
	files.reset()
	level.catch_up_progress({"objectives": kept, "stage": session.stage})
	check("%s: la ficha vuelve con la instantánea del piso" % tag, kept.has("files") and not kept.has("televisions") and files.swiped.has(player.slot) and files.has_card(player.slot))
	check("%s: con la cuota pasada, el nivel 1 se cumple y su puerta se abre" % tag, bool(session.goal.get("ready", false)) and not level.hotel.gates[0].locked)

## Level 2: a zone's lever up lights its rooms, one over the budget trips
## the oldest, a minutero lights its corridor, and the red lever cuts the
## planta and runs the freight lift's clock, which holds the car until it is
## out.
func the_power(tag: String) -> void:
	var power = level.objective(&"power")
	var player = level.player
	var session = level.session
	check("%s: el nivel 2 pide la corriente" % tag, power != null and String(session.goal.get("kind", "")) == "power" and power.zones.size() >= 2)
	if power == null or power.zones.size() < 2: return
	var legend = power.usables.back()
	check("%s: junto al cuadro, un memorándum que se lee" % tag, String(legend.action) == "read" and power.word_of(legend, level.player.slot) == "LEER" and power.paper_of(legend.index).form.lines.size() == power.zones.size() + 3)
	power.lift_timer = 3.0
	var room_of = func(z: int) -> int:
		for id in power.zones[z].rooms:
			if not power.lit_always.has(int(id)) and not level.hotel.dark_ids.has(int(id)): return int(id)
		return -1
	var first: int = room_of.call(0)
	check("%s: con todo abajo, la planta 2 a oscuras" % tag, first >= 0 and not level.hotel.lit(first))
	player.global_position = power.usables[0].stand + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: en el cuadro, SUBIR" % tag, power.word_of(power.usables[0], player.slot) == "SUBIR")
	level.match_net.use_office(&"power", "lever", 0)
	check("%s: la zona subida se enciende" % tag, power.on_order == [0] and level.hotel.lit(first))
	power.budget = 1
	player.global_position = power.usables[1].stand + Vector3(0, 0.04, 0)
	await frames(2)
	level.match_net.use_office(&"power", "lever", 1)
	check("%s: pasado el presupuesto cae la más antigua" % tag, power.on_order == [1] and not level.hotel.lit(first))
	var timer: int = power.red_index() + 1
	if timer < power.usables.size():
		player.global_position = power.usables[timer].stand + Vector3(0, 0.04, 0)
		await frames(2)
		level.match_net.use_office(&"power", "switch", timer)
		var lit_corridor: bool = level.manifest.power.timers[0].rooms.all(func(id): return power.powered(int(id)))
		check("%s: el minutero enciende su pasillo" % tag, lit_corridor)
	var red: int = power.red_index()
	player.global_position = power.usables[red].stand + Vector3(0, 0.04, 0)
	await frames(2)
	level.match_net.use_office(&"power", "red", red)
	check("%s: la roja corta la planta y corre el reloj" % tag, power.red == power.Red.RUNNING and power.on_order.is_empty())
	check("%s: el montacargas no baja con el reloj corriendo" % tag, not level.ride_allowed(1, [player]))
	for i in 600:
		await physics_frame
		if power.red == power.Red.ARMED: break
	check("%s: acabado el reloj, el nivel 2 se cumple" % tag, power.red == power.Red.ARMED and bool(session.goal.get("ready", false)) and level.ride_allowed(1, [player]))

## Until the body's climb (its transit) is over, and a moment more.
func settle(player) -> void:
	for i in 300:
		await physics_frame
		if player.transit.is_empty(): break
	await frames(10)
