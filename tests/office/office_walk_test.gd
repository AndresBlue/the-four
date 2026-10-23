extends SceneTree
## Floor 2 played from its first stage to its end (spec_f1_systems 2 and 4):
## on level 1 the request typed, the card taken from its station and through
## the reader; level 2 met in its refuge (its power is not built yet); the
## freight lift down each time; and on the third the hatch, the climb into the
## main duct and back, the crouched body passing all of it, and the shaft's
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
	# Level 2: into the refuge; each level, then into the car and the button.
	var left := 60.0
	while left > 0.0 and not (session.stage == 3 and session.state == session.State.PLAYING and level.lifts.boarding.is_empty()):
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
	player.global_position = MAIN_DUCT.foot(m).origin + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: al pie de la escalerilla, ABRIR" % tag, air.word_of(air.usables[0], player.slot) == "ABRIR")
	level.match_net.use_office(&"air", "hatch", 0)
	check("%s: la compuerta se abre y da paso" % tag, air.hatch_open and air.word_of(air.usables[0], player.slot) == "ENTRAR")
	player.set_physics_process(true)
	level.match_net.use_office(&"air", "climb", 0)
	await settle(player)
	check("%s: sube al ducto, a gatas" % tag, level.crawling_at(player.global_position) and player.crouched and is_equal_approx(player.eye_height, player.CRAWL_EYE), str(player.global_position))
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
	check("%s: la ficha en la mano" % tag, files.has_card(player.slot) and not files.lamps[station - 1].visible)
	var reader: int = files.reader_index()
	player.global_position = files.usables[reader].stand + Vector3(0, 0.04, 0)
	await frames(3)
	check("%s: en el lector, PASAR FICHA" % tag, files.word_of(files.usables[reader], player.slot) == "PASAR FICHA")
	level.match_net.use_office(&"files", "swipe", reader)
	await frames(10)
	check("%s: con la cuota pasada, el nivel 1 se cumple y su puerta se abre" % tag, bool(session.goal.get("ready", false)) and not level.hotel.gates[0].locked)

## Until the body's climb (its transit) is over, and a moment more.
func settle(player) -> void:
	for i in 300:
		await physics_frame
		if player.transit.is_empty(): break
	await frames(10)
