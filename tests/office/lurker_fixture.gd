extends RefCounted
## The Lurker's test plan and stand-ins (spec_f2_movement 11.1): one row of
## four cells on planta 0 (a despacho, a corridor, an archive, an
## off-limits room) with two duct exits and one aisle, and a level, a hotel
## and doors that are plain objects, read by lurker_routes.gd and
## lurker_motion.gd by duck typing. Shared by lurker_shell_test.gd and
## lurker_motion_test.gd.
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const ROUTES := preload("res://game/enemies/lurker/lurker_routes.gd")
const DUCTS := preload("res://game/enemies/lurker/duct_graph.gd")

class StubDoor extends RefCounted:
	signal swung(target: bool, slow: bool, forceful: bool)
	signal settled(opened: bool)
	var opened := true
	var moving := false
	var locked := false
	var hinge := Vector3.ZERO
	func leaf_line(_open := true) -> Array: return [hinge, hinge + Vector3.RIGHT]
	## Shut as a real door tells it: the signal first, then the state.
	func shut() -> void:
		swung.emit(false, false, false)
		opened = false

class StubHotel extends RefCounted:
	var lit_rooms := {}
	var doors := {}
	func lit(room: int) -> bool: return lit_rooms.has(room)
	func get_node_or_null(path): return doors.get(String(path))

class StubLevel extends RefCounted:
	var manifest := {}
	var hotel
	var objectives := {}
	func objective(id: StringName): return objectives.get(String(id))
	func tuning() -> Dictionary: return {}

## The fans' stand-in: shut or not.
class StubAir extends RefCounted:
	var shut := false
	var hatch_open := true
	func ducts_closed() -> bool: return shut

static func fixture(merge := false) -> Dictionary:
	var table := [[0, 3, 0.0, 8.0, [[1, 0.0]]], [1, 11, 5.2, 2.4, [[0, 0.0], [2, 1.0]]], [2, 6, 11.4, 10.0, [[1, 1.0], [3, 0.0]]], [3, 19, 20.4, 8.0, [[2, 0.0]]]]
	var rooms: Array = []
	for row in table:
		rooms.append({"id": row[0], "x": row[0], "z": 0, "cols": 4, "rows": 1, "wing": 0, "py": 0.0, "pz": 0.0, "span_z": 8.0, "height": 2.95, "open_sides": [],
			"type": row[1], "px": row[2], "span_x": row[3], "doors": row[4], "hides": [], "furniture": []})
	var m := {"floor": 2, "plenum": OFFICE.PLENUM.duplicate(true), "rooms": rooms, "edges": [[0, 1], [1, 2], [2, 3]], "adjacency": [[1], [0, 2], [1, 3], [2]], "merged": [], "entries": [0], "seed": 1}
	var n3 := Vector3(-1.5, 2.95, 1.5)
	var n4 := Vector3(11.4, 0.35, 3.91)
	m["ducts"] = {"nodes": [[0.0, 3.7, 0.0, 0, "branch"], [5.2, 3.7, 0.0, 1, "trunk"], [11.4, 3.7, 0.0, 2, "branch"], [n3.x, n3.y, n3.z, 0, "exit"], [n4.x, n4.y, n4.z, 2, "exit"]],
		"edges": [[0, 1, 5.2, "branch"], [1, 2, 6.2, "branch"], [3, 0, n3.distance_to(Vector3(0, 3.7, 0)), "drop"], [4, 2, n4.distance_to(Vector3(11.4, 3.7, 0)), "drop"]],
		"exits": [{"node": 3, "room": 0, "kind": "ceiling", "point": [n3.x, n3.y, n3.z], "yaw": 0.0}, {"node": 4, "room": 2, "kind": "wall", "point": [n4.x, n4.y, n4.z], "yaw": PI}]}
	m["archives"] = [{"rooms": [2], "axis": "x", "mobile": false, "spine": [6.75, -0.8, 16.05, 0.8], "aisles": [[8.0, 0.8, 9.0, 3.85]]}]
	if merge:
		m.merged = [[0, 1]]
		rooms[0].open_sides = ["east"]
		rooms[1].open_sides = ["west"]
		rooms[0].doors = []
		rooms[1].doors = [[2, 1.0]]
	return m

## A stub level on a manifest with a door node for every edge that is not
## merged, its hinge 0.65 m to the -z (or -x) side of the doorway.
static func stub_level(m: Dictionary) -> StubLevel:
	var lvl := StubLevel.new()
	lvl.manifest = m
	lvl.hotel = StubHotel.new()
	var merged := {}
	for pair in m.get("merged", []): merged[ROUTES.key_of(int(pair[0]), int(pair[1]))] = true
	for edge in m.edges:
		if merged.has(ROUTES.key_of(int(edge[0]), int(edge[1]))): continue
		var door := StubDoor.new()
		var at: Vector3 = FLOOR.portal_between(m.rooms[int(edge[0])], m.rooms[int(edge[1])])
		var across_x: bool = int(m.rooms[int(edge[0])].x) != int(m.rooms[int(edge[1])].x)
		door.hinge = at + (Vector3(0, 0, -0.65) if across_x else Vector3(-0.65, 0, 0))
		lvl.hotel.doors["Door_%d_%d" % [int(edge[0]), int(edge[1])]] = door
	return lvl

static func routes_on(m: Dictionary, lvl: StubLevel):
	var routes = ROUTES.new()
	routes.setup(lvl, SHELL.build(m), DUCTS.of(m), true)
	return routes
