extends RefCounted
## The landmark rooms (the author, 14 November 2026: the rooms a planta is
## played in stand out from the mundane ones, for whoever comes new). Seen
## from three distances: down the corridor, a banner across the corridor over
## the door and a battery bulkhead lamp over it, the only lit doors of the
## floor, its glass in the colour of the room's system and its cone in the
## dust; at the door, an industrial safety sign at eye height (the author's
## four references) and, at the electrical room, hazard stripes on the floor
## of its threshold; inside, the thing used under its own light (office_
## geometry.gd: the window's arm lamp over the typewriter, the electrical
## room's battery unit on the board, a bulkhead over the security console and
## over the plant's isolator). And the way there, kept scarce (the author, 16
## November 2026: with so much it was easy): ONE sign hung from the ceiling on
## the way from the arrival to the planta's landmarks, the sign at their door
## and nothing more (no banner, and the arrival's directory names only the
## departments); among many other way signs, as logical, to the company's other
## places (meeting room, archive, toilets, mail, break room...). All of it from the room types and the manifest's keys
## (mail, power, air, refuges, entries, departments, adjacency), whatever the
## shape of the plan; nothing of it in the manifest or on the wire. The
## freight lift's vestibule keeps its way out hidden: its sign on its door and
## nothing else, and no directory or way sign names it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const KIT := preload("res://game/world/office/pieces/kit.gd")
const MODELS := preload("res://game/world/office/office_models.gd")

## Letters rasterised big and drawn small (office_walls.gd PLATE_PIXEL).
const PIXEL := 0.0015
const INK_BLACK := Color(0.06, 0.06, 0.05)
const INK_WHITE := Color(0.93, 0.91, 0.86)
const INK_YELLOW := Color(0.98, 0.8, 0.12)
## What each kind of landmark shows: its banner's lines and look, its door
## lamp's light and glass and how bright it lights the door, its door sign,
## its name on the way signs.
const KINDS := {
	"window": {"banner": "PERSONAL\nVENTANILLA", "look": "white", "lamp": Color(1.0, 0.86, 0.66), "glass": "glow_white", "wash": 1.6, "sign": "window", "way": "VENTANILLA DE PERSONAL"},
	# Cold white: the battery units of planta 2 are amber too (2400 K).
	"electrical": {"banner": "CUARTO ELÉCTRICO", "look": "yellow", "lamp": Color(0.78, 0.88, 1.0), "glass": "glow_white", "wash": 1.2, "sign": "electrical", "way": "CUADRO ELÉCTRICO"},
	"maneuver": {"banner": "SALA DE MANIOBRA\nMONTACARGAS", "look": "yellow", "lamp": Color(1.0, 0.8, 0.55), "glass": "glow_white", "wash": 1.2, "sign": "maneuver", "way": "SALA DE MANIOBRA"},
	"security": {"banner": "SEGURIDAD\nCONTROL DE ACCESO", "look": "red", "lamp": Color(1.0, 0.2, 0.12), "glass": "glow_red", "wash": 1.3, "sign": "restricted", "way": "SEGURIDAD"},
	"machines": {"banner": "SALA DE MÁQUINAS", "look": "red", "lamp": Color(1.0, 0.2, 0.12), "glass": "glow_red", "wash": 1.3, "sign": "machines", "way": "SALA DE MÁQUINAS"},
	"lift": {"banner": "", "look": "", "sign": "lift", "way": ""},
}
## A panel's enamel and its letters.
const LOOKS := {"white": ["sign_white", INK_BLACK], "yellow": ["sign_yellow", INK_BLACK], "red": ["sign_red", INK_WHITE]}
## The door signs, as the references: [rim, head enamel, head ink, head words,
## body enamel, body ink, body words, the body's small words under them].
const SIGNS := {
	"electrical": ["black", "black", INK_YELLOW, "PELIGRO", "sign_yellow", INK_BLACK, "CUARTO ELÉCTRICO", "SOLO PERSONAL AUTORIZADO"],
	"maneuver": ["black", "black", INK_YELLOW, "PELIGRO", "sign_yellow", INK_BLACK, "SALA DE MANIOBRA", "PUERTA MOTORIZADA"],
	"restricted": ["black", "sign_red", INK_YELLOW, "ACCESO RESTRINGIDO", "sign_yellow", INK_BLACK, "SOLO PERSONAL\nAUTORIZADO", ""],
	"machines": ["sign_white", "sign_red", INK_WHITE, "SALA DE MÁQUINAS", "sign_red", INK_WHITE, "SOLO PERSONAL\nAUTORIZADO", ""],
	"lift": ["black", "sign_red", INK_WHITE, "MONTACARGAS", "sign_white", INK_BLACK, "SOLO PERSONAL\nREGISTRADO", ""],
	"window": ["black", "black", INK_WHITE, "PERSONAL", "sign_white", INK_BLACK, "VENTANILLA", "ATENCIÓN DE 9 A 14 H"],
}
## A door sign: its size (A3 across), its head's share of it, its middle's height.
const SIGN := Vector2(0.42, 0.3)
const SIGN_HEAD := 0.34
const SIGN_Y := 1.6
## On a glazed wall: the pane's face from the wall's (office_geometry
## glazed_run(), the glass GLASS_THICK in the wall's middle), and the plain wall
## kept either side of the security post's reader (READER_SOLID).
const GLASS_FACE := -OFFICE.WALL_HALF + 0.005
const READER_SOLID := 0.4
## Where the door's frame ends either side of its middle (FLOOR.PORTAL, the
## jamb), and the gap from it to the sign.
const FRAME_EDGE := FLOOR.PORTAL * 0.5 + 0.09
const SIGN_GAP := 0.06
## The bulkhead over the door: its body, its middle's height (over the frame's
## head at 2.74, under a false ceiling at 2.95) and its two lights, neither
## casting. Its halo, down 50 degrees and 38 either side: its cone never
## crosses the wall it is on, so it lights the dust of the corridor and never
## the room's behind (a light with no shadow lights the air through walls);
## low, it marks the door and leaves the corridor dark. Its wash, on the door
## and its sign, lighting no air. Where a tube of planta 1 runs along the wall
## over the door, the bulkhead is on the ceiling, CEILING_OUT from the wall.
const BULKHEAD := Vector3(0.24, 0.13, 0.09)
const LAMP_Y := 2.84
const LAMP_DOWN := 50.0
const LAMP_ANGLE := 38.0
const LAMP_ENERGY := 0.7
const LAMP_REACH := 2.8
const WASH_ANGLE := 46.0
const WASH_REACH := 3.2
## The wash from WASH_OUT off the wall: from the glass it grazed the wall and
## left the sign beside the door dark. Paler than the glass by WASH_WHITE, so a
## red lamp does not leave its sign one red.
const WASH_OUT := 0.45
const WASH_WHITE := 0.85
const CEILING_OUT := 0.35
const TUBE_CLEAR := 0.22
## The banner: off the frame's edge, out from the wall, its middle's height.
const BANNER := Vector3(0.022, 0.28, 0.62)
const BANNER_OUT := 0.1
const BANNER_Y := 2.34
const BANNER_GAP := 0.05
## Its words read from the end of a corridor.
const BANNER_REACH := 32.0
const SIGN_REACH := 14.0
## The hazard stripes on the electrical room's threshold, outside.
const STRIPES := Vector2(FLOOR.PORTAL, 0.14)
## The bulkhead over a dark landmark's object (the plant's isolator, the
## security console): how high over what it lights, its light.
const OVER_OBJECT := 0.55
const FOCAL_ENERGY := 3.5
const FOCAL_ANGLE := 28.0
const FOCAL_REACH := 3.0
## As an accent in a lit room (the post), over its fittings.
const ACCENT_ENERGY := 6.0
## The console's start key from the post desk's wall spot (the desk's top,
## the console DESK_MIDDLE out, its key 0.45 right and 0.13 before that).
const CONSOLE_KEY := Vector3(0.45, 0.79, 0.355)
## The way signs: their panel, its bottom's height; one to a planta for its
## landmarks, and up to DECOYS_MOST to its other places, named as the
## palette's WAY_PLACES (room type -> words).
const WAY := Vector3(1.0, 0.2, 0.02)
const WAY_Y := 2.25
const DECOYS_MOST := 6
## The banner across the corridor over a landmark's door: off since the
## author's nerf (its bulkhead lamp stays).
const BANNERS := false
## The directory's board (office_walls.gd PIECES "directory") and its lines.
const LINE_MOST := 0.056

