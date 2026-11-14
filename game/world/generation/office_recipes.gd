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
## Where a run from a corner is tried first (spec_proporcion D4): metres in from
## the wall's end, past the wall across it, at each end in turn; then ALONG.
const FROM_CORNER := [0.12, 0.42, 0.72, 1.02, 1.32, 1.62, 1.92, 2.22]
## How far short of the wall across a run may end and still turn its corner.
const TURN_GAP := 0.5
## Where a free-standing piece is tried: metres toward the feature wall from
## the middle (negative, away from it), and aside, off the middle as the
## references have them (spec_proporcion D5).
## A step of 0.15 by 0.35: a coarser one missed the places between the ways in
## (a break room with three doors took one table of its four).
const MIDDLE_DEPTHS := [1.1, 1.25, 1.4, 1.55, 1.7, 1.85, 2.0, 2.2, 2.4, 2.6, 2.8, 3.0, 3.2, -1.1, -1.25, -1.4, -1.55, -1.7, -1.85, -2.0, -2.2, -2.4, -2.6, -2.8, -3.0, -3.2]
const MIDDLE_SIDES := [0.0, 0.5, -0.5, 1.0, -1.0, 1.35, -1.35, 1.7, -1.7, 2.05, -2.05, 2.4, -2.4]
## The free-standing pieces with no back, which lay_middle() also tries a
## quarter turned (a dining set beside the kitchen, in a cell of 10 m).
const ANY_WAY := ["dining_set", "work_table", "sorting_table", "cart_boxes"]
## A wall spot taken (job.taken: a locker, a station, a reader, the board, a
## timer, the console, the handler, the arrival lift) keeps FIXTURE_CLEAR deep
## and TAKEN_PAST past its half each side free, and a way to it from the
## middle of the room, to TAKEN_OUT in front of it.
const TAKEN_PAST := 0.1
const TAKEN_OUT := 0.6
## Where a stage raises its bodies in a lobby with a lift (revival.gd
## revival_point(), revival_spread()): LIFT_AWAY from its middle, away from the
## lift, and the spread either way with a body's 0.3 round it.
const RAISE_AWAY := 0.9
const RAISE_REACH := 1.2
## What a corner piece keeps from a meeting table: a capsule's way down its side.
const TABLE_WALK := 0.7
## A corridor's floor furniture: off its cell's ends, the stretch of wall that
## takes a zone sign (a little under office_geometry's 3 m, for its jambs), and
## how far along another piece still narrows the way.
const HALL_END := 0.3
const HALL_SIGN_RUN := 2.8
const HALL_BY := 0.5
## Half the widest corridor fitting with its gaps (the hose cabinet, 0.65 m,
## office_walls.gd), kept clear of a fitting's slot by the corridor's floor pieces.
const HALL_SLOT_CLEAR := 0.55

## A furniture item as the manifest keeps it (a partition's size.x is its length).
static func item(kind: String, at: Vector2, turn: int, group: int, length := 0.0) -> Dictionary:
	var spec: Dictionary = OFFICE.FURNITURE[kind]
	var size: Vector2 = spec.size
	if kind == "partition": size.x = length
	return {"kind": kind, "at": [snappedf(at.x, 0.001), snappedf(at.y, 0.001)], "turn": turn, "size": [snappedf(size.x, 0.001), snappedf(size.y, 0.001)], "extra": {"height": float(spec.height), "group": group}}

## Whether a piece fits: inside the walls, clear of every zone, LAYOUT.gap_of()
## (a street in a nave) from the pieces of other groups.
static func fits(room: Dictionary, zones: Array, piece: Dictionary) -> bool:
	var r := LAYOUT.footprint(piece)
	if not LAYOUT.fits_in(LAYOUT.inner(room), r) or hits(r, zones): return false
	for other in room.furniture:
		if int(other.extra.group) == int(piece.extra.group): continue
		if not LAYOUT.apart(r, LAYOUT.footprint(other), LAYOUT.gap_of(room)): return false
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
	var lift := FLOOR.lift_wall(room)
	if lift != Vector2i.ZERO and int(room.type) in [OFFICE.LOBBY, OFFICE.REFUGE]:
		var raised := -Vector2(lift) * RAISE_AWAY
		out.append({"rect": Rect2(raised - Vector2.ONE * RAISE_REACH, Vector2.ONE * RAISE_REACH * 2.0)})
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

