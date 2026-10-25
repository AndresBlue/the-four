extends SceneTree
## The Lurker's senses (game/enemies/lurker/lurker_senses.gd, spec_f2_mind
## 10.1) on a built floor 2: she sees in the dark far and into the light
## little, a torch on her face blinds her, walls hide; she hears through the
## room and through her ducts, never from another planta, and hears a torch
## clicked; she drinks the light of the lamps near her, all together, never
## past dark for the rules, and gives it back; she picks her prey herself; the
## director gives her zones, never people; the words the rest of the game
## reads of her; and what the floor's systems tell her: her room lit, the fans
## stopping, the main duct's crossing while somebody crawls before it, whom
## she leaves be kept across a save.
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SENSES := preload("res://game/enemies/lurker/lurker_senses.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
const SEEDS := [2026, 7, 11, 23]
var checks: Array = []
var failed := 0
var level
var lurker
var corridor := {}

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

class FakeWorld extends RefCounted:
	func behind_point(seen, metres: float) -> Vector3: return Vector3(seen.point.x - metres, 0, 0)
	func flee_exit(_away: Vector3) -> int: return 0
	func dark_retreat(_away: Vector3) -> Vector3: return Vector3(-20, 0, 0)
	func scream(_point: Vector3) -> void: pass
	func show_spot(_seen, _kind: String) -> Dictionary: return {}
	func room_point(_room: int) -> Vector3: return Vector3.ZERO
	func clue_point(point: Vector3) -> Vector3: return point
	var patrol := -1
	func patrol_room() -> int: return patrol
	func travel_metres(_room: int) -> Dictionary: return {}
	func exit_of_room(_room: int) -> int: return -1
	func lead_rooms(_point: Vector3, _radius: float, _avoid: Array) -> Array: return [1]
	func above_locker(_hide) -> Vector3: return Vector3.ZERO
	var emerge := Vector3.INF
	func emerge_point(_seat: int, _mode: String, _span: Vector2) -> Vector3: return emerge

func run() -> void:
	prey_choice()
	roaming()
	encounter()
	gives_up()
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "lurker"
	level.set_floor(2)
	for seed_value in SEEDS:
		await level.start_floor(int(seed_value), false, [1], "desafiante")
		corridor = find_corridor()
		if not corridor.is_empty(): break
	lurker = level.creature
	if corridor.is_empty() or lurker == null or lurker.kind_id() != &"lurker":
		check("Un pasillo largo y ella en el piso", false)
		finish()
		return
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.set_physics_process(false)
	lurker.thinking = false
	lurker.grace = 0.0
	await sight()
	await hearing()
	await torch_click()
	await drain()
	await director_and_words()
	await systems()
	finish()

func finish() -> void:
	var file := FileAccess.open("res://evidence/lurker_senses_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks, "seed": corridor.get("seed", -1)}, "\t"))
	print("LURKER_SENSES_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	if level != null: level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)

## The longest corridor cell of planta 1 (at least 9 m), not next to an
## off-limits room: {room, centre, along, half}.
func find_corridor() -> Dictionary:
	var off: Array = level.off_limits_rooms()
	var best := {}
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != 0 or int(room.type) != OFFICE.CORRIDOR: continue
		var span := FLOOR.size_of(room)
		if maxf(span.x, span.y) < 9.0 or not level.creature.shell.tray_of.has(int(room.id)): continue
		if level.manifest.adjacency[int(room.id)].any(func(other): return off.has(int(other))): continue
		if not best.is_empty() and maxf(span.x, span.y) <= float(best.half) * 2.0: continue
		var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
		best = {"room": int(room.id), "centre": FLOOR.position_of(room), "along": along, "half": maxf(span.x, span.y) / 2.0}
	return best

func place_player(point: Vector3, facing: Vector3) -> void:
	var player = level.player
	player.global_position = point
	player.rotation.y = atan2(-facing.x, -facing.z)
	player.camera.rotation.x = 0.0
	for i in 2: await physics_frame

func aim_at(point: Vector3) -> void:
	var player = level.player
	var to: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

## Her over one end of the corridor facing along it, the player `metres`
## along from her (in plan) facing on.
func line_up(metres: float, dark: bool, torch: bool) -> void:
	level.hotel.set_room_power(int(corridor.room), not dark)
	var along: Vector3 = corridor.along
	var start: Vector3 = (corridor.centre as Vector3) - along * (float(corridor.half) - 0.8)
	lurker.place_over(start, start + along * 10.0)
	await place_player(start + along * metres, along)
	level.player.torch.visible = torch
	await physics_frame

func sight() -> void:
	var span := float(corridor.half) * 2.0 - 1.6
	var far := minf(span - 0.2, 12.0)
	await line_up(far, true, false)
	check("Ver a oscuras: a %.0f m de espaldas y sin linterna, lo ve" % far, lurker.sees(level.player))
	await line_up(6.0, false, false)
	check("Con luz, la luz la ciega: a 6 m no lo ve", not lurker.sees(level.player))
	await line_up(3.0, false, false)
	check("Con luz, a 3 m sí", lurker.sees(level.player))
	await line_up(6.0, true, true)
	aim_at(lurker.face_point())
	check("Con la linterna en la cara no ve a quien la alumbra", not lurker.sees(level.player))
	# A wall between: the player in a room of the planta with no door to hers.
	var walled := -1
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != 0 or FLOOR.is_void(room) or int(room.id) == int(corridor.room): continue
		if level.manifest.adjacency[int(corridor.room)].has(int(room.id)): continue
		if FLOOR.position_of(room).distance_to(corridor.centre) < 14.0 and lurker.shell.tray_of.has(int(room.id)):
			walled = int(room.id)
			break
	if walled >= 0:
		level.hotel.set_room_power(walled, false)
		await place_player(FLOOR.position_of(level.manifest.rooms[walled]), Vector3(1, 0, 0))
		level.player.torch.visible = false
		lurker.place_over(corridor.centre, level.player.camera.global_position)
		await physics_frame
		check("Las paredes tapan", not lurker.sees(level.player))

func hearing() -> void:
	await line_up(5.0, true, false)
	var near: Dictionary = lurker.hear_route(level.player.global_position, NOISE.radius("walk"))
	check("Oye unos pasos a 5 m por la sala", bool(near.audible) and String(near.via) == "room" and float(near.muffle) == 0.0, str(near))
	var down: Vector3 = level.player.global_position + Vector3(0, FLOOR.planta_y(1), 0)
	var other: Dictionary = lurker.hear_route(down, NOISE.radius("slam"))
	check("No oye nada de otra planta", not bool(other.audible))
	# Through her ducts: inside a grille, a noise right under another grille
	# of the same network a short way along it.
	var ducts = lurker.ducts
	var pair := []
	for a in ducts.exits.size():
		var ea: Dictionary = ducts.exits[a]
		if String(ea.kind) != "ceiling" or int(ea.node) < 0 or FLOOR.planta_of((ea.position as Vector3).y) != 0: continue
		var near_exits: Array = ducts.nearest_exits(int(ea.node), 4)
		for found in near_exits:
			var b := int(found.exit)
			if b == a or float(found.metres) > 12.0 or String(ducts.exits[b].kind) != "ceiling" or int(ducts.exits[b].room) == int(ea.room): continue
			pair = [a, b]
			break
		if not pair.is_empty(): break
	if pair.is_empty():
		check("Dos rejillas de techo cerca por los ductos", false)
		return
	lurker.place_in_exit(int(pair[0]))
	await physics_frame
	var under: Vector3 = (ducts.exits[int(pair[1])].position as Vector3) - Vector3(0, 1.5, 0)
	var by_duct: Dictionary = lurker.hear_route(under, NOISE.radius("run"))
	check("Dentro de un ducto oye lo que pasa bajo otra rejilla, por los ductos", bool(by_duct.audible) and String(by_duct.via) == "duct", str(by_duct))
	ducts.closed_wings[0] = 1
	var shut: Dictionary = lurker.hear_route(under, NOISE.radius("run"))
	ducts.closed_wings[0] = 0
	check("Con los ductos cerrados por ahí no le llega", not bool(shut.audible) or String(shut.via) != "duct", str(shut))

func torch_click() -> void:
	await line_up(4.0, true, false)
	lurker.thinking = true
	lurker.brain.forget_all(0.0)
	await physics_frame
	level.player.torch.visible = true
	await physics_frame
	await physics_frame
	var clue: Dictionary = lurker.brain.clue
	lurker.thinking = false
	check("Oye el clic de la linterna a 4 m", not clue.is_empty() and (clue.point as Vector3).distance_to(level.player.camera.global_position) < 0.5, str(clue))

func drain() -> void:
	var room := -1
	var troffer := Vector3.ZERO
	var off: Array = level.off_limits_rooms()
	for r in level.manifest.rooms:
		if int(r.get("wing", -1)) != 0 or off.has(int(r.id)) or OFFICE.lamp_of(r) != "troffer" or not lurker.shell.tray_of.has(int(r.id)): continue
		var list: Array = OFFICE.troffers(r)
		if list.is_empty(): continue
		room = int(r.id)
		troffer = Vector3((list[0].centre as Vector2).x, float(r.get("py", 0.0)), (list[0].centre as Vector2).y)
		break
	if room < 0:
		check("Una sala con luminarias", false)
		return
	level.hotel.set_room_power(room, true)
	level.hotel.reduced = true
	lurker.place_over(troffer, troffer + Vector3(1, 0, 0))
	var dropped := true
	var last := 0.0
	for i in 36:
		await physics_frame
		var now: float = level.hotel.drained(room)
		if now < last - 1e-6: dropped = false
		last = now
	var at := float(level.hotel.drained(room))
	check("Bebe la luz de la sala sobre la que está, sin temblar con efectos reducidos", dropped and at >= SENSES.DRAIN.x - 0.01 and at <= SENSES.DRAIN.y + 0.01, "%.3f" % at)
	check("Y la sala sigue con luz para las reglas", level.hotel.lit(room))
	level.hotel.reduced = false
	var wobble_ok := true
	for i in 36:
		await physics_frame
		var now: float = level.hotel.drained(room)
		if now > SENSES.DRAIN.y + SENSES.DRAIN_WOBBLE + 0.01 or now >= level.hotel.LIT_DRAIN: wobble_ok = false
	check("Con efectos, tiembla sin pasar nunca de lo que deja la sala a oscuras", wobble_ok and level.hotel.lit(room))
	lurker.relocate(corridor.centre, 0.0)
	check("Al moverla de golpe, la luz vuelve entera en el mismo fotograma", level.hotel.drained(room) == 0.0)

func director_and_words() -> void:
	lurker.thinking = true
	level.player.global_position = Vector3(0, -200, 0)
	# Past her next look (every SENSE_EVERY), so she no longer sees them.
	for i in 12: await physics_frame
	lurker.brain.forget_all(0.0)
	await physics_frame
	var off: Array = level.off_limits_rooms()
	var player_room := int(FLOOR.room_at(level.manifest.rooms, corridor.centre).get("id", -1))
	var led: bool = lurker.lead_to(corridor.centre, 12.0, 30.0, "merodea", false, [player_room])
	var rooms: Array = lurker.brain.lead.get("rooms", [])
	check("El director le da una zona, sin salas vedadas ni la que evita", led and not rooms.is_empty() and not rooms.any(func(r): return off.has(int(r)) or int(r) == player_room), "%s %s %s" % [str(rooms), lurker.brain.state_name(), str(lurker.lead_rooms(corridor.centre, 12.0, [player_room]))])
	lurker.brain.force(&"stalk", {"seat": int(level.player.slot)})
	check("Acechando no acepta zonas", not lurker.lead_to(corridor.centre, 12.0, 30.0, "merodea"))
	await physics_frame
	check("Acechar tiene palabra propia: stalk", lurker.activity() == &"stalk" and lurker.is_hostile() and not lurker.is_hunting() and not lurker.is_chasing())
	lurker.brain.force(&"flee")
	await physics_frame
	check("Huir es withdraw, la última palabra", lurker.activity() == &"withdraw" and lurker.WORDS.find(&"withdraw") == lurker.WORDS.size() - 1 and not lurker.is_hostile())
	lurker.thinking = false

## The floor's systems told to her mind (spec_f3_integration 2.2 and 2.7).
func systems() -> void:
	level.player.global_position = Vector3(0, -200, 0)
	var room := int(corridor.room)
	level.hotel.set_room_power(room, false)
	lurker.place_over(corridor.centre, corridor.centre + corridor.along)
	lurker.thinking = true
	for i in 12: await physics_frame
	lurker.brain.forget_all(0.0)
	lurker.brain.force(&"roam")
	for i in 20: await physics_frame
	var before: String = lurker.brain.state_name()
	check("Fuera de los ductos su voz sale de su cara, y su presencia no suena si no espera encima de una taquilla", lurker.voice_point().is_equal_approx(lurker.face_point()) and not lurker.presence_on())
	level.hotel.set_room_power(room, true)
	var fled := false
	for i in 30:
		await physics_frame
		if lurker.brain.state == BRAIN.State.FLEE: fled = true
	check("La luz que se enciende en su sala la hace huir", fled, "%s antes, sala %d, ella en %d" % [before, room, lurker.motion.room()])
	var air = level.objective(&"air")
	var high := {}
	var off: Array = level.off_limits_rooms()
	for r in level.manifest.rooms:
		if int(r.get("wing", -1)) == 2 and not off.has(int(r.id)) and lurker.shell.tray_of.has(int(r.id)):
			high = r
			break
	if air == null or high.is_empty():
		check("Los ventiladores y una sala de la planta 3", false)
	else:
		var at := FLOOR.position_of(high)
		lurker.place_over(at, at + Vector3(1, 0, 0))
		lurker.brain.forget_all(0.0)
		lurker.brain.force(&"roam")
		# Past FAN_SPIN both ways.
		air.running_until = 1.0e9
		for i in 200: await physics_frame
		var shut_seen: bool = lurker.ducts_were_shut
		air.running_until = 0.0
		var stopped_at: float = lurker.brain.clock
		var clued := false
		for i in 200:
			await physics_frame
			var clue: Dictionary = lurker.brain.clue
			if clue.is_empty() or float(clue.at) < stopped_at: continue
			for e in lurker.ducts.exits:
				if (e.position as Vector3).distance_to(clue.point) < 0.01: clued = true
		check("Al parar los ventiladores va a la rejilla más cercana", shut_seen and clued, "cerrados %s, %s" % [str(shut_seen), lurker.brain.state_name()])
	main_duct()
	var seat := int(level.player.slot)
	lurker.brain.spurned[seat] = lurker.brain.clock + 30.0
	var data: Dictionary = lurker.save_state()
	lurker.brain.spurned.erase(seat)
	lurker.restore_state(data, 0.0)
	var left: float = float(lurker.brain.spurned.get(seat, -INF)) - float(lurker.brain.clock)
	check("A quien la espantó la sigue dejando en paz tras guardar y cargar", left > 29.9 and left <= 30.0 + 1e-4, "%.3f" % left)
	lurker.thinking = false

## The main duct's crossing shut to her while somebody crawls between the
## hatch and it, open again once they are past it; out of the main through it
## always (the author's I10).
func main_duct() -> void:
	var routes = lurker.routes
	var main: Dictionary = level.manifest.get("air", {}).get("main", {})
	if routes.main_cross < 0 or main.is_empty():
		check("El ducto principal y su cruce", false, "%d" % routes.main_cross)
		return
	var nodes: Array = main.nodes
	var ci: int = nodes.find(int(main.cross))
	var into := []
	var out_of := []
	for link in routes.graph[routes.main_cross]:
		if int(link[6]) == routes.cross_edge: out_of = link
	var stub: int = int(out_of[0]) if not out_of.is_empty() else -1
	if stub >= 0:
		for link in routes.graph[stub]:
			if int(link[6]) == routes.cross_edge: into = link
	var factors = routes.factors_for(2)
	var before: Vector3 = (routes.main_line[0] + routes.main_line[1]) / 2.0
	level.player.global_position = before
	routes.tick(0.0)
	var shut_before: bool = routes.cross_shut and routes.edge_cost(into, factors, false) == INF and routes.edge_cost(out_of, factors, false) < INF
	check("Con alguien reptando entre la compuerta y el cruce no entra por el cruce, y sí sale", level.crawling_at(before) and not into.is_empty() and shut_before, "repta %s, cruce %d de %d" % [str(level.crawling_at(before)), ci, nodes.size()])
	var past := Vector3.INF
	for i in range(ci + 1, nodes.size() - 1):
		var p: Vector3 = routes.main_line[i]
		if routes.along_main(p) >= routes.cross_along + routes.CROSS_CLEAR and level.crawling_at(p):
			past = p
			break
	if past != Vector3.INF:
		level.player.global_position = past
		routes.tick(0.0)
		check("Pasado el cruce hacia el pozo, entra por detrás", not routes.cross_shut and routes.edge_cost(into, factors, false) < INF)
	level.player.global_position = Vector3(0, -200, 0)
	routes.tick(0.0)
	check("Sin nadie en el ducto principal el cruce es suyo", not routes.cross_shut and routes.edge_cost(into, factors, false) < INF)

## Two ways she used to stand still (24 October 2026, the author's first
## game): a lead given her in a duct, where she has no room to measure from,
## was dropped; and a goal chosen while standing still was taken as reached
## on the same tick, so in a room with no grille she never moved again.
func roaming() -> void:
	var world := FakeWorld.new()
	var brain = BRAIN.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	brain.setup(world, rng, WARNING.new())
	var p = SENSES.Percept.new()
	p.room = -1
	p.in_duct = true
	brain.lead_to(Vector3(10, 0, 0), 12.0, 60.0, "merodea")
	brain.tick(1.0 / 60.0, p)
	check("Una zona que le da el director dentro de un ducto no la tira: va", not brain.lead.is_empty() and int(brain.goal.get("room", -1)) == 1, str(brain.goal))
	brain.force(&"roam")
	brain.lead = {}
	brain.goal = {}
	world.patrol = 2
	p.room = 3
	p.in_duct = false
	# Walking to a room, then there, standing still.
	p.arrived = false
	for i in 40: brain.tick(1.0 / 60.0, p)
	p.arrived = true
	brain.tick(1.0 / 60.0, p)
	var intent: Dictionary = brain.tick(1.0 / 60.0, p)
	check("Parada en una sala, la meta que elige no cuenta como alcanzada: se pone en marcha", String(intent.get("do", "")) == "go" and int(brain.goal.get("room", -1)) == 2, str(intent))

## An encounter of several attempts (the author, 24 October 2026): each
## failed one sends her out of sight and back out where the difficulty says;
## after the last she leaves that survivor be for the rest.
## Her way after somebody failing for good (the author's games, 25 October
## 2026: she hung on the ceiling): past GIVE_UP she lets them go and roams.
func gives_up() -> void:
	var world := FakeWorld.new()
	var brain = BRAIN.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	brain.setup(world, rng, WARNING.new())
	brain.prey = 1
	brain.enter(BRAIN.State.STALK)
	var p = SENSES.Percept.new()
	p.failed = true
	for i in int((BRAIN.GIVE_UP - 0.5) * 60.0): brain.tick(1.0 / 60.0, p)
	var still: bool = brain.state == BRAIN.State.STALK or brain.state == BRAIN.State.ROAM
	var before_give_up: bool = brain.failed_for > 0.0 or brain.state != BRAIN.State.STALK
	for i in 60: brain.tick(1.0 / 60.0, p)
	check("Si su camino tras alguien no deja de fallar, lo deja y vuelve a rondar", still and before_give_up and brain.state != BRAIN.State.STALK and brain.prey == -1, "%s %d" % [brain.state_name(), brain.prey])

func encounter() -> void:
	var world := FakeWorld.new()
	var brain = BRAIN.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	brain.setup(world, rng, WARNING.new())
	brain.tune({"attempts": 3, "encounter_rest": 90.0, "emerge_delay": [1.0, 1.0], "emerge_mode": "behind", "emerge_range": [3.0, 5.0]})
	var p = SENSES.Percept.new()
	brain.prey = 1
	brain.recoil(1, "mirada", p)
	var after_one: bool = int(brain.attempts.get(1, 0)) == 1 and not brain.spurned.has(1) and not brain.comeback.is_empty()
	world.emerge = Vector3(9, 0, 0)
	brain.enter(BRAIN.State.FLEE)
	p.in_duct = true
	var intent: Dictionary = {}
	for i in 90: intent = brain.tick(1.0 / 60.0, p)
	var back_out: bool = String(intent.get("do", "")) == "go" and (intent.get("to", Vector3.INF) as Vector3) == Vector3(9, 0, 0) and brain.prey == 1
	check("Un intento fallido no la aparta: sale del techo por donde toca y vuelve a por esa persona", after_one and back_out, "%s %s" % [str(brain.attempts), str(intent)])
	brain.recoil(1, "linterna", p)
	brain.recoil(1, "corriendo", p)
	check("Al fallar el último intento la deja en paz su rato", not brain.attempts.has(1) and float(brain.spurned.get(1, -INF)) - brain.clock > 89.0 and brain.comeback.is_empty(), str(brain.spurned))

## Her own choice of prey (7.7), on a bare brain with a fake world.
func prey_choice() -> void:
	var brain = BRAIN.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	brain.setup(FakeWorld.new(), rng, WARNING.new())
	var p = SENSES.Percept.new()
	p.bodies[1] = seen_of(1, true, 2.0)
	brain.tick(1.0 / 60.0, p)
	check("Elige presa ella: la primera que ve", brain.prey == 1 and brain.state == BRAIN.State.STALK)
	p.bodies[2] = seen_of(2, false, 18.0)
	brain.tick(1.0 / 60.0, p)
	check("Acechando, cambia a la que está más sola y a oscuras", brain.prey == 2)
	brain.prey = 1
	brain.force(&"creep", {"seat": 1})
	p.victim = p.bodies[1]
	brain.tick(1.0 / 60.0, p)
	check("Acercándose no cambia de presa", brain.prey == 1)
	brain.force(&"stalk", {"seat": 1})
	brain.spurned[2] = brain.clock + 30.0
	brain.tick(1.0 / 60.0, p)
	check("A la que la espantó la deja en paz", brain.prey == 1)

func seen_of(seat: int, lit: bool, alone: float):
	var s = SENSES.Seen.new()
	s.seat = seat
	s.seen = true
	s.fair = true
	s.lit = lit
	s.alone = alone
	s.distance = 9.0
	s.point = Vector3(float(seat) * 3.0, 0, 0)
	s.eye = s.point + Vector3(0, 1.64, 0)
	return s
