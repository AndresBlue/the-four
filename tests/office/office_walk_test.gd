extends SceneTree
## Floor 2 played from its first stage to its end (spec_f1_systems 2 and 4):
## on level 1 the request typed, the card taken from its station and through
## the reader; on level 2 the board, a minutero and the maneuver room; the
## freight lift down each time; and on the third the post opened with the
## card, its console's cameras, lights and the air room's lock, the hatch, the climb into the main duct
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
	# The floor walked by hand, without her (phase 1's).
	level.creature_scene = "none"
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
	check("%s: en la seguridad, las instrucciones" % tag, String(memo.action) == "read" and String(air.paper_of(memo.index).form.subject) == "VIGILANCIA")
	# The post: its door locked until the card from level 1 goes through.
	check("%s: la puerta de la seguridad, cerrada con llave" % tag, air.post_door != null and air.post_door.locked)
	player.global_position = air.usables[3].stand + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: en el lector de la seguridad, PASAR FICHA" % tag, air.word_of(air.usables[3], player.slot) == "PASAR FICHA")
	level.match_net.use_office(&"air", "post", 3)
	check("%s: con la ficha se abre la seguridad" % tag, air.post_open and not air.post_door.locked and air.post_door.opened)
	# The cameras' eight rooms, each shut and locked; the air room one of them.
	var vent: int = air.vent_cam()
	check("%s: ocho salas con cierre eléctrico, la de ventilación entre ellas, todas cerradas" % tag, air.unlocked.size() == 8 and vent >= 0 and air.cam_doors.all(func(nodes): return not nodes.is_empty() and nodes.all(func(door): return door.locked and not door.opened)))
	player.global_position = MAIN_DUCT.foot(m).origin + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: con la sala de ventilación cerrada la compuerta no se abre" % tag, air.word_of(air.usables[0], player.slot) == "")
	player.global_position = air.usables[4].stand + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: en la consola, SENTARSE" % tag, air.word_of(air.usables[4], player.slot) == "SENTARSE")
	level.match_net.use_office(&"air", "sit", 4)
	await frames(3)
	check("%s: sentado, las cámaras en pantalla y el cuerpo quieto" % tag, air.operator == player.slot and air.console != null and player.reading and level.cams_eye != Vector3.INF)
	air.console.show_cam(vent)
	var cam: Dictionary = m.air.cams[vent]
	check("%s: la cámara de la sala de ventilación mira desde su esquina" % tag, level.cams_eye.distance_to(Vector3(float(cam.point[0]), float(cam.point[1]), float(cam.point[2]))) < 0.01)
	# The lights: four at once, a fifth refused; each a room lit.
	var lit: Array = []
	for room in m.rooms:
		if lit.size() >= air.LIGHTS_MOST + 1: break
		if air.lightable(int(room.id)) and not bool(room.get("corridor", false)): lit.append(int(room.id))
	for id in lit: level.match_net.use_office(&"air", "light", int(id))
	await frames(2)
	check("%s: cuatro luces a la vez y la quinta no" % tag, air.lights.size() == air.LIGHTS_MOST and lit.slice(0, air.LIGHTS_MOST).all(func(id): return level.hotel.lit(int(id))) and not level.hotel.lit(int(lit[-1])))
	air.lights[int(lit[0])] = float(session.elapsed) - air.DECOY_TIME - 1.0
	await frames(3)
	check("%s: una luz se apaga sola pasado su tiempo" % tag, not air.lights.has(int(lit[0])) and not level.hotel.lit(int(lit[0])) and air.lights.size() == air.LIGHTS_MOST - 1)
	level.match_net.use_office(&"air", "lock", vent)
	await frames(2)
	check("%s: desde la consola se abre el cierre de la sala de ventilación" % tag, air.vent_open() and air.cam_doors[vent].all(func(door): return not door.locked))
	level.match_net.use_office(&"air", "stand", 4)
	await frames(3)
	check("%s: al levantarse, las cámaras se van" % tag, air.operator == -1 and air.console == null and not player.reading and level.cams_eye == Vector3.INF)
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

