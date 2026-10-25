extends RefCounted
## How she gets from where she is to where she is going on her planta
## (docs/OFICINAS.md 11.4): rooms, the open sides of halls, the doors that are
## open now, her duct exits and the ducts, searched with A* on what it costs
## her (dark rooms cheap, lit ones dear, the zones the team powered dearer
## still, off-limits rooms not there at all), and laid out as legs she can
## follow: up the band at a door, across a ceiling, down to the next door or
## into a grille. She never opens a door: one that shuts on her route sends her
## another way (spec_f2_movement 6). The level, its hotel and its doors are
## read by duck typing, so a stub stands in for them in the tests.
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const METRES := preload("res://game/world/generation/conduit_metres.gd")

## What plans are timed at on surfaces (the clip's 1.0 m/s x 1.35).
const CRAWL_SPEED := 1.35
## A lit room's metres cost this many times a dark one's.
const LIT_FACTOR := 6.0
## A room the team powered, on the board or by a minutero (wing 1).
const POWER_FACTOR := 25.0
## Seconds for going through a doorway, into a grille and out of one.
const PORTAL_COST := 0.5
const ENTER_COST := 1.5
const LEAVE_COST := 1.5
## Seconds between re-costings while on surfaces (lights change).
const REPLAN_EVERY := 2.0
## A door she gave up waiting at is left out this long.
const BAN_TIME := 10.0
## Share of the walk from the planta's entry where she comes out after a
## planta transit.
const ARRIVE_BAND := Vector2(0.5, 0.9)
## Seconds added to an exit straight towards a threat (flee_exit()).
const FLEE_TOWARD := 8.0
## In the visible main duct she goes at this at every difficulty (the author,
## 23 October 2026), under the survivors' crawl.
const MAIN_DUCT_SPEED := 1.0
## Through a door she keeps this far from the band's middle, away from the
## hinge, so her hands miss the open leaf.
const DOOR_SIDE := 0.25
## How far past the main duct's crossing, towards the shaft, every crawler
## must be before she comes in through it: a body's length.
const CROSS_CLEAR := 1.0
## Back into the ceiling by a tile she left open this near her (the author:
## "si entra de nuevo por ahí que la cierre de vuelta").
const TILE_REUSE := 2.5
## A crossing of an open side keeps this far inside both ceilings' ends
## along it: on a corner of one, the way on ran out of it by its wall and she
## stood there (seed 7, 228 to 220, corridors meeting in an L).
const CROSS_IN := 0.1

enum Edge { OPEN, DOOR, IN, OUT, DUCT }

var level
var shell
var ducts
## Off the main duct (the difficulty's, 1.2 to 2.4).
var duct_speed := 1.6
## Bumped by every door signal and whenever door_signature() changes.
var door_epoch := 0
## The last pair a door signal shut, and the physics frame of it (7.3).
var last_shut := Vector2i(-1, -1)
var shut_frame := -1
var manifest: Dictionary = {}
var rooms: Array = []
## Rooms are nodes 0..R-1, duct node k is R + k.
var room_count := 0
## Node -> [[to, kind, metres_a, metres_b, room_a, room_b, key]].
var graph: Array = []
var positions := PackedVector3Array()
var node_wings := PackedInt32Array()
## Vector2i(min, max) -> its door node (null where none was found).
var door_nodes := {}
var merged := {}
## Vector2i -> seconds left.
var bans := {}
var connections: Array = []
var missing_reported := {}
## A missing door node is an error of the floor; a test that makes one on
## purpose turns the message off and reads missing_reported.
var report_missing := true
var signature_frame := -1
var signatures := {}
var last_signature := {}
var travel_cache := {}
var walk_cache := {}
## The main duct (planta 3): its crossing node as a graph node, the cross edge
## into it from her ducts, its line from the hatch and how far along that line
## the crossing is; -1 and empty on a floor without one.
var main_cross := -1
var cross_edge := -1
var main_line := PackedVector3Array()
var cross_along := INF
## A survivor crawls in the main between the hatch and the crossing: she does
## not come in through it (the author's I10: only behind the last crawler,
## whoever drives her). Read every tick().
var cross_shut := false

