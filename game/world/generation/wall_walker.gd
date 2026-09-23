extends RefCounted
## Walking with one hand on the wall. From the room it starts in it always
## takes the same-most door available -- for the right hand: right, straight
## on, left, and only then back the way it came. It is the technique that
## solves most mazes without thinking about them, and a planta is laid out so
## that it does not find the refuge.
##
## The walk is exact, not a sample: the state of the walker is the room it is
## in and the way it is facing, so the first state it repeats is the point
## where its path closes into a loop and nothing new can be reached. That is
## why there is no step limit worth arguing about. (In a plan it goes round
## the edge of one face of the graph of doors: what it can ever see is the
## rooms on the faces round the room it sets off from.)
##
## It stays on the planta it starts on: the lift to the next one is locked
## while the stage is being played.
const HEADINGS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## One walk. `hand` is 1 for the right hand and -1 for the left; `target` -1
## walks until the path closes. Returns {found, rooms (how many it looked
## into), seen (those rooms)}.
static func walk(rooms: Array, adjacency: Array, start: int, heading: Vector2i, hand: int, target: int) -> Dictionary:
	var wing: int = int(rooms[start].wing)
	# Ids run planta after planta, each on its own grid (`cols` by `rows`),
	# offset by where its planta starts.
	var width: int = int(rooms[start].cols)
	var height: int = int(rooms[start].rows)
	var base: int = start - (int(rooms[start].z) * width + int(rooms[start].x))
	var at := start
	var seen := {start: true}
	var states := {}
	while true:
		if at == target: return {"found": true, "rooms": seen.size(), "seen": seen}
		var state: int = at * 9 + (heading.x + 1) * 3 + heading.y + 1
		if states.has(state): return {"found": false, "rooms": seen.size(), "seen": seen}
		states[state] = true
		var side := Vector2i(-heading.y * hand, heading.x * hand)
		var moved := false
		var x0: int = int(rooms[at].x)
		var z0: int = int(rooms[at].z)
		for turn: Vector2i in [side, heading, -side, -heading]:
			var x: int = x0 + turn.x
			var z: int = z0 + turn.y
			if x < 0 or x >= width or z < 0 or z >= height: continue
			var next: int = base + z * width + x
			if not adjacency[at].has(next) or int(rooms[next].wing) != wing or bool(rooms[next].get("landing", false)): continue
			at = next
			heading = turn
			seen[at] = true
			moved = true
			break
		# A room with no doors at all: nothing to follow.
		if not moved: break
	return {"found": at == target, "rooms": seen.size(), "seen": seen}

## The eight walks at once -- both hands, all four ways of setting off -- from
## the entrance of the planta to the target: how many get there (`hits`; zero
## is a refuge the technique does not find whichever way it is tried) and the
## best any of them does (`cost`: the fewest rooms looked into before
## stumbling on it, `band` + 1 if none does).
static func score(rooms: Array, adjacency: Array, start: int, target: int, band: int) -> Dictionary:
	var found := 0
	var best := band + 1
	var done := {}
	for hand in [1, -1]:
		for heading in HEADINGS:
			var key := first_step(rooms, adjacency, start, heading, hand) * 2 + (1 if hand > 0 else 0)
			var result: Dictionary = done[key] if done.has(key) else walk(rooms, adjacency, start, heading, hand, target)
			done[key] = result
			if bool(result.found):
				found += 1
				best = mini(best, int(result.rooms))
	return {"hits": found, "cost": best}

static func hits(rooms: Array, adjacency: Array, start: int, target: int) -> int:
	return int(score(rooms, adjacency, start, target, rooms.size()).hits)

static func reaches(rooms: Array, adjacency: Array, start: int, target: int) -> bool:
	return hits(rooms, adjacency, start, target) > 0

## The best the technique can do: over the eight walks, the fewest rooms any
## of them looks into before stumbling on the target. A walk that never gets
## there counts as the whole planta, so a refuge nothing finds scores highest.
static func cost(rooms: Array, adjacency: Array, start: int, target: int, band: int) -> int:
	return int(score(rooms, adjacency, start, target, band).cost)

## Every room any of the eight walks from `start` ever looks into: a refuge
## whose one door is off all of them is one the technique cannot find.
static func covered(rooms: Array, adjacency: Array, start: int) -> Dictionary:
	var all := {}
	var done := {}
	for hand in [1, -1]:
		for heading in HEADINGS:
			var key := first_step(rooms, adjacency, start, heading, hand) * 2 + (1 if hand > 0 else 0)
			if done.has(key): continue
			done[key] = true
			all.merge(walk(rooms, adjacency, start, heading, hand, -1).seen)
	return all

## Where a walk goes first: two that set off through the same door, facing the
## same way and with the same hand, are the same walk from there on. -1 when
## the room has no door at all.
static func first_step(rooms: Array, adjacency: Array, start: int, heading: Vector2i, hand: int) -> int:
	var width: int = int(rooms[start].cols)
	var height: int = int(rooms[start].rows)
	var x0: int = int(rooms[start].x)
	var z0: int = int(rooms[start].z)
	var base: int = start - (z0 * width + x0)
	var side := Vector2i(-heading.y * hand, heading.x * hand)
	for turn: Vector2i in [side, heading, -side, -heading]:
		var x: int = x0 + turn.x
		var z: int = z0 + turn.y
		if x < 0 or x >= width or z < 0 or z >= height: continue
		var next: int = base + z * width + x
		if not adjacency[start].has(next) or int(rooms[next].wing) != int(rooms[start].wing) or bool(rooms[next].get("landing", false)): continue
		return next * 9 + (turn.x + 1) * 3 + turn.y + 1
	return -1

## The same walk over a finished manifest, for the tools and the tests.
static func follow(data: Dictionary, start: int, target: int, heading := Vector2i(1, 0), hand := 1) -> Dictionary:
	return walk(data.rooms, data.adjacency, start, heading, hand, target)
