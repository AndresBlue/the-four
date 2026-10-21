extends RefCounted
## The emergency-exit signs of the corridors: two to four on the first planta
## and three to six on the others (COUNTS), spread over it, none on the first
## stretch of the way from where the planta is walked into (QUIET), hung across
## the corridor so whoever walks along it reads them face on, each face saying
## which way along the corridors the way out is: ahead,
## to the left, to the right, or back the way you came. Only in corridors (not
## halls, lobbies or rooms), and never pointing into a room: where the way out
## leaves the corridors, the refuge's own sign takes over.
##
## Every sign reads off one tree of ways to the refuge (the shortest walk from
## every room of the planta, keeping to the corridors: going through a room
## costs ROOM_COST times its metres), so following them never goes round in
## circles: each one sends you to a place nearer the way out than the one
## before, and two signs never disagree. A corridor cell is worth a sign by
## how many of those ways pass through it (from every room once, from the way
## into the planta ENTRY_WEIGHT times, which is where everybody starts), more
## where corridors meet than on a corner, more on a corner than on a straight
## stretch. They are chosen to cover the planta: after the first, each next
## one is the best of the rest weighed by how far it is from the ones already
## hung (SPREAD), never nearer than APART (less only where the planta's
## corridors give no room), and not where the refuge is already in sight. A
## planta with more corridor gets more (STEPS).
##
## Deterministic from the manifest alone: every machine hangs the same signs.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## How many, first planta and the others (the author, 20 October 2026): the
## fewest, and one more for every step of corridor cells it reaches, up to the
## most (a quarter of the hotel's plantas have under 33, half under 42, three
## quarters under 50).
const COUNTS := [Vector2i(2, 4), Vector2i(3, 6), Vector2i(3, 6)]
const STEPS := [33, 42, 50]
## None this share of the way out from where the planta is walked into, in
## metres walked: the first of it is found by looking, not by the arrows. The
## first sign used to wait in sight of the door, on the very way out, and the
## first stage was a walk along the arrows.
const QUIET := 0.35
const ROOM_COST := 12.0
const ENTRY_WEIGHT := 20.0
## Straight metres between two signs, the distance past which a candidate is
## no longer held back by the nearest sign already hung, and the least walk
## from a sign to the refuge (closer, its own door and sign are in sight).
const APART := 18.0
const SPREAD := 45.0
const NEAR_REFUGE := 9.0
## What a cell is worth by its shape: corridors meeting, a corner, a stretch.
const MEETING := 1.0
const CORNER := 0.8
const STRAIGHT := 0.5
## What a face shows, in the looker's own terms.
enum Way {AHEAD, LEFT, RIGHT, BACK}
## Types that are circulation, besides corridors and halls: the reception,
## the lift's landing, the lobbies and galleries (map_generator's numbers).
const CIRCULATION := [0, 9, 10, 12]

## [{room, planta, way (Vector2i, the grid way out of that cell), normal
##  (Vector2i: the sign faces along it), front (Way, seen from the normal's
##  side), back (Way, from the other)}], every planta's.
static func place(manifest: Dictionary) -> Array:
	var signs: Array = []
	var refuges: Array = manifest.get("refuges", [])
	for planta in refuges.size(): signs.append_array(planta_signs(manifest, planta))
	return signs

static func circulation(room: Dictionary) -> bool:
	return bool(room.get("corridor", false)) or int(room.get("hall", -1)) >= 0 or int(room.get("type", -1)) in CIRCULATION

## The grid way from one cell to the next, (±1, 0) or (0, ±1), from where
## they stand.
static func way_between(a: Dictionary, b: Dictionary) -> Vector2i:
	var gap := FLOOR.position_of(b) - FLOOR.position_of(a)
	if absf(gap.x) >= absf(gap.z): return Vector2i(signi(int(signf(gap.x))), 0)
	return Vector2i(0, signi(int(signf(gap.z))))

## What `way` is for somebody looking along `forward`.
static func way_for(forward: Vector2i, way: Vector2i) -> int:
	if way == forward: return Way.AHEAD
	if way == -forward: return Way.BACK
	# Their right, with +x east and +z towards them when they face -z.
	var right := Vector2i(-forward.y, forward.x)
	return Way.RIGHT if way == right else Way.LEFT

