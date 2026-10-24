extends "res://game/world/generation/conduit_graph.gd"
## Her ducts (docs/OFICINAS.md 4, Ductos; spec_f2_movement 5.2): the
## manifest's network, the same on every machine, with what only she needs:
## the planta of every node, the kind of every edge she may be seen in, and
## the missing tiles as ways in and out.

## FLOOR.planta_of(y) of each node.
var node_wings := PackedInt32Array()
## The manifest's kind of each node; "gap" for the ones finish() adds.
var node_kinds := PackedStringArray()
## Room -> its trunk or branch node.
var cell_node := {}
## Inside the crawlable main duct she can be seen (1g builds it).
var visible_kinds := ["main", "cross"]
## Per planta: the fans have shut that wing's ducts to her (7.6).
var closed_wings := PackedByteArray([0, 0, 0])

static func of(manifest: Dictionary) -> RefCounted:
	var graph = new()
	graph.fill(manifest.get("ducts", {}), false)
	graph.finish(manifest)
	return graph

## The wings and kinds of the nodes, every room's cell node, and every gap
## whose node is missing or loose hung from its room's cell node by a drop
## (in exit order, so the same on every machine).
func finish(manifest: Dictionary) -> void:
	node_wings = PackedInt32Array()
	node_kinds = PackedStringArray()
	cell_node = {}
	var raw: Array = manifest.get("ducts", {}).get("nodes", [])
	for i in nodes.size():
		node_wings.append(FLOOR.planta_of(nodes[i].y))
		var kind := String(raw[i][4]) if i < raw.size() and raw[i].size() > 4 else ""
		node_kinds.append(kind)
		if kind == "trunk" or kind == "branch": cell_node[node_rooms[i]] = i
	for x in exits.size():
		var e: Dictionary = exits[x]
		if String(e.kind) != "gap": continue
		var node := int(e.node)
		if node >= 0 and node < adjacency.size() and not adjacency[node].is_empty(): continue
		var room := int(e.room)
		if not cell_node.has(room): continue
		var cell := int(cell_node[room])
		var at: Vector3 = e.position
		var added := nodes.size()
		nodes.append(at)
		node_rooms.append(room)
		node_wings.append(FLOOR.planta_of(at.y))
		node_kinds.append("gap")
		adjacency.append([])
		var length := at.distance_to(nodes[cell])
		var edge := edges.size()
		edges.append([added, cell, length, "drop"])
		adjacency[added].append([cell, length, edge])
		adjacency[cell].append([added, length, edge])
		e["node"] = added

## Index into edges of the one between two nodes, -1 if none.
func edge_between(a: int, b: int) -> int:
	if a < 0 or a >= adjacency.size(): return -1
	for link in adjacency[a]:
		if int(link[0]) == b: return int(link[2])
	return -1

func edge_kind(a: int, b: int) -> String:
	var edge := edge_between(a, b)
	return String(edges[edge][3]) if edge >= 0 else ""

## The trunk node of that wing nearest a point in plan (ties: lower index).
func trunk_nearest(point: Vector3, wing: int) -> int:
	var best := -1
	var best_distance := INF
	for i in nodes.size():
		if node_wings[i] != wing or node_kinds[i] != "trunk": continue
		var d := Vector2(nodes[i].x - point.x, nodes[i].z - point.z).length_squared()
		if d < best_distance:
			best_distance = d
			best = i
	return best

## Shut per planta: the fans close the ducts of their wing only.
func edge_closed(edge: int) -> bool:
	if edge < 0 or edge >= edges.size(): return false
	var first := int(edges[edge][0])
	return first >= 0 and first < node_wings.size() and closed_wings[node_wings[first]] != 0
