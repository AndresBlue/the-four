extends RefCounted
## Where The Lurker can be on a floor of the offices, as surfaces worked out from
## the manifest (docs/OFICINAS.md 11.4): the ceiling of each room (a tray), the
## band over each door head and down a wall to a grille (bands), the walls of
## the rooms with no false ceiling and the fronts of the lockers (bands too),
## and the aisles of the archives, where she goes held up between the shelves
## (channels). A place on them is a State (patch, u, v, heading, hang), and the
## transform of a State is the one lurker_visual.gd wants: +Y the surface's
## normal, +Z the way she goes. Pure maths: nothing of the scene is read
## (spec_f2_movement 3).
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")

enum Kind { TRAY, BAND, CHANNEL }
## The round of every seam (lurker_test.gd BEND).
const BEND := 0.45
## No fillet may come out tighter (build() fails loudly).
const R_MIN := 0.05
## The anchor's distance from ceiling, header and soffit on a band.
const BAND_CLEAR := 0.35
## = BAND_CLEAR, so tray to band seams need no easing.
const DEFAULT_HANG := 0.35
const HANG_MIN := 0.05
## On a tray.
const HANG_MAX := 0.9
## In a channel, by default (the bench's SUSPEND 0.5 on a 1 m aisle's wall).
const CH_HANG := 0.25
## A channel's hang stays under this share of half its smaller side: no fold.
const CH_HANG_SHARE := 0.6
## Door head over the floor (= hotel_geometry.OPENING_HIGH).
const OPEN := 2.65
## Her ceiling in rooms without a false ceiling: over the door heads, under
## the main duct's floor (3.1) and the network ducts.
const EXPOSED_CEILING := 3.05
## The anchor keeps this far in from ceiling_rect() on walled sides.
const TRAY_INSET := 0.25
## A door band reaches this far into each room from the wall's centre line.
const PORTAL_REACH := 1.4
## A wall band starts this far out from the wall's face.
const WALL_REACH := 1.4
## How far she starts down before a low header: s = clamp(DIP_RUN - header).
const DIP_RUN := 0.6
## A door band's v range is +-PORTAL_WIDTH / 2 (= FLOOR.PORTAL).
const PORTAL_WIDTH := 1.3
const WALL_BAND_WIDTH := 1.2
## A wall band ends this far above its grille's centre.
const GRILLE_ABOVE := 0.55
## Only aisles narrower than this are channels.
const CHANNEL_MAX := 1.6
const SEAM_TOL := 0.02
## Default stops keep this far in plan from every lamp of the room (3.7).
const LAMP_CLEAR := 1.0
## Her face in her own frame (+Y off the surface, +Z the way she faces).
const FACE_OFFSET := Vector3(0.0, 0.45, 0.3)
## The back cue: her face at most 15 degrees over the victim's eye line.
const CUE_ANGLE := 0.2617993878
## For a cue she comes down further than she hangs to travel (the author,
## 24 October 2026: "baja ella" for a crouched victim), her face kept this
## far over the floor.
const CUE_HANG_MAX := 1.5
const CUE_FACE_LOW := 0.6
## Clamped into a small room, a cue nearer than this in plan is none.
const CUE_NEAR := 1.0
## The walls of the rooms with no false ceiling (the author, 24 October
## 2026: "por las paredes y el techo"): strips down to WALL_LOW over the
## floor, WALL_CORNER clear of the corners, WALL_DOOR clear of a doorway's
## jambs, none shorter than WALL_MIN.
const WALL_LOW := 1.0
const WALL_CORNER := 0.45
const WALL_DOOR := 0.3
const WALL_MIN := 1.0
## Over a locker she goes down its front to the slot, head down (the author,
## 24 October 2026): the slot is at a hider's eyes.
const LOCKER_SLOT := 1.6

