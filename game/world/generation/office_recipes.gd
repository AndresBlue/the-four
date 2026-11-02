extends RefCounted
## How the offices' rooms are furnished (spec_rediseno 5.2 and 6, area 4b):
## each furnished type's recipe (palette.ROOM_FURNITURE) laid in a room, its
## pieces against its feature wall, along its other free walls or standing
## free toward that wall; the feature wall itself (room.feature, which the
## room captures look at); the corner pieces a recipe stands in for, or that
## stand before glass, giving way; the head cell of a salon with a piece it has
## once (hall_heads()); and the lit rooms' open doors. Room-local
## plan (x, z) from the cell's centre, as office_layout.gd. The generator
## gives it random streams of its own (office_generator.furnish_furniture()),
## so its draws move no other system's.
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const WALLS := ["west", "east", "north", "south"]
## The turn that puts a piece's back (its local -Z) to each wall.
const TURNS := {"north": 0, "west": 1, "south": 2, "east": 3}
## Between a wall's face and the back of a piece against it.
const WALL_GAP := 0.05
## Where along a wall a run is tried, from the middle out.
const ALONG := [0.0, -0.9, 0.9, -1.8, 1.8, -2.7, 2.7, -3.6, 3.6, -4.5, 4.5]
## Where a free-standing piece is tried: metres toward the feature wall from
## the middle (negative, away from it), and aside. The cover sweeps keep the
## two metres round the middle.
const MIDDLE_DEPTHS := [2.0, 2.4, 2.8, 3.2, -2.0, -2.4, -2.8, -3.2]
const MIDDLE_SIDES := [0.0, 1.0, -1.0]
## The free-standing pieces with no back, which lay_middle() also tries a
## quarter turned (a dining set beside the kitchen, in a cell of 10 m).
const ANY_WAY := ["dining_set", "work_table", "sorting_table", "cart_boxes"]
## A wall spot taken (job.taken: a locker, a station, a reader, the board, a
## timer, the console, the handler, the arrival lift) keeps FIXTURE_CLEAR deep
## and TAKEN_PAST past its half each side free, and a way to it from the
## middle of the room, to TAKEN_OUT in front of it.
const TAKEN_PAST := 0.1
const TAKEN_OUT := 0.6
## A corridor's floor furniture: off its cell's ends, the stretch of wall that
## takes a zone sign (a little under office_geometry's 3 m, for its jambs), and
## how far along another piece still narrows the way.
const HALL_END := 0.3
const HALL_SIGN_RUN := 2.8
const HALL_BY := 0.5

## A furniture item as the manifest keeps it (a partition's size.x is its length).
static func item(kind: String, at: Vector2, turn: int, group: int, length := 0.0) -> Dictionary:
	var spec: Dictionary = OFFICE.FURNITURE[kind]
	var size: Vector2 = spec.size
	if kind == "partition": size.x = length
	return {"kind": kind, "at": [snappedf(at.x, 0.001), snappedf(at.y, 0.001)], "turn": turn, "size": [snappedf(size.x, 0.001), snappedf(size.y, 0.001)], "extra": {"height": float(spec.height), "group": group}}

## Whether a piece fits: inside the walls, clear of every zone, ITEM_GAP from
## the pieces of other groups.
static func fits(room: Dictionary, zones: Array, piece: Dictionary) -> bool:
	var r := LAYOUT.footprint(piece)
	if not LAYOUT.fits_in(LAYOUT.inner(room), r) or hits(r, zones): return false
	for other in room.furniture:
		if int(other.extra.group) == int(piece.extra.group): continue
		if not LAYOUT.apart(r, LAYOUT.footprint(other), LAYOUT.ITEM_GAP): return false
	return true

## Gives each capsule zone its bounds grown by its radius, which hits() tries
## first: a rect clear of them is at least that far from the capsule's segment.
static func prepare(zones: Array) -> void:
	for zone in zones:
		if zone.has("rect") or zone.has("bound"): continue
		var a: Vector2 = zone.a
		var b: Vector2 = zone.b
		zone["bound"] = Rect2(a, Vector2.ZERO).expand(b).grow(float(zone.r))

