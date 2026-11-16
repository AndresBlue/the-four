extends RefCounted
## The coffee machines (the author, 16 November 2026): three to five a floor,
## more on a bigger one, spread over its plantas, in its wide rooms (where it
## starts, the halls and lobbies, the big salons; on floor 2 its break rooms
## first), each with its back against a stretch of wall. A cup for each
## survivor at each machine: a few seconds after it, "Te sientes mejor..." at
## the foot of the picture, and the mind comes back whole over a second. The
## machine that runs the floor keeps every mind (sanity.gd), so the cup is
## asked of it (match_net.drink_coffee()).
##
## Placed from the built floor and the seed, the same on every machine, and
## nothing of it in the manifest: the hotel's (manifest_golden_test) stays.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const MACHINE := preload("res://game/world/interactables/coffee_machine.gd")
## Seconds from the cup to feeling it, and that it takes the mind to come back.
const BREW := 2.5
const EASE := 1.0
const FEEL := "Te sientes mejor..."
const FEEL_FOR := 3.5
## What it sounds like making it: for now the copier's hum, cut short.
const SOUND := "res://assets/audio/sfx/office/copier.wav"
## Its back this far from the wall's line, and free this much to each side;
## and this far from any door, so no way through a room is narrowed by it
## (office_test's physical check found one on an office floor's way out);
## and from the ducts' low grilles, which need a clear metre in front.
const INSET := 0.56
const SIDE := 0.75
const DOOR_CLEAR := 2.0
## And from wall lamps: the hotel hangs its paintings between two of them.
const LAMP_CLEAR := 1.3
var level
var machines: Array = []
## This machine's own cup on its way: seconds left (-1 none), and the mind as
## it was, for the ease back.
var brewing := -1.0
var easing := -1.0
var eased_from := 0.0
## The host's: each seat's mind coming back, [from, seconds so far].
var restoring := {}

## A floor about to be played (populate_floor).
func place() -> void:
	for machine in machines:
		if is_instance_valid(machine): machine.queue_free()
	machines.clear()
	restoring.clear()
	brewing = -1.0
	easing = -1.0
	var manifest: Dictionary = level.manifest
	if manifest.is_empty() or not is_instance_valid(level.hotel): return
	var count := clampi(roundi(manifest.rooms.size() / 100.0) + 1, 3, 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(manifest.get("seed", 0)), "coffee"])
	# By planta, best first; the plantas take turns, so each one has its own.
	var by_wing := {}
	for room in candidates(manifest): by_wing.get_or_add(int(room.get("wing", 0)), []).append(room)
	var wings: Array = by_wing.keys()
	wings.sort()
	var turn := 0
	var tried := 0
	while machines.size() < count and tried < 400 and not wings.is_empty():
		var list: Array = by_wing[wings[turn % wings.size()]]
		turn += 1
		tried += 1
		if list.is_empty():
			if by_wing.values().all(func(rest): return rest.is_empty()): break
			continue
		var spot := free_spot(list.pop_front(), rng)
		if spot.is_empty(): continue
		var machine := MACHINE.new()
		machine.name = "Coffee_%d" % machines.size()
		machine.position = spot.position
		machine.rotation.y = spot.yaw
		level.hotel.add_child(machine)
		machines.append(machine)

## The rooms a machine may go in, best first.
func candidates(manifest: Dictionary) -> Array:
	var palette: Dictionary = FLOOR.palette(manifest).get_script_constant_map()
	var start := int(manifest.get("start", -1))
	var rooms: Array = []
	for room in manifest.rooms:
		if FLOOR.is_void(room) or bool(room.get("corridor", false)) or bool(room.get("landing", false)): continue
		if int(room.type) == int(palette.get("REFUGE", -1)) or int(room.type) == int(palette.get("CORRIDOR", 11)): continue
		if float(room.get("span_x", 0.0)) < 3.5 or float(room.get("span_z", 0.0)) < 3.5: continue
		rooms.append(room)
	var rank := func(room: Dictionary) -> float:
		var type := int(room.type)
		var best := 0.0
		if int(room.id) == start: best = 3.0
		elif palette.has("BREAK_ROOM"): best = 3.0 if type == int(palette.BREAK_ROOM) else (1.0 if type == int(palette.get("RECEPTION", -1)) else 0.0)
		elif int(room.get("hall", -1)) >= 0 or type in palette.get("HALL_ROOMS", []) or type == int(palette.get("LOBBY", -1)): best = 2.0
		return best * 1000.0 + float(room.span_x) * float(room.span_z)
	rooms.sort_custom(func(a, b): return rank.call(a) > rank.call(b))
	return rooms

