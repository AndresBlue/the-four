extends SceneTree
## The conduit graph (game/world/generation/conduit_graph.gd, spec_f1_systems
## 1.5 and spec_f2_movement 5.1) on the manifests of two floors: the tube tree
## and the duct network connected, the way from the window's hub to every
## station as long as the generator measured it, the nearest exits in order,
## and a closed network shut to a search but not to one that ignores it.
const GEN := preload("res://game/world/generation/office_generator.gd")
const GRAPH := preload("res://game/world/generation/conduit_graph.gd")
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
	print("CONDUIT_GRAPH_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)
