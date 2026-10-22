extends RefCounted

## 5 stacked the three wings of before as plantas; 6 makes each planta a
## hotel of its own (map_generator.gd); 7 draws what is in it by seed: where
## each door stands in its wall and which way it swings, the wardrobes, the
## dark rooms and how kept each one is; 8 draws a floor the size of the
## survivors who play it (the palette's AREA). A checkpoint or a record of another version
## is refused rather than rebuilt as a different floor.
const VERSION := 8

## Each floor's palette, by its number (docs/OFICINAS.md 11.2): what its room
## types are. Here and not in game/floors/floor_index.gd, which preloads the
## floors' scripts and, through them, the generator that preloads this one.
const PALETTES := {1: preload("res://game/floors/palettes/hotel_palette.gd"), 2: preload("res://game/floors/palettes/office_palette.gd")}

## The palette of the floor a manifest is of: the hotel's for a manifest that
## does not say (the hotel's never do) or names a floor without one.
static func palette(manifest: Dictionary) -> GDScript:
	return PALETTES.get(int(manifest.get("floor", 1)), PALETTES[1])

## A floor is three plantas, one per stage, stacked and going down: the first
## at 0 and each next one PITCH below the one before. Enough for the tallest
## ceiling (the 4.8 m halls) and both slabs. What joins them is the lift, and
## nothing else: no stairs, no route a body could walk.
const PITCH := 6.0
const PLANTAS := 3
const CELL := 12.0
## Clear width of a doorway: a hotel door with room for the creature to pass.
const PORTAL := 1.3
## Door leaf width, a little narrower than the opening.
const LEAF_WIDTH := 1.2
## A cell of the grid a planta does not use: nothing is built there, nobody
## walks there. It stays in the list so a room's id is still its index.
const VOID := 20

static func is_void(room: Dictionary) -> bool:
	return int(room.get("type", 0)) == VOID

static func position_of(room: Dictionary) -> Vector3:
	return Vector3(room.get("px", room.x * CELL), float(room.get("py", 0.0)), room.get("pz", room.z * CELL))

static func planta_y(index: int) -> float:
	return -PITCH * float(index)

## The planta a height belongs to: from a metre under its floor up to the air
## under the slab of the one above.
static func planta_of(y: float) -> int:
	return clampi(int(floor((PITCH - 1.0 - y) / PITCH)), 0, PLANTAS - 1)

## A point brought down to the floor of its own planta. The navigation is one
## map for the three: left as it was, a lamp at the ceiling was nearer the
## floor of the planta above than its own, and a sound from it was routed up
## there.
static func floor_point(point: Vector3) -> Vector3:
	return Vector3(point.x, planta_y(planta_of(point.y)) + 0.3, point.z)

