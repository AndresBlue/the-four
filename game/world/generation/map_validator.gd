extends RefCounted
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## What the generator promises of a planta (map_generator.gd): its rooms,
## counted as the game counts them, how far anything runs straight and open,
## how many rings there are to walk round, and the sets of the stages played
## on televisions.
const ROOMS_LEAST := 81
const ROOMS_MOST := 99
const OPEN_RUN := 45.0
const CYCLES := 6
const TV_ROOMS := 8

func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var rooms: Array = data.rooms
	var count := int(data.get("wings", FLOOR.PLANTAS))
	var grids: Array = data.get("plantas", [])
	var cells := 0
	for grid in grids: cells += int(grid.width) * int(grid.height)
	if grids.size() != count or rooms.size() != cells or data.adjacency.size() != rooms.size():
		errors.append("module_count")
		return errors
	if int(data.start) == int(data.exit): errors.append("same_exit")
	# Every cell where its planta's grid says, and a void is nothing: no door,
	# nothing in it.
	for index in rooms.size():
		var room: Dictionary = rooms[index]
		var grid: Dictionary = grids[clampi(int(room.wing), 0, count - 1)]
		if int(room.id) != index or index != int(grid.base) + int(room.z) * int(grid.width) + int(room.x) or int(room.get("cols", -1)) != int(grid.width) or int(room.get("rows", -1)) != int(grid.height): errors.append("grid_%d" % index)
		if FLOOR.is_void(room):
			if not data.adjacency[index].is_empty() or not room.props.is_empty(): errors.append("void_%d" % index)
			continue
		if room.get("kind", "module") == "module" and not bool(room.corridor) and int(room.cover_slots) < 4: errors.append("cover")
		var slots := {}
		for prop in room.props:
			if prop.slot < 0 or prop.slot > 3 or slots.has(prop.slot): errors.append("prop_socket")
			slots[prop.slot] = true
	for edge in data.edges:
		var a: Dictionary = rooms[edge[0]]
		var b: Dictionary = rooms[edge[1]]
		# Nothing joins one planta to another: no door, no stair, only the lift.
		if int(a.wing) != int(b.wing): errors.append("wing_leak_%d_%d" % [a.id, b.id])
		elif absi(int(a.x) - int(b.x)) + absi(int(a.z) - int(b.z)) != 1: errors.append("connector")
	errors.append_array(plantas(data))
	errors.append_array(open_runs(data))
	errors.append_array(lifts(data))
	return errors

