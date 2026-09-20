extends RefCounted
## Three wings and the doors between them. A floor is played wing by wing: the
## way on is a single door, kept locked until its stage is closed, and the room
## holding it is that stage's refuge.
##
## Inside a wing the floor is laid out like a hotel and then allowed to come
## apart: a network of corridors with rooms hanging off them, a marked service
## block near the entrance, and -- as one walks in -- more rings, more dead
## ends and more doors between rooms, until the plan is a warren. How much of
## a hotel any one cell still is comes from `order_field`.
const WINGS := 3
## Rooms with a television in the wing of the second stage: its condition asks
## for as many as there are survivors (up to five) plus two spare.
const TV_ROOMS := 8
## Doors that carry no guest number: reception, circulation, service and the
## refuge. In a hotel only the rooms let to somebody have a plaque.
const NO_NUMBER := [0, 7, 8, 9, 10, 11, 12, 15, 19]
## What a cell can be. Where the floor still reads like a hotel it is a guest
## room; where it has come apart it is whatever the place turned into.
const TIDY_ROOMS := [1, 1, 2, 2, 2, 3, 4, 16]
const UNRULY_ROOMS := [2, 3, 4, 5, 6, 13, 14, 16, 17, 18]
const SERVICE_ROOMS := [7, 8, 9, 15]
## Rooms the three stages have to walk through at the very least. A floor that
## can be finished in fewer is drawn again: the wings exist to be walked.
const MIN_WALK := 24
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const VALIDATOR := preload("res://game/world/generation/map_validator.gd")
const WALKER := preload("res://game/world/generation/wall_walker.gd")

func generate(run_seed: int) -> Dictionary:
	for attempt in 20:
		var result := candidate(run_seed, attempt)
		var errors := VALIDATOR.new().validate(result)
		# A floor whose exit room falls to a hand on the wall is thrown away
		# and drawn again. The two refuges before it cannot promise as much --
		# a room against the next wing is always found in the end -- so what
		# is asked of those is only that the technique be no shortcut. The
		# standby floor at the end promises nothing but that it can be walked.
		if errors.is_empty() and int(result.wall_hits[WINGS - 1]) == 0 and int(result.walk) >= MIN_WALK:
			result["fallback"] = false
			return result
	var fallback := candidate(404, 0, true)
	fallback["requested_seed"] = run_seed
	fallback["fallback"] = true
	assert(VALIDATOR.new().validate(fallback).is_empty(), "Invalid fallback")
	return fallback

