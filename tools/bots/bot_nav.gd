extends RefCounted
## One bot's way somewhere: the walkable route (the navigation mesh, which
## knows nothing of doors), threaded through each doorway the way a body has
## to go through it and bent round every open leaf in its way -- the same
## threading the creature uses (door_threading.gd). A bot collides with open
## leaves as a player does, so a route that hugged the hinge jamb walked it
## into the wood.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const THREAD := preload("res://game/enemies/locust/door_threading.gd")
## A point is reached this near, or once walked past.
const REACHED := 0.3
## A closed door on the route is dealt with from this near its doorway.
const DOOR_NEAR := 1.5
var level
var body
var target := Vector3.INF
var path := PackedVector3Array()
var index := 0
## Per doorway on the route: {door, enter, exit} (indices into path, or -1).
var crossings: Array = []
## Indices of the points that go round a leaf: reached, never cut.
var rounds: Array = []
## How far the route's end falls short of the target, flat metres. More than
## a metre and a half: the target is not where anybody can walk to.
var end_gap := INF
var planned_at := -INF
## The doors whose state the route was threaded against.
var door_states := {}

func _init(owner_level, owner_body) -> void:
	level = owner_level
	body = owner_body

func map() -> RID: return level.get_world_3d().navigation_map

## A route from where the body stands to `to`. False when there is none on
## this planta (the mesh gives nothing across plantas). With `threat`
## (bot_threat.gd) minding the creature: a route that walks into its sight or
## through where it is going is worked out again room by room, round those;
## `blocked` says when there was no way round.
var blocked := false
func plan(to: Vector3, clock: float, threat = null) -> bool:
	target = to
	planned_at = clock
	blocked = false
	var route := FLOOR.navigation_path(map(), body.global_position, to)
	if route.size() < 2:
		clear()
		end_gap = INF
		return false
	if threat != null and threat.near_planta(body.global_position) and risky(route, threat):
		var around := detour(to, threat)
		if around.size() >= 2: route = around
		else: blocked = true
	var near := FLOOR.floor_point(to)
	end_gap = Vector2(route[route.size() - 1].x - near.x, route[route.size() - 1].z - near.z).length()
	var threaded: Dictionary = THREAD.thread(route, level.hotel.doors, map())
	path = threaded.path
	crossings = threaded.crossings
	rounds = threaded.rounds
	index = 1
	door_states.clear()
	for crossing in crossings:
		if is_instance_valid(crossing.door): door_states[crossing.door] = crossing.door.opened
	return true

## Whether a route goes where the creature would see it or is going.
const SEEN_STEP := 2.0
func risky(route: PackedVector3Array, threat) -> bool:
	var rooms: Array = level.manifest.rooms
	for i in range(1, route.size()):
		var from: Vector3 = route[i - 1]
		var leg: float = from.distance_to(route[i])
		var steps := maxi(1, int(leg / SEEN_STEP))
		for s in steps:
			var point := from.lerp(route[i], float(s + 1) / float(steps))
			var id := int(FLOOR.room_at(rooms, point).get("id", -1))
			if id >= 0 and float(threat.danger.get(id, 0.0)) > 0.0: return true
			if point.distance_to(threat.position) < 90.0 and threat.watched(point): return true
	return false

## The way to `to` room by room, each room costing what the creature makes it
## cost (bot_threat.room_cost), through the doorways between them. Empty when
## every way goes where it stands, or the mesh has no leg of it.
func detour(to: Vector3, threat) -> PackedVector3Array:
	var rooms: Array = level.manifest.rooms
	var start := int(FLOOR.room_at(rooms, body.global_position).get("id", -1))
	var goal := int(FLOOR.room_at(rooms, to).get("id", -1))
	if start < 0 or goal < 0: return PackedVector3Array()
	var cost := {start: 0.0}
	var back := {}
	var open: Array = [start]
	var done := {}
	var extra := {}
	while not open.is_empty():
		var current: int = open[0]
		for candidate in open:
			if float(cost[candidate]) < float(cost[current]): current = candidate
		open.erase(current)
		if current == goal: break
		done[current] = true
		for other in level.manifest.adjacency[current]:
			var next := int(other)
			if done.has(next): continue
			if not extra.has(next): extra[next] = threat.room_cost(next) if next != goal else 0.0
			if float(extra[next]) == INF: continue
			var step: float = FLOOR.position_of(rooms[current]).distance_to(FLOOR.position_of(rooms[next])) + float(extra[next])
			if float(cost[current]) + step < float(cost.get(next, INF)):
				cost[next] = float(cost[current]) + step
				back[next] = current
				if not open.has(next): open.append(next)
	if not back.has(goal) and goal != start: return PackedVector3Array()
	var chain: Array = [goal]
	while chain[0] != start: chain.push_front(back[chain[0]])
	var points: Array = [body.global_position]
	for i in range(1, chain.size()):
		var a: Dictionary = rooms[chain[i - 1]]
		var b: Dictionary = rooms[chain[i]]
		var doorway := FLOOR.portal_between(a, b)
		var through := FLOOR.position_of(b) - FLOOR.position_of(a)
		through = Vector3(through.x, 0, through.z).normalized()
		points.append(FLOOR.closest(map(), doorway - through * 0.9))
		points.append(FLOOR.closest(map(), doorway + through * 0.9))
	points.append(to)
	var route := PackedVector3Array()
	for i in range(1, points.size()):
		var leg := FLOOR.navigation_path(map(), points[i - 1], points[i])
		if leg.size() < 2: return PackedVector3Array()
		for k in leg.size():
			if route.size() > 0 and k == 0: continue
			route.append(leg[k])
	return route

