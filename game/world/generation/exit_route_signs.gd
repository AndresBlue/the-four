extends RefCounted
## The emergency-exit signs of the corridors: four to six per planta, hung at
## the junctions where most of the planta's ways to its refuge make a choice,
## each one saying which of its ways leads out -- ahead, left, right, or back
## the way you came.
##
## Every sign reads off one tree of ways to the refuge (the shortest walk from
## every room of the planta, through the corridors: going through a room costs
## ROOM_COST times its metres), so following them never goes round in circles:
## each one sends you to a place nearer the way out than the one before, and two
## signs never disagree. Which junctions get one is decided by how many of those
## ways pass through them and choose there -- from every room once, and from the
## way into the planta ENTRY_WEIGHT times, which is where everybody starts --
## kept APART metres from each other and not where the refuge is already in
## sight. More junctions that matter, more signs: a small planta of few
## corridors has four, a big one six (SIGN_PER).
##
## The sign hangs across the way most of that traffic arrives by, so it is read
## face on by whoever comes that way; each face says where the way out is for
## somebody looking at it: ahead, to their left, to their right, or back.
##
## Deterministic from the manifest alone: every machine hangs the same signs.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const FEWEST := 4
const MOST := 6
## A planta gets one more sign than FEWEST for every this many junctions its
## ways out choose at, past the first SIGN_BASE.
const SIGN_BASE := 8
const SIGN_PER := 5
const ROOM_COST := 3.0
const ENTRY_WEIGHT := 30.0
## Straight metres between two signs, and the least walk from a sign to the
## refuge (closer, its own door and its own sign are in sight).
const APART := 16.0
const NEAR_REFUGE := 9.0
## What a corridor's door the way out leaves by is worth, against a junction
## of corridors.
const LEAVING := 0.6
const CORNER := 0.35
const STRAIGHT := 0.05
## Where a planta has too few places apart enough, the spacing it settles for.
const APART_LEAST := 10.0
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
	# Where a way out makes a choice: a cell of the circulation (a corridor,
	# a gallery, a lobby, a hall, the landing the lift lets out at) where ways
	# meet (three or more along the circulation), where the way out leaves it
	# by one door of several, or where it turns a corner. Plantas that are
	# mostly rooms opening on to rooms have few of the first. The others
	# count for less.
	var junction := {}
	for id in cost:
		var room: Dictionary = rooms[id]
		if not circulation(room) or id == refuge: continue
		var ways := 0
		var doors := 0
		var axes := {}
		for other in manifest.adjacency[id]:
			if not cost.has(int(other)): continue
			doors += 1
			if int(other) == refuge or circulation(rooms[int(other)]):
				ways += 1
				axes[way_between(room, rooms[int(other)]).x != 0] = true
		if ways >= 3: junction[id] = 1.0
		elif doors >= 3 and not circulation(rooms[int(next[id])]): junction[id] = LEAVING
		# A corner: no choice, but the one place a turn is seen coming.
		elif ways == 2 and axes.size() == 2: junction[id] = CORNER
		# A straight stretch: only to make up the fewest a planta gets.
		else: junction[id] = STRAIGHT
	# How much of the planta's way out chooses at each, and from which side it
	# arrives there.
	var entry := FLOOR.entry_of(manifest, planta)
	var flow := {}
	var arriving := {}
	for id in cost:
		if id == refuge or int(rooms[id].get("wing", -1)) != planta: continue
		var amount: float = ENTRY_WEIGHT if id == entry else 1.0
		var came := -1
		var at: int = id
		var guard := 0
		while at != refuge and guard < 400:
			guard += 1
			if junction.has(at):
				flow[at] = float(flow.get(at, 0.0)) + amount * float(junction[at])
				if came >= 0:
					var from := way_between(rooms[at], rooms[came])
					var axis := "x" if from.x != 0 else "z"
					if not arriving.has(at): arriving[at] = {"x": 0.0, "z": 0.0}
					arriving[at][axis] = float(arriving[at][axis]) + amount
			came = at
			at = int(next[at])
	var choices := flow.keys().filter(func(id): return float(junction[id]) > STRAIGHT).size()
	var chosen_count := clampi(FEWEST + maxi(0, choices - SIGN_BASE) / SIGN_PER, FEWEST, MOST)
	var ranked: Array = flow.keys()
	ranked.sort_custom(func(a, b): return float(flow[a]) > float(flow[b]) or (float(flow[a]) == float(flow[b]) and int(a) < int(b)))
	var signs: Array = []
	# Apart as far as the planta allows: the full spacing, then less, and at
	# the last, nearer the refuge too, before it has fewer than FEWEST.
	for rule in [[APART, NEAR_REFUGE], [APART_LEAST, NEAR_REFUGE], [APART_LEAST * 0.6, NEAR_REFUGE], [APART_LEAST * 0.6, NEAR_REFUGE * 0.4]]:
		var spacing: float = rule[0]
		for id in ranked:
			if signs.size() >= chosen_count: break
			if float(cost[id]) < float(rule[1]) or signs.any(func(sign): return int(sign.room) == id): continue
			var here := FLOOR.position_of(rooms[id])
			if signs.any(func(sign): return FLOOR.position_of(rooms[int(sign.room)]).distance_to(here) < spacing): continue
			signs.append(sign_at(rooms, id, next, arriving, planta))
	return signs

## The sign of one cell: which way out, and which way it hangs.
static func sign_at(rooms: Array, id: int, next: Dictionary, arriving: Dictionary, planta: int) -> Dictionary:
	var way := way_between(rooms[id], rooms[int(next[id])])
	# Across the way most of its traffic comes in by; with none (only ways
	# that start here), across the way out, so it reads left or right.
	var sides: Dictionary = arriving.get(id, {"x": 0.0, "z": 0.0})
	var normal := Vector2i(1, 0) if float(sides.x) > float(sides.z) else Vector2i(0, 1)
	if float(sides.x) == float(sides.z): normal = Vector2i(1, 0) if way.x == 0 else Vector2i(0, 1)
	return {"room": id, "planta": planta, "way": way, "normal": normal,
		"front": way_for(-normal, way), "back": way_for(normal, way)}
