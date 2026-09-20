extends RefCounted
## Three wings and the doors between them. A floor is played wing by wing: the
## way on is a single door, kept locked until its stage is closed, and the room
## holding it is that stage's refuge.
const WINGS := 3
## Rooms with a television in the wing of the second stage: its condition asks
## for as many as there are survivors (up to five) plus two spare.
const TV_ROOMS := 8
## Doors that carry no guest number: reception, circulation, service and the
## refuge. In a hotel only the rooms let to somebody have a plaque.
const NO_NUMBER := [0, 7, 8, 9, 10, 11, 12, 15, 19]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const VALIDATOR := preload("res://game/world/generation/map_validator.gd")

func generate(run_seed: int) -> Dictionary:
	for attempt in 20:
		var result := candidate(run_seed, attempt)
		var errors := VALIDATOR.new().validate(result)
		if errors.is_empty():
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
	var rooms: Array = []
	var adjacency: Array = []
	# Three wings, in bands of columns. They share no way through except one
	# door each, so a wing left behind is left behind for good.
	for i in count:
		rooms.append({"id": i, "x": i % width, "z": i / width, "type": 0, "sector": mini(4, (i % width) * 5 / width), "wing": mini(WINGS - 1, (i % width) * WINGS / width), "props": [], "px": x_centers[i % width], "pz": z_centers[i / width], "span_x": x_sizes[i % width], "span_z": z_sizes[i / width], "hall": -1})
		adjacency.append([])
	var edges: Array = []
	# One maze per wing: the spanning tree never crosses a boundary.
	for wing in WINGS:
		var root := -1
		for i in count:
			if int(rooms[i].wing) == wing:
				root = i
				break
		if root < 0: continue
		var seen := {root: true}
		var stack: Array[int] = [root]
		while not stack.is_empty():
			var current: int = stack.back()
			var choices: Array[int] = []
			for n in neighbors(current, width, height):
				if not seen.has(n) and int(rooms[n].wing) == wing: choices.append(n)
			if choices.is_empty():
				stack.pop_back()
			else:
				var next: int = choices[rng.randi_range(0, choices.size() - 1)]
				connect_rooms(current, next, edges, adjacency)
				seen[next] = true
				stack.append(next)
	# Additional connections create alternatives; no long dead-end chains survive.
	for i in count:
		for n in neighbors(i, width, height):
			if n > i and int(rooms[n].wing) == int(rooms[i].wing) and not adjacency[i].has(n) and (full_grid or rng.randf() < 0.18):
				connect_rooms(i, n, edges, adjacency)
	for i in count:
		if adjacency[i].size() == 1:
			var node: int = adjacency[i][0]
			var previous := i
			var length := 1
			while adjacency[node].size() == 2:
				var following: int = adjacency[node][0] if adjacency[node][0] != previous else adjacency[node][1]
				previous = node
				node = following
				length += 1
			if length > 2:
				for n in neighbors(i, width, height):
					if int(rooms[n].wing) == int(rooms[i].wing) and not adjacency[i].has(n):
						connect_rooms(i, n, edges, adjacency)
						break
	# Connected two/three-cell common spaces include L-shaped lounges. Their
	# internal boundaries disappear physically, rather than just changing labels.
	var merged: Array = []
	for anchor in range(1, count):
		if rooms[anchor].hall != -1 or rng.randf() > 0.16: continue
		var members: Array[int] = [anchor]
		for n in neighbors(anchor, width, height):
			if n > 0 and rooms[n].hall == -1 and int(rooms[n].wing) == int(rooms[anchor].wing) and members.size() < 3: members.append(n)
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
	var entrance := 0
	for wing in WINGS - 1:
		var distances := distance_map(adjacency, entrance)
		var best := -1
		var best_distance := -1
		for i in count:
			if int(rooms[i].wing) != wing or distances[i] < 0: continue
			for n in neighbors(i, width, height):
				if int(rooms[n].wing) != wing + 1: continue
				if distances[i] > best_distance:
					best_distance = distances[i]
					best = i
		if best < 0: return candidate(run_seed, attempt + 1, true)
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
	var deepest := entrance
	var outward := Vector2i(1, 0)
	for i in count:
		if int(rooms[i].wing) != WINGS - 1 or last[i] <= last[deepest]: continue
		var side := outer_side(i, width, height)
		if side == Vector2i.ZERO: continue
		deepest = i
		outward = side
	gates.append({"stage": WINGS, "room": deepest, "beyond": -1, "out": [outward.x, outward.y]})
	refuges.append(deepest)
	var exit_id: int = refuges[0]
	merged = merged.filter(func(edge): return not refuges.any(func(id): return edge.has(id)))
	for id in refuges: rooms[id].hall = -1
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
		# Even checkerboard cells are rooms, preventing four consecutive corridors.
		room.type = decoration.randi_range(1, 18)
		if (room.x + room.z) % 2 == 0 and room.type in [11, 12]: room.type = 5
		if room.id == 0: room.type = 0
		if refuges.has(room.id): room.type = 19
		if room.hall >= 0: room.type = [5, 6, 17, 18][int(room.hall) % 4]
	# The second stage is played on the sets of its wing, and it asks for as
	# many as there are survivors: a wing has to hold enough of them whatever
	# the room types rolled, so the ones missing are given a television room.
	var tv_wing := 1
	var with_tv: Array[int] = []
	var plain: Array[int] = []
	for room in rooms:
		if int(room.wing) != tv_wing or refuges.has(room.id) or int(room.hall) >= 0: continue
		if FLOOR.RECIPES[room.type].has("tv"): with_tv.append(int(room.id))
		elif not int(room.type) in [0, 19]: plain.append(int(room.id))
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
	return {"version": FLOOR.VERSION, "seed": run_seed, "attempt": attempt, "width": width, "height": height, "start": 0, "exit": exit_id, "refuges": refuges, "gates": gates, "wings": WINGS, "rooms": rooms, "edges": edges, "adjacency": adjacency, "ambient_seed": run_seed + 4000037, "merged": merged}

## The numbers on the doors. Each wing has its own hundred and each corridor of
## the wing its own twenty: the numbers climb along the corridor, odd on one
## side and even on the other, as they do in a hotel. Which way they climb is
## drawn per corridor, so going up in number no longer walks the floor -- which
## is how the floor used to be solved.
static func number_rooms(rooms: Array, width: int, height: int, rng: RandomNumberGenerator) -> void:
	for room in rooms: room["number"] = 0
	for wing in WINGS:
		var columns: Array[int] = []
		for x in width:
			if int(rooms[x].wing) == wing: columns.append(x)
		var corridor := 0
		var index := 0
		while index < columns.size():
			# A corridor with rooms on both sides, or a single line of them
			# against the wall where the wing has an odd column left over.
			var sides: Array[int] = [columns[index]]
			if index + 1 < columns.size(): sides.append(columns[index + 1])
			index += sides.size()
			var base := (wing + 1) * 100 + corridor * 30
			corridor += 1
			var upward := rng.randi_range(0, 1) == 1
			var step := 0
			for position in height:
				var z: int = position if upward else height - 1 - position
				var used := false
				for side in sides.size():
					var room: Dictionary = rooms[z * width + sides[side]]
					if not numbered(room): continue
					room.number = base + step * 2 + side + 1
					used = true
				# Service and common space do not take a number with them: the
				# next rooms along the corridor carry on where they left off.
				if used: step += 1

## Whether this room is let to somebody, and so has a number on its door.
static func numbered(room: Dictionary) -> bool:
	return int(room.hall) < 0 and not int(room.type) in NO_NUMBER

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