## Level 2: a zone's lever up lights its rooms, a fourth up trips them all, a
## minutero lights its corridor; the maneuver room's door stays shut without
## its sector's power and opens on its motor with it, and the lever inside
## frees the freight lift, which holds the car until then.
func the_power(tag: String) -> void:
	var power = level.objective(&"power")
	var player = level.player
	var session = level.session
	check("%s: el nivel 2 pide la corriente" % tag, power != null and String(session.goal.get("kind", "")) == "power" and power.zones.size() > power.BACKUP)
	if power == null or power.zones.size() <= power.BACKUP: return
	var legend = power.usables.back()
	check("%s: junto al cuadro, un memorándum que se lee" % tag, String(legend.action) == "read" and power.word_of(legend, level.player.slot) == "LEER" and power.paper_of(legend.index).form.lines.size() == power.zones.size() + 3)
	var room_of = func(z: int) -> int:
		for id in power.zones[z].rooms:
			if not power.lit_always.has(int(id)) and not level.hotel.dark_ids.has(int(id)): return int(id)
		return -1
	var first: int = room_of.call(0)
	check("%s: con todo abajo, la planta 2 a oscuras" % tag, first >= 0 and not level.hotel.lit(first))
	var use := func(action: String, index: int) -> void:
		player.global_position = power.usables[index].stand + Vector3(0, 0.04, 0)
		await frames(2)
		level.match_net.use_office(&"power", action, index)
	player.global_position = power.usables[0].stand + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: en el cuadro, SUBIR" % tag, power.word_of(power.usables[0], player.slot) == "SUBIR")
	level.match_net.use_office(&"power", "lever", 0)
	check("%s: la zona subida se enciende" % tag, power.on_order == [0] and level.hotel.lit(first))
	for z in range(1, power.BACKUP): await use.call("lever", z)
	check("%s: tres arriba aguantan, con sus tres pilotos" % tag, power.on_order.size() == power.BACKUP and power.backup_lenses.all(func(pair): return pair[0].visible))
	await use.call("lever", power.BACKUP)
	check("%s: con una cuarta saltan todas" % tag, power.on_order.is_empty() and not level.hotel.lit(first) and power.backup_lenses.all(func(pair): return not pair[0].visible))
	if not power.switch_until.is_empty():
		await use.call("switch", power.zones.size())
		var lit_corridor: bool = level.manifest.power.timers[0].rooms.all(func(id): return power.powered(int(id)))
		check("%s: el minutero enciende su pasillo" % tag, lit_corridor)
	await use.call("door", power.door_index())
	# Aimed high or low at the leaf from where it is pressed, the focus is the
	# motor's button, never the locked leaf.
	var aims: Array = []
	for height: float in [0.5, 1.2, 2.1]:
		var eye: Vector3 = player.camera.global_position
		var at: Vector3 = power.motor_door.doorway + Vector3(0, height, 0)
		var flat := Vector2(at.x - eye.x, at.z - eye.z)
		player.rotation.y = atan2(-flat.x, -flat.y)
		player.camera.rotation.x = atan2(at.y - eye.y, flat.length())
		await frames(2)
		aims.append(level.interaction.focused_area() == power.usables[power.door_index()])
	check("%s: apuntando a cualquier altura de la puerta se enfoca su botón" % tag, aims.all(func(ok): return ok), str(aims))
	check("%s: sin corriente la puerta de la sala de maniobra no se abre" % tag, not power.motor_started and not power.motor_door.opened and power.door_pilot[0].visible)
	await use.call("lever", power.zone_of(power.maneuver_room))
	check("%s: con su sector arriba, el piloto de la puerta en verde" % tag, power.door_powered() and power.door_pilot[1].visible and not power.door_pilot[0].visible)
	await use.call("door", power.door_index())
	check("%s: la puerta se abre sola, despacio, y el montacargas aún no baja" % tag, power.motor_started and power.motor_door.moving and not level.ride_allowed(1, [player]))
	for i in 600:
		await physics_frame
		if power.motor_door.opened: break
	check("%s: la puerta acaba abierta y nadie la cierra" % tag, power.motor_door.opened and power.motor_door.locked and not power.motor_door.toggle())
	await use.call("lift", power.lift_index())
	await frames(3)
	check("%s: la palanca de dentro suelta el montacargas y el nivel 2 se cumple" % tag, power.freed and bool(session.goal.get("ready", false)) and level.ride_allowed(1, [player]), "suelto %s, meta %s, viaje %s, palabra «%s», a %.2f m" % [str(power.freed), str(session.goal.get("ready", false)), str(level.ride_allowed(1, [player])), power.word_of(power.usables[power.lift_index()], player.slot), player.global_position.distance_to(power.usables[power.lift_index()].global_position)])

## Until the body's climb (its transit) is over, and a moment more.
func settle(player) -> void:
	for i in 300:
		await physics_frame
		if player.transit.is_empty(): break
	await frames(10)