## Each planta: of a piece from where it is walked into, between 81 and 99
## rooms, rings to walk round, its refuge entered by one door and its lift
## lobby by none but the refuge's locked one, and on the plantas of the second
## and third stages the sets those stages are played on.
func plantas(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var rooms: Array = data.rooms
	var gates: Array = data.get("gates", [])
	var refuges: Array = data.get("refuges", [])
	var entries: Array = data.get("entries", [])
	var count := int(data.get("wings", FLOOR.PLANTAS))
	if gates.size() != count or refuges.size() != count or entries.size() != count:
		errors.append("gate_count")
		return errors
	for planta in count:
		var base := int(data.plantas[planta].base)
		var per := int(data.plantas[planta].width) * int(data.plantas[planta].height)
		var entry := int(entries[planta])
		var refuge := int(refuges[planta])
		var lobby := int(gates[planta].get("beyond", -1))
		if entry < base or entry >= base + per or FLOOR.is_void(rooms[entry]):
			errors.append("entry_%d" % planta)
			continue
		var seen := {entry: true}
		var queue: Array = [entry]
		var cursor := 0
		while cursor < queue.size():
			var current: int = queue[cursor]
			cursor += 1
			for neighbor in data.adjacency[current]:
				if not seen.has(neighbor):
					seen[neighbor] = true
					queue.append(neighbor)
		var members := 0
		var doors := 0
		var counted := 0
		var halls := {}
		var sets := 0
		var split := false
		for local in per:
			var room: Dictionary = rooms[base + local]
			if FLOOR.is_void(room): continue
			members += 1
			doors += data.adjacency[base + local].size()
			if not seen.has(base + local): split = true
			if room.get("kind", "module") != "module" or bool(room.get("landing", false)) or (planta > 0 and base + local == entry): continue
			if int(room.hall) >= 0:
				if halls.has(int(room.hall)): continue
				halls[int(room.hall)] = true
			counted += 1
			if base + local != refuge and room.props.any(func(prop): return prop.kind == "tv"): sets += 1
		if split: errors.append("planta_split_%d" % planta)
		if counted < ROOMS_LEAST or counted > ROOMS_MOST: errors.append("rooms_%d_%d" % [planta, counted])
		if doors / 2 - members + 1 < CYCLES: errors.append("cycles_%d" % planta)
		if refuge < base or refuge >= base + per: errors.append("refuge_wing_%d" % planta)
		elif not seen.has(refuge): errors.append("refuge_unreachable_%d" % planta)
		else:
			var ways: Array = data.adjacency[refuge].filter(func(id): return int(id) != lobby)
			if ways.size() != 1: errors.append("refuge_doors_%d" % planta)
		if lobby < 0 or data.adjacency[lobby].size() != 1 or int(data.adjacency[lobby][0]) != refuge or not bool(rooms[lobby].get("landing", false)): errors.append("lobby_%d" % planta)
		if planta > 0 and sets < TV_ROOMS: errors.append("few_televisions_%d_%d" % [planta, sets])
	return errors

## Nothing runs straight and open for longer than OPEN_RUN, corridor or salon:
## along every row and every column, the cells with no wall between them.
func open_runs(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var open := {}
	for pair in data.get("merged", []): open[Vector2i(int(pair[0]), int(pair[1]))] = true
	for grid in data.plantas:
		var base := int(grid.base)
		var width := int(grid.width)
		var height := int(grid.height)
		for across in [true, false]:
			for line in (height if across else width):
				var run := 0.0
				var previous := -1
				for along in (width if across else height):
					var id: int = base + (line * width + along if across else along * width + line)
					var room: Dictionary = data.rooms[id]
					var size: float = float(room.span_x) if across else float(room.span_z)
					if previous >= 0 and open.has(Vector2i(previous, id)): run += size
					else: run = size
					if run > OPEN_RUN + 0.01: errors.append("open_run_%d" % id)
					previous = id
	return errors

## Each lift goes down to the lobby straight under its car, and nothing opens
## on to that lobby from the side the car stands against.
func lifts(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var entries: Array = data.get("entries", [])
	for gate in data.get("gates", []):
		var arrive := int(gate.get("arrive", -1))
		if arrive < 0: continue
		var beyond := int(gate.beyond)
		var from: Vector3 = FLOOR.position_of(data.rooms[beyond])
		var to: Vector3 = FLOOR.position_of(data.rooms[arrive])
		if Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z)) > 0.001 or int(data.rooms[arrive].wing) != int(data.rooms[beyond].wing) + 1: errors.append("lift_%d" % int(gate.stage))
		# And the same size: the car stands against the same wall below.
		if absf(float(data.rooms[arrive].span_x) - float(data.rooms[beyond].span_x)) > 0.001 or absf(float(data.rooms[arrive].span_z) - float(data.rooms[beyond].span_z)) > 0.001: errors.append("lift_size_%d" % int(gate.stage))
		if int(gate.stage) < entries.size() and arrive != int(entries[int(gate.stage)]): errors.append("lift_entry_%d" % int(gate.stage))
		var out := Vector2i(int(gate.out[0]), int(gate.out[1]))
		var behind := FLOOR.beside(data.rooms[arrive], out)
		if behind >= 0 and data.adjacency[arrive].has(behind): errors.append("lift_back_%d" % int(gate.stage))
	return errors

# Run after physics synchronization, in addition to graph validation. Capsule
# sweeps cover every connector and, in rooms, four furnished-room escape lanes.
func validate_physics(world: World3D, data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	for room in data.rooms:
		if FLOOR.is_void(room): continue
		var center := FLOOR.position_of(room) + Vector3(0, 0.94, 0)
		query.transform = Transform3D(Basis.IDENTITY, center)
		query.motion = Vector3.ZERO
		if not world.direct_space_state.intersect_shape(query).is_empty(): errors.append("center_%d" % room.id)
		# A corridor is a lane of three or four metres: its walls are there.
		if bool(room.get("corridor", false)): continue
		for corner in [Vector3(-2.2, 0, -2.2), Vector3(2.2, 0, -2.2), Vector3(-2.2, 0, 2.2), Vector3(2.2, 0, 2.2)]:
			query.motion = corner
			var result := world.direct_space_state.cast_motion(query)
			if result[0] < 0.99: errors.append("cover_access_%d" % room.id)
		if room.type in [1, 2, 3, 4, 7, 15, 16]:
			for side in [-1, 1]:
				for end in [-1, 1]:
					query.transform = Transform3D(Basis.IDENTITY, center + Vector3(0, 0, end * 4.4))
					query.motion = Vector3(side * 3.0, 0, 0)
					if world.direct_space_state.cast_motion(query)[0] < 0.99: errors.append("alcove_entrance_%d" % room.id)
		if room.type != 19:
			for spot in FLOOR.hiding_positions(room):
				var approach := FLOOR.hiding_approach(spot)
				query.transform = Transform3D(Basis.IDENTITY, center)
				query.motion = approach
				if world.direct_space_state.cast_motion(query)[0] < 0.99: errors.append("hide_approach_%d" % room.id)
				query.transform = Transform3D(Basis.IDENTITY, center + approach)
				query.motion = spot - approach
				if world.direct_space_state.cast_motion(query)[0] < 0.99: errors.append("hide_entry_%d" % room.id)
	for edge in data.edges:
		var a: Dictionary = data.rooms[edge[0]]
		var b: Dictionary = data.rooms[edge[1]]
		query.transform = Transform3D(Basis.IDENTITY, FLOOR.position_of(a) + Vector3(0, 0.94, 0))
		query.motion = FLOOR.position_of(b) - FLOOR.position_of(a)
		if world.direct_space_state.cast_motion(query)[0] < 0.99: errors.append("passage_%d_%d" % [a.id, b.id])
	return errors