## The kind of landmark a room is ("" for none), from the manifest's keys.
static func kind_of(manifest: Dictionary, room_id: int) -> String:
	if room_id < 0: return ""
	if int(manifest.get("mail", {}).get("window", -1)) == room_id: return "window"
	if int(manifest.get("power", {}).get("room", -1)) == room_id: return "electrical"
	if int(manifest.get("power", {}).get("maneuver", {}).get("room", -1)) == room_id: return "maneuver"
	var air: Dictionary = manifest.get("air", {})
	if int(air.get("security", {}).get("room", -1)) == room_id: return "security"
	if int(air.get("room", -1)) == room_id or int(air.get("plant", -1)) == room_id: return "machines"
	for refuge in manifest.get("refuges", []):
		if int(refuge) == room_id and int(manifest.rooms[room_id].type) == OFFICE.REFUGE: return "lift"
	return ""

## Whether the door between two rooms is the security post's card door.
static func card_door(manifest: Dictionary, a: int, b: int) -> bool:
	var key := String(manifest.get("air", {}).get("security", {}).get("door", ""))
	return key == "%d:%d" % [a, b] or key == "%d:%d" % [b, a]

## A door's marks (office_geometry.door_plaques()): on the face of a mundane
## room's side of a landmark's door, and of the card door's outside.
static func door(b: Node3D, a: Dictionary, c: Dictionary, center: Vector3, yaw: float) -> void:
	var manifest: Dictionary = b.manifest
	if b.gate_stage(manifest, int(a.id), int(c.id)) > 0: return
	for pair in [[a, c], [c, a]]:
		var inside: Dictionary = pair[0]
		var outside: Dictionary = pair[1]
		var kind := kind_of(manifest, int(inside.id))
		if kind.is_empty(): continue
		var card := kind == "security" and card_door(manifest, int(a.id), int(c.id))
		if card and int(manifest.air.security.get("outside", -1)) != int(outside.id): continue
		if not card and not kind_of(manifest, int(outside.id)).is_empty(): continue
		dress_door(b, kind, inside, outside, center, yaw, card)

## The outside face of the door: +Z into `outside`, +X along the wall, the
## origin on the wall's face at the floor, in `outside`'s node.
static func face_of(b: Node3D, outside: Dictionary, center: Vector3, yaw: float) -> Transform3D:
	var normal := Basis(Vector3.UP, yaw).z
	var out := normal * signf((FLOOR.position_of(outside) - center).dot(normal))
	var holder: Node3D = b.room_nodes[int(outside.id)]
	return Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), center + out * OFFICE.WALL_HALF - holder.position)

## How much wall `outside` has from the door's middle along `way` (world),
## to the end of its cell or the next doorway on that wall.
static func wall_left(b: Node3D, inside: Dictionary, outside: Dictionary, center: Vector3, way: Vector3) -> float:
	var middle := FLOOR.position_of(outside)
	var half := FLOOR.size_of(outside) * 0.5
	var left: float = (middle.x + signf(way.x) * half.x - center.x) * signf(way.x) if absf(way.x) > 0.5 else (middle.z + signf(way.z) * half.y - center.z) * signf(way.z)
	for doorway in FLOOR.doorways(outside):
		if int(doorway.other) == int(inside.id): continue
		var portal := FLOOR.portal_between(outside, b.manifest.rooms[int(doorway.other)])
		var off := portal - center
		if absf(off.x * (1.0 - absf(way.x)) + off.z * (1.0 - absf(way.z))) > 0.3: continue
		var ahead := off.dot(way)
		if ahead > 0.0: left = minf(left, ahead - FRAME_EDGE)
	return left