func setup(source_level, source_shell, source_ducts, watch_doors: bool) -> void:
	teardown()
	level = source_level
	shell = source_shell
	ducts = source_ducts
	manifest = level.manifest
	rooms = manifest.get("rooms", [])
	room_count = rooms.size()
	merged = {}
	for pair in manifest.get("merged", []): merged[key_of(int(pair[0]), int(pair[1]))] = true
	var count: int = room_count + ducts.nodes.size()
	graph = []
	graph.resize(count)
	positions = PackedVector3Array()
	positions.resize(count)
	node_wings = PackedInt32Array()
	node_wings.resize(count)
	for n in count: graph[n] = []
	for room in rooms:
		var id := int(room.id)
		node_wings[id] = int(room.get("wing", -1))
		if shell.tray_of.has(id): positions[id] = shell.anchor_of(centre_state(id))
	for k in ducts.nodes.size():
		positions[room_count + k] = ducts.nodes[k]
		node_wings[room_count + k] = int(ducts.node_wings[k])
	add_open_edges()
	add_door_edges()
	add_exit_edges()
	for k in ducts.edges.size():
		var e: Array = ducts.edges[k]
		var a := room_count + int(e[0])
		var b := room_count + int(e[1])
		graph[a].append([b, Edge.DUCT, float(e[2]), 0.0, -1, -1, k])
		graph[b].append([a, Edge.DUCT, float(e[2]), 0.0, -1, -1, k])
	read_main()
	door_nodes = {}
	var hotel = level.hotel
	for edge in manifest.get("edges", []):
		var pair := key_of(int(edge[0]), int(edge[1]))
		if merged.has(pair) or door_nodes.has(pair): continue
		var door = null
		if hotel != null:
			door = hotel.get_node_or_null("Door_%d_%d" % [int(edge[0]), int(edge[1])])
			if door == null: door = hotel.get_node_or_null("Door_%d_%d" % [int(edge[1]), int(edge[0])])
		door_nodes[pair] = door
		if watch_doors and door != null:
			var on_swung := _on_swung.bind(pair)
			var on_settled := _on_settled.bind(pair)
			door.swung.connect(on_swung)
			door.settled.connect(on_settled)
			connections.append([door, on_swung, on_settled])

func read_main() -> void:
	main_cross = -1
	cross_edge = -1
	main_line = PackedVector3Array()
	cross_along = INF
	cross_shut = false
	var main: Dictionary = manifest.get("air", {}).get("main", {})
	if main.is_empty() or int(main.get("cross", -1)) < 0: return
	for k in ducts.edges.size():
		if String(ducts.edges[k][3]) == "cross": cross_edge = k
	if cross_edge < 0: return
	main_cross = room_count + int(main.cross)
	for n in main.nodes: main_line.append(ducts.nodes[int(n)])
	cross_along = along_main(ducts.nodes[int(main.cross)])

## How far along the main duct from the hatch a point is, in plan.
func along_main(point: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var best := INF
	var best_along := 0.0
	var run := 0.0
	for i in range(1, main_line.size()):
		var a := Vector2(main_line[i - 1].x, main_line[i - 1].z)
		var b := Vector2(main_line[i].x, main_line[i].z)
		var piece := a.distance_to(b)
		var t := clampf((p - a).dot(b - a) / (piece * piece), 0.0, 1.0) if piece > 0.0 else 0.0
		var d := p.distance_to(a.lerp(b, t))
		if d < best:
			best = d
			best_along = run + t * piece
		run += piece
	return best_along

## Whether somebody crawling in the main has not yet got CROSS_CLEAR past the
## crossing towards the shaft.
func crawler_before_cross() -> bool:
	if main_cross < 0 or not level.has_method("survivors") or not level.has_method("crawling_at"): return false
	for body in level.survivors():
		if not is_instance_valid(body) or not level.crawling_at(body.global_position): continue
		if along_main(body.global_position) < cross_along + CROSS_CLEAR: return true
	return false

## The cross edge taken into the main while it is shut to her.
func cross_barred(link: Array) -> bool:
	return cross_shut and int(link[6]) == cross_edge and int(link[0]) == main_cross

## Lets go of every door signal (lurker.gd calls it on leaving the tree and
## before a rebuild).
func teardown() -> void:
	for c in connections:
		var door = c[0]
		if not is_instance_valid(door): continue
		if door.swung.is_connected(c[1]): door.swung.disconnect(c[1])
		if door.settled.is_connected(c[2]): door.settled.disconnect(c[2])
	connections = []

static func key_of(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))

func _on_swung(target: bool, _slow: bool, _forceful: bool, pair: Vector2i) -> void:
	door_epoch += 1
	if not target:
		last_shut = pair
		shut_frame = Engine.get_physics_frames()

func _on_settled(_opened: bool, _pair: Vector2i) -> void:
	door_epoch += 1

# --- The graph ------------------------------------------------------------------

func centre_state(room: int):
	var r: Dictionary = rooms[room]
	return shell.tray_state(room, float(r.px), float(r.pz), SHELL.DEFAULT_HANG)

func plan_point(room: int) -> Vector2:
	var r: Dictionary = rooms[room]
	var s = centre_state(room)
	return Vector2(s.u, s.v) if s != null else Vector2(float(r.px), float(r.pz))

## Where two cells beside each other meet: the middle of their shared edge
## and its span along it, [point, lo, hi, along_x].
func shared_edge(a: int, b: int) -> Array:
	var ra: Dictionary = rooms[a]
	var rb: Dictionary = rooms[b]
	var ca := Vector2(float(ra.px), float(ra.pz))
	var cb := Vector2(float(rb.px), float(rb.pz))
	var ha := FLOOR.size_of(ra) * 0.5
	var hb := FLOOR.size_of(rb) * 0.5
	if int(ra.x) != int(rb.x):
		var x := ca.x + signf(cb.x - ca.x) * ha.x
		var lo := maxf(ca.y - ha.y, cb.y - hb.y)
		var hi := minf(ca.y + ha.y, cb.y + hb.y)
		return [Vector2(x, (lo + hi) / 2.0), lo, hi, false]
	var z := ca.y + signf(cb.y - ca.y) * ha.y
	var lo := maxf(ca.x - ha.x, cb.x - hb.x)
	var hi := minf(ca.x + ha.x, cb.x + hb.x)
	return [Vector2((lo + hi) / 2.0, z), lo, hi, true]

