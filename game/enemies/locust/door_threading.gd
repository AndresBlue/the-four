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
## A stretch of route that goes round the free end of a leaf nearer than
## this goes round it wider.
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
## Returns {"path", "crossings", "rounds"}: per doorway, in order, {"door",
## "enter", "exit"}, the indices of the points in front of it and past it (-1
## when the route needed none); and the indices of the points that go round a
## leaf, which have to be reached and not cut (hotel_locust.advance_path).
static func thread(route: PackedVector3Array, doors: Array, map: RID) -> Dictionary:
	if route.size() < 2 or doors.is_empty(): return {"path": route, "crossings": [], "rounds": []}
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
	# Only the leaves of its own planta: the plantas share their plan, and an
	# open door straight overhead bent the route round a board that is not
	# there (it went back and forth under it for good).
	var planta := FLOOR.planta_of(route[0].y)
	var leaves: Array = []
	for door in doors:
		if not is_instance_valid(door) or FLOOR.planta_of(door.doorway.y) != planta: continue
		if door.opened or marks.any(func(mark): return mark.door == door): leaves.append(door.leaf_line(true))
	var rounds: Array = []
	path = bend(path, leaves, map, rounds)
	var crossings: Array = []
	for mark in marks:
		crossings.append({"door": mark.door, "enter": find_point(path, mark.enter), "exit": find_point(path, mark.exit)})
	return {"path": path, "crossings": crossings, "rounds": rounds}

static func find_point(path: PackedVector3Array, point: Vector3) -> int:
	if point == Vector3.INF: return -1
	for i in path.size():
		if path[i].is_equal_approx(point): return i
	return -1

## Every stretch of the route that brushes an open leaf goes round its free end
## instead: the leaf is a board standing out of the wall, so round its end is
## the only way past it that does not go through it.
static func bend(path: PackedVector3Array, leaves: Array, map: RID, rounds: Array = []) -> PackedVector3Array:
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
			rounds.append(out.size())
			out.append(round_it)
		out.append(target)
	return out

## The leaf a stretch goes through, the one nearest its start; or null.
static func brushed(a: Vector3, b: Vector3, leaves: Array):
	var best = null
	var nearest := INF
	for leaf in leaves:
		if not crosses(a, b, leaf): continue
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

## Whether a stretch goes from one side of a leaf to the other through the
## board, or round its free end by less than LEAF_MARGIN. One that stays on
## one side does not go through it, however near it passes: counted as
## brushing it, a creature that had already turned the end of a leaf and was
## behind it was sent back out round the end, and in again, for good.
static func crosses(a: Vector3, b: Vector3, leaf: Array) -> bool:
	var hinge := Vector2(leaf[0].x, leaf[0].z)
	var board := Vector2(leaf[1].x, leaf[1].z) - hinge
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z)
	var from := board.cross(p - hinge)
	var to := board.cross(q - hinge)
	if from * to > 0.0 or absf(from - to) < 0.000001: return false
	var hit := p + (q - p) * (from / (from - to))
	var along := (hit - hinge).dot(board) / board.length_squared()
	return along >= 0.0 and along <= 1.0 + LEAF_MARGIN / board.length()