func candidate(run_seed: int, attempt: int, full_grid := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + attempt * 104729
	var width := rng.randi_range(10, 12)
	var height := rng.randi_range(10, 11)
	var count := width * height
	var x_sizes: Array[float] = []
	var z_sizes: Array[float] = []
	var x_centers: Array[float] = [0.0]
	var z_centers: Array[float] = [0.0]
	for x in width:
		x_sizes.append(12.0 if x == 0 else [12.0, 14.0, 18.0][rng.randi_range(0, 2)])
		if x > 0: x_centers.append(x_centers[-1] + (x_sizes[x-1] + x_sizes[x]) * 0.5)
	for z in height:
		z_sizes.append(12.0 if z == 0 else [12.0, 16.0, 20.0][rng.randi_range(0, 2)])
		if z > 0: z_centers.append(z_centers[-1] + (z_sizes[z-1] + z_sizes[z]) * 0.5)
	var start_id := 0
	var rooms: Array = []
	var adjacency: Array = []
	# Three wings, in bands of columns. They share no way through except one
	# door each, so a wing left behind is left behind for good.
	for i in count:
		rooms.append({"id": i, "x": i % width, "z": i / width, "type": 0, "sector": mini(4, (i % width) * 5 / width), "wing": mini(WINGS - 1, (i % width) * WINGS / width), "props": [], "px": x_centers[i % width], "pz": z_centers[i / width], "span_x": x_sizes[i % width], "span_z": z_sizes[i / width], "hall": -1, "corridor": false, "service": false})
		adjacency.append([])
	order_field(rooms, width, run_seed + attempt * 104729)
	var edges: Array = []
	if full_grid:
		# The standby floor: no plan at all, every wall that can be a doorway
		# is one. It is never played unless twenty attempts failed.
		for i in count:
			for n in neighbors(i, width, height):
				if n > i and int(rooms[n].wing) == int(rooms[i].wing): connect_rooms(i, n, edges, adjacency)
	else:
		for wing in WINGS: lay_wing(rooms, width, height, wing, rng, edges, adjacency)
	# Connected two/three-cell common spaces include L-shaped lounges. Their
	# internal boundaries disappear physically, rather than just changing labels.
	var merged: Array = []
	for anchor in range(1, count):
		if rooms[anchor].hall != -1 or bool(rooms[anchor].corridor) or bool(rooms[anchor].service) or rng.randf() > 0.16: continue
		var members: Array[int] = [anchor]
		for n in neighbors(anchor, width, height):
			if n > 0 and rooms[n].hall == -1 and not bool(rooms[n].corridor) and not bool(rooms[n].service) and int(rooms[n].wing) == int(rooms[anchor].wing) and members.size() < 3: members.append(n)
		if members.size() < 2: continue
		for id in members: rooms[id].hall = anchor
		for id in members:
			for n in neighbors(id, width, height):
				if members.has(n) and n > id:
					if not adjacency[id].has(n): connect_rooms(id, n, edges, adjacency)
					merged.append([id, n])
	# The way on from each wing: one door, as far into the wing as the boundary
	# allows, so a wing is walked through and not cut across.
	var gates: Array = []
	var refuges: Array = []
	var hidden: Array = []
	var entrance := 0
	for wing in WINGS - 1:
		var distances := distance_map(adjacency, entrance)
		var deep: Array = []
		for i in count:
			if int(rooms[i].wing) != wing or distances[i] < 0 or bool(rooms[i].corridor): continue
			if not neighbors(i, width, height).any(func(n): return int(rooms[n].wing) == wing + 1): continue
			deep.append(i)
		if deep.is_empty(): return candidate(run_seed, attempt + 1, true)
		deep.sort_custom(func(one, two): return distances[one] > distances[two])
		# Within two rooms of the deepest there is: the wing has to be walked
		# through, so how well a room hides only settles it between the ones
		# that are far enough in.
		deep = deep.filter(func(id): return distances[id] >= distances[deep[0]] - 2)
		var choice := hide_refuge(rooms, width, height, deep, wing, entrance, edges, adjacency, distances)
		var best: int = int(choice.room)
		hidden.append(int(choice.hits))
		var through := -1
		for n in neighbors(best, width, height):
			if int(rooms[n].wing) == wing + 1:
				through = n
				break
		connect_rooms(best, through, edges, adjacency)
		gates.append({"stage": wing + 1, "room": best, "beyond": through})
		refuges.append(best)
		entrance = through
	# The last stage ends the floor: its refuge is the deepest room of the last
	# wing that sits against the outside of the building, because the door with
	# the code lock opens outwards, into the way out.
	var last := distance_map(adjacency, entrance)
	var island := island_refuge(rooms, width, height, WINGS - 1, entrance, edges, adjacency, last)
	if island.is_empty(): return candidate(run_seed, attempt + 1, true)
	var deepest: int = int(island.room)
	hidden.append(int(island.hits))
	var outward: Vector2i = island.out
	gates.append({"stage": WINGS, "room": deepest, "beyond": int(island.landing), "out": [outward.x, outward.y]})
	refuges.append(deepest)
	var exit_id: int = refuges[0]
	merged = merged.filter(func(edge): return not refuges.any(func(id): return edge.has(id)) and int(rooms[edge[0]].hall) >= 0 and int(rooms[edge[1]].hall) >= 0)
	for id in refuges:
		rooms[id].hall = -1
		rooms[id].service = false
	for room in rooms: room["open_sides"] = []
	for edge in merged:
		var a: Dictionary = rooms[edge[0]]
		var b: Dictionary = rooms[edge[1]]
		var direction := "east" if b.x > a.x else "south"
		a.open_sides.append(direction)
		b.open_sides.append("west" if direction == "east" else "north")
	var decoration := RandomNumberGenerator.new()
	decoration.seed = run_seed + 2000003 + attempt * 104729
	for room in rooms:
		# What a cell holds follows what it is: corridors are circulation, the
		# service block is service, and a room is drawn from the tidy or the
		# unruly list depending on how much of a hotel it still is.
		if bool(room.corridor): room.type = 11 if decoration.randf() < 0.78 else 12
		elif bool(room.service): room.type = SERVICE_ROOMS[decoration.randi_range(0, SERVICE_ROOMS.size() - 1)]
		elif decoration.randf() < float(room.order): room.type = TIDY_ROOMS[decoration.randi_range(0, TIDY_ROOMS.size() - 1)]
		else: room.type = UNRULY_ROOMS[decoration.randi_range(0, UNRULY_ROOMS.size() - 1)]
		if room.hall >= 0: room.type = [5, 6, 17, 18][int(room.hall) % 4]
		if room.id == 0: room.type = 0
		# Behind the last door: the back stairs. Tiled, lit, and nothing in
		# it but the way off the floor.
		if bool(room.get("landing", false)): room.type = 9
		if refuges.has(room.id): room.type = 19
	# One arrives into the next wing through its lobby, whatever the cell was
	# going to be: a landmark to come back to, and the only one there is.
	for gate in gates:
		var beyond := int(gate.get("beyond", -1))
		if beyond >= 0 and not refuges.has(beyond): rooms[beyond].type = 10
	# The second stage is played on the sets of its wing, and it asks for as
	# many as there are survivors: a wing has to hold enough of them whatever
	# the room types rolled, so the ones missing are given a television room.
	var tv_wing := 1
	var with_tv: Array[int] = []
	var plain: Array[int] = []
	for room in rooms:
		if int(room.wing) != tv_wing or refuges.has(room.id) or int(room.hall) >= 0 or bool(room.corridor) or bool(room.service): continue
		if FLOOR.RECIPES[room.type].has("tv"): with_tv.append(int(room.id))
		elif not int(room.type) in [0, 10, 19]: plain.append(int(room.id))
	while with_tv.size() < TV_ROOMS and not plain.is_empty():
		var pick: int = plain[decoration.randi_range(0, plain.size() - 1)]
		plain.erase(pick)
		rooms[pick].type = 14
		with_tv.append(pick)
	# Its own draw, so a change in the numbering never moves the furniture.
	var plaques := RandomNumberGenerator.new()
	plaques.seed = run_seed + 3000017 + attempt * 104729
	number_rooms(rooms, width, height, plaques)
	for room in rooms:
		room["variant"] = decoration.randi_range(0, 3)
		room["layout"] = decoration.randi_range(0, 3)
		room["height"] = 4.8 if room.hall >= 0 else 4.2 if room.type in [0, 5, 6, 17, 18] else 3.15
		room["cover_slots"] = 4
		for slot in 4:
			var kind: String = FLOOR.RECIPES[room.type][slot]
			var rotation := decoration.randi_range(0, 3)
			if kind in ["bed", "sofa", "desk", "tv", "reception", "washer", "basin", "shelf"]: rotation = 0 if slot < 2 else 2
			if kind in ["wardrobe", "curtain"]: rotation = 1 if slot % 2 == 0 else 3
			room.props.append({"kind": kind, "slot": slot, "rotation": rotation})
	var walk := 0
	var leg := int(start_id)
	for gate in gates:
		var spans := distance_map(adjacency, leg)
		walk += maxi(0, int(spans[int(gate.room)]))
		var beyond := int(gate.get("beyond", -1))
		if beyond >= 0 and int(rooms[beyond].wing) != int(rooms[int(gate.room)].wing): leg = beyond
	return {"version": FLOOR.VERSION, "seed": run_seed, "walk": walk, "attempt": attempt, "width": width, "height": height, "start": start_id, "exit": exit_id, "refuges": refuges, "gates": gates, "wings": WINGS, "rooms": rooms, "edges": edges, "adjacency": adjacency, "ambient_seed": run_seed + 4000037, "merged": merged, "wall_hits": hidden}

## How much of a hotel each cell still is: 1 is a plan somebody drew, 0 is what
## the place turned into. It falls as one walks in, and it falls early -- by
## the middle of the first wing the distribution is already breaking -- but it
## does not fall evenly: patches of three or four cells drift either way, so a
## wing can begin in a mess, straighten into something that reads like a normal
## hotel and end up tangled. There are islands of order inside the warren and
## pockets of warren inside the order; only the drift of the whole floor is
## certain.
static func order_field(rooms: Array, width: int, run_seed: int) -> void:
	var bands := {}
	for room in rooms:
		var wing := int(room.wing)
		var span: Array = bands.get(wing, [width, -1])
		bands[wing] = [mini(span[0], int(room.x)), maxi(span[1], int(room.x))]
	for room in rooms:
		var span: Array = bands[int(room.wing)]
		var across := float(int(room.x) - int(span[0])) / maxf(1.0, float(int(span[1]) - int(span[0])))
		var walked := (float(int(room.wing)) + across) / float(WINGS)
		room["order"] = clampf(0.95 - 0.8 * pow(walked, 0.6) + 0.35 * drift(float(room.x) / 3.2, float(room.z) / 3.2, run_seed), 0.0, 1.0)

## Value noise over a coarse grid: patches that drift the same way, with soft
## edges between them. Hand-rolled from `hash` on purpose -- every machine has
## to generate the same floor from the same seed, so it cannot lean on the
## engine's own noise.
static func drift(x: float, z: float, run_seed: int) -> float:
	var gx := floori(x)
	var gz := floori(z)
	var fx := smoothstep(0.0, 1.0, x - float(gx))
	var fz := smoothstep(0.0, 1.0, z - float(gz))
	var near := lerpf(patch(gx, gz, run_seed), patch(gx + 1, gz, run_seed), fx)
	var far := lerpf(patch(gx, gz + 1, run_seed), patch(gx + 1, gz + 1, run_seed), fx)
	return lerpf(near, far, fz)

static func patch(x: int, z: int, run_seed: int) -> float:
	return float(absi(hash([run_seed, "order", x, z])) % 1000) / 499.5 - 1.0

## Where the wing is walked into from: reception in the first one, and the west
## edge in the others, which is the side the gate before it opens on.
static func doorstep(rooms: Array, width: int, wing: int, rng: RandomNumberGenerator) -> int:
	if wing == 0: return 1 if rng.randf() < 0.5 else width
	var west := 9999
	var column: Array[int] = []
	for room in rooms:
		if int(room.wing) != wing: continue
		if int(room.x) < west:
			west = int(room.x)
			column.clear()
		if int(room.x) == west: column.append(int(room.id))
	return column[rng.randi_range(0, column.size() - 1)]

## A wing, laid out in this order: the corridors first, then the service block,
## then the rooms hanging off the corridors and the doors between them.
func lay_wing(rooms: Array, width: int, height: int, wing: int, rng: RandomNumberGenerator, edges: Array, adjacency: Array) -> void:
	var band: Array[int] = []
	var tidiness := 0.0
	for room in rooms:
		if int(room.wing) != wing: continue
		band.append(int(room.id))
		tidiness += float(room.order)
	if band.is_empty(): return
	tidiness /= float(band.size())
	var entrance := doorstep(rooms, width, wing, rng)
	rooms[entrance].corridor = true
	var corridor: Array[int] = [entrance]
	# About a third of a wing that still reads like a hotel is corridor; half
	# of that where it has come apart, because there the floor is rooms giving
	# on to rooms.
	var target := int(round(float(band.size()) * lerpf(0.17, 0.34, tidiness)))
	var guard := 0
	while corridor.size() < target and guard < 400:
		guard += 1
		# It grows out of the tidiest piece of itself, so the network is dense
		# where the plan survives and frays where it does not.
		var from: int = corridor[rng.randi_range(0, corridor.size() - 1)]
		for draw in 2:
			var other: int = corridor[rng.randi_range(0, corridor.size() - 1)]
			if float(rooms[other].order) > float(rooms[from].order): from = other
		# Runs of two or three cells and then a turn, never a hall straight
		# across the wing.
		var run := 3 if rng.randf() < float(rooms[from].order) else 2
		var direction: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi_range(0, 3)]
		var at := from
		for step in run:
			var next := step_cell(rooms, width, height, at, direction, wing)
			if next < 0: break
			if bool(rooms[next].corridor):
				# Running into corridor already laid closes a ring: that is
				# what makes it possible to walk round and round a wing.
				if not adjacency[at].has(next): connect_rooms(at, next, edges, adjacency)
				break
			if not line_ok(rooms, width, height, next): break
			rooms[next].corridor = true
			corridor.append(next)
			connect_rooms(at, next, edges, adjacency)
			at = next
	# Corridor that meets corridor is corridor: no wall between two of them.
	for id in corridor:
		for n in neighbors(id, width, height):
			if int(rooms[n].wing) == wing and bool(rooms[n].corridor) and not adjacency[id].has(n): connect_rooms(id, n, edges, adjacency)
	plant_service(rooms, width, height, band, wing, rng)
	for id in band:
		if bool(rooms[id].corridor): continue
		var doors: Array[int] = []
		for n in neighbors(id, width, height):
			if int(rooms[n].wing) == wing and bool(rooms[n].corridor): doors.append(n)
		if doors.is_empty(): continue
		connect_rooms(id, doors[rng.randi_range(0, doors.size() - 1)], edges, adjacency)
		# A second door on to the corridor where the plan has come apart.
		for n in doors:
			if not adjacency[id].has(n) and rng.randf() < lerpf(0.34, 0.04, float(rooms[id].order)): connect_rooms(id, n, edges, adjacency)
	# The doors a hotel opens between two rooms of a family: rare while the
	# floor is tidy, everywhere once it is not. They are the shortcuts, and
	# they are what stops a walk along the corridors from covering the wing.
	for id in band:
		if bool(rooms[id].corridor): continue
		for n in neighbors(id, width, height):
			if n <= id or int(rooms[n].wing) != wing or bool(rooms[n].corridor) or adjacency[id].has(n): continue
			if bool(rooms[id].service) != bool(rooms[n].service): continue
			var shared := minf(float(rooms[id].order), float(rooms[n].order))
			# A department is one piece: its own back way through.
			if bool(rooms[id].service) or rng.randf() < lerpf(0.46, 0.05, shared): connect_rooms(id, n, edges, adjacency)
	join_wing(rooms, width, height, band, entrance, wing, edges, adjacency)

