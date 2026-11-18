extends RefCounted
## The coffee machines (the author, 16 November 2026): three to five a floor,
## more on a bigger one, spread over its plantas, in its wide rooms (where it
## starts, the halls and lobbies, the big salons; on floor 2 its break rooms
## first), each with its back against a stretch of wall. A cup for each
## survivor at each machine: a few seconds after it the mind comes back whole
## over a second, and the picture says so (nothing is written since 16
## November 2026: the author wants no explaining while a floor is played). The
## machine that runs the floor keeps every mind (sanity.gd), so the cup is
## asked of it (match_net.drink_coffee()). In the offices (the author, 18
## November 2026) they are the only way a mind comes back: two a planta
## (place_offices()), and the cup says "Te sientes mejor..." when it is felt.
##
## Placed from the built floor and the seed, the same on every machine, and
## nothing of it in the manifest: the hotel's (manifest_golden_test) stays.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const MACHINE := preload("res://game/world/interactables/coffee_machine.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
## Seconds from the cup to feeling it, and that it takes the mind to come back.
const BREW := 2.5
const EASE := 1.0
## How many of the rooms nearest the way in, and of the farthest, are tried
## for a corner before a wall's middle.
const NEAR_CORNERS := 8
const FAR_CORNERS := 40
## What the offices say when it is felt.
const FELT := "Te sientes mejor..."
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
## And from a lift's doors: they are no door of `hotel.doors`, and a machine
## stood in front of the reception's (the author, 17 November 2026).
const LIFT_CLEAR := 2.4
## Tucked into a corner as an office has one (the author, 17 November 2026): a
## side this far off the wall beside it; mid wall only where no corner is free.
## Never over what hangs on its wall (hotel_geometry.hung) up to a hand over its
## top, nor this near in plan to something run down the wall (a pneumatic
## tube, a duct's drop).
const CORNER_GAP := 0.15
const OVER_TOP := 0.1
const DROP_CLEAR := 0.6
const STAND := 0.6
const WAY_BY := 0.65
## The machine's half width and half depth in plan.
const HALF := Vector2(MACHINE.SIZE.x, MACHINE.SIZE.z) * 0.5
var level
## The floor's upright runs (drops()), found once a floor.
var drop_spots: Array = []
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
	drop_spots = drops(manifest)
	# By the floor's size (manifest.area: 0.5 for one survivor, 1 for two or
	# three, 1.2 and 1.35 for four and five): 3, 4 or 5.
	var size := float(manifest.get("area", 1.0))
	var count := 3 if size < 0.75 else 4 if size < 1.1 else 5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(manifest.get("seed", 0)), "coffee"])
	if FLOOR.palette(manifest).get_script_constant_map().has("BREAK_ROOM"):
		place_offices(manifest, rng)
		return
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
		if not spot.is_empty(): put(spot)

func put(spot: Dictionary) -> void:
	var machine := MACHINE.new()
	machine.name = "Coffee_%d" % machines.size()
	machine.position = spot.position
	machine.rotation.y = spot.yaw
	level.hotel.add_child(machine)
	machines.append(machine)

## The offices (the author, 18 November 2026: no mind comes back in the light
## there, only with a cup): two a planta, one where it is walked into (or as
## near it as one goes) and one in the rooms farthest by the doors from that
## and from its landmarks, the far corner of the plan. Each in a corner of its
## room where one of the first rooms tried has one (the author, 17 November).
func place_offices(manifest: Dictionary, rng: RandomNumberGenerator) -> void:
	# Rooms of their own: a salon's cell has an open side where a corner looks to be.
	# Nor behind planta 3's electric locks: a cup nobody could reach.
	var shut: Array = manifest.get("air", {}).get("cams", []).map(func(cam): return int(cam.room))
	var rooms: Array = candidates(manifest).filter(func(room): return int(room.get("hall", -1)) < 0 and not shut.has(int(room.id)))
	for planta in FLOOR.PLANTAS:
		var entry := FLOOR.entry_of(manifest, planta)
		var from_entry := FLOOR.route_metres(manifest, entry)
		var near: Array = rooms.filter(func(room): return int(room.get("wing", -1)) == planta and from_entry.has(int(room.id)))
		near.sort_custom(func(a, b): return float(from_entry[int(a.id)]) < float(from_entry[int(b.id)]))
		var arrival: Array = [manifest.rooms[entry]] if entry >= 0 and entry < manifest.rooms.size() else []
		# Never in a landmark (planta 2's maneuver room lies back toward the arrival).
		pick(arrival + near.filter(func(room): return not is_landmark(manifest, int(room.id))), NEAR_CORNERS, rng)
		var away: Array = [from_entry]
		for landmark in landmarks(manifest, planta): away.append(FLOOR.route_metres(manifest, landmark))
		var far: Array = near.filter(func(room): return not is_landmark(manifest, int(room.id)))
		var score := func(room: Dictionary) -> float:
			var least := INF
			for metres: Dictionary in away: least = minf(least, float(metres.get(int(room.id), 0.0)))
			return least
		far.sort_custom(func(a, b): return score.call(a) > score.call(b))
		pick(far, FAR_CORNERS, rng)