## LAYOUT.blocked() with each capsule's bounds tried first: the same answer,
## cheaper.
static func hits(rect: Rect2, zones: Array) -> bool:
	for zone in zones:
		if zone.has("rect"):
			if rect.intersects(zone.rect): return true
		elif zone.has("bound") and not rect.intersects(zone.bound): continue
		elif LAYOUT.segment_rect_distance(zone.a, zone.b, rect) < float(zone.r): return true
	return false

## What a room's furniture keeps clear: LAYOUT.clear_zones() (the validator's
## rule), each glazed wall's GLASS_CLEAR, each corner piece out to its corner
## (nothing stands behind one), each wall spot taken, the air plant's hatch and
## handler (air_zones()), and at the window the line from its camera to the
## typist. Capsules prepared.
static func keep_clear(view: Dictionary, room: Dictionary, taken: Array) -> Array:
	var out := LAYOUT.clear_zones(view, room, int(room.type) == OFFICE.BOARDROOM)
	for wall in room.get("glazed", []): out.append({"rect": glass_band(room, String(wall))})
	var sockets: Array = room.get("sockets", [])
	for prop in room.get("props", []):
		if int(prop.slot) < sockets.size(): out.append({"rect": corner_zone(room, prop)})
	for spot in taken: out.append({"rect": LAYOUT.wall_rect(room, String(spot.wall), float(spot.along), float(spot.half) + TAKEN_PAST, LAYOUT.FIXTURE_CLEAR.y)})
	out.append_array(air_zones(room, view.get("air", {})))
	var mail: Dictionary = view.get("mail", {})
	if int(mail.get("window", -1)) == int(room.id) and mail.has("camera") and mail.has("camera_target"):
		var eye: Array = mail.camera
		var typist: Array = mail.camera_target
		var middle := Vector2(float(room.px), float(room.pz))
		out.append({"a": Vector2(float(eye[0]), float(eye[2])) - middle, "b": Vector2(float(typist[0]), float(typist[2])) - middle, "r": LAYOUT.SWEEP_CLEAR})
	prepare(out)
	return out

## The air plant's hatch square and its handler's whole box (office_generator
## furnish_air()). LAYOUT.fixtures() keeps neither in full: the hatch hangs
## too far from its wall to count as a wall spot, and the handler's wall spot
## clears only FIXTURE_CLEAR.y of its depth. `air` is the manifest's air (empty
## on a floor with none); nothing for any room but the plant.
static func air_zones(room: Dictionary, air: Dictionary) -> Array:
	var out: Array = []
	if not (air.has("plant") and air.has("hatch") and air.has("unit")): return out
	if int(air.plant) != int(room.id): return out
	var hp: Array = air.hatch.point
	var hatch := Vector2(float(hp[0]) - float(room.px), float(hp[2]) - float(room.pz))
	out.append({"rect": Rect2(hatch - Vector2(0.75, 0.75), Vector2(1.5, 1.5))})
	var unit: Dictionary = air.unit
	out.append({"rect": LAYOUT.wall_rect(room, String(unit.wall), float(unit.along), OFFICE.AIR_UNIT.x / 2, OFFICE.AIR_UNIT.z)})
	return out

## A way from the middle of a room to the front of each wall spot taken, for
## the pieces a recipe lays against its walls and in its middle.
static func ways_in(room: Dictionary, taken: Array) -> Array:
	var out: Array = []
	for spot in taken: out.append({"a": Vector2.ZERO, "b": wall_front(room, String(spot.wall), float(spot.along), TAKEN_OUT), "r": LAYOUT.SWEEP_CLEAR})
	prepare(out)
	return out