## The service block: a compact department -- laundry, stores, maintenance, the
## office -- planted in the tidiest patch of the first wing, where it reads at
## a glance. Further in the discipline is gone and service turns up as loose
## pockets between the rooms.
func plant_service(rooms: Array, width: int, height: int, band: Array, wing: int, rng: RandomNumberGenerator) -> void:
	if wing == 0:
		var best := -1
		var best_order := -1.0
		for id in band:
			var block := service_block(rooms, width, height, id, wing)
			if block.is_empty(): continue
			var tidiness := 0.0
			for member in block: tidiness += float(rooms[member].order)
			tidiness /= float(block.size())
			if tidiness > best_order:
				best_order = tidiness
				best = id
		if best >= 0:
			for member in service_block(rooms, width, height, best, wing): rooms[member].service = true
	for id in band:
		if bool(rooms[id].corridor) or bool(rooms[id].service) or id == 0: continue
		if rng.randf() < lerpf(0.0, 0.14, 1.0 - float(rooms[id].order)): rooms[id].service = true

## The four cells of a service block, if this one can anchor it: a two by two
## of cells that are neither corridor nor reception, all in the same wing.
static func service_block(rooms: Array, width: int, height: int, anchor: int, wing: int) -> Array[int]:
	var block: Array[int] = []
	for step: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var x: int = int(rooms[anchor].x) + step.x
		var z: int = int(rooms[anchor].z) + step.y
		if x >= width or z >= height: return []
		var id: int = z * width + x
		if id == 0 or int(rooms[id].wing) != wing or bool(rooms[id].corridor): return []
		block.append(id)
	return block

