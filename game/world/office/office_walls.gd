extends RefCounted
## What hangs on the offices' walls (spec_rediseno 2, 5.2 and 6, area 4c): a
## type's pieces (palette.WALL_DRESSING) with the rule signs
## (palette.RULE_TEXTS); along the corridors, their fittings one every
## CORRIDOR_PITCH metres of the building's grid (palette.CORRIDOR_RHYTHM: as in
## a building, not drawn by lot); the mail room's pneumatic central for show, its lamps out
## (the working one is the window's, area 5); the archives' sign over their
## doors; the washroom's coats on their hooks. Each on a stretch of its wall
## that taken() leaves free: doorways with their switch and number plate,
## glass, open sides and a lift's, lockers, the floor's systems on that wall
## (LAYOUT.fixtures(), palette.FIXTURE_HALF), the zone sign, the furniture and
## corner pieces standing against it as tall as the piece would hang, the
## washroom's tiles (office_fittings.gd) and what was hung there already. Flat
## on the wall's face, on its lining only below the lining's top. By place(),
## box() and Label3D, with no collider; noted in builder.dressing_log.walls
## (tests/office/office_dressing_test.gd).
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
const WALL := preload("res://game/world/office/pieces/wall.gd")
const STAND := preload("res://game/world/office/pieces/stand_ins.gd")
const EQ_MAIL := preload("res://game/world/office/pieces/mail_equipment.gd")
const PICTURES := preload("res://game/world/office/office_pictures.gd")
const MODELS := preload("res://game/world/office/office_models.gd")
const SIDE_OF := {"Wall_-1_0": "west", "Wall_1_0": "east", "Wall_0_-1": "north", "Wall_0_1": "south"}
const SIDE_STEP := {"Wall_-1_0": Vector2i(-1, 0), "Wall_1_0": Vector2i(1, 0), "Wall_0_-1": Vector2i(0, -1), "Wall_0_1": Vector2i(0, 1)}
## A piece keeps this far from its wall's ends, and this much from the next.
const END_CLEAR := 0.35
const GAP := 0.2
## Either side of a doorway's middle: the opening, the jamb, the switch and
## the number plate.
const DOOR_HALF := 1.25
const LOCKER_HALF := 0.75
## Either side of a floor system's spot where palette.FIXTURE_HALF says nothing.
const FIXTURE_HALF := 0.9
## Furniture this near a wall's face stands against it; a corner piece's real
## footprint (CORNER_SIZES) this near, before it: the socket keeps the backed
## pieces 0.51 off the face, the centred ones (plant, bin, cart) up to 0.96.
const AGAINST := 0.35
const CORNER_AGAINST := 1.0
## What hangs over something low keeps this clear of its top.
const OVER := 0.1
## A low piece starts here over a dado or a frieze (wall_trim()).
const LOW_TRIM := 1.15
## How high a wall's lining reaches: a frieze or a dado, the two-tone paint,
## the secretary's panelling (all of it).
const TRIM_TOP := 1.0
const TWO_TONE_TOP := 1.2
const PANEL_TOP := 9.0
## Where a piece is tried along a wall: its middle, then this far either way, and on.
const STEP := 0.3
## The signs' letters as area 5 sets its plates' (objective.gd PLATE_PIXEL):
## each letter rasterised big and drawn small, so it reads.
const PLATE_PIXEL := 0.0015
const PLATE_OFF := 0.0015
const SIGN_FONT := 33
const CENTRAL_FONT := 22
const SIGN_MOUNT := 1.45
## Over an archive's doorway, inside.
const OVER_DOOR := 2.76
const INK := Color("e8e4d6")
const TEXT_REACH := 20.0
## Each kind: its size, and the height of its bottom.
const PIECES := {
	"notice": [Vector3(1.2, 0.9, 0.03), 1.0],
	"picture": [Vector3(0.6, 0.8, 0.03), 1.2],
	"picture_large": [Vector3(0.8, 1.0, 0.035), 1.1],
	"map": [Vector3(1.2, 0.85, 0.03), 1.15],
	"map_large": [Vector3(1.6, 1.1, 0.035), 1.05],
	"plan": [Vector3(0.6, 0.45, 0.025), 1.3],
	"diplomas": [Vector3(0.66, 0.54, 0.02), 1.3],
	"clock": [Vector3(0.4, 0.4, 0.06), 2.05],
	"clock_square": [Vector3(0.3, 0.3, 0.06), 1.85],
	"screen": [Vector3(1.8, 1.6, 0.1), 1.15],
	"keys": [Vector3(0.5, 0.6, 0.08), 1.3],
	"hooks": [Vector3(1.2, 0.12, 0.09), 1.6],
	"directory": [Vector3(0.9, 0.7, 0.05), 1.1],
	"central": [Vector3(0.56, 1.15, 0.2), 0.85],
	"extinguisher": [Vector3(0.2, 0.62, 0.18), 0.3],
	"hose": [Vector3(0.65, 0.75, 0.16), 1.0],
	"fountain": [Vector3(0.4, 0.4, 0.2), 0.75],
	"thermostat": [Vector3(0.09, 0.13, 0.03), 1.5],
	"alarm": [Vector3(0.14, 0.2, 0.08), 1.3],
	"socket": [Vector3(0.09, 0.09, 0.01), 0.25],
}