## Whether pieces may stand against a wall: closed, not glass, not the lift's.
static func usable(room: Dictionary, wall: String) -> bool:
	if room.get("open_sides", []).has(wall) or room.get("glazed", []).has(wall): return false
	return FLOOR.lift_wall(room) != LAYOUT.way_of(wall)

## A point before a wall: `along` it and `out` in from its face.
static func wall_front(room: Dictionary, wall: String, along: float, out: float) -> Vector2:
	var face := LAYOUT.face(room, wall)
	var base: Vector2 = Vector2(face, along) if wall == "west" or wall == "east" else Vector2(along, face)
	return base + LAYOUT.inward(wall) * out

## A room's main doorway, {wall, along, other}: the first to a corridor, else
## its first (office_rooms_capture.door_of()'s choice); {} with none.
static func main_way(rooms: Array, room: Dictionary) -> Dictionary:
	var ways: Array = FLOOR.doorways(room)
	if ways.is_empty(): return {}
	for way in ways:
		if bool(rooms[int(way.other)].get("corridor", false)): return way
	return ways[0]

## The usable wall with no doorway opposite the main doorway, else the one of
## them whose middle is farthest from it (WALLS' order on a tie); with none,
## any usable wall but the main doorway's the same way; "" with none at all.
static func far_wall(rooms: Array, room: Dictionary) -> String:
	var door := main_way(rooms, room)
	var main := String(door.get("wall", ""))
	var doored: Array = []
	for way in FLOOR.doorways(room): doored.append(String(way.wall))
	var closed: Array = []
	for wall in WALLS:
		if usable(room, wall) and not doored.has(wall): closed.append(wall)
	if closed.is_empty():
		for wall in WALLS:
			if usable(room, wall) and wall != main: closed.append(wall)
	if closed.is_empty(): return ""
	if main == "": return String(closed[0])
	var opposite := LAYOUT.wall_of(-LAYOUT.way_of(main))
	if closed.has(opposite): return opposite
	var from := wall_front(room, main, float(door.along), 0.0)
	var best := ""
	var most := -1.0
	for wall in closed:
		var gap := wall_front(room, String(wall), 0.0, 0.0).distance_to(from)
		if gap > most + 0.001:
			most = gap
			best = String(wall)
	return best

## Each salon of a type with a piece it has once (palette.ONE_PER_HALL), by its
## hall: its head cell, the lowest with a door to a corridor, else its lowest.
static func hall_heads(rooms: Array) -> Dictionary:
	var out := {}
	var doored := {}
	for room in rooms:
		var t := int(room.type)
		var hall := int(room.get("hall", -1))
		if hall < 0 or not OFFICE.ONE_PER_HALL.has(t) or doored.has(hall): continue
		if FLOOR.doorways(room).any(func(way): return bool(rooms[int(way.other)].get("corridor", false))):
			out[hall] = int(room.id)
			doored[hall] = true
		elif not out.has(hall):
			out[hall] = int(room.id)
	return out

## The wall a room is framed by and furnished against first
## (palette.FEATURE_WALLS), from the manifest as it stands (`view`: its rooms
## and the systems laid so far); "" with none.
static func feature_of(view: Dictionary, room: Dictionary) -> String:
	var t := int(room.type)
	var id := int(room.id)
	var rule := String(OFFICE.FEATURE_WALLS.get(t, ""))
	if rule == "": return ""
	if rule == "window" and int(view.get("mail", {}).get("window", -1)) == id: return String(view.mail.desk.wall)
	if rule == "board" and int(view.get("power", {}).get("room", -1)) == id: return String(view.power.board.wall)
	if rule == "console" and int(view.get("air", {}).get("security", {}).get("room", -1)) == id: return String(view.air.security.desk.wall)
	if rule == "unit" and int(view.get("air", {}).get("plant", -1)) == id: return String(view.air.unit.wall)
	if rule == "lift" and FLOOR.lift_wall(room) != Vector2i.ZERO: return LAYOUT.wall_of(FLOOR.lift_wall(room))
	if rule == "suite":
		for way in FLOOR.doorways(room):
			if int(view.rooms[int(way.other)].type) == OFFICE.EXEC_OFFICE: return String(way.wall)
	return far_wall(view.rooms, room)