## Whether the wall between two rooms is glass (office_geometry.glazed_run()).
static func glazed(a: Dictionary, c: Dictionary) -> bool:
	for pair in [[a, c], [c, a]]:
		var d := FLOOR.position_of(pair[1]) - FLOOR.position_of(pair[0])
		var side := ("east" if d.x > 0.0 else "west") if absf(d.x) > absf(d.z) else ("south" if d.z > 0.0 else "north")
		if (pair[0] as Dictionary).get("glazed", []).has(side): return true
	return false

static func dress_door(b: Node3D, kind: String, inside: Dictionary, outside: Dictionary, center: Vector3, yaw: float, card: bool) -> void:
	var spec: Dictionary = KINDS[kind]
	var holder: Node3D = b.room_nodes[int(outside.id)]
	var face := face_of(b, outside, center, yaw)
	# The sign on the side away from the leaf's +X (where the number plaques
	# were), the banner over the other.
	var plaque := signf(Basis(Vector3.UP, yaw).x.dot(face.basis.x))
	var sign_side := -plaque
	var sign_x := FRAME_EDGE + SIGN_GAP + SIGN.x * 0.5
	if wall_left(b, inside, outside, center, face.basis.x * sign_side) < sign_x + SIGN.x * 0.5 + 0.05: sign_side = plaque
	# The wash on the door's middle, or between it and its sign.
	var wash := Vector3(0, 1.3, 0)
	if not String(spec.sign).is_empty():
		var x: float = sign_x
		var y: float = SIGN_Y
		var z := 0.0
		if glazed(inside, outside):
			# Past the door's frame the wall is glass (but the card door's stretch
			# of plain wall to its reader): stuck on the glass, clear of the plain
			# wall. On the wall's face it hung in the air before the pane.
			var solid := FRAME_EDGE
			var reader: Dictionary = b.manifest.air.security.get("reader", {}) if card else {}
			if not reader.is_empty():
				var off: float = (spot_of(reader) - center).dot(face.basis.x * sign_side)
				if off > 0.0: solid = off + READER_SOLID
			if solid < x + SIGN.x * 0.5:
				x = maxf(x, solid + SIGN_GAP + SIGN.x * 0.5)
				z = GLASS_FACE
		if wall_left(b, inside, outside, center, face.basis.x * sign_side) >= x + SIGN.x * 0.5 + 0.05:
			door_sign(b, holder, face * Transform3D(Basis.IDENTITY, Vector3(sign_side * x, y, z)), String(spec.sign))
			wash = Vector3(sign_side * x * 0.45, 1.4, 0)
	if kind == "lift": return
	var banner_side := plaque if wall_left(b, inside, outside, center, face.basis.x * plaque) >= FRAME_EDGE + BANNER_GAP + 0.1 else -plaque
	door_head(b, holder, face, kind, banner_side, int(inside.id), float(outside.height), wash)
	if kind in ["electrical", "maneuver"]:
		b.place(holder, stripes_mesh(), face * Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 0.003, 0.1)), false)
	if card:
		# A camera over the card door, at the frame's corner opposite the
		# reader's, looking at whoever comes to it.
		var camera := MODELS.mesh_of(b, "cctv_camera")
		if camera != null:
			var eye := Vector3(-banner_side * (FRAME_EDGE + 0.1), 2.62, 0.16)
			var look := Basis.looking_at(Vector3(banner_side * 0.4, 1.5, 2.2) - eye, Vector3.UP)
			b.place(holder, camera, face * Transform3D(look, eye), false)

## The bulkhead and the banner over a door (one piece, so it is drawn from
## afar), the banner's words on both its faces and the bulkhead's two lights.
static func door_head(b: Node3D, holder: Node3D, face: Transform3D, kind: String, side: float, room_id: int, height: float, wash: Vector3) -> void:
	var spec: Dictionary = KINDS[kind]
	var world := Transform3D(Basis.IDENTITY, holder.position) * face
	var ceiling := height if under_tube(b.manifest, world * Vector3(0, LAMP_Y, BULKHEAD.z * 0.5)) else 0.0
	b.place(holder, head_mesh(b, kind, side, ceiling), face, false)
	if BANNERS:
		var look: Array = LOOKS[String(spec.look)]
		var words := String(spec.banner)
		var font := fit(words, Vector2(BANNER.z - 0.06, BANNER.y - 0.05), 72)
		var x := side * (FRAME_EDGE + BANNER_GAP)
		for s: float in [-1.0, 1.0]:
			var at := Transform3D(Basis(Vector3.UP, s * PI / 2), Vector3(x + s * (BANNER.x * 0.5 + 0.001), BANNER_Y, BANNER_OUT + BANNER.z * 0.5))
			label(holder, words, face * at, look[1], font, BANNER_REACH)
	var from := Vector3(0, ceiling - BULKHEAD.z - 0.01, CEILING_OUT) if ceiling > 0.0 else Vector3(0, LAMP_Y - 0.03, BULKHEAD.z + 0.01)
	var down := deg_to_rad(LAMP_DOWN)
	door_light(b, holder, face * Transform3D(Basis.looking_at(Vector3(0, -sin(down), cos(down)), Vector3.UP), from), spec.lamp, LAMP_ENERGY, LAMP_REACH, LAMP_ANGLE, room_id, "LandmarkDoorHalo")
	var wash_from := Vector3(0, from.y, WASH_OUT)
	door_light(b, holder, face * Transform3D(Basis.looking_at(wash - wash_from, Vector3.UP), wash_from), (spec.lamp as Color).lerp(Color(1.0, 0.92, 0.82), WASH_WHITE), float(spec.wash), WASH_REACH, WASH_ANGLE, room_id, "LandmarkDoorWash")