## A way from the middle of a room (a nave's aisle, LAYOUT.way_out()) to the
## front of each wall spot taken, for the pieces a recipe lays against its
## walls and in its middle.
static func ways_in(room: Dictionary, taken: Array) -> Array:
	var out: Array = []
	for spot in taken:
		var front := wall_front(room, String(spot.wall), float(spot.along), TAKEN_OUT)
		out.append({"a": LAYOUT.way_out(room, front), "b": front, "r": LAYOUT.SWEEP_CLEAR})
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
	return OFFICE.corner_rect(String(prop.kind), room.sockets[int(prop.slot)], int(prop.rotation))

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

## Every corner piece leaves the room before its recipe is laid (spec_proporcion
## D3); returns them, for restore().
static func drop(room: Dictionary) -> Array:
	var gone: Array = room.props
	room.props = []
	return gone

## Puts back the corner pieces drop() took that still fit (spec_proporcion D3),
## in their slots' order: not one a stand-in was laid for (palette.CORNERS_REPLACED),
## none on `zones` (the room's ways, made with no corner in them), none with a
## piece laid on it or behind it (corner_zone()), none whose sweep from the middle
## a piece stands on. A meeting table keeps TABLE_WALK round it, to walk down its
## long sides.
static func restore(room: Dictionary, gone: Array, zones: Array) -> void:
	if gone.is_empty(): return
	var t := int(room.type)
	var swaps: Dictionary = OFFICE.CORNERS_REPLACED.get(t, {})
	var laid := {}
	for it in room.furniture: laid[String(it.kind)] = true
	var reach := LAYOUT.cover_reach(room)
	for prop in gone:
		var kind := String(prop.kind)
		if swaps.has(kind) and (String(swaps[kind]) == "" or laid.has(String(swaps[kind]))): continue
		if hits(prop_rect(room, prop), zones): continue
		var out_to_corner := corner_zone(room, prop)
		var corner := LAYOUT.corner_of(int(prop.slot)) * reach
		var fits_here := true
		for it in room.furniture:
			var foot := LAYOUT.footprint(it)
			if foot.grow(TABLE_WALK if String(it.kind).begins_with("meeting_table") else 0.0).intersects(out_to_corner) or (t != OFFICE.BOARDROOM and reach > 0.0 and LAYOUT.segment_rect_distance(LAYOUT.way_out(room, corner), corner, foot) < LAYOUT.SWEEP_CLEAR):
				fits_here = false
				break
		if fits_here: room.props.append(prop)
	room.props.sort_custom(func(x, y): return int(x.slot) < int(y.slot))

## A piece of IN_ITS_CORNER tried first where the corner it stands in for
## (CORNERS_REPLACED) stood before drop(): on that socket, which the corner's
## plan is centred on, its back to one of the corner's two walls, never to the
## room (spec_4e D). Whether it was laid; if not, the recipe lays it as its
## entry says.
static func lay_corner(room: Dictionary, zones: Array, gone: Array, kind: String) -> bool:
	if not OFFICE.IN_ITS_CORNER.has(kind): return false
	var t := int(room.type)
	var swaps: Dictionary = OFFICE.CORNERS_REPLACED.get(t, {})
	var sockets: Array = room.get("sockets", [])
	for prop in gone:
		if String(swaps.get(String(prop.kind), "")) != kind or int(prop.slot) >= sockets.size(): continue
		var socket: Array = sockets[int(prop.slot)]
		var c := LAYOUT.corner_of(int(prop.slot))
		var walls: Array[String] = ["north" if c.y < 0.0 else "south", "west" if c.x < 0.0 else "east"]
		var turns: Array[int] = [0 if c.y < 0.0 else 2, 1 if c.x < 0.0 else 3]
		for k in 2:
			# Its back goes to one of the corner's walls, and only to one that takes pieces.
			if not usable(room, walls[k]): continue
			var piece := item(kind, Vector2(float(socket[0]), float(socket[1])), turns[k], room.furniture.size())
			if not fits(room, zones, piece): continue
			room.furniture.append(piece)
			return true
	return false

