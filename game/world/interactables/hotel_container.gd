extends Area3D
## A piece with drawers or shelves, gone through by hand. Most hold nothing;
## four of them, in the wing of the last stage, hold a number of the code.
## A suitcase lying on the floor opens too, and never holds a number: only
## what is not needed, a hint or a document of the archive.
##
## Going through one is not instant: it takes a second of standing there with
## your back to the room, and most of them can be heard from the rooms next
## door. That is the price of looking. What makes no sound (SEARCH_SOUNDS) is
## not heard by anybody, the creature either.
signal searched_changed
const NOISE := preload("res://game/audio/noise_kinds.gd")
const ROOM_LAYERS := preload("res://game/world/hotel/room_layers.gd")
## Seconds of holding the interaction before it gives up what it has.
const SEARCH_TIME := 1.0
## The number it hides, or -1, and which place of the code it is (1..4).
var digit := -1
var slot := 0
## The hint in it, if any (hint_placement.gd): its id among the floor's.
var hint := -1
## The document of the archive in it, if any (document_placement.gd): its
## entry, read by whoever finds it the moment they do.
var document := ""
var searched := false
var kind := ""
## How far the piece's front stands from its stretch's wall (room_dressing).
## The note and the hand's reach are measured from it: at a fixed half metre
## the note was buried in most pieces, and a cabinet deeper than that could
## not be searched from the front at all.
var front := 0.5
## Where the note sits on this piece, worked out by the dressing from the
## piece's own mesh (room_dressing.note_fold()): {at, yaw, skew, lie, hang,
## lie_tilt, hang_tilt}. Empty: the old place, out of the front.
var note_spot := {}

func _ready() -> void:
	add_to_group("hotel_containers")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var reach := maxf(front, 0.3) + 0.25
	box.size = Vector3(1.1, 1.2, reach + 0.2)
	shape.shape = box
	shape.position = Vector3(0, 0.6, (reach - 0.2) * 0.5)
	add_child(shape)

## Gone through. Returns whether this changed anything, so the noise and the
## notice happen once.
func set_searched(value: bool) -> bool:
	if searched == value: return false
	searched = value
	searched_changed.emit()
	return true

## Heard like a door opened slowly: enough to say somebody is in this room.
func noise_radius() -> float: return NOISE.radius("door_slow")

## What going through it sounds like, by the piece it is (the model its note
## is worked out on, room_dressing.note_fold()): the drawers of the gothic
## commode are big, and so is the glazed cabinet's lower door; those of the
## painted cabinet small and old, the office's drawer cabinet is a modern one,
## and a stack opens a cardboard box (tools/audio/prepare_search_sfx.py). The
## console, the bookcase, a stack of only crates and a suitcase make none (the
## author's word, 21 October 2026). Anything else would sound like a door
## opened slowly, as everything did before 19 October 2026.
const SEARCH_SOUNDS := {
	"GothicCommode_01": ["res://assets/audio/sfx/search/big_drawer.wav"],
	"vintage_cabinet_01": ["res://assets/audio/sfx/search/big_drawer.wav"],
	"ClassicConsole_01": [],
	"wooden_bookshelf_worn": [],
	"plastic_crate_02": [],
	"vintage_suitcase_b": [],
	"painted_wooden_cabinet": ["res://assets/audio/sfx/search/wooden_drawer.wav"],
	"drawer_cabinet": ["res://assets/audio/sfx/search/soft_drawer_1.wav", "res://assets/audio/sfx/search/soft_drawer_2.wav", "res://assets/audio/sfx/search/soft_drawer_3.wav", "res://assets/audio/sfx/search/soft_drawer_4.wav", "res://assets/audio/sfx/search/soft_drawer_5.wav"],
	"cardboard_box_01": ["res://assets/audio/sfx/search/box.wav"],
}
const SEARCH_SOUND := "res://assets/audio/sfx/door/opening/slow-opening.wav"
## Its level: the drawer close by, about as loud as the slow creak was.
const SEARCH_DB := -20.0
const SEARCH_CREAK_DB := -10.0

## The recordings it may sound with.
func search_sounds() -> Array:
	return SEARCH_SOUNDS.get(String(note_spot.get("model", "")), [SEARCH_SOUND])

## Gone through without a sound: nobody hears it, the creature either.
func silent() -> bool:
	return search_sounds().is_empty()

## Gone through and left as it was: nothing of it opens or is moved (the
## author's word, 21 October 2026).
const STILL := ["console", "bookcase"]
func still() -> bool:
	return kind in STILL