## 2D curves with an arc-length parameter.
class Profile extends RefCounted:
	var closed := false
	## normal = side * Vector2(-t.y, t.x)
	var side := 1.0
	## line: [0, length, start, dir]; arc: [1, length, centre, radius, start_angle, sweep]
	var pieces: Array = []
	## Cumulative u at each piece's start.
	var starts := PackedFloat64Array()
	var length := 0.0
	var min_radius := INF

	func add_line(from: Vector2, to: Vector2) -> void:
		var piece := to - from
		var size := piece.length()
		if size < 1e-9: return
		pieces.append([0, size, from, piece / size])
		starts.append(length)
		length += size

	func add_arc(centre: Vector2, radius: float, start_angle: float, sweep: float) -> void:
		var size := absf(sweep) * radius
		if size < 1e-9: return
		pieces.append([1, size, centre, radius, start_angle, sweep])
		starts.append(length)
		length += size
		min_radius = minf(min_radius, radius)

	## [point, unit tangent]; closed: u wraps; open: clamped to [0, length].
	func at(u: float) -> Array:
		if pieces.is_empty(): return [Vector2.ZERO, Vector2.RIGHT]
		var s: float = fposmod(u, length) if closed else clampf(u, 0.0, length)
		var low := 0
		var high := pieces.size() - 1
		while low < high:
			var middle := (low + high + 1) / 2
			if starts[middle] <= s: low = middle
			else: high = middle - 1
		var piece: Array = pieces[low]
		var local := clampf(s - starts[low], 0.0, float(piece[1]))
		if int(piece[0]) == 0:
			var start: Vector2 = piece[2]
			var dir: Vector2 = piece[3]
			return [start + dir * local, dir]
		var centre: Vector2 = piece[2]
		var radius := float(piece[3])
		var sweep := float(piece[5])
		var angle := float(piece[4]) + sweep * local / float(piece[1])
		return [centre + Vector2(cos(angle), sin(angle)) * radius, Vector2(-sin(angle), cos(angle)) * signf(sweep)]

	func normal_at(u: float) -> Vector2:
		var t: Vector2 = at(u)[1]
		return Vector2(-t.y, t.x) * side

	## Points every `step` along it, its last point included (gizmos, tests).
	func sample(step: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		var count := maxi(1, ceili(length / maxf(step, 1e-4)))
		for i in count + 1: out.append(at(length * float(i) / float(count))[0])
		return out

	## An open polyline with every inner corner rounded to `radius`, or less
	## where the segments are too short for it (a segment that starts or ends
	## at an endpoint may give all of itself, a middle one half to each end).
	static func rounded(points: PackedVector2Array, radius: float, side: float) -> Profile:
		var p := Profile.new()
		p.side = side
		var n := points.size()
		if n < 2: return p
		var from := points[0]
		for i in range(1, n - 1):
			var d0 := (points[i] - points[i - 1]).normalized()
			var d1 := (points[i + 1] - points[i]).normalized()
			var theta := d0.angle_to(d1)
			if absf(theta) < 1e-6: continue
			var len_prev := points[i].distance_to(points[i - 1])
			var len_next := points[i + 1].distance_to(points[i])
			var tau_max := minf(len_prev if i == 1 else len_prev / 2.0, len_next if i == n - 2 else len_next / 2.0)
			var half_tan := tan(absf(theta) / 2.0)
			var r := minf(radius, tau_max / half_tan)
			var tau := r * half_tan
			var t_in := points[i] - d0 * tau
			var t_out := points[i] + d1 * tau
			var centre := t_in + Vector2(-d0.y, d0.x) * r * signf(theta)
			p.add_line(from, t_in)
			p.add_arc(centre, r, (t_in - centre).angle(), theta)
			from = t_out
		p.add_line(from, points[n - 1])
		return p

	## The bench's outline (lurker_test.gd outline()): closed, counter-clockwise
	## in (across, up), x in [-w/2, w/2], y in [0, h], u = 0 at the middle of
	## the floor, then the floor towards +x, the right wall up, the ceiling
	## towards -x, the left wall down; normals inward.
	static func section(width: float, height: float, bend: float) -> Profile:
		var p := Profile.new()
		p.closed = true
		p.side = 1.0
		var r := minf(bend, minf(width, height) / 2.0 - 0.02)
		var w := width / 2.0
		p.add_line(Vector2(0, 0), Vector2(w - r, 0))
		p.add_arc(Vector2(w - r, r), r, -PI / 2.0, PI / 2.0)
		p.add_line(Vector2(w, r), Vector2(w, height - r))
		p.add_arc(Vector2(w - r, height - r), r, 0.0, PI / 2.0)
		p.add_line(Vector2(w - r, height), Vector2(-w + r, height))
		p.add_arc(Vector2(-w + r, height - r), r, PI / 2.0, PI / 2.0)
		p.add_line(Vector2(-w, height - r), Vector2(-w, r))
		p.add_arc(Vector2(-w + r, r), r, PI, PI / 2.0)
		p.add_line(Vector2(-w + r, 0), Vector2(0, 0))
		return p

## A place on the shell.
class State extends RefCounted:
	var patch := -1
	var u := 0.0
	var v := 0.0
	## Radians in the patch's (Tu, Tv) plane: H = Tu * cos(heading) + Tv * sin(heading).
	var heading := 0.0
	var hang := DEFAULT_HANG
	## Come down for a cue: on a tray her hang may reach CUE_HANG_MAX.
	var lowered := false

	func copy() -> State:
		var s := State.new()
		s.patch = patch
		s.u = u
		s.v = v
		s.heading = heading
		s.hang = hang
		s.lowered = lowered
		return s

var manifest: Dictionary = {}
var rooms: Array = []
## Every patch; each record has `kind` and `wing` (3.3).
var patches: Array[Dictionary] = []
## Room -> its tray.
var tray_of := {}
## Room -> its door bands and wall bands.
var bands_of := {}
## Vector2i(min, max) -> the door band.
var band_of_pair := {}
## Duct exit index -> its wall band.
var wall_band_of_exit := {}
## Room -> its channels.
var channels_of := {}
## Room -> the bands down its walls where it has no false ceiling.
var walls_of := {}
## Room -> the bands down the fronts of its lockers.
var lockers_of := {}
## Room -> its lamps in plan (3.7).
var lamps_of := {}
## wall_band()'s cache.
var made := {}
## The worst fillet of the build (R_MIN is the floor).
var min_radius := INF

## Null unless the manifest is a floor of the offices.
static func build(source: Dictionary) -> RefCounted:
	if int(source.get("floor", 1)) != 2: return null
	var shell = new()
	shell.fill(source)
	return shell

func fill(source: Dictionary) -> void:
	manifest = source
	rooms = source.get("rooms", [])
	var off: Array = OFFICE.off_limits_rooms(source)
	for room in rooms:
		if FLOOR.is_void(room) or off.has(int(room.id)): continue
		add_tray(room)
	for id in tray_of: open_sides_of(int(id))
	var merged := {}
	for pair in source.get("merged", []): merged[Vector2i(mini(int(pair[0]), int(pair[1])), maxi(int(pair[0]), int(pair[1])))] = true
	for edge in source.get("edges", []):
		var a := int(edge[0])
		var b := int(edge[1])
		var key := Vector2i(mini(a, b), maxi(a, b))
		if merged.has(key) or band_of_pair.has(key) or not tray_of.has(a) or not tray_of.has(b): continue
		add_door_band(a, b)
	var exits: Array = source.get("ducts", {}).get("exits", [])
	for i in exits.size():
		var e: Dictionary = exits[i]
		if String(e.get("kind", "")) != "wall" or not tray_of.has(int(e.room)): continue
		var p: Array = e.point
		var yaw := float(e.get("yaw", 0.0))
		var across := -(Basis(Vector3.UP, yaw) * Vector3.BACK)
		var room: Dictionary = rooms[int(e.room)]
		var origin := Vector3(float(p[0]), float(room.get("py", 0.0)), float(p[2]))
		var band := add_wall_band(int(e.room), origin, across, WALL_BAND_WIDTH, float(p[1]) - float(room.get("py", 0.0)) + GRILLE_ABOVE)
		patches[band]["exit"] = i
		wall_band_of_exit[i] = band
	for id in tray_of:
		var room: Dictionary = rooms[int(id)]
		if not OFFICE.false_ceiling(room): add_wall_strips(room)
		add_locker_bands(room)
	for unit in source.get("archives", []):
		if bool(unit.get("mobile", false)): continue
		for aisle in unit.get("aisles", []): add_channel(unit, aisle)
	for id in tray_of: lamps_of[int(id)] = lamps_in(rooms[int(id)])
	for patch in patches:
		if patch.has("profile"): min_radius = minf(min_radius, (patch.profile as Profile).min_radius)
	if min_radius < R_MIN: push_error("lurker_shell: a fillet of %0.3f m, under R_MIN" % min_radius)

# --- Trays --------------------------------------------------------------------

func add_tray(room: Dictionary) -> void:
	var py := float(room.get("py", 0.0))
	var y: float = py + OFFICE.height_of(room) if OFFICE.false_ceiling(room) else py + EXPOSED_CEILING
	var rect: Rect2 = OFFICE.ceiling_rect(room)
	var open: Array = room.get("open_sides", [])
	var low := rect.position
	var high := rect.end
	if not open.has("west"): low.x += TRAY_INSET
	if not open.has("east"): high.x -= TRAY_INSET
	if not open.has("north"): low.y += TRAY_INSET
	if not open.has("south"): high.y -= TRAY_INSET
	var half := FLOOR.size_of(room) * 0.5
	var centre := Vector2(float(room.px), float(room.pz))
	tray_of[int(room.id)] = patches.size()
	patches.append({"kind": Kind.TRAY, "room": int(room.id), "wing": int(room.get("wing", 0)), "y": y, "rect": Rect2(low, high - low), "cell": Rect2(centre - half, half * 2.0), "open": {}})

## The neighbours across a room's open sides whose tray is at the same height.
func open_sides_of(id: int) -> void:
	var room: Dictionary = rooms[id]
	var tray: Dictionary = patches[int(tray_of[id])]
	var ways := {"west": Vector2i(-1, 0), "east": Vector2i(1, 0), "north": Vector2i(0, -1), "south": Vector2i(0, 1)}
	for side in room.get("open_sides", []):
		if not ways.has(String(side)): continue
		var other := FLOOR.beside(room, ways[String(side)])
		if other < 0 or not tray_of.has(other): continue
		if absf(float(patches[int(tray_of[other])].y) - float(tray.y)) > 0.001: continue
		tray.open[String(side)] = other

# --- Bands --------------------------------------------------------------------

func tray_height(room: int) -> float:
	return float(patches[int(tray_of[room])].y) - float(rooms[room].get("py", 0.0))

## How far along `out` from `origin` (in plan) still lands in the rect, from
## `reach` down to `least` in 5 cm steps (risk 2 of the spec).
func fit_reach(rect: Rect2, origin: Vector3, out: Vector3, reach: float, least: float) -> float:
	var r := reach
	while r > least:
		var at := origin + out * r
		if rect.grow(1e-6).has_point(Vector2(at.x, at.z)): return r
		r -= 0.05
	return least

func add_door_band(a: int, b: int) -> void:
	var room_a: Dictionary = rooms[a]
	var room_b: Dictionary = rooms[b]
	var across := Vector3(signf(float(room_b.x) - float(room_a.x)), 0, 0) if int(room_a.x) != int(room_b.x) else Vector3(0, 0, signf(float(room_b.z) - float(room_a.z)))
	var origin := FLOOR.portal_between(room_a, room_b)
	var t := 2.0 * OFFICE.WALL_HALF
	var c := BAND_CLEAR
	var h_a := tray_height(a)
	var h_b := tray_height(b)
	var s_a := clampf(DIP_RUN - (h_a - OPEN), 0.0, DIP_RUN)
	var s_b := clampf(DIP_RUN - (h_b - OPEN), 0.0, DIP_RUN)
	var reach_a := fit_reach(patches[int(tray_of[a])].rect, origin, -across, t / 2.0 + PORTAL_REACH, t / 2.0 + c + s_a + 0.2)
	var reach_b := fit_reach(patches[int(tray_of[b])].rect, origin, across, t / 2.0 + PORTAL_REACH, t / 2.0 + c + s_b + 0.2)
	var points := PackedVector2Array([
		Vector2(-reach_a, h_a - c),
		Vector2(-(t / 2.0 + c + s_a), h_a - c),
		Vector2(-(t / 2.0 + c), OPEN - c),
		Vector2(t / 2.0 + c, OPEN - c),
		Vector2(t / 2.0 + c + s_b, h_b - c),
		Vector2(reach_b, h_b - c),
	])
	var key := Vector2i(mini(a, b), maxi(a, b))
	var band := add_band([a, b], origin, across, PORTAL_WIDTH, Profile.rounded(points, BEND, -1.0), [int(tray_of[a]), int(tray_of[b])])
	patches[band]["pair"] = key
	band_of_pair[key] = band

## A band from a room's ceiling down a face to `bottom` over the floor:
## `origin` on that face at floor level, `across` towards it.
func add_wall_band(room: int, origin: Vector3, across: Vector3, width: float, bottom: float) -> int:
	var h := tray_height(room)
	var c := BAND_CLEAR
	var reach := fit_reach(patches[int(tray_of[room])].rect, origin, -across, WALL_REACH, c + 0.2)
	var points := PackedVector2Array([Vector2(-reach, h - c), Vector2(-c, h - c), Vector2(-c, minf(bottom, h - c - BEND))])
	return add_band([room, -1], origin, across, width, Profile.rounded(points, BEND, -1.0), [int(tray_of[room]), -1])

func add_band(pair_rooms: Array, origin: Vector3, across: Vector3, width: float, profile: Profile, ends: Array) -> int:
	var index := patches.size()
	patches.append({"kind": Kind.BAND, "wing": int(rooms[int(pair_rooms[0])].get("wing", 0)), "rooms": pair_rooms, "pair": Vector2i(-1, -1), "exit": -1,
		"origin": origin, "across": across, "axis": Vector3(-across.z, 0, across.x), "width": width, "profile": profile, "ends": ends})
	for r in pair_rooms:
		if int(r) < 0: continue
		if not bands_of.has(int(r)): bands_of[int(r)] = []
		bands_of[int(r)].append(index)
	return index

## Into the room from a wall, and the world point on its inner face at
## `along` (as FLOOR.doorways() gives it) at floor level.
func wall_frame(room: Dictionary, side: String, along: float, depth := 0.0) -> Array:
	var inward2 := LAYOUT.inward(side)
	var inward := Vector3(inward2.x, 0, inward2.y)
	var face := LAYOUT.face(room, side) + inward2.x * depth + inward2.y * depth
	var local := Vector2(face, along) if side == "west" or side == "east" else Vector2(along, face)
	var centre := FLOOR.position_of(room)
	return [Vector3(centre.x + local.x, centre.y, centre.z + local.y), -inward]

## A wall band made on demand (2b: stalking down a wall), cached.
func wall_band(room: int, side: String, along: float, bottom: float) -> int:
	if not tray_of.has(room): return -1
	var key := "%d:%s:%0.2f:%0.2f" % [room, side, along, bottom]
	if made.has(key): return int(made[key])
	var frame := wall_frame(rooms[room], side, along)
	var band := add_wall_band(room, frame[0], frame[1], WALL_BAND_WIDTH, bottom)
	made[key] = band
	return band

## The walls of a room with no false ceiling, in strips between its corners,
## doorways, lockers and what stands against them.
func add_wall_strips(room: Dictionary) -> void:
	var open: Array = room.get("open_sides", [])
	var span := FLOOR.size_of(room)
	var blocked := {"west": [], "east": [], "north": [], "south": []}
	for way in FLOOR.doorways(room): blocked[String(way.wall)].append([float(way.along) - FLOOR.PORTAL / 2.0 - WALL_DOOR, float(way.along) + FLOOR.PORTAL / 2.0 + WALL_DOOR])
	for h in room.get("hides", []):
		var hw := LAYOUT.hide_wall(h)
		blocked[String(hw.wall)].append([float(hw.along) - LAYOUT.LOCKER.x / 2.0 - 0.1, float(hw.along) + LAYOUT.LOCKER.x / 2.0 + 0.1])
	for item in room.get("furniture", []):
		var foot := LAYOUT.footprint(item)
		for side in blocked:
			var face := LAYOUT.face(room, String(side))
			var gap: float
			match String(side):
				"west": gap = foot.position.x - face
				"east": gap = face - foot.end.x
				"north": gap = foot.position.y - face
				_: gap = face - foot.end.y
			if gap > BAND_CLEAR + 0.3: continue
			var vertical: bool = side == "west" or side == "east"
			var lo: float = foot.position.y if vertical else foot.position.x
			var hi: float = foot.end.y if vertical else foot.end.x
			blocked[side].append([lo - 0.1, hi + 0.1])
	for side in ["west", "east", "north", "south"]:
		if open.has(side): continue
		var half: float = span.y / 2.0 if side == "west" or side == "east" else span.x / 2.0
		var pieces: Array = [[-half + OFFICE.WALL_HALF + WALL_CORNER, half - OFFICE.WALL_HALF - WALL_CORNER]]
		for cut in blocked[side]:
			var next: Array = []
			for piece in pieces:
				if float(cut[1]) <= float(piece[0]) or float(cut[0]) >= float(piece[1]):
					next.append(piece)
					continue
				if float(cut[0]) > float(piece[0]): next.append([piece[0], cut[0]])
				if float(cut[1]) < float(piece[1]): next.append([cut[1], piece[1]])
			pieces = next
		for piece in pieces:
			var width := float(piece[1]) - float(piece[0])
			if width < WALL_MIN: continue
			var frame := wall_frame(room, side, (float(piece[0]) + float(piece[1])) / 2.0)
			var band := add_wall_band(int(room.id), frame[0], frame[1], width, WALL_LOW)
			patches[band]["wall"] = side
			if not walls_of.has(int(room.id)): walls_of[int(room.id)] = []
			walls_of[int(room.id)].append(band)

## Over each locker, a band from the ceiling down its front to the slot.
func add_locker_bands(room: Dictionary) -> void:
	var hides: Array = room.get("hides", [])
	for i in hides.size():
		var hw := LAYOUT.hide_wall(hides[i])
		var frame := wall_frame(room, String(hw.wall), float(hw.along), LAYOUT.LOCKER.y)
		var band := add_wall_band(int(room.id), frame[0], frame[1], LAYOUT.LOCKER.x * 0.5, LOCKER_SLOT + FACE_OFFSET.z)
		patches[band]["hide"] = i
		if not lockers_of.has(int(room.id)): lockers_of[int(room.id)] = []
		lockers_of[int(room.id)].append(band)

# --- Channels -----------------------------------------------------------------

func add_channel(unit: Dictionary, aisle: Array) -> void:
	var x0 := float(aisle[0])
	var z0 := float(aisle[1])
	var x1 := float(aisle[2])
	var z1 := float(aisle[3])
	var along_x := (x1 - x0) >= (z1 - z0)
	var width: float = (z1 - z0) if along_x else (x1 - x0)
	var length: float = (x1 - x0) if along_x else (z1 - z0)
	if width >= CHANNEL_MAX or width <= 0.0: return
	var py := float(rooms[int(unit.rooms[0])].get("py", 0.0))
	var centre := Vector2((x0 + x1) / 2.0, (z0 + z1) / 2.0)
	var found := FLOOR.room_at(rooms, Vector3(centre.x, py + 1.0, centre.y))
	var room := int(found.get("id", -1))
	if not tray_of.has(room): return
	# The mouth: the short side nearer the spine's centre line.
	var spine: Array = unit.get("spine", [x0, z0, x1, z1])
	var spine_along_x := (float(spine[2]) - float(spine[0])) >= (float(spine[3]) - float(spine[1]))
	var line := (float(spine[1]) + float(spine[3])) / 2.0 if spine_along_x else (float(spine[0]) + float(spine[2])) / 2.0
	var end_a := Vector2(x0, centre.y) if along_x else Vector2(centre.x, z0)
	var end_b := Vector2(x1, centre.y) if along_x else Vector2(centre.x, z1)
	var off_a: float = absf((end_a.y if spine_along_x else end_a.x) - line)
	var off_b: float = absf((end_b.y if spine_along_x else end_b.x) - line)
	var mouth := end_a if off_a <= off_b else end_b
	var far := end_b if off_a <= off_b else end_a
	var axis := Vector3(far.x - mouth.x, 0, far.y - mouth.y).normalized()
	var height := tray_height(room)
	# An aisle may run on to the wall: she stops where her ceilings stop.
	var ceilings: Array = []
	for r in unit.rooms:
		if tray_of.has(int(r)) and absf(float(patches[int(tray_of[int(r)])].y) - float(patches[int(tray_of[room])].y)) <= 0.001: ceilings.append(patches[int(tray_of[int(r)])].rect)
	var dir := Vector2(axis.x, axis.z)
	while length > 0.0 and not ceilings.any(func(rect: Rect2) -> bool: return rect.grow(1e-6).has_point(mouth + dir * length)): length -= 0.01
	if length <= 0.0: return
	var index := patches.size()
	patches.append({"kind": Kind.CHANNEL, "room": room, "wing": int(rooms[room].get("wing", 0)), "unit": unit.rooms.duplicate(),
		"origin": Vector3(mouth.x, py, mouth.y), "axis": axis, "across": Vector3.UP.cross(axis), "length": length, "width": width, "height": height,
		"profile": Profile.section(width, height, BEND), "tray": int(tray_of[room])})
	if not channels_of.has(room): channels_of[room] = []
	channels_of[room].append(index)

func channel_radius(c: Dictionary) -> float:
	return minf(BEND, minf(float(c.width), float(c.height)) / 2.0 - 0.02)

# --- Lamps (3.7) -------------------------------------------------------------

## A room's lamps in plan, as office_geometry.gd hangs them: the tube's omni
## at the middle, a batten over each aisle of an archive; the emergency unit
## is not in her way.
func lamps_in(room: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var centre := Vector2(float(room.px), float(room.pz))
	match OFFICE.lamp_of(room):
		"emergency":
			return out
		"batten":
			var cell := Rect2(centre - FLOOR.size_of(room) * 0.5, FLOOR.size_of(room))
			for unit in manifest.get("archives", []):
				if not unit.rooms.has(int(room.id)): continue
				for a in unit.aisles:
					var piece := Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1])).intersection(cell)
					if piece.size.x < 0.3 or piece.size.y < 0.3: continue
					out.append(piece.get_center())
	if out.is_empty(): out.append(centre)
	return out