func add_open_edges() -> void:
	for pair in merged:
		var a: int = pair.x
		var b: int = pair.y
		if not shell.tray_of.has(a) or not shell.tray_of.has(b): continue
		if not shell.patches[int(shell.tray_of[a])].open.values().has(b): continue
		var middle: Vector2 = shared_edge(a, b)[0]
		var ma := plan_point(a).distance_to(middle)
		var mb := middle.distance_to(plan_point(b))
		graph[a].append([b, Edge.OPEN, ma, mb, a, b, pair])
		graph[b].append([a, Edge.OPEN, mb, ma, b, a, pair])

func add_door_edges() -> void:
	for pair in shell.band_of_pair:
		var band: int = shell.band_of_pair[pair]
		var record: Dictionary = shell.patches[band]
		var a := int(record.rooms[0])
		var b := int(record.rooms[1])
		var half: float = record.profile.length / 2.0
		var k0: Vector3 = shell.anchor_of(shell.band_start(band, a))
		var k5: Vector3 = shell.anchor_of(shell.band_start(band, b))
		var ma := plan_point(a).distance_to(Vector2(k0.x, k0.z)) + half
		var mb := half + Vector2(k5.x, k5.z).distance_to(plan_point(b))
		graph[a].append([b, Edge.DOOR, ma, mb, a, b, pair])
		graph[b].append([a, Edge.DOOR, mb, ma, b, a, pair])

## The tray point a non-wall exit is entered from, and for a wall exit its
## band; [plan point, band or -1].
func exit_way(e: int) -> Array:
	var ex: Dictionary = ducts.exits[e]
	if String(ex.kind) == "wall" and shell.wall_band_of_exit.has(e):
		var band: int = shell.wall_band_of_exit[e]
		var k0: Vector3 = shell.anchor_of(shell.band_start(band, int(ex.room)))
		return [Vector2(k0.x, k0.z), band]
	var at: Vector3 = ex.position
	var s = shell.tray_state(int(ex.room), at.x, at.z)
	return [Vector2(s.u, s.v), -1]

## The anchor she squeezes from or to at an exit.
func exit_anchor(e: int) -> Vector3:
	var ex: Dictionary = ducts.exits[e]
	var way := exit_way(e)
	if int(way[1]) >= 0:
		var band := int(way[1])
		var end = shell.band_start(band, int(ex.room))
		end.u = shell.patches[band].profile.length
		return shell.anchor_of(end)
	return shell.anchor_of(shell.tray_state(int(ex.room), (way[0] as Vector2).x, (way[0] as Vector2).y))

func add_exit_edges() -> void:
	for e in ducts.exits.size():
		var ex: Dictionary = ducts.exits[e]
		var room := int(ex.room)
		var node := int(ex.node)
		if node < 0 or not shell.tray_of.has(room): continue
		var way := exit_way(e)
		var metres := plan_point(room).distance_to(way[0]) + exit_anchor(e).distance_to(ex.position)
		if int(way[1]) >= 0: metres += float(shell.patches[int(way[1])].profile.length)
		graph[room].append([room_count + node, Edge.IN, metres, 0.0, room, room, e])
		graph[room_count + node].append([room, Edge.OUT, 0.0, metres, room, room, e])

# --- Doors, rooms and exits ---------------------------------------------------------

## Open sides only from the manifest's merged pairs; a door only when its
## node says opened, not moving and not locked; with no node, shut (and one
## error for the session).
func door_open(pair: Vector2i) -> bool:
	if merged.has(pair): return true
	var door = door_nodes.get(pair)
	if door == null or not is_instance_valid(door):
		if not missing_reported.has(pair):
			missing_reported[pair] = true
			if report_missing: push_error("lurker_routes: no door node for %d:%d" % [pair.x, pair.y])
		return false
	return bool(door.opened) and not bool(door.moving) and not bool(door.locked)

## A hash of every door of a wing as it stands, once per physics frame; a
## change bumps door_epoch even when no signal came (set_state(), locks).
func door_signature(wing: int) -> int:
	var frame := Engine.get_physics_frames()
	if frame == signature_frame and signatures.has(wing): return int(signatures[wing])
	if frame != signature_frame:
		signature_frame = frame
		signatures = {}
	var state: Array = []
	for pair in door_nodes:
		if int(rooms[pair.x].get("wing", -1)) != wing: continue
		var door = door_nodes[pair]
		if door == null or not is_instance_valid(door): state.append(-1)
		else: state.append(int(bool(door.opened)) + 2 * int(bool(door.moving)) + 4 * int(bool(door.locked)))
	var h := hash(state)
	signatures[wing] = h
	if last_signature.has(wing) and int(last_signature[wing]) != h: door_epoch += 1
	last_signature[wing] = h
	return h

func herds(room: int) -> bool:
	var power = level.objective(&"power") if level.has_method("objective") else null
	return power != null and power.has_method("herds") and bool(power.herds(room))

func room_factor(room: int) -> float:
	if herds(room): return POWER_FACTOR
	if level.hotel != null and bool(level.hotel.lit(room)): return LIT_FACTOR
	return 1.0

