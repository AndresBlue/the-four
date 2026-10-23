extends RefCounted
## Plan geometry of a room's floor, room-local (x, z) from the cell centre: what free-standing furniture
## must keep clear, so the generator places and the validator checks with one rule. The zones are the
## paths of map_validator.validate_physics() (its capsule is radius 0.32) with a margin.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PALETTE := preload("res://game/floors/palettes/office_palette.gd")
const CENTRE_CLEAR := 0.6
const SWEEP_CLEAR := 0.45      # capsule 0.32 plus a margin
const DOOR_BAND := 1.5         # out from a doorway's wall (the leaf sweeps 1.2)
const DOOR_SIDE := 0.3         # past each jamb along the wall
const FIXTURE_CLEAR := Vector2(1.2, 1.2)
const LOCKER := Vector2(1.3, 0.7)
const ITEM_GAP := 0.9
const INNER_PAD := 0.02
## Room for rounding: positions are stored to the millimetre.
const EPS := 0.001

## Into the room from a wall, room-local (x, z).
static func inward(wall: String) -> Vector2:
	match wall:
		"west": return Vector2(1, 0)
		"east": return Vector2(-1, 0)
		"north": return Vector2(0, 1)
		"south": return Vector2(0, -1)
	return Vector2.ZERO

## The grid step to the neighbour behind a wall.
static func way_of(wall: String) -> Vector2i:
	match wall:
		"west": return Vector2i(-1, 0)
		"east": return Vector2i(1, 0)
		"north": return Vector2i(0, -1)
		"south": return Vector2i(0, 1)
	return Vector2i.ZERO

## The wall a unit grid step goes through; "" for anything else.
static func wall_of(way: Vector2i) -> String:
	if way == Vector2i(-1, 0): return "west"
	if way == Vector2i(1, 0): return "east"
	if way == Vector2i(0, -1): return "north"
	if way == Vector2i(0, 1): return "south"
	return ""

## The yaw of something on a wall facing into the room (FLOOR.hiding_yaw()'s rule).
static func wall_yaw(wall: String) -> float:
	match wall:
		"west": return PI / 2
		"east": return -PI / 2
		"south": return PI
	return 0.0

## The yaw that faces along a grid step.
static func yaw_of(way: Vector2i) -> float:
	if way == Vector2i(1, 0): return PI / 2
	if way == Vector2i(0, -1): return PI
	if way == Vector2i(-1, 0): return -PI / 2
	return 0.0

## The wall a yaw faces out of; "" when it is none of the four.
static func wall_of_yaw(yaw: float) -> String:
	if is_equal_approx(yaw, PI / 2): return "west"
	if is_equal_approx(yaw, -PI / 2): return "east"
	if is_equal_approx(yaw, 0.0): return "north"
	if is_equal_approx(yaw, PI) or is_equal_approx(yaw, -PI): return "south"
	return ""

## How long a wall is: west and east run along z.
static func wall_length(room: Dictionary, wall: String) -> float:
	return float(room.span_z) if wall == "west" or wall == "east" else float(room.span_x)

## Where a wall's inner face is: x for west and east, z for north and south.
static func face(room: Dictionary, wall: String) -> float:
	var half: float = PALETTE.WALL_HALF
	match wall:
		"west": return -float(room.span_x) / 2 + half
		"east": return float(room.span_x) / 2 - half
		"north": return -float(room.span_z) / 2 + half
	return float(room.span_z) / 2 - half

## The band along a wall from along - half to along + half, depth metres in from its inner face.
static func wall_rect(room: Dictionary, wall: String, along: float, half: float, depth: float) -> Rect2:
	var at := face(room, wall)
	match wall:
		"west": return Rect2(at, along - half, depth, half * 2)
		"east": return Rect2(at - depth, along - half, depth, half * 2)
		"north": return Rect2(along - half, at, half * 2, depth)
	return Rect2(along - half, at - depth, half * 2, depth)

## The wall a hide [x, z] stands against and where along it (FLOOR.hiding_yaw()'s rule).
static func hide_wall(hide: Array) -> Dictionary:
	var x := float(hide[0])
	var z := float(hide[1])
	if absf(x) > absf(z): return {"wall": "west" if x < 0 else "east", "along": z}
	return {"wall": "north" if z < 0 else "south", "along": x}