## The point of a room's tray nearest (x, z) at least LAMP_CLEAR in plan from
## every lamp of the room; with none, the tray point farthest from its nearest
## lamp (ties: lower x, then lower z).
func clear_point(room: int, x: float, z: float) -> Vector2:
	if not tray_of.has(room): return Vector2(x, z)
	var rect: Rect2 = patches[int(tray_of[room])].rect
	var lamps: PackedVector2Array = lamps_of.get(room, PackedVector2Array())
	var q := Vector2(x, z)
	var p0 := Vector2(clampf(x, rect.position.x, rect.end.x), clampf(z, rect.position.y, rect.end.y))
	if clear_of(p0, lamps, rect): return p0
	# The nearest point of the rect less the discs is the projection on one
	# piece of its boundary or one of its corners.
	var found: Array = []
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		found.append(a)
		found.append(Geometry2D.get_closest_point_to_segment(q, a, b))
		for lamp in lamps:
			for hit in circle_segment(lamp, LAMP_CLEAR, a, b): found.append(hit)
	for i in lamps.size():
		var away := q - lamps[i]
		found.append(lamps[i] + (away.normalized() if away.length() > 1e-9 else Vector2.RIGHT) * LAMP_CLEAR)
		for j in range(i + 1, lamps.size()):
			for hit in circle_circle(lamps[i], lamps[j], LAMP_CLEAR): found.append(hit)
	var best := Vector2.INF
	var best_d := INF
	for p: Vector2 in found:
		if not clear_of(p, lamps, rect): continue
		var d := p.distance_squared_to(q)
		if d < best_d - 1e-9 or (absf(d - best_d) <= 1e-9 and (p.x < best.x or (p.x == best.x and p.y < best.y))):
			best_d = d
			best = p
	if best_d < INF: return best
	# Nowhere clear: the farthest from its nearest lamp, on a grid.
	var step := maxf(0.05, maxf(rect.size.x, rect.size.y) / 60.0)
	var far := p0
	var far_d := -1.0
	var nx := int(ceil(rect.size.x / step))
	var nz := int(ceil(rect.size.y / step))
	for i in nx + 1:
		for j in nz + 1:
			var p := Vector2(minf(rect.position.x + step * i, rect.end.x), minf(rect.position.y + step * j, rect.end.y))
			var d := INF
			for lamp in lamps: d = minf(d, p.distance_to(lamp))
			if d > far_d + 1e-9:
				far_d = d
				far = p
	return far