## A piece gone through is left open, for anybody to see who comes by --
## the creature too, in its clicks (the author's word, 19 October 2026). One
## that opens (its drawers and doors baked apart: tools/props/
## build_catalogue.gd, MOVING) is taken out of its room's batch and drawn in
## parts, with one of them out: a drawer, or else a wooden door, or else a
## glass one; the note's own drawer if it held one, another the same on every
## machine if not. It comes out with the sound, reaching the end of its travel
## on the recording's last knock. What has no drawer or door of its own has
## one of the things on it or in it moved instead, enough to be read from the
## doorway: on a console an ornament knocked over on its side; off a
## bookcase's shelf one thing taken down and left on the floor in front of
## it; the top box of a stack set down on the floor beside it (one with
## nothing on top is shoved out instead). Moved a hair less (an ornament put
## back askew, a book pulled out a little) none of it was seen in a lit room
## from two metres. Since 21 October 2026 (the author's word) the console and
## the bookcase are left as they were (STILL): only the paper is gone. A
## suitcase's lid is lifted on its hinge until it stands, leaning a little
## back over the case. What is opened or moved has a box of its own on the
## layer the creature's clicks come back from and that stops nobody walking
## (64, echo_view.RAY_MASK; it hides from sight and hearing like a moving
## door). Searching only ever goes one way, so nothing here is shut again.
const DRAWER_OUT := 0.5
const DOOR_OPEN := 1.1
const DOOR_SWING := 1.2
const LID_OPEN := 1.45
## How long what opens takes when there is no recording to keep time with.
const SILENT_OPEN := 0.8
## How far in front of the piece a thing taken down is left (metres, past
## where it stood), how far a box with nothing on top is shoved, how much
## either is turned (radians), and how long an ornament takes to fall over.
const SET_DOWN := 0.4
const SHOVE := 0.2
const SET_TURN := 0.5
const TOPPLE := 0.3
const ECHO := 64
## Where it is drawn (hotel_geometry.place): the piece itself, when it opens,
## and the things put on it or in it.
var main := {}
var things: Array = []
## What it is drawn with once gone through, and the boxes the clicks find.
var shown: Array = []
## What was done to it: {part, node, closed, open} for a part that came out,
## {thing, from, to} for a thing moved (the batch keeps no transforms that
## can be read back without a renderer).
var left := {}

## Gone through: shown so, the opening taking `seconds` (none: at once, as
## when somebody comes back into a floor already gone through).
func show_searched(seconds: float) -> void:
	if not shown.is_empty() or still(): return
	if not main.is_empty() and main.entry.get("multi") != null: open_part(seconds)
	elif not things.is_empty(): shift_thing(seconds > 0.0)

## The same on every machine: from where it stands.
func pick() -> int:
	return absi(hash(Vector3i((global_position * 100.0).round())))

func open_part(seconds: float) -> void:
	var entry: Dictionary = main.entry
	var base := String((entry.mesh as Mesh).resource_path).get_basename()
	var body: Mesh = load(base + "_body.res")
	var stood: Transform3D = entry.transforms[int(main.index)]
	var source: GeometryInstance3D = entry.instance
	var room: Node3D = main.parent
	# Out of the batch: nothing of the whole piece is drawn there any more.
	(entry.multi as MultiMesh).set_instance_transform(int(main.index), Transform3D(Basis.from_scale(Vector3.ZERO), stood.origin))
	drawn(room, source, body, stood)
	var names: PackedStringArray = body.get_meta("parts")
	var chosen := choose_part(names, base)
	for part_name in names:
		var part: Mesh = load("%s_%s.res" % [base, part_name])
		var at := stood * Transform3D(Basis.IDENTITY, part.get_meta("pivot"))
		var node := drawn(room, source, part, at)
		if part_name != chosen: continue
		var open := at * motion(part_name, part)
		left = {"part": part_name, "node": node, "closed": at, "open": open}
		var box: AABB = part.get_meta("box")
		echo_box(room, open * Transform3D(Basis.IDENTITY, box.get_center() - (part.get_meta("pivot") as Vector3)), box.size)
		if seconds <= 0.0:
			node.transform = open
			continue
		var tween := create_tween()
		tween.tween_property(node, "transform", open, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT if part_name.begins_with("drawer") else Tween.EASE_OUT)

## Which part comes out (see show_searched).
func choose_part(names: PackedStringArray, base: String) -> String:
	for kind_of_part in ["drawer", "door", "glass", "lid"]:
		var of_kind: Array = Array(names).filter(func(part_name): return part_name.begins_with(kind_of_part + "_"))
		if of_kind.is_empty(): continue
		# The drawer the note was shut in: the one whose front its slip hung
		# out over, a page's or a hint's.
		if (digit >= 0 or hint >= 0 or not document.is_empty()) and kind_of_part == "drawer" and note_spot.has("piece"):
			var at: Vector3 = (note_spot.piece as Transform3D).affine_inverse() * (note_spot.at as Vector3)
			for part_name in of_kind:
				var box: AABB = (load("%s_%s.res" % [base, part_name]) as Mesh).get_meta("box")
				if at.y >= box.position.y and at.y <= box.end.y + 0.03 and at.x >= box.position.x and at.x <= box.end.x: return part_name
		return of_kind[pick() % of_kind.size()]
	return names[0]

