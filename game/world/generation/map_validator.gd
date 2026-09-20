extends RefCounted
const FLOOR := preload("res://game/world/generation/floor_definition.gd")

func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var rooms: Array = data.rooms
	var graph: Array = data.adjacency
	if rooms.size() < 100 or rooms.size() > 140: errors.append("module_count")
	if data.start == data.exit: errors.append("same_exit")
	if data.edges.size() - rooms.size() + 1 < 4: errors.append("cycles")
	var visited := {int(data.start): true}
	var queue: Array = [int(data.start)]
	var cursor := 0
	while cursor < queue.size():
		var current: int = queue[cursor]
		cursor += 1
		for neighbor in graph[current]:
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	if visited.size() != rooms.size() or not visited.has(int(data.exit)): errors.append("connectivity")
	errors.append_array(wings(data))
	var occupied := {}
	for room in rooms:
		var key := "%d:%d" % [room.x, room.z]
		if occupied.has(key): errors.append("overlap")
		occupied[key] = true
		if room.cover_slots < 4: errors.append("cover")
		var slots := {}
		for prop in room.props:
			if prop.slot < 0 or prop.slot > 3 or slots.has(prop.slot): errors.append("prop_socket")
			slots[prop.slot] = true
	for edge in data.edges:
		var a: Dictionary = rooms[edge[0]]
		var b: Dictionary = rooms[edge[1]]
		if abs(a.x - b.x) + abs(a.z - b.z) != 1: errors.append("connector")
	for room in rooms:
		for step in [1, int(data.width)]:
			var straight := true
			for offset in 4:
				var id: int = room.id + offset * step
				if id >= rooms.size() or (step == 1 and id / int(data.width) != int(room.id) / int(data.width)):
					straight = false
					break
				if rooms[id].type not in [11, 12]: straight = false
			if straight: errors.append("corridor_chain")
	return errors

# Run after physics synchronization, in addition to graph validation. Capsule
# sweeps cover every connector and four furnished-room escape lanes.
func validate_physics(world: World3D, data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	for room in data.rooms:
		var center := FLOOR.position_of(room) + Vector3(0, 0.94, 0)
		query.transform = Transform3D(Basis.IDENTITY, center)
		query.motion = Vector3.ZERO
		if not world.direct_space_state.intersect_shape(query).is_empty(): errors.append("center_%d" % room.id)
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

## Wings: three bands of rooms that share no way through except one door each,
## the gate of that stage, in the room that is its refuge. A floor that failed
## this would let players walk into the next stage before closing this one, or
## strand them in a wing with no way on.
func wings(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var rooms: Array = data.rooms
	var gates: Array = data.get("gates", [])
	var refuges: Array = data.get("refuges", [])
	var count: int = int(data.get("wings", 3))
	if gates.size() != count or refuges.size() != count:
		errors.append("gate_count")
		return errors
	var crossings := {}
	for gate in gates:
		if int(gate.get("beyond", -1)) >= 0: crossings["%d:%d" % [mini(int(gate.room), int(gate.beyond)), maxi(int(gate.room), int(gate.beyond))]] = true
	for edge in data.edges:
		var a: int = int(edge[0])
		var b: int = int(edge[1])
		if int(rooms[a].wing) == int(rooms[b].wing): continue
		if not crossings.has("%d:%d" % [mini(a, b), maxi(a, b)]): errors.append("wing_leak_%d_%d" % [a, b])
	# Every wing is one piece on its own, without its gate.
	for wing in count:
		var members: Array[int] = []
		for room in rooms:
			if int(room.wing) == wing: members.append(int(room.id))
		if members.size() < 20:
			errors.append("wing_small_%d" % wing)
			continue
		var seen := {members[0]: true}
		var queue: Array[int] = [members[0]]
		var cursor := 0
		while cursor < queue.size():
			var current: int = queue[cursor]
			cursor += 1
			for neighbor in data.adjacency[current]:
				if int(rooms[neighbor].wing) == wing and not seen.has(neighbor):
					seen[neighbor] = true
					queue.append(neighbor)
		if seen.size() != members.size(): errors.append("wing_split_%d" % wing)
		var refuge: int = int(refuges[wing])
		if int(rooms[refuge].wing) != wing: errors.append("refuge_wing_%d" % wing)
		elif not seen.has(refuge): errors.append("refuge_unreachable_%d" % wing)
	return errors