func clear_of(p: Vector2, lamps: PackedVector2Array, rect: Rect2) -> bool:
	if not rect.grow(1e-6).has_point(p): return false
	for lamp in lamps:
		if p.distance_to(lamp) < LAMP_CLEAR - 1e-6: return false
	return true

static func circle_segment(centre: Vector2, radius: float, a: Vector2, b: Vector2) -> Array:
	var d := b - a
	var f := a - centre
	var qa := d.dot(d)
	var qb := 2.0 * f.dot(d)
	var qc := f.dot(f) - radius * radius
	var disc := qb * qb - 4.0 * qa * qc
	if qa < 1e-12 or disc < 0.0: return []
	var root := sqrt(disc)
	var out: Array = []
	for t: float in [(-qb - root) / (2.0 * qa), (-qb + root) / (2.0 * qa)]:
		if t >= 0.0 and t <= 1.0: out.append(a + d * t)
	return out

static func circle_circle(a: Vector2, b: Vector2, radius: float) -> Array:
	var d := a.distance_to(b)
	if d < 1e-9 or d > 2.0 * radius: return []
	var middle := (a + b) / 2.0
	var h := sqrt(maxf(radius * radius - d * d / 4.0, 0.0))
	var side := (b - a).orthogonal().normalized() * h
	return [middle + side, middle - side]