## Nothing in a wing may be walled off from its entrance: whatever the draws
## left stranded is given a door on to the part already reachable. `avoid` is
## the refuge, which keeps the one door it was left with.
static func join_wing(rooms: Array, width: int, height: int, band: Array, entrance: int, wing: int, edges: Array, adjacency: Array, avoid: Array = []) -> void:
	while true:
		var seen := {entrance: true}
		var queue: Array[int] = [entrance]
		var cursor := 0
		while cursor < queue.size():
			var current: int = queue[cursor]
			cursor += 1
			for n in adjacency[current]:
				if int(rooms[n].wing) == wing and not seen.has(n):
					seen[n] = true
					queue.append(n)
		var joined := false
		for id in band:
			if seen.has(id) or avoid.has(id): continue
			for n in neighbors(id, width, height):
				if not avoid.has(n) and int(rooms[n].wing) == wing and seen.has(n):
					connect_rooms(id, n, edges, adjacency)
					joined = true
					break
			if joined: break
		if not joined: return

## The refuge of a wing, and the single door it is entered by. The deepest
## rooms are tried in turn, and each of their doors with them, until one is
## found that the walk with a hand on the wall does not reach -- from the way
## into the wing, with either hand and setting off any of the four ways. The
## room that holds up is sealed: every other door of it is bricked up, and
## whatever that leaves cut off is given another way round.
##
## It hides itself in whichever way the floor around it allows. Where the
## corridors close a ring it ends up the core inside it, with its door on the
## inner face -- the hand on the wall goes round the outside and comes back
## out. Where the plan has come apart it ends up at the end of a chain of
## rooms that open into each other, which the corridors never touch.
func hide_refuge(rooms: Array, width: int, height: int, candidates: Array, wing: int, entrance: int, edges: Array, adjacency: Array, reach: Array) -> Dictionary:
	var band: Array[int] = []
	for room in rooms:
		if int(room.wing) == wing: band.append(int(room.id))
	var best := {"room": int(candidates[0]), "keep": -1, "hits": 8, "cost": -1}
	# Only the deepest handful is worth trying: a refuge near the way in is a
	# bad refuge however well it hides.
	for id in candidates.slice(0, 10):
		var ways: Array[int] = []
		for n in adjacency[id]:
			if int(rooms[n].wing) == wing: ways.append(int(n))
		for keep in ways:
			# The trial only needs the doors, not the list of them: what the
			# seal writes into this one is thrown away with it.
			var trial_edges: Array = []
			var trial: Array = adjacency.duplicate(true)
			seal_refuge(rooms, width, height, band, int(id), keep, wing, entrance, trial_edges, trial)
			# A refuge against the next wing cannot be hidden from the hand on
			# the wall -- its walls run into the wall between the wings, and
			# that is the one the walk is holding. What can be asked of it is
			# that the technique be no shortcut: the one kept is the one that
			# makes the walk look into the most rooms before it arrives.
			# Rooms the technique has to look into, and rooms away from the way
			# in: both count in rooms walked, and the depth counts double,
			# because it is what everybody pays and not only the one hugging
			# a wall.
			var price: int = WALKER.cost(rooms, trial, width, height, entrance, int(id), band.size()) + 2 * maxi(0, int(reach[id]))
			if price <= int(best.cost): continue
			best = {"room": int(id), "keep": keep, "hits": WALKER.hits(rooms, trial, width, height, entrance, int(id)), "cost": price}
	if int(best.keep) >= 0: seal_refuge(rooms, width, height, band, int(best.room), int(best.keep), wing, entrance, edges, adjacency)
	return best