## The FURNITURE kinds a type may have (office_validator.furniture_ok()): a
## table recipe's, every one of TABLE_KINDS and its near side's chair.
static func kinds(t: int) -> Array:
	var out: Array = []
	for entry in OFFICE.ROOM_FURNITURE.get(t, []):
		if String(entry[1]) == "lattice":
			for kind in OFFICE.LATTICE_KINDS.get(t, []):
				if not out.has(String(kind)): out.append(String(kind))
		elif String(entry[1]) == "table":
			for kind in OFFICE.TABLE_KINDS: out.append(String(kind))
			out.append("table_chair")
		elif not out.has(String(entry[0])): out.append(String(entry[0]))
	return out

## The walls a recipe entry tries, in order: "back", the feature wall alone;
## "wall", the feature wall and then the other free walls; "side" and "spare",
## the other free walls and then the feature wall; "closed", the free walls with
## no door. The other walls with no doorway before those with one, and the
## wall across from the feature wall last: a room is seen from its doorway or
## from across, and what stands by the eye is out of sight. The feature
## wall only where pieces may stand against it (usable()): a salon's cell
## shares its head cell's, which may be open to the next cell.
static func walls_for(room: Dictionary, how: String) -> Array:
	var doored: Array = FLOOR.doorways(room).map(func(way): return String(way.wall))
	if how == "closed": return WALLS.filter(func(wall): return usable(room, String(wall)) and not doored.has(wall))
	var front_wall := String(room.get("feature", ""))
	var across := LAYOUT.wall_of(-LAYOUT.way_of(front_wall))
	# Ranked: the wall across last, a doored one after a closed one, and of two
	# alike the one at the feature wall's end in sight first (feature_end()).
	var lean := feature_end(room, front_wall)
	var along_z: bool = front_wall == "west" or front_wall == "east"
	var others: Array = []
	for rank in 8:
		for wall in WALLS:
			if wall == front_wall or not usable(room, wall): continue
			var out := LAYOUT.way_of(wall)
			var away: bool = lean != 0.0 and float(out.y if along_z else out.x) != lean
			if (4 if wall == across else 0) + (2 if doored.has(wall) else 0) + (1 if away else 0) == rank: others.append(wall)
	if front_wall == "": return [] if how == "back" else others
	if how == "back": return [front_wall] if usable(room, front_wall) else []
	var front: Array = [front_wall] if usable(room, front_wall) else []
	if how == "wall": return front + others
	return others + front

## One recipe entry laid in a room: its runs, drawn from least to most (one
## draw whether or not they fit), each the first place that takes `row`
## pieces side by side as one group. "back", "wall" and "run" start from the
## corners; "run" goes on from the room's last wall run, kept in `chain`
## (lay_run()); "center" holds `chain` on it, so the runs after it go to either
## side (lay_center()). Returns the wall runs' {wall, along, half, group}
## (office_generator.wall_exit() keeps off them).
static func lay(room: Dictionary, zones: Array, entry: Array, rng: RandomNumberGenerator, chain := {}) -> Array:
	var kind := String(entry[0])
	var how := String(entry[1])
	var runs := rng.randi_range(int(entry[2]), int(entry[3]))
	var row := int(entry[4])
	var out: Array = []
	# A spare no smaller than one that found no wall in this room finds none
	# either (the room only fills): not tried again, kept in `chain`.
	var spec: Dictionary = OFFICE.FURNITURE[kind]
	var foot := Vector2(float(spec.size.x) * row, float(spec.size.y))
	if how == "spare" and (chain.get("spare_fails", []) as Array).any(func(f: Vector2) -> bool: return foot.x >= f.x - LAYOUT.EPS and foot.y >= f.y - LAYOUT.EPS): return out
	for _run in runs:
		# A try that failed changed nothing, so the next would fail the same.
		if how == "middle":
			if not lay_middle(room, zones, kind, row): break
			continue
		var placed := {}
		if how == "run": placed = lay_run(room, zones, kind, row, chain)
		if how == "center": placed = lay_center(room, zones, kind, row)
		if placed.is_empty():
			for wall in walls_for(room, "wall" if how in ["run", "center"] else how):
				placed = lay_wall(room, zones, kind, row, String(wall), how in ["back", "wall", "run", "center"], feature_end(room, String(wall)))
				if not placed.is_empty(): break
		if placed.is_empty():
			if how == "spare":
				if not chain.has("spare_fails"): chain["spare_fails"] = []
				chain.spare_fails.append(foot)
			break
		out.append(placed)
		if not chain.get("center", false): chain.merge(placed, true)
	return out