static func planta_signs(manifest: Dictionary, planta: int) -> Array:
	var rooms: Array = manifest.rooms
	var refuge := int(manifest.refuges[planta])
	var shut := {}
	for gate in manifest.get("gates", []): shut[int(gate.get("beyond", -1))] = true
	var corridor := func(id: int) -> bool: return bool(rooms[id].get("corridor", false))
	var weight := func(id: int) -> float: return 1.0 if id == refuge or circulation(rooms[id]) else ROOM_COST
	# The walk to the refuge from everywhere on the planta, and the next step
	# of it.
	var cost := {refuge: 0.0}
	var next := {}
	var open: Array = [refuge]
	while not open.is_empty():
		var best := 0
		for index in open.size():
			if float(cost[open[index]]) < float(cost[open[best]]): best = index
		var at: int = open[best]
		open.remove_at(best)
		for other in manifest.adjacency[at]:
			var id := int(other)
			if shut.has(id) or FLOOR.is_void(rooms[id]) or int(rooms[id].get("wing", -1)) != planta: continue
			var step: float = FLOOR.position_of(rooms[at]).distance_to(FLOOR.position_of(rooms[id])) * maxf(weight.call(at), weight.call(id))
			var total: float = float(cost[at]) + step
			if not cost.has(id):
				open.append(id)
				cost[id] = total
				next[id] = at
			elif total < float(cost[id]) - 0.001:
				cost[id] = total
				next[id] = at
	# The corridor cells a sign can hang in: the way out goes on along a
	# corridor from them (never into a room), and what shape they are.
	var shape := {}
	var corridors := 0
	for id in cost:
		if corridor.call(id): corridors += 1
		if id == refuge or not corridor.call(id) or not corridor.call(int(next[id])): continue
		var axes := {}
		var ways := 0
		for other in manifest.adjacency[id]:
			if not cost.has(int(other)) or not corridor.call(int(other)): continue
			ways += 1
			axes[way_between(rooms[id], rooms[int(other)]).x != 0] = true
		shape[id] = MEETING if ways >= 3 else CORNER if axes.size() == 2 else STRAIGHT
	# A planta mostly of rooms opening on to rooms has few of those: there, a
	# corridor whose way out goes on into a lobby, a gallery or a hall (open
	# ground, never a room) will do as well, for less.
	var counts: Vector2i = COUNTS[mini(planta, COUNTS.size() - 1)]
	if shape.size() < counts.x * 3:
		for id in cost:
			if id == refuge or shape.has(id) or not corridor.call(id): continue
			var on: int = int(next[id])
			if on != refuge and circulation(rooms[on]): shape[id] = STRAIGHT * 0.5
	# How much of the planta's way out passes through each, and along which
	# corridor it comes in.
	var entry := FLOOR.entry_of(manifest, planta)
	var flow := {}
	var arriving := {}
	for id in cost:
		if id == refuge: continue
		var amount: float = ENTRY_WEIGHT if id == entry else 1.0
		var came := -1
		var at: int = id
		var guard := 0
		while at != refuge and guard < 400:
			guard += 1
			if shape.has(at):
				flow[at] = float(flow.get(at, 0.0)) + amount * float(shape[at])
				if came >= 0 and corridor.call(came):
					var axis := "x" if way_between(rooms[at], rooms[came]).x != 0 else "z"
					if not arriving.has(at): arriving[at] = {"x": 0.0, "z": 0.0}
					arriving[at][axis] = float(arriving[at][axis]) + amount
			came = at
			at = int(next[at])
	var chosen_count := counts.x
	for step in STEPS:
		if corridors >= int(step): chosen_count += 1
	chosen_count = mini(chosen_count, counts.y)
	# The first stretch of the way out, walked from the way in, stays bare.
	var walked := FLOOR.route_metres(manifest, entry)
	var bare := QUIET * float(walked.get(refuge, 0.0))
	var signs: Array = []
	# A planta with little corridor may have too few places past the bare
	# stretch: then it is shortened, by half and then altogether, for the
	# signs it is short of its fewest and no more.
	for quiet in [bare, bare * 0.5, 0.0]:
		if signs.size() >= counts.x: break
		pick_signs(manifest, signs, chosen_count if quiet == bare else counts.x, flow, cost, walked, quiet, next, arriving, planta)
	return signs

## Signs added to `signs`, up to `wanted`: the best of the rest by how much of
## the way out passes there and how far from the ones already hung; none
## within NEAR_REFUGE of the refuge or nearer the way in than `quiet` metres.
static func pick_signs(manifest: Dictionary, signs: Array, wanted: int, flow: Dictionary, cost: Dictionary, walked: Dictionary, quiet: float, next: Dictionary, arriving: Dictionary, planta: int) -> void:
	var rooms: Array = manifest.rooms
	var most := 0.0
	for id in flow: most = maxf(most, float(flow[id]))
	for apart in [APART, APART * 0.7, APART * 0.45]:
		while signs.size() < wanted:
			var pick := -1
			var pick_score := -1.0
			for id in flow:
				if float(cost[id]) < NEAR_REFUGE or float(walked.get(id, INF)) < quiet or signs.any(func(sign): return int(sign.room) == id): continue
				var here := FLOOR.position_of(rooms[id])
				var nearest := INF
				for sign in signs: nearest = minf(nearest, FLOOR.position_of(rooms[int(sign.room)]).distance_to(here))
				if nearest < apart: continue
				var score: float = float(flow[id]) / maxf(most, 0.001) * clampf(nearest / SPREAD, 0.1, 1.0)
				if score > pick_score or (score == pick_score and id < pick):
					pick = id
					pick_score = score
			if pick < 0: break
			signs.append(sign_at(manifest, pick, next, arriving, planta))

## The sign of one cell: which way out along the corridor, and which way it
## hangs -- across the corridor people come along to it: the one most of its
## traffic arrives by, or, with none (ways that start here), the one the way
## out goes along.
static func sign_at(manifest: Dictionary, id: int, next: Dictionary, arriving: Dictionary, planta: int) -> Dictionary:
	var rooms: Array = manifest.rooms
	var way := way_between(rooms[id], rooms[int(next[id])])
	var sides: Dictionary = arriving.get(id, {"x": 0.0, "z": 0.0})
	var along := Vector2i(absi(way.x), absi(way.y))
	var normal := along
	if float(sides.x) > float(sides.z): normal = Vector2i(1, 0)
	elif float(sides.z) > float(sides.x): normal = Vector2i(0, 1)
	return {"room": id, "planta": planta, "way": way, "normal": normal,
		"front": way_for(-normal, way), "back": way_for(normal, way)}