## GLASS_CLEAR before a glazed wall, its whole length.
static func glass_band(room: Dictionary, wall: String) -> Rect2:
	return LAYOUT.wall_rect(room, wall, 0.0, LAYOUT.wall_length(room, wall) / 2, OFFICE.GLASS_CLEAR)

## A corner piece's rect in its cell (office_generator.furnish_sockets()).
static func prop_rect(room: Dictionary, prop: Dictionary) -> Rect2:
	var s: Array = room.sockets[int(prop.slot)]
	var size: Vector2 = Vector2(2.3, 1.4) if int(prop.rotation) % 2 == 0 else Vector2(1.4, 2.3)
	return Rect2(Vector2(float(s[0]), float(s[1])) - size / 2, size)

## A corner piece's rect run out to the corner it stands in, so nothing is
## laid behind it.
static func corner_zone(room: Dictionary, prop: Dictionary) -> Rect2:
	var r := prop_rect(room, prop)
	var space := LAYOUT.inner(room)
	var c := r.get_center()
	return r.expand(Vector2(space.end.x if c.x > 0.0 else space.position.x, space.end.y if c.y > 0.0 else space.position.y))

## The corner pieces before a glazed wall give way (spec_rediseno 3.6; the
## director, 1a: the gun rack before the security post's glass), but for
## those under the sill (palette.GLASS_LOW).
static func clear_glass(room: Dictionary) -> void:
	var glazed: Array = room.get("glazed", [])
	var sockets: Array = room.get("sockets", [])
	if glazed.is_empty() or sockets.is_empty(): return
	var kept: Array = []
	for prop in room.props:
		var before := false
		if int(prop.slot) < sockets.size() and not OFFICE.GLASS_LOW.has(String(prop.kind)):
			var r := prop_rect(room, prop)
			for wall in glazed:
				if r.intersects(glass_band(room, String(wall))): before = true
		if not before: kept.append(prop)
	room.props = kept

## The corner pieces a type's furniture stands in for give way
## (palette.CORNERS_REPLACED); returns them, for restore().
static func drop(room: Dictionary) -> Array:
	var t := int(room.type)
	var swaps: Dictionary = OFFICE.CORNERS_REPLACED.get(t, {})
	var kept: Array = []
	var gone: Array = []
	for prop in room.props:
		if swaps.has(String(prop.kind)): gone.append(prop)
		else: kept.append(prop)
	room.props = kept
	return gone

## Puts back each corner piece drop() took whose stand-in was not laid, where
## no piece laid covers it, the props kept in their slots' order.
static func restore(room: Dictionary, gone: Array) -> void:
	if gone.is_empty(): return
	var t := int(room.type)
	var swaps: Dictionary = OFFICE.CORNERS_REPLACED.get(t, {})
	var laid := {}
	for it in room.furniture: laid[String(it.kind)] = true
	for prop in gone:
		var stand_in := String(swaps.get(String(prop.kind), ""))
		if stand_in == "" or laid.has(stand_in): continue
		var r := prop_rect(room, prop)
		var covered := false
		for it in room.furniture:
			if LAYOUT.footprint(it).intersects(r): covered = true
		if not covered: room.props.append(prop)
	room.props.sort_custom(func(x, y): return int(x.slot) < int(y.slot))

## The FURNITURE kinds a type may have (office_validator.furniture_ok()).
static func kinds(t: int) -> Array:
	var out: Array = []
	for entry in OFFICE.ROOM_FURNITURE.get(t, []):
		if String(entry[1]) == "lattice":
			for kind in OFFICE.LATTICE_KINDS.get(t, []):
				if not out.has(String(kind)): out.append(String(kind))
		elif not out.has(String(entry[0])): out.append(String(entry[0]))
	return out