## Dresses a room's walls (office_geometry.extras(), after office_fittings.gd).
static func dress(builder: Node3D, node: Node3D, room: Dictionary) -> void:
	var t := int(room.type)
	if t == OFFICE.ARCHIVE or t == OFFICE.MOBILE_ARCHIVE:
		archive_signs(builder, node, room)
		return
	var walls := walls_of(builder, node, room)
	if walls.is_empty(): return
	if t == OFFICE.CORRIDOR:
		for wall: Dictionary in walls: corridor(builder, room, wall)
		return
	var entries: Array = OFFICE.WALL_DRESSING.get(t, [])
	if entries.is_empty(): return
	var feature := String(room.get("feature", ""))
	var order: Array = walls.filter(func(w: Dictionary) -> bool: return String(w.side) == feature) + walls.filter(func(w: Dictionary) -> bool: return String(w.side) != feature)
	var turn := 0
	for entry: Array in entries:
		for n in int(entry[1]):
			for k in order.size():
				if hang(builder, room, order[(turn + k) % order.size()], String(entry[0]), int(entry[2]), n):
					turn += 1
					break

## The room's walls that can take something: each {boundary, side, length,
## inner (+1 where the room is on the boundary's +Z), lift (what stands on
## the wall's face), trim_top (how high that reaches), taken (spans [from, to,
## low, high] in the boundary's x)}.
static func walls_of(builder: Node3D, node: Node3D, room: Dictionary) -> Array:
	var span := FLOOR.size_of(room)
	var glazed: Array = room.get("glazed", [])
	var open: Array = room.get("open_sides", [])
	var lift := FLOOR.lift_wall(room)
	var trim := OFFICE.wall_trim(room)
	var top: float = PANEL_TOP if trim == "panel_wall" else TWO_TONE_TOP if trim == "two_tone" else TRIM_TOP
	var arrival := Vector2i(9, 9)
	if int(room.id) == int(builder.manifest.get("start", -1)) and builder.manifest.has("arrival_lift"): arrival = Vector2i(int(builder.manifest.arrival_lift[0]), int(builder.manifest.arrival_lift[1]))
	var out: Array = []
	for boundary in node.get_children():
		var side := String(SIDE_OF.get(String(boundary.name), ""))
		if side.is_empty() or glazed.has(side) or open.has(side): continue
		var step: Vector2i = SIDE_STEP[String(boundary.name)]
		if step == lift or step == arrival: continue
		var length: float = span.y if side == "west" or side == "east" else span.x
		out.append({"boundary": boundary, "side": side, "length": length, "inner": -(step.x + step.y), "lift": builder.lining(side), "trim_top": top, "taken": taken(builder, room, boundary, side)})
	return out

## What a wall already has along it (walls_of()).
static func taken(builder: Node3D, room: Dictionary, boundary: Node3D, side: String) -> Array:
	var t := int(room.type)
	var out: Array = []
	for way in FLOOR.doorways(room):
		if String(way.wall) != side: continue
		var x := to_wall(side, float(way.along))
		out.append([x - DOOR_HALF, x + DOOR_HALF, 0.0, 9.0])
	for h in room.get("hides", []):
		var hw := LAYOUT.hide_wall(h)
		if String(hw.wall) != side: continue
		var x := to_wall(side, float(hw.along))
		out.append([x - LOCKER_HALF, x + LOCKER_HALF, 0.0, 9.0])
	var half: float = float(OFFICE.FIXTURE_HALF.get(t, FIXTURE_HALF))
	for fx in LAYOUT.fixtures(builder.manifest, int(room.id)):
		if String(fx.wall) != side: continue
		var x := to_wall(side, float(fx.along))
		out.append([x - half, x + half, 0.0, 9.0])
	if builder.sign_spans.has(boundary.get_instance_id()):
		var plate: Vector2 = builder.sign_spans[boundary.get_instance_id()]
		out.append([plate.x - 0.1, plate.y + 0.1, 0.0, 9.0])
	for item in room.get("furniture", []):
		var spec: Dictionary = OFFICE.FURNITURE.get(String(item.kind), {})
		var along := against(room, side, LAYOUT.footprint(item), AGAINST)
		if along.y > along.x: out.append([along.x, along.y, 0.0, float(spec.get("height", 2.2)) + OVER])
	if room.has("sockets"):
		for prop in room.get("props", []):
			var rect := OFFICE.corner_rect(String(prop.kind), room.sockets[int(prop.slot)], int(prop.rotation))
			var along := against(room, side, rect, CORNER_AGAINST)
			if along.y > along.x: out.append([along.x, along.y, 0.0, float(OFFICE.CORNER_HEIGHT.get(String(prop.kind), 2.2)) + OVER])
	# The washroom's tiles, and anything else already noted on this wall.
	for entry: Dictionary in builder.dressing_log.walls:
		if int(entry.room) == int(room.id) and String(entry.side) == side: out.append([float(entry.from) - GAP, float(entry.to) + GAP, float(entry.low), float(entry.high)])
	return out