## Frame the lift and the counter together from the middle of the room.
static func reception_counter(room: Dictionary, zones: Array, lift: Vector2i, lift_along: float) -> Dictionary:
	const KIND := "reception_counter_l"
	const FRAME_CLEAR := 0.22
	var size: Vector2 = OFFICE.FURNITURE[KIND].size
	var right := Vector2i(-lift.y, lift.x)
	var group: int = room.furniture.size()
	var walls: Array[Vector2i] = [right, -right]
	if lift_along != 0.0: walls.push_front(lift)
	for direction: Vector2i in walls:
		var wall := LAYOUT.wall_of(direction)
		if not usable(room, wall): continue
		var along_axis := Vector2.DOWN if direction.x != 0 else Vector2.RIGHT
		var toward := along_axis.dot(Vector2(lift if direction != lift else right))
		if direction == lift: toward = -signf(lift_along)
		var reach := LAYOUT.wall_length(room, wall) * 0.5
		for footprint: Vector2 in [size, OFFICE.FURNITURE[KIND].compact]:
			var edge := reach - footprint.x * 0.5 - FRAME_CLEAR
			for step in 15:
				var offset := float(step) * 0.15
				if edge <= offset: break
				var along := toward * (edge - offset)
				var point := wall_front(room, wall, along, WALL_GAP + footprint.y * 0.5)
				var piece := item(KIND, point, int(TURNS[wall]), group)
				piece.size = [footprint.x, footprint.y]
				var frame := LAYOUT.wall_rect(room, wall, along, footprint.x * 0.5 + FRAME_CLEAR, 0.2)
				if hits(frame, zones) or not fits(room, zones, piece): continue
				room.furniture.append(piece)
				return {"wall": wall, "along": along, "half": footprint.x * 0.5 + FRAME_CLEAR, "group": group}
	return {}

static func reception_wait(room: Dictionary, zones: Array, counter: Dictionary, lift: Vector2i, lift_along := 0.0) -> Dictionary:
	if lift_along != 0.0:
		var corner := wait_corner(room, zones, counter, lift, lift_along)
		if not corner.is_empty(): return corner
	var side := Vector2i(lift.y, -lift.x)
	for direction: Vector2i in [side, -side, -lift]:
		var wall := LAYOUT.wall_of(direction)
		if wall == String(counter.get("wall", "")) or not usable(room, wall): continue
		for kind: String in ["waiting_row_4", "waiting_row"]:
			# From the lift's end first: the seats in the first view, as in the reference.
			var run := lay_wall(room, zones, kind, 1, wall, false, feature_end(room, wall))
			if not run.is_empty(): return run
	return {}

## How far either side of the arrival lift's middle its leaves, casing and
## call panel reach (the panel's edge some 1.18): what waits in its corner
## stands past them, its seats' fronts a hand clear.
const LIFT_FRONT := 1.2

## The waiting seats against the wall beside the arrival lift, from the corner
## they share: in the first view, as the reference's. The lift's keep-clear
## (furnish_lobby()) reaches that corner for its lamps and its plant; here only
## its front stays clear, and the plant gives way (office_geometry.arrival_lift()).
## {} where no run fits there.
static func wait_corner(room: Dictionary, zones: Array, counter: Dictionary, lift: Vector2i, lift_along: float) -> Dictionary:
	var toward := int(signf(lift_along))
	var wall := LAYOUT.wall_of(Vector2i(toward, 0) if lift.x == 0 else Vector2i(0, toward))
	if wall == String(counter.get("wall", "")) or not usable(room, wall): return {}
	var lift_wall := LAYOUT.wall_of(lift)
	var door := wall_front(room, lift_wall, lift_along, 0.1)
	var open: Array = zones.filter(func(zone: Dictionary) -> bool: return not (zone.has("rect") and (zone.rect as Rect2).has_point(door)))
	open.append({"rect": LAYOUT.wall_rect(room, lift_wall, lift_along, LIFT_FRONT, LAYOUT.FIXTURE_CLEAR.y)})
	var along_z: bool = wall == "west" or wall == "east"
	var end := float(lift.y if along_z else lift.x)
	# The seats from the lift's end: which way that is along the run's own x.
	var theta := float(TURNS[wall]) * PI / 2.0
	var lead := signf(Vector2(cos(theta), -sin(theta)).dot(Vector2(0.0, end) if along_z else Vector2(end, 0.0)))
	var reach := LAYOUT.wall_length(room, wall) / 2
	var group: int = room.furniture.size()
	# Longest first (office_props.waiting_seats()): two pairs of seats and their
	# table, one pair and its table, one pair.
	var spec: Dictionary = OFFICE.FURNITURE.waiting_row_4
	for run: Vector2 in [spec.size] + spec.shorter:
		var width := run.x
		var a := end * (reach - float(FROM_CORNER[0]) - width / 2)
		var pieces := wall_pieces(room, "waiting_row_4", 1, wall, a, group)
		pieces[0].size[0] = width
		pieces[0].extra["lead"] = lead
		if not all_fit(room, open, pieces, false): continue
		room.furniture.append_array(pieces)
		return {"wall": wall, "along": a, "half": width / 2, "group": group}
	return {}