## A machine in the first of `rooms` with a corner free among the first
## `corners` of them, else in the first that takes one anywhere.
func pick(rooms: Array, corners: int, rng: RandomNumberGenerator) -> void:
	for room in rooms.slice(0, corners):
		var spot := free_spot(room, rng, true)
		if not spot.is_empty():
			put(spot)
			return
	for room in rooms:
		var spot := free_spot(room, rng)
		if not spot.is_empty():
			put(spot)
			return

## A planta's rooms that matter: its errand's and its way out.
func landmarks(manifest: Dictionary, planta: int) -> Array:
	var out: Array = []
	var refuges: Array = manifest.get("refuges", [])
	if planta < refuges.size(): out.append(int(refuges[planta]))
	match planta:
		0: out.append(int(manifest.get("mail", {}).get("window", -1)))
		1:
			out.append(int(manifest.get("power", {}).get("room", -1)))
			out.append(int(manifest.get("power", {}).get("maneuver", {}).get("room", -1)))
		2:
			var air: Dictionary = manifest.get("air", {})
			out.append(int(air.get("security", {}).get("room", -1)))
			out.append(int(air.get("room", -1)))
	return out.filter(func(id): return id >= 0)

func is_landmark(manifest: Dictionary, id: int) -> bool:
	for planta in FLOOR.PLANTAS:
		if landmarks(manifest, planta).has(id) or FLOOR.entry_of(manifest, planta) == id: return true
	return false

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
## doorway), nothing in the way nor hung behind, a floor to stand on in front,
## and no other machine near: a corner first, then mid wall. {position, yaw},
## or nothing.
func free_spot(room: Dictionary, rng: RandomNumberGenerator, corners_only := false) -> Dictionary:
	var half := FLOOR.size_of(room) * 0.5
	# [side, along]: each corner of each wall, then shares of the wall, each lot in its own order.
	var middles: Array = []
	for side in 4:
		var length: float = half.y if side < 2 else half.x
		for share: float in [0.5, 0.3, 0.7, 0.2, 0.8]: middles.append([side, (share - 0.5) * 2.0 * maxf(length - 1.0, 0.0)])
	var tries: Array = []
	for lot: Array in ([corners(room)] if corners_only else [corners(room), middles]):
		for i in range(lot.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap = lot[i]
			lot[i] = lot[j]
			lot[j] = swap
		tries.append_array(lot)
	for attempt in tries:
		var spot := spot_at(room, int(attempt[0]), float(attempt[1]))
		if not spot.is_empty(): return spot
	return {}

## A room's corner spots, [side, along], CORNER_GAP off the wall beside.
func corners(room: Dictionary) -> Array:
	var half := FLOOR.size_of(room) * 0.5
	var out: Array = []
	for side in 4:
		var length: float = half.y if side < 2 else half.x
		for end: float in [-1.0, 1.0]: out.append([side, end * (length - 0.09 - CORNER_GAP - HALF.x)])
	return out

## The spot `along` the wall on `side` (0 east, 1 west, 2 south, 3 north) if it
## takes a machine, {position, yaw}; else {}. `ignore`, a machine left out of
## the reckoning (coffee_test asks whether its corner was free).
func spot_at(room: Dictionary, side: int, along_at: float, ignore: Node = null) -> Dictionary:
	var centre := FLOOR.position_of(room)
	var half := FLOOR.size_of(room) * 0.5
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var map: RID = level.get_world_3d().navigation_map
	var lamps: Array = Array(level.hotel.sconce_spots) if "sconce_spots" in level.hotel else []
	var grilles: Array = []
	for exit in level.manifest.get("ducts", {}).get("exits", []):
		if String(exit.get("kind", "")) == "wall": grilles.append(as_point(exit.point))
	# Outward from the room to the wall, and along it.
	var out: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][side]
	var along := Vector3(out.z, 0, out.x)
	var reach: float = half.x if side < 2 else half.y
	var length: float = half.y if side < 2 else half.x
	var point: Vector3 = centre + out * (reach - INSET) + along * along_at
	if machines.any(func(machine): return machine != ignore and machine.global_position.distance_to(point) < 2.5): return {}
	if level.hotel.doors.any(func(door): return is_instance_valid(door) and Vector2(door.global_position.x - point.x, door.global_position.z - point.z).length() < DOOR_CLEAR): return {}
	# Nor over a wall lamp, nor the painting the hotel hangs between two.
	if lamps.any(func(lamp: Vector3): return Vector2(lamp.x - point.x, lamp.z - point.z).length() < LAMP_CLEAR and absf(lamp.y - point.y) < 3.0): return {}
	if lift_fronts(room).any(func(lift: Vector3): return Vector2(lift.x - point.x, lift.z - point.z).length() < LIFT_CLEAR): return {}
	# Nor in front of a low grille of the ducts (her way out on floor 2).
	if grilles.any(func(grille: Vector3): return Vector2(grille.x - point.x, grille.z - point.z).length() < DOOR_CLEAR and absf(grille.y - point.y) < 2.0): return {}
	if covers_hung(point, out, along): return {}
	if drop_spots.any(func(drop: Vector3): return absf(drop.y - point.y) < 2.5 and drop_gap(point, out, along, drop) < DROP_CLEAR): return {}
	# Wall behind it, and beyond either side but where the wall beside it comes first.
	var face := length - 0.09
	for probe in [Vector3(0, 0.6, 0), Vector3(0, 1.4, 0), along * minf(SIDE, face - along_at - 0.05) + Vector3(0, 1.0, 0), -along * minf(SIDE, face + along_at - 0.05) + Vector3(0, 1.0, 0)]:
		var ray := PhysicsRayQueryParameters3D.create(point + probe, point + probe + out * (INSET + 0.4), 1)
		if space.intersect_ray(ray).is_empty(): return {}
	# Nothing within a way past its sides (WAY_BY, less where the wall beside it
	# comes first) nor in a body's room before it to use it (STAND): tucked by the
	# head of a boardroom's table it cut the way round it.
	var plus := minf(WAY_BY, face - along_at - HALF.x - 0.05)
	var minus := minf(WAY_BY, face + along_at - HALF.x - 0.05)
	# The same in plan against the room's furniture as laid (office_recipes.gd): a
	# table's collider is not all of its footprint.
	var local := Vector2(point.x - centre.x, point.z - centre.z)
	var way := Rect2(local, Vector2.ZERO)
	for a: float in [-HALF.x - minus, HALF.x + plus]:
		for d: float in [-HALF.y - STAND, HALF.y]: way = way.expand(local + Vector2(along.x, along.z) * a + Vector2(out.x, out.z) * d)
	if room.get("furniture", []).any(func(it: Dictionary) -> bool: return LAYOUT.footprint(it).grow(-0.01).intersects(way)): return {}
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF.x * 2.0 + plus + minus, 1.5, 0.8 + STAND)
	query.shape = box
	query.transform = Transform3D(Basis(Vector3.UP, atan2(-out.x, -out.z)), point + along * (plus - minus) * 0.5 - out * STAND * 0.5 + Vector3(0, 0.95, 0))
	query.collision_mask = 1 | 8
	if ignore != null:
		for body in ignore.find_children("*", "StaticBody3D", false, false): query.exclude = [body.get_rid()]
	if not space.intersect_shape(query, 1).is_empty(): return {}
	var front: Vector3 = point - out * 0.95
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		var stand := NavigationServer3D.map_get_closest_point(map, front)
		if Vector2(stand.x - front.x, stand.z - front.z).length() > 0.4 or absf(stand.y - front.y) > 0.6: return {}
	return {"position": point, "yaw": atan2(-out.x, -out.z)}