## The span along `side` (the boundary's x, from < to) of a plan rect within
## `reach` of that wall's face; (0, 0) when it is farther.
static func against(room: Dictionary, side: String, rect: Rect2, reach: float) -> Vector2:
	var face := LAYOUT.face(room, side)
	var near := false
	match side:
		"west": near = rect.position.x - face < reach
		"east": near = face - rect.end.x < reach
		"north": near = rect.position.y - face < reach
		"south": near = face - rect.end.y < reach
	if not near: return Vector2.ZERO
	if side == "west" or side == "east": return Vector2(-rect.end.y, -rect.position.y)
	return Vector2(rect.position.x, rect.end.x)

## Hangs one piece of a type's list on a wall if it finds room there: true
## when it did. `text` is the sign's RULE_TEXTS; `n` how many of the kind are
## up already (a print's variant).
static func hang(builder: Node3D, room: Dictionary, wall: Dictionary, kind: String, text: int, n: int) -> bool:
	var size: Vector3 = sign_size(String(OFFICE.RULE_TEXTS[text])) if kind == "rule" else PIECES[kind][0]
	var mount: float = SIGN_MOUNT if kind == "rule" else float(PIECES[kind][1])
	if mount < LOW_TRIM and kind != "central" and OFFICE.wall_trim(room) in ["frieze", "dado"]: mount = LOW_TRIM
	var low: float = 0.75 if kind == "hooks" else mount
	var high := mount + size.y
	var x := free_x(wall, size.x + GAP * 2.0, low, high)
	if is_nan(x): return false
	draw(builder, room, wall, kind, x, mount, size, text, int(room.id) * 3 + n)
	wall.taken.append([x - size.x * 0.5 - GAP, x + size.x * 0.5 + GAP, low, high])
	logged(builder, room, wall, kind, x, size.x, low, high, size.z)
	return true

## A corridor wall's fittings (palette.CORRIDOR_RHYTHM): one at every multiple
## of CORRIDOR_PITCH of the world's x or z along it, the rhythm started at the
## wall's own quarter so facing walls differ; a slot whose stretch is taken
## stays bare. The rule there is the corridors' own or the grilles'.
static func corridor(builder: Node3D, room: Dictionary, wall: Dictionary) -> void:
	var side := String(wall.side)
	var across := side == "west" or side == "east"
	var start: float = float(room.pz) if across else float(room.px)
	var rhythm: Array = OFFICE.CORRIDOR_RHYTHM
	var pitch: float = OFFICE.CORRIDOR_PITCH
	var quarter: int = ["north", "east", "south", "west"].find(side) * rhythm.size() / 4
	var half := float(wall.length) * 0.5
	for k in range(ceili((start - half) / pitch), floori((start + half) / pitch) + 1):
		var x: float = start - k * pitch if across else k * pitch - start
		var kind := String(rhythm[posmod(k + quarter, rhythm.size())])
		if kind.is_empty(): continue
		var text: int = 0 if posmod(k, 2) == 0 else 3
		var size: Vector3 = sign_size(String(OFFICE.RULE_TEXTS[text])) if kind == "rule" else PIECES[kind][0]
		var mount: float = SIGN_MOUNT if kind == "rule" else float(PIECES[kind][1])
		if kind == "picture" or kind == "plan": mount = maxf(mount, LOW_TRIM)
		if not fits(wall, x, size.x + GAP * 2.0, mount, mount + size.y): continue
		draw(builder, room, wall, kind, x, mount, size, text, k)
		wall.taken.append([x - size.x * 0.5 - GAP, x + size.x * 0.5 + GAP, mount, mount + size.y])
		logged(builder, room, wall, kind, x, size.x, mount, mount + size.y, size.z)