## A hatch only while the air objective has it open (she never opens it).
func exit_usable(e: int) -> bool:
	if String(ducts.exits[e].kind) != "hatch": return true
	var air = level.objective(&"air") if level.has_method("objective") else null
	return air == null or bool(air.get("hatch_open"))

## Her speed along a duct edge of that kind.
func segment_speed(kind: String) -> float:
	return MAIN_DUCT_SPEED if ducts.visible_kinds.has(kind) else duct_speed

func ban(pair: Vector2i, seconds: float) -> void:
	bans[pair] = maxf(seconds, float(bans.get(pair, 0.0)))

func tick(delta: float) -> void:
	cross_shut = crawler_before_cross()
	for pair in bans.keys():
		bans[pair] = float(bans[pair]) - delta
		if float(bans[pair]) <= 0.0: bans.erase(pair)

# --- The search -----------------------------------------------------------------

## Whether an edge may be taken now, and what it costs in seconds (INF: not).
## `factors` by room; `escape` lets duct edges of a closed wing through (she
## is getting out of it, 7.6).
func edge_cost(link: Array, factors: PackedFloat32Array, escape: bool) -> float:
	match int(link[1]):
		Edge.OPEN:
			return (float(link[2]) * factors[int(link[4])] + float(link[3]) * factors[int(link[5])]) / CRAWL_SPEED
		Edge.DOOR:
			if bans.has(link[6]) or not door_open(link[6]): return INF
			return (float(link[2]) * factors[int(link[4])] + float(link[3]) * factors[int(link[5])]) / CRAWL_SPEED + PORTAL_COST
		Edge.IN:
			var node := int(link[0]) - room_count
			if not exit_usable(int(link[6])) or ducts.closed_wings[ducts.node_wings[node]] != 0: return INF
			return float(link[2]) * factors[int(link[4])] / CRAWL_SPEED + ENTER_COST
		Edge.OUT:
			if not exit_usable(int(link[6])): return INF
			return LEAVE_COST + float(link[3]) * factors[int(link[5])] / CRAWL_SPEED
	var edge := int(link[6])
	if not escape and ducts.edge_closed(edge): return INF
	if cross_barred(link): return INF
	return float(link[2]) / segment_speed(String(ducts.edges[edge][3]))

## Plain metres of an edge, for travel_metres() (INF where shut).
func edge_metres(link: Array) -> float:
	match int(link[1]):
		Edge.OPEN:
			return float(link[2]) + float(link[3])
		Edge.DOOR:
			return float(link[2]) + float(link[3]) if door_open(link[6]) else INF
		Edge.IN:
			var node := int(link[0]) - room_count
			if not exit_usable(int(link[6])) or ducts.closed_wings[ducts.node_wings[node]] != 0: return INF
			return float(link[2])
		Edge.OUT:
			return float(link[3]) if exit_usable(int(link[6])) else INF
	return INF if ducts.edge_closed(int(link[6])) or cross_barred(link) else float(link[2])

