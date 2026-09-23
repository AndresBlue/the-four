extends RefCounted
## Routes that go through doors the way a body has to: lined up with the
## doorway, straight through it, and out past the leaf before turning.
##
## The navigation mesh knows nothing of doors -- they move, so they are not
## baked into it -- and its routes hug a jamb at exactly the creature's radius,
## which is where an open leaf stands, 1.2 m into the room. Following such a
## route the creature walked into the wood and stood there; since open leaves
## stopped stopping it (hotel_door.OPEN_SOLID), it would walk through them
## instead. This bends the route round every leaf in its way, so neither
## happens.
##
## For moving only: its hearing and the audio measure the plain route.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const APPROACH := 0.8
## On the side the open leaf stands in, far enough out to clear it: the leaf,
## the creature's radius and a margin.
const LEAF_CLEAR := 1.7
## Through the doorway a little towards the latch: the open leaf narrows the
## hinge side, and down the middle a 0.4 m body clears it by five centimetres.
const LATCH_SHIFT := 0.15
## Round an open leaf: this far past its free end. Past it by less, the
## corner it cuts on reaching the point (hotel_locust.REACHED) took it within
## a hand's width of the wood.
const TIP_CLEAR := 0.9
## A stretch of route that comes nearer a leaf than this brushes it.
const LEAF_MARGIN := 0.5
## A point the walkable floor moves by more than this was inside something.
const SNAP_SLACK := 0.3
## Near a doorway it goes through, the mesh's own corners (hugging the jambs)
## are dropped: this far either side of the wall and this far along it.
const ZONE_DEPTH := 1.25
const ZONE_WIDTH := 1.3
## How far from the middle of a doorway a crossing still goes through it.
const PASS_WIDTH := 0.9
## Already lined up in the doorway: no need to step back out to line up.
const LINED_UP := 0.5

static func depth(door, point: Vector3) -> float:
	return (point - door.doorway).dot(door.across())

static func lateral(door, point: Vector3) -> float:
	return (point - door.doorway).dot(door.along())

## The side of the wall (+1 or -1 along door.across()) its open leaf stands in.
static func leaf_side(door) -> float:
	return signf(depth(door, door.leaf_line(true)[1]))

## How far along a->b the route goes through this doorway, or -1.
static func crossing(door, a: Vector3, b: Vector3) -> float:
	var from := depth(door, a)
	var to := depth(door, b)
	if (from >= 0.0) == (to >= 0.0): return -1.0
	var t := from / (from - to)
	var at := a.lerp(b, t)
	# The same wall carries on past the doorway, and other plantas stack above.
	if absf(lateral(door, at)) > PASS_WIDTH or absf(at.y - door.doorway.y) > 1.5: return -1.0
	return t

## A point lined up with the doorway on `side`, on walkable floor. Brought in
## while it lands inside something; INF when nothing fits.
static func line_up(door, side: float, map: RID, height: float) -> Vector3:
	var reach: float = LEAF_CLEAR if side == leaf_side(door) else APPROACH
	var latch: float = -signf(lateral(door, door.global_position))
	while reach >= APPROACH - 0.01:
		var point: Vector3 = door.doorway + door.across() * (side * reach) + door.along() * (latch * LATCH_SHIFT)
		point.y = height
		var snapped: Vector3 = FLOOR.closest(map, point)
		if Vector2(snapped.x - point.x, snapped.z - point.z).length() <= SNAP_SLACK: return snapped
		reach -= 0.3
	return Vector3.INF