## The nearest walkable point on the point's own planta.
static func closest(map: RID, point: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(map, floor_point(point))

static func size_of(room: Dictionary) -> Vector2:
	return Vector2(room.get("span_x", CELL), room.get("span_z", CELL))

## How far in from the middle of the wall a lift's car backs on to its lobby's
## lift wall stands (hotel_geometry.lift_wall()): the car, 2.13 m deep, fits
## behind it with 20 cm to spare.
const LIFT_DEPTH := 2.34

## The wall of this lobby that its lift's car is behind (the gate's `out`,
## set by the generator on the lobby left and the one arrived at), or zero in
## any other room.
static func lift_wall(room: Dictionary) -> Vector2i:
	var lift: Array = room.get("lift", [])
	return Vector2i(int(lift[0]), int(lift[1])) if lift.size() == 2 else Vector2i.ZERO

## The module whose footprint contains a world point, on the planta the point
## is on, or {} outside the plan (and in a cell its planta does not use).
static func room_at(rooms: Array, point: Vector3) -> Dictionary:
	if rooms.is_empty(): return {}
	if not is_same(rooms, index_rooms): build_index(rooms)
	if grid_index.is_empty(): return scan(rooms, point)
	var grid: Dictionary = grid_index.get(planta_of(point.y), {})
	if grid.is_empty(): return {}
	var x := bisect(grid.xs, point.x)
	var z := bisect(grid.zs, point.z)
	if x < 0 or z < 0: return {}
	var id: int = int(grid.base) + z * int(grid.width) + x
	if id >= rooms.size() or is_void(rooms[id]): return {}
	return rooms[id]

## The cell next to a room on its planta's grid, one step `way` away, or -1
## off the grid.
static func beside(room: Dictionary, way: Vector2i) -> int:
	var x := int(room.x) + way.x
	var z := int(room.z) + way.y
	var cols := int(room.get("cols", 0))
	if x < 0 or z < 0 or x >= cols or z >= int(room.get("rows", 0)): return -1
	return int(room.id) + way.x + way.y * cols

## room_at's index of the last list of rooms it was asked about: per planta,
## where its grid starts in the list and where its columns and rows begin and
## end, so a point finds its cell by halving instead of going through several
## hundred rooms. {} when the list is not laid out as grids (then every room
## is looked at).
static var index_rooms: Array = []
static var grid_index := {}

static func build_index(rooms: Array) -> void:
	index_rooms = rooms
	grid_index = {}
	var index := {}
	var at := 0
	while at < rooms.size():
		var first: Dictionary = rooms[at]
		var width := int(first.get("cols", 0))
		var height := int(first.get("rows", 0))
		if width <= 0 or height <= 0 or int(first.get("id", -1)) != at or int(first.x) != 0 or int(first.z) != 0 or at + width * height > rooms.size(): return
		for local in width * height:
			var room: Dictionary = rooms[at + local]
			if int(room.id) != at + local or int(room.x) != local % width or int(room.z) != local / width or int(room.wing) != int(first.wing): return
		var xs: Array = []
		for x in width: xs.append(float(position_of(rooms[at + x]).x) - size_of(rooms[at + x]).x * 0.5)
		xs.append(float(position_of(rooms[at + width - 1]).x) + size_of(rooms[at + width - 1]).x * 0.5)
		var zs: Array = []
		for z in height: zs.append(float(position_of(rooms[at + z * width]).z) - size_of(rooms[at + z * width]).y * 0.5)
		zs.append(float(position_of(rooms[at + (height - 1) * width]).z) + size_of(rooms[at + (height - 1) * width]).y * 0.5)
		index[int(first.wing)] = {"base": at, "width": width, "height": height, "xs": xs, "zs": zs}
		at += width * height
	grid_index = index

## Which of the spans between consecutive edges holds the value, or -1 off
## both ends (an edge counts for the span on either side, as a footprint
## includes its border).
static func bisect(edges: Array, value: float) -> int:
	var last := edges.size() - 2
	if last < 0 or value < float(edges[0]) - 0.001 or value > float(edges[last + 1]) + 0.001: return -1
	var low := 0
	var high := last
	while low < high:
		var middle := (low + high + 1) / 2
		if float(edges[middle]) <= value: low = middle
		else: high = middle - 1
	return low

static func scan(rooms: Array, point: Vector3) -> Dictionary:
	var planta := planta_of(point.y)
	for room in rooms:
		if is_void(room): continue
		var center := position_of(room)
		if planta_of(center.y) != planta: continue
		var span := size_of(room)
		if absf(point.x - center.x) <= span.x * 0.5 and absf(point.z - center.z) <= span.y * 0.5: return room
	return {}

## Metres from a room to every room of its planta, walking centre to centre
## through the doors: how far in something is, which a straight line across a
## plan full of walls does not say. {id: metres}.
static func route_metres(manifest: Dictionary, from: int) -> Dictionary:
	var rooms: Array = manifest.rooms
	var metres := {from: 0.0}
	var open: Array = [from]
	while not open.is_empty():
		var best := 0
		for index in open.size():
			if float(metres[open[index]]) < float(metres[open[best]]): best = index
		var at: int = open[best]
		open.remove_at(best)
		var here := position_of(rooms[at])
		for other in manifest.adjacency[at]:
			var next := int(other)
			var length: float = float(metres[at]) + here.distance_to(position_of(rooms[next]))
			if not metres.has(next):
				open.append(next)
				metres[next] = length
			elif length < float(metres[next]) - 0.001: metres[next] = length
	return metres

## The room a planta is walked into from: the reception on the first, the
## lobby its lift arrives at on the others.
static func entry_of(manifest: Dictionary, planta: int) -> int:
	var entries: Array = manifest.get("entries", [])
	return int(entries[planta]) if planta < entries.size() else int(manifest.get("start", 0))

## The longest stretch of a planta's corridor with no door on to any room, in
## metres (map_generator.expose()): its corridor cells that open only on to
## corridor, a piece of them joined together at a time.
static func longest_exposed(manifest: Dictionary, planta: int) -> float:
	var rooms: Array = manifest.rooms
	var blind := {}
	for room in rooms:
		if int(room.get("wing", -1)) != planta or is_void(room) or not bool(room.get("corridor", false)): continue
		if manifest.adjacency[int(room.id)].all(func(other): return bool(rooms[int(other)].get("corridor", false))): blind[int(room.id)] = true
	var best := 0.0
	var seen := {}
	for id in blind:
		if seen.has(id): continue
		var length := 0.0
		var queue: Array = [id]
		seen[id] = true
		while not queue.is_empty():
			var here: int = queue.pop_back()
			var span := size_of(rooms[here])
			length += maxf(span.x, span.y) if String(rooms[here].get("kind", "lane")) == "lane" else minf(span.x, span.y)
			for other in manifest.adjacency[here]:
				if blind.has(int(other)) and not seen.has(int(other)):
					seen[int(other)] = true
					queue.append(int(other))
		best = maxf(best, length)
	return best

## A room that does not say where its wardrobes are (the gallery's modules:
## the generators write `hides` in every room) is counted by the hotel's
## table.
static func hiding_count(room: Dictionary) -> int:
	if room.has("hides"): return room.hides.size()
	if int(room.get("hall", -1)) >= 0: return 0
	return palette({}).WARDROBES.get(int(room.type), 0)

## Wardrobe spots against the walls; with two, they go on opposite walls. A
## floor that says where its wardrobes are (each room's `hides`, drawn clear
## of every doorway by map_generator.place_hides()) is taken at its word.
static func hiding_positions(room: Dictionary) -> Array[Vector3]:
	if room.has("hides"):
		var told: Array[Vector3] = []
		for spot in room.hides: told.append(Vector3(float(spot[0]), 0.0, float(spot[1])))
		return told
	var span := size_of(room) * 0.5 - Vector2.ONE * 0.8
	var open: Array = room.get("open_sides", [])
	var candidates: Array[Vector3] = []
	for wall in ["west", "east", "north", "south"]:
		if open.has(wall): continue
		for offset in [-1.8, 1.8]:
			match wall:
				"west": candidates.append(Vector3(-span.x, 0, offset))
				"east": candidates.append(Vector3(span.x, 0, offset))
				"north": candidates.append(Vector3(offset, 0, -span.y))
				"south": candidates.append(Vector3(offset, 0, span.y))
	var result: Array[Vector3] = []
	var count := mini(hiding_count(room), candidates.size())
	if count >= 1: result.append(candidates[0])
	# Candidates come in pairs per wall (west, east, ...): index 2 is the opposite wall.
	if count >= 2: result.append(candidates[2] if candidates.size() > 2 else candidates[1])
	return result

static func hiding_yaw(spot: Vector3) -> float:
	if absf(spot.x) > absf(spot.z): return -signf(spot.x) * PI / 2
	return PI if spot.z > 0 else 0.0

static func hiding_approach(spot: Vector3) -> Vector3:
	return spot + Basis(Vector3.UP, hiding_yaw(spot)) * Vector3(0, 0, 1.1)

## The middle of the doorway between two cells side by side: on the wall they
## share, as far along it from its middle as that door stands (door_offset).
static func portal_between(a: Dictionary, b: Dictionary) -> Vector3:
	var point := position_of(a)
	var size := size_of(a)
	var offset := door_offset(a, int(b.id))
	if a.x != b.x:
		point.x += sign(b.x - a.x) * size.x * 0.5
		point.z += offset
	else:
		point.z += sign(b.z - a.z) * size.y * 0.5
		point.x += offset
	return point

## How far the door to a neighbour stands from the middle of the wall they
## share, in metres along the world axis that wall runs on: +z for a wall
## between cells side by side in x, +x for one between cells one behind the
## other in z. The same number seen from either room; 0 for a floor that does
## not say.
static func door_offset(room: Dictionary, other: int) -> float:
	for entry in room.get("doors", []):
		if int(entry[0]) == other: return float(entry[1])
	return 0.0

## A room's doorways: the wall each is in ("west", "east", "north" or
## "south"), where along it (`along`, as door_offset gives it: z on the west
## and east walls, x on the north and south ones) and the room behind it.
static func doorways(room: Dictionary) -> Array:
	var out: Array = []
	for entry in room.get("doors", []):
		var other := int(entry[0])
		var step := other - int(room.id)
		# Beside it in its row the ids are one apart; in the next row, a
		# whole row of the grid.
		var wall := "east" if step == 1 else "west" if step == -1 else "south" if step > 0 else "north"
		out.append({"wall": wall, "along": float(entry[1]), "other": other})
	return out

## A shut door leaf's yaw, as the floor hangs it (the manifest's `doors`,
## by "a:b"). A leaf runs from its hinge along its own +X, so the jamb it hangs
## from (hinge: +1 the one at +z on a wall between cells side by side in x, at
## +x on the others) decides which of the two ways along the wall it faces.
static func leaf_yaw(a: Dictionary, b: Dictionary, spec: Dictionary) -> float:
	var hinge := int(spec.get("hinge", 1))
	if int(a.x) != int(b.x): return PI / 2 if hinge > 0 else -PI / 2
	return PI if hinge > 0 else 0.0

## Which way (+1 or -1) a leaf hung at `yaw` in the doorway `centre` turns to
## open, so that it swings into the room the floor says (swing: +1 the pair's
## second room, -1 its first). Turned the positive way, a leaf goes to -Z of
## itself shut (hotel_door.gd: OPEN_TURN times this).
static func leaf_turn(a: Dictionary, b: Dictionary, spec: Dictionary, centre: Vector3, yaw: float) -> float:
	var into: Dictionary = b if int(spec.get("swing", 1)) > 0 else a
	return -signf((position_of(into) - centre).dot(Basis(Vector3.UP, yaw).z))

## A walkable route, or nothing between two plantas: they are joined only by
## the lift, and a route that stopped at the nearest point under the target
## was taken for one that got there (a sound heard through the slab).
static func navigation_path(map: RID, origin: Vector3, target: Vector3) -> PackedVector3Array:
	if planta_of(origin.y) != planta_of(target.y): return PackedVector3Array()
	var query := NavigationPathQueryParameters3D.new()
	query.map = map
	query.start_position = floor_point(origin)
	query.target_position = floor_point(target)
	query.path_search_max_polygons = 0
	query.simplify_path = true
	query.simplify_epsilon = 0.02
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(query, result)
	return result.path