func factors_for(wing: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(room_count)
	out.fill(1.0)
	for room in rooms:
		if int(room.get("wing", -1)) == wing and shell.tray_of.has(int(room.id)): out[int(room.id)] = room_factor(int(room.id))
	return out

## The search's starting nodes as {node: seconds}.
func start_nodes(start: Dictionary) -> Dictionary:
	if start.has("duct"):
		var ends: Array = start.duct
		var metres: Array = start.get("metres", [0.0, 0.0])
		var kind: String = ducts.edge_kind(int(ends[0]), int(ends[1]))
		var speed := segment_speed(kind)
		return {room_count + int(ends[0]): float(metres[0]) / speed, room_count + int(ends[1]): float(metres[1]) / speed}
	return {int(start.get("room", -1)): 0.0}

func wing_of_start(start: Dictionary) -> int:
	if start.has("duct"): return int(ducts.node_wings[int(start.duct[0])])
	var room := int(start.get("room", -1))
	return int(rooms[room].get("wing", -1)) if room >= 0 and room < room_count else -1

## A* (or Dijkstra with no goal) by cost from the start: {g, parent, via}
## (via: the edge record each node was reached by).
func search(start: Dictionary, goal_node: int, factors: PackedFloat32Array) -> Dictionary:
	var count := graph.size()
	var g := PackedFloat64Array()
	g.resize(count)
	g.fill(INF)
	var parent := PackedInt32Array()
	parent.resize(count)
	parent.fill(-1)
	var via: Array = []
	via.resize(count)
	var wing := wing_of_start(start)
	var escape: bool = start.has("duct") and ducts.closed_wings[wing] != 0
	var fastest := maxf(CRAWL_SPEED, maxf(duct_speed, MAIN_DUCT_SPEED))
	var target: Vector3 = positions[goal_node] if goal_node >= 0 else Vector3.ZERO
	var heap: Array = []
	var firsts := start_nodes(start)
	var keys: Array = firsts.keys()
	keys.sort()
	for n in keys:
		if n < 0 or n >= count: continue
		g[n] = float(firsts[n])
		METRES.heap_push(heap, g[n] + (positions[n].distance_to(target) / fastest if goal_node >= 0 else 0.0), n)
	while not heap.is_empty():
		var top: Array = METRES.heap_pop(heap)
		var n := int(top[1])
		var h := positions[n].distance_to(target) / fastest if goal_node >= 0 else 0.0
		if float(top[0]) > g[n] + h + 1e-6: continue
		if n == goal_node: break
		for link in graph[n]:
			var to := int(link[0])
			if node_wings[to] != wing: continue
			var cost := edge_cost(link, factors, escape)
			if cost == INF: continue
			var next := g[n] + cost
			if next < g[to] - 1e-9:
				g[to] = next
				parent[to] = n
				via[to] = link
				METRES.heap_push(heap, next + (positions[to].distance_to(target) / fastest if goal_node >= 0 else 0.0), to)
	return {"g": g, "parent": parent, "via": via}

## start: {"room": r} on a surface, or {"duct": [a, b], "metres": [ma, mb],
## "point": p} in a duct (a, b the ends of her segment, ma, mb the conduit
## metres from p to each). goal: {"room": r, "point": p (optional)} or
## {"exit": e, "mouth": bool (optional)}. {ok, cost, nodes, legs, pairs, why}.
func plan(start: Dictionary, goal: Dictionary, from_state = null, from_point := Vector3.INF) -> Dictionary:
	var failed := {"ok": false, "cost": INF, "nodes": PackedInt32Array(), "legs": [], "pairs": [], "why": ""}
	var wing := wing_of_start(start)
	if wing < 0:
		failed.why = "start"
		return failed
	var goal_node := -1
	if goal.has("exit"):
		var e := int(goal.exit)
		if e < 0 or e >= ducts.exits.size() or int(ducts.exits[e].node) < 0:
			failed.why = "exit"
			return failed
		goal_node = room_count + int(ducts.exits[e].node)
	else:
		goal_node = int(goal.get("room", -1))
		if goal_node < 0 or goal_node >= room_count or not shell.tray_of.has(goal_node):
			failed.why = "room"
			return failed
	if node_wings[goal_node] != wing:
		failed.why = "wing"
		return failed
	var found := search(start, goal_node, factors_for(wing))
	if float(found.g[goal_node]) == INF:
		failed.why = "unreachable"
		return failed
	var path := PackedInt32Array()
	var links: Array = []
	var n := goal_node
	while n >= 0:
		path.append(n)
		links.append(found.via[n])
		n = int(found.parent[n])
	path.reverse()
	links.reverse()
	var pairs: Array = []
	for link in links:
		if link != null and int(link[1]) == Edge.DOOR: pairs.append(link[6])
	return {"ok": true, "cost": float(found.g[goal_node]), "nodes": path, "legs": legs_of(start, goal, path, links, from_state, from_point), "pairs": pairs, "why": ""}

## The cost of a node path as it stands now (replanning compares it).
func path_cost(start: Dictionary, path: PackedInt32Array) -> float:
	if path.is_empty(): return INF
	var factors := factors_for(wing_of_start(start))
	var firsts := start_nodes(start)
	var total := float(firsts.get(path[0], INF))
	var escape: bool = start.has("duct") and ducts.closed_wings[wing_of_start(start)] != 0
	for i in range(1, path.size()):
		var best := INF
		for link in graph[path[i - 1]]:
			if int(link[0]) == path[i]: best = minf(best, edge_cost(link, factors, escape))
		total += best
	return total

# --- Legs -----------------------------------------------------------------------------

## v at a door: DOOR_SIDE off the middle, away from the hinge (0 with no node).
func door_v(band: int) -> float:
	var record: Dictionary = shell.patches[band]
	var door = door_nodes.get(record.pair)
	if door == null or not is_instance_valid(door) or not door.has_method("leaf_line"): return 0.0
	var hinge: Vector3 = door.leaf_line()[0]
	var side := (hinge - (record.origin as Vector3)).dot(record.axis)
	return -signf(side) * DOOR_SIDE if absf(side) > 1e-6 else 0.0

## Tray legs from `from` to `to` through the rooms of `chain` (crossing the
## open sides where the straight line meets them).
func tray_legs(legs: Array, from: Vector2, to: Vector2, chain: Array, hang: float) -> void:
	var at := from
	for i in range(1, chain.size()):
		var edge := shared_edge(int(chain[i - 1]), int(chain[i]))
		var lo: float = float(edge[1]) + SHELL.TRAY_INSET
		var hi: float = float(edge[2]) - SHELL.TRAY_INSET
		var middle: Vector2 = edge[0]
		var cross: Vector2
		if bool(edge[3]):
			var t := (middle.y - at.y) / (to.y - at.y) if absf(to.y - at.y) > 1e-9 else 0.5
			cross = Vector2(clampf(at.x + (to.x - at.x) * t, lo, hi), middle.y)
		else:
			var t := (middle.x - at.x) / (to.x - at.x) if absf(to.x - at.x) > 1e-9 else 0.5
			cross = Vector2(middle.x, clampf(at.y + (to.y - at.y) * t, lo, hi))
		# Inside both ceilings: their walled ends keep further in than the edge's.
		var ra: Rect2 = shell.patches[int(shell.tray_of[int(chain[i - 1])])].rect
		var rb: Rect2 = shell.patches[int(shell.tray_of[int(chain[i])])].rect
		if bool(edge[3]): cross.x = inside(cross.x, maxf(ra.position.x, rb.position.x), minf(ra.end.x, rb.end.x))
		else: cross.y = inside(cross.y, maxf(ra.position.y, rb.position.y), minf(ra.end.y, rb.end.y))
		legs.append({"kind": "tray", "to": cross, "room": int(chain[i]), "hang": NAN})
		at = cross
	legs.append({"kind": "tray", "to": to, "room": int(chain[chain.size() - 1]), "hang": hang})

## `value` kept CROSS_IN inside low..high (their middle when that is shorter
## than twice CROSS_IN).
static func inside(value: float, low: float, high: float) -> float:
	if high - low <= 2.0 * CROSS_IN: return (low + high) * 0.5
	return clampf(value, low + CROSS_IN, high - CROSS_IN)

## The duct points of a run of duct nodes (6.4 rule 5): main and cross
## segments on the duct's floor, and where one meets the network a vertical
## step, of the lowered side's kind, so the leg never jumps. A start inside
## a duct begins at her point, on a segment of `first_kind`; a way out by a
## tile ends at it (`last_point`), over the plenum.
func duct_leg(nodes_run: PackedInt32Array, first_point: Vector3, first_kind := "", last_point := Vector3.INF) -> Dictionary:
	var lower := float(manifest.get("plenum", OFFICE.PLENUM).get("main", OFFICE.PLENUM.main)) / 2.0 - 0.02
	var points := PackedVector3Array()
	var kinds := PackedStringArray()
	if first_point != Vector3.INF:
		points.append(first_point)
		var at: Vector3 = ducts.nodes[nodes_run[0]]
		points.append(at - Vector3.UP * lower if ducts.visible_kinds.has(first_kind) else at)
		kinds.append(first_kind)
	for i in range(1, nodes_run.size()):
		var kind: String = ducts.edge_kind(nodes_run[i - 1], nodes_run[i])
		var low: bool = ducts.visible_kinds.has(kind)
		var a: Vector3 = ducts.nodes[nodes_run[i - 1]]
		var b: Vector3 = ducts.nodes[nodes_run[i]]
		if low:
			a -= Vector3.UP * lower
			b -= Vector3.UP * lower
		if points.is_empty():
			points.append(a)
		elif not points[points.size() - 1].is_equal_approx(a):
			kinds.append(kind if low else kinds[kinds.size() - 1])
			points.append(a)
		points.append(b)
		kinds.append(kind)
	if last_point != Vector3.INF:
		if points.is_empty(): points.append(ducts.nodes[nodes_run[0]])
		points.append(last_point)
		kinds.append("plenum")
	var length := 0.0
	for i in range(1, points.size()): length += points[i].distance_to(points[i - 1])
	return {"kind": "duct", "nodes": nodes_run, "points": points, "kinds": kinds, "length": length}

func squeeze(from: Vector3, to: Vector3, into: bool, e: int, basis: Basis) -> Dictionary:
	return {"kind": "squeeze", "from": from, "to": to, "into": into, "exit": e, "basis": basis}

## The tile she goes through by a tile exit (spec_f3_aggression): going in,
## the nearest her (one she left open near her first); coming out, the
## nearest where she is going. [tile, its point at the ceiling, its plan
## point on the tray].
func tile_way(e: int, near: Vector3, going_in: bool) -> Array:
	var room := int(ducts.exits[e].room)
	var tile: Vector2i = ducts.tile_near(room, near, TILE_REUSE if going_in else 0.0)
	var through: Vector3 = ducts.tile_point(room, tile)
	var s = shell.tray_state(room, through.x, through.z)
	return [tile, through, Vector2(s.u, s.v)]

## The basis of a tray State at a plan point heading along `toward`.
func tray_basis(room: int, at: Vector2, toward: Vector2) -> Basis:
	var s = shell.tray_state(room, at.x, at.y)
	if toward.length() > 1e-6: shell.set_heading(s, Vector3(toward.x, 0, toward.y))
	return shell.transform_of(s).basis

func legs_of(start: Dictionary, goal: Dictionary, path: PackedInt32Array, links: Array, from_state, from_point: Vector3) -> Array:
	var legs: Array = []
	var at := Vector2.INF
	var chain: Array = []
	var run := PackedInt32Array()
	var run_first := Vector3.INF
	var run_kind := ""
	if start.has("duct"):
		run.append(path[0] - room_count)
		run_first = start.get("point", Vector3.INF)
		run_kind = ducts.edge_kind(int(start.duct[0]), int(start.duct[1]))
	else:
		var room := int(start.room)
		chain = [room]
		at = plan_point(room)
		if from_state != null and from_state.patch >= 0:
			var record: Dictionary = shell.patches[from_state.patch]
			if int(record.kind) == SHELL.Kind.BAND:
				var toward_a: bool = int(record.rooms[0]) == room
				legs.append({"kind": "band", "patch": from_state.patch, "dir": -1 if toward_a else 1, "v": from_state.v})
				var end = shell.band_start(from_state.patch, room, from_state.v)
				var p: Vector3 = shell.anchor_of(end)
				at = Vector2(p.x, p.z)
			elif int(record.kind) == SHELL.Kind.CHANNEL:
				legs.append({"kind": "channel", "patch": from_state.patch, "v_to": 0.0, "u_goal": float(record.profile.length) / 2.0})
				var p: Vector3 = shell.anchor_of(shell.channel_mouth(from_state.patch))
				at = Vector2(p.x, p.z)
			else:
				at = Vector2(from_state.u, from_state.v)
		elif from_point != Vector3.INF:
			var s = shell.tray_state(room, from_point.x, from_point.z)
			at = Vector2(s.u, s.v)
	for i in range(1, path.size()):
		var link: Array = links[i]
		match int(link[1]):
			Edge.OPEN:
				chain.append(int(link[0]))
			Edge.DOOR:
				var band: int = shell.band_of_pair[link[6]]
				var from_room := int(link[4])
				var v := door_v(band)
				var begin: Vector3 = shell.anchor_of(shell.band_start(band, from_room, v))
				tray_legs(legs, at, Vector2(begin.x, begin.z), chain, SHELL.BAND_CLEAR)
				var record: Dictionary = shell.patches[band]
				legs.append({"kind": "band", "patch": band, "dir": 1 if from_room == int(record.rooms[0]) else -1, "v": v})
				var end: Vector3 = shell.anchor_of(shell.band_start(band, int(link[5]), v))
				at = Vector2(end.x, end.z)
				chain = [int(link[5])]
			Edge.IN:
				var e := int(link[6])
				var ex: Dictionary = ducts.exits[e]
				var way := exit_way(e)
				var target: Vector2 = way[0]
				var by_tile: bool = String(ex.kind) == "tile"
				var tile_at: Array = tile_way(e, Vector3(at.x, 0, at.y), true) if by_tile else []
				if by_tile: target = tile_at[2]
				var toward: Vector2 = target - at
				tray_legs(legs, at, target, chain, SHELL.BAND_CLEAR)
				var basis: Basis
				if int(way[1]) >= 0:
					var band := int(way[1])
					legs.append({"kind": "band", "patch": band, "dir": 1, "v": 0.0})
					var bottom = shell.band_start(band, int(ex.room))
					bottom.u = float(shell.patches[band].profile.length)
					basis = shell.transform_of(bottom).basis
				else:
					basis = tray_basis(int(ex.room), target, toward)
				if by_tile:
					var into := squeeze(shell.anchor_of(shell.tray_state(int(ex.room), target.x, target.y)), tile_at[1], true, e, basis)
					into["room"] = int(ex.room)
					into["tile"] = tile_at[0]
					legs.append(into)
				else: legs.append(squeeze(exit_anchor(e), ex.position, true, e, basis))
				run = PackedInt32Array([int(link[0]) - room_count])
				run_first = tile_at[1] if by_tile else Vector3.INF
				if by_tile: run_kind = "plenum"
				chain = []
			Edge.DUCT:
				run.append(int(link[0]) - room_count)
			Edge.OUT:
				var e := int(link[6])
				var ex: Dictionary = ducts.exits[e]
				var room := int(ex.room)
				var tile_at: Array = []
				if String(ex.kind) == "tile":
					# Out where she is going: the goal's point in this room, else
					# the next room's middle.
					var aim: Vector3 = positions[path[i + 1]] if i + 1 < path.size() else positions[room]
					if i + 1 >= path.size() and goal.has("point"): aim = goal.point
					tile_at = tile_way(e, aim, false)
				var last: Vector3 = tile_at[1] if not tile_at.is_empty() else Vector3.INF
				if run.size() > 1 or run_first != Vector3.INF or last != Vector3.INF: legs.append(duct_leg(run, run_first, run_kind, last))
				run = PackedInt32Array()
				run_first = Vector3.INF
				var way := exit_way(e)
				if not tile_at.is_empty():
					var plan_at: Vector2 = tile_at[2]
					var out := squeeze(tile_at[1], shell.anchor_of(shell.tray_state(room, plan_at.x, plan_at.y)), false, e, tray_basis(room, plan_at, Vector2.ZERO))
					out["room"] = room
					out["tile"] = tile_at[0]
					legs.append(out)
				elif int(way[1]) >= 0:
					var band := int(way[1])
					var bottom = shell.band_start(band, room)
					bottom.u = float(shell.patches[band].profile.length)
					bottom.heading = PI
					legs.append(squeeze(ex.position, shell.anchor_of(bottom), false, e, shell.transform_of(bottom).basis))
					legs.append({"kind": "band", "patch": band, "dir": -1, "v": 0.0})
				else:
					legs.append(squeeze(ex.position, exit_anchor(e), false, e, tray_basis(room, way[0], Vector2.ZERO)))
				at = way[0] if tile_at.is_empty() else tile_at[2]
				chain = [room]
	# Into an exit: the squeeze in, then (from inside) the duct to its node,
	# which is the mouth, so "mouth" stops at the same place.
	if run.size() > 1 or run_first != Vector3.INF: legs.append(duct_leg(run, run_first, run_kind))
	if goal.has("exit"): return legs
	var room := int(goal.room)
	var to: Vector2
	if goal.has("point"):
		var p: Vector3 = goal.point
		var s = shell.tray_state(room, p.x, p.z)
		to = Vector2(s.u, s.v)
	else:
		to = shell.clear_point(room, float(rooms[room].px), float(rooms[room].pz))
	if chain.is_empty(): chain = [room]
	tray_legs(legs, at, to, chain, NAN)
	return legs

# --- What other parts ask ---------------------------------------------------------------

## Plain metres from a room to every room of its planta (the director, every
## tick): cached while the wing's doors and the fans stay as they were.
func travel_metres(room: int) -> Dictionary:
	if room < 0 or room >= room_count or not shell.tray_of.has(room): return {}
	var wing := int(rooms[room].get("wing", -1))
	var key := [door_signature(wing), door_epoch, Array(ducts.closed_wings), cross_shut]
	if travel_cache.has(room) and travel_cache[room][0] == key: return travel_cache[room][1]
	var count := graph.size()
	var metres := PackedFloat64Array()
	metres.resize(count)
	metres.fill(INF)
	metres[room] = 0.0
	var heap: Array = []
	METRES.heap_push(heap, 0.0, room)
	while not heap.is_empty():
		var top: Array = METRES.heap_pop(heap)
		var n := int(top[1])
		if float(top[0]) > metres[n] + 1e-9: continue
		for link in graph[n]:
			var to := int(link[0])
			if node_wings[to] != wing: continue
			var step := edge_metres(link)
			if step == INF: continue
			if metres[n] + step < metres[to] - 1e-9:
				metres[to] = metres[n] + step
				METRES.heap_push(heap, metres[to], to)
	var out := {}
	for r in room_count:
		if metres[r] < INF: out[r] = metres[r]
	travel_cache[room] = [key, out]
	return out

## The cost of going into each exit from the start (INF: none), by exit.
func exit_costs(start: Dictionary) -> PackedFloat64Array:
	var wing := wing_of_start(start)
	var factors := factors_for(wing)
	var found := search(start, -1, factors)
	var out := PackedFloat64Array()
	out.resize(ducts.exits.size())
	out.fill(INF)
	for e in ducts.exits.size():
		var ex: Dictionary = ducts.exits[e]
		var node := int(ex.node)
		if node < 0 or int(ducts.node_wings[node]) != wing or not exit_usable(e): continue
		if start.has("duct"):
			out[e] = float(found.g[room_count + node])
			continue
		var room := int(ex.room)
		if room < 0 or room >= room_count or float(found.g[room]) == INF: continue
		for link in graph[room]:
			if int(link[1]) == Edge.IN and int(link[6]) == e:
				out[e] = float(found.g[room]) + edge_cost(link, factors, false)
	return out

func nearest_exit(start: Dictionary) -> int:
	var costs := exit_costs(start)
	var best := -1
	for e in costs.size():
		if costs[e] < INF and (best < 0 or costs[e] < costs[best]): best = e
	return best

## 2b's flight after a scare: the cheapest exit, those straight towards the
## threat dearer.
func flee_exit(start: Dictionary, threat: Vector3, from_point: Vector3) -> int:
	var costs := exit_costs(start)
	var away := threat - from_point
	var best := -1
	var best_cost := INF
	for e in costs.size():
		if costs[e] == INF: continue
		# A tile is the one over her: never towards anybody.
		var to: Vector3 = (ducts.exits[e].position as Vector3) - from_point if String(ducts.exits[e].kind) != "tile" else Vector3.ZERO
		var cosine := 0.0
		if to.length() > 1e-6 and away.length() > 1e-6: cosine = to.normalized().dot(away.normalized())
		var cost := costs[e] + FLEE_TOWARD * maxf(0.0, cosine)
		if cost < best_cost:
			best_cost = cost
			best = e
	return best

## Where she comes out after coming down to a planta: an exit of a room
## between half and nine tenths of the walk from its entry, weighted by that
## share; none there, the farthest room's.
func arrival_exit(wing: int, rng: RandomNumberGenerator) -> int:
	if not walk_cache.has(wing): walk_cache[wing] = FLOOR.route_metres(manifest, FLOOR.entry_of(manifest, wing))
	var walk: Dictionary = walk_cache[wing]
	var top := 0.0
	for r in walk:
		if shell.tray_of.has(int(r)) and int(rooms[int(r)].get("wing", -1)) == wing: top = maxf(top, float(walk[r]))
	if top <= 0.0: return -1
	var chosen: Array = []
	var weights: Array = []
	var far := -1
	var far_walk := -1.0
	for e in ducts.exits.size():
		var ex: Dictionary = ducts.exits[e]
		if not String(ex.kind) in ["ceiling", "wall", "duct", "gap"]: continue
		var room := int(ex.room)
		if int(ex.node) < 0 or not walk.has(room) or not shell.tray_of.has(room) or int(rooms[room].get("wing", -1)) != wing: continue
		var share := float(walk[room]) / top
		if float(walk[room]) > far_walk:
			far_walk = float(walk[room])
			far = e
		if share >= ARRIVE_BAND.x and share <= ARRIVE_BAND.y:
			chosen.append(e)
			weights.append(share)
	if chosen.is_empty(): return far
	var total := 0.0
	for w in weights: total += float(w)
	var pick := rng.randf() * total
	for i in chosen.size():
		pick -= float(weights[i])
		if pick <= 0.0: return int(chosen[i])
	return int(chosen[chosen.size() - 1])