# --- State and its transform ---------------------------------------------------

## [N, Tu, Tv], unit.
func frame_of(s: State) -> Array:
	var patch: Dictionary = patches[s.patch]
	if int(patch.kind) == Kind.TRAY: return [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK]
	var profile: Profile = patch.profile
	var t: Vector2 = profile.at(s.u)[1]
	var n := profile.normal_at(s.u)
	var across: Vector3 = patch.across
	return [across * n.x + Vector3.UP * n.y, across * t.x + Vector3.UP * t.y, patch.axis]

func anchor_of(s: State) -> Vector3:
	var patch: Dictionary = patches[s.patch]
	match int(patch.kind):
		Kind.TRAY:
			return Vector3(s.u, float(patch.y) - s.hang, s.v)
		Kind.BAND:
			var p: Vector2 = (patch.profile as Profile).at(s.u)[0]
			return (patch.origin as Vector3) + (patch.axis as Vector3) * s.v + (patch.across as Vector3) * p.x + Vector3.UP * p.y
	var p: Vector2 = (patch.profile as Profile).at(s.u)[0]
	var base: Vector3 = (patch.origin as Vector3) + (patch.axis as Vector3) * s.v
	var o: Vector3 = base + (patch.across as Vector3) * p.x + Vector3.UP * p.y
	var c := base + Vector3.UP * float(patch.height) / 2.0
	var out := o - c
	var size := out.length()
	if size < 1e-9: return c
	return c + out * maxf(0.0, 1.0 - s.hang / size)

