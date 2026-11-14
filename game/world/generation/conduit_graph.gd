extends RefCounted
## A network of conduits out of the manifest (the pneumatic tubes, her ducts):
## nodes, edges with their lengths, and the mouths sound comes out of. The same
## on every machine. Phase 2's duct_graph.gd extends it (spec_f1_systems 1.5,
## spec_f2_movement 5.1).
const METRES := preload("res://game/world/generation/conduit_metres.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")

## Sound inside: quieter by -20 log10(1 + metres / UNIT), gone past REACH,
## duller along CUTOFF, and LOSS dB for leaving by a mouth.
const UNIT := 6.0
const REACH := 40.0
const CUTOFF := Vector2(6000.0, 1400.0)
const LOSS := -3.0

var nodes := PackedVector3Array()
## Room of each node (-1: none).
var node_rooms := PackedInt32Array()
## [a, b, length, kind].
var edges: Array = []
## Node -> [[other, length, edge]].
var adjacency: Array = []
## {node, room, kind, number, position: Vector3, normal: Vector3}.
var exits: Array = []
## True: sound leaves anywhere along it (tubes); false: only by its exits (ducts).
var radiates := false
## Phase 3: the fans close the ducts to her.
var closed := false

## The body of from_manifest(), as an instance method, so a script that
## extends this one gets an instance of itself.
func fill(data: Dictionary, radiate: bool) -> void:
	radiates = radiate
	nodes = PackedVector3Array()
	node_rooms = PackedInt32Array()
	var tube_rooms: Array = data.get("rooms", [])
	var raw: Array = data.get("nodes", [])
	for i in raw.size():
		var n: Array = raw[i]
		nodes.append(Vector3(float(n[0]), float(n[1]), float(n[2])))
		# Ducts carry their room in the node; tubes in a list beside them.
		node_rooms.append(int(n[3]) if n.size() > 3 else (int(tube_rooms[i]) if i < tube_rooms.size() else -1))
	edges = []
	for e in data.get("edges", []): edges.append([int(e[0]), int(e[1]), float(e[2]), String(e[3])])
	exits = []
	for e in data.get("exits", []):
		var kind := String(e.kind)
		var yaw := float(e.get("yaw", 0.0))
		var normal := Vector3.ZERO
		if kind in ["hub", "station", "wall"]: normal = Vector3(sin(yaw), 0.0, cos(yaw))
		elif kind in ["ceiling", "gap", "duct"]: normal = Vector3.DOWN
		var p: Array = e.get("point", [0, 0, 0])
		exits.append({"node": int(e.get("node", -1)), "room": int(e.get("room", -1)), "kind": kind, "number": int(e.get("number", -1)), "position": Vector3(float(p[0]), float(p[1]), float(p[2])), "normal": normal})
	rebuild()

## The adjacency again from the edges (after a subclass adds some).
func rebuild() -> void:
	adjacency = []
	adjacency.resize(nodes.size())
	for i in nodes.size(): adjacency[i] = []
	for k in edges.size():
		var e: Array = edges[k]
		if int(e[0]) < 0 or int(e[1]) < 0 or int(e[0]) >= nodes.size() or int(e[1]) >= nodes.size(): continue
		adjacency[int(e[0])].append([int(e[1]), float(e[2]), k])
		adjacency[int(e[1])].append([int(e[0]), float(e[2]), k])

static func from_manifest(data: Dictionary, radiate: bool) -> RefCounted:
	var graph = new()
	graph.fill(data, radiate)
	return graph

## Whether an edge is shut to whoever searches it (the base: the whole
## network, by `closed`; duct_graph.gd decides per edge).
func edge_closed(_edge: int) -> bool: return closed

func connected() -> bool:
	if nodes.is_empty(): return true
	var reached := distances_from(0, true)
	for d in reached:
		if d == INF: return false
	return true

## Metres along the conduit from a node to every node (INF: unreachable),
## through closed edges only with ignore_closed.
func distances_from(node: int, ignore_closed := false) -> PackedFloat64Array:
	return search(node, -1, ignore_closed).distance