## The last refuge and the way off the floor, laid out as an island. The room
## with the lock and the landing behind its door are a block of two cells, and
## the ten cells around them are doored all the way round, a closed ring. The
## refuge keeps a single ordinary door, on to the inner face of that ring.
##
## That is the one shape a hand on the wall cannot solve: the ring's inner
## wall is a piece of wall that touches nothing else, so the walk goes round
## the outside of the block and comes back out without ever turning into the
## refuge. It is also an ordinary hotel plan -- the service core with the
## stairs in it, and the corridor round it.
func island_refuge(rooms: Array, width: int, height: int, wing: int, entrance: int, edges: Array, adjacency: Array, reach: Array) -> Dictionary:
	var band: Array[int] = []
	for room in rooms:
		if int(room.wing) == wing: band.append(int(room.id))
	var blocks: Array = []
	for id in band:
		if id == entrance or id == 0: continue
		for way: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var landing := step_cell(rooms, width, height, id, way, wing)
			if landing < 0 or landing == entrance or landing == 0: continue
			var ring := island_ring(rooms, width, height, id, landing, wing)
			if ring.is_empty(): continue
			blocks.append({"room": id, "landing": landing, "out": way, "ring": ring})
	if blocks.is_empty(): return {}
	# As deep into the wing as a block of twelve cells can be put.
	blocks.sort_custom(func(one, two): return reach[int(one.room)] > reach[int(two.room)])
	var block: Dictionary = blocks[0]
	var ring: Array = block.ring
	for id in ring:
		rooms[id].service = false
		rooms[id].hall = -1
		# Corridor where that does not leave four of them in a line; the rest
		# stay rooms, opening into each other, which is a ring just the same.
		if not bool(rooms[id].corridor) and line_ok(rooms, width, height, int(id)): rooms[id].corridor = true
	for index in ring.size():
		var one: int = int(ring[index])
		var two: int = int(ring[(index + 1) % ring.size()])
		if not adjacency[one].has(two): connect_rooms(one, two, edges, adjacency)
	var core: Array = [int(block.room), int(block.landing)]
	for id in core:
		rooms[id].hall = -1
		rooms[id].service = false
		for n in adjacency[id].duplicate(): disconnect_rooms(int(id), int(n), edges, adjacency)
	rooms[int(block.landing)]["landing"] = true
	var best := {}
	for keep in ring:
		if not neighbors(int(block.room), width, height).has(int(keep)): continue
		var trial_edges: Array = []
		var trial: Array = adjacency.duplicate(true)
		connect_rooms(int(block.room), int(keep), trial_edges, trial)
		join_wing(rooms, width, height, band, entrance, wing, trial_edges, trial, core)
		var hits: int = WALKER.hits(rooms, trial, width, height, entrance, int(block.room))
		if best.is_empty() or hits < int(best.hits): best = {"keep": int(keep), "hits": hits}
		if hits == 0: break
	if best.is_empty(): return {}
	connect_rooms(int(block.room), int(best.keep), edges, adjacency)
	# The lock's door. Nothing else opens on to the landing, and the walk with
	# a hand on the wall does not go through a locked door either.
	connect_rooms(int(block.room), int(block.landing), edges, adjacency)
	join_wing(rooms, width, height, band, entrance, wing, edges, adjacency, core)
	return {"room": int(block.room), "landing": int(block.landing), "out": block.out, "keep": int(best.keep), "hits": int(best.hits)}