## Somewhere along the room's walls with wall behind and to either side (not a
## doorway), nothing in the way, a floor to stand on in front, and no other
## machine near: {position, yaw}, or nothing.
func free_spot(room: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var centre := FLOOR.position_of(room)
	var half := Vector2(float(room.span_x), float(room.span_z)) * 0.5
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var map: RID = level.get_world_3d().navigation_map
	var lamps: Array = Array(level.hotel.sconce_spots) if "sconce_spots" in level.hotel else []
	var grilles: Array = []
	for exit in level.manifest.get("ducts", {}).get("exits", []):
		if String(exit.get("kind", "")) == "wall":
			var at = exit.point
			grilles.append(at if at is Vector3 else Vector3(float(at[0]), float(at[1]), float(at[2])))
	var tries: Array = []
	for side in 4:
		for share in [0.5, 0.3, 0.7, 0.2, 0.8]: tries.append([side, share])
	for i in range(tries.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = tries[i]
		tries[i] = tries[j]
		tries[j] = swap
	for attempt in tries:
		var side: int = attempt[0]
		var share: float = attempt[1]
		# Outward from the room to the wall, and along it.
		var out: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][side]
		var along := Vector3(out.z, 0, out.x)
		var reach: float = half.x if side < 2 else half.y
		var length: float = half.y if side < 2 else half.x
		var point: Vector3 = centre + out * (reach - INSET) + along * (share - 0.5) * 2.0 * maxf(length - 1.0, 0.0)
		if machines.any(func(machine): return machine.global_position.distance_to(point) < 2.5): continue
		if level.hotel.doors.any(func(door): return is_instance_valid(door) and Vector2(door.global_position.x - point.x, door.global_position.z - point.z).length() < DOOR_CLEAR): continue
		# Nor over a wall lamp, nor the painting the hotel hangs between two.
		if lamps.any(func(lamp: Vector3): return Vector2(lamp.x - point.x, lamp.z - point.z).length() < LAMP_CLEAR and absf(lamp.y - point.y) < 3.0): continue
		# Nor in front of a low grille of the ducts (her way out on floor 2).
		if grilles.any(func(grille: Vector3): return Vector2(grille.x - point.x, grille.z - point.z).length() < DOOR_CLEAR and absf(grille.y - point.y) < 2.0): continue
		var walled := true
		for offset in [Vector3(0, 0.6, 0), Vector3(0, 1.4, 0), along * SIDE + Vector3(0, 1.0, 0), -along * SIDE + Vector3(0, 1.0, 0)]:
			var ray := PhysicsRayQueryParameters3D.create(point + offset, point + offset + out * (INSET + 0.4), 1)
			if space.intersect_ray(ray).is_empty(): walled = false
		if not walled: continue
		var query := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 1.5, 0.8)
		query.shape = box
		query.transform = Transform3D(Basis(Vector3.UP, atan2(-out.x, -out.z)), point + Vector3(0, 0.95, 0))
		query.collision_mask = 1 | 8
		if not space.intersect_shape(query, 1).is_empty(): continue
		var front: Vector3 = point - out * 0.95
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			var stand := NavigationServer3D.map_get_closest_point(map, front)
			if Vector2(stand.x - front.x, stand.z - front.z).length() > 0.4 or absf(stand.y - front.y) > 0.6: continue
		return {"position": point, "yaw": atan2(-out.x, -out.z)}
	return {}

func can_drink(machine: Node) -> bool:
	return brewing < 0.0 and not machine.served.has(int(level.player.slot))

## This survivor's cup.
func drink(machine: Node) -> void:
	if not can_drink(machine): return
	machine.served[int(level.player.slot)] = true
	brewing = BREW
	if level.world_audio.enabled: level.world_audio.play_long(SOUND, machine.global_position + Vector3(0, 1.0, 0), -6.0, RID(), false, BREW)
	level.match_net.drink_coffee(machines.find(machine))

## The host's: that seat's cup, felt BREW seconds on, as its own machine does.
func serve(seat: int, index: int) -> void:
	if index >= 0 and index < machines.size(): machines[index].served[seat] = true
	restoring[seat] = [-BREW, 0.0]

## Every frame of play (hotel_main, after the minds are worn).
func tick(delta: float) -> void:
	if brewing >= 0.0:
		brewing -= delta
		if brewing < 0.0:
			level.hints.notice(FEEL, FEEL_FOR)
			easing = 0.0
			eased_from = level.player.sanity
	if easing >= 0.0:
		easing += delta
		# A guest eases its own picture; the host's meter catches it up.
		if level.net.is_client(): level.player.sanity = lerpf(eased_from, 100.0, clampf(easing / EASE, 0.0, 1.0))
		if easing >= EASE: easing = -1.0
	for seat in restoring.keys():
		var row: Array = restoring[seat]
		row[1] = float(row[1]) + delta
		var since: float = float(row[1]) - BREW
		if since < 0.0: continue
		if float(row[0]) < 0.0: row[0] = mind(seat)
		set_mind(seat, lerpf(float(row[0]), 100.0, clampf(since / EASE, 0.0, 1.0)))
		if since >= EASE: restoring.erase(seat)

func mind(seat: int) -> float:
	if seat == int(level.player.slot): return level.player.sanity
	return float(level.sanity.minds.get(seat, {"sanity": 100.0}).sanity)

func set_mind(seat: int, value: float) -> void:
	if seat == int(level.player.slot): level.player.sanity = value
	elif level.sanity.minds.has(seat): level.sanity.minds[seat].sanity = value