## Whether a machine at `point`, its back toward `out`, would stand in front of
## something hung on that wall (hotel_geometry.hung) lower than its top and a
## hand: a picture, a board, a sign, a switch or a socket.
func covers_hung(point: Vector3, out: Vector3, along: Vector3) -> bool:
	if not "hung" in level.hotel: return false
	for entry: Array in level.hotel.hung:
		var a: Vector3 = entry[0]
		var b: Vector3 = entry[1]
		if absf(a.y - point.y) > 1.0 or float(entry[2]) > point.y + MACHINE.SIZE.y + OVER_TOP: continue
		# On this room's face of the wall behind it: between the machine and the wall's line.
		var depth := ((a + b) * 0.5 - point).dot(out)
		if depth < 0.0 or depth > INSET: continue
		var from := minf((a - point).dot(along), (b - point).dot(along))
		var to := maxf((a - point).dot(along), (b - point).dot(along))
		if from < HALF.x + 0.05 and to > -HALF.x - 0.05: return true
	return false

## The plan distance from a machine at `point` (its back toward `out`) to an
## upright run at `drop`.
static func drop_gap(point: Vector3, out: Vector3, along: Vector3, drop: Vector3) -> float:
	var d := drop - point
	return Vector2(maxf(absf(d.dot(along)) - HALF.x, 0.0), maxf(absf(d.dot(out)) - HALF.y, 0.0)).length()

