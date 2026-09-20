extends RefCounted
## Walking with one hand on the wall. From the room it starts in it always
## takes the same-most door available -- for the right hand: right, straight
## on, left, and only then back the way it came. It is the technique that
## solves most mazes without thinking about them, and a wing is laid out so
## that it does not find the refuge.
##
## The walk is exact, not a sample: the state of the walker is the room it is
## in and the way it is facing, so the first state it repeats is the point
## where its path closes into a loop and nothing new can be reached. That is
## why there is no step limit worth arguing about.
##
## It stays in the wing it starts in: the gate into the next one is locked
## while the stage is being played.

## One walk. `hand` is 1 for the right hand and -1 for the left.
static func walk(rooms: Array, adjacency: Array, width: int, height: int, start: int, heading: Vector2i, hand: int, target: int) -> Dictionary:
	var wing: int = int(rooms[start].wing)
	var at := start
	var seen := {start: true}
	var states := {}
	while true:
		if at == target: return {"found": true, "rooms": seen.size()}
		var state := "%d:%d:%d" % [at, heading.x, heading.y]
		if states.has(state): return {"found": false, "rooms": seen.size()}
		states[state] = true
		var side := Vector2i(-heading.y * hand, heading.x * hand)
		var moved := false
		for turn in [side, heading, -side, -heading]:
			var x: int = int(rooms[at].x) + turn.x
			var z: int = int(rooms[at].z) + turn.y
			if x < 0 or x >= width or z < 0 or z >= height: continue
			var next: int = z * width + x
			if int(rooms[next].wing) != wing or bool(rooms[next].get("landing", false)) or not adjacency[at].has(next): continue
			at = next
			heading = turn
			seen[at] = true
			moved = true
			break
		# A room with no doors at all: nothing to follow.
		if not moved: break
	return {"found": at == target, "rooms": seen.size()}

## How many of the eight walks -- both hands, all four ways of setting off --
## get from the entrance of the wing to the target. Zero is a refuge the
## technique does not find whichever way it is tried.
static func hits(rooms: Array, adjacency: Array, width: int, height: int, start: int, target: int) -> int:
	var found := 0
	for hand in [1, -1]:
		for heading in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if bool(walk(rooms, adjacency, width, height, start, heading, hand, target).found): found += 1
	return found

static func reaches(rooms: Array, adjacency: Array, width: int, height: int, start: int, target: int) -> bool:
	return hits(rooms, adjacency, width, height, start, target) > 0

## The best the technique can do: over the eight walks, the fewest rooms any
## of them looks into before stumbling on the target. A walk that never gets
## there counts as the whole wing, so a refuge nothing finds scores highest.
static func cost(rooms: Array, adjacency: Array, width: int, height: int, start: int, target: int, band: int) -> int:
	var worst := band + 1
	for hand in [1, -1]:
		for heading in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var result := walk(rooms, adjacency, width, height, start, heading, hand, target)
			worst = mini(worst, int(result.rooms) if bool(result.found) else band + 1)
	return worst

## The same walk over a finished manifest, for the tools and the tests.
static func follow(data: Dictionary, start: int, target: int, heading := Vector2i(1, 0), hand := 1) -> Dictionary:
	return walk(data.rooms, data.adjacency, int(data.width), int(data.height), start, heading, hand, target)