## One of a door's bulkhead lights, filed for round_landmarks(): the halo
## lights the air, the wash does not.
static func door_light(b: Node3D, holder: Node3D, at: Transform3D, colour: Color, energy: float, reach: float, angle: float, room_id: int, title: String) -> void:
	var light := SpotLight3D.new()
	light.name = title
	light.transform = at
	light.light_color = colour
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = angle
	light.light_specular = 0.2
	light.shadow_enabled = false
	light.light_bake_mode = Light3D.BAKE_DISABLED
	light.light_volumetric_fog_energy = 0.0
	light.set_meta("own_room", true)
	holder.add_child(light)
	b.landmark_lamps.append({"light": light, "room": room_id, "focal": false, "air": title == "LandmarkDoorHalo"})

## Whether a tube of the mail network (manifest.tubes) runs by a world point.
static func under_tube(manifest: Dictionary, at: Vector3) -> bool:
	var tubes: Dictionary = manifest.get("tubes", {})
	var nodes: Array = tubes.get("nodes", [])
	for edge in tubes.get("edges", []):
		var a := Vector3(float(nodes[int(edge[0])][0]), float(nodes[int(edge[0])][1]), float(nodes[int(edge[0])][2]))
		var c := Vector3(float(nodes[int(edge[1])][0]), float(nodes[int(edge[1])][1]), float(nodes[int(edge[1])][2]))
		if Geometry3D.get_closest_point_to_segment(at, a, c).distance_to(at) < TUBE_CLEAR: return true
	return false

## A bulkhead over a landmark's object, aimed at it (office_geometry.extras()):
## `at` its back's middle on the wall, `aim` the point lit, in `node`'s frame;
## its battery's light casting only while the eye is in its room (round_
## landmarks()). Through `accent` it is an accent of a lit room instead,
## going out and dimmed with it.
static func object_lamp(b: Node3D, node: Node3D, room_id: int, at: Transform3D, aim: Vector3, accent := false) -> void:
	b.place(node, bulkhead_mesh(b, "glow_white"), at, false)
	var from := at * Vector3(0, -0.03, BULKHEAD.z + 0.01)
	if accent:
		b.accent_spot(node, room_id, from, aim, Color(1.0, 0.88, 0.7), ACCENT_ENERGY, FOCAL_REACH, FOCAL_ANGLE)
		return
	var light := SpotLight3D.new()
	light.name = "LandmarkLamp"
	var toward := aim - from
	light.transform = Transform3D(Basis.looking_at(toward, Vector3.FORWARD if absf(toward.normalized().y) > 0.99 else Vector3.UP), from)
	light.light_color = Color(1.0, 0.88, 0.7)
	light.light_energy = FOCAL_ENERGY
	light.spot_range = FOCAL_REACH
	light.spot_angle = FOCAL_ANGLE
	light.light_specular = 0.2
	light.shadow_enabled = false
	light.shadow_bias = 0.04
	light.light_bake_mode = Light3D.BAKE_DISABLED
	light.set_meta("own_room", true)
	node.add_child(light)
	b.landmark_lamps.append({"light": light, "room": room_id, "focal": true})

## A door sign at `at` (its middle, on the wall's face), its words on it.
static func door_sign(b: Node3D, holder: Node3D, at: Transform3D, style: String) -> void:
	var spec: Array = SIGNS[style]
	b.place(holder, sign_mesh(b, style), at, false)
	var head_h := SIGN.y * SIGN_HEAD
	var body_h := SIGN.y - head_h
	var front := 0.006
	var head_at := Vector3(0, SIGN.y * 0.5 - head_h * 0.5, front)
	label(holder, String(spec[3]), at * Transform3D(Basis.IDENTITY, head_at), spec[2], fit(String(spec[3]), Vector2(SIGN.x - 0.05, head_h - 0.025), 60), SIGN_REACH)
	# The body's words, and its small ones under them in its lower third.
	var small := String(spec[7])
	var main_h := body_h * (0.62 if not small.is_empty() else 1.0)
	var main_at := Vector3(0, -SIGN.y * 0.5 + body_h - main_h * 0.5, front)
	label(holder, String(spec[6]), at * Transform3D(Basis.IDENTITY, main_at), spec[5], fit(String(spec[6]), Vector2(SIGN.x - 0.05, main_h - 0.03), 48), SIGN_REACH)
	if not small.is_empty():
		var small_h := body_h - main_h
		label(holder, small, at * Transform3D(Basis.IDENTITY, Vector3(0, -SIGN.y * 0.5 + small_h * 0.5 + 0.008, front)), spec[5], fit(small, Vector2(SIGN.x - 0.05, small_h - 0.02), 30), SIGN_REACH)

## The words on a panel: lit as everything else, readable from +Z only.
static func label(parent: Node3D, words: String, at: Transform3D, ink: Color, font: int, reach: float, stencil := true) -> Label3D:
	var text := Label3D.new()
	text.text = words
	if stencil: text.font = sign_face()
	text.font_size = font
	text.pixel_size = PIXEL
	text.modulate = ink
	text.outline_size = 0
	text.shaded = true
	text.double_sided = false
	text.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	text.visibility_range_end = reach
	# Fading out past it, never cut at once (hotel_geometry.fade_out).
	text.visibility_range_end_margin = 6.0
	text.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	text.transform = at
	parent.add_child(text)
	return text

