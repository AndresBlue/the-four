extends "res://game/world/generation/map_validator.gd"
## The offices' validator (docs/OFICINAS.md 11.3; spec_f1_generator.md 3.1):
## the hotel's checks read through the office palette, and then what the
## office generator promises, checked on the manifest alone. Its thresholds
## are its own, not read from the generator.
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const METRES := preload("res://game/world/generation/conduit_metres.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
const SHORTCUT_MIN := 0.55
const AISLE_MIN := 0.95
const SLACK := 0.01
const SLEEVE := 0.05          # round a crawl box in the ceiling band (geometry 4.1)
const PLENUM_KEYS := ["ceiling", "slab", "duct_y", "main", "duct", "branch"]

func validate(data: Dictionary) -> Array[String]:
	var errors := super.validate(data)
	if int(data.get("floor", 1)) == 2: errors.append_array(office(data))
	return errors

## The office's own checks, group by group (spec 3.1).
func office(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	spots = fixtures_by_room(data)
	if not plenum_ok(data, errors): return errors
	rooms_ok(data, errors)
	specials_ok(data, errors)
	if not bool(data.get("fallback", false)): depths_ok(data, errors)
	departments_ok(data, errors)
	lockers_ok(data, errors)
	archives_ok(data, errors)
	mail_ok(data, errors)
	power_ok(data, errors)
	air_ok(data, errors)
	ducts_ok(data, errors)
	arrival_ok(data, errors)
	corners_ok(data, errors)
	glazed_ok(data, errors)
	furniture_ok(data, errors)
	return errors

## LAYOUT.fixtures() of every room at once, by room id: one pass over the
## wall spots instead of one per room asked.
var spots := {}

func fixtures_by_room(data: Dictionary) -> Dictionary:
	var found: Array = []
	for key in ["mail", "power", "air"]: LAYOUT.gather(data.get(key, {}), found)
	for exit in data.get("tubes", {}).get("exits", []):
		if exit is Dictionary and String(exit.get("kind", "")) == "station": found.append(exit)
	for exit in data.get("ducts", {}).get("exits", []):
		if exit is Dictionary and String(exit.get("kind", "")) == "wall": found.append(exit)
	var out := {}
	for spot in found:
		var p := v3(spot.point)
		var room: Dictionary = FLOOR.room_at(data.rooms, p)
		if room.is_empty(): continue
		var wall := LAYOUT.wall_of_yaw(float(spot.yaw))
		if wall == "": continue
		var local := local_of(room, p)
		var off: float = local.x if wall == "west" or wall == "east" else local.y
		if absf(off - LAYOUT.face(room, wall)) > 0.6: continue
		var along: float = local.y if wall == "west" or wall == "east" else local.x
		if not out.has(int(room.id)): out[int(room.id)] = []
		out[int(room.id)].append({"wall": wall, "along": along, "half": LAYOUT.FIXTURE_CLEAR.x / 2})
	return out

static func v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func near(a: float, b: float, e := 0.001) -> bool:
	return absf(a - b) <= e

## The rooms of a type on a wing, by id.
static func of_type(data: Dictionary, wing: int, room_type: int) -> Array:
	return data.rooms.filter(func(room): return int(room.wing) == wing and int(room.type) == room_type)

## Where a wall's spot sits: its wall and along, room-local.
static func local_of(room: Dictionary, point: Vector3) -> Vector2:
	return Vector2(point.x - float(room.px), point.z - float(room.pz))

## 1. The floor, its version and the plenum's heights.
func plenum_ok(data: Dictionary, errors: Array[String]) -> bool:
	if int(data.get("floor", 0)) != 2: errors.append("office_floor")
	if int(data.get("version", 0)) != OFFICE.VERSION: errors.append("office_version")
	var plenum: Dictionary = data.get("plenum", {})
	if not PLENUM_KEYS.all(func(key): return plenum.has(key)):
		errors.append("plenum")
		return false
	var duct_y := float(plenum.duct_y)
	var main := float(plenum.main)
	var tallest := 0.0
	for room in data.rooms:
		if int(room.type) != OFFICE.VOID and OFFICE.false_ceiling(room): tallest = maxf(tallest, float(room.get("height", 0.0)))
	var ok: bool = duct_y - main / 2 >= float(plenum.ceiling) + 0.1 - 0.001 and duct_y + main / 2 <= float(plenum.slab) - 0.05 + 0.001
	for key in ["duct", "branch"]:
		if duct_y - float(plenum[key][1]) / 2 < tallest + 0.05 - 0.001: ok = false
	if not ok: errors.append("plenum")
	return true

## 2. Types, heights, dark rooms, empty archives, no boardroom on the main duct.
func rooms_ok(data: Dictionary, errors: Array[String]) -> void:
	var main_cells: Array = data.get("air", {}).get("main", {}).get("cells", [])
	for room in data.rooms:
		var t := int(room.type)
		var id := int(room.id)
		if not range(OFFICE.HEIGHTS.size()).has(t):
			errors.append("type_%d" % id)
			continue
		if t == OFFICE.VOID: continue
		if not near(float(room.get("height", 0.0)), OFFICE.height_of(room)): errors.append("height_%d" % id)
		if bool(room.get("dark", false)) and not OFFICE.may_be_dark(room): errors.append("dark_%d" % id)
		if (t == OFFICE.ARCHIVE or t == OFFICE.MOBILE_ARCHIVE) and (not room.props.is_empty() or not room.get("furniture", []).is_empty()): errors.append("type_%d" % id)
		if t == OFFICE.BOARDROOM and main_cells.has(id): errors.append("type_%d" % id)

## 3. One of each special piece, and the stage rooms where the floor says.
func specials_ok(data: Dictionary, errors: Array[String]) -> void:
	for want in [["window", 0, OFFICE.WINDOW], ["electrical", 1, OFFICE.ELECTRICAL], ["security", 2, OFFICE.SECURITY], ["air_room", 2, OFFICE.AIR_ROOM], ["air_plant", 2, OFFICE.AIR_PLANT]]:
		if of_type(data, int(want[1]), int(want[2])).size() != 1: errors.append("special_%s" % String(want[0]))
	var refuges: Array = data.refuges
	var gates: Array = data.gates
	var air_room := of_type(data, 2, OFFICE.AIR_ROOM)
	if air_room.size() == 1 and int(air_room[0].id) != int(refuges[2]): errors.append("special_air_room")
	var plant := of_type(data, 2, OFFICE.AIR_PLANT)
	if plant.size() == 1:
		var p: Dictionary = plant[0]
		var pair := [mini(int(p.id), int(refuges[2])), maxi(int(p.id), int(refuges[2]))]
		if int(p.id) != int(gates[2].beyond) or not bool(p.get("landing", false)) or not data.merged.has(pair): errors.append("special_air_plant")
	var kinds := {OFFICE.REFUGE: [int(refuges[0]), int(refuges[1])], OFFICE.LANDING: [int(gates[0].beyond), int(gates[1].beyond)], OFFICE.LOBBY: [int(data.entries[1]), int(data.entries[2])]}
	var names := {OFFICE.REFUGE: "refuge", OFFICE.LANDING: "landing", OFFICE.LOBBY: "lobby"}
	for t in kinds:
		var ids: Array = data.rooms.filter(func(room): return int(room.type) == int(t)).map(func(room): return int(room.id))
		ids.sort()
		var want: Array = kinds[t].duplicate()
		want.sort()
		if ids != want: errors.append("special_%s" % String(names[t]))

## How deep a room lies in its planta: walking metres from the planta's entry
## over the deepest reachable room's, the landing left out.
static func share_in(data: Dictionary, planta: int, id: int) -> float:
	var route := FLOOR.route_metres(data, int(data.entries[planta]))
	var landing := int(data.gates[planta].beyond)
	var most := 0.0
	for key in route:
		if int(key) != landing and int(data.rooms[int(key)].wing) == planta: most = maxf(most, float(route[key]))
	return float(route.get(id, INF)) / most if most > 0.0 else 0.0

## 4. The special pieces and the refuges at their depth, and planta 0's walk.
func depths_ok(data: Dictionary, errors: Array[String]) -> void:
	for want in [["window", 0, OFFICE.WINDOW, OFFICE.WINDOW_DEPTH], ["electrical", 1, OFFICE.ELECTRICAL, OFFICE.ELECTRICAL_DEPTH], ["security", 2, OFFICE.SECURITY, OFFICE.SECURITY_DEPTH]]:
		var found := of_type(data, int(want[1]), int(want[2]))
		if found.size() != 1: continue
		var band: Vector2 = want[3]
		var share := share_in(data, int(want[1]), int(found[0].id))
		if share < band.x - SLACK or share > band.y + SLACK: errors.append("depth_%s_%d" % [String(want[0]), int(want[1])])
	for planta in 3:
		var band: Vector2 = OFFICE.DEPTHS[planta]
		var share := share_in(data, planta, int(data.refuges[planta]))
		if share < band.x - SLACK or share > band.y + SLACK: errors.append("depth_refuge_%d" % planta)
	var walk := float(FLOOR.route_metres(data, int(data.entries[0])).get(int(data.refuges[0]), 0.0))
	if walk < 110.0 * sqrt(float(data.areas[0])) - 0.5: errors.append("depth_walk_0")

## 5. A department per sector, names and colours unique, SEGURIDAD on the
## security office's.
func departments_ok(data: Dictionary, errors: Array[String]) -> void:
	var departments: Array = data.get("departments", [])
	if departments.size() != 3:
		errors.append("departments")
		return
	for planta in 3:
		var sectors := {}
		for room in data.rooms:
			if int(room.wing) == planta and int(room.type) != OFFICE.VOID: sectors[int(room.sector)] = true
		var named := {}
		var names := {}
		var colours := {}
		var ok: bool = true
		for entry in departments[planta]:
			var c := int(entry.colour)
			if named.has(int(entry.sector)) or names.has(String(entry.name)) or colours.has(c) or c < 0 or c >= OFFICE.STRIPES.size(): ok = false
			named[int(entry.sector)] = true
			names[String(entry.name)] = int(entry.sector)
			colours[c] = true
		if named.size() != sectors.size() or not sectors.keys().all(func(s): return named.has(s)): ok = false
		if planta == 2:
			var security := of_type(data, 2, OFFICE.SECURITY)
			if security.size() == 1 and int(names.get("SEGURIDAD", -1)) != int(security[0].sector): ok = false
		if not ok: errors.append("departments_%d" % planta)

## 6. Lockers only where the type keeps them, clear of the wall spots.
func lockers_ok(data: Dictionary, errors: Array[String]) -> void:
	for room in data.rooms:
		var hides: Array = room.get("hides", [])
		if hides.is_empty(): continue
		var id := int(room.id)
		if not palette.WARDROBES.has(int(room.type)):
			errors.append("lockers_%d" % id)
			continue
		var fixed: Array = spots.get(id, [])
		for h in hides:
			var hw := LAYOUT.hide_wall(h)
			if fixed.any(func(s): return String(s.wall) == String(hw.wall) and absf(float(s.along) - float(hw.along)) < OFFICE.WALL_APART - 0.001):
				errors.append("lockers_%d" % id)
				break

## 7. Each archive: one straight unit of archive cells, rows inside it and
## apart, the spine through every centre, aisles wide enough, doors clear.
func archives_ok(data: Dictionary, errors: Array[String]) -> void:
	var a: Dictionary = OFFICE.ARCHIVE_LAYOUT
	var archives: Array = data.get("archives", [])
	for i in archives.size():
		var arch: Dictionary = archives[i]
		var axis := String(arch.axis)
		var cells: Array = arch.rooms
		var xs := {}
		var zs := {}
		var x0 := INF
		var x1 := -INF
		var z0 := INF
		var z1 := -INF
		var ok: bool = true
		for id in cells:
			var r: Dictionary = data.rooms[int(id)]
			if int(r.type) != OFFICE.ARCHIVE and int(r.type) != OFFICE.MOBILE_ARCHIVE: ok = false
			xs[int(r.x)] = true
			zs[int(r.z)] = true
			x0 = minf(x0, float(r.px) - float(r.span_x) / 2)
			x1 = maxf(x1, float(r.px) + float(r.span_x) / 2)
			z0 = minf(z0, float(r.pz) - float(r.span_z) / 2)
			z1 = maxf(z1, float(r.pz) + float(r.span_z) / 2)
		if xs.size() > 1 and zs.size() > 1: ok = false
		if (axis == "x" and xs.size() != cells.size()) or (axis == "z" and zs.size() != cells.size()): ok = false
		var inset := float(a.inset)
		var unit := Rect2(x0 + inset, z0 + inset, x1 - x0 - 2 * inset, z1 - z0 - 2 * inset)
		var rows: Array = arch.rows.map(func(r): return Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])))
		for k in rows.size():
			if not LAYOUT.fits_in(unit, rows[k]): ok = false
			for j in range(k + 1, rows.size()):
				if (rows[k] as Rect2).grow(-0.001).intersects(rows[j]): ok = false
		var s: Array = arch.spine
		var spine := Rect2(float(s[0]), float(s[1]), float(s[2]) - float(s[0]), float(s[3]) - float(s[1]))
		if (spine.size.y if axis == "x" else spine.size.x) < float(a.spine) - 0.001: ok = false
		for id in cells:
			var r: Dictionary = data.rooms[int(id)]
			if not spine.grow(0.001).has_point(Vector2(float(r.px), float(r.pz))): ok = false
		if float(arch.height) > OFFICE.FURNITURE_TOP + 0.001: ok = false
		# Doors: a band clear on the long walls, a deep end aisle on the short ones.
		var low := unit.position.x if axis == "x" else unit.position.y
		var high := unit.end.x if axis == "x" else unit.end.y
		var first := INF
		var last := -INF
		for r in rows:
			first = minf(first, (r as Rect2).position.x if axis == "x" else (r as Rect2).position.y)
			last = maxf(last, (r as Rect2).end.x if axis == "x" else (r as Rect2).end.y)
		for id in cells:
			var r: Dictionary = data.rooms[int(id)]
			for d in FLOOR.doorways(r):
				var wall := String(d.wall)
				var long_wall: bool = (axis == "x" and (wall == "north" or wall == "south")) or (axis == "z" and (wall == "west" or wall == "east"))
				if long_wall:
					if bool(arch.mobile): continue
					var door: float = (float(r.px) if axis == "x" else float(r.pz)) + float(d.along)
					var minus: bool = wall == "north" or wall == "west"
					for row in rows:
						var rr: Rect2 = row
						var mid: float = rr.get_center().y if axis == "x" else rr.get_center().x
						var centre: float = float(r.pz) if axis == "x" else float(r.px)
						if (mid < centre) != minus: continue
						var rs: float = rr.position.x if axis == "x" else rr.position.y
						var re: float = rr.end.x if axis == "x" else rr.end.y
						if rs < door + float(a.door_band) - 0.001 and re > door - float(a.door_band) + 0.001: ok = false
				elif not rows.is_empty() and not cells.has(int(d.other)):
					var end_aisle: float = first - low if wall == "west" or wall == "north" else high - last
					if end_aisle < float(a.door_depth) - 0.001: ok = false
		if not ok: errors.append("archive_%d" % i)
		for aisle in arch.aisles:
			var wide: float = float(aisle[2]) - float(aisle[0]) if axis == "x" else float(aisle[3]) - float(aisle[1])
			if wide < AISLE_MIN - 0.001:
				errors.append("aisle_%d" % i)
				break