func heading_vector(s: State) -> Vector3:
	var f := frame_of(s)
	return ((f[1] as Vector3) * cos(s.heading) + (f[2] as Vector3) * sin(s.heading)).normalized()

## Basis(Y.cross(Z), Y = N, Z = H), origin the anchor.
func transform_of(s: State) -> Transform3D:
	var n: Vector3 = frame_of(s)[0]
	var h := heading_vector(s)
	return Transform3D(Basis(n.cross(h), n, h), anchor_of(s))

## The heading towards a world direction projected on the patch; the old one
## kept when the projection is nearly nothing.
func set_heading(s: State, world: Vector3) -> void:
	var f := frame_of(s)
	var a := world.dot(f[1])
	var b := world.dot(f[2])
	if Vector2(a, b).length() < 1e-4: return
	s.heading = atan2(b, a)

func max_hang(s: State) -> float:
	var patch: Dictionary = patches[s.patch]
	match int(patch.kind):
		Kind.TRAY: return CUE_HANG_MAX if s.lowered else HANG_MAX
		Kind.BAND: return BAND_CLEAR
	return CH_HANG_SHARE * minf(float(patch.width), float(patch.height)) / 2.0

func clamp_state(s: State) -> void:
	var patch: Dictionary = patches[s.patch]
	match int(patch.kind):
		Kind.TRAY:
			var rect: Rect2 = patch.rect
			s.u = clampf(s.u, rect.position.x, rect.end.x)
			s.v = clampf(s.v, rect.position.y, rect.end.y)
			s.hang = clampf(s.hang, HANG_MIN, max_hang(s))
		Kind.BAND:
			s.u = clampf(s.u, 0.0, (patch.profile as Profile).length)
			s.v = clampf(s.v, -float(patch.width) / 2.0, float(patch.width) / 2.0)
			s.hang = BAND_CLEAR
		Kind.CHANNEL:
			s.u = fposmod(s.u, (patch.profile as Profile).length)
			s.v = clampf(s.v, 0.0, float(patch.length))
			s.hang = clampf(s.hang, 0.0, max_hang(s))

## Moves along the heading; the metres actually moved. On a tray, an open side
## carries her on to the next tray at the same point; a walled edge stops her.
func advance(s: State, metres: float) -> float:
	var patch: Dictionary = patches[s.patch]
	match int(patch.kind):
		Kind.TRAY:
			return advance_tray(s, metres)
		Kind.BAND:
			var length: float = (patch.profile as Profile).length
			var half := float(patch.width) / 2.0
			var u := clampf(s.u + cos(s.heading) * metres, 0.0, length)
			var v := clampf(s.v + sin(s.heading) * metres, -half, half)
			var moved := Vector2(u - s.u, v - s.v).length()
			s.u = u
			s.v = v
			return moved
	var du := cos(s.heading) * metres
	var v := clampf(s.v + sin(s.heading) * metres, 0.0, float(patch.length))
	var moved := Vector2(du, v - s.v).length()
	s.u = fposmod(s.u + du, (patch.profile as Profile).length)
	s.v = v
	return moved

func advance_tray(s: State, metres: float) -> float:
	var moved := 0.0
	var left := metres
	for hop in 8:
		var patch: Dictionary = patches[s.patch]
		var rect: Rect2 = patch.rect
		var dir := Vector2(cos(s.heading), sin(s.heading))
		var tx := INF
		var tz := INF
		if dir.x > 1e-12: tx = (rect.end.x - s.u) / dir.x
		elif dir.x < -1e-12: tx = (rect.position.x - s.u) / dir.x
		if dir.y > 1e-12: tz = (rect.end.y - s.v) / dir.y
		elif dir.y < -1e-12: tz = (rect.position.y - s.v) / dir.y
		var t := maxf(minf(tx, tz), 0.0)
		if t >= left:
			s.u += dir.x * left
			s.v += dir.y * left
			return moved + left
		var side := ""
		if tx <= tz: side = "east" if dir.x > 0.0 else "west"
		else: side = "south" if dir.y > 0.0 else "north"
		var open: Dictionary = patch.open
		if not open.has(side):
			var start := Vector2(s.u, s.v)
			var target := start + dir * left
			s.u = clampf(target.x, rect.position.x, rect.end.x)
			s.v = clampf(target.y, rect.position.y, rect.end.y)
			return moved + start.distance_to(Vector2(s.u, s.v))
		s.u += dir.x * t
		s.v += dir.y * t
		moved += t
		left -= t
		var next: Dictionary = patches[int(tray_of[int(open[side])])]
		var next_rect: Rect2 = next.rect
		s.patch = int(tray_of[int(open[side])])
		s.u = clampf(s.u, next_rect.position.x, next_rect.end.x)
		s.v = clampf(s.v, next_rect.position.y, next_rect.end.y)
	return moved

## A tray State, clamped into the rect; null without a tray.
func tray_state(room: int, x: float, z: float, hang := DEFAULT_HANG) -> State:
	if not tray_of.has(room): return null
	var s := State.new()
	s.patch = int(tray_of[room])
	s.u = x
	s.v = z
	s.hang = hang
	clamp_state(s)
	return s