## A drawer slides out by DRAWER_OUT of its depth; a door turns about its
## hinge by DOOR_OPEN, its free edge out into the room; a lid turns up about
## the hinge along its edge by LID_OPEN.
static func motion(part_name: String, part: Mesh) -> Transform3D:
	var box: AABB = part.get_meta("box")
	if part_name.begins_with("drawer"): return Transform3D(Basis.IDENTITY, Vector3(0, 0, box.size.z * DRAWER_OUT))
	if part_name.begins_with("lid"): return Transform3D(Basis(Vector3.RIGHT, LID_OPEN), Vector3.ZERO)
	var hinge: Vector3 = part.get_meta("pivot")
	return Transform3D(Basis(Vector3.UP, -DOOR_OPEN if box.get_center().x > hinge.x else DOOR_OPEN), Vector3.ZERO)

## A mesh drawn on its own where the batch drew it, lit as the batch is.
func drawn(room: Node3D, source: GeometryInstance3D, mesh: Mesh, at: Transform3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Searched_" + mesh.resource_name
	node.mesh = mesh
	node.cast_shadow = source.cast_shadow
	node.gi_mode = source.gi_mode
	node.visibility_range_end = source.visibility_range_end
	node.visibility_range_end_margin = source.visibility_range_end_margin
	room.add_child(node)
	node.transform = at
	ROOM_LAYERS.put_on(node, source.layers & ROOM_LAYERS.ROOMS)
	shown.append(node)
	return node

## One of its things moved (see show_searched): a stack's top box, or one of
## the others. `animated`: an ornament is seen to fall; what is taken down is
## simply there when the search is over.
func shift_thing(animated: bool) -> void:
	var handle: Dictionary = things[pick() % things.size()]
	var floor_y := INF
	for other in things:
		var stands: Transform3D = other.entry.transforms[int(other.index)]
		floor_y = minf(floor_y, stands.origin.y)
		if kind == "boxes" and stands.origin.y > (handle.entry.transforms[int(handle.index)] as Transform3D).origin.y: handle = other
	var entry: Dictionary = handle.entry
	var multi: MultiMesh = entry.get("multi")
	if multi == null: return
	var index := int(handle.index)
	var from: Transform3D = entry.transforms[index]
	var aabb := (entry.mesh as Mesh).get_aabb()
	var grown := from.basis.get_scale().x
	# Out of the piece, towards whoever went through it; the floor it stands
	# on is its own (the piece stands there too).
	var forward := (transform.basis * Vector3.BACK).normalized()
	var way := 1.0 if pick() % 2 == 0 else -1.0
	var ground := transform.origin.y + 0.002
	var to: Transform3D
	if kind == "console":
		# Over on its side where it stood: lying, its middle as high off the
		# top as it is wide.
		to = Transform3D(Basis(forward, way * PI / 2.0) * from.basis, from.origin + Vector3.UP * minf(aabb.size.x, aabb.size.z) * grown * 0.5)
	elif kind == "boxes" and from.origin.y < floor_y + 0.05:
		to = Transform3D(Basis(Vector3.UP, way * SET_TURN) * from.basis, from.origin + forward * SHOVE)
	else:
		var out := forward * (SET_DOWN + aabb.size.z * grown * 0.5)
		to = Transform3D(Basis(Vector3.UP, way * SET_TURN) * from.basis, Vector3(from.origin.x, ground, from.origin.z) + out)
	left = {"thing": handle, "from": from, "to": to}
	echo_box(handle.parent, to * Transform3D(Basis.IDENTITY, aabb.get_center()), aabb.size)
	if not animated or kind != "console":
		multi.set_instance_transform(index, to)
		return
	var tween := create_tween()
	tween.tween_method(func(t: float): multi.set_instance_transform(index, from.interpolate_with(to, t)), 0.0, 1.0, TOPPLE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## What the creature's clicks come back from: a box `size` big (as the piece
## is scaled, `at` carrying the scale) at `at`, in the room.
func echo_box(room: Node3D, at: Transform3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "SearchedEcho"
	body.collision_layer = ECHO
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size * at.basis.get_scale()
	shape.shape = cube
	body.add_child(shape)
	room.add_child(body)
	body.transform = Transform3D(at.basis.orthonormalized(), at.origin)
	shown.append(body)

## The slip of paper one of the four hides, left showing, pale enough to catch
## a torch from across the room. Four numbers among two hundred pieces of
## furniture are not found by opening all of them, and this is what says which
## one is worth the second it takes.
##
## Where it is depends on the piece, as it would: shut in a drawer and hanging
## out of the slit above it, or laid on a shelf, on the top of a console or of
## the painted cupboard or on a box's lid, with its end come down over the
## edge. A sheet folded once, so the part that lies back (inside the
## drawer, under the books) and the part that hangs in front are both where
## paper would be. Put at one height out of the front of everything, it hung
## in the air under a console and in front of a bookcase's empty shelf.
##
## Taking it is going through the piece as usual; the paper leaves with it,
## which is the other half of the answer -- you can see, from the doorway,
## which rooms you have already been through.
const SHEET := Vector2(0.16, 0.21)
const THICK := 0.003
## A few lines of handwriting across it, every LINE_EVERY metres: they are what
## says a note rather than a scrap, close up.
const INK := Color(0.16, 0.15, 0.18)
const LINE_EVERY := 0.024
var note: Node3D
func plant_note() -> void:
	if is_instance_valid(note): return
	var spot := note_spot
	if spot.is_empty(): spot = {"at": Vector3(0.02, 0.56, maxf(front, 0.3) + 0.01), "yaw": 0.0, "skew": 0.0, "lie": 0.0, "hang": SHEET.y, "lie_tilt": 0.0, "hang_tilt": 0.3}
	var sheet := StandardMaterial3D.new()
	# The palest thing in the room, and no light of its own: the torch is what
	# picks it out. Lit of itself it hung in a pitch-dark room like a lamp.
	sheet.albedo_color = Color(0.96, 0.94, 0.87)
	sheet.roughness = 0.95
	var ink := StandardMaterial3D.new()
	ink.albedo_color = INK
	ink.roughness = 1.0
	note = Node3D.new()
	note.name = "Note"
	# With the piece it lies on, which stands a hair off the floor
	# (hotel_geometry.MODEL_LIFT).
	note.position = (spot.at as Vector3) + Vector3(0, 0.002, 0)
	note.rotation.y = float(spot.yaw)
	add_child(note)
	var skew := float(spot.get("skew", 0.0))
	# Back from the fold, down by lie_tilt, askew on the surface it lies on.
	var lie := float(spot.lie)
	if lie > 0.001:
		var tilt := Basis(Vector3.UP, skew) * Basis(Vector3.RIGHT, -float(spot.lie_tilt))
		add_part("Lie", tilt, Vector3(0, THICK * 0.5, -lie * 0.5), Vector3(SHEET.x, THICK, lie), sheet, ink, Vector3(0, 0, -1), Vector3(0, 1, 0))
	# Down from the fold, its foot out by hang_tilt, askew on the face it hangs
	# against: the same turn, seen from the front.
	var hang := float(spot.hang)
	if hang > 0.001:
		var tilt := Basis(Vector3.RIGHT, -float(spot.hang_tilt)) * Basis(Vector3.BACK, skew)
		add_part("Hang", tilt, Vector3(0, -hang * 0.5, THICK * 0.5), Vector3(SHEET.x, hang, THICK), sheet, ink, Vector3(0, -1, 0), Vector3(0, 0, 1))

## One part of the folded sheet: `turn` sets it on its face, `centre` is its
## middle before the turn, measured from the fold. Its lines of writing run
## across it, away from the fold (`away`), on the face that shows (`face`).
func add_part(part_name: String, turn: Basis, centre: Vector3, size: Vector3, sheet: Material, ink: Material, away: Vector3, face: Vector3) -> void:
	var paper := BoxMesh.new()
	paper.size = size
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = paper
	part.material_override = sheet
	part.transform = Transform3D(turn, turn * centre)
	# The shadow of the part hanging down is half of what says a paper and
	# not a label stuck on: the torch throws it on the wood under the part
	# that stands off. The part lying flat casts none (lying across a crate's
	# open top it went grey in its own shadow).
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part_name == "Hang" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	note.add_child(part)
	var length: float = absf(size.dot(away))
	var line := BoxMesh.new()
	line.size = Vector3(SHEET.x * 0.7, 0.003, 0.003)
	line.material = ink
	var written := 0
	var along := 0.018
	while along < length - 0.012:
		var stroke := MeshInstance3D.new()
		stroke.mesh = line
		# Every third line ends a sentence short; all start at one margin.
		var short: float = 0.03 if written % 3 == 2 else 0.0
		stroke.scale = Vector3(1.0 - short / (SHEET.x * 0.7), 1.0, 1.0)
		stroke.position = away * (along - length * 0.5) + face * (THICK * 0.5 + 0.0012) + Vector3(-short * 0.5, 0, 0)
		stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.add_child(stroke)
		written += 1
		along += LINE_EVERY

## Gone through: whoever did it took the paper with them.
func take_note() -> void:
	if is_instance_valid(note): note.queue_free()
	note = null