## The ten cells around a two-cell core, in the order they ring it, or none if
## the block does not fit inside the wing.
static func island_ring(rooms: Array, width: int, height: int, one: int, two: int, wing: int) -> Array[int]:
	var low := Vector2i(mini(int(rooms[one].x), int(rooms[two].x)) - 1, mini(int(rooms[one].z), int(rooms[two].z)) - 1)
	var high := Vector2i(maxi(int(rooms[one].x), int(rooms[two].x)) + 1, maxi(int(rooms[one].z), int(rooms[two].z)) + 1)
	if low.x < 0 or low.y < 0 or high.x >= width or high.y >= height: return []
	var ring: Array[int] = []
	for x in range(low.x, high.x + 1): ring.append(low.y * width + x)
	for z in range(low.y + 1, high.y + 1): ring.append(z * width + high.x)
	for x in range(high.x - 1, low.x - 1, -1): ring.append(high.y * width + x)
	for z in range(high.y - 1, low.y, -1): ring.append(z * width + low.x)
	for id in ring:
		if int(rooms[id].wing) != wing or id == 0: return []
	return ring

## Bricks up every door of the refuge except the one it keeps, and gives the
## rooms that left stranded another way round.
static func seal_refuge(rooms: Array, width: int, height: int, band: Array, refuge: int, keep: int, wing: int, entrance: int, edges: Array, adjacency: Array) -> void:
	for n in adjacency[refuge].duplicate():
		if int(rooms[n].wing) != wing or int(n) == keep: continue
		disconnect_rooms(refuge, int(n), edges, adjacency)
	join_wing(rooms, width, height, band, entrance, wing, edges, adjacency, [refuge])