## The shortest way between two nodes: {path, length}; an empty path when none.
func shortest(from: int, to: int, ignore_closed := false) -> Dictionary:
	var found := search(from, to, ignore_closed)
	if from < 0 or to < 0 or to >= nodes.size() or found.distance[to] == INF: return {"path": PackedInt32Array(), "length": INF}
	var path := PackedInt32Array()
	var n := to
	while n >= 0:
		path.append(n)
		n = found.parent[n]
	path.reverse()
	return {"path": path, "length": found.distance[to]}

## Dijkstra on the instance's own edges (a subclass's added ones included),
## with conduit_metres' heap. {distance, parent}; stops early at `goal`.
func search(from: int, goal: int, ignore_closed: bool) -> Dictionary:
	# Match the heap's precision so a path rounded up in storage cannot be
	# queued again at the same cost through another edge.
	var distance := PackedFloat64Array()
	distance.resize(nodes.size())
	distance.fill(INF)
	var parent := PackedInt32Array()
	parent.resize(nodes.size())
	parent.fill(-1)
	if from < 0 or from >= nodes.size(): return {"distance": distance, "parent": parent}
	distance[from] = 0.0
	var heap: Array = []
	METRES.heap_push(heap, 0.0, from)
	while not heap.is_empty():
		var top: Array = METRES.heap_pop(heap)
		var cost := float(top[0])
		var n := int(top[1])
		if cost > distance[n]: continue
		if n == goal: break
		for link in adjacency[n]:
			if not ignore_closed and edge_closed(int(link[2])): continue
			var next := cost + float(link[1])
			if next < distance[int(link[0])]:
				distance[int(link[0])] = next
				parent[int(link[0])] = n
				METRES.heap_push(heap, next, int(link[0]))
	return {"distance": distance, "parent": parent}