## `route` threaded through each doorway it goes through and bent round every
## open leaf in its way. `doors`: the floor's; `map`: its navigation.
## Returns {"path", "crossings"}: per doorway, in order, {"door", "enter",
## "exit"}, the indices of the points in front of it and past it (-1 when the
## route needed none).
static func thread(route: PackedVector3Array, doors: Array, map: RID) -> Dictionary:
	if route.size() < 2 or doors.is_empty(): return {"path": route, "crossings": []}
	var passes: Array = []
	for i in range(1, route.size()):
		for door in doors:
			if not is_instance_valid(door): continue
			var t := crossing(door, route[i - 1], route[i])
			if t >= 0.0: passes.append([i - 1, t, door])
	passes.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var dropped := {}
	for entry in passes:
		for k in range(1, route.size() - 1):
			if absf(depth(entry[2], route[k])) < ZONE_DEPTH and absf(lateral(entry[2], route[k])) < ZONE_WIDTH: dropped[k] = true
	var path := PackedVector3Array()
	var marks: Array = []
	for k in route.size():
		if not dropped.has(k): path.append(route[k])
		for entry in passes:
			if int(entry[0]) != k: continue
			var door = entry[2]
			var from: Vector3 = path[path.size() - 1]
			var side: float = signf(depth(door, route[k]))
			if side == 0.0: side = -signf(depth(door, route[k + 1]))
			var mark := {"door": door, "enter": Vector3.INF, "exit": Vector3.INF}
			# From right in the doorway it does not step back out to line up.
			var lined: bool = absf(depth(door, from)) < APPROACH + 0.2 and absf(lateral(door, from)) < LINED_UP
			if not lined: mark.enter = line_up(door, side, map, from.y)
			mark.exit = line_up(door, -side, map, from.y)
			if mark.enter != Vector3.INF: path.append(mark.enter)
			if mark.exit != Vector3.INF: path.append(mark.exit)
			marks.append(mark)
	var leaves: Array = []
	for door in doors:
		if not is_instance_valid(door): continue
		if door.opened or marks.any(func(mark): return mark.door == door): leaves.append(door.leaf_line(true))
	path = bend(path, leaves, map)
	var crossings: Array = []
	for mark in marks:
		crossings.append({"door": mark.door, "enter": find_point(path, mark.enter), "exit": find_point(path, mark.exit)})
	return {"path": path, "crossings": crossings}

static func find_point(path: PackedVector3Array, point: Vector3) -> int:
	if point == Vector3.INF: return -1
	for i in path.size():
		if path[i].is_equal_approx(point): return i
	return -1

## Every stretch of the route that brushes an open leaf goes round its free end
## instead: the leaf is a board standing out of the wall, so round its end is
## the only way past it that does not go through it.
static func bend(path: PackedVector3Array, leaves: Array, map: RID) -> PackedVector3Array:
	if leaves.is_empty() or path.size() < 2: return path
	var out := PackedVector3Array([path[0]])
	for i in range(1, path.size()):
		var target: Vector3 = path[i]
		for attempt in 2:
			var from: Vector3 = out[out.size() - 1]
			var leaf = brushed(from, target, leaves)
			if leaf == null: break
			var round_it := round_point(leaf, map, from.y)
			if round_it == Vector3.INF or round_it.distance_to(from) < 0.05: break
			out.append(round_it)
		out.append(target)
	return out

## The leaf a stretch comes too near, the one nearest its start; or null.
static func brushed(a: Vector3, b: Vector3, leaves: Array):
	var best = null
	var nearest := INF
	for leaf in leaves:
		if gap(a, b, leaf[0], leaf[1]) >= LEAF_MARGIN: continue
		var d := Vector2(a.x, a.z).distance_to(Vector2(leaf[1].x, leaf[1].z))
		if d < nearest:
			nearest = d
			best = leaf
	return best

static func round_point(leaf: Array, map: RID, height: float) -> Vector3:
	var hinge: Vector3 = leaf[0]
	var tip: Vector3 = leaf[1]
	var out: Vector3 = tip + (tip - hinge).normalized() * TIP_CLEAR
	out.y = height
	var snapped: Vector3 = FLOOR.closest(map, out)
	if Vector2(snapped.x - out.x, snapped.z - out.z).length() > SNAP_SLACK: return Vector3.INF
	return snapped

## Shortest distance on the floor between segments a-b and c-d.
static func gap(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> float:
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z)
	var r := Vector2(c.x, c.z)
	var s := Vector2(d.x, d.z)
	if segments_cross(p, q, r, s): return 0.0
	return minf(minf(point_gap(p, r, s), point_gap(q, r, s)), minf(point_gap(r, p, q), point_gap(s, p, q)))

static func point_gap(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	var t := 0.0 if span.length_squared() < 0.000001 else clampf((point - a).dot(span) / span.length_squared(), 0.0, 1.0)
	return point.distance_to(a + span * t)

static func segments_cross(p: Vector2, q: Vector2, r: Vector2, s: Vector2) -> bool:
	var one := (q - p).cross(r - p)
	var two := (q - p).cross(s - p)
	var three := (s - r).cross(p - r)
	var four := (s - r).cross(q - r)
	return one * two < 0.0 and three * four < 0.0