func clear() -> void:
	path = PackedVector3Array()
	crossings = []
	rounds = []
	index = 0

func active() -> bool: return index > 0 and index < path.size()

## A door on the route has opened or shut since it was threaded: the way
## round its leaf is another one.
func stale() -> bool:
	for door in door_states:
		if is_instance_valid(door) and not door.moving and door.opened != door_states[door]: return true
	return false

## The flat direction to walk in this frame, moving on past every point
## reached. Zero at the end.
func steer() -> Vector3:
	var at: Vector3 = body.global_position
	while index < path.size():
		var point: Vector3 = path[index]
		var gap := Vector2(point.x - at.x, point.z - at.z)
		if gap.length() < REACHED:
			index += 1
			continue
		# Walked past it (not for a point that goes round a leaf).
		if index > 0 and not rounds.has(index) and index + 1 < path.size():
			var from: Vector3 = path[index - 1]
			var leg := Vector2(point.x - from.x, point.z - from.z)
			if leg.length() > 0.01 and Vector2(at.x - from.x, at.z - from.z).dot(leg) > leg.length_squared():
				index += 1
				continue
		return Vector3(gap.x, 0, gap.y).normalized()
	return Vector3.ZERO

## The next point it is heading for, or the target.
func next_point() -> Vector3:
	return path[index] if active() else target

## Metres of route still to walk.
func remaining() -> float:
	if not active(): return 0.0
	var total := Vector2(path[index].x - body.global_position.x, path[index].z - body.global_position.z).length()
	for i in range(index + 1, path.size()): total += path[i].distance_to(path[i - 1])
	return total

## The first shut door of the route still ahead, when the body is near enough
## to deal with it. Locked doors too: the caller decides.
func door_ahead():
	var at: Vector3 = body.global_position
	for crossing in crossings:
		var door = crossing.door
		if not is_instance_valid(door) or (door.opened and not door.moving): continue
		var past: int = crossing.exit
		if past >= 0 and index > past: continue
		var gap := Vector2(door.doorway.x - at.x, door.doorway.z - at.z).length()
		if gap < DOOR_NEAR and absf(door.doorway.y - at.y) < 1.5: return door
	return null

## Whether a point is on the walkable floor that the rest of its planta is
## on. The mesh keeps a body's radius (0.4 m) off everything and a survivor is
## 0.3 m round, so a body gets into gaps -- behind a bed, between a cupboard
## and the wall -- that are islands of the mesh: no route leaves them.
static func joined(level_ref, point: Vector3) -> bool:
	var planta := FLOOR.planta_of(point.y)
	var entry: Vector3 = FLOOR.position_of(level_ref.manifest.rooms[FLOOR.entry_of(level_ref.manifest, planta)])
	var map: RID = level_ref.get_world_3d().navigation_map
	var route := FLOOR.navigation_path(map, FLOOR.closest(map, entry), point)
	if route.size() < 2: return false
	var near := FLOOR.closest(map, point)
	return Vector2(route[route.size() - 1].x - near.x, route[route.size() - 1].z - near.z).length() < 0.3

## The nearest point of that floor round `point`, within `reach`; INF if none.
static func nearest_joined(level_ref, point: Vector3, reach := 3.0) -> Vector3:
	var map: RID = level_ref.get_world_3d().navigation_map
	for ring in [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]:
		if ring > reach: break
		for step in 12:
			var angle := TAU * float(step) / 12.0
			var candidate := FLOOR.closest(map, point + Vector3(cos(angle), 0, sin(angle)) * float(ring))
			if joined(level_ref, candidate): return candidate
	return Vector3.INF

## Total length of a plain route between two points on one planta, or INF.
static func route_length(level_ref, from: Vector3, to: Vector3) -> float:
	var route := FLOOR.navigation_path(level_ref.get_world_3d().navigation_map, from, to)
	if route.size() < 2: return INF
	var near := FLOOR.floor_point(to)
	if Vector2(route[route.size() - 1].x - near.x, route[route.size() - 1].z - near.z).length() > 1.5: return INF
	var total := 0.0
	for i in range(1, route.size()): total += route[i].distance_to(route[i - 1])
	return total