## A run of `row` pieces with their backs to a wall, WALL_GAP off its face, at
## the first place that fits (ALONG, or corner_first()); {wall, along, half,
## group}, or {} where none does. On a wall beside the feature wall (`toward`,
## feature_end()) from its corner at that end first: the end in sight from the
## doorway the room is looked into from.
static func lay_wall(room: Dictionary, zones: Array, kind: String, row: int, wall: String, from_corner := false, toward := 0.0) -> Dictionary:
	var spec: Dictionary = OFFICE.FURNITURE[kind]
	var size: Vector2 = spec.size
	var width := size.x * row
	var reach := LAYOUT.wall_length(room, wall) / 2
	var group: int = room.furniture.size()
	var off := wall_front(room, wall, 0.0, WALL_GAP + size.y / 2)
	var along_z: bool = wall == "west" or wall == "east"
	# Only the zones and the pieces by this wall can stop a run against it.
	var band: Rect2 = Rect2(off.x - size.y / 2, -reach, size.y, reach * 2) if along_z else Rect2(-reach, off.y - size.y / 2, reach * 2, size.y)
	var near := Near.new(room, zones, group, band)
	for along in (corner_first(reach, width, toward) if from_corner or toward != 0.0 else ALONG):
		var a := float(along)
		if absf(a) + width / 2 > reach: continue
		var whole: Rect2 = Rect2(off.x - size.y / 2, a - width / 2, size.y, width) if along_z else Rect2(a - width / 2, off.y - size.y / 2, width, size.y)
		if not near.clear(whole): continue
		var pieces := wall_pieces(room, kind, row, wall, a, group)
		if not all_fit(room, zones, pieces, false): continue
		room.furniture.append_array(pieces)
		return {"wall": wall, "along": a, "half": width / 2, "group": group}
	return {}

## `row` pieces side by side against a wall, centred `a` along it.
static func wall_pieces(room: Dictionary, kind: String, row: int, wall: String, a: float, group: int) -> Array:
	var spec: Dictionary = OFFICE.FURNITURE[kind]
	var size: Vector2 = spec.size
	var off := wall_front(room, wall, 0.0, WALL_GAP + size.y / 2)
	var along_z: bool = wall == "west" or wall == "east"
	var pieces: Array = []
	for k in row:
		var at_along := a + (float(k) - float(row - 1) / 2.0) * size.x
		var at: Vector2 = Vector2(off.x, at_along) if along_z else Vector2(at_along, off.y)
		pieces.append(item(kind, at, int(TURNS[wall]), group))
	return pieces