## The walls a recipe entry tries, in order: "back", the feature wall alone;
## "wall", the feature wall and then the other free walls; "side" and "spare",
## the other free walls and then the feature wall; "closed", the free walls with
## no door. The feature wall only where pieces may stand against it (usable()):
## a salon's cell shares its head cell's, which may be open to the next cell.
static func walls_for(room: Dictionary, how: String) -> Array:
	if how == "closed":
		var doored: Array = FLOOR.doorways(room).map(func(way): return String(way.wall))
		return WALLS.filter(func(wall): return usable(room, String(wall)) and not doored.has(wall))
	var front_wall := String(room.get("feature", ""))
	var others: Array = []
	for wall in WALLS:
		if wall != front_wall and usable(room, wall): others.append(wall)
	if front_wall == "": return [] if how == "back" else others
	if how == "back": return [front_wall] if usable(room, front_wall) else []
	var front: Array = [front_wall] if usable(room, front_wall) else []
	if how == "wall": return front + others
	return others + front

## One recipe entry laid in a room: its runs, drawn from least to most (one
## draw whether or not they fit), each the first place that takes `row`
## pieces side by side as one group. Returns the wall runs' {wall, along,
## half} (office_generator.wall_exit() keeps off them).
static func lay(room: Dictionary, zones: Array, entry: Array, rng: RandomNumberGenerator) -> Array:
	var kind := String(entry[0])
	var how := String(entry[1])
	var runs := rng.randi_range(int(entry[2]), int(entry[3]))
	var row := int(entry[4])
	var out: Array = []
	for _run in runs:
		if how == "middle":
			lay_middle(room, zones, kind)
			continue
		for wall in walls_for(room, how):
			var placed := lay_wall(room, zones, kind, row, String(wall))
			if not placed.is_empty():
				out.append(placed)
				break
	return out

## A run of `row` pieces with their backs to a wall, WALL_GAP off its face,
## at the first of ALONG that fits; {wall, along, half}, or {} where none does.
static func lay_wall(room: Dictionary, zones: Array, kind: String, row: int, wall: String) -> Dictionary:
	var spec: Dictionary = OFFICE.FURNITURE[kind]
	var size: Vector2 = spec.size
	var width := size.x * row
	var reach := LAYOUT.wall_length(room, wall) / 2
	var off := wall_front(room, wall, 0.0, WALL_GAP + size.y / 2)
	var along_z: bool = wall == "west" or wall == "east"
	for along in ALONG:
		var a := float(along)
		if absf(a) + width / 2 > reach: continue
		var group: int = room.furniture.size()
		var pieces: Array = []
		for k in row:
			var at_along := a + (float(k) - float(row - 1) / 2.0) * size.x
			var at: Vector2 = Vector2(off.x, at_along) if along_z else Vector2(at_along, off.y)
			pieces.append(item(kind, at, int(TURNS[wall]), group))
		var ok := true
		for piece in pieces:
			if not fits(room, zones, piece): ok = false
		if ok:
			room.furniture.append_array(pieces)
			return {"wall": wall, "along": a, "half": width / 2}
	return {}

## A free-standing piece toward the feature wall, its back to it (or a
## quarter turned, for ANY_WAY), at the first of MIDDLE_DEPTHS and
## MIDDLE_SIDES that fits; false where none does.
static func lay_middle(room: Dictionary, zones: Array, kind: String) -> bool:
	var wall := String(room.get("feature", ""))
	var n: Vector2 = LAYOUT.inward(wall) if wall != "" else Vector2(0, 1)
	var side := Vector2(-n.y, n.x)
	var turn: int = int(TURNS[wall]) if wall != "" else 0
	var turns: Array = [turn, (turn + 1) % 4] if ANY_WAY.has(kind) else [turn]
	for depth in MIDDLE_DEPTHS:
		for aside in MIDDLE_SIDES:
			for spin in turns:
				var piece := item(kind, -n * float(depth) + side * float(aside), int(spin), room.furniture.size())
				if fits(room, zones, piece):
					room.furniture.append(piece)
					return true
	return false