## The tray of the room a point is in; outside any tray, the nearest tray
## point of that planta (plan distance; ties: lower room id).
func state_at(point: Vector3, hang := DEFAULT_HANG) -> State:
	var room := int(FLOOR.room_at(rooms, point).get("id", -1))
	if tray_of.has(room): return tray_state(room, point.x, point.z, hang)
	var planta := FLOOR.planta_of(point.y)
	var best := -1
	var best_d := INF
	var ids: Array = tray_of.keys()
	ids.sort()
	for id in ids:
		var tray: Dictionary = patches[int(tray_of[id])]
		if FLOOR.planta_of(float(rooms[int(id)].get("py", 0.0)) + 1.0) != planta: continue
		var rect: Rect2 = tray.rect
		var p := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.z, rect.position.y, rect.end.y))
		var d := p.distance_squared_to(Vector2(point.x, point.z))
		if d < best_d - 1e-9:
			best_d = d
			best = int(id)
	return tray_state(best, point.x, point.z, hang) if best >= 0 else null

## Onto a band from one of its rooms: u = 0 from rooms[0] or its length from
## rooms[1], heading into the band.
func band_start(band: int, from_room: int, v := 0.0) -> State:
	var patch: Dictionary = patches[band]
	var s := State.new()
	s.patch = band
	s.hang = BAND_CLEAR
	s.v = v
	if from_room == int(patch.rooms[0]):
		s.u = 0.0
		s.heading = 0.0
	elif from_room == int(patch.rooms[1]):
		s.u = (patch.profile as Profile).length
		s.heading = PI
	else: return null
	clamp_state(s)
	return s

## The tray State at a band's end in `to_room`, heading kept.
func band_end_state(band: int, to_room: int, v := 0.0) -> State:
	var patch: Dictionary = patches[band]
	var end := State.new()
	end.patch = band
	end.v = v
	end.hang = BAND_CLEAR
	if to_room == int(patch.rooms[0]):
		end.u = 0.0
		end.heading = PI
	elif to_room == int(patch.rooms[1]):
		end.u = (patch.profile as Profile).length
		end.heading = 0.0
	else: return null
	clamp_state(end)
	return switch_to(end, int(tray_of[to_room]))

## At the mouth of a channel: on the middle of its ceiling, or, with a batten
## too near it, up the wall away from the batten (the bench's wall stance).
func channel_mouth(channel: int) -> State:
	var patch: Dictionary = patches[channel]
	var s := State.new()
	s.patch = channel
	s.v = 0.0
	s.heading = PI / 2.0
	s.u = (patch.profile as Profile).length / 2.0
	var origin: Vector3 = patch.origin
	var across: Vector3 = patch.across
	for lamp in lamps_of.get(int(patch.room), PackedVector2Array()):
		if Vector2(origin.x, origin.z).distance_to(lamp) >= LAMP_CLEAR: continue
		var side := -1.0 if (Vector3(lamp.x, origin.y, lamp.y) - origin).dot(across) > 0.0 else 1.0
		s.u = channel_u_on_wall(channel, side, 1.8)
		break
	s.hang = minf(BAND_CLEAR, max_hang(s))
	return s

## lurker_test.gd on_wall() on this channel's section: side -1 left, 1 right.
func channel_u_on_wall(channel: int, side: float, height: float) -> float:
	var patch: Dictionary = patches[channel]
	var r := channel_radius(patch)
	var along := (float(patch.width) - 2.0 * r) * 0.5 + PI * 0.5 * r + clampf(height, r, float(patch.height) - r) - r
	return along if side > 0.0 else (patch.profile as Profile).length - along

## The same place on another patch, or null when s is not on a seam to it.
func switch_to(s: State, patch: int) -> State:
	if patch < 0 or patch >= patches.size() or patch == s.patch: return null
	var here: Dictionary = patches[s.patch]
	var there: Dictionary = patches[patch]
	var anchor := anchor_of(s)
	var world := heading_vector(s)
	var from := int(here.kind)
	var to := int(there.kind)
	var out: State = null
	if from == Kind.TRAY and to == Kind.BAND: out = tray_to_band(s, anchor, patch)
	elif from == Kind.BAND and to == Kind.TRAY and here.ends.has(patch): out = onto_tray(anchor, frame_of(s)[0], patch, BAND_CLEAR)
	elif from == Kind.TRAY and to == Kind.CHANNEL: out = tray_to_channel(s, anchor, patch)
	elif from == Kind.CHANNEL and to == Kind.TRAY: out = channel_to_tray(s, anchor, patch)
	if out == null: return null
	set_heading(out, world)
	return out

func tray_to_band(s: State, anchor: Vector3, band: int) -> State:
	if absf(s.hang - BAND_CLEAR) >= SEAM_TOL: return null
	var patch: Dictionary = patches[band]
	var room := int(patches[s.patch].room)
	var profile: Profile = patch.profile
	var end := -1.0
	if room == int(patch.rooms[0]): end = 0.0
	elif room == int(patch.rooms[1]): end = profile.length
	else: return null
	var probe := State.new()
	probe.patch = band
	probe.u = end
	var at_end := anchor_of(probe)
	var tangent: Vector3 = frame_of(probe)[1]
	var off := anchor - at_end
	var out := State.new()
	out.patch = band
	out.hang = BAND_CLEAR
	out.u = clampf(end + off.dot(tangent), 0.0, profile.length)
	out.v = off.dot(patch.axis)
	clamp_state(out)
	if anchor_of(out).distance_to(anchor) > SEAM_TOL: return null
	return out

## A point on a tray's anchor plane, with the tray's normal, as a tray State.
func onto_tray(anchor: Vector3, normal: Vector3, tray: int, hang: float) -> State:
	var patch: Dictionary = patches[tray]
	if normal.dot(Vector3.DOWN) < 1.0 - 1e-6: return null
	var tray_hang := float(patch.y) - anchor.y
	if absf(tray_hang - hang) >= SEAM_TOL: return null
	var rect: Rect2 = patch.rect
	var p := Vector2(clampf(anchor.x, rect.position.x, rect.end.x), clampf(anchor.z, rect.position.y, rect.end.y))
	if p.distance_to(Vector2(anchor.x, anchor.z)) > SEAM_TOL: return null
	var out := State.new()
	out.patch = tray
	out.u = p.x
	out.v = p.y
	out.hang = tray_hang
	return out