## Whether a rect of pieces of a new `group` may stand within `band` (fits()'s
## test for the whole of a run at once, a hair more lenient for the rounding):
## inside the walls, clear of every zone, LAYOUT.gap_of() from the other
## groups, with what lies by the band picked out once. A quick no: the pieces
## themselves are tried after it (all_fit()).
class Near:
	var space: Rect2
	var gap: float
	var zones: Array = []
	var others: Array[Rect2] = []
	func _init(room: Dictionary, all_zones: Array, group: int, band: Rect2) -> void:
		space = LAYOUT.inner(room)
		gap = LAYOUT.gap_of(room)
		var wide := band.grow(gap + 0.5)
		for zone in all_zones:
			if zone.has("rect"):
				if (zone.rect as Rect2).intersects(wide): zones.append(zone)
			elif not zone.has("bound") or (zone.bound as Rect2).intersects(wide): zones.append(zone)
		for other in room.furniture:
			if int(other.extra.group) == group: continue
			var foot := LAYOUT.footprint(other)
			if foot.intersects(wide): others.append(foot)
	func clear(rect: Rect2) -> bool:
		var r := rect.grow(-LAYOUT.EPS)
		if not LAYOUT.fits_in(space, r): return false
		# hits(), here: an inner class does not see its script's functions.
		for zone in zones:
			if zone.has("rect"):
				if r.intersects(zone.rect): return false
			elif zone.has("bound") and not r.intersects(zone.bound): continue
			elif LAYOUT.segment_rect_distance(zone.a, zone.b, r) < float(zone.r): return false
		for foot in others:
			if not LAYOUT.apart(r, foot, gap): return false
		return true

## Whether every piece fits; `apart`: and overlaps nothing laid, its own group too
## (touching is no overlap: positions are rounded, so by more than LAYOUT.EPS).
static func all_fit(room: Dictionary, zones: Array, pieces: Array, apart: bool) -> bool:
	for piece in pieces:
		if not fits(room, zones, piece): return false
		if not apart: continue
		var r := LAYOUT.footprint(piece)
		for other in room.furniture:
			if r.grow(-LAYOUT.EPS).intersects(LAYOUT.footprint(other)): return false
	return true

## The places along a wall from its corners first, then ALONG: each time the
## corner at `toward`'s end first (-1 with none).
static func corner_first(reach: float, width: float, toward := 0.0) -> Array:
	var first: float = toward if toward != 0.0 else -1.0
	var out: Array = []
	for off in FROM_CORNER:
		var a: float = reach - float(off) - width / 2
		if a <= 0.0: break
		out.append(first * a)
		out.append(-first * a)
	return out + ALONG

## Which end of a wall is in sight, along it (-1 or 1): on a wall beside the
## feature wall, the end that meets it; on the feature wall, the end on the side
## of a doorway in the wall across (the eye stands there), or away from one in
## a wall beside it (the eye looks across); 0 for the wall across, a feature
## wall with no such doorway, or a room with none.
static func feature_end(room: Dictionary, wall: String) -> float:
	var feature := String(room.get("feature", ""))
	if feature == "": return 0.0
	var along_z: bool = wall == "west" or wall == "east"
	if wall == feature:
		var across := LAYOUT.wall_of(-LAYOUT.way_of(feature))
		for door in FLOOR.doorways(room):
			var at := String(door.wall)
			var out := LAYOUT.way_of(at)
			if at == across and absf(float(door.along)) > 0.3: return signf(float(door.along))
			if at != across and at != wall: return -float(out.y if along_z else out.x)
		return 0.0
	var way := LAYOUT.way_of(feature)
	return float(way.y) if along_z else float(way.x)

## Pieces joined to the room's last wall run (spec_proporcion D4), in its group:
## past either of its ends with no gap, else round the corner it reaches (TURN_GAP)
## on the wall across; {} with no run or where none fits.
static func lay_run(room: Dictionary, zones: Array, kind: String, row: int, chain: Dictionary) -> Dictionary:
	if not chain.has("wall"): return {}
	var wall := String(chain.wall)
	var group := int(chain.group)
	var spec: Dictionary = OFFICE.FURNITURE[kind]
	var size: Vector2 = spec.size
	var width := size.x * row
	var reach := LAYOUT.wall_length(room, wall) / 2
	for a: float in [float(chain.along) + float(chain.half) + width / 2, float(chain.along) - float(chain.half) - width / 2]:
		if absf(a) + width / 2 > reach: continue
		var pieces := wall_pieces(room, kind, row, wall, a, group)
		if not all_fit(room, zones, pieces, true): continue
		room.furniture.append_array(pieces)
		return {"wall": wall, "along": a, "half": width / 2, "group": group}
	# Past no end: round the corner the run reaches, from the corner the walls share;
	# a piece elsewhere would be no run, and goes as "wall".
	if reach - absf(float(chain.along)) - float(chain.half) > float(FROM_CORNER[0]) + size.y + TURN_GAP: return {}
	var high: bool = float(chain.along) >= 0.0
	var other: String = ("south" if high else "north") if wall == "west" or wall == "east" else ("east" if high else "west")
	if not usable(room, other): return {}
	var far := LAYOUT.wall_length(room, other) / 2
	var side: float = 1.0 if wall == "south" or wall == "east" else -1.0
	for off in FROM_CORNER:
		var a: float = side * (far - float(off) - width / 2)
		if a * side <= 0.0: break
		var pieces := wall_pieces(room, kind, row, other, a, group)
		if not all_fit(room, zones, pieces, true): continue
		room.furniture.append_array(pieces)
		return {"wall": other, "along": a, "half": width / 2, "group": group}
	return {}

