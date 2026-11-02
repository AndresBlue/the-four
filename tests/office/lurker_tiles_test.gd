extends SceneTree
## Any tile of a false ceiling her way in and out (the author, 24 October
## 2026; .claude/specs/spec_f3_aggression.md, unit 5). On the test plan
## (lurker_fixture.gd): the plenum over every false ceiling, in by the tile
## over her, out by the one nearest where she goes, back in by one she left
## open, never a jump on the way. On a built floor: the tile that swings
## down and stays half open as she comes out and shuts after her as she goes
## back in, and where she comes out for another attempt behind the survivor.
const FIX := preload("res://tests/office/lurker_fixture.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const DUCTS := preload("res://game/enemies/lurker/duct_graph.gd")
const MOTION := preload("res://game/enemies/lurker/lurker_motion.gd")
const GEOMETRY := preload("res://game/world/office/office_geometry.gd")
const DT := 1.0 / 60.0
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func wait(seconds: float) -> void: await create_timer(seconds).timeout

func run() -> void:
	plenum()
	ways()
	await built()
	var file := FileAccess.open("res://evidence/lurker_tiles_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("LURKER_TILES_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

static func tile_exit(ducts, room: int) -> int:
	for e in ducts.exits.size():
		if String(ducts.exits[e].kind) == "tile" and int(ducts.exits[e].room) == room: return e
	return -1

## The squeeze through a tile of a plan's legs, in or out; {} with none.
static func tile_leg(legs: Array, into: bool) -> Dictionary:
	for leg in legs:
		if String(leg.kind) == "squeeze" and leg.has("tile") and bool(leg.into) == into: return leg
	return {}

## A tile of the room this far from a point, give or take a tile.
static func tile_about(ducts, room: int, from: Vector3, metres: float) -> Vector2i:
	var best: Vector2i = DUCTS.NO_TILE
	var best_d := INF
	for tile in ducts.room_tiles.get(room, []):
		var d := absf(DUCTS.tile_flat(tile).distance_to(Vector2(from.x, from.z)) - metres)
		if d < best_d:
			best_d = d
			best = tile
	return best

func plenum() -> void:
	var m: Dictionary = FIX.fixture()
	var hers = DUCTS.of(m)
	var wrong: Array = []
	for room in m.rooms:
		var id := int(room.id)
		var wants: bool = OFFICE.false_ceiling(room) and not OFFICE.off_limits(room) and not OFFICE.free_tiles(room).is_empty()
		if wants != hers.plenum_node.has(id):
			wrong.append(id)
			continue
		if not wants: continue
		var node := int(hers.plenum_node[id])
		var e := tile_exit(hers, id)
		if e < 0 or int(hers.exits[e].node) != node or hers.node_kinds[node] != "plenum": wrong.append(id)
		elif hers.cell_node.has(id) and hers.edge_kind(node, int(hers.cell_node[id])) != "plenum": wrong.append(id)
	check("Cada techo falso tiene su pleno y una salida por placa; la sala que no se pisa, no", wrong.is_empty() and hers.plenum_node.has(0) and not hers.plenum_node.has(3), "%s %s" % [str(wrong), str(hers.plenum_node)])
	var a := int(hers.plenum_node.get(0, -1))
	var b := int(hers.plenum_node.get(1, -1))
	check("Por el pleno se pasa a la sala de al lado", a >= 0 and b >= 0 and hers.edge_kind(a, b) == "plenum")
	check("Una placa cerrada no deja pasar el sonido", b >= 0 and hers.mouths_in_room(1).is_empty() and not hers.mouths_in_room(0).is_empty())
	# Spec_rediseno 9: none of her tiles within COLUMN_TILE of a column of a
	# nave, and the columns take some from the cells they stand in.
	var nave: Dictionary = FIX.nave_fixture()
	var by_nave = DUCTS.of(nave)
	var near_column: Array = []
	var fewer := 0
	for room in nave.rooms:
		var bare: Dictionary = room.duplicate(true)
		bare.columns = []
		if OFFICE.free_tiles(room).size() < OFFICE.free_tiles(bare).size(): fewer += 1
		for tile in by_nave.room_tiles.get(int(room.id), []):
			var c: Vector3 = OFFICE.tile_centre(tile, 0.0)
			for r in OFFICE.column_rects(room):
				var nearest := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.z, r.position.y, r.end.y))
				if Vector2(c.x, c.z).distance_to(nearest) < OFFICE.COLUMN_TILE - 1e-6: near_column.append([int(room.id), tile])
	check("Placas: ninguna de las suyas a menos de 0,6 m de una columna, y las columnas le quitan alguna", near_column.is_empty() and fewer > 0 and not by_nave.room_tiles.is_empty(), "%s %d" % [str(near_column.slice(0, 3)), fewer])