## Where something runs down a wall below the false ceiling, to the floor or
## to a mouth on it: each upright run of the manifest's networks (the pneumatic
## tubes, the ducts) at its foot, Vector3(x, y, z). None in the hotel.
static func drops(manifest: Dictionary) -> Array:
	var out: Array = []
	for key in ["tubes", "ducts"]:
		var net: Dictionary = manifest.get(key, {})
		var nodes: Array = net.get("nodes", [])
		for edge in net.get("edges", []):
			var a := as_point(nodes[int(edge[0])])
			var b := as_point(nodes[int(edge[1])])
			var foot := a if a.y < b.y else b
			# Upright, and down past where a false ceiling is (the plenum's own runs stay up there).
			if Vector2(a.x - b.x, a.z - b.z).length() < 0.05 and absf(a.y - b.y) > 0.3 and foot.y - FLOOR.planta_y(FLOOR.planta_of(foot.y)) < 2.4: out.append(foot)
	return out

static func as_point(at) -> Vector3:
	return at if at is Vector3 else Vector3(float(at[0]), float(at[1]), float(at[2]))

## Where the doors of the lifts in this room stand: the middle of a lobby's
## lift wall, and on floor 2 the hotel's lift arriving in the reception
## (office_geometry.arrival_lift(): its wall, slid along it).
func lift_fronts(room: Dictionary) -> Array:
	var out: Array = []
	var centre := FLOOR.position_of(room)
	var half := FLOOR.size_of(room) * 0.5
	var wall := FLOOR.lift_wall(room)
	if wall != Vector2i.ZERO: out.append(centre + Vector3(wall.x * half.x, 0, wall.y * half.y))
	var manifest: Dictionary = level.manifest
	if int(room.id) == int(manifest.get("start", -1)) and manifest.has("arrival_lift"):
		var back := Vector3(float(manifest.arrival_lift[0]), 0, float(manifest.arrival_lift[1]))
		var along := float(manifest.get("arrival_lift_along", 0.0))
		out.append(centre + Vector3(back.x * half.x, 0, back.z * half.y) + (Vector3.BACK if back.x != 0.0 else Vector3.RIGHT) * along)
	return out

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
			easing = 0.0
			eased_from = level.player.sanity
			# Where it is the only way back, the cup says so (the author, 18 November 2026).
			if FLOOR.palette(level.manifest).get_script_constant_map().has("BREAK_ROOM"): level.ui.flash(FELT, 3.0, true)
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