## Whether r lies inside outer, allowing for the millimetre rounding.
static func fits_in(outer: Rect2, r: Rect2) -> bool:
	return outer.grow(EPS).encloses(r)

## Whether a and b are at least gap apart, allowing for the millimetre rounding.
static func apart(a: Rect2, b: Rect2, gap: float) -> bool:
	return not a.grow(gap - EPS).intersects(b)

## The floor inside the walls, less a pad.
static func inner(room: Dictionary) -> Rect2:
	var half: float = PALETTE.WALL_HALF
	var hx := float(room.span_x) / 2 - half - INNER_PAD
	var hz := float(room.span_z) / 2 - half - INNER_PAD
	return Rect2(-hx, -hz, hx * 2, hz * 2)

## A piece's plan: at, size, turn (odd turns swap the size).
static func footprint(item: Dictionary) -> Rect2:
	var centre := Vector2(float(item.at[0]), float(item.at[1]))
	var size := Vector2(float(item.size[0]), float(item.size[1]))
	if int(item.turn) % 2 == 1: size = Vector2(size.y, size.x)
	return Rect2(centre - size / 2, size)

## How far the cover sweeps reach toward the corners.
static func cover_reach(room: Dictionary) -> float:
	return minf(2.2, minf(float(room.span_x), float(room.span_z)) * 0.5 - 2.5)

## Room-local {wall, along, half} of every wall spot in the room: what the
## mail, the power, the air, the stations and the wall exits fix to its walls.
static func fixtures(manifest: Dictionary, room_id: int) -> Array:
	var found: Array = []
	for key in ["mail", "power", "air"]: gather(manifest.get(key, {}), found)
	for exit in manifest.get("tubes", {}).get("exits", []):
		if exit is Dictionary and String(exit.get("kind", "")) == "station": found.append(exit)
	for exit in manifest.get("ducts", {}).get("exits", []):
		if exit is Dictionary and String(exit.get("kind", "")) == "wall": found.append(exit)
	var room: Dictionary = manifest.rooms[room_id]
	var out: Array = []
	for spot in found:
		var point: Array = spot.point
		var p := Vector3(float(point[0]), float(point[1]), float(point[2]))
		if int(FLOOR.room_at(manifest.rooms, p).get("id", -1)) != room_id: continue
		var wall := wall_of_yaw(float(spot.yaw))
		if wall == "": continue
		var local := Vector2(p.x - float(room.px), p.z - float(room.pz))
		var off: float = local.x if wall == "west" or wall == "east" else local.y
		if absf(off - face(room, wall)) > 0.6: continue
		var along: float = local.y if wall == "west" or wall == "east" else local.x
		out.append({"wall": wall, "along": along, "half": FIXTURE_CLEAR.x / 2})
	return out

## Every Dictionary with a point and a yaw, however deep under value.
static func gather(value: Variant, out: Array) -> void:
	if value is Dictionary:
		var entry: Dictionary = value
		if entry.has("point") and entry.has("yaw") and entry.point is Array and (entry.point as Array).size() == 3: out.append(entry)
		for key in entry: gather(entry[key], out)
	elif value is Array:
		for item in value: gather(item, out)

