extends RefCounted
const FLOOR := preload("res://scripts/hotel/floor_definition.gd")
const VALIDATOR := preload("res://scripts/hotel/map_validator.gd")

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
	for i in count:
		rooms.append({"id": i, "x": i % width, "z": i / width, "type": 0, "sector": mini(4, (i % width) * 5 / width), "props": [], "px": x_centers[i % width], "pz": z_centers[i / width], "span_x": x_sizes[i % width], "span_z": z_sizes[i / width], "hall": -1})
		adjacency.append([])
	var edges: Array = []
	var seen := {0: true}
	var stack: Array[int] = [0]
	while not stack.is_empty():
		var current: int = stack.back()
		var choices: Array[int] = []
		for n in neighbors(current, width, height):
			if not seen.has(n): choices.append(n)
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
			if n > i and not adjacency[i].has(n) and (full_grid or rng.randf() < 0.18):
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
					if not adjacency[i].has(n):
						connect_rooms(i, n, edges, adjacency)
						break
	# Connected two/three-cell common spaces include L-shaped lounges. Their
	# internal boundaries disappear physically, rather than just changing labels.
	var merged: Array = []
	for anchor in range(1, count):
		if rooms[anchor].hall != -1 or rng.randf() > 0.16: continue
		var members: Array[int] = [anchor]
		for n in neighbors(anchor, width, height):
			if n > 0 and rooms[n].hall == -1 and members.size() < 3: members.append(n)
		if members.size() < 2: continue
		for id in members: rooms[id].hall = anchor
		for id in members:
			for n in neighbors(id, width, height):
				if members.has(n) and n > id:
					if not adjacency[id].has(n): connect_rooms(id, n, edges, adjacency)
					merged.append([id, n])
	var distances := distance_map(adjacency, 0)
	var farthest := 0
	for d in distances: farthest = maxi(farthest, d)
	var exits: Array[int] = []
	for i in count:
		if distances[i] >= maxi(8, int(ceil(farthest * 0.85))): exits.append(i)
	var exit_id: int = exits[rng.randi_range(0, exits.size() - 1)] if not exits.is_empty() else count - 1
	merged = merged.filter(func(edge): return not edge.has(exit_id))
	rooms[exit_id].hall = -1
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
		if room.id == exit_id: room.type = 19
		room["variant"] = decoration.randi_range(0, 3)
		if room.hall >= 0: room.type = [5, 6, 17, 18][int(room.hall) % 4]
		room["layout"] = decoration.randi_range(0, 3)
		room["height"] = 4.8 if room.hall >= 0 else 4.2 if room.type in [0, 5, 6, 17, 18] else 3.15
		room["cover_slots"] = 4
		for slot in 4:
			var kind: String = FLOOR.RECIPES[room.type][slot]
			var rotation := decoration.randi_range(0, 3)
			if kind in ["bed", "sofa", "desk", "tv", "reception", "washer", "basin", "shelf"]: rotation = 0 if slot < 2 else 2
			if kind in ["wardrobe", "curtain"]: rotation = 1 if slot % 2 == 0 else 3
			room.props.append({"kind": kind, "slot": slot, "rotation": rotation})
	return {"version": FLOOR.VERSION, "seed": run_seed, "attempt": attempt, "width": width, "height": height, "start": 0, "exit": exit_id, "rooms": rooms, "edges": edges, "adjacency": adjacency, "ambient_seed": run_seed + 4000037, "merged": merged}

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