## An archive's walls are its shelving (9.5): only the rule, over each of its
## doorways on the inside, high and flat on the wall.
static func archive_signs(builder: Node3D, node: Node3D, room: Dictionary) -> void:
	var words := String(OFFICE.RULE_TEXTS[2]).replace("\n", " ")
	var size := sign_size(words)
	for wall: Dictionary in walls_of(builder, node, room):
		for way in FLOOR.doorways(room):
			if String(way.wall) != String(wall.side): continue
			var x := to_wall(String(wall.side), float(way.along))
			var at := xform_of(wall, x, OVER_DOOR, size.z)
			var plate := WALL.sign_plate(builder, size)
			builder.place(wall.boundary, plate, at)
			plate_text(wall.boundary, plate, at, words, SIGN_FONT)
			logged(builder, room, wall, "rule", x, size.x, OVER_DOOR, OVER_DOOR + size.y, size.z)

## The free middle of a span `wide` along the wall from `low` to `high`,
## tried from the wall's middle outward every STEP; NAN when there is none.
static func free_x(wall: Dictionary, wide: float, low: float, high: float) -> float:
	var reach := float(wall.length) * 0.5 - END_CLEAR - wide * 0.5
	if reach < 0.0: return NAN
	for k in int(reach * 2.0 / STEP) + 2:
		var x := STEP * ceili(k / 2.0) * (1.0 if k % 2 == 0 else -1.0)
		if absf(x) > reach: continue
		if fits(wall, x, wide, low, high): return x
	return NAN

## Whether a span `wide` round x, from `low` to `high`, is inside the wall's
## ends and clear of all it has.
static func fits(wall: Dictionary, x: float, wide: float, low: float, high: float) -> bool:
	var half := float(wall.length) * 0.5 - END_CLEAR
	var a := x - wide * 0.5
	var b := x + wide * 0.5
	if a < -half or b > half: return false
	for span: Array in wall.taken:
		if a < float(span[1]) and b > float(span[0]) and low < float(span[3]) and high > float(span[2]): return false
	return true

## How far a piece hung at `mount` stands off the wall's face: on its lining
## when it starts below the lining's top, on the paint above it.
static func lift_at(wall: Dictionary, mount: float) -> float:
	return float(wall.lift) if mount < float(wall.trim_top) else 0.0

## Where a wall piece goes: its middle at x, its bottom at `mount`, its back on
## the wall (lift_at()), its front into the room.
static func xform_of(wall: Dictionary, x: float, mount: float, depth: float) -> Transform3D:
	var inner := int(wall.inner)
	return Transform3D(Basis(Vector3.UP, PI if inner < 0 else 0.0), Vector3(x, mount, inner * (0.09 + lift_at(wall, mount) + 0.002 + depth * 0.5)))