## What free-standing furniture must keep clear in a room, as capsules
## {a, b, r} and rects {rect}, room-local.
static func clear_zones(manifest: Dictionary, room: Dictionary, exempt_cover: bool) -> Array:
	var zones: Array = [{"a": Vector2.ZERO, "b": Vector2.ZERO, "r": CENTRE_CLEAR}]
	var span_x := float(room.span_x)
	var span_z := float(room.span_z)
	if not exempt_cover:
		var c := cover_reach(room)
		if c > 0:
			for corner in [Vector2(-c, -c), Vector2(c, -c), Vector2(-c, c), Vector2(c, c)]:
				zones.append({"a": Vector2.ZERO, "b": corner, "r": SWEEP_CLEAR})
	var rooms: Array = manifest.rooms
	var open: Array = room.get("open_sides", [])
	for n in manifest.adjacency[int(room.id)]:
		var other: Dictionary = rooms[int(n)]
		var t := Vector2(float(int(other.x) - int(room.x)), float(int(other.z) - int(room.z)))
		var d: Vector2
		if open.has(wall_of(Vector2i(int(t.x), int(t.y)))): d = Vector2(t.x * span_x / 2, t.y * span_z / 2)
		else:
			var p := FLOOR.portal_between(room, other) - FLOOR.position_of(room)
			d = Vector2(p.x, p.z)
		zones.append({"a": Vector2.ZERO, "b": d - t, "r": SWEEP_CLEAR})
		zones.append({"a": d - t, "b": d, "r": SWEEP_CLEAR})
	for way in FLOOR.doorways(room):
		zones.append({"rect": wall_rect(room, String(way.wall), float(way.along), FLOOR.PORTAL / 2 + DOOR_SIDE, DOOR_BAND)})
	for h in room.get("hides", []):
		var hw := hide_wall(h)
		zones.append({"rect": wall_rect(room, String(hw.wall), float(hw.along), LOCKER.x / 2, LOCKER.y)})
		var ap := FLOOR.hiding_approach(Vector3(float(h[0]), 0.0, float(h[1])))
		zones.append({"a": Vector2.ZERO, "b": Vector2(ap.x, ap.z), "r": SWEEP_CLEAR})
		zones.append({"a": Vector2(ap.x, ap.z), "b": Vector2(float(h[0]), float(h[1])), "r": SWEEP_CLEAR})
	if room.has("sockets"):
		for prop in room.get("props", []):
			var s: Array = room.sockets[int(prop.slot)]
			var size := Vector2(2.3, 1.4) if int(prop.rotation) % 2 == 0 else Vector2(1.4, 2.3)
			var centre := Vector2(float(s[0]), float(s[1]))
			zones.append({"rect": Rect2(centre - size / 2, size)})
	for fx in fixtures(manifest, int(room.id)):
		zones.append({"rect": wall_rect(room, String(fx.wall), float(fx.along), FIXTURE_CLEAR.x / 2, FIXTURE_CLEAR.y)})
	var lift := FLOOR.lift_wall(room)
	if lift != Vector2i.ZERO:
		var space := inner(room)
		if lift.x != 0:
			var line := float(lift.x) * (span_x / 2 - FLOOR.LIFT_DEPTH)
			var x0: float = line - 1.2 if lift.x > 0 else line
			zones.append({"rect": Rect2(x0, space.position.y, 1.2, space.size.y)})
		else:
			var line := float(lift.y) * (span_z / 2 - FLOOR.LIFT_DEPTH)
			var z0: float = line - 1.2 if lift.y > 0 else line
			zones.append({"rect": Rect2(space.position.x, z0, space.size.x, 1.2)})
	return zones

## Whether a rect cuts into any zone.
static func blocked(rect: Rect2, zones: Array) -> bool:
	for zone in zones:
		if zone.has("rect"):
			if rect.intersects(zone.rect): return true
		elif segment_rect_distance(zone.a, zone.b, rect) < float(zone.r): return true
	return false

## The distance from a segment to a rect; 0 when they touch.
static func segment_rect_distance(a: Vector2, b: Vector2, rect: Rect2) -> float:
	if rect.has_point(a) or rect.has_point(b): return 0.0
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null: return 0.0
	var least := minf(point_rect_distance(a, rect), point_rect_distance(b, rect))
	for corner in corners:
		least = minf(least, Geometry2D.get_closest_point_to_segment(corner, a, b).distance_to(corner))
	return least

## The distance from a point to a rect.
static func point_rect_distance(p: Vector2, rect: Rect2) -> float:
	var near := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	return p.distance_to(near)

## Each rect less cut, as at most 4 rects: the bands above and below at full
## width, and those left and right at the cut's height.
static func rect_minus(rects: Array, cut: Rect2) -> Array:
	var out: Array = []
	for item in rects:
		var r: Rect2 = item
		if not r.intersects(cut):
			out.append(r)
			continue
		var top := cut.position.y
		var bottom := cut.end.y
		var pieces: Array = []
		pieces.append(Rect2(r.position.x, r.position.y, r.size.x, top - r.position.y))
		pieces.append(Rect2(r.position.x, bottom, r.size.x, r.end.y - bottom))
		var y0 := maxf(r.position.y, top)
		var y1 := minf(r.end.y, bottom)
		pieces.append(Rect2(r.position.x, y0, cut.position.x - r.position.x, y1 - y0))
		pieces.append(Rect2(cut.end.x, y0, r.end.x - cut.end.x, y1 - y0))
		for piece in pieces:
			var p: Rect2 = piece
			if p.size.x > 0.0001 and p.size.y > 0.0001: out.append(p)
	return out