## Whether a point stands on a closed wall of a room: on its inner face, not
## an open side. The wall, or "" when it is on none.
static func on_wall(room: Dictionary, point: Vector3, wall: String, inset := 0.0) -> bool:
	if room.get("open_sides", []).has(wall): return false
	var local := local_of(room, point)
	var off: float = local.x if wall == "west" or wall == "east" else local.y
	var n := LAYOUT.inward(wall)
	return near(off, LAYOUT.face(room, wall) + (n.x + n.y) * inset, 0.01)

## 8. The post: the window's fixtures, the reader, the stations and the tubes.
func mail_ok(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("mail") or not data.has("tubes"):
		errors.append("mail")
		return
	var rooms: Array = data.rooms
	var mail: Dictionary = data.mail
	var win: Dictionary = rooms[int(mail.window)]
	var py := float(win.py)
	var ok: bool = int(win.type) == OFFICE.WINDOW
	var doors: Array = FLOOR.doorways(win).map(func(d): return String(d.wall))
	if not on_wall(win, v3(mail.desk.point), String(mail.desk.wall), 0.55) or not on_wall(win, v3(mail.map.point), String(mail.map.wall)): ok = false
	for hub in data.tubes.exits:
		if String(hub.kind) == "hub" and not on_wall(win, v3(hub.point), LAYOUT.wall_of_yaw(float(hub.yaw))): ok = false
	if doors.has(String(mail.desk.wall)): ok = false
	var desk := v3(mail.desk.point)
	var stand := v3(mail.stand.point)
	var gap := Vector2(desk.x, desk.z).distance_to(Vector2(stand.x, stand.z))
	if gap < 0.5 - 0.001 or gap > 0.8 + 0.001 or not near(stand.y, py): ok = false
	var camera := v3(mail.camera)
	if int(FLOOR.room_at(rooms, camera).get("id", -1)) != int(win.id) or not near(camera.y, py + float(win.height) - 0.15, 0.01) or Vector2(camera.x, camera.z).distance_to(Vector2(desk.x, desk.z)) < 2.0: ok = false
	if v3(mail.camera_target).distance_to(stand + Vector3(0, 1.3, 0)) > 0.01: ok = false
	if not ok: errors.append("mail")
	# The reader, on the freight lobby's side of the stage gate.
	var gate: Dictionary = data.gates[0]
	var reader: Dictionary = mail.reader
	var lobby: Dictionary = rooms[int(gate.room)]
	var wall := LAYOUT.wall_of(Vector2i(int(gate.out[0]), int(gate.out[1])))
	var rp := v3(reader.point)
	var portal := FLOOR.portal_between(lobby, rooms[int(gate.beyond)])
	var along_gap: float = absf((rp.z - portal.z) if wall == "west" or wall == "east" else (rp.x - portal.x))
	if int(reader.room) != int(gate.room) or String(reader.wall) != wall or not on_wall(lobby, rp, wall) or along_gap > 1.5 + 0.001 or not near(rp.y, float(lobby.py) + 1.2, 0.01): errors.append("mail_reader")
	# The stations.
	var tubes: Dictionary = data.tubes
	var stations: Array = tubes.exits.filter(func(e): return String(e.kind) == "station")
	if int(mail.stations) != stations.size() or stations.size() < OFFICE.STATIONS.x or stations.size() > OFFICE.STATIONS.y: errors.append("station_count")
	var numbers: Array = stations.map(func(e): return int(e.get("number", 0)))
	numbers.sort()
	if numbers != range(1, stations.size() + 1): errors.append("station_numbers")
	var hubs: Array = tubes.exits.filter(func(e): return String(e.kind) == "hub")
	var nodes: Array = tubes.nodes
	if hubs.size() != 1 or int(hubs[0].room) != int(win.id) or METRES.pieces(tubes, range(nodes.size())) != 1 or nodes.size() != tubes.edges.size() + 1 or tubes.rooms.size() != nodes.size() or tubes.rooms.any(func(r): return int(r) < 0 or int(r) >= rooms.size() or int(rooms[int(r)].type) == OFFICE.VOID):
		errors.append("tube_graph")
		return
	var from_hub := METRES.metres(tubes, int(hubs[0].node))
	var seen := {}
	for e in stations:
		var room: Dictionary = rooms[int(e.room)]
		var p := v3(e.point)
		var bad: bool = seen.has(int(e.room)) or int(room.wing) != 0 or bool(room.corridor) or OFFICE.off_limits(room) or int(room.id) == int(win.id) or int(room.type) == OFFICE.RECEPTION
		seen[int(e.room)] = true
		var wall_of := String(e.get("wall", LAYOUT.wall_of_yaw(float(e.yaw))))
		if not on_wall(room, p, wall_of) or not near(p.y, float(room.py) + OFFICE.STATION_Y, 0.01): bad = true
		var local := local_of(room, p)
		var along: float = local.y if wall_of == "west" or wall_of == "east" else local.x
		for d in FLOOR.doorways(room):
			if String(d.wall) == wall_of and absf(float(d.along) - along) < HIDE_CLEAR - 0.001: bad = true
		var metres := float(from_hub.get(int(e.node), INF))
		if not near(metres, float(e.tube), 0.01) or metres < OFFICE.STATION_TUBE_MIN - 0.001: bad = true
		if bad: errors.append("station_%d" % int(e.get("number", 0)))
	var apart := OFFICE.STATION_APART * sqrt(float(data.areas[0])) * 0.8
	for e in stations:
		var walks := METRES.walk_within(rooms, data.adjacency, int(e.room), apart)
		if stations.any(func(o): return int(o.room) != int(e.room) and walks.has(int(o.room)) and float(walks[int(o.room)]) < apart - 0.001):
			errors.append("station_apart")
			break
	# The runs: square, at TUBE_Y, through the rooms they say, over doors.
	for edge in tubes.edges:
		var a := v3(nodes[int(edge[0])])
		var b := v3(nodes[int(edge[1])])
		if not near(a.y, b.y): continue
		var ra := int(tubes.rooms[int(edge[0])])
		var rb := int(tubes.rooms[int(edge[1])])
		var bad: bool = not near(a.y, float(rooms[ra].py) + OFFICE.TUBE_Y) or (not near(a.x, b.x) and not near(a.z, b.z))
		# Sampled at the middles of 0.5 m steps: a node on a doorway is on two rooms.
		var steps := maxi(1, ceili(a.distance_to(b) / 0.5))
		var last := -1
		for k in steps:
			var at := a.lerp(b, (float(k) + 0.5) / float(steps))
			var here := int(FLOOR.room_at(rooms, at).get("id", -1))
			if here != ra and here != rb:
				bad = true
				break
			if last >= 0 and here != last:
				var door := FLOOR.portal_between(rooms[last], rooms[here])
				var before := a.lerp(b, (float(k) - 0.5) / float(steps))
				var d2 := Vector2(door.x, door.z)
				if d2.distance_to(Geometry2D.get_closest_point_to_segment(d2, Vector2(before.x, before.z), Vector2(at.x, at.z))) > FLOOR.PORTAL / 2 + 0.001: bad = true
			last = here
		if bad:
			errors.append("tube_run_%d_%d" % [int(edge[0]), int(edge[1])])
			break

## 9. Planta 1's power: the board, a circuit a sector in lever order, every
## room on one, the timers on corridor stretches clear of the doors.
func power_ok(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("power"):
		errors.append("power")
		return
	var rooms: Array = data.rooms
	var power: Dictionary = data.power
	var el: Dictionary = rooms[int(power.room)]
	if int(el.type) != OFFICE.ELECTRICAL or not on_wall(el, v3(power.board.point), String(power.board.wall)) or int(power.lift_lever) != power.circuits.size(): errors.append("power")
	var sectors := {}
	var want: Array = []
	for room in rooms:
		if int(room.wing) != 1 or int(room.type) == OFFICE.VOID: continue
		sectors[int(room.sector)] = true
		if not OFFICE.off_limits(room) and int(room.id) != int(el.id): want.append(int(room.id))
	if power.circuits.size() != sectors.size(): errors.append("circuit_count")
	var got: Array = []
	for i in power.circuits.size():
		var c: Dictionary = power.circuits[i]
		if int(c.lever) != i or String(c.code) != "R-%d" % (i + 1): errors.append("circuit_order")
		got.append_array(c.rooms.map(func(id): return int(id)))
	got.sort()
	want.sort()
	if got != want: errors.append("circuit_cover")
	var corridor := 0
	for room in rooms:
		if int(room.wing) == 1 and int(room.type) != OFFICE.VOID and bool(room.corridor): corridor += 1
	var covered := {}
	for i in power.timers.size():
		var t: Dictionary = power.timers[i]
		var ok: bool = not t.has("seconds") and t.rooms.has(int(t.room))
		for id in t.rooms:
			var r: Dictionary = rooms[int(id)]
			if int(r.wing) != 1 or not bool(r.corridor): ok = false
			covered[int(id)] = true
		var room: Dictionary = rooms[int(t.room)]
		if not on_wall(room, v3(t.point), String(t.wall)) or not near(v3(t.point).y, float(room.py) + 1.2, 0.01): ok = false
		for d in FLOOR.doorways(room):
			if String(d.wall) == String(t.wall) and absf(float(d.along) - float(t.along)) < FLOOR.PORTAL / 2 + 1.0 - 0.001: ok = false
		if not ok: errors.append("timer_%d" % i)
	if corridor > 0 and float(covered.size()) / float(corridor) < OFFICE.TIMER_COVER - 0.001: errors.append("timer_cover")

## The main duct's floor line in plan: its nodes, hatch to shaft.
static func main_line(data: Dictionary) -> Array:
	return data.air.main.nodes.map(func(k): return Vector2(float(data.ducts.nodes[int(k)][0]), float(data.ducts.nodes[int(k)][2])))

## 10. Planta 2's air: the card door, the hatch, the handler, the main duct,
## its crossing, the shaft and the remains.
func air_ok(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("air") or not data.has("ducts"):
		errors.append("air")
		return
	var rooms: Array = data.rooms
	var air: Dictionary = data.air
	var plenum: Dictionary = data.plenum
	var sec: Dictionary = air.security
	var sec_room: Dictionary = rooms[int(sec.room)]
	var outside := int(sec.outside)
	if int(sec_room.type) != OFFICE.SECURITY or data.adjacency[int(sec.room)].size() != 1 or int(data.adjacency[int(sec.room)][0]) != outside: errors.append("security_doors")
	var key := "%d:%d" % [mini(int(sec.room), outside), maxi(int(sec.room), outside)]
	var door: Dictionary = data.doors.get(key, {})
	if String(sec.door) != key or String(door.get("lock", "")) != "card" or bool(door.get("open", true)): errors.append("security_door")
	if not on_wall(sec_room, v3(sec.desk.point), String(sec.desk.wall)): errors.append("security_desk")
	var out_room: Dictionary = rooms[outside]
	var rwall := LAYOUT.wall_of(Vector2i(int(sec_room.x) - int(out_room.x), int(sec_room.z) - int(out_room.z)))
	var rp := v3(sec.reader.point)
	var portal := FLOOR.portal_between(out_room, sec_room)
	var along_gap: float = absf((rp.z - portal.z) if rwall == "west" or rwall == "east" else (rp.x - portal.x))
	if not on_wall(out_room, rp, rwall) or along_gap > 1.5 + 0.001 or not near(rp.y, float(out_room.py) + 1.2, 0.01): errors.append("security_reader")
	var gate: Dictionary = data.gates[2]
	if String(gate.get("kind", "")) != "shaft" or rooms[int(gate.beyond)].has("lift"): errors.append("shaft")
	# The hatch over the plant, toward the main duct's first cell.
	var main: Dictionary = air.main
	var cells: Array = main.cells
	var plant: Dictionary = rooms[int(air.plant)]
	var py := float(plant.py)
	if cells.is_empty() or int(cells[0]) != int(plant.id) or cells.size() < 2:
		errors.append("main_chain")
		return
	var c1: Dictionary = rooms[int(cells[1])]
	var d1 := Vector2i(int(c1.x) - int(plant.x), int(c1.z) - int(plant.z))
	var hp := v3(air.hatch.point)
	var want_hatch := Vector3(float(plant.px) + d1.x * (float(plant.span_x) / 2 - float(OFFICE.HATCH["in"])), py + float(plenum.duct_y), float(plant.pz) + d1.y * (float(plant.span_z) / 2 - float(OFFICE.HATCH["in"])))
	if hp.distance_to(want_hatch) > 0.01 or not is_equal_approx(float(air.hatch.yaw), LAYOUT.yaw_of(-d1)): errors.append("hatch")
	# The handler and its stop.
	var hatch_local := local_of(plant, hp)
	var foot := hatch_local - Vector2(d1) * float(OFFICE.HATCH.stand)
	var unit: Dictionary = air.unit
	var box := LAYOUT.wall_rect(plant, String(unit.wall), float(unit.along), OFFICE.AIR_UNIT.x / 2, OFFICE.AIR_UNIT.z)
	if not on_wall(plant, v3(unit.point), String(unit.wall)) or not near(v3(unit.point).y, py) or not LAYOUT.fits_in(LAYOUT.inner(plant).grow(LAYOUT.INNER_PAD), box) or box.intersects(Rect2(hatch_local - Vector2(0.75, 0.75), Vector2(1.5, 1.5))) or LAYOUT.point_rect_distance(foot, box) < 1.0 - 0.001: errors.append("unit")
	var stop: Dictionary = air.stop
	if String(stop.wall) != String(unit.wall) or absf(float(stop.along) - float(unit.along)) > OFFICE.AIR_UNIT.x / 2 + 1.5 + 0.001 or not near(v3(stop.point).y, py + 1.3, 0.01): errors.append("stop")
	# The chain of main nodes.
	var dn: Array = data.ducts.nodes
	var chain: Array = main.nodes
	var ok: bool = chain.size() == cells.size() + 1 and String(dn[int(chain[0])][4]) == "hatch" and String(dn[int(chain[-1])][4]) == "shaft"
	var mains := {}
	for edge in data.ducts.edges:
		if String(edge[3]) == "main": mains[pair_of(int(edge[0]), int(edge[1]))] = float(edge[2])
	if ok:
		for i in range(1, chain.size()):
			if not mains.has(pair_of(int(chain[i - 1]), int(chain[i]))): ok = false
		for i in range(1, cells.size()):
			var cell: Dictionary = rooms[int(cells[i])]
			if OFFICE.off_limits(cell) or v3(dn[int(chain[i])]).distance_to(Vector3(float(cell.px), float(cell.py) + float(plenum.duct_y), float(cell.pz))) > 0.01: ok = false
		if mains.size() != chain.size() - 1: ok = false
	if not ok:
		errors.append("main_chain")
		return
	var length := 0.0
	for k in mains: length += float(mains[k])
	var span: Vector2 = Vector2(15.0, 70.0) if bool(data.get("fallback", false)) else OFFICE.MAIN_LENGTH
	if length < span.x - 0.01 or length > span.y + 0.01 or not near(length, float(main.length), 0.01): errors.append("main_length")
	var line := main_line(data)
	var bends := 0
	for i in range(2, line.size()):
		if not (line[i] - line[i - 1]).normalized().is_equal_approx((line[i - 1] - line[i - 2]).normalized()): bends += 1
	if bends < OFFICE.MAIN_BENDS or bends != int(main.bends): errors.append("main_bends")
	cross_ok(data, chain, cells, errors)
	# The shaft past the last cell's wall, open, its landing at the duct's floor.
	var shaft: Dictionary = air.shaft
	var r: Array = shaft.rect
	var rect := Rect2(float(r[0]) - float(r[2]) / 2, float(r[1]) - float(r[3]) / 2, float(r[2]), float(r[3]))
	var e := Vector2i(int(shaft.side[0]), int(shaft.side[1]))
	var last: Dictionary = rooms[int(cells[-1])]
	var face: float = (float(last.px) + e.x * (float(last.span_x) / 2 + OFFICE.WALL_HALF)) if e.x != 0 else (float(last.pz) + e.y * (float(last.span_z) / 2 + OFFICE.WALL_HALF))
	var near_edge: float = (rect.get_center().x - e.x * rect.size.x / 2) if e.x != 0 else (rect.get_center().y - e.y * rect.size.y / 2)
	var floor_y := float(shaft.floor_y)
	var sp := v3(shaft.point)
	var bad: bool = rect.size.x < 2.0 - 0.001 or rect.size.y < 2.0 - 0.001 or not near(face, near_edge, 0.01) or not rect.grow(0.01).has_point(Vector2(sp.x, sp.z))
	if not near(floor_y, py + float(plenum.duct_y) - float(plenum.main) / 2): bad = true
	for room in rooms:
		if int(room.wing) != 2 or int(room.type) == OFFICE.VOID: continue
		var foot_print := Rect2(float(room.px) - float(room.span_x) / 2, float(room.pz) - float(room.span_z) / 2, float(room.span_x), float(room.span_z)).grow(-0.01)
		if foot_print.intersects(rect): bad = true
	for corner in [Vector2(0, 0), Vector2(-0.49, -0.49), Vector2(0.49, -0.49), Vector2(-0.49, 0.49), Vector2(0.49, 0.49)]:
		var at := Vector3(rect.get_center().x + corner.x * rect.size.x, floor_y, rect.get_center().y + corner.y * rect.size.y)
		if not FLOOR.room_at(rooms, at).is_empty(): bad = true
	var lp := v3(shaft.ladder.point)
	if not rect.grow(0.01).has_point(Vector2(lp.x, lp.z)) or not near(lp.y, floor_y): bad = true
	if bad: errors.append("shaft")
	# The remains on the duct's floor line.
	var remains := v3(air.remains.point)
	var q := Vector2(remains.x, remains.z)
	var off := INF
	for i in range(1, line.size()): off = minf(off, q.distance_to(Geometry2D.get_closest_point_to_segment(q, line[i - 1], line[i])))
	if off > 0.01 or not near(remains.y, floor_y): errors.append("remains")

## A pair of node indices as a key.
static func pair_of(a: int, b: int) -> int:
	return mini(a, b) * 1048576 + maxi(a, b)

## The crossing: one cross edge from an inner main node to a stub at
## main / 2 + STUB, on a side the main does not use, on her network toward a
## cell off the main.
func cross_ok(data: Dictionary, chain: Array, cells: Array, errors: Array[String]) -> void:
	var rooms: Array = data.rooms
	var dn: Array = data.ducts.nodes
	var plenum: Dictionary = data.plenum
	var main: Dictionary = data.air.main
	var crosses: Array = data.ducts.edges.filter(func(edge): return String(edge[3]) == "cross")
	if crosses.size() != 1:
		errors.append("main_cross")
		return
	var edge: Array = crosses[0]
	var m := int(main.cross)
	var s := int(edge[1]) if int(edge[0]) == m else int(edge[0])
	var i := chain.find(m)
	var reach := float(plenum.main) / 2 + OFFICE.STUB
	if (int(edge[0]) != m and int(edge[1]) != m) or i <= 0 or i >= chain.size() - 1 or String(dn[s][4]) != "stub" or not near(float(edge[2]), reach, 0.01):
		errors.append("main_cross")
		return
	var c: Dictionary = rooms[int(cells[i])]
	var stub := Vector2i(int(main.stub[0]), int(main.stub[1]))
	var line := main_line(data)
	var into := Vector2i((line[i] - line[i - 1]).normalized().round())
	var out := Vector2i((line[i + 1] - line[i]).normalized().round())
	var want := Vector2(float(c.px), float(c.pz)) + Vector2(stub) * reach
	var bad: bool = stub == -into or stub == out or absi(stub.x) + absi(stub.y) != 1 or Vector2(float(dn[s][0]), float(dn[s][2])).distance_to(want) > 0.01
	var n := FLOOR.beside(c, stub)
	var linked := false
	for other in data.ducts.edges:
		if String(other[3]) in ["trunk", "branch", "bridge", "loose"] and (int(other[0]) == s or int(other[1]) == s):
			var far := int(other[1]) if int(other[0]) == s else int(other[0])
			if int(dn[far][3]) == n and n >= 0 and not cells.has(n): linked = true
	if bad or not linked: errors.append("main_cross")

## 11. The duct network: its edges, one piece a planta, no shortcut under
## SHORTCUT_MIN, an exit in every room and every lane run, the exits where
## they may be, the gaps.
func ducts_ok(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("ducts"): return
	var rooms: Array = data.rooms
	var ducts: Dictionary = data.ducts
	var dn: Array = ducts.nodes
	var plenum: Dictionary = data.plenum
	var main_cells: Array = data.air.main.cells
	var by_wing := [[], [], []]
	var stub := -1
	for i in dn.size():
		var room_id := int(dn[i][3])
		if room_id < 0 or room_id >= rooms.size():
			errors.append("duct_node_%d" % i)
			return
		if OFFICE.off_limits(rooms[room_id]): errors.append("duct_off_limits_%d" % i)
		if String(dn[i][4]) in ["trunk", "branch", "stub"]: by_wing[int(rooms[room_id].wing)].append(i)
		if String(dn[i][4]) == "stub": stub = i
	var halves: Array = []
	for edge in ducts.edges:
		var a := int(edge[0])
		var b := int(edge[1])
		if a < 0 or b < 0 or a >= dn.size() or b >= dn.size():
			errors.append("duct_edge")
			return
		var pa := v3(dn[a])
		var pb := v3(dn[b])
		var ra: Dictionary = rooms[int(dn[a][3])]
		var rb: Dictionary = rooms[int(dn[b][3])]
		if not near(pa.distance_to(pb), float(edge[2]), 0.01) or int(ra.wing) != int(rb.wing): errors.append("duct_edge_%d_%d" % [a, b])
		var kind := String(edge[3])
		if not (kind in ["trunk", "branch", "bridge", "loose"]): continue
		if a == stub or b == stub:
			halves.append(edge)
			continue
		var y := float(ra.py) + float(plenum.duct_y)
		var square: bool = near(pa.y, y) and near(pb.y, y) and (near(pa.x, pb.x) or near(pa.z, pb.z))
		var step := absi(int(ra.x) - int(rb.x)) + absi(int(ra.z) - int(rb.z))
		var door: bool = data.adjacency[int(ra.id)].has(int(rb.id))
		var right: bool = (kind == "trunk" and door and bool(ra.corridor) and bool(rb.corridor)) or (kind == "branch" and door) or kind == "bridge" or (kind == "loose" and not door)
		if not square or step != 1 or not right: errors.append("duct_link_%d_%d" % [int(ra.id), int(rb.id)])
		if kind == "loose" or (kind == "bridge" and not door):
			var length := float(edge[2])
			var walk := float(METRES.walk_within(rooms, data.adjacency, int(ra.id), length / SHORTCUT_MIN).get(int(rb.id), INF))
			if length / walk < SHORTCUT_MIN - 0.001: errors.append("duct_band_%d_%d" % [int(ra.id), int(rb.id)])
	if halves.size() == 2:
		var ends: Array = halves.map(func(edge): return int(dn[int(edge[1]) if int(edge[0]) == stub else int(edge[0])][3]))
		var length: float = float(halves[0][2]) + float(halves[1][2])
		var door: bool = data.adjacency[int(ends[0])].has(int(ends[1]))
		if not door:
			var walk := float(METRES.walk_within(rooms, data.adjacency, int(ends[0]), length / SHORTCUT_MIN).get(int(ends[1]), INF))
			if length / walk < SHORTCUT_MIN - 0.001: errors.append("duct_band_%d_%d" % [int(ends[0]), int(ends[1])])
	for planta in 3:
		if METRES.pieces(ducts, by_wing[planta], ["main", "cross", "drop"]) != 1: errors.append("duct_split_%d" % planta)
	exits_ok(data, errors)

## The exits of the ducts and the gaps.
func exits_ok(data: Dictionary, errors: Array[String]) -> void:
	var rooms: Array = data.rooms
	var ducts: Dictionary = data.ducts
	var dn: Array = ducts.nodes
	var plenum: Dictionary = data.plenum
	var main_cells: Array = data.air.main.cells
	var line := main_line(data)
	var cross_at := v3(dn[int(data.air.main.cross)])
	var stub_at := cross_at
	for n in dn:
		if String(n[4]) == "stub": stub_at = v3(n)
	var reach := float(plenum.main) / 2 + OFFICE.MAIN_CLEAR
	var has_exit := {}
	var grilles := {}
	var gaps := {}
	var gap_count := [0, 0, 0]
	for e in ducts.exits:
		var kind := String(e.kind)
		var room: Dictionary = rooms[int(e.room)]
		var id := int(room.id)
		var p := v3(e.point)
		if kind == "hatch": continue
		if OFFICE.off_limits(room) or int(FLOOR.room_at(rooms, p).get("id", -1)) != id and kind != "wall": errors.append("exit_off_limits_%d" % id)
		if kind != "gap": has_exit[id] = true
		var local := local_of(room, p)
		if kind != "wall" and (absf(local.x) > float(room.span_x) / 2 - 0.3 + 0.001 or absf(local.y) > float(room.span_z) / 2 - 0.3 + 0.001): errors.append("exit_%d" % id)
		if kind == "ceiling" or kind == "gap":
			var tile := OFFICE.tile_of(p)
			if not OFFICE.free_tiles(room).has(tile) or p.distance_to(OFFICE.tile_centre(tile, float(room.py) + float(room.height))) > 0.001: errors.append("exit_tile_%d" % id)
			if kind == "ceiling": grilles[id] = tile
			else:
				gap_count[int(room.wing)] += 1
				if gaps.has(id): errors.append("exit_tile_%d" % id)
				gaps[id] = tile
		elif kind == "duct":
			var section: Array = plenum.duct if bool(room.corridor) else plenum.branch
			if OFFICE.false_ceiling(room) or not near(p.y, float(room.py) + float(plenum.duct_y) - float(section[1]) / 2, 0.01) or Vector2(p.x, p.z).distance_to(Vector2(float(room.px), float(room.pz))) > 2.0 + 0.01: errors.append("exit_duct_%d" % id)
		elif kind == "wall":
			var wall := LAYOUT.wall_of_yaw(float(e.yaw))
			var along: float = local.y if wall == "west" or wall == "east" else local.x
			var bad: bool = wall == "" or not on_wall(room, p, wall) or room.get("glazed", []).has(wall) or not near(p.y, float(room.py) + OFFICE.WALL_GRILLE_Y, 0.01)
			for d in FLOOR.doorways(room):
				if String(d.wall) == wall and absf(float(d.along) - along) < HIDE_CLEAR - 0.001: bad = true
			if bad: errors.append("exit_wall_%d" % id)
		if int(room.wing) == 2 and kind in ["ceiling", "gap", "duct"]:
			var q := Vector2(p.x, p.z)
			var close: bool = q.distance_to(Geometry2D.get_closest_point_to_segment(q, Vector2(cross_at.x, cross_at.z), Vector2(stub_at.x, stub_at.z))) < reach - 0.001
			for i in range(1, line.size()):
				if q.distance_to(Geometry2D.get_closest_point_to_segment(q, line[i - 1], line[i])) < reach - 0.001: close = true
			if close: errors.append("main_clear_%d" % id)
		if (int(room.type) == OFFICE.ARCHIVE or int(room.type) == OFFICE.MOBILE_ARCHIVE) and kind != "wall":
			for arch in data.get("archives", []):
				for row in arch.rows:
					if p.x >= float(row[0]) and p.x <= float(row[2]) and p.z >= float(row[1]) and p.z <= float(row[3]): errors.append("exit_archive_%d" % id)
	for id in gaps:
		if grilles.has(id) and (gaps[id] == grilles[id] or OFFICE.tile_centre(gaps[id], 0.0).distance_to(OFFICE.tile_centre(grilles[id], 0.0)) < 1.2 - 0.001): errors.append("exit_tile_%d" % int(id))
	var eligible := [0, 0, 0]
	for room in rooms:
		var id := int(room.id)
		if int(room.type) == OFFICE.VOID or OFFICE.off_limits(room): continue
		if OFFICE.false_ceiling(room): eligible[int(room.wing)] += 1
		if bool(room.corridor) or has_exit.has(id): continue
		if int(room.wing) == 2 and main_cells.has(id) and not OFFICE.false_ceiling(room): continue
		errors.append("duct_room_exit_%d" % id)
	for planta in 3:
		if gap_count[planta] != roundi(float(OFFICE.GAP_SHARE[planta]) * float(eligible[planta])): errors.append("gaps_%d" % planta)
	# Every lane run between crossings has an exit.
	for room in rooms:
		if String(room.kind) != "lane" or int(room.type) == OFFICE.VOID or OFFICE.off_limits(room): continue
		var way := Vector2i(0, 1) if float(room.span_x) < float(room.span_z) else Vector2i(1, 0)
		var back := FLOOR.beside(room, -way)
		if back >= 0 and String(rooms[back].kind) == "lane" and int(rooms[back].type) != OFFICE.VOID and not OFFICE.off_limits(rooms[back]): continue
		var run: Array = []
		var at := int(room.id)
		while at >= 0 and String(rooms[at].kind) == "lane" and int(rooms[at].type) != OFFICE.VOID and not OFFICE.off_limits(rooms[at]):
			run.append(at)
			at = FLOOR.beside(rooms[at], way)
		if not run.any(func(id): return has_exit.has(int(id))): errors.append("duct_corridor_%d" % int(room.id))

## 12. The arrival lift on a closed wall of the reception with no doorway.
func arrival_ok(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("arrival_lift"): return
	var reception: Dictionary = data.rooms[int(data.start)]
	var wall := LAYOUT.wall_of(Vector2i(int(data.arrival_lift[0]), int(data.arrival_lift[1])))
	if wall == "" or reception.get("open_sides", []).has(wall) or FLOOR.doorways(reception).any(func(d): return String(d.wall) == wall): errors.append("arrival_lift")

## 13. Sockets by the rule, and corner props off lockers, fixtures, the
## hatch and the handler.
func corners_ok(data: Dictionary, errors: Array[String]) -> void:
	var air: Dictionary = data.get("air", {})
	var plant_id := int(air.get("plant", -1))
	for room in data.rooms:
		if int(room.type) == OFFICE.VOID or bool(room.corridor): continue
		var id := int(room.id)
		var sockets: Array = room.get("sockets", [])
		var sx := float(room.span_x) / 2 - OFFICE.SOCKET_INSET
		var sz := float(room.span_z) / 2 - OFFICE.SOCKET_INSET
		var lift := FLOOR.lift_wall(room)
		var most := (float(room.span_x) * absi(lift.x) + float(room.span_z) * absi(lift.y)) / 2 - FLOOR.LIFT_DEPTH - 0.9
		var ok: bool = sockets.size() == 4
		if ok:
			var corners := [Vector2(-sx, -sz), Vector2(sx, -sz), Vector2(-sx, sz), Vector2(sx, sz)]
			for k in 4:
				var at: Vector2 = corners[k]
				if lift != Vector2i.ZERO:
					var along := at.x * lift.x + at.y * lift.y
					if along > most: at -= Vector2(lift) * (along - most)
				if not near(float(sockets[k][0]), at.x) or not near(float(sockets[k][1]), at.y): ok = false
		if not ok:
			errors.append("sockets_%d" % id)
			continue
		var keep: Array = []
		for h in room.get("hides", []):
			var hw := LAYOUT.hide_wall(h)
			keep.append(LAYOUT.wall_rect(room, String(hw.wall), float(hw.along), LAYOUT.LOCKER.x / 2, LAYOUT.LOCKER.y))
		for fx in spots.get(id, []):
			keep.append(LAYOUT.wall_rect(room, String(fx.wall), float(fx.along), LAYOUT.FIXTURE_CLEAR.x / 2, LAYOUT.FIXTURE_CLEAR.y))
		if id == plant_id:
			var hl := local_of(room, v3(air.hatch.point))
			keep.append(Rect2(hl - Vector2(0.75, 0.75), Vector2(1.5, 1.5)))
			keep.append(LAYOUT.wall_rect(room, String(air.unit.wall), float(air.unit.along), OFFICE.AIR_UNIT.x / 2, OFFICE.AIR_UNIT.z))
		for prop in room.props:
			var s: Array = sockets[int(prop.slot)]
			var size := Vector2(2.3, 1.4) if int(prop.rotation) % 2 == 0 else Vector2(1.4, 2.3)
			var corner := Rect2(Vector2(float(s[0]), float(s[1])) - size / 2, size)
			if keep.any(func(r): return corner.grow(-0.001).intersects(r)):
				errors.append("props_%d" % id)
				break

## 14. Glass on both faces of a wall between a glazed type and a corridor,
## nothing on it, and the window always glazed toward a corridor.
func glazed_ok(data: Dictionary, errors: Array[String]) -> void:
	var rooms: Array = data.rooms
	for room in rooms:
		for side in room.get("glazed", []):
			var wall := String(side)
			var way := LAYOUT.way_of(wall)
			var n := FLOOR.beside(room, way)
			var ok: bool = n >= 0 and not room.get("open_sides", []).has(wall)
			if ok:
				var other: Dictionary = rooms[n]
				var opposite := LAYOUT.wall_of(-way)
				var glass: bool = palette.GLAZED_TYPES.has(int(room.type)) or palette.GLAZED_TYPES.has(int(other.type))
				var hall: bool = int(other.type) in [OFFICE.CORRIDOR, OFFICE.GALLERY] or int(room.type) in [OFFICE.CORRIDOR, OFFICE.GALLERY]
				if not other.get("glazed", []).has(opposite) or not glass or not hall: ok = false
				if FLOOR.lift_wall(room) == way or FLOOR.lift_wall(other) == -way: ok = false
				for gate in data.gates:
					if [int(gate.room), int(gate.beyond)].has(int(room.id)) and [int(gate.room), int(gate.beyond)].has(n): ok = false
				for h in room.get("hides", []):
					if String(LAYOUT.hide_wall(h).wall) == wall: ok = false
				if spots.get(int(room.id), []).any(func(s): return String(s.wall) == wall): ok = false
			if not ok:
				errors.append("glazed_%d" % int(room.id))
				break
	if not data.has("mail"): return
	var win: Dictionary = rooms[int(data.mail.window)]
	var glazed_door := false
	for d in FLOOR.doorways(win):
		if win.get("glazed", []).has(String(d.wall)) and bool(rooms[int(d.other)].corridor): glazed_door = true
	if not glazed_door: errors.append("glazed_window")

## 15. Furniture of its kinds and sizes, in the rooms that take it, clear of
## every path and apart from other groups.
func furniture_ok(data: Dictionary, errors: Array[String]) -> void:
	var kinds := {OFFICE.OPEN_OFFICE: ["desk_pair"], OFFICE.CUBICLES: ["desk", "partition"], OFFICE.BOARDROOM: ["meeting_table"], OFFICE.COPY_ROOM: ["copier"], OFFICE.MAIL: ["pigeonholes"], OFFICE.SECRETARY: ["card_index"]}
	for room in data.rooms:
		var items: Array = room.get("furniture", [])
		if items.is_empty(): continue
		var id := int(room.id)
		var allowed: Array = kinds.get(int(room.type), [])
		var zones := LAYOUT.clear_zones(data, room, int(room.type) == OFFICE.BOARDROOM)
		var ok: bool = true
		for i in items.size():
			var it: Dictionary = items[i]
			var kind := String(it.kind)
			if not allowed.has(kind) or not OFFICE.FURNITURE.has(kind):
				ok = false
				break
			var spec: Dictionary = OFFICE.FURNITURE[kind]
			var size: Vector2 = spec.size
			var height := float(it.extra.height)
			if kind == "partition":
				if float(it.size[0]) < 1.2 - 0.001 or float(it.size[0]) > 4.8 + 0.001 or not near(float(it.size[1]), size.y): ok = false
			elif not near(float(it.size[0]), size.x) or not near(float(it.size[1]), size.y): ok = false
			if not near(height, float(spec.height)) or height > OFFICE.FURNITURE_TOP + 0.001: ok = false
			var r := LAYOUT.footprint(it)
			if not LAYOUT.fits_in(LAYOUT.inner(room), r) or LAYOUT.blocked(r, zones): ok = false
			for j in items.size():
				if j != i and int(items[j].extra.group) != int(it.extra.group) and not LAYOUT.apart(r, LAYOUT.footprint(items[j]), LAYOUT.ITEM_GAP): ok = false
		if not ok: errors.append("furniture_%d" % id)
