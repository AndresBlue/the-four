extends "res://game/world/generation/conduit_graph.gd"
## Her ducts (docs/OFICINAS.md 4, Ductos; spec_f2_movement 5.2): the
## manifest's network, the same on every machine, with what only she needs:
## the planta of every node, the kind of every edge she may be seen in, the
## missing tiles as ways in and out, and the plenum over every false ceiling
## with any of its tiles a way in and out (spec_f3_aggression).
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")

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
## Room -> its plenum node, the tiles she may go through there and its
## ceiling's height (add_plenum()).
var plenum_node := {}
var room_tiles := {}
var tile_height := {}
## Room -> the tiles she left half open there (lurker.gd keeps it).
var open_tiles := {}

## `with_plenum` false: the ducts alone, for the tests of what they do.
static func of(manifest: Dictionary, with_plenum := true) -> RefCounted:
	var graph = new()
	graph.fill(manifest.get("ducts", {}), false)
	graph.finish(manifest, with_plenum)
	return graph

## The wings and kinds of the nodes, every room's cell node, and every gap
## whose node is missing or loose hung from its room's cell node by a drop
## (in exit order, so the same on every machine).
func finish(manifest: Dictionary, with_plenum := true) -> void:
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
		var added := add_node(e.position, room, "gap")
		link(added, int(cell_node[room]), "drop")
		e["node"] = added
	if with_plenum: add_plenum(manifest)

## Any whole tile of a false ceiling is her way in and out (the author, 24
## October 2026). Per room with one, but the off-limits: a node over its free
## tile nearest its middle, kind "plenum", hung from the room's cell node and
## from the plenum nodes of the rooms it has a door or an open side to on its
## planta, and one exit of kind "tile" there. Which of its tiles she takes is
## chosen as she goes (lurker_routes.gd, tile_near()). The tiles are the ones
## a grille or a gap may take (OFFICE.free_tiles()) but theirs.
func add_plenum(manifest: Dictionary) -> void:
	plenum_node = {}
	room_tiles = {}
	tile_height = {}
	open_tiles = {}
	var taken := {}
	for e in exits:
		if String(e.kind) in ["ceiling", "gap"]: taken[OFFICE.tile_of(e.position)] = true
	for room in manifest.get("rooms", []):
		if FLOOR.is_void(room) or not OFFICE.false_ceiling(room) or OFFICE.off_limits(room): continue
		var free: Array = OFFICE.free_tiles(room).filter(func(t): return not taken.has(t))
		if free.is_empty(): continue
		var id := int(room.id)
		var height := float(room.py) + OFFICE.height_of(room)
		room_tiles[id] = free
		tile_height[id] = height
		var middle: Vector2i = tile_near(id, Vector3(float(room.px), height, float(room.pz)))
		var at := OFFICE.tile_centre(middle, height)
		var node := add_node(at, id, "plenum")
		plenum_node[id] = node
		if cell_node.has(id): link(node, int(cell_node[id]), "plenum")
		exits.append({"node": node, "room": id, "kind": "tile", "number": -1, "position": at, "normal": Vector3.DOWN})
	for pair in manifest.get("edges", []) + manifest.get("merged", []):
		var a := int(pair[0])
		var b := int(pair[1])
		if not plenum_node.has(a) or not plenum_node.has(b): continue
		var na := int(plenum_node[a])
		var nb := int(plenum_node[b])
		if node_wings[na] == node_wings[nb] and edge_between(na, nb) < 0: link(na, nb, "plenum")

## A node of hers the manifest has not got; its index.
func add_node(at: Vector3, room: int, kind: String) -> int:
	nodes.append(at)
	node_rooms.append(room)
	node_wings.append(FLOOR.planta_of(at.y))
	node_kinds.append(kind)
	adjacency.append([])
	return nodes.size() - 1

func link(a: int, b: int, kind: String) -> void:
	var length := nodes[a].distance_to(nodes[b])
	var edge := edges.size()
	edges.append([a, b, length, kind])
	adjacency[a].append([b, length, edge])
	adjacency[b].append([a, length, edge])

## The tile of a room she goes through nearest a point: of those she left
## open there, the nearest within `reuse` metres first (she goes back in by
## it); NO_TILE with none (the lattice's own run below zero).
const NO_TILE := Vector2i(-1048576, -1048576)
func tile_near(room: int, point: Vector3, reuse := 0.0) -> Vector2i:
	var flat := Vector2(point.x, point.z)
	var best := NO_TILE
	var best_d := INF
	for tile in open_tiles.get(room, []):
		var d := flat.distance_to(tile_flat(tile))
		if d <= reuse and d < best_d:
			best_d = d
			best = tile
	if best != NO_TILE: return best
	for tile in room_tiles.get(room, []):
		var d := flat.distance_to(tile_flat(tile))
		if d < best_d:
			best_d = d
			best = tile
	return best

## Where she goes through a tile: its middle, at its ceiling.
func tile_point(room: int, tile: Vector2i) -> Vector3:
	return OFFICE.tile_centre(tile, float(tile_height.get(room, 0.0)))

static func tile_flat(tile: Vector2i) -> Vector2:
	var at := OFFICE.tile_centre(tile, 0.0)
	return Vector2(at.x, at.z)

## A closed tile lets no sound through (the false ceiling's own exits do).
func sounding(exit: Dictionary) -> bool: return String(exit.kind) != "tile"

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
