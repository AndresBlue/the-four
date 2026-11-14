extends SceneTree
## The conduit graph (game/world/generation/conduit_graph.gd, spec_f1_systems
## 1.5 and spec_f2_movement 5.1) on the manifests of two floors: the tube tree
## and the duct network connected, the way from the window's hub to every
## station as long as the generator measured it, the nearest exits in order,
## and a closed network shut to a search but not to one that ignores it; and
## her ducts (duct_graph.gd): gaps hung on, wings, and closure per wing.
const GEN := preload("res://game/world/generation/office_generator.gd")
const GRAPH := preload("res://game/world/generation/conduit_graph.gd")
const DUCTS := preload("res://game/enemies/lurker/duct_graph.gd")

class CountedDucts extends "res://game/enemies/lurker/duct_graph.gd":
	var mouth_scans := 0
	var edge_checks := 0

	func mouths_of_all() -> PackedInt32Array:
		mouth_scans += 1
		return super()

	func edge_closed(edge: int) -> bool:
		edge_checks += 1
		return super(edge)

var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	for seed_value in [7, 33]:
		var m: Dictionary = GEN.new().generate(int(seed_value), 2)
		var tag := "semilla %d" % int(seed_value)
		var tubes = GRAPH.from_manifest(m.tubes, true)
		check("%s: el árbol de tubos está unido" % tag, tubes.connected() and tubes.nodes.size() == m.tubes.nodes.size())
		var hub := int(m.tubes.hub)
		var wrong: Array = []
		for e in m.tubes.exits:
			if String(e.kind) != "station": continue
			var way: Dictionary = tubes.shortest(hub, int(e.node))
			if way.path.is_empty() or absf(float(way.length) - float(e.tube)) > 0.05: wrong.append([int(e.number), float(way.length), float(e.tube)])
		check("%s: de la ventanilla a cada estación, los metros del generador" % tag, wrong.is_empty(), str(wrong))
		var points: PackedVector3Array = tubes.points_of(tubes.shortest(hub, int(m.tubes.exits[1].node)).path)
		check("%s: un punto a lo largo de un camino cae en él y se para en su final" % tag, GRAPH.point_along(points, 0.0) == points[0] and GRAPH.point_along(points, 99999.0) == points[points.size() - 1])
		check("%s: los tubos radian por cada nodo de una sala" % tag, tubes.mouths_in_room(int(tubes.node_rooms[hub])).has(hub))
		var ducts = GRAPH.from_manifest(m.ducts, false)
		check("%s: la red de ductos se lee entera" % tag, ducts.nodes.size() == m.ducts.nodes.size() and ducts.edges.size() == m.ducts.edges.size() and ducts.exits.size() == m.ducts.exits.size())
		var start := int(m.ducts.exits[0].node)
		var near: Array = ducts.nearest_exits(start, 5)
		var ordered := near.size() == 5
		for i in range(1, near.size()):
			if float(near[i].metres) < float(near[i - 1].metres): ordered = false
		check("%s: las salidas más cercanas, en orden" % tag, ordered and float(near[0].metres) == 0.0, str(near))
		ducts.closed = true
		check("%s: cerrados, no se pasa; ignorando el cierre, sí" % tag, ducts.nearest_exits(start, 5).size() <= 1 and ducts.nearest_exits(start, 5, Callable(), true).size() == 5)
		# Her ducts (duct_graph.gd): every gap a way in, the wings, closure per wing.
		var hers = DUCTS.of(m)
		var loose: Array = []
		for e in hers.exits:
			if String(e.kind) == "gap" and (int(e.node) < 0 or hers.adjacency[int(e.node)].is_empty()): loose.append(e.room)
		check("%s: cada placa que falta es una entrada enganchada a la red" % tag, loose.is_empty(), str(loose))
		check("%s: cada nodo sabe su planta" % tag, hers.node_wings.size() == hers.nodes.size() and Array(hers.node_wings).all(func(w): return w >= 0 and w <= 2))
		var main_nodes: Array = m.air.main.nodes
		check("%s: el conducto principal se ve como tal" % tag, hers.edge_kind(int(main_nodes[0]), int(main_nodes[1])) == "main")
		var near_trunk: int = hers.trunk_nearest(hers.nodes[int(main_nodes[1])], 2)
		check("%s: el tronco más cercano, de su planta" % tag, near_trunk >= 0 and hers.node_wings[near_trunk] == 2 and hers.node_kinds[near_trunk] == "trunk")
		var top: int = hers.trunk_nearest(Vector3.ZERO, 0)
		var low: int = hers.trunk_nearest(Vector3.ZERO, 2)
		var before_top: int = hers.nearest_exits(top, 3).size()
		hers.closed_wings[2] = 1
		check("%s: los ventiladores cierran los ductos de su planta y no los de otra" % tag, hers.nearest_exits(low, 3).size() <= 1 and hers.nearest_exits(top, 3).size() == before_top and hers.nearest_exits(low, 3, Callable(), true).size() == 3)
	check_sound_outside()
	check_equal_paths()
	print("CONDUIT_GRAPH_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

func check_sound_outside() -> void:
	var graph := CountedDucts.new()
	graph.fill({
		"nodes": [[0, 2, 0], [-2, 2, 0], [2, 2, 0], [0, 2, 1]],
		"edges": [[0, 1, 2.0, "duct"], [0, 2, 2.0, "duct"], [0, 3, 1.0, "duct"]],
		"exits": [
			{"node": 2, "room": 2, "kind": "ceiling"},
			{"node": 1, "room": 1, "kind": "ceiling"},
			{"node": 1, "room": 1, "kind": "gap"},
			{"node": 3, "room": 0, "kind": "tile"},
		],
	}, false)
	# The listener's only outlet is a closed tile. The real grilles are tied
	# by air distance and listed in reverse order.
	var listener := Vector3(0, 1.5, 1)
	var room_of := func(_point: Vector3) -> int: return 0
	var route := graph.sound_route(graph.nodes[0], 0, listener, room_of, null)
	check("Sin rejilla propia, el sonido sale por la rejilla más cercana y desempata por nodo",
		route.audible and route.position == graph.nodes[1] and is_equal_approx(route.distance, 2.0))
	check("La ruta sin rejilla propia enumera las salidas una sola vez", graph.mouth_scans == 1)
	check("La lista de rejillas excluye las placas cerradas y omite nodos repetidos",
		graph.mouths_of_all() == PackedInt32Array([2, 1]))

func check_equal_paths() -> void:
	var graph := CountedDucts.new()
	graph.fill({
		"nodes": [[0, 2, 0], [0.1, 2, 0], [0.2, 2, 0]],
		"edges": [[0, 1, 0.1, "duct"], [0, 1, 0.1, "duct"], [1, 2, 0.1, "duct"]],
	}, false)
	var distances := graph.distances_from(0)
	check("Dos caminos del mismo coste solo expanden su destino una vez",
		graph.edge_checks == graph.edges.size() * 2 and is_equal_approx(distances[2], 0.2))