func ways() -> void:
	var m: Dictionary = FIX.fixture()
	var lvl = FIX.stub_level(m)
	var routes = FIX.routes_on(m, lvl)
	var ducts = routes.ducts
	var e := tile_exit(ducts, 0)
	var hub: Vector3 = ducts.nodes[int(ducts.plenum_node.get(0, 0))]
	var under: Vector2i = tile_about(ducts, 0, hub, 2.0)
	var at: Vector3 = ducts.tile_point(0, under)
	var s = routes.shell.tray_state(0, at.x, at.z)
	var p: Vector3 = routes.shell.anchor_of(s)
	var plan: Dictionary = routes.plan({"room": 0}, {"exit": e}, s, p)
	var into := tile_leg(plan.get("legs", []), true)
	var i: int = (plan.get("legs", []) as Array).find(into)
	var then: Dictionary = plan.legs[i + 1] if i >= 0 and i + 1 < plan.legs.size() else {}
	var first: Vector3 = (then.points as PackedVector3Array)[0] if not then.is_empty() else Vector3.INF
	check("Se mete en el techo por la placa que tiene encima, y por dentro sigue desde ella", bool(plan.ok) and not into.is_empty() and into.tile == under and first.is_equal_approx(at) and (into.from as Vector3).distance_to(p) < 0.05, "%s %s %s" % [str(into.get("tile")), str(under), str(first)])
	check("Iluminada, huye por la placa de encima", routes.flee_exit({"room": 0}, p + Vector3(1.5, 0, 0), p) == e, str(routes.flee_exit({"room": 0}, p + Vector3(1.5, 0, 0), p)))
	var left_open: Vector2i = tile_about(ducts, 0, at, 1.8)
	ducts.open_tiles[0] = [left_open]
	var again := tile_leg(routes.plan({"room": 0}, {"exit": e}, s, p).get("legs", []), true)
	check("Vuelve a entrar por la que dejó abierta cerca", again.get("tile") == left_open and left_open != under, "%s %s" % [str(again.get("tile")), str(left_open)])
	ducts.open_tiles[0] = []
	# Out where she is going: a tile far from the grille, the doors shut.
	var grille: Vector3 = ducts.exits[0].position
	var far: Vector2i = tile_about(ducts, 0, grille, 4.0)
	var q: Vector3 = routes.shell.anchor_of(routes.shell.tray_state(0, ducts.tile_point(0, far).x, ducts.tile_point(0, far).z))
	for door in lvl.hotel.doors.values(): door.opened = false
	var back: Dictionary = routes.plan({"room": 2}, {"room": 0, "point": q})
	var out := tile_leg(back.get("legs", []), false)
	var j: int = (back.get("legs", []) as Array).find(out)
	var before: Dictionary = back.legs[j - 1] if j > 0 else {}
	var last: Vector3 = (before.points as PackedVector3Array)[(before.points as PackedVector3Array).size() - 1] if String(before.get("kind", "")) == "duct" else Vector3.INF
	check("Sale por la placa más cercana a donde va, y llega a ella por dentro", bool(back.ok) and not out.is_empty() and out.tile == far and last.is_equal_approx(ducts.tile_point(0, far)), "%s %s %s" % [str(out.get("tile")), str(far), str(last)])
	for door in lvl.hotel.doors.values(): door.opened = true
	# In and out on her own legs: the tile moves at the squeeze, and never a jump.
	var motion = MOTION.new()
	motion.setup(routes.shell, routes, ducts, lvl)
	motion.place_at(p, Vector3.RIGHT, &"start")
	motion.jumps = []
	var turns: Array = []
	motion.tile_turned.connect(func(room: int, tile: Vector2i, open: bool, below: bool): turns.append([room, tile, open, below]))
	motion.go_to_exit(e, 1.35)
	var worst := drive(motion, 12.0, func(): return motion.in_duct and motion.legs.is_empty())
	check("Al entrar la levanta desde abajo y la cierra tras ella", turns == [[0, under, true, true], [0, under, false, true]] and motion.in_duct and motion.hidden, str(turns))
	turns.clear()
	motion.go_to(q, 1.35)
	worst = maxf(worst, drive(motion, 12.0, func(): return not motion.in_duct and motion.legs.is_empty()))
	check("Al salir la empuja desde arriba y la deja abierta", turns == [[0, far, true, false]] and not motion.in_duct and motion.anchor().distance_to(q) < 0.3, "%s %s" % [str(turns), str(motion.anchor())])
	check("Sin saltos al entrar y salir por una placa", worst <= 0.0 and motion.jumps.is_empty(), "%f %s" % [worst, str(motion.jumps)])