## Whether a tray is one of a channel's unit's at its height.
func channel_tray(channel: Dictionary, tray: int) -> bool:
	var patch: Dictionary = patches[tray]
	return int(patch.kind) == Kind.TRAY and channel.unit.has(int(patch.room)) and absf(float(patch.y) - float(patches[int(channel.tray)].y)) <= 0.001

## How far off a channel's centre line a tray State may be and still switch.
func channel_seam(channel: Dictionary, hang: float) -> float:
	var flat := (float(channel.width) - 2.0 * channel_radius(channel)) / 2.0
	return minf(flat, SEAM_TOL * (float(channel.height) / 2.0) / hang) if hang > 1e-9 else flat

func tray_to_channel(s: State, anchor: Vector3, channel: int) -> State:
	var patch: Dictionary = patches[channel]
	if not channel_tray(patch, s.patch): return null
	var probe := State.new()
	probe.patch = channel
	if s.hang > max_hang(probe) + 1e-9: return null
	var off: Vector3 = anchor - (patch.origin as Vector3)
	var d: float = off.dot(patch.across)
	var along: float = off.dot(patch.axis)
	if absf(d) > channel_seam(patch, s.hang) + 1e-5 or along < -1e-5 or along > float(patch.length) + 1e-5: return null
	var out := State.new()
	out.patch = channel
	out.u = (patch.profile as Profile).length / 2.0 - d
	out.v = clampf(along, 0.0, float(patch.length))
	out.hang = s.hang
	return out

func channel_to_tray(s: State, anchor: Vector3, tray: int) -> State:
	var patch: Dictionary = patches[s.patch]
	if not channel_tray(patch, tray): return null
	var d := (patch.profile as Profile).length / 2.0 - s.u
	if absf(d) > channel_seam(patch, s.hang) + 1e-5: return null
	return onto_tray(anchor, Vector3.DOWN, tray, s.hang)

## The room a State is over.
func room_of(s: State) -> int:
	var patch: Dictionary = patches[s.patch]
	match int(patch.kind):
		Kind.TRAY:
			return int(patch.room)
		Kind.BAND:
			if int(patch.rooms[1]) < 0: return int(patch.rooms[0])
			return int(patch.rooms[0]) if (anchor_of(s) - (patch.origin as Vector3)).dot(patch.across) < 0.0 else int(patch.rooms[1])
	var found := int(FLOOR.room_at(rooms, anchor_of(s)).get("id", -1))
	return found if patch.unit.has(found) else int(patch.room)

## The back cue's posture (3.8): of the tray States `distance` behind the eye
## in its room, the one with the smallest hang that keeps her face at most
## CUE_ANGLE over the eye's level, facing it; she comes down past HANG_MAX
## (lowered) when nothing higher does it; null when nothing does.
func cue_pose(eye: Vector3, view: Vector3, distance: float) -> State:
	var flat := Vector3(view.x, 0, view.z)
	if flat.length() < 1e-6: return null
	flat = flat.normalized()
	var room := int(FLOOR.room_at(rooms, eye).get("id", -1))
	if not tray_of.has(room): return null
	var behind := eye - flat * distance
	var s := tray_state(room, behind.x, behind.z, HANG_MIN)
	var toward := Vector3(eye.x - s.u, 0, eye.z - s.v)
	if toward.length() < CUE_NEAR: return null
	set_heading(s, toward)
	var face_ahead := FACE_OFFSET.z
	var plan := maxf(toward.length() - face_ahead, 0.0)
	var top := float(patches[s.patch].y)
	var needed := top - FACE_OFFSET.y - eye.y - tan(CUE_ANGLE) * plan
	s.hang = maxf(HANG_MIN, needed)
	if s.hang <= HANG_MAX + 1e-9: return s
	var floor_y := float(rooms[room].get("py", 0.0))
	if s.hang > CUE_HANG_MAX + 1e-9 or top - s.hang - FACE_OFFSET.y < floor_y + CUE_FACE_LOW: return null
	s.lowered = true
	return s

## Her face for a State: FACE_OFFSET in her frame.
func face_of(s: State) -> Vector3:
	return transform_of(s) * FACE_OFFSET

## Where her sound comes out when she is in the plenum at `point` (the
## author, 24 October 2026): the middle of the tile under her, on the false
## ceiling; with no false ceiling there, the point itself.
func plenum_mouth(point: Vector3) -> Vector3:
	var found := FLOOR.room_at(rooms, point)
	if found.is_empty() or not OFFICE.false_ceiling(found): return point
	var tiles := OFFICE.full_tiles(found)
	var tile := OFFICE.tile_of(point)
	if tiles.size.x > 0 and tiles.size.y > 0: tile = Vector2i(clampi(tile.x, tiles.position.x, tiles.end.x - 1), clampi(tile.y, tiles.position.y, tiles.end.y - 1))
	return Vector3((float(tile.x) + 0.5) * OFFICE.TILE, float(found.get("py", 0.0)) + OFFICE.height_of(found), (float(tile.y) + 0.5) * OFFICE.TILE)

## A plain, deterministic description of every patch (tests).
func dump() -> Array:
	var out: Array = []
	for patch in patches:
		var row: Array = [int(patch.kind), int(patch.wing)]
		match int(patch.kind):
			Kind.TRAY:
				var rect: Rect2 = patch.rect
				row.append_array([int(patch.room), snappedf(float(patch.y), 0.0001), snappedf(rect.position.x, 0.0001), snappedf(rect.position.y, 0.0001), snappedf(rect.size.x, 0.0001), snappedf(rect.size.y, 0.0001), str(patch.open)])
			_:
				var origin: Vector3 = patch.origin
				var profile: Profile = patch.profile
				row.append_array([str(patch.get("rooms", [patch.get("room", -1)])), snappedf(origin.x, 0.0001), snappedf(origin.y, 0.0001), snappedf(origin.z, 0.0001), str(patch.across), snappedf(profile.length, 0.0001), snappedf(float(patch.width), 0.0001)])
		out.append(row)
	return out