func points_of(path: PackedInt32Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	for n in path: points.append(nodes[n])
	return points

## The point `metres` along a run of points, clamped to its ends.
static func point_along(points: PackedVector3Array, metres: float) -> Vector3:
	if points.is_empty(): return Vector3.ZERO
	var left := maxf(metres, 0.0)
	for i in range(1, points.size()):
		var piece := points[i].distance_to(points[i - 1])
		if left <= piece: return points[i - 1].lerp(points[i], left / maxf(piece, 0.0001))
		left -= piece
	return points[points.size() - 1]

func nearest_node(point: Vector3) -> int:
	var best := -1
	var best_distance := INF
	for i in nodes.size():
		var d := nodes[i].distance_squared_to(point)
		if d < best_distance:
			best_distance = d
			best = i
	return best

## Where sound leaves it in a room: every node there when it radiates (the
## tubes), else the exits' nodes there.
func mouths_in_room(room: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if radiates:
		for i in node_rooms.size():
			if node_rooms[i] == room: out.append(i)
		return out
	for e in exits:
		if int(e.room) == room and int(e.node) >= 0 and sounding(e): out.append(int(e.node))
	return out

## Whether sound goes in and out by an exit (all of them here; duct_graph.gd
## leaves out the closed tiles of a false ceiling).
func sounding(_exit: Dictionary) -> bool: return true

## Exit indices of a room.
func exits_of_room(room: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in exits.size():
		if int(exits[i].room) == room: out.append(i)
	return out

## The `count` exits nearest `from` along the conduit, [{exit, metres}]
## ascending (ties: lower exit index); allow(exit_index) -> bool filters.
func nearest_exits(from: int, count: int, allow := Callable(), ignore_closed := false) -> Array:
	var distance := distances_from(from, ignore_closed)
	var found: Array = []
	for i in exits.size():
		var n := int(exits[i].node)
		if n < 0 or n >= distance.size() or distance[n] == INF: continue
		if allow.is_valid() and not bool(allow.call(i)): continue
		found.append({"exit": i, "metres": distance[n]})
	found.sort_custom(func(a, b): return float(a.metres) < float(b.metres) or (is_equal_approx(float(a.metres), float(b.metres)) and int(a.exit) < int(b.exit)))
	return found.slice(0, count)

## How something travelling inside at `source` (nearest node along it:
## `near_node`) reaches a listener: out of the mouth of the listener's room
## nearest it along the conduit, quieter with every metre inside; with no
## mouth there, out of the mouth nearest the listener within REACH, and then
## by world_audio.route_source(). Shaped like route_source():
## {audible, position, gain, cutoff, echo, distance}.
func sound_route(source: Vector3, near_node: int, listener: Vector3, room_of: Callable, world_audio) -> Dictionary:
	var silent := {"audible": false, "position": source, "gain": -80.0, "cutoff": CUTOFF.y, "echo": false, "distance": INF}
	if FLOOR.planta_of(source.y) != FLOOR.planta_of(listener.y) or near_node < 0: return silent
	var inside := distances_from(near_node)
	var room := int(room_of.call(listener))
	var mouths := mouths_in_room(room)
	var best := -1
	var best_metres := INF
	for m in mouths:
		if inside[m] < best_metres:
			best_metres = inside[m]
			best = m
	var outside := {}
	if best < 0:
		# No mouth in that room: the nearest one to the listener, and on by the air.
		# Enumerate the sounding mouths once. Rebuilding the list for every node
		# made each route from a duct to a room without a grille stall the game.
		var candidates := PackedInt32Array(range(nodes.size())) if radiates else mouths_of_all()
		var nearest := INF
		for i: int in candidates:
			if i >= inside.size() or inside[i] > REACH: continue
			var d := nodes[i].distance_to(listener)
			if d < nearest or (d == nearest and i < best):
				nearest = d
				best = i
		if best < 0: return silent
		best_metres = inside[best]
		if world_audio != null and world_audio.has_method("route_source"): outside = world_audio.route_source(nodes[best], RID(), listener)
		if not outside.is_empty() and not bool(outside.get("audible", false)): return silent
	if best_metres > REACH: return silent
	var share := best_metres / REACH
	var gain := -20.0 * log(1.0 + best_metres / UNIT) / log(10.0) + LOSS + float(outside.get("gain", 0.0))
	return {"audible": true, "position": outside.get("position", nodes[best]), "gain": gain, "cutoff": minf(lerpf(CUTOFF.x, CUTOFF.y, share), float(outside.get("cutoff", CUTOFF.x))), "echo": bool(outside.get("echo", false)), "distance": best_metres + float(outside.get("distance", 0.0))}

## Every exit's node, once.
func mouths_of_all() -> PackedInt32Array:
	var out := PackedInt32Array()
	var seen := {}
	for e in exits:
		var node := int(e.node)
		if node < 0 or seen.has(node) or not sounding(e): continue
		seen[node] = true
		out.append(node)
	return out

## A sound made at `point` (heard `radius` out) reaching somebody inside at
## node `to_node`: in by the mouths of the point's room within `radius` of it,
## and along the conduit. {audible, metres (air plus inside), mouth (exit
## index), apparent (the mouth's position)}; inaudible past REACH inside, from
## another planta, or with no mouth in reach.
func inbound(point: Vector3, radius: float, to_node: int, room_of: Callable) -> Dictionary:
	var silent := {"audible": false, "metres": INF, "mouth": -1, "apparent": point}
	if to_node < 0 or to_node >= nodes.size() or FLOOR.planta_of(point.y) != FLOOR.planta_of(nodes[to_node].y): return silent
	var room := int(room_of.call(point))
	var inside := distances_from(to_node)
	var best := silent
	for i in exits.size():
		var e: Dictionary = exits[i]
		if int(e.room) != room or int(e.node) < 0 or not sounding(e): continue
		var air := (e.position as Vector3).distance_to(point)
		if air > radius or inside[int(e.node)] > REACH: continue
		var total := air + inside[int(e.node)]
		if total < float(best.metres): best = {"audible": true, "metres": total, "mouth": i, "apparent": e.position}
	return best