## Ticks until `done` or `seconds`; the worst step past what she may move in a frame.
func drive(motion, seconds: float, done: Callable) -> float:
	var worst := 0.0
	var last: Vector3 = motion.transform().origin
	for i in int(seconds / DT):
		motion.tick(DT)
		var now: Vector3 = motion.transform().origin
		worst = maxf(worst, now.distance_to(last) - ((MOTION.SCURRY_SPEED + 0.5) * DT + 1e-3))
		last = now
		if bool(done.call()): break
	return worst

## A built floor: the tile that swings, and where she comes out behind.
func built() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "lurker"
	level.set_floor(2)
	await level.start_floor(7, false, [1], "pesadilla")
	var lurker = level.creature
	if lurker == null or lurker.kind_id() != &"lurker":
		check("Ella en el piso", false)
		return
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.set_physics_process(false)
	lurker.thinking = false
	var ducts = lurker.ducts
	var room := -1
	for id in ducts.room_tiles:
		if int(level.manifest.rooms[int(id)].get("wing", -1)) == 0 and lurker.shell.tray_of.has(int(id)) and not level.hotel.lit(int(id)) and (ducts.room_tiles[id] as Array).size() >= 8:
			room = int(id)
			break
	if room < 0:
		check("Una sala a oscuras de la planta 1 con techo falso", false)
		return
	var node: Node3D = level.hotel.room_nodes[room]
	var runs := node.get_node("Mesh_ceiling_service") as MultiMeshInstance3D
	var count: int = runs.multimesh.instance_count
	var tile: Vector2i = ducts.room_tiles[room][0]
	var held = level.hotel.turn_tile(room, tile, true, false)
	await wait(GEOMETRY.TILE_SWING + 0.15)
	var hinge: Node3D = level.hotel.moved_tiles.get(Vector3i(room, tile.x, tile.y))
	var centre: Vector3 = node.to_local(OFFICE.tile_centre(tile, float(level.manifest.rooms[room].height) + float(level.manifest.rooms[room].py)))
	var covered := false
	for t in level.hotel.service_runs[node.get_instance_id()][0]:
		var half: Vector3 = t.basis.get_scale() * 0.5
		if absf(centre.x - t.origin.x) < half.x - 0.01 and absf(centre.z - t.origin.z) < half.z - 0.01 and absf(t.origin.y - centre.y) < 0.05: covered = true
	check("Al salir, la placa se abre hacia abajo y queda a medio abrir sobre su hueco oscuro", held is Vector3 and hinge != null and is_equal_approx(hinge.rotation.z, GEOMETRY.TILE_DOWN) and (hinge.get_meta("dark") as Node3D).visible and not covered and runs.multimesh.instance_count <= count + 1, "%s %s %s %d %d" % [str(held), str(hinge.rotation if hinge != null else null), str(covered), count, runs.multimesh.instance_count])
	level.hotel.turn_tile(room, tile, false, true)
	await wait(GEOMETRY.TILE_SWING + 0.15)
	check("Al volver a entrar por ella, la cierra", absf(hinge.rotation.z) < 0.001 and not (hinge.get_meta("dark") as Node3D).visible)
	level.hotel.turn_tile(room, tile, true, true)
	await wait(GEOMETRY.TILE_SWING + 0.15)
	check("Entrando por una cerrada la levanta hacia el pleno", is_equal_approx(hinge.rotation.z, -GEOMETRY.TILE_UP) and (hinge.get_meta("dark") as Node3D).visible)
	level.hotel.turn_tile(room, tile, false, true)
	# Behind the survivor: in that room, looking along +x, she comes out 3 to 6 m behind.
	var r: Dictionary = level.manifest.rooms[room]
	var stand := Vector3(float(r.px), float(r.py) + 0.1, float(r.pz))
	level.player.global_position = stand
	level.player.look_at(stand + Vector3(1, 0, 0), Vector3.UP)
	await physics_frame
	var look: Vector3 = -(level.player.camera.global_basis.z if level.player.get("camera") != null else level.player.global_basis.z)
	var forward := Vector3(look.x, 0, look.z).normalized()
	var out: Vector3 = lurker.emerge_point(int(level.player.slot), "behind", Vector2(3.0, 6.0))
	var flat := Vector3(out.x - stand.x, 0, out.z - stand.z)
	check("Para otro intento sale de una placa a su espalda, a la distancia pedida", out != Vector3.INF and flat.length() >= 2.9 and flat.length() <= 6.1 and forward.dot(flat.normalized()) <= -0.2, "%s %s %s" % [str(out), str(stand), str(forward)])
	level.queue_free()
	await process_frame