## The biggest font (to `most`) whose lines fit `box` (metres), measured
## with the font a Label3D draws when it has none of its own.
static func fit(words: String, box: Vector2, most: int, stencil := true) -> int:
	var font: Font = sign_face() if stencil else ThemeDB.fallback_font
	var lines := words.split("\n")
	var size := most
	while size > 8:
		var wide := 0.0
		for line in lines: wide = maxf(wide, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		if wide * PIXEL <= box.x and font.get_height(size) * lines.size() * PIXEL <= box.y: break
		size -= 1
	return size

## The signs' letters: the face a Label3D draws with when it has none,
## made bold and narrow as the stencil letters of the period's safety signs
## (with the plain face their long words came out small on their panels).
const STENCIL_BOLD := 0.7
const STENCIL_NARROW := 0.78
static var stencil_face: FontVariation = null
static func sign_face() -> FontVariation:
	if stencil_face == null:
		stencil_face = FontVariation.new()
		stencil_face.base_font = ThemeDB.fallback_font
		stencil_face.variation_embolden = STENCIL_BOLD
		stencil_face.variation_transform = Transform2D(Vector2(STENCIL_NARROW, 0), Vector2(0, 1), Vector2.ZERO)
	return stencil_face

## How wide a line is drawn at `size` in the plain face, in metres.
static func width_of(line: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * PIXEL

## The safety sign of a style: its rim, its head and its body, two screws.
static func sign_mesh(b: Node3D, style: String) -> ArrayMesh:
	return KIT.cached(b, KIT.key_of("safety_sign_" + style, Vector3(SIGN.x, SIGN.y, 0.006)), func() -> ArrayMesh:
		var spec: Array = SIGNS[style]
		var p := KIT.begin()
		var head_h := SIGN.y * SIGN_HEAD
		var rim := 0.008
		KIT.block(p, String(spec[0]), Vector3(0, 0, 0.0015), Vector3(SIGN.x, SIGN.y, 0.003), 0.001)
		KIT.block(p, String(spec[1]), Vector3(0, SIGN.y * 0.5 - head_h * 0.5 - rim * 0.25, 0.0035), Vector3(SIGN.x - rim * 2.0, head_h - rim * 1.5, 0.001))
		KIT.block(p, String(spec[4]), Vector3(0, -SIGN.y * 0.5 + (SIGN.y - head_h) * 0.5 + rim * 0.25, 0.0035), Vector3(SIGN.x - rim * 2.0, SIGN.y - head_h - rim * 1.5, 0.001))
		for s: float in [-1.0, 1.0]:
			KIT.cylinder(p, "metal", Vector3(s * (SIGN.x * 0.5 - 0.016), SIGN.y * 0.5 - 0.016, 0.0045), 0.004, 0.002, 8, KIT.along_z())
		return KIT.finish(b, p, "safety_sign_" + style, Vector3(SIGN.x, SIGN.y, 0.006), {"wall": true, "solid": false}))

## A bulkhead lamp: its cast body, its glass in `glass` and the cage over it;
## its back's middle at `at`, front to +Z turned by `turn` (on a ceiling,
## front down).
static func bulkhead(p: Dictionary, glass: String, at: Vector3, turn := Basis.IDENTITY) -> void:
	KIT.block(p, "steel_grey", at + turn * Vector3(0, 0, 0.015), Vector3(BULKHEAD.x, BULKHEAD.y, 0.03), 0.01, turn)
	KIT.block(p, glass, at + turn * Vector3(0, 0, 0.05), Vector3(BULKHEAD.x - 0.05, BULKHEAD.y - 0.04, 0.05), 0.018, turn)
	for k in 3: KIT.block(p, "steel_grey", at + turn * Vector3(0, -0.03 + k * 0.03, 0.078), Vector3(BULKHEAD.x - 0.03, 0.007, 0.007), 0.0, turn)
	KIT.block(p, "steel_grey", at + turn * Vector3(0, 0, 0.078), Vector3(0.007, BULKHEAD.y - 0.03, 0.007), 0.0, turn)

static func bulkhead_mesh(b: Node3D, glass: String) -> ArrayMesh:
	return KIT.cached(b, KIT.key_of("bulkhead_" + glass, BULKHEAD), func() -> ArrayMesh:
		var p := KIT.begin()
		bulkhead(p, glass, Vector3.ZERO)
		return KIT.finish(b, p, "bulkhead_" + glass, BULKHEAD, {"wall": true, "solid": false}))

## The bulkhead over the door and the banner by it, on the side `side`, in
## the door's face frame; the bulkhead on a ceiling `ceiling` high, if not 0.
static func head_mesh(b: Node3D, kind: String, side: float, ceiling: float) -> ArrayMesh:
	var spec: Dictionary = KINDS[kind]
	return KIT.cached(b, KIT.key_of("landmark_head_%s_%d" % [kind, int(side)], BULKHEAD, "%.2f" % ceiling), func() -> ArrayMesh:
		var p := KIT.begin()
		if ceiling > 0.0: bulkhead(p, String(spec.glass), Vector3(0, ceiling, CEILING_OUT), Basis(Vector3.RIGHT, PI / 2))
		else: bulkhead(p, String(spec.glass), Vector3(0, LAMP_Y, 0))
		var x := side * (FRAME_EDGE + BANNER_GAP)
		if BANNERS:
			var enamel: String = LOOKS[String(spec.look)][0]
			KIT.block(p, enamel, Vector3(x, BANNER_Y, BANNER_OUT + BANNER.z * 0.5), BANNER, 0.003)
			# Its bracket: a plate on the wall and a bar out along the panel's top.
			var top := BANNER_Y + BANNER.y * 0.5
			KIT.block(p, "steel_grey", Vector3(x, top + 0.02, 0.005), Vector3(0.05, 0.12, 0.01))
			KIT.block(p, "steel_grey", Vector3(x, top + 0.02, (BANNER_OUT + BANNER.z) * 0.5), Vector3(0.016, 0.016, BANNER_OUT + BANNER.z))
			for z: float in [BANNER_OUT + 0.06, BANNER_OUT + BANNER.z - 0.06]: KIT.block(p, "steel_grey", Vector3(x, top + 0.006, z), Vector3(0.01, 0.02, 0.01))
		var reach := absf(x) + 0.05
		return KIT.finish(b, p, "landmark_head_" + kind, Vector3(reach * 2.0, LAMP_Y + BULKHEAD.y, BANNER_OUT + BANNER.z), {"solid": false}))

## Yellow and black stripes at 45 degrees, on a quad facing +Z.
static var stripes: QuadMesh = null
static func stripes_mesh() -> QuadMesh:
	if stripes != null: return stripes
	var image := Image.create(128, 14, true, Image.FORMAT_RGB8)
	for y in 14:
		for x in 128: image.set_pixel(x, y, Color(0.8, 0.6, 0.07) if posmod(x + y, 14) < 7 else Color(0.05, 0.05, 0.045))
	image.generate_mipmaps()
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = ImageTexture.create_from_image(image)
	paint.roughness = 0.6
	stripes = QuadMesh.new()
	stripes.size = STRIPES
	stripes.material = paint
	stripes.resource_name = "hazard_stripes"
	return stripes

## A landmark room's object lamps and, in a corridor cell where the way to a
## landmark turns, its way sign (office_geometry.extras()).
static func room(b: Node3D, node: Node3D, here: Dictionary) -> void:
	var manifest: Dictionary = b.manifest
	var id := int(here.id)
	var air: Dictionary = manifest.get("air", {})
	if air.has("stop") and int(air.get("plant", -1)) == id:
		var stop: Dictionary = air.stop
		var turn := Basis(Vector3.UP, float(stop.yaw))
		var point := spot_of(stop) - node.position
		object_lamp(b, node, id, Transform3D(turn, point + Vector3(0, OVER_OBJECT, 0) + turn.z * 0.002), point + turn.z * 0.12)
	if air.has("security") and int(air.security.room) == id:
		var desk: Dictionary = air.security.desk
		var turn := Basis(Vector3.UP, float(desk.yaw))
		var point := spot_of(desk) - node.position
		# Over the console's start key (air_equipment.gd security_console(), at
		# DESK_MIDDLE out on the desk), clear of its monitors' tops at 1.2 m.
		object_lamp(b, node, id, Transform3D(turn, point + turn * Vector3(CONSOLE_KEY.x, 1.85, 0.002)), point + turn * CONSOLE_KEY, true)
	var rows: Array = ways(b).get(id, [])
	if not rows.is_empty(): way_sign(b, node, here, rows)

static func spot_of(spot: Dictionary) -> Vector3:
	return Vector3(float(spot.point[0]), float(spot.point[1]), float(spot.point[2]))

## The landmarks of a planta: [room id, kind] (the window; the electrical
## room and the maneuver room; the security post and the plant room on the third).
static func targets(manifest: Dictionary, planta: int) -> Array:
	match planta:
		0: return [[int(manifest.get("mail", {}).get("window", -1)), "window"]]
		1: return [[int(manifest.get("power", {}).get("room", -1)), "electrical"], [int(manifest.get("power", {}).get("maneuver", {}).get("room", -1)), "maneuver"]]
		2:
			var air: Dictionary = manifest.get("air", {})
			return [[int(air.get("security", {}).get("room", -1)), "security"], [int(air.get("room", -1)), "machines"]]
	return []

## The shortest ways over the planta's rooms from `start` (manifest.adjacency):
## each room reached -> the room it was reached from.
static func tree_from(manifest: Dictionary, start: int) -> Dictionary:
	var rooms: Array = manifest.rooms
	var parent := {start: -1}
	var queue: Array = [start]
	var wing := int(rooms[start].get("wing", 0))
	while not queue.is_empty():
		var id: int = queue.pop_front()
		for next in manifest.adjacency[id]:
			var n := int(next)
			if parent.has(n) or int(rooms[n].get("wing", -1)) != wing or FLOOR.is_void(rooms[n]): continue
			parent[n] = id
			queue.append(n)
	return parent

static func path_to(parent: Dictionary, target: int) -> Array:
	var path: Array = []
	if not parent.has(target): return path
	var at := target
	while at >= 0:
		path.push_front(at)
		at = int(parent[at])
	return path

## Where a way sign can hang: a corridor, a gallery or a lobby, not the
## reception (the floor's first view, with its directory).
static func signable(room: Dictionary) -> bool:
	return bool(room.get("corridor", false)) or int(room.type) in [OFFICE.CORRIDOR, OFFICE.GALLERY, OFFICE.LOBBY]

## The way signs of the floor, made once: cell id -> rows [words, kind ("" for
## a place that is no landmark), way in, way out], two rows to a sign at most.
## On each planta: one sign on the way from its arrival to its landmarks, at
## the turn nearest the way's middle in a cell that can take one, with a row
## for each landmark whose way goes through it; and up to DECOYS_MOST more, to
## the nearest room of each of the company's other places (WAY_PLACES), each
## where its own way turns. Every arrow is true.
static func ways(b: Node3D) -> Dictionary:
	if b.has_meta("landmark_ways"): return b.get_meta("landmark_ways")
	var manifest: Dictionary = b.manifest
	var made := {}
	var entries: Array = manifest.get("entries", [])
	for planta in entries.size():
		var start := int(entries[planta])
		if start < 0 or not manifest.has("adjacency"): continue
		var parent := tree_from(manifest, start)
		var landmarks: Array = targets(manifest, planta).filter(func(target: Array): return int(target[0]) >= 0)
		if not landmarks.is_empty():
			var cell := pick_cell(manifest, path_to(parent, int(landmarks[0][0])), made)
			for target: Array in landmarks:
				var path := path_to(parent, int(target[0]))
				var row := row_at(manifest, path, cell) if cell >= 0 else []
				# A landmark whose way parts from the first one's (the bigger
				# building's air room from its post) has its one sign on its own way.
				var own := cell
				if row.is_empty():
					own = pick_cell(manifest, path, made)
					if own >= 0: row = row_at(manifest, path, own)
				if not row.is_empty(): add_row(made, own, [String(KINDS[String(target[1])].way), String(target[1]), row[0], row[1]])
		# The company's other places on the planta, nearest of each first.
		var taken := {}
		for target: Array in landmarks: taken[int(target[0])] = true
		var places: Array = []
		for place_kind in OFFICE.WAY_PLACES:
			var best := -1
			var best_size := 1 << 30
			for id in parent:
				var room: Dictionary = manifest.rooms[int(id)]
				if int(room.type) != int(place_kind) or taken.has(int(id)) or not kind_of(manifest, int(id)).is_empty(): continue
				var length := path_to(parent, int(id)).size()
				if length < best_size:
					best_size = length
					best = int(id)
			if best >= 0: places.append([best, String(OFFICE.WAY_PLACES[place_kind]), best_size])
		places.sort_custom(func(a: Array, c: Array): return int(a[2]) < int(c[2]) or (int(a[2]) == int(c[2]) and int(a[0]) < int(c[0])))
		var decoys := 0
		for place: Array in places:
			if decoys >= DECOYS_MOST: break
			var path := path_to(parent, int(place[0]))
			var cell := pick_cell(manifest, path, made, true)
			if cell < 0: continue
			var row := row_at(manifest, path, cell)
			if row.is_empty(): continue
			add_row(made, cell, [String(place[1]), "", row[0], row[1]])
			decoys += 1
	b.set_meta("landmark_ways", made)
	return made

## The cell on a way to hang its sign in: a turn in a cell that can take one,
## the one nearest the way's middle (or the middle cell when it never turns);
## never one whose sign is full. `share`: one with a sign of a single row is
## fine too.
static func pick_cell(manifest: Dictionary, path: Array, made: Dictionary, share := false) -> int:
	if path.size() < 3: return -1
	var best := -1
	var best_score := INF
	for k in range(1, path.size() - 1):
		var id := int(path[k])
		if not signable(manifest.rooms[id]): continue
		var rows: int = made.get(id, []).size()
		if rows >= 2 or (rows > 0 and not share): continue
		var into := step(manifest, path[k - 1], path[k])
		var on := step(manifest, path[k], path[k + 1])
		# A turn first; then nearest the middle.
		var score := absf(float(k) - float(path.size() - 1) * 0.5) + (0.0 if into.dot(on) < 0.5 else 100.0)
		if score < best_score:
			best_score = score
			best = id
	return best

## The way in and out of `cell` on `path`, or nothing when it is not on it.
static func row_at(manifest: Dictionary, path: Array, cell: int) -> Array:
	var k := path.find(cell)
	if k <= 0 or k >= path.size() - 1: return []
	return [step(manifest, path[k - 1], path[k]), step(manifest, path[k], path[k + 1])]

## A row onto a cell's sign: its rows share their way in (the sign faces it).
static func add_row(made: Dictionary, cell: int, row: Array) -> void:
	if not made.has(cell): made[cell] = []
	var rows: Array = made[cell]
	if rows.size() >= 2: return
	if not rows.is_empty() and (rows[0][2] as Vector3).dot(row[2]) < 0.5: return
	rows.append(row)

## The way from one room to the next, flat and of unit length.
static func step(manifest: Dictionary, from: int, to: int) -> Vector3:
	var d := FLOOR.position_of(manifest.rooms[int(to)]) - FLOOR.position_of(manifest.rooms[int(from)])
	d.y = 0.0
	return d.normalized()

## A sign hung from the ceiling in the middle of a cell, square to the way in
## and read coming in: a white enamel panel with a row for each landmark, its
## name, its arrow (left, right or on) and a band in its colour at the
## arrow's end; two rods up to the ceiling.
static func way_sign(b: Node3D, node: Node3D, here: Dictionary, rows: Array) -> void:
	var into: Vector3 = rows[0][2]
	var frame := Transform3D(Basis(into.cross(Vector3.UP), Vector3.UP, -into), Vector3(0, WAY_Y, 0))
	var tall := WAY.y * rows.size()
	b.place(node, way_mesh(b, rows.size(), float(here.height) - WAY_Y), frame, false)
	for k in rows.size():
		var row: Array = rows[k]
		var out: Vector3 = row[3]
		var across := out.dot(into.cross(Vector3.UP))
		var angle := 0.0 if across > 0.5 else PI if across < -0.5 else PI / 2
		var arrow_x: float = -WAY.x * 0.5 + 0.08 if across < -0.5 else WAY.x * 0.5 - 0.08
		var y := tall - WAY.y * (k + 0.5)
		# A landmark's row in its colour; any other place's in white.
		var band: String = LOOKS.get(String(KINDS[String(row[1])].look) if KINDS.has(String(row[1])) else "white", ["sign_white"])[0]
		b.place(node, band_mesh(b, band), frame * Transform3D(Basis.IDENTITY, Vector3(signf(arrow_x) * (WAY.x * 0.5 - 0.02), y, WAY.z * 0.5)), false)
		b.place(node, arrow_mesh(b, "black", Vector2(0.1, 0.08)), frame * Transform3D(Basis(Vector3.BACK, angle), Vector3(arrow_x - signf(arrow_x) * 0.03, y, WAY.z * 0.5 + 0.001)), false)
		var words := String(row[0])
		var room_for := Vector2(WAY.x - 0.22, WAY.y - 0.05)
		var text_x := -signf(arrow_x) * 0.05
		label(node, words, frame * Transform3D(Basis.IDENTITY, Vector3(text_x, y, WAY.z * 0.5 + 0.002)), INK_BLACK, fit(words, room_for, 40), BANNER_REACH)

## The way sign's panel for `rows` rows and its rods `drop` up to the ceiling.
static func way_mesh(b: Node3D, rows: int, drop: float) -> ArrayMesh:
	var size := Vector3(WAY.x, drop, WAY.z)
	return KIT.cached(b, KIT.key_of("way_sign_%d" % rows, size), func() -> ArrayMesh:
		var p := KIT.begin()
		var tall := WAY.y * rows
		KIT.block(p, "sign_white", Vector3(0, tall * 0.5, 0), Vector3(WAY.x, tall, WAY.z), 0.004)
		for s: float in [-1.0, 1.0]:
			KIT.cylinder(p, "metal", Vector3(s * (WAY.x * 0.5 - 0.06), tall + (drop - tall) * 0.5, 0), 0.006, drop - tall, 6)
			KIT.block(p, "metal", Vector3(s * (WAY.x * 0.5 - 0.06), drop - 0.006, 0), Vector3(0.05, 0.012, 0.05))
		return KIT.finish(b, p, "way_sign", size, {"solid": false}))

## A band of colour at a way sign's end.
static func band_mesh(b: Node3D, enamel: String) -> ArrayMesh:
	return KIT.cached(b, KIT.key_of("way_band_" + enamel, Vector3(0.04, WAY.y, 0.002)), func() -> ArrayMesh:
		var p := KIT.begin()
		KIT.block(p, enamel, Vector3(0, 0, 0.001), Vector3(0.04, WAY.y - 0.01, 0.002))
		return KIT.finish(b, p, "way_band_" + enamel, Vector3(0.04, WAY.y, 0.002), {"solid": false}))

## An arrow pointing +X on a face to +Z, `size` long and high, centred.
static func arrow_mesh(b: Node3D, key: String, size: Vector2) -> ArrayMesh:
	return KIT.cached(b, KIT.key_of("arrow_" + key, Vector3(size.x, size.y, 0.002)), func() -> ArrayMesh:
		var p := KIT.begin()
		var head := size.x * 0.45
		KIT.block(p, key, Vector3(-head * 0.5, 0, 0.001), Vector3(size.x - head, size.y * 0.3, 0.002))
		var tool := KIT.tool_for(p, key)
		KIT.tri(tool, Vector3(size.x * 0.5, 0, 0.002), Vector3(size.x * 0.5 - head, size.y * 0.5, 0.002), Vector3(size.x * 0.5 - head, -size.y * 0.5, 0.002), Vector3.BACK)
		return KIT.finish(b, p, "arrow_" + key, Vector3(size.x, size.y, 0.002), {"solid": false}))

## The directory in an arrival (office_walls.gd draw(), "directory"): a
## walnut board of black felt with the planta's name, its landmarks first,
## each with a band in its colour, then its departments, each with an arrow
## to where the shortest way to it goes from here (the cell two rooms along
## it), none for the department one stands in. `at` is the board's place in
## `boundary`, its back on the wall, its bottom at the floor's height `at`
## says; the lift out of the first two plantas is not on it.
static func directory(b: Node3D, boundary: Node3D, here: Dictionary, at: Transform3D, size: Vector3) -> void:
	var manifest: Dictionary = b.manifest
	b.place(boundary, board_mesh(b, size), at, false)
	var planta := int(here.get("wing", 0))
	var world: Transform3D = (boundary.get_parent() as Node3D).transform * boundary.transform * at
	var parent := tree_from(manifest, int(here.id))
	# The departments alone: the landmarks have their one way sign (ways()).
	var lines: Array = []
	var named := lines.map(func(line: Array) -> String: return String(line[0]))
	var departments: Array = manifest.get("departments", [])
	for entry in (departments[planta] if planta < departments.size() else []):
		if named.has(String(entry.name)): continue
		var best := -1
		var best_size := 1 << 30
		for id in parent:
			var room: Dictionary = manifest.rooms[int(id)]
			if int(room.get("sector", -2)) != int(entry.sector) or OFFICE.off_limits(room): continue
			var length := path_to(parent, int(id)).size()
			if length < best_size:
				best_size = length
				best = int(id)
		if best >= 0: lines.append([String(entry.name), best, ""])
	var inner := Vector2(size.x - 0.12, size.y - 0.1)
	var line_h := minf(LINE_MOST, (inner.y - 0.07) / maxf(lines.size(), 1))
	var top := size.y - 0.05
	var face_z := -size.z * 0.5 + 0.026
	var title := String(OFFICE.PLANTA_NAMES[planta]) if planta < OFFICE.PLANTA_NAMES.size() else ""
	label(boundary, title, at * Transform3D(Basis.IDENTITY, Vector3(0, top - 0.03, face_z)), INK_WHITE, fit(title, Vector2(inner.x, 0.05), 34, false), SIGN_REACH, false)
	var names_w := inner.x - 0.12
	var font := 40
	for line: Array in lines: font = mini(font, fit(String(line[0]), Vector2(names_w - 0.05, line_h * 0.9), 40, false))
	for k in lines.size():
		var line: Array = lines[k]
		var y := top - 0.07 - line_h * (k + 0.5)
		var left := -inner.x * 0.5 + 0.05
		var words := String(line[0])
		label(boundary, words, at * Transform3D(Basis.IDENTITY, Vector3(left + width_of(words, font) * 0.5, y, face_z)), INK_WHITE, font, SIGN_REACH, false)
		if not String(line[2]).is_empty():
			var enamel: String = LOOKS.get(String(KINDS[String(line[2])].look), ["sign_white"])[0]
			b.place(boundary, band_mesh(b, enamel), at * Transform3D(Basis.IDENTITY.scaled(Vector3(0.5, line_h / WAY.y, 1.0)), Vector3(left - 0.025, y, face_z)), false)
		var path := path_to(parent, int(line[1]))
		if path.size() < 2: continue
		var toward := FLOOR.position_of(manifest.rooms[int(path[mini(2, path.size() - 1)])]) - FLOOR.position_of(here)
		var screen := Vector2(toward.dot(world.basis.x), toward.dot(-world.basis.z))
		var angle := snappedf(screen.angle(), PI / 4)
		b.place(boundary, arrow_mesh(b, "paper", Vector2(0.06, 0.045)), at * Transform3D(Basis(Vector3.BACK, angle), Vector3(inner.x * 0.5 - 0.05, y, face_z + 0.001)), false)

## The directory's board: a walnut frame round black felt.
static func board_mesh(b: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(b, KIT.key_of("directory_felt", size), func() -> ArrayMesh:
		var p := KIT.begin()
		var fw := 0.03
		KIT.block(p, "walnut_object", Vector3(0, size.y - fw * 0.5, 0), Vector3(size.x, fw, size.z), 0.004)
		KIT.block(p, "walnut_object", Vector3(0, fw * 0.5, 0), Vector3(size.x, fw, size.z), 0.004)
		for s: float in [-1.0, 1.0]: KIT.block(p, "walnut_object", Vector3(s * (size.x * 0.5 - fw * 0.5), size.y * 0.5, 0), Vector3(fw, size.y - fw * 2.0, size.z), 0.004)
		KIT.block(p, "black", Vector3(0, size.y * 0.5, -size.z * 0.5 + 0.02), Vector3(size.x - fw * 2.0, size.y - fw * 2.0, 0.01))
		return KIT.finish(b, p, "directory_felt", size, {"wall": true, "mount": 1.1, "solid": false}))