## One piece of `kind` (PIECES) at x on the wall.
static func draw(builder: Node3D, room: Dictionary, wall: Dictionary, kind: String, x: float, mount: float, size: Vector3, text: int, pick: int) -> void:
	var boundary: Node3D = wall.boundary
	var inner := int(wall.inner)
	var face := 0.09 + lift_at(wall, mount)
	var at := xform_of(wall, x, mount, size.z)
	match kind:
		"notice": builder.place(boundary, WALL.notice_board(builder, size), at)
		"picture", "picture_large": framed(builder, boundary, WALL.picture_frame(builder, size, "walnut_object"), at, "print", pick)
		"map": framed(builder, boundary, WALL.picture_frame(builder, size, "black"), at, "city", pick)
		"map_large": framed(builder, boundary, WALL.picture_frame(builder, size, "walnut_object"), at, "city", pick)
		"plan": framed(builder, boundary, WALL.picture_frame(builder, size, "black"), at, "plan", int(room.get("wing", 0)))
		"diplomas":
			var frame := WALL.picture_frame(builder, Vector3(0.3, 0.24, 0.02), "black")
			for k in 4: framed(builder, boundary, frame, at * Transform3D(Basis.IDENTITY, Vector3(-0.17 + (k % 2) * 0.34, 0.3 * (k / 2), 0)), "diploma", 0)
		"clock": MODELS.put(builder, boundary, "wall_clock", Transform3D(at.basis, Vector3(x, mount, inner * (face + 0.027))))
		"clock_square": builder.place(boundary, WALL.clock_square(builder, size), at)
		"screen": builder.place(boundary, WALL.roll_screen(builder, size), at)
		"keys": builder.place(boundary, WALL.key_cabinet(builder, size), at)
		"hooks":
			builder.place(boundary, WALL.coat_hook_rail(builder, size), at)
			builder.place(boundary, STAND.coat_hanging(builder, Vector3(0.5, 0.95, 0.14)), xform_of(wall, x - 0.3, 0.75, 0.14))
			builder.place(boundary, STAND.towel(builder, Vector3(0.3, 0.55, 0.04)), xform_of(wall, x + 0.3, 1.1, 0.04))
		"directory": builder.place(boundary, WALL.directory_board(builder, size), at)
		"central":
			var central := EQ_MAIL.mail_central(builder, EQ_MAIL.CENTRAL, false)
			builder.place(boundary, central, at)
			plate_text(boundary, central, at, "CORREO NEUMÁTICO", CENTRAL_FONT)
		"rule":
			var plate := WALL.sign_plate(builder, size)
			builder.place(boundary, plate, at)
			plate_text(boundary, plate, at, String(OFFICE.RULE_TEXTS[text]), SIGN_FONT)
		"extinguisher": builder.place(boundary, STAND.extinguisher(builder, size), at)
		"hose": builder.place(boundary, STAND.hose_cabinet(builder, size), at)
		"fountain": builder.place(boundary, STAND.wall_fountain(builder, size), at)
		"thermostat": builder.place(boundary, STAND.thermostat(builder, size), at)
		"alarm": MODELS.put(builder, boundary, "fire_alarm", Transform3D(at.basis, Vector3(x, mount, inner * (face + 0.018))))
		"socket":
			builder.box(boundary, Vector3(x, mount + 0.045, inner * (face + 0.004)), Vector3(0.09, 0.09, 0.008), "switch", false, "detail")
			for s: float in [-0.018, 0.018]: builder.box(boundary, Vector3(x + s, mount + 0.045, inner * (face + 0.0085)), Vector3(0.008, 0.016, 0.002), "black")

## A frame and its picture (office_pictures.gd) in the frame's "picture" spot.
static func framed(builder: Node3D, boundary: Node3D, frame: Mesh, at: Transform3D, look: String, pick: int) -> void:
	builder.place(boundary, frame, at)
	var spot: Array = frame.get_meta("picture")
	var centre: Vector3 = spot[0]
	var area: Vector2 = spot[1]
	var normal: Vector3 = spot[2]
	builder.place(boundary, PICTURES.quad(builder, look, pick), at * Transform3D(Basis.IDENTITY.scaled(Vector3(area.x, area.y, 1.0)), centre + normal * 0.0005), false)

## The words on a piece's text_plate (pieces/wall.gd sign_plate(), area 5's
## mail_central()), in light letters, lit as the building's signs are, out
## past TEXT_REACH.
static func plate_text(boundary: Node3D, mesh: Mesh, at: Transform3D, words: String, font: int) -> void:
	if not mesh.has_meta("text_plate"): return
	var spot: Array = mesh.get_meta("text_plate")
	var centre: Vector3 = spot[0]
	var normal: Vector3 = spot[2]
	var label := Label3D.new()
	label.text = words
	label.font_size = font
	label.pixel_size = PLATE_PIXEL
	label.modulate = INK
	label.outline_size = 0
	label.shaded = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.visibility_range_end = TEXT_REACH
	label.position = at * (centre + normal * PLATE_OFF)
	label.rotation.y = at.basis.get_euler().y
	boundary.add_child(label)

## A rule sign's plate, from its longest line and how many lines (SIGN_FONT).
static func sign_size(words: String) -> Vector3:
	var lines := words.split("\n")
	var longest := 0
	for line in lines: longest = maxi(longest, line.length())
	var letter := float(SIGN_FONT) * PLATE_PIXEL
	return Vector3(snappedf(longest * letter * 0.62 + 0.08, 0.01), snappedf(lines.size() * letter * 1.3 + 0.05, 0.01), 0.01)

## Notes a piece for the dressing test (builder.dressing_log.walls).
static func logged(builder: Node3D, room: Dictionary, wall: Dictionary, kind: String, x: float, wide: float, low: float, high: float, depth: float) -> void:
	builder.dressing_log.walls.append({"room": int(room.id), "side": String(wall.side), "kind": kind, "from": x - wide * 0.5, "to": x + wide * 0.5, "low": low, "high": high, "depth": depth})

## A room-local point along a wall (doorways()' along) in the wall's own x.
static func to_wall(side: String, along: float) -> float:
	return -along if side == "west" or side == "east" else along