## `row` pieces in the middle of the feature wall, where a pair of its flanks
## (palette.CENTER_FLANKS, laid by the "run" entry after it) fits either side, all
## one group, as the director's room in its reference; {wall, along, half, group,
## center}, or {} where the whole does not fit, and the entry goes as "wall".
static func lay_center(room: Dictionary, zones: Array, kind: String, row: int) -> Dictionary:
	var wall := String(room.get("feature", ""))
	if wall == "" or not usable(room, wall): return {}
	var spec: Dictionary = OFFICE.FURNITURE[kind]
	var size: Vector2 = spec.size
	var half := size.x * row / 2
	var flank := String(OFFICE.CENTER_FLANKS[kind])
	var flank_spec: Dictionary = OFFICE.FURNITURE[flank]
	var flank_size: Vector2 = flank_spec.size
	var group: int = room.furniture.size()
	var pieces := wall_pieces(room, kind, row, wall, 0.0, group)
	var whole: Array = pieces + wall_pieces(room, flank, 1, wall, half + flank_size.x / 2, group) + wall_pieces(room, flank, 1, wall, -half - flank_size.x / 2, group)
	if not all_fit(room, zones, whole, false): return {}
	room.furniture.append_array(pieces)
	return {"wall": wall, "along": 0.0, "half": half, "group": group, "center": true}

## `row` free-standing pieces side by side toward the feature wall, their backs
## to it (or a quarter turned, for ANY_WAY), at the first of MIDDLE_DEPTHS and
## MIDDLE_SIDES that fits; false where none does.
static func lay_middle(room: Dictionary, zones: Array, kind: String, row := 1) -> bool:
	var wall := String(room.get("feature", ""))
	var n: Vector2 = LAYOUT.inward(wall) if wall != "" else Vector2(0, 1)
	var side := Vector2(-n.y, n.x)
	var turn: int = int(TURNS[wall]) if wall != "" else 0
	var turns: Array = [turn, (turn + 1) % 4] if ANY_WAY.has(kind) and row == 1 else [turn]
	var spec: Dictionary = OFFICE.FURNITURE[kind]
	var size: Vector2 = spec.size
	var group: int = room.furniture.size()
	var near := Near.new(room, zones, group, LAYOUT.inner(room))
	for depth in MIDDLE_DEPTHS:
		for aside in MIDDLE_SIDES:
			for spin in turns:
				# The row's whole rect first: most places fail on it, before any piece is made.
				var across: bool = (absf(side.x) > 0.5) == (int(spin) % 2 == 0)
				var extent: Vector2 = Vector2(size.x * row, size.y) if across else Vector2(size.y, size.x * row)
				if absf(side.x) < 0.5: extent = Vector2(extent.y, extent.x)
				var centre: Vector2 = -n * float(depth) + side * float(aside)
				if not near.clear(Rect2(centre - extent / 2, extent)): continue
				var pieces: Array = []
				for k in row: pieces.append(item(kind, -n * float(depth) + side * (float(aside) + (float(k) - float(row - 1) / 2.0) * size.x), int(spin), group))
				if all_fit(room, zones, pieces, false):
					room.furniture.append_array(pieces)
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
			# Off the fittings' slots (office_walls.corridor(): every CORRIDOR_PITCH of
			# the world along the wall), so the corridor keeps its wall dressed.
			var pitch: float = OFFICE.CORRIDOR_PITCH
			if absf(float(pos) - roundf(float(pos) / pitch) * pitch) < float(piece.size[0]) / 2 + HALL_SLOT_CLEAR: continue
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