## The corridors' floor furniture (spec_rediseno 5.2; the director, 4b): along
## each line of wall of a corridor HALL_WIDTH wide or more, a piece of HALL_KINDS
## every HALL_STEP metres. `taken` is job.taken. Returns each room's wall runs
## {wall, along, half} (office_generator.wall_exit() keeps off them).
static func lay_halls(view: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var lines := {}
	for room in view.rooms:
		var t := int(room.type)
		if t != OFFICE.CORRIDOR or minf(float(room.span_x), float(room.span_z)) < float(OFFICE.HALL_WIDTH) - 0.001: continue
		var along_x: bool = float(room.span_x) >= float(room.span_z)
		var sides: Array = ["north", "south"] if along_x else ["west", "east"]
		for wall in sides:
			var key := "%d:%s:%.3f" % [int(room.get("wing", 0)), String(wall), float(room.pz) if along_x else float(room.px)]
			if not lines.has(key): lines[key] = []
			lines[key].append(room)
	var keys: Array = lines.keys()
	keys.sort()
	var out := {}
	for key in keys: lay_line(view, taken, lines[key], String(key).get_slice(":", 1), rng, out)
	return out

## One line of wall: a window of HALL_STEP's spread at a time, a place drawn in
## it and then the rest of it, half a metre apart; with none, the next window.
static func lay_line(view: Dictionary, taken: Dictionary, cells: Array, wall: String, rng: RandomNumberGenerator, out: Dictionary) -> void:
	var along_x: bool = wall == "north" or wall == "south"
	var step: Vector2 = OFFICE.HALL_STEP
	var spread: float = step.y - step.x
	var start := INF
	var stop := -INF
	for room in cells:
		start = minf(start, hall_mid(room, along_x) - LAYOUT.wall_length(room, wall) / 2)
		stop = maxf(stop, hall_mid(room, along_x) + LAYOUT.wall_length(room, wall) / 2)
	var zones_of := {}
	var at: float = start + rng.randf_range(2.0, step.x)
	while at < stop:
		var kind := String(OFFICE.HALL_KINDS[rng.randi_range(0, OFFICE.HALL_KINDS.size() - 1)])
		var placed := false
		for pos in hall_tries(at, spread, at + rng.randf() * spread):
			var room := hall_cell(cells, wall, along_x, float(pos))
			if room.is_empty(): continue
			var id := int(room.id)
			if not zones_of.has(id):
				var spots: Array = taken.get(id, [])
				zones_of[id] = keep_clear(view, room, spots) + ways_in(room, spots) + hall_signs(room, wall)
			var a: float = float(pos) - hall_mid(room, along_x)
			var piece := hall_piece(room, kind, wall, a)
			if piece.is_empty() or not fits(room, zones_of[id], piece): continue
			var with_it: Array = room.furniture + [piece]
			if hall_gap(room, with_it) < float(OFFICE.HALL_PASS): continue
			room.furniture.append(piece)
			if not out.has(id): out[id] = []
			out[id].append({"wall": wall, "along": a, "half": float(piece.size[0]) / 2})
			at = float(pos) + step.x
			placed = true
			break
		if not placed: at += spread

## Where along its axis a corridor cell's middle is.
static func hall_mid(room: Dictionary, along_x: bool) -> float:
	return float(room.px) if along_x else float(room.pz)

## The places a window tries: the drawn one, up to its end, then down to its start.
static func hall_tries(at: float, spread: float, first: float) -> Array:
	var out: Array = [first]
	var up := first + 0.5
	while up <= at + spread:
		out.append(up)
		up += 0.5
	var down := first - 0.5
	while down >= at:
		out.append(down)
		down -= 0.5
	return out

## The line's cell with a usable wall at `pos`; {} with none.
static func hall_cell(cells: Array, wall: String, along_x: bool, pos: float) -> Dictionary:
	for room in cells:
		if absf(pos - hall_mid(room, along_x)) <= LAYOUT.wall_length(room, wall) / 2 and usable(room, wall): return room
	return {}

## A piece against a wall, `a` along it, HALL_END short of its cell's ends; {} past them.
static func hall_piece(room: Dictionary, kind: String, wall: String, a: float) -> Dictionary:
	var spec: Dictionary = OFFICE.FURNITURE[kind]
	var size: Vector2 = spec.size
	if absf(a) + size.x / 2 > LAYOUT.wall_length(room, wall) / 2 - HALL_END: return {}
	return item(kind, wall_front(room, wall, a, WALL_GAP + size.y / 2), int(TURNS[wall]), room.furniture.size())

## Where a corridor cell's zone sign may be on a wall: office_geometry.wall_run()
## puts it in the middle of the first stretch of 3 m or more.
static func hall_signs(room: Dictionary, wall: String) -> Array:
	var reach := LAYOUT.wall_length(room, wall) / 2
	var doors: Array = []
	for way in FLOOR.doorways(room):
		if String(way.wall) == wall: doors.append(float(way.along))
	doors.sort()
	doors.append(reach + FLOOR.PORTAL / 2)
	var out: Array = []
	var from := -reach
	for along in doors:
		var to: float = float(along) - FLOOR.PORTAL / 2
		if to - from >= HALL_SIGN_RUN: out.append({"rect": LAYOUT.wall_rect(room, wall, (from + to) / 2, float(OFFICE.HALL_SIGN_CLEAR), 1.0)})
		from = float(along) + FLOOR.PORTAL / 2
	return out

## The least width left to walk in a corridor cell, across it, past `items`: each
## item with those on either wall that overlap it, HALL_BY to spare, along the cell.
static func hall_gap(room: Dictionary, items: Array) -> float:
	var along_x: bool = float(room.span_x) >= float(room.span_z)
	var space := LAYOUT.inner(room)
	var axis: int = 0 if along_x else 1
	var across := 1 - axis
	var least: float = space.size[across]
	for it in items:
		var r := LAYOUT.footprint(it)
		var low: float = space.position[across]
		var high: float = space.end[across]
		for other in items:
			var o := LAYOUT.footprint(other)
			if o.position[axis] > r.end[axis] + HALL_BY or o.end[axis] < r.position[axis] - HALL_BY: continue
			if o.get_center()[across] < 0.0: low = maxf(low, o.end[across])
			else: high = minf(high, o.position[across])
		least = minf(least, high - low)
	return least

## Spec_rediseno 3.6: of the doors of lit rooms (not corridors) OPEN_LIT stand
## open, one draw a door in the doors' order, lit or not; the door between a
## secretary's and a director's office always does. A door with a lock (the
## security post's) or a refuge's (`gates`) stays as it is.
static func open_doors(rooms: Array, doors: Dictionary, gates: Array, rng: RandomNumberGenerator) -> void:
	var shut := {}
	for gate in gates:
		var one := int(gate.room)
		var two := int(gate.beyond)
		shut["%d:%d" % [mini(one, two), maxi(one, two)]] = true
	for key in doors:
		var roll := rng.randf()
		var spec: Dictionary = doors[key]
		if shut.has(String(key)) or spec.has("lock"): continue
		var ids := String(key).split(":")
		var a: Dictionary = rooms[int(ids[0])]
		var b: Dictionary = rooms[int(ids[1])]
		var ta := int(a.type)
		var tb := int(b.type)
		if (ta == OFFICE.SECRETARY and tb == OFFICE.EXEC_OFFICE) or (ta == OFFICE.EXEC_OFFICE and tb == OFFICE.SECRETARY): spec.open = true
		elif (not bool(a.corridor) and not bool(a.dark)) or (not bool(b.corridor) and not bool(b.dark)): spec.open = roll < float(OFFICE.OPEN_LIT)