static func disconnect_rooms(a: int, b: int, edges: Array, adjacency: Array) -> void:
	adjacency[a].erase(b)
	adjacency[b].erase(a)
	for index in range(edges.size() - 1, -1, -1):
		if int(edges[index][0]) == mini(a, b) and int(edges[index][1]) == maxi(a, b): edges.remove_at(index)

## The cell one step from this one, or -1 off the grid or out of the wing.
static func step_cell(rooms: Array, width: int, height: int, id: int, direction: Vector2i, wing: int) -> int:
	var x := int(rooms[id].x) + direction.x
	var z := int(rooms[id].z) + direction.y
	if x < 0 or x >= width or z < 0 or z >= height: return -1
	var next: int = z * width + x
	if wing >= 0 and int(rooms[next].wing) != wing: return -1
	return next

## Whether this cell may become corridor without leaving four of them in a
## straight line. A corridor has to turn: the floor is never one long hall with
## doors down both sides, which is the bored version of a hotel.
static func line_ok(rooms: Array, width: int, height: int, id: int) -> bool:
	for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
		var run := 1
		for way in [1, -1]:
			var at := id
			while true:
				var next := step_cell(rooms, width, height, at, axis * way, -1)
				if next < 0 or not bool(rooms[next].corridor): break
				run += 1
				at = next
		if run >= 4: return false
	return true

## The numbers on the doors. Each wing has its own hundred and the numbers run
## along its corridors, odd on one side and even on the other, as they do in a
## hotel. Where they start and which way they run is drawn per wing, so going
## up in number no longer walks the floor -- which is how it used to be solved.
static func number_rooms(rooms: Array, width: int, height: int, rng: RandomNumberGenerator) -> void:
	for room in rooms: room["number"] = 0
	for wing in WINGS:
		var base := (wing + 1) * 100
		var axis := rng.randi_range(0, 1)
		var back := rng.randf() < 0.5
		var odd_first := rng.randf() < 0.5
		var used := {}
		var step := 0
		var corridor: Array[int] = []
		var rest: Array[int] = []
		for room in rooms:
			if int(room.wing) != wing: continue
			if bool(room.get("corridor", false)): corridor.append(int(room.id))
			elif numbered(room): rest.append(int(room.id))
		var sweep := func(one: int, two: int) -> bool:
			var first := Vector2i(int(rooms[one].x), int(rooms[one].z))
			var second := Vector2i(int(rooms[two].x), int(rooms[two].z))
			if axis == 1:
				first = Vector2i(first.y, first.x)
				second = Vector2i(second.y, second.x)
			if first.x != second.x: return first.x < second.x
			return first.y < second.y
		corridor.sort_custom(sweep)
		rest.sort_custom(sweep)
		if back:
			corridor.reverse()
			rest.reverse()
		for id in corridor:
			var took := false
			for n in neighbors(id, width, height):
				if int(rooms[n].wing) != wing or not numbered(rooms[n]) or int(rooms[n].number) > 0: continue
				# Odd down one side of the corridor and even down the other.
				var side := 0 if int(rooms[n].x) + int(rooms[n].z) < int(rooms[id].x) + int(rooms[id].z) else 1
				if not odd_first: side = 1 - side
				var given := take_number(base, step, side, used)
				if given == 0: continue
				rooms[n].number = given
				took = true
			if took: step += 1
		# Rooms no corridor reaches -- the ones behind other rooms -- carry on
		# the same series: in a hotel they are the far half of a suite.
		for id in rest:
			if int(rooms[id].number) > 0: continue
			var given := take_number(base, step, (int(rooms[id].x) + int(rooms[id].z)) % 2, used)
			if given == 0: continue
			rooms[id].number = given
			step += 1

## The next free number of that side's parity, or zero if the hundred is full.
static func take_number(base: int, step: int, side: int, used: Dictionary) -> int:
	var wanted := base + step * 2 + side + 1
	while used.has(wanted) and wanted < base + 98: wanted += 2
	if used.has(wanted): return 0
	used[wanted] = true
	return wanted

## Whether this room is let to somebody, and so has a number on its door.
static func numbered(room: Dictionary) -> bool:
	return int(room.hall) < 0 and not bool(room.get("corridor", false)) and not bool(room.get("service", false)) and not int(room.type) in NO_NUMBER

## Which way this cell faces the outside of the building, or zero if it is
## boxed in by other cells. East first: that is the far side of the last wing.
static func outer_side(id: int, width: int, height: int) -> Vector2i:
	if id % width == width - 1: return Vector2i(1, 0)
	if id < width: return Vector2i(0, -1)
	if id >= width * (height - 1): return Vector2i(0, 1)
	return Vector2i.ZERO

static func neighbors(id: int, width: int, height: int) -> Array[int]:
	var result: Array[int] = []
	if id % width > 0: result.append(id - 1)
	if id % width < width - 1: result.append(id + 1)
	if id >= width: result.append(id - width)
	if id < width * (height - 1): result.append(id + width)
	return result

static func connect_rooms(a: int, b: int, edges: Array, adjacency: Array) -> void:
	edges.append([mini(a, b), maxi(a, b)])
	adjacency[a].append(b)
	adjacency[b].append(a)

static func distance_map(adjacency: Array, start: int) -> Array[int]:
	var distances: Array[int] = []
	distances.resize(adjacency.size())
	distances.fill(-1)
	distances[start] = 0
	var queue: Array[int] = [start]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for next in adjacency[current]:
			if distances[next] == -1:
				distances[next] = distances[current] + 1
				queue.append(next)
	return distances
